#!/bin/zsh

# =============================================================================
# claude/hooks/notify.zsh -- Notification hook: desktop notification on attn
#
# Purpose:      Read Notification event JSON from stdin (Claude Code hook
#               protocol); fire a macOS Notification Center entry with the
#               supplied title and message.
# Depends on:   claude/hooks/lib.zsh; jq; osascript.
# Side effects: posts a macOS user notification; failure is silent (`|| true`)
#               so headless boxes do not abort the hook chain.
# =============================================================================

set -euo pipefail
source "${0:A:h}/lib.zsh"

hook::read_stdin

title="$(hook::extract '.title // "Claude Code"')"
message="$(hook::extract '.message // "Task complete"')"

osascript - "$title" "$message" <<'APPLESCRIPT' 2>/dev/null || true
on run argv
  display notification (item 2 of argv) with title (item 1 of argv)
end run
APPLESCRIPT

exit 0
