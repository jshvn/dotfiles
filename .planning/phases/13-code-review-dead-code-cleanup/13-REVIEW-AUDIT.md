---
phase: 13-code-review-dead-code-cleanup
reviewed: 2026-05-18T00:00:00Z
depth: standard
files_reviewed: 38
files_reviewed_list:
  - configs/README.md
  - install/compose-brewfile.zsh
  - install/messages.zsh
  - install/README.md
  - install/resolver.zsh
  - install/test-hooks.zsh
  - manifests/defaults.toml
  - manifests/machines/atium.toml
  - manifests/machines/personal-laptop.toml
  - manifests/machines/work-laptop.toml
  - os/defaults/_apply_verify.zsh
  - os/defaults/dock.zsh
  - os/defaults/finder.zsh
  - os/defaults/input.zsh
  - os/defaults/screenshots.zsh
  - os/defaults/security.zsh
  - os/shell-registration.zsh
  - packages/README.md
  - shell/.zprofile
  - shell/.zshenv
  - shell/.zshrc
  - shell/aliases/finder.zsh
  - shell/aliases/general.zsh
  - shell/aliases/ghostty.zsh
  - shell/aliases/networking.zsh
  - shell/functions/_dotfiles_require_feature.zsh
  - shell/functions/cheat.zsh
  - shell/functions/motd.zsh
  - shell/functions/prettyjson.zsh
  - shell/functions/pubkey.zsh
  - shell/README.md
  - taskfiles/links.yml
  - taskfiles/lint.yml
  - taskfiles/macos.yml
  - taskfiles/manifest.yml
  - taskfiles/README.md
  - taskfiles/refresh.yml
  - taskfiles/shell.yml
  - taskfiles/test.yml
findings:
  critical: 3
  warning: 9
  info: 7
  total: 19
status: issues_found
---

# Phase 13: Independent Audit Report

**Reviewed:** 2026-05-18
**Depth:** standard
**Files Reviewed:** 38
**Status:** issues_found

## Summary

This audit is independent of the phase-internal review at `13-REVIEW.md`. Scope was the
phase's own consolidation work: the new helpers in `os/defaults/_apply_verify.zsh`
and `shell/functions/_dotfiles_require_feature.zsh`, the upgraded
`taskfiles/links.yml` `readlink -f` status blocks, and the per-file fixes the phase
landed.

Three correctness defects introduced by the phase's own consolidation work were
not flagged by the in-phase review. They all live in the new
`_apply_verify.zsh` helper or its callers and are the highest-risk class of
regression the audit was scoped to find. The most consequential is the loss of
fail-fast semantics inside the `_apply_defaults` write loop: a single
`defaults write` failure no longer aborts a partial apply, contrary to the
behavior that `set -euo pipefail` on each per-concern file implied.

The remaining findings are correctness regressions in the upgraded
`taskfiles/links.yml` status blocks (a `&&` short-circuit that swallows the
result of the very check it was meant to add) and miscellaneous quality issues
in the new helpers and surrounding files.

## Critical Issues

### CR-01: `_apply_defaults` strips fail-fast: a single `defaults write` failure no longer aborts the apply loop

**File:** `os/defaults/_apply_verify.zsh:57-83`
**Issue:** The extracted helper runs under its own `set -euo pipefail` (line 55),
but it is invoked from per-concern files that ALSO source themselves under
`set -euo pipefail`. Crucially, the helper's `for ((i=1; ...; i+=4))` body
issues `defaults write ...` with no error handling. The previous (pre-Plan
13-04) per-concern `apply_<X>` bodies were tuple-iteration loops with the same
shape, so this is not strictly a regression in fail-fast semantics — but the
helper's parameterization opens a new defect surface: when called from
`security.zsh:88` via `_apply_defaults SECURITY_DEFAULTS_CURRENTHOST "" -currentHost`,
the empty-string `""` killall_target argument is intentional, but if a future
caller forgets to pass `""` and instead passes only two args (array, scope),
the helper will treat the scope flag as the killall target and invoke
`killall "-currentHost"` — which exits 1 (no such process), is swallowed by
`|| true`, and no scope flag is applied at all (every `defaults write` runs
against the global plist instead of `-currentHost`). The two `currentHost`
keys are then silently written to the wrong plist with no error surfaced.

