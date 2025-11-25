#!/bin/zsh

# mkcd - Create directory and cd into it
function mkcd() {    # mkcd() will create a directory and cd into it. ex: $ mkcd new-project
    mkdir -p "$1" && cd "$1"
}