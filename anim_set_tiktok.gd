extends "res://anim_pose.gd"

# Danses 0.16 inspirées des tendances TikTok 2025-2026. Les clés sont en temps musicaux
# (beats) puis converties en secondes au BPM de la musique : la boucle d'animation dure un
# nombre entier de mesures et la musique un multiple de cette durée (synchro parfaite).

static func add(c: Dictionary) -> void :
	_sixseven(c)
	_pikki(c)
	_anxiety(c)
	_grrr(c)
	_chicken(c)
	_golden(c)
	_funk(c)
	_amapiano(c)
	_retro(c)
	_baby(c)

static func _beats(bpm: float, keys: Array) -> Array:
	var out: Array = []
	for key: Array in keys:
		var copy: Array = key.duplicate()
		copy[0] = float(key[0]) * 60.0 / bpm
		out.append(copy)
	return out

static func _dance(bpm: float, beats: float, face: String, keys: Array) -> Dictionary:
	return {"len": beats * 60.0 / bpm, "loop": true, "in": 0.15, "face": face, "keys": _beats(bpm, keys)}

static func _sh(up: float, fwd: float = 0.0) -> Dictionary:
	return {"l_clav": V(0.0, - fwd, - up), "r_clav": V(0.0, fwd, up)}

static func _base() -> Dictionary:
	return M([rest(), _sh(0.0), {"curl": 0.4, "curl_l": 0.4, "gesture": "", "jaw": 0.0, "shake": 0.0}])



# 6-7 (Skrilla, « Doot Doot », 2025) : paumes vers le ciel qui montent et descendent en
# balance (« six… seven »), rebond drill sur chaque temps, puis pas de côté drill.
static func _sixseven(c: Dictionary) -> void :
	var bpm: float = 144.0
	var keys: Array = []
	for b: int in range(8):
		var up: float = 1.0 if b % 2 == 0 else -1.0
		var tilt: float = 0.14 * up
		keys.append([float(b), M([_base(), _sev(up, 0.1, tilt), {"sq": 0.97}]), "s"])
		keys.append([float(b) + 0.5, M([_base(), _sev(up * 0.6, 0.0, tilt * 0.6), {"sq": 1.01}])])
	for b: int in range(8, 12):
		var side: float = 1.0 if b % 2 == 0 else -1.0
		keys.append([float(b), M([_base(), _drill_step(side, 0.12)]), "s"])
		keys.append([float(b) + 0.5, M([_base(), _drill_step(side * 0.4, 0.02)])])
	keys.append([12.0, M([_base(), _six_point(1.0)]), "s"])
	keys.append([12.5, M([_base(), _six_point(0.8)])])
	keys.append([13.0, M([_base(), _six_point(-1.0)]), "s"])
	keys.append([13.5, M([_base(), _six_point(-0.8)])])
	keys.append([14.0, M([_base(), _sev(1.0, 0.16, 0.18), _sh(0.25), {"sq": 0.96}]), "s"])
	keys.append([14.5, M([_base(), _sev(-1.0, 0.04, -0.18), _sh(0.25)])])
	keys.append([15.0, M([_base(), _sev(1.0, 0.16, 0.18), _sh(0.25), {"sq": 0.96}]), "s"])
	keys.append([15.5, M([_base(), _sev(-0.4, 0.04, -0.06), _sh(0.05)])])
	keys.append([16.0, keys[0][1], "s"])
	c["dance_sixseven"] = _dance(bpm, 16.0, "calm", keys)

static func _sev(balance: float, dip: float, tilt: float) -> Dictionary:
	var palm_l: Dictionary = WL(0.25, 1.55, 0.0)
	var palm_r: Dictionary = WR(0.25, -1.55, 0.0)
	return M([FL(0.16, 0.02), FR(0.16, -0.02), H(0.04 * balance, - dip, 0.0), B(0.08, 0.06 * balance, 0.05 * balance), C(0.04, 0.05 * balance, 0.04 * balance), HD(-0.02, -0.08 * balance, - tilt),
		Lt(0.3, -0.32 + 0.24 * balance, 0.62, 0.3), Rt(0.3, -0.32 - 0.24 * balance, 0.62, 0.3), palm_l, palm_r,
		{"curl": 0.12, "curl_l": 0.12, "fp_l": 0.0, "fp_r": 0.0}])

static func _drill_step(side: float, dip: float) -> Dictionary:
	return M([FL(0.16 + 0.1 * maxf(side, 0.0), 0.08 * side), FR(0.16 + 0.1 * maxf(- side, 0.0), -0.08 * side), H(-0.1 * side, - dip, 0.0), B(0.16, 0.22 * side, 0.0), C(0.06, 0.18 * side, -0.05 * side), HD(0.05, -0.25 * side, 0.08 * side),
		L(0.35, -0.72, 0.25 + 0.3 * side, 0.4), R(0.35, -0.72, 0.25 - 0.3 * side, 0.4), WL(0.0), WR(0.0), {"curl": 0.7, "curl_l": 0.7, "fp_l": -0.3 * maxf(- side, 0.0), "fp_r": -0.3 * maxf(side, 0.0), "sq": 1.0 - dip * 0.3}])

static func _six_point(side: float) -> Dictionary:
	return M([FL(0.18, 0.05), FR(0.18, -0.05), H(0.05 * side, -0.1, 0.0), B(0.1, -0.15 * side, 0.0), C(0.08, -0.12 * side, 0.0), HD(0.0, 0.2 * side, 0.0),
		R(0.1 + 0.25 * side, 0.05, 0.9, 0.2), L(0.1 - 0.25 * side, 0.0, 0.9, 0.2), WR(0.0), WL(0.0), {"gesture": "point_both", "curl": 1.0, "curl_l": 1.0, "fp_l": 0.0, "fp_r": 0.0, "sq": 0.98}])



# Pikki Pikki (pom-pom girls des Kia Tigers, 2024-2025) : l'air blasé, puis d'un coup les deux
# pouces levés montent et descendent en alternance, hanches qui balancent.
static func _pikki(c: Dictionary) -> void :
	var bpm: float = 130.0
	var keys: Array = []
	keys.append([0.0, M([_base(), _bored(0.0)])])
	keys.append([1.0, M([_base(), _bored(1.0)])])
	keys.append([1.75, M([_base(), _pk(0.0, 0.0, 0.0), {"sq": 0.96}]), "s"])
	for k: int in range(18):
		var beat: float = 2.0 + float(k) * 0.5
		var side: float = 1.0 if k % 2 == 0 else -1.0
		var turn: float = 0.0
		if beat >= 6.0 and beat < 10.0: turn = 0.35 if int(beat / 2.0) % 2 == 1 else -0.35
		keys.append([beat, M([_base(), _pk(side, 1.0 if k % 2 == 0 else 0.4, turn)]), "s" if k % 2 == 0 else ""])
	keys.append([11.0, M([_base(), _pk_down(1.0)]), "s"])
	keys.append([11.5, M([_base(), _pk_down(0.5)])])
	keys.append([12.0, M([_base(), _pk_down(1.0)]), "s"])
	keys.append([12.5, M([_base(), _pk_down(0.5)])])
	for k: int in range(4):
		var beat2: float = 13.0 + float(k) * 0.5
		var side2: float = 1.0 if k % 2 == 0 else -1.0
		keys.append([beat2, M([_base(), _pk(side2, 1.0 if k % 2 == 0 else 0.4, 0.0)]), "s" if k % 2 == 0 else ""])
	keys.append([15.0, M([_base(), _bored(0.5), {"face": "calm"}]), "s"])
	keys.append([16.0, keys[0][1]])
	c["dance_pikki"] = _dance(bpm, 16.0, "grin", keys)

