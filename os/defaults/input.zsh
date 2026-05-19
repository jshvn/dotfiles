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

# Shared apply / verify helpers (REVW-04: extracted in Plan 13-04).
source "${DOTFILEDIR}/os/defaults/_apply_verify.zsh"

# ---------------------------------------------------------------------------
# INPUT_DEFAULTS -- single source of truth (D-02).
# Tuple stride 4: (domain, key, expected_value, write_type).
# ---------------------------------------------------------------------------
typeset -ga INPUT_DEFAULTS=(
  "NSGlobalDomain"  "com.apple.swipescrolldirection"  "false"  "bool"
)

apply_input() {
  # No killall: input domain keys take effect on next login or system reset;
  # no canonical UI process to restart for these keys.
  _apply_defaults INPUT_DEFAULTS
}

verify_input() {
  _verify_defaults INPUT_DEFAULTS input
}
