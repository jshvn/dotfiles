#!/bin/zsh
# shell/aliases/jgrid.zsh -- jgrid.net allomantic-metals ssh-jump aliases.
#
# Purpose: define 22 ssh-jump aliases (one per allomantic metal) that
# connect to <metal>-ssh.jgrid.net via the local Cloudflared daemon.
# Gated on features.jgrid-net via the source-time gate per D-08 (the
# bulk-alias-loop exception).
#
# Why source-time gate (D-08) rather than wrapper-function (D-07): 22
# aliases in a tight loop. A wrapper-function per alias would multiply
# the gate evaluation 22x and balloon the file. The source-time gate
# pays one _dotfiles_feature call (one jq invocation on first lookup,
# cached thereafter) only when the feature is enabled, then defines all
# 22 aliases at once. The early-exit from a sourced file is legal zsh
# and unwinds back to the .zshrc glob loop without printing an error.

[[ "$(_dotfiles_feature jgrid-net)" == "true" ]] || return 0

# This script will insert each of the allomantic metals into
# our current environment as ssh jump commands to each host
# using the local Cloudflared daemon.

METALS=(
    # standard metals
    "steel"
    "iron"
    "zinc"
    "brass"
    "pewter"
    "tin"
    "copper"
    "bronze"
    "duralumin"
    "aluminum"
    "gold"
    "electrum"
    "nicrosil"
    "chromium"
    "cadmium"
    "bendalloy"
    # God metals
    "atium"
    "malatium"
    "lerasium"
    "harmonium"
    "trellium"
    "raysium"
)

for i in $METALS
do
    alias $i="ssh josh@$i-ssh.jgrid.net"
done

unset METALS
