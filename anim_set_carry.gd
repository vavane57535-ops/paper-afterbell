extends "res://anim_pose.gd"

# Portages de Simon pendant la course éclair (0.17), un par allié (voir carry_rig.gd pour le placement).
#   carry_<allié>   : Simon (additif sur la course « Sonic » : buste, tête, bras qui tiennent ; jambes procédurales).
#   carried_<allié> : l'allié porté (pose complète). Les deux clips partagent la même horloge (celle de Simon) :
#   0 = l'instant de la prise, puis une boucle longue (loop_from) pour que rien ne se répète trop visiblement.
# Les mains qui tiennent vraiment quelque chose sont recalées par IK dans carry_finalize() (character_visual.gd) ;
# les poses de bras écrites ici les amènent au bon endroit avant que le contact ne prenne le relais.

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


# Bras de la course « Sonic » (mêmes valeurs que _sonic_arm de anim_set_simon.gd, sans rebond).
static func _sonic_l() -> Dictionary:
	return M([L(0.52, -0.46, -0.72), WL(0.25, 0.35, 0.0)])

static func _sonic_r() -> Dictionary:
	return M([R(0.52, -0.46, -0.72), WR(0.25, -0.35, 0.0)])

# Debout, bras le long du corps (l'instant où Simon arrive).
static func _standing(planted: bool) -> Dictionary:
	return M([{"gait": 0.0, "plant": 1.0 if planted else 0.0}, FLR(0.08, 0.0, 0.0), H(0.0, -0.03, 0.0), B(0.05), C(0.0), HD(0.04), L(0.32, -0.82, 0.1), R(0.32, -0.82, 0.1),
		WL(0.0), WR(0.0), {"fp_l": 0.0, "fp_r": 0.0, "curl": 0.35, "curl_l": 0.35, "shake": 0.0, "jaw": 0.0, "sq": 1.0}])


# --------------------------------------------------------------------------------------------------------
# ASHURA : Simon le tire par la main gauche ; Ashura se laisse tracter sur ses rollers, accroupi en patineur.

# Accroupi sur ses rollers (pieds parallèles, à plat sur les roues), tiré par la main droite (Simon est devant à
# droite) : le buste se laisse entraîner vers lui, le bras gauche tendu sur le côté fait balancier.
# shift = transfert d'appui (+ = sur le pied gauche), dip = flexion en plus.
static func _tuck(shift: float = 0.0, dip: float = 0.0) -> Dictionary:
	return M([{"gait": 0.0, "plant": 1.0}, FL(0.1 + 0.02 * shift, 0.16, 0.0), FR(0.15 - 0.02 * shift, -0.14, 0.0), H(0.03 * shift, -0.36 - dip, -0.04),
		B(0.52 + 0.3 * dip, -0.08, -0.06 + 0.05 * shift), C(0.1, -0.16, 0.03 * shift), HD(0.32, -0.22, 0.04),
		R(0.4, -0.04, 0.88, 0.1), L(0.88, 0.12, -0.2, 0.6), WL(0.2, 0.0, -0.3), WR(0.0), {"fp_l": 0.0, "fp_r": 0.0, "curl": 0.85, "curl_l": 0.2, "sq": 1.0}])

