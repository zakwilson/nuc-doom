# Nucleus cheat-sheet (porter's working notes)

Distilled from `nucleus/docs` while porting. Not authoritative; the docs are.

## Types / syntax
- `(defn name (a:i32 b:&T):ret body)`; return type after param list. `:optional`, `:rest`.
- Pointers: `&T` non-null, `?&T` nullable (narrow via `(when p ...)`, `if-some`), `ptr:T` unchecked, bare `ptr` = void*.
  Narrowing works on locals and globals (global only to end of fn). Loops drop narrows for vars assigned in body.
- Value position `x:T` = `(as T x)`. `as` = safe widen only; `unsafe/cast` for narrowing/int<->float/ptr<->int.
- Implicit coercion at let/set!/return/call: int narrowing **truncates silently** for values (literal must fit).
  Binops: literal adapts; two typed ints widen; **mixed signed/unsigned is an error**; bool not an int.
- `deftype` alias (not a newtype!). Parametric alias `(deftype (Vec T) (ref (Vector T)))`.
- `(array T N)` storage only (defvar/field/alloca/sizeof); decays to `&T`; no nested arrays; no array let bindings.
- Integer literals: decimal/hex only, no octal. String literal is `StrView`; coerces to CStr free. `c"..."` CStr.
- Char literal `\a`. Keyword `:foo` needs nucleus.keyword.
- fn ptr type: `f:(fn i32)(i32 i32)` (adjacent groups). defn name in value pos decays to fn ptr. Nullable.
- `defconst` literal (no storage, adapts) or aggregate (rodata; `(array T ...)`, `(S ...)`). `&TABLE` hole: writable.
- `defenum Name a b c` -> i32 constants 0.. ; members adapt like literals.
- defvar init: const tiers (literal, const expr incl. sizeof/as/bit-*, &g, aggregates) or run-time init (before main,
  ordered by reach). `(array T N)` defvar can't take run-time init.
- Private: `defn-` etc. In file without ns: file-private. With `(ns x)`: namespace-private.
- Names resolve unit-wide order-free (reachability). Macros must be defined/imported ABOVE use.
- `import-use lib` flattens; `(import lib p)` -> `p/name`; prefixes are file-scoped. A file must import libs it uses.
- One definition per name per unit; overloads are per (name, param types).
- Bare `"x"` literal → `StrView`.
