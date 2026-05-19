#!/bin/zsh

# =============================================================================
# shell/aliases/jgrid.zsh -- jgrid.net allomantic-metals ssh-jump aliases
#
# Purpose:      Define 22 ssh-jump aliases (one per allomantic metal) that
#               connect to <metal>-ssh.jgrid.net via the local Cloudflared
#               daemon. Gated on features.jgrid-net via source-time gate
#               (bulk-alias-loop pattern -- one feature query covers all 22).
# Depends on:   shell/functions/_dotfiles_feature.zsh (sourced earlier by
#               .zshrc's functions glob).
# Side effects: defines 22 aliases (steel, iron, ..., raysium) on
#               feature-on machines; no-op (returns 0) on feature-off.
# =============================================================================

[[ "$(_dotfiles_feature jgrid-net)" == "true" ]] || return 0

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
