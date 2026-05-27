#!/usr/bin/env zsh

# =============================================================================
# install/test-repo-sync.zsh -- smoke tests for install/repo-sync.zsh
#
# Purpose:      Exercise every guard branch of the repo-sync fast-forward
#               pull against throwaway git repos: non-repo, detached HEAD,
#               no upstream, dirty tree, up-to-date, behind (clean ff),
#               local-ahead, and diverged. Asserts exit 0 (warn-only) plus
#               the expected message substring on each path.
# Depends on:   DOTFILEDIR env var (exported by taskfiles/test.yml); git;
#               install/repo-sync.zsh; install/messages.zsh.
# Side effects: creates throwaway git repos under mktemp -d (bare "remote"
#               + working clones), removed via EXIT trap. Hermetic git
#               config (GIT_CONFIG_GLOBAL/SYSTEM) so user signing config
#               cannot break test commits.
# =============================================================================

set -euo pipefail

: "${DOTFILEDIR:?DOTFILEDIR must be set (run via task test:repo-sync)}"

# shellcheck source=install/messages.zsh
source "${DOTFILEDIR}/install/messages.zsh"

SCRIPT="${DOTFILEDIR}/install/repo-sync.zsh"
failed=0

BASE="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-reposync-test.XXXXXX")"
trap 'rm -rf "$BASE"' EXIT INT TERM

# Hermetic, deterministic git: no user/system config (signing, pull.rebase,
# etc.) and a fixed identity so commits never prompt or fail.
export GIT_CONFIG_GLOBAL="${BASE}/gitconfig"; : > "$GIT_CONFIG_GLOBAL"
export GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

# run_sync <repo-dir> -> sets OUT (combined stdout+stderr) and CODE.
OUT=""; CODE=0
run_sync() {
  CODE=0
  OUT="$(DOTFILEDIR="$1" zsh "$SCRIPT" 2>&1)" || CODE=$?
}

# assert <label> <expected-substring>; every path must also exit 0.
assert() {
  local label="$1" want="$2"
  if [[ "$CODE" -eq 0 ]] && echo "$OUT" | grep -qi -- "$want"; then
    check "repo-sync.${label}"
  else
    cross "repo-sync.${label}: expected exit 0 + '${want}' (exit=${CODE}, out=${OUT})"
    failed=$((failed + 1))
  fi
}

# mk_pair <bare> <work>: bare "remote" + working clone, both at one commit (A)
# on branch main, with upstream tracking configured.
mk_pair() {
  local bare="$1" work="$2"
  git init -q --bare -b main "$bare"
  git -c init.defaultBranch=main clone -q "$bare" "$work" 2>/dev/null  # silence empty-repo notice
  git -C "$work" checkout -q -B main
  echo seed > "$work/file"
  git -C "$work" add file
  git -C "$work" commit -q -m A
  git -C "$work" push -q -u origin main
}

# advance_remote <bare>: push one extra commit (B) to the bare remote via a
# throwaway clone, so a working clone left at A is now strictly behind.
advance_remote() {
  local bare="$1" c2; c2="$(mktemp -d "${BASE}/clone.XXXXXX")"
  git -c init.defaultBranch=main clone -q "$bare" "$c2"
  echo more >> "$c2/file"
  git -C "$c2" add file
  git -C "$c2" commit -q -m B
  git -C "$c2" push -q origin main
  rm -rf "$c2"
}

# 1. Not a git repo.
mkdir -p "${BASE}/plain"
run_sync "${BASE}/plain"
assert "not-a-repo" "not a git repo"

# 2. Detached HEAD.
det="${BASE}/detached"
git init -q -b main "$det"
echo x > "$det/file"; git -C "$det" add file; git -C "$det" commit -q -m A
git -C "$det" checkout -q --detach
run_sync "$det"
assert "detached-head" "detached HEAD"

# 3. No upstream remote.
noup="${BASE}/noupstream"
git init -q -b main "$noup"
echo x > "$noup/file"; git -C "$noup" add file; git -C "$noup" commit -q -m A
run_sync "$noup"
assert "no-upstream" "no upstream"

# 4. Dirty working tree.
dirty_bare="${BASE}/dirty.git"; dirty="${BASE}/dirty"
mk_pair "$dirty_bare" "$dirty"
echo localedit >> "$dirty/file"  # uncommitted change
run_sync "$dirty"
assert "dirty-tree" "uncommitted local changes"

# 5. Clean and current -> already up to date.
cur_bare="${BASE}/current.git"; cur="${BASE}/current"
mk_pair "$cur_bare" "$cur"
run_sync "$cur"
assert "up-to-date" "already up to date"

# 6. Behind by a clean fast-forward.
ff_bare="${BASE}/ff.git"; ff="${BASE}/ff"
mk_pair "$ff_bare" "$ff"
advance_remote "$ff_bare"
run_sync "$ff"
assert "fast-forward" "dotfiles updated to"
# HEAD must now equal the fetched upstream tip.
if [[ "$(git -C "$ff" rev-parse HEAD)" == "$(git -C "$ff" rev-parse '@{u}')" ]]; then
  check "repo-sync.fast-forward.head-moved"
else
  cross "repo-sync.fast-forward.head-moved: HEAD != upstream after ff"
  failed=$((failed + 1))
fi

# 7. Local ahead of remote -> nothing to pull.
ahead_bare="${BASE}/ahead.git"; ahead="${BASE}/ahead"
mk_pair "$ahead_bare" "$ahead"
echo c >> "$ahead/file"; git -C "$ahead" add file; git -C "$ahead" commit -q -m C
run_sync "$ahead"
assert "local-ahead" "ahead of remote"

# 8. Diverged (local commit + different remote commit on common base).
div_bare="${BASE}/div.git"; div="${BASE}/div"
mk_pair "$div_bare" "$div"
echo c >> "$div/file"; git -C "$div" add file; git -C "$div" commit -q -m C
advance_remote "$div_bare"
run_sync "$div"
assert "diverged" "diverged"

exit "$failed"
