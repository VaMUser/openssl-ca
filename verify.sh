#!/usr/bin/env bash
set -euo pipefail
umask 077

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
source ./lib.sh


usage() {
  cat <<EOF
Usage: $(basename "$0") <cert.pem>

Verify certificate against the CA. If CRL exists, verifies against CRL too.

Options:
  -h, --help   Show this help and exit.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 2
fi

CERT="$1"
[[ -f "$CERT" ]] || die "Not found: $CERT"

CA_CERT="./CA/ca.crt"
[[ -f "$CA_CERT" ]] || die "CA certificate not found: $CA_CERT"

CRL="./crl/crl.pem"
if [[ -f "$CRL" ]]; then
  openssl verify -CAfile "$CA_CERT" -CRLfile "$CRL" -crl_check "$CERT"
else
  openssl verify -CAfile "$CA_CERT" "$CERT"
fi
