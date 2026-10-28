#!/usr/bin/env bash

if [ $# -eq 0 ]; then
  echo "Error: missing argument" >&2
  exit 1
fi

echo "hello $1"
exit 0
