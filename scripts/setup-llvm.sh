#!/usr/bin/env bash
# Makes the host-built nucleusc runnable in a container whose system LLVM is older.
# Prints the directory to put on LD_LIBRARY_PATH. Idempotent.
set -euo pipefail

NUCLEUSC=${NUCLEUSC:-/home/zak/code/nucleus/build/nucleusc}
ROOT=$(cd "$(dirname "$0")/.." && pwd)

missing=$(env -u LD_LIBRARY_PATH ldd "$NUCLEUSC" | sed -n 's/^\s*\(libLLVM\.so\.[0-9]*\)\.1 => not found.*/\1/p')
if [ -z "$missing" ]; then
    echo "nucleusc already runs; no LD_LIBRARY_PATH needed" >&2
    exit 0
fi
N=${missing#libLLVM.so.}
DIR="$ROOT/.toolchain/llvm$N"
LIB="$DIR/usr/lib/x86_64-linux-gnu"

if [ ! -e "$LIB/libLLVM.so.$N.1" ]; then
    mkdir -p "$DIR"
    base="https://apt.llvm.org/trixie"
    pool=$(curl -fsS "$base/dists/llvm-toolchain-trixie-$N/main/binary-amd64/Packages.gz" \
        | zcat | awk -v p="libllvm$N" '$1=="Package:"{m=($2==p)} m&&$1=="Filename:"&&!f{f=$2} END{print f}')
    curl -fsS "$base/$pool" -o "$DIR/libllvm.deb"
    dpkg-deb -x "$DIR/libllvm.deb" "$DIR"
    rm "$DIR/libllvm.deb"
fi
echo "$LIB"
