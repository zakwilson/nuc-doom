#!/usr/bin/env bash
# Demo-sync gate: plays demo1-3 under -timedemo with -tichash and diffs each
# against reference/data/. Reports the first divergent tic and which fields differ.
# Usage: scripts/check-demos.sh [demo1 demo2 demo3]
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
IWAD=${IWAD:-${CHOCOLATE_DOOM:-/home/zak/code/chocolate-doom}/src/DOOM1.WAD}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

. "$ROOT/scripts/env.sh"
(cd "$ROOT" && nucleus build) > "$TMP/build.log" 2>&1 || { cat "$TMP/build.log"; exit 2; }

demos=("$@")
[ ${#demos[@]} -eq 0 ] && demos=(demo1 demo2 demo3)

fail=0
for d in "${demos[@]}"; do
    want="$ROOT/reference/data/$d.tichash"
    got="$TMP/$d.tichash"
    SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout -k 5 600 "$ROOT/build/nuc-doom" \
        -iwad "$IWAD" -nosound -timedemo "$d" -tichash "$got" > "$TMP/$d.log" 2>&1
    if [ ! -f "$got" ]; then
        echo "$d: FAIL (no tichash written; last output: $(tail -1 "$TMP/$d.log"))"
        fail=1
        continue
    fi
    if cmp -s "$want" "$got"; then
        echo "$d: ok ($(wc -l < "$got") tics)"
        continue
    fi
    fail=1
    n=$(cmp "$want" "$got" 2>&1 | sed -n 's/.* line \([0-9]*\).*/\1/p')
    if [ -z "$n" ]; then
        echo "$d: FAIL (ended early after $(wc -l < "$got") of $(wc -l < "$want") tics)"
        continue
    fi
    w=$(sed -n "${n}p" "$want")
    g=$(sed -n "${n}p" "$got")
    fields=$(paste -d'\n' <(tr ' ' '\n' <<< "$w") <(tr ' ' '\n' <<< "$g") |
        paste - - | awk -F'\t' '$1 != $2 { split($1, k, "="); printf "%s ", k[1] }')
    echo "$d: FAIL at line $n, fields: ${fields:-<line count>}"
    echo "  want: $w"
    echo "  got:  $g"
done
exit $fail
