# Nucleus issues found by the DOOM port

Format and rules: `PROMPT.md` §7.

## Summary

| Rank | Issue | Severity | Kind | Sites |
|---|---|---|---|---|
| — | ISSUE-001 | minor | tooling | build.edn |
| — | ISSUE-002 | papercut | diagnostics | 1 |

---

## ISSUE-001: A package's header on clang's default include path gets no link flags, and the failure is a raw linker error

- **Severity:** minor
- **Kind:** tooling
- **Status:** worked-around
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

## ISSUE-002: A function-like C macro is reported as "not defined anywhere"

- **Severity:** papercut
- **Kind:** diagnostics
- **Status:** open
- **Probe:** `probes/issue-002.nuc`. Expected: the error says the imported header defines `INT64_C` as a function-like macro, which isn't imported. Actual: `error: unknown: INT64_C — not defined anywhere in this compilation unit`.
- **Port sites:** `src/main.nuc` (`SDL_WINDOWPOS_UNDEFINED`)
- **Workaround:** spell out the macro's expansion, e.g. `SDL_WINDOWPOS_UNDEFINED_MASK` for `SDL_WINDOWPOS_UNDEFINED` (which is `SDL_WINDOWPOS_UNDEFINED_DISPLAY(0)`).
- **Suggestion:** the importer already reads every `#define` through `clang -dM`. It could keep the names it skipped, with the reason, and add a note to an "undefined" error that hits one.

Context: `docs/compiler.md` ("Integer constants from a C header") documents
that function-like macros are skipped, so the behaviour is known. The problem
is the message: it says the name exists nowhere, which sends the reader to
check their spelling and imports rather than the header.

---

## What worked well
