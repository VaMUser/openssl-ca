#!/usr/bin/env bash
set -euo pipefail
umask 077

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
source ./lib.sh


usage() {
  cat <<EOF
Usage:
  $(basename "$0") <APP_NAME>
  $(basename "$0") --file <CRT_PATH>

Revoke a certificate and regenerate CRL.

Options:
  --file <CRT_PATH>  Revoke a specific certificate file (e.g. ./out/app.crt).
  -h, --help         Show this help and exit.

Notes:
  The CA key passphrase is requested only once and reused for both
  revocation and CRL regeneration.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

CRT=""
if [[ $# -eq 2 && "$1" == "--file" ]]; then
  CRT="$2"
elif [[ $# -eq 1 ]]; then
  APP_NAME="$1"
  validate_name "$APP_NAME"
  CRT="./out/${APP_NAME}.crt"
else
  usage >&2
  exit 2
fi

[[ -f "$CRT" ]] || die "Certificate not found: $CRT"

# Read passphrase once (no echo).
read -r -s -p "Enter CA key passphrase: " CA_PASS
echo

# Revoke (feed passphrase via stdin so it doesn't end up in args/env).
printf '%s\n' "$CA_PASS" | openssl ca -config ./openssl.cnf -revoke "$CRT" -passin stdin

# Regenerate CRL using the same passphrase.
printf '%s\n' "$CA_PASS" | ./gencrl.sh --passin-stdin

echo "Revoked: $CRT"
