"""Aides de composition : motifs de batterie en texte, progressions, lignes de basse."""
import numpy as np

import instruments as I
from song import chord, n


def pattern(song, bus, sig, text, bars=None, start_bar=0, gain=1.0, pan=0.0, duck=False, accent=1.35, soft=0.55, human=0.04, seed=0, every=1):
    """text : une mesure en 16 pas ('x' frappe, 'X' accent, 'o' douce, '.' rien, '3' triolet de 3 sur le pas).
    La mesure peut faire 32 caractères (trente-deuxièmes)."""
    bars = song.bars if bars is None else bars
    steps = len(text.replace(" ", ""))
    t = text.replace(" ", "")
    step = 4.0 / steps
    rng = np.random.default_rng(seed)
    for b in range(start_bar, start_bar + bars, every):
        for i, ch in enumerate(t):
            if ch == ".":
                continue
            g = gain * (accent if ch == "X" else soft if ch == "o" else 1.0) * (1 + rng.uniform(-human, human))
            beat = b * 4 + i * step
            if ch == "3":
                for k in range(3):
                    song.put(bus, sig, beat + k * step / 3.0, g * (0.7 + 0.15 * k), pan)
                continue
            if ch == "4":
                for k in range(4):
                    song.put(bus, sig, beat + k * step / 4.0, g * (0.6 + 0.12 * k), pan)
                continue
            song.put(bus, sig, beat, g, pan)
            if duck:
                song.duck_hits.append(beat)


def pads(song, bus, fn, prog, bar_len=1, start_bar=0, bars=None, gain=1.0, octave_shift=0, spread=0.6, **kw):
    """prog : liste de (racine, type) une par mesure (ou par bar_len mesures)."""
    bars = song.bars if bars is None else bars
    k = 0
    for b in range(start_bar, start_bar + bars, bar_len):
        root, kind = prog[k % len(prog)]
        notes = [x + 12 * octave_shift for x in chord(root, kind)]
        song.notes(bus, fn, notes, b * 4, bar_len * 4, gain, spread, **kw)
        k += 1


def melody(song, bus, fn, notes_text, start_beat=0.0, step=0.5, gain=1.0, pan=0.0, transpose=0, legato=0.92, **kw):
    """notes_text : 'A4 . C5 - - E5 r ...' ; '.' ou 'r' = silence, '-' prolonge la note précédente."""
    tokens = notes_text.split()
    events = []
    for tok in tokens:
        if tok == "-" and events and events[-1][0] is not None:
            events[-1][1] += 1
        elif tok in (".", "r", "-"):
            events.append([None, 1])
        else:
            events.append([n(tok) + transpose, 1])
    t = start_beat
    for pitch, length in events:
        if pitch is not None:
            song.note(bus, fn, pitch, t, length * step * legato, gain, pan, **kw)
        t += length * step
    return t
