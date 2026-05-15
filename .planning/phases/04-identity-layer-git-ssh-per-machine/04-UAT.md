---
status: resolved
phase: 04-identity-layer-git-ssh-per-machine
source: [04-01-SUMMARY.md, 04-02-SUMMARY.md, 04-03-SUMMARY.md, 04-04-SUMMARY.md]
started: 2026-05-14T22:55:00Z
updated: 2026-05-15T16:00:00Z
---

## Current Test

[testing complete; all gaps resolved by Wave 1 (04-05) and Wave 2 (04-06, 04-07)]

## Tests

### 1. Resolver + Identity Install Smoke Test
expected: |
  From a clean shell, run:
    task manifest:resolve
    task identity:install
  Both exit 0. resolved.json materializes at $XDG_STATE_HOME/dotfiles/resolved.json
  with the active machine's identity values populated. identity:install creates
  the expected symlinks. Re-running shows all status checks skip (idempotent).
result: resolved
status: resolved
resolution: |
  Plan 04-05 (commit d94168e) renamed the five public task keys in
  taskfiles/manifest.yml from `manifest:foo` to bare `foo`, eliminating the
  double-prefix produced by the include alias. `task manifest:resolve` now exits 0.
  `task identity:install` exits 0 (cascade dep fixed in same commit via [:manifest:resolve]).
  Live-verified 2026-05-15.

### 2. Manifest Test Fixture Suite
expected: |
  Run: task manifest:test
  Output reports 11/11 fixtures pass.
result: pass
status: resolved

### 3. Active SSH Identity Symlink Correctness
expected: |
  Run: readlink ~/.ssh/identities/active
  Output is the absolute path to the per-identity file matching the active
  machine's manifest identity.ssh value; the file exists.
result: pass
note: |
  Verified on clean machine Joshs-Air: /Users/josh/.ssh/identities/personal.
  All five identity overlays + active + cloudflared wrapper symlinks correct.
status: resolved

### 4. Cloudflared Wrapper Boots Without Unbound HOMEBREW_PREFIX (CR-01 Regression)
expected: |
  Wrapper invoked from a non-login subshell does not abort with "unbound variable".
result: pass
status: resolved

### 5. Empty-MANIFEST Guard Fires (CR-02 Regression)
expected: |
  task identity:install with no resolved.json must FAIL LOUDLY with a
  precondition error and must NOT create broken `<no value>` symlinks.
result: resolved
status: resolved
resolution: |
  Plan 04-05 (commit d94168e) fixed the deps cascade so `task identity:install`
  no longer exits with "Task identity:manifest:manifest:resolve does not exist"
  before reaching the precondition guard. The CR-02 precondition guard at
  taskfiles/identity.yml (test -s resolved.json) is now reachable and fires
  correctly when resolved.json is absent. Live-verified 2026-05-15.

### 6. Placeholder Pub-Keys Rejected by validate:ssh-add (WR-01)
expected: |
  validate:ssh-add either skips placeholder pub-keys cleanly or errors with a
  clear message.
result: skipped
reason: |
  WR-01's code path is server-only (only fires when identity.ssh in {server-1, server-2}
  whose .pub files are placeholders). Both available test machines (JMBP, Joshs-Air)
  are personal-laptops; verifying WR-01 requires a server-1/server-2 machine.
status: skipped

### 7. server-include Materialization (D-08) -- workstation branch
expected: |
  On a workstation: ~/.config/git/server-include.config does NOT exist.
result: pass
note: |
  Verified ABSENT on both JMBP and Joshs-Air. Server branch not exercised
  (no server machine in scope).
status: resolved

### 8. task identity:validate Exits 0 (IDNT-07 BLOCKING Gate)
expected: |
  task identity:validate exits 0 after task install on a converged machine.
result: resolved
status: resolved
resolution: |
  Plan 04-07 (commit f6b6c94) rewrote validate:git to probe from a real
  git repo found via `find "$root" -maxdepth 2 -name .git -type d -print -quit`
  and uses `git -C "$probe_dir" rev-parse --is-inside-work-tree` as the
  work-tree guard. `task identity:validate` exits 0 live on server-2 (server
  identity: $HOME not a git work tree -> info message -> skip -> exit 0).
  Personal-laptop branch (email assertion via [includeIf]) requires human
  exercise on a converged personal-laptop; see 04-VERIFICATION.md human_verification.

