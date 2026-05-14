#!/bin/zsh
# -----------------------------------------------------------------------------
# .zshrc - Zsh interactive shell configuration
#
# Sourced by: interactive zsh shells (after ~/.zshenv and ~/.zprofile when login)
# Zsh startup order (login interactive example):
#   1) ~/.zshenv
#   2) ~/.zprofile   (login shells)
#   3) ~/.zshrc      (interactive shells)
#   4) ~/.zlogin     (after .zshrc for login shells)
#
# Logout order (login shells):
#   - ~/.zlogout is read when a login shell exits
#
# Purpose:
#   - Configure interactive-only features: prompt, history, plugins, aliases,
#     functions, keybindings, completions and interactive helpers.
#
# Typical contents / examples:
#   - Prompt and appearance:
#       export PROMPT='%n@%m %1~ %# '
#   - History configuration:
#       export HISTFILE=~/.zsh_history
#   - Completion and shells helpers (interactive):
#       autoload -Uz compinit && compinit
#   - Plugin managers and interactive hooks (antidote, zinit, oh-my-zsh):
#       source $HOMEBREW_PREFIX/share/antidote/antidote.zsh
#       antidote bundle < $ZDOTDIR/.zsh_plugins.txt > $cache
#   - Aliases and functions (interactive conveniences):
#       alias ll='ls -la'
#       function myfunc() { echo "interactive only" }
#
# Notes:
#   - Keep .zshrc for interactive setup only. If a value must be available to
#     non-interactive shells, put it in ~/.zshenv or ~/.zprofile instead.
#   - Avoid lengthy blocking commands in .zshrc; prefer lazy loading or checks.
#
# See: Zsh manual -- Startup/Shutdown Files:
#   http://zsh.sourceforge.net/Doc/Release/Files.html
# -----------------------------------------------------------------------------

# SHEL-10: compinit daily-rebuild cache.
# Skip security check (-C) when zcompdump is fresh; full check (-d) once per day.
export ZSH_COMPDUMP="$XDG_CACHE_HOME/zsh/zcompcache"
mkdir -p "${ZSH_COMPDUMP%/*}"

autoload -Uz compinit
local _zcomp_age=0
if [[ -f "$ZSH_COMPDUMP" ]]; then
    _zcomp_age=$(( $(date +%s) - $(stat -f %m "$ZSH_COMPDUMP" 2>/dev/null || stat -c %Y "$ZSH_COMPDUMP" 2>/dev/null || echo 0) ))
fi
if (( _zcomp_age > 86400 )); then
    compinit -d "$ZSH_COMPDUMP"
else
    compinit -C -d "$ZSH_COMPDUMP"
fi
unset _zcomp_age

# set tlrc (tldr client) config and cache location
export TLRC_CONFIG="$XDG_CONFIG_HOME/tlrc"

#  Find dotfile repo directory on this system, set $DOTFILEDIR to contain absolute path
SOURCE="${(%):-%N}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
    DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
ZSHDIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
DOTFILEDIR="$(dirname "$ZSHDIR")"
export DOTFILEDIR

# antidote: static bundle, lazy-rebuilt (D-01..D-05, SHEL-04).
# Source: configs/antidote/zsh_plugins.txt (committed; Plan 01)
# Cache:  $XDG_CACHE_HOME/antidote/zsh_plugins.zsh (machine-local, never committed)
local _antidote_src="${DOTFILEDIR}/configs/antidote/zsh_plugins.txt"
local _antidote_cache="${XDG_CACHE_HOME}/antidote/zsh_plugins.zsh"
if [[ -n "$HOMEBREW_PREFIX" && -f "${HOMEBREW_PREFIX}/share/antidote/antidote.zsh" ]]; then
    source "${HOMEBREW_PREFIX}/share/antidote/antidote.zsh"
    if [[ ! -f "$_antidote_cache" || "$_antidote_src" -nt "$_antidote_cache" ]]; then
        mkdir -p "${_antidote_cache:h}"
        antidote bundle < "$_antidote_src" > "$_antidote_cache"
    fi
    source "$_antidote_cache"
else
    echo "$(tput setaf 3)Warning: antidote not found. Run 'task install' to complete setup.$(tput sgr0)" >&2
fi

# lazy conda initialization - wrapper replaces itself after performing hook, then re-runs original command
if command -v conda >/dev/null 2>&1; then
    function conda() {
    unfunction conda 2>/dev/null
        local __conda_bin
        __conda_bin="$(command -v conda)"
        eval "$("$__conda_bin" shell.$(basename "${SHELL}") hook)"
        conda "$@"
    }
fi

# Source VSCode shell integration if running inside VSCode
if [[ "$TERM_PROGRAM" == "vscode" ]]; then
    source "$(code --locate-shell-integration-path zsh)"
fi

# the below sources need to happen after the above shell initializations
# otherwise some functions/scripts like 'which' will not be found in the
# correct spots, and that causes errors in aliases and functions

# Load aliases (flat layout; per-file source-time or wrapper-function gates handle features per D-09)
for file in "${DOTFILEDIR}/shell/aliases/"*.zsh(.N); do
    source "$file"
done

# load common ZSH custom themes
source "${DOTFILEDIR}/shell/theme.zsh"

# Load functions (flat layout; one function per file)
for file in "${DOTFILEDIR}/shell/functions/"*.zsh(.N); do
    source "$file"
done

# Warn if no active machine -- interactive only (CF-05; missing-state pattern).
# This file is only sourced for interactive shells (zsh contract), so the warning
# never spams cron, scp, or non-interactive scripts.
if [[ -z "${DOTFILES_MACHINE:-}" ]]; then
    echo "$(tput setaf 3)Warning: no active machine selected. Run: task setup -- <machine-name>$(tput sgr0)" >&2
fi
