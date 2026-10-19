extends "res://anim_menu_take.gd"

# RÉGLAGES : Ashura règle Lysia, assise sur un tabouret, la trappe du dos ouverte.
# Lysia : automate un peu cassée, gestes par à-coups, arrêts nets, petites saccades.
# Ashura : posé et sec, gestes économes, regards en coin, soupirs.

const LYSIA_AT: Vector3 = Vector3(0.05, 0.0, 0.4)
const LYSIA_YAW: float = 18.0
const ASH_AT: Vector3 = Vector3(-0.13, 0.0, 0.9)
const ASH_YAW: float = -29.0

static func writers(rigs: Dictionary) -> Array:
	return [
		func() -> Dictionary: return {"menu_settings_tune@Lysia": _tune_lysia(rigs.lysia)},
		func() -> Dictionary: return {"menu_settings_tune@Ashura": _tune_ash(rigs.ash)},
	]

# --- Poses de base ---------------------------------------------------------------------------

# Lysia assise : bassin sur le tabouret, pieds à plat devant, mains sur les cuisses.
static func seat() -> Dictionary:
	return M([rest(), start(), H(0.0, -0.3, -0.07), FL(0.07, 0.4, 0.0), FR(0.07, 0.42, 0.0), B(0.03), C(0.02), HD(0.0),
		L(0.04, -0.7, 0.5, 0.1), R(0.04, -0.7, 0.5, 0.1), WL(0.35, 0.0, 0.1), WR(0.35, 0.0, -0.1), CU(0.3)])

# Éteinte : tête tombée, buste affaissé, mains ouvertes sur les cuisses.
static func off() -> Dictionary:
	return M([seat(), B(0.06), C(0.22, 0.0, 0.04), HD(-0.62, 0.05, 0.12), L(0.06, -0.72, 0.48, 0.0), R(0.05, -0.73, 0.47, 0.0), CU(0.15), F("asleep")])

# Ashura au travail derrière elle : penché, le regard sur la trappe.
static func work() -> Dictionary:
	return M([stand(0.03), H(0.0, -0.04, 0.03), B(0.16, 0.0, 0.0), C(0.12, 0.05, 0.0), HD(-0.3, 0.08, 0.0),
		R(-0.12, -0.42, 0.78, 0.25), L(0.05, -0.35, 0.72, 0.25), WR(0.4, 0.0, 0.0), WL(0.2), CU(0.8, 0.3), F("focus")])

# --- « Calibrage » (32 s) ---------------------------------------------------------------------
# Elle démarre par à-coups, regarde ses mains, sa tête tourne trop loin ; molette « vitesse » :
# un coucou au ralenti, puis en accéléré (Ashura esquive) ; un coucou normal, un pouce à
# l'envers qu'il remet à l'endroit ; une étincelle, elle s'éteint ; il soupire, se remet au travail.
const TUNE_LEN: float = 32.0

