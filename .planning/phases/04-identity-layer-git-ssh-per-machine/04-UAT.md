---
status: complete
phase: 04-identity-layer-git-ssh-per-machine
source: [04-01-SUMMARY.md, 04-02-SUMMARY.md, 04-03-SUMMARY.md, 04-04-SUMMARY.md]
started: 2026-05-14T22:55:00Z
updated: 2026-05-14T23:10:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Resolver + Identity Install Smoke Test
expected: |
  From a clean shell, run:
    task manifest:resolve
    task identity:install
  Both exit 0. resolved.json materializes at $XDG_STATE_HOME/dotfiles/resolved.json
  with the active machine's identity values populated. identity:install creates
  the expected symlinks (git config, ssh config, per-identity overlays, ssh
  keys, cloudflared.zsh wrapper) for the active machine. Re-running
  identity:install shows all status checks skip (idempotent).
result: issue
reported: |
  $ task manifest:resolve
  task: Available tasks for this project: [...task list shows manifest:manifest:resolve...]
  task: Task "manifest:resolve" does not exist
  (also confirmed on clean machine Joshs-Air: task identity:install exits 201
   with "Task identity:manifest:manifest:resolve does not exist")
severity: major

### 2. Manifest Test Fixture Suite
expected: |
  Run: task manifest:manifest:test (documented as `task manifest:test`)
  Output reports 11/11 fixtures pass.
result: pass

### 3. Active SSH Identity Symlink Correctness
expected: |
  Run: readlink ~/.ssh/identities/active
  Output is the absolute path to the per-identity file matching the active
  machine's manifest identity.ssh value; the file exists.
result: pass
note: |
  Verified on clean machine Joshs-Air after manual sub-task install
  (workaround for Test 5 cascade). Output:
    /Users/josh/.ssh/identities/personal
  All five identity overlays + active + cloudflared wrapper symlinks
  materialized correctly.

### 4. Cloudflared Wrapper Boots Without Unbound HOMEBREW_PREFIX (CR-01 Regression)
expected: |
  Wrapper invoked from a non-login subshell (HOMEBREW_PREFIX not exported)
  does not abort with "unbound variable" / "parameter not set".
result: pass

### 5. Empty-MANIFEST Guard Fires (CR-02 Regression)
expected: |
  task identity:install on a machine with no resolved.json must FAIL LOUDLY
  with a precondition error and must NOT create broken `<no value>` symlinks.
result: issue
reported: |
  Reproduced on both JMBP and Joshs-Air:
    $ task identity:install ; echo "exit=$?"
    task: Failed to run task "identity:install": task: Task "identity:manifest:manifest:resolve" does not exist
    exit=201
    $ find ~/.ssh ~/.config -name '*no value*' 2>/dev/null  -> zero hits
  CR-02's intent (no broken symlinks) holds, but only because install never
  reaches the symlink stage — the namespace cascade kills the task first.
severity: blocker

### 6. Placeholder Pub-Keys Rejected by validate:ssh-add (WR-01)
expected: |
  validate:ssh-add either skips placeholder pub-keys cleanly or errors with a
  clear message — does NOT extract "Replace" via awk.
result: skipped
reason: |
  WR-01's code path is server-only (it activates when identity.ssh is
  server-1 or server-2, where the .pub files are placeholders). On a
  personal-laptop (identity.ssh=personal), validate:ssh-add looks up the
  real personal.pub key and the placeholder check is unreachable. Both
  available test machines (JMBP, Joshs-Air) are personal-laptops; verifying
  WR-01 requires a server-1/server-2 machine.

### 7. server-include Materialization (D-08) -- workstation branch
expected: |
  On a workstation: ~/.config/git/server-include.config does NOT exist.
result: pass
note: |
  Verified ABSENT on both JMBP and Joshs-Air (both workstations).
  Server branch not exercised (no server machine in scope).

### 8. task identity:validate Exits 0 (IDNT-07 BLOCKING Gate)
expected: |
  task identity:validate exits 0 after task install on a converged machine.
result: issue
reported: |
  On clean Joshs-Air install (sub-task workaround for cascade):
    $ task identity:validate ; echo "exit=$?"
    ✓ git config linked
    ✓ ssh config linked
    ✓ ssh active identity linked
    ✓ ssh cloudflared wrapper linked
    ✗ git user.email mismatch: expected 'josh@vaughen.net', got ''
    task: Failed to run task "identity:validate": task: Failed to run task "identity:validate:git": exit status 1
    exit=201
  All four symlink assertions pass, but validate:git fails because
  `git config --get user.email` in ~/Git/personal/dotfiles returns empty.
  Symlinks were created but the [includeIf] chain isn't actually setting
  user.email on a fresh personal-laptop install.
severity: blocker

## Summary

total: 8
passed: 4
issues: 3
pending: 0
skipped: 1
blocked: 0

## Gaps

