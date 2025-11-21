#!/bin/zsh

# install homebrew
echo "Installing homebrew..."
if ! command -v brew &> /dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Evaluate Homebrew shellenv to make brew available immediately
    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
fi

# Update Homebrew recipes
echo "Updating homebrew..."
brew update
brew upgrade

# Install all apps from the Brewfile
echo "Installing all packages and applications from the Brewfile"
brew bundle --file "$DOTFILEDIR"/install/Brewfile.rb