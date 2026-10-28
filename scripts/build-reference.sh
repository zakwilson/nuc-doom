#!/usr/bin/env bash
# Builds the instrumented reference engine in reference/build: a copy of
# Chocolate Doom with reference/tichash.patch applied (-tichash, -framedump).
# Usage: scripts/build-reference.sh [--record]   (--record regenerates reference/data)
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SRC=${CHOCOLATE_DOOM:-/home/zak/code/chocolate-doom}
OUT="$ROOT/reference/build"
IWAD=${IWAD:-$SRC/src/DOOM1.WAD}

if [ ! -x "$OUT/src/chocolate-doom" ]; then
    rm -rf "$OUT"
    mkdir -p "$OUT"
    rsync -a --exclude .git --exclude '*.o' --exclude '*.a' \
        --exclude 'src/chocolate-*' --exclude autom4te.cache "$SRC/" "$OUT/"
    (cd "$OUT" && patch -p1 < "$ROOT/reference/tichash.patch")
    (cd "$OUT" && ./configure > config.out 2>&1)
    for d in textscreen opl pcsound; do make -j"$(nproc)" -C "$OUT/$d" > /dev/null; done
    make -j"$(nproc)" -C "$OUT/src" chocolate-doom > /dev/null
fi

if [ "${1:-}" = "--record" ]; then
    mkdir -p "$ROOT/reference/data"
    for d in demo1 demo2 demo3; do
        SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy "$OUT/src/chocolate-doom" \
            -iwad "$IWAD" -nosound -timedemo "$d" \
            -tichash "$ROOT/reference/data/$d.tichash" > /dev/null 2>&1 || true
        echo "$d: $(wc -l < "$ROOT/reference/data/$d.tichash") tics"
    done
fi
