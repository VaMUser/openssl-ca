#!/usr/bin/env bash
set -euo pipefail
umask 077

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
source ./lib.sh


usage() {
  cat <<EOF
Usage: $(basename "$0") <CN|APP|SERIAL>

Search certificate records in index.txt.

Search rules:
  - If the argument looks like a hex serial, match by serial (exact, case-insensitive)
  - Otherwise match by substring (case-insensitive) in:
      * CN (from subject)
      * app name (file column)
      * full subject (DN)

Options:
  -h, --help   Show this help and exit.

Examples:
  $(basename "$0") 01AF3C
  $(basename "$0") my-app
  $(basename "$0") example.com
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

QUERY="$1"

run_index_awk '
BEGIN{
  q_raw = q
  ql = tolower(q)
  q_is_serial = is_hex_serial(q_raw)
}
{
  serial = $4
  file = $5
  dn = $6
  cn = cn_from_subject(dn)

  hit = 0
  if (q_is_serial) {
    if (tolower(serial) == tolower(q_raw)) hit = 1
  } else {
    if (index(tolower(cn), ql) ||
        index(tolower(file), ql) ||
        index(tolower(dn), ql)) hit = 1
  }

  if (hit) print
}
' "$QUERY"
