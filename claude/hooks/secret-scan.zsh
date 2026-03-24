#!/bin/zsh
# Pre-tool hook: block writes that contain likely secrets.
# Reads the tool input JSON from stdin (Claude Code hook protocol).

set -euo pipefail
source "${0:A:h}/lib.zsh"

hook::require_ggrep block
hook::read_stdin

# Check both new_string (Edit) and content (Write)
content="$(hook::extract '(.tool_input.content // "") + (.tool_input.new_string // "")')"
[[ -z "$content" ]] && exit 0

# Patterns that strongly indicate real secrets (high-confidence only)
hook::match_patterns "$content" 2 "BLOCKED: Potential secret detected" \
  'AKIA[0-9A-Z]{16}' \
  'gh[pousr]_[A-Za-z0-9_]{36,}' \
  '(api[_-]?key|api[_-]?secret|access[_-]?token|auth[_-]?token|secret[_-]?key)\s*[:=]\s*["\x27][A-Za-z0-9+/=_-]{20,}["\x27]' \
  '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----' \
  '://[^:]+:[^@]{8,}@'

exit 0
