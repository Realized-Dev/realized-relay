#!/bin/sh
# Implements AC-1 and AC-2 of the sample greeting helper spec.
set -eu

if [ "$#" -ne 1 ]; then
	echo "usage: greet.sh <name>" >&2
	exit 2
fi

printf 'Hello, %s!\n' "$1"
