#!/bin/zsh
# -----------------------------------------------------------------------------
# .zprofile - Zsh login shell initialization
#
# Sourced by: zsh login shells (after ~/.zshenv, before ~/.zshrc)
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
#   - Configure per-login environment and perform one-time login tasks.
#   - Source cross-shell files (e.g., ~/.profile) for bash/zsh compatibility.
#
# Typical contents / examples:
#   - export SSH_AUTH_SOCK=~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock
#   - export PATH="$HOME/.local/bin:$HOME/bin:$PATH"
#   - [[ -f ~/.profile ]] && source ~/.profile
#   - Commands that should run once per login (not on every shell spawn)
#
# Notes:
#   - Avoid interactive-only plugin initialization here; put those in ~/.zshrc.
#   - If you want environment available to bash and zsh, keep a shared ~/.profile
#     and source it here.
#
# See: Zsh manual — Startup/Shutdown Files:
#   http://zsh.sourceforge.net/Doc/Release/Files.html
# -----------------------------------------------------------------------------

# MacOS
if [[ "$(uname)" == "Darwin" ]]; then
    if [[ "$(uname -m)" == "arm64" ]]; then
        DIRECTORY="/opt/homebrew/bin/brew"
    else
        DIRECTORY="/usr/local/bin/brew"
    fi
else
# Linux
    DIRECTORY="/home/linuxbrew/.linuxbrew/bin/brew"
fi

eval "$($DIRECTORY shellenv)"

# Set 1Password as SSH agent on macOS (per-login session)
export SSH_AUTH_SOCK=~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock