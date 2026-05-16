---
phase: 8
slug: validation-cutover-readiness
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-16
---

# Phase 8 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `08-RESEARCH.md` § Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | go-task (task runner as test runner; no dedicated test framework) |
| **Config file** | `Taskfile.yml` (root) |
| **Quick run command** | `task lint` |
| **Full suite command** | `task lint && task test && task validate` |
| **Estimated runtime** | ~30 seconds (lint + test); +~10s for full `task validate` after components land |

---

## Sampling Rate

- **After every task commit:** Run `task lint`
- **After every plan wave:** Run `task lint && task test`
- **Before `/gsd:verify-work`:** Full suite must be green: `task lint && task test && task validate`, plus a real `task install` run on `personal-laptop`
- **Max feedback latency:** ~30 seconds for the per-task lint loop

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| _populated by planner_ | _PLAN.md_ | _wave_ | _REQ-ID_ | _T-08-XX / —_ | _expected secure behavior_ | _smoke / static / integration_ | `_command_` | TBD | pending |

*Status: pending / green / red / flaky*

*Planner: fill this table from each PLAN.md's tasks; reference the rows in 08-RESEARCH.md § Phase Requirements to Test Map as the authoritative source for command shape.*

---

## Wave 0 Requirements

- [ ] No new test files needed — Phase 8 validates itself through the existing `task lint` / `task test` / `task validate` pipeline and the D-03 real-install run on `personal-laptop`

*Existing infrastructure (taskfile lint, helper checks, real install on personal-laptop) covers all phase requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `task validate` prints summary table with per-component check/cross | CUTV-01 | Output format is operator-readable; visual confirmation is the spec | Run `task validate` on a healthy machine; confirm one row per component with check (green) markers |
| Orphan-warning text appears at end of `task install` | CUTV-08 | Install output is human-facing; we want to see the exact warning text | Create an orphan symlink under `$DOTFILEDIR`, run `task install`, confirm warning prints and exit code is 0 |
| `links:reconcile -- --remove` interactive y/N prompts work at a TTY | CUTV-07 | Interactive prompt cannot be fully scripted without a pty wrapper | Create 2 orphans, run `task links:reconcile -- --remove`, answer y to first / N to second, confirm only the y'd link is removed |
| Per-machine fresh-install verification procedure works on a clean Mac | DOCS-08 / CUTV-04 | Requires a clean macOS install; cannot be automated in CI | Follow steps in `docs/CUTOVER.md` § "Fresh-machine verification" on a freshly imaged Mac |
| 7-day soak per machine before declaring cut over | CUTV-05 | Calendar-driven; not a test command | Update `docs/CUTOVER.md` per-machine state table as each machine crosses its 7-day mark |
| v1 repo archive (renamed, not deleted) after last machine cuts over | CUTV-06 | Cross-repo manual git operation; out of scope for taskfile automation | Run the documented `git remote rename` / directory move sequence in `docs/MIGRATION.md` § "Archiving v1" |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (no Wave 0 needed for Phase 8)
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s for per-task lint loop
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
