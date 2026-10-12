#!/usr/bin/env python3
"""Bruitages synthétisés du prologue « Yiero » (Paper Afterbell 0.16) — version définitive.

Produit audio/cinematic/sfx_*.wav (stéréo 44,1 kHz, 16 bits). La musique du film
(audio/cinematic/intro_yiero.ogg) est une vraie composition : ce script n'y touche PAS.

Chaque son est construit par synthèse « physique » simple : source glottale + formants pour
les cris de Yiero (voix de géant : formants abaissés, sous-harmonique, friture vocale), transitoires
+ résonateurs pour les impacts, granulaire pour le papier, convolution par une réverbération
synthétique pour l'espace. Les niveaux sont calés en RMS court terme (fenêtre 100 ms) pour que
le film puisse doser les bruitages par rapport à la musique (voir FILM_SFX_LEVEL dans
film_intro_yiero.gd).

Usage : python3 tools/synth_intro_audio.py   (numpy uniquement)
"""
import os
import sys
import wave

import numpy as np

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "audio", "cinematic")
rng = np.random.default_rng(6661)


# ---------------------------------------------------------------- outils de base

def t_axis(seconds):
	return np.arange(int(round(seconds * SR))) / SR


def noise(n):
	return rng.standard_normal(n)


def pink(n):
	spec = np.fft.rfft(noise(n))
	f = np.fft.rfftfreq(n, 1 / SR)
	spec[1:] /= np.sqrt(f[1:])
	spec[0] = 0
	x = np.fft.irfft(spec, n)
	return x / (np.std(x) + 1e-12)


def brown(n):
	x = np.cumsum(noise(n))
	x -= np.convolve(x, np.ones(2048) / 2048, mode="same")
	return x / (np.std(x) + 1e-12)


def fft_filter(x, response):
	"""Filtre statique : response(freqs) -> gain."""
	n = len(x)
	spec = np.fft.rfft(x)
	spec *= response(np.fft.rfftfreq(n, 1 / SR))
	return np.fft.irfft(spec, n)


def lowpass(x, fc, order=2):
	return fft_filter(x, lambda f: 1.0 / np.sqrt(1.0 + (f / fc) ** (2 * order)))


def highpass(x, fc, order=2):
	return fft_filter(x, lambda f: 1.0 / np.sqrt(1.0 + (fc / np.maximum(f, 1e-3)) ** (2 * order)))


def bandpass(x, lo, hi, order=2):
	return highpass(lowpass(x, hi, order), lo, order)


def stft_filter(x, gain_at, frame=2048, hop=512):
	"""Filtre variable dans le temps : gain_at(freqs, t) -> gain, appliqué trame par trame."""
	n = len(x)
	win = np.hanning(frame)
	pad = np.concatenate([np.zeros(frame), x, np.zeros(frame)])
	out = np.zeros(len(pad))
	norm = np.zeros(len(pad))
	freqs = np.fft.rfftfreq(frame, 1 / SR)
	for start in range(0, len(pad) - frame, hop):
		seg = pad[start:start + frame] * win
		t = (start + frame / 2 - frame) / SR
		spec = np.fft.rfft(seg) * gain_at(freqs, max(0.0, t))
		out[start:start + frame] += np.fft.irfft(spec, frame) * win
		norm[start:start + frame] += win ** 2
	out /= np.maximum(norm, 1e-6)
	return out[frame:frame + n]


def formants(freqs, table, scale=1.0):
	"""Somme de résonances (fréquence, largeur, gain) : enveloppe spectrale d'une voyelle."""
	g = np.zeros_like(freqs) + 0.002
	for fc, bw, gain in table:
		fc *= scale
		bw *= scale
		g += gain / (1.0 + ((freqs - fc) / (bw * 0.5)) ** 2)
	return g


# voyelles (Hz, largeur, gain) — voix adulte, abaissées ensuite pour le géant
VOWEL_A = [(730, 90, 1.0), (1090, 110, 0.55), (2440, 170, 0.22), (3400, 250, 0.08)]
VOWEL_O = [(570, 80, 1.0), (840, 100, 0.5), (2410, 170, 0.12), (3300, 250, 0.05)]
VOWEL_U = [(300, 70, 1.0), (870, 100, 0.35), (2240, 160, 0.08)]
VOWEL_E = [(530, 80, 1.0), (1840, 130, 0.45), (2480, 180, 0.2)]


