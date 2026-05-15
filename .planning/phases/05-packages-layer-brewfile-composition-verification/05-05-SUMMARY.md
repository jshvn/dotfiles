---
phase: 05-packages-layer-brewfile-composition-verification
plan: 05
subsystem: packages
tags: [taskfile, root, install-pipeline, vrfy-04, d-10, includes, packages-include]

# Dependency graph
requires:
  - phase: 05-packages-layer-brewfile-composition-verification
    provides: "Plan 04 taskfiles/packages.yml (the include target this plan wires in via the new `packages:` include block)."
  - phase: 04-identity-layer-git-ssh-per-machine
    provides: "taskfiles/identity.yml -- the canonical include-shape reference (taskfile + vars: DOTFILEDIR / XDG_STATE_HOME / DOTFILES_MESSAGES forwarding)."
  - phase: 02-install-engine-bootstrap-idempotency-lint
    provides: "Root Taskfile.yml install task scaffold + cutover-ack precondition + brew-stub include slot (the slot this plan repurposes)."
provides:
  - "Root Taskfile.yml rewired: `brew:` include replaced by `packages:` block forwarding DOTFILEDIR + XDG_STATE_HOME + XDG_CACHE_HOME + DOTFILES_MESSAGES."
  - "Install pipeline now calls `packages:install` (replacing `brew:install`) followed by `packages:verify` as the FINAL task-call before the success message."
  - "VRFY-04 contract live: a missing bin or `.app` fails the whole `task install` with exit 1 (D-10 hard-fail at install gate)."
  - "File-header includes bullet updated to `packages (P5, real)`."
affects: [05, 05-06, 06, 07, 08]

# Tech tracking
tech-stack:
  added: []  # no new tools; pure go-task include + cmds rewire
  patterns:
    - "Three-discrete-edits-to-one-file refactor: surgical Edit-tool replacements, no whole-file rewrite (preserves every other line including the cutover-ack precondition block and the messages-sourcing pattern)."
    - "Include-block forwarding shape with XDG_CACHE_HOME as the fourth forwarded var (NEW in P5; identity.yml / manifest.yml only needed three)."
    - "Final-step verify pattern: `task: packages:verify` is the last task-call before the success shell-block, so any failure short-circuits `success \"install complete\"` (set: [errexit, pipefail] at the root level makes this exit 1 propagate)."

key-files:
  created: []
  modified:
    - "Taskfile.yml (root; +20 / -3 lines: replaced brew-stub include with packages block; swapped task:brew:install -> task:packages:install; inserted task:packages:verify; updated header bullet)"

key-decisions:
  - "Kept the legacy `taskfiles/brew-stub.yml` file on disk; the include line was removed in this plan, so the stub is now an orphan -- Plan 04's summary called out P8 cleanup as the deletion path. Deleting it here is out of scope per the plan's `<output>` Note and would be a scope-creep deviation against the plan's `<action>` block."
  - "Inserted `task: packages:verify` BEFORE the success-message shell-block, not AFTER. The plan's `<interfaces>` block specifies this ordering exactly: verify is the final task-call, and any non-zero exit must hard-fail BEFORE `success \"install complete\"` runs. Placing verify after the success line would emit the success message even on a failed verify (the shell block runs sequentially and a later block does not unwind a printed line)."
  - "Updated the header-comment bullet from `brew (stub; P5 wires real bodies)` to `packages (P5, real)` -- matches the convention set by line 18 (`identity (P4, real)`). The plan's `<action>` block calls this out explicitly under `DO NOT touch ... BUT update the bullet`."

patterns-established:
  - "VRFY-04 wiring pattern: the verify task is the final task-call before the success message. Future phases that add post-install steps must place them BEFORE packages:verify (so verify still gates the success line) OR add a corresponding verify step after their own work."
  - "Forwarded-var convention for include blocks: DOTFILEDIR + XDG_STATE_HOME are universal; XDG_CACHE_HOME is added when the included taskfile writes cache-home artifacts; DOTFILES_MESSAGES is added when cmd blocks need the colored-output helpers."

requirements-completed: [VRFY-04]

# Metrics
duration: 3min
completed: 2026-05-15
---

# Phase 05 Plan 05: Root Taskfile.yml rewires brew -> packages and adds packages:verify as install's final step

