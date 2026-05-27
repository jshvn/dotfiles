#!/bin/zsh

# =============================================================================
# shell/aliases/dotfiles.zsh -- dotfiles-related aliases
#
# Purpose:      `update` shortcut. Fast-forwards the repo from its remote
#               (task repo:sync, feature-gated, warn-only) then runs
#               task install. Two separate `task` processes so pulled
#               taskfile changes are parsed by the install run.
#               `task -d "$DOTFILEDIR"` so `update` works from any CWD.
# Depends on:   $DOTFILEDIR (exported by shell/.zshrc).
# Side effects: defines alias `update`.
# =============================================================================

alias update='task -d "$DOTFILEDIR" repo:sync && task -d "$DOTFILEDIR" install'
