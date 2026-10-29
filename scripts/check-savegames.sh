#!/usr/bin/env bash
# Savegame gate: plays demo1-3 with -savetest, which saves to a file, reloads
# the map and restores the file every N tics, and requires the reference tic
# hashes unchanged. N defaults to 37 so the saves fall on every phase of the
# tic-driven timers; SAVETEST_EVERY overrides it.
# Usage: scripts/check-savegames.sh [demo1 demo2 demo3]
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SAVES=$(mktemp -d)
trap 'rm -rf "$SAVES"' EXIT
DEMO_ARGS="-savedir $SAVES -savetest ${SAVETEST_EVERY:-37}" "$ROOT/scripts/check-demos.sh" "$@"
