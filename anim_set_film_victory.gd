extends "res://anim_pose.gd"

# Victoires LMS (0.17) : chaque mouvement de corps des six films, écrit clé par
# clé pour ses plans. Aucun clip, émote ni geste de capacité du jeu : dans ces
# films, film_victories.gd coupe la démarche et les appuis du jeu ("gait": 0,
# acteurs « en l'air » pour le moteur) et les corps ne suivent que ces clés.
#
# Les clés sont données en temps du film : _film() les ramène au début du clip
# et range ce début dans "at" (film_victories.gd le relit pour lancer le clip au
# bon instant). Les coups tombent ainsi sur les instants des stingers.
# Noms : fv_<film>_<partie>, et fv_<film>_alice_<partie> pour Alice.
#
# Unités : pieds et bassin en longueurs de jambe, mains en longueurs de bras
# (voir anim_pose.gd) ; LEG et ARM donnent ces longueurs en mètres, pour poser
# les pas d'une course au rythme exact du déplacement.

const LEG: Dictionary = {"Simon": 0.699, "Usayuko": 0.675, "Ashura": 0.645, "Lysia": 0.864, "Elly": 0.783, "Bleuette": 0.683, "Alice": 0.863}
const ARM: Dictionary = {"Simon": 0.401, "Usayuko": 0.364, "Ashura": 0.469, "Lysia": 0.409, "Elly": 0.404, "Bleuette": 0.312, "Alice": 0.432}
# longueur du pied (cheville → orteils), en longueurs de jambe
const TOE: Dictionary = {"Simon": 0.15, "Usayuko": 0.03, "Ashura": 0.066, "Lysia": 0.029, "Elly": 0.214, "Bleuette": 0.091, "Alice": 0.135}


static func add(c: Dictionary) -> void :
	_usayuko(c)
	_simon(c)
	_ashura(c)


# ------------------------------------------------------------------- OUTILS --

static func K(t: float, pose: Dictionary, flag: String = "") -> Array:
	return [t, pose] if flag.is_empty() else [t, pose, flag]


# Clip écrit en temps du film : les clés sont décalées au début `start`, triées,
# et le clip reste sur sa dernière pose jusqu'à `end` (sans fondu de sortie).
static func _film(start: float, end: float, keys: Array, face: String = "") -> Dictionary:
	var shifted: Array = []
	for key: Array in keys:
		var copy: Array = key.duplicate()
		copy[0] = maxf(0.0, float(key[0]) - start)
		shifted.append(copy)
	shifted.sort_custom( func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	_hold_modes(shifted)
	return {"len": maxf(0.05, end - start), "in": 0.0, "out": 0.0, "face": face, "at": start, "keys": shifted}


# Les canaux de mode (jambes plantées ou libres, corps posé au sol) ne sont
# écrits qu'aux changements : sans clé de maintien, la courbe glisserait d'un
# état à l'autre pendant tout l'intervalle (jambes à moitié libres pendant des
# secondes). Chaque changement se fait donc en MODE_BLEND s, juste avant sa clé.
const MODE_CHANNELS: Array[String] = ["plant", "gsnap"]
const MODE_BLEND: float = 0.12

static func _hold_modes(keys: Array) -> void :
	var holds: Array = []
	for channel: String in MODE_CHANNELS:
		var last_t: float = -1.0
		var last_v: float = 0.0
		for key: Array in keys:
			var pose: Dictionary = key[1]
			if not pose.has(channel): continue
			var t: float = float(key[0])
			var v: float = float(pose[channel])
			if last_t >= 0.0 and absf(v - last_v) > 0.001 and t - last_t > MODE_BLEND + 0.05:
				holds.append([t - MODE_BLEND, {channel: last_v}, "s"])
			last_t = t
			last_v = v
	if holds.is_empty(): return
	keys.append_array(holds)
	keys.sort_custom( func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))


# Pose de départ complète : tous les canaux que le moteur pourrait laisser à une
# autre couche (démarche, pose « en l'air ») sont tenus par le clip.
static func _zero() -> Dictionary:
	return {"plant": 1.0, "gait": 0.0, "gsnap": 0.0, "shake": 0.0, "jaw": 0.0, "chatter": 0.0, "turn": 0.0, "sq": 1.0,
		"el_l": 0.0, "el_r": 0.0, "fp_l": 0.0, "fp_r": 0.0, "hips": Vector3.ZERO, "body": Vector3.ZERO, "chest": Vector3.ZERO,
		"head": Vector3.ZERO, "foot_l": Vector3.ZERO, "foot_r": Vector3.ZERO, "feet": Vector3.ZERO,
		"l_clav": Vector3.ZERO, "r_clav": Vector3.ZERO, "l_hand": Vector3.ZERO, "r_hand": Vector3.ZERO,
		"ik_l": Vector3(-0.3, -0.85, -0.1), "ik_r": Vector3(0.3, -0.85, -0.1), "tf_l": 0.0, "tf_r": 0.0, "gr_l": 0.0, "gr_r": 0.0,
		"ikw_l": 1.0, "ikw_r": 1.0, "curl": 0.3, "curl_l": 0.3}


# jambes en cinématique directe (avec "plant": 0) : cuisse vers l'avant, écart, rotation
static func TL(fwd: float, out: float = 0.0, yaw: float = 0.0) -> Dictionary:
	return {"l_leg": Vector3(fwd, yaw, - out)}

static func TR(fwd: float, out: float = 0.0, yaw: float = 0.0) -> Dictionary:
	return {"r_leg": Vector3(fwd, - yaw, out)}

static func KL(bend: float, ankle: float = 0.0) -> Dictionary:
	return {"l_knee": - bend, "l_ank": ankle}

static func KR(bend: float, ankle: float = 0.0) -> Dictionary:
	return {"r_knee": - bend, "r_ank": ankle}

# épaules : haussement (+) et avancée (+)
static func SH(left: float, right: float, fwd_l: float = 0.0, fwd_r: float = 0.0) -> Dictionary:
	return {"l_clav": Vector3(0.0, - fwd_l, - left), "r_clav": Vector3(0.0, fwd_r, right)}

static func FACE(mood: String) -> Dictionary:
	return {"face": mood}

# la même pose sans les pieds (quand une foulée déjà lancée les place)
static func _no_feet(pose: Dictionary) -> Dictionary:
	var copy: Dictionary = pose.duplicate()
	for channel: String in ["foot_l", "foot_r", "fp_l", "fp_r", "feet"]: copy.erase(channel)
	return copy

# clignement : les paupières se ferment un instant (humeur « asleep ») puis la
# mine `after` revient
static func blink(t: float, after: String, keys: Array, hold: float = 0.07) -> void :
	keys.append(K(t, FACE("asleep")))
	keys.append(K(t + hold, FACE(after)))


# Foulées écrites au mètre. `count` appuis espacés de `period` s à partir de
# `first` (pied gauche d'abord si `left`). L'acteur avance à `speed` m/s (le
# film lui donne ce trajet en segments linéaires) : le pied posé recule
# exactement à cette vitesse pendant l'appui, il ne glisse pas. Puis le talon
# remonte, le genou repasse devant et le pied se repose `reach` m devant.
# Le dernier appui reste posé (la suite du clip reprend la main).
# opts : stance (durée d'appui), reach, kick (hauteur du talon en longueurs de
# jambe), knee (hauteur du pied quand le genou passe), width, strike (inclinaison
# du pied au poser), push (à l'envol), bob (descente du bassin à l'appui), up
# (montée du bassin en l'air), hips (bassin de base : Vector3(droite, haut, avant)).
static func _strides(person: String, keys: Array, first: float, count: int, period: float, speed: float, left: bool = true, opts: Dictionary = {}) -> void :
	var leg: float = float(LEG[person])
	var toe: float = float(TOE[person])
	var stance: float = float(opts.get("stance", minf(0.16, period * 0.6)))
	var reach: float = float(opts.get("reach", 0.12 + speed * stance * 0.45))
	var kick: float = float(opts.get("kick", 0.42))
	var knee: float = float(opts.get("knee", 0.3))
	var width: float = float(opts.get("width", 0.05))
	var strike: float = float(opts.get("strike", -0.06))
	var push: float = float(opts.get("push", -0.55))
	var bob: float = float(opts.get("bob", 0.06))
	var rise: float = float(opts.get("up", 0.02))
	var base: Vector3 = opts.get("hips", Vector3(0.0, -0.08, 0.0))
	var swing: float = 2.0 * period - stance
	for i: int in range(count):
		var t: float = first + period * float(i)
		var is_left: bool = (i % 2 == 0) == left
		var foot: String = "foot_l" if is_left else "foot_r"
		var pitch: String = "fp_l" if is_left else "fp_r"
		var side: float = -1.0 if is_left else 1.0
		var off: float = reach - speed * stance
		keys.append([t, {foot: Vector3(side * width, 0.0, - reach / leg), pitch: strike}, "l"])
		# bassin : il s'écrase à mi-appui, remonte pendant l'envol
		keys.append([t + stance * 0.5, {"hips": Vector3(base.x + side * 0.02, base.y - bob, - base.z)}])
		if i < count - 1: keys.append([t + stance + (period - stance) * 0.5, {"hips": Vector3(base.x, base.y + rise, - base.z)}])
		if i == count - 1: continue
		var lift: float = toe * sin(- push)
		keys.append([t + stance, {foot: Vector3(side * width, lift, - off / leg), pitch: push}])
		keys.append([t + stance + swing * 0.22, {foot: Vector3(side * width, kick * 0.7, - (off - 0.05) / leg), pitch: push - 0.35}])
		keys.append([t + stance + swing * 0.48, {foot: Vector3(side * width * 0.6, kick, - ((off + reach) * 0.5 - 0.04) / leg), pitch: push * 0.9}])
		keys.append([t + stance + swing * 0.76, {foot: Vector3(side * width, knee, - (reach + 0.08) / leg), pitch: 0.12}])


