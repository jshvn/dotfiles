#!/bin/zsh

# =============================================================================
# shell/functions/mkcd.zsh -- create a directory and cd into it
#
# Purpose:      Convenience helper for `mkdir -p X && cd X`.
# Depends on:   mkdir.
# Side effects: creates the directory if absent; changes working directory.
# =============================================================================

function mkcd() {
    mkdir -p "$1" && cd "$1"
}