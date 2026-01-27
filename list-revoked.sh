#!/usr/bin/env bash
set -euo pipefail

awk '$1=="R"{print}' index.txt
