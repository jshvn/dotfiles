#!/bin/zsh
# os/defaults/_apply_verify.zsh -- shared apply / verify helpers for the
# os/defaults/<concern>.zsh family.
#
# Purpose:
#   The per-concern files (dock.zsh, finder.zsh, input.zsh, screenshots.zsh,
#   security.zsh) all declare a tuple-stride-4 array of macOS defaults keys
#   and previously hand-rolled near-identical apply_<concern> / verify_<concern>
#   loops that differed only in the array name, the killall target, and the
#   scope flag. This file extracts those loops into two parameterized helpers
#   (rule-of-three; 5 sites > threshold).
#
# Caller:
#   Each os/defaults/<concern>.zsh file sources this helper, then implements
#   its public apply_<concern> / verify_<concern> entry points as thin wrappers
#   around _apply_defaults / _verify_defaults. The taskfiles/macos.yml task
#   surface is unchanged -- it still invokes apply_<concern> and
#   verify_<concern> by name.
#
# Functions:
#   _apply_defaults <ARRAY_NAME> [<KILLALL_TARGET>] [<SCOPE_FLAG>]
#     Iterates the named tuple-stride-4 array and writes each key via
#     `defaults [SCOPE_FLAG] write <domain> <key> -<type> <value>`. After
#     all writes, runs `killall <KILLALL_TARGET>` if KILLALL_TARGET is set
#     (`|| true` so headless / pre-launch machines do not abort the script
#     when the UI process is not running -- RESEARCH Pitfall 5).
#
#     SCOPE_FLAG (3rd arg) is "" (global, the default) or "-currentHost"
#     (per-host plist; RESEARCH Pitfall 3 -- reads/writes to per-host plists
#     must use the matching scope flag or the value is invisible to the
#     loop). When SCOPE_FLAG is "-currentHost", the same flag is used by
#     _verify_defaults below for the read side.
#
#     Literal `$HOME` tokens embedded in tuple values are expanded via narrow
#     substitution (`${value/\$HOME/$HOME}`); the (e)-flag was rejected
#     because it performs command substitution and would be a code-exec sink
#     if a future concern starts sourcing tuple values from external data.
#
#   _verify_defaults <ARRAY_NAME> <CONCERN_LABEL> [<SCOPE_FLAG>]
#     Iterates the named tuple-stride-4 array and reads each key via
#     `defaults [SCOPE_FLAG] read <domain> <key>`. Normalizes booleans (true/
#     false -> 1/0 -- RESEARCH Pitfall 2 round-trip) before comparing
#     against the expected value. Emits `check` / `cross` messages prefixed
#     with `<CONCERN_LABEL>.<key>`; when SCOPE_FLAG is "-currentHost",
#     appends ` (currentHost)` to messages so converged-state logs are
#     unambiguous. Returns the count of failures (0 on full convergence).
#
# Contract:
#   Sourced-only. Carries `set -euo pipefail` by v2 convention (CF-06) even
#   though sourced files are technically exempt from LINT-04.
#   Expects messages.zsh to already be sourced by the caller (check / cross
#   functions must be defined). Expects $DOTFILEDIR to be exported by the
#   ultimate task heredoc (the per-concern files assert it via `:?`).

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
    # bool round-trip normalization (RESEARCH Pitfall 2).
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
