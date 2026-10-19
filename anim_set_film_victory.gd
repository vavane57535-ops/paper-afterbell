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
	_lysia(c)
	_elly(c)
	_bleuette(c)


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



# -------------------------------------------------------------------- LYSIA --
# Surtension. Lysia est à l'arrêt sous la pluie, en recharge : tête basse, bras
# ballants, la pluie fume sur son armure ; chaque grosse caisse la secoue
# (3,4 · 3,83 · 4,26 · 4,69) et chaque étincelle de la partition lui arrache un
# tic (3,51 · 3,72). Redémarrage à 4,04 : la tête se relève par à-coups, les
# yeux s'ouvrent (4,15), deux mises au point (4,47 · 4,79). Ruée d'épaule sur
# Alice (4,9 → 5,2), puis les pieds se plantent : la surchauffe monte sur les
# grosses caisses qui s'accélèrent (5,55 → 6,5) pendant qu'Alice revient à la
# charge. DÉCHARGE des deux paumes (6,55) : Alice traverse la cour. Le bras
# droit reste en l'air un temps de trop (automate un peu cassée), la vapeur
# s'échappe (7,65), petits tics de recalage sur l'arpège, un regard vers nous
# et un sourire de travers (8,15).

const L_BOOT: float = 4.043
const L_OPEN: float = 4.15
const L_DASH: float = 4.9
const L_HIT: float = 5.2
const L_HEAT: float = 5.55
const L_PUSH: float = 6.55
const L_VENT: float = 7.65
const L_TURN: float = 8.15
const L_DASH_SPEED: float = 7.2
# Alice : approche, recul, retour à la charge, atterrissage après la décharge
const LA_WALK_SPEED: float = 1.3
const LA_WALK_END: float = 4.45
const LA_RUSH: float = 5.78
const LA_RUSH_SPEED: float = 1.5
const LA_LAND: float = 7.4


static func _lysia(c: Dictionary) -> void :
	var k: Array = []
	# A · 3,3 · à l'arrêt : tête basse, épaules tombées, bras ballants, yeux fermés
	var off: Dictionary = M([FL(0.05, 0.03), FR(0.05, -0.02), H(0, -0.05, 0.0), B(0.06), C(0.1), HD(-0.48, 0.0, 0.06),
		L(0.2, -0.85, 0.06, 0.15), R(0.22, -0.84, 0.04, 0.15), WL(0.25), WR(0.3), SH(-0.1, -0.12), {"curl": 0.35, "curl_l": 0.4}])
	k.append(K(3.3, M([_zero(), off, FACE("asleep")])))
	# chaque grosse caisse : une secousse sèche qui remonte les épaules
	for t: float in [3.4, 3.829, 4.257]:
		k.append(K(t, M([SH(0.1, 0.14), C(0.04), {"shake": 0.7, "sq": 1.02}]), "s"))
		k.append(K(t + 0.1, M([SH(-0.08, -0.1), C(0.1), {"shake": 0.0, "sq": 1.0}])))
	# les étincelles : un doigt, puis la tête qui part d'un coup sur le côté
	k.append(K(3.507, {"curl_l": 0.0}, "s"))
	k.append(K(3.6, {"curl_l": 0.4}))
	k.append(K(3.721, M([HD(-0.46, 0.0, 0.2), {"curl": 0.0}]), "s"))
	k.append(K(3.86, M([HD(-0.48, 0.0, 0.06), {"curl": 0.35}]), "s"))
	# B · 4,04 · redémarrage : la tête se relève en deux crans
	k.append(K(L_BOOT, M([HD(-0.2, 0.0, 0.0), SH(0.0, 0.0), B(0.02), C(0.02), {"shake": 0.3}]), "s"))
	k.append(K(L_OPEN, M([HD(-0.2, 0.0, 0.0), {"face": "focus", "shake": 0.0}]), "s"))
	k.append(K(4.22, M([HD(0.02, 0.0, 0.0)]), "s"))
	# mises au point sur Alice : un cran à gauche, puis la tête se verrouille
	k.append(K(4.471, M([HD(0.02, 0.12, 0.1)]), "s"))
	k.append(K(4.686, M([SH(0.08, 0.08), {"shake": 0.5}]), "s"))
	k.append(K(4.75, M([SH(0.0, 0.0), {"shake": 0.0}])))
	k.append(K(4.793, M([HD(0.0, 0.0, 0.0), {"face": "determined"}]), "s"))
	k.append(K(4.83, M([HD(-0.03, 0.0, 0.0)])))
	# C · 4,85 · la ruée : elle s'abaisse, l'épaule gauche devant, puis part
	k.append(K(4.86, M([FR(0.06, -0.22), H(0, -0.16, 0.0), B(0.3, 0.3), C(0.1, 0.2), HD(0.2, -0.4),
		L(0.25, -0.6, 0.15, 0.4), R(0.3, -0.55, -0.35, 0.3), SH(0.0, 0.0, 0.25, 0.0), {"curl": 1.0, "curl_l": 1.0}]), "s"))
	k.append(K(L_DASH, M([H(0, -0.18, 0.15), B(0.55, 0.35), C(0.12, 0.2), HD(0.42, -0.4)])))
	var dash: Dictionary = {"stance": 0.06, "reach": 0.32, "kick": 0.5, "knee": 0.35, "hips": Vector3(0.0, -0.18, 0.15), "bob": 0.04, "push": -0.6}
	_strides("Lysia", k, 4.94, 3, 0.09, L_DASH_SPEED, true, dash)
	# 5,2 · l'épaule entre dans Alice ; les pieds dérapent, elle s'arrête
	var ram: Dictionary = M([FL(0.06, 0.32), FR(0.08, -0.3), H(0, -0.2, 0.2), B(0.4, 0.55), C(0.15, 0.25), HD(0.3, -0.5),
		L(0.15, -0.45, 0.35, 0.3), R(0.35, -0.5, -0.4, 0.3), SH(0.05, 0.0, 0.35, 0.0), {"fp_l": 0.0, "fp_r": 0.0, "sq": 0.95, "ev": "effort", "fx": "pop_l"}])
	k.append(K(L_HIT, ram, "s"))
	k.append(K(5.34, M([FL(0.06, 0.24), FR(0.08, -0.26), H(0, -0.22, 0.05), B(0.2, 0.35), C(0.05, 0.15), HD(0.18, -0.3), {"sq": 1.0}]), "s"))
	# 5,4 → 5,55 · elle se remet de face et plante les pieds, larges
	k.append(K(5.44, M([FR(0.12, -0.12, 0.1), B(0.05, 0.05), C(0.0), HD(0.0, -0.05), SH(0.0, 0.0)])))
	k.append(K(5.5, M([FR(0.2, -0.05), FL(0.12, 0.12, 0.08), {"fp_r": 0.0}]), "s"))
	k.append(K(L_HEAT - 0.02, M([FL(0.2, 0.06), {"fp_l": 0.0}]), "s"))
	# D · 5,55 → 6,5 · surchauffe : poings serrés, bras écartés du corps, la tête
	# part en arrière ; une secousse à chaque grosse caisse, de plus en plus forte
	var heat: Dictionary = M([FL(0.24, 0.06), FR(0.24, -0.05), H(0, -0.14, 0.0), B(-0.04), C(-0.14), HD(0.12, 0.0),
		L(0.78, -0.42, 0.05, 0.8), R(0.8, -0.4, 0.04, 0.8), WL(0.3, 0.3), WR(0.3, -0.3), SH(0.16, 0.16), {"curl": 1.0, "curl_l": 1.0, "face": "angry", "jaw": 0.3}])
	k.append(K(L_HEAT, M([heat, {"shake": 0.25}])))
	for i: int in range(8):
		var t: float = L_HEAT + 0.11875 * float(i)
		var u: float = float(i) / 7.0
		k.append(K(t, M([H(0, -0.14 - 0.1 * u, 0.0), HD(0.12 + 0.36 * u, 0.0, 0.04 * sin(2.3 * float(i))), C(-0.14 - 0.12 * u),
			L(0.78 + 0.08 * u, -0.42 + 0.08 * u, 0.05, 0.8), R(0.8 + 0.08 * u, -0.4 + 0.08 * u, 0.04, 0.8), {"sq": 0.98, "shake": 0.3 + 0.7 * u}]), "s"))
		k.append(K(t + 0.06, M([{"sq": 1.0}])))
	# 6,42 · elle arme : coudes en arrière, paumes ouvertes, le regard redescend sur Alice
	k.append(K(6.44, M([H(0, -0.16, -0.06), B(-0.1), C(-0.2), HD(-0.05, 0.0), L(0.4, -0.25, -0.35, 0.8), R(0.42, -0.24, -0.36, 0.8),
		WL(-0.6), WR(-0.6), SH(0.0, 0.0, -0.2, -0.2), {"curl": 0.0, "curl_l": 0.0, "jaw": 0.5, "shake": 1.0}]), "s"))
	# E · 6,55 · DÉCHARGE : les deux paumes en avant, tout le corps pousse
	var push: Dictionary = M([FL(0.2, 0.18), FR(0.2, -0.16), H(0, -0.2, 0.2), B(0.25), C(0.08), HD(0.05, 0.0),
		Lt(0.12, 0.22, 0.95, 0.3), Rt(0.12, 0.22, 0.95, 0.3), WL(-1.1), WR(-1.1), SH(0.0, 0.0, 0.3, 0.3),
		{"fp_r": -0.4, "curl": 0.0, "curl_l": 0.0, "jaw": 0.8, "face": "angry", "ev": "roar", "sq": 1.06, "shake": 0.0}])
	k.append(K(L_PUSH, push, "s"))
	k.append(K(6.64, M([H(0, -0.18, 0.12), Lt(0.12, 0.25, 0.82, 0.3), Rt(0.12, 0.25, 0.82, 0.3), {"sq": 1.0, "shake": 0.4}])))
	k.append(K(6.76, M([H(0, -0.2, 0.18), Lt(0.12, 0.22, 0.92, 0.3), Rt(0.12, 0.22, 0.92, 0.3), {"shake": 0.2}])))
	# F · 7,0 · le calme : les bras redescendent… sauf le droit, resté en l'air,
	# qui retombe d'un coup (7,45) ; les genoux fléchissent, la tête s'incline
	k.append(K(7.0, M([H(0, -0.14, 0.12), B(0.15), Lt(0.12, 0.2, 0.9, 0.3), Rt(0.12, 0.22, 0.92, 0.3), {"jaw": 0.1, "face": "focus", "shake": 0.0}])))
	k.append(K(7.3, M([H(0, -0.18, 0.06), B(0.1), HD(-0.12, 0.0, 0.05), L(0.3, -0.75, 0.1, 0.3), WL(0.2), {"curl_l": 0.4}])))
	k.append(K(7.43, M([Rt(0.12, 0.2, 0.9, 0.3), WR(-0.9)]), "h"))
	k.append(K(7.47, M([R(0.28, -0.78, 0.05, 0.3), WR(0.4), {"curl": 0.45, "sq": 0.99}]), "s"))
	k.append(K(7.55, M([R(0.25, -0.82, 0.08, 0.25), WR(0.3), {"sq": 1.0}])))
	# G · 7,65 · la vapeur s'échappe : les épaules montent, puis tout se relâche
	k.append(K(L_VENT, M([H(0, -0.1, 0.05), C(-0.08), HD(0.15, 0.0, 0.0), SH(0.14, 0.14), {"face": "calm"}])))
	k.append(K(7.85, M([H(0, -0.06, 0.03), C(0.06), HD(-0.05, 0.0, 0.0), SH(-0.06, -0.06), FL(0.12, 0.06), FR(0.12, -0.04)])))
	# l'arpège : petits tics de recalage de la tête, un cran par note
	for i: int in range(5):
		var t: float = L_VENT + 0.05 + 0.10714 * float(i)
		k.append(K(t, M([HD(-0.05 + 0.02 * float(i % 2), 0.0, 0.07 * (1.0 if i % 2 == 0 else -1.0))]), "s"))
	# H · 8,15 · elle tourne la tête vers nous ; un sourire de travers, un tic
	k.append(K(L_TURN, M([HD(0.04, 0.42, 0.0), C(0.04, 0.1), B(0.02, 0.06), {"face": "smile"}]), "s"))
	k.append(K(8.3, M([HD(0.06, 0.45, 0.12)])))
	k.append(K(8.44, M([HD(0.06, 0.45, 0.26)]), "s"))
	k.append(K(8.5, M([HD(0.06, 0.45, 0.12)]), "s"))
	blink(8.36, "smile", k, 0.06)
	c["fv_lysia_rain"] = _film(3.3, 8.7, k, "asleep")

	# PAPIER · la décharge figée : les paumes en avant, le corps qui pousse
	var ink: Array = []
	ink.append(K(0.0, M([_zero(), push, {"ev": "", "jaw": 0.7, "shake": 0.0}])))
	ink.append(K(1.3, M([H(0, -0.21, 0.22), Lt(0.12, 0.23, 0.97, 0.3), Rt(0.12, 0.23, 0.97, 0.3)])))
	ink.append(K(2.6, M([H(0, -0.22, 0.24), B(0.27), Lt(0.12, 0.24, 0.98, 0.3), Rt(0.12, 0.24, 0.98, 0.3)])))
	c["fv_lysia_ink"] = _film(0.0, 2.7, ink, "angry")

	_lysia_alice(c)