def glottal(freq_curve, jitter=0.02, sub=0.0, fry=0.0, fry_rate=28.0):
	"""Source voisée : dent de scie adoucie + gigue + sous-harmonique + friture vocale."""
	n = len(freq_curve)
	jit = 1.0 + jitter * lowpass(noise(n), 30.0) / 0.2
	f = freq_curve * jit
	phase = np.cumsum(f / SR)
	saw = 2.0 * (phase % 1.0) - 1.0
	src = lowpass(saw, 2600.0, 1)
	if sub > 0.0:
		src += sub * (2.0 * ((phase * 0.5) % 1.0) - 1.0)
	if fry > 0.0:
		t = np.arange(n) / SR
		pulse = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * fry_rate * t + 2.0 * np.sin(2 * np.pi * 3.1 * t)))
		src *= (1.0 - fry) + fry * pulse
	return src


def env_points(n, points):
	"""Enveloppe linéaire par points [(t, valeur), …]."""
	t = np.arange(n) / SR
	ts = [p[0] for p in points]
	vs = [p[1] for p in points]
	return np.interp(t, ts, vs)


def soft(x, drive=1.0):
	return np.tanh(x * drive) / np.tanh(drive)


def reverb_ir(seconds, damp=3000.0, predelay=0.012, seed=0):
	r = np.random.default_rng(seed)
	n = int(seconds * SR)
	t = np.arange(n) / SR
	ir = r.standard_normal(n) * np.exp(-6.9 * t / seconds)
	# les aigus s'éteignent plus vite
	ir = stft_filter(ir, lambda f, tt: 1.0 / np.sqrt(1.0 + (f / (damp / (1.0 + 4.0 * tt))) ** 2))
	ir = np.concatenate([np.zeros(int(predelay * SR)), ir])
	return ir / (np.sqrt(np.sum(ir ** 2)) + 1e-12)


def convolve(x, ir):
	n = len(x) + len(ir) - 1
	size = 1 << (n - 1).bit_length()
	return np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[:n]


def space(x, seconds=2.0, mix=0.3, damp=3000.0, width=1.0, tail=True):
	"""Réverbération stéréo (deux réponses décorrélées) ; renvoie un tableau (n, 2)."""
	irl = reverb_ir(seconds, damp, 0.011, 11)
	irr = reverb_ir(seconds, damp, 0.017, 23)
	wl = convolve(x, irl)
	wr = convolve(x, irr)
	n = len(wl) if tail else len(x)
	dry = np.zeros(n)
	dry[:len(x)] = x
	wl = wl[:n]
	wr = wr[:n]
	mid = (wl + wr) * 0.5
	side = (wl - wr) * 0.5 * width
	left = dry * (1.0 - mix) + (mid + side) * mix
	right = dry * (1.0 - mix) + (mid - side) * mix
	return np.stack([left, right], axis=1)


def stereo(x, pan=0.0):
	return np.stack([x * np.sqrt(0.5 * (1 - pan)), x * np.sqrt(0.5 * (1 + pan))], axis=1)


def fade_tail(x, seconds=0.05):
	n = min(len(x), int(seconds * SR))
	x = x.copy()
	ramp = np.linspace(1.0, 0.0, n)
	if x.ndim == 1:
		x[-n:] *= ramp
	else:
		x[-n:] *= ramp[:, None]
	return x


def short_rms_db(x):
	mono = x.mean(axis=1) if x.ndim == 2 else x
	hop = int(0.1 * SR)
	best = 1e-9
	for i in range(0, max(1, len(mono) - hop), hop // 2):
		best = max(best, float(np.sqrt(np.mean(mono[i:i + hop] ** 2))))
	return 20 * np.log10(best)


def level(x, target_db, ceiling_db=-1.0):
	"""Cale le RMS court terme maximal sur target_db, sans dépasser le plafond crête."""
	x = x - np.mean(x, axis=0)
	gain = 10 ** ((target_db - short_rms_db(x)) / 20)
	x = x * gain
	peak = np.max(np.abs(x))
	ceiling = 10 ** (ceiling_db / 20)
	if peak > ceiling * 1.6:
		x = np.tanh(x / ceiling) * ceiling
	elif peak > ceiling:
		x = x * ceiling / peak
	# coupe la fin de la queue de réverbération sous -66 dB
	mono = np.max(np.abs(x), axis=1) if x.ndim == 2 else np.abs(x)
	loud = np.nonzero(mono > 10 ** (-66 / 20))[0]
	if len(loud):
		x = x[:min(len(x), loud[-1] + int(0.05 * SR))]
	return fade_tail(x, 0.08)


def resonator_hit(n, modes, strike=1.0):
	"""Impact sur un corps résonant : modes (fréquence, décroissance /s, gain)."""
	t = np.arange(n) / SR
	out = np.zeros(n)
	for f, decay, gain in modes:
		out += gain * np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28)) * np.exp(-decay * t)
	click = noise(n) * np.exp(-t * 900.0) * strike
	return out + click


