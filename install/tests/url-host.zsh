#!/usr/bin/env zsh

# =============================================================================
# install/tests/url-host.zsh -- smoke tests for _dotfiles_url_host()
#
# Purpose:      Assert the URL-to-host reduction shared by host() and whois()
#               handles scheme, userinfo, path/query/fragment, ports, IPv6
#               literals and already-bare hosts.
# Depends on:   DOTFILEDIR env var (exported by taskfiles/test.yml);
#               install/messages.zsh;
#               shell/functions/helpers/_dotfiles_url_host.zsh.
# Side effects: none; no network access.
# =============================================================================

set -euo pipefail

: "${DOTFILEDIR:?DOTFILEDIR must be set (run via task test:url-host)}"

# shellcheck source=install/messages.zsh
source "${DOTFILEDIR}/install/messages.zsh"
source "${DOTFILEDIR}/shell/functions/helpers/_dotfiles_url_host.zsh"

failed=0

# input -> expected host
typeset -a cases=(
    'https://persistiq.io/|persistiq.io'
    'http://www.bbc.co.uk/news?q=1#frag|www.bbc.co.uk'
    'https://example.com:8443/a/b|example.com'
    'ftp://usr:pw@files.example.com/pub|files.example.com'
    'example.com|example.com'
    'example.com:43|example.com'
    '1.2.3.4|1.2.3.4'
    '2001:db8::1|2001:db8::1'
    'https://[2001:db8::1]:53/|2001:db8::1'
)

for case in "${cases[@]}"; do
    input="${case%%|*}"
    expected="${case##*|}"
    actual=$(_dotfiles_url_host "$input")
    if [[ "$actual" == "$expected" ]]; then
        check "url-host: ${input} -> ${actual}"
    else
        cross "url-host: ${input} -> ${actual} (expected ${expected})"
        failed=$(( failed + 1 ))
    fi
done

if (( failed > 0 )); then
    error "url-host smoke tests: ${failed} failure(s)"
    exit 1
fi

success "url-host smoke tests passed"
