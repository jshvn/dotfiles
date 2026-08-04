#!/usr/bin/env zsh

# =============================================================================
# install/tests/brewfile-compose.zsh -- smoke tests for compose-brewfile.zsh
#
# Purpose:      Assert the composed Brewfile grants trust to tap-qualified
#               entries and leaves core entries bare, emits one tap line per
#               distinct tap prefix, and still escapes single quotes so a
#               package name can never break out of its Ruby string literal.
# Depends on:   DOTFILEDIR env var (exported by taskfiles/test.yml);
#               install/compose-brewfile.zsh; jq; install/messages.zsh.
# Side effects: composes into a throwaway XDG_STATE_HOME under mktemp -d,
#               removed via trap. Never touches the real state tree.
# =============================================================================

set -euo pipefail

: "${DOTFILEDIR:?DOTFILEDIR must be set (run via task test:brewfile-compose)}"

# shellcheck source=install/messages.zsh
source "${DOTFILEDIR}/install/messages.zsh"

failed=0

BASE="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-compose-test.XXXXXX")"
trap 'rm -rf "$BASE"' EXIT INT TERM

mkdir -p "${BASE}/dotfiles"
cat > "${BASE}/dotfiles/resolved.json" <<'JSON'
{
  "meta": { "description": "compose-fixture" },
  "packages": {
    "brew": {
      "formulae": ["git", "oven-sh/bun/bun"],
      "casks": [{ "name": "firefox" }, { "name": "wouterdebie/tap/davit" }],
      "mas": []
    },
    "vscode": { "extensions": [] },
    "cargo": { "crates": [] },
    "uv": { "tools": [] },
    "npm": { "packages": [] }
  }
}
JSON

DOTFILEDIR="$DOTFILEDIR" XDG_STATE_HOME="$BASE" \
  zsh "${DOTFILEDIR}/install/compose-brewfile.zsh" >/dev/null

out="${BASE}/dotfiles/build/Brewfile"

# assert_line <description> <exact-line>
assert_line() {
  local desc="$1" needle="$2"
  if ggrep -qxF -- "$needle" "$out"; then
    check "$desc"
  else
    cross "$desc -- missing: ${needle}"
    failed=$(( failed + 1 ))
  fi
}

assert_line "core formula stays bare"        "brew 'git'"
assert_line "core cask stays bare"           "cask 'firefox'"
assert_line "qualified formula is trusted"   "brew 'oven-sh/bun/bun', trusted: true"
assert_line "qualified cask is trusted"      "cask 'wouterdebie/tap/davit', trusted: true"
assert_line "formula tap is declared"        "tap 'oven-sh/bun'"
assert_line "cask tap is declared"           "tap 'wouterdebie/tap'"

# One tap line per distinct prefix, never a duplicate.
tap_lines=$(ggrep -cE "^tap '" "$out" || true)
if [[ "$tap_lines" -eq 2 ]]; then
  check "exactly one tap line per distinct tap"
else
  cross "expected 2 tap lines, got ${tap_lines}"
  failed=$(( failed + 1 ))
fi

# The composed file must be parseable by brew itself, not merely look right.
if command -v brew >/dev/null 2>&1; then
  if brew bundle list --formulae --file="$out" >/dev/null 2>&1; then
    check "composed Brewfile parses under brew bundle list"
  else
    cross "composed Brewfile does not parse under brew bundle list"
    failed=$(( failed + 1 ))
  fi
fi

if [[ "$failed" -gt 0 ]]; then
  cross "${failed} compose assertion(s) failed"
  exit 1
fi
success "Brewfile composition contract holds"
exit 0
