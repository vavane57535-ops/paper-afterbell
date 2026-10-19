#!/usr/bin/env python3
"""Analyse des journaux de tools/test_net_lag.gd (host.json + client.json d'un même dossier).

Mesures :
  * écart instantané : à la même heure murale, distance entre la hitbox de l'hôte et la position
    que le client affiche pour lui-même, et décalage temporel qui aligne au mieux les deux ;
  * écart de jugement : position que l'hôte utilise pour juger un coup porté à l'instant H, contre
    la position que le client voyait de lui-même quand son écran montrait H ;
  * fluidité : indice d'à-coups de chaque mouvement, à la source et chez l'autre machine, mesuré
    à chaque pas physique (base de temps régulière) ;
  * réactivité : délai entre l'appui (départ arrêté) et le premier mouvement affiché chez le
    client, et le premier mouvement de la hitbox chez l'hôte ;
  * recalage : l'hôte étourdit le client en pleine course ; recul vu par le client et plus grand
    saut d'une image à l'autre ;
  * esquives : verdict de l'hôte contre ce que montrait l'écran du client ;
  * client modifié (--lag-cheat) : vitesse de la hitbox, téléportation, mur, fausses esquives ;
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


def stutter(times, points):
	"""À-coups d'une trajectoire : écart moyen entre la vitesse pas à pas et sa médiane glissante
	(7 pas), rapporté à la vitesse moyenne. 0 = mouvement parfaitement régulier. Les temps doivent
	être réguliers (pas physiques) : une heure murale relevée à chaque image compte aussi les
	irrégularités de la machine de test."""
	rows = list(zip(times, points))
	speeds = []
	for (t0, p0), (t1, p1) in zip(rows, rows[1:]):
		if t1 - t0 > 1e-4: speeds.append(flat(p0, p1) / (t1 - t0))
	if len(speeds) < 10: return None
	devs = []
	moving = []
	for i in range(3, len(speeds) - 3):
		window = sorted(speeds[i - 3:i + 4])
		med = window[3]
		if med < 1.0: continue
		devs.append(abs(speeds[i] - med))
		moving.append(med)
	if not moving: return None
	return {"index": sum(devs) / len(devs) / (sum(moving) / len(moving)), "mean_speed": sum(moving) / len(moving), "n": len(devs)}


def window_rows(rows, wcol, w0, w1):
	return [r for r in rows if w0 <= r[wcol] <= w1]


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
	result = {"label": args.label, "ping_ms": args.ping, "jitter_ms": args.jitter}
	ticks = host["ticks"]
	frames = client["frames"]
	cticks = client.get("ticks", [])
	body = Series([r[0] for r in ticks], [(r[2], r[3], r[4]) for r in ticks])
	clock_to_wall = Series([r[1] for r in ticks], [r[0] for r in ticks])
	shown = Series([f[0] for f in frames], [(f[1], f[2], f[3]) for f in frames])
	print("=== %s · ping %s ms · jitter %s ms%s ===" % (args.label, args.ping, args.jitter, " · CLIENT MODIFIÉ" if host.get("cheat") else ""))

	if "track" in marks and len(marks["track"]) > 1 and marks["track"][-1] - marks["track"][0] > 2:
		track = marks["track"]
		w0, w1 = track[0] + 0.5, track[-1] - 0.3
		# 1. Écart instantané (même heure murale) pendant le zigzag.
		window = [r for r in ticks if w0 <= r[0] <= w1]
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
		# Retard d'affichage des autres : Alice (simulée par l'hôte) telle que le client la dessine.
		alice_shown = Series([f[0] for f in frames], [(f[4], 0.0, f[5]) for f in frames])
		best_alice = None
		for shift_ms in range(0, 401, 5):
			s = shift_ms / 1000.0
			err = []
			for r in window[::3]:
				d = alice_shown.at(r[0] + s)
				if d is not None: err.append(flat((r[5], 0.0, r[6]), d))
			if err:
				m = sum(err) / len(err)
				if best_alice is None or m < best_alice[1]: best_alice = (shift_ms, m)
		result["others_delay_ms"] = best_alice[0] if best_alice else None
		# 2. Écart de jugement : l'hôte juge un coup porté à l'instant H avec J(H) ; le client se
		#    voyait en D quand son écran montrait H (t_view mesuré si disponible, sinon estimé :
		#    dernier instantané reçu − 55 ms de lissage, ce que faisait l'ancien code).
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
			if w_h is None or not (w0 <= w_h <= w1): continue
			w = view.at(h) if view else None
			if w is None: continue
			d = shown.at(w)
			if d is not None: jgaps.append(flat(p, d))
		result["judge_gap_m"] = stats(jgaps)
		result["view_time"] = "mesuré (t_view)" if has_view else "estimé"
		print("Écart instantané hitbox/écran (m) :", fmt(result["instant_gap_m"]), "· décalage optimal %s ms (négatif = la hitbox suit l'écran du client)" % result["instant_shift_ms"])
		print("Écart de jugement (m) [%s, temps d'écran %s] :" % (result["judge_source"], result["view_time"]), fmt(result["judge_gap_m"]))
		print("Retard d'affichage des autres acteurs chez le client (aller simple + tampon d'interpolation) : %s ms" % result["others_delay_ms"])
		# 1 bis. Fluidité, mesurée à chaque pas physique.
		smooth = {}
		hw = window_rows(ticks, 0, w0, w1)
		smooth["alice_host"] = stutter([r[1] for r in hw], [(r[5], 0.0, r[6]) for r in hw])
		smooth["client_on_host"] = stutter([r[1] for r in hw], [(r[2], r[3], r[4]) for r in hw])
		if cticks:
			cw = window_rows(cticks, 9, w0, w1)
			smooth["client_own"] = stutter([r[0] for r in cw], [(r[1], r[2], r[3]) for r in cw])
			smooth["alice_on_client"] = stutter([r[0] for r in cw], [(r[4], 0.0, r[5]) for r in cw])
		result["smoothness"] = smooth
		def show(key):
			value = smooth.get(key)
			return "%.3f" % value["index"] if value else "n/a"
		print("Fluidité (indice d'à-coups par pas physique, 0 = parfait) : Alice chez l'hôte %s → chez le client %s ; client chez lui %s → chez l'hôte %s" % (show("alice_host"), show("alice_on_client"), show("client_own"), show("client_on_host")))
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
		print("Appui → mouvement à l'écran (ms) :", fmt(result["input_to_screen_ms"]))
		print("Appui → mouvement de la hitbox chez l'hôte (ms) :", fmt(result["input_to_hitbox_ms"]))

	# 3 bis. Recalage : l'hôte étourdit le client en pleine course.
	stuns = host.get("stuns", [])
	if stuns and cticks:
		rows = []
		for s in stuns:
			sign = 1.0 if s["side"] == "right" else -1.0
			detect = next((r for r in cticks if r[9] >= s["at"] - 0.05 and r[10] == 1), None)
			if detect is None: continue
			t0 = detect[9]
			# Ce que montre l'écran (positions rendues, images réelles).
			# Pas physiques du corps affiché (base de temps régulière : les images de la machine de test
			# arrivent irrégulièrement sous la charge).
			seq = [(r[9], r[1] * sign) for r in cticks if t0 - 0.05 <= r[9] <= t0 + 0.7]
			if len(seq) < 5: continue
			start_x = next((x for t, x in seq if t >= t0), seq[0][1])
			low = min(x for _, x in seq)
			steps_back = [a[1] - b[1] for a, b in zip(seq, seq[1:])]
			host_x = s["host_pos"][0] * sign
			reach = next((t for t, x in seq if x <= low + 0.1 * (start_x - low)), seq[-1][0])
			rows.append({"pullback_m": start_x - low, "max_back_step_m": max(steps_back), "settle_ms": (reach - t0) * 1000.0, "final_vs_host_m": abs(low - host_x)})
		if rows:
			result["stun_corrections"] = rows
			print("Recalage (étourdi en pleine course, l'hôte reprend la main) : recul %s m · plus grand pas arrière par pas physique %s m (un pas de course = 0,17 m) · stabilisé en %s ms · écart entre le point d'arrêt et la position de l'hôte %s m" % (
				"/".join("%.2f" % r["pullback_m"] for r in rows), "/".join("%.3f" % r["max_back_step_m"] for r in rows),
				"/".join("%.0f" % r["settle_ms"] for r in rows), "/".join("%.2f" % r["final_vs_host_m"] for r in rows)))
		# Reprise de la prédiction à la fin de l'étourdissement : plus grand pas physique juste après.
		resume_steps = []
		for i in range(1, len(cticks)):
			a, b = cticks[i - 1], cticks[i]
			if a[8] == 0 and b[8] == 1 and any(s["at"] <= b[9] <= s["at"] + 2.0 for s in stuns):
				seq = cticks[i - 1:i + 18]
				resume_steps.append(max(flat((p[1], p[3]), (q[1], q[3])) for p, q in zip(seq, seq[1:])))
		if resume_steps:
			result["resume_max_step_m"] = resume_steps
			print("Reprise de la prédiction après l'étourdissement : plus grand pas physique %s m (un pas de course = 0,17 m)" % "/".join("%.3f" % v for v in resume_steps))

	# 4. Esquives.
	host_trials = {int(t["index"]): t for t in host.get("trials", [])}
	rows = []
	counts = {"injuste": 0, "juste_touche": 0, "genereux": 0, "juste_rate": 0, "temoin_touche": 0, "temoin_rate": 0, "triche_touche": 0, "triche_ratee": 0, "inconnu": 0}
	for ct in client.get("trials", []):
		ht = host_trials.get(int(ct["index"]))
		if ht is None: continue
		inside = bool(ct.get("inside")) if float(ct.get("seen", -1)) > 0 else None
		hit = bool(ht.get("hit"))
		if ht.get("cheat"): kind = "triche_touche" if hit else "triche_ratee"
		elif not ht.get("dodge", True): kind = "temoin_touche" if hit else "temoin_rate"
		elif inside is None: kind = "inconnu"
		elif not inside and hit: kind = "injuste"
		elif inside and hit: kind = "juste_touche"
		elif inside and not hit: kind = "genereux"
		else: kind = "juste_rate"
		counts[kind] += 1
		rows.append((float(ht["delay"]), "triche " if ht.get("cheat") else "esquive" if ht.get("dodge") else "témoin ", hit, inside, kind, ct.get("min_lateral")))
	result["dodges"] = counts
	print("Esquives :", ", ".join("%s=%d" % kv for kv in counts.items() if kv[1] or kv[0] in ("injuste", "juste_rate")))
	for d, what, hit, inside, kind, lateral in sorted(rows):
		print("  δ=%.2f %s → hôte %s · écran %s · %s (écart latéral min %.2f m)" % (d, what, "TOUCHÉ" if hit else "raté  ", "dedans" if inside else "dehors" if inside is not None else "?", kind, float(lateral) if lateral is not None and float(lateral) < 98 else -1))

	# 5. Client modifié.
	cheats = host.get("cheats", {})
	if host.get("cheat"):
		result["cheats"] = cheats
		span = marks.get("cheat_speed", [])
		if len(span) > 1:
			hw = [r for r in ticks if span[0] + 0.3 <= r[0] <= span[-1]]
			host_speeds = []
			for a, b in zip(hw, hw[6:]):
				dt = b[1] - a[1]
				if dt > 1e-3: host_speeds.append(math.hypot(b[2] - a[2], b[4] - a[4]) / dt)
			cw = [r for r in cticks if span[0] + 0.3 <= r[9] <= span[-1]]
			claimed = []
			for a, b in zip(cw, cw[6:]):
				dt = b[0] - a[0]
				if dt > 1e-3: claimed.append(math.hypot(b[1] - a[1], b[3] - a[3]) / dt)
			result["cheat_speed"] = {"host_max": max(host_speeds) if host_speeds else None, "client_max": max(claimed) if claimed else None}
			print("Vitesse doublée : le client se voit à %.1f m/s au plus ; sa hitbox chez l'hôte %.1f m/s au plus (sprint normal 8,5, limite permise 1,2 × vitesse + 0,6) · refus %s" % (
				max(claimed) if claimed else -1, max(host_speeds) if host_speeds else -1, cheats.get("speed_rejections")))
		if "tp_max_move" in cheats:
			print("Téléportation de 3 m : la hitbox chez l'hôte a bougé de %.2f m au plus · refus %s" % (cheats["tp_max_move"], cheats.get("tp_rejections")))
		if "wall_max_depth" in cheats:
			print("Téléportation à travers un mur (épaisseur %.2f m) : la hitbox chez l'hôte est restée à %.2f m devant la face du mur (négatif = de ce côté) · refus %s" % (
				float(cheats.get("wall", {}).get("thickness", -1)), cheats["wall_max_depth"], cheats.get("wall_rejections")))

	motion = host.get("motion", {})
	if motion:
		result["motion"] = motion
		print("Suivi hôte : refus=%s recalages=%s tampon anti-jitter=%.0f ms retard d'écran du client=%.0f ms · coups jugés : %s" % (motion.get("rejections"), motion.get("resyncs"), float(motion.get("delay") or 0) * 1000, float(motion.get("view_lag") or 0) * 1000, motion.get("lag", {})))
		if motion.get("sync"): print("Messages : %s" % motion["sync"])

	# 6. Débit.
	result["enet_host"] = host.get("net", {})
	try:
		result["proxy"] = json.load(open(os.path.join(args.folder, "proxy.json")))
	except (OSError, ValueError):
		result["proxy"] = {}
	net = result["enet_host"]
	if net:
		print("ENet hôte : envoi %.0f o/s (%.0f paquets/s), réception %.0f o/s (%.0f paquets/s)" % (net.get("sent_bytes_per_s", 0), net.get("sent_packets_per_s", 0), net.get("received_bytes_per_s", 0), net.get("received_packets_per_s", 0)))
	proxy = result["proxy"]
	if proxy:
		print("Relais (toute la session) : hôte→client %.0f o/s · %.1f paquets/s · moy %.0f o ; client→hôte %.0f o/s · %.1f paquets/s · moy %.0f o" % (
			proxy["down"]["payload_bytes_per_s"], proxy["down"]["packets_per_s"], proxy["down"]["mean_payload"],
			proxy["up"]["payload_bytes_per_s"], proxy["up"]["packets_per_s"], proxy["up"]["mean_payload"]))
	with open(args.json or os.path.join(args.folder, "summary.json"), "w") as handle: json.dump(result, handle, indent=1)


if __name__ == "__main__":
	main()
