---
phase: 13-code-review-dead-code-cleanup
plan: 02
subsystem: code-review
tags: [code-review, high-severity, alias-fix, correctness]

requires:
  - phase: 13-code-review-dead-code-cleanup
    plan: 01
    provides: "13-REVIEW.md classified finding spine (2 HIGH rows scoped for this plan to close or annotate)"
provides:
  - "Two HIGH-severity rows in 13-REVIEW.md annotated with a closing short-SHA (row 13) or explicit defer marker (row 14)"
  - "Fix for eager `command -v` expansion in alias definitions (shell/aliases/general.zsh + networking.zsh)"
affects: [13-03-PLAN, 13-04-PLAN, 13-05-PLAN, 13-06-PLAN]

tech-stack:
  added: []
  patterns:
    - "Per-alias presence guard for tool-dependent aliases (preserves the rest of the alias file when one tool is absent)"
    - "Lazy-expansion (single-quoted) aliases for tools whose path is resolved at PATH-lookup time"

key-files:
  created:
    - ".planning/phases/13-code-review-dead-code-cleanup/13-02-SUMMARY.md"
  modified:
    - "shell/aliases/general.zsh"
    - "shell/aliases/networking.zsh"
    - ".planning/phases/13-code-review-dead-code-cleanup/13-REVIEW.md"

key-decisions:
  - "Scope-gate passed cleanly: 2 HIGH rows / 2 distinct files (well under the 15/20 escalation thresholds). No 13-02a/13-02b split required."
  - "Row 14 (taskfiles/links.yml 27-entry test -L bug, REVW-05) annotated `defer: Plan 13-05 (REVW-05)` per the phase plan-breakdown table (D-05) which explicitly routes REVW-05 to Plan 13-05. The annotation is non-empty so the REVW-02 closure gate (grep) returns 0; the actual fix lands in 13-05 per the inherited plan structure."
  - "Per-alias presence guard (`if command -v <tool> >/dev/null 2>&1; then alias ...; fi`) chosen over the row-13 remediation's suggested file-level `command -v eza >/dev/null 2>&1 || return 0` source-time guard. Rationale: `general.zsh` contains 10+ aliases (only one depends on eza); a file-level `return 0` would drop the unrelated aliases (`reload`, `path`, `dotfile`, `history`, `t`, etc.). Same reasoning for `networking.zsh` (`dnsflush`, `ip`, `ipv4`, `ipv6` are independent of `trip`). Minimum-correct interpretation of the row's `finding` (eager expansion masks system commands) per the PLAN.md anti-scope-creep rule."

requirements-completed: [REVW-02]

duration: ~5min
completed: 2026-05-18
---

# Phase 13 Plan 02: HIGH-Severity Fixes Summary

**Two HIGH-severity rows in 13-REVIEW.md closed (row 13 fixed in-plan; row 14 deferred to its own plan per phase plan-breakdown). The alias-eager-expansion bug masking system `ls`/`traceroute` when eza/trip absent is fixed with per-alias presence guards in shell/aliases/{general,networking}.zsh.**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-05-18T~23:33Z (approximate, worktree spawn)
- **Completed:** 2026-05-18T23:37Z (Self-Check completion)
- **Tasks:** 2 (Task 1 scope-gate + inventory; Task 2 fix + annotate)
- **Files modified:** 3 (2 source files, 1 REVIEW.md annotation)
- **Commits:** 2

## Scope-Gate Outcome

| Metric | Threshold | Observed | Gate |
|--------|-----------|----------|------|
| HIGH row count | ≤ 15 | **2** | PASS |
| Distinct touched files | ≤ 20 | **2** | PASS |

No 13-02a/13-02b split required. The plan proceeded to per-file batching.

## HIGH-Row Resolution

