#!/usr/bin/env zsh

# =============================================================================
# install/links-audit-scan.zsh -- symlink orphan detector for links:audit
#
# Purpose:      Single source of orphan-detection logic for `task links:audit`.
#               Reads expected symlink targets on stdin (one per line); takes
#               the repo root and one or more scan roots as args. Prints every
#               orphan symlink path on stdout, one per line, deduplicated.
#               Two orphan kinds, scoped differently because EXPECTED_TARGETS
#               is NOT a complete inventory of repo-managed links (identity
#               git/ssh links are created elsewhere):
#                 A. DANGLING repo-targeted links anywhere under the scan roots.
#                    A dead link whose literal target was under the repo is
#                    always an orphan -- the source it pointed at is gone --
#                    regardless of inventory completeness. (readlink -f returns
#                    empty for these, which is why a resolved-only gate misses
#                    them.) This is the removed-tool case (~/.config/glow).
#                 B. LIVE repo-targeted links that are not expected, but ONLY
#                    under an expected parent dir. Scoped this way so a live
#                    link legitimately owned by another installer (e.g.
#                    ~/.config/git/config) is never misjudged as an orphan.
# Depends on:   readlink, dirname, find, sort (macOS base tools).
# Side effects: none -- read-only; emits orphan paths to stdout.
# =============================================================================

set -euo pipefail

dotfiledir="${1:?usage: links-audit-scan.zsh <repo-root> <scan-root>... < expected}"
shift
roots=("$@")

# Boundary-safe repo prefix. Matching `== "$dotfiledir"*` (raw prefix) would
# treat a sibling like `/Users/josh/dotfiles-backup/x` as repo-targeted when
# the repo root is `/Users/josh/dotfiles`. Compare against the repo root plus a
# trailing slash (strip any existing one first), or the root itself.
repo_root="${dotfiledir%/}"
repo_prefix="${repo_root}/"

# is_under_repo PATH -- true when PATH is the repo root or strictly under it.
is_under_repo() {
  [[ "$1" == "$repo_root" || "$1" == "$repo_prefix"* ]]
}

# Expected targets on stdin (blank lines ignored).
expected=()
while IFS= read -r line; do
  [[ -n "$line" ]] && expected+=("$line")
done

# Parent dirs of expected targets (so deep expected dirs like
# ~/.config/claude/hooks are reached). Deduplicated, word-split-safe -- NOT
# the `array=($(...))` form, which word-splits on spaces in path components.
parent_dirs=()
raw_parents=()
for t in "${expected[@]}"; do
  raw_parents+=("$(dirname -- "$t")")
done
while IFS= read -r dir; do
  [[ -n "$dir" ]] && parent_dirs+=("$dir")
done < <(printf '%s\n' "${raw_parents[@]}" | sort -u)

is_expected() {
  local lnk="$1" e
  for e in "${expected[@]}"; do
    [[ "$lnk" == "$e" ]] && return 0
  done
  return 1
}

already_listed() {
  local lnk="$1" o
  for o in "${orphans[@]}"; do
    [[ "$o" == "$lnk" ]] && return 0
  done
  return 1
}

# Bounded scans (-maxdepth 2): reach whole removed-tool dirs and shallow
# config links without recursing into large trees (e.g. claude plugin cache).
orphans=()

# Pass A -- DANGLING repo-targeted links anywhere under the scan roots.
# `! -e` is true only when the link target does not exist (dangling). Match on
# the LITERAL target (readlink), since readlink -f yields nothing for a dead
# link. No expected-membership filter: a dangling link whose source is gone is
# removable regardless; a dangling EXPECTED link is a broken install that
# links:verify reports, but it is still an orphan to clear here.
for dir in "${roots[@]}"; do
  [[ -d "$dir" ]] || continue
  while IFS= read -r lnk; do
    [[ -z "$lnk" ]] && continue
    [[ -e "$lnk" ]] && continue
    literal="$(readlink "$lnk" 2>/dev/null || true)"
    if is_under_repo "$literal"; then
      already_listed "$lnk" || orphans+=("$lnk")
    fi
  done < <(find "$dir" -maxdepth 2 -type l 2>/dev/null)
done

# Pass B -- LIVE repo-targeted links not in EXPECTED_TARGETS, scoped to
# expected parent dirs (where EXPECTED_TARGETS is the authoritative inventory).
# Match on the RESOLVED target so only live links count; dangling ones were
# handled by pass A.
for dir in "${parent_dirs[@]}"; do
  [[ -d "$dir" ]] || continue
  while IFS= read -r lnk; do
    [[ -z "$lnk" ]] && continue
    resolved="$(readlink -f "$lnk" 2>/dev/null || true)"
    is_under_repo "$resolved" || continue
    if ! is_expected "$lnk" && ! already_listed "$lnk"; then
      orphans+=("$lnk")
    fi
  done < <(find "$dir" -maxdepth 2 -type l 2>/dev/null)
done

if [[ "${#orphans[@]}" -gt 0 ]]; then
  printf '%s\n' "${orphans[@]}"
fi
