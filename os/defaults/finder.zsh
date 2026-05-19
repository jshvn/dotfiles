#!/bin/zsh

# =============================================================================
# os/defaults/finder.zsh -- Finder defaults (gated on features.macos-finder)
#
# Purpose:      Declare the Finder keys this fleet wants; provide
#               apply_finder / verify_finder entry points consuming a
#               single tuple-array source of truth.
# Depends on:   install/messages.zsh; os/defaults/_apply_verify.zsh;
#               $DOTFILEDIR exported by caller.
# Side effects: apply_finder runs `defaults write` per tuple then `killall
#               Finder` (guarded with `|| true`); verify_finder is
#               unprivileged read-only. features.macos-finder also gates
#               shell/aliases/finder.zsh -- same flag, two consumers.
# =============================================================================

set -euo pipefail

: "${DOTFILEDIR:?DOTFILEDIR not set -- run via 'task macos:*' or export it manually}"
source "${DOTFILEDIR}/install/messages.zsh"

source "${DOTFILEDIR}/os/defaults/_apply_verify.zsh"

# Tuple stride 4: (domain, key, expected_value, write_type).
typeset -ga FINDER_DEFAULTS=(
  "NSGlobalDomain"    "AppleShowAllExtensions"          "true"  "bool"
  "com.apple.finder"  "FXEnableExtensionChangeWarning"  "false" "bool"
  "com.apple.finder"  "FXPreferredViewStyle"            "clmv"  "string"
)

apply_finder() {
  _apply_defaults FINDER_DEFAULTS Finder
}

verify_finder() {
  _verify_defaults FINDER_DEFAULTS finder
}
