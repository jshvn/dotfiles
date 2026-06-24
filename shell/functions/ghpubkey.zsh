#!/bin/zsh

# =============================================================================
# shell/functions/ghpubkey.zsh -- fetch a GitHub user's public SSH keys
#
# Purpose:      Print the SSH public keys associated with a GitHub username
#               (via the public github.com/<user>.keys endpoint).
# Depends on:   curl, highlight.
# Side effects: HTTPS GET to github.com; stdout only.
# =============================================================================

function ghpubkey() {    # ghpubkey() fetches a GitHub user's public SSH keys. ex: $ ghpubkey jshvn
    if [[ -z "${1}" ]]; then
		echo "ERROR: No GitHub username specified" >&2
		return 1;
	fi
    # GitHub usernames/orgs are alphanumeric with single hyphens. Validate
    # before URL interpolation so e.g. `ghpubkey ../foo` cannot traverse the
    # path or break out of the URL.
    if [[ ! "${1}" =~ ^[A-Za-z0-9][A-Za-z0-9-]*$ ]]; then
        echo "ERROR: invalid GitHub username: ${1}" >&2
        return 2
    fi

    local response=$(curl -sL --request GET --url "https://github.com/${1}.keys")
    echo "$response" | highlight --syntax=bash
}