#!/bin/zsh

# lookup machine local and public ipv4 addresses
function ipv4lookup() {    # ipv4lookup() will list local and public IPv4 addresses. ex: $ ipv4lookup
	if command -v ifconfig >/dev/null 2>&1; then
		# macOS / BSD: parse ifconfig output, skip loopback
		ifconfig | awk '/^[^[:space:]]+:/ { iface=$1; sub(/:$/,"",iface) } $1=="inet" && $2!="127.0.0.1" { print iface": "$2 }'
	else
		echo "No suitable tool found (ifconfig) to list IPv4 addresses." >&2
		return 1
	fi

	# Public IPv4 address (try a couple of providers, short timeout)
	local public_ipv4
	public_ipv4=$(curl -4 --silent --show-error --max-time 3 https://ifconfig.co 2>/dev/null || \
		curl -4 --silent --show-error --max-time 3 https://icanhazip.com 2>/dev/null || \
		curl -4 --silent --show-error --max-time 3 https://simpip.com 2>/dev/null || true)
	if [[ -n "$public_ipv4" ]]; then
		echo "Public IPv4: ${public_ipv4//[$'\r\n']/ }"
	else
		echo "Public IPv4: (unavailable)"
	fi
}