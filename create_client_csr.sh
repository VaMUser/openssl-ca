#!/usr/bin/env bash
set -euo pipefail

get_default() {
  # Reads *_default values from openssl.cnf (simple parser)
  # Usage: get_default "countryName_default"
  local key="$1"
  awk -F '=' -v k="$key" '
    $1 ~ "^[[:space:]]*"k"[[:space:]]*$" {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2);
      print $2; exit
    }' openssl.cnf
}

build_subj() {
  local cn="$1"
  local C ST L O OU EMAIL
  C="$(get_default countryName_default || true)"
  ST="$(get_default stateOrProvinceName_default || true)"
  L="$(get_default localityName_default || true)"
  # organizationName_default may be written as 0.organizationName_default
  O="$(get_default 0.organizationName_default || true)"
  [ -z "$O" ] && O="$(get_default organizationName_default || true)"
  OU="$(get_default organizationalUnitName_default || true)"
  EMAIL="$(get_default emailAddress_default || true)"

  local subj=""
  [ -n "$C" ] && subj="${subj}/C=${C}"
  [ -n "$ST" ] && subj="${subj}/ST=${ST}"
  [ -n "$L" ] && subj="${subj}/L=${L}"
  [ -n "$O" ] && subj="${subj}/O=${O}"
  [ -n "$OU" ] && subj="${subj}/OU=${OU}"
  subj="${subj}/CN=${cn}"
  [ -n "$EMAIL" ] && subj="${subj}/emailAddress=${EMAIL}"
  echo "$subj"
}

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

KEYOPT="-aes256"
PASS="${CLIENT_KEY_PASS:-}"
if [[ "${ENCRYPT_KEY:-1}" == "0" ]]; then
  KEYOPT="-nodes"
else
  # Read passphrase once to avoid multiple prompts later (also used for PFX in gen_client.sh).
  if [[ -z "$PASS" ]]; then
    read -r -s -p "Enter passphrase for client private key: " PASS; echo
  fi
  [[ -n "$PASS" ]] || die "Empty passphrase is not allowed for encrypted key. Set ENCRYPT_KEY=0 if you need an unencrypted key."
fi

if [[ "$KEYOPT" == "-aes256" ]]; then
  openssl req \
    -config ./openssl.cnf \
    -new \
  -subj "$(build_subj "$NAME")" \
  -addext "subjectAltName=${SAN}" \
    -newkey rsa:3072 -aes256 -passout pass:"$PASS" \
    -keyout "$KEY" \
    -out "$CSR" \
    -reqexts req_ext
else
  openssl req \
    -config ./openssl.cnf \
    -new \
  -subj "$(build_subj "$NAME")" \
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
