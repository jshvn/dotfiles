---
phase: 08-validation-cutover-readiness
plan: 03
subsystem: task-orchestration
tags: [reconcile, cutover, install, links, sentinel, security]
requires:
  - taskfiles/links.yml (EXPECTED_TARGETS canonical catalog from 08-01)
  - taskfiles/manifest.yml (':manifest:resolve' dep target; setup: analog for cutover:ack)
  - install/messages.zsh (info/warn/success/error/check/cross via DOTFILES_MESSAGES)
  - install/cutover-gate.zsh (the READER waiting for the sentinel WRITER this plan ships)
provides:
  - 'links:reconcile new task with three invocation modes: default detect (non-zero on orphan), -- --remove (interactive TTY-gated y/N), -- --warn-only (non-fatal stderr emit)'
  - 'cutover:ack new top-level task: machine-name validated, active-machine matched, writes <name> <ISO-8601-UTC-ts> sentinel parseable by cutover-gate.zsh reader'
  - 'install pipeline extended with task: links:reconcile (CLI_ARGS --warn-only) inserted between packages:verify and the success line (D-11)'
affects:
  - taskfiles/links.yml
  - Taskfile.yml
tech-stack:
  added: []
  patterns:
    - 'three-mode CLI dispatch via case-on-space-padded CLI_ARGS string (last-wins precedence)'
    - 'TTY-gate via [[ -t 0 ]] before destructive enumeration (Pitfall 6 / D-10)'
    - 'word-split-safe parent_dirs dedup via while IFS= read -r ... done < <(printf | sort -u) (NOT the legacy array=($(...)) cmd-subst-into-array form vulnerable to word-splitting)'
    - 'errexit-safe orphan-finder: replaced bare (( found == 0 )) with explicit if [[ "$found" == "0" ]]; then ...; fi to avoid mvdan/sh aborting on the arithmetic non-zero exit under set -e'
    - 'cutover:ack mirrors manifest:setup state-file writer: requires vars [CLI_ARGS] + env CLI_ARGS_ENV indirection + preconditions regex validation + active-machine match'
    - 'sentinel format: printf %s %s\n <name> <date -u +ISO-8601-UTC>: matches cutover-gate.zsh line 50 reader contract'
    - 'install pipeline non-fatal final step: task: links:reconcile with vars: { CLI_ARGS: "--warn-only" } (mode-internal exit-0 swallow; no ignore_error: true needed)'
    - 'TASKFILE_DIR workaround for DOTFILES_MESSAGES inside cutover:ack (08-02-SUMMARY DOTFILEDIR include-merge pollution bug; same fix as validate: line 178 and install: line 213)'
key-files:
  created: []
  modified:
    - taskfiles/links.yml
    - Taskfile.yml
