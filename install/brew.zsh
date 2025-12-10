#!/bin/zsh

# install homebrew
echo "Installing homebrew..."
if ! command -v brew &> /dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Evaluate Homebrew shellenv to make brew available immediately
    # this loads environment variables for brew without needing to restart the shell
    if [[ "$(uname)" == "Darwin" ]]; then
        if [[ "$(uname -m)" == "arm64" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        else 
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    else 
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
fi

# Update Homebrew recipes
echo "Updating homebrew..."
brew update
brew upgrade

# prune cached versions older than 30 days
brew cleanup --prune=30

# Install all apps from the Brewfile
echo "Installing all packages and applications from the Brewfile"
brew bundle --file "$DOTFILEDIR"/install/Brewfile.rb