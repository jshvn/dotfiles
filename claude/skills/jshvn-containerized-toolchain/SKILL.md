---
name: jshvn-containerized-toolchain
description: Use when working on a project's container layer - adding or editing a Dockerfile, picking a base image, wiring a container engine into a build, or debugging an image that runs locally but fails in CI. Carries the cross-repo defaults and the end state a converged repo reaches.
---

# Containerized Toolchain

The image is the environment. A project's checks run inside it on a laptop and in
GitHub Actions alike, so "works on my machine" stops being a thing that can be true.

## End state

A converged repo:

- Runs every check and build inside one image; the host supplies a container engine
  and go-task, nothing else
- Picks its engine at runtime -- Apple `container` on macOS when its daemon is up,
  Docker everywhere else -- from one image that runs on arm64 and amd64
- Builds that image from a `Dockerfile` in the repo, so the environment is reviewable
- Passes secrets in by name, never as a value on a command line
- Leaves files written into the mounted repo owned by the caller, not by root
- Honors `ENGINE=docker` so a CI failure reproduces locally

Auditing a repo untouched for months: walk that list. The first three are usually
intact. The last three are where drift hides.

## Engine detection

Byte-identical in every repo that has one. It belongs in `vars:`:

    ENGINE:
      sh: |
        if [ -n "$ENGINE" ]; then echo "$ENGINE"
        elif command -v container >/dev/null 2>&1 && container system status >/dev/null 2>&1; then echo container
        elif command -v docker >/dev/null 2>&1; then echo docker
        elif command -v container >/dev/null 2>&1; then echo container
        else echo docker
        fi

Probing the daemon rather than just the binary is the whole point: a `container` binary
with a stopped apiserver fails every build with an opaque XPC error while a working
Docker sits idle beside it. The trailing branches pick an installed-but-unhealthy engine
on purpose, so the caller gets that engine's own diagnostic instead of "command not
found". An explicit `ENGINE` wins, which is how a CI failure gets reproduced locally.

## Base image

Alpine when the image wraps static binaries -- it only has to supply a shell, a CA
bundle, and whatever those binaries shell out to. Five megabytes beats Debian's hundred
for something that holds Go binaries and nothing else.

Alpine is not the rule when the toolchain *is* the image. TeX Live, a language runtime,
anything with a maintained official image: take the official one. Rebuilding a large
toolchain onto an Alpine base by hand costs more than the base image saves.

Either way, a third-party base needs its digest pinned --
`FROM texlive/texlive:latest-small@sha256:...`. A bare tag silently changes under you
between a laptop build and a CI build, which is the exact failure the image exists to
prevent.

## Architecture

Read the architecture from the image itself, never from a build arg:

    RUN set -eu; \
        case "$(apk --print-arch)" in \
          x86_64)  arch=amd64 ;; \
          aarch64) arch=arm64 ;; \
          *) echo "unsupported architecture: $(apk --print-arch)" >&2; exit 1 ;; \
        esac; \
        curl -fsSL -o /tmp/tool.tar.gz "https://.../tool_linux_${arch}.tar.gz"

BuildKit sets `TARGETARCH`; Apple `container` does not. A Dockerfile reading `TARGETARCH`
with a default therefore installs amd64 binaries into an arm64 image -- fine on GitHub's
amd64 runners, "Exec format error" on an Apple Silicon laptop. Do not reintroduce inside
the image's own build the divergence the image exists to eliminate.

`apk` reports `x86_64`/`aarch64` while most projects publish under `amd64`/`arm64`. Fail
loudly on anything unrecognized rather than guessing a default.

## The run task

One task runs anything inside the image with the repo mounted:

    run:
      desc: 'Run any command in the toolbox image, e.g. task run -- task validate'
      cmds:
        - >-
          {{.ENGINE}} run --rm -i $(test -t 0 && test -t 1 && echo -t || true)
          --user $(id -u):$(id -g)
          -v "{{.ROOT_DIR}}":/work -w /work
          -e HOME=/tmp
          -e SOME_TOKEN
          {{.IMAGE}} {{.CLI_ARGS}}

Every flag earns its place:

- `--user $(id -u):$(id -g)` -- whatever the container writes lands in the mounted repo.
  Without this it comes out owned by root and the next local command cannot touch it.
- `-e HOME=/tmp` -- that uid has no home directory in the image, and caches need
  somewhere writable.
- `-t` only when both ends are a terminal. The engines reject `-i -t` without one, which
  breaks the task under CI and under any pipe.
- `-e NAME` with no `=value` -- the variable crosses by name, so the value never reaches
  a command line, a process listing, or a task's echoed output.

Secrets resolve at the outer edge, into the process and never to disk:

    op:
      desc: 'Run a task in the toolbox with secrets from 1Password'
      cmds:
        - op run --env-file=op.env -- task run -- {{.CLI_ARGS}}

`op.env` holds `op://` references, not values, so it is safe to commit.

## Image builds

Image presence is the freshness check. Gate the build on it so a converged run is a
no-op:

    image:
      desc: Build the toolbox image
      run: once
      status:
        - '{{.ENGINE}} image inspect {{.IMAGE}} >/dev/null 2>&1'
      cmds:
        - '{{.ENGINE}} build -t {{.IMAGE}} docker/'

That means a Dockerfile edit does not trigger a rebuild on its own. Give the repo a
clean task that removes the image, and say so in a comment above `status:`.
