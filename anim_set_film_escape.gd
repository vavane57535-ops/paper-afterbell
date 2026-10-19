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
		var cadence: float = _cadence(st, v_now) * cad_mul * (1.0 + 0.045 * n1(seed_value, count))
		var land: float = t + 1.0 / cadence
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
		_swing(p, sd, off, s.at, float(next.land), next.at, maxf(v, float(next.speed)), push, j, st, seed_value)
	if bool(opts.get("no_upper", false)): return {"steps": steps}
	# 4) bassin et haut du corps, une pose par appui
	var lean_base: float = float(st.lean) * float(opts.get("lean", 1.0))
	var arms: float = float(st.arms) * float(opts.get("arms", 1.0))
	var bob: float = float(st.bob) * leg
	for j: int in range(steps.size()):
		var s: Dictionary = steps[j]
		if bool(s.get("settle", false)): continue
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
