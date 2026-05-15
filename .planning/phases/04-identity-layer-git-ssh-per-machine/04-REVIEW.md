---
phase: 04-identity-layer-git-ssh-per-machine
reviewed: 2026-05-14T22:10:00Z
depth: standard
files_reviewed: 18
files_reviewed_list:
  - docs/MANIFEST.md
  - identity/README.md
  - identity/ssh/cloudflared.zsh
  - identity/ssh/keys/.gitignore
  - identity/ssh/keys/personal.pub
  - identity/ssh/keys/server-1.pub
  - identity/ssh/keys/server-2.pub
  - install/resolver.zsh
  - manifests/defaults.toml
  - manifests/machines/personal-laptop.toml
  - manifests/machines/server-1.toml
  - manifests/machines/server-2.toml
  - manifests/machines/work-laptop.toml
  - manifests/test/fixtures/_invalid-bad-identity/machine.toml
  - manifests/test/fixtures/_invalid-identity-without-opsign/machine.toml
  - manifests/test/fixtures/_invalid-identity-without-opssh/machine.toml
  - taskfiles/identity.yml
  - taskfiles/links.yml
  - taskfiles/manifest.yml
findings:
  critical: 2
  warning: 7
  info: 4
  total: 13
status: issues_found
---

# Phase 04: Code Review Report

**Reviewed:** 2026-05-14T22:10:00Z
**Depth:** standard
**Files Reviewed:** 18 (one duplicate; 18 distinct paths from config)
**Status:** issues_found

## Summary

Phase 04 wires per-machine git+ssh identity through the manifest model. The
resolver's cross-field validation (D-16), atomic-write contract (T-MAN-03),
and path-traversal guard (T-MAN-02) are well-defended, with previous review
fixes (CR-01..CR-03, WR-01..WR-08) clearly traceable in comments.

Two correctness bugs warrant blocking attention. First,
`identity/ssh/cloudflared.zsh` references `$HOMEBREW_PREFIX` under
`set -u` without a fallback or guard; SSH `ProxyCommand` invokes the script
in a non-login subshell where this env var is typically absent, so the
script will abort with `HOMEBREW_PREFIX: unbound variable` rather than
exec'ing cloudflared. Second, the `identity:ssh` task's
`active`-symlink swap (line 217) interpolates
`{{.MANIFEST.identity.ssh}}` directly into the symlink target without
guarding against the empty-`{}` MANIFEST fallback that the same
taskfile's own `MANIFEST_JSON` block deliberately produces; a missing
`resolved.json` therefore creates `~/.ssh/identities/active -> ~/.ssh/identities/<no value>`,
which is silent corruption of the active SSH identity rather than a
loud failure.

The remaining warnings cover placeholder pub-key handling, redundant
guard logic, hardcoded identity values that drift independently of the
identity overlay file, and minor stderr/exit-code asymmetries.

## Critical Issues

### CR-01: cloudflared wrapper aborts under SSH ProxyCommand because $HOMEBREW_PREFIX is unset

**File:** `identity/ssh/cloudflared.zsh:13`

