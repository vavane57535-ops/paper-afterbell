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

# mesures du squelette, en mètres (tools/film_alice_lab.gd --fal-mode measure)
const LEG: Dictionary = {"Simon": 0.699, "Usayuko": 0.675, "Ashura": 0.645, "Lysia": 0.864, "Elly": 0.783, "Bleuette": 0.683, "Alice": 0.863}
const ARM: Dictionary = {"Simon": 0.401, "Usayuko": 0.364, "Ashura": 0.469, "Lysia": 0.409, "Elly": 0.404, "Bleuette": 0.312, "Alice": 0.432}
# pied (cheville → orteils) en longueurs de jambe
const TOE: Dictionary = {"Simon": 0.15, "Usayuko": 0.027, "Ashura": 0.066, "Lysia": 0.029, "Elly": 0.214, "Bleuette": 0.091, "Alice": 0.135}
# pied au repos dans le repère du perso (m) : écart (× « stance » du style) et recul
const FOOT_X: Dictionary = {"Simon": 0.103, "Usayuko": 0.197, "Ashura": 0.187, "Lysia": 0.103, "Elly": 0.148, "Bleuette": 0.103, "Alice": 0.068}
const FOOT_Z: Dictionary = {"Simon": 0.027, "Usayuko": -0.011, "Ashura": 0.067, "Lysia": 0.084, "Elly": 0.022, "Bleuette": 0.033, "Alice": 0.055}

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
static func blink(t: float, after: String, keys: Array, hold: float = 0.08) -> void :
	keys.append(K(t, FACE("asleep")))
	keys.append(K(t + hold, FACE(after)))

# bruit déterministe dans [-0.5, 0.5] (le film est le même chez tous les joueurs)
static func J(i: int, salt: float) -> float:
	return fposmod(sin(float(i) * 12.9898 + salt * 78.233) * 43758.5453, 1.0) - 0.5


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

# point d'appui au sol (repère du film)
static func plant_at(person: String, path: Array, dir: Vector3, t: float, side: int, reach: float, width: float = 0.0) -> Vector3:
	return at(path, t) + dir * reach + side_of(dir) * (float(side) * (float(FOOT_X[person]) + width))

# valeur du canal foot_l / foot_r qui pose le pied sur `spot` quand le bassin est en `root`
static func foot_on(person: String, side: int, spot: Vector3, root: Vector3, dir: Vector3, up: float = 0.0) -> Vector3:
	var leg: float = float(LEG[person])
	var v: Vector3 = spot - root
	return Vector3((v.dot(side_of(dir)) - float(side) * float(FOOT_X[person])) / leg, up, (- v.dot(dir) - float(FOOT_Z[person])) / leg)


