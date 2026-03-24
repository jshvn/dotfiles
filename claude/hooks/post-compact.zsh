#!/bin/zsh
# Session hook: re-inject context after compaction.
# Restores key project state that gets lost when context is compacted.

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
