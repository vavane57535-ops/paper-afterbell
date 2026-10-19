extends "res://anim_pose.gd"

# Prologue « Yiero », partie B (104 → 182 s, lot prologue_b) : défaite, fuite, porte, école, coup double.
# Chaque mouvement de corps de ces actes est un clip écrit POUR son plan (aucun clip, émote, geste de
# capacité ni locomotion du jeu) : poses clés puis intervalles, anticipation, rattrapage, chevauchement
# (tête, mains et doigts en décalé sur le corps), poids et appuis, visages qui évoluent dans le plan.
# - Les clés sont écrites en temps du FILM (synchro musique) et converties en temps de clip en tenant
#   compte des ralentis du film (SLOW = mêmes valeurs que les _slowmo de film_intro_yiero.gd).
# - Les déplacements sont écrits « pieds d'abord » : chaque appui est posé à un endroit précis du décor,
#   la trajectoire du personnage (que le film suit avec _move) en découle, et le pied d'appui reste fixe
#   au sol (sa position dans le repère du personnage recule exactement de la distance parcourue).
# - Le film (film_intro_yiero.gd : _write_defeat, _write_chase, _write_school) lit tout ici : plans()
#   (trajectoires, orientations), plays() (instant de départ de chaque clip) et contacts() (appuis, pour
#   les ondes dans l'encre).
# Noms des clips préfixés « pb_ ».

const AnimClip = preload("res://anim_clip.gd")

# Ralentis du film dans cette partie : [début, fin, facteur]. L'arrêt sur image (facteur 0) : les clips y
# tiennent leur pose (le jeu avance encore d'1/240 s par image pendant un ralenti nul).
const SLOW: Array = [[149.2, 150.6, 0.3], [162.15, 162.55, 0.3], [179.01, 181.7, 0.0]]

# Mesures des squelettes (tools/pb_probe.gd), en unités du modèle : portée de jambe (hanche → cheville),
# échelle (unités → mètres), hauteur du bassin au repos, hauteur des hanches, demi-écart des hanches,
# longueur d'orteil, chevilles au repos et longueur de bras.
const RIG: Dictionary = {
	"Simon": {"reach": 0.9111, "scale": 0.7675, "base": 1.0643, "hip_y": 1.0643, "hip_x": 0.1069, "toe": 0.1362, "arm": 0.529, "foot_l": Vector3(-0.1425, 0.1559, 0.0356), "foot_r": Vector3(0.1336, 0.1559, 0.0356)},
	"Ashura": {"reach": 0.8648, "scale": 0.7456, "base": 0.9616, "hip_y": 0.9612, "hip_x": 0.1332, "toe": 0.0570, "arm": 0.602, "foot_l": Vector3(-0.2432, 0.1148, -0.0377), "foot_r": Vector3(0.2504, 0.0972, 0.0896)},
	"Usayuko": {"reach": 0.8233, "scale": 0.8202, "base": 1.1736, "hip_y": 1.1732, "hip_x": 0.1071, "toe": 0.0220, "arm": 0.471, "foot_l": Vector3(-0.2143, 0.3640, 0.0786), "foot_r": Vector3(0.2091, 0.3536, -0.0136)},
	"Alice": {"reach": 1.1240, "scale": 0.7675, "base": 1.3582, "hip_y": 1.3137, "hip_x": 0.0891, "toe": 0.1514, "arm": 0.572, "foot_l": Vector3(-0.0891, 0.1915, 0.0713), "foot_r": Vector3(0.0891, 0.1915, 0.0713)},
	"Elly": {"reach": 0.9394, "scale": 0.8333, "base": 1.1623, "hip_y": 1.1088, "hip_x": 0.1069, "toe": 0.2009, "arm": 0.480, "foot_l": Vector3(-0.1781, 0.1737, 0.0267), "foot_r": Vector3(0.1781, 0.1737, 0.0267)},
	"Bleuette": {"reach": 0.9435, "scale": 0.7237, "base": 1.0805, "hip_y": 1.0801, "hip_x": 0.1358, "toe": 0.0862, "arm": 0.438, "foot_l": Vector3(-0.1972, 0.1034, 0.0001), "foot_r": Vector3(0.1427, 0.1385, 0.0462)},
	"Lysia": {"reach": 1.1263, "scale": 0.7675, "base": 1.2563, "hip_y": 1.2506, "hip_x": 0.0978, "toe": 0.0323, "arm": 0.511, "foot_l": Vector3(-0.1017, 0.1354, 0.1529), "foot_r": Vector3(0.1344, 0.1292, 0.1089)},
}

# Vitesse de rotation du film vers l'orientation demandée (PaperPrologue._step : exp(-dt × 11)).
const YAW_RATE: float = 11.0

static var _clips: Dictionary = {}
static var _plays: Array = []
static var _plans: Dictionary = {}
static var _contacts: Array = []
static var _built: bool = false


static func add(c: Dictionary) -> void :
	_build()
	c.merge(_clips, true)


# [instant du film, personnage, clip] : le film les joue avec _do(i, t, "play", clip).
static func plays() -> Array:
	_build()
	return _plays


# Plan d'un personnage : {"put": Vector3 ou null, "moves": [[t0, t1, Vector3, ease]], "faces": [[t, Vector3]]}
# Positions et directions dans le repère du film ; pour Simon dans la dimension, relatives à sa place
# à 104 s (le film ajoute cette origine).
static func plan(person: String) -> Dictionary:
	_build()
	return _plans.get(person, {})


# Appuis [instant, personnage, Vector3 (repère du film), force] : ondes dans l'encre, poussière.
static func contacts() -> Array:
	_build()
	return _contacts


static func _build() -> void :
	if _built: return
	_built = true
	_defeat()
	_chase()
	_school()
	_bench()




# --- Temps -------------------------------------------------------------------------------------------

# Temps du film → temps « ralenti » (celui des clips).
static func scaled(t: float) -> float:
	var lost: float = 0.0
	for row: Array in SLOW:
		var a: float = float(row[0])
		var b: float = float(row[1])
		if t <= a: continue
		lost += (minf(t, b) - a) * (1.0 - float(row[2]))
	return t - lost


static func speed_at(t: float) -> float:
	for row: Array in SLOW:
		if t >= float(row[0]) and t < float(row[1]): return float(row[2])
	return 1.0




# --- Clips -------------------------------------------------------------------------------------------

# Clip en cours d'écriture, clés au temps du film.
class Clip:
	var person: String = ""
	var name: String = ""
	var start: float = 0.0
	var end: float = 0.0
	var keys: Array = []
	var face: String = ""
	var fade_in: float = 0.0
	# Canal → retard (s, temps du film) : la tête, les mains et les doigts arrivent après le corps.
	var lag: Dictionary = {}

	func _init(who: String, clip_name: String, t0: float, t1: float) -> void :
		person = who;name = clip_name;start = t0;end = t1


static func clip(person: String, clip_name: String, t0: float, t1: float, face: String = "") -> Clip:
	var k: Clip = Clip.new(person, clip_name, t0, t1)
	k.face = face
	return k


# Une clé : instant du film, morceaux de pose (fusionnés), drapeau ("s" arrêt, "l" linéaire, "h" tenu).
static func at(k: Clip, t: float, parts: Array, flag: String = "") -> void :
	var pose: Dictionary = M(parts)
	if flag.is_empty(): k.keys.append([t, pose])
	else: k.keys.append([t, pose, flag])


# Canaux de base d'un clip de film : pas de locomotion du jeu, pieds posés, rien d'additif.
static func base() -> Dictionary:
	return {"gait": 0.0, "plant": 1.0, "gsnap": 0.0, "gclamp": 0.0, "turn": 0.0, "sq": 1.0, "shake": 0.0, "jaw": 0.0, "chatter": 0.0, "fp_l": 0.0, "fp_r": 0.0, "el_l": 0.0, "el_r": 0.0}


