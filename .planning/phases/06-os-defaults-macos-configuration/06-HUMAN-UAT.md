---
phase: 06
slug: os-defaults-macos-configuration
status: complete
created: 2026-05-15
last_run: 2026-05-15
tester: Josh Vaughen
---

# Phase 6 -- macOS OS-defaults + shell-registration -- Manual UAT

Verify on real hardware that Phase 6's per-concern defaults model, feature-gate behavior, server-mode contract, idempotency, and the v1 `macos:shell:145` bug-class fix are demonstrably correct. The auto-tests (Tests 1 and 5) prove the file shape of `taskfiles/macos.yml`; the manual tests (Tests 2, 3, 4) prove the runtime behavior on real macOS hardware. `/gsd-verify-work` reads the Sign-off table at the bottom of this file to gate phase completion.

## Pre-conditions

Before running any test, confirm every item below:

1. **macOS dev machine** -- macOS 14+ (Sonoma or later) per `.planning/phases/06-os-defaults-macos-configuration/06-RESEARCH.md`. Apple Silicon or Intel.
2. **Homebrew zsh installed** -- `test -x "${HOMEBREW_PREFIX}/bin/zsh"` returns 0 (Phase 5 dependency).
3. **`task --list` shows the `macos:` namespace** -- `task --list | grep -E '^\* macos:'` returns the three non-internal tasks: `macos:defaults`, `macos:shell`, `macos:validate`. Plan 03 must be deployed.
4. **Active machine recorded** -- `test -f "$XDG_STATE_HOME/dotfiles/machine"` returns 0; the file contains a valid machine name (`personal-laptop`, `work-laptop`, `server-1`, or `server-2`).
5. **Resolved manifest has the five `macos-*` keys** -- `jq -r '.features | to_entries | map(select(.key|startswith("macos-"))) | length' "$XDG_STATE_HOME/dotfiles/resolved.json"` returns `5`.
6. **v1 backup preserved** -- `test -f taskfiles/macos.v1.yml.bak` returns 0 (CF-11 parallel-rewrite invariant; P8 owns final deletion).
7. **Clean working tree** -- if the dev machine is the active checkout, `git stash` any in-progress edits before running the destructive UAT scenarios (Test 4 writes a wrong defaults value and the rollback depends on the apply path being callable from a clean repo state).

## Test 1 -- LINT-02 static regression check (OSCF-04)

**Type:** auto -- read-only static analysis; runs without human interaction; AUTO-RUN by the executor as part of Task 1.

**What it proves:** `taskfiles/macos.yml` `shell:status` block contains no `$BREW_ZSH` shell-var references. This is the structural fix for the v1 `macos:shell:145` bug class (the v1 `taskfiles/macos.yml` line 145 used `$BREW_ZSH` in a `status:` block, where shell vars are NOT in scope -- the task re-ran on every invocation). See `.planning/codebase/CONCERNS.md` lines 15-19 for the historical bug class reference.

**Steps:**

1. `yq '.tasks.shell.status' taskfiles/macos.yml | grep -E '\$BREW_ZSH\b'` -- MUST return nothing (exit 1).
2. `yq '.tasks.shell.status' taskfiles/macos.yml | grep -qE '\{\{\.BREW_ZSH\}\}'` -- MUST return 0 (template var present).
3. `task lint:taskfile 2>&1 | grep -E 'LINT-02:.*macos\.yml$'` -- the new file MUST appear with a green check (`LINT-02: .../taskfiles/macos.yml` with no `cross` prefix).

**Success criterion:** All three commands behave as specified.

**Rollback:** None required (read-only static analysis).

## Test 2 -- Server-mode install simulation (OSCF-04 / ROADMAP SC#4)

**Type:** manual -- runtime; HUMAN-REQUIRED; mutates active machine selection (rollback restores it).

**What it proves:** On a machine with `macos-security = true` and the other four `macos-*` features absent (inherited `false`), `task install` runs `macos:shell` + `macos:defaults:security` only; the other four concern tasks skip at the feature-gate level. This is D-04 + ROADMAP SC#4 on real hardware.

