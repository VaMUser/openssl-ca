#!/usr/bin/env bash
set -euo pipefail
umask 077

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
source ./lib.sh

usage() {
  cat <<EOF
Usage: $(basename "$0") <APP_NAME> [-san "DNS.1:app.local,IP.1:10.0.0.1"]

Create CSR + private key for a TLS server certificate.

Options:
  -san <SAN>   SubjectAltName entries. If omitted, defaults to:
              DNS.1:<APP_NAME>.<dns_suffix>
  -h, --help   Show this help and exit.

Env:
  ENCRYPT_KEY=1        Encrypt private key (default: 0 / unencrypted).
  SERVER_KEY_PASS=...  Provide key passphrase via env (otherwise prompts).
  FORCE=1              Overwrite existing output files.
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




# Create CSR + private key for a TLS server certificate.

# Usage: create_server_csr.sh <APP_NAME> [-san "DNS.1:app.local,IP.1:10.0.0.1"]
# Default SAN if omitted: DNS:<APP_NAME>.<dns_suffix>
# Default: unencrypted key. Set ENCRYPT_KEY=1 to encrypt.

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

SUBJ="$(build_subj "$APP_NAME" 0)"

if [[ "${ENCRYPT_KEY:-0}" == "1" ]]; then
  PASS="${SERVER_KEY_PASS:-}"
  if [[ -z "$PASS" ]]; then
    read -r -s -p "Enter passphrase for server private key: " PASS; echo
  fi
  [[ -n "$PASS" ]] || die "Empty passphrase is not allowed."
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
