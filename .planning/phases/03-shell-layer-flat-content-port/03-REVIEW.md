---
phase: 03-shell-layer-flat-content-port
reviewed: 2026-05-14T00:00:00Z
depth: standard
files_reviewed: 44
files_reviewed_list:
  - Taskfile.yml
  - configs/antidote/zsh_plugins.txt
  - manifests/defaults.toml
  - manifests/machines/personal-laptop.toml
  - manifests/machines/work-laptop.toml
  - shell/.zlogin
  - shell/.zlogout
  - shell/.zprofile
  - shell/.zshenv
  - shell/.zshrc
  - shell/README.md
  - shell/aliases/dotfiles.zsh
  - shell/aliases/finder.zsh
  - shell/aliases/general.zsh
  - shell/aliases/ghostty.zsh
  - shell/aliases/hardware.zsh
  - shell/aliases/jgrid.zsh
  - shell/aliases/networking.zsh
  - shell/functions/_dotfiles_feature.zsh
  - shell/functions/afk.zsh
  - shell/functions/aliaslist.zsh
  - shell/functions/cheat.zsh
  - shell/functions/docker.zsh
  - shell/functions/fs.zsh
  - shell/functions/functionlist.zsh
  - shell/functions/geoip.zsh
  - shell/functions/getcertnames.zsh
  - shell/functions/ghpubkey.zsh
  - shell/functions/host.zsh
  - shell/functions/info.zsh
  - shell/functions/ipv4lookup.zsh
  - shell/functions/ipv6lookup.zsh
  - shell/functions/mkcd.zsh
  - shell/functions/motd.zsh
  - shell/functions/permissions.zsh
  - shell/functions/prettyjson.zsh
  - shell/functions/pubkey.zsh
  - shell/functions/sethostname.zsh
  - shell/functions/sshlist.zsh
  - shell/functions/timezsh.zsh
  - shell/functions/vnc.zsh
  - shell/functions/whois.zsh
  - shell/theme.zsh
  - taskfiles/links.yml
  - taskfiles/shell.yml
findings:
  critical: 4
  warning: 14
  info: 9
  blocker: 4
  total: 27
status: issues_found
---

# Phase 03: Code Review Report

**Reviewed:** 2026-05-14
**Depth:** standard
**Files Reviewed:** 44
**Status:** issues_found

## Summary

Phase 03 ports the v1 shell stack into the new flat layout under `shell/` and
adds two real taskfiles (`taskfiles/links.yml`, `taskfiles/shell.yml`) plus
the manifest-driven `_dotfiles_feature` helper. The structural work is largely
sound, but adversarial review surfaced a load-order bug that breaks the
documented gating contract for `shell/aliases/jgrid.zsh`, an aggregator
`status:` block in `taskfiles/links.yml` that under-checks the symlinks it
creates (allowing the v2-equivalent of the v1 `macos:shell:145` re-run
class), a `find | du` Linux fallback in `fs.zsh` that does not actually
work because `du` ignores stdin, and a v1-leftover `${DOTFILEDIR}/zsh/configs/`
path inside `motd.zsh` that breaks on every fresh v2 cutover because the
flat layout removes `zsh/configs/` entirely.

Several files also lack the file-level comment block required by CLAUDE.md,
and a couple of function bodies retain v1 idioms (`local` at top scope,
recursive `function host()` etc. shadowing system commands) that are worth
flagging even though zsh tolerates them.

## Critical Issues

### CR-01: jgrid.zsh source-time gate runs before `_dotfiles_feature` is defined

**File:** `shell/.zshrc:109-120`, `shell/aliases/jgrid.zsh:17`
**Issue:** `.zshrc` sources `shell/aliases/*.zsh` (line 110) **before** it
sources `shell/functions/*.zsh` (line 118). `shell/aliases/jgrid.zsh:17`
invokes `_dotfiles_feature jgrid-net` at source time:

```zsh
[[ "$(_dotfiles_feature jgrid-net)" == "true" ]] || return 0
```

Because the function is not yet defined when aliases are sourced, the
command substitution either prints "command not found" to stderr and returns
empty (so `[[ "" == "true" ]]` is false, returns 0, skipping the metals on
machines that *do* want them) or, if a stale system `_dotfiles_feature`
existed, behaves unpredictably. Either way, the documented D-08 contract
("source-time gate fires only when the feature is enabled") is violated.

