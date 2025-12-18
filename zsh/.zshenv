#!/bin/zsh
# -----------------------------------------------------------------------------
# .zshenv - Zsh environment initialization
#
# Sourced by: every zsh invocation (login, non-login, interactive, non-interactive)
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
#   - Provide minimal, always-needed environment variables for all invocations.
#   - Must be tiny and safe for non-interactive contexts (scripts, scp, cron).
#
# Typical contents / examples (safe for .zshenv):
#   - Exports used by scripts and programs:
#       export PATH="$HOME/bin:/usr/local/bin:$PATH"
#       export BROWSER="/Applications/Firefox.app/Contents/MacOS/firefox"
#   - Avoid: aliases, functions, plugin managers, compinit, or any heavy commands.
#
# See: Zsh manual — Startup/Shutdown Files:
#   http://zsh.sourceforge.net/Doc/Release/Files.html
# -----------------------------------------------------------------------------

# while not a strict requirement, loosely follow the XDG Base Directory Specification
# https://specifications.freedesktop.org/basedir/latest/
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# setup data and config directories
export XDG_DATA_DIRS="/usr/local/share:/usr/share"
export XDG_CONFIG_DIRS="/etc/xdg"

# setup ZSH directory
export ZDOTDIR="${ZDOTDIR:-$XDG_CONFIG_HOME/zsh}"

# tool defaults (safe for non-interactive shells)
export EDITOR="nano"
export VEDITOR="code"
export VISUAL="code"

# Ensure UTF-8 locale for consistent Unicode character width calculation
# This is critical for prompt width calculation in zsh
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

# set browser to Firefox (some tools use $BROWSER)
export BROWSER="/Applications/Firefox.app/Contents/MacOS/firefox"

# disable shell sessions to avoid creating .zsh/sessions/ directories and files
export SHELL_SESSIONS_DISABLE=1

# set CF_USER_TEXT_ENCODING to avoid locale warnings in some macOS terminal apps
export __CF_USER_TEXT_ENCODING=0x0:0:0

# Read current profile (default to personal if not set)
DOTFILES_PROFILE=$(cat "${XDG_CONFIG_HOME}/dotfiles/profile" 2>/dev/null || echo "personal")
export DOTFILES_PROFILE