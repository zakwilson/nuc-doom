# Nucleus issues found by the DOOM port

Format and rules: `PROMPT.md` §7.

## Summary

| Rank | Issue | Severity | Kind | Sites |
|---|---|---|---|---|
| — | ISSUE-001 | minor | tooling | build.edn |
| — | ISSUE-002 | papercut | diagnostics | 1 |
| — | ISSUE-003 | major | bug | 1 |
| — | ISSUE-004 | minor | tooling | test/build.edn |
| — | ISSUE-005 | papercut | tooling | 0 |
| — | ISSUE-006 | minor | interop | 1 |
| — | ISSUE-007 | minor | known-limitation | 2 |
| — | ISSUE-008 | major | bug | 1 |
| — | ISSUE-009 | minor | diagnostics | 137 |
| — | ISSUE-010 | major | bug | 2 |
| — | ISSUE-011 | major | known-limitation | 1 |

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

## ISSUE-003: An `if` returning a struct value or a struct literal silently returns zero

- **Severity:** major (silent wrong code)
- **Kind:** bug
- **Status:** fixed in nucleus `ca581b5`
- **Probe:** `probes/issue-003.nuc`. Expected `pick=7`. Actual `pick=0`: the IR has no phi, only `store %Fx zeroinitializer`.
- **Port sites:** `src/doom/math.nuc` (`_/`, FixedDiv's overflow clamp)
- **Workaround:** none needed after the fix. Before it, wrap the literal in `(deref …)` or use explicit `(return …)` in each branch.
- **Suggestion:** done. A cond branch that is an `&S` now loads under a by-value `S` want, as every other typed slot does. A cond whose branches still disagree is now an error at an implicit or explicit struct return, not a zero.

Context: `(if (< x 0) FIXED-MIN FIXED-MAX)` works, and so does
`(if c (Fixed 1) (Fixed 2))`. Mixing a struct value (a `defconst`, a call
result) with a compound literal makes the cond's type "either Fixed or &Fixed".
That collapses the cond to void. A `let` reports the collapse, but the
implicit-return path treats a void tail as a "degenerate fall-off" and returns
`zeroinitializer`. FixedDiv's clamp returned 0 instead of `INT_MAX`, which the
first unit test caught. In the playsim it would have been a desync.

---

## ISSUE-004: A project builds one program, so the unit tests need a second project that reaches outside itself

- **Severity:** minor
- **Kind:** tooling
- **Status:** worked-around
- **Probe:** `test/build.edn` (`:entry "../src/tests/main.nuc" :source-root "../src"`) warns at every build: `:entry '../src/tests/main.nuc' is outside the project`, and the same for `:source-root`. Test records then carry paths like `/…/test/../src/tests/math.nuc`.
- **Port sites:** `test/build.edn`
- **Workaround:** a second project under `test/` whose entry and source root point back into `src/`. The warnings are noise on every run.
- **Suggestion:** a `:programs` map (or `:tests`) in `build.edn`, naming several entries that share one source root and settings; `nucleus test` to build and run the test entry.

Context: `PROMPT.md` asks for unit tests in a test program built beside the
game. `docs/build.md` has one `:entry` per project, and a target can't set it
("The project's own keys … are refused inside a target"). The suggested home for
an outside path, `build-local.edn`, is uncommitted, so it doesn't fit a test
program every checkout needs.

---

## ISSUE-005: The project-root search crosses repository boundaries, so the Nucleus test suite fails inside another project

- **Severity:** papercut
- **Kind:** tooling
- **Status:** open
- **Probe:** a Nucleus checkout under any directory that has a `build.edn` (here `.toolchain/nucleus` under the port's root). `make test` then fails 13 `suite-build` tests, e.g. `bt5-zero-config-and-staleness`: `nucleus: error: no C package satisfies 'SDL2/SDL.h' / note: build.edn:4 requires ["sdl2"]`. Their scratch projects under `build/out/nt` have no `build.edn`, so `tool-find-root` climbs to the outer project's.
- **Port sites:** none (the compiler-fix gate's baseline)
- **Workaround:** count those 13 as baseline failures in this container.
- **Suggestion:** stop the root search at a VCS root (`.git`), or give `nucleus` a `--project-root`/`NUCLEUS_PROJECT_ROOT` the test harness can pin. A zero-config test can then say what it means.

Context: `docs/build.md` says the root is "the nearest directory at or above
the current one that has a `build.edn`". Nothing bounds the climb, so a
scratch project's meaning depends on where the checkout happens to live.

---

## ISSUE-006: C header variables such as `stderr` are not imported, and the error doesn't say why

- **Severity:** minor
- **Kind:** interop
- **Status:** open
- **Probe:** `probes/issue-006.nuc`. Expected: `stderr` resolves to `extern FILE *stderr`. Actual: `error: undefined: stderr — not defined anywhere in this compilation unit`. In a namespaced file whose unit also imports `nucleus.vector`, the error is `undefined: stderr — defined in namespace 'nucleus.vector', which this file does not import`. That points at an unrelated library, which declares its own `(extern stderr:ptr)`.
- **Port sites:** `src/doom/bytes.nuc` (`; ISSUE-006`)
- **Workaround:** an explicit `(extern stderr:ptr)` beside the import.
- **Suggestion:** import a header's object declarations as `extern`s, as functions are imported as `declare`s. Failing that, the "undefined" error could note that the name is a variable in an imported header.

Context: `docs/compiler.md` covers what a header import brings in (functions,
typedefs, structs, integer constants). Variables are never mentioned, and
`docs/structs-unions.md` hints that the importer skips them ("a preprocessed
header is full of variables"). `stderr` is the first thing an error path
reaches for.

---

## ISSUE-007: `unwrap-or` and `if-some` work only on pointer Maybes, so a `?usize` from the stdlib needs a full `match`

- **Severity:** minor
- **Kind:** known-limitation
- **Status:** worked-around
- **Probe:** `probes/issue-007.nuc`. Expected: `(unwrap-or (strview-find &hay &needle) 99)` is the index. Actual: `unwrap-or: value must be (Maybe (ref ...)) — launder an unchecked pointer with (as-ref ...)`.
- **Port sites:** `src/tests/tables.nuc` (2, `; ISSUE-007`)
- **Workaround:** `(match (strview-find &src &kv) ((some k) k) (none (len src)))`.
- **Suggestion:** give `unwrap-or`, `if-some` and `when-some` a value-Maybe arm. The tag test and payload read are what `match` already emits. The error message's advice to launder through `as-ref` doesn't apply to a `usize`.

Context: `docs/types.md` says the relabels "stay pointer-only". But the stdlib's
own search functions (`strview-find`, `strview-find-byte`) return value Maybes,
so the most common "position or else" idiom needs the long form. The error
then suggests a pointer cast, which is the wrong fix.

---

## ISSUE-008: A stdlib template method is reported as a duplicate public definition between two namespaces

- **Severity:** major (a correct program is refused, and the message points at lines that don't exist)
- **Kind:** bug
- **Status:** worked-around
- **Probe:** `probes/issue-008.nuc` (with `probes/issue-008/a.nuc`, `b.nuc`). Expected: it compiles and exits 0. Actual: `issue-008/b.nuc:99: error: duplicate definition of 'count' — the same parameter types are already defined at issue-008/a.nuc:99`. Both files are under 15 lines. Line 99 is `count` in `lib/nucleus/vector.nuc`.
- **Port sites:** `src/doom/wad.nuc` (`add-lump`, `; ISSUE-008`)
- **Workaround:** make the private helper public (`defn` for `defn-`).
- **Suggestion:** a stamped stdlib method belongs to the template's namespace, so its privacy, duplicate check and reported location should be the template's, not the calling file's.

Context: it takes three things in `a.nuc` to trigger: a `defn-` that calls
`count` on a `(Vector Lump)`, a public `defn` that also calls it, and a
`(HashMap i64 i32)` in the same file. Then `b.nuc`'s `count` on a
`(Vector i64)` collides. Removing any one of the three makes it compile. In
the port it surfaced only when the WAD module and an unrelated test file met
in one unit. Its message (a duplicate `count` at line 99 of two short files)
gave no lead, so it took a delta-reduction script to find.

---

## ISSUE-009: `bit-or` takes exactly two operands, and in a constant initializer the arity error becomes "not a compile-time constant"

- **Severity:** minor
- **Kind:** diagnostics (and a design gap: `+` and `*` are variadic, the bit operators are not)
- **Status:** worked-around
- **Probe:** `probes/issue-009.nuc`. Expected: `bit-or expects 2 args`, which is what a function body says. Actual: `defvar: init must be a compile-time constant (a literal, a named constant, or an expression over them)`. That names `defvar` for a `defconst` and blames the operands.
- **Port sites:** `src/doom/tablegen.nuc` (`bit-or*`), used by the 137 `mobj-info` rows
- **Workaround:** `(defmacro bit-or* (:rest xs) \`(macfoldr bit-or 0 ~@xs))`, which `docs/macros.md` shows how to write.
- **Suggestion:** make `bit-and`/`bit-or`/`bit-xor` variadic macros over binary primitives, as `+` is over `_+`. In `const-fold-int`, report a known operator with the wrong arity as an arity error.

Context: `MF_SOLID|MF_SHOOTABLE|MF_DROPOFF|MF_PICKUP|MF_NOTDMATCH` is the
normal shape of a Doom flags field. The real cause took a field-by-field
bisection of a 23-field row to find, because the error points at the whole
1,390-line table's closing form.

---

## ISSUE-010: A `fn` that reads a global table is refused as capturing a "runtime local"

- **Severity:** major (every `deftest` body is a `fn`, so no test could read a table)
- **Kind:** bug
- **Status:** fixed in nucleus `0f703f5`
- **Probe:** `probes/issue-010.nuc`. Expected: compiles; `TABLE` is a global. Actual: `` `fn` cannot capture runtime local 'TABLE'; use vfn (clone), mfn (move), or cfn (reference) ``.
- **Port sites:** `src/tests/tables.nuc` (both table tests), and later every menu or callback `fn` that touches a table
- **Workaround:** none needed after the fix.
- **Suggestion:** done. The capture walk now also asks whether the symbol's home is the global scope. `is-local` is 1 for every stored global (the repo's `context/conventions.md` says so), so it couldn't tell the two apart. The same walk made `vfn` capture a stored global by value, a stale copy; it now reads the live global.

Context: a scalar `defconst` is a literal and was never affected. An aggregate
`defconst` or any `defvar` hit it. `deftest` wraps its body in a `fn`, so
the first test to compare a table element tripped it.

---

## ISSUE-011: `SDL_Event` imports as an opaque type, because the importer can't fold a `?:` in an array extent

- **Severity:** major (every SDL program's event loop needs it)
- **Kind:** known-limitation
- **Status:** worked-around
- **Probe:** `probes/issue-011.nuc`. Expected: `(alloca SDL_Event)` compiles. Actual: `alloca: 'SDL_Event' is an opaque type declared at /usr/include/SDL2/SDL_events.h:655; only pointers to it are valid`.
- **Port sites:** `src/doom/main.nuc` (`pump-events`, `; ISSUE-011`); the input code in M5 adds more
- **Workaround:** a 64-byte, 8-aligned `EventBuf` struct, passed to `SDL_PollEvent` with `unsafe/cast` and read through `SDL_CommonEvent`/`SDL_KeyboardEvent` casts. These are the casts the import was supposed to remove.
- **Suggestion:** fold `?:` and the comparison operators in the header constant evaluator. Clang has already preprocessed the text, and the operators are the same C integer semantics the evaluator implements for `+` and `<<`. Short of that, the "opaque type" error could say which member made the type opaque (here, `padding`'s extent).

Context: `docs/compiler.md` lists `?:` and comparisons among the things the
macro evaluator skips, and `docs/structs-unions.md` says an unfoldable array
extent skips the whole struct. The rule is documented. Its cost is not: SDL
wrote that extent to pin the union's ABI, and it costs Nucleus the most
important type in SDL. The message names the union's declaration line, not
the member that caused it, so finding the cause meant reading
`SDL_events.h`.

---

## What worked well

- **Row-set macros for `info.c`.** A table macro holding the rows, plus
  three small expanders (`def-enum-rows`, `def-count-row`, `def-table-rows` in
  `src/doom/tablegen.nuc`), turns `info.c`/`info.h`'s hand-synced enum and
  arrays into one row per state or thing. The names can't drift from the data,
  and the counts (`NUM-STATES` …) are derived. 4,662 + 1,331 C lines became
  1,390 Nucleus lines.
- **A distinct `Fixed` type is cheap to write.** A one-field struct plus
  overloaded `_+ _- _* _/ < …` gives `(* a b)` with FixedMul semantics, and an
  accidental `(+ fixed 5)` is a compile error. Mixed forms (`Fixed * i32`)
  are one more overload each.
- **`!T` and `try` for the WAD reader.** A missing lump or bad header
  propagates to `main` without the C's `I_Error` exits scattered through
  `w_wad.c`.
- **`nucleus.test`.** `deftest` plus `check-eq-int` made the element-wise
  table-equality gate about 60 lines, reading `tables.c` at test time.
