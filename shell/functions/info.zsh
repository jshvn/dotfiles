#!/bin/zsh

# =============================================================================
# shell/functions/info.zsh -- system or git-repo fact sheet
#
# Purpose:      Inside a git work tree, print `onefetch` output. Otherwise,
#               run `fastfetch`; pass "all" for the detailed config.
# Depends on:   onefetch, fastfetch, git.
# Side effects: stdout only.
# =============================================================================

function info() {    # info() shows onefetch in a git repo, else fastfetch ('all' for detail). ex: $ info all
    local show_all=false
    if [[ "$1" == "all" ]]; then
        show_all=true
    fi
    
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        onefetch 
    else 
        if $show_all; then
            fastfetch -c all --logo-padding-top 22
        else
            fastfetch --logo-padding-top 4
        fi
    fi
}