def droplets(n, count, start, spread, lo=350.0, hi=1500.0, gain=1.0):
	"""Gouttes : petits gazouillis ascendants (bulle qui éclate)."""
	out = np.zeros(n)
	for _ in range(count):
		at = start + abs(rng.normal(0.0, spread))
		i = int(at * SR)
		if i >= n:
			continue
		length = rng.uniform(0.012, 0.04)
		m = min(n - i, int(length * SR))
		tt = np.arange(m) / SR
		f0 = rng.uniform(lo, hi)
		f = f0 * (1.0 + 1.6 * tt / length)
		chirp = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt / (length * 0.35))
		out[i:i + m] += chirp * rng.uniform(0.25, 1.0) * gain * np.exp(-at * 1.2)
	return out


def crackle(n, density, lo=1200.0, hi=7000.0, start=0.0, end=None, shape=None):
	"""Craquements (papier, débris) : impulsions filtrées réparties dans le temps."""
	end = end if end is not None else n / SR
	clicks = np.zeros(n)
	duration = max(0.001, end - start)
	count = int(density * duration)
	for _ in range(count):
		u = rng.uniform(0.0, 1.0)
		if shape is not None:
			u = shape(u)
		i = int((start + u * duration) * SR)
		if 0 <= i < n:
			clicks[i] += rng.uniform(-1.0, 1.0) * rng.uniform(0.2, 1.0)
	grains = convolve(clicks, noise(int(0.004 * SR)) * np.exp(-np.arange(int(0.004 * SR)) / (0.0012 * SR)))[:n]
	return bandpass(grains, lo, hi)


def sub_boom(n, f0, f1, decay, curve=3.0):
	t = np.arange(n) / SR
	u = np.clip(t / max(1e-3, decay * 2.5), 0.0, 1.0)
	f = f1 + (f0 - f1) * (1.0 - u) ** curve
	return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / decay) * np.minimum(1.0, t / 0.004)


# ---------------------------------------------------------------- voix de Yiero

def giant_voice(seconds, pitch_points, amp_points, vowel_points, sub=0.45, fry=0.35, breath=0.25, scale=0.58, drive=2.2):
	"""Voix de géant : source glottale (sous-harmonique, friture) filtrée par des formants abaissés
	qui glissent d'une voyelle à l'autre ; souffle filtré par les mêmes formants."""
	n = int(seconds * SR)
	freq = env_points(n, pitch_points)
	src = glottal(freq, jitter=0.03, sub=sub, fry=fry, fry_rate=26.0)
	air = pink(n) * breath
	vowel_t = [p[0] for p in vowel_points]
	vowel_tab = [p[1] for p in vowel_points]

	def response(f, tt):
		k = int(np.searchsorted(vowel_t, tt, side="right")) - 1
		k = max(0, min(k, len(vowel_t) - 1))
		if k + 1 < len(vowel_t):
			u = np.clip((tt - vowel_t[k]) / max(1e-3, vowel_t[k + 1] - vowel_t[k]), 0.0, 1.0)
			return formants(f, vowel_tab[k], scale) * (1 - u) + formants(f, vowel_tab[k + 1], scale) * u
		return formants(f, vowel_tab[k], scale)

	voiced = stft_filter(src + air, response)
	voiced = soft(voiced / (np.std(voiced) + 1e-9) * 0.35, drive)
	return voiced * env_points(n, amp_points)