static func _tune_lysia(rig: Dictionary) -> Dictionary:
	var k: Take = Take.new(TUNE_LEN, "asleep", 21, rig)
	k.lag_scale = 0.5
	k.at(0.0, off(), "sync", "s")
	k.hold(0.0, 4.9, 0.25)
	# 5,0 : démarrage. Un frisson, puis la tête remonte en trois crans.
	k.at(5.0, M([{"shake": 0.7}, C(0.2, 0.0, 0.04), HD(-0.6, 0.05, 0.12)]), "sync", "s")
	k.at(5.3, M([{"shake": 0.2}, HD(-0.36, 0.02, 0.05), C(0.14, 0.0, 0.02)]), "snap", "s")
	k.at(5.62, M([HD(-0.16, -0.02, 0.0), C(0.08, 0.0, 0.0), B(0.04)]), "snap", "s")
	k.at(5.92, M([{"shake": 0.0}, HD(0.06, 0.0, -0.04), C(0.0, 0.0, 0.0), F("surprise")]), "snap", "s")
	k.at(6.05, M([HD(0.0, 0.0, 0.0), C(0.02)]), "snap", "s")
	k.at(6.45, F("neutral"), "sync")
	# Les mains décollent des cuisses : petit tic, puis elle les lève devant ses yeux.
	k.at(6.6, M([L(0.06, -0.66, 0.5, 0.1), R(0.06, -0.66, 0.5, 0.1), CU(0.5)]), "snap", "s")
	k.at(6.75, M([L(0.04, -0.71, 0.49, 0.1), R(0.04, -0.71, 0.49, 0.1), CU(0.2)]), "snap", "s")
	k.at(7.3, M([Lt(0.1, -0.2, 0.7, 0.3), Rt(0.1, -0.22, 0.68, 0.3), WL(-0.5, -0.6, 0.0), WR(-0.5, 0.6, 0.0), HD(-0.25, 0.0, 0.0), CU(0.1)]), "follow", "s")
	# Les doigts bougent un par un (courbure par à-coups), la tête penche par crans.
	var fingers: Array = [[7.55, 0.7, 0.1], [7.7, 0.1, 0.7], [7.85, 0.85, 0.2], [8.0, 0.2, 0.9], [8.12, 0.6, 0.6], [8.3, 0.05, 0.05]]
	for entry: Array in fingers: k.at(float(entry[0]), CU(float(entry[1]), float(entry[2])), "sync", "s")
	k.at(8.2, M([HD(-0.25, 0.0, 0.18)]), "snap", "s")
	k.at(8.55, M([HD(-0.23, 0.0, -0.16), WL(-0.5, 0.2, 0.0), WR(-0.5, -0.2, 0.0)]), "snap", "s")
	k.at(8.9, M([HD(-0.22, 0.0, 0.0), F("smile")]), "snap", "s")
	# Mains reposées.
	k.at(9.4, M([L(0.04, -0.7, 0.5, 0.1), R(0.04, -0.7, 0.5, 0.1), WL(0.35, 0.0, 0.1), WR(0.35, 0.0, -0.1), CU(0.3), HD(0.0, 0.0, 0.0)]), "follow", "s")
	# 10,0 : elle tourne la tête vers Ashura (à sa gauche)… et continue, bien trop loin.
	k.at(10.0, HD(0.02, 0.35, 0.0), "sync")
	k.at(10.4, HD(0.04, 0.95, 0.0), "sync", "l")
	k.at(10.85, M([HD(0.05, 1.85, 0.02), F("smile")]), "sync", "l")
	k.at(11.05, HD(0.05, 2.05, 0.02), "sync", "s")
	# Ashura la remet droite, la main sur le crâne : la tête revient par crans.
	k.at(11.35, HD(0.04, 1.6, 0.0), "snap", "s")
	k.at(11.6, HD(0.02, 1.0, 0.0), "snap", "s")
	k.at(11.85, HD(0.0, 0.4, 0.0), "snap", "s")
	k.at(12.05, M([HD(-0.02, 0.0, 0.0), F("neutral")]), "snap", "s")
	k.hold(12.05, 14.3, 0.15, "snap")
	# 14,4 : molette « vitesse » au minimum : un coucou au ralenti (main gauche, vers nous).
	k.at(14.5, M([F("smile")]), "sync")
	k.at(16.0, M([L(0.3, 0.35, 0.3, 0.6), WL(0.0, 0.0, 0.0), {"curl_l": 0.05}, HD(0.04, -0.12, -0.08), B(0.02, -0.06, 0.0), C(0.0, -0.08, 0.03)]), "sync")
	k.at(16.9, M([L(0.45, 0.38, 0.25, 0.6), WL(0.0, 0.0, 0.35)]), "sync")
	k.at(17.75, M([L(0.25, 0.42, 0.3, 0.6), WL(0.0, 0.0, -0.35)]), "sync")
	# 18,4 : molette au maximum : coucou frénétique, l'autre bras s'y met, la tête tremble.
	var t: float = 18.4
	var beat_i: int = 0
	while t < 20.55:
		var a: float = 0.62 if beat_i % 2 == 0 else -0.55
		var b: float = 0.3 + 0.1 * float(beat_i % 3)
		var pose: Dictionary = M([L(0.35 + 0.18 * a, 0.42 + 0.08 * float(beat_i % 2), 0.28, 0.6), WL(0.0, 0.0, - a * 0.8), {"curl_l": 0.05}])
		if t > 18.9: pose.merge(M([R(0.4 - 0.2 * a, 0.2 + 0.25 * b, 0.35, 0.6), WR(0.0, 0.0, a * 0.7), {"curl": 0.05}]), true)
		pose.merge(M([HD(0.04 + 0.04 * a, -0.12 - 0.1 * a, -0.08 * a), {"shake": 0.6, "jaw": 0.35 + 0.25 * float(beat_i % 2)}]), true)
		if beat_i == 2: pose.merge(F("laugh"), true)
		k.at(t, pose, "sync")
		t += 0.085 + 0.012 * float(beat_i % 3)
		beat_i += 1
	# 20,6 : Ashura remet la molette : arrêt net, figée bras en l'air, bouche ouverte.
	k.at(20.62, M([L(0.42, 0.45, 0.28, 0.6), WL(0.0, 0.0, -0.5), R(0.3, 0.45, 0.32, 0.6), WR(0.0, 0.0, 0.4), HD(0.12, -0.18, -0.15), {"shake": 0.0, "jaw": 0.5}, F("surprise")]), "sync", "s")
	k.hold(20.62, 21.25, 0.05, "sync")
	# Elle baisse les bras, puis un vrai coucou poli, vers nous.
	k.at(21.5, M([R(0.04, -0.7, 0.5, 0.1), WR(0.35, 0.0, -0.1), {"curl": 0.3, "jaw": 0.0}, HD(0.0, 0.0, 0.0), F("neutral")]), "snap", "s")
	k.at(21.75, M([L(0.25, 0.1, 0.35, 0.6), WL(0.0, 0.0, 0.0)]), "follow")
	k.at(22.0, M([L(0.32, 0.35, 0.28, 0.6), WL(0.0, 0.0, 0.3), {"curl_l": 0.05}, HD(0.04, -0.1, -0.18), F("smile")]), "follow")
	k.at(22.3, M([WL(0.0, 0.0, -0.35)]), "follow")
	k.at(22.55, M([WL(0.0, 0.0, 0.3)]), "follow")
	k.at(22.8, M([WL(0.0, 0.0, -0.25), HD(0.04, -0.06, -0.1)]), "follow")
	k.at(23.15, M([L(0.04, -0.7, 0.5, 0.1), WL(0.35, 0.0, 0.1), {"curl_l": 0.3}, HD(0.0, 0.3, 0.0)]), "follow", "s")
	# 23,6 : Ashura approuve ; elle lève fièrement le pouce… à l'envers. Il le montre du doigt ;
	# elle regarde sa main et la retourne en trois crans de cliquet.
	k.at(23.9, M([R(0.12, -0.12, 0.62, 0.4), WR(0.0, 2.7, 0.0), {"gesture": "thumbsup"}, HD(-0.05, 0.12, 0.0), F("smile")]), "follow", "s")
	k.hold(23.9, 24.75, 0.08, "sync")
	k.at(24.95, M([HD(-0.32, -0.05, 0.0), F("surprise")]), "lead", "s")
	k.at(25.2, WR(0.0, 1.8, 0.0), "sync", "s")
	k.at(25.4, WR(0.0, 0.9, 0.0), "sync", "s")
	k.at(25.6, WR(0.0, 0.0, 0.0), "sync", "s")
	k.at(25.85, M([HD(-0.1, 0.1, 0.12), F("smile")]), "snap", "s")
	k.hold(25.85, 26.35, 0.08, "sync")
	# 26,4 : grésillement dans le dos… 27,4 : l'étincelle. Elle se fige, puis s'éteint par crans.
	k.at(26.45, M([{"shake": 0.35}, HD(-0.08, 0.12, 0.12)]), "snap", "s")
	k.at(27.4, M([{"shake": 1.0}, HD(0.08, 0.1, 0.02), C(-0.04), F("surprise"), {"jaw": 0.3}]), "sync", "s")
	k.at(27.75, M([{"shake": 0.2, "jaw": 0.1}, HD(-0.25, 0.08, 0.06), C(0.1), {"gesture": ""}]), "snap", "s")
	k.at(28.1, M([{"shake": 0.0, "jaw": 0.0}, HD(-0.62, 0.05, 0.12), C(0.22, 0.0, 0.04), B(0.06), R(0.05, -0.73, 0.47, 0.0), WR(0.35, 0.0, -0.1), L(0.06, -0.72, 0.48, 0.0), CU(0.15), F("asleep")]), "snap", "s")
	k.hold(28.1, TUNE_LEN, 0.2)
	k.at(TUNE_LEN, off(), "sync", "s")
	return k.clip()