static func _ashura(c: Dictionary) -> void :
	c["carried_ashura"] = {"len": 3.6, "loop": true, "loop_from": 0.6, "in": 0.0, "face": "surprise", "keys": [
		[0.0, _standing(true)],
		[0.06, M([H(0.0, -0.08, 0.0), B(0.16), HD(0.16, -0.3), R(0.3, -0.12, 0.9, 0.1), {"curl": 0.0, "jaw": 0.3}])],
		# Le coup de traction : le bras part devant, le buste suit, la tête et le bras gauche restent en arrière.
		[0.13, M([{"fx": "skate_sparks"}, FL(0.06, -0.08, 0.0), FR(0.12, -0.34, 0.0), H(0.0, -0.2, -0.14), B(0.92, 0.05, 0.0), C(0.2, 0.08), HD(-0.18, -0.1),
			L(0.55, 0.42, -0.6, 0.5), {"curl": 0.9, "curl_l": 0.0, "sq": 0.94, "jaw": 0.6, "face": "panic", "ev": "gasp"}]), "s"],
		[0.26, M([FL(0.08, 0.12, 0.0), FR(0.13, -0.22, 0.0), H(0.0, -0.3, -0.06), B(0.68, 0.0, -0.04), C(0.14, -0.08), HD(0.36, -0.12),
			L(0.92, 0.26, -0.05, 0.6), {"sq": 1.03, "jaw": 0.15, "face": "focus"}])],
		[0.45, M([_tuck(0.0, 0.04), {"jaw": 0.0}])],
		[0.6, _tuck(0.0)],
		[0.95, M([_tuck(0.8, 0.02), {"fx": "skate_sparks"}])],
		[1.25, M([L(0.84, 0.2, 0.06, 0.6), {"face": "calm"}])],
		[1.6, M([_tuck(-0.6, -0.02), L(0.86, 0.16, -0.1, 0.6)])],
		# Un regard vers Simon, un demi-sourire (Ashura ne s'emballe pas).
		[1.95, M([_tuck(-0.2, 0.0), C(0.12, -0.26), HD(0.36, -0.62, -0.05), {"face": "smile"}]), "s"],
		[2.3, M([_tuck(0.3, 0.05), {"fx": "skate_sparks", "shake": 0.3, "face": "calm"}])],
		[2.45, M([{"shake": 0.0}])],
		[2.9, M([_tuck(-0.3, 0.0), {"face": "focus"}])],
		[3.25, M([_tuck(0.0, 0.08), L(0.72, 0.02, -0.3, 0.5)])],
		[3.6, _tuck(0.0)],
	]}

	c["carry_ashura"] = {"len": 3.6, "loop": true, "loop_from": 0.6, "add": true, "in": 0.0, "face": "grin", "keys": [
		[0.0, M([B(0.0), C(0.0), HD(0.0), _sonic_l(), {"curl_l": 0.2}])],
		[0.05, M([C(0.0, 0.16, 0.0), HD(0.05, 0.72, 0.0), L(0.6, -0.2, -0.8), WL(0.0), {"curl_l": 0.0}])],
		[0.13, M([C(0.0, 0.2, 0.0), HD(0.08, 0.78, 0.0), L(0.58, -0.24, -0.8), {"curl_l": 0.95, "ev": "effort"}]), "s"],
		[0.2, M([B(-0.06, 0.06, 0.0), C(0.0, 0.22, 0.0), HD(0.1, 0.55, 0.0), {"sq": 0.97}])],
		[0.42, M([B(0.0), C(0.0, 0.08, 0.0), HD(0.0, 0.1, 0.0), L(0.56, -0.25, -0.8), {"sq": 1.0}])],
		[0.6, M([C(0.0, 0.06, 0.0), HD(0.0, 0.0, 0.0), L(0.56, -0.25, -0.8)])],
		[1.8, M([C(0.0, 0.06, 0.0), HD(0.0, 0.0, 0.0)])],
		[2.0, M([C(0.0, 0.14, 0.0), HD(0.05, 0.6, 0.0)]), "s"],
		[2.35, M([C(0.0, 0.06, 0.0), HD(0.0, 0.0, 0.0)])],
		[3.6, M([C(0.0, 0.06, 0.0), HD(0.0, 0.0, 0.0), L(0.56, -0.25, -0.8)])],
	]}


# --------------------------------------------------------------------------------------------------------
# BLEUETTE : portée « en princesse » (bras gauche de Simon sous son dos, bras droit sous ses genoux).
# Elle hurle, s'agrippe à son cou en tremblant, les yeux fermés… puis ose regarder, et finit rassurée.
# Son repère : elle regarde vers la droite de Simon ; sa droite est contre lui, son dos vers sa gauche.

