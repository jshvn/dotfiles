---
phase: 03-shell-layer-flat-content-port
plan: 06
subsystem: shell
tags: [zsh, antidote, source-order, jgrid-net, gap-closure]

requires:
  - phase: 03-shell-layer-flat-content-port
    provides: shell/.zshrc (Plan 03-02), shell/functions/_dotfiles_feature.zsh (Plan 03-03), shell/aliases/jgrid.zsh (Plan 03-04), taskfiles/common.yml (Phase 2)
provides:
  - shell/.zshrc with functions glob loaded before aliases glob (theme between them)
  - taskfiles/common.yml with antigen-update task and validate aggregator antigen check removed
  - CR-01 BLOCKER closed (D-08 source-time gate in jgrid.zsh evaluates correctly)
  - Truth 4 of 03-VERIFICATION.md satisfied (antidote-replaces-antigen contract met for v2-ship files)
affects: [phase-04-identity-machines, phase-05-packages-migration]

tech-stack:
  added: []
  patterns: [functions-before-aliases-load-order, source-time-feature-gate]

key-files:
  created: []
  modified:
    - shell/.zshrc
    - taskfiles/common.yml

key-decisions:
  - "Source order: functions glob -> theme.zsh -> aliases glob. Theme keeps its position between functions and aliases (preserves Plan 03-02's documented late-init intent while letting the D-08 source-time gate work)."
  - "Antigen install entry in install/Brewfile.rb (v1 packages) is intentionally NOT removed by this plan. The plan files_modified scope is shell/.zshrc + taskfiles/common.yml; the v1 Brewfile cleanup belongs to the Phase 5 packages migration (packages/*.rb)."

patterns-established:
  - "Pattern: when an alias file uses a source-time feature gate (D-08), the functions glob must load before the aliases glob in shell/.zshrc. This is the v2 load-order contract."

requirements-completed:
  - SHEL-03
  - SHEL-04
  - SHEL-08

duration: 12min
completed: 2026-05-15
---

# Plan 03-06: CR-01 Gap Closure Summary

**Source order in shell/.zshrc fixed (functions before aliases) and antigen residue purged from taskfiles/common.yml; jgrid metal-jump aliases now land on personal-laptop when features.jgrid-net=true.**

## Performance

- **Duration:** ~12 min (inline, after worktree base-mismatch recovery)
- **Started:** 2026-05-15T01:55:00Z (inline retry; original parallel worktree blocked on permission denial)
- **Completed:** 2026-05-15T02:08:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- CR-01 BLOCKER closed: shell/.zshrc sources `shell/functions/*.zsh` before `shell/aliases/*.zsh`. The D-08 source-time gate in `shell/aliases/jgrid.zsh:17` (which calls `_dotfiles_feature`) now resolves correctly.
- Antigen residue purged from taskfiles/common.yml: `common:antigen-update` task removed entirely; `common:validate` aggregator no longer calls `_:check-file` against `$HOMEBREW_PREFIX/share/antigen/antigen.zsh`; `validate` desc updated to drop the Antigen mention.
- End-to-end smoke test confirms `alias steel='ssh josh@steel-ssh.jgrid.net'` is defined under `features.jgrid-net=true`.

## Task Commits

1. **Task 1: Swap source order in shell/.zshrc (functions -> theme -> aliases)** -- `470ce98` (fix)
2. **Task 2: Drop antigen residue from taskfiles/common.yml** -- `3a01200` (fix)

## Files Created/Modified

- `shell/.zshrc` -- Reordered three source blocks. Functions glob (with updated leading comment) now precedes theme.zsh, which precedes the aliases glob (with updated leading comment). No other lines changed.
- `taskfiles/common.yml` -- Deleted the `antigen-update` task (12 lines) and the trailing `_:check-file` for Antigen in the `validate` task. Updated `validate.desc` from `"Validate common components (XDG, ZDOTDIR, Antigen)"` to `"Validate common components (XDG, ZDOTDIR)"`. Three tasks remain: `xdg`, `zdotdir`, `validate`.

## Decisions Made

- **Load order: functions -> theme -> aliases (not functions -> aliases -> theme).** Theme.zsh sets `ZSH_THEME_GIT_*` env vars consumed by the omz-git plugin already loaded by antidote. No alias file references theme vars at load time, and no function file references theme vars. The minimal CR-01 fix is to swap functions and aliases positions while keeping theme.zsh between them. This preserves Plan 03-02 Task 3 action item #9 in spirit (theme as late init) while ensuring functions are defined before aliases source.
- **install/Brewfile.rb antigen entry left in place.** Plan 03-06's `files_modified` is `shell/.zshrc` and `taskfiles/common.yml`. The v1 Brewfile still contains `brew "antigen"` at line 71 with a `# antigen is a plugin manager for zsh` comment at line 70. That cleanup belongs to the Phase 5 packages migration (packages/<purpose>.rb), where the v1 Brewfile is replaced wholesale.

## Deviations from Plan

### Orchestration deviation: parallel worktree -> inline (sequential) execution

- **Plan called for:** parallel worktree execution alongside plans 03-07 and 03-08 (all three are Wave 1 gap-closure plans with disjoint `files_modified`).
- **What happened:** the initial worktree executor was denied Edit/Write tools on `shell/.zshrc` and `taskfiles/common.yml`. After the user granted Edit/Write permissions, the relaunched worktree was spawned at an incorrect base commit (`a321531`, an older pre-v2 commit) -- the worktree branch did not pick up the current HEAD (`e3a6597`). The required `git reset --hard e3a6597` was denied inside the worktree.
- **Fix:** plans 03-07 and 03-08 completed successfully in their worktrees; their branches were merged back to `josh/dotfiles-v2-refactor`. Plan 03-06 was then executed inline on the main working tree (sequential mode), which let Edit/Write happen directly with user-approved permissions and on the correct base. The two task commits (`470ce98`, `3a01200`) reflect this inline run.
- **No content deviations from plan.** The edits applied are exactly the surgical changes specified in Tasks 1 and 2.

## Verification

All plan acceptance criteria pass:

- `zsh -n shell/.zshrc` exits 0 (file parses)
- Order: `awk` confirms functions glob (line 110) precedes theme.zsh (line 115) precedes aliases glob (line 118)
- `task --list-all -t taskfiles/common.yml` lists exactly 3 tasks: `xdg`, `zdotdir`, `validate`
- `grep -c 'antigen' taskfiles/common.yml` returns 0
- Negative smoke test (no resolved.json): `command not found: _dotfiles_feature` count = 0
- Positive smoke test (jgrid-net=true): `alias steel='ssh josh@steel-ssh.jgrid.net'` is defined
- Repo-wide sweep over `.yml`/`.zsh`/`.md`/`.toml` (excluding `.planning/`, `zsh/`, `.git/`, `.claude/`): zero antigen references

## Self-Check: PASSED

- [x] Both tasks executed
- [x] Each task committed individually (`470ce98`, `3a01200`)
- [x] SUMMARY.md created (this file)
- [x] No modifications to STATE.md or ROADMAP.md (orchestrator owns those)
- [x] End-to-end smoke tests pass for both feature-off and feature-on paths
