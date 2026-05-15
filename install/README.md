# install

Install-engine machinery. The scripts and helpers that `bootstrap.zsh` (at the
repo root) and `task install` (root `Taskfile.yml`) call into: the manifest
resolver, the messages library every taskfile sources, and the cutover-gate
precondition that blocks `task install` until a machine is explicitly selected.
Phase 5 will move the Brewfile bundles out of this directory into
`packages/<purpose>.rb`.

## Key files

- `resolver.zsh` -- Phase 1 (MFST-04). Compiles `manifests/defaults.toml`
  plus the active machine's `manifests/machines/<name>.toml` into
  `$XDG_STATE_HOME/dotfiles/resolved.json` via yq deep-merge
  (`. as $i ireduce ({}; . * $i)`). Atomic write via `mktemp + mv`. Every
  downstream task reads `resolved.json` through go-task `fromJson`; no
  taskfile parses TOML directly.
- `messages.zsh` -- Phase 1 baseline. Colored-output library exposing
  `info`, `success`, `warn`, `error`, `check`, `cross`. Sourced by task
  `cmds:` blocks via the `{{.DOTFILES_MESSAGES}}` template var. Idempotent
  via the `DOTFILES_MESSAGES_LOADED` guard so double-sourcing under
  `set -u` is safe.
- `cutover-gate.zsh` -- Phase 2 (BTSP-06 / D-12). Reads
  `$XDG_STATE_HOME/dotfiles/machine` and the `cutover-ack` sentinel; exits
  non-zero with an actionable error when no machine is selected or the
  sentinel is missing. Invoked as a precondition in `Taskfile.yml` so every
  `task install` run starts from an explicit machine identity (no hostname
  inference, ever).
- `Brewfile.rb`, `Brewfile-personal.rb`, `Brewfile-server.rb`,
  `Brewfile-work.rb` -- v1 transitional state. Phase 5 (PKGS-01..05)
  refactors these into per-purpose bundles under `packages/<purpose>.rb`
  (`core`, `gui`, `dev`, `ops`, `personal`). Do NOT add new
  profile-suffixed Brewfiles here -- the v2 model is purpose-named bundles
  composed by the manifest, not profile-suffixed files.

## Adding a pattern

- **A new install-engine script.** Create `install/<name>.zsh`. Start with
  the standard shebang plus `set -euo pipefail` if the file is executable
  (LINT-04 enforces; library files sourced from taskfiles are exempt and
  must still guard double-source via a `<NAME>_LOADED` flag). Add a
  file-header comment block per `resolver.zsh` / `cutover-gate.zsh` shape
  naming purpose, callers, reads/writes, and side effects. Wire the
  script into a task by referencing it as
  `{{.DOTFILEDIR}}/install/<name>.zsh` from the appropriate
  `taskfiles/<concern>.yml`.
- **A new task-helper function.** If the helper produces user-facing
  output, add it to `messages.zsh` and bump the same `_LOADED` guard.
  Otherwise create a new file under `install/` following the same
  conventions.
- **A new Brew package.** Do NOT edit the Brewfiles here in Phase 3 scope
  -- wait for Phase 5. Once Phase 5 lands, add packages to
  `packages/<purpose>.rb` (named by role, not by profile) or to the
  machine manifest's `extra_packages` array for one-offs.

## References

- `../docs/MANIFEST.md` -- manifest schema and deep-merge semantics
  consumed by `resolver.zsh`.
- `../docs/SECURITY.md` -- bootstrap trust chain (Phase 2 BTSP-05 /
  DOCS-07).
- `../taskfiles/manifest.yml` -- the `manifest:resolve`,
  `manifest:validate`, `manifest:show`, and `manifest:test` tasks that
  invoke `resolver.zsh`.
- `../CLAUDE.md` -- v2 conventions (file-header comment blocks,
  `set -euo pipefail` on every executable `.zsh`, no AI attribution).
- `../.planning/REQUIREMENTS.md` -- MFST-04, BTSP-01..06, LINT-04,
  DOCS-02 traceability.

Satisfies DOCS-02 for install/.