# Couchée en travers des bras de Simon : buste renversé (recline), tourné vers lui (turn), cuisses à peu près à
# l'horizontale, tibias qui pendent. curl = genoux remontés contre elle (peur).
static func _princess(curl: float, recline: float, turn: float, head_turn: float, head_up: float) -> Dictionary:
	return M([{"gait": 0.0, "plant": 0.0}, TL(0.55 + 0.3 * curl, 0.06), KL(1.62 + 0.28 * curl, 0.25), TR(0.5 + 0.3 * curl, 0.0), KR(1.52 + 0.3 * curl, 0.3),
		H(0.0, 0.0, 0.0), B(- recline, 0.0, 0.0), C(0.14 + 0.12 * curl, - turn, 0.0), HD(head_up, - head_turn, 0.12)])

static func _bleuette(c: Dictionary) -> void :
	c["carried_bleuette"] = {"len": 6.0, "loop": true, "loop_from": 3.4, "in": 0.0, "face": "surprise", "keys": [
		[0.0, M([_standing(false), TL(0.05), KL(0.1), TR(0.05), KR(0.1)])],
		[0.08, M([TL(0.75, 0.1), KL(0.6), TR(0.6, 0.05), KR(0.5), B(-0.45), C(-0.1), HD(0.35, 0.1), L(0.7, 0.5, 0.2, 0.5), R(0.55, 0.65, 0.15, 0.5), {"curl": 0.0, "curl_l": 0.0, "jaw": 0.7, "face": "panic", "ev": "gasp"}])],
		[0.18, M([TL(0.85, 0.15), KL(1.2), TR(0.8, 0.05), KR(1.0), B(-0.95), C(0.05), HD(0.4, -0.3, 0.1), L(0.5, 0.6, 0.3, 0.6), R(0.2, 0.6, 0.55, 0.6), {"jaw": 0.9, "sq": 1.04}]), "s"],
		[0.32, M([_princess(1.0, 1.05, 0.25, 0.6, 0.0), L(0.3, 0.35, 0.55, 0.4), R(0.1, 0.5, 0.6, 0.6), {"jaw": 0.45, "shake": 0.5, "curl": 0.9, "curl_l": 0.9, "sq": 0.95}])],
		[0.5, M([_princess(1.0, 1.0, 0.4, 0.9, -0.15), {"jaw": 0.0, "shake": 0.45, "sq": 1.0, "face": "pain"}])],
		[1.2, M([_princess(0.95, 1.0, 0.42, 0.95, -0.12), {"shake": 0.4}])],
		[1.8, M([_princess(1.0, 0.98, 0.4, 0.92, -0.18), {"shake": 0.35}])],
		# Elle ose ouvrir un œil, regarde la route… puis lui.
		[2.2, M([_princess(0.85, 1.0, 0.3, 0.45, 0.1), {"shake": 0.15, "face": "surprise"}]), "s"],
		[2.6, M([_princess(0.6, 1.02, 0.25, 0.2, 0.3), {"shake": 0.0, "jaw": 0.25}])],
		[3.0, M([_princess(0.4, 1.02, 0.35, 0.75, 0.42), {"jaw": 0.0, "face": "smile"}]), "s"],
		[3.4, M([_princess(0.25, 1.0, 0.35, 0.7, 0.3)])],
		[3.9, M([_princess(0.25, 1.0, 0.35, 0.7, 0.28), KL(2.0, 0.2)])],
		[4.15, M([KL(1.62, 0.2), KR(1.95, 0.25)])],
		[4.4, M([_princess(0.22, 1.02, 0.38, 0.95, 0.0), {"face": "calm"}])],
		[5.0, M([_princess(0.24, 1.0, 0.38, 0.95, -0.02)])],
		[5.4, M([_princess(0.2, 1.0, 0.3, 0.3, 0.3), {"face": "smile"}]), "s"],
		[6.0, M([_princess(0.25, 1.0, 0.35, 0.7, 0.3)])],
	]}

	c["carry_bleuette"] = {"len": 6.0, "loop": true, "loop_from": 3.4, "add": true, "in": 0.0, "face": "determined", "keys": [
		[0.0, M([B(0.0), C(0.0), HD(0.0), _sonic_l(), _sonic_r()])],
		[0.07, M([B(0.06), HD(-0.05), L(0.35, -0.5, 0.5, 0.2), R(0.35, -0.55, 0.5, 0.2), WL(0.0), WR(0.0), {"curl": 0.2, "curl_l": 0.2}])],
		[0.16, M([B(-0.06), C(-0.04), HD(0.05), L(0.3, -0.4, 0.6, 0.2), R(0.35, -0.45, 0.55, 0.2), {"curl": 0.8, "curl_l": 0.8, "ev": "effort", "fx": "whoosh"}]), "s"],
		[0.3, M([B(0.08), C(0.04), HD(-0.06), {"sq": 0.96}])],
		[0.5, M([B(0.0), C(0.0), HD(-0.3, 0.35, 0.0), {"sq": 1.0}])],
		[0.8, M([HD(0.0, 0.05, 0.0)])],
		[2.6, M([HD(0.0, 0.05, 0.0)])],
		[3.0, M([HD(-0.32, 0.4, 0.05), {"face": "grin"}]), "s"],
		[3.4, M([HD(0.0, 0.05, 0.0)])],
		[5.2, M([HD(0.0, 0.05, 0.0), {"face": "determined"}])],
		[5.5, M([HD(-0.3, 0.38, 0.05), {"face": "grin"}]), "s"],
		[6.0, M([HD(0.0, 0.05, 0.0)])],
	]}


