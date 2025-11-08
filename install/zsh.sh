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

# Get oh-my-zsh up and running
echo "Installing oh-my-zsh"
if [ ! -e ~/.oh-my-zsh ]; then
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh) --unattended"
fi

# Install ZSH plugins
# install zsh-autosugestions
if [ ! -e ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions ]; then
  git clone git@github.com:zsh-users/zsh-autosuggestions.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
fi

# install zsh-syntax-highlighting
if [ ! -e ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting ]; then
  git clone git@github.com:zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
fi