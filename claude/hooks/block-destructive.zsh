#!/bin/zsh

# =============================================================================
# claude/hooks/block-destructive.zsh -- pre-tool hook: block destructive Bash
#
# Purpose:      Read tool input JSON from stdin (Claude Code hook protocol);
#               block (exit 2) when the command matches a destructive pattern
#               (force-push, rm -rf, DROP TABLE, --no-verify, remote-fetch-
#               then-exec via pipe or subshell, etc.); pass through (exit 0)
#               otherwise.
# Depends on:   claude/hooks/lib.zsh; jq; ggrep.
# Side effects: writes BLOCKED line to stderr on match.
# =============================================================================

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
  'find\s+.*-delete\b' \
  'DROP\s+(TABLE|DATABASE|SCHEMA)' \
  'TRUNCATE\s+TABLE' \
  'curl\s.*\|\s*(sh|bash|zsh)' \
  'wget\s.*\|\s*(sh|bash|zsh)' \
  '(bash|sh|zsh)\s+-c\s+.*\$\(.*(curl|wget)' \
  '(python|python3)\s+-c\s+.*\$\(.*(curl|wget)' \
  '(perl|node|ruby)\s+-e\s+.*\$\(.*(curl|wget)'

# rm with BOTH a recursive flag and a force flag, in any order or split across
# tokens (rm -r -f, rm --recursive --force, rm -fr). The OR-based
# hook::match_patterns above cannot express this conjunction, so the simpler
# adjacent-flag patterns there miss the split-flag forms.
if "$GGREP" -qE '(^|[[:space:]])rm([[:space:]]|$)' <<< "$command" \
   && "$GGREP" -qE '(^|[[:space:]])(-[a-zA-Z]*r[a-zA-Z]*|--recursive|-R)([[:space:]]|$)' <<< "$command" \
   && "$GGREP" -qE '(^|[[:space:]])(-[a-zA-Z]*f[a-zA-Z]*|--force)([[:space:]]|$)' <<< "$command"; then
  echo "BLOCKED: Destructive command detected (pattern: rm recursive+force)" >&2
  exit 2
fi

exit 0