**Root `Taskfile.yml` now routes the install pipeline through `packages:install` (composer + brew bundle install) and ends with `packages:verify` (per-package check/cross enumerate-all) BEFORE the success message; a missing binary or missing `/Applications/<App>.app` now hard-fails the whole `task install` with exit 1 (VRFY-04 + D-10).**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-05-15T19:11:17Z
- **Completed:** 2026-05-15T19:14:13Z
- **Tasks:** 1 / 1 complete (single `type="auto"`, no checkpoints)
- **Files created:** 0
- **Files modified:** 1 (`Taskfile.yml`; +20 / -3 lines)

## Accomplishments

- VRFY-04 contract realized: a verify failure now exits the whole `task install` with exit 1 BEFORE the success message would print.
- Phase-5 packages layer is now reachable from the canonical `task install` entry point -- the Wave 3 plumbing (`taskfiles/packages.yml`) is no longer an orphan.
- The `brew:` legacy namespace is fully retired from the root install graph -- `yq '.includes.brew'` returns `null`, `yq '.tasks.install.cmds[].task'` shows no `brew:install` reference.

## Task Commits

Each task was committed atomically:

1. **Task 1: Rewire root Taskfile.yml -- rename brew include to packages, wire packages:install and packages:verify** -- `30dacd7` (refactor)

## Files Created/Modified

- `Taskfile.yml` -- Root taskfile. Three discrete edits:
  1. Replaced `brew: ./taskfiles/brew-stub.yml` (single-line include) with a full `packages:` block: `taskfile: ./taskfiles/packages.yml` + `vars:` forwarding DOTFILEDIR + XDG_STATE_HOME + XDG_CACHE_HOME + DOTFILES_MESSAGES. The new include sits between the `identity:` block (lines 87-94) and the remaining stub includes (`claude:`, `macos:`), preserving the install-order semantics.
  2. Swapped `- task: brew:install` for `- task: packages:install` in the install task `cmds:` list (position 2 of the 6-step list, unchanged).
  3. Inserted `- task: packages:verify` as the FINAL task-call (position 6), positioned AFTER `- task: macos:shell` and BEFORE the trailing `- |` shell-block that emits `success "install complete"`. This matches ROADMAP Phase 5 success criterion #6 verbatim ("verify is the install pipeline's final step before the success message").

