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
	"Simon": {"tag": "s", "reach": 0.911139, "scale": 0.767544, "foot_l": Vector3(-0.1425, 0.15586, 0.035625), "foot_r": Vector3(0.133594, 0.155859, 0.035625), "hip_y": 1.064297, "hip_x": 0.106875, "toe": 0.136239, "twist": 1.0,
		"sh_l": Vector3(-0.178125, 1.491797, 0.026719), "sh_r": Vector3(0.169219, 1.491797, 0.026719), "arm_l": 0.535053, "arm_r": 0.522873},
	"Ashura": {"tag": "a", "reach": 0.864776, "scale": 0.745614, "foot_l": Vector3(-0.243224, 0.114758, -0.037701), "foot_r": Vector3(0.250444, 0.097185, 0.089592), "hip_y": 0.961632, "hip_x": 0.133182, "toe": 0.056956, "twist": 1.15,
		"sh_l": Vector3(-0.262653, 1.550927, 0.015823), "sh_r": Vector3(0.221293, 1.592261, -0.03105), "arm_l": 0.575773, "arm_r": 0.629074},
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
	var shoulder: Dictionary = {}
	var arm: Dictionary = {}
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
		shoulder[-1] = rig.sh_l;shoulder[1] = rig.sh_r
		arm[-1] = float(rig.arm_l);arm[1] = float(rig.arm_r)

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
	_hold_defaults(a)
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


# Avant sa première clé, un canal vaut sa valeur de repos (sinon l'interpolation rendrait la valeur de
# cette première clé depuis le début du film : un « sq » ou un « gsnap » écrit à 64 s agirait dès 0 s).
# La valeur de repos tient jusqu'à HOLD_LEAD avant la première clé (clé d'arrêt, sans dépassement).
const HOLD_LEAD: float = 0.2

static func _hold_defaults(a: Actor) -> void :
	var first: Dictionary = {}
	for row: Array in a.acts:
		for channel: String in (row[1] as Dictionary):
			if not first.has(channel): first[channel] = float(row[0])
	var extra: Array = []
	for channel: String in first:
		if channel in AnimClip.STRING_CHANNELS: continue
		var at: float = float(first[channel])
		if at <= 0.0001: continue
		var value: Variant = DEFAULTS.get(channel, Vector3.ZERO)
		extra.append([0.0, {channel: value}, "s"])
		if at - HOLD_LEAD > 0.0001: extra.append([at - HOLD_LEAD, {channel: value}, "s"])
	a.acts.append_array(extra)
	a.acts.sort_custom( func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))


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
			# Jambes au repos sous le clip (le clip « air » du moteur, joué quand le corps n'est pas « au
			# sol », les replierait) : l'IK des pieds les repose ensuite sur les appuis, et « gsnap »
			# mesure le point le plus bas sur ce corps-là.
			elif channel in AnimClip.LEG_CHANNELS: keys.append([0.0, {channel: Vector3.ZERO}])
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


# Épaule (repère du film) à l'instant t, bassin décalé de `hips` (mètres, repère du corps).
static func shoulder_world(a: Actor, t: float, side: int, hips: Vector3 = Vector3.ZERO) -> Vector3:
	var local: Vector3 = (a.shoulder[side] as Vector3) * a.scale + hips
	return root_at(a, t) + local.rotated(Vector3.UP, yaw_at(a, t))


# Cible de main (canal ik_l / ik_r, longueurs de bras, repère du corps) qui pose la main sur un point du
# film ; tronquée à `stretch` longueurs de bras (bras presque tendu).
static func reach(a: Actor, t: float, side: int, world: Vector3, hips: Vector3 = Vector3.ZERO, stretch: float = 0.97) -> Dictionary:
	var d: Vector3 = (world - shoulder_world(a, t, side, hips)).rotated(Vector3.UP, - yaw_at(a, t)) / ((a.arm[side] as float) * a.scale)
	if d.length() > stretch: d = d.normalized() * stretch
	var tag: String = "l" if side < 0 else "r"
	return {"ik_" + tag: d, "el_" + tag: 0.0, "tf_" + tag: 0.0, "gr_" + tag: 0.0}


# Position (repère du film) de la main pour une cible ik donnée.
static func hand_world(a: Actor, t: float, side: int, ik: Vector3, hips: Vector3 = Vector3.ZERO) -> Vector3:
	return shoulder_world(a, t, side, hips) + (ik * (a.arm[side] as float) * a.scale).rotated(Vector3.UP, yaw_at(a, t))


# Orientation tête + buste pour regarder un point du film depuis la position du corps à l'instant t
# (le buste prend `chest` du lacet, la tête le reste ; la tête lève ou baisse).
static func look(a: Actor, t: float, target: Vector3, chest: float = 0.25, height: float = 1.5) -> Dictionary:
	var from: Vector3 = root_at(a, t) + Vector3.UP * height
	var d: Vector3 = (target - from).rotated(Vector3.UP, - yaw_at(a, t))
	var turn: float = atan2( - d.x, - d.z)
	var up: float = atan2(d.y, Vector2(d.x, d.z).length())
	return {"chest": Vector3( - up * 0.25, turn * chest, 0.0), "head": Vector3(up * 0.75, turn * (1.0 - chest), 0.0)}


# --- Le film -------------------------------------------------------------------------------------

# Trajet à vitesse de croisière : accélération sur `accel` s, freinage sur `brake` s.
static func walk_to(a: Actor, t0: float, t1: float, to: Vector3, accel: float = 0.8, brake: float = 0.7) -> void :
	var from: Vector3 = a.end_root()
	if a.root.is_empty() or a.end_time() < t0 - 0.0001: a.go(t0, from)
	var total: float = maxf(0.05, t1 - t0)
	var ta: float = clampf(accel / total, 0.0, 0.5)
	var tb: float = clampf(brake / total, 0.0, 0.5)
	var cruise: float = 1.0 / maxf(0.05, 1.0 - ta * 0.5 - tb * 0.5)
	var n: int = maxi(1, ceili(total / GRID))
	for k: int in range(1, n + 1):
		var u: float = float(k) / float(n)
		var p: float = 0.0
		if u < ta: p = cruise * u * u / (2.0 * ta)
		elif u > 1.0 - tb: p = 1.0 - cruise * (1.0 - u) * (1.0 - u) / (2.0 * tb)
		else: p = cruise * (u - ta * 0.5)
		a.go(t0 + total * u, from.lerp(to, clampf(p, 0.0, 1.0)))


# Rotation du corps entre t0 et t1 (lacet voulu) ; la racine du film suit en deux cibles pour ne jamais
# lui demander un demi-tour d'un coup (sens ambigu).
static func pivot(a: Actor, t0: float, t1: float, to: float, mode: String = "smooth") -> void :
	var from: float = yaw_at(a, t0)
	a.face(t0, from)
	a.face(t1, to, mode)
	if absf(to - from) > 1.2: a.aim(lerpf(t0, t1, 0.45), lerpf(from, to, 0.6))
	a.aim(t1, to)


static func hang_l(out: float = 0.12, fwd: float = 0.06, up: float = -0.92) -> Dictionary:
	return L(out, up, fwd, 0.0)


static func hang_r(out: float = 0.12, fwd: float = 0.06, up: float = -0.92) -> Dictionary:
	return R(out, up, fwd, 0.0)


static func _perform(s: Actor, a: Actor) -> void :
	_act1(s, a)
	_act2(s, a)
	_act3(s, a)
	for one: Actor in [s, a]:
		if one.end_time() < HOLD_END: one.go(HOLD_END, one.end_root())


