#!/bin/zsh

# =============================================================================
# os/defaults/animations.zsh -- AppKit animation defaults
#                               (gated on features.macos-animations)
#
# Purpose:      Shorten the AppKit-level animations every app inherits from
#               NSGlobalDomain: window open/close, window resize/zoom, and
#               the Quick Look panel. Each key below is one macOS 27 still
#               reads (present in the AppKit / QuickLook string tables).
#
#               What this concern deliberately does NOT cover, measured on
#               macOS 27.0 (2026-09-22): the Spaces slide (~1.2 s) and the
#               Mission Control enter/exit (~0.4 s). The Dock renders the
#               slide itself and exposes no duration key; the legacy Dock
#               keys (expose-animation-duration, springboard-*-duration,
#               workspaces-swoosh-animation-off) no longer exist in any 27
#               binary, and com.apple.WindowManager AnimationSpeed,
#               ExposeSpringResponse / ExposeSpringDampingRatio and
#               com.apple.dock mission-control-transition all measure
#               identical to stock. See docs/DECISIONS.md.
# Depends on:   install/messages.zsh; os/defaults/_apply_verify.zsh;
#               $DOTFILEDIR exported by caller.
# Side effects: apply_animations runs `defaults write` per tuple. Apps read
#               NSGlobalDomain at launch, so running apps keep the old
#               timing until relaunched; no UI process to restart.
#               verify_animations is read-only.
# =============================================================================

set -euo pipefail

: "${DOTFILEDIR:?DOTFILEDIR not set -- run via 'task macos:*' or export it manually}"
source "${DOTFILEDIR}/install/messages.zsh"

source "${DOTFILEDIR}/os/defaults/_apply_verify.zsh"

# Tuple stride 4: (domain, key, expected_value, write_type).
# NSWindowResizeTime cannot be 0 (AppKit treats it as unset); 0.001 is the
# conventional floor.
typeset -ga ANIMATIONS_DEFAULTS=(
  "NSGlobalDomain"  "NSAutomaticWindowAnimationsEnabled"  "false"  "bool"
  "NSGlobalDomain"  "NSWindowResizeTime"                  "0.001"  "float"
  "NSGlobalDomain"  "QLPanelAnimationDuration"            "0"      "float"
)

apply_animations() {
  _apply_defaults ANIMATIONS_DEFAULTS
}

verify_animations() {
  _verify_defaults ANIMATIONS_DEFAULTS animations
}
