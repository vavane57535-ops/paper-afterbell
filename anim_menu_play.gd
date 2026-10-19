extends "res://anim_menu_take.gd"

# JOUER : Simon s'échauffe dans le couloir, la nuit ; il se croit seul.
# Simon : nerveux, rapide, petits gestes secs, regard qui file partout.
# Alice ne marche jamais : elle est là quand la lumière revient, ou quand on regarde ailleurs.

const SIMON_AT: Vector3 = Vector3(0.15, 0.0, 1.0)
const SIMON_YAW: float = -20.0

static func writers(rigs: Dictionary) -> Array:
	return [
		func() -> Dictionary: return {"menu_play_alone@Simon": _alone_simon(rigs.simon)},
		func() -> Dictionary: return {"menu_play_alone@Alice": _alone_alice(rigs.alice)},
	]

# Pose de repos de Simon (début et fin de chaque temps fort) : poids un peu sur la gauche,
# épaules souples, mains entrouvertes.
static func home() -> Dictionary:
	return M([stand(0.03), H(-0.025, -0.015, 0.0), B(0.02, 0.0, 0.025), C(0.04, 0.03, -0.015), HD(-0.04, 0.06, 0.03),
		L(0.22, -0.9, 0.08, 0.1), R(0.21, -0.91, 0.05, 0.1), WL(0.1), WR(0.15), CU(0.35, 0.3), F("neutral")])

# Haussement d'épaules (clavicules) : 1 = épaules aux oreilles.
static func shrug(amount: float, left: float = -1.0) -> Dictionary:
	var l: float = amount if left < 0.0 else left
	return {"l_clav": V(0.0, 0.0, -0.32 * l), "r_clav": V(0.0, 0.0, 0.32 * amount)}

# --- « Seul ? » (34 s) -----------------------------------------------------------------------
# Échauffement, le néon grésille (Alice au fond du couloir, il ne la voit pas), il refait son
# lacet (Alice derrière lui, floue), un frisson, il se retourne : rien ; il se remet face à nous…
# et Alice est sur son épaule. Cri, noir.
const ALONE_LEN: float = 33.8

