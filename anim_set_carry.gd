extends "res://anim_pose.gd"

# Portages de Simon pendant la course éclair (0.17), un par allié (voir carry_rig.gd pour le placement).
#   carry_<allié>   : Simon (additif sur la course « Sonic » : buste, tête, bras qui tiennent ; jambes procédurales).
#   carried_<allié> : l'allié porté (pose complète). Les deux clips partagent la même horloge (celle de Simon) :
#   0 = l'instant de la prise, puis une boucle longue (loop_from) pour que rien ne se répète trop visiblement.
# Les mains qui tiennent vraiment quelque chose sont recalées par IK dans carry_finalize() (character_visual.gd).

static func add(c: Dictionary) -> void :
	_ashura(c)
	_bleuette(c)
	_elly(c)
	_usayuko(c)


static func TL(fwd: float, out: float = 0.0, yaw: float = 0.0) -> Dictionary:
	return {"l_leg": Vector3(fwd, yaw, - out)}

static func TR(fwd: float, out: float = 0.0, yaw: float = 0.0) -> Dictionary:
	return {"r_leg": Vector3(fwd, - yaw, out)}

static func KL(bend: float, ankle: float = 0.0) -> Dictionary:
	return {"l_knee": - bend, "l_ank": ankle}

static func KR(bend: float, ankle: float = 0.0) -> Dictionary:
	return {"r_knee": - bend, "r_ank": ankle}


# --------------------------------------------------------------------------------------------------------
# ASHURA : Simon le tire par la main, il se laisse tracter sur ses rollers, accroupi en patineur.

# Accroupi sur ses rollers, tiré par la main droite (Simon est devant à droite) : le corps se laisse un peu
# entraîner vers lui, le bras gauche tendu sur le côté fait balancier. shift = transfert d'appui, dip = flexion.
static func _tuck(shift: float = 0.0, dip: float = 0.0) -> Dictionary:
	return M([{"gait": 0.0, "plant": 1.0}, FL(0.1 + 0.02 * shift, 0.2, 0.0), FR(0.15 - 0.02 * shift, -0.16, 0.0), H(0.04 * shift, -0.33 - dip, -0.05),
		B(0.3 + 0.4 * dip, -0.12, -0.07 + 0.05 * shift), C(0.1, -0.1, 0.03 * shift), HD(0.28, -0.22, 0.04),
		R(0.45, -0.05, 0.85, 0.1), L(0.86, 0.1, -0.15, 0.6), WL(0.2, 0.0, -0.3), {"fp_l": 0.0, "fp_r": 0.0, "curl": 0.85, "curl_l": 0.25, "sq": 1.0}])

