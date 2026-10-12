"""Musiques des 10 danses 0.16 (tendances TikTok 2025-2026). Compositions originales :
seuls le genre, le tempo et l'énergie s'inspirent des tendances, aucune mélodie n'est reprise.
Une boucle = 16 mesures ; les accents tombent sur les gestes clés de la chorégraphie
(cycle d'animation de 16 temps = 4 mesures, sauf le funk : 8 temps)."""
import instruments as I
from kit import melody, pads, pattern
from song import Song, chord, n

# niveaux cibles (dB RMS actif) communs
KICK, SNARE, HATS, PERC, BASS, LEAD, KEYS, PAD, VOX, FX = -11, -14, -22, -21, -10.5, -14, -17, -21, -16, -22


# --------------------------------------------------------------------------- 6-7 : drill de Philadelphie, 144 BPM, fa# mineur
def sixseven():
    s = Song("sixseven", 144, 16)
    s.bus("kick", KICK, hp=30)
    s.bus("snare", SNARE + 1, rev=0.12)
    s.bus("hats", HATS + 2, rev=0.04, hp=3000)
    s.bus("bass", BASS + 1, sat=0.4)
    s.bus("bell", LEAD, rev=0.32, dly=0.18, dly_beats=0.75, hp=300)
    s.bus("piano", KEYS - 2, rev=0.3, hp=150)
    s.bus("pad", PAD, rev=0.55, lp=3200, hp=180)
    s.bus("vox", VOX, rev=0.35, dly=0.15, hp=250)
    s.bus("fx", FX)
    kick = I.kick("808", tune=46, decay=0.5)
    sn = I.snare(210, 0.14)
    hat = I.hat(False, 0.035)
    for b in range(16):
        pattern(s, "hats", hat, "x..x..x.x..x4.3." if b % 4 == 3 else "x..x..x.x..x..x.", 1, b, seed=b)
        pattern(s, "snare", sn, "........X.....o." if b % 2 else "........X.......", 1, b)
        if b >= 4 or b % 4 == 0:
            pattern(s, "kick", kick, "x......x..x....." if b % 2 == 0 else "x.....x.......x.", 1, b)
    roots = [n("F#1"), n("D2"), n("B1"), n("C#2")]
    for b in range(16):
        r = roots[b % 4]
        if b == 15:
            s.note("bass", I.bass_808, r, b * 4, 2.0)
            continue
        nxt = roots[(b + 1) % 4]
        s.note("bass", I.bass_808, r, b * 4, 1.6)
        s.note("bass", I.bass_808, r, b * 4 + 1.75, 0.5)
        s.put("bass", I.bass_808(r + (4 if b % 4 == 3 else 3), s.beats(1.0), glide_to=nxt, glide_time=0.12), b * 4 + 2.5)
        s.note("bass", I.bass_808, r + 7, b * 4 + 3.5, 0.45)
    prog = [("F#3", "m"), ("D3", ""), ("B2", "m"), ("C#3", "")]
    pads(s, "pad", I.voice, prog, vowel="o", vibrato=0.1, attack=0.25, release=0.5)
    a = "C#5 - A4 C#5 F#5 - E5 C#5 D5 - C#5 A4 F#4 - A4 . B4 - D5 F#5 E5 - D5 C#5 C#5 - F5 G#5 F5 - C#5 ."
    b2 = "F#5 - E5 C#5 A4 - C#5 E5 F#5 - A5 - G#5 F#5 E5 . D5 - F#5 A5 G#5 - F#5 E5 F5 - G#5 C#6 G#5 - F5 ."
    for k, phrase in enumerate([a, a, b2, a]):
        melody(s, "bell", I.mallet, phrase, k * 16, 0.5, pan=-0.15, kind="bell")
        if k >= 1:
            melody(s, "piano", I.piano, phrase, k * 16, 0.5, pan=0.2, transpose=-12, bright=0.6)
    for cyc in range(4):
        base = cyc * 16
        s.note("vox", I.voice, n("F#4"), base + 12, 0.45, 0.9, pan=-0.2, vowel="i", to_vowel="e")
        s.note("vox", I.voice, n("A4"), base + 13, 0.6, 1.0, pan=0.2, vowel="e", to_vowel="a")
    s.put("fx", I.riser(s.beats(2.0), 400, 5000), 62)
    return s


