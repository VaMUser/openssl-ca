#!/usr/bin/env bash
set -euo pipefail
umask 077

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"
source ./lib.sh

# List valid certificates from index.txt.

awk -F '\t' '$1=="V"{print}' index.txt
