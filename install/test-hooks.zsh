#!/usr/bin/env zsh

# =============================================================================
# install/test-hooks.zsh -- smoke tests for the four named Claude hooks
#
# Purpose:      Two scenarios per hook (one pass + one block/warn) for
#               secret-scan, no-emojis, no-ai-comments, agent-transparency.
#               Does NOT cover block-destructive, notify, or post-compact.
# Depends on:   DOTFILEDIR env var (exported by taskfiles/test.yml);
#               install/messages.zsh; claude/hooks/<name>.zsh.
# Side effects: read-only -- pipes synthetic JSON payloads to each hook on
#               stdin; emits check/cross output.
# =============================================================================

set -euo pipefail

: "${DOTFILEDIR:?DOTFILEDIR must be set (run via task test:hooks)}"

# shellcheck source=install/messages.zsh
source "${DOTFILEDIR}/install/messages.zsh"

HOOK_DIR="${DOTFILEDIR}/claude/hooks"
failed=0

# Pass: benign content -- expect exit 0.
# Block: api_key='<20+ chars>' matches the (api[_-]?key)\s*[:=]\s*["'][...]
# pattern in secret-scan.zsh and must produce exit 2.
test_secret_scan() {
  local pass_input block_input exit_code

  pass_input='{"tool_name":"Write","tool_input":{"file_path":"foo.txt","content":"hello world"}}'
  if echo "$pass_input" | zsh "${HOOK_DIR}/secret-scan.zsh" >/dev/null 2>&1; then
    check "secret-scan.pass"
  else
    cross "secret-scan.pass: expected exit 0"
    failed=$((failed + 1))
  fi

  # Synthetic value -- does not match AWS/GitHub/real provider key formats.
  block_input='{"tool_name":"Write","tool_input":{"file_path":"foo.txt","content":"api_key='\''aaaabbbbccccddddeeee1234'\''"  }}'
  exit_code=0
  echo "$block_input" | zsh "${HOOK_DIR}/secret-scan.zsh" >/dev/null 2>&1 || exit_code=$?
  if [[ "$exit_code" -eq 2 ]]; then
    check "secret-scan.block"
  else
    cross "secret-scan.block: expected exit 2, got ${exit_code}"
    failed=$((failed + 1))
  fi
}

# Pass: ASCII content -- expect exit 0, no warning on stderr.
# Warn: emoji codepoint -- expect exit 0 AND stderr warning.
#
# The emoji codepoint is constructed at runtime via printf to avoid embedding
# a literal emoji in this source file -- no-emojis.zsh would flag the
# runner itself if the source contained a real emoji byte.
test_no_emojis() {
  local pass_input warn_input emoji_char warn_stderr exit_code

  pass_input='{"tool_name":"Write","tool_input":{"file_path":"foo.txt","content":"plain ASCII content"}}'
  warn_stderr="$(echo "$pass_input" | zsh "${HOOK_DIR}/no-emojis.zsh" 2>&1 >/dev/null || true)"
  if [[ -z "$warn_stderr" ]]; then
    check "no-emojis.pass"
  else
    cross "no-emojis.pass: unexpected stderr: ${warn_stderr}"
    failed=$((failed + 1))
  fi

  emoji_char="$(printf '\U1F600')"
  warn_input="{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"foo.txt\",\"content\":\"this content has ${emoji_char}\"}}"
  exit_code=0
  warn_stderr="$(echo "$warn_input" | zsh "${HOOK_DIR}/no-emojis.zsh" 2>&1 >/dev/null || exit_code=$?)"
  if [[ "$exit_code" -eq 0 ]] && echo "$warn_stderr" | grep -qi "emoji"; then
    check "no-emojis.warn"
  else
    cross "no-emojis.warn: expected exit 0 + 'emoji' in stderr (exit=${exit_code}, stderr=${warn_stderr})"
    failed=$((failed + 1))
  fi
}

# Pass: plain comment.
# Warn: AI-attribution pattern (matches co-authored-by:.*claude in
#       no-ai-comments.zsh). Fixture string flows only through the test
#       runner stdin pipe -- never written to a file or committed.
test_no_ai_comments() {
  local pass_input warn_input warn_stderr exit_code

  pass_input='{"tool_name":"Write","tool_input":{"file_path":"foo.txt","content":"plain comment"}}'
  warn_stderr="$(echo "$pass_input" | zsh "${HOOK_DIR}/no-ai-comments.zsh" 2>&1 >/dev/null || true)"
  if [[ -z "$warn_stderr" ]]; then
    check "no-ai-comments.pass"
  else
    cross "no-ai-comments.pass: unexpected stderr: ${warn_stderr}"
    failed=$((failed + 1))
  fi

  warn_input='{"tool_name":"Write","tool_input":{"file_path":"foo.txt","content":"Co-Authored-By: claude <noreply@example.com>"}}'
  exit_code=0
  warn_stderr="$(echo "$warn_input" | zsh "${HOOK_DIR}/no-ai-comments.zsh" 2>&1 >/dev/null || exit_code=$?)"
  if [[ "$exit_code" -eq 0 ]] && echo "$warn_stderr" | grep -qi "AI attribution"; then
    check "no-ai-comments.warn"
  else
    cross "no-ai-comments.warn: expected exit 0 + 'AI attribution' in stderr (exit=${exit_code}, stderr=${warn_stderr})"
    failed=$((failed + 1))
  fi
}

# Pass (general-purpose): standard agent type -- expect exit 0 + "Agent
# delegated ->" in output.
# Pass (plugin-scoped):   plugin:agent format -- exercises the plugin-scoped
# resolution branch; expect exit 0 + "type: <plugin:agent>" + "task: test".
# agent-transparency is log-only (always exit 0); no block scenario.
test_agent_transparency() {
  local general_input plugin_input general_out plugin_out exit_code

  general_input='{"tool_input":{"subagent_type":"general-purpose","description":"test"},"cwd":"/tmp"}'
  exit_code=0
  general_out="$(echo "$general_input" | zsh "${HOOK_DIR}/agent-transparency.zsh" 2>&1 || exit_code=$?)"
  if [[ "$exit_code" -eq 0 ]] && echo "$general_out" | grep -q "Agent delegated ->"; then
    check "agent-transparency.general-purpose"
  else
    cross "agent-transparency.general-purpose: expected exit 0 + 'Agent delegated ->' in output (exit=${exit_code})"
    failed=$((failed + 1))
  fi

  plugin_input='{"tool_input":{"subagent_type":"some-plugin:some-agent","description":"test"},"cwd":"/tmp"}'
  exit_code=0
  plugin_out="$(echo "$plugin_input" | zsh "${HOOK_DIR}/agent-transparency.zsh" 2>&1 || exit_code=$?)"
  if [[ "$exit_code" -eq 0 ]] \
    && echo "$plugin_out" | grep -q "type: some-plugin:some-agent" \
    && echo "$plugin_out" | grep -q "task: test"; then
    check "agent-transparency.plugin-scoped"
  else
    cross "agent-transparency.plugin-scoped: expected exit 0 + type/task in output (exit=${exit_code}, output=${plugin_out})"
    failed=$((failed + 1))
  fi
}

# Each tallies failures into $failed; runner does NOT abort on first failure
# (gives complete feedback across all hooks).
test_secret_scan
test_no_emojis
test_no_ai_comments
test_agent_transparency

exit "$failed"