# --------------------------------------------------------------------------- Pikki Pikki : remix « DJ » indonésien, 130 BPM, si bémol majeur
def pikki():
    s = Song("pikki", 130, 16)
    s.bus("kick", KICK)
    s.bus("clap", SNARE, rev=0.15)
    s.bus("hats", HATS, hp=2500)
    s.bus("perc", PERC, rev=0.1)
    s.bus("bass", BASS, duck=0.5, sat=0.3)
    s.bus("lead", LEAD, rev=0.2, dly=0.22, dly_beats=0.75, hp=250)
    s.bus("chords", KEYS - 1, duck=0.6, rev=0.25, hp=200)
    s.bus("vox", VOX, rev=0.3)
    s.bus("fx", FX + 2, rev=0.3)
    k = I.kick("house", 52)
    pattern(s, "kick", k, "x...x...x...x...", duck=True)
    pattern(s, "clap", I.clap(0.2), "....x.......x...")
    for b in range(3, 16, 4):
        pattern(s, "clap", I.snare(230, 0.09), "........x.x.4444", 1, b, gain=0.55)
    pattern(s, "hats", I.hat(True, 0.18), "..x...x...x...x.")
    pattern(s, "hats", I.hat(False, 0.03, seed=9), "x.xxx.xxx.xxx.xx", soft=0.5, gain=0.6)
    pattern(s, "perc", I.woodblock(1.0), "x..x..x...x..x..", gain=0.8, pan=0.3)
    pattern(s, "perc", I.woodblock(1.35), "......x.......x.", gain=0.6, pan=-0.3)
    prog = [("A#", ""), ("F", ""), ("G", "m"), ("D#", "")]
    roots = [n("A#1"), n("F1"), n("G1"), n("D#1")]
    for b in range(16):
        r = roots[b % 4]
        for i in range(8):
            if i % 2 == 1:
                s.note("bass", I.bass_saw, r + (12 if i in (3, 7) else 0), b * 4 + i * 0.5, 0.42, cutoff=380, env_amt=6.0, decay=0.08, q=2.0, sub=0.6)
        s.notes("chords", I.pluck, [x + 12 for x in chord(["A#3", "F3", "G3", "D#3"][b % 4], ["", "", "m", ""][b % 4])], b * 4 + 0.5, 0.4, gain=1.0, spread=0.5, cutoff=900, env_amt=4.0)
        s.notes("chords", I.pluck, [x + 12 for x in chord(["A#3", "F3", "G3", "D#3"][b % 4], ["", "", "m", ""][b % 4])], b * 4 + 2.5, 0.4, gain=1.0, spread=0.5, cutoff=900, env_amt=4.0)
    a = "F5 - D5 F5 G5 F5 D5 C5 C5 - A4 C5 D5 C5 A4 F4 G4 A#4 D5 - G5 F5 D5 A#4 C5 - A#4 G4 A#4 - C5 ."
    b2 = "D5 F5 A#5 - A5 G5 F5 D5 C5 F5 A5 - G5 F5 C5 A4 A#4 D5 G5 - F5 D5 A#4 G4 D#5 - D5 - C5 - A#4 ."
    for i, phrase in enumerate([a, b2, a, b2]):
        melody(s, "lead", I.lead_square, phrase, i * 16, 0.5, pw=0.3, cutoff=4200, vibrato=0.4)
    for cyc in range(4):
        base = cyc * 16
        s.note("vox", I.voice, n("A#4"), base + 1.75, 0.3, 1.0, vowel="e", attack=0.01)
        s.note("vox", I.voice, n("D5"), base + 6.0, 0.25, 0.8, vowel="a", attack=0.01)
        s.put("fx", I.laser(0.35, 1800, 300), base + 11.0)
        s.put("fx", I.laser(0.35, 1400, 200), base + 12.0)
    s.put("fx", I.siren(s.beats(4.0), 700, 3.0) * 0.6, 60)
    return s


