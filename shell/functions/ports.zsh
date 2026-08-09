#!/bin/zsh

# =============================================================================
# shell/functions/ports.zsh -- listening TCP socket lister
#
# Purpose:      Print listening TCP sockets (port, command, pid, user, bind
#               address) sorted by port, optionally filtered to one port or
#               service name. Only sockets visible to the current user are
#               shown; run under sudo to include other users' listeners.
# Depends on:   lsof, awk, sort, tput, whoami.
# Side effects: stdout only.
# =============================================================================

function ports() {    # ports() lists listening TCP ports and their owning process. ex: $ ports 3000
    local raw
    # -F emits one field per line (p=pid, c=command, L=user, n=address);
    # column output would misparse command names containing spaces.
    raw=$(lsof -nP -iTCP"${1:+:${1}}" -sTCP:LISTEN -FcpLn 2>/dev/null)

    if [[ -z "$raw" ]]; then
        echo "ERROR: no listening TCP sockets${1:+ on port ${1}} visible to $(whoami) -- sudo shows all users" >&2
        return 1
    fi

    echo "$(tput setaf 6)Listening TCP sockets:$(tput sgr0)"
    # Stage 1 flattens the field stream to one tab-separated row per socket
    # (deduping the extra fds lsof reports for a shared socket); sort orders
    # by port; stage 2 colors and column-aligns.
    printf '%s\n' "$raw" | awk '
        /^p/ { pid = substr($0, 2) }
        /^c/ { cmd = substr($0, 2) }
        /^L/ { user = substr($0, 2) }
        /^n/ {
            addr = substr($0, 2)
            port = addr; sub(/.*:/, "", port)
            bind = substr(addr, 1, length(addr) - length(port) - 1)
            if (!seen[pid ":" addr]++)
                printf "%s\t%s\t%s\t%s\t%s\n", port, cmd, pid, user, bind
        }' | sort -n | awk -F'\t' \
            -v yel="$(tput setaf 3)" -v dim="$(tput setaf 8)" -v rst="$(tput sgr0)" '
        BEGIN { printf "  %s%-6s  %-24s  %-7s  %-10s  %s%s\n", dim, "PORT", "COMMAND", "PID", "USER", "BIND", rst }
        { printf "  %s%-6s%s  %-24.24s  %-7s  %-10.10s  %s%s%s\n", yel, $1, rst, $2, $3, $4, dim, $5, rst }'
}
