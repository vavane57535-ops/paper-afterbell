#!/usr/bin/env python3
"""Synthèse de l'audio PROVISOIRE du prologue « Yiero » (Paper Afterbell 0.16).

Produit :
  audio/cinematic/intro_yiero.ogg  — musique provisoire de 196 s calée sur la feuille de minutage
                                      de docs/INTRO-YIERO.md (à remplacer par une vraie composition)
  audio/cinematic/sfx_*.wav         — bruitages synthétisés du film

Usage : python3 tools/synth_intro_audio.py  (numpy + ffmpeg avec libvorbis)
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 44100
LENGTH = 196.0
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "audio", "cinematic")
rng = np.random.default_rng(1313)


def t_axis(seconds):
    return np.arange(int(seconds * SR)) / SR


def env_adsr(n, a, d, s, r, sustain=1.0):
    e = np.ones(n) * s
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    na = min(na, n)
    e[:na] = np.linspace(0, 1, na, endpoint=False) if na else e[:na]
    if nd and na + nd < n:
        e[na:na + nd] = np.linspace(1, s, nd, endpoint=False)
    if nr:
        nr = min(nr, n)
        e[n - nr:] *= np.linspace(1, 0, nr)
    return e * sustain


def lp_fast(x, cutoff):
    """Passe-bas par FFT (pente douce), pour les longs signaux."""
    n = len(x)
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(n, 1 / SR)
    spec *= 1.0 / np.sqrt(1.0 + (freqs / cutoff) ** 4)
    return np.fft.irfft(spec, n)


def hp_fast(x, cutoff):
    n = len(x)
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(n, 1 / SR)
    spec *= 1.0 - 1.0 / np.sqrt(1.0 + (freqs / max(cutoff, 1.0)) ** 4)
    return np.fft.irfft(spec, n)


def bp_fast(x, low, high):
    return hp_fast(lp_fast(x, high), low)


def saw(freq, t, detune=0.0):
    phase = np.cumsum(np.full_like(t, freq) * (1 + detune) / SR) if np.isscalar(freq) else np.cumsum(freq * (1 + detune) / SR)
    return 2 * (phase % 1.0) - 1


def sine_sweep(f0, f1, seconds, curve=2.0):
    t = t_axis(seconds)
    u = t / max(seconds, 1e-6)
    f = f0 + (f1 - f0) * (u ** curve if f1 < f0 else 1 - (1 - u) ** curve)
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def note(n):
    """n = demi-tons depuis La4 (440 Hz)."""
    return 440.0 * 2 ** (n / 12.0)


NOTES = {"D1": -43, "A1": -36, "D2": -31, "F2": -28, "G2": -26, "A2": -24, "Bb2": -23, "C3": -21, "D3": -19, "E3": -17, "F3": -16,
         "G3": -14, "A3": -12, "Bb3": -11, "C4": -9, "C#4": -8, "D4": -7, "E4": -5, "F4": -4, "F#4": -3, "G4": -2, "G#4": -1, "A4": 0, "Bb4": 1,
         "C5": 3, "D5": 5, "Eb5": 6, "E5": 7, "F5": 8, "G5": 10, "A5": 12, "D6": 17}


def hz(name):
    return note(NOTES[name])


class Mix:
    def __init__(self, seconds):
        self.n = int(seconds * SR)
        self.l = np.zeros(self.n)
        self.r = np.zeros(self.n)

    def add(self, start, sig, gain=1.0, pan=0.0):
        i = int(start * SR)
        if i >= self.n or len(sig) == 0:
            return
        j = min(self.n, i + len(sig))
        s = sig[: j - i] * gain
        self.l[i:j] += s * np.sqrt(0.5 * (1 - pan))
        self.r[i:j] += s * np.sqrt(0.5 * (1 + pan))


def pad(freqs, seconds, attack=1.5, release=1.5, bright=900.0, voices=3):
    t = t_axis(seconds)
    out = np.zeros(len(t))
    for f in freqs:
        for v in range(voices):
            det = (v - (voices - 1) / 2) * 0.006
            vib = 1 + 0.003 * np.sin(2 * np.pi * (4.8 + v * 0.3) * t + v)
            out += saw(f * vib, t, det)
    out = lp_fast(out, bright) / (len(freqs) * voices)
    return out * env_adsr(len(t), attack, 0.3, 1.0, release)


def choir(freqs, seconds, attack=1.2, release=1.5):
    t = t_axis(seconds)
    out = np.zeros(len(t))
    for f in freqs:
        for k, amp in [(1, 1.0), (2, 0.5), (3, 0.32), (4, 0.18), (5, 0.12)]:
            vib = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * t + f)
            out += amp * np.sin(2 * np.pi * np.cumsum(np.full(len(t), f * k) * vib) / SR)
    out /= len(freqs) * 2.0
    return out * env_adsr(len(t), attack, 0.3, 1.0, release)


def drone(freq, seconds, attack=2.0, release=2.0):
    t = t_axis(seconds)
    s = np.sin(2 * np.pi * freq * t) + 0.5 * np.sin(2 * np.pi * freq * 0.5 * t) + 0.25 * np.sin(2 * np.pi * freq * 1.5 * t + 0.4)
    noise = lp_fast(rng.standard_normal(len(t)), 90.0) * 0.6
    return (s * 0.5 + noise) * env_adsr(len(t), attack, 0.5, 1.0, release)


def taiko(gain=1.0, pitch=1.0):
    t = t_axis(0.9)
    body = sine_sweep(150 * pitch, 48 * pitch, 0.9, 3.0) * np.exp(-t * 6.0)
    click = lp_fast(rng.standard_normal(len(t)), 2500) * np.exp(-t * 60.0) * 0.5
    return (body + click) * gain


def kick():
    t = t_axis(0.35)
    return sine_sweep(160, 45, 0.35, 4.0) * np.exp(-t * 11.0)


def snare():
    t = t_axis(0.25)
    return (bp_fast(rng.standard_normal(len(t)), 900, 7000) * 0.7 + np.sin(2 * np.pi * 190 * t) * 0.4) * np.exp(-t * 18.0)


def hat():
    t = t_axis(0.06)
    return hp_fast(rng.standard_normal(len(t)), 7000) * np.exp(-t * 70.0) * 0.5


def stab(freqs, seconds=0.16, bright=2200.0):
    t = t_axis(seconds)
    out = sum(saw(f, t) for f in freqs) / len(freqs)
    return lp_fast(out, bright) * np.exp(-t * 14.0)


def hit_big(gain=1.0, chord=("D2", "A2", "D3", "F3", "A3")):
    t = t_axis(3.2)
    boom = sine_sweep(110, 32, 3.2, 3.0) * np.exp(-t * 1.6)
    noise = lp_fast(rng.standard_normal(len(t)), 3000) * np.exp(-t * 5.0) * 0.6
    brass = lp_fast(sum(saw(hz(n), t) for n in chord) / len(chord), 1600) * np.exp(-t * 1.4) * 0.7
    return (boom + noise + brass) * gain


def riser(seconds, gain=1.0):
    t = t_axis(seconds)
    u = t / seconds
    noise = rng.standard_normal(len(t))
    out = np.zeros(len(t))
    seg = int(SR * 0.25)
    for i in range(0, len(t), seg):
        cut = 300 + 9000 * (i / len(t)) ** 2
        out[i:i + seg] = bp_fast(noise[i:i + seg], cut * 0.5, cut)
    tone = np.sin(2 * np.pi * np.cumsum(200 + 900 * u ** 2) / SR) * 0.25
    return (out * 0.6 + tone) * u ** 2 * gain


def piano(freq, seconds=3.0):
    t = t_axis(seconds)
    s = sum(a * np.sin(2 * np.pi * freq * k * t) * np.exp(-t * (1.2 + k * 0.6)) for k, a in [(1, 1.0), (2, 0.45), (3, 0.25), (4, 0.12)])
    return s * np.minimum(1, t / 0.005)


def musicbox(freq, seconds=1.6):
    t = t_axis(seconds)
    s = np.sin(2 * np.pi * freq * t) + 0.4 * np.sin(2 * np.pi * freq * 3.01 * t) * np.exp(-t * 4) + 0.2 * np.sin(2 * np.pi * freq * 5.4 * t) * np.exp(-t * 7)
    return s * np.exp(-t * 2.2) * np.minimum(1, t / 0.003)


def build_music():
    m = Mix(LENGTH)
    # 0–5 ouverture : drone + vent
    m.add(0.0, drone(36.7, 17.5, 3.0, 2.5), 0.55)
    wind = bp_fast(rng.standard_normal(int(SR * 30)), 200, 900) * 0.18
    m.add(0.0, wind * env_adsr(len(wind), 3.0, 0.5, 1.0, 4.0), 0.6, -0.3)
    # 5–17 nappe sombre ré mineur + chœur lointain
    m.add(5.0, pad([hz("D3"), hz("F3"), hz("A3")], 12.5, 4.0, 2.0, 700), 0.32)
    m.add(7.0, choir([hz("D4"), hz("A4")], 10.0, 3.0, 2.0), 0.08, 0.2)
    # 17–24 + pulsation sourde 50 bpm
    m.add(16.5, drone(36.7, 13.0, 1.0, 1.0), 0.45)
    m.add(17.0, pad([hz("D3"), hz("F3"), hz("Bb3")], 7.5, 1.0, 1.5, 650), 0.3)
    for k in range(6):
        m.add(17.0 + k * 1.2, taiko(0.45, 0.6), 0.7)
    # 24–29 tension : trémolo aigu cluster crescendo
    tt = t_axis(5.0)
    trem = (np.sin(2 * np.pi * hz("D5") * tt) + np.sin(2 * np.pi * hz("Eb5") * tt)) * (0.5 + 0.5 * np.sin(2 * np.pi * 13 * tt))
    m.add(24.0, trem * np.linspace(0.0, 1.0, len(tt)) ** 2 * 0.14, 1.0, 0.25)
    m.add(24.0, pad([hz("D3"), hz("Eb5") / 2], 5.0, 1.0, 0.05, 800), 0.25)
    # 29–30 silence ; 30–34 chute de sous-basse + note grave de piano
    m.add(30.2, sine_sweep(90, 24, 3.0, 2.0) * np.exp(-t_axis(3.0) * 0.6), 0.45)
    m.add(32.0, piano(hz("D2"), 4.0) + piano(hz("D1") * 2, 4.0) * 0.6, 0.35)
    # 34–46 horreur : clusters dissonants montants + cuivres graves + tic-tac
    for k, (a, b) in enumerate([("D3", "Eb5"), ("F3", "E5"), ("G#4", "A4")]):
        m.add(34.0 + k * 0.4, pad([hz(a), hz(b), hz(a) * 1.06], 12.5 - k * 0.4, 3.0, 1.0, 1100 + k * 200), 0.2)
    m.add(36.0, pad([hz("D2"), hz("A2") * 1.06], 10.0, 4.0, 0.5, 400), 0.22)
    for k in range(24):
        m.add(34.0 + k * 0.5, hp_fast(rng.standard_normal(1200) * np.exp(-np.arange(1200) / 140.0), 3000), 0.12, 0.4 if k % 2 else -0.4)
    m.add(40.0, drone(30.0, 10.0, 1.0, 0.3), 0.3)
    # 46–50 suspense, crescendo
    m.add(46.0, pad([hz("D3"), hz("Eb5") / 2, hz("G#4") / 2, hz("A3")], 4.2, 2.5, 0.1, 1800), 0.32)
    m.add(46.5, riser(3.7, 0.35))
    # 50.2 rugissement : impact massif
    m.add(50.2, hit_big(1.6), 1.0)
    m.add(50.2, taiko(1.3, 0.7), 1.0)
    # 52–58 montée héroïque : ostinato 140 bpm + taikos + chœur à 55
    beat = 60.0 / 140.0
    ost = ["D4", "D4", "F4", "D4", "A4", "D4", "F4", "E4"]
    t0 = 52.0
    k = 0
    while t0 + k * beat / 2 < 58.0:
        tt = t0 + k * beat / 2
        m.add(tt, stab([hz(ost[k % 8])], 0.18, 2600), 0.18 + 0.12 * (tt - 52) / 6, 0.15 if k % 2 else -0.15)
        if k % 2 == 0:
            m.add(tt, taiko(0.5 + 0.4 * (tt - 52) / 6, 1.0), 0.7)
        k += 1
    m.add(55.0, choir([hz("D4"), hz("F4"), hz("A4")], 3.0, 0.6, 0.6), 0.22)
    m.add(55.0, hit_big(0.5, ("D2", "A2", "D3")), 0.6)
    m.add(55.0, riser(3.0, 0.45))
    # 58–82 combat épique
    prog = [("D3", "F3", "A3", "D2"), ("Bb2", "D3", "F3", "Bb2"), ("F3", "A3", "C4", "F2"), ("C3", "E3", "G3", "C3")]
    bar = beat * 4
    tt = 58.0
    i = 0
    while tt < 79.0:
        chord = prog[(i // 2) % 4]
        m.add(tt, pad([hz(c) for c in chord[:3]], bar + 0.1, 0.05, 0.15, 1800), 0.35)
        m.add(tt, pad([hz(chord[3]) / 2], bar + 0.1, 0.02, 0.1, 300), 0.4)
        m.add(tt, choir([hz(c) * 2 for c in chord[:3]], bar + 0.2, 0.2, 0.3), 0.12)
        for s in range(8):
            st = tt + s * beat / 2
            m.add(st, stab([hz(chord[s % 3]) * 2], 0.15, 3000), 0.2, 0.2 if s % 2 else -0.2)
        for s in [0, 1.5, 2, 3, 3.5]:
            m.add(tt + s * beat, taiko(0.85 if s in (0, 2) else 0.55), 0.8)
        tt += bar
        i += 1
    for hit_t, g in [(63.2, 0.8), (69.5, 0.7), (76.0, 0.6)]:
        m.add(hit_t, hit_big(g), 0.8)
    # 79–82 espoir : accord majeur
    m.add(79.0, hit_big(1.0, ("D2", "A2", "D3", "F#4", "A3")), 0.9)
    m.add(79.0, pad([hz("D3"), hz("F#4"), hz("A4"), hz("D5")], 3.2, 0.05, 0.8, 2400), 0.5)
    m.add(79.0, choir([hz("D4"), hz("F#4"), hz("A4")], 3.2, 0.2, 0.8), 0.28)
    # 82–87 moquerie : note grave tenue
    m.add(82.0, pad([hz("D1") * 2], 5.2, 0.3, 1.0, 250), 0.6)
    # 87–104 retournement : demi-tempo lourd
    half = 60.0 / 70.0
    dark = [("D3", "F3", "A3"), ("G2", "Bb2", "D3"), ("A2", "C#4", "E3"), ("D3", "F3", "A3")]
    tt = 87.0
    i = 0
    while tt < 104.0:
        chord = dark[i % 4]
        m.add(tt, pad([hz(c) for c in chord], half * 4 + 0.2, 0.3, 0.4, 1200), 0.42)
        m.add(tt, pad([hz(chord[0]) / 2], half * 4 + 0.2, 0.1, 0.3, 260), 0.45)
        m.add(tt, taiko(1.0, 0.8), 0.9)
        m.add(tt + half * 2, taiko(0.8, 0.8), 0.85)
        tt += half * 4
        i += 1
    m.add(92.9, hit_big(0.9), 0.85)
    m.add(99.4, hit_big(0.9, ("D2", "Bb2", "D3", "F3")), 0.85)
    # 104–119.2 élégie
    eleg = [("D3", "F3", "A3"), ("Bb2", "D3", "F3"), ("G2", "Bb2", "D3"), ("A2", "C#4", "E3")]
    for k, chord in enumerate(eleg):
        m.add(104.0 + k * 3.8, pad([hz(c) for c in chord], 4.2, 1.2, 1.2, 900), 0.36)
    melody = [("A4", 104.5, 1.6), ("G4", 106.1, 0.8), ("F4", 106.9, 1.5), ("E4", 108.4, 1.2), ("D4", 109.6, 2.4), ("F4", 112.0, 1.5), ("E4", 113.5, 2.5)]
    for n, st, du in melody:
        m.add(st, choir([hz(n)], du + 0.4, 0.25, 0.4), 0.2, 0.1)
    rev = riser(3.7, 0.4)
    m.add(113.8, rev, 0.6)
    # 119.2–121 silence + sifflement ; 121–122 menace
    m.add(119.4, np.sin(2 * np.pi * 3600 * t_axis(1.6)) * np.linspace(0.05, 0, int(SR * 1.6)), 0.6)
    m.add(121.0, sine_sweep(60, 40, 1.2, 1.5) * np.linspace(0, 1, int(SR * 1.2)), 0.6)
    # 122–148 poursuite 160 bpm
    b = 60.0 / 160.0
    run = ["D4", "D4", "F4", "D4", "E4", "D4", "C4", "D4"]
    tt = 122.0
    k = 0
    while tt < 148.0:
        inten = 0.6 + 0.4 * (tt - 122.0) / 26.0
        if k % 2 == 0:
            m.add(tt, kick(), 0.7 * inten)
        if k % 4 == 2:
            m.add(tt, snare(), 0.45 * inten)
        m.add(tt, hat(), 0.25)
        m.add(tt, stab([hz(run[k % 8]), hz(run[k % 8]) / 2], 0.14, 2400), 0.22 * inten, 0.2 if k % 2 else -0.2)
        if k % 8 == 0:
            m.add(tt, pad([hz("D2")], b * 8, 0.02, 0.1, 280), 0.4)
            m.add(tt, taiko(0.8, 0.9), 0.7 * inten)
        tt += b / 2 if tt > 140 else b
        k += 1
    for st in (132.0, 133.6, 137.2, 138.4):
        m.add(st, stab([hz("D2"), hz("A2"), hz("D3")], 0.6, 1400), 0.7)
    m.add(140.0, pad([hz("A4"), hz("D5"), hz("E5")], 8.0, 0.8, 0.5, 4000), 0.22, 0.1)
    # 148–150.6 accord tenu énorme
    m.add(148.0, pad([hz("D2"), hz("A2"), hz("D3"), hz("E4"), hz("F4"), hz("A4")], 2.62, 0.3, 0.02, 3000), 0.6)
    m.add(148.0, riser(2.6, 0.6))
    # 150.6–153.2 silence blanc + acouphène
    m.add(150.7, np.sin(2 * np.pi * 4100 * t_axis(2.4)) * np.linspace(0.06, 0, int(SR * 2.4)), 0.6)
    # 153.2–157.5 école : piano doux
    for st, n in [(153.6, "F4"), (154.1, "A4"), (154.6, "C5"), (155.1, "A4"), (155.6, "G4"), (156.3, "F4")]:
        m.add(st, piano(hz(n), 2.5), 0.28)
    # 157.5–179.7 bagarre déjantée 165 bpm (filtrée 166–173.5)
    rb = 60.0 / 165.0
    riffs = [("D3", "A3"), ("D3", "A3"), ("F3", "C4"), ("G3", "D4")]
    groove = Mix(LENGTH)
    tt = 157.5
    k = 0
    while tt < 179.7:
        if k % 2 == 0:
            groove.add(tt, kick(), 0.8)
        if k % 4 == 2:
            groove.add(tt, snare(), 0.55)
        groove.add(tt, hat(), 0.3)
        r = riffs[(k // 8) % 4]
        guitar = np.tanh(stab([hz(r[0]), hz(r[1]), hz(r[0]) * 2], rb * 0.9, 3500) * 6) * 0.5
        groove.add(tt, guitar, 0.32, 0.25 if k % 2 else -0.25)
        groove.add(tt, stab([hz(r[0]) / 2], rb * 0.9, 600), 0.4)
        tt += rb / 2
        k += 1
    gl = groove.l.copy()
    gr = groove.r.copy()
    a, z = int(166.0 * SR), int(173.5 * SR)
    gl[a:z] = lp_fast(gl[a:z], 700) * 0.55
    gr[a:z] = lp_fast(gr[a:z], 700) * 0.55
    m.l += gl
    m.r += gr
    m.add(173.5, pad([hz("D3"), hz("F3"), hz("A3"), hz("D4")], 6.2, 2.0, 0.05, 2500), 0.3)
    m.add(176.0, riser(3.7, 0.4))
    m.add(179.72, hit_big(1.0, ("D2", "A2", "D3", "F#4", "A3")), 0.6)
    cut = int(179.8 * SR)
    fade = int(0.05 * SR)
    for ch in (m.l, m.r):
        ch[cut:cut + fade] *= np.linspace(1, 0, fade)
        ch[cut + fade:int(182.0 * SR)] = 0.0
    # 182–184.6 retour du démon
    m.add(182.0, drone(36.7, 4.0, 1.5, 0.8), 0.5)
    for st in (182.6, 183.4, 184.0):
        m.add(st, taiko(0.6, 0.55), 0.6)
    # 184.6 titre
    m.add(184.6, hit_big(1.2, ("D2", "A2", "D3", "F3", "A3", "D4")), 0.95)
    m.add(184.6, choir([hz("D4"), hz("F4"), hz("A4"), hz("D5")], 3.0, 0.05, 2.0), 0.3)
    # 186.6–192 boîte à musique désaccordée
    box = [("D5", 186.8), ("C5", 187.3), ("A4", 187.8), ("G#4", 188.4), ("D5", 189.4), ("C5", 189.9), ("A4", 190.4), ("G#4", 191.0)]
    for n, st in box:
        m.add(st, musicbox(hz(n) * 0.985, 1.8), 0.3, 0.2)
    m.add(186.6, drone(36.7, 7.0, 1.0, 3.5), 0.35)
    # réverbération globale douce
    ir_len = int(2.6 * SR)
    ir = rng.standard_normal(ir_len) * np.exp(-np.arange(ir_len) / (0.55 * SR))
    ir = lp_fast(ir, 5000)
    ir /= np.sqrt(np.sum(ir ** 2))
    out = []
    for ch in (m.l, m.r):
        n = len(ch) + ir_len
        size = 1 << (n - 1).bit_length()
        wet = np.fft.irfft(np.fft.rfft(ch, size) * np.fft.rfft(ir, size), size)[: len(ch)]
        out.append(ch * 0.8 + wet * 0.35)
    st = np.stack(out, axis=1)
    # silences francs demandés par la feuille de minutage
    for a, z in [(29.0, 30.15), (119.25, 119.4), (150.62, 150.7), (179.8, 182.0)]:
        st[int(a * SR):int(z * SR)] *= 0.04
    st[int(192.0 * SR):] *= np.linspace(1, 0, len(st) - int(192.0 * SR))[:, None]
    st /= max(1e-6, np.max(np.abs(st))) / 0.89
    return st


def write_wav(path, data):
    data = np.clip(data, -1, 1)
    with wave.open(path, "wb") as w:
        channels = 1 if data.ndim == 1 else data.shape[1]
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((data * 32000).astype("<i2").tobytes())


def norm(x, peak=0.9):
    return x / max(1e-6, np.max(np.abs(x))) * peak


def noise(seconds):
    return rng.standard_normal(int(seconds * SR))


def build_sfx():
    s = {}
    t = t_axis(0.7)
    s["sfx_thump"] = norm(sine_sweep(70, 38, 0.7, 3) * np.exp(-t * 7) + lp_fast(noise(0.7), 120) * np.exp(-t * 9) * 0.4)
    t = t_axis(2.6)
    s["sfx_drop"] = norm(sine_sweep(95, 24, 2.6, 1.6) * np.exp(-t * 0.9))
    t = t_axis(2.0)
    creak = bp_fast(noise(2.0), 300, 1400) * (0.5 + 0.5 * np.sin(2 * np.pi * (7 + 9 * t) * t)) ** 3
    groan = np.tanh(saw(60 + 15 * np.sin(2 * np.pi * 0.7 * t), t) * 3) * 0.4
    s["sfx_creak"] = norm((creak * 0.7 + lp_fast(groan, 500)) * env_adsr(len(t), 0.4, 0.2, 1, 0.8))
    t = t_axis(3.6)
    s["sfx_rumble"] = norm(lp_fast(noise(3.6), 110) * env_adsr(len(t), 0.8, 0.5, 1, 1.6) + sine_sweep(45, 32, 3.6) * 0.4 * env_adsr(len(t), 0.5, 0.5, 1, 1.5))
    t = t_axis(1.2)
    s["sfx_splash"] = norm(bp_fast(noise(1.2), 200, 3000) * np.exp(-t * 5) + sine_sweep(90, 40, 1.2) * np.exp(-t * 6) * 0.6)
    t = t_axis(2.6)
    wob = 1 + 0.08 * np.sin(2 * np.pi * 6 * t) + 0.04 * np.sin(2 * np.pi * 17 * t)
    roar = sum(saw(f * wob * (1 - 0.15 * t / 2.6), t) for f in (52, 58, 78, 104)) / 4
    roar = np.tanh(roar * 4) * 0.6 + bp_fast(noise(2.6), 150, 2500) * 0.4
    s["sfx_roar"] = norm(lp_fast(roar, 2200) * env_adsr(len(t), 0.12, 0.3, 0.9, 1.0))
    t = t_axis(1.5)
    shimmer = sum(np.sin(2 * np.pi * f * (1 + 0.4 * t) * t + k) for k, f in enumerate((523, 659, 784, 1046))) / 4
    s["sfx_ignite"] = norm(shimmer * env_adsr(len(t), 0.05, 0.2, 0.8, 0.9) + bp_fast(noise(1.5), 600, 6000) * np.exp(-t * 3) * 0.5)
    t = t_axis(0.65)
    sw = np.zeros(len(t))
    seg = int(SR * 0.05)
    nz = noise(0.65)
    for i in range(0, len(t), seg):
        c = 400 + 4000 * np.sin(np.pi * i / len(t))
        sw[i:i + seg] = bp_fast(nz[i:i + seg], c * 0.6, c)
    s["sfx_whoosh"] = norm(sw * np.sin(np.pi * t / 0.65) ** 2)
    t = t_axis(1.8)
    s["sfx_slam"] = norm(sine_sweep(80, 30, 1.8, 3) * np.exp(-t * 2.2) + lp_fast(noise(1.8), 2500) * np.exp(-t * 6) * 0.8 + hp_fast(noise(1.8), 3000) * np.exp(-t * 25) * 0.4)
    t = t_axis(1.1)
    s["sfx_growl"] = norm(lp_fast(np.tanh(saw(68 * (1 + 0.1 * np.sin(2 * np.pi * 9 * t)), t) * 5), 900) * env_adsr(len(t), 0.06, 0.2, 0.8, 0.5))
    t = t_axis(0.8)
    s["sfx_metal"] = norm(sum(np.sin(2 * np.pi * f * t) * np.exp(-t * d) for f, d in ((523, 4), (1370, 6), (2210, 9), (3310, 12))) + hp_fast(noise(0.8), 2000) * np.exp(-t * 40) * 0.5)
    t = t_axis(1.6)
    s["sfx_gold_hit"] = norm(sine_sweep(120, 40, 1.6, 3) * np.exp(-t * 3) + sum(np.sin(2 * np.pi * f * t) for f in (880, 1320, 1760)) * np.exp(-t * 2.5) * 0.25 + lp_fast(noise(1.6), 5000) * np.exp(-t * 9) * 0.6)
    t = t_axis(2.6)
    laugh_env = np.clip(np.sin(2 * np.pi * 4.6 * t), 0, 1) ** 2 * env_adsr(len(t), 0.1, 0.2, 1, 0.6)
    s["sfx_laugh"] = norm(lp_fast(np.tanh(saw(96 * (1 - 0.1 * t / 2.6), t) * 3) + bp_fast(noise(2.6), 300, 1200) * 0.3, 1200) * laugh_env)
    t = t_axis(0.9)
    s["sfx_spike"] = norm(bp_fast(noise(0.9), 300, 4000) * np.exp(-t * 7) + sine_sweep(60, 220, 0.9, 1.5) * np.exp(-t * 5) * 0.5)
    t = t_axis(3.8)
    tear = np.zeros(len(t))
    for k in range(60):
        st = rng.uniform(0, 3.4)
        ln = rng.uniform(0.02, 0.12)
        i = int(st * SR)
        n = int(ln * SR)
        tear[i:i + n] += hp_fast(noise(ln), 1500) * np.exp(-np.arange(n) / (n * 0.4)) * rng.uniform(0.3, 1)
    swell = riser(3.8, 1.0) * 0.7
    s["sfx_erase"] = norm(tear * 0.8 + swell)
    t = t_axis(1.0)
    s["sfx_chomp"] = norm(sine_sweep(100, 35, 1.0, 3) * np.exp(-t * 4) + bp_fast(noise(1.0), 400, 5000) * np.exp(-t * 14) + hp_fast(noise(1.0), 2500) * np.exp(-t * 30) * 0.6)
    t = t_axis(2.6)
    s["sfx_ring"] = norm(np.sin(2 * np.pi * 3900 * t) * np.linspace(1, 0, len(t)) ** 1.5, 0.5)
    t = t_axis(1.3)
    s["sfx_portal"] = norm(sine_sweep(900, 180, 1.3, 2) * np.exp(-t * 2) * 0.5 + bp_fast(noise(1.3), 300, 3000) * np.sin(np.pi * t / 1.3) ** 2)
    t = t_axis(3.2)
    gong = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * d) for f, d in ((73.4, 0.8), (146.8, 1.0), (221, 1.3), (330, 1.8), (587, 2.6)))
    s["sfx_title"] = norm(hit_big(1.0)[: len(t)] * 0.8 + gong * 0.3)
    t = t_axis(0.28)
    s["sfx_ink_step"] = norm(lp_fast(noise(0.28), 900) * np.exp(-t * 22) + sine_sweep(120, 60, 0.28) * np.exp(-t * 25) * 0.3, 0.6)
    return s


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, data in build_sfx().items():
        write_wav(os.path.join(OUT, name + ".wav"), data)
        print("sfx", name, round(len(data) / SR, 2), "s")
    music = build_music()
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "intro.wav")
        write_wav(wav, music)
        ogg = os.path.join(OUT, "intro_yiero.ogg")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", ogg], check=True)
    print("music", round(len(music) / SR, 2), "s ->", ogg)


if __name__ == "__main__":
    sys.exit(main())
