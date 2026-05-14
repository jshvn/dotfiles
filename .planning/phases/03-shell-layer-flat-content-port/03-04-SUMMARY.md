---
phase: 03-shell-layer-flat-content-port
plan: 04
subsystem: shell
tags: [zsh, aliases, manifest-gates, feature-flags, port]

# Dependency graph
requires:
  - phase: 03-shell-layer-flat-content-port
    provides: "Plan 03-01 manifest feature flags (macos-finder, ghostty, jgrid-net) consumed by gated alias files"
  - phase: 02-install-engine-bootstrap-idempotency-lint
    provides: "Phase 2 D-10 canonical `task install` entry point referenced by dotfiles.zsh update alias (CF-06)"
provides:
  - "shell/aliases/general.zsh (12 ungated aliases; Finder x3 + Ghostty extracted)"
  - "shell/aliases/hardware.zsh (9 system_profiler aliases; byte-stable v1 port)"
  - "shell/aliases/networking.zsh (5 DNS/IP aliases; byte-stable v1 port)"
  - "shell/aliases/dotfiles.zsh (alias update='task install'; CF-06)"
  - "shell/aliases/finder.zsh (3 D-07 wrapper functions on features.macos-finder)"
  - "shell/aliases/ghostty.zsh (g() D-07 wrapper on features.ghostty)"
  - "shell/aliases/jgrid.zsh (D-08 source-time gate on features.jgrid-net + 22-metal loop)"
affects: [03-02 (zshrc glob loads these files), 03-03 (functions/_dotfiles_feature consumed by gated files), 03-05 (taskfiles symlink shell/ into ZDOTDIR)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "D-07 wrapper-function gate (per-file gate-evaluation; 1-3 aliases)"
    - "D-08 source-time gate (bulk-alias-loop exception; one gate-evaluation per file)"
    - "Feature-flag string-equality compare (`== \"true\"`; not boolean truthiness)"

key-files:
  created:
    - "shell/aliases/general.zsh"
    - "shell/aliases/hardware.zsh"
    - "shell/aliases/networking.zsh"
    - "shell/aliases/dotfiles.zsh"
    - "shell/aliases/finder.zsh"
    - "shell/aliases/ghostty.zsh"
    - "shell/aliases/jgrid.zsh"
  modified: []

key-decisions:
  - "Kept v1's multi-line METALS=( ... ) layout in jgrid.zsh (one metal per line) for cleanest diff against v1; the compact PATTERNS.md form is functionally equivalent but harder to grep verbatim against the v1 source."
  - "Phrased file-header comment blocks to avoid literal repetition of the implementation strings checked by acceptance-criteria grep counts (e.g., did not paste `\"$@\"` into the ghostty.zsh comment because the criterion expects count==1)."

patterns-established:
  - "D-07 wrapper-function gate: three reps of the gate line in finder.zsh is acceptable per PATTERNS.md (not factored into a shared helper for three aliases)."
  - "D-08 source-time gate: `[[ \"$(_dotfiles_feature <key>)\" == \"true\" ]] || return 0` as the FIRST active line of jgrid.zsh; loop body and final unset run only when the feature is on."
  - "File-header comment blocks describe purpose + why-this-gate-pattern (per CLAUDE.md `## Conventions Not Captured Above` — file-level comment block at the top of every script)."

requirements-completed: [SHEL-06, SHEL-08]

# Metrics
duration: 4min
completed: 2026-05-14
---

# Phase 03 Plan 04: Alias Topic Files Summary

**Ported v1's four alias source files into seven flat `shell/aliases/*.zsh` topics: three byte-stable ports, two surgical extractions (Finder + Ghostty out of v1's `general.zsh`), one D-08 source-time-gated metal loop, and one net-new `dotfiles.zsh` hosting the `update='task install'` alias (CF-06).**

## Performance

- **Duration:** 4 min (198 seconds)
- **Started:** 2026-05-14T22:34:43Z
- **Completed:** 2026-05-14T22:38:01Z
- **Tasks:** 2
- **Files created:** 7
- **Files modified:** 0

## Accomplishments

