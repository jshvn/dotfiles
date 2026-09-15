#!/usr/bin/env zsh

# =============================================================================
# install/tests/tunnel.zsh -- smoke tests for os/tunnel.zsh
#
# Purpose:      Exercise the roll guard and the rendered LaunchAgent with
#               stubbed curl and launchctl: render carries the metrics port and
#               token file; roll refuses when the other colour is not ready;
#               roll restarts green before blue when both are ready.
# Depends on:   DOTFILEDIR env var (exported by taskfiles/test.yml); zsh;
#               os/tunnel.zsh; install/messages.zsh.
# Side effects: stub binaries and markers under mktemp -d, removed via EXIT
#               trap. HOME and HOMEBREW_PREFIX are overridden for the run.
# =============================================================================

set -euo pipefail

: "${DOTFILEDIR:?DOTFILEDIR must be set (run via task test:tunnel)}"

source "${DOTFILEDIR}/install/messages.zsh"

failed=0
BASE="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-tunnel-test.XXXXXX")"
trap 'rm -rf "$BASE"' EXIT INT TERM
mkdir -p "$BASE/bin" "$BASE/home"
CALLS="$BASE/calls"; : > "$CALLS"

# curl stub: ready iff a marker for the port in the URL exists.
cat > "$BASE/bin/curl" <<STUB
#!/bin/zsh
port=\${@[-1]##*:}; port=\${port%%/*}
[[ -e "$BASE/ready-\$port" ]]
STUB
# launchctl stub: record the subcommand and label; print succeeds always.
cat > "$BASE/bin/launchctl" <<STUB
#!/bin/zsh
echo "launchctl \$1 \${@[-1]}" >> "$CALLS"
STUB
chmod +x "$BASE/bin/curl" "$BASE/bin/launchctl"

export PATH="$BASE/bin:$PATH" HOME="$BASE/home" HOMEBREW_PREFIX="$BASE/brew" TUNNEL_READY_TIMEOUT=1
source "${DOTFILEDIR}/os/tunnel.zsh"

assert() {  # assert <label> <condition-exit-code>
  if [[ "$2" -eq 0 ]]; then check "tunnel.$1"; else cross "tunnel.$1"; failed=$((failed + 1)); fi
}

# 1. render carries the port, the token file and the binary under HOMEBREW_PREFIX
out="$(render_tunnel_plist blue)"
rc=1; [[ "$out" == *"127.0.0.1:20255"* && "$out" == *"--token-file"* && "$out" == *"$BASE/brew/opt/cloudflared/bin/cloudflared"* ]] && rc=0
assert "render" "$rc"

# 2. roll refuses when blue is not ready (only green is)
touch "$BASE/ready-20256"
rc=0; roll_tunnels >/dev/null 2>&1 || rc=$?
if [[ "$rc" -ne 0 ]] && ! grep -q kickstart "$CALLS"; then assert "roll-refuses" 0; else assert "roll-refuses" 1; fi

# 3. roll restarts green then blue when both are ready
touch "$BASE/ready-20255"; : > "$CALLS"
roll_tunnels >/dev/null 2>&1
rc=1; [[ "$(grep kickstart "$CALLS" | tr '\n' ' ')" == *"cloudflared-green"*"cloudflared-blue"* ]] && rc=0
assert "roll-order" "$rc"

exit "$failed"
