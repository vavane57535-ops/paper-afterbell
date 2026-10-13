"""Nouvelles musiques des 8 danses de la 0.15 (mêmes tempos, mêmes boucles d'animation),
recomposées entièrement : vraie mélodie, basse, batterie, mixage à -18 LUFS."""
import instruments as I
from kit import melody, pads, pattern
from song import Song, chord, n
from tracks_new import BASS, FX, HATS, KEYS, KICK, LEAD, PAD, PERC, SNARE, VOX


# --------------------------------------------------------------------------- Le Floss : électro-pop « future bass », 120 BPM, la mineur
def floss():
    s = Song("floss", 120, 16)
    s.bus("kick", KICK)
    s.bus("clap", SNARE, rev=0.2)
    s.bus("hats", HATS, hp=3500)
    s.bus("bass", BASS, duck=0.5, sat=0.2)
    s.bus("chords", KEYS + 1, duck=0.7, duck_rel=0.22, rev=0.3, hp=200, width=0.5)
    s.bus("pluck", LEAD, rev=0.25, dly=0.2, dly_beats=0.75, hp=300)
    s.bus("vox", VOX, rev=0.35, dly=0.15, dly_beats=0.5)
    s.bus("fx", FX)
    pattern(s, "kick", I.kick("house", 52), "x...x...x...x...", duck=True)
    pattern(s, "clap", I.clap(0.22), "....x.......x...")
    pattern(s, "hats", I.hat(False, 0.03), "x.x.x.x.x.x.x.x.", gain=0.8)
    pattern(s, "hats", I.hat(True, 0.18), "..x...x...x...x.", gain=0.9)
    prog = [("F3", "maj7"), ("G3", ""), ("A3", "m7"), ("E3", "m")]
    roots = [n("F1"), n("G1"), n("A1"), n("E1")]
    for b in range(16):
        r = roots[b % 4]
        s.note("bass", I.bass_saw, r + 12, b * 4, 3.8, cutoff=400, env_amt=1.5, sub=-0.7)
        root, kind = prog[b % 4]
        notes = chord(root, kind) + [n(root[0] + "4")]
        for hit in (0.0, 0.75, 1.5, 2.5, 3.0):
            s.notes("chords", I.supersaw, notes, b * 4 + hit, 0.55, spread=0.6, cutoff=2800, attack=0.005, release=0.12)
    a = "E5 . A5 . G5 E5 . D5 E5 . . . C5 D5 E5 . D5 . G5 . F#5 D5 . B4 D5 . . . G5 . F#5 . E5 . C6 . B5 A5 . E5 G5 . A5 . . . E5 . E5 . B5 . A5 G5 . E5 G5 . . . F#5 . E5 ."
    for i in range(2):
        melody(s, "pluck", I.pluck, a, i * 32, 0.25 * 2, cutoff=700, env_amt=8.0, decay=0.1)
    for b in range(0, 16, 2):
        s.note("vox", I.voice, n("A4"), b * 4 + 3.5, 0.25, 1.0, vowel="a", to_vowel="e", attack=0.005)
        s.note("vox", I.voice, n("C5"), b * 4 + 7.5, 0.25, 1.0, vowel="o", to_vowel="a", attack=0.005)
    s.put("fx", I.riser(s.beats(4.0), 500, 9000), 60)
    return s


