#!/bin/zsh

# =============================================================================
# os/defaults/dock.zsh -- Dock defaults (gated on features.macos-dock)
#
# Purpose:      Declare the Dock keys this fleet wants; provide apply_dock /
#               verify_dock entry points consuming a single tuple-array
#               source of truth.
# Depends on:   install/messages.zsh; os/defaults/_apply_verify.zsh;
#               $DOTFILEDIR exported by caller (taskfiles/macos.yml heredoc).
# Side effects: apply_dock runs `defaults write` per tuple then `killall Dock`
#               (guarded with `|| true` for headless/pre-launch machines);
#               verify_dock is unprivileged read-only.
# =============================================================================

set -euo pipefail

# messages.zsh self-guards under set -u via the `:-` default expansion on
# $DOTFILES_MESSAGES_LOADED; a bare source is sufficient and idempotent.
: "${DOTFILEDIR:?DOTFILEDIR not set -- run via 'task macos:*' or export it manually}"
source "${DOTFILEDIR}/install/messages.zsh"

# Shared apply / verify helpers, extracted from the 5 near-identical
# per-concern loops.
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
)

apply_dock() {
  _apply_defaults DOCK_DEFAULTS Dock
}

verify_dock() {
  _verify_defaults DOCK_DEFAULTS dock
}
