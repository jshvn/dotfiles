# Phase 9: v1-Drop Audit - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-17
**Phase:** 9-v1-drop-audit
**Areas discussed:** AUDIT.md shape, zsh/ vs shell/ comparison method, Already-ported threshold

---

## AUDIT.md Shape

### Top-level organization

| Option | Description | Selected |
|--------|-------------|----------|
| Sectioned by leftover category | H2 sections: Taskfiles / Install Assets / zsh Tree / Docs; each with its own 6-column table | ✓ |
| One mega-table sorted by file path | Single 6-column table covering all leftovers; max cross-referenceability via Cmd-F | |
| Sectioned by classification (keep/drop/ported) | Top-level sections by verdict; easiest "show me everything to port" view | |

**User's choice:** Sectioned by leftover category.
**Notes:** Maps 1:1 to AUDIT-01..05 and makes section-by-section work natural for Phase 10.

### Row granularity inside Taskfiles section

| Option | Description | Selected |
|--------|-------------|----------|
| One row per task | common.yml:36-57 zdotdir is its own row; common.yml:80-95 zdotdir-validate is another | ✓ |
| One row per taskfile, with task list in 'purpose' cell | Eight rows total; easier at-a-glance, loses per-task verdict granularity | |
| One row per behavior (group across taskfiles) | e.g., "ZDOTDIR write" is one row sourcing from common.yml:36-57; cleaner narrative, loses file:line discipline | |

**User's choice:** One row per task.
**Notes:** Matches AUDIT-04 "every defined task is enumerated" and SC#5's grep cross-reference test.

### Additional structured columns beyond the six required

| Option | Description | Selected |
|--------|-------------|----------|
| Add 'Phase 10 priority' column | Sort hint for Phase 10 implementation order; P0 = blocks fresh-machine install | |
| Stick to the six SC-required columns only | file:line, purpose, v2 status, classification, rationale, v2 owner — nothing else | ✓ |
| Add 'evidence' column | Each row carries the literal grep/diff command output backing its v2 status verdict | |

**User's choice:** Stick to the six SC-required columns only.
**Notes:** Cleanest spec match; Phase 10 derives priority from the rationale text and the keep-list bullet ordering.

### Top-of-document summary surface

| Option | Description | Selected |
|--------|-------------|----------|
| Counts table + keep-list bullet list | Totals (X tasks audited, Y keep, Z drop, W already-ported) plus an explicit bullet list of every keep item with its v2 owner | ✓ |
| Counts only | Just the totals; Phase 10 grep's the tables for keep rows | |
| Executive summary paragraph | One prose paragraph naming the headline findings | |

**User's choice:** Counts table + keep-list bullet list.
**Notes:** The bullet list becomes Phase 10's implementation queue.

---

## zsh/ vs shell/ Comparison Method

### Functions present in both trees — comparison primitive

| Option | Description | Selected |
|--------|-------------|----------|
| Diff body, classify by behavior | diff zsh/functions/<name>.zsh shell/functions/<name>.zsh; if non-zero, classify identical / ported-with-documented-delta / partial port | ✓ |
| Filename-presence only | If shell/functions/<name>.zsh exists, mark v2 status = ported; fastest, misses inside-the-file dropped behaviors | |
| Byte-equivalence required | Any diff → 'partial port'; flags every intentional v2 improvement, lots of noise | |

**User's choice:** Diff body, classify by behavior.
**Notes:** The inside-the-file silent drift class is exactly the bug class that produced this milestone.

### v1 zsh/aliases/{common,personal}/ vs flat v2 shell/aliases/ — comparison

