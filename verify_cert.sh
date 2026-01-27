#!/usr/bin/env bash
set -euo pipefail
umask 077

die() { echo "ERROR: $*" >&2; exit 1; }

# Allow only safe file name tokens for APP_NAME to avoid path traversal.
validate_name() {
  [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]] || die "Invalid APP_NAME '$1' (allowed: A-Za-z0-9._-)"
}

# Verify a certificate against this CA (optionally with CRL).
# Usage:
#   verify_cert.sh ./out/example.crt
#   USE_CRL=1 verify_cert.sh ./out/example.crt

[[ $# -eq 1 ]] || die "Usage: verify_cert.sh <CRT_PATH>"
CRT="$1"
[[ -f "$CRT" ]] || die "Not found: $CRT"

ARGS=()
if [[ "${USE_CRL:-0}" == "1" ]]; then
  [[ -f ./crl/crl.pem ]] || die "CRL not found: ./crl/crl.pem (run ./gen_crl.sh)"
  ARGS+=("-crl_check" "-CRLfile" "./crl/crl.pem")
fi

openssl verify -CAfile ./CA/ca.crt "${ARGS[@]}" "$CRT"
