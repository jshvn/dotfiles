---
phase: 14-comment-doc-trim
plan: 02
subsystem: code
tags: [comment-trim, banner-trim, taskfile, zsh, metrics, trim-01, trim-02]
requires:
  - 14-01 (teaching inventory + CLAUDE.md gap-fill)
provides:
  - 14-METRICS.md aggregate row (TRIM-01 SC#1 quantitative evidence)
  - 3-label banner shape applied across 42 files (TRIM-02 SC#2 satisfied)
affects:
  - 42 files trimmed across 8 tiers (Taskfile.yml + 13 taskfiles/*.yml +
    5 install scripts + 7 os/identity scripts + 5 shell startup files +
    5 claude hooks + 6 Class A shell function/alias files)
tech-stack:
  added: []
  patterns:
    - D-01 3-label banner (Purpose / Depends on / Side effects)
    - D-02 77-char `# === ===` rule above + below; no mid-file dividers
    - D-04 three-test KEEP rule (a non-obvious WHY / b still-live footgun
      / c lint citation)
key-files:
  created:
    - .planning/phases/14-comment-doc-trim/14-METRICS.md
  modified:
    - Taskfile.yml
    - taskfiles/{links,packages,identity,lint,claude,macos,manifest,test,shell,helpers,audit,show,refresh}.yml
    - install/{resolver,messages,compose-brewfile,test-hooks}.zsh
    - bootstrap.zsh (plan referenced install/bootstrap.zsh -- file actually
      lives at repo root; deviation Rule 3 path correction)
    - os/defaults/{dock,finder,input,screenshots,security}.zsh
    - os/shell-registration.zsh
    - identity/ssh/cloudflared.zsh
    - shell/{.zshenv,.zprofile,.zshrc,.zlogin,.zlogout,theme.zsh}
    - claude/hooks/{lib,secret-scan,no-emojis,no-ai-comments,agent-transparency}.zsh
    - shell/functions/{_dotfiles_feature,_dotfiles_require_feature}.zsh
    - shell/aliases/{jgrid,ghostty,finder,dotfiles}.zsh
decisions:
  - D-04 KEEP carve-outs preserved verbatim per CONTEXT line 80 + line 253:
    Taskfile.yml lines for DOTFILEDIR-leak workaround blocks (still-live
    footgun) + install: summary: block (non-obvious WHY for install-IS-update)
  - LINT-08 banner-parity rule body in taskfiles/lint.yml NOT touched
    (RESEARCH §"LINT-08 Banner-Parity Impact": task-parity not banner-parity;
    no fixture changes required)
  - Path correction (Rule 3): plan listed install/bootstrap.zsh; file lives
    at repo root as bootstrap.zsh -- trim applied to actual location
  - Per-tight-subsystem-group commit consolidation honored per Task 3
    action notes (5 os/defaults/ in one commit, 5 hooks in one commit,
    6 Class A files in one commit)
metrics:
  duration: ~2.5 hours
  completed: 2026-05-18
  commits: 27
  files_touched: 42
  comment_lines_pre: 2635
  comment_lines_post: 1257
  comment_lines_delta: -1378
  reduction_percent: 52
---

# Phase 14 Plan 02: Trim Pass Summary

Applied the 3-label banner shape (D-01/D-02/D-03) and the three-test KEEP rule (D-04) across every taskfile and executable .zsh file in scope. 1,378 inline comment lines stripped (52% reduction) while preserving every still-live footgun, non-obvious WHY, and lint citation called out in the 14-01 teaching inventory.

## What landed

| Artifact | Role |
|----------|------|
| 27 per-file (or per-tight-group) trim commits | one commit per file or per tight subsystem group; `task lint && task test && task install` green after every commit |
| `.planning/phases/14-comment-doc-trim/14-METRICS.md` | 43-row pre/post comment-to-code ratio table with aggregate totals |
| Banner-shape consistency | every taskfile and executable .zsh now carries the 3-label banner shape; no mid-file `# === <section> ===` dividers remain |
| LINT-NN catalogue references | inline `# LINT-NN:` citations preserved (D-04 (c)); cross-references to CLAUDE.md §Lint rule catalogue replace narrative explainers |

## Per-tier breakdown

| Tier | Files | Comment-line delta | Notes |
|------|------:|------------------:|-------|
| 1 (heaviest) | 2 | -194 | links.yml (-150) + .zlogout (-44) |
| 2 (heavy taskfiles) | 9 | -726 | Taskfile.yml -35, packages -124, identity -91, lint -78, claude -93, macos -85, manifest -73, test -54, shell -49 |
| 3 (already-minimal taskfiles) | 4 | -22 | helpers / audit / show / refresh; banner relabel `Callers:` -> `Depends on:` |
| 4 (install/) | 5 | -200 | resolver -73, messages -15, compose-brewfile -53, test-hooks -36, bootstrap -23 |
| 5 (os/ + identity) | 7 | -193 | dock -18, finder -26, input -26, screenshots -29, security -57, shell-registration -36, cloudflared -1 |
| 6 (shell startup) | 5 | -91 | .zshenv -18, .zprofile -24, .zshrc -33, .zlogin -6, theme.zsh -10 |
| 7 (claude/hooks/) | 5 | +11 | lib -14; the 4 hook scripts (already very lean, <10 comments each) gained the standardized 9-line 3-label banner -- TRIM-02 banner consistency wins over TRIM-01 reduction on already-lean files |
| 8 (Class A) | 6 | -31 | _dotfiles_feature -14, _dotfiles_require_feature -13, jgrid -5, ghostty -1, finder +2, dotfiles 0; banner-only trim per CONTEXT Claude's Discretion |
| **Total** | **42** | **-1,378 (52%)** | TRIM-01 SC#1 satisfied |

## Files where KEEP carve-outs were preserved verbatim

| File | Lines | Carve-out reason |
|------|-------|------------------|
| `Taskfile.yml` | DOTFILEDIR-leak blocks (formerly :131-148 + :240-248) | D-04 (b) still-live footgun -- the underlying TASKFILE_DIR-vs-DOTFILEDIR architectural fix is deferred to a future phase; the comment warns the next maintainer not to swap the var |
| `Taskfile.yml` | `install:` `summary: \|` block (formerly :212-216) | D-04 (a) non-obvious WHY -- operators need to know install-IS-update on first invocation; `task --summary install` renders both `desc:` and `summary:` |
| `taskfiles/lint.yml` | `banner-parity` task body (LINT-08 rule implementation) | RESEARCH §"LINT-08 Banner-Parity Impact" verdict: do NOT touch the rule body or its fixtures (task-parity check, not banner-shape check; fixture pair `08*-banner-parity-*` is the test surface, unaffected by the new banner shape) |
| `# lint-allow: cmds-without-status` markers across audit.yml, claude.yml, identity.yml, links.yml, macos.yml, packages.yml, shell.yml, test.yml | D-04 (c) functional pragma -- the lint suite reads (or will read) them as opt-out markers; never strip |
| `# LINT-NN:` citation comments throughout taskfiles | D-04 (c) lint citation -- code-to-rule cross-reference; survives D-04 KEEP test |

## Pre-existing LINT-02 false-positives resolved as a side effect

The lint suite's LINT-02 check scans the entire `.status:` blob (including comment lines) for shell-var references. Two pre-existing baseline failures came from `$VAR` references that lived inside COMMENT blocks (not real status logic):

- `taskfiles/claude.yml` ✗ -> ✓ (was triggered by `$i` in the CR-02 comment block at lines 139-146; the trim drops the CR-02 tag and the false-positive)
- `taskfiles/manifest.yml` ✗ -> ✓ (was triggered by `$out` in the WR-08 explainer block at lines 71-77; the trim shortens the comment and the false-positive)

The lint suite still uses run-all-aggregate semantics and exits 0; the surviving LINT-02 ✗ entries on `taskfiles/identity.yml` and `taskfiles/packages.yml` come from genuine `$f` / `$out` references inside `status:` block shell loops that pre-date Plan 14 and are out of scope for a comment-trim plan.

## Deviations from Plan

### Rule 3 — Auto-fix path reference (1 occurrence)

**1. [Rule 3 - Blocking issue] `install/bootstrap.zsh` path correction**
- **Found during:** Task 1 pre-snapshot
- **Issue:** Plan frontmatter and inventory referenced `install/bootstrap.zsh`; the actual file lives at the repository root as `bootstrap.zsh` (verified via `find . -maxdepth 3 -name "bootstrap*"`)
- **Fix:** Used the correct path `bootstrap.zsh` throughout the metrics table and the trim commit; documented inline in 14-METRICS.md preamble
- **Files modified:** `bootstrap.zsh`, `.planning/phases/14-comment-doc-trim/14-METRICS.md`
- **Commit:** `d0504b2` (also calls out the deviation in the commit body)

### Per-tight-subsystem-group commit consolidation (per Task 3 action notes)

Task 3 explicitly allowed per-tight-subsystem-group commits ("the 4 Tier-3 already-minimal taskfiles may be one commit since each is a one-line banner relabel; the 5 hooks may be one commit; the 6 Class A files may be one commit"). I additionally consolidated the 5 `os/defaults/` files into one commit (`0c8594c`) because they share an identical shape pattern. Each consolidated commit still passes `task lint && task test && task install` green; the line-count economy of 27 commits vs 38 separate commits is acceptable per the plan's flexibility note.

## Authentication gates

None encountered.

## Regression checks

Final full-suite gate (Task 4 close):
- `task lint` -> exit 0 (LINT-05 warnings are pre-existing baselines for `pbcopy` / `defaults read` / `defaults write` / `dscl` patterns in shell/aliases + os/defaults; explicit warn-only design)
- `task test` -> exit 0 (11 deep-merge fixtures pass + 8 hook smoke tests pass)
- `task install` -> exit 0 (full install pipeline + verify + reconcile pass; idempotent re-run)
- `task validate` -> exit 0 (manifest + identity + links + macos + packages + claude + shell validators all pass)

## Commits

27 commits between Plan 14-01 close (`55f9556`) and this summary:

| # | Hash | Subject |
|---|------|---------|
| 1 | `58b6a3a` | docs(14-02): pre-snapshot 14-METRICS.md for trim-pass measurement |
| 2 | `7770f34` | refactor(14-02): trim taskfiles/links.yml banner + inline comments |
| 3 | `7e76b1d` | refactor(14-02): collapse shell/.zlogout 51-line banner to 3-label shape |
| 4 | `8bc08b0` | refactor(14-02): trim Taskfile.yml banner + inline comments |
| 5 | `e012445` | refactor(14-02): trim taskfiles/packages.yml banner + inline comments |
| 6 | `c41d22e` | refactor(14-02): trim taskfiles/identity.yml banner + inline comments |
| 7 | `45baad1` | refactor(14-02): trim taskfiles/lint.yml banner + inline comments |
| 8 | `a7df562` | refactor(14-02): trim taskfiles/claude.yml banner + inline comments |
| 9 | `1f436d1` | refactor(14-02): trim taskfiles/macos.yml banner + inline comments |
| 10 | `f5c91f1` | refactor(14-02): trim taskfiles/manifest.yml banner + inline comments |
| 11 | `98d1c44` | refactor(14-02): trim taskfiles/test.yml banner + inline comments |
| 12 | `8a3ef4f` | refactor(14-02): trim taskfiles/shell.yml banner + inline comments |
| 13 | `837c061` | refactor(14-02): normalize Tier-3 taskfile banners to D-01 Depends-on label |
| 14 | `03800d2` | refactor(14-02): trim install/resolver.zsh banner + inline comments |
| 15 | `3b34bd4` | refactor(14-02): trim install/messages.zsh banner + inline comments |
| 16 | `5dd5ba6` | refactor(14-02): trim install/compose-brewfile.zsh banner + inline comments |
| 17 | `371ad7b` | refactor(14-02): trim install/test-hooks.zsh banner + inline comments |
| 18 | `d0504b2` | refactor(14-02): trim bootstrap.zsh banner + inline comments |
| 19 | `0c8594c` | refactor(14-02): trim 5 os/defaults/*.zsh banners + inline comments |
| 20 | `ccfa5f9` | refactor(14-02): trim os/shell-registration + identity/ssh/cloudflared |
| 21 | `9619972` | refactor(14-02): trim shell/.zshenv banner + inline comments |
| 22 | `65754cf` | refactor(14-02): trim shell/.zprofile banner + inline comments |
| 23 | `d33fb87` | refactor(14-02): trim shell/.zshrc banner + inline comments |
| 24 | `7595a46` | refactor(14-02): trim shell/.zlogin + shell/theme.zsh banners + inline comments |
| 25 | `12f881b` | refactor(14-02): normalize claude/hooks/*.zsh banners to 3-label shape |
| 26 | `1802c25` | refactor(14-02): trim 6 Class A heavy-banner files (functions + aliases) |
| 27 | `a18d24c` | docs(14-02): land 14-METRICS.md post-snapshot + aggregate row |

No commit message contains AI attribution; the no-ai-comments hook + project commit-format convention were honored on every commit.

## Plan 14-03 unblocked

Only docs/ + README + CLAUDE.md edits remain for Plan 14-03:
- `docs/MANIFEST.md` motd-drift surgical edits (RESEARCH §"docs/ Review Findings" R3)
- `docs/README.md` stale MIGRATION + CUTOVER ref removal
- `README.md` humans-only simplification (TRIM-04 D-06)
- `.claude/CLAUDE.md` deletion (TRIM-04 D-06/D-07)
- TRIM-05 closing `git grep` gate

Banner shape and inline-comment trim are complete repo-wide for v2 code surface; Plan 14-03's closing `git grep -E 'v1 (bug|finding|leftover)|Gap [0-9]+|D-[0-9]+|UAT [Gg]ap' -- ':!.planning/'` is the only remaining production gate.

## Final `task lint && task test && task install && task validate` exit code

**0** (all four gates green).

## Self-Check: PASSED

- `.planning/phases/14-comment-doc-trim/14-METRICS.md` -- FOUND
- All 42 trimmed files in `git status --short` previously, now committed -- VERIFIED
- 27 commits between `55f9556` and HEAD -- VERIFIED
- D-04 KEEP carve-outs (DOTFILEDIR-leak, install: summary:, LINT-08 banner-parity) -- VERIFIED present
- R1 LINT-04 head-30 sanity passes for every executable .zsh trimmed -- VERIFIED
- Zero TBD remaining in 14-METRICS.md -- VERIFIED
- Aggregate `% reduction` > 0 (52%) -- VERIFIED
- `task lint && task test && task install && task validate` exit 0 -- VERIFIED
- No commit message contains AI attribution -- VERIFIED (commit hook in place)
