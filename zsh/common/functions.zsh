#!/bin/zsh

# this file is meant to encapsulate functions that are general and cover things like
# files, system operations, dotfile changes, etc.

# any scripts that interact with APIs or non-system software should be placed
# in their own script in the scripts subdirectory

# any scripts that are platform specific should be included in their respective
# platform's functions.zsh file

# update the dotfiles completely
function update() {    # update() will update the current dotfiles installation and dependencies. ex: $ update
	# save the current directory
	currentdir=$(pwd)

	# navigate to dotfile install directory
	dotfiles

	# pull new version from origin
	git pull
	
	# execute the install script
	# note: we manually specify bash here, since the install script is written in bash 
	# and we're calling it from zsh. bad things happen if you use source instead
	bash $DOTFILEDIR/install/install.sh

	# return user to previous directory
	cd $currentdir
}

# Extract a compressed archive without worrying about which tool to use
function extract() { # extract() will unzip/unrar/untar any type of compressed file. ex $ extract file.tar.gz
  if [ -f $1 ]; then
    case $1 in
      *.tar.bz2)   tar xjf $1    ;;
      *.tar.gz)    tar xzf $1    ;;
      *.bz2)       bunzip2 $1    ;;
      *.rar)       unrar x $1    ;;
      *.gz)        gunzip $1     ;;
      *.tar)       tar xf $1     ;;
      *.tbz2)      tar xjf $1    ;;
      *.tgz)       tar xzf $1    ;;
      *.zip)       unzip $1      ;;
      *.Z)         uncompress $1 ;;
      *.7z)        7z x $1       ;;
      *)           echo "'$1' cannot be extracted via extract()" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}

# Determine size of a file or total size of a directory
function fs() {    # fs() will print a human readable size of given file or directory. ex: $ fs ~
	if du -b /dev/null > /dev/null 2>&1; then
		local arg=-sbh;
	else
		local arg=-sh;
	fi
	if [[ -n "$@" ]]; then
		du $arg -- "$@";
	else
        if [[ $(uname) == "Darwin" ]]; then
            du $arg .[^.]* ./*;
        else
            find . -type f | du -ah -d1
        fi;
	fi;
}

# Prints permissions of file
function permissions() {    # permissions() will print human readable permissions for a given file or directory. ex: $ permissions ~
	if [ -z "${1}" ]; then
		echo "ERROR: No file or directory specified";
		return 1;
	fi;

    if [[ $(uname) == "Darwin" ]]; then
        stat -f "%Sp %OLp %N" $1
    else
        stat -c '%A %a %n' $1
    fi;
}

