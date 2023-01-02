#!/bin/zsh

DIRECTORY=""

# MacOS 
if [[ `uname` == "Darwin" ]]; then
    if [[ `uname -m` == "arm64" ]]; then
        DIRECTORY="/opt/homebrew/bin/cloudflared"
    else 
        DIRECTORY="/usr/local/bin/cloudflared"
    fi
else
# Linux
    DIRECTORY="/usr/local/bin/cloudflared"
fi

eval "$DIRECTORY $@"