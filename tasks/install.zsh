#!/bin/zsh

# =============================================================================
# tasks/install.zsh -- build, switch, then uninstall what is no longer declared
#
# Purpose:      The body of `task install`, the same on a Mac's first run and
#               every later one. Takes the evaluated declaration on stdin.
#               Builds the selected machine's closure (nothing changes if that
#               fails); on a Mac where nix-darwin is not active yet, clears the
#               paths home-manager will link and moves /etc/zshenv and
#               /etc/shells aside; switches with the built darwin-rebuild; then
#               lets brew uninstall what is installed beyond the declaration
#               only with consent: its own prompt on the terminal, or --yes.
# Depends on:   DOTFILEDIR, MACHINE, NIX env vars (NIX_CONFIG when set); jq;
#               brew (under the declaration's brewPrefix, which the switch
#               installs when missing); sudo; tasks/messages.zsh;
#               tasks/clear-links.zsh.
# Side effects: writes the `result` link in the checkout; on a first switch,
#               removes or renames paths under $HOME and (sudo) renames
#               /etc/zshenv and /etc/shells; activates the system (sudo);
#               uninstalls Homebrew packages after consent.
# =============================================================================

set -euo pipefail

typeset -r HERE="${0:A:h}"
source "$HERE/messages.zsh"
: "${DOTFILEDIR:?}" "${MACHINE:?}" "${NIX:?}"

yes=0
[[ "${1:-}" == --yes ]] && yes=1

declared=$(cat)
if ! jq -e '.dotfiles | type == "object"' <<< "$declared" >/dev/null 2>&1; then
  cross "no declaration on stdin (expected the JSON task install produces with nix eval)"
  exit 1
fi

# --- build: nothing on the machine changes unless this succeeds --------------
info "building $MACHINE"
"$NIX" build "$DOTFILEDIR#darwinConfigurations.$MACHINE.system" --out-link "$DOTFILEDIR/result"

# --- first switch: clear the way for home-manager and nix-darwin -------------
if [[ ! -e /run/current-system ]]; then
  info "first switch on this Mac: clearing the paths home-manager will link"
  jq -r '.dotfiles.links | keys[]' <<< "$declared" | zsh "$HERE/clear-links.zsh"
  # nix-darwin refuses /etc files it did not write
  sudo sh -c 'for f in /etc/zshenv /etc/shells; do if [ -f "$f" ] && [ ! -L "$f" ]; then mv "$f" "$f.before-nix-darwin"; fi; done'
fi

# --- switch --------------------------------------------------------------------
sudo env NIX_CONFIG="${NIX_CONFIG:-}" "$DOTFILEDIR/result/sw/bin/darwin-rebuild" switch --flake "$DOTFILEDIR#$MACHINE"

# --- uninstall what is no longer declared, with consent ------------------------
# the switch already updated Homebrew; stdin from /dev/null keeps brew from prompting on the dry
# run, which exits 1 only when something would be uninstalled (or brew fails, which removes nothing).
# A first switch installs Homebrew, so this shell may not have it on its PATH yet.
export PATH="$(jq -r .brewPrefix <<< "$declared")/bin:$PATH"
export HOMEBREW_NO_AUTO_UPDATE=1
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
jq -r .brewfile <<< "$declared" > "$tmp/Brewfile"
if brew bundle cleanup --file="$tmp/Brewfile" < /dev/null > /dev/null 2>&1; then
  check "nothing installed beyond the declaration"
elif (( yes )); then
  brew bundle cleanup --force --file="$tmp/Brewfile"
elif { : < /dev/tty } 2>/dev/null; then
  # brew lists what it would uninstall and asks; only an explicit yes removes anything
  brew bundle cleanup --file="$tmp/Brewfile" < /dev/tty ||
    info "nothing uninstalled; task audit lists what stays beyond the declaration"
else
  brew bundle cleanup --file="$tmp/Brewfile" < /dev/null || true
  warn "nothing uninstalled: no terminal to ask (task install -- --yes uninstalls the list above)"
fi
