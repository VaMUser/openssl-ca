#!/usr/bin/env bash
set -euo pipefail
umask 077

die() { echo "ERROR: $*" >&2; exit 1; }

# Allow only safe file name tokens for APP_NAME to avoid path traversal.
validate_name() {
  [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]] || die "Invalid APP_NAME '$1' (allowed: A-Za-z0-9._-)"
}

# Generate (or refresh) CRL.
mkdir -p crl
[[ -f crlnumber ]] || echo "01" > crlnumber
touch index.txt
[[ -f serial ]] || echo "01" > serial

openssl ca -config ./openssl.cnf -gencrl -out ./crl/crl.pem
chmod 0644 ./crl/crl.pem
echo "CRL generated: ./crl/crl.pem"
