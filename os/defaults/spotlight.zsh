#!/bin/zsh

# =============================================================================
# os/defaults/spotlight.zsh -- Free Cmd+Space for Raycast
#                              (gated on features.macos-spotlight)
#
# Purpose:      Disable the macOS Spotlight "Show Spotlight search" shortcut
#               (symbolic hotkey 64, Cmd+Space) so Raycast can claim it.
#               Raycast's own Cmd+Space binding is set in-app and persists via
#               Raycast settings sync -- only the Spotlight side is a macOS
#               default we can declare here.
# Depends on:   install/messages.zsh; defaults; PlistBuddy; activateSettings;
#               $DOTFILEDIR exported by caller (taskfiles/macos.yml heredoc).
# Side effects: apply_spotlight writes com.apple.symbolichotkeys key 64 then
#               reloads the hotkey table via activateSettings (guarded with
#               `|| true`). verify_spotlight is read-only.
# =============================================================================

set -euo pipefail

: "${DOTFILEDIR:?DOTFILEDIR not set -- run via 'task macos:*' or export it manually}"
source "${DOTFILEDIR}/install/messages.zsh"

# Spotlight search = AppleSymbolicHotKeys entry 64. The nested-dict value does
# not fit the (domain,key,value,type) tuple helper, so this concern is bespoke.
# parameters = (space char, keycode 49, Cmd mask) -- kept identical to the
# system default so re-enabling is just flipping `enabled` back to 1.
typeset -gr SPOTLIGHT_HOTKEY_ID=64
typeset -gr SPOTLIGHT_HOTKEY_VALUE='{enabled = 0; value = { parameters = (32, 49, 1048576); type = standard; }; }'

apply_spotlight() {
  defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys \
    -dict-add "$SPOTLIGHT_HOTKEY_ID" "$SPOTLIGHT_HOTKEY_VALUE"
  # ponytail: activateSettings -u reloads the hotkey table without a logout.
  # Ceiling -- on some macOS versions the menu-bar Spotlight glyph only clears
  # after the next login; the shortcut itself is freed immediately.
  /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null || true
}

# Reads key 64's `enabled` flag back via an exported plist (cfprefsd-consistent,
# unlike reading the on-disk .plist directly). Returns 0 when disabled.
verify_spotlight() {
  local tmp enabled
  tmp=$(mktemp)
  defaults export com.apple.symbolichotkeys "$tmp" 2>/dev/null || true
  enabled=$(/usr/libexec/PlistBuddy -c "Print :AppleSymbolicHotKeys:${SPOTLIGHT_HOTKEY_ID}:enabled" "$tmp" 2>/dev/null || echo "<unset>")
  rm -f "$tmp"
  if [[ "$enabled" == "false" || "$enabled" == "0" ]]; then
    check "spotlight.cmd-space disabled (freed for Raycast)"
    return 0
  fi
  cross "spotlight.cmd-space: expected disabled, got enabled='$enabled'"
  return 1
}
