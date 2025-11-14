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

# tool defaults (safe for non-interactive shells)
export EDITOR="nano"
export VEDITOR="code"
export VISUAL="code"

# set browser to Firefox (some tools use $BROWSER)
export BROWSER="/Applications/Firefox.app/Contents/MacOS/firefox"