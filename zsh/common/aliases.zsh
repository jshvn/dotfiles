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

# update the dotfiles
#alias update='dotfiles; git pull; ./bootstrap.sh;'