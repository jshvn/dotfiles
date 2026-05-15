---
status: blocked
phase: 05-packages-layer-brewfile-composition-verification
source: [05-VERIFICATION.md, 05-HUMAN-UAT.md]
started: 2026-05-15T19:35:00Z
updated: 2026-05-15T19:45:00Z
---

## Current Test

number: 1
name: PKGS-03 idempotency smoke
expected: |
  Run `task packages:install` once on personal-laptop and let it finish.
  Run it again immediately. The second invocation is a sub-second no-op.
awaiting: gap closure (1password-cli formula/cask classification bug)

## Tests

### 1. PKGS-03 idempotency smoke
expected: After a converged install, running `task packages:install` a second time is a sub-second no-op (status block via `brew bundle check --file=<composed>` returns clean; no full `brew bundle` invocation).
result: fail
issue: blocked at first install -- `brew bundle install` fails before reaching convergence.

### 2. VRFY-03 negative-path smoke
expected: Rename a declared cask's `.app` (e.g. `mv /Applications/Slack.app /Applications/Slack.app.tmp`), then run `task install`. The full pipeline halts at `packages:verify` with non-zero exit and a per-package cross row for the missing `.app`. Restore with `mv /Applications/Slack.app.tmp /Applications/Slack.app`.
result: blocked
reason: depends on a converged install (Test 1).

### 3. End-to-end `task install` smoke
expected: From a clean working tree on `personal-laptop` on the `josh/dotfiles-v2-refactor` branch, `task install` runs the full pipeline (`links:all` -> `packages:install` -> `claude:install` -> `macos:defaults` -> `macos:shell` -> `packages:verify`) and exits 0 with the success banner.
result: blocked
reason: depends on a converged install (Test 1).

## Summary

total: 3
passed: 0
issues: 1
pending: 0
blocked: 2

## Gaps

### Gap 1: 1password-cli misclassified as formula in `packages/core.rb`

**Test:** 1 (PKGS-03 idempotency smoke)
**Severity:** high (blocks `task packages:install` end-to-end)
**Encountered:** 2026-05-15 during initial install on personal-laptop

**Symptom:**
```
Installing 1password-cli
Warning: '1password-cli' formula is unreadable: No available formula with the name "1password-cli".
Error: No formulae found for 1password-cli.
Installing 1password-cli has failed!
`brew bundle` failed! 1 Brewfile dependency failed to install
task: Failed to run task "packages:install": exit status 1
```

**Root cause:** `packages/core.rb` declares `brew '1password-cli' # verify: op`, but Homebrew has migrated `1password-cli` to a cask-only listing (`/opt/homebrew/Caskroom/1password-cli/`, source at `homebrew-cask/Casks/1/1password-cli.rb`). The cask installs a binary artifact (`op`), not an `.app` bundle. The plan's design from 05-01 (formula with `# verify: op`) reflected the pre-migration shape and is no longer valid against current Homebrew.

**Why automated verification missed it:** Phase 5 automated checks confirmed structural shape (verify-comment present, antidote present, antigen absent) but never invoked `brew bundle install` against live Homebrew. The HUMAN-UAT smoke was the first time the formula name was resolved against the registry.

**Fix scope:**
1. Move `1password-cli` from `brew` to `cask` in `packages/core.rb`.
2. Decide how `packages:verify` handles binary-only casks. Current `packages:verify` logic (per 05-04 SUMMARY) assumes casks always populate `/Applications/<App>.app`. `1password-cli` installs `op` to `/opt/homebrew/bin/op` (Binary artifact). Options:
   - **A. Special-case binary-only cask shape:** Allow `cask '1password-cli' # verify: op` to mean "run `command -v op`" instead of "check `/Applications/op.app`". Requires `packages:verify` to detect the binary-artifact shape (look up `brew info --cask --json=v2 1password-cli | jq '.casks[].artifacts[]|select(has("binary"))'`) or use a new comment convention like `# verify: bin:op`.
   - **B. Drop verify for 1password-cli:** Add the cask without a verify comment; rely on the cask installing successfully as the implicit check. Loses the "did `op` actually land on PATH" assurance.
   - **C. Keep verify but use a new bin: prefix:** `cask '1password-cli' # verify: bin:op` -- explicit, no autodetection, fewer surprises.

**Recommended fix:** Option C (`bin:` prefix), because it preserves the strong VRFY guarantee, doesn't require live `brew info` calls inside `packages:verify`, and lets `gui.rb` casks keep using the bare `# verify: <AppName>` shape they already have. Two-file change: `packages/core.rb` (move + reannotate the line) + `taskfiles/packages.yml` (extend cask-verify branch to recognize `# verify: bin:<name>` and dispatch to `command -v <name>`).

**Files to fix:**
- `packages/core.rb` -- move `1password-cli` from `brew` to `cask`, update verify comment
- `taskfiles/packages.yml` -- extend cask-verify dispatch to handle `bin:` prefix
- `packages/README.md` (DOCS-02) -- document the `# verify: bin:<name>` extension

