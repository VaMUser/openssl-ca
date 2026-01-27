#!/usr/bin/env bash
set -euo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

validate_name() {
  [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]] || die "Invalid APP_NAME '$1' (allowed: A-Za-z0-9._-)"
}

# Extract a key from [ script_defaults ] section in ./openssl.cnf
# Usage: conf_get <key> <default>
conf_get() {
  local key="$1"
  local def="${2:-}"
  awk -v k="$key" -v d="$def" '
    BEGIN{sec=0}
    /^[[:space:]]*\[/{sec=0}
    /^[[:space:]]*\[script_defaults\][[:space:]]*$/ {sec=1; next}
    sec==1 {
      # strip comments
      sub(/[;#].*$/, "", $0)
      if (match($0, "^[[:space:]]*" k "[[:space:]]*=[[:space:]]*(.*)$", a)) {
        v=a[1]
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
        if (v!="") { print v; exit }
      }
    }
    END{ if (NR>=0) {} }
  ' ./openssl.cnf 2>/dev/null || true
  # If awk didn't print anything, fallback
}

# Normalize SAN from either:
#   "DNS:example.com,IP:10.0.0.1"
# or "DNS.1:example.com,IP.1:10.0.0.1"
normalize_san() {
  local in="$1"
  local out=""
  IFS=',' read -r -a parts <<< "$in"
  for p in "${parts[@]}"; do
    p="${p#"${p%%[![:space:]]*}"}"  # ltrim
    p="${p%"${p##*[![:space:]]}"}"  # rtrim
    [[ -n "$p" ]] || continue
    if [[ "$p" =~ ^([A-Za-z]+)\.[0-9]+:(.+)$ ]]; then
      out+="${BASH_REMATCH[1]}:${BASH_REMATCH[2]},"
    else
      out+="${p},"
    fi
  done
  out="${out%,}"
  echo "$out"
}