static func _bored(sway: float) -> Dictionary:
	return M([FL(0.12, 0.0), FR(0.12, 0.0), H(0.03 * sway, 0.0, 0.0), B(0.0, 0.0, -0.02 * sway), C(0.0), HD(-0.04, 0.1 * sway, 0.05), LR(0.16, -0.95, 0.06), WL(0.0), WR(0.0), {"curl": 0.35, "curl_l": 0.35, "fp_l": 0.0, "fp_r": 0.0, "sq": 1.0, "face": "neutral"}])

static func _pk(side: float, accent: float, turn: float) -> Dictionary:
	return M([FL(0.14, 0.0), FR(0.14, 0.0), H(0.07 * side, -0.07 * accent, 0.0), B(0.04, 0.0, -0.05 * side), C(0.0, 0.06 * side, -0.04 * side), HD(0.06, -0.1 * side, 0.12 * side),
		Lt(0.22, -0.2 + 0.22 * side, 0.55, 0.25), Rt(0.22, -0.2 - 0.22 * side, 0.55, 0.25), WL(-0.2, 1.4, 0.0), WR(-0.2, -1.4, 0.0),
		{"gesture": "thumbsup_both", "curl": 1.0, "curl_l": 1.0, "turn": turn, "fp_l": -0.25 * maxf(side, 0.0), "fp_r": -0.25 * maxf(- side, 0.0), "sq": 1.0 - 0.03 * accent, "face": "grin"}])

static func _pk_down(accent: float) -> Dictionary:
	return M([FL(0.2, 0.0), FR(0.2, 0.0), H(0.0, -0.14 * accent, 0.0), B(0.12), C(0.08), HD(0.1, 0.0, 0.0), L(0.55, -0.45 - 0.15 * accent, 0.35, 0.3), R(0.55, -0.45 - 0.15 * accent, 0.35, 0.3), WL(0.0, -1.4, 0.0), WR(0.0, 1.4, 0.0),
		{"gesture": "thumbsup_both", "curl": 1.0, "curl_l": 1.0, "turn": 0.0, "fp_l": 0.0, "fp_r": 0.0, "sq": 1.0 - 0.04 * accent, "face": "menace"}])



# Anxiety (Doechii, 2025) : casque sur les oreilles, on vibre seul… puis on se lâche (le pas
# d'Ashley dans le Prince de Bel-Air). Fait pour être rejoint par un deuxième danseur.
static func _anxiety(c: Dictionary) -> void :
	var bpm: float = 129.0
	var keys: Array = []
	for b: int in range(4):
		var side: float = 1.0 if b % 2 == 0 else -1.0
		keys.append([float(b), M([_base(), _phones(side, 0.1)]), "s"])
		keys.append([float(b) + 0.5, M([_base(), _phones(side, -0.02)])])
	for b: int in range(4, 8):
		var side2: float = 1.0 if b % 2 == 0 else -1.0
		keys.append([float(b), M([_base(), _roof(side2, 1.0)]), "s"])
		keys.append([float(b) + 0.5, M([_base(), _roof(side2, 0.3)])])
	for k: int in range(8):
		keys.append([8.0 + float(k) * 0.5, M([_base(), _roll(float(k) * PI * 0.5, 1.0 if k % 2 == 0 else -1.0)])])
	keys.append([12.0, M([_base(), _ax_point(1.0)]), "s"])
	keys.append([12.5, M([_base(), _ax_point(0.6)])])
	keys.append([13.0, M([_base(), _ax_point(-1.0)]), "s"])
	keys.append([13.5, M([_base(), _ax_point(-0.6)])])
	for k: int in range(8):
		var s: float = 1.0 if k % 2 == 0 else -1.0
		keys.append([14.0 + float(k) * 0.25, M([_base(), _shimmy(s)])])
	keys.append([16.0, keys[0][1], "s"])
	c["dance_anxiety"] = _dance(bpm, 16.0, "calm", keys)

static func _phones(side: float, dip: float) -> Dictionary:
	return M([FL(0.12 + 0.08 * maxf(side, 0.0), 0.0), FR(0.12 + 0.08 * maxf(- side, 0.0), 0.0), H(0.06 * side, - dip, 0.0), B(0.02, 0.05 * side, -0.04 * side), C(-0.02, 0.06 * side, -0.05 * side), HD(0.12 - dip, 0.12 * side, 0.18 * side),
		Lt(-0.04, 0.42, 0.05, 0.85), Rt(-0.04, 0.42, 0.05, 0.85), WL(0.4, 0.0, 0.0), WR(0.4, 0.0, 0.0),
		{"curl": 0.45, "curl_l": 0.45, "fp_l": -0.35 * maxf(- side, 0.0), "fp_r": -0.35 * maxf(side, 0.0), "sq": 1.0 - dip * 0.3, "face": "calm"}])

static func _roof(side: float, accent: float) -> Dictionary:
	return M([FL(0.16, 0.05 * side), FR(0.16, -0.05 * side), H(0.08 * side, -0.08 * accent, 0.0), B(0.0, 0.12 * side, -0.06 * side), C(-0.06, 0.1 * side, -0.05 * side), HD(0.15, -0.1 * side, 0.1 * side),
		L(0.6, 0.15 + 0.35 * accent * maxf(side, 0.0), 0.2, 0.3), R(0.6, 0.15 + 0.35 * accent * maxf(- side, 0.0), 0.2, 0.3), WL(-0.8), WR(-0.8),
		{"curl": 0.2, "curl_l": 0.2, "fp_l": 0.0, "fp_r": 0.0, "sq": 1.0 + 0.02 * accent, "face": "grin"}])

