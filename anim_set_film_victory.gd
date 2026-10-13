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


# ------------------------------------------------------------------ USAYUKO --
# Force. Alice abat sa griffe : Usayuko la bloque de l'avant-bras (3,62), plie
# sous le poids, sourit ; il la repousse (4,98), elle revient à la charge et
# s'empale sur son poing (5,75). Elle traverse la cour (5,87 → 6,69). Il souffle
# sur ses phalanges qui fument, s'essuie le nez du pouce et se campe, poings
# sur les hanches.

const U_HIT: float = 5.75

static func _u_guard() -> Dictionary:
	return M([FL(0.06, 0.24), FR(0.14, -0.24), H(0, -0.12, 0.0), B(0.08, -0.25), C(0.05, -0.12), HD(-0.04, 0.37),
		Lt(-0.25, 0.22, 0.55, 0.3), Rt(-0.18, 0.05, 0.42, 0.4), WL(0.0, 0.8), WR(0.0, -0.8), {"curl": 1.0, "curl_l": 1.0}])


static func _usayuko(c: Dictionary) -> void :
	var k: Array = []
	# 3,3 · le flash le surprend en pleine garde haute, l'avant-bras gauche monte
	k.append(K(3.3, M([_zero(), _u_guard(), FACE("determined")])))
	k.append(K(3.4, M([H(0, -0.16, -0.02), Lt(-0.12, 0.38, 0.62, 0.8), WL(0.0, 1.1), HD(0.08, 0.35), C(0.04, -0.15)])))
	# 3,62 · CLANG : la griffe tombe sur l'avant-bras, les genoux encaissent
	k.append(K(3.58, M([H(0, -0.14, 0.0), B(0.1, -0.22), L(-0.06, 0.44, 0.72, 0.95), WL(0.1, 1.2), {"sq": 1.0}])))
	k.append(K(3.62, M([H(0, -0.3, -0.06), B(0.2, -0.18), C(0.1, -0.08), HD(-0.22, 0.32, 0.05), L(-0.04, 0.32, 0.7, 0.95),
		Rt(-0.05, -0.3, 0.2, 0.4), SH(0.25, 0.1), {"sq": 0.93, "shake": 0.8, "ev": "effort", "face": "angry", "fp_l": 0.0}]), "s"))
	k.append(K(3.74, M([H(0, -0.26, -0.04), {"sq": 1.0, "shake": 0.5}])))
	# 3,74 → 4,5 · il plie sous la poussée, puis serre les dents et regagne du terrain
	k.append(K(4.05, M([H(0, -0.34, -0.06), B(0.24, -0.2), HD(-0.18, 0.3, 0.08), L(-0.04, 0.27, 0.68, 0.95), SH(0.3, 0.12), {"shake": 0.7}])))
	k.append(K(4.2, FACE("grin")))
	k.append(K(4.4, M([H(0, -0.3, -0.02), HD(-0.08, 0.34, -0.04), L(-0.05, 0.33, 0.72, 0.95), {"shake": 0.45}])))
	k.append(K(4.62, M([H(0, -0.33, -0.04), B(0.18, -0.35), C(0.1, -0.25), HD(-0.1, 0.55), Rt(0.15, -0.35, -0.05, 0.4), {"shake": 0.6, "face": "angry"}]), "s"))
	# 4,98 · VLAN : l'avant-bras balaie la griffe vers l'extérieur, tout le corps tourne
	k.append(K(4.9, M([H(0, -0.36, -0.06), B(0.2, -0.45), C(0.12, -0.3), L(0.0, 0.25, 0.65, 0.9), {"shake": 0.9}])))
	k.append(K(4.98, M([FL(0.06, 0.34), H(0, -0.2, 0.12), B(0.02, 0.35), C(-0.04, 0.3), HD(0.05, -0.2), L(0.75, 0.55, 0.3, 1.0), WL(-0.3, 0.6),
		Rt(0.1, -0.2, 0.1, 0.4), SH(0.05, 0.0), {"sq": 1.06, "shake": 0.0, "ev": "grunt", "fx": "trail_l whoosh"}]), "s"))
	# 5,07 → 5,6 · armé : le poing droit recule loin derrière, la main gauche vise
	k.append(K(5.12, M([H(0, -0.2, 0.0), B(0.06, -0.25), C(0.02, -0.2), HD(0.0, 0.45), L(0.4, 0.2, 0.55, 0.6), {"sq": 1.0}])))
	k.append(K(5.3, M([FL(0.06, 0.3), FR(0.16, -0.3), H(0, -0.24, -0.14), B(0.1, -0.7), C(0.08, -0.45), HD(-0.02, 1.0), R(0.42, 0.12, -0.55, 0.7), WR(-0.2, -0.3),
		L(-0.05, 0.12, 0.85, 0.2), WL(0.0, 0.3), SH(0.0, 0.25, 0.0, -0.2), {"curl_l": 0.35, "shake": 0.25, "face": "determined", "fx": "flex"}])))
	k.append(K(5.52, M([FL(0.06, 0.34, 0.12), H(0, -0.22, -0.16), B(0.12, -0.78), C(0.1, -0.5), HD(-0.04, 1.08), R(0.44, 0.15, -0.6, 0.7), {"shake": 0.55, "fp_l": 0.3}])))
	# le pied avant se pose, la hanche part, le poing suit
	k.append(K(5.64, M([FL(0.03, 0.62), H(0, -0.26, 0.24), B(0.2, -0.3), C(0.1, -0.2), HD(-0.08, 0.5), R(0.3, 0.05, 0.0, 0.5), {"fp_l": 0.0, "fp_r": -0.3, "shake": 0.2}])))
	# 5,75 · PAF : bras tendu, épaule devant, talon arrière levé ; arrêt sur image
	var punch: Dictionary = M([FL(0.02, 0.64), FR(0.13, -0.46), H(0, -0.27, 0.5), B(0.34, 0.62), C(0.16, 0.6), HD(-0.12, -0.95, 0.05),
		R(-0.12, -0.12, 1.0, 0.0), WR(0.0, 0.0), Lt(0.12, -0.25, 0.1, 0.5), SH(0.0, 0.05, 0.0, 0.3),
		{"fp_r": -0.75, "sq": 1.06, "shake": 0.0, "curl": 1.0, "curl_l": 1.0, "face": "angry", "jaw": 0.5}])
	k.append(K(U_HIT, M([punch, {"ev": "grunt", "fx": "pop_r"}]), "h"))
	k.append(K(U_HIT + 0.1, M([punch, {"sq": 1.0}])))
	# rattrapage : le bras finit sa course, le corps continue de tourner puis revient
	k.append(K(U_HIT + 0.3, M([H(0, -0.25, 0.52), B(0.38, 0.72), C(0.18, 0.66), HD(-0.1, -1.0, 0.05), R(-0.2, 0.0, 1.0, 0.0), {"jaw": 0.2}])))
	k.append(K(6.35, M([FL(0.04, 0.5), FR(0.13, -0.38), H(0, -0.2, 0.3), B(0.2, 0.35), C(0.1, 0.3), HD(-0.02, -0.55), Rt(0.1, -0.1, 0.55, 0.3), WR(0.2, -0.4), {"fp_r": -0.2, "face": "determined", "jaw": 0.0}]), "s"))
	# 6,69 · elle s'écrase au loin ; il redresse le buste et la regarde
	k.append(K(6.75, M([FL(0.05, 0.42), FR(0.14, -0.3), H(0, -0.14, 0.18), B(0.08, 0.15), C(0.04, 0.1), HD(0.04, -0.25), {"fp_r": 0.0}])))
	# 7,05 · VAPEUR : le poing fumant monte devant la bouche, il souffle (7,1),
	# secoue la main brûlante (7,33), sourit (7,56)
	k.append(K(7.0, M([Rt(-0.18, 0.18, 0.42, 0.6), WR(0.5, -0.9), HD(-0.02, -0.1), {"face": "calm"}])))
	k.append(K(7.1, M([Rt(-0.25, 0.32, 0.36, 0.7), WR(0.7, -1.2), HD(-0.12, -0.05), C(0.06, 0.05), {"jaw": 0.35}]), "s"))
	k.append(K(7.28, M([Rt(0.25, 0.05, 0.4, 0.5), WR(-0.6, 0.4), HD(0.0, 0.1), {"jaw": 0.0, "curl": 0.15, "face": "surprise"}])))
	k.append(K(7.33, M([Rt(0.32, -0.05, 0.38, 0.5), WR(0.7, -0.4)])))
	k.append(K(7.38, M([Rt(0.28, 0.06, 0.4, 0.5), WR(-0.7, 0.4)])))
	k.append(K(7.43, M([Rt(0.33, -0.04, 0.38, 0.5), WR(0.6, -0.3)])))
	k.append(K(7.5, M([Rt(0.3, 0.02, 0.4, 0.5), WR(-0.3, 0.2)])))
	k.append(K(7.56, M([Rt(0.35, -0.3, 0.25, 0.4), WR(0.0, 0.0), HD(0.06, -0.15, 0.08), {"curl": 0.4, "face": "grin"}]), "s"))
	blink(7.66, "grin", k)
	# 7,85 · HÉROS : il fait rouler l'épaule (8,12), s'essuie le nez du pouce (8,4),
	# se campe poings sur les hanches (8,67)
	k.append(K(7.85, M([FL(0.08, 0.3), FR(0.16, -0.25), H(0, -0.08, 0.06), B(0.02, 0.0), C(0.02, 0.0), HD(0.05, 0.0, -0.08), Lt(0.2, -0.65, 0.15, 0.2), {"curl_l": 0.7}])))
	k.append(K(8.05, M([SH(0.0, 0.35, 0.0, 0.25), Rt(0.3, -0.45, 0.2, 0.4), HD(0.1, 0.25, 0.15)])))
	k.append(K(8.2, M([SH(0.0, -0.05, 0.0, -0.2), Rt(0.35, -0.55, 0.05, 0.4), HD(0.02, 0.1, -0.05)])))
	k.append(K(8.3, M([SH(0.0, 0.0), Rt(-0.18, 0.38, 0.3, 0.6), WR(0.9, -1.4), {"curl": 0.85}])))
	k.append(K(8.4, M([Rt(-0.3, 0.42, 0.28, 0.6), WR(1.0, -1.6), HD(0.12, -0.05, 0.05), {"gesture": "thumbsup"}]), "s"))
	k.append(K(8.48, M([Rt(-0.05, 0.44, 0.3, 0.6), WR(1.0, -1.3), HD(0.16, 0.05, 0.0)])))
	k.append(K(8.56, {"gesture": ""}))
	var hands_on_hips: Dictionary = M([L(0.62, -0.6, 0.02, 0.9), R(0.62, -0.6, 0.02, 0.9), WL(0.6, 0.0, 0.3), WR(0.6, 0.0, -0.3), {"curl": 1.0, "curl_l": 1.0}])
	k.append(K(8.67, M([FL(0.1, 0.12), FR(0.16, -0.12), H(0, -0.04, 0.0), B(-0.05, 0.0), C(-0.08, 0.0), HD(0.2, 0.05, -0.06), hands_on_hips, SH(0.12, 0.12), {"sq": 1.02}]), "s"))
	k.append(K(8.95, M([HD(0.22, 0.05, -0.08), {"sq": 1.0}])))
	c["fv_usayuko_rain"] = _film(3.3, 9.2, k, "determined")

	# PAPIER · le coup de poing en silhouette de profil : le bras finit sa course
	# au ralenti
	var ink: Array = []
	ink.append(K(0.0, M([_zero(), punch, {"face": "angry", "jaw": 0.4}])))
	ink.append(K(0.5, M([H(0, -0.27, 0.53), B(0.36, 0.68), C(0.17, 0.64), R(-0.16, 0.04, 1.0, 0.0), {"jaw": 0.3}])))
	ink.append(K(2.6, M([H(0, -0.25, 0.58), B(0.4, 0.78), C(0.2, 0.7), HD(-0.1, -1.0, 0.05), R(-0.22, 0.02, 1.0, 0.0), Lt(0.18, -0.3, 0.0, 0.5), {"fp_r": -0.85}])))
	c["fv_usayuko_ink"] = _film(0.0, 2.7, ink, "angry")

	_usayuko_alice(c)


