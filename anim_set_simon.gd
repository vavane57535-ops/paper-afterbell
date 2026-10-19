extends "res://anim_pose.gd"





static func add(c: Dictionary) -> void :
	_carriage(c)
	_flash(c)
	_dash(c)
	_personality(c)


static func _loose() -> Dictionary:
	return M([LR(0.32, -0.9, 0.06, 0.1), WL(0), WR(0)])


static func _hip_l() -> Dictionary:
	return M([Lt(0.08, -0.68, 0.06, 0.75), WL(0), {"curl_l": 0.8}])







static func _stance_keys() -> Array:
	var beat: float = 0.45
	var lean: Array = [0.03, 0.02, -0.02, -0.03, -0.04, -0.02, 0.03, 0.04]
	var keys: Array = [[0.0, M([B(0.05), {"curl": 0.15, "curl_l": 0.15}])]]
	for i in range(8):
		var t: float = beat * i

		keys.append([t, M([H(lean[i], -0.04, 0.0), {"fp_l": 0.0, "fp_r": 0.0}])])
		keys.append([t + 0.21, M([H(lean[i], 0.04, 0.0), {"fp_l": -0.32, "fp_r": -0.32}])])
		if i == 2 or i == 3: continue

		keys.append_array([[t + 0.07, R(0.36, -0.95, 0.03, 0.1)], [t + 0.28, R(0.32, -0.85, 0.1, 0.1)]])
		keys.append_array([[t + 0.1, L(0.36, -0.95, 0.03, 0.1)], [t + 0.31, L(0.32, -0.85, 0.1, 0.1)]])

	var start: float = beat * 2.0
	keys.append([start - 0.1, M([WL(0), WR(0), {"curl": 0.15, "curl_l": 0.15}])])
	for k in range(10):
		var t: float = start + 0.08 + 0.08 * k
		var a: float = 1.0 if k % 2 == 0 else -1.0
		var fade: float = 1.0 if k < 8 else 0.5
		keys.append([t, M([R(0.46 + 0.05 * a, -0.62 + 0.08 * a, 0.3, 0.25), WR(-0.2 - 0.85 * a * fade, 0.0, 0.35 * a * fade), {"curl": 0.0}])])
		keys.append([t + 0.03, M([L(0.46 - 0.05 * a, -0.62 - 0.08 * a, 0.3, 0.25), WL(-0.2 + 0.85 * a * fade, 0.0, 0.35 * a * fade), {"curl_l": 0.0}])])
	keys.append([start + 0.98, M([WL(0), WR(0), {"curl": 0.15, "curl_l": 0.15}])])

	keys.append_array([[0.0, M([C(-0.04, 0.0), HD(0.03, 0.0)])], [start, M([C(-0.04, 0.0), HD(0.03, 0.0)])], [start + 0.3, M([HD(-0.16, 0.0)]), "s"], [start + 0.75, M([HD(-0.12, 0.0)])], 
		[beat * 5.0, M([C(-0.04, 0.0), HD(0.03, 0.0)])], [beat * 5.0 + 0.2, M([C(-0.04, 0.3), HD(0.05, 0.55)]), "s"], [beat * 6.0 + 0.1, M([C(-0.04, 0.3), HD(0.05, 0.55)]), "s"], 
		[beat * 6.0 + 0.32, M([C(-0.04, -0.3), HD(0.05, -0.55)]), "s"], [beat * 7.0 + 0.2, M([C(-0.04, -0.3), HD(0.05, -0.55)]), "s"], [beat * 7.0 + 0.42, M([C(-0.04, 0.0), HD(0.03, 0.0)])]])
	keys.sort_custom( func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	return keys

# Allure de la course éclair (lue par character_visual.gd, fondue avec l'allure normale de Simon) :
# cadence très vive, épaules qui ne contre-tournent presque plus, peu de rebond. Les jambes suivent leurs
# propres courbes (SONIC_THIGH / SONIC_KNEE, voir sonic_curves) : knee_lift et heel_kick valent 1 ici et
# servent aux portages (carry_rig.gd, clé « gait ») pour raccourcir la foulée.
const SONIC_GAIT: Dictionary = {"cadence": 1.42, "lean": 1.56, "knee_lift": 1.0, "heel_kick": 1.0, "twist": 0.3,
	"bob": 0.8, "sway": 0.5, "press": 0.7, "hop": 0.2, "cross": 0.0, "arm_swing": 0.35}

# Oscillation d'une jambe en course éclair (mêmes nœuds et conventions que anim_gait.gd, en degrés) :
# poussée longue (cuisse loin derrière, genou presque tendu au décollage), talon qui remonte sous les fesses,
# genou qui monte devant sans dépasser l'horizontale, tibia lancé loin devant avant de griffer le sol.
const SONIC_THIGH: PackedFloat32Array = [-38.0, -27.0, 6.0, 44.0, 64.0, 52.0, 30.0]
const SONIC_KNEE: PackedFloat32Array = [16.0, 94.0, 134.0, 114.0, 62.0, 26.0, 14.0]
const SONIC_ANKLE: PackedFloat32Array = [0.1, -0.3, -0.32, -0.05, 0.14, 0.05, -0.2]
# Bassin plus haut (le pied se pose presque sous la hanche, peu d'écrasement) : jambe d'appui moins pliée.
const SONIC_PARAMS: Dictionary = {1: 0.2, 4: 0.02, 22: 0.012}


# Remplace (poids w) les courbes de foulée mélangées par celles de la course éclair ; lift / kick : montée du
# genou et repli du talon (allure du moment, 1 = course éclair seule).
static func sonic_curves(w: float, par: PackedFloat32Array, thigh: PackedFloat32Array, knee: PackedFloat32Array, ankle: PackedFloat32Array, lift: float, kick: float) -> void :
	if w <= 0.0001: return
	var last: int = SONIC_THIGH.size() - 1
	for i in range(SONIC_THIGH.size()):
		var th: float = deg_to_rad(SONIC_THIGH[i])
		var kn: float = deg_to_rad(SONIC_KNEE[i])
		if i > 0 and i < last:
			if th > 0.0: th *= lift
			var edge: float = lerpf(deg_to_rad(SONIC_KNEE[0]), deg_to_rad(SONIC_KNEE[last]), float(i) / float(last))
			kn = edge + (kn - edge) * kick
		thigh[i] = lerpf(thigh[i], th, w)
		knee[i] = lerpf(knee[i], kn, w)
		ankle[i] = lerpf(ankle[i], SONIC_ANKLE[i], w)
	for index: int in SONIC_PARAMS:
		par[index] = lerpf(par[index], float(SONIC_PARAMS[index]), w)


# Bras tendus vers l'arrière et un peu écartés, dans le repère du sol : ils traînent dans le vent à ~22° sous
# l'horizontale, bien décollés du dos, mains derrière les fesses. side = -1 gauche, 1 droite ;
# drop = les bras encaissent l'appui (ils plongent un peu), drop < 0 = ils remontent en suspension.
static func _sonic_arm(side: float, drop: float, spread: float) -> Dictionary:
	var out: float = 0.52 + spread
	var up: float = -0.46 - 0.12 * drop
	var fwd: float = -0.72 + 0.06 * drop
	var arm: Dictionary = L(out, up, fwd, 0.0) if side < 0.0 else R(out, up, fwd, 0.0)
	return M([arm, WL(0.25 + 0.3 * drop, 0.35, 0.0) if side < 0.0 else WR(0.25 + 0.3 * drop, -0.35, 0.0)])


# Une foulée complète (deux appuis). Le bassin bascule, le dos s'arrondit à peine (la poitrine continue
# l'inclinaison), la tête se relève franchement pour regarder loin devant. Après chaque pose de pied, les bras
# plongent un peu et le buste « tape » ; en suspension ils remontent. Les deux appuis diffèrent (Simon tire un
# peu à droite).
const SONIC_BODY: float = 0.45
const SONIC_CHEST: float = -0.1
const SONIC_HEAD: float = 0.64

static func _sonic_keys() -> Array:
	var keys: Array = []
	var strikes: Array = [[0.0, -1.0, 1.0], [0.5, 1.0, 0.82]]
	for strike: Array in strikes:
		var t: float = strike[0]
		var lead: float = strike[1]
		var force: float = strike[2]
		keys.append([t, M([B(SONIC_BODY, 0.0, 0.02 * lead), C(SONIC_CHEST, 0.03 * lead, 0.0), HD(SONIC_HEAD, -0.03 * lead, 0.0), _sonic_arm(-1.0, 0.0, 0.02), _sonic_arm(1.0, 0.0, 0.02)])])
		keys.append([t + 0.07, M([B(SONIC_BODY + 0.03 * force, 0.0, 0.03 * lead), C(SONIC_CHEST + 0.02, 0.03 * lead, 0.0), HD(SONIC_HEAD - 0.04, -0.02 * lead, 0.0), _sonic_arm(-1.0, force, 0.03 + 0.02 * lead), _sonic_arm(1.0, force, 0.03 - 0.02 * lead)])])
		keys.append([t + 0.27, M([B(SONIC_BODY - 0.02, 0.0, 0.0), C(SONIC_CHEST - 0.01, -0.02 * lead, 0.0), HD(SONIC_HEAD + 0.02, 0.03 * lead, 0.0), _sonic_arm(-1.0, -0.4, 0.0), _sonic_arm(1.0, -0.4, 0.0)])])
	keys[0][1].merge({"curl": 0.18, "curl_l": 0.18}, true)
	return keys


static func _carriage(c: Dictionary) -> void :
	c["stance@Simon"] = {"len": 3.6, "loop": true, "add": true, "keys": _stance_keys()}


	c["alert@Simon"] = {"len": 1.6, "loop": true, "add": true, "keys": [
		[0.0, M([FL(0.07, 0.26), FR(0.14, -0.4), H(0, -0.27, 0.06), B(0.42, -0.15), C(0.1, 0.25), HD(0.36, 0.5), Lt(0.1, -0.3, 0.7, 0.3), Rt(0.26, -0.52, 0.38, 0.4), WL(0.5), WR(0.5), {"fp_r": -0.6, "fp_l": 0.0, "curl": 0.0}]), "s"], 
		[0.2, H(0, -0.32, 0.06)], 
		[0.4, M([H(0, -0.27, 0.06), Lt(0.12, -0.26, 0.68, 0.3), Rt(0.24, -0.55, 0.42, 0.4)])], 
		[0.55, M([C(0.1, 0.25), HD(0.36, 0.5)]), "s"], 
		[0.6, H(0, -0.32, 0.06)], 
		[0.75, M([C(0.1, -0.3), HD(0.34, -0.6)]), "s"], 
		[0.8, M([H(0, -0.27, 0.06), Lt(0.1, -0.3, 0.7, 0.3), Rt(0.26, -0.52, 0.38, 0.4)])], 
		[1.0, H(0, -0.32, 0.06)], 
		[1.2, M([H(0, -0.27, 0.06), Lt(0.12, -0.26, 0.68, 0.3), Rt(0.24, -0.55, 0.42, 0.4)])], 
		[1.35, M([C(0.1, -0.3), HD(0.34, -0.6)]), "s"], 
		[1.4, H(0, -0.32, 0.06)], 
	]}


	# Course : la foulée et les bras viennent de la locomotion procédurale (rapide et léger, genoux hauts) ;
	# ces clips n'ajoutent que l'attitude (menton, épaules) et les poings.
	c["run@Simon"] = {"len": 1.0, "loop": true, "add": true, "keys": [
		[0.0, M([HD(0.04, -0.04, 0.0), {"curl": 0.75}])],
		[0.5, M([HD(0.04, 0.04, 0.0)])],
	]}


	c["sprint@Simon"] = {"len": 1.0, "loop": true, "add": true, "keys": [
		[0.0, M([C(0.04, 0.0, 0.0), HD(0.06, -0.03, 0.0), {"curl": 0.9}])],
		[0.5, M([C(0.04, 0.0, 0.0), HD(0.06, 0.03, 0.0)])],
	]}


	# Course éclair (0.17) : position « Sonic ». Buste plongé (~50° avec l'allure SONIC_GAIT), tête relevée qui
	# regarde loin devant, bras tendus en arrière le long du corps, mains ouvertes. Le clip suit la phase de foulée
	# (0 = pose du pied gauche, 0,5 = pose du pied droit) : les bras encaissent chaque appui puis flottent.
	c["boost@Simon"] = {"len": 1.0, "loop": true, "add": true, "face": "grin", "keys": _sonic_keys()}





static func _aim(sway: float = 0.0) -> Dictionary:
	return M([FL(0.03, 0.4), FR(0.16, -0.26), H(0.12 - 0.03 * sway, -0.2 - 0.02 * sway, -0.26 + 0.08 * sway), B(-0.16, -0.72 + 0.06 * sway, -0.16), C(0.0, -0.35, -0.05), HD(0.04, 0.98, 0.1), 
		R(0.56, 0.42 + 0.04 * sway, -0.2 - 0.05 * sway, 0.8), WR(0.3), L(-0.2, 0.15 - 0.05 * sway, 0.93, 0.1), WL(0.0), {"fp_l": 0.3, "fp_r": 0.0, "curl": 1.0, "curl_l": 0.0}])

static func _flash(c: Dictionary) -> void :


	c["flash_aim"] = {"len": 1.82, "loop": true, "loop_from": 0.42, "in": 0.05, "face": "focus", "keys": [
		[0.0, M([FLR(0, 0), H(0, -0.08, 0), B(0.16, -0.1), C(0.12), HD(-0.35, 0.05), Rt(-0.18, -0.28, 0.5, 0.5), WR(0), Lt(-0.2, -0.24, 0.56, 0.5), WL(0), {"fp_l": 0.0, "fp_r": 0.0, "curl": 1.0, "curl_l": 0.9, "prop": "flash"}])], 
		[0.14, M([FLR(0, 0), H(0, -0.1, 0), B(0.16, -0.12), C(0.12), HD(-0.35, 0.05), Rt(-0.18, -0.28, 0.5, 0.5), Lt(-0.2, -0.24, 0.56, 0.5), {"curl_l": 0.9}])], 
		[0.21, M([H(0.05, -0.12, -0.08), B(0.0, -0.4), C(0.0, -0.2), HD(0.0, 0.5), Rt(-0.02, -0.12, 0.42, 0.6), L(0.8, -0.05, 0.35, 0.3), {"curl_l": 0.7, "fx": "flash_pin"}])], 
		[0.31, M([FL(0.03, 0.32, 0.08), FR(0.16, -0.2), H(0.1, -0.17, -0.2), B(-0.1, -0.62, -0.1), C(0.0, -0.3), HD(0.02, 0.88), R(0.42, 0.24, 0.02, 0.8), L(0.3, 0.2, 0.8, 0.2), {"curl_l": 0.0}])], 
		[0.42, _aim(0.0), "s"], 
		[0.5, {"fx": "fuse"}], 
		[0.88, _aim(1.0)], 
		[1.35, _aim(-0.7)], 
		[1.82, _aim(0.0)], 
	]}




	c["flash_throw"] = {"len": 0.95, "in": 0.03, "out": 0.2, "face": "determined", "keys": [
		[0.0, M([_aim(0.0), {"feet": V(0, 0, 0), "prop": "flash", "sq": 1.0}])], 
		[0.14, M([FL(0.0, 0.45, 0.7), FR(0.16, -0.26), H(0.16, -0.12, -0.38), B(-0.46, -1.05, -0.28), C(-0.1, -0.4, -0.06), HD(0.2, 1.2, 0.1), R(0.5, 0.6, -0.5, 0.9), WR(0.5), L(-0.2, 0.7, 0.68, 0.2), {"fp_l": 0.4, "fp_r": 0.0, "curl": 1.0, "sq": 0.94}]), "s"], 
		[0.2, M([FL(0.0, 0.52, 0.64), H(0.14, -0.14, -0.3), B(-0.4, -1.0, -0.24), C(-0.1, -0.45, -0.05), HD(0.18, 1.15, 0.08), R(0.5, 0.62, -0.52, 0.9), L(-0.2, 0.6, 0.75, 0.2), {"fp_l": 0.3}])], 
		[0.25, {"fx": "trail_r"}], 
		[0.28, M([FL(0.04, 0.72, 0.0), FR(0.16, -0.26), H(0.0, -0.3, 0.26), B(0.0, -0.1, 0.0), C(-0.12, -0.6, 0.0), HD(0.1, 0.7, 0.0), R(0.5, 0.6, -0.4, 1.0), Lt(0.3, -0.1, 0.4, 0.6), {"fp_l": 0.0, "fp_r": -0.5, "sq": 1.0, "fx": "dust"}])], 
		[0.32, M([H(0, -0.3, 0.44), B(0.32, 0.5), C(0.1, 0.25), HD(0.3, -0.6), R(0.2, 0.78, 0.15, 0.9), WR(0.5), Lt(0.3, -0.3, 0.2, 0.6), {"fp_r": -0.8, "curl": 1.0}])], 
		[0.34, {"prop": ""}], 
		[0.35, M([FR(0.14, -0.3, 0.12), H(0, -0.32, 0.54), B(0.62, 0.75), C(0.22, 0.4), HD(0.6, -1.0), R(-0.12, 0.42, 0.9, 0.3), WR(-0.6), Lt(0.3, -0.45, -0.1, 0.6), {"curl": 0.0, "sq": 1.08, "ev": "effort", "fx": "whoosh"}])], 
		[0.45, M([FR(0.3, -0.35, 0.5), H(0, -0.36, 0.6), B(0.95, 0.95), C(0.3, 0.5), HD(0.9, -1.0), R(-0.6, -0.7, 0.45, 0.2), WR(0), L(0.55, 0.1, -0.6, 0.5), {"sq": 1.0}]), "s"], 
		[0.57, M([FL(0.04, 0.72, 0.0), FR(0.3, -0.2, 0.42), H(0, -0.34, 0.57), B(0.9, 0.9), C(0.3, 0.5), HD(0.9, -1.0), R(-0.62, -0.74, 0.4, 0.2), L(0.55, 0.05, -0.55, 0.5), {"feet": V(0, 0, 0), "fp_l": 0.0, "fp_r": -0.8, "curl": 0.0}])], 
		[0.69, M([FL(0.05, 0.3, 0.06), FR(0.1, 0.08, 0.12), {"feet": V(0, 0.16, 0)}, H(0, 0.12, 0.22), B(0.25, 0.3), C(0.05, 0.1), HD(0.25, -0.3), L(0.7, 0.0, 0.1, 0.3), R(0.6, -0.1, 0.2, 0.3), {"fp_l": -0.4, "fp_r": -0.4, "curl": 0.2, "sq": 1.06}])], 
		[0.8, M([FL(0.02, 0.04, 0.0), FR(0.04, 0.0, 0.0), {"feet": V(0, 0, 0)}, H(0, -0.14, 0.03), B(0.12, 0.0), C(0, 0), HD(0.05, 0.0), LR(0.4, -0.75, 0.15, 0.1), {"fp_l": 0.0, "fp_r": 0.0, "sq": 0.93, "fx": "dust"}])], 
		[0.95, M([rest(), _loose()])], 
	]}


	c["flash_punch"] = {"len": 0.8, "in": 0.03, "out": 0.22, "face": "determined", "keys": [
		[0.0, M([FLR(0, 0), H(0, 0, 0), Rt(0.18, -0.38, -0.05, 0.5), Lt(-0.1, 0.1, 0.45, 0.6), C(0.0, -0.3), {"curl": 1.1, "curl_l": 0.2, "fp_r": 0.0, "sq": 1.0}])], 
		[0.05, M([FL(0.03, 0.14), FR(0.1, -0.12), H(0, -0.16, -0.1), B(0.04, -0.45), C(0.0, -0.5), HD(-0.05, 0.8), Rt(0.22, -0.3, -0.22, 0.5), Lt(-0.25, 0.4, 0.5, 0.9), {"sq": 0.93, "fx": "trail_r"}])], 
		[0.11, M([FL(0.02, 0.62), FR(0.12, -0.5), H(0, -0.26, 0.5), B(0.36, 0.34), C(0.1, 0.22), HD(0.34, -0.5, 0.06), R(-0.14, 0.05, 1.0, 0.0), Lt(-0.3, 0.62, 0.55, 0.9), {"fp_r": -0.7, "sq": 1.1, "ev": "grunt", "fx": "pop_r glint whoosh"}])], 
		[0.2, M([H(0, -0.3, 0.56), B(0.42, 0.4), C(0.12, 0.26), R(-0.18, 0.06, 1.0, 0.0), Lt(-0.32, 0.64, 0.55, 0.9), {"sq": 1.0}]), "s"], 
		[0.44, M([FL(0.02, 0.62), FR(0.12, -0.5), H(0, -0.28, 0.52), B(0.38, 0.36), C(0.1, 0.22), HD(0.34, -0.5, 0.06), R(-0.16, 0.04, 0.98, 0.0), Lt(-0.3, 0.62, 0.55, 0.9), {"fp_r": -0.7, "curl": 1.1}])], 
		[0.55, M([FL(0.02, 0.62), FR(0.12, -0.5), H(0, -0.24, 0.46), B(0.3, 0.3), C(0.08, 0.18), HD(0.42, -0.45, -0.1), R(-0.12, -0.05, 0.9, 0.1), Lt(-0.3, 0.32, 0.55, 0.8), {"fp_r": -0.7, "curl": 1.0, "face": "surprise"}]), "s"], 
		[0.67, M([FL(0.04, 0.26), FR(0.1, -0.2), H(0, -0.12, 0.14), B(0.12, 0.12), C(0.04, 0.08), HD(0.05, -0.2), Rt(0.1, -0.35, 0.35, 0.3), Lt(0.0, -0.1, 0.45, 0.5), {"fp_r": 0.0, "curl": 0.6, "face": "grin"}])], 
		[0.8, M([rest(), _loose(), {"curl": 0.3, "curl_l": 0.3}])], 
	]}



	c["mode_switch@Simon"] = {"len": 0.6, "in": 0.04, "out": 0.15, "face": "grin", "keys": [
		[0.0, M([H(0, 0, 0), R(0.2, -0.55, 0.4, 0.2), WR(0.0, -1.57), _hip_l(), HD(-0.1, -0.2), {"curl": 0.9, "prop": "flash", "sq": 1.0, "fp_l": 0.0, "fp_r": 0.0}])], 
		[0.07, M([H(0, -0.09, 0), R(0.22, -0.7, 0.36, 0.2), WR(0.0, -1.57), HD(-0.12, -0.2), {"curl": 0.9, "sq": 0.94}])], 
		[0.16, M([H(0, 0.05, 0), R(0.3, 0.9, 0.2, 0.2), WR(0.9, 0.0), HD(0.45, -0.25), {"curl": 0.0, "fp_l": -0.4, "fp_r": -0.4, "sq": 1.06}])], 
		[0.17, {"prop": ""}], 
		[0.24, M([H(0, 0.05, 0), R(0.3, 0.96, 0.18, 0.2), WR(1.1, 0.0), HD(0.6, -0.25), {"sq": 1.0}]), "s"], 
		[0.34, M([R(0.3, 0.93, 0.18, 0.2), WR(1.1, 0.0), HD(0.6, -0.25), {"curl": 0.0}])], 
		[0.37, {"prop": "flash", "fx": "glint"}], 
		[0.38, M([H(0, 0.02, 0), R(0.3, 0.82, 0.2, 0.2), WR(0.6, 0.0), {"curl": 1.0, "sq": 0.98}])], 
		[0.47, M([H(0, -0.06, 0), Rt(0.3, 0.05, 0.3, 0.7), WR(0, -1.57), HD(0.0, -0.2, 0.15), {"fp_l": 0.0, "fp_r": 0.0, "curl": 1.0, "sq": 1.0}]), "s"], 
		[0.6, M([rest(), _loose()])], 
	]}





# Position de départ en starting-blocks (charge du boost). « À vos marques » (rise 0) : genou arrière posé au sol
# sous la hanche, tibia à plat, pointe du pied en appui ; « prêts » (rise 1) : bassin levé, genou arrière à ~120°.
static func _blocks(rise: float, sway: float = 0.0) -> Dictionary:
	return M([FL(0.04, lerpf(0.16, 0.1, rise)), FR(0.1, lerpf(-0.5, -0.5, rise)), H(0.1 * sway, lerpf(-0.57, -0.24, rise), lerpf(-0.08, 0.1, rise)), B(lerpf(0.98, 1.5, rise), 0.0, 0.14 * sway), C(lerpf(0.2, 0.25, rise), 0.0, -0.1 * sway), HD(lerpf(0.8, 1.2, rise)), 
		Lg(0.14, lerpf(0.14, 0.05, rise), 0.18 * rise), Rg(0.14, lerpf(0.1, 0.05, rise), 0.18 * rise), {"fp_r": -0.9, "fp_l": -0.4 * rise, "curl": 0.1}])





static func _charge_keys() -> Array:
	var keys: Array = [
		[0.0, M([H(0, -0.12, 0), B(0.25), C(0.05), HD(0.1), LR(0.3, -0.75, 0.3, 0.2), {"fp_l": 0.0, "fp_r": 0.0, "curl": 0.1, "shake": 0.0, "sq": 1.0}])], 
		[0.2, M([_blocks(0.0), H(0, -0.61, -0.06), {"sq": 0.9, "fx": "dust"}])], 
		[0.35, M([_blocks(0.0), {"sq": 1.0, "shake": 0.1}]), "s"], 
	]
	var rise: Array = [0.0, 0.34, 0.68, 1.0]
	for level in range(3):
		var step: float = [0.2, 0.16, 0.13][level]
		var t: float = (0.35 if level == 0 else float(level) + 0.12) + step
		var side: float = 1.0
		while t < float(level) + 0.86:
			keys.append([t, M([_blocks(rise[level], side * (0.5 + 0.25 * level)), {"shake": 0.15 + 0.3 * level, "sq": 1.0}])])
			side = - side
			t += step

		keys.append([float(level) + 0.92, M([_blocks(rise[level] - 0.06), {"sq": 0.97}])])
		if level < 2:
			keys.append([float(level) + 1.0, M([_blocks(rise[level + 1] + 0.06), {"shake": 0.4 + 0.3 * level, "sq": 1.05, "fx": "flex dust"}])])
			keys.append([float(level) + 1.12, M([_blocks(rise[level + 1]), {"sq": 1.0}]), "s"])
	keys.append([3.0, M([_blocks(1.0), {"shake": 1.0, "sq": 1.04, "fx": "dust_ring flex"}]), "s"])
	for k in range(5):
		keys.append([3.1 + 0.1 * k, M([_blocks(1.0 + (0.05 if k % 2 == 0 else 0.0), 1.0 if k % 2 == 0 else -1.0), {"sq": 1.02 if k % 2 == 0 else 0.99, "fx": "dust" if k == 2 else ""}])])
	keys.append([3.6, M([_blocks(1.0), {"shake": 1.0, "sq": 1.04}])])
	return keys

static func _dash(c: Dictionary) -> void :
	c["charge@Simon"] = {"len": 3.6, "loop": true, "loop_from": 3.0, "in": 0.05, "face": "determined", "keys": _charge_keys()}

	# Arrêt net en pleine course éclair (joué par character_visual.gd quand la vitesse tombe d'un coup) :
	# talon droit planté devant, pied gauche qui racle derrière, bassin qui recule ; le buste, lui, continue
	# sur sa lancée et plonge (tête et bras en retard), puis tout se redresse avec un petit rebond.
	c["skid@Simon"] = {"len": 0.66, "in": 0.03, "out": 0.2, "face": "surprise", "keys": [
		[0.0, M([{"gait": 0.0, "plant": 1.0}, FR(0.13, 0.5, 0.0), FL(0.11, -0.36, 0.04), H(0.0, -0.3, -0.2), B(0.42, 0.05, 0.0), C(0.08), HD(0.5, 0.0, 0.0),
			L(0.3, -0.45, -0.8, 0.0), R(0.3, -0.42, -0.82, 0.0), WL(0.3), WR(0.3), {"fp_r": 0.6, "fp_l": -0.7, "curl": 0.2, "curl_l": 0.2, "sq": 0.95, "fx": "skid dust"}])],
		[0.09, M([FR(0.13, 0.46, 0.0), FL(0.11, -0.3, 0.02), H(0.0, -0.36, -0.24), B(0.12, 0.05, 0.03), C(0.42, 0.0, 0.0), HD(-0.05, 0.1, 0.05),
			L(0.82, 0.25, 0.3, 0.6), R(0.78, 0.4, 0.2, 0.6), WL(-0.45), WR(-0.45), {"fp_r": 0.5, "fp_l": -0.55, "curl": 0.0, "curl_l": 0.0, "sq": 0.9, "fx": "dust"}]), "s"],
		[0.2, M([FR(0.13, 0.38, 0.0), FL(0.11, -0.22, 0.0), H(0.0, -0.26, -0.12), B(0.0, 0.0, 0.02), C(0.2, -0.05, 0.0), HD(0.2, 0.05, 0.0),
			L(0.8, 0.0, 0.25, 0.5), R(0.72, -0.2, 0.3, 0.4), WL(-0.2), WR(-0.1), {"fp_r": 0.25, "fp_l": -0.3, "sq": 1.03}])],
		[0.33, M([FR(0.12, 0.24, 0.0), FL(0.1, -0.12, 0.0), H(0.0, -0.1, -0.02), B(-0.08, 0.0, 0.0), C(-0.04, 0.0, 0.0), HD(0.08, 0.0, -0.06),
			L(0.45, -0.55, 0.2, 0.3), R(0.42, -0.6, 0.18, 0.3), WL(0.0), WR(0.0), {"fp_r": 0.0, "fp_l": 0.0, "curl": 0.5, "curl_l": 0.4, "sq": 0.97, "face": "grin"}]), "s"],
		[0.46, M([FR(0.12, 0.2, 0.0), FL(0.1, -0.1, 0.0), H(0.0, -0.14, 0.0), B(0.04, 0.0, 0.0), C(0.03, 0.0, 0.0), HD(0.0, -0.08, 0.04), LR(0.36, -0.8, 0.12, 0.15), {"sq": 1.0}])],
		[0.66, M([rest(), _loose()])],
	]}


	c["carry"] = {"len": 0.56, "loop": true, "in": 0.1, "face": "determined", "keys": [
		[0.0, M([H(0, -0.1, 0.0), B(0.62, 0.0, 0.03), C(0.14), HD(0.62), Lt(0.28, -0.7, -0.3, 0.3), Rt(0.28, -0.7, -0.3, 0.3), WL(-0.6), WR(-0.6), {"curl": 0.7}])], 
		[0.28, M([H(0, -0.15, 0.0), B(0.68, 0.0, -0.03), C(0.16), HD(0.58), Lt(0.3, -0.66, -0.32, 0.3), Rt(0.26, -0.73, -0.3, 0.3)])], 
	]}



	c["dodge"] = {"len": 0.45, "in": 0.02, "out": 0.14, "face": "surprise", "keys": [
		[0.0, M([FLR(0, 0), H(0, 0, 0), B(0), C(0), HD(0), LR(0.3, -0.8, 0.1), WL(0), WR(0), {"curl": 0.0, "sq": 1.0, "fp_l": 0.0, "fp_r": 0.0}])], 
		[0.02, {"fx": "afterimage"}], 
		[0.07, M([FR(0.34, 0.0, 0.05), FL(-0.05, 0.05, 0.25), H(0.34, -0.06, -0.04), B(-0.05, 0.1, 0.3), C(0, 0.05, 0.15), HD(0.0, 0.25, -0.1), L(0.6, 0.3, 0.2, 0.5), R(0.55, 0.2, 0.1, 0.5), {"fp_l": -0.5, "sq": 0.96}])], 
		[0.14, M([FR(0.46, 0.02, 0.0), FL(-0.22, 0.12, 0.5), H(0.5, -0.06, -0.06), B(-0.14, 0.22, 0.5), C(-0.05, 0.1, 0.34), HD(-0.12, 0.4, -0.5), L(0.85, 0.6, 0.15, 0.5), R(0.2, 1.0, -0.05, 0.3), WL(0.6), WR(0.5), {"fp_l": -0.8, "fp_r": -0.4, "sq": 1.06, "fx": "sweat"}]), "s"], 
		[0.26, M([FR(0.46, 0.02, 0.0), FL(-0.2, 0.1, 0.44), H(0.46, -0.08, -0.05), B(-0.1, 0.2, 0.42), C(-0.04, 0.1, 0.28), HD(-0.1, 0.4, -0.45), L(0.9, 0.45, 0.15, 0.5), R(0.26, 0.96, -0.05, 0.3), WL(0.6), WR(0.5), {"fp_l": -0.8, "fp_r": -0.4, "sq": 1.0, "face": "grin"}])], 
		[0.36, M([FR(0.1, 0.0, 0.05), FL(0.02, 0.0, 0.04), H(0.06, 0.03, 0), B(0.02, 0.0, -0.1), C(0, 0, -0.06), HD(0, 0.1, 0.1), L(0.5, -0.4, 0.2, 0.3), R(0.5, -0.3, 0.2, 0.3), WL(0), WR(0), {"fp_l": 0.0, "fp_r": 0.0}])], 
		[0.45, M([rest(), _loose()])], 
	]}




static func _wave(side: float, drag: float = 0.0) -> Dictionary:
	var left: float = 0.35 + 0.7 * side
	var right: float = 0.35 - 0.7 * side
	return M([H(-0.08 * side, 0.09 - 0.03 * absf(side), 0), B(-0.08, 0, 0.2 * side), C(-0.1, 0, 0.14 * side), HD(0.12, 0, -0.2 * side), 
		L(0.98 * sin(left), 0.98 * cos(left), 0.05, 0.3), R(0.98 * sin(right), 0.98 * cos(right), 0.05, 0.3), WL(0.3, 0, 0.45 * drag), WR(0.3, 0, 0.45 * drag)])

static func _personality(c: Dictionary) -> void :


	c["fidget@Simon"] = {"len": 3.3, "in": 0.2, "out": 0.35, "keys": [
		[0.0, M([FLR(0, 0), H(0, 0, 0), B(0), C(0), HD(0), _loose(), {"curl": 0.15, "fp_l": 0.0, "fp_r": 0.0}])], 
		[0.3, M([FL(0.04, 0.55), FR(0.08, -0.08), H(0, -0.28, -0.36), B(0.95), C(0.3), HD(0.6), L(0.05, -0.7, 0.7), R(-0.4, -0.7, 0.7), {"fp_l": 0.6, "curl": 0.0}]), "s"], 
		[0.52, M([H(0, -0.24, -0.32), B(0.82), C(0.24), HD(0.5)])], 
		[0.74, M([FL(0.04, 0.55), FR(0.08, -0.08), H(0, -0.32, -0.38), B(1.05), C(0.36), HD(0.4), L(0.05, -0.74, 0.74), R(-0.4, -0.74, 0.74), {"fp_l": 0.6, "fp_r": 0.0}]), "s"], 
		[1.05, M([FL(0, 0), FR(0, 0), H(0, 0.02, 0), B(0.05), C(0), HD(0.05), LRt(0.2, -0.6, 0.2, 0.2), {"fp_l": 0.0, "fp_r": 0.0, "curl": 0.15}])], 
		[1.22, M([FL(0.0, 0.14, 0.5), H(0, 0.06, 0), B(0.08, 0.14), Rt(-0.05, -0.05, 0.62), Lt(0.15, -0.62, -0.25, -0.8), {"fp_l": -0.7}])], 
		[1.38, M([FL(0, 0, 0), FR(0, 0, 0), H(0, -0.04, 0), {"fp_l": 0.0, "fp_r": 0.0, "fx": "dust"}])], 
		[1.54, M([FR(0.0, 0.14, 0.5), H(0, 0.06, 0), B(0.08, -0.14), Lt(-0.05, -0.05, 0.62), Rt(0.15, -0.62, -0.25, -0.8), {"fp_r": -0.7}])], 
		[1.7, M([FL(0, 0, 0), FR(0, 0, 0), H(0, -0.04, 0), {"fp_r": 0.0, "fp_l": 0.0, "fx": "dust"}])], 
		[1.86, M([FL(0.0, 0.14, 0.5), H(0, 0.06, 0), B(0.08, 0.14), Rt(-0.05, -0.05, 0.62), Lt(0.15, -0.62, -0.25, -0.8), {"fp_l": -0.7}])], 
		[2.02, M([FL(0, 0, 0), H(0, -0.05, 0), B(0.05, 0), C(0, 0, 0), HD(0.05, 0), {"fp_l": 0.0, "fx": "dust"}])], 
		[2.25, M([H(-0.05, -0.03, 0), B(0.06, -0.35), C(0.05, -0.2, -0.12), HD(-0.4, -0.55), Rt(0.34, -0.48, -0.08, 0.6), Lt(0.3, -0.85, 0.12), {"curl": 0.3}])], 
		[2.36, Rt(0.14, -0.74, -0.1, 0.5), "s"], 
		[2.5, Rt(0.34, -0.5, -0.06, 0.6)], 
		[2.62, Rt(0.14, -0.74, -0.1, 0.5), "s"], 
		[2.85, M([H(-0.05, -0.03, 0), B(0.06, -0.35), C(0.05, -0.2, -0.12), HD(-0.38, -0.55), Rt(0.16, -0.72, -0.1, 0.5)])], 
		[3.3, M([rest(), _loose()])], 
	]}


	c["wave@Simon"] = {"len": 2.3, "in": 0.1, "out": 0.25, "face": "grin", "keys": [
		[0.0, M([H(0, -0.14, 0), B(0.12), C(0), HD(-0.05), LR(0.35, -0.75, -0.15, 0.2), WL(0), WR(0), {"feet": V(0, 0, 0), "curl": 0.0, "sq": 0.93, "fp_l": 0.0, "fp_r": 0.0, "jaw": 0.0}])], 
		[0.2, M([_wave(1.0), {"feet": V(0, 0.07, 0), "fp_l": -0.7, "fp_r": -0.7, "sq": 1.06, "jaw": 0.5}])], 
		[0.35, _wave(0.0, 1.0)], 
		[0.5, M([_wave(-1.0), {"sq": 1.03}])], 
		[0.65, _wave(0.0, -1.0)], 
		[0.8, _wave(1.0)], 
		[0.95, _wave(0.0, 1.0)], 
		[1.1, _wave(-1.0)], 
		[1.25, _wave(0.0, -1.0)], 
		[1.4, M([_wave(1.0), {"jaw": 0.5}])], 
		[1.55, _wave(0.3, 1.0)], 
		[1.72, M([H(0, 0.09, 0), B(-0.1, 0, 0), C(-0.1, 0, 0), HD(0.15, 0, 0), L(0.62, 0.76, 0.05, 0.3), R(0.62, 0.76, 0.05, 0.3), WL(0.3), WR(0.3), {"feet": V(0, 0.07, 0), "fp_l": -0.7, "fp_r": -0.7, "sq": 1.04, "jaw": 0.2}]), "s"], 
		[1.96, M([H(0, -0.08, 0), B(0.05), C(0), HD(0), LR(0.5, -0.5, 0.1, 0.2), WL(0), WR(0), {"feet": V(0, 0, 0), "fp_l": 0.0, "fp_r": 0.0, "sq": 0.96, "jaw": 0.0}])], 
		[2.3, M([rest(), _loose()])], 
	]}


	c["cheer@Simon"] = {"len": 2.4, "in": 0.06, "out": 0.0, "face": "grin", "keys": [
		[0.0, M([H(0, -0.05, 0), B(0.05), C(0), HD(0), LR(0.34, -0.85, 0.0, 0.1), WL(0), WR(0), {"feet": V(0, 0, 0)}, FLR(0, 0, 0), {"curl": 0.6, "curl_l": 0.6, "sq": 1.0, "turn": 0.0, "fp_l": 0.0, "fp_r": 0.0, "jaw": 0.0}])], 
		[0.12, M([H(0, -0.34, 0), B(0.34), C(0.1), HD(0.25), LR(0.42, -0.6, -0.45, 0.3), {"curl": 1.0, "curl_l": 1.0, "sq": 0.85}]), "s"], 
		[0.24, M([H(0, 0.12, 0), {"feet": V(0, 0, 0)}, FLR(0, 0, 0), B(-0.05), C(-0.05), HD(0.3), R(0.2, 0.7, 0.3, 0.2), Lt(0.3, -0.5, 0.0, 0.5), {"fp_l": -0.8, "fp_r": -0.8, "sq": 1.12, "fx": "dust"}])], 
		[0.44, M([H(0, 0.76, 0), {"feet": V(0, 0.66, 0)}, FL(0.03, 0.22, 0.3), FR(0.06, -0.28, 0.12), B(-0.1, 0.15), C(-0.1, 0.1), HD(0.35), R(0.2, 0.98, 0.05), Lt(0.3, -0.42, 0.1, 0.7), {"sq": 1.05, "jaw": 0.5}]), "s"], 
		[0.62, M([H(0, 0.05, 0), {"feet": V(0, 0, 0)}, FL(0, 0, 0), FR(0, 0, 0), B(0.1), HD(0.1), R(0.3, 0.6, 0.3, 0.3), {"fp_l": -0.5, "fp_r": -0.5, "sq": 1.0}])], 
		[0.72, M([H(0, -0.36, 0), {"feet": V(0, 0, 0)}, FLR(0, 0, 0), B(0.36), C(0.1), HD(0.1), LR(0.45, -0.55, -0.45, 0.3), {"fp_l": 0.0, "fp_r": 0.0, "sq": 0.84, "turn": 0.0, "jaw": 0.0, "fx": "dust_ring"}]), "s"], 
		[0.86, M([H(0, 0.12, 0), {"feet": V(0, 0, 0)}, FLR(0, 0, 0), B(-0.05, 0.3), C(-0.05, 0.3), HD(0.2, 0.3), LRt(-0.1, -0.2, 0.4, 0.5), {"fp_l": -0.8, "fp_r": -0.8, "sq": 1.14, "turn": 0.5, "fx": "dust"}])], 
		[1.1, M([H(0, 0.9, 0), {"feet": V(0, 1.22, 0)}, FL(0.1, 0.14, 0.06), FR(0.1, 0.04, -0.06), B(0.1, 0), C(-0.1, 0), HD(0.3, 0), L(0.9, 0.4, 0.0, 0.3), R(0.3, 0.95, 0.0, 0.2), {"sq": 1.04, "turn": 3.4, "jaw": 0.6, "fx": "sparkle"}])], 
		[1.32, M([H(0, 0.06, 0), {"feet": V(0, 0, 0)}, FL(0.1, 0, 0), FR(0.1, 0, 0), B(0.1), HD(0.1), L(0.7, 0.0, 0.1, 0.3), R(0.3, 0.8, 0.1, 0.2), {"fp_l": -0.5, "fp_r": -0.5, "sq": 1.0, "turn": 6.0}])], 
		[1.42, M([H(0, -0.34, 0), FLR(0.14, 0, 0), B(0.3), C(0.1), HD(0.25), L(0.7, -0.4, 0.2, 0.4), R(0.5, 0.2, 0.3, 0.4), {"fp_l": 0.0, "fp_r": 0.0, "sq": 0.84, "turn": 6.283, "jaw": 0.2, "fx": "dust_ring"}]), "s"], 
		[1.6, M([H(0.04, 0.02, 0), B(-0.12, 0.1), C(-0.12, 0.1), HD(0.25, -0.1), R(0.2, 0.98, 0.05, 0.1), _hip_l(), {"curl_l": 1.0, "sq": 1.05, "jaw": 0.5}]), "s"], 
		[1.76, M([H(0.04, -0.1, 0), B(0.0, 0.1), C(-0.05, 0.1), HD(0.1, -0.1), Rt(0.3, 0.1, 0.3, 0.6), {"sq": 0.97, "fp_l": 0.0, "fp_r": 0.0}])], 
		[1.88, M([H(0.04, 0.05, 0), FLR(0.14, 0, 0), B(-0.12, 0.1), C(-0.12, 0.1), HD(0.28, -0.1), R(0.2, 0.98, 0.05, 0.1), _hip_l(), {"curl": 1.0, "curl_l": 1.0, "fp_l": -0.5, "fp_r": -0.5, "sq": 1.04, "jaw": 0.5, "fx": "sparkle"}]), "s"], 
		[2.1, M([H(0.04, 0.0, 0), FLR(0.14, 0, 0), B(-0.1, 0.1), C(-0.12, 0.1), HD(0.25, -0.1), R(0.22, 0.95, 0.05, 0.1), _hip_l(), {"curl": 1.0, "curl_l": 1.0, "fp_l": 0.0, "fp_r": 0.0, "sq": 1.0, "jaw": 0.3}])], 
		[2.4, M([rest(), _loose(), {"turn": 6.283, "jaw": 0.0, "curl": 0.2, "curl_l": 0.2}])], 
	]}


	c["thumbsup@Simon"] = {"len": 2.1, "in": 0.1, "out": 0.25, "face": "grin", "keys": [
		[0.0, M([FLR(0, 0), H(0, -0.08, -0.05), B(0.05, -0.35), C(0, -0.2), HD(0, 0.5), Rt(0.2, -0.25, -0.15, 0.5), WR(0, -1.0), _hip_l(), {"curl": 1.0, "sq": 0.96, "fp_r": 0.0}])], 
		[0.2, M([FL(0.03, 0.36), FR(0.1, -0.1), H(0, -0.12, 0.3), B(0.16, 0.4), C(-0.05, 0.3), HD(0.1, -0.65, 0.25), R(0.3, 0.36, 0.9), WR(0.3, -1.57), {"fp_r": -0.5, "sq": 1.06, "ev": "effort"}])], 
		[0.3, M([H(0, -0.1, 0.26), B(0.12, 0.36), R(0.3, 0.3, 0.9), {"sq": 1.0, "fx": "glint"}]), "s"], 
		[0.8, M([H(0, -0.1, 0.26), B(0.12, 0.36), HD(0.1, -0.65, 0.25), R(0.3, 0.3, 0.9)])], 
		[0.9, M([H(0, -0.15, 0.28), HD(-0.08, -0.65, 0.3), Rt(0.3, 0.05, 0.45, 0.3)])], 
		[1.0, M([H(0, -0.1, 0.3), HD(0.1, -0.65, 0.25), R(0.3, 0.36, 0.9), {"fx": "sparkle"}]), "s"], 
		[1.6, M([FL(0.03, 0.36), FR(0.1, -0.1), H(0, -0.1, 0.26), B(0.12, 0.36), C(-0.05, 0.3), HD(0.1, -0.65, 0.25), R(0.3, 0.3, 0.9), WR(0.3, -1.57), _hip_l(), {"fp_r": -0.5, "curl": 1.0}]), "s"], 
		[1.85, M([FL(0.02, 0.15), FR(0.05, -0.05), H(0, -0.04, 0.1), B(0.05, 0.1), C(0, 0.1), HD(0, -0.2, 0.05), Rt(0.1, -0.4, 0.4, 0.3), WR(0, -0.5), {"fp_r": 0.0, "curl": 0.6}])], 
		[2.1, M([rest(), _loose(), {"curl": 0.3, "curl_l": 0.3}])], 
	]}


	c["point@Simon"] = {"len": 2.2, "in": 0.1, "out": 0.25, "face": "surprise", "keys": [
		[0.0, M([FLR(0, 0), H(0, -0.06, 0), B(0.1), C(0), HD(0.1), Lt(-0.1, 0.3, 0.45, 0.8), WL(0), R(0.3, -0.8, 0.1), WR(0), {"curl": 0.0, "curl_l": 0.0, "fp_r": 0.0, "jaw": 0.0}])], 
		[0.22, M([FL(0.04, 0.3), FR(0.1, -0.2), H(0, 0.04, 0.2), B(0.3, 0.3), C(0.0, 0.2), HD(0.2, -0.5), Lt(-0.18, 0.8, 0.42, 1.0), WL(-0.3), R(0.2, -0.5, 0.3, 0.3), {"fp_r": -0.6}]), "s"], 
		[0.55, M([H(0, 0.06, 0.24), B(0.34, 0.3), HD(0.22, -0.5), R(0.2, -0.5, 0.3, 0.3), WR(0)])], 
		[0.68, M([H(0, -0.02, 0.3), B(0.36, 0.42), C(0.0, 0.25), HD(0.2, -0.65), R(-0.1, 0.12, 1.0), WR(0, -1.57), {"ev": "gasp", "face": "grin", "jaw": 0.5}]), "s"], 
		[1.0, R(-0.1, 0.1, 0.98)], 
		[1.1, R(-0.1, 0.12, 0.8, 0.2)], 
		[1.2, M([R(-0.1, 0.14, 1.0), H(0, -0.04, 0.33)]), "s"], 
		[1.4, M([R(-0.1, 0.12, 0.8, 0.2), H(0, -0.02, 0.3)])], 
		[1.5, M([R(-0.1, 0.14, 1.0), H(0, -0.04, 0.33), {"jaw": 0.3}]), "s"], 
		[1.85, M([FL(0.04, 0.3), FR(0.1, -0.2), H(0, -0.02, 0.3), B(0.36, 0.42), C(0.0, 0.25), HD(0.2, -0.65), Lt(-0.18, 0.8, 0.42, 1.0), WL(-0.3), R(-0.1, 0.12, 0.98), WR(0, -1.57), {"fp_r": -0.6, "jaw": 0.3}]), "s"], 
		[2.2, M([rest(), _loose(), {"jaw": 0.0}])], 
	]}



static func _hold(pose: Dictionary, length: float = 1.2) -> Dictionary:
	return {"len": length, "in": 0.05, "out": 0.1, "keys": [[0.0, pose]]}
