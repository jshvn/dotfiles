#!/bin/zsh

# =============================================================================
# shell/functions/host.zsh -- DNS record lookup via doggo (1.1.1.1)
#
# Purpose:      Print A, AAAA, MX, TXT, NS, CNAME records for a hostname,
#               using Cloudflare DNS (1.1.1.1). Accepts a URL as readily as
#               a bare hostname.
# Depends on:   doggo, highlight, _dotfiles_url_host.
# Side effects: DNS query against 1.1.1.1; stdout only.
# =============================================================================

function host() {    # host() looks up A/AAAA/MX/TXT/NS/CNAME records via 1.1.1.1. ex: $ host example.com
    if [[ -z "${1}" ]]; then
		echo "ERROR: No host or IP specified" >&2
		return 1;
	fi

    # Reduce a URL to its host (scheme / userinfo / path / query / fragment /
    # port removed); a bare hostname or IP passes through untouched. No
    # eTLD+1 reduction here -- DNS answers for www.bbc.co.uk and bbc.co.uk
    # differ, so the queried name must stay exactly as given.
    local target="$(_dotfiles_url_host "${1}")"

    # Permissive host/IP guard (matches geoip/vnc) before passing to doggo.
    # Applied to the parsed target, not $1, so URL input is still accepted.
    if [[ ! "$target" =~ ^[A-Za-z0-9.:_-]+$ ]]; then
        echo "ERROR: invalid host/ip: ${target}" >&2
        return 2
    fi

    local records=$(doggo --type=A --type=AAAA --type=MX --type=TXT --type=NS --type=CNAME --nameserver=1.1.1.1 "$target")
    echo "$records" | highlight --syntax=bash
}