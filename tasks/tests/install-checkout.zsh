#!/usr/bin/env zsh

# =============================================================================
# tasks/tests/install-checkout.zsh -- smoke test for the clone guard in tasks/install.zsh
#
# Purpose:      Asserts that tasks/install.zsh stops before the build when it
#               runs from a clone other than dotfiles.checkout, and reaches
#               the build when it runs from that clone through a symlink.
# Depends on:   DOTFILEDIR env var (exported by Taskfile.yml); jq;
#               tasks/install.zsh; tasks/messages.zsh.
# Side effects: creates throwaway directories and a fake nix under
#               mktemp -d, removed via EXIT trap.
# =============================================================================

set -euo pipefail

: "${DOTFILEDIR:?DOTFILEDIR must be set (run via task test)}"

# shellcheck source=tasks/messages.zsh
source "${DOTFILEDIR}/tasks/messages.zsh"

SCRIPT="${DOTFILEDIR}/tasks/install.zsh"
failed=0

BASE="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-checkout-test.XXXXXX")"
trap 'rm -rf "$BASE"' EXIT INT TERM
mkdir "${BASE}/clone" "${BASE}/other"
ln -s "${BASE}/clone" "${BASE}/link"
printf '#!/bin/sh\necho fake-nix-build\nexit 1\n' > "${BASE}/nix"
chmod +x "${BASE}/nix"

# expect <label> <run-from> <checkout> <substring>: install.zsh exits nonzero either way (the
# guard, or the fake build), so the output says which one stopped it
expect() {
  local out
  out="$(DOTFILEDIR="$2" MACHINE=test NIX="${BASE}/nix" zsh "$SCRIPT" \
    <<< "{\"dotfiles\": {\"checkout\": \"$3\"}}" 2>&1)" || true
  if [[ "$out" == *"$4"* ]]; then
    check "install-checkout.$1"
  else
    cross "install-checkout.$1: expected '$4' (out=${out})"
    failed=$((failed + 1))
  fi
}

expect other-clone "${BASE}/other" "${BASE}/clone" "dotfiles.checkout is ${BASE}/clone"
expect symlinked-clone "${BASE}/link" "${BASE}/clone" fake-nix-build

exit "$failed"
