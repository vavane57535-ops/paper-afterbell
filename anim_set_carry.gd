extends "res://anim_pose.gd"

# Portages de Simon pendant la course éclair (0.17), un par allié (voir carry_rig.gd pour le placement).
#   carry_<allié>    : Simon (additif sur la course « Sonic » : buste, tête, bras qui tiennent ; jambes procédurales).
#   carried_<allié>  : l'allié porté (pose complète). Les deux clips partagent la même horloge (celle de Simon) :
#   0 = l'instant de la prise, puis une boucle longue (loop_from) pour que rien ne se répète trop visiblement.
#   released_<allié> : l'allié lâché (action jouée par character_visual.gd à la dépose).
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
	return M([L(0.44, -0.26, -0.86), WL(-0.3, 0.0, 0.0), {"curl_l": 0.04}])

static func _sonic_r() -> Dictionary:
	return M([R(0.44, -0.26, -0.86), WR(-0.3, 0.0, 0.0), {"curl": 0.04}])


# --------------------------------------------------------------------------------------------------------
# ASHURA : Simon le tire par la main gauche ; Ashura se laisse tracter sur ses rollers, accroupi en patineur de
# vitesse, le bras libre en balancier (ou replié dans le dos quand il se met en boule).

# shift = transfert d'appui (+ = sur le pied gauche), dip = flexion en plus, lead = avance du pied droit (négatif :
# le gauche devant), back = bras libre replié dans le dos (0 = écarté en balancier).
static func _skate(shift: float = 0.0, dip: float = 0.0, lead: float = 0.14, back: float = 0.0) -> Dictionary:
	var free: Dictionary = M([L(0.86, 0.06, -0.3, 0.3), WL(0.2, 0.0, -0.2), {"curl_l": 0.25}])
	if back > 0.5: free = M([Lt(-0.22, -0.82, -0.46, 0.7), WL(-0.4, 0.0, 0.3), {"curl_l": 0.55}])
	return M([{"gait": 0.0, "plant": 1.0}, FL(0.13, - lead * 0.5, 0.0), FR(0.13, lead * 0.5, 0.0),
		H(-0.05 * shift, -0.38 - dip, -0.06), B(0.56 + 0.5 * dip, -0.1, 0.06 * shift), C(0.12 + 0.3 * dip, -0.18, 0.02 * shift), HD(0.5 - 0.3 * dip, 0.15, -0.04 * shift),
		R(0.32, -0.42, 0.82, 0.1), WR(0.0), free, {"fp_l": 0.0, "fp_r": 0.0, "curl": 0.9, "sq": 1.0}])

# Simon tient Ashura de la main gauche, bras tendu en arrière vers lui (l'autre bras reste « Sonic »).
static func _hold_ashura() -> Dictionary:
	return M([L(0.62, -0.42, -0.66), WL(0.1, 0.4, 0.0), {"curl_l": 0.9}])

