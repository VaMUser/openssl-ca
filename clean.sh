#!/usr/bin/env bash
set -euo pipefail
umask 077

die() { echo "ERROR: $*" >&2; exit 1; }

# Allow only safe file name tokens for APP_NAME to avoid path traversal.
validate_name() {
  [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]] || die "Invalid APP_NAME '$1' (allowed: A-Za-z0-9._-)"
}

# Remove generated artifacts. Does NOT remove .gitignore files.
rm -f index.txt index.txt.attr index.txt.attr.old index.txt.old
rm -f serial serial.old
rm -f crlnumber crlnumber.old
rm -f CA/ca.crt CA/private/ca.key

find newcerts -type f ! -name ".gitignore" -delete 2>/dev/null || true
find out -type f ! -name ".gitignore" -delete 2>/dev/null || true
find crl -type f ! -name ".gitignore" -delete 2>/dev/null || true

echo "Cleaned."
