#!/usr/bin/env bash

####### Step 0
####### Export dotfiledir environment variable

# Find dotfile repo directory on this system, set $DOTFILEDIR to contain absolute path
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
INSTALLFILEDIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"

# set primary dotfiledir which is the directory of where this git repo lives on the system
DOTFILEDIR="$(dirname "$INSTALLFILEDIR")"
export DOTFILEDIR

# for macOS, we want to stop install flow if we hit an error
set -e

####### Step 1
####### Setup links

# Set up symbolic links for ZSH and Git pointing to this cloned repo
source "$DOTFILEDIR"/install/macos/link.sh

####### Step 2
####### Install oh-my-zsh

# Get oh-my-zsh up and running
echo "Installing oh-my-zsh"
if [ ! -e ~/.oh-my-zsh ]; then
  sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh) --unattended"
fi

####### Step 3
####### Run macOS steps

# run macOS specific install steps
source "$DOTFILEDIR"/install/macos/brew.sh
source "$DOTFILEDIR"/install/macos/xcode.sh
source "$DOTFILEDIR"/install/macos/defaults.sh

# Ensure we're using the correct ZSH shell
# We want to use the latest that is installed by Homebrew
source "$DOTFILEDIR"/install/zsh.sh

# Install ZSH plugins
# install zsh-autosugestions
if [ ! -e ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions ]; then
  git clone git@github.com:zsh-users/zsh-autosuggestions.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
fi

# install zsh-syntax-highlighting
if [ ! -e ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting ]; then
  git clone git@github.com:zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
fi

# install complete

echo """

$(tput setaf 2)Install complete!

$(tput setaf 7)You might need to log out and log back in to activate Homebrew ZSH.

To check which shell is running use: $ which zsh
To change which shell is running use: $ chsh -s $(which zsh)

If you want to update to the latest version of the dotfiles, run the following command:
    $ update

"""