def sfx_roar():
	seconds = 3.0
	n = int(seconds * SR)
	t = np.arange(n) / SR
	voice = giant_voice(seconds,
		[(0.0, 62), (0.18, 88), (0.5, 104), (1.2, 96), (2.0, 78), (2.6, 52), (3.0, 46)],
		[(0.0, 0.0), (0.06, 0.55), (0.25, 1.0), (1.6, 0.95), (2.3, 0.6), (2.75, 0.0), (3.0, 0.0)],
		[(0.0, VOWEL_U), (0.25, VOWEL_A), (1.8, VOWEL_A), (2.6, VOWEL_O)], sub=0.6, fry=0.4, breath=0.35, scale=0.55, drive=2.8)
	# deuxième « gorge » désaccordée pour l'épaisseur
	voice2 = giant_voice(seconds,
		[(0.0, 47), (0.2, 66), (0.5, 79), (1.2, 73), (2.0, 60), (2.6, 41), (3.0, 37)],
		[(0.0, 0.0), (0.1, 0.4), (0.3, 0.8), (1.6, 0.8), (2.4, 0.4), (2.8, 0.0), (3.0, 0.0)],
		[(0.0, VOWEL_O), (0.3, VOWEL_A), (2.6, VOWEL_U)], sub=0.3, fry=0.6, breath=0.2, scale=0.5, drive=3.2)
	rumble = lowpass(brown(n), 90.0) * env_points(n, [(0, 0), (0.08, 1.0), (1.8, 0.8), (2.8, 0.0), (3.0, 0)])
	sub = np.sin(2 * np.pi * np.cumsum(env_points(n, [(0, 34), (0.4, 44), (2.5, 30), (3.0, 28)])) / SR) * env_points(n, [(0, 0), (0.12, 1), (2.2, 0.7), (2.9, 0), (3.0, 0)])
	hiss = bandpass(noise(n), 2500, 9000) * env_points(n, [(0, 0), (0.05, 0.6), (0.4, 0.25), (2.0, 0.15), (2.6, 0), (3.0, 0)])
	x = voice * 1.0 + voice2 * 0.7 + rumble * 0.55 + sub * 0.5 + hiss * 0.12
	return level(space(x, 3.4, 0.32, 2400.0), -9.0)


def sfx_laugh():
	seconds = 3.0
	n = int(seconds * SR)
	out = np.zeros(n)
	# « HA… ha-ha-ha-HAAA » : syllabes courtes et détachées qui accélèrent, la dernière traîne.
	starts = [0.0, 0.46, 0.76, 1.04, 1.3, 1.56]
	pitches = [98, 90, 87, 84, 80, 72]
	lengths = [0.2, 0.15, 0.14, 0.14, 0.14, 0.5]
	for k, (st, p, ln) in enumerate(zip(starts, pitches, lengths)):
		m = int((ln + 0.04) * SR)
		syl = giant_voice(ln + 0.04,
			[(0.0, p * 1.15), (ln * 0.25, p), (ln, p * 0.84), (ln + 0.04, p * 0.8)],
			[(0.0, 0.0), (0.01, 0.9), (0.035, 1.0), (ln * 0.55, 0.75), (ln, 0.06), (ln + 0.04, 0.0)],
			[(0.0, VOWEL_E), (0.03, VOWEL_A), (ln, VOWEL_O)], sub=0.55, fry=0.45, breath=0.45, scale=0.56, drive=2.5)
		# aspiration « h » au début de chaque syllabe
		h = bandpass(noise(m), 400, 3000) * np.exp(-np.arange(m) / (0.025 * SR)) * 0.55
		i = int(st * SR)
		j = min(n, i + m)
		out[i:j] += (syl[:j - i] + h[:j - i]) * (1.0 - 0.05 * k)
	return level(space(out, 2.2, 0.2, 2600.0), -12.0)


def sfx_growl():
	seconds = 1.3
	n = int(seconds * SR)
	x = giant_voice(seconds,
		[(0.0, 44), (0.3, 52), (0.9, 47), (1.3, 40)],
		[(0.0, 0.0), (0.08, 0.9), (0.7, 1.0), (1.15, 0.0), (1.3, 0.0)],
		[(0.0, VOWEL_U), (0.5, VOWEL_O), (1.3, VOWEL_U)], sub=0.7, fry=0.7, breath=0.3, scale=0.5, drive=3.5)
	return level(space(x, 1.8, 0.25, 2200.0), -12.0)