# Enregistre le clip : temps du film → temps de clip, retards par canal, longueur jusqu'à k.end.
static func finish(k: Clip) -> void :
	var origin: float = scaled(k.start)
	var keys: Array = []
	for key: Array in k.keys:
		var t: float = float(key[0])
		var flag: String = str(key[2]) if key.size() > 2 else ""
		var pose: Dictionary = key[1]
		var main: Dictionary = {}
		var delayed: Dictionary = {}
		for channel: String in pose:
			var d: float = float(k.lag.get(channel, 0.0))
			if d <= 0.0 or t <= k.start + 0.0001:
				main[channel] = pose[channel]
				continue
			if not delayed.has(d): delayed[d] = {}
			(delayed[d] as Dictionary)[channel] = pose[channel]
			# Clé de départ du canal retardé : garde sa valeur au début du clip.
		if not main.is_empty(): keys.append(_key(scaled(t) - origin, main, flag))
		for d: float in delayed: keys.append(_key(scaled(t + d) - origin, delayed[d], flag))
	keys.sort_custom( func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var length: float = maxf(0.05, scaled(k.end) - origin)
	_clips[k.name] = {"len": length, "in": k.fade_in, "out": 0.0, "face": k.face, "keys": keys}
	_plays.append([k.start, k.person, k.name])


static func _key(t: float, pose: Dictionary, flag: String) -> Array:
	return [t, pose] if flag.is_empty() else [t, pose, flag]




# --- Plans (trajectoires et orientations) -------------------------------------------------------------

static func _plan(person: String) -> Dictionary:
	if not _plans.has(person): _plans[person] = {"put": null, "moves": [], "faces": [], "points": [], "start": Vector3.ZERO}
	return _plans[person]


# Place le personnage (temps 0) : remplace sa trajectoire.
static func put(person: String, spot: Vector3) -> void :
	var p: Dictionary = _plan(person)
	p.put = spot
	p.start = spot
	p.points = [[0.0, spot, "linear"]]


# Point de départ connu sans le placer (Simon reprend sa trajectoire de la partie A).
static func origin(person: String, spot: Vector3) -> void :
	var p: Dictionary = _plan(person)
	p.start = spot
	p.points = [[0.0, spot, "linear"]]


# Même règle que PaperCinema._move : un point d'attente est ajouté si le trajet démarre plus tard.
static func move(person: String, t0: float, t1: float, spot: Vector3, ease: String = "linear") -> void :
	var p: Dictionary = _plan(person)
	var points: Array = p.points
	var last: float = float(points[points.size() - 1][0])
	t0 = maxf(t0, last)
	t1 = maxf(t1, t0 + 0.02)
	if t0 > last + 0.001: points.append([t0, points[points.size() - 1][1], "linear"])
	points.append([t1, spot, ease])
	(p.moves as Array).append([t0, t1, spot, ease])


static func face(person: String, t: float, direction: Vector3) -> void :
	(_plan(person).faces as Array).append([t, direction])


static func _ease(u: float, mode: String) -> float:
	u = clampf(u, 0.0, 1.0)
	match mode:
		"linear": return u
		"out": return 1.0 - (1.0 - u) * (1.0 - u)
		"dash": return 1.0 - pow(1.0 - u, 3.0)
		"in": return u * u
		"jump": return 1.0 if u >= 1.0 else 0.0
	return smoothstep(0.0, 1.0, u)


# Position du personnage (repère du film) à l'instant t, comme PaperCinema._where.
static func root(person: String, t: float) -> Vector3:
	var points: Array = _plan(person).points
	if points.is_empty(): return Vector3.ZERO
	if t <= float(points[0][0]): return points[0][1]
	for k: int in range(1, points.size()):
		if t <= float(points[k][0]):
			var a: Array = points[k - 1]
			var b: Array = points[k]
			return (a[1] as Vector3).lerp(b[1], _ease((t - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0])), str(b[2])))
	return points[points.size() - 1][1]


static func yaw_of(direction: Vector3) -> float:
	return atan2( - direction.x, - direction.z)


