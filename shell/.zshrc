#!/bin/zsh

# =============================================================================
# shell/.zshrc -- zsh interactive shell configuration
#
# Purpose:      Interactive-only setup: compinit (daily-rebuild cache),
#               antigen plugin manager, lazy conda, optional VS Code shell
#               integration, theme + functions + aliases sourcing, missing-
#               machine warning.
# Depends on:   .zshenv (XDG vars + DOTFILES_MACHINE); .zprofile (brew
#               shellenv); antigen at $HOMEBREW_PREFIX/share/antigen/;
#               shell/theme.zsh; shell/functions/*.zsh; shell/aliases/*.zsh.
# Side effects: exports HISTFILE, HIST_STAMPS, HISTSIZE, SAVEHIST; creates
#               HISTFILE parent dir; enables SHARE_HISTORY setopt; writes
#               $XDG_CACHE_HOME/zsh/zcompcache; sources antigen + OMZ +
#               plugin bundles; conditionally sources VS Code shell
#               integration; prints stderr warning when no machine selected.
# =============================================================================

# compinit daily-rebuild cache: skip security check (-C) when zcompdump is
# fresh; full check (-d) once per day.
export ZSH_COMPDUMP="$XDG_CACHE_HOME/zsh/zcompcache"
mkdir -p "${ZSH_COMPDUMP%/*}"

autoload -Uz compinit
# `local` cannot be used at script scope.
_zcomp_age=0
if [[ -f "$ZSH_COMPDUMP" ]]; then
    _zcomp_age=$(( $(date +%s) - $(stat -f %m "$ZSH_COMPDUMP" 2>/dev/null || stat -c %Y "$ZSH_COMPDUMP" 2>/dev/null || echo 0) ))
fi
if (( _zcomp_age > 86400 )); then
    compinit -d "$ZSH_COMPDUMP"
else
    compinit -C -d "$ZSH_COMPDUMP"
fi
unset _zcomp_age

export TLRC_CONFIG="$XDG_CONFIG_HOME/tlrc"

# Resolve $DOTFILEDIR (absolute path to repo root) via symlink-walk.
SOURCE="${(%):-%N}"
while [ -h "$SOURCE" ]; do
    DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
ZSHDIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
DOTFILEDIR="$(dirname "$ZSHDIR")"
export DOTFILEDIR

# antigen, not antidote: antidote's static bundle did NOT replicate antigen's
# `antigen use ohmyzsh/ohmyzsh` which implicitly sources all of OMZ's
# lib/*.zsh files providing setopt prompt_subst, git_prompt_info,
# git_prompt_status, the `l` alias, history/completion defaults, etc.
export ADOTDIR="$XDG_CONFIG_HOME/antigen"
if [[ -n "$HOMEBREW_PREFIX" && -f "$HOMEBREW_PREFIX/share/antigen/antigen.zsh" ]]; then
    # Self-heal a corrupt antigen cache. Antigen can write init.zsh with an
    # empty bundle section while still setting _ANTIGEN_CACHE_LOADED=true; it
    # then sources that empty cache on every startup and loads NO plugins --
    # silently killing prompt_subst (literal $(git_prompt_info) in the
    # prompt), completions, syntax highlighting, and autosuggestions. The
    # corruption self-perpetuates: the real bundles never load, so nothing is
    # ever re-captured into a fresh cache. Detect the empty-bundle cache and
    # remove it so the next `antigen apply` regenerates a correct one. Pure
    # parameter expansion -- `$(<file)` does not fork in zsh, so no startup
    # cost beyond reading one small file.
    if [[ -f "$ADOTDIR/init.zsh" ]]; then
        _antigen_bundles="$(<"$ADOTDIR/init.zsh")"
        _antigen_bundles="${_antigen_bundles##*#--- BUNDLES BEGIN}"
        _antigen_bundles="${_antigen_bundles%%#--- BUNDLES END*}"
        if [[ -z "${_antigen_bundles//[[:space:]]/}" ]]; then
            rm -f "$ADOTDIR/init.zsh" "$ADOTDIR/init.zsh.zwc" \
                  "$ADOTDIR/.resources" "$ADOTDIR/.resources.zwc"
        fi
        unset _antigen_bundles
    fi

    source "$HOMEBREW_PREFIX/share/antigen/antigen.zsh"

    # `antigen use ohmyzsh/ohmyzsh` sources lib/*.zsh -- prompt_subst, git
    # prompt helpers, directory aliases, history, completion, key-bindings.
    antigen use ohmyzsh/ohmyzsh

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

