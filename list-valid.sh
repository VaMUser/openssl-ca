#!/usr/bin/env bash
set -euo pipefail
umask 077

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
source ./lib.sh


usage() {
  cat <<EOF
Usage: $(basename "$0") [QUERY]

List valid certificates (status=V) from index.txt.

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
function fmt_time(s,   yy,y,mm,dd,HH,MM,SS) {
  if (s == "" || s == "-") return "-"
  yy = substr(s,1,2) + 0
  y  = (yy < 50) ? (2000 + yy) : (1900 + yy)
  mm = substr(s,3,2) + 0
  dd = substr(s,5,2) + 0
  HH = substr(s,7,2) + 0
  MM = substr(s,9,2) + 0
  SS = substr(s,11,2) + 0
  return sprintf("%04d-%02d-%02d %02d:%02d:%02dZ", y, mm, dd, HH, MM, SS)
}
BEGIN{
  ql = tolower(q)
  printf "%-7s %-8s %-20s %-20s %-30s %s\n", "STATUS", "SERIAL", "EXPIRES(UTC)", "REVOKED(UTC)", "CN", "FILE"
}
$1=="V"{
  status = $1
  expiry = $2
  revoked = $3
  serial = $4
  file = $5
  dn   = $6
  cn   = cn_from_subject(dn)

  if (ql == "" ||
      index(tolower(cn), ql) ||
      index(tolower(file), ql) ||
      index(tolower(dn), ql)) {
    printf "%-7s %-8s %-20s %-20s %-30s %s\n", "VALID", tolower(serial), fmt_time(expiry), fmt_time(revoked), cn, file
  }
}
' "$QUERY"
