extends "res://anim_pose.gd"

# Prologue « Yiero », actes I à III (0 → 104 s, lot prologue_a) : chaque mouvement de Simon et
# d'Ashura est écrit pour son plan (aucun clip du jeu, aucune démarche automatique).
#
# Chaque personnage est un « acteur » joué en continu sur tout le film, en trois couches :
# - la racine (trajet au sol, en mètres, repère du film) et l'orientation voulue du corps ;
# - les appuis : chaque pied est posé à un endroit précis de l'encre (il n'en bouge plus tant qu'il
#   porte), puis décrit un arc jusqu'à l'appui suivant (talon qui décolle, pointe, attaque talon) ;
#   les sauts et les chutes ont des pieds libres, écrits dans le repère du corps ;
# - le jeu d'acteur : poses clés (bassin, buste, tête, mains, doigts, visage) avec leurs intervalles.
# Le bassin suit les appuis (il se pose sur la jambe porteuse, descend quand les pieds s'écartent,
# tourne avec les jambes ; le buste contre-tourne, les bras balancent en retard) seulement là où le
# jeu le demande (canaux « loco » et « swing »).
# Le tout est cuit en clips longs (5 à 12 s, noms « pa_s* » et « pa_a* ») : clés tous les 1/20 s en
# temps du film, converties en temps de clip à travers les ralentis (SLOW, mêmes valeurs que les
# _slowmo du film). Le film (film_intro_yiero.gd) lit les mêmes acteurs : trajets de la racine,
# cibles d'orientation, appuis (anneaux dans l'encre, bruits de pas) et instants de départ des clips.
# Le lissage de l'orientation par le film (PaperPrologue._step : 11/s en temps ralenti) est compensé
# exactement dans le canal « turn » : les pieds posés ne tournent pas sur place.

const AnimClip = preload("res://anim_clip.gd")
const AnimLibrary = preload("res://anim_library.gd")

const SLOW: Array = [[63.2, 63.9, 0.25], [79.0, 80.2, 0.2], [92.9, 93.4, 0.25]]
const GRID: float = 0.05
const YAW_RATE: float = 11.0
# Le lot prologue_b reprend les personnages à 104 s ; les derniers clips tiennent leur pose au-delà.
const HANDOFF: float = 104.0
const HOLD_END: float = 112.0
const OVERLAP: float = 0.5
# Le film coupe les petits mouvements d'attente du moteur (balancement, appuis alternés, regards).
const FILM_STYLE: Dictionary = {"contra": 0.0, "shift_rate": 0.0, "idle_sway": 0.0, "idle_bounce": 0.0, "look_rate": 0.0}

# Mesures des squelettes (PaperVisual, unités du modèle ; scale : mètres par unité).
const RIG: Dictionary = {
	"Simon": {"tag": "s", "reach": 0.911139, "scale": 0.767544, "foot_l": Vector3(-0.1425, 0.15586, 0.035625), "foot_r": Vector3(0.133594, 0.155859, 0.035625), "hip_y": 1.064297, "hip_x": 0.106875, "toe": 0.136239, "twist": 1.0},
	"Ashura": {"tag": "a", "reach": 0.864776, "scale": 0.745614, "foot_l": Vector3(-0.243224, 0.114758, -0.037701), "foot_r": Vector3(0.250444, 0.097185, 0.089592), "hip_y": 0.961632, "hip_x": 0.133182, "toe": 0.056956, "twist": 1.15},
}

# Valeurs des canaux de jeu tant qu'aucune clé ne les donne. « loco », « swing », « breath » et
# « bf » sont des réglages internes (bassin piloté par les pas, balancement des bras, respiration).
const DEFAULTS: Dictionary = {
	"hips": Vector3.ZERO, "body": Vector3.ZERO, "chest": Vector3.ZERO, "head": Vector3.ZERO,
	"ik_l": Vector3(-0.12, -0.92, -0.06), "ik_r": Vector3(0.12, -0.92, -0.06),
	"el_l": 0.0, "el_r": 0.0, "tf_l": 0.0, "tf_r": 0.0, "gr_l": 0.0, "gr_r": 0.0, "ikw_l": 1.0, "ikw_r": 1.0,
	"l_hand": Vector3.ZERO, "r_hand": Vector3.ZERO, "curl": 0.3, "curl_l": 0.3,
	"plant": 1.0, "gait": 0.0, "gsnap": 0.0, "sq": 1.0, "shake": 0.0, "jaw": 0.0, "chatter": 0.0,
	"loco": 0.0, "swing": 0.0, "breath": 0.0, "bf": 0.3,
}
const INTERNAL: Array[String] = ["loco", "swing", "breath", "bf"]
const OPTIONAL: Array[String] = ["l_clav", "r_clav", "l_leg", "r_leg", "l_knee", "r_knee", "l_ank", "r_ank"]


