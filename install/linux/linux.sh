#!/usr/bin/env bash

/bin/bash echo "Installing homebrew..."
if test ! "$(which brew)"; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
fi

# Update Homebrew recipes
echo "Updating homebrew..."
/bin/bash brew update

# gcc is needed by a number of binaries, go ahead and install it
/bin/bash brew install gcc

# Install all apps from the Brewfile
/bin/bash echo "Installing all packages and applications from the Brewfile"
/bin/bash brew tap homebrew/bundle
/bin/bash brew bundle --file "$DOTFILEDIR"/install/common/Brewfile
/bin/bash brew bundle --file "$DOTFILEDIR"/install/linux/Brewfile

# install complete
/bin/bash echo "Install complete! You'll probably need to log back in to switch to ZSH, or simply run $ chsh -s $(which zsh)"