# Acte I (0 → 30 s) : marche prudente dans l'encre, l'onde lointaine (9,4), regards, répliques, les
# trois battements (25,0 / 26,2 / 27,4) : Simon s'arrête, fait volte-face, Ashura se retourne aussi.
static func _act1(s: Actor, a: Actor) -> void :
	s.go(0.0, Vector3(-0.55, 0, -30.0));a.go(0.0, Vector3(0.55, 0, -29.45))
	for one: Actor in [s, a]:
		one.face(0.0, PI);one.aim(0.0, PI)
		one.plant(-1, 0.0, world_of(one, 0.0, Vector3(-0.1, 0, 0.03)))
		one.plant(1, 0.0, world_of(one, 0.0, Vector3(0.11, 0, -0.04)))
		for t: float in [0.0, 12.0, 17.0, 24.0, 30.0]: one.cut(t)

	# Simon : marche, s'arrête net à l'onde lointaine, repart, freine au premier battement.
	walk_to(s, 3.35, 9.75, Vector3(-0.53, 0, -24.55), 0.9, 0.75)
	strides(s, 1, 3.9, 0.6, 10, {"width": 0.1, "h": 0.07, "seed": 5, "stop": 9.75})
	walk_to(s, 10.7, 25.15, Vector3(-0.5, 0, -10.65), 0.75, 0.8)
	strides(s, 1, 11.12, 0.6, 24, {"width": 0.1, "h": 0.07, "seed": 6, "stop": 25.15})
	# Ashura : même chemin, plus posé ; il ralentit à peine quand Simon s'arrête.
	walk_to(a, 3.7, 10.05, Vector3(0.57, 0, -24.0), 0.9, 0.85)
	strides(a, -1, 4.28, 0.66, 9, {"width": 0.12, "h": 0.06, "seed": 9, "stop": 10.05})
	walk_to(a, 10.55, 25.55, Vector3(0.6, 0, -10.0), 0.8, 0.9)
	strides(a, 1, 11.02, 0.66, 22, {"width": 0.12, "h": 0.06, "seed": 10, "stop": 25.55})

	# --- Simon : posture de marche (épaules un peu hautes, poings à demi serrés), regard qui balaie.
	var s_walk: Dictionary = M([{"loco": 1.0, "swing": 0.55, "curl": 0.55, "curl_l": 0.5}, B(0.05), C(0.07), hang_l(0.15, 0.1, -0.88), hang_r(0.15, 0.1, -0.88), WL(0.15, 0.0, -0.1), WR(0.15, 0.0, 0.1)])
	s.key(0.0, M([s_walk, {"loco": 0.0, "swing": 0.0, "face": "focus"}, HD(-0.05, 0.0, 0.0)]))
	s.key(3.3, M([{"loco": 0.0, "swing": 0.0}, HD(-0.05, 0.05)]))
	s.key(3.9, M([{"loco": 1.0, "swing": 0.55}, HD(-0.02, 0.18)]))
	s.key(5.6, M([HD(0.0, -0.22, 0.03)]))
	s.key(7.4, M([HD(-0.04, 0.08)]))
	s.key(8.6, M([HD(-0.03, -0.05)]))
	# 9,4 : l'encre frémit au loin. Arrêt, tête qui se lève vers l'avant-droite, bras qui se figent.
	s.key(9.45, M([HD(-0.02, -0.05), {"face": "focus"}]))
	s.key(9.7, M([HD(0.1, -0.32, -0.06), C(0.04, -0.06), {"swing": 0.0, "face": "surprise"}]))
	s.key(9.95, M([{"loco": 0.3}, hang_l(0.18, 0.18, -0.82), hang_r(0.18, 0.2, -0.8), {"curl": 0.7, "curl_l": 0.65, "ev": "gasp"}]))
	s.key(10.4, M([HD(0.08, -0.36, -0.05), {"face": "fear"}]))
	s.key(10.75, M([HD(0.0, -0.12, 0.0), C(0.07, 0.0), {"loco": 1.0}]))
	s.key(11.15, M([{"swing": 0.45}, hang_l(0.15, 0.12, -0.86), hang_r(0.15, 0.12, -0.86)]))
	s.key(12.2, M([HD(-0.06, 0.12), {"face": "focus"}]))
	s.key(14.0, M([HD(-0.03, -0.1)]))
	s.key(15.6, M([HD(-0.05, 0.06)]))
	# 17 → 24 : plan à deux de face. Le regard balaie, s'accroche à Ashura quand il parle.
	s.key(16.9, M([HD(-0.02, 0.32, 0.04), C(0.07, 0.08), {"face": "sad"}]))
	s.key(18.05, M([HD(0.02, 0.36, 0.05)]))
	s.key(18.6, M([HD(-0.04, -0.42, -0.04), C(0.07, -0.1)]))
	s.key(19.55, M([HD(-0.02, -0.36, -0.03)]))
	s.key(20.0, M([HD(-0.05, -0.02, 0.0), C(0.07, 0.0)]))
	s.key(20.95, M([HD(-0.06, 0.5, 0.06), C(0.06, 0.12), {"face": "fear"}]))
	s.key(22.4, M([HD(-0.05, 0.42, 0.05)]))
	s.key(22.85, M([HD(-0.03, -0.04, 0.0), C(0.07, 0.0), {"face": "sad"}]))
	s.key(23.7, M([HD(-0.01, -0.2)]))
	# 25,0 : premier battement. Simon freine, se fige, tête qui se penche pour écouter.
	s.key(24.7, M([HD(-0.02, -0.05)]))
	s.key(25.05, M([HD(0.03, 0.1, 0.1), {"face": "surprise", "swing": 0.2}, hang_l(0.18, 0.16, -0.84), hang_r(0.18, 0.16, -0.84), {"curl": 0.75, "curl_l": 0.7}]))
	s.key(25.5, M([HD(0.05, 0.18, 0.16), C(0.04, 0.05), B(0.03), H(0.0, -0.025, 0.0), {"loco": 0.0, "swing": 0.0, "shake": 0.15}]))
	s.key(26.15, M([HD(0.04, 0.2, 0.14), H(0.0, -0.03, 0.0), {"face": "fear"}]))
	# 26,2 : deuxième battement. Volte-face vers la gauche (vers Ashura et le chemin parcouru), en deux pas.
	pivot(s, 26.2, 26.82, 2.0 * PI, "out")
	step_to(s, 1, 26.24, 26.52, Vector3(0.1, 0, 0.06), 0.09, {"fall": 0.8, "heel": 0.2})
	step_to(s, -1, 26.44, 26.78, Vector3(-0.12, 0, -0.03), 0.07, {"fall": 0.6, "heel": 0.25})
	s.key(26.2, M([HD(0.06, 0.55, 0.06), C(0.05, 0.15), H(0.0, -0.05, 0.0), {"ev": "gasp", "shake": 0.0}]))
	s.key(26.36, M([HD(0.0, 0.35, 0.0), C(0.02, 0.2), B(0.0, 0.1), H(0.0, -0.07, 0.02), L(0.32, -0.62, 0.15, 0.3), R(0.3, -0.55, 0.3, 0.3), {"curl": 0.4, "curl_l": 0.4, "face": "surprise"}]))
	s.key(26.6, M([HD(-0.02, 0.05, -0.03), C(0.06, 0.05), B(0.04, 0.0), H(0.0, -0.06, 0.0), L(0.22, -0.55, 0.32, 0.2), R(0.18, -0.5, 0.38, 0.2), {"curl": 0.7, "curl_l": 0.7}]))
	s.key(26.85, M([HD(-0.04, -0.62, -0.04), C(0.06, -0.12), {"face": "fear"}]))
	# « Attends. » : main droite levée, paume vers Ashura (à sa droite maintenant). 27,4 : troisième
	# battement, il sursaute, tête rentrée. « T'as entendu, là ? » : main au casque, tête penchée pour
	# écouter, l'autre main agrippée au sweat ; puis le silence (29 → 30) : il ne respire plus.
	s.key(26.98, M([R(0.3, -0.2, 0.36, 0.25), WR(-0.35, 0.0, 0.2), {"curl": 0.35}]))
	s.key(27.15, M([HD(-0.03, -0.7, -0.05), R(0.38, -0.08, 0.42, 0.2), WR(-0.75, 0.0, 0.25), {"curl": 0.08}]))
	s.key(27.32, M([R(0.37, -0.07, 0.43, 0.2), WR(-0.7, 0.0, 0.25)]))
	s.key(27.4, M([HD(-0.12, -0.42, 0.04), H(0.0, -0.1, 0.0), C(0.14, -0.08), B(0.06), L(0.14, -0.3, 0.32, 0.35), R(0.12, -0.22, 0.3, 0.4), WR(0.2), {"ev": "gasp", "shake": 0.4, "curl": 0.8, "curl_l": 0.85}]), "s")
	s.key(27.62, M([HD(-0.08, -0.3, 0.06), H(0.0, -0.08, 0.0), C(0.1, -0.05), {"shake": 0.3}]))
	s.key(27.95, M([HD(-0.02, -0.16, 0.2), C(0.08, -0.04), Rt(0.04, 0.44, 0.1, 0.75), WR(0.35, 0.2, 0.0), Lt(-0.02, -0.28, 0.32, 0.2), WL(0.2), {"curl": 0.45, "curl_l": 0.95, "shake": 0.22, "breath": 1.0, "bf": 1.1}]))
	s.key(28.45, M([HD(0.0, 0.12, 0.22), Rt(0.05, 0.46, 0.08, 0.75)]))
	s.key(28.9, M([HD(-0.03, 0.2, 0.16), {"shake": 0.16}]))
	s.key(29.15, M([HD(-0.05, 0.02, 0.1), Rt(0.06, 0.42, 0.1, 0.7), {"breath": 0.0, "shake": 0.12}]))
	s.key(29.7, M([HD(-0.06, 0.04, 0.05)]))

	# --- Ashura : marche posée, bras qui balancent peu ; le drone (appareil) consulté pendant sa réplique.
	var a_walk: Dictionary = M([{"loco": 1.0, "swing": 0.35, "curl": 0.4, "curl_l": 0.35}, B(0.02), C(0.03), hang_l(0.1, 0.04, -0.93), hang_r(0.1, 0.04, -0.93)])
	a.key(0.0, M([a_walk, {"loco": 0.0, "swing": 0.0, "face": "focus"}, HD(-0.06, 0.0)]))
	a.key(3.65, M([{"loco": 0.0, "swing": 0.0}]))
	a.key(4.25, M([{"loco": 1.0, "swing": 0.35}, HD(-0.04, -0.06)]))
	a.key(6.8, M([HD(-0.05, 0.05)]))
	a.key(9.55, M([HD(-0.05, 0.0)]))
	a.key(9.9, M([HD(0.04, -0.16), {"swing": 0.1}]))
	a.key(10.3, M([HD(0.03, -0.2), {"loco": 0.5}]))
	a.key(10.9, M([HD(-0.04, -0.04), {"loco": 1.0, "swing": 0.35}]))
	a.key(13.5, M([HD(-0.06, 0.06)]))
	a.key(16.8, M([HD(-0.05, -0.04), {"face": "focus"}]))
	# 20,3 → 23,1 : il sort l'appareil, le consulte, tapote, le range.
	a.key(19.95, M([hang_r(0.1, 0.04, -0.93), WR(0.0), {"curl": 0.4, "swing": 0.35}]))
	a.key(20.35, M([R(0.05, -0.62, 0.3, 0.15), WR(0.4, 0.0, 0.0), {"swing": 0.0, "curl": 0.55, "prop": "camera"}, HD(-0.12, -0.1)]))
	a.key(20.7, M([R(-0.05, -0.42, 0.4, 0.2), WR(0.7, -0.2, 0.0), HD(-0.42, -0.14), C(0.08, -0.08), {"curl": 0.62}]))
	a.key(21.5, M([HD(-0.45, -0.12), {"curl": 0.5}]))
	a.key(21.65, M([{"curl": 0.66}]))
	a.key(21.9, M([HD(-0.4, -0.13), {"curl": 0.55}]))
	a.key(22.35, M([R(-0.04, -0.44, 0.38, 0.2), HD(-0.2, -0.05), {"face": "calm"}]))
	a.key(22.75, M([R(0.04, -0.6, 0.28, 0.12), WR(0.4), HD(-0.05, 0.02), C(0.03, 0.0)]))
	a.key(23.15, M([hang_r(0.1, 0.04, -0.93), WR(0.0), {"curl": 0.4, "swing": 0.35, "prop": ""}, {"face": "focus"}]))
	a.key(24.4, M([HD(-0.04, 0.05)]))
	# Battements : il s'arrête un pas après Simon, tête droite, écoute ; se retourne au troisième.
	a.key(25.1, M([HD(0.02, -0.1), {"swing": 0.15}]))
	a.key(25.6, M([HD(0.03, -0.18, -0.04), {"loco": 0.0, "swing": 0.0, "curl": 0.55, "curl_l": 0.5}, hang_l(0.14, 0.12, -0.88), hang_r(0.14, 0.12, -0.88)]))
	a.key(26.3, M([HD(0.0, -0.42, -0.05), C(0.03, -0.15), {"face": "surprise"}]))
	a.key(26.7, M([HD(-0.02, -0.55, -0.04), C(0.03, -0.18), {"face": "focus"}]))
	pivot(a, 26.95, 27.55, 0.0, "smooth")
	step_to(a, 1, 26.98, 27.3, Vector3(0.13, 0, 0.05), 0.06, {"fall": 0.6, "heel": 0.3})
	step_to(a, -1, 27.2, 27.55, Vector3(-0.13, 0, -0.02), 0.06, {"fall": 0.5, "heel": 0.3})
	a.key(27.0, M([HD(-0.02, -0.3), C(0.03, -0.1)]))
	a.key(27.42, M([HD(0.05, 0.1, 0.0), C(0.06, 0.0), H(0.0, -0.06, 0.0), L(0.2, -0.6, 0.25, 0.2), R(0.2, -0.58, 0.28, 0.2), {"curl": 0.85, "curl_l": 0.8, "ev": "grunt"}]))
	a.key(27.9, M([HD(0.0, 0.12), H(0.0, -0.04, 0.0), C(0.04, 0.0), L(0.18, -0.66, 0.2, 0.15), R(0.18, -0.64, 0.22, 0.15)]))
	a.key(28.6, M([HD(0.02, -0.15)]))
	a.key(29.5, M([HD(0.01, 0.08)]))