# Pas posés au sol. steps : [[t_pose, côté (-1 gauche, 1 droit), avance au poser
# (m devant le bassin), durée d'appui (s), écart en plus (m, facultatif)], ...].
# Pendant l'appui le pied reste sur son point du sol pendant que le corps suit
# `path` (pas de glissement) ; puis le talon monte, le genou repasse devant et
# le pied se repose au pas suivant. Le dernier appui de chaque pied reste posé.
# o : width (m), kick et knee (hauteur du pied en l'air, longueurs de jambe),
# strike (pied au poser : + pointe levée), push (à l'envol), bob et rise (bassin
# à l'appui / en l'air), base (bassin, Vector3(droite, haut, avant)), sway (bassin
# vers le pied d'appui, m), yaw (rotation du bassin), lean (buste en avant),
# hips (false : pas de clés de bassin), fx (bruits de pas), hold (le dernier appui
# reste posé jusqu'à cet instant, sinon jusqu'au bout du trajet).
static func steps(person: String, k: Array, path: Array, dir: Vector3, list: Array, o: Dictionary = {}) -> Dictionary:
	var leg: float = float(LEG[person])
	var toe: float = float(TOE[person])
	var width: float = float(o.get("width", 0.0))
	var kick: float = float(o.get("kick", 0.35))
	var knee: float = float(o.get("knee", 0.22))
	var strike: float = float(o.get("strike", -0.05))
	var push: float = float(o.get("push", -0.55))
	var bob: float = float(o.get("bob", 0.05))
	var rise: float = float(o.get("rise", 0.02))
	var base: Vector3 = o.get("base", Vector3(0.0, -0.06, 0.0))
	var sway: float = float(o.get("sway", 0.02))
	var yaw: float = float(o.get("yaw", 0.08))
	var lean: float = float(o.get("lean", 0.0))
	var hips: bool = bool(o.get("hips", true))
	var sound: bool = bool(o.get("fx", true))
	var hold: float = float(o.get("hold", 1000.0))
	var spots: Array = []
	var last: Dictionary = {}
	for step: Array in list:
		spots.append(plant_at(person, path, dir, float(step[0]), int(step[1]), float(step[2]), width + (float(step[4]) if step.size() > 4 else 0.0)))
		last[int(step[1])] = spots[spots.size() - 1]
	for i: int in range(list.size()):
		var step: Array = list[i]
		var t0: float = float(step[0])
		var side: int = int(step[1])
		var t1: float = t0 + float(step[3])
		var channel: String = "foot_l" if side < 0 else "foot_r"
		var pitch: String = "fp_l" if side < 0 else "fp_r"
		var spot: Vector3 = spots[i]
		k.append([t0, {channel: foot_on(person, side, spot, at(path, t0), dir), pitch: strike}, "l"])
		if sound: k.append([t0, {"fx": "step_l" if side < 0 else "step_r"}])
		var next: int = -1
		for j: int in range(i + 1, list.size()):
			if int(list[j][1]) == side:
				next = j
				break
		if next < 0:
			# dernier appui de ce pied : il reste posé jusqu'au bout du trajet
			k.append([minf(t1, t0 + 0.12), {pitch: 0.0}])
			for point: Array in path:
				if float(point[0]) > t0 + 0.002 and float(point[0]) <= hold: k.append([float(point[0]), {channel: foot_on(person, side, spot, point[1], dir)}, "l"])
			continue
		for point: Array in path:
			var tp: float = float(point[0])
			if tp > t0 + 0.002 and tp < t1 - 0.002: k.append([tp, {channel: foot_on(person, side, spot, point[1], dir)}, "l"])
		var lift: float = toe * sin( - push)
		var off: Vector3 = foot_on(person, side, spot, at(path, t1), dir, lift)
		k.append([t1, {channel: off, pitch: push}])
		var t2: float = float(list[next][0])
		var land: Vector3 = foot_on(person, side, spots[next], at(path, t2), dir)
		var swing: float = t2 - t1
		k.append([t1 + swing * 0.3, {channel: Vector3(lerpf(off.x, land.x, 0.3), kick, lerpf(off.z, land.z, 0.12)), pitch: push - 0.3}])
		k.append([t1 + swing * 0.6, {channel: Vector3(lerpf(off.x, land.x, 0.75), knee, lerpf(off.z, land.z, 0.66)), pitch: push * 0.4}])
		k.append([t1 + swing * 0.86, {channel: Vector3(land.x, maxf(0.03, knee * 0.22), land.z - 0.06), pitch: strike + 0.12}])
	# pieds posés à la fin du trajet (pour enchaîner sans glissement)
	var end: Vector3 = path[path.size() - 1][1]
	var result: Dictionary = {}
	for side: int in last: result[side] = foot_on(person, side, last[side], end, dir)
	if not hips: return result
	for i: int in range(list.size()):
		var t0: float = float(list[i][0])
		var side: int = int(list[i][1])
		var stance: float = float(list[i][3])
		var amp: float = 1.0 + J(i, 3.1) * 0.3
		k.append([t0 + stance * 0.45, {"hips": Vector3(base.x + float(side) * sway / leg, base.y - bob * amp, - base.z), "body": Vector3( - lean, float(side) * yaw * amp, - float(side) * yaw * 0.3)}])
		if i + 1 < list.size():
			var t1: float = t0 + stance
			var tn: float = float(list[i + 1][0])
			if tn > t1 + 0.03: k.append([(t1 + tn) * 0.5, {"hips": Vector3(base.x, base.y + rise, - base.z)}])
	return result


