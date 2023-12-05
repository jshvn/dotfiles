#!/bin/zsh

DIRECTORY=""

# MacOS 
if [[ `uname` == "Darwin" ]]; then
    if [[ `uname -m` == "arm64" ]]; then
        DIRECTORY="/opt/homebrew/bin/brew"
    else 
        DIRECTORY="/usr/local/bin/brew"
    fi
else
# Linux
    DIRECTORY="/home/linuxbrew/.linuxbrew/bin/brew"
fi

eval "$($DIRECTORY shellenv)"