#!/usr/bin/env bash
set -euo pipefail
umask 077

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
source ./lib.sh


usage() {
  cat <<EOF
Usage: $(basename "$0") [--passin-stdin]

Generate (or refresh) the CRL at ./crl/crl.pem.

Options:
  --passin-stdin  Read CA key passphrase from STDIN (first line) and pass to OpenSSL.
  -h, --help      Show this help and exit.

Examples:
  $(basename "$0")
  printf '%s\n' 'secret' | $(basename "$0") --passin-stdin
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

PASSIN_MODE="prompt"
if [[ "${1:-}" == "--passin-stdin" ]]; then
  PASSIN_MODE="stdin"
  shift
fi

if [[ $# -gt 0 ]]; then
  usage >&2
  exit 2
fi

ensure_layout
mkdir -p crl

if [[ "$PASSIN_MODE" == "stdin" ]]; then
  IFS= read -r CA_PASS || CA_PASS=""
  printf '%s\n' "$CA_PASS" | openssl ca -config ./openssl.cnf -gencrl -passin stdin -out ./crl/crl.pem
else
  openssl ca -config ./openssl.cnf -gencrl -out ./crl/crl.pem
fi

chmod 0644 ./crl/crl.pem
echo "CRL generated: ./crl/crl.pem"
