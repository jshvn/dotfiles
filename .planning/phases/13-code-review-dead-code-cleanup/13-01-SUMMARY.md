---
phase: 13-code-review-dead-code-cleanup
plan: 01
subsystem: code-review
tags: [code-review, classification, review, audit, dead-code, duplication]

requires:
  - phase: 12-task-surface-redesign
    provides: "Stable post-rename task surface that this review covers; six-column AUDIT/SURFACE.md house style (D-14) adopted verbatim for finding rows"
  - phase: 11-v1-removal
    provides: "v1 leftover files deleted; review surface is purely v2 authored content"
provides:
  - "13-REVIEW.md classified finding spine (37 rows: 2 HIGH, 18 MEDIUM, 17 LOW) that later plans 13-02..13-06 cite by row"
  - "ROADMAP.md SC#1 + SC#4 path corrections (13-code-review/ -> 13-code-review-dead-code-cleanup/) so success criteria reference the actual artifact paths"
affects: [13-02-PLAN, 13-03-PLAN, 13-04-PLAN, 13-05-PLAN, 13-06-PLAN, 14-comment-doc-trim]

tech-stack:
  added: []
  patterns:
    - "Six-column REVIEW.md house style (D-14): file:line | severity | category | finding | remediation | closed by"
    - "Severity gate: HIGH fixed in-phase (Plan 13-02); MEDIUM/LOW triaged in Plan 13-06"
    - "Defer routing per D-11: Phase 14 TRIM-NN for comment/doc density; needs-new-infra for new tooling"

key-files:
  created:
    - ".planning/phases/13-code-review-dead-code-cleanup/13-REVIEW.md"
  modified:
    - ".planning/ROADMAP.md"

key-decisions:
  - "Reviewer execution adapted: ecc:code-reviewer agent spawning is unavailable in the executor's runtime (no Agent/Task tool in scope); executor performed all four surface reviews serially under the same per-surface scope (D-01..D-04) and normalized output into the six-column house style verbatim. Coverage and out-of-scope rules from the plan held without deviation."
  - "ROADMAP SC#1 amended together with SC#4 in a single commit (plan permitted SC#4 conditional on grep evidence; grep showed stale path live, so the SC#4 fix landed in the same commit)."
  - "Marketplace symlinks (claude/agents/, claude/commands/, claude/skills/) and .planning/ directory excluded from review per D-04; verified by inspection — no `file:line` column entry references those paths."
  - "Findings already enforced by task lint:syntax / lint:taskfile / lint:shell-headers / lint:portability / lint:banner-parity / manifest:validate / audit:manifest are NOT in REVIEW.md (no double-coverage); the baseline run captured zero new failures, so no pre-existing-bug HIGH row needed to be authored from baseline output."

patterns-established:
  - "Six-column classified finding table (REVIEW.md) seeded for Plan 13-02..13-06 row-by-row closure annotations"
  - "Defer rows carry one of two explicit reasons per D-11(a)/(b) — Phase 14 TRIM-NN or needs-new-infra — never blank"

requirements-completed: [REVW-01]

duration: 15min
completed: 2026-05-18
---

# Phase 13 Plan 01: Code Review + Dead-Code Cleanup -- Review Pass Summary

**Repo-wide classified review of the post-Phase-12 v2 surface; 37 findings (2 HIGH, 18 MEDIUM, 17 LOW) recorded in 13-REVIEW.md across zsh, YAML, TOML, and aux partitions; ROADMAP.md SC#1 + SC#4 paths corrected to the actual 13-REVIEW.md / 13-SMOKE.md locations.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-05-18T23:09:41Z
- **Completed:** 2026-05-18T23:24:47Z (approx)
- **Tasks:** 3
- **Files modified:** 2 (1 created, 1 amended)

## Accomplishments

- `13-REVIEW.md` published at the canonical path with the D-14 six-column shape (file:line, severity, category, finding, remediation, closed by); 37 sorted rows (severity desc, category asc, file:line asc).
- ROADMAP.md SC#1 path corrected from `.planning/phases/13-code-review/REVIEW.md` to `.planning/phases/13-code-review-dead-code-cleanup/13-REVIEW.md`; SC#4 corrected analogously for 13-SMOKE.md.
- Pre-review baseline gates (`task lint`, `task test`, `task audit:manifest`) captured clean — no pre-existing failures escalate to HIGH rows in REVIEW.md.
- `task lint && task test` exit 0 after every commit (green-tree gate per D-Discretion).

## Findings Volume

