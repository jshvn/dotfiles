# install

Install-engine machinery. The scripts and helpers that `bootstrap.zsh` (at the
repo root) and `task install` (root `Taskfile.yml`) call into: the manifest
resolver, the messages library every taskfile sources, the per-machine
Brewfile composer, and the Tier-3 hook smoke-test runner.

## Key files

- `resolver.zsh` -- Compiles `manifests/defaults.toml` plus the active
  machine's `manifests/machines/<name>.toml` into
  `$XDG_STATE_HOME/dotfiles/resolved.json` via yq deep-merge
  (`. as $i ireduce ({}; . * $i)`). Atomic write via `mktemp + mv`. Every
  downstream task reads `resolved.json` through go-task `fromJson`; no
  taskfile parses TOML directly.
- `messages.zsh` -- Colored-output library exposing `info`, `success`,
  `warn`, `error`, `check`, `cross`, `header`, `step`, `debug`. Sourced
  by task `cmds:` blocks via the `{{.DOTFILES_MESSAGES}}` template var.
  Self-bootstrapping under `set -u` via the `${DOTFILES_MESSAGES_LOADED:-}`
  guard -- callers source it with a bare `source` line (see the `set -u
  contract` block at the top of the file).
- `compose-brewfile.zsh` -- Reads `resolved.json` plus
  `packages/<bundle>.rb` files and writes a composed
  `$XDG_CACHE_HOME/dotfiles/Brewfile` (atomic mktemp+mv). Invoked by
  `taskfiles/packages.yml :: packages:compose` and indirectly by
  `packages:install`.
- `test-hooks.zsh` -- Tier-3 smoke-test runner for the four named Claude
  hooks (`secret-scan`, `no-emojis`, `no-ai-comments`, `agent-transparency`).
  Invoked by `taskfiles/test.yml :: test:hooks`; exit code is the count of
  scenario failures (0 == all pass).

## Adding a pattern

- **A new install-engine script.** Create `install/<name>.zsh`. Start with
  the standard shebang plus `set -euo pipefail` if the file is executable
  (LINT-04 enforces; library files sourced from taskfiles are exempt and
  must still guard double-source via a `<NAME>_LOADED` flag). Add a
  file-header comment block per `resolver.zsh` / `compose-brewfile.zsh`
  shape naming purpose, callers, reads/writes, and side effects. Wire the
  script into a task by referencing it as
  `{{.DOTFILEDIR}}/install/<name>.zsh` from the appropriate
  `taskfiles/<concern>.yml`.
- **A new task-helper function.** If the helper produces user-facing
  output, add it to `messages.zsh` -- the existing self-bootstrap contract
  applies to new functions automatically. Otherwise create a new file
  under `install/` following the same conventions.
- **A new Brew package.** Add packages to `packages/<purpose>.rb` (named
  by role, not by profile) or to the machine manifest's `extra_packages`
  typed sub-table (`formulae` / `casks` / `mas`) for one-offs.

## References

- `../docs/MANIFEST.md` -- manifest schema and deep-merge semantics
  consumed by `resolver.zsh`.
- `../docs/SECURITY.md` -- bootstrap trust chain (Phase 2 BTSP-05 /
  DOCS-07).
- `../taskfiles/manifest.yml` -- the `manifest:resolve`,
  `manifest:validate`, and `manifest:show` tasks that invoke
  `resolver.zsh`.
- `../taskfiles/packages.yml` -- the `packages:compose`,
  `packages:install`, and `packages:verify` tasks that invoke
  `compose-brewfile.zsh`.
- `../taskfiles/test.yml` -- the `test:hooks` task that invokes
  `test-hooks.zsh`.
- `../CLAUDE.md` -- v2 conventions (file-header comment blocks,
  `set -euo pipefail` on every executable `.zsh`, no AI attribution).
- `../.planning/REQUIREMENTS.md` -- MFST-04, BTSP-01..06, LINT-04,
  DOCS-02 traceability.

Satisfies DOCS-02 for install/.
