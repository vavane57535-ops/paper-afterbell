extends "res://anim_pose.gd"

# Prologue « Yiero », partie B (104 → 196 s) : défaite, poursuite, porte, école, coup double.
# Chaque mouvement de corps de ces actes est un clip écrit POUR le film (aucun clip, émote ou geste de
# capacité du jeu) : poses clés puis intervalles, anticipation, rattrapage, chevauchement (tête, mains
# et regard en décalé), poids et appuis, visages qui évoluent. Les déplacements ont leur propre cycle
# (course à pieds plantés calée sur le trajet du film : le pied d'appui recule exactement de la
# distance parcourue). Les clés sont écrites en temps du FILM puis converties en temps de clip (les
# ralentis du film ralentissent aussi les clips). Noms préfixés « pb_ ».
# Le film (film_intro_yiero.gd, _write_defeat/_chase/_school) lance les clips aux instants de plays().

const AnimClip = preload("res://anim_clip.gd")

# Longueur de jambe hanche → cheville, en mètres (tools/pb_probe.gd).
const LEG_M: Dictionary = {"Simon": 0.699, "Ashura": 0.645, "Usayuko": 0.675, "Alice": 0.863, "Elly": 0.783, "Bleuette": 0.683, "Lysia": 0.864}
# Ralentis du film dans cette partie : [début, fin, facteur] (mêmes valeurs que _slowmo dans le film).
const SLOW: Array = [[149.2, 150.6, 0.3], [162.15, 162.55, 0.3]]

static var _clips: Dictionary = {}
static var _plays: Array = []


static func add(c: Dictionary) -> void :
	_build()
	c.merge(_clips, true)


# [instant du film, personnage, clip] : le film les joue tous avec _do(i, t, "play", clip).
static func plays() -> Array:
	_build()
	return _plays


static func _build() -> void :
	if not _clips.is_empty(): return
	_test(_clips)




# --- Temps -------------------------------------------------------------------------------------------

# Temps du film → temps « ralenti » (celui des clips).
static func scaled(t: float) -> float:
	var lost: float = 0.0
	for row: Array in SLOW:
		if t <= float(row[0]): continue
		lost += (minf(t, float(row[1])) - float(row[0])) * (1.0 - float(row[2]))
	return t - lost


# Inverse de scaled().
static func film_at(s: float) -> float:
	var lost: float = 0.0
	for row: Array in SLOW:
		var a: float = float(row[0])
		var b: float = float(row[1])
		var f: float = float(row[2])
		var sa: float = a - lost
		if s <= sa: return s + lost
		var sb: float = sa + (b - a) * f
		if s <= sb: return a + (s - sa) / maxf(f, 0.0001)
		lost += (b - a) * (1.0 - f)
	return s + lost


