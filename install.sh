#!/usr/bin/env bash

set -e

# Set up symbolic links for ZSH and Git pointing to this cloned repo
ln -sf "$HOME"/Git/personal/dotfiles/zsh/.zshrc "$HOME"/.zshrc
ln -sf "$HOME"/Git/personal/dotfiles/git/.gitconfig "$HOME"/.gitconfig
ln -sf "$HOME"/Git/personal/dotfiles/git/.gitignore_global "$HOME"/.gitignore_global
ln -sf "$HOME"/Git/personal/dotfiles/ssh/.ssh/config "$HOME"/.ssh/config


if [ "$(uname)" == "Darwin" ]; then
  # shellcheck disable=SC1091
  source ./macos/macos.sh
else
  echo ""
  echo "This isn't a Mac, so we're all done here!"
  echo "Logout/restart now for the full effects."
  exit 0
fi