# --------------------------------------------------------------------------- Anxiety : hip-hop indé à demi-tempo, 129 BPM, ré mineur
def anxiety():
    s = Song("anxiety", 129, 16, swing=0.02)
    s.bus("kick", KICK)
    s.bus("snare", SNARE, rev=0.18)
    s.bus("hats", HATS - 1, hp=3500)
    s.bus("bass", BASS)
    s.bus("xylo", LEAD + 1, rev=0.22, dly=0.12, dly_beats=1.5, hp=250)
    s.bus("pad", PAD, rev=0.6, lp=2600)
    s.bus("vox", VOX, rev=0.35)
    s.bus("fx", FX)
    pattern(s, "kick", I.kick("boombap", 48), "x.....x...x.....")
    pattern(s, "snare", I.snare(185, 0.17), "........X......o")
    pattern(s, "hats", I.hat(False, 0.04), "x.x.x.x.x.x.xox.", seed=3)
    pattern(s, "hats", I.hat(True, 0.2), "..............x.", 4, 4, gain=0.7)
    roots = [n("D2"), n("C2"), n("A#1"), n("C2")]
    for b in range(16):
        r = roots[b % 4]
        s.note("bass", I.bass_saw, r, b * 4, 1.4, cutoff=220, env_amt=1.0, decay=0.2, sub=0.8)
        s.note("bass", I.bass_saw, r, b * 4 + 1.5, 0.4, cutoff=220, env_amt=1.0, sub=0.8)
        s.note("bass", I.bass_saw, r + 7 if b % 2 else r + 12, b * 4 + 2.5, 1.2, cutoff=220, env_amt=1.0, sub=0.8)
    prog = [("D3", "m"), ("C3", ""), ("A#2", ""), ("C3", "")]
    pads(s, "pad", I.pad, prog, attack=0.3, release=0.6, cutoff=1500)
    riff = "D5 A4 F5 A4 E5 A4 D5 A4 C5 G4 E5 G4 D5 G4 C5 G4 A#4 F4 D5 F4 C5 F4 A#4 F4 C5 G4 E5 G4 F5 E5 D5 C5"
    for i in range(4):
        melody(s, "xylo", I.mallet, riff, i * 16, 0.5, kind="xylo")
    # Les 4 premières mesures sonnent « dans le casque » (étouffées), puis tout s'ouvre.
    s.master_lp = [(0, 15.5, 900.0, 1400.0), (15.5, 16.0, 1400.0, 18000.0)]
    s.put("fx", I.whoosh(s.beats(1.0)), 15.0)
    s.put("fx", I.crash(1.4) * 0.6, 16.0)
    for cyc in range(1, 4):
        base = cyc * 16
        s.note("vox", I.voice, n("A4"), base + 12, 0.35, 1.0, vowel="e", to_vowel="i")
        s.note("vox", I.voice, n("D5"), base + 13, 0.35, 1.0, vowel="o")
    return s


