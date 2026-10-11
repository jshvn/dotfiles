#!/bin/zsh

# =============================================================================
# tasks/prune.zsh -- uninstall what the declaration no longer lists, after asking
#
# Purpose:      The body of `task prune`. Takes the evaluated declaration on
#               stdin and runs `brew bundle cleanup` against its Brewfile: every
#               formula, cask, tap, Mac App Store app, VS Code extension and
#               go, cargo, uv, npm or krew install the Brewfile does not list.
#               On a terminal brew prints the list and asks; only y removes
#               anything. Without a terminal it prints the list and removes
#               nothing. --list prints the list and a pointer to `task prune`
#               and never asks (`task install` runs it after the switch).
# Depends on:   jq; brew (under the declaration's brewPrefix);
#               tasks/messages.zsh; tasks/audit-brew-cleanup.zsh.
# Side effects: uninstalls packages after a y at brew's prompt; writes one
#               mktemp directory (trap-removed).
# =============================================================================

set -euo pipefail

typeset -r HERE="${0:A:h}"
source "$HERE/messages.zsh"

declared=$(cat)
if ! jq -e '.dotfiles | type == "object"' <<< "$declared" >/dev/null 2>&1; then
  cross "no declaration on stdin (expected the JSON task prune produces with nix eval)"
  exit 1
fi

# A first switch installs Homebrew, so the caller's PATH may not have it yet
export PATH="$(jq -r .brewPrefix <<< "$declared")/bin:$PATH"
export HOMEBREW_NO_AUTO_UPDATE=1
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
jq -r .brewfile <<< "$declared" > "$tmp/Brewfile"

# stdin from /dev/null: without a terminal brew lists and never prompts; it exits 1 when it would
# uninstall something, so a non-zero exit with nothing listed means the dry run itself failed
rc=0
brew bundle cleanup --file="$tmp/Brewfile" < /dev/null > "$tmp/cleanup" 2>/dev/null || rc=$?
extra=$(zsh "$HERE/audit-brew-cleanup.zsh" < "$tmp/cleanup")
if [[ -z "$extra" ]]; then
  (( rc == 0 )) || { cross "brew bundle cleanup dry run failed (exit $rc)"; exit 1; }
  check "nothing installed beyond the declaration"
  exit 0
fi

if [[ "${1:-}" != --list ]] && { : < /dev/tty } 2>/dev/null; then
  # brew lists what it would uninstall and asks; only y removes anything
  brew bundle cleanup --file="$tmp/Brewfile" < /dev/tty ||
    info "cleanup did not finish (answered no, or failed above); task audit lists what remains"
  exit 0
fi

while IFS=$'\t' read -r kind name; do
  warn "beyond the declaration: $kind: $name"
done <<< "$extra"
if [[ "${1:-}" == --list ]]; then
  info "task prune uninstalls these, after asking"
else
  warn "nothing uninstalled: no terminal to ask; run task prune from one"
fi
