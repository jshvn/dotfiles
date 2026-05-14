#!/bin/zsh
# shell/aliases/ghostty.zsh -- Ghostty launcher alias.
#
# Purpose: launch the Ghostty terminal binary from the shell, gated on
# features.ghostty via _dotfiles_feature per D-07. Replaces v1
# zsh/aliases/common/general.zsh:40 (the bare `g` alias, always loaded
# in v1, broken on machines without Ghostty installed).
#
# Why wrapper-function (D-07) rather than source-time gate (D-08): single
# alias. The wrapper-function gate surfaces a helpful stderr message on
# machines without the feature. The explicit positional-args forwarder
# in the body is needed because zsh aliases pass remaining argv
# automatically but a function does not.

function g() {
    [[ "$(_dotfiles_feature ghostty)" == "true" ]] \
        || { echo "g: feature 'ghostty' is disabled on this machine" >&2; return 1; }
    /Applications/Ghostty.app/Contents/MacOS/ghostty "$@"
}
