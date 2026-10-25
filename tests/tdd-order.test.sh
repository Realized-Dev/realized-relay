#!/usr/bin/env bash
# AC-TD: companion tests on a file list; red-then-green across a commit range.
set -euo pipefail
# shellcheck disable=SC1091
. "$(CDPATH= cd -- "$(dirname "$0")" && pwd)/helpers.sh"
td="$CHECKS/tdd-order.sh"

expect_exit AC-TD-01 1 env RELAY_FILE_LIST='checks/label-guard.sh' "$td" --files
expect_exit AC-TD-02 0 env RELAY_FILE_LIST="$(printf 'checks/label-guard.sh\ntests/label-guard.test.sh\n')" "$td" --files
expect_exit AC-TD-03 0 env RELAY_FILE_LIST='README.md' "$td" --files
expect_exit AC-TD-04 0 env RELAY_FILE_LIST='.githooks/INSTALL' "$td" --files
expect_exit AC-TD-05 0 env RELAY_FILE_LIST='' "$td" --files
expect_exit AC-TD-06 0 env RELAY_FILE_LIST='.github/workflows/ci.yml' "$td" --files
expect_exit AC-TD-07 1 env RELAY_FILE_LIST='.githooks/pre-commit' "$td" --files

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
git init -q "$tmp"
git -C "$tmp" config user.email tdd@example.test
git -C "$tmp" config user.name TDD Range
printf 'base\n' >"$tmp/README.md"
git -C "$tmp" add README.md
git -C "$tmp" commit -q -m base
base=$(git -C "$tmp" rev-parse HEAD)

mkdir -p "$tmp/tests" "$tmp/app"
printf 'red\n' >"$tmp/tests/demo.test.sh"
git -C "$tmp" add tests/demo.test.sh
git -C "$tmp" commit -q -m red
printf 'impl\n' >"$tmp/app/demo.sh"
git -C "$tmp" add app/demo.sh
git -C "$tmp" commit -q -m green
head=$(git -C "$tmp" rev-parse HEAD)

set +e
out=$(cd "$tmp" && "$td" --range "$base" "$head" 2>&1)
code=$?
set -e
if [ "$code" -eq 0 ]; then
	ok AC-TD-08
else
	bad AC-TD-08 "range should pass when tests precede impl: $out"
fi

# Production-only commit with no prior test commit in the range.
tmp2=$(mktemp -d)
trap 'rm -rf "$tmp" "$tmp2"' EXIT
git init -q "$tmp2"
git -C "$tmp2" config user.email tdd@example.test
git -C "$tmp2" config user.name TDD Range
printf 'base\n' >"$tmp2/README.md"
git -C "$tmp2" add README.md
git -C "$tmp2" commit -q -m base
b2=$(git -C "$tmp2" rev-parse HEAD)
mkdir -p "$tmp2/app"
printf 'impl\n' >"$tmp2/app/demo.sh"
git -C "$tmp2" add app/demo.sh
git -C "$tmp2" commit -q -m impl-only
h2=$(git -C "$tmp2" rev-parse HEAD)
set +e
out2=$(cd "$tmp2" && "$td" --range "$b2" "$h2" 2>&1)
code2=$?
set -e
if [ "$code2" -eq 1 ]; then
	ok AC-TD-09
else
	bad AC-TD-09 "range should fail for impl-only: $out2"
fi

init_tdd() {
	_d=$1
	git init -q -b main "$_d"
	git -C "$_d" config user.email tdd@example.test
	git -C "$_d" config user.name TDD
}

range_tdd() {
	# usage: range_tdd <dir> <base> <head>  → sets _rc and _out
	_rc=0
	_out=$(cd "$1" && env RELAY_TDD_BASE=origin/main "$td" --range "$2" "$3" 2>&1) || _rc=$?
}

# Clean merge of origin/main into a feature branch: skip the merge, PASS.
tmp3=$(mktemp -d)
trap 'rm -rf "$tmp" "$tmp2" "$tmp3"' EXIT
init_tdd "$tmp3"
printf 'base\n' >"$tmp3/README.md"
git -C "$tmp3" add README.md
git -C "$tmp3" commit -q -m base
git -C "$tmp3" checkout -q -b feature
printf 'side\n' >"$tmp3/README.md"
git -C "$tmp3" add README.md
git -C "$tmp3" commit -q -m side
git -C "$tmp3" checkout -q main
mkdir -p "$tmp3/app"
printf 'from-main\n' >"$tmp3/app/demo.sh"
git -C "$tmp3" add app/demo.sh
git -C "$tmp3" commit -q -m 'main-only prod'
main3=$(git -C "$tmp3" rev-parse HEAD)
git -C "$tmp3" update-ref refs/remotes/origin/main "$main3"
git -C "$tmp3" checkout -q feature
git -C "$tmp3" merge -q --no-edit main
h3=$(git -C "$tmp3" rev-parse HEAD)
range_tdd "$tmp3" "$main3" "$h3"
if [ "$_rc" -eq 0 ]; then
	ok AC-TD-10
