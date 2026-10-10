#!/usr/bin/env zsh

# =============================================================================
# tasks/tests/install-clear-links.zsh -- smoke tests for tasks/install-clear-links.zsh
#
# Purpose:      Run the script against a throwaway HOME and assert a symlink
#               is removed, a file and a directory are moved aside, a taken
#               backup name is not overwritten, and an absent path is left
#               alone.
# Depends on:   DOTFILEDIR env var (exported by Taskfile.yml);
#               tasks/install-clear-links.zsh; tasks/messages.zsh.
# Side effects: creates a throwaway tree under mktemp -d, removed via trap.
# =============================================================================

set -euo pipefail

: "${DOTFILEDIR:?DOTFILEDIR must be set (run via task test)}"

source "${DOTFILEDIR}/tasks/messages.zsh"

CLEAR="${DOTFILEDIR}/tasks/install-clear-links.zsh"
failed=0

BASE="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-clear-links-test.XXXXXX")"
trap 'rm -rf "$BASE"' EXIT INT TERM

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
  info "install-clear-links: all checks passed"
else
  error "install-clear-links: ${failed} check(s) failed"
fi
exit "$failed"