static func _ashura(c: Dictionary) -> void :
	c["carried_ashura"] = {"len": 3.2, "loop": true, "loop_from": 0.6, "in": 0.0, "face": "surprise", "keys": [
		[0.0, M([{"gait": 0.0, "plant": 1.0}, FLR(0.06, 0.0, 0.0), H(0.0, -0.04, 0.0), B(0.1), C(0.02), HD(0.05), L(0.3, -0.85, 0.1), R(0.32, -0.8, 0.15), WL(0.0), WR(0.0), {"fp_l": 0.0, "fp_r": 0.0, "curl": 0.3, "curl_l": 0.3, "sq": 1.0}])],
		[0.07, M([H(0.0, -0.1, 0.0), B(0.22), HD(0.2, -0.2), R(0.12, 0.0, 0.95, 0.1), {"curl": 0.0, "jaw": 0.3}])],
		[0.15, M([{"fx": "skate_sparks"}, FL(0.06, 0.1, 0.0), FR(0.12, -0.32, 0.0), H(0.0, -0.18, -0.12), B(0.82, 0.05, 0.0), C(0.2, 0.1), HD(-0.15, -0.1), L(0.6, 0.35, -0.55, 0.5), {"curl": 0.9, "sq": 0.94, "ev": "gasp"}]), "s"],
		[0.28, M([FL(0.07, 0.3, 0.0), FR(0.12, -0.2, 0.0), H(0.0, -0.34, -0.06), B(0.62, 0.1, 0.0), C(0.16, 0.1), HD(0.3, -0.05), L(0.9, 0.2, 0.0, 0.6), {"sq": 1.03, "jaw": 0.1, "face": "focus"}])],
		[0.6, _tuck(0.0)],
		[1.15, M([_tuck(1.0, 0.03), {"fx": "skate_sparks"}])],
		[1.4, M([FL(0.09, 0.3, 0.09), {"fp_l": -0.25}])],
		[1.7, M([_tuck(-0.6, 0.0), {"fp_l": 0.0, "face": "calm"}])],
		[2.05, M([HD(0.36, -0.55, -0.05), C(0.1, 0.0, 0.0), {"face": "smile"}]), "s"],
		[2.4, M([_tuck(0.4, 0.04), {"fx": "skate_sparks"}])],
		[2.75, M([_tuck(-0.3, 0.0), {"face": "focus"}])],
		[3.2, _tuck(0.0)],
	]}

	c["carry_ashura"] = {"len": 3.2, "loop": true, "loop_from": 0.6, "add": true, "in": 0.0, "face": "grin", "keys": [
		[0.0, M([B(0.0), C(0.0), HD(0.0), L(0.4, -0.38, -0.9), WL(0.25, 0.35, 0.0), {"curl_l": 0.2}])],
		[0.06, M([C(0.0, 0.18, 0.0), HD(0.05, 0.75, 0.0), L(0.8, -0.2, -0.55), {"curl_l": 0.0}])],
		[0.15, M([C(0.0, 0.22, 0.0), HD(0.08, 0.8, 0.0), L(0.76, -0.28, -0.6), {"curl_l": 0.95, "ev": "effort"}]), "s"],
		[0.22, M([B(-0.08, 0.06, 0.0), C(0.0, 0.25, 0.0), HD(0.1, 0.6, 0.0), {"sq": 0.97}])],
		[0.42, M([B(0.0), C(0.0, 0.1, 0.0), HD(0.0, 0.1, 0.0), L(0.74, -0.3, -0.6), {"sq": 1.0}])],
		[0.6, M([C(0.0, 0.08, 0.0), HD(0.0, 0.0, 0.0), L(0.74, -0.3, -0.6)])],
		[1.8, M([C(0.0, 0.08, 0.0), HD(0.0, 0.0, 0.0)])],
		[2.0, M([C(0.0, 0.16, 0.0), HD(0.05, 0.62, 0.0)]), "s"],
		[2.3, M([C(0.0, 0.08, 0.0), HD(0.0, 0.0, 0.0)])],
		[3.2, M([C(0.0, 0.08, 0.0), HD(0.0, 0.0, 0.0), L(0.74, -0.3, -0.6)])],
	]}


# --------------------------------------------------------------------------------------------------------
# BLEUETTE : portée « en princesse » (bras gauche de Simon dans son dos, bras droit sous ses genoux).
# Elle hurle, s'agrippe à son cou en tremblant, les yeux plissés… puis ose regarder, et finit rassurée.

# Couchée en travers des bras de Simon (son dos sur le bras gauche, ses genoux sur le bras droit) : buste
# renversé (recline), cuisses à peu près à l'horizontale, tibias qui pendent. curl = genoux remontés (peur).
static func _princess(curl: float, recline: float, head_turn: float, head_up: float) -> Dictionary:
	var thigh: float = 0.72 + 0.32 * curl
	var knee: float = 1.68 + 0.3 * curl
	return M([{"gait": 0.0, "plant": 0.0}, TL(thigh, 0.06), KL(knee, 0.25), TR(thigh - 0.1, 0.0), KR(knee - 0.18, 0.3),
		H(0.0, 0.0, 0.0), B(- recline, -0.06, 0.1), C(0.22 + 0.16 * curl, 0.0, 0.0), HD(head_up, head_turn, 0.15)])

