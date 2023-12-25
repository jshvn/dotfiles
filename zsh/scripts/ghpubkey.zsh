#!/bin/zsh

# GitHub public key lookup utility
function ghpubkey() {    # ghpubkey() will print public key information for a given GitHub username. ex: $ ghpubkey jshvn
    if [ -z "${1}" ]; then
		echo "ERROR: No GitHub username specified";
		return 1;
	fi;

    local response=$(curl -sL --request GET --url github.com/$1.keys)
    echo $response | highlight --syntax=bash
}