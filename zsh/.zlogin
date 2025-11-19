#!/bin/zsh
# -----------------------------------------------------------------------------
# .zlogin - Zsh login shell post-initialization (Tron-themed MOTD for JGRID)
#
# Sourced by: login shells (after ~/.zshrc completes)
# Zsh startup order (login interactive example):
#   1) ~/.zshenv
#   2) ~/.zprofile   (login shells)
#   3) ~/.zshrc      (interactive shells)
#   4) ~/.zlogin     (after .zshrc for login shells)
#
# Purpose: Display Tron-themed MOTD with system stats, git repo info, and quotes
# -----------------------------------------------------------------------------

# Tron color scheme
TRON_CYAN="\033[38;5;51m"
TRON_BLUE="\033[38;5;39m"
TRON_ORANGE="\033[38;5;208m"
TRON_DARK="\033[38;5;237m"
TRON_YELLOW="\033[38;5;226m"
TRON_RESET="\033[0m"
TRON_BOLD="\033[1m"
TRON_DIM="\033[2m"

# Get terminal dimensions
TERM_WIDTH=$(tput cols)
TERM_HEIGHT=$(tput lines)

# Function to print centered text
print_centered() {
    local text="$1"
    local color="$2"
    local width=$TERM_WIDTH
    local text_length=${#text}
    local padding=$(( (width - text_length) / 2 ))
    
    printf "%*s" $padding ""
    echo -e "${color}${text}${TRON_RESET}"
}

# Function to print horizontal line
print_line() {
    local char="${1:-━}"
    local color="${2:-$TRON_CYAN}"
    echo -e "${color}$(printf '%*s' $TERM_WIDTH | tr ' ' "$char")${TRON_RESET}"
}

# Function to calculate display width accounting for emojis
_calculate_display_width() {
    local text="$1"
    local width=0
    local i
    for (( i=0; i<${#text}; i++ )); do
        [[ "${text:$i:1}" =~ [⚡📦💭🔥⚙️🌐🔋⬆️⬇️↑↓] ]] && ((width+=2)) || ((width++))
    done
    echo $width
}

# Function to print bordered line with two colors (label › value)
print_bordered_two_color() {
    local label="$1"
    local value="$2"
    local content_width=$((TERM_WIDTH - 4))
    local text="${label} › ${value}"
    local text_plain="${text//\x1b\[[0-9;]*m/}"
    local display_width=$(_calculate_display_width "$text_plain")
    
    if [ $display_width -le $content_width ]; then
        local colored_text="${TRON_CYAN}${label} ›${TRON_RESET}${TRON_ORANGE} ${value}${TRON_RESET}"
        local padding=$((content_width - display_width))
        printf "${TRON_DARK}▐${TRON_RESET} %b%*s ${TRON_DARK}▌${TRON_RESET}\n" "$colored_text" $padding ""
    else
        print_bordered "${text:0:$content_width}" "$TRON_CYAN"
    fi
}

# Function to print bordered line (single color)
print_bordered() {
    local text="$1"
    local color="${2:-$TRON_CYAN}"
    local content_width=$((TERM_WIDTH - 4))
    
    if [[ "$text" =~ › ]]; then
        local label="${text%%›*}"
        local value="${text#*›}"
        # Remove trailing and leading spaces
        label="${label% }"
        value="${value# }"
        print_bordered_two_color "$label" "$value"
    else
        local text_plain="${text//\x1b\[[0-9;]*m/}"
        local display_width=$(_calculate_display_width "$text_plain")
        [ $display_width -gt $content_width ] && text="${text:0:$content_width}" && display_width=$content_width
        local padding=$((content_width - display_width))
        printf "${color}▐${TRON_RESET} %s%*s ${color}▌${TRON_RESET}\n" "$text" $padding ""
    fi
}

# Function to get random Tron quote
get_tron_quote() {
    local quotes_file="${DOTFILEDIR}/zsh/configs/motd_tron.txt"
    if [[ -f "$quotes_file" ]]; then
        local line_count=$(wc -l < "$quotes_file")
        local random_line=$((RANDOM % line_count + 1))
        sed -n "${random_line}p" "$quotes_file"
    else
        echo "The Grid awaits..."
    fi
}

# Function to wrap text to terminal width
wrap_text() {
    local text="$1"
    local width=$((TERM_WIDTH - 6))
    echo "$text" | fold -s -w $width
}

# Function to get git repo status
get_git_status() {
    if [[ -d "${DOTFILEDIR}/.git" ]]; then
        cd "${DOTFILEDIR}" || return
        
        local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
        local status_output=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
        local ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
        local behind=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo "0")
        local last_commit=$(git log -1 --format="%ar" 2>/dev/null)
        local total_commits=$(git rev-list --count HEAD 2>/dev/null || echo "0")
        
        echo "branch:${branch}|changes:${status_output}|ahead:${ahead}|behind:${behind}|last:${last_commit}|commits:${total_commits}"
    else
        echo "branch:unknown|changes:0|ahead:0|behind:0|last:unknown|commits:0"
    fi
}

# Function to print system status section
print_system_status() {
    if [ $TERM_WIDTH -ge 70 ]; then
        print_bordered "⚡ SYSTEM STATUS" "$TRON_CYAN"
        print_bordered "" "$TRON_DARK"
        
        local ff_config="${DOTFILEDIR}/zsh/configs/motd_sysinfo.jsonc"
        if [[ -f "$ff_config" ]]; then
            fastfetch --config "$ff_config" 2>/dev/null | while IFS= read -r line; do
                print_bordered "   $line" "$TRON_DARK"
            done
        fi
        
        print_bordered "" "$TRON_DARK"
    fi
}

# Function to print dotfiles repository section
print_dotfiles_repo() {
    print_bordered "📦 DOTFILES REPOSITORY" "$TRON_CYAN"
    local git_info=$(get_git_status)
    
    IFS='|' read -r branch_info changes_info ahead_info behind_info last_info commits_info <<< "$git_info"
    
    print_bordered "" "$TRON_DARK"
    print_bordered_two_color "   Branch" "${branch_info#*:}"
    print_bordered_two_color "   Total Commits" "${commits_info#*:}"
    print_bordered_two_color "   Uncommitted Changes" "${changes_info#*:}"
    
    local ahead_count="${ahead_info#*:}"
    local behind_count="${behind_info#*:}"
    
    if [ "$ahead_count" != "0" ] || [ "$behind_count" != "0" ]; then
        print_bordered_two_color "   Sync Status" "↑${ahead_count} ↓${behind_count}"
    fi
    
    print_bordered_two_color "   Last Commit" "${last_info#*:}"
    print_bordered "" "$TRON_DARK"
}

# Function to print Tron quote section
print_tron_quote() {
    local quote=$(get_tron_quote)
    print_bordered "💭 TRANSMISSION" "$TRON_CYAN"
    print_bordered "" "$TRON_DARK"
    
    wrap_text "$quote" | while IFS= read -r line; do
        print_bordered "   ${line}" "$TRON_DARK"
    done
    
    echo
}

# Top border with Tron grid pattern
echo -e "${TRON_CYAN}${TRON_BOLD}"
print_line "━"
print_line "▀"

echo

# JGRID logo - ASCII art adapted to terminal width
if [ $TERM_WIDTH -ge 80 ]; then
    # Full logo for wider terminals
    print_centered "     ██╗ ██████╗ ██████╗ ██╗██████╗ " "$TRON_CYAN$TRON_BOLD"
    print_centered "     ██║██╔════╝ ██╔══██╗██║██╔══██╗" "$TRON_CYAN$TRON_BOLD"
    print_centered "     ██║██║  ███╗██████╔╝██║██║  ██║" "$TRON_CYAN$TRON_BOLD"
    print_centered "██   ██║██║   ██║██╔══██╗██║██║  ██║" "$TRON_CYAN$TRON_BOLD"
    print_centered "╚█████╔╝╚██████╔╝██║  ██║██║██████╔╝" "$TRON_CYAN$TRON_BOLD"
    print_centered " ╚════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝╚═════╝ " "$TRON_CYAN$TRON_BOLD"
else
    # Compact logo for narrow terminals
    print_centered "J G R I D" "$TRON_CYAN$TRON_BOLD"
fi

print_centered "━ SYSTEM ACCESS GRANTED ━" "$TRON_ORANGE"
echo

# Middle border
print_line "─" "$TRON_DARK"
echo

# Display sections
print_system_status
print_dotfiles_repo
print_tron_quote

# Bottom border with grid effect
print_line "▄" "$TRON_CYAN"
print_line "━" "$TRON_CYAN"

# Footer message
print_centered "━━━ END OF LINE ━━━" "$TRON_ORANGE$TRON_DIM"

echo

# Clean up all variables and functions to avoid polluting the shell environment
unset TRON_CYAN TRON_BLUE TRON_ORANGE TRON_DARK TRON_YELLOW TRON_RESET TRON_BOLD TRON_DIM
unset TERM_WIDTH TERM_HEIGHT
unset -f print_centered print_line print_bordered print_bordered_two_color _calculate_display_width get_tron_quote wrap_text get_git_status
unset -f print_system_status print_dotfiles_repo print_tron_quote
