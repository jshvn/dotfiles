#!/bin/zsh

# =============================================================================
# shell/functions/host.zsh -- DNS record lookup via doggo (1.1.1.1)
#
# Purpose:      Print A, AAAA, MX, TXT, NS, CNAME records for a hostname,
#               using Cloudflare DNS (1.1.1.1).
# Depends on:   doggo, highlight.
# Side effects: DNS query against 1.1.1.1; stdout only.
# =============================================================================

function host() {    # host() looks up A/AAAA/MX/TXT/NS/CNAME records via 1.1.1.1. ex: $ host example.com
    if [[ -z "${1}" ]]; then
		echo "ERROR: No host or IP specified" >&2
		return 1;
	fi
    # Permissive host/IP guard (matches geoip/vnc) before passing to doggo.
    if [[ ! "${1}" =~ ^[A-Za-z0-9.:_-]+$ ]]; then
        echo "ERROR: invalid host/ip: ${1}" >&2
        return 2
    fi

    local records=$(doggo --type=A --type=AAAA --type=MX --type=TXT --type=NS --type=CNAME --nameserver=1.1.1.1 "${1}")
    echo "$records" | highlight --syntax=bash
}