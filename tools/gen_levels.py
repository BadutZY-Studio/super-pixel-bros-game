#!/usr/bin/env python3
"""Hand-designed level DSL -> scripts/levels_data.gd

Legend:  . empty   G ground   X hard block   B brick   ? coin block   M power-up block
         C coin    E goomba   K koopa         F piranha (above pipe)   S spikes
         V/v lava  - one-way platform         T t L l pipe tiles   P spawn
         Z flag    D castle   c checkpoint    N/n horizontal moving platform  W vertical platform
  --- chapter 2 ---
         Y y warp pipe top (press DOWN on it)   g underground dirt (bonus rooms)   A bat   J spring
         * star block   R fire bar   f falling platform   O crusher
"""
import os

H = 14
SURF = 12  # ground surface row


class Lvl:
    def __init__(s, name, theme, time):
        s.name, s.theme, s.time = name, theme, time
        s.w = 400
        s.g = [["."] * s.w for _ in range(H)]
        s.x = 0
        s.warps = []
        s.main_w = 0
        s.put(2, 11, "P")

    def put(s, x, y, ch):
        if 0 <= x < s.w and 0 <= y < H:
            s.g[y][x] = ch

    def at(s, x, y):
        return s.g[y][x] if 0 <= x < s.w and 0 <= y < H else "."

    # --- terrain (cursor based)
    def flat(s, n, top=SURF):
        x0 = s.x
        for x in range(x0, x0 + n):
            for y in range(top, H):
                s.put(x, y, "G")
        s.x += n
        return x0

    def gap(s, n):
        s.x += n
        return s.x - n

    def raise_(s, x1, x2, top):
        for x in range(x1, x2 + 1):
            for y in range(top, SURF):
                s.put(x, y, "G")

    def island(s, n, top, thick=2):
        x0 = s.x
        for x in range(x0, x0 + n):
            for y in range(top, top + thick):
                s.put(x, y, "G")
        s.x += n
        return x0

    def stones(s, parts):
        for ln, sn in parts:
            s.lava(ln)
            if sn:
                x0 = s.lava(sn)
                for x in range(x0, x0 + sn):
                    s.put(x, 11, "X")

    def bridge(s, n, y=SURF):
        x0 = s.x
        for x in range(x0, x0 + n):
            s.put(x, y, "X")
        s.x += n
        return x0

    def lava(s, n):
        x0 = s.x
        for x in range(x0, x0 + n):
            s.put(x, SURF, "V")
            s.put(x, SURF + 1, "v")
        s.x += n
        return x0

    # --- objects
    def blk(s, x, y, ch="B"):
        s.put(x, y, ch)

    def row(s, x1, x2, y, ch="B"):
        for x in range(x1, x2 + 1):
            s.put(x, y, ch)

    def pipe(s, x, h, piranha=False):
        top = SURF - h
        for y in range(top, SURF):
            if y == top:
                s.put(x, y, "T"); s.put(x + 1, y, "t")
            else:
                s.put(x, y, "L"); s.put(x + 1, y, "l")
        if piranha:
            s.put(x, top - 1, "F")

    def stairs(s, x, n, up=True):
        for i in range(n):
            hgt = i + 1 if up else n - i
            for k in range(hgt):
                s.put(x + i, SURF - 1 - k, "X")

    def coins(s, x, y, n):
        for i in range(n):
            s.put(x + i, y, "C")

    def arc(s, x, y, n):
        for i in range(n):
            off = int(round(-1.6 * (1 - ((2 * i / max(1, n - 1)) - 1) ** 2) * 1.4))
            s.put(x + i, y + off, "C")

    def en(s, x, k="E", y=11):
        s.put(x, y, k)

    def plat(s, x1, x2, y):
        for x in range(x1, x2 + 1):
            s.put(x, y, "-")

    def spikes(s, x1, x2, y=11):
        for x in range(x1, x2 + 1):
            s.put(x, y, "S")

    def cp(s, x, y=11):
        s.put(x, y, "c")

    def mover(s, x, y, ch="N"):
        s.put(x, y, ch)

    # --- chapter 2 helpers
    def warp_pipe(s, x, h=2):
        """Enterable pipe. Returns its id (left column, top row) for link()."""
        top = SURF - h
        for y in range(top, SURF):
            if y == top:
                s.put(x, y, "Y"); s.put(x + 1, y, "y")
            else:
                s.put(x, y, "L"); s.put(x + 1, y, "l")
        return (x, top)

    def link(s, a, b):
        """Two-way link between two warp pipes."""
        s.warps.append([a[0], a[1], b[0], b[1]])

    def spring(s, x, y=11):
        s.put(x, y, "J")

    def bat(s, x, y=7):
        s.put(x, y, "A")

    def star(s, x, y=8):
        s.put(x, y, "*")

    def firebar(s, x, y):
        s.put(x, y, "R")

    def fall(s, x, y):
        s.put(x, y, "f")

    def crusher(s, x, y=5):
        s.put(x, y, "O")

    def room(s):
        """Appends a 25 column underground bonus room (walls + ceiling + floor) and returns its left column.
        Interior = rows 3..11 and columns rx+1 .. rx+23.  A warp pipe goes at rx+3 (use warp_pipe(rx+3))."""
        rx = s.w
        for y in range(H):
            s.g[y] += ["g"] * 25
        s.w += 25
        for y in range(3, 12):
            for x in range(rx + 1, rx + 24):
                s.g[y][x] = "."
        return rx

    def span(s, n, items, lava=False):
        """A hole of n columns that is bridged by moving / falling platforms.
        items = [(dx, row, char)] with dx relative to the start of the hole (char: f N n W)."""
        x0 = s.x
        if lava:
            s.lava(n)
        else:
            s.x += n
        for dx, row, ch in items:
            s.put(x0 + dx, row, ch)

    def finish(s):
        x0 = s.x
        for x in range(x0, x0 + 18):
            for y in range(SURF, H):
                s.put(x, y, "G")
        s.put(x0 + 3, 11, "X")
        s.put(x0 + 3, 10, "Z")
        s.put(x0 + 8, 11, "D")
        s.w = x0 + 18
        s.g = [r[:s.w] for r in s.g]
        s.x = s.w
        s.main_w = s.w

    def rows(s):
        return ["".join(r) for r in s.g]