class Actor:
	var who: String = ""
	var tag: String = ""
	var reach: float = 0.9
	var scale: float = 0.76
	var toe: float = 0.1
	var twist: float = 1.0
	var rest: Dictionary = {}
	var hip: Dictionary = {}
	var root: Array = []
	var yaw: Array = []
	var aims: Array = []
	var feet: Dictionary = {-1: [], 1: []}
	var acts: Array = []
	var cuts: Array = []
	var falls: Array = []
	var clips: Array = []
	var track: Dictionary = {}
	var strings: Dictionary = {}
	var root_t: PackedFloat32Array = PackedFloat32Array()
	var root_v: Array = []
	var yaw_t: PackedFloat32Array = PackedFloat32Array()
	var aim_rows: Array = []
	var aim_t: PackedFloat32Array = PackedFloat32Array()
	var feet_t: Dictionary = {}
	var ready: bool = false

	func _init(person: String) -> void :
		var rig: Dictionary = RIG[person]
		who = person
		tag = str(rig.tag)
		reach = float(rig.reach);scale = float(rig.scale);toe = float(rig.toe);twist = float(rig.twist)
		rest[-1] = rig.foot_l;rest[1] = rig.foot_r
		hip[-1] = Vector3( - float(rig.hip_x), float(rig.hip_y), 0.0);hip[1] = Vector3(float(rig.hip_x), float(rig.hip_y), 0.0)

	# Clé de jeu au temps t du film (drapeaux de AnimClip : "s" arrêt, "l" linéaire, "h" tenu).
	func key(t: float, pose: Dictionary, flag: String = "") -> void :
		if flag.is_empty(): acts.append([t, pose])
		else: acts.append([t, pose, flag])

	func go(t: float, at: Vector3) -> void :
		if not root.is_empty() and t <= float(root[root.size() - 1][0]) + 0.0001: root[root.size() - 1] = [t, at]
		else: root.append([t, at])

	func face(t: float, angle: float, ease: String = "smooth") -> void :
		yaw.append([t, angle, ease])

	func aim(t: float, angle: float) -> void :
		aims.append([t, angle])

	func cut(t: float) -> void :
		if not cuts.has(t): cuts.append(t)

	# Premier appui d'un pied (pas de pas ni d'onde).
	func plant(side: int, t: float, at: Vector3, heel: float = 0.5) -> void :
		feet[side].append([t, INF, "plant", {"at": at, "heel": heel, "h": 0.0, "fall": 0.0}])

	# Pas : le pied quitte son appui à `lift`, décrit un arc et se pose en `at` (repère du film) à `land`.
	# o : "fall" (force de l'onde et du bruit), "kick" (talon qui remonte derrière), "tip" (reste sur la
	# pointe), "heel" (déroulé talon-pointe), "land" (inclinaison du pied à l'attaque).
	func step(side: int, lift: float, land: float, at: Vector3, h: float = 0.07, o: Dictionary = {}) -> void :
		var rows: Array = feet[side]
		if not rows.is_empty():
			var last: Array = rows[rows.size() - 1]
			if str(last[2]) == "plant": last[1] = maxf(float(last[0]), lift)
		var data: Dictionary = {"at": at, "heel": 0.5, "h": h, "fall": 1.0}
		data.merge(o, true)
		rows.append([land, INF, "plant", data])

	# Pied libre (saut, chute, coup) : clés [t, Vector3 position de la cheville en mètres dans le repère
	# du corps (x droite, y haut, z arrière ; y = 0 : au sol), inclinaison]. Le pied quitte son appui à
	# `lift` (par défaut à la première clé).
	func air(side: int, keys: Array, lift: float = -1.0) -> void :
		var rows: Array = feet[side]
		var t0: float = float(keys[0][0])
		if not rows.is_empty():
			var last: Array = rows[rows.size() - 1]
			if str(last[2]) == "plant": last[1] = maxf(float(last[0]), lift if lift >= 0.0 else t0)
		var source: Array = []
		for row: Array in keys: source.append([float(row[0]), {"f": row[1], "p": float(row[2]) if row.size() > 2 else 0.0}])
		var compiled: Dictionary = AnimClip.compile({"len": 1.0, "keys": source})
		rows.append([t0, float(keys[keys.size() - 1][0]), "free", {"track": compiled.channels, "h": 0.06}])

	func last_spot(side: int) -> Vector3:
		var rows: Array = feet[side]
		for i: int in range(rows.size() - 1, -1, -1):
			if str(rows[i][2]) == "plant": return rows[i][3].at
		return Vector3.ZERO

	func end_root() -> Vector3:
		return root[root.size() - 1][1] if not root.is_empty() else Vector3.ZERO

	func end_time() -> float:
		return float(root[root.size() - 1][0]) if not root.is_empty() else 0.0


static var _actors: Dictionary = {}
static var _build_ms: int = 0
static var _registered: bool = false


# Les clips ne sont construits qu'au lancement du prologue (register()) : la bibliothèque ne les voit
# qu'ensuite, sans rien coûter au démarrage du jeu.
static func add(c: Dictionary) -> void :
	if _actors.is_empty(): return
	for person: String in ["Simon", "Ashura"]:
		for row: Array in (_actors[person] as Actor).clips: c[str(row[0])] = row[2]


static func actor(person: String) -> Actor:
	if _actors.is_empty(): build()
	return _actors[person]


static func build() -> void :
	if not _actors.is_empty(): return
	var started: int = Time.get_ticks_msec()
	var s: Actor = Actor.new("Simon")
	var a: Actor = Actor.new("Ashura")
	_actors = {"Simon": s, "Ashura": a}
	_perform(s, a)
	for one: Actor in [s, a]: _bake(one)
	_build_ms = Time.get_ticks_msec() - started


# Construit les acteurs et range leurs clips (déjà compilés) dans AnimLibrary.
static func register() -> void :
	build()
	if _registered: return
	_registered = true
	if AnimLibrary._all.is_empty(): AnimLibrary._all = AnimLibrary._sources()
	for person: String in ["Simon", "Ashura"]:
		for row: Array in (_actors[person] as Actor).clips:
			var clip_name: String = str(row[0])
			AnimLibrary._all[clip_name] = row[2]
			AnimLibrary._owner[clip_name] = "film_prologue_a"
			AnimLibrary._cache[clip_name + "@" + person] = AnimClip.compile(row[2])




# --- Temps ---------------------------------------------------------------------------------------

