#!/bin/zsh

# List all custom aliases defined in the dotfiles and system
function aliaslist() {    # aliaslist() will list all available common, profile, and system aliases. ex: $ aliaslist
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

    # Common aliases
    echo "${yellow}── Common ──${reset}"
    _print_aliases_from_dir "$DOTFILEDIR/zsh/aliases/common"

    # Profile-specific aliases
    local profile="${DOTFILES_PROFILE:-}"
    local profile_dir="$DOTFILEDIR/zsh/aliases/$profile"
    if [[ -n "$profile" && -d "$profile_dir" ]]; then
        local files=("$profile_dir"/*.zsh(.N))
        if (( ${#files} )); then
            echo "\n${yellow}── Profile: $profile ──${reset}"
            _print_aliases_from_dir "$profile_dir"
        fi
    fi

    # System aliases (excluding dotfiles aliases)
    echo "\n${yellow}── System ──${reset}"
    alias | while IFS= read -r line; do
        local name="${line%%=*}"
        (( ${+dotfiles_aliases[$name]} )) || echo "$line" | highlight --syntax=bash
    done
}