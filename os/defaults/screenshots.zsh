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

# ---------------------------------------------------------------------------
# SCREENSHOTS_DEFAULTS -- single source of truth (D-02).
# Tuple stride 4: (domain, key, expected_value, write_type).
# The `location` value embeds $HOME; expanded with `(e)` flag at use time.
# ---------------------------------------------------------------------------
typeset -ga SCREENSHOTS_DEFAULTS=(
  "com.apple.screencapture"  "location"        "\$HOME/Pictures/Screenshots"  "string"
  "com.apple.screencapture"  "type"            "png"                          "string"
  "com.apple.screencapture"  "disable-shadow"  "true"                         "bool"
)

apply_screenshots() {
  local i domain key value type expanded
  # Ensure the screenshots directory exists BEFORE the location key is
  # written; macOS silently falls back to ~/Desktop otherwise
  # (RESEARCH Pitfall 14).
  mkdir -p "$HOME/Pictures/Screenshots"
  for ((i = 1; i <= ${#SCREENSHOTS_DEFAULTS[@]}; i += 4)); do
    domain="${SCREENSHOTS_DEFAULTS[$i]}"
    key="${SCREENSHOTS_DEFAULTS[$((i + 1))]}"
    value="${SCREENSHOTS_DEFAULTS[$((i + 2))]}"
    type="${SCREENSHOTS_DEFAULTS[$((i + 3))]}"
    # Expand the literal $HOME token at use time. (e)-flag was rejected --
    # it performs command substitution + arithmetic and would be a code-exec
    # sink the moment a future concern is copied from this template and
    # starts sourcing tuple values from external data. Narrow substitution
    # only.
    expanded="${value/\$HOME/$HOME}"
    defaults write "$domain" "$key" "-${type}" "$expanded"
  done
  killall SystemUIServer 2>/dev/null || true
}

verify_screenshots() {
  local i domain key value type current expected_read failed=0 expanded
  for ((i = 1; i <= ${#SCREENSHOTS_DEFAULTS[@]}; i += 4)); do
    domain="${SCREENSHOTS_DEFAULTS[$i]}"
    key="${SCREENSHOTS_DEFAULTS[$((i + 1))]}"
    value="${SCREENSHOTS_DEFAULTS[$((i + 2))]}"
    type="${SCREENSHOTS_DEFAULTS[$((i + 3))]}"
    current=$(defaults read "$domain" "$key" 2>/dev/null || echo "<unset>")
    # Expand $HOME and any other env vars in the expected value at use time.
    expanded="${(e)value}"
    # bool round-trip normalization (RESEARCH Pitfall 2).
    case "$type" in
      bool) [[ "$expanded" == "true" ]] && expected_read="1" || expected_read="0" ;;
      *)    expected_read="$expanded" ;;
    esac
    if [[ "$current" == "$expected_read" ]]; then
      check "screenshots.$key = $expanded"
    else
      cross "screenshots.$key: expected '$expected_read', got '$current'"
      failed=1
    fi
  done
  return $failed
}
