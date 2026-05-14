# Phase 3: Shell Layer — Flat Content Port - Pattern Map

**Mapped:** 2026-05-14
**Files analyzed:** ~50 (5 startup files + theme + ~7 alias topic files + 22 functions + 3 manifests + 1 taskfile + 1 config + 1 README)
**Analogs found:** 47 / 47 (every new artifact has a v1 analog or a Phase 1/2 analog)

**Note:** No RESEARCH.md exists for this phase. CONTEXT.md already names the analog paths in `<code_context>` and `<canonical_refs>`; this document extracts the concrete excerpts so the planner can write tasks without re-reading v1 files.

---

## File Classification

### Startup files (sourced, not executable; exempt from LINT-04)

| New File | Role | Data Flow | Closest Analog | Match Quality | Notes |
|----------|------|-----------|----------------|---------------|-------|
| `shell/.zshenv` | startup-script (sourced; every invocation) | request-response (env exports) | `zsh/.zshenv` | exact | Port verbatim; replace `DOTFILES_PROFILE` block (lines 72-74) with `DOTFILES_MACHINE` read from `$XDG_STATE_HOME/dotfiles/machine`. Must degrade gracefully (CF-05) — cron/scp safe. |
| `shell/.zprofile` | startup-script (sourced; login only) | request-response (Homebrew shellenv + SSH agent socket) | `zsh/.zprofile` | exact | Port the `uname -m` Homebrew block verbatim. **Fix CONCERNS bug:** replace literal `hostname -s != "server"` (lines 55-56) with manifest-feature check on `features.one-password-ssh`. |
| `shell/.zshrc` | startup-script (sourced; interactive only) | request-response (plugins, theme, aliases, functions) | `zsh/.zshrc` | exact | Largest rewrite. Replace antigen block (lines 52-72) with antidote bundle-cache logic. Collapse profile-subdir loops (lines 105-129) into flat globs. Add `_dotfiles_feature` priming + missing-machine warning. Insert compinit daily-cache logic (SHEL-10). |
| `shell/.zlogin` | startup-script (sourced; login post-init) | event (display MOTD) | `zsh/.zlogin` | exact | Port the `(( $+functions[motd] )) && motd` block verbatim (lines 17-19). Function body changes (cache-backed), not the dispatch. |
| `shell/.zlogout` | startup-script (sourced; logout cleanup) | event (history flush) | `zsh/.zlogout` | exact | Port verbatim — `fc -W 2>/dev/null || true`. No v1 bugs. |

### Theme

| New File | Role | Data Flow | Closest Analog | Match Quality |
|----------|------|-----------|----------------|---------------|
| `shell/theme.zsh` | sourced-library (prompt + man + grc colors) | request-response (sets PROMPT/RPROMPT, aliases) | `zsh/theme.zsh` | exact |

### Aliases (sourced; exempt from LINT-04)

| New File | Role | Data Flow | Closest Analog | Match Quality | Notes |
|----------|------|-----------|----------------|---------------|-------|
| `shell/aliases/general.zsh` | alias-topic (general shell aliases) | request-response | `zsh/aliases/common/general.zsh` | exact | Port everything EXCEPT the four GUI lines below. `reload`, `environment`, `path`, `dotfile`/`dotfiles`, `fsa`, `perms`, `ls`/`ll`, `lastinstalled`, `history`, `t` (task). |
| `shell/aliases/finder.zsh` | alias-topic (gated wrapper functions) | request-response (D-07 wrapper pattern) | `zsh/aliases/common/general.zsh:27-31` | role-match | Extract `finder`, `findershow`, `finderhide` into wrapper functions; first line calls `_dotfiles_feature macos-finder`. |
| `shell/aliases/ghostty.zsh` | alias-topic (gated wrapper function) | request-response (D-07 wrapper pattern) | `zsh/aliases/common/general.zsh:40` | role-match | Single `g()` wrapper for `/Applications/Ghostty.app/Contents/MacOS/ghostty`; gated on `features.ghostty`. |
| `shell/aliases/hardware.zsh` | alias-topic (system_profiler wrappers) | request-response | `zsh/aliases/common/hardware.zsh` | exact | Port verbatim. macOS-only OK per CONCERNS (v1 is macOS-only). |
| `shell/aliases/networking.zsh` | alias-topic (DNS + IP wrappers) | request-response | `zsh/aliases/common/networking.zsh` | exact | Port verbatim. `traceroute=trip` depends on trippy being in P5 core Brewfile. |
| `shell/aliases/jgrid.zsh` | alias-topic (bulk-loop, source-time gated) | request-response (D-08 source-time gate) | `zsh/aliases/personal/jgrid.zsh` | exact | Port the 22-metal loop verbatim. Prepend source-time gate: `[[ "$(_dotfiles_feature jgrid-net)" == "true" ]] || return 0`. |
| `shell/aliases/dotfiles.zsh` (planner discretion) | alias-topic (dotfiles repo nav + reload + update) | request-response | `zsh/aliases/common/general.zsh:3-14`, `zsh/functions/update.zsh` | role-match | Topic split per CF-06. Add `update='task install'` alias (replaces v1 `update.zsh` function). Includes `reload`, `dotfile`, `dotfiles`. |
| `shell/aliases/task.zsh` (planner discretion) | alias-topic (task runner shortcuts) | request-response | `zsh/aliases/common/general.zsh:43` | role-match | Hosts `alias t='task'`. Single-line topic; OK per SHEL-06 if planner prefers it inside `general.zsh` instead. |
| `shell/aliases/eza.zsh` (planner discretion) | alias-topic (ls/ll via eza) | request-response | `zsh/aliases/common/general.zsh:22-24` | role-match | Hosts `ls`/`ll` using `$(command -v eza)`. Planner may fold into `general.zsh`. |

### Functions (sourced; one function per file)

All 22 v1 functions port verbatim to `shell/functions/<name>.zsh`. None require behavioural change except `motd.zsh` (SHEL-11 cache) and the `update.zsh` function which is removed entirely per CF-06 (replaced by an alias).

