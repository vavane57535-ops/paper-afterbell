"""Paper Afterbell 0.16 — moteur de synthèse des musiques de danse (numpy + petit noyau C).

Tout est composé par code : instruments synthétisés, motifs, mixage, réverbération,
compression, limiteur et normalisation à -18 LUFS. Les boucles sont rendues trois fois de
suite et seule la copie du milieu est gardée : les queues de réverbération de la fin
retombent naturellement sur le début, la boucle est sans clic.
"""
import ctypes
import os
import subprocess
import tempfile

import numpy as np

SR = 44100

_C = r"""
#include <math.h>
#include <string.h>
#include <stdlib.h>

/* Filtre à variables d'état (TPT, Zavalishin) à fréquence de coupure variable. mode 0=LP 1=BP 2=HP */
void svf(const float* x, float* y, int n, const float* fc, float q, int mode, float sr) {
    float ic1 = 0.f, ic2 = 0.f;
    float k = 1.f / q;
    for (int i = 0; i < n; i++) {
        float f = fc[i];
        if (f < 10.f) f = 10.f;
        if (f > sr * 0.45f) f = sr * 0.45f;
        float g = tanf(3.14159265f * f / sr);
        float a1 = 1.f / (1.f + g * (g + k));
        float a2 = g * a1;
        float a3 = g * a2;
        float v3 = x[i] - ic2;
        float v1 = a1 * ic1 + a2 * v3;
        float v2 = ic2 + a2 * ic1 + a3 * v3;
        ic1 = 2.f * v1 - ic1;
        ic2 = 2.f * v2 - ic2;
        if (mode == 0) y[i] = v2;
        else if (mode == 1) y[i] = v1 * k;
        else y[i] = x[i] - k * v1 - v2;
    }
}

void onepole(const float* x, float* y, int n, float a) {
    float s = 0.f;
    for (int i = 0; i < n; i++) { s += a * (x[i] - s); y[i] = s; }
}

/* Délai à réinjection avec amortissement (écho). */
void fbdelay(const float* x, float* y, int n, int d, float fb, float damp) {
    float* buf = (float*)calloc(d + 1, sizeof(float));
    int w = 0; float lp = 0.f;
    for (int i = 0; i < n; i++) {
        float out = buf[w];
        lp += damp * (out - lp);
        buf[w] = x[i] + lp * fb;
        y[i] = out;
        w++; if (w >= d) w = 0;
    }
    free(buf);
}

/* Réverbération type Freeverb (8 peignes + 4 passe-tout par canal). */
static const int CT[8] = {1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617};
static const int AT[4] = {556, 441, 341, 225};
void reverb(const float* in, float* out, int n, float room, float damp, int spread) {
    float* cb[8]; int ci[8]; float cs[8];
    float* ab[4]; int ai[4];
    int cl[8], al[4];
    for (int j = 0; j < 8; j++) { cl[j] = CT[j] + spread; cb[j] = (float*)calloc(cl[j], sizeof(float)); ci[j] = 0; cs[j] = 0.f; }
    for (int j = 0; j < 4; j++) { al[j] = AT[j] + spread; ab[j] = (float*)calloc(al[j], sizeof(float)); ai[j] = 0; }
    for (int i = 0; i < n; i++) {
        float x = in[i] * 0.015f; float acc = 0.f;
        for (int j = 0; j < 8; j++) {
            float o = cb[j][ci[j]];
            cs[j] = o * (1.f - damp) + cs[j] * damp;
            cb[j][ci[j]] = x + cs[j] * room;
            if (++ci[j] >= cl[j]) ci[j] = 0;
            acc += o;
        }
        for (int j = 0; j < 4; j++) {
            float b = ab[j][ai[j]];
            float o = -acc + b;
            ab[j][ai[j]] = acc + b * 0.5f;
            if (++ai[j] >= al[j]) ai[j] = 0;
            acc = o;
        }
        out[i] = acc;
    }
    for (int j = 0; j < 8; j++) free(cb[j]);
    for (int j = 0; j < 4; j++) free(ab[j]);
}

/* Compresseur (détection crête lissée) : renvoie le gain à appliquer. */
void compgain(const float* det, float* g, int n, float thr, float ratio, float att, float rel) {
    float env = 0.f;
    for (int i = 0; i < n; i++) {
        float v = det[i];
        float c = v > env ? att : rel;
        env += c * (v - env);
        float db = 20.f * log10f(env + 1e-9f);
        float over = db - thr;
        float red = over > 0.f ? over * (1.f - 1.f / ratio) : 0.f;
        g[i] = powf(10.f, -red / 20.f);
    }
}

/* Karplus-Strong : y[i] = k * (y[i-P] + y[i-P+1]) avec une période initiale. */
void ks(const float* init, int period, float* y, int n, float k) {
    for (int i = 0; i < n; i++) {
        if (i < period) { y[i] = init[i]; continue; }
        float a = y[i - period];
        float b = (i - period + 1 < i) ? y[i - period + 1] : a;
        y[i] = k * (a + b);
    }
}

/* Limiteur à anticipation : gain minimal sur la fenêtre, relâchement exponentiel. */
void limitgain(const float* peak, float* g, int n, float ceiling, int look, float rel) {
    float cur = 1.f;
    for (int i = 0; i < n; i++) {
        float need = 1.f;
        int end = i + look; if (end > n) end = n;
        for (int k = i; k < end; k++) { float p = peak[k]; if (p * need > ceiling) need = ceiling / p; }
        if (need < cur) cur = need; else cur += rel * (need - cur);
        g[i] = cur;
    }
}
"""

