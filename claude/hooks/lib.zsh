#!/bin/zsh

# =============================================================================
# claude/hooks/lib.zsh -- shared helpers for Claude Code hooks
#
# Purpose:      Provide hook::read_stdin / hook::require_ggrep /
#               hook::extract / hook::match_patterns building blocks.
# Depends on:   jq; $HOMEBREW_PREFIX/bin/ggrep.
# Side effects: none -- source-only library; do NOT execute directly.
# =============================================================================

# hook::read_stdin
#   Read stdin once into HOOK_INPUT. Safe to call multiple times.
hook::read_stdin() {
  [[ -n "${HOOK_INPUT:-}" ]] && return 0
  HOOK_INPUT="$(cat)"
}

# hook::require_ggrep MODE
#   Resolve GNU grep from Homebrew into $GGREP.
#   MODE=block -> exit 2 if missing (fail closed, security hooks)
#   MODE=warn  -> exit 0 with warning if missing (fail open, advisory hooks)
hook::require_ggrep() {
  local mode="${1:?usage: hook::require_ggrep block|warn}"
  # Hooks run in a subprocess that does NOT source .zprofile, so
  # $HOMEBREW_PREFIX may be unset. Detect it via `uname -m` rather than
  # defaulting to the Apple-Silicon path -- a wrong fallback on Intel would
  # leave $GGREP missing and (in block mode) fail closed on EVERY command.
  local prefix="${HOMEBREW_PREFIX:-}"
  if [[ -z "$prefix" ]]; then
    case "$(uname -m)" in
      arm64)  prefix="/opt/homebrew" ;; # lint-allow: hardcoded-prefix
      x86_64) prefix="/usr/local"    ;; # lint-allow: hardcoded-prefix
    esac
  fi
  GGREP="${prefix}/bin/ggrep"

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

# hook::extract EXPR
#   Run a jq expression against $HOOK_INPUT and print the result. Caller
#   must have called hook::read_stdin first.
hook::extract() {
  local expr="${1:?usage: hook::extract '<jq expression>'}"
  jq -r "$expr" <<< "$HOOK_INPUT"
}

# hook::match_patterns TEXT EXIT_CODE LABEL PATTERNS...
#   Iterate PATTERNS, testing each against TEXT with ggrep -Ei. On first
#   match: print LABEL + matched pattern to stderr and exit with EXIT_CODE.
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