else
	bad AC-TD-10 "clean main merge should pass: $_out"
fi

# Faked MERGE_HEAD must not skip the companion rule.
tmp4=$(mktemp -d)
trap 'rm -rf "$tmp" "$tmp2" "$tmp3" "$tmp4"' EXIT
init_tdd "$tmp4"
printf 'base\n' >"$tmp4/README.md"
git -C "$tmp4" add README.md
git -C "$tmp4" commit -q -m base
mkdir -p "$tmp4/app"
printf 'prod\n' >"$tmp4/app/demo.sh"
git -C "$tmp4" add app/demo.sh
git -C "$tmp4" rev-parse HEAD >"$tmp4/.git/MERGE_HEAD"
set +e
out4=$(cd "$tmp4" && env RELAY_TDD_BASE=origin/main "$td" --staged 2>&1)
code4=$?
set -e
if [ "$code4" -eq 1 ]; then
	ok AC-TD-11
else
	bad AC-TD-11 "faked MERGE_HEAD should fail companion: $out4"
fi

# Merge of main that carries its own production edit: FAIL.
tmp5=$(mktemp -d)
trap 'rm -rf "$tmp" "$tmp2" "$tmp3" "$tmp4" "$tmp5"' EXIT
init_tdd "$tmp5"
printf 'base\n' >"$tmp5/README.md"
git -C "$tmp5" add README.md
git -C "$tmp5" commit -q -m base
git -C "$tmp5" checkout -q -b feature
printf 'side\n' >"$tmp5/README.md"
git -C "$tmp5" add README.md
git -C "$tmp5" commit -q -m side
git -C "$tmp5" checkout -q main
printf 'main-more\n' >"$tmp5/NOTES.md"
git -C "$tmp5" add NOTES.md
git -C "$tmp5" commit -q -m 'main notes'
main5=$(git -C "$tmp5" rev-parse HEAD)
git -C "$tmp5" update-ref refs/remotes/origin/main "$main5"
git -C "$tmp5" checkout -q feature
git -C "$tmp5" merge --no-commit --no-ff main
mkdir -p "$tmp5/app"
printf 'own-edit\n' >"$tmp5/app/own.sh"
git -C "$tmp5" add app/own.sh
git -C "$tmp5" commit -q -m 'merge with own edit'
h5=$(git -C "$tmp5" rev-parse HEAD)
range_tdd "$tmp5" "$main5" "$h5"
if [ "$_rc" -eq 1 ]; then
	ok AC-TD-12
else
	bad AC-TD-12 "merge with own edits should fail: $_out"
fi

# Two-parent commit whose second parent is not on main, with its own
# production edit: FAIL. First parent is not on main, so this is not
# an integration merge.
tmp6=$(mktemp -d)
trap 'rm -rf "$tmp" "$tmp2" "$tmp3" "$tmp4" "$tmp5" "$tmp6"' EXIT
init_tdd "$tmp6"
printf 'base\n' >"$tmp6/README.md"
git -C "$tmp6" add README.md
git -C "$tmp6" commit -q -m base
main6=$(git -C "$tmp6" rev-parse HEAD)
git -C "$tmp6" update-ref refs/remotes/origin/main "$main6"
git -C "$tmp6" checkout -q -b side
printf 'side\n' >"$tmp6/README.md"
git -C "$tmp6" add README.md
git -C "$tmp6" commit -q -m side
p1_6=$(git -C "$tmp6" rev-parse HEAD)
git -C "$tmp6" checkout -q -b feat
mkdir -p "$tmp6/app"
printf 'feat-prod\n' >"$tmp6/app/feat.sh"
git -C "$tmp6" add app/feat.sh
git -C "$tmp6" commit -q -m feat
p2_6=$(git -C "$tmp6" rev-parse HEAD)
git -C "$tmp6" checkout -q side
git -C "$tmp6" merge --no-commit --no-ff feat
printf 'own\n' >"$tmp6/app/own.sh"
git -C "$tmp6" add app/own.sh
git -C "$tmp6" commit -q -m 'off-main merge with own prod'
h6=$(git -C "$tmp6" rev-parse HEAD)
# Only the merge is in p2..merge; p2 is not an ancestor of origin/main.
range_tdd "$tmp6" "$p2_6" "$h6"
if [ "$_rc" -eq 1 ]; then
	ok AC-TD-13
