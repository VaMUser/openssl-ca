#!/usr/bin/env bash
set -euo pipefail
umask 077

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
source ./lib.sh


usage() {
  cat <<EOF
Usage: $(basename "$0") <APP_NAME>

Sign an existing CSR as a TLS client certificate.

Inputs:
  ./out/<APP_NAME>.csr

Outputs:
  - OpenSSL output dir: ./newcerts/<SERIAL>.pem
  - Convenience symlink: ./out/<SERIAL>_<CN>.crt  (created automatically)

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

APP_NAME="$1"
validate_name "$APP_NAME"

ensure_layout

CSR="./out/${APP_NAME}.csr"
[[ -f "$CSR" ]] || die "CSR not found: $CSR"

OUTDIR="./newcerts"
LINKDIR="./out"

# Issue certificate into OUTDIR as <SERIAL>.pem (OpenSSL standard for -outdir).
# Then create missing symlinks in LINKDIR as <SERIAL>_<CN>.crt for easy access.
openssl ca -batch -config ./openssl.cnf -extensions usr_cert -in "$CSR" -outdir "$OUTDIR" -out /dev/null

ensure_recent_links "$OUTDIR" "$LINKDIR" 5

# Best-effort: show the latest link matching this APP_NAME.
latest_link="$(ls -1t "$LINKDIR"/*_"$APP_NAME".crt 2>/dev/null | head -n1 || true)"
if [[ -n "$latest_link" ]]; then
  echo "OK: $latest_link"
else
  echo "OK: issued in $OUTDIR (link will be named <SERIAL>_<CN>.crt)"
fi
