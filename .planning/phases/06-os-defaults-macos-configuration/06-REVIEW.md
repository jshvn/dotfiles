---
phase: 06
slug: os-defaults-macos-configuration
reviewer: gsd-code-reviewer
review_depth: standard
status: warnings
files_reviewed: 11
critical_count: 0
warning_count: 6
info_count: 7
created: 2026-05-15
---

# Phase 06 Code Review

## Summary

Reviewed all 11 source files for Phase 6 (`os-defaults-macos-configuration`). The phase
ships its keystone deliverable cleanly: the v1 `macos:shell:145` `$BREW_ZSH`-in-status
bug class is structurally closed by the combination of `taskfiles/macos.yml`'s
`{{.BREW_ZSH}}` template-var usage in `tasks.shell.status` and
`os/shell-registration.zsh`'s `: "${BREW_ZSH:?...}"` script-side assertion. Tuple-array
shape across the five concern scripts is consistent, the `set -u`-safe `messages.zsh`
prelude is uniformly applied, and the manifest-schema changes are minimal and
well-commented.

Headline issues to address before they bite in production:

- **WR-01 / WR-02 (likely correctness bug):** The `sysadminctl -guestAccount` grep gates
  in `os/defaults/security.zsh` rely on literal lowercase "enabled" / "disabled" matches
  against tool output whose format and capitalization vary across macOS versions. On a
  machine where the output is "Enabled = true" / "Enabled = false" (or the unprivileged
  call prints "Permission denied"), `apply_security` silently no-ops while
  `verify_security` reports a permanent cross — apply / verify disagree.
- **WR-03 (LINT-02 spirit):** `taskfiles/macos.yml:234` keeps a `$USER` shell-var inside
  a `status:` block. The LINT-02 regex skips the line because it also contains `{{.BREW_ZSH}}`,
  so this is a latent reintroduction of the exact bug class this phase exists to close.
- **WR-04 (code injection vector):** `${(e)value}` in `screenshots.zsh` runs full
  parameter / command substitution on tuple values. Safe today because the array is
  hardcoded; it becomes a code-exec sink the moment the tuple is ever populated from
  external data.

No Critical findings. The remaining items are minor / quality / documentation.

## Critical

None.

## Warnings

### WR-01: `sysadminctl -guestAccount status` parse is fragile and case-sensitive

- **File:** `os/defaults/security.zsh:104`
- **Code:**
  ```zsh
  if sysadminctl -guestAccount status 2>&1 | grep -q "enabled"; then
    warn "Guest account is enabled. Disabling it now (sudo required)..."
    sudo sysadminctl -guestAccount off
  fi
  ```
- **Why it matters:** `sysadminctl -guestAccount status` output varies by macOS version
  and is generally case-titled (e.g. `Enabled = true`, `Enabled: Yes`, or
  `Guest account is enabled.`). The lowercase substring `enabled` may or may not match.
  On the unprivileged path Apple sometimes returns a permission notice with no
  `enabled` token at all. In all of those cases, `apply_security` silently treats the
  account as "not enabled" and skips the `sudo` call — security drift goes unnoticed.
- **Fix:** Anchor to the actual boolean. One option:
  ```zsh
  local guest_status
  guest_status=$(sysadminctl -guestAccount status 2>&1 || true)
  if printf '%s' "$guest_status" | grep -qiE 'enabled[[:space:]]*[:=][[:space:]]*(true|yes|1)|is[[:space:]]+enabled\b'; then
    warn "Guest account is enabled. Disabling it now (sudo required)..."
    sudo sysadminctl -guestAccount off
  fi
  ```
  Add an explicit fallback branch (`else` log a `debug "guest-account status: $guest_status"`)
  so the parsed string is captured for future review.

### WR-02: Apply / verify disagree on guest-account state when neither grep matches

- **File:** `os/defaults/security.zsh:150-155` (paired with WR-01)
- **Code:**
  ```zsh
  if sysadminctl -guestAccount status 2>&1 | grep -q "disabled"; then
    check "security.guest-account = disabled"
  else
    cross "security.guest-account: expected 'disabled', got 'enabled'"
    failed=1
  fi
  ```
- **Why it matters:** `apply_security` keys off the literal `enabled` token; `verify_security`
  keys off the literal `disabled` token. When `sysadminctl` outputs `Enabled = false`
  (which contains neither token), apply correctly does nothing — but verify reports
  `cross "...got 'enabled'"` even though the account is in fact disabled. The cross
  message is also misleading: it labels the actual state as `enabled` based on the
  absence of a `disabled` substring, not on a positive detection.
