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

# messages.zsh references a bare $DOTFILES_MESSAGES_LOADED in its double-source
# guard; under set -u that would abort. Pre-initialize the guard variable and
# the caller-supplied DOTFILEDIR var so this script is safe to source from a
# `set -euo pipefail` taskfile heredoc (matches install/resolver.zsh +
# install/compose-brewfile.zsh pattern).
: "${DOTFILEDIR:?DOTFILEDIR not set -- run via 'task macos:*' or export it manually}"
: "${DOTFILES_MESSAGES_LOADED:=}"
if [[ -z "$DOTFILES_MESSAGES_LOADED" ]]; then
  source "${DOTFILEDIR}/install/messages.zsh"
fi

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
  local i domain key value type
  for ((i = 1; i <= ${#FINDER_DEFAULTS[@]}; i += 4)); do
    domain="${FINDER_DEFAULTS[$i]}"
    key="${FINDER_DEFAULTS[$((i + 1))]}"
    value="${FINDER_DEFAULTS[$((i + 2))]}"
    type="${FINDER_DEFAULTS[$((i + 3))]}"
    defaults write "$domain" "$key" "-${type}" "$value"
  done
  killall Finder 2>/dev/null || true
}

verify_finder() {
  local i domain key value type current expected_read failed=0
  for ((i = 1; i <= ${#FINDER_DEFAULTS[@]}; i += 4)); do
    domain="${FINDER_DEFAULTS[$i]}"
    key="${FINDER_DEFAULTS[$((i + 1))]}"
    value="${FINDER_DEFAULTS[$((i + 2))]}"
    type="${FINDER_DEFAULTS[$((i + 3))]}"
    current=$(defaults read "$domain" "$key" 2>/dev/null || echo "<unset>")
    # bool round-trip normalization (RESEARCH Pitfall 2).
    case "$type" in
      bool) [[ "$value" == "true" ]] && expected_read="1" || expected_read="0" ;;
      *)    expected_read="$value" ;;
    esac
    if [[ "$current" == "$expected_read" ]]; then
      check "finder.$key = $value"
    else
      cross "finder.$key: expected '$expected_read', got '$current'"
      failed=1
    fi
  done
  return $failed
}
