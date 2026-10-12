"""Instruments synthétisés (une note = un tableau mono float32)."""
import numpy as np

from dsp import (SR, bp, env_adsr, env_exp, f32, fade_tail, hp, karplus, lp, midi_hz, noise, onepole,
                 saturate, saw, sine, square, tri)


def _n(sec):
    return max(1, int(sec * SR))


# ------------------------------------------------------------------ batterie

def kick(kind="house", tune=50.0, decay=None, seed=1):
    if kind == "808":
        dur = decay or 0.9
        n = _n(dur)
        t = np.arange(n) / SR
        f = tune + (tune * 2.6) * np.exp(-t / 0.035)
        body = sine(f, n) * env_exp(n, dur * 0.45, 0.001)
        click = hp(noise(_n(0.01), seed), 3000) * env_exp(_n(0.01), 0.002)
        body[: len(click)] += click * 0.4
        return saturate(body * 1.6, 1.4) * 0.9
    if kind == "boombap":
        dur = decay or 0.45
        n = _n(dur)
        t = np.arange(n) / SR
        f = tune + 110 * np.exp(-t / 0.025)
        body = sine(f, n) * env_exp(n, 0.16, 0.001)
        thud = lp(noise(n, seed), 900) * env_exp(n, 0.03)
        return saturate(body * 1.8 + thud * 0.5, 1.6)
    # house / pop : court et punchy
    dur = decay or 0.38
    n = _n(dur)
    t = np.arange(n) / SR
    f = tune + 150 * np.exp(-t / 0.018) + 40 * np.exp(-t / 0.08)
    body = sine(f, n) * env_exp(n, 0.13, 0.0008)
    click = bp(noise(_n(0.006), seed), 4000, 0.8) * env_exp(_n(0.006), 0.0015)
    body[: len(click)] += click * 0.6
    return saturate(body * 1.7, 1.5) * 0.95


def snare(tone=190.0, decay=0.16, snap=1.0, seed=2):
    n = _n(decay * 3.0)
    t = np.arange(n) / SR
    body = (sine(tone * (1 + 0.5 * np.exp(-t / 0.01)), n) * 0.6 + sine(tone * 1.72, n) * 0.3) * env_exp(n, decay * 0.45)
    nz = bp(noise(n, seed), 3800, 0.6) * env_exp(n, decay) * snap
    nz += hp(noise(n, seed + 7), 7000) * env_exp(n, decay * 0.6) * 0.4 * snap
    return saturate(body + nz * 0.9, 1.3) * 0.8


def clap(decay=0.22, seed=3, tight=False):
    n = _n(decay * 3)
    out = np.zeros(n, np.float32)
    base = bp(noise(n, seed), 1300, 1.1)
    bursts = [0.0] if tight else [0.0, 0.011, 0.021, 0.034]
    for i, b in enumerate(bursts):
        s = _n(b)
        k = n - s
        e = env_exp(k, 0.007 if i < len(bursts) - 1 else decay, 0.0005)
        out[s:] += base[:k] * e
    return out * 1.3


def snap(seed=4):
    n = _n(0.12)
    nz = bp(noise(n, seed), 2600, 2.0) * env_exp(n, 0.018, 0.0005)
    tone = sine(1700.0, n) * env_exp(n, 0.012) * 0.3
    return (nz * 2.2 + tone)


def hat(open_=False, decay=None, seed=5, metal=True):
    dur = decay or (0.32 if open_ else 0.045)
    n = _n(dur * 2.5)
    if metal:
        ratios = [2.0, 3.0, 4.16, 5.43, 6.79, 8.21]
        src = sum(square(40.0 * r * 4.0, n, 0.5) for r in ratios) / 6.0
        src = src * 0.6 + noise(n, seed) * 0.4
    else:
        src = noise(n, seed)
    x = hp(bp(src, 9000, 0.6) + hp(src, 8000) * 0.5, 6500)
    return x * env_exp(n, dur, 0.0005) * (0.9 if open_ else 1.0)


def shaker(decay=0.06, seed=6):
    n = _n(decay * 2.2)
    t = np.arange(n) / SR
    e = np.minimum(1.0, t / 0.012) * np.exp(-t / decay)
    return hp(bp(noise(n, seed), 7000, 0.8), 4500) * e.astype(np.float32) * 1.4