# Foulée déjà lancée à `start` (avant le premier appui `first` de _strides,
# mêmes réglages) : sur une coupe franche, l'acteur marche déjà. Les deux pieds
# sont posés à `start` là où une marche établie les mettrait, puis finissent
# leur appui et leur envol jusqu'aux appuis écrits par _strides.
static func _stride_in(person: String, keys: Array, start: float, first: float, period: float, speed: float, left: bool = true, opts: Dictionary = {}) -> void :
	var leg: float = float(LEG[person])
	var toe: float = float(TOE[person])
	var stance: float = float(opts.get("stance", minf(0.16, period * 0.6)))
	var reach: float = float(opts.get("reach", 0.12 + speed * stance * 0.45))
	var kick: float = float(opts.get("kick", 0.42))
	var knee: float = float(opts.get("knee", 0.3))
	var width: float = float(opts.get("width", 0.05))
	var strike: float = float(opts.get("strike", -0.06))
	var push: float = float(opts.get("push", -0.55))
	var swing: float = 2.0 * period - stance
	var off: float = reach - speed * stance
	var lift: float = toe * sin(- push)
	# pied A : se pose à `first` ; pied B : s'est posé une période plus tôt
	for which: int in range(2):
		var is_left: bool = (which == 0) == left
		var foot: String = "foot_l" if is_left else "foot_r"
		var pitch: String = "fp_l" if is_left else "fp_r"
		var side: float = -1.0 if is_left else 1.0
		var land: float = first - (2.0 if which == 0 else 1.0) * period
		var toe_off: float = land + stance
		# trajet du pied, en mètres devant la hanche, aux instants clés
		var path: Array = [[land, Vector3(side * width, 0.0, - reach / leg), strike],
			[toe_off, Vector3(side * width, lift, - off / leg), push],
			[toe_off + swing * 0.22, Vector3(side * width, kick * 0.7, - (off - 0.05) / leg), push - 0.35],
			[toe_off + swing * 0.48, Vector3(side * width * 0.6, kick, - ((off + reach) * 0.5 - 0.04) / leg), push * 0.9],
			[toe_off + swing * 0.76, Vector3(side * width, knee, - (reach + 0.08) / leg), 0.12],
			[land + 2.0 * period, Vector3(side * width, 0.0, - reach / leg), strike]]
		for k: int in range(path.size() - 1):
			var a: Array = path[k]
			var b: Array = path[k + 1]
			if float(b[0]) <= start: continue
			if float(a[0]) <= start:
				var u: float = clampf((start - float(a[0])) / maxf(0.001, float(b[0]) - float(a[0])), 0.0, 1.0)
				keys.append([start, {foot: (a[1] as Vector3).lerp(b[1], u), pitch: lerpf(float(a[2]), float(b[2]), u)}, "l" if k == 0 else ""])
			# l'appui du pied B (k == 0) recule à vitesse constante ; le poser de A
			# (dernier point) est écrit par _strides
			if k + 1 < path.size() - 1 and not (which == 0 and k + 1 == path.size() - 1):
				keys.append([float(b[0]), {foot: b[1], pitch: b[2]}])
		# le pied B se repose à first + period : _strides l'écrit (i = 1)


# Poussées de patineur (rollers). Chaque poussée dure `period` s ; le pied qui
# pousse part en diagonale, dehors et derrière, roue au sol, puis se relève et
# revient sous la hanche pendant que l'autre glisse. Sur des roulettes le pied
# d'appui roule avec le corps : il reste sous la hanche, il ne « glisse » pas.
# Le bassin passe au-dessus du pied qui glisse, le buste roule à l'opposé et
# les bras balancent en travers. opts : push (écart du pied qui pousse, en
# longueurs de jambe), back (recul), depth (descente du bassin), lean (buste),
# arms (amplitude du balancier), lift (hauteur du pied qui revient), vary
# (variation d'une poussée à l'autre : jamais deux poussées identiques).
static func _skate(keys: Array, first: float, count: int, period: float, right_first: bool = true, opts: Dictionary = {}) -> void :
	var push: float = float(opts.get("push", 0.42))
	var back: float = float(opts.get("back", 0.3))
	var depth: float = float(opts.get("depth", 0.3))
	var lean: float = float(opts.get("lean", 0.55))
	var arms: float = float(opts.get("arms", 1.0))
	var lift: float = float(opts.get("lift", 0.12))
	var vary: float = float(opts.get("vary", 0.12))
	for i: int in range(count):
		var t: float = first + period * float(i)
		var right: bool = (i % 2 == 0) == right_first
		var side: float = 1.0 if right else -1.0
		# chaque poussée est un peu différente (ampleur, rythme du bras)
		var k: float = 1.0 + vary * sin(1.7 * float(i) + 0.6)
		var pusher: String = "foot_r" if right else "foot_l"
		var glider: String = "foot_l" if right else "foot_r"
		var p_pitch: String = "fp_r" if right else "fp_l"
		var g_pitch: String = "fp_l" if right else "fp_r"
		# 0 · le pied qui va pousser se pose sous la hanche, l'autre glisse
		keys.append([t, {pusher: Vector3(side * 0.07, 0.0, -0.06), p_pitch: 0.0, glider: Vector3(side * 0.05, 0.0, 0.02),
			"hips": Vector3(side * 0.03, - depth * 0.92, - 0.05), "body": Vector3(- lean, 0.0, side * 0.03)}])
		# 0,55 · pleine poussée : jambe tendue en diagonale, bassin sur le pied qui glisse
		keys.append([t + period * 0.55, {pusher: Vector3(side * push * k, 0.0, back * k), p_pitch: -0.15, glider: Vector3(side * 0.06, 0.0, -0.04), g_pitch: 0.0,
			"hips": Vector3(- side * 0.07, - depth, - 0.02), "body": Vector3(- lean - 0.04, side * 0.1, - side * 0.07), "chest": Vector3(- 0.08, - side * 0.12, side * 0.04),
			"ik_r" if right else "ik_l": Vector3(side * 0.42 * arms, -0.25, 0.42 * arms), "ik_l" if right else "ik_r": Vector3(side * 0.22 * arms, -0.05, -0.62 * arms)}])
		# 0,8 · le pied quitte le sol et revient en arc sous la hanche
		keys.append([t + period * 0.8, {pusher: Vector3(side * push * 0.6, lift, back * 0.7), p_pitch: -0.35}])
		if i == count - 1: continue
		# il revient sous la hanche et se repose au début de la poussée suivante
		keys.append([t + period * 0.93, {pusher: Vector3(side * 0.14, lift * 0.45, 0.06), p_pitch: -0.1}])


# ------------------------------------------------------------------ USAYUKO --
# Force. Alice abat sa griffe : Usayuko la bloque de l'avant-bras gauche (3,62),
# plie sous le poids, lève les yeux vers elle et sourit ; il la repousse d'un
# balayage (4,98). Elle revient à la charge : il arme le poing gauche loin
# derrière la hanche, avance d'une grande fente et le lui enfonce dans le ventre
# (5,75). Elle traverse la cour (5,87 → 6,69). Il souffle sur ses phalanges qui
# fument, secoue la main, s'essuie le nez du pouce, poings sur les hanches.
# Toute l'action est du côté gauche d'Usayuko, celui des caméras.

const U_HIT: float = 5.75

static func _u_guard() -> Dictionary:
	return M([FL(0.06, 0.24), FR(0.15, -0.24), H(0, -0.16, 0.0), B(0.1, -0.25), C(0.06, -0.12), HD(0.0, 0.37),
		Lt(-0.25, 0.22, 0.55, 0.3), Rt(-0.18, 0.05, 0.42, 0.4), WL(0.0, 0.8), WR(0.0, -0.8), {"curl": 1.0, "curl_l": 1.0}])


