#!/bin/zsh

# =============================================================================
# tasks/install.zsh -- build, switch, then list what is no longer declared
#
# Purpose:      The body of `task install`, the same on a Mac's first run and
#               every later one. Takes the evaluated declaration on stdin.
#               Stops unless it runs from dotfiles.checkout. Builds the selected machine's closure (nothing changes if that
#               fails); on a Mac where nix-darwin is not active yet, clears the
#               paths home-manager will link and moves /etc/zshenv and
#               /etc/shells aside; switches with the built darwin-rebuild; then
#               lists what is installed beyond the declaration (prune.zsh
#               --list), which only `task prune` uninstalls; then warns about
#               each pin the install does not move (install-pins.zsh).
# Depends on:   DOTFILEDIR, MACHINE, NIX env vars (NIX_CONFIG when set); jq;
#               sudo; tasks/messages.zsh; tasks/install-clear-links.zsh;
#               tasks/prune.zsh; tasks/install-pins.zsh.
# Side effects: writes the `result` link in the checkout; on a first switch,
#               removes or renames paths under $HOME and (sudo) renames
#               /etc/zshenv and /etc/shells; activates the system (sudo).
# =============================================================================

set -euo pipefail

typeset -r HERE="${0:A:h}"
source "$HERE/messages.zsh"
: "${DOTFILEDIR:?}" "${MACHINE:?}" "${NIX:?}"

declared=$(cat)
if ! jq -e '.dotfiles | type == "object"' <<< "$declared" >/dev/null 2>&1; then
  cross "no declaration on stdin (expected the JSON task install produces with nix eval)"
  exit 1
fi

# --- the links point at dotfiles.checkout, so this must be that clone -----------
# -ef (same file), not a string compare: APFS ignores case and either path may be a symlink
checkout=$(jq -r .dotfiles.checkout <<< "$declared")
if [[ ! "$DOTFILEDIR" -ef "$checkout" ]]; then
  cross "this clone is $DOTFILEDIR but dotfiles.checkout is $checkout: run task install from there, or set dotfiles.checkout in machines/$MACHINE.nix"
  exit 1
fi

# --- build: nothing on the machine changes unless this succeeds --------------
info "building $MACHINE"
"$NIX" build "$DOTFILEDIR#darwinConfigurations.$MACHINE.system" --out-link "$DOTFILEDIR/result"

# --- first switch: clear the way for home-manager and nix-darwin -------------
if [[ ! -e /run/current-system ]]; then
  info "first switch on this Mac: clearing the paths home-manager will link"
  jq -r '.dotfiles.links | keys[]' <<< "$declared" | zsh "$HERE/install-clear-links.zsh"
  # nix-darwin refuses /etc files it did not write
  sudo sh -c 'for f in /etc/zshenv /etc/shells; do if [ -f "$f" ] && [ ! -L "$f" ]; then mv "$f" "$f.before-nix-darwin"; fi; done'
fi

# --- switch --------------------------------------------------------------------
sudo env NIX_CONFIG="${NIX_CONFIG:-}" "$DOTFILEDIR/result/sw/bin/darwin-rebuild" switch --flake "$DOTFILEDIR#$MACHINE"

# --- list what is no longer declared; task prune uninstalls it ----------------
zsh "$HERE/prune.zsh" --list <<< "$declared" || true # a hint; the switch has already finished

# --- warn about each pin the install does not move ------------------------------
zsh "$HERE/install-pins.zsh" <<< "$declared" || warn "pins: the check failed (above); the install has finished"