def sfx_creak():
	"""Le sourire qui se fend : cuir/os qui craque, salive, grondement sourd."""
	seconds = 2.2
	n = int(seconds * SR)
	t = np.arange(n) / SR
	rate = env_points(n, [(0, 9), (1.0, 22), (1.6, 34), (2.2, 14)])
	phase = np.cumsum(rate * (1.0 + 0.35 * lowpass(noise(n), 6.0) / 0.1) / SR)
	ticks = np.zeros(n)
	edges = np.nonzero(np.diff(np.floor(phase)) > 0)[0]
	ticks[edges] = rng.uniform(0.4, 1.0, len(edges)) * np.sign(rng.uniform(-1, 1, len(edges)))
	body = convolve(ticks, resonator_hit(int(0.05 * SR), [(330, 70, 1.0), (760, 110, 0.6), (1450, 160, 0.35)], 0.2))[:n]
	wet = stft_filter(noise(n), lambda f, tt: formants(f, [(900 + 500 * np.sin(tt * 5.0), 300, 1.0)]) * (0.3 + 0.7 * (np.sin(tt * 11.0) > 0.6)))
	groan = giant_voice(seconds, [(0, 38), (1.2, 42), (2.2, 36)], [(0, 0), (0.5, 0.5), (1.7, 0.6), (2.2, 0)], [(0, VOWEL_U), (2.2, VOWEL_O)], sub=0.5, fry=0.8, breath=0.1, scale=0.45, drive=2.0)
	envl = env_points(n, [(0, 0), (0.25, 0.8), (1.5, 1.0), (2.0, 0.4), (2.2, 0)])
	x = (body * 1.0 + wet * 0.12 + groan * 0.6) * envl
	return level(space(x, 1.6, 0.28, 3000.0), -15.0)


def sfx_thump():
	"""Battement de cœur lointain et gigantesque : « lub-dub » étouffé."""
	seconds = 1.2
	n = int(seconds * SR)
	x = np.zeros(n)
	for at, f0, g in ((0.0, 58.0, 1.0), (0.21, 50.0, 0.75)):
		i = int(at * SR)
		m = n - i
		beat = sub_boom(m, f0, 34.0, 0.16, 2.0) + lowpass(noise(m), 180.0) * np.exp(-np.arange(m) / (0.03 * SR)) * 0.35
		x[i:] += beat * g
	x = lowpass(x, 260.0)
	return level(space(x, 2.2, 0.3, 900.0), -12.0)


def sfx_rumble():
	seconds = 3.8
	n = int(seconds * SR)
	t = np.arange(n) / SR
	mod = 0.65 + 0.35 * lowpass(noise(n), 4.0) / 0.03
	base = lowpass(brown(n), 110.0) * np.clip(mod, 0.2, 1.4)
	deep = np.sin(2 * np.pi * np.cumsum(env_points(n, [(0, 31), (3.8, 27)])) / SR) * 0.6
	debris = crackle(n, 70, 900.0, 5000.0, 0.4, 3.2) * 0.25
	x = (base + deep) * env_points(n, [(0, 0), (0.7, 1.0), (2.3, 0.9), (3.8, 0)]) + debris * env_points(n, [(0, 0), (1.0, 1.0), (3.2, 0)])
	return level(space(x, 2.5, 0.25, 1200.0), -13.0)


def sfx_splash():
	"""Main géante qui crève la surface d'encre."""
	seconds = 1.6
	n = int(seconds * SR)
	t = np.arange(n) / SR
	bloosh = lowpass(noise(n), 500.0) * np.exp(-t / 0.18) * np.minimum(1.0, t / 0.01)
	sheet = bandpass(noise(n), 700.0, 5000.0) * np.exp(-t / 0.35) * np.minimum(1.0, t / 0.03) * 0.5
	thud = sub_boom(n, 70.0, 36.0, 0.18) * 0.8
	drops = droplets(n, 46, 0.08, 0.35, 300.0, 1300.0, 0.5)
	x = bloosh + sheet + thud + drops
	return level(space(x, 1.8, 0.28, 3500.0), -13.0)


def sfx_slam():
	"""Griffe qui s'abat dans l'encre : énorme coup sourd, éclaboussure, débris."""
	seconds = 2.4
	n = int(seconds * SR)
	t = np.arange(n) / SR
	boom = sub_boom(n, 64.0, 28.0, 0.42) * 1.2
	crunch = soft(bandpass(noise(n), 180.0, 2600.0) * np.exp(-t / 0.06) * 3.0, 2.0) * 0.7
	crack = highpass(noise(n), 2500.0) * np.exp(-t / 0.012) * 0.6
	splash = lowpass(noise(n), 900.0) * np.exp(-t / 0.3) * np.minimum(1.0, t / 0.02) * 0.6
	drops = droplets(n, 60, 0.12, 0.5, 260.0, 1100.0, 0.45)
	debris = crackle(n, 120, 800.0, 6000.0, 0.05, 1.6, lambda u: u ** 2) * 0.35
	x = boom + crunch + crack + splash + drops + debris
	return level(space(x, 2.8, 0.3, 2500.0), -10.0)