static func _ashura(c: Dictionary) -> void :
	c["carried_ashura"] = {"len": 6.0, "loop": true, "loop_from": 1.0, "in": 0.0, "face": "surprise", "keys": [
		# Simon lui happe la main droite au passage.
		[0.0, M([{"gait": 0.0, "plant": 1.0}, FLR(0.1, 0.0), H(0.0, -0.06, 0.0), B(0.1), C(0.0, -0.1), HD(0.12, -0.35), R(0.45, -0.3, 0.75, 0.1), L(0.35, -0.75, 0.1, 0.1),
			WL(0.0), WR(0.0), {"fp_l": 0.0, "fp_r": 0.0, "curl": 0.1, "curl_l": 0.3, "jaw": 0.25, "sq": 1.0}])],
		# L'à-coup : le bras est tiré, l'épaule droite part devant, la tête reste en arrière, le bras gauche est projeté
		# derrière ; les roues crissent.
		[0.1, M([FL(0.12, -0.18, 0.0), FR(0.14, 0.1, 0.0), H(0.03, -0.18, 0.06), B(0.32, 0.0, 0.05), C(0.08, -0.32, 0.0), HD(-0.12, 0.25, 0.08),
			L(0.55, 0.25, -0.7, 0.4), {"curl": 0.95, "curl_l": 0.0, "jaw": 0.55, "sq": 0.95, "face": "panic", "ev": "gasp", "fx": "skate_sparks"}]), "s"],
		# Il encaisse en pliant les genoux, le bras gauche s'ouvre pour l'équilibre.
		[0.22, M([FL(0.13, -0.1, 0.0), FR(0.13, 0.08, 0.0), H(-0.02, -0.34, -0.02), B(0.5, -0.05, 0.02), C(0.12, -0.24, 0.0), HD(0.42, 0.05, 0.0),
			L(0.92, 0.25, -0.2, 0.4), {"jaw": 0.15, "sq": 1.03, "face": "surprise"}])],
		# Un peu trop bas (amorti), puis il se cale.
		[0.36, M([_skate(0.0, 0.07, 0.14), {"sq": 0.98}])],
		[0.52, M([_skate(0.0, -0.01, 0.14), {"face": "calm", "jaw": 0.0}])],
		# Coup d'œil à Simon, demi-sourire (Ashura ne s'emballe pas).
		[0.75, M([_skate(0.1, 0.0, 0.14), C(0.12, -0.3), HD(0.45, -0.45, -0.05), {"face": "smile"}]), "s"],
		[1.0, _skate(0.0, 0.0, 0.14)],
		# Boucle : appui à gauche, appui à droite (étincelles), position de vitesse main dans le dos, regard vers Alice,
		# changement de pied, petite bosse sautée, retour.
		[1.6, M([_skate(0.9, 0.02, 0.12), {"face": "calm"}])],
		[2.2, M([_skate(-0.7, 0.0, 0.16), {"fx": "skate_sparks"}])],
		[2.6, M([_skate(0.0, 0.08, 0.14, 1.0), {"face": "focus"}])],
		[3.3, M([_skate(0.2, 0.1, 0.14, 1.0)])],
		[3.6, M([_skate(0.0, 0.02, 0.14), C(0.08, 0.3), HD(0.35, 0.95, 0.05), L(0.95, 0.15, 0.1, 0.4), {"face": "smile"}]), "s"],
		[4.0, M([_skate(0.0, 0.0, 0.12), {"face": "calm"}])],
		[4.35, M([_skate(0.3, 0.02, -0.14), {"fx": "skate_sparks"}])],
		[4.85, M([_skate(0.0, 0.1, -0.14), {"sq": 0.96}])],
		[5.0, M([_skate(0.0, -0.08, -0.14), FL(0.13, 0.07, 0.12), FR(0.13, -0.07, 0.12), {"sq": 1.04}])],
		[5.14, M([_skate(0.0, 0.08, -0.14), {"sq": 0.96, "fx": "skate_sparks"}]), "s"],
		[5.4, M([_skate(-0.3, 0.0, 0.0), {"sq": 1.0}])],
		[6.0, _skate(0.0, 0.0, 0.14)],
	]}

	c["carry_ashura"] = {"len": 6.0, "loop": true, "loop_from": 1.0, "add": true, "in": 0.0, "face": "grin", "keys": [
		[0.0, M([B(0.0), C(0.0), HD(0.0), _sonic_l(), {"curl_l": 0.1}])],
		# Il tend le bras gauche vers Ashura en le regardant, main ouverte…
		[0.04, M([C(0.0, 0.14, 0.0), HD(0.0, 0.62, 0.0), L(0.78, -0.3, -0.52), WL(0.0), {"curl_l": 0.0}])],
		# …la referme sur la sienne et tire (à-coup dans l'épaule, le buste se redresse un instant).
		[0.1, M([C(0.0, 0.2, 0.0), HD(0.04, 0.66, 0.0), L(0.7, -0.38, -0.6), {"curl_l": 0.95, "ev": "effort"}]), "s"],
		[0.18, M([B(-0.07, 0.04, 0.0), C(0.02, 0.22, 0.0), HD(0.08, 0.45, 0.0), L(0.64, -0.42, -0.65), {"sq": 0.97}])],
		[0.4, M([B(0.0), C(0.0, 0.1, 0.0), HD(0.0, 0.08, 0.0), _hold_ashura(), {"sq": 1.0}])],
		[1.0, M([B(0.0), C(0.0, 0.1, 0.0), HD(0.0, 0.0, 0.0), _hold_ashura()])],
		[2.3, M([C(0.0, 0.1, 0.0), HD(0.0, 0.0, 0.0)])],
		# Coup d'œil derrière : « ça va ? »
		[2.55, M([C(0.0, 0.18, 0.0), HD(0.05, 0.65, 0.0), {"face": "grin"}]), "s"],
		[2.95, M([C(0.0, 0.1, 0.0), HD(0.0, 0.0, 0.0)])],
		[4.6, M([C(0.0, 0.1, 0.0), HD(0.0, 0.0, 0.0), {"face": "determined"}])],
		[4.85, M([C(0.0, 0.12, 0.0), HD(0.05, 0.3, 0.0)]), "s"],
		[5.3, M([C(0.0, 0.1, 0.0), HD(0.0, 0.0, 0.0), {"face": "grin"}])],
		[6.0, M([B(0.0), C(0.0, 0.1, 0.0), HD(0.0, 0.0, 0.0), _hold_ashura()])],
	]}

	# Lâché : il se redresse sur ses roues en écartant les bras, dérape un peu, puis se remet droit, l'air de rien.
	c["released_ashura"] = {"len": 0.75, "in": 0.0, "out": 0.25, "face": "surprise", "keys": [
		[0.0, M([_skate(0.0, 0.0, 0.14), {"curl": 0.4}])],
		[0.12, M([{"gait": 0.0, "plant": 1.0}, FL(0.15, -0.05, 0.0), FR(0.15, 0.08, 0.0), H(0.0, -0.22, 0.04), B(0.18, 0.0, -0.04), C(0.0, 0.1), HD(0.15, -0.2),
			L(0.9, 0.2, 0.15, 0.4), R(0.9, 0.25, 0.1, 0.4), WL(0.0), WR(0.0), {"curl": 0.2, "curl_l": 0.2, "sq": 1.02, "fx": "skate_sparks"}])],
		[0.32, M([FL(0.12, -0.02, 0.0), FR(0.12, 0.04, 0.0), H(0.0, -0.08, 0.0), B(0.02, 0.0, 0.03), C(0.0, 0.0), HD(0.05, 0.1), L(0.7, -0.2, 0.1, 0.3), R(0.75, -0.15, 0.05, 0.3), {"face": "calm"}])],
		[0.52, M([FLR(0.1, 0.0), H(0.0, -0.03, 0.0), B(0.03), C(0.0), HD(0.03, 0.25), LR(0.34, -0.85, 0.08, 0.1), {"face": "smile"}])],
		[0.75, M([{"gait": 1.0, "plant": 0.0}, rest(), LR(0.32, -0.9, 0.06, 0.1)])],
	]}


