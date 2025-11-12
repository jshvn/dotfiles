#!/bin/zsh

# copy primary public key to clipboard
function pubkey() {    # pubkey() will copy a public key to the clipboard. ex: $ pubkey id_rsa_adobe.pub
    if [ -z "${1}" ]; then
        echo "ERROR: No key specified. The possible keys are:";
        local keylist=$(ls ~/.ssh/*.pub);
        echo $keylist | highlight --syntax=bash
        return 1;
    fi;
    more ~/.ssh/$1 | pbcopy | echo '=> Public key copied to clipboard.'
}