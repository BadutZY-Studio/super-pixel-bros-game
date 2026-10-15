#!/usr/bin/env python3
"""Chapter 2 assets for Super Pixel Bros (requires Pillow).

Adds only NEW files, nothing from chapter 1 is overwritten:
  sprites: bat, star, spring, crusher, pipe_arrow, fern
  themes : jungle, space  (tiles + far/near backgrounds, space also gets a star sky)

Run:  python3 tools/gen_assets_ch2.py
"""
import os, math, random
from PIL import Image, ImageDraw

import gen_assets as G   # re-use the helpers and palettes of chapter 1 (importing does not regenerate anything)

c = G.c
new = G.new
outline = G.outline
sheet = G.sheet
save = G.save


# ------------------------------------------------------------------ SPRITES
def bat(f):
    """16x16 flying enemy, f: 0 wings up, 1 wings down, 2 squashed."""
    im = new(16, 16)
    d = ImageDraw.Draw(im)
    body, dark, wing, eye = c(110, 60, 170), c(70, 34, 120), c(150, 96, 210), c(255, 240, 90)
    if f == 2:
        d.ellipse((3, 8, 12, 14), fill=body)
        d.line((0, 12, 3, 12), fill=wing)
        d.line((12, 12, 15, 12), fill=wing)
        d.point([(5, 10), (10, 10)], fill=eye)
        return outline(im)
    if f == 0:
        d.polygon([(7, 7), (0, 1), (1, 8), (3, 6), (5, 9)], fill=wing)
        d.polygon([(8, 7), (15, 1), (14, 8), (12, 6), (10, 9)], fill=wing)
        d.line((1, 2, 5, 6), fill=dark)
        d.line((14, 2, 10, 6), fill=dark)
    else:
        d.polygon([(7, 8), (0, 13), (2, 8), (4, 11), (6, 10)], fill=wing)
        d.polygon([(8, 8), (15, 13), (13, 8), (11, 11), (9, 10)], fill=wing)
        d.line((1, 12, 5, 9), fill=dark)
        d.line((14, 12, 10, 9), fill=dark)
    d.ellipse((4, 4, 11, 12), fill=body)
    d.polygon([(4, 5), (5, 1), (7, 4)], fill=body)
    d.polygon([(11, 5), (10, 1), (8, 4)], fill=body)
    d.rectangle((5, 6, 6, 8), fill=eye)
    d.rectangle((9, 6, 10, 8), fill=eye)
    d.point([(6, 7), (9, 7)], fill=c(30, 10, 30))
    d.point([(7, 11), (8, 11)], fill=c(255, 255, 255))
    return outline(im)


def star(f):
    im = new(16, 16)
    d = ImageDraw.Draw(im)
    cx, cy = 7.5, 8.2
    pts = []
    for i in range(10):
        r = 7.4 if i % 2 == 0 else 3.2
        a = -math.pi / 2 + i * math.pi / 5
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    cols = [(c(255, 230, 40), c(255, 250, 170)), (c(255, 170, 30), c(255, 235, 120))]
    d.polygon(pts, fill=cols[f % 2][0])
    d.polygon([(cx, cy - 4), (cx + 2, cy - 1), (cx, cy + 1), (cx - 2, cy - 1)], fill=cols[f % 2][1])
    d.rectangle((5, 7, 5, 9), fill=c(40, 24, 8))
    d.rectangle((9, 7, 9, 9), fill=c(40, 24, 8))
    return outline(im)


def spring(f):
    """16x16 spring, f: 0 rest, 1 squashed, 2 stretched."""
    im = new(16, 16)
    d = ImageDraw.Draw(im)
    pad_y = {0: 3, 1: 8, 2: 0}[f]
    base_y = 15
    red, redl, steel, steeld = c(224, 50, 50), c(255, 130, 110), c(200, 205, 225), c(120, 126, 156)
    # coil
    y0, y1 = pad_y + 4, base_y - 2
    n = 4 if f != 1 else 3
    for i in range(n + 1):
        y = y0 + int((y1 - y0) * i / n)
        d.line((3, y, 12, y), fill=steel if i % 2 == 0 else steeld, width=1)
        if i < n:
            y2 = y0 + int((y1 - y0) * (i + 0.5) / n)
            d.line((3, y, 12, y2), fill=steeld)
            d.line((12, y, 3, y2), fill=steel)
    # pad + base
    d.rectangle((1, pad_y, 14, pad_y + 3), fill=red)
    d.rectangle((1, pad_y, 14, pad_y), fill=redl)
    d.rectangle((2, base_y - 1, 13, base_y), fill=steeld)
    return outline(im)


