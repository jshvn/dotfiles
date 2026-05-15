---
status: partial
phase: 05-packages-layer-brewfile-composition-verification
source: [05-VERIFICATION.md]
started: 2026-05-15T19:25:00Z
updated: 2026-05-15T19:25:00Z
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
expected: Renaming a declared cask's `.app` bundle makes `task install` hard-fail at the `packages:verify` step with a per-package cross report.
steps:
  - Confirm a declared cask is installed (e.g. `/Applications/Slack.app`).
  - `mv /Applications/Slack.app /Applications/Slack.app.tmp`.
  - Run `task install`. Expected: pipeline halts at `packages:verify` with non-zero exit and a cross row for the missing `.app`.
  - Restore: `mv /Applications/Slack.app.tmp /Applications/Slack.app`.
result: [pending]

### 3. End-to-end `task install` smoke
expected: From a clean working tree on `personal-laptop`, `task install` runs the full pipeline (`links:all` -> `packages:install` -> `claude:install` -> `macos:defaults` -> `macos:shell` -> `packages:verify`) and exits 0 with the success banner.
steps:
  - On `personal-laptop` with the current `josh/dotfiles-v2-refactor` branch checked out, run `task install`.
  - Expected: composer produces a Brewfile, `brew bundle install` reports clean, `packages:verify` checks every formula + cask + mas, success banner prints.
result: [pending]

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps
