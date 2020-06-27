#!/usr/bin/env bash

# Update Homebrew recipes
echo "Updating homebrew..."
brew update

# Install all apps from the Brewfile
echo "Installing all packages and applications from the Brewfile"
brew tap homebrew/bundle
brew bundle --file "$DOTFILEDIR"/install/common/Brewfile
brew bundle --file "$DOTFILEDIR"/install/linux/Brewfile