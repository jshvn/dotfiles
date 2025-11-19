#!/bin/zsh
# -----------------------------------------------------------------------------
# motd - Display Tron-themed MOTD with system info
# Usage: motd
# -----------------------------------------------------------------------------

# message of the day function
function motd() {    # motd() will display a Tron-themed message of the day with system info. ex: $ motd
    # Tron color scheme using tput for portability
    local cyan=$(tput setaf 51)
    local orange=$(tput setaf 208)
    local dim=$(tput dim)
    local bold=$(tput bold)
    local reset=$(tput sgr0)
    
    local width=$(tput cols)
    
    # Helper: print centered text
    _motd_center() {
        local text="$1"
        local color="$2"
        local padding=$(( (width - ${#text}) / 2 ))
        printf "%*s${color}%s${reset}\n" $padding "" "$text"
    }
    
    # Helper: horizontal line
    _motd_line() {
        printf "${1:-$cyan}%*s${reset}\n" $width | tr ' ' "${2:-━}"
    }
    
    # Header
    echo
    _motd_line "$cyan" "━"
    _motd_line "$cyan" "▀"
    echo
    
    # Logo (adaptive to width)
    if [ $width -ge 80 ]; then
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
    echo "${cyan}${bold}⚡ SYSTEM INFORMATION${reset}"
    local ff_config="${DOTFILEDIR}/zsh/configs/motd_sysinfo.jsonc"
    if [[ -f "$ff_config" ]]; then
        fastfetch --config "$ff_config" 2>/dev/null | sed 's/^/   /'
    else
        fastfetch 2>/dev/null | sed 's/^/   /' || echo "   ${orange}fastfetch not configured${reset}"
    fi
    
    echo
    
    # Dotfiles git status (if in repo)
    if [[ -d "${DOTFILEDIR}/.git" ]]; then
        echo "${cyan}${bold}📦 DOTFILES${reset}"
        (
            cd "${DOTFILEDIR}" 2>/dev/null || return
            local branch=$(git branch --show-current 2>/dev/null || echo "unknown")
            local changes=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
            local last_commit=$(git log -1 --format="%ar" 2>/dev/null || echo "unknown")
            
            echo "   ${dim}Branch:${reset} ${branch}  ${dim}|${reset}  ${dim}Changes:${reset} ${changes}  ${dim}|${reset}  ${dim}Last commit:${reset} ${last_commit}"
        )
        echo
    fi
    
    # Random Tron quote
    local quotes_file="${DOTFILEDIR}/zsh/configs/motd_tron.txt"
    if [[ -f "$quotes_file" ]]; then
        local quote=$(shuf -n 1 "$quotes_file" 2>/dev/null || sort -R "$quotes_file" | head -1)
        echo "${cyan}${bold}💭 TRANSMISSION${reset}"
        echo "   ${dim}${quote}${reset}"
        echo
    fi
    
    # Footer
    _motd_line "$cyan" "▄"
    _motd_line "$cyan" "━"
    _motd_center "━━━ END OF LINE ━━━" "${orange}${dim}"
    echo
    
    # Cleanup
    unset -f _motd_center _motd_line
}