static func _lysia_alice(c: Dictionary) -> void :
	var k: Array = []
	# A · 3,3 → 4,85 · elle avance vers la machine éteinte, les griffes prêtes
	var prowl: Dictionary = M([H(0, -0.05, 0.0), B(0.15), C(0.2, 0.0, -0.04), HD(0.05, 0.0, -0.15),
		L(0.36, -0.7, 0.3, 0.3), R(0.36, -0.72, 0.26, 0.3), WL(-0.4), WR(-0.35), {"curl": 0.2, "curl_l": 0.2}])
	k.append(K(3.3, _no_feet(M([_zero(), prowl, FACE("menace")]))))
	var walk: Dictionary = {"stance": 0.62, "reach": 0.36, "kick": 0.1, "knee": 0.07, "strike": 0.16, "push": -0.32, "bob": 0.015, "up": 0.0, "hips": Vector3(0.0, -0.05, 0.0), "width": 0.03}
	_stride_in("Alice", k, 3.3, 3.45, 0.5, LA_WALK_SPEED, true, walk)
	_strides("Alice", k, 3.45, 3, 0.5, LA_WALK_SPEED, true, walk)
	k.append(K(3.75, M([HD(0.0, 0.05, -0.2), {"curl": 0.4}])))
	k.append(K(4.2, M([HD(0.08, -0.04, -0.1), {"curl": 0.1, "curl_l": 0.45}])))
	# 4,45 → 4,85 · elle s'arrête devant elle, penche la tête : cette chose dort ?
	k.append(K(4.55, M([FL(0.05, 0.14), FR(0.06, -0.08), H(0, -0.03, 0.0), {"fp_l": 0.0, "fp_r": 0.0}])))
	k.append(K(4.72, M([B(0.2), C(0.25), HD(0.0, 0.0, -0.32), {"face": "grin"}])))
	# 4,9 · elle ne s'attendait pas à ça : les griffes se lèvent trop tard
	k.append(K(4.95, M([B(0.0), C(0.05), HD(0.15, 0.0, 0.0), R(0.4, 0.3, 0.35, 0.6), L(0.4, 0.25, 0.35, 0.6), WR(-0.6), WL(-0.6), {"face": "surprise", "jaw": 0.5, "curl": 0.0, "curl_l": 0.0}])))
	# 5,2 · l'épaule de Lysia dans la poitrine : elle décolle en arrière
	var hit: Dictionary = M([H(0, 0.05, -0.12), B(-0.4, 0.15), C(-0.2), HD(-0.3, 0.1, 0.1), R(0.5, 0.1, 0.65, 0.5), L(0.5, 0.15, 0.6, 0.5),
		FL(0.05, 0.25, 0.12), FR(0.06, 0.12, 0.08), {"sq": 0.92, "jaw": 0.8, "face": "pain", "ev": "hurt"}])
	k.append(K(L_HIT, hit, "s"))
	k.append(K(5.32, M([H(0, 0.0, -0.08), B(-0.25, 0.1), HD(0.15, 0.1, 0.15), R(0.75, 0.35, 0.3, 0.7), L(0.75, 0.4, 0.2, 0.7), {"sq": 1.03}])))
	# 5,42 · elle retombe sur ses pieds, glisse, se rattrape
	k.append(K(5.42, M([FL(0.06, 0.2), FR(0.06, -0.15), H(0, -0.2, -0.02), B(0.25, 0.0), C(0.2), HD(-0.1, -0.1, 0.1), R(0.55, -0.3, 0.35, 0.5), L(0.55, -0.32, 0.3, 0.5), {"sq": 0.94, "fp_l": 0.0, "fp_r": 0.0}]), "s"))
	k.append(K(5.5, M([HD(0.0, 0.3, 0.0), {"sq": 1.0}])))
	k.append(K(5.56, M([HD(0.0, -0.25, 0.0)])))
	# 5,62 · le rugissement, puis elle revient sur elle à grands pas
	k.append(K(5.64, M([H(0, -0.12, 0.0), B(0.35), C(0.25), HD(-0.2, 0.0, 0.0), R(0.55, 0.0, 0.45, 0.6), L(0.55, 0.0, 0.4, 0.6), WR(-0.7), WL(-0.7),
		{"jaw": 1.0, "face": "angry", "ev": "roar"}]), "s"))
	var stalk: Dictionary = {"stance": 0.4, "reach": 0.32, "kick": 0.18, "knee": 0.12, "strike": 0.12, "push": -0.4, "bob": 0.03, "up": 0.0, "hips": Vector3(0.0, -0.14, 0.04), "width": 0.04}
	_strides("Alice", k, LA_RUSH, 3, 0.3, LA_RUSH_SPEED, false, stalk)
	k.append(K(6.0, M([B(0.3), HD(-0.12, 0.0, 0.0), R(0.45, 0.55, 0.15, 0.7), L(0.45, 0.5, 0.2, 0.7), {"jaw": 0.6}])))
	# 6,4 · elle bondit, griffes en avant
	k.append(K(6.46, M([H(0, -0.06, 0.2), B(0.5), C(0.3), HD(-0.25), R(0.25, 0.3, 0.85, 0.3), L(0.25, 0.28, 0.85, 0.3), WR(-0.8), WL(-0.8), {"jaw": 0.9, "fp_r": -0.6}])))
	# 6,55 · la décharge la cueille : cambrée, bras et jambes projetés vers Lysia
	var blasted: Dictionary = M([{"plant": 0.0}, H(0, 0.04, -0.3), B(-0.55, 0.0), C(-0.35), HD(0.55, 0.0, 0.1),
		TL(0.7, 0.1), KL(0.6), TR(0.45, 0.12), KR(0.9), Rt(0.25, 0.4, 0.7, 0.5), Lt(0.25, 0.35, 0.75, 0.5), WR(0.5), WL(0.5),
		{"sq": 0.9, "jaw": 1.0, "face": "pain", "ev": "hurt", "curl": 0.0, "curl_l": 0.0, "fp_r": 0.0, "shake": 1.0}])
	k.append(K(L_PUSH, blasted, "h"))
	k.append(K(L_PUSH + 0.08, M([blasted, {"sq": 1.0}])))
	k.append(K(6.95, M([H(0, 0.0, -0.3), B(-0.7, 0.0, 0.1), HD(0.65, -0.2, 0.15), TL(1.0, 0.15), KL(0.5), TR(0.8, 0.15), KR(0.8), {"shake": 0.8}])))
	# 7,4 · elle s'écrase sur le dos ; les jambes rebondissent, l'électricité la secoue
	var down: Dictionary = M([{"plant": 0.0, "gsnap": 1.0}, H(0, 0.0, -0.45), {"body": V(1.5, -0.12, 0.0), "chest": V(-0.12, -0.12, -0.06), "head": V(-0.35, -0.75, -0.1)},
		TL(0.25, 0.12, 0.15), KL(0.35), TR(0.45, 0.15, -0.2), KR(0.7), {"l_arm": V(1.2, 0.0, -0.5), "r_arm": V(1.2, 0.0, 0.5)}, Lg(0.9, 0.1), Rg(0.95, -0.25),
		{"el_l": 0.7, "el_r": 0.6, "face": "dazed", "jaw": 0.35, "sq": 1.0, "curl": 0.35, "curl_l": 0.25}])
	k.append(K(LA_LAND, M([down, TL(0.85, 0.12, 0.15), KL(0.3), TR(1.0, 0.15, -0.2), KR(0.4), {"sq": 0.9, "ev": "hurt", "shake": 1.0}]), "s"))
	k.append(K(7.52, M([TL(1.05, 0.12, 0.15), KL(0.5), TR(1.25, 0.15, -0.2), KR(0.6), {"sq": 1.03}])))
	k.append(K(7.75, M([down, {"shake": 0.8}])))
	# les décharges qui restent : la main se crispe, la jambe tressaute
	for i: int in range(5):
		var t: float = 7.9 + 0.15 * float(i) + 0.03 * float(i % 2)
		k.append(K(t, M([{"shake": 0.9 - 0.15 * float(i), "curl_l": 0.9 if i % 2 == 0 else 0.25}, KR(0.7 + (0.25 if i % 2 == 1 else 0.0))]), "s"))
	k.append(K(8.6, M([{"shake": 0.2, "head": V(-0.38, -0.8, -0.12), "face": "dead"}])))
	c["fv_lysia_alice_rain"] = _film(3.3, 8.7, k, "menace")

	# PAPIER · cueillie par la décharge, cambrée, elle part en arrière au ralenti
	var ink: Array = []
	ink.append(K(0.0, M([_zero(), blasted, {"ev": "", "shake": 0.6}])))
	ink.append(K(1.3, M([B(-0.62), HD(0.6, 0.0, 0.12), TL(0.8, 0.12), KL(0.55), TR(0.55, 0.12), KR(0.85), Rt(0.28, 0.45, 0.68, 0.5), Lt(0.28, 0.4, 0.72, 0.5)])))
	ink.append(K(2.6, M([B(-0.68), HD(0.62, 0.0, 0.14), TL(0.9, 0.12), KL(0.5), TR(0.65, 0.12), KR(0.8), Rt(0.3, 0.5, 0.66, 0.5), Lt(0.3, 0.45, 0.7, 0.5)])))
	c["fv_lysia_alice_ink"] = _film(0.0, 2.7, ink, "pain")



