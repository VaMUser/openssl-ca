#!/usr/bin/env bash
set -euo pipefail
umask 077

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
source ./lib.sh

# Sign an existing CSR as a TLS client certificate.
# Prompts for CA key passphrase.

[[ $# -eq 1 ]] || die "Usage: sign_client_csr.sh <APP_NAME>"
APP_NAME="$1"
validate_name "$APP_NAME"

CSR="./out/${APP_NAME}.csr"
CRT="./out/${APP_NAME}.crt"
[[ -f "$CSR" ]] || die "CSR not found: $CSR"
if [[ -f "$CRT" ]]; then
  [[ "${FORCE:-0}" == "1" ]] || die "Certificate exists ($CRT). Set FORCE=1 to overwrite."
  rm -f "$CRT"
fi

openssl ca \
  -config ./openssl.cnf \
  -extensions client_cert \
  -in "$CSR" \
  -out "$CRT" \
  -batch

chmod 0644 "$CRT"
echo "Wrote: $CRT"
