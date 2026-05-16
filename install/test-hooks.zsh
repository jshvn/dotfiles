#!/usr/bin/env zsh
# -----------------------------------------------------------------------------
# install/test-hooks.zsh -- Tier-3 smoke tests for the four named Claude hooks.
#
# Invoked by: task test:hooks (via taskfiles/test.yml)
# Scope: CLDE-02 named hooks only -- secret-scan, no-emojis, no-ai-comments,
#        agent-transparency. Does NOT cover block-destructive, notify, or
#        post-compact (D-17).
#
# Each hook receives a synthetic JSON payload matching Claude Code's hook stdin
# contract: {"tool_name":"...", "tool_input":{...}, "cwd":"..."}.
# Two scenarios per hook (D-16): one pass + one block/warn scenario.
# Exit codes: 0 if all eight fixtures pass; non-zero (count of failures) otherwise.
#
# Requires: DOTFILEDIR env var (exported by taskfiles/test.yml at invocation).
# -----------------------------------------------------------------------------

set -euo pipefail

# Fail loud if DOTFILEDIR is not set -- set -u will catch this, but an explicit
# message is more helpful than "DOTFILEDIR: parameter not set".
: "${DOTFILEDIR:?DOTFILEDIR must be set (run via task test:hooks)}"

# shellcheck source=install/messages.zsh
source "${DOTFILEDIR}/install/messages.zsh"

HOOK_DIR="${DOTFILEDIR}/claude/hooks"
failed=0

# =============================================================================
# test_secret_scan
#   Pass: benign content -- expect exit 0
#   Block: content matching the api_key pattern with quoted value -- expect exit 2
#   Pattern used: (api[_-]?key)[:=]["'][20+ chars]["'] from secret-scan.zsh
# =============================================================================
test_secret_scan() {
  local pass_input block_input exit_code

  # Pass scenario: plain text -- no pattern matches
  pass_input='{"tool_name":"Write","tool_input":{"file_path":"foo.txt","content":"hello world"}}'
  if echo "$pass_input" | zsh "${HOOK_DIR}/secret-scan.zsh" >/dev/null 2>&1; then
    check "secret-scan.pass"
  else
    cross "secret-scan.pass: expected exit 0"
    failed=1
  fi

  # Block scenario: content contains api_key='"<20+ chars>"' which matches the
  # (api[_-]?key)\s*[:=]\s*["'][A-Za-z0-9+/=_-]{20,}["'] pattern.
  # Synthetic value -- does not match AWS/GitHub/real provider key formats.
  block_input='{"tool_name":"Write","tool_input":{"file_path":"foo.txt","content":"api_key='\''aaaabbbbccccddddeeee1234'\''"  }}'
  exit_code=0
  echo "$block_input" | zsh "${HOOK_DIR}/secret-scan.zsh" >/dev/null 2>&1 || exit_code=$?
  if [[ "$exit_code" -eq 2 ]]; then
    check "secret-scan.block"
  else
    cross "secret-scan.block: expected exit 2, got ${exit_code}"
    failed=1
  fi
}

# =============================================================================
# test_no_emojis
#   Pass: plain ASCII content -- expect exit 0, no warning on stderr
#   Warn: content with an emoji codepoint -- expect exit 0 AND stderr warning
#
# The emoji codepoint is constructed at runtime via printf to avoid embedding
# a literal emoji character in this source file (T-07-18: no-emojis.zsh would
# flag the runner itself if the source contained a real emoji byte).
# =============================================================================
test_no_emojis() {
  local pass_input warn_input emoji_char warn_stderr exit_code

  # Pass scenario: ASCII only
  pass_input='{"tool_name":"Write","tool_input":{"file_path":"foo.txt","content":"plain ASCII content"}}'
  warn_stderr="$(echo "$pass_input" | zsh "${HOOK_DIR}/no-emojis.zsh" 2>&1 >/dev/null || true)"
  if [[ -z "$warn_stderr" ]]; then
    check "no-emojis.pass"
  else
    cross "no-emojis.pass: unexpected stderr: ${warn_stderr}"
    failed=1
  fi

  # Warn scenario: inject emoji at runtime (U+1F600 GRINNING FACE).
  # printf '\U1F600' constructs the codepoint without literal bytes in source.
  emoji_char="$(printf '\U1F600')"
  warn_input="{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"foo.txt\",\"content\":\"this content has ${emoji_char}\"}}"
  exit_code=0
  warn_stderr="$(echo "$warn_input" | zsh "${HOOK_DIR}/no-emojis.zsh" 2>&1 >/dev/null || exit_code=$?)"
  if [[ "$exit_code" -eq 0 ]] && echo "$warn_stderr" | grep -qi "emoji"; then
    check "no-emojis.warn"
  else
    cross "no-emojis.warn: expected exit 0 + 'emoji' in stderr (exit=${exit_code}, stderr=${warn_stderr})"
    failed=1
  fi
}

