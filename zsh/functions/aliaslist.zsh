#!/bin/zsh

# List all custom aliases defined in the dotfiles and system
function aliaslist() {    # aliaslist() will list all available common, profile, and system aliases. ex: $ aliaslist
    local dotfiles_aliases=()

    # Common aliases (at zsh/aliases/common/*.zsh)
    echo "$(tput setaf 3)── Common ──$(tput sgr0)"
    for file in "$DOTFILEDIR/zsh/aliases/common/"*.zsh(.N); do
        if [[ -f $file ]]; then
            while IFS= read -r line; do
                # Extract alias name (everything before the = sign)
                local alias_name="${line#alias }"
                alias_name="${alias_name%%=*}"
                dotfiles_aliases+=("$alias_name")
                echo "$line" | awk '{$1=$1};1' | highlight --syntax=bash
            done < <(grep '^alias' "$file")
        fi
    done

    # Profile-specific aliases (at zsh/aliases/$profile/*.zsh)
    local profile="${DOTFILES_PROFILE:-}"
    if [[ -n "$profile" && -d "$DOTFILEDIR/zsh/aliases/$profile" ]]; then
        local profile_files=("$DOTFILEDIR/zsh/aliases/$profile/"*.zsh(.N))
        if [[ ${#profile_files[@]} -gt 0 ]]; then
            echo ""
            echo "$(tput setaf 3)── Profile: $profile ──$(tput sgr0)"
            for file in "${profile_files[@]}"; do
                if [[ -f $file ]]; then
                    while IFS= read -r line; do
                        # Extract alias name (everything before the = sign)
                        local alias_name="${line#alias }"
                        alias_name="${alias_name%%=*}"
                        dotfiles_aliases+=("$alias_name")
                        echo "$line" | awk '{$1=$1};1' | highlight --syntax=bash
                    done < <(grep '^alias' "$file")
                fi
            done
        fi
    fi

    # System aliases (from 'alias' command, excluding dotfiles aliases)
    # Separate jgrid.net aliases to show in personal section
    local personal_aliases=()
    local system_aliases=()
    while IFS= read -r line; do
        # Extract alias name (everything before the = sign)
        local alias_name="${line%%=*}"
        # Check if this alias is in our dotfiles aliases
        local is_dotfiles_alias=0
        for da in "${dotfiles_aliases[@]}"; do
            if [[ "$da" == "$alias_name" ]]; then
                is_dotfiles_alias=1
                break
            fi
        done
        if [[ $is_dotfiles_alias -eq 0 ]]; then
            # Check if alias contains jgrid.net - show in personal section
            if [[ "$line" == *"jgrid.net"* ]]; then
                personal_aliases+=("$line")
            else
                system_aliases+=("$line")
            fi
        fi
    done < <(alias)

    # Print personal (jgrid.net) aliases
    if [[ ${#personal_aliases[@]} -gt 0 ]]; then
        echo ""
        echo "$(tput setaf 3)── Personal ──$(tput sgr0)"
        for line in "${personal_aliases[@]}"; do
            echo "$line" | highlight --syntax=bash
        done
    fi

    # Print system aliases
    echo ""
    echo "$(tput setaf 3)── System ──$(tput sgr0)"
    for line in "${system_aliases[@]}"; do
        echo "$line" | highlight --syntax=bash
    done
}