static func scaled(t: float) -> float:
	var lost: float = 0.0
	for row: Array in SLOW:
		var a: float = float(row[0])
		if t <= a: continue
		lost += (minf(t, float(row[1])) - a) * (1.0 - float(row[2]))
	return t - lost


static func ease_u(u: float, mode: String) -> float:
	u = clampf(u, 0.0, 1.0)
	match mode:
		"linear": return u
		"in": return u * u
		"out": return 1.0 - (1.0 - u) * (1.0 - u)
		"in3": return u * u * u
		"out3": return 1.0 - pow(1.0 - u, 3.0)
		"hold": return 0.0 if u < 1.0 else 1.0
	return u * u * (3.0 - 2.0 * u)


static func _search(times: PackedFloat32Array, t: float) -> int:
	# Dernier indice i tel que times[i] <= t (ou -1).
	var lo: int = 0
	var hi: int = times.size() - 1
	if hi < 0 or t < times[0]: return -1
	if t >= times[hi]: return hi
	while hi - lo > 1:
		var mid: int = (lo + hi) >> 1
		if times[mid] <= t: lo = mid
		else: hi = mid
	return lo


# Échantillonnage d'une piste compilée par AnimClip (même interpolation que le moteur), avec recherche
# dichotomique.
static func _sample(track: Dictionary, t: float) -> Variant:
	var times: PackedFloat32Array = track.t
	var values: Array = track.v
	var count: int = times.size()
	if count == 1 or t <= times[0]: return values[0]
	if t >= times[count - 1]: return values[count - 1]
	var i: int = _search(times, t)
	var b: int = i + 1
	var span: float = maxf(times[b] - times[i], 0.0001)
	var u: float = clampf((t - times[i]) / span, 0.0, 1.0)
	var flag: int = track.f[i]
	if flag == AnimClip.FLAG_HOLD: return values[i]
	if flag == AnimClip.FLAG_LINEAR: return values[i] + (values[b] - values[i]) * u
	var u2: float = u * u
	var u3: float = u2 * u
	return values[i] * (2.0 * u3 - 3.0 * u2 + 1.0) + track.m[i] * ((u3 - 2.0 * u2 + u) * span) + values[b] * (-2.0 * u3 + 3.0 * u2) + track.m[b] * ((u3 - u2) * span)




# --- Évaluation des couches -----------------------------------------------------------------------

static func root_at(a: Actor, t: float) -> Vector3:
	if a.ready:
		var i: int = _search(a.root_t, t)
		if i < 0: return a.root_v[0]
		if i >= a.root_t.size() - 1: return a.root_v[a.root_v.size() - 1]
		var u: float = (t - a.root_t[i]) / maxf(0.0001, a.root_t[i + 1] - a.root_t[i])
		return (a.root_v[i] as Vector3).lerp(a.root_v[i + 1], u)
	# Pendant l'écriture (trajet pas encore figé).
	var rows: Array = a.root
	if rows.is_empty(): return Vector3.ZERO
	if t <= float(rows[0][0]): return rows[0][1]
	for k: int in range(rows.size() - 1, 0, -1):
		if t >= float(rows[k - 1][0]):
			if t >= float(rows[k][0]): return rows[k][1]
			var u: float = (t - float(rows[k - 1][0])) / maxf(0.0001, float(rows[k][0]) - float(rows[k - 1][0]))
			return (rows[k - 1][1] as Vector3).lerp(rows[k][1], u)
	return rows[0][1]


static func yaw_at(a: Actor, t: float) -> float:
	var rows: Array = a.yaw
	if rows.is_empty(): return PI
	var k: int = 0
	if a.ready:
		k = _search(a.yaw_t, t) + 1
	else:
		k = rows.size()
		for j: int in range(rows.size()):
			if float(rows[j][0]) > t:
				k = j
				break
	if k <= 0: return float(rows[0][1])
	if k >= rows.size(): return float(rows[rows.size() - 1][1])
	var from: Array = rows[k - 1]
	var to: Array = rows[k]
	var u: float = (t - float(from[0])) / maxf(0.0001, float(to[0]) - float(from[0]))
	return lerpf(float(from[1]), float(to[1]), ease_u(u, str(to[2])))


# Orientation réelle de la racine dans le film : chaque cible est rejointe en exponentielle (11/s en
# temps ralenti), comme PaperPrologue._step.
static func root_yaw_at(a: Actor, t: float) -> float:
	var rows: Array = a.aim_rows
	if rows.is_empty(): return yaw_at(a, t)
	var i: int = -1
	if a.ready: i = _search(a.aim_t, t)
	else:
		for k: int in range(rows.size()):
			if float(rows[k][0]) <= t: i = k
			else: break
	if i < 0: return float(rows[0][1])
	var row: Array = rows[i]
	var target: float = float(row[1])
	var gap: float = angle_difference(target, float(row[2]))
	return target + gap * exp( - YAW_RATE * (scaled(t) - float(row[3])))


static func local_of(a: Actor, t: float, world: Vector3) -> Vector3:
	return (world - root_at(a, t)).rotated(Vector3.UP, - yaw_at(a, t))


static func world_of(a: Actor, t: float, local: Vector3) -> Vector3:
	return root_at(a, t) + local.rotated(Vector3.UP, yaw_at(a, t))


static func _act(a: Actor, channel: String, t: float) -> Variant:
	if a.track.has(channel): return _sample(a.track[channel], t)
	return DEFAULTS.get(channel, 0.0)


static func _row_at(a: Actor, side: int, t: float) -> int:
	if a.ready: return _search(a.feet_t[side], t)
	var rows: Array = a.feet[side]
	var found: int = -1
	for k: int in range(rows.size()):
		if float(rows[k][0]) <= t: found = k
		else: break
	return found