static func _tune_ash(rig: Dictionary) -> Dictionary:
	var k: Take = Take.new(TUNE_LEN, "focus", 22, rig)
	k.at(0.0, work(), "sync", "s")
	# Il visse : trois quarts de tour, reprise de la main, encore (poignet, jamais régulier).
	var turns: Array = [[0.4, 0.5], [0.85, -0.2], [1.2, 0.65], [1.75, -0.1], [2.1, 0.55], [2.55, -0.25], [2.95, 0.6], [3.35, 0.0]]
	for entry: Array in turns: k.at(float(entry[0]), M([WR(0.4, float(entry[1]), 0.0), HD(-0.3 + 0.03 * float(entry[1]), 0.08, 0.0)]), "follow")
	k.at(3.6, M([HD(-0.24, 0.05, 0.05)]), "heavy", "s")
	# Il retire le tournevis, se redresse, puis appuie sur le bouton de l'index gauche.
	k.at(4.0, M([R(0.15, -0.55, 0.4, 0.25), WR(0.2), B(0.08), C(0.05, 0.05, 0.0), HD(-0.2, 0.1, 0.0)]), "follow")
	k.at(4.45, M([L(0.0, -0.36, 0.76, 0.25), CU(0.8, 0.6)]), "follow")
	k.at(4.75, M([L(0.0, -0.37, 0.8, 0.25)]), "snap", "s")
	k.at(5.05, M([L(0.15, -0.6, 0.4, 0.2), CU(0.8, 0.3), B(0.04), C(0.0, 0.1, 0.0), HD(-0.12, 0.2, 0.0), F("calm")]), "heavy")
	# Il se penche par-dessus son épaule gauche pour voir son visage pendant qu'elle démarre.
	k.at(6.0, M([H(0.0, -0.03, 0.04), B(0.18, 0.12, 0.05), C(0.1, 0.2, 0.05), HD(-0.14, -0.15, 0.08), R(0.15, -0.75, 0.3, 0.2), L(0.1, -0.75, 0.25, 0.2), CU(0.7, 0.4)]), "heavy", "s")
	k.hold(6.0, 9.7, 0.4)
	# 10,4 : sa tête tourne vers lui, puis bien trop loin. Il fronce, pose la main gauche sur son crâne.
	k.at(10.2, M([HD(-0.12, -0.1, 0.0), B(0.1, 0.05, 0.0), C(0.06, 0.1, 0.0), F("neutral")]), "lead")
	k.at(10.6, M([H(0.0, -0.01, -0.03), B(0.02, 0.05, 0.0), HD(0.02, -0.05, 0.0), F("surprise")]), "snap")
	k.at(10.8, M([L(0.0, 0.1, 0.75, 0.35), CU(0.8, 0.25), F("tired")]), "follow")
	k.at(11.05, M([L(0.0, 0.12, 0.8, 0.35), B(0.12, 0.05, 0.0)]), "heavy", "s")
	k.at(12.1, M([L(0.0, 0.08, 0.78, 0.35)]), "sync", "s")
	k.at(12.45, M([L(0.1, -0.5, 0.45, 0.2), CU(0.8, 0.4), F("focus")]), "follow")
	# 12,6 : molette (main gauche) : petit tour, grand tour.
	k.at(12.9, M([L(-0.02, -0.4, 0.78, 0.25), B(0.18, 0.0, 0.0), C(0.12, 0.05, 0.0), HD(-0.32, 0.08, 0.0), WL(0.2, 0.0, 0.0)]), "follow", "s")
	k.at(13.3, WL(0.2, -0.6, 0.0), "follow")
	k.at(13.7, WL(0.2, -1.3, 0.0), "follow", "s")
	k.at(14.1, M([L(0.12, -0.55, 0.45, 0.2), WL(0.1), B(0.1, 0.05, 0.0), HD(-0.1, -0.1, 0.05), F("calm")]), "heavy")
	# Le coucou au ralenti : il attend, nous regarde, soupire, tapote du pied.
	k.at(15.2, M([shrug(0.3), HD(0.1, -0.55, 0.0), C(0.08, -0.2, 0.0), F("tired")]), "heavy")
	k.at(15.7, M([shrug(-0.1), HD(0.0, -0.6, 0.05)]), "heavy", "s")
	for i: int in range(4):
		k.at(16.1 + 0.32 * i, {"fp_r": 0.35}, "sync")
		k.at(16.25 + 0.32 * i, {"fp_r": 0.0}, "sync")
	k.at(17.4, M([HD(-0.1, -0.05, -0.05), C(0.12, 0.05, 0.0)]), "heavy", "s")
	# 17,8 : il tourne la molette à fond, d'un coup sec.
	k.at(17.85, M([L(-0.02, -0.4, 0.8, 0.25), B(0.18, 0.0, 0.0), C(0.12, 0.05, 0.0), HD(-0.3, 0.08, 0.0), WL(0.2, 0.0, 0.0), F("focus")]), "follow", "s")
	k.at(18.15, WL(0.2, 1.4, 0.0), "snap", "s")
	# Le bras de Lysia passe sous son nez : il recule, se baisse sous le moulinet.
	k.at(18.55, M([H(0.0, -0.02, -0.08), B(-0.05, -0.1, 0.0), C(-0.05, -0.15, 0.0), HD(0.05, -0.2, 0.1), L(0.3, -0.4, 0.3, 0.4), R(0.3, -0.45, 0.3, 0.4), CU(0.5), F("surprise")]), "snap")
	k.at(19.1, M([H(0.0, -0.32, -0.04), B(0.35, -0.1, 0.0), C(0.15, -0.1, 0.0), HD(0.1, -0.2, 0.0), FL(0.06, 0.0, 0.0), FR(0.06, -0.08, 0.0), L(0.35, 0.15, 0.35, 0.5), R(0.3, 0.1, 0.4, 0.5), F("fear")]), "snap", "s")
	k.at(19.5, M([HD(0.14, -0.15, -0.06)]), "snap", "s")
	# Accroupi, il passe la main sous le bras et coupe la molette.
	k.at(20.05, M([L(-0.05, -0.3, 0.85, 0.3), B(0.3, 0.0, 0.0), HD(0.0, 0.0, 0.0), F("determined")]), "follow")
	k.at(20.5, WL(0.2, -0.4, 0.0), "snap", "s")
	k.hold(20.6, 21.3, 0.2, "snap")
	# Il se relève, époussette sa veste, et approuve d'un hochement.
	k.at(21.75, M([H(0.0, -0.03, 0.02), B(0.08), C(0.06, 0.1, 0.0), HD(-0.08, 0.0, 0.05), FR(0.06, 0.0, 0.0), L(0.15, -0.6, 0.4, 0.2), R(0.15, -0.65, 0.35, 0.2), CU(0.5), F("calm")]), "heavy")
	k.at(22.1, M([L(0.0, -0.45, 0.45, 0.3), WL(0.5, 0.0, 0.3)]), "follow")
	k.at(22.3, M([L(0.05, -0.55, 0.35, 0.3), WL(0.5, 0.0, -0.2)]), "snap")
	k.at(22.5, M([L(0.15, -0.65, 0.3, 0.2), WL(0.1)]), "follow", "s")
	k.at(23.2, M([HD(-0.2, -0.05, 0.0)]), "follow")
	k.at(23.4, M([HD(-0.05, -0.05, 0.0), F("smile")]), "snap", "s")
	# Le pouce à l'envers : il le montre de l'index, les yeux au ciel.
	k.at(24.2, M([HD(-0.2, -0.1, 0.0), F("tired")]), "lead", "s")
	k.at(24.55, M([L(-0.05, -0.3, 0.75, 0.25), {"curl_l": 0.75}, B(0.16, 0.05, 0.0), C(0.08, 0.1, 0.0)]), "follow", "s")
	k.at(25.0, M([HD(0.05, -0.15, 0.0)]), "heavy")
	k.at(25.7, M([L(0.12, -0.6, 0.4, 0.2), {"curl_l": 0.3}, B(0.08), HD(-0.12, -0.05, 0.0), F("smile")]), "follow", "s")
	k.hold(25.7, 26.4, 0.2)
	# Grésillement : son sourire tombe. L'étincelle : il sursaute.
	k.at(26.6, M([HD(-0.2, 0.05, 0.0), F("neutral")]), "lead", "s")
	k.at(27.45, M([H(0.0, 0.03, -0.06), B(-0.1, -0.1, 0.0), C(-0.08, -0.12, 0.0), HD(0.12, -0.15, 0.1), {"sq": 1.05}, R(0.35, -0.3, 0.3, 0.5), L(0.3, -0.35, 0.3, 0.5), CU(0.2), F("surprise")]), "snap")
	k.at(27.75, M([H(0.0, -0.01, -0.03), {"sq": 1.0}, B(0.0, -0.05, 0.0), HD(0.0, -0.05, 0.0), R(0.2, -0.75, 0.2, 0.2), L(0.2, -0.75, 0.2, 0.2), CU(0.5)]), "heavy", "s")
	# Il la regarde s'éteindre, puis tourne la tête vers nous. Soupir.
	k.at(28.6, M([HD(-0.12, 0.05, 0.0), F("neutral")]), "heavy", "s")
	k.at(29.1, M([HD(0.0, -0.6, 0.0), C(0.04, -0.2, 0.0), B(0.0, -0.08, 0.0), F("tired")]), "lead")
	k.at(29.4, M([HD(0.02, -0.65, 0.03)]), "heavy", "s")
	k.at(29.9, M([shrug(0.35), HD(0.12, -0.6, 0.0)]), "heavy")
	k.at(30.3, M([shrug(0.0), HD(-0.08, -0.58, 0.0)]), "heavy", "s")
	# Retour au travail : tournevis dans la trappe.
	k.at(31.2, M([work()]), "follow")
	k.at(TUNE_LEN, work(), "sync", "s")
	return k.clip()

static func shrug(amount: float) -> Dictionary:
	return {"l_clav": V(0.0, 0.0, -0.32 * amount), "r_clav": V(0.0, 0.0, 0.32 * amount)}