# Orientation réelle (rad) à l'instant t : la consigne la plus récente, rejointe en douceur comme le fait
# le film (taux YAW_RATE, ralentis compris). Simulée au 1/120 s depuis la première consigne (table mise
# en cache, refaite quand une consigne s'ajoute).
static func yaw(person: String, t: float) -> float:
	var p: Dictionary = _plan(person)
	var faces: Array = p.faces
	if faces.is_empty(): return PI
	if int(p.get("yaw_n", -1)) != faces.size():
		faces.sort_custom( func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		var table: PackedFloat32Array = PackedFloat32Array()
		var value: float = yaw_of(faces[0][1])
		var clock: float = float(faces[0][0])
		var index: int = 0
		var dt: float = 1.0 / 120.0
		while clock < 200.0:
			table.append(value)
			while index + 1 < faces.size() and float(faces[index + 1][0]) <= clock + 0.00001: index += 1
			value = lerp_angle(value, yaw_of(faces[index][1]), 1.0 - exp( - dt * speed_at(clock) * YAW_RATE))
			clock += dt
		p.yaw_table = table
		p.yaw_t0 = float(faces[0][0])
		p.yaw_n = faces.size()
	var table: PackedFloat32Array = p.yaw_table
	var u: float = (t - float(p.yaw_t0)) * 120.0
	if u <= 0.0: return table[0]
	var i: int = mini(int(u), table.size() - 2)
	return lerp_angle(table[i], table[i + 1], clampf(u - float(i), 0.0, 1.0))


# Point du décor (repère du film) → repère du personnage à l'instant t (x à droite, z vers l'arrière).
static func to_body(person: String, t: float, spot: Vector3) -> Vector3:
	return (spot - root(person, t)).rotated(Vector3.UP, - yaw(person, t))


# Direction du repère du personnage → repère du film à l'instant t.
static func to_film(person: String, t: float, local: Vector3) -> Vector3:
	return root(person, t) + local.rotated(Vector3.UP, yaw(person, t))




# --- Conversions mètres → canaux ---------------------------------------------------------------------

# Cheville du pied `side` (-1 gauche, 1 droit) à la position p du repère du personnage (mètres ; y = levée
# de la semelle au-dessus du sol) avec la pente `pitch` (négative : talon levé) → valeur foot_l / foot_r.
static func foot(person: String, side: int, p: Vector3, pitch: float = 0.0) -> Vector3:
	var rig: Dictionary = RIG[person]
	var s: float = float(rig.scale)
	var rest: Vector3 = rig.foot_l if side < 0 else rig.foot_r
	var raise: float = float(rig.toe) * sin( - pitch) if pitch < 0.0 else 0.0
	var model: Vector3 = Vector3(p.x / s, rest.y + p.y / s + raise, p.z / s)
	return (model - rest) / float(rig.reach)


# Pied au repos (mètres, repère du personnage) : là où il se pose quand l'acteur est droit.
static func rest_foot(person: String, side: int) -> Vector3:
	var rig: Dictionary = RIG[person]
	var rest: Vector3 = rig.foot_l if side < 0 else rig.foot_r
	return Vector3(rest.x, 0.0, rest.z) * float(rig.scale)


# Décalage du bassin en mètres (x à droite, y en haut, z vers l'arrière) → canal hips.
static func hips(person: String, offset: Vector3) -> Vector3:
	var rig: Dictionary = RIG[person]
	return offset / float(rig.scale) / float(rig.reach)


static func leg_m(person: String) -> float:
	var rig: Dictionary = RIG[person]
	return float(rig.reach) * float(rig.scale)


# Abaissement (mètres, ≤ 0) qui laisse les deux jambes atteindre leurs pieds avec une extension
# maximale `ext` : le bassin ne monte jamais au point de tendre la jambe (pied qui flotte).
static func fit_drop(person: String, offset: Vector3, feet: Dictionary, ext: float = 0.95) -> float:
	var rig: Dictionary = RIG[person]
	var s: float = float(rig.scale)
	var reach: float = float(rig.reach) * ext
	var y: float = offset.y
	for side: int in feet:
		var p: Vector3 = feet[side]
		var rest: Vector3 = rig.foot_l if side < 0 else rig.foot_r
		var hip: Vector3 = Vector3(float(rig.hip_x) * float(side) + offset.x / s, float(rig.hip_y), offset.z / s)
		var ankle: Vector3 = Vector3(p.x / s, rest.y + p.y / s, p.z / s)
		var flat: float = Vector2(hip.x - ankle.x, hip.z - ankle.z).length()
		if flat >= reach: flat = reach * 0.98
		var top: float = ankle.y + sqrt(reach * reach - flat * flat)
		y = minf(y, (top - float(rig.hip_y)) * s)
	return y


static func _noise(seed_value: int, k: int) -> float:
	var h: int = absi((seed_value * 73856093) ^ (k * 19349663) ^ (k * k * 83492791))
	return float(h % 10007) / 10006.0 * 2.0 - 1.0


static func TL(fwd: float, out: float = 0.0, twist: float = 0.0) -> Dictionary:
	return {"l_leg": Vector3(fwd, twist, - out)}

static func TR(fwd: float, out: float = 0.0, twist: float = 0.0) -> Dictionary:
	return {"r_leg": Vector3(fwd, - twist, out)}

static func KL(bend: float, ankle: float = 0.0) -> Dictionary:
	return {"l_knee": - bend, "l_ank": ankle}

static func KR(bend: float, ankle: float = 0.0) -> Dictionary:
	return {"r_knee": - bend, "r_ank": ankle}

static func FACE(mood: String) -> Dictionary:
	return {"face": mood}




# --- Poses communes -----------------------------------------------------------------------------------

# À genoux : sit 0 = droit sur les genoux, 1 = assis sur les talons ; lean = inclinaison du bassin (la
# cuisse compense pour rester d'aplomb) ; spread = écart des genoux.
static func kneel(sit: float, lean: float = 0.0, spread: float = 0.18, uneven: float = 0.0) -> Dictionary:
	var thigh: float = lerpf(0.12, 1.72, sit) + lean
	var knee: float = lerpf(1.62, 2.42, sit)
	return M([{"plant": 0.0, "gsnap": 1.0}, TL(thigh + uneven, spread), KL(knee, -0.75), TR(thigh - uneven, spread), KR(knee, -0.75)])


# Un genou au sol (genou droit levé si side = 1) : prêt à se relever.
static func half_kneel(side: int, lean: float = 0.0, depth: float = 0.0) -> Dictionary:
	var up: Dictionary = M([TR(1.45 + lean - depth * 0.3, 0.12), KR(1.55 - depth * 0.4, 0.15)]) if side > 0 else M([TL(1.45 + lean - depth * 0.3, 0.12), KL(1.55 - depth * 0.4, 0.15)])
	var down: Dictionary = M([TL(0.25 + lean, 0.16), KL(1.7, -0.75)]) if side > 0 else M([TR(0.25 + lean, 0.16), KR(1.7, -0.75)])
	return M([{"plant": 0.0, "gsnap": 1.0}, up, down])




# --- Acte IV : la défaite (104 → 122,9 s) ------------------------------------------------------------

static func _defeat() -> void :
	_defeat_simon()
	_defeat_ashura()


# Simon au sol après le revers de Yiero : il revient à lui, voit Ashura dans la griffe, se redresse sur une
# main et tend l'autre en hurlant, tente de se relever, retombe à genoux ; le poing se referme. Pendant
# l'effacement il regarde, puis hurle (119,2) tête renversée, s'effondre en sanglots et relève la tête
# vers Yiero qui lui parle. Repère : Simon regarde vers +z (Yiero) ; Ashura est à ~36° sur sa droite,
# ~18° au-dessus de l'horizon.
static func _defeat_simon() -> void :
	origin("Simon", Vector3.ZERO)
	face("Simon", 103.9, Vector3(0, 0, 1))
	var k: Clip = clip("Simon", "pb_simon_floor", 104.0, 122.95, "dazed")
	k.lag = {"head": 0.07, "ik_r": 0.05, "ik_l": 0.06, "curl": 0.09, "curl_l": 0.1}
	var ground: Dictionary = M([base(), {"plant": 0.0, "gsnap": 1.0}])
	# À plat ventre, appuyé sur les avant-bras, tête basse : il revient à lui.
	at(k, 104.0, [ground, B(1.42, 0.06, -0.06), C(-0.32, 0.08, 0.0), HD(-0.05, 0.1, 0.12), TL(-0.08, 0.1), KL(0.25, 0.25), TR(0.02, 0.12), KR(0.55, 0.3), Lg(0.14, 0.34), WL(0.4), Rg(0.1, 0.4), WR(0.4), {"el_l": 0.75, "el_r": 0.7, "curl": 0.45, "curl_l": 0.4, "jaw": 0.15}, FACE("dazed")])
	at(k, 104.3, [HD(0.02, -0.08, -0.1), {"jaw": 0.25}])
	# La tête se relève : il voit Ashura dans la griffe.
	at(k, 104.58, [B(1.38, 0.04, -0.04), C(-0.42, -0.05, 0.0), HD(0.3, -0.25, 0.0), {"jaw": 0.1}, FACE("hurt")])
	at(k, 104.8, [C(-0.46, -0.12, 0.0), HD(0.42, -0.42, -0.04), FACE("fear")], "s")
	# Anticipation : les épaules s'enfoncent, les mains se plantent à plat pour pousser.
	at(k, 105.0, [B(1.44, 0.0, 0.0), C(-0.3, -0.1, 0.0), HD(0.36, -0.4, -0.02), Lg(0.12, 0.3), Rg(0.1, 0.32), WL(1.2), WR(1.2), {"curl": 0.15, "curl_l": 0.15, "sq": 0.97}])
	# Il pousse sur les bras : le buste monte, les genoux glissent sous lui…
	at(k, 105.22, [B(1.05, 0.08, -0.05), C(-0.32, -0.18, 0.02), HD(0.4, -0.42, -0.04), TL(1.2, 0.12), KL(1.7, -0.6), TR(1.15, 0.14), KR(1.75, -0.6), Lg(0.08, 0.26), Rg(0.12, 0.24), {"sq": 1.02, "ev": "effort"}, FACE("panic")])
	# … appuyé sur la main gauche, le bras droit part vers Ashura, doigts écartés.
	at(k, 105.42, [B(0.82, 0.14, -0.1), C(-0.3, -0.3, 0.05), HD(0.48, -0.45, -0.08), TL(1.25, 0.12), KL(1.95, -0.7), TR(1.1, 0.16), KR(1.9, -0.7), Lg(0.04, 0.22), WL(1.2), R(0.5, 0.42, 0.62, 0.15), WR(-0.2, 0.0, -0.2), {"curl": 0.05, "sq": 1.0}])
	# « ASHURA ! Lâche-le ! » : le buste pousse vers lui, le bras tremble.
	at(k, 105.62, [B(0.76, 0.12, -0.08), C(-0.4, -0.34, 0.06), HD(0.54, -0.47, -0.1), R(0.52, 0.48, 0.66, 0.12), {"shake": 0.35, "jaw": 0.6}])
	at(k, 105.92, [B(0.8, 0.13, -0.09), C(-0.33, -0.31, 0.06), HD(0.5, -0.45, -0.07), R(0.5, 0.42, 0.64, 0.12), {"shake": 0.45, "jaw": 0.3}])
	at(k, 106.12, [C(-0.42, -0.34, 0.07), HD(0.55, -0.47, -0.12), R(0.53, 0.52, 0.68, 0.12), {"shake": 0.5, "jaw": 0.65}])
	# Il essaie de se relever : la main droite revient au sol, le pied droit vient devant…
	at(k, 106.36, [B(0.55, 0.06, -0.04), C(-0.08, -0.15, 0.03), HD(0.36, -0.4, -0.05), half_kneel(1, 0.55), Lg(0.08, 0.3), Rg(0.16, 0.28), WR(1.1), {"curl": 0.3, "shake": 0.25, "jaw": 0.1, "sq": 0.98, "ev": "effort"}, FACE("pain")])
	at(k, 106.5, [B(0.42, 0.04, -0.03), HD(0.3, -0.38, -0.04), half_kneel(1, 0.42, 0.3), Lg(0.06, 0.34), Rt(0.0, -0.25, 0.3, 0.4), {"sq": 1.02}])
	# … la jambe lâche : il retombe à genoux, la main gauche le rattrape.
	at(k, 106.66, [B(0.82, 0.05, 0.1), C(0.2, -0.05, 0.06), HD(-0.22, -0.12, 0.12), kneel(0.4, 0.82, 0.2), Lg(0.0, 0.26), Rg(0.14, 0.3, 0.08), WL(1.1), WR(0.9), {"curl": 0.3, "shake": 0.1, "sq": 0.95, "ev": "hurt"}], "s")
	at(k, 106.84, [B(0.74, 0.05, 0.08), C(0.12, -0.05, 0.05), HD(-0.1, -0.15, 0.1), kneel(0.42, 0.74, 0.2), {"sq": 1.0}])
	# Plan par-dessus son épaule : il relève la tête et retend la main vers Ashura, tout là-haut.
	at(k, 107.05, [B(0.32, 0.0, 0.0), C(-0.15, -0.25, 0.0), HD(0.42, -0.38, 0.0), kneel(0.35, 0.32, 0.2), Lg(0.05, 0.28), R(0.42, 0.55, 0.55, 0.1), WR(-0.3), {"curl": 0.1, "shake": 0.25}, FACE("fear")])
	at(k, 107.6, [B(0.28, 0.0, 0.0), C(-0.2, -0.28, 0.0), HD(0.46, -0.4, 0.02), R(0.44, 0.6, 0.58, 0.1), {"shake": 0.35}])
	at(k, 108.15, [C(-0.18, -0.26, 0.0), HD(0.44, -0.4, 0.04), R(0.42, 0.56, 0.55, 0.1), {"curl": 0.25, "shake": 0.3}, FACE("sad")])
	# Le poing se referme et revient contre la poitrine.
	at(k, 108.7, [B(0.36, 0.0, 0.0), C(-0.05, -0.2, 0.0), HD(0.38, -0.38, 0.06), R(0.25, 0.25, 0.4, 0.2), WR(0.2), {"curl": 1.0, "shake": 0.2}])
	at(k, 109.3, [B(0.4, 0.0, 0.0), C(0.05, -0.18, 0.0), HD(0.36, -0.36, 0.08), Rt(-0.1, 0.0, 0.32, 0.4), {"curl": 1.0, "shake": 0.15}])
	# Pendant qu'Ashura parle et s'efface : à genoux, il regarde, le souffle court.
	at(k, 110.6, [B(0.38, 0.0, 0.0), C(0.02, -0.2, 0.02), HD(0.38, -0.38, 0.06), {"shake": 0.18}])
	at(k, 112.2, [B(0.4, 0.02, 0.0), C(0.06, -0.22, 0.0), HD(0.4, -0.4, 0.04), Lg(0.05, 0.3)])
	at(k, 113.9, [B(0.3, 0.0, 0.0), C(-0.1, -0.25, 0.0), HD(0.46, -0.42, 0.0), Rt(-0.05, 0.1, 0.38, 0.4), {"curl": 0.6, "shake": 0.3}, FACE("panic")])
	at(k, 115.8, [B(0.26, 0.0, 0.0), C(-0.14, -0.26, 0.0), HD(0.5, -0.42, 0.0), R(0.4, 0.5, 0.5, 0.1), {"curl": 0.15, "shake": 0.4}])
	at(k, 117.5, [B(0.32, 0.0, 0.0), C(-0.08, -0.24, 0.0), HD(0.44, -0.4, 0.0), R(0.42, 0.45, 0.55, 0.1), {"curl": 0.05, "shake": 0.25}, FACE("fear")])
	# Anticipation du cri : la tête tombe, les épaules montent (inspiration).
	at(k, 118.85, [B(0.55, 0.0, 0.0), C(0.3, 0.0, 0.0), HD(-0.4, 0.0, 0.05), kneel(0.75, 0.55, 0.2), L(0.32, -0.75, 0.15, 0.2), R(0.32, -0.75, 0.15, 0.2), {"curl": 0.9, "curl_l": 0.9, "shake": 0.2, "sq": 0.96, "jaw": 0.0}, FACE("pain")], "s")
	# « ASHURAAA ! » : tête renversée, poitrine ouverte, poings en arrière.
	at(k, 119.22, [B(-0.08, 0.0, 0.0), C(-0.32, 0.0, 0.0), HD(0.95, 0.06, 0.0), kneel(0.6, -0.08, 0.2), L(0.3, -0.85, -0.25, 0.3), R(0.3, -0.85, -0.25, 0.3), {"curl": 1.0, "curl_l": 1.0, "shake": 0.6, "sq": 1.05, "jaw": 1.0}])
	at(k, 119.6, [B(-0.1, 0.0, 0.0), C(-0.36, 0.02, 0.0), HD(1.02, 0.04, 0.03), {"shake": 0.75, "jaw": 1.0, "sq": 1.03}])
	at(k, 120.15, [B(-0.06, 0.0, 0.0), C(-0.3, 0.0, 0.0), HD(0.9, 0.0, 0.0), {"shake": 0.65, "jaw": 0.9}])
	# Il s'effondre : le buste plie, les poings tombent au sol ; sanglots.
	at(k, 120.5, [B(0.75, 0.0, 0.0), C(0.45, 0.0, 0.05), HD(-0.45, 0.0, 0.08), kneel(0.8, 0.75, 0.22), Lg(0.0, 0.32), Rg(0.02, 0.36), WL(1.2), WR(1.2), {"curl": 1.0, "curl_l": 1.0, "shake": 0.5, "sq": 0.95, "jaw": 0.3}, FACE("sad")])
	at(k, 120.68, [B(0.8, 0.0, 0.0), C(0.5, 0.0, 0.05), HD(-0.5, 0.0, 0.1), {"sq": 1.0}], "s")
	at(k, 121.05, [B(0.76, 0.0, 0.0), C(0.42, 0.0, 0.04), HD(-0.42, 0.04, 0.06), {"shake": 0.55}])
	at(k, 121.4, [B(0.8, 0.0, 0.0), C(0.48, 0.0, 0.05), HD(-0.48, -0.03, 0.08), {"shake": 0.45, "jaw": 0.2}])
	# La voix de Yiero : il relève lentement la tête vers lui.
	at(k, 121.9, [B(0.72, 0.0, 0.0), C(0.35, 0.0, 0.03), HD(-0.2, 0.0, 0.04), {"shake": 0.3}, FACE("fear")])
	at(k, 122.5, [B(0.6, 0.0, 0.0), C(0.15, 0.0, 0.0), HD(0.35, 0.05, 0.0), {"shake": 0.35, "jaw": 0.15}])
	at(k, 122.95, [B(0.58, 0.0, 0.0), C(0.1, 0.0, 0.0), HD(0.42, 0.05, 0.0), {"shake": 0.4}, FACE("panic")])
	finish(k)


# Ashura pendu à la griffe de Yiero (tenu au-dessus de la tête, par le col) : il se débat, s'épuise,
# regarde Simon en bas, lui parle, s'apaise ; pendant l'effacement il ferme les yeux et ouvre les mains.
static func _defeat_ashura() -> void :
	var k: Clip = clip("Ashura", "pb_ashura_held", 104.0, 117.7, "pain")
	k.lag = {"head": 0.08, "ik_r": 0.07, "ik_l": 0.07, "curl": 0.1, "curl_l": 0.1, "l_leg": 0.04, "r_leg": 0.06, "l_knee": 0.08, "r_knee": 0.1}
	var hang: Dictionary = M([base(), {"plant": 0.0, "gsnap": 0.0}])
	# Il se débat : les deux mains agrippent la griffe au-dessus de la tête, les jambes battent.
	at(k, 104.0, [hang, H(0, 0.02, 0), B(-0.05, 0.1, 0.06), C(0.1, 0.1), HD(-0.2, 0.25, 0.1), TL(0.35, 0.05), KL(0.7, -0.4), TR(-0.1, 0.08), KR(0.3, -0.5), L(0.1, 0.95, 0.1, 0.4), R(-0.05, 0.92, 0.12, 0.4), WL(-0.6), WR(-0.6), {"curl": 0.9, "curl_l": 0.9, "shake": 0.3}, FACE("pain")])
	at(k, 104.45, [B(0.05, -0.15, -0.05), C(0.05, -0.1), HD(-0.1, -0.2, -0.08), TL(-0.15, 0.08), KL(0.25, -0.5), TR(0.5, 0.05), KR(0.9, -0.4), L(0.08, 0.98, 0.05, 0.4), R(-0.02, 0.9, 0.15, 0.4), {"shake": 0.5, "ev": "effort"}])
	at(k, 104.85, [B(-0.08, 0.18, 0.08), C(0.12, 0.15), HD(-0.15, 0.3, 0.12), TL(0.45, 0.05), KL(0.8, -0.4), TR(-0.12, 0.08), KR(0.2, -0.5), L(0.12, 0.92, 0.12, 0.45), R(-0.04, 0.95, 0.1, 0.4)])
	at(k, 105.3, [B(0.06, -0.12, -0.04), C(0.0, -0.12), HD(0.05, -0.25, -0.05), TL(-0.05, 0.1), KL(0.4, -0.45), TR(0.4, 0.06), KR(0.75, -0.4), {"shake": 0.4}])
	# Il entend Simon crier : la tête se tourne vers le bas, vers lui.
	at(k, 105.75, [B(0.0, 0.0, 0.0), C(0.08, 0.0), HD(-0.45, 0.1, 0.05), TL(0.2, 0.06), KL(0.55, -0.5), TR(0.1, 0.06), KR(0.45, -0.5), {"shake": 0.25}, FACE("surprise")])
	at(k, 106.3, [HD(-0.55, 0.12, 0.08), TL(0.15, 0.06), KL(0.5, -0.55), TR(0.12, 0.06), KR(0.5, -0.55), FACE("fear")])
	# Dernier sursaut : il tire sur la griffe, un coup de pied dans le vide…
	at(k, 106.9, [B(-0.1, 0.1, 0.05), C(0.18, 0.08), HD(-0.05, 0.15, 0.06), TL(0.6, 0.05), KL(1.1, -0.3), TR(-0.15, 0.08), KR(0.15, -0.5), L(0.06, 0.88, 0.14, 0.5), R(-0.08, 0.86, 0.15, 0.5), {"shake": 0.6, "sq": 0.97, "ev": "effort"}, FACE("pain")])
	at(k, 107.25, [B(0.08, -0.08, -0.04), C(0.05, -0.05), HD(-0.1, -0.1, -0.05), TL(-0.1, 0.08), KL(0.3, -0.5), TR(0.45, 0.06), KR(0.6, -0.45), {"shake": 0.45, "sq": 1.0}])
	# … puis il lâche : les bras retombent, le corps pend, il se balance un peu.
	at(k, 107.8, [B(0.04, 0.0, 0.0), C(0.15, 0.0), HD(-0.4, 0.05, 0.1), TL(0.12, 0.06), KL(0.35, -0.6), TR(0.06, 0.07), KR(0.3, -0.6), L(0.25, -0.2, 0.25, 0.4), R(0.22, 0.2, 0.25, 0.3), WL(0.3), WR(-0.3), {"curl": 0.5, "curl_l": 0.35, "shake": 0.1}, FACE("hurt")])
	at(k, 108.4, [B(0.02, 0.03, 0.03), C(0.18, 0.02), HD(-0.48, 0.08, 0.12), TL(0.1, 0.06), KL(0.4, -0.65), TR(0.08, 0.07), KR(0.32, -0.62), L(0.26, -0.55, 0.12, 0.3), R(0.25, 0.55, 0.12, 0.3), {"curl": 0.65, "curl_l": 0.3}])
	# Plan serré : il regarde Simon, triste ; « Simon. Cours. Te retourne pas. »
	at(k, 109.05, [B(0.0, 0.02, 0.02), C(0.12, 0.05), HD(-0.5, 0.12, 0.1), L(0.24, -0.72, 0.1, 0.2), R(0.24, 0.75, 0.1, 0.3), WR(-0.6), {"curl": 0.8, "curl_l": 0.2}, FACE("sad")])
	at(k, 109.9, [C(0.1, 0.05), HD(-0.46, 0.1, 0.06), {"curl_l": 0.35}])
	at(k, 110.7, [C(0.08, 0.06), HD(-0.52, 0.14, 0.04), L(0.22, -0.75, 0.12, 0.2)])
	# Il s'apaise : un souffle, les épaules se relâchent, la tête se redresse un peu (calme résigné).
	at(k, 111.6, [B(0.0, 0.0, 0.0), C(0.02, 0.04), HD(-0.36, 0.1, 0.02), L(0.28, -0.78, 0.08, 0.2), {"curl_l": 0.15}, FACE("calm")])
	at(k, 112.5, [C(0.0, 0.04), HD(-0.32, 0.08, 0.0), TL(0.08, 0.06), KL(0.3, -0.6), TR(0.06, 0.06), KR(0.28, -0.6)])
	# L'effacement (113,8 → 117,4) : il ferme les yeux, lève le visage, les mains s'ouvrent.
	at(k, 113.5, [B(-0.02, 0.0, 0.0), C(-0.05, 0.02), HD(-0.1, 0.05, 0.0), FACE("asleep")])
	at(k, 114.6, [B(-0.06, 0.0, 0.0), C(-0.12, 0.0), HD(0.15, 0.0, -0.04), L(0.42, -0.62, 0.12, 0.3), R(0.3, 0.7, 0.1, 0.3), {"curl": 0.4, "curl_l": 0.0}, FACE("calm")])
	at(k, 116.0, [C(-0.15, 0.0), HD(0.22, 0.0, -0.06), L(0.48, -0.55, 0.15, 0.35), {"curl": 0.2, "curl_l": 0.0}])
	at(k, 117.4, [C(-0.16, 0.0), HD(0.25, 0.0, -0.06), L(0.5, -0.5, 0.15, 0.35)])
	finish(k)

# --- Acte V : la fuite (122,95 → 149,2 s), Acte VI : le plongeon (149,2 → 150,65 s) -------------------

# Grille de la musique de poursuite (160 bpm) : une croche toutes les 0,1875 s depuis 122,164 s. Les
# appuis de la course tombent dessus.
const CHASE_GRID: float = 122.164
const CHASE_STEP: float = 0.1875

static func beat(n: int) -> float:
	return CHASE_GRID + CHASE_STEP * float(n)

# Vitesse (m/s) et cap de la course : panique à 8 m/s, saut de côté à 133,3, sursaut doré à 140,2.
const CHASE_SPEED: Array = [[124.5, 1.6], [124.8, 2.6], [125.1, 4.8], [125.5, 6.6], [126.0, 7.8], [126.6, 8.1], [131.9, 8.0], [132.15, 7.2], [132.6, 8.0], [133.2, 8.3], [133.4, 8.8], [133.8, 7.4], [134.4, 8.0], [140.1, 8.1], [140.5, 10.6], [141.0, 12.0], [149.2, 12.0]]
const CHASE_HEADING: Array = [[124.5, Vector3(0.0, 0, -1)], [126.0, Vector3(-0.05, 0, -1)], [131.8, Vector3(-0.06, 0, -1)], [132.2, Vector3(-0.16, 0, -1)], [132.9, Vector3(-0.08, 0, -1)], [133.3, Vector3(-0.1, 0, -1)], [133.45, Vector3(-0.62, 0, -1)], [133.8, Vector3(-0.5, 0, -1)], [134.3, Vector3(-0.04, 0, -1)], [149.2, Vector3(-0.03, 0, -1)]]


static func _chase() -> void :
	var who: String = "Simon"
	# Trajectoire et orientations d'abord : les pieds posés en dépendent.
	move(who, 123.4, 123.6, Vector3(0.0, 0.0, -0.12), "smooth")
	move(who, 123.6, 124.5, Vector3(0.0, 0.0, -1.78), "smooth")
	face(who, 124.5, Vector3(-1.0, 0.0, 0.35))
	face(who, 124.6, Vector3(-0.8, 0.0, -0.8))
	face(who, 124.7, Vector3(0.0, 0.0, -1.0))
	_plan(who).chase_end = drive(who, 124.5, 149.2, Vector3(0.0, 0.0, -1.78), CHASE_SPEED, CHASE_HEADING, 124.8)
	_dive_path()
	var k: Clip = clip(who, "pb_simon_flee", 122.95, 149.2, "panic")
	k.lag = {"head": 0.05, "ik_r": 0.035, "ik_l": 0.035, "curl": 0.06, "curl_l": 0.06}
	_flee_getup(k)
	_flee_run(k)
	finish(k)
	_dive()


# Il se relève en reculant face à Yiero (trois pas en arrière, pieds posés), puis pivote et s'enfuit.
static func _flee_getup(k: Clip) -> void :
	var who: String = "Simon"
	# Toujours à genoux (fin de pb_simon_floor), il pousse sur ses mains, le pied droit vient devant.
	at(k, 122.95, [base(), {"plant": 0.0, "gsnap": 1.0}, B(0.58, 0.0, 0.0), C(0.1, 0.0, 0.0), HD(0.42, 0.05, 0.0), kneel(0.8, 0.58, 0.22), Lg(0.0, 0.32), Rg(0.02, 0.36), WL(1.2), WR(1.2), {"curl": 0.6, "curl_l": 0.6, "shake": 0.4}, FACE("panic")])
	at(k, 123.12, [B(0.62, 0.05, 0.0), C(0.15, 0.05, 0.0), HD(0.5, 0.0, 0.0), half_kneel(1, 0.62), Lg(0.02, 0.26), Rg(0.06, 0.3), {"shake": 0.2, "sq": 0.97, "ev": "gasp"}])
	# Il se redresse d'un bloc, déjà penché en arrière ; les pieds passent sur l'appui (IK).
	at(k, 123.3, [{"plant": 0.5, "gsnap": 0.4}, H(0.0, -0.3, 0.05), B(0.35, 0.0, 0.0), C(0.1, 0.0, 0.0), HD(0.55, 0.0, 0.0), Lt(0.15, -0.55, 0.25, 0.3), Rt(0.15, -0.5, 0.3, 0.3), {"curl": 0.5, "curl_l": 0.5, "sq": 1.02}])
	at(k, 123.48, [{"plant": 1.0, "gsnap": 0.0}, {"hips": hips(who, Vector3(0.0, -0.12, 0.04))}, B(-0.05, 0.0, 0.0), C(-0.08, 0.0, 0.0), HD(0.55, 0.05, 0.0), Lt(0.2, -0.15, 0.45, 0.5), Rt(0.15, -0.05, 0.5, 0.5), WL(0.5), WR(0.5), {"curl": 0.3, "curl_l": 0.3, "sq": 1.0}])
	# Recul : trois pas en arrière, le buste penché vers l'arrière, les mains devant lui.
	var feet: Dictionary = {-1: Vector3(0.12, 0.0, -0.3), 1: Vector3(-0.13, 0.0, 0.28)}
	var plan: Array = [
		[123.62, 123.9, 1, Vector3(-0.14, 0.0, -0.85)],
		[123.9, 124.18, -1, Vector3(0.13, 0.0, -1.45)],
		[124.18, 124.46, 1, Vector3(-0.14, 0.0, -2.0)],
	]
	steps(k, feet, plan, {"lift": 0.06, "roll": 0.35, "land": -0.15, "begin": 123.45, "end": 124.55})
	at(k, 123.66, [{"hips": hips(who, Vector3(-0.015, -0.08, 0.0))}, B(-0.1, -0.05, 0.02), C(-0.12, 0.04), HD(0.52, 0.0, 0.0), Lt(0.25, 0.0, 0.42, 0.5), Rt(0.2, 0.1, 0.5, 0.5), {"curl": 0.2, "curl_l": 0.25}])
	at(k, 123.94, [{"hips": hips(who, Vector3(0.015, -0.06, 0.0))}, B(-0.12, 0.05, -0.02), C(-0.1, -0.05), HD(0.48, 0.05, 0.0), Lt(0.28, 0.05, 0.4, 0.5), Rt(0.18, 0.05, 0.46, 0.5)])
	at(k, 124.22, [{"hips": hips(who, Vector3(-0.015, -0.09, 0.0))}, B(-0.08, -0.05, 0.02), C(-0.06, 0.04), HD(0.45, -0.1, 0.0), Lt(0.25, 0.0, 0.4, 0.5), Rt(0.22, 0.12, 0.44, 0.5), {"shake": 0.3}])
	# Le regard d'abord (par-dessus l'épaule droite), puis le buste, puis tout le corps : il pivote.
	at(k, 124.42, [{"hips": hips(who, Vector3(0.0, -0.1, 0.0))}, B(0.0, -0.1, 0.0), C(0.0, -0.25), HD(0.15, -0.95, 0.0), Lt(0.3, -0.1, 0.35, 0.5), Rt(0.25, -0.1, 0.2, 0.5), {"curl": 0.3, "curl_l": 0.3, "shake": 0.0}])
	at(k, 124.56, [{"hips": hips(who, Vector3(0.0, -0.12, 0.0))}, B(0.15, -0.4, 0.0), C(0.15, -0.35), HD(0.05, -0.6, 0.0)])
	# Pivot sur le pied droit (posé jusqu'à 124,86) ; le gauche part vers le premier appui de la course.
	_planted(k, who, 1, Vector3(-0.14, 0.0, -2.0), 124.47, 124.86, 0.0)


# Course de 124,79 à 149,2 : deux tronçons autour du saut de côté (133,23 → 133,98).
static func _flee_run(k: Clip) -> void :
	var who: String = "Simon"
	var style: Dictionary = {
		"period": [[124.7, 0.27], [125.0, 0.215], [125.4, CHASE_STEP]],
		"duty": [[124.7, 0.62], [125.2, 0.48], [125.8, 0.38], [126.4, 0.36], [140.1, 0.36], [140.8, 0.31]],
		"lean": [[124.7, 0.62], [125.3, 0.55], [126.2, 0.42], [131.9, 0.4], [132.05, 0.22], [132.5, 0.4], [140.1, 0.42], [140.6, 0.82], [149.2, 0.86]],
		"chest": [[124.7, 0.2], [126.2, 0.08], [131.95, -0.12], [132.4, 0.06], [140.1, 0.06], [140.6, 0.28], [149.2, 0.3]],
		"head": [[124.7, 0.4], [126.2, 0.36], [140.1, 0.38], [140.6, 0.78], [149.2, 0.8]],
		"kick": [[124.7, 0.22], [125.5, 0.38], [126.4, 0.44], [140.1, 0.44], [140.6, 0.5]],
		"knee": [[124.7, 0.26], [125.5, 0.32], [126.4, 0.34], [140.1, 0.34], [140.6, 0.38]],
		"drop": [[124.7, 0.1], [125.5, 0.07], [126.4, 0.055], [140.1, 0.055], [140.6, 0.065]],
		"width": [[124.7, 0.11], [126.0, 0.075], [140.1, 0.07], [140.6, 0.05]],
		"panic": [[124.7, 0.8], [126.5, 0.9], [131.8, 0.75], [132.6, 0.35], [140.0, 0.25], [140.4, 0.0]],
		"sonic": [[140.15, 0.0], [140.6, 1.0]],
		"strength": [[124.7, 0.5], [126.0, 0.9], [140.1, 0.9], [140.6, 1.2]],
		"look": [[128.1, 129.05, -1, 1.0], [136.35, 136.95, 1, 0.7], [145.25, 145.85, -1, 0.55]],
		"seed": 11,
	}
	var first: Dictionary = style.duplicate()
	first.t0 = beat(14)
	first.t1 = beat(58) + 0.01
	first.side = -1
	first.prev = {-1: [124.55, Vector3(0.13, 0.0, -1.45)], 1: [124.86, Vector3(-0.14, 0.0, -2.0)]}
	run(k, first)
	# Faces et réactions pendant la course.
	at(k, 125.0, [FACE("panic")])
	at(k, 128.2, [FACE("fear")])
	at(k, 129.1, [FACE("panic")])
	# 131,95 : la griffe jaillit devant lui, sur la droite : il sursaute, se protège, dévie.
	at(k, 131.93, [Lt(0.45, 0.35, 0.3, 0.7), Rt(0.1, 0.55, 0.45, 0.6), {"curl": 0.2, "curl_l": 0.2, "ev": "gasp"}, FACE("surprise")])
	at(k, 132.25, [FACE("panic")])
	_flee_leap(k)
	var second: Dictionary = style.duplicate()
	second.t0 = beat(63)
	second.t1 = beat(144) + 0.01
	second.side = 1
	second.prev = {-1: [beat(63) - 0.02, _plan(who).leap_land]}
	run(k, second)
	at(k, 134.2, [FACE("panic")])
	at(k, 136.4, [FACE("fear")])
	at(k, 137.0, [FACE("panic")])
	# 140,17 : sursaut doré, il se penche, bras tendus en arrière, mâchoire serrée.
	at(k, 140.17, [{"ev": "effort"}, FACE("determined")])
	at(k, 141.0, [FACE("surprise")])
	at(k, 141.7, [FACE("determined")])
	at(k, 144.9, [FACE("pain")])
	at(k, 145.3, [FACE("fear")])
	at(k, 145.9, [FACE("determined")])
	# Dernier appui de course (148,98, pied droit) : le plongeon part du pied gauche (pb_simon_dive).
	at(k, 149.2, [FACE("determined")])


# 133,23 : la griffe va jaillir là où il court : il pousse fort du pied droit et plonge sur la gauche,
# se rattrape du pied gauche, la main gauche touche le sol, et repart.
static func _flee_leap(k: Clip) -> void :
	var who: String = "Simon"
	var push: float = beat(59)
	var push_off: float = push + 0.13
	var land: float = beat(62)
	# Appui de poussée (pied droit), long et profond.
	var direction: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, yaw(who, push))
	var right_dir: Vector3 = Vector3.UP.cross(direction).normalized() * -1.0
	var push_spot: Vector3 = root(who, push + 0.06) + right_dir * 0.12
	push_spot.y = 0.0
	_contacts.append([push, who, push_spot, 1.1])
	var land_spot: Vector3 = root(who, land + 0.05) - right_dir * 0.18
	land_spot.y = 0.0
	_plan(who).leap_land = land_spot
	_contacts.append([land, who, land_spot, 1.3])
	var catch_t: float = beat(63)
	k.keys.append([push, {"foot_r": foot(who, 1, to_body(who, push, push_spot), -0.15), "fp_r": -0.15}, "l"])
	k.keys.append([push + 0.07, {"foot_r": foot(who, 1, to_body(who, push + 0.07, push_spot), 0.0), "fp_r": 0.0}, "l"])
	k.keys.append([push_off, {"foot_r": foot(who, 1, to_body(who, push_off, push_spot), -0.9), "fp_r": -0.9}])
	# En vol : jambes repliées, le corps s'allonge vers la gauche.
	k.keys.append([push_off + 0.12, {"foot_r": foot(who, 1, Vector3(0.2, 0.42, 0.25), -1.0), "fp_r": -1.0, "foot_l": foot(who, -1, Vector3(-0.15, 0.35, -0.2), -0.6), "fp_l": -0.6}])
	k.keys.append([land - 0.1, {"foot_l": foot(who, -1, to_body(who, land - 0.1, land_spot) + Vector3(0.0, 0.12, 0.0), 0.15), "fp_l": 0.15}])
	k.keys.append([land, {"foot_l": foot(who, -1, to_body(who, land, land_spot), 0.1), "fp_l": 0.1}, "l"])
	k.keys.append([land + 0.12, {"foot_l": foot(who, -1, to_body(who, land + 0.12, land_spot), 0.0), "fp_l": 0.0}, "l"])
	k.keys.append([land - 0.04, {"foot_r": foot(who, 1, Vector3(0.25, 0.25, 0.1), -0.8), "fp_r": -0.8}])
	# Bassin, buste, bras : poussée, envol couché sur le côté, réception écrasée, main au sol.
	at(k, push, [{"hips": hips(who, Vector3(0.03, -0.1, 0.0))}, B(0.45, 0.1, 0.12), C(0.1, 0.1, 0.1), HD(0.3, 0.3, 0.0), Lt(0.5, 0.2, 0.3, 0.6), Rt(0.2, -0.4, -0.3, 0.4), {"curl": 0.3, "curl_l": 0.2, "sq": 0.96, "ev": "effort"}, FACE("panic")])
	at(k, push + 0.07, [{"hips": hips(who, Vector3(0.04, -0.13, 0.0))}, B(0.4, 0.15, 0.25), C(0.05, 0.15, 0.15), HD(0.32, 0.35, -0.1)])
	at(k, push_off, [{"hips": hips(who, Vector3(0.0, -0.02, 0.0))}, B(0.3, 0.2, 0.42), C(-0.05, 0.2, 0.2), HD(0.3, 0.4, -0.2), Lt(0.65, 0.35, 0.25, 0.7), Rt(0.4, 0.5, 0.2, 0.6), {"sq": 1.04}])
	at(k, push_off + 0.2, [{"hips": hips(who, Vector3(0.0, 0.18, 0.0))}, B(0.35, 0.2, 0.62), C(-0.05, 0.15, 0.25), HD(0.25, 0.35, -0.3), Lt(0.7, 0.2, 0.3, 0.8), Rt(0.45, 0.65, 0.1, 0.6), {"sq": 1.0}, FACE("fear")])
	at(k, land - 0.08, [{"hips": hips(who, Vector3(-0.05, 0.05, 0.0))}, B(0.42, 0.15, 0.45), C(0.05, 0.1, 0.2), HD(0.3, 0.2, -0.2), Lt(0.55, -0.35, 0.35, 0.6), Rt(0.35, 0.4, 0.2, 0.5)])
	at(k, land + 0.03, [{"hips": hips(who, Vector3(-0.06, -0.24, 0.0))}, B(0.62, 0.1, 0.3), C(0.25, 0.05, 0.15), HD(0.35, 0.1, -0.1), Lg(0.25, 0.25, 0.05), Rt(0.4, 0.25, 0.1, 0.5), {"sq": 0.93, "ev": "hurt"}, FACE("pain")], "s")
	at(k, land + 0.12, [{"hips": hips(who, Vector3(-0.04, -0.2, 0.0))}, B(0.58, 0.05, 0.18), C(0.2, 0.0, 0.08), HD(0.4, 0.05, 0.0), Lg(0.2, 0.15, 0.08), Rt(0.3, 0.1, 0.25, 0.5), {"sq": 1.0}])
	at(k, catch_t + 0.03, [{"hips": hips(who, Vector3(0.0, -0.12, 0.0))}, B(0.52, 0.0, 0.05), C(0.12, 0.0, 0.0), HD(0.42, 0.0, 0.0), Lt(0.3, -0.25, 0.1, 0.4), Rt(0.15, -0.2, 0.45, 0.3), {"curl": 0.4, "curl_l": 0.3}, FACE("panic")])