def rim(seed=7):
    n = _n(0.08)
    x = sine(1700.0, n) * env_exp(n, 0.012) + bp(noise(n, seed), 2500, 3.0) * env_exp(n, 0.008) * 1.5
    return x * 0.9


def cowbell(pitch=1.0, decay=0.22):
    n = _n(decay * 3)
    x = square(587.0 * pitch, n, 0.5) * 0.5 + square(845.0 * pitch, n, 0.5) * 0.5
    x = bp(x, 900 * pitch, 1.4) + bp(x, 2600 * pitch, 2.0) * 0.4
    e = env_exp(n, 0.03) * 0.6 + env_exp(n, decay) * 0.4
    return x * e * 1.4


def tom(note=45, decay=0.28):
    n = _n(decay * 2.5)
    t = np.arange(n) / SR
    f = midi_hz(note) * (1 + 0.6 * np.exp(-t / 0.03))
    return saturate(sine(f, n) * env_exp(n, decay) * 1.4 + lp(noise(n, 9), 1500) * env_exp(n, 0.02) * 0.3, 1.2)


def crash(decay=1.6, seed=8):
    n = _n(decay * 2)
    ratios = [1.0, 1.48, 1.93, 2.71, 3.35, 4.12, 5.27]
    src = sum(square(330.0 * r, n, 0.5) for r in ratios) / 7.0 * 0.4 + noise(n, seed) * 0.6
    return hp(src, 4000) * env_exp(n, decay * 0.5, 0.001) * 0.7


def log_drum(note=40, decay=0.55, drive=1.6):
    """Log drum amapiano : sinus/triangle accordé, chute de hauteur, attaque claquante."""
    n = _n(decay * 1.8)
    t = np.arange(n) / SR
    f = midi_hz(note) * (1.0 + 0.9 * np.exp(-t / 0.012)) * (1.0 - 0.06 * (1 - np.exp(-t / 0.25)))
    body = (sine(f, n) * 0.8 + tri(f * 2.0, n) * 0.25) * env_exp(n, decay, 0.001)
    knock = bp(noise(_n(0.02), 11), 1200, 1.5) * env_exp(_n(0.02), 0.004)
    body[: len(knock)] += knock * 0.5
    return saturate(body * drive, drive)


def taiko(decay=0.7):
    n = _n(decay * 2)
    t = np.arange(n) / SR
    f = 62.0 * (1 + 0.8 * np.exp(-t / 0.02))
    body = sine(f, n) * env_exp(n, decay * 0.5, 0.001)
    skin = lp(noise(n, 12), 600) * env_exp(n, 0.06)
    return saturate(body * 1.5 + skin * 0.8, 1.3)


