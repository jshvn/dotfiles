#!/bin/zsh

# flush dns cache
alias dnsflush="sudo killall -HUP mDNSResponder; sudo killall mDNSResponderHelper; sudo dscacheutil -flushcache"

# get current IP information. show all: $ ips
local activeinterfaces=$(ifconfig | awk '/^[^[:space:]]+:/ { iface=$1; sub(/:$/,"",iface) } /status: active/ { print iface }' | tr '\n' ' ')
local getiploc=$(ipconfig getifaddr en0)

# replace traceroute with trip
alias traceroute="$(which trip) -u"

alias iploc="echo Local IP: $getiploc"
alias interfaces="echo Active Interfaces: $activeinterfaces"

# use ipv4lookup and ipv6lookup functions to get IPs
alias ip="ipv4lookup; ipv6lookup;"
alias ipv4="ipv4lookup"
alias ipv6="ipv6lookup"