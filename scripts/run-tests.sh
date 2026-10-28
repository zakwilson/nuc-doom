#!/usr/bin/env bash
# Builds and runs the unit-test program (test/build.edn). Extra arguments go to
# the test binary (--list, --run NAME).
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/scripts/env.sh"
# The outside-the-project warnings are ISSUE-004 noise.
out=$(cd "$ROOT/test" && nucleus build 2>&1); st=$?
grep -v 'is outside the project\|belongs in build-local.edn' <<< "$out"
[ $st -eq 0 ] || exit 2
cd "$ROOT" && test/build/tests "$@"
