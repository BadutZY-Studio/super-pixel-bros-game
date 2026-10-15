#!/usr/bin/env python3
"""Generates all pixel-art assets for Super Pixel Bros (requires Pillow)."""
import os, math, random
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
A = os.path.join(ROOT, "assets")
OUTLINE = (24, 16, 32, 255)


def new(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def outline(img, col=OUTLINE):
    w, h = img.size
    src = img.copy().load()
    o = img.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] > 0:
                        o[x, y] = col
                        break
    return img


def sheet(frames):
    w, h = frames[0].size
    s = new(w * len(frames), h)
    for i, f in enumerate(frames):
        s.paste(f, (i * w, 0))
    return s


def save(img, *path):
    p = os.path.join(A, *path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    img.save(p)


def c(r, g, b, a=255):
    return (r, g, b, a)


# ------------------------------------------------------------------ PLAYER
HEAD = [
    "....RRRRR.......",
    "...RRRRRRRRR....",
    "...NNNSSESS.....",
    "..NSNSSSESSSS...",
    "..NSNNSSSESSSS..",
    "..NNSSSSNNNN....",
    "....SSSSSSS.....",
]
TORSO = [
    "...RRRBRRR......",
    "..RRRRBRRBRRR...",
    "..RRRRBBBBRRR...",
    "..WWRBYBBYBWW...",
    "..WWBBBBBBBBWW..",
    "..WBBBBBBBBBW...",
]
TORSO_JUMP = [
    "..WRRRBRRR......",
    ".WWRRRBRRBRRW...",
    ".WWRRBBBBRRWW...",
    "..RRBYBBYBR.....",
    "...BBBBBBBB.....",
    "..BBBBBBBBBB....",
]
STAND = ("...BBB..BBB.....", ["..OOO....OOO....", ".OOOO....OOOO..."])
LEGS = {
    "idle": STAND,
    "run1": ("..BBB....BBB....", [".OOO......OOO...", "OOOO.....OOOO..."]),
    "run2": ("...BBBBBBB......", ["...OOOOOOO......", "...OOOOOOO......"]),
    "run3": ("....BB..BBB.....", ["...OOO...OOOO...", "..OOO....OOOO..."]),
    "jump": ("..BBB....BBBB...", ["OOOO.....OOOO...", "OOO.......OOO...."]),
    "skid": ("...BB....BB.....", ["..OOO.....OO....", ".OOOO....OOOO..."]),
    "die": ("..BBB....BBBB...", ["OOOO.....OOOO...", "OOO.......OOO...."]),
}
PAL = {
    "R": c(224, 36, 36), "W": c(250, 250, 250), "B": c(52, 84, 224), "Y": c(255, 220, 60),
    "N": c(110, 60, 20), "S": c(255, 204, 156), "E": c(20, 20, 20), "O": c(140, 80, 30),
}
PAL_FIRE = dict(PAL, R=c(245, 245, 245), B=c(224, 36, 36), W=c(245, 245, 245))


def pad(s):
    return s.ljust(16, ".")[:16]


def player_frame(pose, big, pal):
    head = list(HEAD)
    torso = TORSO_JUMP if pose in ("jump", "die") else TORSO
    blue, shoes = LEGS[pose]
    if big:
        head = head + [HEAD[3], HEAD[4]]
        head = [head[i] for i in (0, 1, 2, 3, 7, 4, 8, 5, 6)]
        torso = [torso[i] for i in (0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 5)]
        legs = [STAND[0]] * 4 + [blue] * 5 + shoes
    else:
        legs = [blue] + shoes
    rows = [pad(r) for r in head + torso + legs]
    img = new(16, len(rows))
    px = img.load()
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in pal:
                px[x, y] = pal[ch]
    return outline(img)


def make_player():
    poses = ["idle", "run1", "run2", "run3", "jump", "skid", "die"]
    for name, big, pal in (("small", False, PAL), ("big", True, PAL), ("fire", True, PAL_FIRE)):
        save(sheet([player_frame(p, big, pal) for p in poses]), "sprites", f"player_{name}.png")


# ------------------------------------------------------------------ ENEMIES
def goomba(f):
    im = new(16, 16)
    d = ImageDraw.Draw(im)
    brown, light, tan, blk = c(168, 92, 40), c(204, 128, 64), c(244, 208, 160), c(40, 24, 16)
    if f in (0, 1):
        d.ellipse((1, 0, 14, 11), fill=brown)
        d.ellipse((3, 1, 9, 5), fill=light)
        d.rectangle((4, 9, 11, 12), fill=tan)
        if f == 0:
            d.ellipse((0, 11, 6, 15), fill=blk)
            d.ellipse((9, 10, 15, 14), fill=blk)
        else:
            d.ellipse((0, 10, 6, 14), fill=blk)
            d.ellipse((9, 11, 15, 15), fill=blk)
        d.rectangle((3, 5, 6, 8), fill=(255, 255, 255, 255))
        d.rectangle((9, 5, 12, 8), fill=(255, 255, 255, 255))
        d.point([(5, 7), (6, 7), (9, 7), (10, 7)], fill=blk)
        d.line((3, 3, 7, 5), fill=blk)
        d.line((12, 3, 8, 5), fill=blk)
    else:
        d.ellipse((1, 8, 14, 15), fill=brown)
        d.rectangle((3, 12, 12, 14), fill=tan)
        d.line((4, 10, 6, 10), fill=blk)
        d.line((9, 10, 11, 10), fill=blk)
        d.rectangle((0, 14, 4, 15), fill=blk)
        d.rectangle((11, 14, 15, 15), fill=blk)
    return outline(im)


def koopa(f):
    im = new(16, 24)
    d = ImageDraw.Draw(im)
    g, gl, y, o = c(40, 168, 60), c(120, 228, 110), c(250, 220, 90), c(240, 140, 40)
    d.ellipse((5, 9, 15, 21), fill=g)
    d.ellipse((7, 11, 13, 17), fill=gl)
    d.rectangle((7, 19, 13, 21), fill=c(250, 240, 200))
    d.ellipse((0, 0, 8, 9), fill=y)
    d.rectangle((2, 7, 7, 12), fill=y)
    d.rectangle((0, 5, 2, 7), fill=o)
    d.rectangle((3, 2, 5, 4), fill=(255, 255, 255, 255))
    d.point((3, 3), fill=(0, 0, 0, 255))
    if f == 0:
        d.ellipse((1, 20, 7, 23), fill=o)
        d.ellipse((9, 21, 15, 23), fill=o)
    else:
        d.ellipse((3, 21, 9, 23), fill=o)
        d.ellipse((8, 20, 14, 23), fill=o)
    return outline(im)


def shell(f):
    im = new(16, 16)
    d = ImageDraw.Draw(im)
    g, gl, cr = c(40, 168, 60), c(120, 228, 110), c(250, 240, 200)
    d.ellipse((1, 3, 14, 14), fill=g)
    d.rectangle((3, 11, 12, 13), fill=cr)
    if f == 0:
        d.ellipse((5, 5, 10, 10), fill=gl)
    else:
        off = [-3, 0, 3][f - 1]
        d.rectangle((7 + off, 4, 8 + off, 11), fill=gl)
        d.rectangle((3, 7, 12, 8), fill=gl)
    return outline(im)


def piranha(f):
    im = new(16, 24)
    d = ImageDraw.Draw(im)
    red, wh, gr = c(224, 40, 40), c(255, 255, 255), c(40, 168, 60)
    d.rectangle((6, 14, 9, 23), fill=gr)
    d.polygon([(9, 18), (15, 14), (15, 20)], fill=gr)
    d.ellipse((0, 0, 15, 15), fill=red)
    for p in ((3, 3), (11, 3), (7, 9)):
        d.ellipse((p[0], p[1], p[0] + 3, p[1] + 3), fill=wh)
    if f == 0:
        d.line((1, 8, 14, 8), fill=wh)
    else:
        d.polygon([(0, 7), (15, 7), (8, 14)], fill=c(40, 0, 20))
        d.polygon([(2, 7), (4, 7), (3, 10)], fill=wh)
        d.polygon([(11, 7), (13, 7), (12, 10)], fill=wh)
    return outline(im)


def make_enemies():
    save(sheet([goomba(i) for i in range(3)]), "sprites", "goomba.png")
    save(sheet([koopa(i) for i in range(2)]), "sprites", "koopa.png")
    save(sheet([shell(i) for i in range(4)]), "sprites", "shell.png")
    save(sheet([piranha(i) for i in range(2)]), "sprites", "piranha.png")


# ------------------------------------------------------------------ ITEMS
def coin(f):
    im = new(16, 16)
    d = ImageDraw.Draw(im)
    w = [10, 6, 2, 6][f]
    x0, x1 = 8 - w // 2, 7 + w // 2
    d.ellipse((x0, 1, x1, 14), fill=c(255, 210, 40))
    if w >= 6:
        d.rectangle((7, 4, 8, 11), fill=c(255, 245, 150))
    return outline(im)


def mushroom():
    im = new(16, 16)
    d = ImageDraw.Draw(im)
    d.rectangle((4, 9, 11, 15), fill=c(250, 225, 180))
    d.ellipse((0, 0, 15, 12), fill=c(224, 40, 40))
    d.rectangle((0, 8, 15, 10), fill=c(224, 40, 40))
    for p in ((2, 3, 5, 6), (10, 3, 13, 6), (6, 1, 9, 4)):
        d.ellipse(p, fill=(255, 255, 255, 255))
    d.point([(6, 12), (9, 12)], fill=(30, 20, 20, 255))
    return outline(im)


def flower():
    im = new(16, 16)
    d = ImageDraw.Draw(im)
    gr = c(40, 168, 60)
    d.rectangle((7, 8, 8, 15), fill=gr)
    d.polygon([(8, 12), (14, 9), (14, 13)], fill=gr)
    d.polygon([(7, 12), (1, 9), (1, 13)], fill=gr)
    for p in ((1, 4), (10, 4), (5, 0), (5, 7)):
        d.ellipse((p[0], p[1], p[0] + 4, p[1] + 4), fill=c(255, 120, 30))
    d.ellipse((4, 3, 11, 10), fill=c(255, 70, 40))
    d.ellipse((6, 5, 9, 8), fill=c(255, 230, 80))
    return outline(im)


def fireball(f):
    im = new(8, 8)
    d = ImageDraw.Draw(im)
    d.ellipse((0, 0, 7, 7), fill=c(255, 110, 20))
    d.ellipse((2, 2, 5, 5), fill=c(255, 230, 90))
    if f == 0:
        d.point((1, 1), fill=c(255, 255, 220))
    else:
        d.point((6, 6), fill=c(255, 255, 220))
    return outline(im)


def flag_pennant():
    im = new(16, 16)
    d = ImageDraw.Draw(im)
    d.polygon([(15, 1), (0, 8), (15, 15)], fill=c(250, 250, 250))
    d.ellipse((8, 5, 12, 10), fill=c(224, 40, 40))
    return outline(im)


def flag_ball():
    im = new(8, 8)
    d = ImageDraw.Draw(im)
    d.ellipse((0, 0, 7, 7), fill=c(255, 210, 40))
    d.point((2, 2), fill=c(255, 250, 200))
    return outline(im)


def checkpoint():
    frames = []
    for col in (c(150, 150, 160), c(255, 210, 40)):
        im = new(16, 32)
        d = ImageDraw.Draw(im)
        d.rectangle((7, 2, 8, 31), fill=c(200, 200, 210))
        d.polygon([(9, 3), (9, 13), (15, 8)], fill=col)
        d.ellipse((5, 0, 10, 4), fill=c(255, 210, 40))
        frames.append(outline(im))
    return sheet(frames)


def castle():
    im = new(80, 80)
    d = ImageDraw.Draw(im)
    st, stl, std = c(150, 140, 150), c(190, 180, 190), c(100, 92, 104)
    d.rectangle((8, 30, 71, 79), fill=st)
    for y in range(32, 80, 8):
        d.line((8, y, 71, y), fill=std)
        for x in range(8 + (y // 8 % 2) * 4, 72, 8):
            d.line((x, y, x, y + 7), fill=std)
    for x in range(8, 72, 12):
        d.rectangle((x, 22, x + 7, 30), fill=st)
    d.rectangle((26, 4, 53, 30), fill=stl)
    for x in range(26, 54, 8):
        d.rectangle((x, 0, x + 4, 4), fill=stl)
    d.rectangle((32, 12, 37, 20), fill=c(30, 20, 40))
    d.rectangle((44, 12, 49, 20), fill=c(30, 20, 40))
    d.rectangle((30, 50, 49, 79), fill=c(30, 20, 40))
    d.ellipse((30, 42, 49, 58), fill=c(30, 20, 40))
    d.rectangle((14, 40, 18, 48), fill=c(30, 20, 40))
    d.rectangle((61, 40, 65, 48), fill=c(30, 20, 40))
    return outline(im)


def make_items():
    save(sheet([coin(i) for i in range(4)]), "sprites", "coin.png")
    save(mushroom(), "sprites", "mushroom.png")
    save(flower(), "sprites", "flower.png")
    save(sheet([fireball(0), fireball(1)]), "sprites", "fireball.png")
    save(flag_pennant(), "sprites", "flag.png")
    save(flag_ball(), "sprites", "flag_ball.png")
    save(checkpoint(), "sprites", "checkpoint.png")
    save(castle(), "sprites", "castle.png")
    # moving platform
    im = new(48, 10)
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 47, 7), fill=c(200, 140, 70))
    d.rectangle((0, 0, 47, 2), fill=c(240, 190, 110))
    d.rectangle((0, 6, 47, 7), fill=c(130, 80, 40))
    for x in (4, 22, 40):
        d.point((x, 4), fill=c(90, 50, 30))
    save(outline(im), "sprites", "platform.png")


# ------------------------------------------------------------------ DECOR
def blob(draw, circles, fill):
    for (x, y, r) in circles:
        draw.ellipse((x - r, y - r, x + r, y + r), fill=fill)


def decor():
    im = new(32, 16); d = ImageDraw.Draw(im)
    blob(d, [(9, 10, 5), (16, 7, 6), (23, 10, 5)], c(255, 255, 255)); d.rectangle((6, 10, 26, 14), fill=c(255, 255, 255))
    save(outline(im, c(190, 215, 240, 255)), "sprites", "cloud_s.png")
    im = new(48, 24); d = ImageDraw.Draw(im)
    blob(d, [(11, 15, 7), (21, 10, 9), (32, 11, 8), (39, 16, 6)], c(255, 255, 255)); d.rectangle((8, 15, 40, 21), fill=c(255, 255, 255))
    save(outline(im, c(190, 215, 240, 255)), "sprites", "cloud_l.png")
    for name, w in (("bush_s", 32), ("bush_l", 48)):
        im = new(w, 16); d = ImageDraw.Draw(im)
        n = w // 12
        blob(d, [(8 + i * 10, 9 if i % 2 == 0 else 7, 6) for i in range(n + 1)], c(60, 180, 70))
        d.rectangle((2, 10, w - 6, 15), fill=c(60, 180, 70))
        save(outline(im, c(20, 90, 40, 255)), "sprites", f"{name}.png")
    for name, w, h in (("hill_l", 80, 40), ("hill_s", 48, 24)):
        im = new(w, h); d = ImageDraw.Draw(im)
        d.ellipse((0, 4, w - 1, h * 2 - 4), fill=c(70, 190, 80))
        d.ellipse((w // 4, h // 4, w // 2, h // 2 + 4), fill=c(100, 215, 100))
        ex = w // 2 - 6
        d.rectangle((ex, h // 3, ex + 1, h // 3 + 5), fill=(20, 60, 30, 255))
        d.rectangle((ex + 8, h // 3, ex + 9, h // 3 + 5), fill=(20, 60, 30, 255))
        im = im.crop((0, 0, w, h))
        save(outline(im, c(20, 90, 40, 255)), "sprites", f"{name}.png")
    # cactus
    im = new(20, 32); d = ImageDraw.Draw(im); g = c(70, 160, 70)
    d.rectangle((7, 2, 12, 31), fill=g); d.rectangle((1, 12, 6, 15), fill=g); d.rectangle((1, 7, 3, 15), fill=g)
    d.rectangle((13, 16, 18, 19), fill=g); d.rectangle((16, 10, 18, 19), fill=g)
    d.line((9, 5, 9, 28), fill=c(110, 200, 110))
    save(outline(im, c(20, 70, 30, 255)), "sprites", "cactus.png")
    # pine
    im = new(24, 40); d = ImageDraw.Draw(im)
    d.rectangle((10, 32, 13, 39), fill=c(110, 70, 40))
    for i, y in enumerate((20, 10, 1)):
        w = 11 - i * 2
        d.polygon([(12, y), (12 - w, y + 14), (12 + w, y + 14)], fill=c(30, 110, 80))
        d.polygon([(12, y), (12 - w // 2, y + 6), (12 + w // 2, y + 6)], fill=c(240, 248, 255))
    save(outline(im, c(10, 50, 50, 255)), "sprites", "pine.png")
    # torch
    im = new(16, 32); d = ImageDraw.Draw(im)
    d.rectangle((6, 14, 9, 31), fill=c(90, 80, 90)); d.rectangle((4, 12, 11, 15), fill=c(130, 120, 130))
    d.polygon([(8, 0), (3, 11), (13, 11)], fill=c(255, 130, 30)); d.polygon([(8, 4), (5, 11), (11, 11)], fill=c(255, 230, 90))
    save(outline(im), "sprites", "torch.png")
    # crystal
    im = new(16, 24); d = ImageDraw.Draw(im)
    d.polygon([(8, 0), (2, 24), (14, 24)], fill=c(90, 220, 240)); d.polygon([(8, 0), (8, 24), (14, 24)], fill=c(50, 160, 220))
    d.polygon([(8, 6), (5, 20), (7, 20)], fill=c(200, 250, 255))
    save(outline(im, c(20, 60, 110, 255)), "sprites", "crystal.png")
    # palm / dead tree
    im = new(24, 40); d = ImageDraw.Draw(im)
    d.rectangle((11, 12, 13, 39), fill=c(150, 100, 50))
    for pts in ([(12, 12), (2, 14), (0, 20)], [(12, 12), (22, 14), (23, 20)], [(12, 12), (4, 6), (1, 8)], [(12, 12), (20, 6), (23, 8)], [(12, 12), (8, 2), (16, 2)]):
        d.polygon(pts, fill=c(70, 170, 80))
    save(outline(im, c(30, 80, 40, 255)), "sprites", "palm.png")


# ------------------------------------------------------------------ TILES
THEMES = {
    "grass": dict(top=(88, 200, 60), top_d=(40, 140, 40), fill=(200, 120, 60), fill_d=(150, 84, 40), fill_l=(230, 164, 96),
                  brick=(200, 76, 20), brick_l=(240, 130, 60), brick_d=(100, 36, 12), hard=(160, 140, 130), pipe=(40, 190, 70)),
    "desert": dict(top=(240, 210, 130), top_d=(200, 160, 90), fill=(226, 180, 104), fill_d=(190, 140, 76), fill_l=(246, 214, 144),
                   brick=(214, 140, 70), brick_l=(244, 190, 110), brick_d=(120, 70, 30), hard=(200, 160, 100), pipe=(40, 170, 150)),
    "cave": dict(top=(90, 100, 150), top_d=(50, 56, 100), fill=(70, 78, 124), fill_d=(46, 52, 90), fill_l=(100, 110, 160),
                 brick=(60, 110, 170), brick_l=(110, 160, 220), brick_d=(26, 50, 90), hard=(100, 110, 150), pipe=(60, 190, 200)),
    "snow": dict(top=(250, 252, 255), top_d=(170, 205, 240), fill=(140, 190, 235), fill_d=(100, 150, 205), fill_l=(190, 225, 250),
                 brick=(110, 170, 230), brick_l=(180, 225, 250), brick_d=(50, 90, 150), hard=(170, 200, 230), pipe=(70, 180, 130)),
    "night": dict(top=(70, 150, 140), top_d=(36, 90, 100), fill=(90, 70, 130), fill_d=(60, 46, 100), fill_l=(120, 100, 170),
                  brick=(120, 60, 150), brick_l=(170, 110, 200), brick_d=(60, 26, 90), hard=(120, 120, 160), pipe=(60, 150, 170)),
    "sky": dict(top=(255, 255, 255), top_d=(190, 215, 245), fill=(235, 245, 255), fill_d=(200, 225, 250), fill_l=(255, 255, 255),
                brick=(250, 180, 190), brick_l=(255, 220, 225), brick_d=(190, 110, 130), hard=(200, 215, 240), pipe=(250, 150, 80)),
    "castle": dict(top=(120, 110, 120), top_d=(70, 60, 74), fill=(90, 80, 94), fill_d=(56, 48, 60), fill_l=(130, 120, 134),
                   brick=(150, 60, 60), brick_l=(200, 100, 90), brick_d=(80, 24, 30), hard=(110, 100, 116), pipe=(90, 90, 130)),
}


def sh(col, k):
    return tuple(max(0, min(255, int(v * k))) for v in col) + (255,)


def t_ground(t, top):
    im = new(16, 16)
    d = ImageDraw.Draw(im)
    rnd = random.Random(7)
    d.rectangle((0, 0, 15, 15), fill=t["fill"] + (255,))
    for _ in range(14):
        x, y = rnd.randrange(16), rnd.randrange(16)
        d.point((x, y), fill=t["fill_d"] + (255,))
    for _ in range(8):
        x, y = rnd.randrange(16), rnd.randrange(16)
        d.point((x, y), fill=t["fill_l"] + (255,))
    d.line((0, 15, 15, 15), fill=t["fill_d"] + (255,))
    d.line((15, 0, 15, 15), fill=t["fill_d"] + (255,))
    if top:
        d.rectangle((0, 0, 15, 4), fill=t["top"] + (255,))
        for x in range(0, 16, 4):
            d.rectangle((x, 5, x + 1, 6), fill=t["top"] + (255,))
        d.line((0, 4, 15, 4), fill=t["top_d"] + (255,))
        d.line((0, 0, 15, 0), fill=sh(t["top"], 1.15))
    return im


def t_brick(t):
    im = new(16, 16)
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 15, 15), fill=t["brick_d"] + (255,))
    for i, y in enumerate(range(0, 16, 4)):
        off = 0 if i % 2 == 0 else 4
        for x in range(-8 + off, 16, 8):
            x0, x1 = max(x + 1, 0), min(x + 7, 15)
            if x1 > x0:
                d.rectangle((x0, y + 1, x1, y + 3), fill=t["brick"] + (255,))
                d.line((x0, y + 1, x1, y + 1), fill=t["brick_l"] + (255,))
    return im


def t_hard(t):
    im = new(16, 16)
    d = ImageDraw.Draw(im)
    h = t["hard"]
    d.rectangle((0, 0, 15, 15), fill=sh(h, 0.55))
    d.rectangle((1, 1, 14, 14), fill=sh(h, 1.0))
    d.line((0, 0, 15, 0), fill=sh(h, 1.3)); d.line((0, 0, 0, 15), fill=sh(h, 1.3))
    d.line((0, 15, 15, 15), fill=sh(h, 0.5)); d.line((15, 0, 15, 15), fill=sh(h, 0.5))
    d.rectangle((4, 4, 11, 11), fill=sh(h, 0.85))
    for p in ((2, 2), (13, 2), (2, 13), (13, 13)):
        d.point(p, fill=sh(h, 0.5))
    return im


GLYPH = ["..XXX..", ".X...X.", ".....X.", "....X..", "...X...", ".......", "...X..."]


def t_question(f, used=False):
    im = new(16, 16)
    d = ImageDraw.Draw(im)
    base = (230, 160, 30) if not used else (150, 110, 80)
    k = [1.0, 1.12, 1.25][f] if not used else 1.0
    d.rectangle((0, 0, 15, 15), fill=sh(base, 0.45))
    d.rectangle((1, 1, 14, 14), fill=sh(base, k))
    d.line((1, 1, 14, 1), fill=sh(base, k * 1.2)); d.line((1, 1, 1, 14), fill=sh(base, k * 1.2))
    for p in ((2, 2), (13, 2), (2, 13), (13, 13)):
        d.point(p, fill=sh(base, 0.5))
    if not used:
        for y, row in enumerate(GLYPH):
            for x, ch in enumerate(row):
                if ch == "X":
                    d.point((4 + x, 4 + y + 1), fill=(90, 40, 0, 255))
                    d.point((4 + x, 4 + y), fill=(255, 250, 220, 255))
    return im


def t_pipe(t):
    cap = new(32, 16)
    body = new(32, 16)
    p = t["pipe"]
    for img, is_cap in ((cap, True), (body, False)):
        d = ImageDraw.Draw(img)
        x0, x1 = (0, 31) if is_cap else (2, 29)
        d.rectangle((x0, 0, x1, 15), fill=OUTLINE)
        for x in range(x0 + 1, x1):
            u = (x - x0) / (x1 - x0)
            k = 1.35 if 0.12 < u < 0.28 else (1.0 if u < 0.6 else (0.8 if u < 0.85 else 0.65))
            d.line((x, 1 if is_cap else 0, x, 14 if is_cap else 15), fill=sh(p, k))
    return cap, body


def t_lava(top):
    im = new(16, 16)
    d = ImageDraw.Draw(im)
    rnd = random.Random(3)
    d.rectangle((0, 0, 15, 15), fill=(230, 70, 20, 255))
    for _ in range(10):
        d.point((rnd.randrange(16), rnd.randrange(16)), fill=(255, 170, 40, 255))
    if top:
        d.rectangle((0, 0, 15, 3), fill=(0, 0, 0, 0))
        for x in range(16):
            h = 2 + int(1.5 * math.sin(x * 0.8))
            d.line((x, h, x, 15), fill=(255, 150, 30, 255))
            d.point((x, h), fill=(255, 240, 120, 255))
    return im


def t_spikes():
    im = new(16, 16)
    d = ImageDraw.Draw(im)
    for x in (0, 8):
        d.polygon([(x, 15), (x + 4, 6), (x + 8, 15)], fill=c(200, 205, 220))
        d.polygon([(x + 4, 6), (x + 8, 15), (x + 4, 15)], fill=c(140, 145, 170))
    return outline(im)


def t_platform(t):
    im = new(16, 16)
    d = ImageDraw.Draw(im)
    h = t["hard"]
    d.rectangle((0, 0, 15, 5), fill=sh(h, 0.5))
    d.rectangle((0, 0, 15, 4), fill=sh(h, 1.0))
    d.line((0, 0, 15, 0), fill=sh(h, 1.3))
    d.point([(2, 2), (13, 2)], fill=sh(h, 0.5))
    return im


def make_tiles():
    for name, t in THEMES.items():
        tiles = [t_ground(t, True), t_ground(t, False), t_brick(t), t_hard(t), t_question(0, True)]
        cap, body = t_pipe(t)
        tiles += [cap.crop((0, 0, 16, 16)), cap.crop((16, 0, 32, 16)), body.crop((0, 0, 16, 16)), body.crop((16, 0, 32, 16))]
        tiles += [t_lava(True), t_lava(False)]
        tiles += [t_question(0), t_question(1), t_question(2)]
        tiles += [t_spikes(), t_platform(t)]
        save(sheet(tiles), "tiles", f"tiles_{name}.png")


# ------------------------------------------------------------------ BACKGROUNDS
BG = {
    "grass": dict(far=(120, 175, 215), near=(80, 175, 95), cap=None),
    "desert": dict(far=(238, 170, 100), near=(214, 134, 74), cap=None),
    "cave": dict(far=(34, 36, 76), near=(52, 56, 104), cap=None),
    "snow": dict(far=(170, 200, 235), near=(60, 120, 120), cap=(250, 252, 255)),
    "night": dict(far=(44, 44, 104), near=(34, 66, 80), cap=None),
    "sky": dict(far=(235, 245, 255), near=(255, 255, 255), cap=None),
    "castle": dict(far=(70, 24, 36), near=(46, 14, 26), cap=None),
}


def ridge(w, h, base, amp, seed, harm=((1, 1.0), (3, 0.5), (7, 0.25))):
    rnd = random.Random(seed)
    ph = [(k, a, rnd.random() * 6.28) for k, a in harm]
    ys = []
    for x in range(w):
        v = sum(a * math.sin(2 * math.pi * k * x / w + p) for k, a, p in ph)
        ys.append(int(base - amp * (v / sum(a for _, a in harm) * 0.5 + 0.5)))
    return ys


def make_bg():
    for name, b in BG.items():
        W = 256
        far = new(W, 128)
        d = ImageDraw.Draw(far)
        if name == "castle":
            for x in range(0, W, 32):
                hh = 50 + (x // 32 * 37) % 40
                d.rectangle((x + 4, 128 - hh, x + 26, 127), fill=b["far"] + (255,))
                for tx in range(x + 4, x + 27, 8):
                    d.rectangle((tx, 128 - hh - 5, tx + 3, 128 - hh), fill=b["far"] + (255,))
                d.rectangle((x + 12, 128 - hh + 10, x + 16, 128 - hh + 18), fill=(255, 120, 40, 255))
        elif name == "sky":
            for cx, cy, r in ((30, 100, 26), (100, 90, 34), (180, 105, 28), (230, 95, 22)):
                blob(d, [(cx, cy, r), (cx + r, cy + 6, r * 0.7), (cx - r, cy + 8, r * 0.7)], b["far"] + (255,))
            d.rectangle((0, 112, W, 127), fill=b["far"] + (255,))
        else:
            ys = ridge(W, 128, 118, 82, 11 + len(name))
            for x, y in enumerate(ys):
                d.line((x, y, x, 127), fill=b["far"] + (255,))
                if b["cap"] and y < 60:
                    d.line((x, y, x, y + 7), fill=b["cap"] + (255,))
            if name == "cave":
                for x in range(0, W, 24):
                    hh = 12 + (x * 7) % 26
                    d.polygon([(x, 0), (x + 10, 0), (x + 5, hh)], fill=b["far"] + (255,))
        save(far, "bg", f"bg_{name}_far.png")
        near = new(W, 72)
        d = ImageDraw.Draw(near)
        if name == "sky":
            for cx, cy, r in ((50, 60, 16), (150, 56, 20), (220, 62, 14)):
                blob(d, [(cx, cy, r), (cx + r, cy + 5, r * 0.7), (cx - r, cy + 5, r * 0.7)], b["near"] + (255,))
            d.rectangle((0, 62, W, 71), fill=b["near"] + (255,))
        elif name == "snow":
            d.rectangle((0, 60, W, 71), fill=b["near"] + (255,))
            for x in range(6, W, 20):
                hh = 30 + (x * 3) % 18
                for k in range(3):
                    wy = 62 - hh + k * 12
                    d.polygon([(x, wy), (x - 8 + k, wy + 16), (x + 8 - k, wy + 16)], fill=b["near"] + (255,))
        elif name == "cave":
            ys = ridge(W, 72, 66, 40, 5, ((2, 1.0), (5, 0.6), (9, 0.4)))
            for x, y in enumerate(ys):
                d.line((x, y, x, 71), fill=b["near"] + (255,))
            for x in range(10, W, 40):
                d.polygon([(x, 66), (x + 4, 30 + x % 17), (x + 8, 66)], fill=(90, 200, 230, 255))
        else:
            ys = ridge(W, 72, 68, 44, 23 + len(name), ((2, 1.0), (4, 0.6), (9, 0.3)))
            for x, y in enumerate(ys):
                d.line((x, y, x, 71), fill=b["near"] + (255,))
        save(near, "bg", f"bg_{name}_near.png")
    # sky dressing layers
    rnd = random.Random(42)
    st = new(256, 180)
    d = ImageDraw.Draw(st)
    for _ in range(70):
        x, y = rnd.randrange(256), rnd.randrange(150)
        d.point((x, y), fill=(255, 255, 255, rnd.choice([120, 200, 255])))
    save(st, "bg", "bg_night_sky.png")
    st2 = st.copy()
    d = ImageDraw.Draw(st2)
    d.ellipse((190, 22, 218, 50), fill=(250, 245, 210, 255))
    d.ellipse((199, 18, 224, 44), fill=(0, 0, 0, 0))
    save(st2, "bg", "bg_night_moon.png")
    sun = new(256, 180)
    d = ImageDraw.Draw(sun)
    d.ellipse((170, 20, 218, 68), fill=(255, 245, 190, 255))
    d.ellipse((176, 26, 212, 62), fill=(255, 255, 230, 255))
    save(sun, "bg", "bg_desert_sky.png")
    cs = new(256, 180)
    d = ImageDraw.Draw(cs)
    for _ in range(40):
        x, y = rnd.randrange(256), rnd.randrange(60)
        d.point((x, y), fill=(120, 140, 200, 200))
    save(cs, "bg", "bg_cave_sky.png")


# ------------------------------------------------------------------ LOGO / ICON
def make_logo():
    font_path = os.path.join(A, "fonts", "PressStart2P.ttf")
    try:
        f1 = ImageFont.truetype(font_path, 24)
        f2 = ImageFont.truetype(font_path, 24)
    except Exception:
        f1 = f2 = ImageFont.load_default()
    W, H = 296, 78
    out = new(W, H)

    def draw_text(text, font, y, top, bot, x_center=W // 2):
        mask = Image.new("L", (W, H), 0)
        md = ImageDraw.Draw(mask)
        bb = md.textbbox((0, 0), text, font=font)
        x = x_center - (bb[2] - bb[0]) // 2
        md.text((x, y), text, font=font, fill=255)
        grad = new(W, H)
        gp = grad.load()
        for yy in range(H):
            t = max(0, min(1, (yy - y) / 24))
            col = tuple(int(top[i] * (1 - t) + bot[i] * t) for i in range(3)) + (255,)
            for xx in range(W):
                gp[xx, yy] = col
        # outline + shadow
        ol = Image.new("L", (W, H), 0)
        od = ImageDraw.Draw(ol)
        od.text((x, y), text, font=font, fill=255, stroke_width=3, stroke_fill=255)
        black = Image.new("RGBA", (W, H), (24, 16, 32, 255))
        shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        shadow.paste(black, (0, 3), ol)
        out.alpha_composite(shadow)
        o2 = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        o2.paste(black, (0, 0), ol)
        out.alpha_composite(o2)
        txt = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        txt.paste(grad, (0, 0), mask)
        out.alpha_composite(txt)

    draw_text("SUPER", f1, 4, (255, 120, 90), (210, 20, 30))
    draw_text("PIXEL BROS", f2, 42, (255, 250, 150), (255, 160, 20))
    save(out, "ui", "logo.png")


def make_icon():
    img = Image.new("RGBA", (128, 128), (92, 148, 252, 255))
    d = ImageDraw.Draw(img)
    d.rectangle((0, 100, 127, 127), fill=(200, 120, 60, 255))
    d.rectangle((0, 100, 127, 108), fill=(88, 200, 60, 255))
    p = player_frame("idle", False, PAL).resize((96, 96), Image.NEAREST)
    img.alpha_composite(p, (16, 8))
    img.save(os.path.join(ROOT, "icon.png"))


if __name__ == "__main__":
    make_player(); make_enemies(); make_items(); decor(); make_tiles(); make_bg(); make_logo(); make_icon()
    print("assets ok")
