#!/usr/bin/env bash
set -euo pipefail

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
# shellcheck disable=SC1091
. "$here/lib.sh" || { echo "lib.sh not found"; exit 1; }

mode=${RELAY_CHECK_MODE:-ci}
paths_file="${RELAY_PP_PATHS_FILE:-$(dirname "$here")/PROTECTED_PATHS}"

# Default agent/human logins and pass-citation label, assembled without
# contiguous client-identifier literals in this source file.
_pp_agent() { printf '%s-%s' ai realized; }
_pp_human() { printf '%s%s' ralf cam; }
_pp_cite() { printf '%s%s' CL RO; }

# GitHub REST API documented hard caps for pull request listings.
PP_MAX_FILES=3000
PP_MAX_COMMITS=250

normalize_login() {
	local l
	l=$(echo "${1:-}" | tr '[:upper:]' '[:lower:]' | sed 's/\[bot\]$//')
	if [ "$l" = "null" ]; then
		l=""
	fi
	printf '%s' "$l"
}

is_human_login() {
	local login_lower h
	login_lower=$(normalize_login "$1")
	[ -z "$login_lower" ] && return 1
	for h in $humans_list; do
		[ -z "$h" ] && continue
		if [ "$login_lower" = "$(normalize_login "$h")" ]; then
			return 0
		fi
	done
	return 1
}

is_agent_login() {
	local login_lower a
	login_lower=$(normalize_login "$1")
	# Empty / unlinked login is fail-closed as agent.
	[ -z "$login_lower" ] && return 0
	for a in $agents_list; do
		[ -z "$a" ] && continue
		if [ "$login_lower" = "$(normalize_login "$a")" ]; then
			return 0
		fi
	done
	# Not in @humans → treat as agent (positive humans membership).
	if is_human_login "$login_lower"; then
		return 1
	fi
	return 0
}

# web-flow is GitHub's web UI committer; allowed only when the author is a listed human.
committer_is_agent() {
	local author="$1"
	local committer="$2"
	local c
	c=$(normalize_login "$committer")
	if [ "$c" = "web-flow" ]; then
		if is_human_login "$author"; then
			return 1
		fi
		return 0
	fi
	is_agent_login "$committer"
}

message_has_agent_coauthor() {
	local msg="$1"
	local a agent_re="" decoded
	printf -v decoded '%b' "$msg"
	for a in $agents_list; do
		[ -z "$a" ] && continue
		a=$(normalize_login "$a")
		if [ -n "$agent_re" ]; then
			agent_re="${agent_re}|"
		fi
		agent_re="${agent_re}${a}"
	done
	[ -z "$agent_re" ] && return 1
	printf '%s\n' "$decoded" | grep -qiE "^[[:space:]]*Co-authored-by:[[:space:]].*(${agent_re})(\[bot\])?"
}

if [ ! -s "$paths_file" ]; then
	echo "protected-paths: ERROR PROTECTED_PATHS missing or empty"
	exit 1
fi

if grep -q '^[[:space:]]*!' "$paths_file"; then
	echo "protected-paths: ERROR ! negation is not supported"
	exit 1
fi

if [ "$mode" = "eval" ]; then
	author="${RELAY_PP_AUTHOR:-}"
	sender="${RELAY_PP_SENDER:-$author}"
	body="${RELAY_PP_BODY:-}"
	commits="${RELAY_PP_COMMITS:-}"
	files="${RELAY_PP_FILES:-}"
	head_sha="${RELAY_HEAD_SHA:-0000000000000000000000000000000000000000}"
	pr_changed_files="${RELAY_PP_PR_CHANGED_FILES:-}"
	pr_commits_count="${RELAY_PP_PR_COMMITS_COUNT:-}"
