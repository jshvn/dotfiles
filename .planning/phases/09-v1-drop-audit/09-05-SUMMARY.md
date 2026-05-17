---
phase: 09-v1-drop-audit
plan: 05
subsystem: documentation
tags: [audit, assembly, summary, sc5-cross-reference, d-xx-coverage, phase10-handoff]
dependency_graph:
  requires:
    - AUDIT.md skeleton from 09-01 (with the ## Summary placeholders + four section headers + four column-header rows)
    - shards/taskfiles.md from 09-02 (33 rows; one row per task across the 8 v1 leftover taskfiles)
    - shards/install-assets.md from 09-02 (19 rows; v1 Brewfile per-machine effective-set diff + install/*.zsh scope-check catch-all)
    - shards/zsh-tree.md from 09-03 (43 rows; 6 startup files + 24 functions + 3 alias buckets + 1 jgrid + 9 configs/styles)
    - shards/docs.md from 09-04 (8 rows; install/README.md fragment-by-fragment + install/*.md inventory catch-all)
  provides:
    - .planning/phases/09-v1-drop-audit/AUDIT.md (final assembled report - AUDIT-04 closed; 102 audited / 3 keep / 99 drop / 70 already-ported)
    - "### Keep List (Phase 10 queue) bullet block (3 bullets) — Phase 10's implementation queue, read directly by Phase 10 plans"
    - SC#5 cross-reference proof (23/23 task names from ROADMAP Phase 9 SC#5 grep are covered by AUDIT.md rows)
    - D-XX coverage proof (all 12 locked decisions D-01..D-12 cited in the assembled file)
  affects:
    - Phase 10 v1-Drop Remediation can now begin (gate cleared; AUDIT.md is the source-of-truth for the keep-list)
    - REQUIREMENTS.md AUDIT-04 marked complete (delegated to orchestrator)
    - ROADMAP.md Phase 9 progress 5/5 (delegated to orchestrator)
tech-stack:
  added: []
  patterns:
    - "Python smart-split for markdown table rows containing literal `|` inside backtick-delimited cells (BSD/GNU awk-agnostic; the plan's verbatim awk `match($2, /regex/, a)` is gawk-only and broke on macOS BSD awk — Rule 1 inline fix used Python instead)"
    - "Idempotent assembly: re-running both Python scripts against the same shard inputs produces byte-identical AUDIT.md (verified via cp /tmp/audit-pre.md + diff)"
    - "D-XX coverage amendment: when distinct-decision count fell below 12 (initially 9, missing D-01, D-03, D-05), section preambles were edited to cite the missing decisions inline rather than re-running the bullet-generator (preamble citations carry decision attribution without restructuring rows)"
key-files:
  created:
    - .planning/phases/09-v1-drop-audit/09-05-SUMMARY.md
  modified:
    - .planning/phases/09-v1-drop-audit/AUDIT.md (skeleton → assembled report with 103 data rows + populated Summary + Status flipped to Complete)
decisions:
  - "Catch-all informational `n/a` rows (docs.md install/*.md inventory) are excluded from counts arithmetic but retained in the AUDIT.md as content — they assert v2-set completeness for their dimension, not auditable units. The install-assets.md install/*.zsh row keeps its self-classification as `drop` (was already counted)."
  - "BSD/GNU awk incompatibility in the plan's verbatim SC#5 verification awk: the `match($2, /regex/, a)` 3-argument form is GNU-only. Re-implemented the cross-reference check in Python (see /tmp/sc5_check.py); semantics unchanged, but the proof now runs on macOS without gawk."
  - "Three keep rows in the AUDIT.md (ZDOTDIR write, ZDOTDIR validation, Things-MAS name normalization) are exactly Phase 10's full implementation queue. The ZDOTDIR write is the milestone driver and lands first (per ROADMAP Phase 10 SC#1)."
metrics:
  duration_seconds: 504
  duration_hms: "8m 24s"
  completed_at: "2026-05-17T20:39:54Z"
  tasks: 2
  files_modified: 1
  files_created: 1
  commits: 2
---

# Phase 9 Plan 5: Final Assembly of AUDIT.md Summary

Concatenate the four Wave 2 shard files (taskfiles, install-assets, zsh-tree, docs) into AUDIT.md's D-01 section bodies, then populate the ## Summary block (real counts + sorted keep-list bullets with ZDOTDIR driver first), prove SC#5 cross-reference coverage, prove D-XX coverage ≥12, and flip Status to Complete — closing AUDIT-04 and gating Phase 10 readiness.

## What Was Done

### Task 1 — Concatenate four shards into AUDIT.md section bodies (D-01)

Built a Python assembly script (`/tmp/assemble_audit.py`) that walks the skeleton AUDIT.md, finds each `## ` header in order, and inserts the matching shard's normalized rows immediately after the section's column-header row plus separator (synthesizing a `|---|...|` separator when the skeleton omits one). Row normalization: every row ends with ` |` (the docs.md shard shipped without trailing pipes — Rule 1 fix). Rows containing literal `|` inside backtick-delimited cells (3 of them — `taskfiles/profile.yml:4-38`, `zsh/.zlogout:1-56`, `zsh/aliases/personal/jgrid.zsh:1-39`) are passed through verbatim; they render as valid 6-column markdown rows even though naive pipe-splitting reports extra fields.

Idempotency guarantee: if the section's body row count already matches the shard's row count AND byte-matches the shard rows, the section is left untouched. If counts match but bytes differ, the script fails loudly rather than silently overwriting. If counts differ but the section is non-empty, same fail-loud behavior.

Also stamped the `**Last updated:**` line to today's date (`2026-05-17`).

**Result:** 103 data rows total across the 4 sections (33 + 19 + 43 + 8 = 103). Five top-level headers preserved (## Summary, ## Taskfiles, ## Install Assets, ## zsh/ Tree, ## Docs); four column-header rows preserved verbatim.

**Commit:** `db182b6` — `docs(09-05): assemble shards into AUDIT.md sections`

### Task 2 — Populate ## Summary block, run SC#5 + D-XX verifications, flip Status

Built a second Python script (`/tmp/populate_summary.py`) that parses the assembled AUDIT.md using a smart-split (backtick-aware pipe parser), computes counts by walking every data row across the 4 sections, replaces the 4 TBD cells in the counts table with real numbers, generates the sorted keep-list bullet block (section order then file:line ascending; ZDOTDIR milestone-driver bullet pinned first under Taskfiles), and flips `**Status:** In progress` → `**Status:** Complete (Phase 9 closed, ready for Phase 10)`.

**Counts computed (102 = 3 + 99):**

| Metric | Value | Notes |
|--------|-------|-------|
| Tasks audited | 102 | Excludes 1 `n/a` informational catch-all (docs.md `install/*.md inventory` row) |
| Keep | 3 | All under ## Taskfiles or ## Install Assets; no zsh/Tree or Docs keeps |
| Drop | 99 | Includes the `install/*.zsh` v2-set scope-check row (self-classified `drop`, `n/a` v2-status) |
| Already-ported | 70 | Subset of drop rows whose v2 status is `ported` — covers the v2-replacement majority |

**Per-section breakdown (recounted from final AUDIT.md):**

| Section | Total rows | Keep | Drop | Already-ported (subset of drop) | n/a (excluded) |
|---------|------------|------|------|--------------------------------|----------------|
| ## Taskfiles | 33 | 2 | 31 | ~25 (taskfiles fully replaced by v2 packages.yml / shell.yml / manifest.yml / macos.yml / claude.yml / links.yml) | 0 |
| ## Install Assets | 19 | 1 | 18 | ~10 (Brewfile packages ported to packages/core.rb + extras) | 0 (but `install/*.zsh` row has v2-status n/a) |
| ## zsh/ Tree | 43 | 0 | 43 | ~33 (functions byte-identical / startup files present-equivalent / configs/styles byte-identical) | 0 |
| ## Docs | 8 | 0 | 7 | ~2 (install/README.md install-engine internals retained) | 1 (install/*.md inventory catch-all) |
| **Total** | 103 | 3 | 99 | 70 | 1 |

(Per-section already-ported approximations are illustrative; the exact count of 70 was computed by the Python script across all 4 sections.)

**Keep List (Phase 10 queue) — verbatim:**

1. `` `taskfiles/common.yml:36-57` → **taskfiles/shell.yml** — Write `export ZDOTDIR="$HOME/.config/zsh"` to /etc/zshenv via sudo (idempotent grep-and-append) ``
2. `` `taskfiles/common.yml:63-88` → **taskfiles/shell.yml** — Validate XDG dirs and the /etc/zshenv ZDOTDIR line are present ``
3. `` `install/Brewfile-personal.rb:72` → **manifests/machines/personal-laptop.toml** — mas 'Things' (id 904280696) declared in v1 personal-profile Brewfile ``

The ZDOTDIR write is the milestone driver (PORT-01) and lands first; the ZDOTDIR validation completes the assertion side of the write; the Things-MAS name-normalization is a small audit-trail polish item (functional install is already correct because `mas` resolves on id, but the v2 manifest name `Things3` drifted from the v1 audit-display name `Things`).

**Commit:** `00e6e65` — `docs(09-05): populate AUDIT.md Summary, flip Status to Complete`

## Verification Trail

### SC#5 cross-reference proof (ROADMAP Phase 9 SC#5)

The verbatim ROADMAP grep over the eight v1 leftover taskfiles produced **23 distinct task-name candidates** after stripping go-task structural keys (desc, cmds, vars, silent, status, preconditions, deps, internal, requires, dotenv, includes, aliases, version, env, sources, generates, method, prefix, run, interval, set, shopt, platforms, label, summary, ignore_error, tasks):

```
all bundle defaults defaults-appearance defaults-dock defaults-finder
defaults-general defaults-init defaults-misc ensure ensure-homebrew install
links msg require shell show unlink update validate xdg zdotdir brew
```

Coverage check (re-implemented in Python because the plan's verbatim awk uses GNU-only `match($2, /regex/, a)` 3-argument form which fails on macOS BSD awk): **23 / 23 task names** were proven covered by an AUDIT.md row whose file:line range encloses the task's defining line. Zero MISSING entries. Output: `OK: SC#5 cross-reference passes — AUDIT.md is a superset of the grep output`.

### D-XX coverage proof (must_haves truth #6)

Initial count: 9 distinct decisions cited (D-02, D-04, D-06, D-07, D-08, D-09, D-10, D-11, D-12). Missing: D-01 (section split), D-03 (six-column shape), D-05 (zsh function comparison method).

Amendment: extended the `### Keep List (Phase 10 queue)` preamble italic line to cite D-01 (section split mirrors leftover category) and D-03 (locked six-column shape); extended the `## zsh/ Tree` preamble italic line to cite D-05 (function-file presence-plus-diff comparison) alongside the already-present D-06/D-07/D-08 citations.

Final count: **12 distinct D-XX decisions cited** (D-01 through D-12) — meets the ≥12 threshold exactly.

Verification command: `grep -oE 'D-(0[1-9]|1[0-2])' .planning/phases/09-v1-drop-audit/AUDIT.md | sort -u | wc -l` → `12`.

### Idempotency proof

```
cp .planning/phases/09-v1-drop-audit/AUDIT.md /tmp/audit-pre-rerun.md
python3 /tmp/assemble_audit.py     # Re-runs Task 1 logic
python3 /tmp/populate_summary.py   # Re-runs Task 2 logic
diff /tmp/audit-pre-rerun.md .planning/phases/09-v1-drop-audit/AUDIT.md
# → exit 0 (byte-identical)
```

Both scripts are deterministic: assembly detects pre-populated sections and skips; populate's regex replacements look for `TBD` / `In progress` markers that are gone on re-run; bullet generation replaces the placeholder string which is gone on re-run. The preamble D-XX amendments are not in the scripts, but they live outside the script's edit boundaries (assembly only touches between column-header and next `## `; populate only touches counts table + Status line + placeholder bullet line) so they survive script re-runs.

### Per-row column-shape verification

Every data row across the assembled AUDIT.md uses the locked 6-column shape (7 `|` delimiters). The 3 rows containing literal `|` inside backtick-enclosed cells (markdown-valid code-fence content) parse as 8/10/11 fields under naive pipe-splitting but render correctly as 6-column rows in GitHub-flavored markdown. No rows are malformed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Normalized docs.md shard rows that shipped without trailing `|`**

- **Found during:** Task 1 (assembly preflight)
- **Issue:** All 8 rows in `.planning/phases/09-v1-drop-audit/shards/docs.md` ended in `install/README.md` (or similar v2-owner text) with NO trailing pipe character. Without a trailing pipe, the row is not a valid markdown table row — the last cell silently absorbs into the row terminator.
- **Fix:** Assembly script appends ` |` to every shard row that doesn't already end with `|` during the verbatim copy step. The upstream shard files were NOT modified; the fix lives in the assembly logic so re-running the script on the same shards always produces well-formed AUDIT.md rows.
- **Files modified:** `.planning/phases/09-v1-drop-audit/AUDIT.md` (8 rows in ## Docs section now have proper trailing pipe)
- **Commit:** `db182b6`

**2. [Rule 1 - Bug] BSD/GNU awk incompatibility in plan's verbatim SC#5 verification**

- **Found during:** Task 2 SC#5 check
- **Issue:** The plan's verbatim acceptance-criteria awk uses `match($2, /regex/, a)` 3-argument form (GNU gawk extension). macOS ships BSD awk by default which lacks this. The verbatim script reported every task as MISSING with `awk: syntax error at source line 4` for each iteration.
- **Fix:** Re-implemented the SC#5 cross-reference check in Python (`/tmp/sc5_check.py`). Semantics unchanged: walk grep input → strip structural keys → enumerate task defining lines → prove each is covered by an AUDIT.md row whose `file:line` range encloses it. The Python verifier produced `Covered: 23 / 23` and `OK`.
- **Files modified:** None in the repo (verifier lives in /tmp; documented here for reproducibility).
- **Commit:** N/A (verification artifact; no source change)

**3. [Rule 1 - Bug] Plan's awk acceptance criteria use `NF != 7` to check 6-column shape, but 6 columns produce NF=8 (7 pipes split into 8 fields)**

- **Found during:** Task 1 verification
- **Issue:** `awk -F'|' 'NF != 7' ... | grep -q OK` would flag CORRECT 6-column rows as bad. Off-by-one in the plan's check.
- **Fix:** Did NOT modify shard data (the rows are correctly shaped at 6 columns / NF=8). Used a manual inspection of the 9 non-NF=8 rows to confirm they are: 6 Summary-table rows (2 columns, NF=4) + 3 rows with literal backtick-pipes (NF=10/11, all valid markdown). The 7-pipe / 6-column structure of every data row is intact.
- **Files modified:** None
- **Commit:** N/A

**4. [Rule 2 - Auto-add missing critical functionality] D-XX coverage amendment for D-01, D-03, D-05**

- **Found during:** Task 2 D-XX coverage probe
- **Issue:** Initial assembled AUDIT.md cited only 9 of 12 locked decisions (D-02, D-04, D-06, D-07, D-08, D-09, D-10, D-11, D-12). The `must_haves.truths[6]` threshold requires ≥12 distinct citations. Missing: D-01 (section split by leftover category), D-03 (locked six-column shape), D-05 (zsh-vs-shell function comparison method).
- **Fix:** Per Task 2 Step 4 explicit instruction ("If the count is below 12, identify the missing D-XX and amend the most appropriate Summary line OR section-preamble italic line to cite it"), extended two preamble italic lines: the `### Keep List (Phase 10 queue)` preamble now cites D-01 + D-03; the `## zsh/ Tree` preamble now also cites D-05 alongside D-06/D-07/D-08. No row content was altered.
- **Files modified:** `.planning/phases/09-v1-drop-audit/AUDIT.md` (2 italic preamble lines)
- **Commit:** `00e6e65` (bundled with the Task 2 commit)

### Architectural changes

None. Read-only concatenation + counts-fill + verification. No new tooling, no new files beyond AUDIT.md edits and this SUMMARY.md.

## Authentication Gates

None — read-only documentation assembly; no external services touched.

## Known Stubs

None. The keep-list bullet block is fully populated with 3 real bullets; the counts table carries real numbers; the Status line is flipped to Complete. No placeholder text, no `TBD`, no `coming soon`.

## Self-Check: PASSED

**Files created:**
- `.planning/phases/09-v1-drop-audit/09-05-SUMMARY.md` — FOUND (this file)

**Files modified:**
- `.planning/phases/09-v1-drop-audit/AUDIT.md` — FOUND (154 lines, all 4 sections populated)

**Commits:**
- `db182b6` — `docs(09-05): assemble shards into AUDIT.md sections` — FOUND in git log
- `00e6e65` — `docs(09-05): populate AUDIT.md Summary, flip Status to Complete` — FOUND in git log

**Acceptance criteria:**
- Task 1: 9/9 PASS (5 headers, 4 col-headers, 4 per-section row counts equal shards, today's date stamped, no emojis, no unexpected rows)
- Task 2: 11/11 PASS (counts populated, no TBD, internal consistency, bullet count = keep, every bullet names owner, ZDOTDIR first, SC#5 23/23, D-XX 12/12, Status Complete, structure preserved, no emojis)
- Idempotency: PASS (re-run produces byte-identical AUDIT.md)

**Success criteria:**
- AUDIT-04 closed (single canonical report with D-03 six-column shape + D-04 Summary structure)
- ROADMAP Phase 9 SC#5 cross-reference grep proof passes
- D-01, D-03, D-04 all enforced structurally on disk
- D-04 keep-list bullet block IS Phase 10's implementation queue (3 bullets, sorted, ZDOTDIR first)
- All 12 D-XX decisions cited somewhere in the assembled file