static func _usayuko(c: Dictionary) -> void :
	var k: Array = []
	# 3,3 · le flash le surprend en pleine garde : l'avant-bras gauche monte
	k.append(K(3.3, M([_zero(), _u_guard(), FACE("determined")])))
	k.append(K(3.42, M([H(0, -0.2, -0.02), Lt(-0.12, 0.38, 0.62, 0.8), WL(0.0, 1.1), HD(0.12, 0.35), C(0.04, -0.15)])))
	# 3,62 · CLANG : la griffe tombe sur l'avant-bras, les genoux encaissent
	k.append(K(3.58, M([H(0, -0.18, 0.0), B(0.1, -0.22), L(-0.06, 0.44, 0.72, 0.95), WL(0.1, 1.2), {"sq": 1.0}])))
	k.append(K(3.62, M([H(0, -0.34, -0.06), B(0.2, -0.18), C(0.1, -0.08), HD(0.12, 0.32, 0.05), L(-0.04, 0.32, 0.7, 0.95),
		Rt(-0.05, -0.3, 0.2, 0.4), SH(0.25, 0.1), {"sq": 0.93, "shake": 0.8, "ev": "effort", "face": "angry"}]), "s"))
	k.append(K(3.74, M([H(0, -0.3, -0.04), {"sq": 1.0, "shake": 0.5}])))
	# il plie sous la poussée, lève les yeux vers elle, serre les dents… et sourit
	k.append(K(4.05, M([H(0, -0.4, -0.06), B(0.2, -0.2), C(0.04, -0.06), HD(0.5, 0.26, 0.1), L(-0.04, 0.02, 0.64, 0.95), SH(0.32, 0.14), {"shake": 0.7}])))
	k.append(K(4.22, FACE("grin")))
	k.append(K(4.4, M([H(0, -0.37, -0.02), HD(0.55, 0.28, -0.06), L(-0.05, 0.05, 0.66, 0.95), {"shake": 0.45}])))
	k.append(K(4.62, M([H(0, -0.37, -0.04), B(0.18, -0.35), C(0.1, -0.25), HD(0.35, 0.5), L(-0.05, 0.14, 0.66, 0.95), Rt(0.15, -0.35, -0.05, 0.4), {"shake": 0.6, "face": "angry"}]), "s"))
	# 4,98 · VLAN : il tape du pied gauche et balaie la griffe vers l'extérieur ;
	# le buste tourne à gauche, ce qui charge déjà le poing gauche
	k.append(K(4.8, M([FL(0.06, 0.24), H(0, -0.38, -0.06), B(0.2, -0.45), C(0.12, -0.3), L(0.0, 0.25, 0.65, 0.9), {"shake": 0.9}])))
	k.append(K(4.9, M([FL(0.06, 0.28, 0.07), {"fp_l": 0.15}])))
	k.append(K(4.98, M([FL(0.06, 0.36), H(0, -0.24, 0.12), B(0.04, 0.35), C(-0.04, 0.3), HD(0.08, -0.2), L(0.75, 0.55, 0.3, 1.0), WL(-0.3, 0.6),
		Rt(0.1, -0.2, 0.1, 0.4), SH(0.05, 0.0), {"fp_l": 0.0, "sq": 1.06, "shake": 0.0, "ev": "grunt", "fx": "trail_l whoosh"}]), "s"))
	# 5,07 → 5,6 · armé : le poing gauche part loin derrière la hanche, le buste
	# vrille, le poids passe sur la jambe arrière ; la main droite ouverte vise
	k.append(K(5.12, M([H(0, -0.24, 0.02), B(0.08, 0.5), C(0.02, 0.38), HD(0.04, -0.62), L(0.5, -0.1, 0.1, 0.5), WL(0.0, 0.6), {"sq": 1.0}])))
	k.append(K(5.3, M([H(0, -0.32, -0.16), B(0.16, 0.8), C(0.12, 0.5), HD(0.02, -1.05), L(0.22, -0.42, -0.42, 0.25), WL(-0.4, 0.4),
		Rt(-0.18, 0.1, 0.6, 0.35), WR(0.0, -0.3), SH(0.1, 0.0, -0.3, 0.0), {"fp_l": -0.15, "curl": 0.35, "curl_l": 1.0, "shake": 0.25, "face": "determined"}])))
	k.append(K(5.52, M([FL(0.06, 0.44, 0.12), H(0, -0.33, -0.18), B(0.18, 0.88), C(0.14, 0.54), HD(0.0, -1.12), L(0.24, -0.45, -0.46, 0.25), {"shake": 0.6, "fp_l": 0.3}])))
	# la fente : le pied gauche se pose loin devant, la hanche part, le poing suit
	k.append(K(5.64, M([FL(0.03, 0.74), H(0, -0.32, 0.26), B(0.24, 0.3), C(0.1, 0.2), HD(-0.06, -0.5), L(0.3, -0.12, 0.0, 0.5), {"fp_l": 0.0, "fp_r": -0.3, "shake": 0.2}])))
	# 5,75 · PAF : bras tendu dans le ventre d'Alice, épaule devant, talon arrière levé
	var punch: Dictionary = M([FL(0.03, 0.74), FR(0.15, -0.24), H(0, -0.34, 0.52), B(0.36, -0.62), C(0.16, -0.6), HD(-0.1, 0.95, -0.05),
		L(-0.1, -0.16, 1.0, 0.0), WL(0.0, 0.0), Rt(0.12, -0.25, 0.1, 0.5), SH(0.05, 0.0, 0.3, 0.0),
		{"fp_l": 0.0, "fp_r": -0.75, "sq": 1.06, "shake": 0.0, "curl": 1.0, "curl_l": 1.0, "face": "angry", "jaw": 0.5}])
	k.append(K(U_HIT, M([punch, {"ev": "grunt", "fx": "pop_l"}]), "h"))
	k.append(K(U_HIT + 0.1, M([punch, {"sq": 1.0}])))
	# rattrapage : le bras finit sa course, le buste continue de tourner puis revient ;
	# le pied arrière rejoint la garde (6,5 → 6,7)
	k.append(K(U_HIT + 0.3, M([H(0, -0.32, 0.55), B(0.4, -0.72), C(0.18, -0.66), HD(-0.08, 1.0, -0.05), L(-0.18, -0.18, 1.0, 0.0), {"jaw": 0.2}])))
	k.append(K(6.4, M([FR(0.15, -0.24), H(0, -0.24, 0.32), B(0.2, -0.35), C(0.1, -0.3), HD(0.0, 0.55), Lt(0.1, -0.1, 0.55, 0.3), WL(0.2, 0.4), {"fp_r": -0.2, "face": "determined", "jaw": 0.0}]), "s"))
	k.append(K(6.55, M([FR(0.15, 0.05, 0.1), H(0, -0.2, 0.36), {"fp_r": 0.2}])))
	k.append(K(6.7, M([FR(0.16, 0.2), H(0, -0.16, 0.42), B(0.08, -0.15), C(0.04, -0.1), HD(0.08, 0.25), {"fp_r": 0.0}])))
	# 7,05 · VAPEUR : le poing gauche fume ; il le porte à sa bouche et souffle
	# dessus (7,1), secoue la main brûlante (7,33), sourit (7,56)
	k.append(K(7.0, M([Lt(-0.2, 0.18, 0.42, 0.6), WL(0.5, 0.9), HD(0.16, 0.12), {"face": "calm"}])))
	k.append(K(7.1, M([Lt(-0.26, 0.32, 0.36, 0.7), WL(0.7, 1.2), HD(0.06, 0.05), C(0.06, -0.05), {"jaw": 0.35}]), "s"))
	k.append(K(7.28, M([Lt(0.25, 0.05, 0.4, 0.5), WL(-0.6, -0.4), HD(0.16, -0.1), {"jaw": 0.0, "curl_l": 0.15, "face": "surprise"}])))
	k.append(K(7.33, M([Lt(0.32, -0.05, 0.38, 0.5), WL(0.7, 0.4)])))
	k.append(K(7.38, M([Lt(0.28, 0.06, 0.4, 0.5), WL(-0.7, -0.4)])))
	k.append(K(7.43, M([Lt(0.33, -0.04, 0.38, 0.5), WL(0.6, 0.3)])))
	k.append(K(7.5, M([Lt(0.3, 0.02, 0.4, 0.5), WL(-0.3, -0.2)])))
	k.append(K(7.56, M([Lt(0.35, -0.3, 0.25, 0.4), WL(0.0, 0.0), HD(0.2, 0.15, -0.08), {"curl_l": 0.4, "face": "grin"}]), "s"))
	blink(7.66, "grin", k)
	# 7,85 · HÉROS : le pied gauche revient, il fait rouler l'épaule (8,12),
	# s'essuie le nez du pouce droit (8,4), se campe poings sur les hanches (8,67)
	k.append(K(7.85, M([FL(0.03, 0.74), H(0, -0.12, 0.4), B(0.04, 0.0), C(0.02, 0.0), HD(0.1, 0.0, -0.08), Lt(0.2, -0.62, 0.15, 0.2), {"curl_l": 0.7}])))
	k.append(K(7.98, M([FL(0.06, 0.55, 0.1), H(0, -0.1, 0.32), {"fp_l": 0.25}])))
	k.append(K(8.1, M([FL(0.12, 0.34), H(0, -0.08, 0.26), {"fp_l": 0.0}])))
	k.append(K(8.05, M([SH(0.0, 0.35, 0.0, 0.25), Rt(0.3, -0.45, 0.2, 0.4), HD(0.14, 0.25, 0.15)])))
	k.append(K(8.2, M([SH(0.0, -0.05, 0.0, -0.2), Rt(0.35, -0.55, 0.05, 0.4), HD(0.06, 0.1, -0.05)])))
	k.append(K(8.3, M([SH(0.0, 0.0), Rt(-0.18, 0.38, 0.3, 0.6), WR(0.9, -1.4), {"curl": 0.85}])))
	k.append(K(8.4, M([Rt(-0.3, 0.42, 0.28, 0.6), WR(1.0, -1.6), HD(0.16, -0.05, 0.05), {"gesture": "thumbsup"}]), "s"))
	k.append(K(8.48, M([Rt(-0.05, 0.44, 0.3, 0.6), WR(1.0, -1.3), HD(0.2, 0.05, 0.0)])))
	k.append(K(8.56, {"gesture": ""}))
	var hands_on_hips: Dictionary = M([L(0.62, -0.6, 0.02, 0.9), R(0.62, -0.6, 0.02, 0.9), WL(0.6, 0.0, 0.3), WR(0.6, 0.0, -0.3), {"curl": 1.0, "curl_l": 1.0}])
	k.append(K(8.67, M([H(0, -0.04, 0.22), B(-0.05, 0.0), C(-0.08, 0.0), HD(0.24, 0.05, -0.06), hands_on_hips, SH(0.12, 0.12), {"sq": 1.02}]), "s"))
	k.append(K(8.95, M([HD(0.26, 0.05, -0.08), {"sq": 1.0}])))
	c["fv_usayuko_rain"] = _film(3.3, 9.2, k, "determined")

	# PAPIER · le coup de poing en silhouette de profil : le bras finit sa course
	# au ralenti
	var ink: Array = []
	ink.append(K(0.0, M([_zero(), punch, {"face": "angry", "jaw": 0.4}])))
	ink.append(K(0.5, M([H(0, -0.33, 0.55), B(0.38, -0.68), C(0.17, -0.64), L(-0.14, -0.17, 1.0, 0.0), {"jaw": 0.3}])))
	ink.append(K(2.6, M([H(0, -0.31, 0.6), B(0.42, -0.78), C(0.2, -0.7), HD(-0.08, 1.0, -0.05), L(-0.2, -0.18, 1.0, 0.0), Rt(0.18, -0.3, 0.0, 0.5), {"fp_r": -0.85}])))
	c["fv_usayuko_ink"] = _film(0.0, 2.7, ink, "angry")

	_usayuko_alice(c)


