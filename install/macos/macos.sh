#!/usr/bin/env bash

# Update Homebrew recipes
echo "Updating homebrew..."
brew update

# Install all apps from the Brewfile
echo "Installing all packages and applications from the Brewfile"
brew tap homebrew/bundle
brew bundle --file "$DOTFILEDIR"/install/common/Brewfile
brew bundle --file "$DOTFILEDIR"/install/macos/Brewfile

if xcode-select -p 1>/dev/null; then
  echo "Xcode Command Line Tools already installed, skipping installation"
else
  echo "Installing Xcode Command Line Tools"
  # Install Xcode Command Line Tools
  sudo xcode-select --install
  # Accept Xcode license
  sudo xcodebuild -license accept
fi
