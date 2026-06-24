#!/bin/zsh

# =============================================================================
# shell/functions/cheat.zsh -- cheat.sh man-page-style query helper
#
# Purpose:      Print the cheat.sh entry for the given command, or the top-
#               level cheat.sh help when invoked with no argument.
# Depends on:   curl.
# Side effects: HTTPS GET to cheat.sh; stdout only.
# =============================================================================

function cheat() {    # cheat() prints the cheat.sh entry for a command. ex: $ cheat tar
	if [[ -z "${1}" ]]; then
		echo "No command specified. Printing top-level cheat.sh help." >&2
        curl "https://cheat.sh" -s
		return 0;
	fi
    # Validate before URL interpolation. cheat.sh paths allow letters, digits,
    # `/`, `+`, `.`, `_`, `-`; reject everything else (`?`, `&`, `#`, spaces,
    # quotes, `$`, backticks) so the argument cannot break out of the URL.
    if [[ ! "${1}" =~ ^[A-Za-z0-9._/+-]+$ ]]; then
        echo "ERROR: invalid cheat query: ${1}" >&2
        return 2
    fi

    curl "https://cheat.sh/${1}?style=xcode" -s
}