# --------------------------------------------------------------------------- Le Dab : hip-hop « trap » cuivré, 100 BPM, sol mineur
def dab():
    s = Song("dab", 100, 16)
    s.bus("kick", KICK)
    s.bus("snare", SNARE, rev=0.15)
    s.bus("hats", HATS + 1, hp=3500)
    s.bus("bass", BASS, sat=0.4)
    s.bus("brass", KEYS + 2, rev=0.22)
    s.bus("keys", PAD + 2, rev=0.35, hp=200)
    s.bus("fx", FX + 3, rev=0.15)
    s.bus("vox", VOX, rev=0.25)
    pattern(s, "kick", I.kick("808", 45, 0.55), "x......x..x.....")
    pattern(s, "snare", I.snare(200, 0.15), "....x.......x...")
    for b in range(16):
        pattern(s, "hats", I.hat(False, 0.03), "x.xxx.x.x3x.xx4x" if b % 4 == 3 else "x.xxx.x.x.xxx.x.", 1, b, seed=b)
    roots = [n("G1"), n("D#1"), n("C2"), n("D2")]
    prog = [("G3", "m"), ("D#3", ""), ("C3", "m"), ("D3", "")]
    for b in range(16):
        r = roots[b % 4]
        s.note("bass", I.bass_808, r, b * 4, 1.6)
        s.put("bass", I.bass_808(r, s.beats(0.9), glide_to=r + 12, glide_time=0.08), b * 4 + 1.75)
        s.note("bass", I.bass_808, r, b * 4 + 2.75, 1.1)
        root, kind = prog[b % 4]
        notes = [x + 12 for x in chord(root, kind)]
        # cuivres sur les dabs (temps 2 et 4 de chaque cycle de 4 temps)
        s.notes("brass", I.brass, notes, b * 4 + 1.0, 0.35, spread=0.5)
        s.notes("brass", I.brass, notes, b * 4 + 3.0, 0.35, spread=0.5)
        s.notes("brass", I.brass, notes, b * 4 + 3.5, 0.2, 0.7, spread=0.5)
        s.notes("keys", I.epiano, chord(root, kind), b * 4, 3.5, spread=0.4)
        s.put("fx", I.scratch(0.22, seed=b), b * 4 + 1.0, 0.8)
    for b in range(0, 16, 2):
        s.note("vox", I.voice, n("D5"), b * 4 + 3.0, 0.3, 1.0, vowel="e", attack=0.005)
    return s


# --------------------------------------------------------------------------- Le Robot : électro 8 bits, 110 BPM, mi mineur
def robot():
    s = Song("robot", 110, 16)
    s.bus("kick", KICK)
    s.bus("snare", SNARE)
    s.bus("hats", HATS + 1)
    s.bus("bass", BASS)
    s.bus("lead", LEAD, dly=0.18, dly_beats=0.75, rev=0.1)
    s.bus("arp", KEYS, rev=0.12)
    s.bus("fx", FX + 2)
    kick = I.kick("house", 55, 0.25)
    pattern(s, "kick", kick, "x...x...x...x...")
    pattern(s, "snare", I.chip_noise(0.12, False), "....x.......x...")
    pattern(s, "hats", I.chip_noise(0.03, True), "x.x.x.x.x.x.x.x.", soft=0.5)
    roots = [n("E2"), n("C2"), n("D2"), n("B1")]
    arps = [[0, 3, 7, 12], [0, 4, 7, 12], [0, 4, 7, 12], [0, 4, 7, 10]]
    for b in range(16):
        r = roots[b % 4]
        for i in range(8):
            s.note("bass", I.chip, r + (12 if i % 2 else 0), b * 4 + i * 0.5, 0.42, duty=0.5)
        for i in range(16):
            s.note("arp", I.chip, r + 24 + arps[b % 4][i % 4], b * 4 + i * 0.25, 0.22, 0.7, duty=0.125)
    a = "E5 - G5 - B5 - A5 G5 E5 - - - D5 E5 G5 - C6 - B5 - G5 - E5 - D5 - - - B4 - D5 - F#5 - A5 - G5 F#5 D5 - - - B4 D5 F#5 - D#5 - F#5 - B5 - - - A5 - F#5 - D#5 - - -"
    for i in range(2):
        melody(s, "lead", I.chip, a, i * 32, 0.5, duty=0.25, vib=0.4)
    # bips du robot à chaque pose (chaque temps)
    for beat in range(64):
        s.put("fx", I.chip(n("E6") + (7 if beat % 2 else 0), s.beats(0.08), duty=0.5) * 0.6, beat)
    return s