static func _alone_simon(rig: Dictionary) -> Dictionary:
	var k: Take = Take.new(ALONE_LEN, "neutral", 11, rig)
	k.at(0.0, M([home(), shrug(0.0)]), "sync", "s")
	k.hold(0.0, 1.15, 0.6)
	# Coup d'œil à gauche, puis à droite : personne.
	k.at(1.3, M([HD(-0.02, 0.78, 0.04), C(0.04, 0.22, -0.01), B(0.02, 0.06, 0.02), F("focus")]), "lead")
	k.at(1.5, M([HD(-0.03, 0.84, 0.02), C(0.04, 0.24, -0.01)]), "heavy", "s")
	k.at(1.85, M([HD(-0.06, -0.62, -0.03), C(0.05, -0.14, -0.02), B(0.02, -0.04, 0.02)]), "lead")
	k.at(2.05, M([HD(-0.05, -0.7, -0.02), C(0.05, -0.16, -0.02)]), "heavy", "s")
	# Personne : il souffle, les épaules retombent, petit hochement.
	k.at(2.45, M([HD(-0.1, 0.05, 0.02), C(0.08, 0.02, -0.01), B(0.04, 0.0, 0.02), shrug(-0.12), F("calm")]), "heavy")
	k.at(2.7, HD(-0.2, 0.04, 0.02), "snap")
	k.at(2.9, M([HD(-0.06, 0.06, 0.03), C(0.05, 0.02, -0.015), shrug(0.0)]), "follow", "s")
	# La nuque qui roule : penchée à gauche, en bas, à droite, en arrière.
	k.at(3.2, M([HD(-0.12, 0.05, 0.42), C(0.05, 0.03, 0.06), F("neutral")]), "follow")
	k.at(3.55, M([HD(-0.5, 0.0, 0.12), C(0.12, 0.0, 0.0)]), "follow")
	k.at(3.9, M([HD(-0.14, -0.05, -0.42), C(0.06, -0.02, -0.06)]), "follow")
	k.at(4.25, M([HD(0.28, 0.0, -0.08), C(-0.02, 0.0, 0.0), shrug(0.2)]), "follow")
	k.at(4.55, M([HD(-0.04, 0.06, 0.03), C(0.04, 0.03, -0.015), shrug(0.0)]), "follow", "s")
	# Bras droit en travers de la poitrine, la main gauche tire le coude.
	k.at(4.95, M([C(0.04, 0.14, 0.0), B(0.03, 0.06, 0.02), HD(-0.05, -0.32, 0.0), R(-0.45, 0.02, 0.38, 0.0), WR(-0.2, 0.0, 0.3), L(-0.05, -0.2, 0.42, 0.5), WL(0.3), CU(0.2, 0.6), F("focus")]))
	k.at(5.3, M([C(0.05, 0.18, 0.0), HD(-0.06, -0.48, 0.03), R(-0.58, 0.03, 0.34, 0.0), L(-0.12, -0.18, 0.4, 0.5)]), "heavy", "s")
	k.hold(5.3, 5.85, 0.5)
	# Il lâche et secoue les mains, poignets mous.
	k.at(6.05, M([C(0.05, 0.02, 0.0), B(0.03, 0.0, 0.02), HD(-0.12, 0.05, 0.0), L(0.26, -0.82, 0.12, 0.2), R(0.25, -0.82, 0.14, 0.2), WL(0.2), WR(0.2), CU(0.1), F("neutral")]), "follow")
	for i: int in range(6):
		var t: float = 6.12 + i * 0.075
		var up: float = 0.05 if i % 2 == 0 else -0.05
		k.at(t, M([L(0.26, -0.82 + up, 0.12, 0.2), R(0.25, -0.82 - up, 0.14, 0.2), WL(0.6 if i % 2 == 0 else -0.5), WR(-0.5 if i % 2 == 0 else 0.6), CU(0.05)]), "snap")
	k.at(6.65, M([L(0.24, -0.88, 0.1, 0.15), R(0.23, -0.88, 0.1, 0.15), WL(0.1), WR(0.1), CU(0.25), HD(-0.12, 0.0, 0.0), F("focus")]), "follow", "s")
	# Étirement du quadriceps droit : le poids passe à gauche, la main droite va chercher la cheville.
	k.at(7.0, M([H(-0.06, -0.02, 0.0), B(0.05, 0.0, 0.06), C(0.06, 0.0, -0.03), HD(-0.18, 0.0, 0.0), L(0.4, -0.7, 0.1, 0.4), FR(0.02, -0.05, 0.12), {"fp_r": 0.3}]), "follow")
	k.at(7.35, M([H(-0.075, -0.035, -0.02), B(0.18, 0.06, 0.07), C(0.1, 0.0, -0.04), HD(-0.3, 0.1, 0.05), FR(0.02, -0.38, 0.72), R(0.12, -0.78, -0.42, 0.0), WR(0.4), CU(0.6, 0.15), L(0.62, -0.38, 0.12, 0.6), {"fp_r": 0.9}]), "follow")
	k.at(7.65, M([H(-0.07, -0.03, -0.01), B(0.08, 0.04, 0.06), C(0.04, 0.0, -0.03), HD(-0.05, 0.05, 0.04), FR(0.02, -0.34, 0.8), R(0.1, -0.8, -0.36, 0.0), CU(0.85, 0.1), L(0.7, -0.2, 0.08, 0.7), F("focus")]), "follow", "s")
	# Il tangue… petit saut sur le pied gauche pour se rattraper.
	k.at(8.05, M([H(-0.04, -0.035, 0.0), B(0.06, 0.0, 0.0), C(0.02, 0.0, 0.03), HD(-0.02, 0.1, -0.06), L(0.78, 0.05, 0.0, 0.9), F("surprise")]), "snap")
	k.at(8.25, M([H(-0.1, -0.03, 0.02), B(0.07, 0.0, 0.12), C(0.0, 0.0, -0.08), HD(0.04, 0.0, 0.1), L(0.85, -0.1, 0.2, 0.9), {"sq": 1.0}]), "snap")
	k.at(8.38, M([H(-0.08, -0.07, 0.0), FL(0.0, 0.03, 0.0), {"sq": 0.97}]), "snap")
	k.at(8.52, M([H(-0.08, 0.04, 0.02), FL(0.0, 0.05, 0.08), {"sq": 1.03, "fp_l": -0.4}]), "snap")
	k.at(8.68, M([H(-0.075, -0.05, 0.03), FL(0.0, 0.07, 0.0), B(0.08, 0.0, 0.03), {"sq": 0.98, "fp_l": 0.0}]), "snap", "s")
	k.at(8.9, M([H(-0.07, -0.03, 0.02), B(0.07, 0.03, 0.05), C(0.04, 0.0, -0.02), HD(-0.08, 0.05, 0.02), L(0.66, -0.3, 0.1, 0.6), {"sq": 1.0}, F("smile")]), "heavy", "s")
	k.hold(8.9, 9.4, 0.7)
	# Il lâche la jambe, la secoue, retour en appui sur les deux pieds.
	k.at(9.6, M([H(-0.03, -0.02, 0.0), B(0.04, 0.0, 0.02), FR(0.02, 0.1, 0.25), R(0.25, -0.86, 0.05, 0.15), CU(0.3), L(0.3, -0.85, 0.08, 0.2), HD(-0.12, -0.05, 0.0), {"fp_r": -0.3}, F("neutral")]))
	k.at(9.75, M([FR(0.03, -0.04, 0.14), {"fp_r": 0.5}]), "snap")
	k.at(9.88, M([FR(0.03, 0.06, 0.1), {"fp_r": -0.2}]), "snap")
	k.at(10.05, M([H(0.0, -0.03, 0.0), FL(0.05, 0.0, 0.0), FR(0.05, 0.0, 0.0), B(0.06, 0.0, 0.0), C(0.06), HD(-0.02, 0.0, 0.0), {"fp_r": 0.0, "fp_l": 0.0}, F("determined")]), "follow", "s")
	# Montées de genoux sur place, très vite, bras qui pompent ; chaque pas un peu différent.
	var knees: Array = [0.4, 0.46, 0.42, 0.5, 0.44, 0.48, 0.41, 0.36]
	var t_knee: float = 10.25
	for i: int in range(knees.size()):
		var side: int = 1 if i % 2 == 0 else -1
		var dur: float = 0.24 - 0.012 * float(i % 3)
		var up: float = float(knees[i])
		var swing_pose: Dictionary = M([
			FR(0.05, 0.16, up) if side > 0 else FL(0.05, 0.16, up),
			FL(0.05, 0.0, 0.0) if side > 0 else FR(0.05, 0.0, 0.0),
			{"fp_r" if side > 0 else "fp_l": 0.35, "fp_l" if side > 0 else "fp_r": -0.15},
			H(0.012 * - side, 0.012, 0.0), B(0.1, 0.03 * side, - 0.03 * side), C(0.04, - 0.08 * side, 0.02 * side), HD(-0.06, 0.06 * side, 0.0),
			L(0.16, -0.52, 0.42 if side > 0 else -0.18, 0.3), R(0.16, -0.52, -0.18 if side > 0 else 0.42, 0.3),
			WL(0.4), WR(0.4), CU(0.85)])
		k.at(t_knee + dur * 0.45, swing_pose, "snap")
		k.at(t_knee + dur, M([FL(0.05, 0.0, 0.0), FR(0.05, 0.0, 0.0), {"fp_r": 0.0, "fp_l": 0.0}, H(0.0, -0.035, 0.0), {"sq": 0.97}]), "snap")
		t_knee += dur
	# Il finit sur la pointe des pieds, petit sautillement de boxeur.
	k.at(t_knee + 0.15, M([H(0.0, 0.025, 0.0), {"fp_l": -0.35, "fp_r": -0.35, "sq": 1.02}, B(0.05), C(0.05), HD(-0.04, 0.0, 0.0),
		L(0.2, -0.6, 0.32, 0.3), R(0.2, -0.62, 0.3, 0.3), WL(0.2), WR(0.2), CU(0.9), F("smile")]), "follow")
	k.at(t_knee + 0.32, M([H(0.0, -0.02, 0.0), {"fp_l": -0.1, "fp_r": -0.1, "sq": 0.98}]), "snap")
	k.at(t_knee + 0.5, M([H(0.0, 0.02, 0.0), {"fp_l": -0.32, "fp_r": -0.32, "sq": 1.01}, HD(-0.02, 0.05, -0.03)]), "snap")
	# 12,6 : le néon grésille. Il se fige, les yeux au plafond.
	k.at(12.62, M([H(0.0, -0.01, 0.0), {"fp_l": 0.0, "fp_r": 0.0, "sq": 1.0}, shrug(0.3), HD(0.25, -0.1, 0.0), C(0.02, -0.04, 0.0), B(0.0), F("surprise")]), "lead")
	k.at(12.9, M([HD(0.5, -0.06, 0.05), C(-0.04, -0.06, 0.0), B(-0.04), L(0.22, -0.72, 0.18, 0.2), R(0.22, -0.74, 0.16, 0.2), CU(0.5), F("fear")]), "lead", "s")
	k.hold(12.9, 13.75, 0.3, "snap")
	# Le néon meurt : il serre les poings, ne bouge plus.
	k.at(13.8, M([HD(0.52, 0.02, 0.03), shrug(0.45), CU(0.9), {"shake": 0.25}]), "snap", "s")
	k.hold(13.8, 15.1, 0.2, "snap")
	# 15,2 : la lumière revient. Il la fixe, méfiant ; secoue la tête ; rire nerveux.
	k.at(15.3, M([HD(0.42, 0.0, 0.0), shrug(0.2), {"shake": 0.0}, CU(0.5), F("focus")]), "heavy")
	k.at(15.8, M([HD(0.36, 0.05, -0.08), C(-0.02, 0.02, 0.0)]), "heavy", "s")
	k.at(16.2, M([HD(0.02, 0.0, 0.0), C(0.06, 0.0, 0.0), B(0.02), shrug(0.0), F("neutral")]), "follow")
	k.at(16.4, HD(0.0, 0.2, 0.04), "snap")
	k.at(16.58, HD(0.0, -0.18, -0.04), "snap")
	k.at(16.76, HD(0.0, 0.12, 0.02), "snap")
	k.at(16.95, M([HD(-0.06, 0.02, 0.05), shrug(0.25), C(0.03, 0.04, 0.02), F("smile"), {"jaw": 0.25}]), "follow")
	k.at(17.15, M([shrug(0.05), {"jaw": 0.05}]), "snap")
	k.at(17.3, M([shrug(0.22), {"jaw": 0.2}]), "snap")
	k.at(17.5, M([shrug(0.0), {"jaw": 0.0}, HD(-0.08, 0.05, 0.03)]), "follow", "s")
	# Il se frotte le nez du dos de l'index.
	k.at(17.85, M([R(-0.04, 0.12, 0.62, 0.3), WR(0.4, 0.0, -0.2), {"gesture": "point"}, CU(0.6), HD(-0.1, 0.05, 0.0)]), "follow")
	k.at(18.0, M([R(-0.1, 0.14, 0.6, 0.3), HD(-0.08, 0.02, 0.05)]), "snap")
	k.at(18.13, M([R(-0.02, 0.12, 0.62, 0.3), HD(-0.1, 0.06, -0.03)]), "snap")
	k.at(18.45, M([R(0.21, -0.91, 0.05, 0.1), WR(0.15), {"gesture": ""}, CU(0.35, 0.3), HD(-0.05, 0.06, 0.03), F("determined")]), "follow", "s")
	# Grands moulinets des bras, en arrière, deux tours, le second plus ample.
	var mill_t: float = 18.8
	for turn: int in range(2):
		var big: float = 1.0 + 0.15 * turn
		var dur2: float = 0.95 - 0.12 * turn
		var stations: Array = [[0.3, -0.75, 0.55], [0.35, 0.2, 0.75], [0.4, 0.95, 0.15], [0.45, 0.25, -0.55], [0.3, -0.85, -0.05]]
		for j: int in range(stations.size()):
			var s: Array = stations[j]
			var u: float = float(j + 1) / float(stations.size())
			k.at(mill_t + dur2 * u, M([L(float(s[0]) * big, float(s[1]) * big, float(s[2]) * big, 0.6), R(float(s[0]) * big, float(s[1]) * big, float(s[2]) * big, 0.6),
				C(0.02 - 0.06 * float(s[1]), 0.0, 0.0), B(0.02, 0.0, 0.0), HD(-0.05 + 0.04 * float(s[1]), 0.0, 0.0), CU(0.3)]), "follow")
		mill_t += dur2
	k.at(mill_t + 0.3, M([home(), shrug(0.0), F("calm")]), "heavy", "s")
	# Coups d'œil par-dessus l'épaule, vite, sans y croire.
	k.at(mill_t + 0.7, M([HD(0.0, 0.95, 0.0), C(0.03, 0.3, 0.0), F("focus")]), "snap")
	k.at(mill_t + 0.95, M([HD(-0.04, 0.06, 0.03), C(0.04, 0.03, -0.015)]), "follow", "s")
	k.hold(mill_t + 0.95, 22.4, 0.5)
	# 22,5 : il refait son lacet droit. Il regarde sa chaussure, grand pas du pied droit, et le
	# genou gauche descend au sol, orteils repliés. Les mains vont au lacet (contact : reach de la scène).
	k.at(22.5, M([HD(-0.3, 0.0, 0.0), C(0.08), F("neutral")]), "lead")
	k.at(22.7, M([H(0.0, -0.05, 0.04), B(0.12), C(0.1), L(0.25, -0.85, 0.12, 0.2), R(0.25, -0.85, 0.12, 0.2), CU(0.35)]), "follow")
	k.step(22.72, 23.08, 1, Vector3(0.06, 0.0, -0.92), 0.06, 0.25)
	k.at(23.1, M([H(0.0, -0.3, 0.3), B(0.3), C(0.16), HD(-0.32, 0.0, 0.0), {"fp_l": -0.55}, L(0.25, -0.6, 0.35, 0.3), R(0.25, -0.6, 0.4, 0.3)]), "follow")
	k.at(23.5, M([H(0.0, -0.586, 0.46), FL(0.04, 0.0, 0.03), {"fp_l": -1.15}, B(0.46, 0.0, 0.0), C(0.22), HD(-0.36, 0.0, 0.0),
		L(0.05, -0.62, 0.62, 0.3), R(0.0, -0.62, 0.66, 0.3), WL(0.5), WR(0.5), CU(0.55)]), "heavy", "s")
	k.at(23.62, M([H(0.0, -0.6, 0.47), {"sq": 0.99}]), "snap")
	k.at(23.8, M([H(0.0, -0.586, 0.46), {"sq": 1.0}]), "heavy", "s")
	# Les doigts travaillent (piste de la scène) ; la tête suit, petits hochements.
	var nods: Array = [[24.0, -0.4, 0.04], [24.5, -0.34, -0.03], [25.1, -0.42, 0.02], [25.6, -0.36, 0.05], [26.2, -0.4, -0.02]]
	for entry: Array in nods:
		k.at(float(entry[0]), M([HD(float(entry[1]), float(entry[2]), 0.02), CU(0.5 + float(entry[2]) * 3.0, 0.62)]), "follow")
	# Il tire les deux boucles d'un coup sec.
	k.at(26.85, M([L(0.25, -0.5, 0.55, 0.4), R(0.3, -0.5, 0.6, 0.4), CU(0.95), HD(-0.3, 0.0, 0.0), C(0.18)]), "snap", "s")
	# 27,3 : le néon refait des siennes. Il lève les yeux, agacé.
	k.at(27.35, M([HD(0.3, 0.0, 0.0), C(0.1), B(0.4), F("tired")]), "lead")
	k.at(27.6, M([HD(0.36, 0.05, -0.06), L(0.2, -0.6, 0.45, 0.3), R(0.1, -0.55, 0.55, 0.3), CU(0.4)]), "heavy", "s")
	# Il se relève en poussant sur la cuisse droite, puis ramène le pied droit.
	k.at(27.95, M([HD(-0.12, 0.0, 0.0), R(-0.02, -0.66, 0.55, 0.2), L(0.22, -0.72, 0.3, 0.2), F("neutral")]), "follow")
	k.at(28.25, M([H(0.0, -0.3, 0.3), {"fp_l": -0.5}, B(0.36), C(0.12), HD(-0.08, 0.0, 0.0), R(0.0, -0.72, 0.45, 0.2)]), "heavy")
	k.at(28.55, M([H(0.0, -0.07, 0.12), FL(0.04, 0.0, 0.0), {"fp_l": 0.0}, B(0.12), C(0.06), HD(-0.02, 0.0, 0.0), R(0.22, -0.88, 0.1, 0.15), L(0.24, -0.88, 0.1, 0.15)]), "follow")
	k.step(28.55, 28.9, 1, Vector3(0.05, 0.0, -0.03), 0.05, 0.25)
	k.at(28.95, M([home(), FL(0.05, 0.0, 0.0), FR(0.05, 0.03, 0.0), shrug(0.2), F("determined")]), "follow", "s")
	k.at(29.15, shrug(0.0), "heavy")
	# 29,4 : un frisson. Il se fige, les yeux s'ouvrent grand.
	k.at(29.4, M([{"shake": 0.65}, shrug(0.5), HD(0.06, 0.04, 0.0), C(-0.02, 0.0, 0.0), CU(0.7), F("fear")]), "snap")
	k.at(29.75, M([{"shake": 0.3}, HD(0.03, 0.22, 0.05)]), "heavy", "s")
	# Il tourne lentement la tête, puis le buste, par-dessus l'épaule gauche.
	k.at(30.35, M([HD(0.02, 1.15, -0.05), C(0.0, 0.42, 0.0), B(0.0, 0.22, 0.0), H(0.0, -0.02, 0.0), {"shake": 0.15}]), "lead")
	k.at(30.6, M([HD(0.0, 1.22, -0.06), C(0.0, 0.46, 0.0)]), "heavy", "s")
	k.hold(30.6, 31.2, 0.25)
	# Rien. Il se remet face à nous, soulagé, souffle.
	k.at(31.75, M([HD(-0.06, 0.12, 0.02), C(0.06, 0.06, 0.0), B(0.03, 0.02, 0.0), H(-0.025, -0.015, 0.0), shrug(-0.1), {"shake": 0.0}, CU(0.3), F("calm")]), "follow")
	k.at(32.05, M([HD(-0.1, 0.04, 0.03), C(0.08, 0.02, 0.0), L(0.24, -0.88, 0.1, 0.15), R(0.23, -0.88, 0.08, 0.15)]), "heavy", "s")
	# 32,25 : une main se pose sur son épaule. Il comprend avant de crier : les yeux d'abord.
	k.at(32.35, M([HD(0.04, -0.1, 0.0), shrug(0.35, 0.15), {"shake": 0.4}, L(0.25, -0.86, 0.1, 0.15), R(0.24, -0.85, 0.08, 0.15), CU(0.6), F("fear")]), "snap")
	k.at(32.75, M([HD(0.05, -0.18, -0.04), {"shake": 0.6}, L(0.26, -0.84, 0.1, 0.15), R(0.25, -0.83, 0.08, 0.15), F("panic"), {"jaw": 0.3}]), "heavy", "s")
	# Le cri : tout le corps se tend, bras qui partent, il décolle presque.
	k.at(32.92, M([H(0.0, 0.05, 0.0), {"sq": 1.06, "jaw": 1.0, "shake": 1.0}, shrug(0.9), HD(0.25, -0.15, 0.05), C(-0.12, 0.0, 0.0), B(-0.08),
		L(0.75, 0.15, 0.35, 0.8), R(0.75, 0.1, 0.3, 0.8), CU(0.1), F("panic")]), "snap")
	k.at(33.2, M([H(0.0, 0.03, 0.0), {"sq": 1.03}]), "heavy", "s")
	k.at(ALONE_LEN, M([{"sq": 1.0}]), "sync")
	return k.clip()