static func _roll(angle: float, side: float) -> Dictionary:
	var a: float = sin(angle) * 0.1
	var b: float = cos(angle) * 0.1
	return M([FL(0.14, 0.12 * side), FR(0.14, -0.12 * side), H(0.0, -0.08 + 0.03 * side, 0.0), B(0.1, 0.0, 0.0), C(0.05, 0.08 * side, 0.0), HD(0.0, 0.0, 0.08 * side),
		Lt(-0.12, -0.25 + a, 0.55 + b, 0.5), Rt(-0.12, -0.25 - a, 0.55 - b, 0.5), WL(0.4, 0.0, 0.0), WR(0.4, 0.0, 0.0),
		{"curl": 0.8, "curl_l": 0.8, "fp_l": 0.0, "fp_r": 0.0, "sq": 1.0, "face": "grin"}])

static func _ax_point(side: float) -> Dictionary:
	var right: bool = side > 0.0
	return M([FL(0.18, 0.0), FR(0.18, 0.0), H(-0.08 * side, -0.1 * absf(side), 0.0), B(0.0, -0.25 * side, 0.08 * side), C(0.0, -0.15 * side, 0.0), HD(0.05, -0.35 * side, 0.0),
		R(0.95, 0.3, 0.2, 0.0) if right else Rt(0.1, -0.55, 0.3, 0.6), L(0.95, 0.3, 0.2, 0.0) if not right else Lt(0.1, -0.55, 0.3, 0.6), WL(0.0), WR(0.0),
		{"gesture": "point" if right else "", "curl": 1.0, "curl_l": 1.0, "fp_l": 0.0, "fp_r": 0.0, "sq": 1.0, "face": "grin"}])

static func _shimmy(side: float) -> Dictionary:
	return M([FL(0.16, 0.0), FR(0.16, 0.0), H(0.0, -0.1, 0.0), B(0.12, 0.0, 0.0), C(0.08, 0.22 * side, 0.0), HD(0.05, -0.15 * side, 0.0), _sh(0.15),
		L(0.45, -0.5, 0.35, 0.4), R(0.45, -0.5, 0.35, 0.4), WL(0.0), WR(0.0), {"curl": 0.6, "curl_l": 0.6, "fp_l": 0.0, "fp_r": 0.0, "sq": 0.98, "face": "laugh"}])



# Dame un Grrr (Fantomel & Kate Linn, été 2025) : la griffe au visage, coup de hanche,
# griffures de chat, ondulation, tour sur soi et rugissement. Effets BD discrets (traînées de
# mains, veine de colère) : pas de griffes ni d'éclats d'impact, qu'on confondrait avec un coup d'Alice.
static func _grrr(c: Dictionary) -> void :
	var bpm: float = 126.0
	var keys: Array = []
	keys.append([0.0, M([_base(), _claw_face(1.0, 1.0), {"turn": 0.0}]), "s"])
	keys.append([0.5, M([_base(), _claw_face(1.0, 0.5), {"turn": 0.0}])])
	keys.append([1.0, M([_base(), _claw_face(1.0, 1.0), {"turn": 0.0, "fx": "anger"}]), "s"])
	keys.append([1.5, M([_base(), _claw_face(1.0, 0.4), {"turn": 0.0}])])
	keys.append([2.0, M([_base(), _claw_face(-1.0, 1.0), {"turn": 0.0}]), "s"])
	keys.append([2.5, M([_base(), _claw_face(-1.0, 0.5), {"turn": 0.0}])])
	keys.append([3.0, M([_base(), _claw_face(-1.0, 1.0), {"turn": 0.0}]), "s"])
	keys.append([3.5, M([_base(), _claw_face(-1.0, 0.4), {"turn": 0.0}])])
	for k: int in range(4):
		var s: float = 1.0 if k % 2 == 0 else -1.0
		keys.append([4.0 + float(k) * 0.5, M([_base(), _scratch(s, true), {"turn": 0.0, "fx": "trail_r" if s > 0.0 else "trail_l"}]), "s"])
		keys.append([4.25 + float(k) * 0.5, M([_base(), _scratch(s, false), {"turn": 0.0}])])
	keys.append([6.0, M([_base(), _body_roll(0.0), {"turn": 0.0}])])
	keys.append([6.5, M([_base(), _body_roll(1.0), {"turn": 0.0}])])
	keys.append([7.0, M([_base(), _roar(), {"turn": 0.0, "fx": "anger dust"}]), "s"])
	for b: int in range(8, 12):
		var side: float = 1.0 if b % 2 == 0 else -1.0
		keys.append([float(b), M([_base(), _catwalk(side, 1.0), {"turn": 0.0}]), "s"])
		keys.append([float(b) + 0.5, M([_base(), _catwalk(side, 0.3), {"turn": 0.0}])])
	keys.append([12.0, M([_base(), _catwalk(1.0, 1.0), {"turn": 0.0}]), "l"])
	keys.append([13.0, M([_base(), _spin_pose(), {"turn": - PI, "fx": "spin"}]), "l"])
	keys.append([14.0, M([_base(), _roar(), {"turn": - TAU}]), "s"])
	keys.append([15.0, M([_base(), _roar(), _claw_face(1.0, 0.6), {"turn": - TAU}])])
	keys.append([16.0, M([_base(), _claw_face(1.0, 1.0), {"turn": - TAU}]), "s"])
	c["dance_grrr"] = _dance(bpm, 16.0, "menace", keys)

static func _claw_face(side: float, accent: float) -> Dictionary:
	var right: bool = side > 0.0
	var claw: Dictionary = Rt(-0.12, 0.3, 0.42, 0.75) if right else Lt(-0.12, 0.3, 0.42, 0.75)
	var other: Dictionary = Lt(0.12, -0.66, 0.1, 0.6) if right else Rt(0.12, -0.66, 0.1, 0.6)
	return M([FL(0.12, 0.04 * side), FR(0.12, -0.04 * side), H(0.12 * side * accent, -0.05 * accent, 0.0), B(0.0, -0.08 * side, -0.06 * side * accent), C(-0.04, -0.06 * side, 0.08 * side * accent), HD(0.08, -0.12 * side, -0.12 * side),
		claw, other, WR(-0.7, 0.0, 0.0) if right else WR(0.0), WL(-0.7, 0.0, 0.0) if not right else WL(0.0),
		{"curl": 0.55 if right else 0.9, "curl_l": 0.55 if not right else 0.9, "fp_l": -0.3 * maxf(side, 0.0), "fp_r": -0.3 * maxf(- side, 0.0), "sq": 1.0 - 0.02 * accent, "face": "menace"}])

static func _scratch(side: float, down: bool) -> Dictionary:
	var y: float = -0.3 if down else 0.15
	return M([FL(0.16, 0.0), FR(0.16, 0.0), H(0.03 * side, -0.12, 0.0), B(0.2, 0.06 * side, 0.0), C(0.1), HD(0.15, 0.0, 0.06 * side),
		L(0.25, y if side < 0.0 else 0.0, 0.8, 0.4), R(0.25, y if side > 0.0 else 0.0, 0.8, 0.4), WL(-0.8), WR(-0.8), {"curl": 0.55, "curl_l": 0.55, "fp_l": 0.0, "fp_r": 0.0, "sq": 0.98, "face": "angry"}])

