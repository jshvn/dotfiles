#!/bin/zsh

# =============================================================================
# shell/functions/fs.zsh -- human-readable filesystem size helper
#
# Purpose:      Report size of one or more given paths, or current directory
#               when invoked with no arguments. Prefers GNU `du -sbh` when
#               available, falls back to `-sh`.
# Depends on:   du, find (Linux fallback), highlight.
# Side effects: stdout only.
# =============================================================================

function fs() {
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
        fi
	fi
}