def chip_noise(decay=0.08, hi=True, seed=13):
    """Bruit 8 bits (registre à décalage simulé par échantillonnage bloqué)."""
    n = _n(decay * 2)
    step = 4 if hi else 18
    raw = np.repeat(noise(n // step + 1, seed), step)[:n]
    return np.sign(raw).astype(np.float32) * env_exp(n, decay, 0.0005) * 0.6


# ------------------------------------------------------------------ basses

def bass_808(note, dur, glide_to=None, glide_time=0.06, drive=1.8, decay=None):
    n = _n(dur + 0.04)
    t = np.arange(n) / SR
    f0 = midi_hz(note)
    f = np.full(n, f0)
    if glide_to is not None:
        f1 = midi_hz(glide_to)
        start = max(0.0, dur - glide_time)
        k = np.clip((t - start) / max(glide_time, 1e-4), 0.0, 1.0)
        f = f0 * (f1 / f0) ** k
    f = f * (1 + 0.25 * np.exp(-t / 0.02))
    x = sine(f, n) + sine(f * 2.0, n) * 0.08
    e = env_adsr(n, 0.002, decay or 0.8, 0.55, 0.05, gate=dur)
    return saturate(x * e * drive, drive) * 0.8


def bass_saw(note, dur, cutoff=900.0, env_amt=2.5, q=1.2, decay=0.18, sub=0.5, detune=0.0):
    n = _n(dur + 0.05)
    f = midi_hz(note)
    x = saw(f, n) * 0.6
    if detune:
        x += saw(f * (1 + detune), n) * 0.4
    x += sine(f * 0.5 if sub < 0 else f, n) * abs(sub)
    fe = cutoff * (1 + env_amt * env_exp(n, decay))
    y = lp(x, fe, q)
    return y * env_adsr(n, 0.003, 0.3, 0.8, 0.04, gate=dur)


def bass_organ(note, dur):
    n = _n(dur + 0.04)
    f = midi_hz(note)
    x = sine(f, n) + 0.5 * sine(f * 2, n) + 0.25 * square(f, n, 0.5) * 0.4
    return lp(x, 1400) * env_adsr(n, 0.003, 0.2, 0.75, 0.03, gate=dur) * 0.8


def bass_fm(note, dur, index=3.0, ratio=1.0, decay=0.25):
    n = _n(dur + 0.05)
    f = midi_hz(note)
    t = np.arange(n) / SR
    idx = index * env_exp(n, decay) + 0.6
    mod = np.sin(2 * np.pi * np.cumsum(np.full(n, f * ratio)) / SR) * idx
    car = np.sin(2 * np.pi * np.cumsum(np.full(n, f)) / SR + mod).astype(np.float32)
    return car * env_adsr(n, 0.002, 0.35, 0.6, 0.03, gate=dur) * 0.9


def bass_upright(note, dur):
    """Contrebasse pincée (Karplus-Strong filtré)."""
    return pluck_ks(note, max(dur, 0.25), bright=0.25, decay=0.9) * 1.6


def bass_slap(note, dur):
    n = _n(dur + 0.05)
    f = midi_hz(note)
    x = saw(f, n) * 0.5 + square(f, n, 0.3) * 0.3 + sine(f, n) * 0.6
    y = lp(x, 400 + 3500 * env_exp(n, 0.05), 1.8)
    return y * env_adsr(n, 0.001, 0.12, 0.55, 0.03, gate=dur)


# ------------------------------------------------------------------ claviers, cordes pincées

def pluck_ks(note, dur, bright=0.5, decay=0.996, seed=21):
    """Corde pincée Karplus-Strong."""
    f = float(midi_hz(note))
    period = max(2, int(round(SR / f)))
    n = _n(dur)
    rng = np.random.default_rng(seed + int(note))
    init = onepole(rng.uniform(-1, 1, period).astype(np.float32), 0.15 + 0.8 * bright)
    y = karplus(init - init.mean(), n, 0.5 * decay)
    return fade_tail(y * env_adsr(n, 0.001, 1.0, 1.0, 0.03, gate=max(0.01, dur - 0.03)) * 1.5)


def piano(note, dur, vel=1.0, bright=1.0):
    n = _n(dur + 0.6)
    f = float(midi_hz(note))
    t = np.arange(n) / SR
    x = np.zeros(n, np.float32)
    for k in range(1, 9):
        fk = f * k * (1 + 0.0004 * k * k)
        if fk > SR * 0.45:
            break
        amp = (1.0 / k ** (1.4 - 0.4 * bright)) * vel
        dk = 1.6 / (1 + 0.5 * k) * (1.0 if note < 72 else 0.6)
        x += (np.sin(2 * np.pi * fk * t + k) * amp * np.exp(-t / dk)).astype(np.float32)
    hammer = bp(noise(_n(0.02), 31), f * 4, 1.0) * env_exp(_n(0.02), 0.004) * 0.3
    x[: len(hammer)] += hammer
    e = env_adsr(n, 0.002, 2.0, 1.0, 0.25, gate=dur)
    return x * e * 0.5


def epiano(note, dur, vel=1.0, tine=1.0):
    """Piano électrique type Rhodes (FM 2 opérateurs)."""
    n = _n(dur + 0.7)
    f = float(midi_hz(note))
    t = np.arange(n) / SR
    idx = (1.6 * tine * vel) * np.exp(-t / 0.35) + 0.2
    mod = np.sin(2 * np.pi * f * 1.0 * t) * idx
    car = np.sin(2 * np.pi * f * t + mod)
    bell = np.sin(2 * np.pi * f * 14.0 * t) * np.exp(-t / 0.05) * 0.06 * tine
    x = (car + bell).astype(np.float32) * np.exp(-t / 1.8).astype(np.float32)
    trem = 1.0 + 0.12 * np.sin(2 * np.pi * 4.5 * t)
    return x * trem.astype(np.float32) * env_adsr(n, 0.002, 2.0, 1.0, 0.3, gate=dur) * 0.45 * vel


def organ(note, dur, drawbars=(1.0, 0.6, 0.4, 0.2), perc=0.3):
    n = _n(dur + 0.1)
    f = float(midi_hz(note))
    t = np.arange(n) / SR
    x = np.zeros(n, np.float32)
    for k, a in zip([1, 2, 3, 4], drawbars):
        x += (np.sin(2 * np.pi * f * k * t) * a).astype(np.float32)
    x += (np.sin(2 * np.pi * f * 3 * t) * perc * np.exp(-t / 0.15)).astype(np.float32)
    lfo = 1 + 0.08 * np.sin(2 * np.pi * 6.0 * t)
    return x * lfo.astype(np.float32) * env_adsr(n, 0.004, 0.1, 1.0, 0.05, gate=dur) * 0.3


def mallet(note, dur, kind="marimba"):
    """Marimba / xylophone / vibraphone / célesta / cloche (partiels inharmoniques)."""
    specs = {
        "marimba": [(1.0, 1.0, 0.5), (3.99, 0.35, 0.12), (10.0, 0.12, 0.03)],
        "xylo": [(1.0, 1.0, 0.25), (3.0, 0.5, 0.1), (6.25, 0.25, 0.04)],
        "vibes": [(1.0, 1.0, 1.4), (3.99, 0.25, 0.4), (9.9, 0.06, 0.1)],
        "celesta": [(1.0, 1.0, 0.8), (2.0, 0.3, 0.3), (4.0, 0.15, 0.1), (6.0, 0.05, 0.05)],
        "bell": [(1.0, 1.0, 1.2), (2.76, 0.5, 0.6), (5.4, 0.3, 0.3), (8.9, 0.15, 0.15)],
        "glock": [(1.0, 1.0, 0.7), (2.7, 0.4, 0.25), (5.9, 0.2, 0.08)],
    }[kind]
    tail = max(s[2] for s in specs) * 3
    n = _n(max(dur, 0.05) + tail)
    f = float(midi_hz(note))
    t = np.arange(n) / SR
    x = np.zeros(n, np.float32)
    for r, a, d in specs:
        fr = f * r
        if fr > SR * 0.45:
            continue
        x += (np.sin(2 * np.pi * fr * t) * a * np.exp(-t / d)).astype(np.float32)
    if kind == "vibes":
        x *= (1 + 0.25 * np.sin(2 * np.pi * 5.5 * t)).astype(np.float32)
    att = np.minimum(1.0, t / 0.0015).astype(np.float32)
    return x * att * 0.5


# ------------------------------------------------------------------ nappes, accords, voix

def supersaw(note, dur, voices=7, detune=0.18, cutoff=3200.0, attack=0.02, release=0.25, seed=41):
    n = _n(dur + release)
    f = float(midi_hz(note))
    rng = np.random.default_rng(seed + int(note))
    x = np.zeros(n, np.float32)
    for v in range(voices):
        d = (v - (voices - 1) / 2) / ((voices - 1) / 2) if voices > 1 else 0
        x += saw(f * (1 + d * detune * 0.06), n, rng.uniform())
    x /= voices ** 0.6
    y = lp(x, cutoff, 0.8)
    return y * env_adsr(n, attack, 0.4, 0.85, release, gate=dur)


def pad(note, dur, attack=0.4, release=0.8, cutoff=1800.0, bright=0.5):
    n = _n(dur + release)
    f = float(midi_hz(note))
    x = saw(f * 0.997, n, 0.1) + saw(f * 1.003, n, 0.6) + tri(f * 2.0, n) * 0.4 * bright
    t = np.arange(n) / SR
    fc = cutoff * (1 + 0.25 * np.sin(2 * np.pi * 0.3 * t))
    return lp(x, fc, 0.7) * env_adsr(n, attack, 1.0, 1.0, release, gate=dur) * 0.4


_VOWELS = {
    "a": [(800, 1.0, 80), (1150, 0.5, 90), (2900, 0.25, 120)],
    "e": [(400, 1.0, 70), (2000, 0.45, 100), (2600, 0.3, 120)],
    "i": [(300, 1.0, 60), (2300, 0.4, 100), (3000, 0.3, 120)],
    "o": [(450, 1.0, 70), (800, 0.6, 80), (2830, 0.15, 100)],
    "u": [(325, 1.0, 50), (700, 0.35, 60), (2530, 0.08, 100)],
}


def voice(note, dur, vowel="a", vibrato=0.25, breath=0.08, attack=0.03, release=0.12, seed=51, to_vowel=None):
    """Voix synthétique (source glottique + formants)."""
    n = _n(dur + release)
    t = np.arange(n) / SR
    f = midi_hz(note) * (1 + 0.012 * vibrato * np.sin(2 * np.pi * 5.6 * t) * np.minimum(1, t / 0.25))
    src = saw(f, n) * 0.7 + square(f, n, 0.12) * 0.15 + noise(n, seed) * breath
    out = np.zeros(n, np.float32)
    form = _VOWELS[vowel]
    form2 = _VOWELS[to_vowel] if to_vowel else form
    k = np.clip(t / max(dur, 1e-3), 0, 1)
    for (f1, a1, b1), (f2, a2, b2) in zip(form, form2):
        fc = f1 + (f2 - f1) * k
        out += bp(src, fc, float(f1) / float(b1)) * (a1 + (a2 - a1) * k).astype(np.float32)
    return out * env_adsr(n, attack, 0.3, 0.9, release, gate=dur) * 0.9


# ------------------------------------------------------------------ mélodies

def lead_square(note, dur, pw=0.5, vibrato=0.0, glide_from=None, cutoff=5000.0, attack=0.004, release=0.06):
    n = _n(dur + release)
    t = np.arange(n) / SR
    f = midi_hz(note) * np.ones(n)
    if glide_from is not None:
        f0 = midi_hz(glide_from)
        k = np.clip(t / 0.05, 0, 1)
        f = f0 * (midi_hz(note) / f0) ** k
    if vibrato:
        f = f * (1 + vibrato * 0.01 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.12) / 0.2, 0, 1))
    x = square(f, n, pw)
    return lp(x, cutoff) * env_adsr(n, attack, 0.2, 0.8, release, gate=dur) * 0.5


