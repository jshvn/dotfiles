# =============================================================================
# apps/terraform/env.zsh -- login-shell environment for terraform
#
# Purpose:      Turn off HashiCorp's version check, the only thing terraform
#               writes to ~/.terraform.d unless logged in. Linked into
#               $XDG_STATE_HOME/dotfiles/env.d/ by the switch when the app is
#               on, and sourced from there by shell/.zprofile.
# Depends on:   nothing.
# Side effects: exports CHECKPOINT_DISABLE.
# =============================================================================

export CHECKPOINT_DISABLE=1
