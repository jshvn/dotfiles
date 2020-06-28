#!/bin/zsh

##############################
###### General
##############################

# reload current configuration
alias reload="source ~/.zshrc"

# Print each PATH entry on a separate line
alias path='echo -e ${PATH//:/\\n}'

# print the dotfile directory
alias dotfile='cd $DOTFILEDIR'
alias dotfiles='cd $DOTFILEDIR'

# enter ncdu
alias fsa='ncdu'

##############################
###### Networking
##############################

# helper methods
getipv4=$(curl -4 simpip.com --max-time 1 --proto-default https --silent)
getipv6=$(curl -6 simpip.com --max-time 1 --proto-default https --silent)