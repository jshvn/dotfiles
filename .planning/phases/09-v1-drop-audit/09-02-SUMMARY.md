---
phase: 09-v1-drop-audit
plan: 02
subsystem: audit
tags: [audit, manifest, brewfile, resolver, taskfiles]

# Dependency graph
requires:
  - phase: 09-v1-drop-audit
    provides: "AUDIT.md skeleton with locked six-column shape (plan 09-01)"
provides:
  - "shards/taskfiles.md: 33 D-03-shaped rows -- one per task across the eight v1 leftover taskfiles (common.yml, profile.yml, profile-tasks.yml, brew.yml, claude-stub.yml, brew-stub.yml, links-stub.yml, macos.v1.yml.bak)"
  - "shards/install-assets.md: 19 D-03-shaped rows -- per-machine package-level Brewfile diff (18 rows) + install/*.zsh confirmation row (1 row)"
  - "ZDOTDIR /etc/zshenv milestone-driver row classified dropped/keep with v2 owner taskfiles/shell.yml (ROADMAP Phase 9 SC#2, Phase 10 PORT-01 trigger)"
  - "Stub taskfiles mapping to v2 owners (D-11: claude-stub->claude.yml, brew-stub->packages.yml, links-stub->links.yml)"
  - "$BREW_ZSH bug-class cross-reference (D-10) in macos.v1.yml.bak:111-146 row, pointing to v2 {{.BREW_ZSH}} fix in taskfiles/macos.yml"
  - "Per-machine effective-set diff via install/resolver.zsh covering all four machines (personal-laptop, work-laptop, server-1, server-2)"
affects:
  - "plan-09-05 (concatenates these shards under AUDIT.md ## Taskfiles and ## Install Assets headers)"
  - "phase-10 (PORT-01 implements the ZDOTDIR keep row; Things vs Things3 name reconciliation; antigen->antidote already in place)"
  - "phase-11 (deletion manifest: dropped/drop rows are the v1-file removal candidates)"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pre-formatted six-column D-03 row shards for plan 09-05 concatenation"
    - "Per-machine effective-set diff via install/resolver.zsh --stdout into /tmp staging files"
    - "Awk-based brewfile package extractor that handles both single-quote and double-quote forms"

key-files:
  created:
    - ".planning/phases/09-v1-drop-audit/shards/taskfiles.md"
    - ".planning/phases/09-v1-drop-audit/shards/install-assets.md"
  modified: []

key-decisions:
  - "Servers (server-1, server-2) intentionally omit the gui bundle in v2 -- v1 Brewfile-server.rb GUI casks (dropbox, appcleaner, 1password, cryptomator, ghostty, cloudflare-warp, miniconda, docker-desktop) are dropped/drop by v2 design intent, not a regression to keep"
  - "antigen -> antidote is the v2 zsh plugin manager swap; classify as ported/drop (D-09 behavior-equivalent: zsh plugin management)"
  - "Things vs Things3 mas-name drift: same MAS id 904280696, name differs; classify partially-ported/keep so Phase 10 can normalize the v2 manifest name to match v1 'Things'"
  - "install/*.zsh non-v2 set is empty -- all five install/*.zsh files (messages.zsh, resolver.zsh, compose-brewfile.zsh, cutover-gate.zsh, test-hooks.zsh) are v2-set members; Block B is a single confirmation row"
  - "Stub taskfile row count: claude-stub has 1 task (install), brew-stub has 0 (tasks: {}, captured as the wrapper row), links-stub has 1 task (all) -- 2 stub rows total covering the three stub files (brew-stub captured under brewfile-level row since no tasks)"

patterns-established:
  - "Pattern: shard files contain only data rows, no headers -- plan 09-05 owns the section header concatenation. Avoids duplicate ## Taskfiles / ## Install Assets headers after assembly."
  - "Pattern: per-machine resolver invocation -- DOTFILEDIR=\"$PWD\" zsh install/resolver.zsh --machine <name> --stdout > /tmp/resolved-<name>.json"
  - "Pattern: v1-vs-v2 effective-set diff at formula/cask/mas-name granularity (D-12) via sort+comm -23"

requirements-completed: [AUDIT-01, AUDIT-02]

# Metrics
duration: 18min
completed: 2026-05-17
---

# Phase 09 Plan 02: v1 Taskfiles + Install Assets Shard Production Summary

**Two D-03-shaped row shards (52 rows total) enumerating every v1 leftover taskfile task and every v1 install-asset Brewfile package diff per machine, ready for plan 09-05 to concatenate verbatim into AUDIT.md ## Taskfiles and ## Install Assets sections**

