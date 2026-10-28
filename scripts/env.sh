# Source this: `. scripts/env.sh`. Sets NUCLEUS_HOME (a Nucleus tree with a built
# compiler) and, in the container, LD_LIBRARY_PATH for the host's newer libLLVM.
# On the host the real tree's compiler runs natively and is used as is; in the
# container the compiler is built in a private copy (scripts/build-compiler.sh),
# because `make` in the shared tree would relink it against the container's LLVM.

_nd_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
NUCLEUS_SRC=${NUCLEUS_SRC:-/home/zak/code/nucleus}
export NUCLEUS_SRC

if env -u LD_LIBRARY_PATH "$NUCLEUS_SRC/build/nucleusc" >/dev/null 2>&1 \
   || [ "$(env -u LD_LIBRARY_PATH "$NUCLEUS_SRC/build/nucleusc" 2>&1 | head -c 6)" = "usage:" ]; then
    export NUCLEUS_HOME=${NUCLEUS_HOME:-$NUCLEUS_SRC}
else
    LD_LIBRARY_PATH=$("$_nd_root/scripts/setup-llvm.sh")
    export LD_LIBRARY_PATH
    if [ -x "$_nd_root/.toolchain/nucleus/build/nucleusc" ]; then
        export NUCLEUS_HOME=${NUCLEUS_HOME:-$_nd_root/.toolchain/nucleus}
    else
        export NUCLEUS_HOME=${NUCLEUS_HOME:-$NUCLEUS_SRC}
    fi
fi
export PATH="$NUCLEUS_HOME/build:$PATH"
unset _nd_root
