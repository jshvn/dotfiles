#!/bin/zsh

# =============================================================================
# os/defaults/_apply_verify.zsh -- shared apply/verify loop for os/defaults/*
#
# Purpose:      Parameterized helpers _apply_defaults and _verify_defaults
#               iterate a tuple-stride-4 array (domain, key, value, type) to
#               write or read macOS `defaults`. Accepts an optional killall
#               target (post-write UI restart) and an optional scope flag
#               ("" or "-currentHost"). Verify normalizes bool round-trip
#               ("true"/"false" vs "1"/"0") before comparison.
# Depends on:   defaults, killall (optional); install/messages.zsh check/
#               cross must already be sourced; $DOTFILEDIR exported.
# Side effects: _apply_defaults writes to macOS user defaults and may kill
#               UI processes; _verify_defaults emits check/cross to stderr
#               and returns 0 on full convergence, 1 otherwise.
# =============================================================================

set -euo pipefail

_apply_defaults() {
  local array_name="$1"
  local killall_target="${2:-}"
  local scope_flag="${3:-}"
  local -a arr
  # Indirect array expansion (zsh `(P)` flag): read the array whose name
  # is held in $array_name. Equivalent to bash `${!array_name}` for arrays.
  arr=("${(@P)array_name}")
  local i domain key value type expanded
  for ((i = 1; i <= ${#arr[@]}; i += 4)); do
    domain="${arr[$i]}"
    key="${arr[$((i + 1))]}"
    value="${arr[$((i + 2))]}"
    type="${arr[$((i + 3))]}"
    # Narrow substitution: literal $HOME token only. Avoids the (e)-flag
    # command-exec sink documented in the screenshots.zsh prior implementation.
    expanded="${value/\$HOME/$HOME}"
    if [[ -n "$scope_flag" ]]; then
      defaults "$scope_flag" write "$domain" "$key" "-${type}" "$expanded"
    else
      defaults write "$domain" "$key" "-${type}" "$expanded"
    fi
  done
  if [[ -n "$killall_target" ]]; then
    killall "$killall_target" 2>/dev/null || true
  fi
}

_verify_defaults() {
  local array_name="$1"
  local concern_label="$2"
  local scope_flag="${3:-}"
  local -a arr
  arr=("${(@P)array_name}")
  local i domain key value type current expected_read failed=0 expanded
  local suffix=""
  [[ -n "$scope_flag" ]] && suffix=" (${scope_flag#-})"
  for ((i = 1; i <= ${#arr[@]}; i += 4)); do
    domain="${arr[$i]}"
    key="${arr[$((i + 1))]}"
    value="${arr[$((i + 2))]}"
    type="${arr[$((i + 3))]}"
    expanded="${value/\$HOME/$HOME}"
    if [[ -n "$scope_flag" ]]; then
      current=$(defaults "$scope_flag" read "$domain" "$key" 2>/dev/null || echo "<unset>")
    else
      current=$(defaults read "$domain" "$key" 2>/dev/null || echo "<unset>")
    fi
    # bool round-trip normalization: defaults read returns "1"/"0" for bools.
    case "$type" in
      bool) [[ "$expanded" == "true" ]] && expected_read="1" || expected_read="0" ;;
      *)    expected_read="$expanded" ;;
    esac
    if [[ "$current" == "$expected_read" ]]; then
      check "${concern_label}.$key = $expanded${suffix}"
    else
      cross "${concern_label}.$key: expected '$expected_read', got '$current'${suffix}"
      failed=1
    fi
  done
  return $failed
}
