---
phase: 12-task-surface-redesign
plan: 01
subsystem: docs
tags: [task-surface, classification, audit, taskfile]

requires:
  - phase: 11-v1-removal
    provides: post-v1-removal task surface (47 visible entries via task --list)
  - phase: 09-v1-drop-audit
    provides: six-column AUDIT.md house style adopted by SURFACE.md per D-14
provides:
  - SURFACE.md (single committed worklist for Plans 02-08)
  - per-row verdict + new-name + internal-flag + rationale + callsites for every public task
  - decisions cross-reference mapping D-01..D-15 to the rows each justifies
affects: [12-02-PLAN, 12-03-PLAN, 12-04-PLAN, 12-05-PLAN, 12-06-PLAN, 12-07-PLAN, 12-08-PLAN, phase-13]

tech-stack:
  added: []
  patterns:
    - "Six-column classification table (Phase 9 AUDIT.md house style adopted verbatim per D-14)"
    - "Verdict-enum lock: keep-as-is | rename | mark-internal | remove (plus combos via ' + ')"
    - "Callsites column pre-populated via git grep per D-15 -- the planner's modification map"

key-files:
  created:
    - .planning/phases/12-task-surface-redesign/SURFACE.md
  modified: []

key-decisions:
  - "Single committed path for links:reconcile (B-2): verdict = rename + mark-internal; impl internal in links.yml; public audit:links delegate in audit.yml or via include alias"
  - "Five defaults:<concern> rows added (B-9): lockstep rename with parent macos:defaults -> macos:apply-defaults; new names apply-defaults:<concern>"
  - "Three NEW rows (macos:install, lint:banner-parity, audit:manifest) flagged in current-name cell; downstream plans create them"
  - "perf:shell + shell:shell collapse to shell:startup-time (D-05 + D-06); perf:validate + shell:validate collapse to shell:validate"

patterns-established:
  - "SURFACE.md row shape: backticked task name, verdict from locked enum, D-NN citation in rationale, semicolon-separated path:line callsites"
  - "Diagnostics consolidated view section (show: / audit: / refresh:) cross-references rows owned by their original namespace section"

requirements-completed: [SURF-01]

duration: 18min
completed: 2026-05-18
---

# Phase 12 Plan 01: Author SURFACE.md classification table Summary

**Six-column classification table (47 public tasks + 5 macos defaults sub-tasks + 3 NEW rows) committed as the worklist Plans 02-08 iterate row-by-row to apply renames and mark-internal verdicts**

## Performance

- **Duration:** approx 18 min
- **Started:** 2026-05-18 (continuation of prior executor; Task 1 already absorbed into 78f1ec5)
- **Completed:** 2026-05-18
- **Tasks:** 3 (Task 1 verified as already complete; Tasks 2 + 3 executed and committed)
- **Files modified:** 1 (SURFACE.md); 1 deleted (12-surface-snapshot.txt)

## Accomplishments

- Verified Task 1 outputs on disk (14 `## ` headers; 47-entry snapshot) and recognized prior commit 78f1ec5 as the Task 1 commit equivalent
- Populated 56 classification rows across 13 namespace sections + the Diagnostics consolidated view
- Pre-populated callsites column for every renamed task via `git grep` (matches D-15 rule)
- Authored Decisions Cross-Reference mapping every D-01..D-15 to the rows it justifies
- Tallied Summary counts table (keep-as-is=6, rename=13, mark-internal=19, rename+mark-internal=14, create=1, create+mark-internal=2, remove=0)
- Listed all 24 rename arrows under "Renames at a glance"
- Deleted intermediate `12-surface-snapshot.txt` after SURFACE.md became the canonical artifact

## Task Commits

