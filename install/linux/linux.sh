#!/usr/bin/env bash

echo "Installing homebrew..."
if test ! "$(which brew)"; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
fi

# add homebrew to our current shell's path to continue with installation
eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)

# Update Homebrew recipes
echo "Updating homebrew..."
brew update

# gcc is needed by a number of binaries, go ahead and install it
brew install gcc

# Install all apps from the Brewfile
echo "Installing all packages and applications from the Brewfile"
brew bundle --file "$DOTFILEDIR"/install/common/Brewfile.rb
brew bundle --file "$DOTFILEDIR"/install/linux/Brewfile.rb

# ensure trip has root access
# https://github.com/fujiapple852/trippy
sudo chown root $(which trip) && sudo chmod +s $(which trip)
sudo setcap CAP_NET_RAW+p $(which trip)