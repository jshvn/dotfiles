#!/bin/zsh

# list of public ipv4 providers to query (tried in order).
public_ipv4_providers=(
    "https://simpip.com"
	"https://ifconfig.co"
	"https://icanhazip.com"
)

# lookup machine local and public ipv4 addresses
function ipv4lookup() {    # ipv4lookup() will list local and public IPv4 addresses. ex: $ ipv4lookup
	if command -v ifconfig >/dev/null 2>&1; then
		# macOS / BSD: parse ifconfig output, skip loopback
		ifconfig | awk '/^[^[:space:]]+:/ { iface=$1; sub(/:$/,"",iface) } $1=="inet" && $2!="127.0.0.1" { print iface": "$2 }'
	else
		echo "No suitable tool found (ifconfig) to list IPv4 addresses." >&2
		return 1
	fi

	# Public ipv4 address (try a couple of providers, short timeout)
	local public_ipv4
	# iterate through configured providers until one returns a non-empty response
	for url in "${public_ipv4_providers[@]}"; do
		# --fail makes curl exit non-zero on HTTP errors; silence progress and limit time
		public_ipv4=$(curl -4 --silent --show-error --fail --max-time 3 "$url" 2>/dev/null) || public_ipv4=
		if [[ -n "$public_ipv4" ]]; then
			# normalize whitespace/newlines
			public_ipv4="${public_ipv4//[$'\r\n']/ }"
			break
		fi
	done
	if [[ -n "$public_ipv4" ]]; then
		echo "Public IPv4: $public_ipv4"
	else
		echo "Public IPv4: (unavailable)"
	fi
}