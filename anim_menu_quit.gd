extends "res://anim_menu_take.gd"

# QUITTER : Bleuette veut rentrer ; la porte du hall est fermée. Alice, au fond, lui dit au revoir.
# Bleuette : timide, petits gestes rentrés, épaules hautes, elle bégaie (mâchoire qui claque).
# Alice : ne marche jamais, ne se presse jamais ; elle est déjà plus près quand la lumière s'éteint.

const DOOR_Z: float = 6.2
const BAR_Y: float = 1.0
const LAMPS_Z: Array = [-4.4, -1.4, 1.6, 4.3]
# Bleuette face à la porte (lacet 180° : elle regarde vers +z), puis sur l'autre battant,
# puis contre la vitre, et enfin dos à la porte, face au hall.
const BLEU_AT: Vector3 = Vector3(0.33, 0.0, 5.86)
const BLEU_SIDE: Vector3 = Vector3(-0.34, 0.0, 5.86)
const BLEU_GLASS: Vector3 = Vector3(-0.36, 0.0, 6.0)
const BLEU_BACK: Vector3 = Vector3(-0.24, 0.0, 6.0)
const ALICE_AT: Array = [Vector3(-0.22, 0.0, -4.4), Vector3(0.12, 0.0, -1.4), Vector3(-0.14, 0.0, 1.6), Vector3(0.02, 0.0, 5.02)]
const LEAVE_LEN: float = 31.0

static func writers(rigs: Dictionary) -> Array:
	return [
		func() -> Dictionary: return {"menu_quit_leave@Bleuette": _leave_bleu(rigs.bleu)},
		func() -> Dictionary: return {"menu_quit_leave@Alice": _leave_alice(rigs.alice)},
	]

static func shrug(amount: float, left: float = -1.0) -> Dictionary:
	var l: float = amount if left < 0.0 else left
	return {"l_clav": V(0.0, 0.0, -0.32 * l), "r_clav": V(0.0, 0.0, 0.32 * amount)}

# Bleuette qui pousse la barre : penchée, les bras tendus, les épaules rentrées.
static func push(force: float) -> Dictionary:
	return M([H(0.0, -0.03 - 0.03 * force, -0.05 - 0.07 * force), B(0.12 + 0.12 * force, 0.0, 0.0), C(0.05 + 0.05 * force), HD(0.24 - 0.2 * force, 0.0, 0.0),
		L(0.14, -0.38, 0.58 + 0.08 * force, 0.25), R(0.14, -0.38, 0.58 + 0.08 * force, 0.25), WL(-0.35), WR(-0.35), CU(0.75), shrug(0.15 + 0.1 * force)])

# Debout, timide : genoux un peu rentrés, épaules hautes, mains serrées sur les bretelles du sac.
static func shy() -> Dictionary:
	return M([stand(0.0), FL(-0.01, 0.0, 0.0), FR(-0.01, 0.02, 0.0), H(0.0, -0.015, 0.0), B(0.03), C(0.06), HD(-0.12, 0.0, 0.04),
		L(0.05, -0.12, 0.2, 0.0), R(0.05, -0.12, 0.2, 0.0), WL(0.3), WR(0.3), CU(0.85), shrug(0.25)])