# --------------------------------------------------------------------------------------------------------
# BLEUETTE : portée « en princesse » (bras gauche de Simon sous son dos, bras droit sous ses genoux).
# Elle crie, s'agrippe à son cou en tremblant, les yeux fermés… ose regarder la route, puis lui, et finit rassurée,
# la tête contre son épaule, les pieds qui se balancent.
# Son repère : elle regarde vers la droite de Simon ; sa droite est contre lui, son dos vers sa gauche.

# Couchée en travers des bras de Simon : buste renversé (recline), tourné vers lui (turn), cuisses à peu près à
# l'horizontale, tibias qui pendent. curl = genoux remontés contre elle (peur), swing = balancement des pieds.
static func _princess(curl: float, recline: float, turn: float, head_turn: float, head_up: float, swing: float = 0.0) -> Dictionary:
	return M([{"gait": 0.0, "plant": 0.0}, TL(0.55 + 0.35 * curl, 0.06), KL(1.55 + 0.3 * curl - 0.25 * swing, 0.25), TR(0.5 + 0.35 * curl, 0.0), KR(1.5 + 0.3 * curl + 0.25 * swing, 0.3),
		H(0.0, -0.22, 0.0), B(- recline, 0.0, 0.0), C(0.14 + 0.12 * curl, - turn, 0.0), HD(head_up, - head_turn, 0.12)])

# Main gauche de Bleuette : contre sa bouche (peur), sur sa poitrine, ou posée sur ses genoux (rassurée).
static func _bleu_left(where: float) -> Dictionary:
	if where < 0.5: return M([Lt(-0.25, 0.35, 0.55, 0.6), WL(-0.6, 0.0, 0.0), {"curl_l": 0.8}])
	if where < 1.5: return M([Lt(-0.2, -0.05, 0.45, 0.5), WL(-0.2, 0.0, 0.0), {"curl_l": 0.6}])
	return M([L(0.15, -0.6, 0.55, 0.3), WL(0.2, 0.0, 0.0), {"curl_l": 0.3}])