**Issue:** The script enables `set -euo pipefail` and then references
`"$HOMEBREW_PREFIX/bin/cloudflared"`. The `-u` flag turns any unset
variable reference into a hard error. SSH invokes `ProxyCommand` in a
minimal non-login, non-interactive subshell -- the user's shell startup
files are NOT sourced, so `HOMEBREW_PREFIX` (set by `brew shellenv` in
`shell/.zprofile` per the project's startup-order documentation) is not
present. Result: every SSH connection to `*.jgrid.net` / `*.plex.me`
hosts on the personal identity will fail with
`identity/ssh/cloudflared.zsh: HOMEBREW_PREFIX: unbound variable` instead
of exec'ing cloudflared, breaking the personal identity's primary
remote-access path.

The project rule "no hardcoded /opt/homebrew or /usr/local" forbids
hard-coding the prefix, but the same rule says detection MUST happen via
`uname -m` dispatch -- which this script omits.

**Fix:**
```zsh
#!/bin/zsh
# identity/ssh/cloudflared.zsh -- ProxyCommand wrapper for cloudflared tunnels.
# (... existing header ...)

set -euo pipefail

# SSH ProxyCommand subshells do not source .zprofile, so derive the
# Homebrew prefix locally rather than relying on $HOMEBREW_PREFIX being
# exported into the environment.
if [[ -z "${HOMEBREW_PREFIX:-}" ]]; then
  case "$(uname -m)" in
    arm64)  HOMEBREW_PREFIX="/opt/homebrew" ;;
    x86_64) HOMEBREW_PREFIX="/usr/local"    ;;
    *)
      echo "cloudflared.zsh: unknown arch $(uname -m); cannot locate cloudflared" >&2
      exit 1
      ;;
  esac
fi

if [[ ! -x "${HOMEBREW_PREFIX}/bin/cloudflared" ]]; then
  echo "cloudflared.zsh: ${HOMEBREW_PREFIX}/bin/cloudflared not found or not executable" >&2
  exit 1
fi

exec "${HOMEBREW_PREFIX}/bin/cloudflared" "$@"
```

### CR-02: Active-symlink swap silently corrupts when resolved.json is missing

**File:** `taskfiles/identity.yml:216-217` (and status check at line 230)

**Issue:** The `MANIFEST_JSON` var (lines 72-79) deliberately falls back
to `'{}'` when `resolved.json` is missing or empty, emitting only a
stderr warning. The `MANIFEST` ref then evaluates against `{}`, so
`{{.MANIFEST.identity.ssh}}` renders as the literal string `<no value>`
in go-task's output. The `ssh:` task at line 216-217 uses that value
directly as the `SOURCE` of a `_:safe-link` call:

```yaml
- task: _:safe-link
  vars: { SOURCE: "{{.SSH_IDENTITIES_DIR}}/{{.MANIFEST.identity.ssh}}", TARGET: "{{.SSH_IDENTITIES_DIR}}/active" }
```

When the MANIFEST is the empty fallback, this becomes
`SOURCE: "~/.ssh/identities/<no value>"`. `_:safe-link` runs
`ln -sfn "<no value>" "~/.ssh/identities/active"` unconditionally,
overwriting any prior `active` symlink with a broken pointer. The status
block at line 230 also evaluates against `<no value>`, so the corrupted
state appears "fresh" on the next run.

The `validate:symlinks` task (line 250-261) only checks that `active`
exists as a symlink (`test -L`), not that it points to a real
identity file -- the `_:check-link` helper does verify `-e`, but a
later install run that happens with state present then overwrites,
masking the symptom intermittently.

This is the same class of bug that the resolver hard-fails on
(`STATE_FILE` missing -> exit 1 with actionable error). The taskfile
should not permit the install to proceed against an empty MANIFEST.

**Fix:** Add a precondition to `identity:ssh` (and `identity:git`) that
fails loudly when MANIFEST identity values are absent. For example:

```yaml
ssh:
  desc: "Link SSH identity files; swap active symlink to manifest value"
  preconditions:
    - sh: test -s '{{.RESOLVED_JSON_PATH}}'
      msg: |
        resolved.json missing or empty; cannot resolve identity.ssh
          run: task setup -- <machine-name>
    - sh: |
        v='{{.MANIFEST.identity.ssh}}'
        case "$v" in
          personal|work|server-1|server-2|none) exit 0 ;;
          *) exit 1 ;;
        esac
      msg: 'identity.ssh = "{{.MANIFEST.identity.ssh}}" is not a known identity'
  cmds:
    # ... existing cmds ...
```

The `git:` task and `server-include:` task have the same exposure on
`{{.MANIFEST.identity.git}}`; apply the same guard there.

## Warnings

### WR-01: Placeholder pub keys pass the "non-empty" check and would cause confusing ssh-add failures

**File:** `taskfiles/identity.yml:323-330`, `identity/ssh/keys/server-1.pub:1`, `identity/ssh/keys/server-2.pub:1`

**Issue:** `server-1.pub` and `server-2.pub` currently contain a
placeholder comment line:

```
# Replace this file with the contents of id_ed25519_server-1.pub generated at cutover.
```

The `validate:ssh-add` task guards with `if [[ ! -s "$expected_pub" ]]`
(file empty) and warns/skips. Placeholder files are NOT empty, so the
guard does not catch them. `awk '{print $2}'` on the placeholder line
extracts the literal string `Replace`, which is non-empty (so the
second guard at line 328 also passes), and the script proceeds to
`ssh-add -L | grep -qF "Replace"` -- which will spuriously match if any
real pub key in the agent contains the substring `Replace` (unlikely
but possible) or, more typically, mismatch and exit 1 with a
misleading "ssh-add -L does not include expected pub key" message.

Today this is dormant because no machine sets `one-password-ssh = true`
with `identity.ssh = "server-1"` -- but the cross-field rule does not
forbid that combination, and the placeholder will outlive Phase 04
(IDNT-07 awaits operator cutover per commit `9862b3d`).

**Fix:** Detect the placeholder shape explicitly and skip with a clear
message:

```bash
# Reject placeholder content: a real pub key starts with one of the SSH
# key-type identifiers, never with `#`.
case "$(head -n1 "$expected_pub")" in
  ssh-ed25519*|ssh-rsa*|ecdsa-*|sk-*) ;;
  *)
    warn "$expected_pub is a placeholder, not a real public key -- skipping"
    exit 0
    ;;
