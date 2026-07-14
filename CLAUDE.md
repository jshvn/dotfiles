# Dotfiles v2 — Project Instructions for AI Agents

## What This Is

These dotfiles use the manifest model: each machine is described by a single TOML file in
`manifests/machines/<name>.toml` that inherits from a shared `manifests/defaults.toml`. The
resolver compiles them into a JSON cache that every go-task task reads — no profile suffixes,
no hostname inference, no hidden branching. macOS only in v1 (Apple Silicon and Intel).

## The Manifest Model (the keystone)

| Concept | Location |
|---------|----------|
| Shared baseline | `manifests/defaults.toml` |
| Per-machine declaration | `manifests/machines/<name>.toml` |
| Compiled output (machine-local) | `$XDG_STATE_HOME/dotfiles/resolved.json` |
| Active machine name (machine-local) | `$XDG_STATE_HOME/dotfiles/machine` |

Schema reference: `docs/MANIFEST.md`

## Common Tasks (operator surface)

Bare `task` prints the curated two-tier banner. The canonical operator
surface is six top-level lifecycle commands:

| Command          | Purpose                                                      |
|------------------|--------------------------------------------------------------|
| `task install`   | Install dotfiles + refresh brew, upgrade declared packages   |
| `task setup`     | Set the active machine: `task setup -- <machine-name>`       |
| `task validate`  | Validate full installation state                             |
| `task test`      | Run all smoke tests                                          |
| `task lint`      | Run all lint checks                                          |
| `task audit`     | Detect drift across all domains (read-only aggregate)        |

Diagnostics follow a domain-first grammar: `<domain>:<verb>` (pick a domain,
pick a verb). Bare verbs aggregate across all domains.

- `task <domain>:show` -- inspect current state (`manifest:show`, `claude:show`,
  `claude-addons:show`, `hostname:show`); bare `task show` lists inspectable domains.
- `task <domain>:audit` -- detect drift (`manifest:audit`, `packages:audit`,
  `links:audit`, `claude:audit`, `claude-addons:audit`); bare `task audit` runs them all.

`task --list` shows the full curated graph (every public task; internals
hidden). Per-component install / validate tasks are intentionally
internal -- they are pipeline steps, not operator commands.

## Rules

### Manifests are the source of truth for install state

Never infer state from hostname. Never branch on a filename suffix. v2 has no profile variable —
there is only a machine name. When you need to know whether a machine wants a feature, read
`resolved.json`; it is already loaded as `{{.MANIFEST}}` in every taskfile via `ref: 'fromJson .MANIFEST_JSON'`.

Cross-field validation: the resolver enforces conditional rules across manifest sections
(e.g., `identity.ssh in {personal, work}` requires `features.one-password-ssh = true`;
`identity.git in {personal, work}` requires `features.one-password-signing = true`). Failing
rules surface at `task setup` time with a clear error from `install/resolver.zsh`. Add new
rules to the `validate_manifest` block in `resolver.zsh`.

### One concept per file

- One alias topic per `shell/aliases/<topic>.zsh`
- One function per `shell/functions/<name>.zsh`
- One taskfile per concern (`taskfiles/<concern>.yml`)
- One machine manifest per machine (`manifests/machines/<name>.toml`)
- One shared bundle per purpose (`manifests/bundles/<purpose>.toml`)
- One macOS defaults concern per file (`os/defaults/<concern>.zsh`)

### Flat directories

No subdirectories inside `shell/aliases/` — all alias files live at the top of that directory.
No `manifests/bundles/brew/` subdirectory; bundle TOMLs are flat under `manifests/bundles/`. No
`os/darwin/` nesting. The project targets macOS only, so the platform dimension collapses to a
flat layout.

### kebab-case feature names need `index` access

Go-template dot-access (`.MANIFEST.features.one-password-ssh`) fails at parse time because `-` is
not a valid identifier character. Any feature key that contains a hyphen **must** use the `index`
form:

```yaml
# Wrong — parser rejects this
{{if .MANIFEST.features.one-password-ssh}}

# Correct — use index for all kebab-case feature keys
{{if index .MANIFEST.features "one-password-ssh"}}
```

Snake_case keys (e.g., `identity.git`, `meta.description`) work with dot access as usual.

### Lint rule catalogue (LINT-02..12)

In-code `# LINT-NN:` citations reference this catalogue. The rule body lives in
`taskfiles/lint.yml`; this table is the operator-facing summary.