The wrapper-function gates in `finder.zsh` and `ghostty.zsh` are fine because
they call `_dotfiles_feature` at *call* time, not source time, by which
point the function loop has completed.

**Fix:** Reverse the source order so functions load before aliases (the
v1 `.zshrc` and the README's "callers" claim both assume this order):

```zsh
# Load functions FIRST so source-time gates in aliases can call them
for file in "${DOTFILEDIR}/shell/functions/"*.zsh(.N); do
    source "$file"
done

# Load aliases SECOND (source-time gates in jgrid.zsh now have
# _dotfiles_feature available)
for file in "${DOTFILEDIR}/shell/aliases/"*.zsh(.N); do
    source "$file"
done

source "${DOTFILEDIR}/shell/theme.zsh"
```

Add a regression test that asserts `alias steel` exists on a machine
manifest with `jgrid-net = true`.

---

### CR-02: `taskfiles/links.yml all:` `status:` skips the task when only `.zshenv` and `.zsh_plugins.txt` exist

**File:** `taskfiles/links.yml:73-76`
**Issue:** The aggregator's `status:` only checks two of the six symlinks
the task creates:

```yaml
all:
  cmds:
    - task: zsh        # creates .zshenv .zprofile .zshrc .zlogin .zlogout
    - task: antidote   # creates .zsh_plugins.txt
  status:
    - test -L "{{.ZDOTDIR}}/.zshenv"
    - test -L "{{.ZDOTDIR}}/.zsh_plugins.txt"
```

If a user partially links the tree (e.g., manually `rm`s
`$ZDOTDIR/.zshrc` after a botched edit, or `$ZDOTDIR/.zprofile` is
missing because a previous run was interrupted between the two
`_:safe-link` calls), `task install` -> `links:all` will see both
checked symlinks present, exit 0, and **never restore the missing
files**. The `links:zsh` sub-task does check all five files in its
own `status:`, but go-task short-circuits sub-task evaluation when the
parent's `status:` reports done — so the partial state goes uncorrected
until the user deletes one of the two probed targets.

This is exactly the v1 `macos:shell:145` bug class the linter rules
were written to prevent.

**Fix:** Either delete the `status:` block on `all:` entirely (the
underlying sub-tasks already idempotency-check via their own status
blocks, which is the canonical pattern for aggregator tasks), or
enumerate every symlink the aggregator owns:

```yaml
all:
  desc: "Create all symlinks (P3: shell only; later phases extend)"
  cmds:
    - task: zsh
    - task: antidote
  status:
    - test -L "{{.ZDOTDIR}}/.zshenv"
    - test -L "{{.ZDOTDIR}}/.zprofile"
    - test -L "{{.ZDOTDIR}}/.zshrc"
    - test -L "{{.ZDOTDIR}}/.zlogin"
    - test -L "{{.ZDOTDIR}}/.zlogout"
    - test -L "{{.ZDOTDIR}}/.zsh_plugins.txt"
```

Prefer dropping the aggregator `status:` — it adds nothing once every
sub-task is idempotent, and it traps you into re-extending the list on
every future plan (P4 git/ssh, P7 claude/tools, etc.).

---

### CR-03: `motd.zsh` reads `${DOTFILEDIR}/zsh/configs/` which does not exist on a v2 machine

**File:** `shell/functions/motd.zsh:91`, `:115`
**Issue:** The function reads two paths that v2 has not yet created:

```zsh
local ff_config="${DOTFILEDIR}/zsh/configs/motd_sysinfo.jsonc"
...
local quotes_file="${DOTFILEDIR}/zsh/configs/motd_tron.txt"
```

The file-level comment block flags this ("v1 config-file paths under
zsh/configs/ are still consumed verbatim; Phase 7 will move them to
configs/<tool>/") and the `[[ -f ... ]]` guard prevents a hard error,
but on every v2-only machine the result is a silent fallback to
`fastfetch 2>/dev/null` with no quote line — i.e., the MOTD is
silently degraded for the entire window between this phase and Phase 7.

On a fresh v2 install (no `zsh/` directory anywhere because the v1
layout was deleted), `motd` looks broken to the user even though the
function "ran successfully." On a *staged* v2 install where v1 files
still exist, the function works but is reading from a path the phase is
supposed to be retiring — masking incomplete migration.

**Fix:** Move `motd_sysinfo.jsonc` and `motd_tron.txt` into
`configs/motd/` (or `configs/fastfetch/`) in this phase rather than
deferring to Phase 7, then update the two paths:

```zsh
local ff_config="${DOTFILEDIR}/configs/motd/sysinfo.jsonc"
local quotes_file="${DOTFILEDIR}/configs/motd/tron.txt"
```

If the move is genuinely out of scope, fail loudly when the config is
absent (print a warning to stderr citing the missing path) rather than
silently degrading.

---

### CR-04: `fs.zsh` Linux fallback pipes `find` to `du` which ignores stdin

**File:** `shell/functions/fs.zsh:16`
**Issue:** The non-Darwin branch is:

```zsh
find . -type f | du -ah -d1 | highlight --syntax=bash
```

`du` does not read paths from stdin; it requires file arguments. The
pipe is dropped on the floor, and `du -ah -d1` runs on the current
directory by accident. On a fresh Linux machine the command does not
crash, but it does not do what the v1 author intended either — it
produces depth-1 sizes of the cwd ignoring the `find` filter, which
is a behaviour drift bug.

v1 is macOS-only, so this never executes today; but the dead branch is
in the v2 tree and will fire the moment Linux support lands. Either
delete the branch (with a comment saying "v1 macos-only") or fix it:

```zsh
# Linux: equivalent of macOS branch -- non-dotfile entries depth 1
du -ah --max-depth=1 .[^.]* ./* 2>/dev/null | highlight --syntax=bash
```

Adding `set -euo pipefail` to function-scoped shells is not in scope
because these are sourced into the user's interactive shell.

**Fix:** Either delete the Linux branch or replace it with a correct
GNU `du` invocation. Track this on the platform-port debt list rather
than leaving the broken pipe in `master`.

---

## Warnings

### WR-01: `shell/aliases/jgrid.zsh` source-time call to `_dotfiles_feature` emits "command not found" on first source

**File:** `shell/aliases/jgrid.zsh:17`
**Issue:** Even after CR-01 is fixed by reordering the loops, anyone who
reverts that order — or who copies this file into a slot where the
function load is gated — will silently break the feature. The file should
defensively check that the helper is loaded before invoking it.

**Fix:**

```zsh
# Defensive: bail if the manifest helper hasn't loaded yet (load-order guard).
if ! (( $+functions[_dotfiles_feature] )); then
    echo "jgrid.zsh: _dotfiles_feature not loaded (functions must source first)" >&2
    return 0
fi

[[ "$(_dotfiles_feature jgrid-net)" == "true" ]] || return 0
```

---

### WR-02: `.zshenv` `DOTFILES_MACHINE` capture retains trailing newline

**File:** `shell/.zshenv:77`
**Issue:**

```zsh
DOTFILES_MACHINE="$(<${XDG_STATE_HOME}/dotfiles/machine)"
```

zsh's `$(<file)` substitution preserves the file content verbatim including
the trailing newline (unlike `$()` which strips trailing newlines).
Downstream consumers that compare with `[[ "$DOTFILES_MACHINE" == "personal-laptop" ]]`
will fail when the file was written with `echo personal-laptop > .../machine`.

**Fix:**

```zsh
DOTFILES_MACHINE="$(<${XDG_STATE_HOME}/dotfiles/machine)"
DOTFILES_MACHINE="${DOTFILES_MACHINE%$'\n'}"
export DOTFILES_MACHINE
```

Or use `read -r` which strips the newline by default:

```zsh
{ read -r DOTFILES_MACHINE; } < "${XDG_STATE_HOME}/dotfiles/machine" 2>/dev/null && export DOTFILES_MACHINE
```

---

### WR-03: `.zshrc` `code --locate-shell-integration-path` invoked without existence check

**File:** `shell/.zshrc:101-103`
**Issue:**

```zsh
if [[ "$TERM_PROGRAM" == "vscode" ]]; then
    source "$(code --locate-shell-integration-path zsh)"
fi
```

If `code` is not in PATH (fresh machine; `code` symlink installed only by
"Install 'code' command in PATH" in VS Code), the command substitution
produces an empty string and `source ""` errors out. The error then
propagates because nothing guards it.

**Fix:**

```zsh
if [[ "$TERM_PROGRAM" == "vscode" ]] && command -v code >/dev/null 2>&1; then
    local _vscode_integration
    _vscode_integration="$(code --locate-shell-integration-path zsh 2>/dev/null)"
    [[ -n "$_vscode_integration" && -f "$_vscode_integration" ]] && source "$_vscode_integration"
    unset _vscode_integration
fi
```

---

### WR-04: `docker.zsh` `docker ps` inside wrapper recurses instead of calling the binary

**File:** `shell/functions/docker.zsh:14`
**Issue:** Inside the function `docker()`, the body runs:

```zsh
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
```

This re-enters the wrapper function, which then matches the `if [[ "$1" == "ps" ]]`
branch again and recurses forever — except that on this second call `$1` is
"ps" again so the function `shift`s and re-runs `command docker ps` on line 7.
Actually re-reading: line 14 is inside the `bash|sh|...` branch, not the
`ps` branch, so it *will* recurse infinitely until the shell hits the
function-depth limit.

**Fix:** Always prefix with `command`:

```zsh
echo "Running containers:"
command docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
```

---

### WR-05: `whois.zsh` `$(whence -p whois)` evaluates to empty string when not installed

**File:** `shell/functions/whois.zsh:37`
**Issue:**

```zsh
gtimeout "$timeout_seconds" grc --colour=auto $(whence -p whois) "$target"
```

If `whois` is not in PATH, `whence -p whois` prints nothing and `grc`
receives `--colour=auto "$target"` — interpreting `$target` as the command
to colorize. The user sees `grc: command not found: example.com` or
similar confusion instead of a clear "whois is not installed" error.

**Fix:**

```zsh
local whois_bin
whois_bin="$(whence -p whois)"
if [[ -z "$whois_bin" ]]; then
    echo "ERROR: whois binary not found in PATH" >&2
    return 1
fi
gtimeout "$timeout_seconds" grc --colour=auto "$whois_bin" "$target"
```

Same applies to `gtimeout` itself (mac-only, requires `brew install coreutils`).

---

### WR-06: `aliaslist.zsh` populates an associative array inside a piped while loop

**File:** `shell/functions/aliaslist.zsh:9-19`
**Issue:**

```zsh
grep '^alias' "$file" 2>/dev/null | while IFS= read -r line; do
    local name="${line#alias }"
    name="${name%%=*}"
    dotfiles_aliases[$name]=1
    echo "$line" | highlight --syntax=bash
done
```

The right-hand side of the pipe runs in a subshell in many shell
configurations. In zsh with `MULTIOS` and default `setopt`s the loop body
runs in the parent shell, so this works *today*, but the moment a user
sets `setopt POSIX_BUILTINS` or runs under a tweaked rc the array
assignment evaporates and the "exclude dotfiles aliases from system
section" logic breaks silently — every alias gets printed twice.

**Fix:** Use process substitution to keep the loop in the parent shell:

```zsh
while IFS= read -r line; do
    local name="${line#alias }"
    name="${name%%=*}"
    dotfiles_aliases[$name]=1
    echo "$line" | highlight --syntax=bash
done < <(grep '^alias' "$file" 2>/dev/null)
```

---

### WR-07: `functionlist.zsh` `grep 'function'` matches docstring comments

**File:** `shell/functions/functionlist.zsh:10`
**Issue:**

```zsh
grep 'function' "$file" | awk '{$1=$1};1' | highlight --syntax=bash
```

The pattern `function` matches any line containing that substring — including
documentation comments that mention the word ("the function returns..."),
not just function definitions. Output is noisier than intended and
non-deterministic across edits.

**Fix:** Anchor to definition lines:

```zsh
grep -E '^[[:space:]]*function[[:space:]]+[A-Za-z_]' "$file" | awk '{$1=$1};1' | highlight --syntax=bash
```

---

### WR-08: `motd.zsh` async refresh races on `${cache}.tmp`

**File:** `shell/functions/motd.zsh:41`
**Issue:**

```zsh
( _motd_render > "${cache}.tmp" 2>/dev/null && mv "${cache}.tmp" "$cache" ) &!
```

Two interactive shells started within seconds of each other will both fork
async refreshes that write to the **same** `${cache}.tmp` path; one wins the
write and the other's `mv` clobbers a partial file or vice versa. Result:
on a fast-shell-spawning workflow the cache content becomes a torn read.

**Fix:** Use a per-PID tempfile:

```zsh
local tmp="${cache}.$$.$RANDOM.tmp"
( _motd_render > "$tmp" 2>/dev/null && mv "$tmp" "$cache" || rm -f "$tmp" ) &!
```

---

### WR-09: `motd.zsh` `tput cols` in backgrounded render has no controlling terminal

**File:** `shell/functions/motd.zsh:53`
**Issue:** The async refresh path forks `_motd_render` into the background
via `&!`. Once disowned, the subprocess has no controlling tty (or has the
parent's tty that may be detached by the time it runs); `tput cols` then
returns either 80 (default) or empty, and the cached output is built at
the wrong width. Next time the user opens a wide terminal, the displayed
MOTD is too narrow because it was cached at narrow width.

**Fix:** Capture width before backgrounding:

```zsh
if (( now - mtime > ttl )); then
    local _w; _w="$(tput cols 2>/dev/null || echo 80)"
    ( COLUMNS="$_w" _motd_render > "${tmp}" 2>/dev/null && mv "${tmp}" "$cache" ) &!
fi
```

and update `_motd_render` to honour `$COLUMNS` if set.

---

### WR-10: `pubkey.zsh` `ls ~/.ssh/*.pub` glob; `more` instead of `cat`

**File:** `shell/functions/pubkey.zsh:7,11`
**Issue:**

```zsh
local keylist=$(ls ~/.ssh/*.pub);
...
more ~/.ssh/"${1}" | pbcopy
```

Three problems: (1) `ls` is the wrong tool for parsing filenames (parsing
`ls` output is fragile per the Unix Pitfalls FAQ); (2) `more` is a pager
that does no useful work here vs. `cat` and on some setups will write the
pager control codes to the clipboard; (3) on a machine with zero `*.pub`
files, `ls ~/.ssh/*.pub` errors with "No such file" — but the function
already gates on `-z "$1"` and only enters this branch when *no* arg is
provided, so the "no keys" path is the error path.

**Fix:**

```zsh
if [[ -z "${1}" ]]; then
    echo "ERROR: No key specified. The possible keys are:" >&2
    local keylist
    keylist=( ~/.ssh/*.pub(N) )
    if (( ${#keylist} == 0 )); then
        echo "  (no .pub files found in ~/.ssh)" >&2
    else
        printf '  %s\n' "${keylist[@]##*/}" | highlight --syntax=bash
    fi
    return 1
fi
cat ~/.ssh/"${1}" | pbcopy
```

---

### WR-11: `theme.zsh` `local` declarations at top scope; `local user='...'`

**File:** `shell/theme.zsh:19-23`, `shell/.zshrc:48,76-77`
**Issue:** `local user='%F{green}%n@%m%f'` is valid only inside a function;
at top scope zsh prints a warning ("local: can only be used in a function")
under some option sets and silently treats it as `typeset` otherwise.
Functionally equivalent today, but breaks future portability and produces
noisy stderr on shells with `WARN_CREATE_GLOBAL` or when the file is run
under `zsh -n` for linting.

**Fix:** Drop `local` at top scope:

```zsh
user='%F{green}%n@%m%f'
pwd='%F{blue}%~%f'
return_code='%(?..%F{red}%? ↵%f)'
git_branch='$(git_prompt_status)%f$(git_prompt_info)%f'
time='%F{cyan}%T%f'
```

Same applies to `.zshrc` lines 48 (`local _zcomp_age=0`) and 76-77
(`local _antidote_src=...`, `local _antidote_cache=...`).

---

### WR-12: `info.zsh` `if $show_all; then` evaluates the variable as a command

**File:** `shell/functions/info.zsh:13`
**Issue:**

```zsh
local show_all=false
if [[ "$1" == "all" ]]; then
    show_all=true
fi
...
if $show_all; then
```

This idiom only works because `true` and `false` are shell builtins. If
the variable ever holds any other value (an empty string, "yes", a
stray `1`), the conditional executes that string as a command — which is
a foot-gun and a code-injection vector if anyone ever lets user input
into `show_all`.

**Fix:** Compare strings explicitly:

```zsh
if [[ "$show_all" == "true" ]]; then
    fastfetch -c all --logo-padding-top 22
else
    fastfetch --logo-padding-top 4
fi
```

---

### WR-13: `_dotfiles_feature.zsh` array assignment in piped while loop has same subshell hazard as WR-06

**File:** `shell/functions/_dotfiles_feature.zsh:36-39`
**Issue:**

```zsh
while IFS='=' read -r k v; do
    _DOTFILES_FEATURES[$k]="$v"
done < <(jq -r '.features | to_entries[] | "\(.key)=\(.value)"' "$resolved" 2>/dev/null)
```

This particular instance uses process substitution `< <(...)` so the
parent-shell-assignment is preserved — i.e., this one is **correct**, no
fix needed. Flagging it only to confirm the pattern that WR-06 should
adopt for `aliaslist.zsh`.

**Fix:** None. The contrast is the point; aliaslist.zsh should follow
this file's pattern.

---

### WR-14: `personal-laptop.toml` / `work-laptop.toml` declare feature keys absent from `defaults.toml`

**File:** `manifests/defaults.toml:23-31`,
`manifests/machines/personal-laptop.toml:15-25`,
`manifests/machines/work-laptop.toml:14-22`
**Issue:** The machine manifests set `macos-dock`, `macos-input`,
`macos-screenshots`, `macos-security` to `true`, but `defaults.toml`'s
`[features]` block declares only `one-password-ssh`, `motd`,
`claude-marketplace`, `macos-finder`, `ghostty`, `jgrid-net`. Per
`CLAUDE.md` and the defaults.toml comment block ("Defaults supply shape
so the resolver always produces a complete resolved.json"), defaults
should declare every feature key in the schema — otherwise machines that
*omit* `macos-dock` get an undefined lookup and downstream gates evaluate
to "false" by accident rather than by design.

If Phase 6 (macos) hasn't introduced these flags yet, then either
(a) personal-laptop and work-laptop shouldn't reference them yet, or
(b) `defaults.toml` should declare them with `false`.

**Fix:** Add the missing keys to `defaults.toml`:

```toml
[features]
one-password-ssh = false
motd = true
claude-marketplace = true
macos-finder = false
macos-dock = false
macos-input = false
macos-screenshots = false
macos-security = false
ghostty = false
jgrid-net = false
```

---

## Info

### IN-01: Many alias/function files lack the required file-level comment block

**Files:** `shell/aliases/general.zsh`, `shell/aliases/hardware.zsh`,
`shell/aliases/networking.zsh`, `shell/functions/afk.zsh`,
`shell/functions/aliaslist.zsh`, `shell/functions/cheat.zsh`,
`shell/functions/docker.zsh`, `shell/functions/fs.zsh`,
`shell/functions/functionlist.zsh`, `shell/functions/geoip.zsh`,
`shell/functions/getcertnames.zsh`, `shell/functions/ghpubkey.zsh`,
`shell/functions/host.zsh`, `shell/functions/info.zsh`,
`shell/functions/ipv4lookup.zsh`, `shell/functions/ipv6lookup.zsh`,
`shell/functions/mkcd.zsh`, `shell/functions/permissions.zsh`,
`shell/functions/prettyjson.zsh`, `shell/functions/pubkey.zsh`,
`shell/functions/sethostname.zsh`, `shell/functions/sshlist.zsh`,
`shell/functions/timezsh.zsh`, `shell/functions/vnc.zsh`,
`shell/functions/whois.zsh`, `shell/theme.zsh`
**Issue:** Project rule (CLAUDE.md): "File-level comment block at the top
of every script explaining its purpose, callers, and side effects." The
listed files have only a one-line inline `#` comment or none, while the
newer files added by this phase (`finder.zsh`, `ghostty.zsh`, `jgrid.zsh`,
`_dotfiles_feature.zsh`, `motd.zsh`, `dotfiles.zsh`) follow the rule.

**Fix:** Add a 5-10 line banner to each, matching the established
pattern. Most are one-liners and the banner can be brief:

```zsh
#!/bin/zsh
# -----------------------------------------------------------------------------
# shell/functions/afk.zsh -- screen-lock helper.
#
# Purpose: invoke `pmset displaysleepnow` to lock the active display.
# Callers: interactive shell only (.zshrc functions glob).
# Side effects: locks the macOS display.
# -----------------------------------------------------------------------------
```

---

### IN-02: Several functions shadow system commands

**File:** `shell/functions/whois.zsh:4`, `shell/functions/host.zsh:4`,
`shell/functions/docker.zsh:4`
**Issue:** `function whois`, `function host`, `function docker` all shadow
their identically-named system binaries. The function bodies explicitly
re-dispatch via `whence -p` or `command`, so the shadow is intentional —
but it's worth a comment in each file that "this function intentionally
shadows the system command." Otherwise a future maintainer running
`unfunction whois` to debug will be surprised when behaviour changes.

**Fix:** Add a note in each file-level comment block (when IN-01 is
applied):

```zsh
# Note: intentionally shadows the system `whois` binary; re-dispatches via
# `whence -p whois` to invoke the underlying tool.
```

---

### IN-03: Inconsistent error-message channel (`echo "ERROR..."` to stdout vs. stderr)

**Files:** All `shell/functions/*.zsh` that print "ERROR: ..." messages
(cheat, geoip, getcertnames, ghpubkey, host, permissions, prettyjson,
pubkey, sethostname, vnc, whois)
**Issue:** CLAUDE.md global: "Errors go to stderr." Today most ERROR
messages are printed to stdout (`echo "ERROR: ..."`) which pollutes
piped consumers (`whois example.com | grep foo` will show the error
line in grep's input).

**Fix:** Append `>&2`:

```zsh
echo "ERROR: No host or IP specified" >&2
```

---

### IN-04: `cheat.zsh` indentation uses literal tabs in some lines and 4 spaces in others

**File:** `shell/functions/cheat.zsh:5-13`
**Issue:** Lines 5-10 use tab indentation; lines 11-13 use 4-space
indentation. Cosmetic but visually jarring under most editors and breaks
a stable `git blame`.

**Fix:** Normalize to 4 spaces throughout (matches the rest of the
function directory).

---

### IN-05: `cheat.zsh` `echo $result` unquoted; loses formatting on multi-line output

**File:** `shell/functions/cheat.zsh:8`
**Issue:** When `cheat.sh` returns the help text (no command argument),
`echo $result` (unquoted) re-splits on whitespace and collapses newlines.
The intended help text is mangled. The recovered case below correctly
uses `echo "$result"`.

**Fix:** Quote:

```zsh
echo "$result"
```

---

### IN-06: `getcertnames.zsh` uses ellipsis-1 character `…`, generally avoided in CLI output

**File:** `shell/functions/getcertnames.zsh:11`
**Issue:** `echo "Testing ${domain}…";` uses U+2026 horizontal ellipsis.
Not an emoji per se, but the project favours plain ASCII in tooling
output (consistent with the "no emojis" stance). On the rare terminal
without UTF-8 the character renders as `?`.

**Fix:** Replace with `...`:

```zsh
echo "Testing ${domain}..."
```

---

### IN-07: `motd.zsh` uses emoji glyphs `⚡`, `📦`, `💭` in output

**File:** `shell/functions/motd.zsh:90,102,118`
**Issue:** CLAUDE.md project rule: "No emojis in any file — including
markdown. Project convention is stricter than the global 'no emojis in
non-markdown' rule." The strict reading of the rule includes runtime
output (which is sourced from this file).

**Fix:** Replace with ASCII / unicode geometric shapes:

```zsh
echo "${cyan}${bold}>> SYSTEM INFORMATION${reset}"
echo "${cyan}${bold}** DOTFILES${reset}"
echo "${cyan}${bold}-- TRANSMISSION${reset}"
```

(or whichever ASCII glyph fits the Tron theme; the cyan+bold colouring
carries the visual weight even without the emoji).

---

### IN-08: `hardware.zsh` `gpu` and `monitor` aliases are identical

**File:** `shell/aliases/hardware.zsh:3,11`
**Issue:** Both `gpu` and `monitor` are
`system_profiler SPDisplaysDataType | highlight --syntax=markdown`. Likely
intentional (displays-data covers both), but they're trivially aliased
without a comment explaining why.

**Fix:** Add a one-line explanation, or alias one to the other:

```zsh
alias gpu="system_profiler SPDisplaysDataType | highlight --syntax=markdown"
alias monitor=gpu  # same data: SPDisplaysDataType covers both
```

---

### IN-09: `timezsh.zsh` does not validate the `$shell` arg before invocation

**File:** `shell/functions/timezsh.zsh:6-7`
**Issue:**

```zsh
local shell=${1-$SHELL}
for i in $(seq 1 4); do /usr/bin/time "$shell" -i -c exit; done
```

If a user passes a path that doesn't exist (`timezsh /nope`), the loop
runs four `time` invocations all reporting "command not found", producing
useless output. A leading existence check would short-circuit cleanly.

**Fix:**

```zsh
local shell=${1-$SHELL}
if ! [[ -x "$shell" ]] && ! command -v "$shell" >/dev/null 2>&1; then
    echo "ERROR: shell '$shell' not found or not executable" >&2
    return 1
fi
```

---

_Reviewed: 2026-05-14_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
