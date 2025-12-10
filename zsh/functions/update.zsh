#!/bin/zsh

# update the dotfiles completely
function update() {    # update() will update the current dotfiles installation and dependencies. ex: $ update
	# save the current directory
	local currentdir=$(pwd)

	# navigate to dotfile install directory
	cd "$DOTFILEDIR"

	# pull new version from origin
	git pull

	# update oh-my-zsh
	# https://github.com/ohmyzsh/ohmyzsh/wiki/FAQ#how-do-i-update-oh-my-zsh
	zsh "$ZSH/tools/upgrade.sh"

    # update tldr definitions
    tldr --update

    # update antigen plugins
    antigen update
	
	# execute the install script
	zsh "$DOTFILEDIR/install.zsh"

	# return user to previous directory
	cd "$currentdir"
}