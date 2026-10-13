"""Rend les musiques de danse : python3 -B tools/dance_music/make.py [noms...] [--out audio/dances] [--png dossier]

Chaque piste est normalisée à -18 LUFS intégrés (pic <= -1 dBFS) et encodée en Ogg Vorbis.
La durée de la boucle est un nombre entier de mesures : un multiple exact de la boucle d'animation.
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from song import bands, ebur128, spectrogram_png  # noqa: E402

import tracks_new  # noqa: E402

try:
    import tracks_old  # noqa: E402
    OLD = tracks_old.SONGS
except ImportError:
    OLD = {}

ALL = dict(tracks_new.SONGS)
ALL.update(OLD)


def main():
    args = sys.argv[1:]
    out = "audio/dances"
    png = None
    names = []
    i = 0
    while i < len(args):
        if args[i] == "--out":
            out = args[i + 1]
            i += 2
        elif args[i] == "--png":
            png = args[i + 1]
            i += 2
        else:
            names.append(args[i])
            i += 1
    if not names or names == ["all"]:
        names = list(ALL.keys())
    for name in names:
        t0 = time.time()
        song = ALL[name]()
        loop = song.render()
        ogg = song.export(out, name)
        os.remove(os.path.join(out, name + ".wav"))
        lufs, peak = ebur128(ogg)
        dur = loop.shape[1] / 44100.0
        print("%-10s %6.1f BPM  %2d mesures  %6.2f s  %6.1f LUFS  pic %5.1f dBFS  (%.0f s de calcul)" % (name, song.bpm, song.bars, dur, lufs, peak, time.time() - t0), flush=True)
        lv = sorted(song.levels.items(), key=lambda kv: -kv[1])
        print("           bus (dB RMS) : " + ", ".join("%s %.1f" % kv for kv in lv))
        print("           bandes sub/basse/médium/haut-médium/aigu (dB rel.) : %s" % bands(loop))
        if png:
            os.makedirs(png, exist_ok=True)
            spectrogram_png(loop, os.path.join(png, name + ".png"))


if __name__ == "__main__":
    main()
