extends "res://anim_pose.gd"

# Outils d'écriture des clips de l'écran titre (anim_set_menu.gd).
#
# Take : une prise (un clip) qu'on écrit pose par pose. Chaque pose est datée et répartie
# sur ses canaux avec un léger décalage selon un « profil » de chevauchement :
#   follow : le bassin part, le buste suit, la tête puis les mains et les doigts arrivent après ;
#   lead   : le regard et le visage partent d'abord (on regarde avant de bouger) ;
#   heavy  : comme follow, en plus traînant (corps lourd, fatigue, peur qui retombe) ;
#   snap   : réflexe, presque tout ensemble ; sync : tout au même instant.
# Drapeaux : "" (passe sans s'arrêter), "s" (s'arrête net sur la clé), "h" (tient jusqu'à la clé
# suivante), "l" (linéaire). Les canaux non repris gardent leur dernière valeur.

const CHANNEL_GROUP: Dictionary = {
	"hips": "root", "body": "root", "foot_l": "root", "foot_r": "root", "fp_l": "root", "fp_r": "root",
	"turn": "root", "plant": "root", "gsnap": "root", "gclamp": "root", "sq": "root", "gait": "root", "feet": "root",
	"l_leg": "root", "r_leg": "root", "l_knee": "root", "r_knee": "root", "l_ank": "root", "r_ank": "root",
	"chest": "chest", "l_clav": "chest", "r_clav": "chest",
	"head": "head",
	"ik_l": "arms", "ik_r": "arms", "el_l": "arms", "el_r": "arms", "tf_l": "arms", "tf_r": "arms", "gr_l": "arms", "gr_r": "arms",
	"l_hand": "arms", "r_hand": "arms", "l_arm": "arms", "r_arm": "arms", "l_elb": "arms", "r_elb": "arms", "ikw_l": "arms", "ikw_r": "arms",
	"curl": "fingers", "curl_l": "fingers", "gesture": "fingers",
	"face": "face", "jaw": "face", "chatter": "face", "shake": "face",
	"ev": "cue", "fx": "cue", "prop": "cue",
}
const PROFILES: Dictionary = {
	"follow": {"root": 0.0, "chest": 0.035, "head": 0.08, "arms": 0.06, "fingers": 0.11, "face": 0.0, "cue": 0.0},
	"lead": {"root": 0.0, "chest": -0.03, "head": -0.1, "arms": 0.03, "fingers": 0.08, "face": -0.12, "cue": 0.0},
	"heavy": {"root": 0.0, "chest": 0.06, "head": 0.14, "arms": 0.1, "fingers": 0.16, "face": 0.02, "cue": 0.0},
	"snap": {"root": 0.0, "chest": 0.015, "head": 0.035, "arms": 0.025, "fingers": 0.05, "face": 0.0, "cue": 0.0},
	"sync": {"root": 0.0, "chest": 0.0, "head": 0.0, "arms": 0.0, "fingers": 0.0, "face": 0.0, "cue": 0.0},
}

