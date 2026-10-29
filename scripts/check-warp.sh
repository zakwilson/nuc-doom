#!/usr/bin/env bash
# Warp gate: loads every shareware map at each skill and plays it for a while
# with no input, which must end in the requested framedump rather than a crash.
# Usage: scripts/check-warp.sh [tics]
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
IWAD=${IWAD:-${CHOCOLATE_DOOM:-/home/zak/code/chocolate-doom}/src/DOOM1.WAD}
TICS=${1:-700}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

. "$ROOT/scripts/env.sh"
(cd "$ROOT" && nucleus build) > "$TMP/build.log" 2>&1 || { cat "$TMP/build.log"; exit 2; }

fail=0
for skill in 1 3 5; do
    for map in 1 2 3 4 5 6 7 8 9; do
        out="$TMP/e1m$map-$skill"
        mkdir -p "$out"
        SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout -k 5 120 "$ROOT/build/nuc-doom" \
            -iwad "$IWAD" -nosound -config "$TMP/none.edn" -warp 1 "$map" -skill "$skill" -framedump "$TICS" "$out" \
            > "$out.log" 2>&1
        rc=$?
        if [ $rc -eq 0 ] && [ -f "$out/tic$(printf '%05d' "$TICS").ppm" ]; then
            echo "e1m$map skill $skill: ok"
        else
            echo "e1m$map skill $skill: FAILED (exit $rc)"
            tail -3 "$out.log"
            fail=1
        fi
    done
done
exit $fail
