#!/bin/zsh

# list all ssh endpoints from /ssh/.ssh/config
function sshlist() {    # sshlist() will list all available ssh endpoints. ex: $ sshlist
    local CONFIG_PATH=("$DOTFILEDIR/ssh/configs"/**/*(.))
    for f in $CONFIG_PATH
    do
        grep "Host " "$f" | awk '{print $2}' | while read -r host; do
            echo "$host" | highlight --syntax=bash
        done
    done
}