def lead_saw(note, dur, cutoff=3000.0, env_amt=1.5, q=1.0, vibrato=0.0, detune=0.12, glide_from=None, attack=0.005, release=0.08):
    n = _n(dur + release)
    t = np.arange(n) / SR
    f = midi_hz(note) * np.ones(n)
    if glide_from is not None:
        f0 = midi_hz(glide_from)
        k = np.clip(t / 0.06, 0, 1)
        f = f0 * (midi_hz(note) / f0) ** k
    if vibrato:
        f = f * (1 + vibrato * 0.01 * np.sin(2 * np.pi * 5.8 * t) * np.clip((t - 0.15) / 0.2, 0, 1))
    x = saw(f, n) * 0.6 + saw(f * (1 + detune * 0.01), n, 0.3) * 0.4
    y = lp(x, cutoff * (1 + env_amt * env_exp(n, 0.12)), q)
    return y * env_adsr(n, attack, 0.25, 0.75, release, gate=dur) * 0.5


def pluck(note, dur, cutoff=600.0, env_amt=7.0, decay=0.12, q=1.4, wave="saw"):
    n = _n(dur + 0.3)
    f = midi_hz(note)
    x = saw(f, n) if wave == "saw" else square(f, n, 0.35)
    x = x * 0.7 + saw(f * 1.006, n, 0.4) * 0.3
    y = lp(x, cutoff * (1 + env_amt * env_exp(n, decay)), q)
    return y * env_exp(n, decay * 3.0, 0.002) * 0.6