static func _free_local(row: Array, t: float) -> Array:
	var track: Dictionary = row[3].track
	return [_sample(track.f, t), float(_sample(track.p, t)) if track.has("p") else 0.0]


# État d'un pied à l'instant t : [position de la cheville (mètres, repère du corps, y au-dessus du
# sol), inclinaison, part du poids portée, position dans le film].
static func foot_at(a: Actor, side: int, t: float) -> Array:
	var rows: Array = a.feet[side]
	if rows.is_empty(): return [Vector3(0.11 * float(side), 0.0, 0.0), 0.0, 1.0, world_of(a, t, Vector3(0.11 * float(side), 0.0, 0.0))]
	var k: int = _row_at(a, side, t)
	if k < 0:
		k = 0
		t = float(rows[0][0])
	var row: Array = rows[k]
	var t0: float = float(row[0])
	var t1: float = float(row[1])
	var data: Dictionary = row[3]
	if t <= t1:
		if str(row[2]) == "free":
			var state: Array = _free_local(row, t)
			return [state[0], state[1], 0.0, world_of(a, t, state[0])]
		var at: Vector3 = data.at
		var heel: float = float(data.heel)
		var pitch: float = 0.0
		var land: float = float(data.get("land", 0.22)) * heel
		if k > 0 and float(data.h) > 0.0: pitch = land * (1.0 - smoothstep(t0, t0 + 0.13, t))
		if data.has("tip"): pitch = minf(pitch, float(data.tip))
		var support: float = smoothstep(t0, t0 + 0.07, t) if k > 0 and float(data.h) > 0.0 else 1.0
		if t1 < INF:
			var roll: float = clampf(0.36 * (t1 - t0), 0.07, 0.3)
			pitch = minf(pitch, lerpf(0.0, - 0.62 * heel, smoothstep(t1 - roll, t1, t)))
			support *= 1.0 - smoothstep(t1 - roll * 0.6, t1, t)
		return [local_of(a, t, at), pitch, support, at]
	# Entre deux appuis : arc du pied libre.
	if k + 1 >= rows.size():
		var last: Array = foot_at(a, side, t1)
		return [local_of(a, t, last[3]), last[1], 0.0, last[3]]
	var next: Array = rows[k + 1]
	var t2: float = float(next[0])
	var from: Array = foot_at(a, side, t1)
	var to_data: Dictionary = next[3]
	var u: float = clampf((t - t1) / maxf(0.001, t2 - t1), 0.0, 1.0)
	var kick: float = float(to_data.get("kick", 0.0))
	var along: float = smoothstep(0.12 * minf(kick * 4.0, 1.0), 1.0, u)
	var h: float = float(to_data.get("h", 0.07))
	if str(next[2]) == "free":
		var start: Array = _free_local(next, t2)
		var local_from: Vector3 = local_of(a, t, from[3])
		var local: Vector3 = local_from.lerp(start[0], along)
		local.y = lerpf(local_from.y, (start[0] as Vector3).y, u) + h * 4.0 * u * (1.0 - u)
		return [local, lerpf(float(from[1]), float(start[1]), smoothstep(0.0, 0.7, u)), 0.0, world_of(a, t, local)]
	var to_world: Vector3 = to_data.at
	var to_pitch: float = float(to_data.get("land", 0.22)) * float(to_data.heel)
	var world: Vector3 = (from[3] as Vector3).lerp(to_world, along)
	world.y = lerpf((from[3] as Vector3).y, to_world.y, u) + h * 4.0 * u * (1.0 - u) * (1.1 - 0.2 * u)
	if kick > 0.0: world.y += kick * exp( - pow((u - 0.32) / 0.2, 2.0))
	var pitch: float = lerpf(float(from[1]), to_pitch, smoothstep(0.0, 0.62, u))
	if kick > 0.0: pitch -= kick * 2.2 * exp( - pow((u - 0.3) / 0.22, 2.0))
	return [local_of(a, t, world), pitch, 0.0, world]




# --- Conversions vers les unités des clips ----------------------------------------------------------

static func _foot_clip(a: Actor, side: int, local: Vector3, pitch: float) -> Vector3:
	var r: Vector3 = a.rest[side]
	var raise: float = a.toe * sin( - pitch) if pitch < 0.0 else 0.0
	var model: Vector3 = Vector3(local.x / a.scale, r.y + local.y / a.scale + raise, local.z / a.scale)
	return (model - r) / a.reach


static func _ankle_model(a: Actor, side: int, local: Vector3, pitch: float) -> Vector3:
	var r: Vector3 = a.rest[side]
	var raise: float = a.toe * sin( - pitch) if pitch < 0.0 else 0.0
	return Vector3(local.x / a.scale, r.y + local.y / a.scale + raise, local.z / a.scale)


# Hauteur de bassin la plus haute (mètres, relative au repos) qui laisse chaque jambe porteuse
# atteindre son pied (extension maximale `ext`) : pas de pied qui flotte, genoux jamais verrouillés.
static func _fit_hips(a: Actor, hips: Vector3, fl: Array, fr: Array, ext: float = 0.965) -> float:
	var y: float = hips.y
	for side: int in [-1, 1]:
		var state: Array = fl if side < 0 else fr
		var local: Vector3 = state[0]
		if local.y > 0.25: continue
		var ankle: Vector3 = _ankle_model(a, side, local, float(state[1]))
		var joint: Vector3 = a.hip[side] + Vector3(hips.x, 0.0, hips.z) / a.scale
		var flat: float = Vector2(joint.x - ankle.x, joint.z - ankle.z).length()
		var leg: float = a.reach * ext
		if flat >= leg: flat = leg * 0.98
		var top: float = ankle.y + sqrt(leg * leg - flat * flat)
		y = minf(y, (top - a.hip[side].y) * a.scale)
	return y




