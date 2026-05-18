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

# antigen plugin manager (reverted from antidote — antidote's static bundle did
# NOT replicate antigen's `antigen use ohmyzsh/ohmyzsh` which implicitly sources
# all of OMZ's lib/*.zsh files providing setopt prompt_subst, git_prompt_info,
# git_prompt_status, the `l` alias, history/completion defaults, etc.).
export ADOTDIR="$XDG_CONFIG_HOME/antigen"
if [[ -n "$HOMEBREW_PREFIX" && -f "$HOMEBREW_PREFIX/share/antigen/antigen.zsh" ]]; then
    source "$HOMEBREW_PREFIX/share/antigen/antigen.zsh"

    # load the oh-my-zsh framework (sources lib/*.zsh — prompt_subst, git
    # prompt helpers, directory aliases, history, completion, key-bindings).
    antigen use ohmyzsh/ohmyzsh

    # plugins (verbatim from v1 zsh/.zshrc:60-66)
    antigen bundle ohmyzsh/ohmyzsh git
    antigen bundle ohmyzsh/ohmyzsh colorize
    antigen bundle ohmyzsh/ohmyzsh kubectl
    antigen bundle ohmyzsh/ohmyzsh plugins/extract
    antigen bundle zsh-users/zsh-syntax-highlighting
    antigen bundle zsh-users/zsh-completions
    antigen bundle zsh-users/zsh-autosuggestions

    antigen apply
else
    echo "$(tput setaf 3)Warning: antigen not found. Run 'task install' to complete setup.$(tput sgr0)" >&2
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

# load common ZSH custom themes FIRST so theme.zsh's `alias highlight=...`
# is defined before functions are sourced. Zsh expands aliases at function
# PARSE time, so functions that pipe through `highlight` (aliaslist,
# functionlist) need the alias in scope when their body is sourced.
source "${DOTFILEDIR}/shell/theme.zsh"

# Load functions SECOND (flat layout; one function per file). Source-time gates in shell/aliases/*.zsh (D-08, e.g. jgrid.zsh) call _dotfiles_feature, so the helper function must be defined before the aliases glob runs.
for file in "${DOTFILEDIR}/shell/functions/"*.zsh(.N); do
    source "$file"
done

# Load aliases THIRD (flat layout; per-file source-time or wrapper-function gates handle features per D-09). Functions glob above has already defined _dotfiles_feature, so D-08 source-time gates evaluate correctly.
for file in "${DOTFILEDIR}/shell/aliases/"*.zsh(.N); do
    source "$file"
done

# Warn if no active machine -- interactive only (CF-05; missing-state pattern).
# This file is only sourced for interactive shells (zsh contract), so the warning
# never spams cron, scp, or non-interactive scripts.
if [[ -z "${DOTFILES_MACHINE:-}" ]]; then
    echo "$(tput setaf 3)Warning: no active machine selected. Run: task setup -- <machine-name>$(tput sgr0)" >&2
fi