else
	bad AC-TD-13 "off-main 2-parent merge with own prod should fail: $_out"
fi

# Octopus (3 parents): FAIL.
tmp7=$(mktemp -d)
trap 'rm -rf "$tmp" "$tmp2" "$tmp3" "$tmp4" "$tmp5" "$tmp6" "$tmp7"' EXIT
init_tdd "$tmp7"
printf 'base\n' >"$tmp7/README.md"
git -C "$tmp7" add README.md
git -C "$tmp7" commit -q -m base
main7=$(git -C "$tmp7" rev-parse HEAD)
git -C "$tmp7" update-ref refs/remotes/origin/main "$main7"
git -C "$tmp7" checkout -q -b t1
printf 't1\n' >"$tmp7/T1.md"
git -C "$tmp7" add T1.md
git -C "$tmp7" commit -q -m t1
git -C "$tmp7" checkout -q -b t2 "$main7"
printf 't2\n' >"$tmp7/T2.md"
git -C "$tmp7" add T2.md
git -C "$tmp7" commit -q -m t2
git -C "$tmp7" checkout -q -b t3 "$main7"
printf 't3\n' >"$tmp7/T3.md"
git -C "$tmp7" add T3.md
git -C "$tmp7" commit -q -m t3
git -C "$tmp7" checkout -q t1
git -C "$tmp7" merge --no-ff t2 t3 -m octopus
n7=$(git -C "$tmp7" rev-parse HEAD^@ | awk 'END { print NR+0 }')
h7=$(git -C "$tmp7" rev-parse HEAD)
if [ "$n7" -ge 3 ]; then
	ok AC-TD-14-shape
else
	bad AC-TD-14-shape "expected octopus, got ${n7} parents"
fi
range_tdd "$tmp7" "$main7" "$h7"
if [ "$_rc" -eq 1 ]; then
	ok AC-TD-14
else
	bad AC-TD-14 "octopus merge should fail: $_out"
fi

# Root commit with production files: FAIL (--root must not skip it).
tmp8=$(mktemp -d)
trap 'rm -rf "$tmp" "$tmp2" "$tmp3" "$tmp4" "$tmp5" "$tmp6" "$tmp7" "$tmp8"' EXIT
init_tdd "$tmp8"
mkdir -p "$tmp8/app"
printf 'root-prod\n' >"$tmp8/app/root.sh"
git -C "$tmp8" add app/root.sh
git -C "$tmp8" commit -q -m root
root8=$(git -C "$tmp8" rev-parse HEAD)
git -C "$tmp8" checkout -q --orphan other
git -C "$tmp8" commit -q --allow-empty -m other
other8=$(git -C "$tmp8" rev-parse HEAD)
range_tdd "$tmp8" "$other8" "$root8"
if [ "$_rc" -eq 1 ]; then
	ok AC-TD-15
else
	bad AC-TD-15 "root production commit should fail: $_out"
fi

# Verified in-progress merge of origin/main: --staged may skip (local convenience).
tmp9=$(mktemp -d)
trap 'rm -rf "$tmp" "$tmp2" "$tmp3" "$tmp4" "$tmp5" "$tmp6" "$tmp7" "$tmp8" "$tmp9"' EXIT
init_tdd "$tmp9"
printf 'base\n' >"$tmp9/README.md"
git -C "$tmp9" add README.md
git -C "$tmp9" commit -q -m base
git -C "$tmp9" checkout -q -b feature
printf 'side\n' >"$tmp9/README.md"
git -C "$tmp9" add README.md
git -C "$tmp9" commit -q -m side
git -C "$tmp9" checkout -q main
printf 'main-more\n' >"$tmp9/NOTES.md"
git -C "$tmp9" add NOTES.md
git -C "$tmp9" commit -q -m 'main notes'
main9=$(git -C "$tmp9" rev-parse HEAD)
git -C "$tmp9" update-ref refs/remotes/origin/main "$main9"
git -C "$tmp9" checkout -q feature
git -C "$tmp9" merge --no-commit --no-ff main
set +e
out9=$(cd "$tmp9" && env RELAY_TDD_BASE=origin/main "$td" --staged 2>&1)
code9=$?
set -e
if [ "$code9" -eq 0 ]; then
	ok AC-TD-16
