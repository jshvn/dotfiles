---
status: resolved
trigger: "task identity:validate exits 201 on a converged personal-laptop with: 'git user.email mismatch: expected josh@vaughen.net, got '''. validate:symlinks passes (all four canonical symlinks present), but validate:git fails because git config --get user.email returns empty."
created: 2026-05-14T23:30:00Z
updated: 2026-05-19T05:46:00Z
resolution: "Resolved at v2.1 milestone close without separate fix. Diagnosis preserved for reference; revisit in v2.2 if validate:git still mismatches."
---

## Current Focus

hypothesis: validate:git invokes `git -C "$HOME/git/personal" config user.email` against a directory that is NOT a git repository, so git operates with no repo context and the [includeIf "gitdir/i:..."] block in identity/git/config never fires; the global config has no top-level [user] email, so the lookup returns empty.
test: traced the validate:git case branch for identity=personal at taskfiles/identity.yml:316 and the actual git invocation at taskfiles/identity.yml:354; confirmed identity/git/config only has [user] name (no email); confirmed [includeIf] is keyed on gitdir which only matches when a current .git directory is being resolved.
expecting: gitdir="$HOME/git/personal" is the *parent* of repos, not a repo itself. Git in that directory has no .git -> no includeIf match -> no overlay applied -> empty user.email. Symptom matches exactly.
next_action: return ROOT CAUSE FOUND with confirmed mechanism + the supporting hypothesis that the [user] block in identity/git/config lacks an email and is the only thing global git config sees outside a tracked repo.

## Symptoms

expected: |
  After `task setup -- personal-laptop` and `task identity:install` (or its sub-task workaround:
  `task identity:git && task identity:ssh`), `task identity:validate` returns exit 0 on a clean
  personal-laptop. validate:git, in particular, asserts that git's user.email equals
  'josh@vaughen.net' (loaded from identity/git/identities/personal via the personal includeIf).
actual: |
  On clean Joshs-Air (identity=personal):
    $ task identity:validate ; echo "exit=$?"
    OK git config linked
    OK ssh config linked
    OK ssh active identity linked
    OK ssh cloudflared wrapper linked
    FAIL git user.email mismatch: expected 'josh@vaughen.net', got ''
    task: Failed to run task "identity:validate": task: Failed to run task "identity:validate:git": exit status 1
    exit=201
  All four validate:symlinks assertions PASS. validate:git fails because
  `git config --get user.email` (run from inside the validate:git task's chosen
  $gitdir) returns the empty string.
errors: |
  "git user.email mismatch: expected 'josh@vaughen.net', got ''"
  task: Failed to run task "identity:validate:git": exit status 1
  exit=201
reproduction: |
  Test 8 in .planning/phases/04-identity-layer-git-ssh-per-machine/04-UAT.md.
  On a fresh personal-laptop checkout where ~/git/personal exists as a directory
  but is NOT itself a git repo (it is the *parent* of cloned repos), run
  `task identity:validate` after the symlinks have been created. validate:git
  exits 1 with the empty-email mismatch.
started: |
  Discovered during Phase 04 verify-work UAT on a clean Joshs-Air install,
  2026-05-14. The IDNT-07 BLOCKING gate has never passed end-to-end on a
  fresh personal-laptop install in v2; this is the first machine on which
  the symptom was reproduced.

## Eliminated

- hypothesis: identity/git/config doesn't have a [includeIf] block matching the gitdir pattern at all
  evidence: |
    Read identity/git/config:16-20 -- the file DOES carry:
      [includeIf "gitdir/i:~/git/personal/"]
          path = identities/personal
      [includeIf "gitdir/i:~/git/work/"]
          path = identities/work
    So the includeIf chain is present and shaped correctly. Hypothesis (1) of the
    investigation hint is false.
  timestamp: 2026-05-14T23:35:00Z

- hypothesis: identities/personal overlay doesn't actually set user.email
  evidence: |
    Read identity/git/identities/personal:9-11 -- the overlay sets:
      [user]
          name = Josh Vaughen
          email = josh@vaughen.net
          signingkey = ssh-ed25519 ...
    user.email is present and correct. Hypothesis (2) of the investigation hint
    is false.
  timestamp: 2026-05-14T23:36:00Z