| ID | Scope | What it checks |
|----|-------|----------------|
| LINT-02 | Taskfiles | `status:` uses `{{.X}}` template vars, not `$X` shell vars |
| LINT-03a | Taskfiles | Tasks with `cmds:` have `status:` (or exempt via `internal: true` / all-task-delegates) |
| LINT-03b | Repo-wide | No bare `ln -s` outside `taskfiles/helpers.yml` |
| LINT-04 | Executable .zsh | `set -euo pipefail` in first 30 lines |
| LINT-05 | shell/ + os/ (.zsh only) | Portability-sensitive commands surface as warnings (non-blocking) |
| LINT-07 | All .zsh | `zsh -n` parse-check (Tier-0 syntax) |
| LINT-08 | Root Taskfile.yml | `default:` banner lists every public top-level task |
| LINT-09 | claude/settings.json | Matches the composed output of `claude/settings.d/*.json` + preserved CLI-managed keys |
| LINT-10 | .zsh + .yml repo-wide | No hardcoded `/opt/homebrew` or `/usr/local`; dispatch sites carry `# lint-allow: hardcoded-prefix` |
| LINT-11 | Taskfiles | Kebab-case feature keys use the `index` form, never template dot-access |
| LINT-12 | All .zsh | File-header banner (Purpose / Depends on / Side effects between `# ===` rules) |

LINT-01 and LINT-06 are intentionally absent. The original LINT-01 rule
("every install task has a status: block") was generalized into LINT-03a
during v2 refactoring; the gap is preserved so existing `# LINT-NN:`
citations in code remain unambiguous.

### Every install task has a `status:` block

The `status:` block must return 0 (skip) when the desired state is already present and non-zero
(run) when work is needed. **The block must use template variables (`{{.X}}`), never shell
variables (`$X`)** — shell vars are not in scope during status evaluation. Using `$X` in a
`status:` block causes the task to re-run on every invocation (the v1 `macos:shell:145` bug class).

```yaml
# Wrong — $RESOLVED_JSON_PATH is empty in status context
status:
  - test -f "$RESOLVED_JSON_PATH"

# Correct — template var resolved at task-graph build time
status:
  - test -f "{{.RESOLVED_JSON_PATH}}"
```

### `set -euo pipefail` on every executable `.zsh`

No `set -e` alone. The `-u` flag catches unbound-variable bugs; `-o pipefail` catches failures
in the middle of a pipeline that would otherwise be masked by a successful final command.

### No hardcoded `/opt/homebrew` or `/usr/local`

Detect the Homebrew prefix via `uname -m`-based dispatch. The `HOMEBREW_PREFIX` variable is
already resolved in `Taskfile.yml` and available to every included taskfile. Do not hard-code
the path in scripts — use `$HOMEBREW_PREFIX` (shell context) or `{{.HOMEBREW_PREFIX}}`
(task context).

### Symlinks via `_:safe-link` only

No bare `ln -s` outside `taskfiles/helpers.yml`. The `_:safe-link` helper creates the parent
directory if it does not exist and uses `ln -sfn` for idempotent re-linking. Direct `ln`
calls bypass this guarantee.

### XDG everywhere

| Variable | Default | Purpose |
|----------|---------|---------|
| `$XDG_CONFIG_HOME` | `~/.config` | User configuration |
| `$XDG_DATA_HOME` | `~/.local/share` | Application data |
| `$XDG_STATE_HOME` | `~/.local/state` | Machine-local state (resolved.json, machine name) |
| `$XDG_CACHE_HOME` | `~/.cache` | Caches |

Set in `shell/.zshenv`; available as `{{.XDG_*}}` in taskfiles via the
root `Taskfile.yml` vars block.

### Zsh startup order

`.zshenv` (always sourced — keep minimal) -> `.zprofile` (login only;
`brew shellenv`, 1Password SSH socket) -> `.zshrc` (interactive only;
antidote plugin load from `shell/.zsh_plugins.txt` (use-omz owns deferred
`compinit`), theme, functions, aliases) ->
`.zlogin` (login only; MOTD dispatch) -> `.zlogout` (login exit; history flush).

### `claude/settings.json` is a generated build artifact

Edit `claude/settings.d/*.json` fragments; `task install` recomposes
`claude/settings.json` from them (composition is an internal pipeline step --
`claude:settings-compose` is `internal: true`, so there is no public compose
command to run by hand). Don't hand-edit the generated file.
LINT-09 fails the lint pipeline if `settings.json` drifts from the composed
output (third-party installer wrote keys, manual edit, etc.). The composer
preserves `enabledPlugins`, `extraKnownMarketplaces`, and `model` from the
live file (the first two are managed by the `claude plugin` CLI, `model` by
the `/model` command -- none are owned by fragments).