# --------------------------------------------------------------------------------------------------------
# ELLY : elle saute sur son dos, jambes repliées en jockey, se redresse, se retourne et braque son fusil vers
# l'arrière pour le couvrir (repère d'Elly = buste de Simon, incliné : son « haut » suit le dos de Simon).

# twist = rotation vers sa droite (vers l'arrière de la course), look = tête tournée en plus, sway = balancement.
static func _rider(twist: float, look: float, sway: float = 0.0) -> Dictionary:
	return M([{"gait": 0.0, "plant": 0.0}, TL(1.4, 0.55), KL(2.0, 0.4), TR(1.35, 0.55), KR(2.05, 0.4), H(0.0, 0.0, 0.0),
		B(-0.5 * twist + 0.05 * (1.0 - twist), -0.2 * twist, 0.04 * sway), C(0.0, -0.72 * twist, 0.1 * twist), HD(0.15 * look, -1.0 * look, 0.15 * look)])

static func _elly(c: Dictionary) -> void :
	c["carried_elly"] = {"len": 3.6, "loop": true, "loop_from": 0.9, "in": 0.0, "face": "focus", "keys": [
		[0.0, M([_standing(false), TL(0.0, 0.05), KL(0.1), TR(0.0, 0.05), KR(0.1)])],
		[0.07, M([TL(0.5, 0.15), KL(0.9), TR(0.5, 0.15), KR(0.9), H(0.0, -0.12, 0.0), B(0.35), HD(0.3), L(0.45, -0.6, -0.4, 0.3), R(0.45, -0.6, -0.4, 0.3), {"sq": 0.93}])],
		[0.16, M([TL(1.2, 0.4), KL(1.6), TR(1.15, 0.4), KR(1.65), H(0.0, 0.0, 0.0), B(0.2), HD(0.15), L(0.2, 0.3, 0.7, 0.3), R(0.35, -0.1, 0.6, 0.3), {"sq": 1.06, "ev": "effort"}]), "s"],
		[0.3, M([_rider(0.0, 0.0), L(0.1, 0.4, 0.8, 0.4), R(0.3, -0.5, 0.4, 0.2), {"sq": 0.96}])],
		[0.45, M([_rider(0.2, 0.1), R(0.35, -0.65, 0.1, 0.2), WR(0.0), {"prop": "shotgun", "curl": 1.0, "sq": 1.0}])],
		[0.6, M([R(0.32, -0.6, 0.0, 0.2), {"fx": "glint"}]), "s"],
		[0.78, M([_rider(0.8, 0.8), R(0.3, -0.5, -0.5, 0.1)])],
		[0.9, M([_rider(1.0, 1.0), R(0.28, -0.5, -0.55, 0.1), {"face": "focus"}])],
		[1.5, M([_rider(1.0, 1.05, 0.5)])],
		[2.1, M([_rider(0.9, 0.95, -0.4), {"face": "calm"}])],
		# Un coup d'œil devant (« à gauche ! »), le fusil reste braqué derrière.
		[2.45, M([_rider(0.4, 0.15, 0.0), {"face": "focus"}]), "s"],
		[2.8, M([_rider(1.0, 1.0, 0.2)])],
		[3.6, M([_rider(1.0, 1.0, 0.0), R(0.28, -0.5, -0.55, 0.1)])],
	]}

	c["carry_elly"] = {"len": 3.6, "loop": true, "loop_from": 0.9, "add": true, "in": 0.0, "face": "determined", "keys": [
		[0.0, M([B(0.0), C(0.0), HD(0.0), _sonic_r(), _sonic_l()])],
		# Bras gauche libre : toujours « Sonic », mais plus écarté (le genou gauche d'Elly est contre son flanc).
		[0.3, M([L(0.74, -0.38, -0.6), WL(0.25, 0.35, 0.0)])],
		[0.08, M([C(0.0, -0.12, 0.0), HD(0.05, -0.4, 0.0), R(0.45, -0.55, -0.55), WR(0.0), {"curl": 0.1}])],
		[0.22, M([B(0.12), C(0.06, -0.06, 0.0), HD(-0.08, -0.15, 0.0), {"curl": 0.9, "sq": 0.95, "ev": "effort"}]), "s"],
		[0.4, M([B(0.04), C(0.02, 0.0, 0.0), HD(0.0, 0.0, 0.0), {"sq": 1.0}])],
		[0.9, M([B(0.04), C(0.02), HD(0.0)])],
		[2.3, M([B(0.04), C(0.02), HD(0.0), {"fx": "sweat"}])],
		[2.5, M([B(0.04), C(0.02, -0.1, 0.0), HD(0.08, -0.45, 0.0)]), "s"],
		[2.8, M([B(0.04), C(0.02), HD(0.0)])],
		[3.6, M([B(0.04), C(0.02), HD(0.0)])],
	]}


