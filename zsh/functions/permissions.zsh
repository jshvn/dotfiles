#!/bin/zsh

# Prints permissions of file
function permissions() {    # permissions() will print human readable permissions for a given file or directory. ex: $ permissions ~
	if [ -z "${1}" ]; then
		echo "ERROR: No file or directory specified";
		return 1;
	fi;

    if [[ $(uname) == "Darwin" ]]; then
        stat -f "%Sp %OLp %N" "${1}" | highlight --syntax=bash
    else
        stat -c '%A %a %n' "${1}" | highlight --syntax=bash
    fi;
}