static func _usayuko_alice(c: Dictionary) -> void :
	var k: Array = []
	# 3,3 · elle tombe sur lui, griffe droite armée haut derrière la tête
	k.append(K(3.3, M([_zero(), FL(0.06, 0.3, 0.05), FR(0.1, -0.3), H(0, -0.06, -0.1), B(-0.12, -0.35), C(-0.1, -0.3), HD(0.1, 0.55, 0.08),
		R(0.35, 0.95, -0.2, 0.8), WR(-0.7), L(0.3, -0.25, 0.55, 0.3), WL(0.2), {"curl": 0.15, "curl_l": 0.4, "face": "angry", "jaw": 0.6}])))
	k.append(K(3.48, M([H(0, -0.04, -0.12), B(-0.16, -0.42), C(-0.14, -0.36), R(0.3, 1.0, -0.3, 0.8), WR(-0.9), {"jaw": 0.8}]), "s"))
	# 3,62 · la griffe s'abat sur l'avant-bras d'Usayuko : le choc remonte dans son bras
	k.append(K(3.58, M([FL(0.06, 0.55), H(0, -0.12, 0.25), B(0.3, 0.3), C(0.2, 0.3), HD(-0.1, -0.3), R(0.0, 0.42, 0.8, 0.3), WR(0.4), L(0.4, -0.35, 0.15, 0.3), {"jaw": 0.3}])))
	k.append(K(3.62, M([H(0, -0.16, 0.3), B(0.36, 0.34), C(0.24, 0.32), HD(-0.18, -0.32, 0.06), R(0.02, 0.3, 0.74, 0.35), WR(0.6), {"sq": 0.96, "shake": 0.6, "fx": "spark_r"}]), "s"))
	k.append(K(3.72, M([R(0.02, 0.33, 0.74, 0.35), {"sq": 1.0, "shake": 0.3}])))
	# elle pèse de tout son poids, l'autre main vient appuyer
	k.append(K(3.95, M([H(0, -0.2, 0.36), B(0.42, 0.25), C(0.28, 0.22), HD(-0.2, -0.22), R(0.02, 0.24, 0.72, 0.35), L(0.05, 0.2, 0.72, 0.45), WL(0.5), {"curl_l": 0.2, "shake": 0.45, "jaw": 0.5}])))
	k.append(K(4.4, M([H(0, -0.18, 0.34), B(0.4, 0.22), HD(-0.12, -0.2, -0.06), R(0.02, 0.28, 0.73, 0.35), L(0.05, 0.25, 0.72, 0.45), {"shake": 0.55, "fx": "spark_r"}])))
	k.append(K(4.75, M([H(0, -0.2, 0.36), B(0.44, 0.2), R(0.02, 0.26, 0.72, 0.35), L(0.05, 0.22, 0.72, 0.45), {"shake": 0.7}])))
	k.append(K(4.9, M([H(0, -0.16, 0.32), B(0.38, 0.18), R(0.04, 0.34, 0.74, 0.35), L(0.07, 0.3, 0.72, 0.45)])))
	# 4,98 · repoussée : bras projetés en l'air, elle recule en titubant
	k.append(K(4.98, M([FL(0.06, 0.45), H(0, -0.08, 0.1), B(-0.2, 0.55), C(-0.22, 0.45), HD(0.35, -0.5, -0.2), R(0.85, 0.6, 0.0, 0.8), WR(-0.6), L(0.6, 0.45, 0.2, 0.7),
		{"sq": 1.05, "shake": 0.0, "jaw": 0.7, "face": "surprise", "ev": "gasp"}]), "s"))
	k.append(K(5.08, M([FL(0.06, 0.3, 0.25), FR(0.1, -0.2), H(0, -0.05, -0.12), B(-0.32, 0.4), C(-0.25, 0.35), HD(0.4, -0.35, -0.25), R(0.95, 0.3, -0.25, 0.8), L(0.9, 0.55, -0.1, 0.8), {"sq": 1.0}])))
	k.append(K(5.18, M([FL(0.06, -0.25), FR(0.1, -0.15, 0.2), H(0, -0.12, -0.2), B(-0.2, 0.3), HD(0.25, -0.2, -0.15)])))
	k.append(K(5.28, M([FL(0.06, -0.2), FR(0.1, -0.55), H(0, -0.22, -0.3), B(-0.05, 0.15), C(-0.05, 0.1), HD(0.05, -0.1, -0.05), R(0.7, -0.1, 0.1, 0.6), L(0.65, -0.05, 0.15, 0.6), {"face": "angry"}]), "s"))
	# 5,3 → 5,75 · elle se reprend, gronde et revient à la charge, griffes en avant
	k.append(K(5.42, M([FL(0.06, 0.0), FR(0.1, -0.5), H(0, -0.3, -0.25), B(0.35, 0.0), C(0.3, 0.0), HD(-0.3, 0.0), R(0.4, 0.15, 0.1, 0.6), L(0.4, 0.15, 0.1, 0.6), WR(-0.5), WL(-0.5), {"jaw": 0.9, "ev": "roar", "curl": 0.1, "curl_l": 0.1}]), "s"))
	k.append(K(5.62, M([FL(0.06, 0.35, 0.15), FR(0.1, -0.45), H(0, -0.15, 0.25), B(0.5, 0.0), C(0.25, 0.0), HD(-0.2, 0.0), R(0.25, 0.3, 0.8, 0.4), L(0.25, 0.3, 0.8, 0.4), {"fp_r": -0.6}])))
	# 5,75 · le poing s'enfonce dans son ventre : elle se plie en deux autour,
	# tête, bras et jambes fouettés vers l'avant ; arrêt sur image
	var struck: Dictionary = M([{"plant": 0.0}, H(0, 0.04, -0.4), B(0.72, 0.05), C(0.32, 0.05), HD(-0.05, 0.1, 0.05),
		TL(0.55, 0.12), KL(0.6, 0.3), TR(0.3, 0.14), KR(0.85, 0.3), R(0.25, -0.15, 0.85, 0.5), L(0.3, -0.1, 0.8, 0.5), WR(-0.4), WL(-0.4),
		{"sq": 0.9, "jaw": 1.0, "face": "pain", "curl": 0.0, "curl_l": 0.0}])
	k.append(K(U_HIT - 0.04, M([{"plant": 0.6}, FL(0.06, 0.4), FR(0.1, -0.3), H(0, -0.08, 0.15), B(0.45, 0.0), C(0.2, 0.0), HD(-0.1, 0.0), R(0.25, 0.25, 0.85, 0.4), L(0.25, 0.25, 0.85, 0.4)])))
	k.append(K(U_HIT, M([struck, {"ev": "hurt"}]), "h"))
	k.append(K(U_HIT + 0.1, struck))
	# envol (5,87 → 6,69) : pliée, elle part en arrière, membres traînant vers lui,
	# puis le haut du corps bascule et elle retombe sur le dos
	k.append(K(6.05, M([H(0, 0.05, -0.45), B(0.85, 0.1), C(0.35, 0.1), HD(0.15, 0.2, 0.1), TL(0.75, 0.15), KL(0.4), TR(0.6, 0.2), KR(0.6), R(0.4, 0.1, 0.9, 0.6), L(0.45, 0.2, 0.85, 0.6), {"sq": 1.04}])))
	k.append(K(6.35, M([H(0, 0.0, -0.2), B(0.1, -0.15), C(-0.05), HD(0.35, 0.3, 0.2), TL(1.1, 0.2), KL(0.7), TR(0.75, 0.25), KR(1.0), R(0.9, 0.5, 0.4, 0.9), L(0.85, 0.6, 0.2, 0.9), {"sq": 1.0, "jaw": 0.7}])))
	k.append(K(6.6, M([{"gsnap": 0.3}, H(0, 0.0, -0.3), {"body": V(1.05, 0.1, 0.05)}, C(-0.1), HD(-0.2, 0.4, 0.1), TL(1.35, 0.2), KL(0.4), TR(1.1, 0.25), KR(0.5), R(0.9, 0.7, 0.0, 0.9), L(0.9, 0.75, -0.1, 0.9)])))
	# 6,69 · elle s'écrase sur le dos, les jambes rebondissent et retombent
	var down: Dictionary = M([{"plant": 0.0, "gsnap": 1.0}, H(0, 0.0, -0.45), {"body": V(1.5, 0.12, 0.0), "chest": V(-0.12, 0.12, 0.06), "head": V(-0.35, 0.75, 0.1)},
		TL(0.45, 0.15, 0.2), KL(0.7), TR(0.25, 0.12, -0.15), KR(0.35), {"l_arm": V(1.2, 0.0, -0.5), "r_arm": V(1.2, 0.0, 0.5)}, Lg(0.95, -0.25), Rg(0.9, 0.1),
		{"el_l": 0.6, "el_r": 0.7, "face": "dazed", "jaw": 0.35, "sq": 1.0, "curl": 0.25, "curl_l": 0.35}])
	k.append(K(6.69, M([down, TL(1.0, 0.15, 0.2), KL(0.4), TR(0.85, 0.12, -0.15), KR(0.3), {"sq": 0.9, "ev": "hurt"}]), "s"))
	k.append(K(6.82, M([TL(1.25, 0.15, 0.2), KL(0.6), TR(1.05, 0.12, -0.15), KR(0.5), HD(-0.2, 0.8, 0.1), {"sq": 1.03}])))
	k.append(K(7.05, M([down])))
	# elle bouge encore : une main se crispe sur le sol (7,6), la tête retombe (8,3)
	k.append(K(7.5, M([Rg(0.9, 0.1)])))
	k.append(K(7.62, M([Rg(0.8, 0.25, 0.06), {"curl": 0.85}])))
	k.append(K(7.8, M([Rg(0.85, 0.15), {"curl": 0.3}])))
	k.append(K(8.2, M([{"head": V(-0.15, 0.65, 0.05)}])))
	k.append(K(8.32, M([{"head": V(-0.38, 0.8, 0.12)}, {"face": "dead"}])))
	c["fv_usayuko_alice_rain"] = _film(3.3, 9.2, k, "angry")

	# PAPIER · pliée autour du poing, elle part en arrière au ralenti
	var ink: Array = []
	ink.append(K(0.0, M([_zero(), struck, {"face": "pain"}])))
	ink.append(K(2.6, M([H(0, 0.06, -0.5), B(0.95, 0.12), C(0.4, 0.1), HD(0.1, 0.25, 0.15), TL(0.85, 0.15), KL(0.5), TR(0.65, 0.2), KR(0.7), R(0.4, 0.05, 0.95, 0.6), L(0.45, 0.15, 0.9, 0.6), {"sq": 1.0}])))
	c["fv_usayuko_alice_ink"] = _film(0.0, 2.7, ink, "pain")
