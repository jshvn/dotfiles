#!/bin/zsh
# os/defaults/security.zsh -- Security / privacy defaults
# (gated on features.macos-security).
#
# Purpose:
#   Declare the screensaver, hot-plug-image-capture, and guest-account
#   posture this v2 fleet wants and provide apply / verify entry points
#   that consume tuple-array sources of truth (D-02). This is the one
#   concern servers also enable -- keys must stay server-safe (no GUI
#   assumptions).
#
# Caller:
#   taskfiles/macos.yml -- macos:defaults:security task (Plan 03). The
#   task sources this file and invokes apply_security (cmds:) and
#   verify_security (status:).
#
# Side effects:
#   apply_security runs `defaults write` for each row of SECURITY_DEFAULTS
#   (global plist), `defaults -currentHost write` for each row of
#   SECURITY_DEFAULTS_CURRENTHOST (per-host plist under
#   ~/Library/Preferences/ByHost/), and conditionally invokes
#   `sudo sysadminctl -guestAccount off` -- but only after first checking
#   the unprivileged `sysadminctl -guestAccount status` output, so sudo
#   never prompts on a converged machine (RESEARCH Code Examples;
#   CONTEXT Claude's Discretion option a).
#   verify_security is unprivileged and read-only.
#
#   No killall: security keys take effect at next logout or screensaver
#   activation; no relevant UI process to restart.
#
#   Two menu-bar-visibility keys from v1 `defaults-misc` (lines 102-105 of
#   the v1 macos.yml -- the text-input-menu visibility and assistant-menu
#   visibility toggles) are intentionally NOT ported here. They are
#   personal-preference toggles, not security posture, and defer to a
#   future preferences.zsh concern (CONTEXT Claude's Discretion +
#   RESEARCH User-Constraints).
#
# Contract:
#   Sourced-only. Carries `set -euo pipefail` by v2 convention (CF-06).
#   Expects $DOTFILEDIR to be exported by the caller.
#   Two tuple-arrays:
#     SECURITY_DEFAULTS              -- global plist scope (default `defaults`)
#     SECURITY_DEFAULTS_CURRENTHOST  -- per-host plist scope (`-currentHost`)
#   RESEARCH Pitfall 3: addressing a `-currentHost`-scoped key with the
#   default `defaults read` (no flag) returns `<unset>` even when the value
#   is in fact set -- the loops below MUST use the matching scope flag.

set -euo pipefail

# Source the messages library. messages.zsh handles its own set -u-safe
# double-source guard via the `:-` default expansion on
# $DOTFILES_MESSAGES_LOADED (see messages.zsh `set -u contract` block);
# a bare source is sufficient and idempotent under `set -euo pipefail`.
: "${DOTFILEDIR:?DOTFILEDIR not set -- run via 'task macos:*' or export it manually}"
source "${DOTFILEDIR}/install/messages.zsh"

# ---------------------------------------------------------------------------
# SECURITY_DEFAULTS -- global plist scope (D-02).
# Tuple stride 4: (domain, key, expected_value, write_type).
# Source: v1 taskfiles/macos.yml `defaults-general` (screensaver lines 29-38).
# ---------------------------------------------------------------------------
typeset -ga SECURITY_DEFAULTS=(
  "com.apple.screensaver"  "askForPassword"       "1"  "int"
  "com.apple.screensaver"  "askForPasswordDelay"  "0"  "int"
)

# ---------------------------------------------------------------------------
# SECURITY_DEFAULTS_CURRENTHOST -- per-host plist scope (D-02).
# Per-host plists live under ~/Library/Preferences/ByHost/<domain>.<UUID>.plist;
# reads / writes MUST go through `defaults -currentHost` or the value is
# invisible to the apply/verify loops (RESEARCH Pitfall 3).
# Source: v1 taskfiles/macos.yml `defaults-misc` line 96.
# ---------------------------------------------------------------------------
typeset -ga SECURITY_DEFAULTS_CURRENTHOST=(
  "com.apple.ImageCapture"  "disableHotPlug"  "true"  "bool"
)