# Acte II (30 → 59,45 s) : les yeux s'ouvrent derrière Simon, volte-face, le sourire, la taille du démon,
# le rugissement (50,2), la résistance au souffle, les répliques, les poings qui s'embrasent (56,95).
static func _act2(s: Actor, a: Actor) -> void :
	for one: Actor in [s, a]:
		for t: float in [34.0, 40.0, 46.0, 51.0, 55.3]: one.cut(t)
	var yiero_eyes: Vector3 = Vector3(0, 30, 84)
	# --- Simon : figé face au noir, les yeux s'ouvrent derrière lui. Il le sent, se retourne lentement,
	# puis d'un coup.
	s.key(30.0, M([HD(-0.06, 0.04, 0.0), C(0.09, 0.0), H(0.0, -0.06, 0.0), {"shake": 0.18, "breath": 0.5, "bf": 0.8, "face": "fear"}]))
	s.key(30.45, M([Rt(0.08, 0.3, 0.14, 0.6), WR(0.2)]))
	s.key(31.0, M([R(0.2, -0.42, 0.3, 0.25), WR(0.1), Lt(-0.02, -0.3, 0.3, 0.2), {"curl": 0.75}]))
	s.key(30.9, M([HD(-0.07, -0.05, -0.02)]))
	s.key(31.3, M([HD(-0.12, -0.02, 0.0), {"jaw": 0.12}]))
	s.key(31.55, M([HD(-0.05, -0.03, 0.0), {"jaw": 0.0}]))
	s.key(32.0, M([HD(0.0, -0.04, 0.0), {"breath": 0.0, "shake": 0.1, "ev": "gasp", "face": "panic"}, L(0.24, -0.55, 0.25, 0.2), R(0.22, -0.52, 0.3, 0.2)]))
	s.key(32.6, M([HD(0.0, -0.18, -0.05), C(0.07, -0.05)]))
	s.key(33.15, M([HD(0.02, -0.75, -0.1), C(0.05, -0.32), B(0.02, -0.08)]))
	pivot(s, 33.3, 33.95, PI, "in")
	step_to(s, 1, 33.4, 33.72, Vector3(0.14, 0, 0.1), 0.08, {"fall": 0.7, "heel": 0.2})
	step_to(s, -1, 33.62, 33.95, Vector3(-0.14, 0, 0.0), 0.07, {"fall": 0.6, "heel": 0.2})
	s.key(33.55, M([HD(0.12, -0.3, -0.05), C(0.0, -0.2), B(-0.04, -0.12), H(0.0, -0.05, 0.05)]))
	var look34: Dictionary = look(s, 34.5, yiero_eyes, 0.2, 1.45)
	s.key(34.0, M([look34, B(-0.06), H(0.0, -0.08, 0.06), L(0.3, -0.5, 0.2, 0.3), R(0.3, -0.48, 0.25, 0.3), {"curl": 0.8, "curl_l": 0.8, "shake": 0.3, "face": "panic"}]))
	# 36,0 → 38,0 : le rire, le sourire qui se fend. Simon recule d'un demi-pas au coup sourd.
	s.key(36.0, M([{"shake": 0.22, "breath": 0.8, "bf": 1.4}]))
	s.key(37.9, M([H(0.0, -0.08, 0.06)]))
	s.key(38.05, M([H(0.0, -0.12, 0.12), B(-0.1), C(-0.04), {"ev": "gasp", "shake": 0.5}]))
	walk_to(s, 38.02, 38.3, s.end_root() + Vector3(0, 0, -0.11), 0.12, 0.12)
	shuffle(s, 1, 38.02, 38.3, Vector3(0.02, 0, 0.22), 0.05)
	s.key(38.6, M([H(0.0, -0.09, 0.07), B(-0.05), C(0.02), {"shake": 0.3}]))
	# 40 → 46 : la tête monte, il recule de deux pas, sursaute aux mains qui sortent de l'encre.
	s.key(40.6, M([look(s, 40.6, Vector3(0, 40, 84), 0.25, 1.45)]))
	walk_to(s, 41.1, 42.15, s.end_root() + Vector3(0, 0, -0.31), 0.4, 0.4)
	shuffle(s, -1, 41.1, 41.55, Vector3(0.0, 0, 0.32), 0.05)
	shuffle(s, 1, 41.7, 42.15, Vector3(0.0, 0, 0.3), 0.05)
	s.key(42.5, M([look(s, 42.5, Vector3(0, 48, 82), 0.25, 1.45)]))
	s.key(42.75, M([look(s, 42.75, Vector3(-30, 10, 40), 0.3, 1.45), H(0.0, -0.11, 0.05), {"ev": "gasp", "shake": 0.45}]))
	s.key(43.5, M([look(s, 43.5, Vector3(29, 10, 40), 0.3, 1.45), {"shake": 0.4}]))
	s.key(44.4, M([look(s, 44.4, Vector3(0, 55, 80), 0.25, 1.45), H(0.0, -0.08, 0.04)]))
	walk_to(s, 44.6, 45.05, s.end_root() + Vector3(0, 0, -0.14), 0.2, 0.2)
	shuffle(s, -1, 44.6, 45.05, Vector3(0.0, 0, 0.28), 0.05)
	s.key(45.6, M([look(s, 45.6, Vector3(0, 60, 78), 0.25, 1.45), {"shake": 0.3}]))
	s.key(48.0, M([look(s, 48.0, Vector3(0, 52, 74), 0.25, 1.45)]))
	s.key(49.9, M([look(s, 49.9, Vector3(0, 45, 70), 0.25, 1.45), H(0.0, -0.1, 0.06), {"breath": 0.0}]))
	# 50,28 : le souffle. Projeté en arrière, deux pas qui rattrapent, avant-bras devant le visage.
	s.key(50.28, M([HD(0.25, 0.0, 0.0), C(-0.2, 0.0), B(-0.18), H(0.0, -0.1, 0.18), L(0.15, 0.15, 0.4, 0.6), R(0.1, 0.2, 0.42, 0.7), {"shake": 0.8, "ev": "hurt", "face": "pain", "curl": 0.6, "curl_l": 0.6}]))
	walk_to(s, 50.3, 50.9, s.end_root() + Vector3(0.02, 0, -0.44), 0.05, 0.3)
	shuffle(s, -1, 50.32, 50.62, Vector3(0.0, 0, 0.45), 0.08, {"fall": 1.2})
	shuffle(s, 1, 50.55, 50.9, Vector3(0.05, 0, 0.42), 0.08, {"fall": 1.2})
	s.key(50.7, M([HD(0.05, 0.1, 0.05), C(0.1, 0.05), B(0.12), H(0.0, -0.16, 0.0), {"shake": 0.65}]))
	# 51 → 55,3 : le vent en pleine face. Buste penché dedans, bras qui protègent, plissement des yeux.
	var brace_s: Dictionary = M([HD(-0.12, 0.08, 0.04), C(0.22, 0.04), B(0.18), H(0.0, -0.14, 0.0), Lt(0.05, 0.5, 0.42, 0.75), Rt(-0.05, 0.42, 0.48, 0.8), WL(0.3), WR(0.3), {"shake": 0.55, "face": "pain", "curl": 0.7, "curl_l": 0.7}])
	s.key(51.05, brace_s)
	s.key(52.0, M([HD(-0.14, 0.12, 0.06), {"shake": 0.5}]))
	s.key(52.6, M([HD(-0.06, 0.25, 0.04), {"face": "hurt"}]))
	s.key(53.6, M([HD(-0.1, 0.18, 0.05), {"shake": 0.4}]))
	# 54,4 : il baisse le bras, regarde le démon en face.
	s.key(54.35, M([Lt(0.05, 0.48, 0.42, 0.75), Rt(-0.05, 0.4, 0.46, 0.8), HD(-0.08, 0.1)]))
	s.key(54.8, M([L(0.22, -0.45, 0.28, 0.25), R(0.2, -0.42, 0.32, 0.25), WL(0.1), WR(0.1), HD(0.12, 0.0), C(0.12, 0.0), B(0.1), H(0.0, -0.1, 0.02), {"shake": 0.2, "face": "determined", "curl": 0.9, "curl_l": 0.9}]))
	# 55,45 : « Ouais ! On le renvoie d'où il vient ! » — poing droit dans la paume gauche.
	s.key(55.4, M([HD(0.1, 0.0, 0.0), C(0.08, 0.0), L(0.22, -0.45, 0.28, 0.25), R(0.2, -0.42, 0.32, 0.25)]))
	s.key(55.7, M([HD(0.14, 0.05, 0.03), C(0.1, -0.08), B(0.12, -0.05), Lt(-0.05, -0.32, 0.42, 0.3), Rt(0.18, -0.15, 0.25, 0.45), WL(-0.2, 0.0, 0.3), {"curl_l": 0.2, "curl": 1.0}]))
	s.key(55.96, M([Rt(0.0, -0.28, 0.44, 0.2), Lt(-0.08, -0.34, 0.45, 0.3), C(0.14, 0.06), HD(0.1, -0.04), {"ev": "effort", "shake": 0.15}]), "s")
	s.key(56.25, M([Rt(0.02, -0.27, 0.43, 0.2), Lt(-0.07, -0.33, 0.44, 0.3), HD(0.12, 0.0)]))
	# 56,75 : gros plan sur la main droite qui se referme, tremble… et s'embrase (56,95).
	s.key(56.6, M([R(0.25, -0.35, 0.35, 0.3), L(0.25, -0.5, 0.25, 0.25), WR(0.2, 0.3), {"curl": 0.8, "curl_l": 0.85}]))
	s.key(56.85, M([R(0.27, -0.32, 0.36, 0.3), WR(0.35, 0.35), {"curl": 1.0, "shake": 0.45}]))
	s.key(56.95, M([R(0.3, -0.3, 0.38, 0.35), WR(0.1, 0.2), C(0.04, 0.0), HD(0.05, 0.0), {"shake": 0.0, "ev": "effort", "face": "angry"}]), "s")
	s.key(57.3, M([R(0.28, -0.28, 0.38, 0.3), WR(0.15, 0.25), {"face": "determined"}]))
	# 57,75 → 59,45 : garde de boxeur, un pas en avant, sautille sur la pointe des pieds.
	s.key(57.8, M([Lt(0.02, 0.1, 0.45, 0.3), Rt(0.0, 0.05, 0.38, 0.3), WL(0.25), WR(0.25), HD(0.08, 0.0), C(0.12), B(0.1), H(0.0, -0.1, 0.0), {"curl": 1.0, "curl_l": 1.0}]))
	walk_to(s, 57.85, 58.2, s.end_root() + Vector3(0, 0, 0.19), 0.15, 0.15)
	shuffle(s, -1, 57.85, 58.2, Vector3(0.02, 0, -0.38), 0.07, {"fall": 1.0})
	s.key(58.3, M([H(0.0, -0.14, -0.06), B(0.14), {"face": "determined"}]))
	s.key(58.6, M([H(0.0, -0.11, -0.04)]))
	s.key(59.0, M([H(0.0, -0.13, -0.05), HD(0.12, 0.0)]))

	# --- Ashura : il se retourne en même temps que Simon, se place devant lui, bras tendu.
	a.key(30.0, M([HD(0.0, -0.04), H(0.0, -0.04, 0.0), {"face": "focus", "curl": 0.8, "curl_l": 0.75}]))
	a.key(31.5, M([HD(0.0, 0.1)]))
	a.key(32.4, M([HD(0.02, 0.0), {"face": "surprise"}]))
	a.key(33.3, M([HD(0.06, 0.55, 0.06), C(0.03, 0.2)]))
	pivot(a, 33.55, 34.2, PI, "smooth")
	step_to(a, -1, 33.6, 33.92, Vector3(-0.14, 0, 0.08), 0.06, {"fall": 0.6, "heel": 0.3})
	step_to(a, 1, 33.82, 34.2, Vector3(0.13, 0, -0.02), 0.06, {"fall": 0.5, "heel": 0.3})
	a.key(34.3, M([look(a, 34.3, Vector3(0, 30, 84), 0.2, 1.4), H(0.0, -0.06, 0.0), {"face": "fear"}]))
	a.key(36.4, M([look(a, 36.4, Vector3(0, 32, 84), 0.2, 1.4), {"face": "focus"}]))
	# 36,8 → 37,6 : un pas vers Simon, en travers de lui, bras droit tendu devant lui.
	walk_to(a, 36.85, 37.6, a.end_root() + Vector3(-0.42, 0, -0.35), 0.3, 0.3)
	step_to(a, 1, 36.85, 37.3, Vector3(0.13, 0, -0.02), 0.07, {"fall": 0.8})
	step_to(a, -1, 37.15, 37.6, Vector3(-0.12, 0, 0.02), 0.06, {"fall": 0.6})
	a.key(37.0, M([C(0.04, 0.1), hang_r(0.15, 0.1, -0.85)]))
	a.key(37.5, M([R(0.85, -0.22, 0.3, 0.1), WR(0.0, 0.0, 0.2), C(0.04, 0.18), B(0.0, 0.08), {"curl": 0.25, "face": "determined"}]))
	a.key(38.05, M([H(0.0, -0.1, 0.06), B(-0.06, 0.08), {"ev": "grunt", "shake": 0.25}]))
	a.key(38.4, M([H(0.0, -0.07, 0.03), B(0.0, 0.08), {"shake": 0.1}]))
	a.key(40.6, M([look(a, 40.6, Vector3(0, 40, 84), 0.25, 1.4), R(0.85, -0.25, 0.28, 0.1)]))
	walk_to(a, 41.25, 42.3, a.end_root() + Vector3(0, 0, -0.3), 0.4, 0.4)
	shuffle(a, 1, 41.25, 41.7, Vector3(0.0, 0, 0.3), 0.05)
	shuffle(a, -1, 41.85, 42.3, Vector3(0.0, 0, 0.3), 0.05)
	a.key(42.7, M([look(a, 42.7, Vector3(-30, 10, 40), 0.3, 1.4), H(0.0, -0.09, 0.0), {"ev": "grunt"}]))
	a.key(43.55, M([look(a, 43.55, Vector3(29, 10, 40), 0.35, 1.4)]))
	a.key(44.4, M([look(a, 44.4, Vector3(0, 55, 80), 0.25, 1.4), R(0.7, -0.4, 0.25, 0.1), {"face": "fear"}]))
	walk_to(a, 44.75, 45.2, a.end_root() + Vector3(0, 0, -0.13), 0.2, 0.2)
	shuffle(a, 1, 44.75, 45.2, Vector3(0.0, 0, 0.26), 0.05)
	a.key(45.8, M([look(a, 45.8, Vector3(0, 60, 78), 0.25, 1.4), {"face": "focus"}]))
	a.key(49.9, M([look(a, 49.9, Vector3(0, 45, 70), 0.25, 1.4), H(0.0, -0.08, 0.0)]))
	a.key(50.3, M([HD(0.22, 0.0), C(-0.18, 0.0), B(-0.16), H(0.0, -0.1, 0.16), L(0.1, 0.25, 0.42, 0.7), R(0.15, 0.15, 0.4, 0.6), {"shake": 0.7, "ev": "hurt", "face": "pain"}]))
	walk_to(a, 50.34, 50.95, a.end_root() + Vector3(-0.02, 0, -0.39), 0.05, 0.3)
	shuffle(a, 1, 50.36, 50.66, Vector3(0.0, 0, 0.42), 0.08, {"fall": 1.2})
	shuffle(a, -1, 50.6, 50.95, Vector3(-0.05, 0, 0.36), 0.08, {"fall": 1.2})
	a.key(50.75, M([HD(0.05, -0.05), C(0.1, -0.05), B(0.12), H(0.0, -0.15, 0.0), {"shake": 0.6}]))
	var brace_a: Dictionary = M([HD(-0.1, -0.06, -0.03), C(0.2, -0.04), B(0.16), H(0.0, -0.13, 0.0), Lt(-0.05, 0.38, 0.46, 0.8), Rt(0.05, 0.48, 0.42, 0.7), WL(0.3), WR(0.3), {"shake": 0.5, "face": "pain", "curl": 0.75, "curl_l": 0.7}])
	a.key(51.05, brace_a)
	a.key(51.8, M([HD(-0.12, -0.08, -0.04), {"shake": 0.45}]))
	# 52,2 : il baisse le bras le premier, se redresse, tourne la tête vers Simon (à sa droite).
	a.key(52.2, M([Lt(-0.05, 0.36, 0.44, 0.8), HD(-0.06, -0.04), {"face": "hurt"}]))
	a.key(52.55, M([L(0.15, -0.6, 0.2, 0.15), R(0.15, -0.62, 0.18, 0.15), WL(0.0), WR(0.0), C(0.14, -0.12), B(0.12), HD(0.02, -0.55, -0.04), H(0.0, -0.11, 0.0), {"shake": 0.25, "face": "determined", "curl": 0.9, "curl_l": 0.9}]))
	a.key(53.6, M([HD(0.0, -0.5, -0.03)]))
	a.key(54.1, M([HD(0.05, -0.1, 0.0), C(0.14, 0.0), {"shake": 0.15}]))
	a.key(55.2, M([HD(0.08, -0.05)]))
	# 56,95 : il serre les poings le long du corps, la lumière jaillit ; il prend sa garde.
	a.key(56.7, M([L(0.16, -0.62, 0.15, 0.2), R(0.16, -0.62, 0.15, 0.2), {"curl": 1.0, "curl_l": 1.0, "shake": 0.3}]))
	a.key(56.95, M([L(0.22, -0.66, 0.12, 0.3), R(0.22, -0.66, 0.12, 0.3), C(0.1, 0.0), HD(0.1, 0.0), {"shake": 0.0, "ev": "effort", "face": "angry"}]), "s")
	a.key(57.75, M([Lt(0.0, -0.05, 0.5, 0.2), Rt(0.15, -0.35, 0.12, 0.3), WL(0.15), WR(0.2), HD(0.1, 0.05), C(0.1, 0.2), B(0.08, 0.15), H(0.0, -0.12, 0.0), {"face": "determined"}]))
	walk_to(a, 57.8, 58.15, a.end_root() + Vector3(0, 0, 0.16), 0.15, 0.15)
	shuffle(a, 1, 57.8, 58.15, Vector3(0.05, 0, -0.32), 0.06, {"fall": 1.0})
	a.key(58.4, M([H(0.0, -0.15, -0.04), B(0.1, 0.2)]))
	a.key(59.2, M([HD(0.14, 0.04)]))

	# Simon s'accroche à l'avant-bras qu'Ashura tend devant lui (main gauche), puis le lâche au souffle.
	var arm_a: Vector3 = Vector3(0.85, -0.22, -0.3)
	var sleeve: Vector3 = hand_world(a, 39.3, 1, arm_a).lerp(shoulder_world(a, 39.3, 1), 0.28)
	s.key(38.9, M([L(0.3, -0.5, 0.2, 0.3)]))
	s.key(39.3, M([reach(s, 39.3, -1, sleeve + Vector3(0, -0.02, -0.03), H(0.0, -0.09, 0.07).hips), WL(0.35, 0.0, -0.25), {"curl_l": 0.95}]))
	var sleeve2: Vector3 = hand_world(a, 42.3, 1, Vector3(0.85, -0.25, -0.28)).lerp(shoulder_world(a, 42.3, 1), 0.28)
	s.key(42.3, M([reach(s, 42.3, -1, sleeve2 + Vector3(0, -0.02, -0.03), Vector3(0, -0.08, 0.04))]))
	var sleeve3: Vector3 = hand_world(a, 45.2, 1, Vector3(0.7, -0.4, -0.25)).lerp(shoulder_world(a, 45.2, 1), 0.28)
	s.key(45.2, M([reach(s, 45.2, -1, sleeve3 + Vector3(0, -0.02, -0.03), Vector3(0, -0.08, 0.04))]))
	s.key(49.9, M([reach(s, 49.9, -1, sleeve3 + Vector3(0, -0.02, -0.03), Vector3(0, -0.1, 0.06)), {"curl_l": 0.95}]))
	s.key(50.2, M([{"curl_l": 0.4}]))


