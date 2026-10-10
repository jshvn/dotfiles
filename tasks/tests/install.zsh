#!/usr/bin/env zsh

# =============================================================================
# tasks/tests/install.zsh -- smoke tests for the first-switch and cleanup helpers
#
# Purpose:      Feed tasks/brew-cleanup-scan.zsh the dry-run shapes brew prints
#               (items with a clean cache and its closing "Run ..." line, items
#               plus a cache section, an update report before the sections,
#               columns, nothing to remove) and assert the exact items. Run
#               tasks/clear-links.zsh against a throwaway HOME and assert a
#               symlink is removed, a file and a directory are moved aside, a
#               taken backup name is not overwritten, and an absent path is
#               left alone.
# Depends on:   DOTFILEDIR env var (exported by Taskfile.yml);
#               tasks/brew-cleanup-scan.zsh; tasks/clear-links.zsh;
#               tasks/messages.zsh.
# Side effects: creates a throwaway tree under mktemp -d, removed via trap.
# =============================================================================

set -euo pipefail

: "${DOTFILEDIR:?DOTFILEDIR must be set (run via task test)}"

source "${DOTFILEDIR}/tasks/messages.zsh"

SCAN="${DOTFILEDIR}/tasks/brew-cleanup-scan.zsh"
CLEAR="${DOTFILEDIR}/tasks/clear-links.zsh"
failed=0
tab=$'\t'

BASE="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-install-test.XXXXXX")"
trap 'rm -rf "$BASE"' EXIT INT TERM

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

# --- clear-links against a throwaway HOME ---------------------------------------
home="${BASE}/home"
mkdir -p "${home}/.config/tool" "${home}/.config/dirlink" "${home}/.ssh"
ln -s "${BASE}/elsewhere" "${home}/.config/tool/link.toml"
echo keep > "${home}/.config/tool/file.toml"
echo x > "${home}/.config/dirlink/inside"
echo old > "${home}/.ssh/config"
echo older > "${home}/.ssh/config.before-dotfiles"

printf '%s\n' .config/tool/link.toml .config/tool/file.toml .config/dirlink .ssh/config .config/absent \
  | HOME="$home" zsh "$CLEAR" >/dev/null 2>&1

assert() { # assert NAME CONDITION...
  local name="$1"; shift
  if "$@"; then check "clear: $name"; else cross "clear: $name"; failed=$((failed + 1)); fi
}
assert "symlink removed"            test ! -e "${home}/.config/tool/link.toml" -a ! -L "${home}/.config/tool/link.toml"
assert "file moved aside"           test -f "${home}/.config/tool/file.toml.before-dotfiles"
assert "file path cleared"          test ! -e "${home}/.config/tool/file.toml"
assert "directory moved aside"      test -f "${home}/.config/dirlink.before-dotfiles/inside"
assert "taken backup kept"          grep -qx older "${home}/.ssh/config.before-dotfiles"
assert "second backup made"         test -n "$(print -l "${home}"/.ssh/config.before-dotfiles.*(N))"
assert "absent path left alone"     test ! -e "${home}/.config/absent"

if (( failed == 0 )); then
  info "install: all checks passed"
else
  error "install: ${failed} check(s) failed"
fi
exit "$failed"