else
	bad AC-TD-16 "verified MERGE_HEAD of a clean main merge should pass: $out9"
fi

# (a) Merge of main that adds its own production file while main adds a
# test. First-parent comparison would see the test and pass; only the
# merge's own edits (app/evil.sh) may be judged.
tmp10=$(mktemp -d)
trap 'rm -rf "$tmp" "$tmp2" "$tmp3" "$tmp4" "$tmp5" "$tmp6" "$tmp7" "$tmp8" "$tmp9" "$tmp10"' EXIT
init_tdd "$tmp10"
printf 'base\n' >"$tmp10/README.md"
git -C "$tmp10" add README.md
git -C "$tmp10" commit -q -m base
git -C "$tmp10" checkout -q -b feature
printf 'side\n' >"$tmp10/README.md"
git -C "$tmp10" add README.md
git -C "$tmp10" commit -q -m side
git -C "$tmp10" checkout -q main
mkdir -p "$tmp10/tests"
printf 'main-test\n' >"$tmp10/tests/m.test.sh"
git -C "$tmp10" add tests/m.test.sh
git -C "$tmp10" commit -q -m 'main test'
main10=$(git -C "$tmp10" rev-parse HEAD)
git -C "$tmp10" update-ref refs/remotes/origin/main "$main10"
git -C "$tmp10" checkout -q feature
git -C "$tmp10" merge --no-commit --no-ff main
mkdir -p "$tmp10/app"
printf 'evil\n' >"$tmp10/app/evil.sh"
git -C "$tmp10" add app/evil.sh
git -C "$tmp10" commit -q -m 'merge with own evil'
h10=$(git -C "$tmp10" rev-parse HEAD)
range_tdd "$tmp10" "$main10" "$h10"
if [ "$_rc" -eq 1 ]; then
	ok AC-TD-17
else
	bad AC-TD-17 "own merge edit must not pass because main added a test: $_out"
fi

# (b) Conflict-resolution merge that adds production while main adds a
# test. Combined diff is the resolution; first-parent includes the test.
tmp11=$(mktemp -d)
trap 'rm -rf "$tmp" "$tmp2" "$tmp3" "$tmp4" "$tmp5" "$tmp6" "$tmp7" "$tmp8" "$tmp9" "$tmp10" "$tmp11"' EXIT
init_tdd "$tmp11"
printf 'base\n' >"$tmp11/README.md"
git -C "$tmp11" add README.md
git -C "$tmp11" commit -q -m base
git -C "$tmp11" checkout -q -b feature
printf 'feat\n' >"$tmp11/README.md"
git -C "$tmp11" add README.md
git -C "$tmp11" commit -q -m feat
git -C "$tmp11" checkout -q main
printf 'main\n' >"$tmp11/README.md"
mkdir -p "$tmp11/tests"
printf 'main-test\n' >"$tmp11/tests/m.test.sh"
git -C "$tmp11" add README.md tests/m.test.sh
git -C "$tmp11" commit -q -m 'main test and readme'
main11=$(git -C "$tmp11" rev-parse HEAD)
git -C "$tmp11" update-ref refs/remotes/origin/main "$main11"
git -C "$tmp11" checkout -q feature
set +e
git -C "$tmp11" merge --no-commit --no-ff main
set -e
printf 'resolved\n' >"$tmp11/README.md"
mkdir -p "$tmp11/app"
printf 'prod\n' >"$tmp11/app/prod.sh"
git -C "$tmp11" add README.md app/prod.sh
git -C "$tmp11" commit -q -m 'merge conflict with prod'
h11=$(git -C "$tmp11" rev-parse HEAD)
range_tdd "$tmp11" "$main11" "$h11"
if [ "$_rc" -eq 1 ]; then
	ok AC-TD-18
else
	bad AC-TD-18 "conflict-resolution prod must not pass because main added a test: $_out"
fi