# --------------------------------------------------------------------------------------------------------
# USAYUKO (plus lourd, vitesse × 0,85) : Simon l'attrape par la cheville en passant. Il part en arrière, tombe
# sur le dos et se laisse traîner, la jambe gauche tendue dans la main de Simon, les mains derrière la tête
# comme sur un transat… et fait coucou à Alice, la tête à l'envers.

# Couché sur le dos (tête vers l'arrière de la course), bassin au ras du sol, jambe gauche (côté Simon) levée vers
# sa main, jambe droite écartée qui traîne au sol. bump = cahot (le dos rebondit), lift = tête relevée vers Simon.
static func _lounge(bump: float = 0.0, lift: float = 0.0) -> Dictionary:
	return M([{"gait": 0.0, "plant": 0.0}, H(0.0, -1.2 + 0.04 * bump, 0.0), B(-1.46 + 0.05 * bump, 0.0, 0.0), C(0.12 + 0.05 * lift, 0.0, 0.0), HD(-0.2 - 0.35 * lift, 0.0, 0.0),
		TL(0.95, -0.04), KL(0.06, 0.2), TR(0.16, 0.3), KR(0.35, 0.3),
		Lt(0.16, 1.05, -0.25, 1.0), Rt(0.16, 1.05, -0.25, 1.0), WL(0.5), WR(0.5), {"curl": 0.4, "curl_l": 0.4, "sq": 1.0}])