_lib = None


def lib():
    global _lib
    if _lib is None:
        d = tempfile.mkdtemp(prefix="pa_dsp_")
        src = os.path.join(d, "dsp.c")
        so = os.path.join(d, "dsp.so")
        with open(src, "w") as f:
            f.write(_C)
        subprocess.check_call(["gcc", "-O2", "-shared", "-fPIC", "-o", so, src, "-lm"])
        _lib = ctypes.CDLL(so)
        F = ctypes.POINTER(ctypes.c_float)
        _lib.svf.argtypes = [F, F, ctypes.c_int, F, ctypes.c_float, ctypes.c_int, ctypes.c_float]
        _lib.onepole.argtypes = [F, F, ctypes.c_int, ctypes.c_float]
        _lib.fbdelay.argtypes = [F, F, ctypes.c_int, ctypes.c_int, ctypes.c_float, ctypes.c_float]
        _lib.reverb.argtypes = [F, F, ctypes.c_int, ctypes.c_float, ctypes.c_float, ctypes.c_int]
        _lib.compgain.argtypes = [F, F, ctypes.c_int, ctypes.c_float, ctypes.c_float, ctypes.c_float, ctypes.c_float]
        _lib.ks.argtypes = [F, ctypes.c_int, F, ctypes.c_int, ctypes.c_float]
        _lib.limitgain.argtypes = [F, F, ctypes.c_int, ctypes.c_float, ctypes.c_int, ctypes.c_float]
    return _lib


def _p(a):
    return a.ctypes.data_as(ctypes.POINTER(ctypes.c_float))


def f32(a):
    return np.ascontiguousarray(a, dtype=np.float32)


# ---------------------------------------------------------------- filtres et effets

def filt(x, fc, q=0.707, mode="lp"):
    x = f32(x)
    n = len(x)
    fcv = f32(np.broadcast_to(np.asarray(fc, dtype=np.float32), (n,)).copy())
    y = np.zeros(n, np.float32)
    lib().svf(_p(x), _p(y), n, _p(fcv), float(q), {"lp": 0, "bp": 1, "hp": 2}[mode], float(SR))
    return y


def lp(x, fc, q=0.707):
    return filt(x, fc, q, "lp")


def hp(x, fc, q=0.707):
    return filt(x, fc, q, "hp")


def bp(x, fc, q=1.0):
    return filt(x, fc, q, "bp")


def peak_eq(x, fc, gain_db, q=1.0):
    return x + (10 ** (gain_db / 20.0) - 1.0) * bp(x, fc, q)


def onepole(x, a):
    x = f32(x)
    y = np.zeros(len(x), np.float32)
    lib().onepole(_p(x), _p(y), len(x), float(a))
    return y


def delay(x, seconds, fb=0.35, damp=0.5):
    x = f32(x)
    y = np.zeros(len(x), np.float32)
    lib().fbdelay(_p(x), _p(y), len(x), max(1, int(seconds * SR)), float(fb), float(damp))
    return y


def reverb(st, room=0.84, damp=0.4, width=1.0):
    """st : tableau (2, n). Renvoie la réverbération (wet) stéréo."""
    l = f32(st[0])
    r = f32(st[1])
    m = f32((l + r) * 0.5)
    ol = np.zeros(len(m), np.float32)
    orr = np.zeros(len(m), np.float32)
    lib().reverb(_p(m), _p(ol), len(m), float(room), float(damp), 0)
    lib().reverb(_p(m), _p(orr), len(m), float(room), float(damp), 23)
    mid = (ol + orr) * 0.5
    side = (ol - orr) * 0.5 * width
    return np.stack([mid + side, mid - side])


def compress(st, thr=-18.0, ratio=3.0, att_ms=5.0, rel_ms=120.0, makeup=0.0):
    det = f32(np.max(np.abs(st), axis=0))
    g = np.zeros(len(det), np.float32)
    att = 1.0 - np.exp(-1.0 / (att_ms * 0.001 * SR))
    rel = 1.0 - np.exp(-1.0 / (rel_ms * 0.001 * SR))
    lib().compgain(_p(det), _p(g), len(det), float(thr), float(ratio), float(att), float(rel))
    return st * g * (10 ** (makeup / 20.0))


