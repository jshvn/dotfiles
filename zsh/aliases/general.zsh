#!/bin/zsh

# reload current configuration
alias reload="source $ZDOTDIR/.zshrc"

# show current environment variables
alias environment="env"

# Print each PATH entry on a separate line
alias path='echo -e ${PATH//:/\\n} | highlight --syntax=bash'

# print the dotfile directory
alias dotfile='cd $DOTFILEDIR'
alias dotfiles='cd $DOTFILEDIR'

# enter ncdu
alias fsa='ncdu'

# shorthand for permissions function
alias perms='permissions'

# shorthands for directory listing
alias ls="$(which eza) --time-style long-iso"
alias ll='ls -alh'

# open finder at current location
alias finder="open -a Finder ./"

# Show/hide hidden files in Finder
alias findershow="defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder"
alias finderhide="defaults write com.apple.finder AppleShowAllFiles -bool false && killall Finder"

# show last time macOS was installed
alias lastinstalled="ls -l /var/db/.AppleSetupDone"

# color history output
alias history="omz_history -t '%Y-%m-%d %I:%M:%S' | highlight --syntax=bash"

# ghostty alias
alias g="/Applications/Ghostty.app/Contents/MacOS/ghostty"