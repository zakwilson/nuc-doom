#!/usr/bin/env bash
# Container only: sync the Nucleus working tree into .toolchain/nucleus and build
# (and optionally test) the compiler there against the shimmed libLLVM.
# Usage: scripts/build-compiler.sh [make targets...]   (e.g. test bootstrap)
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SRC=${NUCLEUS_SRC:-/home/zak/code/nucleus}
COPY="$ROOT/.toolchain/nucleus"
LIB=$("$ROOT/scripts/setup-llvm.sh")
if [ -z "$LIB" ]; then
    echo "nucleusc runs natively here; run make in $SRC instead" >&2
    exit 1
fi
N=$(basename "$(ls "$LIB"/libLLVM.so.*.1 | head -1)" | sed 's/libLLVM\.so\.\([0-9]*\)\.1/\1/')

mkdir -p "$COPY"
# The first sync takes the host-built bin/ (the boot compiler); later syncs must
# not overwrite the copy's freshly built compiler.
if [ -e "$COPY/bin/nucleusc" ]; then
    rsync -a --delete --exclude /build --exclude /bin --exclude /.git "$SRC/" "$COPY/"
else
    rsync -a --exclude /.git "$SRC/" "$COPY/"
fi

cd "$COPY"
export LD_LIBRARY_PATH="$LIB"
make "$@" \
    LLVM_LDFLAGS="-L$LIB -Wl,-rpath,$LIB" \
    LLVM_LIBS="-l:libLLVM.so.$N.1" \
    LLVM_SYSLIBS=
