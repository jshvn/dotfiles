#!/bin/zsh

# This simple script allows me to directly use cloudflared tunnels via ProxyCommand in SSH configs

exec "$HOMEBREW_PREFIX/bin/cloudflared" "$@"