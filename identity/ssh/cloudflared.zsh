#!/bin/zsh
# identity/ssh/cloudflared.zsh -- ProxyCommand wrapper for cloudflared tunnels.
#
# Callers: identity/ssh/identities/personal via ProxyCommand directive for
#   *.jgrid.net and *.plex.me hosts. Invoked by SSH as a subprocess for each
#   connection that matches those Host blocks.
# Side effects: exec replaces this shell process with cloudflared; the parent SSH
#   process communicates with cloudflared over stdin/stdout.
# Requires: cloudflared installed at $HOMEBREW_PREFIX/bin/cloudflared (Homebrew).

set -euo pipefail

exec "$HOMEBREW_PREFIX/bin/cloudflared" "$@"
