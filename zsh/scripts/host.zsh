#!/bin/zsh

# Host info look up utility
function host() {    # host() will print information related to a given name or IP. ex: $ host sniffies.com
    if [ -z "${1}" ]; then
		echo "ERROR: No host or IP specified";
		return 1;
	fi;

    local arecords=$(dig @1.1.1.1 +short $1. A)
    local aaaarecords=$(dig @1.1.1.1 +short $1. AAAA)
    local mxrecords=$(dig @1.1.1.1 +short $1. MX)
    local txtrecords=$(dig @1.1.1.1 +short $1. TXT)
    local nsrecords=$(dig @1.1.1.1 +short $1. NS)

    echo "A records:\n$arecords" | highlight --syntax=bash
    echo "AAAA records:\n$aaaarecords" | highlight --syntax=bash
    echo "MX records:\n$mxrecords" | highlight --syntax=bash
    echo "TXT records:\n$txtrecords" | highlight --syntax=bash
    echo "NS records:\n$nsrecords" | highlight --syntax=bash
}