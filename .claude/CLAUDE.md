# Dotfiles Project

## Overview

macOS dotfiles managed with go-task, symlinks, and XDG base directory spec.
Per-machine TOML manifests under `manifests/machines/<name>.toml` inherit from
`manifests/defaults.toml`. Active machine selection is stored at
`$XDG_STATE_HOME/dotfiles/machine` and exported as `$DOTFILES_MACHINE`. No
hostname inference, no profile suffixes, no per-profile env var. Schema
reference: `docs/MANIFEST.md`.

## Quick Reference

- Fresh install: `./bootstrap.zsh`
- Re-install / update: `task install` (D-10: install IS update; single canonical pipeline)
- Validate: `task validate`
- Show tasks: `task --list`
- Set machine: `task setup -- <machine-name>` (BTSP-04; writes `$XDG_STATE_HOME/dotfiles/machine`)
- Show manifest: `task show:manifest` (prints the post-merge structure for debugging)

## Structure

- `Taskfile.yml` -- root orchestration; defines global vars (XDG paths,
  `ZDOTDIR`, `DOTFILEDIR`, `HOMEBREW_PREFIX`, `DOTFILES_MESSAGES`,
  `RESOLVED_JSON_PATH`, `MANIFEST`) and includes per-concern taskfiles.
- `taskfiles/<concern>.yml` -- modular taskfiles (helpers, manifest, lint,
  links, shell, brew, claude, macos). See `taskfiles/README.md`.
- `taskfiles/helpers.yml` -- reusable `_:safe-link`, `_:check-link`,
  `_:check-dir`, `_:check-file`, `_:check-command`.
- `manifests/defaults.toml` -- shared baseline (`[features]`, default
  `packages.brew.bundles`, identity placeholders). Every machine TOML
  inherits via deep-merge.
- `manifests/machines/<name>.toml` -- per-machine declaration: identity,
  features, package bundles, `extra_packages`. Compiled into
  `$XDG_STATE_HOME/dotfiles/resolved.json` by the resolver.
- `install/` -- install engine machinery (`resolver.zsh`, `messages.zsh`,
  `cutover-gate.zsh`). See `install/README.md`.
- `shell/` -- flat shell layout (`.zshenv`, `.zprofile`, `.zshrc`,
  `.zlogin`, `.zlogout`, `theme.zsh`); aliases under
  `shell/aliases/<topic>.zsh`; functions under `shell/functions/<name>.zsh`.
  See `shell/README.md`.
- `configs/<tool>/` -- tool configs (Phase 7 moves
  ghostty/glow/trippy/tlrc/conda/eza/motd in).
- `claude/` -- Claude Code config (`CLAUDE.md`, `settings.json`, `hooks/`,
  `agents/`, `commands/`, `skills/`). See `claude/README.md`.
- `packages/<purpose>.rb` -- per-purpose Brewfile bundles (Phase 5 ships;
  currently transitional Brewfiles live under `install/`).
- `os/defaults/<concern>.zsh` -- macOS defaults split by concern (Phase 6).
- `identity/git/`, `identity/ssh/` -- git + ssh per-machine identity (Phase 4).

## Conventions

- All hooks are zsh scripts with `set -euo pipefail`. They use GNU grep
  (`ggrep`) from Homebrew.
- Symlinks use the `_:safe-link` helper, which creates parent dirs and uses
  `ln -sfn` for idempotent re-linking. No bare `ln -s` outside
  `taskfiles/helpers.yml` (LINT-03b).
- Aliases use `$(command -v cmd)` for Homebrew tool resolution.
- Functions: one per file, `.zsh` extension, no output on source, idempotent.
- Path resolution: `BASH_SOURCE` / `${(%):-%N}` symlink traversal. Never
  hardcode repo paths.
- Detect the Homebrew prefix by `uname -m` architecture. Never hardcode
  `/opt/homebrew` or `/usr/local`. Use `$HOMEBREW_PREFIX` (shell context)
  or `{{.HOMEBREW_PREFIX}}` (task context).
- Tasks use `status:` checks for idempotency (LINT-01). Status blocks use
  `{{.X}}` template vars only -- never `$X` shell vars (LINT-02; the v1
  `macos:shell:145` bug class). Aggregator tasks whose `cmds:` are entirely
  `task:` delegations omit `status:` and use the
  `# lint-allow: cmds-without-status` marker; idempotency lives inside each
  sub-task.
- `install/messages.zsh` must be sourced in task commands that need colored
  output via `{{.DOTFILES_MESSAGES}}`.
- Kebab-case feature keys need `index` access in go-template:
  `{{if index .MANIFEST.features "one-password-ssh"}}`. Snake_case keys can
  use dot access (`{{.MANIFEST.identity.git}}`).
- No AI attribution in commits or source -- no attribution trailers, no
  machine-authorship comments. Hooks enforce this at commit time.
- No emojis in any file -- markdown included. Project convention is
  stricter than the global rule.

## Adding Things

- **Function:** `shell/functions/<name>.zsh` (filename equals the function
  name; flat layout, no subdirectories). See `shell/README.md`.
- **Alias:** `shell/aliases/<topic>.zsh` (one topic per file; flat). Gated
  aliases use `_dotfiles_feature <name>` either via a wrapper function
  (D-07) or as a source-time `return 0` guard for bulk-alias loops (D-08).
- **Brew package:** Phase 5 ships `packages/<purpose>.rb` (`core`, `gui`,
  `dev`, `ops`, `personal`); currently transitional Brewfiles live in
  `install/`. Per-machine extras via `extra_packages` in the machine TOML.
- **Symlink:** add a `_:safe-link` entry in `taskfiles/links.yml` + the
  matching `test -L` line in the sub-task's `status:` block + a
  `_:check-link` invocation in `links:validate`.
- **Tool config:** add to `configs/<tool>/`; create the symlink in
  `taskfiles/links.yml`.
- **Machine:** create `manifests/machines/<name>.toml`, then
  `task setup -- <name>`.
- **Feature flag:** add the kebab-case key to `manifests/defaults.toml`
  `[features]` (default `false`). Enable in the relevant machine TOMLs.
  Consumers call `_dotfiles_feature <key>` in shell or
  `index .MANIFEST.features "key"` in tasks.

## Zsh Startup Order

1. `/etc/zshenv` -- sets `ZDOTDIR`.
2. `.zshenv` -- XDG vars, `DOTFILES_MACHINE` (read from
   `$XDG_STATE_HOME/dotfiles/machine`), `EDITOR`, `LANG`. Always sourced;
   must stay minimal (non-interactive contexts source this too).
3. `.zprofile` -- `brew shellenv`, `SSH_AUTH_SOCK` gated on
   `features.one-password-ssh` from `resolved.json` (login only).
4. `.zshrc` -- antigen plugin load (sources OMZ lib/* + bundles),
   `compinit` daily-rebuild cache (SHEL-10), theme, functions glob,
   aliases glob (interactive only).
5. `.zlogin` -- MOTD dispatch (always-fresh `tput cols` render) (login only).
6. `.zlogout` -- history flush via `fc -W` (login exit).

## Safety

- macOS is the v1 target. Linux support is deferred to v2+.
- Only use `sudo` when required; document why.
- Never commit private keys. `identity/ssh/keys/` contains public keys
  only (Phase 4).
- Manifest is the source of truth -- no hostname inference, no env-var
  sniffing. Feature gates always read `_dotfiles_feature <key>` (shell) or
  `resolved.json` via jq / `fromJson` (taskfiles).