static func _leave_bleu(rig: Dictionary) -> Dictionary:
	var k: Take = Take.new(LEAVE_LEN, "fear", 31, rig)
	k.lag_scale = 0.85
	var turn_mid: Vector3 = BLEU_GLASS.lerp(BLEU_BACK, 0.5) + Vector3(0.04, 0.0, -0.06)
	k.path([[0.0, BLEU_AT, 180.0, "s"], [3.62, BLEU_AT, 180.0, "s"], [4.28, BLEU_SIDE, 180.0, "s"], [7.85, BLEU_SIDE, 180.0, "s"], [8.3, BLEU_GLASS, 180.0, "s"],
		[11.95, BLEU_GLASS, 180.0, "s"], [12.75, turn_mid, 95.0, ""], [13.55, BLEU_BACK, 0.0, "s"], [LEAVE_LEN, BLEU_BACK, 0.0, "s"]])
	# 0 : elle pousse la barre, une fois, deux fois ; la porte ne bouge pas.
	k.at(0.0, M([stand(0.02), push(0.0), F("determined")]), "sync", "s")
	k.at(0.42, push(1.0), "snap")
	k.at(0.7, push(0.3), "follow")
	k.at(1.02, push(0.85), "snap")
	k.at(1.4, M([push(0.1), HD(-0.05, 0.0, 0.0)]), "heavy", "s")
	# Elle recule la tête, regarde la serrure en haut, incrédule.
	k.at(1.75, M([HD(0.25, 0.08, 0.05), C(0.02), B(0.08), F("surprise")]), "lead")
	k.at(2.0, M([HD(0.28, -0.06, -0.04)]), "heavy", "s")
	# Deux coups d'épaule, tout le corps, la tête rentrée.
	k.at(2.3, M([push(0.0), HD(-0.1, 0.0, 0.0), F("determined")]), "follow")
	k.at(2.45, M([push(1.25), HD(-0.18, 0.0, 0.06)]), "snap")
	k.at(2.65, push(0.4), "follow")
	k.at(2.85, M([push(1.35), HD(-0.2, 0.0, -0.05), {"jaw": 0.25}]), "snap")
	k.at(3.15, M([push(0.2), {"jaw": 0.0}, F("sad")]), "heavy", "s")
	# Elle lâche, se décale vers l'autre battant (deux petits pas vers sa droite).
	k.at(3.5, M([B(0.06), C(0.05), HD(-0.08, -0.2, 0.0), L(0.1, -0.6, 0.35, 0.1), R(0.1, -0.6, 0.35, 0.1), WL(0.0), WR(0.0), CU(0.5), shrug(0.1), F("focus")]), "lead")
	k.steps([[1, 3.63, 3.8, {"lift": 0.035}], [-1, 3.79, 3.96, {"lift": 0.03}], [1, 3.95, 4.12, {"lift": 0.035}], [-1, 4.11, 4.28, {"lift": 0.03}]], {"from": 3.62, "to": 4.28, "bob": 0.018})
	k.at(4.3, M([push(0.0), F("determined")]), "follow")
	k.at(4.75, M([push(1.1), HD(-0.16, 0.0, 0.05)]), "snap")
	k.at(5.0, push(0.2), "heavy")
	# Elle tire, au cas où : le corps part en arrière, rien.
	k.at(5.3, M([H(0.0, -0.06, 0.06), B(-0.04), C(0.0), HD(-0.05, 0.0, 0.0), L(0.14, -0.4, 0.72, 0.25), R(0.14, -0.4, 0.72, 0.25), CU(0.95)]), "snap")
	k.at(5.5, M([H(0.0, -0.04, 0.03), B(0.04)]), "follow")
	k.at(5.72, M([H(0.0, -0.07, 0.08), B(-0.07), HD(0.02, 0.0, -0.04), {"jaw": 0.2}]), "snap")
	k.at(6.0, M([H(0.0, -0.02, 0.0), B(0.03), {"jaw": 0.0}, F("sad")]), "heavy", "s")
	# Les mains retombent. Elle lève les yeux vers l'horloge au-dessus de la porte.
	k.at(6.25, M([shy(), HD(0.1, 0.0, 0.0), F("neutral")]), "follow")
	k.at(6.55, M([HD(0.48, 0.04, 0.02), C(0.0), B(0.0), shrug(0.3), F("surprise")]), "lead")
	k.at(6.8, HD(0.5, 0.02, -0.03), "heavy", "s")
	k.hold(6.8, 7.6, 0.35)
	# Elle s'approche de la vitre et met ses mains en visière pour voir dehors.
	k.at(7.75, M([HD(0.05, 0.0, 0.0), shy(), F("focus")]), "follow")
	k.steps([[-1, 7.87, 8.07, {"lift": 0.04}], [1, 8.06, 8.29, {"lift": 0.04}]], {"from": 7.85, "to": 8.3, "bob": 0.02})
	k.at(8.35, M([H(0.0, -0.02, 0.04), B(0.16), C(0.06), HD(0.36, 0.0, 0.0), L(0.45, 0.05, 0.5, 0.4), R(0.45, 0.05, 0.5, 0.4), WL(-0.75, 0.0, 0.25), WR(-0.75, 0.0, -0.25), CU(0.15), shrug(0.3)]), "follow")
	k.at(8.7, M([B(0.19), HD(0.4, 0.0, 0.0)]), "heavy", "s")
	# Elle cherche dehors : à gauche, à droite, plus près.
	k.at(9.3, M([HD(0.38, -0.08, -0.02), C(0.06, -0.03, 0.0)]), "heavy")
	k.at(9.55, HD(0.37, -0.1, -0.02), "heavy", "s")
	k.at(10.1, M([HD(0.36, 0.24, 0.04), C(0.06, 0.07, 0.0)]), "heavy")
	k.at(10.4, HD(0.35, 0.27, 0.03), "heavy", "s")
	k.at(10.85, M([HD(0.42, 0.0, 0.0), C(0.08, 0.0, 0.0), B(0.21)]), "follow", "s")
	# 10,9 : un néon claque au fond du hall. Elle se fige ; les mains quittent la vitre.
	k.at(11.0, M([{"shake": 0.35}, shrug(0.55), HD(0.0, 0.05, 0.0), F("surprise")]), "snap")
	k.at(11.35, M([B(0.08), C(0.04), HD(0.0, -0.25, 0.0), L(0.05, -0.12, 0.22, 0.0), R(0.05, -0.12, 0.22, 0.0), WL(0.3), WR(0.3), CU(0.9), F("fear")]), "heavy", "s")
	# Elle se retourne : la tête d'abord, par-dessus l'épaule droite, puis le corps, en quatre pas.
	k.at(11.75, M([HD(0.02, -0.95, 0.02), C(0.04, -0.3, 0.0), {"shake": 0.2}]), "lead")
	k.at(11.95, HD(0.02, -1.0, 0.0), "heavy", "s")
	k.steps([[1, 12.0, 12.32, {"lift": 0.04}], [-1, 12.3, 12.7, {"lift": 0.05}], [1, 12.7, 13.1, {"lift": 0.04}], [-1, 13.12, 13.5, {"lift": 0.03}]], {"from": 11.95, "to": 13.55, "bob": 0.02})
	k.at(12.5, M([HD(0.0, -0.45, 0.0), C(0.04, -0.15, 0.0)]), "follow")
	k.at(13.55, M([shy(), HD(-0.02, 0.0, 0.0), C(0.02), B(0.0), {"shake": 0.15}, F("fear")]), "follow", "s")
	# Elle plisse les yeux vers le fond du hall, le cou tendu.
	k.at(14.0, M([HD(-0.05, 0.05, 0.0), C(0.08), B(0.06), F("focus")]), "lead")
	k.at(14.4, HD(-0.04, 0.03, 0.03), "heavy", "s")
	# 14,5 : elle la voit. Les mains plaquées sur la bouche, les épaules aux oreilles.
	k.at(15.0, M([{"shake": 0.5}, HD(0.08, 0.0, 0.0), C(-0.04), B(-0.04), F("fear")]), "snap")
	k.at(15.35, M([Lt(-0.06, 0.32, 0.34, 0.5), Rt(-0.06, 0.32, 0.34, 0.5), WL(-0.4, 0.0, 0.3), WR(-0.4, 0.0, -0.3), CU(0.3), shrug(0.7), {"chatter": 0.5}]), "snap", "s")
	k.hold(15.35, 17.3, 0.2, "snap")
	# Gros plan : elle bégaie, un « non » de la tête, minuscule.
	k.at(17.55, M([HD(0.04, 0.12, 0.03), {"chatter": 0.8}, F("panic")]), "snap")
	k.at(17.8, HD(0.04, -0.1, -0.02), "snap")
	k.at(18.05, HD(0.05, 0.08, 0.02), "snap")
	k.at(18.3, HD(0.05, -0.05, 0.0), "snap")
	k.at(18.7, M([Lt(-0.05, 0.22, 0.32, 0.4), Rt(-0.05, 0.22, 0.32, 0.4), HD(0.02, 0.0, 0.0), {"chatter": 0.45}, F("fear")]), "heavy", "s")
	# Le dos collé à la porte : elle recule encore d'un rien.
	k.at(19.5, M([H(0.0, -0.02, -0.05), B(-0.08), C(-0.02), HD(0.0, 0.0, 0.0)]), "heavy", "s")
	k.hold(19.5, 22.4, 0.25, "snap")
	# 22,55 · 23,85 · 25,15 : chaque néon qui meurt la fait sursauter, les yeux se ferment.
	for hit: float in [22.55, 23.85, 25.15]:
		k.at(hit + 0.05, M([{"shake": 0.9, "sq": 0.97}, shrug(0.95), HD(-0.12, 0.08, 0.0), F("pain")]), "snap")
		k.at(hit + 0.4, M([{"shake": 0.45, "sq": 1.0}, shrug(0.75), HD(-0.02, 0.0, 0.0), F("panic")]), "heavy", "s")
	# 26,4 : elle se laisse glisser contre la porte, les bras sur la tête.
	k.at(26.5, M([{"shake": 0.4}, F("panic")]), "snap")
	k.at(27.3, M([H(0.0, -0.32, -0.12), B(-0.12), C(0.12), HD(-0.2, 0.0, 0.0), FL(0.0, 0.12, 0.0), FR(0.0, 0.14, 0.0), {"fp_l": 0.15, "fp_r": 0.15},
		Lt(0.0, 0.62, 0.22, 0.6), Rt(0.0, 0.62, 0.22, 0.6), WL(-0.5, 0.0, 0.4), WR(-0.5, 0.0, -0.4), CU(0.6)]), "heavy")
	k.at(28.0, M([H(0.0, -0.52, -0.16), B(-0.06), C(0.3), HD(-0.45, 0.0, 0.0), Lt(0.05, 0.7, 0.12, 0.7), Rt(0.05, 0.7, 0.12, 0.7), {"shake": 0.6, "chatter": 0.7}, F("pain")]), "heavy", "s")
	k.hold(28.0, LEAVE_LEN, 0.25, "snap")
	return k.clip()

