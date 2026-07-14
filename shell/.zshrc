#!/bin/zsh

# =============================================================================
# shell/.zshrc -- zsh interactive shell configuration
#
# Purpose:      Interactive-only setup: antidote plugin manager (OMZ lib +
#               plugins via shell/.zsh_plugins.txt; use-omz owns deferred
#               compinit), lazy conda, optional VS Code shell integration,
#               theme + functions + aliases sourcing, missing-machine warning.
# Depends on:   .zshenv (XDG vars + DOTFILES_MACHINE); .zprofile (brew
#               shellenv); antidote at $HOMEBREW_PREFIX/opt/antidote/;
#               shell/.zsh_plugins.txt; shell/theme.zsh;
#               shell/functions/*.zsh; shell/aliases/*.zsh.
# Side effects: exports ANTIDOTE_HOME, HISTFILE, HIST_STAMPS, HISTSIZE,
#               SAVEHIST; creates HISTFILE parent dir; enables SHARE_HISTORY
#               setopt; clones plugin repos + writes static init file under
#               $ANTIDOTE_HOME; writes zcompdump under $XDG_CACHE_HOME/zsh;
#               conditionally sources VS Code shell integration; prints
#               stderr warning when no machine selected.
# =============================================================================

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

# antidote (static plugin manager). getantidote/use-omz supplies OMZ
# scaffolding ($ZSH, $ZSH_CACHE_DIR, deferred compinit before first prompt);
# `ohmyzsh/ohmyzsh path:lib` provides prompt_subst, git_prompt_info/status,
# the `l` alias, and history/completion defaults that theme.zsh and the rest
# of this file rely on. Plugin set lives in shell/.zsh_plugins.txt.
export ANTIDOTE_HOME="$XDG_CACHE_HOME/antidote"
_antidote_sh="$HOMEBREW_PREFIX/opt/antidote/share/antidote/antidote.zsh"
_zsh_plugins_txt="$DOTFILEDIR/shell/.zsh_plugins.txt"
_zsh_plugins_static="$ANTIDOTE_HOME/.zsh_plugins.zsh"

if [[ -n "$HOMEBREW_PREFIX" && -f "$_antidote_sh" && -f "$_zsh_plugins_txt" ]]; then
    # OMZ self-update (sourced by use-omz) would interactively prompt every
    # ~2 weeks and git-pull a clone antidote also manages. Updates go through
    # `task install` instead.
    zstyle ':omz:update' mode disabled

    # Self-heal a partial static file (e.g. an offline first run writes a
    # partial static newer than the txt; antidote's mtime check then never
    # retries). A complete static file must mention the LAST bundle in the
    # txt -- derived at runtime so reordering the plugin list cannot silently
    # disarm the check. Pure zsh expansion, no forks.
    if [[ -f "$_zsh_plugins_static" ]]; then
        _plugin_lines=(${(f)"$(<"$_zsh_plugins_txt")"})
        _plugin_lines=(${${_plugin_lines:#[[:space:]]#\#*}:#[[:space:]]#})
        _last_bundle="${_plugin_lines[-1]%% *}"
        if [[ -n "$_last_bundle" && "$(<"$_zsh_plugins_static")" != *"$_last_bundle"* ]]; then
            rm -f "$_zsh_plugins_static" "$_zsh_plugins_static.zwc"
        fi
        unset _plugin_lines _last_bundle
    fi

    source "$_antidote_sh"
    antidote load "$_zsh_plugins_txt" "$_zsh_plugins_static"
else
    echo "$(tput setaf 3)Warning: antidote not found. Run 'task install' to complete setup.$(tput sgr0)" >&2
    # Degraded shell still gets working completion.
    autoload -Uz compinit
    mkdir -p "$XDG_CACHE_HOME/zsh"
    compinit -d "$XDG_CACHE_HOME/zsh/zcompdump-fallback"
fi
unset _antidote_sh _zsh_plugins_txt _zsh_plugins_static

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
#   3. OMZ lib/history.zsh (via antidote): HISTFILE=$HOME/.zsh_history (only if unset).
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
