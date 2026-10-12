# =============================================================================
# apps/vscode/env.zsh -- login-shell environment for VS Code
#
# Purpose:      Make VS Code the visual editor (git's commit editor included:
#               apps/git/config sets none, so git reads VISUAL, then the nano
#               EDITOR in shell/.zshenv). Point VS Code's built-in Copilot at
#               XDG_CONFIG_HOME; it writes config, logs and skills to ~/.copilot
#               otherwise. VS Code reads the login-shell environment at launch,
#               so the extension host sees this even when started from the Dock.
#               Linked into $XDG_STATE_HOME/dotfiles/env.d/ by the switch when
#               the app is on, and sourced from there by shell/.zprofile.
# Depends on:   the `code` CLI on PATH.
# Side effects: exports VISUAL, COPILOT_HOME.
# =============================================================================

export VISUAL="code --wait"
export COPILOT_HOME="$XDG_CONFIG_HOME/copilot"
