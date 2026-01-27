#!/usr/bin/env bash
set -euo pipefail
umask 077

die() { echo "ERROR: $*" >&2; exit 1; }

# Allow only safe file name tokens for APP_NAME to avoid path traversal.
validate_name() {
  [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]] || die "Invalid APP_NAME '$1' (allowed: A-Za-z0-9._-)"
}

# Revoke a certificate and regenerate CRL.
# Usage:
#   revoke_cert.sh <APP_NAME>
#   revoke_cert.sh --file ./out/example.crt

if [[ $# -eq 2 && "$1" == "--file" ]]; then
  CRT="$2"
else
  [[ $# -eq 1 ]] || die "Usage: revoke_cert.sh <APP_NAME> | revoke_cert.sh --file <CRT_PATH>"
  APP_NAME="$1"
  validate_name "$APP_NAME"
  CRT="./out/${APP_NAME}.crt"
fi

[[ -f "$CRT" ]] || die "Certificate not found: $CRT"

mkdir -p crl
[[ -f crlnumber ]] || echo "01" > crlnumber

openssl ca -config ./openssl.cnf -revoke "$CRT"
./gen_crl.sh

echo "Revoked: $CRT"
