# nuc-doom

A port of Chocolate Doom to the Nucleus language. Its **primary purpose is to
stress-test Nucleus** and record language problems in `ISSUES.md`; the playable
port is secondary. The full brief is in `PROMPT.md`, and current status is in
`PROGRESS.md`.

## Locations

- `/home/zak/code/chocolate-doom`: the C original. **Read-only.** The game is in
  `src/doom/`, platform and shared code in `src/*.c`. `src/chocolate-doom` is a
  built reference binary, and `src/DOOM1.WAD` is the shareware v1.9 IWAD (the
  only IWAD available).
- `/home/zak/code/nucleus`: the language, on branch `doom-bugfixes`. You may fix
  compiler **bugs** there (`PROMPT.md` §7, "Fixing the compiler"), following
  that repo's own `CLAUDE.md`. **Never run `make` in that tree.** Its binaries
  are host-built, and `make` in the container would relink them against LLVM 19.
  Docs are in `docs/`, idiom examples in `examples/`, the stdlib in
  `lib/nucleus/`, and design history and known gaps in `design/`.

## Environment

The container runs LLVM 19, but the Nucleus binaries are built on the host
against a newer `libLLVM.so.N` (currently 23). Everything goes through two
scripts:

- `. scripts/env.sh` sets `NUCLEUS_HOME` and puts `$NUCLEUS_HOME/build` on
  `PATH`, so `nucleus` and `nucleusc` resolve.
  - **On the host:** the real tree's compiler runs natively and is used as is.
  - **In the container:** the script sets `LD_LIBRARY_PATH` to the libLLVM that
    `scripts/setup-llvm.sh` unpacks into `.toolchain/`. It then uses the
    compiler built in `.toolchain/nucleus`, falling back to the real tree's
    binary if that copy hasn't been built yet.
- `scripts/build-compiler.sh [make targets]` (container only) rsyncs the Nucleus
  working tree into `.toolchain/nucleus` and runs `make` there, against the
  shim. With no arguments it builds in about a minute; `-k test bootstrap` runs the
  gates. **Rerun it after every Nucleus source change.** The port otherwise
  keeps using the old compiler.
  - Five `suite-target` datalayout tests always fail in the container
    (baseline 2026-10-28: 1611 passed, 5 failed, bootstrap PASS). Their failure
    makes `make test` exit non-zero, which is why the bootstrap needs `-k` to
    run after it.
  - On the host, compiler fixes take effect only after `make` in
    `/home/zak/code/nucleus`. Say so in every playtest request.

Other environment facts:
- **No display.** Run everything with
  `SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy`. The user playtests on the host.
- **SDL2 needs an explicit package mapping.** `SDL2/SDL.h` resolves through
  clang's default include path, so the build tool never consults pkg-config and
  the link fails with undefined `SDL_*` symbols (ISSUE-001). `build.edn` must
  carry `:pkg-config {"SDL2/SDL.h" ["sdl2"] "SDL2/SDL_mixer.h" ["SDL2_mixer"]}`.
- **Installed:** SDL2 2.32, SDL2_mixer 2.8, SDL2_net 2.2, clang 19 (the link
  driver) and rsync.
- **The reference engine** is built by `scripts/build-reference.sh` (it skips
  the build if the binary exists, so delete `reference/build/src/chocolate-doom`
  after editing the patch). Always pass `-nosound`, which is much faster and
  hashes the same. A `-framedump` run exits by itself after its last dump. A
  `-timedemo` run ends in `I_Error` (exit 255) on the demo's end marker.
- **Probes** state their own pass condition on a `; fixed-when:` header line
  (see `scripts/check-probes.sh`).
- **Keep Bash calls small.** A big compound command (edits plus `rm` of a
  wildcard plus runs) gets denied by the permission policy. Use Edit for
  source changes and run steps separately.

## Commands

```
. scripts/env.sh
nucleus build               # → build/nuc-doom
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy build/nuc-doom -iwad /home/zak/code/chocolate-doom/src/DOOM1.WAD
scripts/check-demos.sh      # demo-sync gate against reference/data/
scripts/check-probes.sh     # which ISSUES.md probes still reproduce
scripts/build-compiler.sh && scripts/build-compiler.sh -k test bootstrap   # after a Nucleus fix
```

Under `-timedemo`, the reference engine plays demo1/2/3 in 5658, 13980 and 13605
gametics. A desynced demo still runs to its end, so only the tic-hash diff proves
sync.

## Layout

- `src/` holds the Nucleus sources, organized by subsystem namespace
  (`doom.wad`, `doom.render.*`, `doom.play.*`, …), not one file per C file.
- `probes/` holds minimal standalone repros, one per bug-kind issue
  (`issue-NNN.nuc`).
- `reference/` holds the reference-engine instrumentation patch and the recorded
  per-tic hashes and framedumps. `reference/build/` is a patched copy of
  Chocolate Doom (gitignored).
- `scripts/` holds the environment, gate and probe scripts.
- `.toolchain/` (gitignored) holds the libLLVM shim and the private compiler
  build.

## Rules

- **No subagents and no workflows.** The harness auto-resumes the main thread
  after a session limit, but not a subagent.
- **Language problems go to `ISSUES.md`** when you hit them, in the format
  `PROMPT.md` §7 defines. Each bug needs a probe, and each workaround site is
  tagged `; ISSUE-NNN`. Before calling something new, check `nucleus/docs` and
  `nucleus/design` for whether it's already known.
- **The playsim is fixed-point and must stay in demo sync** (`PROMPT.md` §6.1).
  No floats in `doom.play.*`; keep the RNG, thinker order and blockmap order
  exact. If that constraint gets in the way, record it as an issue.
- **Nothing may hardcode container paths.** The port must also build on the
  host.
- **Never discard work with git** in either repo (`restore`, `checkout <file>`,
  `reset --hard`, `clean`). Fix the source instead.
- The code is GPLv2: keep `COPYING` and the upstream copyright headers.
- Comments say *why*, in one or two lines. Never restate what the code does.
- When you discover a non-obvious environment or workflow fact, add it here.
  Language findings go to `ISSUES.md`, not here.
