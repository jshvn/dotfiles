---
phase: 08-validation-cutover-readiness
plan: 01
subsystem: task-orchestration
tags: [links, taskfile, refactor, expected-targets, validate]
requires:
  - taskfiles/links.yml
  - taskfiles/helpers.yml ('_:safe-link', '_:check-link' primitives)
  - taskfiles/manifest.yml (':manifest:resolve' dep target)
  - install/messages.zsh (check/cross output via DOTFILES_MESSAGES)
provides:
  - EXPECTED_TARGETS multiline var in taskfiles/links.yml (canonical symlink-target catalog, 26 entries)
  - links:validate shell-block validator that exits non-zero on any failed check (closes the _:check-link always-exits-0 gap)
  - configs:ghostty internal sub-task (isolates the ghostty feature-gate from the always-on tool-configs status block)
affects:
  - taskfiles/links.yml
tech-stack:
  added: []
  patterns:
    - inline-ternary EXPECTED_TARGETS feature gating (analog: taskfiles/claude.yml status: blocks)
    - failures-counter shell block with `exit "$failures"` (analog: taskfiles/macos.yml validate:, taskfiles/packages.yml verify:)
    - leading-colon root-namespace deps: [":manifest:resolve"] (analog: taskfiles/macos.yml validate: line 258)
    - feature-gate isolation via dedicated sub-task with task-level inline-ternary status (configs:ghostty)
key-files:
  created: []
  modified:
    - taskfiles/links.yml
decisions:
  - "Use inline-ternary form in EXPECTED_TARGETS for feature-gated entries: feature-off renders an empty line that consumers skip via `[[ -z \"$line\" ]] && continue`. Avoids the cmds-spanning template-EOF bug class."
  - "Hoist the ghostty safe-link call into a dedicated configs:ghostty internal sub-task with a task-level inline-ternary status. The naive in-place wrapper removal would have run the unconditional ghostty safe-link whenever any always-on configs: status check failed -- a partial-state regression. Sub-task isolation preserves the feature-off no-op contract in all cases (Rule 1 deviation)."
  - "Map TARGET -> SOURCE in links:validate via a single resolve_source() case statement keyed on target path patterns (case + glob suffix extraction). Single source of truth that mirrors the literal pairings in links:zsh / links:antidote / links:claude / links:configs cmds: blocks."
  - "Identity symlinks (git/ssh) intentionally OUT of EXPECTED_TARGETS -- they live in taskfiles/identity.yml and are validated by identity:validate. Including them would create a cross-module boundary violation."
  - "EXPECTED_TARGETS final count is 26 unique target paths (5 zsh + 1 antidote + 13 claude-gated + 1 ghostty-gated + 6 tool-configs always-on). The plan's acceptance text says 27 due to a double-count of antidote in the breakdown line; the interfaces bullet list (authoritative source) lists exactly 26."
metrics:
  duration: 6m
  completed: 2026-05-16
---

# Phase 08 Plan 01: EXPECTED_TARGETS Refactor + links:validate Exit-Code Fix Summary

## One-liner

Refactor `taskfiles/links.yml` to a single `EXPECTED_TARGETS` source of truth + rewrite `links:validate` as an exit-code-bubbling shell-block, retiring the 5 cmds-spanning `{{if}}/{{end}}` template-EOF spots and the 2 bare `manifest:resolve` deps in transit.

## What This Plan Delivered

| Deliverable | Location | Verified |
|-------------|----------|----------|
| `EXPECTED_TARGETS` multiline var with 26 symlink-target paths (feature-gated via inline ternaries) | `taskfiles/links.yml` lines 65-108 | `grep -n 'EXPECTED_TARGETS:'` returns line 82 |
| `links:validate` rewritten as a single shell-block with a failures counter; exits non-zero on any failed check | `taskfiles/links.yml` lines 272-373 | `task links:validate` exits 26 (non-zero) on the worktree |
| Two bare `deps: [manifest:resolve]` references flipped to leading-colon form | `taskfiles/links.yml` claude: + configs: tasks | `grep -v '^[[:space:]]*#' \| grep -c 'deps: \[manifest:resolve\]'` returns 0 |
| Five cmds-spanning `{{if}}/{{end}}` wrappers retired (claude:, configs:, validate:) | `taskfiles/links.yml` | `grep -nE "^[[:space:]]*-[[:space:]]*'\{\{end\}\}'$"` returns 0 |
| New `configs:ghostty` internal sub-task isolating the ghostty feature gate | `taskfiles/links.yml` lines 252-260 | `yq '.tasks \| keys'` shows `- configs:ghostty` |

