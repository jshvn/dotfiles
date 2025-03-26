#!/usr/bin/env bash

# install homebrew
echo "Installing homebrew..."
if test ! "$(which brew)"; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
fi

# Update Homebrew recipes
echo "Updating homebrew..."
brew update

# Install all apps from the Brewfile
echo "Installing all packages and applications from the Brewfile"
brew bundle --file "$DOTFILEDIR"/install/common/Brewfile.rb
brew bundle --file "$DOTFILEDIR"/install/macos/Brewfile.rb

if xcode-select -p 1>/dev/null; then
  echo "Xcode Command Line Tools already installed, skipping installation"
else
  echo "Installing Xcode Command Line Tools"
  # Install Xcode Command Line Tools
  sudo xcode-select --install
  # Accept Xcode license
  sudo xcodebuild -license accept
fi