def sfx_spike():
	"""Griffe d'encre qui jaillit du sol."""
	seconds = 1.2
	n = int(seconds * SR)
	t = np.arange(n) / SR
	rise = stft_filter(noise(n), lambda f, tt: formants(f, [(300.0 + 9000.0 * min(tt, 0.16), 500.0 + 3000.0 * min(tt, 0.16), 1.0)])) * env_points(n, [(0, 0), (0.1, 0.8), (0.16, 1.0), (0.3, 0.2), (1.2, 0)])
	crack = np.zeros(n)
	i = int(0.15 * SR)
	crack[i:] = resonator_hit(n - i, [(420, 30, 0.6), (1130, 45, 0.4), (2650, 70, 0.25)], 1.0)
	wet = lowpass(noise(n), 1400.0) * np.exp(-np.maximum(0, t - 0.16) / 0.25) * (t > 0.15) * 0.5
	drops = droplets(n, 22, 0.2, 0.3, 400.0, 1600.0, 0.4)
	x = rise * 0.8 + crack * 0.7 + wet + drops
	return level(space(x, 1.5, 0.25, 3500.0), -13.0)


def sfx_whoosh():
	seconds = 0.75
	n = int(seconds * SR)
	t = np.arange(n) / SR
	center = env_points(n, [(0, 500), (0.32, 2600), (0.75, 700)])
	src = noise(n)
	x = stft_filter(src, lambda f, tt: formants(f, [(float(np.interp(tt, [0, 0.32, 0.75], [500, 2600, 700])), 900.0, 1.0)]), 1024, 256)
	x *= np.sin(np.pi * np.clip(t / seconds, 0, 1)) ** 2.2
	flutter = 1.0 + 0.25 * np.sin(2 * np.pi * 31.0 * t)
	left = x * flutter * np.linspace(1.15, 0.6, n)
	right = x * flutter * np.linspace(0.6, 1.15, n)
	return level(np.stack([left, right], axis=1), -15.0)


BELL = [(1.0, 1.0, 1.4), (2.76, 0.5, 2.2), (5.40, 0.28, 3.4), (8.93, 0.14, 5.0), (13.3, 0.07, 7.0)]


def bell(n, f0, decay=1.0, gain=1.0):
	t = np.arange(n) / SR
	out = np.zeros(n)
	for ratio, g, d in BELL:
		out += g * np.sin(2 * np.pi * f0 * ratio * t + rng.uniform(0, 6.28)) * np.exp(-t * d / decay)
	return out * gain * np.minimum(1.0, t / 0.002)


def sfx_ignite():
	"""Les poings s'embrasent de lumière dorée : souffle qui monte + carillon + chaleur."""
	seconds = 2.0
	n = int(seconds * SR)
	t = np.arange(n) / SR
	fwoom = stft_filter(noise(n), lambda f, tt: formants(f, [(200.0 + 2400.0 * min(tt, 0.3) / 0.3, 700.0, 1.0)])) * env_points(n, [(0, 0), (0.22, 1.0), (0.5, 0.45), (1.6, 0.15), (2.0, 0)])
	flame = bandpass(noise(n), 900, 5000) * (0.6 + 0.4 * lowpass(noise(n), 18.0) / 0.12) * env_points(n, [(0, 0), (0.3, 0.3), (1.8, 0.1), (2.0, 0)])
	chime = np.zeros(n)
	for k, (f0, at) in enumerate(((587.3, 0.2), (880.0, 0.26), (1174.7, 0.32), (1760.0, 0.4))):
		i = int(at * SR)
		chime[i:] += bell(n - i, f0, 1.4, 0.5 - 0.08 * k)
	warm = np.sin(2 * np.pi * 146.8 * t) * 0.3 + np.sin(2 * np.pi * 220.0 * t) * 0.18
	warm *= env_points(n, [(0, 0), (0.3, 1.0), (1.4, 0.6), (2.0, 0)])
	x = fwoom * 0.9 + flame * 0.5 + chime * 0.45 + warm
	return level(space(x, 2.4, 0.33, 5000.0, 1.3), -14.0)


def sfx_gold_hit():
	"""Coup de poing béni : claque, corps grave, craquement, résonance dorée."""
	seconds = 2.2
	n = int(seconds * SR)
	t = np.arange(n) / SR
	snap = highpass(noise(n), 1800.0) * np.exp(-t / 0.008)
	body = sub_boom(n, 110.0, 42.0, 0.2) * 1.1
	crunch = soft(bandpass(noise(n), 300, 3500) * np.exp(-t / 0.035) * 4.0, 2.5) * 0.6
	ring = bell(n, 659.3, 1.1, 0.35) + bell(n, 987.8, 0.9, 0.22)
	air = bandpass(noise(n), 3000, 10000) * np.exp(-t / 0.4) * 0.08
	x = snap * 0.8 + body + crunch + ring + air
	return level(space(x, 2.4, 0.3, 4500.0, 1.2), -10.0)


