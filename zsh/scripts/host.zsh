#!/bin/zsh

# Host info look up utility
function host() {    # host() will print information related to a given name or IP. ex: $ host sniffies.com
    if [ -z "${1}" ]; then
		echo "ERROR: No host or IP specified";
		return 1;
	fi;

    local records=$(doggo --type=A --type=AAAA --type=MX --type=TXT --type=NS --type=CNAME --nameserver=1.1.1.1 $1) 
    echo "$records" | highlight --syntax=bash
}