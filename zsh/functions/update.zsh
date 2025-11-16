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
	# Run the updater in a child zsh so any `exec` performed by the updater
	# replaces only the child process — not the current interactive shell
	# (when `omz update` applies an update it may exec a new shell, which
	# would otherwise replace the shell running this func and terminate
	# the rest of the script).
	zsh -ic 'omz update' || true

    # update tldr definitions
    tldr --update

    # update antigen plugins
    antigen update
	
	# execute the install script
	zsh $DOTFILEDIR/install.zsh

	# return user to previous directory
	cd $currentdir
}