#!/usr/bin/env bash
# Frame gate: renders each reference frame with -framedump and compares it with
# reference/data/frames/. On a mismatch, reports how many pixels differ.
# Usage: scripts/check-frames.sh [title e1m1]
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
IWAD=${IWAD:-${CHOCOLATE_DOOM:-/home/zak/code/chocolate-doom}/src/DOOM1.WAD}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

. "$ROOT/scripts/env.sh"
(cd "$ROOT" && nucleus build) > "$TMP/build.log" 2>&1 || { cat "$TMP/build.log"; exit 2; }

# name, dump tic, extra arguments; these must match how the reference was recorded.
declare -A TIC=([title]=5 [e1m1]=40)
declare -A ARGS=([title]="" [e1m1]="-warp 1 1")

frames=("$@")
[ ${#frames[@]} -eq 0 ] && frames=(title e1m1)

fail=0
for f in "${frames[@]}"; do
    tic=$(printf '%05d' "${TIC[$f]}")
    want="$ROOT/reference/data/frames/$f/tic$tic.ppm"
    mkdir -p "$TMP/$f"
    # shellcheck disable=SC2086
    SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout -k 5 60 "$ROOT/build/nuc-doom" \
        -iwad "$IWAD" -nosound -config "$TMP/none.edn" ${ARGS[$f]} -framedump "${TIC[$f]}" "$TMP/$f" > "$TMP/$f.log" 2>&1
    got="$TMP/$f/tic$tic.ppm"
    if [ ! -f "$got" ]; then
        echo "$f: FAIL (no frame written; last output: $(tail -1 "$TMP/$f.log"))"
        fail=1
    elif cmp -s "$want" "$got"; then
        echo "$f: ok"
    else
        fail=1
        echo -n "$f: "
        python3 - "$want" "$got" <<'EOF'
import sys
a, b = (open(p, "rb").read()[15:] for p in sys.argv[1:])
diff = [i // 3 for i in range(0, min(len(a), len(b)), 3) if a[i:i+3] != b[i:i+3]]
first = diff[0] if diff else 0
# The status bar is the bottom 32 rows; it is drawn separately from the view.
bar = sum(1 for p in diff if p // 320 >= 168)
print(f"FAIL: {len(diff)} of {len(a)//3} pixels differ ({len(diff) - bar} above the status bar), first at x={first%320} y={first//320}")
EOF
    fi
done
exit $fail
