#!/bin/zsh

# =============================================================================
# shell/.zshenv -- zsh environment initialization
#
# Purpose:      Minimal always-needed env (XDG dirs, ZDOTDIR, locale,
#               DOTFILES_STATE, DOTFILES_MACHINE) for ALL zsh invocations, including
#               non-interactive contexts (scripts, scp, cron). Must stay tiny.
# Depends on:   nothing.
# Side effects: exports XDG_{CONFIG,DATA,STATE,CACHE}_HOME, XDG_{DATA,CONFIG}_DIRS,
#               ZDOTDIR, CLAUDE_CONFIG_DIR, GNUPGHOME, GOPATH, NPM_CONFIG_CACHE,
#               NODE_REPL_HISTORY, PYTHON_HISTORY, MPLCONFIGDIR, EDITOR,
#               VEDITOR, VISUAL, HIGHLIGHT_OPTIONS, LANG, LC_ALL,
#               SHELL_SESSIONS_DISABLE, __CF_USER_TEXT_ENCODING, DOTFILES_STATE,
#               DOTFILES_MACHINE (gated).
# =============================================================================

# XDG Base Directory Specification (preserve any pre-set value).
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# Preserve any value the launching context already set (site-wide admins
# may export XDG_DATA_DIRS).
export XDG_DATA_DIRS="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" # lint-allow: hardcoded-prefix
export XDG_CONFIG_DIRS="${XDG_CONFIG_DIRS:-/etc/xdg}"

export ZDOTDIR="${ZDOTDIR:-$XDG_CONFIG_HOME/zsh}"

# Claude Code: XDG-compliant config directory instead of ~/.claude.
export CLAUDE_CONFIG_DIR="${XDG_CONFIG_HOME}/claude"

# Tools that otherwise write a dot-directory or dot-file straight into $HOME.
export GNUPGHOME="${XDG_DATA_HOME}/gnupg"
export GOPATH="${XDG_DATA_HOME}/go"
export NPM_CONFIG_CACHE="${XDG_CACHE_HOME}/npm"
export NODE_REPL_HISTORY="${XDG_STATE_HOME}/node_repl_history"
export PYTHON_HISTORY="${XDG_STATE_HOME}/python_history"
export MPLCONFIGDIR="${XDG_CONFIG_HOME}/matplotlib"

export EDITOR="nano"
export VEDITOR="code"
export VISUAL="code --wait"

# highlight reads its default options from here, so every caller (aliases,
# functions, git aliases) gets the same output format and theme.
export HIGHLIGHT_OPTIONS="--out-format=xterm256 --style=duotone-dark-sky"

# UTF-8 locale -- critical for prompt width calculation in zsh.
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

# Disable shell sessions to avoid creating .zsh/sessions/ directories.
export SHELL_SESSIONS_DISABLE=1

# Avoid locale warnings in some macOS terminal apps.
export __CF_USER_TEXT_ENCODING=0x0:0:0

# The machine-local state: the machine file, and the aliases.d/ and env.d/
# fragments the switch links.
export DOTFILES_STATE="${XDG_STATE_HOME}/dotfiles"

# DOTFILES_MACHINE (written by `task setup -- <name>`). .zshenv is sourced
# by non-interactive contexts (cron, scp); degrade gracefully on missing
# state. .zshrc handles the missing-machine warning for interactive shells.
# Do NOT loud-fail here -- a crash breaks cron/scp.
if [[ -r "${DOTFILES_STATE}/machine" ]]; then
    DOTFILES_MACHINE="$(<${DOTFILES_STATE}/machine)"
    export DOTFILES_MACHINE
fi
