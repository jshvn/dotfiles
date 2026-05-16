---
status: testing
phase: 05-packages-layer-brewfile-composition-verification
source: [05-VERIFICATION.md, 05-HUMAN-UAT.md]
started: 2026-05-15T19:35:00Z
updated: 2026-05-15T20:05:00Z
---

## Current Test

number: 2
name: VRFY-03 negative-path smoke
expected: |
  Rename a declared cask's `.app` (e.g. `mv /Applications/Slack.app /Applications/Slack.app.tmp`),
  then run `task install`. The full pipeline halts at `packages:verify` with non-zero exit
  and a per-package cross row for the missing `.app`. Restore with
  `mv /Applications/Slack.app.tmp /Applications/Slack.app`.
awaiting: user response (after deciding how to handle Gap 2: 7 unrelated verify-comment issues)

## Tests

### 1. PKGS-03 idempotency smoke
expected: After a converged install, running `task packages:install` a second time is a sub-second no-op (status block via `brew bundle check --file=<composed>` returns clean; no full `brew bundle` invocation).
result: pass
evidence: |
  After applying the gap-1 fix (commit 896e09e):
  - `brew bundle check --no-upgrade --file=$XDG_CACHE_HOME/dotfiles/Brewfile`
    returned "The Brewfile's dependencies are satisfied." in 0.959s.
  - Two back-to-back `task packages:install` invocations both completed
    as no-ops (1.001s / 1.001s wall, no `brew bundle install` output,
    no "Using/Installing" lines).
  - Idempotency claim (sub-second no-op via status block) confirmed.

### 2. VRFY-03 negative-path smoke
expected: Rename a declared cask's `.app` (e.g. `mv /Applications/Slack.app /Applications/Slack.app.tmp`), then run `task install`. The full pipeline halts at `packages:verify` with non-zero exit and a per-package cross row for the missing `.app`. Restore with `mv /Applications/Slack.app.tmp /Applications/Slack.app`.
result: blocked
reason: |
  Gap 2 (7 unrelated verify-comment issues) makes `packages:verify` already exit
  non-zero for legitimately-installed packages, so Test 2 can't isolate the
  rename-induced failure from the background noise.

### 3. End-to-end `task install` smoke
expected: From a clean working tree on `personal-laptop` on the `josh/dotfiles-v2-refactor` branch, `task install` runs the full pipeline (`links:all` -> `packages:install` -> `claude:install` -> `macos:defaults` -> `macos:shell` -> `packages:verify`) and exits 0 with the success banner.
result: blocked
reason: |
  Blocked on Gap 2 -- `packages:verify` is the final step of `task install`
  (D-10 + VRFY-04) and currently fails on the 7 verify-comment issues even
  for fully-installed packages.

## Summary

total: 3
passed: 1
issues: 2
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

**Resolution:** Fixed inline 2026-05-15 in commit 896e09e (Option C). The new `# verify: bin:<bin>` convention is implemented in the cask loop of `taskfiles/packages.yml`; `packages/core.rb` declares `cask '1password-cli' # verify: bin:op`; `packages/README.md` documents the extension under "Verify rules". Direct exercise of the dispatch path confirmed `✓ cask 1password-cli -> op`. `brew bundle check` is clean against the new composed Brewfile.

### Gap 2: 7 unrelated verify-comment mismatches surfaced by `packages:verify`

**Test:** 1 (revealed while exercising the post-gap-1 verify path)
**Severity:** high (blocks `task install` end-to-end via VRFY-04; tests 2 and 3 cannot proceed)
**Encountered:** 2026-05-15 after gap-1 fix on personal-laptop

**Symptom:** `task packages:verify` reports 7 failures even though all referenced packages are fully installed:

