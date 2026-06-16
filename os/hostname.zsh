#!/bin/zsh

# =============================================================================
# os/hostname.zsh -- per-machine hostname apply / verify / state-file library
#
# Purpose:      Provide apply_hostname / verify_hostname plus state-file
#               helpers (read/write/path) keyed on
#               $XDG_STATE_HOME/dotfiles/hostname. File presence gates the
#               install-time apply step; contents are the authoritative value.
# Depends on:   install/messages.zsh; $DOTFILEDIR exported by caller
#               (taskfiles/hostname.yml heredoc, or interactive shell function
#               sethostname). macOS scutil + defaults (gated by callers).
# Side effects: apply_hostname runs three sudo commands (scutil ComputerName /
#               HostName / LocalHostName). NetBIOSName is deliberately NOT
#               managed -- macOS derives it from the reverse-DNS PTR record at
#               SMB-init and reverts any local write within ~15s.
#               write_hostname_state_file writes the state file atomically
#               via mktemp + mv. read / verify / validate helpers are
#               read-only.
# =============================================================================

set -euo pipefail

# messages.zsh self-guards under set -u via the `:-` default expansion on
# $DOTFILES_MESSAGES_LOADED; a bare source is sufficient and idempotent.
: "${DOTFILEDIR:?DOTFILEDIR not set -- run via 'task hostname:*' or source from your shell rc}"
source "${DOTFILEDIR}/install/messages.zsh"

# Apple LocalHostName regex: ASCII letters, digits, hyphens; no leading hyphen.
# An empty name is rejected with its own dedicated error before the regex
# check so the operator sees "hostname is required" instead of a confusing
# regex-mismatch message.
typeset -r HOSTNAME_NAME_RE='^[A-Za-z0-9][A-Za-z0-9-]*$'

validate_hostname_name() {
  local name="${1:-}"
  if [[ -z "$name" ]]; then
    error "hostname is required"
    return 1
  fi
  if ! [[ "$name" =~ $HOSTNAME_NAME_RE ]]; then
    error "invalid hostname: '${name}' (must match ${HOSTNAME_NAME_RE} -- ASCII letters, digits, hyphens; no leading hyphen)"
    return 1
  fi
  return 0
}

# read_local_hostname -- echo `scutil --get LocalHostName` (already trimmed by
# scutil). Returns the scutil exit status verbatim so callers can branch on a
# missing/unset LocalHostName the same way they would on any other live-read
# failure.
read_local_hostname() {
  scutil --get LocalHostName 2>/dev/null
}

# apply_hostname <name> -- validate then run the three canonical hostname
# writes. Sudo password prompts are left to sudo's controlling tty (no
# redirection); a single sudo timestamp covers all three calls when the
# caller invokes apply_hostname once. NetBIOSName is intentionally omitted:
# macOS derives it from the reverse-DNS PTR record and reverts any
# `defaults write` to com.apple.smb.server within ~15s, so managing it here
# only produces dishonest "applied" output. Change the PTR record to rename
# the NetBIOS name.
apply_hostname() {
  local name="${1:-}"
  validate_hostname_name "$name" || return 1
  sudo scutil --set ComputerName  "$name"
  sudo scutil --set HostName      "$name"
  sudo scutil --set LocalHostName "$name"
  success "hostname applied: ${name}"
}

# verify_hostname <name> -- silent comparison against live LocalHostName.
# Returns 0 on match (status:-block "up-to-date"); 1 on mismatch.
# LocalHostName is the authoritative comparison key (it's what
# `scutil --set LocalHostName` writes and what users see in `hostname`
# output). NetBIOSName is not managed and not compared (see apply_hostname).
verify_hostname() {
  local expected="${1:-}"
  local live
  live=$(read_local_hostname) || return 1
  [[ "$live" == "$expected" ]]
}

# hostname_state_file -- echo the canonical state-file path. No side effects.
hostname_state_file() {
  echo "${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/hostname"
}

# write_hostname_state_file <name> -- validate, then atomically write the
# state file (mktemp + mv with EXIT/INT/TERM trap clean-up). Mirrors
# install/resolver.zsh::resolve_manifest exactly: trap registered BEFORE
# the write so repeated Ctrl-Cs cannot accumulate hostname.aBcDeF-style
# siblings; trap cleared after a successful mv so the (now-renamed) path
# is not subsequently rm'd.
write_hostname_state_file() {
  local name="${1:-}"
  validate_hostname_name "$name" || return 1

  local out_path out_dir tmp
  out_path=$(hostname_state_file)
  out_dir="${out_path:h}"
  mkdir -p "$out_dir"

  tmp=$(mktemp "${out_path}.XXXXXX")
  trap 'rm -f "$tmp"' EXIT INT TERM
  {
    printf '%s\n' "$name" > "$tmp"
    mv "$tmp" "$out_path"
  } || {
    rm -f "$tmp"
    trap - EXIT INT TERM
    return 1
  }
  trap - EXIT INT TERM
}

# read_hostname_state_file -- echo the first line of the state file (read -r
# trims leading/trailing whitespace and stops at the first newline). Returns
# 1 silently when the file is missing; the caller decides whether to warn or
# skip. `cat | tr -d '[:space:]'` would silently strip embedded whitespace
# and let a "bad name" payload escape MACHINE_NAME_RE-style validation, the
# same failure-loudness rule install/resolver.zsh follows.
read_hostname_state_file() {
  local file value
  file=$(hostname_state_file)
  [[ -f "$file" ]] || return 1
  value=""
  read -r value < "$file" || return 1
  echo "$value"
}