def flute(note, dur, breath=0.18, vibrato=0.6, attack=0.05, release=0.1, seed=61):
    n = _n(dur + release)
    t = np.arange(n) / SR
    f = midi_hz(note) * (1 + vibrato * 0.008 * np.sin(2 * np.pi * 5.2 * t) * np.clip((t - 0.15) / 0.25, 0, 1))
    x = sine(f, n) + sine(f * 2, n) * 0.18 + sine(f * 3, n) * 0.05
    chiff = bp(noise(n, seed), float(midi_hz(note)) * 2.0, 2.0) * env_exp(n, 0.05) * 0.35
    air = hp(noise(n, seed + 1), 2000) * breath * 0.25
    return (x * 0.7 + chiff + air) * env_adsr(n, attack, 0.3, 0.85, release, gate=dur) * 0.6


def accordion(note, dur, attack=0.02, release=0.08):
    n = _n(dur + release)
    t = np.arange(n) / SR
    f = midi_hz(note)
    x = square(f, n, 0.3) * 0.5 + square(f * 1.004, n, 0.27) * 0.5 + square(f * 2.0, n, 0.4) * 0.2
    y = bp(x, 1100, 0.7) + lp(x, 2500) * 0.6
    trem = 1 + 0.18 * np.sin(2 * np.pi * 6.3 * t)
    return y * trem.astype(np.float32) * env_adsr(n, attack, 0.2, 0.9, release, gate=dur) * 0.45