# Trajet du plongeon (ralenti 149,2 → 150,6 : 12 m/s × 0,3 en temps du film) : il monte de 1 m puis file
# vers la porte, posée juste au-delà.
static func _dive_path() -> void :
	var who: String = "Simon"
	var start: Vector3 = root(who, 149.2)
	var direction: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, yaw(who, 149.2))
	move(who, 149.2, 149.6, start + direction * 1.45 + Vector3.UP * 0.55, "linear")
	move(who, 149.6, 150.2, start + direction * 3.6 + Vector3.UP * 1.0, "linear")
	move(who, 150.2, 150.62, start + direction * 5.1 + Vector3.UP * 0.95, "linear")
	face(who, 149.2, direction)
	_plan(who).door = start + direction * 5.6


# Le plongeon dans la porte : dernier appui du pied gauche (149,16), poussée, corps allongé, bras
# devant ; ralenti 149,2 → 150,6 (×0,3) ; il disparaît dans la lumière à 150,65.
static func _dive() -> void :
	var who: String = "Simon"
	var t0: float = beat(144)
	var k: Clip = clip(who, "pb_simon_dive", t0, 150.7, "determined")
	k.lag = {"head": 0.06, "ik_r": 0.05, "ik_l": 0.05}
	var spot: Vector3 = root(who, t0 + 0.04)
	spot.y = 0.0
	_contacts.append([t0, who, spot, 1.4])
	var off: float = 149.31
	at(k, t0, [base(), {"foot_l": foot(who, -1, to_body(who, t0, spot), -0.2), "fp_l": -0.2, "foot_r": foot(who, 1, Vector3(0.1, 0.38, 0.22), -1.1), "fp_r": -1.1}, {"hips": hips(who, Vector3(0.0, -0.06, 0.0))}, B(0.86), C(0.3), HD(0.8), Lt(0.28, -0.42, -0.84, 0.15), Rt(0.28, -0.42, -0.88, 0.15), WL(-0.5, 0, -0.8), WR(-0.5, 0, 0.8), {"curl": 0.1, "curl_l": 0.1}], "l")
	k.keys.append([t0 + 0.07, {"foot_l": foot(who, -1, to_body(who, t0 + 0.07, spot), 0.0), "fp_l": 0.0}, "l"])
	k.keys.append([off, {"foot_l": foot(who, -1, to_body(who, off, spot), -0.95), "fp_l": -0.95}])
	# Poussée : les bras passent de l'arrière à l'avant, le corps se déplie.
	at(k, t0 + 0.08, [{"hips": hips(who, Vector3(0.0, -0.12, 0.0))}, B(0.8), C(0.25), HD(0.75), Lt(0.2, -0.3, -0.5, 0.2), Rt(0.2, -0.3, -0.55, 0.2), {"foot_r": foot(who, 1, Vector3(0.1, 0.3, -0.25), -0.6), "fp_r": -0.6, "sq": 0.95, "ev": "effort"}])
	at(k, off, [{"hips": hips(who, Vector3(0.0, 0.0, 0.0))}, B(0.95), C(0.1), HD(0.7), Lt(0.18, 0.1, 0.55, 0.15), Rt(0.15, 0.18, 0.6, 0.15), WL(0.0), WR(0.0), {"foot_r": foot(who, 1, Vector3(0.1, 0.5, -0.1), -0.4), "fp_r": -0.4, "curl": 0.0, "curl_l": 0.0, "sq": 1.04}])
	# En l'air : allongé, bras tendus vers la lumière, jambes qui suivent.
	at(k, 149.6, [{"plant": 0.0}, B(1.25), C(-0.1), HD(0.9), Lt(0.16, 0.2, 0.92, 0.1), Rt(0.12, 0.25, 0.95, 0.1), TL(0.05, 0.08), KL(0.35, -0.6), TR(-0.15, 0.08), KR(0.8, -0.7), {"sq": 1.0}])
	at(k, 150.2, [B(1.4), C(-0.15), HD(0.95), Lt(0.14, 0.28, 0.95, 0.1), Rt(0.1, 0.3, 0.97, 0.1), TL(0.0, 0.06), KL(0.25, -0.7), TR(-0.25, 0.06), KR(0.6, -0.8), FACE("pain")])
	at(k, 150.65, [B(1.45), C(-0.15), HD(0.95), TL(0.0, 0.06), KL(0.2, -0.7), TR(-0.3, 0.06), KR(0.5, -0.8)])
	finish(k)