Repo-owned fragments live at `claude/settings.d/{00-base,10-hooks}.json`.
Each enabled third-party addon with a paired settings template gets its own
`claude/settings.d/99-addon-<name>.json` written during addon install (a
`task install` pipeline step) and deleted by `task claude-addons:remove`. See
`docs/CLAUDE-ADDONS.md`.

### Third-party Claude addons are declarative

The set of third-party Claude addons (marketplace plugins, npx installers)
enabled on a machine is declared in the machine's `[claude].addons` array.
Each name must have a matching `manifests/claude-addons/<name>.toml` declaring
install/upgrade/remove commands, verify probe, file footprint, and optional
settings fragment. Addons install as part of `task install`; the operator
surface for the rest is `task claude-addons:remove` (tear one down) and
`task claude-addons:show` / `claude-addons:audit` (inspect state). The resolver
enforces TOML existence at validation time. See `docs/CLAUDE-ADDONS.md` for the
schema and worked examples.

## Where to Add Things

| Adding | Where | Naming |
|--------|-------|--------|
| An alias | `shell/aliases/<topic>.zsh` | kebab-case topic; one topic per file; flat (no subdir) |
| A function | `shell/functions/<name>.zsh` | filename equals function name; lowercase |
| A new machine | `manifests/machines/<name>.toml` + `task setup -- <name>` | kebab-case |
| A brew package | `manifests/bundles/<purpose>.toml` (or `extra_packages` in the machine manifest for one-offs) | by purpose, not by machine |
| A VSCode extension (or cargo/uv/npm tool) | `[packages.vscode].extensions` (resp. `cargo.crates`, `uv.tools`, `npm.packages`) in `manifests/bundles/dev.toml` or a machine manifest | `publisher.name` id; emitted into the Brewfile via `brew bundle` |
| A macOS defaults concern | `os/defaults/<concern>.zsh` + feature flag in `defaults.toml` | one concern per file |
| A feature flag | `manifests/defaults.toml [features]` block + consuming task in the appropriate taskfile | kebab-case key |
| A tool config | `configs/<tool>/` + symlink entry in `taskfiles/links.yml` | use the tool's expected config filename |
| A Claude hook | `claude/hooks/<name>.zsh` + entry in `claude/settings.d/10-hooks.json` (recomposed on next `task install`) | kebab-case |
| A third-party Claude addon | `manifests/claude-addons/<name>.toml` (+ optional `<name>.fragment.json`) + list in machine manifest's `[claude].addons` | kebab-case |

## Conventions Not Captured Above

- No AI attribution in commits or source — no attribution trailers, no "written by AI" comments,
  anywhere. Hooks enforce this at commit time.
- No emojis in any file — including markdown. Project convention is stricter than the global
  "no emojis in non-markdown" rule.
- File-level comment block at the top of every script: Purpose / Depends on / Side effects
  (3 labels; one `# === ===` 77-char rule above and below; no narrative prose, no examples).
- The file-header banner uses one `# === ===` 77-char rule above and below the 3 labels; no
  mid-file dividers.
- Errors go to stderr (`echo "..." >&2` or `error "..."` from the messages library in
  `install/messages.zsh`).

## Tooling Versions

| Tool | Minimum | Reason |
|------|---------|--------|
| `yq` (mikefarah) | 4.52.1 | Full TOML read/write roundtrip; `. * .` deep-merge operator |
| `go-task` | 3.37 | `ref:` keyword + `fromJson` template function for structured vars |
| `jq` | 1.7 | Sorted-key output (`-S`) for stable fixture diffs; `--argjson` |

## Don't Do

- Don't infer machine identity from `hostname` or any environment heuristic.
- Don't read TOML in a taskfile — read `resolved.json` via `fromJson`. TOML parsing belongs
  in `install/resolver.zsh`.
- Don't create subdirectories under `shell/aliases/` — the v2 layout is flat. No `common/`,
  no `darwin/`, no profile subdirs. All alias files live directly in `shell/aliases/`.
- Don't add a profile-suffixed bundle (e.g., `manifests/bundles/personal.toml`).
  Bundles are named by purpose (`dotfiles.toml`, `cli.toml`, `dotfiles-gui.toml`,
  `dev.toml`, `productivity.toml`, `apps.toml`), not by machine. Per-machine variation
  goes in `manifests/machines/<name>.toml [packages.brew.extra_packages]`.
- Don't bypass `_:safe-link` when creating symlinks.
- Don't use `$VAR` (shell variable) where `{{.VAR}}` (task template variable) is expected —
  especially inside `status:` blocks.
