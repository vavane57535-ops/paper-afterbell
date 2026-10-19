extends "res://anim_menu_take.gd"

# JOUER : Simon s'échauffe dans le couloir, la nuit ; il se croit seul.
# Simon : nerveux, rapide, petits gestes secs, regard qui file partout.

static func add(c: Dictionary) -> void :
	_warmup(c)
	_gallery(c)

# Galerie de poses de calibrage (temporaire) : une pose par seconde.
static func _gallery(c: Dictionary) -> void :
	var poses: Array = [
		home(),
		M([home(), H(-0.07, -0.03, -0.01), B(0.08, 0.04, 0.06), C(0.04, 0.0, -0.03), HD(-0.05, 0.05, 0.04), FR(0.02, -0.34, 0.8), R(0.1, -0.8, -0.36, 0.0), CU(0.85, 0.1), L(0.7, -0.2, 0.08, 0.7), {"fp_r": 0.9}]),
		M([home(), H(-0.06, -0.03, 0.0), FR(0.0, -0.2, 0.62), R(0.15, -0.55, -0.3, 0.0), WR(0.6), {"fp_r": 1.2}]),
		M([home(), C(0.04, 0.12, 0.0), HD(-0.04, -0.4, 0.0), R(-0.75, -0.02, 0.32, 0.0), WR(0.0), L(-0.42, -0.12, 0.42, 0.3), WL(0.2), CU(0.2, 0.6)]),
		M([home(), HD(0.02, 1.05, -0.04), C(0.0, 0.42, 0.0), B(0.0, 0.25, 0.0)]),
		M([home(), H(0, -0.12, 0.05), B(0.45), C(0.25), HD(0.35), L(0.12, -0.72, 0.32, 0.2), R(0.12, -0.72, 0.32, 0.2), WL(0.6), WR(0.6), CU(0.4)]),
		M([home(), {"plant": 1.0}, H(0.0, -0.45, -0.25), B(-0.1), C(0.1), FL(0.02, 0.3, 0.0), FR(0.02, 0.32, 0.0), L(0.25, -0.75, 0.2, 0.2), R(0.25, -0.75, 0.2, 0.2)]),
		M([home(), H(0.0, -0.55, 0.15), B(0.6), C(0.2), HD(0.5), FL(0.04, 0.45, 0.0), FR(0.04, -0.45, 0.0), L(0.1, -1.0, 0.6, 0.2), R(0.1, -1.0, 0.6, 0.2), {"fp_r": -0.8}]),
	]
	var k: Take = Take.new(float(poses.size()), "neutral", 3)
	for i: int in range(poses.size()):
		k.at(float(i) + 0.05, poses[i], "sync", "s")
		k.at(float(i) + 0.95, poses[i], "sync", "s")
	c["menu_gallery_poses@Simon"] = k.clip()

# Pose de repos de Simon (début et fin de chaque temps fort) : poids un peu sur la gauche,
# épaules souples, mains entrouvertes.
static func home() -> Dictionary:
	return M([stand(0.03), H(-0.025, -0.015, 0.0), B(0.02, 0.0, 0.025), C(0.04, 0.03, -0.015), HD(-0.04, 0.06, 0.03),
		L(0.22, -0.9, 0.08, 0.1), R(0.21, -0.91, 0.05, 0.1), WL(0.1), WR(0.15), CU(0.35, 0.3), F("neutral")])

# Haussement d'épaules (clavicules) : 1 = épaules aux oreilles.
static func shrug(amount: float, left: float = -1.0) -> Dictionary:
	var l: float = amount if left < 0.0 else left
	return {"l_clav": V(0.0, 0.0, -0.32 * l), "r_clav": V(0.0, 0.0, 0.32 * amount)}

