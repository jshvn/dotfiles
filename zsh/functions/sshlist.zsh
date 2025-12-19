#!/bin/zsh

# Display configured SSH host information for current profile only
function sshlist() {    #  sshlist() will list all configured SSH hosts for the current profile. ex: $ sshlist
    echo "$(tput setaf 6)SSH Configurations:$(tput sgr0)"
    echo ""
    
    local profile="${DOTFILES_PROFILE:-personal}"
    
    # Main SSH config (always show)
    echo "$(tput setaf 3)── Main Config ──$(tput sgr0)"
    if [[ -f "$DOTFILEDIR/ssh/configs/config" ]]; then
        grep -E "^Host " "$DOTFILEDIR/ssh/configs/config" 2>/dev/null | \
            sed 's/Host /  /' | \
            highlight --syntax=conf --out-format=ansi 2>/dev/null || cat
    fi
    
    # Profile-specific SSH config
    local profile_config="$DOTFILEDIR/ssh/configs/config-$profile"
    if [[ -f "$profile_config" ]]; then
        echo ""
        echo "$(tput setaf 3)── Profile: $profile ──$(tput sgr0)"
        grep -E "^Host " "$profile_config" 2>/dev/null | \
            sed 's/Host /  /' | \
            highlight --syntax=conf --out-format=ansi 2>/dev/null || cat
    fi
    
    echo ""
    echo "$(tput setaf 8)Config files: ~/.ssh/config, ~/.ssh/config-$profile$(tput sgr0)"
}