# ================================================================= LEVELS
def lvl1():
    L = Lvl("GREEN HILLS", "grass", 300)
    L.flat(16); x = L.flat(26)
    L.coins(x - 8, 9, 3)
    L.blk(x + 3, 8, "?"); L.row(x + 5, x + 9, 8, "B"); L.blk(x + 6, 8, "M"); L.blk(x + 8, 8, "?")
    L.en(x + 16); L.pipe(x + 20, 2)
    L.gap(3); L.arc(x + 26, 9, 3)
    x = L.flat(28)
    L.en(x + 5); L.en(x + 9); L.pipe(x + 13, 3); L.en(x + 19, "K")
    L.row(x + 21, x + 25, 8, "B"); L.blk(x + 23, 8, "?"); L.coins(x + 21, 6, 5)
    L.gap(4)
    x = L.flat(30)
    L.stairs(x + 3, 4); L.en(x + 13); L.en(x + 16)
    L.blk(x + 19, 8, "?"); L.blk(x + 21, 8, "M"); L.blk(x + 23, 8, "?")
    L.cp(x + 26)
    L.gap(4)
    x = L.flat(26)
    L.pipe(x + 3, 2); L.pipe(x + 9, 3); L.en(x + 6); L.en(x + 14, "K"); L.en(x + 18)
    L.coins(x + 12, 7, 6)
    L.gap(3)
    x = L.flat(10)
    L.stairs(x, 5, up=False)
    L.gap(4)
    L.flat(8)
    L.finish()
    return L


def lvl2():
    L = Lvl("DUNE RUN", "desert", 320)
    L.flat(14)
    x = L.flat(24)
    L.spikes(x + 8, x + 9); L.blk(x + 12, 8, "?"); L.blk(x + 14, 8, "?"); L.en(x + 18, "K")
    L.gap(3)
    x = L.flat(20)
    L.en(x + 4); L.en(x + 8); L.spikes(x + 12, x + 14); L.coins(x + 11, 8, 5)
    L.gap(4); L.plat(L.x - 3, L.x - 2, 10)
    x = L.flat(26)
    L.blk(x + 3, 8, "M"); L.row(x + 5, x + 7, 8, "B")
    L.pipe(x + 12, 2); L.en(x + 16, "K"); L.en(x + 19)
    L.cp(x + 22)
    L.gap(5); L.plat(L.x - 4, L.x - 2, 9); L.arc(L.x - 5, 9, 4)
    x = L.flat(30)
    L.stairs(x + 2, 5); L.stairs(x + 8, 5, up=False)
    L.en(x + 16); L.en(x + 18, "K"); L.spikes(x + 22, x + 23); L.blk(x + 25, 8, "?")
    L.gap(4)
    x = L.flat(10); L.raise_(x + 3, x + 6, 10); L.coins(x + 3, 8, 4)
    L.gap(4)
    x = L.flat(24)
    L.en(x + 5, "K"); L.en(x + 7, "K"); L.pipe(x + 12, 3); L.spikes(x + 16, x + 17)
    L.finish()
    return L


def lvl3():
    L = Lvl("CRYSTAL CAVE", "cave", 340)
    L.flat(14)
    x = L.flat(30)
    L.pipe(x + 5, 2, piranha=True); L.en(x + 12); L.en(x + 15)
    L.row(x + 18, x + 24, 8, "B"); L.blk(x + 20, 8, "M"); L.blk(x + 22, 8, "?"); L.coins(x + 18, 6, 7)
    L.gap(3)
    x = L.flat(24)
    L.pipe(x + 4, 3, piranha=True); L.en(x + 10, "K"); L.pipe(x + 14, 2, piranha=True); L.en(x + 20)
    L.gap(4)
    x = L.flat(8); L.raise_(x + 2, x + 5, 10)
    L.coins(x + 2, 8, 4)
    L.gap(4)
    x = L.flat(30)
    L.cp(x + 2)
    L.en(x + 6); L.en(x + 8); L.en(x + 10, "K")
    L.row(x + 14, x + 20, 8, "B"); L.blk(x + 17, 8, "?"); L.blk(x + 15, 8, "M")
    L.en(x + 25); L.pipe(x + 27, 3, piranha=True)
    L.gap(4)
    x = L.flat(6); L.plat(x, x + 5, 9)
    L.gap(4)
    x = L.flat(26)
    L.stairs(x + 2, 4); L.en(x + 9); L.en(x + 12); L.en(x + 14, "K")
    L.pipe(x + 20, 2, piranha=True)
    L.gap(3)
    L.flat(10)
    L.finish()
    return L


def lvl4():
    L = Lvl("FROSTY PEAKS", "snow", 340)
    L.flat(14)
    x = L.flat(22)
    L.en(x + 8); L.blk(x + 12, 8, "?"); L.blk(x + 14, 8, "?");
    L.gap(8); L.mover(L.x - 4, 12, "N"); L.coins(L.x - 7, 9, 5)
    x = L.flat(18)
    L.en(x + 6, "K"); L.pipe(x + 12, 2)
    L.gap(9); L.mover(L.x - 5, 12, "n")
    x = L.flat(22)
    L.cp(x + 1)
    L.blk(x + 4, 8, "M"); L.en(x + 8); L.en(x + 11); L.en(x + 15, "K")
    L.gap(5); L.plat(L.x - 4, L.x - 2, 10)
    x = L.flat(14)
    L.stairs(x + 2, 4); L.stairs(x + 8, 4, up=False)
    L.gap(10); L.mover(L.x - 7, 11, "n"); L.coins(L.x - 9, 8, 6)
    x = L.flat(26)
    L.en(x + 5); L.en(x + 8, "K"); L.pipe(x + 12, 3)
    L.row(x + 16, x + 22, 8, "B"); L.blk(x + 19, 8, "?")
    L.gap(4)
    L.flat(8)
    L.finish()
    return L


