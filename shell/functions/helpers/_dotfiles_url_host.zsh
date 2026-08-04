#!/bin/zsh

# =============================================================================
# shell/functions/helpers/_dotfiles_url_host.zsh -- URL/host string to bare hostname
#
# Purpose:      Reduce a URL-ish argument to the host component -- strip
#               scheme, userinfo, path, query, fragment and port -- so
#               network lookups accept a pasted URL as readily as a bare
#               hostname. Subdomains are preserved; callers that need the
#               registrable domain reduce further themselves.
# Depends on:   nothing (zsh parameter expansion only).
# Side effects: none; prints the host to stdout.
# =============================================================================

function _dotfiles_url_host() {    # _dotfiles_url_host() prints the host part of a URL or host string. ex: $ _dotfiles_url_host https://persistiq.io/
    local target="${1#*://}"        # scheme
    target="${target%%[/?#]*}"      # path, query string, fragment
    target="${target#*@}"           # userinfo (user:pass@host)

    if [[ "$target" == \[*\]* ]]; then
        # Bracketed IPv6 literal ([::1]:53) -- take what is inside the
        # brackets, which drops any port along with them.
        target="${${target#\[}%%\]*}"
    elif [[ "$target" == *:<-> && "${target//[^:]}" == ":" ]]; then
        # host:port -- only when a single colon precedes digits, so a bare
        # IPv6 address (many colons) survives intact.
        target="${target%:*}"
    fi

    print -r -- "$target"
}
