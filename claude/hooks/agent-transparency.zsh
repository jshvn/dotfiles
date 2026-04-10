#!/usr/bin/env zsh
set -euo pipefail

# Log which subagent is being delegated to for conversation transparency.
# Runs as a PreToolUse hook on the Agent tool.

source "${0:A:h}/lib.zsh"

hook::read_stdin

local agent_type description cwd agent_md
agent_type=$(hook::extract '.tool_input.subagent_type // "general-purpose"')
description=$(hook::extract '.tool_input.description // "no description"')
cwd=$(hook::extract '.cwd // ""')

# Resolve agent.md from known locations (project, user global, plugin)
agent_md=""
if [[ "$agent_type" != "general-purpose" ]]; then
  # Check for plugin-scoped agents (e.g. "everything-claude-code:rust-reviewer")
  if [[ "$agent_type" == *:* ]]; then
    local plugin="${agent_type%%:*}"
    local agent_name="${agent_type#*:}"
    # Plugin agents live under the plugin's agents directory
    for candidate in \
      "${XDG_CONFIG_HOME}/claude/plugins/${plugin}/agents/${agent_name}.md" \
      "${XDG_CONFIG_HOME}/claude/plugins/${plugin}/agents/${agent_name}/agent.md"; do
      [[ -f "$candidate" ]] && { agent_md="$candidate"; break; }
    done
  else
    # Non-plugin agents: check project then global
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