# --no-ff merge of a good feature into origin/main: integration commit,
# range must pass (second-parent commits are still checked).
tmp12=$(mktemp -d)
trap 'rm -rf "$tmp" "$tmp2" "$tmp3" "$tmp4" "$tmp5" "$tmp6" "$tmp7" "$tmp8" "$tmp9" "$tmp10" "$tmp11" "$tmp12"' EXIT
init_tdd "$tmp12"
printf 'base\n' >"$tmp12/README.md"
git -C "$tmp12" add README.md
git -C "$tmp12" commit -q -m base
main12=$(git -C "$tmp12" rev-parse HEAD)
git -C "$tmp12" update-ref refs/remotes/origin/main "$main12"
git -C "$tmp12" checkout -q -b feature
mkdir -p "$tmp12/app" "$tmp12/tests"
printf 'prod\n' >"$tmp12/app/feat.sh"
printf 'test\n' >"$tmp12/tests/feat.test.sh"
git -C "$tmp12" add app/feat.sh tests/feat.test.sh
git -C "$tmp12" commit -q -m feat
git -C "$tmp12" checkout -q main
git -C "$tmp12" merge -q --no-ff --no-edit feature
h12=$(git -C "$tmp12" rev-parse HEAD)
range_tdd "$tmp12" "$main12" "$h12"
if [ "$_rc" -eq 0 ]; then
	ok AC-TD-19
else
	bad AC-TD-19 "no-ff merge into main with a good second parent should pass: $_out"
fi

# Same shape, but the second-parent side has a production-only commit: FAIL.
tmp13=$(mktemp -d)
trap 'rm -rf "$tmp" "$tmp2" "$tmp3" "$tmp4" "$tmp5" "$tmp6" "$tmp7" "$tmp8" "$tmp9" "$tmp10" "$tmp11" "$tmp12" "$tmp13"' EXIT
init_tdd "$tmp13"
printf 'base\n' >"$tmp13/README.md"
git -C "$tmp13" add README.md
git -C "$tmp13" commit -q -m base
main13=$(git -C "$tmp13" rev-parse HEAD)
git -C "$tmp13" update-ref refs/remotes/origin/main "$main13"
git -C "$tmp13" checkout -q -b feature
mkdir -p "$tmp13/app"
printf 'bad\n' >"$tmp13/app/bad.sh"
git -C "$tmp13" add app/bad.sh
git -C "$tmp13" commit -q -m 'prod only'
git -C "$tmp13" checkout -q main
git -C "$tmp13" merge -q --no-ff --no-edit feature
h13=$(git -C "$tmp13" rev-parse HEAD)
range_tdd "$tmp13" "$main13" "$h13"
if [ "$_rc" -eq 1 ]; then
	ok AC-TD-20
else
	bad AC-TD-20 "no-ff merge into main must still fail a bad second-parent commit: $_out"
fi

# --staged during a real merge: own production must not pass because main
# brought in a test.
tmp14=$(mktemp -d)
trap 'rm -rf "$tmp" "$tmp2" "$tmp3" "$tmp4" "$tmp5" "$tmp6" "$tmp7" "$tmp8" "$tmp9" "$tmp10" "$tmp11" "$tmp12" "$tmp13" "$tmp14"' EXIT
init_tdd "$tmp14"
printf 'base\n' >"$tmp14/README.md"
git -C "$tmp14" add README.md
git -C "$tmp14" commit -q -m base
git -C "$tmp14" checkout -q -b feature
printf 'side\n' >"$tmp14/README.md"
git -C "$tmp14" add README.md
git -C "$tmp14" commit -q -m side
git -C "$tmp14" checkout -q main
mkdir -p "$tmp14/tests"
printf 'main-test\n' >"$tmp14/tests/m.test.sh"
git -C "$tmp14" add tests/m.test.sh
git -C "$tmp14" commit -q -m 'main test'
main14=$(git -C "$tmp14" rev-parse HEAD)
git -C "$tmp14" update-ref refs/remotes/origin/main "$main14"
git -C "$tmp14" checkout -q feature
git -C "$tmp14" merge --no-commit --no-ff main
mkdir -p "$tmp14/app"
printf 'evil\n' >"$tmp14/app/evil.sh"
git -C "$tmp14" add app/evil.sh
set +e
out14=$(cd "$tmp14" && env RELAY_TDD_BASE=origin/main "$td" --staged 2>&1)
code14=$?
set -e
if [ "$code14" -eq 1 ]; then
	ok AC-TD-21
else
	bad AC-TD-21 "staged own prod during merge must not pass because main added a test: $out14"
fi

finish
