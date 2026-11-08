#!/usr/bin/env python3
"""Static fairness checks for the levels in gen_levels.py (no game engine needed).

Usage:  python3 tools/check_levels.py [first_level [last_level]]      (1-based, default 41 50)

It can not play the levels, but it catches the mistakes that make a level unbeatable or unfair:
  * floor holes wider than a running jump (unless a platform / mover / falling platform covers them)
  * landing spots that are much higher than the take-off spot
  * enemies standing on nothing, crushers hanging over pits, hazards inside solid tiles
  * spike fields without a safe take-off and landing strip
  * checkpoints that are too far apart, warp pipes that do not line up with their link
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_levels as G  # noqa: E402

SOLID = set("GXBM?*-TtLlg")      # anything that blocks
STAND = set("GXTtLl-g")          # things the hero walks on (blocks hanging in the air are ignored)
MAX_RUN = 5          # widest hole (in tiles) a normal running jump has to cross
MAX_RUN_LOW_G = 9    # low gravity worlds (space)


def analyse(L):
    mw = L.main_w if L.main_w else L.w
    rows = [r[:mw] for r in L.rows()]
    problems, notes = [], []
    low_g = L.theme == "space"
    limit = MAX_RUN_LOW_G if low_g else MAX_RUN

    # ---- columns that are supported by something you can stand on
    sup = [False] * mw
    top = [99] * mw
    for c in range(mw):
        for r in range(5, G.H):
            if rows[r][c] in STAND:
                sup[c] = True
                top[c] = min(top[c], r)
    # moving / falling platforms add support around them
    for r in range(G.H):
        for c in range(mw):
            ch = rows[r][c]
            if ch == "N":
                for k in range(c - 4, c + 5):
                    if 0 <= k < mw:
                        sup[k] = True; top[k] = min(top[k], r)
            elif ch == "n":
                for k in range(c - 5, c + 6):
                    if 0 <= k < mw:
                        sup[k] = True; top[k] = min(top[k], r)
            elif ch in "Wf":
                for k in range(c - 1, c + 2):
                    if 0 <= k < mw:
                        sup[k] = True; top[k] = min(top[k], r)
    # lava is not support, stones (X) are
    springs = [c for c in range(mw) if any(rows[r][c] == "J" for r in range(G.H))]
    run, start = 0, 0
    worst = 0
    for c in range(mw + 1):
        if c < mw and not sup[c]:
            if run == 0:
                start = c
            run += 1
        else:
            if run:
                worst = max(worst, run)
                boosted = any(start - 3 <= sc < start for sc in springs)
                if boosted and run <= 8:
                    pass  # a spring right before the hole launches the hero much higher and further
                elif run > limit:
                    problems.append("hole of %d tiles at column %d (limit %d)" % (run, start, limit))
                elif 0 < start and c < mw:
                    rise = top[start - 1] - top[c]
                    allowed = 3 if run <= 3 else 2
                    if rise > allowed:
                        problems.append("landing %d tiles higher than take-off after a %d tile hole at column %d" % (rise, run, start))
            run = 0
    notes.append("widest hole %d" % worst)

    # ---- falling platform chains: neighbours must be close enough to hop between
    fcols = []
    for r in range(G.H):
        for c in range(mw):
            if rows[r][c] == "f":
                fcols.append((c, r))
    fcols.sort()
    for (c1, r1), (c2, r2) in zip(fcols, fcols[1:]):
        if c2 - c1 <= 6:
            if c2 - c1 > 4:
                problems.append("falling platforms %d tiles apart at column %d" % (c2 - c1, c1))
            if abs(r2 - r1) > 1:
                problems.append("falling platforms differ by %d rows at column %d" % (abs(r2 - r1), c1))

    # ---- enemies, pipes, crushers
    for c in range(mw):
        for r in range(G.H):
            ch = rows[r][c]
            if ch in "EK":
                below = rows[r + 1][c] if r + 1 < G.H else "."
                if below not in SOLID:
                    problems.append("%s at column %d row %d has no floor" % (ch, c, r))
            if ch == "O":
                for k in (c, c + 1):
                    if k >= mw or rows[12][k] not in "GX":
                        problems.append("crusher at column %d hangs over a hole" % c)
                        break
                if rows[11][c] in "SEK" or rows[11][min(c + 1, mw - 1)] in "SEK":
                    problems.append("crusher at column %d sits on a hazard" % c)
            if ch == "F":
                if rows[r + 1][c] != "T":
                    problems.append("piranha at column %d is not above a pipe" % c)

    # ---- spike fields need a safe strip before and after
    c = 0
    while c < mw:
        if rows[11][c] == "S" and (c == 0 or rows[11][c - 1] != "S"):
            e = c
            while e + 1 < mw and rows[11][e + 1] == "S":
                e += 1
            width = e - c + 1
            if width > 5:
                problems.append("spike field of %d tiles at column %d" % (width, c))
            for k in (c - 2, c - 1, e + 1, e + 2):
                if k < 0 or k >= mw:
                    continue
                if rows[12][k] not in "GX" and rows[11][k] not in "GX":
                    problems.append("no floor next to spikes at column %d" % k)
                if rows[11][k] in "EKSFTtLl" or rows[10][k] in "TtLl":
                    problems.append("no safe strip next to spikes at column %d (%s)" % (k, rows[11][k]))
                for r in range(4, 8):
                    if rows[r][k] == "O" or (k > 0 and rows[r][k - 1] == "O"):
                        problems.append("crusher right next to spikes at column %d" % k)
            c = e + 1
        else:
            c += 1

    # ---- checkpoints
    cps = [c for c in range(mw) if "c" in "".join(rows[r][c] for r in range(G.H))]
    marks = [2] + cps + [mw - 15]
    for a, b in zip(marks, marks[1:]):
        if b - a > 90:
            problems.append("%d columns without a checkpoint after column %d" % (b - a, a))
    notes.append("%d checkpoints" % len(cps))

    # ---- warps
    for (x1, y1, x2, y2) in L.warps:
        for (x, y) in ((x1, y1), (x2, y2)):
            if G.Lvl.at(L, x, y) != "Y" or G.Lvl.at(L, x + 1, y) != "y":
                problems.append("warp pipe at (%d,%d) is missing" % (x, y))
    if L.warps:
        flat = "".join(L.rows())
        if "M" not in "".join(r[mw:] for r in L.rows()) and "*" not in "".join(r[mw:] for r in L.rows()):
            problems.append("bonus rooms have no power-up")
    return problems, notes


def main():
    a = int(sys.argv[1]) if len(sys.argv) > 1 else 41
    b = int(sys.argv[2]) if len(sys.argv) > 2 else 50
    bad = 0
    for i in range(a, b + 1):
        L = getattr(G, "lvl%d" % i)()
        problems, notes = analyse(L)
        status = "OK " if not problems else "BAD"
        print("%s %2d %-18s width %3d time %3d  %s" % (status, i, L.name, L.main_w if L.main_w else L.w, L.time, ", ".join(notes)))
        for p in problems:
            print("      - " + p)
        bad += len(problems)
    print("\n%d problem(s)" % bad)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
