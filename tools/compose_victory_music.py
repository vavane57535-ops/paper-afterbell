#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Paper Afterbell 0.16 — musique des victoires LMS, composée par code.

Six partitions définitives (une par survivant), calées sur les films de
film_victories.gd, et les ambiances de ces films (pluie, télé, tonnerre).

numpy seul : synthèse additive à filtre variable (cordes, cuivres, chœur,
synthés), Karplus-Strong (pizzicati, harpe, guitare), cloches et percussions
modales, réverbération à convolution, chaîne « haut-parleur de télé », bande
qui s'arrête, compression de bus, limiteur true-peak et normalisation à
-18 LUFS intégrés (mesure ffmpeg ebur128), encodage Ogg Vorbis.

  python3 tools/compose_victory_music.py                 # tout, dans audio/victory/
  python3 tools/compose_victory_music.py --only Simon    # un seul film
  python3 tools/compose_victory_music.py --wav /tmp/x    # garde aussi les .wav
"""
import os
import re
import subprocess
import sys

import numpy as np

SR = 44100
TAU = 2.0 * np.pi
LUFS = -18.0
CEILING = -1.5

# film timings: must follow INK_AT / TAIL in film_victories.gd
INK = {"Ashura": 9.85, "Usayuko": 8.95, "Simon": 9.4, "Lysia": 8.65, "Elly": 8.95, "Bleuette": 8.7}
TAIL = 4.2
CUT, RAIN, FLASH = 2.25, 2.5, 3.3

rng = np.random.default_rng(16)


def S(t):
    return max(0, int(round(t * SR)))


_PC = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def m(x):
    if isinstance(x, (int, float, np.integer, np.floating)):
        return float(x)
    g = re.fullmatch(r"([A-G])([#b]?)(-?\d)", x)
    if not g:
        raise ValueError(x)
    return 12 * (int(g[3]) + 1) + _PC[g[1]] + (1 if g[2] == "#" else -1 if g[2] == "b" else 0)


def hz(x):
    return 440.0 * 2.0 ** ((m(x) - 69.0) / 12.0)


def tr(x, semis):
    return m(x) + semis


# ------------------------------------------------------------------ utils --
def _size(n):
    return 1 << int(np.ceil(np.log2(max(2, n))))


def spectral(x, gain_fn, pad=8192):
    """Zero-phase filter: multiply the spectrum by gain_fn(freqs)."""
    if x.ndim == 2:
        return np.stack([spectral(x[:, c], gain_fn, pad) for c in range(x.shape[1])], axis=1)
    n = len(x)
    size = _size(n + pad)
    spec = np.fft.rfft(x, size)
    f = np.fft.rfftfreq(size, 1.0 / SR)
    return np.fft.irfft(spec * gain_fn(np.maximum(f, 1.0)), size)[:n]


def lp(x, fc, order=2):
    return spectral(x, lambda f: 1.0 / np.sqrt(1.0 + (f / fc) ** (2 * order)))


def hp(x, fc, order=2):
    return spectral(x, lambda f: 1.0 / np.sqrt(1.0 + (fc / f) ** (2 * order)))


def bp(x, lo, hi, order=2):
    return spectral(x, lambda f: 1.0 / np.sqrt(1.0 + (f / hi) ** (2 * order)) / np.sqrt(1.0 + (lo / f) ** (2 * order)))


def bell_eq(x, f0, db, width=1.0):
    g = 10 ** (db / 20.0) - 1.0
    return spectral(x, lambda f: 1.0 + g * np.exp(-(np.log2(f / f0) / width) ** 2))


def shelf(x, f0, db, high=True):
    g = 10 ** (db / 20.0) - 1.0
    def fn(f):
        s = 1.0 / (1.0 + np.exp(-np.log2(f / f0) * 3.0))
        return 1.0 + g * (s if high else 1.0 - s)
    return spectral(x, fn)


def noise(d, seed=None):
    r = rng if seed is None else np.random.default_rng(seed)
    return r.standard_normal(S(d))


def pan2(x, pan=0.0):
    if x.ndim == 2:
        return x
    a = (np.clip(pan, -1.0, 1.0) + 1.0) * np.pi / 4.0
    return np.stack([x * np.cos(a), x * np.sin(a)], axis=1) * np.sqrt(2.0)


def fit(x, n):
    if len(x) >= n:
        return x[:n]
    pad = np.zeros((n - len(x),) + x.shape[1:])
    return np.concatenate([x, pad])


def fade_edges(x, a=0.002, r=0.01):
    x = x.copy()
    ka, kr = min(len(x), S(a)), min(len(x), S(r))
    if ka:
        x[:ka] *= np.linspace(0, 1, ka)[:, None] if x.ndim == 2 else np.linspace(0, 1, ka)
    if kr:
        x[-kr:] *= np.linspace(1, 0, kr)[:, None] if x.ndim == 2 else np.linspace(1, 0, kr)
    return x


def env_adsr(n, a=0.005, d=0.15, s=0.8, r=0.25, gate=None):
    t = np.arange(n) / SR
    if gate is None:
        gate = max(a, n / SR - r)
    att = np.sin(np.clip(t / max(a, 1e-4), 0.0, 1.0) * np.pi / 2.0)
    dec = s + (1.0 - s) * np.exp(-np.maximum(t - a, 0.0) * 4.6 / max(d, 1e-4))
    e = att * dec
    eg = float(np.interp(gate, t, e)) if n else 0.0
    rel = eg * np.exp(-np.maximum(t - gate, 0.0) * 6.9 / max(r, 1e-4))
    e = np.where(t < gate, e, rel)
    k = min(n, S(0.004))
    if k:
        e[-k:] *= np.linspace(1, 0, k)
    return e


def env_perc(n, decay, a=0.001):
    t = np.arange(n) / SR
    e = np.minimum(1.0, t / max(a, 1e-5)) * np.exp(-t * decay)
    k = min(n, S(0.004))
    if k:
        e[-k:] *= np.linspace(1, 0, k)
    return e


def automation(n, points):
    """Piecewise-linear gain curve from [(seconds, gain), ...]."""
    t = np.arange(n) / SR
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    return np.interp(t, xs, ys)


def rms(x):
    return float(np.sqrt(np.mean(np.square(x)) + 1e-12))


def norm_rms(x, level):
    return x * (level / rms(x))


def norm_peak(x, level):
    return x * (level / (np.max(np.abs(x)) + 1e-9))


def sat(x, drive=1.5):
    return np.tanh(x * drive) / np.tanh(drive)


# ------------------------------------------------------------- oscillator --
def _amp(shape, k, pw):
    if shape == "saw":
        return 1.0 / k
    if shape == "square":
        return 0.0 if k % 2 == 0 else 1.0 / k
    if shape == "pulse":
        return np.sin(np.pi * k * pw) / k
    if shape == "tri":
        return 0.0 if k % 2 == 0 else ((-1) ** ((k - 1) // 2)) / (k * k)
    if shape == "voice":
        return 1.0 / k ** 1.25
    if shape == "organ":
        return {1: 1.0, 2: 0.7, 3: 0.5, 4: 0.35, 6: 0.25, 8: 0.2}.get(k, 0.0)
    if shape == "sine":
        return 1.0 if k == 1 else 0.0
    raise ValueError(shape)


VOWELS = {
    # (centre Hz, bandwidth Hz, linear gain) — Peterson & Barney / Klatt style tables
    "a": [(800, 90, 1.0), (1150, 100, 0.5), (2900, 130, 0.03), (3900, 140, 0.1), (4950, 150, 0.004)],
    "o": [(450, 70, 1.0), (800, 80, 0.3), (2830, 110, 0.08), (3800, 130, 0.06), (4950, 140, 0.004)],
    "u": [(325, 50, 1.0), (700, 60, 0.16), (2530, 170, 0.02), (3500, 180, 0.01), (4950, 200, 0.002)],
    "a_low": [(650, 80, 1.0), (1080, 90, 0.45), (2650, 120, 0.25), (2900, 130, 0.2), (3250, 140, 0.05)],
    "o_low": [(400, 60, 1.0), (750, 80, 0.3), (2400, 110, 0.12), (2600, 120, 0.1), (2900, 130, 0.04)],
}


def osc(freq, dur, shape="saw", cutoff=None, slope=2.0, reso=0.0, vib=0.0, vib_rate=5.5,
        vib_delay=0.2, bend=None, drift=0.0, pw=0.5, kmax=200, vowel=None, seed=None, phase=None):
    """Band-limited additive oscillator; `cutoff` (Hz, scalar or per-sample array)
    applies a time-varying low-pass to every partial; `vowel` shapes the partials
    with formants instead."""
    r = rng if seed is None else np.random.default_rng(seed)
    n = S(dur)
    if n == 0:
        return np.zeros(0)
    t = np.arange(n) / SR
    f = np.full(n, float(freq)) if np.isscalar(freq) else np.asarray(freq, float)[:n].copy()
    if bend is not None:
        f = f * 2.0 ** ((np.asarray(bend, float) if not np.isscalar(bend) else bend) / 12.0)
    if vib:
        depth = vib * np.clip((t - vib_delay) / 0.35, 0.0, 1.0)
        f = f * (1.0 + depth * np.sin(TAU * vib_rate * t + r.uniform(0, TAU)))
    if drift:
        f = f * (1.0 + drift * (0.6 * np.sin(TAU * 0.37 * t + r.uniform(0, TAU)) + 0.4 * np.sin(TAU * 1.13 * t + r.uniform(0, TAU))))
    ph = TAU * np.cumsum(f) / SR + (r.uniform(0, TAU) if phase is None else phase)
    fmax = float(f.max())
    K = max(1, min(kmax, int(SR * 0.45 / max(fmax, 1.0))))
    c = None
    if cutoff is not None:
        c = np.full(n, float(cutoff)) if np.isscalar(cutoff) else np.asarray(cutoff, float)[:n]
    table = VOWELS.get(vowel) if vowel else None
    out = np.zeros(n)
    for k in range(1, K + 1):
        a = _amp(shape, k, pw)
        if a == 0.0:
            if shape == "sine":
                break
            continue
        fk = k * f
        h = None
        if table is not None:
            h = 0.004 + sum(g / (1.0 + ((fk - fc) / bw) ** 2) for fc, bw, g in table)
        if c is not None:
            ratio = fk / c
            hc = 1.0 / np.sqrt(1.0 + ratio ** (2.0 * slope))
            if reso:
                hc = hc * (1.0 + reso * np.exp(-(np.log2(np.maximum(ratio, 1e-6)) / 0.28) ** 2))
            h = hc if h is None else h * hc
            if float(np.max(hc)) < 3e-4:
                break
        out += a * (np.sin(k * ph) if h is None else h * np.sin(k * ph))
    return out


def fm(freq, dur, ratio=1.0, index=2.0, index_decay=4.0, decay=3.0, bend=None):
    n = S(dur)
    t = np.arange(n) / SR
    f = np.full(n, float(freq))
    if bend is not None:
        f = f * 2.0 ** (bend / 12.0)
    ph = TAU * np.cumsum(f) / SR
    mod = np.sin(ph * ratio) * index * np.exp(-t * index_decay)
    return np.sin(ph + mod) * np.exp(-t * decay)


# ------------------------------------------------------------ instruments --
def ensemble(note, dur, voices=5, detune=12.0, width=0.8, seed=None, **kw):
    f0 = hz(note)
    out = np.zeros((S(dur), 2))
    r = rng if seed is None else np.random.default_rng(seed)
    for i in range(voices):
        x = (i / (voices - 1)) * 2.0 - 1.0 if voices > 1 else 0.0
        cents = x * detune + r.uniform(-1.5, 1.5)
        sig = osc(f0 * 2.0 ** (cents / 1200.0), dur, seed=int(r.integers(1 << 30)), **kw)
        out += pan2(sig, x * width)
    return out / np.sqrt(voices)


def strings(notes, dur, a=0.3, r=0.8, bright=1.0, trem=0.0, voices=4, level=0.1, vib=0.0045, s=0.9, d=0.4, attack_bite=0.0):
    """Section strings: detuned saws, vibrato fading in, filter tracking the pitch."""
    total = dur + r
    n = S(total)
    out = np.zeros((n, 2))
    t = np.arange(n) / SR
    for note in notes:
        f = hz(note)
        cut = np.full(n, min(7000.0, f * 7.0 * bright + 900.0 * bright))
        if attack_bite:
            cut = cut * (1.0 + attack_bite * np.exp(-t * 18.0))
        sig = ensemble(note, total, voices=voices, detune=9.0, width=0.75, shape="saw", cutoff=cut,
                       slope=1.4, vib=vib, vib_rate=5.3, vib_delay=0.15, drift=0.0007)
        e = env_adsr(n, a, d, s, r, gate=dur)
        if trem:
            e = e * (0.45 + 0.55 * np.abs(np.sin(TAU * trem * 0.5 * t)) ** 1.5)
        out += sig * e[:, None]
    out = hp(out, 55.0)
    out = bell_eq(out, 2600.0, -1.5, 1.2)
    return norm_rms(out, level * np.sqrt(len(notes)) * 0.7) if np.any(out) else out


def brass(notes, dur, level=1.0, a=0.035, r=0.35, voices=3, gain=0.1, s=0.85, scoop=0.35, vib=0.003, mellow=False):
    """Brass section: saw with a blaring filter envelope, a lip scoop, breath."""
    total = dur + r
    n = S(total)
    t = np.arange(n) / SR
    out = np.zeros((n, 2))
    for note in notes:
        f = hz(note)
        top = (5.5 if mellow else 9.0) * level
        cut = f * (1.6 + top * (1.0 - np.exp(-t / 0.045)) * (0.7 + 0.3 * np.exp(-t / 0.25)))
        cut = np.minimum(cut, 7500.0)
        bend = -scoop * np.exp(-t / 0.035)
        sig = ensemble(note, total, voices=voices, detune=7.0, width=0.6, shape="saw", cutoff=cut,
                       slope=1.7, bend=bend, vib=vib, vib_rate=5.0, vib_delay=0.35, drift=0.0006)
        e = env_adsr(n, a, 0.2, s, r, gate=dur)
        out += sig * e[:, None]
    breath = bp(noise(total), 1200, 5000) * env_adsr(n, 0.02, 0.1, 0.15, r, gate=dur) * 0.03
    out += pan2(breath)
    out = hp(out, 60.0)
    return norm_rms(out, gain * np.sqrt(len(notes)) * 0.7) if np.any(out) else out


def choir(notes, dur, vowel="a", a=0.35, r=0.9, voices=5, gain=0.08, vib=0.006):
    total = dur + r
    n = S(total)
    out = np.zeros((n, 2))
    for note in notes:
        low = m(note) < 60
        v = (vowel + "_low") if low and (vowel + "_low") in VOWELS else vowel
        sig = ensemble(note, total, voices=voices, detune=14.0, width=0.9, shape="voice", vowel=v,
                       vib=vib, vib_rate=5.1, vib_delay=0.25, drift=0.0012, kmax=80)
        out += sig * env_adsr(n, a, 0.3, 0.92, r, gate=dur)[:, None]
    air = bp(noise(total), 1800, 7000) * env_adsr(n, a, 0.3, 0.8, r, gate=dur) * 0.02
    out += pan2(air)
    out = hp(out, 90.0)
    return norm_rms(out, gain * np.sqrt(len(notes)) * 0.7) if np.any(out) else out


def supersaw(notes, dur, a=0.01, r=0.4, cutoff=6000.0, voices=7, detune=22.0, gain=0.1, s=0.85, d=0.3, slope=1.5):
    total = dur + r
    n = S(total)
    out = np.zeros((n, 2))
    for note in notes:
        sig = ensemble(note, total, voices=voices, detune=detune, width=1.0, shape="saw", cutoff=cutoff, slope=slope, kmax=120)
        out += sig * env_adsr(n, a, d, s, r, gate=dur)[:, None]
    out = hp(out, 70.0)
    return norm_rms(out, gain * np.sqrt(len(notes)) * 0.7) if np.any(out) else out


def lead(note, dur, kind="saw", gain=0.1, a=0.008, r=0.18, cutoff=5200.0, vib=0.006, glide_from=None, glide=0.05, s=0.85, pw=0.25):
    total = dur + r
    n = S(total)
    t = np.arange(n) / SR
    bend = None
    if glide_from is not None:
        bend = (m(glide_from) - m(note)) * np.exp(-t / glide)
    if kind == "saw":
        sig = ensemble(note, total, voices=3, detune=10.0, width=0.5, shape="saw", cutoff=cutoff, slope=1.6,
                       vib=vib, vib_rate=5.8, vib_delay=0.18, bend=bend)
    elif kind == "chip":
        sig = pan2(osc(hz(note), total, "pulse", pw=pw, vib=vib, vib_rate=6.0, vib_delay=0.15, bend=bend, kmax=60))
    elif kind == "square":
        sig = pan2(osc(hz(note), total, "square", cutoff=cutoff, vib=vib, vib_delay=0.15, bend=bend))
    elif kind == "whistle":
        tone = osc(hz(note), total, "sine", vib=0.012, vib_rate=5.2, vib_delay=0.08, bend=bend)
        tone += 0.05 * osc(hz(note) * 2, total, "sine", vib=0.012, vib_rate=5.2, vib_delay=0.08, bend=bend)
        breath = bp(noise(total), hz(note) * 0.9, hz(note) * 1.3, 2) * 0.25
        sig = pan2(tone + breath)
    elif kind == "trumpet":
        return brass([note], dur, level=1.2, voices=1, gain=gain * 1.4, r=r, scoop=0.6, vib=0.006)
    else:
        raise ValueError(kind)
    e = env_adsr(n, a, 0.15, s, r, gate=dur)
    # leads carry the motifs: they sit 3 dB over the arrangement
    return norm_rms(sig * e[:, None], gain * 1.4)


def synth_pluck(note, dur=0.3, shape="saw", top=6000.0, bottom=300.0, decay=12.0, gain=0.1, reso=0.6, amp_decay=None, pw=0.5):
    n = S(dur)
    t = np.arange(n) / SR
    cut = bottom + (top - bottom) * np.exp(-t * decay)
    sig = osc(hz(note), dur, shape, cutoff=cut, slope=2.0, reso=reso, pw=pw)
    e = env_perc(n, amp_decay if amp_decay is not None else decay * 0.45, 0.002)
    return norm_peak(sig * e, gain * 3.0)


def karplus(note, dur, bright=0.6, decay=0.996, gain=0.3, pick=0.15, seed=None):
    """Karplus-Strong string, computed one period at a time."""
    f = hz(note)
    period = max(2, int(SR / f))
    real = SR / period
    n = S(dur) + 2
    r = rng if seed is None else np.random.default_rng(seed)
    exc = r.uniform(-1, 1, period)
    exc = lp(exc, 800 + 9000 * bright, 1) if period > 64 else exc
    # comb by pick position
    k = max(1, int(period * pick))
    exc = exc - np.roll(exc, k)
    y = np.zeros(n)
    y[:period] = exc
    y[period] = decay * y[0]
    s = period + 1
    while s < n:
        e = min(n, s + period)
        y[s:e] = decay * (0.5 * y[s - period:e - period] + 0.5 * y[s - period - 1:e - period - 1])
        s = e
    # retune: period is an integer, resample to the exact pitch
    out = np.interp(np.arange(S(dur)) * (f / real), np.arange(n), y)
    out = fade_edges(out, 0.0005, 0.02)
    return norm_peak(out, gain)


def pizz(note, dur=0.45, gain=0.3):
    x = karplus(note, dur, bright=0.35, decay=0.988, gain=1.0, pick=0.2)
    x = bell_eq(x, 350.0, 4.0, 1.0)
    return norm_peak(x * env_perc(len(x), 4.5, 0.002), gain)


def harp(note, dur=1.6, gain=0.25):
    x = karplus(note, dur, bright=0.55, decay=0.9975, gain=1.0, pick=0.12)
    return norm_peak(x, gain)


def guitar(note, dur=1.4, gain=0.25):
    x = karplus(note, dur, bright=0.7, decay=0.997, gain=1.0, pick=0.1)
    x = bell_eq(x, 2400.0, 3.0, 1.0)
    return norm_peak(x, gain)


BELLS = {
    "celesta": [(1.0, 1.0, 2.2), (2.0, 0.22, 4.5), (3.0, 0.06, 7.0), (4.07, 0.05, 10.0)],
    "glock": [(1.0, 1.0, 1.1), (2.76, 0.32, 3.5), (5.40, 0.12, 7.0), (8.93, 0.05, 11.0)],
    "musicbox": [(1.0, 1.0, 2.4), (2.0, 0.28, 4.0), (5.03, 0.13, 9.0), (8.9, 0.05, 15.0)],
    "chime": [(1.0, 1.0, 0.7), (2.76, 0.45, 1.5), (5.40, 0.25, 2.6), (8.93, 0.12, 4.0), (13.3, 0.05, 6.0)],
    "anvil": [(1.0, 1.0, 5.0), (2.31, 0.7, 7.0), (3.86, 0.5, 9.0), (5.12, 0.35, 12.0), (7.43, 0.2, 15.0)],
    "tink": [(1.0, 1.0, 14.0), (2.61, 0.5, 22.0), (4.73, 0.3, 30.0)],
}


def bell(note, kind="glock", dur=2.0, gain=0.25, bend=0.0):
    f = hz(note)
    n = S(dur)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for ratio, amp, dec in BELLS[kind]:
        fk = f * ratio
        if fk > SR * 0.45:
            continue
        ff = fk * 2.0 ** (bend * np.minimum(1.0, t / 0.6) / 12.0) if bend else fk
        ph = TAU * np.cumsum(np.full(n, ff) if np.isscalar(ff) else ff) / SR
        out += amp * np.sin(ph + rng.uniform(0, TAU)) * np.exp(-t * dec)
    click = hp(noise(0.01), 3000) * env_perc(S(0.01), 600.0) * 0.15
    out[: len(click)] += click
    out *= np.minimum(1.0, t / 0.0015)
    return norm_peak(fade_edges(out, 0.0, 0.03), gain)


# ---------------------------------------------------------------- drums ---
def kick(gain=0.8, f0=150.0, f1=45.0, decay=7.0, click=0.3, dur=0.55):
    n = S(dur)
    t = np.arange(n) / SR
    f = f1 + (f0 - f1) * np.exp(-t * 28.0)
    body = np.sin(TAU * np.cumsum(f) / SR) * np.exp(-t * decay)
    body = sat(body, 1.6)
    c = hp(noise(dur), 1500) * np.exp(-t * 300.0) * click
    return norm_peak(body + c, gain * 0.75)


def snare(gain=0.5, tone=190.0, decay=16.0, dur=0.4, bright=1.0):
    n = S(dur)
    t = np.arange(n) / SR
    body = (np.sin(TAU * tone * t) * 0.7 + np.sin(TAU * tone * 1.73 * t) * 0.35) * np.exp(-t * 28.0)
    wires = bp(noise(dur), 1400 * bright, 9500, 1) * np.exp(-t * decay)
    return norm_peak(body * 0.6 + wires, gain)


def clap(gain=0.4):
    d = 0.3
    n = S(d)
    t = np.arange(n) / SR
    e = np.zeros(n)
    for off in (0.0, 0.011, 0.023, 0.034):
        e += np.where(t >= off, np.exp(-(t - off) * 140.0), 0.0) * (t >= off)
    e += np.where(t >= 0.034, 0.5 * np.exp(-(t - 0.034) * 16.0), 0.0)
    x = bp(noise(d), 900, 6000, 2) * e
    return norm_peak(x, gain)


_METAL = [205.3, 304.4, 369.6, 522.7, 540.0, 800.0]


def metal(d):
    t = np.arange(S(d)) / SR
    return sum(np.sign(np.sin(TAU * f * t + rng.uniform(0, TAU))) for f in _METAL) / 6.0


def hat(gain=0.15, decay=45.0, dur=0.12):
    n = S(dur)
    t = np.arange(n) / SR
    x = hp(0.6 * metal(dur) + 0.6 * noise(dur), 7000, 3) * np.exp(-t * decay)
    return norm_peak(x, gain)


def crash(gain=0.35, dur=2.6, decay=1.5, bright=1.0):
    n = S(dur)
    t = np.arange(n) / SR
    m1 = metal(dur)
    x = hp(0.5 * m1 * np.exp(-t * 5.0) + noise(dur) * (0.35 + 0.65 * np.exp(-t * 10.0)), 2600 * bright, 2) * np.exp(-t * decay)
    x = shelf(x, 9000, -4)
    x *= np.minimum(1.0, t / 0.003)
    return norm_peak(fade_edges(x, 0.0, 0.2), gain)


def reverse_crash(dur=0.9, gain=0.3):
    x = crash(1.0, dur * 1.4, 2.4)[: S(dur * 1.4)][::-1][-S(dur):]
    x = x * np.linspace(0.0, 1.0, len(x)) ** 1.5
    return norm_peak(x, gain)


def tom(note, gain=0.6, decay=7.0, dur=0.7):
    n = S(dur)
    t = np.arange(n) / SR
    f = hz(note) * (1.0 + 0.35 * np.exp(-t * 20.0))
    x = np.sin(TAU * np.cumsum(f) / SR) * np.exp(-t * decay) + 0.25 * lp(noise(dur), 2000) * np.exp(-t * 35.0)
    return norm_peak(x, gain)


def taiko(note="D2", gain=0.9, dur=1.6, decay=4.5):
    f = hz(note)
    n = S(dur)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for ratio, amp, dec in [(1.0, 1.0, decay), (1.59, 0.45, decay * 1.8), (2.14, 0.3, decay * 2.4), (2.65, 0.15, decay * 3.0)]:
        fr = f * ratio * (1.0 + 0.22 * np.exp(-t * 22.0))
        out += amp * np.sin(TAU * np.cumsum(fr) / SR) * np.exp(-t * dec)
    slap = lp(noise(dur), 1400, 2) * np.exp(-t * 32.0) * 0.6
    body = lp(noise(dur), 260, 2) * np.exp(-t * 7.0) * 0.8
    x = sat(out + slap + body, 1.3)
    return norm_peak(x, gain)


def timpani(note="D2", gain=0.8, dur=3.0, mallet=1.0):
    f = hz(note)
    n = S(dur)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for ratio, amp, dec in [(0.62, 0.6, 9.0), (1.0, 1.0, 1.4), (1.5, 0.55, 2.2), (1.99, 0.38, 3.0), (2.44, 0.22, 4.0), (2.9, 0.12, 5.0)]:
        out += amp * np.sin(TAU * f * ratio * t + rng.uniform(0, TAU)) * np.exp(-t * dec)
    hit = lp(noise(dur), 900 * mallet, 2) * np.exp(-t * 45.0) * 0.5
    x = (out + hit) * np.minimum(1.0, t / 0.002)
    return norm_peak(fade_edges(x, 0.0, 0.1), gain)


def timp_roll(note, dur, gain=0.6, rate=17.0, start=0.25, end=1.0):
    total = dur + 2.0
    out = np.zeros(S(total))
    k = 0
    t = 0.0
    while t < dur:
        u = t / dur
        g = start + (end - start) * u ** 1.5
        hit = timpani(note, 1.0 * g * rng.uniform(0.85, 1.0), 2.0, 0.6)
        i = S(t)
        out[i:i + len(hit)] += hit[: len(out) - i]
        t += 1.0 / rate * rng.uniform(0.9, 1.1)
        k += 1
    return norm_peak(out, gain)


def snare_roll(dur, gain=0.35, rate=24.0, start=0.15, end=1.0, accel=0.0):
    out = np.zeros(S(dur + 0.4))
    t = 0.0
    while t < dur:
        u = t / dur
        g = start + (end - start) * u ** 1.4
        hit = snare(g * rng.uniform(0.8, 1.0), decay=22.0, dur=0.25)
        i = S(t)
        out[i:i + len(hit)] += hit[: len(out) - i]
        t += 1.0 / (rate * (1.0 + accel * u))
    return norm_peak(out, gain)


def boom(gain=0.9, dur=2.4, f0=70.0, f1=34.0, grit=0.35):
    n = S(dur)
    t = np.arange(n) / SR
    f = f1 + (f0 - f1) * np.exp(-t * 6.0)
    sub = np.sin(TAU * np.cumsum(f) / SR) * np.exp(-t * 1.9)
    rumble = lp(noise(dur), 220, 2) * np.exp(-t * 2.2) * 0.9
    crack = bp(noise(dur), 1500, 7000) * np.exp(-t * 18.0) * grit
    x = sat(sub * 1.2 + rumble + crack, 1.6) * np.minimum(1.0, t / 0.002)
    return norm_peak(fade_edges(x, 0.0, 0.2), gain)


def gong(note="B1", gain=0.5, dur=4.5):
    f = hz(note)
    n = S(dur)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for ratio, amp, dec in [(1.0, 1.0, 0.7), (1.42, 0.6, 0.9), (2.11, 0.5, 1.1), (2.73, 0.4, 1.4), (3.36, 0.3, 1.6), (4.6, 0.25, 2.0), (5.8, 0.15, 2.4)]:
        swell = 1.0 - 0.6 * np.exp(-t * 3.0) if ratio > 2 else 1.0
        out += amp * np.sin(TAU * f * ratio * t * (1.0 + 0.004 * np.exp(-t)) + rng.uniform(0, TAU)) * np.exp(-t * dec) * swell
    out += lp(noise(dur), 600) * np.exp(-t * 8.0) * 0.4
    return norm_peak(fade_edges(out, 0.0, 0.4), gain)


def braam(notes, dur=1.6, gain=0.35):
    out = brass(notes, dur, level=1.6, a=0.01, r=0.6, voices=4, gain=1.0, scoop=0.8)
    out = sat(out * 2.5, 2.0)
    out = lp(out, 3200)
    return norm_rms(out, gain)


def riser(dur, gain=0.3, lo=300.0, hi=9000.0, bands=14, curve=2.0):
    n = S(dur)
    t = np.arange(n) / SR
    u = t / dur
    src = noise(dur)
    out = np.zeros(n)
    centres = lo * (hi / lo) ** (np.arange(bands) / (bands - 1))
    pos = u ** 1.2 * (bands - 1)
    for i, c in enumerate(centres):
        part = bp(src, c / 1.35, c * 1.35, 2)
        w = np.clip(1.0 - np.abs(pos - i) / 1.6, 0.0, 1.0)
        out += part * w
    out *= u ** curve
    return norm_peak(fade_edges(out, 0.0, 0.01), gain)


def whoosh(dur=0.6, gain=0.3, lo=400.0, hi=4500.0):
    n = S(dur)
    t = np.arange(n) / SR
    u = t / dur
    src = noise(dur)
    out = np.zeros(n)
    bands = 9
    centres = lo * (hi / lo) ** (np.arange(bands) / (bands - 1))
    pos = np.sin(np.pi * u) * (bands - 1)
    for i, c in enumerate(centres):
        out += bp(src, c / 1.4, c * 1.4, 2) * np.clip(1.0 - np.abs(pos - i) / 1.5, 0.0, 1.0)
    out *= np.sin(np.pi * u) ** 2
    return norm_peak(out, gain)


def zap(dur=0.4, gain=0.25, f=1200.0, down=24.0):
    n = S(dur)
    t = np.arange(n) / SR
    bend = -down * (t / dur) ** 0.6
    x = fm(f, dur, ratio=1.41, index=5.0, index_decay=6.0, decay=7.0, bend=bend)
    x = sat(x * 1.5, 1.5)
    return norm_peak(fade_edges(x, 0.0005, 0.02), gain)


def crackle(dur, gain=0.15, density=60.0):
    out = np.zeros(S(dur))
    count = int(density * dur)
    for _ in range(count):
        i = int(rng.integers(0, max(1, len(out) - 300)))
        k = int(rng.integers(30, 260))
        out[i:i + k] += rng.standard_normal(k) * np.exp(-np.arange(k) / (k * 0.3)) * rng.uniform(0.2, 1.0)
    return norm_peak(hp(out, 1800), gain)


def heartbeat(gain=0.5):
    d = 0.5
    n = S(d)
    t = np.arange(n) / SR
    one = np.sin(TAU * np.cumsum(55.0 + 40.0 * np.exp(-t * 30.0)) / SR) * np.exp(-t * 14.0)
    two = np.zeros(n)
    k = S(0.17)
    two[k:] = 0.7 * one[: n - k]
    return norm_peak(lp(one + two, 400), gain)


def slide_whistle(dur=0.4, n0="C7", n1="C5", gain=0.2):
    n = S(dur)
    t = np.arange(n) / SR
    u = t / dur
    f = hz(n0) * (hz(n1) / hz(n0)) ** (u ** 0.8)
    x = np.sin(TAU * np.cumsum(f * (1 + 0.004 * np.sin(TAU * 7 * t))) / SR)
    x += 0.12 * bp(noise(dur), 1500, 6000)
    return norm_peak(x * env_adsr(n, 0.02, 0.1, 0.9, 0.08), gain)


def steam(dur=1.2, gain=0.2):
    n = S(dur)
    t = np.arange(n) / SR
    x = hp(noise(dur), 2500, 2) * (np.minimum(1.0, t / 0.03) * np.exp(-t * 2.2))
    return norm_peak(x, gain)


# ----------------------------------------------------------------- reverb --
def make_ir(seconds=2.8, t60_lo=2.4, t60_hi=0.8, predelay=0.018, seed=3, early=10, damp=11000.0):
    r = np.random.default_rng(seed)
    n = S(seconds)
    t = np.arange(n) / SR
    out = np.zeros((n, 2))
    edges = [20, 160, 400, 900, 1800, 3500, 7000, 20000]
    for ch in range(2):
        src = r.standard_normal(n)
        spec = np.fft.rfft(src, _size(n))
        f = np.fft.rfftfreq(_size(n), 1.0 / SR)
        ir = np.zeros(n)
        for lo, hi in zip(edges[:-1], edges[1:]):
            mask = 1.0 / np.sqrt(1.0 + (np.maximum(f, 1) / hi) ** 8) / np.sqrt(1.0 + (lo / np.maximum(f, 1)) ** 8)
            part = np.fft.irfft(spec * mask, _size(n))[:n]
            fc = np.sqrt(lo * hi)
            t60 = float(np.interp(np.log(fc), [np.log(150), np.log(8000)], [t60_lo, t60_hi]))
            ir += part * np.exp(-6.9 * t / t60)
        ir = lp(ir, damp, 1)
        onset = np.clip((t - predelay) / 0.02, 0.0, 1.0)
        ir *= onset
        for _ in range(early):
            at = predelay * 0.5 + r.uniform(0.004, 0.07)
            ir[S(at)] += r.uniform(-1, 1) * 2.5 * np.exp(-at * 18)
        out[:, ch] = ir
    out /= np.sqrt(np.sum(out ** 2) / 2.0)
    return out


_IR = {}


def ir(kind):
    if kind not in _IR:
        if kind == "hall":
            _IR[kind] = make_ir(3.2, 2.6, 0.9, 0.022, 11, 12, 9500)
        elif kind == "room":
            _IR[kind] = make_ir(1.1, 0.75, 0.35, 0.008, 12, 14, 12000)
        elif kind == "tv":
            _IR[kind] = make_ir(0.5, 0.32, 0.18, 0.004, 13, 8, 6000)
        elif kind == "plate":
            _IR[kind] = make_ir(2.2, 1.6, 1.2, 0.01, 14, 4, 14000)
    return _IR[kind]


def convolve(x, h):
    n = len(x)
    size = _size(n + len(h))
    out = np.zeros((n, 2))
    for c in range(2):
        out[:, c] = np.fft.irfft(np.fft.rfft(x[:, c], size) * np.fft.rfft(h[:, c], size), size)[:n]
    return out


# -------------------------------------------------------------------- mix --
class Mix:
    SENDS = ("hall", "room", "plate")

    def __init__(self, seconds):
        self.n = S(seconds)
        self.bus = {k: np.zeros((self.n, 2)) for k in ("main", "tv") + self.SENDS}

    def add(self, sig, at, gain=1.0, pan=0.0, hall=0.0, room=0.0, plate=0.0, bus="main"):
        st = pan2(np.asarray(sig, float), pan)
        i = S(at)
        if i >= self.n or len(st) == 0:
            return
        j = min(self.n, i + len(st))
        piece = st[: j - i] * gain
        self.bus[bus][i:j] += piece
        for name, amount in (("hall", hall), ("room", room), ("plate", plate)):
            if amount:
                self.bus[name][i:j] += piece * amount

    def render(self):
        out = self.bus["main"].copy()
        for name in self.SENDS:
            if np.any(self.bus[name]):
                out += convolve(self.bus[name], ir(name))
        if np.any(self.bus["tv"]):
            out += tv_speaker(self.bus["tv"])
        return out


def tv_speaker(x):
    """Old CRT set: mono, narrow band, wow and flutter, a little cabinet."""
    mono = x.mean(axis=1)
    n = len(mono)
    t = np.arange(n) / SR
    delay = (0.0045 + 0.0016 * np.sin(TAU * 0.55 * t) + 0.00035 * np.sin(TAU * 6.1 * t)) * SR
    mono = np.interp(np.arange(n) - delay, np.arange(n), mono)
    mono = bp(mono, 320.0, 3600.0, 2)
    mono = bell_eq(mono, 1150.0, 4.0, 0.8)
    mono = np.tanh(mono * 2.4) / 2.4
    st = pan2(mono) * 0.5
    return st + convolve(st, ir("tv")) * 0.35


def glitch(x, t0, t1, seed=5, crush=True):
    """Stutters, sample-rate and bit reduction growing across [t0, t1]."""
    r = np.random.default_rng(seed)
    y = x.copy()
    i0, i1 = S(t0), min(len(x), S(t1))
    i = i0
    while i < i1:
        u = (i - i0) / max(1, i1 - i0)
        k = int(S(r.uniform(0.025, 0.07)))
        e = min(i1, i + k)
        chunk = x[i:e].copy()
        if r.random() < 0.25 + 0.5 * u and i - k >= i0:
            chunk = x[i - k:i - k + (e - i)].copy()
        if crush:
            hold = 1 + int(u * 7)
            if hold > 1:
                idx = (np.arange(len(chunk)) // hold) * hold
                chunk = chunk[idx]
            bits = 2 ** (8 - int(u * 4))
            chunk = np.round(chunk * bits) / bits
        y[i:e] = chunk
        i = e
    return y


def tape_stop(x, t0, dur=0.45):
    i0 = S(t0)
    n = min(S(dur), len(x) - i0)
    if n <= 0:
        return x
    u = np.arange(n) / n
    rate = (1.0 - u) ** 1.7
    pos = np.cumsum(rate)
    y = x.copy()
    for c in range(x.shape[1]):
        y[i0:i0 + n, c] = np.interp(i0 + pos, np.arange(len(x)), x[:, c])
    y[i0:i0 + n] *= (1.0 - np.clip((u - 0.65) / 0.35, 0.0, 1.0))[:, None]
    y[i0 + n:] = 0.0
    return y


def gate(x, t0, t1, fade=0.012):
    a, b = S(t0), min(len(x), S(t1))
    y = x.copy()
    k = min(S(fade), a)
    if k:
        y[a - k:a] *= np.linspace(1, 0, k)[:, None]
    y[a:b] = 0.0
    return y


# -------------------------------------------------------------- mastering --
def measure(x):
    pcm = np.clip(x, -1.0, 1.0).astype("<f4").tobytes()
    res = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-",
                          "-af", "ebur128=peak=true", "-f", "null", "-"], input=pcm, capture_output=True)
    text = res.stderr.decode("utf-8", "replace")
    summary = text[text.rfind("Summary:"):]
    i = float(re.search(r"I:\s+(-?[\d.]+|-inf)\s+LUFS", summary).group(1))
    peak = re.search(r"True peak:\s+Peak:\s+(-?[\d.]+|-inf)", summary)
    return i, float(peak.group(1)) if peak else 0.0


def _oversampled_peak(x, factor=4):
    n = len(x)
    size = _size(n)
    peaks = np.zeros(n)
    for c in range(x.shape[1]):
        spec = np.fft.rfft(x[:, c], size)
        up = np.fft.irfft(spec, size * factor)[: n * factor] * factor
        peaks = np.maximum(peaks, np.abs(up).reshape(n, factor).max(axis=1))
    return peaks


def _min_filter(x, k):
    """Centred running minimum over k samples (van Herk / Gil-Werman)."""
    if k <= 1:
        return x
    n = len(x)
    pad = np.pad(x, (k // 2, k - 1 - k // 2), mode="edge")
    total = int(np.ceil(len(pad) / k)) * k
    pad = np.pad(pad, (0, total - len(pad)), mode="edge").reshape(-1, k)
    prefix = np.minimum.accumulate(pad, axis=1).ravel()
    suffix = np.minimum.accumulate(pad[:, ::-1], axis=1)[:, ::-1].ravel()
    return np.minimum(suffix[:n], prefix[k - 1:k - 1 + n])


def _moving_avg(x, k):
    if k <= 1:
        return x
    c = np.cumsum(np.pad(x, (k // 2 + 1, k - 1 - k // 2), mode="edge"))
    return (c[k:] - c[:-k]) / k


def limiter(x, ceiling_db=CEILING, look=0.005, release=0.06):
    c = 10 ** (ceiling_db / 20.0)
    p = _oversampled_peak(x)
    g = np.minimum(1.0, c / np.maximum(p, 1e-9))
    L = S(look)
    gm = _min_filter(g, 2 * L + 1)
    # every averaged window contains the sample, so the gain never exceeds g
    R = max(S(release), L + 1)
    gain = _moving_avg(_min_filter(gm, R), R)
    y = x * gain[:, None]
    # safety on the sample peaks left by the smoothing
    return np.clip(y, -c, c)


def glue(x, ratio=2.0, window=0.04, smooth=0.08, above=4.0):
    level = np.sqrt(_moving_avg(np.mean(x ** 2, axis=1), S(window)) + 1e-12)
    db = 20 * np.log10(level)
    live = db[db > -60]
    if len(live) == 0:
        return x
    thr = np.percentile(live, 80) - above
    gr = np.minimum(0.0, (thr - db) * (1.0 - 1.0 / ratio))
    gr = _moving_avg(gr, S(smooth))
    return x * (10 ** (gr / 20.0))[:, None]


def master(x, target=LUFS):
    # tone: clean sub, a touch of presence, softer air (matched by ear-less
    # long-term spectrum against the game's orchestral tracks)
    # the 808 tails, booms and reese subs piled up around 40 Hz (4 to 10 dB above
    # the game's LMS tracks in the 35-50 Hz band): steeper high-pass and a dip there
    x = hp(x, 38.0, 4)
    x = bell_eq(x, 45.0, -4.0, 0.6)
    x = shelf(x, 70.0, -1.5, high=False)
    x = bell_eq(x, 2800.0, 1.5, 1.2)
    x = shelf(x, 9000.0, -4.0, high=True)
    x = glue(x)
    for _ in range(3):
        level, _peak = measure(x)
        x = x * 10 ** ((target - level) / 20.0)
        x = limiter(x)
    level, peak = measure(x)
    return x, level, peak


def write_ogg(x, path, wav_dir=None, quality=6):
    pcm = np.clip(x, -1.0, 1.0).astype("<f4").tobytes()
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", str(quality), path], input=pcm, check=True)
    if wav_dir:
        os.makedirs(wav_dir, exist_ok=True)
        wav = os.path.join(wav_dir, os.path.basename(path).replace(".ogg", ".wav"))
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-",
                        "-c:a", "pcm_s16le", wav], input=pcm, check=True)


def reese(note, dur, cutoff=700.0, gain=0.12, lfo=0.0, depth=0.0, r=0.08, drive=1.6, sub=0.8, open_to=None):
    total = dur + r
    n = S(total)
    t = np.arange(n) / SR
    cut = np.full(n, float(cutoff))
    if open_to:
        cut = cutoff * (open_to / cutoff) ** np.clip(t / max(dur, 0.01), 0.0, 1.0)
    if np.any(lfo):
        rate = np.full(n, float(lfo)) if np.isscalar(lfo) else np.pad(np.asarray(lfo, float)[:n], (0, max(0, n - len(lfo))), mode="edge")
        cut = cut * (1.0 + depth * np.sin(TAU * np.cumsum(rate) / SR - np.pi / 2))
    sig = ensemble(note, total, voices=2, detune=16.0, width=0.35, shape="saw", cutoff=np.maximum(cut, 40.0), slope=2.0, reso=0.5)
    low = pan2(osc(hz(note), total, "sine"))
    x = (sig + low * sub) * env_adsr(n, 0.006, 0.1, 0.95, r, gate=dur)[:, None]
    x = sat(x * drive, 1.3)
    return norm_rms(x, gain)


def gliss(n0, n1, dur, level=0.06, trem=0.0, bright=0.9, a=0.1, r=0.2, voices=4, curve=1.0):
    """String section sliding from n0 to n1."""
    total = dur + r
    n = S(total)
    t = np.arange(n) / SR
    semis = (m(n1) - m(n0)) * np.clip(t / dur, 0.0, 1.0) ** curve
    sig = ensemble(n0, total, voices=voices, detune=9.0, width=0.75, shape="saw",
                   cutoff=min(7000.0, hz(n1) * 7.0 * bright), slope=1.4, bend=semis, vib=0.004, vib_delay=0.1)
    e = env_adsr(n, a, 0.2, 0.95, r, gate=dur)
    if trem:
        e = e * (0.45 + 0.55 * np.abs(np.sin(TAU * trem * 0.5 * t)) ** 1.5)
    return norm_rms(sig * e[:, None], level)


def boing(note, dur=0.5, gain=0.15):
    n = S(dur)
    t = np.arange(n) / SR
    f = hz(note) * (1.0 + 0.25 * np.sin(TAU * 14.0 * t) * np.exp(-t * 7.0))
    x = np.sin(TAU * np.cumsum(f) / SR) + 0.3 * np.sin(2 * TAU * np.cumsum(f) / SR)
    return norm_peak(x * env_perc(n, 6.0, 0.003), gain)


def trance_gate(x, step, pattern, duty=0.8, smooth=0.004):
    n = len(x)
    t = np.arange(n) / SR
    idx = (t // step).astype(int)
    within = t - idx * step
    on = np.asarray(pattern, float)[idx % len(pattern)]
    env = on * np.minimum(1.0, within / smooth) * np.clip((step * duty - within) / smooth, 0.0, 1.0)
    return x * env[:, None] if x.ndim == 2 else x * env


def click(gain=0.2, f=3500.0):
    d = 0.02
    return norm_peak(bp(noise(d), f * 0.6, f * 1.8, 2) * env_perc(S(d), 300.0), gain)


def ratchet(gain=0.15, teeth=3, gap=0.016):
    out = np.zeros(S(gap * teeth + 0.03))
    for k in range(teeth):
        c = click(gain * (1.0 - 0.15 * k), 4200 - 400 * k)
        i = S(k * gap)
        out[i:i + len(c)] += c[: len(out) - i]
    return out


def flute(note, dur, gain=0.08, a=0.04, r=0.12):
    total = dur + r
    n = S(total)
    tone = osc(hz(note), total, "tri", vib=0.006, vib_rate=5.0, vib_delay=0.12) + 0.25 * osc(hz(note) * 2, total, "sine")
    breath = bp(noise(total), hz(note) * 1.5, hz(note) * 6.0, 1) * 0.12
    return norm_rms((tone + breath) * env_adsr(n, a, 0.1, 0.9, r, gate=dur), gain)


# ----------------------------------------------------------------- pieces --
class Piece:
    """One film: `op` is the television opening (cut dead at 2.25 s), `mx` the
    memory in the rain and the paper cut (faded with the paper going black),
    `tv` the television outro (the tape stops when the set goes off)."""

    def __init__(self, name, root):
        self.name = name
        self.root = root
        self.ink = INK[name]
        self.total = self.ink + TAIL
        self.back = self.ink + 2.6
        self.off = self.back + 0.8
        self.op = Mix(self.total)
        self.mx = Mix(self.total)
        self.tv = Mix(self.total)
        # dB below 150 Hz, for the scores built on taikos and big basses
        self.low_shelf = 0.0

    def render(self):
        self.op.bus["tv"] = glitch(self.op.bus["tv"], 1.58, CUT, seed=len(self.name))
        opening = gate(self.op.render(), CUT, self.total, 0.006)
        film = self.mx.render()
        film *= automation(len(film), [(0, 1), (self.ink + 1.5, 1), (self.ink + 2.45, 0), (self.total, 0)])[:, None]
        outro = self.tv.render()
        out = opening + film + outro
        out = tape_stop(out, self.off, 0.5)
        if self.low_shelf:
            out = shelf(out, 150.0, self.low_shelf, high=False)
        return out


def tv_opening(p, motif, step, pad, start=0.48, extra=None):
    """0 → 2.25: the motif on an old set, then Alice tears through it."""
    mx = p.op
    for b, note, length in motif:
        t = start + b * step
        if t >= CUT - 0.04:
            break
        detune = -min(1.4, (t - 1.55) / 0.6 * 1.4) if t > 1.55 else 0.0
        mx.add(bell(m(note) + detune, "musicbox", 1.4 + length * step, 0.42), t, bus="tv")
        if extra:
            extra(t, note, length, detune)
    n = S(1.9)
    chord = sum(osc(hz(x), 1.9, "tri", vib=0.004, vib_rate=4.2, vib_delay=0.0) for x in pad)
    mx.add(chord * env_adsr(n, 0.35, 0.3, 0.8, 0.4, gate=1.3) * 0.06, 0.42, bus="tv")
    # Alice: a low tremolo cluster swelling under the glitch, cut dead at 2.25
    r = m(p.root)
    cluster = strings([r - 24, r - 23, r - 18, r - 12], 0.75, a=0.45, r=0.05, trem=13.0, bright=0.55, level=0.1)
    cluster *= np.linspace(0.15, 1.0, len(cluster))[:, None] ** 2
    mx.add(cluster, 1.52, 0.9, hall=0.15)
    mx.add(osc(hz(r - 36), 0.75, "sine") * np.linspace(0, 1, S(0.75)) ** 2 * 0.25, 1.52)
    mx.add(riser(0.62, 0.12, 400, 7000, curve=3.0), 1.62, pan=0.0)


def rain_entry(p, stab=None):
    """2.5 → 3.3: the dark school door in the rain, then the white flash."""
    mx = p.mx
    r = m(p.root)
    n = S(0.95)
    drone = (osc(hz(r - 24), 0.95, "sine") + 0.45 * osc(hz(r - 17), 0.95, "sine")) * env_adsr(n, 0.3, 0.2, 1.0, 0.06, gate=0.88)
    mx.add(drone * 0.15, RAIN)
    shimmer = strings([r + 19, r + 24], 0.75, a=0.45, r=0.1, bright=0.35, level=0.025, vib=0.002)
    mx.add(shimmer, 2.55, hall=0.6)
    mx.add(heartbeat(0.32), 2.6)
    mx.add(reverse_crash(0.72, 0.16), FLASH - 0.72, hall=0.2)
    mx.add(riser(0.65, 0.08, 500, 9000, curve=2.5), FLASH - 0.65)
    mx.add(boom(0.62), FLASH, hall=0.25)
    mx.add(crash(0.26, 2.4), FLASH, pan=-0.2, hall=0.3)
    if stab:
        stab(FLASH)


def glint(p, t, notes, gain=0.07):
    for k, note in enumerate(notes):
        p.mx.add(bell(note, "glock", 1.6, gain), t + 0.035 * k, pan=0.3 * (1 if k % 2 else -1), hall=0.7)


def ink_hit(p, gain=1.0):
    t = p.ink
    p.mx.add(reverse_crash(0.85, 0.2 * gain), t - 0.85, hall=0.2)
    p.mx.add(boom(0.75 * gain, 3.0), t, hall=0.3)
    p.mx.add(crash(0.26 * gain, 3.0, 1.1), t, pan=-0.35, hall=0.35)
    p.mx.add(crash(0.22 * gain, 3.0, 1.2), t + 0.012, pan=0.35, hall=0.35)


def tv_outro(p, notes):
    """The memory ends on the set: a last phrase, then the tape stops."""
    for at, note, gain in notes:
        p.tv.add(bell(note, "musicbox", 1.6, gain), p.back + at, bus="tv")


# ------------------------------------------------------------------ SIMON --
def simon():
    """Vitesse. La mineur (comme son thème LMS), drum'n'bass à 171 BPM : la charge
    accélère par paliers (croches, doubles, triples), lâcher au passage éclair,
    tornade en arpèges tournants, sprint en gamme montante, La majeur au papier."""
    p = Piece("Simon", "A3")
    mx = p.mx
    tv_opening(p, [(0, "A4", 1), (1, "C5", 1), (2, "E5", 1), (3, "A5", 2), (5, "G5", 1), (6, "E5", 1), (7, "D5", 1), (8, "E5", 2)], 0.2, ["A3", "C4", "E4"])
    def stab(t):
        mx.add(supersaw(["A2", "E3", "A3"], 0.18, r=0.45, cutoff=2600, gain=0.11), t, hall=0.25)
        mx.add(timpani("A2", 0.5), t, hall=0.2)
    rain_entry(p, stab)

    # CHARGE · eighths of 0.1625 s: 8ths, then 16ths, then 32nds as the levels rise
    e = 0.1625
    blocks = [(3.3, 3.95, ["A3", "C4", "E4", "A4", "C5", "E5"], e, "A1"),
              (3.95, 4.6, ["F3", "A3", "C4", "F4", "A4", "C5"], e / 2, "F1"),
              (4.6, 5.24, ["G3", "B3", "D4", "G4", "B4", "D5", "G5"], e / 4, "G1")]
    k = 0
    for t0, t1, arp, dt, root in blocks:
        t = t0
        i = 0
        while t < t1 - 1e-6:
            u = (t - 3.3) / 1.95
            mx.add(synth_pluck(arp[i % len(arp)], 0.22, top=1400 + 4600 * u, bottom=260, decay=18, gain=0.035 + 0.03 * u),
                   t, pan=0.4 * np.sin(k * 1.9), room=0.15, plate=0.08)
            t += dt
            i += 1
            k += 1
        mx.add(reese(root, t1 - t0 - 0.02, cutoff=220 + 300 * (t0 - 3.3), open_to=500 + 500 * (t0 - 3.3), gain=0.075), t0)
    for j in range(6):
        mx.add(kick(0.5 + 0.06 * j), 3.3 + j * 2 * e)
    for j in range(12):
        mx.add(hat(0.05 + 0.004 * j), 3.3 + e * j + e * 0.5, pan=0.3)
    mx.add(snare_roll(0.6, 0.22, rate=1 / (e / 2), start=0.2, end=1.0, accel=1.0), 4.6)
    mx.add(riser(1.28, 0.16, 300, 10000, curve=2.2), 3.95)
    mx.add(reverse_crash(0.72, 0.2), 5.32 - 0.72, hall=0.2)
    mx.add(strings(["E4", "A4"], 0.6, a=0.5, r=0.05, bright=0.8, level=0.04), 4.6, hall=0.3)
    glint(p, 4.05, ["A6", "E7"])

    # GO · 171 BPM drop, 22 sixteenths to the tornado
    s16 = (7.25 - 5.32) / 22
    go = 5.32
    mx.add(crash(0.3, 2.5), go, pan=0.3, hall=0.25)
    mx.add(boom(0.55, 1.6, 90, 35), go)
    mx.add(whoosh(0.45, 0.16, 600, 6000), go - 0.12)
    drums = {0: "K", 4: "S", 7: "g", 10: "K", 12: "S", 14: "g", 16: "K", 18: "S", 19: "S", 20: "S", 21: "S"}
    for i in range(22):
        t = go + i * s16
        hit = drums.get(i)
        if hit == "K":
            mx.add(kick(0.75), t)
        elif hit == "S":
            mx.add(snare(0.42 if i < 18 else 0.24 + 0.05 * (i - 18), tone=210), t, room=0.18)
        elif hit == "g":
            mx.add(snare(0.1, tone=210), t, room=0.1)
        mx.add(hat(0.07 if i % 2 == 0 else 0.045, 55), t, pan=0.25)
    for t0, t1, root, chord in [(0, 8, "A1", ["A3", "C4", "E4"]), (8, 16, "F1", ["F3", "A3", "C4"]), (16, 22, "G1", ["G3", "B3", "D4"])]:
        mx.add(reese(root, (t1 - t0) * s16 - 0.01, cutoff=500, lfo=1.0 / (2 * s16), depth=0.6, gain=0.11), go + t0 * s16)
        mx.add(supersaw(chord, (t1 - t0) * s16 - 0.02, r=0.15, cutoff=3200, gain=0.03), go + t0 * s16, hall=0.15)
    line = [(0, "A5", 1), (1, "C6", 1), (2, "E6", 1), (3, "A6", 2), (5, "G6", 1), (6, "E6", 1), (7, "D6", 1),
            (8, "F6", 2), (10, "E6", 2), (12, "C6", 2), (14, "A5", 2), (16, "B5", 2), (18, "D6", 2), (20, "G6", 2)]
    for i, note, length in line:
        mx.add(lead(note, length * s16 * 0.92, "saw", 0.09, cutoff=6500, vib=0.0), go + i * s16, pan=0.1, plate=0.25)

    # TORNADO · 7.25: swirling 32nd arpeggio circling the stereo field
    tor = 7.25
    s16 = (8.3 - tor) / 12
    mx.add(crash(0.28, 2.2), tor, pan=-0.3, hall=0.25)
    swirl = ["A4", "C5", "E5", "A5", "C6", "E6", "A6", "E6", "C6", "A5", "E5", "C5"]
    for i in range(24):
        t = tor + i * s16 / 2
        mx.add(synth_pluck(swirl[i % len(swirl)], 0.16, top=7000, bottom=500, decay=20, gain=0.05), t, pan=np.sin(TAU * 1.8 * (t - tor)), plate=0.2)
    for i, hit in {0: "K", 4: "S", 6: "K", 8: "K", 10: "S", 11: "S"}.items():
        mx.add(kick(0.7) if hit == "K" else snare(0.4, tone=210), tor + i * s16, room=0.12 if hit == "S" else 0.0)
    for i in range(12):
        mx.add(hat(0.06, 55), tor + i * s16, pan=-0.25)
    mx.add(reese("A1", 12 * s16 - 0.01, cutoff=600, lfo=1.0 / s16, depth=0.7, gain=0.11), tor)
    mx.add(supersaw(["A3", "C4", "E4", "A4"], 12 * s16, r=0.1, cutoff=4200, gain=0.05), tor, hall=0.15)
    mx.add(whoosh(0.4, 0.14, 800, 7000), 7.8, pan=0.4)

    # RUN · 8.3: F, then E (the dominant) climbing to the paper
    run = 8.3
    s16 = 0.0875
    for i, hit in {0: "K", 4: "S", 6: "K"}.items():
        mx.add(kick(0.75) if hit == "K" else snare(0.42, tone=210), run + i * s16, room=0.12 if hit == "S" else 0.0)
    mx.add(snare_roll(0.62, 0.3, rate=1 / (s16 / 2), start=0.25, end=1.0), run + 8 * s16 - 0.02)
    for i in range(24):
        mx.add(hat(0.05, 60), run + i * s16 / 2, pan=0.2 * (1 if i % 2 else -1))
    mx.add(reese("F1", 4 * s16 - 0.01, cutoff=600, lfo=1.0 / s16, depth=0.6, gain=0.11), run)
    mx.add(reese("E1", 0.7, cutoff=500, open_to=1800, gain=0.12), run + 4 * s16)
    mx.add(supersaw(["F3", "A3", "C4"], 4 * s16, r=0.05, cutoff=4000, gain=0.05), run, hall=0.15)
    mx.add(strings(["E3", "B3", "E4", "G#4", "D5"], 0.7, a=0.25, r=0.05, bright=1.1, level=0.07), run + 4 * s16, hall=0.2)
    mx.add(brass(["E3", "G#3", "B3", "D4"], 0.68, level=0.9, a=0.2, r=0.05, gain=0.06), run + 4 * s16, hall=0.2)
    mx.add(lead("F6", 0.16, "saw", 0.075), run, plate=0.25)
    mx.add(lead("E6", 0.16, "saw", 0.075), run + 2 * s16, plate=0.25)
    scale = ["E5", "F5", "G#5", "A5", "B5", "C6", "D6", "E6", "F6", "G#6", "A6", "B6", "C7", "D7", "E7", "G#7"]
    for i, note in enumerate(scale):
        mx.add(lead(note, 0.04, "saw", 0.055 + 0.002 * i, r=0.05, vib=0.0), run + 4 * s16 + i * 0.7 / 16, plate=0.25)
    mx.add(riser(1.0, 0.16, 500, 11000, curve=2.0), run)

    # INK · La majeur
    t = p.ink
    ink_hit(p)
    mx.add(timpani("A2", 0.6), t, hall=0.3)
    mx.add(brass(["A2", "E3", "A3", "C#4", "E4"], 1.9, level=1.25, a=0.03, r=0.6, gain=0.12), t, hall=0.35)
    mx.add(strings(["A2", "E3", "A3", "C#4", "E4", "A4", "C#5"], 2.0, a=0.06, r=0.7, bright=1.2, level=0.09, attack_bite=0.8), t, hall=0.4)
    mx.add(choir(["A3", "E4", "A4", "C#5"], 2.0, "a", a=0.12, r=0.8, gain=0.06), t, hall=0.5)
    mx.add(supersaw(["A3", "C#4", "E4", "A4"], 1.8, r=0.6, cutoff=6500, gain=0.06), t, hall=0.3)
    mx.add(reese("A1", 1.8, cutoff=500, gain=0.09, r=0.5), t)
    for k, note in enumerate(["A5", "C#6", "E6"]):
        mx.add(lead(note, 0.11, "saw", 0.08), t + 0.12 * k, plate=0.3)
    mx.add(lead("A6", 1.5, "saw", 0.085, glide_from="E6", glide=0.03, vib=0.008, r=0.5), t + 0.36, plate=0.35, hall=0.2)
    for k, note in enumerate(["A6", "C#7", "E7", "A7"]):
        mx.add(bell(note, "glock", 2.0, 0.08), t + 0.03 + 0.06 * k, pan=-0.4 + 0.27 * k, hall=0.5)

    tv_outro(p, [(0.08, "E5", 0.4), (0.38, "A5", 0.42), (0.38, "A4", 0.25)])
    return p


# ---------------------------------------------------------------- USAYUKO --
def usayuko():
    """Force. Si mineur (comme son thème LMS) : taikos, cuivres et cordes graves.
    Le blocage sonne comme une enclume, le contre claque dans les cuivres, la
    charge monte en roulement, le coup de poing tombe sur tout l'orchestre et un
    gong, Alice s'écrase sur les taikos ; montée héroïque Sol, La, puis Si majeur
    au papier."""
    p = Piece("Usayuko", "B3")
    p.low_shelf = -2.5
    mx = p.mx
    tv_opening(p, [(0, "B4", 1), (1, "F#5", 1), (2, "B5", 2), (4, "A5", 1), (5, "F#5", 1), (6, "D5", 1), (7, "E5", 1), (8, "F#5", 2)], 0.3, ["B3", "D4", "F#4"])
    def stab(t):
        mx.add(taiko("B1", 0.7), t, hall=0.3)
        mx.add(strings(["B1", "F#2", "B2"], 0.35, a=0.01, r=0.3, bright=0.8, level=0.07, attack_bite=1.0), t, hall=0.2)
    rain_entry(p, stab)

    # BLOCK · 3.62: anvil, brass, then a taiko groove in eighths to the counter
    blk = 3.62
    mx.add(bell("B5", "anvil", 1.6, 0.2), blk, pan=0.2, hall=0.35)
    mx.add(bell("F6", "anvil", 1.2, 0.1), blk + 0.004, pan=-0.2, hall=0.35)
    mx.add(brass(["B2", "D3", "F#3", "B3"], 0.22, level=1.4, a=0.008, r=0.35, gain=0.12), blk, hall=0.3)
    mx.add(timpani("B2", 0.55), blk, hall=0.25)
    mx.add(crash(0.16, 2.0), blk, pan=0.3, hall=0.2)
    e = (4.85 - blk) / 4
    for i, (note, g, pan) in enumerate([("B1", 0.85, 0.0), ("F#2", 0.4, -0.35), ("D2", 0.6, 0.2), ("F#2", 0.4, -0.35), ("F#2", 0.3, 0.35)]):
        at = blk + e * (i if i < 4 else 3.5)
        mx.add(taiko(note, g), at, pan=pan, hall=0.3)
    mx.add(strings(["B1", "F#2"], 1.25, a=0.15, r=0.2, trem=16.0, bright=0.7, level=0.065), blk + 0.05, hall=0.2)
    swell = brass(["G2", "B2", "D3"], 0.8, level=0.8, a=0.65, r=0.15, gain=0.08, mellow=True)
    mx.add(swell, 4.1, hall=0.3)
    glint(p, 4.15, ["F#6", "B6"])

    # COUNTER · 4.98, then the wind-up roll into the punch
    ctr = 4.98
    mx.add(brass(["A2", "C#3", "E3", "A3"], 0.18, level=1.4, a=0.006, r=0.3, gain=0.12), ctr, hall=0.3)
    mx.add(taiko("A1", 0.8), ctr, hall=0.3)
    mx.add(crash(0.14, 1.8), ctr, pan=-0.3, hall=0.2)
    hit = 5.75
    t = 5.07
    k = 0
    while t < hit - 0.07:
        u = (t - 5.07) / (hit - 5.07)
        mx.add(taiko("B1" if k % 2 == 0 else "F#2", 0.25 + 0.6 * u ** 1.3, 1.0), t, pan=0.3 * (1 if k % 2 else -1), hall=0.25)
        t += 0.16 - 0.115 * u
        k += 1
    mx.add(gliss("B2", "B3", 0.62, level=0.07, trem=18.0, a=0.1, r=0.03, curve=1.5), 5.07, hall=0.2)
    mx.add(choir(["B2", "F#3"], 0.6, "o", a=0.45, r=0.04, gain=0.05), 5.07, hall=0.3)
    mx.add(riser(0.66, 0.14, 250, 8000, curve=2.4), 5.07)
    mx.add(reverse_crash(0.66, 0.2), hit - 0.66, hall=0.2)

    # PUNCH · 5.75: everything at once
    mx.add(boom(1.0, 3.2, 62, 33, grit=0.5), hit, hall=0.3)
    mx.add(taiko("B1", 1.0, 2.0, 3.5), hit, hall=0.35)
    mx.add(taiko("F#2", 0.75, 1.6), hit + 0.006, pan=-0.35, hall=0.35)
    mx.add(taiko("B2", 0.6, 1.4), hit + 0.012, pan=0.35, hall=0.35)
    mx.add(timpani("B1", 0.7, 3.0), hit, hall=0.3)
    mx.add(gong("B1", 0.3, 4.0), hit, hall=0.3)
    mx.add(crash(0.3, 3.0, 1.0), hit, pan=-0.3, hall=0.3)
    mx.add(crash(0.26, 3.0, 1.1), hit + 0.01, pan=0.3, hall=0.3)
    mx.add(brass(["B1", "F#2", "B2", "D3", "F#3", "B3"], 0.85, level=1.6, a=0.006, r=0.5, gain=0.15, s=0.7), hit, hall=0.35)
    mx.add(braam(["B1", "F#2"], 0.9, 0.08), hit, hall=0.2)
    mx.add(strings(["B2", "F#3", "B3", "D4", "F#4"], 0.85, a=0.008, r=0.5, bright=1.2, level=0.08, attack_bite=1.2), hit, hall=0.35)

    # FLIGHT · 5.87 → 6.69, the crash on the taikos
    mx.add(gliss("B3", "F#4", 0.8, level=0.06, trem=20.0, a=0.15, r=0.1, curve=0.8), 5.9, hall=0.3)
    mx.add(lead("F#5", 0.75, "trumpet", 0.07, r=0.15), 5.95, hall=0.4)
    mx.add(whoosh(0.8, 0.12, 300, 3500), 5.88)
    land = 6.69
    mx.add(taiko("B1", 0.9, 1.8), land, hall=0.3)
    mx.add(taiko("E2", 0.6, 1.4), land + 0.008, pan=0.3, hall=0.3)
    mx.add(timpani("F#2", 0.55), land, hall=0.3)
    mx.add(brass(["B1", "F#2", "B2"], 0.3, level=1.2, a=0.006, r=0.4, gain=0.1), land, hall=0.3)
    mx.add(boom(0.5, 2.0, 58, 33), land)
    mx.add(crash(0.12, 2.0), land, pan=0.4, hall=0.2)

    # STEAM · 7.05: a horn alone over low strings
    mx.add(strings(["B1", "F#2", "B2", "D3"], 0.85, a=0.12, r=0.2, bright=0.6, level=0.045), 7.05, hall=0.4)
    for at, note in [(7.1, "B3"), (7.33, "F#4"), (7.56, "B4")]:
        mx.add(brass([note], 0.2 if note != "B4" else 0.28, level=0.8, a=0.03, r=0.2, voices=2, gain=0.07, mellow=True), at, hall=0.5)
    mx.add(taiko("B1", 0.35), 7.05, hall=0.3)
    mx.add(taiko("B1", 0.3), 7.45, hall=0.3)

    # HERO · Sol, La, then Si majeur
    hero = 7.85
    for t0, t1, chord, top in [(hero, 8.4, ["G2", "D3", "G3", "B3", "D4"], ["G3", "B3", "D4"]), (8.4, p.ink, ["A2", "E3", "A3", "C#4", "E4"], ["A3", "C#4", "E4"])]:
        d = t1 - t0
        mx.add(brass(chord, d - 0.03, level=1.1, a=0.04, r=0.08, gain=0.11), t0, hall=0.3)
        mx.add(strings(chord, d - 0.03, a=0.05, r=0.08, bright=1.0, level=0.07), t0, hall=0.3)
        mx.add(choir(top, d - 0.03, "a", a=0.1, r=0.08, gain=0.05), t0, hall=0.4)
    mx.add(timp_roll("G2", 0.55, 0.35, start=0.3, end=0.7), hero)
    mx.add(timp_roll("A2", 0.5, 0.45, start=0.4, end=1.0), 8.4)
    mx.add(snare_roll(1.05, 0.2, rate=22.0, start=0.2, end=1.0), hero)
    for at, note, d in [(hero, "D5", 0.25), (hero + 0.27, "B4", 0.25), (8.4, "C#5", 0.25), (8.67, "E5", 0.24)]:
        mx.add(lead(note, d, "trumpet", 0.075), at, hall=0.35)
    mx.add(reverse_crash(0.6, 0.18), p.ink - 0.6, hall=0.2)

    # INK · Si majeur
    t = p.ink
    ink_hit(p)
    mx.add(taiko("B1", 0.9, 1.8), t, hall=0.3)
    mx.add(taiko("F#2", 0.6, 1.4), t + 0.01, pan=0.3, hall=0.3)
    mx.add(timpani("B1", 0.6), t, hall=0.3)
    mx.add(brass(["B1", "F#2", "B2", "D#3", "F#3", "B3", "D#4"], 2.0, level=1.35, a=0.02, r=0.6, gain=0.14), t, hall=0.35)
    mx.add(strings(["B1", "F#2", "B2", "F#3", "B3", "D#4", "F#4", "B4"], 2.0, a=0.05, r=0.7, bright=1.1, level=0.09, attack_bite=0.8), t, hall=0.4)
    mx.add(choir(["B3", "D#4", "F#4", "B4"], 2.0, "a", a=0.1, r=0.8, gain=0.065), t, hall=0.5)
    for k, note in enumerate(["B4", "F#5"]):
        mx.add(lead(note, 0.13, "trumpet", 0.09), t + 0.15 * k, hall=0.35)
    mx.add(lead("B5", 1.5, "trumpet", 0.095, r=0.5), t + 0.3, hall=0.4)

    tv_outro(p, [(0.08, "F#5", 0.4), (0.38, "B5", 0.42), (0.38, "B4", 0.25)])
    return p


# ----------------------------------------------------------------- ASHURA --
def ashura():
    """Drones, rollers et bricolage. Fa mineur (comme son thème LMS) : groove
    électro-funk à 116 BPM, percussions d'atelier (cliquets, petites clés de
    métal), lead en onde carrée façon jouet, hélice du drone qui grimpe, « bonk »
    sur les deux impacts, Fa majeur au papier avec une cascade chiptune."""
    p = Piece("Ashura", "F3")
    p.low_shelf = -1.0
    mx = p.mx
    def chip(t, note, length, detune):
        p.op.add(synth_pluck(m(note) - 12 + detune, 0.16, "pulse", top=4000, bottom=900, decay=10, gain=0.02, reso=0.0, pw=0.25), t + 0.02, bus="tv")
    tv_opening(p, [(0, "F4", 1), (1, "Ab4", 1), (2, "C5", 1), (3, "Eb5", 1), (4, "C5", 1), (5, "Bb4", 1), (6, "Ab4", 1), (7, "G4", 1), (8, "F4", 2)], 0.214, ["F3", "Ab3", "C4"], extra=chip)
    def stab(t):
        mx.add(supersaw(["F2", "C3", "F3"], 0.16, r=0.35, cutoff=2400, gain=0.1), t, hall=0.2)
        mx.add(kick(0.7), t)
    rain_entry(p, stab)

    # TINKER · 3.3 → 4.85, twelve sixteenths of workshop rhythm
    s16 = (4.85 - 3.3) / 12
    tinks = ["F6", "Ab6", "C7", "Eb7", "C7", "F6", "Bb6", "Ab6"]
    for j, i in enumerate([0, 2, 3, 5, 7, 8, 10, 11]):
        mx.add(bell(tinks[j], "tink", 0.4, 0.06), 3.3 + i * s16, pan=0.5 * (1 if j % 2 else -1), room=0.25)
    for i in [1, 6, 9]:
        mx.add(ratchet(0.09), 3.3 + i * s16, pan=0.3, room=0.2)
    for j, note in enumerate(["F2", "F3", "F2", "Ab2", "C3", "Eb3"]):
        mx.add(synth_pluck(note, 0.22, "square", top=2600, bottom=220, decay=14, gain=0.07, reso=0.9), 3.3 + 2 * j * s16, room=0.1)
    for i in [0, 4, 8]:
        mx.add(kick(0.45, 120, 48, 9.0), 3.3 + i * s16)
    mx.add(clap(0.16), 3.3 + 4 * s16, room=0.25)
    for j, note in enumerate(["F5", "Ab5", "C6"]):
        mx.add(lead(note, s16 * 0.8, "chip", 0.05, pw=0.25, vib=0.0), 3.3 + (6 + j) * s16, pan=0.15, room=0.2)
    mx.add(lead("Eb6", 0.3, "chip", 0.05, pw=0.25), 3.3 + 9 * s16, pan=0.15, room=0.25)
    glint(p, 4.15, ["C7", "F7"])

    # FLING · the drone takes off (propeller climbing), BONK at 5.47
    fl = 4.85
    d = 5.47 - fl
    n = S(d)
    tt = np.arange(n) / SR
    prop_f = 95.0 * 2 ** (2.0 * (tt / d) ** 0.8)
    prop = osc(prop_f, d, "saw", cutoff=1800, slope=1.5) * (0.6 + 0.4 * np.sign(np.sin(TAU * 34.0 * tt)))
    mx.add(norm_rms(prop * np.linspace(0.3, 1.0, n), 0.03), fl, pan=0.2, room=0.2)
    for i, note in enumerate(["F4", "F#4", "G4", "Ab4", "A4", "Bb4", "B4", "C5"]):
        mx.add(synth_pluck(note, 0.12, "pulse", top=5000, bottom=800, decay=14, gain=0.04, reso=0.0, pw=0.25), fl + i * d / 8, pan=-0.3 + 0.08 * i)
    mx.add(riser(d, 0.08, 400, 7000), fl)
    bonk = 5.47
    mx.add(supersaw(["F3", "Ab3", "C4"], 0.14, r=0.35, cutoff=3000, gain=0.09), bonk, hall=0.2)
    mx.add(clap(0.3), bonk, room=0.25)
    mx.add(crash(0.18, 2.0), bonk, pan=0.3, hall=0.2)
    mx.add(zap(0.35, 0.12, 1500, 30), bonk, pan=-0.2)
    mx.add(boing("F4", 0.5, 0.1), bonk + 0.04, pan=0.25, room=0.2)
    mx.add(kick(0.6), bonk)
    mx.add(reese("F1", 0.32, cutoff=400, gain=0.08), bonk)

    # CHARGE · 5.85: the rollers wind up
    ch = 5.85
    t = ch
    k = 0
    while t < 6.75:
        u = (t - ch) / 0.95
        mx.add(click(0.06 + 0.08 * u, 3000 + 2000 * u), t, pan=0.4 * np.sin(k), room=0.15)
        t += 0.11 - 0.08 * u
        k += 1
    for i in range(4):
        mx.add(kick(0.45 + 0.08 * i, 130, 48, 9.0), ch + i * 0.2375)
    for i, note in enumerate(["F4", "Ab4", "C5", "Eb5", "F5", "Ab5", "C6", "Eb6"]):
        mx.add(synth_pluck(note, 0.1, "pulse", top=6000, bottom=900, decay=16, gain=0.035, reso=0.0, pw=0.25), 6.3 + i * 0.0594, pan=0.2)
    mx.add(riser(0.95, 0.12, 300, 9000), ch)
    mx.add(reese("C2", 0.9, cutoff=200, open_to=1400, gain=0.08), ch)
    mx.add(reverse_crash(0.6, 0.18), 6.8 - 0.6, hall=0.2)

    # GO · 6.8: roller funk, twelve sixteenths, then the second bonk
    go = 6.8
    s16 = (8.35 - go) / 12
    mx.add(crash(0.24, 2.4), go, pan=-0.3, hall=0.25)
    mx.add(whoosh(0.5, 0.12, 500, 6000), go - 0.1)
    for i in range(12):
        t = go + i * s16
        if i in (0, 3, 7, 8):
            mx.add(kick(0.72, 140, 48), t)
        if i in (4, 10):
            mx.add(clap(0.3), t, room=0.25)
            mx.add(snare(0.25, tone=230), t, room=0.15)
        if i in (6, 11):
            mx.add(snare(0.08, tone=230), t, room=0.1)
        mx.add(hat(0.06 if i % 2 == 0 else 0.04, 50 if i not in (2, 6) else 9, 0.12 if i not in (2, 6) else 0.3), t, pan=0.3)
    for i, note, length in [(0, "F2", 2), (2, "F3", 1), (3, "F2", 1), (5, "Ab2", 1), (6, "C3", 2), (8, "Db3", 1), (9, "Db2", 1), (10, "Eb2", 1), (11, "C3", 1)]:
        mx.add(synth_pluck(note, length * s16 + 0.06, "saw", top=1800, bottom=180, decay=9, gain=0.1, reso=0.8), go + i * s16)
    for i, note, length in [(0, "F5", 1), (1, "Ab5", 1), (2, "C6", 1), (3, "Eb6", 1), (4, "C6", 1), (5, "Bb5", 1), (6, "Ab5", 1), (7, "G5", 1), (8, "Ab5", 2), (10, "Bb5", 2)]:
        mx.add(lead(note, length * s16 * 0.85, "chip", 0.055, pw=0.25, vib=0.0), go + i * s16, pan=0.1, room=0.2)
    mx.add(supersaw(["F3", "Ab3", "C4"], 6 * s16, r=0.08, cutoff=2600, gain=0.035), go, hall=0.15)
    mx.add(supersaw(["Db3", "F3", "Ab3"], 6 * s16, r=0.08, cutoff=2600, gain=0.035), go + 6 * s16, hall=0.15)
    mx.add(whoosh(0.4, 0.08, 700, 5000), 7.2, pan=0.4)

    b2 = 8.35
    mx.add(supersaw(["Eb3", "G3", "Bb3"], 0.14, r=0.35, cutoff=3000, gain=0.09), b2, hall=0.2)
    mx.add(clap(0.3), b2, room=0.25)
    mx.add(kick(0.7), b2)
    mx.add(crash(0.2, 2.0), b2, pan=-0.3, hall=0.2)
    mx.add(zap(0.35, 0.12, 1700, 30), b2, pan=0.2)
    mx.add(boing("Eb4", 0.5, 0.1), b2 + 0.04, pan=-0.25, room=0.2)
    for k, note in enumerate(["Bb6", "Eb7", "G7"]):
        mx.add(bell(note, "glock", 1.0, 0.05), b2 + 0.06 + 0.07 * k, pan=0.4 - 0.4 * k, hall=0.5)
    mx.add(snare(0.3, tone=230), b2 + 0.25, room=0.2)
    mx.add(synth_pluck("Eb2", 0.45, "saw", top=1600, bottom=180, decay=8, gain=0.1, reso=0.8), b2)

    # COOL · 8.85: thumbs up, a toy fanfare climbing to F
    cool = 8.85
    q = 0.25
    for i in range(4):
        mx.add(kick(0.65, 140, 48) if i % 2 == 0 else clap(0.26), cool + i * q, room=0.0 if i % 2 == 0 else 0.25)
        mx.add(hat(0.05), cool + i * q + q / 2, pan=0.3)
    for i, note in enumerate(["F5", "Ab5", "Db6"]):
        mx.add(lead(note, 0.11, "chip", 0.06, pw=0.25, vib=0.0), cool + i * 0.125, room=0.2)
    for i, note in enumerate(["G5", "Bb5", "Eb6"]):
        mx.add(lead(note, 0.11, "chip", 0.06, pw=0.25, vib=0.0), cool + 0.5 + i * 0.125, room=0.2)
    mx.add(synth_pluck("Db2", 0.5, "saw", top=1600, bottom=180, decay=6, gain=0.1, reso=0.8), cool)
    mx.add(synth_pluck("Eb2", 0.5, "saw", top=1600, bottom=180, decay=6, gain=0.1, reso=0.8), cool + 0.5)
    mx.add(supersaw(["Db3", "F3", "Ab3"], 0.48, r=0.05, cutoff=3000, gain=0.04), cool, hall=0.2)
    mx.add(supersaw(["Eb3", "G3", "Bb3"], 0.48, r=0.05, cutoff=3500, gain=0.045), cool + 0.5, hall=0.2)
    mx.add(snare_roll(0.35, 0.18, rate=28.0, start=0.3, end=1.0), p.ink - 0.37)

    # INK · Fa majeur, chiptune cascade
    t = p.ink
    ink_hit(p)
    mx.add(timpani("F2", 0.6), t, hall=0.3)
    mx.add(supersaw(["F3", "A3", "C4", "F4"], 1.9, r=0.6, cutoff=6500, gain=0.07), t, hall=0.3)
    mx.add(brass(["F2", "C3", "F3", "A3", "C4"], 1.9, level=1.2, a=0.03, r=0.6, gain=0.11), t, hall=0.35)
    mx.add(strings(["F2", "C3", "F3", "A3", "C4", "F4", "A4"], 2.0, a=0.06, r=0.7, bright=1.1, level=0.08, attack_bite=0.8), t, hall=0.4)
    mx.add(choir(["F3", "C4", "F4", "A4"], 2.0, "a", a=0.12, r=0.8, gain=0.055), t, hall=0.5)
    mx.add(reese("F1", 1.8, cutoff=500, gain=0.08, r=0.5), t)
    cascade = ["F5", "A5", "C6", "F6", "A6", "C7", "F7", "C7", "A6", "F6", "C6", "A5"]
    for i, note in enumerate(cascade):
        mx.add(lead(note, 0.035, "chip", 0.035, pw=0.125, vib=0.0, r=0.04), t + 0.04 + i * 0.045, pan=-0.5 + i / 11.0, room=0.2)
    mx.add(lead("F6", 1.4, "chip", 0.06, pw=0.25, vib=0.008, r=0.4), t + 0.6, room=0.3, hall=0.2)
    mx.add(lead("C6", 1.4, "chip", 0.035, pw=0.5, vib=0.008, r=0.4), t + 0.6, room=0.3, hall=0.2)

    tv_outro(p, [(0.08, "C5", 0.4), (0.38, "F5", 0.42), (0.38, "F4", 0.25)])
    return p


# ------------------------------------------------------------------ LYSIA --
def lysia():
    """Mécanique, électricité, surchauffe. Si mineur (comme son thème LMS) :
    ronflement électrique sur le Si grave, accords hachés à 140 BPM, étincelles
    en FM ; la surchauffe accélère le LFO et sature tout, la décharge tombe sur
    un accord saturé, la vapeur retombe sur Ré majeur, Si majeur héroïque au
    papier, une étincelle à chaque éclair noir."""
    p = Piece("Lysia", "B3")
    p.low_shelf = -2.0
    mx = p.mx
    tv_opening(p, [(0, "B4", 1), (1, "D5", 1), (2, "F#5", 1), (3, "E5", 1), (4, "D5", 1), (5, "C#5", 1), (6, "B4", 2)], 0.25, ["B3", "D4", "F#4"])
    def stab(t):
        mx.add(sat(supersaw(["B1", "F#2", "B2"], 0.18, r=0.4, cutoff=2200, gain=0.1) * 2.0, 1.5) * 0.5, t, hall=0.2)
        mx.add(crackle(0.4, 0.06), t, pan=0.3)
    rain_entry(p, stab)

    # PLUGGED · 3.4 → 4.9 on a 140 BPM grid
    g = 3.4
    s16 = 60.0 / 140.0 / 4.0
    d = 4.9 - g
    n = S(d + 0.1)
    tt = np.arange(n) / SR
    hum = osc(hz("B1"), d + 0.1, "saw", cutoff=250 * 2 ** (2.2 * tt / d), slope=1.6, reso=0.6)
    hum *= env_adsr(n, 0.3, 0.1, 1.0, 0.08, gate=d)
    mx.add(norm_rms(hum, 0.05), g)
    chord = supersaw(["B3", "D4", "F#4", "B4"], d, a=0.01, r=0.05, cutoff=1800, gain=0.05)
    chord = trance_gate(chord, s16, [1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 1, 0, 1, 1, 1])
    chord *= np.linspace(0.5, 1.0, len(chord))[:, None]
    mx.add(chord, g, hall=0.15)
    for i in range(4):
        mx.add(kick(0.62, 150, 46), g + i * 4 * s16)
    for i in range(14):
        mx.add(hat(0.05, 50), g + i * s16 + (s16 if i % 2 == 0 else 0) * 0, pan=0.25 if i % 2 else -0.25)
    sparks = ["B5", "D6", "E6", "F#6", "A6", "B6"]
    for i in [1, 3, 6, 7, 10, 13]:
        note = sparks[int(rng.integers(len(sparks)))]
        mx.add(norm_peak(fm(hz(note), 0.18, ratio=2.01, index=3.0, index_decay=12, decay=18), 0.05), g + i * s16, pan=rng.uniform(-0.7, 0.7), plate=0.3)
    mx.add(reese("B1", 0.8, cutoff=260, open_to=900, gain=0.07), 4.1)
    glint(p, 4.15, ["F#6", "B6"])

    # DASH 4.9 → HIT 5.2
    mx.add(zap(0.3, 0.1, 900, 18), 4.9, pan=-0.3)
    mx.add(whoosh(0.32, 0.1, 600, 6000), 4.88)
    hit = 5.2
    mx.add(sat(supersaw(["B2", "F#3", "B3"], 0.16, r=0.35, cutoff=3200, gain=0.1) * 2.0, 1.4) * 0.55, hit, hall=0.2)
    mx.add(kick(0.75), hit)
    mx.add(snare(0.38, tone=200), hit, room=0.2)
    mx.add(crash(0.18, 2.0), hit, pan=0.3, hall=0.2)
    mx.add(zap(0.4, 0.12, 1800, 30), hit, pan=0.2)
    stutter = trance_gate(supersaw(["B3", "D4", "F#4"], 0.33, r=0.02, cutoff=2600, gain=0.045), s16 / 2, [1, 0, 1, 1, 0, 1])
    mx.add(stutter, hit + 0.02, hall=0.1)

    # OVERHEAT · 5.55 → 6.5: the LFO runs away, the whine climbs, everything saturates
    heat = 5.55
    d = 6.5 - heat
    n = S(d + 0.05)
    tt = np.arange(n) / SR
    rate = 4.0 + 16.0 * (tt / d) ** 1.5
    mx.add(reese("B1", d, cutoff=380, lfo=rate, depth=0.85, gain=0.1, drive=2.4), heat)
    for semis in (5.0, 7.0):
        w = osc(hz("F#5"), d + 0.05, "saw", cutoff=4200, slope=2.0, bend=semis * (tt / d) ** 1.3, vib=0.004, vib_rate=9.0, vib_delay=0.0)
        mx.add(norm_rms(w * np.linspace(0.15, 1.0, n) ** 1.5, 0.022), heat, pan=-0.4 if semis < 6 else 0.4, plate=0.2)
    kettle = np.sin(TAU * np.cumsum(2600.0 * 2 ** (0.4 * tt / d) * (1 + 0.01 * np.sin(TAU * 11 * tt))) / SR)
    mx.add(norm_rms(kettle * np.linspace(0, 1, n) ** 2, 0.008), heat)
    for i in range(8):
        mx.add(kick(0.55 + 0.03 * i, 150, 46), heat + i * 2 * s16 * (d / (16 * s16)))
    mx.add(snare_roll(d - 0.04, 0.24, rate=1.0 / s16, start=0.2, end=1.0, accel=1.0), heat)
    mx.add(riser(d, 0.16, 300, 11000, curve=2.0), heat)
    mx.add(reverse_crash(0.75, 0.2), 6.55 - 0.75, hall=0.2)

    # PUSH · 6.55: the discharge
    push = 6.55
    mx.add(boom(1.0, 3.0, 70, 34, grit=0.6), push, hall=0.3)
    mx.add(braam(["B1", "F#2", "B2"], 1.0, 0.09), push, hall=0.25)
    mx.add(sat(supersaw(["B2", "F#3", "B3", "F#4"], 0.9, a=0.004, r=0.5, cutoff=4000, gain=0.1) * 2.2, 1.5) * 0.5, push, hall=0.3)
    mx.add(crash(0.3, 3.0, 1.0), push, pan=-0.3, hall=0.3)
    mx.add(crash(0.26, 3.0, 1.1), push + 0.01, pan=0.3, hall=0.3)
    mx.add(zap(0.9, 0.14, 2400, 40), push, pan=0.1)
    mx.add(timpani("B1", 0.6), push, hall=0.3)
    mx.add(norm_peak(hp(noise(0.45), 400) * env_perc(S(0.45), 9.0), 0.2), push, hall=0.3)
    mx.add(crackle(0.9, 0.08, 90), push + 0.05, pan=0.2, plate=0.2)
    mx.add(strings(["G2", "D3", "G3", "B3"], 0.6, a=0.3, r=0.3, bright=0.8, level=0.05), 7.0, hall=0.4)
    mx.add(choir(["G3", "D4"], 0.6, "o", a=0.3, r=0.3, gain=0.035), 7.0, hall=0.5)

    # VENT · 7.65: steam, then D major and an echoing pluck
    vent = 7.65
    mx.add(steam(1.1, 0.06), vent, pan=-0.2, hall=0.2)
    mx.add(strings(["D3", "F#3", "A3", "D4"], 0.5, a=0.25, r=0.1, bright=0.7, level=0.05), vent, hall=0.4)
    mx.add(strings(["A2", "E3", "A3", "C#4"], 0.45, a=0.2, r=0.1, bright=0.8, level=0.055), 8.15, hall=0.4)
    mx.add(choir(["F#3", "A3", "D4"], 0.95, "o", a=0.3, r=0.1, gain=0.035), vent, hall=0.5)
    arp = ["D5", "F#5", "A5", "D6", "A5", "F#5", "E5", "A5", "C#6", "E6"]
    for i, note in enumerate(arp):
        t = vent + 0.05 + i * s16
        pl = synth_pluck(note, 0.2, "saw", top=4500, bottom=600, decay=16, gain=0.04, reso=0.4)
        mx.add(pl, t, pan=-0.3, plate=0.2)
        mx.add(pl, t + 3 * s16, 0.4, pan=0.4, plate=0.2)
    mx.add(timp_roll("B1", 0.5, 0.35, start=0.2, end=0.9), p.ink - 0.5)
    mx.add(reverse_crash(0.55, 0.18), p.ink - 0.55, hall=0.2)

    # INK · Si majeur, a spark on every black bolt
    t = p.ink
    ink_hit(p)
    mx.add(timpani("B1", 0.6), t, hall=0.3)
    mx.add(brass(["B1", "F#2", "B2", "D#3", "F#3", "B3"], 2.0, level=1.3, a=0.02, r=0.6, gain=0.13), t, hall=0.35)
    mx.add(strings(["B1", "F#2", "B2", "F#3", "B3", "D#4", "F#4"], 2.0, a=0.05, r=0.7, bright=1.1, level=0.085, attack_bite=0.8), t, hall=0.4)
    mx.add(choir(["B3", "D#4", "F#4", "B4"], 2.0, "a", a=0.1, r=0.8, gain=0.06), t, hall=0.5)
    mx.add(supersaw(["B3", "D#4", "F#4"], 1.8, r=0.6, cutoff=5500, gain=0.05), t, hall=0.3)
    for k, note in enumerate(["B4", "D#5", "F#5"]):
        mx.add(lead(note, 0.11, "saw", 0.08), t + 0.12 * k, plate=0.3)
    mx.add(lead("B5", 1.5, "saw", 0.085, glide_from="F#5", glide=0.03, vib=0.008, r=0.5), t + 0.36, plate=0.35, hall=0.2)
    for k in range(9):
        note = ["B6", "F#6", "D#7", "B6", "F#7"][k % 5]
        mx.add(norm_peak(fm(hz(note), 0.2, ratio=2.01, index=3.0, index_decay=14, decay=16), 0.05 * (1.0 - 0.06 * k)), t + 0.05 + 0.25 * k, pan=rng.uniform(-0.6, 0.6), plate=0.3)

    tv_outro(p, [(0.08, "F#5", 0.4), (0.38, "B5", 0.42), (0.38, "B4", 0.25)])
    return p


# ------------------------------------------------------------------- ELLY --
def elly():
    """Soin et arme à feu. Fa majeur / Ré mineur (comme son thème LMS) :
    glissando de harpe et célesta pour le soin, cordes en trémolo et cœur qui bat
    pendant la visée, tutti orchestral sur la détonation (Si bémol), sifflet et
    guitare de western pour la fumée du canon, Fa majeur lumineux au papier."""
    p = Piece("Elly", "F3")
    mx = p.mx
    tv_opening(p, [(0, "C5", 1), (1, "F5", 1), (2, "G5", 1), (3, "A5", 2), (5, "G5", 1), (6, "F5", 1), (7, "D5", 1)], 0.3, ["F3", "A3", "C4"])
    def stab(t):
        mx.add(strings(["D2", "A2", "D3", "F3"], 0.3, a=0.01, r=0.4, bright=0.9, level=0.07, attack_bite=1.0), t, hall=0.3)
        mx.add(timpani("D2", 0.5), t, hall=0.3)
    rain_entry(p, stab)

    # HEAL · harp up the F pentatonic, celesta, warm strings
    harp_notes = ["F4", "G4", "A4", "C5", "D5", "F5", "G5", "A5", "C6", "D6", "F6"]
    for i, note in enumerate(harp_notes):
        mx.add(harp(note, 1.6, 0.11), 3.42 + i * 0.038, pan=-0.4 + 0.08 * i, hall=0.45)
    for i, note in enumerate(["F5", "A5", "C6", "F6"]):
        mx.add(bell(note, "celesta", 2.0, 0.08), 3.5 + i * 0.05, pan=0.3, hall=0.5)
    mx.add(strings(["F2", "C3", "F3", "A3", "C4"], 0.9, a=0.35, r=0.3, bright=0.7, level=0.06), 3.5, hall=0.45)
    mx.add(choir(["F4", "A4", "C5"], 0.85, "u", a=0.35, r=0.3, gain=0.035), 3.55, hall=0.55)
    mx.add(heartbeat(0.22), 3.75)

    # RISE · D minor tremolo, horns
    mx.add(strings(["D2", "A2", "D3"], 0.8, a=0.2, r=0.05, trem=15.0, bright=0.8, level=0.06), 4.4, hall=0.3)
    mx.add(brass(["D3", "F3", "A3"], 0.78, level=0.8, a=0.55, r=0.05, gain=0.06, mellow=True), 4.42, hall=0.35)
    mx.add(timpani("D2", 0.35), 4.4, hall=0.3)
    glint(p, 4.55, ["A6", "D7"])

    # DODGE · 5.2, spiccato pizz to the aim
    dodge = 5.2
    mx.add(strings(["D3", "F3", "A3", "D4"], 0.12, a=0.005, r=0.25, bright=1.1, level=0.07, attack_bite=1.2), dodge, hall=0.3)
    mx.add(whoosh(0.35, 0.12, 500, 5000), dodge - 0.05, pan=-0.3)
    mx.add(snare(0.3, tone=200), dodge, room=0.2)
    for i, note in enumerate(["D3", "D3", "F3", "D3"]):
        mx.add(pizz(note, 0.4, 0.14), dodge + 0.1375 * i + 0.06, pan=0.2, room=0.2)

    # AIM · 5.75: a held harmonic, ticking, the heart
    aim = 5.75
    mx.add(strings(["A6"], 0.38, a=0.08, r=0.05, bright=0.35, level=0.018, vib=0.002), aim, hall=0.5)
    for at in (5.8, 5.93, 6.03):
        mx.add(click(0.14, 2200), at, pan=0.3, room=0.3)
    mx.add(heartbeat(0.35), 5.77)
    mx.add(reverse_crash(0.6, 0.2), 6.15 - 0.6, hall=0.2)

    # BANG · 6.15: tutti on B flat
    bang = 6.15
    mx.add(boom(0.95, 3.0, 65, 33), bang, hall=0.3)
    mx.add(brass(["Bb1", "F2", "Bb2", "D3", "F3", "Bb3"], 0.45, level=1.6, a=0.006, r=0.7, gain=0.15, s=0.6), bang, hall=0.4)
    mx.add(strings(["Bb1", "F2", "Bb2", "F3", "Bb3", "D4", "F4"], 0.9, a=0.006, r=0.6, bright=1.2, level=0.08, attack_bite=1.2, s=0.6), bang, hall=0.45)
    mx.add(choir(["Bb3", "D4", "F4"], 0.8, "a", a=0.02, r=0.5, gain=0.05), bang, hall=0.5)
    mx.add(timpani("F2", 0.7), bang, hall=0.3)
    mx.add(timpani("Bb1", 0.5), bang + 0.01, hall=0.3)
    mx.add(crash(0.3, 3.0, 1.0), bang, pan=-0.3, hall=0.35)
    mx.add(crash(0.25, 3.0, 1.1), bang + 0.01, pan=0.3, hall=0.35)

    # COOL · 7.15: the smoke, a western whistle over a strummed C chord
    cool = 7.15
    for i, note in enumerate(["C3", "G3", "C4", "E4", "G4"]):
        mx.add(guitar(note, 1.2, 0.09), cool + 0.012 * i, pan=-0.25, plate=0.35)
        mx.add(guitar(note, 0.8, 0.06), cool + 0.35 + 0.01 * (4 - i), pan=-0.25, plate=0.35)
    for at, note, d in [(7.2, "C5", 0.16), (7.38, "F5", 0.16), (7.56, "G5", 0.16), (7.74, "A5", 0.5)]:
        mx.add(lead(note, d, "whistle", 0.06), at, pan=0.2, plate=0.45, hall=0.2)
    mx.add(strings(["C3", "G3", "E4"], 0.65, a=0.25, r=0.1, bright=0.7, level=0.035), cool, hall=0.4)

    # LEAVE · B flat, C, then F
    leave = 7.85
    for t0, t1, chord in [(leave, 8.4, ["Bb2", "F3", "Bb3", "D4"]), (8.4, p.ink, ["C3", "G3", "C4", "E4"])]:
        mx.add(strings(chord, t1 - t0 - 0.03, a=0.12, r=0.08, bright=0.9, level=0.07), t0, hall=0.4)
        mx.add(brass(chord[:3], t1 - t0 - 0.03, level=0.9, a=0.1, r=0.08, gain=0.07, mellow=True), t0, hall=0.4)
    for at, note, d in [(leave, "D5", 0.24), (leave + 0.27, "F5", 0.25), (8.4, "E5", 0.24), (8.67, "G5", 0.24)]:
        mx.add(lead(note, d, "trumpet", 0.07), at, hall=0.4)
    for i, note in enumerate(["C6", "F6", "A6"]):
        mx.add(bell(note, "celesta", 1.4, 0.05), 8.15 + 0.06 * i, pan=0.3, hall=0.5)
    mx.add(timp_roll("C2", 0.55, 0.4, start=0.3, end=1.0), 8.4)
    mx.add(reverse_crash(0.6, 0.18), p.ink - 0.6, hall=0.2)

    # INK · Fa majeur
    t = p.ink
    ink_hit(p)
    mx.add(timpani("F2", 0.6), t, hall=0.3)
    mx.add(brass(["F2", "C3", "F3", "A3", "C4"], 2.0, level=1.3, a=0.02, r=0.6, gain=0.13), t, hall=0.35)
    mx.add(strings(["F2", "C3", "F3", "A3", "C4", "F4", "A4"], 2.0, a=0.05, r=0.7, bright=1.1, level=0.09, attack_bite=0.8), t, hall=0.4)
    mx.add(choir(["F3", "C4", "F4", "A4"], 2.0, "a", a=0.1, r=0.8, gain=0.06), t, hall=0.5)
    for k, note in enumerate(["C5", "F5", "A5"]):
        mx.add(lead(note, 0.13, "trumpet", 0.09), t + 0.14 * k, hall=0.35)
    mx.add(lead("C6", 1.5, "trumpet", 0.095, r=0.5), t + 0.42, hall=0.4)
    for k, note in enumerate(["F6", "A6", "C7", "F7"]):
        mx.add(bell(note, "glock", 2.0, 0.07), t + 0.03 + 0.06 * k, pan=-0.4 + 0.27 * k, hall=0.5)

    tv_outro(p, [(0.08, "A5", 0.4), (0.38, "F5", 0.42), (0.38, "F4", 0.25)])
    return p


# --------------------------------------------------------------- BLEUETTE --
def bleuette():
    """Courage et boosts. Mi mineur puis Mi majeur (comme son thème LMS) : la
    peur en trémolos grinçants et cœur qui s'emballe, le chocolat en célesta, le
    « Je peux le faire ! » qui module en Mi majeur (glockenspiel, chœur), une
    marche bondissante à 146 BPM, un sifflet à coulisse pour la chute d'Alice."""
    p = Piece("Bleuette", "E3")
    mx = p.mx
    tv_opening(p, [(0, "E5", 1), (1, "G5", 1), (2, "B5", 1), (3, "A5", 1), (4, "G5", 1), (5, "F#5", 1), (6, "E5", 2)], 0.273, ["E3", "G3", "B3"])
    def stab(t):
        mx.add(strings(["E2", "F2", "Bb2", "E3"], 0.3, a=0.01, r=0.4, bright=0.9, level=0.07, attack_bite=1.0), t, hall=0.3)
        mx.add(timpani("E2", 0.5), t, hall=0.3)
    rain_entry(p, stab)

    # FEAR · 3.35 → 4.2: thin trembling strings, a heart running, Alice's brass
    mx.add(strings(["B4", "C5"], 0.85, a=0.3, r=0.05, trem=19.0, bright=1.4, level=0.035, vib=0.0), 3.35, hall=0.3)
    mx.add(brass(["E2", "F2", "Bb2"], 0.82, level=0.7, a=0.6, r=0.06, gain=0.06, mellow=True), 3.38, hall=0.3)
    for at, g in [(3.4, 0.25), (3.72, 0.3), (4.0, 0.34)]:
        mx.add(heartbeat(g), at)
    mx.add(bell("E7", "glock", 0.8, 0.04), 3.6, pan=0.3, hall=0.5)
    mx.add(bell("Bb5", "chime", 1.5, 0.035), 3.45, pan=-0.3, hall=0.5)

    # BITE · 4.2: chocolate
    bite = 4.2
    for i, note in enumerate(["C5", "E5", "G5", "C6"]):
        mx.add(bell(note, "celesta", 1.6, 0.11), bite + 0.07 * i, pan=0.25, hall=0.45)
    for at in (bite + 0.02, bite + 0.1, bite + 0.17):
        mx.add(norm_peak(bp(noise(0.05), 1800, 6500) * env_perc(S(0.05), 70.0), 0.08), at, pan=0.1)
    mx.add(strings(["C3", "G3", "C4", "E4"], 1.05, a=0.25, r=0.1, bright=0.7, level=0.05), bite, hall=0.45)
    mx.add(choir(["E4", "G4", "C5"], 1.0, "u", a=0.3, r=0.1, gain=0.03), bite + 0.05, hall=0.55)
    mx.add(bell("G6", "glock", 0.8, 0.035), 4.6, pan=0.35, hall=0.5)
    mx.add(bell("E6", "glock", 0.8, 0.035), 4.95, pan=-0.35, hall=0.5)

    # BRAVE · 5.3: the climb, the B7, then E major at 5.65
    brave = 5.3
    for i, note in enumerate(["B3", "C#4", "D#4", "E4", "F#4", "G#4", "A4", "B4"]):
        mx.add(strings([note], 0.05, a=0.006, r=0.06, bright=1.0, level=0.05, vib=0.0), brave + i * 0.044, hall=0.3)
    mx.add(timp_roll("B1", 0.35, 0.4, start=0.2, end=1.0), brave)
    mx.add(choir(["B3", "D#4", "F#4", "A4"], 0.33, "a", a=0.2, r=0.05, gain=0.04), brave, hall=0.4)
    mx.add(snare_roll(0.34, 0.16, rate=26.0, start=0.2, end=1.0), brave)
    up = 5.65
    mx.add(brass(["E2", "B2", "E3", "G#3", "B3", "E4"], 0.7, level=1.3, a=0.01, r=0.4, gain=0.13), up, hall=0.4)
    mx.add(strings(["E2", "B2", "E3", "G#3", "B3", "E4", "G#4"], 0.75, a=0.01, r=0.4, bright=1.1, level=0.08, attack_bite=1.0), up, hall=0.45)
    mx.add(choir(["E4", "G#4", "B4"], 0.75, "a", a=0.05, r=0.4, gain=0.05), up, hall=0.5)
    for i, note in enumerate(["E6", "G#6", "B6", "E7"]):
        mx.add(bell(note, "glock", 1.8, 0.08), up + 0.06 * i, pan=-0.3 + 0.2 * i, hall=0.5)
    mx.add(crash(0.25, 2.5), up, pan=0.3, hall=0.3)
    mx.add(timpani("E2", 0.6), up, hall=0.3)
    mx.add(boom(0.45, 1.8, 80, 32), up)
    for k, note in enumerate(["E5", "G#5"]):
        mx.add(lead(note, 0.13, "trumpet", 0.08), up + 0.15 * k, hall=0.4)
    mx.add(lead("B5", 0.45, "trumpet", 0.085, r=0.3), up + 0.3, hall=0.4)

    # LUNGE · 6.45: the run, then a bouncing march on eighths of 0.205 s
    lunge = 6.45
    g = (7.27 - lunge) / 4
    for i, note in enumerate(["E5", "F#5", "G#5", "A5", "B5", "C#6", "D#6", "E6"]):
        mx.add(flute(note, 0.04, 0.05), lunge + i * 0.044, pan=0.2, hall=0.3)
    mx.add(whoosh(0.4, 0.12, 600, 6000), lunge - 0.05, pan=-0.3)
    for i, note in enumerate(["E2", "B2", "E2", "B2"]):
        mx.add(pizz(note, 0.4, 0.2), lunge + i * g, room=0.2)
        if i % 2 == 1:
            mx.add(snare(0.18, tone=220, decay=22), lunge + i * g, room=0.2)
    mx.add(slide_whistle(0.36, "C7", "C5", 0.08), 6.9, pan=0.2, hall=0.3)
    fall = 7.27
    mx.add(timpani("E2", 0.6), fall, hall=0.3)
    mx.add(tom("E2", 0.5), fall)
    mx.add(crash(0.18, 0.5, 9.0), fall, pan=0.3, room=0.3)
    for k, note in enumerate(["B6", "E7", "G#7"]):
        mx.add(bell(note, "glock", 0.9, 0.045), fall + 0.06 + 0.07 * k, pan=0.4 - 0.4 * k, hall=0.5)

    # MARCH · 7.27 → 8.7: E, A, B7, (E at the paper)
    bass = ["E2", "B2", "A2", "E2", "B1", "F#2", "B1"]
    chords = [["E3", "G#3", "B3"], ["E3", "G#3", "B3"], ["A3", "C#4", "E4"], ["A3", "C#4", "E4"], ["B3", "D#4", "A4"], ["B3", "D#4", "A4"], ["B3", "D#4", "F#4", "A4"]]
    melody = [("E5", 1), ("G#5", 1), ("B5", 2), None, ("F#5", 1), ("A5", 1), ("B5", 1)]
    for i in range(7):
        t = fall + i * g
        mx.add(pizz(bass[i], 0.4, 0.2), t, room=0.2)
        mx.add(kick(0.35, 90, 45, 10.0) if i % 2 == 0 else snare(0.2, tone=220, decay=20), t, room=0.15)
        mx.add(snare(0.07, tone=220, decay=26), t + g / 2, room=0.1)
        mx.add(strings(chords[i], g * 0.4, a=0.01, r=0.1, bright=1.0, level=0.04), t + g / 2, hall=0.25)
        if melody[i]:
            note, length = melody[i]
            mx.add(lead(note, g * length * 0.9, "trumpet", 0.075), t, hall=0.35)
            mx.add(bell(tr(note, 12), "glock", 1.0, 0.04), t, pan=0.3, hall=0.4)
    mx.add(brass(["B2", "D#3", "F#3", "A3"], 0.6, level=1.0, a=0.15, r=0.05, gain=0.07), 8.09, hall=0.35)
    mx.add(timp_roll("B1", 0.4, 0.35, start=0.3, end=1.0), p.ink - 0.4)
    mx.add(reverse_crash(0.45, 0.18), p.ink - 0.45, hall=0.2)

    # INK · Mi majeur
    t = p.ink
    ink_hit(p)
    mx.add(timpani("E2", 0.6), t, hall=0.3)
    mx.add(brass(["E2", "B2", "E3", "G#3", "B3", "E4"], 2.0, level=1.3, a=0.02, r=0.6, gain=0.13), t, hall=0.35)
    mx.add(strings(["E2", "B2", "E3", "G#3", "B3", "E4", "G#4", "B4"], 2.0, a=0.05, r=0.7, bright=1.1, level=0.09, attack_bite=0.8), t, hall=0.4)
    mx.add(choir(["E4", "G#4", "B4", "E5"], 2.0, "a", a=0.1, r=0.8, gain=0.06), t, hall=0.5)
    for k, note in enumerate(["E5", "G#5", "B5"]):
        mx.add(lead(note, 0.12, "trumpet", 0.09), t + 0.13 * k, hall=0.35)
    mx.add(lead("E6", 1.5, "trumpet", 0.09, r=0.5), t + 0.39, hall=0.4)
    for k, note in enumerate(["E6", "G#6", "B6", "E7", "G#7"]):
        mx.add(bell(note, "glock", 2.0, 0.07), t + 0.03 + 0.06 * k, pan=-0.4 + 0.2 * k, hall=0.5)

    tv_outro(p, [(0.08, "B5", 0.4), (0.38, "E6", 0.4), (0.38, "E5", 0.25)])
    return p


