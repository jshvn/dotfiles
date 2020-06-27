#!/usr/bin/env bash

echo "Installing homebrew..."
if test ! "$(which brew)"; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
fi

# Update Homebrew recipes
echo "Updating homebrew..."
brew update

# Install all apps from the Brewfile
echo "Installing all packages and applications from the Brewfile"
brew tap homebrew/bundle
brew bundle --file "$DOTFILEDIR"/install/common/Brewfile
brew bundle --file "$DOTFILEDIR"/install/linux/Brewfile