static func _bleuette(c: Dictionary) -> void :
	c["carried_bleuette"] = {"len": 6.0, "loop": true, "loop_from": 3.4, "in": 0.0, "face": "surprise", "keys": [
		[0.0, M([{"gait": 0.0, "plant": 1.0}, FLR(0.08, 0.0), H(0.0, -0.03, 0.0), B(0.05), C(0.0), HD(0.04), L(0.32, -0.82, 0.1), R(0.32, -0.82, 0.1),
			WL(0.0), WR(0.0), TL(0.05), KL(0.1), TR(0.05), KR(0.1), {"fp_l": 0.0, "fp_r": 0.0, "curl": 0.35, "curl_l": 0.35, "jaw": 0.0, "sq": 1.0}])],
		# Soulevée d'un coup : les jambes partent, elle hurle, les bras en l'air.
		[0.08, M([{"plant": 0.0}, TL(0.75, 0.1), KL(0.6), TR(0.6, 0.05), KR(0.5), H(0.0, -0.08, 0.0), B(-0.45), C(-0.1), HD(0.35, 0.1), L(0.7, 0.5, 0.2, 0.5), R(0.55, 0.65, 0.15, 0.5),
			{"curl": 0.0, "curl_l": 0.0, "jaw": 0.7, "face": "panic", "ev": "gasp"}])],
		[0.18, M([TL(0.85, 0.15), KL(1.2), TR(0.8, 0.05), KR(1.0), H(0.0, -0.16, 0.0), B(-0.9), C(0.05), HD(0.4, -0.3, 0.1), L(0.5, 0.6, 0.3, 0.6), R(0.2, 0.6, 0.55, 0.6), {"jaw": 0.9, "sq": 1.04}]), "s"],
		# Elle se recroqueville et s'agrippe, yeux fermés, elle tremble.
		[0.32, M([_princess(1.0, 1.0, 0.3, 0.6, 0.0), _bleu_left(0.0), R(0.1, 0.5, 0.6, 0.6), {"jaw": 0.45, "shake": 0.5, "curl": 0.9, "sq": 0.95}])],
		[0.5, M([_princess(1.0, 0.98, 0.42, 0.9, -0.15), {"jaw": 0.0, "shake": 0.45, "sq": 1.0, "face": "pain"}])],
		[1.2, M([_princess(0.95, 1.0, 0.44, 0.95, -0.12), {"shake": 0.4}])],
		[1.8, M([_princess(1.0, 0.97, 0.42, 0.92, -0.18), {"shake": 0.35}])],
		# Elle ose ouvrir un œil, regarde la route défiler… puis lui.
		[2.2, M([_princess(0.85, 1.0, 0.3, 0.45, 0.1), _bleu_left(1.0), {"shake": 0.15, "face": "surprise"}]), "s"],
		[2.6, M([_princess(0.6, 1.02, 0.25, 0.15, 0.3), {"shake": 0.0, "jaw": 0.25}])],
		[3.0, M([_princess(0.4, 1.02, 0.36, 0.75, 0.42), {"jaw": 0.0, "face": "smile"}]), "s"],
		# Rassurée : la tête contre son épaule, la main posée, les pieds qui se balancent.
		[3.4, M([_princess(0.25, 1.0, 0.4, 0.8, 0.2), _bleu_left(2.0)])],
		[3.9, M([_princess(0.25, 1.0, 0.4, 0.82, 0.18, 1.0)])],
		[4.4, M([_princess(0.22, 1.02, 0.42, 0.95, 0.05, -1.0), {"face": "calm"}])],
		[4.9, M([_princess(0.24, 1.0, 0.4, 0.9, 0.08, 0.6)])],
		[5.4, M([_princess(0.2, 1.0, 0.32, 0.35, 0.3, -0.4), {"face": "smile"}]), "s"],
		[6.0, M([_princess(0.25, 1.0, 0.4, 0.8, 0.2), _bleu_left(2.0)])],
	]}

	c["carry_bleuette"] = {"len": 6.0, "loop": true, "loop_from": 3.4, "add": true, "in": 0.0, "face": "determined", "keys": [
		[0.0, M([B(0.0), C(0.0), HD(0.0), _sonic_l(), _sonic_r()])],
		# Il ramène les deux bras devant et plonge un peu pour la cueillir…
		[0.06, M([B(0.1), HD(-0.08, 0.2, 0.0), L(0.35, -0.6, 0.45, 0.2), R(0.35, -0.62, 0.45, 0.2), WL(0.0), WR(0.0), {"curl": 0.2, "curl_l": 0.2}])],
		# …et la soulève (effort), le buste se redresse.
		[0.16, M([B(-0.08), C(-0.04), HD(0.05, 0.1, 0.0), L(0.3, -0.4, 0.6, 0.2), R(0.35, -0.45, 0.55, 0.2), {"curl": 0.8, "curl_l": 0.8, "ev": "effort"}]), "s"],
		[0.3, M([B(0.04), C(0.02), HD(-0.06, 0.0, 0.0), {"sq": 0.96}])],
		[0.5, M([B(0.0), C(0.0), HD(-0.25, 0.35, 0.0), {"sq": 1.0}])],
		[0.8, M([HD(0.0, 0.05, 0.0)])],
		[2.6, M([HD(0.0, 0.05, 0.0)])],
		# Il baisse les yeux vers elle quand elle le regarde.
		[3.0, M([HD(-0.3, 0.4, 0.05), {"face": "grin"}]), "s"],
		[3.4, M([HD(0.0, 0.05, 0.0)])],
		[5.2, M([HD(0.0, 0.05, 0.0), {"face": "determined"}])],
		[5.5, M([HD(-0.28, 0.36, 0.05), {"face": "grin"}]), "s"],
		[6.0, M([HD(0.0, 0.05, 0.0)])],
	]}

	# Posée : elle retombe sur ses pieds, vacille, se rattrape les bras écartés, souffle.
	c["released_bleuette"] = {"len": 0.8, "in": 0.0, "out": 0.25, "face": "surprise", "keys": [
		[0.0, M([_princess(0.3, 0.9, 0.3, 0.6, 0.1), L(0.4, -0.3, 0.3, 0.3), R(0.4, -0.3, 0.3, 0.3)])],
		[0.14, M([{"gait": 0.0, "plant": 0.0}, TL(0.5, 0.1), KL(0.7), TR(0.4, 0.05), KR(0.6), H(0.0, -0.05, 0.0), B(-0.1), C(0.1), HD(0.1), L(0.7, 0.2, 0.2, 0.5), R(0.7, 0.25, 0.2, 0.5), {"curl": 0.1, "curl_l": 0.1}])],
		[0.26, M([{"plant": 1.0}, TL(0.15), KL(0.6), TR(0.1), KR(0.5), FLR(0.12, 0.0), H(0.0, -0.18, 0.0), B(0.25), C(0.15), HD(-0.1), L(0.8, 0.0, 0.25, 0.4), R(0.85, 0.05, 0.2, 0.4), {"sq": 0.92, "fx": "dust"}]), "s"],
		[0.42, M([H(0.0, -0.05, 0.0), B(-0.05, 0.05, 0.06), C(0.0), HD(0.1, 0.1, 0.05), L(0.75, 0.15, 0.1, 0.4), R(0.6, -0.1, 0.15, 0.3), {"sq": 1.02, "face": "fear"}])],
		[0.62, M([H(0.0, -0.03, 0.0), B(0.08), C(0.04), HD(-0.08, -0.1, 0.0), LR(0.3, -0.75, 0.25, 0.2), {"sq": 1.0, "face": "smile"}])],
		[0.8, M([{"gait": 1.0}, rest(), LR(0.32, -0.85, 0.1, 0.1), TL(0.0), KL(0.0), TR(0.0), KR(0.0)])],
	]}


