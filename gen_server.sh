#!/usr/bin/env bash
set -euo pipefail
umask 077

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
source ./lib.sh

# Generate and sign a TLS server certificate (CSR + CRT).

[[ $# -ge 1 ]] || die "Usage: gen_server.sh <APP_NAME> [-san \"DNS.1:app.local,IP.1:10.0.0.1\"]"
APP_NAME="$1"; shift
validate_name "$APP_NAME"

./create_server_csr.sh "$APP_NAME" "$@"
./sign_server_csr.sh "$APP_NAME"
