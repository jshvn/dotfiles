#!/bin/zsh

# =============================================================================
# shell/.zlogin -- zsh login-shell post-initialization
#
# Purpose:      Display MOTD on login (call `motd` interactively to re-display),
#               only when stdout is a terminal: VS Code resolves its
#               environment through a login shell whose output is a pipe.
# Depends on:   shell/functions/motd.zsh (provides the motd function via
#               .zshrc's functions glob).
# Side effects: prints MOTD to stdout; motd starts background cache refreshes.
# =============================================================================

if [[ -t 1 ]] && (( $+functions[motd] )); then
    motd
fi
