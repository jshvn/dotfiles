---
status: diagnosed
phase: 04-identity-layer-git-ssh-per-machine
source: [04-01-SUMMARY.md, 04-02-SUMMARY.md, 04-03-SUMMARY.md, 04-04-SUMMARY.md]
started: 2026-05-14T22:55:00Z
updated: 2026-05-14T23:25:00Z
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
  the expected symlinks. Re-running shows all status checks skip (idempotent).
result: issue
reported: |
  $ task manifest:resolve
  task: Task "manifest:resolve" does not exist
  (also confirmed on clean machine Joshs-Air)
severity: major

### 2. Manifest Test Fixture Suite
expected: |
  Run: task manifest:manifest:test
  Output reports 11/11 fixtures pass.
result: pass

### 3. Active SSH Identity Symlink Correctness
expected: |
  Run: readlink ~/.ssh/identities/active
  Output is the absolute path to the per-identity file matching the active
  machine's manifest identity.ssh value; the file exists.
result: pass
note: |
  Verified on clean machine Joshs-Air: /Users/josh/.ssh/identities/personal.
  All five identity overlays + active + cloudflared wrapper symlinks correct.

### 4. Cloudflared Wrapper Boots Without Unbound HOMEBREW_PREFIX (CR-01 Regression)
expected: |
  Wrapper invoked from a non-login subshell does not abort with "unbound variable".
result: pass

### 5. Empty-MANIFEST Guard Fires (CR-02 Regression)
expected: |
  task identity:install with no resolved.json must FAIL LOUDLY with a
  precondition error and must NOT create broken `<no value>` symlinks.
result: issue
reported: |
  Reproduced on both JMBP and Joshs-Air: exit=201 with
  "Task identity:manifest:manifest:resolve does not exist".
  CR-02's intent (no broken symlinks) holds, but only because install never
  reaches the symlink stage.
severity: blocker

### 6. Placeholder Pub-Keys Rejected by validate:ssh-add (WR-01)
expected: |
  validate:ssh-add either skips placeholder pub-keys cleanly or errors with a
  clear message.
result: skipped
reason: |
  WR-01's code path is server-only (only fires when identity.ssh ∈ {server-1, server-2}
  whose .pub files are placeholders). Both available test machines (JMBP, Joshs-Air)
  are personal-laptops; verifying WR-01 requires a server-1/server-2 machine.

### 7. server-include Materialization (D-08) -- workstation branch
expected: |
  On a workstation: ~/.config/git/server-include.config does NOT exist.
result: pass
note: |
  Verified ABSENT on both JMBP and Joshs-Air. Server branch not exercised
  (no server machine in scope).

### 8. task identity:validate Exits 0 (IDNT-07 BLOCKING Gate)
expected: |
  task identity:validate exits 0 after task install on a converged machine.
