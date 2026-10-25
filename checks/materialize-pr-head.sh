#!/bin/sh
# Download one commit tarball and extract it as data.
# Never execute, checkout, or install from the extracted tree.
# Usage: materialize-pr-head.sh <40-char-sha> <dest-dir>

set -eu
set +x

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
# shellcheck disable=SC1091
. "$here/lib.sh"

sha=$(relay_normalize_sha "${1:-}")
dest=${2:-}

if ! relay_is_full_sha "$sha"; then
	relay_die "materialize-pr-head: need a full 40-char SHA"
fi
[ -n "$dest" ] || relay_die "materialize-pr-head: destination directory is required"

repo=$(relay_repo)
[ -n "$repo" ] || relay_die "materialize-pr-head: missing GITHUB_REPOSITORY"
relay_have_cmd gh || relay_die "materialize-pr-head: gh is required"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# gh uses GH_TOKEN / GITHUB_TOKEN from the environment. Do not print them.
if ! gh api "repos/${repo}/tarball/${sha}" >"$tmpdir/tree.tgz"; then
	relay_die "materialize-pr-head: tarball download failed"
fi

mkdir -p "$dest"
if ! tar -tzf "$tmpdir/tree.tgz" >/dev/null 2>&1; then
	relay_die "materialize-pr-head: tarball is not readable"
fi
if ! tar -xzf "$tmpdir/tree.tgz" -C "$dest" --strip-components=1; then
	relay_die "materialize-pr-head: tarball extract failed"
fi

printf 'materialize-pr-head: extracted %s as data\n' "$sha"
exit 0
