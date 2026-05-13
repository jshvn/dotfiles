---
phase: 01-manifest-engine-repository-skeleton
plan: "03"
subsystem: infra
tags: [go-task, manifest, toml, taskfile, fromJson, idempotency, mtime-status]

requires:
  - phase: 01-manifest-engine-repository-skeleton
    plan: "01"
    provides: "fixture corpus (6 positive + 2 negative) for manifest:test"
  - phase: 01-manifest-engine-repository-skeleton
    plan: "02"
    provides: "install/resolver.zsh -- the implementation surface invoked by all tasks"

provides:
  - "taskfiles/manifest.yml: go-task module with setup, manifest:resolve, manifest:show, manifest:validate, manifest:test, manifest:test:add-machine"
  - "fromJson ref: wiring enabling {{.MANIFEST.identity.git}} in downstream tasks (MFST-06)"
  - "BSD-find mtime status block for idempotent manifest:resolve (MFST-07)"
  - "Preconditions regex guard rejecting path-traversal on setup CLI_ARGS (T-MAN-02)"
  - "MFST-09 smoke test: one TOML + task setup proves new machine workflow end-to-end"

affects:
  - phase-02-root-taskfile-integration
  - any downstream taskfile using {{.MANIFEST.*}} variables

tech-stack:
  added: []
  patterns:
    - "go-task fromJson ref: for loading resolved.json as structured var (RESEARCH §6.1)"
    - "BSD-find -newer -print -quit mtime check in status blocks for idempotency (RESEARCH §7)"
    - "sed-based CLI_ARGS parsing (portable across gosh/sh/zsh -- avoids zsh-only match[])"
    - "Function-based EXIT trap (do_cleanup) for gosh-compatible cleanup in go-task"
    - "DOTFILES_MESSAGES inline-source pattern in every cmd block (S2)"

key-files:
  created:
    - "taskfiles/manifest.yml -- 400-line go-task module; six user-facing tasks + _: helpers include"
  modified: []

key-decisions:
  - "Used sed for --machine NAME extraction from CLI_ARGS instead of zsh match[]: go-task 3.x uses gosh as default shell executor; ${match[1]} is zsh-specific and silently fails in gosh"
  - "Used function-based EXIT trap (do_cleanup) in manifest:test:add-machine: inline trap with embedded quotes (the original implementation) fails to parse in gosh; named function avoids the quoting complexity"
  - "Used printf '%s\n' for throwaway TOML generation instead of heredoc: avoids indentation stripping issues when the heredoc is inside an indented YAML block"
  - "Status block uses two-line check (test -f AND negated find): go-task requires all status lines to return 0 for the task to be skipped; the find expression alone was insufficient"

patterns-established:
  - "Pattern: DOTFILEDIR detection via dirname(dirname(realpath(TASKFILE))) makes the module self-contained for task -t invocation"
  - "Pattern: XDG_STATE_HOME fallback via sh: echo ${XDG_STATE_HOME:-$HOME/.local/state} works in gosh without requiring zsh parameter expansion"
  - "Pattern: Negative fixture testing via cp-to-machines/validate/rm cycle avoids modifying resolver.zsh for ad-hoc validation"

requirements-completed: [MFST-06, MFST-07, MFST-09, MFST-05, MFST-08]

duration: 45min
completed: "2026-05-13"
---

# Phase 1 Plan 03: Manifest go-task Module Summary

**go-task module with six tasks wiring resolver.zsh against Plan 01 fixtures, fromJson ref: for downstream consumption, and BSD-find mtime idempotency**

## Performance

- **Duration:** ~45 min (including debugging gosh shell compatibility issues)
- **Started:** 2026-05-13T22:30:00Z
- **Completed:** 2026-05-13T23:15:00Z
- **Tasks:** 2 (Task 1: four production tasks; Task 2: two test tasks)
- **Files modified:** 1

## Accomplishments

- `taskfiles/manifest.yml` (400 lines) exposes the manifest engine to humans and downstream taskfiles via six discoverable go-task tasks
- All 8 fixture tests pass (6 positive deep-merge fixtures + 2 negative validation fixtures)
- `setup -- personal-laptop` writes machine state and produces resolved.json with `identity.git=personal` in a single command
- `manifest:resolve` is idempotent via BSD-find mtime check; second invocation reports "up to date"
- `setup -- ../etc/passwd` rejected at preconditions before any state write (T-MAN-02)
- `manifest:test:add-machine` proves MFST-09: new machine is one TOML file + `task setup`; cleanup trap restores prior state on both success and failure paths

## Task Commits

1. **Tasks 1+2: Build complete taskfiles/manifest.yml** - `5f2df9b` (feat)

## Files Created/Modified

