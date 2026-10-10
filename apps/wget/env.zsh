# =============================================================================
# apps/wget/env.zsh -- login-shell environment for wget
#
# Purpose:      Point wget at its config under XDG_CONFIG_HOME; it reads only
#               ~/.wgetrc otherwise. Linked into $XDG_STATE_HOME/dotfiles/env.d/
#               by the switch when the app is on, and sourced from there by
#               shell/.zprofile.
# Depends on:   apps/wget/wgetrc, linked to $XDG_CONFIG_HOME/wget/wgetrc.
# Side effects: exports WGETRC.
# =============================================================================

export WGETRC="$XDG_CONFIG_HOME/wget/wgetrc"