static func _bleuette(c: Dictionary) -> void :
	c["carried_bleuette"] = {"len": 6.0, "loop": true, "loop_from": 3.4, "in": 0.0, "face": "surprise", "keys": [
		[0.0, M([{"gait": 0.0, "plant": 0.0}, TL(0.1, 0.05), KL(0.15), TR(0.05, 0.05), KR(0.1), H(0.0, 0.0, 0.0), B(0.05), C(0.0), HD(0.0), L(0.3, -0.8, 0.1), R(0.3, -0.8, 0.1), WL(0.0), WR(0.0), {"curl": 0.3, "curl_l": 0.3, "shake": 0.0, "jaw": 0.0, "sq": 1.0}])],
		[0.1, M([TL(0.7, 0.1), KL(0.5), TR(0.55, 0.05), KR(0.45), B(-0.45), C(-0.1), HD(0.3, 0.1), L(0.7, 0.4, 0.2, 0.5), R(0.6, 0.6, 0.1, 0.5), {"curl": 0.0, "curl_l": 0.0, "jaw": 0.6, "face": "panic", "ev": "gasp"}])],
		[0.2, M([TL(1.0, 0.15), KL(0.6), TR(0.95, 0.05), KR(0.8), B(-1.1), C(0.05), HD(0.45, -0.2, 0.1), L(0.55, 0.85, 0.0, 0.6), R(0.4, 0.9, 0.2, 0.6), {"jaw": 0.9, "sq": 1.04}]), "s"],
		[0.34, M([_princess(0.8, 1.0, -0.6, 0.15), L(0.2, 0.45, 0.6, 0.4), R(-0.1, 0.7, 0.45, 0.8), {"jaw": 0.5, "shake": 0.5, "curl": 0.9, "curl_l": 0.9}])],
		[0.6, M([_princess(1.0, 0.95, -1.0, -0.1), {"jaw": 0.0, "shake": 0.45, "face": "fear"}])],
		[1.2, M([_princess(0.95, 0.96, -0.95, -0.08), {"shake": 0.4}])],
		[1.8, M([_princess(1.0, 0.95, -1.02, -0.12), {"shake": 0.35}])],
		[2.25, M([_princess(0.8, 1.0, -0.5, 0.15), {"shake": 0.15, "face": "surprise"}]), "s"],
		[2.7, M([_princess(0.5, 1.02, -0.25, 0.3), {"shake": 0.0, "jaw": 0.25}])],
		[3.05, M([_princess(0.35, 1.02, -0.75, 0.45), {"jaw": 0.0, "face": "smile"}]), "s"],
		[3.4, M([_princess(0.2, 1.0, -0.7, 0.3)])],
		[3.9, M([_princess(0.25, 1.0, -0.72, 0.28), KL(1.95, 0.2)])],
		[4.15, M([KL(1.68, 0.2), KR(1.95, 0.25)])],
		[4.4, M([_princess(0.2, 1.02, -0.35, 0.18), {"face": "calm"}])],
		[5.0, M([_princess(0.22, 1.0, -0.4, 0.2)])],
		[5.4, M([_princess(0.2, 1.0, -0.75, 0.4), {"face": "smile"}]), "s"],
		[6.0, M([_princess(0.2, 1.0, -0.7, 0.3)])],
	]}

	c["carry_bleuette"] = {"len": 6.0, "loop": true, "loop_from": 3.4, "add": true, "in": 0.0, "face": "determined", "keys": [
		[0.0, M([B(0.0), C(0.0), HD(0.0)])],
		[0.08, M([B(0.1), C(0.05), HD(-0.05), L(0.32, -0.55, 0.45, 0.2), R(0.32, -0.6, 0.45, 0.2), {"curl": 0.2, "curl_l": 0.2}])],
		[0.17, M([B(-0.05), C(-0.05), HD(0.05), L(0.3, -0.4, 0.55, 0.2), R(0.34, -0.45, 0.55, 0.2), {"curl": 0.8, "curl_l": 0.8, "ev": "effort", "fx": "whoosh"}]), "s"],
		[0.3, M([B(-0.26), C(-0.12), HD(-0.12), {"sq": 1.03}])],
		[0.5, M([B(-0.22), C(-0.1), HD(-0.1, -0.08), {"sq": 1.0}])],
		[2.6, M([B(-0.22), C(-0.1), HD(-0.1, -0.05)])],
		[3.0, M([B(-0.24), C(-0.12), HD(-0.42, -0.35, 0.05), {"face": "grin"}]), "s"],
		[3.5, M([B(-0.22), C(-0.1), HD(-0.12, -0.05)])],
		[5.2, M([B(-0.22), C(-0.1), HD(-0.1, -0.08), {"face": "determined"}])],
		[5.5, M([B(-0.24), C(-0.12), HD(-0.38, -0.3, 0.05), {"face": "grin"}]), "s"],
		[6.0, M([B(-0.22), C(-0.1), HD(-0.1, -0.05)])],
	]}


# --------------------------------------------------------------------------------------------------------
# ELLY : elle saute sur son dos, jambes repliées comme un jockey, se retourne et braque son fusil vers
# l'arrière pour le couvrir (repère d'Elly = buste de Simon, incliné : « bas » = vers l'arrière de la course).

static func _rider(twist: float, look: float, sway: float = 0.0) -> Dictionary:
	return M([{"gait": 0.0, "plant": 0.0}, TL(1.45, 0.5), KL(1.95, 0.4), TR(1.4, 0.5), KR(2.0, 0.4), H(0.0, 0.0, 0.0),
		B(0.08, -0.15 * twist, 0.05 * sway), C(0.05, -0.45 * twist, 0.08 * twist), HD(-0.45 * look, -0.75 * look, 0.15 * look)])

static func _elly(c: Dictionary) -> void :
	c["carried_elly"] = {"len": 3.6, "loop": true, "loop_from": 0.9, "in": 0.0, "face": "focus", "keys": [
		[0.0, M([{"gait": 0.0, "plant": 0.0}, TL(0.0, 0.05), KL(0.1), TR(0.0, 0.05), KR(0.1), H(0.0, 0.0, 0.0), B(0.05), C(0.0), HD(0.0), L(0.3, -0.85, 0.05), R(0.3, -0.85, 0.05), WL(0.0), WR(0.0), {"curl": 0.4, "curl_l": 0.4, "sq": 1.0}])],
		[0.08, M([TL(0.8, 0.2), KL(1.3), TR(0.8, 0.2), KR(1.3), B(0.35), HD(0.3), L(0.45, -0.3, 0.5, 0.3), R(0.45, -0.3, 0.5, 0.3), {"sq": 0.94}])],
		[0.18, M([TL(1.3, 0.5), KL(1.9), TR(1.25, 0.5), KR(1.95), B(0.3), HD(0.2), L(0.2, 0.3, 0.7, 0.3), R(0.35, -0.2, 0.5, 0.3), {"sq": 1.05, "ev": "effort"}]), "s"],
		[0.32, M([_rider(0.0, 0.0), L(0.1, 0.35, 0.8, 0.4), R(0.35, -0.6, 0.3, 0.2), {"sq": 1.0}])],
		[0.5, M([_rider(0.2, 0.1), R(0.3, -0.75, 0.1, 0.2), WR(0.0), {"prop": "shotgun", "curl": 1.0}])],
		[0.62, M([R(0.32, -0.7, -0.05, 0.2), {"fx": "glint"}]), "s"],
		[0.75, M([_rider(0.8, 0.8), R(0.25, -0.86, -0.42, 0.1)])],
		[0.9, M([_rider(1.0, 1.0), R(0.22, -0.88, -0.45, 0.1), {"face": "focus"}])],
		[1.5, M([_rider(1.0, 1.05, 0.5), R(0.24, -0.87, -0.44, 0.1)])],
		[2.1, M([_rider(0.9, 0.95, -0.4), R(0.2, -0.89, -0.43, 0.1), {"face": "calm"}])],
		[2.45, M([_rider(0.3, 0.1, 0.0), {"face": "focus"}]), "s"],
		[2.75, M([_rider(1.0, 1.0, 0.2)])],
		[3.6, M([_rider(1.0, 1.0, 0.0), R(0.22, -0.88, -0.45, 0.1)])],
	]}

	c["carry_elly"] = {"len": 3.6, "loop": true, "loop_from": 0.9, "add": true, "in": 0.0, "face": "determined", "keys": [
		[0.0, M([B(0.0), C(0.0), HD(0.0)])],
		[0.08, M([C(0.0, -0.12, 0.0), HD(0.05, -0.35, 0.0), R(0.42, -0.5, -0.6), {"curl": 0.1}])],
		[0.2, M([B(0.12), C(0.06, -0.08, 0.0), HD(-0.08, -0.2, 0.0), {"curl": 0.9, "sq": 0.95, "ev": "effort"}]), "s"],
		[0.4, M([B(0.06), C(0.03, 0.0, 0.0), HD(0.0, 0.0, 0.0), {"sq": 1.0}])],
		[0.9, M([B(0.06), C(0.03), HD(0.0)])],
		[2.3, M([B(0.06), C(0.03), HD(0.0), {"fx": "sweat"}])],
		[2.5, M([B(0.06), C(0.03, -0.1, 0.0), HD(0.1, -0.45, 0.0)]), "s"],
		[2.8, M([B(0.06), C(0.03), HD(0.0)])],
		[3.6, M([B(0.06), C(0.03), HD(0.0)])],
	]}


# --------------------------------------------------------------------------------------------------------
# USAYUKO (plus lourd, vitesse × 0,85) : Simon le traîne par la capuche. Il se laisse glisser à reculons sur
# les talons (étincelles), raide comme une planche, les mains derrière la tête… et fait coucou à Alice.

static func _ski(bump: float = 0.0, wave: float = 0.0) -> Dictionary:
	return M([{"gait": 0.0, "plant": 1.0}, FL(0.08, 0.02, 0.0), FR(0.1, -0.04, 0.0), H(0.0, -0.55 + 0.03 * bump, -0.98), B(-1.05 + 0.03 * bump, 0.0, 0.0), C(0.05), HD(-0.62, 0.0, 0.0),
		Lt(0.28, 0.95, -0.28, 0.9), WL(0.0), Rt(0.28 + 0.2 * wave, 0.95 - 0.3 * wave, -0.28 + 0.9 * wave, 0.9 - 0.6 * wave), WR(0.0),
		{"fp_l": 0.85, "fp_r": 0.9, "curl": 0.6 * (1.0 - wave), "curl_l": 0.6}])

