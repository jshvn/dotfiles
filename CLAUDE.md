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
surface is exactly five top-level commands:

| Command          | Purpose                                                      |
|------------------|--------------------------------------------------------------|
| `task install`   | Install dotfiles for the active machine                      |
| `task setup`     | Set the active machine: `task setup -- <machine-name>`       |
| `task validate`  | Validate full installation state                             |
| `task test`      | Run all smoke tests                                          |
| `task lint`      | Run all lint checks                                          |

Two diagnostic namespaces:

- `task show:*` -- inspect current state (`show:manifest`, `show:claude`, `show:hostname`)
- `task audit:*` -- detect drift (`audit:manifest`, `audit:packages`, `audit:links`)

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
- One shared bundle per purpose (`manifests/shared/<purpose>.toml`)
- One macOS defaults concern per file (`os/defaults/<concern>.zsh`)

### Flat directories in v1

No subdirectories inside `shell/aliases/` — all alias files live at the top of that directory.
No `manifests/shared/brew/` subdirectory; shared TOMLs are flat under `manifests/shared/`. No
`os/darwin/` nesting. v1 targets macOS only, so the platform dimension collapses to a flat
layout. When Linux enters scope in a future version, the directory structure will reshape —
that migration cost is documented in `PROJECT.md` and accepted.

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

### Lint rule catalogue (LINT-01..08)

In-code `# LINT-NN:` citations reference this catalogue. The rule body lives in
`taskfiles/lint.yml`; this table is the operator-facing summary.

| ID | Scope | What it checks |
|----|-------|----------------|
| LINT-02 | Taskfiles | `status:` uses `{{.X}}` template vars, not `$X` shell vars |
| LINT-03a | Taskfiles | Tasks with `cmds:` have `status:` (or exempt via `internal: true` / all-task-delegates) |
| LINT-03b | Repo-wide | No bare `ln -s` outside `taskfiles/helpers.yml` |
| LINT-04 | Executable .zsh | `set -euo pipefail` in first 30 lines |
| LINT-05 | shell/ + os/ | Portability-sensitive commands surface as warnings (non-blocking) |
| LINT-07 | All .zsh | `zsh -n` parse-check (Tier-0 syntax) |
| LINT-08 | Root Taskfile.yml | `default:` banner lists every public top-level task |

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

Set in `shell/.zshenv` (Phase 3 populates `shell/`); available as `{{.XDG_*}}` in taskfiles via the
root `Taskfile.yml` vars block.

### Zsh startup order

`.zshenv` (always sourced — keep minimal) -> `.zprofile` (login only;
`brew shellenv`, 1Password SSH socket) -> `.zshrc` (interactive only;
antigen, `compinit` daily-rebuild cache, theme, functions, aliases) ->
`.zlogin` (login only; MOTD dispatch) -> `.zlogout` (login exit; history flush).

## Where to Add Things

| Adding | Where | Naming |
|--------|-------|--------|
| An alias | `shell/aliases/<topic>.zsh` | kebab-case topic; one topic per file; flat (no subdir) |
| A function | `shell/functions/<name>.zsh` | filename equals function name; lowercase |
| A new machine | `manifests/machines/<name>.toml` + `task setup -- <name>` | kebab-case |
| A brew package | `manifests/shared/<purpose>.toml` (or `extra_packages` in the machine manifest for one-offs) | by purpose, not by machine |
| A macOS defaults concern | `os/defaults/<concern>.zsh` + feature flag in `defaults.toml` | one concern per file |
| A feature flag | `manifests/defaults.toml [features]` block + consuming task in the appropriate taskfile | kebab-case key |
| A tool config | `configs/<tool>/` + symlink entry in `taskfiles/links.yml` | use the tool's expected config filename |
| A Claude hook | `claude/hooks/<name>.zsh` + entry in `claude/hooks/hooks.json` | kebab-case |

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
- Don't add a profile-suffixed shared bundle (e.g., `manifests/shared/personal.toml`).
  Shared bundles are named by purpose (`core.toml`, `gui.toml`, future `dev.toml`), not by
  machine. Per-machine variation goes in `manifests/machines/<name>.toml [packages.brew.extra_packages]`.
- Don't bypass `_:safe-link` when creating symlinks.
- Don't use `$VAR` (shell variable) where `{{.VAR}}` (task template variable) is expected —
  especially inside `status:` blocks.
- Don't define `DOTFILEDIR: { sh: dirname ... }` in included taskfiles — it leaks into root
  scope under include-merge and competes with the root `Taskfile.yml` definition. Source
  `install/messages.zsh` via `{{.TASKFILE_DIR}}` (per the `Taskfile.yml` comment block warning
  the same).
- Don't commit private keys. `identity/ssh/keys/` contains public keys only.

## Project State and Workflow

Use `/gsd-*` commands for any non-trivial change. Direct edits outside a GSD workflow bypass
the planning artifacts and lose context for AI-assisted maintenance.

Entry points:
- `/gsd-quick` — small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` — investigation and bug fixing
- `/gsd-execute-phase` — planned phase work
