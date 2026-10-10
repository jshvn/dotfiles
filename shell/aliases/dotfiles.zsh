#!/bin/zsh

# =============================================================================
# shell/aliases/dotfiles.zsh -- dotfiles-related aliases
#
# Purpose:      `update` shortcut: task install, which fast-forwards the
#               checkout, switches, and refreshes the plugin bundles.
#               `task -d "$DOTFILEDIR"` so `update` works from any CWD.
# Depends on:   $DOTFILEDIR (exported by shell/.zshrc).
# Side effects: defines alias `update`.
# =============================================================================

alias update='task -d "$DOTFILEDIR" install'