# --------------------------------------------------------------------------------------------------------
# ELLY : au passage, elle saute sur les reins de Simon et s'y assoit à l'envers, comme une tourelle, les cuisses de
# part et d'autre de ses hanches (que Simon tient, bras « Sonic » tendus en arrière) ; elle sort son fusil, l'arme,
# et couvre leurs arrières. Repère d'Elly : face à l'arrière de la course.

# Assise à califourchon, buste droit : twist = rotation du buste (+ = vers sa gauche), sway = balancement,
# look = tête tournée vers l'avant de la course (par-dessus son épaule).
static func _turret(twist: float = 0.0, sway: float = 0.0, look: float = 0.0) -> Dictionary:
	return M([{"gait": 0.0, "plant": 0.0}, TL(0.95, 0.42), KL(1.5, 0.3), TR(0.95, 0.42), KR(1.5, 0.3), H(0.0, 0.0, 0.0),
		B(0.06, 0.0, 0.04 * sway), C(0.0, 0.15 * twist, - 0.03 * sway), HD(0.04, 0.05 * twist + 1.6 * look, 0.02 * sway)])

# Fusil épaulé, braqué vers l'arrière de la course (l'IK de visée termine l'orientation dans carry_finalize).
static func _aim_gun(rise: float = 0.0) -> Dictionary:
	return M([R(0.08, 0.02 + 0.1 * rise, 0.62, 0.6), WR(0.0), L(-0.12, -0.02 + 0.1 * rise, 0.9, 0.3), WL(0.0), {"curl": 1.0, "curl_l": 0.75, "prop": "shotgun"}])

