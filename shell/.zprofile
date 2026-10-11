#!/bin/zsh

# =============================================================================
# shell/.zprofile -- zsh login-shell initialization
#
# Purpose:      Load Homebrew shellenv, then the login-shell fragments the
#               switch linked into $DOTFILES_STATE/env.d/ (the 1Password
#               agent socket).
# Depends on:   HOMEBREW_PREFIX from /etc/zshenv (modules/shell.nix); brew at
#               $HOMEBREW_PREFIX/bin/brew; .zshenv for DOTFILES_STATE;
#               $DOTFILES_STATE/env.d/*.zsh.
# Side effects: evals `brew shellenv` (PATH/MANPATH/INFOPATH/HOMEBREW_* exports);
#               whatever the fragments export (SSH_AUTH_SOCK).
# =============================================================================

# Guarded eval so a partial install does not crash on a missing brew binary.
if [[ -x "${HOMEBREW_PREFIX:-}/bin/brew" ]]; then
    eval "$("${HOMEBREW_PREFIX}/bin/brew" shellenv)"
else
    echo "warn: brew not found at ${HOMEBREW_PREFIX:-<HOMEBREW_PREFIX unset>}/bin/brew -- run bootstrap" >&2
fi

# Login-shell fragments linked into env.d by the switch (the 1Password agent socket).
# .zprofile runs before .zshrc, so nothing from functions/ exists yet.
for file in "${DOTFILES_STATE}/env.d/"*.zsh(-.N); do
    source "$file"
done