# -------------------------------------------------------------- ambiences --
def _sparse(n, rate, r):
    """Random impulse train: about `rate` impulses per second."""
    x = np.zeros(n)
    count = int(rate * n / SR)
    idx = r.integers(0, n, count)
    np.add.at(x, idx, r.uniform(0.2, 1.0, count) ** 2 * r.choice([-1.0, 1.0], count))
    return x


def _fftconv1(x, k):
    size = _size(len(x) + len(k))
    return np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(k, size), size)[: len(x)]


def loop_join(x, overlap):
    """Seamless loop: the last `overlap` seconds fade into the first ones."""
    k = S(overlap)
    head = x[:k].copy()
    body = x[k:].copy()
    ramp = np.sin(np.linspace(0, np.pi / 2, k)) ** 2
    ramp = ramp[:, None] if x.ndim == 2 else ramp
    body[-k:] = body[-k:] * (1 - ramp) ** 0.5 + head * ramp ** 0.5
    return body


def rain_loop(seconds=10.0):
    """Night rain on a schoolyard: a hissing bed, thousands of fine drops,
    bubbly splashes in the puddles, a gutter dripping on one side."""
    r = np.random.default_rng(2024)
    total = seconds + 1.2
    n = S(total)
    t = np.arange(n) / SR
    out = np.zeros((n, 2))
    gust = 0.8 + 0.2 * np.sin(TAU * 0.13 * t + 1.0) + 0.08 * np.sin(TAU * 0.41 * t)
    for c in range(2):
        bed = r.standard_normal(n)
        bed = spectral(bed, lambda f: (np.maximum(f, 50) / 1000.0) ** -0.35 / np.sqrt(1 + (300 / f) ** 4) / np.sqrt(1 + (f / 9000) ** 4))
        out[:, c] += norm_rms(bed, 0.05) * gust
        for lo, hi, rate, dec, g in [(3000, 9000, 1600, 900.0, 0.05), (1500, 5000, 700, 500.0, 0.05), (700, 2500, 160, 260.0, 0.045)]:
            kern = bp(r.standard_normal(S(0.03)), lo, hi, 2) * np.exp(-np.arange(S(0.03)) / SR * dec)
            drops = _fftconv1(_sparse(n, rate, r), kern)
            out[:, c] += norm_rms(drops, g) * gust
    # splashes: tiny bubbles whose pitch rises as they close
    for _ in range(int(14 * total)):
        at = r.uniform(0, total - 0.05)
        f0 = r.uniform(1200, 4200)
        d = r.uniform(0.012, 0.035)
        k = S(d)
        tt = np.arange(k) / SR
        bub = np.sin(TAU * np.cumsum(f0 * (1 + 2.5 * tt / d * r.uniform(0.2, 0.6))) / SR) * np.exp(-tt / d * 4.0)
        i = S(at)
        pan = r.uniform(-0.9, 0.9)
        g = r.uniform(0.01, 0.04)
        out[i:i + k, 0] += bub * g * np.cos((pan + 1) * np.pi / 4) * 1.4
        out[i:i + k, 1] += bub * g * np.sin((pan + 1) * np.pi / 4) * 1.4
    # a gutter on the left, irregular
    at = 0.3
    while at < total - 0.2:
        k = S(0.06)
        tt = np.arange(k) / SR
        f0 = r.uniform(700, 950)
        drip = np.sin(TAU * np.cumsum(f0 * (1 + 0.6 * tt / 0.06)) / SR) * np.exp(-tt * 70)
        i = S(at)
        out[i:i + k, 0] += drip * 0.035
        out[i:i + k, 1] += drip * 0.012
        at += r.uniform(0.35, 0.9)
    rumble = lp(r.standard_normal(n), 160, 2)
    out += pan2(norm_rms(rumble, 0.03) * gust)
    out = loop_join(out, 1.2)
    return out


