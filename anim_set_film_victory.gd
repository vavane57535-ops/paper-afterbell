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
	return {"len": maxf(0.05, end - start), "in": 0.0, "out": 0.0, "face": face, "at": start, "keys": shifted}


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
