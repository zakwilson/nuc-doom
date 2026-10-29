#!/usr/bin/env python3
# Code lines (not blank, not comment-only) per subsystem: the C each part of
# the port replaces against the Nucleus it became, as a Markdown table. The
# C is also counted without lines that hold only a brace, since a Lisp closes
# its forms on the last line; the ratio is against that count.
# Headers count with their C files; Chocolate Doom's own extras that the port
# leaves out (netgames, dehacked, OPL, the setup tool) are not counted.
# Usage: scripts/count-lines.py [CHOCOLATE_DOOM_SRC]
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHOC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    os.environ.get("CHOCOLATE_DOOM", "/home/zak/code/chocolate-doom"), "src")

# (subsystem, C sources under src/ with their headers, Nucleus sources under src/doom/)
SUBSYSTEMS = [
    ("Fixed point, trig and RNG", ["m_fixed", "doom/m_random", "m_bbox"], ["math", "random"], ""),
    ("Trig tables (data)", ["tables"], ["tables"], "embedded, checked element-wise against the C"),
    ("Thing, state and sound tables (data)", ["doom/info", "doom/sounds"],
     ["info", "sounds", "tablegen"], "one row per line, expanded by `tablegen` macros"),
    ("WAD files", ["w_wad", "w_file", "w_file_stdc", "w_main"], ["wad", "bytes"], "whole files in memory; no merging or checksums"),
    ("Types and globals", ["doom/doomdef", "doom/doomstat", "doom/d_items", "doom/doomdata",
                           "doom/d_player", "doom/d_think", "doom/r_defs", "doom/p_mobj",
                           "doom/doomtype", "d_mode", "doom/d_englsh"],
     ["defs", "world", "state", "items", "table", "geom"],
     "`d_englsh.h`'s 587 lines of strings are inlined where they're used"),
    ("Renderer", ["doom/r_bsp", "doom/r_data", "doom/r_draw", "doom/r_main", "doom/r_plane",
                  "doom/r_segs", "doom/r_sky", "doom/r_things", "doom/r_state", "doom/r_local"],
     ["render/bsp", "render/data", "render/draw", "render/main", "render/plane",
      "render/segs", "render/things"], ""),
    ("Playsim", ["doom/p_ceilng", "doom/p_doors", "doom/p_enemy", "doom/p_floor", "doom/p_inter",
                 "doom/p_lights", "doom/p_map", "doom/p_maputl", "doom/p_mobj", "doom/p_plats",
                 "doom/p_pspr", "doom/p_setup", "doom/p_sight", "doom/p_spec", "doom/p_switch",
                 "doom/p_telept", "doom/p_tick", "doom/p_user", "doom/p_local", "p_rejectpad"],
     ["play/thinkers", "play/tick", "play/setup", "play/mobj", "play/maputl", "play/map",
      "play/sight", "play/inter", "play/enemy", "play/pspr", "play/user", "play/movers",
      "play/lights", "play/spec"], "every `gameversion` branch kept"),
    ("Game flow and main loop", ["doom/g_game", "doom/d_main", "d_loop", "d_event", "m_argv",
                                 "i_main", "i_timer", "i_system"],
     ["game", "main", "event", "args", "sys/timer", "system", "tichash"], "no netgame, demo recording or response files"),
    ("Menus, HUD, status bar, cheats", ["doom/m_menu", "doom/hu_lib", "doom/hu_stuff",
                                        "doom/st_lib", "doom/st_stuff", "m_cheat",
                                        "doom/dstrings"],
     ["menu", "hud", "status", "cheat"], "no chat"),
    ("Automap, intermission, finale, wipe", ["doom/am_map", "doom/wi_stuff", "doom/f_finale",
                                             "doom/f_wipe"],
     ["automap", "intermission", "finale", "wipe"], "single-player intermission only"),
    ("Video and input", ["v_video", "i_video", "i_input"], ["video", "sys/video", "sys/input"], "no scaling options, fullscreen toggle or joystick"),
    ("Sound and music", ["doom/s_sound", "i_sdlsound", "i_sdlmusic", "i_sound", "mus2mid"],
     ["sound", "sys/sound", "sys/music", "sys/mus2mid"], "SDL_mixer only: no OPL, PC speaker or GUS"),
    ("Savegames and config", ["doom/p_saveg", "m_config", "m_controls", "m_misc"],
     ["savegame", "savecodec", "config", "files"], "the C config covers every Chocolate Doom setting"),
]


def c_lines(path):
    text = open(path, encoding="latin-1").read()
    text = re.sub(r"/\*.*?\*/", lambda m: "\n" * m.group(0).count("\n"), text, flags=re.S)
    text = re.sub(r"//[^\n]*", "", text)
    lines = [line.strip() for line in text.split("\n") if line.strip()]
    return (len(lines), sum(1 for line in lines if line not in ("{", "}", "};", "},")))


def nuc_lines(path):
    n = 0
    for line in open(path, encoding="utf-8"):
        s = line.strip()
        if s and not s.startswith(";"):
            n += 1
    return n


def count(stems, base, exts, fn):
    total = None
    for stem in stems:
        for ext in exts:
            p = os.path.join(base, stem + ext)
            if os.path.exists(p):
                v = fn(p)
                total = v if total is None else tuple(a + b for a, b in zip(total, v)) \
                    if isinstance(v, tuple) else total + v
    return total


def main():
    rows = []
    tc = tb = tn = 0
    for name, cs, ns, note in SUBSYSTEMS:
        c, b = count(cs, CHOC, [".c", ".h"], c_lines)
        n = count(ns, os.path.join(ROOT, "src", "doom"), [".nuc"], nuc_lines)
        rows.append((name, c, b, n, note))
        tc += c
        tb += b
        tn += n
    print("| Subsystem | C | C without braces | Nucleus | Ratio | Notes |")
    print("|---|---:|---:|---:|---:|---|")
    for name, c, b, n, note in rows:
        print(f"| {name} | {c} | {b} | {n} | {n / b:.2f} | {note} |")
    print(f"| **Total** | **{tc}** | **{tb}** | **{tn}** | **{tn / tb:.2f}** | |")


main()