- `taskfiles/manifest.yml` -- go-task module; six user-facing tasks (setup, manifest:resolve, manifest:show, manifest:validate, manifest:test, manifest:test:add-machine); includes ./helpers.yml; self-contained vars block for standalone `task -t` invocation; fromJson ref: wiring for MFST-06

## Decisions Made

- **sed over zsh match[]**: go-task 3.x uses `gosh` (Go Shell) as its default command executor, not `/bin/sh` or zsh. The `${match[1]}` array populated by zsh's `=~` operator is zsh-specific and silently returns empty in gosh. Replaced with `sed -n 's/.*--machine[[:space:]]\{1,\}\(...\).*/\1/p'` for portability.
- **Function-based EXIT trap**: The original implementation used `trap 'rm -f "'"$var"'" ...' EXIT` with embedded variable expansion. gosh's trap parser fails on this quoting pattern. Replaced with a named `do_cleanup()` function referenced by `trap do_cleanup EXIT`.
- **printf for TOML generation**: Heredoc inside an indented YAML block (`cat << 'TOML'`) strips leading whitespace unpredictably in some shells. `printf '%s\n' line1 line2 ...` is unambiguous.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed --machine NAME parsing in manifest:show and manifest:validate**
- **Found during:** Validation run (manifest:show -- --machine work-laptop returned personal-laptop data)
- **Issue:** Original implementation used `[[ "$cli_args" =~ pattern ]] && machine_name="${match[1]}"`. In gosh (go-task's shell), `${match[1]}` is always empty even when the regex matches. Machine name silently fell back to the state file value.
- **Fix:** Replaced `${match[1]}` extraction with `sed -n 's/.*--machine[[:space:]]\{1,\}\([a-z0-9_][a-z0-9_-]*\).*/\1/p'` in both tasks
- **Files modified:** `taskfiles/manifest.yml` (two locations: manifest:show, manifest:validate)
- **Verification:** `task -t taskfiles/manifest.yml manifest:show -- --machine work-laptop` now outputs `identity.git=work` while leaving the state file unchanged
- **Committed in:** `5f2df9b` (combined with full task commit)

**2. [Rule 1 - Bug] Fixed EXIT trap in manifest:test:add-machine**
- **Found during:** manifest:test:add-machine run; cleanup failed with `exittrap: not a valid test operator`
- **Issue:** Original trap used `trap '..complex quoting..' EXIT`. gosh fails to parse embedded single-quote patterns in trap strings.
- **Fix:** Extracted cleanup into `do_cleanup()` shell function; `trap do_cleanup EXIT` uses a simple function name with no quoting complexity
- **Files modified:** `taskfiles/manifest.yml` (manifest:test:add-machine task)
- **Verification:** After fix, throwaway TOML is cleaned up and prior machine state is restored on both success and failure paths
- **Committed in:** `5f2df9b`

**3. [Rule 1 - Bug] Fixed TOML generation using printf instead of heredoc**
- **Found during:** Investigation of manifest:test:add-machine throwaway TOML
- **Issue:** `cat > file << 'TOML' ... TOML` inside an indented YAML block carries indentation into the output file, which could confuse TOML parsers
- **Fix:** Replaced heredoc with `printf '%s\n' line1 line2 ...` which produces unindented output regardless of context indentation
- **Files modified:** `taskfiles/manifest.yml` (manifest:test:add-machine task)
- **Committed in:** `5f2df9b`

---

**Total deviations:** 3 auto-fixed (all Rule 1 - Bug)
**Impact on plan:** All fixes were correctness bugs in the salvaged file's gosh-incompatible patterns. No scope creep. All plan acceptance criteria satisfied after fixes.

## Issues Encountered

- The salvaged taskfile (from the killed prior executor) had three gosh-incompatible patterns: zsh match[], complex trap quoting, and heredoc indentation. All were diagnosed and fixed during the validation run required by the recovery objective.
- go-task uses `gosh` (a Go-native shell implementation) as its default command executor. This shell supports `[[`, `set -e`, and most POSIX constructs, but NOT zsh-specific features like `${match[1]}` (regex capture groups), the `(N)` glob qualifier, or complex trap string quoting. Any future taskfile code must be written for gosh compatibility or must explicitly invoke `zsh -c '...'`.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `taskfiles/manifest.yml` is complete and passes all Phase 1 acceptance criteria
- Phase 2 integration requires one line in the root `Taskfile.yml` includes block: `manifest: ./taskfiles/manifest.yml`
- The `{{.MANIFEST.identity.git}}` and `{{index .MANIFEST.features "one-password-ssh"}}` patterns are verified and ready for downstream consumption (MFST-06)
- Known limitation: the `manifest:test` negative fixture tests use a temp-copy approach (cp fixture into manifests/machines/, validate, rm). This is intentional for Plan 03 -- Plan 02's resolver is used as-is without modification.

---
*Phase: 01-manifest-engine-repository-skeleton*
*Completed: 2026-05-13*
