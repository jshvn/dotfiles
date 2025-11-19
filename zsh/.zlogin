#!/bin/zsh
# -----------------------------------------------------------------------------
# .zlogin - Zsh login shell post-initialization
#
# Sourced by: login shells (after ~/.zshrc completes)
# Zsh startup order (login interactive example):
#   1) ~/.zshenv
#   2) ~/.zprofile   (login shells)
#   3) ~/.zshrc      (interactive shells)
#   4) ~/.zlogin     (after .zshrc for login shells)
#
# Purpose: Optional startup hooks for login shells
# Note: MOTD is now available as a function - call 'motd' to display
# -----------------------------------------------------------------------------

# Uncomment to auto-display MOTD on login:
# motd
