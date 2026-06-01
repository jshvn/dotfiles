#!/bin/zsh

# =============================================================================
# shell/functions/aliaslist.zsh -- enumerate dotfiles + system aliases
#
# Purpose:      List every alias defined under shell/aliases/ plus every
#               system alias that is not a dotfiles alias; pretty-print with
#               highlight under a Dotfiles / System split header.
# Depends on:   $DOTFILEDIR, highlight, tput, grep.
# Side effects: stdout only.
# =============================================================================

function aliaslist() {    # aliaslist() lists all dotfiles and system aliases. ex: $ aliaslist
    local -A dotfiles_aliases  # Associative array for O(1) lookup
    local yellow=$(tput setaf 3) reset=$(tput sgr0)

    # Helper: print aliases from files and track them
    _print_aliases_from_dir() {
        local dir="$1"
        for file in "$dir"/*.zsh(.N); do
            grep '^alias' "$file" 2>/dev/null | while IFS= read -r line; do
                local name="${line#alias }"
                name="${name%%=*}"
                dotfiles_aliases[$name]=1
                echo "$line" | highlight --syntax=bash
            done
        done
    }

    # Dotfiles aliases (flat layout — no profile walk)
    echo "${yellow}── Dotfiles ──${reset}"
    _print_aliases_from_dir "${DOTFILEDIR}/shell/aliases"

    # System aliases (excluding dotfiles aliases)
    echo "\n${yellow}── System ──${reset}"
    alias | while IFS= read -r line; do
        local name="${line%%=*}"
        (( ${+dotfiles_aliases[$name]} )) || echo "$line" | highlight --syntax=bash
    done
}