# --------------------------------------------------------------------------- Running Man : house au piano, 128 BPM, fa majeur
def shuffle():
    s = Song("shuffle", 128, 16)
    s.bus("kick", KICK)
    s.bus("clap", SNARE, rev=0.18)
    s.bus("hats", HATS, hp=3000)
    s.bus("perc", PERC)
    s.bus("bass", BASS, duck=0.5)
    s.bus("piano", KEYS + 2, duck=0.35, rev=0.22, hp=150)
    s.bus("vox", VOX, rev=0.35)
    s.bus("fx", FX)
    pattern(s, "kick", I.kick("house", 50), "x...x...x...x...", duck=True)
    pattern(s, "clap", I.clap(0.2), "....x.......x...")
    pattern(s, "hats", I.hat(True, 0.16), "..x...x...x...x.")
    pattern(s, "perc", I.shaker(0.05), "xxxxxxxxxxxxxxxx", soft=0.5)
    prog = [("F3", ""), ("D3", "m7"), ("A#2", "maj7"), ("C3", "sus4")]
    roots = [n("F1"), n("D1"), n("A#0"), n("C1")]
    for b in range(16):
        r = roots[b % 4] + 12
        for i, step in enumerate([2, 6, 10, 14]):
            s.note("bass", I.bass_organ, r if i % 2 == 0 else r + 12, b * 4 + step * 0.25, 0.45)
        root, kind = prog[b % 4]
        notes = [x + 12 for x in chord(root, kind)]
        for step in (0, 3, 6, 10, 13):
            s.notes("piano", I.piano, notes, b * 4 + step * 0.25, 0.4, spread=0.5, vel=1.0, bright=1.3)
    for b in range(0, 16, 2):
        s.note("vox", I.voice, n("C5"), b * 4 + 2.0, 1.5, 1.0, vowel="o", to_vowel="a", attack=0.05)
        s.note("vox", I.voice, n("A4"), b * 4 + 6.0, 1.5, 0.9, vowel="a", attack=0.05)
    s.put("fx", I.riser(s.beats(4.0), 400, 8000), 60)
    return s


# --------------------------------------------------------------------------- Le Griddy : trap à la flûte, 140 BPM, do mineur
def griddy():
    s = Song("griddy", 140, 16)
    s.bus("kick", KICK)
    s.bus("clap", SNARE, rev=0.15)
    s.bus("hats", HATS + 2, hp=3500)
    s.bus("bass", BASS, sat=0.4)
    s.bus("flute", LEAD, rev=0.3, dly=0.15, dly_beats=0.75)
    s.bus("pad", PAD, rev=0.5, lp=2500)
    s.bus("fx", FX)
    pattern(s, "kick", I.kick("808", 46, 0.5), "x.....x...x.....")
    pattern(s, "clap", I.clap(0.18), "........x.......")
    for b in range(16):
        pattern(s, "hats", I.hat(False, 0.03), "x.x.x3x.x.x.x4x3" if b % 2 else "x.x.x.x.x.x.x.x.", 1, b, seed=b)
    roots = [n("C2"), n("G#1"), n("F1"), n("G1")]
    for b in range(16):
        r = roots[b % 4]
        s.note("bass", I.bass_808, r, b * 4, 1.4)
        s.put("bass", I.bass_808(r, s.beats(0.7), glide_to=r + 12, glide_time=0.1), b * 4 + 1.5)
        s.note("bass", I.bass_808, r + 12, b * 4 + 2.5, 0.45)
        s.note("bass", I.bass_808, r, b * 4 + 3.0, 0.9)
    pads(s, "pad", I.pad, [("C3", "m"), ("G#2", ""), ("F2", "m"), ("G2", "")], attack=0.3, cutoff=1600)
    a = "G5 - D#5 C5 D#5 - F5 G5 G#5 - G5 F5 D#5 - C5 . C5 - D#5 F5 G5 - F5 D#5 D5 - B4 D5 G4 - - ."
    b2 = "C6 - A#5 G5 G#5 - G5 F5 D#5 - F5 G5 C5 - - . G#5 - G5 F5 D#5 - D5 C5 B4 - D5 F5 G5 - - ."
    for i, phrase in enumerate([a, b2, a, b2]):
        melody(s, "flute", I.flute, phrase, i * 16, 0.5, vibrato=0.8)
    return s