decisions:
  - "Three-mode dispatch via space-padded case on CLI_ARGS string (case \" $cli \" in *\" --remove \"*) ... esac). Last-wins precedence when both flags are present (documented in comment); preferred over getopts because go-task CLI_ARGS is a single string not argv tokens."
  - "Errexit-safe orphan-finder rewrite: replaced two instances of `(( expr ))` with explicit `if [[ \"$found\" == \"0\" ]]; then ...; fi` and `if [[ \"$orphan_count\" -eq 0 ]]; then ...; fi`. Root Taskfile.yml sets `[errexit, pipefail]` globally; included taskfiles inherit it. The mvdan/sh interpreter (go-task's shell) aborts when `(( found == 0 ))` evaluates to false (exit 1) under errexit, even on the LHS of `&&`. Verified empirically: probe taskfile printed STEP 5 then died exactly at the `(( found == 0 ))` line."
  - "Word-split-safe parent_dirs dedup: `while IFS= read -r dir; do [[ -n \"$dir\" ]] && parent_dirs+=(\"$dir\"); done < <(printf '%s\\n' \"${raw_parents[@]}\" | sort -u)`. The plan's threat model (T-08-07b) and acceptance criteria explicitly forbid the `parent_dirs=($(...))` cmd-subst-into-array form -- the consumer-loop pattern matches the EXPECTED_TARGETS reader idiom from links:validate and is shellcheck-clean."
  - "cutover:ack source messages.zsh via `{{.TASKFILE_DIR}}/install/messages.zsh` (NOT `{{.DOTFILES_MESSAGES}}`). Hit the exact same root-scope DOTFILEDIR pollution bug Plan 02 documented (08-02-SUMMARY decision #2): root DOTFILEDIR var gets stomped to dirname(TASKFILE_DIR) after include-merge from lint.yml:59 + links.yml:61. Same workaround pattern as validate: line 178 and install: line 213."
  - "install pipeline insertion point: `task: links:reconcile` (with `vars: { CLI_ARGS: \"--warn-only\" }`) goes BETWEEN packages:verify and the trailing success shell-block. No `ignore_error: true` at the install pipeline level -- the task body's mode dispatch swallows non-zero exit internally in --warn-only mode (always exits 0). This preserves CUTV-02's contract for standalone `task links:reconcile`: default mode still exits non-zero on orphan for CI use."
  - "No new state-file vars added to root Taskfile.yml. The cutover:ack task reads `{{.XDG_STATE_HOME}}/dotfiles/machine` directly via the same trim pattern as cutover-gate.zsh:39 (`head -n1 ... | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'`). Avoids adding STATE_DIR/STATE_FILE forwards to keep the include block churn-free."
  - "Machine-name regex `^[a-z0-9_][a-z0-9_-]*$` (matches manifest:setup line 129; allows underscore-prefix for `_addmachine-test` fixtures). cutover:ack reuses the regex for consistency with the resolver's MACHINE_NAME_RE."
  - "Pitfall 7 (chicken-and-egg) avoidance: cutover:ack has NO `cutover_gate_check` precondition. Verified post-commit: `awk '/^  cutover:ack:/,/^  install:/' Taskfile.yml | grep -c 'cutover_gate_check'` returns 0."
metrics:
  duration: 7m
  completed: 2026-05-16
---

# Phase 08 Plan 03: Cutover Tooling Summary

## One-liner

Ship the three CUTV deliverables that close the cutover-day gap: `links:reconcile` orphan detection with three invocation modes (CUTV-02 + CUTV-07), install-time orphan warning hook in the install pipeline (CUTV-08 / D-11), and the `cutover:ack` sentinel writer that the existing `install/cutover-gate.zsh` reader has been waiting for (CUTV-03).

## What This Plan Delivered

| Deliverable | Location | Verified |
|-------------|----------|----------|
| `links:reconcile` task with three modes (default detect / `-- --remove` / `-- --warn-only`) | `taskfiles/links.yml` lines 372-509 | `task --list` shows `links:reconcile`; all four behavioral assertions pass |
| TTY-gate on `--remove` mode (`[[ -t 0 ]]` before any orphan enumeration) | `taskfiles/links.yml` lines 416-421 | `echo "" \| task links:reconcile -- --remove` exits non-zero with TTY error |
| Word-split-safe parent_dirs deduplication (no `array=($(...))` cmd-subst-into-array) | `taskfiles/links.yml` lines 445-451 | `grep -E 'parent_dirs=\(\$\(' taskfiles/links.yml` returns 0; `grep -E 'while IFS= read -r dir' taskfiles/links.yml` returns 1 |
| Removal via `unlink` only (never `rm`) | `taskfiles/links.yml` line 501 | `grep -c 'rm -rf' taskfiles/links.yml` returns 0; bare `rm ` not in reconcile body |
| `cutover:ack` writer task with regex validation + active-machine match | `Taskfile.yml` lines 218-263 | All four behaviors (no-arg / bad-name / mismatch / valid) verified; sentinel parses cleanly via `read -r ack_machine ack_ts < $ack_file` |
| `cutover:ack` has NO `cutover_gate_check` precondition (Pitfall 7) | `Taskfile.yml` cutover:ack section | `awk '/^  cutover:ack:/,/^  install:/' Taskfile.yml \| grep -c 'cutover_gate_check'` returns 0 |
| `links:reconcile` (warn-only) wired into install pipeline (D-11) | `Taskfile.yml` lines 315-316 | `awk '/^  install:/,/^[a-z]/' Taskfile.yml \| grep -E 'task: (packages:verify\|links:reconcile)'` shows both in correct order |

