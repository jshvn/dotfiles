---
phase: 09-v1-drop-audit
plan: 04
subsystem: docs
tags: [audit, docs, install-readme, packages-readme, migration]

# Dependency graph
requires:
  - phase: 09-v1-drop-audit
    provides: AUDIT.md skeleton with locked six-column row shape (D-03) under ## Docs (plan 09-01)
provides:
  - shards/docs.md with 8 audit rows enumerating every substantive v1-only doc fragment classified against the v2 docs/ set per AUDIT-05 / D-09
affects: [09-05, 10, 11, 14]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Audit shard pattern: per-section AUDIT.md row aggregator concatenated verbatim under existing header (no internal ## headers in shard files)"

key-files:
  created:
    - .planning/phases/09-v1-drop-audit/shards/docs.md
  modified: []

key-decisions:
  - "Used the NF=7 (no trailing pipe) row format the plan's acceptance criteria assert, even though the AUDIT.md skeleton header rows use trailing pipes; plan 09-05's concatenation under ## Docs renders correctly either way and the plan's verify/acceptance commands are the contract."
  - "Embedded git-history archeology note in the preamble row's rationale rather than emitting a separate row, per the plan's <action> step 1: 'If the output is trivial or empty, do NOT chase it -- explicitly write in the shard's first row's rationale ...'"
  - "Split the ## Key files section (lines 10-35) into three rows: the section-level row (10-35), the cutover-gate sub-row (23-28), and the Brewfile sub-row (29-34). Plan acceptance explicitly requires a Brewfile-classified row matching ^| install/README.md:[0-9]+(-[0-9]+)? |.*Brewfile.*|.*ported.*| drop and a cutover-gate row pointing to docs/CUTOVER.md; emitting them as sub-rows preserves the parent ## Key files row for inventory exhaustiveness while satisfying the targeted acceptance regexes."
  - "Split the ## Adding a pattern section (lines 36-55) into a parent row plus a 'wait for Phase 5' sub-row (51-54), per the plan's required-rows enumeration."

patterns-established:
  - "AUDIT shard rows omit the trailing pipe (NF=7 awk format) to match the plan's strict column-count acceptance check while remaining valid markdown table rows under the existing AUDIT.md ## Docs header."
  - "When a parent ## section contains a v1-historical sub-fragment that the plan calls out by name (Brewfile bullets, cutover-gate, wait-for-Phase-5 guidance), emit the sub-fragment as its own row in addition to the parent-section row so the targeted acceptance regexes match without losing inventory exhaustiveness coverage of the parent ## heading line."

requirements-completed: [AUDIT-05]

# Metrics
duration: 12min
completed: 2026-05-17
---

# Phase 09 Plan 04: Docs audit shard (AUDIT-05) Summary

**Emitted shards/docs.md with 8 rows classifying every substantive v1-only doc fragment in install/README.md against the v2 docs/ set per D-09 behavior-equivalence, with grep-evidence rationales and named v2 owners ready for plan 09-05 concatenation under AUDIT.md ## Docs.**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-05-17 (parallel wave 2 executor)
- **Completed:** 2026-05-17
- **Tasks:** 1
- **Files modified:** 1 (created)

## Accomplishments

- Inventoried the v1 doc surface for AUDIT-05: install/README.md (the only .md in install/ per Phase 1 DOCS-02), enumerated via `grep -n '^##' install/README.md` producing 3 ## sections + 1 H1 preamble.
- Classified every section and sub-fragment against the v2 docs/ set (docs/MANIFEST.md, docs/SECURITY.md, docs/CUTOVER.md, docs/MIGRATION.md, docs/MACHINES.md, docs/README.md, plus root README.md and packages/README.md) using literal grep evidence captured in each row's rationale column per D-09 paraphrase-OK threshold.
- Performed git-history archeology via `git log --diff-filter=D --name-only --pretty=format: -- '*.md'` and documented in the preamble row's rationale that the only deleted .md files are zsh/cheat/ cheat sheets, two historical planning .md files (docs/consistent-messaging-plan.md, docs/go-task-analysis.md), .github/copilot-instructions.md, and planning todos — none are v1-install-engine doc fragments and all fall under the 09-CONTEXT.md `<deferred>` out-of-scope clause.
- All plan acceptance criteria pass (NF=7 row shape, v2 status enum, keep/drop enum, Brewfile row regex, v2 docs reference present, keep rows have non-n/a v2 owner, single .md in install/, no internal ## headers, no emojis, evidence trail count 7 ≥ 3).

## Task Commits

Each task was committed atomically:

1. **Task 1: Inventory v1 doc surface and classify against v2 docs/ set** — `c17fbd5` (docs)

## Files Created/Modified

- `.planning/phases/09-v1-drop-audit/shards/docs.md` — 8 audit rows: preamble (1-9, partially-ported / drop, owner install/README.md), ## Key files (10-35, ported / drop, owner install/README.md), cutover-gate sub-row (23-28, ported / drop, owner docs/CUTOVER.md), Brewfile transitional bullets sub-row (29-34, ported / drop, owner packages/README.md), ## Adding a pattern (36-55, ported / drop, owner install/README.md), wait-for-Phase-5 sub-row (51-54, ported / drop, owner packages/README.md), ## References (56-70, ported / drop, owner install/README.md), and a catch-all install/*.md inventory row (n/a / n/a / n/a).

## Inventory Snapshot

| Metric | Count |
|--------|-------|
| Data rows in shards/docs.md | 8 |
| Rows referencing install/README.md | 7 |
| `^## ` sections in install/README.md | 3 |
| Classification: ported | 6 |
| Classification: partially-ported | 1 |
| Classification: dropped | 0 |
| Classification: n/a (catch-all only) | 1 |
| keep | 0 |
| drop | 7 |
| n/a (catch-all only) | 1 |
| Rows citing docs/<file>.md / grep / paraphrased / byte-equivalent / D-09 in rationale | 7 |

## Keep List (feeds Phase 10 via plan 09-05)

**None.** Every classified v1 doc fragment is `drop` because the v2 docs/ set already paraphrases the operator-visible content (D-09) or because the v1 fragment was v1-historical commentary (the Brewfile-by-profile pattern, the wait-for-Phase-5 guidance) that the v2 model retired intentionally. The preamble row is `partially-ported / drop` rather than `keep` because install/README.md itself is the v2 owner (Phase 11 RMV-01 does NOT delete install/README.md) — the file stays, so there is no separate keep-list bullet for plan 09-05 to surface.

The cutover-gate sub-row names `docs/CUTOVER.md` as its v2 owner with the note that Phase 11 RMV-04 retires `docs/CUTOVER.md` after the soak window closes; Phase 14 TRIM-03 then folds residual cutover narrative into `docs/MIGRATION.md`. This is captured in the rationale column rather than as a keep-list bullet because the content is already in v2 docs/ today.

## Non-README install/*.md files

**None.** `find install -maxdepth 1 -name '*.md'` returns exactly one path: `install/README.md`. The v2 set assertion (install/-rooted markdown surface is exactly install/README.md per Phase 1 DOCS-02) holds. The catch-all row in shards/docs.md records this with classification n/a / n/a / n/a.

## Git-history Archeology

**Performed (quick check).** Command run:

```bash
git log --diff-filter=D --name-only --pretty=format: -- '*.md' | sort -u | head -20
```

Output:
- `.github/copilot-instructions.md` (GHA Copilot config, never an install-engine doc fragment)
- `.planning/todos/pending/manifest-resolve-machine-switch-cache.md` (planning todo, not a v1 doc)
- `docs/consistent-messaging-plan.md` (historical planning artifact for the v2 refactor)
- `docs/go-task-analysis.md` (historical planning artifact for the v2 refactor)
- `zsh/cheat/cheat.md`, `zsh/cheat/md/conda.md`, `zsh/cheat/md/git.md`, `zsh/cheat/md/zsh.md`, `zsh/cheat/README.md` (v1 user-facing cheat sheets — reference data, not install-engine docs)

Per 09-CONTEXT.md `<deferred>`, deeper archeology is out of scope unless trivial. The above output is trivial: no v1-install-engine doc fragments were deleted in the v2 refactor that are not already represented in the v2 docs/ set or that warrant a keep-list bullet. The zsh/cheat/ cheat sheets fall under the zsh/ tree audit (plan 09-03 wave 2), not the docs audit. The two historical planning .md files (`docs/consistent-messaging-plan.md`, `docs/go-task-analysis.md`) were planning artifacts for the v2 refactor itself, not v1 docs to be ported. The result is documented in the shards/docs.md preamble row's rationale column.

## D-09 Reasoning Citations

D-09 (behavior-equivalence threshold for ported) is explicitly cited in 5 rows' rationale columns: the preamble row, the ## Key files row, the cutover-gate sub-row, the Brewfile transitional commentary sub-row, the ## Adding a pattern row, the wait-for-Phase-5 sub-row, and the ## References row (7 of 8 rows; the catch-all row is informational-only and does not classify content). Confirms the acceptance criterion threshold of ≥ 3.

## Decisions Made

- **Row format chosen as NF=7 (no trailing pipe)** to satisfy the plan's acceptance criterion `awk -F'|' 'NF != 7 && /^\|/ {...}'`. This is the format the plan author explicitly chose; the AUDIT.md skeleton header rows use NF=8 (trailing pipe), but plan 09-05's concatenation appends rows verbatim and markdown renders both row styles correctly under the same header. The shards/ folder is a transient staging area whose contract is the plan's verify command, not the AUDIT.md skeleton format.
- **Embedded git-history archeology in the preamble row's rationale** rather than emitting a separate row, per the plan's <action> step 1 instructions for the empty / trivial case.
- **Split sections into parent + sub-fragment rows** for ## Key files (3 rows: parent 10-35 + cutover-gate 23-28 + Brewfile 29-34) and ## Adding a pattern (2 rows: parent 36-55 + wait-for-Phase-5 51-54). This satisfies the plan's named required rows (Brewfile commentary, cutover-gate, wait-for-Phase-5 guidance) without sacrificing inventory exhaustiveness coverage of the parent ## headings.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Plan's inventory-exhaustiveness acceptance criterion uses gawk-only 3-arg match()**

- **Found during:** Self-verification of acceptance criteria after row emission
- **Issue:** The plan's inventory-exhaustiveness acceptance criterion uses `awk ... match($2, /:([0-9]+)-?([0-9]*)/, a)` — the 3-arg form of `match()` with an output array. This is a gawk extension; BSD awk (the awk shipped on macOS, the v1 target per CLAUDE.md "macOS only in v1") does not support it. The command errors with `awk: syntax error at source line 1` on macOS and the check is unrunnable as written.
- **Fix:** Verified inventory exhaustiveness via an equivalent python script that parses the shard ranges and confirms every `^## ` heading line number (10, 36, 56) falls inside at least one row's line range. Result: all three covered (preamble 1-9 covers nothing; 10-35 covers 10; 36-55 covers 36; 56-70 covers 56). Documented in this summary; the plan author should treat the gawk dependency as a known plan defect for plan 09-05's pre-concatenation validation or rewrite the criterion against BSD awk for macOS portability.
- **Files modified:** None (verification-only; no shard content change required).
- **Verification:** Python script produced "RESULT: PASS" with explicit per-heading coverage trace.
- **Committed in:** N/A (no code change; documented here for plan 09-05 / verifier awareness).

**2. [Rule 1 - Bug] Pipe characters inside row rationale broke NF=7 check**

- **Found during:** Initial NF=7 verification of the first shard write
- **Issue:** Line 1's rationale contained an escaped markdown pipe sequence (` \| sort -u \| head -20`) inside a backtick-quoted shell pipeline. The `\|` escape is markdown-rendering syntax, but `awk -F'|'` splits on the literal `|` regardless of backslash, producing NF=9 for that row instead of the required NF=7.
- **Fix:** Rewrote the shell pipeline as separate `then ... then ...` segments in the rationale so no literal `|` appears in the row content. Re-ran NF check: all 8 rows now NF=7.
- **Files modified:** `.planning/phases/09-v1-drop-audit/shards/docs.md` (line 1 only).
- **Verification:** `awk -F'|' 'NF != 7 && /^\|/ {bad=1} END {if (!bad) print "OK"}'` returns OK.
- **Committed in:** `c17fbd5` (Task 1 commit; the fix was made before the commit).

---

**Total deviations:** 2 auto-fixed (1 plan-defect documented in summary, 1 content-formatting bug fixed before commit)
**Impact on plan:** Neither deviation changed the substantive content or classification decisions. The plan defect (gawk-only acceptance criterion) is a verification-tool portability issue; the row content is correct and the inventory exhaustiveness invariant holds. The pipe-character fix was a representational fix-up that preserved the rationale semantically.

## Issues Encountered

- BSD vs gawk portability: macOS's default `awk` lacks the 3-arg `match(str, regex, array)` form. Worked around for self-verification (documented above as Rule 1 deviation #1). Plan 09-05's pre-concatenation step or the verifier agent should use a BSD-awk-compatible exhaustiveness check or shell out to python on macOS.

## User Setup Required

None.

## Next Phase Readiness

- `shards/docs.md` exists at the canonical path with all 8 rows, satisfying every BSD-runnable acceptance criterion from the plan.
- Wave 3 (plan 09-05) can concatenate this shard verbatim under AUDIT.md's `## Docs` section. The shard contains no internal ## headers (verified: 0).
- AUDIT-05 coverage of the v1 doc surface is complete: every substantive v1-only doc fragment is enumerated with grep-evidence rationale and a named v2 owner (or n/a for the catch-all). The keep-list for Phase 10 (plan 09-05's D-04 bullet list) gets zero new bullets from the docs section because every classified row is `drop`.

## Self-Check: PASSED

- File exists: `.planning/phases/09-v1-drop-audit/shards/docs.md` — verified via `test -f`.
- Commit exists: `c17fbd5` — verified via `git log --oneline --all | grep c17fbd5` (post-commit confirmation in the executor's bash history).
- Plan verify.automated command (`awk -F'|' 'NF>=7 ...'` v2 status enum) returns "OK" → "VERIFY AUTOMATED: PASS".

---
*Phase: 09-v1-drop-audit*
*Completed: 2026-05-17*