## Summary

total: 8
passed: 5
issues: 0
pending: 0
skipped: 1
blocked: 0
resolved: 3

## Gaps

- truth: "task manifest:resolve (as documented in CLAUDE.md and PROJECT docs) resolves the active manifest"
  status: resolved
  resolution: Plan 04-05 (commit d94168e) -- bare key rename in taskfiles/manifest.yml
  reason: |
    User reported: `task manifest:resolve` exits with `task: Task "manifest:resolve"
    does not exist`. Actual name was `manifest:manifest:resolve` (double-prefixed).
  severity: major
  test: 1
  root_cause: |
    `taskfiles/manifest.yml` declared all five public task keys with a literal
    `manifest:` segment baked in. The root `Taskfile.yml` includes that file
    under alias `manifest`, so go-task prepended `manifest:` again -> doubled
    names. Fixed by renaming all five keys to bare form (resolve, show, validate,
    test, test:add-machine).

- truth: "Resolver warning shows a usable XDG_STATE_HOME path AND only fires when resolved.json is actually missing"
  status: resolved
  resolution: Plan 04-06 (commit 36925a0) -- one-hop RESOLVED_JSON_PATH in manifest.yml vars block
  reason: |
    Two-part observation. (a) Path interpolation printed bare `/resolved.json`.
    (b) Warning fired even when resolved.json clearly existed.
  severity: minor
  test: 1
  root_cause: |
    `taskfiles/manifest.yml` built RESOLVED_JSON_PATH via a two-hop template
    chain (STATE_DIR -> RESOLVED_JSON_PATH). When included by root Taskfile.yml,
    go-task's include-vars evaluation saw XDG_STATE_HOME in scope but not the
    locally-derived STATE_DIR intermediate. Chain collapsed to `/resolved.json`.
    Fixed by one-hop: `'{{.XDG_STATE_HOME}}/dotfiles/resolved.json'`.

- truth: "task identity:install runs end-to-end on a converged machine"
  status: resolved
  resolution: Plan 04-05 (commit d94168e) -- leading-colon absolute dep in identity.yml
  reason: |
    Reproduced on both JMBP and Joshs-Air: `task identity:install` exited 201
    with `Task "identity:manifest:manifest:resolve" does not exist`.
  severity: blocker
  test: 5
  root_cause: |
    Direct cascade of the manifest-namespace gap. `taskfiles/identity.yml`
    used `deps: [manifest:manifest:resolve]`. go-task resolves unqualified
    deps relative to the current include namespace, so from inside `identity:`
    the dep became `identity:manifest:manifest:resolve` (triple-prefixed,
    undefined). Fixed by using `deps: [":manifest:resolve"]` (quoted
    leading-colon absolute form).

- truth: "task identity:validate exits 0 on a converged personal-laptop after install (IDNT-07 BLOCKING gate)"
  status: resolved
  resolution: Plan 04-07 (commit f6b6c94) -- validate:git find+rev-parse probe-repo rewrite
  reason: |
    On clean Joshs-Air install, all four validate:symlinks assertions passed but
    validate:git failed: `expected 'josh@vaughen.net', got ''`.
  severity: blocker
  test: 8
  root_cause: |
    validate:git used `gitdir="$HOME/git/personal"` (a parent directory) as the
    probe source. git's [includeIf gitdir/i:] block requires a real .git to match
    against; from a non-repo directory it is silently skipped. Fixed by using
    `find "$root" -maxdepth 2 -name .git -type d -print -quit` to locate a real
    repo and `git -C "$probe_dir" rev-parse --is-inside-work-tree` as the
    work-tree guard.
  remaining: |
    Personal/work identity email assertion requires exercise on a converged
    personal-laptop or work-laptop. Server-2 skip path verified live 2026-05-15.
    See 04-VERIFICATION.md human_verification section.