def brass(note, dur, attack=0.03, release=0.08, bright=1.0):
    n = _n(dur + release)
    t = np.arange(n) / SR
    f = midi_hz(note) * (1 - 0.015 * np.exp(-t / 0.04))
    x = saw(f, n) * 0.6 + saw(f * 1.004, n, 0.5) * 0.4
    fc = 700 + 2600 * bright * np.minimum(1.0, t / max(attack * 2, 1e-3)) * (0.7 + 0.3 * np.exp(-t / 0.3))
    return lp(x, fc, 0.9) * env_adsr(n, attack, 0.3, 0.8, release, gate=dur) * 0.5


def fm_lead(note, dur, ratio=2.0, index=2.0, release=0.08):
    n = _n(dur + release)
    f = float(midi_hz(note))
    t = np.arange(n) / SR
    idx = index * (0.6 + 0.4 * np.exp(-t / 0.2))
    mod = np.sin(2 * np.pi * f * ratio * t) * idx
    x = np.sin(2 * np.pi * f * t + mod).astype(np.float32)
    return x * env_adsr(n, 0.004, 0.25, 0.8, release, gate=dur) * 0.45


def chip(note, dur, duty=0.25, vib=0.0, arp=None, release=0.03):
    """Voix 8 bits (carré à rapport cyclique, arpège optionnel)."""
    n = _n(dur + release)
    t = np.arange(n) / SR
    m = np.full(n, float(note))
    if arp:
        step = (t / 0.035).astype(int) % len(arp)
        m = m + np.asarray(arp)[step]
    f = midi_hz(m) * (1 + vib * 0.01 * np.sin(2 * np.pi * 6 * t))
    x = square(f, n, duty)
    q = np.round(x * 7) / 7
    return q.astype(np.float32) * env_adsr(n, 0.001, 0.1, 0.85, release, gate=dur) * 0.35


# ------------------------------------------------------------------ effets

def riser(dur, start=300.0, end=6000.0, seed=71):
    n = _n(dur)
    t = np.arange(n) / SR
    k = t / dur
    fc = start * (end / start) ** k
    x = bp(noise(n, seed), fc, 2.0) * (k ** 1.5).astype(np.float32)
    return x * 0.8


def downlifter(dur, seed=72):
    n = _n(dur)
    t = np.arange(n) / SR
    k = t / dur
    fc = 6000 * (200 / 6000) ** k
    return bp(noise(n, seed), fc, 1.5) * np.exp(-k * 3).astype(np.float32) * 0.8


def impact(seed=73):
    n = _n(1.6)
    t = np.arange(n) / SR
    boom = sine(45 * (1 + np.exp(-t / 0.05)), n) * env_exp(n, 0.5, 0.001)
    nz = lp(noise(n, seed), 2500) * env_exp(n, 0.2)
    return saturate(boom * 1.4 + nz * 0.4, 1.2)


def siren(dur, base=880.0, rate=2.0):
    n = _n(dur)
    t = np.arange(n) / SR
    f = base * (1 + 0.35 * np.sin(2 * np.pi * rate * t))
    return lp(saw(f, n) * 0.4 + square(f * 0.5, n) * 0.2, 3000) * env_adsr(n, 0.05, 0.2, 1.0, 0.2, gate=dur - 0.2) * 0.5


def vinyl(n_sec, seed=74):
    n = _n(n_sec)
    rng = np.random.default_rng(seed)
    x = np.zeros(n, np.float32)
    pops = rng.integers(0, n, int(n_sec * 9))
    x[pops] = rng.uniform(-1, 1, len(pops))
    x = bp(x, 3000, 0.8) * 0.5 + lp(noise(n, seed + 1), 400) * 0.04
    return x


