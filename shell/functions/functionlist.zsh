#!/bin/zsh

# List all custom functions defined in the dotfiles
function functionlist() {    # functionlist() will list all available dotfiles functions. ex: $ functionlist
    # Dotfiles functions (flat layout — no profile walk)
    echo "$(tput setaf 3)── Dotfiles ──$(tput sgr0)"
    for file in "${DOTFILEDIR}/shell/functions/"*.zsh(.N)
    do
        if [[ -f $file && ${file:t} != "functionlist.zsh" ]]; then
            grep 'function' "$file" | awk '{$1=$1};1' | highlight --syntax=bash
        fi
    done
}
