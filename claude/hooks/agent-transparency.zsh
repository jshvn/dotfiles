#!/bin/zsh

# =============================================================================
# claude/hooks/agent-transparency.zsh -- PreToolUse hook: log Agent delegation
#
# Purpose:      Log which subagent is being delegated to (read by the
#               Claude Code transcript). Never blocks (always exits 0).
# Depends on:   claude/hooks/lib.zsh; jq.
# Side effects: writes one log line to stdout per Agent tool invocation.
# =============================================================================

set -euo pipefail
source "${0:A:h}/lib.zsh"

main() {
  hook::read_stdin

  local agent_type description cwd agent_md
  agent_type=$(hook::extract '.tool_input.subagent_type // "general-purpose"')
  description=$(hook::extract '.tool_input.description // "no description"')
  cwd=$(hook::extract '.cwd // ""')

  # Resolve agent.md from known locations (project, user global, plugin).
  agent_md=""
  if [[ "$agent_type" != "general-purpose" ]]; then
    # Plugin-scoped agents (e.g. "everything-claude-code:rust-reviewer").
    if [[ "$agent_type" == *:* ]]; then
      local plugin="${agent_type%%:*}"
      local agent_name="${agent_type#*:}"
      for candidate in \
        "${XDG_CONFIG_HOME}/claude/plugins/${plugin}/agents/${agent_name}.md" \
        "${XDG_CONFIG_HOME}/claude/plugins/${plugin}/agents/${agent_name}/agent.md"; do
        [[ -f "$candidate" ]] && { agent_md="$candidate"; break; }
      done
    else
      # Non-plugin agents: project then global.
      for base in "${cwd}/.claude/agents" "${XDG_CONFIG_HOME}/claude/agents"; do
        for candidate in "${base}/${agent_type}.md" "${base}/${agent_type}/agent.md"; do
          [[ -f "$candidate" ]] && { agent_md="$candidate"; break 2; }
        done
      done
    fi
  fi

  local output="Agent delegated -> type: ${agent_type}, task: ${description}"
  [[ -n "$agent_md" ]] && output+=", definition: ${agent_md}"
  echo "$output"
}

main "$@"
