#!/bin/zsh

# list of public ipv6 providers to query (tried in order)
local public_ipv6_providers=(
    "https://simpip.com"
	"https://ifconfig.co"
	"https://icanhazip.com"
)

# lookup machine local and public ipv6 addresses 
function ipv6lookup() {    # ipv6lookup() will list local and public IPv6 addresses. ex: $ ipv6lookup
	if command -v ifconfig >/dev/null 2>&1; then
		# macOS / BSD: parse inet6 lines, skip link-local (fe80) and localhost
		ifconfig | awk '/^[^[:space:]]+:/ { iface=$1; sub(/:$/,"",iface) } $1=="inet6" { addr=$2; sub(/%.*/,"",addr); if (addr!~"^fe80" && addr!="::1") print iface": "addr }'
	else
		echo "No suitable tool found (ifconfig) to list IPv6 addresses." >&2
		return 1
	fi

	# Public ipv6 address (try a list of providers that support ipv6) with short timeout
	local public_ipv6
	# iterate through configured providers until one returns a non-empty response
	for url in "${public_ipv6_providers[@]}"; do
		# --fail makes curl exit non-zero on HTTP errors; silence progress and limit time
		public_ipv6=$(curl -6 --silent --show-error --fail --max-time 3 "$url" 2>/dev/null) || public_ipv6=
		if [[ -n "$public_ipv6" ]]; then
			# normalize whitespace/newlines
			public_ipv6="${public_ipv6//[$'\r\n']/ }"
			break
		fi
	done
	if [[ -n "$public_ipv6" ]] && printf '%s' "$public_ipv6" | grep -Eq '^[0-9A-Fa-f:]+$' && [[ "$public_ipv6" == *:* ]]; then
		echo "Public IPv6: $public_ipv6"
	else
		echo "Public IPv6: (unavailable)"
	fi
}