# --------------------------------------------------------------------- ELLY --
# Soin, esquive, fusil. Un genou à terre, blessée, la main droite sur les
# côtes ; sur le glissando de harpe elle sort sa trousse et la plaque sur la
# plaie (3,5), respire sur le battement de cœur (3,75). Alice approche : Elly
# lève les yeux (4,4 → 4,55), se relève en poussant sur son genou. La griffe
# part (5,05) : elle plonge sous le coup (5,2), deux petits sauts en arrière sur
# les pizzicati, et décroche le fusil de son dos (5,45 → 5,75). Pompe sur les
# clics (5,8 · 5,93), BANG (6,15) : le recul lui fait reculer l'épaule. Elle
# souffle sur la fumée (7,38), cale le fusil sur l'épaule (7,6), tourne les
# talons ; un regard par-dessus l'épaule (8,4), un sourire.

const E_HEAL: float = 3.5
const E_RISE: float = 4.4
const E_DODGE: float = 5.2
const E_AIM: float = 5.75
const E_BANG: float = 6.15
const E_COOL: float = 7.15
const E_LEAVE: float = 7.85
const E_WALK: float = 7.98
const E_WALK_PERIOD: float = 0.47
const E_WALK_SPEED: float = 1.15
# Alice
const EA_WALK_SPEED: float = 1.25
const EA_WALK_END: float = 4.5
const EA_LUNGE: float = 5.05
const EA_LAND: float = 6.55


# visée au fusil, épaule droite : le buste se met de profil, la tête revient
# sur la mire. Les poignets reprennent l'orientation mesurée qui aligne le
# fusil du jeu avec le regard ; `pump` recule la main gauche sur la pompe.
static func _e_aim(pump: float = 0.0) -> Dictionary:
	return M([FL(0.05, 0.16), FR(0.08, -0.14), H(0, -0.08, 0.03), B(0.1, -0.6), C(0.05, -0.3), HD(-0.1, 0.86, -0.1),
		Rt(-0.43, 0.21, 0.39, 0.55), WR(-0.85, -0.06, 1.85), Lt(0.1, 0.17, 0.75 - pump, 0.0), WL(0.14, 1.82, -0.15),
		{"prop": "shotgun", "curl": 1.0, "curl_l": 0.8}])


