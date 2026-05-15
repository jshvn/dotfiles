#!/bin/zsh
# identity/ssh/cloudflared.zsh -- ProxyCommand wrapper for cloudflared tunnels.
#
# Callers: identity/ssh/identities/personal via ProxyCommand directive for
#   *.jgrid.net and *.plex.me hosts. Invoked by SSH as a subprocess for each
#   connection that matches those Host blocks.
# Side effects: exec replaces this shell process with cloudflared; the parent SSH
#   process communicates with cloudflared over stdin/stdout.
# Requires: cloudflared installed at $HOMEBREW_PREFIX/bin/cloudflared (Homebrew).
#
# CR-01: SSH ProxyCommand subshells do NOT source .zprofile, so HOMEBREW_PREFIX
# (set by `brew shellenv` at login) is absent. Under `set -u` a bare reference
# to $HOMEBREW_PREFIX would abort the wrapper with `unbound variable` on every
# SSH connection. Detect the prefix locally via `uname -m` per project rule
# (no hardcoded /opt/homebrew or /usr/local except inside the dispatch).

set -euo pipefail

if [[ -z "${HOMEBREW_PREFIX:-}" ]]; then
  case "$(uname -m)" in
    arm64)  HOMEBREW_PREFIX="/opt/homebrew" ;;
    x86_64) HOMEBREW_PREFIX="/usr/local"    ;;
    *)
      echo "cloudflared.zsh: unknown arch $(uname -m); cannot locate cloudflared" >&2
      exit 1
      ;;
  esac
fi

if [[ ! -x "${HOMEBREW_PREFIX}/bin/cloudflared" ]]; then
  echo "cloudflared.zsh: ${HOMEBREW_PREFIX}/bin/cloudflared not found or not executable" >&2
  exit 1
fi

exec "${HOMEBREW_PREFIX}/bin/cloudflared" "$@"
