#!/bin/zsh
# Post-tool hook: warn if emojis were written to code files.
# Non-blocking (exit 0) -- prints a warning for Claude to fix.

set -euo pipefail
source "${0:A:h}/lib.zsh"

hook::require_ggrep warn
hook::read_stdin

file_path="$(hook::extract '.tool_input.file_path // ""')"

# Skip markdown files -- emojis are acceptable there if user adds them
[[ "$file_path" == *.md ]] && exit 0

content="$(hook::extract '(.tool_input.content // "") + (.tool_input.new_string // "")')"
[[ -z "$content" ]] && exit 0

# Check for emoji Unicode ranges using GNU grep -P (PCRE)
# Covers Misc Symbols, Emoticons, Dingbats, Transport/Map, and Extended Pictographics
if "$GGREP" -qP '[\x{1F300}-\x{1F9FF}\x{2702}-\x{27B0}\x{FE00}-\x{FE0F}\x{1FA00}-\x{1FAFF}\x{2600}-\x{26FF}]' <<< "$content"; then
  echo "WARNING: Emoji detected in $file_path. Remove emojis -- use text alternatives like [OK], [X], [WARNING]." >&2
fi

exit 0
