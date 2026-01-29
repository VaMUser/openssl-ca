#!/usr/bin/env bash
set -euo pipefail
umask 077

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
source ./lib.sh

# Generate (or refresh) CRL.

ensure_layout
mkdir -p crl
openssl ca -config ./openssl.cnf -gencrl -out ./crl/crl.pem
chmod 0644 ./crl/crl.pem
echo "CRL generated: ./crl/crl.pem"
