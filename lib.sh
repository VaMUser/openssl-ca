# lib.sh — shared helpers for OpenSSL CA scripts
# This file is sourced by other scripts; it should not rely on being executed directly.


die() { echo "ERROR: $*" >&2; exit 1; }

validate_name() {
  [[ "${1:-}" =~ ^[A-Za-z0-9._-]+$ ]] || die "Invalid name '${1:-}' (allowed: A-Za-z0-9._-)"
}

# Read key=value from a specific section in openssl.cnf.
# Usage: conf_get <section> <key> <default>
conf_get() {
  local section="$1" key="$2" def="${3:-}"
  awk -v sec="[$section]" -v k="$key" -v d="$def" '
    BEGIN{in=0; val=""}
    /^[[:space:]]*\[/{in=0}
    tolower($0) ~ "^[[:space:]]*\\[" tolower(substr(sec,2,length(sec)-2)) "\\][[:space:]]*$" {in=1; next}
    in==1 {
      line=$0
      sub(/[;#].*$/, "", line)
      if (match(line, "^[[:space:]]*" k "[[:space:]]*=[[:space:]]*(.*)$", a)) {
        val=a[1]
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
        if (val!="") { print val; exit }
      }
    }
    END{ }
  ' ./openssl.cnf 2>/dev/null || true
}

conf_get_or_default() {
  local v
  v="$(conf_get "$1" "$2" "" || true)"
  if [[ -n "$v" ]]; then
    echo "$v"
  else
    echo "${3:-}"
  fi
}

# Read *_default from [ req_distinguished_name ].
# Usage: dn_default <key> <default>
dn_default() {
  local key="$1" def="${2:-}"
  local v
  v="$(awk -v k="$key" -v d="$def" '
    BEGIN{in=0}
    /^[[:space:]]*\[/{in=0}
    /^[[:space:]]*\[ *req_distinguished_name *\][[:space:]]*$/ {in=1; next}
    in==1 {
      line=$0
      sub(/[;#].*$/, "", line)
      if (match(line, "^[[:space:]]*" k "[[:space:]]*=[[:space:]]*(.*)$", a)) {
        v=a[1]
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
        print v; exit
      }
    }
  ' ./openssl.cnf 2>/dev/null || true)"
  if [[ -n "$v" ]]; then echo "$v"; else echo "$def"; fi
}

escape_dn_value() {
  # Escape characters that break -subj format.
  local v="${1:-}"
  v="${v//\\/\\\\}"
  v="${v//\//\\/}"
  echo "$v"
}

build_subj() {
  # build_subj <CN> [include_email=0|1]
  local cn="${1:-}"; local include_email="${2:-0}"
  [[ -n "$cn" ]] || die "build_subj: CN is empty"

  local C ST L O OU EMAIL
  C="$(dn_default countryName_default "")"
  ST="$(dn_default stateOrProvinceName_default "")"
  L="$(dn_default localityName_default "")"
  O="$(dn_default 0.organizationName_default "")"
  [[ -n "$O" ]] || O="$(dn_default organizationName_default "")"
  OU="$(dn_default organizationalUnitName_default "")"
  EMAIL="$(dn_default emailAddress_default "")"

  local subj=""
  [[ -n "$C" ]] && subj+="/C=$(escape_dn_value "$C")"
  [[ -n "$ST" ]] && subj+="/ST=$(escape_dn_value "$ST")"
  [[ -n "$L" ]] && subj+="/L=$(escape_dn_value "$L")"
  [[ -n "$O" ]] && subj+="/O=$(escape_dn_value "$O")"
  [[ -n "$OU" ]] && subj+="/OU=$(escape_dn_value "$OU")"
  subj+="/CN=$(escape_dn_value "$cn")"
  if [[ "$include_email" == "1" && -n "$EMAIL" ]]; then
    subj+="/emailAddress=$(escape_dn_value "$EMAIL")"
  fi
  echo "$subj"
}

# Normalize SAN input:
# - Accepts "DNS:example.com,IP:10.0.0.1"
# - Accepts "DNS.1:example.com,IP.1:10.0.0.1"
normalize_san() {
  local in="${1:-}"
  local out=""
  IFS=',' read -r -a parts <<< "$in"
  for p in "${parts[@]}"; do
    p="${p#"${p%%[![:space:]]*}"}"
    p="${p%"${p##*[![:space:]]}"}"
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

# Parse script args: supports -san "..." or -san:"..."
parse_san_arg() {
  local san=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -san)
        shift
        san="${1:-}"
        shift || true
        ;;
      -san:*)
        san="${1#-san:}"
        shift
        ;;
      *)
        die "Unknown argument: $1"
        ;;
    esac
  done
  echo "$san"
}

ensure_layout() {
  mkdir -p CA/private newcerts out crl
  touch index.txt
  [[ -f serial ]] || echo "01" > serial
  [[ -f crlnumber ]] || echo "01" > crlnumber
  [[ -f index.txt.attr ]] || echo "unique_subject = no" > index.txt.attr
}