# --------------------------------------------------------------------------- Cheval invisible : électro K-pop, 132 BPM, si mineur
def horse():
    s = Song("horse", 132, 16)
    s.bus("kick", KICK)
    s.bus("clap", SNARE, rev=0.15)
    s.bus("hats", HATS, hp=3500)
    s.bus("bass", BASS, duck=0.5, sat=0.3)
    s.bus("riff", LEAD, rev=0.15, duck=0.3)
    s.bus("vox", VOX, rev=0.25)
    s.bus("fx", FX + 2, rev=0.2)
    pattern(s, "kick", I.kick("house", 52), "x...x...x...x...", duck=True)
    pattern(s, "clap", I.clap(0.2), "....x.......x...")
    pattern(s, "hats", I.hat(False, 0.03), "xxxxxxxxxxxxxxxx", soft=0.5, gain=0.8)
    pattern(s, "hats", I.hat(True, 0.15), "..x...x...x...x.")
    roots = [n("B1"), n("G1"), n("D2"), n("A1")]
    for b in range(16):
        r = roots[b % 4]
        for i in range(8):
            if i % 2 == 1:
                s.note("bass", I.bass_saw, r + 12, b * 4 + i * 0.5, 0.42, cutoff=600, env_amt=3.0, decay=0.08)
    riff = "B4 B4 . B4 . D5 . B4 E5 . D5 . B4 . A4 B4"
    riff2 = "G4 G4 . G4 . B4 . G4 D5 . B4 . A4 . F#4 A4"
    for b in range(16):
        melody(s, "riff", I.lead_saw, riff if b % 2 == 0 else riff2, b * 4, 0.25, cutoff=1800, env_amt=3.0, detune=0.25, release=0.03)
    for cyc in range(8):
        base = cyc * 8
        s.note("vox", I.voice, n("B4"), base + 3.5, 0.3, 1.0, vowel="e", attack=0.005)
        for k in range(4):
            s.put("fx", I.whoosh(s.beats(0.45)), base + 4.0 + k * 0.5, 0.6)
        s.put("fx", I.snare(300, 0.05) * 0.8, base + 6.0)
    return s


# --------------------------------------------------------------------------- Le Hérisson pressé : jeu vidéo 16 bits, 150 BPM, mi majeur
def hedgehog():
    s = Song("hedgehog", 150, 16)
    s.bus("kick", KICK)
    s.bus("snare", SNARE, rev=0.1)
    s.bus("hats", HATS)
    s.bus("bass", BASS)
    s.bus("lead", LEAD, rev=0.18, dly=0.12, dly_beats=0.75)
    s.bus("chords", KEYS - 1, rev=0.15)
    s.bus("perc", PERC)
    s.bus("fx", FX + 2, rev=0.25)
    pattern(s, "kick", I.kick("house", 56, 0.25), "x.....x...x.....")
    pattern(s, "snare", I.snare(230, 0.1), "....x.......x..o")
    pattern(s, "hats", I.hat(False, 0.025), "x.x.x.x.x.x.x.x.", soft=0.5)
    roots = [n("E2"), n("C#2"), n("A1"), n("B1")]
    prog = [("E4", ""), ("C#4", "m"), ("A3", ""), ("B3", "")]
    for b in range(16):
        r = roots[b % 4]
        for i in range(8):
            s.note("bass", I.bass_fm, r + (12 if i in (2, 5) else 0), b * 4 + i * 0.5, 0.42, index=2.5)
        root, kind = prog[b % 4]
        s.notes("chords", I.fm_lead, chord(root, kind), b * 4 + 0.5, 0.3, spread=0.4, ratio=1.0, index=1.2)
        s.notes("chords", I.fm_lead, chord(root, kind), b * 4 + 2.5, 0.3, spread=0.4, ratio=1.0, index=1.2)
    a = "B5 - G#5 E5 F#5 - G#5 B5 C#6 - B5 G#5 E5 - - . A5 - B5 C#6 E6 - D#6 C#6 B5 - - - D6 - E6 ."
    b2 = "E6 - D#6 B5 C#6 - B5 G#5 A5 - G#5 E5 C#5 - - . A5 - G#5 F#5 E5 - F#5 G#5 B5 - - - B5 C#6 D#6 ."
    for i, phrase in enumerate([a, b2, a, b2]):
        melody(s, "lead", I.fm_lead, phrase, i * 16, 0.5, ratio=2.0, index=1.8)
    for cyc in range(8):
        base = cyc * 8
        for t in (0.5, 1.5, 2.5):
            s.put("perc", I.woodblock(1.3), base + t, 0.8, pan=0.3)
        s.put("fx", I.mallet(n("B6"), 0.3, kind="glock"), base + 5.0)
        s.put("fx", I.mallet(n("E7"), 0.5, kind="glock"), base + 5.25)
    return s