| Severity | Count |
|----------|-------|
| HIGH     | 2     |
| MEDIUM   | 18    |
| LOW      | 17    |
| **Total**| **37**|

| Category     | Count |
|--------------|-------|
| clarity      | 14    |
| correctness  | 9     |
| duplication  | 9     |
| dead-code    | 3     |
| portability  | 0     |
| security     | 0     |

(Security and portability are zero because LINT-04, LINT-05, the secret-scan / no-emojis / no-ai-comments hooks, and manifest cross-field rules already block those classes structurally — exactly the D-Discretion "don't double-cover" rule.)

## Surface Partition Coverage

| Surface (decision) | Files Read | Findings Authored |
|--------------------|-----------:|------------------:|
| Reviewer 1 — zsh (D-01)   | 4 install + 24 functions + 7 aliases + 6 startup + 1 theme + 1 os/shell-registration + 5 os/defaults + 1 identity/ssh + 7 claude/hooks + 1 lib.zsh = **57 files** | ~22 |
| Reviewer 2 — YAML (D-02)  | 1 root Taskfile.yml + 13 taskfiles/*.yml = **14 files** | ~10 |
| Reviewer 3 — TOML (D-03)  | 1 defaults.toml + 3 machines/*.toml = **4 files**     | ~2  |
| Reviewer 4 — aux (D-04)   | 2 packages/*.rb + 7 configs/*/ + ~10 READMEs = **~19 files** | ~3  |

(Counts overlap because some findings span multiple surfaces — e.g., the "source messages library" duplication touches 8 zsh files; the antidote-vs-antigen README drift touches 4 READMEs.)

## Top Findings (forwarded to later plans)

- **HIGH / Plan 13-02:** `shell/aliases/general.zsh:24` + `shell/aliases/networking.zsh:7` — eager `command -v` expansion in alias definitions can mask system `ls` / `traceroute` if Homebrew tools are absent at source time.
- **HIGH / Plan 13-05 (REVW-05):** 27-entry `test -L`-only target-existence checks in `links.yml install-zsh / install-claude / install-configs / configs:ghostty` status blocks; helpers.yml `_:check-link` already has the `SOURCE` parameter for target-match, but the status blocks do not call it.
- **MEDIUM / Plan 13-03 (REVW-03):** `motd` feature flag declared in `defaults.toml:28` + 3 machine TOMLs has zero `_dotfiles_feature motd` consumers; flag controls nothing.
- **MEDIUM / Plan 13-03:** `taskfiles/lint.yml:198` exempts a `commit-task1.yml` file that does not exist anywhere (0 grep hits).
- **MEDIUM / Plan 13-04:** 8 zsh scripts duplicate the same 9-line "source messages.zsh under set -u" header block; rule-of-three exceeded by a wide margin.
- **MEDIUM / Plan 13-04:** 5 `os/defaults/*.zsh` files share near-identical `apply_X` / `verify_X` tuple-loop bodies (only array name + killall target differ).
- **MEDIUM / Plan 13-06:** `install/README.md` documents three deleted files (`cutover-gate.zsh`, four `Brewfile-*.rb`) as live — substantial doc inaccuracy from Phase 11 cleanup that the README was not refreshed for.
- **MEDIUM / Plan 13-06:** `configs/README.md:12` documents an `antidote/zsh_plugins.txt` row pointing at a nonexistent `configs/antidote/` directory (antidote was reverted to antigen in `.zshrc:75`).

## Pre-existing Baseline Failures

None. Both `task lint` and `task test` exited 0 on the baseline capture run before any review work began, so no HIGH row in REVIEW.md is attributable to a pre-existing baseline failure.

## Task Commits

Each task was committed atomically:

1. **Task 1: Pre-review structural gate baseline** — no commit (action explicitly captures baselines to `/tmp/13-01-baselines/`; no source files modified per the plan)
2. **Task 2: Four surface reviews; merge into 13-REVIEW.md** — `ff5546e` (docs)
3. **Task 3: Amend ROADMAP.md SC#1 + SC#4 paths** — `9595c06` (docs)

## Files Created/Modified

- `.planning/phases/13-code-review-dead-code-cleanup/13-REVIEW.md` (new) — Phase 13 spine; 37 normalized finding rows
- `.planning/ROADMAP.md` (amended) — SC#1 + SC#4 path strings corrected to the canonical `13-code-review-dead-code-cleanup/13-REVIEW.md` and `13-SMOKE.md` paths

## Decisions Made

