#!/bin/zsh

# this func allows you to easily list all of the available funcs
function functionlist() {    # functionlist() will list all of the available functions. ex: $ functionlist
    local funcslist=()

    # grab all of the platform agnostic funcs
    for file in "$DOTFILEDIR/zsh/functions/"*
    do
        if [[ -f $file && ${file:t} != "functionlist.zsh" ]]; then
            funcslist+=$(grep 'function' "$file" | awk '{$1=$1};1' | highlight --syntax=bash)
            funcslist+=$'\n'
        fi
    done

    echo "$funcslist" | awk '{$1=$1};1'
}