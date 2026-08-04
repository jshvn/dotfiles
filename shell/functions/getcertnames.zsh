#!/bin/zsh

# =============================================================================
# shell/functions/getcertnames.zsh -- inspect a domain's TLS certificate
#
# Purpose:      Open a TLS connection to <domain>:443, print the certificate
#               Common Name and Subject Alternative Names. Accepts a URL as
#               readily as a bare domain.
# Depends on:   openssl, grep, sed, _dotfiles_url_host.
# Side effects: outbound TLS handshake to the requested host; stdout only.
# =============================================================================

function getcertnames() {    # getcertnames() prints a domain's TLS cert Common Name + SANs. ex: $ getcertnames github.com
	if [[ -z "${1}" ]]; then
		echo "ERROR: No domain specified." >&2
		return 1;
	fi
	# Reduce a URL to its host; a bare domain passes through untouched. The
	# connection is always made on 443, so a port in the input is discarded.
	local domain="$(_dotfiles_url_host "${1}")"

	# Permissive host/IP guard (matches geoip/vnc) before passing to openssl.
	# Applied to the parsed domain, not $1, so URL input is still accepted.
	if [[ ! "$domain" =~ ^[A-Za-z0-9.:_-]+$ ]]; then
		echo "ERROR: invalid domain: ${domain}" >&2
		return 2
	fi

	echo "Testing ${domain}…";
	echo ""; # newline

	local tmp=$(echo -e "GET / HTTP/1.0\nEOT" \
		| openssl s_client -connect "${domain}:443" -servername "${domain}" 2>&1);

	if [[ "${tmp}" = *"-----BEGIN CERTIFICATE-----"* ]]; then
		local certText=$(echo "${tmp}" \
			| openssl x509 -text -certopt "no_aux, no_header, no_issuer, no_pubkey, \
			no_serial, no_sigdump, no_signame, no_validity, no_version");
		echo "Common Name:";
		echo ""; # newline
		echo "${certText}" | grep "Subject:" | sed -e "s/^.*CN=//" | sed -e "s/\/emailAddress=.*//";
		echo ""; # newline
		echo "Subject Alternative Name(s):";
		echo ""; # newline
		echo "${certText}" | grep -A 1 "Subject Alternative Name:" \
			| sed -e "2s/DNS://g" -e "s/ //g" | tr "," "\n" | tail -n +2;
		return 0;
	else
		echo "ERROR: Certificate not found.";
		return 1;
	fi
}