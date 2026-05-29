#!/bin/zsh

# =============================================================================
# claude/hooks/auto-approve-reads.zsh -- pre-tool hook: auto-approve read-only
#
# Purpose:      Read tool input JSON from stdin (Claude Code hook protocol);
#               emit permissionDecision "allow" (skip the prompt) when the
#               Bash command is provably read-only -- including pipelines,
#               ; / && / || sequences, and for-loops whose every command
#               position is a known read-only command. Fall through (exit 0,
#               no output) on anything ambiguous so normal permission flow
#               applies. Never approves writes, exec wrappers, redirections,
#               or command substitution.
# Depends on:   claude/hooks/lib.zsh; jq.
# Side effects: writes allow-decision JSON to stdout on match; nothing else.
# =============================================================================

set -euo pipefail
source "${0:A:h}/lib.zsh"

hook::read_stdin
command="$(hook::extract '.tool_input.command // ""')"
[[ -z "$command" ]] && exit 0

# --- Fail-safe rejections (fall through to normal permission flow) ----------
# Any of these can hide a write or run arbitrary code, so never auto-approve.
#   >, >>   output redirection to a file
#   backtick command substitution
#   $(...)  command substitution
#   <(...)  >(...)  process substitution
case "$command" in
  *'>'*|*'`'*|*'$('*|*'<('*|*'>('*) exit 0 ;;
esac

# Tokenize using zsh shell-word splitting (honors quoting, separates
# operators). Read-only by construction: ${(z)} parses, it does not execute.
local -a tokens
tokens=(${(z)command})
(( ${#tokens} )) || exit 0

# Control words and wrappers we refuse to reason about: presence anywhere
# means fall through. (if/while/case bodies are hard to parse safely; the
# wrappers run their arguments as a fresh command our walk would not check.)
local -A BLOCK
for w in if then elif else fi while until select case esac function coproc \
         time eval exec source trap sudo env command xargs nice timeout \
         nohup watch setsid ionice flock tee dd; do
  BLOCK[$w]=1
done

# Commands that only read (write to stdout, never to files; no exec flags).
local -A READONLY
for c in cat bat echo printf ls pwd head tail wc grep egrep fgrep rg ag \
         file stat diff which type basename dirname realpath readlink \
         cut tr column tac rev nl paste comm join fold fmt expand unexpand \
         look jq true false test '[' '[[' ':' date id groups whoami uname \
         hostname arch du df locale od xxd strings hexdump shasum md5 \
         md5sum sha1sum sha256sum sha512sum cksum cd printenv ps uptime \
         who tty; do
  READONLY[$c]=1
done

# State machine: expect_cmd is 1 when the next token sits in command position
# (start of a simple command), 0 when it is an argument. Every command-position
# token must be a known read-only command or a recognized structural keyword.
local expect_cmd=1
local tok
for tok in "${tokens[@]}"; do
  # Refuse outright on any blocked control word / wrapper.
  [[ -n "${BLOCK[$tok]:-}" ]] && exit 0

  case "$tok" in
    '|'|'||'|'&&'|';'|'&'|'|&'|'do'|'('|'{')
      expect_cmd=1; continue ;;
    ')'|'}'|'done')
      expect_cmd=0; continue ;;
    'for')
      expect_cmd=0; continue ;;   # next token is a loop variable, not a command
    'in')
      expect_cmd=0; continue ;;   # next tokens are the word list
  esac

  if (( expect_cmd )); then
    # Command position: must be a known read-only command.
    [[ -n "${READONLY[$tok]:-}" ]] || exit 0
    expect_cmd=0
  fi
  # Argument position: ignored.
done

# Every command position was read-only -> approve and skip the prompt.
print -r -- '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"Read-only command auto-approved by dotfiles auto-approve-reads hook"}}'
exit 0
