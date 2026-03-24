# Shared helpers for Claude Code hooks.
# Source this file; do not execute directly.
#
# Provides:
#   hook::read_stdin         -- read hook JSON into $HOOK_INPUT
#   hook::require_ggrep MODE -- resolve $GGREP, exit on failure (block|warn)
#   hook::extract EXPR       -- jq expression against $HOOK_INPUT
#   hook::match_patterns TEXT EXIT_CODE LABEL PATTERNS...
#                            -- grep each pattern, exit on first match

# ---------------------------------------------------------------------------
# hook::read_stdin
#   Reads stdin once into HOOK_INPUT. Safe to call multiple times.
# ---------------------------------------------------------------------------
hook::read_stdin() {
  [[ -n "${HOOK_INPUT:-}" ]] && return 0
  HOOK_INPUT="$(cat)"
}

# ---------------------------------------------------------------------------
# hook::require_ggrep MODE
#   Resolves GNU grep from Homebrew into $GGREP.
#   MODE=block  -> exit 2 if missing (fail closed, for security hooks)
#   MODE=warn   -> exit 0 with warning if missing (fail open, for advisory hooks)
# ---------------------------------------------------------------------------
hook::require_ggrep() {
  local mode="${1:?usage: hook::require_ggrep block|warn}"
  GGREP="${HOMEBREW_PREFIX:-/opt/homebrew}/bin/ggrep"

  if [[ -x "$GGREP" ]]; then
    return 0
  fi

  case "$mode" in
    block)
      echo "BLOCKED: ggrep (GNU grep) not found at $GGREP -- cannot verify safety" >&2
      exit 2
      ;;
    warn)
      echo "WARNING: ggrep (GNU grep) not found at $GGREP -- check skipped" >&2
      exit 0
      ;;
    *)
      echo "ERROR: hook::require_ggrep: unknown mode '$mode'" >&2
      exit 1
      ;;
  esac
}

# ---------------------------------------------------------------------------
# hook::extract EXPR
#   Runs a jq expression against $HOOK_INPUT and prints the result.
#   Caller must have called hook::read_stdin first.
# ---------------------------------------------------------------------------
hook::extract() {
  local expr="${1:?usage: hook::extract '<jq expression>'}"
  jq -r "$expr" <<< "$HOOK_INPUT"
}

# ---------------------------------------------------------------------------
# hook::match_patterns TEXT EXIT_CODE LABEL PATTERNS...
#   Iterates PATTERNS, testing each against TEXT with ggrep -Ei.
#   On first match: prints LABEL + matched pattern to stderr and exits
#   with EXIT_CODE. Returns 0 if no patterns match.
#
#   Example:
#     hook::match_patterns "$cmd" 2 "BLOCKED: Destructive command" \
#       'git\s+push\s+.*--force' \
#       'rm\s+-rf'
# ---------------------------------------------------------------------------
hook::match_patterns() {
  local text="$1" exit_code="$2" label="$3"
  shift 3

  for pattern in "$@"; do
    if "$GGREP" -qEi -- "$pattern" <<< "$text"; then
      echo "$label (pattern: $pattern)" >&2
      exit "$exit_code"
    fi
  done

  return 0
}
