#!/usr/bin/env bash
set -euo pipefail
umask 077

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
source ./lib.sh

# Generate and sign a mTLS client certificate (CSR + CRT) and export to PFX.
# Usage: gen_client.sh <NAME> [-san "DNS.1:alice.local,email.1:alice@example.com"]
#
# Output:
#   ./out/<NAME>.key   (encrypted by default; set ENCRYPT_KEY=0 to disable)
#   ./out/<NAME>.crt
#   ./out/<NAME>.pfx   (contains client cert + unencrypted private key + CA cert; protected by PFX password)
#
# The PFX password is set to the same value as the private-key passphrase (you enter it once).

[[ $# -ge 1 ]] || die "Usage: gen_client.sh <NAME> [-san \"DNS.1:alice.local\"]"

APP_NAME="$1"; shift
validate_name "$APP_NAME"

# Ask once for passphrase (only if key is encrypted)
PASS=""
if [[ "${ENCRYPT_KEY:-1}" != "0" ]]; then
  read -r -s -p "Enter passphrase for client private key / PFX: " PASS; echo
  [[ -n "$PASS" ]] || die "Empty passphrase is not allowed for encrypted key. Set ENCRYPT_KEY=0 if you need an unencrypted key."
  export CLIENT_KEY_PASS="$PASS"
fi

./create_client_csr.sh "$APP_NAME" "$@"
./sign_client_csr.sh "$APP_NAME"

KEY="./out/${APP_NAME}.key"
CRT="./out/${APP_NAME}.crt"
PFX="./out/${APP_NAME}.pfx"
CA_CRT="./CA/ca.crt"

[[ -f "$KEY" ]] || die "Key not found: $KEY"
[[ -f "$CRT" ]] || die "Certificate not found: $CRT"
[[ -f "$CA_CRT" ]] || die "CA certificate not found: $CA_CRT"

if [[ -f "$PFX" ]]; then
  [[ "${FORCE:-0}" == "1" ]] || die "PFX exists ($PFX). Set FORCE=1 to overwrite."
  rm -f "$PFX"
fi

# Export PKCS#12:
# - PFX password equals PASS (or empty if ENCRYPT_KEY=0 and PASS left empty)
# - Private key inside PFX is not separately passworded; it is protected by the PFX password.
if [[ "${ENCRYPT_KEY:-1}" != "0" ]]; then
  openssl pkcs12 -export     -inkey "$KEY" -passin pass:"$PASS"     -in "$CRT"     -certfile "$CA_CRT"     -out "$PFX"     -passout pass:"$PASS"
else
  openssl pkcs12 -export     -inkey "$KEY"     -in "$CRT"     -certfile "$CA_CRT"     -out "$PFX"     -passout pass:
fi

chmod 0600 "$PFX"
echo "Wrote: $PFX"
