#!/bin/zsh

# update the dotfiles completely
function update() {    # update() will update the current dotfiles installation and dependencies. ex: $ update
	# save the current directory
	currentdir=$(pwd)

	# navigate to dotfile install directory
	dotfiles

	# pull new version from origin
	git pull

	# update oh-my-zsh
	# Call upgrade.sh directly instead of 'omz update' to avoid exec-ing a new shell
	zsh "$ZSH/tools/upgrade.sh"

    # update tldr definitions
    tldr --update

    # update antigen plugins
    antigen update
	
	# execute the install script
	zsh $DOTFILEDIR/install.zsh

	# return user to previous directory
	cd $currentdir
}