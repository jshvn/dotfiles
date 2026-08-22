#!/usr/bin/env zsh

# =============================================================================
# install/tests/report.zsh -- smoke test for install/report.zsh
#
# Purpose:      Run the report against a fixture state tree and assert the
#               package table carries one row per `.packages.<manager>.<kind>`
#               in resolved.json with the declared count, including a manager
#               that has no installed-count probe (renders `-`), and that the
#               links section counts converged symlinks.
# Depends on:   DOTFILEDIR env var (exported by taskfiles/test.yml);
#               install/report.zsh; install/messages.zsh; jq.
# Side effects: creates a fixture XDG_STATE_HOME under mktemp -d, removed via
#               trap.
# =============================================================================

set -euo pipefail

: "${DOTFILEDIR:?DOTFILEDIR must be set (run via task test:report)}"

# shellcheck source=install/messages.zsh
source "${DOTFILEDIR}/install/messages.zsh"

BASE="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-report-test.XXXXXX")"
trap 'rm -rf "$BASE"' EXIT INT TERM
STATE="${BASE}/state/dotfiles"
mkdir -p "${STATE}/build" "${BASE}/src"
print fixture > "${STATE}/machine"

cat > "${STATE}/resolved.json" <<'JSON'
{
  "meta": {"description": "fixture"},
  "platform": {"os": "darwin", "arch": "arm64"},
  "features": {"a": true, "b": false, "c": true},
  "packages": {
    "brew": {"formulae": ["x", "y"], "casks": []},
    "future-manager": {"things": ["one", "two", "three"]}
  },
  "claude": {"addons": []}
}
JSON

# Two links: one converged, one pointing elsewhere.
touch "${BASE}/src/a" "${BASE}/src/b"
ln -s "${BASE}/src/a" "${BASE}/link-a"
ln -s "${BASE}/src/b" "${BASE}/link-b"
printf '%s\t%s\n' "${BASE}/link-a" "${BASE}/src/a" "${BASE}/link-b" "${BASE}/src/other" \
  > "${STATE}/build/links.map"

out=$(XDG_STATE_HOME="${BASE}/state" zsh "${DOTFILEDIR}/install/report.zsh")

failed=0
assert_contains() {
  if print -r -- "$out" | ggrep -qF -- "$2"; then
    check "$1"
  else
    cross "$1 -- expected: $2"
    failed=1
  fi
}

assert_contains "machine header"            '| Machine | `fixture` -- fixture |'
assert_contains "feature counts"            '## Features: 2 enabled, 1 disabled'
assert_contains "brew formulae declared"    '| brew | formulae | 2 |'
assert_contains "empty kind still listed"   '| brew | casks | 0 |'
assert_contains "unknown manager renders -" '| future-manager | things | 3 | - |'
assert_contains "links converged count"     '## Links: 1/2 converged'

exit "$failed"
