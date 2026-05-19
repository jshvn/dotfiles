#!/bin/zsh

# =============================================================================
# shell/.zlogin -- zsh login-shell post-initialization
#
# Purpose:      Display MOTD on login (call `motd` interactively to re-display).
# Depends on:   shell/functions/motd.zsh (provides the motd function via
#               .zshrc's functions glob).
# Side effects: prints MOTD to stdout.
# =============================================================================

if (( $+functions[motd] )); then
    motd
fi