# Bras et buste d'une course : le bras opposé au pied posé part devant, le
# buste se tord, la tête reste stable. Une clé par appui, amplitudes variées.
# o : lag (s après le poser), lean (buste), twist, head (tête : haut/bas),
# front / back (Vector3 main devant / derrière : dehors, haut, avant), flare,
# wild (désordre des bras, 0..1), curl, skip (côtés à ne pas toucher : "l", "r")
static func pump(k: Array, list: Array, o: Dictionary = {}) -> void :
	var lag: float = float(o.get("lag", 0.03))
	var lean: float = float(o.get("lean", 0.12))
	var twist: float = float(o.get("twist", 0.16))
	var head: float = float(o.get("head", 0.0))
	var front: Vector3 = o.get("front", Vector3(0.06, -0.3, 0.55))
	var back: Vector3 = o.get("back", Vector3(0.18, -0.62, -0.35))
	var flare: float = float(o.get("flare", 0.25))
	var wild: float = float(o.get("wild", 0.0))
	var curl: float = float(o.get("curl", 0.6))
	var skip: String = str(o.get("skip", ""))
	for i: int in range(list.size()):
		var t: float = float(list[i][0]) + lag
		var side: int = int(list[i][1])
		var amp: float = 1.0 + J(i, 7.7) * 0.25
		var pose: Dictionary = {"chest": Vector3( - lean, - float(side) * twist * amp, 0.0), "head": Vector3(head + J(i, 2.2) * 0.04, float(side) * twist * amp * 0.8, J(i, 5.3) * 0.05)}
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


# ----------------------------------------------------------------- BLEUETTE --
# Elle court en serrant sa barre de chocolat, se prend les pieds dans les
# siens et s'étale. Assise, elle recule sur les fesses ; Alice arrive. Bleuette
# lui lance son chocolat : Alice l'attrape au vol sans la quitter des yeux.
# Elle s'accroupit à sa hauteur, lève la griffe : on ne voit que la barre
# tombée par terre et la main qui retombe à côté. Alice se relève et croque
# dans le chocolat.

const B_FALL: float = 2.5
const B_THROW: float = 6.32
const B_CATCH: float = 6.62
const B_KILL: float = 8.78

# trajets (repère du film) : film_alice_kill.gd les donne aux corps
static func bleuette_path() -> Array:
	return [[0.0, Vector3(0.3, 0, -3.6)], [B_FALL, Vector3(0.2, 0, 2.9)], [2.78, Vector3(0.2, 0, 3.42)], [3.02, Vector3(0.2, 0, 3.72)],
		[3.2, Vector3(0.2, 0, 3.82)], [4.3, Vector3(0.2, 0, 3.82)], [4.62, Vector3(0.22, 0, 3.95)], [5.1, Vector3(0.25, 0, 4.35)],
		[5.6, Vector3(0.28, 0, 4.62)], [12.0, Vector3(0.28, 0, 4.62)]]

static func bleuette_alice_path() -> Array:
	return [[0.0, Vector3(-0.2, 0, -6.4)], [5.95, Vector3(0.22, 0, 3.32)], [12.0, Vector3(0.22, 0, 3.32)]]


