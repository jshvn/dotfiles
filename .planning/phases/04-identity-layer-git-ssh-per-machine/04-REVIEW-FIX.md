---
phase: 04-identity-layer-git-ssh-per-machine
fixed_at: 2026-05-14T22:45:00Z
review_path: .planning/phases/04-identity-layer-git-ssh-per-machine/04-REVIEW.md
iteration: 1
findings_in_scope: 9
fixed: 9
skipped: 0
status: all_fixed
---

# Phase 04: Code Review Fix Report

**Fixed at:** 2026-05-14T22:45:00Z
**Source review:** .planning/phases/04-identity-layer-git-ssh-per-machine/04-REVIEW.md
**Iteration:** 1
**Fix scope:** critical_warning (CR-* and WR-* findings; IN-* excluded)

**Summary:**
- Findings in scope: 9 (2 Critical, 7 Warning)
- Fixed: 9
- Skipped: 0

All 9 in-scope findings were fixed and committed atomically. Each fix was
verified with `task -t taskfiles/identity.yml --list` (YAML + go-template
parse) and, for the .zsh wrapper, `zsh -n` syntax check. No findings
required rollback. Info-tier findings (IN-01 through IN-04) are out of
scope per the default --fix policy and remain in REVIEW.md for follow-up.

## Fixed Issues

### CR-01: cloudflared wrapper aborts under SSH ProxyCommand because $HOMEBREW_PREFIX is unset

**Files modified:** `identity/ssh/cloudflared.zsh`
**Commit:** 09efe1b
**Applied fix:** Added a `${HOMEBREW_PREFIX:-}` guard with `uname -m`
dispatch (`arm64` -> `/opt/homebrew`, `x86_64` -> `/usr/local`, unknown
arch -> stderr error + exit 1) before the `exec`. Also added an `-x`
check on the resolved cloudflared binary so the wrapper fails with a
clear stderr message rather than a generic exec error. Header comment
updated to explain why the local detection is needed (ProxyCommand
subshells do not source `.zprofile`). Project rule honored: the bare
`/opt/homebrew` and `/usr/local` literals are confined to the
`uname -m` dispatch (the same pattern used in `Taskfile.yml` to derive
`HOMEBREW_PREFIX` for tasks).

### CR-02: Active-symlink swap silently corrupts when resolved.json is missing

**Files modified:** `taskfiles/identity.yml`
**Commit:** a907355
**Applied fix:** Added two `preconditions:` blocks to both the `git:`
and `ssh:` tasks. The first asserts `test -s '{{.RESOLVED_JSON_PATH}}'`
(resolved.json exists and is non-empty). The second validates that
`{{.MANIFEST.identity.git}}` / `{{.MANIFEST.identity.ssh}}` resolves to
one of the known values (`personal|work|server-1|server-2|none`), which
catches both the `<no value>` literal that go-task emits when the
ref-dot lookup fails AND any future typo or unknown identity. Failure
messages point the operator at `task setup -- <machine-name>` so the
recovery step is obvious. The `server-include` task is downstream of
`git`, so its identity guarantee transitively flows through the new
`git` preconditions.

### WR-01: Placeholder pub keys pass the "non-empty" check and would cause confusing ssh-add failures

**Files modified:** `taskfiles/identity.yml`
**Commit:** b9797e1
**Applied fix:** Added a placeholder-shape check immediately after the
`! -s` guard in `validate:ssh-add`. The first line of the file is
inspected with `head -n1`; if it does not start with one of the SSH
key-type identifiers (`ssh-ed25519`, `ssh-rsa`, `ecdsa-`, `sk-`), the
task warns and exits 0 ("placeholder, not a real public key --
skipping") rather than proceeding to extract bogus key material with
`awk` and producing a misleading "ssh-add -L does not include expected
pub key" error. The placeholder pub-key files themselves
(`server-1.pub`, `server-2.pub`) are NOT modified; per the inline
comments in those files they are intentional cutover stubs awaiting
IDNT-07 in Phase 8.

### WR-02: cloudflared.zsh has no executable bit / no callsite verification

**Files modified:** `identity/ssh/cloudflared.zsh` (mode change only)
**Commit:** a5ca6f3
**Applied fix:** Used `chmod +x` followed by `git update-index
--chmod=+x` to flip the file mode from `100644` to `100755` in the git
index. The script is now directly executable, which matches the
"`exec` replaces this shell process" contract its header documents.
SSH `ProxyCommand <path>` already worked via `/bin/sh -c` wrapping, but
direct invocation (testing, alternate ProxyCommand syntax, future
Linux port) now also works.

### WR-03: Hardcoded josh@vaughen.net in validate:git drifts from identity overlay file

**Files modified:** `taskfiles/identity.yml`
**Commit:** f9689ec
**Applied fix:** Replaced the inline constants
`expected_email="josh@vaughen.net"` (personal) and
`expected_email="${identity}@jgrid.net"` (server-1, server-2) with
`git config -f .../identity/git/identities/<id> user.email` reads,
matching the pattern the `work` branch already used. All four
non-`none` branches now read the source-of-truth value from the same
overlay files that get symlinked into `~/.config/git/identities/`, so
any future drift in those files is actually exercised by the
validator.

### WR-04: validate:git skip-when-gitdir-absent guard has dead-code branches

**Files modified:** `taskfiles/identity.yml`
**Commit:** 3587409
**Applied fix:** Replaced the three-clause `[[ ! -d ... ]] && [[ ...
!= "server-1" ]] && [[ ... != "server-2" ]]` chain with an explicit
`case "$identity" in server-1|server-2) ;; *) ... esac` switch that
documents the intent: workstation identities skip the assertion when
`$gitdir` is absent (fresh checkout case); server identities key off
`$HOME` (which always exists) and bypass this guard entirely. A future
maintainer adding `server-3` only needs to extend the case list.

### WR-05: validate:keys does not detect private keys in subdirectories

**Files modified:** `taskfiles/identity.yml`
**Commit:** 5b4af09
**Applied fix:** Removed `-maxdepth 1` from the `find` invocation in
`validate:keys`, with an inline comment citing IDNT-06 (defense in
depth: a private key smuggled into a subdirectory should still be
flagged, even though `.gitignore`'s `*` rule would normally block the
commit).

### WR-06: validate:ssh-add awk extraction is brittle for multi-field key bodies

**Files modified:** `taskfiles/identity.yml`
**Commit:** 40081e1
**Applied fix:** Replaced the bare `awk '{print $2}'` calls (both the
local pub-key extraction and the `ssh-add -L` filter) with anchored
expressions: `awk '$1 ~ /^(ssh-|ecdsa-|sk-)/ {print $2; exit}'` for
the local file (single-line guarantee via `exit`) and `awk '$1 ~
/^(ssh-|ecdsa-|sk-)/ {print $2}'` for the agent output (skip any
non-key lines). This handles pub-key files that contain leading
comments or blank lines and protects against newline-containing
strings being passed to the line-oriented `grep -qF`.

### WR-07: server-include task does not idempotently rewrite stale path under correct identity

**Files modified:** `taskfiles/identity.yml`
**Commit:** 277e120
**Applied fix:** Replaced the loose `grep -q
"identities/{{.MANIFEST.identity.git}}"` status check with an
exact-match `diff` against the canonical two-line content the cmd
writes (`[includeIf "gitdir:~/"]` + `    path = identities/<id>`).
Stale-content cases (e.g., a file containing both server-1 and
server-2 path lines from a prior buggy append) now fail the status
check and trigger a rewrite, restoring idempotency.

---

_Fixed: 2026-05-14T22:45:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
