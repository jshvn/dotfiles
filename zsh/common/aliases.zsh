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

# shorthand for permissions function
alias perms='permissions'

# highlight printing
alias highlight-blue="highlight --out-format=xterm256 --style=fine_blue"

##############################
###### Networking
##############################

# jgrid.net machines
alias atium="ssh josh@atium-ssh.jgrid.net"
alias copper="ssh josh@copper-ssh.jgrid.net"
alias tin="ssh josh@tin-ssh.jgrid.net"
alias zinc="ssh josh@zinc-ssh.jgrid.net"

# helper methods
getipv4=$(curl -4 simpip.com --max-time 1 --proto-default https --silent)
getipv6=$(curl -6 simpip.com --max-time 1 --proto-default https --silent)