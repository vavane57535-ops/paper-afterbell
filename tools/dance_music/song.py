"""Cadre de composition : grille en temps musicaux, bus de mixage, rendu en boucle parfaite."""
import os
import re
import subprocess
import tempfile
import wave

import numpy as np

import dsp
from dsp import SR

NOTE = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}

CHORDS = {
    "": [0, 4, 7], "m": [0, 3, 7], "7": [0, 4, 7, 10], "maj7": [0, 4, 7, 11], "m7": [0, 3, 7, 10],
    "m9": [0, 3, 7, 10, 14], "maj9": [0, 4, 7, 11, 14], "9": [0, 4, 7, 10, 14], "sus2": [0, 2, 7], "sus4": [0, 5, 7],
    "add9": [0, 4, 7, 14], "madd9": [0, 3, 7, 14], "dim": [0, 3, 6], "6": [0, 4, 7, 9], "m6": [0, 3, 7, 9], "5": [0, 7, 12],
}


def n(name):
    """'C4' -> 60, 'F#2' -> 42."""
    m = re.match(r"([A-G][#b]?)(-?\d)", name)
    return NOTE[m.group(1)] + 12 * (int(m.group(2)) + 1)


def chord(root, kind="", inv=0):
    r = n(root) if isinstance(root, str) else root
    notes = [r + i for i in CHORDS[kind]]
    for _ in range(inv):
        notes = notes[1:] + [notes[0] + 12]
    return notes


