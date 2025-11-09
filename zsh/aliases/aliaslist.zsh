#!/bin/zsh

# this function allows you to easily list all of the available aliases
# function aliaslist() {
#     # grab all of the common aliases to both platforms
#     local list=$(grep 'alias ' "$DOTFILEDIR/zsh/aliases.zsh" | awk '{$1=$1};1' | highlight --syntax=bash)

#     echo "$list" | sort -u -d -s
# }

function aliaslist() {    # aliaslist() will list all of the available functions. ex: $ aliaslist
    local aliaslist=()

    # grab all of the platform agnostic funcs
    for file in "$DOTFILEDIR/zsh/aliases/"*
    do
        if [[ -f $file && ${file:t} != "aliaslist.zsh" ]]; then
            aliaslist+=$(grep 'alias' "$file" | awk '{$1=$1};1' | highlight --syntax=bash)
            aliaslist+=$'\n'
        fi
    done

    echo "$aliaslist" | awk '{$1=$1};1'
}