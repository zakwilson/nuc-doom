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
| — | ISSUE-012 | major | bug | 1 |
| — | ISSUE-013 | minor | known-limitation | 2 |
| — | ISSUE-014 | major | bug | 1 |
| — | ISSUE-015 | minor | bug | 0 |
| — | ISSUE-016 | papercut | bug | 24 |
| — | ISSUE-017 | papercut | design gap | 1 |
| — | ISSUE-018 | papercut | design gap | 4 |
| — | ISSUE-019 | papercut | diagnostics | 0 |
| — | ISSUE-020 | papercut | docs | 1 |
| — | ISSUE-021 | minor | design gap | many |
| — | ISSUE-022 | major | bug | 1 |
| — | ISSUE-023 | major | bug | 1 |
| — | ISSUE-024 | minor | bug | 8 |
| — | ISSUE-025 | minor | design gap | 13 |
| — | ISSUE-026 | minor | design gap | ~15 |
| — | ISSUE-027 | major | bug | 1 |
| — | ISSUE-028 | papercut | stdlib gap | 1 |
| — | ISSUE-029 | papercut | diagnostics | 0 |
| — | ISSUE-030 | minor | bug | 1 |
| — | ISSUE-031 | minor | bug | 0 |
| — | ISSUE-032 | major | bug | 0 |
| — | ISSUE-033 | major | bug | 0 |
| — | ISSUE-034 | minor | bug | 0 |
| — | ISSUE-035 | papercut | stdlib gap | 4 |
| — | ISSUE-036 | papercut | stdlib gap | 5 |
| — | ISSUE-037 | papercut | design gap | 1 |
| — | ISSUE-038 | major | bug | 0 |
| — | ISSUE-039 | major | bug | 0 |
| — | ISSUE-040 | critical | bug | 0 |
| — | ISSUE-041 | major | bug | 1 |
| — | ISSUE-042 | major | bug | 0 |
| — | ISSUE-043 | papercut | diagnostics | 1 |
| — | ISSUE-044 | minor | bug | 0 |
| — | ISSUE-045 | minor | known-limitation | 1 |

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
- **Status:** fixed in nucleus `01b61c1`
- **Probe:** `probes/issue-008.nuc` (with `probes/issue-008/a.nuc`, `b.nuc`). Expected: it compiles and exits 0. Actual: `issue-008/b.nuc:99: error: duplicate definition of 'count' — the same parameter types are already defined at issue-008/a.nuc:99`. Both files are under 15 lines. Line 99 is `count` in `lib/nucleus/vector.nuc`.
- **Port sites:** `src/doom/wad.nuc` (`add-lump`, private again since the fix)
- **Workaround:** none needed after the fix. Before it, the private helper was made public (`defn` for `defn-`).
- **Suggestion:** done. A stamped method now takes the template's `src-file` and `priv`, as it already took its namespace and imports. A stamp made from inside a `defn-` body had been private, so the next namespace's memo probe missed it and stamped a duplicate.

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

## ISSUE-012: A user `defunion` shaped like a `Maybe` refuses its own arm names

- **Severity:** major (any two-arm "nothing or a reference" union is unusable)
- **Kind:** bug
- **Status:** fixed in nucleus `dd3f165`
- **Probe:** `probes/issue-012.nuc`. Expected: `(defunion Slot empty (full b:&Box))` constructs and matches as `Slot-empty`/`Slot-full`. Actual: `niche (Maybe (ref T)) has arms `some`/`none`, not 'empty'`.
- **Port sites:** `src/doom/world.nuc` (`Thinker`, while it had only the list head and the mobj arm)
- **Workaround:** `:repr tagged`, or a third arm.
- **Suggestion:** fixed by giving such a union the tagged layout unless its arms are named `some`/`none` (or `ok`/`err` for the error niche). The niche value is a bare pointer and can't carry other names.

Context: `structs-unions.md` says the layout rules are invisible: "User code
does not need to know which rule applies." Rule 2 matched on shape alone,
though, and the niche constructors and `match` know only `Maybe`'s arm names.
So the first draft of the thinker union (a list-head arm and a mobj arm) failed
in the union's own definition, with an error naming arms the user never wrote.

---

## ISSUE-013: A struct template stamped over a nullable pointer gets a non-null field

- **Severity:** minor (it is refused at compile time, not silently wrong, and a wrapper struct gets around it)
- **Kind:** known-limitation
- **Status:** worked-around
- **Probe:** `probes/issue-013.nuc`. Expected: `((Box ?&M) null)` builds a box holding null. Actual: `assignment: unchecked pointer where non-null (ref ...) is required`. `(?ref M)`, `(? (ref M))` and `?ptr:M` fail the same way.
- **Port sites:** `src/doom/world.nuc` (`BlockLink`, `; ISSUE-013`), `src/doom/play/mobj.nuc`
- **Workaround:** a one-field struct, `(defstruct BlockLink head:?&Mobj)`, and a `(Table BlockLink)`.
- **Suggestion:** carry the pointer kind through the stamp and into the memo key (`type-mangle-token`). `design/deferred/overview.md` already names that as the fix.

Context: the blockmap's per-cell thing lists are a table of possibly-null list
heads, the most natural `(Table ?&Mobj)` there is. `design/deferred/overview.md`
("A template stamp loses the pointer kind") records this as deferred. Its
effect on users isn't documented: `docs/types.md` mentions only that a stamped
instance *prints* with the first spelling's kind. The error appears at the
first `null` store, far from the type that caused it, and says nothing about
templates.

---