result: issue
reported: |
  On clean Joshs-Air install (sub-task workaround for cascade):
    ✓ git config linked / ✓ ssh config linked / ✓ ssh active / ✓ cloudflared
    ✗ git user.email mismatch: expected 'josh@vaughen.net', got ''
    exit=201
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
    does not exist`. Actual name is `manifest:manifest:resolve` (double-prefixed).
  severity: major
  test: 1
  root_cause: |
    `taskfiles/manifest.yml` declares all five public task keys with a literal
    `manifest:` segment baked in (`manifest:resolve`, `manifest:show`,
    `manifest:validate`, `manifest:test`, `manifest:test:add-machine` at lines
    148, 174, 222, 277, 469). The root `Taskfile.yml:78-83` includes that file
    under the alias `manifest`, so go-task prepends `manifest:` again -> doubled
    names. By contrast `taskfiles/identity.yml` uses bare keys (`install`, `git`,
    `ssh`, `validate`), so its include produces correct single-prefixed names.
    The asymmetry is self-introduced by manifest.yml. An inline comment at root
    `Taskfile.yml:126-128` already acknowledges this as a P1 nomenclature
    artifact deferred from P2 scope.
  artifacts:
    - path: "taskfiles/manifest.yml"
      issue: "Lines 148, 174, 222, 277, 469 declare task keys with redundant `manifest:` prefix"
    - path: "taskfiles/manifest.yml"
      issue: "Lines 140, 142 are intra-file `task:` calls referencing the prefixed names; will need lockstep rename"
    - path: "Taskfile.yml"
      issue: "Line 129 references `deps: [manifest:manifest:resolve]`; needs rename post-fix"
    - path: "Taskfile.yml"
      issue: "Lines 126-128 carry the deferred-fix acknowledgement comment; remove on cutover"
  missing:
    - "Rename five task keys in taskfiles/manifest.yml: manifest:resolve -> resolve, manifest:show -> show, manifest:validate -> validate, manifest:test -> test, manifest:test:add-machine -> test:add-machine"
    - "Update intra-file task: refs in taskfiles/manifest.yml (lines 140, 142) to bare names"
    - "Update root Taskfile.yml line 129 deps: to use the bare manifest:resolve form"
    - "Remove the deferred-fix comment block at Taskfile.yml:126-128"
    - "Update taskfiles/README.md (lines 19-20) and CLAUDE.md / docs to confirm the canonical names"
  debug_session: ".planning/debug/manifest-namespace-double-prefix.md"

- truth: "Resolver warning shows a usable XDG_STATE_HOME path AND only fires when resolved.json is actually missing"
  status: failed
  reason: |
    Two-part observation. (a) Path interpolation prints bare `/resolved.json`.
    (b) Warning fires even when resolved.json clearly exists. (c) Apparent
    asymmetry between identity:git and identity:ssh.
  severity: minor
  test: 1
  root_cause: |
    `taskfiles/manifest.yml:51-53` builds RESOLVED_JSON_PATH via a TWO-HOP
    template chain:
      STATE_DIR:          '{{.XDG_STATE_HOME}}/dotfiles'
      RESOLVED_JSON_PATH: '{{.STATE_DIR}}/resolved.json'
    When manifest.yml is loaded as an INCLUDE from root Taskfile.yml, go-task's
    variable substitution renders MANIFEST_JSON's sh: text against a scope where
    XDG_STATE_HOME is in scope (forwarded via the include's vars: block) but the
    locally-derived intermediate STATE_DIR is NOT in scope. Chain collapses to
    `'/resolved.json'` -- the bare-slash artifact. The `[[ -s '/resolved.json' ]]`
    test always fails -> warning fires unconditionally. go-task's eager-eval of
    sh: vars (issue #535) means this runs at startup regardless of which task
    you invoked. The "asymmetry" between identity:git and identity:ssh was
    ILLUSORY: identity:ssh's `status:` was already satisfied (cmds skipped, noise
    suppressed); identity:git's status: was unsatisfied so cmds actually ran.
    Confirmed by direct test: standalone `task -t taskfiles/manifest.yml
    manifest:resolve` substitutes the path correctly; only the include path
    triggers the bug.
  artifacts:
    - path: "taskfiles/manifest.yml"
      issue: "Line 53 uses two-hop template '{{.STATE_DIR}}/resolved.json' which collapses under include-eval scope"
    - path: "Taskfile.yml"
      issue: "Lines 78-83 forward XDG_STATE_HOME but not STATE_DIR/RESOLVED_JSON_PATH (correct behaviour, but exposes the bug)"
  missing:
    - "Replace taskfiles/manifest.yml line 53: RESOLVED_JSON_PATH: '{{.XDG_STATE_HOME}}/dotfiles/resolved.json' (one-hop form, matching the working pattern in taskfiles/identity.yml:67-79)"
    - "Keep STATE_DIR defined for cmds: blocks that use it for mkdir (cmd-time substitution is unaffected)"
  debug_session: ".planning/debug/resolver-warn-fallback-broken.md"

- truth: "task identity:install runs end-to-end on a converged machine"
  status: failed
  reason: |
    Reproduced on both JMBP and Joshs-Air: `task identity:install` exits 201
    with `Task "identity:manifest:manifest:resolve" does not exist`.
  severity: blocker
  test: 5
  root_cause: |
    Direct cascade of the manifest-namespace gap above. `taskfiles/identity.yml:111`
    declares `deps: [manifest:manifest:resolve]`. go-task resolves unqualified
    deps RELATIVE to the current include namespace, so from inside `identity:`
    the dep becomes `identity:manifest:manifest:resolve` (triple-prefixed,
    undefined). The CR-02 manifest-empty precondition guard is reached AFTER
    deps resolution, so it never fires. Net effect: `task identity:install` is
    unrunnable on every machine. The CR-02 design intent (no broken `<no value>`
    symlinks) does still hold -- but only because install never reaches the
    symlink stage. WORKAROUND CONFIRMED: `task identity:git ; task identity:ssh`
    sub-tasks succeed with correct symlink layout.
  artifacts:
    - path: "taskfiles/identity.yml"
      issue: "Line 111 deps reference uses bare `manifest:manifest:resolve` which resolves relative to identity: namespace -> triple-prefixed -> undefined"
    - path: "taskfiles/identity.yml"
      issue: "Line 13 comment block also references manifest:manifest:resolve; update for consistency"
  missing:
    - "After fixing the manifest-namespace gap, update taskfiles/identity.yml:111 deps to use absolute namespace form: deps: [:manifest:resolve] (leading colon anchors at root namespace, bypassing the relative-resolution gotcha)"
    - "Smoke-test the leading-colon absolute-reference form on the project's go-task minimum (3.37) before mass-edit; if not supported, fallback is to invoke manifest:resolve as a cmds: `task:` call instead of a deps:"
    - "Update the comment block at taskfiles/identity.yml:13 to reflect the canonical clean names"
  debug_session: ".planning/debug/manifest-namespace-double-prefix.md"

- truth: "task identity:validate exits 0 on a converged personal-laptop after install (IDNT-07 BLOCKING gate)"
  status: failed
  reason: |
    On clean Joshs-Air install, all four validate:symlinks assertions pass but
    validate:git fails: `expected 'josh@vaughen.net', got ''`.
  severity: blocker
  test: 8
  root_cause: |
    `taskfiles/identity.yml:316` sets `gitdir="$HOME/git/personal"` -- the
    PARENT directory that contains personal repos as subdirectories, not a
    repo itself. Line 354 runs `git -C "$gitdir" config user.email`. Per
    git-config(1), `[includeIf "gitdir:..."]` is evaluated only when git is
    resolving a current `.git` directory. With no `.git` to compare against,
    the personal includeIf is silently skipped. The compounding fact:
    `identity/git/config:13-14` declares a top-level `[user]` block setting
    only `name = Josh Vaughen` -- email is delegated entirely to per-identity
    overlays via [includeIf]. So when no includeIf fires, no email exists in
    any layer git can see, and `git config user.email` legitimately returns
    empty. validate:symlinks's four assertions pass because they verify
    symlink topology only -- never exercise git's config-resolution path.
    Same structural bug exists for identity=work (line 320: gitdir=$HOME/git/work).
    Server identities (lines 323-326: gitdir=$HOME) are not affected because
    the server-include.config materialization uses unconditional [include].
  artifacts:
    - path: "taskfiles/identity.yml"
      issue: "Line 316 (personal) and line 320 (work) set gitdir to a non-repo parent directory; gitdir-conditioned includeIf cannot fire"
    - path: "taskfiles/identity.yml"
      issue: "Lines 348-351 [[ -d $gitdir ]] guard accepts any existing directory; should verify it's actually a git work tree"
    - path: "taskfiles/identity.yml"
      issue: "Line 354 git -C $gitdir config user.email runs from outside any repo -> empty result"
    - path: "identity/git/config"
      issue: "Lines 13-14 [user] block sets only `name`; this is correct-by-design (delegate email to overlays) and should NOT be changed"
  missing:
    - "Change validate:git to probe from inside an actual git repository whose .git path matches the personal/work gitdir glob"
    - "Replace the [[ -d ]] guard at lines 348-351 with `git -C $gitdir rev-parse --is-inside-work-tree` (skip cleanly if not a repo)"
    - "Pick one of three probe-source strategies: (1) probe from $DOTFILEDIR if it lives under ~/git/personal/ -- brittle; (2) find any subdir containing .git via `find ~/git/personal -maxdepth 2 -name .git -type d -print -quit` -- recommended; (3) materialize a throwaway probe repo via `git init` in tempdir -- most robust, highest cost"
    - "Apply same fix shape to identity=work branch (line 320)"
  debug_session: ".planning/debug/validate-git-empty-useremail-after-install.md"
