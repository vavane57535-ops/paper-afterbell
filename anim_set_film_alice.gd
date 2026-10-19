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
	_simon(c)
	_usayuko(c)


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

# Orientation de la racine : le film lisse le lacet vers chaque nouvelle cible donnée par
# _face(i, t, "dir", d) (lerp_angle à 11/s, soit exp(-11 Δt) quelle que soit la cadence).
# Un programme d'orientation [[t, direction (film)], ...] est donné tel quel au film
# (film_alice_kill.gd) ; les pieds posés s'en servent pour rester fixes quand le corps tourne.
const YAW_RATE: float = 11.0

static func yaw_of(dir: Vector3) -> float:
	return atan2(dir.x, dir.z)

static func dir_of(yaw: float) -> Vector3:
	return Vector3(sin(yaw), 0.0, cos(yaw))

static func facing_at(schedule: Array, t: float) -> Vector3:
	if schedule.is_empty(): return Vector3(0, 0, 1)
	var yaw: float = yaw_of(schedule[0][1])
	var target: float = yaw
	var since: float = float(schedule[0][0])
	for entry: Array in schedule:
		if float(entry[0]) > t: break
		yaw = target - angle_difference(yaw, target) * exp( - YAW_RATE * (float(entry[0]) - since))
		since = float(entry[0])
		target = yaw_of(entry[1])
	yaw = target - angle_difference(yaw, target) * exp( - YAW_RATE * maxf(0.0, t - since))
	return dir_of(yaw)

# canal du pied posé sur `spot` à l'instant t, racine sur `path`, orientée selon `schedule`
static func foot_at(person: String, side: int, spot: Vector3, path: Array, schedule: Array, t: float, lift: float = 0.0, turn: float = 0.0) -> Vector3:
	return foot_on(person, side, spot, at(path, t), facing_at(schedule, t), lift, turn)

# Pied posé et tenu pendant [t0, t1] (racine qui bouge ou tourne) : clés linéaires serrées.
static func hold_foot(k: Array, person: String, side: int, spot: Vector3, path: Array, schedule: Array, t0: float, t1: float, step: float = 0.05) -> void :
	var channel: String = "foot_l" if side < 0 else "foot_r"
	var t: float = t0
	while t < t1 - 0.0001:
		k.append([t, {channel: foot_at(person, side, spot, path, schedule, t)}, "l"])
		t += step
	k.append([t1, {channel: foot_at(person, side, spot, path, schedule, t1)}, "l"])

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


# ------------------------------------------------------------------- SIMON --
# « Un pas d'avance ». Simon file en Course éclair, buste couché, bras tendus en arrière. Il jette
# un œil derrière lui : Alice est là-bas, immobile… puis plus là. Il regarde devant : elle est
# devant lui. Il freine, ses pieds partent, il tombe sur les fesses à ses pieds et recule sur les
# mains. Il sort sa flashbang, arrache la goupille avec les dents, la lance. Alice ferme les yeux.
# Elle attrape au vol la goupille qu'il lui crache dessus, et la regarde plutôt que la grenade.
# Flash. Plus personne. Il souffle, rit nerveusement… une griffe se pose sur son épaule. Il lève
# la tête : elle est penchée au-dessus de lui. Noir. Alice lâche la goupille à côté de lui.

const S_SEEN: float = 1.2
const S_BRAKE: float = 1.34
const S_SIT: float = 1.98
const S_GRAB: float = 4.06
const S_PIN: float = 4.62
const S_THROW: float = 5.3
const S_FLASH: float = 5.8
const S_BACK: float = 7.1
const S_TOUCH: float = 7.85
const S_KILL: float = 9.15
const S_SPIT: float = 4.74
const S_CATCH: float = 4.95
const S_DROP: float = 10.36

static func simon_path() -> Array:
	return [[0.0, Vector3(0.25, 0, -4.0)], [1.32, Vector3(0.25, 0, 3.1)], [1.5, Vector3(0.25, 0, 3.93)], [1.68, Vector3(0.25, 0, 4.37)],
		[1.84, Vector3(0.26, 0, 4.55)], [2.0, Vector3(0.26, 0, 4.63)], [2.2, Vector3(0.26, 0, 4.65)],
		[2.6, Vector3(0.26, 0, 4.65)], [2.82, Vector3(0.26, 0, 4.43)], [3.12, Vector3(0.26, 0, 4.43)], [3.34, Vector3(0.26, 0, 4.21)],
		[3.64, Vector3(0.26, 0, 4.21)], [3.88, Vector3(0.26, 0, 3.99)], [12.0, Vector3(0.26, 0, 3.99)]]

static func simon_alice_path() -> Array:
	return [[0.0, Vector3(0.1, 0, -6.0)], [1.0, Vector3(0.1, 0, -6.0)], [1.04, Vector3(0.22, 0, 5.55)], [2.75, Vector3(0.22, 0, 5.55)],
		[3.25, Vector3(0.22, 0, 5.3)], [3.55, Vector3(0.22, 0, 5.3)], [4.05, Vector3(0.22, 0, 5.08)], [6.4, Vector3(0.22, 0, 5.08)],
		[6.44, Vector3(0.24, 0, 3.55)], [12.0, Vector3(0.24, 0, 3.55)]]


# assis par terre, jambes devant (jambes en cinématique directe, bassin posé au sol) : genoux
# pliés, les cuisses remontent pour que les talons restent au sol sous les fesses.
static func sit_floor(lean: float = 0.3, knees: float = 0.3) -> Dictionary:
	var lift: float = 0.55 * maxf(0.0, knees - 0.3)
	return M([{"plant": 0.0, "gsnap": 1.0}, H(0, -1.0, 0.0), B( - lean), TL(1.42 + lift, 0.08), KL(knees, 0.3), TR(1.38 + lift, 0.1), KR(knees + 0.1, 0.25)])


