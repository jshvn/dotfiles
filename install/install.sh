#!/usr/bin/env bash

####################################################################################
#################################### Common ########################################
####################################################################################

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

  # for macOS, we want to stop install flow if we hit an error
  set -e

  ####### Step 1
  ####### Setup links

  # Set up symbolic links for ZSH and Git pointing to this cloned repo
  source "$DOTFILEDIR"/install/macos/link.sh

  ####### Step 2
  ####### Setup ZSH

  # Get Oh My ZSH up and running
  echo "Installing oh-my-zsh"
  if [ ! -e ~/.oh-my-zsh ]; then
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh) --unattended"
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
  echo "If curl or build-essential aren't already avaialble we will install them now"
  echo "We may ask for sudo access here so that we can install curl, build-essential, zsh"

  REQUIRED_PKG="curl build-essential"
  for package in $REQUIRED_PKG
  do
    PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $package|grep "install ok installed")
    echo Checking for $package: $PKG_OK
    if [ "" = "$PKG_OK" ]; then
      echo "$package not yet installed. installing $package"
      sudo apt install $package
    fi
  done

  ####### Step 1
  ####### Setup oh my zsh

  # Get Oh My ZSH up and running
  echo "Installing oh-my-zsh"
  if [ ! -e ~/.oh-my-zsh ]; then
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh) --unattended"
  fi

  ####### Step 2
  ####### Run Linux steps

  # run Linux specific install steps
  source "$DOTFILEDIR"/install/linux/linux.sh

  ####### Step 3
  ####### Setup links

  # Set up symbolic links for ZSH and Git pointing to this cloned repo
  source "$DOTFILEDIR"/install/linux/link.sh

fi


# Ensure we're using the correct ZSH shell
source "$DOTFILEDIR"/install/common/zsh.sh

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

$(tput setaf 7)Depending on which platform you are running this on, you might need to log out
and log back in to activate ZSH. 

You might also need to manually set your shell if the settings didn't take. To
do that you can run the command: $ chsh -s $(which zsh)

If you want to update to the latest version of the dotfiles, run the following command:
    $ update

"""
