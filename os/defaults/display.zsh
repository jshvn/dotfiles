#!/bin/zsh

# =============================================================================
# os/defaults/display.zsh -- Display scaling defaults
#                            (gated on features.macos-display)
#
# Purpose:      Set the built-in (laptop) panel to its "More Space" scaling
#               preset -- the largest 2x HiDPI mode. Unlike the other concerns
#               this is NOT a `defaults write`; macOS display scaling is a live
#               CoreGraphics reconfiguration, so the work is delegated to the
#               os/defaults/display-mode.swift helper (public CGDisplay* API).
# Depends on:   install/messages.zsh; os/defaults/display-mode.swift; the
#               `swift` interpreter from Xcode CLT; $DOTFILEDIR exported by
#               caller. Does NOT source _apply_verify.zsh (no `defaults` keys).
# Side effects: apply_display permanently reconfigures the built-in display
#               mode (takes effect immediately, persists across logins);
#               verify_display is read-only and returns non-zero on drift.
# =============================================================================

set -euo pipefail

: "${DOTFILEDIR:?DOTFILEDIR not set -- run via 'task macos:*' or export it manually}"
source "${DOTFILEDIR}/install/messages.zsh"

typeset -g DISPLAY_HELPER="${DOTFILEDIR}/os/defaults/display-mode.swift"

apply_display() {
  local out
  if out=$(swift "${DISPLAY_HELPER}" apply 2>&1); then
    success "display: built-in at More Space (${out})"
  else
    error "display: failed to set built-in to More Space -- ${out}"
    return 1
  fi
}

verify_display() {
  local out
  if out=$(swift "${DISPLAY_HELPER}" verify 2>&1); then
    check "display.builtin = More Space (${out})"
  else
    cross "display.builtin: not at More Space (${out})"
    return 1
  fi
}
