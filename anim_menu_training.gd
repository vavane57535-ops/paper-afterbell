extends "res://anim_menu_take.gd"

# TERRAIN D'ESSAI : le gymnase, la nuit. Usayuko boxe un mannequin en carton à la tête d'Alice,
# monté sur un ressort. Elly lit, assise sur le plinth, et ne lève pas les yeux… presque jamais.
# Usayuko : gouailleur, grands gestes, il frime, il encaisse mal. Elly : douce, directe, un sourcil.

# Usayuko regarde vers +x (lacet -90°), le mannequin lui fait face (lacet 90°).
const USA_AT: Vector3 = Vector3(0.6, 0.0, 1.0)
const USA_BACK: Vector3 = Vector3(0.16, 0.0, 0.94)
const DUMMY_AT: Vector3 = Vector3(1.1, 0.0, 1.0)
# Elly assise sur le plinth, tournée vers Usayuko et vers nous.
const ELLY_AT: Vector3 = Vector3(-1.35, 0.0, 2.25)
const ELLY_YAW: float = -38.0
const BOX_TOP: float = 0.88
const JAB_LEN: float = 32.5

# Instants des coups (le mannequin y réagit dans menu_scene_training.gd).
const JABS: Array = [2.62, 3.02]
const HAYMAKER: float = 9.92
const SMACK: float = 10.62
const SNAP_BACK: float = 22.45
const LATE_JABS: Array = [25.55, 26.0]
const FLICKER_OFF: float = 26.95
const FLICKER_ON: float = 27.5

static func writers(rigs: Dictionary) -> Array:
	return [
		func() -> Dictionary: return {"menu_training_jab@Usayuko": _jab_usa(rigs.usa)},
		func() -> Dictionary: return {"menu_training_jab@Elly": _jab_elly(rigs.elly)},
	]

static func shrug(amount: float, left: float = -1.0) -> Dictionary:
	var l: float = amount if left < 0.0 else left
	return {"l_clav": V(0.0, 0.0, -0.32 * l), "r_clav": V(0.0, 0.0, 0.32 * amount)}

# Garde de boxeur (gaucher en avant) : pied gauche devant, buste de trois quarts, gants au menton.
static func guard(bounce: float = 0.0, lean: float = 0.0) -> Dictionary:
	return M([start(), FL(0.06, 0.16, 0.0), FR(0.1, -0.16, 0.0), H(0.0, -0.05 + bounce, 0.0), B(0.08 + lean, -0.3, 0.0), C(0.06, -0.08, 0.0), HD(-0.08, 0.36, 0.0),
		L(0.12, 0.22, 0.5, 0.35), R(0.02, 0.24, 0.32, 0.3), WL(0.3, 0.0, 0.0), WR(0.3, 0.0, 0.0), CU(1.0), shrug(0.2), {"fp_l": -0.1, "fp_r": -0.25}])