# --- Outils de mouvement ------------------------------------------------------------------------------

# Courbe [[t, valeur], ...] lissée entre les points (smoothstep).
static func curve(rows: Array, t: float) -> float:
	if rows.is_empty(): return 0.0
	if t <= float(rows[0][0]): return float(rows[0][1])
	for i: int in range(1, rows.size()):
		if t <= float(rows[i][0]):
			var a: Array = rows[i - 1]
			var b: Array = rows[i]
			return lerpf(float(a[1]), float(b[1]), smoothstep(float(a[0]), float(b[0]), t))
	return float(rows[rows.size() - 1][1])


# Fenêtre 0 → 1 → 0 : monte de a à a + ramp, redescend de b - ramp à b.
static func bump(t: float, a: float, b: float, ramp: float) -> float:
	return smoothstep(a, a + ramp, t) * (1.0 - smoothstep(b - ramp, b, t))


# Trajectoire écrite par sa vitesse : de t0 à t1, part de `from` et suit la direction dir(t) (rows de
# Vector3) à la vitesse speed(t) (m/s) ; un point tous les `step` s (segments linéaires : les pieds
# posés reculent exactement à la vitesse du sol). Renvoie la position d'arrivée.
static func drive(person: String, t0: float, t1: float, from: Vector3, speed: Array, heading: Array, face_from: float = -1.0, step: float = 0.05) -> Vector3:
	var at: Vector3 = from
	var t: float = t0
	var last_face: float = face_from - 0.2
	while t < t1 - 0.0001:
		var t_next: float = minf(t1, t + step)
		var mid: float = (t + t_next) * 0.5
		var direction: Vector3 = _heading(heading, mid)
		at += direction * curve(speed, mid) * (t_next - t)
		move(person, t, t_next, at, "linear")
		if mid - last_face >= 0.2 and t >= face_from:
			face(person, t, direction)
			last_face = mid
		t = t_next
	return at


