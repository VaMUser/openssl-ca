#!/usr/bin/env bash
set -euo pipefail
umask 077

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
source ./lib.sh


usage() {
  cat <<EOF
Usage: $(basename "$0") [--db|--all]

Clean generated artifacts.

Modes:
  (default)   Remove ./out/* and ./csr/*
  --db        Also reset CA database (index/serial/newcerts/crl), keep CA key/cert
  --all       Remove everything including CA key/cert

Options:
  -h, --help  Show this help and exit.
EOF
}

MODE="out"
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -gt 1 ]]; then
  usage >&2
  exit 2
fi

if [[ $# -eq 1 ]]; then
  case "$1" in
    --db) MODE="db" ;;
    --all) MODE="all" ;;
    *) usage >&2; exit 2 ;;
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