# Saut : la racine décrit un arc (hauteur `h` au-dessus de la droite entre départ et arrivée).
static func leap(a: Actor, t0: float, t1: float, to: Vector3, h: float, mode: String = "linear") -> void :
	var from: Vector3 = a.end_root()
	if a.root.is_empty() or a.end_time() < t0 - 0.0001: a.go(t0, from)
	var n: int = maxi(2, ceili((t1 - t0) / (GRID * 0.5)))
	for k: int in range(1, n + 1):
		var u: float = float(k) / float(n)
		var p: Vector3 = from.lerp(to, ease_u(u, mode))
		p.y = lerpf(from.y, to.y, u) + 4.0 * h * u * (1.0 - u)
		a.go(t0 + (t1 - t0) * u, p)


# Pied libre qui part exactement de son appui : première clé = position du pied posé à `lift`.
static func air_from(a: Actor, side: int, lift: float, keys: Array, pitch: float = -0.3) -> void :
	var rows: Array = a.feet[side]
	var spot: Vector3 = a.last_spot(side)
	var first: Vector3 = local_of(a, lift, spot)
	var list: Array = [[lift, first, pitch]]
	for row: Array in keys:
		if float(row[0]) > lift + 0.02: list.append(row)
	a.air(side, list, lift)


# Glisse en rollers : les pieds roulent avec le corps (pieds libres, repère du corps). Chaque pied
# pousse en diagonale vers l'extérieur-arrière puis revient sous la hanche ; le bassin passe sur le
# pied qui glisse. `period` : durée d'une poussée (un pied).
static func skate(a: Actor, t0: float, t1: float, first: int, period: float, o: Dictionary = {}) -> void :
	var width: float = float(o.get("width", 0.11))
	var push: float = float(o.get("push", 0.36))
	var lift: float = float(o.get("lift", 0.07))
	var keys: Dictionary = {-1: [], 1: []}
	var t: float = t0
	var k: int = 0
	var side: int = first
	while t < t1 - 0.05:
		var w: float = noise(int(o.get("seed", 21)), k)
		var p: float = period * (1.0 + 0.06 * w)
		var x: float = float(side) * width
		var reach_x: float = float(side) * (width + push * 0.75)
		# Poussée (pied au sol qui part en diagonale), dégagement, retour sous la hanche.
		(keys[side] as Array).append([t, Vector3(x, 0.0, 0.02), 0.0])
		(keys[side] as Array).append([t + p * 0.55, Vector3(reach_x, 0.0, push * 0.9), -0.1])
		(keys[side] as Array).append([t + p * 0.75, Vector3(reach_x * 0.8, lift, push * 0.6), -0.2])
		(keys[side] as Array).append([t + p * 1.0, Vector3(x * 1.1, lift * 0.6, -0.04), 0.05])
		var other: int = - side
		(keys[other] as Array).append([t, Vector3(float(other) * width * 0.8, 0.0, -0.06), 0.0])
		(keys[other] as Array).append([t + p * 0.9, Vector3(float(other) * width, 0.0, 0.04), 0.0])
		t += p
		k += 1
		side = - side
	for one: int in [-1, 1]:
		var list: Array = keys[one]
		list.sort_custom( func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
		var clean: Array = []
		for row: Array in list:
			if not clean.is_empty() and float(row[0]) - float(clean[clean.size() - 1][0]) < 0.02: clean[clean.size() - 1] = row
			else: clean.append(row)
		a.air(one, clean)


# Acte III (59,45 → 104 s) : charge, griffe (63,2), plongeon, course éclair, saut et flashbang (68,4),
# rollers et drone (74,6), double coup de poing (79,0), rire, piques, revers (92,9), saisie (99,4).
static func _act3(s: Actor, a: Actor) -> void :
	for one: Actor in [s, a]:
		for t: float in [59.45, 61.9, 65.45, 68.25, 72.9, 77.75, 80.3, 84.6, 89.05, 92.82, 96.5, 99.55]: one.cut(t)
	var chin: Vector3 = Vector3(-0.37, 13.8, 61.2)

	# --- 59,45 : poses héroïques, puis la charge vers le démon (61,0 → 62,9).
	s.key(59.45, M([HD(0.16, 0.02), C(0.1, 0.02), B(0.1), H(0.0, -0.13, -0.05), Lt(0.02, 0.12, 0.45, 0.3), Rt(0.0, 0.06, 0.38, 0.3), {"face": "determined", "curl": 1.0, "curl_l": 1.0}]))
	s.key(60.2, M([H(0.0, -0.11, -0.05), HD(0.18, 0.0)]))
	s.key(60.6, M([H(0.0, -0.14, -0.06)]))
	s.key(61.0, M([H(0.0, -0.17, -0.02), B(0.22), C(0.12), {"ev": "effort"}]))
	a.key(59.45, M([HD(0.16, 0.04), C(0.1, 0.2), B(0.08, 0.15), H(0.0, -0.14, -0.04), Lt(0.0, -0.05, 0.5, 0.2), Rt(0.15, -0.35, 0.12, 0.3), {"face": "determined", "curl": 1.0, "curl_l": 1.0}]))
	a.key(60.8, M([HD(0.17, 0.0), C(0.12, 0.1), B(0.1, 0.05), H(0.0, -0.16, -0.02)]))
	walk_to(s, 61.0, 62.92, s.end_root() + Vector3(-0.25, 0, 6.6), 0.9, 0.05)
	strides(s, 1, 61.25, 0.27, 7, {"stance": 0.42, "width": 0.09, "h": 0.1, "kick": 0.12, "seed": 31, "heel": 0.3})
	s.key(61.3, M([{"loco": 1.0, "swing": 0.0}, B(0.3), C(0.1), HD(0.22, 0.0), Lt(0.05, 0.05, 0.5, 0.35), Rt(0.02, 0.0, 0.45, 0.35)]))
	s.key(62.3, M([HD(0.3, 0.05), {"face": "determined"}]))
	s.key(62.62, M([HD(0.55, 0.1), C(0.0, 0.1), B(0.12), {"face": "surprise"}]))
	walk_to(a, 61.1, 62.88, a.end_root() + Vector3(0.2, 0, 6.6), 1.0, 0.05)
	skate(a, 61.15, 62.88, 1, 0.5, {"width": 0.12, "push": 0.34, "seed": 4})
	a.key(61.3, M([{"loco": 1.0, "swing": 0.0}, B(0.36, 0.0), C(0.1), HD(0.25, 0.0), H(0.0, -0.2, 0.0), Lt(0.1, -0.3, 0.3, 0.3), Rt(0.15, -0.5, -0.1, 0.3)]))
	a.key(62.6, M([HD(0.55, -0.1), C(0.0, -0.1), {"face": "surprise"}]))

	# --- 62,95 : la griffe arrive. Simon plonge sur sa droite (ralenti 63,2 → 63,9), roule, se relève accroupi.
	var s0: Vector3 = s.end_root()
	travel(s, 62.95, 63.2, s0 + Vector3(-1.9, 0.55, -0.25), "out")
	travel(s, 63.2, 63.9, s0 + Vector3(-3.0, 0.62, -0.38), "linear")
	travel(s, 63.9, 64.22, s0 + Vector3(-4.05, 0.0, -0.5), "in")
	travel(s, 64.22, 64.75, s0 + Vector3(-4.85, 0.0, -0.6), "out")
	s.face(62.95, PI);s.face(63.3, PI - 0.25);s.face(64.2, PI - 0.15);s.face(64.75, PI)
	air_from(s, -1, 63.0, [[63.2, Vector3(-0.7, 0.18, 0.25), -0.6], [63.9, Vector3(-0.78, 0.22, 0.3), -0.6], [64.12, Vector3(-0.35, 0.12, 0.15), -0.3]])
	air_from(s, 1, 63.06, [[63.2, Vector3(-0.42, 0.02, 0.1), -0.5], [63.9, Vector3(-0.5, 0.05, 0.12), -0.5], [64.12, Vector3(-0.1, 0.05, 0.05), -0.3]])
	step_to(s, -1, 64.2, 64.42, Vector3(-0.2, 0, 0.12), 0.08, {"fall": 1.0, "heel": 0.1})
	step_to(s, 1, 64.3, 64.62, Vector3(0.18, 0, -0.18), 0.08, {"fall": 0.8, "heel": 0.1})
	s.key(62.95, M([H(0.0, -0.22, 0.0), B(0.25, 0.0, 0.2), C(0.1, 0.0, 0.1), HD(0.3, 0.2, 0.0), {"ev": "effort", "loco": 0.0, "face": "angry"}]))
	s.key(63.15, M([H(0.0, -0.35, 0.0), B(0.45, 0.0, -1.05), C(0.1, 0.0, -0.25), HD(0.25, -0.5, 0.35), R(0.85, -0.25, 0.25, 0.4), L(0.25, 0.6, 0.35, 0.5), {"curl": 0.4, "curl_l": 0.3}]))
	s.key(63.6, M([B(0.42, 0.0, -1.18), HD(0.2, -0.65, 0.4), C(0.12, -0.05, -0.3)]))
	s.key(63.9, M([H(0.0, -0.4, 0.0), B(0.4, 0.0, -1.25), R(0.9, -0.45, 0.3, 0.4), L(0.3, 0.45, 0.4, 0.5)]))
	s.key(64.05, M([H(0.0, -0.55, 0.0), B(0.6, 0.0, -0.85), C(0.3, 0.0, -0.2), HD(-0.05, -0.35, 0.2), Rg(0.55, 0.15), Lg(0.35, 0.45), {"gsnap": 1.0, "ev": "grunt"}]))
	s.key(64.25, M([H(0.0, -0.5, 0.0), B(0.5, 0.0, -0.3), C(0.2, 0.0, 0.0), HD(0.1, -0.1, 0.0), Rg(0.4, 0.35), L(0.4, -0.4, 0.4, 0.3), {"gsnap": 0.0}]))
	s.key(64.6, M([H(0.0, -0.42, 0.05), B(0.3), C(0.12), HD(0.3, 0.05), R(0.25, -0.75, 0.5, 0.2), Lt(0.05, -0.05, 0.42, 0.3), {"face": "determined", "curl": 0.6, "curl_l": 1.0}]))
	s.key(65.1, M([H(0.0, -0.4, 0.06), HD(0.32, -0.05), {"curl": 1.0}]))
	s.key(65.38, M([H(0.0, -0.46, 0.1), B(0.45), C(0.2), HD(0.2, 0.0), R(0.2, -0.6, -0.2, 0.3), L(0.2, -0.6, -0.2, 0.3), {"ev": "effort", "face": "angry"}]))
	# Ashura : poussée latérale sur les rollers, glisse, dérapage d'arrêt face à la griffe.
	var a0: Vector3 = a.end_root()
	travel_curve(a, 62.9, 63.9, a0 + Vector3(2.6, 0, 0.6), a0 + Vector3(3.9, 0, 0.2), "out")
	travel(a, 63.9, 64.7, a0 + Vector3(4.7, 0, -0.5), "out")
	a.face(62.9, PI);a.face(63.3, PI + 0.5);a.face(64.7, PI + 0.15);a.aim(63.3, PI + 0.4);a.aim(64.7, PI)
	a.air(-1, [[62.9, Vector3(-0.12, 0, 0.0), 0.0], [63.1, Vector3(-0.16, 0, -0.08), 0.0], [63.9, Vector3(-0.2, 0, -0.12), 0.0], [64.4, Vector3(-0.3, 0, -0.2), 0.0], [64.7, Vector3(-0.3, 0, -0.2), 0.0]])
	a.air(1, [[62.9, Vector3(0.12, 0, 0.0), 0.0], [63.1, Vector3(0.45, 0, 0.3), -0.1], [63.25, Vector3(0.42, 0.12, 0.22), -0.2], [63.9, Vector3(0.3, 0.1, 0.1), 0.0], [64.15, Vector3(0.28, 0, 0.12), 0.0], [64.7, Vector3(0.28, 0, 0.12), 0.0]])
	a.key(62.9, M([H(0.0, -0.26, 0.0), B(0.45, 0.4, -0.15), C(0.1, 0.1), HD(0.35, -0.3), Lt(0.2, -0.2, 0.4, 0.3), R(0.5, -0.5, -0.3, 0.3), {"face": "angry", "ev": "effort"}]))
	a.key(63.5, M([H(0.0, -0.32, 0.0), B(0.5, 0.45, -0.2), HD(0.3, -0.6)]))
	a.key(64.2, M([H(0.0, -0.36, 0.0), B(0.3, 0.2, 0.25), C(0.1, -0.2), HD(0.25, -0.4), {"fx": "skid"}]))
	a.key(64.7, M([H(0.0, -0.3, 0.0), B(0.2, 0.0, 0.0), C(0.1, 0.0), HD(0.3, -0.1), Lt(0.0, -0.05, 0.5, 0.2), Rt(0.15, -0.35, 0.12, 0.3), {"face": "determined"}]))

	# --- 65,45 → 68,3 : course éclair (buste plongé, bras tendus en arrière, foulées immenses).
	var start: Vector3 = s.end_root()
	var run_to: Vector3 = Vector3(-3.5, 0, 14.0)
	walk_to(s, 65.45, 68.28, run_to, 0.55, 0.0)
	step_to(s, 1, 65.42, 65.6, Vector3(0.1, 0, -0.35), 0.08, {"fall": 1.2, "heel": 0.0})
	step_to(s, -1, 65.52, 65.76, Vector3(-0.1, 0, -0.55), 0.12, {"fall": 1.2, "heel": 0.0, "kick": 0.1})
	strides(s, 1, 65.95, 0.19, 12, {"stance": 0.33, "width": 0.07, "h": 0.16, "kick": 0.32, "seed": 41, "heel": 0.0, "land": 0.0, "fall": 1.4})
	s.key(65.45, M([{"loco": 0.6, "swing": 0.0}, H(0.0, -0.3, 0.12), B(0.62), C(0.18), HD(-0.05, 0.0), R(0.25, -0.55, -0.55, 0.2), L(0.25, -0.5, -0.5, 0.2), {"face": "angry"}]))
	s.key(65.9, M([H(0.0, -0.18, 0.18), B(0.78), C(0.2), HD(-0.42, 0.0), R(0.22, -0.32, -0.92, 0.0), L(0.22, -0.3, -0.92, 0.0), WR(-0.5), WL(-0.5), {"curl": 0.2, "curl_l": 0.2, "loco": 0.8}]))
	s.key(67.6, M([HD(-0.38, 0.05), {"face": "determined"}]))
	# 68,0 : appel ; 68,3 → 69,4 : saut, armé, lancer de la flashbang vers l'œil (68,6).
	s.key(67.95, M([B(0.6), HD(-0.1, 0.0), R(0.25, -0.45, -0.6, 0.2), {"prop": "flash", "curl": 0.75}]))
	s.key(68.18, M([H(0.0, -0.28, 0.05), B(0.35), C(0.0), HD(0.25, 0.0), R(0.35, -0.2, -0.45, 0.3), L(0.3, 0.1, 0.4, 0.4), {"loco": 0.0, "ev": "effort"}]))
	leap(s, 68.3, 69.38, Vector3(-3.0, 0, 20.5), 3.4, "linear")
	air_from(s, -1, 68.3, [[68.5, Vector3(-0.12, 0.28, 0.25), -0.5], [68.95, Vector3(-0.14, 0.36, 0.1), -0.3], [69.3, Vector3(-0.13, 0.05, -0.1), 0.15]], -0.7)
	air_from(s, 1, 68.0, [[68.2, Vector3(0.12, 0.3, -0.1), -0.2], [68.5, Vector3(0.12, 0.45, -0.18), -0.2], [68.95, Vector3(0.14, 0.3, -0.05), 0.0], [69.3, Vector3(0.13, 0.06, 0.05), 0.15]], -0.6)
	step_to(s, -1, 69.3, 69.38, Vector3(-0.13, 0, -0.08), 0.02, {"fall": 1.5, "heel": 0.2})
	step_to(s, 1, 69.32, 69.42, Vector3(0.14, 0, 0.12), 0.02, {"fall": 1.2, "heel": 0.2})
	s.key(68.35, M([H(0.0, -0.05, 0.0), B(-0.15), C(-0.22, 0.2), HD(0.4, -0.15), R(0.55, 0.45, -0.35, 0.6), WR(-0.6), L(0.35, 0.3, 0.55, 0.4), {"face": "angry"}]))
	s.key(68.56, M([C(-0.3, 0.3), B(-0.2, 0.15), R(0.4, 0.7, -0.2, 0.7), WR(-0.8)]))
	s.key(68.64, M([C(0.25, -0.3), B(0.05, -0.15), HD(0.35, 0.05), R(0.05, 0.4, 0.85, 0.3), WR(0.4), L(0.4, -0.2, -0.2, 0.3), {"prop": "", "curl": 0.1, "ev": "effort"}]))
	s.key(68.85, M([C(0.15, -0.15), B(0.1, -0.05), R(0.2, -0.1, 0.55, 0.2), WR(0.1), {"curl": 0.6}]))
	s.key(69.25, M([B(0.2), C(0.1), HD(0.15, 0.0), R(0.4, 0.0, 0.3, 0.4), L(0.45, 0.05, 0.3, 0.4)]))
	s.key(69.45, M([H(0.0, -0.38, 0.0), B(0.42), C(0.22), HD(-0.05, 0.0), Rg(0.35, 0.3), L(0.5, -0.2, 0.2, 0.4), {"sq": 0.94, "ev": "grunt"}]))
	s.key(69.7, M([H(0.0, -0.42, 0.04), B(0.38), C(0.15), HD(0.25, 0.0), Rg(0.35, 0.3), {"sq": 1.0}]))
	s.key(70.3, M([H(0.0, -0.32, 0.03), B(0.25), HD(0.35, 0.05), R(0.2, -0.6, 0.35, 0.2), {"face": "determined"}]))
	s.key(70.9, M([H(0.0, -0.08, 0.0), B(0.08), C(0.05), HD(0.3, -0.1), L(0.18, -0.65, 0.25, 0.2), R(0.18, -0.65, 0.25, 0.2), {"curl": 1.0, "curl_l": 1.0}]))
	s.key(72.0, M([HD(0.32, -0.3), C(0.06, -0.15)]))
	s.key(73.5, M([HD(0.3, -0.55), C(0.06, -0.25)]))
	# 75,1 : « Il recule ! » — poing serré qui monte, rire nerveux.
	s.key(74.8, M([HD(0.32, -0.2), C(0.06, -0.08), {"face": "surprise"}]))
	s.key(75.25, M([HD(0.4, 0.05), C(-0.05, 0.0), B(-0.04), R(0.15, 0.2, 0.3, 0.6), WR(0.3), {"face": "grin", "ev": "effort"}]))
	s.key(75.55, M([R(0.18, 0.5, 0.25, 0.7)]))
	s.key(75.8, M([R(0.16, 0.12, 0.32, 0.6), HD(0.3, -0.25)]))
	s.key(76.2, M([R(0.18, 0.45, 0.25, 0.7), HD(0.25, -0.45), C(0.0, -0.15), {"face": "grin"}]))
	s.key(76.8, M([R(0.2, -0.35, 0.3, 0.3), HD(0.2, -0.5), {"face": "determined"}]))
	s.key(77.2, M([HD(0.25, -0.35), C(0.08, -0.1), H(0.0, -0.1, 0.0), {"face": "angry"}]))
	# 77,3 : course, appel à 77,9, saut immense jusqu'au menton : coup de poing droit (79,0).
	s.key(77.32, M([H(0.0, -0.28, 0.1), B(0.5), C(0.15), HD(0.1, 0.0), R(0.3, -0.5, -0.5, 0.2), L(0.3, -0.5, 0.35, 0.3), {"loco": 0.6, "ev": "effort"}]))
	walk_to(s, 77.3, 77.85, Vector3(-1.8, 0, 25.0), 0.15, 0.0)
	step_to(s, 1, 77.3, 77.48, Vector3(0.1, 0, -0.4), 0.1, {"fall": 1.3, "heel": 0.0})
	step_to(s, -1, 77.42, 77.62, Vector3(-0.1, 0, -0.5), 0.14, {"fall": 1.3, "heel": 0.0, "kick": 0.12})
	step_to(s, 1, 77.58, 77.8, Vector3(0.1, 0, -0.3), 0.12, {"fall": 1.6, "heel": 0.0})
	s.key(77.78, M([H(0.0, -0.36, 0.05), B(0.4), C(0.1), HD(0.45, 0.0), R(0.35, -0.4, -0.45, 0.3), L(0.3, -0.4, -0.4, 0.3), {"loco": 0.0}]))
	leap(s, 77.9, 79.0, chin + Vector3(-0.6, -1.35, -0.9), 3.0, "out")
	air_from(s, -1, 77.84, [[78.1, Vector3(-0.12, 0.25, 0.35), -0.6], [78.7, Vector3(-0.14, 0.4, 0.2), -0.4], [79.0, Vector3(-0.14, 0.32, 0.25), -0.5]], -0.6)
	air_from(s, 1, 77.9, [[78.1, Vector3(0.12, 0.1, 0.45), -0.7], [78.7, Vector3(0.14, 0.15, 0.55), -0.7], [79.0, Vector3(0.14, 0.05, 0.6), -0.7]], -0.6)
	s.key(77.95, M([H(0.0, -0.05, 0.0), B(0.1), C(-0.1), HD(0.55, 0.0), R(0.4, -0.2, -0.5, 0.3), L(0.35, 0.3, 0.4, 0.4), {"face": "angry", "ev": "effort"}]))
	s.key(78.55, M([B(-0.05, -0.2), C(-0.15, -0.35), HD(0.5, 0.25), R(0.55, 0.25, -0.45, 0.6), WR(-0.3), L(0.25, 0.45, 0.55, 0.4), {"curl": 1.0}]))
	s.key(78.82, M([B(-0.1, -0.35), C(-0.2, -0.5), HD(0.45, 0.35), R(0.6, 0.35, -0.55, 0.7)]))
	s.key(79.0, M([B(0.15, 0.25), C(0.1, 0.45), HD(0.4, -0.2), R(-0.05, 0.62, 0.72, 0.2), WR(0.1), L(0.55, -0.1, -0.35, 0.4), {"ev": "roar", "sq": 0.96}]), "s")
	s.key(80.2, M([B(0.25, 0.32), C(0.18, 0.55), HD(0.35, -0.25), R(-0.08, 0.66, 0.78, 0.2), {"sq": 1.0}]))
	# Rebond sur la mâchoire : chute en arrière, réception en trois appuis (81,6), se relève.
	leap(s, 80.2, 81.6, Vector3(-2.5, 0, 40.0), 2.5, "out")
	s.air(-1, [[80.2, Vector3(-0.14, 0.32, 0.25), -0.5], [80.7, Vector3(-0.2, 0.45, -0.25), -0.2], [81.4, Vector3(-0.16, 0.15, -0.2), 0.1]])
	s.air(1, [[80.2, Vector3(0.14, 0.05, 0.6), -0.7], [80.7, Vector3(0.2, 0.35, -0.1), -0.2], [81.4, Vector3(0.16, 0.12, 0.05), 0.1]])
	step_to(s, -1, 81.45, 81.6, Vector3(-0.2, 0, -0.3), 0.03, {"fall": 1.6, "heel": 0.0})
	step_to(s, 1, 81.48, 81.62, Vector3(0.18, 0, 0.35), 0.03, {"fall": 1.2, "heel": 0.0})
	s.face(80.2, PI);s.face(81.0, PI + 0.2);s.face(81.6, PI)
	s.key(80.45, M([B(-0.6, 0.1), C(-0.3, 0.2), HD(0.2, -0.1), R(0.5, 0.4, 0.2, 0.5), L(0.6, 0.3, 0.1, 0.5), {"face": "pain", "ev": "hurt"}]))
	s.key(81.0, M([B(-0.2, 0.0), C(0.1), HD(-0.1, 0.0), R(0.4, -0.2, 0.3, 0.4), L(0.45, -0.1, 0.25, 0.4), {"face": "determined"}]))
	s.key(81.6, M([H(0.0, -0.5, 0.1), B(0.45), C(0.25), HD(-0.1, 0.0), Rg(0.3, 0.35), L(0.55, -0.3, -0.1, 0.4), {"sq": 0.92, "fx": "dust_ring", "ev": "grunt"}]))
	s.key(81.85, M([H(0.0, -0.52, 0.1), HD(0.15, 0.0), {"sq": 1.0}]))
	s.key(82.3, M([H(0.0, -0.3, 0.05), B(0.25), C(0.1), HD(0.4, 0.0), R(0.25, -0.6, 0.3, 0.2), {"face": "surprise"}]))
	s.key(82.9, M([H(0.0, -0.1, 0.0), B(0.06), C(0.04), HD(0.5, 0.05), L(0.2, -0.6, 0.25, 0.2), R(0.2, -0.6, 0.25, 0.2), {"curl": 0.9, "curl_l": 0.9}]))

	# --- Ashura : il regarde Simon foncer, puis s'élance en rollers (71,0), drone (74,55), rejoint Simon.
	a.key(65.6, M([HD(0.25, 0.4), C(0.08, 0.15)]))
	a.key(68.3, M([HD(0.35, 0.25)]))
	a.key(69.5, M([HD(0.3, 0.1), {"face": "focus"}]))
	a.key(70.5, M([H(0.0, -0.32, 0.0), B(0.3), C(0.1), HD(0.15, 0.0), {"ev": "effort"}]))
	var b0: Vector3 = a.end_root()
	walk_to(a, 70.8, 74.6, Vector3(8.0, 0, 12.0), 1.0, 0.3)
	a.face(70.8, PI);a.face(71.6, angle_to(b0, Vector3(8.0, 0, 12.0)));a.aim(71.6, angle_to(b0, Vector3(8.0, 0, 12.0)))
	skate(a, 70.85, 74.4, -1, 0.56, {"width": 0.12, "push": 0.38, "seed": 8})
	a.key(71.0, M([{"loco": 1.0}, H(0.0, -0.24, 0.0), B(0.42), C(0.12), HD(0.15, 0.0), L(0.35, -0.55, -0.25, 0.3), Rt(0.15, -0.4, 0.25, 0.3), {"face": "determined"}]))
	a.key(72.5, M([L(0.4, -0.5, 0.2, 0.3), Rt(0.1, -0.45, -0.2, 0.3)]))
	a.key(73.3, M([L(0.35, -0.55, -0.25, 0.3), Rt(0.15, -0.4, 0.25, 0.3)]))
	# Lancer du drone (main droite, par-dessus l'épaule), le drone part vers les dents à 74,7.
	a.key(74.1, M([HD(0.4, 0.0), C(0.0, -0.2), B(0.25, -0.1), R(0.5, 0.35, -0.35, 0.6), WR(-0.5), L(0.35, 0.1, 0.45, 0.3), {"curl": 0.65, "loco": 0.4}]))
	a.key(74.45, M([C(-0.15, -0.35), B(0.1, -0.2), R(0.45, 0.65, -0.25, 0.7), WR(-0.8), HD(0.45, 0.1)]))
	a.key(74.7, M([C(0.25, 0.3), B(0.3, 0.15), R(0.0, 0.45, 0.85, 0.3), WR(0.4), L(0.4, -0.3, -0.3, 0.3), HD(0.4, -0.05), {"curl": 0.15, "ev": "effort"}]))
	a.key(75.1, M([C(0.12, 0.1), B(0.2, 0.0), R(0.2, -0.3, 0.4, 0.2), WR(0.0), HD(0.45, 0.0), {"curl": 0.8, "face": "focus", "loco": 1.0}]))
	var c0: Vector3 = Vector3(8.0, 0, 12.0)
	travel_curve(a, 74.6, 77.25, Vector3(6.5, 0, 19.5), Vector3(2.4, 0, 21.8), "smooth")
	a.face(74.6, angle_to(b0, c0));a.face(77.2, PI);a.aim(76.0, (angle_to(b0, c0) + PI) * 0.5);a.aim(77.2, PI)
	skate(a, 74.75, 77.15, 1, 0.62, {"width": 0.12, "push": 0.3, "seed": 12})
	a.key(76.2, M([HD(0.4, 0.3), C(0.1, 0.15), {"face": "determined"}]))
	# 77,2 : « Ensemble ! Vise la mâchoire ! » — 77,3 élan, 77,9 saut, coup du gauche (79,0).
	a.key(77.15, M([HD(0.35, 0.4), C(0.05, 0.2), Lt(0.1, 0.2, 0.4, 0.4), {"face": "angry", "ev": "effort"}]))
	walk_to(a, 77.3, 77.85, Vector3(2.0, 0, 25.0), 0.1, 0.0)
	a.key(77.4, M([H(0.0, -0.3, 0.08), B(0.48), C(0.1), HD(0.15, 0.0), L(0.3, -0.5, -0.45, 0.2), R(0.35, -0.5, 0.35, 0.3), {"loco": 0.3}]))
	a.key(77.78, M([H(0.0, -0.38, 0.05), B(0.42), HD(0.45, 0.0), L(0.35, -0.4, -0.45, 0.3), R(0.3, -0.4, -0.4, 0.3), {"loco": 0.0}]))
	leap(a, 77.88, 79.0, chin + Vector3(0.6, -1.4, -0.9), 3.1, "out")
	a.air(-1, [[77.8, Vector3(-0.12, 0.0, -0.05), -0.5], [78.1, Vector3(-0.14, 0.1, 0.4), -0.6], [78.7, Vector3(-0.16, 0.12, 0.5), -0.6], [79.0, Vector3(-0.16, 0.05, 0.55), -0.6]])
	a.air(1, [[77.86, Vector3(0.12, 0.0, 0.05), -0.5], [78.1, Vector3(0.14, 0.28, 0.3), -0.5], [78.7, Vector3(0.16, 0.42, 0.15), -0.4], [79.0, Vector3(0.16, 0.35, 0.2), -0.5]])
	a.key(77.95, M([H(0.0, -0.05, 0.0), B(0.1), C(-0.1), HD(0.55, 0.0), L(0.4, -0.2, -0.5, 0.3), R(0.35, 0.3, 0.4, 0.4), {"face": "angry"}]))
	a.key(78.55, M([B(-0.05, 0.2), C(-0.15, 0.35), HD(0.5, -0.25), L(0.55, 0.25, -0.45, 0.6), WL(-0.3), R(0.25, 0.45, 0.55, 0.4), {"curl_l": 1.0, "curl": 1.0}]))
	a.key(78.84, M([B(-0.1, 0.35), C(-0.2, 0.5), HD(0.45, -0.35), L(0.6, 0.35, -0.55, 0.7)]))
	a.key(79.0, M([B(0.15, -0.25), C(0.1, -0.45), HD(0.4, 0.2), L(-0.05, 0.62, 0.72, 0.2), WL(0.1), R(0.55, -0.1, -0.35, 0.4), {"ev": "roar", "sq": 0.96}]), "s")
	a.key(80.2, M([B(0.25, -0.32), C(0.18, -0.55), HD(0.35, 0.25), L(-0.08, 0.66, 0.78, 0.2), {"sq": 1.0}]))
	leap(a, 80.2, 81.62, Vector3(2.5, 0, 40.5), 2.4, "out")
	a.air(-1, [[80.2, Vector3(-0.16, 0.05, 0.55), -0.6], [80.7, Vector3(-0.2, 0.35, -0.1), -0.2], [81.45, Vector3(-0.16, 0.12, 0.05), 0.1]])
	a.air(1, [[80.2, Vector3(0.16, 0.35, 0.2), -0.5], [80.7, Vector3(0.2, 0.45, -0.25), -0.2], [81.45, Vector3(0.16, 0.15, -0.2), 0.1]])
	step_to(a, 1, 81.5, 81.62, Vector3(0.22, 0, -0.32), 0.03, {"fall": 1.6, "heel": 0.0})
	step_to(a, -1, 81.52, 81.66, Vector3(-0.2, 0, 0.35), 0.03, {"fall": 1.2, "heel": 0.0})
	a.key(80.45, M([B(-0.6, -0.1), C(-0.3, -0.2), HD(0.2, 0.1), R(0.6, 0.3, 0.1, 0.5), L(0.5, 0.4, 0.2, 0.5), {"face": "pain", "ev": "hurt"}]))
	a.key(81.0, M([B(-0.2, 0.0), C(0.1), HD(-0.1, 0.0), R(0.45, -0.1, 0.25, 0.4), L(0.4, -0.2, 0.3, 0.4), {"face": "determined"}]))
	a.key(81.62, M([H(0.0, -0.48, 0.1), B(0.42), C(0.22), HD(-0.08, 0.0), Lg(0.3, 0.35), R(0.55, -0.3, -0.1, 0.4), {"sq": 0.92, "fx": "dust_ring", "ev": "grunt"}]))
	a.key(81.9, M([H(0.0, -0.5, 0.1), HD(0.15, 0.0), {"sq": 1.0}]))
	a.key(82.4, M([H(0.0, -0.28, 0.05), B(0.22), C(0.1), HD(0.4, 0.0), L(0.25, -0.6, 0.3, 0.2), {"face": "surprise"}]))
	a.key(83.0, M([H(0.0, -0.1, 0.0), B(0.05), C(0.04), HD(0.5, -0.05), L(0.2, -0.6, 0.22, 0.2), R(0.2, -0.6, 0.22, 0.2), {"curl": 0.9, "curl_l": 0.9}]))

	# --- 83 → 89 : le rire. Ils se redressent, la peur revient, un pas en arrière.
	s.key(83.6, M([HD(0.5, 0.0), {"face": "surprise"}]))
	s.key(84.5, M([HD(0.45, 0.05), C(0.06), H(0.0, -0.06, 0.04), {"face": "fear", "shake": 0.2}]))
	walk_to(s, 84.7, 85.2, s.end_root() + Vector3(0, 0, -0.15), 0.2, 0.2)
	shuffle(s, 1, 84.7, 85.15, Vector3(0.02, 0, 0.3), 0.05)
	s.key(86.4, M([HD(0.42, 0.1), {"shake": 0.3}]))
	a.key(83.6, M([HD(0.5, 0.0), {"face": "surprise"}]))
	a.key(84.6, M([HD(0.46, -0.05), C(0.06), H(0.0, -0.08, 0.03), {"face": "fear"}]))
	walk_to(a, 84.9, 85.4, a.end_root() + Vector3(0, 0, -0.14), 0.2, 0.2)
	shuffle(a, -1, 84.9, 85.35, Vector3(-0.02, 0, 0.28), 0.05)
	a.key(86.6, M([HD(0.44, -0.08), {"face": "focus"}]))
	# 87,3 : « Votre petite lumière… » — la lumière vacille, ils serrent les poings, regardent les yeux.
	s.key(87.6, M([HD(0.48, 0.0), C(0.1), H(0.0, -0.12, 0.0), Lt(0.02, 0.1, 0.45, 0.3), Rt(0.0, 0.05, 0.38, 0.3), {"face": "determined", "curl": 1.0, "curl_l": 1.0, "shake": 0.25}]))
	s.key(88.6, M([HD(0.5, 0.05), {"face": "fear"}]))
	a.key(87.7, M([HD(0.48, 0.0), C(0.1, 0.2), H(0.0, -0.13, 0.0), Lt(0.0, -0.05, 0.5, 0.2), Rt(0.15, -0.35, 0.12, 0.3), {"face": "determined", "curl": 1.0, "curl_l": 1.0}]))
	# 89,2 → 89,9 : les piques jaillissent autour d'eux ; sursauts, ils se resserrent épaule contre épaule.
	var spike1: Vector3 = Vector3(-6.0, 0, 36.0)
	var spike2: Vector3 = Vector3(6.5, 0, 37.0)
	var spike3: Vector3 = Vector3(-4.0, 0, 46.5)
	var spike4: Vector3 = Vector3(5.0, 0, 45.5)
	s.key(89.18, M([HD(0.4, 0.0)]))
	s.key(89.3, M([look(s, 89.3, spike1 + Vector3(0, 3, 0), 0.4, 1.4), B(0.0, 0.0, 0.12), H(0.05, -0.1, 0.0), {"ev": "gasp", "face": "panic", "shake": 0.5}]))
	walk_to(s, 89.25, 90.4, s.end_root() + Vector3(1.4, 0, 0.1), 0.25, 0.4)
	step_to(s, -1, 89.28, 89.55, Vector3(-0.12, 0, 0.0), 0.06, {"fall": 1.0})
	step_to(s, 1, 89.5, 89.85, Vector3(0.12, 0, 0.05), 0.06, {"fall": 0.8})
	step_to(s, -1, 89.95, 90.38, Vector3(-0.14, 0, -0.04), 0.05, {"fall": 0.7})
	s.key(89.75, M([look(s, 89.75, spike3 + Vector3(0, 3, 0), 0.35, 1.4), {"ev": "gasp"}]))
	s.key(90.4, M([HD(0.3, 0.3), C(0.08, 0.1), H(0.0, -0.14, 0.0), {"shake": 0.35}]))
	s.key(91.2, M([HD(0.32, 0.55), C(0.08, 0.3)]))
	s.key(91.9, M([HD(0.25, 0.75), C(0.06, 0.45), {"face": "fear"}]))
	a.key(89.25, M([HD(0.42, 0.1), {"shake": 0.2}]))
	a.key(89.52, M([look(a, 89.52, spike2 + Vector3(0, 3, 0), 0.4, 1.4), B(0.0, 0.0, -0.12), H(-0.05, -0.12, 0.0), {"ev": "grunt", "face": "fear"}]))
	walk_to(a, 89.5, 90.5, a.end_root() + Vector3(-1.4, 0, 0.0), 0.25, 0.4)
	step_to(a, 1, 89.52, 89.82, Vector3(0.13, 0, 0.0), 0.06, {"fall": 1.0})
	step_to(a, -1, 89.75, 90.12, Vector3(-0.12, 0, 0.03), 0.06, {"fall": 0.8})
	step_to(a, 1, 90.1, 90.5, Vector3(0.14, 0, -0.03), 0.05, {"fall": 0.7})
	a.key(89.95, M([look(a, 89.95, spike4 + Vector3(0, 3, 0), 0.35, 1.4)]))
	a.key(90.5, M([HD(0.3, -0.35), C(0.08, -0.12), H(0.0, -0.15, 0.0), {"face": "determined"}]))
	a.key(91.3, M([HD(0.32, -0.6), C(0.08, -0.3)]))
	a.key(92.0, M([HD(0.3, -0.2), C(0.08, -0.1)]))
	# 92,3 : la main arrive par la gauche du film (côté de Simon) ; il fait un pas vers elle, poing armé…
	s.key(92.35, M([HD(0.2, 0.95), C(0.06, 0.55), B(0.0, 0.25), {"face": "panic", "ev": "gasp"}]))
	s.key(92.6, M([HD(0.15, 1.05), C(0.12, 0.6), B(0.1, 0.35), H(0.0, -0.16, 0.0), R(0.4, 0.1, -0.35, 0.6), Lt(0.1, 0.1, 0.45, 0.3), {"face": "angry", "ev": "effort"}]))
	# 92,9 : le revers. Choc (ralenti 92,9 → 93,4), Simon plié, projeté au loin, retombe et glisse.
	var hit: Vector3 = s.end_root()
	s.key(92.9, M([HD(-0.35, 0.6, -0.5), C(0.45, 0.3, -0.4), B(0.25, 0.2, -0.6), H(0.0, -0.08, 0.0), R(0.6, 0.35, 0.25, 0.7), L(0.5, 0.3, 0.45, 0.6), {"face": "pain", "ev": "hurt", "sq": 0.9, "curl": 0.3, "curl_l": 0.3}]), "s")
	s.key(93.2, M([HD(-0.45, 0.4, -0.6), C(0.5, 0.2, -0.5), B(0.3, 0.1, -0.85), {"sq": 1.0}]))
	travel(s, 92.9, 93.4, hit + Vector3(0.9, 0.35, -0.6), "linear")
	leap(s, 93.4, 93.85, Vector3(9.0, 0, 28.5), 1.6, "out")
	air_from(s, -1, 92.92, [[93.2, Vector3(-0.2, 0.3, 0.3), -0.4], [93.6, Vector3(-0.35, 0.6, -0.1), -0.2], [93.85, Vector3(-0.4, 0.3, -0.3), 0.0]], -0.4)
	air_from(s, 1, 92.92, [[93.2, Vector3(0.1, 0.1, 0.4), -0.4], [93.6, Vector3(0.2, 0.7, 0.2), -0.2], [93.85, Vector3(0.1, 0.35, -0.2), 0.0]], -0.4)
	s.face(92.9, yaw_at(s, 92.9));s.face(93.4, yaw_at(s, 92.9) - 0.6);s.face(93.85, yaw_at(s, 92.9) - 1.5)
	s.key(93.55, M([HD(0.3, 0.2, 0.4), C(-0.3, 0.0, 0.4), B(-0.9, 0.0, -1.2), R(0.8, 0.5, 0.1, 0.6), L(0.85, 0.4, -0.1, 0.6), {"ev": "hurt"}]))
	s.key(93.85, M([HD(0.15, -0.2, 0.3), C(0.1, 0.0, 0.2), B(-1.3, 0.0, -0.4), H(0.0, -0.55, 0.0), Rg(0.7, 0.1), Lg(0.75, -0.2), {"gsnap": 1.0, "fx": "dust_ring", "ev": "grunt"}]))
	travel(s, 93.85, 94.6, Vector3(11.5, 0, 26.0), "out")
	s.face(94.6, yaw_at(s, 92.9) - 1.75, "out")
	s.aim(93.4, yaw_at(s, 92.9) - 0.8);s.aim(94.6, yaw_at(s, 92.9) - 1.75)
	s.air(-1, [[94.0, Vector3(-0.45, 0.2, -0.3), 0.0], [94.6, Vector3(-0.42, 0.18, -0.55), 0.1]])
	s.air(1, [[94.0, Vector3(0.1, 0.25, -0.35), 0.0], [94.6, Vector3(0.18, 0.2, -0.6), 0.1]])
	s.key(94.2, M([B(-1.45, 0.0, -0.25), C(0.05, 0.0, 0.1), HD(0.25, -0.1, 0.2), {"face": "dazed", "fx": "skid"}]))
	# Au sol (94,6 → 104) : sonné, il se tourne, s'appuie sur un coude, cherche Ashura, tend la main.
	var lie: Dictionary = M([H(0.0, -0.62, 0.0), B(-1.5, 0.0, -0.2), C(0.05, 0.0, 0.05), HD(0.15, -0.15, 0.25), Rg(0.75, 0.05), Lg(0.7, -0.25), {"gsnap": 1.0, "curl": 0.25, "curl_l": 0.3, "face": "dazed"}])
	s.key(94.7, lie)
	s.key(96.0, M([HD(0.2, -0.2, 0.25), {"ev": "hurt", "face": "pain"}]))
	s.key(97.2, M([HD(0.35, 0.15, 0.1), C(0.2, 0.1, 0.1), B(-1.2, 0.0, -0.35), Lg(0.55, 0.1), {"face": "hurt"}]))
	s.key(98.4, M([HD(0.4, 0.35, 0.05), B(-1.05, 0.1, -0.45), C(0.3, 0.2, 0.1), {"ev": "gasp", "face": "fear"}]))
	s.key(99.5, M([HD(0.55, 0.5, 0.0), C(0.35, 0.25, 0.1), B(-0.95, 0.15, -0.5), Lg(0.5, 0.15), {"face": "panic"}]))
	s.key(101.0, M([HD(0.6, 0.55, 0.0), B(-0.85, 0.18, -0.55), C(0.4, 0.3, 0.1), {"face": "panic"}]))
	s.key(102.6, M([R(0.35, 0.55, 0.55, 0.3), WR(-0.2), {"curl": 0.2, "gr_r": 0.0}]))
	s.key(103.8, M([R(0.32, 0.62, 0.62, 0.3), HD(0.65, 0.55, 0.0), {"face": "pain"}]))
	# --- Ashura : il se baisse sous la main, cherche Simon des yeux, crie, charge ses rollers et fonce.
	s.cut(94.6)
	a.key(92.75, M([HD(0.35, 0.3), {"face": "surprise"}]))
	a.key(92.95, M([H(0.0, -0.32, 0.0), B(0.35, 0.0, 0.1), C(0.2), HD(-0.1, 0.4), Lt(0.2, 0.3, 0.35, 0.6), Rt(0.15, 0.35, 0.3, 0.6), {"ev": "grunt", "face": "pain"}]))
	a.key(93.4, M([H(0.0, -0.22, 0.0), B(0.2), C(0.1), HD(0.1, -0.5), {"face": "panic"}]))
	var target_s: Vector3 = Vector3(11.5, 0, 26.0)
	var a1: Vector3 = a.end_root()
	pivot(a, 93.45, 93.95, angle_to(a1, target_s), "out")
	step_to(a, 1, 93.48, 93.75, Vector3(0.13, 0, 0.0), 0.06, {"fall": 0.8})
	step_to(a, -1, 93.66, 93.98, Vector3(-0.12, 0, 0.02), 0.06, {"fall": 0.6})
	a.key(93.6, M([HD(0.15, 0.0), C(0.18, 0.0), B(0.15), H(0.0, -0.18, 0.0), L(0.35, -0.4, 0.45, 0.3), R(0.35, -0.4, 0.45, 0.3), {"face": "panic", "ev": "roar", "curl": 0.6, "curl_l": 0.6}]))
	a.key(94.4, M([HD(-0.05, 0.0), C(0.12), H(0.0, -0.12, 0.0), L(0.2, -0.6, 0.25, 0.2), R(0.2, -0.6, 0.25, 0.2), {"face": "sad", "breath": 1.0, "bf": 1.2}]))
	a.key(95.0, M([HD(0.35, 0.45), C(0.08, 0.2), {"face": "angry", "breath": 0.5}]))
	a.key(95.4, M([H(0.0, -0.45, 0.05), B(0.55), C(0.2), HD(0.05, 0.0), Lg(0.35, 0.45), R(0.3, -0.5, -0.4, 0.3), {"face": "angry", "ev": "effort", "curl": 1.0, "curl_l": 0.4, "breath": 0.0}]))
	a.key(96.2, M([H(0.0, -0.5, 0.06), B(0.6), {"shake": 0.4}]))
	a.key(96.6, M([H(0.0, -0.32, 0.0), B(0.5), C(0.1), HD(0.05, 0.0), L(0.4, -0.5, -0.5, 0.3), R(0.4, -0.5, -0.5, 0.3), {"shake": 0.0, "ev": "roar", "loco": 1.0}]))
	walk_to(a, 96.6, 98.35, a.end_root() + (target_s - a1).normalized() * 11.0, 0.7, 0.0)
	skate(a, 96.62, 98.3, 1, 0.42, {"width": 0.12, "push": 0.42, "seed": 17})
	# 98,4 : la main s'abat devant lui. Dérapage, recul, il lève les yeux… et la main se referme (99,4).
	var a2: Vector3 = a.end_root()
	var away: Vector3 = (a1 - target_s).normalized()
	travel(a, 98.35, 98.9, a2 + (target_s - a1).normalized() * 0.9, "out")
	travel(a, 98.9, 99.45, a2 + (target_s - a1).normalized() * 0.9 + away * 0.6, "smooth")
	a.face(98.35, angle_to(a1, target_s));a.face(98.6, angle_to(a1, target_s) + 0.7, "out");a.face(99.4, angle_to(a1, target_s) + 0.35)
	a.aim(98.6, angle_to(a1, target_s) + 0.5)
	a.air(-1, [[98.36, Vector3(-0.15, 0, 0.0), 0.0], [98.6, Vector3(-0.32, 0, -0.25), 0.0], [98.9, Vector3(-0.3, 0, -0.2), 0.0]])
	a.air(1, [[98.36, Vector3(0.15, 0, 0.0), 0.0], [98.6, Vector3(0.3, 0, 0.3), 0.0], [98.9, Vector3(0.28, 0, 0.25), 0.0]])
	step_to(a, 1, 98.95, 99.2, Vector3(0.15, 0, 0.1), 0.05, {"fall": 0.6})
	step_to(a, -1, 99.0, 99.25, Vector3(-0.15, 0, -0.05), 0.05, {"fall": 0.5})
	a.key(98.4, M([H(0.0, -0.4, 0.0), B(0.1, 0.5, 0.25), C(-0.1, 0.3), HD(0.35, -0.3), L(0.6, 0.0, 0.2, 0.5), R(0.5, -0.2, -0.2, 0.4), {"fx": "skid", "ev": "gasp", "face": "panic", "loco": 0.0}]))
	a.key(98.9, M([H(0.0, -0.2, 0.0), B(-0.1, 0.2), C(-0.1, 0.1), HD(0.55, 0.0), L(0.3, 0.2, 0.4, 0.5), R(0.3, 0.2, 0.4, 0.5), {"face": "fear"}]))
	a.key(99.3, M([HD(0.65, 0.0), C(-0.15), B(-0.12), Lt(0.1, 0.55, 0.35, 0.5), Rt(0.1, 0.6, 0.3, 0.5), {"face": "panic", "curl": 0.3, "curl_l": 0.3}]))
	# Tenu dans la griffe (99,5 → 104) : il se débat, mains agrippées aux doigts, jambes qui battent.
	a.key(99.52, M([HD(-0.2, 0.0), C(0.15), B(0.15), H(0.0, 0.0, 0.0), Lt(0.05, 0.92, 0.1, 0.3), Rt(0.05, 0.95, 0.05, 0.3), WL(-0.4), WR(-0.4), {"ev": "hurt", "face": "pain", "curl": 0.9, "curl_l": 0.9, "sq": 1.06}]), "s")
	a.key(99.8, M([HD(-0.35, 0.2), {"sq": 1.0}]))
	a.key(100.6, M([HD(-0.4, 0.35), C(0.12, 0.1), B(0.1, 0.1), {"face": "sad"}]))
	a.key(101.4, M([HD(0.25, -0.1), C(0.2, -0.1), B(0.2, -0.1), {"face": "angry", "ev": "effort"}]))
	a.key(102.2, M([HD(0.3, 0.05), C(-0.05, 0.1), B(-0.1, 0.15), {"ev": "effort"}]))
	a.key(103.1, M([HD(0.4, 0.0), C(0.1), B(0.05), {"face": "determined"}]))
	a.air(-1, [[99.5, Vector3(-0.12, 0.0, 0.0), 0.2], [99.9, Vector3(-0.1, 0.25, -0.35), 0.4], [100.3, Vector3(-0.12, 0.05, 0.15), -0.3], [100.8, Vector3(-0.1, 0.3, -0.3), 0.3], [101.6, Vector3(-0.12, 0.08, 0.1), -0.2], [102.4, Vector3(-0.1, 0.2, -0.2), 0.2], [103.5, Vector3(-0.12, 0.02, 0.05), -0.4], [105.0, Vector3(-0.12, 0.0, 0.05), -0.5]], 99.46)
	a.air(1, [[99.5, Vector3(0.12, 0.02, 0.05), 0.2], [99.75, Vector3(0.1, 0.05, 0.2), -0.3], [100.15, Vector3(0.12, 0.32, -0.3), 0.4], [100.6, Vector3(0.1, 0.06, 0.15), -0.3], [101.2, Vector3(0.12, 0.28, -0.25), 0.3], [102.0, Vector3(0.1, 0.1, 0.1), -0.2], [103.0, Vector3(0.12, 0.05, 0.0), -0.4], [105.0, Vector3(0.12, 0.0, 0.0), -0.5]], 99.46)
	a.cut(99.55)