# Alice : debout, immobile, la tête qui penche ; « au revoir » de la main, la main qui ne redescend plus.
static func _leave_alice(rig: Dictionary) -> Dictionary:
	var k: Take = Take.new(LEAVE_LEN, "neutral", 7, rig)
	var p: Array = ALICE_AT
	k.path([[0.0, p[0], 180.0, "s"], [22.6, p[0], 180.0, "s"], [22.61, p[1], 182.0, "s"], [23.9, p[1], 182.0, "s"], [23.91, p[2], 177.0, "s"],
		[25.2, p[2], 177.0, "s"], [25.21, p[3], 184.0, "s"], [LEAVE_LEN, p[3], 184.0, "s"]])
	var still: Dictionary = M([stand(0.0), H(0.0, -0.01, 0.0), B(0.0), C(-0.02), HD(-0.1, 0.0, 0.18), L(0.1, -0.97, 0.05, 0.0), R(0.1, -0.97, 0.05, 0.0), WL(0.0), WR(0.0), CU(0.3), F("neutral")])
	k.at(0.0, still, "sync", "s")
	k.at(14.3, still, "sync", "s")
	# Elle la regarde. La tête penche encore un peu, très lentement.
	k.at(17.2, M([HD(-0.12, 0.0, 0.3), CU(0.35)]), "heavy", "s")
	# 19,6 : au revoir. La main monte, paume vers Bleuette, les doigts qui se replient un à un.
	k.at(20.3, M([R(0.32, 0.12, 0.32, 0.55), WR(-0.1, 0.0, 0.15), CU(0.1, 0.35), HD(-0.12, 0.0, 0.34), F("smile")]), "heavy")
	k.at(20.55, M([R(0.33, 0.14, 0.32, 0.55), WR(-0.1, 0.0, 0.0)]), "heavy", "s")
	var waves: Array = [[20.85, 0.65], [21.15, 0.15], [21.5, 0.75], [21.85, 0.1], [22.3, 0.6]]
	for w: Array in waves: k.at(float(w[0]), M([CU(float(w[1]), 0.35), WR(-0.1 - 0.2 * float(w[1]), 0.0, 0.0)]), "sync")
	k.at(22.5, M([CU(0.15, 0.35), WR(-0.1, 0.0, 0.0), F("grin")]), "heavy", "s")
	# Plus près à chaque lampe qui s'éteint : la main toujours levée, la tête de plus en plus penchée.
	k.at(22.61, M([R(0.33, 0.14, 0.32, 0.55), HD(-0.14, 0.0, 0.42), CU(0.55, 0.4), F("grin")]), "sync", "s")
	k.at(23.91, M([R(0.33, 0.16, 0.34, 0.55), HD(-0.18, 0.04, 0.5), CU(0.1, 0.45), F("menace")]), "sync", "s")
	k.at(25.21, M([R(0.3, 0.22, 0.42, 0.5), WR(-0.2, 0.0, 0.1), HD(-0.2, 0.06, 0.38), B(0.06), C(0.08), CU(0.15, 0.5), F("grin")]), "sync", "s")
	# Devant elle : elle se penche sur elle à mesure qu'elle glisse, la main qui fait encore au revoir,
	# tout près de son visage, très lentement.
	k.at(26.6, M([B(0.16), C(0.14), HD(-0.3, 0.0, 0.28), R(0.24, -0.12, 0.55, 0.45), H(0.0, -0.03, 0.0)]), "heavy")
	k.at(27.2, M([CU(0.7, 0.5), WR(-0.35, 0.0, 0.0)]), "heavy")
	k.at(27.9, M([B(0.3), C(0.24), H(0.0, -0.09, -0.04), HD(-0.12, 0.0, 0.3), R(0.16, -0.42, 0.62, 0.4), CU(0.12, 0.5), WR(-0.1, 0.0, 0.0)]), "heavy")
	k.at(28.6, M([CU(0.75, 0.55), WR(-0.4, 0.0, 0.0), F("menace")]), "heavy")
	k.at(29.3, M([CU(0.1, 0.55), WR(-0.1, 0.0, 0.0), HD(-0.1, 0.0, 0.38), F("grin")]), "heavy")
	k.at(30.1, M([CU(0.7, 0.55), WR(-0.35, 0.0, 0.0)]), "heavy", "s")
	k.hold(30.1, LEAVE_LEN, 0.1)
	return k.clip()