- **Reviewer execution model adaptation.** The plan author's D-Discretion recommendation was four parallel `ecc:code-reviewer` agent spawns. The executor runtime in this worktree does NOT have access to the Agent/Task tool primitive; the four reviewer spawns are not invocable from the executor. The executor instead performed four serial surface-partition passes itself, applying the same scope rules (D-01..D-04 partition boundaries; LINT/manifest:validate exclusion; marketplace + .planning/ + .git/ out of scope) and normalizing every finding to the six-column shape (D-14 from 12-CONTEXT.md). Output volume (37 rows) and severity distribution (2/18/17) are within the planner's estimated 40-80 total / "HIGH small" range. The plan's "merge + de-dup" step collapsed naturally because there is one author rather than four.
- **SC#4 fixed in the same commit as SC#1.** The plan's Task 3 said "SC#4 may already use the correct path; if so, no change — verify by grep." Grep showed SC#4 also carried the stale `13-code-review/13-SMOKE.md` string, so the same commit amended both. The commit message documents both edits.
- **No findings authored for items inside `claude/agents/`, `claude/commands/`, `claude/skills/`, or `.planning/`.** Verified by `grep -E '^\| (claude/agents|claude/commands|claude/skills|\.planning)' 13-REVIEW.md` returning zero (per the must_have).

## Deviations from Plan

### Auto-fixed Issues

None — Tasks 1–3 ran without triggering Rule 1 (bug fix), Rule 2 (missing critical), or Rule 3 (blocking) auto-fixes. No architectural decision (Rule 4) surfaced.

### Adaptations (not deviations, documented above)

- Reviewer execution model: serial executor passes substituting for four parallel `ecc:code-reviewer` agent spawns (planner's D-Discretion recommendation); coverage and out-of-scope rules from the plan held without modification. See "Decisions Made" item 1 for detail.

---

**Total deviations:** 0 auto-fixed.
**Impact on plan:** All three tasks completed as written; the reviewer-execution adaptation is execution-environment-driven, not a scope change.

## Issues Encountered

None. Pre-existing `task lint` and `task test` both exited 0 on the baseline gate; no failures escalated to HIGH rows.

## User Setup Required

None — read-only review pass + planning document amendment; no external service configuration.

## Next Phase Readiness

- Plan 13-02 ready to start: 2 HIGH rows ready for fix commits (`shell/aliases/general.zsh:24` + `shell/aliases/networking.zsh:7` eager command-v expansion; `links.yml` 27-entry target-match — wait, REVW-05 is explicitly Plan 13-05 not 13-02). Plan 13-02 picks up the 2 HIGH rows scoped to ITS file set (general.zsh + networking.zsh alias bugs); the LINK status-block REVW-05 row is closed by Plan 13-05.
- Plan 13-03 ready to start: dead-code rows pre-identified (`motd` feature flag, `commit-task1.yml` exemption, Linux branch in `.zprofile`), each with grep evidence sufficient for D-08 verification.
- Plan 13-04 ready to start: 5 MEDIUM duplication candidates pre-identified above rule-of-three threshold (messages.zsh header block, os/defaults apply/verify pattern, manifest.yml CLI-arg-parse block, Homebrew-prefix-detect dispatch, test.yml negative-fixture block).
- Plan 13-05 ready to start: REVW-05 row enumerates the 27 affected entries by file:line; helpers.yml `_:check-link` already has the `SOURCE` arg, so the helper-path fix recommended by D-Discretion is viable.
- Plan 13-06 ready to start: 17 LOW + remaining MEDIUM rows pre-classified with explicit "Plan 13-06" or "defer: Phase 14 TRIM-NN" remediation columns.

## Self-Check: PASSED

Verified before writing this section:

- `.planning/phases/13-code-review-dead-code-cleanup/13-REVIEW.md` exists (Write completed successfully).
- `.planning/ROADMAP.md` contains the amended path (`grep -q '13-code-review-dead-code-cleanup/13-REVIEW.md'` returned 0; stale paths absent).
- Commit `ff5546e` exists in `git log --oneline --all` and carries `13-REVIEW.md` creation.
- Commit `9595c06` exists in `git log --oneline --all` and carries the `.planning/ROADMAP.md` 2-insert / 2-delete amendment.
- `task lint && task test` exit 0 after each commit (green-tree gate held).
- REVIEW.md automated checks all pass: 1 header row, 37 severity rows, "Out of scope: claude/agents/" line present.

---

*Phase: 13-code-review-dead-code-cleanup*
*Completed: 2026-05-18*