- hypothesis: git's config search-path doesn't reach identity/git/config because XDG_CONFIG_HOME isn't set in the validate:git context (so git falls back to ~/.gitconfig which isn't symlinked)
  evidence: |
    validate:symlinks PASSES the "git config linked" assertion at
    taskfiles/identity.yml:293. _:check-link verifies the canonical XDG path
    {{.GIT_CONFIG_DIR}}/config which resolves to $XDG_CONFIG_HOME/git/config
    (= ~/.config/git/config when XDG_CONFIG_HOME is unset; default per Taskfile.yml:35).
    git on macOS checks $XDG_CONFIG_HOME/git/config OR $HOME/.config/git/config
    OR $HOME/.gitconfig in that order; the symlink IS at the XDG location and
    git finds it. Proof: the [user] name = Josh Vaughen line *is* picked up
    globally (otherwise validate:git's expected_email would not even reach the
    actual_email check -- but expected_email IS read correctly via -f flag).
    More to the point: if git could not find any global config at all, the
    [user] name from identity/git/config would also be missing, and we would
    see the cross-check error trigger differently. Hypothesis (5) of the
    investigation hint is false.
  timestamp: 2026-05-14T23:38:00Z

- hypothesis: case-sensitivity mismatch between pattern (~/git/personal/) and on-disk dir (/Users/josh/Git/personal/...) breaks the includeIf
  evidence: |
    The pattern uses `gitdir/i:` -- the `/i` flag explicitly enables
    case-INsensitive matching (per git-config(1) docs: "gitdir/i is the same
    as gitdir except that matching is done case-insensitively"). Additionally
    macOS APFS by default is case-insensitive, so `~/git/personal/` and
    `~/Git/personal/` resolve to the same on-disk directory regardless of the
    pattern flag. Case is therefore not the failure mode. Hypothesis (4) of
    the investigation hint is false.
  timestamp: 2026-05-14T23:40:00Z

## Evidence

- timestamp: 2026-05-14T23:32:00Z
  checked: identity/git/config (full file)
  found: |
    Lines 13-23:
      [user]
          name = Josh Vaughen
      [includeIf "gitdir/i:~/git/personal/"]
          path = identities/personal
      [includeIf "gitdir/i:~/git/work/"]
          path = identities/work
      [include]
          path = server-include.config
    The top-level [user] block sets ONLY `name`, not `email`. Email is
    delegated to the per-identity overlays via [includeIf]. So globally, with
    no repo context, `git config user.email` will see no value.
  implication: |
    For `git config user.email` to return josh@vaughen.net, the [includeIf]
    block MUST fire -- which requires git to be evaluating against a current
    .git directory whose path matches the `~/git/personal/` glob.

- timestamp: 2026-05-14T23:33:00Z
  checked: identity/git/identities/personal
  found: |
    Lines 8-11:
      [user]
          name = Josh Vaughen
          email = josh@vaughen.net
          signingkey = ssh-ed25519 ...
    The overlay correctly sets user.email. The overlay file itself is correct.
  implication: |
    The overlay would produce the expected email IF it were loaded. So the
    bug is in load triggering, not in overlay content.

- timestamp: 2026-05-14T23:34:00Z
  checked: taskfiles/identity.yml:302-360 (validate:git task body)
  found: |
    For identity=personal the task does:
      gitdir="$HOME/git/personal"               # line 316
      ...
      if [[ ! -d "$gitdir" ]]; then exit 0; fi  # lines 348-351 (skip when absent)
      ...
      actual_email=$(git -C "$gitdir" config user.email 2>/dev/null || echo "")  # line 354
    The crucial detail: gitdir = "$HOME/git/personal" is the PARENT directory
    that contains personal repos as subdirs. It is NOT itself a git repo. There
    is no .git directory at $HOME/git/personal/.git -- the .git lives one level
    deeper (e.g., $HOME/git/personal/dotfiles/.git).
  implication: |
    `git -C "$HOME/git/personal" config user.email` runs git in a directory
    that is NOT inside any git repository. Per git-config(1), [includeIf
    "gitdir:..."] only fires when git is resolving the location of an actual
    .git directory; with no current .git, the gitdir pattern has nothing to
    match and the include is silently skipped. So git only sees the global
    config (identity/git/config via the symlink), whose top-level [user]
    block has no email -> empty result. EXACTLY the symptom reported.

- timestamp: 2026-05-14T23:42:00Z
  checked: web search (git-config docs) -- includeIf gitdir matching semantics
  found: |
    Per git-config(1):
      "If the location of the .git directory matches the pattern, the include
       condition is met."
    There must BE a .git directory for matching to occur. When git is invoked
    outside any repo, gitdir-conditioned includes are not evaluated. The
    well-documented behavior of `git -C <dir> config <key>` outside a repo
    is to fall back to system + global config only.
  implication: |
    Confirms the mechanism: the validate:git task's choice of `gitdir =
    "$HOME/git/personal"` (a non-repo parent directory) is incompatible with
    the includeIf-driven email scheme. The validator's "expected" assertion
    requires that includeIf fires, but the validator runs git in a location
    where it cannot fire.

- timestamp: 2026-05-14T23:44:00Z
  checked: validate:symlinks behavior (taskfiles/identity.yml:288-299) vs the actual symptom
  found: |
    The four passing assertions only verify -L/-e on:
      {{.GIT_CONFIG_DIR}}/config       (~/.config/git/config)
      {{.SSH_DIR}}/config              (~/.ssh/config)
      {{.SSH_IDENTITIES_DIR}}/active   (~/.ssh/identities/active)
      {{.SSH_IDENTITIES_DIR}}/cloudflared.zsh
    None of them verify behavior of git config resolution -- they only verify
    that a symlink is present and points at an existing target. So
    validate:symlinks passing tells us only that the symlink topology is
    correct; it tells us nothing about whether [includeIf] fires.
  implication: |
    Confirms the bug is purely in validate:git's invocation site, not in
    install layer. install does the right thing (symlinks land); validate
    queries git from a place where the includeIf cannot fire.

- timestamp: 2026-05-14T23:46:00Z
  checked: hypothesis cross-check -- could the symptom also occur if validate:git were run from inside an actual repo under ~/git/personal/?
  found: |
    If validate:git did `gitdir="$HOME/git/personal/dotfiles"` (or any real
    repo under ~/git/personal/), git would:
      1. Discover .git at .../dotfiles/.git
      2. Read global config ~/.config/git/config
      3. Encounter [includeIf "gitdir/i:~/git/personal/"]
      4. Match: .git is at $HOME/git/personal/dotfiles/.git which matches
         the pattern $HOME/git/personal/**
      5. Load identities/personal -> set user.email = josh@vaughen.net
      6. Return josh@vaughen.net
    The fix path is therefore: change validate:git to invoke git from inside
    a real repo under the gitdir pattern, not from the parent directory.
  implication: |
    Confirms root cause AND points at the fix shape (run validate from inside
    a real repo, OR construct a temporary repo, OR use the existing dotfiles
    repo at $DOTFILEDIR which happens to be inside ~/Git/personal/ on the
    reporting machine).

## Resolution

root_cause: |
  validate:git invokes `git -C "$HOME/git/personal" config user.email` (taskfiles/identity.yml:354
  for identity=personal, line 316 sets gitdir). $HOME/git/personal is the *parent* directory
  that contains personal repos as subdirectories -- it is NOT itself a git repository. Git
  evaluates [includeIf "gitdir:..."] blocks only when resolving a current .git directory; in
  a non-repo directory there is no .git to match against, so the personal includeIf in
  identity/git/config is never triggered, and the user.email override from
  identity/git/identities/personal is never loaded.

  Compounding (necessary for the symptom): identity/git/config's top-level [user] block at
  lines 13-14 sets ONLY `name = Josh Vaughen`. There is no top-level `email`. The email is
  delegated entirely to the per-identity overlays via [includeIf]. So when the includeIf does
  not fire, `git config user.email` legitimately returns empty -- the global config holds no
  email value, and there is no system-level git config setting one either.

  Net effect: `git -C "$HOME/git/personal" config user.email` returns empty regardless of how
  correctly the symlinks are placed; validate:git's assertion is unsatisfiable from this
  invocation site. The same install on the same machine WOULD pass the assertion if validate:git
  ran git from inside any actual repo under ~/git/personal/ (e.g., $HOME/git/personal/dotfiles
  or any other cloned repo there) -- because then the includeIf's gitdir glob would match the
  resolved .git path and load the personal overlay.

  The four validate:symlinks assertions pass because they verify symlink topology only -- they
  never exercise git's config resolution. The symlink layout is correct; the validator's choice
  of probe location is wrong.

fix: ""  # diagnose-only mode -- no fix applied
verification: ""  # diagnose-only mode
files_changed: []
