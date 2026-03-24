#!/bin/zsh
# Notification hook: show macOS desktop notification when Claude needs attention.
# Reads the tool input JSON from stdin (Claude Code hook protocol).

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
