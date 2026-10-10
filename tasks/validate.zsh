#!/bin/zsh

# =============================================================================
# tasks/validate.zsh -- read the whole declared state back from the live system
#
# Purpose:      Nix activates state but never reads it back. This takes the
#               evaluated declaration (JSON on stdin, produced by `task
#               validate` via nix eval) and verifies, domain by domain, that
#               the machine matches it: shell plumbing, hostname, every link,
#               the profile identity (git email, ssh agent), every Homebrew
#               package and cask artifact, the jshvn/ai checkout, and every
#               macOS default plus the display preset, the Spotlight hotkey
#               and the application firewall.
#               One check/cross line per item; exits 1 on any drift.
# Depends on:   jq; git; brew; defaults; dscl; PlistBuddy; scutil; ssh-add;
#               socketfilterfw; swift (Xcode CLT); tasks/messages.zsh;
#               system/display-mode.swift; MACHINE env var (the selected
#               machine name, optional).
# Side effects: none (read-only; one temp file for the Brewfile).
# =============================================================================

set -euo pipefail

typeset -r HERE="${0:A:h}"
typeset -r ROOT="${HERE:h}"
source "$HERE/messages.zsh"
# read-only: brew must not update itself mid-check
export HOMEBREW_NO_AUTO_UPDATE=1

declared=$(cat)
if ! jq -e '.dotfiles | type == "object"' <<< "$declared" >/dev/null 2>&1; then
  cross "no declaration on stdin (expected the JSON task validate produces with nix eval)"
  exit 1
fi
j() { jq -r "$1" <<< "$declared"; }

typeset -r CHECKOUT="$(j .dotfiles.checkout)"
typeset -r PROFILE="$(j .dotfiles.profile)"
typeset -r STATE="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
failed=0
fail() {
  cross "$1"
  failed=1
}

# --- shell plumbing ----------------------------------------------------------
info "shell"
for dir in "${XDG_CONFIG_HOME:-$HOME/.config}" "${XDG_DATA_HOME:-$HOME/.local/share}" \
           "${XDG_STATE_HOME:-$HOME/.local/state}" "${XDG_CACHE_HOME:-$HOME/.cache}" \
           "${ZDOTDIR:-$HOME/.config/zsh}"; do
  if [[ -d "$dir" ]]; then check "dir $dir"; else fail "dir $dir missing"; fi
done
if [[ -f /etc/zshenv ]] && grep -qF 'ZDOTDIR="$HOME/.config/zsh"' /etc/zshenv; then
  check "/etc/zshenv exports ZDOTDIR"
else
  fail "/etc/zshenv does not export ZDOTDIR (nix-darwin environment.etc.zshenv)"
fi
login_shell=$(j .loginShell)
have_shell=$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{ print $2 }')
if [[ "$have_shell" == "$login_shell" && -x "$login_shell" ]]; then
  check "login shell $login_shell"
else
  fail "login shell: expected $login_shell, got ${have_shell:-<unset>}"
fi
if grep -qxF "$login_shell" /etc/shells 2>/dev/null; then
  check "/etc/shells lists $login_shell"
else
  fail "/etc/shells does not list $login_shell"
fi
if [[ -r "$STATE/machine" ]]; then
  if [[ -z "${MACHINE:-}" || "$(<"$STATE/machine")" == "$MACHINE" ]]; then
    check "machine state file: $(<"$STATE/machine")"
  else
    fail "machine state file says '$(<"$STATE/machine")', validating '$MACHINE'"
  fi
else
  fail "machine state file missing (task setup -- <name>)"
fi

# --- hostname ----------------------------------------------------------------
info "hostname"
want=$(j .hostName)
have=$(scutil --get LocalHostName 2>/dev/null || echo "<unset>")
if [[ "$have" == "$want" ]]; then check "LocalHostName = $want"; else fail "LocalHostName: expected '$want', got '$have'"; fi

# --- links: every registered link resolves to its source in the checkout -----
info "links"
while IFS=$'\t' read -r target source; do
  [[ -n "$target" ]] || continue
  # not `path`: in zsh that is the array tied to $PATH
  link="$HOME/$target"
  want="$(readlink -f "$CHECKOUT/$source" 2>/dev/null || echo "$CHECKOUT/$source")"
  if [[ -L "$link" && "$(readlink -f "$link" 2>/dev/null)" == "$want" ]]; then
    check "~/$target -> $source"
  elif [[ -L "$link" ]]; then
    fail "~/$target -> $(readlink -f "$link" 2>/dev/null || readlink "$link"), expected $source"
  else
    fail "~/$target is not a symlink (expected -> $source)"
  fi
done < <(j '.dotfiles.links | to_entries[] | [.key, .value] | @tsv')

# --- profile identity: stray files, git email, the 1Password agent ------------
info "profile ($PROFILE)"
typeset -r PROFILE_DIR="profiles/$PROFILE"
# profiles/.gitignore allows a profile directory exactly five files; anything else it ignores
# (a private key, say) is a cross. Finder's .DS_Store is not.
stray=$(git -C "$CHECKOUT" ls-files --others --ignored --exclude-standard -- profiles | grep -v '/\.DS_Store$' || true)
if [[ -z "$stray" ]]; then
  check "profiles/: no file beyond the five a profile holds"
