#!/bin/zsh
# Pre-tool hook: block destructive Bash commands.
# Reads the tool input JSON from stdin (Claude Code hook protocol).

set -euo pipefail
source "${0:A:h}/lib.zsh"

hook::require_ggrep block
hook::read_stdin

command="$(hook::extract '.tool_input.command // ""')"
[[ -z "$command" ]] && exit 0

hook::match_patterns "$command" 2 "BLOCKED: Destructive command detected" \
  'git\s+push\s+.*--force' \
  'git\s+push\s+-f\b' \
  'git\s+reset\s+--hard' \
  'git\s+clean\s+-f' \
  'git\s+branch\s+-D' \
  'git\s+checkout\s+(--\s+)?\.(\s|$)' \
  'git\s+restore\s+(--\s+)?\.(\s|$)' \
  '--no-verify' \
  '--no-gpg-sign' \
  'rm\s+-[a-zA-Z]*r[a-zA-Z]*f' \
  'rm\s+-[a-zA-Z]*f[a-zA-Z]*r' \
  'DROP\s+(TABLE|DATABASE|SCHEMA)' \
  'TRUNCATE\s+TABLE' \
  'curl\s.*\|\s*(sh|bash|zsh)' \
  'wget\s.*\|\s*(sh|bash|zsh)'

exit 0
