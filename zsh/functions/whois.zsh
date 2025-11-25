#!/bin/zsh

# Whois lookup utility that handles URLs, domains, and IPs
function whois() {    # whois() wraps whois with URL parsing and colored output. ex: $ whois https://ijosh.com/
    if [ -z "${1}" ]; then
        echo "ERROR: No domain, IP, or URL specified";
        return 1;
    fi;

    local input="$1"
    local target

    # Strip protocol (http://, https://, etc.)
    target="${input#*://}"

    # Strip path, query string, and fragment
    target="${target%%/*}"
    target="${target%%\?*}"
    target="${target%%#*}"

    # Strip port if present
    target="${target%%:*}"

    # Extract top-level domain from subdomains (e.g., www.foo.example.com -> example.com)
    # Only do this for hostnames, not IP addresses
    if [[ ! "$target" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && [[ ! "$target" =~ : ]]; then
        # Count the dots to determine if we have subdomains
        local dot_count="${target//[^.]}"
        if [[ ${#dot_count} -ge 2 ]]; then
            # Extract last two parts (domain.tld) using awk
            target=$(echo "$target" | awk -F'.' '{print $(NF-1)"."$NF}')
        fi
    fi

    # Run whois through grc for colored output
    grc --colour=auto $(whence -p whois) "$target"
}
