#!/bin/zsh

# =============================================================================
# shell/functions/vnc.zsh -- launch macOS Screen Sharing against a host
#
# Purpose:      Open a `vnc://<host>` URL via macOS `open`; input is
#               validated against a permissive host/IP regex before
#               interpolation. A `<machine>-vnc.jgrid.net` host is a
#               Cloudflare Tunnel ingress (tcp://127.0.0.1:5900 on the
#               machine, gated by the *.jgrid.net Access app): cloudflared
#               proxies it onto 127.0.0.1:5901 and Screen Sharing opens that.
# Depends on:   open (macOS); cloudflared at $HOMEBREW_PREFIX/bin
#               (manifests/base.toml); nc.
# Side effects: launches Screen Sharing or the default vnc:// handler; for a
#               tunnel host, leaves a background `cloudflared access tcp`
#               listening on 127.0.0.1:5901 (reused on the next call).
# =============================================================================

function vnc() {    # vnc() opens Screen Sharing to a host; <m>-vnc.jgrid.net rides its Cloudflare tunnel. ex: $ vnc atium-vnc.jgrid.net
    if [[ -z "${1}" ]]; then
        echo "ERROR: No domain specified." >&2
        return 1
    fi
    if [[ ! "${1}" =~ ^[A-Za-z0-9.:_-]+$ ]]; then
        echo "ERROR: invalid host/ip: ${1}" >&2
        return 2
    fi
    if [[ "${1}" != *-vnc.jgrid.net ]]; then
        open "vnc://${1}"
        return
    fi

    # ponytail: one fixed local port, so one tunnel-fronted VNC host at a time;
    # a per-host port map is the upgrade if a second such host ever exists.
    local port=5901
    if ! pgrep -qf "cloudflared access tcp --hostname ${1} "; then
        "${HOMEBREW_PREFIX}/bin/cloudflared" access tcp --hostname "${1}" --url "127.0.0.1:${port}" >/dev/null 2>&1 &!
        local tries=0
        until nc -z 127.0.0.1 "${port}" >/dev/null 2>&1; do
            if (( ++tries > 50 )); then
                echo "ERROR: cloudflared did not start listening on 127.0.0.1:${port} for ${1}" >&2
                return 3
            fi
            sleep 0.2
        done
    fi
    open "vnc://127.0.0.1:${port}"
}