## ISSUE-014: Once a unit has an import cycle, a C `typedef struct Tag {…} Name` is refused by value

- **Severity:** major (any import cycle, anywhere, breaks every by-value use of a typedef'd C struct)
- **Kind:** bug
- **Status:** fixed in nucleus `068cc73`
- **Probe:** `probes/issue-014.nuc` (with `probes/issue-014/a.nuc`, `b.nuc`). Expected: `(alloca ENTRY)` from `search.h`, and a store to `(e 'key)`, compile. Actual: `field assignment: 'ENTRY' has no layout at this point — its definition has not been emitted yet`, with a note blaming "a file this unit imports circularly". The cycle is `a` ↔ `b`; neither touches `search.h`.
- **Port sites:** `src/doom/main.nuc` (`pump-events` reads `SDL_CommonEvent`). The renderer's namespaces import each other, and that cycle broke the event loop.
- **Workaround:** none needed after the fix.
- **Suggestion:** done. `cheader-adopt-shape` (`src/cheader.nuc`) copied a typedef alias's fields from its tag but not `laid-out`, so `sdef-layout-pending` reported every such alias as pending whenever `g-import-cycles` was non-null. It now copies `laid-out` with the fields.

Context: the diagnostic is very specific and wrong. It says the type "is
defined in a file this unit imports circularly", for a type from a system
header that no file in the cycle imports. It took a three-file reduction to
see that the cycle's members don't matter, only that a cycle exists. `struct
tm` (no typedef) is unaffected, which made the first reduction pass by mistake.

---

## ISSUE-015: Compiled by absolute path with a relative `-I`, an import cycle loads a file twice

- **Severity:** minor (`nucleus build` passes consistent paths; only a hand-run `nucleusc` hits it)
- **Kind:** bug
- **Status:** open
- **Probe:** `probes/issue-015.nuc` (with `probes/issue-015/a.nuc`, `b.nuc`). Expected: compiles and exits 0. Actual: `probes/issue-015/a.nuc:3: error: duplicate definition of 'a-one' — the same parameter types are already defined at /home/…/probes/issue-015/a.nuc:3`. That is the same file under two spellings.
- **Port sites:** none; `scripts/check-probes.sh` gained `$ROOT` expansion in `; flags:` so the ISSUE-014 probe can avoid it.
- **Workaround:** pass `-I` and the main file the same way, both absolute or both relative.
- **Suggestion:** canonicalize a file's path (`realpath`) before the import-cycle and already-loaded checks.

Context: found while writing the ISSUE-014 probe, which `check-probes.sh` runs
by absolute path. The ISSUE-008 probe uses the same layout without a cycle and
is unaffected.

---

## ISSUE-016: A `defvar` can't be initialized with an aggregate `defconst`, contrary to the docs

- **Severity:** papercut
- **Kind:** bug (the documented behaviour is a startup initializer)
- **Status:** worked-around
- **Probe:** `probes/issue-016.nuc`. Expected: `(defvar g:Fx ZERO)` with `(defconst ZERO (Fx 0))` compiles and runs at startup, as `docs/toplevel.md` ("Names") says. Actual: `defvar: a Fx slot must be initialized with a (Fx ...) compound literal`.
- **Port sites:** 24 `Fixed` globals in `world.nuc` and `render/{main,plane,segs,things}.nuc`; the first in each file is tagged `; ISSUE-016`.
- **Workaround:** write the literal, `(Fixed 0)`, not `FIXED-ZERO`.
- **Suggestion:** let a named aggregate constant through to the run-time tier (or fold it: its value is known). The same check also refuses a union arm constructor as a field of a global's struct literal, which the docs do list as refused (a non-constant element of a constant aggregate). The thinker list head in `play/tick.nuc` is zero-filled because of that.

---

## ISSUE-017: A constant subexpression doesn't adapt to the other operand's type the way its leaves do

- **Severity:** papercut
- **Kind:** design gap
- **Status:** worked-around
- **Probe:** `probes/issue-017.nuc`. Expected: `(- (- BIG 1) x)` at `x:ui32` compiles, since `(- BIG x)` does. Actual: `_-: mixed signed/unsigned operands — use explicit cast`. A literal `(- 0x40000000 1)` behaves the same.
- **Port sites:** `src/doom/render/things.nuc` (`ROT-BIAS`, `; ISSUE-017`)
- **Workaround:** name the expression with a `defconst`, which adapts as a single constant.
- **Suggestion:** fold a constant operator tree first, then adapt the result as a literal. That is the rule a `defconst` already gets.

Context: the angle code is all `ui32` arithmetic with constant offsets
(`ANG90 - 1`, `ANG45/2 * 9`). The adaptation rule is per leaf, so whether it
applies depends on whether the constant is spelled as one name or as an
expression.

---

## ISSUE-018: `inc!` takes only a variable, not a place

- **Severity:** papercut
- **Kind:** design gap
- **Status:** worked-around
- **Probe:** `probes/issue-018.nuc`. Expected: `(inc! (p 'n))` increments the field, as `set!` accepts the same place. Actual: `inc!: target must be symbol`.
- **Port sites:** `src/doom/play/setup.nuc` (`group-lines`, four `; ISSUE-018`)
- **Workaround:** `(set! (p 'n) (+ (p 'n) 1))`.
- **Suggestion:** accept any `set!` place, evaluating its receiver once.

Context: `docs/builtins.md` says "Increment a variable", so it is as documented.
But C's `sector->linecount++` and `count[i]++` are the common shape, and every
one has to be written twice.

---

## ISSUE-019: A parameter that shadows a function gives an error that names neither

- **Severity:** papercut
- **Kind:** diagnostics
- **Status:** open
- **Probe:** `probes/issue-019.nuc`. Expected: a note that `fx` is the `i32` parameter, shadowing the function `fx`. Actual: `value is not callable: no `invoke` method is defined for this type`.
- **Port sites:** none left (the parameters were renamed)
- **Workaround:** rename the parameter.
- **Suggestion:** when the head of a call is a local that isn't callable and a function of that name is in scope, say so.

Context: the port has a function `fx` (int to fixed) and C code full of
variables named `fx`. The message names no type and no binding, so the first
hit took a while to read.

---

## ISSUE-020: `docs/builtins.md` gives `case` two different syntaxes

- **Severity:** papercut
- **Kind:** docs
- **Status:** worked-around
- **Probe:** none (documentation). `docs/builtins.md` line 816 gives the flat macro form `(case x v1 r1 v2 r2 default)`. Line 914 describes clauses `(KEY body...)` with `_` as the default, lowering to `switch`. Only the flat form compiles; the clause form fails with `0 is not callable`.
- **Port sites:** `src/doom/play/setup.nuc` (`pad-reject`, `; ISSUE-020`)
- **Workaround:** the flat form.
- **Suggestion:** drop or rewrite the stale row at line 914.

---

## ISSUE-021: Nested places and array elements need explicit `&`, and the stdlib has no fixed-length element view

- **Severity:** minor
- **Kind:** design gap
- **Status:** worked-around
- **Probe:** none; the rule is documented and the errors are clear.
- **Port sites:** `src/doom/table.nuc` (the whole module); `(set! (&(aref …) 'f) v)` and `(set! (&(s 'sound-org) 'x) v)` in `play/pspr.nuc`, `play/setup.nuc` and the renderer
- **Workaround:**
  - Write `&(aref arr i)` or `&(s 'inner)` before the field.
  - A global struct template is indexed through `(&g i)`, so level tables are `&(Table T)` from `new`.
  - `doom.table` defines a bounds-checked `(Table T)` whose `invoke` returns `&T`.
- **Suggestion:** treat `(aref a i)` and `(s 'f)` as places when their base is one, as C's lvalue rule does. Add a stdlib slice type, a pointer plus a length with `invoke` returning `&T`, so map data needn't be either a growable `Vector` or a raw `ptr`.

Context: `docs/structs-unions.md` is explicit that a member place needs the
receiver's storage, "a binding, not a temporary". But a global array's element
and a field of a field *have* storage in C's model. Map structures are linked
by address and mutated in place everywhere in the C. A `Vector` may move its
elements and a `ptr` has no bounds, so neither fits.

---

## ISSUE-022: A `match` whose arms mix a struct value and a struct literal silently returns zero

- **Severity:** major (silent wrong code)
- **Kind:** bug
- **Status:** fixed in nucleus `5daff8f`
- **Probe:** `probes/issue-022.nuc`. Expected `union 3 7 / enum 1 7 / niche 4 7`. Actual `union 0 0 / enum 0 0 / niche 0 0`. Bound in a `let`, the same match gives "alloca void" IR. In the port it surfaced as "internal: aggregate return of a ptr where the declared return type is Fixed".
- **Port sites:** `src/doom/play/spec.nuc` (`find-next-highest-floor`, a match on `?i32` whose arms are `(Fixed …)` and a Fixed variable)
- **Workaround:** none needed after the fix. Before it, wrap the literal in `(deref …)` or return from each arm explicitly.
- **Suggestion:** done. Both match joins now load a `&S` arm under a by-value `S` want, as cond does since ISSUE-003. A union or enum match whose arms still disagree is refused at a return. The niche-Maybe match path still doesn't record why its join was lost, so a disagreeing niche match still returns zero. One shared branch-join helper for cond and every match path would have prevented this.

Context: this is ISSUE-003 again, in the other branching form. ISSUE-003's fix
went into `emit-cond` alone, while `match` keeps two join loops of its own
(`emit-match-clauses` and `emit-niche-match-arm`). Each repeats cond's typing
rules by hand, and the comments say so.

---

## ISSUE-023: An untyped `let` binding that shares a function's name loses the let's tail to the function

- **Severity:** major (an internal error at line 0, or a refusal that names neither binding)
- **Kind:** bug
- **Status:** fixed in nucleus `ec21b5e`
- **Probe:** `probes/issue-023.nuc`. Expected `4 8`. Actual: "shadow: implicit return type mismatch — last expression does not match declared return type". With a struct return, "internal: aggregate return of a (f64):f64 where the declared return type is Fixed", at line 0.
- **Port sites:** `src/doom/play/spec.nuc` (`find-lowest-floor-surrounding`, whose local `floor` met libm's `floor`, pulled in by an import)
- **Workaround:** none needed after the fix. Before it, give the binding a type or another name.
- **Suggestion:** done. `node-type-block` now types a bare binding by its init, as `emit-let` does. The aggregate-return internal error also names its function now. The root cause is two passes that must agree: every Val's type is overwritten by `node-type`'s answer, so any form `node-type` models less precisely than the emitter is a latent miscompile. A debug mode that checks the two agree, instead of overwriting, would find the rest.

Context: the name came from an unrelated `math.h` import, three modules away,
so nothing in `spec.nuc` hinted at it. Only a temporary patch to the compiler's
message showed which function it was in.

---

## ISSUE-024: A computed `defconst` doesn't resolve across an import cycle, though the docs say constants do

- **Severity:** minor
- **Kind:** bug
- **Status:** worked-around
- **Probe:** `probes/issue-024.nuc` (with `probes/issue-024/`). Expected `sum=12`. Actual: "undefined: EXPR — defined in a file this unit imports circularly, and not registered yet at this point".
- **Port sites:** `src/doom/world.nuc` (eight playsim constants, `MELEERANGE` …, moved out of `play/map`, `play/mobj`, `play/maputl` and `play/pspr`); `src/doom/items.nuc` (the `weapon-info` table, moved out of `play/pspr` when the status bar joined the cycle and changed its emission order)
- **Workaround:** define such constants in a module outside the cycle.
- **Suggestion:** `docs/toplevel.md` ("Cross-file resolution") promises that "every function, global, constant and enum-member reference inside the cycle resolves". The prescan registers only a `defconst` whose value is a literal. A computed one (`(* 64 FRAC-UNIT)`, or even a bare `FRAC-UNIT`) waits for its file to be emitted, because macros aren't registered yet. Either fold on demand at the first reference, or add the case to the docs' table of things a cycle doesn't carry.

Context: the playsim modules call each other freely, as the C files do
through `p_local.h`, so they form one big cycle. The diagnostic was good, but
it said nothing about constants, and it named only one cycle pair.

---

## ISSUE-025: A struct literal bound by an untyped `let` is a `&S`, so `S`'s operators and `set!`s don't apply

- **Severity:** minor
- **Kind:** design gap
- **Status:** worked-around
- **Probe:** none; this is the documented rule (`docs/structs-unions.md`, "Compound literals in by-value struct positions").
- **Port sites:** 13 `name:Fixed (Fixed …)` bindings in `play/*.nuc`; `movers.nuc` `do-donut` (`s3-height`); 2 in `automap.nuc`
- **Workaround:** give the binding its type: `(let (range:Fixed (Fixed …)) …)`.
- **Suggestion:** bind an untyped struct literal as an `S` value, the way a `:S` binding takes it. Then join a `&S` literal branch with `S` siblings as `S` even with no want. Today `(let (h (if-some (s x) (s 'floor-height) (Fixed 0))) …)` collapses to void.

Context: `(let (step (Fixed (* 24 FRAC-UNIT))) (* step x))` reads as a value.
Instead it fails with "no matching method for '_*' with operand types
(&Fixed, Fixed)". `(set! step other)` fails with "value is Fixed, slot is
&Fixed". Both messages are accurate, and neither says the literal is the cause.

---

## ISSUE-026: Loops have no `break` or `continue`, and no form loops while a Maybe has a value

- **Severity:** minor
- **Kind:** design gap
- **Status:** worked-around
- **Probe:** none; nothing is broken.
- **Port sites:** about 15 loops in `play/map.nuc`, `play/maputl.nuc`, `play/movers.nuc`, `play/setup.nuc` and `render/bsp.nuc` carry an `ok`/`go`/`going`/`stopped` flag; 4 linked-list walks in `play/thinkers.nuc`, `render/things.nuc` and `automap.nuc`
- **Workaround:** a flag in the `while` test; for lists, `(while (not (null? cur)) (when-some (n cur) … (set! cur (next n))))`, hidden in `do-mobjs`. `(return)` covers a loop at the end of a function.
- **Suggestion:** a `break` (and `continue`) scoped to the nearest `while`/`dotimes`, and a `while-some` that binds the narrowed value each pass, as `when-some` does once. `label`/`goto` can express both, but they're function-scoped and read as C.

Context: the blockmap and line-iterator code is all "walk until a callback
says stop". The C writes it as `if (!func(...)) return false;` inside
nested `for` loops. The flags make each loop's test longer than its body.

---

## ISSUE-027: A field access on a string literal or string `defconst` emits invalid IR

- **Severity:** major (the whole build fails, with an LLVM parse error)
- **Kind:** bug
- **Status:** fixed in nucleus `1e1495c`
- **Probe:** `probes/issue-027.nuc`. Expected `b 3`. Actual: "failed to parse generated IR … '%t1' defined with type 'ptr' but expected '%nuc_StrView = type { ptr, i64 }'".
- **Port sites:** `src/doom/sys/input.nuc` (`typed-char` indexes the `SHIFTED` string table through `'data`)
- **Workaround:** none needed after the fix. Before it, bind the literal to a `:StrView` local first.
- **Suggestion:** done. A string literal's Val is its bare rodata pointer typed as StrView, and `materialize-struct-value` stored that pointer as a whole StrView. It now builds the view first, as other StrView consumers do. A literal whose Val doesn't hold its own type is a trap for every new consumer. Building the view when the literal is emitted, and letting LLVM fold the unused length, would remove the special case.

Context: the error came from LLVM, naming an IR temporary and the mangled
function, with no source line. Only bisecting the function by hand found
the expression.

---

## ISSUE-028: `nucleus.fmt` has no hexadecimal (or any radix) formatting

- **Severity:** papercut
- **Kind:** stdlib gap
- **Status:** worked-around
- **Probe:** none; nothing is broken.
- **Port sites:** `src/doom/status.nuc` (the `idmypos` cheat message)
- **Workaround:** `snprintf` into a fixed buffer with `%x`, as the C does.
- **Suggestion:** a `hex` wrapper (or `(radix v 16)`) with a `ToStr` method, so `(str "0x" (hex v))` works. `strview-parse-magnitude` already reads any radix, so only the writing half is missing.

Context: one site, but the obvious spelling (`str` with a hex part) has no
equivalent, so the port drops to C varargs for one message.

---

## ISSUE-029: `try` on a void call reports a `match` error

- **Severity:** papercut
- **Kind:** diagnostics
- **Status:** fixed in nucleus `5f2bfae`
- **Probe:** `probes/issue-029.nuc`. Expected: an error that says `try` needs a result (`!T`) and names the callee's type. Actual: "match: scrutinee must be a defunion value, a pointer to one, or a defenum integer".
- **Port sites:** none left (`automap-drawer` became `!void`)
- **Workaround:** drop the `try`, or make the callee fallible.
- **Suggestion:** done, together with ISSUE-033. `try` now checks its operand before expanding it into a match: "try: the operand must be a result (a !T, or a union with ok and err arms), but its type is void".

Context: stubbing a subsystem as `:void` and implementing it as `!void`
later is common in the port. The message shows `try`'s expansion, not
what was written.

---

## ISSUE-030: A struct literal can fill an array field in a global initializer but not in a function

- **Severity:** minor
- **Kind:** bug
- **Status:** worked-around
- **Probe:** `probes/issue-030.nuc`. Expected `3 6 7`. Actual: "struct literal: type mismatch for positional initializer".
- **Port sites:** `src/doom/status.nuc` (the `Cheat` constructor, dropped in favour of `defvar` literals that omit the array field)
- **Workaround:** omit the array field (it zero-fills) and set its elements afterwards, or initialize only at a `defvar`.
- **Suggestion:** at runtime, copy an `(array T N)` literal into an array field element by element, as the global initializer path already lays it out. Until then, the error should name the field and say that array fields take literals only in global initializers.

Context: `docs/structs-unions.md` shows `(Row 1 (array i32 9 8 7 6) 2)` as a
`defvar` initializer, so the same literal in a constructor function looks
fine. The message names neither the field nor the types.

---

## ISSUE-031: An array `defconst` used above its definition is "not defined anywhere", even in the same file

- **Severity:** minor
- **Kind:** bug
- **Status:** fixed in nucleus `3d8c5ab`
- **Probe:** `probes/issue-031.nuc`. Expected `2 5`. Actual: "undefined: NAMES — not defined anywhere in this compilation unit", with the note "'NAMES' is defined in ./issue-031.nuc, which no import in this unit reaches". That is the file being compiled.
- **Port sites:** none left; `src/doom/hud.nuc` keeps its level-name tables at the end of the file
- **Workaround:** none needed after the fix. Before it, define the table above its first use, or annotate it (`NAMES:(array StrView 2)`).
- **Suggestion:** done. The value-name prescan registered a stored constant only when its type was known early: an annotation or a struct literal's head. A bare `(array T …)` now registers too, sized from its initializers as emission sizes it. The note's wording should also exclude the current file, since "no import reaches" can't be true of it.

Context: `docs/toplevel.md` says "Order does not matter. A constant may be used
above its definition, in the same file", and that held for every scalar
constant the port had used. Generated data tables are naturally appended at
the end of a module, which is where this came up. This is the same prescan
gap that makes ISSUE-024's computed constants fail across a cycle.

---

## ISSUE-032: Two namespaces with a `defn-` returning `!void` fail with an LLVM "redefinition of type"

- **Severity:** major
- **Kind:** bug
- **Status:** fixed in nucleus `5d3cfe8`
- **Probe:** `probes/issue-032.nuc` (with `probes/issue-032/a.nuc` and `b.nuc`). Expected `a.num 3` then `b.num 6`. Actual: the macro JIT module fails with "redefinition of type %nuc_Result.void.Err".
- **Port sites:** none left; `src/doom/intermission.nuc` and `src/doom/status.nuc` both have private `draw-num` and `draw-percent`
- **Workaround:** none needed after the fix. Before it, renaming one namespace's private functions avoided the trigger.
- **Suggestion:** done. A template instance (`!void` is `(Result void Error)`) was registered while `g-defining-private` was still set by the enclosing `defn-`, so the instance became private to that namespace. Another namespace's lookup missed it and stamped a second copy under the same IR name. Registration now clears the flag, since an instance belongs to every namespace.

Context: this showed up as a bare LLVM error with no Nucleus source line, and
only once the intermission and the status bar both existed. The error was
also hard to bisect: it came from the macro JIT module, not the program.
Investigating it uncovered ISSUE-033.

---

## ISSUE-033: `try` on an overloaded call whose argument is a macro call picks the wrong arm shape

- **Severity:** major
- **Kind:** bug
- **Status:** fixed in nucleus `5f2bfae`
- **Probe:** `probes/issue-033.nuc`. Expected `f 4`. Actual: "match: arm 'ok' binder count does not match its field count".
- **Port sites:** none left; `src/doom/intermission.nuc`'s `(try (draw-percent (- SCREEN-WIDTH STATS-X) …))`
- **Workaround:** none needed after the fix. Before it, bind the macro-call argument with `let` first, or give the function a unique name.
- **Suggestion:** done. `try` chose between `(ok)` and `(ok v)` from `node-type` of its operand. `node-type` returns null for a macro call (`-` is a macro), and an overloaded or mangled callee can be resolved only from its argument types, so the operand came back untyped. `try` then assumed one binder, which is wrong for `!void`. When the operand is untyped, `try` now emits it first and reads the arm shape off the value. The same change gives ISSUE-029 its message.

Context: an arithmetic argument in a fallible draw call is ordinary code. The
error named a `match` the user never wrote, and named neither `try` nor the
callee. The private `defn-` pair in ISSUE-032 is what made the callee
mangled, so the two bugs surfaced together.

---

## ISSUE-034: A char literal is "not a compile-time constant" inside a global aggregate

- **Severity:** minor
- **Kind:** bug
- **Status:** fixed in nucleus `4d7ea58`
- **Probe:** `probes/issue-034.nuc`. Expected `110 98`. Actual: "defvar: init must be a compile-time constant (a literal, a named constant, or an expression over them)".
- **Port sites:** none left; `src/doom/menu.nuc`'s item table gives each item's hotkey as `\n`, `\o` and so on
- **Workaround:** none needed after the fix. Before it, `(char "n")` was folded, and so was an `i32` field holding the code.
- **Suggestion:** done. The global-initializer renderer had no case for a char-literal node. A scalar `Char` global hid the gap because it falls back to a run-time initializer, but an aggregate element has no such fallback.

Context: `docs/builtins.md` lists "character" among the literals a constant may
be, and calls `(char "x")` sugar for `\x`. The menu table is the natural
place for one: each item's hotkey, as in the C's `menuitem_t`.

---

## ISSUE-035: No scalar `min`, `max` or `abs` in the stdlib

- **Severity:** papercut
- **Kind:** stdlib gap
- **Status:** worked-around
- **Probe:** none; nothing is broken.
- **Port sites:** `src/doom/math.nuc` (`imin`, `imax`, `iabs`), used by `src/doom/menu.nuc` and `src/doom/finale.nuc`; `src/doom/sys/sound.nuc` (`imid`, a clamp)
- **Workaround:** one-line `if` helpers per type.
- **Suggestion:** generic `min`/`max`/`abs`/`clamp` over the numeric types in a prelude module. `nucleus.combinators` already has an iterator `min`, so a two-argument scalar overload would sit beside it.

Context: `(min a b)` is the first thing a C programmer reaches for when clamping
a length or an index. The error ("unknown: min") is clear, but the port had
already hand-written `iabs` in milestone 1 for the same reason.

---

## ISSUE-036: `Vector` and `HashMap` have no `clear`, though `String` has `string-clear`

- **Severity:** papercut
- **Kind:** stdlib gap
- **Status:** worked-around
- **Probe:** none; nothing is broken.
- **Port sites:** `src/doom/sys/music.nuc` (`play-song` reuses one MIDI
  buffer); `src/doom/savegame.nuc` and `src/doom/savecodec.nuc` (the save
  stream and object table, reset per save); `src/tests/savegame.nuc`
- **Workaround:** `(set! (v 'len) 0)`, writing the struct's length field
  directly. For a `HashMap`, `(drop &m)` then `(set! m (make (HashMap K V)))`,
  which frees and reallocates the table on every save.
- **Suggestion:** `(clear v)` (and probably `truncate`) on `(Vector T)`, and
  `clear` on `HashMap`, dropping the elements and keeping the capacity. `string-clear` is already
  `(set! ((ref self 'bytes) 'len) 0)`, so the Vector version is the same line
  plus a drop loop for elements that own memory.

Context: the music player converts each song into the same buffer. The first
guess, `(set! (midi 'count) 0)`, fails with "no field 'count'". `count` is a
function and the field is `len`. The workaround depends on the layout, and for
an element type with a `Drop` it would leak.

---

## ISSUE-037: `as` calls an exact `i32` → `f64` conversion "lossy"

- **Severity:** papercut
- **Kind:** design gap
- **Status:** worked-around
- **Probe:** none; this is the documented rule (`docs/types.md`, "Implicit Type
  Coercion": `float`↔`int` is `unsafe/cast` only).
- **Port sites:** `src/doom/sys/sound.nuc` (the resampler's low-pass filter, 4 casts)
- **Workaround:** `(unsafe/cast f64 n)` for every integer operand.
- **Suggestion:** let `as` (and the implicit coercions) accept integer → float
  conversions that are exact for every value of the source type: `i8`/`i16`/`i32`
  and their unsigned forms into `f64`, and 8- and 16-bit integers into `f32`.
  Keep `unsafe/cast` for `i64` → `f64`, which can round, and for float → int.
  At minimum, the error should not say "lossy" about a conversion that loses
  nothing.

Context: `(as f64 mixer-freq)` reports "as: lossy conversion from i32 to f64 --
use unsafe/cast". Every `f64` holds every `i32` exactly. So the only spelling
left for a safe conversion is the one the language reserves for unsafe ones,
and an `unsafe/` search over the port now finds four harmless casts. The
playsim never uses floats, so the rule costs nothing there. It shows up as
soon as code touches audio or other host-side arithmetic.

---

## ISSUE-038: A template method first stamped inside a `defn-`, in a file with no `ns`, gets no definition

- **Severity:** major
- **Kind:** bug
- **Status:** fixed in nucleus 1862c27
- **Probe:** `probes/issue-038.nuc`. Expected `count 1`. Actual: "nucleusc:
  failed to parse generated IR …: use of undefined value
  '@nuc_count.pnuc_Vector.u8'".
- **Port sites:** none. Every port file has an `ns`. It was found while
  prototyping the savegame macro in a scratch file.
- **Workaround:** make the function public, or give the file an `ns`.
- **Suggestion:** done. The stamp is registered with `g-defining-private`
  cleared, as ISSUE-032's fix does for union instances. The remaining
  question is whether anything else registers under the private key while a
  `defn-` body is being compiled. Both bugs came from that one global, which
  stays set for everything the body causes to be compiled.

Context: `(defn- size (v:&(Vector ui8)):i32 (unsafe/cast i32 (count v)))` was
the first use of `count` on `(Vector ui8)`. The call was emitted against the
mangled `@nuc_count.pnuc_Vector.u8` and the definition as `@nuc_count`. The
error points at generated IR, so a user learns nothing from it about which
form caused it. Making the same function a `defn` hides it.

---

## ISSUE-039: With `nucleus.error` loaded only by `import-ct`, every `err` calls an undefined function

- **Severity:** major
- **Kind:** bug
- **Status:** fixed in nucleus 95b70b9
- **Probe:** `probes/issue-039.nuc`. Expected `ok 1`. Actual: "nucleusc:
  failed to parse generated IR …: use of undefined value
  '@nuc_err-find-handler'".
- **Port sites:** none yet. It is hit by the savegame macro, whose
  `import-ct nucleus.node` brings in `nucleus.error` at compile time.
- **Workaround:** `(import-use nucleus.error)` as well.
- **Suggestion:** done. The `err` emitter asked whether the error library's
  names were registered, and `import-ct` registers names it never defines.
  It now also asks whether they are compile-time only. The compiler had
  already added that check for the node runtime, so the rule ("a `ct-only`
  binding is absent from the program") belongs wherever the emitter probes
  for a library by name.

Context: a macro file needs `(import-ct nucleus.node)` to build forms, and
`nucleus.node` imports `nucleus.error`. Any `!T` function that returns
`(err …)` in the same program then fails at the IR stage. The error names
neither the import nor the `err`.

---

## ISSUE-040: An array field of a struct binding decays into a copy, so stores through it vanish

- **Severity:** critical (silent wrong code)
- **Kind:** bug
- **Status:** fixed in nucleus 712308d
- **Probe:** `probes/issue-040.nuc`. Expected `1 9`. Actual: `0 0`.
- **Port sites:** none found. The port's array fields are written through
  `&T` receivers (`(p 'powers)` on a `&Player`), which were always right. It
  was found when the savegame prototype round-tripped a local struct.
- **Workaround:** write through a pointer: `(set! (aref (&t 'flags) 0) 1)`.
- **Suggestion:** done. Field reads now use the binding's own slot, and only
  a true temporary is copied. The deeper problem is that the copy was
  invisible. `docs/types.md` says reading an array field is "the address of
  element 0 … nothing is loaded and nothing is copied", and the copy broke
  that promise without a diagnostic. A test that the decayed pointer of a
  local's field equals the field's address would have caught it.

Context: `(let (t:Thing (Thing)) (set! (aref (t 'flags) 0) 1) …)` stored into
a `%tc3.mat` temporary that SV-1 had made so a by-value struct could be a
field-access receiver. Every later read made a fresh copy of the unchanged
binding. The fix moved the compiler's own bootstrap (93,924 IR lines, all of
them a copy fewer per field read), so it needed the converge cycle.

---

## ISSUE-041: A `defvar` defined by two `import-use`d namespaces silently resolves to the first import's

- **Severity:** major (silent wrong binding)
- **Kind:** bug
- **Status:** open
- **Probe:** `probes/issue-041.nuc` (with `probes/issue-041/a.nuc` and `b.nuc`).
  Expected: an error naming `issue-041.a/nodes` and `issue-041.b/nodes`.
  Actual: it compiles and prints `1`. Swap the two imports and it prints `2`.
- **Port sites:** `src/doom/savecodec.nuc` (the stream and object-table globals
  are `save-*`, not the shorter `nodes`/`in`/`out`, since `doom.world` already
  has a `nodes`).
- **Workaround:** give every public global a name no other flattened
  namespace uses, or spell it qualified.
- **Suggestion:** do what `design/stage15-stress-test/name-resolution.md` §8.2
  recommends. Its table already lists `defvar`/`defconst`/enum members as kinds
  where "the same name from two flattened namespaces" is a collision, reported
  lazily at the first bare use. Functions get that diagnostic ("defined in
  namespaces 'a' and 'b' … write 'a/f' or 'b/f' here"), but only for an
  unresolved call. A value lookup returns the first candidate key it finds, so
  import order picks the binding. `docs/toplevel.md` says import order doesn't
  affect resolution, and here it does.

Context: `doom.savecodec` first named its node table `nodes`. `doom.savegame`
imports both `doom.world` (whose `nodes` is the BSP node table) and
`doom.savecodec`, and its bare `nodes` meant the BSP table. That surfaced as a
type error only because the two element types differed. Two `i32` counters with
the same name would have compiled and read the wrong variable.

---

## ISSUE-042: A function name used as a value is "undefined" once another namespace defines the same name

- **Severity:** major
- **Kind:** bug
- **Status:** fixed in nucleus cab687d
- **Probe:** `probes/issue-042.nuc` (with `probes/issue-042/lib.nuc` and `m.nuc`).
  Expected `run 1`. Actual: "undefined: pick — defined in namespace
  'issue-042.lib', which this file does not import", reported at `m.nuc`'s
  own use of its own `pick`.
- **Port sites:** none now. It blocked the unit-test program, whose
  `nucleus.test` import puts a public `check-line` in the unit beside
  `doom.play.map`'s private one, which `check-position` passes to
  `block-lines-iterator`.
- **Workaround:** wrap the function in a lambda, `(fn (ld:&Line):bool (check-line ld))`.
- **Suggestion:** done. A value reference that finds no binding now asks the
  generic, through the same visibility filter a bare call uses. If exactly one
  method is reachable, that method is the value; if several are, the error
  says the name is overloaded rather than undefined. The root cause is that
  the "solitary" `g-globals` binding a value reference needs is decided per
  unit, while overloading is decided per namespace. Any library that added a
  public function could break unrelated code taking a same-named function as
  a value.

Context: the game built and the test program didn't. The two differ only in
which libraries are in the unit, so it first looked like an import-order
problem, and the first message blamed an import cycle (`play.map` ↔
`play.spec`).

---

## ISSUE-043: `(ok)` as a statement is "unknown: ok — not defined anywhere"

- **Severity:** papercut
- **Kind:** diagnostics
- **Status:** open
- **Probe:** `probes/issue-043.nuc`. `(defn f ():!void (ok) (ok))` reports
  "unknown: ok — not defined anywhere in this compilation unit", with
  `nucleus.error` imported.
- **Port sites:** `src/tests/savegame.nuc` (match arms that succeed are
  `(do)`, because `deftest` appends its own `(return (ok))`).
- **Workaround:** write `(ok)` only in tail or `return` position. In a
  `deftest` body, don't write it at all.
- **Suggestion:** a non-tail `(ok)` has no expected type to construct. Either
  take it from the enclosing function's result type (the value is discarded,
  so accepting it costs nothing), or say that `ok` needs a result type there.
  The current message sends the reader looking for a missing import.
  `docs/testing.md` could also say that `deftest` supplies the `(ok)`.

Context: hit twice in one test file. The first time, an `(ok)` closed a
`deftest` body, the way a `defn` test helper ends. The second time it was a
match arm that was out of tail position for the same reason.

---

## ISSUE-044: `nucleus build` reports a syntax error in an imported file at the importer's path

- **Severity:** minor
- **Kind:** bug
- **Status:** fixed in nucleus 6518d10
- **Probe:** `probes/issue-044.nuc` (run with `--list-imports`). Expected
  `issue-044/lib.nuc:3: error: unexpected )`. Actual: `issue-044.nuc:3`, the
  importer's path with the imported file's line.
- **Port sites:** none.
- **Workaround:** compile the entry with `nucleusc` directly, which names
  the right file.
- **Suggestion:** done. `--list-imports` set the current file after reading
  it rather than before. The general hazard is that `g-source-path` is
  ambient state that every reader error consults. A reader that took the path
  as an argument couldn't get it wrong.

Context: an extra `)` in `doom/config.nuc` came back as `main.nuc:161:
error: unexpected )`. Line 161 of `main.nuc` was a balanced `(when …)`, and
the note ("the form opened at line 143 is already closed") described forms
that don't exist there.

---

## ISSUE-045: `derive-edn` reads a struct only if every field is present

- **Severity:** minor
- **Kind:** known-limitation
- **Status:** worked-around
- **Probe:** none; `docs/edn.md` "Not yet" lists "default values", and
  missing keys are `edn-missing-key` by design.
- **Port sites:** `src/doom/config.nuc` (every setting and binding is read by
  hand with `edn-get`)
- **Workaround:** one `edn-get` per key, falling back to the variable's
  current value, driven by two `each-setting`/`each-key` macros that list
  each name and variable once, for reading and writing both.
- **Suggestion:** a field default in `derive-edn`, say `:edn-default` per field
  or a whole-struct "absent keys keep the destination's value" mode. A config
  file is the textbook EDN use, and it always meets an older file that lacks
  a newer key. A strict codec makes the first new setting a breaking change
  for every saved config.

Context: PROMPT asks for an EDN config through `nucleus.edn`. A `Config`
struct with `derive-edn` would have been about five lines. It wasn't usable,
because a file written before a setting existed would fail to load at all.
The by-hand reader and writer are about 75 lines, and they also give key bindings by name
(`"ctrl"`, `"f5"`, `"space"`), which a struct of `i32`s wouldn't.

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
- **A union for thinkers.** The C keeps each thinker's behavior as a function
  pointer in a struct that every thinker type embeds, and finds mobjs by
  comparing that pointer with `P_MobjThinker`. The port's `Thinker` union has
  one arm per kind. One `match` in `doom.play.tick` runs them, and
  `thinker-mobj` is a `match` too. A ninth kind of thinker would be a compile
  error at each `match`, not a silent no-op.
- **`case` with `(:or …)`** maps the C's fall-through `switch` groups (line
  specials, pickups, state actions) row for row without the `break`s.
- **Signedness errors earned their keep.** About a dozen "mixed
  signed/unsigned operands" refusals in the playsim each forced a decision the
  C makes implicitly: angle arithmetic wraps, turn offsets are signed, button
  bits are bytes. Once the M4 modules compiled, all three demos stayed in sync
  for every tic on the first run.
- **A union for sound origins.** `S_StartSound` takes a `void *` that is a
  `mobj_t *`, a sector's `degenmobj_t`, NULL, or (through a vanilla bug) a
  pointer into a button record. The port's `Origin` union names all four.
  Where the C's pointer comparison has to be reproduced (`S_StopSound`,
  `S_GetChannel`), `same-origin?` spells out each case, including the one
  that never matches.
- **SDL_mixer imported without a binding.** `Mix_*` functions, `AUDIO_S16SYS`
  (defined under `#if` on byte order) and `SDL_RWFromConstMem` all came
  straight from `(import-use "SDL2/SDL_mixer.h")`. Only `Mix_PlayChannel`, a
  function-like macro, needed the underlying `Mix_PlayChannelTimed`
  (ISSUE-002). `mus2mid` ported from a byte-reading `!i32` reader and matched
  Chocolate Doom's output byte for byte on all twelve shareware songs the first
  time it compiled.