static func _simon(c: Dictionary) -> void :
	var p: String = "Simon"
	var path: Array = simon_path()
	var fwd: Vector3 = Vector3(0, 0, 1)
	var k: Array = []
	# --- FUITE : Course éclair, buste couché, bras tendus en arrière, la tête qui tire en avant
	k.append(K(0.0, M([_zero(), H(0, -0.1, 0.12), B(0.75), C(0.35), HD(1.05), R(0.22, 0.12, -0.95), L(0.22, 0.12, -0.95), WR(-0.5, 0.0, 0.2), WL(-0.5, 0.0, -0.2),
		{"curl": 0.3, "curl_l": 0.3, "face": "panic", "jaw": 0.3}])))
	var plants: Array = cadence(0.0, 1.2, 0.232, 0.105, -1, 0.36, 31.0, {"vary": 0.05})
	gait(k, p, path, fwd, plants, {"kick": 0.38, "pass": 0.3, "reach_h": 0.09, "strike": 0.08, "push": -0.9, "bob_low": 0.06, "bob_high": 0.035,
		"lean": 0.75, "heel": 0.2, "yaw": 0.1, "roll": 0.035, "base": Vector3(0, -0.1, 0.12), "leave": [-1, 1]})
	pump(k, plants, {"skip": "lr", "lean": 0.35, "twist": 0.08, "head": 1.05})
	for n: int in range(plants.size()):
		var side: float = float(plants[n][1])
		k.append(K(float(plants[n][0]) + 0.05, M([R(0.22 + J(n, 1.1) * 0.05, 0.12 + side * 0.06, -0.95), L(0.22 + J(n, 2.2) * 0.05, 0.12 - side * 0.06, -0.95),
			{"curl": 0.3 + J(n, 3.0) * 0.12, "curl_l": 0.3 + J(n, 4.0) * 0.12, "jaw": 0.25 + 0.2 * float(n % 2)}])))
	# un regard par-dessus l'épaule droite : elle est là-bas, immobile… puis plus là
	carve(k, ["head", "chest"], 0.4, 1.25)
	k.append(K(0.44, M([C(0.3, -0.22), HD(0.8, -0.85, -0.1)])))
	k.append(K(0.6, M([C(0.28, -0.3), HD(0.72, -1.15, -0.14), FACE("fear"), {"jaw": 0.5}]), "s"))
	k.append(K(0.92, M([C(0.28, -0.3), HD(0.7, -1.2, -0.15)])))
	k.append(K(1.02, M([FACE("surprise")])))
	k.append(K(1.1, M([C(0.34, 0.02), HD(1.05, 0.05, 0.02)])))
	blink(1.08, "surprise", k, 0.05)
	# devant lui : elle
	k.append(K(S_SEEN, M([C(0.2, 0.0), HD(1.1, 0.0, 0.0), FACE("panic"), {"jaw": 0.85}])))

	# --- CHUTE : il freine des deux talons, les bras moulinent, ses pieds partent devant
	k.append(K(1.22, M([{"foot_l": Vector3(0.0, 0.12, -0.55), "fp_l": 0.25}])))
	k.append(K(S_BRAKE, M([{"foot_l": Vector3(-0.02, 0.0, -0.82), "fp_l": 0.45, "fx": "skid"}, H(0, -0.16, -0.06), B(0.1), C(-0.05), HD(0.8),
		R(0.38, 0.25, 0.4, 0.3), L(0.42, 0.4, 0.3, 0.3), WR(-0.2), WL(-0.2), {"curl": 0.05, "curl_l": 0.05}])))
	k.append(K(1.42, M([{"foot_r": Vector3(0.02, 0.18, -0.3), "fp_r": -0.1}])))
	k.append(K(1.5, M([{"foot_r": Vector3(0.03, 0.0, -0.66), "fp_r": 0.35, "fx": "skid"}, {"foot_l": Vector3(-0.02, 0.0, -0.84), "fp_l": 0.42},
		H(0, -0.3, -0.12), B(-0.28), C(-0.12), HD(0.5), R(0.5, 0.55, 0.2, 0.4), L(0.3, 0.2, 0.62, 0.2), {"ev": "gasp"}])))
	k.append(K(1.62, M([{"foot_l": Vector3(-0.02, 0.0, -0.9), "fp_l": 0.5}, {"foot_r": Vector3(0.03, 0.0, -0.72), "fp_r": 0.45},
		H(0, -0.38, -0.16), B(-0.36), C(-0.1), HD(0.42), R(0.3, 0.6, 0.45, 0.4), L(0.5, 0.45, 0.2, 0.3)])))
	k.append(K(1.74, M([{"plant": 1.0}, {"foot_l": Vector3(0.0, 0.25, -1.08), "fp_l": 0.7}, {"foot_r": Vector3(0.05, 0.12, -0.95), "fp_r": 0.6},
		H(0, -0.62, -0.25), B(-0.55), C(-0.05), HD(0.25), R(0.32, -0.25, -0.35, 0.2), L(0.36, -0.2, -0.4, 0.2), FACE("surprise"), {"jaw": 0.7}])))
	k.append(K(1.86, M([{"plant": 0.0, "gsnap": 0.0}, H(0, -0.88, -0.12), B(-0.62), TL(1.62, 0.08), KL(0.2, 0.3), TR(1.5, 0.1), KR(0.32, 0.25)])))
	# les fesses touchent : les mains claquent au sol derrière lui, la tête part en arrière puis revient
	k.append(K(S_SIT, M([sit_floor(0.5, 0.25), B(-0.48), C(0.0), HD(0.2), Rg(0.3, -0.55, 0.0), Lg(0.32, -0.5, 0.0), WR(0.3), WL(0.3),
		{"fx": "dust_ring", "ev": "hurt", "face": "pain", "sq": 0.93, "curl": 0.15, "curl_l": 0.15}]), "s"))
	k.append(K(2.07, M([B(-0.32), C(0.12), HD(-0.05), TL(1.58, 0.08), KL(0.2, 0.35), TR(1.52, 0.1), KR(0.28, 0.3), {"sq": 1.0}])))
	k.append(K(2.22, M([sit_floor(0.32, 0.32), C(0.05), HD(0.5, 0.02, 0.04), Rg(0.3, -0.6, 0.0), Lg(0.32, -0.56, 0.0), FACE("fear"), {"jaw": 0.55, "shake": 0.35}]), "s"))
	blink(2.36, "fear", k, 0.06)

	# --- il recule sur les mains et les talons, trois poussées, les yeux rivés sur elle
	var pushes: Array = [[2.6, 2.82, 0.0], [3.12, 3.34, 1.0], [3.64, 3.88, 2.0]]
	for push: Array in pushes:
		var t0: float = float(push[0])
		var t1: float = float(push[1])
		var n: float = float(push[2])
		var look: float = 0.55 + 0.05 * n
		# les talons ramenés, les mains plantées loin derrière
		k.append(K(t0 - 0.14, M([sit_floor(0.38, 1.0), TL(1.12 + J(int(n), 1.0) * 0.08, 0.1), KL(1.3, 0.1), TR(1.16, 0.12), KR(1.22 + J(int(n), 2.0) * 0.1, 0.1),
			C(0.0, J(int(n), 3.0) * 0.12), HD(look, J(int(n), 4.0) * 0.1, 0.05), Rg(0.28, -0.82, 0.0), Lg(0.3, -0.8, 0.0), {"shake": 0.5}])))
		# la poussée : les jambes se tendent, le corps glisse en arrière par-dessus les mains
		k.append(K(t1, M([sit_floor(0.42, 0.35), TL(1.36, 0.1), KL(0.45, 0.25), TR(1.32, 0.12), KR(0.5, 0.25), C(-0.05), HD(look + 0.08, 0.0, 0.0),
			Rg(0.28, -0.22, 0.0), Lg(0.3, -0.2, 0.0), {"jaw": 0.6 + 0.1 * n}]), "s"))
		if n == 1.0: k.append(K(t1 - 0.1, {"ev": "effort"}))
	k.append(K(3.98, M([sit_floor(0.3, 0.5), C(0.08), HD(0.62, 0.02, 0.06), Rg(0.28, -0.55, 0.0), Lg(0.3, -0.52, 0.0), FACE("panic"), {"shake": 0.6, "jaw": 0.4}])))

	# --- DÉFENSE : la main droite file à la poche, la flashbang, la goupille aux dents, le lancer
	k.append(K(S_GRAB - 0.06, M([R(0.34, -0.62, 0.05, 0.2), WR(0.4), C(0.1, -0.12, -0.08), {"curl": 0.4}])))
	k.append(K(S_GRAB + 0.04, M([R(0.33, -0.6, 0.08, 0.2), {"curl": 0.92, "face": "determined", "jaw": 0.1}]), "s"))
	k.append(K(4.34, M([R(-0.3, 0.22, 0.45, 0.2), WR(-0.3, 0.6), C(0.32, 0.05), HD(-0.2, 0.08, -0.05), {"curl": 0.95, "jaw": 0.35}])))
	k.append(K(4.52, M([R(-0.3, 0.23, 0.45, 0.2), HD(-0.3, 0.1, -0.08), {"jaw": 0.0}]), "s"))
	# il arrache la goupille d'un coup de tête, et la lui crache dessus
	k.append(K(S_PIN, M([R(0.36, -0.15, 0.55, 0.3), C(0.12, -0.15), HD(0.05, -0.45, -0.15), {"jaw": 0.0}])))
	k.append(K(S_SPIT - 0.05, M([C(0.0, -0.05), HD(0.3, -0.1, 0.0)])))
	k.append(K(S_SPIT, M([C(0.18, 0.05), HD(0.42, 0.02, 0.0), {"jaw": 0.45}])))
	k.append(K(4.86, M([C(0.0, -0.32), B(-0.36), HD(0.5, 0.05, 0.0), R(0.36, 0.42, -0.28, 0.3), WR(0.5), FACE("angry"), {"jaw": 0.0}])))
	k.append(K(5.12, M([C(0.0, -0.38), R(0.4, 0.5, -0.32, 0.3)]), "s"))
	k.append(K(S_THROW, M([C(0.28, 0.32), B(-0.22), HD(0.42, -0.05, 0.0), R(0.1, 0.36, 0.92, 0.1), WR(-0.4), {"curl": 0.2, "ev": "effort", "fx": "trail_r"}])))
	k.append(K(5.42, M([C(0.3, 0.3), R(0.05, -0.05, 0.85, 0.1), WR(-0.6)])))
	# il se détourne, l'avant-bras gauche devant les yeux, les genoux remontés
	k.append(K(5.55, M([sit_floor(0.2, 1.1), C(0.32, 0.5, 0.12), HD(-0.2, 0.75, 0.25), L(-0.22, 0.42, 0.62, 0.4), WL(0.4), R(0.3, -0.2, 0.55, 0.2),
		FACE("asleep"), {"curl_l": 0.7, "curl": 0.6, "shake": 0.4}])))
	k.append(K(S_FLASH, M([C(0.38, 0.55, 0.15), HD(-0.28, 0.82, 0.28), L(-0.2, 0.44, 0.6, 0.4), {"shake": 0.9, "sq": 0.97}]), "s"))
	k.append(K(6.0, M([{"sq": 1.0, "shake": 0.7}])))
	# le blanc retombe : il baisse le bras, cligne, cherche autour de lui. Personne.
	k.append(K(6.2, M([C(0.25, 0.35, 0.08), HD(-0.05, 0.55, 0.15), L(-0.1, 0.25, 0.6, 0.3), FACE("pain"), {"shake": 0.5}])))
	k.append(K(6.42, M([sit_floor(0.25, 0.9), C(0.12, 0.05), HD(0.2, 0.1, 0.05), L(0.3, -0.35, 0.5, 0.2), R(0.3, -0.35, 0.5, 0.2), FACE("surprise"), {"shake": 0.3}])))
	blink(6.38, "surprise", k, 0.08)
	blink(6.54, "surprise", k, 0.06)
	k.append(K(6.62, M([C(0.12, -0.2), HD(0.22, -0.6, -0.05)]), "s"))
	k.append(K(6.86, M([C(0.12, 0.22), HD(0.18, 0.62, 0.05)]), "s"))
	k.append(K(7.04, M([C(0.1, 0.0), HD(0.1, 0.0, 0.0), {"shake": 0.15}])))
	# il souffle, la tête qui retombe, puis un petit rire nerveux, les mains sur les genoux
	k.append(K(7.2, M([sit_floor(0.12, 0.9), C(0.3), HD(-0.35, 0.0, 0.1), SH(-0.08, -0.08), R(0.22, -0.45, 0.55, 0.2), L(0.22, -0.45, 0.53, 0.2), FACE("tired"), {"jaw": 0.3, "shake": 0.0}])))
	k.append(K(7.36, M([C(0.18), HD(0.05, 0.05, 0.08), FACE("laugh"), {"jaw": 0.45}])))
	k.append(K(7.48, M([C(0.22), HD(0.0, 0.0, 0.1), {"jaw": 0.15}])))
	k.append(K(7.6, M([C(0.16), HD(0.08, -0.04, 0.06), {"jaw": 0.5}])))
	k.append(K(7.74, M([C(0.12), HD(0.05, 0.0, 0.05), FACE("smile"), {"jaw": 0.3}])))
	# la griffe sur son épaule : il se fige
	k.append(K(S_TOUCH + 0.02, M([C(0.1), HD(0.02, 0.0, 0.05), SH(0.3, 0.25), FACE("surprise"), {"jaw": 0.05}]), "s"))
	k.append(K(8.05, M([C(0.08), HD(0.12, 0.08, 0.0), FACE("fear"), {"shake": 0.45}])))
	blink(8.15, "fear", k, 0.08)
	# il lève la tête, lentement, jusqu'à la voir au-dessus de lui
	k.append(K(8.55, M([B(-0.08), C(0.05), HD(0.38, -0.05, 0.0), SH(0.2, 0.3), {"shake": 0.6, "jaw": 0.3}])))
	k.append(K(8.85, M([B(-0.12), C(0.0), HD(0.62, -0.02, 0.03), {"chatter": 0.6, "jaw": 0.45}]), "s"))
	k.append(K(S_KILL - 0.02, M([HD(0.68, 0.0, 0.05), {"face": "panic", "jaw": 0.9}])))
	# (noir) il s'effondre en avant
	k.append(K(S_KILL + 0.2, M([sit_floor(0.0, 0.3), B(0.6, 0.0, 0.15), TL(2.1, 0.12), KL(0.25, 0.3), TR(2.0, 0.15), KR(0.4, 0.25), C(0.5, 0.1, 0.15), HD(-0.5, 0.35, 0.2),
		SH(0.0, 0.0), Rg(0.35, 0.45, 0.0), Lg(0.25, 0.55, 0.0), {"face": "dead", "jaw": 0.25, "chatter": 0.0, "shake": 0.0, "curl": 0.3, "curl_l": 0.3, "ev": "death"}])))
	k.append(K(12.5, M([B(0.62, 0.0, 0.16), C(0.52, 0.1, 0.15), HD(-0.52, 0.35, 0.2)])))
	c["fa_simon"] = _film(0.0, 12.5, k, "panic")
	_simon_alice(c)


