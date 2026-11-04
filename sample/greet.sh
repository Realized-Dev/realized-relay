#!/bin/sh
# Implements AC-1 and AC-2 from docs/specs/sample.md.
set -eu

if [ "$#" -ne 1 ]; then
	echo "usage: greet.sh <name>" >&2
	exit 2
fi

printf 'Hello, %s!\n' "$1"