class Take:
	var length: float = 1.0
	var face: String = "neutral"
	var rows: Array = []
	var state: Dictionary = {}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var lag_scale: float = 1.0
	# Mesures du squelette de l'acteur (rig_of) et piste de sa racine dans le décor (root_sample).
	var rig: Dictionary = {}
	var root: Array = []
	var contacts: Array = []
	var _order: int = 0

	func _init(clip_length: float, base_face: String = "neutral", seed_value: int = 1, actor_rig: Dictionary = {}) -> void :
		length = clip_length
		face = base_face
		rng.seed = seed_value
		rig = actor_rig

	# Piste de la racine : [[t, position au sol (repère de la scène), lacet en degrés, drapeau], ...].
	func path(track: Array) -> Take:
		root = track
		return self

	func _root_at(t: float) -> Array:
		if root.is_empty(): return [Vector3.ZERO, 0.0]
		return root_sample(root, t)

	static func root_sample(track: Array, t: float) -> Array:
		var n: int = track.size()
		if n == 0: return [Vector3.ZERO, 0.0]
		if n == 1 or t <= float(track[0][0]): return [track[0][1], deg_to_rad(float(track[0][2]))]
		if t >= float(track[n - 1][0]): return [track[n - 1][1], deg_to_rad(float(track[n - 1][2]))]
		var i: int = 0
		while i < n - 2 and t >= float(track[i + 1][0]): i += 1
		var ka: Array = track[i]
		var kb: Array = track[i + 1]
		var ta: float = float(ka[0])
		var tb: float = float(kb[0])
		var span: float = maxf(tb - ta, 0.0001)
		var u: float = clampf((t - ta) / span, 0.0, 1.0)
		var pa: Vector3 = ka[1]
		var pb: Vector3 = kb[1]
		var ya: float = float(ka[2])
		var yb: float = float(kb[2])
		if _root_flag(ka) == "l": return [pa.lerp(pb, u), deg_to_rad(lerpf(ya, yb, u))]
		var ma: Vector3 = Vector3.ZERO
		var mb: Vector3 = Vector3.ZERO
		var na: float = 0.0
		var nb: float = 0.0
		if i > 0 and _root_flag(ka) != "s":
			var kp: Array = track[i - 1]
			var gap: float = maxf(tb - float(kp[0]), 0.001)
			ma = (pb - (kp[1] as Vector3)) / gap
			na = (yb - float(kp[2])) / gap
		if i + 2 < n and _root_flag(kb) != "s":
			var kn: Array = track[i + 2]
			var gap2: float = maxf(float(kn[0]) - ta, 0.001)
			mb = ((kn[1] as Vector3) - pa) / gap2
			nb = (float(kn[2]) - ya) / gap2
		var u2: float = u * u
		var u3: float = u2 * u
		var h00: float = 2.0 * u3 - 3.0 * u2 + 1.0
		var h10: float = u3 - 2.0 * u2 + u
		var h01: float = -2.0 * u3 + 3.0 * u2
		var h11: float = u3 - u2
		var pos: Vector3 = pa * h00 + ma * (h10 * span) + pb * h01 + mb * (h11 * span)
		var yaw: float = ya * h00 + na * (h10 * span) + yb * h01 + nb * (h11 * span)
		return [pos, deg_to_rad(yaw)]

	static func _root_flag(key: Array) -> String:
		return str(key[3]) if key.size() > 3 else ""

	# Pied posé (repère de la scène, au sol) pour un décalage de canal donné, racine à l'instant t.
	func foot_world(side: int, t: float, offset: Vector3) -> Vector3:
		var at: Array = _root_at(t)
		var feet: Dictionary = rig.get("feet", {-1: Vector3(-0.15, 0.15, 0.0), 1: Vector3(0.15, 0.15, 0.0)})
		var local: Vector3 = (feet[side] as Vector3) + offset * float(rig.get("leg", 0.9))
		var world: Vector3 = (at[0] as Vector3) + (local * float(rig.get("scale", 0.77))).rotated(Vector3.UP, float(at[1]))
		world.y = 0.0
		return world

	# Canal de pied (décalage, en longueurs de jambe) qui place la cheville sur un point du décor.
	func foot_channel(side: int, t: float, world: Vector3, height: float = 0.0) -> Vector3:
		var at: Array = _root_at(t)
		var scale: float = float(rig.get("scale", 0.77))
		var feet: Dictionary = rig.get("feet", {-1: Vector3(-0.15, 0.15, 0.0), 1: Vector3(0.15, 0.15, 0.0)})
		var local: Vector3 = (world - (at[0] as Vector3)).rotated(Vector3.UP, - float(at[1])) / scale
		local.y = (feet[side] as Vector3).y + height / scale
		return (local - (feet[side] as Vector3)) / float(rig.get("leg", 0.9))

	# Pas plantés pendant que la racine se déplace (piste « path ») : chaque pas [côté, décollage, pose,
	# {options}] soulève le pied et le repose sous la hanche de la racine au milieu de son appui suivant
	# (au dernier appui : sous la racine à l'arrêt, dans la position de repos « stance »). Le pied posé ne
	# bouge plus dans le décor : la piste est échantillonnée serrée et recalculée dans le repère de l'acteur.
	# Options d'un pas : "at" (point du décor imposé), "shift" (décalage de canal en plus), "lift" (hauteur
	# du pas en m), "ref" (0..1, instant de l'appui qui sert de référence).
	# Options : "from", "to" (fenêtre), "dt" (pas d'échantillonnage), "stance" ({-1: canal, 1: canal} de fin),
	# "bob" (descente du bassin à la pose, en longueurs de jambe), "sway" (report latéral), "hips" (bassin de base).
	func steps(list: Array, opts: Dictionary = {}) -> Take:
		var t_start: float = float(opts.get("from", float(root[0][0]) if not root.is_empty() else 0.0))
		var t_end: float = float(opts.get("to", float(root[root.size() - 1][0]) if not root.is_empty() else length))
		var stance: Dictionary = opts.get("stance", {})
		var plants: Dictionary = {-1: [], 1: []}
		for side: int in [-1, 1]:
			var channel: String = "foot_l" if side < 0 else "foot_r"
			var now: Vector3 = state.get(channel, Vector3.ZERO)
			if not stance.has(side): stance[side] = now
			plants[side].append({"land": t_start - 1.0, "lift": INF, "at": foot_world(side, t_start, now), "extra": {}})
		var order: Array = list.duplicate()
		order.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) < float(b[1]))
		for s: Array in order:
			var side: int = int(s[0])
			var extra: Dictionary = s[3] if s.size() > 3 else {}
			(plants[side].back() as Dictionary)["lift"] = float(s[1])
			plants[side].append({"land": float(s[2]), "lift": INF, "at": null, "extra": extra})
		for side: int in [-1, 1]:
			var line: Array = plants[side]
			for j: int in range(1, line.size()):
				var p: Dictionary = line[j]
				var extra: Dictionary = p.extra
				if extra.has("at"):
					p.at = extra.at
					continue
				var last: bool = is_inf(float(p.lift))
				var ref: float = t_end if last else lerpf(float(p.land), float(p.lift), float(extra.get("ref", 0.5)))
				p.at = foot_world(side, ref, (stance[side] as Vector3) + (extra.get("shift", Vector3.ZERO) as Vector3))
		var times: Array = []
		var dt: float = float(opts.get("dt", 1.0 / 20.0))
		var t: float = t_start
		while t < t_end - 0.0001:
			times.append(t)
			t += dt
		times.append(t_end)
		for side: int in [-1, 1]:
			for p: Dictionary in plants[side]:
				for mark: float in [float(p.land), float(p.land) + 0.06, float(p.land) + 0.13, float(p.lift) - 0.13, float(p.lift) - 0.05, float(p.lift)]:
					if is_finite(mark) and mark > t_start and mark < t_end: times.append(mark)
		times.sort()
		var toe: float = float(rig.get("toe", 0.08)) * float(rig.get("scale", 0.77))
		var previous: float = -INF
		for when: float in times:
			if when - previous < 0.012: continue
			previous = when
			var pose: Dictionary = {}
			for side: int in [-1, 1]:
				var sample: Array = _foot_sample(plants[side], when, toe)
				pose["foot_l" if side < 0 else "foot_r"] = foot_channel(side, when, sample[0], float(sample[1]))
				pose["fp_l" if side < 0 else "fp_r"] = sample[2]
			key(when, pose)
		# Bassin : descend à chaque pose de pied, passe au-dessus du pied d'appui.
		var bob: float = float(opts.get("bob", 0.0))
		var sway: float = float(opts.get("sway", 0.0))
		if bob > 0.0 or sway > 0.0:
			var base: Vector3 = opts.get("hips", state.get("hips", Vector3.ZERO))
			var lands: Array = []
			for side: int in [-1, 1]:
				for j: int in range(1, (plants[side] as Array).size()):
					var p: Dictionary = plants[side][j]
					lands.append([float(p.land), side, float(p.lift) if is_finite(float(p.lift)) else t_end])
			lands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
			for land: Array in lands:
				var at_t: float = land[0]
				var mid: float = minf(at_t + (float(land[2]) - at_t) * 0.45, t_end)
				var side_x: float = float(land[1]) * sway
				key(at_t + 0.04, {"hips": base + Vector3(side_x * 0.5, - bob, 0.0)})
				key(mid, {"hips": base + Vector3(side_x, bob * 0.35, 0.0)})
			key(t_end, {"hips": base}, "s")
		contacts.clear()
		for side: int in [-1, 1]:
			for p: Dictionary in plants[side]: contacts.append([side, float(p.land), float(p.lift)])
		return self

	# Pied du côté donné à l'instant t : [point au sol, hauteur de la cheville au-dessus du repos, inclinaison].
	func _foot_sample(line: Array, t: float, toe: float) -> Array:
		for j: int in range(line.size()):
			var p: Dictionary = line[j]
			var lift: float = float(p.lift)
			if t <= lift or j == line.size() - 1:
				if j > 0 and t < float(p.land):
					# En l'air entre l'appui précédent et celui-ci.
					var a: Dictionary = line[j - 1]
					var t0: float = float(a.lift)
					var t1: float = float(p.land)
					var u: float = clampf((t - t0) / maxf(t1 - t0, 0.001), 0.0, 1.0)
					var from: Vector3 = a.at
					var to: Vector3 = p.at
					var dist: float = Vector2(to.x - from.x, to.z - from.z).length()
					var extra: Dictionary = p.extra
					var high: float = float(extra.get("lift", clampf(dist * 0.3, 0.035, 0.11)))
					var push: float = clampf(dist * 1.1, 0.05, 0.5)
					var strike: float = clampf(dist * 0.6, 0.0, 0.28)
					var s: float = u * u * (3.0 - 2.0 * u)
					var spot: Vector3 = from.lerp(to, s)
					var height: float = high * sin(PI * pow(u, 0.85)) + toe * sin(push) * (1.0 - u) * 0.9
					var pitch: float = lerpf(- push, 0.06, u / 0.5) if u < 0.5 else lerpf(0.06, strike, (u - 0.5) / 0.5)
					return [spot, height, pitch]
				# Posé : déroulé du talon après la pose, talon qui se lève avant de décoller.
				var pitch_on: float = 0.0
				var lift_h: float = 0.0
				var land: float = float(p.land)
				if j > 0 and t < land + 0.13:
					var prev_at: Vector3 = (line[j - 1] as Dictionary).at
					var d: float = Vector2((p.at as Vector3).x - prev_at.x, (p.at as Vector3).z - prev_at.z).length()
					pitch_on = clampf(d * 0.6, 0.0, 0.28) * (1.0 - smoothstep(land, land + 0.13, t))
				if is_finite(lift) and t > lift - 0.13 and j + 1 < line.size():
					var next_at: Vector3 = (line[j + 1] as Dictionary).at
					var d2: float = Vector2(next_at.x - (p.at as Vector3).x, next_at.z - (p.at as Vector3).z).length()
					var push2: float = clampf(d2 * 1.1, 0.05, 0.5)
					var w: float = smoothstep(lift - 0.13, lift, t)
					pitch_on = - push2 * w
					lift_h = toe * sin(push2 * w) * 0.9
				return [p.at, lift_h, pitch_on]
		var tail: Dictionary = line[line.size() - 1]
		return [tail.at, 0.0, 0.0]

	# Pas sur place (racine immobile) : le pied part de sa position courante, décrit un arc et se pose
	# sur « to » (décalage de canal) ; déroulé du pied au départ et à l'arrivée.
	func step(t_lift: float, t_land: float, side: int, to: Vector3, high: float = 0.05, push: float = 0.3) -> Take:
		var channel: String = "foot_l" if side < 0 else "foot_r"
		var pitch: String = "fp_l" if side < 0 else "fp_r"
		var from: Vector3 = state.get(channel, Vector3.ZERO)
		var leg: float = float(rig.get("leg", 0.9))
		var scale: float = float(rig.get("scale", 0.77))
		var h: float = high / (leg * scale)
		key(maxf(0.0, t_lift - 0.1), {channel: from, pitch: 0.0})
		key(t_lift, {channel: from + Vector3(0, push * 0.05, 0), pitch: - push})
		for i: int in range(1, 5):
			var u: float = float(i) / 5.0
			var s: float = u * u * (3.0 - 2.0 * u)
			var spot: Vector3 = from.lerp(to, s) + Vector3(0, h * sin(PI * pow(u, 0.85)), 0)
			key(lerpf(t_lift, t_land, u), {channel: spot, pitch: lerpf(- push, push * 0.5, u)})
		key(t_land, {channel: to, pitch: push * 0.4})
		key(t_land + 0.12, {channel: to, pitch: 0.0}, "s")
		return self

	# Pose datée, répartie sur ses canaux selon le profil de chevauchement.
	func at(t: float, pose: Dictionary, profile: String = "follow", flag: String = "") -> Take:
		var lags: Dictionary = PROFILES.get(profile, PROFILES.follow)
		for channel: String in pose:
			var group: String = CHANNEL_GROUP.get(channel, "root")
			var when: float = t + float(lags.get(group, 0.0)) * lag_scale
			if group == "cue" or group == "face": when = t + float(lags.get(group, 0.0))
			rows.append([clampf(when, 0.0, length), _order, channel, pose[channel], flag])
			_order += 1
			state[channel] = pose[channel]
		return self

	# Clé brute, sans chevauchement.
	func key(t: float, pose: Dictionary, flag: String = "") -> Take:
		return at(t, pose, "sync", flag)

	# Pose relative à l'état courant (valeurs ajoutées à la dernière pose écrite).
	func rel(t: float, delta: Dictionary, profile: String = "follow", flag: String = "") -> Take:
		var pose: Dictionary = {}
		for channel: String in delta:
			var base: Variant = state.get(channel, null)
			var change: Variant = delta[channel]
			if base == null or change is String: pose[channel] = change
			elif base is Vector3 and (change is float or change is int): pose[channel] = (base as Vector3) + Vector3(float(change), 0.0, 0.0)
			elif (base is float or base is int) and change is Vector3: pose[channel] = Vector3(float(base), 0.0, 0.0) + (change as Vector3)
			else: pose[channel] = base + change
		return at(t, pose, profile, flag)

	# Tenue vivante : le corps ne se fige jamais (respiration, poids, tête qui dérive).
	func hold(t0: float, t1: float, amount: float = 1.0, profile: String = "heavy") -> Take:
		var span: float = t1 - t0
		if span < 0.7: return self
		var count: int = maxi(1, floori(span / 1.05))
		var base: Dictionary = {}
		for channel: String in ["hips", "chest", "head"]:
			if state.has(channel): base[channel] = state[channel]
		for i: int in range(count):
			var t: float = t0 + span * (float(i) + 0.55 + rng.randf_range(-0.12, 0.12)) / float(count + 0.35)
			var pose: Dictionary = {}
			if base.has("chest"): pose["chest"] = (base.chest as Vector3) + Vector3(rng.randf_range(-0.02, 0.025), rng.randf_range(-0.025, 0.025), rng.randf_range(-0.015, 0.015)) * amount
			if base.has("head"): pose["head"] = (base.head as Vector3) + Vector3(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.05, 0.05), rng.randf_range(-0.03, 0.03)) * amount
			if base.has("hips"): pose["hips"] = (base.hips as Vector3) + Vector3(rng.randf_range(-0.008, 0.008), rng.randf_range(-0.006, 0.004), 0.0) * amount
			at(t, pose, profile)
		var back: Dictionary = {}
		for channel: String in base: back[channel] = base[channel]
		at(t1, back, profile, "s")
		return self

	func clip(extra: Dictionary = {}) -> Dictionary:
		var sorted: Array = rows.duplicate()
		sorted.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]) or (is_equal_approx(float(a[0]), float(b[0])) and int(a[1]) < int(b[1])))
		# Deux clés du même canal presque au même instant : la dernière écrite gagne.
		var last: Dictionary = {}
		var keep: Array = []
		for row: Array in sorted:
			var channel: String = row[2]
			if last.has(channel):
				var previous: Array = keep[int(last[channel])]
				if float(row[0]) - float(previous[0]) < 0.006 and not (row[3] is String):
					keep[int(last[channel])] = []
			last[channel] = keep.size()
			keep.append(row)
		var keys: Array = []
		var current_time: float = -1.0
		var current_flag: String = "?"
		var current: Dictionary = {}
		for row: Array in keep:
			if row.is_empty(): continue
			var time: float = snappedf(float(row[0]), 0.0001)
			var flag: String = row[4]
			if time != current_time or flag != current_flag or current.has(row[2]):
				if not current.is_empty(): keys.append([current_time, current, current_flag] if current_flag != "" else [current_time, current])
				current = {}
				current_time = time
				current_flag = flag
			current[row[2]] = row[3]
		if not current.is_empty(): keys.append([current_time, current, current_flag] if current_flag != "" else [current_time, current])
		var result: Dictionary = {"len": length, "in": 0.0, "out": 0.0, "face": face, "keys": keys}
		if not root.is_empty(): result["root"] = root
		result.merge(extra, true)
		return result