static func _bleuette(c: Dictionary) -> void :
	var p: String = "Bleuette"
	var path: Array = bleuette_path()
	var fwd: Vector3 = Vector3(0, 0, 1)
	var k: Array = []
	# --- FUITE (0 → 2,5) : petite course paniquée, chocolat serré dans la main droite
	var run: Array = []
	var t: float = 0.02
	var side: int = -1
	var i: int = 0
	while t < B_FALL - 0.2:
		var period: float = 0.3 + J(i, 11.0) * 0.03
		run.append([t, side, 0.3 + J(i, 12.0) * 0.04, 0.12 + J(i, 13.0) * 0.015])
		t += period
		side = - side
		i += 1
	k.append(K(0.0, M([_zero(), H(0, -0.07, 0), B(0.2), C(0.08), HD(0.05),
		Lt(0.12, -0.35, 0.4, 0.4), Rt(0.08, -0.4, 0.3, 0.3), FL(0.0, 0.2, 0.15), FR(0.0, -0.25, 0.1),
		{"curl": 0.9, "curl_l": 0.4, "prop": "chocolate", "face": "panic", "jaw": 0.35}])))
	steps(p, k, path, fwd, run, {"kick": 0.42, "knee": 0.3, "bob": 0.06, "rise": 0.03, "base": Vector3(0, -0.07, 0), "sway": 0.025, "yaw": 0.1, "lean": 0.22, "hold": B_FALL})
	pump(k, run, {"lean": 0.08, "twist": 0.14, "front": Vector3(0.22, -0.18, 0.45), "back": Vector3(0.32, -0.45, -0.25), "flare": 0.6, "wild": 0.35, "curl": 0.45})
	# le chocolat reste serré dans la main droite, les doigts gauches s'ouvrent
	for key: Array in k:
		if float(key[0]) > 0.0 and float(key[0]) < B_FALL and (key[1] as Dictionary).has("curl"):
			(key[1] as Dictionary)["curl"] = 0.95
			(key[1] as Dictionary)["curl_l"] = 0.3
	# deux regards en arrière, par-dessus chaque épaule ; souffle court
	carve(k, ["head", "chest"], 0.75, 1.25)
	k.append(K(0.8, M([C(0.04, 0.35), HD(0.1, 1.05, 0.12), FACE("panic")])))
	k.append(K(1.08, M([C(0.06, 0.3), HD(0.05, 0.95, 0.1)]), "s"))
	k.append(K(1.28, M([C(0.08, -0.1), HD(0.0, -0.1)])))
	carve(k, ["head", "chest"], 1.7, 2.2)
	k.append(K(1.75, M([C(0.02, -0.4), HD(0.12, -1.15, -0.1), FACE("fear")])))
	k.append(K(2.0, M([C(0.04, -0.36), HD(0.1, -1.1, -0.12), {"jaw": 0.6}]), "s"))
	k.append(K(2.22, M([C(0.12, 0.05), HD(-0.05, 0.1), FACE("panic")])))
	for n: int in range(8):
		k.append(K(0.1 + n * 0.29, {"jaw": 0.25 + 0.2 * float(n % 2)}))

	# --- CHUTE (2,5 → 3,2) : le pied droit accroche le talon gauche, elle part en avant
	var f: float = B_FALL
	k.append(K(f, M([{"plant": 1.0}, B(0.3, 0.05), C(0.12), HD(-0.1), FACE("surprise"), {"jaw": 0.5}])))
	k.append(K(f + 0.1, M([{"plant": 0.4}, H(0, -0.05, 0.1), B(0.62, 0.1, 0.05), C(0.2, 0.05), HD(0.35, 0.0, 0.05),
		Rt(0.25, 0.1, 0.6, 0.5), Lt(0.3, 0.15, 0.5, 0.5), TL(-0.6, 0.05), KL(0.9), TR(0.4, 0.05), KR(0.5),
		{"curl": 0.2, "curl_l": 0.1, "ev": "gasp"}])))
	k.append(K(f + 0.22, M([{"plant": 0.0, "gsnap": 0.0}, H(0, -0.12, 0.2), B(1.0, 0.1, 0.1), C(0.25, 0.05), HD(0.6, 0.05, 0.05),
		R(0.35, -0.2, 0.75, 0.4), L(0.4, -0.15, 0.7, 0.4), WR(-0.6), WL(-0.6), TL(-0.4, 0.08), KL(1.0), TR(0.2, 0.06), KR(0.3),
		{"prop": "", "curl": 0.0, "curl_l": 0.0, "face": "panic"}])))
	# mains au sol, puis les genoux, puis le ventre : elle glisse un peu
	k.append(K(f + 0.34, M([{"gsnap": 1.0}, H(0, -0.5, 0.1), B(1.25, 0.08, 0.12), C(0.2), HD(0.75, 0.0, 0.1),
		Lg(0.45, 0.55, 0.0), Rg(0.4, 0.6, 0.0), TL(0.1, 0.1), KL(1.3), TR(-0.1, 0.08), KR(1.0),
		{"sq": 0.92, "ev": "effort", "fx": "dust"}]), "s"))
	k.append(K(f + 0.48, M([H(0, -0.62, 0.05), B(1.45, 0.05, 0.15), C(0.05), HD(0.7, 0.1, 0.1),
		Lg(0.6, 0.62, 0.0), Rg(0.55, 0.65, 0.0), TL(-0.15, 0.12), KL(0.6), TR(-0.25, 0.1), KR(0.4),
		{"sq": 1.0, "fx": "dust_ring", "shake": 0.6, "face": "pain"}])))
	k.append(K(f + 0.7, M([B(1.52, 0.05, 0.12), C(-0.05), HD(0.45, 0.15, 0.15), Lg(0.65, 0.5, 0.0), Rg(0.6, 0.55, 0.0),
		TL(-0.1, 0.12), KL(0.5), TR(-0.15, 0.1), KR(0.7), {"shake": 0.3}]), "s"))
	# sonnée, le nez par terre ; elle relève la tête
	k.append(K(3.45, M([B(1.53, 0.05, 0.1), C(-0.08), HD(0.25, 0.2, 0.1), {"shake": 0.1, "face": "hurt"}])))
	blink(3.55, "hurt", k, 0.14)
	k.append(K(3.8, M([B(1.45, 0.0, 0.05), C(-0.25), HD(0.75, 0.05, 0.0), Lg(0.55, 0.45, 0.0), Rg(0.5, 0.48, 0.0), {"face": "sad"}])))
	# elle se redresse sur les bras et regarde derrière elle : Alice arrive
	k.append(K(4.02, M([H(0, -0.5, 0.0), B(1.15, -0.05, 0.0), C(-0.15, -0.15), HD(0.35, -0.5, -0.1), Lg(0.4, 0.35, 0.0), Rg(0.35, 0.4, 0.0),
		TL(0.0, 0.1), KL(0.9), TR(-0.1, 0.1), KR(0.6), {"face": "fear"}])))
	k.append(K(4.22, M([B(1.0, -0.35, -0.1), C(-0.1, -0.45), HD(0.3, -1.1, -0.15), {"face": "panic", "jaw": 0.55, "shake": 0.4}]), "s"))
	# elle se retourne sur les fesses (le film tourne le corps de 180°) …
	k.append(K(4.45, M([H(0, -0.62, 0.0), B(0.25, -0.2, 0.6), C(-0.1, -0.2, 0.1), HD(0.2, -0.3, 0.1),
		Lg(0.6, 0.0, 0.0), Rg(0.3, 0.5, 0.0), TL(1.5, 0.2), KL(1.8), TR(0.9, 0.15), KR(2.0), {"shake": 0.5}])))
	# … et recule, mains derrière elle, talons qui poussent
	var sit: Dictionary = M([{"gsnap": 1.0}, H(0, -0.68, -0.1), B(-0.32, 0.0, 0.0), C(0.25), HD(0.25, 0.0, 0.0),
		Lg(0.35, -0.55, 0.0), Rg(0.38, -0.5, 0.0), TL(1.95, 0.25), KL(1.9, -0.3), TR(1.85, 0.22), KR(1.8, -0.3), {"face": "panic"}])
	k.append(K(4.65, M([sit, {"jaw": 0.4, "shake": 0.6, "sq": 0.96}])))
	k.append(K(4.85, M([TL(1.55, 0.25), KL(1.25, -0.1), TR(2.1, 0.22), KR(2.1, -0.4), B(-0.4, 0.05), Lg(0.3, -0.7, 0.0), {"sq": 1.0}])))
	k.append(K(5.05, M([TL(2.1, 0.25), KL(2.1, -0.4), TR(1.55, 0.22), KR(1.25, -0.1), B(-0.3, -0.05), Rg(0.36, -0.7, 0.0), HD(0.3, 0.1)])))
	k.append(K(5.3, M([TL(1.55, 0.25), KL(1.3, -0.1), TR(2.1, 0.22), KR(2.05, -0.4), B(-0.38, 0.05), Lg(0.32, -0.62, 0.0), HD(0.35, -0.1), {"jaw": 0.7}])))
	k.append(K(5.6, M([sit, HD(0.4, 0.0), {"shake": 0.8, "jaw": 0.3}]), "s"))
	# --- DÉFENSE (5,6 → 6,6) : sa main droite trouve la barre et la lance
	k.append(K(5.85, M([B(-0.25, -0.25, 0.1), C(0.2, -0.25), HD(0.3, -0.5, 0.1), Rg(0.75, -0.15, 0.0), WR(0.3), {"curl": 0.2}])))
	k.append(K(6.0, M([Rg(0.85, -0.1, 0.0), {"curl": 0.95, "prop": "chocolate"}]), "s"))
	k.append(K(6.15, M([B(-0.38, 0.35, -0.1), C(0.15, 0.45), HD(0.45, 0.35, 0.0), R(0.45, 0.55, -0.45, 0.6), WR(-0.5), {"face": "angry", "jaw": 0.2}])))
	k.append(K(B_THROW, M([B(-0.12, -0.3, 0.05), C(0.35, -0.4), HD(0.25, -0.2, 0.0), R(0.0, 0.25, 0.95, 0.2), WR(0.6), {"curl": 0.0, "prop": "", "face": "pain", "jaw": 0.8, "ev": "effort", "fx": "trail_r"}]), "s"))
	k.append(K(6.5, M([B(-0.28, -0.15), C(0.25, -0.2), HD(0.3, -0.1), R(0.15, 0.0, 0.7, 0.3), {"face": "fear", "jaw": 0.3}])))
	# elle voit Alice attraper la barre : le souffle se coupe
	k.append(K(B_CATCH + 0.08, M([sit, B(-0.45, 0.0), HD(0.5, 0.0), R(0.3, -0.25, 0.45, 0.4), WR(0.2), {"curl": 0.4, "face": "surprise", "jaw": 0.6, "shake": 0.2}]), "s"))
	k.append(K(7.2, M([HD(0.45, 0.05, -0.08), {"face": "fear", "jaw": 0.4, "shake": 0.6}])))
	# Alice s'accroupit : Bleuette se recroqueville, détourne la tête, ferme les yeux
	k.append(K(7.9, M([H(0, -0.68, -0.14), B(-0.55, 0.15, 0.1), C(0.1, 0.25), HD(0.2, 0.75, 0.25), L(0.15, 0.25, 0.3, 0.5), R(0.12, 0.3, 0.35, 0.5),
		WL(0.6), WR(0.6), {"curl": 0.7, "curl_l": 0.7, "face": "pain", "jaw": 0.2, "shake": 0.9}])))
	k.append(K(8.6, M([HD(0.12, 0.85, 0.3), B(-0.6, 0.18, 0.1), {"shake": 1.0}]), "s"))
	# --- MISE À MORT (8,78) : hors champ ; elle s'effondre sur le côté, la main retombe
	k.append(K(B_KILL, M([H(0, -0.6, -0.1), B(-0.2, 0.3, 0.3), C(0.4, 0.3), HD(-0.3, 0.6, 0.4), L(0.4, 0.1, 0.4, 0.5), R(0.5, 0.2, 0.3, 0.5),
		{"face": "pain", "jaw": 1.0, "shake": 0.0, "sq": 0.94, "ev": "death"}]), "s"))
	k.append(K(9.1, M([{"gsnap": 1.0}, H(0, -0.7, -0.2), B(-1.15, 0.2, 0.9), C(-0.1, 0.1, 0.2), HD(0.1, 0.5, 0.4),
		Lg(0.7, 0.2, 0.0), Rg(0.9, 0.5, 0.0), WR(0.0, 0.0, 0.4), TL(0.9, 0.3), KL(1.2), TR(0.6, 0.2), KR(1.4), {"sq": 1.0, "face": "dead", "jaw": 0.4, "curl": 0.15, "curl_l": 0.3}])))
	k.append(K(9.35, M([B(-1.3, 0.2, 1.1), HD(0.0, 0.55, 0.45), Rg(0.95, 0.55, 0.0), TL(0.7, 0.3), KL(1.0), {"jaw": 0.3}]), "s"))
	k.append(K(12.5, M([B(-1.3, 0.2, 1.12), HD(0.0, 0.56, 0.46)])))
	c["fa_bleuette"] = _film(0.0, 12.5, k, "panic")
	_bleuette_alice(c)