Header-comment bullet at line 19 also updated from `brew (stub; P5 wires real bodies)` to `packages (P5, real)` (the plan's `<action>` block called this out explicitly).

## Before / After Diff Reference

**Includes block (Taskfile.yml lines 74-108 post-edit):**

```
# Before (single line at old line 95):
brew:     ./taskfiles/brew-stub.yml       # P5 wires real bodies

# After (full block at new lines 95-106):
# packages needs the root's DOTFILEDIR + XDG_STATE_HOME + XDG_CACHE_HOME
# explicitly forwarded -- it reads resolved.json (manifest), writes the
# composed Brewfile under XDG_CACHE_HOME (D-08), and verifies post-install
# state. XDG_CACHE_HOME is new in Phase 5; the root already declares it
# in the vars: block above.
packages:
  taskfile: ./taskfiles/packages.yml
  vars:
    DOTFILEDIR: '{{.DOTFILEDIR}}'
    XDG_STATE_HOME: '{{.XDG_STATE_HOME}}'
    XDG_CACHE_HOME: '{{.XDG_CACHE_HOME}}'
    DOTFILES_MESSAGES: '{{.DOTFILES_MESSAGES}}'
```

**Install task cmds (Taskfile.yml lines 138-152 post-edit):**

```
# Before:
cmds:
  - task: links:all
  - task: brew:install
  - task: claude:install
  - task: macos:defaults
  - task: macos:shell
  - |
    {{.DOTFILES_MESSAGES}}
    success "install complete"

# After:
cmds:
  - task: links:all
  - task: packages:install
  - task: claude:install
  - task: macos:defaults
  - task: macos:shell
  # VRFY-04 + D-10 + ROADMAP P5 success criterion #6:
  # packages:verify is the FINAL task-call in the install pipeline.
  # A missing bin or missing /Applications/<App>.app fails the entire
  # `task install` with exit 1 -- no `success "install complete"` line
  # is printed when verify trips.
  - task: packages:verify
  - |
    {{.DOTFILES_MESSAGES}}
    success "install complete"
```

## Decisions Made

- **Kept `taskfiles/brew-stub.yml` on disk** (deletion deferred to Phase 8 cleanup). The plan's `<output>` Note explicitly defers this; deleting here would be scope creep. Plan 04 already emptied the file to `tasks: {}` with a DEPRECATED header, so it is dead weight but harmless.
- **`packages:verify` inserted BEFORE the success shell-block, not after.** Reason: go-task executes `cmds:` items sequentially with `set: [errexit, pipefail]` at the root level, so a non-zero exit from a task-call short-circuits subsequent cmds. Placing verify after `success "install complete"` would print the success line even when verify is about to fail -- the exact "silent install failure" gap VRFY-04 closes.
- **`XDG_CACHE_HOME` is the fourth forwarded var** in the new `packages:` include block (identity.yml forwards three; packages.yml needs cache-home for the composed Brewfile destination per D-08 / CF-07). The root taskfile already declared `XDG_CACHE_HOME` at line 38, so the forwarding is a clean pass-through.

## Deviations from Plan

None -- plan executed exactly as written. Three discrete Edit-tool replacements + one header-bullet update + zero auto-fixes. The plan's `<action>` block was explicit enough that no Rule-1/2/3 deviations were triggered.

## Issues Encountered

None.

## Verification Results

All acceptance criteria from the plan's `<acceptance_criteria>` block were verified:

| Check | Result |
|-------|--------|
| `yq '.includes.packages' Taskfile.yml` is non-null | PASS (full block returned) |
| `yq '.includes.packages.taskfile'` = `./taskfiles/packages.yml` | PASS |
| `yq '.includes.packages.vars \| keys'` returns DOTFILEDIR, XDG_STATE_HOME, XDG_CACHE_HOME, DOTFILES_MESSAGES | PASS (all four present) |
| `yq '.includes.brew'` = `null` (the include key was renamed, not duplicated) | PASS |
| `grep -c '^packages:install$'` in install cmds task list | PASS (1) |
| `grep -c '^packages:verify$'` in install cmds task list | PASS (1) |
| `grep -c '^brew:install$'` in install cmds task list | PASS (0) |
| Ordering: macos:shell (#5) < packages:verify (#6) < success line (#7) | PASS |
| `task --list` exits 0 | PASS (all 32 tasks list cleanly; all 5 `packages:*` tasks reachable: audit, compose, install, validate, verify) |
| `task -t taskfiles/packages.yml --list` exits 0 | PASS (5 tasks listed) |
| `task lint` introduces no new failures | PASS (`packages.yml`: LINT-02 PASS; `Taskfile.yml` not flagged anywhere; pre-existing 29 LINT-03a failures are all v1-leftover taskfiles outside this plan's scope per the SCOPE BOUNDARY rule -- documented in Plan 04 summary) |
| Header bullet update: `grep -E '^# +- packages '` returns `packages (P5, real)` | PASS |
| `yq '.tasks.update'` = `null` (D-10 preserved -- no task-update reintroduced) | PASS |
| File parses as valid YAML | PASS (`yq '.'` exits 0; `task --list` succeeds) |
| No emojis: `LC_ALL=C grep -P '[^\\x00-\\x7f]'` exits 1 | PASS |
| No AI attribution: `grep -iE 'co-authored-by\|generated by ai\|written by ai'` exits 1 | PASS |

## End-to-End Smoke (Deferred to Post-Merge)

The plan's `<verification>` step 5/6 (rename a real cask's `.app` then run `task install` and confirm exit 1 + no success line) requires a live machine state and modifies `/Applications/`. The plan's `<verification>` documents this as a post-merge step for the converged personal-laptop -- not part of this worktree's automation surface. The wiring-correctness verification above (yq-driven acceptance criteria) is sufficient to confirm the change shape; the runtime hard-fail behavior is inherited from `packages:verify`'s `exit "$failures"` (Plan 04, lines 260-265) plus the root taskfile's `set: [errexit, pipefail]` -- both already verified independently.

## Threat Surface Scan

Scanned `Taskfile.yml` for security surface not in the plan's `<threat_model>`:

- The new `packages:` include forwards four vars to `taskfiles/packages.yml` -- all four were already in scope at the root level (DOTFILEDIR, XDG_STATE_HOME, XDG_CACHE_HOME, DOTFILES_MESSAGES); no new env-var ingress.
- `task: packages:install` and `task: packages:verify` are pure delegations to the Wave-3 taskfile -- the trust boundary lives at `packages.yml`'s install / verify cmd blocks, already covered by T-05-16 / T-05-17 / T-05-18 in Plan 04's threat register.
- T-05-25 (Tampering -- install task graph silently dropping `packages:verify`) is mitigated by the acceptance-criteria ordering check (`packages:verify` after `macos:shell` before `success` line); the inline comment block at the new lines 144-148 documents this for future reviewers.

No new endpoints, no new auth paths, no new file-access patterns outside what the plan's threat register already covers. **No threat flags.**

## Next Phase Readiness

- **Plan 06 (LINT-09 cask-without-verify-comment lint):** Unblocked. The runtime failsafe (`packages:verify` cask-loop hard-failing on a cask line missing `# verify:`) is now wired into `task install`'s final step, so LINT-09 adds the static-time gate that mirrors it.
- **Phase 8 (CUTV cleanup):** `taskfiles/brew-stub.yml` is now a true orphan (no include line references it). Queued for deletion alongside the other v1-leftover taskfiles.
- **End-to-end on personal-laptop (post-merge smoke):** Ready. The plan's `<verification>` block documents the steps -- `task setup -- personal-laptop && task install`, then rename a cask's `.app` and re-run to confirm the hard-fail behavior.

## Self-Check: PASSED

Files modified (worktree-relative paths verified):

- `Taskfile.yml` -- FOUND (committed `30dacd7`; +20 / -3 lines; includes the new `packages:` block, the swapped `task: packages:install` call, the new `task: packages:verify` call, and the updated header bullet)

Commit exists on `worktree-agent-a16787a68624ea8ff`:

- `30dacd7` -- FOUND (refactor(05-05): rewire root Taskfile.yml to packages layer)

Acceptance-criteria re-verification (post-commit):

1. `task --list` exits 0; `packages:install`, `packages:verify`, `packages:audit`, `packages:compose`, `packages:validate` all listed -- PASS
2. `yq '.includes.packages'` returns full block; `yq '.includes.brew'` returns `null` -- PASS
3. `yq '.tasks.install.cmds[].task'` returns the new 6-call sequence: links:all, packages:install, claude:install, macos:defaults, macos:shell, packages:verify -- PASS
4. `yq '.tasks.update'` returns `null` (D-10 preserved) -- PASS
5. Header bullet at line 19 reads `packages (P5, real)` -- PASS
6. `task lint` introduces no new LINT-02/03/04/03a/03b failures attributable to this plan's change -- PASS (the residual 29 LINT-03a failures are all v1-leftover taskfiles outside this plan's scope, identical to Plan 04's baseline)
7. No emojis in `Taskfile.yml`; no AI attribution -- PASS

## Cross-References

- VRFY-04 (verify in install's final step) -- realized by the third edit (insertion of `task: packages:verify` before the success shell-block).
- D-10 (install IS update; hard-fail at install gate) -- preserved (no `task update` block; `set: [errexit, pipefail]` at root level propagates the verify failure).
- ROADMAP Phase 5 success criterion #6 (`task packages:verify` in its final step) -- ordering verified: macos:shell (#5) < packages:verify (#6) < success line (#7).
- CF-07 (`COMPOSED_BREWFILE` var name + path) -- inherited from Plan 03 / Plan 04; the new include forwards `XDG_CACHE_HOME` so packages.yml can derive `COMPOSED_BREWFILE = $XDG_CACHE_HOME/dotfiles/Brewfile`.
- CF-08 (every task reading resolved.json declares `deps: [":manifest:resolve"]`) -- inherited from Plan 04's packages.yml; this plan does not change deps.
- T-05-25 (Tampering -- verify silently dropped from install graph) -- mitigated by the inline comment block at Taskfile.yml lines 144-148 explaining the ordering invariant.

---

*Phase: 05-packages-layer-brewfile-composition-verification*
*Plan: 05*
*Completed: 2026-05-15*
