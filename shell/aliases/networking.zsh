#!/bin/zsh

# =============================================================================
# shell/aliases/networking.zsh -- networking shortcuts
#
# Purpose:      DNS cache flush, optional `trip` replacement for traceroute,
#               combined IPv4 + IPv6 lookup helpers (highlight-piped).
# Depends on:   trip (optional), mDNSResponder, dscacheutil, highlight,
#               shell/functions/ipv4lookup.zsh, ipv6lookup.zsh.
# Side effects: defines aliases dnsflush, traceroute (when trip present),
#               ip, ipv4, ipv6.
# =============================================================================

alias dnsflush="sudo killall -HUP mDNSResponder; sudo killall mDNSResponderHelper; sudo dscacheutil -flushcache"

# Lazy expansion (single quotes) + presence guard: when trip is absent,
# the alias is not defined and the system `traceroute` falls through.
# Eager `$(command -v trip)` expansion at source time was masking the
# system `traceroute` entirely when trip was uninstalled (Plan 13-02
# REVIEW.md row 13).
if command -v trip >/dev/null 2>&1; then
    alias traceroute='trip -u'
fi

alias ip="ipv4; ipv6;"
alias ipv4="ipv4lookup | highlight --syntax=bash"
alias ipv6="ipv6lookup | highlight --syntax=bash"