esac
expected_body=$(awk '$1 ~ /^(ssh-|ecdsa-|sk-)/ {print $2; exit}' "$expected_pub")
```

### WR-02: cloudflared.zsh has no executable bit / no callsite verification

**File:** `identity/ssh/cloudflared.zsh` (mode), `taskfiles/identity.yml:212-213`

**Issue:** `taskfiles/identity.yml:212-213` symlinks the script into
`~/.ssh/identities/cloudflared.zsh`. SSH's `ProxyCommand` directive
typically invokes the value with `/bin/sh -c <value>`, so the script
does not need `+x` for that call path -- but if any caller invokes it
directly (testing, alternate ProxyCommand syntax, future Linux port),
the missing executable bit becomes a silent break. The repo file has
`-rw-r--r--` per `ls -l identity/ssh/keys/` (the cloudflared.zsh file
inherits mode from git).

This is a robustness issue, not a correctness bug for the documented
ProxyCommand usage, but flagging because the script's own header
documents "exec replaces this shell process" -- implying a direct exec
contract.

**Fix:** Either add an explicit `chmod +x` step in the install task, or
document that cloudflared.zsh is invoked exclusively via
`ProxyCommand <path>` (which SSH wraps in `/bin/sh -c`). The lighter
option:

```bash
# Add to the file in git:
chmod +x identity/ssh/cloudflared.zsh
git update-index --chmod=+x identity/ssh/cloudflared.zsh
```

### WR-03: Hardcoded josh@vaughen.net in validate:git drifts from identity overlay file

**File:** `taskfiles/identity.yml:272-275`

**Issue:** The `personal` branch hardcodes `expected_email="josh@vaughen.net"`
inline, while the `work` branch correctly reads the value from the
identity overlay file via `git config -f .../identities/work user.email`.
The two paths drift: any future edit to
`identity/git/identities/personal` (e.g., changing
`email = josh@vaughen.net` to a different address) is silently NOT
checked because the validator carries its own private constant.

This defeats the validator's stated purpose ("git config user.email
matches manifest identity"). For the work identity, a drift would be
caught; for personal, it would not.

**Fix:** Read both from the overlay file with the same pattern:

```bash
case "$identity" in
  personal)
    gitdir="$HOME/git/personal"
    expected_email=$(git config -f "{{.DOTFILEDIR}}/identity/git/identities/personal" user.email 2>/dev/null || echo "")
    ;;
  work)
    gitdir="$HOME/git/work"
    expected_email=$(git config -f "{{.DOTFILEDIR}}/identity/git/identities/work" user.email 2>/dev/null || echo "")
    ;;
  server-1|server-2)
    gitdir="$HOME"
    expected_email=$(git config -f "{{.DOTFILEDIR}}/identity/git/identities/${identity}" user.email 2>/dev/null || echo "")
    ;;
  ...
```

The server branches presently hardcode `${identity}@jgrid.net` -- same
drift exposure; same fix.

### WR-04: validate:git skip-when-gitdir-absent guard has dead-code branches

**File:** `taskfiles/identity.yml:297`

**Issue:**

```bash
if [[ ! -d "$gitdir" ]] && [[ "$identity" != "server-1" ]] && [[ "$identity" != "server-2" ]]; then
  info "gitdir $gitdir absent -- skipping email assertion"
  exit 0