def lvl5():
    L = Lvl("MIDNIGHT RUN", "night", 330)
    L.flat(12)
    x = L.flat(24)
    L.en(x + 6); L.en(x + 9); L.en(x + 12, "K"); L.blk(x + 15, 8, "M"); L.blk(x + 17, 8, "?")
    L.gap(4); L.blk(L.x - 2, 8, "B")
    x = L.flat(22)
    L.en(x + 4, "K"); L.en(x + 7); L.en(x + 10); L.pipe(x + 15, 2, piranha=True)
    L.gap(3)
    x = L.flat(4); L.gap(3); x2 = L.flat(4); L.gap(3); x3 = L.flat(4); L.gap(3)
    L.coins(x, 9, 4); L.coins(x2, 9, 4); L.en(x3 + 2)
    x = L.flat(26)
    L.cp(x + 1)
    L.stairs(x + 4, 5); L.stairs(x + 9, 5, up=False)
    L.en(x + 16); L.en(x + 18); L.en(x + 20, "K"); L.blk(x + 22, 8, "?")
    L.gap(5); L.plat(L.x - 4, L.x - 2, 9)
    x = L.flat(30)
    L.en(x + 4, "K"); L.en(x + 6, "K"); L.en(x + 9)
    L.pipe(x + 12, 3, piranha=True); L.pipe(x + 18, 2, piranha=True)
    L.row(x + 22, x + 27, 8, "B"); L.blk(x + 24, 8, "M")
    L.gap(4)
    L.flat(6)
    L.gap(4)
    L.flat(8)
    L.finish()
    return L


def lvl6():
    L = Lvl("SKY HIGH", "sky", 320)
    L.flat(10)
    L.gap(4); L.island(8, 11); L.coins(L.x - 7, 8, 5)
    L.gap(4); L.island(6, 10); L.blk(L.x - 4, 6, "?")
    L.gap(4); L.island(6, 9); L.en(L.x - 3, y=8)
    L.gap(5); x = L.island(5, 10); L.coins(x, 7, 5)
    L.gap(3); L.mover(L.x + 2, 11, "N"); L.gap(9)
    x = L.island(8, 10); L.blk(x + 3, 7, "M"); L.cp(x + 6, 9)
    L.gap(4); L.island(4, 11)
    L.gap(4); L.island(4, 10)
    L.gap(4); x = L.island(10, 9); L.en(x + 5, "K", y=8); L.coins(x + 1, 6, 8)
    L.gap(3); L.mover(L.x + 2, 10, "W"); L.gap(7)
    x = L.island(8, 8); L.blk(x + 2, 5, "?"); L.blk(x + 5, 5, "?")
    L.gap(4); L.island(5, 10)
    L.gap(5); L.island(5, 11)
    L.gap(4); x = L.island(8, 10); L.en(x + 3, y=9)
    L.gap(3)
    # landing runway
    L.bridge(2, 12)
    L.finish()
    return L


def lvl7():
    L = Lvl("ANCIENT RUINS", "desert", 350)
    L.flat(12)
    x = L.flat(26)
    L.spikes(x + 5, x + 7); L.en(x + 12, "K"); L.en(x + 15); L.pipe(x + 19, 3, piranha=True)
    L.gap(4)
    x = L.flat(24)
    L.stairs(x + 2, 4); L.spikes(x + 7, x + 9); L.stairs(x + 11, 4, up=False)
    L.blk(x + 18, 8, "M"); L.en(x + 20, "K"); L.en(x + 22)
    L.gap(4)
    x = L.flat(26)
    L.cp(x + 1)
    L.pipe(x + 4, 2, piranha=True); L.pipe(x + 10, 3, piranha=True); L.pipe(x + 17, 2, piranha=True)
    L.en(x + 14, "K"); L.coins(x + 5, 8, 5)
    L.gap(5); L.plat(L.x - 4, L.x - 2, 10)
    x = L.flat(28)
    L.spikes(x + 4, x + 5); L.spikes(x + 9, x + 11); L.en(x + 15, "K"); L.en(x + 17, "K")
    L.row(x + 20, x + 25, 8, "B"); L.blk(x + 22, 8, "?")
    L.gap(4)
    x = L.flat(10); L.raise_(x + 3, x + 6, 10); L.raise_(x + 4, x + 5, 9); L.en(x + 8)
    L.gap(5)
    x = L.flat(24)
    L.en(x + 4); L.en(x + 6); L.en(x + 8, "K"); L.spikes(x + 13, x + 14); L.pipe(x + 18, 3, piranha=True)
    L.finish()
    return L


def lvl8():
    L = Lvl("BLIZZARD PASS", "snow", 360)
    L.flat(12)
    x = L.flat(20)
    L.en(x + 6, "K"); L.pipe(x + 12, 2, piranha=True); L.blk(x + 16, 8, "?")
    L.gap(9); L.mover(L.x - 5, 12, "n"); L.coins(L.x - 8, 9, 6)
    x = L.flat(14)
    L.en(x + 4, "K"); L.en(x + 7, "K"); L.blk(x + 10, 8, "M")
    L.gap(4); L.plat(L.x - 3, L.x - 2, 10)
    x = L.flat(10); L.raise_(x + 2, x + 7, 10); L.en(x + 5, y=9)
    L.gap(11); L.mover(L.x - 7, 11, "n"); L.mover(L.x - 3, 12, "W")
    x = L.flat(22)
    L.cp(x + 1)
    L.en(x + 6); L.en(x + 9); L.en(x + 12, "K"); L.pipe(x + 16, 3, piranha=True)
    L.gap(5)
    x = L.flat(18)
    L.stairs(x + 2, 5); L.stairs(x + 8, 5, up=False); L.blk(x + 14, 8, "?"); L.en(x + 15, "K")
    L.gap(10); L.mover(L.x - 6, 12, "n")
    x = L.flat(26)
    L.en(x + 4, "K"); L.en(x + 6, "K"); L.en(x + 10); L.pipe(x + 14, 2, piranha=True); L.pipe(x + 20, 3, piranha=True)
    L.finish()
    return L


