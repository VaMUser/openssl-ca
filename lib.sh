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


# ---------- index.txt helpers ----------

# Portable awk program part: extract CN from OpenSSL "subject" field.
# DN format: /C=RU/O=Org/CN=example
awk_cn_helpers='
function cn_from_subject(dn,   i,n,parts) {
  n = split(dn, parts, "/")
  for (i = 1; i <= n; i++) {
    if (parts[i] ~ /^CN=/) {
      sub(/^CN=/, "", parts[i])
      return parts[i]
    }
  }
  return ""
}
function is_hex_serial(s) {
  return (s ~ /^[0-9A-Fa-f]+$/)
}
'

# Run awk against index.txt with injected helper functions.
# Usage:
#   run_index_awk '<main awk code>' [query]
run_index_awk() {
  local main_awk="${1:?main awk required}"
  local query="${2:-}"
  awk -F $'\t' -v q="$query" "${awk_cn_helpers}
${main_awk}" index.txt
}
# ---------- recent cert link helpers ----------

sanitize_filename() {
  # Keep only safe filename characters; replace the rest with "_".
  echo "${1:-}" | sed -E 's/[^A-Za-z0-9._-]+/_/g'
}

cert_cn() {
  # Extract CN from certificate subject. Best-effort; assumes CN does not contain unescaped commas.
  local crt="${1:?cert path required}"
  openssl x509 -in "$crt" -noout -subject -nameopt RFC2253     | sed -nE 's/^subject=//p'     | sed -nE 's/.*CN=([^,]+).*/\1/p'     | head -n1
}

ensure_recent_links() {
  # ensure_recent_links <OUTDIR> <LINKDIR> [N=5]
  # OUTDIR is where openssl ca -outdir writes SERIAL.pem
  # LINKDIR will receive symlinks named: {SERIAL}_{CN}.crt
  local outdir="${1:?outdir required}"
  local linkdir="${2:?linkdir required}"
  local n="${3:-5}"

  mkdir -p "$outdir" "$linkdir"

  # Pick N newest certs
  mapfile -t certs < <(ls -1t "$outdir"/*.pem 2>/dev/null | head -n "$n" || true)
  [[ "${#certs[@]}" -gt 0 ]] || return 0

  local crt serial cn cn_s link tmp_link target_abs
  for crt in "${certs[@]}"; do
    [[ -f "$crt" ]] || continue
    serial="$(basename "$crt" .pem)"
    serial="${serial,,}"

    cn="$(cert_cn "$crt" || true)"
    [[ -n "$cn" ]] || continue
    cn_s="$(sanitize_filename "$cn")"

    link="$linkdir/${serial}_${cn_s}.crt"
    if [[ -L "$link" || -e "$link" ]]; then
      continue
    fi

    # Absolute target to avoid relative-path surprises.
    target_abs="$(cd "$(dirname "$crt")" && pwd)/$(basename "$crt")"

    tmp_link="${link}.tmp.$$"
    ln -s "$target_abs" "$tmp_link"
    mv -Tf "$tmp_link" "$link"
  done
}