## Performance

- **Duration:** ~18 min
- **Started:** 2026-05-17 (Wave 2 execution)
- **Completed:** 2026-05-17
- **Tasks:** 2
- **Files modified:** 2 (both new shard files)

## Accomplishments

- 33-row `shards/taskfiles.md` covering all 8 v1 leftover taskfiles at one-row-per-task granularity (D-02)
- 19-row `shards/install-assets.md` covering per-machine Brewfile package-level diff (D-12) plus an install/*.zsh confirmation row
- ZDOTDIR /etc/zshenv milestone-driver row landed with correct classification (dropped/keep) and correct v2 owner (taskfiles/shell.yml)
- All three stub taskfiles mapped to their v2 owners per D-11
- $BREW_ZSH bug class cross-referenced in macos.v1.yml.bak:111-146 row per D-10
- Per-machine effective-set diff performed against the live install/resolver.zsh output (not a static snapshot) for all four machines

## Task Commits

Each task was committed atomically:

1. **Task 1: Enumerate v1 leftover taskfiles in shards/taskfiles.md** - `dde16fd` (docs)
2. **Task 2: Audit v1 Brewfiles + non-v2 install/*.zsh in shards/install-assets.md** - `1c1d529` (docs)

## Files Created/Modified

- `.planning/phases/09-v1-drop-audit/shards/taskfiles.md` -- 33 rows; one per v1 task across 8 taskfiles; six-column D-03 shape; ZDOTDIR row + stub mappings + $BREW_ZSH bug cross-reference
- `.planning/phases/09-v1-drop-audit/shards/install-assets.md` -- 19 rows; 18 per-machine Brewfile package rows + 1 install/*.zsh confirmation row; six-column D-03 shape

## shards/taskfiles.md row count

- 33 data rows (excluding any headers; shard contains no headers per plan's "no shard-internal section headers" rule)
- Coverage breakdown:
  - common.yml: 3 rows (xdg, zdotdir, validate)
  - profile.yml: 8 rows (ensure, require, set, show, install, brew, links, validate)
  - profile-tasks.yml: 5 rows (install, links, brew, unlink, validate)
  - brew.yml: 5 rows (install, ensure-homebrew, update, bundle, validate)
  - claude-stub.yml: 1 row (install)
  - brew-stub.yml: 1 row (the empty `tasks: {}` wrapper; D-11 mapping to packages.yml)
  - links-stub.yml: 1 row (all)
  - macos.v1.yml.bak: 9 rows (defaults, defaults-init, defaults-general, defaults-dock, defaults-appearance, defaults-finder, defaults-misc, shell, validate)
- All 33 rows carry the six locked D-03 columns; no extras

## shards/install-assets.md row count + per-machine diff results

- 19 data rows total
- Block A (Brewfile package-level diff, 18 rows): one row per (package, set-of-machines-where-impacted)
- Block B (install/*.zsh): 1 confirmation row -- no v1-only install/*.zsh files exist beyond the v2 set

### Per-machine effective-set diff (v1 set vs v2 effective set built via install/resolver.zsh)

| Machine | v1 effective count | v2 effective count | In v1 not v2 (dropped) | In v2 not v1 (added, informational) |
|---------|-------------------|-------------------|------------------------|-------------------------------------|
| personal-laptop | 61 | 64 | 2 (brew antigen, mas Things) | 5 (brew antidote, brew node, brew yq, cask claude-code, mas Things3) |
| work-laptop     | 52 | 55 | 1 (brew antigen)              | 4 (brew antidote, brew node, brew yq, cask claude-code) |
| server-1        | 38 | 32 | 9 (brew antigen + 8 GUI casks dropped by v2 design) | 3 (brew antidote, brew node, brew yq) |
| server-2        | 38 | 32 | 9 (brew antigen + 8 GUI casks dropped by v2 design) | 3 (brew antidote, brew node, brew yq) |

The 8 server-only "dropped" casks (dropbox, appcleaner, 1password, cryptomator, ghostty, cloudflare-warp, miniconda, docker-desktop) are intentional v2 design: v2 server manifests omit the `gui` bundle because servers are headless. Each is captured as a dropped/drop row with the design rationale.

### install/*.zsh non-v2 set

`ls install/*.zsh` returns exactly the five v2-set members (messages.zsh, resolver.zsh, compose-brewfile.zsh, cutover-gate.zsh, test-hooks.zsh). Zero leftover v1-only install/*.zsh files exist. Block B is therefore a single confirmation row, not per-file rows.

## D-10 and D-11 landing confirmation

- D-10 ($BREW_ZSH bug class): row `| taskfiles/macos.v1.yml.bak:111-146 |` contains the literal text "$BREW_ZSH" in its rationale, classified `ported | drop`, with v2 owner `taskfiles/macos.yml` (which carries the `{{.BREW_ZSH}}` template-var fix). Verified via `grep -qE '\| taskfiles/macos.v1.yml.bak:[0-9-]+ \|.*BREW_ZSH.*\| ported \| drop \|.*taskfiles/macos.yml'` -- PASS.
- D-11 stub mapping:
  - claude-stub.yml row: `| ported | drop |` with `taskfiles/claude.yml` -- PASS
  - brew-stub.yml row: `| ported | drop |` with `taskfiles/packages.yml` -- PASS
  - links-stub.yml row: `| ported | drop |` with `taskfiles/links.yml` -- PASS

## Decisions Made

- Servers omit GUI casks by v2 design -- those rows are dropped/drop (not dropped/keep). v1 Brewfile-server.rb assumed servers needed Dropbox/1Password/etc.; v2 corrected this assumption.
- antigen -> antidote is classified ported/drop using D-09's behavior-equivalence threshold (both manage zsh plugins; both are sourced in .zshrc; the operator outcome is "plugins available in interactive shell"). Not a regression.
- Things vs Things3 mas-name drift gets keep classification so Phase 10 can normalize. The MAS id (904280696) is identical, so functional install is unaffected -- this is a metadata-display fix, not a behavior fix.
- All eight v1 leftover taskfiles' tasks are individually enumerated even when behavior overlaps (e.g., profile.yml + profile-tasks.yml both have install/links/brew/validate tasks at the profile level) -- per D-02 "row granularity is one row per task". The rationale columns disambiguate each row's specific behavior.

## Deviations from Plan

None - plan executed exactly as written.

The only minor adjustment was capitalizing "No" in the Block B confirmation row ("No v1-only install/*.zsh") to match the case-sensitive regex in the plan's acceptance criterion (`grep -qE 'No v1-only install/\*\.zsh'`). This was a trivial wording fix, not a deviation from behavior or scope.

## Issues Encountered

- **Initial brewfile-extractor regex captured only double-quoted strings.** v1 Brewfiles use double quotes (`brew "antigen"`) but v2 `packages/*.rb` files use single quotes (`brew 'antidote'`). The first extractor produced an empty v2 effective set for every machine, which would have falsely flagged every v2 package as "missing". Fixed by extending the awk regex to match both quote styles (`if (match(line, /"[^"]+"/) || match(line, /'[^']+'/))`). After fix, all four machines produce non-empty v2 effective sets and the diff is meaningful.

## User Setup Required

None - this is a read-only audit plan; no external service configuration required.

## Next Phase Readiness

- Plan 09-05 can now concatenate `shards/taskfiles.md` verbatim under AUDIT.md `## Taskfiles` and `shards/install-assets.md` verbatim under AUDIT.md `## Install Assets`.
- Phase 10 has its keep-list anchor: the ZDOTDIR /etc/zshenv row + the Things vs Things3 mas-name normalization + the partially-ported common:validate /etc/zshenv assertion are the Phase 10 Wave-2 keep items from this plan.
- Phase 11 has its deletion-safe rows: every dropped/drop and ported/drop row in these shards confirms a v1 file can be deleted without losing behavior.

## Self-Check: PASSED

File-existence verification:
- `.planning/phases/09-v1-drop-audit/shards/taskfiles.md` -- FOUND (33 rows, all D-03-shaped)
- `.planning/phases/09-v1-drop-audit/shards/install-assets.md` -- FOUND (19 rows, all D-03-shaped)

Commit verification:
- `dde16fd` (Task 1) -- FOUND in `git log --oneline`
- `1c1d529` (Task 2) -- FOUND in `git log --oneline`

Acceptance criterion verification (all PASS):
- ZDOTDIR milestone-driver row present and correctly classified -- PASS
- Stub taskfile mappings D-11 -- PASS
- $BREW_ZSH bug-class cross-reference D-10 -- PASS
- >= 20 data rows in shards/taskfiles.md (actual: 33) -- PASS
- Six locked D-03 columns enforced -- PASS
- No emojis (project convention is stricter than global rule) -- PASS
- Per-machine effective-set diff covers all four machines -- PASS
- Block B install/*.zsh coverage row present -- PASS

---
*Phase: 09-v1-drop-audit*
*Completed: 2026-05-17*