static func _usayuko_alice(c: Dictionary) -> void :
	var k: Array = []
	# 3,3 · elle fond sur lui, griffe droite armée haut derrière la tête
	k.append(K(3.3, M([_zero(), FL(0.06, 0.3, 0.06), FR(0.1, -0.3), H(0, -0.06, -0.1), B(-0.12, -0.35), C(-0.1, -0.3), HD(0.1, 0.55, 0.08),
		R(0.35, 0.95, -0.2, 0.8), WR(-0.7), L(0.3, -0.25, 0.55, 0.3), WL(0.2), {"curl": 0.15, "curl_l": 0.4, "face": "angry", "jaw": 0.6}])))
	k.append(K(3.48, M([FL(0.06, 0.42, 0.08), H(0, -0.04, -0.12), B(-0.16, -0.42), C(-0.14, -0.36), R(0.3, 1.0, -0.3, 0.8), WR(-0.9), {"jaw": 0.8}]), "s"))
	# 3,62 · la griffe s'abat sur l'avant-bras d'Usayuko, le pied gauche se pose
	k.append(K(3.58, M([FL(0.06, 0.55), H(0, -0.12, 0.25), B(0.3, 0.3), C(0.2, 0.3), HD(-0.1, -0.3), R(0.0, 0.42, 0.8, 0.3), WR(0.4), L(0.4, -0.35, 0.15, 0.3), {"jaw": 0.3}])))
	k.append(K(3.62, M([H(0, -0.16, 0.3), B(0.36, 0.34), C(0.24, 0.32), HD(-0.18, -0.32, 0.06), R(0.02, 0.3, 0.74, 0.35), WR(0.6), {"sq": 0.96, "shake": 0.6, "fx": "spark_r"}]), "s"))
	k.append(K(3.72, M([R(0.02, 0.33, 0.74, 0.35), {"sq": 1.0, "shake": 0.3}])))
	# elle pèse de tout son poids, l'autre main vient appuyer
	k.append(K(3.95, M([H(0, -0.26, 0.38), B(0.46, 0.22), C(0.38, 0.18), HD(-0.02, -0.2), R(0.02, -0.1, 0.74, 0.35), L(0.05, -0.12, 0.72, 0.45), WL(0.5), {"curl_l": 0.2, "shake": 0.45, "jaw": 0.5}])))
	k.append(K(4.4, M([H(0, -0.25, 0.37), B(0.44, 0.2), HD(0.04, -0.18, -0.06), R(0.02, -0.07, 0.74, 0.35), L(0.05, -0.1, 0.72, 0.45), {"shake": 0.55, "fx": "spark_r", "face": "menace"}])))
	k.append(K(4.75, M([H(0, -0.24, 0.36), B(0.44, 0.2), R(0.02, 0.0, 0.73, 0.35), L(0.05, -0.02, 0.72, 0.45), {"shake": 0.7, "face": "angry"}])))
	k.append(K(4.9, M([FL(0.06, 0.55), FR(0.1, -0.3), H(0, -0.16, 0.32), B(0.38, 0.18), R(0.04, 0.34, 0.74, 0.35), L(0.07, 0.3, 0.72, 0.45)])))
	# 4,98 · repoussée : bras projetés en l'air, elle recule en titubant (pied
	# gauche, puis droit)
	k.append(K(4.98, M([H(0, -0.08, 0.1), B(-0.2, 0.55), C(-0.22, 0.45), HD(0.35, -0.5, -0.2), R(0.85, 0.6, 0.0, 0.8), WR(-0.6), L(0.6, 0.45, 0.2, 0.7),
		{"sq": 1.05, "shake": 0.0, "jaw": 0.7, "face": "surprise", "ev": "gasp"}]), "s"))
	k.append(K(5.08, M([FL(0.06, 0.25, 0.2), H(0, -0.05, -0.12), B(-0.32, 0.4), C(-0.25, 0.35), HD(0.4, -0.35, -0.25), R(0.95, 0.3, -0.25, 0.8), L(0.9, 0.55, -0.1, 0.8), {"sq": 1.0}])))
	k.append(K(5.17, M([FL(0.06, -0.22), FR(0.1, -0.3), H(0, -0.12, -0.22), B(-0.2, 0.3), HD(0.25, -0.2, -0.15)])))
	k.append(K(5.22, M([FR(0.1, -0.42, 0.15)])))
	k.append(K(5.3, M([FR(0.1, -0.58), H(0, -0.24, -0.32), B(-0.05, 0.15), C(-0.05, 0.1), HD(0.05, -0.1, -0.05), R(0.7, -0.1, 0.1, 0.6), L(0.65, -0.05, 0.15, 0.6), {"face": "angry"}]), "s"))
	# 5,3 → 5,75 · elle se reprend, gronde et revient à la charge, griffes en avant
	k.append(K(5.42, M([FL(0.06, -0.22), H(0, -0.32, -0.25), B(0.35, 0.0), C(0.3, 0.0), HD(-0.3, 0.0), R(0.4, 0.15, 0.1, 0.6), L(0.4, 0.15, 0.1, 0.6), WR(-0.5), WL(-0.5), {"jaw": 0.9, "ev": "roar", "curl": 0.1, "curl_l": 0.1}]), "s"))
	k.append(K(5.56, M([FL(0.06, 0.1, 0.16), {"fp_r": -0.4}])))
	k.append(K(5.68, M([FL(0.06, 0.4), H(0, -0.12, 0.2), B(0.48, 0.0), C(0.24, 0.0), HD(-0.18, 0.0), R(0.25, 0.28, 0.8, 0.4), L(0.25, 0.28, 0.8, 0.4), {"fp_r": -0.6}])))
	# 5,75 · le poing s'enfonce dans son ventre : elle se plie en deux autour,
	# tête, bras et jambes fouettés vers l'avant ; arrêt sur image
	var struck: Dictionary = M([{"plant": 0.0}, H(0, 0.06, -0.42), B(-0.2, -0.05), C(1.05, -0.05), HD(-0.25, -0.1, -0.05),
		TL(0.75, 0.12), KL(0.55, 0.3), TR(0.5, 0.14), KR(0.8, 0.3), Rt(0.3, -0.35, 0.75, 0.5), Lt(0.25, -0.4, 0.8, 0.5), WR(-0.4), WL(-0.4),
		{"sq": 0.9, "jaw": 1.0, "face": "pain", "curl": 0.0, "curl_l": 0.0, "fp_r": 0.0}])
	k.append(K(U_HIT, M([struck, {"ev": "hurt"}]), "h"))
	k.append(K(U_HIT + 0.1, struck))
	# envol (5,87 → 6,69) : pliée, elle part en arrière, membres traînant vers lui,
	# puis le haut du corps bascule et elle retombe sur le dos
	k.append(K(6.05, M([H(0, 0.05, -0.45), B(-0.3, -0.1), C(1.15, -0.1), HD(-0.1, -0.2, -0.1), TL(0.9, 0.15), KL(0.4), TR(0.75, 0.2), KR(0.6), Rt(0.45, -0.2, 0.85, 0.6), Lt(0.4, -0.3, 0.9, 0.6), {"sq": 1.04}])))
	k.append(K(6.35, M([H(0, 0.0, -0.2), B(0.1, 0.15), C(-0.05), HD(0.35, -0.3, -0.2), TL(1.1, 0.2), KL(0.7), TR(0.75, 0.25), KR(1.0), R(0.85, 0.6, 0.2, 0.9), L(0.9, 0.5, 0.4, 0.9), {"sq": 1.0, "jaw": 0.7}])))
	k.append(K(6.6, M([{"gsnap": 0.3}, H(0, 0.0, -0.3), {"body": V(1.05, -0.1, -0.05)}, C(-0.1), HD(-0.2, -0.4, -0.1), TL(1.35, 0.2), KL(0.4), TR(1.1, 0.25), KR(0.5), R(0.9, 0.75, -0.1, 0.9), L(0.9, 0.7, 0.0, 0.9)])))
	# 6,69 · elle s'écrase sur le dos, les jambes rebondissent et retombent
	var down: Dictionary = M([{"plant": 0.0, "gsnap": 1.0}, H(0, 0.0, -0.45), {"body": V(1.5, -0.12, 0.0), "chest": V(-0.12, -0.12, -0.06), "head": V(-0.35, -0.75, -0.1)},
		TL(0.25, 0.12, 0.15), KL(0.35), TR(0.45, 0.15, -0.2), KR(0.7), {"l_arm": V(1.2, 0.0, -0.5), "r_arm": V(1.2, 0.0, 0.5)}, Lg(0.9, 0.1), Rg(0.95, -0.25),
		{"el_l": 0.7, "el_r": 0.6, "face": "dazed", "jaw": 0.35, "sq": 1.0, "curl": 0.35, "curl_l": 0.25}])
	k.append(K(6.69, M([down, TL(0.85, 0.12, 0.15), KL(0.3), TR(1.0, 0.15, -0.2), KR(0.4), {"sq": 0.9, "ev": "hurt"}]), "s"))
	k.append(K(6.82, M([TL(1.05, 0.12, 0.15), KL(0.5), TR(1.25, 0.15, -0.2), KR(0.6), HD(-0.2, -0.8, -0.1), {"sq": 1.03}])))
	k.append(K(7.05, M([down])))
	# elle bouge encore : une main se crispe sur le sol (7,6), la tête retombe (8,3)
	k.append(K(7.5, M([Lg(0.9, 0.1)])))
	k.append(K(7.62, M([Lg(0.8, 0.25, 0.06), {"curl_l": 0.85}])))
	k.append(K(7.8, M([Lg(0.85, 0.15), {"curl_l": 0.3}])))
	k.append(K(8.2, M([{"head": V(-0.15, -0.65, -0.05)}])))
	k.append(K(8.32, M([{"head": V(-0.38, -0.8, -0.12)}, {"face": "dead"}])))
	c["fv_usayuko_alice_rain"] = _film(3.3, 9.2, k, "angry")

	# PAPIER · pliée autour du poing, elle part en arrière au ralenti
	var ink: Array = []
	ink.append(K(0.0, M([_zero(), struck, {"face": "pain"}])))
	ink.append(K(2.6, M([H(0, 0.06, -0.5), B(-0.35, -0.12), C(1.2, -0.1), HD(-0.15, -0.25, -0.15), TL(1.0, 0.15), KL(0.45), TR(0.8, 0.2), KR(0.65), Rt(0.45, -0.25, 0.9, 0.6), Lt(0.4, -0.35, 0.95, 0.6), {"sq": 1.0}])))
	c["fv_usayuko_alice_ink"] = _film(0.0, 2.7, ink, "pain")



# -------------------------------------------------------------------- SIMON --
# Vitesse. Coincé devant Alice, Simon sautille sur place sur les croches,
# secoue les mains, cherche une sortie du regard (3,3) ; ses yeux se fixent sur
# elle (4,05). Il se met en position de départ (4,6), hanches en l'air (5,05).
# Alice fonce sur lui et tranche… une image rémanente : il est déjà passé
# (5,32), le souffle la fait tourner sur elle-même. Il dérape loin derrière, se
# retourne et agite le doigt, « non non non » (6,9 → 7,16). Tornade autour
# d'elle (7,3 → 8,15) : elle tombe sur les fesses. Il file dans la nuit, buste
# couché, bras en arrière (8,3).
# Les trajets (film_victories.gd) suivent les mêmes instants et vitesses.

const S_GO: float = 5.32
const S_SKID: float = 5.5
const S_STOP: float = 6.25
const S_TORNADO: float = 7.3
const S_EXIT: float = 8.15
const S_RUN: float = 8.3
const S_RUN_SPEED: float = 8.0
const S_RUN_STEP: float = 0.15

# buste couché, bras tendus en arrière : la course « Sonic »
static func _s_sonic() -> Dictionary:
	return M([B(0.95, 0.0), C(0.36, 0.0), HD(1.22, 0.0), L(0.24, -0.02, -0.92, 0.0), R(0.24, -0.02, -0.92, 0.0), WL(0.35), WR(0.35),
		SH(-0.1, -0.1, -0.2, -0.2), {"curl": 0.15, "curl_l": 0.15}])


