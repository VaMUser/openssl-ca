#!/usr/bin/env bash
set -euo pipefail

awk '$1=="V"{print}' index.txt
