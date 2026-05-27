#!/bin/zsh

# =============================================================================
# shell/functions/sshlist.zsh -- enumerate configured SSH host blocks
#
# Purpose:      Print Host blocks from identity/ssh/config and from every
#               file in identity/ssh/identities/, marking which identity
#               overlay is currently active (symlink at
#               ~/.ssh/identities/active).
# Depends on:   $DOTFILEDIR, grep, sed, tput, readlink, basename.
# Side effects: stdout only.
# =============================================================================

function sshlist() {
    local main_config="$DOTFILEDIR/identity/ssh/config"
    local identities_dir="$DOTFILEDIR/identity/ssh/identities"
    local active_name=""

    if [[ -L "$HOME/.ssh/identities/active" ]]; then
        active_name=$(basename "$(readlink "$HOME/.ssh/identities/active")")
    fi

    echo "$(tput setaf 6)SSH Configurations:$(tput sgr0)"
    echo ""

    echo "$(tput setaf 3)── Main Config ──$(tput sgr0)"
    if [[ -f "$main_config" ]]; then
        grep -E "^Host " "$main_config" 2>/dev/null | sed 's/Host /  /'
    fi
    echo ""

    if [[ -d "$identities_dir" ]]; then
        for f in "$identities_dir"/*; do
            [[ -f "$f" ]] || continue
            local name=$(basename "$f")
            local marker=""
            [[ "$name" == "$active_name" ]] && marker=" $(tput setaf 2)(active)$(tput sgr0)"
            echo "$(tput setaf 3)── Identity: ${name}${marker} ──$(tput sgr0)"
            grep -E "^Host " "$f" 2>/dev/null | sed 's/Host /  /'
            echo ""
        done
    fi

    echo "$(tput setaf 8)Main config: $main_config$(tput sgr0)"
    [[ -n "$active_name" ]] && echo "$(tput setaf 8)Active identity: $identities_dir/$active_name$(tput sgr0)"
}
