#!/bin/zsh
# shell/aliases/dotfiles.zsh -- dotfiles-related aliases.
#
# Purpose: update shortcut and (future) repo helpers.
#
# Why this replaces v1: the `update` alias below replaces v1's
# zsh/functions/update.zsh wrapper. Per CF-06 and Phase 2 D-10,
# `task install` IS `task update` -- there is no separate update
# pipeline in v2.

alias update='task install'
