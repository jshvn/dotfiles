#!/bin/zsh

# =============================================================================
# claude/hooks/no-emojis.zsh -- post-tool hook: warn on emojis in code files
#
# Purpose:      Non-blocking warning when emojis are written to non-markdown
#               files (exit 0 always; prints warning to stderr for Claude
#               to fix on the next iteration).
# Depends on:   claude/hooks/lib.zsh; jq; ggrep with PCRE support.
# Side effects: writes WARNING line to stderr on emoji match.
# =============================================================================

set -euo pipefail
source "${0:A:h}/lib.zsh"

hook::require_ggrep warn
hook::read_stdin

file_path="$(hook::extract '.tool_input.file_path // ""')"

# Markdown files are exempt -- emojis are acceptable if user adds them.
[[ "$file_path" == *.md ]] && exit 0

content="$(hook::extract '(.tool_input.content // "") + (.tool_input.new_string // "")')"
[[ -z "$content" ]] && exit 0

# Emoji Unicode ranges via GNU grep -P (PCRE): Misc Symbols, Emoticons,
# Dingbats, Transport/Map, Extended Pictographics.
if "$GGREP" -qP '[\x{1F300}-\x{1F9FF}\x{2702}-\x{27B0}\x{FE00}-\x{FE0F}\x{1FA00}-\x{1FAFF}\x{2600}-\x{26FF}]' <<< "$content"; then
  echo "WARNING: Emoji detected in $file_path. Remove emojis -- use text alternatives like [OK], [X], [WARNING]." >&2
fi

exit 0
