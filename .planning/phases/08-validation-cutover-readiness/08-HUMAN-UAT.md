---
status: partial
phase: 08-validation-cutover-readiness
source: [08-VERIFICATION.md (re-verified after 8 fixes)]
started: 2026-05-16T22:35:00Z
updated: 2026-05-16T23:00:00Z
---

## Current Test

[awaiting operator-driven cutover runbook (multi-week window)]

## Tests

### 1. CR-01 (BLOCKER) -- Fresh-install procedure
expected: bootstrap.zsh exits cleanly on a fresh machine; documented 5-step setup runs end-to-end
result: resolved (commit 30477ac: cutover-gate.zsh returns 0 when machine file absent; bootstrap path validated)

### 2. CR-02 (BLOCKER) -- claude.yml jq selectors disagree
expected: status/install/validate use the SAME jq field selector on plugin objects
result: resolved (commit 7e8f3f3: line 133 plugin selector unified to .id == $i; marketplace selector at line 125 intentionally remains .name since it targets a different jq object)

### 3. CR-03 (BLOCKER) -- claude:validate exits 0 on missing CLI
expected: per-component validate exits non-zero when CLI/jq missing so aggregator renders cross
result: resolved (commit d226211: rc=1 tracking + exit "$rc" at end of cmds[0])

### 4. CR-04 (BLOCKER) -- links.yml configs: status omits ghostty
expected: configs: re-checks every link in scope including ghostty
result: resolved (commit 2f52d82: inline-ternary status entry added for ghostty, mirrors claude: pattern)

### 5. CUTV-04 -- All four machines install end-to-end with task validate exiting 0
expected: personal-laptop, work-laptop, server-1, server-2 each complete `task install` -> `task validate` with all six per-component rows green
result: pending (operator-driven; requires SSH access to remote machines; ~28+ calendar day window)

### 6. CUTV-05 -- Each machine soaked >= 7 days on v2 without falling back to v1
expected: each row in docs/CUTOVER.md per-machine table shows days-on-v2 >= 7 with no rollback events before status transitions to cut-over
result: pending (operator-driven; per-machine soak window)

### 7. CUTV-06 -- v1 repository archived (renamed, not deleted) after last machine cut over
expected: all four rows show status archived; git ls-remote origin 'refs/heads/archive/v1' returns a ref; v1 local clones renamed not deleted
result: pending (operator-driven; cross-repo manual git operation)

### 8. WR-04 single-pass validate aggregator smoke test
expected: task validate output appears once per component (not duplicated), summary table renders, server-1 claude row shows n/a, aggregate exit code reflects per-component failures
result: pending (post-fix smoke test on a real machine; deferred to first cutover-task execution)

## Summary

total: 8
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0
resolved: 4

## Gaps

- All 4 engineering gaps (CR-01..CR-04) resolved by commits 30477ac, 7e8f3f3, d226211, 2f52d82
- 3 operator-driven items remain pending until per-machine cutover runbook executes (Plan 08-06; deferred to operator)
- 1 post-fix smoke test deferred to first real-machine cutover (WR-04 validate single-pass refactor)