# --- Temps fort A : échauffement, le néon grésille, il regarde derrière lui (16 s). ----------
static func _warmup(c: Dictionary) -> void :
	var k: Take = Take.new(16.0, "neutral", 11)
	k.at(0.0, home(), "sync", "s")
	k.at(0.15, shrug(0.0), "sync")
	# Épaules qui roulent, deux fois, la seconde plus ample.
	k.at(0.45, M([shrug(0.55), C(0.0, 0.03), HD(-0.08, 0.04, 0.0), L(0.24, -0.84, 0.0, 0.2), R(0.23, -0.85, 0.0, 0.2)]))
	k.at(0.75, M([shrug(0.2), C(0.1, 0.03), HD(0.02, 0.05, 0.02), L(0.22, -0.9, 0.12, 0.1), R(0.21, -0.9, 0.12, 0.1)]))
	k.at(1.0, M([shrug(0.85), C(-0.04, 0.02), HD(-0.1, 0.04, -0.03), L(0.25, -0.8, -0.04, 0.25), R(0.24, -0.81, -0.04, 0.25)]))
	k.at(1.35, M([shrug(-0.05), C(0.07, 0.02), HD(0.0, 0.06, 0.03), L(0.23, -0.91, 0.07, 0.1), R(0.22, -0.92, 0.06, 0.1), CU(0.2)]), "follow", "s")
	# Il secoue les mains, vite, les poignets mous.
	for i: int in range(6):
		var t: float = 1.45 + i * 0.085
		var up: float = 0.05 if i % 2 == 0 else -0.05
		k.at(t, M([L(0.26, -0.82 + up, 0.12, 0.2), R(0.25, -0.82 - up, 0.14, 0.2), WL(0.6 if i % 2 == 0 else -0.5), WR(-0.5 if i % 2 == 0 else 0.6), CU(0.05)]), "snap")
	k.at(2.05, M([L(0.24, -0.88, 0.1, 0.15), R(0.23, -0.88, 0.1, 0.15), WL(0.1), WR(0.1), CU(0.25), HD(-0.12, 0.0, 0.0), F("focus")]), "follow", "s")
	# Étirement du quadriceps droit : le poids passe à gauche, la main droite va chercher la cheville.
	k.at(2.4, M([H(-0.06, -0.02, 0.0), B(0.05, 0.0, 0.06), C(0.06, 0.0, -0.03), HD(-0.18, 0.0, 0.0), L(0.4, -0.7, 0.1, 0.4), FR(0.02, -0.05, 0.12), {"fp_r": 0.3}]), "follow")
	k.at(2.75, M([H(-0.075, -0.035, -0.02), B(0.18, 0.06, 0.07), C(0.1, 0.0, -0.04), HD(-0.3, 0.1, 0.05), FR(0.02, -0.38, 0.72), R(0.12, -0.78, -0.42, 0.0), WR(0.4), CU(0.6, 0.15), L(0.62, -0.38, 0.12, 0.6), {"fp_r": 0.9}]), "follow")
	k.at(3.05, M([H(-0.07, -0.03, -0.01), B(0.08, 0.04, 0.06), C(0.04, 0.0, -0.03), HD(-0.05, 0.05, 0.04), FR(0.02, -0.34, 0.8), R(0.1, -0.8, -0.36, 0.0), CU(0.85, 0.1), L(0.7, -0.2, 0.08, 0.7), F("focus")]), "follow", "s")
	# Il tangue... petit saut sur le pied gauche pour se rattraper.
	k.at(3.45, M([H(-0.04, -0.035, 0.0), B(0.06, 0.0, 0.0), C(0.02, 0.0, 0.03), HD(-0.02, 0.1, -0.06), L(0.78, 0.05, 0.0, 0.9), F("surprise")]), "snap")
	k.at(3.65, M([H(-0.1, -0.03, 0.02), B(0.07, 0.0, 0.12), C(0.0, 0.0, -0.08), HD(0.04, 0.0, 0.1), L(0.85, -0.1, 0.2, 0.9), {"sq": 1.0}]), "snap")
	k.at(3.78, M([H(-0.08, -0.07, 0.0), FL(0.0, 0.03, 0.0), {"sq": 0.97}]), "snap")
	k.at(3.92, M([H(-0.08, 0.04, 0.02), FL(0.0, 0.05, 0.08), {"sq": 1.03, "fp_l": -0.4}]), "snap")
	k.at(4.08, M([H(-0.075, -0.05, 0.03), FL(0.0, 0.07, 0.0), B(0.08, 0.0, 0.03), {"sq": 0.98, "fp_l": 0.0}]), "snap", "s")
	k.at(4.3, M([H(-0.07, -0.03, 0.02), B(0.07, 0.03, 0.05), C(0.04, 0.0, -0.02), HD(-0.08, 0.05, 0.02), L(0.66, -0.3, 0.1, 0.6), {"sq": 1.0}, F("smile")]), "heavy", "s")
	k.hold(4.3, 5.0, 0.7)
	# Il lâche la jambe droite, la secoue, puis la gauche.
	k.at(5.25, M([H(-0.03, -0.02, 0.0), B(0.04, 0.0, 0.02), FR(0.02, 0.1, 0.25), R(0.25, -0.86, 0.05, 0.15), CU(0.3), L(0.3, -0.85, 0.08, 0.2), HD(-0.12, -0.05, 0.0), {"fp_r": -0.3}, F("neutral")]))
	k.at(5.45, M([FR(0.03, -0.04, 0.14), {"fp_r": 0.5}]), "snap")
	k.at(5.6, M([FR(0.03, 0.06, 0.1), {"fp_r": -0.2}]), "snap")
	k.at(5.8, M([H(0.0, -0.015, 0.0), FR(0.02, 0.0, 0.0), B(0.02, 0.0, 0.0), {"fp_r": 0.0}]), "follow", "s")
	k.at(6.1, M([H(0.065, -0.03, 0.0), B(0.08, -0.04, -0.06), C(0.06, 0.0, 0.03), HD(-0.2, -0.05, 0.0), R(0.4, -0.7, 0.1, 0.4), FL(0.02, -0.05, 0.12), {"fp_l": 0.3}, F("determined")]))
	k.at(6.45, M([H(0.075, -0.035, -0.015), B(0.15, -0.05, -0.07), C(0.08, 0.0, 0.03), HD(-0.22, -0.05, -0.04), FL(0.02, -0.36, 0.78), L(0.12, -0.8, -0.38, 0.0), WL(0.4), CU(0.15, 0.85), R(0.55, -0.42, 0.12, 0.5), {"fp_l": 0.9}]), "follow", "s")
	k.at(6.75, M([B(0.06, -0.03, -0.06), C(0.02, 0.0, 0.03), HD(0.02, -0.12, 0.02), R(0.62, -0.36, 0.14, 0.55), F("smile")]), "follow", "s")
	k.hold(6.75, 7.45, 0.6)
	k.at(7.7, M([H(0.0, -0.015, 0.0), B(0.03, 0.0, 0.0), C(0.04), FL(0.03, 0.0, 0.0), L(0.24, -0.88, 0.08, 0.1), R(0.23, -0.88, 0.08, 0.1), CU(0.3), HD(-0.05, 0.05, 0.0), {"fp_l": 0.0}, F("neutral")]), "follow", "s")
	# Bras droit en travers de la poitrine, la main gauche tient le coude ; il regarde à droite.
	k.at(8.1, M([C(0.04, 0.12, 0.0), HD(-0.04, -0.4, 0.0), R(-0.45, 0.02, 0.38, 0.0), WR(-0.2, 0.0, 0.3), L(-0.05, -0.2, 0.42, 0.5), WL(0.3), CU(0.2, 0.6)]))
	k.at(8.45, M([C(0.05, 0.16, 0.0), HD(-0.06, -0.55, 0.03), R(-0.58, 0.03, 0.34, 0.0), L(-0.12, -0.18, 0.4, 0.5)]), "heavy", "s")
	k.hold(8.45, 9.0, 0.5)
	# Le néon grésille : il se fige, les yeux au plafond.
	k.at(9.08, M([shrug(0.35), HD(0.22, -0.25, 0.0), B(-0.03, 0.0, 0.0), {"sq": 1.02}, F("surprise")]), "lead")
	k.at(9.3, M([HD(0.38, -0.08, 0.04), C(0.0, 0.1, 0.0), F("fear")]), "lead", "s")
	k.hold(9.3, 9.95, 0.25, "snap")
	# Le néon tient. Il souffle, les épaules retombent, petit hochement de tête dépité.
	k.at(10.15, M([shrug(-0.1), HD(0.1, -0.05, 0.0), C(0.1, 0.05, 0.0), B(0.05), {"sq": 1.0}, F("tired")]), "heavy")
	k.at(10.45, M([R(0.24, -0.86, 0.08, 0.1), L(0.24, -0.86, 0.1, 0.1), WR(0.1), WL(0.1), CU(0.3), HD(-0.18, 0.04, 0.0), C(0.14, 0.0, 0.0)]), "heavy", "s")
	k.at(10.7, HD(-0.16, 0.18, 0.05), "snap")
	k.at(10.88, HD(-0.15, -0.14, -0.05), "snap")
	k.at(11.08, M([HD(-0.12, 0.04, 0.0), C(0.06), shrug(0.0), F("neutral")]), "follow", "s")
	# Il fait rouler sa tête... et la rotation s'arrête net vers l'arrière : un coup d'œil derrière lui.
	k.at(11.35, HD(-0.05, 0.0, 0.32), "follow")
	k.at(11.6, HD(0.18, 0.15, 0.1), "follow")
	k.at(11.85, M([HD(0.1, 0.6, -0.2), C(0.04, 0.2, 0.0)]), "follow")
	k.at(12.05, M([HD(0.02, 1.05, -0.04), C(0.0, 0.42, 0.0), B(0.0, 0.25, 0.0), H(0.0, -0.02, 0.0), L(0.26, -0.86, 0.02, 0.1), R(0.2, -0.88, 0.14, 0.1), F("surprise")]), "lead", "s")
	k.at(12.6, M([HD(0.0, 1.12, 0.02), C(0.0, 0.46, 0.0), F("fear")]), "heavy", "s")
	k.hold(12.6, 13.1, 0.2)
	# Rien. Il se retourne, se frotte le nez, haussement d'épaules.
	k.at(13.35, M([HD(-0.05, 0.25, 0.0), C(0.03, 0.1, 0.0), B(0.02, 0.05, 0.0), F("neutral")]), "lead")
	k.at(13.6, M([HD(-0.08, 0.0, 0.0), C(0.06, 0.0, 0.0), B(0.02, 0.0, 0.02), R(-0.05, 0.12, 0.45, 0.3), WR(0.4, 0.0, -0.2), {"gesture": "point"}, CU(0.6)]), "follow")
	k.at(13.8, M([R(-0.1, 0.14, 0.42, 0.3), HD(-0.02, 0.03, 0.06)]), "snap")
	k.at(13.95, M([R(-0.03, 0.12, 0.44, 0.3), HD(-0.06, -0.03, -0.04)]), "snap")
	k.at(14.25, M([R(0.22, -0.88, 0.06, 0.1), WR(0.15), {"gesture": ""}, CU(0.35, 0.3), shrug(0.4), HD(-0.02, 0.08, 0.06), F("smile")]), "follow")
	k.at(14.6, M([shrug(0.0), home()]), "heavy", "s")
	k.hold(14.6, 16.0, 0.6)
	k.at(16.0, home(), "sync", "s")
	c["menu_play_warmup@Simon"] = k.clip()
