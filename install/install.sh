#!/usr/bin/env bash

####################################################################################
#################################### Common ########################################
####################################################################################

# for any errors, go ahead and cancel
set -e

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

# Execute setup depending on the system
if [ "$(uname)" == "Darwin" ]; then

####################################################################################
#################################### macOS #########################################
####################################################################################

  ####### Step 0
  ####### Install any dependencies to run the setup scripts

  ####### Step 1
  ####### Setup links

  # Set up symbolic links for ZSH and Git pointing to this cloned repo
  source "$DOTFILEDIR"/install/macos/link.sh

  ####### Step 2
  ####### Setup ZSH

  # Get Oh My ZSH up and running
  echo "Installing oh-my-zsh"
  if [ ! -e ~/.oh-my-zsh ]; then
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi

  ####### Step 3
  ####### Run macOS steps

  # run macOS specific install steps
  source "$DOTFILEDIR"/install/macos/macos.sh
  source "$DOTFILEDIR"/install/macos/defaults.sh
else
  

####################################################################################
#################################### Linux #########################################
####################################################################################

  ####### Step 0
  ####### Install any dependencies to run the setup scripts

  # curl isn't always available by default on ubuntu, install it. 
  # while we're at it, lets install zsh too
  echo "We're asking for sudo access here so that we can install curl, build-essential, zsh"
  sudo apt install curl build-essential zsh

  # now lets make ZSH our default shell
  # this wont take effect until after we have rebooted
  echo "changing default shell"
  sudo chsh -s $(which zsh)

  ####### Step 1
  ####### Setup links

  echo "setting up links"
  # Set up symbolic links for ZSH and Git pointing to this cloned repo
  source "$DOTFILEDIR"/install/linux/link.sh

  ####### Step 2
  ####### Setup ZSH

  # Get Oh My ZSH up and running
  echo "Installing oh-my-zsh"
  if [ ! -e ~/.oh-my-zsh ]; then
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh) --unattended"
  fi

  ####### Step 3
  ####### Run Linux steps

  echo "running linux install steps"
  # run Linux specific install steps
  source "$DOTFILEDIR"/install/linux/linux.sh
fi






