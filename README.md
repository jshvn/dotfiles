# dotfiles

## What This Is

macOS dotfiles managed with go-task, manifest-driven per-machine
configuration via TOML, and an XDG base directory layout throughout.
New contributors and AI agents working on this repo should read this
README and `docs/MANIFEST.md` to understand the v2 manifest model.

A single TOML file per machine under `manifests/machines/<name>.toml`
inherits from a shared baseline at `manifests/defaults.toml`. The
resolver (`install/resolver.zsh`) deep-merges the two TOMLs and compiles
the result to `$XDG_STATE_HOME/dotfiles/resolved.json` once per setup;
every go-task task reads from that JSON via `fromJson`. Active machine
selection is stored at `$XDG_STATE_HOME/dotfiles/machine` and set
explicitly via `task setup -- <machine-name>`. There is no hostname
inference, no environment variable to remember, and no hidden profile
branching anywhere in the pipeline. The complete schema for both TOML
files (sections, types, deep-merge rules, worked examples) lives in
`docs/MANIFEST.md`.

## Fresh Machine Setup

Run these commands in order on a clean Mac. `bootstrap.zsh` acquires
Homebrew, go-task, and yq and then prints the next-step hint.
`task setup` writes the active machine name to
`$XDG_STATE_HOME/dotfiles/machine`; `task install` runs the full install
pipeline (links + packages + claude + macos + verify + reconcile).

```zsh
git clone <repo-url>
./bootstrap.zsh
task setup -- <machine-name>
task install
```

For the list of accepted `<machine-name>` values and the per-machine
purpose, hardware, and special-handling notes, see `docs/MACHINES.md`.

## Where to Add Things

| Adding | Where | Naming |
|--------|-------|--------|
| An alias | `shell/aliases/<topic>.zsh` | kebab-case topic; one topic per file; flat (no subdir) |
| A function | `shell/functions/<name>.zsh` | filename equals function name; lowercase |
| A new machine | `manifests/machines/<name>.toml` + `task setup -- <name>` | kebab-case |
| A brew package | `packages/<purpose>.rb` (or `extra_packages` in the machine manifest for one-offs) | by purpose, not by machine |
| A macOS defaults concern | `os/defaults/<concern>.zsh` + feature flag in `defaults.toml` | one concern per file |
| A feature flag | `manifests/defaults.toml [features]` block + consuming task in the appropriate taskfile | kebab-case key |
| A tool config | `configs/<tool>/` + symlink entry in `taskfiles/links.yml` | use the tool's expected config filename |
| A Claude hook | `claude/hooks/<name>.zsh` + entry in `claude/hooks/hooks.json` | kebab-case |

## Documentation

- `docs/MANIFEST.md` -- manifest schema, inheritance rules, worked examples
- `docs/SECURITY.md` -- bootstrap trust chain and SSH key handling
- `docs/MACHINES.md` -- per-machine purpose, hardware, and role narrative
- `.claude/CLAUDE.md` -- Claude Code project rules for working in this repo
