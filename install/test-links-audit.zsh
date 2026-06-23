#!/usr/bin/env zsh

# =============================================================================
# install/test-links-audit.zsh -- smoke tests for install/links-audit-scan.zsh
#
# Purpose:      Exercise the orphan detector against a throwaway repo + config
#               tree. Asserts it flags (a) a dangling repo-targeted link
#               anywhere under the roots and (b) a live repo-targeted unexpected
#               link UNDER an expected parent dir, while NOT flagging an
#               expected link, a live non-repo link, a dangling external link,
#               or a live repo link owned by another installer (outside any
#               expected parent dir -- the identity git/ssh case).
# Depends on:   DOTFILEDIR env var (exported by taskfiles/test.yml);
#               install/links-audit-scan.zsh; install/messages.zsh.
# Side effects: creates a throwaway tree under mktemp -d, removed via trap.
# =============================================================================

set -euo pipefail

: "${DOTFILEDIR:?DOTFILEDIR must be set (run via task test:links-audit)}"

# shellcheck source=install/messages.zsh
source "${DOTFILEDIR}/install/messages.zsh"

SCRIPT="${DOTFILEDIR}/install/links-audit-scan.zsh"
failed=0

BASE="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-linksaudit-test.XXXXXX")"
trap 'rm -rf "$BASE"' EXIT INT TERM
# Canonicalize: $TMPDIR may end in `/` (double slash) or be a symlink, which
# would diverge from readlink -f output and break the repo-prefix compare. The
# real repo root ({{.ROOT_DIR}}) is already canonical.
BASE="$(cd "$BASE" && pwd -P)"

repo="${BASE}/repo"
cfg="${BASE}/config"
mkdir -p "${repo}/configs/live" "${cfg}/glow" "${cfg}/git" "${cfg}/keep"
echo x > "${repo}/configs/live/keep.txt"   # real target; configs/gone/* never created

# Orphans we expect to be flagged.
ln -s "${repo}/configs/gone/dead.toml" "${cfg}/glow/dead.toml"    # pass A: dangling, repo-targeted
ln -s "${repo}/configs/live/keep.txt" "${cfg}/keep/sibling.txt"   # pass B: live, repo, unexpected, under expected parent
# Non-orphans we expect to be ignored.
ln -s "${repo}/configs/live/keep.txt" "${cfg}/git/config"         # live, repo, unexpected, but NOT under an expected parent (identity case)
ln -s /etc/hosts "${cfg}/control.conf"                            # live, non-repo
ln -s "${BASE}/nowhere/x" "${cfg}/dead-external.conf"             # dangling, non-repo
ln -s "${repo}/configs/live/keep.txt" "${cfg}/keep/expected.txt"  # repo-targeted but EXPECTED

OUT="$(zsh "$SCRIPT" "$repo" "$cfg" <<< "${cfg}/keep/expected.txt")"

# assert_flagged / assert_absent <label> <path>
assert_flagged() {
  if echo "$OUT" | grep -qxF -- "$2"; then
    check "links-audit.$1"
  else
    cross "links-audit.$1: expected '$2' in output (out=${OUT})"
    failed=$((failed + 1))
  fi
}
assert_absent() {
  if echo "$OUT" | grep -qxF -- "$2"; then
    cross "links-audit.$1: '$2' should NOT be flagged (out=${OUT})"
    failed=$((failed + 1))
  else
    check "links-audit.$1"
  fi
}

assert_flagged "dangling-repo-link"        "${cfg}/glow/dead.toml"
assert_flagged "live-unexpected-in-parent" "${cfg}/keep/sibling.txt"
assert_absent  "live-other-installer"      "${cfg}/git/config"
assert_absent  "live-external-link"        "${cfg}/control.conf"
assert_absent  "dangling-external"         "${cfg}/dead-external.conf"
assert_absent  "expected-link"             "${cfg}/keep/expected.txt"

if (( failed == 0 )); then
  info "links-audit: all checks passed"
else
  error "links-audit: ${failed} check(s) failed"
fi
exit "$failed"
