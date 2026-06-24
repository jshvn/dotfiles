#!/bin/zsh

# =============================================================================
# shell/functions/whois.zsh -- whois wrapper with URL parsing + timeout
#
# Purpose:      Strip scheme / path / port / subdomains down to a registrable
#               domain (or pass an IP straight through), then run whois via
#               grc with a 5s gtimeout.
# Depends on:   whois, grc, gtimeout, psl (libpsl).
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

    # Reduce subdomains to the registrable domain -- the eTLD+1, e.g.
    # www.bbc.co.uk -> bbc.co.uk -- so the query hits the registry record.
    # This delegates to libpsl's `psl` tool, which embeds the full, current
    # Public Suffix List (the same library curl / wget / git use) and resolves
    # wildcard and exception rules a hand-maintained list cannot express.
    # libpsl is installed on every machine via the shared `dotfiles` brew
    # bundle specifically so this function can compute eTLD+1 correctly.
    #   PSL: https://publicsuffix.org/  --  libpsl: https://github.com/rockdaboot/libpsl
    # Skipped for IP addresses. If psl is absent, or returns no registrable
    # domain (e.g. a bare host like "localhost", reported as "(null)"), the
    # target is queried unchanged rather than guessed at.
    if [[ ! "$target" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && [[ ! "$target" =~ : ]]; then
        if command -v psl >/dev/null 2>&1; then
            # `psl --print-reg-domain <host>` prints "<host>: <regdomain>";
            # strip the "<host>: " prefix and ignore the "(null)" sentinel.
            local reg="$(psl --print-reg-domain "$target" 2>/dev/null)"
            reg="${reg##*: }"
            [[ -n "$reg" && "$reg" != "(null)" ]] && target="$reg"
        else
            echo "whois: libpsl not installed (provides 'psl'); querying '$target' without subdomain reduction -- run 'task install'" >&2
        fi
    fi

    # Guard the parsed target (a bare domain or IP after URL stripping) before
    # it reaches whois. Validated here, not on $1, so URL input is still
    # accepted and reduced above.
    if [[ ! "$target" =~ ^[A-Za-z0-9.:_-]+$ ]]; then
        echo "ERROR: invalid whois target: ${target}" >&2
        return 2
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
