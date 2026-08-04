#!/bin/zsh

# =============================================================================
# shell/functions/whois.zsh -- registration lookup: RDAP first, WHOIS fallback
#
# Purpose:      Resolve a domain, IP, or URL to its full registration record.
#               RDAP answers first because that is where gTLD registration
#               data now lives; port-43 WHOIS covers the TLDs publishing no
#               RDAP service.
# Depends on:   rdap, whois (keg-only, hence the explicit opt path), grc
#               (grcat), gtimeout, psl (libpsl), $HOMEBREW_PREFIX,
#               _dotfiles_url_host.
# Side effects: outbound RDAP (HTTPS) and WHOIS (TCP/43) queries; rdap caches
#               the IANA bootstrap registry under $XDG_CACHE_HOME/openrdap;
#               stdout only.
# =============================================================================

# ICANN's Registration Data Policy retired the gTLD WHOIS requirement on
# 2025-01-28, and registries have been dropping port 43 since. One that has
# leaves an empty `whois:` field in its IANA record, so whois(1) has no
# referral to follow and answers with the IANA record for the TLD -- a
# description of ".app", not of the domain asked about, returned with a zero
# exit status. Asking RDAP first sidesteps that failure mode rather than
# trying to detect it in the response after the fact.
# See https://www.icann.org/rdap and RFC 9224 (bootstrap).
function whois() {    # whois() looks up a domain, IP, or URL over RDAP, falling back to WHOIS (5s timeout). ex: $ whois example.com
    if [[ -z "${1}" ]]; then
        echo "ERROR: No domain, IP, or URL specified" >&2
        return 1
    fi

    local timeout_seconds=5

    # Reduce a URL to its host (scheme / userinfo / path / query / fragment /
    # port removed); a bare domain or IP passes through untouched.
    local target="$(_dotfiles_url_host "$1")"

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
    # it reaches either client. Validated here, not on $1, so URL input is
    # still accepted and reduced above.
    if [[ ! "$target" =~ ^[A-Za-z0-9.:_-]+$ ]]; then
        echo "ERROR: invalid whois target: ${target}" >&2
        return 2
    fi

    # RDAP, tried first. `rdap` bootstraps the TLD -> service mapping off IANA
    # (RFC 9224), follows the registry -> registrar referral, and prints the
    # whole object: data on stdout, "# Error: ..." on stderr, non-zero exit on
    # any failure. Both streams are captured because the 404 case below is
    # read out of the error text.
    local response="" exit_code=1
    if command -v rdap >/dev/null 2>&1; then
        response=$(gtimeout "$timeout_seconds" rdap -T "$timeout_seconds" "$target" 2>&1)
        exit_code=$?

        # A 404 comes from the TLD's own RDAP service, so it is authoritative:
        # the domain is unregistered. Reported as such instead of falling
        # through to WHOIS, which for a no-port-43 gTLD answers a DNS
        # resolution error for a whois host that was never delegated.
        if (( exit_code != 0 )) && [[ "$response" == *404* ]]; then
            response="No match for \"${target}\""
            exit_code=0
        fi
    else
        echo "whois: rdap not installed; querying WHOIS only -- run 'task install'" >&2
    fi

    # WHOIS fallback: no RDAP service for this TLD (most ccTLDs, e.g. .de),
    # or the RDAP query failed or timed out.
    if (( exit_code != 0 )); then
        # The brew formula is keg-only, so it is absent from PATH and a plain
        # lookup would find the older BSD whois in /usr/bin. Named through
        # opt/ to get the rfc1036 client, whose server table covers the
        # ccTLDs that answer nothing else; `whence -p` (path-only, so the
        # function cannot recurse into itself) is the pre-`task install`
        # fallback.
        local whois_bin="${HOMEBREW_PREFIX}/opt/whois/bin/whois"
        [[ -x "$whois_bin" ]] || whois_bin="$(whence -p whois)"
        if [[ -z "$whois_bin" ]]; then
            echo "ERROR: '${target}' has no RDAP service and no whois client is installed -- run 'task install'" >&2
            return 1
        fi

        response=$(gtimeout "$timeout_seconds" "$whois_bin" "$target" 2>&1)
        exit_code=$?

        if (( exit_code == 124 )); then
            echo "$(tput setaf 1)ERROR: WHOIS lookup timed out after ${timeout_seconds}s for '$target'$(tput sgr0)" >&2
            return 1
        fi
    fi

    # Single colouring point, so an RDAP answer and a WHOIS one look alike:
    # both are "Key: value" lines, which is the shape conf.whois reads. Its
    # field pattern tolerates leading whitespace, so RDAP's indented nesting
    # colours the same as WHOIS's flat records. grcat applies the ruleset grc
    # would; tty only.
    if [[ -t 1 ]]; then
        print -r -- "$response" | grcat conf.whois
    else
        print -r -- "$response"
    fi

    return $exit_code
}
