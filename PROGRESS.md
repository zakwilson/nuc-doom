# Progress

## Milestones

| # | Milestone | Status |
|---|---|---|
| 0 | Setup: scaffold, hello SDL, reference harness, demo data | done |
| 1 | Foundations: fixed, tables, random, WAD, info, types, argv | next |
| 2 | Static graphics, `-framedump` | — |
| 3 | Level load and renderer | — |
| 4 | Playsim, demos, `-tichash` | — |
| 5 | Playable | — |
| 6 | Sound and music (optional) | — |
| 7 | Savegames and config (optional) | — |
| 8 | Idiom pass and final report | — |

## Reference harness

- `scripts/build-reference.sh` builds the patched engine into `reference/build/`
  (gitignored). `--record` regenerates `reference/data/demo*.tichash`.
- The tichash line is `tic=N rnd=R prnd=P mobj=XXXXXXXX p0=health,armor,weapon,kills,items,secrets`,
  where the mobj hash is FNV-1a over the little-endian bytes of each mobj's
  `x y z angle momx momy momz health type state-index flags`, in thinker order.
  It is written after each `G_Ticker`. See `reference/tichash.patch`.
- `-framedump <tic,...> <dir>` writes `<dir>/ticNNNNN.ppm` (P6, 320×200) after
  `I_FinishUpdate` on normal frames (never mid-wipe), forces one tic per frame,
  and exits after the last dump.
- Reference frames: `reference/data/frames/title/tic00005.ppm` (TITLEPIC) and
  `reference/data/frames/e1m1/tic00040.ppm` (`-warp 1 1`, default view size).
- Things the port must reproduce for sync: `M_Random` is drawn by the status-bar
  face every tic, by the wipe melt (320 draws, between tics: rnd jumps by 321 at
  tic 2 of demo1), by intermission animations, and by `S_StartSound` even with
  `-nosound`.

## Next steps

- Milestone 1. Open question: how to build a unit-test program beside the game.
  `build.edn` has one `:entry`; options are a second project directory under
  `test/`, or a plain `nucleusc` line in a script.
