#!/bin/zsh

# list all ssh endpoints from /ssh/.ssh/config
function sshlist() {    # sshlist() will list all available ssh endpoints. ex: $ sshlist
    local CONFIG_PATH=("$DOTFILEDIR/ssh/configs"/**/*(.))
    for f in $CONFIG_PATH
    do
        cat "$f" | 
            grep -e "Host " -e "######## " -e "#### $" |
            grep -v "Host \*" |
            grep "Host \|####"
    done
}