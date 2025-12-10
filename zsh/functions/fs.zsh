#!/bin/zsh

# Determine size of a file or total size of a directory
function fs() {    # fs() will print a human readable size of given file or directory. ex: $ fs ~
	if du -b /dev/null > /dev/null 2>&1; then
		local arg=-sbh;
	else
		local arg=-sh;
	fi
    if (( $# > 0 )); then
		du $arg -- "$@";
	else
        if [[ $(uname) == "Darwin" ]]; then
            du $arg .[^.]* ./* | highlight --syntax=bash
        else
            find . -type f | du -ah -d1 | highlight --syntax=bash
        fi;
	fi;
}