# Lazy conda init: wrapper replaces itself after performing hook, then
# re-runs the original command.
if command -v conda >/dev/null 2>&1; then
    function conda() {
    unfunction conda 2>/dev/null
        local __conda_bin
        __conda_bin="$(command -v conda)"
        eval "$("$__conda_bin" shell.$(basename "${SHELL}") hook)"
        conda "$@"
    }
fi

# VS Code shell integration: only when running inside VSCode AND the `code`
# CLI is on PATH. Skips noisily-failing `source ""` when the CLI is not
# installed via "Shell Command: Install 'code' command in PATH".
if [[ "$TERM_PROGRAM" == "vscode" ]] && command -v code >/dev/null 2>&1; then
    _vscode_shell_integration="$(code --locate-shell-integration-path zsh 2>/dev/null || true)"
    [[ -n "$_vscode_shell_integration" && -f "$_vscode_shell_integration" ]] && \
        source "$_vscode_shell_integration"
    unset _vscode_shell_integration
fi

# HISTFILE must be assigned AFTER the VS Code shell-integration source above.
# Three sources try to set HISTFILE before this block:
#   1. Apple's /etc/zshrc: HISTFILE=${ZDOTDIR:-$HOME}/.zsh_history
#   2. VS Code's shellIntegration-rc.zsh: HISTFILE=$USER_ZDOTDIR/.zsh_history
#      USER_ZDOTDIR is $HOME when VS Code is launched without ZDOTDIR set in
#      its parent process (the usual launchd/Dock case), so VS Code's
#      assignment lands at $HOME/.zsh_history.
#   3. antigen/OMZ history.zsh: HISTFILE=$HOME/.zsh_history (only if unset).
# Placing the assignment here means it is the last write, so it wins. Earlier
# placement (top of .zshrc) is silently clobbered by the VS Code source.
# SHARE_HISTORY requires HISTFILE to be set before any history I/O begins;
# this still runs before the prompt is drawn.
export HISTFILE="$XDG_DATA_HOME/zsh/history"
export HIST_STAMPS="%Y-%m-%d %I:%M:%S"
export HISTSIZE=50000
export SAVEHIST=50000
mkdir -p "${HISTFILE%/*}"
setopt SHARE_HISTORY

# Source order matters. theme.zsh defines `alias highlight=...`; zsh
# expands aliases at function PARSE time, so functions that pipe through
# `highlight` (aliaslist, functionlist) need the alias in scope when their
# body is sourced. theme FIRST, functions SECOND, aliases THIRD --
# source-time gates in shell/aliases/*.zsh (e.g. jgrid.zsh) call
# _dotfiles_feature, which is defined by the functions glob.
source "${DOTFILEDIR}/shell/theme.zsh"

for file in "${DOTFILEDIR}/shell/functions/"*.zsh(.N); do
    source "$file"
done

for file in "${DOTFILEDIR}/shell/aliases/"*.zsh(.N); do
    source "$file"
done

# Interactive-only warning: .zshrc is sourced only for interactive shells,
# so this never spams cron, scp, or non-interactive scripts.
if [[ -z "${DOTFILES_MACHINE:-}" ]]; then
    echo "$(tput setaf 3)Warning: no active machine selected. Run: task setup -- <machine-name>$(tput sgr0)" >&2
fi