def lvl9():
    L = Lvl("FIRE FORTRESS", "castle", 380)
    L.flat(12)
    x = L.flat(18)
    L.en(x + 6, "K"); L.spikes(x + 10, x + 11); L.blk(x + 14, 8, "M")
    L.stones([(3, 2), (2, 2)])
    x = L.flat(10)
    L.en(x + 4)
    L.lava(8); L.mover(L.x - 4, 11, "N")
    x = L.flat(14)
    L.cp(x + 1); L.stairs(x + 3, 4); L.en(x + 10, "K")
    L.lava(10); L.mover(L.x - 6, 10, "W")
    x = L.flat(12)
    L.blk(x + 3, 8, "?"); L.en(x + 6); L.en(x + 8)
    L.stones([(2, 2), (2, 2), (3, 0)])
    x = L.flat(20)
    L.spikes(x + 4, x + 6); L.en(x + 10, "K"); L.en(x + 12, "K"); L.pipe(x + 16, 3, piranha=True)
    L.lava(12); L.mover(L.x - 8, 11, "n")
    x = L.flat(24)
    L.stairs(x + 2, 5); L.stairs(x + 8, 5, up=False)
    L.en(x + 15); L.en(x + 17, "K"); L.spikes(x + 20, x + 21)
    L.finish()
    return L


def lvl10():
    L = Lvl("FINAL CASTLE", "castle", 420)
    L.flat(10)
    x = L.flat(22)
    L.en(x + 5); L.en(x + 8, "K"); L.pipe(x + 12, 3, piranha=True); L.blk(x + 17, 8, "M"); L.blk(x + 19, 8, "?")
    L.lava(6)
    x = L.flat(8); L.spikes(x + 3, x + 4)
    L.lava(9); L.mover(L.x - 5, 11, "N")
    x = L.flat(18)
    L.cp(x + 1); L.en(x + 5, "K"); L.en(x + 7, "K"); L.en(x + 10); L.stairs(x + 12, 4)
    L.gap(4); L.plat(L.x - 3, L.x - 2, 10)
    x = L.flat(16)
    L.pipe(x + 3, 2, piranha=True); L.pipe(x + 8, 3, piranha=True); L.en(x + 13, "K")
    L.lava(11); L.mover(L.x - 7, 11, "W"); L.mover(L.x - 3, 12, "n")
    x = L.flat(14)
    L.blk(x + 3, 8, "M"); L.spikes(x + 7, x + 9); L.en(x + 11)
    L.stones([(3, 3), (2, 3), (2, 3), (3, 0)])
    x = L.flat(22)
    L.cp(x + 2)
    L.en(x + 5, "K"); L.en(x + 7, "K"); L.en(x + 9, "K"); L.pipe(x + 14, 3, piranha=True); L.spikes(x + 18, x + 19)
    L.gap(5); L.plat(L.x - 4, L.x - 2, 9)
    x = L.flat(14)
    L.stairs(x + 1, 5); L.stairs(x + 8, 5, up=False)
    L.lava(14); L.mover(L.x - 10, 11, "n"); L.mover(L.x - 4, 10, "W")
    x = L.flat(26)
    L.en(x + 4); L.en(x + 6); L.en(x + 8, "K"); L.en(x + 10, "K"); L.spikes(x + 14, x + 16)
    L.row(x + 18, x + 22, 8, "B"); L.blk(x + 20, 8, "M")
    L.finish()
    return L


# ================================================================= CHAPTER 2
def coin_room(L, rx, rows=((6, 9, 14), (9, 15, 20))):
    """Fills a bonus room with coin lines: (row, first column offset, count)."""
    for (y, a, n) in rows:
        L.coins(rx + a, y, n)


def lvl11():
    L = Lvl("WARP VALLEY", "jungle", 330)
    L.flat(12)
    x = L.flat(26)
    A = L.warp_pipe(x + 9, 2)                      # -> coin room
    L.coins(x + 15, 9, 4); L.en(x + 17); L.blk(x + 20, 8, "?"); L.blk(x + 22, 8, "M"); L.blk(x + 24, 8, "?")
    L.gap(4)
    x = L.flat(24)
    L.en(x + 5); L.en(x + 9, "K"); L.pipe(x + 14, 2); L.coins(x + 17, 8, 4)
    B = L.warp_pipe(x + 20, 3)                     # -> shortcut to C
    L.gap(4)
    x = L.flat(26)
    L.cp(x + 2); L.en(x + 6); L.en(x + 8); L.row(x + 12, x + 18, 8, "B"); L.blk(x + 14, 8, "?"); L.blk(x + 16, 8, "M")
    L.en(x + 21, "K")
    L.gap(5); L.plat(L.x - 4, L.x - 2, 10)
    x = L.flat(22)
    L.stairs(x + 2, 4); L.en(x + 10); L.pipe(x + 15, 2); L.en(x + 19)
    L.gap(4)
    x = L.flat(30)                                 # the shortcut lands here
    L.en(x + 3, "K")
    C = L.warp_pipe(x + 8, 2)
    L.en(x + 14); L.en(x + 16); L.blk(x + 20, 8, "?"); L.coins(x + 19, 6, 5)
    L.gap(4)
    x = L.flat(24)
    L.en(x + 5, "K"); L.en(x + 7); L.pipe(x + 12, 3); L.en(x + 17); L.spikes(x + 20, x + 21)
    L.gap(3)
    L.flat(10)
    L.finish()
    r1 = L.room()
    R1 = L.warp_pipe(r1 + 3, 2); coin_room(L, r1)
    L.blk(r1 + 12, 8, "M")
    L.link(A, R1)
    L.link(B, C)
    return L


