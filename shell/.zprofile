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

# v1 targets darwin only. Every machine TOML enforces platform.os = "darwin",
# so the previous Linux (linuxbrew) else-branch was unreachable;
# re-introduce it when a Linux machine TOML is added.
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

# SSH Agent. .zprofile runs BEFORE .zshrc, so the _dotfiles_feature helper
# is not yet defined; use an inline jq read of resolved.json. On missing
# resolved.json (fresh machine, before `task setup`), the jq read returns
# nothing, the local var defaults to false, and SSH_AUTH_SOCK stays unset
# (graceful degrade -- the system ssh-agent handles key lookup).
if [[ -r "${XDG_STATE_HOME}/dotfiles/resolved.json" ]]; then
    _opssh=$(jq -r '.features."one-password-ssh" // false' "${XDG_STATE_HOME}/dotfiles/resolved.json" 2>/dev/null)
    if [[ "$_opssh" == "true" ]]; then
        export SSH_AUTH_SOCK=~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock
    fi
    unset _opssh
fi
