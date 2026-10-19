extends "res://anim_pose.gd"

# Fuites en équipe (0.17) : animation écrite pour les films « ending_survivors ».
# Aucun clip, émote ni geste de capacité du jeu : film_escape.gd distribue les rôles et
# le minutage, puis les modules de ce fichier écrivent, clé par clé, la piste de chaque
# acteur. Chaque acteur joue UN clip écrit pour son film (fesc_…), qui tient tous les
# canaux du corps ("gait": 0, "plant": 1) : la démarche du jeu est coupée.
#
# Repères :
#   E (film) : x latéral (+x = droite de la caméra quand on regarde la sortie de face),
#              y en haut, z vers la sortie ; z = 0 est le plan de la porte.
#   T (acteur) : x à sa droite, y en haut, z derrière lui (il regarde vers -z).
#   L'acteur garde dans le film un cap fixe (il « regarde » la sortie) ; tous les
#   demi-tours passent par le canal "turn" du clip (θ, + = vers sa gauche).
# Unités des canaux : pieds et bassin en longueurs de jambe, mains en longueurs de bras.

const AnimClip = preload("res://anim_clip.gd")

const GRID: float = 0.05

const STYLE: Dictionary = {
	# cadence (pas/s à 5,5 m/s), buste, bras, poings, rebond, levée de genou, écart des appuis,
	# tête (+ = relevée), bras qui battent, épaules
	"Simon": {"cadence": 4.5, "lean": 0.36, "arms": 1.15, "fist": 0.75, "bob": 0.07, "knee": 1.15, "width": 0.07, "head": 0.06, "flail": 0.35, "shrug": 0.05},
	"Usayuko": {"cadence": 3.9, "lean": 0.27, "arms": 1.2, "fist": 1.05, "bob": 0.075, "knee": 0.95, "width": 0.1, "head": -0.04, "flail": 0.0, "shrug": 0.02},
	"Ashura": {"cadence": 4.0, "lean": 0.3, "arms": 0.85, "fist": 0.55, "bob": 0.05, "knee": 1.0, "width": 0.08, "head": 0.0, "flail": 0.0, "shrug": 0.0},
	"Lysia": {"cadence": 3.7, "lean": 0.14, "arms": 0.7, "fist": 0.2, "bob": 0.035, "knee": 0.8, "width": 0.06, "head": -0.06, "flail": 0.0, "shrug": 0.0},
	"Elly": {"cadence": 3.6, "lean": 0.22, "arms": 0.85, "fist": 0.35, "bob": 0.055, "knee": 0.9, "width": 0.05, "head": 0.06, "flail": 0.12, "shrug": 0.03},
	"Bleuette": {"cadence": 4.7, "lean": 0.18, "arms": 0.95, "fist": 0.45, "bob": 0.06, "knee": 1.1, "width": 0.07, "head": 0.1, "flail": 0.55, "shrug": 0.08},
	"Alice": {"cadence": 3.4, "lean": 0.34, "arms": 0.55, "fist": 0.15, "bob": 0.045, "knee": 1.05, "width": 0.025, "head": -0.16, "flail": 0.0, "shrug": 0.0},
}


static func style(person: String) -> Dictionary:
	return STYLE.get(person, STYLE.Simon)


# Bruit déterministe dans [-1, 1] : chaque pas, chaque clé varie un peu, jamais deux cycles identiques.
static func n1(seed_value: int, i: int) -> float:
	var x: float = sin(float(seed_value) * 12.9898 + float(i) * 78.233) * 43758.5453
	return (x - floor(x)) * 2.0 - 1.0


static func heading_of(direction: Vector3) -> float:
	return atan2(direction.x, direction.z)


static func ahead(theta: float) -> Vector3:
	return Vector3(sin(theta), 0.0, cos(theta))


# Gauche de l'acteur (dans E) pour un cap θ : son côté « side = -1 ».
static func leftward(theta: float) -> Vector3:
	return Vector3(cos(theta), 0.0, - sin(theta))


# ============================================================== Performer --
# La piste d'un acteur : trajectoire de la racine (E), canaux du clip, clés de pieds
# exprimées dans le monde (converties dans le repère de l'acteur à la fin).

