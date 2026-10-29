#!/usr/bin/env python3
# One-time conversion of info.c/info.h/sounds.c into src/doom/info.nuc and
# src/doom/sounds.nuc. Those files are the maintained source now; this script
# is kept to show where their rows came from.
import os
import re
import sys

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
choc = os.environ.get("CHOCOLATE_DOOM", "/home/zak/code/chocolate-doom")
doom = os.path.join(choc, "src/doom")

HEADER = [
    "; Copyright(C) 1993-1996 Id Software, Inc.; Copyright(C) 2005-2014 Simon Howard.",
    "; GPLv2 or later; see COPYING.",
]


def sym(c):
    """A C identifier in Nucleus constant style: S_PLAY_RUN1 -> S-PLAY-RUN1."""
    return c.replace("_", "-").upper()


def expr(c):
    c = c.strip()
    if re.fullmatch(r"-?\d+", c):
        return c
    m = re.fullmatch(r"(\d+)\*FRACUNIT", c)
    if m:
        return "(* %s FRAC-UNIT)" % m.group(1)
    if "|" in c:
        return "(bit-or* %s)" % " ".join(expr(p) for p in c.split("|"))
    m = re.fullmatch(r"sfx_(\w+)", c)
    if m:
        return "SFX-" + sym(m.group(1))
    if re.fullmatch(r"[A-Z][A-Z0-9_]*", c):
        return sym(c)
    raise ValueError("unhandled C expression: " + c)


def macro(name, rows, width):
    out = ["(defmacro- %s (m :rest args)" % name, "  `(~m ~@args"]
    for r in rows:
        out.append("    (" + " ".join(r) + ")")
    out[-1] += "))"
    return out


info = open(os.path.join(doom, "info.c")).read()

sprites = re.findall(r'"(\w{4})"', info[info.index("sprnames"):info.index("// Doesn't work")
                                       if "// Doesn't work" in info else info.index("state_t")])
sprite_rows = [("SPR-" + s, '"%s"' % s) for s in sprites]

state_src = info[info.index("state_t\tstates"):info.index("mobjinfo_t mobjinfo")]
state_rows = []
actions = ["A-NULL"]
for m in re.finditer(r"\{(SPR_\w+),(\d+),(-?\d+),\{(\w+)\},(\w+),(-?\d+),(-?\d+)\},?\s*// (\w+)", state_src):
    spr, frame, tics, act, nxt, m1, m2, name = m.groups()
    a = "A-NULL" if act == "NULL" else sym(act)
    if a not in actions:
        actions.append(a)
    state_rows.append((sym(name), sym(spr), frame, tics, a, sym(nxt), m1, m2))

mobj_src = info[info.index("mobjinfo_t mobjinfo"):]
mobj_rows = []
for m in re.finditer(r"\{\s*// (MT_\w+)(.*?)\n\s*\}", mobj_src, re.S):
    vals = [line.split("//")[0].strip().rstrip(",") for line in m.group(2).strip().split("\n")]
    vals = [v for v in vals if v]
    assert len(vals) == 23, (m.group(1), vals)
    row = [sym(m.group(1))] + [expr(v) for v in vals]
    # radius and height are fixed-point fields.
    row[17] = "(Fixed %s)" % row[17]
    row[18] = "(Fixed %s)" % row[18]
    mobj_rows.append(row)

sounds = open(os.path.join(doom, "sounds.c")).read()
music_rows = []
for i, m in enumerate(re.finditer(r"MUSIC\((NULL|\"(\w+)\")\)", sounds)):
    name = m.group(2) or ""
    music_rows.append(("MUS-" + (sym(name) if name else "NONE"), '"%s"' % name))
sfx_rows = []
for m in re.finditer(r'SOUND(?:_LINK)?\("(\w+)",\s*(\d+)(?:,\s*sfx_(\w+),\s*(\d+),\s*(\d+))?\)', sounds):
    name, prio, link, pitch, vol = m.groups()
    sfx_rows.append(("SFX-" + sym(name), '"%s"' % name, prio,
                     "SFX-" + sym(link) if link else "-1", pitch or "-1", vol or "-1"))

out = HEADER + [
    "; Sound effect and music tables (sounds.c, sounds.h).",
    "",
    "(ns doom.sounds)",
    "",
    "(import-use doom.tablegen)",
    "",
    "; `link` is another sfx whose pitch and volume this one borrows, or -1.",
    "(defstruct SfxInfo name:StrView priority:i32 link:i32 pitch:i32 volume:i32)",
    "",
]
out += macro("over-sfx", sfx_rows, 6) + ["", "(over-sfx def-enum-rows Sfx)",
                                        "(over-sfx def-count-row NUM-SFX)",
                                        "(over-sfx def-table-rows sfx-info SfxInfo)", ""]
out += macro("over-music", music_rows, 2) + ["", "(over-music def-enum-rows Music)",
                                            "(over-music def-count-row NUM-MUSIC)",
                                            "(over-music def-table-rows music-names StrView)", ""]
open(os.path.join(root, "src/doom/sounds.nuc"), "w").write("\n".join(out))

out = HEADER + [
    "; Sprite, state and thing tables (info.c, info.h). Each table is one row",
    "; set: its enum and its data are both expanded from the same rows.",
    "",
    "(ns doom.info)",
    "",
    "(import-use doom.tablegen)",
    "(import-use doom.math)",
    "(import-use doom.sounds)",
    "",
]
pm = open(os.path.join(doom, "p_mobj.h")).read()
out += ["; Thing flags (p_mobj.h)."]
for name, val in re.findall(r"\b(MF_\w+)\s*=\s*(\w+)", pm):
    out.append("(defconst %s %s)" % (sym(name), val))
out += [""]
out += macro("over-sprites", sprite_rows, 2) + [
    "", "(over-sprites def-enum-rows SpriteNum)", "(over-sprites def-count-row NUM-SPRITES)",
    "(over-sprites def-table-rows sprite-names StrView)", ""]
out += ["; The code pointers states name. The playsim maps each to its function."]
out += ["(defenum Action"] + ["  " + a for a in actions]
out[-1] += ")"
out += [""]
out += ["(defstruct State sprite:i32 frame:i32 tics:i32 action:i32 next-state:i32 misc1:i32 misc2:i32)", ""]
out += macro("over-states", state_rows, 8) + [
    "", "(over-states def-enum-rows StateNum)", "(over-states def-count-row NUM-STATES)",
    "(over-states def-mutable-table-rows states State)", ""]
out += ["(defstruct MobjInfo",
        "  doomed-num:i32 spawn-state:i32 spawn-health:i32 see-state:i32 see-sound:i32",
        "  reaction-time:i32 attack-sound:i32 pain-state:i32 pain-chance:i32 pain-sound:i32",
        "  melee-state:i32 missile-state:i32 death-state:i32 xdeath-state:i32 death-sound:i32",
        "  speed:i32 radius:Fixed height:Fixed mass:i32 damage:i32 active-sound:i32",
        "  flags:i32 raise-state:i32)", ""]
out += macro("over-mobjs", mobj_rows, 24) + [
    "", "(over-mobjs def-enum-rows MobjType)", "(over-mobjs def-count-row NUM-MOBJ-TYPES)",
    "(over-mobjs def-mutable-table-rows mobj-info MobjInfo)", ""]
open(os.path.join(root, "src/doom/info.nuc"), "w").write("\n".join(out))
print(len(sprite_rows), "sprites,", len(state_rows), "states,", len(actions), "actions,",
      len(mobj_rows), "mobj types,", len(sfx_rows), "sfx,", len(music_rows), "music")