def crusher(f):
    """24x24 spiked stone block, f: 0 calm, 1 angry."""
    im = new(24, 24)
    d = ImageDraw.Draw(im)
    st, stl, std = c(130, 126, 150), c(176, 172, 196), c(78, 74, 100)
    d.rectangle((2, 2, 21, 21), fill=st)
    d.rectangle((2, 2, 21, 3), fill=stl)
    d.rectangle((2, 2, 3, 21), fill=stl)
    d.rectangle((20, 2, 21, 21), fill=std)
    d.rectangle((2, 20, 21, 21), fill=std)
    for p in ((4, 4), (19, 4), (4, 19), (19, 19)):
        d.rectangle((p[0], p[1], p[0] + 1, p[1] + 1), fill=std)
    # spikes on the underside + sides
    for x in (5, 11, 17):
        d.polygon([(x, 21), (x + 2, 23), (x + 4, 21)], fill=c(220, 224, 236))
    for y in (5, 11, 17):
        d.polygon([(2, y), (0, y + 2), (2, y + 4)], fill=c(220, 224, 236))
        d.polygon([(21, y), (23, y + 2), (21, y + 4)], fill=c(220, 224, 236))
    # face
    if f == 0:
        d.rectangle((6, 8, 9, 11), fill=c(255, 255, 255))
        d.rectangle((14, 8, 17, 11), fill=c(255, 255, 255))
        d.rectangle((7, 9, 8, 11), fill=c(20, 10, 30))
        d.rectangle((15, 9, 16, 11), fill=c(20, 10, 30))
        d.line((8, 16, 15, 16), fill=c(40, 30, 50))
    else:
        d.rectangle((6, 9, 9, 12), fill=c(255, 80, 60))
        d.rectangle((14, 9, 17, 12), fill=c(255, 80, 60))
        d.line((5, 6, 10, 9), fill=c(30, 20, 40))
        d.line((18, 6, 13, 9), fill=c(30, 20, 40))
        d.rectangle((7, 10, 8, 12), fill=c(20, 10, 30))
        d.rectangle((15, 10, 16, 12), fill=c(20, 10, 30))
        d.polygon([(7, 15), (16, 15), (11, 19)], fill=c(40, 10, 20))
        d.polygon([(8, 15), (10, 15), (9, 17)], fill=c(255, 255, 255))
        d.polygon([(13, 15), (15, 15), (14, 17)], fill=c(255, 255, 255))
    return outline(im)


def pipe_arrow(f):
    """12x10 bobbing 'enter here' arrow."""
    im = new(12, 10)
    d = ImageDraw.Draw(im)
    col = (c(255, 230, 60), c(255, 255, 200))[f % 2]
    d.rectangle((4, 0, 7, 4), fill=col)
    d.polygon([(0, 4), (11, 4), (5, 9)], fill=col)
    d.rectangle((5, 1, 6, 3), fill=c(255, 255, 255, 160))
    return outline(im)


def fern():
    """Jungle ground decor 24x24."""
    im = new(24, 24)
    d = ImageDraw.Draw(im)
    g1, g2 = c(30, 150, 70), c(60, 200, 100)
    for ang, ln in ((-70, 18), (-45, 20), (-20, 17), (15, 15), (-100, 17), (-125, 19), (-155, 16), (-180, 13)):
        a = math.radians(ang)
        x, y = 12, 23
        pts = [(x, y), (x + math.cos(a) * ln * 0.5 - 2, y + math.sin(a) * ln * 0.5), (x + math.cos(a) * ln, y + math.sin(a) * ln),
               (x + math.cos(a) * ln * 0.5 + 2, y + math.sin(a) * ln * 0.5)]
        d.polygon(pts, fill=g1)
        d.line((x, y, pts[2][0], pts[2][1]), fill=g2)
    return outline(im)


def make_sprites():
    save(sheet([bat(0), bat(1), bat(2)]), "sprites", "bat.png")
    save(sheet([star(0), star(1)]), "sprites", "star.png")
    save(sheet([spring(0), spring(1), spring(2)]), "sprites", "spring.png")
    save(sheet([crusher(0), crusher(1)]), "sprites", "crusher.png")
    save(sheet([pipe_arrow(0), pipe_arrow(1)]), "sprites", "pipe_arrow.png")
    save(fern(), "sprites", "fern.png")


