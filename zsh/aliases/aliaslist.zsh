#!/bin/zsh

# this function allows you to easily list all of the available aliases
# it is included in the aliases directory simply because it deals with aliases

function aliaslist() {    # aliaslist() will list all of the available aliases. ex: $ aliaslist
    local aliaslist=$(alias | awk '{$1=$1};1' | highlight --syntax=bash)

    # print the final alias list
    echo "$aliaslist" | awk '{$1=$1};1'
}