# Enregistre un clip écrit en temps du film (clés [t_film, pose, drapeau]) qui démarre à t0 (film).
static func _register(c: Dictionary, person: String, clip_name: String, t0: float, source: Dictionary) -> void :
	var base: float = scaled(t0)
	var keys: Array = []
	for key: Array in source.keys:
		var copy: Array = key.duplicate()
		copy[0] = scaled(float(key[0])) - base
		keys.append(copy)
	keys.sort_custom( func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var clip: Dictionary = source.duplicate()
	clip.keys = keys
	if not clip.has("len"): clip.len = float(keys[keys.size() - 1][0]) + 0.05
	if not clip.has("in"): clip["in"] = 0.0
	if not clip.has("out"): clip.out = 0.0
	c[clip_name] = clip
	_plays.append([t0, person, clip_name])




# --- Poses -------------------------------------------------------------------------------------------

static func TL(fwd: float, out: float = 0.0, yaw: float = 0.0) -> Dictionary:
	return {"l_leg": Vector3(fwd, yaw, - out)}

static func TR(fwd: float, out: float = 0.0, yaw: float = 0.0) -> Dictionary:
	return {"r_leg": Vector3(fwd, - yaw, out)}

static func KL(bend: float, ankle: float = 0.0) -> Dictionary:
	return {"l_knee": - bend, "l_ank": ankle}

static func KR(bend: float, ankle: float = 0.0) -> Dictionary:
	return {"r_knee": - bend, "r_ank": ankle}

# Canaux de base d'un clip de film : pas de locomotion du jeu, pieds posés, rien d'additif.
static func base() -> Dictionary:
	return {"gait": 0.0, "plant": 1.0, "gsnap": 0.0, "turn": 0.0, "sq": 1.0, "shake": 0.0, "jaw": 0.0, "fp_l": 0.0, "fp_r": 0.0, "el_l": 0.0, "el_r": 0.0}

static func K(t: float, parts: Array, flag: String = "") -> Array:
	return [t, M(parts), flag] if not flag.is_empty() else [t, M(parts)]




# --- Course à pieds plantés ---------------------------------------------------------------------------

# Distance parcourue (m) à l'instant t (film) sur un trajet [[t, Vector3], ...] interpolé linéairement.
static func path_distance(path: Array, t: float) -> float:
	if path.is_empty(): return 0.0
	var d: float = 0.0
	for k: int in range(1, path.size()):
		var a: Array = path[k - 1]
		var b: Array = path[k]
		var ta: float = float(a[0])
		var tb: float = float(b[0])
		var length: float = Vector2((b[1] as Vector3).x - (a[1] as Vector3).x, (b[1] as Vector3).z - (a[1] as Vector3).z).length()
		if t >= tb:
			d += length
			continue
		if t > ta: d += length * (t - ta) / maxf(0.0001, tb - ta)
		break
	return d

static func path_at(path: Array, t: float) -> Vector3:
	if path.is_empty(): return Vector3.ZERO
	if t <= float(path[0][0]): return path[0][1]
	for k: int in range(1, path.size()):
		if t <= float(path[k][0]):
			var a: Array = path[k - 1]
			var b: Array = path[k]
			return (a[1] as Vector3).lerp(b[1], (t - float(a[0])) / maxf(0.0001, float(b[0]) - float(a[0])))
	return path[path.size() - 1][1]


static func _noise(seed_value: int, k: int) -> float:
	var h: int = absi((seed_value * 73856093) ^ (k * 19349663) ^ (k * k * 83492791))
	return float(h % 10007) / 10006.0 * 2.0 - 1.0


# Ajoute les clés d'une course entre t0 et t1 (temps du film). Pas alternés tous les o.period s
# (premier appui à o.phase, pied o.first : -1 gauche, 1 droit). Pendant l'appui (o.contact s), le pied
# recule de la distance parcourue sur path : il reste fixe au sol. Options : land (pose du pied devant
# la hanche, en jambes), kick (talon derrière), knee (montée du genou), drop (bassin qui s'écrase),
# lean (buste), chest, head, arms ("pump" bras qui pompent, "sonic" bras tendus en arrière, "flail"
# bras paniqués), width (écart des pieds), seed (variations).
static func _run(keys: Array, person: String, t0: float, t1: float, path: Array, o: Dictionary) -> void :
	var leg: float = float(LEG_M.get(person, 0.7))
	var period: float = float(o.get("period", 0.1875))
	var contact: float = float(o.get("contact", 0.075))
	var phase: float = float(o.get("phase", t0))
	var first: int = int(o.get("first", -1))
	var land: float = float(o.get("land", 0.28))
	var kick: float = float(o.get("kick", 0.52))
	var knee: float = float(o.get("knee", 0.36))
	var drop: float = float(o.get("drop", 0.07))
	var lean: float = float(o.get("lean", 0.24))
	var chest: float = float(o.get("chest", 0.1))
	var head: float = float(o.get("head", 0.0))
	var arms: String = str(o.get("arms", "pump"))
	var width: float = float(o.get("width", 0.05))
	var seed_value: int = int(o.get("seed", 7))
	var swing: float = 2.0 * period - contact
	var n0: int = floori((t0 - phase) / period) - 1
	var n1: int = ceili((t1 - phase) / period) + 1
	for n: int in range(n0, n1 + 1):
		var tc: float = phase + float(n) * period
		var side: int = first if posmod(n, 2) == 0 else - first
		var jitter: float = _noise(seed_value, n)
		var foot: String = "foot_l" if side < 0 else "foot_r"
		var pitch: String = "fp_l" if side < 0 else "fp_r"
		var x: float = float(side) * - width
		var d0: float = path_distance(path, tc)
		var a: float = land * (1.0 + 0.08 * jitter)
		var mid_t: float = tc + contact * 0.5
		var off_t: float = tc + contact
		var a_mid: float = a - (path_distance(path, mid_t) - d0) / leg
		var a_off: float = a - (path_distance(path, off_t) - d0) / leg
		var rows: Array = [
			[tc, Vector3(x, 0.02, - a), -0.2, "l"],
			[mid_t, Vector3(x, 0.0, - a_mid), -0.08, "l"],
			[off_t, Vector3(x, 0.07, - a_off), -0.6, ""],
			[off_t + swing * 0.24, Vector3(x * 1.2, kick * (1.0 + 0.1 * jitter), - (a_off + 0.12)), -1.0, ""],
			[off_t + swing * 0.55, Vector3(x * 0.7, knee * (1.0 - 0.08 * jitter), - 0.16), 0.15, ""],
			[off_t + swing * 0.82, Vector3(x, 0.13, - (a + 0.14)), 0.1, ""],
		]
		for row: Array in rows:
			var at: float = float(row[0])
			if at < t0 - 0.0001 or at > t1 + 0.0001: continue
			var pose: Dictionary = {foot: row[1], pitch: float(row[2])}
			if str(row[3]).is_empty(): keys.append([at, pose])
			else: keys.append([at, pose, str(row[3])])
		# Bassin, buste, tête : un battement par appui (les deux pieds).
		var sway: float = 0.018 * float(side)
		var hip_rows: Array = [
			[tc, H(sway, - drop * 0.75, 0.0)],
			[tc + contact * 0.55, H(sway * 1.2, - drop * (1.15 + 0.1 * jitter), 0.0)],
			[off_t, H(sway, - drop * 0.6, 0.0)],
			[off_t + (period - contact) * 0.5, H(0.0, drop * 0.25, 0.0)],
		]
		for row: Array in hip_rows:
			if float(row[0]) >= t0 - 0.0001 and float(row[0]) <= t1 + 0.0001: keys.append([float(row[0]), row[1]])
		if tc >= t0 - 0.0001 and tc <= t1 + 0.0001:
			var pelvis: float = 0.1 * float(side)
			keys.append([tc + 0.02, M([B(lean + 0.02 * jitter, pelvis, -0.035 * float(side)), C(chest, - pelvis * 2.1, 0.02 * float(side)), HD(head + (lean + chest) * 0.75, pelvis * 1.1, 0.0)])])
			keys.append([tc + contact + (period - contact) * 0.5, M([B(lean + 0.045, 0.0, 0.0)])])
			# Bras opposés aux jambes, légèrement en retard (rattrapage).
			var arm_t: float = tc + 0.035
			var fore: int = - side
			var lead: Dictionary = {}
			var back: Dictionary = {}
			match arms:
				"sonic":
					lead = _arm(fore, 0.22, -0.28, -0.92, 0.0, false)
					back = _arm(- fore, 0.24, -0.3, -0.9, 0.0, false)
				"flail":
					lead = _arm(fore, 0.22, 0.05 + 0.12 * jitter, 0.5, 0.45, true)
					back = _arm(- fore, 0.3, -0.45, -0.42, 0.3, true)
				_:
					lead = _arm(fore, 0.0, 0.02 + 0.06 * jitter, 0.6, 0.12, true)
					back = _arm(- fore, 0.16, -0.48, -0.5, 0.3, true)
			keys.append([arm_t, M([lead, back])])


# Cible de main (côté -1 gauche / 1 droit), dans le repère du buste (torso) ou du corps.
static func _arm(side: int, out: float, up: float, fwd: float, flare: float, torso: bool) -> Dictionary:
	if side < 0: return Lt(out, up, fwd, flare) if torso else L(out, up, fwd, flare)
	return Rt(out, up, fwd, flare) if torso else R(out, up, fwd, flare)




# --- Essais (banc tools/pb_pose.gd) -------------------------------------------------------------------

static func _test(c: Dictionary) -> void :
	var path: Array = [[0.0, Vector3(0, 0, 0)], [0.6, Vector3(0, 0, -2.4)], [1.2, Vector3(0, 0, -6.6)], [4.0, Vector3(0, 0, -27.6)], [6.0, Vector3(0, 0, -53.6)]]
	var keys: Array = [K(0.0, [base(), rest(), {"curl": 0.3, "curl_l": 0.3, "face": "panic"}])]
	_run(keys, "Simon", 0.0, 4.0, path, {"phase": 0.05, "lean": 0.36, "chest": 0.16, "kick": 0.66, "knee": 0.46, "land": 0.3, "drop": 0.08, "arms": "pump"})
	_run(keys, "Simon", 4.0, 6.0, path, {"phase": 4.0, "period": 0.125, "contact": 0.05, "lean": 0.5, "chest": 0.35, "arms": "sonic", "land": 0.3, "kick": 0.6, "knee": 0.42, "drop": 0.09})
	var clip: Dictionary = {"len": 6.0, "in": 0.0, "out": 0.0, "face": "panic", "keys": keys, "pb_path": path}
	c["pb_test_run"] = clip
	c["pb_test_lean"] = {"len": 3.0, "in": 0.0, "out": 0.0, "keys": [K(0.0, [base(), rest(), B(0.0), C(0.0)]), K(1.0, [B(0.9), C(0.0)]), K(2.0, [B(0.0), C(0.9)]), K(3.0, [B(0.0), C(0.0)])]}
