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

    # Capture before rendering: on an error status curl returns an empty body,
    # which jq passes through silently -- a blank line and exit 0 reads as
    # "no data" when it means "lookup failed". ip.guide answers 404 both for a
    # host with no A/AAAA record and for one it has no data on, so the message
    # names the likely cause without claiming to know which.
    # `curl_status`, not `status` -- the latter is a read-only zsh builtin
    # parameter (an alias for $?) and assigning to it aborts the function.
    local response curl_status=0
    response=$(curl -sL --fail --max-time 5 --request GET --url "https://ip.guide/${target}" \
        --header 'accept: application/json' \
        --header 'content-type: application/json') || curl_status=$?

    if (( curl_status != 0 )); then
        echo "ERROR: ip.guide lookup failed for '${target}' (curl exit ${curl_status}) -- unknown to ip.guide, or the host does not resolve" >&2
        return 1
    fi

    echo "$response" | jq '.' | highlight --syntax=json
}