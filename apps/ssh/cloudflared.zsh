#!/bin/zsh

# =============================================================================
# apps/ssh/cloudflared.zsh -- ProxyCommand wrapper for cloudflared tunnels
#
# Purpose:      Locate cloudflared on the Homebrew prefix and exec it,
#               invoked by SSH for *-*.jgrid.net / *.plex.me Host blocks.
# Depends on:   HOMEBREW_PREFIX from /etc/zshenv (modules/shell.nix); cloudflared
#               installed at $HOMEBREW_PREFIX/bin/cloudflared.
# Side effects: exec replaces this shell with cloudflared; the parent SSH
#               process communicates over stdin/stdout.
# =============================================================================

set -euo pipefail

# An SSH ProxyCommand never reads .zprofile; HOMEBREW_PREFIX comes from
# /etc/zshenv, which every zsh reads.
if [[ ! -x "${HOMEBREW_PREFIX:-}/bin/cloudflared" ]]; then
  echo "cloudflared.zsh: ${HOMEBREW_PREFIX:-<HOMEBREW_PREFIX unset>}/bin/cloudflared not found or not executable" >&2
  exit 1
fi

exec "${HOMEBREW_PREFIX}/bin/cloudflared" "$@"
