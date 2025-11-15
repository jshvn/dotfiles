#!/bin/zsh

# install homebrew
echo "Installing homebrew..."
if test ! "$(which brew)"; then
  /bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
fi

# Update Homebrew recipes
echo "Updating homebrew..."
brew update

# Install all apps from the Brewfile
echo "Installing all packages and applications from the Brewfile"
brew bundle --file "$DOTFILEDIR"/install/Brewfile.rb