def tv_loop(seconds=4.0):
    """A CRT between channels: static that flutters, the line whine, mains hum
    through a small speaker, a few pops."""
    r = np.random.default_rng(1985)
    total = seconds + 0.4
    n = S(total)
    t = np.arange(n) / SR
    flutter = 0.75 + 0.25 * lp(r.standard_normal(n), 30, 1) / 0.05
    flutter = np.clip(flutter, 0.4, 1.2)
    hiss = bp(r.standard_normal(n), 900, 9000, 2)
    hiss = norm_rms(hiss, 0.08) * flutter
    pops = _fftconv1(_sparse(n, 9, r), hp(r.standard_normal(S(0.004)), 1500))
    hum = sum(np.sin(TAU * 50.0 * k * t) / k for k in (2, 3, 4, 5)) * 0.012
    whine = np.sin(TAU * 15734.0 * t) * 0.006
    mono = hiss + norm_rms(pops, 0.02) + hum + whine
    st = np.stack([mono, mono * 0.92 + 0.08 * bp(r.standard_normal(n), 900, 9000, 2) * 0.08], axis=1)
    return loop_join(st, 0.4)


def thunder(seconds=4.6):
    """Close lightning: a split crack, then the roll moving across the sky."""
    r = np.random.default_rng(77)
    n = S(seconds)
    t = np.arange(n) / SR
    out = np.zeros((n, 2))
    for k in range(5):
        at = r.uniform(0.0, 0.09) if k else 0.0
        d = 0.35
        kk = S(d)
        tt = np.arange(kk) / SR
        crack = hp(r.standard_normal(kk), 700, 2) * np.exp(-tt * r.uniform(18, 30)) * r.uniform(0.5, 1.0)
        i = S(at)
        pan = r.uniform(-0.5, 0.5)
        out[i:i + kk] += pan2(crack, pan)[: n - i]
    body = np.zeros(n)
    base = lp(r.standard_normal(n), 240, 2)
    env = np.exp(-t * 0.9) * np.minimum(1.0, t / 0.08)
    for _ in range(6):
        c = r.uniform(0.15, 2.8)
        w = r.uniform(0.2, 0.6)
        env = env + 0.8 * np.exp(-((t - c) / w) ** 2) * np.exp(-c * 0.7)
    body = base * env
    mid = bp(r.standard_normal(n), 200, 1200, 2) * env * np.exp(-t * 1.2)
    roll = np.stack([body + 0.3 * mid, np.roll(body, S(0.012)) + 0.3 * np.roll(mid, S(0.02))], axis=1)
    out = norm_peak(out, 0.6) + norm_peak(roll, 0.9)
    out = convolve(out, ir("hall")) * 0.35 + out
    return fade_edges(out, 0.0, 0.4)