static func _simon(c: Dictionary) -> void :
	var k: Array = []
	var stand: Dictionary = M([FL(0.04, 0.06, 0.04), FR(0.06, -0.06, 0.04), H(0, -0.06, 0.0), B(0.06), C(0.05), HD(-0.03),
		L(0.28, -0.7, 0.18, 0.2), R(0.28, -0.7, 0.18, 0.2), {"fp_l": -0.25, "fp_r": -0.25, "curl": 0.25, "curl_l": 0.25}])
	# A · 3,3 → 3,95 · il sautille sur les croches, secoue les mains, cherche une sortie
	k.append(K(3.3, M([_zero(), stand, FACE("fear")])))
	var beat: float = 0.1625
	for i: int in range(4):
		var t: float = 3.3 + beat * float(i)
		k.append(K(t + 0.04, M([H(0.01 * float(1 - 2 * (i % 2)), -0.13, 0.02), {"sq": 0.97}])))
		k.append(K(t + 0.11, M([H(-0.01 * float(1 - 2 * (i % 2)), -0.03, 0.0), {"sq": 1.02}])))
	for i: int in range(8):
		var t: float = 3.32 + 0.08 * float(i)
		var flap: float = 0.55 if i % 2 == 0 else -0.45
		k.append(K(t, M([WL(flap, 0.2 * flap), WR(- flap, -0.2 * flap)])))
	k.append(K(3.36, M([HD(-0.02, 0.0)])))
	k.append(K(3.44, M([HD(0.02, 0.55, 0.05)]), "s"))
	k.append(K(3.58, M([HD(0.0, 0.5, 0.04)])))
	k.append(K(3.64, M([HD(0.02, -0.5, -0.05)]), "s"))
	blink(3.6, "fear", k, 0.06)
	k.append(K(3.78, M([HD(0.0, -0.45, -0.04)])))
	# B · 3,95 · il ne bouge plus : le regard se plante dans le sien, l'ombre d'un sourire
	k.append(K(3.9, M([H(0, -0.08, 0.0), HD(-0.05, 0.0, 0.0), WL(0.0), WR(0.0), {"sq": 1.0}]), "s"))
	k.append(K(3.95, M([H(0, -0.09, 0.0), B(0.1), C(0.07), HD(-0.14, 0.0, 0.03), L(0.3, -0.68, 0.15, 0.25), R(0.3, -0.68, 0.15, 0.25), {"curl": 0.85, "curl_l": 0.85, "face": "determined", "fp_l": -0.15, "fp_r": -0.15}]), "s"))
	k.append(K(4.3, M([HD(-0.16, 0.02, 0.06), {"face": "grin"}])))
	k.append(K(4.52, M([HD(-0.17, 0.0, 0.05)])))
	# C · 4,6 · « à vos marques » : il plonge, mains au sol, genou arrière bas
	k.append(K(4.74, M([FR(0.07, -0.2, 0.08)])))
	k.append(K(4.66, M([FL(0.04, 0.28, 0.08), H(0, -0.3, 0.12), B(0.6), C(0.3), HD(0.55), Lt(-0.05, -0.5, 0.6, 0.3), Rt(-0.05, -0.5, 0.6, 0.3), {"fp_l": 0.0, "fp_r": 0.0, "face": "determined"}])))
	var marks: Dictionary = M([FL(0.04, 0.44), FR(0.07, -0.32), H(0, -0.56, 0.2), B(1.05), C(0.32), HD(1.0), Lg(0.18, 0.22, 0.02), Rg(0.18, 0.22, 0.02),
		{"fp_l": 0.0, "fp_r": -0.5, "el_l": 0.2, "el_r": 0.2, "curl": 0.1, "curl_l": 0.1}])
	k.append(K(4.82, marks, "s"))
	k.append(K(4.95, M([H(0, -0.55, 0.21), {"shake": 0.2}])))
	# « prêts » : les hanches montent au-dessus des épaules, tout se tend
	k.append(K(5.08, M([FR(0.07, -0.32, 0.04), H(0, -0.36, 0.26), B(1.12), C(0.28), HD(1.05), {"fp_r": -0.75, "shake": 0.35}]), "s"))
	k.append(K(5.28, M([H(0, -0.35, 0.28), {"shake": 0.55}])))
	# D · 5,32 · parti : course éclair, buste couché, bras en arrière
	k.append(K(S_GO, M([_s_sonic(), H(0, -0.2, 0.35), {"shake": 0.0, "face": "grin", "fp_r": 0.0}])))
	_strides("Simon", k, S_GO + 0.03, 3, 0.05, 21.0, false, {"stance": 0.028, "reach": 0.38, "kick": 0.55, "knee": 0.38, "hips": Vector3(0.0, -0.2, 0.35), "bob": 0.04})
	# E · 5,5 → 6,25 · dérapage : il se met de travers, glisse sur l'eau, la main
	# gauche frôle le sol ; son regard ne la quitte pas
	var skid: Dictionary = M([FL(0.12, 0.02), FR(0.5, -0.02), H(0, -0.44, -0.05), B(0.12, 0.0, 0.42), C(0.12, 0.0, 0.15), HD(0.05, 0.85, -0.2),
		Lg(0.95, 0.15, 0.04), R(0.55, 0.35, 0.25, 0.7), {"fp_l": 0.0, "fp_r": 0.2, "curl": 0.3, "curl_l": 0.2, "face": "determined"}])
	k.append(K(S_SKID - 0.04, M([FL(0.08, 0.1, 0.1), FR(0.3, 0.0, 0.08), H(0, -0.3, 0.1), B(0.25, 0.0, 0.25), C(0.3), HD(0.6, 0.5), L(0.6, -0.2, -0.3, 0.4), R(0.5, 0.2, 0.0, 0.5)])))
	k.append(K(S_SKID + 0.06, M([skid, {"sq": 0.95, "fx": "skid"}]), "s"))
	k.append(K(5.85, M([H(0, -0.46, -0.06), B(0.14, 0.0, 0.45), Lg(0.95, 0.2, 0.0), {"sq": 1.0, "fx": "skid"}])))
	k.append(K(S_STOP, M([FL(0.12, 0.02), FR(0.48, -0.02), H(0, -0.4, -0.04), B(0.1, 0.0, 0.36), HD(0.0, 0.9, -0.15)]), "s"))
	# 6,25 → 6,45 · il se redresse et pivote vers elle
	k.append(K(6.36, M([FR(0.32, 0.06, 0.1), H(0, -0.18, 0.0), B(0.08, 0.0, 0.1), C(0.05), HD(-0.02, 0.4), L(0.35, -0.6, 0.1, 0.3), R(0.35, -0.6, 0.1, 0.3), {"fp_r": 0.0}])))
	k.append(K(6.46, M([FR(0.12, -0.08), FL(0.06, 0.08), H(0, -0.08, 0.0), B(0.04), HD(-0.05, 0.0), {"sq": 1.0}]), "s"))
	# F · le sourire, puis le doigt qui fait « non non non » sur les caisses claires
	k.append(K(6.58, M([H(0, -0.05, 0.0), B(-0.02, 0.1, -0.05), C(-0.04, 0.08), HD(0.06, -0.08, -0.12), L(0.62, -0.58, 0.02, 0.9), WL(0.6, 0.0, 0.3), {"curl_l": 1.0, "face": "grin"}])))
	k.append(K(6.78, M([Rt(0.02, 0.05, 0.62, 0.3), WR(-0.2, -0.3, 0.0), {"gesture": "point", "curl": 0.9}])))
	for i: int in range(4):
		var t: float = 6.9 + 0.088 * float(i)
		var wag: float = 1.0 if i % 2 == 0 else -1.0
		k.append(K(t, M([Rt(0.02 + 0.06 * wag, 0.06, 0.62, 0.3), WR(-0.2, -0.3, 0.5 * wag), HD(0.06, -0.1 * wag - 0.04, -0.12)])))
	k.append(K(7.16, M([H(0, -0.05, 0.0), B(-0.02, 0.1, -0.05), C(-0.04, 0.08), HD(0.06, -0.02, -0.12), L(0.62, -0.58, 0.02, 0.9), FL(0.06, 0.08), FR(0.12, -0.08), {"fp_r": 0.0}]), "s"))
	k.append(K(7.22, M([Rt(0.1, -0.1, 0.4, 0.4), WR(0.0), {"gesture": ""}])))
	blink(6.66, "grin", k, 0.07)
	# 7,22 · il se ramasse pour repartir
	k.append(K(7.26, M([FL(0.06, 0.18), FR(0.1, -0.2), H(0, -0.3, 0.12), B(0.5), C(0.3), HD(0.6), L(0.3, -0.4, -0.3, 0.3), R(0.3, -0.4, -0.3, 0.3), {"curl": 0.4, "curl_l": 0.4, "fp_r": -0.4}]), "s"))
	# G · tornade (7,3 → 8,15) : course éclair penchée vers l'intérieur du cercle
	k.append(K(S_TORNADO, M([_s_sonic(), B(0.4, 0.0, 0.35), C(0.5, 0.0, 0.2), HD(0.85, 0.3, -0.25), H(0, -0.22, 0.3), {"fp_r": 0.0, "face": "grin"}])))
	_strides("Simon", k, S_TORNADO + 0.02, 18, 0.05, 20.0, true, {"stance": 0.026, "reach": 0.36, "kick": 0.55, "knee": 0.38, "hips": Vector3(0.05, -0.22, 0.3), "bob": 0.04})
	# H · 8,3 · la vraie foulée, au mètre : 8 m/s, appuis de 0,08 s
	k.append(K(S_EXIT + 0.06, M([_s_sonic(), H(0, -0.12, 0.3)])))
	var run: Dictionary = {"stance": 0.08, "reach": 0.32, "kick": 0.6, "knee": 0.4, "hips": Vector3(0.0, -0.12, 0.3), "bob": 0.07, "up": 0.02, "push": -0.65}
	_strides("Simon", k, S_RUN, 8, S_RUN_STEP, S_RUN_SPEED, true, run)
	# le buste roule avec les foulées, la tête reste stable
	for i: int in range(8):
		var t: float = S_RUN + S_RUN_STEP * float(i)
		var side: float = 1.0 if i % 2 == 0 else -1.0
		k.append(K(t + 0.04, M([B(0.95, 0.08 * side, 0.03 * side), C(0.36, -0.1 * side), HD(1.22, 0.02 * side)])))
	# 8,65 · il jette un œil par-dessus l'épaule, sourit, et accélère (9,05)
	k.append(K(8.6, M([HD(1.1, 0.55, 0.1), {"face": "grin"}])))
	k.append(K(8.82, M([HD(1.2, 0.05, 0.0)])))
	k.append(K(9.05, M([B(1.0), C(0.38), HD(1.28), {"face": "determined"}])))
	c["fv_simon_rain"] = _film(3.3, 9.5, k, "fear")

	# PAPIER · une foulée au ralenti, suspendue : 2,6 s pour deux appuis
	var ink: Array = []
	ink.append(K(0.0, M([_zero(), _s_sonic(), H(0, -0.1, 0.3), {"face": "grin"}])))
	var slow: Dictionary = {"stance": 0.7, "reach": 0.3, "kick": 0.62, "knee": 0.42, "hips": Vector3(0.0, -0.1, 0.3), "bob": 0.06, "up": 0.03, "push": -0.7}
	_strides("Simon", ink, 0.05, 3, 1.25, 0.92, true, slow)
	ink.append(K(1.3, M([B(0.97, 0.05), C(0.37, -0.06)])))
	ink.append(K(2.5, M([B(0.95, -0.05), C(0.36, 0.06)])))
	c["fv_simon_ink"] = _film(0.0, 2.7, ink, "grin")

	_simon_alice(c)


