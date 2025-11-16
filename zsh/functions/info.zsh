#!/bin/zsh

# Print information related to current system or git repository
function info() {    # info() will print git repository info if inside a repository, otherwise print system info. Pass "all" for detailed output. ex: $ info all
    local show_all=false
    if [[ "$1" == "all" ]]; then
        show_all=true
    fi
    
    git check-ignore -q . 2>/dev/null; if [ "$?" -ne "1" ]; then
        # Not in a git repo - show system info
        if $show_all; then
            fastfetch -c all --logo-padding-top 22
        else
            fastfetch --logo-padding-top 4
        fi
    else
        onefetch
    fi
}