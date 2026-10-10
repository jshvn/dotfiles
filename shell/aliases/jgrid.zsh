#!/bin/zsh

# =============================================================================
# shell/aliases/jgrid.zsh -- jgrid.net allomantic-metals ssh-jump aliases
#
# Purpose:      Define 22 ssh-jump aliases (one per allomantic metal) that
#               connect to <metal>-ssh.jgrid.net via the cloudflared
#               ProxyCommand in the active SSH identity. Linked into
#               aliases.d by the switch when dotfiles.shell.jgrid-net is
#               true; absent otherwise.
# Depends on:   the cloudflared ProxyCommand in the active SSH identity.
# Side effects: defines 22 aliases (steel, iron, ..., raysium).
# =============================================================================

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
