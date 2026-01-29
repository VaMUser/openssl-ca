#!/usr/bin/env bash
set -euo pipefail
umask 077

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
source ./lib.sh

# Verify certificate against CA (and CRL if present).

[[ $# -eq 1 ]] || die "Usage: verify.sh <cert.pem>"
CERT="$1"
[[ -f "$CERT" ]] || die "Not found: $CERT"

CA_CERT="./CA/ca.crt"
[[ -f "$CA_CERT" ]] || die "CA certificate not found: $CA_CERT"

if [[ -f ./crl/crl.pem ]]; then
  openssl verify -CAfile "$CA_CERT" -CRLfile ./crl/crl.pem -crl_check "$CERT"
else
  openssl verify -CAfile "$CA_CERT" "$CERT"
fi