def sfx_metal():
	"""Le drone d'Ashura ricoche sur une dent : tintement métallique + émail."""
	seconds = 1.1
	n = int(seconds * SR)
	clang = resonator_hit(n, [(523, 5, 0.8), (1310, 7, 0.6), (2230, 10, 0.45), (3420, 14, 0.3), (4710, 18, 0.2), (6150, 24, 0.12)], 0.8)
	tooth = resonator_hit(n, [(1900, 60, 0.6), (3100, 80, 0.4)], 0.5)
	x = clang + tooth * 0.6
	return level(space(x, 1.4, 0.25, 6000.0), -15.0)


def sfx_erase():
	"""Ashura effacé : papier qui se déchire de plus en plus, aspiration inversée, voile spectral."""
	seconds = 4.0
	n = int(seconds * SR)
	t = np.arange(n) / SR
	tear = crackle(n, 520, 1200.0, 7500.0, 0.1, 3.6, lambda u: u ** 0.7) * env_points(n, [(0, 0.3), (2.0, 0.8), (3.5, 1.0), (3.7, 0)])
	rips = np.zeros(n)
	for _ in range(14):
		at = rng.uniform(0.2, 3.3)
		ln = rng.uniform(0.08, 0.25)
		i = int(at * SR)
		m = min(n - i, int(ln * SR))
		seg = bandpass(noise(m), 1500, 6500) * (0.5 + 0.5 * (rng.uniform(size=m) > 0.7)) * np.sin(np.linspace(0, np.pi, m)) ** 0.5
		rips[i:i + m] += seg * rng.uniform(0.3, 0.8)
	suction = stft_filter(pink(n), lambda f, tt: formants(f, [(200.0 + 3800.0 * (min(tt, 3.6) / 3.6) ** 2, 400.0 + 1500.0 * min(tt, 3.6) / 3.6, 1.0)]))
	suction *= env_points(n, [(0, 0), (3.55, 1.0), (3.62, 0.0), (4.0, 0)]) ** 1.5
	ghost = np.sin(2 * np.pi * np.cumsum(env_points(n, [(0, 880), (3.6, 220), (4.0, 200)])) / SR) * (0.7 + 0.3 * np.sin(2 * np.pi * 6.0 * t))
	ghost *= env_points(n, [(0, 0), (0.6, 0.2), (3.4, 0.25), (3.6, 0), (4.0, 0)])
	sparkle = np.zeros(n)
	for _ in range(18):
		at = rng.uniform(0.3, 3.4)
		i = int(at * SR)
		sparkle[i:] += bell(n - i, rng.uniform(1800, 3600), 0.25, 0.12)
	x = tear * 0.55 + rips * 0.4 + suction * 0.9 + ghost * 0.2 + sparkle
	return level(space(x, 2.6, 0.32, 4000.0, 1.4), -14.0)


def sfx_chomp():
	"""Les mâchoires de Yiero claquent derrière Simon : aspiration, CLAC d'émail, choc sourd."""
	seconds = 1.6
	n = int(seconds * SR)
	t = np.arange(n) / SR
	pre = stft_filter(noise(n), lambda f, tt: formants(f, [(400.0 + 3000.0 * min(tt, 0.09) / 0.09, 900.0, 1.0)])) * env_points(n, [(0, 0), (0.08, 1.0), (0.095, 0.0), (1.6, 0)])
	hit_at = int(0.09 * SR)
	clack = np.zeros(n)
	clack[hit_at:] = resonator_hit(n - hit_at, [(720, 55, 1.0), (1330, 70, 0.8), (2550, 95, 0.55), (3900, 130, 0.3)], 1.5)
	thud = np.zeros(n)
	thud[hit_at:] = sub_boom(n - hit_at, 72.0, 30.0, 0.3) * 1.3
	squelch = np.zeros(n)
	squelch[hit_at:] = lowpass(noise(n - hit_at), 1200.0) * np.exp(-np.arange(n - hit_at) / (0.12 * SR)) * 0.4
	x = pre * 0.5 + soft(clack, 1.5) * 0.9 + thud + squelch
	return level(space(x, 2.2, 0.3, 3000.0), -9.0)