- **Fix:** Use the same robust parser introduced in WR-01 for both apply and verify, and
  surface the raw output in the cross message:
  ```zsh
  local guest_status
  guest_status=$(sysadminctl -guestAccount status 2>&1 || true)
  if printf '%s' "$guest_status" | grep -qiE 'enabled[[:space:]]*[:=][[:space:]]*(false|no|0)|is[[:space:]]+disabled\b'; then
    check "security.guest-account = disabled"
  else
    cross "security.guest-account: expected 'disabled', raw='$guest_status'"
    failed=1
  fi
  ```

### WR-03: `$USER` shell-var inside `tasks.shell.status` — latent LINT-02 regression

- **File:** `taskfiles/macos.yml:234`
- **Code:**
  ```yaml
  status:
    - grep -qxF "{{.BREW_ZSH}}" /etc/shells
    - '[[ "$(dscl . -read /Users/$USER UserShell 2>/dev/null | awk "{print \$2}")" = "{{.BREW_ZSH}}" ]]'
  ```
- **Why it matters:** This phase exists to close the "shell vars in `status:`" bug
  class. The LINT-02 regex at `taskfiles/lint.yml:144-147` filters out any line
  containing `{{`, so a line that *also* references `{{.BREW_ZSH}}` is exempted —
  even if it carries a `$USER` shell-var. That is exactly how the v1
  `$BREW_ZSH`-in-status bug would be re-introduced: a `$VAR` sneaking through under
  a `{{.OTHER_VAR}}` cover. `$USER` is conventionally exported by login shells but go-task's
  status-eval shell inherits whatever the invoker's env supplies; in cron / launchd /
  CI contexts `$USER` may be empty, which silently makes the test compare against
  `"/Users/ UserShell"` and never matches.
- **Fix:** Hoist the username into a task-level `vars:` entry alongside `BREW_ZSH` and
  use the template var:
  ```yaml
  shell:
    vars:
      BREW_ZSH: '{{.HOMEBREW_PREFIX}}/bin/zsh'
      USER_NAME:
        sh: id -un
    ...
    status:
      - grep -qxF "{{.BREW_ZSH}}" /etc/shells
      - '[[ "$(dscl . -read /Users/{{.USER_NAME}} UserShell 2>/dev/null | awk ''{print $2}'')" = "{{.BREW_ZSH}}" ]]'
  ```
  The awk argument is single-quoted in YAML (`''` escapes) so the inner `$2` no longer
  needs the `\$2` escape dance and there is no risk of a shell-var slipping in.

### WR-04: `${(e)value}` is full expansion — code-exec sink if tuple ever becomes data-driven

- **File:** `os/defaults/screenshots.zsh:73, 88`
- **Code:**
  ```zsh
  expanded="${(e)value}"
  ```
- **Why it matters:** zsh's `(e)` parameter-expansion flag performs parameter
  expansion, **command substitution, and arithmetic** on the value. Today the tuple
  array is a hardcoded literal, so the only thing it ever expands is `$HOME` — safe.
  But this script is the template every future concern will be copied from; the
  moment a future contributor sources tuple values from a manifest entry, a TOML
  string, or any environment-influenced source, `${(e)value}` will execute
  `$(curl evil)` / `${$(rm -rf $HOME)}` and similar payloads.
- **Fix:** Use the much narrower substitution flag that only expands parameters, not
  command-substitution / arithmetic. A safe and self-documenting alternative is
  explicit `${value/\$HOME/$HOME}`:
  ```zsh
  expanded="${value/\$HOME/$HOME}"
  ```
  or, if you want to keep the generic shape, replace `(e)` with a parameter-only
  expansion such as `${~value}` (glob expansion only — still safer than `(e)`) plus
  an inline `case` for the `$HOME` token. Add a comment explaining why `(e)` is
  banned so future concerns do not copy the unsafe idiom.

### WR-05: `dscl` username argument is unquoted in three call sites

- **File:** `os/shell-registration.zsh:80, 95`; `taskfiles/macos.yml:234`
- **Code:**
  ```zsh
  current_shell=$(dscl . -read /Users/$USER UserShell 2>/dev/null | head -n 1 | awk '{print $2}')
  ```
- **Why it matters:** `$USER` is interpolated into a path without quoting. On macOS
  the value is almost always safe, but a username with whitespace or `$IFS`
  metacharacters (allowed by `useradd` on the underlying BSD layer) would cause the
  `dscl` argument to split into multiple tokens, producing
  `dscl . -read /Users/first second UserShell` and a misleading "record not found"
  error. The `verify_shell_registration` cross message would then report the wrong
  current shell. Couple this with WR-03: the fix for WR-03 also fixes this one when
  the username comes from a `vars: { sh: id -un }` entry.
