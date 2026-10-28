# Port DOOM to Nucleus — a language stress test

## 1. Mission

Port the open-source classic game DOOM (Chocolate Doom, `/home/zak/code/chocolate-doom`)
to the Nucleus programming language (`/home/zak/code/nucleus`).

**Producing a port is the secondary goal. The primary goal is to stress-test the
language: find missing or poorly designed features, and record them in `ISSUES.md`.**
A finished port with a thin `ISSUES.md` is a failed run. A partial port with a
precise, well-evidenced `ISSUES.md` is a useful one. When the two goals compete
for your time, the report wins.

Use Nucleus features to make the code shorter, easier to understand, or more
reliable than the original C, including but not limited to:

* Macros, including `macrolet` and `macmap`
* Generics (multimethods, bounded generic `defn`, parametric structs)
* Protocols (including `(dyn P)` where runtime dispatch is genuinely needed)
* Compile-time evaluation
* Non-nullable refs (`&T`) and narrowed nullables (`?&T`)
* Error handling (`!T`, `deferror`, `try`, `match`)
* `Const` data literals (`[…]`, `{…}`, `#{…}`)
* The Nucleus standard library (collections, `String`/`StrView`, allocators, `fmt`, EDN, file I/O, test framework)

Replace programming techniques that made sense in 1993 with modern ones; nobody
runs this on a 386 without an FPU. You may fix bugs from the original or improve
performance, but you don't have to.

Replicating the original perfectly is not a goal, and neither is improving its
performance or gameplay. The goal is **a playable DOOM port in idiomatic
Nucleus, plus a report on the language issues that made it hard to write**.

This is not a transliteration exercise. The previous Nucleus Doom port (Stage 15;
see `/home/zak/code/nucleus/design/stage15-stress-test/`) was a close, bit-exact
transliteration, and its findings are already fixed. This port is meant to find
what goes wrong when someone writes Nucleus *the way the language intends*. If a
module ends up reading like C with parentheses, that is either a finding (the
idiomatic version was impossible or worse; say why) or a defect in the port.

## 2. Inputs and locations

| What | Where |
|---|---|
| This project (the port) | `/home/zak/code/nuc-doom` |
| Chocolate Doom source, read-only | `/home/zak/code/chocolate-doom` (`src/doom/` = game, `src/*.c` = platform/shared) |
| Reference engine binary (built) | `/home/zak/code/chocolate-doom/src/chocolate-doom` |
| Shareware IWAD (v1.9, sha1 `d4dc6806…`) | `/home/zak/code/chocolate-doom/src/DOOM1.WAD` |
| Nucleus source (you may fix bugs on branch `doom-bugfixes`) | `/home/zak/code/nucleus` |
| Nucleus compiler and build tool | `$NUCLEUS_HOME/build/nucleusc` and `$NUCLEUS_HOME/build/nucleus`, after `. scripts/env.sh` |
| Nucleus language docs | `/home/zak/code/nucleus/docs/` (start at `index.md`) |
| Nucleus design history and known gaps | `/home/zak/code/nucleus/design/` (`progress.md`, `deferred/`, `future/`, `long-term-issues.md`) |
| Nucleus stdlib source | `/home/zak/code/nucleus/lib/nucleus/` |

`CLAUDE.md` has the environment setup (LLVM shim, headless SDL, build commands).
Read it first.

## 3. Ground rules

1. **Never modify `/home/zak/code/chocolate-doom`.** To instrument the reference
   engine, work in a copy (see §6).
2. **You may fix bugs in Nucleus** (see §7, "Fixing the compiler"). Everything
   else, including missing features and design problems, is recorded and worked
   around, not changed. **Never run `make` in `/home/zak/code/nucleus` itself.**
   Its binaries are host-built, and `make` would relink them against the
   container's LLVM 19. Build and test only through `scripts/build-compiler.sh`.
3. **Never discard work with git** (`git restore`, `git checkout <file>`,
   `git reset --hard`, `git clean`), in either repo. If the build breaks, fix
   the source.
