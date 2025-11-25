#!/bin/zsh

# flush dns cache
alias dnsflush="sudo killall -HUP mDNSResponder; sudo killall mDNSResponderHelper; sudo dscacheutil -flushcache"

# replace traceroute with trip
alias traceroute="$(which trip) -u"

# use ipv4lookup and ipv6lookup functions to get IPs
alias ip="ipv4; ipv6;"
alias ipv4="ipv4lookup | highlight --syntax=bash"
alias ipv6="ipv6lookup | highlight --syntax=bash"