fi
```

For `identity in {server-1, server-2}`, the `gitdir` is set to `$HOME`
(line 281), which always exists -- so `[[ ! -d "$gitdir" ]]` is always
false on those branches and the second/third clauses are unreachable.
For other identities (`personal`, `work`), the second/third clauses are
trivially true. The guard reduces to `[[ ! -d "$gitdir" ]]` for non-server
identities and unreachable for server identities. The intent is correct
but the expression is misleading: a future reviewer trying to add a
`server-3` identity would have to figure out the meaning of these
clauses.

**Fix:** Simplify to a single conditional that documents intent:

```bash
# For workstation identities, skipping the assertion when the gitdir
# is absent is expected (e.g., a fresh checkout where ~/git/personal
# has not been created). Server identities key off $HOME, which
# always exists, so they bypass this guard.
case "$identity" in
  server-1|server-2) ;;
  *)
    if [[ ! -d "$gitdir" ]]; then
      info "gitdir $gitdir absent -- skipping email assertion"
      exit 0
    fi
    ;;
esac
```

### WR-05: validate:keys does not detect private keys in subdirectories

**File:** `taskfiles/identity.yml:346`

**Issue:**

```bash
bad=$(find "{{.DOTFILEDIR}}/identity/ssh/keys" -maxdepth 1 -type f -not -name '*.pub' -not -name '.gitignore' 2>/dev/null)
```

The `-maxdepth 1` flag confines the search to the top level of
`identity/ssh/keys/`. A private key placed in a subdirectory (e.g.,
`identity/ssh/keys/personal/id_ed25519`) would NOT be flagged. While
the `.gitignore` `*` rule does block subdirectory contents from being
committed, the validate task is the runtime defense in depth -- the
README explicitly cites IDNT-06 ("private keys NEVER enter the repo")
as the validate:keys responsibility. A defense that the layered
.gitignore could be modified out from under should not silently shrink
to "top-level only" at the validate layer.

**Fix:**

```bash
bad=$(find "{{.DOTFILEDIR}}/identity/ssh/keys" -type f -not -name '*.pub' -not -name '.gitignore' 2>/dev/null)
```

Drop `-maxdepth 1`. If the project intent is "no subdirectories
allowed", add a separate check that flags any directory under keys/.

### WR-06: validate:ssh-add awk extraction is brittle for multi-field key bodies

**File:** `taskfiles/identity.yml:327, 332`

**Issue:** `awk '{print $2}'` extracts the second whitespace-delimited
field. For a typical pub key file that contains exactly one line like
`ssh-ed25519 AAAAC3...keybody... user@host`, this works. But:

1. If the file contains a leading comment line plus the key on line 2,
   `awk '{print $2}'` runs against ALL lines and prints the 2nd field
   of EACH line. The `grep -qF "$expected_body"` then searches for a
   newline-containing string against `ssh-add -L` output, which uses
   `grep -F` (literal, no special chars) but NOT multi-line aware --
   `grep -qF` would search line-by-line for the multi-line pattern,
   which fails.
2. If the pub key is missing the comment field (`ssh-ed25519 KEYBODY`
   only -- valid), $2 still extracts KEYBODY correctly.

**Fix:** Restrict to the first valid key line:

```bash
expected_body=$(awk '$1 ~ /^(ssh-|ecdsa-|sk-)/ {print $2; exit}' "$expected_pub")
```

The `exit` after the first match guarantees a single value; the regex
anchor on $1 ensures we only consume real key lines, not comments.

### WR-07: server-include task does not idempotently rewrite stale path under correct identity

**File:** `taskfiles/identity.yml:158-184`

**Issue:** The status block at line 175-184 checks
`grep -q "identities/{{.MANIFEST.identity.git}}" "{{.SERVER_INCLUDE_CONFIG}}"`
which passes if the file mentions the current identity ANYWHERE (e.g.,
in a comment, in a different `path =` line, in a stale block). If the
file was previously written for `server-1` and the manifest changes to
`server-2`, the `grep -q` for `identities/server-2` correctly fails and
the cmd re-runs -- OK. But if the file contains BOTH lines (e.g., due
to a previous bug that appended rather than overwrote), the status
check passes and the cmd does not re-run, leaving stale content.

The cmd uses `>` (truncate) so a single-line write is correct. But the
status check could be tightened to validate exact content (line count
== 2, exact second line matches the expected `path = identities/<id>`).

**Fix (defensive):**

```bash
status:
  - |
    case "{{.MANIFEST.identity.git}}" in
      server-1|server-2)
        test -f "{{.SERVER_INCLUDE_CONFIG}}" || exit 1
        # exact-match: file must contain exactly the two expected lines
        diff <(printf '[includeIf "gitdir:~/"]\n    path = identities/%s\n' "{{.MANIFEST.identity.git}}") "{{.SERVER_INCLUDE_CONFIG}}" >/dev/null
        ;;
      *)
        test ! -f "{{.SERVER_INCLUDE_CONFIG}}"
        ;;
    esac
