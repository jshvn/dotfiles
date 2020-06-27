#!/usr/bin/env bash

set -e

if [[ -z $DOTFILEDIR ]]; then
  # Find dotfile repo directory on this system, set $DOTFILEDIR to contain absolute path
  SOURCE="${BASH_SOURCE[0]}"
  while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
    DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
  done
  INSTALLFILEDIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  DOTFILEDIR="$(dirname "$(dirname "$INSTALLFILEDIR")")"
fi

# Set up symbolic links for ZSH and Git pointing to this cloned repo
echo "Setting up symbolic links for ZSH, gitconfig"
ln -sf "$DOTFILEDIR"/zsh/.zshrc "$HOME"/.zshrc
ln -sf "$DOTFILEDIR"/zsh/linux/aliases.zsh "$HOME"/.aliases.zsh
ln -sf "$DOTFILEDIR"/zsh/linux/functions.zsh "$HOME"/.functions.zsh
ln -sf "$DOTFILEDIR"/git/linux/.gitconfig "$HOME"/.gitconfig
ln -sf "$DOTFILEDIR"/git/linux/.gitignore_global "$HOME"/.gitignore_global