static func _heading(rows: Array, t: float) -> Vector3:
	if t <= float(rows[0][0]): return (rows[0][1] as Vector3).normalized()
	for i: int in range(1, rows.size()):
		if t <= float(rows[i][0]):
			var a: Array = rows[i - 1]
			var b: Array = rows[i]
			return (a[1] as Vector3).normalized().slerp((b[1] as Vector3).normalized(), smoothstep(float(a[0]), float(b[0]), t)).normalized()
	return (rows[rows.size() - 1][1] as Vector3).normalized()


# Pas « pieds d'abord » pour la marche, le recul, les fentes : plan = [[t_lever, t_poser, côté, Vector3
# appui (repère du film)], ...] ; feet = {côté: appui de départ}. Le pied posé est fixe dans le décor
# (clés denses quand le personnage bouge), le pied levé décrit un arc de hauteur o.lift ; talon qui
# décolle (o.roll) avant le lever, pointe qui se pose. Renvoie les appuis de chaque pied par instant.
static func steps(k: Clip, feet: Dictionary, plan: Array, o: Dictionary = {}) -> void :
	var person: String = k.person
	var lift: float = float(o.get("lift", 0.07))
	var roll: float = float(o.get("roll", 0.5))
	var land_pitch: float = float(o.get("land", 0.12))
	var t_end: float = float(o.get("end", k.end))
	var t_begin: float = float(o.get("begin", k.start))
	for side: int in [-1, 1]:
		var channel: String = "foot_l" if side < 0 else "foot_r"
		var pitch: String = "fp_l" if side < 0 else "fp_r"
		var spot: Vector3 = feet[side]
		var since: float = t_begin
		for row: Array in plan:
			if int(row[2]) != side: continue
			var t_lift: float = float(row[0])
			var t_land: float = float(row[1])
			var to: Vector3 = row[3]
			_planted(k, person, side, spot, since, t_lift - 0.06, 0.0)
			# Le talon décolle, puis la pointe quitte le sol.
			k.keys.append([t_lift - 0.03, {channel: foot(person, side, to_body(person, t_lift - 0.03, spot), - roll * 0.6), pitch: - roll * 0.6}])
			k.keys.append([t_lift, {channel: foot(person, side, to_body(person, t_lift, spot) + Vector3.UP * 0.01, - roll), pitch: - roll}])
			for u: float in [0.3, 0.6, 0.85]:
				var t: float = lerpf(t_lift, t_land, u)
				var p: Vector3 = spot.lerp(to, smoothstep(0.0, 1.0, u))
				var local: Vector3 = to_body(person, t, p)
				local.y = lift * sin(PI * minf(1.0, u * 1.1))
				var a: float = lerpf( - roll * 0.8, land_pitch, smoothstep(0.2, 0.9, u))
				k.keys.append([t, {channel: foot(person, side, local, a), pitch: a}])
			k.keys.append([t_land, {channel: foot(person, side, to_body(person, t_land, to), land_pitch), pitch: land_pitch}, "l"])
			spot = to
			since = t_land + 0.04
			k.keys.append([since, {channel: foot(person, side, to_body(person, since, to)), pitch: 0.0}, "l"])
		_planted(k, person, side, spot, since, t_end, 0.0)


