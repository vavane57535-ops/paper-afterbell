extends "res://anim_pose.gd"

# Films « Alice · X rattrapé(e) » (ending_killer) et épilogue d'exécution (0.17) :
# chaque mouvement de corps est écrit clé par clé pour son plan. Aucun clip du
# jeu, aucune émote, aucun geste de capacité : film_alice_kill.gd coupe la
# démarche et l'attente du jeu, et les corps ne suivent que ces clés.
#
# Les clés sont en temps du film ; _film() les range dans un clip qui couvre
# tout le film (lancé à 0). Noms : fa_<victime> (la victime), fa_<victime>_alice
# (Alice dans ce film) et fa_epilogue_alice (épilogue d'exécution).
#
# Unités (anim_pose.gd) : pieds et bassin en longueurs de jambe, mains en
# longueurs de bras. Les trajets sont en mètres, dans le repère du film (x vers
# la « droite » du film, z vers la sortie). Un perso qui regarde vers +z a sa
# main droite du côté -x.
#
# Les pas (gait) sont écrits comme un animateur pose une course : contact,
# amorti, passage, envol, pour chaque pas, avec le pied d'appui fixé au sol
# (aucun glissement : il est recalculé à chaque sommet du trajet) et la hauteur
# du bassin bornée par la longueur de jambe (le pied touche toujours le sol).

# Squelette mesuré (tools/film_alice_lab.gd --fal-mode measure), en mètres : jambe (hanche →
# cheville), bras, hauteur de l'articulation de hanche, écart des hanches, pieds au repos
# [gauche, droite] (x × écart du style, y hauteur de cheville, z recul) et longueur d'orteil.
const RIG: Dictionary = {
	"Simon": {"leg": 0.699, "arm": 0.401, "hip": 0.817, "hip_x": 0.082, "feet": [Vector3(-0.109, 0.12, 0.027), Vector3(0.103, 0.12, 0.027)], "toe": 0.105},
	"Usayuko": {"leg": 0.675, "arm": 0.364, "hip": 0.962, "hip_x": 0.088, "feet": [Vector3(-0.202, 0.299, 0.065), Vector3(0.197, 0.29, -0.011)], "toe": 0.04},
	"Ashura": {"leg": 0.645, "arm": 0.469, "hip": 0.717, "hip_x": 0.099, "feet": [Vector3(-0.181, 0.086, -0.028), Vector3(0.187, 0.072, 0.067)], "toe": 0.043},
	"Lysia": {"leg": 0.864, "arm": 0.409, "hip": 0.968, "hip_x": 0.075, "feet": [Vector3(-0.078, 0.104, 0.117), Vector3(0.103, 0.099, 0.084)], "toe": 0.04},
	"Elly": {"leg": 0.783, "arm": 0.404, "hip": 0.924, "hip_x": 0.089, "feet": [Vector3(-0.148, 0.145, 0.022), Vector3(0.148, 0.145, 0.022)], "toe": 0.168},
	"Bleuette": {"leg": 0.683, "arm": 0.312, "hip": 0.782, "hip_x": 0.098, "feet": [Vector3(-0.143, 0.075, 0.0), Vector3(0.103, 0.1, 0.033)], "toe": 0.062},
	"Alice": {"leg": 0.863, "arm": 0.432, "hip": 1.008, "hip_x": 0.068, "feet": [Vector3(-0.068, 0.147, 0.055), Vector3(0.068, 0.147, 0.055)], "toe": 0.117},
}

# durée de chaque film « Alice · X rattrapé(e) »
const LENGTH: Dictionary = {"Bleuette": 12.0, "Elly": 12.0, "Simon": 12.0, "Ashura": 12.0, "Lysia": 12.0, "Usayuko": 12.0}
const EPILOGUE: float = 6.7


static func add(c: Dictionary) -> void :
	_bleuette(c)


# ------------------------------------------------------------------- OUTILS --

static func K(t: float, pose: Dictionary, flag: String = "") -> Array:
	return [t, pose] if flag.is_empty() else [t, pose, flag]


