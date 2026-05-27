#!/bin/zsh

# =============================================================================
# shell/functions/prettyjson.zsh -- pretty-print and syntax-highlight JSON
#
# Purpose:      Pipe a JSON file through jq for indentation, then highlight
#               for color.
# Depends on:   jq, highlight.
# Side effects: stdout only.
# =============================================================================

function prettyjson() {
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