static func _elly(c: Dictionary) -> void :
	c["carried_elly"] = {"len": 5.4, "loop": true, "loop_from": 1.3, "in": 0.0, "face": "focus", "keys": [
		[0.0, M([{"gait": 0.0, "plant": 1.0}, FLR(0.08, 0.0), H(0.0, -0.04, 0.0), B(0.05), C(0.0), HD(0.04, 0.2), L(0.32, -0.82, 0.1), R(0.32, -0.82, 0.1),
			WL(0.0), WR(0.0), TL(0.0), KL(0.05), TR(0.0), KR(0.05), {"fp_l": 0.0, "fp_r": 0.0, "curl": 0.35, "curl_l": 0.35, "sq": 1.0}])],
		# Elle se ramasse et bondit…
		[0.07, M([{"plant": 1.0}, H(0.0, -0.2, 0.0), B(0.35), C(0.1), HD(0.25, 0.4), L(0.4, -0.6, -0.4, 0.3), R(0.4, -0.6, -0.4, 0.3), TL(0.4), KL(0.9), TR(0.4), KR(0.9), {"sq": 0.92, "ev": "effort"}]), "s"],
		[0.16, M([{"plant": 0.0}, H(0.0, 0.05, 0.0), B(-0.1), C(-0.05), HD(0.1, 0.2), L(0.6, 0.5, 0.1, 0.5), R(0.6, 0.55, 0.0, 0.5), TL(0.6, 0.2), KL(1.1), TR(0.7, 0.2), KR(1.2), {"sq": 1.06}])],
		# …pivote en l'air et retombe assise à l'envers sur ses reins.
		[0.32, M([_turret(0.0, 0.0), L(0.7, 0.3, 0.3, 0.5), R(0.7, 0.3, 0.3, 0.5), {"sq": 1.0}])],
		[0.44, M([_turret(0.0, 0.0), H(0.0, -0.04, 0.0), B(0.16), L(0.5, -0.4, 0.3, 0.3), R(0.5, -0.4, 0.3, 0.3), {"sq": 0.93, "fx": "dust"}]), "s"],
		# Le fusil : elle le sort, l'arme (glissière), épaule et vise.
		[0.62, M([_turret(0.2, 0.0), H(0.0, 0.0, 0.0), B(0.06), R(0.35, -0.2, 0.2, 0.4), L(0.2, -0.3, 0.5, 0.3), {"prop": "shotgun", "curl": 1.0, "sq": 1.0}])],
		[0.82, M([R(0.1, 0.0, 0.55, 0.5), L(-0.05, -0.05, 0.62, 0.3), {"fx": "glint"}]), "s"],
		[0.92, M([L(-0.08, -0.05, 0.85, 0.3)])],
		[1.3, M([_turret(0.0, 0.0), _aim_gun(0.0), {"face": "focus"}])],
		# Boucle : elle suit la cible, un coup d'œil devant (« à gauche ! »), se recale, souffle.
		[1.9, M([_turret(0.5, 0.5), _aim_gun(0.2)])],
		[2.5, M([_turret(-0.4, -0.4), _aim_gun(-0.1)])],
		[2.75, M([_turret(-0.3, 0.0, 0.85), {"face": "calm"}]), "s"],
		[3.05, M([_turret(0.0, 0.0), _aim_gun(0.0), {"face": "focus"}])],
		[3.7, M([_turret(0.3, -0.3), _aim_gun(0.1)])],
		[4.4, M([_turret(-0.2, 0.4), _aim_gun(-0.05), {"face": "calm"}])],
		[5.4, M([_turret(0.0, 0.0), _aim_gun(0.0)])],
	]}

	c["carry_elly"] = {"len": 5.4, "loop": true, "loop_from": 1.3, "add": true, "in": 0.0, "face": "determined", "keys": [
		[0.0, M([B(0.0), C(0.0), HD(0.0), _sonic_r(), _sonic_l()])],
		# Il la voit bondir (coup d'œil), tend les mains derrière lui pour la rattraper…
		[0.08, M([HD(0.0, -0.45, 0.0), C(0.0, -0.1, 0.0)])],
		[0.3, M([HD(0.0, -0.2, 0.0), C(0.0, 0.0, 0.0), L(0.5, -0.35, -0.8), R(0.5, -0.35, -0.8), {"curl": 0.0, "curl_l": 0.0}])],
		# …encaisse son poids (le buste plonge un peu) et serre ses cuisses.
		[0.46, M([B(0.1), HD(-0.05, 0.0, 0.0), {"curl": 0.9, "curl_l": 0.9, "sq": 0.95, "ev": "effort"}]), "s"],
		[0.7, M([B(0.03), HD(0.0, 0.0, 0.0), {"sq": 1.0}])],
		[1.3, M([B(0.03), C(0.0), HD(0.0)])],
		# Quand elle crie « à gauche ! », il tourne la tête vers elle une seconde.
		[2.7, M([B(0.03), C(0.0), HD(0.0), {"face": "determined"}])],
		[2.9, M([B(0.03), C(0.0, -0.08, 0.0), HD(0.06, -0.4, 0.0), {"face": "surprise"}]), "s"],
		[3.2, M([B(0.03), C(0.0), HD(0.0), {"face": "grin"}])],
		[5.4, M([B(0.03), C(0.0), HD(0.0)])],
	]}

	# Elle saute de son dos, se réceptionne accroupie, fusil en main, et se relève.
	c["released_elly"] = {"len": 0.8, "in": 0.0, "out": 0.25, "face": "focus", "keys": [
		[0.0, M([_turret(0.0, 0.0), _aim_gun(0.0)])],
		[0.14, M([{"gait": 0.0, "plant": 0.0}, TL(0.6, 0.2), KL(1.0), TR(0.6, 0.2), KR(1.0), H(0.0, 0.0, 0.0), B(0.1), C(0.05), HD(0.0), R(0.4, -0.3, 0.3, 0.4), L(0.6, 0.2, 0.2, 0.4), {"prop": "shotgun", "curl_l": 0.2}])],
		[0.3, M([{"plant": 1.0}, TL(0.0), KL(0.0), TR(0.0), KR(0.0), FLR(0.14, 0.0), H(0.0, -0.3, 0.0), B(0.35), C(0.12), HD(0.3), R(0.35, -0.45, 0.3, 0.3), L(0.55, -0.3, 0.3, 0.3), {"sq": 0.9, "fx": "dust"}]), "s"],
		[0.55, M([H(0.0, -0.06, 0.0), B(0.06), C(0.02), HD(0.05, 0.3), R(0.3, -0.6, 0.15, 0.2), L(0.32, -0.8, 0.1, 0.1), {"sq": 1.0, "face": "calm"}])],
		[0.8, M([{"gait": 1.0}, rest(), LR(0.32, -0.85, 0.08, 0.1)])],
	]}


