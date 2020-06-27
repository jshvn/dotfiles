#!/usr/bin/env bash

# curl isn't always available by default on ubuntu, install it. 
# while we're at it, lets install zsh too
echo "We're asking for sudo access here so that we can install curl, build-essential, zsh"
sudo apt install curl build-essential zsh

# now lets make ZSH our default shell
sudo usermod -s $(which zsh) $(whoami)

echo "Installing homebrew..."
if test ! "$(which brew)"; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
fi

# now, because homebrew installs to /home/linuxbrew/.linuxbrew/ by default it obviously won't be in my path 
# so I need to go ahead and update my path and profile
echo 'eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)' >> ~/.profile
eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)

# Update Homebrew recipes
echo "Updating homebrew..."
brew update

# gcc is needed by a number of binaries, go ahead and install it
brew install gcc

# Install all apps from the Brewfile
echo "Installing all packages and applications from the Brewfile"
brew tap homebrew/bundle
brew bundle --file "$DOTFILEDIR"/install/common/Brewfile
brew bundle --file "$DOTFILEDIR"/install/linux/Brewfile

# install complete
echo "Install complete! You'll probably need to log back in to switch to ZSH, or simply run $ chsh -s $(which zsh)"