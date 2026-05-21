#!/bin/zsh

# =============================================================================
# os/defaults/security.zsh -- Security / privacy defaults
#                             (gated on features.macos-security)
#
# Purpose:      Declare screensaver, hot-plug-image-capture, and guest-
#               account posture; servers also enable this concern, so keys
#               must stay server-safe (no GUI assumptions).
# Depends on:   install/messages.zsh; os/defaults/_apply_verify.zsh;
#               $DOTFILEDIR exported by caller.
# Side effects: `defaults write` for global SECURITY_DEFAULTS + `defaults
#               -currentHost write` for SECURITY_DEFAULTS_CURRENTHOST;
#               conditionally `sudo sysadminctl -guestAccount off` and
#               `sudo /usr/libexec/ApplicationFirewall/socketfilterfw
#               --setglobalstate on` (both gated on unprivileged status
#               checks so sudo never prompts on a converged machine).
#               No killall.
# =============================================================================

set -euo pipefail

: "${DOTFILEDIR:?DOTFILEDIR not set -- run via 'task macos:*' or export it manually}"
source "${DOTFILEDIR}/install/messages.zsh"

# _apply_defaults / _verify_defaults take an optional 3rd arg `scope_flag`
# (e.g. "-currentHost") so the per-host plist family uses the same helper
# signature as the global-scope family.
source "${DOTFILEDIR}/os/defaults/_apply_verify.zsh"

# Tuple stride 4: (domain, key, expected_value, write_type).
typeset -ga SECURITY_DEFAULTS=(
  "com.apple.screensaver"  "askForPassword"       "1"  "int"
  "com.apple.screensaver"  "askForPasswordDelay"  "0"  "int"
)

# Per-host plists live under ~/Library/Preferences/ByHost/<domain>.<UUID>.plist;
# reads/writes MUST go through `defaults -currentHost` or the value is
# invisible to the apply/verify loops.
typeset -ga SECURITY_DEFAULTS_CURRENTHOST=(
  "com.apple.ImageCapture"  "disableHotPlug"  "true"  "bool"
)

apply_security() {
  _apply_defaults SECURITY_DEFAULTS
  _apply_defaults SECURITY_DEFAULTS_CURRENTHOST "" -currentHost
  # Guest account: sysadminctl output varies across macOS versions; observed:
  #   "Guest account enabled." / "Guest account disabled."
  #   "Enabled = true" / "Enabled = false"
  #   "Enabled: Yes" / "Enabled: No"
  # A bare substring grep for "enabled" silently false-positives on
  # "Enabled = false". The two-step parser checks disabled signals first;
  # only if disabled is NOT detected and enabled IS detected do we conclude
  # the account is enabled and trigger sudo. Unknown output is no-op.
  local guest_status guest_state=unknown
  guest_status=$(sysadminctl -guestAccount status 2>&1 || true)
  if printf '%s' "$guest_status" | grep -qiE '\bdisabled\b|enabled[[:space:]]*[:=][[:space:]]*(false|no|0)'; then
    guest_state=disabled
  elif printf '%s' "$guest_status" | grep -qiE '\benabled\b'; then
    guest_state=enabled
  fi
  if [[ "$guest_state" == enabled ]]; then
    warn "Guest account is enabled. Disabling it now (sudo required)..."
    if ! sudo sysadminctl -guestAccount off; then
      error "Failed to disable guest account; run manually: sudo sysadminctl -guestAccount off"
      return 1
    fi
  fi
  # Application Firewall: socketfilterfw --getglobalstate works without sudo
  # and prints e.g. "Firewall is enabled. (State = 1)" or
  # "Firewall is disabled. (State = 0)". State 1 (on) and 2 (on + block all)
  # are both treated as desired; only state 0 triggers the sudo write.
  local fw_status fw_state=unknown
  fw_status=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>&1 || true)
  if printf '%s' "$fw_status" | grep -qE 'State = [12]\b'; then
    fw_state=enabled
  elif printf '%s' "$fw_status" | grep -qE 'State = 0\b'; then
    fw_state=disabled
  fi
  if [[ "$fw_state" == disabled ]]; then
    warn "Application Firewall is disabled. Enabling it now (sudo required)..."
    if ! sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on >/dev/null; then
      error "Failed to enable firewall; run manually: sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on"
      return 1
    fi
  fi
}

verify_security() {
  local failed=0
  _verify_defaults SECURITY_DEFAULTS security || failed=1
  # _verify_defaults appends ` (currentHost)` to its check / cross messages
  # automatically when scope_flag is set.
  _verify_defaults SECURITY_DEFAULTS_CURRENTHOST security -currentHost || failed=1
  # Mirrors apply_security's two-step parser; raw output surfaced in the
  # cross message so field debugging is not misled by a missing substring.
  local guest_status guest_state=unknown
  guest_status=$(sysadminctl -guestAccount status 2>&1 || true)
  if printf '%s' "$guest_status" | grep -qiE '\bdisabled\b|enabled[[:space:]]*[:=][[:space:]]*(false|no|0)'; then
    guest_state=disabled
  elif printf '%s' "$guest_status" | grep -qiE '\benabled\b'; then
    guest_state=enabled
  fi
  if [[ "$guest_state" == disabled ]]; then
    check "security.guest-account = disabled"
  else
    cross "security.guest-account: expected 'disabled', got '$guest_state', raw='$guest_status'"
    failed=1
  fi
  # Firewall: mirrors apply_security's parser; raw output surfaced in the
  # cross message so field debugging is not misled by a missing substring.
  local fw_status fw_state=unknown
  fw_status=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>&1 || true)
  if printf '%s' "$fw_status" | grep -qE 'State = [12]\b'; then
    fw_state=enabled
  elif printf '%s' "$fw_status" | grep -qE 'State = 0\b'; then
    fw_state=disabled
  fi
  if [[ "$fw_state" == enabled ]]; then
    check "security.firewall = enabled"
  else
    cross "security.firewall: expected 'enabled', got '$fw_state', raw='$fw_status'"
    failed=1
  fi
  return $failed
}
