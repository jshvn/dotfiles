#!/bin/zsh

# open vnc connection
function vnc() {    # vnc() will open a VNC connection to a given host. ex: vnc copper.jgrid.net
    if [ -z "${1}" ]; then
		echo "ERROR: No domain specified.";
		return 1;
	fi;
    open vnc://$1
}

# copy primary public key to clipboard
function pubkey() {    # pubkey() will copy a public key to the clipboard. ex: pubkey id_rsa_work.pub
    if [ -z "${1}" ]; then
		echo "ERROR: No key specified. The possible keys are:";
		local keylist=$(ls $DOTFILEDIR/ssh/.ssh/*.pub);
		echo $keylist;
		return 1;
	fi;
	more $DOTFILEDIR/ssh/.ssh/$1 | pbcopy | echo '=> Public key copied to clipboard.'
}