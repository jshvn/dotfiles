#!/bin/zsh

# =============================================================================
# shell/aliases/general.zsh -- catch-all interactive shell aliases
#
# Purpose:      Reload, env inspection, PATH pretty-print, repo navigation,
#               directory listing (eza when present), history with colours,
#               and the `t` shorthand for `task`.
# Depends on:   eza (optional), ncdu, highlight, omz_history, task.
# Side effects: defines aliases reload, path, dotfiles, fsa, perms,
#               ls (when eza present), ll, lastinstalled, history, t.
# =============================================================================

alias reload='source "$ZDOTDIR"/.zshrc'
alias path='echo -e ${PATH//:/\\n} | highlight --syntax=bash'
alias dotfiles='cd "$DOTFILEDIR"'
alias fsa='ncdu'
alias perms='permissions'

# Lazy expansion (single quotes) + presence guard: when eza is absent,
# the alias is not defined and the system `ls` falls through. Eager
# `$(command -v eza)` expansion at source time was masking the system
# `ls` entirely when eza was uninstalled (Plan 13-02 REVIEW.md row 13).
if command -v eza >/dev/null 2>&1; then
    alias ls='eza --time-style long-iso'
fi
alias ll='ls -alh'

# /var/db/.AppleSetupDone is touched when macOS finishes initial setup.
alias lastinstalled="ls -l /var/db/.AppleSetupDone"

alias history="omz_history -t '%Y-%m-%d %I:%M:%S' | highlight --syntax=bash"
alias t='task'