apply_security() {
  local i domain key value type
  # --- global-scope tuples ------------------------------------------------
  for ((i = 1; i <= ${#SECURITY_DEFAULTS[@]}; i += 4)); do
    domain="${SECURITY_DEFAULTS[$i]}"
    key="${SECURITY_DEFAULTS[$((i + 1))]}"
    value="${SECURITY_DEFAULTS[$((i + 2))]}"
    type="${SECURITY_DEFAULTS[$((i + 3))]}"
    defaults write "$domain" "$key" "-${type}" "$value"
  done
  # --- currentHost-scope tuples ------------------------------------------
  for ((i = 1; i <= ${#SECURITY_DEFAULTS_CURRENTHOST[@]}; i += 4)); do
    domain="${SECURITY_DEFAULTS_CURRENTHOST[$i]}"
    key="${SECURITY_DEFAULTS_CURRENTHOST[$((i + 1))]}"
    value="${SECURITY_DEFAULTS_CURRENTHOST[$((i + 2))]}"
    type="${SECURITY_DEFAULTS_CURRENTHOST[$((i + 3))]}"
    defaults -currentHost write "$domain" "$key" "-${type}" "$value"
  done
  # --- guest account -----------------------------------------------------
  # Check the unprivileged status first; sudo only fires when the guest
  # account is actually enabled (RESEARCH Code Examples; CONTEXT
  # Claude's Discretion option a).
  # macOS sysadminctl output varies across versions; observed forms:
  #   "Guest account enabled." / "Guest account disabled."
  #   "Enabled = true" / "Enabled = false"
  #   "Enabled: Yes" / "Enabled: No"
  # A bare substring grep for "enabled" silently false-positives on
  # "Enabled = false" (the v1 behavior) and a substring grep for
  # "disabled" misses every variant that uses a boolean qualifier instead.
  # The two-step parser below first checks for the disabled signals; only
  # if disabled is NOT detected and enabled IS detected do we conclude
  # the account is enabled and trigger sudo. Unknown output (empty / perm
  # denied) is treated as not-enabled (no-op).
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
}

verify_security() {
  local i domain key value type current expected_read failed=0
  # --- global-scope tuples ------------------------------------------------
  for ((i = 1; i <= ${#SECURITY_DEFAULTS[@]}; i += 4)); do
    domain="${SECURITY_DEFAULTS[$i]}"
    key="${SECURITY_DEFAULTS[$((i + 1))]}"
    value="${SECURITY_DEFAULTS[$((i + 2))]}"
    type="${SECURITY_DEFAULTS[$((i + 3))]}"
    current=$(defaults read "$domain" "$key" 2>/dev/null || echo "<unset>")
    # bool round-trip normalization (RESEARCH Pitfall 2).
    case "$type" in
      bool) [[ "$value" == "true" ]] && expected_read="1" || expected_read="0" ;;
      *)    expected_read="$value" ;;
    esac
    if [[ "$current" == "$expected_read" ]]; then
      check "security.$key = $value"
    else
      cross "security.$key: expected '$expected_read', got '$current'"
      failed=1
    fi
  done
  # --- currentHost-scope tuples ------------------------------------------
  for ((i = 1; i <= ${#SECURITY_DEFAULTS_CURRENTHOST[@]}; i += 4)); do
    domain="${SECURITY_DEFAULTS_CURRENTHOST[$i]}"
    key="${SECURITY_DEFAULTS_CURRENTHOST[$((i + 1))]}"
    value="${SECURITY_DEFAULTS_CURRENTHOST[$((i + 2))]}"
    type="${SECURITY_DEFAULTS_CURRENTHOST[$((i + 3))]}"
    current=$(defaults -currentHost read "$domain" "$key" 2>/dev/null || echo "<unset>")
    case "$type" in
      bool) [[ "$value" == "true" ]] && expected_read="1" || expected_read="0" ;;
      *)    expected_read="$value" ;;
    esac
    if [[ "$current" == "$expected_read" ]]; then
      check "security.$key = $value (currentHost)"
    else
      cross "security.$key: expected '$expected_read', got '$current' (currentHost)"
      failed=1
    fi
  done
  # --- guest account -----------------------------------------------------
  # Mirrors apply_security's two-step parser. Disabled-signal short-circuit
  # comes first so "Enabled = false" is correctly recognized as disabled.
  # Surface the raw output in the cross message so field debugging is not
  # misled by absence of a specific substring.
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
  return $failed
}
