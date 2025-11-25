#!/bin/zsh

function aliaslist() {    # aliaslist() will list all of the available aliases. ex: $ aliaslist
    local aliaslist=$(alias | awk '{$1=$1};1' | highlight --syntax=bash)

    # print the final alias list
    echo "$aliaslist" | awk '{$1=$1};1'
}