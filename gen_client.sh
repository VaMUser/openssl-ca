#!/usr/bin/env bash
set -euo pipefail
umask 077

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
source ./lib.sh

usage() {
  cat <<EOF
Usage: $(basename "$0") <NAME> [-san "DNS.1:alice.local,email.1:alice@example.com"]

Generate and sign a mTLS client certificate (CSR + CRT) and export to PFX.

Outputs:
  ./out/<NAME>.key
  ./out/<SERIAL>_<CN>.crt   (symlink)
  ./out/<NAME>.pfx

Options:
  -san <SAN>   SubjectAltName entries (passed to CSR creation).
  -h, --help   Show this help and exit.

Env:
  FORCE=1              Overwrite existing output files.
  ENCRYPT_KEY=0|1      See create_client_csr.sh
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 2
fi




# Generate and sign a mTLS client certificate (CSR + CRT) and export to PFX.

# Usage: gen_client.sh <NAME> [-san "..."]
#
# Output:
#   ./out/<NAME>.key
#   ./out/<SERIAL>_<CN>.crt
#   ./out/<NAME>.pfx   (contains client cert + private key + CA cert; protected by PFX password)

APP_NAME="$1"; shift
validate_name "$APP_NAME"

PASS=""

# Ask once for passphrase (only if key is encrypted)
if [[ "${ENCRYPT_KEY:-1}" != "0" ]]; then
  read -r -s -p "Enter passphrase for client private key / PFX: " PASS; echo
  [[ -n "$PASS" ]] || die "Empty passphrase is not allowed for encrypted key. Set ENCRYPT_KEY=0 if you need an unencrypted key."
  export CLIENT_KEY_PASS="$PASS"
fi

./create_client_csr.sh "$APP_NAME" "$@"
./sign_client_csr.sh "$APP_NAME"

KEY="./out/${APP_NAME}.key"
CRT="$(ls -1t ./out/*_"$APP_NAME".crt 2>/dev/null | head -n1 || true)"
PFX="./out/${APP_NAME}.pfx"
CA_CRT="./CA/ca.crt"

[[ -f "$KEY" ]] || die "Key not found: $KEY"
[[ -n "$CRT" && -f "$CRT" ]] || die "Certificate not found (expected symlink ./out/<SERIAL>_${APP_NAME}.crt)"
[[ -f "$CA_CRT" ]] || die "CA certificate not found: $CA_CRT"

if [[ -f "$PFX" ]]; then
  [[ "${FORCE:-0}" == "1" ]] || die "PFX exists ($PFX). Set FORCE=1 to overwrite."
  rm -f "$PFX"
fi

if [[ "${ENCRYPT_KEY:-1}" != "0" ]]; then
  openssl pkcs12 -export \
    -inkey "$KEY" -passin pass:"$PASS" \
    -in "$CRT" \
    -certfile "$CA_CRT" \
    -out "$PFX" \
    -passout pass:"$PASS"
else
  openssl pkcs12 -export \
    -inkey "$KEY" \
    -in "$CRT" \
    -certfile "$CA_CRT" \
    -out "$PFX" \
    -passout pass:
fi

chmod 0600 "$PFX"
echo "Wrote: $PFX"
