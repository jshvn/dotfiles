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
brew tap homebrew/bundle
brew bundle --file "$DOTFILEDIR"/install/common/Brewfile
brew bundle --file "$DOTFILEDIR"/install/linux/Brewfile

# install complete
echo "Install complete! You'll probably need to log back in to switch to ZSH, or simply run $ chsh -s $(which zsh)"