def lvl12():
    L = Lvl("VINE RUN", "jungle", 340)
    L.flat(12)
    x = L.flat(24)
    L.en(x + 6); L.en(x + 10); L.pipe(x + 14, 2); L.blk(x + 18, 8, "?"); L.blk(x + 20, 8, "?")
    L.spring(x + 23)
    L.gap(6); L.plat(L.x - 4, L.x - 2, 9); L.coins(L.x - 4, 6, 3)
    x = L.flat(22)
    L.bat(x + 8, 7); L.en(x + 12, "K")
    A = L.warp_pipe(x + 16, 2)
    L.coins(x + 3, 9, 4)
    L.gap(4)
    x = L.flat(26)
    L.cp(x + 2); L.en(x + 6); L.en(x + 8); L.bat(x + 14, 8); L.row(x + 17, x + 22, 8, "B"); L.blk(x + 19, 8, "M")
    L.spring(x + 25)
    L.gap(6)
    x = L.island(8, 10); L.coins(x, 7, 8); L.star(x + 4, 6)
    L.gap(4)
    x = L.flat(28)
    L.en(x + 4, "K"); L.bat(x + 9, 7); L.pipe(x + 12, 3, piranha=True); L.en(x + 18); L.bat(x + 22, 8)
    L.gap(4)
    x = L.flat(22)
    L.stairs(x + 2, 4); L.spikes(x + 8, x + 9); L.en(x + 14); L.en(x + 16, "K"); L.blk(x + 19, 8, "?")
    L.gap(3)
    L.flat(10)
    L.finish()
    r1 = L.room()
    R1 = L.warp_pipe(r1 + 3, 2); coin_room(L, r1, ((5, 8, 15), (8, 10, 12), (10, 14, 8)))
    L.link(A, R1)
    return L


def lvl13():
    L = Lvl("BAT CAVE", "cave", 350)
    L.flat(12)
    x = L.flat(26)
    L.bat(x + 8, 7); L.en(x + 11); L.pipe(x + 15, 2, piranha=True); L.bat(x + 20, 8)
    L.blk(x + 22, 8, "?"); L.blk(x + 24, 8, "M")
    L.gap(4)
    x = L.flat(24)
    A = L.warp_pipe(x + 4, 3)                      # shortcut to B
    L.en(x + 9, "K"); L.bat(x + 12, 7); L.bat(x + 18, 8); L.coins(x + 14, 9, 4)
    L.gap(4)
    x = L.flat(8); L.raise_(x + 2, x + 5, 10); L.coins(x + 2, 8, 4); L.bat(x + 4, 6)
    L.gap(4)
    x = L.flat(30)
    L.cp(x + 2); L.en(x + 6); L.bat(x + 9, 7); L.en(x + 11, "K")
    L.row(x + 15, x + 21, 8, "B"); L.blk(x + 18, 8, "?"); L.blk(x + 16, 8, "M")
    L.bat(x + 24, 7); L.pipe(x + 27, 3, piranha=True)
    L.gap(4)
    x = L.flat(6); L.plat(x, x + 5, 9); L.bat(x + 3, 7)
    L.gap(4)
    x = L.flat(26)
    B = L.warp_pipe(x + 3, 2)                      # lands here
    L.en(x + 8); L.bat(x + 10, 7); L.bat(x + 13, 8); L.en(x + 15, "K"); L.stairs(x + 18, 3)
    C = L.warp_pipe(x + 23, 2)                     # -> star room
    L.gap(4)
    x = L.flat(24)
    L.en(x + 4); L.bat(x + 7, 7); L.en(x + 10, "K"); L.bat(x + 14, 8); L.blk(x + 17, 8, "?")
    L.spikes(x + 19, x + 20)
    L.gap(3)
    L.flat(10)
    L.finish()
    r1 = L.room()
    R1 = L.warp_pipe(r1 + 3, 2); coin_room(L, r1); L.star(r1 + 12, 7)
    L.link(A, B)
    L.link(C, R1)
    return L


def lvl14():
    L = Lvl("SPRING DUNES", "desert", 350)
    L.flat(12)
    x = L.flat(22)
    L.spikes(x + 6, x + 7); L.en(x + 10, "K"); L.blk(x + 14, 8, "?"); L.spring(x + 21)
    L.gap(6); L.arc(L.x - 5, 8, 4)
    x = L.flat(18)
    L.en(x + 4); L.en(x + 7); L.pipe(x + 11, 3); L.coins(x + 3, 9, 3)
    A = L.warp_pipe(x + 15, 2)
    L.gap(4)
    x = L.flat(14)
    L.cp(x + 1); L.spring(x + 4); L.plat(x + 3, x + 6, 6); L.coins(x + 3, 4, 4); L.star(x + 9, 8)
    L.en(x + 11)
    L.span(10, [(2, 11, "f"), (7, 11, "f")])
    x = L.flat(24)
    L.en(x + 5, "K"); L.en(x + 7); L.spikes(x + 11, x + 13); L.blk(x + 16, 8, "M"); L.spring(x + 23)
    L.gap(6); L.coins(L.x - 5, 6, 4)
    x = L.flat(16)
    B = L.warp_pipe(x + 3, 2)
    L.en(x + 8, "K"); L.en(x + 11); L.spikes(x + 13, x + 14)
    L.gap(4)
    x = L.flat(26)
    L.stairs(x + 2, 4); L.stairs(x + 8, 4, up=False); L.en(x + 14); L.en(x + 16, "K"); L.spikes(x + 20, x + 21)
    L.blk(x + 23, 8, "?")
    L.gap(3)
    L.flat(10)
    L.finish()
    r1 = L.room()
    R1 = L.warp_pipe(r1 + 3, 2); coin_room(L, r1)
    r2 = L.room()
    R2 = L.warp_pipe(r2 + 3, 2); coin_room(L, r2, ((7, 8, 16),)); L.blk(r2 + 12, 8, "M"); L.coins(r2 + 6, 4, 12)
    L.link(A, R1)
    L.link(B, R2)
    return L