static func _body_roll(phase: float) -> Dictionary:
	return M([FL(0.14, 0.0), FR(0.14, 0.0), H(0.0, -0.06 - 0.06 * phase, 0.06 - 0.14 * phase), B(-0.1 + 0.3 * phase, 0.0, 0.0), C(0.25 - 0.4 * phase, 0.0, 0.0), HD(-0.2 + 0.35 * phase, 0.0, 0.0),
		L(0.35, -0.6, 0.2, 0.5), R(0.35, -0.6, 0.2, 0.5), WL(0.0), WR(0.0), {"curl": 0.5, "curl_l": 0.5, "fp_l": 0.0, "fp_r": 0.0, "sq": 1.0, "face": "menace"}])

static func _roar() -> Dictionary:
	return M([FL(0.24, 0.1), FR(0.24, -0.1), H(0.0, -0.16, 0.0), B(0.1), C(-0.15), HD(0.2), _sh(0.2),
		L(0.75, 0.25, 0.45, 0.5), R(0.75, 0.25, 0.45, 0.5), WL(-0.8), WR(-0.8), {"curl": 0.55, "curl_l": 0.55, "fp_l": 0.0, "fp_r": 0.0, "jaw": 0.8, "sq": 1.04, "face": "angry"}])

static func _catwalk(side: float, accent: float) -> Dictionary:
	return M([FL(0.02 + 0.06 * maxf(side, 0.0), 0.12 * side), FR(0.02 + 0.06 * maxf(- side, 0.0), -0.12 * side), H(0.12 * side, -0.04 * accent, 0.0), B(-0.04, 0.1 * side, -0.07 * side), C(-0.04, 0.08 * side, 0.06 * side), HD(0.1, -0.1 * side, -0.1 * side),
		Rt(-0.12, 0.3, 0.42, 0.75), WR(-0.7, 0.0, 0.0), Lt(0.12, -0.66, 0.1, 0.6), WL(0.0),
		{"curl": 0.55, "curl_l": 0.9, "fp_l": -0.4 * maxf(- side, 0.0), "fp_r": -0.4 * maxf(side, 0.0), "sq": 1.0, "face": "menace"}])

static func _spin_pose() -> Dictionary:
	return M([FL(0.06, 0.0), FR(0.06, 0.0), H(0.0, 0.02, 0.0), B(0.0), C(-0.05), HD(0.1), L(0.7, 0.1, 0.1, 0.5), R(0.7, 0.1, 0.1, 0.5), WL(-0.5), WR(-0.5), {"curl": 0.55, "curl_l": 0.55, "fp_l": -0.5, "fp_r": -0.5, "sq": 1.03, "face": "grin"}])



# Chicken Banana (Maads & Bruno, 2025) : ailes de poulet qui battent et tête qui picore,
# puis la banane — bras en arc au-dessus de la tête, corps penché.
static func _chicken(c: Dictionary) -> void :
	var bpm: float = 128.0
	var keys: Array = []
	for k: int in range(8):
		var s: float = 1.0 if k % 2 == 0 else -1.0
		keys.append([float(k) * 0.5, M([_base(), _chick(s, k % 2 == 0, 0.0)]), "s" if k % 2 == 0 else ""])
	keys.append([4.0, M([_base(), _banana(1.0, 1.0)]), "s"])
	keys.append([5.0, M([_base(), _banana(1.0, 0.6)])])
	keys.append([6.0, M([_base(), _banana(-1.0, 1.0)]), "s"])
	keys.append([7.0, M([_base(), _banana(-1.0, 0.6)])])
	for k: int in range(8):
		var s2: float = 1.0 if k % 2 == 0 else -1.0
		keys.append([8.0 + float(k) * 0.5, M([_base(), _chick(s2, k % 2 == 0, 0.4 * sin(float(k) * PI / 4.0))]), "s" if k % 2 == 0 else ""])
	keys.append([12.0, M([_base(), _banana(0.0, 1.0)]), "s"])
	keys.append([13.0, M([_base(), _peel(0.5)])])
	keys.append([14.0, M([_base(), _peel(1.0)]), "s"])
	keys.append([14.75, M([_base(), _hop(0.0)])])
	keys.append([15.0, M([_base(), _hop(1.0), {"fx": "dust"}])])
	keys.append([15.5, M([_base(), _hop(0.0)]), "s"])
	keys.append([16.0, keys[0][1], "s"])
	c["dance_chicken"] = _dance(bpm, 16.0, "laugh", keys)

static func _chick(side: float, flap: bool, turn: float) -> Dictionary:
	var wing: float = 0.55 if flap else 0.15
	return M([FL(0.16, 0.06 * side), FR(0.16, -0.06 * side), H(0.0, -0.18 if flap else -0.12, 0.0), B(0.28, 0.0, 0.0), C(0.05, 0.05 * side, 0.0), HD(0.35 if flap else 0.05, 0.12 * side, 0.0),
		Lt(0.12, -0.08, 0.02, 0.0), Rt(0.12, -0.08, 0.02, 0.0), {"el_l": wing, "el_r": wing}, WL(0.8), WR(0.8),
		{"curl": 0.9, "curl_l": 0.9, "turn": turn, "fp_l": -0.35 * maxf(side, 0.0), "fp_r": -0.35 * maxf(- side, 0.0), "sq": 0.97 if flap else 1.01, "face": "laugh"}])

static func _banana(side: float, accent: float) -> Dictionary:
	return M([FL(0.12, 0.0), FR(0.12, 0.0), H(-0.12 * side, -0.02, 0.0), B(0.0, 0.0, 0.18 * side * accent), C(0.0, 0.0, 0.2 * side * accent), HD(0.05, 0.0, 0.15 * side),
		L(0.18 + 0.2 * side, 0.9, 0.14, 0.25), R(0.18 - 0.2 * side, 0.9, 0.14, 0.25), WL(0.7, 0.0, 0.0), WR(0.7, 0.0, 0.0),
		{"curl": 0.2, "curl_l": 0.2, "turn": 0.0, "fp_l": 0.0, "fp_r": 0.0, "sq": 1.0 + 0.04 * accent, "face": "grin"}])

static func _peel(amount: float) -> Dictionary:
	return M([FL(0.16, 0.0), FR(0.16, 0.0), H(0.0, -0.06 * amount, 0.0), B(0.0), C(-0.06), HD(0.15),
		L(0.4 + 0.5 * amount, 0.92 - 0.9 * amount, 0.2, 0.3), R(0.4 + 0.5 * amount, 0.92 - 0.9 * amount, 0.2, 0.3), WL(0.0, -1.0, 0.0), WR(0.0, 1.0, 0.0),
		{"curl": 0.1, "curl_l": 0.1, "turn": 0.0, "fp_l": 0.0, "fp_r": 0.0, "sq": 1.0, "face": "laugh"}])

