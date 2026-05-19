---
phase: 14
slug: comment-doc-trim
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-18
---

# Phase 14 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: 14-RESEARCH.md §"Validation Architecture".

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | go-task task suite (`task lint`, `task test`, `task install`, `task validate`) + `git grep` for SC#5 |
| **Config file** | `Taskfile.yml` + `taskfiles/*.yml` + `taskfiles/test/lint-fixtures/*` |
| **Quick run command** | `task lint && task test` |
| **Full suite command** | `task lint && task test && task install && task validate` |
| **Estimated runtime** | ~30s quick / ~90s full (smoke + idempotent re-install) |

---

## Sampling Rate

- **After every task commit (per-file trim):** `task lint && task test`
- **After every plan wave (per-plan close):** `task lint && task test && task install && task validate` + `git grep` SC#5 spot-check on files touched this wave
- **Before `/gsd:verify-work` (phase gate):** Full suite + SC#5 grep gate returns "PASS" + `14-METRICS.md` aggregate row shows positive overall `% reduction` + `14-TEACHING-INVENTORY.md` present with all NEEDS-ADD rows resolved
- **Max feedback latency:** ~30s (quick) / ~90s (full)

---

## Per-Task Verification Map

> Tasks are filled in by the planner (Plan 14-01, 14-02, 14-03). Skeleton rows below map each requirement to its evidence type per RESEARCH §"Validation Architecture". `Wave 0` marks artifacts that must exist before the task can be verified.

| Req ID | Behavior | Test Type | Automated Command | Wave 0 Artifact |
|--------|----------|-----------|-------------------|-----------------|
| TRIM-01 | Inline comment ratio drops per-file; restatement removed | artifact + smoke | `cat .planning/phases/14-comment-doc-trim/14-METRICS.md` ; `wc -l` + `grep -cE '^[[:space:]]*#'` pre/post per file | `14-METRICS.md` (Plan 14-02) |
| TRIM-02 | Banner shape consistent across files (3 labels + `# === ===` rule above/below; no narrative prose) | manual sample + lint smoke | spot-check 3–5 trimmed taskfiles + 2 `.zsh` scripts; `task lint` green (LINT-04 head-30 + LINT-07 zsh -n) | none (uses existing lint suite) |
| TRIM-03 | `docs/` reviewed; obsolete content removed | grep + artifact | `git grep -n motd docs/MANIFEST.md` returns 0 hits; `git grep -n 'Phase 1 note' docs/` returns 0 hits; `ls docs/` matches the curated set | none |
| TRIM-04 | Three audience docs deduped to canonical homes (`.claude/CLAUDE.md` deleted) | grep + artifact | `test ! -f .claude/CLAUDE.md` ; `diff <(grep '^##' README.md) <(grep '^##' CLAUDE.md) \| wc -l` shows ≤2 shared headers | none |
| TRIM-05 | SC#5 grep gate returns zero matches in code | grep gate | `git grep -E 'v1 (bug\|finding\|leftover)\|Gap [0-9]+\|D-[0-9]+\|UAT [Gg]ap' -- ':!.planning/' \|\| echo PASS` returns "PASS" | none |
| TRIM-05 (prereq) | Teaching inventory built before strip pass | artifact | `cat .planning/phases/14-comment-doc-trim/14-TEACHING-INVENTORY.md` ; verify every annotation block ≥3 lines mapped to `CLAUDE.md §X` or `NEEDS-ADD` row resolved | `14-TEACHING-INVENTORY.md` (Plan 14-01) |

*Status: planner fills per-task rows during plan generation.*

---

## Wave 0 Requirements

- [ ] `14-TEACHING-INVENTORY.md` — Plan 14-01 creates. Six-column table per Phase 12 D-14 / Phase 13 REVIEW house style: `file:line | snippet | lesson encoded | covered by CLAUDE.md §X | NEEDS-ADD? | action`. Required before any TRIM-05 strip pass.
- [ ] `14-METRICS.md` — Plan 14-02 creates. Pre-snapshot taken at Plan 14-02 start (before any trim commit lands); post-snapshot at Plan 14-02 close. Columns: `file | code_lines | comment_lines_pre | comment_lines_post | delta | %_reduction` + aggregate row.
- [ ] No new test framework install needed — the existing `task lint` + `task test` suite covers all phase requirements.

> **Note (informational):** `shellcheck` is NOT installed locally and is NOT invoked by `task lint` (LINT-07 is `zsh -n` only). Do NOT add a shellcheck step to Phase 14 that does not exist today.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Banner shape conformance (3 labels, no narrative, single `# === ===` rule above/below) | TRIM-02 | Banner content is qualitative (D-03 explicitly rejects a hard char-count gate); no lint rule enforces the exact 3-label vocabulary | After each trim commit, spot-check the touched file: open in editor, confirm: (a) one 77-char `# === ===` rule above and one below; (b) exactly the labels `Purpose`, `Depends on`, `Side effects`; (c) no narrative prose, no examples, no change history; (d) no mid-file `# === <section> ===` dividers |
| `docs/` reviewed for stale content + clear purpose | TRIM-03 | Subjective "clear purpose" judgment; grep covers known stale tokens (`motd`, `Phase 1 note`) but not every drift case | Plan 14-03 task: per-doc read-through; for each remaining doc in `docs/`, write a 1-line "purpose + current-accuracy" assertion in the commit message |
| README/CLAUDE.md content split honors D-06 (humans-only vs canonical-AI-ref) | TRIM-04 | Audience split is qualitative; the grep diff catches header overlap but not paragraph-level duplication | After Plan 14-03's README/CLAUDE.md edits, manual cross-read: README must not contain any rule that an AI agent needs; CLAUDE.md must not contain "what is this repo" intro text suited for humans only |

---

## Risk-Driven Verification Additions

> From RESEARCH §"Refined Risk Surface" — risks that need an explicit verify step in the per-task map.

| Risk | Verify Step | Where to Run |
|------|-------------|--------------|
| R1: LINT-04 head-30 window | After any banner trim on an executable `.zsh`, run `head -30 <file> \| grep -q '^set -euo pipefail$'` | Per-task verify in Plan 14-02 for touched `.zsh` files |
| R3/R4: docs/MANIFEST.md drift | TRIM-03 task includes explicit `git grep` for `motd` (target: 0 hits) and `task -t taskfiles/manifest.yml` (target: 0 hits in `docs/`) | Plan 14-03 TRIM-03 task |
| R6: CLAUDE.md size after gap-fills | `wc -l CLAUDE.md` after Plan 14-01 completes; if > 220 lines, planner splits LINT catalogue into `.claude/rules/lint.md` | Plan 14-01 close gate |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies declared
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify (quick suite runs after every task commit per D-Discretion green-tree rule)
- [ ] Wave 0 covers all MISSING references (`14-TEACHING-INVENTORY.md`, `14-METRICS.md`)
- [ ] No watch-mode flags introduced
- [ ] Feedback latency < 90s (full suite)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
