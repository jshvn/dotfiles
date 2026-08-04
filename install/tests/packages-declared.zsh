#!/usr/bin/env zsh

# =============================================================================
# install/tests/packages-declared.zsh -- smoke tests for declared-set extraction
#
# Purpose:      Pin the `brew bundle list --<type>` contract that
#               packages:audit and packages:diff rely on. Asserts each type
#               flag returns exactly the declared entries, and pins the
#               asymmetry where a tap-qualified formula lists as its full
#               name while a tap-qualified cask lists as its leaf token.
# Depends on:   DOTFILEDIR env var (exported by taskfiles/test.yml); brew
#               (>= 6.0); install/messages.zsh.
# Side effects: creates a throwaway Brewfile under mktemp -d, removed via trap.
# =============================================================================

set -euo pipefail

: "${DOTFILEDIR:?DOTFILEDIR must be set (run via task test:packages-declared)}"

# shellcheck source=install/messages.zsh
source "${DOTFILEDIR}/install/messages.zsh"

if ! command -v brew >/dev/null 2>&1; then
  warn "brew not on PATH -- skipping declared-set smoke tests"
  exit 0
fi

failed=0

BASE="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-declared-test.XXXXXX")"
trap 'rm -rf "$BASE"' EXIT INT TERM

bf="${BASE}/Brewfile"
cat > "$bf" <<'FIXTURE'
brew 'git'
brew 'oven-sh/bun/bun'
cask 'firefox'
cask 'wouterdebie/tap/davit'
mas 'Magnet', id: 441258766
vscode 'biomejs.biome'
npm 'typescript'
FIXTURE

# assert_set <label> <type-flag> <expected-newline-separated>
assert_set() {
  local label="$1" flag="$2" expected="$3" actual
  actual=$(brew bundle list "$flag" --file="$bf" 2>/dev/null | sort -u || true)
  if [[ "$actual" == "$(printf '%s' "$expected" | sort -u)" ]]; then
    check "declared ${label}: ${actual//$'\n'/, }"
  else
    cross "declared ${label}: expected [${expected//$'\n'/, }], got [${actual//$'\n'/, }]"
    failed=$(( failed + 1 ))
  fi
}

# Formulae list as their FULL name when tap-qualified; this matches `brew leaves`.
assert_set formulae --formulae "$(printf 'git\noven-sh/bun/bun')"
# Casks list as their LEAF token when tap-qualified; this matches `brew list --cask`.
assert_set casks --casks "$(printf 'davit\nfirefox')"
# mas lists NAMES, not ids -- which is why packages:audit keeps a grep for mas.
assert_set mas --mas 'Magnet'
assert_set vscode --vscode 'biomejs.biome'
assert_set npm --npm 'typescript'

if [[ "$failed" -gt 0 ]]; then
  cross "${failed} declared-set assertion(s) failed"
  exit 1
fi
success "declared-set extraction contract holds"
exit 0
