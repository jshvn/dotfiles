#!/bin/zsh

# =============================================================================
# os/defaults/input.zsh -- Keyboard / trackpad defaults
#                          (gated on features.macos-input)
#
# Purpose:      Declare the input keys this fleet wants; apply_input /
#               verify_input consume a single tuple-array source of truth.
# Depends on:   install/messages.zsh; os/defaults/_apply_verify.zsh;
#               $DOTFILEDIR exported by caller.
# Side effects: apply_input runs `defaults write` per tuple. Input-domain
#               keys take effect on next login / system reset (no canonical
#               UI process to restart). verify_input is read-only.
# =============================================================================

set -euo pipefail

: "${DOTFILEDIR:?DOTFILEDIR not set -- run via 'task macos:*' or export it manually}"
source "${DOTFILEDIR}/install/messages.zsh"

source "${DOTFILEDIR}/os/defaults/_apply_verify.zsh"

# Tuple stride 4: (domain, key, expected_value, write_type).
# Extension point: add KeyRepeat / InitialKeyRepeat / trackpad.scaling
# tuples when preferences emerge.
typeset -ga INPUT_DEFAULTS=(
  "NSGlobalDomain"  "com.apple.swipescrolldirection"  "false"  "bool"
)

apply_input() {
  _apply_defaults INPUT_DEFAULTS
}

verify_input() {
  _verify_defaults INPUT_DEFAULTS input
}
