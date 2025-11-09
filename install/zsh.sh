#!/usr/bin/env bash

# This script exists to ensure we are using the ZSH shell that is installed by Homebrew

# LINUX: /home/linuxbrew/.linuxbrew/bin/zsh
# MAC (arm): /opt/homebrew/bin/zsh
# MAC (intel): /user/local/bin/zsh

ZSHBREWSHELL=""

if [ "$(uname)" == "Darwin" ]; then
    if [[ `uname -m` == "arm64" ]]; then
        ZSHBREWSHELL="/opt/homebrew/bin/zsh"
    else 
        ZSHBREWSHELL="/user/local/bin/zsh"
    fi
else 
    ZSHBREWSHELL="/home/linuxbrew/.linuxbrew/bin/zsh"
fi

# Check if ZSH (installed by Homebrew) is currently in /etc/shells
if [[ "$(cat /etc/shells)" != *"$ZSHBREWSHELL"* ]]; then
    echo "Homebrew ZSH is not currently present in /etc/shells, adding it now..."
    echo $ZSHBREWSHELL | sudo tee -a /etc/shells
fi

CURRENTSHELL=$(which $SHELL)

# Finally, we change our shell if it is not ZSH
if [ "$CURRENTSHELL" != "$ZSHBREWSHELL" ]; then
    chsh -s $ZSHBREWSHELL
fi 