# Usayuko : échauffement, deux directs, un crochet énorme… et le mannequin revient.
static func _jab_usa(rig: Dictionary) -> Dictionary:
	var k: Take = Take.new(JAB_LEN, "determined", 41, rig)
	k.lag_scale = 0.8
	var turn_to_elly: float = -222.0
	k.path([[0.0, USA_AT, -90.0, "s"], [SMACK + 0.1, USA_AT, -90.0, "s"], [SMACK + 0.55, USA_AT.lerp(USA_BACK, 0.7), -84.0, ""], [SMACK + 1.1, USA_BACK, -80.0, "s"],
		[16.0, USA_BACK, -80.0, "s"], [16.9, USA_BACK + Vector3(-0.08, 0.0, 0.1), -160.0, ""], [17.6, USA_BACK + Vector3(-0.12, 0.0, 0.16), turn_to_elly, "s"],
		[23.6, USA_BACK + Vector3(-0.12, 0.0, 0.16), turn_to_elly, "s"], [24.3, USA_BACK.lerp(USA_AT, 0.45) + Vector3(0.0, 0.0, 0.08), -150.0, ""], [24.95, USA_AT + Vector3(-0.04, 0.0, 0.0), -90.0, "s"],
		[28.4, USA_AT + Vector3(-0.04, 0.0, 0.0), -90.0, "s"], [29.0, USA_AT + Vector3(-0.3, 0.0, 0.0), -93.0, "s"], [JAB_LEN, USA_AT + Vector3(-0.3, 0.0, 0.0), -93.0, "s"]])
	# Sautille sur la pointe des pieds, jamais au même rythme.
	k.at(0.0, guard(0.0), "sync", "s")
	var hops: Array = [0.22, 0.47, 0.69, 0.95, 1.2, 1.41, 1.68, 1.92, 2.14]
	for i: int in range(hops.size()):
		var up: bool = i % 2 == 0
		k.at(float(hops[i]), M([H(0.0, -0.05 + (0.025 if up else -0.01), 0.0), {"fp_l": -0.35 if up else -0.1, "fp_r": -0.45 if up else -0.2, "sq": 1.015 if up else 0.99},
			HD(-0.08 + (0.03 if up else -0.02), 0.36, 0.0)]), "snap")
	# Il roule des épaules, secoue le gant droit.
	k.at(1.1, M([shrug(0.5, 0.1), C(0.06, -0.12, 0.05)]), "follow")
	k.at(1.4, M([shrug(0.1, 0.45), C(0.06, -0.04, -0.05)]), "follow")
	k.at(1.7, M([shrug(0.2), C(0.06, -0.08, 0.0)]), "follow")
	# Deux directs du gauche, secs ; retour en garde à chaque fois.
	for i: int in range(JABS.size()):
		var t: float = float(JABS[i])
		k.at(t - 0.1, M([B(0.1, -0.36, 0.0), L(0.1, 0.22, 0.46, 0.35), H(0.0, -0.06, -0.02), {"fp_l": -0.05, "fp_r": -0.3}]), "snap")
		k.at(t, M([B(0.16, 0.0, 0.0), C(0.08, 0.15, 0.0), H(0.0, -0.06, 0.06), L(0.02, 0.24, 1.0, 0.1), WL(0.0, 0.0, 0.0), HD(-0.1, 0.12, 0.0), {"sq": 0.98}]), "snap")
		k.at(t + 0.16, M([guard(-0.01), {"sq": 1.0}]), "follow")
	k.at(3.35, guard(0.0), "follow", "s")
	# « T'as vu ? » : il se tourne vers Elly, menton levé, fier de lui.
	k.at(3.8, M([HD(0.12, 1.15, 0.05), C(0.04, 0.2, 0.0), B(0.04, -0.05, 0.0), L(0.2, -0.3, 0.3, 0.2), R(0.15, -0.35, 0.25, 0.2), shrug(0.0), F("grin")]), "lead")
	k.at(4.05, HD(0.14, 1.2, 0.08), "heavy", "s")
	k.hold(4.05, 5.3, 0.4)
	# Elle lève le pouce sans lever les yeux. Il hausse les épaules, revient au mannequin.
	k.at(5.55, M([shrug(0.45), HD(0.05, 1.05, 0.0), F("smile")]), "heavy")
	k.at(5.85, M([shrug(0.0), HD(-0.05, 0.6, 0.0)]), "heavy")
	k.at(6.3, M([guard(0.0), F("determined")]), "follow", "s")
	# Il fait craquer sa nuque, à gauche, à droite.
	k.at(6.7, M([HD(-0.06, 0.4, 0.35), C(0.06, -0.06, 0.06)]), "follow")
	k.at(6.88, HD(-0.04, 0.38, 0.45), "snap", "s")
	k.at(7.2, M([HD(-0.06, 0.34, -0.35), C(0.06, -0.1, -0.06)]), "follow")
	k.at(7.36, HD(-0.04, 0.36, -0.46), "snap", "s")
	k.at(7.7, M([HD(-0.12, 0.38, 0.0), C(0.06, -0.08, 0.0)]), "heavy", "s")
	# Le gros coup : il arme, très loin en arrière, le poids sur la jambe de derrière…
	k.at(8.4, M([H(0.0, -0.1, -0.08), B(0.02, -0.75, -0.06), C(0.0, -0.3, -0.04), HD(-0.1, 0.85, 0.06), R(0.42, 0.18, -0.38, 0.6), WR(0.2, 0.0, 0.0),
		L(0.25, 0.2, 0.55, 0.4), {"fp_l": -0.5, "fp_r": 0.1}, shrug(0.35, 0.1), F("angry")]), "heavy")
	k.at(9.1, M([H(0.0, -0.12, -0.1), B(0.0, -0.82, -0.08), HD(-0.12, 0.92, 0.08), R(0.46, 0.22, -0.42, 0.65)]), "heavy", "s")
	k.hold(9.1, 9.7, 0.2, "snap")
	# … et lâche tout : rotation des hanches, du buste, le bras arrive en dernier.
	k.at(9.82, M([H(0.0, -0.08, 0.06), B(0.18, 0.1, 0.0), C(0.1, 0.1, 0.0), {"fp_l": 0.05, "fp_r": -0.6}]), "snap")
	k.at(HAYMAKER, M([H(0.0, -0.07, 0.16), B(0.32, 0.55, 0.05), C(0.16, 0.3, 0.0), HD(-0.2, -0.2, 0.0), R(-0.08, 0.2, 1.0, 0.2), WR(0.0, 0.0, 0.0), L(0.25, 0.05, 0.2, 0.3), {"sq": 0.97}, F("determined")]), "snap")
	# Rattrapé par son élan, penché en avant, il regarde le mannequin partir.
	k.at(10.25, M([H(0.0, -0.08, 0.2), B(0.4, 0.62, 0.08), C(0.2, 0.3, 0.0), HD(0.05, -0.28, 0.0), R(-0.15, -0.1, 0.85, 0.2), {"sq": 1.0}, F("surprise")]), "heavy", "s")
	k.at(10.5, M([HD(0.15, -0.15, 0.0), F("smile")]), "lead", "s")
	# 10,62 : le carton revient et lui claque le visage. La tête part, le corps suit, deux pas en arrière.
	k.at(SMACK + 0.04, M([HD(0.6, 0.25, 0.25), C(-0.16, 0.0, 0.08), B(0.0, 0.2, 0.05), R(0.35, 0.3, 0.3, 0.6), L(0.4, 0.35, 0.25, 0.6), CU(0.6), {"shake": 0.6, "sq": 1.03}, F("pain")]), "snap")
	k.at(SMACK + 0.3, M([H(0.0, -0.06, -0.08), B(-0.22, 0.1, 0.06), C(-0.12, 0.0, 0.04), HD(0.35, 0.1, 0.15), {"sq": 1.0}]), "heavy")
	k.steps([[1, SMACK + 0.12, SMACK + 0.45, {"lift": 0.06}], [-1, SMACK + 0.42, SMACK + 0.85, {"lift": 0.05}], [1, SMACK + 0.82, SMACK + 1.12, {"lift": 0.04}]],
		{"from": SMACK + 0.1, "to": SMACK + 1.1, "bob": 0.03, "stance": {-1: FL(0.08, 0.04, 0.0).foot_l, 1: FR(0.1, -0.05, 0.0).foot_r}})
	# Le gant sur le nez, plié en deux.
	k.at(11.5, M([H(0.0, -0.1, 0.02), B(0.32, 0.0, 0.0), C(0.15, 0.0, 0.0), HD(-0.3, 0.05, 0.0), Rt(-0.12, 0.62, 0.42, 0.3), WR(0.6, 0.0, 0.0), L(0.3, -0.5, 0.35, 0.2), CU(0.9), {"shake": 0.3}, F("pain")]), "heavy")
	k.at(12.1, M([HD(-0.36, -0.12, 0.05), {"shake": 0.15}]), "heavy")
	k.at(12.6, M([HD(-0.3, 0.14, -0.05)]), "heavy", "s")
	# Elly lui tend la poche de glace : il refuse, la main en l'air, l'autre toujours sur le nez.
	k.at(13.6, M([B(0.16, 0.0, 0.0), C(0.06, 0.25, 0.0), HD(-0.05, 0.85, 0.0), F("hurt")]), "lead")
	k.at(14.2, M([L(0.35, 0.15, 0.55, 0.5), WL(-0.4, 0.0, 0.0), CU(0.8, 0.3)]), "follow")
	k.at(14.45, M([L(0.45, 0.18, 0.5, 0.5), WL(-0.4, 0.0, 0.4)]), "snap")
	k.at(14.7, M([L(0.32, 0.15, 0.55, 0.5), WL(-0.4, 0.0, -0.3)]), "snap")
	k.at(14.95, M([L(0.44, 0.17, 0.52, 0.5), WL(-0.4, 0.0, 0.35), HD(0.0, 0.8, 0.08), F("grin")]), "snap")
	k.at(15.4, M([L(0.25, -0.6, 0.25, 0.2), WL(0.2), Rt(-0.05, 0.45, 0.35, 0.3), HD(-0.05, 0.6, 0.0), B(0.1, 0.05, 0.0)]), "follow", "s")
	# Il se retourne vers Elly pour raconter : la tête d'abord, puis le corps.
	k.at(15.9, M([HD(0.0, 1.0, 0.0), C(0.05, 0.3, 0.0), R(0.2, -0.5, 0.3, 0.2), CU(0.9), F("neutral")]), "lead")
	k.steps([[-1, 16.05, 16.45, {"lift": 0.05}], [1, 16.4, 16.85, {"lift": 0.05}], [-1, 16.8, 17.25, {"lift": 0.04}], [1, 17.2, 17.6, {"lift": 0.04}]],
		{"from": 16.0, "to": 17.6, "bob": 0.025, "stance": {-1: FL(0.05, 0.0, 0.0).foot_l, 1: FR(0.06, 0.02, 0.0).foot_r}})
	k.at(17.6, M([H(0.0, -0.02, 0.0), B(0.04), C(0.05), HD(0.0, 0.0, 0.0), L(0.22, -0.6, 0.3, 0.2), R(0.22, -0.6, 0.3, 0.2), shrug(0.0), F("smile")]), "follow", "s")
	# Il raconte : le carton (une main plate), le coup (l'autre poing), boum ; il mime le vol plané.
	k.at(18.0, M([L(0.1, 0.0, 0.6, 0.3), WL(-0.2, 0.0, 0.0), R(0.4, 0.1, 0.25, 0.4), HD(0.05, 0.15, 0.05), B(0.06, 0.1, 0.0), {"jaw": 0.3}, F("grin")]), "follow")
	k.at(18.35, M([R(-0.02, 0.05, 0.62, 0.3), {"jaw": 0.0}]), "snap")
	k.at(18.55, M([L(0.15, 0.25, 0.4, 0.3), WL(-0.8, 0.0, 0.0), HD(0.15, 0.05, 0.0), {"jaw": 0.4}]), "snap")
	k.at(19.0, M([L(0.35, 0.55, 0.15, 0.5), R(0.35, 0.5, 0.15, 0.5), HD(0.2, 0.0, -0.05), C(-0.05, 0.0, 0.0), {"jaw": 0.15}, F("laugh")]), "follow")
	k.at(19.5, M([L(0.3, -0.4, 0.35, 0.2), R(0.3, -0.4, 0.35, 0.2), HD(0.0, 0.1, 0.08), C(0.08, 0.0, 0.0), {"jaw": 0.0}]), "heavy")
	k.at(19.9, M([Rt(0.0, 0.15, 0.45, 0.3), {"gesture": "point"}, HD(-0.04, 0.1, 0.0), F("smile")]), "follow")
	k.at(20.3, M([Rt(0.05, 0.18, 0.5, 0.3)]), "snap")
	k.at(20.55, M([Rt(0.0, 0.14, 0.44, 0.3)]), "snap", "s")
	# Elly ne l'écoute plus : elle regarde derrière lui. Il s'arrête, la main en l'air.
	k.at(21.2, M([HD(0.05, 0.0, 0.1), F("neutral")]), "lead", "s")
	k.at(21.7, M([HD(0.0, -0.4, 0.0), C(0.04, -0.15, 0.0), F("surprise")]), "lead")
	# 22,1 : il se retourne d'un coup, par-dessus son épaule (le mannequin est droit, bien sûr).
	k.at(22.1, M([HD(0.02, -1.3, 0.0), C(0.02, -0.45, 0.0), B(0.0, -0.3, 0.0), {"gesture": ""}, R(0.25, -0.5, 0.3, 0.2), CU(0.9)]), "snap")
	k.at(22.4, HD(0.0, -1.35, 0.02), "heavy", "s")
	k.hold(22.4, 23.0, 0.2)
	# « Quoi ? » : il revient vers elle, les bras ouverts.
	k.at(23.25, M([HD(0.08, 0.15, 0.1), C(0.05, 0.0, 0.0), B(0.0, 0.0, 0.0), L(0.4, -0.3, 0.3, 0.6), R(0.4, -0.3, 0.3, 0.6), WL(-0.5), WR(-0.5), shrug(0.5), F("tired")]), "follow")
	k.at(23.6, M([shrug(0.1), HD(0.0, 0.1, 0.0)]), "heavy", "s")
	# Il retourne à son mannequin, en garde.
	k.at(23.8, M([HD(0.0, -0.6, 0.0), C(0.05, -0.2, 0.0), F("determined")]), "lead")
	k.steps([[1, 23.75, 24.12, {"lift": 0.05}], [-1, 24.1, 24.48, {"lift": 0.05}], [1, 24.45, 24.8, {"lift": 0.04}], [-1, 24.78, 25.0, {"lift": 0.03}]],
		{"from": 23.6, "to": 24.95, "bob": 0.02, "stance": {-1: guard().foot_l, 1: guard().foot_r}})
	k.at(25.0, guard(0.0), "follow", "s")
	# Deux directs : le carton ne bouge plus. Pas d'un millimètre.
	for t: float in LATE_JABS:
		k.at(t - 0.1, M([B(0.1, -0.36, 0.0), L(0.1, 0.22, 0.46, 0.35), H(0.0, -0.06, -0.02)]), "snap")
		k.at(t, M([B(0.16, 0.0, 0.0), C(0.08, 0.15, 0.0), H(0.0, -0.06, 0.06), L(0.02, 0.24, 1.0, 0.1), HD(-0.1, 0.12, 0.0)]), "snap")
		k.at(t + 0.12, M([L(0.04, 0.24, 0.95, 0.1)]), "snap", "s")
	# Il regarde son gant. Puis le carton.
	k.at(26.35, M([guard(0.0), L(0.1, 0.35, 0.45, 0.3), WL(0.0, 0.8, 0.0), HD(0.05, 0.2, -0.1), F("surprise")]), "follow")
	k.at(26.7, M([HD(-0.05, 0.38, 0.0), WL(0.3, 0.0, 0.0), F("neutral")]), "lead", "s")
	# Le néon claque. Quand il revient, le carton regarde Elly. Usayuko baisse la garde, recule.
	k.at(FLICKER_ON + 0.1, M([{"shake": 0.4}, shrug(0.5), HD(0.0, 0.42, 0.0), F("fear")]), "snap")
	k.at(28.2, M([L(0.2, -0.3, 0.35, 0.3), R(0.2, -0.35, 0.3, 0.3), B(0.0, -0.2, 0.0), C(0.0, -0.05, 0.0), HD(0.05, 0.55, 0.0)]), "heavy")
	k.steps([[-1, 28.45, 28.75, {"lift": 0.04}], [1, 28.72, 29.0, {"lift": 0.03}]], {"from": 28.4, "to": 29.0, "bob": 0.015})
	k.at(29.4, M([HD(0.05, 0.9, 0.0), C(0.02, 0.15, 0.0), {"shake": 0.25}]), "lead")
	k.at(29.8, HD(0.02, 0.95, 0.03), "heavy", "s")
	k.hold(29.8, JAB_LEN, 0.25, "snap")
	return k.clip()

