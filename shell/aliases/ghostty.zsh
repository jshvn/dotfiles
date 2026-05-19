#!/bin/zsh

# =============================================================================
# shell/aliases/ghostty.zsh -- Ghostty launcher wrapper
#
# Purpose:      Launch the Ghostty terminal binary; gated on
#               features.ghostty via the wrapper-function pattern (single
#               alias, so the helpful stderr message wins over the
#               bulk-loop source-time gate).
# Depends on:   shell/functions/_dotfiles_require_feature.zsh.
# Side effects: defines function g(); execs Ghostty.app/MacOS/ghostty
#               on feature-on machines.
# =============================================================================

function g() {
    _dotfiles_require_feature ghostty || return 1
    /Applications/Ghostty.app/Contents/MacOS/ghostty "$@"
}