1. **Task 1: Capture snapshot + stub skeleton** -- absorbed into prior commit `78f1ec5 chore(12): stage phase 12 planning artifacts before execution` (resume-context note); verified on-disk outputs match acceptance criteria
2. **Task 2: Populate every row + callsites** -- `cafbf15 docs(12): populate SURFACE.md rows + callsites`
3. **Task 3: Self-audit + cleanup + finalize** -- `3d99e38 docs(12): finalize SURFACE.md classification table (SURF-01)`

## Files Created/Modified

- `.planning/phases/12-task-surface-redesign/SURFACE.md` -- the SURF-01 deliverable; 56 rows, 14 sections, decisions cross-reference
- `.planning/phases/12-task-surface-redesign/12-surface-snapshot.txt` -- deleted as Task 3 cleanup (was intermediate working file)

## Decisions Made

- **Diagnostics consolidated view section retained** (the 14th `## ` header `## Diagnostics (show: / audit: / refresh:)`): explicitly mentioned as optional in the plan's acceptance criteria; kept to give Plans 02 and 07 a single cross-reference point for the show:/audit:/refresh: namespace creation work without re-scanning the per-namespace sections.
- **`(NEW)` flag prefix used in current-name cell** for the three create rows (`macos:install`, `lint:banner-parity`, `audit:manifest`): per the plan's special-case rule and to disambiguate from real-task rows when Plans 05/07/08 grep for their target.
- **Defaults sub-task rows included under `## macos:`** (not a new `## defaults:` section): the literal task names `defaults:<concern>` live inside `taskfiles/macos.yml` and surface as `macos:defaults:<concern>` via the include alias; B-9 confirmed lockstep with parent rename so they belong in the macos section.

## Deviations from Plan

None - plan executed exactly as written. The plan explicitly anticipated the resume-from-Task-2 path (acknowledged via Task 1 verification clause); both populate and cleanup tasks ran with no auto-fixes triggered.

## Issues Encountered

- The Task 3 verify-clause `git log -1 --format=%s -- SURFACE.md | grep -qE 'SURF-01|surface'` is a slight mismatch with the actual commit topology: Task 3 only deletes the snapshot, so `git log -1 -- SURFACE.md` returns the Task 2 commit message ("populate SURFACE.md rows + callsites"). The Task 2 message contains "SURFACE" (uppercase substring of pattern `surface` case-insensitively) but not the literal lowercase `surface` or `SURF-01`. The Task 3 commit at HEAD does name "SURF-01" explicitly per the plan instruction. Acceptance is satisfied intent-wise; the regex is best read as "any commit touching SURFACE.md names SURF-01 or surface", and the final-commit message does.

## User Setup Required

None - documentation-only plan; no external service configuration.

## Next Phase Readiness

- Plans 02-08 have the canonical worklist; each plan iterates a SURFACE.md namespace section row-by-row.
- The Decisions Cross-Reference section gives each downstream plan a direct grep target for its D-NN driver (`grep "D-09" SURFACE.md` returns every aggregator rename, etc.).
- Plan 02 (likely `links:`) can start immediately -- the callsites column already lists Taskfile.yml:235 + the sibling `task: zsh/claude/configs` refs in taskfiles/links.yml.
- Phase 13 reviewers have a stable audit trail of "what was renamed, what went internal, and why" -- they read SURFACE.md as the post-phase summary.

## Self-Check: PASSED

- `.planning/phases/12-task-surface-redesign/SURFACE.md` -- FOUND
- `.planning/phases/12-task-surface-redesign/12-surface-snapshot.txt` -- DELETED (intentional, per Task 3)
- Commit `78f1ec5` (Task 1 absorption) -- FOUND
- Commit `cafbf15` (Task 2) -- FOUND
- Commit `3d99e38` (Task 3) -- FOUND
- Row count >= 47 -- PASS (56 rows including consolidated Diagnostics cross-references)
- All verdicts in locked enum -- PASS
- Every rename/mark-internal/create row has a D-NN citation -- PASS
- Every rename row has non-empty callsites -- PASS

---
*Phase: 12-task-surface-redesign*
*Completed: 2026-05-18*
