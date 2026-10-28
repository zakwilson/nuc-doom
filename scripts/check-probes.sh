#!/usr/bin/env bash
# Reruns every probes/issue-NNN.nuc and reports which issues still reproduce.
# Each probe's header carries one line saying what "fixed" looks like:
#   ; fixed-when: compiles               the compile succeeds
#   ; fixed-when: runs                   it compiles, runs and exits 0
#   ; fixed-when: compile-fails          the compiler rejects it
#   ; fixed-when: output-contains TEXT   compiler or program output contains TEXT
# and optionally `; flags: ...` with extra nucleusc arguments ($ROOT expands to
# the repo root).
# Usage: scripts/check-probes.sh [issue-NNN ...]
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/scripts/env.sh"
NUCLEUSC="$NUCLEUS_HOME/build/nucleusc"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

if [ $# -gt 0 ]; then
    probes=()
    for p in "$@"; do probes+=("$ROOT/probes/${p%.nuc}.nuc"); done
else
    probes=("$ROOT"/probes/issue-*.nuc)
fi

reproduce=0 fixed=0
for p in "${probes[@]}"; do
    id=$(basename "$p" .nuc)
    rule=$(sed -n 's/^; fixed-when: *//p' "$p" | head -1)
    flags=$(sed -n 's/^; flags: *//p' "$p" | head -1)
    flags=${flags//\$ROOT/$ROOT}
    out="$TMP/$id.out"
    # shellcheck disable=SC2086
    (cd "$ROOT" && "$NUCLEUSC" $flags "$p" -o "$TMP/$id") > "$out" 2>&1
    built=$?
    ran=1
    if [ $built -eq 0 ]; then
        (cd "$ROOT" && timeout 20 "$TMP/$id") >> "$out" 2>&1
        ran=$?
    fi
    case "$rule" in
        compiles)          [ $built -eq 0 ] ;;
        runs)              [ $built -eq 0 ] && [ $ran -eq 0 ] ;;
        compile-fails)     [ $built -ne 0 ] ;;
        output-contains\ *) grep -qF -- "${rule#output-contains }" "$out" ;;
        *) echo "$id: no '; fixed-when:' line"; reproduce=$((reproduce + 1)); continue ;;
    esac
    if [ $? -eq 0 ]; then
        echo "$id: FIXED"
        fixed=$((fixed + 1))
    else
        echo "$id: reproduces ($(head -1 "$out"))"
        reproduce=$((reproduce + 1))
    fi
done
echo "$reproduce reproduce, $fixed fixed"
