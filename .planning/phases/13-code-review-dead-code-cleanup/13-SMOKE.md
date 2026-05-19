# Phase 13 Smoke Test: links:* target-match (REVW-05)

**Purpose:** Verify the fix in Plan 13-05 -- when a links:* symlink points to a wrong source, the next `task install` re-links it to the correct source (per ROADMAP SC#4).

**Run frequency:** Once after Plan 13-05 lands; re-run if a later plan modifies `taskfiles/links.yml` status blocks or if a regression is suspected in the readlink -f target-match logic.

**Prerequisites:**

- Active machine set: `cat "$XDG_STATE_HOME/dotfiles/machine"` returns a valid machine name.
- `task install` previously completed successfully (the symlink under test is currently correct).
- Manifest resolved: `task manifest:resolve` exits 0 and `$XDG_STATE_HOME/dotfiles/resolved.json` exists.
- Operator is on macOS (the canonical readlink -f behavior tested here is BSD/macOS; the inline expression in `taskfiles/links.yml` uses `readlink -f` which is supported by both `/usr/bin/readlink` on macOS and GNU readlink under coreutils).

---

## Scenario 1: Deliberately corrupted symlink -> next `task install` repairs it

**Target under test:** `$XDG_CONFIG_HOME/eza/theme.yaml`
(Always-on link, no feature gate. Other links in `install-zsh`, `install-claude`, `install-configs`, and `configs:ghostty` work the same way; this one is chosen for its simplicity and zero side effects to the operator's interactive shell.)

**Setup:**

1. Verify the symlink is currently correct:
   ```
   readlink -f "$XDG_CONFIG_HOME/eza/theme.yaml"
   ```
   Expected: a path ending in `configs/eza/theme.yaml` rooted at the dotfiles repo (`$DOTFILEDIR`). On the dev machine this is typically `/Users/josh/Git/personal/dotfiles/configs/eza/theme.yaml`.

2. Create a decoy file the corrupted symlink will point to:
   ```
   touch /tmp/13-smoke-decoy-target
   ```

3. Corrupt the symlink by re-pointing it to the decoy (uses `ln -sfn` for idempotent replacement of the existing symlink):
   ```
   ln -sfn /tmp/13-smoke-decoy-target "$XDG_CONFIG_HOME/eza/theme.yaml"
   ```

4. Verify the corruption is in place:
   ```
   readlink "$XDG_CONFIG_HOME/eza/theme.yaml"
   ```
   Expected: `/tmp/13-smoke-decoy-target` (raw readlink shows the link's target string verbatim).
   Note: `readlink -f` on macOS may resolve `/tmp` through the system `/tmp -> /private/tmp` symlink and print `/private/tmp/13-smoke-decoy-target` -- this is expected macOS behavior and does not affect the assertion below.

**Action:**

5. Run `task install`. Observe that the install pipeline performs work (does NOT no-op past the `links:install-configs` sub-task). The sub-task SHOULD re-execute its `cmds:` because its status block (post-Plan-13-05) detects the readlink -f mismatch against the manifest-expected source path (`$DOTFILEDIR/configs/eza/theme.yaml`).

**Assertion:**

6. After `task install` returns, verify the symlink is restored:
   ```
   readlink -f "$XDG_CONFIG_HOME/eza/theme.yaml"
   ```
   Expected: a path ending in `$DOTFILEDIR/configs/eza/theme.yaml` (the original correct source). NOT `/tmp/13-smoke-decoy-target` or `/private/tmp/13-smoke-decoy-target`.

7. Verify the converged-state idempotency contract is restored -- a second `task install` immediately after the first MUST no-op on the `links:install-configs` sub-task:
   ```
   task install
   ```
   Expected: the install pipeline runs but produces no "running command" output for `links:install-configs` (its status block now returns 0; `cmds:` is skipped).

**Cleanup:**

8. Remove the decoy file:
   ```
   rm /tmp/13-smoke-decoy-target
   ```

**Pass:** all assertions in steps 6 and 7 hold.
**Fail:** if step 6 returns `/tmp/13-smoke-decoy-target` (the corruption was not repaired), Plan 13-05's status-block fix is broken -- file a regression and re-investigate `taskfiles/links.yml` status blocks.

**Operator results log** (fill after run):

- Date run:
- Result (PASS / FAIL):
- Notes:

---

## Scenario 2 (optional): Broken parent directory recovery

*Author this scenario if a future plan touches logic around parent-dir creation in `_:safe-link`. Otherwise omit; the deliberately-corrupted scenario is the SC#4 minimum.*

---

## Scenario 3 (optional): Manifest feature flag toggle

*Author this scenario if interested in cross-checking that toggling `features.claude-marketplace` from true -> false -> true correctly re-links the 13 claude entries. Otherwise omit.*

---

*Phase: 13-code-review-dead-code-cleanup*
*Procedure authored: 2026-05-18*
*Smoke-test results recorded inline (operator notes pass/fail per scenario after run).*
