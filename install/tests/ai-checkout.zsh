#!/usr/bin/env zsh

# =============================================================================
# install/tests/ai-checkout.zsh -- smoke tests for install/ai-checkout.zsh
#
# Purpose:      Against a throwaway bare remote holding a main branch and a
#               tag: a missing checkout is cloned onto the branch; a tag ref
#               detaches at the tag; the branch ref re-attaches; an unknown
#               ref exits 1 and leaves HEAD where it was.
# Depends on:   DOTFILEDIR env var (exported by taskfiles/test.yml);
#               install/ai-checkout.zsh; install/messages.zsh; git.
# Side effects: creates a sandbox under mktemp -d, removed via trap.
# =============================================================================

set -euo pipefail

: "${DOTFILEDIR:?DOTFILEDIR must be set (run via task test:ai-checkout)}"
source "${DOTFILEDIR}/install/messages.zsh"

typeset -i failures=0
sandbox=$(mktemp -d "${TMPDIR:-/tmp}/ai-checkout-test.XXXXXX")
trap 'rm -rf "$sandbox"' EXIT INT TERM

remote="${sandbox}/remote.git"
seed="${sandbox}/seed"
target="${sandbox}/ai"
script="${DOTFILEDIR}/install/ai-checkout.zsh"

git init -q -b main "$seed"
git -C "$seed" -c user.name=t -c user.email=t@t commit -q --allow-empty -m "one"
git -C "$seed" tag 2000.01.01
git -C "$seed" -c user.name=t -c user.email=t@t commit -q --allow-empty -m "two"
git init -q --bare "$remote"
git -C "$seed" push -q "$remote" main --tags

run() { AI_DIR="$target" AI_REMOTE="$remote" AI_REF="$1" AI_SYNC=false zsh "$script" >/dev/null 2>&1; }

# 1. Missing checkout: cloned, on branch main.
if run main && [[ "$(git -C "$target" symbolic-ref --short HEAD)" == "main" ]]; then
  check "clone lands on the branch ref"
else
  cross "clone did not land on main"
  failures=$(( failures + 1 ))
fi

# 2. Tag ref: detached at the tag's commit.
if run 2000.01.01 && ! git -C "$target" symbolic-ref -q HEAD >/dev/null \
   && [[ "$(git -C "$target" rev-parse HEAD)" == "$(git -C "$target" rev-parse 2000.01.01^{commit})" ]]; then
  check "tag ref detaches at the tag"
else
  cross "tag ref did not detach at 2000.01.01"
  failures=$(( failures + 1 ))
fi

# 3. Back to the branch: re-attached and at the remote tip.
if run main && [[ "$(git -C "$target" symbolic-ref --short HEAD)" == "main" ]] \
   && [[ "$(git -C "$target" rev-parse HEAD)" == "$(git -C "$remote" rev-parse main)" ]]; then
  check "branch ref re-attaches at the remote tip"
else
  cross "branch ref did not re-attach"
  failures=$(( failures + 1 ))
fi

# 4. Unknown ref: exit 1, HEAD unchanged.
before=$(git -C "$target" rev-parse HEAD)
if ! run no-such-ref && [[ "$(git -C "$target" rev-parse HEAD)" == "$before" ]]; then
  check "unknown ref fails and leaves HEAD alone"
else
  cross "unknown ref did not fail cleanly"
  failures=$(( failures + 1 ))
fi

if (( failures == 0 )); then
  success "ai-checkout: all scenarios passed"
else
  error "ai-checkout: ${failures} scenario(s) failed"
fi
exit "$failures"