# Clip écrit en temps du film, lancé à `start` et tenu sur sa dernière pose
# jusqu'à `end` (pas de fondu : la pose de départ est complète).
static func _film(start: float, end: float, keys: Array, face: String = "") -> Dictionary:
	var shifted: Array = []
	for key: Array in keys:
		var copy: Array = key.duplicate()
		copy[0] = maxf(0.0, float(key[0]) - start)
		shifted.append(copy)
	shifted.sort_custom( func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	return {"len": maxf(0.05, end - start), "in": 0.0, "out": 0.0, "face": face, "at": start, "keys": shifted}


# Pose complète : tous les canaux que le moteur pourrait laisser à une autre
# couche (démarche, pose « en l'air », attente) sont tenus par le clip.
static func _zero() -> Dictionary:
	return {"plant": 1.0, "gait": 0.0, "gsnap": 0.0, "shake": 0.0, "jaw": 0.0, "chatter": 0.0, "turn": 0.0, "sq": 1.0,
		"el_l": 0.0, "el_r": 0.0, "fp_l": 0.0, "fp_r": 0.0, "hips": Vector3.ZERO, "body": Vector3.ZERO, "chest": Vector3.ZERO,
		"head": Vector3.ZERO, "foot_l": Vector3.ZERO, "foot_r": Vector3.ZERO, "feet": Vector3.ZERO,
		"l_clav": Vector3.ZERO, "r_clav": Vector3.ZERO, "l_hand": Vector3.ZERO, "r_hand": Vector3.ZERO,
		"l_leg": Vector3.ZERO, "r_leg": Vector3.ZERO, "l_knee": Vector3.ZERO, "r_knee": Vector3.ZERO, "l_ank": Vector3.ZERO, "r_ank": Vector3.ZERO,
		"ik_l": Vector3(-0.2, -0.9, -0.05), "ik_r": Vector3(0.2, -0.9, -0.05), "tf_l": 0.0, "tf_r": 0.0, "gr_l": 0.0, "gr_r": 0.0,
		"ikw_l": 1.0, "ikw_r": 1.0, "curl": 0.3, "curl_l": 0.3, "prop": ""}


# jambes en cinématique directe (avec "plant": 0) : cuisse vers l'avant, écart, rotation
static func TL(fwd: float, out: float = 0.0, yaw: float = 0.0) -> Dictionary:
	return {"l_leg": Vector3(fwd, yaw, - out)}

static func TR(fwd: float, out: float = 0.0, yaw: float = 0.0) -> Dictionary:
	return {"r_leg": Vector3(fwd, - yaw, out)}

static func KL(bend: float, ankle: float = 0.0) -> Dictionary:
	return {"l_knee": Vector3(- bend, 0.0, 0.0), "l_ank": Vector3(ankle, 0.0, 0.0)}

static func KR(bend: float, ankle: float = 0.0) -> Dictionary:
	return {"r_knee": Vector3(- bend, 0.0, 0.0), "r_ank": Vector3(ankle, 0.0, 0.0)}

# épaules : haussement (+) et avancée (+)
static func SH(left: float, right: float, fwd_l: float = 0.0, fwd_r: float = 0.0) -> Dictionary:
	return {"l_clav": Vector3(0.0, - fwd_l, - left), "r_clav": Vector3(0.0, fwd_r, right)}

static func FACE(mood: String) -> Dictionary:
	return {"face": mood}

# clignement : paupières fermées un instant, puis la mine `after`
static func blink(t: float, after: String, keys: Array, hold: float = 0.07) -> void :
	keys.append(K(t, FACE("asleep")))
	keys.append(K(t + hold, FACE(after)))

# bruit déterministe dans [-0.5, 0.5] (le film est le même chez tous les joueurs)
static func J(i: int, salt: float) -> float:
	return fposmod(sin(float(i) * 12.9898 + salt * 78.233) * 43758.5453, 1.0) - 0.5

static func leg_of(person: String) -> float:
	return float(RIG[person].leg)


# ---------------------------------------------------------------- TRAJETS --
# Un trajet : [[t, Vector3], ...] parcouru en segments linéaires. Le film le
# donne tel quel au corps (film_alice_kill.gd) et les pas s'en servent pour
# garder le pied d'appui immobile au sol.

static func at(path: Array, t: float) -> Vector3:
	if t <= float(path[0][0]): return path[0][1]
	for k: int in range(1, path.size()):
		if t <= float(path[k][0]):
			var a: Array = path[k - 1]
			var b: Array = path[k]
			return (a[1] as Vector3).lerp(b[1], (t - float(a[0])) / maxf(0.0001, float(b[0]) - float(a[0])))
	return path[path.size() - 1][1]

# droite du perso (repère du film) quand il regarde vers `dir`
static func side_of(dir: Vector3) -> Vector3:
	return Vector3(- dir.z, 0.0, dir.x)

static func rot_y(v: Vector3, angle: float) -> Vector3:
	return Vector3(v.x * cos(angle) + v.z * sin(angle), v.y, - v.x * sin(angle) + v.z * cos(angle))

# point du sol (repère du film) sous le pied `side` posé `ahead` m devant la racine, `width` m plus au dehors
static func plant_at(person: String, path: Array, dir: Vector3, t: float, side: int, ahead: float, width: float = 0.0) -> Vector3:
	var base: Vector3 = RIG[person].feet[0 if side < 0 else 1]
	return at(path, t) + dir * ahead + side_of(dir) * (base.x + float(side) * width)

# Valeur du canal foot_l / foot_r qui pose la cheville sur `spot` (repère du film, hauteur
# `lift` m au-dessus de la cheville au repos) quand la racine est en `root` et regarde vers
# `dir`, le corps tourné de `turn` (canal "turn", radians, vers la gauche).
static func foot_on(person: String, side: int, spot: Vector3, root: Vector3, dir: Vector3, lift: float = 0.0, turn: float = 0.0) -> Vector3:
	var rig: Dictionary = RIG[person]
	var base: Vector3 = rig.feet[0 if side < 0 else 1]
	var v: Vector3 = spot - root
	var local: Vector3 = rot_y(Vector3(v.dot(side_of(dir)), 0.0, - v.dot(dir)), - turn)
	return Vector3(local.x - base.x, lift, local.z - base.z) / float(rig.leg)


# Hauteur maximale du bassin (canal hips.y, en longueurs de jambe) pour que la cheville
# posée en `foot` (canal du pied) reste atteignable, genou un peu fléchi (`reach` × jambe).
static func hip_cap(person: String, side: int, foot: Vector3, hips: Vector3, reach: float = 0.965) -> float:
	var rig: Dictionary = RIG[person]
	var leg: float = float(rig.leg)
	var base: Vector3 = rig.feet[0 if side < 0 else 1]
	var ankle: Vector3 = base + foot * leg
	var joint: Vector3 = Vector3(float(side) * float(rig.hip_x) + hips.x * leg, float(rig.hip), hips.z * leg)
	var flat: float = Vector2(ankle.x - joint.x, ankle.z - joint.z).length()
	var most: float = reach * leg
	var vertical: float = sqrt(maxf(0.0, most * most - flat * flat))
	return (ankle.y + vertical - float(rig.hip)) / leg


# ------------------------------------------------------------------- DÉMARCHE --
# Appuis : [[t_contact, côté (-1 gauche, 1 droit), avance au poser (m devant la racine),
# durée d'appui (s), écart en plus (m, facultatif)], ...]. Le pied reste sur son point
# du sol pendant l'appui pendant que la racine suit `path`.
# o : kick (talon au retour, m), pass (pied au passage, m), reach_h (pied avant le poser, m),
# strike (pied au poser : + pointe levée), push (pointe au décollage), heel (part de l'appui
# talon levé), base (bassin, Vector3(droite, haut, avant) en jambes), bob_low / bob_high
# (bassin à l'amorti / au sommet, jambes), walk (bassin le plus haut au passage), sway (m vers
# le pied d'appui), yaw / roll (bassin), lean (buste penché en avant, rad), hold (fin des
# appuis : le dernier appui de chaque pied reste posé jusque-là), fx (bruits de pas),
# reach (genou : part de la jambe tendue au plus), hips (false : pas de clés de bassin),
# leave ([côtés] : le dernier appui de ce pied décolle au lieu de rester posé), start (départ).
# Rend {-1: canal du pied gauche, 1: canal du droit} posés à la fin (pour enchaîner).
static func gait(k: Array, person: String, path: Array, dir: Vector3, plants: Array, o: Dictionary = {}) -> Dictionary:
	var rig: Dictionary = RIG[person]
	var leg: float = float(rig.leg)
	var toe: float = float(rig.toe)
	var kick: float = float(o.get("kick", 0.22))
	var pass_h: float = float(o.get("pass", 0.16))
	var reach_h: float = float(o.get("reach_h", 0.05))
	var strike: float = float(o.get("strike", 0.12))
	var push: float = float(o.get("push", -0.6))
	var heel: float = float(o.get("heel", 0.35))
	var base: Vector3 = o.get("base", Vector3.ZERO)
	var bob_low: float = float(o.get("bob_low", 0.06))
	var bob_high: float = float(o.get("bob_high", 0.02))
	var walking: bool = bool(o.get("walk", false))
	var sway: float = float(o.get("sway", 0.02))
	var yaw: float = float(o.get("yaw", 0.12))
	var roll: float = float(o.get("roll", 0.04))
	var lean: float = float(o.get("lean", 0.12))
	var hold: float = float(o.get("hold", 1000.0))
	var sound: bool = bool(o.get("fx", true))
	var reach: float = float(o.get("reach", 0.965))
	var with_hips: bool = bool(o.get("hips", true))
	var leave: Array = o.get("leave", [])
	var spots: Array = []
	for plant: Array in plants:
		spots.append(plant_at(person, path, dir, float(plant[0]), int(plant[1]), float(plant[2]), float(plant[4]) if plant.size() > 4 else 0.0))
	# Départ en pleine foulée : le pied qui ne se pose pas au premier appui arrive d'un appui
	# précédent (avant le début du trajet, racine prolongée en arrière) ; on n'en garde que la
	# fin, à partir de l'instant de départ.
	var start: float = float(o.get("start", float(plants[0][0])))
	var first_seen: Dictionary = {}
	for i: int in range(plants.size()):
		if not first_seen.has(int(plants[i][1])): first_seen[int(plants[i][1])] = i
	# from_rest : les deux pieds partent posés au repos sous la racine (départ arrêté) ;
	# chaque pied décolle `swing` s avant son premier appui.
	var from_rest: bool = bool(o.get("from_rest", false))
	var swing_rest: float = float(o.get("swing", 0.42))
	for side: int in first_seen:
		var i0: int = int(first_seen[side])
		var t_first: float = float(plants[i0][0])
		if t_first <= start + 0.01 and not from_rest: continue
		var step: float = t_first - float(plants[0][0]) if i0 > 0 else 0.3
		var t_prev: float = t_first - 2.0 * maxf(step, 0.12)
		var contact: float = float(plants[i0][3])
		var spot_prev: Vector3 = _root_back(path, t_prev) + dir * float(plants[i0][2]) + side_of(dir) * float(RIG[person].feet[0 if side < 0 else 1].x)
		var t_off: float = t_prev + contact
		if from_rest:
			var rest_foot: Vector3 = RIG[person].feet[0 if side < 0 else 1]
			spot_prev = at(path, start) + side_of(dir) * rest_foot.x - dir * rest_foot.z
			t_off = t_first - swing_rest
			t_prev = start - 1.0
		var lift: float = toe * sin( - push)
		var channel: String = "foot_l" if side < 0 else "foot_r"
		var pitch: String = "fp_l" if side < 0 else "fp_r"
		var land: Vector3 = foot_on(person, side, spots[i0], at(path, t_first), dir)
		if t_off > start:
			k.append([start, {channel: foot_on(person, side, spot_prev, _root_back(path, start), dir), pitch: 0.0}, "l"])
			for point: Array in path:
				if float(point[0]) > start + 0.002 and float(point[0]) < t_off - float(plants[i0][3]) * heel - 0.002:
					k.append([float(point[0]), {channel: foot_on(person, side, spot_prev, point[1], dir)}, "l"])
			var heel_rest: float = maxf(start + 0.01, t_off - float(plants[i0][3]) * heel)
			k.append([heel_rest, {channel: foot_on(person, side, spot_prev, at(path, heel_rest), dir), pitch: 0.0}, "l"])
		var off: Vector3 = foot_on(person, side, spot_prev, _root_back(path, t_off), dir, lift)
		var swing: float = t_first - t_off
		var marks: Array = [[t_off, off, push], [t_off + swing * 0.24, Vector3(lerpf(off.x, land.x, 0.2), kick / leg, lerpf(off.z, land.z, 0.1)), push - 0.3],
			[t_off + swing * 0.55, Vector3(lerpf(off.x, land.x, 0.55), pass_h / leg, lerpf(off.z, land.z, 0.52)), push * 0.35],
			[t_off + swing * 0.82, Vector3(lerpf(off.x, land.x, 0.92), reach_h / leg, lerpf(off.z, land.z, 1.03)), strike + 0.08]]
		var placed: bool = t_off > start
		for n: int in range(marks.size()):
			var mark: Array = marks[n]
			if float(mark[0]) < start - 0.001: continue
			if not placed and n > 0:
				# l'instant de départ tombe pendant le retour du pied : pose interpolée
				var a: Array = marks[n - 1]
				var u: float = (start - float(a[0])) / maxf(0.001, float(mark[0]) - float(a[0]))
				k.append([start, {channel: (a[1] as Vector3).lerp(mark[1], u), pitch: lerpf(float(a[2]), float(mark[2]), u)}])
				placed = true
			k.append([float(mark[0]), {channel: mark[1], pitch: mark[2]}])
	# canal de chaque pied au cours du temps (pour borner le bassin) : [[t, canal, posé], ...]
	var tracks: Dictionary = {-1: [], 1: []}
	var last: Dictionary = {}
	for i: int in range(plants.size()):
		var plant: Array = plants[i]
		var t0: float = float(plant[0])
		var side: int = int(plant[1])
		var t_off: float = t0 + float(plant[3])
		var channel: String = "foot_l" if side < 0 else "foot_r"
		var pitch: String = "fp_l" if side < 0 else "fp_r"
		var spot: Vector3 = spots[i]
		var next: int = -1
		for j: int in range(i + 1, plants.size()):
			if int(plants[j][1]) == side:
				next = j
				break
		var final: bool = next < 0 and not leave.has(side)
		var end: float = hold if final else t_off
		var landing: Vector3 = foot_on(person, side, spot, at(path, t0), dir)
		k.append([t0, {channel: landing, pitch: strike}, "l"])
		(tracks[side] as Array).append([t0, landing, true])
		if sound: k.append([t0, {"fx": "step_l" if side < 0 else "step_r"}])
		k.append([t0 + minf(0.09, float(plant[3]) * 0.3), {pitch: 0.0}])
		var heel_at: float = t_off - float(plant[3]) * heel
		for point: Array in path:
			var tp: float = float(point[0])
			if tp > t0 + 0.002 and tp < (end if final else heel_at) - 0.002:
				var value: Vector3 = foot_on(person, side, spot, point[1], dir)
				k.append([tp, {channel: value}, "l"])
				(tracks[side] as Array).append([tp, value, true])
		if final:
			var stay: Vector3 = foot_on(person, side, spot, at(path, minf(end, float(path[path.size() - 1][0]))), dir)
			k.append([minf(end, float(path[path.size() - 1][0])), {channel: stay}, "l"])
			(tracks[side] as Array).append([minf(end, float(path[path.size() - 1][0])), stay, true])
			last[side] = stay
			continue
		var at_heel: Vector3 = foot_on(person, side, spot, at(path, heel_at), dir)
		k.append([heel_at, {channel: at_heel, pitch: 0.0}, "l"])
		(tracks[side] as Array).append([heel_at, at_heel, true])
		var lift: float = toe * sin( - push)
		var off: Vector3 = foot_on(person, side, spot, at(path, t_off), dir, lift / leg * leg)
		off.y = lift / leg
		k.append([t_off, {channel: off, pitch: push}])
		(tracks[side] as Array).append([t_off, off, false])
		if next < 0:
			# ce pied décolle et la suite est écrite à la main (trébuchement, arrêt…)
			last[side] = off
			continue
		var t_land: float = float(plants[next][0])
		var land: Vector3 = foot_on(person, side, spots[next], at(path, t_land), dir)
		var swing: float = t_land - t_off
		var u1: Vector3 = Vector3(lerpf(off.x, land.x, 0.2), kick / leg, lerpf(off.z, land.z, 0.1))
		var u2: Vector3 = Vector3(lerpf(off.x, land.x, 0.55), pass_h / leg, lerpf(off.z, land.z, 0.52))
		var u3: Vector3 = Vector3(lerpf(off.x, land.x, 0.92), reach_h / leg, lerpf(off.z, land.z, 1.03))
		k.append([t_off + swing * 0.24, {channel: u1, pitch: push - 0.3}])
		k.append([t_off + swing * 0.55, {channel: u2, pitch: push * 0.35}])
		k.append([t_off + swing * 0.82, {channel: u3, pitch: strike + 0.08}])
		(tracks[side] as Array).append([t_off + swing * 0.55, u2, false])
	if not with_hips: return last
	# bassin : un temps bas et un temps haut par pas, puis bornage par la longueur de jambe
	var hip_keys: Array = []
	for i: int in range(plants.size()):
		var plant: Array = plants[i]
		var t0: float = float(plant[0])
		var side: int = int(plant[1])
		var contact: float = float(plant[3])
		var amp: float = 1.0 + J(i, 3.1) * 0.25
		var t_next: float = float(plants[i + 1][0]) if i + 1 < plants.size() else t0 + contact
		if walking:
			hip_keys.append([t0 + 0.02, base.y - bob_low * amp, side, 0.0])
			hip_keys.append([(t0 + t_next) * 0.5, base.y + bob_high * amp, side, 1.0])
		else:
			hip_keys.append([t0 + contact * 0.45, base.y - bob_low * amp, side, 1.0])
			if t_next > t0 + contact + 0.03: hip_keys.append([(t0 + contact + t_next) * 0.5, base.y + bob_high * amp, side, 0.0])
	for entry: Array in hip_keys:
		var t: float = float(entry[0])
		var side: int = int(entry[2])
		var stance: float = float(entry[3])
		var y: float = float(entry[1])
		var hips: Vector3 = Vector3(base.x + float(side) * sway / leg * stance, y, - base.z)
		for foot_side: int in [-1, 1]:
			var state: Array = _track_at(tracks[foot_side], t)
			if not state.is_empty() and bool(state[1]): y = minf(y, hip_cap(person, foot_side, state[0], hips, reach))
		hips.y = y
		var turn: float = float(side) * yaw * (0.4 + 0.6 * stance)
		k.append([t, {"hips": hips, "body": Vector3( - lean, turn, float(side) * roll * stance)}])
	return last


# racine à l'instant t, prolongée avant le début du trajet à la vitesse du premier segment
static func _root_back(path: Array, t: float) -> Vector3:
	if t >= float(path[0][0]) or path.size() < 2: return at(path, t)
	var span: float = maxf(0.001, float(path[1][0]) - float(path[0][0]))
	var speed: Vector3 = ((path[1][1] as Vector3) - (path[0][1] as Vector3)) / span
	return (path[0][1] as Vector3) + speed * (t - float(path[0][0]))


# état d'une piste de pied à l'instant t : [canal, posé] (interpolation linéaire)
static func _track_at(track: Array, t: float) -> Array:
	if track.is_empty(): return []
	var prev: Array = []
	for entry: Array in track:
		if float(entry[0]) <= t: prev = entry
		else:
			if prev.is_empty(): return [entry[1], false]
			var u: float = (t - float(prev[0])) / maxf(0.0001, float(entry[0]) - float(prev[0]))
			return [(prev[1] as Vector3).lerp(entry[1], u), bool(prev[2])]
	return [prev[1], bool(prev[2])]


# Appuis réguliers de `t0` à `t1` : période et appui en s, premier pied `side`, avance au poser.
# Le rythme varie un peu d'un pas à l'autre (jamais un tempo de métronome).
static func cadence(t0: float, t1: float, period: float, contact: float, side: int, ahead: float, salt: float, o: Dictionary = {}) -> Array:
	var list: Array = []
	var t: float = t0
	var i: int = 0
	var vary: float = float(o.get("vary", 0.06))
	var width: float = float(o.get("width", 0.0))
	while t < t1 - 0.001:
		var p: float = period * (1.0 + J(i, salt) * vary)
		list.append([t, side, ahead * (1.0 + J(i, salt + 1.0) * vary), contact * (1.0 + J(i, salt + 2.0) * vary * 0.5), width + J(i, salt + 3.0) * 0.02])
		t += p
		side = - side
		i += 1
	return list


# Bras et buste d'une course : le bras opposé au pied posé part devant, le
# buste se tord à l'inverse du bassin, la tête reste stable. Une clé par appui,
# amplitudes variées.
# o : lag (s après le poser), lean (buste, rad, en plus du bassin), twist, head (tête : haut/bas,
# compense la penche), front / back (Vector3 main devant / derrière : dehors, haut, avant),
# flare, wild (désordre des bras, 0..1), curl, skip (côtés laissés libres : "l", "r"), torso (0 : pas de buste).
static func pump(k: Array, plants: Array, o: Dictionary = {}) -> void :
	var lag: float = float(o.get("lag", 0.03))
	var lean: float = float(o.get("lean", 0.1))
	var twist: float = float(o.get("twist", 0.2))
	var head: float = float(o.get("head", 0.2))
	var front: Vector3 = o.get("front", Vector3(0.05, -0.28, 0.55))
	var back: Vector3 = o.get("back", Vector3(0.15, -0.62, -0.35))
	var flare: float = float(o.get("flare", 0.2))
	var wild: float = float(o.get("wild", 0.0))
	var curl: float = float(o.get("curl", 0.6))
	var skip: String = str(o.get("skip", ""))
	var torso: float = float(o.get("torso", 1.0))
	for i: int in range(plants.size()):
		var t: float = float(plants[i][0]) + lag
		var side: int = int(plants[i][1])
		var amp: float = 1.0 + J(i, 7.7) * 0.25
		var pose: Dictionary = {}
		if torso > 0.0:
			pose["chest"] = Vector3( - lean, - float(side) * twist * amp, J(i, 4.4) * 0.03) * torso
			pose["head"] = Vector3(head + J(i, 2.2) * 0.04, float(side) * twist * amp * 0.85, J(i, 5.3) * 0.04) * torso
		# pied gauche posé (side = -1) : bras droit devant
		var f: Vector3 = front + Vector3(J(i, 1.3), J(i, 4.1), J(i, 6.6)) * wild * 0.5
		var b: Vector3 = back + Vector3(J(i, 8.2), J(i, 9.9), J(i, 0.7)) * wild * 0.5
		var right_hand: Vector3 = f if side < 0 else b
		var left_hand: Vector3 = b if side < 0 else f
		if not skip.contains("r"): pose.merge(Rt(right_hand.x, right_hand.y, right_hand.z * amp, flare), true)
		if not skip.contains("l"): pose.merge(Lt(left_hand.x, left_hand.y, left_hand.z * amp, flare), true)
		pose["curl"] = curl
		k.append([t, pose])


# Retire les canaux `channels` des clés comprises dans [t0, t1] (pour écrire à
# la main un regard, un geste… par-dessus un cycle généré).
static func carve(k: Array, channels: Array, t0: float, t1: float) -> void :
	for key: Array in k:
		var t: float = float(key[0])
		if t < t0 or t > t1: continue
		var pose: Dictionary = (key[1] as Dictionary).duplicate()
		for channel: Variant in channels: pose.erase(channel)
		key[1] = pose


# ------------------------------------------------------------- ALICE (COMMUN) --
# Alice ne court jamais : une marche longue et régulière, le buste penché, la tête qui ne bouge
# pas, les griffes qui pendent. Les pas sont écrits comme ceux des autres (pieds posés).

const ALICE_WALK: Dictionary = {"kick": 0.06, "pass": 0.07, "reach_h": 0.03, "strike": 0.22, "push": -0.42, "heel": 0.4,
	"bob_low": 0.022, "bob_high": 0.008, "walk": true, "sway": 0.018, "yaw": 0.05, "roll": 0.025, "lean": 0.12, "reach": 0.975}

static func alice_stand() -> Dictionary:
	return M([_zero(), H(0, -0.015, 0), B(0.12), C(0.36), HD(0.3, 0.0, 0.08), L(0.4, -0.82, 0.18, 0.2), R(0.44, -0.75, 0.3, 0.25), WL(-0.35), WR(-0.3),
		{"curl": 0.25, "curl_l": 0.3, "face": "menace"}])


# Le haut du corps d'Alice qui marche : presque rien ne bouge. Les mains ne balancent pas,
# elles flottent un peu en retard sur le pas ; le buste roule à peine ; la tête reste fixe
# (tilt : inclinaison), les doigts s'ouvrent et se ferment sans rythme.
static func alice_walk_upper(k: Array, plants: Array, o: Dictionary = {}) -> void :
	var tilt: float = float(o.get("tilt", 0.08))
	var look: float = float(o.get("look", 0.3))
	for i: int in range(plants.size()):
		var t: float = float(plants[i][0])
		var side: int = int(plants[i][1])
		k.append([t + 0.16, M([C(0.36 + J(i, 1.7) * 0.02, float(side) * 0.04, float(side) * 0.015), HD(look + J(i, 3.3) * 0.02, - float(side) * 0.03, tilt),
			L(0.4 + J(i, 1.1) * 0.03, -0.82, 0.16 + float(side) * 0.05, 0.2), R(0.44, -0.75, 0.3 - float(side) * 0.05, 0.25),
			{"curl": 0.22 + J(i, 4.4) * 0.12, "curl_l": 0.28 + J(i, 5.5) * 0.12}])])


# ----------------------------------------------------------------- BLEUETTE --
# « La tablette ». Bleuette court en serrant sa barre de chocolat, se retourne, se prend les
# pieds et s'étale ; la barre glisse devant elle. Elle rampe pour la reprendre… et entend les
# pas. Plan subjectif : Alice approche, immense. À genoux, Bleuette lui tend sa barre à deux
# mains, tête baissée, comme une offrande à une reine. Alice la prend du bout des griffes, la
# regarde, lève l'autre main. Noir. Alice, seule, croque dans le chocolat.

const B_TRIP: float = 1.72
const B_DROP: float = 1.97
const B_GRAB: float = 3.92
const B_FLIP: float = 5.0
const B_TAKE: float = 7.82
const B_KILL: float = 9.42
const B_BITE: float = 10.82

static func bleuette_path() -> Array:
	return [[0.0, Vector3(0.35, 0, -1.6)], [1.78, Vector3(0.35, 0, 3.75)], [1.95, Vector3(0.36, 0, 4.18)], [2.12, Vector3(0.37, 0, 4.52)],
		[2.3, Vector3(0.37, 0, 4.76)], [2.55, Vector3(0.37, 0, 4.9)], [2.8, Vector3(0.37, 0, 4.95)], [3.62, Vector3(0.37, 0, 4.95)],
		[3.92, Vector3(0.37, 0, 5.1)], [B_FLIP, Vector3(0.37, 0, 5.1)], [5.6, Vector3(0.37, 0, 5.05)], [12.0, Vector3(0.37, 0, 5.05)]]

static func bleuette_alice_path() -> Array:
	return [[0.0, Vector3(-0.1, 0, -4.2)], [0.25, Vector3(-0.1, 0, -4.2)], [5.55, Vector3(0.22, 0, 3.35)], [6.0, Vector3(0.27, 0, 3.8)],
		[6.42, Vector3(0.3, 0, 4.05)], [12.0, Vector3(0.3, 0, 4.05)]]


static func _bleuette(c: Dictionary) -> void :
	var p: String = "Bleuette"
	var path: Array = bleuette_path()
	var fwd: Vector3 = Vector3(0, 0, 1)
	var k: Array = []
	# --- FUITE : petite course paniquée, la barre serrée contre la poitrine (main droite)
	var clutch: Dictionary = M([Rt(-0.18, -0.12, 0.42, 0.45), WR(0.5, 0.3), {"curl": 0.95}])
	k.append(K(0.0, M([_zero(), H(0, -0.06, 0), B(0.3), C(0.1), HD(0.34), clutch, Lt(0.15, -0.3, 0.5, 0.3), {"curl_l": 0.5, "face": "panic", "jaw": 0.35}])))
	var plants: Array = cadence(0.0, 1.66, 0.265, 0.15, -1, 0.23, 11.0, {"vary": 0.07})
	gait(k, p, path, fwd, plants, {"kick": 0.24, "pass": 0.2, "reach_h": 0.06, "strike": 0.16, "push": -0.7, "bob_low": 0.075, "bob_high": 0.03,
		"lean": 0.3, "heel": 0.3, "yaw": 0.15, "roll": 0.05, "base": Vector3(0, -0.04, 0), "leave": [-1, 1]})
	pump(k, plants, {"skip": "r", "lean": 0.1, "twist": 0.16, "head": 0.34, "front": Vector3(0.2, -0.15, 0.6), "back": Vector3(0.28, -0.5, -0.35), "flare": 0.55, "wild": 0.5, "curl": 0.45})
	for n: int in range(plants.size()):
		k.append(K(float(plants[n][0]) + 0.04, M([clutch, {"jaw": 0.25 + 0.25 * float(n % 2) + J(n, 2.0) * 0.1}])))
	# un regard en arrière par-dessus l'épaule droite, la barre plaquée contre elle
	carve(k, ["head", "chest"], 0.86, 1.42)
	k.append(K(0.9, M([C(0.08, -0.32), HD(0.22, -1.05, -0.12), FACE("fear")])))
	k.append(K(1.12, M([C(0.06, -0.38), HD(0.18, -1.15, -0.15), {"jaw": 0.6}]), "s"))
	k.append(K(1.36, M([C(0.12, 0.08), HD(0.3, 0.12, 0.05), FACE("panic")])))

	# --- CHUTE : la pointe du pied droit accroche le sol, elle part en avant
	var trip_spot: Vector3 = at(path, B_TRIP) + Vector3(-0.1, 0, 0.02)
	var t: float = B_TRIP
	k.append(K(t - 0.12, M([{"foot_r": foot_on(p, 1, trip_spot, at(path, t - 0.12), fwd, 0.07), "fp_r": -0.35}])))
	k.append(K(t, M([{"foot_r": foot_on(p, 1, trip_spot, at(path, t), fwd, 0.0), "fp_r": -0.8}, B(0.42, 0.05), C(0.12), HD(0.15), FACE("surprise"), {"jaw": 0.55}]), "l"))
	k.append(K(t + 0.1, M([{"foot_r": foot_on(p, 1, trip_spot, at(path, t + 0.1), fwd, 0.01), "fp_r": -1.0}, H(0, -0.1, 0.05), B(0.62, 0.1, 0.05), C(0.2, 0.05), HD(0.35),
		Rt(0.15, 0.1, 0.65, 0.4), Lt(0.3, 0.2, 0.55, 0.5), {"curl": 0.4, "curl_l": 0.1, "ev": "gasp"}])))
	# un grand pas de rattrapage du pied gauche, trop tard
	var catch_spot: Vector3 = at(path, B_TRIP + 0.2) + Vector3(0.0, 0, 0.42)
	k.append(K(t - 0.02, M([{"foot_l": foot_on(p, -1, at(path, t - 0.02) + Vector3(0.1, 0, -0.14), at(path, t - 0.02), fwd, 0.03), "fp_l": -0.5}])))
	k.append(K(t + 0.1, M([{"foot_l": foot_on(p, -1, catch_spot + Vector3(0, 0, -0.2), at(path, t + 0.1), fwd, 0.14), "fp_l": 0.1}])))
	k.append(K(t + 0.2, M([{"foot_l": foot_on(p, -1, catch_spot, at(path, t + 0.2), fwd, 0.0), "fp_l": 0.2, "fx": "step_l"}, H(0, -0.22, 0.12), B(0.95, 0.05, 0.08), C(0.22), HD(0.5)]), "l"))
	k.append(K(t + 0.3, M([{"foot_l": foot_on(p, -1, catch_spot, at(path, t + 0.3), fwd, 0.0), "fp_l": 0.0}, {"foot_r": foot_on(p, 1, trip_spot + Vector3(0, 0, 0.3), at(path, t + 0.3), fwd, 0.3), "fp_r": -0.9}])))
	# les mains en avant (la barre s'échappe), puis le sol : mains, genoux, ventre
	k.append(K(B_DROP, M([R(0.25, 0.05, 0.75, 0.3), L(0.3, 0.0, 0.75, 0.3), WR(-0.3), WL(-0.3), {"curl": 0.05, "curl_l": 0.05, "face": "panic", "jaw": 0.7}])))
	k.append(K(t + 0.34, M([{"plant": 1.0}, H(0, -0.3, 0.2), B(1.15, 0.05, 0.08), C(0.22), HD(0.65)])))
	k.append(K(t + 0.44, M([{"plant": 0.0, "gsnap": 0.0}, Lg(0.42, 0.55, 0.0), Rg(0.38, 0.6, 0.0), {"fx": "dust"}])))
	k.append(K(t + 0.46, M([TL(0.4, 0.1), KL(0.7, -0.3), TR(-0.12, 0.08), KR(0.45, -0.5)])))
	k.append(K(t + 0.5, M([{"gsnap": 1.0}, B(1.28, 0.04, 0.1), C(0.2), HD(0.75), Lg(0.48, 0.42, 0.0), Rg(0.44, 0.45, 0.0), {"sq": 0.93, "ev": "effort"}]), "s"))
	k.append(K(t + 0.62, M([B(1.46, 0.03, 0.12), C(0.08), HD(0.7, 0.05, 0.05), Lg(0.6, 0.55, 0.0), Rg(0.55, 0.6, 0.0), TL(0.08, 0.12), KL(0.32, -0.6), TR(-0.04, 0.1), KR(0.25, -0.6),
		{"sq": 1.0, "fx": "dust_ring", "face": "pain", "jaw": 0.4}])))
	k.append(K(t + 0.85, M([B(1.52, 0.02, 0.1), C(-0.02), HD(0.45, 0.1, 0.1), Lg(0.65, 0.5, 0.0), Rg(0.6, 0.52, 0.0), TL(0.0, 0.12), KL(0.12, -0.8), TR(0.02, 0.1), KR(0.22, -0.8), {"jaw": 0.15}]), "s"))
	# --- À TERRE : sonnée, le nez au sol ; elle relève la tête et voit la barre
	k.append(K(3.05, M([C(0.0), HD(0.15, 0.15, 0.12), {"face": "hurt", "shake": 0.15}])))
	k.append(K(3.3, M([C(0.03), HD(0.2, 0.12, 0.1)])))
	k.append(K(3.45, M([B(1.45, 0.0, 0.05), C(-0.15), HD(0.85, 0.0, 0.0), Lg(0.55, 0.42, 0.0), Rg(0.5, 0.45, 0.0), {"face": "sad", "shake": 0.0}])))
	blink(3.52, "sad", k, 0.1)
	# elle tend le bras droit vers la barre et se traîne sur les coudes
	k.append(K(3.62, M([Rg(0.25, 1.05, 0.0), WR(-0.2), {"curl": 0.15, "face": "fear"}])))
	k.append(K(3.78, M([B(1.48, -0.05), C(-0.1, 0.06), Rg(0.2, 1.15, 0.0), Lg(0.5, 0.65, 0.0), TL(0.3, 0.15), KL(0.45, -0.7)])))
	k.append(K(B_GRAB, M([Rg(0.22, 1.0, 0.03), {"curl": 0.95}, TL(0.0, 0.12), KL(0.15, -0.8)]), "s"))
	# les pas d'Alice : elle se fige, ramène la barre sous elle et regarde par-dessus l'épaule
	k.append(K(4.12, M([B(1.45, 0.0), C(-0.05), HD(0.55, -0.1), Rg(0.15, 0.4, 0.05), Lg(0.5, 0.45, 0.0), {"face": "fear"}]), "s"))
	k.append(K(4.4, M([B(1.25, -0.1, -0.15), C(-0.2, -0.45, -0.1), HD(0.25, -1.15, -0.2), Lg(0.42, 0.3, 0.0), Rg(0.05, 0.25, 0.08), {"face": "panic", "jaw": 0.5, "shake": 0.5}])))
	k.append(K(4.8, M([C(-0.22, -0.5, -0.1), HD(0.22, -1.25, -0.22), {"jaw": 0.7, "shake": 0.8}]), "s"))
	# --- (hors champ, plan subjectif) elle se retourne et se met à genoux face à Alice
	var kneel: Dictionary = M([{"plant": 0.0, "gsnap": 1.0}, H(0, -0.5, 0.0), B(0.08), C(0.12), HD(0.3), TL(1.48, 0.12), KL(2.05, -0.55), TR(1.48, 0.1), KR(2.05, -0.55)])
	k.append(K(B_FLIP + 0.3, M([kneel, B(0.3), C(0.3), HD(0.1), Rt(-0.2, -0.25, 0.32, 0.4), Lt(-0.18, -0.3, 0.3, 0.4), WR(0.6), WL(0.6),
		{"curl": 0.95, "curl_l": 0.8, "face": "panic", "shake": 0.9, "jaw": 0.3}])))
	# --- à genoux, la barre serrée contre elle, elle lève les yeux vers Alice
	k.append(K(6.0, M([kneel, B(0.18), C(0.25), HD(0.55, 0.05, 0.08), Rt(-0.22, -0.22, 0.3, 0.4), Lt(-0.2, -0.28, 0.28, 0.4), {"shake": 0.7}])))
	k.append(K(6.4, M([B(0.12), C(0.2), HD(0.75, 0.0, 0.1), {"face": "fear", "shake": 0.85}]), "s"))
	blink(6.55, "fear", k)
	# --- OFFRANDE : elle se redresse sur les genoux et lui tend la barre à deux mains, tête baissée
	var up: Dictionary = M([{"plant": 0.0, "gsnap": 1.0}, H(0, -0.28, 0.0), TL(0.35, 0.12), KL(1.75, -0.55), TR(0.35, 0.1), KR(1.75, -0.55)])
	k.append(K(6.75, M([up, B(0.05), C(0.05), HD(0.6), R(0.0, -0.1, 0.55, 0.35), L(-0.02, -0.12, 0.55, 0.35), WR(0.3, 0.6), WL(0.3, -0.6), {"shake": 0.6}])))
	k.append(K(7.0, M([B(0.12), C(0.2), HD(-0.35, 0.0, 0.06), R(-0.05, 0.35, 0.75, 0.3), L(-0.06, 0.32, 0.75, 0.3), WR(-0.4, 0.5), WL(-0.4, -0.5),
		{"face": "asleep", "shake": 0.75, "jaw": 0.1}])))
	k.append(K(7.5, M([B(0.14), C(0.22), HD(-0.4, 0.05, 0.08), R(-0.05, 0.38, 0.78, 0.3), L(-0.06, 0.35, 0.78, 0.3), {"shake": 0.95}]), "s"))
	# Alice prend la barre : les mains restent tendues, vides, un instant
	k.append(K(B_TAKE + 0.05, M([R(-0.04, 0.36, 0.76, 0.3), L(-0.05, 0.33, 0.76, 0.3), {"curl": 0.1, "curl_l": 0.1, "shake": 0.3}]), "s"))
	k.append(K(8.2, M([B(0.1), C(0.18), HD(-0.2, 0.0, 0.05), R(0.02, 0.0, 0.5, 0.35), L(0.0, -0.02, 0.5, 0.35), {"face": "sad", "shake": 0.4}])))
	k.append(K(8.5, M([up, B(0.04), C(0.08), HD(0.45, 0.05, 0.1), Rt(-0.12, -0.35, 0.32, 0.4), Lt(-0.1, -0.38, 0.3, 0.4), {"face": "surprise"}])))
	# la griffe gauche d'Alice monte : elle la suit des yeux et se recroqueville
	k.append(K(8.95, M([HD(0.85, 0.08, 0.12), {"face": "fear", "shake": 0.5}])))
	k.append(K(9.2, M([B(-0.08), C(-0.05), HD(0.9, 0.3, 0.2), SH(0.35, 0.3), R(0.15, 0.25, 0.4, 0.6), L(0.1, 0.3, 0.42, 0.6), WR(0.9), WL(0.9),
		{"face": "panic", "jaw": 0.6, "shake": 0.9, "curl": 0.6, "curl_l": 0.6}])))
	k.append(K(B_KILL - 0.02, M([HD(0.5, 0.7, 0.3), {"face": "pain", "jaw": 0.9}]), "s"))
	# --- (noir) elle s'effondre sur le côté
	k.append(K(B_KILL + 0.15, M([{"gsnap": 1.0}, H(0, -0.6, 0.0), B(-0.3, 0.3, 0.8), C(0.2, 0.2), HD(0.2, 0.4, 0.3), SH(0.0, 0.0), L(0.6, -0.4, 0.3, 0.3), R(0.7, -0.2, 0.2, 0.3),
		TL(1.2, 0.3), KL(1.6, -0.4), TR(1.0, 0.2), KR(1.8, -0.4), {"face": "dead", "jaw": 0.3, "shake": 0.0, "curl": 0.2, "curl_l": 0.3, "ev": "death"}])))
	k.append(K(B_KILL + 0.5, M([B(-0.2, 0.4, 1.45), C(0.1, 0.1, 0.1), HD(0.0, 0.3, 0.35), Lg(0.5, 0.3, 0.0), Rg(0.8, 0.2, 0.0), TL(1.0, 0.3), KL(1.3, -0.4), TR(0.9, 0.2), KR(1.5, -0.4)]), "s"))
	k.append(K(12.5, M([B(-0.2, 0.4, 1.46), HD(0.0, 0.3, 0.36)])))
	c["fa_bleuette"] = _film(0.0, 12.5, k, "panic")
	_bleuette_alice(c)


static func _bleuette_alice(c: Dictionary) -> void :
	var p: String = "Alice"
	var path: Array = bleuette_alice_path()
	var fwd: Vector3 = Vector3(0.04, 0, 1).normalized()
	var k: Array = []
	k.append(K(0.0, alice_stand()))
	# immobile dans le noir, puis la marche : longue, égale, sans hâte ; elle ralentit en arrivant
	var plants: Array = cadence(0.72, 5.5, 0.56, 0.72, 1, 0.24, 23.0, {"vary": 0.03, "width": -0.02})
	var side_next: int = - int(plants[plants.size() - 1][1])
	plants.append([float(plants[plants.size() - 1][0]) + 0.6, side_next, 0.2, 0.75, -0.02])
	plants.append([float(plants[plants.size() - 1][0]) + 0.5, - side_next, 0.1, 0.6, -0.02])
	var walk: Dictionary = ALICE_WALK.duplicate()
	walk["from_rest"] = true
	walk["start"] = 0.3
	var feet: Dictionary = gait(k, p, path, fwd, plants, walk)
	alice_walk_upper(k, plants)
	# elle s'arrête au-dessus de Bleuette, la tête qui se penche lentement
	var standing: Dictionary = M([{"foot_l": feet[-1], "foot_r": feet[1], "fp_l": 0.0, "fp_r": 0.0}])
	k.append(K(6.55, M([standing, H(0, -0.015, 0), B(0.1), C(0.4), HD(0.12, 0.0, 0.1), L(0.4, -0.82, 0.14, 0.2), R(0.44, -0.75, 0.28, 0.25), {"curl": 0.2, "curl_l": 0.25}])))
	k.append(K(7.25, M([B(0.12), C(0.44, 0.02), HD(0.05, 0.05, 0.32), {"curl": 0.45, "curl_l": 0.4}]), "s"))
	# --- elle prend la barre du bout des griffes, sans hâte
	k.append(K(7.5, M([C(0.5, 0.0, 0.05), HD(0.0, 0.0, 0.25), R(0.3, -0.5, 0.45, 0.4), WR(-0.2), {"curl": 0.2}])))
	k.append(K(B_TAKE - 0.08, M([B(0.16), C(0.62), HD(-0.05, 0.0, 0.2), R(0.08, -0.38, 0.72, 0.35), WR(0.25, 0.2), {"curl": 0.35}])))
	k.append(K(B_TAKE, M([R(0.07, -0.36, 0.74, 0.35), {"curl": 0.8}]), "s"))
	# elle se redresse et regarde la barre de près, la tête qui bascule de l'autre côté
	k.append(K(8.2, M([B(0.1), C(0.42), HD(0.2, -0.05, -0.1), R(0.1, 0.15, 0.32, 0.35), WR(0.6, -0.3), {"face": "calm"}])))
	k.append(K(8.45, M([HD(0.25, -0.1, -0.28), R(0.09, 0.18, 0.3, 0.35)]), "s"))
	blink(8.5, "calm", k)
	# puis Bleuette : la main gauche monte, doigts écartés
	k.append(K(8.75, M([C(0.45), HD(0.0, 0.05, 0.18), L(0.35, -0.6, 0.25, 0.4), {"face": "menace", "curl_l": 0.3}])))
	k.append(K(9.25, M([C(0.4, -0.1), HD(-0.05, 0.1, 0.2), L(0.32, 0.45, 0.25, 0.7), WL(-0.6, 0.2), {"curl_l": 0.05, "face": "grin"}])))
	k.append(K(B_KILL - 0.04, M([L(0.3, 0.55, 0.2, 0.75), WL(-0.8, 0.2), {"curl_l": 0.35}]), "s"))
	k.append(K(B_KILL + 0.06, M([B(0.25), C(0.7, 0.25), HD(-0.2, 0.1, 0.1), L(-0.05, -0.55, 0.65, 0.2), WL(0.5), {"curl_l": 0.8, "fx": "claw_l trail_l", "ev": "grunt", "sq": 1.04}])))
	k.append(K(B_KILL + 0.22, M([B(0.2), C(0.62, 0.15), L(0.05, -0.62, 0.45, 0.25), {"sq": 1.0}]), "s"))
	# --- seule : elle se redresse, la barre devant la bouche, et croque dedans en nous regardant
	k.append(K(9.9, M([B(0.12), C(0.45, 0.05), HD(0.1, 0.0, 0.12), L(0.4, -0.8, 0.18, 0.2), WL(-0.35), R(0.15, -0.3, 0.3, 0.35), WR(0.3), {"curl_l": 0.3, "face": "calm"}])))
	k.append(K(10.35, M([C(0.36), HD(0.28, 0.08, 0.1), R(0.08, 0.1, 0.32, 0.3), WR(0.7, -0.2)])))
	k.append(K(10.68, M([HD(0.32, 0.1, 0.06), R(0.02, 0.24, 0.24, 0.25), WR(1.0, -0.35), {"jaw": 0.55}]), "s"))
	k.append(K(B_BITE, M([HD(0.22, 0.06, 0.12), R(0.04, 0.16, 0.3, 0.25), {"jaw": 0.0, "sq": 1.015}])))
	k.append(K(B_BITE + 0.12, M([HD(0.26, 0.08, 0.1), R(0.12, -0.05, 0.34, 0.3), WR(0.45), {"sq": 1.0, "jaw": 0.12}])))
	k.append(K(11.15, {"jaw": 0.0}))
	k.append(K(11.32, M([HD(0.3, 0.12, 0.16), {"jaw": 0.15, "face": "grin"}])))
	k.append(K(11.5, {"jaw": 0.02}))
	k.append(K(11.62, {"jaw": 0.1}))
	k.append(K(11.8, M([HD(0.32, 0.13, 0.2), {"jaw": 0.0}])))
	k.append(K(12.5, M([HD(0.33, 0.14, 0.22)])))
	c["fa_bleuette_alice"] = _film(0.0, 12.5, k, "menace")