static func _elly(c: Dictionary) -> void :
	var k: Array = []
	var leg: float = float(LEG.Elly)
	var kneel_h: float = (0.55 - 0.969) / leg
	# A · 3,3 · un genou (le gauche) à terre, la main droite plaquée sur les côtes
	var hurt: Dictionary = M([FR(0.06, 0.46), FL(0.1, -0.5), H(0, kneel_h, -0.02), B(0.28, 0.08, 0.06), C(0.18, 0.05), HD(-0.3, 0.1, 0.12),
		Rt(-0.38, -0.3, 0.22, 0.3), WR(0.6, 0.0, -0.3), L(0.3, -0.62, 0.3, 0.3), WL(0.3), {"fp_r": 0.0, "fp_l": -1.1, "curl": 0.5, "curl_l": 0.45}])
	k.append(K(3.3, M([_zero(), hurt, FACE("hurt")])))
	# 3,42 · la main gauche plonge dans la poche de la blouse, sort la trousse…
	k.append(K(3.38, M([Lt(-0.05, -0.42, 0.05, 0.4), WL(0.5), {"curl_l": 0.9}])))
	k.append(K(3.44, M([Lt(-0.15, -0.3, 0.35, 0.3), WL(-0.3), {"prop": "heal"}])))
	# 3,5 · … et la plaque sur la plaie ; la main droite s'écarte, le buste se plie
	k.append(K(E_HEAL, M([Lt(-0.34, -0.28, 0.22, 0.2), WL(-0.4, 0.3, 0.2), Rt(0.05, -0.45, 0.3, 0.3), WR(0.2), B(0.34, 0.1, 0.08), HD(-0.38, 0.12, 0.14), {"sq": 0.97, "face": "pain"}]), "s"))
	k.append(K(3.62, M([HD(-0.22, 0.08, 0.06), B(0.3, 0.08, 0.06), {"sq": 1.0, "face": "hurt"}])))
	# 3,75 · le battement de cœur : une grande inspiration, les yeux se ferment
	k.append(K(3.75, M([C(0.08, 0.05), SH(0.12, 0.12), HD(-0.1, 0.06, 0.0), {"face": "calm"}])))
	k.append(K(3.86, FACE("asleep")))
	k.append(K(4.05, M([C(0.2, 0.05), SH(-0.04, -0.04), HD(-0.26, 0.05, 0.06)])))
	k.append(K(4.12, FACE("calm")))
	# 4,15 → 4,35 · la trousse retourne dans la poche
	k.append(K(4.2, M([Lt(-0.1, -0.4, 0.08, 0.35), WL(0.4)])))
	k.append(K(4.3, M([Lt(0.05, -0.5, 0.0, 0.3), WL(0.4), {"prop": "", "curl_l": 0.5}])))
	# B · 4,4 · elle lève les yeux vers Alice, puis se relève en poussant sur son genou
	k.append(K(E_RISE, M([HD(-0.05, 0.0, 0.04), B(0.24, 0.04, 0.02), C(0.12), Rt(0.12, -0.55, 0.42, 0.3), WR(0.6), L(0.3, -0.6, 0.15, 0.3), {"face": "determined"}])))
	k.append(K(4.56, M([HD(0.12, 0.0, 0.02), B(0.3), {"curl": 0.8}])))
	k.append(K(4.7, M([H(0, kneel_h + 0.12, 0.04), B(0.38), C(0.15), FL(0.1, -0.42, 0.02), {"fp_l": -0.7}])))
	k.append(K(4.84, M([H(0, -0.18, 0.02), B(0.18), C(0.08), HD(0.1), FL(0.08, -0.22, 0.1), Rt(0.1, -0.5, 0.25, 0.3), {"fp_l": -0.3}])))
	k.append(K(4.95, M([FL(0.08, -0.12), FR(0.08, 0.2), H(0, -0.08, 0.0), B(0.05), C(0.03), HD(0.06), R(0.3, -0.7, 0.12, 0.25), L(0.3, -0.7, 0.12, 0.25),
		{"fp_l": 0.0, "fp_r": 0.0, "curl": 0.4, "curl_l": 0.4}]), "s"))
	# C · 5,05 · la griffe part : elle la voit venir…
	k.append(K(5.1, M([H(0, -0.12, -0.02), B(0.02, 0.0, 0.0), HD(0.12, 0.0, 0.0), SH(0.1, 0.1), {"face": "surprise"}])))
	# 5,2 · … et plonge dessous, sur le côté (le film la décale en l'air)
	var duck: Dictionary = M([FL(0.08, -0.05, 0.12), FR(0.1, 0.1, 0.16), H(0.1, -0.34, 0.02), B(0.55, 0.0, 0.35), C(0.2, 0.0, 0.1), HD(0.25, 0.2, 0.0),
		L(0.55, -0.2, 0.2, 0.5), R(0.6, -0.1, -0.1, 0.5), SH(0.0, 0.0), {"fp_l": 0.0, "fp_r": 0.0, "face": "determined", "ev": "gasp"}])
	k.append(K(E_DODGE, duck, "s"))
	k.append(K(5.33, M([FL(0.1, -0.02), FR(0.12, 0.16), H(0.05, -0.3, 0.0), B(0.35, 0.0, 0.15), C(0.12), HD(0.2, 0.15), {"sq": 0.95}]), "s"))
	# 5,38 → 5,54 · deux petits sauts en arrière (pizzicati), elle se redresse
	k.append(K(5.4, M([FL(0.08, 0.0, 0.08), FR(0.1, 0.12, 0.1), H(0, -0.12, -0.04), B(0.12, 0.0, 0.05), {"sq": 1.03}])))
	k.append(K(5.47, M([FL(0.08, 0.04), FR(0.1, 0.1), H(0, -0.16, 0.0), {"sq": 0.97}]), "s"))
	# 5,45 → 5,75 · la main droite décroche le fusil par-dessus l'épaule et
	# l'amène en arc devant elle ; la gauche vient chercher la pompe
	k.append(K(5.45, M([Rt(0.15, 0.62, -0.12, 0.6), WR(0.4, 0.0, 0.3), {"curl": 0.9}])))
	k.append(K(5.5, M([Rt(0.1, 0.65, -0.18, 0.6), {"prop": "shotgun"}])))
	k.append(K(5.54, M([FL(0.06, 0.12), FR(0.08, -0.08), H(0, -0.1, 0.02), B(0.1, -0.3), C(0.05, -0.15), HD(0.0, 0.45),
		Rt(-0.1, 0.45, 0.35, 0.55), WR(-0.5, -0.1, 1.2), Lt(0.2, 0.0, 0.55, 0.2), WL(0.1, 1.2, 0.0), {"sq": 1.0}]), "s"))
	k.append(K(5.66, M([B(0.1, -0.52), C(0.05, -0.26), HD(-0.05, 0.75, -0.06), Rt(-0.35, 0.25, 0.4, 0.55), WR(-0.8, -0.06, 1.7), Lt(0.12, 0.12, 0.72, 0.0), WL(0.14, 1.7, -0.1)])))
	# D · 5,75 · en joue ; la pompe sur les clics (5,8 en arrière, 5,93 en avant)
	k.append(K(E_AIM, _e_aim(), "s"))
	k.append(K(5.8, _e_aim(0.17), "s"))
	k.append(K(5.93, _e_aim(0.0), "s"))
	k.append(K(6.03, M([HD(-0.14, 0.86, -0.12), H(0, -0.09, 0.04)]), "s"))
	# E · 6,15 · BANG : l'épaule recule, le canon se relève, le buste encaisse
	var recoil: Dictionary = M([H(0, -0.06, -0.06), B(-0.08, -0.66), C(-0.12, -0.34), HD(0.12, 0.8, -0.06), Rt(-0.38, 0.3, 0.32, 0.55), WR(-1.0, -0.02, 1.62),
		Lt(0.06, 0.32, 0.72, 0.0), WL(0.12, 1.5, -0.4), FR(0.08, -0.22), {"fp_l": 0.3, "sq": 1.05, "fx": "muzzle", "ev": "grunt", "jaw": 0.2}])
	k.append(K(E_BANG, recoil, "s"))
	k.append(K(6.28, M([H(0, -0.08, -0.08), B(-0.12, -0.66), C(-0.12, -0.34), HD(0.18, 0.78, -0.04), WR(-0.95, 0.0, 1.55), {"sq": 1.0, "jaw": 0.0}]), "s"))
	# elle tient la visée, puis abaisse le canon et souffle
	k.append(K(6.55, M([_e_aim(0.0), H(0, -0.08, 0.0), B(0.05, -0.6), {"fp_l": 0.0}])))
	k.append(K(6.9, M([B(0.08, -0.5), C(0.06, -0.25), HD(-0.05, 0.7, -0.05), Rt(-0.3, 0.05, 0.35, 0.5), WR(-0.9, -0.2, 1.6), Lt(0.15, 0.0, 0.6, 0.1), {"face": "calm"}])))
	# F · 7,15 · la fumée : elle relève le canon devant son visage…
	k.append(K(E_COOL, M([B(0.0, -0.35), C(0.0, -0.15), HD(0.05, 0.3, 0.0), Rt(-0.05, 0.42, 0.25, 0.4), WR(-1.5, -0.3, 1.2), L(0.35, -0.65, 0.12, 0.3), WL(0.2, 0.0, 0.0),
		{"curl_l": 0.4, "face": "smile"}])))
	# … souffle dessus (7,38)…
	k.append(K(7.32, M([HD(0.1, 0.22, 0.05), {"jaw": 0.0}])))
	k.append(K(7.38, M([HD(0.14, 0.2, 0.05), {"jaw": 0.3}]), "s"))
	k.append(K(7.5, M([HD(0.08, 0.15, 0.08), {"jaw": 0.0}])))
	blink(7.46, "smile", k, 0.07)
	# … et le cale sur l'épaule (7,56 → 7,74)
	k.append(K(7.62, M([Rt(0.12, 0.72, 0.0, 0.5), WR(-1.2, 0.2, 0.4), B(0.0, -0.2), C(-0.02, -0.08), HD(0.06, 0.15, 0.06)])))
	k.append(K(7.74, M([Rt(0.18, 0.62, -0.12, 0.5), WR(-0.6, 0.3, 0.2), {"sq": 0.99}]), "s"))
	# G · 7,85 · elle tourne les talons (le film la fait pivoter) et s'en va
	var shoulder: Dictionary = M([Rt(0.18, 0.62, -0.12, 0.5), WR(-0.6, 0.3, 0.2), L(0.3, -0.72, 0.12, 0.25), WL(0.2), {"prop": "shotgun", "curl": 1.0, "curl_l": 0.35}])
	k.append(K(E_LEAVE, M([shoulder, B(0.04, 0.0), C(0.0), HD(0.0, 0.0, 0.04), FL(0.06, 0.05), FR(0.08, -0.04), H(0, -0.05, 0.0), {"fp_l": 0.0, "fp_r": 0.0, "sq": 1.0}])))
	var walk: Dictionary = {"stance": 0.56, "reach": 0.3, "kick": 0.12, "knee": 0.08, "strike": 0.18, "push": -0.35, "bob": 0.02, "up": 0.0, "hips": Vector3(0.0, -0.05, 0.0), "width": 0.04}
	# premier pas depuis l'arrêt : le pied gauche décolle pendant le demi-tour ;
	# le droit reste posé (il recule avec le corps qui démarre) puis repasse devant
	k.append(K(7.88, M([FL(0.06, 0.02, 0.08), {"fp_l": -0.2}])))
	k.append(K(7.93, M([FL(0.06, 0.2, 0.1), {"fp_l": 0.1}])))
	k.append(K(E_WALK, FR(0.08, -0.04), "l"))
	k.append(K(8.16, M([FR(0.08, -0.04 - E_WALK_SPEED * 0.18 / leg), {"fp_r": -0.35}])))
	k.append(K(8.26, M([FR(0.08, -0.15, 0.12), {"fp_r": -0.6}])))
	k.append(K(8.36, M([FR(0.08, 0.12, 0.09), {"fp_r": 0.1}])))
	_strides("Elly", k, E_WALK, 3, E_WALK_PERIOD, E_WALK_SPEED, true, walk)
	# le bras libre balance un peu, la blouse suit
	k.append(K(8.2, M([L(0.3, -0.72, -0.08, 0.25)])))
	k.append(K(8.68, M([L(0.3, -0.72, 0.18, 0.25)])))
	# 8,4 · un regard par-dessus l'épaule, vers Alice ; puis elle regarde devant elle
	k.append(K(8.3, M([HD(0.02, 0.5, 0.04), C(0.0, 0.12)])))
	k.append(K(8.42, M([HD(0.05, 0.95, 0.06), C(0.0, 0.25), {"face": "smile"}]), "s"))
	k.append(K(8.62, M([HD(0.04, 0.9, 0.06)])))
	k.append(K(8.76, M([HD(0.02, 0.05, 0.02), C(0.0, 0.0), {"face": "calm"}])))
	c["fv_elly_rain"] = _film(3.3, 9.0, k, "hurt")

	# PAPIER · le coup de feu figé : le recul, le canon qui se relève
	var ink: Array = []
	ink.append(K(0.0, M([_zero(), recoil, {"fx": "", "ev": "", "face": "determined"}])))
	ink.append(K(1.3, M([B(-0.1, -0.66), HD(0.14, 0.79, -0.05), WR(-1.02, -0.02, 1.6)])))
	ink.append(K(2.6, M([B(-0.12, -0.66), HD(0.16, 0.78, -0.04), WR(-1.05, -0.02, 1.58)])))
	c["fv_elly_ink"] = _film(0.0, 2.7, ink, "determined")

	_elly_alice(c)