static func _simon_alice(c: Dictionary) -> void :
	var k: Array = []
	var stalk: Dictionary = M([FL(0.04, 0.08), FR(0.06, -0.06), H(0, -0.03, 0.0), B(0.12), C(0.34), HD(0.3, 0.0, 0.08),
		L(0.4, -0.82, 0.2, 0.2), R(0.44, -0.74, 0.34, 0.25), WL(-0.35), WR(-0.3), {"curl": 0.2, "curl_l": 0.25}])
	# A · elle attend, immobile, la tête penchée ; le menton remonte lentement
	k.append(K(3.3, M([_zero(), stalk, FACE("menace")])))
	k.append(K(3.9, M([HD(0.36, 0.0, 0.16), C(0.32)])))
	k.append(K(4.45, M([HD(0.22, 0.0, 0.2), C(0.3), {"face": "grin"}])))
	# C · 4,6 → 5,1 · deux pas vers lui, les griffes se lèvent
	_strides("Alice", k, 4.62, 3, 0.24, 2.0, true, {"stance": 0.3, "reach": 0.32, "kick": 0.08, "knee": 0.1, "strike": 0.2, "push": -0.3, "bob": 0.025, "up": 0.0, "hips": Vector3(0.0, -0.04, 0.02), "width": 0.04})
	k.append(K(4.8, M([B(0.2), C(0.3), HD(0.18, 0.0, 0.1), R(0.5, -0.2, 0.3, 0.5), L(0.5, -0.25, 0.25, 0.5), WR(-0.6), WL(-0.6), {"curl": 0.1, "curl_l": 0.1}])))
	# 5,1 → 5,32 · elle fond sur lui, griffes armées… et tranche une image rémanente
	k.append(K(5.12, M([FL(0.05, 0.36, 0.14), H(0, -0.1, 0.1), B(-0.1, 0.0), C(0.05), HD(0.15), R(0.4, 0.95, -0.15, 0.8), L(0.4, 0.92, -0.1, 0.8), WR(-0.9), WL(-0.9), {"jaw": 0.6, "face": "angry"}]), "s"))
	k.append(K(5.16, M([FR(0.06, -0.3, 0.1), {"fp_r": -0.5}])))
	k.append(K(5.26, M([FL(0.05, 0.45, 0.04), FR(0.06, -0.6, 0.18), H(0, -0.25, 0.4), B(0.55), C(0.4), HD(-0.2), R(0.2, 0.2, 0.95, 0.3), L(0.2, 0.15, 0.95, 0.3), {"jaw": 0.9}])))
	k.append(K(5.29, M([FL(0.05, 0.45), {"fp_l": 0.0}])))
	k.append(K(S_GO, M([H(0, -0.36, 0.5), B(0.7), C(0.5), HD(-0.35), R(0.0, -0.55, 0.75, 0.2), L(0.0, -0.6, 0.7, 0.2), WR(0.4), WL(0.4), {"sq": 0.96}]), "s"))
	k.append(K(5.36, M([FR(0.06, -0.48), {"fp_r": 0.0}])))
	# 5,36 → 6,2 · le souffle la fait tourner sur elle-même (le film fait tourner le
	# corps) : bras projetés, tête qui ballotte
	k.append(K(5.45, M([FL(0.06, 0.3), FR(0.08, -0.2), H(0, -0.12, 0.1), B(-0.05, 0.0, 0.1), C(0.0), HD(0.25, 0.0, 0.35), R(0.95, 0.15, 0.1, 0.9), L(0.95, 0.25, -0.05, 0.9), WR(0.0), WL(0.0),
		{"fp_r": 0.0, "sq": 1.0, "jaw": 0.7, "face": "surprise", "curl": 0.0, "curl_l": 0.0}])))
	k.append(K(5.75, M([HD(0.15, 0.0, -0.3), R(1.0, 0.35, 0.0, 0.9), L(1.0, 0.1, 0.1, 0.9), B(0.0, 0.0, -0.08)])))
	k.append(K(6.0, M([HD(0.3, 0.0, 0.3), R(0.95, 0.05, 0.1, 0.9), L(0.95, 0.3, 0.0, 0.9), B(0.05, 0.0, 0.1), {"face": "dazed"}])))
	# 6,2 → 7,25 · ivre de tours : elle titube, secoue la tête, retrouve Simon
	var wobble: Dictionary = M([FL(0.12, 0.15), FR(0.12, -0.12), H(0, -0.1, 0.0), B(0.1, 0.0, 0.1), C(0.2), HD(0.2, 0.0, 0.3), R(0.55, -0.4, 0.3, 0.5), L(0.6, -0.35, 0.25, 0.5), {"jaw": 0.3}])
	k.append(K(6.25, wobble, "s"))
	k.append(K(6.5, M([H(0.05, -0.12, 0.0), B(0.12, 0.0, -0.14), HD(0.25, 0.0, -0.3)])))
	k.append(K(6.72, M([H(-0.05, -0.1, 0.0), B(0.08, 0.0, 0.12), HD(0.12, 0.0, 0.25)])))
	k.append(K(6.85, M([HD(0.1, 0.3, 0.0)])))
	k.append(K(6.92, M([HD(0.1, -0.3, 0.0)])))
	k.append(K(6.99, M([HD(0.12, 0.25, 0.05)])))
	k.append(K(7.08, M([HD(0.25, 0.0, 0.1), B(0.15), C(0.3), R(0.5, -0.2, 0.3, 0.5), L(0.5, -0.2, 0.3, 0.5), {"face": "angry", "jaw": 0.6}]), "s"))
	# G · 7,3 → 8,15 · la tornade : elle tourne la tête pour le suivre, se fait
	# happer, perd l'équilibre et tombe sur les fesses (8,0)
	k.append(K(7.4, M([HD(0.3, 0.7, 0.1), B(0.1, 0.3), {"face": "surprise"}])))
	k.append(K(7.55, M([HD(0.3, -0.7, -0.1), B(0.1, -0.3)])))
	k.append(K(7.7, M([HD(0.4, 0.6, 0.25), B(0.0, 0.2, 0.15), R(0.9, 0.3, 0.1, 0.9), L(0.9, 0.3, 0.1, 0.9), {"face": "dazed"}])))
	k.append(K(7.88, M([H(0, -0.2, -0.1), B(-0.25, 0.0, -0.2), HD(0.35, -0.4, -0.3), R(0.8, 0.5, 0.3, 0.9), L(0.9, 0.6, 0.0, 0.9), {"jaw": 0.8}])))
	var sit: Dictionary = M([{"plant": 0.0, "gsnap": 1.0}, H(0, -0.55, -0.15), B(-0.25, 0.0, 0.0), C(0.25), HD(0.15, 0.0, 0.25),
		TL(1.35, 0.25), KL(0.3), TR(1.25, 0.15), KR(0.55), Lg(0.6, -0.35), Rg(0.65, -0.3), {"el_l": 0.4, "el_r": 0.4, "face": "dazed", "jaw": 0.35, "curl": 0.3, "curl_l": 0.3}])
	k.append(K(8.0, M([sit, {"sq": 0.9, "ev": "hurt"}]), "s"))
	k.append(K(8.12, M([{"sq": 1.03}, HD(0.0, 0.0, -0.2)])))
	k.append(K(8.3, M([sit, HD(0.2, 0.2, 0.3)])))
	# H · assise, la tête qui roule, étourdie
	k.append(K(8.6, M([HD(0.1, -0.2, -0.3), B(-0.22, 0.0, -0.06)])))
	k.append(K(8.95, M([HD(0.22, 0.25, 0.28), B(-0.26, 0.0, 0.06)])))
	k.append(K(9.3, M([HD(0.12, -0.15, -0.25)])))
	c["fv_simon_alice_rain"] = _film(3.3, 9.5, k, "menace")

	# PAPIER · la toupie qui va tomber : bras écartés, tête qui ballotte, elle
	# tourne au ralenti pendant qu'il passe (le film la fait tourner et pencher)
	var ink: Array = []
	ink.append(K(0.0, M([_zero(), FL(0.14, 0.12), FR(0.14, -0.1, 0.1), H(0, -0.08, 0.0), B(0.0, 0.0, 0.12), C(0.1), HD(0.3, 0.0, 0.35),
		R(0.98, 0.35, 0.05, 0.9), L(0.98, 0.15, 0.1, 0.9), WR(0.2), WL(0.2), {"curl": 0.0, "curl_l": 0.0, "jaw": 0.5, "face": "dazed", "fp_r": -0.3}])))
	ink.append(K(1.3, M([HD(0.2, 0.0, -0.3), R(1.0, 0.1, 0.1, 0.9), L(0.98, 0.4, 0.0, 0.9), B(0.0, 0.0, -0.1)])))
	ink.append(K(2.6, M([HD(0.35, 0.0, 0.3), R(0.98, 0.4, 0.0, 0.9), L(1.0, 0.1, 0.1, 0.9), B(0.0, 0.0, 0.14)])))
	c["fv_simon_alice_ink"] = _film(0.0, 2.7, ink, "dazed")



# ------------------------------------------------------------------- ASHURA --
# Drone et rollers. Un genou à terre sous la pluie, Ashura revisse son drone
# posé devant lui : un tour de poignet sur chaque cliquet (3,43 · 4,08 · 4,46).
# Il a entendu Alice : les yeux montent avant la tête (4,05), il continue de
# visser sans la quitter du regard, un coin de bouche (4,33). Il glisse la main
# sous le drone et le lance d'un geste de bas en haut en se relevant (4,85 →
# 5,0) : BONK en pleine figure (5,47). Départ de patineur, les roues grincent
# sur les clics qui s'accélèrent (5,85 → 6,8), puis poussées croisées autour
# d'elle sur le funk (6,8 → 8,6). Le drone revient lui cogner la nuque (8,35).
# Arrêt de hockeyeur dans une gerbe d'eau (8,6 → 8,85), il rattrape le drone de
# la main gauche (9,1), pouce levé (9,35), les yeux qui brillent (9,6).

const A_FLING: float = 4.85
const A_RELEASE: float = 5.0
const A_BONK: float = 5.47
const A_CHARGE: float = 5.85
const A_GO: float = 6.8
const A_BONK2: float = 8.35
const A_STOP: float = 8.6
const A_CATCH: float = 9.1
const A_THUMB: float = 9.35
const A_STROKE: float = 0.26
# Alice : trois pas lents vers lui (premier appui, vitesse)
const A_WALK: float = 3.4
const A_WALK_SPEED: float = 1.08


# un genou (le droit) à terre, le pied gauche à plat devant
static func _a_kneel() -> Dictionary:
	return M([FL(0.04, 0.5), FR(0.1, -0.52), H(0, -0.5, 0.0), {"fp_l": 0.0, "fp_r": -1.15}])


