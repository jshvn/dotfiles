#!/usr/bin/env zsh

# =============================================================================
# install/packages-trust-scan.zsh -- tap and trust-grant drift detector
#
# Purpose:      Compare the taps a machine is subscribed to, and the entries in
#               its Homebrew trust store, against the taps the manifest
#               declares. Emits one finding per line on stdout; the caller
#               counts them. A tap is a code-execution boundary, so a tap
#               nobody declared -- or a trust grant for one -- is drift.
# Depends on:   jq (>= 1.7); zsh (>= 5). Reads three input files -- declared
#               taps, installed taps, and a trust store in `brew trust --json
#               v1` shape (keys taps/formulae/casks/commands). Runs no brew
#               commands itself so the logic stays testable in isolation.
# Side effects: none. Writes findings to stdout only.
# =============================================================================

set -euo pipefail

if [[ $# -ne 3 ]]; then
  print -u2 "usage: packages-trust-scan.zsh <declared-taps> <installed-taps> <trust-json>"
  exit 2
fi

typeset -r DECLARED_FILE="$1"
typeset -r INSTALLED_FILE="$2"
typeset -r TRUST_FILE="$3"

# Absent inputs are legitimate: a machine may declare no taps, and trust.json
# does not exist until the first grant is made. Treat all three as empty.
declared=""
[[ -s "$DECLARED_FILE" ]] && declared=$(sort -u < "$DECLARED_FILE")
installed=""
[[ -s "$INSTALLED_FILE" ]] && installed=$(sort -u < "$INSTALLED_FILE")

# is_declared <tap>: exact whole-line match against the declared set.
is_declared() {
  [[ -n "$declared" ]] && printf '%s\n' "$declared" | ggrep -qxF -- "$1"
}

# Undeclared taps.
if [[ -n "$installed" ]]; then
  while IFS= read -r tap; do
    [[ -z "$tap" ]] && continue
    is_declared "$tap" || print -r -- "tap ${tap}: tapped but not declared"
  done <<< "$installed"
fi

# Trust grants whose owning tap is undeclared. Item grants are fully qualified
# (<user>/<tap>/<name>); .taps holds bare <user>/<tap> whole-tap grants, which
# cover every current and future item in the tap and so are reported distinctly.
if [[ -s "$TRUST_FILE" ]]; then
  while IFS=$'\t' read -r kind entry; do
    [[ -z "$entry" ]] && continue
    if [[ "$kind" == "taps" ]]; then
      is_declared "$entry" \
        || print -r -- "trust tap ${entry}: whole-tap grant for an undeclared tap"
      continue
    fi
    # Strip the trailing /<name> component to recover <user>/<tap>.
    owning_tap="${entry%/*}"
    is_declared "$owning_tap" \
      || print -r -- "trust ${kind} ${entry}: granted for undeclared tap ${owning_tap}"
  done < <(jq -r 'to_entries[] | .key as $k | .value[]? | [$k, .] | @tsv' "$TRUST_FILE" 2>/dev/null || true)
fi

exit 0
