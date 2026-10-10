#!/bin/zsh

# =============================================================================
# shell/.zprofile -- zsh login-shell initialization
#
# Purpose:      Load Homebrew shellenv; conditionally configure SSH_AUTH_SOCK
#               to the 1Password agent socket (manifest-driven via
#               features.one-password-ssh).
# Depends on:   brew (at $HOMEBREW_PREFIX/bin/brew); resolved.json (read
#               via jq for the one-password-ssh feature gate); .zshenv
#               for XDG_STATE_HOME.
# Side effects: evals `brew shellenv` (PATH/MANPATH/INFOPATH/HOMEBREW_* exports);
#               may export SSH_AUTH_SOCK to the 1Password agent socket.
# =============================================================================

# Darwin only: every machine in manifests/machines/ sets machine.os = "darwin".
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

# Login-shell fragments linked into env.d by the switch (the 1Password agent socket when
# that app is on). .zprofile runs before .zshrc, so nothing from functions/ exists yet.
for file in "${XDG_STATE_HOME}/dotfiles/env.d/"*.zsh(-.N); do
    source "$file"
done
