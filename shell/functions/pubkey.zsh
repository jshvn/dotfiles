#!/bin/zsh

# copy primary public key to clipboard
function pubkey() {    # pubkey() will copy a public key to the clipboard. ex: $ pubkey id_ed25519_personal.pub
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