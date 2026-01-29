#!/usr/bin/env bash
set -euo pipefail
umask 077

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
source ./lib.sh

# Clean generated artifacts (safe by default).

# Usage:
#   clean.sh           # remove out/* and csr/* only
#   clean.sh --db      # also reset CA DB (index/serial/newcerts/crl) but keep CA key/cert
#   clean.sh --all     # remove EVERYTHING including CA key/cert

MODE="out"
if [[ $# -gt 0 ]]; then
  case "$1" in
    --db) MODE="db" ;;
    --all) MODE="all" ;;
    -h|--help)
      echo "Usage: $0 [--db|--all]"
      exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
fi

rm -f out/* csr/* 2>/dev/null || true

if [[ "$MODE" == "db" || "$MODE" == "all" ]]; then
  rm -f index.txt index.txt.old index.txt.attr index.txt.attr.old serial serial.old crlnumber crlnumber.old 2>/dev/null || true
  find newcerts -type f -delete 2>/dev/null || true
  rm -f crl/crl.pem 2>/dev/null || true
fi

if [[ "$MODE" == "all" ]]; then
  rm -f CA/ca.crt CA/private/ca.key 2>/dev/null || true
fi

echo "Cleaned (mode=$MODE)."
