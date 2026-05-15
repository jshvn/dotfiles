---
phase: 04-identity-layer-git-ssh-per-machine
plan: 05
subsystem: infra
tags: [go-task, manifest, taskfiles, namespace, yaml]

requires:
  - phase: 04-identity-layer-git-ssh-per-machine
    provides: taskfiles/manifest.yml, taskfiles/identity.yml, Taskfile.yml with identity layer

provides:
  - "Correct single-prefixed manifest task names (manifest:resolve, manifest:show, manifest:validate, manifest:test, manifest:test:add-machine)"
  - "Fixed cross-namespace dep in identity.yml using leading-colon absolute form [:manifest:resolve]"
  - "Clean task --list output with no manifest:manifest:* double-prefixed entries"
  - "Unblocked task identity:install end-to-end pipeline"

affects: [04-06, 04-07, any plan that calls identity:install or manifest:* tasks]

tech-stack:
  added: []
  patterns:
    - "go-task intra-file task: refs use bare key names (no include alias prefix)"
    - "Cross-namespace deps from included taskfiles use leading-colon [:namespace:task] absolute form"
    - "Root Taskfile.yml deps use unqualified namespace:task without leading colon"

key-files:
  created: []
  modified:
    - taskfiles/manifest.yml
    - Taskfile.yml
    - taskfiles/identity.yml

key-decisions:
  - "Quote [:manifest:resolve] as a YAML string in the deps array to avoid YAML flow-sequence parse error (bare colon-prefixed values are invalid YAML)"
  - "Single atomic commit for all three file changes to avoid intermediate broken state where keys are renamed but identity.yml still references old names"

patterns-established:
  - "go-task intra-file cmds task: refs must be bare key names, not namespace-qualified names"
  - "Leading-colon absolute form is required for cross-namespace deps inside an included taskfile; it must be quoted as a YAML string"

requirements-completed: [IDNT-07, IDNT-08]

duration: 15min
completed: 2026-05-15
---

# Phase 4 Plan 5: Manifest Namespace Double-Prefix Fix Summary

**Fixed go-task namespace double-prefix bug that produced manifest:manifest:* task names and broke identity:install deps resolution — all five canonical manifest tasks now run correctly**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-05-15
- **Completed:** 2026-05-15
- **Tasks:** 5 (bundled into 1 atomic commit per plan output spec)
- **Files modified:** 3

## Accomplishments
- Renamed 5 public task keys in taskfiles/manifest.yml from `manifest:foo` to bare `foo`; updated 2 intra-file `task:` refs from `manifest:validate`/`manifest:resolve` to bare `validate`/`resolve`
- Removed 3-line deferred-fix comment block from Taskfile.yml; changed deps from `manifest:manifest:resolve` to `manifest:resolve`
- Fixed taskfiles/identity.yml install task deps from `manifest:manifest:resolve` to `":manifest:resolve"` (leading-colon absolute form, quoted for YAML validity)
- `task --list` now shows exactly 6 manifest: entries with no double-prefixed names
- `task identity:install` exits 0 end-to-end (UAT gap 3 closed)

## Task Commits

All five task edits bundled into one atomic commit per plan output spec:

1. **Tasks 1-5: All manifest namespace fixes** - `d94168e` (fix)

**Plan metadata:** (SUMMARY commit)

## Files Created/Modified
- `taskfiles/manifest.yml` - Renamed 5 public keys and 2 intra-file refs to bare names
- `Taskfile.yml` - Fixed deps to `manifest:resolve`; removed deferred-fix comment block
- `taskfiles/identity.yml` - Fixed install deps to `":manifest:resolve"` absolute form; updated header comment

## Decisions Made
- Quote `":manifest:resolve"` as a YAML string: bare `[:manifest:resolve]` in a YAML flow sequence triggers a parse error ("did not find expected node content") because a leading colon is not valid YAML there. Quoting is required. This is not a go-task limitation — it is standard YAML.
- Single atomic commit: the plan's output section explicitly requires all five edits in one commit to avoid the intermediate broken state where manifest keys are renamed but identity.yml still points at the old double-prefixed names.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Quoted [:manifest:resolve] to fix YAML parse error**
- **Found during:** Task 3 verification (task --list failed with "did not find expected node content" at identity.yml line 110)
- **Issue:** `deps: [:manifest:resolve]` — the bare leading-colon value inside a YAML flow sequence is a YAML parse error. The plan's written form was syntactically invalid YAML.
- **Fix:** Changed to `deps: [":manifest:resolve"]` — the quoted string is valid YAML and go-task interprets the leading colon as the absolute-reference marker.
- **Files modified:** taskfiles/identity.yml
- **Verification:** `task --list` parses successfully; `task identity:install` exits 0.
- **Committed in:** d94168e (bundled in the single atomic commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - Bug: YAML syntax error in written plan form)
**Impact on plan:** Required fix for correctness. The leading-colon absolute-reference form is correct go-task semantics; the quoting is correct YAML syntax. No scope creep.

## Issues Encountered
- YAML flow-sequence parse error when `[:manifest:resolve]` was written without quotes. The leading colon is a valid go-task absolute-reference marker but requires quoting to be valid YAML in a flow sequence. Fixed inline as deviation Rule 1.

## Next Phase Readiness
- UAT gaps 1 and 3 are closed: `task manifest:resolve`, `task manifest:show`, `task manifest:validate`, `task manifest:test`, `task manifest:test:add-machine`, and `task identity:install` all exit 0 under their canonical names.
- `task install` deps reference resolves correctly (cutover-ack gate fires as expected on non-converged machine — not a task-not-found error).
- Plans 04-06 and 04-07 (wave 2) can now proceed — the IDNT-07 BLOCKING gate is unblocked.

---
*Phase: 04-identity-layer-git-ssh-per-machine*
*Completed: 2026-05-15*