static func _ashura(c: Dictionary) -> void :
	var k: Array = []
	var work: Dictionary = M([_a_kneel(), B(0.42, 0.05), C(0.22, -0.05), HD(-0.38, 0.05, 0.04),
		Lg(0.02, 0.3, 0.14), Rg(0.18, 0.32, 0.12), WL(0.3, 0.0, 0.2), WR(0.2, 0.0, -0.2), {"curl_l": 0.35, "curl": 0.8, "el_r": 0.35}])
	# A · 3,3 · penché sur le drone : la main gauche le tient, la droite visse
	k.append(K(3.3, M([_zero(), work, FACE("focus")])))
	# cliquet (3,43) : le poignet arme, puis tourne d'un coup sec
	k.append(K(3.37, M([WR(0.2, -0.55, -0.2), Rg(0.19, 0.31, 0.13)])))
	k.append(K(3.43, M([WR(0.2, 0.5, -0.2), Rg(0.18, 0.32, 0.12), SH(0.0, 0.06)]), "s"))
	k.append(K(3.5, SH(0.0, 0.0)))
	# tink (3,56) : un petit coup du bout des doigts (l'étincelle vient du film)
	k.append(K(3.556, M([Rg(0.17, 0.34, 0.1), WR(0.35, 0.3, -0.2), HD(-0.45, 0.1, 0.06)]), "s"))
	# tink (3,69) : la main passe sur l'autre bras du drone
	k.append(K(3.688, M([Rg(0.08, 0.38, 0.12), WR(0.25, 0.2, -0.1), HD(-0.44, 0.0, 0.0)]), "s"))
	# 3,82 · il souffle l'eau qui coule sur la carcasse
	k.append(K(3.76, M([HD(-0.5, 0.0, 0.0), B(0.56, 0.05), {"jaw": 0.0}])))
	k.append(K(3.84, M([HD(-0.53, 0.02, 0.0), B(0.6, 0.05), {"jaw": 0.32}]), "s"))
	k.append(K(3.93, M([HD(-0.46, 0.0, 0.0), B(0.54, 0.05), {"jaw": 0.0}])))
	# tink (3,95) : retour sur la vis
	k.append(K(3.946, M([Rg(0.18, 0.32, 0.12), WR(0.2, -0.5, -0.2)]), "s"))
	# B · 4,05 · il l'a entendue. Les yeux d'abord (paupières), puis la tête
	# monte lentement ; la main droite continue de visser (cliquets 4,08, 4,46)
	k.append(K(4.05, M([HD(-0.46, 0.0, 0.0), {"face": "focus"}])))
	k.append(K(4.075, WR(0.2, 0.5, -0.2), "s"))
	k.append(K(4.14, M([HD(-0.42, 0.0, 0.02)])))
	k.append(K(4.2, WR(0.2, -0.45, -0.2)))
	k.append(K(4.42, M([B(0.3, 0.05), C(0.1, -0.04), HD(0.14, 0.02, 0.07)])))
	k.append(K(4.7, M([B(0.28, 0.05), C(0.08, -0.04), HD(0.18, 0.0, 0.09)])))
	k.append(K(4.333, FACE("smile")))
	k.append(K(4.463, WR(0.2, 0.55, -0.2), "s"))
	blink(4.53, "smile", k, 0.06)
	# 4,6 → 4,85 · la main droite glisse sous le drone ; le corps se ramasse
	k.append(K(4.64, M([Rg(0.14, 0.34, 0.04), WR(-0.2, 0.0, -0.2), {"curl": 0.55}])))
	k.append(K(4.8, M([H(0, -0.55, -0.04), B(0.56, 0.14), C(0.3, 0.06), HD(-0.08, 0.0, 0.05), Rg(0.12, 0.3, 0.03), Lg(0.0, 0.28, 0.13), SH(0.0, -0.06, 0.0, 0.12), {"curl": 0.7}]), "s"))
	# C · 4,85 → 5,0 · il saisit et lance : le bras balaie de bas en haut, le
	# drone part à hauteur d'épaule (5,0) ; le corps se déplie, il se relève
	k.append(K(4.92, M([H(0, -0.44, 0.04), B(0.3, 0.18), C(0.1, 0.12), HD(0.04, -0.05), R(0.3, -0.35, 0.5, 0.2), WR(-0.5, 0.0, 0.0),
		L(0.45, -0.45, 0.25, 0.3), WL(0.0), SH(0.0, 0.05, 0.0, 0.1), {"curl": 0.8, "curl_l": 0.3}])))
	k.append(K(A_RELEASE, M([H(0, -0.3, 0.1), B(0.05, 0.1), C(-0.08, 0.15), HD(0.1, -0.08), R(0.18, 0.2, 0.95, 0.1), WR(0.4, 0.0, 0.0),
		L(0.5, -0.5, -0.1, 0.4), SH(0.0, 0.12, 0.0, 0.2), {"curl": 0.15, "ev": "effort", "fx": "trail_r"}]), "s"))
	k.append(K(5.12, M([H(0, -0.2, 0.08), B(-0.04, 0.05), C(-0.1, 0.08), HD(0.12, -0.04), R(0.25, 0.42, 0.75, 0.2), WR(0.6, 0.0, 0.0), SH(0.0, 0.04), {"curl": 0.0}])))
	# 5,15 → 5,45 · debout : le pied droit revient sous lui, il suit le drone des yeux
	k.append(K(5.2, M([FR(0.1, -0.3, 0.12), {"fp_r": -0.4}])))
	k.append(K(5.34, M([FR(0.12, -0.06), FL(0.06, 0.24), H(0, -0.08, 0.02), B(0.02, 0.0), C(0.0, 0.04), HD(0.06, 0.0, 0.04),
		R(0.3, -0.5, 0.35, 0.3), WR(0.2), L(0.32, -0.7, 0.12, 0.2), SH(0.0, 0.0), {"fp_r": 0.0, "curl": 0.35}]), "s"))
	# 5,47 · BONK (hors champ) : il grimace pour elle, puis le sourire
	k.append(K(A_BONK + 0.03, M([SH(0.12, 0.12), HD(0.02, 0.0, -0.06), {"face": "surprise"}]), "s"))
	k.append(K(5.62, M([SH(0.0, 0.0), HD(0.08, 0.05, 0.1), {"face": "grin"}])))
	# 5,62 → 5,85 · il recule le pied droit, roulettes de biais : départ de patineur
	k.append(K(5.66, M([FR(0.16, -0.25, 0.1), {"fp_r": -0.2}])))
	k.append(K(5.78, M([FR(0.24, -0.5), FL(0.04, 0.22), H(0, -0.26, 0.06), B(0.45, 0.12), C(0.15, -0.05), HD(0.42, -0.08),
		L(0.25, -0.3, 0.45, 0.3), R(0.35, -0.35, -0.42, 0.2), WL(0.2), WR(-0.2), {"fp_r": 0.0, "curl": 0.6, "curl_l": 0.6}]), "s"))
	# D · 5,85 → 6,8 · la charge : il se balance d'avant en arrière sur les
	# roues, plus bas à chaque grosse caisse, de plus en plus tendu
	var crouch: Dictionary = M([FR(0.24, -0.5), FL(0.04, 0.22), B(0.6, 0.12), C(0.2, -0.05), HD(0.55, -0.1),
		L(0.22, -0.28, 0.5, 0.3), R(0.38, -0.32, -0.45, 0.2), {"curl": 0.85, "curl_l": 0.85, "face": "determined"}])
	for i: int in range(4):
		var t: float = A_CHARGE + 0.2375 * float(i)
		var low: float = 0.3 + 0.045 * float(i)
		k.append(K(t, M([crouch, H(0, - low - 0.04, 0.1), FR(0.24, -0.5 - 0.02 * float(i)), {"sq": 0.97}]), "s"))
		k.append(K(t + 0.12, M([H(0, - low, 0.04), {"sq": 1.0, "shake": 0.1 + 0.18 * float(i)}])))
	k.append(K(6.4, FACE("grin")))
	k.append(K(6.62, M([H(0, -0.47, 0.12), B(0.68, 0.14), HD(0.62, -0.1), {"shake": 0.75, "face": "determined"}])))
	k.append(K(6.76, M([H(0, -0.48, 0.14), B(0.7, 0.15), {"shake": 0.9}])))
	# E · 6,8 · parti : la jambe arrière pousse, tout le corps se jette en avant
	k.append(K(A_GO, M([FR(0.34, -0.72), FL(0.02, 0.3), H(0, -0.36, 0.26), B(0.78, 0.0), C(0.15, 0.0), HD(0.72, 0.0),
		R(0.1, -0.1, 0.7, 0.2), L(0.35, -0.3, -0.5, 0.2), {"shake": 0.0, "fp_r": -0.45, "sq": 1.05, "ev": "effort"}]), "s"))
	k.append(K(6.92, M([FR(0.26, -0.4, 0.14), {"fp_r": -0.3, "sq": 1.0}])))
	# poussées croisées (gauche, droite…) sur les doubles croches du funk
	_skate(k, 7.02, 6, A_STROKE, false, {"push": 0.46, "back": 0.32, "depth": 0.34, "lean": 0.62, "arms": 1.0, "lift": 0.12})
	# tête stable, le regard sur Alice pendant la courbe
	for i: int in range(6):
		var t: float = 7.02 + A_STROKE * (float(i) + 0.5)
		k.append(K(t, M([HD(0.6, 0.12 * sin(1.3 * float(i)) + 0.25, 0.0), C(0.15, 0.0)])))
	k.append(K(7.32, FACE("grin")))
	# 8,35 → 8,6 · il glisse sur un pied, couché dans le virage
	k.append(K(8.42, M([FL(0.06, 0.05), FR(0.12, -0.2, 0.1), H(-0.04, -0.36, -0.02), B(0.5, 0.15, 0.12), C(0.1, 0.1), HD(0.45, 0.4),
		L(0.5, -0.15, 0.1, 0.4), R(0.45, -0.25, -0.2, 0.3), {"fp_r": -0.2}])))
	# F · 8,6 → 8,85 · arrêt de hockeyeur : les deux patins en travers, il se
	# couche contre la glissade, la gerbe d'eau (le film), puis se redresse
	var skid: Dictionary = M([FL(0.2, 0.06), FR(0.26, -0.08), H(-0.12, -0.42, -0.05), B(-0.12, 0.0, 0.22), C(0.1, -0.1, 0.05), HD(0.15, 0.1, -0.15),
		L(0.75, 0.1, 0.25, 0.6), R(0.7, -0.05, -0.1, 0.5), WL(0.2), WR(-0.2), {"fp_l": 0.0, "fp_r": 0.0, "curl": 0.4, "curl_l": 0.4, "face": "grin"}])
	k.append(K(A_STOP, M([skid, {"fx": "skid"}]), "s"))
	k.append(K(8.74, M([H(-0.1, -0.4, -0.04), B(-0.06, 0.0, 0.18), {"fx": "skid"}])))
	k.append(K(8.85, M([FL(0.12, 0.1), FR(0.14, -0.1), H(0, -0.12, 0.04), B(0.12, 0.0, 0.0), C(0.04), HD(0.05, 0.0, 0.0), L(0.4, -0.55, 0.15, 0.3), R(0.4, -0.55, 0.1, 0.3), {"sq": 1.02}]), "s"))
	k.append(K(8.95, M([H(0, -0.06, 0.0), B(0.02), {"sq": 1.0}])))
	# 9,0 → 9,1 · le drone redescend : la main gauche monte et l'attrape au vol
	k.append(K(8.98, M([HD(0.4, 0.15, 0.05), L(0.35, 0.3, 0.25, 0.4), {"curl_l": 0.1}])))
	k.append(K(A_CATCH, M([HD(0.32, 0.12, 0.05), L(0.38, 0.62, 0.18, 0.3), WL(-0.3), {"curl_l": 0.9}]), "s"))
	k.append(K(9.16, M([L(0.4, 0.5, 0.18, 0.35), H(0, -0.09, 0.0), {"sq": 0.98}])))
	k.append(K(9.26, M([L(0.45, 0.25, 0.2, 0.4), HD(0.05, 0.0, 0.08), H(0, -0.05, 0.0), {"sq": 1.0}])))
	# 9,35 · pouce levé vers nous
	k.append(K(9.28, M([Rt(0.3, 0.06, 0.45, 0.4), WR(0.3, -0.6), {"curl": 1.0}])))
	k.append(K(A_THUMB, M([Rt(0.42, 0.2, 0.62, 0.35), WR(0.0, -1.3), HD(0.06, -0.06, 0.16), B(0.0, -0.08), {"gesture": "thumbsup", "face": "grin"}]), "s"))
	k.append(K(9.5, M([Rt(0.42, 0.23, 0.6, 0.35), HD(0.08, -0.05, 0.14)])))
	blink(9.53, "grin", k, 0.06)
	k.append(K(9.62, M([HD(0.12, -0.04, 0.12), B(-0.02, -0.06)])))
	k.append(K(9.8, M([Rt(0.42, 0.24, 0.6, 0.35), HD(0.12, -0.03, 0.13)])))
	c["fv_ashura_rain"] = _film(3.3, 9.9, k, "focus")

	# PAPIER · la glisse : sur le patin droit, la jambe gauche tendue derrière,
	# bras ouverts ; il se retourne vers Alice, le drone au-dessus de l'épaule
	var ink: Array = []
	# de profil, tout s'étire d'avant en arrière pour que la silhouette se lise
	var glide: Dictionary = M([_zero(), FR(0.02, 0.06), FL(0.06, -0.9, 0.34), H(0.0, -0.26, 0.08), B(0.5, 0.0, 0.0), C(0.12), HD(0.55, 0.12, 0.0),
		L(0.18, -0.05, -0.85, 0.2), R(0.18, 0.1, 0.8, 0.2), WL(0.3), WR(-0.2), {"fp_l": -0.6, "curl": 0.6, "curl_l": 0.3, "face": "grin"}])
	ink.append(K(0.0, glide))
	ink.append(K(1.3, M([FL(0.06, -0.95, 0.4), B(0.53), HD(0.56, 0.16, 0.02), L(0.18, 0.0, -0.9, 0.2), R(0.18, 0.15, 0.84, 0.2)])))
	ink.append(K(2.6, M([FL(0.06, -0.98, 0.44), B(0.55), HD(0.58, 0.2, 0.04), L(0.18, 0.04, -0.92, 0.2), R(0.16, 0.18, 0.86, 0.2)])))
	c["fv_ashura_ink"] = _film(0.0, 2.7, ink, "grin")

	_ashura_alice(c)


# Alice assise par terre, jambes devant, les mains derrière elle. Bassin posé
# explicitement à 12 cm du sol et pieds plantés loin devant (l'IK relève les
# genoux) : "gsnap" se calerait sur les mains au sol, pas sur les fesses.
static func _alice_sit() -> Dictionary:
	var leg: float = float(LEG.Alice)
	var low: float = (0.12 - 1.042) / leg
	# penchée en arrière sur les mains, un genou levé : la silhouette se lit
	# même sous la robe
	return M([H(0, low, -0.2), FL(0.1, 0.88), FR(0.16, 0.52), B(-0.55, 0.0, 0.0), C(0.16), HD(0.32, 0.0, 0.25),
		Lg(0.45, -0.58), Rg(0.5, -0.52), {"fp_l": 0.5, "fp_r": 0.2, "el_l": 0.4, "el_r": 0.4, "face": "dazed", "jaw": 0.35, "curl": 0.3, "curl_l": 0.3}])


