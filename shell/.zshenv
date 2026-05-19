#!/bin/zsh

# =============================================================================
# shell/.zshenv -- zsh environment initialization
#
# Purpose:      Minimal always-needed env (XDG dirs, ZDOTDIR, locale,
#               DOTFILES_MACHINE) for ALL zsh invocations, including
#               non-interactive contexts (scripts, scp, cron). Must stay tiny.
# Depends on:   nothing.
# Side effects: exports XDG_{CONFIG,DATA,STATE,CACHE}_HOME, XDG_{DATA,CONFIG}_DIRS,
#               ZDOTDIR, HISTFILE, HIST_STAMPS, CLAUDE_CONFIG_DIR, EDITOR,
#               VEDITOR, VISUAL, LANG, LC_ALL, BROWSER (gated), SHELL_SESSIONS_DISABLE,
#               __CF_USER_TEXT_ENCODING, DOTFILES_MACHINE (gated); creates
#               $HISTFILE parent dir; enables SHARE_HISTORY.
# =============================================================================

# XDG Base Directory Specification (preserve any pre-set value).
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# Preserve any value the launching context already set (site-wide admins
# may export XDG_DATA_DIRS).
export XDG_DATA_DIRS="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
export XDG_CONFIG_DIRS="${XDG_CONFIG_DIRS:-/etc/xdg}"

export ZDOTDIR="${ZDOTDIR:-$XDG_CONFIG_HOME/zsh}"

# HISTFILE set here, not .zshrc, so it is defined before VS Code shell
# integration or other wrappers can write to the default path.
export HISTFILE="$XDG_DATA_HOME/zsh/history"
export HIST_STAMPS="%Y-%m-%d %I:%M:%S"
mkdir -p "${HISTFILE%/*}"
setopt SHARE_HISTORY

# Claude Code: XDG-compliant config directory instead of ~/.claude.
export CLAUDE_CONFIG_DIR="${XDG_CONFIG_HOME}/claude"

export EDITOR="nano"
export VEDITOR="code"
export VISUAL="code"

# UTF-8 locale -- critical for prompt width calculation in zsh.
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

# Guard with executable check so tools reading $BROWSER do not get a
# path-to-nothing on machines without Firefox.
[[ -x "/Applications/Firefox.app/Contents/MacOS/firefox" ]] && \
    export BROWSER="/Applications/Firefox.app/Contents/MacOS/firefox"

# Disable shell sessions to avoid creating .zsh/sessions/ directories.
export SHELL_SESSIONS_DISABLE=1

# Avoid locale warnings in some macOS terminal apps.
export __CF_USER_TEXT_ENCODING=0x0:0:0

# DOTFILES_MACHINE (written by `task setup -- <name>`). .zshenv is sourced
# by non-interactive contexts (cron, scp); degrade gracefully on missing
# state. .zshrc handles the missing-machine warning for interactive shells.
# Do NOT loud-fail here -- a crash breaks cron/scp.
if [[ -r "${XDG_STATE_HOME}/dotfiles/machine" ]]; then
    DOTFILES_MACHINE="$(<${XDG_STATE_HOME}/dotfiles/machine)"
    export DOTFILES_MACHINE
fi