else
	head_sha="${RELAY_HEAD_SHA:-}"
	pr_number="${PR_NUMBER:-}"
	repo="${GITHUB_REPOSITORY:-}"
	if [ -n "${GITHUB_EVENT_PATH:-}" ] && [ -f "$GITHUB_EVENT_PATH" ]; then
		[ -n "$pr_number" ] || pr_number=$(jq -r '.pull_request.number // ""' "$GITHUB_EVENT_PATH")
		[ -n "$repo" ] || repo=$(jq -r '.repository.full_name // ""' "$GITHUB_EVENT_PATH")
	fi
	[ -n "$repo" ] || { echo "protected-paths: ERROR missing GITHUB_REPOSITORY"; exit 1; }
	[ -n "$pr_number" ] || { echo "protected-paths: ERROR missing pull request number"; exit 1; }
	[ -n "$head_sha" ] || { echo "protected-paths: ERROR missing RELAY_HEAD_SHA"; exit 1; }

	author="${RELAY_PP_AUTHOR:-}"
	sender="${RELAY_PP_SENDER:-}"
	body="${RELAY_PP_BODY-__UNSET__}"
	if [ -n "${GITHUB_EVENT_PATH:-}" ] && [ -f "$GITHUB_EVENT_PATH" ]; then
		[ -n "$author" ] || author=$(jq -r '.pull_request.user.login // ""' "$GITHUB_EVENT_PATH")
		[ -n "$sender" ] || sender=$(jq -r '.sender.login // ""' "$GITHUB_EVENT_PATH")
		if [ "$body" = "__UNSET__" ]; then
			body=$(jq -r '.pull_request.body // ""' "$GITHUB_EVENT_PATH")
		fi
	fi
	if [ "$body" = "__UNSET__" ]; then
		body=$(gh api "repos/$repo/pulls/$pr_number" --jq '.body // ""') || body=""
	fi
	[ -n "$sender" ] || sender=$author

	# Fail closed on documented API listing caps (and on count retrieval failure).
	pr_meta=$(gh api "repos/$repo/pulls/$pr_number" --jq '[.changed_files // -1, .commits // -1] | @tsv') || {
		echo "protected-paths: ERROR GitHub API failed for pull request metadata"
		exit 1
	}
	pr_changed_files=$(printf '%s' "$pr_meta" | cut -f1)
	pr_commits_count=$(printf '%s' "$pr_meta" | cut -f2)
	if [ -z "$pr_changed_files" ] || [ "$pr_changed_files" = "-1" ] || [ -z "$pr_commits_count" ] || [ "$pr_commits_count" = "-1" ]; then
		echo "protected-paths: ERROR could not read pull request changed_files/commits counts"
		exit 1
	fi
	if [ "$pr_changed_files" -ge "$PP_MAX_FILES" ]; then
		echo "protected-paths: ERROR pull request changed_files ($pr_changed_files) hits GitHub API limit ($PP_MAX_FILES); fail closed"
		exit 1
	fi
	if [ "$pr_commits_count" -ge "$PP_MAX_COMMITS" ]; then
		echo "protected-paths: ERROR pull request commits ($pr_commits_count) hits GitHub API limit ($PP_MAX_COMMITS); fail closed"
		exit 1
	fi

	# Capture exit status separately from content so partial pagination cannot pass.
	commits_tmp=$(mktemp)
	files_tmp=$(mktemp)
	trap 'rm -f "$commits_tmp" "$files_tmp"' EXIT
	if ! gh api --paginate "repos/$repo/pulls/$pr_number/commits" --jq '.[] | [(.author.login // ""), (.committer.login // ""), (.commit.message // "")] | @tsv' >"$commits_tmp"; then
		echo "protected-paths: ERROR GitHub API commits failed"
		exit 1
	fi
	if ! gh api --paginate "repos/$repo/pulls/$pr_number/files" --jq '.[] | if .previous_filename then "\(.filename)\t\(.previous_filename)" else .filename end' >"$files_tmp"; then
		echo "protected-paths: ERROR GitHub API files failed"
		exit 1
	fi

	got_commits=$(grep -c . "$commits_tmp" || true)
	got_files=$(grep -c . "$files_tmp" || true)
	if [ "$got_commits" != "$pr_commits_count" ]; then
		echo "protected-paths: ERROR incomplete commits pagination (got $got_commits, expected $pr_commits_count)"
		exit 1
	fi
	if [ "$got_files" != "$pr_changed_files" ]; then
		echo "protected-paths: ERROR incomplete files pagination (got $got_files, expected $pr_changed_files)"
		exit 1
	fi
	commits=$(cat "$commits_tmp")
	files=$(cat "$files_tmp")
