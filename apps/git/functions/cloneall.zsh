#!/bin/zsh

# =============================================================================
# apps/git/functions/cloneall.zsh -- git cloneall: clone every repo an owner has
#
# Purpose:      `git cloneall <owner>` clones each repository of a GitHub user
#               or org into the directory it is typed in, over SSH like every
#               other clone, and skips each name already there.
# Depends on:   gh, logged in (it lists private repos too); git; the 1Password
#               SSH agent.
# Side effects: clones into the current directory.
# =============================================================================

set -euo pipefail

owner=${1:?usage: git cloneall <owner>}
# git runs an alias from the repository's top level; GIT_PREFIX leads back to where it was typed
cd "${GIT_PREFIX:-.}"

# ponytail: one list call capped at 1000 repos; raise --limit past that
repos=$(gh repo list "$owner" --limit 1000 --json name --jq '.[].name')
failed=0
for name in ${(f)repos}; do
  if [[ -e $name ]]; then
    print "  skipped  $name"
    continue
  fi
  if git clone --quiet "git@github.com:$owner/$name.git"; then
    print "  cloned   $name"
  else
    print -u2 "  failed   $name"
    failed=1
  fi
done
exit $failed
