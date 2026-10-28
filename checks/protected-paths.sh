#!/usr/bin/env bash
set -euo pipefail

here=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
# shellcheck disable=SC1091
. "$here/lib.sh" || { echo "lib.sh not found"; exit 1; }

mode=${RELAY_CHECK_MODE:-ci}
paths_file="${RELAY_PP_PATHS_FILE:-$(dirname "$here")/PROTECTED_PATHS}"

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

	# Prefer explicit env (workflow), then event payload, then API.
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
		body=$(gh api "repos/$repo/pulls/$pr_number" --jq '.body // ""' 2>/dev/null || echo "")
	fi
	[ -n "$sender" ] || sender=$author

	commits=$(gh api --paginate "repos/$repo/pulls/$pr_number/commits" --jq '.[] | [(.author.login // ""), (.committer.login // "")] | @tsv' 2>/dev/null || echo "__ERROR__")
	if [ "$commits" = "__ERROR__" ]; then
		echo "protected-paths: ERROR GitHub API commits failed"
		exit 1
	fi

	files=$(gh api --paginate "repos/$repo/pulls/$pr_number/files" --jq '.[] | if .previous_filename then "\(.filename)\t\(.previous_filename)" else .filename end' 2>/dev/null || echo "__ERROR__")
	if [ "$files" = "__ERROR__" ]; then
		echo "protected-paths: ERROR GitHub API files failed"
		exit 1
	fi
fi

if [ "$files" = "__ERROR__" ]; then
	echo "protected-paths: ERROR API error or truncation"
	exit 1
fi

agents_list=$(grep -i '^@agents:' "$paths_file" | head -n1 | sed 's/^@agents:[[:space:]]*//i' | tr ',' ' ' || true)
[ -z "$agents_list" ] && agents_list="ai-realized"

humans_list=$(grep -i '^@humans:' "$paths_file" | head -n1 | sed 's/^@humans:[[:space:]]*//i' | tr ',' ' ' || true)
[ -z "$humans_list" ] && humans_list="ralfcam"

is_agent() {
	local l
	l=$(echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/\[bot\]$//')
	if [ -z "$l" ]; then return 0; fi # No login = agent
	for a in $agents_list; do
		if [ "$l" = "$a" ]; then return 0; fi
	done
	for h in $humans_list; do
		if [ "$l" = "$h" ]; then return 1; fi
	done
	return 0 # not in humans -> treat as agent
}

agent_pr="no"
if is_agent "$author"; then agent_pr="yes"; fi
if is_agent "$sender"; then agent_pr="yes"; fi
while IFS=$'\t' read -r c_a c_c || [ -n "$c_a" ]; do
	[ -z "$c_a" ] && c_a=""
	[ -z "$c_c" ] && c_c=""
	if is_agent "$c_a"; then agent_pr="yes"; fi
	if is_agent "$c_c"; then agent_pr="yes"; fi
done <<EOF
$commits
EOF

# Parse files to list
declare -a file_list
file_list=()
while IFS=$'\t' read -r f1 f2 || [ -n "$f1" ]; do
	[ -z "$f1" ] && continue
	file_list+=("$f1")
	[ -n "$f2" ] && file_list+=("$f2")
done <<EOF
$files
EOF

if [ ${#file_list[@]} -eq 0 ]; then
	echo "protected-paths: PASS (agent=$agent_pr, 0 protected hits)"
	exit 0
fi

# Prepare gitignore
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
cd "$tmpdir"
git init -q
# Preserve original line numbers; comment out @directive lines so they never match.
sed -E 's/^[[:space:]]*@/# &/' "$paths_file" > .gitignore
base_lines=$(wc -l < .gitignore)
echo ".github/workflows/protected-paths.yml" >> .gitignore
echo "checks/protected-paths.sh" >> .gitignore
echo "PROTECTED_PATHS" >> .gitignore

printf "%s\n" "${file_list[@]}" | git check-ignore -v --stdin > matches.txt || true

if [ ! -s matches.txt ]; then
	echo "protected-paths: PASS (agent=$agent_pr, 0 protected hits)"
	exit 0
fi

if [ "$agent_pr" = "no" ]; then
	# Ralfcam PR. Check body for CLRO pass
	head_sha=$(echo "$head_sha" | tr '[:upper:]' '[:lower:]')
	if echo "$body" | grep -i -q "CLRO pass @$head_sha"; then
		echo "protected-paths: PASS"
		exit 0
	else
		echo "protected-paths: FAIL. protected path(s) touched but PR body missing 'CLRO pass @<headsha>'; see PROTECTED_PATHS."
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
echo "protected-paths: FAIL. ai-realized PR touches protected path(s): $msg. Protected changes must be authored by ralfcam; see PROTECTED_PATHS."
exit 1
