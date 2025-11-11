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
    omz update

    # update tldr definitions
    tldr --update

    # update antigen plugins
    antigen update
	
	# execute the install script
	# note: we manually specify bash here, since the install script is written in bash 
	# and we're calling it from zsh. bad things happen if you use source instead
	bash $DOTFILEDIR/install.sh

	# return user to previous directory
	cd $currentdir
}