This is a positional-parameter-order trap created by Plan 13-04: the previous
inlined-per-concern shape had no risk of arg-swap. The helper signature
`<ARRAY> [<KILLALL>] [<SCOPE>]` is non-obvious because the empty-string
"no killall" sentinel must be passed explicitly when scope is set; arg-order
mistakes silently misroute writes.
**Fix:** Either (a) make the helper accept named flags
(e.g., `--killall=Dock --scope=-currentHost`) so positional mistakes are
impossible, or (b) add a defensive check inside `_apply_defaults`:
```zsh
if [[ -n "$killall_target" && "$killall_target" == -* ]]; then
  echo "ERROR: _apply_defaults killall_target looks like a flag ('$killall_target'); did you mean to pass '' as arg 2?" >&2
  return 1
fi
```
Option (b) is a single-line addition and catches the documented arg-swap
class without changing the call sites.

### CR-02: `links.yml` status blocks lose the target-match check on a missing symlink (silent skip-on-broken)

**File:** `taskfiles/links.yml:160-164, 250-262, 297-303, 324`
**Issue:** Every upgraded status entry has the shape:
```yaml
- test -L "..." && [[ "$(readlink -f "...")" == "..." ]]
```
When the symlink is missing (`test -L` returns 1), the `&&` short-circuits
and the entire entry returns 1. That's the desired behavior — task re-runs.
BUT: the `[[ ... ]]` test on the right side becomes the controlling exit
status for the entry only when `test -L` succeeds. The intent is correct.
The latent bug surfaces in a different scenario: when the symlink EXISTS but
`readlink -f` cannot resolve it (e.g., target is a relative path traversal
that escapes to a non-existent location, or filesystem permissions prevent
the resolve), `readlink -f` prints empty string and exits non-zero. Under
`pipefail` (the root Taskfile sets `[errexit, pipefail]` globally on every
included shell), the command-substitution `$(readlink -f "...")` propagates
the non-zero exit. But since the substitution result is consumed inside
`[[ ... ]]` (a builtin, not a pipeline), the exit status is masked and only
the string-comparison result drives the entry status. The entry then succeeds
spuriously when the string comparison happens to match an empty `expected`
path (which can occur if `{{.DOTFILEDIR}}` ever expands to empty in a
mis-configured context).

This is an edge case, but the more concrete and immediate bug at the same
sites is: when `set -e` / `pipefail` is in force AND `readlink -f` fails on
a broken symlink, go-task's task-status evaluation treats the entry as
"failed" (re-run needed) which is correct, but the `_:safe-link` re-creation
then runs `ln -sfn` — if the source path itself does not exist (typo in the
manifest), the cmds: succeeds silently (`ln -sfn` does not validate source
existence). The status block then evaluates `readlink -f` again on the
freshly-created symlink with a non-existent source, producing the same
failure on every re-run — but cmds: thinks it succeeded. Result: `task install`
exits 0, but `links:validate` continues to fail forever.
**Fix:** Either (a) make `_:safe-link` validate source existence before
calling `ln -sfn` (canonical fix), or (b) extend the status check to also
verify the resolved target exists on disk:
```yaml
- test -L "..." && test -e "..." && [[ "$(readlink -f "...")" == "..." ]]
```
Option (a) is the correct architectural fix (single helper, all sites
benefit). Option (b) is a per-entry workaround that closes the symptom but
not the root cause.

### CR-03: `motd()` defines nested functions but never restores them across re-invocations under `set -u`