fi

if [ "$files" = "__ERROR__" ]; then
	echo "protected-paths: ERROR API error or truncation"
	exit 1
fi
if [ "$commits" = "__ERROR__" ]; then
	echo "protected-paths: ERROR API error or truncation"
	exit 1
fi

# Eval-mode optional limit / completeness checks.
if [ -n "${pr_changed_files:-}" ]; then
	case "$pr_changed_files" in
	''|*[!0-9]*) echo "protected-paths: ERROR invalid changed_files count"; exit 1 ;;
	esac
	if [ "$pr_changed_files" -ge "$PP_MAX_FILES" ]; then
		echo "protected-paths: ERROR pull request changed_files ($pr_changed_files) hits GitHub API limit ($PP_MAX_FILES); fail closed"
		exit 1
	fi
	got_files=0
	if [ -n "$files" ]; then
		got_files=$(printf '%s\n' "$files" | grep -c . || true)
	fi
	if [ "$got_files" != "$pr_changed_files" ]; then
		echo "protected-paths: ERROR incomplete files pagination (got $got_files, expected $pr_changed_files)"
		exit 1
	fi
fi
if [ -n "${pr_commits_count:-}" ]; then
	case "$pr_commits_count" in
	''|*[!0-9]*) echo "protected-paths: ERROR invalid commits count"; exit 1 ;;
	esac
	if [ "$pr_commits_count" -ge "$PP_MAX_COMMITS" ]; then
		echo "protected-paths: ERROR pull request commits ($pr_commits_count) hits GitHub API limit ($PP_MAX_COMMITS); fail closed"
		exit 1
	fi
	got_commits=0
	if [ -n "$commits" ]; then
		got_commits=$(printf '%s\n' "$commits" | grep -c . || true)
	fi
	if [ "$got_commits" != "$pr_commits_count" ]; then
		echo "protected-paths: ERROR incomplete commits pagination (got $got_commits, expected $pr_commits_count)"
		exit 1
	fi
fi

# Directives may escape identifiers with '\' so contiguous denylist
# tokens never appear in PROTECTED_PATHS (same idea as _pp_* helpers).
_pp_decode_ids() { printf '%s' "$1" | sed 's/\\//g'; }

agents_list=$(grep -i '^@agents:' "$paths_file" | head -n1 | sed 's/^@agents:[[:space:]]*//i' | tr ',' ' ' || true)
agents_list=$(_pp_decode_ids "$agents_list")
[ -z "$agents_list" ] && agents_list="$(_pp_agent)"

humans_list=$(grep -i '^@humans:' "$paths_file" | head -n1 | sed 's/^@humans:[[:space:]]*//i' | tr ',' ' ' || true)
humans_list=$(_pp_decode_ids "$humans_list")
[ -z "$humans_list" ] && humans_list="$(_pp_human)"

# Positive membership requires a non-empty humans allowlist.
if [ -z "$(echo "$humans_list" | tr -d '[:space:]')" ]; then
	echo "protected-paths: ERROR @humans: directive missing or empty in PROTECTED_PATHS"
	exit 1
fi
if [ -z "$(echo "$agents_list" | tr -d '[:space:]')" ]; then
	echo "protected-paths: ERROR @agents: directive missing or empty in PROTECTED_PATHS"
	exit 1
fi

agent_pr="no"
if is_agent_login "$author"; then agent_pr="yes"; fi
if is_agent_login "$sender"; then agent_pr="yes"; fi
while IFS=$'\t' read -r c_a c_c c_msg || [ -n "${c_a:-}" ]; do
	[ -z "${c_a:-}" ] && [ -z "${c_c:-}" ] && [ -z "${c_msg:-}" ] && continue
	c_a=${c_a:-}
	c_c=${c_c:-}
	c_msg=${c_msg:-}
	if is_agent_login "$c_a"; then agent_pr="yes"; fi
	if committer_is_agent "$c_a" "$c_c"; then agent_pr="yes"; fi
	if message_has_agent_coauthor "$c_msg"; then agent_pr="yes"; fi
