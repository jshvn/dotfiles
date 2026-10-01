#!/bin/zsh

# =============================================================================
# os/defaults/dock.zsh -- Desktop & Dock defaults (gated on features.macos-dock)
#
# Purpose:      Declare the Desktop & Dock keys this fleet wants -- the Dock
#               itself, the Spaces edge switch, and window tiling (which lives
#               in com.apple.WindowManager); provide apply_dock / verify_dock
#               entry points consuming a single tuple-array source of truth.
# Depends on:   install/messages.zsh; os/defaults/_apply_verify.zsh;
#               $DOTFILEDIR exported by caller (taskfiles/macos.yml heredoc).
# Side effects: apply_dock runs `defaults write` per tuple then `killall Dock`
#               (guarded with `|| true` so a missing Dock process is not an
#               error); WindowManager reads its keys live, so it needs no
#               restart. verify_dock is unprivileged read-only.
# =============================================================================

set -euo pipefail

# messages.zsh self-guards under set -u via the `:-` default expansion on
# $DOTFILES_MESSAGES_LOADED; a bare source is sufficient and idempotent.
: "${DOTFILEDIR:?DOTFILEDIR not set -- run via 'task macos:*' or export it manually}"
source "${DOTFILEDIR}/install/messages.zsh"

# Shared apply / verify helpers.
source "${DOTFILEDIR}/os/defaults/_apply_verify.zsh"

# Tuple stride 4: (domain, key, expected_value, write_type).
# write_type is one of: bool int string float.
typeset -ga DOCK_DEFAULTS=(
  "com.apple.dock"  "orientation"   "bottom"  "string"
  "com.apple.dock"  "tilesize"      "45"      "int"
  "com.apple.dock"  "autohide"      "true"    "bool"
  "com.apple.dock"  "mineffect"     "genie"   "string"
  "com.apple.dock"  "show-recents"  "false"   "bool"
  "com.apple.dock"  "mru-spaces"    "false"   "bool"
  # Hot corners: disable bottom-right (1 = no action). modifier 0 = no key held.
  "com.apple.dock"  "wvous-br-corner"   "1"  "int"
  "com.apple.dock"  "wvous-br-modifier" "0"  "int"
  # Dock reveal: no hover delay, 0.15 s slide (macOS default is 0.5 s).
  "com.apple.dock"  "autohide-delay"          "0"     "float"
  "com.apple.dock"  "autohide-time-modifier"  "0.15"  "float"
  # Spaces edge switch: a window held against a screen edge no longer jumps
  # to the next desktop (stock delay 0.75 s), so the tiling outline below
  # can be held as long as needed. The Dock reads this at launch.
  "com.apple.dock"  "workspaces-edge-delay"  "1000"  "float"
  # Window tiling (Desktop & Dock > Windows): drag to a side edge for a
  # half, to the menu bar to fill the screen; hold Option while dragging
  # to skip the edge hold.
  "com.apple.WindowManager"  "EnableTilingByEdgeDrag"     "true"  "bool"
  "com.apple.WindowManager"  "EnableTopTilingByEdgeDrag"  "true"  "bool"
)

apply_dock() {
  _apply_defaults DOCK_DEFAULTS Dock
}

verify_dock() {
  _verify_defaults DOCK_DEFAULTS dock
}