def sfx_portal():
	"""Le portail de papier se referme : souffle aspiré, « chlop » qui descend, étincelles."""
	seconds = 1.6
	n = int(seconds * SR)
	t = np.arange(n) / SR
	swell = stft_filter(pink(n), lambda f, tt: formants(f, [(1600.0 - 1300.0 * min(tt, 1.1) / 1.1, 700.0, 1.0)])) * env_points(n, [(0, 0), (0.9, 1.0), (1.1, 0.3), (1.6, 0)])
	shloop = np.sin(2 * np.pi * np.cumsum(env_points(n, [(0, 900), (0.95, 900), (1.25, 140), (1.6, 120)])) / SR) * env_points(n, [(0, 0), (0.95, 0), (1.0, 0.6), (1.4, 0), (1.6, 0)])
	pop = np.zeros(n)
	i = int(1.1 * SR)
	pop[i:] = sub_boom(n - i, 90.0, 45.0, 0.12) * 0.8
	sparkle = np.zeros(n)
	for _ in range(10):
		at = rng.uniform(0.1, 1.0)
		j = int(at * SR)
		sparkle[j:] += bell(n - j, rng.uniform(1500, 3000), 0.3, 0.08)
	x = swell * 0.7 + shloop * 0.5 + pop + sparkle
	return level(space(x, 1.8, 0.3, 5000.0, 1.3), -14.0)


def sfx_title():
	"""Le logo en papier claque à l'écran (la musique porte l'impact orchestral)."""
	seconds = 2.2
	n = int(seconds * SR)
	t = np.arange(n) / SR
	flap = bandpass(noise(n), 700.0, 7000.0) * np.exp(-t / 0.05) * np.minimum(1.0, t / 0.002)
	rustle = crackle(n, 260, 1500.0, 8000.0, 0.0, 0.5, lambda u: u ** 2) * 0.4
	thump = sub_boom(n, 80.0, 38.0, 0.25)
	x = flap * 0.8 + rustle + thump
	return level(space(x, 2.4, 0.3, 4000.0), -13.0)


def sfx_ink_step():
	seconds = 0.35
	n = int(seconds * SR)
	t = np.arange(n) / SR
	splat = lowpass(noise(n), 1600.0) * np.exp(-t / 0.035) * np.minimum(1.0, t / 0.004)
	low = sub_boom(n, 120.0, 70.0, 0.04) * 0.4
	drops = droplets(n, 4, 0.03, 0.05, 600.0, 1800.0, 0.3)
	x = splat + low + drops
	return level(stereo(x), -22.0)


SOUNDS = {
	"sfx_roar": sfx_roar, "sfx_laugh": sfx_laugh, "sfx_growl": sfx_growl, "sfx_creak": sfx_creak,
	"sfx_thump": sfx_thump, "sfx_rumble": sfx_rumble, "sfx_splash": sfx_splash, "sfx_slam": sfx_slam,
	"sfx_spike": sfx_spike, "sfx_whoosh": sfx_whoosh, "sfx_ignite": sfx_ignite, "sfx_gold_hit": sfx_gold_hit,
	"sfx_metal": sfx_metal, "sfx_erase": sfx_erase, "sfx_chomp": sfx_chomp, "sfx_portal": sfx_portal,
	"sfx_title": sfx_title, "sfx_ink_step": sfx_ink_step,
}


def write_wav(path, data):
	data = np.clip(data, -1.0, 1.0)
	if data.ndim == 1:
		data = np.stack([data, data], axis=1)
	with wave.open(path, "wb") as w:
		w.setnchannels(2)
		w.setsampwidth(2)
		w.setframerate(SR)
		w.writeframes((data * 32767).astype("<i2").tobytes())


def main():
	args = sys.argv[1:]
	out = OUT
	if "--out" in args:
		k = args.index("--out")
		out = args[k + 1]
		del args[k:k + 2]
	os.makedirs(out, exist_ok=True)
	only = set(args)
	for name, build in SOUNDS.items():
		if only and name not in only:
			continue
		data = build()
		write_wav(os.path.join(out, name + ".wav"), data)
		print("sfx %-14s %4.2f s  RMS court %5.1f dB  crête %5.1f dB" % (name, len(data) / SR, short_rms_db(data), 20 * np.log10(np.max(np.abs(data)) + 1e-9)))


if __name__ == "__main__":
	sys.exit(main())
