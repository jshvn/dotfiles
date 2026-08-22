# Dotfiles v2 -- Project Instructions for AI Agents

## What This Is

Manifest-model dotfiles for macOS (Apple Silicon and Intel). Each machine is described by one
self-contained TOML at `manifests/machines/<name>.toml`, validated against the feature-flag
registry `manifests/features.toml`, and compiled by `install/resolver.zsh` into a JSON cache
that every go-task task reads. No profile suffixes, no hostname inference, no hidden branching.

The pipeline runs three stages: evaluate (resolver -> `resolved.json`), realize (compose ->
`$XDG_STATE_HOME/dotfiles/build/`), activate (`task install` -> the live system).

| Concept | Location |
|---------|----------|
| Feature-flag registry | `manifests/features.toml` |
| Per-machine declaration | `manifests/machines/<name>.toml` |
| Unconditional package tier | `manifests/base.toml` |
| Compiled output (machine-local) | `$XDG_STATE_HOME/dotfiles/resolved.json` |
| Materialized desired state (machine-local) | `$XDG_STATE_HOME/dotfiles/build/` |
| Active machine name (machine-local) | `$XDG_STATE_HOME/dotfiles/machine` |

## Finding Things

- Manifest schema: `docs/MANIFEST.md`. Claude addon schema: `docs/CLAUDE-ADDONS.md`.
- Locked decisions, scope boundaries, performance/security constraints: `docs/DECISIONS.md`.
  Revisit only with new evidence.
- Every top-level concept directory has a README saying what belongs there and how to name it.
- Operator surface: the lifecycle commands (`install`, `setup`, `validate`, `test`, `lint`,
  `audit`, `diff`, `report`) plus `<domain>:<verb>` diagnostics (`show`, `audit`, `diff`) and
  `packages:vulns` (OSV.dev scan of the declared set). Bare `task`
  prints the banner; `task --list` the full graph. Per-component install/validate tasks are
  internal pipeline steps, not operator commands.
- Verifying a change: use the `verifying-dotfiles-changes` skill (change type to exact
  commands, five-tier model, one-check rule).

## Gotchas

What the file system will not tell you:

- Taskfiles read `resolved.json` (preloaded as `{{.MANIFEST}}`), never TOML. TOML parsing
  lives only in `install/resolver.zsh`.
- Kebab-case feature keys need the `index` form -- `{{if index .MANIFEST.features
  "one-password-ssh"}}` -- because `-` breaks Go-template dot-access at parse time.
  Snake_case keys (`identity.git`, `meta.description`) take dot-access as usual.
- `status:` blocks evaluate before shell context exists: `{{.X}}` template vars only, never
  `$X` (empty there; the task re-runs forever). Every install task has a `status:` block
  returning 0 when converged.
- The repo tree holds source only -- no generated file is tracked. `settings.json` is composed
  from `claude/settings.d/*.json` plus `$XDG_STATE_HOME/dotfiles/settings.d/*.json` into
  `$XDG_STATE_HOME/dotfiles/build/settings.json`, then installed onto
  `$XDG_CONFIG_HOME/claude/settings.json` as a real file. Edit fragments and re-run
  `task install`; never hand-edit the live file, and never register a hook there directly.
  Compose reads back exactly these CLI-managed keys and no others: `enabledPlugins`,
  `extraKnownMarketplaces`, `model`, `tui`. `task claude:audit` reports drift.
- A machine's `[features]` must account for every registry flag applicable to its `os` in
  either `enabled` or `disabled`; an unaccounted flag is a hard `task setup` error. A flag
  whose `platforms` excludes the machine's os is inapplicable and appears in neither list.
  Cross-field rules (e.g. identity overlays carrying `# capability:` sentinels require the
  matching feature) live in `validate_manifest` in `install/resolver.zsh`.
- Symlinks only via `_:safe-link` (`taskfiles/helpers.yml`); bare `ln -s` fails LINT-03b.
  Machine-local links that land in the working tree go in `.git/info/exclude`, not
  `.gitignore`.
- No hardcoded `/opt/homebrew` or `/usr/local`: `$HOMEBREW_PREFIX` (shell) or
  `{{.HOMEBREW_PREFIX}}` (task), resolved in the root Taskfile (LINT-10).
- Repo root is the go-task built-in `{{.ROOT_DIR}}`; scripts receive it as the `DOTFILEDIR`
  env var at invocation. No custom repo-root variable.
- Machine identity is explicit (`task setup -- <name>`); never infer from hostname or any
  environment heuristic.
- Executable `.zsh`: `set -euo pipefail` (LINT-04), the three-label header banner
  (Purpose / Depends on / Side effects between `# ===` 77-char rules, LINT-12), errors to
  stderr via `install/messages.zsh`. XDG paths come from `shell/.zshenv` and `{{.XDG_*}}`.
- Zsh startup order: `.zshenv` -> `.zprofile` (brew shellenv, 1Password socket) -> `.zshrc`
  (antidote plugins, theme, functions, aliases) -> `.zlogin` (MOTD) -> `.zlogout`.
- Lint rules: catalogue table in `taskfiles/README.md`, rule bodies in `taskfiles/lint.yml`;
  `# LINT-NN:` comments cite them. LINT-01, LINT-06, and LINT-09 are retired numbers -- never
  reuse them.
- Third-party Claude addons are declarative: `manifests/claude-addons/<name>.toml` plus the
  machine's `[claude].addons` list; they install inside `task install`. Machine-generated
  addon fragments live in the state tree, never the repo.
- One concept per file, flat directories: one alias topic / function / taskfile / machine
  manifest / defaults concern per file; no subdirectories under `shell/aliases/` and no
  `os/darwin/` nesting. The one nesting that exists is `shell/functions/helpers/`, holding
  the private `_dotfiles_*` primitives so the flat directory above it lists only what you
  would run at a prompt; `.zshrc` sources helpers first.
- Packages arrive in three tiers: `manifests/base.toml` (unconditional, no machine names it),
  `[<flag>.packages]` in the registry (a concern owns its tooling), and a machine's
  `[packages]` (free choices only). Listing something base or an enabled flag already provides
  is a hard resolver error.
- Tests live at `<domain>/tests/`; `task test` is the single aggregator.
- No AI attribution and no emojis anywhere, markdown included (hooks enforce both). No
  private keys in the repo; `identity/ssh/keys/` holds public keys only.
