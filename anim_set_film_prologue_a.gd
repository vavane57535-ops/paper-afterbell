extends "res://anim_pose.gd"

# Prologue « Yiero », actes I à III (0 → 104 s, lot prologue_a) : chaque mouvement de Simon et
# d'Ashura est un clip écrit pour son plan (aucun clip du jeu, aucune locomotion automatique).
# - Les pas sont posés à des endroits précis de la dimension : les pieds d'appui restent fixes (clés
#   linéaires calées sur la trajectoire que film_prologue_a.gd donne au personnage), le pied libre
#   décrit un arc (talon qui décolle, pointe, attaque talon), le bassin, le buste, les bras et la tête
#   suivent avec du décalage.
# - Les clips sont propres à chaque rig : les positions en mètres sont converties avec les mesures du
#   modèle (RIG, relevées sur PaperVisual : portée de jambe, échelle, pieds au repos).
# - Le temps des clés est le temps du film (synchro musique) ; Clip le convertit en temps de clip en
#   tenant compte des ralentis (SLOW), comme le fait PaperPrologue._scaled().
# Le film (film_prologue_a.gd) lit les mêmes plans : trajectoires, orientations, appuis (ondes dans
# l'encre) et moments où chaque clip démarre.

const AnimClip = preload("res://anim_clip.gd")

const SLOW: Array = [[63.2, 63.9, 0.25], [79.0, 80.2, 0.2], [92.9, 93.4, 0.25]]

const RIG: Dictionary = {
	"Simon": {"reach": 0.911139, "scale": 0.767544, "foot_l": Vector3(-0.1425, 0.15586, 0.035625), "foot_r": Vector3(0.133594, 0.155859, 0.035625), "hip_y": 1.064297, "hip_x": 0.106875, "toe": 0.136239},
	"Ashura": {"reach": 0.864776, "scale": 0.745614, "foot_l": Vector3(-0.243224, 0.114758, -0.037701), "foot_r": Vector3(0.250444, 0.097185, 0.089592), "hip_y": 0.961632, "hip_x": 0.133182, "toe": 0.056956},
}


class Body:
	var who: String = ""
	var reach: float = 0.9
	var scale: float = 0.76
	var toe: float = 0.1
	var rest: Dictionary = {}
	var hip: Dictionary = {}

	func _init(person: String, rig: Dictionary) -> void :
		who = person
		reach = float(rig.reach);scale = float(rig.scale);toe = float(rig.toe)
		rest[-1] = rig.foot_l;rest[1] = rig.foot_r
		hip[-1] = Vector3( - float(rig.hip_x), float(rig.hip_y), 0.0);hip[1] = Vector3(float(rig.hip_x), float(rig.hip_y), 0.0)


# Un clip en cours d'écriture : clés au temps du film, converties en temps de clip à l'ajout.
class Clip:
	var start: float = 0.0
	var keys: Array = []

	func _init(film_start: float) -> void :
		start = film_start


static func scaled(t: float) -> float:
	var lost: float = 0.0
	for row: Array in SLOW:
		var a: float = float(row[0])
		var b: float = float(row[1])
		if t <= a: continue
		lost += (minf(t, b) - a) * (1.0 - float(row[2]))
	return t - lost

static func unscaled(s: float) -> float:
	var t: float = s
	for i: int in range(6):
		t += s - scaled(t)
	return t




static func at(k: Clip, t: float, pose: Dictionary, flag: String = "") -> void :
	var local: float = scaled(t) - scaled(k.start)
	if flag.is_empty(): k.keys.append([local, pose])
	else: k.keys.append([local, pose, flag])

