#!/bin/zsh

# open vnc connection
function vnc() {
    if [ -z "${1}" ]; then
		echo "ERROR: No domain specified.";
		return 1;
	fi;
    open vnc://$1
}
