#!/bin/zsh
# os/defaults/dock.zsh -- Dock defaults (gated on features.macos-dock).
#
# Purpose:
#   Declare the Dock keys this v2 fleet wants and provide apply / verify
#   entry points that consume a single tuple-array source of truth (D-02).
#
# Caller:
#   taskfiles/macos.yml -- macos:defaults:dock task (Plan 03). The task
#   sources this file and invokes apply_dock (cmds:) and verify_dock
#   (status:). Always-on for any machine with features.macos-dock = true
#   in its resolved manifest; a no-op at the task level otherwise.
#
# Side effects:
#   apply_dock runs `defaults write com.apple.dock <key> <value>` for each
#   tuple, then restarts the Dock UI process (killall Dock) so the changes
#   take effect immediately. The killall is guarded with `|| true` so a
#   headless or pre-launch machine does not abort the script when Dock is
#   not running (RESEARCH Pitfall 5).
#   verify_dock is unprivileged and read-only.
#
# Contract:
#   Sourced-only. Carries `set -euo pipefail` by v2 convention (CF-06) even
#   though sourced files are technically exempt from LINT-04.
#   Expects $DOTFILEDIR to be exported by the caller (the task heredoc
#   exports DOTFILEDIR="{{.TASKFILE_DIR}}" before sourcing).

set -euo pipefail

# Source the messages library. messages.zsh handles its own set -u-safe
# double-source guard via the `:-` default expansion on
# $DOTFILES_MESSAGES_LOADED (see messages.zsh `set -u contract` block);
# a bare source is sufficient and idempotent under `set -euo pipefail`.
: "${DOTFILEDIR:?DOTFILEDIR not set -- run via 'task macos:*' or export it manually}"
source "${DOTFILEDIR}/install/messages.zsh"

# ---------------------------------------------------------------------------
# DOCK_DEFAULTS -- single source of truth (D-02).
# Tuple stride 4: (domain, key, expected_value, write_type).
# write_type is one of: bool int string float.
# ---------------------------------------------------------------------------
typeset -ga DOCK_DEFAULTS=(
  "com.apple.dock"  "orientation"   "bottom"  "string"
  "com.apple.dock"  "tilesize"      "45"      "int"
  "com.apple.dock"  "autohide"      "true"    "bool"
  "com.apple.dock"  "mineffect"     "genie"   "string"
  "com.apple.dock"  "show-recents"  "false"   "bool"
  "com.apple.dock"  "mru-spaces"    "false"   "bool"
)

apply_dock() {
  local i domain key value type
  for ((i = 1; i <= ${#DOCK_DEFAULTS[@]}; i += 4)); do
    domain="${DOCK_DEFAULTS[$i]}"
    key="${DOCK_DEFAULTS[$((i + 1))]}"
    value="${DOCK_DEFAULTS[$((i + 2))]}"
    type="${DOCK_DEFAULTS[$((i + 3))]}"
    defaults write "$domain" "$key" "-${type}" "$value"
  done
  killall Dock 2>/dev/null || true
}

verify_dock() {
  local i domain key value type current expected_read failed=0
  for ((i = 1; i <= ${#DOCK_DEFAULTS[@]}; i += 4)); do
    domain="${DOCK_DEFAULTS[$i]}"
    key="${DOCK_DEFAULTS[$((i + 1))]}"
    value="${DOCK_DEFAULTS[$((i + 2))]}"
    type="${DOCK_DEFAULTS[$((i + 3))]}"
    current=$(defaults read "$domain" "$key" 2>/dev/null || echo "<unset>")
    # `defaults write -bool true` round-trips to literal "1" on read; normalize
    # the expected side so the comparison succeeds on converged machines
    # (RESEARCH Pitfall 2).
    case "$type" in
      bool) [[ "$value" == "true" ]] && expected_read="1" || expected_read="0" ;;
      *)    expected_read="$value" ;;
    esac
    if [[ "$current" == "$expected_read" ]]; then
      check "dock.$key = $value"
    else
      cross "dock.$key: expected '$expected_read', got '$current'"
      failed=1
    fi
  done
  return $failed
}
