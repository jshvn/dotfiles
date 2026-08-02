# install

Install-engine machinery. The scripts and helpers that `bootstrap.zsh` (at the
repo root) and `task install` (root `Taskfile.yml`) call into: the manifest
resolver, the messages library every taskfile sources, the per-machine
Brewfile composer, and the smoke-test runners.

## Key files, by pipeline stage

Every script here belongs to exactly one stage. A new script must name its
stage in this list.

### lib (sourced, never executed)

- `messages.zsh` -- Colored-output library exposing `info`, `success`,
  `warn`, `error`, `check`, `cross`, `header`, `step`, `debug`. Sourced
  by task `cmds:` blocks via the `{{.DOTFILES_MESSAGES}}` template var.
  Self-bootstrapping under `set -u` via the `${DOTFILES_MESSAGES_LOADED:-}`
  guard -- callers source it with a bare `source` line (see the `set -u
  contract` block at the top of the file).
- `compose-settings.zsh` -- Single source of truth for the settings-compose
  algorithm shared by `claude:settings-compose` and `claude:audit`.

### evaluate (manifests -> resolved.json)

- `resolver.zsh` -- Validates the active machine's
  `manifests/machines/<name>.toml` against the `manifests/features.toml`
  registry and the `manifests/base.toml` base tier, then compiles it into
  `$XDG_STATE_HOME/dotfiles/resolved.json` (three-tier package union +
  feature-map materialization). Atomic write via `mktemp + mv`. Every downstream task
  reads `resolved.json` through go-task `fromJson`; no taskfile parses TOML
  directly.

### realize (resolved.json + repo source -> build artifacts)

- `compose-brewfile.zsh` -- Reads `resolved.json`'s typed buckets
  (`packages.brew.{formulae,casks,mas}`, already folded
  in by `resolver.zsh` from the base tier and enabled feature flags) and writes
  a composed `$XDG_CACHE_HOME/dotfiles/Brewfile` (atomic mktemp+mv).
  Invoked by `taskfiles/packages.yml :: packages:compose` and indirectly
  by `packages:install`.

### operate (drift detection, addon lifecycle, repo hygiene)

- `claude-addons.zsh` -- Install / upgrade / remove / list / validate the
  third-party Claude addons declared in `manifests/claude-addons/<name>.toml`
  and selected per machine via `[claude].addons`. Invoked by
  `taskfiles/claude-addons.yml`.
- `lint-rules.zsh` -- Shared lint detectors used by both the production scan
  (`taskfiles/lint.yml :: lint:taskfile`) and the fixture self-test
  (`lint:test-fixtures`), so one implementation backs both.
- `links-audit-scan.zsh` -- Orphan-detection logic for `task links:audit`.
  Reads expected symlink targets on stdin and prints repo-targeted links that
  are dangling or unexpected under the scan roots.
- `repo-sync.zsh` -- Fast-forward pull run before install (the `update` alias
  runs this, then `task install`). Fetches then fast-forwards the current
  branch; never merges or rebases. Invoked by `taskfiles/repo.yml :: repo:sync`.

### tests (`install/tests/`)

- `hooks.zsh` -- Smoke-test runner for the four named Claude hooks
  (`secret-scan`, `no-emojis`, `no-ai-comments`, `agent-transparency`).
  Invoked by `taskfiles/test.yml :: test:hooks`; exit code is the count of
  scenario failures (0 == all pass).
- `links-audit.zsh` -- Smoke test for `links-audit-scan.zsh` against a
  throwaway repo + config tree. Invoked by `test:links-audit`.
- `repo-sync.zsh` -- Smoke test exercising every guard branch of
  `repo-sync.zsh` against throwaway git repos. Invoked by `test:repo-sync`.
- `shell-startup.zsh` -- Smoke test for the zsh startup files (`.zshenv`,
  `.zprofile`, `.zshrc`, `.zlogin`, `.zlogout`). Invoked by
  `test:shell-startup`.

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
- **A new Brew package.** Pick the tier. An application you want on a machine
  goes in that machine's own `[packages]` table. Tooling a feature needs goes
  in `[<flag>.packages]` in `manifests/features.toml`, so enabling the flag
  guarantees it. Something every machine needs to run these dotfiles goes in
  `manifests/base.toml`. All three use the identical bucket shape.

## References

- `../docs/MANIFEST.md` -- manifest schema and package-union semantics
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
  `tests/hooks.zsh`.
- `../CLAUDE.md` -- v2 conventions (file-header comment blocks,
  `set -euo pipefail` on every executable `.zsh`, no AI attribution).