static func _elly_alice(c: Dictionary) -> void :
	var k: Array = []
	# A · 3,3 → 4,6 · elle marche sur la blessée, sans se presser
	var prowl: Dictionary = M([H(0, -0.03, 0.0), B(0.1), C(0.18), HD(0.12, 0.0, 0.18),
		L(0.3, -0.8, 0.18, 0.25), R(0.36, -0.7, 0.32, 0.3), WL(-0.3), WR(-0.5), {"curl": 0.15, "curl_l": 0.3}])
	k.append(K(3.3, _no_feet(M([_zero(), prowl, FACE("menace")]))))
	var walk: Dictionary = {"stance": 0.66, "reach": 0.34, "kick": 0.1, "knee": 0.07, "strike": 0.16, "push": -0.32, "bob": 0.015, "up": 0.0, "hips": Vector3(0.0, -0.03, 0.0), "width": 0.03}
	_stride_in("Alice", k, 3.3, 3.4, 0.55, EA_WALK_SPEED, true, walk)
	_strides("Alice", k, 3.4, 3, 0.55, EA_WALK_SPEED, true, walk)
	k.append(K(3.9, M([HD(0.08, 0.04, 0.24), {"curl": 0.35}])))
	k.append(K(4.35, M([HD(0.14, -0.03, 0.14), {"curl": 0.1}])))
	# 4,6 → 5,0 · elle s'arrête au-dessus d'elle, arme la griffe droite haut
	k.append(K(4.6, M([FL(0.05, 0.1), FR(0.06, -0.08), H(0, -0.03, 0.0), {"fp_l": 0.0, "fp_r": 0.0}])))
	k.append(K(4.85, M([B(-0.05, -0.15), C(-0.05, -0.2), HD(0.05, 0.1, 0.1), R(0.45, 0.85, -0.25, 0.8), WR(-0.8), {"curl": 0.0, "jaw": 0.3, "face": "grin"}])))
	k.append(K(5.0, M([B(-0.1, -0.25), C(-0.1, -0.28), HD(0.08, 0.15, 0.05), R(0.5, 0.95, -0.35, 0.8), {"jaw": 0.6, "face": "angry"}]), "s"))
	# C · 5,05 · le pas et la griffe qui fauche (5,2)… dans le vide
	k.append(K(5.12, M([FL(0.05, 0.38, 0.08), H(0, -0.06, 0.12), B(0.2, 0.2), C(0.15, 0.25), R(0.35, 0.4, 0.55, 0.5), {"jaw": 0.9}])))
	k.append(K(E_DODGE, M([FL(0.05, 0.5), H(0, -0.16, 0.25), B(0.5, 0.55), C(0.3, 0.4), HD(-0.1, 0.3), R(0.05, -0.2, 0.85, 0.3), WR(0.5), {"ev": "roar", "fx": "trail_r", "fp_l": 0.0}]), "s"))
	# l'élan l'emporte : un pas pour se rattraper, le corps qui tourne
	k.append(K(5.36, M([FR(0.06, 0.25, 0.1), H(0, -0.12, 0.2), B(0.35, 0.65), C(0.2, 0.35), HD(0.1, -0.2, 0.1), R(0.3, -0.3, 0.4, 0.4), {"face": "surprise", "jaw": 0.4, "fp_r": -0.3}])))
	k.append(K(5.46, M([FR(0.06, 0.32), H(0, -0.1, 0.18), {"fp_r": 0.0, "sq": 0.97}]), "s"))
	# 5,5 → 6,1 · elle se retourne vers Elly, gronde et revient
	k.append(K(5.7, M([B(0.15, 0.15), C(0.1, 0.1), HD(0.05, 0.25, 0.0), R(0.45, 0.2, 0.35, 0.6), L(0.4, 0.1, 0.35, 0.6), WR(-0.6), WL(-0.6), {"face": "angry", "jaw": 0.7, "curl": 0.0, "curl_l": 0.0}])))
	k.append(K(5.95, M([FL(0.05, 0.3, 0.1), H(0, -0.08, 0.1), B(0.3, 0.0), C(0.15), HD(-0.1, 0.0), R(0.4, 0.45, 0.4, 0.7), L(0.4, 0.4, 0.42, 0.7), {"jaw": 0.9}])))
	k.append(K(6.08, M([FL(0.05, 0.42), H(0, -0.1, 0.15), {"fp_l": 0.0}]), "s"))
	# 6,15 · la décharge du fusil : bras jetés en l'air, elle décolle en arrière
	var shot: Dictionary = M([{"plant": 0.0}, H(0, 0.05, -0.3), B(-0.5, 0.0, 0.1), C(-0.3), HD(0.6, 0.1, 0.15),
		TL(0.6, 0.12), KL(0.5), TR(0.35, 0.12), KR(0.8), R(0.75, 0.6, 0.25, 0.8), L(0.7, 0.65, 0.2, 0.8), WR(0.4), WL(0.4),
		{"sq": 0.9, "jaw": 1.0, "face": "pain", "ev": "hurt", "curl": 0.0, "curl_l": 0.0}])
	k.append(K(E_BANG, shot, "h"))
	k.append(K(E_BANG + 0.08, M([shot, {"sq": 1.0}])))
	k.append(K(6.4, M([H(0, 0.0, -0.32), B(-0.65, 0.0, 0.12), HD(0.65, -0.1, 0.12), TL(0.95, 0.15), KL(0.4), TR(0.75, 0.15), KR(0.6)])))
	# 6,55 · sur le dos, les jambes rebondissent
	var down: Dictionary = M([{"plant": 0.0, "gsnap": 1.0}, H(0, 0.0, -0.45), {"body": V(1.5, 0.12, 0.0), "chest": V(-0.12, 0.12, 0.06), "head": V(-0.3, 0.7, 0.1)},
		TL(0.4, 0.12, -0.15), KL(0.6), TR(0.2, 0.12, 0.15), KR(0.35), {"l_arm": V(1.2, 0.0, -0.5), "r_arm": V(1.2, 0.0, 0.5)}, Lg(0.95, -0.2), Rg(0.9, 0.15),
		{"el_l": 0.6, "el_r": 0.7, "face": "dazed", "jaw": 0.4, "sq": 1.0, "curl": 0.3, "curl_l": 0.3}])
	k.append(K(EA_LAND, M([down, TL(1.0, 0.12, -0.15), KL(0.4), TR(0.8, 0.12, 0.15), KR(0.3), {"sq": 0.9, "ev": "hurt"}]), "s"))
	k.append(K(6.68, M([TL(1.2, 0.12, -0.15), KL(0.6), TR(1.05, 0.12, 0.15), KR(0.5), {"sq": 1.03}])))
	k.append(K(6.9, down))
	# 7,9 · elle relève la tête… qui retombe (8,35)
	k.append(K(7.85, M([{"head": V(-0.3, 0.7, 0.1)}])))
	k.append(K(8.05, M([{"head": V(0.25, 0.3, 0.05), "chest": V(0.15, 0.1, 0.05)}, {"face": "angry", "jaw": 0.2}])))
	k.append(K(8.22, M([{"head": V(0.28, 0.25, 0.05)}])))
	k.append(K(8.36, M([{"head": V(-0.35, 0.75, 0.12), "chest": V(-0.12, 0.12, 0.06)}, {"face": "dead", "jaw": 0.35}]), "s"))
	k.append(K(8.46, M([{"head": V(-0.28, 0.72, 0.1)}])))
	c["fv_elly_alice_rain"] = _film(3.3, 9.0, k, "menace")

	# PAPIER · cueillie par la décharge, elle part en arrière
	var ink: Array = []
	ink.append(K(0.0, M([_zero(), shot, {"ev": ""}])))
	ink.append(K(1.3, M([B(-0.56, 0.0, 0.12), HD(0.62, 0.1, 0.16), TL(0.7, 0.12), KL(0.45), TR(0.45, 0.12), KR(0.75), R(0.8, 0.66, 0.24, 0.8), L(0.75, 0.7, 0.18, 0.8)])))
	ink.append(K(2.6, M([B(-0.62, 0.0, 0.14), HD(0.64, 0.1, 0.18), TL(0.8, 0.12), KL(0.42), TR(0.55, 0.12), KR(0.7), R(0.84, 0.7, 0.22, 0.8), L(0.8, 0.74, 0.16, 0.8)])))
	c["fv_elly_alice_ink"] = _film(0.0, 2.7, ink, "pain")



# ----------------------------------------------------------------- BLEUETTE --
# Chocolat, courage, sprint. Alice approche ; Bleuette serre sa tablette contre
# elle, toute tremblante, et sursaute à chaque battement de cœur (3,4 · 3,72 ·
# 4,0). Elle baisse les yeux sur le chocolat (4,05), croque trois fois sur les
# croquements du célesta (4,22 · 4,3 · 4,37), ferme les yeux et avale (4,6) ;
# ses yeux se rouvrent sur Alice (4,95). Elle range la tablette, se redresse sur
# la montée des cordes (5,3 → 5,61), serre les poings sur le Mi majeur (5,65)
# et se ramasse sur les trompettes (5,8 · 5,95). Alice frappe (6,45) : Bleuette
# est déjà sous son bras, au sprint, un appui toutes les 0,1025 s (un sur deux
# sur les pizzicati). Elle dérape (7,27), se retourne, les mains sur la bouche
# (7,62), puis lève le poing en sautillant sur la marche (8,09 · 8,3).
# Alice : trois pas lents, penchée sur elle, la griffe levée ; interdite devant
# le chocolat (4,72) ; repoussée par l'élan de courage (5,65) ; elle arme et
# fauche le vide (6,45), se retourne d'un bond (6,62), se lance après elle, se
# prend les pieds dans sa robe (6,9) et s'étale à plat ventre dans une flaque
# (7,27, sifflet à coulisse). Elle relève la tête, ruisselante (7,8), glisse et
# retombe le nez dans l'eau (8,12), tape l'eau de rage (8,3 · 8,5).

const B_LOOK: float = 4.05
const B_GULP: float = 4.6
const B_OPEN: float = 4.95
const B_RISE: float = 5.3
const B_BRAVE: float = 5.65
const B_SET: float = 5.95
const B_GO: float = 6.38
const B_FIRST: float = 6.45
const B_STEP: float = 0.1025
const B_RUN_SPEED: float = 6.4
const B_SKID: float = 7.27
const B_SKID_END: float = 7.49
const B_TURN: float = 7.44
const B_OOPS: float = 7.62
const B_PUMP: float = 8.09
# Alice
const BA_WALK_SPEED: float = 1.0
const BA_WALK_END: float = 4.4
const BA_SWIPE: float = 6.45
const BA_LUNGE: float = 0.45
const BA_WHIRL: float = 6.62
const BA_PUSH: float = 6.8
const BA_TRIP: float = 6.9
const BA_LAND: float = 7.27


# retire des clés générées (foulées) les canaux donnés après `after` : la fin
# d'un déplacement, écrite à la main, reprend ces canaux
static func _drop_after(keys: Array, channels: Array, after: float) -> void :
	for key: Array in keys:
		if float(key[0]) <= after: continue
		for channel: Variant in channels: (key[1] as Dictionary).erase(channel)


# toute petite : pieds serrés, épaules remontées, la tablette serrée contre elle
static func _b_fear() -> Dictionary:
	return M([FL(-0.01, 0.04), FR(0.03, -0.1, 0.02), H(0, -0.07, -0.02), B(0.16), C(0.12), HD(-0.05, 0.0, 0.1),
		Rt(-0.28, -0.1, 0.5, 0.3), WR(0.3, 0.0, 0.2), Lt(-0.25, -0.3, 0.48, 0.1), WL(0.2), SH(0.3, 0.3, 0.12, 0.12),
		{"fp_l": 0.0, "fp_r": -0.4, "curl": 0.9, "curl_l": 1.0, "prop": "chocolate", "shake": 0.6}])


# course : buste en avant, tête relevée, la bouche ouverte
static func _b_run() -> Dictionary:
	return M([B(0.44), C(0.1), HD(0.5), SH(0.0, 0.0), {"curl": 0.75, "curl_l": 0.75, "face": "determined", "jaw": 0.25, "shake": 0.0}])


# bras de course, opposés aux jambes : `right_fwd` quand le pied gauche se pose
static func _b_arms(right_fwd: bool, amount: float = 1.0) -> Dictionary:
	var front: Vector3 = Vector3(-0.04, -0.22, 0.58) * Vector3(1.0, 1.0, amount)
	var back: Vector3 = Vector3(0.14, -0.72, -0.46 * amount)
	var fr: Vector3 = front if right_fwd else back
	var fl: Vector3 = back if right_fwd else front
	return M([Rt(fr.x, fr.y, fr.z, 0.25), Lt(fl.x, fl.y, fl.z, 0.25), WR(0.3 if right_fwd else -0.2), WL(-0.2 if right_fwd else 0.3),
		C(0.1, 0.1 if right_fwd else -0.1)])


