#!/usr/bin/env bash
set -euo pipefail
umask 077

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
source ./lib.sh

# Search CA database (index.txt) by serial or CN.

[[ $# -eq 1 ]] || die "Usage: status.sh <CN|serial>"
Q="$1"

# OpenSSL index.txt format fields are tab-separated:
# status \t expiry \t revocation \t serial \t filename \t subject
awk -F '\t' -v q="$Q" '
  function cn(subject,   n, a, rest) {
    n=split(subject, a, "/CN=");
    if (n<2) return "";
    rest=a[2];
    sub(/\/.*/, "", rest);
    return rest;
  }
  {
    s=$4; subj=$6; thecn=cn(subj);
    if (toupper(s)==toupper(q) || thecn==q || index(subj, q)>0) {
      print $0;
      found=1;
    }
  }
  END{ if (!found) exit 1 }
' index.txt || die "No matching certificate found"
