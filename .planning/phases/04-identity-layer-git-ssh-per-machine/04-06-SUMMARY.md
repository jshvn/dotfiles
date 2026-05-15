---
phase: 04-identity-layer-git-ssh-per-machine
plan: "06"
subsystem: infra
tags: [go-task, manifest, taskfile, include-vars, template-evaluation]

requires:
  - phase: 04-identity-layer-git-ssh-per-machine
    plan: "05"
    provides: "manifest namespace fix (manifest: prefix) that this plan builds on"

provides:
  - "One-hop RESOLVED_JSON_PATH in taskfiles/manifest.yml that substitutes correctly under include-vars evaluation"
  - "Closure of UAT gap 2: no spurious bare-slash warning when resolved.json exists"

affects:
  - 04-identity-layer-git-ssh-per-machine
  - any plan that includes or extends taskfiles/manifest.yml

tech-stack:
  added: []
  patterns:
    - "One-hop template var for paths sourced from parent-forwarded XDG vars: '{{.XDG_STATE_HOME}}/dotfiles/<file>' not '{{.STATE_DIR}}/<file>'"

key-files:
  created: []
  modified:
    - taskfiles/manifest.yml

key-decisions:
  - "Fix only RESOLVED_JSON_PATH (gap-2 truth); leave STATE_FILE (line 52) on the two-hop chain as it degrades silently and is benign -- follow-up recorded but out of scope"
  - "STATE_DIR retained in vars: block because cmds: blocks (mkdir -p at lines 135, 158, 540) evaluate templates at a later lifecycle stage where two-hop chains resolve correctly"

patterns-established:
  - "One-hop pattern: any var consumed in a vars: sh: block must reference parent-forwarded XDG vars directly, not locally-derived intermediates, because include-vars evaluation resolves parent vars but not local intermediates"

requirements-completed: [IDNT-08]

duration: 8min
completed: 2026-05-15
---

# Phase 04 Plan 06: Manifest RESOLVED_JSON_PATH One-Hop Fix Summary

**Single-line change to taskfiles/manifest.yml eliminates spurious bare-slash warning by replacing two-hop STATE_DIR chain with direct XDG_STATE_HOME one-hop template, closing UAT gap 2**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-05-15T15:13:00Z
- **Completed:** 2026-05-15T15:21:37Z
- **Tasks:** 2 (1 edit + 1 verification)
- **Files modified:** 1

## Accomplishments

- Replaced two-hop `{{.STATE_DIR}}/resolved.json` with one-hop `{{.XDG_STATE_HOME}}/dotfiles/resolved.json` in the manifest.yml vars block
- `task identity:git --force`, `task identity:ssh --force`, and `task manifest:resolve` no longer emit `warning: /resolved.json missing or empty` when resolved.json exists
- STATE_DIR (line 51) remains defined -- cmds: callers at lines 135, 158, 540 continue to work correctly because cmds: template substitution runs at a later lifecycle stage than vars: sh: evaluation

## Task Commits

Each task was committed atomically:

1. **Task 1: Replace two-hop RESOLVED_JSON_PATH with one-hop template** - `36925a0` (fix)
2. **Task 2: Verify bare-slash warning eliminated** - verification only, no file edits, no separate commit

**Plan metadata:** (this SUMMARY commit)

## Files Created/Modified

- `taskfiles/manifest.yml` - Line 53 changed from `'{{.STATE_DIR}}/resolved.json'` to `'{{.XDG_STATE_HOME}}/dotfiles/resolved.json'`

## Decisions Made

- Fix only RESOLVED_JSON_PATH: the documented gap-2 truth is specifically about this variable. STATE_FILE (line 52) shares the same two-hop shape but its sh: consumer (MACHINE at line 69) degrades silently when STATE_FILE collapses to `/machine` -- head fails and MACHINE becomes empty, which downstream code handles explicitly. Fixing STATE_FILE is a consistency improvement but not a documented gap; recorded as a follow-up consideration.
- STATE_DIR retained: three cmds: callers depend on it at lines 135, 158, 540. The include-vars evaluation issue only affects vars: sh: blocks; cmd-time template substitution runs after all vars are populated, so STATE_DIR resolves correctly there.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## Known Stubs

None -- the fix is complete. No placeholder paths or fallback stubs remain in the resolved path.

## STATE_FILE Follow-up (out of scope)

STATE_FILE at line 52 also uses the two-hop pattern `{{.STATE_DIR}}/machine`. Its sh: consumer (MACHINE, line 69) collapses to `/machine` during include-vars evaluation, causing head to fail silently and MACHINE to become empty. This is benign because downstream code already handles empty MACHINE via the AVAILABLE_MACHINES error path. A future gap-closure plan could apply the same one-hop fix (`'{{.XDG_STATE_HOME}}/dotfiles/machine'`) for consistency, but it is explicitly not part of the gap-2 truth documented in this plan.

## Next Phase Readiness

- UAT gap 2 is closed. Combined with the 04-05 manifest namespace fix, identity tasks no longer emit spurious stderr warnings during normal converged operation.
- 04-07 (remaining UAT gaps if any) can proceed without the bare-slash noise masking real errors.

---
*Phase: 04-identity-layer-git-ssh-per-machine*
*Completed: 2026-05-15*