else
  for f in ${(f)stray}; do fail "$f: not a profile file (profiles/.gitignore); a private key never belongs here"; done
fi
expected_email=$(git config -f "$CHECKOUT/$PROFILE_DIR/git" user.email 2>/dev/null || true)
if [[ -z "$expected_email" ]]; then
  warn "$PROFILE_DIR/git sets no user.email, git email check skipped"
else
  actual_email=$(git -C "$CHECKOUT" config user.email 2>/dev/null || true)
  if [[ "$actual_email" == "$expected_email" ]]; then
    check "git user.email = $expected_email (this checkout, through ~/.config/git/profile)"
  else
    fail "git user.email in this checkout: expected '$expected_email', got '$actual_email'"
  fi
fi
if [[ "${SSH_AUTH_SOCK:-}" == *2BUA8C4S2C.com.1password* ]]; then
  check "SSH_AUTH_SOCK is the 1Password agent (env.d)"
else
  fail "SSH_AUTH_SOCK is '${SSH_AUTH_SOCK:-}', expected the 1Password agent socket (env.d/1password.zsh)"
fi
pub="$CHECKOUT/$PROFILE_DIR/key.pub"
body=$(awk '$1 ~ /^(ssh-|ecdsa-|sk-)/ {print $2; exit}' "$pub" 2>/dev/null || true)
if [[ -z "$body" ]]; then
  warn "no real public key at $PROFILE_DIR/key.pub, ssh-add check skipped"
elif ssh-add -L 2>/dev/null | awk '$1 ~ /^(ssh-|ecdsa-|sk-)/ {print $2}' | grep -qF "$body"; then
  check "ssh-add -L offers $PROFILE_DIR/key.pub"
else
  fail "ssh-add -L does not offer $PROFILE_DIR/key.pub"
fi

# --- packages: brew bundle check, then every cask's app artifact ------------
info "packages"
brewfile=$(mktemp)
trap 'rm -f "$brewfile"' EXIT
j .brewfile > "$brewfile"
if brew bundle check --no-upgrade --file="$brewfile" >/dev/null 2>&1; then
  check "brew bundle check: every declared formula, cask, mas app and extension is installed"
else
  fail "brew bundle check:"
  # the detail exits 1 as well; the cross is recorded, so keep reading the other domains
  brew bundle check --no-upgrade --verbose --file="$brewfile" 2>&1 | sed 's/^/      /' || true