def lvl15():
    L = Lvl("ICE STEPS", "snow", 360)
    L.flat(12)
    x = L.flat(20)
    L.en(x + 6); L.pipe(x + 10, 2); L.en(x + 14, "K"); L.blk(x + 17, 8, "?")
    L.span(5, [(2, 11, "f")])
    x = L.flat(14)
    L.en(x + 5); L.spring(x + 8); L.plat(x + 7, x + 10, 6); L.coins(x + 7, 4, 4)
    A = L.warp_pipe(x + 11, 2)
    L.span(11, [(2, 11, "f"), (5, 10, "f"), (8, 11, "f")])
    x = L.flat(22)
    L.cp(x + 1); L.en(x + 6); L.bat(x + 9, 7); L.en(x + 12, "K"); L.blk(x + 15, 8, "M"); L.coins(x + 17, 8, 4)
    L.gap(9); L.mover(L.x - 5, 12, "n")
    x = L.flat(18)
    L.en(x + 4, "K"); L.en(x + 6); L.stairs(x + 9, 4); L.spikes(x + 14, x + 15)
    L.gap(4); L.plat(L.x - 3, L.x - 2, 10)
    x = L.flat(12)
    B = L.warp_pipe(x + 4, 2)
    L.bat(x + 8, 7)
    L.span(11, [(2, 11, "f"), (5, 10, "f"), (8, 11, "f")])
    x = L.flat(26)
    L.en(x + 4); L.en(x + 6, "K"); L.bat(x + 11, 8); L.pipe(x + 14, 3, piranha=True)
    L.row(x + 18, x + 23, 8, "B"); L.blk(x + 20, 8, "?")
    L.gap(3)
    L.flat(10)
    L.finish()
    r1 = L.room()
    R1 = L.warp_pipe(r1 + 3, 2); coin_room(L, r1); L.star(r1 + 11, 7)
    r2 = L.room()
    R2 = L.warp_pipe(r2 + 3, 2); coin_room(L, r2, ((8, 8, 16),)); L.blk(r2 + 10, 8, "M")
    L.link(A, R1)
    L.link(B, R2)
    return L


def lvl16():
    L = Lvl("MOONWALK", "space", 340)
    L.flat(12)
    x = L.flat(22)
    L.en(x + 8); L.blk(x + 12, 8, "?"); L.blk(x + 14, 8, "M"); L.blk(x + 16, 8, "?"); L.coins(x + 11, 5, 7)
    L.gap(7)
    x = L.flat(14)
    L.cp(x + 1); L.en(x + 6, "K"); L.pipe(x + 10, 2)
    L.gap(7); L.arc(L.x - 6, 8, 5)
    x = L.island(8, 10); L.coins(x, 7, 8); L.blk(x + 3, 6, "?")
    L.gap(6)
    x = L.island(6, 9); L.en(x + 3, y=8)
    L.gap(6)
    x = L.flat(24)
    A = L.warp_pipe(x + 4, 2)
    L.en(x + 8); L.en(x + 10, "K"); L.stairs(x + 13, 4); L.star(x + 19, 8); L.coins(x + 18, 5, 5)
    L.gap(8)
    x = L.island(7, 11); L.coins(x, 8, 7)
    L.gap(7)
    x = L.flat(26)
    L.cp(x + 1); L.en(x + 5); L.en(x + 7, "K"); L.pipe(x + 11, 3, piranha=True); L.bat(x + 16, 6); L.en(x + 20)
    L.blk(x + 23, 8, "M")
    L.gap(4)
    L.flat(10)
    L.finish()
    r1 = L.room()
    R1 = L.warp_pipe(r1 + 3, 2); coin_room(L, r1, ((4, 8, 15), (7, 10, 12), (10, 8, 6)))
    L.link(A, R1)
    return L


def lvl17():
    L = Lvl("CRATER CRUSH", "space", 360)
    L.flat(12)
    x = L.flat(24)
    L.en(x + 6); L.crusher(x + 14, 6); L.crusher(x + 20, 6); L.blk(x + 10, 8, "?")
    L.gap(6)
    x = L.flat(20)
    L.cp(x + 1); L.en(x + 5, "K"); L.bat(x + 8, 7); L.crusher(x + 13, 6); L.coins(x + 11, 9, 5)
    A = L.warp_pipe(x + 17, 2)
    L.gap(7)
    x = L.island(6, 10); L.coins(x, 7, 6)
    L.gap(6)
    x = L.flat(26)
    L.en(x + 4); L.en(x + 6, "K"); L.crusher(x + 11, 6); L.crusher(x + 15, 5); L.bat(x + 19, 7)
    L.blk(x + 22, 8, "M")
    L.gap(6)
    x = L.flat(22)
    L.cp(x + 1); L.stairs(x + 3, 4); L.crusher(x + 10, 6); L.en(x + 13); L.bat(x + 16, 8)
    B = L.warp_pipe(x + 19, 2)
    L.gap(7)
    x = L.flat(26)
    L.en(x + 3, "K"); L.crusher(x + 8, 6); L.crusher(x + 12, 6); L.crusher(x + 16, 6); L.star(x + 22, 8)
    L.gap(4)
    L.flat(10)
    L.finish()
    r1 = L.room()
    R1 = L.warp_pipe(r1 + 3, 2); coin_room(L, r1)
    r2 = L.room()
    R2 = L.warp_pipe(r2 + 3, 2); coin_room(L, r2, ((6, 8, 16), (9, 8, 16))); L.blk(r2 + 18, 8, "M")
    L.link(A, R1)
    L.link(B, R2)
    return L