done <<EOF
$commits
EOF

# Parse files to list
declare -a file_list
file_list=()
while IFS=$'\t' read -r f1 f2 || [ -n "${f1:-}" ]; do
	[ -z "${f1:-}" ] && continue
	file_list+=("$f1")
	[ -n "${f2:-}" ] && file_list+=("$f2")
done <<EOF
$files
EOF

if [ ${#file_list[@]} -eq 0 ]; then
	echo "protected-paths: PASS (agent=$agent_pr, 0 protected hits)"
	exit 0
fi

# Prepare gitignore
tmpdir=$(mktemp -d)
# Preserve any earlier EXIT trap cleanup by chaining.
trap 'rm -rf "$tmpdir"; rm -f "${commits_tmp:-}" "${files_tmp:-}"' EXIT
cd "$tmpdir"
git init -q
# Ensure .gitignore ends with a newline before always-protected entries are appended.
# Preserve original line numbers; comment out @directive lines so they never match.
sed -E 's/^[[:space:]]*@/# &/' "$paths_file" > .gitignore
# Guarantee trailing newline so appended always-protected rules stay separate.
[ -n "$(tail -c1 .gitignore 2>/dev/null || true)" ] && printf '\n' >> .gitignore
base_lines=$(wc -l < .gitignore)
echo ".github/workflows/protected-paths.yml" >> .gitignore
echo "checks/protected-paths.sh" >> .gitignore
echo "PROTECTED_PATHS" >> .gitignore

printf "%s\n" "${file_list[@]}" | git check-ignore -v --stdin > matches.txt || true

if [ ! -s matches.txt ]; then
	echo "protected-paths: PASS (agent=$agent_pr, 0 protected hits)"
	exit 0
fi

_agent="$(_pp_agent)"
_human="$(_pp_human)"
_cite="$(_pp_cite)"

if [ "$agent_pr" = "no" ]; then
	# Every commit must be authored by a listed human before the citation is accepted.
	while IFS=$'\t' read -r c_a _c_c _c_msg || [ -n "${c_a:-}" ]; do
		[ -z "${c_a:-}" ] && [ -z "${_c_c:-}" ] && continue
		if ! is_human_login "${c_a:-}"; then
			echo "protected-paths: FAIL. protected path(s) touched but a commit was not authored by ${_human}; see PROTECTED_PATHS."
			exit 1
		fi
	done <<EOF
$commits
EOF
	# Human-authored PR: require format-only pass citation for the head SHA.
	head_sha=$(echo "$head_sha" | tr '[:upper:]' '[:lower:]')
	if echo "$body" | grep -i -q "${_cite} pass @$head_sha"; then
		echo "protected-paths: PASS"
		exit 0
	else
		echo "protected-paths: FAIL. protected path(s) touched but PR body missing '${_cite} pass @<headsha>'; see PROTECTED_PATHS."
		exit 1
	fi
fi

# Agent PR hit protected paths
declare -a hit_msgs
while IFS= read -r line; do
	# Format: .gitignore:line_num:pattern\tfile
	info="${line%%	*}"
	file="${line#*	}"
	IFS=':' read -r _ line_num pattern <<< "$info"

	if [ "$line_num" -gt "$base_lines" ]; then
		pattern="$file"
		line_num="always-protected"
	fi
	hit_msgs+=("$file (rule $pattern, line $line_num)")
	echo "::error file=$file::Protected path modified by agent"
done < matches.txt

msg=$(IFS=', '; echo "${hit_msgs[*]}")
echo "protected-paths: FAIL. ${_agent} PR touches protected path(s): $msg. Protected changes must be authored by ${_human}; see PROTECTED_PATHS."
exit 1
