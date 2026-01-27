#!/usr/bin/env bash
set -euo pipefail

CA_CERT="certs/ca.crt"
CRL="crl/ca.crl.pem"

if [ $# -ne 1 ]; then
  echo "Usage: $0 <cert.pem>"
  exit 1
fi

CERT="$1"

openssl verify \
  -CAfile "$CA_CERT" \
  -CRLfile "$CRL" \
  -crl_check \
  "$CERT"