static func _hop(up: float) -> Dictionary:
	return M([FL(0.14, 0.0, 0.18 * up), FR(0.14, 0.0, 0.18 * up), {"feet": V(0.0, 0.2 * up, 0.0)}, H(0.0, -0.14 + 0.36 * up, 0.0), B(0.1 - 0.1 * up), C(0.0), HD(0.1 + 0.1 * up),
		L(0.7, 0.2 + 0.5 * up, 0.15, 0.4), R(0.7, 0.2 + 0.5 * up, 0.15, 0.4), WL(0.0), WR(0.0), {"curl": 0.1, "curl_l": 0.1, "turn": 0.0, "fp_l": -0.5 * up, "fp_r": -0.5 * up, "sq": 0.94 + 0.1 * up, "face": "laugh"}])



# Golden (KPop Demon Hunters, 2025) : chorégraphie de chasseuse de démons inspirée des arts
# martiaux — dégainer, garde, coup de poing, grand V doré, refrain en angles nets.
static func _golden(c: Dictionary) -> void :
	var bpm: float = 123.0
	var keys: Array = [
		[0.0, M([_base(), _draw(0.0)]), "s"],
		[1.0, M([_base(), _draw(1.0), {"fx": "trail_r"}]), "s"],
		[1.5, M([_base(), _draw(1.0)])],
		[2.0, M([_base(), _guard(1.0)]), "s"],
		[2.5, M([_base(), _guard(0.7)])],
		[3.0, M([_base(), _guard(1.0), {"turn": 0.0}]), "s"],
		[3.5, M([_base(), _guard(0.85)])],
		[4.0, M([_base(), _strike(1.0, 0.0), {"fx": "trail_r"}]), "s"],
		[4.5, M([_base(), _strike(0.4, 0.0)])],
		[5.0, M([_base(), _strike(-1.0, 1.0), {"fx": "trail_l"}]), "s"],
		[5.5, M([_base(), _strike(-0.4, 0.4)])],
		[6.0, M([_base(), _golden_v(0.0)])],
		[7.0, M([_base(), _golden_v(1.0), {"fx": "sparkle glint"}]), "s"],
		[7.5, M([_base(), _golden_v(0.9)])],
	]
	for b: int in range(8, 12):
		var side: float = 1.0 if b % 2 == 0 else -1.0
		keys.append([float(b), M([_base(), _hit(side, b % 4 < 2)]), "s"])
		keys.append([float(b) + 0.5, M([_base(), _hit(side * 0.5, b % 4 < 2), {"sq": 1.0}])])
	keys += [
		[12.0, M([_base(), _flip(0.0)])],
		[13.0, M([_base(), _flip(1.0)]), "s"],
		[13.5, M([_base(), _flip(0.8)])],
		[14.0, M([_base(), _frame(1.0)]), "s"],
		[15.0, M([_base(), _frame(0.8)])],
		[15.5, M([_base(), _draw(0.0)])],
		[16.0, M([_base(), _draw(0.0)]), "s"],
	]
	c["dance_golden"] = _dance(bpm, 16.0, "determined", keys)

static func _draw(amount: float) -> Dictionary:
	return M([FL(0.18, 0.08), FR(0.2, -0.12), H(0.0, -0.1, 0.0), B(0.05, 0.25 - 0.55 * amount, 0.0), C(0.05, 0.2 - 0.4 * amount, 0.0), HD(0.0, -0.3 + 0.35 * amount, 0.0),
		Rt(-0.45 + 1.3 * amount, -0.55 + 1.05 * amount, 0.3 + 0.1 * amount, 0.3), Lt(-0.35, -0.6, 0.3, 0.4), WR(0.0, 0.0, 0.0), WL(0.0),
		{"curl": 1.0, "curl_l": 0.8, "turn": 0.0, "fp_l": 0.0, "fp_r": -0.3, "sq": 1.0, "face": "determined"}])

static func _guard(accent: float) -> Dictionary:
	return M([FL(0.3, 0.2), FR(0.3, -0.2), H(0.0, -0.22 * accent, 0.0), B(0.08, -0.35, 0.0), C(0.05, -0.1, 0.0), HD(0.05, 0.35, 0.0),
		L(0.2, 0.05, 0.85, 0.2), Rt(0.15, -0.55, 0.05, 0.6), WL(-1.0, 0.0, 0.0), WR(0.0),
		{"curl": 1.0, "curl_l": 0.0, "turn": 0.0, "fp_l": 0.0, "fp_r": 0.0, "sq": 1.0 - 0.03 * accent, "face": "determined"}])

static func _strike(side: float, low: float) -> Dictionary:
	var right: bool = side > 0.0
	var reach: float = absf(side)
	return M([FL(0.26, 0.15), FR(0.26, -0.15), H(0.0, -0.18, 0.04 * reach), B(0.1, -0.3 * side, 0.0), C(0.05, -0.15 * side, 0.0), HD(0.0, 0.2 * side, 0.0),
		R(0.05, 0.1 - 0.4 * low, 0.6 + 0.4 * reach, 0.0) if right else Rt(0.15, -0.55, 0.05, 0.6), L(0.05, 0.1 - 0.4 * low, 0.6 + 0.4 * reach, 0.0) if not right else Lt(0.15, -0.55, 0.05, 0.6), WL(0.0), WR(0.0),
		{"curl": 1.0, "curl_l": 1.0, "turn": 0.0, "fp_l": 0.0, "fp_r": -0.2, "sq": 0.98, "face": "angry"}])

static func _golden_v(amount: float) -> Dictionary:
	return M([FL(0.2, 0.0), FR(0.2, 0.0), H(0.0, -0.12 + 0.14 * amount, 0.0), B(0.0), C(-0.15 * amount), HD(0.25 * amount), _sh(0.15 * amount),
		L(0.4 + 0.15 * amount, -0.3 + 1.15 * amount, 0.25, 0.2), R(0.4 + 0.15 * amount, -0.3 + 1.15 * amount, 0.25, 0.2), WL(0.0, -1.2 * amount, 0.0), WR(0.0, 1.2 * amount, 0.0),
		{"curl": 0.1, "curl_l": 0.1, "turn": 0.0, "fp_l": -0.4 * amount, "fp_r": -0.4 * amount, "sq": 1.0 + 0.04 * amount, "face": "grin"}])