| Option | Description | Selected |
|--------|-------------|----------|
| Build v1 effective-set then diff against v2 set | Concatenate v1 common/*.zsh + personal/*.zsh under the personal profile; flatten and diff against shell/aliases/*.zsh | ✓ |
| Map v1 file-by-file to expected v2 file | v1 common/general.zsh → v2 general.zsh; loses _dotfiles_feature gating coverage | |
| Alias-name-level comparison only | Set-diff alias names; misses behavioral changes (same name, different command) | |

**User's choice:** Build v1 effective-set then diff against v2 set.
**Notes:** Captures both per-profile losses and content drift inside same-named alias files.

### zsh/configs/ and zsh/styles/ vs configs/ — audit depth

| Option | Description | Selected |
|--------|-------------|----------|
| Diff each v1 file against its v2 sibling | Content-level diff per file; catches operator hand-edits that diverged silently | ✓ |
| Presence + symlink-target check only | Trust Phase 7 TOOL-04; fastest, won't catch hand-edits | |
| Skip configs/styles entirely — Phase 7 already ported them | Trust Phase 7's TOOL-02 verification; one row per directory | |

**User's choice:** Diff each v1 file against its v2 sibling.
**Notes:** Tool configs change rarely; behavioral drift here usually means hand-edited v1 forgotten in the port.

### Six startup files — audit shape

| Option | Description | Selected |
|--------|-------------|----------|
| One row per startup file with block-by-block diff in rationale | Six rows total; rationale cell lists each v1 block and its v2 disposition | ✓ |
| One row per dropped or partially-ported behavior | Skip per-file structure; rows only for behaviors that need a verdict | |
| Run zsh -x trace on both v1 and v2 shells, diff the trace | Most exhaustive; surfaces order-of-operations differences invisible to source diff | |

**User's choice:** One row per startup file with block-by-block diff in rationale.
**Notes:** Surfaces every block-level decision without inflating to per-line rows. Trace-level comparison deferred unless Phase 10 surfaces unexpected order-of-operations bugs.

---

## Already-Ported Threshold

### Headline rule for "ported" vs "partially-ported"

| Option | Description | Selected |
|--------|-------------|----------|
| Behavior-equivalent under v2 manifest model | Same operator-visible outcome on the same machine; bar is "on personal-laptop today, does it still work the same way?" | ✓ |
| Code-equivalent (any v1 line missing → partial) | Most surgical, lots of 'partial' rows for intentional v2 improvements | |
| Operator-equivalent across ALL four machines | Strictest; surfaces inter-machine drift but doubles audit complexity | |

**User's choice:** Behavior-equivalent under v2 manifest model.
**Notes:** Matches PROJECT.md's existing "feature parity confirmed via task validate per machine" bar.

### v2-fixes-a-v1-bug rows

| Option | Description | Selected |
|--------|-------------|----------|
| Ported, with 'v1 bug fixed' in rationale | v2 status = ported; rationale names the bug and points to the v2 fix | ✓ |
| Already-ported (fourth verdict added) | Add 'fixed-and-ported' beyond ported/partial/dropped; breaks the SC#1 three-value enum | |
| Treat the v1 line as 'dropped' | Most literal; mixes intentional improvement with silent loss in the same bucket | |

**User's choice:** Ported, with 'v1 bug fixed' in rationale.
**Notes:** Tracks the fix for milestone-summary use without inflating the 'partial' count or breaking the SC enum.

### Stub taskfiles (claude-stub.yml, brew-stub.yml, links-stub.yml)

| Option | Description | Selected |
|--------|-------------|----------|
| Already-ported — v2 real file supersedes | v2 status = ported; classification = drop; rationale points to the v2 owner | ✓ |
| Dropped, with no v2 replacement | Inaccurate — they were placeholders that were replaced by real files | |
| Skip in AUDIT.md entirely — they're not 'features' | Breaks audit-coverage contract; SC#1 explicitly names them | |

**User's choice:** Already-ported — v2 real file supersedes.
**Notes:** They're scaffolds, not features; the v2 owner column points to claude.yml / packages.yml / links.yml.

### v1 Brewfiles — package-level comparison primitive

| Option | Description | Selected |
|--------|-------------|----------|
| Set-diff every formula/cask/mas line | Build v1 effective set per machine (Brewfile.rb + Brewfile-<profile>.rb) and v2 effective set from resolved.json; set-diff at the name level per machine | ✓ |
| Bundle-name comparison only | Compare bundle names; if every v1 bundle has a v2 equivalent, mark ported; misses silently-dropped packages | |
| Skip Brewfile audit — Phase 5 already verified composition | Trust Phase 5 PKGS verification; risks any silently-dropped package slipping past (PKGS verify only checks declared packages) | |

**User's choice:** Set-diff every formula/cask/mas line.
**Notes:** PKGS verification only checks declared packages, so a silently-dropped v1 package would slip past without per-line set-diff.

---

## Claude's Discretion

- Plan breakdown gray area (one audit plan vs split by leftover category) was offered but not selected. Planner picks. Recommendation in CONTEXT.md is to split by section to match AUDIT.md section boundaries; single-plan walk is also viable.
- Scope of v1 doc review (AUDIT-05) was offered but not selected. Planner picks. Baseline coverage: `install/README.md` + obvious doc fragments not present in v2 `docs/`. Deeper git-history archeology is optional.

## Deferred Ideas

- Phase 10 priority column or evidence column on AUDIT.md rows — rejected for v2.1; a later milestone can add priority if Phase 10 has trouble ordering from the keep-list bullets alone.
- `zsh -x` trace-level comparison for the 6 startup files — rejected as overkill for read-only audit; available as a fallback if Phase 10 surfaces unexpected order-of-operations bugs.
