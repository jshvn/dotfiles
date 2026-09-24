#!/bin/zsh

# =============================================================================
# os/defaults/security.zsh -- Security / privacy defaults
#                             (gated on features.macos-security)
#
# Purpose:      Declare screen-lock delay, hot-plug-image-capture, guest-
#               account, and firewall posture.
# Depends on:   install/messages.zsh; os/defaults/_apply_verify.zsh;
#               $DOTFILEDIR exported by caller.
# Side effects: `defaults -currentHost write` for
#               SECURITY_DEFAULTS_CURRENTHOST; conditionally
#               `sysadminctl -screenLock immediate -password -` (prompts for
#               the account password on the terminal), `sudo sysadminctl
#               -guestAccount off`, and `sudo
#               /usr/libexec/ApplicationFirewall/socketfilterfw
#               --setglobalstate on` (all gated on unprivileged status checks
#               so nothing prompts on a converged machine). No killall.
# =============================================================================

set -euo pipefail

: "${DOTFILEDIR:?DOTFILEDIR not set -- run via 'task macos:*' or export it manually}"
source "${DOTFILEDIR}/install/messages.zsh"

# _apply_defaults / _verify_defaults take an optional 3rd arg `scope_flag`
# (e.g. "-currentHost") so the per-host plist family uses the same helper
# signature as the global-scope family.
source "${DOTFILEDIR}/os/defaults/_apply_verify.zsh"

# Per-host plists live under ~/Library/Preferences/ByHost/<domain>.<UUID>.plist;
# reads/writes MUST go through `defaults -currentHost` or the value is
# invisible to the apply/verify loops.
typeset -ga SECURITY_DEFAULTS_CURRENTHOST=(
  "com.apple.ImageCapture"  "disableHotPlug"  "true"  "bool"
)

# Screen lock: the "require password after sleep or screen saver" delay is
# owned by sysadminctl, not by com.apple.screensaver keys (those stopped
# driving the setting in macOS 13). `-screenLock status` is unprivileged and
# logs one line to stderr, e.g. "screenLock delay is immediate" or
# "screenLock delay is 300 seconds". Echoes immediate|delayed|unknown.
_security_screenlock_state() {
  local out
  out=$(sysadminctl -screenLock status 2>&1 || true)
  if printf '%s' "$out" | grep -qi 'immediate'; then
    echo immediate
  elif printf '%s' "$out" | grep -qi 'screenLock delay'; then
    echo delayed
  else
    echo unknown
  fi
}

apply_security() {
  _apply_defaults SECURITY_DEFAULTS_CURRENTHOST "" -currentHost
  # Screen lock: sysadminctl needs the account password (not sudo); `-password -`
  # prompts on the terminal, mirroring how the sudo steps below prompt.
  if [[ "$(_security_screenlock_state)" != immediate ]]; then
    warn "Screen lock is not immediate. Setting it now (account password required)..."
    if ! sysadminctl -screenLock immediate -password -; then
      error "Failed to set screen lock; run manually: sysadminctl -screenLock immediate -password -"
      return 1
    fi
  fi
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
  # _verify_defaults appends ` (currentHost)` to its check / cross messages
  # automatically when scope_flag is set.
  _verify_defaults SECURITY_DEFAULTS_CURRENTHOST security -currentHost || failed=1
  local lock_state
  lock_state=$(_security_screenlock_state)
  if [[ "$lock_state" == immediate ]]; then
    check "security.screen-lock = immediate"
  else
    cross "security.screen-lock: expected 'immediate', got '$lock_state', raw='$(sysadminctl -screenLock status 2>&1 || true)'"
    failed=1
  fi
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