# --------------------------------------------------------------------------------------------------------
# USAYUKO (plus lourd, vitesse × 0,85) : Simon l'attrape par la cheville en passant. Il part en arrière, tombe sur le
# dos et se laisse traîner, la jambe gauche tendue dans la main de Simon, les hanches soulevées, les mains derrière
# la tête comme sur un transat… fait coucou à Alice la tête à l'envers, se prend en selfie, prend un cahot.

# Couché sur le dos, la tête vers l'arrière de la course : jambe gauche tendue vers la main de Simon (IK du pied),
# jambe droite pliée, talon qui traîne au sol. bump = cahot (le dos rebondit), lift = tête relevée.
static func _lounge(bump: float = 0.0, lift: float = 0.0) -> Dictionary:
	return M([{"gait": 0.0, "plant": 1.0}, FL(0.2, 0.62, 0.58), FR(0.28, 0.16, -0.08), H(0.0, -0.95 + 0.04 * bump, 0.12), B(-1.9 + 0.06 * bump, 0.0, 0.0), C(0.16 + 0.05 * lift, 0.0, 0.0), HD(-0.25 + 0.5 * lift, 0.0, 0.0),
		Lt(0.22, 0.95, -0.35, 1.0), Rt(0.22, 0.95, -0.35, 1.0), WL(0.6), WR(0.6), {"fp_l": 0.5, "fp_r": 0.2, "curl": 0.45, "curl_l": 0.45, "sq": 1.0}])

