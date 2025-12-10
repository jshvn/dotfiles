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
#   - Plugin managers and interactive hooks (antigen, zinit, oh-my-zsh):
#       source $HOMEBREW_PREFIX/share/antigen/antigen.zsh
#       antigen bundle zsh-users/zsh-autosuggestions
#       antigen apply
#   - Aliases and functions (interactive conveniences):
#       alias ll='ls -la'
#       function myfunc() { echo "interactive only" }
#
# Notes:
#   - Keep .zshrc for interactive setup only. If a value must be available to
#     non-interactive shells, put it in ~/.zshenv or ~/.zprofile instead.
#   - Avoid lengthy blocking commands in .zshrc; prefer lazy loading or checks.
#
# See: Zsh manual — Startup/Shutdown Files:
#   http://zsh.sourceforge.net/Doc/Release/Files.html
# -----------------------------------------------------------------------------

# setup zsh history file in XDG data home, turn on history sharing
export HISTFILE="$XDG_DATA_HOME/zsh/history"
export HIST_STAMPS="%Y-%m-%d %I:%M:%S"
mkdir -p "${HISTFILE%/*}"
setopt SHARE_HISTORY

export ZSH_COMPDUMP="$XDG_CACHE_HOME/zsh/zcompcache"
mkdir -p "${ZSH_COMPDUMP%/*}"

# set antigen config location
export ADOTDIR=$XDG_CONFIG_HOME/antigen

# set tlrc (tldr client) config and cache location
export TLRC_CONFIG="$XDG_CONFIG_HOME/tlrc"

# load antigen for plugin management
source $HOMEBREW_PREFIX/share/antigen/antigen.zsh

# load the oh-my-zsh's library.
antigen use ohmyzsh/ohmyzsh

# load plugins for oh-my-zsh
antigen bundle ohmyzsh/ohmyzsh git
antigen bundle ohmyzsh/ohmyzsh colorize
antigen bundle ohmyzsh/ohmyzsh kubectl
antigen bundle ohmyzsh/ohmyzsh plugins/extract
antigen bundle zsh-users/zsh-syntax-highlighting
antigen bundle zsh-users/zsh-completions
antigen bundle zsh-users/zsh-autosuggestions

# apply antigen plugin settings
antigen apply

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

# the below sources need to happen after the above shell initializations
# otherwise some functions/scripts like 'which' will not be found in the 
# correct spots, and that causes errors in aliases and functions

# load ZSH aliases
for file in "$DOTFILEDIR/zsh/aliases/"*.zsh(.N); do
    source "$file"
done

# load common ZSH custom themes
source $DOTFILEDIR/zsh/theme.zsh

# load ZSH function and helper scripts
for file in "$DOTFILEDIR/zsh/functions/"*.zsh(.N); do
    source "$file"
done