#!/usr/bin/env zsh

# =============================================================================
# install/tests/packages-trust.zsh -- smoke tests for packages-trust-scan.zsh
#
# Purpose:      Exercise the tap/trust drift detector against fixture inputs.
#               Asserts it flags (a) an installed tap no manifest declares,
#               (b) a trust grant whose tap is undeclared, and (c) a whole-tap
#               grant for an undeclared tap, while NOT flagging a declared tap
#               or a grant belonging to a declared tap.
# Depends on:   DOTFILEDIR env var (exported by taskfiles/test.yml);
#               install/packages-trust-scan.zsh; install/messages.zsh; jq.
# Side effects: creates fixture files under mktemp -d, removed via trap.
# =============================================================================

set -euo pipefail

: "${DOTFILEDIR:?DOTFILEDIR must be set (run via task test:packages-trust)}"

# shellcheck source=install/messages.zsh
source "${DOTFILEDIR}/install/messages.zsh"

SCRIPT="${DOTFILEDIR}/install/packages-trust-scan.zsh"
failed=0

BASE="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-trust-test.XXXXXX")"
trap 'rm -rf "$BASE"' EXIT INT TERM

# Declared: one tap the manifest asked for.
printf 'declared/keep\n' > "${BASE}/declared"

# Installed: the declared one plus a stray.
printf 'declared/keep\nstray/tap\n' > "${BASE}/installed"

# Trust store: a grant for the declared tap (fine), an item grant for the stray
# (stale), and a whole-tap grant for a third tap nobody declared -- the shape a
# CI runner produces when it trusts a preinstalled tap such as aws/tap.
cat > "${BASE}/trust.json" <<'JSON'
{
  "taps": ["runner/preinstalled"],
  "formulae": ["declared/keep/tool"],
  "casks": ["stray/tap/ghost"],
  "commands": []
}
JSON

out=$(zsh "$SCRIPT" "${BASE}/declared" "${BASE}/installed" "${BASE}/trust.json")

# assert_contains <description> <needle>
assert_contains() {
  local desc="$1" needle="$2"
  if printf '%s\n' "$out" | ggrep -qF -- "$needle"; then
    check "$desc"
  else
    cross "$desc -- missing line: ${needle}"
    failed=$(( failed + 1 ))
  fi
}

# assert_absent <description> <needle>
assert_absent() {
  local desc="$1" needle="$2"
  if printf '%s\n' "$out" | ggrep -qF -- "$needle"; then
    cross "$desc -- unexpected line: ${needle}"
    failed=$(( failed + 1 ))
  else
    check "$desc"
  fi
}

assert_contains "flags an undeclared tap" "tap stray/tap: tapped but not declared"
assert_contains "flags a grant for an undeclared tap" "trust casks stray/tap/ghost: granted for undeclared tap stray/tap"
assert_contains "flags a whole-tap grant" "trust tap runner/preinstalled: whole-tap grant for an undeclared tap"
assert_absent   "ignores a declared tap" "tap declared/keep:"
assert_absent   "ignores a grant for a declared tap" "declared/keep/tool"

# Empty inputs are legitimate: a machine may declare no taps and have no trust
# store yet. That must be silent, not a crash.
: > "${BASE}/empty"
if empty_out=$(zsh "$SCRIPT" "${BASE}/empty" "${BASE}/empty" "${BASE}/missing.json" 2>&1) \
  && [[ -z "$empty_out" ]]; then
  check "empty inputs produce no findings"
else
  cross "empty inputs should be silent, got: ${empty_out}"
  failed=$(( failed + 1 ))
fi

if [[ "$failed" -gt 0 ]]; then
  cross "${failed} tap/trust assertion(s) failed"
  exit 1
fi
success "tap/trust drift detection holds"
exit 0
