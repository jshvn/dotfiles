#!/bin/zsh

# lookup machine local and public ipv6 addresses 
function ipv6lookup() {    # ipv6lookup() will list local and public IPv6 addresses. ex: $ ipv6lookup
	if command -v ifconfig >/dev/null 2>&1; then
		# macOS / BSD: parse inet6 lines, skip link-local (fe80) and localhost
		ifconfig | awk '/^[^[:space:]]+:/ { iface=$1; sub(/:$/,"",iface) } $1=="inet6" { addr=$2; sub(/%.*/,"",addr); if (addr!~"^fe80" && addr!="::1") print iface": "addr }'
	else
		echo "No suitable tool found (ifconfig) to list IPv6 addresses." >&2
		return 1
	fi

	# Public IPv6 address (try providers that support IPv6) with short timeout
	local public_ipv6
	public_ipv6=$(curl -6 --silent --show-error --max-time 3 https://ifconfig.co 2>/dev/null || \
		curl -6 --silent --show-error --max-time 3 https://icanhazip.com 2>/dev/null || true)
    if [[ -n "$public_ipv6" ]] && printf '%s' "$public_ipv6" | grep -Eq '^[0-9A-Fa-f:]+$' && [[ "$public_ipv6" == *:* ]]; then
        echo "Public IPv6: ${public_ipv6//[$'\r\n']/ }"
	else
		echo "Public IPv6: (unavailable)"
	fi
}
