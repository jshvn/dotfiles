#!/bin/zsh

# =============================================================================
# shell/.zprofile -- zsh login-shell initialization
#
# Purpose:      Load Homebrew shellenv, then the login-shell fragments the
#               switch linked into $XDG_STATE_HOME/dotfiles/env.d/ (the
#               1Password agent socket).
# Depends on:   brew (at $HOMEBREW_PREFIX/bin/brew); .zshenv for
#               XDG_STATE_HOME; $XDG_STATE_HOME/dotfiles/env.d/*.zsh.
# Side effects: evals `brew shellenv` (PATH/MANPATH/INFOPATH/HOMEBREW_* exports);
#               whatever the fragments export (SSH_AUTH_SOCK).
# =============================================================================

# Darwin only: every machine file is a Mac (docs/DECISIONS.md).
# A Linux machine needs a linuxbrew branch here.
if [[ "$(uname -m)" == "arm64" ]]; then
    DIRECTORY="/opt/homebrew/bin/brew"
else
    DIRECTORY="/usr/local/bin/brew"
fi

# Guarded eval so a partial install does not crash on a missing brew binary.
if [[ -x "$DIRECTORY" ]]; then
    eval "$($DIRECTORY shellenv)"
else
    echo "warn: brew not found at $DIRECTORY -- run bootstrap" >&2
fi

# Login-shell fragments linked into env.d by the switch (the 1Password agent socket).
# .zprofile runs before .zshrc, so nothing from functions/ exists yet.
for file in "${XDG_STATE_HOME}/dotfiles/env.d/"*.zsh(-.N); do
    source "$file"
done