static func _bleuette(c: Dictionary) -> void :
	var k: Array = []
	var leg: float = float(LEG.Bleuette)
	# A · 3,3 → 4,05 · elle tremble, la tablette contre elle ; chaque battement
	# de cœur la fait sursauter, elle recule d'un demi-pas
	k.append(K(3.3, M([_zero(), _b_fear(), FACE("fear")])))
	k.append(K(3.37, M([SH(0.3, 0.3, 0.12, 0.12), HD(-0.05, 0.0, 0.1), H(0, -0.07, -0.02), {"sq": 1.0}])))
	k.append(K(3.43, M([SH(0.44, 0.44, 0.16, 0.16), HD(-0.14, 0.0, 0.05), H(0, -0.09, -0.03), {"sq": 0.97}]), "s"))
	k.append(K(3.55, M([SH(0.32, 0.32, 0.12, 0.12), HD(-0.04, 0.0, 0.12), H(0, -0.07, -0.02), {"sq": 1.0}])))
	k.append(K(3.6, M([FR(0.03, -0.18, 0.05), {"fp_r": -0.5}])))
	k.append(K(3.68, M([FR(0.04, -0.26), H(0, -0.07, -0.06), {"fp_r": -0.3}]), "s"))
	k.append(K(3.7, M([SH(0.3, 0.3, 0.12, 0.12), HD(-0.05, 0.0, 0.1), {"sq": 1.0}])))
	k.append(K(3.75, M([SH(0.46, 0.46, 0.16, 0.16), HD(-0.13, 0.04, 0.06), H(0, -0.09, -0.07), {"sq": 0.97}]), "s"))
	# 3,82 · elle lève les yeux vers Alice
	k.append(K(3.84, M([SH(0.3, 0.3, 0.12, 0.12), HD(0.08, 0.0, 0.14), H(0, -0.07, -0.06), {"sq": 1.0}])))
	blink(3.9, "fear", k, 0.06)
	k.append(K(3.98, M([SH(0.3, 0.3, 0.12, 0.12), HD(0.07, 0.0, 0.12), {"sq": 1.0}])))
	k.append(K(4.03, M([SH(0.42, 0.42, 0.15, 0.15), HD(0.0, 0.0, 0.1), {"sq": 0.97}]), "s"))
	# B · 4,05 · … puis sur le chocolat. Elle le porte à sa bouche
	k.append(K(B_LOOK + 0.05, M([SH(0.3, 0.3, 0.1, 0.1), HD(-0.32, 0.0, 0.05), Rt(-0.28, -0.02, 0.55, 0.35), WR(0.1, 0.0, 0.2), {"sq": 1.0, "shake": 0.45}])))
	k.append(K(4.15, M([HD(-0.16, 0.0, 0.04), R(-0.3, 0.05, 0.66, 0.45), WR(0.0), {"jaw": 0.5}])))
	k.append(K(4.19, M([HD(-0.1, 0.0, 0.03), R(-0.3, 0.1, 0.72, 0.5), {"jaw": 0.6}])))
	# trois coups de dents, sur les croquements du célesta
	var chomp: Array = [[4.22, 0.97, true], [4.3, 0.98, false], [4.37, 0.97, true]]
	for bite: Array in chomp:
		var t: float = float(bite[0])
		var pose: Dictionary = M([HD(-0.15, 0.0, 0.03), R(-0.31, 0.1, 0.65, 0.5), {"jaw": 0.0, "sq": float(bite[1])}])
		if bool(bite[2]): pose["fx"] = "crumbs"
		k.append(K(t, pose, "s"))
		if t < 4.35: k.append(K(t + 0.04, M([HD(-0.1, 0.0, 0.03), R(-0.3, 0.1, 0.71, 0.5), {"jaw": 0.45, "sq": 1.0}])))
	# 4,45 · la tablette redescend ; les yeux fermés, elle mâche, la peur s'en va
	k.append(K(4.45, M([HD(-0.08, 0.0, 0.08), Rt(-0.28, -0.14, 0.5, 0.3), WR(0.3, 0.0, 0.2), SH(0.14, 0.14, 0.05, 0.05), {"face": "asleep", "jaw": 0.15, "sq": 1.0, "shake": 0.2}])))
	k.append(K(4.5, {"jaw": 0.0}))
	k.append(K(4.54, {"jaw": 0.12}))
	k.append(K(4.58, {"jaw": 0.0}))
	# 4,6 · elle avale
	k.append(K(B_GULP, M([HD(-0.18, 0.0, 0.04), C(0.16), {"sq": 0.98}]), "s"))
	k.append(K(4.72, M([HD(0.0, 0.0, 0.12), C(0.1), SH(0.04, 0.04), {"face": "smile", "sq": 1.0, "shake": 0.04}])))
	k.append(K(4.86, M([C(0.06), SH(0.1, 0.1), HD(0.03, 0.0, 0.1)])))
	# 4,95 · les yeux se rouvrent sur Alice
	k.append(K(B_OPEN, M([HD(0.2, 0.0, 0.0), C(0.08), SH(0.05, 0.05), {"face": "determined", "shake": 0.0}]), "s"))
	# 5,0 → 5,2 · la tablette retourne dans sa poche
	k.append(K(5.04, M([Rt(-0.05, -0.5, 0.3, 0.3), WR(0.2)])))
	k.append(K(5.12, M([R(0.14, -0.86, 0.06, 0.25), WR(0.3), L(0.24, -0.78, 0.14, 0.2), WL(0.0), {"curl_l": 0.6}])))
	k.append(K(5.15, {"prop": ""}))
	k.append(K(5.22, M([R(0.2, -0.8, 0.1, 0.25), {"curl": 0.5}])))
	# C · 5,3 → 5,61 · elle se redresse sur la montée des cordes, le pied droit
	# avance, les poings se serrent sous son menton
	k.append(K(B_RISE, M([H(0, -0.07, -0.06), B(0.14), C(0.08), HD(0.2)])))
	k.append(K(5.36, M([FR(0.04, -0.12, 0.05), {"fp_r": -0.4}])))
	k.append(K(5.44, M([FR(0.06, 0.1), {"fp_r": 0.0}]), "s"))
	k.append(K(5.46, M([H(0, -0.04, 0.0), B(0.04), C(-0.02), HD(0.24), Rt(-0.22, -0.2, 0.42, 0.3), Lt(-0.22, -0.22, 0.42, 0.3), WR(0.3), WL(0.3), {"curl": 1.0, "curl_l": 1.0}])))
	k.append(K(5.6, M([H(0, 0.0, 0.02), B(-0.06), C(-0.12), HD(0.3), Rt(-0.2, -0.06, 0.45, 0.3), Lt(-0.2, -0.08, 0.45, 0.3), SH(0.16, 0.16)])))
	# 5,65 · Mi majeur : elle tape du pied et tire les poings vers le bas,
	# « j'peux le faire »
	k.append(K(5.62, M([FR(0.08, 0.16, 0.05), H(0, 0.02, 0.02), {"sq": 1.02, "fp_r": -0.2}])))
	var brave: Dictionary = M([FR(0.11, 0.24), FL(0.06, -0.1), H(0, -0.06, 0.04), B(-0.04), C(-0.2), HD(0.32), SH(-0.06, -0.06),
		R(0.24, -0.55, -0.12, 0.45), L(0.24, -0.55, -0.12, 0.45), WR(0.4), WL(0.4), {"fp_r": 0.0, "fp_l": 0.0, "sq": 0.95, "jaw": 0.5, "fx": "flex", "ev": "effort"}])
	k.append(K(B_BRAVE, brave, "s"))
	k.append(K(5.72, M([C(-0.16), HD(0.3), {"sq": 1.0, "jaw": 0.2}])))
	# 5,8 · elle se ramasse : le pied gauche glisse en arrière, les bras s'arment
	k.append(K(5.8, M([FL(0.07, -0.3, 0.02), H(0, -0.16, 0.04), B(0.3), C(0.04), HD(0.5), L(0.18, -0.5, 0.4, 0.25), R(0.25, -0.62, -0.32, 0.3), WR(0.0), WL(0.0),
		{"fp_l": -0.5, "jaw": 0.0}])))
	k.append(K(B_SET, M([FL(0.07, -0.32), H(0, -0.22, 0.07), B(0.42), C(0.08), HD(0.62), {"shake": 0.12}]), "s"))
	k.append(K(6.25, M([H(0, -0.25, 0.08), HD(0.66), {"shake": 0.2}])))
	# D · 6,38 · parti : le pied gauche pousse et passe devant (appui à 6,45) ;
	# le droit, posé, recule avec le corps qui démarre, puis repart
	var lane0: float = 0.28
	var launch: float = B_RUN_SPEED * (B_FIRST - B_GO) * 0.5
	k.append(K(B_GO, M([_b_run(), H(0, -0.2, 0.22), FR(0.11, lane0), FL(0.07, -0.34, 0.02), _b_arms(true, 1.15), {"fp_l": -0.85, "fp_r": 0.0}])))
	k.append(K(6.41, M([FL(0.06, -0.1, 0.24), {"fp_l": -0.4}])))
	k.append(K(B_FIRST, M([FR(0.1, lane0 - launch / leg), {"fp_r": -0.2}]), "l"))
	k.append(K(6.47, M([FR(0.08, lane0 - launch / leg - 0.08, 0.04), {"fp_r": -0.75}])))
	k.append(K(6.51, M([FR(0.05, 0.06, 0.32), {"fp_r": -0.35}])))
	var run: Dictionary = {"stance": 0.0615, "reach": 0.3, "kick": 0.5, "knee": 0.36, "hips": Vector3(0.0, -0.1, 0.18), "bob": 0.05, "up": 0.03, "push": -0.6, "width": 0.04}
	var strides: Array = []
	_strides("Bleuette", strides, B_FIRST, 8, B_STEP, B_RUN_SPEED, true, run)
	k.append_array(strides)
	for i: int in range(8):
		var t: float = B_FIRST + B_STEP * float(i)
		k.append(K(t + 0.015, _b_arms(i % 2 == 0, 1.0 + 0.08 * sin(1.9 * float(i)))))
	k.append(K(6.6, M([HD(0.46), B(0.42)])))
	k.append(K(6.95, M([HD(0.5), B(0.45)])))
	# le dernier appui droit (7,17) recule jusqu'à l'envol, puis traîne derrière
	var last_r: float = B_FIRST + B_STEP * 7.0
	k.append(K(last_r + 0.062, M([FR(0.05, - (B_RUN_SPEED * 0.062 - 0.3) / leg, 0.03), {"fp_r": -0.55}])))
	# E · 7,27 · dérapage sur l'eau : talon gauche devant, bras en moulinet
	var skid: Dictionary = M([FL(0.06, 0.62), FR(0.08, -0.3, 0.03), H(0, -0.22, -0.15), B(-0.12), C(-0.06), HD(0.2),
		L(0.85, 0.25, 0.3, 0.3), R(0.9, 0.0, -0.1, 0.3), WR(0.0), WL(0.0), {"fp_l": 0.35, "fp_r": -0.6, "curl": 0.25, "curl_l": 0.25, "face": "surprise", "jaw": 0.35, "fx": "skid", "sq": 0.96}])
	k.append(K(7.22, M([H(0, -0.14, 0.0), B(0.2)])))
	k.append(K(B_SKID, skid, "s"))
	k.append(K(7.36, M([L(0.9, -0.05, 0.15, 0.3), R(0.85, 0.35, 0.25, 0.3), B(-0.16), {"sq": 1.0}])))
	k.append(K(7.45, M([L(0.72, 0.18, 0.2, 0.3), R(0.78, 0.05, 0.1, 0.3), B(-0.05), H(0, -0.12, -0.08)])))
	k.append(K(B_SKID_END, M([FL(0.06, 0.4), FR(0.06, -0.15), {"fp_l": 0.0, "fp_r": -0.3}]), "s"))
	# 7,44 → 7,6 · elle se retourne (le film la fait pivoter) en deux petits pas
	k.append(K(7.52, M([FR(0.06, 0.0, 0.07), H(0, -0.08, 0.0), B(0.02), {"fp_r": -0.2}])))
	k.append(K(7.56, M([FL(0.05, 0.3, 0.05), {"fp_l": -0.2}])))
	k.append(K(7.58, M([FR(0.07, 0.04), {"fp_r": 0.0}]), "s"))
	k.append(K(7.63, M([FL(0.05, 0.1), {"fp_l": 0.0}]), "s"))
	# 7,62 · elle la voit dans la flaque : les mains sur la bouche
	k.append(K(7.57, M([R(-0.2, -0.2, 0.5, 0.4), L(-0.2, -0.24, 0.5, 0.4), {"curl": 0.5, "curl_l": 0.5}])))
	var oops: Dictionary = M([H(0, -0.06, -0.03), B(-0.06), C(-0.02), HD(0.0, 0.0, 0.0), SH(0.3, 0.3, 0.1, 0.1), R(-0.32, 0.12, 0.62, 0.5), L(-0.32, 0.08, 0.6, 0.5),
		WR(0.2), WL(0.2), {"curl": 0.6, "curl_l": 0.6, "face": "surprise", "jaw": 0.3, "sq": 0.97}])
	k.append(K(B_OOPS, oops, "s"))
	k.append(K(7.75, M([HD(-0.04, 0.0, 0.16), {"sq": 1.0, "jaw": 0.1}])))
	blink(7.82, "surprise", k, 0.06)
	# 7,885 · un petit sourire derrière ses doigts…
	k.append(K(7.9, M([Rt(-0.3, 0.0, 0.5, 0.4), Lt(-0.3, -0.06, 0.48, 0.4), SH(0.15, 0.15), HD(0.02, 0.0, 0.1), {"face": "smile", "jaw": 0.0}])))
	# … elle arme le poing et saute sur la grosse caisse (8,09)
	k.append(K(8.01, M([H(0, -0.13, 0.0), Rt(0.12, 0.3, 0.28, 0.5), WR(0.4), Lt(-0.28, -0.15, 0.45, 0.3), {"curl": 1.0, "curl_l": 1.0, "sq": 0.97}])))
	var pump: Dictionary = M([H(0, 0.06, 0.0), FL(0.05, 0.1, 0.06), FR(0.07, 0.04, 0.08), B(-0.06), C(-0.1), HD(0.15, 0.0, -0.1), R(0.15, -0.5, 0.22, 0.4), WR(0.0),
		{"fp_l": -0.4, "fp_r": -0.4, "face": "laugh", "sq": 1.04, "fx": "cheer"}])
	k.append(K(B_PUMP, pump, "s"))
	k.append(K(8.18, M([H(0, -0.1, 0.0), FL(0.05, 0.1), FR(0.07, 0.04), {"fp_l": 0.0, "fp_r": 0.0, "sq": 0.95}]), "s"))
	k.append(K(8.26, M([H(0, -0.03, 0.0), {"sq": 1.0}])))
	k.append(K(8.31, M([H(0, 0.03, 0.0), R(0.15, -0.42, 0.25, 0.4), {"fp_l": -0.45, "fp_r": -0.45}])))
	k.append(K(8.39, M([H(0, -0.05, 0.0), {"fp_l": 0.0, "fp_r": 0.0}]), "s"))
	# 8,5 · les deux poings contre elle, toute fière
	k.append(K(8.5, M([H(0, -0.04, 0.0), B(0.0), C(-0.04), Rt(-0.28, -0.12, 0.45, 0.3), Lt(-0.28, -0.15, 0.45, 0.3), WR(0.3), WL(0.3), SH(0.2, 0.2), HD(0.08, 0.0, 0.18), {"face": "smile"}])))
	k.append(K(8.75, M([HD(0.1, 0.0, 0.2), SH(0.16, 0.16)])))
	c["fv_bleuette_rain"] = _film(3.3, 8.8, k, "fear")

	# PAPIER · la foulée au ralenti, cheveux au vent
	var ink: Array = []
	ink.append(K(0.0, M([_zero(), _b_run(), H(0, -0.08, 0.18), _b_arms(true, 1.2), {"face": "laugh"}])))
	var slow: Dictionary = {"stance": 0.7, "reach": 0.28, "kick": 0.55, "knee": 0.4, "hips": Vector3(0.0, -0.08, 0.18), "bob": 0.05, "up": 0.03, "push": -0.65}
	_strides("Bleuette", ink, 0.05, 3, 1.25, 0.55, true, slow)
	ink.append(K(1.3, _b_arms(false, 1.2)))
	ink.append(K(2.55, _b_arms(true, 1.2)))
	c["fv_bleuette_ink"] = _film(0.0, 2.7, ink, "laugh")

	_bleuette_alice(c)


