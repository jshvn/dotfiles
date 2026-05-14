# Phase 2: Install Engine — Bootstrap, Idempotency, Lint - Pattern Map

**Mapped:** 2026-05-13
**Files analyzed:** 18 (8 net-new artifacts + 11 lint test fixtures, counted as one fixture-suite artifact for the role table)
**Analogs found:** 8 / 8 (every new artifact has a Phase 1 or v1 analog the planner can reference)

---

## File Classification

| New / Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---------------------|------|-----------|----------------|---------------|
| `bootstrap.zsh` (rewrite) | bootstrap-script (executable zsh) | request-response (CLI tool, exits 0/1) | `bootstrap.zsh` (v1, current) + `install/resolver.zsh` (P1, header pattern) | exact (same file role) + role-match (header conventions) |
| `Taskfile.yml` (rewrite) | orchestration-root (taskfile) | request-response (delegates to subtasks) | `Taskfile.yml` (v1, current) + `taskfiles/manifest.yml` (P1) | exact (same file role) |
| `taskfiles/install.yml` (NEW; optional inline alternative) | orchestration-module (taskfile) | request-response (composes subtask graph) | `taskfiles/manifest.yml` (P1) | exact role + data flow |
| `taskfiles/lint.yml` (NEW) | lint-suite (taskfile) | batch (scan-many-files-emit-violations) | `taskfiles/manifest.yml manifest:test` task (P1) — same fixture-iteration shape | role-match (taskfile module) + data-flow match (batch scan + report) |
| `taskfiles/links-stub.yml` (NEW) | stub-taskfile | request-response (no-op placeholder) | `taskfiles/helpers.yml` (P1, structurally simplest taskfile) | role-match |
| `taskfiles/brew-stub.yml` (NEW) | stub-taskfile | request-response (no-op placeholder) | `taskfiles/helpers.yml` (P1) | role-match |
| `taskfiles/claude-stub.yml` (NEW) | stub-taskfile | request-response (no-op placeholder) | `taskfiles/helpers.yml` (P1) | role-match |
| `taskfiles/macos-stub.yml` (NEW) | stub-taskfile | request-response (no-op placeholder) | `taskfiles/helpers.yml` (P1) | role-match |
| `install/cutover-gate.zsh` (NEW) | sourced-helper (zsh library) | request-response (function returns 0/1) | `install/messages.zsh` (P1) — same double-source-guard library pattern | exact role + data flow |
| `docs/SECURITY.md` (NEW) | documentation (markdown) | n/a (prose) | `manifests/README.md` (P1) — terse, declarative, scoped to one concern | role-match |
| `taskfiles/test/lint-fixtures/<NN>-<name>/` × 11 (NEW) | test-fixture (taskfile or .zsh + expect file) | batch (read-fixture, run-lint, diff-expect) | `manifests/test/fixtures/01-map-over-map/` (P1) — same `<NN>-<name>/{input, expected}` shape | exact (positive + negative fixtures, numbered, with expected output) |

---

## Pattern Assignments

### `bootstrap.zsh` (rewrite — bootstrap-script, request-response)

**Primary analog:** `install/resolver.zsh` (P1, hardened script header pattern)
**Secondary analog:** `bootstrap.zsh` (v1, current — for the `DOTFILEDIR` symlink-walk and `header` invocation; everything else gets replaced)

**Header + strict-mode pattern** (mirror `install/resolver.zsh:1-30`):

```zsh
#!/bin/zsh
# -----------------------------------------------------------------------------
# install/resolver.zsh -- compile defaults + machine manifest into resolved.json
#
# Sourced from: taskfiles/manifest.yml (manifest:resolve, manifest:validate,
#               manifest:show tasks). Also runnable directly via
#               `zsh install/resolver.zsh [flags]`.
#
# Reads:        $DOTFILEDIR/manifests/defaults.toml
# Writes:       $XDG_STATE_HOME/dotfiles/resolved.json  (atomic via mktemp+mv)
# Depends on:   yq (>= 4.52.1), jq (>= 1.7), zsh (>= 5)
# -----------------------------------------------------------------------------

set -euo pipefail
```

**The v2 `bootstrap.zsh` MUST adopt this 28-line file-level header convention** (purpose / sourced-from / reads / writes / depends-on / modes) — and `set -euo pipefail` (BTSP-01) replaces v1's `set -e` at line 2.