# Pied posé à `spot` (repère du film) de t0 à t1 : clés au 1/30 s quand le personnage bouge.
static func _planted(k: Clip, person: String, side: int, spot: Vector3, t0: float, t1: float, pitch_value: float) -> void :
	if t1 <= t0: return
	var channel: String = "foot_l" if side < 0 else "foot_r"
	var pitch: String = "fp_l" if side < 0 else "fp_r"
	var t: float = t0
	var previous: Vector3 = Vector3.INF
	while true:
		var local: Vector3 = to_body(person, t, spot)
		if previous == Vector3.INF or local.distance_to(previous) > 0.004 or t >= t1:
			k.keys.append([t, {channel: foot(person, side, local, pitch_value), pitch: pitch_value}, "l"])
			previous = local
		if t >= t1: break
		t = minf(t1, t + 1.0 / 30.0)


# Course écrite pas à pas sur la trajectoire (repère du film). r = {
#   "t0", "t1" : premier appui, fin (aucune clé de course après t1) ; "side" : pied du premier appui ;
#   courbes [[t, v]] : "period" (s entre deux appuis), "duty" (part d'appui), "lean" (bassin vers l'avant),
#   "chest", "head" (redresse la tête), "kick" (talon vers la fesse, m), "knee" (genou levé, m), "drop"
#   (bassin qui s'écrase à l'appui, m), "width" (écart des appuis, m), "panic" et "sonic" (0 → 1 : style
#   des bras), "look" ([[t0, t1, côté, force]] regards par-dessus l'épaule), "seed" }.
# Les appuis tombent exactement aux instants t0 + Σ period ; chaque appui est posé sous le bassin au
# milieu de son temps d'appui et ne bouge plus. Ajoute les appuis à contacts().
static func run(k: Clip, r: Dictionary) -> Array:
	var person: String = k.person
	var t1: float = float(r.t1)
	var seed_value: int = int(r.get("seed", 3))
	var rows: Array = []
	var t: float = float(r.t0)
	var side: int = int(r.get("side", -1))
	while t <= t1 + 0.0001:
		var period: float = curve(r.period, t)
		var contact: float = period * curve(r.duty, t)
		rows.append([t, side, contact, period])
		t += period
		side = - side
	var steps_out: Array = []
	var seen: Dictionary = {}
	for n: int in range(rows.size()):
		var tc: float = float(rows[n][0])
		var s: int = int(rows[n][1])
		var c: float = float(rows[n][2])
		var period: float = float(rows[n][3])
		var jitter: float = _noise(seed_value, n)
		var mid_t: float = tc + c * 0.5
		var off_t: float = tc + c
		var direction: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, yaw(person, mid_t))
		var lateral: Vector3 = Vector3.UP.cross(direction).normalized() * - 1.0
		var spot: Vector3 = root(person, mid_t) + lateral * float(s) * curve(r.width, mid_t)
		spot.y = 0.0
		steps_out.append([tc, s, spot, c])
		_contacts.append([tc, person, spot, clampf(curve(r.get("strength", [[0.0, 1.0]]), tc), 0.2, 1.5)])
		var channel: String = "foot_l" if s < 0 else "foot_r"
		var pitch: String = "fp_l" if s < 0 else "fp_r"
		# Premier appui d'un pied : il vient de son appui précédent (r.prev = {côté: [t_lever, appui]}) en arc.
		if not seen.has(s) and (r.get("prev", {}) as Dictionary).has(s):
			var prev: Array = r.prev[s]
			var t_lift: float = float(prev[0])
			var from: Vector3 = prev[1]
			k.keys.append([t_lift, {channel: foot(person, s, to_body(person, t_lift, from), -0.8), pitch: -0.8}])
			for u: float in [0.3, 0.6, 0.85]:
				var at: float = lerpf(t_lift, tc, u)
				var local: Vector3 = to_body(person, at, from.lerp(spot, smoothstep(0.0, 1.0, u)))
				local.y = curve(r.knee, at) * sin(PI * minf(1.0, u * 1.08))
				var a: float = lerpf(-0.9, -0.1, u)
				k.keys.append([at, {channel: foot(person, s, local, a), pitch: a}])
		seen[s] = true
		# Appui : la pointe se pose, le pied s'aplatit, le talon décolle ; fixe dans le décor.
		var land_local: Vector3 = to_body(person, tc, spot)
		var mid_local: Vector3 = to_body(person, mid_t, spot)
		var off_local: Vector3 = to_body(person, off_t, spot)
		k.keys.append([tc, {channel: foot(person, s, land_local, -0.2), pitch: -0.2}, "l"])
		k.keys.append([mid_t, {channel: foot(person, s, mid_local, 0.0), pitch: 0.0}, "l"])
		k.keys.append([off_t, {channel: foot(person, s, off_local, -0.75), pitch: -0.75}])
		# Vol du pied (repère du personnage) jusqu'à son prochain appui (n + 2).
		var next_t: float = float(rows[n + 2][0]) if n + 2 < rows.size() else off_t + 2.0 * period - c
		var swing: float = next_t - off_t
		var kick: float = curve(r.kick, off_t) * (1.0 + 0.08 * jitter)
		var knee: float = curve(r.knee, off_t) * (1.0 - 0.06 * jitter)
		var x: float = off_local.x
		var swing_rows: Array = [
			[0.2, Vector3(x * 1.1, kick * 0.75, off_local.z * 0.9 + 0.04), -1.05],
			[0.42, Vector3(x * 0.9, kick, off_local.z * 0.35), -1.2],
			[0.66, Vector3(x * 0.8, knee, -0.1), -0.55],
			[0.86, Vector3(x * 0.95, knee * 0.45, land_local.z - 0.12), -0.05],
		]
		for row: Array in swing_rows:
			var at: float = off_t + swing * float(row[0])
			if at > t1: continue
			k.keys.append([at, {channel: foot(person, s, row[1], float(row[2])), pitch: float(row[2])}])
		# Bassin : s'écrase à l'appui, remonte en vol ; jamais plus haut que ce que la jambe atteint.
		var drop: float = curve(r.drop, tc) * (1.0 + 0.12 * jitter)
		var feet_land: Dictionary = {s: land_local}
		var feet_mid: Dictionary = {s: mid_local}
		var feet_off: Dictionary = {s: off_local}
		var y_land: float = fit_drop(person, Vector3(0.0, - drop * 0.55, 0.0), feet_land)
		var y_mid: float = fit_drop(person, Vector3(0.0, - drop, 0.0), feet_mid)
		var y_off: float = fit_drop(person, Vector3(0.0, - drop * 0.35, 0.0), feet_off)
		var sway: float = 0.012 * float(s)
		k.keys.append([tc, {"hips": hips(person, Vector3(sway, y_land, 0.0))}])
		k.keys.append([mid_t, {"hips": hips(person, Vector3(sway * 1.3, y_mid, 0.0))}])
		k.keys.append([off_t, {"hips": hips(person, Vector3(sway, y_off, 0.0))}])
		k.keys.append([off_t + (period - c) * 0.5, {"hips": hips(person, Vector3(0.0, drop * 0.15, 0.0))}])
		# Bassin tourné vers la jambe qui passe devant, buste à l'opposé, tête stable ; regards en arrière.
		var lean: float = curve(r.lean, tc) + 0.02 * jitter
		var chest: float = curve(r.chest, tc)
		var look: float = 0.0
		for w: Array in r.get("look", []):
			look += float(w[2]) * float(w[3]) * bump(tc, float(w[0]), float(w[1]), 0.22)
		var twist: float = 0.16 * float(s) * (1.0 - 0.6 * curve(r.get("sonic", [[0.0, 0.0]]), tc))
		var body_t: float = tc + 0.015
		k.keys.append([body_t, M([B(lean, - twist, -0.03 * float(s)), C(chest - absf(look) * 0.15, twist * 1.6 + look * 0.45, 0.02 * float(s)), HD(curve(r.head, tc) + absf(look) * 0.1, - twist * 0.8 + look * 1.15, 0.0)])])
		k.keys.append([off_t + (period - c) * 0.5, M([B(lean + 0.03, 0.0, 0.0), C(chest, look * 0.45, 0.0), HD(curve(r.head, tc) + absf(look) * 0.1, look * 1.15, 0.0)])])
		# Bras opposés aux jambes, légèrement en retard ; style pompe / panique / Sonic.
		var panic: float = curve(r.get("panic", [[0.0, 0.0]]), tc)
		var sonic: float = curve(r.get("sonic", [[0.0, 0.0]]), tc)
		var fore: int = - s
		var arm_t: float = tc + 0.03
		var lead: Vector3 = Vector3(0.05, -0.12, 0.55).lerp(Vector3(0.32, 0.12 + 0.1 * jitter, 0.45), panic)
		var back: Vector3 = Vector3(0.16, -0.55, -0.38).lerp(Vector3(0.35, -0.35, -0.5), panic)
		var tail_l: Vector3 = Vector3(0.28, -0.42, -0.86 + 0.03 * float(fore))
		var tail_r: Vector3 = Vector3(0.28, -0.42, -0.86 - 0.03 * float(fore))
		var hand_fore: Vector3 = lead.lerp(tail_l if fore < 0 else tail_r, sonic)
		var hand_back: Vector3 = back.lerp(tail_r if fore < 0 else tail_l, sonic)
		var arms: Dictionary = {}
		var flare: float = lerpf(0.15, 0.45, panic)
		if fore < 0:
			arms = M([Lt(hand_fore.x, hand_fore.y, hand_fore.z, flare), Rt(hand_back.x, hand_back.y, hand_back.z, flare)])
		else:
			arms = M([Rt(hand_fore.x, hand_fore.y, hand_fore.z, flare), Lt(hand_back.x, hand_back.y, hand_back.z, flare)])
		arms["l_hand"] = Vector3(lerpf(0.1, -0.5, sonic), 0.0, lerpf(0.0, -0.8, sonic))
		arms["r_hand"] = Vector3(lerpf(0.1, -0.5, sonic), 0.0, lerpf(0.0, 0.8, sonic))
		arms["curl"] = lerpf(lerpf(0.85, 0.25, panic), 0.1, sonic)
		arms["curl_l"] = arms["curl"]
		k.keys.append([arm_t, arms])
	return steps_out

