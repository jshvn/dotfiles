#!/usr/bin/env bash

set -e

# Set up symbolic links for ZSH and Git pointing to this cloned repo
ln -sf "$HOME"/Git/personal/dotfiles/zsh/.zshrc "$HOME"/.zshrc
ln -sf "$HOME"/Git/personal/dotfiles/zsh/aliases.zsh "$HOME"/.aliases.zsh
ln -sf "$HOME"/Git/personal/dotfiles/zsh/functions.zsh "$HOME"/.functions.zsh
ln -sf "$HOME"/Git/personal/dotfiles/git/.gitconfig "$HOME"/.gitconfig
ln -sf "$HOME"/Git/personal/dotfiles/git/.gitignore_global "$HOME"/.gitignore_global
ln -sf "$HOME"/Git/personal/dotfiles/ssh/.ssh/config "$HOME"/.ssh/config


# Get Oh My ZSH up and running
if [ ! -e ~/.oh-my-zsh ]; then
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

if [ "$(uname)" == "Darwin" ]; then
  source ./macos/macos.sh
else
  echo ""
  echo "This isn't a Mac, so we're all done here!"
  echo "Logout/restart now for the full effects."
  exit 0
fi