# --------------------------------------------------------------------------- Danse macabre : funk fantôme, 100 BPM, do# mineur
def zombie():
    s = Song("zombie", 100, 16)
    s.bus("kick", KICK)
    s.bus("snare", SNARE, rev=0.35)
    s.bus("hats", HATS, hp=3500)
    s.bus("bass", BASS, sat=0.25)
    s.bus("organ", KEYS, rev=0.4, hp=150)
    s.bus("bell", LEAD + 1, rev=0.45, dly=0.2, dly_beats=1.5)
    s.bus("choir", PAD + 1, rev=0.6, hp=150)
    s.bus("fx", FX + 2, rev=0.4)
    pattern(s, "kick", I.kick("boombap", 50), "x.....x.x.......")
    pattern(s, "snare", I.snare(180, 0.2), "....X.......X...")
    pattern(s, "hats", I.hat(False, 0.035), "x.xox.xox.xox.xo")
    roots = [n("C#2"), n("C#2"), n("A1"), n("G#1")]
    riff = [(0, 0.5), (0.75, 0.25), (1.0, 0.5), (1.5, 0.25), (2.0, 0.5), (2.75, 0.25), (3.0, 0.25), (3.5, 0.5)]
    ivs = [0, 12, 10, 7, 0, 3, 5, 7]
    for b in range(16):
        r = roots[b % 4]
        for (t, d), iv in zip(riff, ivs):
            s.note("bass", I.bass_saw, r + iv, b * 4 + t, d, cutoff=500, env_amt=2.5, q=1.5, decay=0.1, sub=0.6)
    pads(s, "organ", I.organ, [("C#3", "m"), ("C#3", "m"), ("A2", ""), ("G#2", "")])
    pads(s, "choir", I.voice, [("C#4", "m"), ("C#4", "m"), ("A3", ""), ("G#3", "")], vowel="o", vibrato=0.4, attack=0.4)
    a = "G#5 - - E5 C#5 - D#5 E5 G#5 - F#5 E5 D#5 - - . C#5 - E5 - A5 - G#5 F#5 G#5 - - - C5 - D#5 ."
    for i in range(4):
        melody(s, "bell", I.mallet, a, i * 16, 0.5, kind="bell")
    for cyc in range(8):
        base = cyc * 8
        s.put("fx", I.slide_whistle(n("C#5"), n("G#5"), s.beats(1.2)) * 0.5, base + 6.0)
    s.note("fx", I.voice, n("C#4"), 28, 3.0, 0.8, vowel="u", to_vowel="o", vibrato=1.0, attack=0.3)
    s.note("fx", I.voice, n("C#4"), 60, 3.0, 0.8, vowel="u", to_vowel="o", vibrato=1.0, attack=0.3)
    return s


SONGS = {"floss": floss, "dab": dab, "robot": robot, "shuffle": shuffle, "griddy": griddy, "horse": horse, "hedgehog": hedgehog, "zombie": zombie}