# ------------------------------------------------------------------ NEW THEME TILES / BACKGROUNDS
THEMES2 = {
    "jungle": dict(top=(60, 170, 70), top_d=(24, 110, 50), fill=(120, 84, 50), fill_d=(86, 56, 32), fill_l=(160, 116, 70),
                   brick=(170, 110, 40), brick_l=(220, 168, 80), brick_d=(90, 56, 20), hard=(130, 150, 110), pipe=(200, 160, 40)),
    "space": dict(top=(190, 196, 220), top_d=(120, 126, 160), fill=(110, 116, 150), fill_d=(76, 80, 112), fill_l=(150, 156, 190),
                  brick=(120, 90, 180), brick_l=(170, 140, 230), brick_d=(60, 40, 110), hard=(150, 160, 190), pipe=(230, 90, 150)),
}

BG2 = {
    "jungle": dict(far=(40, 120, 100), near=(20, 90, 60)),
    "space": dict(far=(60, 50, 120), near=(80, 84, 120)),
}


def make_tiles():
    for name, t in THEMES2.items():
        tiles = [G.t_ground(t, True), G.t_ground(t, False), G.t_brick(t), G.t_hard(t), G.t_question(0, True)]
        cap, body = G.t_pipe(t)
        tiles += [cap.crop((0, 0, 16, 16)), cap.crop((16, 0, 32, 16)), body.crop((0, 0, 16, 16)), body.crop((16, 0, 32, 16))]
        tiles += [G.t_lava(True), G.t_lava(False)]
        tiles += [G.t_question(0), G.t_question(1), G.t_question(2)]
        tiles += [G.t_spikes(), G.t_platform(t)]
        save(sheet(tiles), "tiles", f"tiles_{name}.png")


def make_bg():
    W = 256
    for name, b in BG2.items():
        far = new(W, 128)
        d = ImageDraw.Draw(far)
        if name == "jungle":
            # layered tree canopies
            rnd = random.Random(5)
            for x in range(-10, W + 10, 22):
                h = 40 + rnd.randrange(60)
                d.rectangle((x + 8, 128 - h, x + 11, 127), fill=b["far"][0:3] + (255,))
                G.blob(d, [(x + 10, 128 - h, 14), (x + 2, 128 - h + 6, 10), (x + 18, 128 - h + 8, 11)], b["far"] + (255,))
        else:
            # big planet + crater ridge
            d.ellipse((150, 16, 230, 96), fill=(120, 100, 190, 255))
            d.ellipse((160, 28, 200, 56), fill=(150, 130, 220, 255))
            d.arc((128, 40, 252, 80), 190, 350, fill=(220, 200, 255, 255), width=2)
            ys = G.ridge(W, 128, 118, 50, 17)
            for x, y in enumerate(ys):
                d.line((x, y, x, 127), fill=b["far"] + (255,))
        save(far, "bg", f"bg_{name}_far.png")
        near = new(W, 72)
        d = ImageDraw.Draw(near)
        if name == "jungle":
            ys = G.ridge(W, 72, 68, 40, 31, ((2, 1.0), (5, 0.6), (11, 0.4)))
            for x, y in enumerate(ys):
                d.line((x, y, x, 71), fill=b["near"] + (255,))
            for x in range(8, W, 36):
                d.line((x, 0, x, 40 + x % 20), fill=(30, 130, 70, 255), width=1)
                d.ellipse((x - 2, 40 + x % 20, x + 2, 44 + x % 20), fill=(60, 190, 90, 255))
        else:
            ys = G.ridge(W, 72, 66, 36, 9, ((3, 1.0), (7, 0.5), (13, 0.3)))
            for x, y in enumerate(ys):
                d.line((x, y, x, 71), fill=b["near"] + (255,))
            rnd = random.Random(2)
            for _ in range(7):
                cx, cy, r = rnd.randrange(8, W - 8), rnd.randrange(52, 68), rnd.randrange(3, 6)
                d.ellipse((cx - r, cy - r // 2, cx + r, cy + r // 2), fill=(56, 60, 92, 255))
        save(near, "bg", f"bg_{name}_near.png")
    # star field for space
    rnd = random.Random(77)
    st = new(W, 180)
    d = ImageDraw.Draw(st)
    for _ in range(110):
        x, y = rnd.randrange(W), rnd.randrange(160)
        a = rnd.choice([110, 180, 255])
        d.point((x, y), fill=(255, 255, 255, a))
        if a == 255 and rnd.random() < 0.3:
            d.point((x + 1, y), fill=(255, 255, 255, 140))
            d.point((x, y + 1), fill=(255, 255, 255, 140))
    save(st, "bg", "bg_space_sky.png")


if __name__ == "__main__":
    make_sprites()
    make_tiles()
    make_bg()
    print("chapter 2 assets ok")
