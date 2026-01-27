\
#!/usr/bin/env bash
set -euo pipefail

# expire-soon.sh — list certificates expiring within N days and optionally notify Telegram.
#
# Requires GNU date (Debian) and curl for Telegram notifications.
#
# Usage:
#   ./expire-soon.sh <days> [--notify] [--dry-run]
#
# Config file (optional):
#   ./notify.config (or set NOTIFY_CONFIG=/path/to/notify.config)
#   TELEGRAM_BOT_TOKEN="123:ABC..."
#   TELEGRAM_CHAT_ID="-1001234567890"
#   TELEGRAM_API_URL="https://api.telegram.org"   # optional
#
# Notes:
# - Uses OpenSSL CA database index.txt format.
# - Only considers status "V" (valid) certs.

INDEX="index.txt"
CONFIG_FILE="${NOTIFY_CONFIG:-./notify.config}"
DO_NOTIFY=0
DRY_RUN=0

if [ $# -lt 1 ]; then
  echo "Usage: $0 <days> [--notify] [--dry-run]"
  exit 1
fi

DAYS="$1"; shift

while [ $# -gt 0 ]; do
  case "$1" in
    --notify) DO_NOTIFY=1 ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help)
      echo "Usage: $0 <days> [--notify] [--dry-run]"
      exit 0
      ;;
    *)
      echo "Unknown arg: $1"
      exit 1
      ;;
  esac
  shift
done

if ! [[ "$DAYS" =~ ^[0-9]+$ ]]; then
  echo "Days must be an integer"
  exit 1
fi

now_epoch="$(date -u +%s)"
cutoff_epoch="$(date -u -d "+${DAYS} days" +%s)"

# Parse index.txt lines:
# V\tYYMMDDHHMMSSZ\t\tSERIAL\tFILENAME\t/SUBJECT
# R\tYYMMDDHHMMSSZ\tYYMMDDHHMMSSZ\tSERIAL\tFILENAME\t/SUBJECT
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

awk -F '\t' '$1=="V"{print $0}' "$INDEX" | while IFS=$'\t' read -r st exp rev serial fname subject; do
  # exp like 260127120000Z
  # Convert to "YYYY-MM-DD HH:MM:SSZ" for GNU date
  yy="${exp:0:2}"
  mm="${exp:2:2}"
  dd="${exp:4:2}"
  HH="${exp:6:2}"
  MM="${exp:8:2}"
  SS="${exp:10:2}"
  yyyy="20${yy}"
  iso="${yyyy}-${mm}-${dd} ${HH}:${MM}:${SS}Z"
  exp_epoch="$(date -u -d "$iso" +%s 2>/dev/null || true)"
  if [ -z "${exp_epoch}" ]; then
    continue
  fi
  if [ "$exp_epoch" -le "$cutoff_epoch" ]; then
    # days_left rounded down
    days_left=$(( (exp_epoch - now_epoch) / 86400 ))
    # Extract CN if present for readability
    cn="$(echo "$subject" | sed -n 's/.*\/CN=\([^/]*\).*/\1/p')"
    [ -z "$cn" ] && cn="$subject"
    printf "%s\t%s\t%s\t%s\n" "$serial" "$exp" "$days_left" "$cn" >> "$tmp"
  fi
done

if [ ! -s "$tmp" ]; then
  echo "No certificates expiring within ${DAYS} days."
  exit 0
fi

# Sort by days_left ascending
sort -t $'\t' -k3,3n "$tmp" > "${tmp}.sorted"
mv "${tmp}.sorted" "$tmp"

echo "Certificates expiring within ${DAYS} days:"
printf "SERIAL\tNOTAFTER\tDAYS_LEFT\tCN\n"
cat "$tmp"

if [ "$DO_NOTIFY" -eq 0 ]; then
  exit 0
fi

# Load config for Telegram
if [ -f "$CONFIG_FILE" ]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

: "${TELEGRAM_BOT_TOKEN:=}"
: "${TELEGRAM_CHAT_ID:=}"
: "${TELEGRAM_API_URL:=https://api.telegram.org}"

if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
  echo "Telegram config missing. Set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID in $CONFIG_FILE (or env)."
  exit 2
fi

host="$(hostname -f 2>/dev/null || hostname)"
count="$(wc -l < "$tmp" | tr -d ' ')"

msg="OpenSSL CA ($host): ${count} certificate(s) expiring within ${DAYS} day(s)%0A%0A"
# Include up to 30 lines to stay within message size
max_lines=30
i=0
while IFS=$'\t' read -r serial exp days_left cn; do
  i=$((i+1))
  [ "$i" -gt "$max_lines" ] && break
  # exp to ISO-ish
  yy="${exp:0:2}"; mm="${exp:2:2}"; dd="${exp:4:2}"
  HH="${exp:6:2}"; MI="${exp:8:2}"
  msg="${msg}${days_left}d  ${yyyy}-${mm}-${dd} ${HH}:${MI}Z  ${serial}  ${cn}%0A"
done < "$tmp"

if [ "$i" -lt "$count" ]; then
  rest=$((count - i))
  msg="${msg}%0A...and ${rest} more"
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "DRY RUN: would send Telegram notification."
  exit 0
fi

curl -fsS -X POST "${TELEGRAM_API_URL}/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  -d "chat_id=${TELEGRAM_CHAT_ID}" \
  -d "text=${msg}" \
  -d "disable_web_page_preview=true" >/dev/null

echo "Telegram notification sent."