static func _usayuko(c: Dictionary) -> void :
	c["carried_usayuko"] = {"len": 3.9, "loop": true, "loop_from": 0.95, "in": 0.0, "face": "surprise", "keys": [
		[0.0, M([{"gait": 0.0, "plant": 1.0}, FLR(0.08, 0.0, 0.0), H(0.0, -0.04, 0.0), B(0.05), C(0.0), HD(0.0), L(0.35, -0.8, 0.1), R(0.35, -0.8, 0.1), WL(0.0), WR(0.0), {"fp_l": 0.0, "fp_r": 0.0, "curl": 0.6, "curl_l": 0.6, "jaw": 0.0, "sq": 1.0}])],
		[0.1, M([H(0.0, -0.1, -0.35), B(-0.45), HD(0.4), L(0.6, 0.6, 0.3, 0.6), R(0.55, 0.7, 0.2, 0.6), FL(0.08, 0.3, 0.2), {"fp_l": 0.6, "curl": 0.0, "curl_l": 0.0, "jaw": 0.8, "ev": "gasp"}])],
		[0.24, M([H(0.0, -0.3, -0.75), B(-0.9), HD(0.1), L(0.7, 0.5, 0.0, 0.7), R(0.75, 0.3, 0.1, 0.7), FL(0.08, 0.2, 0.15), FR(0.1, 0.1, 0.1), {"fp_l": 0.7, "fp_r": 0.7, "sq": 1.04}]), "s"],
		[0.38, M([_ski(1.0), L(0.7, 0.2, 0.2, 0.6), R(0.7, 0.1, 0.25, 0.6), {"sq": 0.92, "jaw": 0.3, "fx": "skate_sparks dust"}])],
		[0.6, M([_ski(0.0), L(0.5, 0.3, 0.3, 0.6), R(0.45, 0.5, 0.2, 0.6), {"sq": 1.0, "jaw": 0.0, "face": "neutral"}])],
		[0.95, M([_ski(0.0), {"face": "grin", "fx": "skate_sparks"}])],
		[1.45, M([_ski(0.6), {"fx": "skate_sparks"}])],
		[1.6, _ski(0.0)],
		[2.0, M([_ski(0.0, 1.0), HD(-0.7, 0.15, 0.1), {"face": "laugh"}])],
		[2.2, M([_ski(0.0, 0.85), Rt(0.62, 0.55, 0.55, 0.3), {"fx": "skate_sparks"}])],
		[2.4, M([_ski(0.0, 1.0)])],
		[2.6, M([_ski(0.4, 0.85), Rt(0.62, 0.55, 0.55, 0.3)])],
		[2.85, M([_ski(0.0, 0.0), {"face": "grin"}])],
		[3.3, M([_ski(0.7), {"fx": "skate_sparks"}])],
		[3.45, _ski(0.0)],
		[3.9, _ski(0.0)],
	]}

	c["carry_usayuko"] = {"len": 3.9, "loop": true, "loop_from": 0.95, "add": true, "in": 0.0, "face": "determined", "keys": [
		[0.0, M([B(0.0), C(0.0), HD(0.0), R(0.36, -0.42, -0.85), {"curl": 0.2}])],
		[0.06, M([C(0.0, -0.15, 0.0), HD(0.05, -0.5, 0.0), R(0.42, -0.55, -0.72), {"curl": 0.0}])],
		[0.12, M([C(0.0, -0.2, 0.0), HD(0.05, -0.6, 0.0), {"curl": 1.0}]), "s"],
		[0.2, M([B(-0.18, -0.08, 0.0), C(-0.08, -0.15, 0.0), HD(0.2, -0.2, 0.0), {"ev": "effort", "sq": 0.95, "face": "pain"}])],
		[0.42, M([B(0.12), C(0.06), HD(-0.08), {"sq": 1.0, "face": "determined"}])],
		[0.95, M([B(0.1), C(0.05), HD(-0.06), {"shake": 0.15}])],
		[1.7, M([B(0.12), C(0.06), HD(-0.1), {"fx": "sweat"}])],
		[2.1, M([B(0.1), C(0.05, -0.12, 0.0), HD(0.05, -0.55, 0.0), {"face": "angry"}]), "s"],
		[2.5, M([B(0.1), C(0.05), HD(-0.06), {"face": "determined"}])],
		[3.9, M([B(0.1), C(0.05), HD(-0.06), {"shake": 0.15}])],
	]}
