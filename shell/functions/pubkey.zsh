#!/bin/zsh

# =============================================================================
# shell/functions/pubkey.zsh -- copy ~/.ssh/<key>.pub to the clipboard
#
# Purpose:      Copy the named public key from ~/.ssh/ to the macOS
#               clipboard; with no argument, list available *.pub files.
# Depends on:   pbcopy (macOS), highlight.
# Side effects: writes to the clipboard.
# =============================================================================

function pubkey() {    # pubkey() copies ~/.ssh/<key>.pub to the clipboard (no arg lists keys). ex: $ pubkey id_ed25519.pub
    if [[ -z "${1}" ]]; then
        echo "ERROR: No key specified. The possible keys are:";
        local keylist=$(print -l ~/.ssh/*.pub(N))
        echo "$keylist" | highlight --syntax=bash
        return 1;
    fi
    if [[ ! -f ~/.ssh/"${1}" ]]; then
        echo "ERROR: key file not found: ~/.ssh/${1}" >&2
        return 1
    fi
    pbcopy < ~/.ssh/"${1}"
    echo '=> Public key copied to clipboard.'
}