static func _hit(side: float, high: bool) -> Dictionary:
	var up: float = 0.75 if high else -0.55
	return M([FL(0.2 + 0.1 * maxf(side, 0.0), 0.0), FR(0.2 + 0.1 * maxf(- side, 0.0), 0.0), H(0.1 * side, -0.12, 0.0), B(0.04, 0.12 * side, -0.05 * side), C(0.0, 0.12 * side, 0.0), HD(0.1 * signf(up), -0.25 * side, 0.0),
		R(0.75, up, 0.25, 0.0) if side > 0.0 else Rt(0.1, -0.5, 0.35, 0.5), L(0.75, - up, 0.25, 0.0) if side > 0.0 else L(0.75, up, 0.25, 0.0), WL(0.0), WR(0.0),
		{"gesture": "point" if side > 0.0 else "", "curl": 1.0, "curl_l": 0.2, "turn": 0.0, "fp_l": -0.3 * maxf(side, 0.0), "fp_r": -0.3 * maxf(- side, 0.0), "sq": 0.98, "face": "determined"}])

static func _flip(amount: float) -> Dictionary:
	return M([FL(0.18, 0.0), FR(0.18, 0.0), H(0.0, -0.08, 0.0), B(0.05, 0.0, -0.1 * amount), C(0.0, 0.0, -0.12 * amount), HD(0.3 * amount, 0.3 * amount, -0.3 * amount),
		Rt(-0.05, 0.4 * amount, 0.2 + 0.1 * amount, 0.8), Lt(0.12, -0.66, 0.1, 0.6), WR(0.5, 0.0, 0.0), WL(0.0),
		{"curl": 0.2, "curl_l": 0.9, "turn": 0.0, "fp_l": 0.0, "fp_r": 0.0, "sq": 1.0 + 0.03 * amount, "face": "grin"}])

static func _frame(amount: float) -> Dictionary:
	return M([FL(0.22, 0.12), FR(0.18, -0.06), H(0.06, -0.06, 0.0), B(0.0, 0.1, 0.06), C(-0.05, 0.1, 0.05), HD(0.08, -0.2, 0.15),
		Rt(-0.1, 0.2 * amount, 0.55, 0.4), Lt(-0.1, -0.05 * amount, 0.55, 0.4), WR(0.0, 1.3, 0.0), WL(0.0, -1.3, 0.0),
		{"gesture": "point", "curl": 1.0, "curl_l": 0.2, "turn": 0.0, "fp_l": 0.0, "fp_r": -0.35, "sq": 1.0, "face": "grin"}])



# Funk brésilien (« passinho », tendances funk/phonk 2025) : jeu de pieds rapide talon-pointe,
# genoux qui rebondissent, bras lâches, hanches qui tournent.
static func _funk(c: Dictionary) -> void :
	var bpm: float = 130.0
	var keys: Array = []
	for k: int in range(8):
		keys.append([float(k) * 0.5, M([_base(), _passinho(k)]), "s" if k % 2 == 0 else ""])
	for k: int in range(4):
		keys.append([4.0 + float(k) * 0.5, M([_base(), _hips_circle(float(k) * PI * 0.5)])])
	keys.append([6.0, M([_base(), _fling(0.0)]), "s"])
	keys.append([6.5, M([_base(), _fling(1.0), {"fx": "trail_both"}]), "s"])
	keys.append([7.0, M([_base(), _fling(0.4)])])
	keys.append([7.5, M([_base(), _fling(0.0)])])
	keys.append([8.0, keys[0][1], "s"])
	c["dance_funk"] = _dance(bpm, 8.0, "grin", keys)

static func _passinho(k: int) -> Dictionary:
	var side: float = 1.0 if (k / 2) % 2 == 0 else -1.0
	var heel: bool = k % 2 == 0
	var twist: float = 0.35 if heel else -0.2
	return M([FL(0.16 + 0.06 * maxf(side, 0.0), 0.14 * maxf(side, 0.0) if heel else 0.0), FR(0.16 + 0.06 * maxf(- side, 0.0), 0.14 * maxf(- side, 0.0) if heel else 0.0), H(0.05 * side, -0.16 if heel else -0.08, 0.0),
		B(0.12, 0.1 * side * twist, 0.0), C(0.05, -0.12 * side, 0.0), HD(0.05, 0.1 * side, 0.06 * side),
		L(0.4, -0.55, 0.3 - 0.25 * side, 0.4), R(0.4, -0.55, 0.3 + 0.25 * side, 0.4), WL(0.3), WR(0.3),
		{"curl": 0.6, "curl_l": 0.6, "fp_l": 0.55 if heel and side > 0.0 else 0.0, "fp_r": 0.55 if heel and side < 0.0 else 0.0, "sq": 0.98 if heel else 1.01, "face": "grin"}])

static func _hips_circle(angle: float) -> Dictionary:
	return M([FL(0.2, 0.0), FR(0.2, 0.0), H(0.1 * cos(angle), -0.14, 0.1 * sin(angle)), B(0.06 + 0.06 * sin(angle), 0.0, -0.08 * cos(angle)), C(0.0, 0.0, 0.1 * cos(angle)), HD(0.05, 0.0, 0.08 * cos(angle)),
		Lt(-0.05, -0.15, 0.45, 0.6), Rt(-0.05, -0.12, 0.45, 0.6), WL(0.5), WR(0.5), {"curl": 0.7, "curl_l": 0.7, "fp_l": 0.0, "fp_r": 0.0, "sq": 1.0, "face": "grin"}])

static func _fling(amount: float) -> Dictionary:
	return M([FL(0.22, 0.0, 0.08 * amount), FR(0.22, 0.0), H(0.0, -0.18 + 0.14 * amount, 0.0), B(0.1 - 0.1 * amount), C(0.0, 0.0, -0.08 * amount), HD(0.2 * amount, 0.0, 0.0),
		L(0.5 + 0.3 * amount, -0.4 + 1.2 * amount, 0.3, 0.3), R(0.5 + 0.3 * amount, -0.4 + 1.1 * amount, 0.3, 0.3), WL(0.0), WR(0.0),
		{"curl": 0.3, "curl_l": 0.3, "fp_l": -0.3 * amount, "fp_r": -0.3 * amount, "sq": 0.96 + 0.08 * amount, "face": "laugh"}])



