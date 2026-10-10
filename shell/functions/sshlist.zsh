#!/bin/zsh

# =============================================================================
# shell/functions/sshlist.zsh -- enumerate configured SSH host blocks
#
# Purpose:      Print Host blocks from apps/ssh/config and from every
#               profile's ssh file (profiles/<name>/ssh), marking the one
#               this machine links (~/.ssh/profile).
# Depends on:   $DOTFILEDIR, grep, sed, tput.
# Side effects: stdout only.
# =============================================================================

function sshlist() {    # sshlist() lists configured SSH host blocks per profile. ex: $ sshlist
    local main_config="$DOTFILEDIR/apps/ssh/config"
    local active=""

    # :A follows home-manager's store link through to the checkout file
    [[ -L "$HOME/.ssh/profile" ]] && active="$HOME/.ssh/profile" && active=${active:A}

    echo "$(tput setaf 6)SSH Configurations:$(tput sgr0)"
    echo ""

    echo "$(tput setaf 3)── Main Config ──$(tput sgr0)"
    if [[ -f "$main_config" ]]; then
        grep -E "^Host " "$main_config" 2>/dev/null | sed 's/Host /  /'
    fi
    echo ""

    local f marker
    for f in "$DOTFILEDIR"/profiles/*/ssh(.N); do
        marker=""
        [[ "${f:A}" == "$active" ]] && marker=" $(tput setaf 2)(active)$(tput sgr0)"
        echo "$(tput setaf 3)── Profile: ${f:h:t}${marker} ──$(tput sgr0)"
        grep -E "^Host " "$f" 2>/dev/null | sed 's/Host /  /'
        echo ""
    done

    echo "$(tput setaf 8)Main config: $main_config$(tput sgr0)"
    [[ -n "$active" ]] && echo "$(tput setaf 8)Active profile: $active$(tput sgr0)"
}
