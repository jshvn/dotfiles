#!/bin/zsh

# =============================================================================
# apps/git/functions/cloneall.zsh -- git cloneall: clone every repo an owner has
#
# Purpose:      `git cloneall <owner>` clones each repository of a GitHub user
#               or org into the directory it is typed in, over SSH, and skips
#               each name already there.
# Depends on:   gh, logged in (it lists private repos too); git; an SSH key
#               GitHub accepts.
# Side effects: clones into the current directory.
# =============================================================================

set -euo pipefail

# git runs an alias from the repository's top level; GIT_PREFIX leads back to where it was typed
cd "${GIT_PREFIX:-.}"

usage() {
  cat <<EOF
usage: git cloneall <owner>

Clones every repository of a GitHub user or org into this directory, one
folder per repository.

  into     $PWD/<repo>
  lists    gh repo list <owner>: every repo your gh login can see, private,
           forks and archived included, up to 1000
  clones   git@github.com:<owner>/<repo>.git, over SSH
  skips    a repo when anything named <repo> is already here; it is not
           fetched or changed

Prints cloned, skipped or failed for each repo; exits 1 if any clone failed.

example: cd ~/Git/katoptra && git cloneall katoptra
EOF
}

case ${1:-} in
  -h) usage; exit 0 ;;
  '' | -*) usage >&2; exit 1 ;;
esac
owner=$1

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
