#!/usr/bin/env zsh

# =============================================================================
# tasks/tests/validate.zsh -- smoke test for two read-backs in tasks/validate.zsh
#
# Purpose:      Run the real validate against a small declaration, with fake
#               defaults, unzip and brew answering from a sandbox. A
#               dictionary that matches (keys in another order, 1000.0
#               declared and 1000 read back) and a matching list check; a
#               dictionary that differs and one that is absent cross; none
#               goes through the scalar compare. Each managed Firefox
#               preference on the fake Sync list (one split across lines, as
#               in firefox.js) warns; an unmanaged or unlisted one does not.
#               Only those lines are asserted: the rest of validate runs
#               against nothing, and its exit code is ignored.
# Depends on:   DOTFILEDIR env var (exported by Taskfile.yml); macOS
#               (validate reads dscl and scutil); tasks/validate.zsh;
#               tasks/messages.zsh; plutil; jq.
# Side effects: creates a sandbox under mktemp -d, removed via trap.
# =============================================================================

set -euo pipefail

: "${DOTFILEDIR:?DOTFILEDIR must be set (run via task test)}"
source "${DOTFILEDIR}/tasks/messages.zsh"

typeset -i failures=0
sandbox=$(mktemp -d "${TMPDIR:-/tmp}/validate-test.XXXXXX")
trap 'rm -rf "$sandbox"' EXIT INT TERM
mkdir -p "$sandbox/bin" "$sandbox/plist" "$sandbox/state"

# --- the fakes: defaults export serves $SANDBOX/plist/<domain>.plist; unzip prints a Sync list and
# exits 2, as it does on omni.ja; brew finds nothing ---
print -r -- '#!/bin/sh
[ "$1" = export ] && [ -f "$SANDBOX/plist/$2.plist" ] && exec cat "$SANDBOX/plist/$2.plist"; exit 1' > "$sandbox/bin/defaults"
print -r -- '#!/bin/sh
printf "%s\n" "pref(\"services.sync.prefs.sync.browser.synced\", true);" \
  "pref(\"services.sync.prefs.sync.browser.other\", true);" \
  "pref(" "  \"services.sync.prefs.sync.browser.wrapped\"," "  true" ");"
exit 2' > "$sandbox/bin/unzip"
print -r -- '#!/bin/sh
exit 1' > "$sandbox/bin/brew"
chmod +x "$sandbox/bin/"*

# --- the live side: Same and List hold what is declared, Changed differs, Absent is missing ---
print -r -- '<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>Same</key><dict><key>s</key><string>a\b"c</string><key>r</key><real>1000</real><key>n</key><integer>5</integer><key>t</key><true/></dict>
<key>List</key><array><string>a</string><string>b</string></array>
<key>Changed</key><dict><key>n</key><integer>4</integer></dict>
</dict></plist>' > "$sandbox/plist/test.dict.plist"
declared=$(jq -n '{
  dotfiles: {checkout: "/nonexistent", profile: "none", links: {}, apps: {firefox: {enable: true}}, system: {}},
  defaults: {CustomUserPreferences: {
    "test.dict": {Same: {t: true, n: 5, r: 1000.0, s: "a\\b\"c"}, List: ["a", "b"], Changed: {n: 5}, Absent: {n: 1}},
    "org.mozilla.firefox": {Preferences: {"browser.synced": {}, "browser.wrapped": {}, "browser.local": {}}}}},
  casks: [], brewfile: ""}')

out=$(SANDBOX="$sandbox" PATH="$sandbox/bin:$PATH" DOTFILES_STATE="$sandbox/state" \
  zsh "$DOTFILEDIR/tasks/validate.zsh" <<< "$declared" 2>&1) || true

# expect NAME PATTERN [absent]: the pattern is in validate's output, or with absent, is not
expect() {
  local found=0 want=1
  grep -qE -- "$2" <<< "$out" && found=1
  [[ "${3:-}" == absent ]] && want=0
  if (( found == want )); then
    check "validate.$1"
  else
    cross "validate.$1: expected /$2/ ${3:-present}"
    failures+=1
  fi
}
expect dict-same 'test\.dict\.Same matches the declaration'
expect list-same 'test\.dict\.List matches the declaration'
expect dict-changed 'test\.dict\.Changed: differs'
expect dict-absent 'test\.dict\.Absent: differs'
expect dict-not-scalar "test\.dict\.(Same|List): expected" absent
expect sync-carried 'Sync now carries browser\.synced'
expect sync-wrapped 'Sync now carries browser\.wrapped'
expect sync-local 'carries browser\.local' absent
expect sync-unmanaged 'carries browser\.other' absent

(( failures == 0 )) || print -r -- "$out" | sed 's/^/      /'
exit $failures