static func _simon_alice(c: Dictionary) -> void :
	var p: String = "Alice"
	var path: Array = simon_alice_path()
	var k: Array = []
	# là-bas, immobile, elle le regarde partir ; puis elle n'est plus là
	k.append(K(0.0, M([alice_stand(), HD(0.25, 0.0, 0.18)])))
	k.append(K(0.62, M([HD(0.3, 0.0, 0.1), C(0.33)])))
	k.append(K(0.92, M([{"fx": "ink_burst"}])))
	# devant lui : elle sort de l'ombre, droite, la tête qui suit sa glissade jusqu'à ses pieds
	k.append(K(1.22, M([alice_stand(), B(0.05), C(0.3), HD(0.18, 0.0, 0.05), L(0.38, -0.84, 0.12, 0.2), R(0.42, -0.8, 0.2, 0.25), {"curl": 0.15, "curl_l": 0.2, "fx": "shadow_rise"}])))
	k.append(K(1.6, M([C(0.34), HD(0.0, 0.0, 0.06)])))
	k.append(K(2.05, M([C(0.4), HD(-0.22, 0.02, 0.1), {"curl": 0.3, "curl_l": 0.35}]), "s"))
	blink(2.2, "menace", k)
	k.append(K(2.5, M([HD(-0.24, 0.05, 0.32)])))
	# deux pas, sans hâte, pendant qu'il recule
	var plants: Array = [[3.0, 1, 0.12, 0.8, -0.02], [3.8, -1, 0.12, 0.8, -0.02]]
	var walk: Dictionary = ALICE_WALK.duplicate()
	walk["from_rest"] = true
	walk["start"] = 2.6
	walk["swing"] = 0.4
	walk["hold"] = 6.3
	var feet: Dictionary = gait(k, p, path, Vector3(0, 0, -1), plants, walk)
	k.append(K(3.1, M([C(0.42, 0.04), HD(-0.26, -0.03, 0.22), L(0.4, -0.82, 0.16, 0.2), R(0.44, -0.75, 0.24, 0.25)])))
	k.append(K(3.9, M([C(0.44, -0.04), HD(-0.3, 0.03, 0.15)])))
	# elle le regarde fouiller sa poche, la tête qui penche d'un côté puis de l'autre
	k.append(K(4.3, M([HD(-0.32, 0.0, -0.22), {"curl": 0.2}])))
	k.append(K(S_PIN + 0.05, M([HD(-0.3, 0.02, -0.28), FACE("grin")])))
	# il lui crache la goupille dessus : la griffe droite monte et la cueille au vol, sans hâte
	k.append(K(S_SPIT, M([R(0.32, -0.5, 0.42, 0.3), WR(0.2), {"curl": 0.1}])))
	k.append(K(S_CATCH - 0.04, M([R(0.2, -0.32, 0.62, 0.3), WR(-0.2), {"curl": 0.05}])))
	k.append(K(S_CATCH, M([R(0.2, -0.31, 0.62, 0.3), {"curl": 0.55}]), "s"))
	# elle l'examine de près, la tête penchée : la grenade ne l'intéresse pas
	k.append(K(5.2, M([R(0.08, 0.12, 0.42, 0.35), WR(-0.5, 0.4), C(0.36), HD(-0.12, -0.05, -0.3), FACE("calm")])))
	k.append(K(5.42, M([R(0.07, 0.14, 0.4, 0.35), HD(-0.1, -0.06, -0.34)]), "s"))
	# … et elle ferme les yeux, calmement, avant le flash
	k.append(K(5.6, M([HD(-0.05, 0.0, -0.2), FACE("asleep")])))
	k.append(K(6.3, M([alice_stand(), {"foot_l": feet[-1], "foot_r": feet[1], "fp_l": 0.0, "fp_r": 0.0}])))
	# derrière lui : elle sort de l'ombre, penchée, la griffe droite qui descend sur son épaule
	var rise: Dictionary = M([{"plant": 1.0, "foot_l": Vector3.ZERO, "foot_r": Vector3.ZERO}, H(0, -0.06, 0.04), B(0.3), C(0.45), HD(-0.35, 0.0, 0.1),
		R(0.3, -0.55, 0.35, 0.25), WR(-0.2), L(0.1, -0.2, 0.62, 0.3), WL(-0.3), {"curl": 0.55, "curl_l": 0.05, "face": "calm"}])
	k.append(K(6.5, rise))
	k.append(K(S_BACK - 0.05, M([rise, {"fx": "shadow_rise"}])))
	k.append(K(7.45, M([H(0, -0.25, 0.04), B(0.38), C(0.48), HD(-0.45, 0.0, -0.1), L(0.12, -0.3, 0.5, 0.3), WL(-0.2)])))
	k.append(K(S_TOUCH - 0.06, M([H(0, -0.38, 0.04), B(0.42), C(0.5), HD(-0.5, 0.0, -0.12), L(0.16, -0.8, 0.46, 0.25), WL(0.1), {"curl_l": 0.15}])))
	k.append(K(S_TOUCH, M([L(0.16, -0.86, 0.46, 0.25), {"curl_l": 0.35}]), "s"))
	k.append(K(S_TOUCH + 0.12, M([{"curl_l": 0.62, "face": "menace"}])))
	# il lève la tête : elle se redresse un peu, le visage penché au-dessus du sien
	k.append(K(8.4, M([H(0, -0.38, 0.04), B(0.36), C(0.42), HD(-0.75, 0.0, -0.1), L(0.17, -0.88, 0.44, 0.25)])))
	k.append(K(8.75, M([B(0.34), C(0.4), HD(-0.85, 0.0, -0.05), FACE("grin")]), "s"))
	k.append(K(9.0, M([H(0, -0.38, 0.04), HD(-0.85, 0.0, -0.32)]), "s"))
	k.append(K(S_KILL - 0.04, M([H(0, -0.36, 0.04), R(0.4, 0.1, 0.3, 0.6), WR(-0.5), {"curl": 0.6}])))
	k.append(K(S_KILL + 0.05, M([R(-0.05, -0.62, 0.62, 0.2), WR(0.5), {"fx": "claw_r trail_r", "ev": "grunt"}])))
	# elle se redresse, regarde la goupille, tend le bras sur le côté… et la lâche
	k.append(K(9.65, M([H(0, -0.03, 0.02), B(0.12), C(0.32), HD(-0.2, 0.0, 0.1), R(0.3, -0.5, 0.35, 0.3), WR(-0.2), L(0.4, -0.8, 0.18, 0.2), WL(-0.35),
		{"curl": 0.55, "curl_l": 0.35, "face": "calm"}])))
	k.append(K(9.95, M([B(0.08), C(0.32), HD(-0.25, 0.05, 0.15), R(0.08, -0.12, 0.6, 0.35), WR(-0.6, 0.3)])))
	k.append(K(10.12, M([HD(-0.28, 0.1, 0.25)]), "s"))
	k.append(K(S_DROP - 0.06, M([R(0.85, -0.3, 0.3, 0.3), WR(0.2, 0.0), HD(-0.3, -0.35, 0.1)])))
	k.append(K(S_DROP, M([R(0.86, -0.31, 0.3, 0.3), {"curl": 0.05}]), "s"))
	k.append(K(10.75, M([R(0.45, -0.75, 0.25, 0.25), WR(-0.3), HD(-0.42, -0.2, 0.05), FACE("menace"), {"curl": 0.25}])))
	blink(10.95, "menace", k)
	k.append(K(11.4, M([HD(-0.38, -0.18, 0.12)]), "s"))
	k.append(K(12.5, M([HD(-0.36, -0.17, 0.14), R(0.44, -0.76, 0.25, 0.25)])))
	c["fa_simon_alice"] = _film(0.0, 12.5, k, "menace")


