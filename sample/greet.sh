#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 1 ]]; then
  exit 1
fi
printf 'hello %s\n' "$1"