class Performer extends RefCounted:
	var person: String = ""
	var index: int = -1
	var seed: int = 0
	var duration: float = 10.0
	var scale: float = 1.0
	var leg: float = 0.7
	var arm: Dictionary = {-1: 0.4, 1: 0.4}
	var base: Dictionary = {-1: Vector3(-0.1, 0.08, 0.0), 1: Vector3(0.1, 0.08, 0.0)}
	var hip: Dictionary = {-1: Vector3(-0.09, 0.8, 0.0), 1: Vector3(0.09, 0.8, 0.0)}
	var limb: Dictionary = {-1: 0.72, 1: 0.72}
	var pelvis: float = 0.8
	var toe: float = 0.05
	var height: float = 1.75
	var tracks: Dictionary = {}
	var strings: Dictionary = {}
	var segments: Array = []
	var feet_keys: Dictionary = {-1: [], 1: []}
	var end_t: float = 0.0
	var end_p: Vector3 = Vector3.ZERO
	var end_v: Vector3 = Vector3.ZERO
	# état des pieds pour enchaîner les modules : dernière position posée (E) et instant
	var foot_at: Dictionary = {-1: Vector3.ZERO, 1: Vector3.ZERO}
	var foot_free: Dictionary = {-1: 0.0, 1: 0.0}
	var _theta_track: Dictionary = {}
	var _hips_track: Dictionary = {}
	var _theta_dirty: bool = true
	var overreach: float = 0.0
	var overreach_t: float = -1.0

	func setup(visual: Node, who: String, at: int, length: float) -> void :
		person = who;index = at;duration = length
		seed = absi(who.hash()) % 977
		scale = float(visual.get("_model_scale"))
		leg = float(visual.get("_leg_reach")) * scale
		var arms: Dictionary = visual.get("_arm_length")
		var rest: Dictionary = visual.get("_foot_rest")
		var hips: Dictionary = visual.get("_hip_rest")
		var lengths: Dictionary = visual.get("_leg_length")
		var look: Dictionary = visual.get("_style")
		var width: float = float(look.get("stance", 1.0))
		for side: int in [-1, 1]:
			arm[side] = float(arms[side]) * scale
			var r: Vector3 = rest[side]
			base[side] = Vector3(r.x * width, r.y, r.z) * scale
			hip[side] = (hips[side] as Vector3) * scale
			limb[side] = float(lengths[side]) * scale
		pelvis = float(visual.get("_base_height")) * scale
		toe = float(visual.get("_toe_length")) * scale
		height = float(visual.call("visual_height"))

	# ---------------------------------------------------------- canaux
	func key(t: float, channel: String, value: Variant, flag: String = "") -> void :
		if not tracks.has(channel): tracks[channel] = []
		tracks[channel].append([t, value, flag])
		if channel == "turn": _theta_dirty = true
		if channel == "hips": _hips_track = {}

	func pose(t: float, values: Dictionary, flag: String = "") -> void :
		for channel: String in values:
			var value: Variant = values[channel]
			if value is String or value is StringName: text(t, channel, str(value))
			else: key(t, channel, value, flag)

	func text(t: float, channel: String, value: String) -> void :
		if not strings.has(channel): strings[channel] = []
		strings[channel].append([t, value])

	func face(t: float, mood: String) -> void :
		text(t, "face", mood)

	func ev(t: float, name: String) -> void :
		text(t, "ev", name)

	func fx(t: float, name: String) -> void :
		text(t, "fx", name)

	# ---------------------------------------------------------- racine (E)
	# Départ en `at` à l'instant t ; avec une vitesse, l'acteur court déjà (trajectoire prolongée avant t).
	func start(t: float, at: Vector3, v: Vector3 = Vector3.ZERO) -> void :
		segments.clear()
		end_t = t;end_p = at;end_v = v
		if v.length_squared() > 0.0001: segments.append({"k": "curve", "t0": t - 1.5, "t1": t, "p0": at - v * 1.5, "p1": at, "v0": v, "v1": v})
		else: segments.append({"k": "hold", "t0": -1.0, "t1": t, "p0": at})

	# Va de la fin actuelle jusqu'à `to` entre end_t et t1 (Hermite : vitesses de départ et d'arrivée).
	func go(t1: float, to: Vector3, v1: Vector3 = Vector3.ZERO) -> void :
		if t1 <= end_t + 0.001:
			if OS.is_debug_build() and to.distance_to(end_p) > 0.05:
				print("FILM_ESCAPE late go %s %.2f <= %.2f (%.2f m)" % [person, t1, end_t, to.distance_to(end_p)])
			end_p = to;end_v = v1
			return
		segments.append({"k": "curve", "t0": end_t, "t1": t1, "p0": end_p, "p1": to, "v0": end_v, "v1": v1})
		end_t = t1;end_p = to;end_v = v1

	func hold(t1: float) -> void :
		if t1 <= end_t + 0.001: return
		if end_v.length_squared() > 0.0001: go(t1, end_p + end_v * (t1 - end_t) * 0.5, Vector3.ZERO)
		else:
			segments.append({"k": "hold", "t0": end_t, "t1": t1, "p0": end_p})
			end_t = t1

	# Saut : trajectoire horizontale Hermite, verticale balistique (hauteur max `apex` au-dessus
	# de la droite qui joint le départ et l'arrivée).
	func leap(t1: float, to: Vector3, apex: float, v1: Vector3 = Vector3.ZERO) -> void :
		segments.append({"k": "leap", "t0": end_t, "t1": t1, "p0": end_p, "p1": to, "v0": Vector3(end_v.x, 0.0, end_v.z), "v1": Vector3(v1.x, 0.0, v1.z), "apex": apex})
		end_t = t1;end_p = to;end_v = v1

	func at(t: float) -> Vector3:
		if segments.is_empty(): return Vector3.ZERO
		for s: Dictionary in segments:
			if t <= float(s.t1): return _eval(s, t)
		var last: Dictionary = segments[segments.size() - 1]
		var p: Vector3 = _eval(last, float(last.t1))
		return p

	func velocity(t: float) -> Vector3:
		return (at(t + 0.01) - at(t - 0.01)) / 0.02

	func speed(t: float) -> float:
		var v: Vector3 = velocity(t)
		return Vector2(v.x, v.z).length()

	func _eval(s: Dictionary, t: float) -> Vector3:
		if str(s.k) == "hold": return s.p0
		var t0: float = float(s.t0)
		var span: float = maxf(float(s.t1) - t0, 0.001)
		var u: float = clampf((t - t0) / span, 0.0, 1.0)
		var u2: float = u * u
		var u3: float = u2 * u
		var p0: Vector3 = s.p0
		var p1: Vector3 = s.p1
		var m0: Vector3 = (s.v0 as Vector3) * span
		var m1: Vector3 = (s.v1 as Vector3) * span
		var p: Vector3 = p0 * (2.0 * u3 - 3.0 * u2 + 1.0) + m0 * (u3 - 2.0 * u2 + u) + p1 * (-2.0 * u3 + 3.0 * u2) + m1 * (u3 - u2)
		if str(s.k) == "leap":
			p.y = lerpf(p0.y, p1.y, u) + 4.0 * float(s.apex) * u * (1.0 - u)
		return p

	# ---------------------------------------------------------- cap (canal turn)
	func turn(t: float, theta: float, flag: String = "") -> void :
		key(t, "turn", theta, flag)

	func theta(t: float) -> float:
		if _theta_dirty:
			_theta_track = _compile_one("turn")
			_theta_dirty = false
		if _theta_track.is_empty(): return 0.0
		return float(AnimClip.sample(_theta_track, t, false, duration))

	func hips_at(t: float) -> Vector3:
		if _hips_track.is_empty(): _hips_track = _compile_one("hips")
		if _hips_track.is_empty(): return Vector3.ZERO
		return AnimClip.sample(_hips_track, t, false, duration)

	func _compile_one(channel: String) -> Dictionary:
		if not tracks.has(channel): return {}
		var keys: Array = []
		for entry: Array in _sorted(tracks[channel]):
			keys.append([entry[0], {channel: entry[1]}, entry[2]] if not str(entry[2]).is_empty() else [entry[0], {channel: entry[1]}])
		var clip: Dictionary = AnimClip.compile({"len": duration, "keys": keys})
		return clip.channels.get(channel, {})

	static func ahead(theta_value: float) -> Vector3:
		return Vector3(sin(theta_value), 0.0, cos(theta_value))

	static func _sorted(list: Array) -> Array:
		var copy: Array = list.duplicate()
		copy.sort_custom( func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		# une seule valeur par instant et par canal : la dernière écrite gagne
		var out: Array = []
		for entry: Array in copy:
			if not out.is_empty() and absf(float(out[out.size() - 1][0]) - float(entry[0])) < 0.0005: out[out.size() - 1] = entry
			else: out.append(entry)
		return out

	# ---------------------------------------------------------- repères
	# Point du monde (E) → repère de l'acteur (T, mètres) à l'instant t.
	func to_local(world_point: Vector3, t: float) -> Vector3:
		var d: Vector3 = world_point - at(t)
		var v: Vector3 = Vector3( - d.x, d.y, - d.z)
		return v.rotated(Vector3.UP, - theta(t))

	# Repère de l'acteur (T) → monde (E).
	func to_world(local_point: Vector3, t: float) -> Vector3:
		var v: Vector3 = local_point.rotated(Vector3.UP, theta(t))
		return at(t) + Vector3( - v.x, v.y, - v.z)

	# Position de repos d'une cheville dans le monde (E) à l'instant t, décalée de `fwd`/`out` m.
	func rest_foot(side: int, t: float, fwd: float = 0.0, out: float = 0.0) -> Vector3:
		var local: Vector3 = base[side] + Vector3(float(side) * out, 0.0, - fwd)
		return to_world(local, t)

	# ---------------------------------------------------------- pieds
	# Clé de pied dans le monde (E) : y = hauteur de la cheville au-dessus du sol de la racine.
	func foot_w(t: float, side: int, world_point: Vector3, pitch: float = 0.0, flag: String = "") -> void :
		feet_keys[side].append([t, "w", world_point, pitch, flag])

	# Clé de pied dans le repère de l'acteur (T, mètres, cheville).
	func foot_l(t: float, side: int, local_point: Vector3, pitch: float = 0.0, flag: String = "") -> void :
		feet_keys[side].append([t, "l", local_point, pitch, flag])

	# Pied posé au sol en `world_point` (y = 0 → cheville à sa hauteur de repos) de t0 à t1 :
	# clés serrées pour qu'il ne glisse pas pendant que la racine avance ou pivote.
	# Quand le pied se déroule (pitch < 0, talon levé), la cheville tourne autour de l'avant du
	# pied : elle monte et avance un peu ; l'avant du pied, lui, ne bouge pas.
	func plant(side: int, t0: float, t1: float, world_point: Vector3, pitch0: float = 0.0, pitch1: float = 0.0, last_flag: String = "", roll_from: float = 0.55) -> void :
		var ankle: float = float(base[side].y)
		var span: float = maxf(t1 - t0, 0.0)
		var steps: int = maxi(1, ceili(span / GRID))
		for k: int in range(steps + 1):
			var t: float = t0 + span * float(k) / float(steps)
			var u: float = float(k) / float(steps)
			var flag: String = "l" if k < steps else last_flag
			var pitch: float = lerpf(pitch0, pitch1, u)
			var p: Vector3 = Vector3(world_point.x, ankle, world_point.z)
			if pitch1 < 0.0 and u > roll_from:
				pitch = lerpf(pitch0 * (1.0 - roll_from), pitch1, smoothstep(roll_from, 1.0, u))
				var phi: float = - pitch
				var fwd: Vector3 = ahead(theta(t))
				p += fwd * toe * (1.0 - cos(phi)) + Vector3.UP * toe * sin(phi)
			elif pitch1 < 0.0:
				pitch = lerpf(pitch0, 0.0, smoothstep(0.0, roll_from, u))
			feet_keys[side].append([t, "w", p, pitch, flag])
		foot_at[side] = Vector3(world_point.x, 0.0, world_point.z)
		foot_free[side] = t1

	# Le pied est-il encore posé à l'instant t (son dernier appui n'est pas fini) ?
	func grounded(side: int, t: float) -> bool:
		return float(foot_free[side]) >= t - 0.03

	# ---------------------------------------------------------- compilation
	func compile_source(clip_name: String) -> Dictionary:
		_bake_feet()
		_solve_reach()
		overreach = 0.0
		for side: int in [-1, 1]:
			var foot: Dictionary = _compile_one("foot_l" if side < 0 else "foot_r")
			if foot.is_empty(): continue
			var probe: float = 0.0
			while probe <= duration:
				_check_reach(side, probe, (base[side] as Vector3) + (AnimClip.sample(foot, probe, false, duration) as Vector3) * leg)
				probe += GRID * 0.5
		var keys: Array = []
		for channel: String in tracks:
			for entry: Array in _sorted(tracks[channel]):
				if str(entry[2]).is_empty(): keys.append([entry[0], {channel: entry[1]}])
				else: keys.append([entry[0], {channel: entry[1]}, entry[2]])
		for channel: String in strings:
			var list: Array = strings[channel].duplicate()
			list.sort_custom( func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
			for entry: Array in list: keys.append([entry[0], {channel: entry[1]}])
		keys.sort_custom( func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		return {"len": duration, "loop": false, "in": 0.0, "out": 0.0, "face": "neutral", "keys": keys, "name": clip_name}

	func _bake_feet() -> void :
		for side: int in [-1, 1]:
			var channel: String = "foot_l" if side < 0 else "foot_r"
			var pitch_channel: String = "fp_l" if side < 0 else "fp_r"
			tracks.erase(channel)
			tracks.erase(pitch_channel)
			var list: Array = _sorted(feet_keys[side])
			for entry: Array in list:
				var t: float = float(entry[0])
				var local: Vector3 = to_local(entry[2], t) if str(entry[1]) == "w" else entry[2]
				_check_reach(side, t, local)
				key(t, channel, (local - (base[side] as Vector3)) / leg, str(entry[4]))
				key(t, pitch_channel, float(entry[3]), str(entry[4]))

	# Bassin abaissé juste ce qu'il faut, en douceur, partout où une cheville serait hors de portée
	# (pied loin devant au freinage, grande enjambée, réception de saut…).
	func _solve_reach() -> void :
		var feet: Dictionary = {-1: _compile_one("foot_l"), 1: _compile_one("foot_r")}
		var hips_old: Dictionary = _compile_one("hips")
		var times: Array[float] = []
		var drops: Array[float] = []
		var t: float = -0.3
		var worst: float = 0.0
		while t <= duration + 0.0001:
			var h: Vector3 = (AnimClip.sample(hips_old, t, false, duration) as Vector3) if not hips_old.is_empty() else Vector3.ZERO
			var drop: float = 0.0
			for side: int in [-1, 1]:
				if (feet[side] as Dictionary).is_empty(): continue
				var ankle: Vector3 = (base[side] as Vector3) + (AnimClip.sample(feet[side], t, false, duration) as Vector3) * leg
				var joint: Vector3 = (hip[side] as Vector3) + h * leg
				var reach: float = float(limb[side]) * 0.99
				var horiz: float = Vector2(ankle.x - joint.x, ankle.z - joint.z).length()
				var vert: float = joint.y - ankle.y
				var need: float = vert - sqrt(maxf(reach * reach - horiz * horiz, 0.0)) if horiz < reach else vert * 0.6
				drop = maxf(drop, clampf(need, 0.0, leg * 0.45))
			times.append(t);drops.append(drop)
			worst = maxf(worst, drop)
			t += GRID * 0.5
		if worst < 0.004: return
		var smooth: Array[float] = []
		smooth.resize(drops.size())
		for k: int in range(drops.size()):
			var m: float = 0.0
			for o: int in range(-3, 4):
				var idx: int = clampi(k + o, 0, drops.size() - 1)
				m = maxf(m, drops[idx] * (1.0 - absf(float(o)) * 0.12))
			smooth[k] = m
		var list: Array = []
		for k: int in range(times.size()):
			var h: Vector3 = (AnimClip.sample(hips_old, times[k], false, duration) as Vector3) if not hips_old.is_empty() else Vector3.ZERO
			list.append([times[k], h - Vector3(0.0, (smooth[k] + 0.004) / leg if smooth[k] > 0.0 else 0.0, 0.0), ""])
		tracks["hips"] = list
		_hips_track = {}

	# Garde-fou : la cheville visée doit rester à portée de la hanche (sinon le pied « flotte »).
	func _check_reach(side: int, t: float, local: Vector3) -> void :
		var h: Vector3 = (hip[side] as Vector3) + hips_at(t) * leg
		var over: float = local.distance_to(h) - float(limb[side]) * 0.995
		if over > overreach:
			overreach = over;overreach_t = t
			if OS.get_environment("ESC_FEET") == person and over > 0.3:
				print("REACH %s side=%d t=%.2f over=%.2f local=%s root=%s theta=%.2f" % [person, side, t, over, local, at(t), theta(t)])


# ============================================================ locomotion --

# Course écrite au mètre près sur la trajectoire de la racine déjà posée (p.go…) entre t0 et t1.
# Les appuis alternent ; chaque pied posé reste fixe dans le monde pendant que le corps passe
# au-dessus, puis le talon monte, le genou repasse devant et le pied va se poser plus loin.
# Le buste se penche selon l'accélération (en arrière au freinage, les pieds se posent alors
# plus loin devant), les bras s'opposent aux jambes, la tête reste stable ; chaque pas varie.
# opts : first (côté du premier pied qui part), stop (finit les deux pieds posés sous le corps),
#        moving (le cycle tourne déjà à t0 : appuis « virtuels » avant t0), lean, arms, cadence (×),
#        face, low (bassin), takeoff (finit sur l'appui d'élan : rend son instant et son côté),
#        no_arms, no_upper (seulement les jambes et le bassin)
static func run(p: Performer, t0: float, t1: float, opts: Dictionary = {}) -> Dictionary:
	var st: Dictionary = style(p.person)
	var leg: float = p.leg
	var first: int = int(opts.get("first", 1))
	var cad_mul: float = float(opts.get("cadence", 1.0))
	var stop: bool = bool(opts.get("stop", true))
	var moving: bool = bool(opts.get("moving", false))
	var seed_value: int = p.seed + int(opts.get("seed", 0))
	var width: float = float(st.width) + float(opts.get("width", 0.0))
	# fin du mouvement de la racine
	var t_stop: float = t1
	if stop:
		var probe: float = t1
		while probe > t0 + 0.1 and p.speed(probe) < 0.08: probe -= GRID
		t_stop = minf(t1, probe + GRID)
	# 1) appuis : instants et positions
	var steps: Array = []
	var side: int = first
	var t: float = t0 + float(opts.get("delay", 0.05))
	if moving:
		var v0: float = maxf(p.speed(t0), 3.0)
		t = t0 - 2.0 / (_cadence(st, v0) * cad_mul)
	var count: int = 0
	while true:
		var v_now: float = maxf(p.speed(maxf(t, t0)), 0.0)
		var jitter: float = 1.0 + 0.045 * n1(seed_value, count)
		var cadence: float = _cadence(st, v_now) * cad_mul * jitter
		var land: float = t + 1.0 / cadence
		# départ arrêté ou freinage : la cadence suit la vitesse pendant le pas, pas celle du début
		for iteration: int in range(3):
			var v_mid: float = maxf(p.speed(clampf((t + land) * 0.5, t0, t1)), 0.0)
			var v_end: float = maxf(p.speed(clampf(land, t0, t1)), 0.0)
			cadence = _cadence(st, maxf(v_mid, v_end * 0.85)) * cad_mul * jitter
			land = t + 1.0 / cadence
		if stop and (land > t_stop - 0.04 or (land > t0 + 0.3 and p.speed(land) < 0.9)): break
		if not stop and land > t1 + 0.0001: break
		var v_land: float = maxf(p.speed(land), 0.0)
		var stance: float = _stance(p, v_land, _cadence(st, v_land) * cad_mul)
		var theta: float = p.theta(land)
		var vel: Vector3 = p.velocity(land)
		var dir: Vector3 = Vector3(vel.x, 0.0, vel.z).normalized() if v_land > 0.3 else ahead(theta)
		var accel: float = (p.speed(land + 0.05) - p.speed(land - 0.05)) / 0.1
		var lead: float = v_land * stance * 0.42 + 0.015 * leg - clampf(accel, -14.0, 6.0) * 0.011
		var lat: float = absf(float(p.base[side].x)) * 0.55 + width * leg * 0.3
		var spot: Vector3 = p.at(land) + dir * lead + leftward(theta) * ( - float(side) * lat)
		steps.append({"side": side, "land": land, "off": land + stance, "at": spot, "speed": v_land, "stance": stance, "accel": accel, "i": count})
		side = - side
		t = land
		count += 1
	# 2) arrêt : les pieds reviennent sous le corps, le pied le plus loin d'abord
	if stop:
		var settle_t: float = maxf(t_stop - 0.1, t0 + 0.1)
		if not steps.is_empty(): settle_t = maxf(settle_t, float(steps[steps.size() - 1].land) + 0.13)
		var order: Array[int] = [-1, 1]
		var dist: Dictionary = {}
		for sd: int in [-1, 1]:
			var last_spot: Vector3 = _last_spot(steps, sd, p.foot_at[sd])
			dist[sd] = last_spot.distance_to(p.rest_foot(sd, t_stop))
		if float(dist[1]) > float(dist[-1]): order = [1, -1]
		var gap: float = 0.0
		for sd: int in order:
			if float(dist[sd]) < 0.07: continue
			var land: float = settle_t + gap
			steps.append({"side": sd, "land": land, "off": t1 + 1.0, "at": p.rest_foot(sd, t_stop), "speed": 0.0, "stance": 0.3, "accel": 0.0, "i": count, "settle": true})
			gap += 0.15 + 0.03 * n1(seed_value + 5, count)
			count += 1
	# 3) pieds : avant le premier pas, chaque pied est posé où il était
	var planted_from: Dictionary = {-1: t0, 1: t0}
	for sd: int in [-1, 1]:
		var first_step: Dictionary = {}
		for s: Dictionary in steps:
			if int(s.side) == sd:
				first_step = s
				break
		if moving or first_step.is_empty() and not stop: continue
		var lift: float = (float(first_step.land) - 1.0 / maxf(_cadence(st, 2.0), 0.1) * 0.9) if not first_step.is_empty() else t1
		if not first_step.is_empty(): lift = maxf(t0, minf(lift, float(first_step.land) - 0.16))
		var from_spot: Vector3 = p.foot_at[sd] if (p.foot_at[sd] as Vector3) != Vector3.ZERO else p.rest_foot(sd, t0)
		p.plant(sd, t0, lift, from_spot, 0.0, -0.25 if not first_step.is_empty() else 0.0)
		planted_from[sd] = lift
		if not first_step.is_empty():
			_swing(p, sd, lift, from_spot, float(first_step.land), first_step.at, float(first_step.speed), -0.25, 0, st, seed_value)
	for j: int in range(steps.size()):
		var s: Dictionary = steps[j]
		var sd: int = int(s.side)
		var v: float = float(s.speed)
		var walking: bool = v < 2.2
		var strike: float = (0.2 if walking else 0.07) + 0.04 * n1(seed_value + 3, j)
		if bool(s.get("settle", false)): strike = 0.05
		var push: float = (-0.55 if walking else -0.85) + 0.1 * n1(seed_value + 7, j)
		var next: Dictionary = {}
		for m: int in range(j + 1, steps.size()):
			if int(steps[m].side) == sd:
				next = steps[m]
				break
		if next.is_empty():
			if stop or bool(s.get("settle", false)):
				p.plant(sd, float(s.land), t1, s.at, strike, 0.0)
			else:
				p.plant(sd, float(s.land), minf(float(s.off), t1), s.at, strike, push * 0.4)
			continue
		var off: float = float(s.off)
		if float(next.land) - off < 0.12: off = float(next.land) - 0.12
		p.plant(sd, float(s.land), off, s.at, strike, push * 0.8)
		if float(s.land) >= t0: p.fx(float(s.land), "fstep_l" if sd < 0 else "fstep_r")
		_swing(p, sd, off, s.at, float(next.land), next.at, maxf(v, float(next.speed)), push, j, st, seed_value)
	if bool(opts.get("no_upper", false)): return {"steps": steps}
	# 4) bassin et haut du corps, une pose par appui
	var lean_base: float = float(st.lean) * float(opts.get("lean", 1.0))
	var arms: float = float(st.arms) * float(opts.get("arms", 1.0))
	var bob: float = float(st.bob) * leg
	var upper_until: float = float(opts.get("upper_until", INF))
	for j: int in range(steps.size()):
		var s: Dictionary = steps[j]
		if bool(s.get("settle", false)): continue
		if float(s.land) > upper_until: continue
		var sd: int = int(s.side)
		var v: float = float(s.speed)
		var run_w: float = smoothstep(1.2, 4.5, v)
		var land: float = float(s.land)
		var stance: float = float(s.stance)
		var mid: float = land + stance * 0.5
		var accel: float = clampf(float(s.accel), -14.0, 6.0)
		var wob: float = n1(seed_value + 17, j)
		var wob2: float = n1(seed_value + 23, j)
		var low: float = float(opts.get("low", 0.05)) * leg * run_w + maxf(0.0, - accel) * 0.005 * leg
		p.key(mid, "hips", Vector3(float(sd) * 0.022 * (1.0 + 0.2 * wob), (- low - bob * run_w * (1.0 + 0.25 * wob)) / leg, - 0.02 * run_w))
		if j + 1 < steps.size() and not bool(steps[j + 1].get("settle", false)):
			var nxt: float = float(steps[j + 1].land)
			p.key(maxf((land + stance + nxt) * 0.5, mid + 0.03), "hips", Vector3(float(sd) * 0.005, (- low + bob * 0.5 * run_w) / leg, - 0.025 * run_w))
		var lean_now: float = lean_base * run_w + accel * 0.03
		var yaw: float = float(sd) * (0.1 * run_w + 0.04)
		var tilt: float = float(sd) * -0.035
		p.key(land + stance * 0.3, "body", Vector3( - (lean_now + 0.025 * wob), yaw, tilt))
		p.key(land + stance * 0.3, "chest", Vector3( - (0.04 * run_w + 0.02 * wob2) + minf(0.0, accel) * -0.006, - yaw * 1.6 * arms, float(sd) * 0.02))
		p.key(land + stance * 0.3 + 0.05, "head", Vector3(lean_now * 0.75 + float(st.head) + 0.03 * wob2, - yaw * 0.5, - tilt * 0.6))
		if bool(opts.get("no_arms", false)): continue
		var at_t: float = land + stance * 0.4 + 0.035
		var front: int = - sd
		var a: float = arms * (1.0 + 0.1 * wob2) * lerpf(0.4, 1.0, run_w)
		var fl: float = float(st.flail) * (0.6 + 0.4 * wob)
		var brace: float = clampf( - accel / 10.0, 0.0, 1.0)
		var fwd_hand: Vector3 = Vector3(0.06 + 0.18 * fl + 0.25 * brace, -0.5 + 0.12 * a - 0.05 * fl + 0.35 * brace, 0.12 + 0.28 * a + 0.15 * brace)
		var back_hand: Vector3 = Vector3(0.12 + 0.2 * fl + 0.3 * brace, -0.72 + 0.06 * a + 0.35 * brace, -0.12 - 0.36 * a + 0.4 * brace)
		var pose_keys: Dictionary = M([_ik(front, fwd_hand, 0.2 + 0.35 * fl, 1.0), _ik(sd, back_hand, 0.3 + 0.3 * fl, 1.0)])
		pose_keys["curl"] = float(st.fist) * (1.0 - 0.6 * brace) + 0.08 * wob
		pose_keys["curl_l"] = float(st.fist) * (1.0 - 0.6 * brace) + 0.08 * wob2
		pose_keys["l_hand"] = Vector3(0.15 * a, 0.25, 0.0)
		pose_keys["r_hand"] = Vector3(0.15 * a, -0.25, 0.0)
		p.pose(at_t, pose_keys)
	if not str(opts.get("face", "")).is_empty(): p.face(t0, str(opts.face))
	var result: Dictionary = {"steps": steps, "stop": t_stop}
	if not steps.is_empty():
		var last: Dictionary = steps[steps.size() - 1]
		result["last_side"] = int(last.side)
		result["last_land"] = float(last.land)
	return result


static func _last_spot(steps: Array, side: int, fallback: Vector3) -> Vector3:
	var spot: Vector3 = fallback
	for s: Dictionary in steps:
		if int(s.side) == side: spot = s.at
	return spot


# Vol d'un pied entre deux appuis (clés dans le repère de l'acteur) : en course, le talon
# remonte derrière puis le genou repasse devant ; en petit pas, simple arc bas.
static func _swing(p: Performer, side: int, t_off: float, from_w: Vector3, t_land: float, to_w: Vector3, v: float, push: float, j: int, st: Dictionary, seed_value: int) -> void :
	var leg: float = p.leg
	var swing: float = t_land - t_off
	if swing < 0.06: return
	var ankle: float = float(p.base[side].y)
	var x_rest: float = float(p.base[side].x)
	var off_l: Vector3 = p.to_local(Vector3(from_w.x, ankle, from_w.z), t_off)
	var land_l: Vector3 = p.to_local(Vector3(to_w.x, ankle, to_w.z), t_land)
	var run_w: float = smoothstep(1.6, 4.0, v)
	var travel: float = Vector2(to_w.x - from_w.x, to_w.z - from_w.z).length()
	var lift: float = lerpf(clampf(travel * 0.22, 0.03, 0.12) * leg / 0.7, leg * (0.2 + 0.3 * smoothstep(2.0, 6.0, v)) * float(st.knee), run_w) * (1.0 + 0.1 * n1(seed_value + 11, j))
	var heel: float = p.toe * sin(clampf( - push, 0.0, 1.0))
	p.foot_l(t_off + 0.015, side, off_l + Vector3(0.0, heel + 0.01, 0.0), push)
	if run_w > 0.5:
		p.foot_l(t_off + swing * 0.28, side, Vector3(lerpf(off_l.x, x_rest, 0.5), ankle + lift * 0.85, off_l.z * 0.5 + 0.08 * leg), -0.95)
		p.foot_l(t_off + swing * 0.56, side, Vector3(x_rest, ankle + lift * 0.72, - 0.1 * leg), -0.3)
		p.foot_l(t_off + swing * 0.82, side, Vector3(lerpf(x_rest, land_l.x, 0.7), ankle + lift * 0.28 + 0.015, land_l.z - 0.04 * leg), 0.14)
	else:
		var mid: Vector3 = off_l.lerp(land_l, 0.5)
		p.foot_l(t_off + swing * 0.5, side, Vector3(lerpf(mid.x, x_rest, 0.3), ankle + lift, mid.z), -0.1)
		p.foot_l(t_off + swing * 0.8, side, Vector3(land_l.x, ankle + lift * 0.35, land_l.z - 0.02), 0.12)


# Abaisse le bassin si le pied posé en avant ne serait pas atteignable.
static func _reach_drop(p: Performer, side: int, s: Dictionary) -> float:
	var v: float = float(s.speed)
	var lead: float = v * float(s.stance) * 0.52 + 0.04 * p.leg
	var h: float = float(p.hip[side].y) - float(p.base[side].y)
	var limit: float = float(p.limb[side]) * 0.97
	if lead >= limit: return h * 0.35
	var need: float = h - sqrt(limit * limit - lead * lead)
	return maxf(0.0, need)


static func _cadence(st: Dictionary, v: float) -> float:
	# pas/s : marche ~1,8 ; course 5,5 m/s ~ cadence du perso
	var walk: float = 1.7 + 0.25 * v
	var running: float = float(st.cadence) * (0.82 + 0.033 * v)
	return lerpf(walk, running, smoothstep(1.6, 3.4, v))


static func _stance(p: Performer, v: float, cadence: float) -> float:
	var period: float = 2.0 / cadence
	var walk: float = period * 0.62
	var sweep: float = p.leg * 0.7
	var running: float = clampf(sweep / maxf(v, 0.5), period * 0.17, period * 0.4)
	return lerpf(walk, running, smoothstep(1.6, 3.4, v))


static func _ik(side: int, at: Vector3, flare: float, frame: float) -> Dictionary:
	if side < 0: return {"ik_l": Vector3( - at.x, at.y, - at.z), "el_l": flare, "tf_l": frame, "gr_l": 0.0, "ikw_l": 1.0}
	return {"ik_r": Vector3(at.x, at.y, - at.z), "el_r": flare, "tf_r": frame, "gr_r": 0.0, "ikw_r": 1.0}


# Pose de départ : tous les canaux que le moteur pourrait laisser à une autre couche.
static func base_pose() -> Dictionary:
	return {"plant": 1.0, "gait": 0.0, "gsnap": 0.0, "shake": 0.0, "jaw": 0.0, "chatter": 0.0, "sq": 1.0,
		"el_l": 0.15, "el_r": 0.15, "hips": Vector3.ZERO, "body": Vector3.ZERO, "chest": Vector3.ZERO,
		"head": Vector3.ZERO, "l_clav": Vector3.ZERO, "r_clav": Vector3.ZERO, "l_hand": Vector3.ZERO, "r_hand": Vector3.ZERO,
		"ik_l": Vector3(-0.22, -0.93, -0.04), "ik_r": Vector3(0.22, -0.93, -0.04), "tf_l": 0.0, "tf_r": 0.0, "gr_l": 0.0, "gr_r": 0.0,
		"ikw_l": 1.0, "ikw_r": 1.0, "curl": 0.35, "curl_l": 0.35}


# Les deux pieds posés à leur place de repos autour de la racine, de t0 à t1.
static func stand(p: Performer, t0: float, t1: float, spread: float = 0.0, stagger: float = 0.0) -> void :
	for side: int in [-1, 1]:
		p.plant(side, t0, t1, p.rest_foot(side, t0, stagger * float(side) * 0.5, spread * 0.5))


# ============================================================ utilitaires --

# Point du monde à `r` m à droite et `f` m devant `spot` pour un acteur au cap θ.
static func w(spot: Vector3, theta: float, r: float, f: float, up: float = 0.0) -> Vector3:
	var fwd: Vector3 = ahead(theta)
	var right: Vector3 = - leftward(theta)
	return spot + right * r + fwd * f + Vector3.UP * up


# Clés relatives à t0 : [dt, pose (canaux ou textes), drapeau éventuel].
static func keys(p: Performer, t0: float, list: Array) -> void :
	for entry: Array in list:
		p.pose(t0 + float(entry[0]), entry[1], str(entry[2]) if entry.size() > 2 else "")


static func arms_down(spread: float = 0.0, fwd: float = 0.04, curl: float = 0.35) -> Dictionary:
	return M([L(0.2 + spread, -0.92, fwd, 0.15), R(0.2 + spread, -0.92, fwd, 0.15), WL(0.0), WR(0.0), {"curl": curl, "curl_l": curl}])


# Pose debout neutre, propre à chacun (là où les modules reviennent au calme).
static func neutral(person: String) -> Dictionary:
	match person:
		"Usayuko": return M([H(0, -0.03, 0), B(-0.02, 0.0, 0.0), C(-0.04), HD(0.04), L(0.26, -0.9, 0.02, 0.2), R(0.26, -0.9, 0.02, 0.2), {"curl": 0.8, "curl_l": 0.8}])
		"Ashura": return M([H(0, -0.04, 0), B(0.05, 0.05), C(0.03), HD(-0.02, -0.05), L(0.18, -0.92, 0.0, 0.1), R(0.2, -0.9, 0.04, 0.12), {"curl": 0.45, "curl_l": 0.4}])
		"Lysia": return M([H(0, 0.0, 0), B(0.0), C(0.0), HD(0.0, 0.0, 0.05), L(0.16, -0.95, 0.03, 0.05), R(0.16, -0.95, 0.03, 0.05), {"curl": 0.15, "curl_l": 0.15}])
		"Elly": return M([H(0, -0.02, 0), B(0.02), C(0.02), HD(0.0, 0.0, 0.04), L(0.17, -0.92, 0.06, 0.1), R(0.17, -0.92, 0.06, 0.1), {"curl": 0.3, "curl_l": 0.3}])
		"Bleuette": return M([H(0, -0.05, 0), B(0.06), C(0.06), HD(-0.06, 0.0, 0.06), L(0.1, -0.7, 0.28, 0.1), R(0.1, -0.68, 0.3, 0.1), WL(0.2), WR(0.2), {"curl": 0.55, "curl_l": 0.55}])
		"Alice": return M([H(0, -0.04, 0), B(0.08), C(0.1), HD(0.06, 0.0, -0.08), L(0.24, -0.86, 0.12, 0.35), R(0.26, -0.84, 0.14, 0.35), WL(0.3, 0.0, 0.2), WR(0.3, 0.0, -0.2), {"curl": 0.55, "curl_l": 0.55}])
	return M([H(0, -0.03, 0), B(0.03), C(0.02), HD(0.0), L(0.2, -0.92, 0.04, 0.12), R(0.2, -0.92, 0.04, 0.12), {"curl": 0.4, "curl_l": 0.4}])


# Pose de garde tendue (on attend, on surveille Alice), propre à chacun.
static func tense(person: String) -> Dictionary:
	match person:
		"Usayuko": return M([H(0, -0.1, 0), B(0.14, 0.0), C(0.08), HD(0.02), Lt(0.05, -0.32, 0.45, 0.3), Rt(0.12, -0.38, 0.4, 0.3), WL(0.2), WR(0.2), {"curl": 1.0, "curl_l": 1.0}])
		"Ashura": return M([H(0, -0.12, 0), B(0.16, 0.05), C(0.06), HD(0.08, -0.04), L(0.32, -0.7, 0.12, 0.3), R(0.34, -0.66, 0.2, 0.3), {"curl": 0.6, "curl_l": 0.55}])
		"Lysia": return M([H(0, -0.04, 0), B(0.04), C(0.02), HD(0.02, 0.0, 0.1), L(0.2, -0.88, 0.14, 0.15), R(0.22, -0.86, 0.16, 0.15), {"curl": 0.25, "curl_l": 0.25}])
		"Elly": return M([H(0, -0.08, 0), B(0.08), C(0.04), HD(0.04), L(0.38, -0.62, 0.3, 0.3), R(0.26, -0.78, 0.18, 0.2), WL(0.3, 0.0, 0.3), {"curl": 0.25, "curl_l": 0.15}])
		"Bleuette": return M([H(0, -0.14, 0), B(0.16), C(0.14), HD(-0.12, 0.0, 0.08), Lt(-0.05, -0.12, 0.42, 0.2), Rt(-0.02, -0.08, 0.42, 0.2), WL(0.6), WR(0.6), {"curl": 0.75, "curl_l": 0.75, "shake": 0.35}])
		"Simon": return M([H(0, -0.1, 0), B(0.12), C(0.1), HD(0.02), L(0.3, -0.62, 0.3, 0.35), R(0.32, -0.6, 0.28, 0.35), WL(0.4), WR(0.4), {"curl": 0.2, "curl_l": 0.2, "shake": 0.2}])
	return neutral(person)


# ============================================================== attentes --

# Attente sur place, sans boucle : respiration, transfert de poids, regards (Alice, la haie,
# les autres), un geste propre à chacun. Les pieds restent posés (rien ne glisse).
static func wait(p: Performer, t0: float, t1: float, opts: Dictionary = {}) -> void :
	var span: float = t1 - t0
	if span < 0.15: return
	var seed_value: int = p.seed + int(opts.get("seed", 0))
	var base: Dictionary = opts.get("pose", tense(p.person))
	var look_back: float = float(opts.get("look", 0.0))
	var mood: String = str(opts.get("face", "fear"))
	var beats: int = maxi(2, int(span / 0.42))
	p.face(t0, mood)
	for k: int in range(beats + 1):
		var u: float = float(k) / float(beats)
		var t: float = t0 + span * u + 0.05 * n1(seed_value, k)
		if t > t1 - 0.02: t = t1 - 0.02
		var breathe: float = sin(float(k) * 2.4 + float(seed_value)) * 0.5 + 0.5
		var shift: float = n1(seed_value + 3, k / 2)
		var glance: float = look_back * (1.0 if (k + seed_value) % 3 == 0 else 0.25) * signf(n1(seed_value + 9, k) + 0.2)
		var pose: Dictionary = base.duplicate()
		var body: Vector3 = pose.get("body", Vector3.ZERO)
		var chest: Vector3 = pose.get("chest", Vector3.ZERO)
		var head: Vector3 = pose.get("head", Vector3.ZERO)
		var hips: Vector3 = pose.get("hips", Vector3.ZERO)
		pose["hips"] = hips + Vector3(0.025 * shift, -0.012 * breathe, 0.0)
		pose["body"] = body + Vector3(-0.012 * breathe, 0.03 * shift, -0.03 * shift)
		pose["chest"] = chest + Vector3(0.03 * breathe, -0.02 * shift, 0.02 * shift)
		pose["head"] = head + Vector3(0.04 * n1(seed_value + 5, k), glance * 0.9 + 0.08 * n1(seed_value + 7, k), 0.04 * shift)
		p.pose(t, pose)


# Demi-tour (ou quart de tour) sur place en deux pas : la tête part d'abord, le pied du côté
# du virage pivote puis l'autre le rejoint ; le bassin plonge un peu pendant le transfert.
static func pivot(p: Performer, t0: float, t1: float, spot: Vector3, theta_to: float, opts: Dictionary = {}) -> void :
	var theta_from: float = p.theta(t0)
	var delta: float = theta_to - theta_from
	var turn_side: int = 1 if delta < 0.0 else -1
	var span: float = t1 - t0
	p.turn(t0, theta_from, "s")
	p.turn(t0 + span * 0.18, theta_from + delta * 0.08)
	p.turn(t1, theta_to, "s")
	var lead: int = turn_side
	var trail: int = - turn_side
	var t_a: float = t0 + span * 0.12
	var t_b: float = t0 + span * 0.55
	var t_c: float = t0 + span * 0.5
	var t_d: float = t1
	var lead_from: Vector3 = p.foot_at[lead] if (p.foot_at[lead] as Vector3) != Vector3.ZERO else p.rest_foot(lead, t0)
	var trail_from: Vector3 = p.foot_at[trail] if (p.foot_at[trail] as Vector3) != Vector3.ZERO else p.rest_foot(trail, t0)
	var spread: float = float(opts.get("spread", 0.0))
	var lead_to: Vector3 = w(spot, theta_to, float(lead) * (absf(float(p.base[lead].x)) + spread * 0.5), 0.0)
	var trail_to: Vector3 = w(spot, theta_to, float(trail) * (absf(float(p.base[trail].x)) + spread * 0.5), float(opts.get("stagger", 0.0)))
	p.plant(lead, p.foot_free[lead] if float(p.foot_free[lead]) < t0 else t0, t_a, lead_from)
	p.plant(trail, p.foot_free[trail] if float(p.foot_free[trail]) < t0 else t0, t_c, trail_from)
	var st: Dictionary = style(p.person)
	_swing(p, lead, t_a, lead_from, t_b, lead_to, 0.8, -0.2, 1, st, p.seed)
	p.plant(lead, t_b, t1, lead_to)
	_swing(p, trail, t_c, trail_from, t_d, trail_to, 0.8, -0.2, 2, st, p.seed)
	p.plant(trail, t_d, t1, trail_to)
	p.hold(t1)
	var head_lead: float = clampf(delta, -1.4, 1.4) * 0.45
	p.pose(t0 + span * 0.08, {"head": HD(0.02, head_lead, 0.0).head})
	p.pose(t0 + span * 0.5, {"hips": H(0.0, -0.08, 0.0).hips, "body": B(0.08, clampf(delta, -1.0, 1.0) * 0.18).body})
	p.pose(t1 - span * 0.1, {"head": HD(0.0, - head_lead * 0.15, 0.0).head})
	p.foot_at[lead] = Vector3(lead_to.x, 0.0, lead_to.z)
	p.foot_at[trail] = Vector3(trail_to.x, 0.0, trail_to.z)
	p.foot_free[lead] = t1;p.foot_free[trail] = t1


# Quelques pas (marche ou trot) jusqu'à `to`, en finissant au cap θ.
static func step_to(p: Performer, t0: float, t1: float, to: Vector3, theta_to: float, opts: Dictionary = {}) -> Dictionary:
	var from: Vector3 = p.end_p
	var theta_from: float = p.theta(t0)
	var travel: Vector3 = to - from
	travel.y = 0.0
	var span: float = t1 - t0
	var mid_speed: float = travel.length() / maxf(span, 0.1) * 1.45
	var dir: Vector3 = travel.normalized() if travel.length() > 0.01 else ahead(theta_from)
	p.hold(t0)
	p.go(t0 + span * 0.5, from.lerp(to, 0.5), dir * mid_speed)
	p.go(t1, to, Vector3.ZERO)
	var face_dir: float = heading_of(dir) if travel.length() > 0.4 and bool(opts.get("face_travel", true)) else theta_from
	face_dir = theta_from + wrapf(face_dir - theta_from, -PI, PI)
	var end_theta: float = face_dir + wrapf(theta_to - face_dir, -PI, PI)
	p.turn(t0, theta_from, "s")
	if absf(face_dir - theta_from) > 0.05: p.turn(t0 + minf(0.3, span * 0.35), face_dir)
	p.turn(t1, end_theta, "s")
	var result: Dictionary = run(p, t0, t1 + 0.12, {"stop": true, "first": int(opts.get("first", 1)), "seed": int(opts.get("seed", 0)), "no_upper": bool(opts.get("no_upper", false))})
	return result


# ================================================================ gestes --
# Chaque geste part de la position actuelle (racine immobile sauf mention), cap θ vers Alice.

# Simon : main à la poche, goupille, armé du bras, lancer par-dessus l'épaule avec le pas
# en avant, puis il détourne la tête et se cache les yeux (il connaît sa flashbang).
# Rend l'instant du lâcher.
static func flash(p: Performer, t: float, theta: float) -> float:
	var s: Vector3 = p.end_p
	p.hold(t + 1.2)
	p.turn(t, p.theta(t), "s")
	p.turn(t + 0.3, theta, "s")
	var front_from: Vector3 = p.foot_at[-1]
	var front_to: Vector3 = w(s, theta, -0.14, 0.32)
	p.plant(1, p.foot_free[1], t + 1.2, p.foot_at[1])
	p.plant(-1, p.foot_free[-1], t + 0.4, front_from)
	_swing(p, -1, t + 0.4, front_from, t + 0.55, front_to, 1.0, -0.3, 3, style(p.person), p.seed)
	p.plant(-1, t + 0.55, t + 1.2, front_to)
	keys(p, t, [
		[0.0, {"face": "focus"}],
		[0.1, M([H(0, -0.08, 0), B(0.1, -0.12), C(0.06, -0.1), HD(-0.18, -0.2), Rt(0.24, -0.8, -0.04, 0.3), WR(0.3), Lt(0.2, -0.5, 0.3, 0.2), {"curl": 0.6}])],
		[0.24, M([H(0, -0.06, 0), B(0.06, -0.05), C(0.03), HD(-0.08, 0.0), Rt(0.08, -0.36, 0.3, 0.2), Lt(-0.02, -0.33, 0.36, 0.2), WR(0.2), WL(0.3), {"curl": 0.95, "curl_l": 0.8}])],
		[0.32, M([Lt(0.36, -0.26, 0.3, 0.3), WL(-0.2), {"curl_l": 0.9, "ev": "effort", "face": "determined"}])],
		[0.44, M([H(0.02, -0.1, 0.03), B(-0.04, -0.42, -0.06), C(-0.08, -0.25), HD(0.08, 0.5, 0.05), Rt(0.34, 0.28, -0.3, 0.5), WR(-0.5), Lt(0.18, 0.02, 0.8, 0.1), WL(0.0), {"curl_l": 0.2}]), "s"],
		[0.55, M([H(-0.02, -0.14, -0.06), B(0.22, 0.38, 0.05), C(0.1, 0.3), HD(0.05, -0.4), Rt(0.08, 0.36, 0.62, 0.3), WR(0.4), Lt(0.3, -0.4, -0.1, 0.3), {"fx": "whoosh", "ev": "grunt"}])],
		[0.66, M([H(-0.02, -0.17, -0.08), B(0.36, 0.42, 0.06), C(0.18, 0.25), HD(0.1, -0.3), Rt(-0.28, -0.58, 0.42, 0.2), WR(0.2), Lt(0.32, -0.62, -0.2, 0.3), {"curl": 0.4}])],
		[0.8, M([H(0, -0.16, -0.04), B(0.2, -0.2, 0.1), C(0.22, -0.2), HD(-0.25, -0.75, 0.2), Rt(-0.08, 0.32, 0.25, 0.6), WR(0.6, 0.0, 0.4), Lt(0.2, -0.55, 0.15, 0.2), {"curl": 0.7, "face": "panic", "shake": 0.25}])],
		[1.05, M([HD(-0.2, -0.6, 0.18), Rt(-0.06, 0.28, 0.28, 0.6), {"shake": 0.5}])],
		[1.18, M([H(0, -0.1, 0), B(0.12, -0.05), C(0.1), HD(0.02, -0.15, 0.05), Rt(0.18, -0.25, 0.3, 0.4), WR(0.2), {"face": "surprise", "shake": 0.1}])],
	])
	return t + 0.57


# Ashura : il décroche le drone de son dos, armé en bas, lâcher vers l'avant comme un oiseau,
# puis les deux pouces sur la télécommande imaginaire ; petit poing quand ça touche.
static func drone(p: Performer, t: float, theta: float) -> float:
	var s: Vector3 = p.end_p
	p.hold(t + 1.15)
	p.turn(t, p.theta(t), "s")
	p.turn(t + 0.28, theta, "s")
	var left_to: Vector3 = w(s, theta, -0.16, 0.22)
	var right_to: Vector3 = w(s, theta, 0.14, -0.14)
	var st: Dictionary = style(p.person)
	p.plant(1, p.foot_free[1], t + 0.12, p.foot_at[1])
	_swing(p, 1, t + 0.12, p.foot_at[1], t + 0.3, right_to, 0.8, -0.2, 4, st, p.seed)
	p.plant(1, t + 0.3, t + 1.15, right_to)
	p.plant(-1, p.foot_free[-1], t + 0.36, p.foot_at[-1])
	_swing(p, -1, t + 0.36, p.foot_at[-1], t + 0.5, left_to, 1.0, -0.3, 5, st, p.seed)
	p.plant(-1, t + 0.5, t + 1.15, left_to)
	keys(p, t, [
		[0.0, {"face": "focus"}],
		[0.12, M([H(0, -0.06, 0), B(0.08, -0.3), C(0.04, -0.3), HD(0.0, 0.25), Rt(0.12, -0.28, -0.32, 0.4), WR(0.5), L(0.3, -0.8, 0.1, 0.2), {"curl": 0.5}])],
		[0.26, M([H(0, -0.16, 0.02), B(0.26, -0.1), C(0.1, -0.05), HD(0.12, 0.05), Rt(0.22, -0.7, -0.15, 0.3), WR(-0.2), Lt(0.22, -0.4, 0.4, 0.2), {"curl": 0.85}]), "s"],
		[0.44, M([H(0, -0.04, -0.04), B(0.05, 0.12), C(-0.06, 0.1), HD(0.16, -0.05), Rt(0.1, 0.12, 0.78, 0.2), WR(0.5), Lt(0.3, -0.62, -0.05, 0.2), {"curl": 0.2, "fx": "whoosh", "face": "determined"}])],
		[0.6, M([H(0, -0.06, 0), B(0.06, 0.05), C(0.02), HD(0.1, 0.0, 0.08), Rt(-0.04, 0.02, 0.6, 0.3), WR(0.2), Lt(0.2, -0.5, 0.25, 0.2)])],
		[0.76, M([H(0, -0.08, 0), B(0.1, 0.0), C(0.06), HD(0.05, 0.0, 0.12), Lt(-0.06, -0.36, 0.42, 0.25), Rt(-0.04, -0.34, 0.42, 0.25), WL(0.7, 0.3), WR(0.7, -0.3), {"curl": 0.55, "curl_l": 0.55, "face": "focus"}])],
		[0.92, M([HD(0.08, 0.04, 0.14), Lt(-0.05, -0.34, 0.44, 0.25), Rt(-0.03, -0.33, 0.45, 0.25)])],
		[1.02, M([H(0, -0.1, 0), B(0.12, -0.05), HD(0.0, 0.0, 0.05), Rt(0.2, -0.62, 0.22, 0.3), WR(0.4), {"curl": 1.0, "face": "grin"}]), "s"],
		[1.15, M([H(0, -0.07, 0), B(0.08), Rt(0.22, -0.72, 0.15, 0.25), Lt(0.22, -0.72, 0.15, 0.2), {"curl": 0.6}])],
	])
	return t + 0.46


# Lysia : les yeux s'allument, pas en avant, paumes ramenées à la taille, puis poussée des deux
# mains dans la poitrine d'Alice (« DÉGAGE ! »), tenue raide qui vibre, retour mécanique.
# Rend l'instant de l'impact.
static func push(p: Performer, t: float, theta: float) -> float:
	var s: Vector3 = p.end_p
	var to: Vector3 = s + ahead(theta) * 0.35
	p.hold(t + 0.2)
	p.go(t + 0.42, to, Vector3.ZERO)
	p.hold(t + 1.2)
	p.turn(t, p.theta(t), "s")
	p.turn(t + 0.2, theta, "s")
	var st: Dictionary = style(p.person)
	var front_to: Vector3 = w(to, theta, -0.14, 0.34)
	var back_to: Vector3 = w(to, theta, 0.15, -0.36)
	p.plant(-1, p.foot_free[-1], t + 0.2, p.foot_at[-1])
	_swing(p, -1, t + 0.2, p.foot_at[-1], t + 0.38, front_to, 1.2, -0.3, 6, st, p.seed)
	p.plant(-1, t + 0.38, t + 1.2, front_to)
	p.plant(1, p.foot_free[1], t + 0.34, p.foot_at[1])
	_swing(p, 1, t + 0.34, p.foot_at[1], t + 0.5, back_to, 0.6, -0.4, 7, st, p.seed)
	p.plant(1, t + 0.5, t + 1.2, back_to, 0.0, -0.5)
	keys(p, t, [
		[0.0, {"face": "focus"}],
		[0.18, M([H(0, -0.12, 0.04), B(-0.06, 0.0), C(-0.08), HD(0.02, 0.0, 0.0), Lt(0.32, -0.52, -0.06, 0.4), Rt(0.32, -0.52, -0.06, 0.4), WL(-0.6), WR(-0.6), {"curl": 0.0, "curl_l": 0.0, "face": "determined"}]), "s"],
		[0.38, M([H(0, -0.16, 0.2), B(0.3, 0.0), C(0.12), HD(-0.12, 0.0), Lt(0.12, -0.14, 0.96, 0.15), Rt(0.12, -0.14, 0.96, 0.15), WL(-1.2), WR(-1.2), {"ev": "grunt", "shake": 0.6, "face": "angry"}]), "s"],
		[0.6, M([H(0, -0.15, 0.18), B(0.28), HD(-0.1, 0.0, 0.03), Lt(0.13, -0.12, 0.94, 0.15), Rt(0.13, -0.12, 0.94, 0.15), {"shake": 0.4}])],
		[0.82, M([H(0, -0.06, 0.05), B(0.06), C(0.0), HD(0.0, 0.0, 0.0), Lt(0.22, -0.7, 0.3, 0.1), Rt(0.22, -0.7, 0.3, 0.1), WL(0.0), WR(0.0), {"curl": 0.15, "curl_l": 0.15, "shake": 0.0, "face": "focus"}]), "s"],
		[0.98, M([HD(0.0, 0.0, 0.22)]), "s"],
		[1.12, M([HD(0.02, 0.1, 0.18), Lt(0.18, -0.9, 0.06, 0.05), Rt(0.18, -0.9, 0.06, 0.05)]), "s"],
	])
	return t + 0.4


# Usayuko : garde haute, il encaisse la griffe (CLANG, il recule d'un rien), grand sourire,
# armé du poing droit, crochet avec rotation du bassin, puis il secoue la main en rigolant.
# Rend [instant du blocage, instant du crochet].
static func counter(p: Performer, t: float, theta: float) -> Array:
	var s: Vector3 = p.end_p
	var guard: Vector3 = s + ahead(theta) * 0.9
	var st: Dictionary = style(p.person)
	p.hold(t)
	p.go(t + 0.3, guard, Vector3.ZERO)
	p.go(t + 0.42, guard - ahead(theta) * 0.12, Vector3.ZERO)
	p.hold(t + 0.58)
	p.go(t + 0.7, guard + ahead(theta) * 0.18, Vector3.ZERO)
	p.hold(t + 1.4)
	p.turn(t, p.theta(t), "s")
	p.turn(t + 0.25, theta, "s")
	var run_info: Dictionary = run(p, t, t + 0.33, {"stop": true, "first": -1, "no_upper": true, "seed": 31})
	var g: Vector3 = guard - ahead(theta) * 0.12
	var left_at: Vector3 = w(g, theta, -0.18, 0.2)
	var right_at: Vector3 = w(g, theta, 0.18, -0.22)
	p.plant(-1, p.foot_free[-1], t + 0.58, p.foot_at[-1])
	p.plant(1, p.foot_free[1], t + 0.58, p.foot_at[1])
	var hook_front: Vector3 = w(guard + ahead(theta) * 0.18, theta, -0.18, 0.3)
	_swing(p, -1, t + 0.58, p.foot_at[-1], t + 0.68, hook_front, 1.0, -0.3, 8, st, p.seed)
	p.plant(-1, t + 0.68, t + 1.4, hook_front)
	p.plant(1, t + 0.58, t + 1.4, p.foot_at[1], 0.0, -0.6, "", 0.2)
	keys(p, t, [
		[0.0, {"face": "determined"}],
		[0.2, M([H(0, -0.14, 0), B(0.16, 0.0), C(0.08), HD(-0.04), Lt(0.02, 0.0, 0.42, 0.7), Rt(0.06, 0.08, 0.4, 0.7), WL(0.4, 0.4), WR(0.4, -0.4), {"curl": 1.0, "curl_l": 1.0}])],
		[0.34, M([H(0, -0.18, -0.06), B(-0.04, 0.05), C(-0.08), HD(-0.1, 0.0, -0.05), Lt(0.0, 0.06, 0.36, 0.8), Rt(0.04, 0.14, 0.34, 0.8), {"shake": 0.7, "ev": "grunt"}]), "s"],
		[0.5, M([H(0.02, -0.15, -0.04), B(0.06, -0.3, -0.05), C(0.0, -0.2), HD(0.05, 0.3, 0.0), Lt(0.04, -0.02, 0.44, 0.6), Rt(0.32, -0.44, -0.24, 0.5), WR(0.2), {"shake": 0.0, "face": "grin"}]), "s"],
		[0.64, M([H(-0.03, -0.16, 0.08), B(0.26, 0.55, 0.06), C(0.12, 0.35), HD(0.0, -0.45, 0.05), Rt(-0.06, 0.04, 0.96, 0.2), WR(0.1), Lt(0.28, -0.35, 0.1, 0.4), {"fx": "trail_r whoosh", "ev": "grunt", "face": "angry"}])],
		[0.76, M([H(-0.03, -0.17, 0.1), B(0.3, 0.7, 0.08), C(0.15, 0.45), HD(0.0, -0.55), Rt(-0.32, 0.02, 0.82, 0.2), Lt(0.3, -0.45, -0.05, 0.4)])],
		[0.98, M([H(0, -0.08, 0.02), B(0.06, 0.2), C(0.02, 0.1), HD(0.1, -0.1, 0.1), Rt(0.3, -0.5, 0.3, 0.5), WR(0.8, 0.6), Lt(0.26, -0.75, 0.1, 0.2), {"curl": 0.2, "face": "laugh"}])],
		[1.1, M([Rt(0.32, -0.55, 0.28, 0.5), WR(-0.6, -0.6)])],
		[1.22, M([HD(0.12, 0.0, -0.08), Rt(0.3, -0.52, 0.3, 0.5), WR(0.7, 0.5), {"face": "grin"}])],
		[1.38, M([H(0, -0.06, 0), B(0.04), C(-0.02), HD(0.05), Rt(0.26, -0.85, 0.05, 0.2), Lt(0.26, -0.85, 0.05, 0.2), WR(0.0), {"curl": 0.8}])],
	])
	return [t + 0.34, t + 0.66]


# Elly : regard vers les autres, un genou au sol, paume à plat sur le carrelage : la zone de soin
# s'étend. Elle relève la tête vers eux, puis se redresse. Rend l'instant où la main touche le sol.
static func heal(p: Performer, t: float, theta: float) -> float:
	var s: Vector3 = p.end_p
	p.hold(t + 1.1)
	p.turn(t, p.theta(t), "s")
	p.turn(t + 0.25, theta, "s")
	var st: Dictionary = style(p.person)
	var front: Vector3 = w(s, theta, -0.14, 0.3)
	p.plant(-1, p.foot_free[-1], t + 0.2, p.foot_at[-1])
	_swing(p, -1, t + 0.2, p.foot_at[-1], t + 0.36, front, 0.7, -0.2, 9, st, p.seed)
	p.plant(-1, t + 0.36, t + 1.1, front)
	# genou droit au sol : pied derrière, sur les orteils
	var ankle: float = float(p.base[1].y)
	p.plant(1, p.foot_free[1], t + 0.26, p.foot_at[1])
	p.foot_l(t + 0.4, 1, Vector3(0.12, ankle + 0.06, 0.38), -1.25)
	p.foot_l(t + 0.8, 1, Vector3(0.12, ankle + 0.06, 0.38), -1.25)
	var back: Vector3 = w(s, theta, 0.14, -0.12)
	p.foot_l(t + 0.92, 1, Vector3(0.13, ankle + 0.04, 0.2), -0.6)
	p.plant(1, t + 1.0, t + 1.1, back)
	keys(p, t, [
		[0.0, {"face": "calm"}],
		[0.1, M([HD(0.0, 0.6, 0.0), B(0.04, 0.2), Lt(0.3, -0.55, 0.3, 0.2)])],
		[0.24, M([HD(-0.05, 0.3, 0.06), {"face": "determined"}])],
		[0.42, M([H(0, -0.48, -0.08), B(0.32, 0.0), C(0.15), HD(0.25, 0.0, 0.0), Rg(0.22, 0.42, 0.0), WR(0.0), {"el_r": 0.5}, L(0.45, -0.62, 0.2, 0.3), WL(0.3), {"curl": 0.0, "curl_l": 0.3}])],
		[0.6, M([H(0, -0.5, -0.08), B(0.3, 0.0), HD(0.35, 0.25, 0.08), Rg(0.22, 0.42, 0.0), {"face": "calm"}])],
		[0.8, M([HD(0.3, -0.25, -0.05)])],
		[1.02, M([H(0, -0.06, 0), B(0.06), C(0.04), HD(0.0, 0.0, 0.04), L(0.2, -0.9, 0.06, 0.1), R(0.2, -0.88, 0.08, 0.1), {"curl": 0.3, "face": "determined"}])],
	])
	return t + 0.44


# Bleuette : elle se tasse, poings serrés contre la poitrine, puis jaillit bras en l'air sur
# la pointe des pieds pour crier « ALLEZ ! » aux autres ; elle retombe, toute tremblante.
static func cheer_on(p: Performer, t: float, theta: float) -> float:
	var s: Vector3 = p.end_p
	p.hold(t + 0.95)
	p.turn(t, p.theta(t), "s")
	p.turn(t + 0.2, theta, "s")
	var left: Vector3 = p.foot_at[-1]
	var right: Vector3 = p.foot_at[1]
	p.plant(-1, p.foot_free[-1], t + 0.95, left, 0.0, 0.0)
	p.plant(1, p.foot_free[1], t + 0.95, right, 0.0, 0.0)
	keys(p, t, [
		[0.0, {"face": "fear"}],
		[0.14, M([H(0, -0.2, 0), B(0.2), C(0.18), HD(-0.2, 0.0, 0.0), Lt(-0.04, -0.2, 0.36, 0.3), Rt(-0.02, -0.18, 0.36, 0.3), WL(0.7), WR(0.7), {"curl": 1.0, "curl_l": 1.0, "shake": 0.4, "face": "determined"}]), "s"],
		[0.3, M([H(0, 0.04, 0.0), B(-0.12), C(-0.14), HD(0.32, 0.0, 0.0), Lt(0.3, 0.95, 0.12, 0.2), Rt(0.3, 0.95, 0.12, 0.2), WL(0.0), WR(0.0), {"shake": 0.0, "jaw": 0.9, "ev": "roar", "face": "grin"}])],
		[0.5, M([H(0, 0.02, 0.0), B(-0.08), HD(0.25, 0.08, 0.06), Lt(0.34, 0.9, 0.08, 0.2), Rt(0.28, 0.98, 0.14, 0.2), {"jaw": 0.7}])],
		[0.68, M([H(0, -0.12, 0), B(0.1), C(0.08), HD(0.0, 0.0, 0.1), Lt(0.05, -0.15, 0.4, 0.3), Rt(0.08, -0.2, 0.38, 0.3), WL(0.5), WR(0.5), {"jaw": 0.0, "shake": 0.3, "face": "determined"}])],
		[0.9, M([H(0, -0.1, 0), B(0.12), HD(-0.04, 0.0, 0.08), {"shake": 0.4}])],
	])
	return t + 0.32


# ============================================================ la haie --
# Les piques occupent z ∈ [-0.3, 0.3] (plan de la porte) jusqu'à ~0,9 m de haut.

# Saut par-dessus la haie, au cap 0 (vers la sortie), depuis la position actuelle.
# kind : "tuck" (genoux à la poitrine), "flail" (Simon : moulinets, réception ratée),
#        "hurdle" (Elly : jambe d'attaque tendue, jambe d'appel repliée sur le côté),
#        "ollie" (Ashura : accroupi, saut groupé, main qui attrape la chaussure, réception en roulant),
#        "brave" (Bleuette seule : yeux fermés, bras en avant), "vault" (Usayuko : saut haut et large).
# Rend {land, out (instant où il peut repartir), spot (position à la réception)}.
static func hedge_jump(p: Performer, t: float, kind: String, opts: Dictionary = {}) -> Dictionary:
	var s: Vector3 = p.end_p
	var lane: float = s.x
	var leg: float = p.leg
	var st: Dictionary = style(p.person)
	var take_z: float = -0.72 if kind != "hurdle" else -0.82
	var land_z: float = float(opts.get("land_z", 1.05 if kind != "hurdle" else 1.15))
	var apex: float = float(opts.get("apex", 0.52))
	var flight: float = float(opts.get("flight", 0.48))
	var runup: float = maxf(0.0, take_z - s.z)
	var t_take: float = t + clampf(runup / 3.4, 0.2, 0.5)
	var take: Vector3 = Vector3(lane, 0.0, take_z)
	var land: Vector3 = Vector3(lane + float(opts.get("drift", 0.0)), 0.0, land_z)
	var t_land: float = t_take + flight
	p.hold(t)
	p.turn(t, p.theta(t), "s")
	p.turn(t + 0.14, 0.0, "s")
	p.go(t_take, take, Vector3(0, 0, 3.4))
	p.leap(t_land, land, apex, Vector3(0, 0, 2.6))
	var absorb: float = 0.3 if kind != "flail" else 0.24
	var settle: Vector3 = land + Vector3(0, 0, absorb)
	p.go(t_land + 0.3, settle, Vector3.ZERO)
	# appuis d'élan : pied droit, puis pied gauche d'appel
	var ankle_l: float = float(p.base[-1].y)
	var ankle_r: float = float(p.base[1].y)
	var r1: Vector3 = Vector3(lane - 0.08, 0.0, lerpf(s.z, take_z, 0.45))
	var l1: Vector3 = Vector3(lane + 0.06, 0.0, take_z - 0.04)
	var t_r1: float = lerpf(t, t_take, 0.4)
	p.plant(1, p.foot_free[1], t + 0.04, p.foot_at[1], 0.0, -0.4)
	_swing(p, 1, t + 0.04, p.foot_at[1], t_r1, r1, 2.5, -0.4, 10, st, p.seed)
	p.plant(1, t_r1, t_r1 + 0.1, r1, 0.05, -0.8)
	p.plant(-1, p.foot_free[-1], t_r1 - 0.02, p.foot_at[-1], 0.0, -0.5)
	_swing(p, -1, t_r1 - 0.02, p.foot_at[-1], t_take - 0.12, l1, 2.8, -0.5, 11, st, p.seed)
	p.plant(-1, t_take - 0.12, t_take + 0.01, l1, 0.1, -0.9)
	# vol : jambes selon le style (repère de l'acteur, chevilles)
	var tuck: Array = _tuck(p, kind)
	var u_keys: Array[float] = [0.18, 0.45, 0.72]
	for k: int in range(3):
		var tt: float = t_take + flight * u_keys[k]
		p.foot_l(tt, -1, (tuck[k] as Array)[0], float((tuck[k] as Array)[2]))
		p.foot_l(tt, 1, (tuck[k] as Array)[1], float((tuck[k] as Array)[3]))
	p.foot_l(t_take + 0.05, 1, Vector3(0.1, ankle_r + 0.3 * leg, -0.25 * leg), -0.2)
	# réception
	var stance_l: Vector3 = Vector3(lane + 0.12, 0.0, land_z + 0.1)
	var stance_r: Vector3 = Vector3(lane - 0.12, 0.0, land_z + 0.24)
	var out: float = t_land + 0.45
	match kind:
		"hurdle":
			# réception sur la jambe d'attaque (gauche), la droite repasse devant : elle repart en courant
			p.plant(-1, t_land, t_land + 0.16, Vector3(lane + 0.06, 0.0, land_z), 0.1, -0.7)
			var r_next: Vector3 = Vector3(lane - 0.08, 0.0, land_z + 0.55)
			p.foot_l(t_land + 0.06, 1, Vector3(0.16, ankle_r + 0.28 * leg, -0.05 * leg), -0.4)
			p.plant(1, t_land + 0.2, t_land + 0.6, r_next, 0.1, 0.0)
			_swing(p, -1, t_land + 0.16, Vector3(lane + 0.06, 0.0, land_z), t_land + 0.36, Vector3(lane + 0.1, 0.0, land_z + 0.62), 1.5, -0.5, 12, st, p.seed)
			p.plant(-1, t_land + 0.36, t_land + 0.6, Vector3(lane + 0.1, 0.0, land_z + 0.62))
			out = t_land + 0.3
		"flail":
			# un pied puis l'autre qui accroche : il part en avant et finit à quatre pattes
			p.plant(1, t_land, t_land + 0.5, Vector3(lane - 0.1, 0.0, land_z + 0.05), 0.0, -0.6)
			p.foot_l(t_land + 0.1, -1, Vector3(-0.13, ankle_l + 0.1, -0.3 * leg), 0.3)
			p.plant(-1, t_land + 0.18, t_land + 0.5, Vector3(lane + 0.12, 0.0, land_z + 0.32))
			out = t_land + 0.45
		_:
			p.plant(-1, t_land, out, stance_l, 0.15, 0.0)
			p.plant(1, t_land + 0.04, out, stance_r, 0.15, 0.0)
	# haut du corps
	var up_keys: Array = _jump_upper(p.person, kind)
	keys(p, t, [
		[0.0, {"face": str(opts.get("face", "determined"))}],
		[(t_take - t) * 0.5, M([H(0, -0.08, 0.02), B(0.22, 0.0), C(0.08), HD(0.12), L(0.22, -0.55, -0.25, 0.3), R(0.22, -0.4, 0.3, 0.3), {"curl": 0.6, "curl_l": 0.6}])],
		[t_take - t - 0.06, M([H(0, -0.16, 0.0), B(0.3, 0.0), C(0.1), HD(0.18), L(0.3, -0.62, -0.35, 0.3), R(0.3, -0.62, -0.35, 0.3), {"ev": "effort"}]), "s"],
	])
	for entry: Array in up_keys:
		var tt: float = t_take + flight * float(entry[0])
		p.pose(tt, entry[1], str(entry[2]) if entry.size() > 2 else "")
	# réception : flexion, bras en balancier, puis redressement
	match kind:
		"flail":
			keys(p, t_land, [
				[0.0, M([H(0, -0.2, 0.05), B(0.45, 0.1, 0.1), C(0.2), HD(0.3, 0.0, 0.1), L(0.5, 0.3, 0.4, 0.4), R(0.55, 0.1, 0.5, 0.4), {"face": "panic", "ev": "gasp"}])],
				[0.16, M([H(0, -0.36, 0.25), B(0.85, 0.05, 0.08), C(0.3), HD(0.6, 0.0, 0.05), Lg(0.25, 0.45, 0.0), Rg(0.25, 0.5, 0.0), {"el_l": 0.5, "el_r": 0.5, "fx": "dust", "ev": "hurt", "sq": 0.95}])],
				[0.3, M([H(0, -0.52, 0.3), B(1.0, 0.0, 0.05), C(0.25), HD(0.75, 0.1, 0.1), Lg(0.25, 0.42, 0.0), Rg(0.24, 0.46, 0.0), {"sq": 1.0, "face": "hurt"}]), "s"],
			])
		_:
			keys(p, t_land, [
				[0.0, M([H(0, -0.14, 0.0), B(0.25, 0.0), C(0.12), HD(0.2), L(0.42, -0.2, 0.45, 0.4), R(0.42, -0.2, 0.45, 0.4), {"fx": "dust", "sq": 0.97}])],
				[0.12, M([H(0, -0.32, -0.04), B(0.42, 0.0), C(0.18), HD(0.36), L(0.4, -0.4, 0.4, 0.4), R(0.4, -0.4, 0.4, 0.4), {"sq": 1.0}]), "s"],
				[0.36, M([H(0, -0.1, 0), B(0.12), C(0.06), HD(0.08), L(0.25, -0.8, 0.12, 0.2), R(0.25, -0.8, 0.12, 0.2)])],
			])
	return {"take": t_take, "land": t_land, "out": out, "spot": settle}


# Positions des chevilles en vol (repère de l'acteur) à 18 %, 45 % et 72 % du saut : [gauche, droite, pitch g, pitch d].
static func _tuck(p: Performer, kind: String) -> Array:
	var leg: float = p.leg
	var al: float = float(p.base[-1].y)
	var ar: float = float(p.base[1].y)
	var xl: float = float(p.base[-1].x)
	var xr: float = float(p.base[1].x)
	match kind:
		"hurdle":
			return [
				[Vector3(xl, al + 0.4 * leg, - 0.45 * leg), Vector3(xr + 0.12 * leg, ar + 0.2 * leg, 0.3 * leg), 0.3, -0.9],
				[Vector3(xl + 0.02, al + 0.5 * leg, - 0.58 * leg), Vector3(xr + 0.42 * leg, ar + 0.46 * leg, 0.1 * leg), 0.25, -0.6],
				[Vector3(xl, al + 0.18 * leg, - 0.4 * leg), Vector3(xr + 0.3 * leg, ar + 0.5 * leg, - 0.12 * leg), 0.1, -0.5],
			]
		"flail":
			return [
				[Vector3(xl - 0.05, al + 0.35 * leg, 0.05 * leg), Vector3(xr + 0.04, ar + 0.5 * leg, - 0.3 * leg), -0.6, -0.1],
				[Vector3(xl + 0.06, al + 0.55 * leg, - 0.2 * leg), Vector3(xr + 0.1, ar + 0.3 * leg, 0.15 * leg), -0.2, -0.9],
				[Vector3(xl, al + 0.2 * leg, - 0.32 * leg), Vector3(xr - 0.02, ar + 0.12 * leg, - 0.1 * leg), 0.2, 0.1],
			]
		"ollie":
			return [
				[Vector3(xl, al + 0.5 * leg, 0.0), Vector3(xr, ar + 0.52 * leg, 0.02 * leg), 0.0, 0.0],
				[Vector3(xl - 0.02, al + 0.62 * leg, - 0.06 * leg), Vector3(xr + 0.06, ar + 0.66 * leg, 0.08 * leg), 0.05, -0.2],
				[Vector3(xl, al + 0.3 * leg, - 0.12 * leg), Vector3(xr, ar + 0.3 * leg, - 0.08 * leg), 0.0, 0.0],
			]
		"vault":
			return [
				[Vector3(xl, al + 0.35 * leg, 0.1 * leg), Vector3(xr, ar + 0.5 * leg, - 0.28 * leg), -0.5, 0.0],
				[Vector3(xl - 0.04, al + 0.55 * leg, - 0.12 * leg), Vector3(xr + 0.04, ar + 0.52 * leg, - 0.22 * leg), -0.1, 0.1],
				[Vector3(xl, al + 0.2 * leg, - 0.3 * leg), Vector3(xr, ar + 0.15 * leg, - 0.25 * leg), 0.15, 0.15],
			]
	# tuck / brave : genoux remontés
	return [
		[Vector3(xl, al + 0.38 * leg, 0.06 * leg), Vector3(xr, ar + 0.46 * leg, - 0.12 * leg), -0.5, -0.2],
		[Vector3(xl - 0.02, al + 0.52 * leg, - 0.08 * leg), Vector3(xr + 0.02, ar + 0.55 * leg, - 0.1 * leg), -0.2, -0.1],
		[Vector3(xl, al + 0.22 * leg, - 0.25 * leg), Vector3(xr, ar + 0.2 * leg, - 0.2 * leg), 0.15, 0.15],
	]


# Haut du corps en vol, propre à chacun : [fraction du vol, pose].
static func _jump_upper(person: String, kind: String) -> Array:
	match kind:
		"flail":
			return [
				[0.0, M([B(0.1), C(-0.1), HD(0.3), L(0.55, 0.6, 0.2, 0.4), R(0.5, 0.1, 0.55, 0.4), {"face": "panic", "jaw": 0.8, "curl": 0.0, "curl_l": 0.0}])],
				[0.3, M([B(0.0, 0.1), C(-0.12, 0.15), HD(0.35, 0.1), L(0.6, -0.2, 0.55, 0.4), R(0.55, 0.75, 0.1, 0.4)])],
				[0.6, M([B(0.12, -0.1), C(-0.05, -0.12), HD(0.25, -0.15), L(0.5, 0.75, -0.1, 0.4), R(0.6, -0.1, 0.5, 0.4)])],
				[0.9, M([B(0.3), HD(0.2), L(0.55, 0.3, 0.45, 0.4), R(0.5, 0.4, 0.4, 0.4)])],
			]
		"hurdle":
			return [
				[0.0, M([B(0.42, 0.1), C(0.15, 0.1), HD(0.2, -0.1), Lt(0.05, -0.55, -0.35, 0.3), Rt(0.1, -0.1, 0.7, 0.2), {"curl": 0.3, "curl_l": 0.3, "face": "determined"}])],
				[0.45, M([B(0.52, 0.15), C(0.2, 0.12), HD(0.3, -0.12), Lt(0.1, -0.6, -0.3, 0.3), Rt(0.08, -0.2, 0.75, 0.2)])],
				[0.85, M([B(0.25, 0.0), C(0.1), HD(0.15), Lt(0.2, -0.45, 0.2, 0.3), Rt(0.2, -0.5, 0.1, 0.3)])],
			]
		"ollie":
			return [
				[0.0, M([B(0.3, 0.1), C(0.1), HD(0.25), L(0.55, -0.2, 0.2, 0.4), R(0.4, -0.85, 0.35, 0.3), {"curl": 0.9, "face": "grin"}])],
				[0.45, M([B(0.42, 0.15, 0.05), C(0.15), HD(0.35, 0.1), L(0.6, -0.05, 0.15, 0.4), R(0.12, -1.0, 0.3, 0.2), {"curl": 1.0}])],
				[0.8, M([B(0.2), HD(0.2), L(0.5, -0.3, 0.3, 0.4), R(0.4, -0.55, 0.35, 0.3)])],
			]
		"brave":
			return [
				[0.0, M([B(0.25), C(0.1), HD(0.1), Lt(0.1, -0.05, 0.75, 0.2), Rt(0.1, -0.05, 0.75, 0.2), {"face": "asleep", "curl": 0.2, "curl_l": 0.2, "jaw": 0.5}])],
				[0.5, M([B(0.3), HD(0.15, 0.0, 0.1), Lt(0.15, 0.1, 0.7, 0.2), Rt(0.15, 0.1, 0.7, 0.2)])],
				[0.9, M([B(0.2), HD(0.2), Lt(0.3, -0.2, 0.55, 0.3), Rt(0.3, -0.2, 0.55, 0.3), {"face": "panic"}])],
			]
		"vault":
			return [
				[0.0, M([B(0.3), C(0.05), HD(0.3), L(0.4, 0.6, 0.3, 0.3), R(0.4, 0.6, 0.3, 0.3), {"face": "grin", "curl": 1.0, "curl_l": 1.0}])],
				[0.45, M([B(0.25, -0.1), C(-0.05), HD(0.25, 0.15), L(0.5, 0.35, 0.3, 0.3), R(0.5, 0.45, 0.25, 0.3), {"face": "laugh"}])],
				[0.85, M([B(0.25), HD(0.2), L(0.45, -0.2, 0.4, 0.4), R(0.45, -0.2, 0.4, 0.4)])],
			]
	return [
		[0.0, M([B(0.3), C(0.1), HD(0.25), L(0.4, 0.2, 0.45, 0.3), R(0.4, 0.2, 0.45, 0.3), {"face": "fear"}])],
		[0.45, M([B(0.35), C(0.12), HD(0.3), L(0.45, -0.1, 0.4, 0.3), R(0.45, -0.1, 0.4, 0.3)])],
		[0.85, M([B(0.25), HD(0.25), L(0.45, -0.3, 0.45, 0.3), R(0.45, -0.3, 0.45, 0.3)])],
	]


# Courte échelle : l'aide (b) se met de profil contre la haie, accroupi, mains croisées en étrier ;
# la grimpeuse (c) arrive, pose le pied droit dans ses mains, il se relève d'un coup en poussant
# et elle passe par-dessus les piques ; il la suit des yeux, bras encore en l'air.
# Rend {"foot": [t0, t1] (contact mains de b ↔ pied droit de c), "land", "out", "spot", "free" (b libre)}.
static func legup(c: Performer, b: Performer, t: float, lane: float, side: float) -> Dictionary:
	var st_c: Dictionary = style(c.person)
	var st_b: Dictionary = style(b.person)
	var leg_c: float = c.leg
	# l'aide arrive à sa place (de profil, face au couloir de la grimpeuse)
	var b_spot: Vector3 = Vector3(lane + side * 0.62, 0.0, -0.66)
	var b_theta: float = heading_of(Vector3( - side, 0.0, 0.0))
	step_to(b, minf(maxf(t - 0.62, b.end_t), t - 0.4), t - 0.12, b_spot, b_theta, {"seed": 41})
	var t_step: float = t + 0.3
	var t_lift: float = t + 0.36
	var t_top: float = t + 0.62
	var t_land: float = t + 1.02
	# accroupi, étrier, poussée vers le haut
	b.hold(t + 1.3)
	b.plant(-1, b.foot_free[-1], t + 1.3, b.foot_at[-1])
	b.plant(1, b.foot_free[1], t + 1.3, b.foot_at[1])
	keys(b, t - 0.12, [
		[0.0, M([H(0, -0.3, -0.04), B(0.35), C(0.12), HD(0.15, 0.5), L(0.06, -0.9, 0.42, 0.35), R(0.06, -0.9, 0.42, 0.35), WL(0.3, 0.6), WR(0.3, -0.6), {"curl": 0.7, "curl_l": 0.7, "face": "determined"}])],
		[0.3, M([H(0, -0.42, -0.06), B(0.42), C(0.16), HD(0.2, 0.6), L(0.04, -1.02, 0.42, 0.35), R(0.04, -1.02, 0.42, 0.35)]), "s"],
		[0.48, M([H(0, -0.44, -0.06), B(0.44), HD(0.12, 0.65), {"ev": "effort"}]), "s"],
		[0.62, M([H(0, -0.12, -0.02), B(0.1), C(-0.08), HD(0.3, 0.55), L(0.06, -0.35, 0.36, 0.4), R(0.06, -0.35, 0.36, 0.4), {"ev": "grunt", "sq": 1.04}])],
		[0.78, M([H(0, 0.0, 0.0), B(-0.12), C(-0.16), HD(0.5, 0.3), L(0.12, 0.45, 0.32, 0.3), R(0.12, 0.45, 0.32, 0.3), {"sq": 1.0}])],
		[1.05, M([H(0, -0.04, 0.0), B(-0.04), C(-0.06), HD(0.35, -0.2), L(0.2, 0.1, 0.25, 0.3), R(0.2, 0.15, 0.25, 0.3), {"face": "grin"}])],
		[1.3, M([neutral(b.person), HD(0.1, -0.4)])],
	])
	# la grimpeuse : deux pas, le pied droit dans l'étrier, montée, saut groupé, réception
	var s: Vector3 = c.end_p
	var plant_l: Vector3 = Vector3(lane + 0.1, 0.0, -1.02)
	var cup: Vector3 = Vector3(lane - 0.03, 0.0, -0.64)
	var cup_h: float = 0.34
	var top: Vector3 = Vector3(lane, 0.62, -0.48)
	var land: Vector3 = Vector3(lane, 0.0, 1.1)
	c.hold(t)
	c.turn(t, c.theta(t), "s")
	c.turn(t + 0.12, 0.0, "s")
	c.go(t_step, Vector3(lane, 0.0, -0.98), Vector3(0, 0, 1.4))
	c.go(t_lift, Vector3(lane, 0.06, -0.86), Vector3(0, 0.6, 0.8))
	c.go(t_top, top, Vector3(0, 0.9, 0.7))
	c.leap(t_land, land, 0.26, Vector3(0, 0, 1.5))
	c.go(t_land + 0.32, land + Vector3(0, 0, 0.25), Vector3.ZERO)
	c.plant(1, c.foot_free[1], t + 0.05, c.foot_at[1])
	_swing(c, 1, t + 0.05, c.foot_at[1], t + 0.18, Vector3(lane - 0.06, 0.0, -1.2), 1.5, -0.3, 13, st_c, c.seed)
	c.plant(1, t + 0.18, t + 0.24, Vector3(lane - 0.06, 0.0, -1.2), 0.0, -0.6)
	c.plant(-1, c.foot_free[-1], t + 0.12, c.foot_at[-1])
	_swing(c, -1, t + 0.12, c.foot_at[-1], t + 0.28, plant_l, 1.5, -0.3, 14, st_c, c.seed)
	c.plant(-1, t + 0.28, t_lift + 0.06, plant_l, 0.05, -0.9)
	# pied droit : monte dans l'étrier, puis suit les mains qui poussent
	var ankle_r: float = float(c.base[1].y)
	c.foot_l(t + 0.3, 1, Vector3(0.1, ankle_r + 0.28 * leg_c, - 0.3 * leg_c), 0.2)
	c.foot_w(t_step + 0.06, 1, Vector3(cup.x, cup_h + ankle_r * 0.5, cup.z), 0.0, "l")
	c.foot_w(t_lift + 0.08, 1, Vector3(cup.x, cup_h + 0.08 + ankle_r * 0.5, cup.z + 0.02), 0.0, "l")
	c.foot_w(t_top - 0.04, 1, Vector3(cup.x, 0.92 + ankle_r * 0.5, cup.z + 0.06), -0.3)
	var tuck: Array = _tuck(c, "tuck")
	c.foot_l(t_top + 0.04, -1, Vector3(float(c.base[-1].x), float(c.base[-1].y) + 0.45 * leg_c, - 0.05 * leg_c), -0.3)
	c.foot_l(t_top + 0.12, 1, Vector3(float(c.base[1].x), ankle_r + 0.25 * leg_c, 0.05 * leg_c), -0.6)
	for k: int in range(3):
		var tt: float = t_top + (t_land - t_top) * [0.3, 0.55, 0.8][k]
		c.foot_l(tt, -1, (tuck[k] as Array)[0], float((tuck[k] as Array)[2]))
		c.foot_l(tt, 1, (tuck[k] as Array)[1], float((tuck[k] as Array)[3]))
	c.plant(-1, t_land, t_land + 0.5, Vector3(lane + 0.12, 0.0, land.z + 0.1), 0.15, 0.0)
	c.plant(1, t_land + 0.05, t_land + 0.5, Vector3(lane - 0.1, 0.0, land.z + 0.26), 0.15, 0.0)
	keys(c, t, [
		[0.0, {"face": "fear"}],
		[0.15, M([H(0, -0.06, 0), B(0.18), C(0.08), HD(0.15), L(0.3, -0.5, 0.35, 0.3), R(0.3, -0.5, 0.35, 0.3), {"curl": 0.5, "curl_l": 0.5}])],
		[0.32, M([H(0, -0.2, 0.05), B(0.35), C(0.15), HD(0.25, 0.2), Lt(0.3, -0.3, 0.35, 0.3), Rt(0.45, -0.25, 0.3, 0.3), {"face": "determined", "ev": "effort"}]), "s"],
		[0.5, M([H(0, -0.05, 0.05), B(0.12), C(0.0), HD(0.35), L(0.35, 0.55, 0.3, 0.3), R(0.35, 0.6, 0.3, 0.3), {"curl": 0.2, "curl_l": 0.2, "face": "surprise"}])],
		[0.66, M([B(0.3), C(0.12), HD(0.35, 0.0, 0.1), L(0.45, 0.4, 0.4, 0.3), R(0.45, 0.35, 0.45, 0.3), {"face": "fear", "jaw": 0.6}])],
		[0.85, M([B(0.35), HD(0.3), L(0.45, -0.1, 0.45, 0.3), R(0.45, -0.1, 0.45, 0.3), {"jaw": 0.3}])],
		[1.02, M([H(0, -0.22, 0.0), B(0.4), C(0.18), HD(0.35), L(0.42, -0.25, 0.45, 0.4), R(0.42, -0.25, 0.45, 0.4), {"fx": "dust", "sq": 0.96}])],
		[1.16, M([H(0, -0.34, -0.04), B(0.45), C(0.2), HD(0.4, 0.0, 0.08), L(0.4, -0.45, 0.4, 0.4), R(0.4, -0.45, 0.4, 0.4), {"sq": 1.0, "face": "surprise"}]), "s"],
		[1.42, M([H(0, -0.1, 0), B(0.14), C(0.08), HD(0.1), L(0.25, -0.75, 0.15, 0.2), R(0.25, -0.75, 0.15, 0.2), {"face": "grin"}])],
	])
	return {"foot": [t_step + 0.02, t_top + 0.02], "top": t_top, "land": t_land, "out": t_land + 0.5, "spot": land + Vector3(0, 0, 0.25), "free": t + 1.3, "b_spot": b_spot, "b_theta": b_theta}


# Lysia traverse les piques sans ralentir : pas lourds, les piques cassent contre son armure.
static func wade(p: Performer, t: float) -> Dictionary:
	var s: Vector3 = p.end_p
	var lane: float = s.x
	var to: Vector3 = Vector3(lane, 0.0, 1.45)
	p.hold(t)
	p.turn(t, p.theta(t), "s")
	p.turn(t + 0.25, 0.0, "s")
	var dist: float = to.z - s.z
	p.go(t + 0.25, s + Vector3(0, 0, 0.18), Vector3(0, 0, 1.3))
	p.go(t + 0.25 + (dist - 0.36) / 2.1, to - Vector3(0, 0, 0.18), Vector3(0, 0, 1.9))
	var t_end: float = t + 0.25 + (dist - 0.36) / 2.1 + 0.3
	p.go(t_end, to, Vector3.ZERO)
	run(p, t, t_end + 0.25, {"stop": true, "first": 1, "seed": 51, "no_upper": true, "cadence": 0.85})
	var n: int = int((t_end - t) / 0.32)
	p.face(t, "focus")
	for k: int in range(n + 1):
		var tt: float = t + 0.3 * float(k) + 0.05
		var sgn: float = 1.0 if k % 2 == 0 else -1.0
		p.pose(tt, M([H(0.02 * sgn, -0.05 - 0.03 * float(k % 2), 0.0), B(0.03, 0.05 * sgn, -0.03 * sgn), C(0.0, -0.04 * sgn), HD(0.0, 0.0, 0.04), L(0.3, -0.75, 0.15, 0.2), R(0.3, -0.75, 0.15, 0.2), WL(-0.3, 0.0, 0.2), WR(-0.3, 0.0, -0.2), {"curl": 0.1, "curl_l": 0.1, "shake": 0.2 if k > 0 and k < n else 0.0}]), "s" if k % 2 == 0 else "")
	p.pose(t_end + 0.1, neutral(p.person))
	return {"out": t_end + 0.25, "spot": to, "break_from": t + 0.3, "break_to": t_end - 0.15}


# ============================================================ de l'autre côté --

# Attendre les autres face à la porte : chacun à sa façon, et jamais deux fois le même geste.
static func wait_out(p: Performer, t0: float, t1: float, door_x: float) -> void :
	var span: float = t1 - t0
	if span < 0.2: return
	var seed_value: int = p.seed + 77
	var beats: Array = []
	match p.person:
		"Bleuette":
			# sautille d'angoisse, mains devant la bouche, puis appelle
			beats = [
				M([H(0, -0.08, 0), B(0.1), C(0.1), HD(0.05, 0.0, 0.08), Lt(-0.05, 0.22, 0.4, 0.2), Rt(-0.04, 0.24, 0.42, 0.2), WL(0.9), WR(0.9), {"curl": 0.4, "curl_l": 0.4, "face": "fear", "shake": 0.3}]),
				M([H(0, -0.14, 0), B(0.16), C(0.12), HD(0.0, 0.1, 0.1), Lt(-0.04, 0.2, 0.42, 0.2), Rt(-0.03, 0.22, 0.42, 0.2), {"shake": 0.45}]),
				M([H(0, -0.06, 0), B(0.0), C(-0.04), HD(0.18, 0.0, 0.0), L(0.4, 0.3, 0.35, 0.3), R(0.2, -0.6, 0.2, 0.2), WL(-0.4), {"curl_l": 0.0, "jaw": 0.8, "face": "determined", "ev": "roar"}]),
			]
		"Elly":
			# tend la main vers la porte, appelle doucement, mains sur les genoux pour souffler
			beats = [
				M([H(0, -0.06, 0), B(0.12), C(0.06), HD(0.05), L(0.3, -0.3, 0.6, 0.2), R(0.2, -0.85, 0.1, 0.1), {"curl_l": 0.1, "face": "determined"}]),
				M([H(0, -0.18, 0), B(0.45), C(0.15), HD(0.35), Lt(0.15, -0.95, 0.45, 0.3), Rt(0.15, -0.95, 0.45, 0.3), {"face": "tired", "jaw": 0.3}]),
				M([H(0, -0.05, 0), B(0.1), HD(0.08, 0.0, 0.08), L(0.32, -0.15, 0.65, 0.2), R(0.25, -0.8, 0.15, 0.1), WL(-0.5), {"curl_l": 0.0, "jaw": 0.4, "face": "fear"}]),
			]
		"Simon":
			# piétine, se tient la tête, fait de grands signes « viens, viens ! »
			beats = [
				M([H(0, -0.06, 0), B(0.08), C(0.04), HD(0.1), Lt(0.2, 0.55, 0.15, 0.4), Rt(0.2, 0.5, 0.18, 0.4), WL(0.6), WR(0.6), {"curl": 0.3, "curl_l": 0.3, "face": "panic"}]),
				M([H(0, -0.1, 0), B(0.05, 0.1), HD(0.15, -0.1), L(0.45, 0.4, 0.35, 0.3), R(0.3, -0.5, 0.3, 0.3), WL(0.9), {"curl_l": 0.0, "jaw": 0.7, "face": "fear"}]),
				M([H(0, -0.08, 0), B(0.05, -0.1), HD(0.12, 0.1), L(0.45, -0.1, 0.55, 0.3), R(0.3, -0.5, 0.3, 0.3), WL(-0.9), {"jaw": 0.4}]),
			]
		"Ashura":
			# posé : poids sur une jambe, deux doigts « allez » ; il garde un œil sur Alice
			beats = [
				M([H(0.04, -0.06, 0), B(0.03, 0.08, 0.05), C(0.0, 0.05), HD(0.05, -0.1), L(0.2, -0.85, 0.05, 0.1), R(0.35, -0.2, 0.45, 0.3), WR(-0.4), {"curl": 0.3, "face": "focus"}]),
				M([H(0.04, -0.06, 0), B(0.03, 0.06, 0.05), HD(0.08, 0.05), R(0.35, -0.05, 0.4, 0.3), WR(0.5), {"curl": 0.5}]),
				M([H(-0.02, -0.08, 0), B(0.06, -0.04), HD(0.04, 0.0, -0.05), L(0.2, -0.85, 0.08, 0.1), R(0.22, -0.82, 0.1, 0.1), {"curl": 0.45, "face": "determined"}]),
			]
		"Lysia":
			# immobile, bras tendu pour faire signe, la tête qui pivote par saccades
			beats = [
				M([H(0, 0.0, 0), B(0.0), C(0.0), HD(0.0, 0.25, 0.0), L(0.16, -0.95, 0.03, 0.05), R(0.16, -0.95, 0.03, 0.05), {"face": "focus"}]),
				M([HD(0.0, -0.15, 0.12), R(0.45, 0.15, 0.5, 0.1), WR(-0.5), {"curl": 0.0}]),
				M([HD(0.05, 0.0, 0.0), R(0.4, 0.1, 0.55, 0.1), WR(0.3)]),
			]
		"Usayuko":
			beats = [
				M([H(0, -0.06, 0), B(0.05), C(-0.05), HD(0.1), L(0.4, 0.5, 0.3, 0.3), R(0.26, -0.8, 0.1, 0.2), WL(0.6), {"curl_l": 0.2, "face": "grin", "jaw": 0.6}]),
				M([H(0, -0.05, 0), B(0.03), HD(0.06), L(0.3, -0.1, 0.5, 0.3), WL(-0.6), {"jaw": 0.2}]),
			]
		_:
			beats = [tense(p.person)]
	var n: int = maxi(2, int(span / 0.38))
	for k: int in range(n + 1):
		var u: float = float(k) / float(n)
		var tt: float = t0 + span * u + 0.04 * n1(seed_value, k)
		var pick: int = absi(int(floor(float(k) * 0.55 + n1(seed_value + 5, k) * 0.6))) % beats.size()
		var pose: Dictionary = (beats[pick] as Dictionary).duplicate()
		var head: Vector3 = pose.get("head", Vector3.ZERO)
		pose["head"] = head + Vector3(0.03 * n1(seed_value + 9, k), 0.12 * n1(seed_value + 11, k), 0.03 * n1(seed_value + 13, k))
		if k == 0: pose.erase("ev")
		p.pose(tt, pose)


# On tire un ami : l'aide (h) arrive devant celui qui est à terre (f), lui attrape la main et
# se penche en arrière pour le relever. Rend [début, fin] du contact des mains droites.
static func pull_up(h: Performer, f: Performer, t: float, fallen_at: Vector3) -> Array:
	var face_theta: float = PI
	var h_spot: Vector3 = fallen_at + Vector3(0.0, 0.0, 0.72)
	step_to(h, t, t + 0.36, h_spot, face_theta, {"seed": 61})
	var t_grab: float = t + 0.42
	h.hold(t + 1.25)
	f.hold(t + 1.25)
	h.plant(-1, h.foot_free[-1], t + 1.25, h.foot_at[-1])
	h.plant(1, h.foot_free[1], t + 1.25, h.foot_at[1])
	keys(h, t + 0.3, [
		[0.0, M([H(0, -0.1, 0), B(0.35), C(0.15), HD(0.3), R(0.3, -0.5, 0.6, 0.2), L(0.25, -0.8, 0.2, 0.2), {"curl": 0.0, "face": "determined"}])],
		[0.14, M([H(0, -0.25, -0.02), B(0.55), C(0.2), HD(0.4), R(0.18, -0.85, 0.72, 0.1), WR(-0.3), {"curl": 0.0}])],
		[0.24, M([{"curl": 0.9}])],
		[0.42, M([H(0, -0.2, -0.12), B(-0.05), C(-0.12), HD(0.15), R(0.15, -0.55, 0.65, 0.1), L(0.4, -0.5, -0.2, 0.3), {"ev": "effort", "curl": 1.0}])],
		[0.7, M([H(0, -0.05, -0.05), B(-0.08), C(-0.06), HD(0.05), R(0.18, -0.3, 0.42, 0.2), L(0.3, -0.75, 0.0, 0.2), {"face": "grin"}])],
		[0.95, M([neutral(h.person), {"curl": 0.4}])],
	])
	# celui qui est à terre lève la main, se fait tirer et se redresse
	var fl: Vector3 = f.foot_at[-1]
	var fr: Vector3 = f.foot_at[1]
	f.plant(-1, f.foot_free[-1], t + 1.25, fl)
	f.plant(1, f.foot_free[1], t + 0.82, fr, 0.0, -0.6)
	var stand_r: Vector3 = Vector3(fallen_at.x - 0.12, 0.0, fl.z + 0.05)
	_swing(f, 1, t + 0.82, fr, t + 1.0, stand_r, 0.8, -0.3, 15, style(f.person), f.seed)
	f.plant(1, t + 1.0, t + 1.25, stand_r)
	keys(f, t + 0.3, [
		[0.0, M([H(0, -0.5, 0.3), B(0.9), C(0.25), HD(0.7, 0.0, 0.1), Lg(0.25, 0.42, 0.0), R(0.3, -0.3, 0.6, 0.2), {"el_l": 0.5, "face": "hurt", "curl": 0.0}])],
		[0.16, M([HD(0.85, 0.0, 0.05), R(0.25, 0.1, 0.75, 0.15), {"face": "surprise"}])],
		[0.42, M([H(0, -0.32, 0.18), B(0.55), C(0.15), HD(0.5), R(0.2, 0.2, 0.8, 0.1), L(0.35, -0.6, 0.3, 0.3), {"curl": 1.0, "ev": "effort"}])],
		[0.68, M([H(0, -0.12, 0.05), B(0.2), C(0.08), HD(0.15), R(0.2, -0.2, 0.55, 0.2), L(0.3, -0.8, 0.15, 0.2), {"face": "grin"}])],
		[0.95, M([neutral(f.person), HD(0.1, 0.2), {"face": "laugh"}])],
	])
	return [t_grab + 0.06, t + 0.98]


# Petit saut sur place (joie) : les deux pieds quittent le sol puis se reposent.
static func hop(p: Performer, t: float, height: float, dur: float = 0.34) -> void :
	var s: Vector3 = p.end_p
	var leg: float = p.leg
	p.hold(t)
	p.leap(t + dur, s, height)
	var fl: Vector3 = p.foot_at[-1]
	var fr: Vector3 = p.foot_at[1]
	p.plant(-1, p.foot_free[-1], t, fl, 0.0, -0.6, "", 0.3)
	p.plant(1, p.foot_free[1], t, fr, 0.0, -0.6, "", 0.3)
	for side: int in [-1, 1]:
		var b: Vector3 = p.base[side]
		p.foot_l(t + dur * 0.5, side, Vector3(b.x, b.y + 0.12 * leg + height * 0.2, b.z + 0.04 * leg), -0.4)
	p.plant(-1, t + dur, t + dur + 0.05, fl, 0.1, 0.0)
	p.plant(1, t + dur + 0.02, t + dur + 0.05, fr, 0.1, 0.0)
	p.hold(t + dur + 0.05)


# Joie ou soulagement à la sortie, propre à chacun (≈ 3,5 s, aucun geste répété à l'identique).
static func celebrate(p: Performer, t0: float, t1: float, theta: float, opts: Dictionary = {}) -> void :
	var s: Vector3 = p.end_p
	p.hold(t0)
	if absf(wrapf(theta - p.theta(t0), -PI, PI)) > 0.3:
		pivot(p, t0, t0 + 0.45, s, p.theta(t0) + wrapf(theta - p.theta(t0), -PI, PI))
		t0 += 0.45
	var span: float = t1 - t0
	var feet_end: float = t1 + 0.5
	match p.person:
		"Simon":
			# plié en deux, il souffle ; il se redresse, poings qui battent « on l'a fait ! », saut, rire nerveux
			p.plant(-1, p.foot_free[-1], t0 + 1.55, p.foot_at[-1])
			p.plant(1, p.foot_free[1], t0 + 1.55, p.foot_at[1])
			keys(p, t0, [
				[0.0, M([H(0, -0.2, -0.05), B(0.62), C(0.2), HD(0.55), Lt(0.18, -0.95, 0.52, 0.3), Rt(0.18, -0.95, 0.52, 0.3), {"curl": 0.2, "curl_l": 0.2, "face": "tired", "jaw": 0.6}])],
				[0.35, M([H(0, -0.18, -0.05), B(0.58), HD(0.5, 0.1, 0.05), {"jaw": 0.4}])],
				[0.7, M([H(0, -0.2, -0.05), B(0.63), HD(0.58, -0.05), {"jaw": 0.65}])],
				[1.0, M([H(0, -0.05, 0), B(-0.05), C(-0.1), HD(0.25), Lt(0.3, 0.3, 0.3, 0.4), Rt(0.3, 0.32, 0.28, 0.4), {"curl": 1.0, "curl_l": 1.0, "face": "surprise", "jaw": 0.5}])],
				[1.18, M([Lt(0.32, -0.15, 0.35, 0.5), Rt(0.32, 0.4, 0.3, 0.4), {"face": "laugh", "jaw": 0.9}])],
				[1.34, M([Lt(0.32, 0.42, 0.28, 0.4), Rt(0.32, -0.12, 0.35, 0.5)])],
				[1.5, M([H(0, -0.18, 0), B(0.15), Lt(0.3, -0.2, 0.35, 0.5), Rt(0.3, -0.18, 0.36, 0.5), {"ev": "effort"}]), "s"],
			])
			hop(p, t0 + 1.55, 0.22, 0.4)
			p.plant(-1, p.foot_free[-1], feet_end, p.foot_at[-1])
			p.plant(1, p.foot_free[1], feet_end, p.foot_at[1])
			keys(p, t0 + 1.55, [
				[0.05, M([H(0, 0.02, 0), B(-0.1), C(-0.12), HD(0.35), L(0.35, 0.95, 0.1, 0.2), R(0.35, 0.92, 0.12, 0.2), {"curl": 1.0, "curl_l": 1.0, "jaw": 1.0, "ev": "roar"}])],
				[0.4, M([H(0, -0.16, 0), B(0.12), HD(0.2), L(0.4, 0.5, 0.2, 0.3), R(0.4, 0.55, 0.2, 0.3), {"sq": 0.97}])],
				[0.7, M([H(0, -0.04, 0), B(0.02, 0.1), C(0.0, 0.1), HD(0.1, 0.25, 0.1), Lt(-0.05, 0.45, -0.05, 0.6), WL(0.5), R(0.25, -0.75, 0.1, 0.2), {"curl_l": 0.3, "face": "laugh", "jaw": 0.5, "sq": 1.0}])],
				[1.2, M([HD(0.15, 0.15, 0.12), Lt(-0.06, 0.48, -0.02, 0.6), {"jaw": 0.7}])],
				[1.7, M([HD(0.1, -0.1, 0.05), Lt(-0.04, 0.44, -0.06, 0.6), {"face": "grin", "jaw": 0.2}])],
			])
		"Usayuko":
			# bras en l'air, poing qui tire vers le bas, demi-tour vers Alice : « bye-bye » du bout des doigts, rire
			p.plant(-1, p.foot_free[-1], feet_end, p.foot_at[-1])
			p.plant(1, p.foot_free[1], feet_end, p.foot_at[1])
			keys(p, t0, [
				[0.0, M([H(0, -0.12, 0), B(0.1), C(0.05), HD(0.0), L(0.3, -0.5, 0.3, 0.3), R(0.3, -0.5, 0.3, 0.3), {"curl": 1.0, "curl_l": 1.0, "face": "grin"}])],
				[0.22, M([H(0, 0.0, 0), B(-0.15), C(-0.18), HD(0.4, 0.0, 0.0), L(0.35, 0.95, 0.05, 0.2), R(0.35, 0.95, 0.08, 0.2), {"jaw": 1.0, "ev": "roar", "face": "laugh"}])],
				[0.62, M([H(0, -0.14, 0), B(0.22, -0.1), C(0.1), HD(0.05, 0.1), Rt(0.15, -0.6, 0.15, 0.6), L(0.3, -0.7, 0.2, 0.2), WR(0.4), {"jaw": 0.6, "ev": "grunt"}]), "s"],
				[0.95, M([H(0, -0.06, 0), B(0.02), HD(0.12, 0.0, 0.05), Rt(0.28, -0.5, 0.25, 0.4), {"jaw": 0.2, "face": "grin"}])],
				[1.3, M([HD(0.1, 0.05, -0.1), R(0.35, 0.28, 0.45, 0.2), WR(0.6, 0.0, 0.3), {"curl": 0.1, "face": "menace"}])],
				[1.48, M([R(0.36, 0.3, 0.44, 0.2), WR(0.1, 0.0, -0.3)])],
				[1.64, M([R(0.36, 0.28, 0.45, 0.2), WR(0.7, 0.0, 0.3)])],
				[1.8, M([R(0.36, 0.3, 0.44, 0.2), WR(0.1, 0.0, -0.3), {"face": "grin"}])],
				[2.2, M([H(0, -0.06, 0), B(-0.08), C(-0.1), HD(0.2, 0.0, 0.1), Lt(0.32, -0.55, -0.02, 0.6), Rt(0.32, -0.55, -0.02, 0.6), WL(0.3), WR(0.3), {"curl": 0.9, "curl_l": 0.9, "face": "laugh", "jaw": 0.8}])],
				[2.5, M([B(-0.04), HD(0.25, 0.05, 0.12), {"jaw": 0.5}])],
				[2.8, M([B(-0.09), HD(0.18, -0.05, 0.05), {"jaw": 0.9}])],
				[3.2, M([B(-0.05), HD(0.15, 0.0, 0.1), {"jaw": 0.3, "face": "grin"}])],
			])
		"Ashura":
			# il souffle, main dans les cheveux, bras croisés, petit signe de tête satisfait
			p.plant(-1, p.foot_free[-1], feet_end, p.foot_at[-1])
			p.plant(1, p.foot_free[1], feet_end, p.foot_at[1], 0.0, 0.0)
			keys(p, t0, [
				[0.0, M([H(0, -0.1, 0), B(0.2), C(0.08), HD(0.15), L(0.25, -0.8, 0.15, 0.2), R(0.25, -0.78, 0.15, 0.2), {"face": "tired", "jaw": 0.3}])],
				[0.45, M([H(0, -0.04, 0), B(-0.04), C(-0.08), HD(0.25, 0.0, -0.05), Rt(0.12, 0.62, 0.05, 0.6), WR(0.6, 0.0, 0.3), {"curl": 0.3, "face": "calm", "jaw": 0.0}])],
				[0.8, M([HD(0.1, -0.1, -0.1), Rt(0.08, 0.55, -0.1, 0.6), WR(0.9, 0.0, 0.2)])],
				[1.2, M([H(0.03, -0.05, 0), B(0.0, 0.05, 0.04), C(0.0), HD(0.02, 0.2, 0.0), Lt(-0.25, -0.3, 0.35, 0.3), Rt(-0.25, -0.22, 0.33, 0.3), WL(0.1), WR(0.1), {"curl": 0.6, "curl_l": 0.6, "face": "focus"}])],
				[1.9, M([HD(0.06, 0.25, 0.06), {"face": "smile"}])],
				[2.2, M([HD(-0.08, 0.22, 0.06)])],
				[2.45, M([HD(0.06, 0.2, 0.04)])],
				[3.1, M([H(0.04, -0.06, 0), B(-0.02, 0.06, 0.05), HD(0.08, -0.15, 0.08), {"face": "grin"}])],
			])
		"Lysia":
			# raide, tête qui pivote par saccades, bras levé tout droit, petit bug, pouce levé
			p.plant(-1, p.foot_free[-1], feet_end, p.foot_at[-1])
			p.plant(1, p.foot_free[1], feet_end, p.foot_at[1])
			keys(p, t0, [
				[0.0, M([neutral("Lysia"), {"face": "focus"}])],
				[0.3, M([HD(0.0, 0.35, 0.0)]), "s"],
				[0.55, M([HD(0.0, -0.3, 0.0)]), "s"],
				[0.8, M([HD(0.05, 0.0, 0.18)]), "s"],
				[1.15, M([R(0.12, 1.0, 0.1, 0.05), WR(0.0), {"curl": 1.0, "face": "smile"}]), "s"],
				[1.75, M([R(0.13, 0.98, 0.12, 0.05), HD(0.08, 0.0, 0.2), {"shake": 0.0}])],
				[1.9, M([{"shake": 0.9}, HD(0.02, 0.1, -0.1)])],
				[2.2, M([{"shake": 0.0}, HD(0.0, 0.0, 0.0), R(0.16, -0.95, 0.03, 0.05)]), "s"],
				[2.6, M([Rt(0.05, -0.3, 0.45, 0.3), WR(0.0, -0.4), {"gesture": "thumbsup", "curl": 1.0, "face": "grin"}]), "s"],
				[3.3, M([Rt(0.06, -0.28, 0.46, 0.3), {"gesture": "thumbsup"}])],
			])
		"Elly":
			# main sur le cœur, long soupir, revers de main sur le front, sourire, petit signe doux
			p.plant(-1, p.foot_free[-1], feet_end, p.foot_at[-1])
			p.plant(1, p.foot_free[1], feet_end, p.foot_at[1])
			keys(p, t0, [
				[0.0, M([H(0, -0.12, 0), B(0.25), C(0.1), HD(0.2), Lt(-0.12, -0.32, 0.3, 0.3), WL(0.3, 0.6), R(0.25, -0.85, 0.1, 0.1), {"curl_l": 0.1, "face": "tired", "jaw": 0.4}])],
				[0.6, M([H(0, -0.04, 0), B(0.02), C(-0.08), HD(-0.12, 0.0, 0.05), {"jaw": 0.0, "face": "calm"}])],
				[1.0, M([HD(0.08, 0.0, 0.08), Rt(-0.12, 0.42, 0.25, 0.6), WR(0.9, 0.0, -0.4), {"face": "smile"}])],
				[1.35, M([HD(0.1, 0.05, 0.1), Rt(0.05, 0.4, 0.22, 0.6), WR(0.9, 0.0, -0.4)])],
				[1.7, M([H(0, -0.05, 0), B(0.05), HD(0.05, 0.2, 0.1), Lt(-0.1, -0.35, 0.32, 0.3), R(0.35, 0.1, 0.4, 0.2), WR(-0.3), {"curl": 0.1, "face": "smile"}])],
				[2.0, M([R(0.38, 0.15, 0.38, 0.2), WR(0.4)])],
				[2.3, M([R(0.36, 0.12, 0.4, 0.2), WR(-0.3)])],
				[2.9, M([HD(0.0, 0.1, 0.12), Rt(-0.08, 0.15, 0.3, 0.5), WR(0.6), {"face": "laugh", "jaw": 0.2}])],
				[3.4, M([HD(0.02, 0.05, 0.1), {"face": "smile", "jaw": 0.0}])],
			])
		"Bleuette":
			# les larmes de joie, mains sur les joues, trois petits sauts, tourbillon, mains jointes
			p.plant(-1, p.foot_free[-1], t0 + 0.75, p.foot_at[-1])
			p.plant(1, p.foot_free[1], t0 + 0.75, p.foot_at[1])
			keys(p, t0, [
				[0.0, M([H(0, -0.14, 0), B(0.15), C(0.12), HD(-0.1, 0.0, 0.1), Lt(-0.08, 0.32, 0.25, 0.3), Rt(-0.08, 0.34, 0.24, 0.3), WL(0.8, 0.5), WR(0.8, -0.5), {"curl": 0.2, "curl_l": 0.2, "face": "sad", "shake": 0.3}])],
				[0.45, M([HD(0.05, 0.1, 0.1), {"face": "laugh", "shake": 0.2}])],
				[0.7, M([H(0, -0.18, 0), B(0.12), Lt(0.2, -0.3, 0.3, 0.3), Rt(0.2, -0.3, 0.3, 0.3), {"curl": 0.9, "curl_l": 0.9, "shake": 0.0}]), "s"],
			])
			for k: int in range(3):
				var th: float = t0 + 0.75 + 0.36 * float(k)
				hop(p, th, 0.12 - 0.02 * float(k), 0.3)
				keys(p, th, [
					[0.08, M([H(0, 0.02, 0), B(-0.06), HD(0.25 + 0.05 * float(k), 0.08 * float(k - 1)), Lt(0.3, 0.6, 0.15, 0.2), Rt(0.3, 0.65, 0.15, 0.2), {"jaw": 0.8, "face": "laugh"}])],
					[0.3, M([H(0, -0.14, 0), B(0.1), Lt(0.25, 0.1, 0.3, 0.3), Rt(0.25, 0.12, 0.3, 0.3), {"jaw": 0.3}])],
				])
			var spin_at: float = t0 + 0.75 + 0.36 * 3.0 + 0.1
			var th0: float = p.theta(spin_at)
			p.turn(spin_at, th0, "s")
			p.turn(spin_at + 0.7, th0 + TAU, "s")
			p.plant(-1, p.foot_free[-1], spin_at + 0.05, p.foot_at[-1])
			p.plant(1, p.foot_free[1], spin_at + 0.05, p.foot_at[1])
			var b_l: Dictionary = p.base
			for k: int in range(1, 7):
				var tt: float = spin_at + 0.7 * float(k) / 7.0
				var sd: int = -1 if k % 2 == 1 else 1
				p.foot_l(tt, sd, (b_l[sd] as Vector3) + Vector3(0.0, 0.06, 0.0), -0.4)
				p.foot_l(tt + 0.05, - sd, b_l[- sd], 0.0)
			p.plant(-1, spin_at + 0.75, feet_end, p.rest_foot(-1, spin_at + 0.75))
			p.plant(1, spin_at + 0.8, feet_end, p.rest_foot(1, spin_at + 0.8))
			keys(p, spin_at, [
				[0.1, M([H(0, -0.04, 0), B(-0.05), C(-0.05), HD(0.2, 0.0, 0.15), L(0.6, 0.1, 0.0, 0.2), R(0.6, 0.1, 0.0, 0.2), {"curl": 0.2, "curl_l": 0.2, "face": "laugh"}])],
				[0.75, M([H(0, -0.1, 0), B(0.08), HD(0.05, 0.0, 0.1), Lt(-0.05, -0.2, 0.36, 0.3), Rt(-0.04, -0.18, 0.36, 0.3), WL(0.6), WR(0.6), {"curl": 0.5, "curl_l": 0.5, "face": "smile"}])],
				[1.3, M([HD(0.1, 0.1, 0.15), {"face": "laugh", "jaw": 0.3}])],
			])
		_:
			stand(p, t0, feet_end)
			p.pose(t0, neutral(p.person))


# ================================================================== Alice --
# Griffes ouvertes, épaules hautes, tête en avant ; elle ne court pas comme les élèves.

static func claws(spread: float = 0.0) -> Dictionary:
	return M([L(0.34 + spread, -0.7, 0.2, 0.5), R(0.36 + spread, -0.68, 0.22, 0.5), WL(0.5, 0.0, 0.3), WR(0.5, 0.0, -0.3), {"curl": 0.55, "curl_l": 0.55}])


# Course d'Alice : grandes foulées basses, bras qui traînent en arrière griffes ouvertes.
static func alice_run(a: Performer, t0: float, t1: float, opts: Dictionary = {}) -> Dictionary:
	var info: Dictionary = run(a, t0, t1, M([{"no_arms": true}, opts]))
	for s: Dictionary in info.steps:
		if bool(s.get("settle", false)): continue
		var at: float = float(s.land) + 0.05
		var sd: int = int(s.side)
		var v: float = float(s.speed)
		var run_w: float = smoothstep(1.0, 4.5, v)
		a.pose(at, M([L(0.42, lerpf(-0.75, -0.55, run_w), lerpf(0.1, -0.45, run_w) + 0.12 * float(-sd), 0.55), R(0.44, lerpf(-0.73, -0.52, run_w), lerpf(0.12, -0.42, run_w) + 0.12 * float(sd), 0.55), WL(0.6, 0.0, 0.4), WR(0.6, 0.0, -0.4), {"curl": 0.5, "curl_l": 0.5}]))
	return info


# La griffe plantée dans le sol : les piques partent vers la porte.
static func alice_slam(a: Performer, t: float, theta: float) -> float:
	var s: Vector3 = a.end_p
	a.hold(t + 0.95)
	var st: Dictionary = style("Alice")
	var front: Vector3 = w(s, theta, -0.1, 0.42)
	a.plant(1, a.foot_free[1], t + 0.95, a.foot_at[1], 0.0, 0.0)
	a.plant(-1, a.foot_free[-1], t + 0.08, a.foot_at[-1])
	_swing(a, -1, t + 0.08, a.foot_at[-1], t + 0.24, front, 1.5, -0.3, 16, st, a.seed)
	a.plant(-1, t + 0.24, t + 0.95, front)
	keys(a, t, [
		[0.0, {"face": "menace"}],
		[0.12, M([H(0, -0.1, 0.0), B(0.0, 0.1), C(-0.15, 0.1), HD(0.2, -0.1, -0.1), R(0.3, 0.75, -0.15, 0.6), WR(-0.8), L(0.45, -0.4, 0.2, 0.5), WL(0.5), {"curl": 0.2, "curl_l": 0.4, "face": "angry"}]), "s"],
		[0.28, M([H(0, -0.5, 0.15), B(0.85, -0.1), C(0.35), HD(0.6, 0.0, 0.0), Rg(0.12, 0.45, 0.0), WR(0.0), {"el_r": 0.4}, L(0.5, -0.3, -0.1, 0.5), {"curl": 1.0, "ev": "roar", "fx": "crack", "sq": 0.95}]), "s"],
		[0.5, M([H(0, -0.48, 0.15), B(0.8, -0.08), HD(0.45, 0.05, 0.1), Rg(0.12, 0.45, 0.0), {"sq": 1.0, "shake": 0.5}])],
		[0.78, M([H(0, -0.18, 0.05), B(0.3), C(0.15), HD(0.3, 0.0, -0.15), claws(0.05), {"shake": 0.0, "face": "menace"}])],
		[0.95, M([H(0, -0.08, 0.0), B(0.15), C(0.1), HD(0.1, 0.0, -0.1), claws()])],
	])
	return t + 0.28


# Coup de griffe (le bras droit part de haut derrière l'épaule et traverse en diagonale).
static func alice_slash(a: Performer, t: float) -> float:
	keys(a, t, [
		[0.0, M([H(0, -0.06, 0), B(0.05, 0.25), C(-0.05, 0.25), HD(0.1, -0.2), R(0.3, 0.62, -0.2, 0.6), WR(-0.6), L(0.35, -0.55, 0.3, 0.5), {"curl": 0.1, "face": "angry"}]), "s"],
		[0.13, M([H(0, -0.16, 0.08), B(0.35, -0.4), C(0.15, -0.35), HD(0.15, 0.3), R(-0.2, -0.5, 0.6, 0.2), WR(0.5), L(0.4, -0.5, -0.1, 0.5), {"fx": "trail_r whoosh", "ev": "grunt"}])],
		[0.3, M([H(0, -0.12, 0.05), B(0.25, -0.3), C(0.1, -0.2), HD(0.1, 0.2), R(-0.1, -0.7, 0.35, 0.3), {"curl": 0.4}])],
	])
	return t + 0.12


# Flashbang : bras devant les yeux, recul titubant, secoue la tête.
static func alice_flashed(a: Performer, t: float, theta: float) -> void :
	var s: Vector3 = a.end_p
	var back: Vector3 = s - ahead(theta) * 0.55
	a.hold(t)
	a.go(t + 0.45, back, Vector3.ZERO)
	a.hold(t + 1.3)
	run(a, t, t + 0.6, {"stop": true, "first": 1, "no_upper": true, "cadence": 1.2, "seed": 71})
	a.plant(-1, a.foot_free[-1], t + 1.3, a.foot_at[-1])
	a.plant(1, a.foot_free[1], t + 1.3, a.foot_at[1])
	keys(a, t, [
		[0.0, M([H(0, -0.05, -0.05), B(-0.2, 0.0), C(-0.2), HD(-0.3, 0.0, 0.0), Rt(-0.12, 0.38, 0.28, 0.7), WR(0.6, 0.0, 0.5), Lt(0.3, 0.2, 0.3, 0.5), {"face": "pain", "ev": "hurt", "curl": 0.3, "curl_l": 0.1}])],
		[0.3, M([H(0, -0.12, -0.08), B(0.1, 0.25, 0.1), C(0.15), HD(-0.35, 0.2, 0.15), Rt(-0.1, 0.35, 0.3, 0.7), Lt(0.45, -0.1, 0.25, 0.5), {"shake": 0.6}])],
		[0.6, M([B(0.2, -0.2, -0.1), HD(-0.2, -0.3, -0.1), Rt(-0.05, 0.3, 0.32, 0.7)])],
		[0.85, M([H(0, -0.14, 0), B(0.35, 0.0), C(0.2), HD(0.2, 0.25, 0.0), Rt(0.15, -0.2, 0.35, 0.5), Lt(0.3, -0.4, 0.3, 0.5), {"shake": 0.3, "face": "angry"}])],
		[1.0, M([HD(0.15, -0.3, 0.05)])],
		[1.12, M([HD(0.2, 0.2, -0.05)])],
		[1.3, M([H(0, -0.08, 0), B(0.2), C(0.12), HD(0.1, 0.0, -0.1), claws(), {"shake": 0.0, "face": "angry"}])],
	])


# Drone dans la tête : la tête part sur le côté, elle titube et chasse le drone d'un revers.
static func alice_droned(a: Performer, t: float, theta: float) -> void :
	var s: Vector3 = a.end_p
	var side_step: Vector3 = s - ahead(theta) * 0.25 + (- leftward(theta)) * 0.28
	a.hold(t)
	a.go(t + 0.35, side_step, Vector3.ZERO)
	a.hold(t + 1.0)
	run(a, t, t + 0.5, {"stop": true, "first": 1, "no_upper": true, "cadence": 1.2, "seed": 73})
	a.plant(-1, a.foot_free[-1], t + 1.0, a.foot_at[-1])
	a.plant(1, a.foot_free[1], t + 1.0, a.foot_at[1])
	keys(a, t, [
		[0.0, M([B(-0.1, -0.2, 0.15), C(-0.15, -0.2), HD(0.15, -0.6, 0.35), L(0.5, -0.2, 0.2, 0.5), R(0.45, -0.3, 0.1, 0.5), {"face": "pain", "ev": "hurt"}]), "s"],
		[0.22, M([H(0.03, -0.12, 0), B(0.15, -0.1, 0.1), HD(0.0, -0.3, 0.2), {"face": "angry"}])],
		[0.42, M([B(0.1, 0.35), C(0.05, 0.3), HD(0.2, 0.4, 0.0), L(0.25, 0.55, 0.35, 0.5), WL(-0.6), {"fx": "whoosh", "ev": "grunt"}])],
		[0.56, M([B(0.12, -0.3), C(0.05, -0.25), HD(0.25, -0.15), L(-0.05, 0.35, 0.55, 0.3), WL(0.4)])],
		[1.0, M([H(0, -0.08, 0), B(0.18), C(0.1), HD(0.12, 0.0, -0.1), claws(), {"face": "angry"}])],
	])


# Poussée de Lysia : pliée en deux par le choc, elle part en arrière en glissant sur les talons,
# une main qui frotte le sol pour s'arrêter.
static func alice_pushed(a: Performer, t: float, theta: float, metres: float) -> void :
	var s: Vector3 = a.end_p
	var back: Vector3 = s - ahead(theta) * metres
	a.hold(t)
	a.go(t + 0.55, back, Vector3.ZERO)
	a.hold(t + 1.45)
	var fl: Vector3 = a.foot_at[-1]
	var fr: Vector3 = a.foot_at[1]
	var slide: Vector3 = - ahead(theta) * metres
	# glissade : les pieds suivent la racine (dérapage voulu, poussière)
	a.plant(-1, a.foot_free[-1], t, fl)
	a.plant(1, a.foot_free[1], t, fr)
	for k: int in range(1, 7):
		var u: float = float(k) / 6.0
		var e: float = 1.0 - (1.0 - u) * (1.0 - u)
		a.foot_w(t + 0.55 * u, -1, fl + slide * e + Vector3.UP * float(a.base[-1].y), 0.3)
		a.foot_w(t + 0.55 * u, 1, fr + slide * e + Vector3.UP * float(a.base[1].y), 0.3)
	a.plant(-1, t + 0.6, t + 1.45, fl + slide)
	a.plant(1, t + 0.6, t + 1.45, fr + slide)
	a.fx(t + 0.1, "skid")
	a.fx(t + 0.3, "dust")
	keys(a, t, [
		[0.0, M([H(0, -0.1, -0.15), B(0.55, 0.0), C(0.3), HD(-0.2, 0.0, 0.0), L(0.4, -0.2, 0.55, 0.3), R(0.4, -0.2, 0.55, 0.3), {"face": "pain", "ev": "hurt", "curl": 0.1, "curl_l": 0.1}]), "s"],
		[0.25, M([H(0, -0.32, -0.2), B(0.5, 0.1), C(0.25), HD(0.2, 0.1), Lg(0.4, 0.3, 0.0), R(0.5, -0.1, 0.4, 0.4), {"el_l": 0.4, "shake": 0.4}])],
		[0.55, M([H(0, -0.38, -0.15), B(0.55, 0.05), HD(0.35, 0.0, 0.1), Lg(0.4, 0.35, 0.0), R(0.45, -0.3, 0.45, 0.4), {"shake": 0.2, "face": "angry"}]), "s"],
		[0.95, M([H(0, -0.2, 0), B(0.35), C(0.2), HD(0.25, 0.0, -0.1), claws(0.1), {"shake": 0.0}])],
		[1.45, M([H(0, -0.08, 0), B(0.18), C(0.1), HD(0.12, 0.0, -0.12), claws()])],
	])


# Contre d'Usayuko : la tête fouettée, quart de tour, elle recule en titubant, sonnée.
static func alice_countered(a: Performer, t: float, theta: float) -> void :
	var s: Vector3 = a.end_p
	var back: Vector3 = s - ahead(theta) * 1.4 + (- leftward(theta)) * -0.3
	a.hold(t)
	a.go(t + 0.6, back, Vector3.ZERO)
	a.hold(t + 1.5)
	a.turn(t, a.theta(t), "s")
	a.turn(t + 0.25, a.theta(t) + 0.7)
	a.turn(t + 0.9, a.theta(t) + 0.15, "s")
	run(a, t, t + 0.75, {"stop": true, "first": -1, "no_upper": true, "cadence": 1.1, "seed": 75})
	a.plant(-1, a.foot_free[-1], t + 1.5, a.foot_at[-1])
	a.plant(1, a.foot_free[1], t + 1.5, a.foot_at[1])
	keys(a, t, [
		[0.0, M([B(-0.15, 0.45, -0.2), C(-0.2, 0.4), HD(0.3, 0.8, -0.4), L(0.6, 0.1, 0.0, 0.5), R(0.5, 0.25, -0.1, 0.5), {"face": "pain", "ev": "hurt", "curl": 0.1, "curl_l": 0.1}]), "s"],
		[0.3, M([H(0, -0.15, -0.05), B(0.2, 0.2, -0.1), C(0.1), HD(0.0, 0.3, -0.2), L(0.5, -0.4, 0.1, 0.5), R(0.5, -0.4, 0.2, 0.5), {"face": "dazed", "shake": 0.3}])],
		[0.65, M([H(0, -0.18, 0), B(0.3, -0.1, 0.12), HD(-0.1, -0.2, 0.25), {"shake": 0.2}])],
		[0.95, M([B(0.25, 0.1, -0.1), HD(0.05, 0.25, -0.2)])],
		[1.2, M([B(0.25, -0.05, 0.08), HD(0.1, -0.15, 0.15), {"face": "angry"}])],
		[1.5, M([H(0, -0.1, 0), B(0.22), C(0.12), HD(0.12, 0.0, -0.1), claws(), {"shake": 0.0}])],
	])


# L'esquive (élève seul) : Alice frappe dans le vide.
static func alice_whiff(a: Performer, t: float) -> void :
	alice_slash(a, t)
	keys(a, t, [
		[0.45, M([H(0, -0.1, 0), B(0.2, 0.0), HD(0.1, 0.0, -0.1), claws(), {"face": "angry"}])],
	])


# Trop tard : elle s'élance dans ses propres piques, le bras tendu par la porte, la griffe se
# referme sur le vide ; elle reste là, à genoux sur le seuil.
static func alice_lunge(a: Performer, t: float, reach_x: float) -> void :
	var s: Vector3 = a.end_p
	var land: Vector3 = Vector3(reach_x * 0.9, 0.0, -0.55)
	a.hold(t)
	a.turn(t, a.theta(t), "s")
	a.turn(t + 0.2, 0.0, "s")
	a.leap(t + 0.42, land, 0.22, Vector3(0, 0, 0.6))
	a.go(t + 0.62, land + Vector3(0, 0, 0.12), Vector3.ZERO)
	a.hold(t + 0.7)
	var leg: float = a.leg
	if a.grounded(-1, t): a.plant(-1, a.foot_free[-1], t + 0.02, a.foot_at[-1], 0.0, -0.8)
	if a.grounded(1, t): a.plant(1, a.foot_free[1], t + 0.06, a.foot_at[1], 0.0, -0.9)
	a.foot_l(t + 0.22, -1, (a.base[-1] as Vector3) + Vector3(0.0, 0.1 * leg, 0.35 * leg), -0.8)
	a.foot_l(t + 0.22, 1, (a.base[1] as Vector3) + Vector3(0.0, 0.25 * leg, 0.45 * leg), -0.9)
	# genou droit au sol, pied gauche devant
	a.plant(-1, t + 0.42, t + 0.75, Vector3(land.x + 0.14, 0.0, land.z + 0.3), 0.1, 0.0)
	a.foot_l(t + 0.48, 1, Vector3(float(a.base[1].x), float(a.base[1].y) + 0.06, 0.4), -1.25)
	a.foot_l(t + 0.75, 1, Vector3(float(a.base[1].x), float(a.base[1].y) + 0.06, 0.42), -1.25)
	a.fx(t + 0.42, "dust")
	keys(a, t, [
		[0.0, M([H(0, -0.2, 0.05), B(0.4), C(0.2), HD(0.4), L(0.4, -0.5, -0.3, 0.5), R(0.4, -0.3, -0.35, 0.5), {"face": "angry", "ev": "roar"}]), "s"],
		[0.18, M([H(0, -0.12, 0.1), B(0.7), C(0.15), HD(0.75), R(0.05, 0.12, 0.98, 0.1), WR(-0.3), L(0.45, -0.3, -0.4, 0.5), {"curl": 0.0}])],
		[0.36, M([H(0, -0.22, 0.12), B(0.65), HD(0.7, 0.0, 0.05), R(0.04, 0.08, 1.0, 0.05), {"curl": 0.05}])],
		[0.44, M([H(0, -0.5, 0.0), B(0.5), C(0.1), HD(0.55), R(0.05, 0.02, 0.98, 0.05), {"curl": 1.0, "fx": "whoosh"}]), "s"],
		[0.62, M([H(0, -0.48, 0.0), B(0.45), HD(0.5, 0.0, 0.1), R(0.06, -0.02, 0.95, 0.05), {"curl": 1.0, "face": "surprise"}])],
		[0.75, M([H(0, -0.46, 0.0), B(0.4), HD(0.45, 0.05, 0.12), R(0.08, -0.08, 0.9, 0.1), L(0.4, -0.75, 0.1, 0.4), {"face": "angry"}])],
	])


# Alice reste sur le seuil : elle se relève, serre les poings et hurle ; puis elle les fixe.
static func alice_rage(a: Performer, t0: float, t1: float) -> void :
	var s: Vector3 = a.end_p
	a.hold(t1)
	var stand_l: Vector3 = a.foot_at[-1]
	var stand_r: Vector3 = w(s, 0.0, 0.16, -0.05)
	a.plant(-1, a.foot_free[-1], t1, stand_l)
	_swing(a, 1, t0 + 0.4, a.to_world((a.base[1] as Vector3) + Vector3(0, 0.06, 0.42), t0 + 0.4), t0 + 0.65, stand_r, 0.6, -0.2, 17, style("Alice"), a.seed)
	a.plant(1, t0 + 0.65, t1, stand_r)
	keys(a, t0, [
		[0.0, M([H(0, -0.46, 0.0), B(0.4), HD(0.45, 0.05, 0.12), R(0.1, -0.2, 0.85, 0.2), L(0.4, -0.75, 0.1, 0.4), {"face": "angry"}])],
		[0.5, M([H(0, -0.2, 0.0), B(0.25), C(0.1), HD(0.2), L(0.4, -0.6, 0.15, 0.5), R(0.4, -0.6, 0.2, 0.5), {"curl": 1.0, "curl_l": 1.0}])],
		[0.85, M([H(0, -0.05, 0.0), B(-0.15), C(-0.3), HD(0.45, 0.0, 0.0), L(0.45, -0.45, -0.15, 0.6), R(0.45, -0.45, -0.15, 0.6), {"jaw": 1.0, "ev": "roar", "shake": 0.8}])],
		[1.5, M([B(-0.12), C(-0.28), HD(0.4, 0.05, 0.05), {"jaw": 0.9, "shake": 0.6}])],
		[1.9, M([H(0, -0.1, 0.0), B(0.25), C(0.15), HD(0.05, 0.0, -0.15), claws(0.0), {"jaw": 0.0, "shake": 0.0, "face": "menace"}])],
		[2.6, M([B(0.28), HD(0.02, 0.1, -0.2)])],
		[3.3, M([B(0.25), HD(0.0, -0.05, -0.18)])],
	])


# ============================================================ modules 0.17 (suite) --

# Piques courbes du Shadow spike du jeu (même dessin qu'effects.gd), hauteur 1 : chaque pique
# est mise à l'échelle par la haie.
static func thorn_mesh(height: float, lean: float) -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	for level: int in range(5):
		var fraction: float = float(level) / 4.0
		var radius: float = (1.0 - fraction) * 0.31 + 0.006
		var ring: Array[Vector3] = []
		for i: int in range(7):
			var angle: float = float(i) / 7.0 * TAU
			ring.append(Vector3(cos(angle) * radius + fraction * fraction * lean * 0.17, fraction * height, sin(angle) * radius - fraction * fraction * 0.32))
		rings.append(ring)
	for level: int in range(4):
		for i: int in range(7):
			var j: int = (i + 1) % 7
			for vertex: Vector3 in [rings[level][i], rings[level + 1][i], rings[level][j], rings[level][j], rings[level + 1][i], rings[level + 1][j]]: surface.add_vertex(vertex)
	surface.generate_normals()
	return surface.commit()


# Vol d'un pied d'un appui à l'autre (petit pas), pour les modules qui posent leurs pieds à la main.
static func swing_to(p: Performer, side: int, t0: float, from_w: Vector3, t1: float, to_w: Vector3, v: float = 0.8) -> void :
	_swing(p, side, t0, from_w, t1, to_w, v, -0.3, 21 + side, style(p.person), p.seed)


# Les piques jaillissent devant eux : sursaut propre à chacun pendant le freinage (la course ne
# pilote plus le haut du corps après `brake`), puis on se fige, essoufflé.
static func brake_upper(p: Performer, brake: float, stop: float) -> void :
	var flinch: Dictionary
	var brace: Dictionary
	var settle: Dictionary = tense(p.person)
	match p.person:
		"Simon":
			flinch = M([H(0, -0.06, -0.05), B(-0.3, 0.06), C(-0.2), HD(-0.12, 0.3, 0.12), Lt(0.04, 0.4, 0.32, 0.6), Rt(0.1, 0.32, 0.36, 0.6), WL(0.7), WR(0.7), {"curl": 0.15, "curl_l": 0.15, "face": "panic"}])
			brace = M([H(0, -0.16, -0.08), B(-0.16, -0.05), C(-0.06), HD(0.02, 0.12), L(0.45, -0.32, 0.3, 0.5), R(0.48, -0.26, 0.26, 0.5), {"curl": 0.3, "curl_l": 0.3}])
		"Bleuette":
			flinch = M([H(0, -0.14, -0.02), B(0.05), C(0.18), HD(-0.3, -0.1, 0.1), Lt(-0.06, 0.3, 0.3, 0.3), Rt(-0.05, 0.32, 0.28, 0.3), WL(1.0), WR(1.0), {"curl": 0.5, "curl_l": 0.5, "face": "fear", "shake": 0.4}])
			brace = M([H(0, -0.18, -0.02), B(0.1), C(0.16), HD(-0.18, 0.05, 0.08), Lt(-0.05, 0.12, 0.38, 0.3), Rt(-0.04, 0.15, 0.37, 0.3), WL(0.8), WR(0.8), {"shake": 0.3}])
		"Elly":
			flinch = M([H(0, -0.08, -0.04), B(-0.2, -0.12), C(-0.1), HD(-0.05, 0.2), L(0.75, -0.05, 0.25, 0.3), Rt(-0.1, -0.15, 0.3, 0.3), WL(-0.3), {"curl_l": 0.1, "curl": 0.5, "face": "surprise"}])
			brace = M([H(0, -0.14, -0.06), B(-0.08, -0.06), C(-0.03), HD(0.0, 0.15), L(0.6, -0.25, 0.25, 0.3), Rt(-0.12, -0.2, 0.32, 0.3), {"curl_l": 0.2}])
		"Ashura":
			flinch = M([H(0, -0.1, -0.06), B(-0.22, 0.08), C(-0.08), HD(0.04, -0.1), L(0.55, -0.1, 0.1, 0.4), R(0.5, -0.05, 0.15, 0.4), {"curl": 0.5, "curl_l": 0.5, "face": "surprise"}])
			brace = M([H(0, -0.2, -0.1), B(-0.1, 0.04), C(-0.02), HD(0.06, -0.05), L(0.42, -0.45, 0.12, 0.3), R(0.4, -0.42, 0.18, 0.3), {"curl": 0.6, "curl_l": 0.6, "face": "determined"}])
		"Lysia":
			flinch = M([H(0, -0.04, -0.03), B(-0.12), C(-0.04), HD(0.0, 0.0, 0.2), L(0.32, -0.6, 0.2, 0.2), R(0.32, -0.6, 0.2, 0.2), {"curl": 0.1, "curl_l": 0.1, "face": "surprise", "shake": 0.5}])
			brace = M([H(0, -0.06, -0.02), B(-0.03), C(0.0), HD(0.0, 0.0, 0.08), L(0.2, -0.85, 0.08, 0.1), R(0.2, -0.85, 0.08, 0.1), {"shake": 0.0, "face": "focus"}])
		"Usayuko":
			flinch = M([H(0, -0.14, -0.06), B(-0.18, -0.1), C(-0.05, -0.1), HD(0.0, 0.1), Lt(0.08, -0.05, 0.45, 0.5), Rt(0.25, -0.3, 0.25, 0.5), WL(0.3), {"curl": 1.0, "curl_l": 1.0, "face": "angry"}])
			brace = M([H(0, -0.2, -0.08), B(-0.06, -0.05), C(0.02), HD(0.02, 0.06), Lt(0.06, -0.12, 0.42, 0.5), Rt(0.14, -0.3, 0.35, 0.5), {"face": "determined"}])
		_:
			flinch = M([H(0, -0.08, -0.04), B(-0.2), C(-0.08), HD(-0.05), L(0.5, -0.1, 0.25, 0.3), R(0.5, -0.1, 0.25, 0.3), {"face": "surprise"}])
			brace = M([H(0, -0.14, -0.06), B(-0.08), L(0.4, -0.4, 0.2, 0.3), R(0.4, -0.4, 0.2, 0.3)])
	var seed_value: int = p.seed + 41
	var span: float = maxf(stop - brake, 0.3)
	keys(p, brake, [
		[0.0, M([{"ev": "gasp"}])],
		[0.1 + 0.03 * n1(seed_value, 0), flinch, "s"],
		[span * 0.55 + 0.05, brace],
		[span + 0.12, M([settle, {"face": "fear"}])],
	])
	# le souffle court après l'arrêt : épaules qui montent et retombent
	for k: int in range(3):
		var tt: float = stop + 0.22 + 0.3 * float(k) + 0.04 * n1(seed_value, k + 1)
		p.pose(tt, {"chest": (settle.get("chest", Vector3.ZERO) as Vector3) + Vector3(-0.045 if k % 2 == 0 else 0.0, 0.0, 0.0)})


# Seul(e) contre Alice : elle frappe, on plonge de côté sous la griffe, on se relève tendu(e).
static func dodge(p: Performer, t: float, theta: float) -> void :
	var s: Vector3 = p.end_p
	var away: float = 1.0 if p.person == "Elly" else -1.0
	var to: Vector3 = s + leftward(theta) * (0.5 * away) - ahead(theta) * 0.12
	p.hold(t + 0.08)
	p.turn(t, p.theta(t), "s")
	p.turn(t + 0.16, theta, "s")
	p.go(t + 0.32, to, Vector3.ZERO)
	p.hold(t + 0.62)
	run(p, t + 0.04, t + 0.62, {"stop": true, "first": 1 if away > 0.0 else -1, "no_upper": true, "seed": 3})
	keys(p, t, [
		[0.0, {"face": "fear"}],
		[0.12, M([H(0.1 * away, -0.32, 0), B(0.35, 0.0, 0.18 * away), C(0.15), HD(-0.3, 0.0, 0.12 * away), Lt(0.0, 0.42, 0.22, 0.6), Rt(0.0, 0.46, 0.22, 0.6), WL(0.8), WR(0.8), {"curl": 0.4, "curl_l": 0.4, "ev": "gasp", "face": "panic"}]), "s"],
		[0.3, M([H(0.08 * away, -0.36, 0), B(0.4, 0.0, 0.1 * away), HD(-0.22, 0.12 * away, 0.1 * away), {"shake": 0.45}])],
		[0.6, M([tense(p.person), {"shake": 0.0, "face": "fear"}])],
	])


# Alice a le temps : elle se fige comme une statue, puis des à-coups de tête d'oiseau, les
# griffes qui se referment une à une, une épaule qui roule. Jamais deux fois le même geste.
static func alice_wait(a: Performer, t0: float, t1: float) -> void :
	var span: float = t1 - t0
	if span < 0.12: return
	a.hold(t1)
	for side: int in [-1, 1]:
		if float(a.foot_free[side]) < t1 - 0.02:
			var at: Vector3 = a.foot_at[side] if (a.foot_at[side] as Vector3) != Vector3.ZERO else a.rest_foot(side, t0)
			a.plant(side, a.foot_free[side], t1, at)
	var beats: int = maxi(1, int(span / 0.5))
	var seed_value: int = a.seed + int(t0 * 37.0)
	for k: int in range(beats + 1):
		var u: float = float(k) / float(beats)
		var tt: float = minf(t1 - 0.02, t0 + span * u + 0.07 * n1(seed_value, k))
		var tilt: float = 0.28 * n1(seed_value + 3, k)
		var yaw: float = 0.22 * n1(seed_value + 5, k)
		var curl_r: float = 0.45 + 0.4 * absf(n1(seed_value + 7, k))
		var curl_l: float = 0.45 + 0.4 * absf(n1(seed_value + 9, k))
		var pose: Dictionary = M([H(0, -0.05 - 0.03 * absf(n1(seed_value + 11, k)), 0.02), B(0.18 + 0.05 * n1(seed_value + 13, k)), C(0.12, 0.06 * n1(seed_value + 15, k)), HD(0.02 + 0.06 * n1(seed_value + 17, k), yaw, tilt), claws(0.04 * n1(seed_value + 19, k)), {"curl": curl_r, "curl_l": curl_l, "face": "menace"}])
		# la tête s'arrête net (« s ») : des à-coups, pas une oscillation
		a.pose(tt, pose, "s")
		if k < beats: a.pose(tt + minf(0.22, span / float(beats) * 0.45), {"head": HD(0.02 + 0.06 * n1(seed_value + 17, k), yaw, tilt).head}, "s")


# On tire un ami par-dessus la haie. L'aide (h), déjà dehors, vient se planter face à la haie dans
# le couloir de son ami, se penche et tend les deux mains ; l'ami (c) prend deux pas d'élan,
# attrape les mains au-dessus des piques, fléchit et saute ; l'aide se jette en arrière en tirant
# (un grand pas de recul) et le rattrape à l'arrivée.
# Rend {grab, release, land, out}.
static func haul(c: Performer, h: Performer, t: float, lane: float) -> Dictionary:
	var spot: Vector3 = Vector3(lane + 0.06, 0.0, 0.8)
	step_to(h, maxf(t - 0.55, h.end_t), maxf(t - 0.06, h.end_t + 0.3), spot, PI, {"seed": 43})
	var st_c: Dictionary = style(c.person)
	var leg_c: float = c.leg
	var t_grab: float = t + 0.3
	var t_jump: float = t + 0.46
	var t_land: float = t + 0.94
	# --- l'aide : pied gauche avancé contre la haie, il se penche, tire, recule d'un pas
	var front: Vector3 = w(spot, PI, -0.13, 0.17)
	var spot2: Vector3 = spot + Vector3(0.0, 0.0, 0.52)
	var back2: Vector3 = w(spot2, PI, -0.13, -0.04)
	var right2: Vector3 = w(spot2, PI, 0.14, 0.02)
	h.hold(t + 0.48)
	h.go(t + 0.64, spot + Vector3(0.0, 0.0, 0.26), Vector3(0, 0, 1.1))
	h.go(t + 0.86, spot2, Vector3.ZERO)
	h.hold(t + 1.5)
	var h_start: float = h.foot_free[-1]
	h.plant(-1, h_start, t + 0.02, h.foot_at[-1])
	swing_to(h, -1, t + 0.02, h.foot_at[-1], t + 0.15, front)
	h.plant(-1, t + 0.15, t + 0.62, front, 0.0, -0.4)
	swing_to(h, -1, t + 0.62, front, t + 0.8, back2, 1.4)
	h.plant(-1, t + 0.8, t + 1.5, back2)
	var r_at: Vector3 = h.foot_at[1]
	h.plant(1, h.foot_free[1], t + 0.86, r_at, 0.0, -0.3)
	swing_to(h, 1, t + 0.86, r_at, t + 1.02, right2)
	h.plant(1, t + 1.02, t + 1.5, right2)
	keys(h, t - 0.06, [
		[0.0, M([H(0, -0.06, 0.02), B(0.2), C(0.08), HD(-0.12), L(0.18, -0.4, 0.55, 0.3), R(0.18, -0.4, 0.55, 0.3), {"curl": 0.2, "curl_l": 0.2, "face": "determined"}])],
		[0.14, M([H(0, -0.12, 0.08), B(0.48), C(0.16), HD(-0.2, 0.0, 0.04), L(0.12, -0.12, 0.88, 0.25), R(0.12, -0.1, 0.9, 0.25), WL(0.2), WR(0.2), {"curl": 0.12, "curl_l": 0.12}])],
		[0.34, M([HD(-0.16, 0.0, -0.03), {"curl": 0.95, "curl_l": 0.95, "ev": "effort"}])],
		[0.5, M([H(0, -0.2, -0.02), B(0.26), C(0.08), HD(-0.05), L(0.1, -0.06, 0.8, 0.3), R(0.1, -0.05, 0.8, 0.3)]), "s"],
		[0.66, M([H(0, -0.26, -0.18), B(-0.32), C(-0.16), HD(0.22, 0.0, 0.05), L(0.12, 0.04, 0.55, 0.45), R(0.12, 0.05, 0.55, 0.45), {"ev": "grunt", "face": "angry"}])],
		[0.86, M([H(0, -0.2, -0.1), B(-0.16), C(-0.08), HD(0.12), L(0.15, -0.08, 0.45, 0.4), R(0.15, -0.08, 0.45, 0.4)])],
		[1.04, M([H(0, -0.14, 0.0), B(0.12), C(0.04), HD(-0.05, 0.0, 0.08), L(0.22, -0.28, 0.42, 0.3), R(0.22, -0.26, 0.42, 0.3), {"curl": 0.6, "curl_l": 0.6, "face": "surprise"}])],
		[1.3, M([neutral(h.person), HD(0.04, 0.12, 0.1), {"face": "laugh"}])],
		[1.56, M([neutral(h.person), HD(0.0, 0.05, 0.04), {"face": "grin"}])],
	])
	# --- l'ami : deux pas d'élan, il attrape les mains, fléchit, saute groupé, se reçoit
	var s: Vector3 = c.end_p
	c.hold(t)
	c.turn(t, c.theta(t), "s")
	c.turn(t + 0.12, 0.0, "s")
	c.go(t + 0.3, Vector3(lane, 0.0, -0.8), Vector3(0, 0, 1.3))
	c.go(t_jump, Vector3(lane, 0.0, -0.7), Vector3(0, 0, 0.4))
	c.leap(t_land, Vector3(lane + 0.04, 0.0, 0.6), 0.68, Vector3(0, 0, 1.4))
	c.go(t_land + 0.24, Vector3(lane + 0.04, 0.0, 0.8), Vector3.ZERO)
	c.hold(t + 1.45)
	var r1: Vector3 = Vector3(lane - 0.09, 0.0, -1.12)
	var r2: Vector3 = Vector3(lane - 0.1, 0.0, -0.76)
	var l1: Vector3 = Vector3(lane + 0.1, 0.0, -0.74)
	c.plant(1, c.foot_free[1], t + 0.03, c.foot_at[1], 0.0, -0.3)
	_swing(c, 1, t + 0.03, c.foot_at[1], t + 0.16, r1, 1.4, -0.3, 31, st_c, c.seed)
	c.plant(1, t + 0.16, t + 0.28, r1, 0.05, -0.5)
	_swing(c, 1, t + 0.28, r1, t + 0.4, r2, 1.0, -0.4, 32, st_c, c.seed)
	c.plant(1, t + 0.4, t_jump + 0.05, r2, 0.05, -0.9)
	c.plant(-1, c.foot_free[-1], t + 0.13, c.foot_at[-1], 0.0, -0.3)
	_swing(c, -1, t + 0.13, c.foot_at[-1], t + 0.27, l1, 1.4, -0.3, 33, st_c, c.seed)
	c.plant(-1, t + 0.27, t_jump + 0.04, l1, 0.05, -0.9)
	var tuck: Array = _tuck(c, "tuck")
	for k: int in range(3):
		var tt: float = t_jump + (t_land - t_jump) * [0.25, 0.5, 0.78][k]
		c.foot_l(tt, -1, (tuck[k] as Array)[0], float((tuck[k] as Array)[2]))
		c.foot_l(tt, 1, (tuck[k] as Array)[1], float((tuck[k] as Array)[3]))
	c.plant(-1, t_land, t + 1.45, Vector3(lane + 0.16, 0.0, 0.64), 0.12, 0.0)
	c.plant(1, t_land + 0.04, t + 1.45, Vector3(lane - 0.08, 0.0, 0.8), 0.12, 0.0)
	keys(c, t, [
		[0.0, M([H(0, -0.05, 0.02), B(0.18), C(0.06), HD(0.1), L(0.14, -0.2, 0.7, 0.3), R(0.14, -0.18, 0.72, 0.3), {"curl": 0.2, "curl_l": 0.2, "face": "determined"}])],
		[0.16, M([H(0, -0.08, 0.04), B(0.24), HD(0.22), L(0.1, 0.02, 0.88, 0.25), R(0.1, 0.04, 0.88, 0.25), {"curl": 0.1, "curl_l": 0.1}])],
		[0.3, M([{"curl": 0.95, "curl_l": 0.95, "ev": "effort"}])],
		[0.46, M([H(0, -0.3, 0.06), B(0.42), C(0.12), HD(0.28), L(0.1, -0.06, 0.74, 0.3), R(0.1, -0.05, 0.74, 0.3)]), "s"],
		[0.54, M([H(0, -0.04, 0.08), B(0.52), HD(0.38)])],
		[0.7, M([H(0, 0.04, 0.1), B(0.82), C(0.12), HD(0.6), L(0.1, 0.2, 0.55, 0.4), R(0.1, 0.22, 0.55, 0.4), {"face": "fear", "jaw": 0.5}])],
		[0.86, M([H(0, -0.04, 0.04), B(0.48), HD(0.36), {"jaw": 0.2}])],
		[0.94, M([H(0, -0.3, 0.0), B(0.42), C(0.14), HD(0.3), L(0.2, -0.2, 0.5, 0.4), R(0.2, -0.2, 0.5, 0.4), {"fx": "dust", "sq": 0.96}]), "s"],
		[1.06, M([H(0, -0.38, -0.02), B(0.36), C(0.12), HD(0.25, 0.0, 0.06), L(0.3, -0.5, 0.35, 0.3), R(0.3, -0.5, 0.36, 0.3), {"sq": 1.0, "curl": 0.4, "curl_l": 0.4, "face": "surprise"}])],
		[1.3, M([H(0, -0.12, 0.0), B(0.12), C(0.06), HD(0.1, -0.15, 0.08), L(0.24, -0.78, 0.15, 0.2), R(0.24, -0.78, 0.15, 0.2), {"face": "laugh"}])],
		[1.45, M([neutral(c.person), HD(0.06, -0.1, 0.06), {"face": "grin"}])],
	])
	return {"grab": t_grab, "release": t_land + 0.06, "land": t_land, "out": t + 1.45}


# Le dernier passe par la brèche de Lysia : trois foulées d'élan, il se laisse tomber en glissade
# sur la hanche (jambe droite tendue, gauche repliée, une main qui frotte le sol), passe sous les
# moignons de piques et se relève d'un coup de reins de l'autre côté.
# Rend {through (instant où il passe le plan de la porte), out}.
static func slide(p: Performer, t: float, lane: float) -> Dictionary:
	var leg: float = p.leg
	var t_drop: float = t + 0.46
	p.hold(t)
	p.turn(t, p.theta(t), "s")
	p.turn(t + 0.14, 0.0, "s")
	p.go(t_drop, Vector3(lane, 0.0, -1.0), Vector3(0, 0, 5.0))
	p.go(t + 1.0, Vector3(lane, 0.0, 1.05), Vector3(0, 0, 0.7))
	p.go(t + 1.3, Vector3(lane, 0.0, 1.25), Vector3.ZERO)
	p.hold(t + 1.5)
	run(p, t, t_drop - 0.02, {"stop": false, "first": 1, "seed": 61, "upper_until": t_drop - 0.1, "lean": 1.2})
	var ankle_r: float = float(p.base[1].y)
	var ankle_l: float = float(p.base[-1].y)
	var xr: float = float(p.base[1].x)
	var xl: float = float(p.base[-1].x)
	# glissade (le corps glisse sur le sol : les pieds glissent avec lui, c'est voulu)
	for k: int in range(4):
		var tt: float = t_drop + 0.04 + 0.14 * float(k)
		p.foot_l(tt, 1, Vector3(xr + 0.02, ankle_r + 0.05, - 0.58 * leg), 0.45)
		p.foot_l(tt, -1, Vector3(xl - 0.04, ankle_l + 0.02, - 0.12 * leg), -0.2)
	# il se relève : pied gauche sous lui, poussée, pied droit qui revient
	var up_l: Vector3 = Vector3(lane + 0.1, 0.0, 1.0)
	var up_r: Vector3 = Vector3(lane - 0.1, 0.0, 1.2)
	p.plant(-1, t + 0.98, t + 1.6, up_l, 0.1, 0.0)
	p.foot_l(t + 1.06, 1, Vector3(xr, ankle_r + 0.14 * leg, - 0.3 * leg), 0.2)
	p.plant(1, t + 1.18, t + 1.6, up_r, 0.1, 0.0)
	p.fx(t_drop + 0.05, "dust")
	p.fx(t_drop + 0.3, "skid")
	keys(p, t, [
		[0.0, {"face": "determined"}],
		[t_drop - t - 0.06, M([H(0, -0.12, 0.05), B(0.3), C(0.08), HD(0.12), L(0.35, -0.45, -0.2, 0.3), R(0.3, -0.35, 0.3, 0.3), {"curl": 0.8, "curl_l": 0.8}])],
		[t_drop - t + 0.08, M([H(0.04, -0.58, -0.2), B(-0.5, 0.0, 0.06), C(-0.1), HD(-0.36, 0.0, 0.05), Lg(0.32, -0.3, 0.0), R(0.3, 0.05, 0.45, 0.4), WR(0.3), {"curl_l": 0.2, "curl": 0.5, "ev": "effort", "face": "angry"}]), "s"],
		[t_drop - t + 0.3, M([H(0.04, -0.62, -0.22), B(-0.56, 0.0, 0.05), HD(-0.4, 0.0, 0.02), Lg(0.32, -0.32, 0.0), R(0.32, 0.12, 0.42, 0.4), {"shake": 0.3}])],
		[t_drop - t + 0.48, M([H(0.04, -0.6, -0.15), B(-0.4), HD(-0.3), Lg(0.3, -0.22, 0.0), {"shake": 0.0}])],
		[1.02, M([H(0.0, -0.46, 0.02), B(0.32), C(0.1), HD(0.18), Lg(0.25, 0.25, 0.02), R(0.35, -0.3, 0.4, 0.3), {"ev": "grunt", "face": "determined"}]), "s"],
		[1.18, M([H(0, -0.2, 0.0), B(0.18), HD(0.1, 0.2), L(0.32, -0.6, 0.2, 0.3), R(0.3, -0.55, 0.28, 0.3), {"curl": 0.7, "curl_l": 0.7}])],
		[1.4, M([tense(p.person), HD(0.06, 0.35, 0.05), {"face": "grin"}])],
	])
	return {"through": t_drop + 0.22, "out": t + 1.4}


# La brèche se referme sous son nez : Alice s'élance griffe tendue, les piques repoussent d'un
# coup devant elle ; elle s'arrête net, retire sa main piquée en secouant les doigts, recule.
static func alice_blocked(a: Performer, t: float, x: float) -> void :
	var s: Vector3 = a.end_p
	var stop_at: Vector3 = Vector3(x * 0.92, 0.0, -0.85)
	var back: Vector3 = stop_at - Vector3(0.0, 0.0, 0.5)
	a.hold(t)
	a.turn(t, a.theta(t), "s")
	a.turn(t + 0.12, 0.0, "s")
	a.go(t + 0.3, stop_at, Vector3.ZERO)
	a.go(t + 0.62, back, Vector3.ZERO)
	a.hold(t + 0.8)
	run(a, t - 0.02, t + 0.8, {"stop": true, "first": 1, "no_upper": true, "cadence": 1.15, "seed": 79})
	keys(a, t, [
		[0.0, M([H(0, -0.18, 0.05), B(0.42), C(0.18), HD(0.3), R(0.4, 0.3, -0.3, 0.5), WR(-0.6), L(0.45, -0.45, 0.1, 0.5), {"curl": 0.0, "face": "angry", "ev": "roar"}])],
		[0.2, M([H(0, -0.16, 0.12), B(0.55), C(0.15), HD(0.45), R(0.05, 0.12, 0.96, 0.1), WR(-0.2), L(0.45, -0.3, -0.3, 0.5), {"curl": 0.05}])],
		[0.3, M([R(0.06, 0.14, 0.82, 0.1), B(0.5), {"ev": "hurt", "face": "pain", "shake": 0.7}]), "s"],
		[0.46, M([H(0, -0.12, -0.06), B(-0.08), C(-0.1), HD(0.2, 0.35, 0.1), Rt(0.12, -0.1, 0.32, 0.4), WR(0.9, 0.0, 0.4), L(0.45, -0.5, 0.2, 0.5), {"curl": 0.6, "shake": 0.4}])],
		[0.58, M([Rt(0.18, -0.12, 0.3, 0.4), WR(-0.5, 0.0, -0.4)])],
		[0.7, M([Rt(0.15, -0.1, 0.32, 0.4), WR(0.8, 0.0, 0.3), {"face": "angry"}])],
		[0.82, M([H(0, -0.1, 0), B(0.2), C(0.12), HD(0.12, 0.0, -0.1), claws(0.05), {"shake": 0.0}])],
	])
