#!/bin/zsh

# =============================================================================
# shell/functions/motd.zsh -- Tron-themed message-of-the-day banner
#
# Purpose:      Display a centered Tron-themed banner with fastfetch system
#               info, dotfiles repo summary (last commit + uncommitted count),
#               and a random Tron quote. Helpers _motd_center / _motd_line
#               live at file scope and rely on zsh dynamic scoping to read
#               width / reset / cyan from motd()'s locals.
# Depends on:   tput, fastfetch (optional), shuf or sort, git, sed, tr,
#               $DOTFILEDIR, configs/motd/motd_sysinfo.jsonc,
#               configs/motd/motd_tron.txt.
# Side effects: stdout only.
# =============================================================================

# Helpers rely on zsh dynamic scoping: motd() declares width/reset/cyan as
# locals, and these helpers read them at call time.
_motd_center() {
    local text="$1"
    local color="$2"
    local padding=$(( (width - ${#text}) / 2 ))
    printf "%*s${color}%s${reset}\n" $padding "" "$text"
}

_motd_line() {
    printf "${1:-$cyan}%*s${reset}\n" $width | tr ' ' "${2:-━}"
}

function motd() {
    local cyan=$(tput setaf 51)
    local orange=$(tput setaf 208)
    local dim=$(tput dim)
    local bold=$(tput bold)
    local reset=$(tput sgr0)
    local width=$(tput cols)


    # Header
    echo
    _motd_line "$cyan" "━"
    _motd_line "$cyan" "▀"
    echo
    
    # Logo (adaptive to width)
    if [[ $width -ge 80 ]]; then
        _motd_center "     ██╗ ██████╗ ██████╗ ██╗██████╗ " "${cyan}${bold}"
        _motd_center "     ██║██╔════╝ ██╔══██╗██║██╔══██╗" "${cyan}${bold}"
        _motd_center "     ██║██║  ███╗██████╔╝██║██║  ██║" "${cyan}${bold}"
        _motd_center "██   ██║██║   ██║██╔══██╗██║██║  ██║" "${cyan}${bold}"
        _motd_center "╚█████╔╝╚██████╔╝██║  ██║██║██████╔╝" "${cyan}${bold}"
        _motd_center " ╚════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝╚═════╝ " "${cyan}${bold}"
    else
        _motd_center "J G R I D" "${cyan}${bold}"
    fi
    
    _motd_center "━ SYSTEM ACCESS GRANTED ━" "${orange}"
    echo
    
    # System info via fastfetch
    echo "${cyan}${bold}[ SYSTEM INFORMATION ]${reset}"
    local ff_config="${DOTFILEDIR}/configs/motd/motd_sysinfo.jsonc"
    if [[ -f "$ff_config" ]]; then
        fastfetch --config "$ff_config" 2>/dev/null | sed "s/^/   /; s/› /› ${orange}/; s/$/${reset}/"
    else
        fastfetch 2>/dev/null | sed "s/^/   /; s/› /› ${orange}/; s/$/${reset}/" || echo "   ${orange}fastfetch not configured${reset}"
    fi
    
    echo
    
    # Dotfiles git status (if in repo)
    if [[ -d "${DOTFILEDIR}/.git" ]]; then
        echo "${cyan}${bold}[ DOTFILES ]${reset}"
        (
            cd "${DOTFILEDIR}" 2>/dev/null || return
            local last_commit=$(git log -1 --format="%ar" 2>/dev/null || echo "unknown")
            local changes=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
            
            echo "   ${reset}Last commit › ${orange}${last_commit}"
            echo "   ${reset}Changes › ${orange}${changes}"
        )
        echo
    fi
    
    # Random Tron quote
    local quotes_file="${DOTFILEDIR}/configs/motd/motd_tron.txt"
    if [[ -f "$quotes_file" ]]; then
        local quote=$(shuf -n 1 "$quotes_file" 2>/dev/null || sort -R "$quotes_file" | head -1)
        echo "${cyan}${bold}[ TRANSMISSION ]${reset}"
        echo "   ${dim}${quote}${reset}"
        echo
    fi
    
    # Footer
    _motd_line "$cyan" "▄"
    _motd_line "$cyan" "━"
    _motd_center "━━━ END OF LINE ━━━" "${orange}${dim}"
    echo
}