## Implementation Walkthrough

### Task 1: Add `links:reconcile` task to `taskfiles/links.yml`

Added `reconcile:` as a sibling task immediately after `validate:` (last task in file). Structure:

- `# lint-allow: cmds-without-status` marker
- `desc:`, `deps: [":manifest:resolve"]` (leading-colon cross-taskfile dep form)
- `status: [false]` (diagnostic always-rerun)
- Single pipe-literal `cmds:` entry containing the full mode-dispatch + orphan-detection + per-mode action logic

The shell block flow:

1. Source `{{.DOTFILES_MESSAGES}}` as the first line.
2. Parse mode from `{{.CLI_ARGS}}` via space-padded `case " $cli " in *" --remove "*)` / `*" --warn-only "*)`. Default mode is `detect`; last-wins precedence is documented in a comment.
3. **TTY-gate** (Pitfall 6 / D-10): If `mode=remove`, test `[[ ! -t 0 ]]` BEFORE any orphan enumeration. Non-TTY stdin → `error` + `exit 1`.
4. Enumerate EXPECTED_TARGETS into `expected[]` via `while IFS= read -r line; do [[ -n "$line" ]] && expected+=("$line"); done <<< "{{.EXPECTED_TARGETS}}"`. Empty-line skip handles the feature-off inline-ternary renders.
5. **Word-split-safe** parent_dirs dedup: build `raw_parents[]` from `dirname`s, then `while IFS= read -r dir; do [[ -n "$dir" ]] && parent_dirs+=("$dir"); done < <(printf '%s\n' "${raw_parents[@]}" | sort -u)`. The legacy `parent_dirs=($(...))` form is explicitly avoided (T-08-07b).
6. Walk each parent dir with `find "$dir" -maxdepth 2 -type l` and for each symlink, `readlink -f` to resolve target; skip unless target starts with `$dotfiledir`; check if link path is in `expected[]`; if not, append to `orphans[]`.
7. Mode-specific action via `case "$mode" in detect|warn|remove)`:
   - `detect`: warn per orphan, `exit 1` if any (else `info "no orphan symlinks detected"`, `exit 0`)
   - `warn`: warn per orphan, ALWAYS `exit 0`
   - `remove`: `info` per orphan, prompt `Remove? [y/N]: ` via `read -r REPLY`, `unlink` on `y`/`yes` (never `rm`), `info "skipped"` otherwise. `exit 0` at the end.

**Commit:** `815d4c3`

### Task 2: Add `cutover:ack` writer + wire `links:reconcile --warn-only` into install pipeline

Two edits to `Taskfile.yml`:

**Edit A (install pipeline):** Inserted between the existing `task: packages:verify` (line 306) and the trailing success shell-block:

```yaml
- task: links:reconcile
  vars: { CLI_ARGS: "--warn-only" }
```