fi
installed=$(brew info --installed --json=v2 2>/dev/null || echo '{}')
# homebrew.casks is a list of records (name, args, greedy ...), so take the name
for cask in ${(f)"$(j '.casks[].name')"}; do
  token="${cask##*/}"
  record=$(jq -c --arg t "$token" '.casks[]? | select(.token == $t)' <<< "$installed")
  if [[ -z "$record" ]]; then
    fail "cask $token: declared but not in brew info --installed"
    continue
  fi
  apps=(${(f)"$(jq -r '[.artifacts[]? | .app[]? | strings] | .[]' <<< "$record")"})
  if (( ${#apps} == 0 )); then
    check "cask $token installed (no app artifact to probe)"
  fi
  for app in $apps; do
    if [[ -e "/Applications/$app" ]]; then check "cask $token: /Applications/$app"; else fail "cask $token: /Applications/$app missing"; fi
  done
done

# --- claude-code: the jshvn/ai checkout at its ref ---------------------------
if [[ "$(j '.dotfiles.apps."claude-code".enable')" == true ]]; then
  info "claude-code"
  dir=$(j '.dotfiles.apps."claude-code".dir')
  ref=$(j '.dotfiles.apps."claude-code".ref')
  if ! git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    fail "no checkout at $dir"
  else
    head=$(git -C "$dir" rev-parse HEAD)
    branch=$(git -C "$dir" symbolic-ref -q --short HEAD 2>/dev/null || true)
    tag=$(git -C "$dir" rev-parse -q --verify "refs/tags/$ref^{commit}" 2>/dev/null || true)
    if [[ "$branch" == "$ref" || "$tag" == "$head" || "$head" == "$ref"* ]]; then
      check "$dir at $ref"
    else
      fail "$dir is at ${branch:-${head:0:12}}, declared $ref"
    fi
    if [[ -f "$dir/Taskfile.yml" ]]; then
      if task -d "$dir" validate >/dev/null 2>&1; then check "ai repo: task validate passed"; else fail "ai repo: task validate failed (run: task -d $dir validate)"; fi
    fi
  fi
fi

# --- macOS defaults ----------------------------------------------------------
info "system"
# nix-darwin option group -> the domain nix-darwin writes it to
# (nix-darwin modules/system/defaults-write.nix). A group with values and no
# row here is a cross, so a newly used group forces a row.
typeset -A DOMAIN=(
  NSGlobalDomain  -g
  dock            com.apple.dock
  finder          com.apple.finder
  screencapture   com.apple.screencapture
  WindowManager   com.apple.WindowManager
  loginwindow     /Library/Preferences/com.apple.loginwindow
  trackpad        com.apple.AppleMultitouchTrackpad
  controlcenter   com.apple.controlcenter
  menuExtraClock  com.apple.menuextra.clock
  screensaver     com.apple.screensaver
)

# compare DOMAIN KEY EXPECTED TYPE [SCOPE]: one defaults read, bools read back
# as 1/0, numbers compared numerically
compare() {
  local domain="$1" key="$2" expected="$3" type="$4" scope="${5:-}"
  local current label="${domain}.${key}${scope:+ (${scope#-})}"
  current=$(defaults ${scope:+$scope} read "$domain" "$key" 2>/dev/null || echo "<unset>")
  case "$type" in
    boolean) [[ "$expected" == true ]] && expected=1 || expected=0 ;;
  esac
  if [[ "$current" == "$expected" ]] ||
     { [[ "$type" == number && "$current" != "<unset>" ]] && (( current == expected )); }; then
    check "$label = $expected"
  else
    fail "$label: expected '$expected', got '$current'"
  fi
}

# a group nix eval could not serialise (tryEval failed): fine for a removed
# group nothing here uses, a cross for one the DOMAIN table expects values from
for group in ${(f)"$(j '.defaults | to_entries[] | select(.value == "<error>") | .key')"}; do
  [[ -n "$group" && -n "${DOMAIN[$group]:-}" ]] || continue
  fail "$group: failed to evaluate (removed or broken nix-darwin group)"
done

while IFS=$'\t' read -r group key value type; do
  [[ -n "$group" ]] || continue
  if [[ -z "${DOMAIN[$group]:-}" ]]; then
    fail "$group.$key: no domain mapping for nix-darwin group '$group' (add it to DOMAIN)"
    continue
  fi
  compare "${DOMAIN[$group]}" "$key" "$value" "$type"
done < <(j '
  .defaults | to_entries[]
  | select(.key != "CustomUserPreferences" and .key != "CustomSystemPreferences" and (.value | type) == "object")
  | .key as $g | .value | to_entries[]
  | select(.value != null and (.value | type) != "object" and (.value | type) != "array")
  | [$g, .key, (.value | tostring), (.value | type)] | @tsv')

while IFS=$'\t' read -r domain key value type; do
  [[ -n "$domain" ]] || continue
  [[ "$domain" == NSGlobalDomain ]] && domain=-g
  compare "$domain" "$key" "$value" "$type"
done < <(j '
  (.defaults.CustomUserPreferences // {}) | to_entries[]
  | .key as $d | .value | to_entries[] | select(.value != null)
  | [$d, .key, (.value | tostring), (.value | type)] | @tsv')

while IFS=$'\t' read -r domain key value type; do
  [[ -n "$domain" ]] || continue
  compare "$domain" "$key" "$value" "$type" -currentHost
done < <(j '
  (.currentHost // {}) | to_entries[]
  | .key as $d | .value | to_entries[] | select(.value != null)
  | [$d, .key, (.value | tostring), (.value | type)] | @tsv')

# display-mode.swift verify exits 0 at More Space, 1 in another mode, 2 with no active built-in
# panel or no HiDPI mode (lid closed on a dock, a mirrored display), 64 on usage. Exit 2 leaves
# nothing to read back, which is not drift.
if [[ "$(j .dotfiles.system.display)" == true ]]; then
  rc=0
  out=$(swift "$ROOT/system/display-mode.swift" verify 2>&1) || rc=$?
  case $rc in
    0) check "display.builtin = More Space ($out)" ;;
    2) warn "display.builtin: not checked, no active built-in panel ($out)" ;;
    *) fail "display.builtin: $out" ;;
  esac
fi

# --getglobalstate needs no sudo: "Firewall is enabled. (State = 1)", or State = 2 for on and
# block-all, both enabled; State = 0 is off
if [[ "$(j .dotfiles.system.security)" == true ]]; then
  fw=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>&1 || true)
  if [[ "$fw" == *'(State = '[12]')'* ]]; then
    check "security.firewall = enabled"
  else
    fail "security.firewall: expected enabled, got '${fw:-<unset>}'"
  fi
fi

if [[ "$(j '.dotfiles.apps.raycast.enable and .dotfiles.apps.raycast.freeCmdSpace')" == true ]]; then
  tmp=$(mktemp)
  defaults export com.apple.symbolichotkeys "$tmp" 2>/dev/null || true
  enabled=$(/usr/libexec/PlistBuddy -c 'Print :AppleSymbolicHotKeys:64:enabled' "$tmp" 2>/dev/null || echo "<unset>")
  rm -f "$tmp"
  if [[ "$enabled" == false || "$enabled" == 0 ]]; then
    check "spotlight.cmd-space disabled (freed for Raycast)"
  else
    fail "spotlight.cmd-space: expected disabled, got enabled='$enabled'"
  fi
fi

exit $failed
