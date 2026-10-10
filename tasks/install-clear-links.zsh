#!/bin/zsh

# =============================================================================
# tasks/install-clear-links.zsh -- clear the paths home-manager is about to link
#
# Purpose:      home-manager refuses to replace a path it does not own, so the
#               first switch on a Mac clears every registered link path first.
#               Reads home-relative paths on stdin (the dotfiles.links
#               registry); under $HOME it removes a symlink and moves anything
#               else to <path>.before-dotfiles (.before-dotfiles.<epoch> when
#               that name is taken). Prints one line per path it touched.
# Depends on:   tasks/messages.zsh.
# Side effects: removes symlinks and renames files or directories under $HOME.
# =============================================================================

set -euo pipefail

typeset -r HERE="${0:A:h}"
source "$HERE/messages.zsh"

while IFS= read -r rel; do
  [[ -n "$rel" ]] || continue
  target="$HOME/$rel"
  if [[ -L "$target" ]]; then
    rm "$target"
    info "removed link ~/$rel"
  elif [[ -e "$target" ]]; then
    dest="$target.before-dotfiles"
    [[ -e "$dest" || -L "$dest" ]] && dest="$dest.$(date +%s)"
    mv "$target" "$dest"
    warn "moved ~/$rel to ~/${dest#$HOME/}"
  fi
done
