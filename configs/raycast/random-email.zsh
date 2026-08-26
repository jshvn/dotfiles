#!/bin/zsh

# =============================================================================
# configs/raycast/random-email.zsh -- Raycast script command: random email
#
# Purpose:      Build `<prefix>.<8 random [a-z0-9]>@jgrid.net` from the prefix
#               typed in Raycast, copy it to the clipboard, and show it as a
#               HUD toast. Local /dev/urandom stands in for random.org. The
#               prefix is reduced to ASCII letters and digits, so a stray
#               trailing "." or any punctuation/unicode is dropped.
# Depends on:   /dev/urandom; tr; head; pbcopy; Raycast passing the prefix
#               as $1 (see @raycast.argument1 below).
# Side effects: Overwrites the clipboard.
# =============================================================================

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Random Email
# @raycast.mode silent

# Optional parameters:
# @raycast.packageName Utilities
# @raycast.argument1 { "type": "text", "placeholder": "prefix" }

set -euo pipefail

suffix=$(head -c 512 /dev/urandom | LC_ALL=C tr -dc 'a-z0-9')
suffix=${suffix[1,8]}
prefix=${1//[^A-Za-z0-9]/}
[[ -n $prefix ]] || { echo "prefix '$1' has no letters or digits" >&2; exit 1; }
email="$prefix.$suffix@jgrid.net"
printf '%s' "$email" | pbcopy
echo "Copied $email"