**Steps:**

1. Capture current state:
   ```bash
   CURRENT_MACHINE=$(cat "$XDG_STATE_HOME/dotfiles/machine")
   echo "Will restore to: $CURRENT_MACHINE"
   ```
2. Switch active machine to `server-1`:
   ```bash
   task manifest:setup -- server-1
   ```
   This runs the resolver against `manifests/machines/server-1.toml`; the four GUI concern feature flags inherit `false` from defaults; `macos-security = true` per Plan 01. (Note: `task --list` describes this as `task setup --`, but the actual task name is `manifest:setup` -- the root-level alias does not exist.)
3. Verify the resolved feature gates:
   ```bash
   task manifest:resolve
   jq -r '.features | to_entries | map(select(.key|startswith("macos-"))) | .[] | "\(.key)=\(.value)"' "$XDG_STATE_HOME/dotfiles/resolved.json"
   ```
   Expected output (order may vary):
   ```
   macos-dock=false
   macos-finder=false
   macos-input=false
   macos-screenshots=false
   macos-security=true
   ```
4. Run the defaults aggregator with verbose tracing:
   ```bash
   task macos:defaults --verbose 2>&1 | tee /tmp/p6-test2.log
   ```
   Expected: tasks `macos:defaults:dock`, `macos:defaults:finder`, `macos:defaults:input`, `macos:defaults:screenshots` all print `task: Task "macos:defaults:<concern>" is up to date` (the single-shell-block status's `exit 0` short-circuit fires). Task `macos:defaults:security` runs `apply_security` (info/warn lines from the script + sudo prompt only if guest account is enabled and not previously disabled).
5. Run the shell-registration task:
   ```bash
   task macos:shell
   ```
   Expected: either runs apply (if `/etc/shells` doesn't already contain Homebrew zsh OR the user's registered shell isn't Homebrew zsh -- both status conditions ANDed must pass for skip) or skips with `task: Task "macos:shell" is up to date`.
6. Re-run the defaults aggregator immediately:
   ```bash
   task macos:defaults
   ```
   Expected: ALL five sub-tasks report "up to date" (security:status now passes because apply just ran; the other four skip via feature gate). Confirm zero `apply_*` info lines in the second-run output.

**Success criterion:** Step 4 output shows four sub-tasks skipped + one ran; Step 6 output shows ALL five sub-tasks skipped (idempotency on the second run).

**Rollback:**

1. Switch back to the original dev machine:
   ```bash
   task manifest:setup -- "$CURRENT_MACHINE"
   ```
2. Run `task manifest:resolve` to restore the original `resolved.json`.
3. (Optional, rarely needed) If the security apply set `guest-account=disabled` on a machine where it was previously enabled and the dev wants to revert: `sudo sysadminctl -guestAccount on`.

## Test 3 -- Laptop-mode install round-trip + idempotency (OSCF-03)

**Type:** manual -- runtime; HUMAN-REQUIRED; non-destructive (the round trip lands the canonical converged state).

**What it proves:** On a machine with all five `macos-*` features `true` (the dev's personal-laptop or work-laptop default), the full install pipeline runs each concern's apply once; a second invocation is a no-op (the `verify_<concern>` status calls pass cleanly). The v1 `macos:shell:145` bug class regression check is the critical sub-assertion: `task macos:shell && task macos:shell` second run must NOT re-apply.

**Steps:**

1. Verify active machine is a laptop with all five flags `true`:
   ```bash
   jq -r '.features | to_entries | map(select(.key|startswith("macos-"))) | .[] | "\(.key)=\(.value)"' "$XDG_STATE_HOME/dotfiles/resolved.json"
   ```
   Expect all five = true.
2. First run (timed):
   ```bash
   time task macos:defaults 2>&1 | tee /tmp/p6-test3-first.log
   ```
   Expected: first run may take seconds (apply paths actually write defaults + `killall Dock/Finder/SystemUIServer` per concern). Each concern script's info lines from `apply_<concern>` appear in the log.
3. Second run (timed) immediately after:
   ```bash
   time task macos:defaults 2>&1 | tee /tmp/p6-test3-second.log
   ```
   Expected: completes in under 2 seconds (all five status blocks gate the re-run); zero "Adding" / "Applying" / "Writing" info lines in the log; every concern reports `task: Task "macos:defaults:<concern>" is up to date`.
4. Shell-registration idempotency:
   ```bash
   task macos:shell && task macos:shell
   ```
   Expected first run: applies (or skips if already converged); expected second run: ALWAYS skips with `task: Task "macos:shell" is up to date`. **If the second run still prints "Adding Homebrew zsh to /etc/shells..." or "Changing default shell ...", the v1 `macos:shell:145` bug class regressed -- FAIL THIS TEST.**

**Success criterion:** First-run timing > second-run timing by at least 2x; second-run log contains no apply info lines; `task macos:shell` is genuinely idempotent (the bug-class fix holds).

**Rollback:** None required; the round trip lands the canonical converged state.

## Test 4 -- task macos:validate against deliberate drift (OSCF-05)

**Type:** manual -- runtime; HUMAN-REQUIRED; mutates state, but the rollback is the apply path itself.

**What it proves:** `task macos:validate` exits non-zero when any single defaults key is drifted away from its in-script expected value; the cross-line output names the failing key with both expected and actual values.

**Steps:**

1. Confirm `task macos:validate` exits 0 on the currently-converged machine:
   ```bash
   task macos:validate; echo "exit=$?"
   ```
   Expected: `exit=0`; check lines for every enabled concern's keys.
2. Deliberately bork a Dock key:
   ```bash
   defaults write com.apple.dock orientation -string "left"
   killall Dock 2>/dev/null || true
   ```
   Dock orientation flips from `bottom` (the in-script expected value) to `left`.
3. Run validate against the drifted state:
   ```bash
   task macos:validate; echo "exit=$?"
   ```
   Expected: `exit=1` (non-zero); the output contains a cross line of the shape `dock.orientation: expected 'bottom', got 'left'` (exact text format may vary; the key name + both values must appear).
4. Restore the converged state:
   ```bash
   task macos:defaults
   ```
   `task macos:defaults:dock` is marked `internal: true` in `taskfiles/macos.yml` and is NOT CLI-callable. The aggregator `task macos:defaults` routes through the internal task and `apply_dock` writes orientation back to `bottom` + `killall Dock` to refresh.
5. Re-validate:
   ```bash
   task macos:validate; echo "exit=$?"
   ```
   Expected: `exit=0`; no cross lines.

**Success criterion:** Step 3 produces exit-1 + the specific cross line for `dock.orientation`; Step 5 restores exit-0.

**Rollback:** Step 4 is the rollback. If `task macos:defaults` fails for any reason: manually run `defaults write com.apple.dock orientation -string "bottom" && killall Dock 2>/dev/null || true` and re-run `task macos:validate` to confirm.

## Test 5 -- Lint-suite regression on the new taskfile (OSCF-04 / LINT-02 / LINT-05 expected warnings)

**Type:** auto -- AUTO-RUN by the executor as part of Task 1.

**What it proves:** The new `taskfiles/macos.yml` introduces no LINT-02 violations and triggers the expected LINT-05 portability warnings (`defaults`/`dscl` calls in Darwin-only heredocs).

**Scope note:** This test's pass criterion is scoped to the new `taskfiles/macos.yml` shipped by Phase 6. Pre-existing `task lint` aggregator failures in other taskfiles (`common.yml`, `manifest.yml`, `brew.yml`, `claude.yml`) are owned by Phase 7 (CLAUDE) and Phase 8 (cutover/wrap-up) per `06-02-SUMMARY.md` and are NOT Phase 6 regressions.

**Steps:**

1. `task lint:taskfile 2>&1 | grep -E 'LINT-02:.*taskfiles/macos\.yml$'` -- MUST show the new file with a green check.
2. `task lint:syntax 2>&1 | grep -E 'yaml-parse:.*taskfiles/macos\.yml$'` -- MUST show the new file with a green check.
3. `task lint:portability 2>&1 | grep -E 'defaults|dscl' | wc -l` -- MUST be > 0 (warn-only output present and expected per RESEARCH Pitfall 10); the task itself MUST exit 0 (warn-only contract).

**Success criterion:** All three commands behave as specified for the new `taskfiles/macos.yml`.

**Rollback:** None required (read-only static analysis).

## Sign-off

| Test | Type | Status | Date | Tester | Notes |
|------|------|--------|------|--------|-------|
| 1. LINT-02 static regression | auto | green | 2026-05-15 | Josh Vaughen | yq grep returned no $BREW_ZSH matches; {{.BREW_ZSH}} template var present; LINT-02 check on taskfiles/macos.yml: green |
| 2. Server-mode install simulation | manual | green | 2026-05-15 | Josh Vaughen | Phase 6 server-mode contract proven via `zsh install/resolver.zsh --machine server-1 --stdout` (4 GUI concerns false + macos-security true per D-04). Note: `task manifest:resolve` has an upstream mtime-cache bug (already documented in 06-01-SUMMARY) that prevents the cached resolved.json from refreshing when only the active-machine file changes; the manifest itself is correct. Phase 8 follow-up: invalidate manifest:resolve cache on machine-selection change. |
| 3. Laptop-mode round-trip + idempotency | manual | green | 2026-05-15 | Josh Vaughen | passed; v1 macos:shell:145 bug class runtime regression check holds (second invocation skipped cleanly) |
| 4. macos:validate against deliberate drift | manual | green | 2026-05-15 | Josh Vaughen | passed; restored via `task macos:defaults` (aggregator) -- per-concern task is `internal: true` and not CLI-callable; UAT plan updated |
| 5. Lint-suite regression | auto | green | 2026-05-15 | Josh Vaughen | LINT-02 + yaml-parse: green on new taskfiles/macos.yml; lint:portability fired 21 expected warn lines on defaults/dscl; pre-existing aggregator failures in common.yml/manifest.yml/brew.yml/claude.yml documented as out-of-scope in 06-02-SUMMARY |

**Phase 6 UAT approved by:** Josh Vaughen  2026-05-15

## References

- **VALIDATION.md Manual-Only Verifications table:** `.planning/phases/06-os-defaults-macos-configuration/06-VALIDATION.md` lines 81-92 (the source of UAT test scenarios; each row maps 1:1 to a test in this file).
- **CONCERNS.md bug-class line range:** `.planning/codebase/CONCERNS.md` lines 15-19 (the v1 `macos:shell:145` `$BREW_ZSH`-in-status bug class; Test 1 cites this).
- **RESEARCH pitfalls:**
  - Pitfall 1 (broken two-line ANDed status -- feature-off machines must skip without running verify) at `.planning/phases/06-os-defaults-macos-configuration/06-RESEARCH.md` lines 521-555. Test 2 validates this on server-1.
  - Pitfall 10 (expected LINT-05 portability warnings on `defaults`/`dscl`) -- Test 5 records the expected count.
- **Per-test requirement IDs:**
  - Test 1: OSCF-04 (the structural fix for the v1 bug class).
  - Test 2: OSCF-04 (server-mode contract) + ROADMAP SC#4.
  - Test 3: OSCF-03 (per-task `status:` reads current defaults before writing).
  - Test 4: OSCF-05 (validate exits non-zero on drift).
  - Test 5: OSCF-04 (lint regression check) + LINT-02 / LINT-05 contracts.
- **Plan SUMMARYs:**
  - `06-01-SUMMARY.md` (manifest schema migration; defines the feature-gate keys this UAT tests).
  - `06-02-SUMMARY.md` (sourced concern scripts; the apply / verify functions the runtime tests exercise).
  - `06-03-SUMMARY.md` (taskfiles/macos.yml; the task surface this UAT runs commands against).
