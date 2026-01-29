#!/usr/bin/env bash
set -euo pipefail
umask 077

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
source ./lib.sh

# Create CSR + private key for a mTLS client certificate.

# Usage: create_client_csr.sh <NAME> [-san "DNS.1:alice.local,email.1:alice@example.com"]
# Default SAN if omitted: DNS:<NAME>.<dns_suffix>
# Default: encrypted key. Set ENCRYPT_KEY=0 for unencrypted key.

[[ $# -ge 1 ]] || die "Usage: create_client_csr.sh <NAME> [-san \"DNS.1:alice.local\"]"
APP_NAME="$1"; shift
validate_name "$APP_NAME"

SAN_ARG="$(parse_san_arg "$@")"
DNS_SUFFIX="$(conf_get_or_default script_defaults dns_suffix local)"
if [[ -z "$SAN_ARG" ]]; then
  SAN_ARG="DNS.1:${APP_NAME}.${DNS_SUFFIX}"
fi
SAN="$(normalize_san "$SAN_ARG")"

ensure_layout

KEY="./out/${APP_NAME}.key"
CSR="./out/${APP_NAME}.csr"

if [[ -f "$KEY" || -f "$CSR" ]]; then
  [[ "${FORCE:-0}" == "1" ]] || die "Output exists ($KEY or $CSR). Set FORCE=1 to overwrite."
  rm -f "$KEY" "$CSR"
fi

SUBJ="$(build_subj "$APP_NAME" 1)"

KEYOPT="-aes256"
PASS="${CLIENT_KEY_PASS:-}"
if [[ "${ENCRYPT_KEY:-1}" == "0" ]]; then
  KEYOPT="-nodes"
else
  if [[ -z "$PASS" ]]; then
    read -r -s -p "Enter passphrase for client private key: " PASS; echo
  fi
  [[ -n "$PASS" ]] || die "Empty passphrase is not allowed for encrypted key. Set ENCRYPT_KEY=0 if you need an unencrypted key."
fi

if [[ "$KEYOPT" == "-aes256" ]]; then
  openssl req \
    -config ./openssl.cnf \
    -new \
    -subj "$SUBJ" \
    -addext "subjectAltName=${SAN}" \
    -newkey rsa:3072 -aes256 -passout pass:"$PASS" \
    -keyout "$KEY" \
    -out "$CSR" \
    -reqexts req_ext
else
  openssl req \
    -config ./openssl.cnf \
    -new \
    -subj "$SUBJ" \
    -addext "subjectAltName=${SAN}" \
    -newkey rsa:3072 -nodes \
    -keyout "$KEY" \
    -out "$CSR" \
    -reqexts req_ext
fi

chmod 0600 "$KEY"
chmod 0644 "$CSR"
echo "Wrote: $KEY"
echo "Wrote: $CSR"
echo "SAN:  $SAN"
