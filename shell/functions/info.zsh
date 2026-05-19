#!/bin/zsh

# Print information related to current system or git repository
function info() {    # info() print git repository or system info. Pass "all" for detailed output. ex: $ info all
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