#!/bin/zsh

# =============================================================================
# shell/functions/ghpubkey.zsh -- fetch a GitHub user's public SSH keys
#
# Purpose:      Print the SSH public keys associated with a GitHub username
#               (via the public github.com/<user>.keys endpoint).
# Depends on:   curl, highlight.
# Side effects: HTTPS GET to github.com; stdout only.
# =============================================================================

function ghpubkey() {
    if [[ -z "${1}" ]]; then
		echo "ERROR: No GitHub username specified";
		return 1;
	fi

    local response=$(curl -sL --request GET --url "https://github.com/${1}.keys")
    echo "$response" | highlight --syntax=bash
}