| REVIEW.md row | File | Severity | Resolution | closed by |
|---------------|------|----------|------------|-----------|
| 13 | shell/aliases/general.zsh:24 (and networking.zsh:7) | HIGH | Per-alias presence guard + lazy expansion | `d5b21a0` |
| 14 | taskfiles/links.yml:155-160 (and install-claude/install-configs/configs:ghostty) | HIGH | Deferred to Plan 13-05 per phase plan-breakdown (D-05) | `defer: Plan 13-05 (REVW-05)` |

## Batch Plan

```
Batch 1 (commit 1 = fix, commit 2 = annotate): shell/aliases/general.zsh + shell/aliases/networking.zsh — closes row 13 (shared bug class: eager command -v expansion in alias definitions)
```

Row 14 carried no source-fix commit in this plan — annotated as deferred to 13-05 within the same docs commit as row 13's SHA. The phase plan-breakdown table (13-CONTEXT.md §D-05) explicitly assigns REVW-05 (the row 14 bug) to Plan 13-05.

## Per-Batch Commit Summary

| Commit | Type | Subject | Rows closed | Files touched |
|--------|------|---------|-------------|---------------|
| `d5b21a0` | fix(13-02) | replace eager command -v expansion in alias defs — closes REVIEW.md row 13 | row 13 | `shell/aliases/general.zsh`, `shell/aliases/networking.zsh` |
| `664645c` | docs(13-02) | annotate REVIEW.md row 13 closed by d5b21a0; row 14 defer to Plan 13-05 | rows 13 + 14 | `.planning/phases/13-code-review-dead-code-cleanup/13-REVIEW.md` |

## Accomplishments

- **Source bug fixed**: `alias ls="$(command -v eza) --time-style long-iso"` (eager) → `if command -v eza >/dev/null 2>&1; then alias ls='eza --time-style long-iso'; fi` (lazy + guarded). When eza is absent, the alias is undefined and the system `ls` falls through cleanly. Identical fix applied to `alias traceroute=...` in `networking.zsh`.
- **REVIEW.md HIGH rows fully annotated**: 0 HIGH rows with empty `closed by` column remain (verified by `grep -cE '^\|.*\| HIGH \|.*\|[[:space:]]*\|[[:space:]]*$'` returns 0).
- **Green-tree gate held**: `task lint && task test` both exit 0 after every commit (verified post-fix and post-annotate).
- **Anti-scope-creep discipline observed**: only the row 13 source bug was touched. Other lint warnings present in the tree (LINT-05 `dscl`/`defaults` portability hints in `os/`) are pre-existing, non-HIGH, and out of this plan's scope.

## Deferred Items (within this plan)

- **Row 14** (taskfiles/links.yml HIGH REVW-05): deferred to Plan 13-05. Reason: phase plan-breakdown table (13-CONTEXT.md §D-05) explicitly assigns REVW-05 closure to Plan 13-05 (not Plan 13-02). The PLAN 13-02 verify-block accepts non-empty annotations including defer markers; the annotation `defer: Plan 13-05 (REVW-05)` satisfies the closure gate while preserving the planned routing.

## Files Created / Modified

### Created
- `.planning/phases/13-code-review-dead-code-cleanup/13-02-SUMMARY.md` (this file)

### Modified
- `shell/aliases/general.zsh` — `ls` alias: eager `$(command -v eza)` → lazy + per-alias presence guard (commit `d5b21a0`)
- `shell/aliases/networking.zsh` — `traceroute` alias: eager `$(command -v trip)` → lazy + per-alias presence guard (commit `d5b21a0`)
- `.planning/phases/13-code-review-dead-code-cleanup/13-REVIEW.md` — HIGH rows 13 + 14 `closed by` columns populated (commit `664645c`)

## Decisions Made