# Amapiano (pas « Tshwala Bam » et tendances amapiano 2025-2026) : décontracté, genoux souples,
# pas glissés, mains qui poussent, ondulation des hanches et le grand penché arrière.
static func _amapiano(c: Dictionary) -> void :
	var bpm: float = 113.0
	var keys: Array = []
	for b: int in range(4):
		var side: float = 1.0 if b % 2 == 0 else -1.0
		keys.append([float(b), M([_base(), _ama_step(side, 1.0)])])
		keys.append([float(b) + 0.5, M([_base(), _ama_step(side, 0.0)])])
	for b: int in range(4, 8):
		keys.append([float(b), M([_base(), _push(1.0, b % 2 == 0)]), "s"])
		keys.append([float(b) + 0.5, M([_base(), _push(0.0, b % 2 == 0)])])
	for k: int in range(8):
		keys.append([8.0 + float(k) * 0.5, M([_base(), _wind(float(k) * PI * 0.5)])])
	keys.append([12.0, M([_base(), _lean_back(0.5, 1.0)])])
	keys.append([13.0, M([_base(), _lean_back(1.0, -1.0)])])
	keys.append([14.0, M([_base(), _lean_back(1.0, 1.0)])])
	keys.append([15.0, M([_base(), _lean_back(0.4, -1.0)])])
	keys.append([16.0, keys[0][1]])
	c["dance_amapiano"] = _dance(bpm, 16.0, "calm", keys)

static func _ama_step(side: float, weight: float) -> Dictionary:
	return M([FL(0.18 + 0.12 * maxf(side, 0.0) * weight, 0.0), FR(0.18 + 0.12 * maxf(- side, 0.0) * weight, 0.0), H(0.1 * side * weight, -0.14 + 0.05 * (1.0 - weight), 0.0), B(0.1, 0.1 * side, -0.04 * side), C(0.04, -0.06 * side, 0.05 * side), HD(-0.08 + 0.1 * (1.0 - weight), 0.1 * side, 0.06 * side),
		L(0.35, -0.75, 0.2 + 0.15 * side, 0.35), R(0.35, -0.75, 0.2 - 0.15 * side, 0.35), WL(0.2), WR(0.2), _sh(0.06 * weight),
		{"curl": 0.5, "curl_l": 0.5, "fp_l": -0.3 * maxf(- side, 0.0) * weight, "fp_r": -0.3 * maxf(side, 0.0) * weight, "sq": 1.0, "face": "calm"}])

static func _push(amount: float, left: bool) -> Dictionary:
	var s: float = 1.0 if left else -1.0
	return M([FL(0.18, 0.1 * s * amount), FR(0.18, -0.1 * s * amount), H(0.0, -0.2, -0.04 * amount), B(0.22, 0.0, 0.0), C(0.08, 0.06 * s, 0.0), HD(0.15, 0.0, 0.05 * s),
		Lt(-0.1, -0.3, 0.45 + 0.35 * amount, 0.3), Rt(-0.1, -0.3, 0.45 + 0.35 * amount, 0.3), WL(-0.9), WR(-0.9),
		{"curl": 0.1, "curl_l": 0.1, "fp_l": 0.0, "fp_r": 0.0, "sq": 1.0 - 0.03 * amount, "face": "grin"}])

static func _wind(angle: float) -> Dictionary:
	return M([FL(0.22, 0.0), FR(0.22, 0.0), H(0.11 * sin(angle), -0.2, 0.08 * cos(angle)), B(0.15 - 0.08 * cos(angle), 0.0, -0.1 * sin(angle)), C(0.0, 0.0, 0.12 * sin(angle)), HD(0.0, 0.0, 0.06 * sin(angle)),
		L(0.7, -0.5, 0.2, 0.2), R(0.7, -0.5, 0.2, 0.2), WL(0.0, -0.4, 0.0), WR(0.0, 0.4, 0.0), {"curl": 0.2, "curl_l": 0.2, "fp_l": 0.0, "fp_r": 0.0, "sq": 1.0, "face": "calm"}])

static func _lean_back(amount: float, side: float) -> Dictionary:
	return M([FL(0.2, 0.1 * side), FR(0.2, -0.1 * side), H(0.0, -0.2 - 0.08 * amount, 0.1 * amount), B(-0.25 * amount, 0.0, 0.0), C(-0.1 * amount, 0.0, 0.0), HD(0.15 * amount, 0.15 * side, 0.0),
		L(0.8, -0.2 + 0.2 * amount, 0.05, 0.2), R(0.8, -0.2 + 0.2 * amount, 0.05, 0.2), WL(0.0, -1.0, 0.0), WR(0.0, 1.0, 0.0),
		{"curl": 0.2, "curl_l": 0.2, "fp_l": -0.4 * maxf(side, 0.0), "fp_r": -0.4 * maxf(- side, 0.0), "sq": 1.0, "face": "grin"}])



# Retour en 2016 (tendance nostalgie « 2026 is the new 2016 ») : le Whip, le Nae Nae,
# deux pas de Juju… et le Mannequin Challenge : tout le monde se fige.
static func _retro(c: Dictionary) -> void :
	var bpm: float = 140.0
	var keys: Array = [
		[0.0, M([_base(), _whip(0.0)]), "s"],
		[1.0, M([_base(), _whip(1.0)]), "s"],
		[1.5, M([_base(), _whip(0.3)])],
		[2.0, M([_base(), _whip(0.0)]), "s"],
		[3.0, M([_base(), _whip(1.0)]), "s"],
		[3.5, M([_base(), _whip(0.3)])],
	]
	for b: int in range(4, 8):
		var side: float = 1.0 if b % 2 == 0 else -1.0
		keys.append([float(b), M([_base(), _naenae(side)])])
	for b: int in range(8, 12):
		var side2: float = 1.0 if b % 2 == 0 else -1.0
		keys.append([float(b), M([_base(), _juju(side2, 1.0)]), "s"])
		keys.append([float(b) + 0.5, M([_base(), _juju(side2, 0.3)])])
	keys += [
		[12.0, M([_base(), _mannequin(), {"fx": "stars"}]), "s"],
		[14.0, M([_base(), _mannequin()]), "h"],
		[14.5, M([_base(), _mannequin(), {"sq": 1.0}]), "s"],
		[15.25, M([_base(), _whip(0.0), {"face": "laugh"}])],
		[16.0, M([_base(), _whip(0.0)]), "s"],
	]
	c["dance_retro"] = _dance(bpm, 16.0, "grin", keys)

static func _whip(amount: float) -> Dictionary:
	return M([FL(0.2, 0.0), FR(0.2, 0.0), H(-0.05 * amount, -0.2 - 0.06 * amount, 0.0), B(0.1, -0.1 * amount, 0.06 * amount), C(0.05, -0.08 * amount, 0.0), HD(0.0, 0.15 * amount, -0.1 * amount),
		R(0.5 + 0.25 * amount, 0.05 - 0.45 * amount, 0.55 - 0.1 * amount, 0.2), Lt(0.12, -0.66, 0.1, 0.6), WR(-0.5 + 1.1 * amount, 0.0, 0.0), WL(0.0),
		{"curl": 0.8, "curl_l": 0.9, "fp_l": 0.0, "fp_r": 0.0, "sq": 1.0 - 0.03 * amount, "face": "grin"}])

