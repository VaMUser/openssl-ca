#!/usr/bin/env bash
set -euo pipefail
umask 077

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
source ./lib.sh

# List certificates expiring within N days and optionally notify Telegram.

# Requires GNU date and curl.
# Usage: ./expire-soon.sh <days> [--notify] [--dry-run]
#
# Config file:
#   ./notify.config (or set NOTIFY_CONFIG=/path/to/notify.config)
# Variables:
#   TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID, TELEGRAM_API_URL (optional)

INDEX="index.txt"
CONFIG_FILE="${NOTIFY_CONFIG:-./notify.config}"
DO_NOTIFY=0
DRY_RUN=0

[[ $# -ge 1 ]] || die "Usage: $0 <days> [--notify] [--dry-run]"
DAYS="$1"; shift

while [[ $# -gt 0 ]]; do
  case "$1" in
    --notify) DO_NOTIFY=1 ;;
    --dry-run) DRY_RUN=1 ;;
    *) die "Unknown arg: $1" ;;
  esac
  shift
done

[[ "$DAYS" =~ ^[0-9]+$ ]] || die "Days must be an integer"

now_epoch="$(date -u +%s)"
cutoff_epoch="$(date -u -d "+${DAYS} days" +%s)"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

awk -F '\t' '$1=="V"{print}' "$INDEX" | while IFS=$'\t' read -r st exp rev serial fname subject; do
  yy="${exp:0:2}"; mm="${exp:2:2}"; dd="${exp:4:2}"
  HH="${exp:6:2}"; MI="${exp:8:2}"; SS="${exp:10:2}"
  yyyy="20${yy}"
  iso="${yyyy}-${mm}-${dd} ${HH}:${MI}:${SS}Z"
  exp_epoch="$(date -u -d "$iso" +%s 2>/dev/null || true)"
  [[ -n "$exp_epoch" ]] || continue
  if [[ "$exp_epoch" -le "$cutoff_epoch" ]]; then
    days_left=$(( (exp_epoch - now_epoch) / 86400 ))
    cn="$(echo "$subject" | sed -n 's/.*\/CN=\([^/]*\).*/\1/p')"
    [[ -n "$cn" ]] || cn="$subject"
    printf "%s\t%s\t%s\t%s\n" "$serial" "$iso" "$days_left" "$cn" >> "$tmp"
  fi
done

if [[ ! -s "$tmp" ]]; then
  echo "No certificates expiring within ${DAYS} days."
  exit 0
fi

sort -t $'\t' -k3,3n "$tmp" -o "$tmp"

echo "Certificates expiring within ${DAYS} days:"
printf "SERIAL\tNOTAFTER(UTC)\tDAYS_LEFT\tCN\n"
cat "$tmp"

[[ "$DO_NOTIFY" -eq 1 ]] || exit 0

if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi

: "${TELEGRAM_BOT_TOKEN:=}"
: "${TELEGRAM_CHAT_ID:=}"
: "${TELEGRAM_API_URL:=https://api.telegram.org}"

[[ -n "$TELEGRAM_BOT_TOKEN" ]] || die "TELEGRAM_BOT_TOKEN is not set (config: $CONFIG_FILE)"
[[ -n "$TELEGRAM_CHAT_ID" ]] || die "TELEGRAM_CHAT_ID is not set (config: $CONFIG_FILE)"

host="$(hostname -f 2>/dev/null || hostname)"
count="$(wc -l < "$tmp" | tr -d ' ')"

msg="OpenSSL CA (${host}): ${count} certificate(s) expiring within ${DAYS} day(s)\n\n"
max_lines=30
i=0
while IFS=$'\t' read -r serial iso days_left cn; do
  i=$((i+1))
  [[ "$i" -gt "$max_lines" ]] && break
  msg+="${days_left}d  ${iso}  ${serial}  ${cn}\n"
done < "$tmp"
if [[ "$i" -lt "$count" ]]; then
  rest=$((count - i))
  msg+="\n...and ${rest} more"
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "DRY RUN: would send Telegram notification."
  exit 0
fi

curl -fsS -X POST "${TELEGRAM_API_URL}/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
  --data-urlencode "text=${msg}" \
  -d "disable_web_page_preview=true" >/dev/null

echo "Telegram notification sent."
