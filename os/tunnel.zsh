#!/bin/zsh

# =============================================================================
# os/tunnel.zsh -- blue/green cloudflared connector pair as LaunchAgents
#
# Purpose:      Provide apply_tunnels / verify_tunnel / roll_tunnels /
#               show_tunnels for the cloudflared-tunnel feature: two
#               LaunchAgents (blue, green) each running `cloudflared tunnel run`
#               as a replica of one remotely managed tunnel, token read from a
#               file the operator writes once. Every restart is one colour at a
#               time, gated on the other colour's /ready, so a connector always
#               serves and ssh over the tunnel survives its own upgrade.
# Depends on:   install/messages.zsh; $DOTFILEDIR and $HOMEBREW_PREFIX exported
#               by the caller (taskfiles/tunnel.yml); cloudflared
#               (manifests/base.toml); launchctl; curl.
# Side effects: writes ~/Library/LaunchAgents/com.jshvn.cloudflared-<colour>.plist;
#               launchctl bootstrap / bootout / kickstart in the gui domain;
#               replicas log to ~/Library/Logs/com.jshvn.cloudflared-<colour>.log.
#               verify_* and show_tunnels are read-only.
# =============================================================================

set -euo pipefail

: "${DOTFILEDIR:?DOTFILEDIR not set -- run via 'task tunnel:*'}"
: "${HOMEBREW_PREFIX:?HOMEBREW_PREFIX not set -- run via 'task tunnel:*'}"
source "${DOTFILEDIR}/install/messages.zsh"

typeset -r TUNNEL_TOKEN_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/cloudflared/tunnel.token"
typeset -r TUNNEL_LABEL_PREFIX="com.jshvn.cloudflared"
typeset -rA TUNNEL_METRICS_PORT=(blue 20255 green 20256)
typeset -r TUNNEL_READY_TIMEOUT="${TUNNEL_READY_TIMEOUT:-120}"

tunnel_label()  { echo "${TUNNEL_LABEL_PREFIX}-$1"; }
tunnel_plist()  { echo "${HOME}/Library/LaunchAgents/$(tunnel_label "$1").plist"; }
tunnel_domain() { echo "gui/$(id -u)"; }
tunnel_other()  { [[ "$1" == green ]] && echo blue || echo green; }

# render_tunnel_plist <colour> -- the desired plist on stdout. launchd expands
# no variables, so every path is absolute at render time. KeepAlive restarts
# the replica on any exit; RunAtLoad starts it at login (auto-login is on).
# ponytail: a gui-domain LaunchAgent needs a logged-in user; a LaunchDaemon
# (sudo, /Library/LaunchDaemons, root-owned token) is the upgrade if
# auto-login ever goes away.
render_tunnel_plist() {
  local colour="$1" label port
  label=$(tunnel_label "$colour")
  port="${TUNNEL_METRICS_PORT[$colour]}"
  cat <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>${label}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${HOMEBREW_PREFIX}/opt/cloudflared/bin/cloudflared</string>
    <string>tunnel</string>
    <string>--no-autoupdate</string>
    <string>--metrics</string>
    <string>127.0.0.1:${port}</string>
    <string>run</string>
    <string>--token-file</string>
    <string>${TUNNEL_TOKEN_FILE}</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>${HOME}/Library/Logs/${label}.log</string>
  <key>StandardErrorPath</key><string>${HOME}/Library/Logs/${label}.log</string>
</dict>
</plist>
PLIST
}

# tunnel_ready <colour> -- 0 when the replica's connector reports /ready.
tunnel_ready() {
  curl -fsS -m 3 "http://127.0.0.1:${TUNNEL_METRICS_PORT[$1]}/ready" >/dev/null 2>&1
}

wait_tunnel_ready() {
  local colour="$1" deadline=$((SECONDS + TUNNEL_READY_TIMEOUT))
  until tunnel_ready "$colour"; do
    if (( SECONDS >= deadline )); then
      error "$(tunnel_label "$colour") not ready after ${TUNNEL_READY_TIMEOUT}s (log: ~/Library/Logs/$(tunnel_label "$colour").log)"
      return 1
    fi
    sleep 5
  done
}

tunnel_loaded() { launchctl print "$(tunnel_domain)/$(tunnel_label "$1")" >/dev/null 2>&1; }

check_tunnel_token() {
  if [[ ! -f "$TUNNEL_TOKEN_FILE" ]]; then
    error "tunnel token missing: write it to ${TUNNEL_TOKEN_FILE}, mode 600 (docs/MACHINES.md)"
    return 1
  fi
  local mode
  mode=$(stat -f %Lp "$TUNNEL_TOKEN_FILE")
  if [[ "$mode" != "600" ]]; then
    error "tunnel token is mode ${mode}; run: chmod 600 ${TUNNEL_TOKEN_FILE}"
    return 1
  fi
}

# verify_tunnel <colour> -- plist installed as rendered, loaded, and ready.
verify_tunnel() {
  local colour="$1" plist
  plist=$(tunnel_plist "$colour")
  [[ -f "$plist" ]] || return 1
  diff -q <(render_tunnel_plist "$colour") "$plist" >/dev/null || return 1
  tunnel_loaded "$colour" && tunnel_ready "$colour"
}

# guard_other_ready <colour> -- refuse to touch <colour> unless the other
# colour is serving. The one rule: never both down.
guard_other_ready() {
  local other
  other=$(tunnel_other "$1")
  if ! tunnel_ready "$other"; then
    error "$(tunnel_label "$other") is not ready -- refusing to touch $1: a bad change could sever every connector. Fix ${other} first."
    return 1
  fi
}

# apply_tunnels -- converge both replicas, green then blue. A colour whose
# plist and state already match is left alone. On first install neither is
# loaded, so the guard is skipped for the first colour only.
apply_tunnels() {
  check_tunnel_token || return 1
  mkdir -p "${HOME}/Library/LaunchAgents" "${HOME}/Library/Logs"
  local colour plist domain
  domain=$(tunnel_domain)
  for colour in green blue; do
    if verify_tunnel "$colour"; then continue; fi
    if tunnel_loaded "$(tunnel_other "$colour")"; then guard_other_ready "$colour" || return 1; fi
    plist=$(tunnel_plist "$colour")
    render_tunnel_plist "$colour" > "$plist"
    launchctl bootout "${domain}/$(tunnel_label "$colour")" 2>/dev/null || true
    launchctl bootstrap "$domain" "$plist"
    wait_tunnel_ready "$colour" || return 1
    success "$(tunnel_label "$colour") ready on 127.0.0.1:${TUNNEL_METRICS_PORT[$colour]}"
  done
}

# roll_tunnels -- restart green, wait for ready, then blue. Run after a
# cloudflared upgrade so the replicas pick up the new binary.
roll_tunnels() {
  local colour
  for colour in green blue; do
    guard_other_ready "$colour" || return 1
    launchctl kickstart -k "$(tunnel_domain)/$(tunnel_label "$colour")"
    wait_tunnel_ready "$colour" || return 1
    success "$(tunnel_label "$colour") restarted and ready"
  done
}

show_tunnels() {
  local colour state
  for colour in blue green; do
    if ! tunnel_loaded "$colour"; then state="not loaded"
    elif tunnel_ready "$colour"; then state="ready"
    else state="loaded, not ready"; fi
    info "  $(tunnel_label "$colour")  127.0.0.1:${TUNNEL_METRICS_PORT[$colour]}  ${state}"
  done
}
