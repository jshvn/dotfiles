---
status: partial
phase: 05-packages-layer-brewfile-composition-verification
source: [05-VERIFICATION.md]
started: 2026-05-15T19:25:00Z
updated: 2026-05-16T02:55:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. PKGS-03 idempotency smoke
expected: After a converged install, running `task packages:install` a second time is a sub-second no-op (status block via `brew bundle check --file=<composed>` returns clean; no full `brew bundle` invocation).
steps:
  - On `personal-laptop` (or any converged machine), run `task packages:install` once and let it complete.
  - Immediately re-run `task packages:install`.
  - Observe wall-clock time and absence of `brew bundle` output.
result: [pending]

### 2. VRFY-03 negative-path smoke
expected: Renaming a declared cask's `.app` bundle makes `task packages:verify` hard-fail with a per-package cross row for the missing `.app` and a non-zero exit code equal to the failure count.
steps:
  - Confirm a declared cask is installed (e.g. `/Applications/Slack.app`).
  - `mv /Applications/Slack.app /Applications/Slack.app.tmp`.
  - Run `task packages:verify`. Expected: exits non-zero with a `✗ cask slack -> /Applications/Slack.app NOT FOUND` row and a summary `✗ N package(s) failed verify`.
  - Restore: `mv /Applications/Slack.app.tmp /Applications/Slack.app`.
  - Re-run `task packages:verify` to confirm it returns to clean green.
note: |
  Originally written against `task install`, but `task install` is blocked by the
  cutover-ack gate (`install/cutover-gate.zsh`) until Phase 8 implements the
  sentinel writer (CUTV-03). `task packages:verify` exercises the identical
  verify code path that `task install` would have run as its final step, so the
  test still covers VRFY-03 end-to-end without being held up by the gate.
result: passed
verified: 2026-05-16

### 3. End-to-end `task install` smoke
expected: From a clean working tree on `personal-laptop`, `task install` runs the full pipeline (`links:all` -> `packages:install` -> `claude:install` -> `macos:defaults` -> `macos:shell` -> `packages:verify`) and exits 0 with the success banner.
status: blocked
blocked_on: Phase 8 CUTV-03 (cutover-ack sentinel writer)
steps:
  - PRECONDITION (Phase 8 work): `task cutover:ack -- <machine>` must exist; it writes `$XDG_STATE_HOME/dotfiles/cutover-ack` containing `<machine> <ISO-8601 timestamp>`. This task is not yet implemented in Phase 5.
  - Once CUTV-03 lands: on `personal-laptop` with `josh/dotfiles-v2-refactor` checked out, run `task cutover:ack -- personal-laptop` then `task install`.
  - Expected: composer produces a Brewfile, `brew bundle install` reports clean, `packages:verify` checks every formula + cask + mas, success banner prints.
manual_workaround: |
  To unblock without waiting for Phase 8, write the sentinel manually:
    mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
    printf 'personal-laptop %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      > "${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/cutover-ack"
  Then `task install` will pass the gate. This is a workaround for testing only;
  the canonical Phase 8 task should still be implemented before milestone close.
result: [pending]

## Summary

total: 3
passed: 2
issues: 0
pending: 0
skipped: 0
blocked: 1
notes:
  - Test 1 (PKGS-03 idempotency) recorded passed 2026-05-15 in 05-VERIFICATION.md.
  - Test 2 (VRFY-03 negative path) reworded 2026-05-16 to invoke `task packages:verify` directly instead of `task install`; the cutover-ack gate would otherwise block before verify runs. Identical verify code path; identical contract. Confirmed passed 2026-05-16.
  - Test 3 blocked on Phase 8 CUTV-03 (the `task cutover:ack -- <machine>` writer is not yet implemented). A manual sentinel-write workaround is documented in-step for users who want to exercise the full pipeline before CUTV-03 lands.

## Gaps
