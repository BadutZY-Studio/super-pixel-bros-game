#!/usr/bin/env python3
"""Generates chiptune SFX + music loops (WAV) for Super Pixel Bros. Requires numpy."""
import os, wave
import numpy as np

SR = 22050
OUT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "assets", "audio"))
os.makedirs(OUT, exist_ok=True)


def write(name, data):
    data = np.clip(data, -1, 1)
    pcm = (data * 32000).astype("<i2")
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def osc(freq, n, kind="square", duty=0.5):
    """freq may be scalar or array of length n"""
    if np.isscalar(freq):
        freq = np.full(n, float(freq))
    phase = np.cumsum(freq) / SR
    ph = phase % 1.0
    if kind == "square":
        return np.where(ph < duty, 1.0, -1.0)
    if kind == "tri":
        return 4 * np.abs(ph - 0.5) - 1
    if kind == "saw":
        return 2 * ph - 1
    if kind == "noise":
        return np.random.uniform(-1, 1, n)
    return np.sin(2 * np.pi * phase)


def env(n, a=0.005, d=None, sustain=1.0):
    t = np.arange(n) / SR
    e = np.ones(n)
    at = max(1, int(a * SR))
    e[:at] = np.linspace(0, 1, at)
    rel = int(0.03 * SR)
    if rel < n:
        e[-rel:] *= np.linspace(1, 0, rel)
    if d:
        e *= np.exp(-t / d) * (1 - sustain) + sustain
    return e


def tone(f0, f1, dur, kind="square", vol=0.4, duty=0.5, decay=None):
    n = int(dur * SR)
    f = np.linspace(f0, f1, n)
    return osc(f, n, kind, duty) * env(n, d=decay) * vol


def seq(parts, gap=0.0):
    return np.concatenate([np.concatenate([p, np.zeros(int(gap * SR))]) for p in parts])


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def sfx():
    write("sfx_jump", tone(260, 620, 0.18, duty=0.25))
    write("sfx_jump_big", tone(180, 520, 0.22, duty=0.5))
    write("sfx_coin", seq([tone(988, 988, 0.07, vol=0.35), tone(1319, 1319, 0.28, vol=0.35, decay=0.12)]))
    write("sfx_stomp", tone(420, 120, 0.12, "square", 0.45) + 0)
    write("sfx_bump", tone(150, 90, 0.09, "tri", 0.6))
    n = int(0.22 * SR)
    write("sfx_break", osc(0, n, "noise") * np.exp(-np.arange(n) / (0.05 * SR)) * 0.5)
    write("sfx_powerup", seq([tone(midi(m), midi(m), 0.06, duty=0.25, vol=0.3) for m in (60, 64, 67, 72, 76, 79, 84, 88)]))
    write("sfx_powerup_appear", tone(200, 900, 0.45, "tri", 0.5))
    write("sfx_die", seq([tone(midi(m), midi(m), 0.12, duty=0.5, vol=0.35) for m in (72, 71, 70, 69)] + [tone(400, 60, 0.7, "square", 0.35)]))
    write("sfx_fireball", tone(900, 300, 0.1, duty=0.125, vol=0.3))
    write("sfx_kick", tone(700, 200, 0.12, "square", 0.4, duty=0.25))
    write("sfx_pipe", tone(500, 120, 0.4, "tri", 0.6))
    write("sfx_flag", tone(1200, 200, 1.1, "tri", 0.5))
    write("sfx_oneup", seq([tone(midi(m), midi(m), 0.09, duty=0.5, vol=0.3) for m in (76, 79, 88, 84, 86, 91)]))
    write("sfx_click", tone(700, 900, 0.05, vol=0.3, duty=0.25))
    write("sfx_select", seq([tone(660, 660, 0.06, vol=0.3), tone(990, 990, 0.1, vol=0.3)]))
    write("sfx_tick", tone(1500, 1500, 0.03, vol=0.25, duty=0.25))
    write("sfx_hurry", seq([tone(1200, 1200, 0.08, vol=0.3), tone(900, 900, 0.08, vol=0.3)] * 3))
    write("sfx_checkpoint", seq([tone(midi(m), midi(m), 0.08, duty=0.25, vol=0.3) for m in (67, 72, 76)]))
    write("sfx_gameover", seq([tone(midi(m), midi(m), 0.25, "tri", 0.6) for m in (67, 64, 60)] + [tone(midi(55), midi(52), 0.8, "tri", 0.6)]))
    win = [(72, .1), (72, .1), (72, .1), (72, .3), (68, .3), (70, .3), (72, .15), (70, .1), (72, .6), (76, .1), (79, .1), (84, .7)]
    lead = seq([tone(midi(m), midi(m), d, duty=0.25, vol=0.3) for m, d in win])
    write("sfx_win", lead)


# ---------------------------------------------------------------- MUSIC
SCALES = {
    "major": [0, 2, 4, 5, 7, 9, 11],
    "minor": [0, 2, 3, 5, 7, 8, 10],
    "pent": [0, 2, 4, 7, 9],
    "dorian": [0, 2, 3, 5, 7, 9, 10],
}


