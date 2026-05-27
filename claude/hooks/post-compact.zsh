#!/bin/zsh

# =============================================================================
# claude/hooks/post-compact.zsh -- SessionStart hook: re-inject git context
#
# Purpose:      After context compaction, restore key project state (current
#               branch, last 5 commits, uncommitted-changes summary) to
#               stdout so Claude sees them in the new conversation.
# Depends on:   git.
# Side effects: writes a short context block to stdout (consumed by Claude
#               Code as additionalContext for the SessionStart event).
# =============================================================================

set -euo pipefail

branch="$(git branch --show-current 2>/dev/null || echo 'unknown')"
recent="$(git log --oneline -5 2>/dev/null || echo 'no git history')"
status="$(git status --short 2>/dev/null || echo 'not a git repo')"

cat <<EOF
Context restored after compaction:
  Branch: $branch
  Recent commits:
$recent
  Uncommitted changes:
$status
EOF

exit 0