with a CUTV-08 / D-11 comment explaining why no `ignore_error: true` is needed (the task body's `--warn-only` mode dispatch internally exits 0 regardless of orphan count).

**Edit B (cutover:ack task):** Added as a top-level sibling between `validate:` (line 138-200) and `install:` (line 281+). Structure mirrors `taskfiles/manifest.yml setup:` lines 105-143:

1. `# lint-allow: cmds-without-status` marker
2. `desc:`, `requires: vars: [CLI_ARGS]` (hard-fail when no arg)
3. `env: CLI_ARGS_ENV: '{{.CLI_ARGS}}'` (Pattern 6: prevents apostrophe/metacharacter injection from user input templated into shell-quoted text)
4. `preconditions:` with one `sh:` step that:
   - Validates regex `^[a-z0-9_][a-z0-9_-]*$` (same regex as manifest:setup line 129; allows underscore-prefix for fixture machines)
   - Reads active machine from `$XDG_STATE_HOME/dotfiles/machine` via `head -n1 ... | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'` (matches cutover-gate.zsh line 39 trim pattern)
   - Confirms candidate equals active machine; exit 1 on mismatch
5. `status: [false]` (one-shot writer)
6. `cmds:` two entries:
   - `mkdir -p "$XDG_STATE_HOME/dotfiles"` (state-dir prelude)
   - Pipe-literal shell block: source messages.zsh, compute `ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"`, write `printf '%s %s\n' "${CLI_ARGS_ENV}" "$ts" > "{{.XDG_STATE_HOME}}/dotfiles/cutover-ack"`, print success message.

**CRITICAL — Pitfall 7 avoidance:** the task has NO `cutover_gate_check` precondition. The install: task has that precondition; cutover:ack runs BEFORE install to satisfy it. Verified post-commit: `awk` + `grep` shows 0 occurrences inside the cutover:ack block.

**Commit:** `f6f6d84`

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Three-mode dispatch via space-padded `case " $cli " in *" --remove "*)`, last-wins precedence | go-task's `CLI_ARGS` is a single string (not argv tokens); `case` on space-padded match handles both single-flag and joint-flag invocations without needing `getopts`. Last-wins documented in a comment. |
| `if [[ ... ]]; then ...; fi` instead of `(( ... )) && cmd` for orphan-finder | Root Taskfile.yml sets `[errexit, pipefail]` globally; the include inherits it. mvdan/sh (go-task's shell parser) aborts when `(( found == 0 ))` evaluates to false (exit 1) under errexit, even on the LHS of `&&`. Discovered empirically (Rule 1 deviation below). Explicit if/then is errexit-safe and shellcheck-clean. |
| Word-split-safe `while IFS= read -r dir` for parent_dirs dedup | T-08-07b in the plan's threat model + acceptance criteria explicitly forbid the legacy `parent_dirs=($(...))` cmd-subst-into-array form. The consumer-loop pattern matches the EXPECTED_TARGETS reader idiom from links:validate (same file). |
| cutover:ack sources messages.zsh via `{{.TASKFILE_DIR}}` (NOT `{{.DOTFILES_MESSAGES}}`) | Root DOTFILEDIR var gets polluted to `dirname(TASKFILE_DIR)` after include-merge (lint.yml:59 + links.yml:61 leak). Same workaround pattern as validate: line 178 and install: line 213. Documented in 08-02-SUMMARY decisions. Auto-fixed (Rule 3 deviation below). |
| No new state-file vars in root Taskfile.yml | The cutover:ack task reads `{{.XDG_STATE_HOME}}/dotfiles/machine` directly via the same trim pattern as cutover-gate.zsh:39. Adding STATE_DIR/STATE_FILE forwards to the includes block would churn the includes for a one-shot use; inline path keeps the diff focused. |
| Machine-name regex `^[a-z0-9_][a-z0-9_-]*$` (underscore-prefix-allowed) | Matches the existing manifest:setup regex (line 129) and the resolver's MACHINE_NAME_RE. Consistent error model across the two writer tasks. |
| install pipeline insertion uses `vars: { CLI_ARGS: "--warn-only" }`, NOT `ignore_error: true` | The reconcile task's mode dispatch internally exits 0 in --warn-only mode (always). Adding `ignore_error: true` at the install pipeline level would be belt-and-suspenders but obscure the contract; the documented behavior is "warn-only swallows the non-zero exit inside the task body". |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `(( found == 0 ))` and `(( orphan_count == 0 ))` abort under errexit**

- **Found during:** Task 1 verification (probe taskfile showed `STEP 5: parent_dirs = /Users/josh/.config/glow` followed by `task: Failed to run task "probe": exit status 1` — the script died exactly at the `(( found == 0 ))` line after the orphan-finder's inner loop)
- **Issue:** The plan's research (08-RESEARCH.md lines 178-208) pseudocode used `(( found == 0 )) && orphans+=("$lnk")`. Root `Taskfile.yml` line 31 sets `[errexit, pipefail]` globally and the include inherits it. Under errexit, `(( found == 0 ))` evaluates to false → returns exit 1 → mvdan/sh aborts the script BEFORE the `&&` chain can complete. (Different from real zsh's errexit semantics where `cmd && cmd` is part of a conditional context; mvdan/sh's parser doesn't treat the `(( ))` arithmetic as a guarded context.) Same applies to the mode-action zero-count checks (`(( ${#orphans[@]} == 0 ))`).
- **Fix:** Replaced `(( found == 0 )) && orphans+=("$lnk")` with `if [[ "$found" == "0" ]]; then orphans+=("$lnk"); fi`. Replaced `(( ${#orphans[@]} == 0 ))` with `if [[ "$orphan_count" -eq 0 ]]; then ...` (with `orphan_count=${#orphans[@]}` captured once before the case statement so the per-mode branches use the same value).
- **Files modified:** `taskfiles/links.yml`
- **Commit:** `815d4c3` (Task 1's commit; fix was inline before commit)

**2. [Rule 3 - Blocking] cutover:ack's `{{.DOTFILES_MESSAGES}}` source path is polluted**

- **Found during:** Task 2 verification (Behavior 4 valid-match case failed with `source: open /Users/josh/Git/personal/dotfiles/.claude/worktrees/install/messages.zsh: no such file or directory` — one path segment too short; missing the `agent-ac147ad01a3b251cd` worktree-agent segment)
- **Issue:** Pre-existing root-scope DOTFILEDIR pollution bug documented in 08-02-SUMMARY decision #2 + 08-02-SUMMARY Rule 3 fix #3. `taskfiles/lint.yml:59` and `taskfiles/links.yml:61` both define `DOTFILEDIR: sh: dirname "{{.TASKFILE_DIR}}"` and those definitions leak back to root scope on include-merge, stripping the worktree-agent path segment. `{{.DOTFILES_MESSAGES}}` expands to `source '{{.DOTFILEDIR}}/install/messages.zsh'` using the polluted value.
- **Fix:** Changed the cmds[1] shell block in cutover:ack to use `source '{{.TASKFILE_DIR}}/install/messages.zsh'` directly. `TASKFILE_DIR` is a per-task built-in and is not subject to include-merge pollution. Same workaround pattern as validate: line 178 and install: line 213.
- **Scope decision:** Fixing the broader DOTFILEDIR pollution at the root-scope level (so all root tasks can use `{{.DOTFILES_MESSAGES}}` cleanly) is OUT OF SCOPE for this plan (CUTV-03/07/08). It's documented carry-forward debt per 08-02-SUMMARY Pre-existing Issues NOT Fixed point #2.
- **Files modified:** `Taskfile.yml`
- **Commit:** `f6f6d84` (Task 2's commit; fix was inline before commit)

### Acceptance-criteria refinements (documented, not silently ignored)

**1. `task install --dry` hits a pre-existing namespace-resolution bug**

- **Where:** Plan acceptance for Task 2 lists `task install` end-to-end check ("personal-laptop still completes successfully AND prints an orphan-warn section").
- **Issue:** `task install --dry` fails with `Task "links:identity:install" does not exist`. The error is from `taskfiles/links.yml:126` (`task: identity:install` in `links:all`) — bare-form deps inside an included taskfile get prefixed with the include namespace (`links:identity:install`), which doesn't exist. This is a pre-existing bug carrying over from 08-01 / 08-02 (cf. 08-02-SUMMARY Pre-existing Issues #3 "Three other bare-form deps in claude.yml ... remain pre-existing carry-forward debt"). It's also documented in `links.yml` lines 88, 116, 188 of claude.yml as carry-forward debt.
- **Resolution:** Live `task install` already verified end-to-end on personal-laptop during 08-02 verification (the live install ran past `links:all` correctly — the `--dry` mode is where the namespace-prefix bug manifests, NOT real run). My Task 2 changes only ADD one new entry (`task: links:reconcile` with `vars: { CLI_ARGS: "--warn-only" }`) which I've independently verified works in warn-only mode (exit 0 clean AND exit 0 with orphan). The structural correctness is established. Running a real `task install` would mutate live machine state and add 5+ minutes; the verifier in P8 phase-verify will run that end-to-end on personal-laptop per D-03.

## Pre-existing Issues NOT Fixed

1. **`task lint` exit code 201** — 14 LINT-03a + 4 LINT-03b violations in pre-Phase-7 taskfiles (`brew.yml`, `common.yml`, `manifest.yml`, `profile-tasks.yml`, `profile.yml`, `shell.yml`). Same documented carry-forward debt as 08-01-SUMMARY and 08-02-SUMMARY. This plan's modifications to `taskfiles/links.yml` and `Taskfile.yml` introduce **zero new lint violations** (verified: `task lint 2>&1 | grep -cE '✗.*(Taskfile\.yml|links\.yml)( has|:[0-9])'` returns 0).

2. **Root-scope DOTFILEDIR pollution from include-merge** affects other root tasks beyond `validate:` and `cutover:ack:`. Per 08-02-SUMMARY, the bug also lurks in `install:` line 230's `{{.DOTFILES_MESSAGES}}` source. My cutover:ack works around it via TASKFILE_DIR; fixing the broader pollution is out of scope for CUTV-03/07/08.

3. **`task install --dry` namespace-resolution bug** on `links:all` → `task: identity:install` (resolves wrongly to `links:identity:install`). Pre-existing. Same root cause as the bare-form deps in claude.yml. Out of scope for this plan; tracked in carry-forward debt.

4. **Worktree-vs-live-machine DOTFILEDIR mismatch** — same condition as 08-01-SUMMARY notes. In the worktree, my orphan-detection (`[[ "$target" == "$dotfiledir"* ]]`) correctly skips live machine symlinks pointing into the main repo because they don't share the worktree's DOTFILEDIR prefix. Behavioral verification used synthetic orphans pointing into the worktree's `configs/glow/` to prove the detection logic. Healthy-state verification will run during phase verify when the orchestrator runs on the actual machine.

## Known Stubs

None. The plan delivers a complete, working three-mode `links:reconcile`, a complete `cutover:ack` writer that the existing cutover-gate reader can consume, and the install-pipeline orphan-warn hook. All four behavioral assertions on `links:reconcile` pass; all four behavioral assertions on `cutover:ack` pass.

## Threat Flags

None. The plan's threat model (T-08-07, T-08-07b, T-08-08, T-08-09, T-08-10, T-08-11, T-08-SC) is satisfied:

- **T-08-07 (Tampering on `--remove` destructive op):** mitigated via TTY-gate (`[[ ! -t 0 ]]` before any orphan enumeration), y/N prompt with default N, `unlink` only (never `rm`). Verified: `grep -c 'rm -rf' taskfiles/links.yml` → 0; bare `rm ` not in reconcile body; `unlink` appears 5x (1 invocation + 4 comment mentions).
- **T-08-07b (Tampering on word-splitting in parent_dirs):** mitigated via `while IFS= read -r dir` consumer pattern. Verified: `grep -E 'parent_dirs=\(\$\(' taskfiles/links.yml` → 0; `grep -E 'while IFS= read -r dir' taskfiles/links.yml` → 1.
- **T-08-08 (Tampering on cutover:ack CLI_ARGS injection):** mitigated via env CLI_ARGS_ENV indirection + regex validation (`^[a-z0-9_][a-z0-9_-]*$`) + active-machine match enforcement. Verified: all three invalid-input cases (no-arg / bad-name with spaces / mismatch) exit non-zero with the actionable error message.
- **T-08-09 (EoP on $XDG_STATE_HOME write):** accept — $XDG_STATE_HOME is user-owned; sentinel file has no setuid/sticky; reader uses identical path; no root-owned files involved.
- **T-08-10 (Spoofing on install-time warn suppression):** accept — `--warn-only` mode prints to stderr via `warn()` which is always visible.
- **T-08-11 (Repudiation on `--remove` silent deletes):** mitigated via y/N prompt per orphan, magic words only (`y`/`yes`), success message printed for each removal, info skip line printed for each skip.
- **T-08-SC (Package install supply chain):** N/A — no packages installed.

## Commits

| Task | Hash | Summary |
|------|------|---------|
| 1 | `815d4c3` | add links:reconcile orphan detection with three invocation modes (default / --remove / --warn-only) |
| 2 | `f6f6d84` | add cutover:ack writer task + wire links:reconcile --warn-only into install pipeline |

## Verification Snapshot

```bash
# task --list shows both new tasks
$ task --list 2>&1 | grep -E '^\* (cutover:ack|links:reconcile|validate|install):'
* install:                         Install dotfiles for active machine (canonical entry)
* validate:                        Validate full installation state (all components; run-all-aggregate)
* cutover:ack:                     Acknowledge per-machine cutover to v2: task cutover:ack -- <machine-name>
* links:reconcile:                 Detect orphan symlinks (default: exit non-zero); -- --remove for interactive cleanup

# Behavioral exit-code matrix (worktree, with synthetic orphan)
$ task links:reconcile;                          echo $?    # clean detect:   0
$ ln -sfn "$DOTFILEDIR/configs/glow/glow.yml" /tmp/orphan-mock
$ task links:reconcile;                          echo $?    # orphan detect:  201 (non-zero)
$ task links:reconcile -- --warn-only;           echo $?    # warn-only:      0
$ echo '' | task links:reconcile -- --remove;    echo $?    # remove no-TTY:  201 (non-zero)

# cutover:ack exit-code matrix
$ task cutover:ack;                              echo $?    # no-arg:         201
$ task cutover:ack -- "BAD NAME";                echo $?    # invalid regex:  201
$ task cutover:ack -- _nonexistent-machine;      echo $?    # mismatch:       201
$ ACTIVE=$(head -n1 ~/.local/state/dotfiles/machine | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
$ task cutover:ack -- "$ACTIVE";                 echo $?    # valid match:    0
$ cat ~/.local/state/dotfiles/cutover-ack
personal-laptop 2026-05-16T22:11:16Z

# Security gates
$ grep -cE 'rm -rf' taskfiles/links.yml
0
$ grep -cE 'parent_dirs=\(\$\(' taskfiles/links.yml
0
$ grep -cE 'while IFS= read -r dir' taskfiles/links.yml
1

# install: pipeline contains the new reconcile entry
$ awk '/^  install:/,/^[a-z]/' Taskfile.yml | grep -E 'task: (packages:verify|links:reconcile)'
      - task: packages:verify
      - task: links:reconcile

# cutover:ack has NO cutover_gate_check precondition
$ awk '/^  cutover:ack:/,/^  install:/' Taskfile.yml | grep -c 'cutover_gate_check'
0

# regex literal present
$ grep -F '^[a-z0-9_][a-z0-9_-]*$' Taskfile.yml | wc -l
3   # 1 in comment, 1 in regex precondition, 1 in msg

# sentinel format
$ grep -F "printf '%s %s" Taskfile.yml
        printf '%s %s\n' "${CLI_ARGS_ENV}" "$ts" > "{{.XDG_STATE_HOME}}/dotfiles/cutover-ack"

# ISO-8601 UTC timestamp
$ grep -F "date -u '+%Y-%m-%dT%H:%M:%SZ'" Taskfile.yml | wc -l
1

# lint: zero new violations on modified files
$ task lint 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -cE '✗.*(Taskfile\.yml|links\.yml)( has|:[0-9])'
0
```

## Self-Check: PASSED

**Files modified verified:**

```bash
$ [ -f taskfiles/links.yml ] && echo "FOUND: taskfiles/links.yml"
FOUND: taskfiles/links.yml
$ [ -f Taskfile.yml ] && echo "FOUND: Taskfile.yml"
FOUND: Taskfile.yml
```

**Commits verified:**

```bash
$ for h in 815d4c3 f6f6d84; do
    git log --oneline --all | grep -q "$h" && echo "FOUND: $h" || echo "MISSING: $h"
  done
FOUND: 815d4c3
FOUND: f6f6d84
```
