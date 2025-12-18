#!/bin/zsh

# List all custom functions defined in the dotfiles
function functionlist() {    # functionlist() will list all available common and profile functions. ex: $ functionlist
    # Common functions (at zsh/functions/*.zsh level)
    echo "$(tput setaf 3)── Common ──$(tput sgr0)"
    for file in "$DOTFILEDIR/zsh/functions/"*.zsh(.N)
    do
        if [[ -f $file && ${file:t} != "functionlist.zsh" ]]; then
            grep 'function' "$file" | awk '{$1=$1};1' | highlight --syntax=bash
        fi
    done
    
    # Profile-specific functions (at zsh/functions/$profile/*.zsh)
    local profile="${DOTFILES_PROFILE:-}"
    if [[ -n "$profile" && -d "$DOTFILEDIR/zsh/functions/$profile" ]]; then
        echo ""
        echo "$(tput setaf 3)── Profile: $profile ──$(tput sgr0)"
        for file in "$DOTFILEDIR/zsh/functions/$profile/"*.zsh(.N); do
            if [[ -f $file && ${file:t} != "functionlist.zsh" ]]; then
                grep 'function' "$file" | awk '{$1=$1};1' | highlight --syntax=bash
            fi
        done
    fi
}