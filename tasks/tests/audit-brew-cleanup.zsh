#!/usr/bin/env zsh

# =============================================================================
# tasks/tests/audit-brew-cleanup.zsh -- smoke tests for tasks/audit-brew-cleanup.zsh
#
# Purpose:      Feed the scanner the dry-run shapes brew prints (items with a
#               clean cache and its closing "Run ..." line, items plus a cache
#               section, an update report before the sections, columns,
#               nothing to remove) and assert the exact items.
# Depends on:   DOTFILEDIR env var (exported by Taskfile.yml);
#               tasks/audit-brew-cleanup.zsh; tasks/messages.zsh.
# Side effects: none.
# =============================================================================

set -euo pipefail

: "${DOTFILEDIR:?DOTFILEDIR must be set (run via task test)}"

source "${DOTFILEDIR}/tasks/messages.zsh"

SCAN="${DOTFILEDIR}/tasks/audit-brew-cleanup.zsh"
failed=0
tab=$'\t'

# scan NAME EXPECTED INPUT: the scanner's output for INPUT must equal EXPECTED exactly
scan() {
  local name="$1" want="$2" input="$3" got
  got=$(print -rn -- "$input" | zsh "$SCAN")
  if [[ "$got" == "$want" ]]; then
    check "scan: $name"
  else
    cross "scan: $name"
    print -r -- "      want: ${(q)want}" "      got:  ${(q)got}"
    failed=$((failed + 1))
  fi
}

scan "items, clean cache, closing line" "casks${tab}zoom
VSCode extensions${tab}jshvn.title-buttons" \
'Would uninstall casks:
zoom
Would uninstall VSCode extensions:
jshvn.title-buttons
Run `brew bundle cleanup --force` to make these changes.
'

scan "items plus brew cache section" "formulae${tab}wget" \
'Would uninstall formulae:
wget
Would `brew cleanup`:
Would remove: /Users/josh/Library/Caches/Homebrew/wget--1.25.0.bottle.tar.gz (1.5MB)
Run `brew bundle cleanup --force` to make these changes.
'

scan "update report before the sections" "taps${tab}hashicorp/tap" \
'==> Updated Homebrew from 7.0.8 to 7.0.9.
==> New Formulae
fresh-formula
Would untap:
hashicorp/tap
'

scan "items in columns" "formulae${tab}bat
formulae${tab}fd
formulae${tab}htop" \
'Would uninstall formulae:
bat     fd      htop
'

scan "nothing to remove" "" ''

if (( failed == 0 )); then
  info "audit-brew-cleanup: all checks passed"
else
  error "audit-brew-cleanup: ${failed} check(s) failed"
fi
exit "$failed"