## Implementation Walkthrough

### Task 1: Add EXPECTED_TARGETS var + flip bare manifest:resolve deps

Added an `EXPECTED_TARGETS` multiline pipe-literal to the existing `vars:` block. The 26 entries cover:

- 5 zsh startup files (`.zshenv`, `.zprofile`, `.zshrc`, `.zlogin`, `.zlogout`) — always-on
- 1 antidote plugin manifest (`.zsh_plugins.txt`) — always-on
- 13 claude config tree entries (`CLAUDE.md`, `settings.json`, `agents`, `commands`, `skills`, 8 hooks) — `claude-marketplace` gated
- 1 ghostty config — `ghostty` gated
- 6 tool configs (`glow.yml`, `glow_style.json`, `trippy.toml`, `tlrc/config.toml`, `condarc`, `eza/theme.yaml`) — always-on

Feature-gated entries use the inline-ternary form `{{if index .MANIFEST.features "<key>"}}<path>{{end}}` so feature-off renders as an empty line that downstream consumers skip via `[[ -z "$line" ]] && continue`. Identity symlinks intentionally excluded — owned by `taskfiles/identity.yml` and validated by `identity:validate`.

Both bare `deps: [manifest:resolve]` references (claude: and configs: tasks) flipped to the leading-colon root-namespace form `deps: [":manifest:resolve"]`, matching the proven cross-taskfile dep form in `taskfiles/macos.yml validate:` and `taskfiles/packages.yml verify:`.

**Commit:** `2ea9b04`

### Task 2: Retire cmds-spanning `{{if}}/{{end}}` wrappers

Removed all 5 cmds-spanning template wrappers:

- `claude:` cmds: lines 133/160 (the `{{if index .MANIFEST.features "claude-marketplace"}}` / `{{end}}` pair around all 13 safe-link calls)
- `configs:` cmds: lines 186/189 (the `{{if index .MANIFEST.features "ghostty"}}` / `{{end}}` pair around the ghostty safe-link)
- `validate:` cmds: lines 234/261 (claude-marketplace gate) and 263/266 (ghostty gate)

For `claude:`, the existing inline-ternary `status:` block (all 13 entries claude-marketplace-gated) is sufficient: feature-off renders `true` for every status check → status passes → cmds never executes (correct no-op).

For `configs:`, the naive in-place wrapper removal would have introduced a partial-state regression: the existing `configs:` status block has 6 always-on `test -L` checks. If any of those fails (e.g., glow link missing on a server-1 machine with ghostty=false), status fails → all cmds run → including the unconditional ghostty safe-link → would create the ghostty link when the feature is off. Applied Rule 1 (auto-fix bug): hoisted the ghostty safe-link into a dedicated `configs:ghostty` internal sub-task with a task-level inline-ternary status gate. The parent `configs:` task delegates to it as the first cmds entry. This preserves the feature-off no-op contract in all states.

For `validate:`, removed the standalone `{{if}}/{{end}}` entries but kept the `_:check-link` chain in place as transit state (Task 3 rewrites the entire body).

**Commit:** `fd985f5`

### Task 3: Rewrite `links:validate` as shell-block with failures counter

Replaced the entire `_:check-link` delegation chain with a single shell-block matching the `macos:validate` analog (lines 254-305):

- `# lint-allow: cmds-without-status` marker
- `deps: [":manifest:resolve"]`
- `status: [false]` (diagnostic always-rerun)
- Pipe-literal cmds entry sourcing `{{.DOTFILES_MESSAGES}}` as the first line

The validator iterates `EXPECTED_TARGETS` line-by-line via `while IFS= read -r target; do ... done <<< "{{.EXPECTED_TARGETS}}"`. For each non-empty target:

1. If not a symlink → `cross "<target> missing"` + `failures+=1`
2. Else if not resolving (dangling) → `cross "<target> broken (target missing)"` + `failures+=1`
3. Else compare `readlink -f` to the expected SOURCE → `check "<target> linked"` on match, `cross "<target> points to wrong source (expected ..., got ...)"` + `failures+=1` on mismatch

Ends with `exit "$failures"`. Closes the `_:check-link`-always-exits-0 gap confirmed in `helpers.yml` lines 48-73 — root `task validate` (Plan 02) can now bubble `links:validate` failures via exit code.

TARGET → SOURCE mapping uses a single `resolve_source()` case statement keyed on target path patterns. Path-tail extraction (`${target##*/hooks/}` etc.) collapses the 8 claude hook entries and the 6 tool-config entries into a few glob branches without duplicating the mapping.