static func finish(k: Clip, t_end: float, face: String, fade_in: float = 0.0) -> Dictionary:
	var keys: Array = k.keys.duplicate()
	keys.sort_custom( func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	return {"len": maxf(0.05, scaled(t_end) - scaled(k.start)), "in": fade_in, "out": 0.0, "face": face, "keys": keys}


# Pose complète d'un clip déjà écrit, échantillonnée à l'instant t du film (raccord entre deux clips).
static func pose_of(source: Dictionary, film_start: float, t: float) -> Dictionary:
	var clip: Dictionary = AnimClip.compile(source)
	var local: float = clampf(scaled(t) - scaled(film_start), 0.0, float(clip.len))
	var pose: Dictionary = {}
	for channel: String in clip.channels:
		pose[channel] = AnimClip.sample(clip.channels[channel], local, false, float(clip.len))
	for channel: String in clip.strings:
		if channel == "face":
			var face: String = AnimClip.sample_string(clip.strings[channel], local)
			if not face.is_empty(): pose[channel] = face
	return pose

# Démarre un clip à l'instant t en reprenant exactement la pose (et l'élan sur `carry` secondes) du
# clip précédent.
static func follow(k: Clip, previous: Dictionary, previous_start: float, carry: float = 0.0) -> void :
	at(k, k.start, M([base(), pose_of(previous, previous_start, k.start)]))
	if carry > 0.0: at(k, k.start + carry, pose_of(previous, previous_start, k.start + carry))


static func base() -> Dictionary:
	return {"plant": 1.0, "gait": 0.0, "gsnap": 0.0, "shake": 0.0, "jaw": 0.0, "chatter": 0.0, "turn": 0.0, "sq": 1.0, "el_l": 0.0, "el_r": 0.0, "tf_l": 0.0, "tf_r": 0.0, "gr_l": 0.0, "gr_r": 0.0}




# Conversions mètres → unités de clip (repère local du personnage : x à droite, y en haut, z vers
# l'arrière ; le personnage regarde vers -z).
static func foot_offset(b: Body, side: int, local: Vector3, pitch: float = 0.0) -> Vector3:
	var r: Vector3 = b.rest[side]
	var raise: float = b.toe * sin( - pitch) if pitch < 0.0 else 0.0
	var model: Vector3 = Vector3(local.x / b.scale, r.y + local.y / b.scale + raise, local.z / b.scale)
	return (model - r) / b.reach

static func hips_offset(b: Body, local: Vector3) -> Vector3:
	return local / b.scale / b.reach

# Hauteur de bassin (mètres, relative) la plus haute qui laisse les deux jambes atteindre leurs pieds
# (extension maximale `ext` de la jambe) : évite les pieds qui flottent quand le pas s'allonge.
static func fit_hips(b: Body, hips: Vector3, feet: Dictionary, ext: float = 0.965) -> float:
	var y: float = hips.y
	for side: int in [-1, 1]:
		if not feet.has(side): continue
		var foot: Vector3 = feet[side]
		var r: Vector3 = b.rest[side]
		var hip_joint: Vector3 = b.hip[side] + Vector3(hips.x, 0.0, hips.z) / b.scale
		var ankle: Vector3 = Vector3(foot.x / b.scale, r.y + foot.y / b.scale, foot.z / b.scale)
		var flat: float = Vector2(hip_joint.x - ankle.x, hip_joint.z - ankle.z).length()
		var leg: float = b.reach * ext
		if flat >= leg: flat = leg * 0.98
		var top: float = ankle.y + sqrt(leg * leg - flat * flat)
		y = minf(y, (top - b.hip[side].y) * b.scale)
	return y

static func to_local(offset: Vector3, yaw: float) -> Vector3:
	return offset.rotated(Vector3.UP, - yaw)

static func yaw_of(direction: Vector3) -> float:
	return atan2( - direction.x, - direction.z)

static func path_at(path: Array, t: float) -> Vector3:
	if path.is_empty(): return Vector3.ZERO
	if t <= float(path[0][0]): return path[0][1]
	for i: int in range(1, path.size()):
		if t <= float(path[i][0]):
			var a: Array = path[i - 1]
			var b: Array = path[i]
			return (a[1] as Vector3).lerp(b[1], clampf((t - float(a[0])) / maxf(0.0001, float(b[0]) - float(a[0])), 0.0, 1.0))
	return path[path.size() - 1][1]




# Marche (ou course lente) écrite pas à pas.
# w = {
#   "yaw": orientation du personnage (rad, comme Node3D.rotation.y),
#   "feet": [Vector3 gauche, Vector3 droite] : appuis de départ (repère du film, mètres),
#   "steps": [[t_pose, côté, Vector3 appui], ...] (temps du film ; côté -1 gauche, 1 droit),
#   "lift_at": {index du pas: t_levée} (facultatif), "ds": part de double appui (0,2),
#   "crouch", "bob", "sway", "lean", "twist", "lift" (mètres / radians),
#   "arms": [[t0, t1, amplitude]] fenêtres où les bras balancent, "arm": {"out", "up", "fwd", "flare"},
#   "chest": [[t, lacet ajouté], ...] lacet du buste écrit à la main (regards), "end": fin de la marche }
# Écrit les pieds, le bassin, le buste et le balancement des bras dans k ; renvoie
# {"root": [[t, Vector3]], "contacts": [[t, côté, Vector3]]}.
static func walk(b: Body, k: Clip, w: Dictionary) -> Dictionary:
	var yaw: float = float(w.get("yaw", PI))
	var steps: Array = w.steps
	var start: float = float(w.get("start", k.start))
	var ds: float = float(w.get("ds", 0.2))
	var lift: float = float(w.get("lift", 0.075))
	var crouch: float = float(w.get("crouch", -0.02))
	var bob: float = float(w.get("bob", 0.018))
	var sway: float = float(w.get("sway", 0.22))
	var lean: float = float(w.get("lean", 0.05))
	var twist: float = float(w.get("twist", 0.07))
	var heel: float = float(w.get("heel", 0.5))
	var lift_at: Dictionary = w.get("lift_at", {})
	var plants: Dictionary = {-1: [[start - 10.0, 0.0, w.feet[0]]], 1: [[start - 10.0, 0.0, w.feet[1]]]}
	var current: Dictionary = {-1: w.feet[0], 1: w.feet[1]}
	var root: Array = [[start, (current[-1] as Vector3).lerp(current[1], 0.5)]]
	var contacts: Array = []
	var previous_contact: float = start
	for j: int in range(steps.size()):
		var step: Array = steps[j]
		var tc: float = float(step[0])
		var side: int = int(step[1])
		var spot: Vector3 = step[2]
		var tl: float = previous_contact + ds * (tc - previous_contact) if j > 0 else tc - float(w.get("first_swing", 0.42))
		if lift_at.has(j): tl = float(lift_at[j])
		var row: Array = plants[side][plants[side].size() - 1]
		row[1] = tl
		plants[side].append([tc, 0.0, spot])
		current[side] = spot
		var mid: Vector3 = (current[-1] as Vector3).lerp(current[1], 0.5)
		var from: Array = root[root.size() - 1]
		var span: float = tc - float(from[0])
		# Démarrage et arrêt amortis : clés intermédiaires (le pied d'appui suit les mêmes clés).
		if j == 0 and span > 0.05:
			for u: float in [0.3, 0.55, 0.8]:
				root.append([float(from[0]) + span * u, (from[1] as Vector3).lerp(mid, u * u)])
		elif j == steps.size() - 1 and span > 0.05:
			for u: float in [0.3, 0.55, 0.8]:
				root.append([float(from[0]) + span * u, (from[1] as Vector3).lerp(mid, 1.0 - (1.0 - u) * (1.0 - u))])
		root.append([tc, mid])
		contacts.append([tc, side, spot])
		previous_contact = tc
	var end: float = float(w.get("end", previous_contact + 0.6))
	for side: int in [-1, 1]:
		var last: Array = plants[side][plants[side].size() - 1]
		last[1] = end + 10.0
	var times: Array = []
	for row: Array in root: times.append(float(row[0]))

	# Pieds : appuis (clés linéaires aux mêmes instants que la trajectoire) puis arcs de pas.
	for side: int in [-1, 1]:
		var list: Array = plants[side]
		var key_pos: String = "foot_l" if side < 0 else "foot_r"
		var key_pitch: String = "fp_l" if side < 0 else "fp_r"
		for p: int in range(list.size()):
			var land: float = maxf(float(list[p][0]), start)
			var leave: float = minf(float(list[p][1]), end)
			var spot: Vector3 = list[p][2]
			var stance: float = leave - land
			var heel_from: float = land + stance * (1.0 - 0.38 * heel) if p < list.size() - 1 else INF
			var marks: Array = [land]
			for t: float in times:
				if t > land + 0.001 and t < leave - 0.001: marks.append(t)
			if heel_from < leave - 0.02:
				marks.append(heel_from)
			marks.append(leave)
			marks.sort()
			for t: float in marks:
				var pitch: float = 0.0
				if t >= heel_from and p < list.size() - 1: pitch = - heel * 0.62 * smoothstep(heel_from, leave, t)
				var local: Vector3 = to_local(spot - path_at(root, t), yaw)
				local.y = 0.0
				at(k, t, {key_pos: foot_offset(b, side, local, pitch)}, "" if is_equal_approx(t, leave) else "l")
			if p > 0:
				at(k, land, {key_pitch: 0.16 * heel})
				at(k, minf(land + 0.11, leave), {key_pitch: 0.0})
			else:
				at(k, land, {key_pitch: 0.0})
			if p < list.size() - 1:
				at(k, heel_from if heel_from < leave else leave, {key_pitch: 0.0})
				at(k, leave, {key_pitch: - heel * 0.62})
				# Arc du pied libre jusqu'au prochain appui.
				var arrive: float = float(list[p + 1][0])
				var next: Vector3 = list[p + 1][2]
				var swing: float = arrive - leave
				var height: float = lift * clampf(spot.distance_to(next) / 0.55, 0.45, 1.6)
				for row: Array in [[0.28, 0.16, 0.72, - heel * 0.5], [0.55, 0.55, 1.0, - heel * 0.05], [0.82, 0.93, 0.42, 0.22]]:
					var u: float = float(row[0])
					var t: float = leave + swing * u
					var world: Vector3 = spot.lerp(next, float(row[1]))
					var local: Vector3 = to_local(world - path_at(root, t), yaw)
					local.y = height * float(row[2])
					at(k, t, {key_pos: foot_offset(b, side, local, float(row[3]) * 0.0)})
					at(k, t, {key_pitch: float(row[3])})

	# Bassin : plus bas juste après chaque appui, plus haut au milieu de l'appui ; déporté vers le pied
	# porteur ; rotation qui accompagne la jambe qui avance ; buste en contre-rotation.
	var chest_add: Array = w.get("chest", [])
	var arms: Array = w.get("arms", [])
	var arm: Dictionary = w.get("arm", {})
	var marks: Array = []
	for c: int in range(contacts.size()):
		var tc: float = float(contacts[c][0])
		var next_tc: float = float(contacts[c + 1][0]) if c + 1 < contacts.size() else tc + 0.6
		marks.append([tc + 0.09 * (next_tc - tc), c, "low"])
		if c + 1 < contacts.size(): marks.append([tc + 0.55 * (next_tc - tc), c, "high"])
	marks.push_front([start, -1, "rest"])
	marks.append([end, contacts.size() - 1, "rest"])
	for row: Array in marks:
		var t: float = float(row[0])
		var c: int = int(row[1])
		var kind: String = str(row[2])
		var feet_now: Dictionary = {}
		for side: int in [-1, 1]:
			var local: Vector3 = to_local(_foot_world(plants[side], t) - path_at(root, t), yaw)
			local.y = 0.0
			feet_now[side] = local
		var support: int = int(contacts[c][1]) if c >= 0 else 0
		var moving: float = 0.0 if kind == "rest" else 1.0
		var hips: Vector3 = Vector3.ZERO
		hips.y = crouch * (0.4 + 0.6 * moving) + (- bob if kind == "low" else (bob * 0.5 if kind == "high" else 0.0))
		if kind == "high": hips.x = (feet_now[support] as Vector3).x * sway
		hips.y = fit_hips(b, hips, feet_now)
		var turn_body: float = (twist * float(support) if kind == "low" else 0.0) * moving
		var roll: float = (0.035 * float(support) if kind == "high" else 0.0) * moving
		at(k, t, {"hips": hips_offset(b, hips), "body": Vector3( - lean * (0.3 + 0.7 * moving), turn_body, roll)})
		at(k, t, {"chest": Vector3(0.012 * moving, - turn_body * 1.15 + _curve(chest_add, t), 0.0)})
	# Balancement des bras : bras opposé à la jambe qui avance, avec un léger retard.
	var out: float = float(arm.get("out", 0.12))
	var up: float = float(arm.get("up", -0.93))
	var fwd: float = float(arm.get("fwd", 0.06))
	var flare: float = float(arm.get("flare", 0.0))
	for c: int in range(contacts.size()):
		var tc: float = float(contacts[c][0])
		var amp: float = _window(arms, tc)
		if amp <= 0.0: continue
		var support: int = int(contacts[c][1])
		var t: float = tc + float(arm.get("lag", 0.07))
		var swing_l: float = amp * float(support)
		at(k, t, M([L(out, up + absf(swing_l) * 0.12, fwd + swing_l, flare), R(out, up + absf(swing_l) * 0.12, fwd - swing_l, flare)]))
	return {"root": root, "contacts": contacts}

static func _foot_world(list: Array, t: float) -> Vector3:
	for p: int in range(list.size()):
		var land: float = float(list[p][0])
		var leave: float = float(list[p][1])
		if t < land:
			if p == 0: return list[0][2]
			var from: Vector3 = list[p - 1][2]
			var u: float = clampf((t - float(list[p - 1][1])) / maxf(0.001, land - float(list[p - 1][1])), 0.0, 1.0)
			return from.lerp(list[p][2], smoothstep(0.0, 1.0, u))
		if t <= leave: return list[p][2]
	return list[list.size() - 1][2]

static func _curve(keys: Array, t: float) -> float:
	if keys.is_empty(): return 0.0
	if t <= float(keys[0][0]): return float(keys[0][1])
	for i: int in range(1, keys.size()):
		if t <= float(keys[i][0]):
			var u: float = (t - float(keys[i - 1][0])) / maxf(0.001, float(keys[i][0]) - float(keys[i - 1][0]))
			return lerpf(float(keys[i - 1][1]), float(keys[i][1]), smoothstep(0.0, 1.0, u))
	return float(keys[keys.size() - 1][1])

static func _window(windows: Array, t: float) -> float:
	for row: Array in windows:
		if t >= float(row[0]) and t <= float(row[1]): return float(row[2])
	return 0.0




static var _plans: Dictionary = {}

# Plans complets par personnage (calculés une fois) : {"clips": [[nom, t_début, source]], "path":
# [[t, Vector3]], "yaw": [[t, rad]], "contacts": [[t, côté, Vector3]]}.
static func plan(person: String) -> Dictionary:
	if _plans.has(person): return _plans[person]
	var result: Dictionary = {"clips": [], "path": [], "yaw": [], "contacts": []}
	var b: Body = Body.new(person, RIG[person])
	if person == "Simon": _simon(b, result)
	else: _ashura(b, result)
	_plans[person] = result
	return result

static func add(c: Dictionary) -> void :
	for person: String in RIG:
		for row: Array in plan(person).clips:
			c[str(row[0])] = row[2]

static func _push_root(result: Dictionary, root: Array) -> void :
	var path: Array = result.path
	for row: Array in root:
		var t: float = float(row[0])
		if not path.is_empty() and t <= float(path[path.size() - 1][0]) + 0.0001:
			path[path.size() - 1] = [t, row[1]]
		else:
			path.append([t, row[1]])

static func _push_clip(result: Dictionary, clip_name: String, k: Clip, t_end: float, face: String, fade_in: float = 0.0) -> Dictionary:
	var source: Dictionary = finish(k, t_end, face, fade_in)
	result.clips.append([clip_name, k.start, source])
	return source




static func _simon(b: Body, r: Dictionary) -> void :
	pass

static func _ashura(b: Body, r: Dictionary) -> void :
	pass
