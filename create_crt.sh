#!/usr/bin/env bash
set -euo pipefail
umask 077

die() { echo "ERROR: $*" >&2; exit 1; }

# Allow only safe file name tokens for APP_NAME to avoid path traversal.
validate_name() {
  [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]] || die "Invalid APP_NAME '$1' (allowed: A-Za-z0-9._-)"
}

# Convenience wrapper: create + sign a SERVER certificate by default.
# For client certs, use create_client_csr.sh + sign_client_csr.sh.

[[ $# -eq 1 ]] || die "Usage: create_crt.sh <APP_NAME>"
APP_NAME="$1"
validate_name "$APP_NAME"

SAN="${SAN:-}"
[[ -n "$SAN" ]] || die "SAN is required. Example: SAN='DNS:example.com,DNS:www.example.com,IP:10.0.0.10'"

SAN="$SAN" ./create_server_csr.sh "$APP_NAME"
./sign_server_csr.sh "$APP_NAME"