- truth: "task manifest:resolve (as documented in CLAUDE.md and PROJECT docs) resolves the active manifest"
  status: failed
  reason: |
    User reported: `task manifest:resolve` exits with `task: Task "manifest:resolve"
    does not exist`. The task list shows the actual name as `manifest:manifest:resolve`
    -- the manifest namespace is double-prefixed because the include block in
    Taskfile.yml prefixes `manifest:` and the included taskfile already prefixes
    its own task names with `manifest:`. By contrast, `identity:install` and
    `identity:validate` show up in the root namespace correctly (single-prefix),
    so the bug is asymmetric: only the manifest taskfile is affected.
  severity: major
  test: 1
  artifacts: []  # Filled by diagnosis
  missing: []    # Filled by diagnosis

- truth: "Resolver warning shows a usable XDG_STATE_HOME path AND only fires when resolved.json is actually missing"
  status: failed
  reason: |
    Two-part bug. (a) Path interpolation: warning prints
    `warning: /resolved.json missing or empty -- run 'task setup -- <machine>' first`
    -- the path is bare `/resolved.json`, not `$XDG_STATE_HOME/dotfiles/resolved.json`.
    Likely an empty `${XDG_STATE_HOME}` or `${RESOLVED_JSON_PATH}` shell var in
    the warn-fallback branch. (b) Spurious-fire: on Joshs-Air the warning ALSO
    fires when running `task identity:git` even though resolved.json clearly
    exists at /Users/josh/.local/state/dotfiles/resolved.json (jq query
    succeeded). So the warn-fallback is using a different (broken) path-resolution
    code path than the actual MANIFEST_JSON loader, and treats every successful
    run as a "missing manifest" warning. Note: `task identity:ssh` does NOT
    print the warning, so the issue is specific to identity:git's vars block
    (or a shared helper called only from identity:git).
  severity: minor
  test: 1
  artifacts: []  # Filled by diagnosis
  missing: []    # Filled by diagnosis

- truth: "task identity:install runs end-to-end on a converged machine"
  status: failed
  reason: |
    Reproduced on both JMBP and Joshs-Air: `task identity:install` exits 201
    with `task: Failed to run task "identity:install": task: Task
    "identity:manifest:manifest:resolve" does not exist`. The CR-02 manifest-
    empty precondition guard was NEVER reached -- task died earlier on a
    namespace-resolution cascade. Root cause is the same as the Test 1
    finding (manifest taskfile is double-prefixed in the includes block),
    but the cascade is more damaging here: identity:install carries a deps
    reference to `manifest:manifest:resolve`, which from inside the
    `identity:` namespace gets re-prefixed to `identity:manifest:manifest:resolve`
    (triple-prefixed) and is undefined. Net effect: `task identity:install`
    is unrunnable on every machine, fresh or set-up. By extension `task install`
    (canonical entry per docs) is unrunnable end-to-end. The CR-02 design
    intent (no broken `<no value>` symlinks) does still hold -- find for
    `*no value*` returned zero hits -- but only because install never reaches
    the symlink stage. WORKAROUND CONFIRMED: invoking the sub-tasks directly
    (task identity:git ; task identity:ssh) succeeds and produces a complete,
    correct symlink layout.
  severity: blocker
  test: 5
  artifacts: []  # Filled by diagnosis
  missing: []    # Filled by diagnosis

- truth: "task identity:validate exits 0 on a converged personal-laptop after install (IDNT-07 BLOCKING gate)"
  status: failed
  reason: |
    On a clean Joshs-Air install (using sub-task workaround for the cascade),
    all four validate:symlinks assertions pass (git config, ssh config, ssh
    active identity, ssh cloudflared wrapper -- all linked correctly). But
    validate:git fails: `expected 'josh@vaughen.net', got ''`. The git
    config symlink IS in place (validate:symlinks confirmed it), but
    `git config --get user.email` returns empty. Implications:
      - identity/git/config is symlinked into ~/.config/git/config (or wherever
        git's XDG path resolves) -- otherwise validate:symlinks would have failed
      - But [include] of identity/git/config and the [includeIf gitdir/i:~/Git/personal/]
        chain isn't propagating user.email to the dotfiles repo (which IS under
        ~/Git/personal/...).
    Possible root causes:
      (1) identity/git/config doesn't carry an [includeIf] block matching the
          gitdir pattern -- check if it actually has `[includeIf "gitdir/i:~/Git/personal/"]`
          pointing at identities/personal
      (2) identities/personal overlay doesn't set user.email
      (3) git's config resolution isn't picking up identity/git/config (wrong
          target path -- e.g., symlinked to ~/.gitconfig but git reads
          ~/.config/git/config instead, or vice versa)
      (4) gitdir pattern uses a path form that doesn't match -- e.g., literal
          `~` instead of $HOME, or missing trailing slash
    This breaks the IDNT-07 BLOCKING gate. Phase 04 cannot be marked complete
    until validate:git exits 0 on a fresh personal-laptop install.
  severity: blocker
  test: 8
  artifacts: []  # Filled by diagnosis
  missing: []    # Filled by diagnosis
