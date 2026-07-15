#!/bin/zsh

# =============================================================================
# install/repo-sync.zsh -- fast-forward the dotfiles repo from its remote
#
# Purpose:      Pull the latest dotfiles before install (the `update` alias
#               runs this, then `task install`, in two processes). Fetches
#               then fast-forwards the current branch; never merges, rebases,
#               or clobbers local work.
# Depends on:   DOTFILEDIR env var (the repo to pull; exported by
#               taskfiles/repo.yml); git; install/messages.zsh (sourced
#               relative to this script, NOT from DOTFILEDIR, so the repo
#               under operation is decoupled from the library location).
# Side effects: at most a `git merge --ff-only` of the working tree to the
#               upstream tip. No-op (warn + exit 0) on non-repo, detached
#               HEAD, no upstream, dirty tree, offline/auth failure, or
#               divergence. Writes one mktemp scratch file (trap-removed).
# =============================================================================

set -euo pipefail

: "${DOTFILEDIR:?DOTFILEDIR must be set (run via task repo:sync)}"

# Source the messaging library from this script's own directory (${0:A:h}),
# so DOTFILEDIR is free to point at any repo (notably the throwaway repos in
# install/test-repo-sync.zsh).
# shellcheck source=install/messages.zsh
source "${0:A:h}/messages.zsh"

repo="${DOTFILEDIR}"

# Every guard below is warn-and-skip with `exit 0`: the `update` alias chains
# `task repo:sync && task install`, so a skipped/failed pull must still let
# install converge local state (including offline).

# 1. Is it a git repo at all? (Covers "don't already have the repo"; the
#    initial clone is bootstrap's job per README, not the update path.)
if ! git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  warn "dotfiles dir is not a git repo (${repo}); skipping pull"
  exit 0
fi

# 2. On a branch? A detached HEAD has nowhere to fast-forward.
branch="$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
if [[ -z "$branch" ]]; then
  warn "detached HEAD; skipping pull (checkout a branch to enable auto-update)"
  exit 0
fi

# 3. Upstream tracking branch configured?
if ! git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
  warn "branch '${branch}' has no upstream remote; skipping pull"
  exit 0
fi

# 4. Clean working tree? Never pull over uncommitted local edits.
if [[ -n "$(git -C "$repo" status --porcelain 2>/dev/null || true)" ]]; then
  warn "uncommitted local changes; skipping pull to avoid clobbering work"
  exit 0
fi

# 5. Fetch. Network/auth errors surface here. Disable credential prompts and
#    cap the SSH handshake so a missing/locked/invalid key or a dead network
#    fails fast instead of hanging or blocking on a passphrase prompt.
step "fetching latest dotfiles..."
fetch_err="$(mktemp "${TMPDIR:-/tmp}/dotfiles-fetch.XXXXXX")"
trap 'rm -f "$fetch_err"' EXIT INT TERM
if ! GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=10' \
     git -C "$repo" fetch --quiet 2>"$fetch_err"; then
  warn "git fetch failed (offline, or missing/invalid SSH key?); skipping pull"
  [[ -s "$fetch_err" ]] && warn "  $(tail -n1 "$fetch_err")"
  exit 0
fi

# 6. Compare local HEAD, upstream tip, and their merge base.
local_rev="$(git -C "$repo" rev-parse HEAD 2>/dev/null || true)"
remote_rev="$(git -C "$repo" rev-parse '@{u}' 2>/dev/null || true)"
base_rev="$(git -C "$repo" merge-base HEAD '@{u}' 2>/dev/null || true)"

if [[ "$local_rev" == "$remote_rev" ]]; then
  info "dotfiles already up to date"
  exit 0
fi
if [[ "$remote_rev" == "$base_rev" ]]; then
  info "local branch is ahead of remote; nothing to pull"
  exit 0
fi
if [[ "$local_rev" != "$base_rev" ]]; then
  warn "local and remote have diverged; resolve manually (git -C ${repo} pull --rebase)"
  exit 0
fi

# 7. Behind by a clean fast-forward only.
step "fast-forwarding ${branch}..."
if git -C "$repo" merge --ff-only --quiet '@{u}'; then
  # Most recent tag reachable from HEAD (not necessarily on HEAD); empty if
  # the repo has no tags yet.
  latest_tag="$(git -C "$repo" describe --tags --abbrev=0 2>/dev/null || true)"
  success "dotfiles updated to $(git -C "$repo" rev-parse --short HEAD)${latest_tag:+ (latest release ${latest_tag})}"
else
  warn "fast-forward failed; resolve manually (git -C ${repo} status)"
fi
exit 0