# Alice : trois apparitions, immobile ou presque. Racine téléportée entre deux plans.
static func _alone_alice(rig: Dictionary) -> Dictionary:
	var k: Take = Take.new(ALONE_LEN, "neutral", 5, rig)
	var far: Vector3 = Vector3(-0.3, 0.0, 14.5)
	var mid: Vector3 = Vector3(0.1, 0.0, 6.2)
	var yaw: float = deg_to_rad(SIMON_YAW)
	var facing: Vector3 = Vector3(- sin(yaw), 0.0, - cos(yaw))
	var right: Vector3 = Vector3(cos(yaw), 0.0, - sin(yaw))
	var back: Vector3 = SIMON_AT - facing * 0.3 + right * 0.2
	k.path([[0.0, far, 0.0, "s"], [20.0, far, 0.0, "s"], [20.01, mid, 4.0, "s"], [29.0, mid, 4.0, "s"], [29.01, back, SIMON_YAW - 8.0, "s"], [ALONE_LEN, back, SIMON_YAW - 8.0, "s"]])
	var still: Dictionary = M([stand(0.0), H(0.0, -0.01, 0.0), B(0.0), C(-0.02), HD(-0.08, 0.0, 0.22), L(0.12, -0.96, 0.06, 0.0), R(0.12, -0.96, 0.06, 0.0), WL(0.0), WR(0.0), CU(0.3), F("neutral")])
	k.at(0.0, still, "sync", "s")
	# Au fond du couloir : immobile, la tête qui penche encore un peu.
	k.at(14.0, still, "sync", "s")
	k.at(15.1, M([HD(-0.1, 0.0, 0.32), CU(0.42)]), "heavy", "s")
	# Derrière Simon, floue : la tête penche, les doigts se referment un à un.
	k.at(20.0, M([still, HD(-0.12, -0.08, 0.18)]), "sync", "s")
	k.at(24.4, M([HD(-0.14, -0.06, 0.22), CU(0.3, 0.3)]), "sync", "s")
	k.at(25.8, M([HD(-0.18, -0.1, 0.4), C(0.02, -0.04, 0.0), CU(0.7, 0.45), F("menace")]), "heavy", "s")
	k.at(27.0, M([HD(-0.16, -0.08, 0.45), CU(0.75, 0.6)]), "heavy", "s")
	# Sur son épaule : penchée en avant, le visage à côté du sien, la main qui se pose.
	k.at(29.0, M([still, H(0.0, -0.08, 0.04), B(0.18, -0.1, -0.08), C(0.16, -0.14, -0.06), HD(-0.1, -0.12, -0.2), R(0.05, -0.4, 0.55, 0.3), L(0.12, -0.92, 0.1, 0.0), CU(0.25, 0.4), F("grin")]), "sync", "s")
	k.at(32.2, M([HD(-0.12, -0.16, -0.26), R(0.04, -0.3, 0.62, 0.3)]), "heavy")
	k.at(32.6, M([HD(-0.08, -0.1, -0.32), CU(0.55, 0.45), F("menace")]), "heavy", "s")
	k.at(33.1, M([HD(-0.05, -0.08, -0.36), F("grin")]), "heavy", "s")
	return k.clip()
