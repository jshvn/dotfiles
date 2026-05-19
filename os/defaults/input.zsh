#!/bin/zsh
# os/defaults/input.zsh -- Keyboard / trackpad defaults
# (gated on features.macos-input).
#
# Purpose:
#   Declare the keyboard / trackpad / pointer keys this v2 fleet wants and
#   provide apply / verify entry points that consume a single tuple-array
#   source of truth (D-02). v1 starter ships exactly one key
#   (swipescrolldirection) hoisted from v1 `defaults-appearance`; the file
#   exists so OSCF-01's file-exists contract is satisfied without
#   speculative defaults.
#
# Caller:
#   taskfiles/macos.yml -- macos:defaults:input task (Plan 03). The task
#   sources this file and invokes apply_input (cmds:) and verify_input
#   (status:).
#
# Side effects:
#   apply_input runs `defaults write` for each tuple. Input-domain keys
#   take effect on next login / system reset; no canonical UI process
#   restart applies (no killall here).
#   verify_input is unprivileged and read-only.
#
# Contract:
#   Sourced-only. Carries `set -euo pipefail` by v2 convention (CF-06).
#   Expects $DOTFILEDIR to be exported by the caller.
#
# Extension point:
#   Add KeyRepeat / InitialKeyRepeat / com.apple.trackpad.scaling tuples
#   when preferences emerge -- keep array small to satisfy OSCF-01 file-
#   exists contract without speculative defaults.

set -euo pipefail

# Source the messages library. messages.zsh handles its own set -u-safe
# double-source guard via the `:-` default expansion on
# $DOTFILES_MESSAGES_LOADED (see messages.zsh `set -u contract` block);
# a bare source is sufficient and idempotent under `set -euo pipefail`.
: "${DOTFILEDIR:?DOTFILEDIR not set -- run via 'task macos:*' or export it manually}"
source "${DOTFILEDIR}/install/messages.zsh"

# ---------------------------------------------------------------------------
# INPUT_DEFAULTS -- single source of truth (D-02).
# Tuple stride 4: (domain, key, expected_value, write_type).
# ---------------------------------------------------------------------------
typeset -ga INPUT_DEFAULTS=(
  "NSGlobalDomain"  "com.apple.swipescrolldirection"  "false"  "bool"
)

apply_input() {
  local i domain key value type
  for ((i = 1; i <= ${#INPUT_DEFAULTS[@]}; i += 4)); do
    domain="${INPUT_DEFAULTS[$i]}"
    key="${INPUT_DEFAULTS[$((i + 1))]}"
    value="${INPUT_DEFAULTS[$((i + 2))]}"
    type="${INPUT_DEFAULTS[$((i + 3))]}"
    defaults write "$domain" "$key" "-${type}" "$value"
  done
  # No killall: input domain keys take effect on next login or system reset;
  # no canonical UI process to restart for these keys.
}

verify_input() {
  local i domain key value type current expected_read failed=0
  for ((i = 1; i <= ${#INPUT_DEFAULTS[@]}; i += 4)); do
    domain="${INPUT_DEFAULTS[$i]}"
    key="${INPUT_DEFAULTS[$((i + 1))]}"
    value="${INPUT_DEFAULTS[$((i + 2))]}"
    type="${INPUT_DEFAULTS[$((i + 3))]}"
    current=$(defaults read "$domain" "$key" 2>/dev/null || echo "<unset>")
    # bool round-trip normalization (RESEARCH Pitfall 2).
    case "$type" in
      bool) [[ "$value" == "true" ]] && expected_read="1" || expected_read="0" ;;
      *)    expected_read="$value" ;;
    esac
    if [[ "$current" == "$expected_read" ]]; then
      check "input.$key = $value"
    else
      cross "input.$key: expected '$expected_read', got '$current'"
      failed=1
    fi
  done
  return $failed
}