**`DOTFILEDIR` symlink-walk pattern to PORT from v1** (`bootstrap.zsh:5-12`, hardened with `set -u`-safe `:-$0` fallback per RESEARCH §3.6):

```zsh
SOURCE="${BASH_SOURCE[0]:-$0}"
while [[ -h "$SOURCE" ]]; do
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
DOTFILEDIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
export DOTFILEDIR
```

**Messages-library sourcing pattern** (mirror `install/resolver.zsh:36-40`, double-source-guard-aware under `set -u`):

```zsh
: "${DOTFILEDIR:?DOTFILEDIR not set -- run via 'task manifest:*' or export it manually}"
: "${DOTFILES_MESSAGES_LOADED:=}"
if [[ -z "$DOTFILES_MESSAGES_LOADED" ]]; then
  source "${DOTFILEDIR}/install/messages.zsh"
fi
```

**Audit-line + brew installer pattern** — NEW (no v1 analog; v1's `bootstrap.zsh:33` is the bug being fixed). Use the RESEARCH §3.2 sketch verbatim. Concrete excerpt the planner copies:

```zsh
if ! command -v brew >/dev/null 2>&1; then
  {
    echo
    echo "AUDIT: about to fetch and execute brew install script"
    echo "  source: https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
    echo "  trust:  HTTPS only, no checksum pin (see docs/SECURITY.md)"
    echo "  ctrl-C now to abort (3 second window)"
    echo
  } >&2
  sleep 3
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ "$(uname -m)" == "arm64" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    eval "$(/usr/local/bin/brew shellenv)"
  fi
else
  info "brew already installed: $(brew --version | head -1)"
fi
```

**`command -v` precheck idempotency pattern** (RESEARCH §3.3, Pitfall 4) — every `brew install` is wrapped:

```zsh
if ! command -v task >/dev/null 2>&1; then
  info "installing go-task..."
  brew install go-task
else
  info "go-task already installed: $(task --version)"
fi
```

**`info`/`success`/`warn`/`error`/`header` invocation** — sourced from `install/messages.zsh` (P1-preserved):
- `info "..."` → blue `[INFO]` to stdout
- `success "..."` → green `[SUCCESS]` to stdout
- `warn "..."` → yellow `[WARN]` to stdout
- `error "..."` → red `[ERROR]` to **stderr** (note: `messages.zsh:47` writes `>&2`)
- `header "Dotfiles v2 Bootstrap"` → green bold banner

**Cutover-gate sourcing block** (per RESEARCH §3.4):

```zsh
source "${DOTFILEDIR}/install/cutover-gate.zsh"
cutover_gate_check || exit 1
```

**v1 `task install "$@"` invocation MUST be removed** (D-03 — bootstrap is tools-only; user runs `task setup -- <name>` and `task install` themselves).

---

### `Taskfile.yml` (rewrite — orchestration-root, request-response)

**Primary analog:** `Taskfile.yml` (v1, current — for the `version: '3'` + `set: [errexit, pipefail]` + global `vars:` block + `includes:` block + `tasks: install:` shape)
**Secondary analog:** `taskfiles/manifest.yml` (P1 — for `vars:` block depth and `DOTFILES_MESSAGES` declaration; for the `MANIFEST` `ref: 'fromJson .MANIFEST_JSON'` pattern Phase 2 inherits)

**Top-of-file pattern to PORT** (`Taskfile.yml:1-13`):

```yaml
version: '3'

set: [errexit, pipefail]

silent: true

vars:
  # Core paths
  HOME: '{{.HOME}}'
  XDG_CONFIG_HOME: '{{.HOME}}/.config'
  XDG_DATA_HOME: '{{.HOME}}/.local/share'
  XDG_STATE_HOME: '{{.HOME}}/.local/state'
  XDG_CACHE_HOME: '{{.HOME}}/.cache'
  ZDOTDIR: '{{.XDG_CONFIG_HOME}}/zsh'
```

**`HOMEBREW_PREFIX` detection pattern to PORT** (`Taskfile.yml:30-39`) — matches CLAUDE.md's "no hardcoded /opt/homebrew" rule:

```yaml
HOMEBREW_PREFIX:
  sh: |
    if command -v brew &>/dev/null; then
      brew --prefix
    elif [[ "$(uname)" == "Darwin" ]]; then
      [[ "$(uname -m)" == "arm64" ]] && echo "/opt/homebrew" || echo "/usr/local"
    else
      echo "/home/linuxbrew/.linuxbrew"
    fi
```

**`DOTFILES_MESSAGES` template var** (`Taskfile.yml:48-49`):

```yaml
DOTFILES_MESSAGES: |
  source '{{.DOTFILEDIR}}/install/messages.zsh'
```

**Manifest-loading vars to ADD** (port from `taskfiles/manifest.yml:80-93` — Phase 2's root Taskfile.yml gains these so every install task can reference `{{.MANIFEST.identity.git}}`):

```yaml
MANIFEST_JSON:
  sh: |
    if [[ -s '{{.RESOLVED_JSON_PATH}}' ]]; then
      cat '{{.RESOLVED_JSON_PATH}}'
    else
      echo "warning: {{.RESOLVED_JSON_PATH}} missing or empty -- run 'task setup -- <machine>' first" >&2
      echo '{}'
    fi

MANIFEST:
  ref: 'fromJson .MANIFEST_JSON'
```

**`includes:` block transformation** (the P2 v2 form replaces `Taskfile.yml:54-72` profile-suffixed includes with stub references per RESEARCH §4.1):

```yaml
includes:
  manifest: ./taskfiles/manifest.yml
  lint:     ./taskfiles/lint.yml
  links:    ./taskfiles/links-stub.yml      # P3 wires real bodies
  brew:     ./taskfiles/brew-stub.yml       # P5 wires real bodies
  claude:   ./taskfiles/claude-stub.yml     # P7 wires real bodies
  macos:    ./taskfiles/macos-stub.yml      # P6 wires real bodies
```

**`task install` body — the P2 canonical entry** (RESEARCH §4.1 / Example 4). Mirrors the v1 `task install` cmds: shape (`Taskfile.yml:92-116`) but adds `preconditions:` for the cutover gate and `deps: [manifest:resolve]` for the auto-rebuild precondition (P1 D-14):

```yaml
install:
  desc: "Install dotfiles for active machine (canonical entry)"
  summary: |
    task install IS task update -- there is no separate update pipeline.
    Re-running is a no-op (every subtask has a status: block).
  preconditions:
    - sh: |
        source "{{.DOTFILEDIR}}/install/cutover-gate.zsh"
        cutover_gate_check
      msg: "cutover-ack gate failed -- see error above"
  deps: [manifest:resolve]
  cmds:
    - task: links:all
    - task: brew:install
    - task: claude:install
    - task: macos:defaults
    - task: macos:shell
    - |
      {{.DOTFILES_MESSAGES}}
      success "install complete"
```

**`tasks: update:` block MUST be REMOVED** (D-10 — `Taskfile.yml:118-139` deleted entirely; `task install` is the only entry).

**`tasks: validate:` block — DEFER to Phase 8** (CONTEXT `<deferred>` — P2's rewrite drops `validate:` from the P2-shipped Taskfile.yml; Phase 8 re-adds via `task validate` composition).

---

### `taskfiles/install.yml` (optional NEW — orchestration-module, request-response)

**Primary analog:** `taskfiles/manifest.yml` (P1)

**Open question (RESEARCH §16 #1):** the planner decides whether to inline the `install:` task in root `Taskfile.yml` or split it into `taskfiles/install.yml`. If split, mirror manifest.yml's structure exactly:

**Self-contained `vars:` block pattern** (`taskfiles/manifest.yml:35-49`):

```yaml
vars:
  HOME: '{{.HOME}}'
  XDG_STATE_HOME:
    sh: echo "${XDG_STATE_HOME:-$HOME/.local/state}"
  DOTFILEDIR:
    sh: dirname "$(dirname "$(realpath "${TASKFILE:-$0}")")"
  DOTFILES_MESSAGES: |
    source '{{.DOTFILEDIR}}/install/messages.zsh'
```

**File-level header banner pattern** (`taskfiles/manifest.yml:3-18`):

```yaml
# =============================================================================
# taskfiles/manifest.yml -- go-task module: manifest engine orchestration
#
# Exposes the manifest engine (install/resolver.zsh) to humans and downstream
# taskfiles. Wires Plan 02's resolver against Plan 01's fixtures.
#
# NOT yet included from the root Taskfile.yml (Phase 1 constraint).
# Invoke standalone via:
#   task -t taskfiles/manifest.yml <task> [-- <args>]
# =============================================================================
```

**Recommendation:** keep `task install` body inline in root `Taskfile.yml` for P2 (only one orchestration task; splitting adds a file with one task in it). Only split if the planner adds enough auxiliary tasks (e.g., `install:dry-run`, `install:diff`) to justify a module.

---

### `taskfiles/lint.yml` (NEW — lint-suite, batch)

**Primary analog:** `taskfiles/manifest.yml manifest:test` task (P1) — same fixture-iteration + `failures` counter + `check`/`cross` reporting + `exit "$failures"` shape (`taskfiles/manifest.yml:277-412`).
**Secondary analog:** `taskfiles/helpers.yml` (P1) — for the `includes: _: ./helpers.yml` declaration and the `internal: true` + `requires: vars: [...]` patterns.

**Header banner pattern** (mirror `taskfiles/lint.yml` skeleton in RESEARCH §7):

```yaml
# =============================================================================
# Lint suite -- enforces v2 conventions structurally.
#
# - LINT-02: $VAR in status: blocks (the macos:shell:145 bug class)
# - LINT-03a: cmds: without status: (the gsd-install bug class)
# - LINT-03b: bare ln -s outside helpers.yml (the links.yml:69 bug class)
# - LINT-04: executable .zsh missing set -euo pipefail (the bootstrap.zsh:2 bug class)
# - LINT-05: portability hints (warn-only, exit 0)
# - LINT-07: zsh -n parse errors
#
# Callable as `task lint` (default) or individually as `task lint:taskfile`, etc.
# Read-only (no manifest dependency); not gated by cutover-ack.
# =============================================================================
```

**Aggregator pattern** (RESEARCH §5.1 + the v1 `tasks: install:` orchestration shape from `Taskfile.yml:92-116`):

```yaml
tasks:
  default:
    desc: "Run all lint checks (LINT-06 aggregator)"
    cmds:
      - task: syntax        # LINT-07 -- zsh -n parse + task --list-all parse
      - task: taskfile      # LINT-02 + LINT-03a + LINT-03b
      - task: shell-headers # LINT-04
      - task: portability   # LINT-05 (warn-only)
```

**Per-check `cmds:` block pattern** (port the failures-counter + `check`/`cross` reporting from `taskfiles/manifest.yml:281-348`):

```yaml
- |
  {{.DOTFILES_MESSAGES}}
  failures=0
  for f in taskfiles/*.yml; do
    out=$(yq '.tasks[] | select(.status) | .status' "$f" 2>/dev/null \
          | ggrep -nE '\$[A-Za-z_][A-Za-z0-9_]*' \
          | ggrep -vE '\$\(' \
          | ggrep -vE '\{\{' || true)
    if [[ -n "$out" ]]; then
      cross "LINT-02: \$VAR in status: block — $f"
      echo "$out" >&2
      failures=$(( failures + 1 ))
    else
      check "LINT-02: $f"
    fi
  done
  exit "$failures"
```

The `failures=0 ... exit "$failures"` envelope is the canonical P1 pattern (`manifest:test:412`). Re-use verbatim across LINT-02 / LINT-03a / LINT-03b / LINT-04 / LINT-07. **LINT-05 (portability) breaks this rule by design** — always `exit 0` per D-13.

**`status:` block on lint sub-tasks — DO NOT add one.** Lint tasks are intentionally always-re-run (no cached "last lint pass" state). Justify in a comment so LINT-03a doesn't false-positive on its own taskfile (or use `internal: true` for sub-tasks the aggregator calls; the aggregator itself can use `status: [false]` to assert "always run" — but RESEARCH §5.4 recommends NOT exempting validate/test tasks; planner picks the cleanest enforcement).

---

### `taskfiles/links-stub.yml`, `brew-stub.yml`, `claude-stub.yml`, `macos-stub.yml` (NEW — stub-taskfile, request-response)

**Primary analog:** `taskfiles/helpers.yml` (P1) — structurally simplest taskfile in the repo (no `vars:` block, no `includes:`, just `version: '3'` + `tasks:`).

**Header pattern** (port from `taskfiles/helpers.yml:1-23`, replacing the helper description with the stub marker):

```yaml
version: '3'

# =============================================================================
# taskfiles/links-stub.yml -- Phase 3 placeholder
#
# This file is loaded by the root Taskfile.yml via:
#   includes:
#     links: ./taskfiles/links-stub.yml
#
# Phase 3 (SHEL-01..03) replaces this file with the real taskfiles/links.yml.
# The stub exists so `task install` has a complete call graph in Phase 2 and
# the lint suite can self-test against a fully wired manifest.
# =============================================================================
```

**Stub task body pattern** (RESEARCH §4.1 — `status: [true]` makes the stub idempotent under LINT-03a; `>&2` echo is the visible "this is a stub" trace):

```yaml
tasks:
  all:
    desc: "STUB (Phase 3 will implement SHEL-01..03 here)"
    status: [true]   # always-pass; nothing to do
    cmds:
      - |
        echo "links:all -- stub (Phase 3 will implement SHEL-01..03)" >&2
```

**Per-stub task list to ship in P2** (RESEARCH §4.1 `task install` body cmds):
- `links-stub.yml`: tasks `all` (called by `task install`)
- `brew-stub.yml`: tasks `install` (called by `task install`)
- `claude-stub.yml`: tasks `install` (called by `task install`)
- `macos-stub.yml`: tasks `defaults`, `shell` (both called by `task install`)

**Each stub task MUST have `status: [true]`** so LINT-03a passes, AND the desc starts with `STUB (Phase X)` so `grep -r "STUB (Phase " taskfiles/` cleanly enumerates outstanding work.

---

### `install/cutover-gate.zsh` (NEW — sourced-helper, request-response)

**Primary analog:** `install/messages.zsh` (P1-preserved) — same double-source-guard library pattern, same sourced-by-multiple-callers role.

**File-level header pattern** (port from `install/messages.zsh:1-17` style, expanded to match the P1 `install/resolver.zsh:1-28` 28-line header convention since this is a more substantive helper):

```zsh
#!/bin/zsh
# -----------------------------------------------------------------------------
# install/cutover-gate.zsh -- enforce per-machine cutover-ack sentinel.
#
# Sourced by:
#   - bootstrap.zsh (called BEFORE printing next-step hint)
#   - taskfiles/install.yml (preconditions: block on `task install`)
#
# Reads: $XDG_STATE_HOME/dotfiles/cutover-ack    (single line: <name> <ts>)
#        $XDG_STATE_HOME/dotfiles/machine        (active machine name)
# Exits: 1 on missing/invalid/mismatched sentinel
#        0 on valid sentinel for active machine
#
# The sentinel WRITER (`task cutover:ack -- <name>`) is owned by Phase 8
# (CUTV-03). P2 only reads/enforces.
# -----------------------------------------------------------------------------
```

**Double-source-guard pattern** (mirror `install/messages.zsh:19-21` exactly):

```zsh
[[ -n "${DOTFILES_CUTOVER_GATE_LOADED:-}" ]] && return 0
DOTFILES_CUTOVER_GATE_LOADED=1
```

**Defensive messages-source pattern under `set -u`** (port from `install/resolver.zsh:36-40`):

```zsh
: "${DOTFILES_MESSAGES_LOADED:=}"
[[ -z "$DOTFILES_MESSAGES_LOADED" ]] && source "${DOTFILEDIR:?}/install/messages.zsh"
```

**`cutover_gate_check` function body** — RESEARCH §6.2 / Example 3. Use verbatim as the planner reference. Three failure modes (missing, malformed, mismatch) each call `_cutover_gate_emit_error` with a reason string.

**State-file read pattern to PORT** (mirror `taskfiles/manifest.yml:69` `MACHINE` var which uses the trim-edges-only sed pattern):

```zsh
active_machine=$(head -n1 "$machine_file" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
```

**Why `head -n1 | sed -e ...` not `cat | tr -d`:** the P1 WR-08 fix (logged in `taskfiles/manifest.yml:62-69` comment) is binding — `tr -d '[:space:]'` silently rewrites `"bad name\n"` to `"badname"`, mangling malformed state into a wrong-but-valid name. Use the P1-blessed pattern.

**Sentinel-line read pattern** (RESEARCH §6.2): `read -r ack_machine ack_ts < "$ack_file"` — splits on whitespace, ignores extra fields, prevents backslash interpretation.

**Error-emission pattern** (mirror `install/messages.zsh:46-48` `error()`'s `>&2` convention) — every line in `_cutover_gate_emit_error` is wrapped in `{ ... } >&2`.

---

### `docs/SECURITY.md` (NEW — documentation, prose)

**Primary analog:** `manifests/README.md` (P1) — terse, declarative, scoped to one concern.

**Recommended structure** (RESEARCH §8 outline, copied verbatim by planner):
1. `## What This Document Covers` — bootstrap trust chain only; SSH defers to P4, hooks defer to P7
2. `## Bootstrap Trust Chain`
   - `### Step 1 -- Homebrew installer` — what / from where / how verified / NOT verified
   - `### Step 2 -- go-task and yq` — Homebrew SHA256-signed bottles
3. `## Threat Model` — table: attack / vector / mitigation / residual risk
4. `## Trust Anchors` — brew.sh TLS, GitHub mirror, Homebrew signing infra
5. `## What This Document Does NOT Cover` — deferred to P4/P7
6. `## How to Audit` — concrete commands the user runs
7. `## Future Hardening` — pinned checksums, vendored installer (deferred per CONTEXT)

**Style conventions** (CLAUDE.md):
- No emojis (project-stricter rule than the global no-emoji-in-non-md)
- No AI attribution
- Plain markdown; section separators may use `---` between top-level `##` blocks

---

### `taskfiles/test/lint-fixtures/<NN>-<name>/` × 11 (NEW — test-fixture, batch)

**Primary analog:** `manifests/test/fixtures/01-map-over-map/` (P1) — same `<NN>-<name>/{input-files, expected-output}` shape.

**Directory structure pattern to MIRROR** (verified live: `manifests/test/fixtures/01-map-over-map/` contains `defaults.toml`, `machine.toml`, `expected.json`):

```
manifests/test/fixtures/
├── 01-map-over-map/
│   ├── defaults.toml      # input
│   ├── machine.toml       # input
│   └── expected.json      # expected output
├── _invalid-bad-os/       # negative fixture (underscore-prefix convention)
└── _invalid-missing-desc/ # negative fixture
```

**v2 lint-fixtures structure** (RESEARCH §10.4 — adapt the P1 numbering convention; positives use `<NN><suffix>-<name>/`, negatives use either `<NN><suffix>-<name>/` with FAIL expect file or underscore-prefix):

```
taskfiles/test/lint-fixtures/
├── 02a-shell-var-in-status/         # positive: status uses $VAR; expect FAIL
│   ├── Taskfile.yml
│   └── expect                        # contents: "fail"
├── 02b-template-var-in-status/      # negative: status uses {{.X}}; expect PASS
├── 02c-command-substitution-in-status/  # negative: $(cmd) is OK; expect PASS
├── 03a-cmds-no-status/              # positive: cmds: no status:; expect FAIL
├── 03a-internal-no-status-ok/       # negative: internal: true exempt; expect PASS
├── 03b-bare-ln/                     # positive: ln -sf outside helpers; expect FAIL
├── 03b-helpers-allowed/             # negative: helpers.yml ln -sfn; expect PASS
├── 04a-missing-set-euo/             # positive: executable .zsh has set -e only
├── 04b-non-exec-no-set/             # negative: sourced-only is exempt; PASS
├── 05a-pbcopy-warn/                 # positive (warn): pbcopy in shell/; WARN+exit0
└── 07a-syntax-error/                # positive: deliberate zsh -n parse error; FAIL
```

**Fixture file conventions:**
- Each fixture directory contains the **minimum** files needed to trigger or not trigger one specific lint check
- An `expect` text file (one word: `pass`, `fail`, or `warn`) for the test runner to assert against
- For taskfile fixtures: the file must be valid YAML (so the runner can load it)
- For .zsh fixtures: the file must include the standard header comment block (so it looks like a real script)

**Self-test pattern** (port from `manifest:test`'s positive+negative fixture loop — `taskfiles/manifest.yml:306-348`):
- Iterate `taskfiles/test/lint-fixtures/*/`
- For each: invoke the relevant `task lint:<check>` against the fixture
- Compare exit code against the `expect` file
- Report `check`/`cross` per fixture
- Sum `failures` and `exit "$failures"`

The planner ships a `task lint:test-fixtures` (or `task lint:self-test`) sub-task that runs this loop. NOT part of the `task lint` default aggregator (lint default = lint the actual repo; self-test is opt-in).

---

## Shared Patterns

### Pattern S1: File-level header comment block (BINDING per CLAUDE.md)

**Source:** `install/resolver.zsh:1-28` (28-line header) and `taskfiles/manifest.yml:3-18` (taskfile banner)
**Apply to:** Every `bootstrap.zsh`, every `install/*.zsh`, every `taskfiles/*.yml` file shipped in P2

**Required content:**
- Filename + one-line purpose (top of header)
- "Sourced from" / "Reads" / "Writes" / "Depends on" sections (script files)
- Rationale + cross-reference to research/decisions when non-obvious
- For taskfiles: usage example showing `task -t taskfiles/<file>.yml <task> -- <args>` if standalone-invocable

**Verbatim shape:**
```zsh
#!/bin/zsh
# -----------------------------------------------------------------------------
# install/<file>.zsh -- one-line purpose
#
# Sourced from: <list of callers, with task names>
# Reads:        <files / env vars>
# Writes:       <files>
# Depends on:   <external tools with min versions>
# -----------------------------------------------------------------------------
```

---

### Pattern S2: `set -euo pipefail` on every executable `.zsh`

**Source:** `install/resolver.zsh:30`, `claude/hooks/no-emojis.zsh:5`
**Apply to:** `bootstrap.zsh` (the BTSP-01 fix target), every other executable `.zsh` shipped in P2 — the lint suite (LINT-04) enforces this structurally on file count > 0

**No alternatives.** `set -e` alone is the v1 bug class. `set -eu` misses pipefail. `set -euo pipefail` is the only acceptable form.

---

### Pattern S3: Double-source guard for sourced libraries

**Source:** `install/messages.zsh:19-21`
**Apply to:** `install/cutover-gate.zsh` (the only new sourced library in P2)

```zsh
[[ -n "${DOTFILES_<LIB_NAME>_LOADED:-}" ]] && return 0
DOTFILES_<LIB_NAME>_LOADED=1
```

**Note the `:-` empty-default operator** — required under `set -u` so the guard works in scripts that source the library before any other init.

---

### Pattern S4: Errors to stderr via `error()` from messages.zsh

**Source:** `install/messages.zsh:46-48` — `error()` is the only message function that writes `>&2`
**Apply to:** `bootstrap.zsh` audit lines, `install/cutover-gate.zsh` failure paths, every lint sub-task violation report

**Convention:** all user-facing error output goes through `error "..."`. Multi-line error blocks wrap the whole block in `{ ... } >&2` (RESEARCH §6.2 `_cutover_gate_emit_error`).

---

### Pattern S5: Template vars in `status:` blocks (NOT shell vars)

**Source:** `taskfiles/manifest.yml:164-168` `manifest:resolve` task, CLAUDE.md "Every install task has a `status:` block" section
**Apply to:** Every task in `Taskfile.yml`, `taskfiles/install.yml` (if split), every stub taskfile

**Rule:** inside `status:` blocks, use `{{.VAR}}` (template var, resolved at task-graph build time). NEVER use `$VAR` (shell var, unset in the status-eval context). This is the v1 `taskfiles/macos.yml:145` bug class that LINT-02 catches.

```yaml
# Wrong — $RESOLVED_JSON_PATH is empty in status context
status:
  - test -f "$RESOLVED_JSON_PATH"

# Correct — template var
status:
  - test -f "{{.RESOLVED_JSON_PATH}}"
```

---

### Pattern S6: kebab-case feature keys use `index` not dot-access

**Source:** `taskfiles/manifest.yml:90-93` comment + CLAUDE.md "kebab-case feature names need `index` access"
**Apply to:** Any `taskfiles/*.yml` that consumes `{{.MANIFEST.features.X}}`

```yaml
# Wrong — parser rejects kebab in dot-access
{{if .MANIFEST.features.one-password-ssh}}

# Correct — index form
{{if index .MANIFEST.features "one-password-ssh"}}
```

P2's stubs themselves don't consume features (their bodies are no-ops), but the cutover-gate gate documentation should reference this rule for downstream phases.

---

### Pattern S7: Symlinks via `_:safe-link` only (LINT-03b enforced)

**Source:** `taskfiles/helpers.yml:30-37` (the `safe-link` task) + CLAUDE.md "Symlinks via `_:safe-link` only"
**Apply to:** Every taskfile that creates symlinks

**No bare `ln -s` allowed outside `taskfiles/helpers.yml`.** P2's lint enforcement (LINT-03b) makes this structural. P2's stubs don't create symlinks; the rule documentation lives in `taskfiles/lint.yml`'s file header.

---

### Pattern S8: XDG-state file conventions for machine-local state

**Source:** `taskfiles/manifest.yml:51-53` (`STATE_DIR`, `STATE_FILE`, `RESOLVED_JSON_PATH` vars)
**Apply to:** `install/cutover-gate.zsh` (adds `cutover-ack` to the same dir)

```zsh
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
# Files in this dir (single-line, plain text, no nesting):
#   $STATE_DIR/machine        -- P1 owns
#   $STATE_DIR/resolved.json  -- P1 owns
#   $STATE_DIR/cutover-ack    -- P2 owns (this phase)
```

Single-line text files. No nested subdirs. No timestamps in filenames. Match the P1 convention exactly.

---

### Pattern S9: `failures=0` counter + `check`/`cross` per item + `exit "$failures"`

**Source:** `taskfiles/manifest.yml:283-412` (`manifest:test` task)
**Apply to:** Every lint sub-task in `taskfiles/lint.yml` (LINT-02 / LINT-03a / LINT-03b / LINT-04 / LINT-07)

```bash
{{.DOTFILES_MESSAGES}}
failures=0
for item in <list>; do
  if <check passes>; then
    check "<lint-id>: ${item}"
  else
    cross "<lint-id>: ${item} -- <reason>"
    failures=$(( failures + 1 ))
  fi
done
exit "$failures"
```

**Exception:** LINT-05 (portability) uses the same iteration shape but always `exit 0` per D-13 — counter becomes `warnings` and the final `exit 0` is hard-coded.

---

### Pattern S10: Numbered fixture directories with `expect` file

**Source:** `manifests/test/fixtures/01-map-over-map/` and `manifests/test/fixtures/_invalid-bad-os/`
**Apply to:** `taskfiles/test/lint-fixtures/<NN>-<name>/`

- Positive fixture (the lint check should fire): numeric prefix `<NN><suffix>-<name>/` matching the LINT-id
- Negative fixture (the lint check must NOT fire): same numeric prefix, suffix marks it as the negative variant (e.g., `02b-`, `04b-`)
- Each directory contains: the file(s) being tested + `expect` text file (`pass` / `fail` / `warn`)
- The fixture runner iterates with `for fix in fixtures/[0-9]*-*; do` (P1 idiom)

---

## No Analog Found

None. Every P2 artifact has at least one Phase 1 or v1 analog the planner can copy patterns from.

---

## Metadata

**Analog search scope:**
- `/Users/josh/Git/personal/dotfiles/Taskfile.yml` (v1 root)
- `/Users/josh/Git/personal/dotfiles/bootstrap.zsh` (v1)
- `/Users/josh/Git/personal/dotfiles/install/messages.zsh` (P1-preserved)
- `/Users/josh/Git/personal/dotfiles/install/resolver.zsh` (P1)
- `/Users/josh/Git/personal/dotfiles/taskfiles/manifest.yml` (P1)
- `/Users/josh/Git/personal/dotfiles/taskfiles/helpers.yml` (P1)
- `/Users/josh/Git/personal/dotfiles/taskfiles/macos.yml` (v1 — for LINT-02 bug class)
- `/Users/josh/Git/personal/dotfiles/taskfiles/links.yml` (v1 — for LINT-03b bug class)
- `/Users/josh/Git/personal/dotfiles/taskfiles/claude.yml` (v1 — for LINT-03a bug class)
- `/Users/josh/Git/personal/dotfiles/claude/hooks/no-emojis.zsh` (v1 — for `set -euo pipefail` example)
- `/Users/josh/Git/personal/dotfiles/manifests/test/fixtures/` (P1 — for fixture directory shape)
- `/Users/josh/Git/personal/dotfiles/manifests/defaults.toml`, `manifests/machines/personal-laptop.toml` (P1 — for header comment style)

**Files scanned:** 12

**Pattern extraction date:** 2026-05-13

---

## Cross-references

- Bug-class pinpoints (CONTEXT `<canonical_refs>` `.planning/codebase/CONCERNS.md`):
  - `taskfiles/macos.yml:145` → drives LINT-02 fixture `02a-shell-var-in-status/`
  - `taskfiles/links.yml:69` → drives LINT-03b fixture `03b-bare-ln/`
  - `taskfiles/claude.yml:211-219` → drives LINT-03a fixture `03a-cmds-no-status/`
  - `bootstrap.zsh:2` → drives LINT-04 fixture `04a-missing-set-euo/`

- Phase 1 deliverables binding on P2 (CONTEXT `<canonical_refs>`):
  - D-14 (auto-rebuild via task precondition) → `task install` declares `deps: [manifest:resolve]`
  - D-16 (missing-state hard-fail with actionable error) → `cutover_gate_check` reuses this pattern
  - `_:safe-link` / `_:check-link` in `taskfiles/helpers.yml` → P2 `task install` precondition msgs reference these helpers