# --------------------------------------------------------------------------- Dame un Grrr : dance-pop balkanique, 126 BPM, la mineur harmonique
def grrr():
    s = Song("grrr", 126, 16)
    s.bus("kick", KICK)
    s.bus("clap", SNARE, rev=0.15)
    s.bus("hats", HATS, hp=3000)
    s.bus("perc", PERC)
    s.bus("bass", BASS, duck=0.55, sat=0.2)
    s.bus("acc", LEAD, rev=0.22, dly=0.12, dly_beats=0.75, hp=200)
    s.bus("chords", KEYS - 2, duck=0.6, rev=0.3, hp=250)
    s.bus("growl", VOX + 1, rev=0.15)
    s.bus("fx", FX)
    pattern(s, "kick", I.kick("house", 50), "x...x...x...x...", duck=True)
    pattern(s, "clap", I.clap(0.2), "....x.......x...")
    pattern(s, "hats", I.hat(True, 0.16), "..x...x...x...x.")
    pattern(s, "perc", I.shaker(0.05), "xxxxxxxxxxxxxxxx", soft=0.5, gain=0.7)
    pattern(s, "perc", I.tom(57, 0.15), "...x.....x....x.", gain=0.5, pan=0.2)
    roots = [n("A1"), n("F1"), n("C2"), n("E1")]
    for b in range(16):
        r = roots[b % 4]
        for i in range(8):
            if i % 2 == 1:
                s.note("bass", I.bass_saw, r + 12, b * 4 + i * 0.5, 0.4, cutoff=500, env_amt=3.0, decay=0.08, sub=0.7)
        s.notes("chords", I.supersaw, chord(["A3", "F3", "C4", "E3"][b % 4], ["m", "", "", ""][b % 4]), b * 4, 4.0, cutoff=2200, attack=0.01, release=0.2)
    a = "A4 - C5 E5 - D5 C5 B4 A4 - F4 A4 C5 - B4 A4 G4 - C5 E5 G5 - F5 E5 G#4 - B4 E5 D5 - C5 B4"
    b2 = "E5 - A5 G#5 A5 - E5 C5 F5 - E5 D5 C5 - A4 F4 E5 - G5 F5 E5 - D5 C5 B4 - G#4 B4 E5 - - ."
    for i, phrase in enumerate([a, b2, a, b2]):
        melody(s, "acc", I.accordion, phrase, i * 16, 0.5)
    for cyc in range(4):
        base = cyc * 16
        s.note("growl", I.growl, n("A2"), base + 0, 0.9)
        s.note("growl", I.growl, n("E2"), base + 2, 0.9)
        s.note("growl", I.growl, n("A2"), base + 7, 1.2, rate=11.0)
        s.put("fx", I.whoosh(s.beats(1.0)), base + 12.5)
        s.put("fx", I.impact() * 0.7, base + 14)
    return s


