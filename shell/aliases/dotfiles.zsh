#!/bin/zsh

# =============================================================================
# shell/aliases/dotfiles.zsh -- dotfiles-related aliases
#
# Purpose:      `update` shortcut (and future repo helpers). `task install`
#               IS `task update` in v2 -- no separate update pipeline.
#               `task -d "$DOTFILEDIR"` so `update` works from any CWD.
# Depends on:   $DOTFILEDIR (exported by shell/.zshrc).
# Side effects: defines alias `update`.
# =============================================================================

alias update='task -d "$DOTFILEDIR" install'