static func _usayuko(c: Dictionary) -> void :
	c["carried_usayuko"] = {"len": 6.0, "loop": true, "loop_from": 1.2, "in": 0.0, "face": "surprise", "keys": [
		[0.0, M([{"gait": 0.0, "plant": 1.0}, FLR(0.08, 0.0), H(0.0, -0.03, 0.0), B(0.05), C(0.0), HD(0.04), L(0.32, -0.82, 0.1), R(0.32, -0.82, 0.1),
			WL(0.0), WR(0.0), {"fp_l": 0.0, "fp_r": 0.0, "curl": 0.6, "curl_l": 0.6, "sq": 1.0}])],
		# La cheville part vers l'avant, il bascule en arrière, bras en l'air.
		[0.08, M([FL(0.15, 0.55, 0.45), FR(0.1, -0.1, 0.0), H(0.0, -0.15, 0.0), B(-0.55), C(0.0), HD(0.35), L(0.6, 0.6, 0.3, 0.6), R(0.55, 0.7, 0.2, 0.6),
			{"fp_l": 0.4, "curl": 0.0, "curl_l": 0.0, "jaw": 0.8, "sq": 1.06, "face": "panic", "ev": "gasp"}])],
		[0.2, M([FL(0.18, 0.6, 0.55), FR(0.2, 0.3, 0.3), H(0.0, -0.6, 0.05), B(-1.3), HD(0.4), L(0.7, 0.5, -0.2, 0.6), R(0.6, 0.6, 0.1, 0.6)]), "s"],
		# Le dos touche le sol (poussière), rebond…
		[0.3, M([_lounge(1.0), HD(0.3), L(0.8, 0.2, 0.1, 0.5), R(0.8, 0.1, 0.2, 0.5), {"sq": 0.9, "jaw": 0.4, "face": "pain", "fx": "dust"}])],
		[0.46, M([_lounge(0.0), HD(-0.1), L(0.8, 0.15, 0.1, 0.5), R(0.82, 0.1, 0.15, 0.5), {"sq": 1.0, "jaw": 0.1, "face": "dazed"}])],
		# …il comprend, hausse les épaules, croise les mains derrière la tête.
		[0.75, M([_lounge(0.0, 0.6), L(0.7, 0.4, 0.2, 0.5), R(0.7, 0.4, 0.2, 0.5), {"face": "neutral", "jaw": 0.0}])],
		[1.2, M([_lounge(0.0), {"face": "grin"}])],
		[1.6, M([_lounge(1.0), {"fx": "dust"}])],
		[1.75, _lounge(0.0)],
		# Coucou à Alice, la tête renversée en arrière.
		[2.2, M([_lounge(0.0, -0.4), {"face": "laugh"}])],
		[2.35, M([Rt(0.5, 1.2, 0.2, 0.3), WR(0.0, 0.0, 0.6), {"curl": 0.0}])],
		[2.5, M([WR(0.0, 0.0, -0.6)])],
		[2.65, M([WR(0.0, 0.0, 0.6)])],
		[2.8, M([WR(0.0, 0.0, -0.6)])],
		[3.0, M([_lounge(0.0), {"face": "grin", "curl": 0.45}])],
		# Selfie : le téléphone au-dessus du visage, deux doigts levés de l'autre main.
		[3.5, M([_lounge(0.0, 0.3), Rt(0.05, 0.4, 0.75, 0.3), WR(-0.8, 0.0, 0.0), Lt(0.3, 0.7, 0.4, 0.4), WL(0.0), {"prop": "phone", "curl": 0.7, "curl_l": 0.4, "face": "grin"}])],
		[4.2, M([_lounge(0.0, 0.32), Rt(0.05, 0.42, 0.75, 0.3), Lt(0.3, 0.75, 0.38, 0.4), {"prop": "phone", "face": "laugh"}])],
		[4.4, M([_lounge(0.0), {"prop": "", "face": "grin"}])],
		# Un cahot plus fort : « aïe », puis le sourire revient.
		[4.9, M([_lounge(1.0), {"fx": "dust", "face": "pain", "sq": 0.94}]), "s"],
		[5.1, M([_lounge(0.0), {"sq": 1.0}])],
		[5.5, M([_lounge(0.0), {"face": "grin"}])],
		[6.0, _lounge(0.0)],
	]}

	c["carry_usayuko"] = {"len": 6.0, "loop": true, "loop_from": 1.2, "add": true, "in": 0.0, "face": "determined", "keys": [
		[0.0, M([B(0.0), C(0.0), HD(0.0), _sonic_r(), {"curl": 0.2}])],
		# La main droite plonge vers sa cheville…
		[0.04, M([C(0.0, -0.12, 0.0), HD(0.05, -0.45, 0.0), R(0.55, -0.62, -0.55), WR(0.0), {"curl": 0.0}])],
		# …l'attrape : à-coup dans tout le corps (il est lourd).
		[0.12, M([C(0.0, -0.16, 0.0), HD(0.05, -0.5, 0.0), {"curl": 1.0}]), "s"],
		[0.2, M([B(-0.12, -0.06, 0.0), C(-0.06, -0.12, 0.0), HD(0.15, -0.2, 0.0), {"ev": "effort", "sq": 0.95, "face": "pain"}])],
		[0.45, M([B(0.1), C(0.05), HD(-0.05), {"sq": 1.0, "face": "determined"}])],
		[1.2, M([B(0.08), C(0.04), HD(-0.05), {"shake": 0.12}])],
		[1.8, M([B(0.08), C(0.04), HD(-0.05), {"fx": "sweat"}])],
		# Il entend « coucou » derrière lui : coup d'œil noir.
		[2.3, M([B(0.08), C(0.04, -0.12, 0.0), HD(0.08, -0.5, 0.0), {"face": "angry"}]), "s"],
		[2.7, M([B(0.08), C(0.04), HD(-0.05), {"face": "determined"}])],
		[3.6, M([B(0.08), C(0.04), HD(-0.05), {"fx": "sweat"}])],
		[4.95, M([B(0.12), C(0.04), HD(-0.08), {"face": "pain", "sq": 0.97}])],
		[5.2, M([B(0.08), C(0.04), HD(-0.05), {"face": "determined", "sq": 1.0}])],
		[6.0, M([B(0.08), C(0.04), HD(-0.05), {"shake": 0.12}])],
	]}

	# Lâché : il roule sur le côté et se relève d'un bond (kip-up raté de peu), puis s'étire.
	c["released_usayuko"] = {"len": 0.9, "in": 0.0, "out": 0.25, "face": "surprise", "keys": [
		[0.0, M([_lounge(0.0)])],
		[0.16, M([{"gait": 0.0, "plant": 1.0}, FL(0.18, 0.3, 0.3), FR(0.18, 0.25, 0.3), H(0.0, -0.85, 0.05), B(-1.5), C(0.3), HD(0.3), L(0.5, 0.6, -0.2, 0.5), R(0.5, 0.6, -0.2, 0.5), {"sq": 0.95}])],
		[0.32, M([FLR(0.14, 0.05, 0.0), H(0.0, -0.45, 0.1), B(0.2), C(0.3), HD(0.2), L(0.6, -0.3, 0.4, 0.3), R(0.6, -0.3, 0.4, 0.3), {"sq": 1.06, "ev": "effort", "fx": "dust"}]), "s"],
		[0.5, M([FLR(0.12, 0.0), H(0.0, -0.12, 0.0), B(0.05), C(0.0), HD(0.0, 0.2), L(0.5, 0.5, 0.0, 0.4), R(0.5, 0.5, 0.0, 0.4), {"sq": 1.0, "face": "grin"}])],
		[0.72, M([H(0.0, -0.03, 0.0), B(-0.06), C(-0.08), HD(0.15, 0.1), Lt(0.3, 0.9, 0.1, 0.5), Rt(0.3, 0.9, 0.1, 0.5), {"face": "laugh"}])],
		[0.9, M([{"gait": 1.0}, rest(), LR(0.32, -0.85, 0.08, 0.1)])],
	]}