static func _school() -> void :
	pass

# Poses d'essai tenues 1 s chacune (banc tools/pb_pose.gd, --pb-step 1) : calage des axes du squelette.
static func _bench() -> void :
	var poses: Array = [
		# 0 : à plat ventre, appuyé sur les avant-bras, tête levée
		M([base(), {"plant": 0.0, "gsnap": 1.0}, B(1.3), C(-0.3), HD(0.7), TL(0.15, 0.06), KL(0.35, 0.3), TR(0.05, 0.08), KR(0.6, 0.3), Lg(0.2, 0.45), Rg(0.15, 0.5), {"el_l": 0.7, "el_r": 0.7}, WL(0.6), WR(0.6), FACE("pain")]),
		# 1 : appuyé sur la main gauche, bras droit tendu vers le haut
		M([base(), {"plant": 0.0, "gsnap": 1.0}, B(1.0, 0.25, -0.15), C(-0.35, 0.3), HD(0.6, 0.35), TL(0.25, 0.06), KL(0.5, 0.3), TR(0.1, 0.1), KR(0.8, 0.3), Lg(0.05, 0.35), R(0.2, 0.75, 0.6, 0.2), {"el_l": 0.3}, WL(1.2), WR(0.0), {"curl": 0.1, "curl_l": 0.2}, FACE("panic")]),
		# 2 : à genoux, assis sur les talons, mains au sol
		M([base(), {"plant": 0.0, "gsnap": 1.0}, B(0.35), C(0.15), HD(0.1), TL(1.75, 0.2), KL(2.4, -0.8), TR(1.75, 0.2), KR(2.4, -0.8), Lg(0.1, 0.25), Rg(0.12, 0.3), WL(1.0), WR(1.0), FACE("sad")]),
		# 3 : à genoux, buste droit, tête renversée (cri)
		M([base(), {"plant": 0.0, "gsnap": 1.0}, B(-0.1), C(-0.25), HD(0.9), TL(1.6, 0.2), KL(2.3, -0.8), TR(1.6, 0.2), KR(2.3, -0.8), L(0.25, -0.85, -0.1, 0.2), R(0.25, -0.85, -0.1, 0.2), {"curl": 1.0, "curl_l": 1.0}, FACE("pain")]),
	]
	var k: Clip = clip("Simon", "pbt_simon_floor", 0.0, float(poses.size()))
	for i: int in range(poses.size()): at(k, float(i), [poses[i]], "h")
	_bench_clip(k)


# Clip d'essai : enregistré sans entrée dans plays().
static func _bench_clip(k: Clip) -> void :
	finish(k)
	_plays.pop_back()