static func _naenae(side: float) -> Dictionary:
	return M([FL(0.22, 0.0), FR(0.22, 0.0), H(0.12 * side, -0.24, 0.0), B(0.12, 0.0, 0.12 * side), C(0.05, 0.0, 0.08 * side), HD(0.1, -0.1 * side, -0.12 * side),
		R(0.25 + 0.3 * side, 0.92, 0.1, 0.2), Lt(0.3, -0.4, 0.3, 0.5), WR(0.0, 1.2, 0.3 * side), WL(0.0),
		{"curl": 0.05, "curl_l": 0.8, "fp_l": -0.3 * maxf(side, 0.0), "fp_r": -0.3 * maxf(- side, 0.0), "sq": 1.0, "face": "laugh"}])

static func _juju(side: float, accent: float) -> Dictionary:
	return M([FL(0.16 + 0.12 * maxf(side, 0.0) * accent, 0.06 * side), FR(0.16 + 0.12 * maxf(- side, 0.0) * accent, -0.06 * side), H(0.1 * side * accent, -0.14 * accent, 0.0), B(0.12, -0.15 * side, 0.0), C(0.05, -0.12 * side, 0.0), HD(0.0, 0.15 * side, 0.0), _sh(0.2 * accent),
		L(0.35, -0.55, 0.4 + 0.3 * side, 0.4), R(0.35, -0.55, 0.4 - 0.3 * side, 0.4), WL(0.3), WR(0.3),
		{"curl": 0.9, "curl_l": 0.9, "fp_l": -0.35 * maxf(- side, 0.0), "fp_r": -0.35 * maxf(side, 0.0), "sq": 1.0 - 0.03 * accent, "face": "grin"}])

static func _mannequin() -> Dictionary:
	return M([FL(0.22, 0.2), FR(0.2, -0.2, 0.0), H(0.05, -0.2, 0.0), B(0.08, 0.25, 0.1), C(0.0, 0.1, 0.05), HD(0.05, -0.3, 0.12),
		R(0.85, 0.55, 0.3, 0.2), Lt(-0.2, 0.15, 0.55, 0.5), WR(0.0, 1.0, 0.0), WL(0.3),
		{"gesture": "point", "curl": 1.0, "curl_l": 0.4, "fp_l": 0.0, "fp_r": -0.5, "sq": 1.0, "face": "surprise"}])



# Pretty Little Baby (Connie Francis, 1962 — chanson TikTok de l'année 2025) : doo-wop tout
# doux, claquements de doigts, bébé bercé, main sur le cœur, et un petit twist.
static func _baby(c: Dictionary) -> void :
	var bpm: float = 120.0
	var keys: Array = []
	for b: int in range(4):
		var side: float = 1.0 if b % 2 == 0 else -1.0
		keys.append([float(b), M([_base(), _snap_step(side, b % 2 == 1)]), "s" if b % 2 == 1 else ""])
		keys.append([float(b) + 0.5, M([_base(), _snap_step(side * 0.4, false)])])
	for b: int in range(4, 8):
		var s2: float = 1.0 if b % 2 == 0 else -1.0
		keys.append([float(b), M([_base(), _cradle(s2)])])
	for b: int in range(8, 12):
		var s3: float = 1.0 if b % 2 == 0 else -1.0
		keys.append([float(b), M([_base(), _heart_reach(s3)])])
	for k: int in range(8):
		keys.append([12.0 + float(k) * 0.5, M([_base(), _twist(1.0 if k % 2 == 0 else -1.0, 0.3 * float(k) / 7.0)])])
	keys.append([16.0, keys[0][1]])
	c["dance_baby"] = _dance(bpm, 16.0, "smile", keys)

static func _snap_step(side: float, snap: bool) -> Dictionary:
	return M([FL(0.1 + 0.1 * maxf(side, 0.0), 0.0), FR(0.1 + 0.1 * maxf(- side, 0.0), 0.0), H(0.08 * side, -0.05, 0.0), B(0.0, 0.06 * side, -0.05 * side), C(0.0, 0.0, 0.06 * side), HD(0.05, -0.08 * side, -0.15 * side),
		L(0.4, -0.3, 0.35, 0.5), R(0.4, -0.3, 0.35, 0.5), WL(-0.4, -0.6, 0.0), WR(-0.4, 0.6, 0.0),
		{"curl": 0.75, "curl_l": 0.75, "fp_l": -0.3 * maxf(- side, 0.0), "fp_r": -0.3 * maxf(side, 0.0), "sq": 0.99 if snap else 1.0, "fx": "snap" if snap else "", "face": "smile"}])

static func _cradle(side: float) -> Dictionary:
	return M([FL(0.14, 0.0), FR(0.14, 0.0), H(0.06 * side, -0.06, 0.0), B(0.05, 0.1 * side, -0.05 * side), C(0.05, 0.12 * side, -0.08 * side), HD(-0.25, 0.1 * side, 0.15 * side),
		Lt(-0.25 + 0.06 * side, -0.48 + 0.08 * side, 0.4, 0.3), Rt(-0.25 - 0.06 * side, -0.4 - 0.08 * side, 0.42, 0.3), WL(0.0, -1.2, 0.0), WR(0.0, 1.2, 0.0),
		{"curl": 0.3, "curl_l": 0.3, "fp_l": 0.0, "fp_r": 0.0, "sq": 1.0, "fx": "", "face": "smile"}])

static func _heart_reach(side: float) -> Dictionary:
	return M([FL(0.14, 0.12 * side), FR(0.14, -0.12 * side), H(0.0, -0.04, 0.04 * side), B(-0.04, 0.08, 0.0), C(-0.08, 0.08, 0.0), HD(0.12, -0.2, 0.1),
		Lt(-0.35, -0.3, 0.32, 0.4), R(0.5, 0.15, 0.75, 0.1), WL(-0.4), WR(0.0, 1.2, 0.0),
		{"curl": 0.2, "curl_l": 0.1, "fp_l": -0.4 * maxf(- side, 0.0), "fp_r": -0.4 * maxf(side, 0.0), "sq": 1.0, "fx": "notes" if side > 0.0 else "", "face": "grin"}])

static func _twist(side: float, low: float) -> Dictionary:
	return M([FL(0.2, 0.05), FR(0.2, -0.05), H(0.0, -0.14 - low, 0.0), B(0.1 + low * 0.2, 0.3 * side, 0.0), C(0.05, -0.45 * side, 0.0), HD(0.05, 0.3 * side, 0.0),
		L(0.65, -0.25, 0.3 - 0.3 * side, 0.4), R(0.65, -0.25, 0.3 + 0.3 * side, 0.4), WL(0.0), WR(0.0),
		{"curl": 0.6, "curl_l": 0.6, "fp_l": -0.4, "fp_r": -0.4, "turn": 0.25 * side, "sq": 1.0, "fx": "", "face": "laugh"}])
