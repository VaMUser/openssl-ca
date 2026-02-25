#!/usr/bin/env bash
set -euo pipefail
umask 077

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
source ./lib.sh


usage() {
  cat <<EOF
Usage: $(basename "$0") <APP_NAME> [-san "DNS.1:app.local,IP.1:10.0.0.1"]

Generate and sign a TLS server certificate (CSR + CRT).

Outputs:
  - OpenSSL output dir: ./newcerts/<SERIAL>.pem
  - Convenience symlink: ./out/<SERIAL>_<CN>.crt

Options:
  -san <SAN>   SubjectAltName entries. Example:
              "DNS.1:app.local,IP.1:10.0.0.1"
  -h, --help   Show this help and exit.

Env:
  FORCE=1      Overwrite existing output files (where applicable).
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 2
fi

APP_NAME="$1"; shift
validate_name "$APP_NAME"

./create_server_csr.sh "$APP_NAME" "$@"
./sign_server_csr.sh "$APP_NAME"

latest_link="$(ls -1t ./out/*_"$APP_NAME".crt 2>/dev/null | head -n1 || true)"
if [[ -n "$latest_link" ]]; then
  echo "OK: $latest_link"
else
  echo "OK: issued in ./newcerts (link will be named <SERIAL>_<CN>.crt)"
fi