# --- Racine et squelette -----------------------------------------------------------

# Position et lacet (radians) de la racine d'un acteur à l'instant t sur sa piste
# [[t, position, lacet en degrés, drapeau], ...] : courbe d'Hermite (tangentes de Catmull-Rom,
# nulles aux extrémités et sur les clés « s »), segment linéaire après une clé « l ».
static func root_sample(track: Array, t: float) -> Array:
	return Take.root_sample(track, t)

# Mesures du squelette d'un acteur construit (PaperVisual) utiles aux clips : échelle du modèle,
# longueur de jambe, chevilles au repos (écart du perso compris), bras, épaules, pointe du pied.
static func rig_of(visual: Node3D) -> Dictionary:
	var style: Dictionary = visual.get("_style")
	var width: float = float(style.get("stance", 1.0))
	var rest: Dictionary = visual.get("_foot_rest")
	var feet: Dictionary = {}
	for side: int in [-1, 1]:
		var v: Vector3 = rest[side]
		feet[side] = Vector3(v.x * width, v.y, v.z)
	return {"name": str(visual.get("character_name")), "scale": visual.scale.x, "leg": float(visual.get("_leg_reach")), "feet": feet,
		"toe": float(visual.get("_toe_length")), "base": float(visual.get("_base_height")),
		"arm": (visual.get("_arm_length") as Dictionary).duplicate(), "shoulder": (visual.get("_shoulder_rest") as Dictionary).duplicate()}


