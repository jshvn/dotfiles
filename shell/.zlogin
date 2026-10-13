#!/bin/zsh

# =============================================================================
# shell/.zlogin -- zsh login-shell post-initialization
#
# Purpose:      Display MOTD on login (call `motd` interactively to re-display),
#               only when stdout is a terminal: VS Code resolves its
#               environment through a login shell whose output is a pipe.
# Depends on:   shell/motd/motd.zsh (defines motd; the switch links it into
#               aliases.d/ when the profile sets shell.motd, and .zshrc
#               sources it from there). Without it, no MOTD.
# Side effects: prints MOTD to stdout; motd starts background cache refreshes.
# =============================================================================

if [[ -t 1 ]] && (( $+functions[motd] )); then
    motd
fi
