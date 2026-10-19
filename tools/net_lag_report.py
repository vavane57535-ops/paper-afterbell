#!/usr/bin/env python3
"""Analyse des journaux de tools/test_net_lag.gd (host.json + client.json d'un même dossier).

Mesures :
  * écart instantané : à la même heure murale, distance entre la hitbox de l'hôte et la position
    que le client affiche pour lui-même, et décalage temporel qui aligne au mieux les deux ;
  * écart de jugement : position que l'hôte utilise pour juger un coup porté à l'instant H, contre
    la position que le client voyait de lui-même quand son écran montrait H ;
  * réactivité : délai entre l'appui (départ arrêté) et le premier mouvement affiché chez le
    client, et le premier mouvement de la hitbox chez l'hôte ;
  * esquives : verdict de l'hôte contre ce que montrait l'écran du client ;
  * débit : octets par seconde mesurés par ENet chez l'hôte et par le relais.
"""
import argparse
import bisect
import json
import math
import os
import sys


def stats(values):
	values = sorted(v for v in values if v is not None and not math.isnan(v))
	if not values: return {"n": 0}
	return {"n": len(values), "mean": sum(values) / len(values), "p50": values[len(values) // 2], "p95": values[min(len(values) - 1, int(len(values) * 0.95))], "max": values[-1]}


def fmt(s, unit="", scale=1.0):
	if s.get("n", 0) == 0: return "n=0"
	return "moy %.*f%s · méd %.*f · p95 %.*f · max %.*f (n=%d)" % (
		2 if scale == 1.0 else 0, s["mean"] * scale, unit, 2 if scale == 1.0 else 0, s["p50"] * scale,
		2 if scale == 1.0 else 0, s["p95"] * scale, 2 if scale == 1.0 else 0, s["max"] * scale, s["n"])


class Series:
	"""Série temporelle (temps croissants) avec interpolation linéaire."""

	def __init__(self, times, values):
		pairs = sorted(zip(times, values), key=lambda p: p[0])
		self.t = [p[0] for p in pairs]
		self.v = [p[1] for p in pairs]

	def at(self, t):
		if not self.t or t < self.t[0] or t > self.t[-1]: return None
		i = bisect.bisect_right(self.t, t)
		if i >= len(self.t): return self.v[-1]
		if i == 0: return self.v[0]
		t0, t1 = self.t[i - 1], self.t[i]
		u = 0.0 if t1 <= t0 else (t - t0) / (t1 - t0)
		a, b = self.v[i - 1], self.v[i]
		if isinstance(a, tuple): return tuple(x + (y - x) * u for x, y in zip(a, b))
		return a + (b - a) * u


def flat(a, b):
	return math.hypot(a[0] - b[0], a[-1] - b[-1])


def main():
	parser = argparse.ArgumentParser()
	parser.add_argument("folder")
	parser.add_argument("--ping", default="?")
	parser.add_argument("--jitter", default="?")
	parser.add_argument("--label", default="")
	parser.add_argument("--json", default="")
	args = parser.parse_args()
	try:
		host = json.load(open(os.path.join(args.folder, "host.json")))
		client = json.load(open(os.path.join(args.folder, "client.json")))
	except (OSError, ValueError) as error:
		print("RAPPORT IMPOSSIBLE :", error)
		sys.exit(1)
	marks = host.get("marks", {})
	track = marks.get("track", [0, 0])
	result = {"label": args.label, "ping_ms": args.ping, "jitter_ms": args.jitter}

	ticks = host["ticks"]
	body = Series([r[0] for r in ticks], [(r[2], r[3], r[4]) for r in ticks])
	body_by_clock = Series([r[1] for r in ticks], [(r[2], r[3], r[4]) for r in ticks])
	clock_to_wall = Series([r[1] for r in ticks], [r[0] for r in ticks])
	frames = client["frames"]
	shown = Series([f[0] for f in frames], [(f[1], f[2], f[3]) for f in frames])

	# 1. Écart instantané (même heure murale) pendant le zigzag.
	window = [r for r in ticks if track[0] + 0.5 <= r[0] <= track[-1] - 0.3]
	gaps = []
	for r in window:
		d = shown.at(r[0])
		if d is not None: gaps.append(flat((r[2], r[3], r[4]), d))
	best = None
	for shift_ms in range(-400, 401, 5):
		s = shift_ms / 1000.0
		err = []
		for r in window[::3]:
			d = shown.at(r[0] + s)
			if d is not None: err.append(flat((r[2], r[3], r[4]), d))
		if err:
			m = sum(err) / len(err)
			if best is None or m < best[1]: best = (shift_ms, m)
	result["instant_gap_m"] = stats(gaps)
	result["instant_shift_ms"] = best[0] if best else None

	# 2. Écart de jugement : l'hôte juge un coup porté à l'instant H avec J(H) ; le client se voyait
	#    en D quand son écran montrait H (t_view mesuré si disponible, sinon estimé : dernier
	#    instantané reçu − 55 ms de lissage, ce que faisait l'ancien code).
	has_view = any(f[7] >= 0 for f in frames)
	view = Series([f[7] if f[7] >= 0 else f[8] - 0.055 for f in frames], [f[0] for f in frames]) if frames else None
	judged_rows = host.get("judged", [])
	if judged_rows:
		judged = [(j[0], (j[1], j[2], j[3])) for j in judged_rows]
		result["judge_source"] = "compensation (own_view_at)"
	else:
		judged = [(r[1], (r[2], r[3], r[4])) for r in ticks]
		result["judge_source"] = "hitbox de l'hôte"
	jgaps = []
	for h, p in judged:
		w_h = clock_to_wall.at(h)
		if w_h is None or not (track[0] + 0.5 <= w_h <= track[-1] - 0.3): continue
		# Le moment où l'écran du client montrait H.
		w = view.at(h) if view else None
		if w is None: continue
		d = shown.at(w)
		if d is not None: jgaps.append(flat(p, d))
	result["judge_gap_m"] = stats(jgaps)
	result["view_time"] = "mesuré (t_view)" if has_view else "estimé"

	# 3. Réactivité.
	delays = [r["delay_ms"] for r in client.get("reactions", []) if r.get("delay_ms", -1) >= 0]
	host_delays = []
	for r in client.get("reactions", []):
		press = r["pressed"]
		start = body.at(press)
		if start is None: continue
		for t in ticks:
			if t[0] < press: continue
			if flat((t[2], t[3], t[4]), start) > 0.03:
				host_delays.append((t[0] - press) * 1000.0)
				break
	result["input_to_screen_ms"] = stats(delays)
	result["input_to_hitbox_ms"] = stats(host_delays)

	# 4. Esquives.
	host_trials = {int(t["index"]): t for t in host.get("trials", [])}
	rows = []
	counts = {"injuste": 0, "juste_touche": 0, "genereux": 0, "juste_rate": 0, "temoin_touche": 0, "temoin_rate": 0, "inconnu": 0}
	for ct in client.get("trials", []):
		ht = host_trials.get(int(ct["index"]))
		if ht is None: continue
		inside = bool(ct.get("inside")) if float(ct.get("seen", -1)) > 0 else None
		hit = bool(ht.get("hit"))
		if not ht.get("dodge", True): kind = "temoin_touche" if hit else "temoin_rate"
		elif inside is None: kind = "inconnu"
		elif not inside and hit: kind = "injuste"
		elif inside and hit: kind = "juste_touche"
		elif inside and not hit: kind = "genereux"
		else: kind = "juste_rate"
		counts[kind] += 1
		rows.append((float(ht["delay"]), bool(ht.get("dodge")), hit, inside, kind, ct.get("min_lateral")))
	result["dodges"] = counts

	# 5. Débit.
	result["enet_host"] = host.get("net", {})
	try:
		result["proxy"] = json.load(open(os.path.join(args.folder, "proxy.json")))
	except (OSError, ValueError):
		result["proxy"] = {}

	print("=== %s · ping %s ms · jitter %s ms ===" % (args.label, args.ping, args.jitter))
	print("Écart instantané hitbox/écran (m) :", fmt(result["instant_gap_m"]), "· décalage optimal %s ms" % result["instant_shift_ms"])
	print("Écart de jugement (m) [%s, temps d'écran %s] :" % (result["judge_source"], result["view_time"]), fmt(result["judge_gap_m"]))
	print("Appui → mouvement à l'écran (ms) :", fmt(result["input_to_screen_ms"], scale=1.0))
	print("Appui → mouvement de la hitbox (ms) :", fmt(result["input_to_hitbox_ms"], scale=1.0))
	print("Esquives :", ", ".join("%s=%d" % kv for kv in counts.items()))
	for d, dodge, hit, inside, kind, lateral in sorted(rows):
		print("  δ=%.2f %s → hôte %s · écran %s · %s (écart latéral min %.2f m)" % (d, "esquive" if dodge else "témoin ", "TOUCHÉ" if hit else "raté  ", "dedans" if inside else "dehors" if inside is not None else "?", kind, float(lateral) if lateral not in (None, "inf") and lateral != float("inf") else -1))
	net = result["enet_host"]
	if net:
		print("ENet hôte : envoi %.0f o/s (%.0f paquets/s), réception %.0f o/s (%.0f paquets/s)" % (net.get("sent_bytes_per_s", 0), net.get("sent_packets_per_s", 0), net.get("received_bytes_per_s", 0), net.get("received_packets_per_s", 0)))
	proxy = result["proxy"]
	if proxy:
		print("Relais (toute la session) : hôte→client %.0f o/s · %.1f paquets/s · moy %.0f o ; client→hôte %.0f o/s · %.1f paquets/s · moy %.0f o" % (
			proxy["down"]["payload_bytes_per_s"], proxy["down"]["packets_per_s"], proxy["down"]["mean_payload"],
			proxy["up"]["payload_bytes_per_s"], proxy["up"]["packets_per_s"], proxy["up"]["mean_payload"]))
	if args.json:
		with open(args.json, "w") as handle: json.dump(result, handle, indent=1)
	else:
		with open(os.path.join(args.folder, "summary.json"), "w") as handle: json.dump(result, handle, indent=1)


if __name__ == "__main__":
	main()