**Commit:** `815f426`

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Hoist ghostty safe-link into a dedicated `configs:ghostty` sub-task (instead of leaving it inline in `configs:`) | The plan's "simpler" inline approach has a partial-state regression: if any always-on `configs:` status check fails, all cmds run including the gated ghostty safe-link. The sub-task isolation preserves the feature-off no-op contract in all states. Rule 1 (auto-fix bug). |
| Single `resolve_source()` case statement for TARGET → SOURCE mapping in `links:validate` | Lower complexity than a parallel SOURCE list iterated in lockstep; glob branches collapse the 8 claude hooks and 6 tool configs into 2 case clauses. Single source of truth that mirrors the cmds: block pairings. |
| EXPECTED_TARGETS contains exactly 26 unique paths (not 27 as the plan acceptance text says) | The plan's acceptance text breakdown double-counts antidote ("6 zsh+antidote + ... + 1 antidote"). The plan's interfaces bullet list (the authoritative source) lists exactly 26 paths. |
| Keep the validate body in `claude:` task untouched; only retire the wrappers | The existing inline-ternary status block already short-circuits correctly when `claude-marketplace=false` (all 13 status entries are feature-gated; feature-off → all return true → status pass → no-op). Unlike `configs:`, there's no mixed-gating risk. |
| Inline check logic instead of delegating to `_:check-link` | `_:check-link` always exits 0 (helpers.yml lines 48-73 confirmed); the rewrite requires explicit failures-counter increment on each failure path, which is only possible with inline logic. |

## Deviations from Plan

### Rule 1 (Auto-fixed bugs)

**1. [Rule 1 - Bug] Hoisted ghostty safe-link into a dedicated `configs:ghostty` sub-task to prevent partial-state regression**

- **Found during:** Task 2 (in-place wrapper removal of `configs:` cmds: block)
- **Issue:** The plan's Action text suggested leaving the ghostty `_:safe-link` call in `configs:` cmds: unconditionally and relying on the existing inline-ternary status: block to short-circuit on feature-off. But the `configs:` status: block has 6 always-on `test -L` checks alongside the inline-ternary ghostty check; if ANY always-on check fails (e.g., glow link missing during partial-state recovery), status fails → all cmds execute → the unconditional ghostty safe-link runs even when `ghostty=false`. This would create the ghostty config symlink on a server-1 machine (feature off) — a behavioral regression vs the pre-refactor cmds-spanning wrapper, which correctly elided the ghostty cmd on feature-off.
- **Fix:** Created `configs:ghostty` as an internal sub-task with task-level inline-ternary `status:` gate. The parent `configs:` task delegates to it as the first cmds entry. The sub-task's status block is entirely ghostty-gated, so feature-off → status pass → no-op regardless of any other state.
- **Files modified:** `taskfiles/links.yml`
- **Commit:** `fd985f5`

### Acceptance-criteria refinements (documented, not silently ignored)

**1. Verification regex pattern broader than intent**