static func _bleuette_alice(c: Dictionary) -> void :
	var k: Array = []
	var leg: float = float(LEG.Alice)
	# A · 3,3 → 4,4 · trois pas lents vers elle, la griffe qui pend
	var prowl: Dictionary = M([H(0, -0.03, 0.0), B(0.1), C(0.2), HD(0.06, 0.0, 0.18),
		L(0.32, -0.8, 0.12, 0.25), R(0.38, -0.66, 0.3, 0.35), WL(-0.3), WR(-0.6), {"curl": 0.2, "curl_l": 0.3}])
	k.append(K(3.3, _no_feet(M([_zero(), prowl, FACE("menace")]))))
	var walk: Dictionary = {"stance": 0.62, "reach": 0.32, "kick": 0.1, "knee": 0.07, "strike": 0.16, "push": -0.32, "bob": 0.015, "up": 0.0, "hips": Vector3(0.0, -0.03, 0.0), "width": 0.03}
	var steps: Array = []
	_stride_in("Alice", steps, 3.3, 3.4, 0.5, BA_WALK_SPEED, true, walk)
	_strides("Alice", steps, 3.4, 3, 0.5, BA_WALK_SPEED, true, walk)
	_drop_after(steps, ["foot_r", "fp_r"], BA_WALK_END - 0.01)
	k.append_array(steps)
	# elle s'arrête au-dessus d'elle : le pied droit recule jusqu'à l'arrêt, puis
	# vient se poser derrière le gauche
	k.append(K(BA_WALK_END, {"foot_r": Vector3(0.03, 0.0, (0.5 * BA_WALK_SPEED - 0.32) / leg), "fp_r": -0.2}, "l"))
	k.append(K(4.47, M([FR(0.05, 0.05, 0.06), {"fp_r": -0.35}])))
	k.append(K(4.56, M([FR(0.05, 0.18), H(0, -0.05, 0.12), {"fp_r": 0.0}]), "s"))
	# 4,35 → 4,6 · penchée sur elle, la griffe monte à côté de son visage
	k.append(K(4.35, M([B(0.2), C(0.3), HD(-0.1, 0.0, 0.26), R(0.42, 0.2, 0.25, 0.6), WR(-0.7), {"curl": 0.05, "face": "grin"}])))
	k.append(K(4.6, M([B(0.26), C(0.36), HD(-0.2, 0.04, 0.3), R(0.46, 0.48, 0.12, 0.7), WR(-0.9), L(0.34, -0.78, 0.1, 0.25)])))
	# 4,72 · … elle mange ?! La tête penche de l'autre côté, la griffe reste en l'air
	k.append(K(4.74, M([HD(-0.14, -0.04, -0.3), C(0.32), {"face": "surprise"}])))
	blink(4.86, "surprise", k)
	# 5,0 · agacée : elle gronde, la griffe monte encore
	k.append(K(5.04, M([HD(-0.08, 0.0, 0.05), B(0.18), C(0.26), R(0.48, 0.82, -0.05, 0.8), WR(-1.0), {"face": "angry", "jaw": 0.35}])))
	k.append(K(5.3, M([HD(-0.06, 0.0, 0.08), R(0.5, 0.88, -0.1, 0.8), {"jaw": 0.2}])))
	# 5,4 · Bleuette se redresse : Alice relève la tête, méfiante
	k.append(K(5.5, M([B(0.1), C(0.18), HD(0.04, 0.0, 0.04), {"jaw": 0.1, "face": "menace"}])))
	# 5,65 · l'élan de courage la repousse : bras devant le visage, un pas en arrière
	k.append(K(5.62, M([FR(0.05, 0.12, 0.07), {"fp_r": -0.4}])))
	var flinch: Dictionary = M([FR(0.06, -0.22), H(0, -0.07, -0.08), B(-0.24, -0.25), C(-0.14, -0.15), HD(0.12, -0.45, -0.12),
		Lt(-0.28, 0.3, 0.42, 0.3), WL(0.7, 0.3), R(0.65, 0.3, -0.2, 0.7), WR(-0.4), {"fp_r": 0.0, "face": "pain", "jaw": 0.3, "curl_l": 0.4, "sq": 0.97}])
	k.append(K(5.71, flinch, "s"))
	k.append(K(5.82, M([B(-0.2, -0.22), HD(0.1, -0.38, -0.1), {"sq": 1.0}])))
	# 5,95 → 6,38 · furieuse : elle revient d'un pas et arme la griffe très haut
	k.append(K(5.98, M([B(-0.05, -0.1), C(0.05, -0.08), HD(0.06, -0.12, 0.0), Lt(-0.1, 0.0, 0.32, 0.3), WL(0.2), {"face": "angry", "jaw": 0.5}])))
	k.append(K(6.05, M([FR(0.05, 0.0, 0.07), {"fp_r": -0.35}])))
	k.append(K(6.14, M([FR(0.05, 0.2), H(0, -0.06, 0.04), {"fp_r": 0.0}]), "s"))
	var cocked: Dictionary = M([H(0, -0.1, -0.08), B(-0.14, -0.45), C(-0.1, -0.35), HD(0.0, 0.32, 0.12), R(0.38, 1.0, -0.45, 0.9), WR(-1.15), L(0.4, -0.05, 0.55, 0.4), WL(-0.4),
		{"curl": 0.0, "curl_l": 0.15, "jaw": 0.9, "ev": "roar", "face": "angry"}])
	k.append(K(6.3, cocked, "s"))
	k.append(K(6.38, M([R(0.4, 1.04, -0.5, 0.9), {"jaw": 1.0}])))
	# 6,45 · elle fauche… le vide. Une fente du pied droit ; le film l'avance de
	# BA_LUNGE m (6,4 → 6,55, « dash ») : le pied gauche, posé, recule d'autant
	var at_swipe: float = BA_LUNGE * (1.0 - pow(1.0 - (BA_SWIPE - 6.4) / 0.15, 3.0))
	k.append(K(6.4, M([FL(0.03, 0.37), FR(0.05, 0.36, 0.1), {"fp_r": -0.3, "fp_l": 0.0}])))
	k.append(K(6.42, M([R(0.35, 0.45, 0.45, 0.6), WR(-0.6), B(0.15, 0.0), C(0.05, 0.0), {"fx": "trail_r"}])))
	var swipe: Dictionary = M([FL(0.03, 0.37 - at_swipe / leg), FR(0.05, 0.85), H(0, -0.28, 0.25), B(0.45, 0.5), C(0.25, 0.3), HD(-0.15, -0.35),
		R(-0.3, -0.5, 0.65, 0.3), WR(0.4), L(0.5, -0.2, -0.25, 0.5), WL(-0.2), {"fp_r": 0.0, "fp_l": -0.3, "jaw": 0.8, "sq": 0.96}])
	k.append(K(BA_SWIPE, swipe, "s"))
	k.append(K(6.55, M([FL(0.03, 0.37 - BA_LUNGE / leg), FR(0.05, 0.85 - (BA_LUNGE - at_swipe) / leg), H(0, -0.3, 0.28), {"sq": 1.0, "fp_l": -0.4}]), "s"))
	# 6,58 · plus personne : la tête part à gauche, là où elle est passée
	k.append(K(6.6, M([HD(0.05, 0.75, 0.0), C(0.2, 0.4), {"face": "surprise", "jaw": 0.4}])))
	# 6,62 → 6,8 · elle se retourne d'un bond (le film la tourne vers Bleuette)
	k.append(K(6.66, M([H(0, -0.1, 0.05), FL(0.05, 0.1, 0.07), FR(0.06, 0.35, 0.07), B(0.25, 0.2), C(0.15, 0.25), HD(0.05, 0.4, 0.0), {"fp_l": -0.3, "fp_r": -0.3}])))
	k.append(K(BA_PUSH - 0.02, M([FL(0.05, -0.12), FR(0.06, 0.1), H(0, -0.16, 0.12), B(0.35, 0.0), C(0.15, 0.0), HD(0.25, 0.0, 0.0), {"fp_l": 0.0, "fp_r": 0.0, "face": "angry", "jaw": 0.6}]), "s"))
	# 6,8 · elle se lance après elle, griffes tendues…
	k.append(K(6.86, M([FR(0.06, 0.32, 0.12), FL(0.05, -0.3), H(0, -0.12, 0.25), B(0.55), C(0.1), HD(0.35), R(0.15, 0.15, 0.9, 0.3), L(0.15, 0.1, 0.9, 0.3), WR(-0.5), WL(-0.5),
		{"fp_r": -0.4, "fp_l": -0.6, "curl": 0.0, "curl_l": 0.0, "jaw": 0.8}])))
	# 6,9 · … le pied droit se prend dans la robe : elle pique du nez
	var tripped: Dictionary = M([{"plant": 0.0, "gsnap": 1.0}, H(0, 0.0, 0.0), B(0.68), C(0.1), HD(0.3), TL(-0.2, 0.08), KL(0.4), TR(0.15, 0.08), KR(0.6),
		R(0.6, 0.85, 0.3, 0.8), L(0.75, -0.1, 0.45, 0.6), WR(0.0), WL(0.0), {"face": "surprise", "jaw": 0.9, "ev": "gasp", "fp_l": 0.0, "fp_r": 0.0}])
	k.append(K(6.95, tripped))
	k.append(K(7.06, M([B(1.0), HD(0.45), R(0.75, 0.25, 0.6, 0.6), L(0.6, 0.75, 0.3, 0.6), TL(-0.3, 0.08), KL(0.75), TR(-0.05, 0.08), KR(0.85)])))
	k.append(K(7.17, M([B(1.3), HD(0.55), R(0.3, 0.1, 0.95, 0.3), L(0.35, 0.15, 0.95, 0.3), TL(-0.18, 0.1), KL(1.0), TR(-0.12, 0.1), KR(1.1), {"jaw": 1.0}])))
	# 7,27 · PLOUF : à plat ventre, les pieds qui remontent derrière
	var flat: Dictionary = M([{"plant": 0.0, "gsnap": 1.0}, H(0, 0.0, 0.0), B(1.52), C(0.0), HD(0.15, 0.1, 0.1), TL(0.0, 0.1), KL(0.2), TR(0.0, 0.12), KR(0.3),
		Lg(0.35, 0.95), Rg(0.25, 1.05), {"el_l": 0.3, "el_r": 0.3, "curl": 0.2, "curl_l": 0.2, "face": "dazed", "jaw": 0.3, "sq": 1.0}])
	k.append(K(BA_LAND, M([flat, KL(1.2), KR(1.4), {"sq": 0.88, "face": "pain", "jaw": 0.6, "ev": "hurt"}]), "s"))
	k.append(K(7.36, M([KL(1.5), KR(1.2), {"sq": 1.03}])))
	k.append(K(7.5, M([flat, KL(0.25), KR(0.35)])))
	k.append(K(7.6, M([KL(0.15), KR(0.25)])))
	k.append(K(7.68, {"curl": 0.65, "curl_l": 0.55}))
	k.append(K(7.74, {"curl": 0.2, "curl_l": 0.2}))
	# 7,8 · elle se redresse sur les bras, ruisselante, et la fusille du regard…
	var up: Dictionary = M([Lg(0.35, 0.15), Rg(0.3, 0.2), C(-0.5), HD(0.75, 0.0, 0.0), {"el_l": 0.5, "el_r": 0.5, "face": "angry", "jaw": 0.4}])
	k.append(K(7.84, M([up, {"fx": "sweat"}])))
	k.append(K(7.98, M([C(-0.55), HD(0.8, 0.05, 0.05), {"jaw": 0.6}])))
	# … les bras glissent : retour le nez dans l'eau (8,12)
	k.append(K(8.06, M([Lg(0.4, 0.75), Rg(0.35, 0.85), C(-0.3), HD(0.6), {"face": "surprise"}])))
	k.append(K(8.12, M([C(0.05), HD(0.15, 0.0, 0.1), {"sq": 0.94, "face": "pain", "jaw": 0.3}]), "s"))
	k.append(K(8.2, {"sq": 1.0}))
	# 8,3 · 8,5 · elle tape l'eau de rage, les jambes battent
	k.append(K(8.25, M([Rg(0.45, 0.7, 0.45), {"face": "angry"}])))
	k.append(K(8.3, M([Rg(0.45, 0.75, 0.0), KR(0.9)]), "s"))
	k.append(K(8.45, M([Lg(0.5, 0.65, 0.45), KR(0.3)])))
	k.append(K(8.5, M([Lg(0.5, 0.7, 0.0), KL(0.9)]), "s"))
	k.append(K(8.62, M([KL(0.3)])))
	c["fv_bleuette_alice_rain"] = _film(3.3, 8.8, k, "menace")

	# PAPIER · le plongeon raté : à l'horizontale au-dessus de la flaque, les
	# griffes tendues vers Bleuette qui file
	var dive: Dictionary = M([{"plant": 0.0}, H(0, 0.0, 0.0), B(1.3), C(0.05), HD(0.55), TL(-0.25, 0.1), KL(0.6), TR(0.05, 0.1), KR(0.95),
		R(0.12, 0.2, 0.95, 0.3), L(0.25, 0.3, 0.9, 0.3), WR(-0.4), WL(-0.4), {"curl": 0.0, "curl_l": 0.0, "face": "surprise", "jaw": 0.9}])
	var ink: Array = []
	ink.append(K(0.0, M([_zero(), dive])))
	ink.append(K(1.3, M([B(1.36), HD(0.58), R(0.1, 0.24, 0.97, 0.3), L(0.22, 0.34, 0.92, 0.3), KL(0.65), KR(1.0)])))
	ink.append(K(2.6, M([B(1.42), HD(0.6), R(0.08, 0.26, 0.98, 0.3), L(0.2, 0.36, 0.94, 0.3), KL(0.7), KR(1.05)])))
	c["fv_bleuette_alice_ink"] = _film(0.0, 2.7, ink, "surprise")