def lvl18():
    L = Lvl("MIDNIGHT BATS", "night", 370)
    L.flat(12)
    x = L.flat(24)
    L.bat(x + 6, 7); L.en(x + 9); L.bat(x + 13, 8); L.en(x + 15, "K"); L.pipe(x + 19, 2, piranha=True)
    L.blk(x + 22, 8, "M")
    L.gap(4)
    x = L.flat(22)
    L.cp(x + 1); L.bat(x + 5, 6); L.bat(x + 8, 8); L.en(x + 12); L.crusher(x + 15, 6); L.spring(x + 20)
    L.gap(6); L.coins(L.x - 5, 6, 4)
    x = L.island(8, 10); L.bat(x + 4, 7); L.blk(x + 3, 6, "?")
    L.gap(4)
    x = L.flat(26)
    A = L.warp_pipe(x + 3, 2)
    L.en(x + 7, "K"); L.bat(x + 10, 8); L.en(x + 12); L.bat(x + 15, 6); L.crusher(x + 18, 6); L.blk(x + 22, 8, "?")
    L.gap(5); L.plat(L.x - 4, L.x - 2, 9)
    x = L.flat(24)
    L.cp(x + 1); L.stairs(x + 3, 5); L.bat(x + 11, 7); L.en(x + 13, "K"); L.en(x + 15); L.bat(x + 18, 8)
    L.pipe(x + 21, 3, piranha=True)
    L.gap(4)
    x = L.flat(22)
    B = L.warp_pipe(x + 4, 3)
    L.en(x + 9); L.bat(x + 11, 7); L.crusher(x + 14, 6); L.en(x + 17, "K"); L.star(x + 19, 8)
    L.gap(3)
    L.flat(10)
    L.finish()
    r1 = L.room()
    R1 = L.warp_pipe(r1 + 3, 2); coin_room(L, r1); L.blk(r1 + 12, 8, "M")
    r2 = L.room()
    R2 = L.warp_pipe(r2 + 3, 2); coin_room(L, r2, ((8, 8, 16),)); L.star(r2 + 12, 7)
    L.link(A, R1)
    L.link(B, R2)
    return L


def lvl19():
    L = Lvl("LAVA FORGE", "castle", 400)
    L.flat(12)
    x = L.flat(18)
    L.en(x + 5, "K"); L.firebar(x + 11, 8); L.blk(x + 14, 8, "M")
    L.span(9, [(2, 11, "f"), (6, 10, "f")], lava=True)
    x = L.flat(14)
    L.cp(x + 1); L.en(x + 5); L.crusher(x + 9, 6); L.spikes(x + 12, x + 13)
    L.lava(10); L.mover(L.x - 6, 11, "n")
    x = L.flat(16)
    A = L.warp_pipe(x + 3, 2)
    L.en(x + 7, "K"); L.firebar(x + 11, 7); L.blk(x + 13, 8, "?")
    L.stones([(3, 2), (3, 2), (2, 0)])
    x = L.flat(20)
    L.cp(x + 1); L.bat(x + 6, 7); L.crusher(x + 9, 6); L.crusher(x + 14, 6); L.en(x + 17, "K")
    L.span(8, [(1, 11, "f"), (5, 11, "f")], lava=True)
    x = L.flat(14)
    L.firebar(x + 5, 8); L.firebar(x + 11, 6); L.blk(x + 8, 8, "M")
    L.lava(11); L.mover(L.x - 8, 11, "W")
    x = L.flat(22)
    L.cp(x + 1); L.en(x + 5, "K"); L.en(x + 7, "K"); L.spikes(x + 10, x + 12); L.crusher(x + 15, 6)
    B = L.warp_pipe(x + 19, 2)
    L.finish()
    r1 = L.room()
    R1 = L.warp_pipe(r1 + 3, 2); coin_room(L, r1); L.star(r1 + 12, 7)
    r2 = L.room()
    R2 = L.warp_pipe(r2 + 3, 2); coin_room(L, r2, ((8, 8, 16),)); L.blk(r2 + 12, 8, "M")
    L.link(A, R1)
    L.link(B, R2)
    return L


def lvl20():
    L = Lvl("KING'S RETURN", "castle", 440)
    L.flat(10)
    x = L.flat(20)
    L.en(x + 5, "K"); L.bat(x + 8, 7); L.crusher(x + 12, 6); L.blk(x + 16, 8, "M")
    L.span(7, [(2, 11, "f")], lava=True)
    x = L.flat(14)
    L.cp(x + 1); L.firebar(x + 6, 8); L.en(x + 10, "K"); L.spikes(x + 12, x + 13)
    L.lava(9); L.mover(L.x - 5, 11, "N")
    x = L.flat(16)
    A = L.warp_pipe(x + 3, 2)
    L.bat(x + 7, 8); L.en(x + 9, "K"); L.crusher(x + 12, 6); L.spring(x + 15)
    L.gap(6); L.plat(L.x - 4, L.x - 2, 9); L.coins(L.x - 4, 6, 3)
    x = L.flat(20)
    L.cp(x + 1); L.firebar(x + 5, 7); L.firebar(x + 11, 8); L.en(x + 8); L.en(x + 14, "K"); L.star(x + 17, 8)
    L.stones([(3, 3), (2, 3), (2, 3), (3, 0)])
    x = L.flat(18)
    L.crusher(x + 4, 6); L.crusher(x + 9, 6); L.bat(x + 13, 7); L.en(x + 14, "K"); L.pipe(x + 16, 3, piranha=True)
    L.span(11, [(2, 11, "f"), (5, 10, "f"), (9, 12, "W")], lava=True)
    x = L.flat(20)
    L.cp(x + 1); L.stairs(x + 3, 5); L.firebar(x + 11, 8); L.en(x + 13, "K"); L.en(x + 15, "K"); L.spikes(x + 17, x + 18)
    B = L.warp_pipe(x + 21, 2)
    L.gap(5); L.plat(L.x - 4, L.x - 2, 9)
    x = L.flat(26)
    L.en(x + 4, "K"); L.bat(x + 7, 7); L.crusher(x + 10, 6); L.crusher(x + 14, 5); L.firebar(x + 18, 8)
    L.en(x + 20); L.en(x + 22, "K"); L.row(x + 23, x + 25, 8, "B"); L.blk(x + 24, 8, "M")
    L.finish()
    r1 = L.room()
    R1 = L.warp_pipe(r1 + 3, 2); coin_room(L, r1); L.blk(r1 + 12, 8, "M"); L.star(r1 + 14, 8)
    r2 = L.room()
    R2 = L.warp_pipe(r2 + 3, 2); coin_room(L, r2, ((6, 8, 16), (9, 8, 16)))
    L.link(A, R1)
    L.link(B, R2)
    return L