# ----------------------------------------------------------------- USAYUKO --
# « Derrière moi ». Usayuko ne tourne jamais le dos : il recule garde haute, Alice avance. Son
# talon accroche, il part à la renverse, à plat dos. Il se relève, s'essuie la bouche, sourit,
# roule des épaules… et la charge pour la plaquer. Elle recule d'un pas sous le choc, puis plus
# rien ne bouge. Elle pose ses griffes sur ses épaules et l'enfonce à genoux. Il lève les yeux,
# sourit encore. Le coup, en silhouette. Elle époussette sa robe là où il l'a tenue.

const U_TRIP: float = 2.55
const U_FLOOR: float = 2.95
const U_UP: float = 4.55
const U_CHARGE: float = 5.3
const U_HIT: float = 5.78
const U_STOP: float = 5.98
const U_KNEE: float = 6.8
const U_KILL: float = 8.38

static func usayuko_path() -> Array:
	return [[0.0, Vector3(0.2, 0, -0.7)], [2.5, Vector3(0.2, 0, 1.15)], [2.62, Vector3(0.2, 0, 1.25)], [2.85, Vector3(0.2, 0, 1.42)], [3.0, Vector3(0.2, 0, 1.5)],
		[3.6, Vector3(0.2, 0, 1.5)], [4.0, Vector3(0.2, 0, 1.45)], [4.55, Vector3(0.22, 0, 1.4)], [U_CHARGE, Vector3(0.24, 0, 1.4)],
		[U_HIT, Vector3(0.4, 0, -0.82)], [U_STOP, Vector3(0.4, 0, -1.04)], [6.5, Vector3(0.36, 0, -1.07)], [U_KNEE, Vector3(0.2, 0, -1.4)], [12.0, Vector3(0.2, 0, -1.4)]]