4. **License.** The port is a derivative of GPLv2 code. Keep the license
   (`COPYING`, copied from Chocolate Doom's `COPYING.md`) and keep the upstream
   copyright notices in a short header on each ported file.
5. **Commit** to this repo at each milestone whose gates are green, with a message
   that names the milestone and the new ISSUE ids. Work on `main`.
6. **No subagents and no workflows.** Do all the work in the main thread. The
   harness resumes the main thread automatically when it hits a session limit,
   but a subagent that hits the limit is lost.
7. **The port must also build on the host,** which has a newer LLVM. Nothing in
   `build.edn` or the scripts may hardcode container paths. Every script gets its
   compiler from `scripts/env.sh`.

## 4. Required reading before writing port code

Read these Nucleus docs in full: `index.md`, `types.md`, `toplevel.md`,
`special-forms.md`, `structs-unions.md`, `generics.md`, `macros.md`,
`errors.md`, `collections.md`, `allocators.md`, `strings.md`, `iterators.md`,
`build.md` (Commands, `build.edn`, Choosing C packages), and `testing.md`.
Skim `builtins.md`, `stdlib.md`, `io.md`, `edn.md` and `compiler.md`, and come
back to them as needed. Then read `examples/` for idiom: the examples are the
closest thing to a style guide.

Before you report a limitation, check whether it is already documented (look for
"Sharp edge", "Limits" and "not supported" in `docs/`, and in `design/deferred/`
and `design/future/`). A documented limitation that still hurts the port **is
still a finding**: record it with `Kind: known-limitation` and say what it cost.
But never present it as a newly discovered bug.

## 5. Scope

**In scope (core):** WAD loading (IWAD + PWADs via `-file`), fixed-point math and
tables, the info/state tables, the software renderer, the playsim (movement,
collision, monsters, weapons, specials, sector movers), the game loop and tic
timing, demo playback and recording, menus, HUD messages, status bar, automap,
intermission, finale, screen wipe, cheats, SDL2 video (scaled 320×200 with
aspect correction) and keyboard and mouse input.

**In scope (optional; do after core is playable):**
- Sound effects through SDL2 / SDL2_mixer.
- Music: MUS→MIDI conversion (port `mus2mid.c`), played through SDL2_mixer. Do
  **not** port the OPL emulator.
- Savegames and configuration. Neither has to be vanilla-compatible: use your
  own format (EDN through `nucleus.edn` is the natural choice for config).
- Game modes beyond shareware (registered, Doom II, Final Doom, Freedoom IWADs).
  The code paths should exist, but `DOOM1.WAD` is the only IWAD available for
  testing.

**Out of scope:** Heretic, Hexen and Strife; networking and netgames (keep
`ticcmd_t` and the single-player tic loop, and drop `net_*`, `d_loop`'s net
parts and `d_dedicated`); the setup tool and textscreen; DeHackEd/BEX; OPL, PC
speaker and GUS; the joystick; ENDOOM; high-res video modes; Windows/macOS
specifics; vanilla limit and overflow emulation (spechit, intercepts, donut,
visplane limits), unless a test demo needs one to stay in sync.

## 6. Verification

There is no display in this environment, so every check must run headless
(`SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy`). The user will play-test on the
host.

### 6.1 Fidelity contract

- **The playsim must be deterministic and stay in demo sync with Chocolate Doom.**
  That means the same `P_Random`/`M_Random` table and indices, the same fixed-point
  semantics (`FixedMul`/`FixedDiv` with 64-bit intermediates and FixedDiv's
  overflow clamp), the same trig tables, 32-bit wrapping angle arithmetic, the
  same thinker iteration order and the same blockmap traversal order. Write all of
  that in idiomatic Nucleus, but don't change the arithmetic. Floats are
  **forbidden** in the playsim. If this contract becomes a bottleneck (it forces
  unidiomatic code, or a language feature can't express fixed-point cleanly),
  record that in `ISSUES.md` and keep the contract.
- **Generated tables must equal the originals.** If you compute `finesine`,
  `finetangent`, `tantoangle`, `gammatable` and the like at compile time (which is
  encouraged), add a test proving element-wise equality with `tables.c`. If they
  can't be made equal, embed them and record why.
- **Outside the playsim** (the renderer, menus, HUD, platform layer, sound) you may
  modernize freely, floats included. Frame-exact output is a diagnostic tool, not a
  requirement.

### 6.2 The reference harness (build this first)

1. Copy Chocolate Doom into `reference/build/` (gitignored), apply a patch that
   you keep in `reference/tichash.patch`, and build it there. The patch adds:
   - `-tichash <file>`: after each gametic, write one line containing the gametic
     number, `rndindex`, `prndindex`, and a hash over every mobj's `x y z angle
     momx momy momz health type state-index flags` (in thinker order), plus each
     player's `health armorpoints readyweapon` and the counts of kills, items and
     secrets.
   - `-framedump <tic,tic,…> <dir>`: write the 320×200 indexed framebuffer plus
     the palette as a PPM file at the listed tics.
2. Record the reference output for `demo1`, `demo2` and `demo3` in
   `reference/data/` and commit it (it is small text). Under `-timedemo` the
   reference plays 5658, 13980 and 13605 gametics respectively. That count is
   necessary but **not** sufficient, since a desynced demo still runs to its end.
3. Implement the same two flags in the port, with byte-identical output formats.
4. `scripts/check-demos.sh` runs the port on all three demos and diffs the tic
   hashes against the reference. It reports the **first** divergent tic and the
   fields that differ, and exits non-zero on any mismatch. This is the main
   regression gate from the first-playable milestone onward.

### 6.3 Tests

Use the Nucleus test framework (`nucleus.test`, `docs/testing.md`) for unit
tests: fixed-point math, table equality, WAD directory parsing, the MUS→MIDI
converter, config round-tripping and similar. Keep them in a test program built
alongside the game.

## 7. Recording findings — `ISSUES.md`

### What counts

Any place where the language, its standard library, its tooling, its diagnostics
or its docs made the port harder, longer, less clear or less safe than it should
be. Concretely:

- compiler bugs: crashes, miscompiles, wrong or misleading diagnostics, rejected
  valid code, accepted invalid code;
- missing features, where you had to fall back to a less idiomatic or more
  verbose form;
- design problems: features that exist but compose badly, surprise you, or push
  you toward C idioms;
- stdlib gaps (anything you had to write that belongs in `nucleus.*`);
- C interop friction (SDL2 headers, macros, varargs, unions, callbacks);
- build-tool and workflow friction, slow compiles, and poor error locality in a
  large program;
- docs that are wrong, missing, or contradicted by the compiler.

**Notice friction actively.** After finishing each module, compare it with the C
original and ask: where is the Nucleus version longer, harder to read, or less
safe than C, and why? Where did you reach for `ptr`, a cast or a manual loop
because the idiomatic tool didn't fit? Each answer is a candidate finding.

### Format

`ISSUES.md` starts with a summary table ranked by **porter pain removed per unit
of language work**. Below the table, each issue looks like this:

```markdown
## ISSUE-007: <one-line claim, not a topic>

- **Severity:** blocker | major | minor | papercut
- **Kind:** bug | missing-feature | design | diagnostics | stdlib | interop | tooling | docs | known-limitation
- **Status:** open | worked-around | fixed in nucleus `<sha>`
- **Probe:** `probes/issue-007.nuc` — expected …, actual … (exact compiler output)
- **Port sites:** `src/play/map.nuc:212`, … (N sites in total)
- **Workaround:** what the port does instead, and what it costs
- **Suggestion:** what the language could do (optional, brief)

Context: one or two short paragraphs, with the idiomatic code you wanted to write
next to the code you had to write.
```

Severity: **blocker** means no workaround was possible, so a feature was dropped
or a module couldn't be written. **Major** means the workaround costs
significant code, safety or clarity, or recurs widely. **Minor** is a local
annoyance. A **papercut** is cosmetic or a diagnostics wording issue.

Rules:
- **Every bug-kind issue needs a minimal standalone probe** in `probes/` that
  compiles (or fails to) with `$NUCLEUS_HOME/build/nucleusc` alone, with a header comment
  giving the issue id and the expected behaviour. `scripts/check-probes.sh`
  reruns every probe and reports which issues still reproduce, so the language
  maintainers can rerun it after fixing the compiler.
- **Tag every workaround site** in the port with `; ISSUE-007` so that it can be
  removed once the issue is fixed.
- **Log a finding when you hit it**, not at the end. A module isn't done until
  its findings are in `ISSUES.md`.
- Merge duplicates, and update a finding's site count and severity as evidence
  accumulates.
- Keep a short **"What worked well"** section at the end, listing features that
  clearly beat the C. That is signal too.

### Fixing the compiler

You may fix **bugs**: crashes, miscompiles, rejected valid code, accepted invalid
code, wrong diagnostics, and docs that contradict the compiler. Missing features,
design problems and stdlib gaps are recorded only, because they are the
language designer's decisions. A bug whose fix needs a design decision counts as
a design problem.

- **When to fix.** Fix a bug when it blocks the port, or when its workaround is
  costly or recurs widely. Otherwise record it, work around it, and move on.
  Don't let compiler work crowd out the port. The port is how findings are made.
- **Where.** Work in `/home/zak/code/nucleus` on the branch `doom-bugfixes`,
  which is already checked out. Never commit to `main` there. Before your first
  change, read that repo's `CLAUDE.md` and `context/conventions.md`, and follow
  its rules (tests, bootstrap, docs, `design/progress.md`, context files,
  comment budget). Its "use subagents" guidance does not apply here (rule 6).
- **How.** The order is probe first, then the fix, then the gates:
  1. Write the probe (§7 rules) and record the issue.
  2. Make the fix in the real tree.
  3. Run `scripts/build-compiler.sh` and then `scripts/build-compiler.sh -k test bootstrap`.
     These sync the tree into `.toolchain/nucleus` and build and test it there
     against the LLVM shim. The suite takes several minutes, so run it in the
     background. Five `suite-target` datalayout tests fail in this container
     whatever you change. Compare against that baseline, not against zero.
  4. Add a regression test in the Nucleus suite.
  5. Make one commit per fix on `doom-bugfixes`, naming the ISSUE id.
- **Afterwards.** Set the issue's status to `fixed in nucleus <sha>` (the finding
  stays in `ISSUES.md`), confirm that `check-probes.sh` reports the probe as
  fixed, and remove the port's `; ISSUE-NNN` workarounds.

## 8. Design guidance — modernize these

These are suggestions, not mandates. If one turns out worse in Nucleus than in
C, that is a finding.

| C original | Modern Nucleus direction |
|---|---|
| `info.c`: about 4,600 lines of state and mobjinfo tables, `enum` lists kept in lockstep by hand | `Const` literals; generate the enums and tables from one `macmap` row set, so the names and data can't drift apart |
| `tables.c`: trig tables written out as literals | Compile-time evaluation, checked for equality (§6.1) |
| `m_fixed.c`, `fixed_t` as a bare `int` | A distinct fixed-point type whose operators are defined through multimethods or protocols, so a fixed can't be mixed with an int by accident |
| `z_zone.c` with purge tags `PU_STATIC`, `PU_LEVEL`, `PU_CACHE` | Nucleus allocators: a level `Arena` dropped on level change, the heap for static data, and a lump cache in a `HashMap` |
| The `thinker_t` "base class" as the first struct member, a function pointer, casts, and the `-1` removal sentinel | `defunion`+`match`, protocols, or `dyn`. Keep the iteration order and the deferred-removal semantics exact |
| `mobj_t *target`, `tracer` and friends: nullable everywhere | `?&T` where absence is meaningful, `&T` in parameters, narrowing through `match` |
| `I_Error` and exit/longjmp | `!T` and `try`, propagated to `main`. Fatal errors happen only at the top |
| `W_CheckNumForName` with linear scans and 8-char names | A name→lump `HashMap` and `StrView` keys; lump reads return `!T` |
| `dstrings.c`, `d_englsh.h` and `#define` strings | `Const` data, `String` and `fmt` |
| Menus: parallel arrays of `menuitem_t` with function pointers | `Const` literals of structs holding closures or functions |
| `m_cheat.c` | A table of sequences and actions |
| `m_config.c` with `default.cfg` | EDN config read and written through `nucleus.edn`; key bindings by name |
| `doomtype.h`, `boolean`, `SHORT()`/`LONG()` byte swapping | `bool`; explicit little-endian reads from the WAD byte stream |
| `p_saveg.c`, which writes raw struct images | A savegame format driven by `struct-fields` macros, versioned |
| `d_loop.c`/`d_net.c` | A plain single-player 35 Hz tic loop over `ticcmd` |
| `i_video.c`: palettized buffer, multiple scaling paths | A 320×200 8-bit buffer, a palette→ARGB conversion and an SDL texture, with `SDL_RenderSetLogicalSize` and 4:3 aspect correction |

Organize the code by subsystem under Nucleus namespaces (for example `doom.wad`,
`doom.math`, `doom.info`, `doom.render.*`, `doom.play.*`, `doom.game`,
`doom.ui.*`, `doom.sound`, `doom.sys`) rather than mirroring the C file names
one to one. Use the build tool (`build.edn`), not hand-written compiler command
lines. Use Nucleus naming (kebab-case functions, CamelCase types). Follow the
Nucleus repo's comment style: comments say *why*, in one or two lines.

## 9. Milestones

Do these in order. Each one ends with green gates, any new findings logged, an
update to `PROGRESS.md`, and a commit.

0. **Setup.** Read the required docs (§4). Write `build.edn`, `COPYING`, the
   `ISSUES.md` skeleton, `probes/`, `scripts/check-probes.sh` and a "hello SDL"
   window that runs headless. Build the reference harness (§6.2) and record
   the demo data.
1. **Foundations.** Fixed-point math, the tables, `m_random`, the WAD reader,
   `info` (states, mobjinfo, sprites, sounds), `doomdata`/`doomdef` types and
   argv handling. *Gate:* unit tests, including table equality.
2. **Static graphics.** Palette, patches, `v_video`, the SDL presentation layer,
   and `-framedump`. *Gate:* the title screen (`TITLEPIC`) framedump matches the
   reference.
3. **Level load and 3D view.** `p_setup` (geometry, blockmap, reject), `r_data`
   (textures, flats, colormaps) and the full renderer. *Gate:* a static E1M1
   view from the player start matches the reference framedump, or any
   differences are explained.
4. **Playsim and demo playback.** All the `p_*` modules, `g_game`'s demo and tic
   loop, `-playdemo`/`-timedemo` and `-tichash`. *Gate:* `check-demos.sh` passes
   for all three demos with no desync.
5. **Playable.** Input, menus, HUD, status bar, automap, intermission, finale,
   wipe, cheats, the attract loop and the new-game flow. *Gate:* demos still in
   sync, and scripted headless runs of `-warp` 1 1 through every shareware map
   (start the map, run N tics, end) finish with no crash. Then post a
   **playtest request** (see below).
6. **Sound and music** (optional scope). SFX, `mus2mid`, SDL_mixer playback.
   *Gate:* the MUS→MIDI unit tests pass against `mus2mid.c` output, and a
   headless run with the dummy audio driver doesn't crash. Then post a playtest
   request.
7. **Savegames and config** (optional scope). *Gate:* round-trip tests; saving
   and loading mid-demo continues the tic hashes unchanged. Then post a playtest
   request.
8. **Idiom pass and final report.** Revisit the modules written early with the
   experience gained since, and tighten them. Finalize the `ISSUES.md` ranking,
   add a per-subsystem table of C line counts against Nucleus line counts, and
   write a short executive summary at the top: the five changes that would help
   most, and why.

**Playtest requests.** The user playtests on the host. A request is a section in
`PROGRESS.md` that gives:
- the exact host commands to build and run the game (including `make` in
  `/home/zak/code/nucleus` if the port depends on compiler fixes);
- what to try;
- known problems.

Mention the request in your reply too. **Don't block on it.** Continue with the
next milestone, and work any feedback that comes back in as soon as it arrives.

## 10. Working practices

- **Progress tracking.** Keep `PROGRESS.md` current: the milestone status, what's
  in progress, the next steps and any open questions. Assume your context will be
  compacted and that another session may pick the work up from `PROGRESS.md` and
  `CLAUDE.md` alone.
- **Long sessions.** Work in small increments that build and commit cleanly, so
  that a session limit or a context compaction never strands half-done work.
  Before each long-running step (a compiler test run, a full demo check), make
  sure `PROGRESS.md` says what is in flight.
- **Probing.** When the compiler surprises you, stop and write the probe *before*
  working around the problem; this keeps the workaround from hiding it. Use
  `nucleusc --run` or the REPL for quick experiments (see the Nucleus
  `docs/compiler.md` and `context/repl.md`).
- **Self-improving context.** When you learn something non-obvious about the
  environment, the toolchain or a workflow, add it to `CLAUDE.md`. Language
  findings go to `ISSUES.md`, not `CLAUDE.md`.

## 11. Definition of done

- All milestones in scope are complete, with their gates green, and the work is
  committed.
- `ISSUES.md` is ranked and evidenced: every bug has a probe, every workaround
  is tagged in the code, and the executive summary and line-count table are
  written.
- `scripts/check-probes.sh`, `scripts/check-demos.sh` and the unit tests all run
  from a clean checkout, following only the instructions in `CLAUDE.md`, both in
  the container and on the host.
- Every compiler fix is committed on `doom-bugfixes` with a passing Nucleus test
  suite and bootstrap, and the `ISSUES.md` entry for each one names its commit.
