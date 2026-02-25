#!/usr/bin/env bash
set -euo pipefail
umask 077

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
source ./lib.sh


usage() {
  cat <<EOF
Usage: $(basename "$0") [QUERY]

List revoked certificates (status=R) from index.txt.

Arguments:
  QUERY   Optional case-insensitive filter by:
         - CN (from subject)
         - app name (file column)
         - full subject (DN)

Options:
  -h, --help   Show this help and exit.

Examples:
  $(basename "$0")
  $(basename "$0") my-app
  $(basename "$0") example.com
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -gt 1 ]]; then
  usage >&2
  exit 2
fi

QUERY="${1:-}"

run_index_awk '
BEGIN{ ql = tolower(q) }
$1=="R"{
  file = $5
  dn   = $6
  cn   = cn_from_subject(dn)

  if (ql == "" ||
      index(tolower(cn), ql) ||
      index(tolower(file), ql) ||
      index(tolower(dn), ql)) {
    print
  }
}
' "$QUERY"
