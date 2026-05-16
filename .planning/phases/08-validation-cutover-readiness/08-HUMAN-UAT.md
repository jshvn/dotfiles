---
status: partial
phase: 08-validation-cutover-readiness
source: [08-VERIFICATION.md]
started: 2026-05-16T22:35:00Z
updated: 2026-05-16T22:35:00Z
---

## Current Test

[awaiting human testing / decision]

## Tests

### 1. CR-01 (BLOCKER) — Fresh-install procedure cannot complete as documented
expected: `bootstrap.zsh` exits cleanly when the machine sentinel file does not exist (so the documented 5-step setup `clone -> bootstrap -> setup -> cutover:ack -> install` actually runs end-to-end on a fresh machine)
result: pending (`install/cutover-gate.zsh:35-38` returns 1 when sentinel missing; `bootstrap.zsh:111-112` `cutover_gate_check || exit 1` aborts; documented procedure in `docs/CUTOVER.md:33-38` and `README.md:24-36` is wrong)

### 2. CR-02 (BLOCKER) — claude.yml jq selectors disagree
expected: marketplace task status, install, and validate blocks all use the SAME jq field selector for the same plugin object (`.id == $i` everywhere or `.name == ...` everywhere)
result: pending (`taskfiles/claude.yml:127` uses `select(.name == "ecc@ecc")` while lines 150 and 277 use `select(.id == $i)` — reintroduces the v1 macos:shell:145 idempotency regression class)

### 3. CR-03 (BLOCKER) — claude:validate reports `cross` then `exit 0` on missing CLI
expected: when the claude CLI is missing, the per-component validate exits non-zero so the root `task validate` aggregator renders `cross` in the summary table (CUTV-01 check/cross contract)
result: pending (`taskfiles/claude.yml:240-245` prints `cross` then `exit 0`; aggregator captures rc=0 and renders green)

### 4. CR-04 (BLOCKER) — links.yml configs: status omits ghostty
expected: `task configs` re-checks every link in its scope; on a ghostty=true machine where only the ghostty link is broken, `task configs` invokes `configs:ghostty` and repairs it
result: pending (`taskfiles/links.yml:241-247` status block lists only the 6 always-on links; status pass short-circuits the entire cmds block; partial-state regression class the file's own header at 25-30 warns against)

### 5. CUTV-04 — All four target machines install end-to-end with `task validate` exiting 0
expected: personal-laptop, work-laptop, server-1, server-2 each complete `task install` → `task validate` with all six per-component rows green (after CR-01..CR-04 are resolved)
result: pending (operator-driven; requires SSH access to remote machines)

### 6. CUTV-05 — Each machine soaked >= 7 days on v2 without falling back to v1
expected: each row in `docs/CUTOVER.md` per-machine table shows `days-on-v2 >= 7` with no rollback events before the row transitions to `cut-over`
result: pending (operator-driven; ~28+ calendar day window)

### 7. CUTV-06 — v1 repository archived (renamed, not deleted) after last machine cut over
expected: all four rows in `docs/CUTOVER.md` show status `archived`; `git ls-remote origin 'refs/heads/archive/v1'` returns a ref; v1 local clones renamed not deleted
result: pending (operator-driven; cross-repo manual git operation)

## Summary

total: 7
passed: 0
issues: 4
pending: 3
skipped: 0
blocked: 0

## Gaps

- CR-01: BLOCKER — documented fresh-install procedure cannot complete (reader-side: cutover-gate.zsh + bootstrap.zsh; writer-side: docs/CUTOVER.md + README.md)
- CR-02: BLOCKER — claude.yml jq selectors disagree across status/install/validate
- CR-03: BLOCKER — claude:validate prints cross then exits 0
- CR-04: BLOCKER — links.yml configs: status omits ghostty entry