static func usayuko_alice_path() -> Array:
	return [[0.0, Vector3(0.15, 0, -3.3)], [0.45, Vector3(0.15, 0, -3.3)], [2.75, Vector3(0.15, 0, -1.55)], [3.15, Vector3(0.15, 0, -1.35)],
		[U_HIT, Vector3(0.15, 0, -1.35)], [U_STOP, Vector3(0.15, 0, -1.62)], [12.0, Vector3(0.15, 0, -1.62)]]


# garde de boxe (poings devant le menton)
static func guard(bounce: float = 0.0) -> Dictionary:
	return M([H(0, -0.08 + bounce, 0.0), B(0.12), C(0.08), HD(-0.08), R(0.06, 0.26, 0.55, 0.25), L(0.1, 0.3, 0.48, 0.25), WR(-0.3), WL(-0.3), {"curl": 1.0, "curl_l": 1.0}])


static func _usayuko(c: Dictionary) -> void :
	var p: String = "Usayuko"
	var path: Array = usayuko_path()
	var face_dir: Vector3 = Vector3(0, 0, -1)
	var k: Array = []
	# --- FUITE : il recule pas à pas, garde haute, sans la quitter des yeux
	k.append(K(0.0, M([_zero(), guard(), FACE("determined"), {"jaw": 0.1}])))
	var plants: Array = cadence(0.12, 2.3, 0.5, 0.32, 1, -0.24, 41.0, {"vary": 0.08})
	gait(k, p, path, face_dir, plants, {"kick": 0.05, "pass": 0.07, "reach_h": 0.03, "strike": 0.0, "push": -0.25, "heel": 0.2, "bob_low": 0.03, "bob_high": 0.012,
		"walk": true, "sway": 0.03, "yaw": 0.06, "roll": 0.03, "lean": 0.12, "base": Vector3(0, -0.08, 0), "leave": [-1]})
	for n: int in range(plants.size()):
		var t: float = float(plants[n][0])
		k.append(K(t + 0.1, M([C(0.08 + J(n, 1.0) * 0.04, J(n, 2.0) * 0.08), HD(-0.08 + J(n, 3.0) * 0.05, J(n, 4.0) * 0.1, J(n, 5.0) * 0.05),
			R(0.06, 0.26 + J(n, 6.0) * 0.04, 0.55), L(0.1, 0.3 + J(n, 7.0) * 0.04, 0.48)])))
	blink(0.8, "determined", k)
	# un coup d'œil par-dessus l'épaule droite (où il va ?), puis de nouveau sur elle
	carve(k, ["head", "chest"], 1.2, 1.75)
	k.append(K(1.26, M([C(0.06, -0.25), HD(0.0, -1.05, -0.05), FACE("fear")])))
	k.append(K(1.45, M([C(0.06, -0.3), HD(0.02, -1.15, -0.08)]), "s"))
	k.append(K(1.62, M([C(0.08, 0.0), HD(-0.08, 0.02, 0.0), FACE("angry"), {"jaw": 0.25}])))

	# --- CHUTE : le talon gauche accroche, il part à la renverse, à plat dos
	k.append(K(2.4, M([{"foot_l": Vector3(0.0, 0.06, 0.4), "fp_l": 0.0}])))
	k.append(K(U_TRIP, M([{"foot_l": Vector3(0.0, 0.0, 0.52), "fp_l": 0.35}, B(-0.15), C(0.0), HD(0.1), R(0.32, 0.42, 0.5, 0.4), L(0.36, 0.5, 0.42, 0.4),
		{"curl": 0.15, "curl_l": 0.15, "face": "surprise", "ev": "gasp", "jaw": 0.6}]), "l"))
	k.append(K(2.7, M([{"foot_r": Vector3(0.0, 0.25, -0.4), "fp_r": 0.4}, H(0, -0.3, -0.2), B(-0.55), C(-0.1), HD(0.35), R(0.45, 0.65, 0.2, 0.5), L(0.2, 0.3, 0.62, 0.3)])))
	k.append(K(2.82, M([{"plant": 0.0, "gsnap": 1.0}, H(0, -1.0, -0.3), B(-0.95), C(-0.1), HD(0.25), TL(1.15, 0.12), KL(0.5, 0.2), TR(1.4, 0.15), KR(0.3, 0.2),
		Rg(0.55, -0.3, 0.1), Lg(0.6, -0.25, 0.1), {"fx": "dust_ring", "ev": "hurt", "sq": 0.94}])))
	# le dos claque au sol, les jambes montent puis retombent, la tête rebondit
	k.append(K(U_FLOOR, M([B(-1.48), C(-0.05), HD(0.4), TL(0.65, 0.15), KL(0.35, 0.1), TR(0.85, 0.18), KR(0.2, 0.1), Rg(0.85, -0.15, 0.0), Lg(0.9, -0.1, 0.0),
		{"fx": "land_hard", "face": "pain", "sq": 1.0}]), "s"))
	k.append(K(3.05, M([HD(-0.15, 0.1, 0.05), {"fx": "stars"}])))
	k.append(K(3.2, M([B(-1.5), HD(0.15, 0.2, 0.1), TL(0.08, 0.15), KL(0.3, 0.1), TR(0.12, 0.2), KR(0.4, 0.1), FACE("dazed"), {"jaw": 0.3}]), "s"))
	# il se redresse sur les mains, secoue la tête
	k.append(K(3.55, M([B(-0.62), C(0.12), HD(0.05, 0.0, 0.0), TL(0.9, 0.15), KL(0.7, 0.1), TR(1.0, 0.18), KR(0.5, 0.1), Rg(0.35, -0.35, 0.0), Lg(0.4, -0.3, 0.0), FACE("hurt")])))
	k.append(K(3.68, M([HD(0.0, 0.3, -0.15)])))
	k.append(K(3.78, M([HD(0.05, -0.3, 0.15)])))
	# un genou au sol, il s'essuie la bouche du revers du pouce… et sourit
	var knee: Dictionary = M([{"plant": 0.0, "gsnap": 1.0}, H(0, -0.55, 0.0), B(0.1), TL(1.5, 0.12), KL(1.55, 0.0), TR(0.1, 0.1), KR(1.6, 0.4)])
	k.append(K(3.98, M([knee, C(0.15), HD(0.15, 0.05, 0.0), R(0.25, -0.35, 0.45, 0.3), L(0.2, -0.5, 0.55, 0.2), {"curl": 0.5, "curl_l": 0.5, "face": "angry"}])))
	k.append(K(4.1, M([R(-0.42, 0.6, 0.4, 0.5), WR(-0.4, 0.3), HD(0.2, 0.1, 0.05), {"curl": 0.8}])))
	k.append(K(4.24, M([R(-0.1, 0.55, 0.42, 0.5), HD(0.18, -0.05, 0.0)])))
	k.append(K(4.34, M([R(0.25, -0.3, 0.45, 0.3), FACE("grin"), {"jaw": 0.2}])))
	# il se relève
	k.append(K(U_UP, M([_zero(), H(0, -0.06, 0.0), B(0.06), C(0.05), HD(0.05), R(0.35, -0.75, 0.15, 0.2), L(0.35, -0.75, 0.15, 0.2), {"curl": 0.6, "curl_l": 0.6, "face": "grin"}])))
	# il roule des épaules, fait craquer sa nuque, lève la garde
	k.append(K(4.72, M([SH(0.35, 0.0, -0.1, 0.0), C(0.05, 0.12)])))
	k.append(K(4.86, M([SH(0.0, 0.35, 0.0, -0.1), C(0.05, -0.12)])))
	k.append(K(4.98, M([SH(0.0, 0.0), HD(0.05, 0.0, 0.4)]), "s"))
	k.append(K(5.08, M([HD(0.0, 0.0, -0.1), guard(0.0), FACE("determined")])))
	k.append(K(5.2, M([guard(-0.06), {"gsnap": 0.0, "plant": 1.0}])))
	# --- DÉFENSE : il charge pour la plaquer, l'épaule dans le ventre
	var charge: Array = [[5.36, -1, 0.3, 0.13], [5.57, 1, 0.38, 0.13], [U_HIT - 0.02, -1, 0.42, 0.12]]
	gait(k, p, path, face_dir, charge, {"kick": 0.3, "pass": 0.22, "reach_h": 0.08, "strike": 0.1, "push": -0.8, "heel": 0.25, "bob_low": 0.07, "bob_high": 0.03,
		"lean": 0.55, "yaw": 0.1, "roll": 0.04, "base": Vector3(0, -0.12, 0.05), "start": U_CHARGE, "hold": U_STOP + 0.3})
	k.append(K(5.45, M([C(0.3), HD(0.35), R(0.45, -0.05, 0.5, 0.4), L(0.45, -0.05, 0.5, 0.4), {"curl": 0.4, "curl_l": 0.4, "face": "angry", "jaw": 0.5, "ev": "effort"}])))
	k.append(K(U_HIT, M([H(0, -0.22, 0.12), B(0.62), C(0.42), HD(0.45, 0.3, 0.0), R(0.12, -0.32, 0.72, 0.3), L(0.12, -0.32, 0.72, 0.3), {"curl": 0.7, "curl_l": 0.7, "sq": 0.97}])))
	k.append(K(U_STOP, M([H(0, -0.25, 0.2), B(0.7), C(0.45), {"sq": 1.0, "jaw": 0.8, "shake": 0.5}]), "s"))
	# elle ne bouge plus : il pousse, ses pieds patinent, puis les griffes sur ses épaules l'enfoncent
	k.append(K(6.3, M([H(0, -0.3, 0.22), B(0.72), HD(0.5, 0.3, 0.05), {"shake": 0.8, "face": "pain", "gsnap": 0.0, "plant": 1.0}])))
	k.append(K(6.55, M([{"plant": 1.0, "gsnap": 0.0}, H(0, -0.6, 0.15), B(0.4), C(0.25), HD(0.4, 0.1, 0.0), R(0.2, -0.3, 0.6, 0.3), L(0.2, -0.3, 0.6, 0.3)])))
	var kneel: Dictionary = M([{"plant": 0.0, "gsnap": 1.0}, H(0, -0.8, 0.0), TL(0.05, 0.12), KL(1.6, 0.4), TR(0.08, 0.14), KR(1.6, 0.4)])
	k.append(K(U_KNEE, M([kneel, B(-0.04), C(0.0), HD(0.6, 0.0, 0.0), R(0.15, 0.2, 0.62, 0.4), L(0.15, 0.2, 0.62, 0.4), WR(0.4), WL(0.4),
		{"fx": "dust", "curl": 0.85, "curl_l": 0.85, "shake": 0.6, "jaw": 0.4}]), "s"))
	# à genoux : il serre les dents… lève les yeux sur elle, et sourit quand même
	k.append(K(7.2, M([B(0.0), HD(0.68, 0.05, 0.05), {"face": "pain", "jaw": 0.15, "shake": 0.7}])))
	k.append(K(7.6, M([HD(0.72, -0.02, 0.1), {"face": "angry", "shake": 0.4}])))
	blink(7.8, "angry", k)
	k.append(K(7.95, M([HD(0.74, 0.0, 0.12), {"face": "grin", "jaw": 0.2, "shake": 0.2}])))
	k.append(K(8.15, M([{"jaw": 0.35}])))
	k.append(K(8.25, M([{"jaw": 0.1}]), "s"))
	# le coup : la tête part, le corps se raidit puis bascule sur le côté
	k.append(K(U_KILL + 0.02, M([B(0.1, 0.25, -0.1), C(-0.1, 0.2), HD(0.2, 0.5, -0.3), R(0.4, -0.2, 0.4, 0.4), L(0.3, 0.1, 0.5, 0.4), {"face": "pain", "jaw": 0.7, "shake": 0.0, "ev": "hurt"}])))
	k.append(K(8.6, M([B(0.2, 0.2, -0.25), C(0.2, 0.1), HD(-0.2, 0.3, -0.2), R(0.4, -0.6, 0.3, 0.2), L(0.4, -0.6, 0.3, 0.2), {"face": "dead", "jaw": 0.3, "curl": 0.3, "curl_l": 0.3}])))
	k.append(K(8.85, M([B(0.35, 0.3, -0.7), C(0.2, 0.1, -0.2), HD(-0.1, 0.3, -0.3), {"ev": "death"}])))
	k.append(K(9.12, M([B(0.3, 0.3, -1.42), C(0.1, 0.1, -0.15), HD(0.0, 0.2, -0.25), TL(0.5, 0.2), KL(1.1, 0.3), TR(0.4, 0.2), KR(1.2, 0.3),
		Rg(0.6, 0.3, 0.0), Lg(0.5, 0.5, 0.2), {"fx": "dust_ring", "sq": 0.97}]), "s"))
	k.append(K(9.3, M([{"sq": 1.0}])))
	k.append(K(12.5, M([B(0.3, 0.3, -1.43)])))
	c["fa_usayuko"] = _film(0.0, 12.5, k, "determined")
	_usayuko_alice(c)


