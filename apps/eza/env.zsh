# =============================================================================
# apps/eza/env.zsh -- login-shell environment for eza's theme
#
# Purpose:      Point eza at ~/.config/eza, where the switch links theme.yaml.
#               On macOS eza reads ~/Library/Application Support/eza and
#               ignores XDG_CONFIG_HOME. Linked into
#               $XDG_STATE_HOME/dotfiles/env.d/ by the switch and sourced from
#               there by shell/.zprofile.
# Depends on:   eza (apps/eza/default.nix); XDG_CONFIG_HOME (.zshenv).
# Side effects: exports EZA_CONFIG_DIR.
# =============================================================================

export EZA_CONFIG_DIR="$XDG_CONFIG_HOME/eza"
