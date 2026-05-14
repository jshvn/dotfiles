#!/bin/zsh
# -----------------------------------------------------------------------------
# shell/functions/motd.zsh -- Tron-themed MOTD with 24h-TTL cache (SHEL-11).
#
# Purpose: Display a Tron-themed message of the day with system info.
# Behavior: public motd() displays cached content synchronously; async
#           background refresh fires when the cache is older than 86400s
#           (24 hours). _motd_render holds the v1 rendering logic verbatim.
#           On a fresh machine with no cache file, the first call renders
#           synchronously and writes the cache (cold path); subsequent calls
#           within the TTL window display the cached output instantly.
#
# Cache file: $XDG_CACHE_HOME/dotfiles/motd.cache -- machine-local; never
#             committed; auto-created on first run.
#
# v1 config-file paths under zsh/configs/ are still consumed verbatim;
# Phase 7 (Plan TBD) will move them to configs/<tool>/.
# -----------------------------------------------------------------------------

function motd() {    # motd() will display a Tron-themed message of the day with system info. ex: $ motd
    local cache="${XDG_CACHE_HOME}/dotfiles/motd.cache"
    local ttl=86400  # 24h
    local now mtime=0
    now=$(date +%s)
    mkdir -p "${cache:h}"

    # Cold path: no cache yet → render synchronously and seed the file.
    if [[ ! -f "$cache" ]]; then
        _motd_render | tee "$cache"
        return
    fi

    # Warm path: display the cached content immediately.
    mtime=$(stat -f %m "$cache" 2>/dev/null || stat -c %Y "$cache" 2>/dev/null || echo 0)
    cat "$cache"

    # Stale: async refresh via atomic temp-file write so the prompt is never
    # blocked and a partial write never replaces a good cache. The &! suffix
    # backgrounds and disowns in one step (zsh-specific).
    if (( now - mtime > ttl )); then
        ( _motd_render > "${cache}.tmp" 2>/dev/null && mv "${cache}.tmp" "$cache" ) &!
    fi
}

function _motd_render() {
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
        fastfetch --config "$ff_config" 2>/dev/null | sed "s/^/   /; s/› /› ${orange}/; s/$/${reset}/"
    else
        fastfetch 2>/dev/null | sed "s/^/   /; s/› /› ${orange}/; s/$/${reset}/" || echo "   ${orange}fastfetch not configured${reset}"
    fi

    echo

    # Dotfiles git status (if in repo)
    if [[ -d "${DOTFILEDIR}/.git" ]]; then
        echo "${cyan}${bold}📦 DOTFILES${reset}"
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