# --- Raccourcis de pose ---------------------------------------------------------

static func TL(fwd: float, out: float = 0.0, yaw: float = 0.0) -> Dictionary:
	return {"l_leg": Vector3(fwd, yaw, - out)}

static func TR(fwd: float, out: float = 0.0, yaw: float = 0.0) -> Dictionary:
	return {"r_leg": Vector3(fwd, - yaw, out)}

static func KL(bend: float, ankle: float = 0.0) -> Dictionary:
	return {"l_knee": - bend, "l_ank": ankle}

static func KR(bend: float, ankle: float = 0.0) -> Dictionary:
	return {"r_knee": - bend, "r_ank": ankle}

static func F(mood: String) -> Dictionary:
	return {"face": mood}

static func CU(right: float, left: float = -1.0) -> Dictionary:
	return {"curl": right, "curl_l": right if left < 0.0 else left}

# Début de tout clip de menu : pieds plantés, pas d'allure du jeu, pas de rotation ajoutée.
static func start() -> Dictionary:
	return {"plant": 1.0, "gait": 0.0, "gsnap": 0.0, "turn": 0.0, "sq": 1.0, "jaw": 0.0, "shake": 0.0, "chatter": 0.0, "fp_l": 0.0, "fp_r": 0.0, "el_l": 0.0, "el_r": 0.0}

# Debout, bras le long du corps, mains détendues.
static func stand(width: float = 0.0) -> Dictionary:
	return M([rest(), start(), FL(0.02 + width, 0.0), FR(0.02 + width, 0.0), H(0, 0, 0), B(0.0), C(0.02), HD(0.0),
		L(0.2, -0.93, 0.04, 0.0), R(0.2, -0.93, 0.04, 0.0), WL(0.0), WR(0.0), CU(0.25)])