# Elly assise sur le plinth, les jambes qui pendent ; le livre dans la main gauche.
static func sit_box(swing: float = 0.0) -> Dictionary:
	return M([rest(), start(), {"plant": 0.0, "gsnap": 0.0}, H(0.0, -0.05, 0.02), TL(1.48 + 0.12 * swing, 0.06, 0.04), KL(1.42 - 0.2 * swing, -0.2), TR(1.5 - 0.1 * swing, 0.08, -0.04), KR(1.46 + 0.18 * swing, -0.2),
		B(0.0), C(0.1), HD(-0.42, 0.0, 0.05), L(0.08, -0.48, 0.42, 0.2), WL(0.35, 0.0, 0.3), R(0.0, -0.5, 0.42, 0.2), WR(0.35, 0.0, -0.3), CU(0.55, 0.6), F("calm")])

static func _jab_elly(rig: Dictionary) -> Dictionary:
	var k: Take = Take.new(JAB_LEN, "calm", 43, rig)
	k.at(0.0, sit_box(0.0), "sync", "s")
	# Les jambes se balancent, chacune à son rythme.
	var swings: Array = [[0.8, 0.8], [1.9, -0.6], [2.7, 0.5], [3.9, -0.8], [5.2, 0.6], [6.1, -0.4], [7.4, 0.7], [8.6, -0.5]]
	for s: Array in swings:
		k.at(float(s[0]), M([TL(1.48 + 0.12 * float(s[1]), 0.06, 0.04), KL(1.42 - 0.22 * float(s[1]), -0.2), TR(1.5 - 0.1 * float(s[1]), 0.08, -0.04), KR(1.46 + 0.2 * float(s[1]), -0.2)]), "heavy")
	# Elle tourne une page.
	k.at(2.1, M([R(-0.05, -0.42, 0.5, 0.2), WR(0.2, 0.0, -0.8), CU(0.3, 0.6)]), "follow")
	k.at(2.45, M([R(0.12, -0.45, 0.45, 0.2), WR(0.3, 0.0, 0.2)]), "follow")
	k.at(2.75, M([R(0.0, -0.5, 0.42, 0.2), WR(0.35, 0.0, -0.3), CU(0.55, 0.6)]), "heavy", "s")
	# « T'as vu ? » : le pouce levé, sans lever les yeux du livre.
	k.at(4.35, M([R(0.18, -0.15, 0.4, 0.3), WR(0.0, 0.0, 0.0), {"gesture": "thumbsup"}, CU(0.8, 0.6)]), "follow")
	k.at(4.6, R(0.19, -0.1, 0.42, 0.3), "snap", "s")
	k.hold(4.6, 5.3, 0.2)
	k.at(5.6, M([R(0.0, -0.5, 0.42, 0.2), WR(0.35, 0.0, -0.3), {"gesture": ""}, CU(0.55, 0.6)]), "follow", "s")
	# Le gros coup : elle lève enfin les yeux… juste à temps pour le retour du carton.
	k.at(9.6, M([HD(-0.28, 0.12, 0.0)]), "lead")
	k.at(10.3, M([HD(-0.05, 0.25, 0.0), C(0.06), F("neutral")]), "lead", "s")
	k.at(SMACK + 0.08, M([HD(0.0, 0.22, -0.08), shrug(0.5), C(0.0), F("pain")]), "snap")
	k.at(SMACK + 0.5, M([HD(-0.05, 0.22, -0.04), shrug(0.1), F("tired")]), "heavy", "s")
	# Un soupir. Elle pose le livre sur ses genoux, sort la poche de glace de la trousse, la lui tend.
	k.at(12.0, M([shrug(0.35), HD(0.06, 0.2, 0.0)]), "heavy")
	k.at(12.45, M([shrug(0.0), HD(-0.1, 0.2, 0.0)]), "heavy", "s")
	k.at(12.8, M([R(0.45, -0.35, 0.18, 0.4), WR(0.4, 0.0, 0.0), C(0.08, -0.25, 0.0), HD(-0.3, -0.5, 0.0), B(0.0, -0.1, 0.0), CU(0.3, 0.6)]), "follow")
	k.at(13.2, M([R(0.5, -0.42, 0.12, 0.4), CU(0.8, 0.6)]), "follow", "s")
	k.at(13.75, M([R(0.25, 0.1, 0.75, 0.3), WR(0.0, 0.0, 0.0), C(0.12, 0.15, 0.0), B(0.05, 0.12, 0.0), HD(-0.02, 0.2, 0.0), F("calm")]), "follow")
	k.at(14.1, M([R(0.27, 0.12, 0.8, 0.3)]), "heavy", "s")
	k.hold(14.1, 15.0, 0.2)
	# Il refuse : elle hausse un sourcil (la tête penche), range la glace.
	k.at(15.25, M([HD(0.0, 0.2, 0.18), F("smile")]), "lead")
	k.at(15.7, M([R(0.5, -0.42, 0.12, 0.4), C(0.08, -0.25, 0.0), HD(-0.2, -0.3, 0.1), B(0.0, -0.1, 0.0)]), "follow")
	k.at(16.15, M([R(0.0, -0.5, 0.42, 0.2), WR(0.35, 0.0, -0.3), C(0.1), B(0.0), HD(-0.1, 0.2, 0.05), CU(0.55, 0.6)]), "follow", "s")
	# Elle l'écoute raconter, un petit sourire en coin ; les jambes se balancent de nouveau.
	k.at(17.4, M([HD(0.02, 0.22, 0.08), F("smile")]), "heavy")
	for s: Array in [[17.8, 0.6], [18.9, -0.5], [19.9, 0.4]]:
		k.at(float(s[0]), M([TL(1.48 + 0.12 * float(s[1]), 0.06, 0.04), KL(1.42 - 0.22 * float(s[1]), -0.2), TR(1.5 - 0.1 * float(s[1]), 0.08, -0.04), KR(1.46 + 0.2 * float(s[1]), -0.2)]), "heavy")
	k.at(19.2, M([HD(0.0, 0.18, 0.12), {"jaw": 0.15}, F("laugh")]), "heavy")
	k.at(19.7, M([HD(0.02, 0.2, 0.06), {"jaw": 0.0}, F("smile")]), "heavy", "s")
	# 20,6 : son regard glisse derrière lui. Le sourire tombe ; les jambes s'arrêtent.
	k.at(20.6, M([HD(0.03, 0.05, 0.0), F("neutral")]), "lead")
	k.at(20.9, M([HD(0.06, 0.02, -0.04), C(0.0), TL(1.5, 0.06, 0.04), KL(1.45, -0.2), TR(1.5, 0.08, -0.04), KR(1.45, -0.2), F("surprise")]), "heavy", "s")
	# Elle montre le mannequin du doigt, sans le quitter des yeux.
	k.at(21.35, M([R(0.2, 0.08, 0.75, 0.3), WR(0.0, 0.0, 0.0), {"gesture": "point"}, CU(0.6, 0.6), B(0.04, 0.05, 0.0), C(0.06, 0.05, 0.0)]), "follow")
	k.at(21.6, R(0.21, 0.1, 0.8, 0.3), "heavy", "s")
	k.hold(21.6, 23.0, 0.15)
	# « Quoi ? » : elle baisse la main, lentement ; remonte le livre devant son visage, mais regarde par-dessus.
	k.at(23.4, M([R(0.0, -0.5, 0.42, 0.2), WR(0.35, 0.0, -0.3), {"gesture": ""}, CU(0.55, 0.6), HD(-0.05, 0.15, 0.0), F("tired")]), "heavy")
	k.at(24.0, M([L(0.06, -0.2, 0.42, 0.2), R(0.0, -0.22, 0.42, 0.2), HD(-0.1, 0.1, 0.0), C(0.06), F("neutral")]), "follow")
	k.at(24.4, M([HD(-0.06, 0.12, 0.0)]), "heavy", "s")
	k.at(25.5, HD(-0.04, 0.22, 0.0), "lead", "s")
	k.at(26.3, HD(-0.08, 0.14, 0.0), "heavy", "s")
	# Le néon revient : le carton la regarde. Elle referme le livre, le serre contre elle.
	k.at(FLICKER_ON + 0.15, M([HD(-0.02, 0.05, 0.0), {"shake": 0.4}, F("fear")]), "snap")
	k.at(28.0, M([L(0.0, -0.05, 0.25, 0.3), R(-0.02, 0.0, 0.25, 0.3), C(0.12), B(0.05), shrug(0.45), HD(-0.08, 0.05, 0.0), CU(0.85, 0.85)]), "heavy")
	k.at(28.5, M([shrug(0.55), {"shake": 0.25}]), "heavy", "s")
	k.hold(28.5, JAB_LEN, 0.2, "snap")
	return k.clip()
