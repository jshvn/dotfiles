#!/bin/zsh
# os/defaults/finder.zsh -- Finder defaults (gated on features.macos-finder).
#
# Purpose:
#   Declare the Finder keys this v2 fleet wants and provide apply / verify
#   entry points that consume a single tuple-array source of truth (D-02).
#
# Caller:
#   taskfiles/macos.yml -- macos:defaults:finder task (Plan 03). The task
#   sources this file and invokes apply_finder (cmds:) and verify_finder
#   (status:). features.macos-finder is a same-flag-two-consumers gate
#   (D-01): the same flag also gates shell/aliases/finder.zsh in Phase 3
#   (P3 D-07). Any machine with macos-finder = true wants both the
#   Finder customization aliases and the Finder defaults applied.
#
# Side effects:
#   apply_finder runs `defaults write` for each tuple, then restarts the
#   Finder UI process (killall Finder) so the changes take effect
#   immediately. The killall is guarded with `|| true` for headless or
#   pre-launch machines (RESEARCH Pitfall 5).
#   verify_finder is unprivileged and read-only.
#
#   v1 also fired three direct-plist-edit writes against the
#   ~/Library/Preferences/com.apple.finder.plist desktop / icon-view sub-
#   dictionaries (the v1 macos.yml:80-82 block); those were brittle (depend
#   on Finder having been launched once so the parent dict exists) and are
#   dropped per Claude's Discretion (RESEARCH Pitfall 13). If desktop icon-
#   grid behavior is missed, it earns a follow-up plan, not a P6 carry-over.
#
# Contract:
#   Sourced-only. Carries `set -euo pipefail` by v2 convention (CF-06).
#   Expects $DOTFILEDIR to be exported by the caller.

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
# FINDER_DEFAULTS -- single source of truth (D-02).
# Tuple stride 4: (domain, key, expected_value, write_type).
# ---------------------------------------------------------------------------
typeset -ga FINDER_DEFAULTS=(
  "NSGlobalDomain"    "AppleShowAllExtensions"          "true"  "bool"
  "com.apple.finder"  "FXEnableExtensionChangeWarning"  "false" "bool"
  "com.apple.finder"  "FXPreferredViewStyle"            "clmv"  "string"
)

apply_finder() {
  _apply_defaults FINDER_DEFAULTS Finder
}

verify_finder() {
  _verify_defaults FINDER_DEFAULTS finder
}
