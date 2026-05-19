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

# Shared apply / verify helpers (REVW-04: extracted in Plan 13-04 from the
# 5 near-identical per-concern apply_<X> / verify_<X> loops).
source "${DOTFILEDIR}/os/defaults/_apply_verify.zsh"

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
  _apply_defaults DOCK_DEFAULTS Dock
}

verify_dock() {
  _verify_defaults DOCK_DEFAULTS dock
}
