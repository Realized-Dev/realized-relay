# Shared helpers for Realized-Relay™ hook and CI checks.
# Sourced by the scripts in this directory. Not executable on its own.

relay_err() {
	printf '%s\n' "$*" >&2
}

relay_die() {
	relay_err "error: $*"
	exit 1
}

relay_notice() {
	# Notices go to stderr so command substitution (label-guard --gated-only) stays clean.
	printf 'notice: %s\n' "$*" >&2
}

relay_trim() {
	# stdin -> trimmed stdout (leading/trailing whitespace)
	sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

relay_lower() {
	tr '[:upper:]' '[:lower:]'
}

relay_normalize_label() {
	printf '%s' "$1" | relay_trim | relay_lower
}

relay_normalize_sha() {
	printf '%s' "$1" | relay_trim | tr 'A-F' 'a-f'
}

relay_is_full_sha() {
	# Fail closed on abbreviations: require a 40-char hex SHA.
	printf '%s' "$1" | grep -qxE '[0-9a-f]{40}'
}

relay_gated_label_list() {
	printf '%s\n' \
		sensitive \
		migration \
		approval-required \
		privacy \
		legal \
		security
}

relay_is_gated_label() {
	_n=$(relay_normalize_label "$1")
	[ -n "$_n" ] && relay_gated_label_list | grep -qxF "$_n"
}

relay_repo() {
	printf '%s' "${GITHUB_REPOSITORY:-${GH_REPO:-}}"
}

relay_pr_number() {
	printf '%s' "${PR_NUMBER:-${RELAY_PR_NUMBER:-}}"
}

relay_head_sha() {
	relay_normalize_sha "${RELAY_HEAD_SHA:-}"
}

relay_token_present() {
	[ -n "${GITHUB_TOKEN:-}" ] || [ -n "${GH_TOKEN:-}" ]
}

relay_have_cmd() {
	command -v "$1" >/dev/null 2>&1
}

relay_require_jq() {
	if ! relay_have_cmd jq; then
		relay_die "jq is required to parse GitHub JSON (fail closed)"
	fi
}

relay_ci_claimed() {
	[ "${CI:-}" = true ] || [ "${GITHUB_ACTIONS:-}" = true ]
}

relay_running_in_ci() {
	# Fail-closed denylist and live GitHub reads when CI claims to be running,
	# or when a caller sets RELAY_CHECK_MODE=ci.
	relay_ci_claimed || [ "${RELAY_CHECK_MODE:-}" = ci ]
}

relay_check_mode() {
	# Test fixtures (RELAY_LABELS* / RELAY_REVIEWS*) and RELAY_CHECK_MODE=eval
	# are ignored when CI=true. Fixture-driven tests must unset CI.
	if relay_ci_claimed; then
		printf '%s' ci
		return
	fi
	if [ -n "${RELAY_CHECK_MODE:-}" ]; then
		printf '%s' "$RELAY_CHECK_MODE"
		return
	fi
	if [ -n "${RELAY_LABELS+x}" ] || [ -n "${RELAY_LABELS_JSON+x}" ] \
		|| [ -n "${RELAY_REVIEWS_JSON+x}" ] || [ -n "${RELAY_REVIEWS+x}" ]; then
		printf '%s' eval
		return
	fi
	printf '%s' hook
}

relay_allow_eval_overrides() {
	if relay_ci_claimed; then
		return 1
	fi
	[ "$(relay_check_mode)" = eval ]
}
