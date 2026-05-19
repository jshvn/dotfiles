#!/bin/zsh

# =============================================================================
# os/defaults/screenshots.zsh -- Screen capture defaults
#                                (gated on features.macos-screenshots)
#
# Purpose:      Declare the com.apple.screencapture keys this fleet wants;
#               apply_screenshots / verify_screenshots consume a single
#               tuple-array source of truth.
# Depends on:   install/messages.zsh; os/defaults/_apply_verify.zsh;
#               $DOTFILEDIR exported by caller.
# Side effects: apply_screenshots ensures $HOME/Pictures/Screenshots exists
#               BEFORE writing the `location` key (macOS silently falls back
#               to ~/Desktop otherwise), then `defaults write` + `killall
#               SystemUIServer` (guarded with `|| true`). Read-only verify.
# =============================================================================

set -euo pipefail

: "${DOTFILEDIR:?DOTFILEDIR not set -- run via 'task macos:*' or export it manually}"
source "${DOTFILEDIR}/install/messages.zsh"

# _apply_defaults / _verify_defaults expand the literal $HOME token in tuple
# values via narrow substitution (`${value/\$HOME/$HOME}`); the (e)-flag was
# rejected because it performs command substitution and would be a code-exec
# sink if a future concern starts sourcing tuple values from external data.
source "${DOTFILEDIR}/os/defaults/_apply_verify.zsh"

# Tuple stride 4: (domain, key, expected_value, write_type).
# The `location` value embeds the literal $HOME token -- do NOT pre-expand
# in the array; keeping it literal makes the file re-expandable when read
# by a different $HOME (CI fixtures).
typeset -ga SCREENSHOTS_DEFAULTS=(
  "com.apple.screencapture"  "location"        "\$HOME/Pictures/Screenshots"  "string"
  "com.apple.screencapture"  "type"            "png"                          "string"
  "com.apple.screencapture"  "disable-shadow"  "true"                         "bool"
)

apply_screenshots() {
  # Ensure the screenshots directory exists BEFORE the location key is
  # written; macOS silently falls back to ~/Desktop otherwise.
  mkdir -p "$HOME/Pictures/Screenshots"
  _apply_defaults SCREENSHOTS_DEFAULTS SystemUIServer
}

verify_screenshots() {
  _verify_defaults SCREENSHOTS_DEFAULTS screenshots
}