class Song:
    def __init__(self, name, bpm, bars, swing=0.0, swing_unit=0.25):
        self.name = name
        self.bpm = float(bpm)
        self.bars = bars
        self.spb = 60.0 / self.bpm
        self.L = int(round(bars * 4 * self.spb * SR))
        self.total = 3 * self.L + int(SR * 3)
        self.swing = swing
        self.swing_unit = swing_unit
        self.buses = {}
        self.cfg = {}
        self.duck_hits = []
        self.levels = {}
        self.master_lp = []

    # ---------------------------------------------------------- bus
    def bus(self, name, target=None, rev=0.0, dly=0.0, dly_beats=0.75, dly_fb=0.3, hp=0.0, lp=0.0, duck=0.0, duck_rel=0.18, sat=0.0, width=0.0, comp=None):
        self.buses[name] = np.zeros((2, self.total), np.float32)
        self.cfg[name] = dict(target=target, rev=rev, dly=dly, dly_beats=dly_beats, dly_fb=dly_fb, hp=hp, lp=lp, duck=duck, duck_rel=duck_rel, sat=sat, width=width, comp=comp)

    # ---------------------------------------------------------- temps
    def sec(self, beat):
        """Temps (s) d'un temps musical, avec swing (en temps) sur les contretemps de swing_unit."""
        p = beat / (2.0 * self.swing_unit)
        frac = p - np.floor(p + 1e-6)
        if self.swing and abs(frac - 0.5) < 1e-3:
            beat = beat + self.swing
        return beat * self.spb

    def beats(self, b):
        return b * self.spb

    # ---------------------------------------------------------- placement
    def put(self, bus, sig, beat, gain=1.0, pan=0.0, offset_sec=0.0):
        sig = np.asarray(sig, np.float32)
        st = dsp.pan(sig, pan) if sig.ndim == 1 else sig
        st = st * gain
        s0 = int(round((self.sec(beat) + offset_sec) * SR))
        buf = self.buses[bus]
        for k in range(3):
            s = s0 + k * self.L
            if s < 0:
                continue
            e = min(self.total, s + st.shape[1])
            if e > s:
                buf[:, s:e] += st[:, : e - s]

    def note(self, bus, fn, pitch, beat, dur, gain=1.0, pan=0.0, **kw):
        self.put(bus, fn(pitch, self.beats(dur), **kw), beat, gain, pan)

    def notes(self, bus, fn, pitches, beat, dur, gain=1.0, spread=0.0, strum=0.0, **kw):
        k = len(pitches)
        for i, p in enumerate(pitches):
            pn = (i / (k - 1) * 2 - 1) * spread if k > 1 else 0.0
            self.put(bus, fn(p, self.beats(dur), **kw), beat, gain / (k ** 0.5), pn, offset_sec=strum * i)

    def hit(self, bus, sig, beats_list, gain=1.0, pan=0.0, duck=False, human=0.0, seed=0):
        rng = np.random.default_rng(seed)
        for b in beats_list:
            g = gain * (1.0 + rng.uniform(-human, human)) if human else gain
            self.put(bus, sig, b, g, pan)
            if duck:
                self.duck_hits.append(b)

    def seq(self, bus, fn, pattern, start=0.0, step=0.25, gain=1.0, pan=0.0, **kw):
        """pattern : liste de (hauteur ou None, longueur en pas)."""
        t = start
        for item in pattern:
            p, length = item[0], item[1]
            if p is not None:
                self.note(bus, fn, p, t, length * step * 0.95, gain, pan, **kw)
            t += length * step

    # ---------------------------------------------------------- rendu
    def _duck_env(self, depth, rel):
        env = np.ones(self.total, np.float32)
        if depth <= 0 or not self.duck_hits:
            return env
        k = int(rel * 4 * SR)
        t = np.arange(k) / SR
        shape = (1.0 - depth * np.exp(-t / rel) * np.minimum(1.0, t / 0.004 + 0.2)).astype(np.float32)
        for b in self.duck_hits:
            s0 = int(round(self.sec(b) * SR))
            for c in range(3):
                s = s0 + c * self.L
                e = min(self.total, s + k)
                if 0 <= s < e:
                    env[s:e] = np.minimum(env[s:e], shape[: e - s])
        return env

    def render(self, room=0.82, damp=0.45, rev_gain=5.0, master_comp=(-14.0, 2.0), target_lufs=-18.0, ceiling=-1.2):
        dry = np.zeros((2, self.total), np.float32)
        send_rev = np.zeros((2, self.total), np.float32)
        for name, buf in self.buses.items():
            c = self.cfg[name]
            x = buf
            if c["hp"]:
                x = np.stack([dsp.hp(x[0], c["hp"]), dsp.hp(x[1], c["hp"])])
            if c["lp"]:
                x = np.stack([dsp.lp(x[0], c["lp"]), dsp.lp(x[1], c["lp"])])
            if c["sat"]:
                x = dsp.saturate(x, 1.0 + c["sat"])
            if c["comp"]:
                x = dsp.compress(x, *c["comp"])
            if c["width"]:
                mid = (x[0] + x[1]) * 0.5
                side = (x[0] - x[1]) * 0.5 * (1.0 + c["width"])
                x = np.stack([mid + side, mid - side])
            if c["duck"]:
                x = x * self._duck_env(c["duck"], c["duck_rel"])
            if c["target"] is not None:
                level = active_rms(x[:, self.L: 2 * self.L])
                x = x * 10 ** ((c["target"] - level) / 20.0)
            self.levels[name] = active_rms(x[:, self.L: 2 * self.L])
            if c["dly"]:
                d = self.beats(c["dly_beats"])
                l = dsp.delay(x[0] * c["dly"], d, c["dly_fb"], 0.4)
                r = dsp.delay(x[1] * c["dly"], d * 1.5 if d * 1.5 < 2.0 else d, c["dly_fb"], 0.4)
                x = x + np.stack([l, r])
            dry += x
            if c["rev"]:
                send_rev += x * c["rev"]
        wet = dsp.reverb(np.stack([dsp.hp(send_rev[0], 250), dsp.hp(send_rev[1], 250)]), room, damp) * rev_gain
        self.levels["(réverb)"] = active_rms(wet[:, self.L: 2 * self.L])
        self.levels["(sec)"] = active_rms(dry[:, self.L: 2 * self.L])
        mix = dry + wet
        if self.master_lp:
            fc = np.full(self.total, 19000.0, np.float32)
            for b0, b1, f0, f1 in self.master_lp:
                s0, s1 = int(self.sec(b0) * SR), int(self.sec(b1) * SR)
                ramp = (f0 * (f1 / f0) ** np.linspace(0, 1, s1 - s0)).astype(np.float32)
                for c in range(3):
                    a, b = s0 + c * self.L, s1 + c * self.L
                    fc[a:b] = ramp[: max(0, min(b, self.total) - a)]
            mix = np.stack([dsp.lp(mix[0], fc, 0.8), dsp.lp(mix[1], fc, 0.8)])
        mix = np.stack([dsp.hp(mix[0], 28), dsp.hp(mix[1], 28)])
        if master_comp:
            mix = dsp.compress(mix, master_comp[0], master_comp[1], 10.0, 150.0)
        loop = mix[:, self.L: 2 * self.L].copy()
        # normalisation intégrée puis limiteur (deux passes)
        for _ in range(3):
            lufs = measure_lufs(loop)
            loop *= 10 ** ((target_lufs - lufs) / 20.0)
            # limiteur sur une copie circulaire pour respecter la boucle
            ext = np.concatenate([loop[:, -SR // 2:], loop, loop[:, : SR // 2]], axis=1)
            ext = dsp.limit(ext, ceiling, 2.0, 60.0)
            loop = ext[:, SR // 2: SR // 2 + loop.shape[1]]
        self.loop = loop
        return loop

    def export(self, out_dir, base):
        os.makedirs(out_dir, exist_ok=True)
        wav = os.path.join(out_dir, base + ".wav")
        write_wav(wav, self.loop)
        ogg = os.path.join(out_dir, base + ".ogg")
        subprocess.check_call(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", ogg])
        return ogg


def write_wav(path, st):
    data = np.clip(st.T, -1, 1)
    pcm = (data * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def ebur128(path):
    out = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", "ebur128=peak=true", "-f", "null", "-"], capture_output=True, text=True).stderr
    i = re.findall(r"I:\s+(-?[\d.]+) LUFS", out)
    p = re.findall(r"Peak:\s+(-?[\d.]+) dBFS", out)
    return (float(i[-1]) if i else None, float(p[-1]) if p else None)


def measure_lufs(st):
    fd, path = tempfile.mkstemp(suffix=".wav")
    os.close(fd)
    # deux copies pour que la mesure intégrée couvre la boucle sans effet de bord
    write_wav(path, np.concatenate([st, st], axis=1) * 0.5)
    lufs, _ = ebur128(path)
    os.remove(path)
    return lufs + 20 * np.log10(2.0)


def spectrogram_png(st, path, width=1200, height=300):
    from PIL import Image
    mono = st.mean(axis=0)
    hop = max(1, len(mono) // width)
    win = 2048
    cols = []
    w = np.hanning(win)
    for i in range(width):
        s = i * hop
        seg = mono[s: s + win]
        if len(seg) < win:
            seg = np.pad(seg, (0, win - len(seg)))
        spec = np.abs(np.fft.rfft(seg * w))
        cols.append(spec)
    S = np.array(cols).T
    freqs = np.fft.rfftfreq(win, 1.0 / SR)
    edges = np.geomspace(30, 16000, height + 1)
    img = np.zeros((height, width))
    for j in range(height):
        m = (freqs >= edges[j]) & (freqs < edges[j + 1])
        if np.any(m):
            img[height - 1 - j] = S[m].mean(axis=0)
        else:
            k = np.searchsorted(freqs, edges[j])
            img[height - 1 - j] = S[min(k, len(freqs) - 1)]
    db = 20 * np.log10(img + 1e-6)
    db = np.clip((db - db.max() + 80) / 80, 0, 1)
    Image.fromarray((db * 255).astype(np.uint8)).save(path)


def bands(st):
    mono = st.mean(axis=0)
    spec = np.abs(np.fft.rfft(mono)) ** 2
    freqs = np.fft.rfftfreq(len(mono), 1.0 / SR)
    out = []
    for lo, hi in [(20, 60), (60, 250), (250, 2000), (2000, 6000), (6000, 16000)]:
        m = (freqs >= lo) & (freqs < hi)
        out.append(10 * np.log10(spec[m].sum() + 1e-9))
    top = max(out)
    return [round(v - top, 1) for v in out]


def active_rms(st, win_ms=50.0, floor_db=30.0):
    """Niveau RMS sur les seules fenêtres actives (ce qu'on entend quand l'instrument joue)."""
    mono = np.asarray(st).mean(axis=0) if np.asarray(st).ndim == 2 else np.asarray(st)
    w = int(win_ms * 0.001 * SR)
    k = len(mono) // w
    if k == 0:
        return -120.0
    p = (mono[: k * w].reshape(k, w) ** 2).mean(axis=1)
    db = 10 * np.log10(p + 1e-12)
    act = p[db > db.max() - floor_db]
    return float(10 * np.log10(act.mean() + 1e-12))
