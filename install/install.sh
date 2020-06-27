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

  # Set up symbolic links for ZSH and Git pointing to this cloned repo
  source "$DOTFILEDIR"/install/macos/link.sh

  # Get Oh My ZSH up and running
  echo "Installing oh-my-zsh"
  if [ ! -e ~/.oh-my-zsh ]; then
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi

  # install homebrew
  echo "Installing homebrew..."
  if test ! "$(which brew)"; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
  fi

  source "$DOTFILEDIR"/install/macos/macos.sh
  source "$DOTFILEDIR"/install/macos/defaults.sh
else
  

####################################################################################
#################################### Linux #########################################
####################################################################################
  
  echo "Installing homebrew..."
  if test ! "$(which brew)"; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
  fi
  
fi






