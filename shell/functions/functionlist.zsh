#!/bin/zsh

# =============================================================================
# shell/functions/functionlist.zsh -- enumerate dotfiles functions
#
# Purpose:      List every function defined under shell/functions/ (excluding
#               itself); pretty-print with highlight under a Dotfiles header.
# Depends on:   $DOTFILEDIR, highlight, tput, grep, awk.
# Side effects: stdout only.
# =============================================================================

function functionlist() {
    # Dotfiles functions (flat layout — no profile walk)
    echo "$(tput setaf 3)── Dotfiles ──$(tput sgr0)"
    for file in "${DOTFILEDIR}/shell/functions/"*.zsh(.N)
    do
        if [[ -f $file && ${file:t} != "functionlist.zsh" ]]; then
            grep 'function' "$file" | awk '{$1=$1};1' | highlight --syntax=bash
        fi
    done
}