- **Where:** Task 2 acceptance and Task 3 acceptance both use `grep -nE "^[[:space:]]*-[[:space:]]*'\{\{(if|end)" taskfiles/links.yml | wc -l == 0`
- **Issue:** This regex matches both the buggy standalone `'{{if condition}}'` / `'{{end}}'` cmds: entries (true target) AND the well-formed inline-ternary status: entries like `'{{if not (...)}}true{{else}}test -L "..."{{end}}'` (correct pattern, not a bug). Strict literal application would require rewriting all 14 inline-ternary status: entries (which the plan explicitly endorses as the correct pattern).
- **Resolution:** Applied the plan's stated INTENT (no cmds-spanning template wrappers). Verified via stricter patterns: `^[[:space:]]*-[[:space:]]*'\{\{if[^']*\}\}'[[:space:]]*$` (opening-only, no closing same-line) returns 0; `^[[:space:]]*-[[:space:]]*'\{\{end\}\}'[[:space:]]*$` (standalone {{end}}) returns 0. Documented in the Self-Check section below.

**2. EXPECTED_TARGETS count: 26, not 27**

- **Where:** Task 1 acceptance text says "exactly 27 target paths (6 zsh+antidote + 13 claude + 1 ghostty + 6 tool-configs + 1 antidote)"
- **Issue:** The breakdown double-counts antidote (`6 zsh+antidote ... + 1 antidote` = 7 unique zsh-area paths, but there are only 6).
- **Resolution:** Used the authoritative bullet list in the plan's `<interfaces>` section — 26 unique paths. Documented in frontmatter `decisions`.

**3. Behavioral verify for links:validate**

- **Where:** Task 3 verify block mutates `~/.config/zsh/.zsh_plugins.txt` to test broken-symlink detection.
- **Issue:** Running inside a Claude Code worktree, the live machine's symlinks point at `/Users/josh/Git/personal/dotfiles/...` (the main repo's DOTFILEDIR), but this worktree's `{{.DOTFILEDIR}}` resolves to `.claude/worktrees/agent-.../`. Every symlink check produces a "wrong source" cross because the worktree expects worktree-prefixed paths.
- **Resolution:** The behavioral contract is verified by the worktree-vs-live-machine mismatch itself: `task links:validate` exits with status 26 (one failure per detected symlink), proving the failures counter works and `exit "$failures"` bubbles a non-zero exit. The healthy-state verification will run during phase verify when the orchestrator runs on the actual machine.

## Pre-existing Issues NOT Fixed

- `task lint` exit code is 201 both pre- and post-refactor. The 14 LINT-03a violations in pre-Phase-7 taskfiles (`brew.yml`, `common.yml`, `manifest.yml`, `profile-tasks.yml`, `profile.yml`, `shell.yml`) and the 4 LINT-03b violations (1 fixture file + 3 README documentation references + 1 in profile-tasks.yml) are documented carry-forward debt per `08-CONTEXT.md` and `07-VERIFICATION.md`. My refactor introduced zero new lint violations; `taskfiles/links.yml` itself is clean post-refactor.

## Known Stubs

None. The refactor delivers a complete, working `EXPECTED_TARGETS` catalog and a fully-functional `links:validate` shell-block. Plan 02 (root `task validate` aggregator) can compose `links:validate` and reliably detect its failures via exit code.

## Threat Flags

None. This is a pure taskfile refactor — no new network endpoints, auth paths, file access patterns, or trust-boundary surface introduced. Validated against the plan's `<threat_model>`:

- T-08-01 (Tampering on EXPECTED_TARGETS rendering): mitigated via inline-ternary `{{if cond}}path{{end}}` deterministic empty-line render + `[[ -z ]] && continue` guard in `links:validate`.
- T-08-02 (Info disclosure via readlink -f): unchanged; targets bounded to XDG dirs (user-owned).
- T-08-03 (DoS on iteration): bounded to 26 entries; O(n) shell loop.

## Commits

| Task | Hash | Summary |
|------|------|---------|
| 1 | `2ea9b04` | add EXPECTED_TARGETS var + flip bare manifest:resolve deps |
| 2 | `fd985f5` | retire cmds-spanning {{if}}/{{end}} wrappers in links.yml |
| 3 | `815f426` | rewrite links:validate as shell-block with failures counter |

## Verification Snapshot

```bash
# YAML parse
$ task --list-all --json >/dev/null && echo "ok"
ok

# Standalone {{if}} cmds: entries (bug pattern)
$ grep -nE "^[[:space:]]*-[[:space:]]*'\{\{if[^']*\}\}'[[:space:]]*$" taskfiles/links.yml | wc -l
0

# Standalone {{end}} cmds: entries (bug pattern)
$ grep -nE "^[[:space:]]*-[[:space:]]*'\{\{end\}\}'[[:space:]]*$" taskfiles/links.yml | wc -l
0

# Bare deps: [manifest:resolve] (excluding comments)
$ grep -v '^[[:space:]]*#' taskfiles/links.yml | grep -c 'deps: \[manifest:resolve\]'
0

# Leading-colon deps: [":manifest:resolve"] count
$ grep -c 'deps: \[":manifest:resolve"\]' taskfiles/links.yml
4

# EXPECTED_TARGETS presence in vars: block
$ grep -n 'EXPECTED_TARGETS:' taskfiles/links.yml
82:  EXPECTED_TARGETS: |

# links:validate exits non-zero on any failed check (proves failures counter works)
$ task links:validate >/dev/null 2>&1; echo $?
26

# links.yml-specific lint violations
$ task lint 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -E '✗.*links.yml( has|:[0-9])' | wc -l
0
```

## Self-Check: PASSED

**Files created/modified verified:**

```bash
$ [ -f taskfiles/links.yml ] && echo "FOUND: taskfiles/links.yml"
FOUND: taskfiles/links.yml
```

**Commits verified:**

```bash
$ for h in 2ea9b04 fd985f5 815f426; do
    git log --oneline --all | grep -q "$h" && echo "FOUND: $h" || echo "MISSING: $h"
  done
FOUND: 2ea9b04
FOUND: fd985f5
FOUND: 815f426
```