static func _usayuko_alice(c: Dictionary) -> void :
	var p: String = "Alice"
	var path: Array = usayuko_alice_path()
	var k: Array = []
	k.append(K(0.0, M([alice_stand(), HD(0.2, 0.0, 0.12)])))
	# elle avance, sans hâte, plus vite qu'il ne recule
	var plants: Array = cadence(0.62, 2.7, 0.56, 0.72, 1, 0.24, 57.0, {"vary": 0.04, "width": -0.02})
	plants.append([float(plants[plants.size() - 1][0]) + 0.5, - int(plants[plants.size() - 1][1]), 0.18, 0.7, -0.02])
	var walk: Dictionary = ALICE_WALK.duplicate()
	walk["from_rest"] = true
	walk["start"] = 0.4
	walk["hold"] = U_HIT
	var feet: Dictionary = gait(k, p, path, Vector3(0, 0, 1), plants, walk)
	alice_walk_upper(k, plants, {"tilt": 0.1, "look": 0.2})
	# il tombe : elle penche la tête pour le regarder
	k.append(K(3.3, M([C(0.4), HD(-0.1, 0.0, 0.25), L(0.4, -0.82, 0.16, 0.2), R(0.44, -0.75, 0.26, 0.25), {"curl": 0.25, "curl_l": 0.3}])))
	k.append(K(4.3, M([C(0.38), HD(0.0, 0.03, -0.22)]), "s"))
	blink(4.5, "menace", k)
	k.append(K(5.0, M([C(0.36), HD(0.08, 0.0, -0.05)]), "s"))
	# le choc : elle glisse d'une demi-foulée sous la charge… puis plus rien ne bouge
	var stand: Dictionary = M([{"foot_l": feet[-1], "foot_r": feet[1], "fp_l": 0.0, "fp_r": 0.0}])
	k.append(K(U_HIT - 0.02, M([stand, B(0.1), C(0.36), HD(0.05, 0.0, -0.05), L(0.4, -0.82, 0.16, 0.2), R(0.44, -0.75, 0.26, 0.25)])))
	k.append(K(U_HIT + 0.06, M([B(0.0), C(0.25), HD(0.12, 0.0, 0.0), L(0.55, -0.6, 0.2, 0.4), R(0.55, -0.55, 0.25, 0.4), {"curl": 0.05, "curl_l": 0.05}])))
	k.append(K(U_STOP, M([B(0.08), C(0.32), HD(-0.2, 0.0, 0.05)]), "s"))
	# les griffes se posent sur ses épaules, puis l'enfoncent à genoux
	k.append(K(6.2, M([B(0.2), C(0.45), HD(-0.4, 0.0, 0.1), L(0.6, -0.28, 0.2, 0.3), R(-0.35, -0.28, 0.2, 0.3), WL(0.2), WR(0.2), {"curl": 0.2, "curl_l": 0.2}])))
	k.append(K(6.45, M([L(0.72, -0.42, 0.14, 0.3), R(-0.46, -0.42, 0.16, 0.3), {"curl": 0.65, "curl_l": 0.65, "face": "menace"}]), "s"))
	k.append(K(U_KNEE, M([B(0.28), C(0.5), HD(-0.55, 0.0, 0.08), L(0.32, -0.88, 0.37, 0.3), R(-0.05, -0.88, 0.37, 0.3)]), "s"))
	k.append(K(7.4, M([HD(-0.6, 0.0, 0.3)]), "s"))
	# la griffe droite le lâche et monte… le coup, en diagonale
	k.append(K(7.95, M([HD(-0.58, 0.0, 0.15), L(0.32, -0.88, 0.37, 0.3), R(0.3, -0.3, 0.45, 0.4), {"face": "grin"}])))
	k.append(K(8.22, M([B(0.2), C(0.4, -0.25), R(0.55, 0.62, 0.0, 0.7), WR(-0.6), {"curl": 0.0}]), "s"))
	k.append(K(U_KILL, M([B(0.35), C(0.58, 0.3), R(-0.15, -0.55, 0.75, 0.3), WR(0.6), {"curl": 0.7, "fx": "claw_r trail_r", "ev": "grunt"}])))
	k.append(K(8.55, M([C(0.55, 0.25), R(-0.25, -0.75, 0.5, 0.3)]), "s"))
	# elle le lâche
	k.append(K(8.75, M([B(0.12), C(0.4, 0.05), HD(-0.4, 0.0, 0.1), L(0.4, -0.75, 0.25, 0.25), R(0.4, -0.8, 0.22, 0.25), {"curl": 0.3, "curl_l": 0.35, "face": "calm"}])))
	# elle le regarde, puis époussette sa robe du revers de la griffe, là où il l'a tenue
	k.append(K(9.4, M([C(0.42), HD(-0.5, 0.05, 0.2)]), "s"))
	k.append(K(9.9, M([B(0.08), C(0.32), HD(-0.2, 0.0, 0.05), R(0.2, -0.4, 0.3, 0.3), WR(0.6, 0.0, 0.3)])))
	k.append(K(10.15, M([R(-0.08, -0.45, 0.28, 0.3), WR(0.7, 0.0, 0.4), HD(-0.35, 0.05, 0.05)])))
	k.append(K(10.32, M([R(0.18, -0.42, 0.3, 0.3)])))
	k.append(K(10.5, M([R(-0.06, -0.46, 0.27, 0.3)])))
	k.append(K(10.8, M([R(0.42, -0.78, 0.24, 0.25), WR(-0.3, 0.0, 0.0), HD(-0.2, 0.0, 0.05)])))
	# … et lève les yeux sur nous
	k.append(K(11.2, M([HD(0.15, 0.03, 0.2), FACE("grin")])))
	blink(11.7, "grin", k)
	k.append(K(12.5, M([HD(0.16, 0.04, 0.22)])))
	c["fa_usayuko_alice"] = _film(0.0, 12.5, k, "menace")
