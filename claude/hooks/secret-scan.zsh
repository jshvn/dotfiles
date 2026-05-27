#!/bin/zsh

# =============================================================================
# claude/hooks/secret-scan.zsh -- pre-tool hook: block writes containing secrets
#
# Purpose:      Read tool input JSON from stdin (Claude Code hook protocol);
#               block (exit 2) when content matches a high-confidence secret
#               pattern; pass through (exit 0) otherwise.
# Depends on:   claude/hooks/lib.zsh; jq; ggrep.
# Side effects: writes BLOCKED line to stderr on match.
# =============================================================================

set -euo pipefail
source "${0:A:h}/lib.zsh"

hook::require_ggrep block
hook::read_stdin

# Both new_string (Edit) and content (Write) flow through here.
content="$(hook::extract '(.tool_input.content // "") + (.tool_input.new_string // "")')"
[[ -z "$content" ]] && exit 0

# High-confidence secret patterns only (avoids false positives on legitimate
# config snippets).
hook::match_patterns "$content" 2 "BLOCKED: Potential secret detected" \
  'AKIA[0-9A-Z]{16}' \
  'gh[pousr]_[A-Za-z0-9_]{36,}' \
  'github_pat_[A-Za-z0-9_]{82,}' \
  'sk-ant-[A-Za-z0-9_-]{32,}' \
  'sk-(proj-|svcacct-)?[A-Za-z0-9_-]{40,}' \
  '(sk|pk|rk)_live_[A-Za-z0-9]{20,}' \
  'https://hooks\.slack\.com/services/[A-Z0-9]+/[A-Z0-9]+/[A-Za-z0-9]+' \
  $'(api[_-]?key|api[_-]?secret|access[_-]?token|auth[_-]?token|secret[_-]?key)\\s*[:=]\\s*["\'"][A-Za-z0-9+/=_-]{20,}["\']' \
  '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----' \
  '://[^:]+:[^@]{8,}@'

exit 0
