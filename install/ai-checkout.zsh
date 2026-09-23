#!/bin/zsh

# =============================================================================
# install/ai-checkout.zsh -- put the jshvn/ai checkout at the pinned ref
#
# Purpose:      Clone $AI_REMOTE into $AI_DIR when absent, then check out
#               $AI_REF: a branch on origin is checked out (tracking) and,
#               when $AI_SYNC is "true", fast-forwarded via repo-sync.zsh;
#               a tag or commit is checked out detached. Anything else is an
#               error. Invoked by taskfiles/ai.yml.
# Depends on:   AI_DIR, AI_REMOTE, AI_REF env vars (AI_SYNC optional,
#               default false); git; install/repo-sync.zsh;
#               install/messages.zsh (sourced relative to this script).
# Side effects: git clone into $AI_DIR; git fetch; git checkout; at most a
#               fast-forward merge of the current branch.
# =============================================================================

set -euo pipefail

: "${AI_DIR:?AI_DIR must be set}"
: "${AI_REMOTE:?AI_REMOTE must be set}"
: "${AI_REF:?AI_REF must be set}"
AI_SYNC="${AI_SYNC:-false}"

source "${0:A:h}/messages.zsh"

# Non-interactive git: no credential prompts, a capped SSH handshake, so an
# offline machine warns instead of hanging.
export GIT_TERMINAL_PROMPT=0
git_q() { git -c core.sshCommand='ssh -o BatchMode=yes -o ConnectTimeout=5' -C "$AI_DIR" "$@"; }

if [[ ! -d "${AI_DIR}/.git" ]]; then
  info "ai: cloning ${AI_REMOTE} into ${AI_DIR}"
  mkdir -p "${AI_DIR:h}"
  git -c core.sshCommand='ssh -o BatchMode=yes -o ConnectTimeout=5' clone --quiet "$AI_REMOTE" "$AI_DIR"
fi

# Fetch so a tag or branch cut since the last run is known locally; offline
# is a warning and the local refs decide.
git_q fetch --quiet --tags origin 2>/dev/null || warn "ai: fetch from origin failed; using local refs"

if git_q show-ref --verify --quiet "refs/remotes/origin/${AI_REF}"; then
  current=$(git_q symbolic-ref --quiet --short HEAD 2>/dev/null || true)
  if [[ "$current" != "$AI_REF" ]]; then
    # Creates a local tracking branch on first checkout of a remote branch.
    git_q checkout --quiet "$AI_REF"
  fi
  if [[ "$AI_SYNC" == "true" ]]; then
    DOTFILEDIR="$AI_DIR" zsh "${0:A:h}/repo-sync.zsh"
  fi
elif git_q rev-parse --verify --quiet "${AI_REF}^{commit}" >/dev/null; then
  if [[ "$(git_q rev-parse HEAD)" != "$(git_q rev-parse "${AI_REF}^{commit}")" ]]; then
    git_q checkout --quiet --detach "$AI_REF"
  fi
else
  error "ai: ref '${AI_REF}' is neither a branch on origin nor a tag or commit in ${AI_DIR}"
  exit 1
fi

check "ai: ${AI_DIR} at $(git_q describe --tags --always) (ref ${AI_REF})"
