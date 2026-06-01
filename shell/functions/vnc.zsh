#!/bin/zsh

# =============================================================================
# shell/functions/vnc.zsh -- launch macOS Screen Sharing against a host
#
# Purpose:      Open a `vnc://<host>` URL via macOS `open`; input is
#               validated against a permissive host/IP regex before
#               interpolation.
# Depends on:   open (macOS).
# Side effects: launches Screen Sharing or the default vnc:// handler.
# =============================================================================

function vnc() {    # vnc() opens macOS Screen Sharing to a host via vnc://. ex: $ vnc 10.0.0.5
    if [[ -z "${1}" ]]; then
        echo "ERROR: No domain specified.";
        return 1;
    fi
    if [[ ! "${1}" =~ ^[A-Za-z0-9.:_-]+$ ]]; then
        echo "ERROR: invalid host/ip: ${1}" >&2
        return 2
    fi
    open "vnc://${1}"
}