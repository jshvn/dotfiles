# =============================================================================
# apps/1password/env.zsh -- login-shell environment for the 1Password SSH agent
#
# Purpose:      Point SSH at the agent inside the 1Password app. Linked into
#               $XDG_STATE_HOME/dotfiles/env.d/ by the switch when the app is
#               on, and sourced from there by shell/.zprofile.
# Depends on:   the 1Password app (apps/1password/default.nix).
# Side effects: exports SSH_AUTH_SOCK.
# =============================================================================

export SSH_AUTH_SOCK=~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock
