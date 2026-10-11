#!/usr/bin/env zsh

# =============================================================================
# tasks/tests/vscode-vsix.zsh -- smoke tests for apps/vscode/vsix.zsh
#
# Purpose:      Against a throwaway bare remote committing title-buttons.vsix
#               and a fake `code` that records installs: an extension not
#               installed is installed from the VSIX; the same version
#               installed is left alone; another version is replaced; an
#               unreachable remote exits non-zero.
# Depends on:   DOTFILEDIR env var (exported by Taskfile.yml);
#               apps/vscode/vsix.zsh; tasks/messages.zsh; git; zip; unzip; jq.
# Side effects: creates a sandbox under mktemp -d, removed via trap.
# =============================================================================

set -euo pipefail

: "${DOTFILEDIR:?DOTFILEDIR must be set (run via task test)}"
source "${DOTFILEDIR}/tasks/messages.zsh"

typeset -i failures=0
sandbox=$(mktemp -d "${TMPDIR:-/tmp}/vscode-vsix-test.XXXXXX")
trap 'rm -rf "$sandbox"' EXIT INT TERM

remote="${sandbox}/remote.git"
seed="${sandbox}/seed"
script="${DOTFILEDIR}/apps/vscode/vsix.zsh"

mkdir -p "$sandbox/bin" "$sandbox/src/extension" "$seed"
print '{"version": "0.2.0"}' > "$sandbox/src/extension/package.json"
(cd "$sandbox/src" && zip -q -r "$seed/title-buttons.vsix" extension)
git init -q -b main "$seed"
git -C "$seed" add title-buttons.vsix
git -C "$seed" -c user.name=t -c user.email=t@t commit -q -m "vsix"
git init -q --bare -b main "$remote"  # the clone checks out HEAD, whatever init.defaultBranch says
git -C "$seed" push -q "$remote" main

# the fake code lists $sandbox/installed and appends each install's VSIX name to $sandbox/calls
print -r -- '#!/bin/sh
case "$1" in
  --list-extensions) cat "$SANDBOX/installed" ;;
  --install-extension) basename "$2" >> "$SANDBOX/calls" ;;
esac' > "$sandbox/bin/code"
chmod +x "$sandbox/bin/code"

run() {
  print -r -- "$1" > "$sandbox/installed"
  : > "$sandbox/calls"
  SANDBOX="$sandbox" PATH="$sandbox/bin:$PATH" zsh "$script" jshvn.title-buttons "${2:-$remote}" >/dev/null 2>&1
}

# 1. Not installed: installed from the VSIX at the repo root.
if run "" && [[ "$(<"$sandbox/calls")" == "title-buttons.vsix" ]]; then
  check "an extension not installed is installed from <name>.vsix"
else
  cross "an extension not installed was not installed from title-buttons.vsix"
  failures=$(( failures + 1 ))
fi

# 2. Same version installed (code lists ids in their own case): left alone.
if run "JSHVN.Title-Buttons@0.2.0" && [[ ! -s "$sandbox/calls" ]]; then
  check "the version inside the VSIX, already installed, is left alone"
else
  cross "the installed version was reinstalled"
  failures=$(( failures + 1 ))
fi

# 3. Another version installed: replaced.
if run "jshvn.title-buttons@0.3.0" && [[ "$(<"$sandbox/calls")" == "title-buttons.vsix" ]]; then
  check "another installed version is replaced by the VSIX"
else
  cross "another installed version was not replaced"
  failures=$(( failures + 1 ))
fi

# 4. Unreachable remote: non-zero, so the activation step warns.
if ! run "" "${sandbox}/missing.git" && [[ ! -s "$sandbox/calls" ]]; then
  check "an unreachable remote fails without installing"
else
  cross "an unreachable remote did not fail cleanly"
  failures=$(( failures + 1 ))
fi

if (( failures == 0 )); then
  success "vscode-vsix: all scenarios passed"
else
  error "vscode-vsix: ${failures} scenario(s) failed"
fi
exit "$failures"
