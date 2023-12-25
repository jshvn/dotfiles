#!/bin/zsh

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
    alias $i="ssh josh@ssh.$i.jgrid.net"
done
