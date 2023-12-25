#!/bin/zsh

# Print information related to current system or git repository
function info() {    # info() will print git repository info if inside a repository, otherwise print system info. ex: $ info
    git check-ignore -q . 2>/dev/null; if [ "$?" -ne "1" ]; then
        neofetch
    else
        onefetch
    fi;
}