#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <CN-or-serial>"
  exit 1
fi

QUERY="$1"
INDEX="index.txt"

grep -E "(^|\t)${QUERY}(\t|$)" "$INDEX" || {
  echo "No matching certificate found"
  exit 1
}
