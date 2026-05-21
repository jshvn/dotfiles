#!/bin/zsh

# =============================================================================
# os/defaults/appearance.zsh -- Appearance defaults
#                               (gated on features.macos-appearance)
#
# Purpose:      Pin system appearance to Dark and the Sequoia 15+ icon &
#               widget style to Dark/Always. Both keys live in
#               NSGlobalDomain and are read by every app at launch.
# Depends on:   install/messages.zsh; os/defaults/_apply_verify.zsh;
#               $DOTFILEDIR exported by caller.
# Side effects: `defaults write` for global APPEARANCE_DEFAULTS;
#               `osascript` to System Events to live-flip dark mode --
#               `defaults write -g AppleInterfaceStyle Dark` persists across
#               logins but does NOT broadcast a live appearance change to
#               running apps (whereas AppleIconAppearanceTheme does
#               broadcast on its own). The osascript hop is the documented
#               workaround; it is idempotent when already Dark. Aggregator-
#               level killall (apply-defaults:refresh-ui) handles the rest
#               of the relaunch.
# =============================================================================

set -euo pipefail

: "${DOTFILEDIR:?DOTFILEDIR not set -- run via 'task macos:*' or export it manually}"
source "${DOTFILEDIR}/install/messages.zsh"

source "${DOTFILEDIR}/os/defaults/_apply_verify.zsh"

# Tuple stride 4: (domain, key, expected_value, write_type).
# AppleIconAppearanceTheme value grammar: "<mode><tone>" where mode is
# "Regular" (Always) or "Auto" (follows system appearance), tone is one of
# Light, Dark, Clear, Tinted. "RegularDark" = Icon & widget style: Dark,
# Always (the screenshot's state).
typeset -ga APPEARANCE_DEFAULTS=(
  "NSGlobalDomain"  "AppleInterfaceStyle"        "Dark"         "string"
  "NSGlobalDomain"  "AppleIconAppearanceTheme"   "RegularDark"  "string"
)

apply_appearance() {
  _apply_defaults APPEARANCE_DEFAULTS
  # System Events live-flip. First invocation on a fresh machine prompts for
  # Automation permission (TCC) -- if denied, the defaults write above still
  # persists, so next login picks up Dark mode. We warn rather than fail.
  if ! osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true' >/dev/null 2>&1; then
    warn "Could not live-flip appearance via System Events (TCC permission?); next login will pick up AppleInterfaceStyle=Dark"
  fi
}

verify_appearance() {
  _verify_defaults APPEARANCE_DEFAULTS appearance
}
