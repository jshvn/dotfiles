#!/usr/bin/env bash

set -e

# Find dotfile repo directory on this system, set $DOTFILEDIR to contain absolute path
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DOTFILEDIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"

# Set up symbolic links for ZSH and Git pointing to this cloned repo
echo "Setting up symbolic links for ZSH, gitconfig, sshconfig"
ln -sf "$DOTFILEDIR"/zsh/.zshrc "$HOME"/.zshrc
ln -sf "$DOTFILEDIR"/zsh/aliases.zsh "$HOME"/.aliases.zsh
ln -sf "$DOTFILEDIR"/zsh/functions.zsh "$HOME"/.functions.zsh
ln -sf "$DOTFILEDIR"/git/.gitconfig "$HOME"/.gitconfig
ln -sf "$DOTFILEDIR"/git/.gitignore_global "$HOME"/.gitignore_global
ln -sf "$DOTFILEDIR"/ssh/.ssh/config "$HOME"/.ssh/config


# Get Oh My ZSH up and running
echo "Installing oh-my-zsh"
if [ ! -e ~/.oh-my-zsh ]; then
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# Execute macOS specific setup
if [ "$(uname)" == "Darwin" ]; then
  source "$DOTFILEDIR"/macos/macos.sh
  source "$DOTFILEDIR"/macos/defaults.sh
else
  echo ""
  echo "This isn't a Mac, so we're all done here!"
  echo "Logout/restart now for the full effects."
  exit 0
fi