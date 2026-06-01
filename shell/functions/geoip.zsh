#!/bin/zsh

# =============================================================================
# shell/functions/geoip.zsh -- ip.guide geolocation lookup
#
# Purpose:      Print geolocation data for the given IPv4 / hostname via
#               ip.guide; input is validated against a permissive host/IP
#               regex before interpolation.
# Depends on:   curl, jq, highlight.
# Side effects: HTTPS GET to ip.guide; stdout only.
# =============================================================================

function geoip() {    # geoip() prints geolocation data for an IP or host. ex: $ geoip 1.1.1.1
    if [[ -z "${1}" ]]; then
		echo "ERROR: No IP or host specified";
		return 1;
	fi
    if [[ ! "${1}" =~ ^[A-Za-z0-9.:_-]+$ ]]; then
        echo "ERROR: invalid host/ip: ${1}" >&2
        return 2
    fi

    curl -sL --request GET --url "https://ip.guide/${1}" \
        --header 'accept: application/json' \
        --header 'content-type: application/json' \
        | jq '.' | highlight --syntax=json
}