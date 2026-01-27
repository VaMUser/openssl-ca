#!/usr/bin/env bash
set -euo pipefail
umask 077

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
source ./lib.sh

# Legacy wrapper: create SERVER CSR (unencrypted key by default).
# Usage: create_csr.sh <APP_NAME> [-san "DNS.1:app.local,IP.1:10.0.0.1"]
exec ./create_server_csr.sh "$@"
