#!/bin/zsh

# =============================================================================
# shell/functions/getcertnames.zsh -- inspect a domain's TLS certificate
#
# Purpose:      Open a TLS connection to <domain>:443, print the certificate
#               Common Name and Subject Alternative Names.
# Depends on:   openssl, grep, sed.
# Side effects: outbound TLS handshake to the requested host; stdout only.
# =============================================================================

function getcertnames() {    # getcertnames() prints a domain's TLS cert Common Name + SANs. ex: $ getcertnames github.com
	if [[ -z "${1}" ]]; then
		echo "ERROR: No domain specified." >&2
		return 1;
	fi
	# Permissive host/IP guard (matches geoip/vnc) before passing to openssl.
	if [[ ! "${1}" =~ ^[A-Za-z0-9.:_-]+$ ]]; then
		echo "ERROR: invalid domain: ${1}" >&2
		return 2
	fi

	local domain="${1}";
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