static func _ashura_alice(c: Dictionary) -> void :
	var k: Array = []
	# A · 3,3 → 4,65 · elle s'approche sans se presser, la tête penchée, les
	# griffes qui pendent ; trois pas
	var prowl: Dictionary = M([H(0, -0.04, 0.0), B(0.12), C(0.22, 0.0, 0.04), HD(0.08, 0.0, 0.22),
		L(0.32, -0.78, 0.22, 0.25), R(0.34, -0.74, 0.3, 0.3), WL(-0.3), WR(-0.35), {"curl": 0.25, "curl_l": 0.3}])
	k.append(K(3.3, _no_feet(M([_zero(), prowl, FACE("menace")]))))
	var walk: Dictionary = {"stance": 0.66, "reach": 0.34, "kick": 0.1, "knee": 0.07, "strike": 0.16, "push": -0.32, "bob": 0.015, "up": 0.0, "hips": Vector3(0.0, -0.04, 0.0), "width": 0.03}
	_stride_in("Alice", k, 3.3, A_WALK, 0.55, A_WALK_SPEED, true, walk)
	_strides("Alice", k, A_WALK, 3, 0.55, A_WALK_SPEED, true, walk)
	# les doigts qui pianotent dans le vide, la tête qui roule d'une épaule à l'autre
	k.append(K(3.7, M([HD(0.06, 0.05, 0.12), {"curl": 0.45}])))
	k.append(K(3.95, M([HD(0.1, -0.04, 0.24), {"curl": 0.15, "curl_l": 0.5}])))
	k.append(K(4.3, M([HD(0.05, 0.02, 0.18), {"curl": 0.4, "curl_l": 0.2}])))
	# 4,65 → 4,85 · elle s'arrête au-dessus de lui, lève lentement la griffe droite
	k.append(K(4.62, M([FLR(0.04, 0.0), FL(0.05, 0.08), FR(0.06, -0.06), H(0, -0.03, 0.0), {"fp_l": 0.0, "fp_r": 0.0}])))
	k.append(K(4.86, M([B(0.04, 0.1), C(0.1, 0.08), HD(-0.05, -0.05, 0.12), R(0.32, 0.55, 0.15, 0.6), WR(-0.7), {"curl": 0.0, "jaw": 0.15}])))
	# 4,95 → 5,4 · le drone décolle : elle le suit des yeux, surprise
	k.append(K(5.05, M([HD(0.12, -0.02, 0.05), {"face": "surprise"}])))
	k.append(K(5.3, M([HD(0.0, 0.0, 0.0), R(0.32, 0.6, 0.18, 0.6), {"jaw": 0.35}])))
	# 5,47 · BONK : la tête part en arrière, les bras s'envolent ; petit saut en
	# arrière (le film recule le corps pendant qu'elle est en l'air)
	var bonk: Dictionary = M([H(0, 0.04, -0.06), B(-0.32, 0.0, 0.05), C(-0.25, 0.08), HD(0.7, 0.1, 0.15), R(0.85, 0.55, 0.05, 0.8), L(0.8, 0.4, -0.05, 0.8),
		WR(0.3), WL(0.3), FL(0.05, 0.1, 0.08), FR(0.06, -0.05, 0.1), {"sq": 1.06, "jaw": 0.7, "face": "pain", "ev": "hurt", "curl": 0.0, "curl_l": 0.0}])
	k.append(K(A_BONK, bonk, "s"))
	k.append(K(5.56, M([H(0, -0.02, -0.08), B(-0.25, 0.0, 0.08), HD(0.5, 0.15, 0.2), FL(0.05, 0.12, 0.05), FR(0.06, -0.1, 0.06), {"sq": 1.0}])))
	k.append(K(5.62, M([FL(0.05, 0.12), FR(0.06, -0.14), H(0, -0.16, -0.04), B(0.1, 0.0, 0.04), HD(0.0, 0.1, 0.1), {"sq": 0.95, "fp_l": 0.0, "fp_r": 0.0}]), "s"))
	# 5,62 → 5,85 · les mains sur les yeux, pliée
	var blind: Dictionary = M([H(0, -0.1, -0.02), B(0.3, 0.0, 0.02), C(0.25), HD(-0.25, 0.05, 0.08),
		Rt(-0.06, 0.62, 0.42, 0.5), Lt(-0.08, 0.6, 0.45, 0.5), WR(0.6, 0.0, -0.2), WL(0.6, 0.0, 0.2), {"curl": 0.25, "curl_l": 0.25, "jaw": 0.4, "sq": 1.0}])
	k.append(K(5.78, blind))
	# 5,85 → 6,8 · aveuglée : elle se frotte les yeux, secoue la tête, puis écoute
	k.append(K(5.96, M([Rt(-0.02, 0.66, 0.4, 0.5), Lt(-0.12, 0.58, 0.46, 0.5), HD(-0.2, 0.1, 0.0)])))
	k.append(K(6.1, M([Rt(-0.08, 0.6, 0.44, 0.5), Lt(-0.04, 0.64, 0.42, 0.5), HD(-0.28, -0.05, 0.1)])))
	k.append(K(6.2, M([HD(-0.1, 0.35, 0.0), Rt(0.1, 0.4, 0.4, 0.4), Lt(0.1, 0.38, 0.42, 0.4)])))
	k.append(K(6.26, M([HD(-0.1, -0.35, 0.0)])))
	k.append(K(6.32, M([HD(-0.05, 0.25, 0.0)])))
	k.append(K(6.42, M([H(0, -0.12, 0.0), B(0.22, 0.0), C(0.15), HD(0.02, 0.0, 0.05), R(0.5, -0.1, 0.45, 0.5), L(0.5, -0.12, 0.42, 0.5), WR(-0.5), WL(-0.5),
		{"face": "angry", "jaw": 0.2, "curl": 0.1, "curl_l": 0.1}])))
	k.append(K(6.55, M([HD(0.05, 0.45, 0.12)])))
	k.append(K(6.7, M([HD(0.05, -0.3, -0.08)])))
	# 6,8 · le départ des roulettes : la tête claque vers sa gauche
	k.append(K(A_GO + 0.04, M([HD(0.08, 0.7, 0.05), B(0.2, 0.35), C(0.12, 0.2)]), "s"))
	# 7,0 → 7,32 · elle arme la griffe… et fauche le vide (clap 7,32)
	k.append(K(7.16, M([B(0.12, -0.25), C(0.05, -0.3), HD(0.05, 0.5, 0.05), R(0.75, 0.45, -0.25, 0.8), WR(-0.8), {"jaw": 0.6, "curl": 0.0}])))
	k.append(K(7.32, M([FR(0.06, 0.18), B(0.35, 0.65), C(0.25, 0.4), HD(-0.05, 0.3, 0.1), R(0.1, -0.1, 0.9, 0.3), WR(0.4), {"jaw": 0.9, "ev": "roar", "fx": "trail_r"}]), "s"))
	# l'élan la fait tourner sur elle-même (le film fait pivoter le corps)
	k.append(K(7.48, M([B(0.25, 0.4, 0.1), C(0.1, 0.2), HD(0.15, 0.1, 0.25), R(0.75, 0.3, 0.35, 0.8), L(0.8, 0.35, -0.1, 0.8), {"jaw": 0.4, "face": "surprise"}])))
	k.append(K(7.7, M([FR(0.08, 0.02), FL(0.06, 0.06), B(0.1, 0.0, -0.08), HD(0.12, -0.3, -0.15), R(0.55, 0.0, 0.3, 0.5), L(0.6, 0.05, 0.25, 0.5), {"face": "angry"}])))
	k.append(K(7.95, M([HD(0.08, 0.45, 0.1), B(0.12, 0.15, 0.05)])))
	k.append(K(8.15, M([HD(0.06, -0.4, -0.05), B(0.15, -0.12, 0.0), {"jaw": 0.5}])))
	# 8,35 · BONK dans la nuque : la tête part en avant, les genoux lâchent…
	k.append(K(A_BONK2, M([H(0, -0.1, 0.06), B(0.55, 0.0, 0.0), C(0.3), HD(-0.45, 0.0, 0.0), R(0.6, 0.2, 0.55, 0.6), L(0.55, 0.25, 0.5, 0.6),
		{"sq": 0.94, "jaw": 0.8, "face": "pain", "ev": "hurt"}]), "s"))
	k.append(K(8.46, M([H(0, -0.3, -0.05), B(0.2, 0.0, 0.1), HD(0.1, 0.1, 0.2), {"sq": 1.0}])))
	# … et elle s'assoit d'un coup sur les fesses (8,6)
	var sit: Dictionary = _alice_sit()
	k.append(K(A_STOP, M([sit, {"sq": 0.9}]), "s"))
	k.append(K(8.72, M([{"sq": 1.03}, HD(0.0, 0.1, -0.2)])))
	k.append(K(8.9, M([sit, HD(0.2, 0.2, 0.3)])))
	# assise, étourdie : la main droite frotte la bosse, la tête roule
	k.append(K(9.15, M([HD(0.05, -0.15, -0.25), Rt(-0.05, 0.75, -0.05, 0.6), WR(0.5), {"curl": 0.5}])))
	k.append(K(9.4, M([HD(0.18, 0.2, 0.25), Rt(0.0, 0.78, -0.1, 0.6)])))
	k.append(K(9.65, M([HD(0.08, -0.12, -0.2), Rt(-0.06, 0.74, -0.04, 0.6)])))
	k.append(K(9.85, M([HD(0.15, 0.15, 0.22)])))
	c["fv_ashura_alice_rain"] = _film(3.3, 9.9, k, "menace")

	# PAPIER · l'instant où elle s'étale : les fesses au sol, les jambes qui
	# partent en l'air, les bras jetés en arrière (sous la robe, une Alice assise
	# se lirait debout) ; tout continue de monter au ralenti
	var ink: Array = []
	var low: float = (0.14 - 1.042) / float(LEG.Alice)
	ink.append(K(0.0, M([_zero(), H(0, low, -0.3), B(-0.72), C(0.1), HD(0.42, 0.1, 0.3), FL(0.08, 0.72, 0.62), FR(0.12, 0.58, 0.82),
		L(0.85, 0.15, -0.3, 0.6), R(0.8, 0.35, -0.15, 0.6), WL(-0.4), WR(-0.5), {"fp_l": 0.4, "fp_r": 0.6, "curl": 0.0, "curl_l": 0.1, "jaw": 0.6, "face": "dazed"}])))
	ink.append(K(1.3, M([B(-0.76), HD(0.46, 0.05, 0.32), FL(0.08, 0.74, 0.7), FR(0.12, 0.6, 0.9), L(0.88, 0.2, -0.32, 0.6), R(0.82, 0.42, -0.16, 0.6)])))
	ink.append(K(2.6, M([B(-0.8), HD(0.5, 0.0, 0.34), FL(0.08, 0.75, 0.76), FR(0.12, 0.6, 0.96), L(0.9, 0.24, -0.34, 0.6), R(0.84, 0.48, -0.18, 0.6)])))
	c["fv_ashura_alice_ink"] = _film(0.0, 2.7, ink, "dazed")
