#!/bin/zsh

# flush dns cache
alias dnsflush="sudo killall -HUP mDNSResponder; sudo killall mDNSResponderHelper; sudo dscacheutil -flushcache"

# replace traceroute with trip
# Lazy expansion (single quotes) + presence guard: when trip is absent,
# the alias is not defined and the system `traceroute` falls through.
# Eager `$(command -v trip)` expansion at source time was masking the
# system `traceroute` entirely when trip was uninstalled (Plan 13-02
# REVIEW.md row 13).
if command -v trip >/dev/null 2>&1; then
    alias traceroute='trip -u'
fi

# use ipv4lookup and ipv6lookup functions to get IPs
alias ip="ipv4; ipv6;"
alias ipv4="ipv4lookup | highlight --syntax=bash"
alias ipv6="ipv6lookup | highlight --syntax=bash"