```

## Info

### IN-01: Mixed identity-validation rules: server identities not enforced for one-password-ssh

**File:** `install/resolver.zsh:220-227`, `manifests/defaults.toml:26`

**Issue:** The cross-field rule (D-16) at lines 220-227 only requires
`one-password-ssh = true` when `identity.ssh in {personal, work}`. For
server identities the rule is intentionally silent because servers do
not run 1Password. This is correct per the design but is not documented
in `defaults.toml` where the future maintainer reads
`one-password-ssh = false  # gates ...`. Add a comment indicating the
asymmetry.

**Fix:** Annotate `manifests/defaults.toml:26-27`:

```toml
# Cross-field rule (D-16): identity.ssh in {personal, work} REQUIRES this
# to be true; identity.ssh in {server-1, server-2, none} does not.
one-password-ssh = false
# Cross-field rule (D-16): identity.git in {personal, work} REQUIRES this
# to be true; identity.git in {server-1, server-2, none} does not.
one-password-signing = false
```

### IN-02: emit_unknown_key_warnings line-number heuristic produces false-positive lookups

**File:** `install/resolver.zsh:288-295`

**Issue:** The grep heuristic searches `^${leaf}[[:space:]]*=` against
the entire file. If the same key name (`bundles`, `name`, `description`)
appears in multiple TOML tables, the grep returns the FIRST occurrence,
which may not be the one that triggered the warning. The phase-04
manifests do not currently exercise this (each leaf name is unique),
but `description` would collide with `meta.description` if a future
table added another `description` field.

**Fix:** Either accept the imprecision (the docs at line 414 already
acknowledge it -- "Line numbers in unknown-key warnings may be
imprecise for deeply nested keys"), or use yq's column/line tracking
where available. No code change required; this is informational.

### IN-03: AVAILABLE_MACHINES var pollutes preconditions output with negative-fixture filenames during manifest:test

**File:** `taskfiles/manifest.yml:96-97`, `taskfiles/manifest.yml:362, 380, 397, 414, 431`

**Issue:** `manifest:test` copies `_invalid-*` fixtures into
`manifests/machines/` and removes them after each fixture runs. The
EXIT trap (CR-01 fix) cleans up on signal. However, between the `cp`
and the `rm`, any concurrent `task setup -- <name>` invocation that
shells out to `AVAILABLE_MACHINES` would see the temporary
`_invalid-*` entries. This is a narrow race -- `task` invocations are
typically serial by user -- and the underscore prefix is a clear
"do not touch" marker, but worth noting in case CI parallelism is
introduced.

**Fix:** None required for v1. Documented for future awareness.

### IN-04: README links Phase 8 / DOCS-08 for cutover, but cutover doc not yet present

**File:** `identity/ssh/keys/server-1.pub:1`, `identity/ssh/keys/server-2.pub:1`, `identity/README.md` (transitively)

**Issue:** The placeholder pub keys reference `docs/CUTOVER.md (Phase 8,
DOCS-08)`. That file is a phase-8 deliverable. Until it lands, an
operator who reads the placeholder for guidance has no destination. Not
a code defect; flagged so that the phase-8 owner picks it up.

**Fix:** No action needed in phase 04. Track in phase-8 backlog.

---

_Reviewed: 2026-05-14T22:10:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
