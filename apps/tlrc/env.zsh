# =============================================================================
# apps/tlrc/env.zsh -- login-shell environment for tlrc
#
# Purpose:      Point tlrc at its config under XDG_CONFIG_HOME; on macOS it
#               reads ~/Library/Application Support/tlrc/config.toml otherwise.
#               Linked into $XDG_STATE_HOME/dotfiles/env.d/ by the switch, and
#               sourced from there by shell/.zprofile.
# Depends on:   apps/tlrc/config.toml, linked to $XDG_CONFIG_HOME/tlrc/config.toml.
# Side effects: exports TLRC_CONFIG.
# =============================================================================

export TLRC_CONFIG="$XDG_CONFIG_HOME/tlrc/config.toml"