- **Fix:** Quote the path. In the script:
  ```zsh
  current_shell=$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | head -n 1 | awk '{print $2}')
  ```
  In the taskfile, prefer the `{{.USER_NAME}}` template-var approach from WR-03.

### WR-06: `apply_security` runs `sudo sysadminctl -guestAccount off` without `set -e` failure handling

- **File:** `os/defaults/security.zsh:106`
- **Code:**
  ```zsh
  if sysadminctl -guestAccount status 2>&1 | grep -q "enabled"; then
    warn "Guest account is enabled. Disabling it now (sudo required)..."
    sudo sysadminctl -guestAccount off
  fi
  ```
- **Why it matters:** Script-level `set -euo pipefail` is in effect. If `sudo` is
  refused (TTY-less environment, sudoers policy denies, user aborts the password
  prompt) `sudo sysadminctl -guestAccount off` returns non-zero and the script
  aborts mid-apply — without a clear error message naming what went wrong. Because
  this is the last apply step, any subsequent ordering issue inherits the same
  failure mode. The current `warn "...sudo required..."` text helps but is printed
  *before* the failure, so the user sees the warn but no follow-up `error` telling
  them what to do next.
- **Fix:** Capture the failure explicitly so the user sees an actionable error:
  ```zsh
  if ! sudo sysadminctl -guestAccount off; then
    error "Failed to disable guest account; run manually: sudo sysadminctl -guestAccount off"
    return 1
  fi
  ```
  (`return 1` rather than `exit 1` because this is a sourced function — `exit` would
  exit the calling `zsh -c` subshell, which is currently fine but couples the script
  to the caller shape.)

## Info

### IN-01: `taskfiles/macos.yml:59` redefines `HOME: '{{.HOME}}'` redundantly

- **File:** `taskfiles/macos.yml:59`
- **Issue:** `HOME` is already established by the root `Taskfile.yml:35`; the local
  re-declaration in the included taskfile's `vars:` block is redundant under the
  "root vars win on include merge" behavior the rest of the file relies on
  (see comments at lines 45-47).
- **Fix:** Drop the line; rely on the root forward.

### IN-02: Inconsistent `dscl` parse between script and taskfile

- **File:** `os/shell-registration.zsh:80, 95` vs `taskfiles/macos.yml:234`
- **Issue:** The script uses `dscl ... | head -n 1 | awk '{print $2}'` (the `head -n 1`
  is documented as "cheap insurance against future dscl output variance"). The
  taskfile's `status:` runs only `dscl ... | awk "{print \$2}"` with no `head -n 1`.
  If dscl ever emits multiple lines, the two parsers disagree — apply may not match
  status. Pick one shape and use it in both places (preferably the safer one with
  `head -n 1`).
- **Fix:** Add `| head -n 1` to the taskfile status command, or pull the dscl-parse
  into a tiny helper function in `os/shell-registration.zsh` (e.g.
  `get_current_login_shell`) and call it from both places. Folded together with the
  WR-03 / WR-05 fixes this becomes a one-liner change.

### IN-03: Five concern scripts duplicate the apply/verify loop body

- **File:** `os/defaults/{dock,finder,input,screenshots,security}.zsh`
- **Issue:** Each concern reimplements an almost-identical 4-tuple iterator (`for ((i = 1;
  i <= ${#ARR[@]}; i += 4)); do ... defaults write "$domain" "$key" "-$type" "$value"; done`)
  plus the same `case "$type"` bool-normalization in verify. Five files, four are
  essentially template-instantiated copies. Today's footprint is small (~30 lines per
  file). Once `preferences.zsh` and `appearance.zsh` land (named as future work in
  the summaries), the duplication multiplies.
- **Fix:** Extract `os/defaults/_lib.zsh` with `_apply_tuples ARR_NAME` and
  `_verify_tuples ARR_NAME CONCERN_LABEL` helpers; have each concern source it via
  the same `set -u`-safe prelude pattern. The `-currentHost` variant in
  `security.zsh` can take a `--scope=currentHost` flag.

### IN-04: `verify_security` cross message says "got 'enabled'" without actually checking

- **File:** `os/defaults/security.zsh:153`
- **Issue:** `cross "security.guest-account: expected 'disabled', got 'enabled'"` is a
  hard-coded literal; the script never confirms the state is actually `enabled`. It
  may be `unknown`, `permission-denied`, or anything else (see WR-02). Misleading
  diagnostics make field debugging slower.
