#!/bin/zsh

# =============================================================================
# shell/functions/mkcd.zsh -- create a directory and cd into it
#
# Purpose:      Convenience helper for `mkdir -p X && cd X`.
# Depends on:   mkdir.
# Side effects: creates the directory if absent; changes working directory.
# =============================================================================

function mkcd() {    # mkcd() creates a directory and cd's into it. ex: $ mkcd src/new-module
    mkdir -p "$1" && cd "$1"
}