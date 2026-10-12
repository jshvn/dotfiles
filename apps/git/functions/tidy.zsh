#!/bin/zsh

# =============================================================================
# apps/git/functions/tidy.zsh -- git tidy: delete local branches GitHub merged
#
# Purpose:      `git tidy` deletes each local branch whose upstream is gone and
#               whose tip is the head of a merged pull request. It skips a
#               branch checked out in a worktree, one with no merged PR, and
#               one with commits past the PR.
# Depends on:   gh, logged in; git.
# Side effects: fetches with --prune; deletes local branches.
# =============================================================================

set -euo pipefail

command -v gh >/dev/null || { print -u2 'tidy: gh not installed'; exit 1; }
git fetch --prune --quiet || print -u2 'tidy: fetch failed, using cached state'

deleted=0
skipped=0
# zsh runs the last stage of a pipeline in this shell, so the counts outlive the loop
git for-each-ref --format='%(refname:short) %(upstream:track) %(worktreepath)' refs/heads |
  while read -r branch track worktree; do
    [[ $track == '[gone]' ]] || continue
    if [[ -n $worktree ]]; then
      printf '  skipped  %-34s checked out at %s\n' "$branch" "$worktree"
      skipped=$((skipped + 1))
      continue
    fi
    pr=$(gh pr list --head "$branch" --state merged --json number,headRefOid \
      --jq '.[] | [.number, .headRefOid] | join(" ")' 2>/dev/null | tail -1) || true
    if [[ -z $pr ]]; then
      printf '  skipped  %-34s no merged PR found\n' "$branch"
      skipped=$((skipped + 1))
      continue
    fi
    num=${pr%% *}
    head=${pr##* }
    if [[ $head != "$(git rev-parse "$branch")" ]]; then
      ahead=$(git rev-list --count "$head..$branch" 2>/dev/null) || ahead=0
      printf '  skipped  %-34s %s ahead of merged PR #%s\n' "$branch" "$ahead" "$num"
      skipped=$((skipped + 1))
      continue
    fi
    if git branch -D "$branch" >/dev/null; then
      printf '  deleted  %-34s PR #%s\n' "$branch" "$num"
      deleted=$((deleted + 1))
    fi
  done
print "$deleted deleted, $skipped skipped"
