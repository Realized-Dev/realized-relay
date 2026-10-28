#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
. "$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)/helpers.sh"

ROOT=$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd)
wf="$ROOT/.github/workflows/protected-paths.yml"

if [ ! -f "$wf" ]; then
	# Bootstrap: workflow YAML cannot be pushed without Workflows write on the token.
	# Jose adds .github/workflows/protected-paths.yml from the PR comment; then these asserts run.
	echo "notice: protected-paths workflow absent; skipping WF-* asserts"
	finish
fi

expect_exit WF-yaml 0 run_eval grep -q "pull_request_target:" "$wf"
expect_exit WF-types 0 run_eval grep -E -q "\[opened, synchronize, reopened, edited, ready_for_review\]" "$wf"
expect_exit WF-job-name 0 run_eval grep -q "protected-paths" "$wf"
expect_exit WF-permissions-contents 0 run_eval grep -q "contents: read" "$wf"
expect_exit WF-permissions-prs 0 run_eval grep -q "pull-requests: read" "$wf"
expect_omits WF-no-write "write" "$(cat "$wf")"
expect_exit WF-checkout-base 0 run_eval grep -q "ref: \${{ github.event.pull_request.base.sha }}" "$wf"
expect_exit WF-persist-credentials-false 0 run_eval grep -q "persist-credentials: false" "$wf"
expect_exit WF-actions-checkout-sha 0 run_eval grep -q "actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683" "$wf"

finish