# =============================================================================
# test_no_ai_comments
#   Pass: plain comment -- expect exit 0, no warning on stderr
#   Warn: content with an AI attribution pattern -- expect exit 0 AND stderr warning
#
# The fixture string uses 'Co-Authored-By:' which matches the
# co-authored-by:.*\b(claude|...) pattern in no-ai-comments.zsh.
# This string flows only through the test runner stdin pipe -- it is never
# written to a file or committed (T-07-19).
# =============================================================================
test_no_ai_comments() {
  local pass_input warn_input warn_stderr exit_code

  # Pass scenario: plain comment -- no AI attribution pattern
  pass_input='{"tool_name":"Write","tool_input":{"file_path":"foo.txt","content":"plain comment"}}'
  warn_stderr="$(echo "$pass_input" | zsh "${HOOK_DIR}/no-ai-comments.zsh" 2>&1 >/dev/null || true)"
  if [[ -z "$warn_stderr" ]]; then
    check "no-ai-comments.pass"
  else
    cross "no-ai-comments.pass: unexpected stderr: ${warn_stderr}"
    failed=1
  fi

  # Warn scenario: the string below matches the co-authored-by:.*claude pattern.
  # Fixture marker -- test input only, not committed code or commit message.
  warn_input='{"tool_name":"Write","tool_input":{"file_path":"foo.txt","content":"Co-Authored-By: claude <noreply@example.com>"}}'
  exit_code=0
  warn_stderr="$(echo "$warn_input" | zsh "${HOOK_DIR}/no-ai-comments.zsh" 2>&1 >/dev/null || exit_code=$?)"
  if [[ "$exit_code" -eq 0 ]] && echo "$warn_stderr" | grep -qi "AI attribution"; then
    check "no-ai-comments.warn"
  else
    cross "no-ai-comments.warn: expected exit 0 + 'AI attribution' in stderr (exit=${exit_code}, stderr=${warn_stderr})"
    failed=1
  fi
}

# =============================================================================
# test_agent_transparency
#   Pass (general-purpose): standard agent type -- expect exit 0 + "Agent delegated ->"
#   Pass (plugin-scoped):   plugin:agent format -- expect exit 0 + "type: some-plugin:some-agent"
#                           and "task: test" in output (exercises Plan 02 rewrite branch)
#
# agent-transparency is log-only (always exit 0); there is no block scenario.
# The second fixture exercises the plugin-scoped resolution branch from the
# Plan 02 function-wrap rewrite (regression check for CLDE-02).
# =============================================================================
test_agent_transparency() {
  local general_input plugin_input general_out plugin_out exit_code

  # Pass scenario: general-purpose agent type
  general_input='{"tool_input":{"subagent_type":"general-purpose","description":"test"},"cwd":"/tmp"}'
  exit_code=0
  general_out="$(echo "$general_input" | zsh "${HOOK_DIR}/agent-transparency.zsh" 2>&1 || exit_code=$?)"
  if [[ "$exit_code" -eq 0 ]] && echo "$general_out" | grep -q "Agent delegated ->"; then
    check "agent-transparency.general-purpose"
  else
    cross "agent-transparency.general-purpose: expected exit 0 + 'Agent delegated ->' in output (exit=${exit_code})"
    failed=1
  fi

  # Plugin-scoped scenario: exercises the plugin:agent resolution branch
  plugin_input='{"tool_input":{"subagent_type":"some-plugin:some-agent","description":"test"},"cwd":"/tmp"}'
  exit_code=0
  plugin_out="$(echo "$plugin_input" | zsh "${HOOK_DIR}/agent-transparency.zsh" 2>&1 || exit_code=$?)"
  if [[ "$exit_code" -eq 0 ]] \
    && echo "$plugin_out" | grep -q "type: some-plugin:some-agent" \
    && echo "$plugin_out" | grep -q "task: test"; then
    check "agent-transparency.plugin-scoped"
  else
    cross "agent-transparency.plugin-scoped: expected exit 0 + type/task in output (exit=${exit_code}, output=${plugin_out})"
    failed=1
  fi
}

# =============================================================================
# Run all four test functions. Each tallies failures into $failed; the runner
# does NOT abort on first failure (gives complete feedback across all hooks).
# =============================================================================
test_secret_scan
test_no_emojis
test_no_ai_comments
test_agent_transparency

exit "$failed"