THEMES = {
    "grass": dict(sky_top=(92, 148, 252), sky_bot=(176, 224, 255), music="grass", gdecor=["hill_l", "hill_s", "bush_s", "bush_l"], sdecor=["cloud_s", "cloud_l"], cloud=(1, 1, 1), fx="", far=0.15, near=0.35),
    "desert": dict(sky_top=(250, 170, 100), sky_bot=(255, 230, 170), music="desert", gdecor=["cactus", "palm", "cactus"], sdecor=["cloud_s"], cloud=(1, .95, .85), fx="", far=0.12, near=0.3),
    "cave": dict(sky_top=(8, 8, 24), sky_bot=(30, 32, 66), music="cave", gdecor=["crystal", "crystal"], sdecor=[], cloud=(1, 1, 1), fx="dust", far=0.15, near=0.35),
    "snow": dict(sky_top=(140, 185, 235), sky_bot=(235, 245, 255), music="snow", gdecor=["pine", "pine", "bush_s"], sdecor=["cloud_s", "cloud_l"], cloud=(.95, .98, 1), fx="snow", far=0.12, near=0.3),
    "night": dict(sky_top=(8, 8, 44), sky_bot=(70, 44, 120), music="night", gdecor=["bush_s", "bush_l", "hill_s"], sdecor=["cloud_s"], cloud=(.45, .45, .7), fx="", far=0.12, near=0.3),
    "sky": dict(sky_top=(56, 150, 255), sky_bot=(200, 240, 255), music="sky", gdecor=[], sdecor=["cloud_s", "cloud_l"], cloud=(1, 1, 1), fx="", far=0.1, near=0.25),
    "castle": dict(sky_top=(24, 0, 10), sky_bot=(110, 26, 24), music="castle", gdecor=["torch", "torch"], sdecor=[], cloud=(1, 1, 1), fx="embers", far=0.15, near=0.35),
    "jungle": dict(sky_top=(40, 140, 130), sky_bot=(176, 232, 190), music="grass", gdecor=["fern", "bush_l", "fern", "palm", "bush_s"], sdecor=["cloud_s"], cloud=(0.9, 1, 0.95), fx="", far=0.14, near=0.34),
    "space": dict(sky_top=(4, 2, 22), sky_bot=(44, 26, 96), music="sky", gdecor=[], sdecor=[], cloud=(1, 1, 1), fx="dust", far=0.08, near=0.22, grav=0.55),
}


def fmt_col(t):
    return "Color(%.3f, %.3f, %.3f)" % tuple(v / 255 for v in t)


def main():
    levels = [f() for f in (lvl1, lvl2, lvl3, lvl4, lvl5, lvl6, lvl7, lvl8, lvl9, lvl10,
                              lvl11, lvl12, lvl13, lvl14, lvl15, lvl16, lvl17, lvl18, lvl19, lvl20)]
    out = ["extends RefCounted", "# AUTO-GENERATED by tools/gen_levels.py - edit the generator, not this file", "", "const THEMES = {"]
    for k, t in THEMES.items():
        out.append('\t"%s": {"sky_top": %s, "sky_bot": %s, "music": "%s", "gdecor": %s, "sdecor": %s, "cloud": Color(%s, %s, %s), "fx": "%s", "far": %s, "near": %s, "grav": %s},' % (
            k, fmt_col(t["sky_top"]), fmt_col(t["sky_bot"]), t["music"],
            str(t["gdecor"]).replace("'", '"'), str(t["sdecor"]).replace("'", '"'),
            t["cloud"][0], t["cloud"][1], t["cloud"][2], t["fx"], t["far"], t["near"], t.get("grav", 1.0)))
    out.append("}")
    out.append("")
    out.append("const DATA = [")
    for L in levels:
        rows = L.rows()
        assert all(len(r) == len(rows[0]) for r in rows)
        main_w = L.main_w if L.main_w else L.w
        out.append('\t{"name": "%s", "theme": "%s", "time": %d, "main_cols": %d, "warps": %s, "rows": [' % (L.name, L.theme, L.time, main_w, str(L.warps)))
        for r in rows:
            out.append('\t\t"%s",' % r)
        out.append("\t]},")
    out.append("]")
    path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "scripts", "levels_data.gd"))
    with open(path, "w") as f:
        f.write("\n".join(out) + "\n")
    for i, L in enumerate(levels):
        gaps, run, mx = [], 0, 0
        r12 = L.rows()[SURF]
        for ch in r12:
            if ch in "GXTtLl-":
                mx = max(mx, run); run = 0
            else:
                run += 1
        print(i + 1, L.name, "width", L.w, "max floor gap", mx)


if __name__ == "__main__":
    main()