def scratch(dur=0.25, seed=75):
    n = _n(dur)
    t = np.arange(n) / SR
    speed = np.sin(2 * np.pi * t / dur * 1.5)
    fc = 800 + 2500 * np.abs(speed)
    return bp(noise(n, seed), fc, 3.0) * np.abs(speed).astype(np.float32) * env_adsr(n, 0.005, 0.1, 1.0, 0.03, gate=dur - 0.03) * 1.2


def laser(dur=0.18, f0=2400.0, f1=200.0):
    n = _n(dur)
    t = np.arange(n) / SR
    f = f0 * (f1 / f0) ** (t / dur)
    return square(f, n, 0.5) * env_exp(n, dur * 0.6) * 0.35


def growl(note, dur, rate=8.0):
    """Grognement « grrr » : scie basse modulée en amplitude et formant."""
    n = _n(dur + 0.05)
    t = np.arange(n) / SR
    f = midi_hz(note)
    x = saw(f, n) + saw(f * 1.01, n, 0.5) * 0.7
    am = 0.55 + 0.45 * np.sign(np.sin(2 * np.pi * rate * 2.0 * t))
    fc = 500 + 900 * (0.5 + 0.5 * np.sin(2 * np.pi * rate * t))
    return saturate(bp(x * am.astype(np.float32), fc, 2.5) * 2.0, 2.0) * env_adsr(n, 0.01, 0.2, 0.9, 0.05, gate=dur) * 0.6


def cluck(seed=76):
    """Petit gloussement de poulet (pincement aigu qui chute)."""
    n = _n(0.11)
    t = np.arange(n) / SR
    f = 1300 * np.exp(-t / 0.04) + 500
    x = square(f, n, 0.3) * env_exp(n, 0.03, 0.002)
    return bp(x, 1600, 1.5) * 1.4


def cowbell_note(note, dur=0.2, decay=0.11):
    """Cloche accordée (mélodie de funk/phonk brésilien)."""
    n = _n(max(dur, decay * 4))
    f = float(midi_hz(note))
    x = square(f, n, 0.5) * 0.6 + square(f * 1.482, n, 0.5) * 0.4
    y = bp(x, f * 1.2, 1.3) + bp(x, f * 3.1, 2.5) * 0.35
    e = env_exp(n, 0.018) * 0.5 + env_exp(n, decay) * 0.5
    return y * e * 1.5


def slide_whistle(note_from, note_to, dur):
    n = _n(dur + 0.05)
    t = np.arange(n) / SR
    k = np.clip(t / max(dur, 1e-3), 0, 1)
    f = midi_hz(note_from) * (midi_hz(note_to) / midi_hz(note_from)) ** (k * k * (3 - 2 * k))
    f = f * (1 + 0.006 * np.sin(2 * np.pi * 6.0 * t))
    x = sine(f, n) + hp(noise(n, 77), 3000) * 0.05
    return x * env_adsr(n, 0.02, 0.2, 0.9, 0.05, gate=dur) * 0.5


def tape_stop(note_list, dur=0.6):
    """Arrêt de disque : un accord dont la hauteur s'effondre."""
    n = _n(dur)
    t = np.arange(n) / SR
    k = np.clip(t / dur, 0, 1)
    slow = (1 - k) ** 2
    x = np.zeros(n, np.float32)
    for p in note_list:
        f = midi_hz(p) * (0.05 + 0.95 * slow)
        x += saw(f, n) * 0.3
    return lp(x, 300 + 4000 * slow) * (1 - k).astype(np.float32) * 0.8


def woodblock(pitch=1.0):
    n = _n(0.09)
    x = sine(1150.0 * pitch, n) * env_exp(n, 0.02) + bp(noise(n, 78), 1800 * pitch, 4.0) * env_exp(n, 0.006) * 1.2
    return x * 0.9


def whoosh(dur=0.5, up=True, seed=79):
    n = _n(dur)
    t = np.arange(n) / SR
    k = t / dur
    fc = (400 * (8000 / 400) ** k) if up else (8000 * (400 / 8000) ** k)
    e = np.sin(np.pi * k) ** 2
    return bp(noise(n, seed), fc, 1.2) * e.astype(np.float32) * 0.9
