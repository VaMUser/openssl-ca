#!/usr/bin/env bash
set -euo pipefail
umask 077

die() { echo "ERROR: $*" >&2; exit 1; }

# Allow only safe file name tokens for APP_NAME to avoid path traversal.
validate_name() {
  [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]] || die "Invalid APP_NAME '$1' (allowed: A-Za-z0-9._-)"
}

# Legacy wrapper (kept for compatibility): signs as SERVER certificate.
# Prefer sign_server_csr.sh or sign_client_csr.sh.

[[ $# -eq 1 ]] || die "Usage: sign_csr.sh <APP_NAME>"
APP_NAME="$1"
validate_name "$APP_NAME"

./sign_server_csr.sh "$APP_NAME"
