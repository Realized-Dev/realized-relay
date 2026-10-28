#!/usr/bin/env bash
set -euo pipefail
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"
fail=0
if out=$(bash sample/greet.sh world 2>/dev/null); then
  if [[ "$out" == "hello world" ]]; then echo "PASS AC-1"; else echo "FAIL AC-1 bad out: $out"; fail=1; fi
else
  echo "FAIL AC-1 exit nonzero"; fail=1
fi
set +e
out2=$(bash sample/greet.sh 2>/dev/null); ec=$?
set -e
if [[ $ec -ne 0 ]] && [[ "$out2" != hello* ]]; then echo "PASS AC-2"; else echo "FAIL AC-2 ec=$ec out=$out2"; fail=1; fi
exit "$fail"