# --------------------------------------------------------------------------- Poulet-Banane : électro-house rigolote, 128 BPM, sol majeur
def chicken():
    s = Song("chicken", 128, 16)
    s.bus("kick", KICK)
    s.bus("clap", SNARE, rev=0.12)
    s.bus("hats", HATS, hp=3000)
    s.bus("perc", PERC, rev=0.08)
    s.bus("bass", BASS, duck=0.5, sat=0.3)
    s.bus("xylo", LEAD, rev=0.18, dly=0.1, dly_beats=0.75)
    s.bus("vox", VOX, rev=0.22)
    s.bus("fx", FX + 2, rev=0.2)
    pattern(s, "kick", I.kick("house", 54), "x...x...x...x...", duck=True)
    pattern(s, "clap", I.clap(0.18), "....x.......x...")
    pattern(s, "hats", I.hat(True, 0.15), "..x...x...x...x.")
    pattern(s, "hats", I.hat(False, 0.03), "x.x.x.x.x.x.x.x.", soft=0.5, gain=0.5)
    roots = [n("G1"), n("C2"), n("D2"), n("G1")]
    for cyc in range(4):
        base = cyc * 16
        for half in (0, 8):
            # poulet : basse sautillante, gloussements, cloche
            for i in range(8):
                r = roots[(half // 4 + i // 4) % 4]
                s.note("bass", I.bass_slap, r + (12 if i % 2 else 0), base + half + i * 0.5, 0.35)
                if i % 2 == 1:
                    s.put("perc", I.cluck(seed=cyc * 10 + i), base + half + i * 0.5, 1.0, pan=0.3 if i % 4 == 1 else -0.3)
            for i in (0, 3, 6):
                s.put("perc", I.cowbell(1.0, 0.12), base + half + i * 0.25, 0.6)
            s.note("vox", I.voice, n("G5"), base + half + 2.0, 0.22, 0.9, vowel="i", attack=0.005)
            s.note("vox", I.voice, n("E5"), base + half + 2.5, 0.3, 0.9, vowel="e", attack=0.005)
            # banane : xylophone et « ba-na-na »
            banana = "D5 G5 B5 G5 D5 B4 G4 B4" if half == 0 else "E5 A5 C6 B5 A5 G5 F#5 D5"
            melody(s, "xylo", I.mallet, banana, base + half + 4, 0.5, kind="xylo")
            for j, p in enumerate(["B4", "D5", "G5"]):
                s.note("vox", I.voice, n(p), base + half + 4 + j * 0.5, 0.3, 0.9, vowel="a", attack=0.008)
            for i in range(8):
                r = roots[(2 + i // 4) % 4]
                s.note("bass", I.bass_saw, r, base + half + 4 + i * 0.5, 0.4, cutoff=500, env_amt=3.0, decay=0.1, sub=0.6)
        s.put("fx", I.slide_whistle(n("G4"), n("G6"), s.beats(0.9)), base + 3.1)
        s.put("fx", I.slide_whistle(n("D6"), n("G4"), s.beats(1.6)), base + 12.5)
        s.put("fx", I.whoosh(s.beats(0.75)), base + 14.25)
    return s


# --------------------------------------------------------------------------- Golden : hymne K-pop « chasseuses de démons », 123 BPM, do# mineur / mi majeur
def golden():
    s = Song("golden", 123, 16)
    s.bus("kick", KICK)
    s.bus("snare", SNARE, rev=0.22)
    s.bus("hats", HATS, hp=3500)
    s.bus("perc", PERC + 2, rev=0.25)
    s.bus("bass", BASS, duck=0.45, sat=0.2)
    s.bus("chords", KEYS, duck=0.55, rev=0.3, hp=180, width=0.4)
    s.bus("arp", PAD + 1, rev=0.3, dly=0.2, dly_beats=0.75, hp=600)
    s.bus("lead", LEAD + 1, rev=0.3, dly=0.15, dly_beats=0.5)
    s.bus("brass", KEYS, rev=0.25)
    s.bus("fx", FX + 2, rev=0.3)
    pattern(s, "kick", I.kick("house", 50), "x...x...x...x...", duck=True)
    pattern(s, "snare", I.snare(200, 0.18), "....x.......x...")
    pattern(s, "snare", I.clap(0.2), "....x.......x...", gain=0.7)
    pattern(s, "hats", I.hat(False, 0.04), "x.xxx.xxx.xxx.xx", soft=0.5)
    pattern(s, "hats", I.hat(True, 0.2), "..x...x...x...x.", gain=0.8)
    prog = [("C#3", "m"), ("A2", ""), ("E3", ""), ("B2", "")]
    roots = [n("C#2"), n("A1"), n("E2"), n("B1")]
    for b in range(16):
        r = roots[b % 4]
        for i in range(8):
            s.note("bass", I.bass_saw, r if i % 2 == 0 else r + 12, b * 4 + i * 0.5, 0.45, cutoff=600, env_amt=2.0, sub=0.7)
        root, kind = prog[b % 4]
        notes = chord(root, kind)
        s.notes("chords", I.supersaw, [x + 12 for x in notes] + [notes[0] + 24], b * 4, 4.0, cutoff=3000, attack=0.02)
        arp = [notes[0] + 24, notes[1] + 24, notes[2] + 24, notes[0] + 36]
        for i in range(16):
            s.note("arp", I.mallet, arp[i % 4], b * 4 + i * 0.25, 0.2, 0.8 if i % 4 == 0 else 0.55, pan=(-0.3 if i % 2 else 0.3), kind="glock")
    a = "G#4 - B4 C#5 - E5 - D#5 C#5 - - B4 A4 - B4 C#5 B4 - G#4 - E5 - F#5 G#5 F#5 - - E5 D#5 - B4 -"
    b2 = "C#6 - B5 G#5 - E5 - G#5 A5 - G#5 E5 - C#5 - E5 G#5 - - F#5 E5 - B4 E5 D#5 - E5 F#5 - - B4 -"
    for i, phrase in enumerate([a, b2, a, b2]):
        melody(s, "lead", I.lead_saw, phrase, i * 16, 0.5, cutoff=2600, vibrato=0.6, detune=0.15)
    for cyc in range(4):
        base = cyc * 16
        s.put("fx", I.whoosh(s.beats(1.0)), base + 0.0)
        s.put("perc", I.taiko(0.7), base + 0.0, 1.0)
        s.put("perc", I.taiko(0.5), base + 4.0, 0.9, pan=-0.2)
        s.put("perc", I.taiko(0.5), base + 5.0, 0.9, pan=0.2)
        s.notes("brass", I.brass, chord("C#4", "m"), base + 2.0, 0.4, spread=0.4)
        s.notes("brass", I.brass, chord("C#4", "m"), base + 3.0, 0.4, spread=0.4)
        s.put("fx", I.riser(s.beats(1.0), 1000, 9000) * 0.7, base + 6.0)
        s.put("fx", I.crash(1.8) * 0.8, base + 7.0)
    return s


# --------------------------------------------------------------------------- Passinho : funk brésilien « montagem » à la cloche, 130 BPM, mi mineur
def funk():
    s = Song("funk", 130, 16)
    s.bus("kick", KICK + 0.5)
    s.bus("snare", SNARE, rev=0.12)
    s.bus("hats", HATS, hp=3000)
    s.bus("perc", PERC)
    s.bus("bass", BASS + 0.5, sat=0.5)
    s.bus("bell", LEAD, rev=0.15, dly=0.12, dly_beats=0.75)
    s.bus("vox", VOX, rev=0.25)
    s.bus("fx", FX)
    pattern(s, "kick", I.kick("808", 44, 0.35), "x..x..x...x..x..")
    pattern(s, "snare", I.clap(0.16, tight=True), "....x..x....x...")
    pattern(s, "snare", I.snare(240, 0.08), "..........x....x", gain=0.5)
    pattern(s, "hats", I.hat(False, 0.03), "xxxxxxxxxxxxxxxx", soft=0.45, gain=0.7)
    pattern(s, "perc", I.tom(50, 0.12), ".x....x.....x..x", gain=0.6, pan=0.25)
    pattern(s, "perc", I.tom(57, 0.1), "...x.....x......", gain=0.5, pan=-0.25)
    roots = [n("E1"), n("E1"), n("C2"), n("D2")]
    for b in range(16):
        r = roots[b % 4]
        for step in (0, 3, 6, 10, 13):
            s.note("bass", I.bass_808, r, b * 4 + step * 0.25, 0.6, decay=0.35, drive=2.2)
    riff_a = "E5 . G5 E5 . B5 . A5 G5 . E5 . D5 E5 . . E5 . G5 E5 . C6 . B5 A5 . G5 . F#5 G5 . ."
    riff_b = "C6 . B5 G5 . E5 . G5 A5 . G5 . E5 D5 . . D5 . E5 F#5 . A5 . G5 F#5 . D5 . E5 . . ."
    for i in range(8):
        melody(s, "bell", I.cowbell_note, riff_a if i % 2 == 0 else riff_b, i * 8, 0.25, legato=1.0)
    for b in range(0, 16, 2):
        s.note("vox", I.voice, n("E4"), b * 4 + 0.5, 0.25, 1.0, vowel="a", attack=0.005)
        s.note("vox", I.voice, n("G4"), b * 4 + 6.5, 0.4, 1.0, vowel="o", attack=0.005)
    for b in range(1, 16, 2):
        s.put("fx", I.whoosh(s.beats(0.5)), b * 4 + 2.0)
    return s


# --------------------------------------------------------------------------- Amapiano : log drum et piano jazzy, 113 BPM, fa mineur
def amapiano():
    s = Song("amapiano", 113, 16, swing=0.035)
    s.bus("kick", KICK - 1.5)
    s.bus("rim", PERC + 1, rev=0.15)
    s.bus("shaker", HATS - 2, hp=4000, lp=12000)  # relecture : shaker moins sifflant (aigus > présence de 6 dB)
    s.bus("log", BASS + 0.5, sat=0.1)
    s.bus("keys", KEYS + 1, rev=0.3, hp=150)
    s.bus("pad", PAD, rev=0.6, lp=2500)
    s.bus("flute", LEAD + 1, rev=0.35, dly=0.2, dly_beats=0.75)
    s.bus("fx", FX)
    pattern(s, "kick", I.kick("house", 48, 0.4), "x.......x.......")
    pattern(s, "rim", I.rim(), "....x..x....x...", pan=0.15)
    pattern(s, "rim", I.clap(0.15, tight=True), "....x.......x...", gain=0.5)
    pattern(s, "shaker", I.shaker(0.05), "xxxxxxxxxxxxxxxx", soft=0.55)
    pattern(s, "shaker", I.hat(True, 0.15), "..x...x...x...x.", gain=0.6)
    chords = [("F3", "m9"), ("A#2", "m9"), ("D#3", "9"), ("G#2", "maj9")]
    roots = [n("F2"), n("A#1"), n("D#2"), n("G#1")]
    log_steps = [(0, 0), (3, 7), (6, 12), (10, 0), (12, 10), (14, 7)]
    for b in range(16):
        r = roots[b % 4] + 12
        for step, iv in log_steps:
            s.note("log", I.log_drum, r + iv - 12, b * 4 + step * 0.25, 0.4)
        if b % 4 == 3:
            for step in (13, 15):
                s.note("log", I.log_drum, r + 12, b * 4 + step * 0.25, 0.3)
        root, kind = chords[b % 4]
        notes = chord(root, kind)
        for hit in (0.0, 1.5, 3.0):
            s.notes("keys", I.epiano, notes, b * 4 + hit, 1.2 if hit < 3 else 0.9, spread=0.5, strum=0.012, vel=0.9)
    pads(s, "pad", I.pad, chords, attack=0.6, release=0.8, cutoff=1200)
    a = "C5 - - G#4 - F4 - - A#4 - C5 C#5 - C5 - - D#5 - - C#5 C5 - A#4 - G#4 - - - G4 - G#4 -"
    b2 = "F5 - - D#5 - C5 - - C#5 - C5 A#4 - C5 - - G5 - - F5 D#5 - C#5 - C5 - - - A#4 - C5 -"
    for i, phrase in enumerate([a, b2, a, b2]):
        melody(s, "flute", I.flute, phrase, i * 16, 0.5)
    for cyc in range(4):
        s.put("fx", I.whoosh(s.beats(2.0), up=False), cyc * 16 + 12)
    return s


# --------------------------------------------------------------------------- Retour en 2016 : trap-pop 2016, 140 BPM, do majeur (gel du Mannequin Challenge)
def retro():
    s = Song("retro", 140, 16)
    s.bus("kick", KICK)
    s.bus("clap", SNARE, rev=0.18)
    s.bus("hats", HATS + 1, hp=3500)
    s.bus("bass", BASS, sat=0.35)
    s.bus("lead", LEAD, rev=0.2, dly=0.18, dly_beats=0.75)
    s.bus("steel", KEYS, rev=0.25, hp=300)
    s.bus("fx", FX + 3, rev=0.2)
    kick = I.kick("808", 48, 0.45)
    clap = I.clap(0.2)
    hat = I.hat(False, 0.035)
    snp = I.snap()
    roots = [n("C2"), n("A1"), n("F1"), n("G1")]
    lead_a = "E5 G5 E5 C5 - G4 C5 E5 A5 G5 E5 C5 - E5 D5 C5"
    lead_b = "F5 A5 F5 C5 - A4 C5 F5 G5 - F5 E5 D5 - B4 D5"
    for cyc in range(4):
        base = cyc * 16
        for bar in range(4):
            b = cyc * 4 + bar
            freeze = bar == 3
            if not freeze:
                pattern(s, "kick", kick, "x......x..x.....", 1, b)
                pattern(s, "clap", clap, "........x.......", 1, b)
                pattern(s, "clap", snp, "....x.......x...", 1, b, gain=0.6)
                pattern(s, "hats", hat, "x.x.x.x.x.x.x3x." if bar == 2 else "x.x.x.x.x.x.x.x.", 1, b, seed=b)
                r = roots[bar]
                s.note("bass", I.bass_808, r, b * 4, 1.7)
                s.put("bass", I.bass_808(r, s.beats(1.2), glide_to=r + 12, glide_time=0.1), b * 4 + 2.5)
                melody(s, "lead", I.lead_saw, lead_a if bar % 2 == 0 else lead_b, b * 4, 0.25, cutoff=3500, detune=0.2)
                s.notes("steel", I.mallet, [x + 12 for x in chord(["C4", "A3", "F3", "G3"][bar], ["", "m", "", ""][bar])], b * 4 + 0.75, 0.3, kind="marimba", strum=0.01)
                s.notes("steel", I.mallet, [x + 12 for x in chord(["C4", "A3", "F3", "G3"][bar], ["", "m", "", ""][bar])], b * 4 + 2.75, 0.3, kind="marimba", strum=0.01)
            else:
                # Mannequin Challenge : tout s'arrête au temps 12, tic-tac, et ça repart à 14,5.
                s.put("fx", I.tape_stop([n("C4"), n("E4"), n("G4"), n("C3")], s.beats(1.0)), b * 4)
                for t in (0.5, 1.0, 1.5, 2.0):
                    s.put("fx", I.woodblock(1.6 if t % 1.0 == 0 else 1.25) * 0.7, b * 4 + t)
                s.put("fx", I.riser(s.beats(0.5), 600, 8000), b * 4 + 2.0)
                s.put("kick", kick, b * 4 + 2.5)
                s.put("clap", clap, b * 4 + 3.0)
                pattern(s, "hats", hat, "..........x.x3x.", 1, b)
                s.note("bass", I.bass_808, roots[3], b * 4 + 2.5, 1.4)
                melody(s, "lead", I.lead_saw, "G4 B4 D5 G5", b * 4 + 3.0, 0.25, cutoff=3500)
    return s


# --------------------------------------------------------------------------- Pretty Little Baby : doo-wop 1962, 120 BPM en ternaire, do majeur
def baby():
    s = Song("baby", 120, 16, swing=1.0 / 6.0, swing_unit=0.5)
    s.bus("kick", KICK - 4)
    # relecture : balais plus doux (souffle filtré) et contrebasse ronde, sans grésillement aigu
    s.bus("brush", SNARE - 8, rev=0.2, hp=400, lp=5000)
    s.bus("snap", PERC + 3, rev=0.25)
    s.bus("bass", BASS - 1, lp=1100)
    s.bus("piano", KEYS, rev=0.3, hp=120)
    s.bus("celesta", LEAD, rev=0.35, dly=0.1, dly_beats=1.0)
    s.bus("choir", PAD + 2, rev=0.55, hp=200)
    s.bus("vinyl", -34, hp=800)
    pattern(s, "kick", I.kick("boombap", 52, 0.3), "x.......x.......", gain=0.8)
    brush = I.hat(False, 0.12, metal=False)
    pattern(s, "brush", brush, "....x.......x...")
    pattern(s, "brush", I.shaker(0.09), "x.x.x.x.x.x.x.x.", soft=0.4, gain=0.5)
    pattern(s, "snap", I.snap(), "....x.......x...")
    walk = [["C2", "E2", "G2", "A2"], ["A1", "C2", "E2", "G2"], ["F1", "A1", "C2", "D2"], ["G1", "B1", "D2", "F2"]]
    prog = [("C4", ""), ("A3", "m"), ("F3", ""), ("G3", "7")]
    for b in range(16):
        for i, p in enumerate(walk[b % 4]):
            s.note("bass", I.bass_upright, n(p), b * 4 + i, 0.9)
        root, kind = prog[b % 4]
        notes = chord(root, kind)
        for beat in range(4):
            for k in range(3):
                s.notes("piano", I.piano, notes, b * 4 + beat + k / 3.0, 0.3, 0.75 if k == 0 else 0.5, spread=0.3, vel=0.7)
    pads(s, "choir", I.voice, [("C4", ""), ("A3", "m"), ("F3", ""), ("G3", "")], vowel="u", vibrato=0.3, attack=0.35, release=0.6)
    a = "E5 - G5 - E5 D5 C5 - C5 - E5 - A5 - - - A5 - G5 F5 E5 - D5 C5 D5 - - - B4 - - -"
    b2 = "E5 - G5 - C6 - B5 A5 G5 - E5 - C5 - - - F5 - A5 - G5 F5 E5 D5 C5 - - - - - . ."
    for i, phrase in enumerate([a, b2, a, b2]):
        melody(s, "celesta", I.mallet, phrase, i * 16, 0.5, kind="celesta")
    s.put("vinyl", I.vinyl(s.beats(64) + 1.0), 0)
    return s


SONGS = {"sixseven": sixseven, "pikki": pikki, "anxiety": anxiety, "grrr": grrr, "chicken": chicken, "golden": golden, "funk": funk, "amapiano": amapiano, "retro": retro, "baby": baby}