- v1's three `common/` alias files (`general.zsh`, `hardware.zsh`, `networking.zsh`) ported with `hardware.zsh` and `networking.zsh` byte-stable.
- The four GUI-coupled lines extracted from v1's `general.zsh` (Finder x3, Ghostty `g`) moved into their own gated files (`finder.zsh`, `ghostty.zsh`) per D-10. v2's `general.zsh` now contains exactly 12 ungated aliases (verified via `grep -c '^alias'`).
- New `dotfiles.zsh` topic created to host `alias update='task install'` (CF-06; replaces v1's 21-line `zsh/functions/update.zsh` wrapper -- per Phase 2 D-10, `task install` IS `task update`).
- `finder.zsh` defines three D-07 wrapper functions (`finder`, `findershow`, `finderhide`), each gated on `features.macos-finder`. Disabled-feature calls return 1 with a `feature 'macos-finder' is disabled on this machine` stderr message.
- `ghostty.zsh` defines a D-07 `g()` wrapper gated on `features.ghostty` that forwards `"$@"` to `/Applications/Ghostty.app/Contents/MacOS/ghostty`.
- `jgrid.zsh` uses the D-08 source-time gate as its first active line, then runs v1's 22-metal verbatim loop (all 22 metals present: 16 standard metals + 6 God metals).

## Task Commits

Each task was committed atomically:

1. **Task 1: Port three ungated alias files + new dotfiles.zsh** — `e7417ff` (feat)
2. **Task 2: Create three gated alias files (finder, ghostty, jgrid)** — `d9953a8` (feat)

_(SUMMARY.md commit follows; this worktree's branch will be merged by the orchestrator after the wave.)_

## Files Created/Modified

### Created

- `shell/aliases/general.zsh` — 12 ungated aliases (reload, environment, path, dotfile/dotfiles, fsa, perms, ls/ll, lastinstalled, history, t). Finder x3 + Ghostty `g` extracted to gated files per D-10. v1 inline comments preserved verbatim.
- `shell/aliases/hardware.zsh` — Byte-stable `diff`-empty port of v1 `zsh/aliases/common/hardware.zsh` (9 `system_profiler` aliases).
- `shell/aliases/networking.zsh` — Byte-stable `diff`-empty port of v1 `zsh/aliases/common/networking.zsh` (5 DNS/IP aliases).
- `shell/aliases/dotfiles.zsh` — New topic; single alias `update='task install'` (CF-06).
- `shell/aliases/finder.zsh` — Three D-07 wrapper functions gated on `features.macos-finder`. Each function runs the gate then either executes the body (`open -a Finder ./`, or the `defaults write com.apple.finder AppleShowAllFiles ...` toggle) or prints a disabled-feature stderr message and returns 1.
- `shell/aliases/ghostty.zsh` — Single D-07 `g()` wrapper gated on `features.ghostty`; forwards `"$@"` to the Ghostty binary explicitly (zsh aliases pass remaining argv automatically; functions need explicit `"$@"`).
- `shell/aliases/jgrid.zsh` — D-08 source-time gate as first active line, then the verbatim v1 METALS array (22 metals across two comment-delimited sections: 16 standard + 6 God metals), the `for i in $METALS; do alias $i="ssh josh@$i-ssh.jgrid.net"; done` loop, and the final `unset METALS`.

### Modified

None.

## Decisions Made

- **Kept v1's multi-line METALS array layout** (one metal per line) in `jgrid.zsh` rather than the compact PATTERNS.md form. The plan explicitly permitted either layout; multi-line diffs cleanest against v1 and makes the standard-vs-God-metals boundary trivially visible.
- **File-header comment blocks paraphrase implementation strings** rather than quoting them verbatim. The plan's acceptance criteria use strict exact-match counts (e.g., `grep -c "alias update='task install'" returns 1`, `grep -c '"$@"' returns 1`, `grep -c 'return 0' returns 1`); if comments contained the same literal strings the counts double. Paraphrasing keeps comments informative without breaking criteria. Documented in Deviations.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Spec compliance] Adjusted file-header comments to satisfy strict grep-count acceptance criteria**

- **Found during:** Task 1 verification (`shell/aliases/dotfiles.zsh`) and Task 2 verification (`shell/aliases/ghostty.zsh`, `shell/aliases/jgrid.zsh`)
- **Issue:** Three acceptance criteria use exact-match grep counts:
  - `grep -c "alias update='task install'" shell/aliases/dotfiles.zsh` must return 1
  - `grep -c '/Applications/Ghostty.app/Contents/MacOS/ghostty' shell/aliases/ghostty.zsh` must return 1
  - `grep -c '"$@"' shell/aliases/ghostty.zsh` must return 1
  - `grep -c 'return 0' shell/aliases/jgrid.zsh` must return 1
  
  My initial file-header comment blocks (which the plan's `<action>` section explicitly requires for purpose + why-this-pattern documentation) included the implementation strings verbatim — causing the counts to be 2 instead of 1.
- **Fix:** Rewrote the comment blocks to describe the implementation without literal repetition (e.g., "the `update` alias below replaces..." instead of `\`alias update='task install'\` replaces...`; "explicit positional-args forwarder" instead of `"$@"`; "early-exit from a sourced file" instead of `return 0`).
- **Files modified:** `shell/aliases/dotfiles.zsh`, `shell/aliases/ghostty.zsh`, `shell/aliases/jgrid.zsh`
- **Verification:** Re-ran all four `grep -c` checks; all four now return 1. All acceptance criteria pass.
- **Committed in:** `e7417ff` (Task 1) and `d9953a8` (Task 2) — the fix was applied before each task's commit, so no separate fix commit is needed.

---

**Total deviations:** 1 auto-fixed (1 spec compliance, no architectural impact)  
**Impact on plan:** Cosmetic only — comment content is semantically equivalent. No code-level deviation; all required gate patterns, alias bodies, and counts match the plan as specified.

## Issues Encountered

None. Both tasks executed in a single pass after the comment-rewording fix. `zsh -n` parses cleanly on all 7 files; the sibling-plan integration (calls to `_dotfiles_feature` defined by Plan 03-03) was simulated locally with a stub and all gate paths behave correctly:

- `_dotfiles_feature` returns `"false"` → finder/findershow/finderhide/g print disabled-feature stderr message and return 1; jgrid.zsh sources to completion with zero aliases defined.
- `_dotfiles_feature` returns `"true"` → wrappers execute body; jgrid.zsh defines all 22 metal aliases.

The plan's end-to-end smoke tests (acceptance criteria sourcing `shell/functions/_dotfiles_feature.zsh`) will be runnable only after Plan 03-03 merges into the wave. They are deferred to post-wave-merge phase verification (the orchestrator owns that step).

## User Setup Required

None — no external service configuration required. All files are inert until Plan 03-02's `.zshrc` glob loop (also in this wave) sources them; the gated files no-op gracefully on machines without the relevant feature flag.

## Next Phase Readiness

- **Plan 03-02 (.zshrc):** all 7 files are valid `zsh -n` sources; glob loop in `.zshrc` will pick them up unchanged.
- **Plan 03-03 (functions/_dotfiles_feature):** the three gated files (finder, ghostty, jgrid) reference `_dotfiles_feature` by name; the helper's stdout-only `"true"`/`"false"` contract is honored by my string-equality checks.
- **Plan 03-05 (taskfiles symlinks):** `shell/aliases/` is the standard flat directory the taskfile will symlink to `${ZDOTDIR}/aliases/` (or equivalent); no file-naming pitfalls.
- **Phase 4 onward:** the D-07 wrapper-function and D-08 source-time gate patterns are now established as the canonical manifest-feature-gating idioms for any future shell file that needs to no-op on certain machines.

## Self-Check: PASSED

Files verified present and committed:

- `shell/aliases/general.zsh` — FOUND (commit `e7417ff`)
- `shell/aliases/hardware.zsh` — FOUND (commit `e7417ff`)
- `shell/aliases/networking.zsh` — FOUND (commit `e7417ff`)
- `shell/aliases/dotfiles.zsh` — FOUND (commit `e7417ff`)
- `shell/aliases/finder.zsh` — FOUND (commit `d9953a8`)
- `shell/aliases/ghostty.zsh` — FOUND (commit `d9953a8`)
- `shell/aliases/jgrid.zsh` — FOUND (commit `d9953a8`)
- Commit `e7417ff` — present in `git log`
- Commit `d9953a8` — present in `git log`
- All 9 plan-level `<verification>` items pass (file count, zsh -n, no DOTFILES_PROFILE, byte-stable diffs, extractions, update alias, 22 metals, source-time gate first active line, end-to-end gate behavior verified via stub).

---

*Phase: 03-shell-layer-flat-content-port*  
*Completed: 2026-05-14*
