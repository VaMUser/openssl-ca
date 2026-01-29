#!/usr/bin/env bash
set -euo pipefail
umask 077

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
source ./lib.sh

# Revoke a certificate and regenerate CRL.

# Usage:
#   revoke.sh <APP_NAME>
#   revoke.sh --file ./out/example.crt

CRT=""
if [[ $# -eq 2 && "$1" == "--file" ]]; then
  CRT="$2"
elif [[ $# -eq 1 ]]; then
  APP_NAME="$1"; validate_name "$APP_NAME"
  CRT="./out/${APP_NAME}.crt"
else
  die "Usage: revoke.sh <APP_NAME> | revoke.sh --file <CRT_PATH>"
fi

[[ -f "$CRT" ]] || die "Certificate not found: $CRT"

openssl ca -config ./openssl.cnf -revoke "$CRT"
./gencrl.sh
echo "Revoked: $CRT"
