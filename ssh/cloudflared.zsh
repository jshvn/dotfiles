#!/bin/zsh

# This script allows me to directly use cloudflared tunnels via ProxyCommand in SSH configs

CLOUDFLARED_BIN_PATH=""

# MacOS 
if [[ `uname` == "Darwin" ]]; then
    if [[ `uname -m` == "arm64" ]]; then
        CLOUDFLARED_BIN_PATH="/opt/homebrew/bin/cloudflared"
    else 
        CLOUDFLARED_BIN_PATH="/usr/local/bin/cloudflared"
    fi
else
# Linux
    CLOUDFLARED_BIN_PATH="/usr/local/bin/cloudflared"
fi

eval "$CLOUDFLARED_BIN_PATH $@"