def compose(root, scale, bpm, seed, prog, lead_duty=0.25, bars=8, bass_style="walk", drums=True, lead_vol=0.22, oct_up=0):
    rng = np.random.RandomState(seed)
    sc = SCALES[scale]
    spb = 60.0 / bpm
    step = spb / 2  # eighth note
    total_steps = bars * 8
    n_total = int(total_steps * step * SR)
    out = np.zeros(n_total)

    def degree_to_midi(deg, octave):
        o, i = divmod(deg, len(sc))
        return root + sc[i] + 12 * (o + octave)

    # melody phrases (4 bars each: A, A', B, A'')
    def phrase(seed_):
        r = np.random.RandomState(seed_)
        deg = r.randint(2, 5)
        notes = []
        rhythm = [2, 1, 1, 2, 2, 1, 1, 2, 1, 1, 1, 1, 2, 2]
        pos = 0
        while pos < 32:
            ln = int(r.choice([1, 1, 2, 2, 2, 4]))
            ln = min(ln, 32 - pos)
            if r.rand() < 0.15:
                notes.append((None, ln))
            else:
                deg = int(np.clip(deg + r.choice([-2, -1, -1, 0, 1, 1, 2]), 0, 9))
                notes.append((deg, ln))
            pos += ln
        return notes

    A = phrase(seed * 3 + 1)
    B = phrase(seed * 3 + 2)
    layout = [A, A, B, A] if bars == 8 else [A, B]
    # for 8 bars: each phrase 4 bars (32 steps) -> need 2 phrases only
    layout = [A, B]
    pos = 0
    for ph in layout:
        for deg, ln in ph:
            if deg is not None:
                m = degree_to_midi(deg, 1 + oct_up)
                n = int(ln * step * SR * 0.92)
                s = int(pos * step * SR)
                if s + n <= n_total:
                    out[s:s + n] += osc(midi(m), n, "square", lead_duty) * env(n, a=0.003, d=0.25, sustain=0.5) * lead_vol
            pos += ln
    # bass + arpeggio
    for bar in range(bars):
        chord_deg = prog[bar % len(prog)]
        for st in range(8):
            gstep = bar * 8 + st
            s = int(gstep * step * SR)
            n = int(step * SR * 0.9)
            if s + n > n_total:
                continue
            if bass_style == "walk":
                d = chord_deg + (0 if st % 4 in (0, 1) else (4 if st % 4 == 2 else 2))
                m = degree_to_midi(d, -1)
                out[s:s + n] += osc(midi(m), n, "tri") * env(n, a=0.002) * 0.38
            else:
                m = degree_to_midi(chord_deg, -1) + (0 if st % 2 == 0 else 12)
                out[s:s + n] += osc(midi(m), n, "tri") * env(n, a=0.002) * 0.38
            # arp
            ad = chord_deg + [0, 2, 4, 2][st % 4]
            m = degree_to_midi(ad, 0)
            out[s:s + n] += osc(midi(m), n, "square", 0.125) * env(n, a=0.002, d=0.08, sustain=0.2) * 0.07
            if drums:
                if st % 4 == 0:
                    kn = int(0.09 * SR)
                    out[s:s + kn] += osc(np.linspace(150, 45, kn), kn, "sine") * np.linspace(1, 0, kn) * 0.5
                if st % 4 == 2:
                    sn = int(0.08 * SR)
                    out[s:s + sn] += osc(0, sn, "noise") * np.linspace(1, 0, sn) ** 2 * 0.22
                if st % 2 == 1:
                    hn = int(0.025 * SR)
                    out[s:s + hn] += osc(0, hn, "noise") * np.linspace(1, 0, hn) * 0.07
    return out * 0.9


def music():
    tracks = {
        "menu": dict(root=60, scale="major", bpm=118, seed=3, prog=[0, 5, 3, 4], lead_duty=0.5),
        "grass": dict(root=60, scale="major", bpm=152, seed=11, prog=[0, 4, 5, 3]),
        "desert": dict(root=57, scale="dorian", bpm=132, seed=21, prog=[0, 0, 3, 4], lead_duty=0.125),
        "cave": dict(root=52, scale="minor", bpm=110, seed=31, prog=[0, 5, 3, 4], lead_duty=0.5, lead_vol=0.18, bass_style="oct"),
        "snow": dict(root=64, scale="pent", bpm=124, seed=41, prog=[0, 3, 4, 2], lead_duty=0.5, oct_up=0),
        "night": dict(root=55, scale="minor", bpm=140, seed=51, prog=[0, 3, 5, 4], lead_duty=0.25),
        "sky": dict(root=67, scale="major", bpm=160, seed=61, prog=[0, 5, 3, 4], lead_duty=0.25, oct_up=0),
        "castle": dict(root=50, scale="minor", bpm=148, seed=71, prog=[0, 0, 5, 4], lead_duty=0.125, bass_style="oct"),
    }
    for name, kw in tracks.items():
        write("music_" + name, compose(**kw))


if __name__ == "__main__":
    sfx(); music(); print("audio ok")