# --- Cuisson -------------------------------------------------------------------------------------

const COMPOSITE: Array[String] = ["hips", "body", "chest", "head", "ik_l", "ik_r", "turn"]
const TOLERANCE: Dictionary = {"hips": 0.0025, "body": 0.003, "chest": 0.003, "head": 0.003, "ik_l": 0.004, "ik_r": 0.004, "turn": 0.002, "foot": 0.0025, "pitch": 0.006}

static func _compile(a: Actor) -> void :
	a.root.sort_custom( func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	a.root_t = PackedFloat32Array()
	a.root_v = []
	for row: Array in a.root:
		a.root_t.append(float(row[0]))
		a.root_v.append(row[1])
	a.yaw.sort_custom( func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	a.yaw_t = PackedFloat32Array()
	for row: Array in a.yaw: a.yaw_t.append(float(row[0]))
	a.aims.sort_custom( func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	# Orientation réelle de la racine au moment de chaque nouvelle cible.
	a.aim_rows = []
	a.aim_t = PackedFloat32Array()
	for row: Array in a.aims:
		var t: float = float(row[0])
		var start: float = float(row[1]) if a.aim_rows.is_empty() else root_yaw_at(a, t)
		a.aim_rows.append([t, float(row[1]), start, scaled(t)])
		a.aim_t.append(t)
	for side: int in [-1, 1]:
		var times: PackedFloat32Array = PackedFloat32Array()
		for row: Array in a.feet[side]: times.append(float(row[0]))
		a.feet_t[side] = times
	a.acts.sort_custom( func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	var compiled: Dictionary = AnimClip.compile({"len": 1.0, "keys": a.acts})
	a.track = compiled.channels
	a.strings = compiled.strings
	a.ready = true
	for side: int in [-1, 1]:
		for k: int in range(a.feet[side].size()):
			var row: Array = a.feet[side][k]
			if str(row[2]) == "plant" and k > 0 and float(row[3].get("fall", 1.0)) > 0.0:
				a.falls.append([float(row[0]), side, row[3].at, float(row[3].get("fall", 1.0))])
	a.falls.sort_custom( func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))


# Canaux composés du corps (unités du moteur) à l'instant t du film : jeu d'acteur + appuis.
# fl, fr : états des pieds à t ; gl, gr : états des pieds un peu avant (retard du balancement des bras).
static func composite_at(a: Actor, t: float, fl: Array, fr: Array, gl: Array, gr: Array) -> Array:
	var loco: float = float(_act(a, "loco", t))
	var swing: float = float(_act(a, "swing", t))
	var hips: Vector3 = _act(a, "hips", t)
	var body: Vector3 = _act(a, "body", t)
	var chest: Vector3 = _act(a, "chest", t)
	var head: Vector3 = _act(a, "head", t)
	var ik_l: Vector3 = _act(a, "ik_l", t)
	var ik_r: Vector3 = _act(a, "ik_r", t)
	if loco > 0.001:
		var l: Vector3 = fl[0]
		var r: Vector3 = fr[0]
		var wl: float = float(fl[2])
		var wr: float = float(fr[2])
		var stride: float = (- l.z) - (- r.z)
		var pelvis: float = - 0.16 * a.twist * stride * loco
		var drop: float = 0.045 * (wr - wl) * loco
		body += Vector3(0.0, pelvis, drop)
		chest += Vector3(0.0, - pelvis * 2.1, - drop * 0.6)
		head += Vector3(0.0, pelvis * 1.0, - drop * 0.35)
		var weight: float = wl + wr
		if weight > 0.05: hips.x += (wl * l.x + wr * r.x) / weight * 0.28 * loco
		var spread: float = Vector2(l.x - r.x, l.z - r.z).length()
		hips.y -= maxf(0.0, spread - 0.24) * 0.05 * loco
	hips.y = _fit_hips(a, hips, fl, fr)
	if swing > 0.001:
		var diff: float = (- (gl[0] as Vector3).z) - (- (gr[0] as Vector3).z)
		var arm: float = clampf(diff * 0.55, -0.42, 0.42) * swing
		ik_l += Vector3(0.0, arm * arm * 0.35, arm)
		ik_r += Vector3(0.0, arm * arm * 0.35, - arm)
	var breath: float = float(_act(a, "breath", t))
	if breath > 0.001:
		var wave: float = sin(TAU * t * float(_act(a, "bf", t)))
		chest += Vector3( - 0.035 * breath * wave, 0.0, 0.0)
		head += Vector3(0.02 * breath * wave, 0.0, 0.0)
		hips.y += 0.004 * breath * wave
	return [hips / a.scale / a.reach, body, chest, head, ik_l, ik_r, angle_difference(root_yaw_at(a, t), yaw_at(a, t))]


# Pose composée à un instant isolé (outils, raccords).
static func pose_at(a: Actor, t: float) -> Array:
	return composite_at(a, t, foot_at(a, -1, t), foot_at(a, 1, t), foot_at(a, -1, t - 0.075), foot_at(a, 1, t - 0.075))


# Douglas-Peucker sur une suite [temps, valeur] : garde les clés nécessaires pour rester à moins de
# `tol` de la courbe échantillonnée (interpolation linéaire entre clés) ; `forced` : indices gardés
# d'office.
static func _simplify(times: PackedFloat32Array, values: PackedVector3Array, tol: float, forced: PackedByteArray) -> PackedByteArray:
	var n: int = times.size()
	var keep: PackedByteArray = PackedByteArray()
	keep.resize(n)
	keep.fill(0)
	if n == 0: return keep
	keep[0] = 1
	keep[n - 1] = 1
	for i: int in range(mini(n, forced.size())):
		if forced[i] == 1: keep[i] = 1
	var limit: float = tol * tol
	var stack: Array[Vector2i] = []
	var previous: int = 0
	for i: int in range(1, n):
		if keep[i] == 1:
			stack.append(Vector2i(previous, i))
			previous = i
	while not stack.is_empty():
		var segment: Vector2i = stack.pop_back()
		var i0: int = segment.x
		var i1: int = segment.y
		if i1 - i0 < 2: continue
		var from: Vector3 = values[i0]
		var to: Vector3 = values[i1]
		var start: float = times[i0]
		var inverse: float = 1.0 / maxf(0.0001, times[i1] - start)
		var worst: float = -1.0
		var at: int = -1
		for j: int in range(i0 + 1, i1):
			var d: float = values[j].distance_squared_to(from.lerp(to, (times[j] - start) * inverse))
			if d > worst:
				worst = d
				at = j
		if worst <= limit: continue
		keep[at] = 1
		stack.append(Vector2i(i0, at))
		stack.append(Vector2i(at, i1))
	return keep


static func _window_times(a: Actor, t0: float, t1: float, extra: Array) -> PackedFloat32Array:
	var times: Array = []
	var t: float = t0
	while t < t1 - 0.0001:
		times.append(t)
		t += GRID
	times.append(t1)
	for m: float in extra:
		if m > t0 + 0.004 and m < t1 - 0.004: times.append(m)
	times.sort()
	var out: PackedFloat32Array = PackedFloat32Array()
	var previous: float = -INF
	for at: float in times:
		if at - previous < 0.004: continue
		previous = at
		out.append(at)
	return out


static func _edges(a: Actor) -> Array:
	var edges: Array = []
	for side: int in [-1, 1]:
		for row: Array in a.feet[side]:
			edges.append(float(row[0]))
			if float(row[1]) < INF: edges.append(float(row[1]))
			if str(row[2]) == "plant" and float(row[1]) < INF:
				var roll: float = clampf(0.36 * (float(row[1]) - float(row[0])), 0.07, 0.3)
				edges.append(float(row[0]) + 0.13)
				edges.append(float(row[1]) - roll)
	return edges


static func _feet_keys(a: Actor, times: PackedFloat32Array, states: Dictionary, edges: Array, base: float, keys: Array) -> void :
	var count: int = times.size()
	for side: int in [-1, 1]:
		var channel: String = "foot_l" if side < 0 else "foot_r"
		var pitch_channel: String = "fp_l" if side < 0 else "fp_r"
		var rows: Array = a.feet[side]
		var list: Array = states[side]
		var values: PackedVector3Array = PackedVector3Array()
		var pitches: PackedVector3Array = PackedVector3Array()
		var stance: PackedByteArray = PackedByteArray()
		var forced: PackedByteArray = PackedByteArray()
		values.resize(count);pitches.resize(count);stance.resize(count);forced.resize(count)
		forced.fill(0)
		for i: int in range(count):
			var state: Array = list[i]
			values[i] = _foot_clip(a, side, state[0], float(state[1]))
			pitches[i] = Vector3(float(state[1]), 0.0, 0.0)
			var k: int = _row_at(a, side, times[i])
			stance[i] = 1 if k >= 0 and str(rows[k][2]) == "plant" and times[i] < float(rows[k][1]) - 0.0005 else 0
		for edge: float in edges:
			var j: int = _search(times, edge + 0.0005)
			if j >= 0 and absf(times[j] - edge) < 0.002: forced[j] = 1
		# Les bords d'appui sont gardés : les segments posés sont linéaires (pieds immobiles dans le film).
		for i: int in range(1, count):
			if stance[i] != stance[i - 1]:
				forced[i] = 1
				forced[i - 1] = 1
		var keep: PackedByteArray = _simplify(times, values, TOLERANCE.foot, forced)
		var keep_pitch: PackedByteArray = _simplify(times, pitches, TOLERANCE.pitch, forced)
		for i: int in range(count):
			if keep[i] == 0 and keep_pitch[i] == 0: continue
			var pose: Dictionary = {}
			if keep[i] == 1: pose[channel] = values[i]
			if keep_pitch[i] == 1: pose[pitch_channel] = pitches[i].x
			keys.append([scaled(times[i]) - base, pose, "l"])


static func _bake(a: Actor) -> void :
	_compile(a)
	a.cuts.sort()
	if a.cuts.is_empty() or float(a.cuts[0]) > 0.0: a.cuts.push_front(0.0)
	if float(a.cuts[a.cuts.size() - 1]) < HOLD_END: a.cuts.append(HOLD_END)
	var marks: Array = _edges(a)
	for row: Array in a.acts: marks.append(float(row[0]))
	for i: int in range(a.cuts.size() - 1):
		var t0: float = float(a.cuts[i])
		# Le clip déborde sur le suivant (OVERLAP) : il ne s'arrête jamais une image trop tôt (sinon le
		# moteur montrerait sa pose « en l'air »), le clip suivant le remplace à son instant de départ.
		var t1: float = float(a.cuts[i + 1]) + OVERLAP
		var base: float = scaled(t0)
		var keys: Array = []
		var times: PackedFloat32Array = _window_times(a, t0, t1, marks)
		var count: int = times.size()
		var states: Dictionary = {-1: [], 1: []}
		for side: int in [-1, 1]:
			var list: Array = states[side]
			list.resize(count)
			for j: int in range(count): list[j] = foot_at(a, side, times[j])
		# Canaux composés : échantillonnés serré, puis simplifiés canal par canal.
		var dense: Array[PackedVector3Array] = []
		for c: int in range(COMPOSITE.size()):
			var column: PackedVector3Array = PackedVector3Array()
			column.resize(count)
			dense.append(column)
		for j: int in range(count):
			var at: float = times[j]
			var lag: int = _search(times, at - 0.075)
			var gl: Array = states[-1][lag] if lag >= 0 else foot_at(a, -1, at - 0.075)
			var gr: Array = states[1][lag] if lag >= 0 else foot_at(a, 1, at - 0.075)
			var values: Array = composite_at(a, at, states[-1][j], states[1][j], gl, gr)
			for c: int in range(COMPOSITE.size() - 1): dense[c][j] = values[c]
			dense[COMPOSITE.size() - 1][j] = Vector3(float(values[COMPOSITE.size() - 1]), 0.0, 0.0)
		var none: PackedByteArray = PackedByteArray()
		for c: int in range(COMPOSITE.size()):
			var channel: String = COMPOSITE[c]
			var keep: PackedByteArray = _simplify(times, dense[c], float(TOLERANCE[channel]), none)
			var column: PackedVector3Array = dense[c]
			for j: int in range(count):
				if keep[j] == 0: continue
				var value: Variant = column[j].x if channel == "turn" else column[j]
				keys.append([scaled(times[j]) - base, {channel: value}, "l"])
		# Canaux de jeu purs : les clés écrites, plus les bords de la fenêtre.
		for channel: String in DEFAULTS:
			if channel in INTERNAL or channel in COMPOSITE: continue
			_direct_keys(a, channel, t0, t1, base, keys)
		for channel: String in OPTIONAL:
			if a.track.has(channel): _direct_keys(a, channel, t0, t1, base, keys)
		_feet_keys(a, times, states, marks, base, keys)
		for channel: String in a.strings:
			var list: Array = a.strings[channel]
			if channel == "face":
				var current: String = AnimClip.sample_string(list, t0)
				if not current.is_empty(): keys.append([0.0, {"face": current}])
			for entry: Array in list:
				var at: float = float(entry[0])
				if at < t0 - 0.0001 or at >= t1 - 0.0001: continue
				if channel == "face" and at <= t0 + 0.0001: continue
				keys.append([maxf(0.0, scaled(at) - base), {channel: str(entry[1])}])
		keys.sort_custom( func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
		var length: float = maxf(0.05, scaled(t1) - base)
		var name_value: String = "pa_%s%02d" % [a.tag, i]
		a.clips.append([name_value, t0, {"len": length, "in": 0.0, "out": 0.0, "face": "", "keys": keys}])


static func _direct_keys(a: Actor, channel: String, t0: float, t1: float, base: float, keys: Array) -> void :
	if not a.track.has(channel):
		keys.append([0.0, {channel: DEFAULTS[channel]}])
		return
	var track: Dictionary = a.track[channel]
	var times: PackedFloat32Array = track.t
	var start_flag: String = ""
	var i0: int = _search(times, t0)
	if i0 >= 0 and i0 < times.size() - 1:
		match int(track.f[i0]):
			AnimClip.FLAG_LINEAR: start_flag = "l"
			AnimClip.FLAG_HOLD: start_flag = "h"
	var first: Array = [0.0, {channel: _sample(track, t0)}]
	if not start_flag.is_empty(): first.append(start_flag)
	keys.append(first)
	for k: int in range(times.size()):
		var at: float = times[k]
		if at <= t0 + 0.0005 or at >= t1 - 0.0005: continue
		var row: Array = [scaled(at) - base, {channel: track.v[k]}]
		match int(track.f[k]):
			AnimClip.FLAG_STOP: row.append("s")
			AnimClip.FLAG_LINEAR: row.append("l")
			AnimClip.FLAG_HOLD: row.append("h")
		keys.append(row)
	keys.append([scaled(t1) - base, {channel: _sample(track, t1)}])




# --- Outils d'écriture -------------------------------------------------------------------------------

static func dir_of(angle: float) -> Vector3:
	return Vector3( - sin(angle), 0.0, - cos(angle))


static func angle_to(from: Vector3, to: Vector3) -> float:
	var d: Vector3 = to - from
	return atan2( - d.x, - d.z)


# Trajet de la racine de la position courante jusqu'à `to`, entre t0 et t1, clés serrées.
static func travel(a: Actor, t0: float, t1: float, to: Vector3, mode: String = "smooth") -> void :
	var from: Vector3 = a.end_root()
	if a.root.is_empty() or a.end_time() < t0 - 0.0001: a.go(t0, from)
	var n: int = maxi(1, ceili((t1 - t0) / GRID))
	for k: int in range(1, n + 1):
		var u: float = float(k) / float(n)
		a.go(t0 + (t1 - t0) * u, from.lerp(to, ease_u(u, mode)))


# Courbe de Bézier quadratique (contrôle c) pour un trajet qui tourne.
static func travel_curve(a: Actor, t0: float, t1: float, c: Vector3, to: Vector3, mode: String = "smooth") -> void :
	var from: Vector3 = a.end_root()
	if a.root.is_empty() or a.end_time() < t0 - 0.0001: a.go(t0, from)
	var n: int = maxi(1, ceili((t1 - t0) / GRID))
	for k: int in range(1, n + 1):
		var u: float = ease_u(float(k) / float(n), mode)
		var p: Vector3 = from.lerp(c, u).lerp(c.lerp(to, u), u)
		a.go(t0 + (t1 - t0) * float(k) / float(n), p)


# Pas réguliers sous la racine : premier appui du pied `side` à `first`, puis un pas tous les
# `period` s ; chaque pied se pose là où la racine passera au milieu de son appui (il porte le corps
# pendant que celui-ci passe au-dessus). o : "stance" (part d'appui d'un cycle, 0,6 marche, 0,35
# course), "width" (écart latéral), "h", "kick", "heel", "jitter" (variations de cadence et
# d'appui), "seed", "fall".
static func strides(a: Actor, side: int, first: float, period: float, count: int, o: Dictionary = {}) -> float:
	var stance: float = float(o.get("stance", 0.6)) * 2.0 * period
	var width: float = float(o.get("width", 0.105))
	var h: float = float(o.get("h", 0.07))
	var jitter: float = float(o.get("jitter", 0.04))
	var seed_value: int = int(o.get("seed", 3))
	var end_at: float = float(o.get("stop", INF))
	var t: float = first
	var last: float = first
	for k: int in range(count):
		var foot: int = side if k % 2 == 0 else - side
		var wobble: float = noise(seed_value, k)
		var tc: float = t + period * jitter * wobble * 0.6
		var mid: float = minf(tc + stance * 0.5, end_at)
		var spot: Vector3 = world_of(a, mid, Vector3(float(foot) * width * (1.0 + 0.12 * noise(seed_value + 7, k)), 0.0, 0.0))
		spot.y = 0.0
		var swing: float = 2.0 * period - stance
		var lift: float = tc - swing * (1.0 + 0.05 * noise(seed_value + 3, k))
		var step_o: Dictionary = {"heel": float(o.get("heel", 0.5)), "kick": float(o.get("kick", 0.0)), "fall": float(o.get("fall", 1.0)) * (1.0 + 0.15 * wobble)}
		if o.has("land"): step_o["land"] = float(o.land)
		a.step(foot, lift, tc, spot, h * (1.0 + 0.15 * noise(seed_value + 11, k)), step_o)
		last = tc
		t += period
	return last


# Petit pas d'ajustement : le pied `side` se décale de `delta` (repère du corps à l'instant `land`).
static func shuffle(a: Actor, side: int, lift: float, land: float, delta: Vector3, h: float = 0.05, o: Dictionary = {}) -> void :
	var spot: Vector3 = a.last_spot(side) + delta.rotated(Vector3.UP, yaw_at(a, land))
	spot.y = 0.0
	var options: Dictionary = {"fall": 0.5}
	options.merge(o, true)
	a.step(side, lift, land, spot, h, options)


# Pied posé à une position du repère du corps (relative à la racine à l'instant `land`).
static func step_to(a: Actor, side: int, lift: float, land: float, local: Vector3, h: float = 0.06, o: Dictionary = {}) -> void :
	var spot: Vector3 = world_of(a, land, local)
	spot.y = 0.0
	a.step(side, lift, land, spot, h, o)


static func noise(seed_value: int, k: int) -> float:
	var h: int = absi((seed_value * 73856093) ^ (k * 19349663) ^ (k * k * 83492791))
	return float(h % 10007) / 10006.0 * 2.0 - 1.0


# Orientation tête + buste pour regarder un point du film depuis la position du corps à l'instant t
# (le buste prend `chest` du lacet, la tête le reste ; la tête lève ou baisse).
static func look(a: Actor, t: float, target: Vector3, chest: float = 0.25, height: float = 1.5) -> Dictionary:
	var from: Vector3 = root_at(a, t) + Vector3.UP * height
	var d: Vector3 = (target - from).rotated(Vector3.UP, - yaw_at(a, t))
	var turn: float = atan2( - d.x, - d.z)
	var up: float = atan2(d.y, Vector2(d.x, d.z).length())
	return {"chest": Vector3( - up * 0.25, turn * chest, 0.0), "head": Vector3(up * 0.75, turn * (1.0 - chest), 0.0)}




# --- Le film -------------------------------------------------------------------------------------

static func _perform(s: Actor, a: Actor) -> void :
	_act1(s, a)
	for one: Actor in [s, a]:
		if one.end_time() < HOLD_END: one.go(HOLD_END, one.end_root())


static func _act1(s: Actor, a: Actor) -> void :
	# Départ dans le noir, côte à côte, face au fond de la dimension (+z, lacet PI).
	s.go(0.0, Vector3(-0.75, 0, -30.0));a.go(0.0, Vector3(0.8, 0, -29.6))
	for one: Actor in [s, a]:
		one.face(0.0, PI);one.aim(0.0, PI)
		one.plant(-1, 0.0, world_of(one, 0.0, Vector3(-0.1, 0, 0.02)))
		one.plant(1, 0.0, world_of(one, 0.0, Vector3(0.11, 0, -0.03)))
		one.cut(0.0)
	travel(s, 3.4, 25.3, Vector3(-0.7, 0, -9.6), "smooth")
	travel(a, 3.7, 25.6, Vector3(0.85, 0, -9.3), "smooth")
	strides(s, 1, 3.95, 0.62, 35, {"width": 0.1, "h": 0.07, "seed": 5, "stop": 25.3})
	strides(a, -1, 4.25, 0.66, 33, {"width": 0.12, "h": 0.065, "seed": 9, "stop": 25.6})
	for one: Actor in [s, a]:
		one.key(0.0, M([{"loco": 1.0, "swing": 0.6, "curl": 0.55, "curl_l": 0.55, "face": "focus"}]))
		one.cut(12.0);one.cut(17.0);one.cut(24.0)
