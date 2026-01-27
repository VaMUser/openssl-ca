#!/usr/bin/env bash
set -euo pipefail
umask 077

die() { echo "ERROR: $*" >&2; exit 1; }

# Allow only safe file name tokens for APP_NAME to avoid path traversal.
validate_name() {
  [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]] || die "Invalid APP_NAME '$1' (allowed: A-Za-z0-9._-)"
}

# Create a single-tier CA (self-signed CA certificate).
# Prompts for CA key passphrase.

[[ $# -eq 0 ]] || die "Usage: create_ca.sh (no arguments)"

mkdir -p CA/private newcerts out crl
touch index.txt
[[ -f serial ]] || echo "01" > serial
[[ -f crlnumber ]] || echo "01" > crlnumber

if [[ -f CA/private/ca.key || -f CA/ca.crt ]]; then
  [[ "${FORCE:-0}" == "1" ]] || die "CA already exists (CA/private/ca.key or CA/ca.crt). Set FORCE=1 to overwrite."
  rm -f CA/private/ca.key CA/ca.crt
fi

openssl req -new -x509 -days 3650 \
  -config ./openssl.cnf \
  -extensions v3_ca \
  -keyout ./CA/private/ca.key \
  -out ./CA/ca.crt

chmod 0600 ./CA/private/ca.key
chmod 0644 ./CA/ca.crt

echo "CA created:"
openssl x509 -in ./CA/ca.crt -noout -subject -issuer -dates
