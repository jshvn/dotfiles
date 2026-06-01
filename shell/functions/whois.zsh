#!/bin/zsh

# =============================================================================
# shell/functions/whois.zsh -- whois wrapper with URL parsing + timeout
#
# Purpose:      Strip scheme / path / port / subdomains down to a registrable
#               domain (or pass an IP straight through), then run whois via
#               grc with a 5s gtimeout.
# Depends on:   whois, grc, gtimeout, awk.
# Side effects: outbound WHOIS query; stdout only.
# =============================================================================

function whois() {    # whois() runs whois on a domain, IP, or URL (5s timeout). ex: $ whois example.com
    if [[ -z "${1}" ]]; then
        echo "ERROR: No domain, IP, or URL specified";
        return 1;
    fi

    local input="$1"
    local target
    local timeout_seconds=5

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

    # Run whois through grc for colored output, with timeout to avoid slow WHOIS servers
    gtimeout "$timeout_seconds" grc --colour=auto $(whence -p whois) "$target"
    local exit_code=$?

    if [[ $exit_code -eq 124 ]]; then
        echo "$(tput setaf 1)ERROR: WHOIS lookup timed out after ${timeout_seconds}s for '$target'$(tput sgr0)" >&2
        return 1
    fi

    return $exit_code
}