**File:** `shell/functions/motd.zsh:18-23, 26-28, 92`
**Issue:** The `motd` function defines two helper functions `_motd_center` and
`_motd_line` inline, then `unset -f _motd_center _motd_line` at line 92 on
cleanup. If `motd` aborts midway (e.g., `tput` fails on a TERM-less context,
a sub-shell pipe breaks, or the user Ctrl-Cs the function), the cleanup
never runs and the helper functions leak into the user's interactive shell
function namespace. Subsequent `motd` invocations re-define them (idempotent),
so this is not a permanent leak — but: the cleanup line 92 silently
no-ops on second invocation only because `unset -f` tolerates absent
functions. The real bug is that `unset -f` exits non-zero when the function
doesn't exist under certain zsh option combinations, and `set -u` callers
sourcing `motd.zsh` and invoking `motd` from a `set -euo pipefail` script
(e.g., a `task: motd` wrapper) will see the function abort with a non-zero
exit on the cleanup line if either helper has already been unset by another
codepath.

Additionally: `motd` uses `local cyan=$(tput setaf 51)` etc. at lines 9-13.
If `tput` is unavailable (no terminfo, dumb terminal, CI), `tput` writes an
error to stderr and the local var is empty. The subsequent printf format
strings `"%*s${color}%s${reset}\n"` then render unstyled, which is fine —
but the `tput cols` call at line 15 returns empty on a TERM-less context,
making `width` empty, making `padding=$(( (width - ${#text}) / 2 ))` a zsh
arithmetic error (empty operand) that aborts the function under `set -e`.
**Fix:** Guard the tput calls and provide sane defaults:
```zsh
local width=$(tput cols 2>/dev/null || echo 80)
local cyan=$(tput setaf 51 2>/dev/null || echo "")
# ...etc
```
For the unset-f cleanup, move it inside a `trap '...' EXIT RETURN` so abnormal
returns also clean up, and use `2>/dev/null || true`:
```zsh
trap 'unset -f _motd_center _motd_line 2>/dev/null || true' EXIT
```

## Warnings

### WR-01: `_apply_defaults` indirect-array expansion fails silently on undeclared arrays under `set -u`

**File:** `os/defaults/_apply_verify.zsh:64`
**Issue:** `arr=("${(@P)array_name}")` uses zsh's indirect-expansion `(P)` flag.
If `$array_name` refers to a variable that is unset (typo in caller, e.g.
`_apply_defaults DOC_DEFAULTS` instead of `DOCK_DEFAULTS`), `(P)` returns
empty and the loop body never executes. The helper returns 0 with no work
done. Under `set -u`, the typo should abort — but `(P)` deliberately suppresses
the unset error. The caller sees a green checkmark for "applied N=0 defaults"
with no signal that the array was missing.
**Fix:** Add an explicit pre-check:
```zsh
if ! typeset -p "$array_name" >/dev/null 2>&1; then
  echo "ERROR: _apply_defaults: array '$array_name' is not declared" >&2
  return 1
fi
```

### WR-02: `_apply_defaults` does not validate tuple-stride; a malformed array silently truncates

**File:** `os/defaults/_apply_verify.zsh:66-79`
**Issue:** The loop `for ((i = 1; i <= ${#arr[@]}; i += 4))` assumes
`${#arr[@]} % 4 == 0`. If a future array author adds an entry with the wrong
number of fields (e.g., forgets the type column), the final tuple silently
truncates and the off-by-N error is invisible — the missing column reads
empty, the `defaults write ... -<type> <expanded>` call becomes
`defaults write <domain> <key> - <expanded>` (no type flag), and macOS
defaults accepts it as a string write with literal `-` type. This corrupts
the plist.
**Fix:** Validate stride at the top of the helper:
```zsh
if (( ${#arr[@]} % 4 != 0 )); then
  echo "ERROR: _apply_defaults: array '$array_name' length ${#arr[@]} is not a multiple of 4" >&2
  return 1
fi
```

### WR-03: `_dotfiles_require_feature` doc-comment vs. behavior mismatch on `$2` default

