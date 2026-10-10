#!/bin/zsh

# =============================================================================
# apps/ghostty/aliases.zsh -- Ghostty launcher wrapper
#
# Purpose:      Launch the Ghostty terminal binary. Linked into aliases.d
#               by the switch when dotfiles.apps.ghostty is on; absent
#               otherwise.
# Depends on:   Ghostty.app (apps/ghostty/default.nix).
# Side effects: defines function g(); execs Ghostty.app/MacOS/ghostty.
# =============================================================================

function g() {
    /Applications/Ghostty.app/Contents/MacOS/ghostty "$@"
}