- **Fix:** Capture and print the actual output (`raw='$guest_status'`). Already folded
  into the WR-02 patch above.

### IN-05: Status-block one-liner formatting is hard to scan

- **File:** `taskfiles/macos.yml:147-152, 161-166, 175-180, 189-194, 203-208`
- **Issue:** Every `cmds:`/`status:` block embeds a long
  `DOTFILEDIR={{.DOTFILEDIR}} zsh -c 'set -euo pipefail; source ...; ...'` invocation
  on a single line. They are correct but visually noisy; a future maintainer
  reading a diff will skim past a subtle change inside the single-quoted string.
- **Fix:** Either break into multiple physical lines via YAML literal-block-scalar
  pipes (`|`) within the `'...'` body, or hoist the heredoc body into a `vars:`
  block at the file level (`APPLY_BODY: ...` / `VERIFY_BODY: ...`) and reference it
  via `{{.APPLY_BODY}}`. Both keep the single-shell-block status contract intact.

### IN-06: Aggregator task `defaults` carries `deps: [":manifest:resolve"]` that every sub-task also carries

- **File:** `taskfiles/macos.yml:118-132` + each `defaults:<concern>:` definition
- **Issue:** Each `macos:defaults:<concern>` task declares `deps: [":manifest:resolve"]`,
  and the aggregator `macos:defaults` also declares it. go-task dedupes by name and
  run-once contract, so it is not a correctness issue — but the duplication invites
  drift (e.g. someone removes the dep from the aggregator and the precondition
  check at line 122-126 then becomes the only guard).
- **Fix:** Either remove the dep from the per-concern tasks (relying on the
  aggregator) and keep it on the aggregator only, or remove it from the aggregator
  and keep it on the sub-tasks. Document the choice in the file header so future
  contributors do not re-add it.

### IN-07: `taskfile.yml:31` line break inside the `set:` directive comment block leaves an outdated `update:` block reference

- **File:** `Taskfile.yml:111-112`
- **Issue:** Comment reads `# Note: task install IS task update -- D-10 dropped the
  update: block. / # Phase 3 ships shell alias 'update=task install' for muscle
  memory.` This is fine for Phase 3 context but does not document the new `macos:*`
  tasks. Minor doc miss; the rest of the file does call out Phase 6.
- **Fix:** Optional — add a short line under the `tasks:` header noting that the
  install pipeline now includes `task: macos:defaults` and `task: macos:shell`
  (already present at lines 143-144 of the install task; no code change needed).

## Files Reviewed

- `manifests/defaults.toml` — clean. Four new kebab-case `macos-*` keys default
  `false`; `macos-finder` dual-consumer note recorded. No issues.
- `manifests/machines/server-1.toml` — clean. `macos-security = true` per D-04 with
  the deliberate-absence comment naming the four inherited-false keys.
- `manifests/machines/server-2.toml` — clean. Identical to server-1.
- `os/defaults/dock.zsh` — clean. Tuple-array shape correct; killall guarded with
  `|| true`; bool round-trip normalization correct.
- `os/defaults/finder.zsh` — clean. Same shape as dock.zsh; dropped v1 PlistBuddy
  block documented in the header.
- `os/defaults/input.zsh` — clean. One-key starter; no killall (correct — keyboard
  keys take effect at next login).
- `os/defaults/screenshots.zsh` — **WR-04** (code-exec sink in `${(e)value}`); apply
  / verify shape otherwise correct; `mkdir -p` before `defaults write` correct per
  Pitfall 14.
- `os/defaults/security.zsh` — **WR-01, WR-02, WR-06, IN-04** (sysadminctl parse
  fragility, apply/verify disagree, sudo-failure messaging, misleading diagnostics).
  Dual-array global / currentHost split correct.
- `os/shell-registration.zsh` — **WR-05** (`$USER` unquoted in dscl path).
  `:?` assertion on BREW_ZSH correct; /etc/shells append before chsh order correct.
- `taskfiles/macos.yml` — **WR-03** (`$USER` in status: block under LINT-02
  exemption), **IN-01, IN-02, IN-05, IN-06**. Eight tasks per plan; aggregator
  pattern correct; `{{.BREW_ZSH}}` template var properly closes the v1 bug class
  on the producer side.
- `Taskfile.yml` — clean. Include flip from `macos-stub.yml` to `macos.yml`
  documented; root vars forward correctly.