- Don't define a custom `DOTFILEDIR` (or similar) var to hold the repo root. Use the go-task
  built-in `{{.ROOT_DIR}}` — it always resolves to the directory of the topmost Taskfile
  (added v3.15.0; repo minimum is v3.37, so always available) and special vars cannot be
  shadowed by the include-merge leak. Shell scripts that need the repo path receive it via
  the existing `DOTFILEDIR=` env var passed at invocation, e.g.
  `DOTFILEDIR="{{.ROOT_DIR}}" zsh "{{.ROOT_DIR}}/install/foo.zsh"`.
- Don't commit private keys. `identity/ssh/keys/` contains public keys only.
- Don't edit `claude/settings.json` directly. It's a generated build artifact
  recomposed from `claude/settings.d/*.json` fragments during `task install`
  (the internal `claude:settings-compose` step). LINT-09 will fail on drift.
  Edit the fragments instead.
- Don't add a hook by editing `claude/settings.json` directly. Add it to
  `claude/settings.d/10-hooks.json` (repo-owned hooks) or, for a third-party
  addon, to that addon's `manifests/claude-addons/<name>.fragment.json`, then
  re-run `task install` to recompose.

## Out of Scope

Explicit boundaries with reasoning. The point is to prevent re-litigation; revisit only with
new evidence.

- **Linux / Windows / WSL** — macOS-only is a deliberate simplification. All target machines
  (laptops + Mac servers) are macOS. Platform-aware directory split, apt/dnf manifests, and
  Linux bootstrap branch are deferred until a real Linux machine enters scope.
- **Nix / home-manager** — evaluated; conflicts with go-task lock-in, slows AI iteration loop,
  Homebrew still needed for macOS GUI apps via `nix-darwin.homebrew` escape hatch. The
  declarative-manifest goal is already achieved via TOML at lower cost.
- **chezmoi / stow / yadm** — adds a tool dependency that overlaps with go-task; doesn't
  solve the manifest problem.
- **Starship prompt** — the existing alanpeabody-based `theme.zsh` is small, fast, and not on
  life support. Starship would be a behavior change with no problem to solve.
- **fish / nu / bash** — zsh is the chosen shell.
- **Replacing go-task** — locked.
- **Hostname-based machine detection** — burned us before (the legacy `.zprofile`
  literal-hostname check). Explicit `task setup -- <machine>` only.
- **Inline profile branching in shared files** — replaced by manifest-driven feature gates.
- **Auto-detection of identity / capabilities** — the manifest is the source of truth; no
  clever inference at runtime.

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Symlinks + TOML manifests over Nix | Nix conflicts with go-task lock-in, slows AI iteration; manifest layer captures the declarative win without language overhead. |
| Per-machine manifest with shared `defaults.toml` | Picked clarity (per-machine) over DRY (tags); a handful of machines means defaults prevents pure duplication while machine files stay self-describing. |
| Explicit machine selection at setup | Hostname-based detection has bitten us; explicit selection beats clever auto-detect. |
| macOS-only | All target machines are macOS (laptops + Mac servers); avoids cross-platform complexity until a real Linux machine enters scope. |
| Keep alanpeabody-based prompt; reject Starship | The existing `theme.zsh` is small, fast, and not on life support; Starship would be a behavior change with no problem to solve. |
| Bootstrap without curl-to-shell | Removes supply-chain risk on every fresh install. |
| One concept per file; README per top-level directory | Reduces AI's inference burden; every directory teaches itself. |
| `task install` is the canonical entry; update path runs through the same task | Prevents the "add a package to update path, forget install, fresh machine breaks" drift class — single source of truth, single pipeline. |
| Five-tier testing: static lint, validate, reconcile, smoke, system | Each tier catches different drift; without verify+reconcile we'd ship "looks installed but isn't" or "symlink-soup-after-refactor". |
| Curated top-level surface (`install / setup / validate / test / lint / audit`) + domain-first `<domain>:<verb>` diagnostics | Audited every exposed task; one grammar (pick a domain, pick a verb); bare verbs aggregate; lint enforces banner drift via LINT-08. |

## Performance and Security Constraints

- **Performance target** — interactive shell cold start under 200ms; `task install` re-run
  under 30s on a converged machine (includes `brew update` network round-trip; under 5s
  without network).
- **Security** — bootstrap verifies install integrity; no curl-to-shell without checksum;
  no secrets in repo; public SSH keys only.
- **Idempotency** — every install task has a working `status:` check; re-running
  `task install` is a fast no-op.
