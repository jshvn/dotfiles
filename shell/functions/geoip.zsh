#!/bin/zsh

# =============================================================================
# shell/functions/geoip.zsh -- ip.guide geolocation lookup
#
# Purpose:      Print geolocation data for the given IPv4 / hostname via
#               ip.guide; a URL is reduced to its host first, then validated
#               against a permissive host/IP regex before interpolation.
# Depends on:   curl, jq, highlight, _dotfiles_url_host.
# Side effects: HTTPS GET to ip.guide; stdout only.
# =============================================================================

function geoip() {    # geoip() prints geolocation data for an IP or host. ex: $ geoip 1.1.1.1
    if [[ -z "${1}" ]]; then
		echo "ERROR: No IP or host specified";
		return 1;
	fi
    # Reduce a URL to its host; a bare hostname or IP passes through untouched.
    # Validated after parsing, not on $1, so URL input is still accepted.
    local target="$(_dotfiles_url_host "${1}")"
    if [[ ! "$target" =~ ^[A-Za-z0-9.:_-]+$ ]]; then
        echo "ERROR: invalid host/ip: ${target}" >&2
        return 2
    fi

    curl -sL --request GET --url "https://ip.guide/${target}" \
        --header 'accept: application/json' \
        --header 'content-type: application/json' \
        | jq '.' | highlight --syntax=json
}