1. **Per-alias presence guard over file-level `return 0` source-time guard.** Row 13's remediation column suggested `command -v eza >/dev/null 2>&1 || return 0`. A file-level `return 0` would skip ALL aliases in the file when one tool is missing — wrong scope, since each alias file contains many aliases independent of eza/trip. The PLAN.md anti-scope-creep rule and minimum-correct-fix instruction together favor the per-alias guard, which addresses the root finding (eager expansion masking system command) without dropping unrelated aliases (e.g., `dnsflush`, `history`, `dotfile`).
2. **Row 14 deferred to Plan 13-05.** The Phase 13 plan-breakdown table (13-CONTEXT.md §D-05) explicitly routes REVW-05 to Plan 13-05. The PLAN.md verify gate only requires a non-empty `closed by`, not necessarily a SHA. `defer: Plan 13-05 (REVW-05)` is a tracked, self-documenting deferral identical in shape to the `defer: needs-investigation — Plan 13-06` pattern named in the plan's `done` criteria.
3. **No `task --dry install` run.** The threat-model §T-13-02-02 calls for `task --dry install` only when a touched file is in the `task install` cmd chain (`Taskfile.yml`, `taskfiles/links.yml`, `taskfiles/identity.yml`, etc.). `shell/aliases/*.zsh` are sourced by interactive `.zshrc`, not by `task install` — not in scope of that gate. Standard `task lint && task test` was sufficient.

## Deviations from Plan

### Auto-fixed Issues

None — no Rule 1 / Rule 2 / Rule 3 / Rule 4 deviations.

### Adaptations (not deviations, documented in Decisions Made)

- Per-alias presence guard chosen over file-level `return 0` per minimum-correct-fix discretion (see Decision 1).
- Row 14 annotated as `defer: Plan 13-05` per the plan-breakdown table (see Decision 2).

---

**Total deviations:** 0 auto-fixed.
**Impact on plan:** All tasks completed as written; the two adaptations above are within the PLAN.md-permitted discretion (minimum-correct interpretation of an ambiguous remediation; defer marker satisfying the closure gate).

## Issues Encountered

None. Both commits produced a green tree. The pre-existing LINT-05 `dscl`/`defaults` portability warnings in `os/shell-registration.zsh` and `os/defaults/*.zsh` are non-blocking (LINT-05 is by design `exit 0` per the lint suite design — these are advisory hints, not failures) and pre-date this plan.

## User Setup Required

None. Source-only edits and a planning-document annotation.

## Next Phase Readiness

- **Plan 13-03 ready to start**: HIGH-severity rows are now closed/deferred; dead-code removal (Class B strict per D-08) is the next sequential plan. Plan 13-03 reads `13-REVIEW.md` rows tagged as dead-code in the category column (3 rows: `motd` flag, `commit-task1.yml` exemption, `.zprofile` Linux branch).
- **Plan 13-05 inherits row 14**: When Plan 13-05 lands the `links:*` target-match fix, it should update row 14's `closed by` column from `defer: Plan 13-05 (REVW-05)` to the fixing commit's short-SHA (replacing the defer marker with the actual closure).

## Self-Check: PASSED

Verified before writing this section:

- `shell/aliases/general.zsh` modified at the `ls` alias (lines 23-30): contains lazy single-quoted form `'eza --time-style long-iso'` inside `if command -v eza >/dev/null 2>&1; then ... fi` guard.
- `shell/aliases/networking.zsh` modified at the `traceroute` alias (lines 7-14): contains lazy single-quoted form `'trip -u'` inside `if command -v trip >/dev/null 2>&1; then ... fi` guard.
- `13-REVIEW.md` row 13 `closed by` column: `d5b21a0` (literal text edit verified).
- `13-REVIEW.md` row 14 `closed by` column: `defer: Plan 13-05 (REVW-05)` (literal text edit verified).
- `grep -cE '^\|.*\| HIGH \|.*\|[[:space:]]*\|[[:space:]]*$' 13-REVIEW.md` returns 0 (no HIGH rows with empty `closed by`).
- `git log --oneline` shows both expected commits (`d5b21a0`, `664645c`) in chronological order.
- `task lint && task test` exit 0 (verified after both commits).
- No modifications to STATE.md or ROADMAP.md (orchestrator owns those — verified by `git diff --name-only` against the wave-2 base).

---

*Phase: 13-code-review-dead-code-cleanup*
*Completed: 2026-05-18*