static func _usayuko(c: Dictionary) -> void :
	c["carried_usayuko"] = {"len": 4.2, "loop": true, "loop_from": 1.0, "in": 0.0, "face": "surprise", "keys": [
		[0.0, M([_standing(true), {"curl": 0.6, "curl_l": 0.6}])],
		# La cheville part vers l'avant, il bascule en arrière, bras en l'air.
		[0.07, M([{"plant": 0.0}, TL(0.95, 0.0), KL(0.1), TR(0.05), KR(0.15), H(0.0, -0.1, 0.0), B(-0.4), HD(0.3), L(0.6, 0.6, 0.3, 0.6), R(0.55, 0.7, 0.2, 0.6),
			{"curl": 0.0, "curl_l": 0.0, "jaw": 0.8, "sq": 1.06, "face": "panic", "ev": "gasp"}])],
		[0.18, M([H(0.0, -0.55, 0.0), B(-1.0), TL(0.92, 0.0), TR(0.6, 0.2), KR(0.9), L(0.7, 0.5, -0.2, 0.6), R(0.6, 0.6, 0.1, 0.6), HD(0.4)]), "s"],
		[0.3, M([_lounge(1.0), HD(0.35), L(0.8, 0.2, 0.1, 0.5), R(0.8, 0.1, 0.2, 0.5), {"sq": 0.9, "jaw": 0.4, "face": "pain", "fx": "dust"}])],
		[0.48, M([_lounge(0.0), HD(-0.1), L(0.8, 0.15, 0.1, 0.5), R(0.82, 0.1, 0.15, 0.5), {"sq": 1.0, "jaw": 0.1, "face": "dazed"}])],
		[0.75, M([_lounge(0.0), {"face": "neutral", "jaw": 0.0}])],
		[1.0, M([_lounge(0.0), {"face": "grin"}])],
		[1.4, M([_lounge(1.0), {"fx": "dust"}])],
		[1.55, _lounge(0.0)],
		[2.0, M([_lounge(0.0, 1.0), {"face": "grin"}])],
		# Coucou à Alice, la tête renversée en arrière.
		[2.35, M([_lounge(0.0), HD(0.55), {"face": "laugh"}])],
		[2.5, M([Rt(0.55, 1.25, 0.35, 0.3), WR(0.0, 0.0, 0.6), {"curl": 0.0}])],
		[2.65, M([WR(0.0, 0.0, -0.6)])],
		[2.8, M([WR(0.0, 0.0, 0.6)])],
		[2.95, M([WR(0.0, 0.0, -0.6)])],
		[3.15, M([_lounge(0.0), HD(-0.2), {"face": "grin", "curl": 0.4}])],
		[3.6, M([_lounge(0.7), {"fx": "dust"}])],
		[3.75, _lounge(0.0)],
		[4.2, M([_lounge(0.0), {"face": "grin"}])],
	]}

	c["carry_usayuko"] = {"len": 4.2, "loop": true, "loop_from": 1.0, "add": true, "in": 0.0, "face": "determined", "keys": [
		[0.0, M([B(0.0), C(0.0), HD(0.0), _sonic_r(), {"curl": 0.2}])],
		[0.05, M([C(0.0, -0.12, 0.0), HD(0.05, -0.45, 0.0), R(0.55, -0.62, -0.55), WR(0.0), {"curl": 0.0}])],
		[0.12, M([C(0.0, -0.16, 0.0), HD(0.05, -0.5, 0.0), {"curl": 1.0}]), "s"],
		[0.2, M([B(-0.12, -0.06, 0.0), C(-0.06, -0.12, 0.0), HD(0.15, -0.2, 0.0), {"ev": "effort", "sq": 0.95, "face": "pain"}])],
		[0.42, M([B(0.1), C(0.05), HD(-0.05), {"sq": 1.0, "face": "determined"}])],
		[1.0, M([B(0.08), C(0.04), HD(-0.05), {"shake": 0.12}])],
		[1.7, M([B(0.08), C(0.04), HD(-0.05), {"fx": "sweat"}])],
		[2.1, M([B(0.08), C(0.04, -0.12, 0.0), HD(0.08, -0.5, 0.0), {"face": "angry"}]), "s"],
		[2.5, M([B(0.08), C(0.04), HD(-0.05), {"face": "determined"}])],
		[3.4, M([B(0.08), C(0.04), HD(-0.05), {"fx": "sweat"}])],
		[4.2, M([B(0.08), C(0.04), HD(-0.05), {"shake": 0.12}])],
	]}