def finish_sfx(x, target, loop=False):
    level, _peak = measure(np.concatenate([x, x]) if loop else x)
    x = x * 10 ** ((target - level) / 20.0)
    return limiter(x, -3.0)


PIECES = {"Ashura": "ashura", "Usayuko": "usayuko", "Simon": "simon", "Lysia": "lysia", "Elly": "elly", "Bleuette": "bleuette"}


def analyse(x, step=0.25):
    rows = []
    for i in range(0, len(x), S(step)):
        seg = x[i:i + S(step)]
        rows.append("%5.2f %6.1f" % (i / SR, 20 * np.log10(rms(seg) + 1e-9)))
    return rows


def main(argv):
    global rng
    out_dir = "audio/victory"
    only = None
    wav = None
    show = False
    i = 0
    while i < len(argv):
        if argv[i] == "--only":
            only = argv[i + 1].split(",")
            i += 1
        elif argv[i] == "--wav":
            wav = argv[i + 1]
            i += 1
        elif argv[i] == "--out":
            out_dir = argv[i + 1]
            i += 1
        elif argv[i] == "--show":
            show = True
        i += 1
    os.makedirs(out_dir, exist_ok=True)
    for name, fn in PIECES.items():
        if only and name not in only:
            continue
        rng = np.random.default_rng(sum(map(ord, name)))
        piece = globals()[fn]()
        x = piece.render()
        x, level, peak = master(x)
        write_ogg(x, os.path.join(out_dir, name + ".ogg"), wav)
        print("%-9s %.2f s  %.1f LUFS  true peak %.1f dBTP" % (name, len(x) / SR, level, peak))
        if show:
            print("\n".join(analyse(x)))
    if only and "sfx" not in only:
        return
    for name, fn, target, loop in (("rain", rain_loop, -25.0, True), ("tv", tv_loop, -22.0, True), ("thunder", thunder, -18.0, False)):
        rng = np.random.default_rng(sum(map(ord, name)))
        x = finish_sfx(fn(), target, loop)
        write_ogg(x, os.path.join(out_dir, name + ".ogg"), wav, quality=5)
        level, peak = measure(x)
        print("%-9s %.2f s  %.1f LUFS  true peak %.1f dBTP" % (name, len(x) / SR, level, peak))


if __name__ == "__main__":
    main(sys.argv[1:])
