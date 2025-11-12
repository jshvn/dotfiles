#!/bin/zsh

# reload current configuration
alias reload="source $HOME/.zshrc"

# show current environment variables
alias environment="env"

# Print each PATH entry on a separate line
alias path='echo -e ${PATH//:/\\n}'

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

# add formatting to glow command
alias glow='glow --style "$DOTFILEDIR/zsh/styles/glow_style.json" -w 120'

# open finder at current location
alias finder="open -a Finder ./"

# Show/hide hidden files in Finder
alias findershow="defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder"
alias finderhide="defaults write com.apple.finder AppleShowAllFiles -bool false && killall Finder"

# show last time macOS was installed
alias lastinstalled="ls -l /var/db/.AppleSetupDone"