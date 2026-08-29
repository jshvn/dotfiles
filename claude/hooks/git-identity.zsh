#!/bin/zsh

# =============================================================================
# claude/hooks/git-identity.zsh -- pre-tool hook: block commits made under the
#                                  wrong git identity
#
# Purpose:      Read tool input JSON from stdin (Claude Code hook protocol);
#               block (exit 2) any command that would write a commit whose
#               author or committer email is not the one identity/git assigns
#               to that repository. `git config user.email` is the wrong probe:
#               GIT_AUTHOR_EMAIL and GIT_COMMITTER_EMAIL outrank config, so a
#               config check reads clean while the commit lands under another
#               address. `git var GIT_AUTHOR_IDENT` applies the whole
#               precedence chain, so it is what actually gets recorded. (EMAIL
#               does not outrank a configured user.email, only an absent one.)
# Depends on:   claude/hooks/lib.zsh; jq; git.
# Side effects: writes BLOCKED line to stderr on mismatch.
# =============================================================================

set -euo pipefail
source "${0:A:h}/lib.zsh"

hook::read_stdin

command="$(hook::extract '.tool_input.command // ""')"
[[ -z "$command" ]] && exit 0

# Only commands that write a commit object. rebase, cherry-pick, revert and am
# keep the original author but stamp a fresh committer, so they are in scope.
if [[ ! "$command" =~ 'git[[:space:]]+([^[:space:]]+[[:space:]]+)*(commit|merge|rebase|cherry-pick|revert|am)([[:space:]]|$)' ]]; then
  exit 0
fi

cwd="$(hook::extract '.cwd // ""')"
[[ -n "$cwd" ]] || cwd="$PWD"

repo="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)"
[[ -n "$repo" ]] || exit 0

gitconfig="${XDG_CONFIG_HOME:-$HOME/.config}/git/config"
[[ -f "$gitconfig" ]] || exit 0

# Resolve the identity by reading the same includeIf blocks git itself uses, so
# adding an identity to identity/git/config needs no edit here.
#
# ponytail: prefix match only. Git's gitdir patterns also accept globs; none of
# the identities use one today. If one ever does, replace this loop with
# `git -C "$repo" config --show-origin --get user.email` and read the identity
# from the origin path git reports.
identity_file=""
while IFS= read -r line; do
  [[ -n "$line" ]] || continue
  key="${line%% *}"
  value="${line#* }"
  sub="${key#includeif.}"
  sub="${sub%.path}"

  case "$sub" in
    gitdir/i:*) pattern="${sub#gitdir/i:}"; fold=1 ;;
    gitdir:*)   pattern="${sub#gitdir:}";   fold=0 ;;
    *) continue ;;
  esac
  pattern="${pattern/#\~/$HOME}"

  if (( fold )); then
    [[ "${repo:l}/" == "${pattern:l}"* ]] || continue
  else
    [[ "$repo/" == "$pattern"* ]] || continue
  fi

  case "$value" in
    /*) identity_file="$value" ;;
    *)  identity_file="${gitconfig:h}/$value" ;;
  esac
done < <(git config --file "$gitconfig" --get-regexp '^includeif\.' 2>/dev/null || true)

# No identity covers this path. There is nothing to check the commit against,
# so say nothing -- blocking here would stop every commit outside ~/Git.
[[ -n "$identity_file" ]] || exit 0

# From here the repo IS covered by an identity, so an unreadable identity is a
# failure to verify, not an absence of rules. Fail closed.
if [[ ! -f "$identity_file" ]]; then
  echo "BLOCKED: git identity $identity_file is missing -- cannot verify the commit email" >&2
  exit 2
fi

expected="$(git config -f "$identity_file" user.email 2>/dev/null || true)"
if [[ -z "$expected" ]]; then
  echo "BLOCKED: $identity_file sets no user.email -- cannot verify the commit email" >&2
  exit 2
fi

# "Name <email> 1730000000 +0000" -> "email"
ident_email() {
  local s="${1#*<}"
  print -r -- "${s%%>*}"
}

for role in AUTHOR COMMITTER; do
  ident="$(git -C "$repo" var "GIT_${role}_IDENT" 2>/dev/null || true)"
  if [[ -z "$ident" ]]; then
    echo "BLOCKED: git cannot resolve GIT_${role}_IDENT in $repo" >&2
    exit 2
  fi

  actual="$(ident_email "$ident")"
  if [[ "$actual" != "$expected" ]]; then
    echo "BLOCKED: commit ${role:l} would be <$actual>, but ${identity_file:t} assigns <$expected> to $repo" >&2
    echo "GIT_${role}_EMAIL in the environment outranks git config; check it." >&2
    exit 2
  fi
done

# The command may carry its own override that `git var` cannot see from here,
# as an inline -c or a leading assignment.
inline="$(print -r -- "$command" \
  | sed -nE 's/.*(GIT_AUTHOR_EMAIL|GIT_COMMITTER_EMAIL|user\.email)[[:space:]]*=[[:space:]]*["'\'']?([^"'\''[:space:];]+).*/\2/p' \
  | head -1)"

if [[ -n "$inline" && "$inline" != "$expected" ]]; then
  echo "BLOCKED: this command sets the commit email to <$inline>, but ${identity_file:t} assigns <$expected> to $repo" >&2
  exit 2
fi

exit 0