| New File | Role | Data Flow | Closest Analog | Match Quality | Notes |
|----------|------|-----------|----------------|---------------|-------|
| `shell/functions/afk.zsh` | function (sleep display) | request-response | `zsh/functions/afk.zsh` | exact | Port verbatim. |
| `shell/functions/aliaslist.zsh` | function (list aliases) | batch | `zsh/functions/aliaslist.zsh` | exact (with rewrite) | Rewrite the profile-subdir walk (lines 26-34) — drop the `DOTFILES_PROFILE` lookup; instead iterate `shell/aliases/*.zsh` flat. The "Common"/"Profile" section headers collapse into "Dotfiles". |
| `shell/functions/cheat.zsh` | function (curl cheat.sh) | request-response | `zsh/functions/cheat.zsh` | exact | Port verbatim. |
| `shell/functions/docker.zsh` | function (docker wrapper) | request-response | `zsh/functions/docker.zsh` | exact | Port verbatim. |
| `shell/functions/fs.zsh` | function (du wrapper) | request-response | `zsh/functions/fs.zsh` | exact | Port verbatim. |
| `shell/functions/functionlist.zsh` | function (list functions) | batch | `zsh/functions/functionlist.zsh` | exact (with rewrite) | Same rewrite as `aliaslist.zsh` — drop `$DOTFILES_PROFILE` subdir walk (lines 14-24); flat `shell/functions/*.zsh` only. |
| `shell/functions/geoip.zsh` | function (curl ip.guide) | request-response | `zsh/functions/geoip.zsh` | exact | Port verbatim. |
| `shell/functions/getcertnames.zsh` | function (openssl cert parse) | request-response | `zsh/functions/getcertnames.zsh` | exact | Port verbatim. |
| `shell/functions/ghpubkey.zsh` | function (curl github keys) | request-response | `zsh/functions/ghpubkey.zsh` | exact | Port verbatim. |
| `shell/functions/host.zsh` | function (doggo DNS lookup) | request-response | `zsh/functions/host.zsh` | exact | Port verbatim. |
| `shell/functions/info.zsh` | function (onefetch/fastfetch) | request-response | `zsh/functions/info.zsh` | exact | Port verbatim. |
| `shell/functions/ipv4lookup.zsh` | function (multi-provider IP lookup) | request-response | `zsh/functions/ipv4lookup.zsh` | exact | Port verbatim. |
| `shell/functions/ipv6lookup.zsh` | function (multi-provider IP lookup) | request-response | `zsh/functions/ipv6lookup.zsh` | exact | Port verbatim. |
| `shell/functions/mkcd.zsh` | function (mkdir + cd) | request-response | `zsh/functions/mkcd.zsh` | exact | Port verbatim (3 lines). |
| `shell/functions/motd.zsh` | function (cached MOTD display) | batch (display + async refresh) | `zsh/functions/motd.zsh` | role-match | **Rewrite for SHEL-11.** v1's rendering logic ports to a `_motd_render` helper; the new public `motd()` reads `$XDG_CACHE_HOME/dotfiles/motd.cache`, displays stale content immediately, and triggers async refresh if older than 24h. Planner picks exact mechanic. |
| `shell/functions/permissions.zsh` | function (stat wrapper) | request-response | `zsh/functions/permissions.zsh` | exact | Port verbatim. |
| `shell/functions/prettyjson.zsh` | function (jq + highlight) | request-response | `zsh/functions/prettyjson.zsh` | exact | Port verbatim. |
| `shell/functions/pubkey.zsh` | function (pbcopy public key) | request-response | `zsh/functions/pubkey.zsh` | exact | Port verbatim. **Fix CONCERNS bug:** update docstring example from `id_rsa_adobe.pub` to `id_ed25519_personal.pub` (cosmetic, but listed in CONCERNS). |
| `shell/functions/sethostname.zsh` | function (scutil hostname set) | request-response | `zsh/functions/sethostname.zsh` | exact | Port verbatim. |
| `shell/functions/sshlist.zsh` | function (list SSH hosts) | batch | `zsh/functions/sshlist.zsh` | role-match | Rewrite: drop `DOTFILES_PROFILE` reference (lines 8, 19, 22, 29) — replace with `DOTFILES_MACHINE` and read the manifest-declared identity (`identity.ssh`) via `_dotfiles_feature`-style accessor, OR simplify to: show main config + any `ssh/configs/config-<identity>` files. Planner picks. |
| `shell/functions/timezsh.zsh` | function (zsh startup timer) | request-response | `zsh/functions/timezsh.zsh` | exact | Port verbatim. |
| `shell/functions/vnc.zsh` | function (open vnc://) | request-response | `zsh/functions/vnc.zsh` | exact | Port verbatim. |
| `shell/functions/whois.zsh` | function (whois with URL parsing) | request-response | `zsh/functions/whois.zsh` | exact | Port verbatim. |
| `shell/functions/_dotfiles_feature.zsh` | function (lazy manifest feature query) | request-response (cached lookup) | none — net-new helper | no analog | See CONTEXT.md `<specifics>` sketch (D-06). Pattern is new; planner uses the sketch + RESEARCH PITFALLS drift class guidance. |

**Dropped (do NOT port to v2):**
- `zsh/functions/update.zsh` — replaced by `update='task install'` alias per CF-06.

### Plugin manager config

| New File | Role | Data Flow | Closest Analog | Match Quality |
|----------|------|-----------|----------------|---------------|
| `configs/antidote/zsh_plugins.txt` | config-file (declarative plugin list) | n/a (data) | `zsh/.zshrc:57-66` (antigen bundle lines) | role-match (extracted from v1's antigen block into v2's static bundle format) |

### Manifests (P3 edits)

| Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---------------|------|-----------|----------------|---------------|
| `manifests/defaults.toml` | manifest (shared baseline TOML) | n/a (data) | `manifests/defaults.toml` (current) | exact | Add `features.ghostty = false`, `features.jgrid-net = false`. Confirm `features.macos-finder` (currently only in machine TOMLs; D-10 says "already in defaults.toml/personal-laptop.toml" — planner verifies and adds to defaults if absent). |
| `manifests/machines/personal-laptop.toml` | manifest (machine TOML) | n/a (data) | `manifests/machines/personal-laptop.toml` (current) | exact | Add `features.ghostty = true`, `features.jgrid-net = true`. |
| `manifests/machines/work-laptop.toml` | manifest (machine TOML) | n/a (data) | `manifests/machines/work-laptop.toml` (current) | exact | Add `features.ghostty = true`. (jgrid-net stays false — default.) |
| `manifests/machines/server-1.toml`, `server-2.toml` | manifest (machine TOML) | n/a (data) | (current) | exact | No edits — defaults `false` for ghostty/jgrid-net already serve servers. |

### Taskfile (P3 wires the real `links` body)

| New / Replaced File | Role | Data Flow | Closest Analog | Match Quality | Notes |
|---------------------|------|-----------|----------------|---------------|-------|
| `taskfiles/links.yml` (REPLACES `links-stub.yml` per Taskfile.yml comment) | taskfile (symlink orchestration) | request-response (creates symlinks idempotently) | `taskfiles/links.yml` (v1, current) + `taskfiles/manifest.yml` (P2 status-block patterns) | exact (v1 same purpose) + role-match (P2 status patterns) | P3 rewrites the `zsh:` task to point at `shell/.*` instead of `zsh/.*`. Drop the v1 `tools:` task (Phase 7 owns tool configs). Drop the v1 `claude:` task (Phase 7 owns Claude). Wire `task install` → `links:all` → `links:shell`. |
| `taskfiles/shell.yml` OR add to `links.yml` (planner picks) | taskfile (perf + shell-specific tasks) | request-response (`task perf:shell`) | `taskfiles/manifest.yml` (status-block + DOTFILES_MESSAGES patterns) | role-match | Hosts `task perf:shell` (SHEL-12). Uses `hyperfine` per STACK.md. |
| `Taskfile.yml` (UPDATE) | orchestration-root | n/a | `Taskfile.yml` (current) | exact | Flip `includes: links: ./taskfiles/links-stub.yml` to `./taskfiles/links.yml`. Optionally add `perf: ./taskfiles/shell.yml`. |

### Documentation

| New File | Role | Data Flow | Closest Analog | Match Quality | Notes |
|----------|------|-----------|----------------|---------------|-------|
| `shell/README.md` | documentation (sibling README) | n/a (prose) | `manifests/README.md` (P1) | role-match | Establishes the DOCS-02 template per CONTEXT.md "Claude's Discretion". Covers: purpose, key files, how to add an alias/function. |

---

## Pattern Assignments

### 1. `shell/.zshenv` (startup-script, sourced)

**Primary analog:** `zsh/.zshenv` (port lines 1-71 verbatim; replace 72-74).

**File-level comment-block header** (lines 1-27) — keep the docstring style verbatim (it correctly documents zsh startup order; the in-scope `Zsh startup order` comment is reused identically).

**XDG block** (lines 29-41, **port verbatim**):
```zsh
# while not a strict requirement, loosely follow the XDG Base Directory Specification
# https://specifications.freedesktop.org/basedir/latest/
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# setup data and config directories
export XDG_DATA_DIRS="/usr/local/share:/usr/share"
export XDG_CONFIG_DIRS="/etc/xdg"

# setup ZSH directory
export ZDOTDIR="${ZDOTDIR:-$XDG_CONFIG_HOME/zsh}"
```

**Locale/HISTFILE block** (lines 43-70, **port verbatim**) — HISTFILE, HIST_STAMPS, share-history, CLAUDE_CONFIG_DIR, EDITOR/VEDITOR/VISUAL, LANG/LC_ALL, BROWSER, SHELL_SESSIONS_DISABLE, __CF_USER_TEXT_ENCODING.

**REPLACE v1 lines 72-74** (the `DOTFILES_PROFILE` block — this is the SHEL-01 swap):
```zsh
# Read active machine from state surface (written by `task setup -- <name>`)
# .zshenv is sourced by non-interactive contexts (cron, scp) -- degrade gracefully.
# .zshrc handles the missing-machine warning for interactive shells (CF-05).
if [[ -r "${XDG_STATE_HOME}/dotfiles/machine" ]]; then
    DOTFILES_MACHINE="$(<${XDG_STATE_HOME}/dotfiles/machine)"
    export DOTFILES_MACHINE
fi
```

**Acceptance criteria for planner:**
- Sourced (no shebang executable bit needed; v1 has shebang for editor-only — keep it).
- No `DOTFILES_PROFILE` anywhere.
- `zsh -n` passes (LINT-07 already covers this dir).
- Sourcing under `set -u` (subshells) does not crash.

---

### 2. `shell/.zprofile` (startup-script, login)

**Primary analog:** `zsh/.zprofile`.

**Homebrew shellenv block** (lines 33-47, **port verbatim** — already detects via `uname -m`, no hardcoded paths):
```zsh
# MacOS
if [[ "$(uname)" == "Darwin" ]]; then
    if [[ "$(uname -m)" == "arm64" ]]; then
        DIRECTORY="/opt/homebrew/bin/brew"
    else
        DIRECTORY="/usr/local/bin/brew"
    fi
else
# Linux
    DIRECTORY="/home/linuxbrew/.linuxbrew/bin/brew"
fi

# ensure Homebrew is inserted into $PATH, $MANPATH, $INFOPATH
# and load $HOMEBREW_PREFIX, $HOMEBREW_CELLAR and $HOMEBREW_REPOSITORY into the environment
eval "$($DIRECTORY shellenv)"
```

**REPLACE v1 lines 49-57** (hostname check — CONCERNS bug). Planner has two options per CONTEXT.md "Claude's Discretion":

Option A — call `_dotfiles_feature` (function defined in `shell/functions/_dotfiles_feature.zsh`):
```zsh
# SSH Agent Configuration
# Manifest-driven: features.one-password-ssh declares 1Password availability.
# Servers default to system ssh-agent (feature flag = false in defaults.toml).
if [[ "$(_dotfiles_feature one-password-ssh)" == "true" ]]; then
    export SSH_AUTH_SOCK=~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock
fi
```

Option B (faster login start; requires `task setup` to write a sourced env file): read a precomputed env var. Planner picks.

**Acceptance criteria:**
- No literal `hostname -s` anywhere in the file.
- Sourcing under `set -e` does not abort on missing 1Password socket file (the export sets a non-existent path if 1Password isn't installed — that's a separate Phase 4 problem; P3 just sets the var when the feature is on).
- `[[ -x "$BREW" ]]`-style guard for the brew shellenv eval per SHEL-02 (planner adds; v1 is unguarded).

---

### 3. `shell/.zshrc` (startup-script, interactive)

**Primary analog:** `zsh/.zshrc` (port the overall shape; replace antigen block, collapse profile loops, add compinit cache + antidote bundle logic).

**Compinit + ZSH_COMPDUMP block** (lines 43-44, **port; ENHANCE per SHEL-10**):
```zsh
export ZSH_COMPDUMP="$XDG_CACHE_HOME/zsh/zcompcache"
mkdir -p "${ZSH_COMPDUMP%/*}"

# SHEL-10: compinit daily-rebuild cache.
# Skip security check (-C) when zcompdump is fresh; full check (-d) once per day.
autoload -Uz compinit
local _zcomp_age=0
if [[ -f "$ZSH_COMPDUMP" ]]; then
    _zcomp_age=$(( $(date +%s) - $(stat -f %m "$ZSH_COMPDUMP" 2>/dev/null || stat -c %Y "$ZSH_COMPDUMP" 2>/dev/null || echo 0) ))
fi
if (( _zcomp_age > 86400 )); then
    compinit -d "$ZSH_COMPDUMP"
else
    compinit -C -d "$ZSH_COMPDUMP"
fi
unset _zcomp_age
```
(Planner refines: zsh-idiomatic `glob.qualifiers` for mtime is `*(.mh+24)` — pick whichever is clearer.)

**REPLACE v1 lines 52-72 (antigen block)** with antidote bundle-cache (D-05 sketch from CONTEXT.md):
```zsh
# antidote: static bundle, lazy-rebuilt (D-01..D-05).
# Source: configs/antidote/zsh_plugins.txt (committed)
# Cache:  $XDG_CACHE_HOME/antidote/zsh_plugins.zsh (machine-local, never committed)
local _antidote_src="${DOTFILEDIR}/configs/antidote/zsh_plugins.txt"
local _antidote_cache="${XDG_CACHE_HOME}/antidote/zsh_plugins.zsh"
if [[ -n "$HOMEBREW_PREFIX" && -f "${HOMEBREW_PREFIX}/share/antidote/antidote.zsh" ]]; then
    source "${HOMEBREW_PREFIX}/share/antidote/antidote.zsh"
    if [[ ! -f "$_antidote_cache" || "$_antidote_src" -nt "$_antidote_cache" ]]; then
        mkdir -p "${_antidote_cache:h}"
        antidote bundle < "$_antidote_src" > "$_antidote_cache"
    fi
    source "$_antidote_cache"
else
    echo "$(tput setaf 3)Warning: antidote not found. Run 'task install' to complete setup.$(tput sgr0)" >&2
fi
```

**DOTFILEDIR symlink-walk** (lines 74-83, **port verbatim**):
```zsh
#  Find dotfile repo directory on this system, set $DOTFILEDIR to contain absolute path
SOURCE="${(%):-%N}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
    DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
ZSHDIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
DOTFILEDIR="$(dirname "$ZSHDIR")"
export DOTFILEDIR
```
**Note:** v1 derives `DOTFILEDIR` from the `zsh/` parent. In v2 the symlink target is `shell/.zshrc`, so `dirname` of the script's dir lands in the repo root the same way (parent of `shell/`). No change needed.

**Lazy conda init** (lines 86-94, **port verbatim**) — single block; no profile branching.

**VSCode integration** (lines 96-99, **port verbatim**).

**REPLACE v1 lines 105-129** (profile-conditional alias/function loops — D-09 collapse). Single flat glob each:
```zsh
# Load aliases (flat layout; per-file source-time or wrapper-function gates handle features)
for file in "${DOTFILEDIR}/shell/aliases/"*.zsh(.N); do
    source "$file"
done

# load common ZSH custom themes
source "${DOTFILEDIR}/shell/theme.zsh"

# Load functions (flat layout; one function per file)
for file in "${DOTFILEDIR}/shell/functions/"*.zsh(.N); do
    source "$file"
done
```

**ADD: missing-machine warning** (CF-05; only loud in interactive `.zshrc`):
```zsh
# Warn if no active machine -- interactive only (CF-05; missing-state pattern).
if [[ -z "${DOTFILES_MACHINE:-}" ]]; then
    echo "$(tput setaf 3)Warning: no active machine selected. Run: task setup -- <machine-name>$(tput sgr0)" >&2
fi
```

**Acceptance criteria:**
- `zsh -n` passes.
- No `DOTFILES_PROFILE` references.
- No profile-conditional `if [[ -d "...$DOTFILES_PROFILE" ]]` blocks (per D-09).
- `task perf:shell` reports cold-start ≤ 200ms on personal-laptop (SHEL-12).
- Antidote bundle cache is regenerated when `configs/antidote/zsh_plugins.txt` is touched.

---

### 4. `shell/.zlogin` (startup-script, login post-init)

**Primary analog:** `zsh/.zlogin` — port verbatim.

```zsh
# Display MOTD on login if function exists (may be profile-specific)
if (( $+functions[motd] )); then
    motd
fi
```

**Acceptance criteria:**
- No changes from v1.
- The `motd` function (`shell/functions/motd.zsh`) is responsible for the 24h-TTL cache (SHEL-11).

---

### 5. `shell/.zlogout` (startup-script, logout cleanup)

**Primary analog:** `zsh/.zlogout` — port verbatim (line 54):
```zsh
# Minimal default actions: flush history
fc -W 2>/dev/null || true
```

No v1 bugs. Comment block ports as-is.

---

### 6. `shell/theme.zsh` (sourced theme library)

**Primary analog:** `zsh/theme.zsh` — port **verbatim** per CF-02. All 100 lines.

Key blocks the planner must not modify:
- `local user`, `local pwd`, `local return_code`, `local git_branch`, `local time` prompt-segment vars (lines 19-23).
- `ZSH_THEME_GIT_PROMPT_*` exports (lines 25-39) — consumed by omz-git plugin loaded via antidote.
- `PROMPT` / `RPROMPT` assignments (lines 41-42).
- `man()` function with `LESS_TERMCAP_*` env (lines 57-67).
- `grc` alias loop (lines 73-99).

Acceptance: `zsh -n shell/theme.zsh` passes; prompt renders identically to v1 after antidote loads omz-git.

---

### 7. `shell/aliases/general.zsh` (alias-topic, ungated)

**Primary analog:** `zsh/aliases/common/general.zsh`.

**Port verbatim** lines 1-25, 33-37, 42-43 (skipping the four GUI-coupled lines):
```zsh
#!/bin/zsh

# reload current configuration
alias reload='source "$ZDOTDIR"/.zshrc'

# show current environment variables
alias environment="env"

# Print each PATH entry on a separate line
alias path='echo -e ${PATH//:/\\n} | highlight --syntax=bash'

# print the dotfile directory
alias dotfile='cd "$DOTFILEDIR"'
alias dotfiles='cd "$DOTFILEDIR"'

# enter ncdu
alias fsa='ncdu'

# shorthand for permissions function
alias perms='permissions'

# shorthands for directory listing
alias ls="$(command -v eza) --time-style long-iso"
alias ll='ls -alh'

# show last time macOS was installed
alias lastinstalled="ls -l /var/db/.AppleSetupDone"

# color history output
alias history="omz_history -t '%Y-%m-%d %I:%M:%S' | highlight --syntax=bash"

# task alias
alias t='task'
```

**EXTRACT** lines 27-31 (Finder) to `shell/aliases/finder.zsh`.
**EXTRACT** line 40 (Ghostty `g`) to `shell/aliases/ghostty.zsh`.
**ADD** `alias update='task install'` per CF-06 (planner decides whether to put it here or in `dotfiles.zsh`).

---

### 8. `shell/aliases/finder.zsh` (alias-topic, wrapper-function gated)

**Primary analog:** D-07 sketch in CONTEXT.md `<specifics>`; v1 source lines `zsh/aliases/common/general.zsh:27-31`.

**Exact pattern** (D-07 wrapper-function gate):
```zsh
#!/bin/zsh
# shell/aliases/finder.zsh -- Finder GUI aliases (gated on features.macos-finder)

function finder() {
    [[ "$(_dotfiles_feature macos-finder)" == "true" ]] \
        || { echo "finder: feature 'macos-finder' is disabled on this machine" >&2; return 1; }
    open -a Finder ./
}

function findershow() {
    [[ "$(_dotfiles_feature macos-finder)" == "true" ]] \
        || { echo "findershow: feature 'macos-finder' is disabled on this machine" >&2; return 1; }
    defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder
}

function finderhide() {
    [[ "$(_dotfiles_feature macos-finder)" == "true" ]] \
        || { echo "finderhide: feature 'macos-finder' is disabled on this machine" >&2; return 1; }
    defaults write com.apple.finder AppleShowAllFiles -bool false && killall Finder
}
```

Planner may DRY the gate into a single inline helper inside the file — but must not lift it into a shared library (that's overkill for three aliases).

---

### 9. `shell/aliases/ghostty.zsh` (alias-topic, wrapper-function gated)

**Primary analog:** D-07 sketch; v1 source `zsh/aliases/common/general.zsh:40`.

```zsh
#!/bin/zsh
# shell/aliases/ghostty.zsh -- Ghostty launcher alias (gated on features.ghostty)

function g() {
    [[ "$(_dotfiles_feature ghostty)" == "true" ]] \
        || { echo "g: feature 'ghostty' is disabled on this machine" >&2; return 1; }
    /Applications/Ghostty.app/Contents/MacOS/ghostty "$@"
}
```

---

### 10. `shell/aliases/hardware.zsh` (alias-topic, ungated)

**Primary analog:** `zsh/aliases/common/hardware.zsh` — port verbatim. All 9 aliases use `system_profiler` (macOS-only; OK per CONCERNS — v1 is macOS-only).

---

### 11. `shell/aliases/networking.zsh` (alias-topic, ungated)

**Primary analog:** `zsh/aliases/common/networking.zsh` — port verbatim. `traceroute=$(command -v trip) -u` works as long as trippy is in P5 core Brewfile.

---

### 12. `shell/aliases/jgrid.zsh` (alias-topic, source-time gated)

**Primary analog:** D-08 sketch in CONTEXT.md `<specifics>`; v1 source `zsh/aliases/personal/jgrid.zsh`.

**Exact pattern** (D-08 source-time gate — the bulk-loop exception):
```zsh
#!/bin/zsh
# shell/aliases/jgrid.zsh -- jgrid.net allomantic-metals ssh-jump aliases
# (gated on features.jgrid-net; source-time gate is the bulk-alias-loop exception per D-08)

[[ "$(_dotfiles_feature jgrid-net)" == "true" ]] || return 0

# This script inserts each of the allomantic metals into our current environment
# as ssh jump commands to each host using the local Cloudflared daemon.
METALS=(
    # standard metals
    "steel" "iron" "zinc" "brass" "pewter" "tin" "copper" "bronze"
    "duralumin" "aluminum" "gold" "electrum" "nicrosil" "chromium"
    "cadmium" "bendalloy"
    # God metals
    "atium" "malatium" "lerasium" "harmonium" "trellium" "raysium"
)

for i in $METALS; do
    alias $i="ssh josh@$i-ssh.jgrid.net"
done

unset METALS
```

22 metals, identical to v1.

---

### 13. `shell/functions/_dotfiles_feature.zsh` (function — net-new lazy helper)

**No v1 analog.** Use CONTEXT.md D-06 sketch verbatim:
```zsh
#!/bin/zsh
# shell/functions/_dotfiles_feature.zsh -- lazy manifest feature query.
#
# Sourced by: shell/.zshrc (function glob loop), shell/aliases/*.zsh (gated files).
# Reads:      $XDG_STATE_HOME/dotfiles/resolved.json (compiled by manifest:resolve).
# Caches:     $_DOTFILES_FEATURES associative array (per shell).
#
# Usage:      [[ "$(_dotfiles_feature macos-finder)" == "true" ]]

typeset -gA _DOTFILES_FEATURES
_dotfiles_features_loaded=0

function _dotfiles_feature() {
    local name="$1"
    if (( ! _dotfiles_features_loaded )); then
        local resolved="${XDG_STATE_HOME}/dotfiles/resolved.json"
        if [[ -r "$resolved" ]]; then
            while IFS='=' read -r k v; do
                _DOTFILES_FEATURES[$k]="$v"
            done < <(jq -r '.features | to_entries[] | "\(.key)=\(.value)"' "$resolved" 2>/dev/null)
        fi
        _dotfiles_features_loaded=1
    fi
    echo "${_DOTFILES_FEATURES[$name]:-false}"
}
```

**Acceptance criteria:**
- First call costs ~10ms (one jq invocation); subsequent calls O(1).
- Missing `resolved.json` → returns `"false"` for every feature (graceful degrade per integration-point note).
- Safe under `set -u` (`${...:-false}` default everywhere).
- Function name prefixed with `_` to signal "private helper, do not call directly from interactive prompt".

---

### 14. `shell/functions/motd.zsh` (function — cache-backed rewrite for SHEL-11)

**Primary analog:** `zsh/functions/motd.zsh` (port the rendering logic into a `_motd_render` helper; wrap with cache).

**v1 rendering pattern to preserve** (`zsh/functions/motd.zsh` lines 8-92) — Tron color scheme, fastfetch invocation, Tron quotes file. Port that block verbatim into a `_motd_render()` internal helper.

**NEW wrapper for SHEL-11** (planner picks exact mechanism; one viable shape):
```zsh
function motd() {
    local cache="${XDG_CACHE_HOME}/dotfiles/motd.cache"
    local ttl=86400  # 24h
    local now=$(date +%s)
    local mtime=0
    mkdir -p "${cache:h}"

    if [[ -f "$cache" ]]; then
        mtime=$(stat -f %m "$cache" 2>/dev/null || stat -c %Y "$cache" 2>/dev/null || echo 0)
        cat "$cache"
    fi

    if (( now - mtime > ttl )); then
        # Async refresh: regenerate in background so login isn't blocked.
        ( _motd_render > "${cache}.tmp" && mv "${cache}.tmp" "$cache" ) &!
    fi
}

function _motd_render() {
    # ... v1 motd.zsh body verbatim (lines 8-92) ...
}
```

**v1 cache-file dependencies** (lines 53, 77) still apply:
- `motd_sysinfo.jsonc` — currently at `zsh/configs/motd_sysinfo.jsonc`. Phase 7 moves it; in P3 keep the v1 path working until P7 cuts over (CONTEXT.md `<deferred>`).
- `motd_tron.txt` — same.

**Acceptance criteria:**
- First login on a fresh machine: empty cache → cold path renders synchronously and writes cache.
- Subsequent logins within 24h: display cached output instantly; no fastfetch invocation.
- Stale cache (>24h) triggers async refresh without blocking the prompt.

---

### 15. `shell/functions/aliaslist.zsh` and `functionlist.zsh` (functions — drop profile walk)

**Primary analog:** `zsh/functions/aliaslist.zsh`, `zsh/functions/functionlist.zsh`.

**Port pattern** (`aliaslist.zsh` lines 6-19) — keep the `_print_aliases_from_dir` helper:
```zsh
local -A dotfiles_aliases  # Associative array for O(1) lookup
local yellow=$(tput setaf 3) reset=$(tput sgr0)

_print_aliases_from_dir() {
    local dir="$1"
    for file in "$dir"/*.zsh(.N); do
        grep '^alias' "$file" 2>/dev/null | while IFS= read -r line; do
            local name="${line#alias }"
            name="${name%%=*}"
            dotfiles_aliases[$name]=1
            echo "$line" | highlight --syntax=bash
        done
    done
}
```

**REPLACE** v1 lines 21-34 (profile walk) with a single flat call:
```zsh
echo "${yellow}── Dotfiles ──${reset}"
_print_aliases_from_dir "${DOTFILEDIR}/shell/aliases"
```

System-alias loop (lines 36-41) ports verbatim.

`functionlist.zsh` follows the same shape (drop lines 14-24, keep the flat loop).

---

### 16. `shell/functions/sshlist.zsh` (function — rewrite for DOTFILES_MACHINE)

**Primary analog:** `zsh/functions/sshlist.zsh`.

**v1 issue:** references `DOTFILES_PROFILE` (lines 8, 19, 22, 29) and walks `ssh/configs/config-<profile>`. v2 has no `DOTFILES_PROFILE`.

**Planner options:**
1. Read `identity.ssh` from `resolved.json` via `jq` (or a new `_dotfiles_identity` helper) and use that as the suffix.
2. Glob `ssh/configs/config-*` and list all matched files.
3. Defer the per-identity portion to Phase 4 (IDNT-03 owns SSH wiring); in P3, `sshlist` just shows the main `ssh/configs/config` Host entries.

Option 3 is the safest P3 shape:
```zsh
function sshlist() {    #  sshlist() will list all configured SSH hosts. ex: $ sshlist
    echo "$(tput setaf 6)SSH Configurations:$(tput sgr0)"
    echo ""

    if [[ -f "$DOTFILEDIR/ssh/configs/config" ]]; then
        echo "$(tput setaf 3)── Main Config ──$(tput sgr0)"
        grep -E "^Host " "$DOTFILEDIR/ssh/configs/config" 2>/dev/null | \
            sed 's/Host /  /' | \
            highlight --syntax=conf --out-format=ansi 2>/dev/null || cat
    fi
    echo ""
    echo "$(tput setaf 8)Config file: $DOTFILEDIR/ssh/configs/config$(tput sgr0)"
}
```
Phase 4 can later extend it once identity wiring lands.

---

### 17. `shell/functions/pubkey.zsh` (function — cosmetic docstring fix)

**Primary analog:** `zsh/functions/pubkey.zsh` — port verbatim except line 4 docstring.

**Fix CONCERNS bug:**
- v1 line 4: `# pubkey() will copy a public key to the clipboard. ex: $ pubkey id_rsa_adobe.pub`
- v2: `# pubkey() will copy a public key to the clipboard. ex: $ pubkey id_ed25519_personal.pub`

---

### 18. `configs/antidote/zsh_plugins.txt` (config-file)

**Primary analog:** D-01 extracts from v1 `zsh/.zshrc:57-66` (antigen bundle lines).

**Exact contents** (D-01, copy verbatim):
```
ohmyzsh/ohmyzsh path:plugins/git
ohmyzsh/ohmyzsh path:plugins/colorize
ohmyzsh/ohmyzsh path:plugins/kubectl
ohmyzsh/ohmyzsh path:plugins/extract
zsh-users/zsh-syntax-highlighting
zsh-users/zsh-completions
zsh-users/zsh-autosuggestions
```

**Acceptance criteria:**
- File is plain text, no shell shebang, no executable bit.
- Symlinked into `${ZDOTDIR}/.zsh_plugins.txt` only if antidote requires it at a specific path; otherwise referenced by absolute path in `.zshrc` (planner picks — D-03 reads "symlinked through `_:safe-link` into `$ZDOTDIR/.zsh_plugins.txt` if needed").

---

### 19. `manifests/defaults.toml` (manifest — add three feature flags)

**Primary analog:** current `manifests/defaults.toml` lines 24-29.

**Port verbatim:**
```toml
[features]
one-password-ssh = false
motd = true
claude-marketplace = true
```

**ADD three flags** (D-12 + D-10 + D-09 working names; planner may rename per "Claude's Discretion → Feature flag naming"):
```toml
[features]
one-password-ssh = false
motd = true
claude-marketplace = true
macos-finder = false      # gates shell/aliases/finder.zsh
ghostty = false           # gates shell/aliases/ghostty.zsh
jgrid-net = false         # gates shell/aliases/jgrid.zsh
```

**Verify:** D-10 says `macos-finder` "already exists in `defaults.toml`/personal-laptop.toml" — current `manifests/defaults.toml` does NOT have it (only the machine TOMLs do). The planner MUST add it to defaults.toml per the schema-completeness contract (D-05 hybrid pattern in `manifests/defaults.toml` header).

**Machine manifest edits:**
- `manifests/machines/personal-laptop.toml`: add `ghostty = true`, `jgrid-net = true` (lines 15-23). `macos-finder = true` already present (line 18).
- `manifests/machines/work-laptop.toml`: add `ghostty = true`. (jgrid-net stays default false; see "Claude's Discretion → features.jgrid-net semantics".)
- `manifests/machines/server-1.toml`, `server-2.toml`: no edits — defaults serve them.

---

### 20. `taskfiles/links.yml` (taskfile — replaces stub)

**Primary analog:** `taskfiles/links.yml` (v1, current) — same purpose; structure ports with v2 source/target paths.

**Port the `_:safe-link` task call pattern** (v1 lines 28-39):
```yaml
zsh:
  desc: "Link zsh configuration files"
  cmds:
    - task: _:safe-link
      vars: { SOURCE: "{{.DOTFILEDIR}}/shell/.zshenv", TARGET: "{{.ZDOTDIR}}/.zshenv" }
    - task: _:safe-link
      vars: { SOURCE: "{{.DOTFILEDIR}}/shell/.zprofile", TARGET: "{{.ZDOTDIR}}/.zprofile" }
    - task: _:safe-link
      vars: { SOURCE: "{{.DOTFILEDIR}}/shell/.zshrc", TARGET: "{{.ZDOTDIR}}/.zshrc" }
    - task: _:safe-link
      vars: { SOURCE: "{{.DOTFILEDIR}}/shell/.zlogin", TARGET: "{{.ZDOTDIR}}/.zlogin" }
    - task: _:safe-link
      vars: { SOURCE: "{{.DOTFILEDIR}}/shell/.zlogout", TARGET: "{{.ZDOTDIR}}/.zlogout" }
  status:
    - test -L "{{.ZDOTDIR}}/.zshenv"
    - test -L "{{.ZDOTDIR}}/.zprofile"
    - test -L "{{.ZDOTDIR}}/.zshrc"
    - test -L "{{.ZDOTDIR}}/.zlogin"
    - test -L "{{.ZDOTDIR}}/.zlogout"
```

**ADD: antidote config link** (D-03 if planner picks the symlink path):
```yaml
antidote:
  desc: "Link antidote plugin manifest"
  cmds:
    - task: _:safe-link
      vars: { SOURCE: "{{.DOTFILEDIR}}/configs/antidote/zsh_plugins.txt", TARGET: "{{.ZDOTDIR}}/.zsh_plugins.txt" }
  status:
    - test -L "{{.ZDOTDIR}}/.zsh_plugins.txt"
```

**`all:` aggregator** (port from v1 lines 19-25):
```yaml
all:
  desc: "Create all symlinks (P3: shell only; later phases extend)"
  cmds:
    - task: zsh
    - task: antidote
```
(Drop v1's `git`, `ssh`, `tools`, `claude` for P3 — those land in P4/P5/P7.)

**Validation task** (port v1 lines 130-143 pattern):
```yaml
validate:
  desc: "Validate all common symlinks"
  cmds:
    - task: _:check-link
      vars: { TARGET: "{{.ZDOTDIR}}/.zshenv", NAME: "zshenv" }
    # ... etc for .zprofile, .zshrc, .zlogin, .zlogout, .zsh_plugins.txt
```

**Update `Taskfile.yml`:** flip the include from `./taskfiles/links-stub.yml` to `./taskfiles/links.yml` (line 83).

**Status-block convention** (PATTERNS Pattern from `taskfiles/manifest.yml:163-168`):
- Every install task has a `status:` block.
- Status blocks use `{{.X}}` template vars only, **never** `$X` shell vars (CLAUDE.md "Every install task has a status: block").

---

### 21. `taskfiles/shell.yml` (taskfile — perf task; planner may merge into `links.yml`)

**Primary analog for status pattern:** `taskfiles/manifest.yml:163-168`.

**Primary analog for hyperfine usage:** STACK.md line 65 (`hyperfine` recommendation).

**`task perf:shell` pattern** (SHEL-12; ≤200ms cold-start, fails CI):
```yaml
version: '3'

includes:
  _: ./helpers.yml

vars:
  DOTFILES_MESSAGES: |
    source '{{.DOTFILEDIR}}/install/messages.zsh'

tasks:
  # lint-allow: cmds-without-status (perf is always-re-run; not an idempotent install task)
  shell:
    desc: "Measure cold interactive zsh startup time (fails if > 200ms)"
    cmds:
      - |
        {{.DOTFILES_MESSAGES}}
        if ! command -v hyperfine >/dev/null 2>&1; then
          error "hyperfine not installed (brew install hyperfine)"
          exit 1
        fi
        # Cold-start: each run a fresh login interactive shell that exits immediately.
        result=$(hyperfine --warmup 1 --runs 5 --export-json /dev/stdout \
            "zsh -lic exit" 2>/dev/null \
            | jq -r '.results[0].mean')
        ms=$(echo "$result * 1000" | bc | awk '{printf "%d\n", $0}')
        info "cold shell start: ${ms}ms (target: ≤ 200ms)"
        if (( ms > 200 )); then
            error "shell start exceeds 200ms target (SHEL-12)"
            exit 1
        fi
        check "shell start within budget"
```

**Acceptance criteria:**
- Exits non-zero on a converged personal-laptop with cold-start > 200ms.
- Uses hyperfine (STACK.md line 65; brew-installed in P5).
- Read-only task — no manifest dependency, no cutover gate.

---

### 22. `shell/README.md` (documentation)

**Primary analog:** `manifests/README.md` — same terse, declarative, scoped style.

**Recommended structure** (DOCS-02 contract anchor per CONTEXT.md "Claude's Discretion → Sibling-README pattern propagation"):
```markdown
# shell

Zsh startup files, theme, aliases, and functions. Sourced by every login or
interactive shell on a converged v2 machine.

## Key files

- `.zshenv`, `.zprofile`, `.zshrc`, `.zlogin`, `.zlogout` — startup files in
  zsh's documented order.
- `theme.zsh` — alanpeabody-based prompt; consumed by .zshrc after antidote
  loads omz-git.
- `aliases/<topic>.zsh` — flat layout, one topic per file. Gating happens
  inside the file (wrapper functions for 1-3 aliases; source-time `return 0`
  for bulk-alias loops).
- `functions/<name>.zsh` — flat layout, one function per file. Filename
  matches the function name.

## Adding a pattern

- **An alias:** create `aliases/<topic>.zsh`. If gated, call
  `_dotfiles_feature <name>` inside each wrapper function (small files) or
  prepend a source-time gate (bulk loops). Source-time gate pattern:
  `[[ "$(_dotfiles_feature foo)" == "true" ]] || return 0`.
- **A function:** create `functions/<name>.zsh`; filename equals the function
  name. Add a docstring on the function-definition line.
- **A feature flag:** add the key (kebab-case) to `manifests/defaults.toml`
  `[features]` with `false`. Set `true` in the machine TOMLs that want it.

## Performance budget

Cold interactive shell start: ≤ 200ms. Measured via `task perf:shell`
(SHEL-12). Re-measure on every plugin change.
```

---

## Shared Patterns

### Shared 1: File-level comment-block header

**Source:** `install/resolver.zsh:1-30`, `install/cutover-gate.zsh:1-21`, every v1 startup file.

**Apply to:** every new `.zsh` file (executable AND sourced — convention is repo-wide per global CLAUDE.md "File-level comment block at the top of every script explaining its purpose, callers, and side effects").

**Concrete excerpt** (`install/cutover-gate.zsh:1-21`):
```zsh
#!/bin/zsh
# -----------------------------------------------------------------------------
# install/cutover-gate.zsh -- enforce per-machine cutover-ack sentinel.
#
# Sourced by:
#   - bootstrap.zsh (called BEFORE printing next-step hint)
#   - Taskfile.yml (preconditions: block on `task install`)
#
# Reads: $XDG_STATE_HOME/dotfiles/cutover-ack    (single line: <name> <ts>)
#        $XDG_STATE_HOME/dotfiles/machine        (active machine name)
# Exits: cutover_gate_check returns 1 on missing/invalid/mismatched sentinel
#        cutover_gate_check returns 0 on valid sentinel for active machine
# -----------------------------------------------------------------------------
```

P3's shell files follow this pattern (the v1 `.zshenv`/`.zprofile`/`.zlogin`/`.zlogout` already have it; port the comment blocks verbatim and update the "Purpose" line if behaviour changed).

---

### Shared 2: `_dotfiles_feature` lazy helper invocation

**Source:** D-06 sketch + `manifests/test/...` jq invocation patterns.

**Apply to:** `shell/aliases/finder.zsh`, `shell/aliases/ghostty.zsh`, `shell/aliases/jgrid.zsh`, possibly `shell/.zprofile`.

**Caller pattern** (always `[[ ... == "true" ]]`):
```zsh
[[ "$(_dotfiles_feature <name>)" == "true" ]] || return 0   # source-time gate
# OR
[[ "$(_dotfiles_feature <name>)" == "true" ]] \
    || { echo "<func>: feature '<name>' is disabled on this machine" >&2; return 1; }
```

---

### Shared 3: Messages library sourcing under `set -u`

**Source:** `install/resolver.zsh:32-40`, `install/cutover-gate.zsh:26-27`.

**Apply to:** any taskfile cmd block or executable `.zsh` that uses `info`/`success`/`warn`/`error`/`check`/`cross`. **The shell startup files do NOT use this** — they use `tput` directly to avoid sourcing overhead.

**Concrete excerpt** (`install/resolver.zsh:32-40`):
```zsh
: "${DOTFILEDIR:?DOTFILEDIR not set -- run via 'task manifest:*' or export it manually}"
: "${DOTFILES_MESSAGES_LOADED:=}"
if [[ -z "$DOTFILES_MESSAGES_LOADED" ]]; then
  source "${DOTFILEDIR}/install/messages.zsh"
fi
```

For `taskfiles/shell.yml`: use the cleaner `{{.DOTFILES_MESSAGES}}` template var as in `taskfiles/manifest.yml`.

---

### Shared 4: Status-block convention (LINT-02 compliance)

**Source:** `taskfiles/manifest.yml:148-168`, `taskfiles/links.yml:40-45`, CLAUDE.md "Every install task has a `status:` block".

**Apply to:** every install-style task in `taskfiles/links.yml`. (`task perf:shell` is exempt — it's a measurement, not an install operation; mark with `# lint-allow: cmds-without-status`.)

**Concrete excerpt** (`taskfiles/manifest.yml:163-168`):
```yaml
# S4: status blocks use {{.X}} template vars only -- never $X shell vars.
status:
  - test -f "{{.RESOLVED_JSON_PATH}}"
  - |
    out=$(find "{{.DOTFILEDIR}}/manifests" \( -name 'defaults.toml' -o -path '*/machines/*.toml' \) -newer "{{.RESOLVED_JSON_PATH}}" -print -quit 2>/dev/null)
    [ -z "$out" ]
```

**Critical:** never use `$RESOLVED_JSON_PATH` inside `status:` — the macos:shell:145 bug class. The lint suite (LINT-02) catches this if missed.

---

### Shared 5: `_:safe-link` for every symlink (no bare `ln`)

**Source:** `taskfiles/helpers.yml:25-37`.

**Apply to:** every `links.yml` symlink creation. Never `ln -s` outside `helpers.yml` (LINT-03b).

**Concrete excerpt** (`taskfiles/helpers.yml:25-37`):
```yaml
safe-link:
  desc: "Create a symlink with automatic parent directory creation"
  internal: true
  requires:
    vars: [SOURCE, TARGET]
  cmds:
    - mkdir -p "$(dirname "{{.TARGET}}")"
    - ln -sfn "{{.SOURCE}}" "{{.TARGET}}"
```

---

### Shared 6: Function docstring convention (sourced-discoverability)

**Source:** every v1 `zsh/functions/*.zsh`.

**Apply to:** every `shell/functions/*.zsh` (so `functionlist` can grep them).

**Pattern** (single-line docstring on the function-definition line — keep verbatim from v1):
```zsh
function mkcd() {    # mkcd() will create a directory and cd into it. ex: $ mkcd new-project
    mkdir -p "$1" && cd "$1"
}
```

The `aliaslist`/`functionlist` functions grep the `function` line for documentation; preserving the inline-comment convention is the contract.

---

## v1 Bugs to Fix in Transit

These are listed in `.planning/codebase/CONCERNS.md` and CONTEXT.md `<code_context>`. The planner MUST emit acceptance criteria that prove each fix landed.

| Bug | v1 Location | v2 Fix Location | Fix |
|-----|-------------|-----------------|-----|
| Hostname-based SSH agent dispatch | `zsh/.zprofile:55-56` | `shell/.zprofile` | Replace `hostname -s != "server"` with `_dotfiles_feature one-password-ssh` (or precomputed env var per planner choice). |
| `DOTFILES_PROFILE` references in functions | `zsh/functions/aliaslist.zsh:26-34`, `functionlist.zsh:14-24`, `sshlist.zsh:8,19,22,29` | corresponding `shell/functions/*.zsh` | Drop profile-subdir walks; flat `shell/aliases/` and `shell/functions/` only. `sshlist` may defer per-identity portion to Phase 4. |
| `DOTFILES_PROFILE` in `.zshrc` profile-conditional loops | `zsh/.zshrc:105-129` | `shell/.zshrc` | Collapse to flat globs per D-09. |
| Synchronous MOTD on every login (~200ms cost) | `zsh/.zlogin:17-19` → `zsh/functions/motd.zsh` | `shell/functions/motd.zsh` | 24h-TTL cache (SHEL-11). `.zlogin` dispatch unchanged. |
| Antigen plugin manager (archived since 2018; cold-start cost) | `zsh/.zshrc:52-72` | `shell/.zshrc`, `configs/antidote/zsh_plugins.txt` | Antidote static bundle (D-01..D-05, SHEL-04). |
| `pubkey.zsh` docstring references deprecated `id_rsa_adobe.pub` | `zsh/functions/pubkey.zsh:4` | `shell/functions/pubkey.zsh` | Update example to `id_ed25519_personal.pub`. |
| compinit runs per shell start | `zsh/.zshrc:25` (docs only — v1 doesn't even invoke compinit explicitly) | `shell/.zshrc` | Daily-cache pattern (SHEL-10): `-d` once per 24h, `-C` fast path otherwise. |

**Bugs explicitly NOT P3's responsibility:**
- `claude/hooks/agent-transparency.zsh` `local`-at-script-scope (CONCERNS) — Phase 7.
- `bootstrap.zsh:2` `set -e` (CONCERNS) — Phase 2 (already fixed; verified).
- `taskfiles/macos.yml:145` `$BREW_ZSH` in status (CONCERNS) — v1 file; v2 doesn't include `macos.yml` until P6.

---

## No Analog Found

Files with no close v1 analog — planner uses CONTEXT.md sketches directly:

| File | Role | Reason | Reference |
|------|------|--------|-----------|
| `shell/functions/_dotfiles_feature.zsh` | function (lazy manifest reader) | Net-new helper for D-06; no v1 precedent. | CONTEXT.md `<specifics>` D-06 sketch (already a complete implementation; planner refines edge cases). |
| `configs/antidote/zsh_plugins.txt` | declarative plugin list | Data format swap (antigen-imperative → antidote-declarative). | D-01 lists the seven lines verbatim. |
| Antidote bundle-cache logic in `.zshrc` | startup-shell logic | Antidote-specific; no v1 antigen-side equivalent. | CONTEXT.md `<specifics>` ".zshrc antidote block sketch" — mtime check + `antidote bundle` invocation. |
| MOTD cache wrapper | function (display + async refresh) | SHEL-11 is net-new behaviour. | This document Pattern 14 + CONTEXT.md "Claude's Discretion → MOTD cache architecture". |
| `task perf:shell` | measurement task | SHEL-12 is net-new requirement. | This document Pattern 21 + STACK.md line 65 (hyperfine). |
| compinit daily-rebuild cache | startup-shell logic | SHEL-10 is net-new behaviour (v1 didn't even call compinit). | This document Pattern 3 + CONTEXT.md "Claude's Discretion → compinit daily-rebuild cache". |

---

## Metadata

**Analog search scope:**
- `/Users/josh/Git/personal/dotfiles/zsh/` (5 startup files + theme + aliases/{common,personal} + 24 function files)
- `/Users/josh/Git/personal/dotfiles/taskfiles/` (links.yml, helpers.yml, manifest.yml, links-stub.yml, lint.yml)
- `/Users/josh/Git/personal/dotfiles/install/` (messages.zsh, resolver.zsh, cutover-gate.zsh)
- `/Users/josh/Git/personal/dotfiles/manifests/` (defaults.toml, machines/*.toml, README.md)
- `/Users/josh/Git/personal/dotfiles/.planning/` (CONCERNS.md, REQUIREMENTS.md, STATE.md, prior phase plans + PATTERNS.md)

**Files scanned:** ~50 (every v1 zsh file plus v2 infrastructure files).

**Pattern extraction date:** 2026-05-14

**Phase:** 03-shell-layer-flat-content-port
