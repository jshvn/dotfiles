---
phase: 08-validation-cutover-readiness
plan: 06
subsystem: cutover
tags: [cutover, soak, operator, multi-machine, runbook, deferred]

# Dependency graph
requires:
  - phase: 08-validation-cutover-readiness
    provides: "Wave 1-5 engineering: validate aggregator, links:reconcile, cutover:ack writer, CUTOVER.md/MACHINES.md/MIGRATION.md/README.md"
provides:
  - "Operator runbook executed and per-machine cutover state recorded in docs/CUTOVER.md (deferred to operator)"
affects: [milestone-v1.0 completion, REQUIREMENTS.md status for CUTV-04/05/06]

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified: []

key-decisions:
  - "Tasks 1-5 are operator-driven (~28+ day calendar window) and cannot be executed inside an agent invocation per the plan's autonomous=false contract."
  - "CUTV-04, CUTV-05, CUTV-06 remain Pending in REQUIREMENTS.md until the operator marks each docs/CUTOVER.md row through the planning -> ready -> installing -> soaking -> cut-over -> archived progression and commits."
  - "Phase 8 engineering deliverables (Waves 1-5) are complete and verified; this SUMMARY records the deferral so traceability is not lost when the phase is marked complete in ROADMAP."

patterns-established: []

requirements-completed: []

# Metrics
duration: deferred
completed: deferred
---

# Phase 08 Plan 06 Summary

**Operator-driven per-machine cutover runbook deferred -- engineering complete (Waves 1-5); CUTV-04/05/06 pending operator execution of the 4-machine, 7-day-soak-each runbook.**

## Performance

- **Duration:** deferred (operator-driven, ~28+ calendar days)
- **Started:** deferred
- **Completed:** deferred
- **Tasks:** 0/5 (operator runbook)
- **Files modified:** 0 (no engineering work in this plan)

## Accomplishments

None directly in this plan. Wave 1-5 engineering work delivered the tooling and documentation this runbook operates against:

- `task validate` aggregator (Plan 02) -- the green-check gate per machine
- `links:reconcile` (Plan 03) -- the orphan detector the runbook references
- `cutover:ack` writer (Plan 03) -- the sentinel each machine needs before `task install`
- `docs/CUTOVER.md` (Plan 04) -- the fresh-machine procedure + per-machine state table the operator updates
- `docs/MACHINES.md` (Plan 04) -- per-machine context
- `docs/MIGRATION.md` (Plan 05) -- Rollback + Archiving v1 procedures
- `README.md` (Plan 05) -- v2 tutorial walkthrough

## Task Commits

None. Tasks 1-5 produce commits only when the operator drives the runbook.

## Files Created/Modified

None. The deliverable is `docs/CUTOVER.md` state-table edits committed by the operator as each machine progresses.

## Decisions Made

- **Defer Plan 06, finish phase verification now.** User-selected per the in-session checkpoint dialog. The autonomous engineering work (Waves 1-5) shipped and is verified; the operator runbook is the natural follow-on outside this session.
- **CUTV-04, CUTV-05, CUTV-06 stay Pending.** Marked operationally pending in REQUIREMENTS.md / VERIFICATION.md rather than silently closed. The verifier should report them as `gaps_found` or `human_needed` depending on policy.

## Deviations from Plan

None - the plan is by design `autonomous: false`. Deferral is sanctioned by the plan's own design.

## Issues Encountered

None.

## Next Phase Readiness

- **Phase 8 engineering complete.** All autonomous deliverables shipped.
- **Operator runbook outstanding.** The operator can resume by following `docs/CUTOVER.md` section "Fresh-machine verification" on each target machine in the documented order (personal-laptop -> server-1 -> server-2 -> work-laptop -> archive), updating the per-machine state table and committing as each milestone lands.
- **Resume signal:** When all four rows in `docs/CUTOVER.md` show `status: archived` and `git ls-remote origin 'refs/heads/archive/v1'` returns a ref, this plan is genuinely complete. At that point, re-run `/gsd-execute-phase 8` (which will re-verify) or manually update this SUMMARY to record actual cutover dates.

---
*Phase: 08-validation-cutover-readiness*
*Completed: deferred (operator-driven)*
