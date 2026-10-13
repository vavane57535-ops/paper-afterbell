"""Petits sons des émotes (audio/emotes/*.wav) : python3 -B tools/dance_music/emote_sfx.py"""
import os
import sys
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import dsp  # noqa: E402
import instruments as I  # noqa: E402
from dsp import SR  # noqa: E402


def room(x, amount=0.12):
    st = np.stack([x, x])
    pad = np.zeros((2, int(SR * 0.4)), np.float32)
    st = np.concatenate([st, pad], axis=1)
    wet = dsp.reverb(st, 0.55, 0.5) * 5.0
    out = st + wet * amount
    return out.mean(axis=0)


def save(name, x, peak_db=-4.0):
    x = np.asarray(x, np.float32)
    k = int(SR * 0.004)
    x[:k] *= np.linspace(0, 1, k)
    x[-k * 3:] *= np.linspace(1, 0, k * 3)
    x = x / (np.abs(x).max() + 1e-9) * 10 ** (peak_db / 20.0)
    os.makedirs("audio/emotes", exist_ok=True)
    with wave.open("audio/emotes/%s.wav" % name, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())


def kiss():
    n = int(SR * 0.35)
    t = np.arange(n) / SR
    smack = dsp.bp(dsp.noise(n, 3), 2800, 3.0) * I.env_exp(n, 0.006, 0.0005) * 2.0
    mw = I.voice(70, 0.18, vowel="u", to_vowel="a", vibrato=0.0, attack=0.02, release=0.08)[:n]
    out = np.zeros(n, np.float32)
    out += smack
    s = int(0.02 * SR)
    out[s:s + len(mw)] += mw[: n - s] * 0.6
    return out


def shutter():
    n = int(SR * 0.25)
    out = np.zeros(n, np.float32)
    for at, f in ((0.0, 3200), (0.07, 2400)):
        s = int(at * SR)
        k = int(0.03 * SR)
        click = dsp.bp(dsp.noise(k, int(f)), f, 2.5) * I.env_exp(k, 0.004, 0.0003) * 2.0
        click += dsp.lp(dsp.noise(k, 9), 900) * I.env_exp(k, 0.008) * 0.6
        out[s:s + k] += click
    return out


def raspberry():
    n = int(SR * 0.55)
    t = np.arange(n) / SR
    buzz = dsp.saw(np.full(n, 82.0) * (1 + 0.04 * np.sin(2 * np.pi * 7 * t)), n)
    am = (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 26 * t))).astype(np.float32)
    x = dsp.bp(buzz * am, 700, 1.2) + dsp.bp(dsp.noise(n, 4), 1200, 1.0) * am * 0.3
    return x * I.env_adsr(n, 0.02, 0.2, 0.9, 0.12, gate=0.42)


def heel():
    n = int(SR * 0.2)
    out = np.zeros(n, np.float32)
    for at in (0.0, 0.035):
        s = int(at * SR)
        c = I.woodblock(0.7)
        out[s:s + len(c)] += c[: n - s]
    out += dsp.lp(dsp.noise(n, 5), 400) * I.env_exp(n, 0.03) * 0.6
    return out


def slap():
    n = int(SR * 0.18)
    x = dsp.bp(dsp.noise(n, 6), 1800, 0.9) * I.env_exp(n, 0.012, 0.0005) * 1.6
    x += dsp.sine(np.full(n, 160.0), n) * I.env_exp(n, 0.02) * 0.5
    return x


def stomp():
    n = int(SR * 0.35)
    t = np.arange(n) / SR
    thud = dsp.sine(70 * (1 + 0.8 * np.exp(-t / 0.02)), n) * I.env_exp(n, 0.09, 0.001)
    grit = dsp.lp(dsp.noise(n, 7), 1500) * I.env_exp(n, 0.025) * 0.6
    return dsp.saturate(thud * 1.4 + grit, 1.3)


def main():
    save("clap", room(I.clap(0.14, seed=11)))
    save("slap", room(slap(), 0.08))
    save("kiss", room(kiss(), 0.1), -6.0)
    save("shutter", room(shutter(), 0.05), -6.0)
    save("raspberry", room(raspberry(), 0.08), -5.0)
    save("heel", room(heel(), 0.1))
    save("snap", room(I.snap(12), 0.15), -6.0)
    save("stomp", room(stomp(), 0.1))
    print("sons d'émotes écrits dans audio/emotes/")


if __name__ == "__main__":
    main()
