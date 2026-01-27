#!/usr/bin/env bash
set -euo pipefail
umask 077

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
source ./lib.sh

# Create CSR + private key for a TLS server certificate.
# Usage: create_server_csr.sh <APP_NAME> [-san "DNS.1:app.local,IP.1:10.0.0.1"]
# If -san is omitted, defaults to DNS:<APP_NAME>.<dns_suffix> (dns_suffix from [script_defaults] in openssl.cnf).

[[ $# -ge 1 ]] || die "Usage: create_server_csr.sh <APP_NAME> [-san \"DNS.1:app.local,IP.1:10.0.0.1\"]"
APP_NAME="$1"; shift
validate_name "$APP_NAME"

SAN_ARG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -san|-san:*)
      if [[ "$1" == -san:* ]]; then SAN_ARG="${1#-san:}"; shift;
      else shift; SAN_ARG="${1:-}"; shift || true; fi
      ;;
    *) die "Unknown argument: $1" ;;
  esac
done

# Determine default SAN if not provided
if [[ -z "$SAN_ARG" ]]; then
  DNS_SUFFIX="$(awk 'BEGIN{sec=0} /^[[:space:]]*\[/{sec=0} /^[[:space:]]*\[script_defaults\][[:space:]]*$/ {sec=1; next} sec==1 {sub(/[;#].*$/, "", $0); if ($0 ~ /^[[:space:]]*dns_suffix[[:space:]]*=/) {sub(/.*=/,""); gsub(/^[[:space:]]+|[[:space:]]+$/, ""); print; exit}}' ./openssl.cnf)"
  [[ -n "$DNS_SUFFIX" ]] || DNS_SUFFIX="local"
  SAN_ARG="DNS.1:${APP_NAME}.${DNS_SUFFIX}"
fi
SAN="$(normalize_san "$SAN_ARG")"

KEY="./out/${APP_NAME}.key"
CSR="./out/${APP_NAME}.csr"

if [[ -f "$KEY" || -f "$CSR" ]]; then
  [[ "${FORCE:-0}" == "1" ]] || die "Output exists ($KEY or $CSR). Set FORCE=1 to overwrite."
  rm -f "$KEY" "$CSR"
fi

KEYOPT="-nodes"
if [[ "${ENCRYPT_KEY:-0}" == "1" ]]; then
  KEYOPT="-aes256"
fi

SAN="$SAN" openssl req \
  -config ./openssl.cnf \
  -new \
  -newkey rsa:3072 $KEYOPT \
  -keyout "$KEY" \
  -out "$CSR" \
  -reqexts req_ext

chmod 0600 "$KEY"
chmod 0644 "$CSR"
echo "Wrote: $KEY"
echo "Wrote: $CSR"
echo "SAN:  $SAN"
