#!/usr/bin/env bash
set -euo pipefail
umask 077

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
source ./lib.sh

# Create a single-tier CA (self-signed CA certificate).

# Usage: create_ca.sh [--cn "My CA"]
# Prompts for CA key passphrase.

CN_OVERRIDE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cn)
      shift; CN_OVERRIDE="${1:-}"; shift || true ;;
    --cn=*)
      CN_OVERRIDE="${1#--cn=}"; shift ;;
    -h|--help)
      echo "Usage: $0 [--cn \"My CA\"]"
      exit 0 ;;
    *)
      die "Unknown argument: $1" ;;
  esac
done

ensure_layout

if [[ -f CA/private/ca.key || -f CA/ca.crt ]]; then
  [[ "${FORCE:-0}" == "1" ]] || die "CA already exists (CA/private/ca.key or CA/ca.crt). Set FORCE=1 to overwrite."
  rm -f CA/private/ca.key CA/ca.crt
fi

CA_CN="${CN_OVERRIDE:-$(conf_get_or_default script_defaults ca_common_name "Local CA")}"
SUBJ="$(build_subj "$CA_CN" 0)"

openssl req \
  -config ./openssl.cnf \
  -new -x509 \
  -days 3650 \
  -extensions v3_ca \
  -subj "$SUBJ" \
  -keyout CA/private/ca.key \
  -out CA/ca.crt

chmod 0600 CA/private/ca.key
chmod 0644 CA/ca.crt
echo "CA created:"
echo "  Key:  CA/private/ca.key"
echo "  Cert: CA/ca.crt"
