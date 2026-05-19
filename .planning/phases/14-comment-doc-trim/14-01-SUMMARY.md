---
phase: 14-comment-doc-trim
plan: 01
subsystem: docs
tags: [teaching-inventory, claude-md, d-01-amend, d-09-gap-fill, gate]
requires:
  - PLAN.md frontmatter requirements [TRIM-04, TRIM-05]
provides:
  - 14-TEACHING-INVENTORY.md (gates Plan 14-02 strip pass)
  - CLAUDE.md amended (D-01 banner shape; D-09 NEEDS-ADD lessons preserved)
affects:
  - All 13 strip-pass files + 7 heavy-banner files (Plan 14-02 will trim them per the inventory's action column)
tech-stack:
  added: []
  patterns: [six-column-table house style, D-04 three-test KEEP rule, R6 size-guideline mitigation]
key-files:
  created:
    - .planning/phases/14-comment-doc-trim/14-TEACHING-INVENTORY.md
  modified:
    - CLAUDE.md
decisions:
  - D-01 contradiction resolved: "Purpose / Depends on / Side effects" replaces "purpose, callers, and side effects"
  - D-09 gate satisfied: 3 NEEDS-ADD lessons (DOTFILEDIR-leak Don't-Do, cross-field validation paragraph, LINT-NN catalogue) gap-filled into CLAUDE.md before Plan 14-02 strips the in-code annotations
  - R6 mitigation not needed: CLAUDE.md = 214 lines (<= 220 ceiling), so LINT-NN catalogue stays inline; .claude/rules/lint.md NOT created
  - D-02 narrowed: Section-separators bullet rewritten to "no mid-file dividers" (only the 77-char `# === ===` header banner remains permitted)
metrics:
  duration: ~20 minutes
  completed: 2026-05-18
---

# Phase 14 Plan 01: Teaching Inventory + CLAUDE.md Gap-Fill Summary

Built the pre-strip teaching inventory that gates the entire Phase 14 strip pass, then back-filled CLAUDE.md so every project-relevant lesson encoded as an in-code annotation survives the Plan 14-02 trim.

## What landed

| Artifact | Role |
|----------|------|
| `.planning/phases/14-comment-doc-trim/14-TEACHING-INVENTORY.md` | 162-row six-column table mapping every annotation block (>= 3 comment lines OR any strip-pattern token) across 13 strip-pass files + 7 heavy-banner files to its CLAUDE.md coverage. Three NEEDS-ADD rows surfaced and resolved. Strip Manifest section breaks the work down per-file for Plan 14-02. |
| `CLAUDE.md` (amended) | D-01 banner-shape contradiction resolved; three NEEDS-ADD lessons added; D-02 mid-file-divider bullet narrowed; total size 214 lines (under the 220 ceiling). |

## Inventory row distribution

| Action | Count |
|--------|------:|
| `strip after Plan 14-01` (pure tag-only or duplicate; no WHY survives) | 19 |
| `keep -- D-04 rule (a) WHY / (b) footgun / (c) lint citation` | 61 |
| `rewrite -- preserve WHY, strip planning tag` | 79 |
| `strip; do not gap-fill` (out of CLAUDE.md scope; zsh tutorial content) | 1 |
| zero-action coverage of remaining banner/section blocks | 2 |
| **Total distinct annotation blocks** | **162** |

(Total is distinct rows in the inventory; Plan 14-02's per-file edit count may be smaller when adjacent rows collapse into one rewrite.)

## Per-file row count (top 10 by density)

| File | rows |
|------|-----:|
| install/resolver.zsh | 19 |
| taskfiles/packages.yml | 18 |
| taskfiles/links.yml | 17 |
| taskfiles/lint.yml | 15 |
| taskfiles/identity.yml | 14 |
| taskfiles/manifest.yml | 12 |
| install/compose-brewfile.zsh | 11 |
| taskfiles/macos.yml | 11 |
| Taskfile.yml | 10 |
| taskfiles/claude.yml | 10 |
| taskfiles/test.yml | 10 |

Remaining files (cloudflared.zsh, os/shell-registration.zsh, shell/.zlogout, 4 alias files, 2 function helpers) each have 1-5 rows; combined total of 24.

## NEEDS-ADD rows resolved (D-09 gate)

Each row's CLAUDE.md insertion point named below, with the proposed wording landed in the actual file.

| # | Lesson | Surfaced by | CLAUDE.md insertion |
|---|--------|-------------|---------------------|
| 1 | DOTFILEDIR-leak Don't-Do | Taskfile.yml:73-82, :131-136, :224-247 (plus 7 included taskfiles that all define `DOTFILEDIR: { sh: dirname ... }`) | `§Don't Do` new bullet after line 200: "Don't define `DOTFILEDIR: { sh: dirname ... }` in included taskfiles -- it leaks into root scope under include-merge and competes with the root Taskfile.yml definition. Source `install/messages.zsh` via `{{.TASKFILE_DIR}}` (per the Taskfile.yml comment block warning the same)." |
| 2 | Cross-field validation rule | install/resolver.zsh:212-238 (D-16) | `§Rules > Manifests are the source of truth` new paragraph after line 50: 4-line paragraph documenting that the resolver enforces conditional rules across manifest sections (e.g., `identity.ssh in {personal, work}` requires `features.one-password-ssh = true`), with pointer to `validate_manifest` in `resolver.zsh`. |
| 3 | LINT-NN catalogue (LINT-01..08) | taskfiles/lint.yml:1-35 (full LINT-NN catalogue) + 6 LINT-NN section-header repeats | New `§Lint rule catalogue (LINT-01..08)` subsection inserted between §kebab-case feature names and §Every install task has a status: (lines 92-106). 8-row inline table summarizing each rule's scope and check. Inline (NOT extracted to `.claude/rules/lint.md`) because CLAUDE.md final size = 214 lines, safely under the R6 220-line ceiling. |

## CLAUDE.md size budget

| Metric | Value |
|--------|------:|
| Pre-amendment line count | 187 |
| Post-amendment line count | 214 |
| Lines added | 27 |
| 220-line ceiling (R6 mitigation threshold) | OK (6 lines of headroom) |
| `.claude/rules/lint.md` created? | no (inline catalogue fits) |

## D-01 amendment verification

- `grep -qE '^- File-level comment block at the top of every script: Purpose / Depends on / Side effects' CLAUDE.md` -- PASS
- `grep -qE 'purpose, callers, and side effects' CLAUDE.md` -- FAIL (old wording removed; this is the expected result)

## D-02 follow-up

The existing bullet "Section separators in YAML files use `# ===` or `# ---` banner style" conflicted with D-02 (no mid-file separators). Rewritten to: "The file-header banner uses one `# === ===` 77-char rule above and below the 3 labels; no mid-file dividers." This eliminates ambiguity about banner shape and removes permission for mid-file separators in a single bullet.

## Deviations from Plan

None -- plan executed exactly as written. The acceptance criteria were tracked verbatim; no Rule 1/2/3 auto-fixes were needed. All edits stayed inside the prescribed sites (CLAUDE.md §Conventions Not Captured Above, §Rules > Manifests, §Rules new subsection, §Don't Do).

## Authentication gates

None encountered.

## Regression checks

`task lint && task test` both exit 0 (the lint suite uses run-all-aggregate semantics; the LINT-02 / LINT-03b warnings shown in output are pre-existing baselines in `taskfiles/manifest.yml`, `taskfiles/packages.yml`, and the `03b-bare-ln` lint fixture -- none touch the files this plan modified, and none were introduced by 14-01).

## Commits

| Hash | Type | Description |
|------|------|-------------|
| 804e535 | docs(14-01) | build teaching inventory for 13 strip files + 7 banners |
| 0278867 | docs(14-01) | amend CLAUDE.md for D-01 banner + D-09 gap-fills |

## Plan 14-02 gate disposition

**UNBLOCKED.** Plan 14-02's strip pass has zero NEEDS-ADD blockers when it starts. The teaching inventory's `## Plan 14-02 Strip Manifest` section provides the per-file work breakdown (strip / keep / rewrite counts per file), and every lesson categorized as `rewrite` or `strip after Plan 14-01` is either (a) already covered by CLAUDE.md, (b) being preserved as an inline 1-3 line WHY comment after the planning tag is stripped, or (c) covered by one of the three NEEDS-ADD rows now in CLAUDE.md.

## Self-Check: PASSED

- `.planning/phases/14-comment-doc-trim/14-TEACHING-INVENTORY.md` -- FOUND
- `CLAUDE.md` -- FOUND (modified; 214 lines)
- Commit 804e535 -- FOUND in git log
- Commit 0278867 -- FOUND in git log
- D-01 amendment wording present -- VERIFIED
- D-01 old wording absent -- VERIFIED
- All 3 NEEDS-ADD lessons present in CLAUDE.md -- VERIFIED (cross-field-validation paragraph, LINT-NN catalogue header, DOTFILEDIR-leak Don't-Do bullet)
- CLAUDE.md size <= 220 -- VERIFIED (214 lines)
- task lint exit 0 -- VERIFIED
- task test exit 0 -- VERIFIED
