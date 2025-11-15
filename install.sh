#!/bin/zsh

echo """
$(tput setaf 2)Beginning dotfiles install: 
$(tput setaf 7)PID=$(tput setaf 4)$$  
$(tput setaf 7)process=$(tput setaf 4)$(ps -p $$ -o comm=)  
$(tput setaf 7)argv0=$(tput setaf 4)$0$(tput setaf 7)
"""

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
DOTFILEDIR="$INSTALLFILEDIR"

# set primary dotfiledir which is the directory of where this git repo lives on the system
export DOTFILEDIR

# for macOS, we want to stop install flow if we hit an error
set -e

####### Step 1
####### Setup links

# Set up symbolic links for ZSH and Git pointing to this cloned repo
source "$DOTFILEDIR"/install/links.sh


####### Step 2
####### Run macOS steps

# run macOS specific install steps
source "$DOTFILEDIR"/install/brew.sh
source "$DOTFILEDIR"/install/xcode.sh
source "$DOTFILEDIR"/install/defaults.sh

####### Step 3
####### Run macOS steps

# Ensure we're using the correct ZSH shell
# We want to use the latest that is installed by Homebrew
# And setup our zsh plugins
source "$DOTFILEDIR"/install/zsh.sh

# install complete

echo """

$(tput setaf 2)Install complete!

$(tput setaf 7)You might need to log out and log back in to activate Homebrew ZSH.

To check which shell is running use: $ $(tput setaf 2)which zsh$(tput setaf 7)
To change which shell is running use: $ $(tput setaf 2)chsh -s $(which zsh)$(tput setaf 7)

If you want to update to the latest version of the dotfiles, run the following command:
    $ $(tput setaf 2)update$(tput setaf 7)

"""
