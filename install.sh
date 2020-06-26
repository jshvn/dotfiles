#!/usr/bin/env bash

set -e

# find git directory
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
GITDIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"

# Set up symbolic links for ZSH and Git pointing to this cloned repo
ln -sf "$GITDIR"/zsh/.zshrc "$HOME"/.zshrc
ln -sf "$GITDIR"/zsh/aliases.zsh "$HOME"/.aliases.zsh
ln -sf "$GITDIR"/functions.zsh "$HOME"/.functions.zsh
ln -sf "$GITDIR"/git/.gitconfig "$HOME"/.gitconfig
ln -sf "$GITDIR"/git/.gitignore_global "$HOME"/.gitignore_global
ln -sf "$GITDIR"/ssh/.ssh/config "$HOME"/.ssh/config


# Get Oh My ZSH up and running
if [ ! -e ~/.oh-my-zsh ]; then
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

if [ "$(uname)" == "Darwin" ]; then
  source "$GITDIR"/macos/macos.sh
else
  echo ""
  echo "This isn't a Mac, so we're all done here!"
  echo "Logout/restart now for the full effects."
  exit 0
fi