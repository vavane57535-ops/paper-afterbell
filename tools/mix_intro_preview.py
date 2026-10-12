#!/usr/bin/env python3
"""Mixage de contrôle du prologue « Yiero » hors du jeu (le serveur de test n'a pas de sortie audio).

Rejoue la bande-son du film aux gains du jeu (réglages par défaut : musique 70 %, effets 100 %) :
musique + bruitages (sfx_*.wav du film et audio/sfx du jeu) + blips de dialogue, et écrit un WAV
stéréo à écouter, plus un relevé de sonie (LUFS momentanés) par événement.

Préparation (dans le dossier du projet) :
  godot --headless -- --tool test_intro --intro-mode audio --intro-out /tmp/x   (feuille audio_sheet.json)
  godot --headless -- --tool test_intro --intro-mode blips --intro-out /tmp/x   (blips du jeu en WAV)
Puis :
  python3 tools/mix_intro_preview.py /tmp/x [--out /tmp/x/prologue_mix.wav] [--report]
(numpy + ffmpeg)
"""
import json
import math
import os
import random
import re
import subprocess
import sys
import wave

import numpy as np

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def constant(path, name, default):
	text = open(os.path.join(ROOT, path), encoding="utf-8").read()
	match = re.search(r"const %s: float = ([\d.]+)" % name, text)
	return float(match.group(1)) if match else default


def voice_lengths():
	text = open(os.path.join(ROOT, "intro_overlay.gd"), encoding="utf-8").read()
	return {m.group(1): float(m.group(2)) for m in re.finditer(r'"(\w+)": \[[\d.]+, ([\d.]+), "', text)}


def volume_db(value):
	if value <= 0.001:
		return -80.0
	value = min(value, 1.0)
	return 20.0 * math.log10(value) * (2.0 - value)


def read_wav(path):
	with wave.open(path) as w:
		channels, rate, width = w.getnchannels(), w.getframerate(), w.getsampwidth()
		raw = w.readframes(w.getnframes())
	if width == 2:
		data = np.frombuffer(raw, dtype="<i2").astype(np.float64) / 32768.0
	else:
		data = np.frombuffer(raw, dtype=np.uint8).astype(np.float64) / 128.0 - 1.0
	data = data.reshape(-1, channels)
	if channels == 1:
		data = np.repeat(data, 2, axis=1)
	if rate != SR:
		index = np.arange(0, len(data), rate / SR)
		data = np.stack([np.interp(index, np.arange(len(data)), data[:, c]) for c in range(2)], axis=1)
	return data


def decode(path):
	raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", "2", "-ar", str(SR), "-f", "f32le", "-"], capture_output=True, check=True).stdout
	return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).astype(np.float64)


def place(target, at, sound, gain, pitch=1.0):
	if pitch != 1.0:
		index = np.arange(0, len(sound) - 1, pitch)
		sound = np.stack([np.interp(index, np.arange(len(sound)), sound[:, c]) for c in range(2)], axis=1)
	i = int(at * SR)
	j = min(len(target), i + len(sound))
	if i < len(target):
		target[i:j] += sound[:j - i] * gain


def write(path, data):
	with wave.open(path, "wb") as w:
		w.setnchannels(2)
		w.setsampwidth(2)
		w.setframerate(SR)
		w.writeframes((np.clip(data, -1.0, 1.0) * 32767).astype("<i2").tobytes())


def momentary(path):
	err = subprocess.run(["ffmpeg", "-nostats", "-i", path, "-af", "ebur128", "-f", "null", "-"], capture_output=True, text=True).stderr
	rows = [(float(m.group(1)), float(m.group(2)) if m.group(2) != "-inf" else -120.0) for m in re.finditer(r"t:\s*([\d.]+)\s+TARGET.*?M:\s*(-?[\d.]+|-inf)", err)]
	return np.array([r[0] for r in rows]), np.array([r[1] for r in rows])


