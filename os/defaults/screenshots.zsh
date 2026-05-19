#!/bin/zsh
# os/defaults/screenshots.zsh -- Screen capture defaults
# (gated on features.macos-screenshots).
#
# Purpose:
#   Declare the com.apple.screencapture keys this v2 fleet wants and
#   provide apply / verify entry points that consume a single tuple-array
#   source of truth (D-02). v1 starter: screenshots go to
#   $HOME/Pictures/Screenshots as png with no drop shadow.
#
# Caller:
#   taskfiles/macos.yml -- macos:defaults:screenshots task (Plan 03). The
#   task sources this file and invokes apply_screenshots (cmds:) and
#   verify_screenshots (status:).
#
# Side effects:
#   apply_screenshots creates the screenshot directory before writing the
#   `location` key (RESEARCH Pitfall 14: macOS silently falls back to
#   ~/Desktop if the configured location does not exist when the key is
#   read by the screencapture process). It then runs `defaults write` for
#   each tuple and restarts SystemUIServer so the change takes effect
#   without requiring a logout. The killall is guarded with `|| true`
#   (RESEARCH Pitfall 5).
#   verify_screenshots is unprivileged and read-only.
#
# Contract:
#   Sourced-only. Carries `set -euo pipefail` by v2 convention (CF-06).
#   Expects $DOTFILEDIR to be exported by the caller.
#
#   The `location` tuple value embeds the literal token `$HOME/Pictures/
#   Screenshots` -- the apply / verify loops expand it via zsh's `(e)`
#   parameter-expansion flag (`"${(e)value}"`) at use time. Do NOT collapse
#   this to a pre-expanded path in the array: keeping the literal in the
#   array makes the file self-contained and re-expandable when the same
#   array is read by a different $HOME (e.g. CI fixtures).

set -euo pipefail

# Source the messages library. messages.zsh handles its own set -u-safe
# double-source guard via the `:-` default expansion on
# $DOTFILES_MESSAGES_LOADED (see messages.zsh `set -u contract` block);
# a bare source is sufficient and idempotent under `set -euo pipefail`.
: "${DOTFILEDIR:?DOTFILEDIR not set -- run via 'task macos:*' or export it manually}"
source "${DOTFILEDIR}/install/messages.zsh"

# Shared apply / verify helpers (REVW-04: extracted in Plan 13-04).
# _apply_defaults / _verify_defaults both expand the literal $HOME token in
# tuple values via narrow substitution (`${value/\$HOME/$HOME}`); the
# (e)-flag was rejected because it performs command substitution and would
# be a code-exec sink if a future concern starts sourcing tuple values from
# external data.
source "${DOTFILEDIR}/os/defaults/_apply_verify.zsh"

# ---------------------------------------------------------------------------
# SCREENSHOTS_DEFAULTS -- single source of truth (D-02).
# Tuple stride 4: (domain, key, expected_value, write_type).
# The `location` value embeds the literal $HOME token; _apply_defaults /
# _verify_defaults expand it via narrow substitution at use time.
# ---------------------------------------------------------------------------
typeset -ga SCREENSHOTS_DEFAULTS=(
  "com.apple.screencapture"  "location"        "\$HOME/Pictures/Screenshots"  "string"
  "com.apple.screencapture"  "type"            "png"                          "string"
  "com.apple.screencapture"  "disable-shadow"  "true"                         "bool"
)

apply_screenshots() {
  # Ensure the screenshots directory exists BEFORE the location key is
  # written; macOS silently falls back to ~/Desktop otherwise
  # (RESEARCH Pitfall 14).
  mkdir -p "$HOME/Pictures/Screenshots"
  _apply_defaults SCREENSHOTS_DEFAULTS SystemUIServer
}

verify_screenshots() {
  _verify_defaults SCREENSHOTS_DEFAULTS screenshots
}
