#!/bin/zsh

# =============================================================================
# identity/ssh/cloudflared.zsh -- ProxyCommand wrapper for cloudflared tunnels
#
# Purpose:      Locate cloudflared on the Homebrew prefix and exec it,
#               invoked by SSH for *.jgrid.net / *.plex.me Host blocks.
# Depends on:   cloudflared installed at $HOMEBREW_PREFIX/bin/cloudflared.
# Side effects: exec replaces this shell with cloudflared; the parent SSH
#               process communicates over stdin/stdout.
# =============================================================================

set -euo pipefail

# SSH ProxyCommand subshells do NOT source .zprofile, so HOMEBREW_PREFIX
# (set by `brew shellenv` at login) is absent. Under `set -u` a bare
# reference would abort the wrapper with `unbound variable` on every SSH
# connection. Detect the prefix locally via `uname -m`.
if [[ -z "${HOMEBREW_PREFIX:-}" ]]; then
  case "$(uname -m)" in
    arm64)  HOMEBREW_PREFIX="/opt/homebrew" ;; # lint-allow: hardcoded-prefix
    x86_64) HOMEBREW_PREFIX="/usr/local"    ;; # lint-allow: hardcoded-prefix
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
