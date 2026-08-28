#!/bin/zsh

# =============================================================================
# claude/hooks/block-destructive.zsh -- pre-tool hook: block unrecoverable Bash
#
# Purpose:      Read tool input JSON from stdin (Claude Code hook protocol);
#               block (exit 2) commands whose damage nothing can undo --
#               history rewrites, uncommitted-work discards, verification
#               bypasses, schema drops, remote-fetch-then-exec. Deletes are
#               Claude Code's own critical-path check to gate, so they pass
#               through here.
# Depends on:   claude/hooks/lib.zsh; jq; ggrep.
# Side effects: writes BLOCKED line to stderr on match.
# =============================================================================

set -euo pipefail
source "${0:A:h}/lib.zsh"

hook::require_ggrep block
hook::read_stdin

command="$(hook::extract '.tool_input.command // ""')"
[[ -z "$command" ]] && exit 0

# Every pattern names damage that leaves no recovery path. Deletes are absent
# on purpose: branch and index resets are reflog-recoverable, and a delete
# aimed at the filesystem root, a top-level directory, $HOME, or the working
# directory and its parents is a critical path Claude Code routes to its own
# check, which no allow rule or hook can approve. Matching the rest by regex
# blocks `rm -rf node_modules` while `rm -r ~/Documents` walks past, so this
# hook does not try. Working-tree discards stay blocked -- uncommitted work is
# in no reflog and no critical-path list.
hook::match_patterns "$command" 2 "BLOCKED: Unrecoverable command detected" \
  'git\s+push\s+.*--force' \
  'git\s+push\s+-f\b' \
  'git\s+checkout\s+(--\s+)?\.(\s|$)' \
  'git\s+restore\s+(--\s+)?\.(\s|$)' \
  '--no-verify' \
  '--no-gpg-sign' \
  'DROP\s+(TABLE|DATABASE|SCHEMA)' \
  'TRUNCATE\s+TABLE' \
  'curl\s.*\|\s*(sh|bash|zsh)' \
  'wget\s.*\|\s*(sh|bash|zsh)' \
  '(bash|sh|zsh)\s+-c\s+.*\$\(.*(curl|wget)' \
  '(python|python3)\s+-c\s+.*\$\(.*(curl|wget)' \
  '(perl|node|ruby)\s+-e\s+.*\$\(.*(curl|wget)'

exit 0