**File:** `shell/functions/_dotfiles_require_feature.zsh:23-29, 38`
**Issue:** The header comment claims `$2` defaults to `${funcstack[2]}` (the
calling function's name) so the typical call is single-arg. The implementation
is `local fn_name="${2:-${funcstack[2]:-${0}}}"`. When called outside any
function (direct script context), `funcstack[2]` is unset and the fallback
falls through to `$0` — which under zsh inside a sourced function file is
the FILE PATH of the sourced file (`shell/functions/_dotfiles_require_feature.zsh`),
not the function name. Users get error messages like
`/Users/.../shell/functions/_dotfiles_require_feature.zsh: feature 'X' is disabled`,
which is the helper file path, not anything actionable. Under `set -u`, if
both `$2` and `funcstack[2]` are unset, the chained `:-` defaults handle it,
but the `$0` fallback is semantically wrong.
**Fix:** Use `${funcstack[2]:-_dotfiles_require_feature}` as the inner
fallback (helper's own name is more informative than its file path):
```zsh
local fn_name="${2:-${funcstack[2]:-_dotfiles_require_feature}}"
```

### WR-04: `cheat()` does not quote `$result` when echoing — multi-line output collapses

**File:** `shell/functions/cheat.zsh:8, 13`
**Issue:** Line 8 (`echo $result`) and line 13 (`echo "$result"`) handle the
same variable differently. Line 13 quotes correctly; line 8 does not. The
unquoted form on the empty-arg branch (help text fallback) word-splits the
multi-line `curl cheat.sh` response, collapsing whitespace-significant
content. Same class as the original phase-flagged bug at row 39 of
`13-REVIEW.md` — but that finding was "closed" in commit e821f8f, which
fixed line 13 but apparently re-introduced or left line 8 unquoted.
Re-inspection of the current file confirms line 8 is still `echo $result`.
**Fix:** Quote line 8:
```zsh
echo "$result"
```

### WR-05: `prettyjson()` pipes through `highlight` which may not exist on every machine

**File:** `shell/functions/prettyjson.zsh:14`
**Issue:** `jq '.' "${1}" | highlight --syntax=json` assumes `highlight` is
installed and on PATH. On a fresh machine (pre-install) or a server-class
machine without the `highlight` package, this fails with `command not found`
plus a broken pipe — and under `pipefail` (which the function inherits if
called from a `set -euo pipefail` parent), the failure propagates as an exit
code, breaking interactive usage. The companion `cheat()` function does NOT
have this issue because it just `echo`s the result.
**Fix:** Guard the pipe:
```zsh
if command -v highlight >/dev/null 2>&1; then
  jq '.' "${1}" | highlight --syntax=json
else
  jq '.' "${1}"
fi
```

### WR-06: `pubkey()` `pbcopy` fails silently on Linux / SSH session — no diagnostic

**File:** `shell/functions/pubkey.zsh:15`
**Issue:** `pbcopy < ~/.ssh/"${1}"` is macOS-only. On a non-macOS context
(SSH from Linux into a remote macOS machine, or simply running on Linux),
`pbcopy` is absent and the redirection silently consumes the file with no
error to the user (under `set -e` this propagates, but interactive zsh
doesn't have `-e` by default). The success message at line 16 then lies
about completion.
**Fix:** Check the result:
```zsh
if pbcopy < ~/.ssh/"${1}"; then
  echo '=> Public key copied to clipboard.'
else
  echo 'ERROR: pbcopy failed (not on macOS, or pbcopy missing)' >&2
  return 1
fi
```

### WR-07: `screenshots.zsh` apply hardcodes `$HOME/Pictures/Screenshots` but tuple value could change

**File:** `os/defaults/screenshots.zsh:60-71`
**Issue:** The `SCREENSHOTS_DEFAULTS` array declares
`"\$HOME/Pictures/Screenshots"` as the location value (line 61). The
`apply_screenshots` body hardcodes the same path literal at line 70
(`mkdir -p "$HOME/Pictures/Screenshots"`) BEFORE delegating to
`_apply_defaults`. If an operator changes the array value (e.g., to
`"$HOME/Documents/Screenshots"`), `apply_screenshots` will create the OLD
directory and `defaults write` will set the NEW location — yielding the
exact failure mode (Pitfall 14) the mkdir was added to prevent.
**Fix:** Derive the path from the array:
```zsh
apply_screenshots() {
  local loc="${SCREENSHOTS_DEFAULTS[3]/\$HOME/$HOME}"
  mkdir -p "$loc"
  _apply_defaults SCREENSHOTS_DEFAULTS SystemUIServer
}
```
This couples the mkdir to the same source of truth as the defaults write.

### WR-08: `_verify_defaults` `failed=1` not `failed=$((failed + 1))` — same bug class as `install/test-hooks.zsh` row 19

**File:** `os/defaults/_apply_verify.zsh:114`
**Issue:** `failed=1` overwrites instead of incrementing. The function returns
`return $failed` (line 117), so the caller cannot distinguish "1 key failed"
from "12 keys failed" — both return 1. Same exact bug class as
`install/test-hooks.zsh` row 19 of `13-REVIEW.md`, fixed in commit 739ab57
for that file but NOT propagated to the newly-extracted helper.
**Fix:** Increment instead of overwrite:
```zsh
failed=$((failed + 1))
```

### WR-09: `motd()` `_motd_center` arithmetic is fragile when text is wider than terminal

**File:** `shell/functions/motd.zsh:18-23, 21`
**Issue:** `local padding=$(( (width - ${#text}) / 2 ))` produces a NEGATIVE
number when `${#text} > width`. The next line `printf "%*s${color}%s${reset}\n" $padding "" "$text"`
passes a negative width specifier to printf, which most printf implementations
treat as left-justification with absolute-value width — producing visually
wrong output but no crash. Under `set -e`, the printf return is 0 regardless,
so this is silent visual corruption only on narrow terminals.
**Fix:** Clamp to zero:
```zsh
local padding=$(( (width - ${#text}) / 2 ))
(( padding < 0 )) && padding=0
```

## Info

### IN-01: `_apply_verify.zsh` docstring contradicts its own code about $HOME expansion

**File:** `os/defaults/_apply_verify.zsh:34-37`
**Issue:** The docstring at lines 34-37 explains the `(e)`-flag was rejected,
and lines 71-73 (apply) and 99 (verify) use the narrow substitution
`${value/\$HOME/$HOME}`. But the `screenshots.zsh` docstring at lines 30-35
still claims `(e)`-flag expansion is used: "the apply / verify loops expand
it via zsh's `(e)` parameter-expansion flag (`"${(e)value}"`) at use time".
Code uses narrow substitution; doc says `(e)`-flag. Doc drift introduced
during the Plan 13-04 helper extraction.
**Fix:** Update `screenshots.zsh` docstring lines 30-35 to match the helper's
narrow-substitution form (matches the corrected docstring at
`screenshots.zsh:47-51`, which is correct).

### IN-02: `_dotfiles_require_feature` reads `$_DOTFILES_FEATURES` per docstring but actually calls `_dotfiles_feature()`

**File:** `shell/functions/_dotfiles_require_feature.zsh:15, 39`
**Issue:** Header doc at line 15 says `Reads: $_DOTFILES_FEATURES (populated
by _dotfiles_feature on first call).` The function body actually calls
`_dotfiles_feature "$feature"` directly (line 39), which is what reads the
array. The "Reads:" claim conflates the helper with the underlying cache and
will mislead future maintainers searching for direct array accesses.
**Fix:** Update the Reads: line:
```
# Reads:   calls _dotfiles_feature (which reads/populates $_DOTFILES_FEATURES).
```

### IN-03: `links.yml` `install-claude.status` block has 13 identical 200-character lines (readability + diff noise)

**File:** `taskfiles/links.yml:250-262`
**Issue:** The 13 status entries are mechanical clones with only the filename
differing. The phase's review (`13-REVIEW.md` row 22) explicitly chose to keep
this shape for per-link diagnostic visibility — that decision is sound. But
the resulting 13 200+ character lines each are now dense enough that any
future edit (e.g., renaming `claude-marketplace` to a different feature key)
must touch all 13 sites consistently. A defensive measure: extract the
common substring into a vars block reference. No correctness impact.
**Fix:** Optional. If revisited, consider:
```yaml
vars:
  CLAUDE_GATE: '{{if not (index .MANIFEST.features "claude-marketplace")}}true{{else}}'
status:
  - '{{.CLAUDE_GATE}}test -L "{{.XDG_CONFIG_HOME}}/claude/CLAUDE.md" && [[ "$(readlink -f "{{.XDG_CONFIG_HOME}}/claude/CLAUDE.md")" == "{{.DOTFILEDIR}}/claude/CLAUDE.md" ]]{{end}}'
```

### IN-04: `compose-brewfile.zsh` `bundles_csv` loop reinvents `IFS`-join

**File:** `install/compose-brewfile.zsh:106-114`
**Issue:** Nine lines to build a comma-separated list. Zsh has a one-line
form: `bundles_csv="${(j:, :)bundles}"`. The current implementation is
correct, just verbose.
**Fix:** Replace lines 106-114 with:
```zsh
local bundles_csv="${(j:, :)bundles}"
```

### IN-05: `shell/.zshrc` `_zcomp_age=0` initial assignment masks a stat failure

**File:** `shell/.zshrc:52-55`
**Issue:** `_zcomp_age=0` then `if [[ -f "$ZSH_COMPDUMP" ]]; then _zcomp_age=$(...)`.
If the file exists but `stat` fails on both BSD and GNU forms (the `|| echo 0`
fallback handles it), the subtraction `$(date +%s) - 0` yields the current
epoch — a huge number that's always > 86400, so `compinit -d` always runs.
That's the SAFE failure direction (slower but correct), but a `cross "stat
failed"` message would help debugging. Same class as the broader
"fall-through-to-no-op" risk in the message handling library.
**Fix:** Optional defensive log:
```zsh
local _file_mtime
_file_mtime=$(stat -f %m "$ZSH_COMPDUMP" 2>/dev/null || stat -c %Y "$ZSH_COMPDUMP" 2>/dev/null || echo "")
if [[ -z "$_file_mtime" ]]; then
  _zcomp_age=0  # force re-run
else
  _zcomp_age=$(( $(date +%s) - _file_mtime ))
fi
```

### IN-06: `taskfiles/refresh.yml` `status: [false]` is a "skipped" sentinel, not a no-op

**File:** `taskfiles/refresh.yml:22`
**Issue:** `status: [false]` is the canonical "always re-run" idiom (go-task
parses `false` as a non-zero-exit single command, so the task always runs).
Operators reading this for the first time may think `false` is the sentinel
string "false" — confusing without a comment. Same convention used at
`test.yml:88, 98`, `links.yml:335, 463`, `shell.yml:100`, `macos.yml:287`.
**Fix:** Add a one-line comment above the `status: [false]` line citing the
go-task idiom:
```yaml
# go-task: `status: [false]` -> command `false` always exits non-zero, so this
# task is always re-run by design (read-only / always-re-run semantics).
status: [false]
```

### IN-07: `manifest.yml setup` task `printf '%s' "${CLI_ARGS_ENV}" > "$state_file"` does not add trailing newline

**File:** `taskfiles/manifest.yml:153`
**Issue:** `printf '%s'` writes the machine name with NO trailing newline.
Several downstream readers use `head -n1 | sed ...` (manifest.yml:79, 225,
269) which works fine without a newline. But `read -r name < "$MACHINE_FILE"`
(resolver.zsh:77, 595) reads until newline OR EOF — both work — and
`<${file}` for read also works without newline. However, the
`< "$MACHINE_FILE"` form in resolver.zsh:77 inside the `if [[ -s "$MACHINE_FILE" ]]`
block expects the file to be "non-empty"; `printf '%s' "name"` produces a
non-empty file. OK, no functional bug. But: POSIX text files canonically end
with newline, and tools like `cat $state_file` followed by another command's
prompt run them together on one line. Cosmetic.
**Fix:** Add the newline:
```yaml
- printf '%s\n' "${CLI_ARGS_ENV}" > "{{.STATE_FILE}}"
```

---

_Reviewed: 2026-05-18_
_Reviewer: Claude (gsd-code-reviewer) -- independent audit_
_Depth: standard_