def main():
	args = sys.argv[1:]
	if not args:
		print(__doc__)
		return 1
	folder = args[0]
	out = args[args.index("--out") + 1] if "--out" in args else os.path.join(folder, "prologue_mix.wav")
	sheet = json.load(open(os.path.join(folder, "audio_sheet.json"), encoding="utf-8"))
	music_gain = 10 ** (volume_db(0.7) / 20.0) * constant("audio.gd", "MUSIC_LEVEL", 0.82)
	sfx_level = constant("film_intro_yiero.gd", "FILM_SFX_LEVEL", 1.0)
	voice_gain = constant("intro_overlay.gd", "VOICE_GAIN", 0.6)
	yiero_gain = constant("intro_overlay.gd", "YIERO_GAIN", 0.9)
	shout_gain = constant("intro_overlay.gd", "SHOUT_GAIN", 1.25)
	lengths = voice_lengths()
	music = decode(os.path.join(ROOT, "audio/cinematic/intro_yiero.ogg")) * music_gain
	stems = {"musique": music, "bruitages": np.zeros_like(music), "voix": np.zeros_like(music)}
	families = set(name.rsplit("_", 1)[0] for name in os.listdir(os.path.join(ROOT, "audio/sfx")) if name.endswith(".wav"))
	cache = {}
	for cue in sheet["sfx"]:
		name, gain, pitch = cue["name"], cue["gain"], cue["pitch"]
		path = os.path.join(ROOT, "audio/cinematic", name + ".wav")
		if os.path.exists(path):
			gain *= sfx_level if name.startswith("sfx_") else 1.0
		elif name in families:
			path = os.path.join(ROOT, "audio/sfx", name + "_00.wav")
			gain *= 0.8
		else:
			path = os.path.join(ROOT, "audio/sfx", name + ".wav")
		if not os.path.exists(path):
			print("bruitage introuvable :", name)
			continue
		if path not in cache:
			cache[path] = read_wav(path)
		place(stems["bruitages"], cue["t"], cache[path], gain, pitch)
	rng = random.Random(7)
	blips = {}
	last = {}
	for blip in sheet["blips"]:
		who = blip["who"]
		if who not in blips:
			blips[who] = [read_wav(os.path.join(folder, "blip_%s_%d.wav" % (who, k))) for k in range(4)]
		if blip["t"] - last.get(who, -9.0) < lengths.get(who, 0.04) * 0.75:
			continue
		last[who] = blip["t"]
		gain = (yiero_gain if who == "Yiero" else voice_gain) * (shout_gain if blip.get("shout") else 1.0)
		place(stems["voix"], blip["t"], blips[who][rng.randrange(4)], gain)
	mix = stems["musique"] + stems["bruitages"] + stems["voix"]
	ceiling = 10 ** (-1.2 / 20.0)
	print("échantillons au-dessus du limiteur (-1,2 dBFS) : %d" % int((np.abs(mix) > ceiling).any(axis=1).sum()))
	write(out, np.clip(mix, -ceiling, ceiling))
	print("mixage écrit :", out)
	if "--report" not in args:
		return 0
	series = {}
	for label, data in stems.items():
		path = out[:-4] + "_" + label + ".wav"
		write(path, data)
		series[label] = momentary(path)

	def peak(label, t0, t1):
		t, m = series[label]
		sel = (t >= t0) & (t <= t1)
		return float(m[sel].max()) if sel.any() else -120.0

	print("%-16s %7s  %8s %9s %6s" % ("bruitage", "t", "musique", "bruitage", ""))
	for cue in sorted(sheet["sfx"], key=lambda c: c["t"]):
		print("%-16s %7.2f  %8.1f %9.1f" % (cue["name"][:16], cue["t"], peak("musique", cue["t"], cue["t"] + 0.8), peak("bruitages", cue["t"], cue["t"] + 0.8)))
	for line in sheet["lines"]:
		print("%-9s %7.2f  musique %6.1f  voix %6.1f  « %s »" % (line["who"], line["t"], peak("musique", line["t"], line["typed"]), peak("voix", line["t"], line["typed"]), line["text"][:44]))
	return 0


if __name__ == "__main__":
	sys.exit(main())