def limit(st, ceiling_db=-1.2, look_ms=3.0, rel_ms=80.0):
    peak = f32(np.max(np.abs(st), axis=0))
    g = np.zeros(len(peak), np.float32)
    rel = 1.0 - np.exp(-1.0 / (rel_ms * 0.001 * SR))
    look = max(1, int(look_ms * 0.001 * SR))
    lib().limitgain(_p(peak), _p(g), len(peak), float(10 ** (ceiling_db / 20.0)), look, float(rel))
    # le gain est appliqué avec l'anticipation (décalé) pour attraper les crêtes
    g = np.concatenate([g[look:], np.full(look, g[-1], np.float32)])
    g = np.minimum(g, np.concatenate([g[:1].repeat(look), g[:-look]]))
    return st * g


def saturate(x, drive=1.0):
    return np.tanh(x * drive) / np.tanh(drive)


def pan(mono, p=0.0):
    a = (p + 1.0) * np.pi / 4.0
    return np.stack([mono * np.cos(a), mono * np.sin(a)]) * np.sqrt(2.0)


def widen(mono, ms=12.0, amount=0.5):
    """Mono -> stéréo élargi par léger décalage (Haas) d'un côté."""
    d = int(ms * 0.001 * SR)
    shifted = np.concatenate([np.zeros(d, np.float32), mono[:-d]]) if d > 0 else mono
    return np.stack([mono, mono * (1 - amount) + shifted * amount])


# ---------------------------------------------------------------- oscillateurs

def midi_hz(m):
    return 440.0 * 2.0 ** ((np.asarray(m, dtype=np.float64) - 69.0) / 12.0)


def phase_of(freq, n):
    f = np.broadcast_to(np.asarray(freq, dtype=np.float64), (n,))
    return np.cumsum(f) / SR


def _blep(t, dt):
    # correction polyBLEP (t en [0,1), dt = incrément de phase)
    out = np.zeros_like(t)
    m1 = t < dt
    x = t[m1] / dt[m1]
    out[m1] = x + x - x * x - 1.0
    m2 = t > 1.0 - dt
    x = (t[m2] - 1.0) / dt[m2]
    out[m2] = x * x + x + x + 1.0
    return out


def saw(freq, n, ph0=0.0):
    f = np.broadcast_to(np.asarray(freq, dtype=np.float64), (n,))
    ph = (phase_of(f, n) + ph0) % 1.0
    dt = np.clip(f / SR, 1e-6, 0.5)
    return (2.0 * ph - 1.0 - _blep(ph, dt)).astype(np.float32)


def square(freq, n, pw=0.5, ph0=0.0):
    f = np.broadcast_to(np.asarray(freq, dtype=np.float64), (n,))
    ph = (phase_of(f, n) + ph0) % 1.0
    dt = np.clip(f / SR, 1e-6, 0.5)
    s = np.where(ph < pw, 1.0, -1.0)
    s = s + _blep(ph, dt) - _blep((ph - pw) % 1.0, dt)
    return s.astype(np.float32)


def tri(freq, n, ph0=0.0):
    f = np.broadcast_to(np.asarray(freq, dtype=np.float64), (n,))
    ph = (phase_of(f, n) + ph0) % 1.0
    return (4.0 * np.abs(ph - 0.5) - 1.0).astype(np.float32)


def sine(freq, n, ph0=0.0):
    return np.sin(2 * np.pi * (phase_of(freq, n) + ph0)).astype(np.float32)


def noise(n, seed=None):
    rng = np.random.default_rng(seed)
    return rng.uniform(-1, 1, n).astype(np.float32)


def env_adsr(n, a=0.005, d=0.1, s=0.7, r=0.1, gate=None):
    """Enveloppe ADSR ; gate = durée tenue en secondes (sinon n - release)."""
    t = np.arange(n) / SR
    g = gate if gate is not None else max(0.0, n / SR - r)
    e = np.where(t < a, t / max(a, 1e-6), s + (1 - s) * np.exp(-(t - a) / max(d, 1e-6)))
    rel = t > g
    if np.any(rel):
        at_g = (g / max(a, 1e-6)) if g < a else s + (1 - s) * np.exp(-(g - a) / max(d, 1e-6))
        e = np.where(rel, at_g * np.exp(-(t - g) / max(r / 4.0, 1e-6)), e)
    return e.astype(np.float32)


def env_exp(n, decay, attack=0.002):
    t = np.arange(n) / SR
    e = np.exp(-t / max(decay, 1e-6))
    if attack > 0:
        e *= np.minimum(1.0, t / attack)
    return e.astype(np.float32)


def fade_tail(x, ms=8.0):
    k = min(len(x), int(ms * 0.001 * SR))
    if k > 1:
        x[-k:] *= np.linspace(1.0, 0.0, k, dtype=np.float32)
    return x


def karplus(init, n, k):
    init = f32(init)
    y = np.zeros(n + len(init), np.float32)
    lib().ks(_p(init), len(init), _p(y), len(y), float(k))
    return y[len(init):]
