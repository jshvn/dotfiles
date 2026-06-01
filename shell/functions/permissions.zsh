#!/bin/zsh

# =============================================================================
# shell/functions/permissions.zsh -- human-readable file mode printer
#
# Purpose:      Print mode + octal + path for a file or directory; uses
#               BSD `stat -f` on macOS, GNU `stat -c` on Linux.
# Depends on:   stat, highlight.
# Side effects: stdout only.
# =============================================================================

function permissions() {    # permissions() prints mode + octal + path for a file or dir. ex: $ permissions ~/.ssh
	if [[ -z "${1}" ]]; then
		echo "ERROR: No file or directory specified";
		return 1;
	fi

    if [[ $(uname) == "Darwin" ]]; then
        stat -f "%Sp %OLp %N" "${1}" | highlight --syntax=bash
    else
        stat -c '%A %a %n' "${1}" | highlight --syntax=bash
    fi
}