# Nucleus issues found by the DOOM port

Format and rules: `PROMPT.md` §7.

## Summary

| Rank | Issue | Severity | Kind | Sites |
|---|---|---|---|---|
| — | ISSUE-001 | minor | tooling | build.edn |

---

## ISSUE-001: A package's header on clang's default include path gets no link flags, and the failure is a raw linker error

- **Severity:** minor
- **Kind:** tooling
- **Probe:** a project whose `src/main.nuc` does `(import-use "SDL2/SDL.h")` and calls `SDL_Init`, with no `build.edn`. `nucleus build` compiles it, then fails at link time with `undefined reference to 'SDL_Init'` and `nucleusc: link step failed (clang exit 1)`. Expected: the build tool links `sdl2`, or stops before compiling with a note naming the header and the `:pkg-config` entry to add.
- **Port sites:** `build.edn` (one entry per SDL header)
- **Workaround:** `:pkg-config {"SDL2/SDL.h" ["sdl2"]}` in `build.edn`.
- **Suggestion:** consult the header index for every imported header, not only for ones clang can't find. Failing that, map an unresolved link symbol back to the header that declared it.

Context: `docs/build.md` ("The header index") documents this: a header is looked
up only when clang's own include path doesn't find it. `SDL2/SDL.h` lives under
`/usr/include`, so it is never looked up, and nothing tells the user that a
package is missing. Found while preparing the port's environment, before any
port code was written.

---

## What worked well
