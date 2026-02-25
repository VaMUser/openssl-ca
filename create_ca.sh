#!/usr/bin/env bash
set -euo pipefail
umask 077

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
source ./lib.sh


usage() {
  cat <<EOF
Usage: $(basename "$0") [--cn "My CA"]

Create a single-tier (self-signed) CA certificate and private key.

Options:
  --cn <CN>    Override CA Common Name (CN).
  -h, --help   Show this help and exit.

Notes:
  You will be prompted for the CA key passphrase.
EOF
}

CN_OVERRIDE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage; exit 0 ;;
    --cn)
      shift; CN_OVERRIDE="${1:-}"; shift || true ;;
    --cn=*)
      CN_OVERRIDE="${1#*=}"; shift ;;
    *)
      usage >&2; exit 2 ;;
  esac
done

ensure_layout

CA_KEY="./CA/private/ca.key"
CA_CRT="./CA/ca.crt"

if [[ -f "$CA_KEY" || -f "$CA_CRT" ]]; then
  [[ "${FORCE:-0}" == "1" ]] || die "CA already exists. Set FORCE=1 to overwrite."
  rm -f "$CA_KEY" "$CA_CRT"
fi

CN="${CN_OVERRIDE:-$(conf_get_or_default ca cn "Local CA")}"

openssl req -new -x509 -days 3650 -newkey rsa:4096 \
  -keyout "$CA_KEY" -out "$CA_CRT" \
  -subj "/CN=${CN}" \
  -sha256

chmod 600 "$CA_KEY"
chmod 644 "$CA_CRT"

echo "OK: $CA_CRT"
