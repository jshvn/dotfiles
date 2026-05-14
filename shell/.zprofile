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
#   - Set up SSH agent (1Password on machines with the feature enabled).
#
# SSH Agent Configuration:
#   - Manifest-driven via features.one-password-ssh in resolved.json.
#     Workstations with the feature enabled use the 1Password SSH agent socket;
#     machines without the feature inherit the system default ssh-agent.
#
# Notes:
#   - Avoid interactive-only plugin initialization here; put those in ~/.zshrc.
#   - If you want environment available to bash and zsh, keep a shared ~/.profile
#     and source it here.
#
# See: Zsh manual -- Startup/Shutdown Files:
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

# ensure Homebrew is inserted into $PATH, $MANPATH, $INFOPATH
# and load $HOMEBREW_PREFIX, $HOMEBREW_CELLAR and $HOMEBREW_REPOSITORY into the environment
# SHEL-02: guarded eval so a partial install does not crash on a missing brew binary.
if [[ -x "$DIRECTORY" ]]; then
    eval "$($DIRECTORY shellenv)"
else
    echo "warn: brew not found at $DIRECTORY -- run bootstrap" >&2
fi

# SSH Agent Configuration
# Manifest-driven (CONCERNS.md bug fix: replaces v1 literal hostname == 'server' check
# with features.one-password-ssh). .zprofile runs BEFORE .zshrc, so the _dotfiles_feature
# helper is not yet defined; use an inline jq read of resolved.json instead. On missing
# resolved.json (fresh machine, before `task setup`), the jq read returns nothing, the
# local var defaults to false, and SSH_AUTH_SOCK stays unset (graceful degrade -- the
# system ssh-agent handles key lookup).
if [[ -r "${XDG_STATE_HOME}/dotfiles/resolved.json" ]]; then
    _opssh=$(jq -r '.features."one-password-ssh" // false' "${XDG_STATE_HOME}/dotfiles/resolved.json" 2>/dev/null)
    if [[ "$_opssh" == "true" ]]; then
        export SSH_AUTH_SOCK=~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock
    fi
    unset _opssh
fi