| Kind | Declared | Verify target | Actual on disk |
|------|----------|---------------|----------------|
| formula | `brew 'tlrc'` | `command -v tlrc` | tlrc binary not on PATH (likely not installed; check `brew list tlrc`) |
| formula | `brew 'antidote'` | `command -v antidote` | antidote is a zsh plugin (function loaded via `.zshrc`), not a binary -- `command -v` from a non-interactive shell can't find it |
| cask | `cask 'miniconda'` | `/Applications/Miniconda.app` | Miniconda is a CLI distribution; no .app bundle. Same class as 1password-cli -- needs `# verify: bin:conda` or similar |
| cask | `cask 'nvidia-geforce-now'` | `/Applications/NVIDIA GeForce NOW.app` | App-name mismatch (cask installs to a different bundle name) |
| cask | `cask 'protonvpn'` | `/Applications/Proton VPN.app` | App-name mismatch (verify comment in manifest TOML is wrong) |
| mas | `mas 'Things'` | `/Applications/Things.app` | App-name mismatch -- the actual bundle is `Things3.app` |

**Root cause:** Each entry's verify metadata was authored against the *expected* App-bundle name without per-machine field validation. The verify-comment shape works (the dispatch logic is correct), but the metadata values are wrong for at least these 5 casks/MAS apps, plus 2 formulas that need different verify strategies (antidote = function-not-binary; tlrc = legitimately not installed yet).

**Fix scope (per-item):**
1. **antidote** (formula): Either drop the verify check (it's a sourced zsh function) or change to `# verify: cd-or-similar-shim`. Architectural call. The most honest fix is to remove `# verify: antidote` and add a comment that documents why -- antidote loads via the .zshrc plugin chain, not as a PATH binary. Alternative: ship a `antidote-loaded` wrapper script.
2. **tlrc** (formula): Run `brew list tlrc` to confirm install state; if missing, `brew install tlrc` once (Brewfile install must have skipped it). If installed but the binary is named differently, add `# verify: <bin>` override.
3. **miniconda** (cask): Move to `# verify: bin:conda` (or `bin:python` if the cask's binary artifact is the python installer). Same pattern as 1password-cli.
4. **nvidia-geforce-now** (cask): Run `brew info --cask nvidia-geforce-now | grep -i artifact` (or `ls /Applications/ | grep -i nvidia`) and update the `verify` field in `manifests/machines/personal-laptop.toml`.
5. **protonvpn** (cask): Same -- inspect `/Applications/` for the real `.app` name and update the `verify` field.
6. **Things** (mas): Verify the actual installed `.app` name (probably `Things3.app`) and update the `name` field in the manifest's `extra_packages.mas` entry. Note: `name` here doubles as both the MAS-list display name and the verify target, so any change must keep the MAS install path working.

**Closure path (decided 2026-05-15):** Full design pivot to brew-info-driven verify. The per-item rename fix proposed above is superseded -- it papers over the underlying brittleness (hand-typed verify metadata that re-breaks on the next upstream rename). Instead:

**Two-layer verify model (replaces D-04 + D-05 + D-06 verify-comment annotations):**

| Layer | Check | Mechanism |
|---|---|---|
| 1 | Is the package installed per brew? | `brew bundle check --no-upgrade --file=<composed>` -- already wired in `packages:install`'s status block; Test 1 confirmed sub-second behavior. |
| 2 | Are the artifacts actually on disk? | `brew info --installed --json=v2` (bulk call, ~200ms total) returns every installed package's artifact list. `packages:verify` parses `.casks[].artifacts[]` / `.formulae[].installed[].linked_keg` / per-package binaries and checks each declared artifact path exists. |

**Scope delta vs the original 6-file rename:**

- `taskfiles/packages.yml` -- rewrite the `verify` task to use the brew-info bulk path. Drop the cask-loop verify-comment dispatch (including the just-added `bin:` prefix from commit 896e09e). Drop the formula-loop's `# verify: <bin>` override path. Keep the MAS loop (no brew-info equivalent for App Store; `mas list | awk '{print $1}'` returns installed ids, compared against declared `extra_packages.mas[].id`).
- `packages/core.rb` -- strip every `# verify: <bin>` and `# verify: bin:<bin>` comment. The brew-info bulk call is authoritative. Keep `1password-cli` as a cask (gap-1 was correct independent of this pivot).
- `packages/gui.rb` -- strip the two `# verify: <App>` comments on the cask lines.
- `manifests/defaults.toml` + `manifests/machines/*.toml` (5 files) -- drop the `verify` field from every cask object in `extra_packages.casks` (27 + 18 + 0 + 0 + 0 = 45 entries to delist). Schema becomes `casks = [{name = "<cask>"}]` instead of `[{name, verify}]`. Keep `extra_packages.mas[].name` (drives MAS-list display + the simple `/Applications/<name>.app` fallback for App Store apps).
- `install/resolver.zsh` -- adjust the cask validation: `name` field still required, `verify` field no longer required.
- `docs/MANIFEST.md` -- update the typed-bucket-extras section to remove the `verify` requirement on cask entries. Add a Verify-model section describing the brew-info two-layer check.
- `packages/README.md` -- replace the Verify rules section with the new two-layer model. Drop the gap-1 `bin:` prefix documentation (no longer needed).
- `taskfiles/packages.yml` -- set `silent: false` on `packages:verify` to close Gap 3 in the same plan.

**Mitigations baked in:** Bulk `brew info --installed --json=v2` keeps verify under 1s even for the full 50-package set (~200ms brew call + parse). No per-package brew-info subprocess fan-out. Cache file path (`$XDG_CACHE_HOME/dotfiles/brew-artifacts.json`) is an open question for the planner to decide -- whether to cache between runs (faster repeat verify) or always-fresh (no stale-cache failure class).

**Risk register for the planner:**
- Some brew packages have empty `.casks[].artifacts[]` (no installable artifacts; service-only formulas). The verify task must accept "package installed per brew + no on-disk artifact required" as a pass.
- `brew info` over the network on first run after a long idle period can take longer; the `--installed` form should hit local metadata only, but the planner should test this assumption.
- The `name` field on MAS entries doubles as display + verify target. Keep both responsibilities -- MAS has no `brew info` equivalent.

Plan goes through `/gsd-plan-phase 5 --gaps`.

### Gap 3: `silent: true` swallows `packages:verify` output through `task`

**Test:** 1 (observed while diagnosing Gap 2)
**Severity:** medium (diagnosability; verify still produces correct exit codes)
**Encountered:** 2026-05-15 while running `task packages:verify` to investigate Gap 2

**Symptom:** Running `task packages:verify` directly (or piped to a file) produces zero visible stdout/stderr lines, even though the underlying script writes check/cross output via `messages.zsh`. The task exits with the correct failure count (exit 1 in our case), but the user gets no actionable diagnostic. Running the same script body in a plain `zsh -c '...'` block (bypassing the `task` wrapper) prints the full check/cross enumeration correctly.

**Root cause:** Root `Taskfile.yml` declares `silent: true` at the top level. Combined with `set: [errexit, pipefail]` and the way go-task captures cmd output when the cmd returns non-zero, the heredoc cmd's stdout/stderr gets buffered and discarded on failure exit. `--silent=false`, `--output=interleaved`, `--output=group`, and `--verbose` flags do not restore output. Output is visible in a real interactive TTY (per the user's original failing transcript), so the issue is specific to non-TTY/piped/captured invocations.

**Fix scope:** Either (a) drop `silent: true` at root and add `silent: true` per-task only where it's wanted, or (b) keep `silent: true` but explicitly mark `packages:verify` with `silent: false` so its check/cross output is always visible. Option (b) is smaller and matches the intent (verify failures should be diagnosable).

**Suggested closure path:** Same as Gap 2 -- bundle into the same gap-closure plan since it touches `taskfiles/packages.yml` and is logically the same "verify diagnosability" concern.

