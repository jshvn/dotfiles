#!/bin/zsh

# =============================================================================
# shell/functions/motd.zsh -- Tron-themed message-of-the-day banner
#
# Purpose:      Display a centered Tron-themed banner with fastfetch system
#               info, dotfiles repo summary (last commit + uncommitted count),
#               and a random Tron quote. Helpers _motd_center / _motd_line
#               live at file scope and rely on zsh dynamic scoping to read
#               width / reset / cyan from motd()'s locals. Terminals with
#               an image protocol get the jgrid logo; others the ASCII art.
# Depends on:   tput, fastfetch (optional), shuf or sort, git, sed, tr,
#               base64, $DOTFILEDIR, configs/motd/motd_sysinfo.jsonc,
#               configs/motd/motd_tron.txt, configs/motd/motd_jgrid.png.
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

# Draws the logo inline: the kitty graphics protocol (kitty, Ghostty) or the
# iTerm2 protocol (iTerm2, WezTerm). Returns 1 where neither applies, and
# inside tmux, which drops both unless passthrough is on.
_motd_image() {
    local png="${DOTFILEDIR}/configs/motd/motd_jgrid.png" rows=16
    [[ -r "$png" && -z "$TMUX" ]] || return 1
    # ponytail: centers on a 2:1 cell; fonts with another ratio sit a column off
    local pad=$(( (width - rows * 2) / 2 ))
    local b64=$(base64 < "$png" | tr -d '\n')

    if [[ "$TERM" == (xterm-kitty|xterm-ghostty) ]]; then
        # Chunks of 4096 (the protocol's limit); q=2 keeps replies out of the
        # prompt, C=1 leaves the cursor so the rows are stepped over below.
        local i=0 more
        printf '%*s' $pad ''
        while (( i < ${#b64} )); do
            more=$(( i + 4096 < ${#b64} ))
            if (( i == 0 )); then
                printf '\e_Gf=100,a=T,r=%d,C=1,q=2,m=%d;%s\e\\' $rows $more "${b64:$i:4096}"
            else
                printf '\e_Gm=%d;%s\e\\' $more "${b64:$i:4096}"
            fi
            (( i += 4096 ))
        done
        printf '\n%.0s' {1..$rows}
    elif [[ "$TERM_PROGRAM" == (iTerm.app|WezTerm) ]]; then
        printf '%*s\e]1337;File=inline=1;height=%d;preserveAspectRatio=1:%s\a\n' $pad '' $rows "$b64"
    else
        return 1
    fi
}

function motd() {    # motd() prints the Tron-themed message-of-the-day banner. ex: $ motd
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
    
    # Logo: the image where the terminal draws one, else ASCII adaptive to width
    if _motd_image; then
        :
    elif [[ $width -ge 80 ]]; then
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
