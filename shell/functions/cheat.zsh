#!/bin/zsh

# =============================================================================
# shell/functions/cheat.zsh -- cheat.sh man-page-style query helper
#
# Purpose:      Print the cheat.sh entry for the given command, or the top-
#               level cheat.sh help when invoked with no argument.
# Depends on:   curl.
# Side effects: HTTPS GET to cheat.sh; stdout only.
# =============================================================================

function cheat() {
	if [[ -z "${1}" ]]; then
		echo "ERROR: No command specified. Printing help instead.";
        local result=$(curl "https://cheat.sh" -s)
        echo "$result"
		return 1;
	fi
    
    local result=$(curl "https://cheat.sh/${1}?style=xcode" -s)
    echo "$result"
}