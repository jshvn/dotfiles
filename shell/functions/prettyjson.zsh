#!/bin/zsh

# pretty print json
function prettyjson() {    # prettyjson() will print human readable json that has been colorized. ex: $ prettyjson file.json
	if [[ -z "${1}" ]]; then
		echo "ERROR: No file specified";
		return 1;
	fi
    if [[ ! -f "${1}" ]]; then
        echo "ERROR: file not found: ${1}" >&2
        return 1
    fi

    jq '.' "${1}" | highlight --syntax=json
}