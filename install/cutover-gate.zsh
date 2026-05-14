#!/bin/zsh
# -----------------------------------------------------------------------------
# install/cutover-gate.zsh -- enforce per-machine cutover-ack sentinel.
#
# Sourced by:
#   - bootstrap.zsh (called BEFORE printing next-step hint)
#   - Taskfile.yml (preconditions: block on `task install`)
#
# Reads: $XDG_STATE_HOME/dotfiles/cutover-ack    (single line: <name> <ts>)
#        $XDG_STATE_HOME/dotfiles/machine        (active machine name)
# Exits: cutover_gate_check returns 1 on missing/invalid/mismatched sentinel
#        cutover_gate_check returns 0 on valid sentinel for active machine
#
# The sentinel WRITER (`task cutover:ack -- <name>`) is owned by Phase 8
# (CUTV-03). P2 only reads/enforces.
#
# Library (sourced, not executed). No `set -euo pipefail` per D-14: this file
# has no execute bit; the shebang above exists for editor syntax highlighting
# only. Every expansion uses `:-` default form so the file is safe under
# caller's `set -u`.
# -----------------------------------------------------------------------------

[[ -n "${DOTFILES_CUTOVER_GATE_LOADED:-}" ]] && return 0
DOTFILES_CUTOVER_GATE_LOADED=1

: "${DOTFILES_MESSAGES_LOADED:=}"
[[ -z "$DOTFILES_MESSAGES_LOADED" ]] && source "${DOTFILEDIR:?}/install/messages.zsh"

cutover_gate_check() {
  local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
  local machine_file="${state_dir}/machine"
  local ack_file="${state_dir}/cutover-ack"
  local active_machine ack_machine ack_ts

  if [[ ! -f "$machine_file" ]]; then
    error "no machine selected (run: task setup -- <machine-name>)"
    return 1
  fi
  active_machine=$(head -n1 "$machine_file" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

  if [[ ! -f "$ack_file" ]]; then
    _cutover_gate_emit_error "$active_machine" "missing"
    return 1
  fi

  # `|| true`: tolerate `read` returning non-zero on empty/EOF so a caller
  # running under `set -e` (bootstrap.zsh) reaches the `[[ -z ]]` check
  # below and emits the actionable "malformed" error per D-09. Without it,
  # an empty ack file silently aborts the function (REVIEW.md C-01).
  read -r ack_machine ack_ts < "$ack_file" || true
  if [[ -z "$ack_machine" || -z "$ack_ts" ]]; then
    _cutover_gate_emit_error "$active_machine" "malformed"
    return 1
  fi

  if [[ "$ack_machine" != "$active_machine" ]]; then
    _cutover_gate_emit_error "$active_machine" "mismatch (sentinel claims '$ack_machine')"
    return 1
  fi

  return 0
}

_cutover_gate_emit_error() {
  local machine="$1"
  local reason="$2"
  {
    echo
    error "machine '${machine}' is not cut over to v2 (${reason})."
    echo
    echo "  This branch is v2-only. v1 lives on master."
    echo "  To cut this machine over, run:"
    echo "    task cutover:ack -- ${machine}"
    echo
    echo "  See docs/CUTOVER.md for the full procedure."
    echo
  } >&2
}