static func _alice_walk_upper(k: Array, list: Array, o: Dictionary = {}) -> void :
	# Alice marche sans balancer les bras : mains écartées de la robe, griffes
	# entrouvertes ; le buste roule à peine, la tête reste penchée et immobile.
	var tilt: float = float(o.get("tilt", 0.12))
	for i: int in range(list.size()):
		var t: float = float(list[i][0])
		var side: int = int(list[i][1])
		k.append([t + 0.12, M([C(0.32, float(side) * 0.035, float(side) * 0.02), HD(0.18 + J(i, 3.3) * 0.03, - float(side) * 0.02, tilt),
			L(0.38 + J(i, 1.1) * 0.03, -0.78, 0.18 + float(side) * 0.04, 0.25), R(0.42, -0.72, 0.3 - float(side) * 0.04, 0.3),
			{"curl": 0.25 + J(i, 4.4) * 0.15, "curl_l": 0.3 + J(i, 5.5) * 0.15}])])


static func _bleuette_alice(c: Dictionary) -> void :
	var p: String = "Alice"
	var path: Array = bleuette_alice_path()
	var dir: Vector3 = (at(path, 5.9) - at(path, 0.0))
	dir.y = 0.0
	dir = dir.normalized()
	var k: Array = []
	k.append(K(0.0, M([_zero(), H(0, -0.03, 0), B(0.06), C(0.32), HD(0.18, 0.0, 0.12),
		L(0.38, -0.78, 0.18, 0.25), R(0.42, -0.72, 0.3, 0.3), WL(-0.35), WR(-0.3), FL(0.0, 0.1), FR(0.0, -0.1),
		{"curl": 0.25, "curl_l": 0.3, "face": "menace"}])))
	# marche lente et régulière : pas posés sur une ligne, sans rebond
	var walk: Array = []
	var t: float = 0.05
	var side: int = 1
	var i: int = 0
	while t < 5.6:
		walk.append([t, side, 0.36 + J(i, 21.0) * 0.02, 0.42, -0.035])
		t += 0.565 + J(i, 22.0) * 0.02
		side = - side
		i += 1
	var feet: Dictionary = steps(p, k, path, dir, walk, {"kick": 0.12, "knee": 0.1, "strike": 0.22, "push": -0.35, "bob": 0.012, "rise": 0.0, "base": Vector3(0, -0.03, 0), "sway": 0.012, "yaw": 0.04, "lean": 0.06})
	var planted: Dictionary = {"foot_l": feet[-1], "foot_r": feet[1], "fp_l": 0.0, "fp_r": 0.0}
	_alice_walk_upper(k, walk)
	# elle s'arrête face à Bleuette, pieds joints, la tête se penche
	var stop: float = 5.95
	k.append(K(stop, M([H(0, -0.02, 0), planted, B(0.04), C(0.3), HD(0.32, 0.0, 0.22), L(0.36, -0.8, 0.12, 0.25), R(0.4, -0.76, 0.2, 0.3), {"curl": 0.3, "face": "menace"}]), "s"))
	# --- elle attrape la barre au vol, main droite, sans quitter Bleuette des yeux
	k.append(K(B_CATCH - 0.12, M([R(0.4, -0.7, 0.22, 0.3), {"curl": 0.2}])))
	k.append(K(B_CATCH, M([C(0.28, 0.05), HD(0.32, 0.0, 0.22), R(0.18, 0.12, 0.62, 0.3), WR(0.2, 0.0, 0.0), {"curl": 0.95, "prop": "chocolate", "sq": 1.02}]), "s"))
	k.append(K(B_CATCH + 0.4, M([R(0.18, 0.12, 0.62, 0.3), {"sq": 1.0}]), "s"))
	# elle regarde enfin la barre, penche la tête de l'autre côté
	k.append(K(7.15, M([C(0.32, -0.12), HD(0.45, -0.35, -0.18), R(0.12, 0.1, 0.5, 0.35), WR(0.35, -0.4), {"face": "calm"}])))
	blink(7.3, "calm", k)
	k.append(K(7.5, M([HD(0.42, -0.3, -0.22)]), "s"))
	# elle range la barre derrière son dos et s'accroupit, lentement
	k.append(K(7.75, M([H(0, -0.06, 0), C(0.36, 0.0), HD(0.3, 0.0, 0.15), R(0.38, -0.6, -0.15, 0.4), WR(-0.3), {"face": "menace"}])))
	var crouch: Dictionary = M([{"plant": 1.0}, planted, H(0, -0.55, -0.08), B(0.35, 0.0), C(0.45), HD(0.05, 0.0, 0.22), {"fp_r": -0.4}])
	k.append(K(8.25, M([crouch, L(0.25, -0.35, 0.45, 0.3), WL(0.2), R(0.38, -0.55, -0.2, 0.4), {"curl_l": 0.4}])))
	# la griffe gauche monte, doigts qui se replient un à un
	k.append(K(8.5, M([HD(0.0, 0.05, 0.3), L(0.15, 0.55, 0.25, 0.6), WL(-0.5), {"curl_l": 0.1, "face": "grin"}])))
	k.append(K(8.68, M([L(0.1, 0.7, 0.15, 0.6), WL(-0.7), {"curl_l": 0.55}]), "s"))
	k.append(K(B_KILL, M([H(0, -0.6, 0.05), B(0.45, 0.1), C(0.55, 0.2), HD(-0.05, -0.1, 0.1), L(-0.1, -0.35, 0.8, 0.2), WL(0.5), {"curl_l": 0.75, "fx": "claw_l trail_l", "ev": "grunt", "sq": 1.04}]), "s"))
	k.append(K(9.2, M([H(0, -0.58, 0.02), B(0.4, 0.05), C(0.5, 0.1), HD(0.05, -0.1, 0.25), L(0.1, -0.45, 0.6, 0.3), WL(0.4), {"sq": 1.0, "face": "calm"}]), "s"))
	# --- elle se relève, sort la barre et croque dedans en nous regardant
	k.append(K(9.9, M([H(0, -0.3, -0.02), planted, B(0.18), C(0.38), HD(0.2, 0.0, 0.15), L(0.4, -0.78, 0.2, 0.25), WL(-0.3), R(0.38, -0.55, 0.0, 0.4), {"plant": 1.0}])))
	k.append(K(10.4, M([H(0, -0.03, 0), planted, B(0.04), C(0.28), HD(0.25, 0.1, 0.12), R(0.2, -0.2, 0.45, 0.35), WR(0.4)])))
	k.append(K(10.8, M([HD(0.18, 0.12, 0.1), R(0.02, 0.26, 0.22, 0.2), WR(0.9, -0.3), {"jaw": 0.55}]), "s"))
	k.append(K(10.95, M([HD(0.14, 0.1, 0.12), {"jaw": 0.0, "sq": 1.01}])))
	k.append(K(11.1, M([R(0.15, -0.05, 0.38, 0.3), WR(0.4), {"jaw": 0.15}])))
	k.append(K(11.3, M([{"jaw": 0.0}, HD(0.2, 0.15, 0.2), FACE("grin")])))
	k.append(K(11.5, {"jaw": 0.12}))
	k.append(K(11.7, {"jaw": 0.0}))
	k.append(K(12.5, M([HD(0.22, 0.16, 0.22)])))
	c["fa_bleuette_alice"] = _film(0.0, 12.5, k, "menace")
