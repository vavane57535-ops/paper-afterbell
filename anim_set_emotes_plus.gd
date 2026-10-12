extends "res://anim_pose.gd"

# Émotes 0.16 : applaudir, facepalm, bouder, cœur avec les mains, nananère, salut militaire,
# selfie, révérence, faire le beau, s'asseoir en tailleur.
# Repères : bras en longueurs de bras depuis l'épaule (dehors, haut, avant), « t » = repère du buste.

static func add(c: Dictionary) -> void :
	_clap(c)
	_facepalm(c)
	_sulk(c)
	_heart(c)
	_taunt(c)
	_salute(c)
	_selfie(c)
	_bow(c)
	_beg(c)
	_sit(c)


static func _hang() -> Dictionary:
	return M([LR(0.14, -0.96, 0.1), WL(0.0), WR(0.0), {"curl": 0.3, "curl_l": 0.3}])

static func _hip_l() -> Dictionary:
	return M([Lt(0.12, -0.66, 0.1, 0.6), WL(0.0), {"curl_l": 0.9}])

static func _hip_r() -> Dictionary:
	return M([Rt(0.12, -0.66, 0.1, 0.6), WR(0.0), {"curl": 0.9}])

static func _sh(up: float, fwd: float = 0.0) -> Dictionary:
	return {"l_clav": V(0.0, - fwd, - up), "r_clav": V(0.0, fwd, up)}

static func _start() -> Dictionary:
	return M([rest(), _hang(), _sh(0.0), {"jaw": 0.0, "shake": 0.0, "chatter": 0.0, "gesture": "", "prop": ""}])

static func _end() -> Dictionary:
	return M([rest(), _hang(), _sh(0.0), {"jaw": 0.0, "shake": 0.0, "chatter": 0.0}])



static func _clap(c: Dictionary) -> void :
	var open: Dictionary = M([Lt(0.02, -0.26, 0.5, 0.3), Rt(0.02, -0.26, 0.5, 0.3), WL(0.0, 1.3, 0.0), WR(0.0, -1.3, 0.0), {"curl": 0.05, "curl_l": 0.05}])
	var shut: Dictionary = M([Lt(-0.26, -0.3, 0.54, 0.3), Rt(-0.26, -0.3, 0.54, 0.3), WL(0.0, 1.3, 0.0), WR(0.0, -1.3, 0.0)])
	var high_open: Dictionary = M([L(0.14, 0.78, 0.56, 0.3), R(0.14, 0.78, 0.56, 0.3), WL(-0.3, 1.3, 0.0), WR(-0.3, -1.3, 0.0)])
	var high_shut: Dictionary = M([L(-0.2, 0.82, 0.56, 0.3), R(-0.2, 0.82, 0.56, 0.3), WL(-0.3, 1.3, 0.0), WR(-0.3, -1.3, 0.0)])
	var keys: Array = [
		[0.0, _start()],
		[0.18, M([H(0.0, -0.05, 0.0), B(0.06), C(0.05), HD(-0.05), open, {"sq": 0.97}])],
	]
	var t: float = 0.32
	for k: int in range(6):
		var side: float = 1.0 if k % 2 == 0 else -1.0
		keys.append([t, M([shut, H(0.0, -0.045, 0.0), B(0.04, 0.06 * side), C(0.06, 0.05 * side), HD(-0.08, 0.1 * side, 0.06 * side), {"sq": 0.98, "fx": "clap"}]), "s"])
		keys.append([t + 0.14, M([open, H(0.0, 0.0, 0.0), B(0.0, 0.03 * side), C(0.0, 0.02 * side), HD(0.06, 0.05 * side, 0.0), {"sq": 1.01}])])
		t += 0.27
	keys += [
		[1.98, M([high_open, H(0.0, 0.02, 0.0), B(-0.08), C(-0.12), HD(0.22), _sh(0.12), {"fp_l": -0.4, "fp_r": -0.4, "sq": 1.04}])],
		[2.12, M([high_shut, H(0.0, 0.04, 0.0), HD(0.25, 0.0, 0.05), {"sq": 1.05, "fx": "clap pop_r"}]), "s"],
		[2.26, M([high_open, H(0.0, 0.0, 0.0), HD(0.2)])],
		[2.4, M([high_shut, H(0.0, 0.05, 0.0), HD(0.26, 0.0, -0.05), {"sq": 1.06, "fx": "clap sparkle"}]), "s"],
		[2.68, M([H(0.0, -0.03, 0.0), B(0.0), C(0.02), HD(0.0), _sh(0.0), LR(0.25, -0.85, 0.2, 0.2), WL(0.0), WR(0.0), {"fp_l": 0.0, "fp_r": 0.0, "sq": 1.0, "curl": 0.3, "curl_l": 0.3}])],
		[3.0, _end()],
	]
	c["clap"] = {"len": 3.0, "in": 0.1, "out": 0.28, "face": "grin", "keys": keys}



static func _facepalm(c: Dictionary) -> void :
	var palm: Dictionary = M([Rt(-0.3, 0.36, 0.42, 0.55), WR(0.5, -0.3, 0.0), {"curl": 0.1}])
	c["facepalm"] = {"len": 2.9, "in": 0.1, "out": 0.3, "face": "tired", "keys": [
		[0.0, _start()],
		[0.24, M([H(0.0, 0.02, -0.03), B(-0.06), C(-0.08), HD(0.22, 0.25, 0.12), _sh(0.2), L(0.35, -0.6, 0.3, 0.3), R(0.35, -0.6, 0.3, 0.3), WL(0.0, -1.2), WR(0.0, 1.2), {"curl": 0.0, "curl_l": 0.0, "face": "surprise", "sq": 1.02}])],
		[0.46, M([HD(0.18, 0.3, 0.12), Rt(0.15, 0.1, 0.55, 0.4), WR(0.2, 0.0, 0.0), {"face": "tired"}])],
		[0.6, M([H(0.0, -0.03, 0.02), B(0.12), C(0.16), HD(-0.38, 0.0, 0.05), _sh(-0.05), palm, _hip_l(), {"sq": 0.96, "fx": "slap", "face": "pain"}]), "s"],
		[0.8, M([HD(-0.36, 0.0, 0.0), {"sq": 1.0, "face": "tired"}])],
		[1.05, M([B(0.14, 0.04), C(0.18, 0.05), HD(-0.34, 0.18, 0.0), Rt(-0.28, 0.35, 0.44, 0.55)])],
		[1.35, M([B(0.14, -0.04), C(0.18, -0.05), HD(-0.34, -0.18, 0.0), Rt(-0.32, 0.35, 0.42, 0.55)])],
		[1.65, M([B(0.14, 0.04), C(0.18, 0.05), HD(-0.34, 0.15, 0.0), Rt(-0.28, 0.35, 0.44, 0.55)])],
		[1.9, M([B(0.13), C(0.17), HD(-0.36, 0.0, 0.0), palm])],
		[2.2, M([B(0.16), C(0.22), HD(-0.42, 0.0, 0.06), _sh(-0.2, 0.1), Rt(-0.18, -0.15, 0.42, 0.3), WR(0.0), {"curl": 0.3, "ev": "sigh"}])],
		[2.55, M([H(0.0, -0.02, 0.0), B(0.06), C(0.08), HD(-0.15), _sh(-0.05), LR(0.16, -0.94, 0.12), WL(0.0), WR(0.0), {"curl": 0.3, "curl_l": 0.3}])],
		[2.9, _end()],
	]}



static func _sulk(c: Dictionary) -> void :
	var crossed: Dictionary = M([Lt(-0.52, -0.42, 0.34, 0.3), Rt(-0.46, -0.32, 0.42, 0.3), WL(0.3, 0.0, 0.0), WR(0.2, 0.0, 0.0), {"curl": 0.6, "curl_l": 0.6}])
	var away: Dictionary = M([H(0.03, 0.0, -0.02), B(-0.04, -0.12), C(-0.08, -0.1, 0.0), HD(0.26, 0.62, 0.12), _sh(0.06)])
	var keys: Array = [
		[0.0, _start()],
		[0.2, M([H(0.0, 0.04, 0.0), B(-0.05), C(-0.08), HD(0.15, 0.0, 0.0), _sh(0.22), LR(0.3, -0.7, 0.3, 0.3), FR(0.1, 0.06, 0.14), {"sq": 1.04, "curl": 0.8, "curl_l": 0.8, "fp_r": 0.0}])],
		[0.38, M([crossed, away, FR(0.1, 0.06, 0.0), {"sq": 0.97, "fx": "stomp dust", "turn": -0.25}]), "s"],
		[0.55, M([HD(0.3, 0.66, 0.1), {"sq": 1.0}])],
	]
	var t: float = 0.8
	for k: int in range(6):
		keys.append([t, M([FR(0.1, 0.12, 0.0), {"fp_r": -0.45}])])
		keys.append([t + 0.13, M([FR(0.1, 0.12, 0.0), {"fp_r": 0.0}]), "s"])
		t += 0.26
	keys += [
		[1.55, M([crossed, HD(0.05, 0.15, 0.0), B(0.0, -0.05), C(0.0, -0.05), {"sq": 1.0}])],
		[1.85, M([HD(0.05, 0.12, 0.0), {"sq": 1.03}])],
		[2.05, M([crossed, away, HD(0.32, 0.7, 0.14), _sh(0.16), {"sq": 1.05, "ev": "effort"}]), "s"],
		[2.25, M([_sh(0.04), {"sq": 1.0}])],
		[2.75, M([crossed, away, {"turn": -0.25}])],
		[3.05, M([H(0.0, -0.02, 0.0), B(0.0), C(0.0), HD(0.0), _sh(0.0), LR(0.2, -0.88, 0.2, 0.2), WL(0.0), WR(0.0), FR(0.0, 0.0, 0.0), {"curl": 0.3, "curl_l": 0.3, "turn": 0.0, "fp_r": 0.0}])],
		[3.3, _end()],
	]
	c["sulk"] = {"len": 3.3, "in": 0.1, "out": 0.28, "face": "angry", "keys": keys}



static func _heart(c: Dictionary) -> void :
	c["heart"] = _heart_clip(0.0, 0.04)
	c["heart@Simon"] = _heart_clip(0.5, 0.04)
	# Mains qui se touchent juste au centre, sans croiser les avant-bras (carrures différentes).
	c["heart@Ashura"] = _heart_clip(0.0, 0.01, -0.07, 0.8)
	c["heart@Bleuette"] = _heart_clip(0.0, 0.14)

# Petit cœur avec les mains devant la poitrine (bouts des doigts joints, coudes ouverts),
# puis grand cœur avec les bras au-dessus de la tête.
static func _heart_clip(front: float, inward: float, big_out: float = -0.1, big_up: float = 0.9) -> Dictionary:
	var small: Dictionary = M([Lt(- inward, -0.2, 0.56, 0.9), Rt(- inward, -0.2, 0.56, 0.9), WL(-0.6, 1.3, 0.0), WR(-0.6, -1.3, 0.0), {"curl": 0.55, "curl_l": 0.55}])
	var big: Dictionary = M([L(big_out, big_up - 0.1 * front, 0.1 + front, 0.95), R(big_out, big_up - 0.1 * front, 0.1 + front, 0.95), WL(1.1, 0.0, 0.0), WR(1.1, 0.0, 0.0), {"curl": 0.25, "curl_l": 0.25}])
	return {"len": 2.9, "in": 0.1, "out": 0.3, "face": "smile", "keys": [
		[0.0, _start()],
		[0.2, M([H(0.0, -0.04, 0.0), B(0.05), C(0.08), HD(-0.08), Lt(-0.12, -0.32, 0.45, 0.3), Rt(-0.12, -0.32, 0.45, 0.3), {"sq": 0.97, "curl": 0.3, "curl_l": 0.3}])],
		[0.4, M([small, H(0.0, 0.02, 0.0), B(-0.03), C(-0.05), HD(0.05, 0.0, 0.18), _sh(0.12), {"fp_l": -0.3, "fp_r": -0.3, "sq": 1.04, "fx": "notes kiss", "face": "grin"}]), "s"],
		[0.6, M([small, HD(0.04, 0.0, 0.16), _sh(0.08), {"fp_l": 0.0, "fp_r": 0.0, "sq": 1.0}])],
		[0.85, M([small, H(0.05, 0.0, 0.0), B(0.0, 0.0, -0.06), C(-0.04, 0.0, -0.06), HD(0.05, 0.05, -0.18)])],
		[1.1, M([small, H(-0.04, 0.0, 0.0), B(0.0, 0.0, 0.05), C(-0.04, 0.0, 0.05), HD(0.05, -0.05, 0.16)])],
		[1.3, M([L(0.62, 0.55, 0.15, 0.6), R(0.62, 0.55, 0.15, 0.6), WL(0.3), WR(0.3), H(0.0, -0.05, 0.0), B(0.0, 0.0, 0.0), C(-0.04), HD(0.12, 0.0, 0.0), _sh(0.05), {"curl": 0.1, "curl_l": 0.1, "sq": 0.97}])],
		[1.52, M([big, H(0.0, 0.03, 0.0), B(-0.04), C(-0.1), HD(0.08, 0.0, 0.1), _sh(0.2), {"fp_l": -0.4, "fp_r": -0.4, "sq": 1.05, "fx": "cheer kiss", "face": "laugh"}]), "s"],
		[1.72, M([big, HD(0.06, 0.0, 0.08), {"fp_l": 0.0, "fp_r": 0.0, "sq": 1.0, "face": "grin"}])],
		[1.98, M([big, H(0.05, 0.0, 0.0), B(0.0, 0.0, -0.07), C(-0.1, 0.0, -0.06), HD(0.08, 0.05, -0.14)])],
		[2.24, M([big, H(-0.05, 0.0, 0.0), B(0.0, 0.0, 0.07), C(-0.1, 0.0, 0.06), HD(0.08, -0.05, 0.14)])],
		[2.52, M([H(0.0, -0.02, 0.0), B(0.0), C(0.0), HD(0.0), _sh(0.0), LR(0.3, -0.75, 0.15, 0.3), WL(0.0), WR(0.0), {"curl": 0.3, "curl_l": 0.3, "face": "smile"}])],
		[2.9, _end()],
	]}



static func _taunt(c: Dictionary) -> void :
	c["taunt"] = _taunt_clip(0.0)
	c["taunt@Simon"] = _taunt_clip(0.22)

static func _taunt_clip(reach: float) -> Dictionary:
	var nose: Dictionary = M([Rt(-0.3, 0.32, 0.4 + reach, 0.6), WR(-0.2, -1.4, 0.0), Lt(-0.28, 0.3, 0.62 + reach, 0.6), WL(-0.2, 1.4, 0.0), {"curl": 0.0, "curl_l": 0.0}])
	var keys: Array = [
		[0.0, _start()],
		[0.16, M([H(0.0, -0.04, -0.03), B(-0.1), C(-0.08), HD(0.12, 0.0, 0.1), Rt(-0.1, 0.0, 0.5, 0.4), Lt(-0.1, -0.05, 0.5, 0.4), {"sq": 0.98}])],
		[0.32, M([nose, H(0.0, 0.0, -0.04), B(-0.14), C(-0.12), HD(0.15, 0.0, -0.12), {"sq": 1.03, "fx": "raspberry"}]), "s"],
	]
	var t: float = 0.44
	for k: int in range(8):
		var wiggle: float = 1.0 if k % 2 == 0 else -1.0
		keys.append([t, M([nose, WR(-0.2, -1.4, 0.35 * wiggle), WL(-0.2, 1.4, -0.35 * wiggle), B(-0.14), C(-0.12), HD(0.15, 0.08 * wiggle, -0.12 * wiggle), H(0.03 * wiggle, 0.0, -0.04), {"curl": 0.25 if k % 2 == 0 else 0.0, "curl_l": 0.0 if k % 2 == 0 else 0.25, "turn": 0.0}])])
		t += 0.12
	keys += [
		[1.42, M([H(0.0, -0.02, 0.0), B(0.0), C(0.0), HD(0.05, 0.3, 0.0), R(0.3, -0.75, 0.1, 0.3), L(0.3, -0.75, 0.1, 0.3), WR(0.0), WL(0.0), {"curl": 0.3, "curl_l": 0.3, "turn": 0.0}])],
		[1.68, M([H(0.0, -0.04, 0.0), B(0.32), C(0.12), HD(0.35, -0.5, 0.0), R(0.25, -0.62, -0.32, 0.4), _hip_l(), {"turn": PI * 0.85, "sq": 0.98}])],
		[1.82, M([H(0.06, -0.03, 0.0), B(0.32), C(0.12), HD(0.35, -0.5, 0.0), R(0.2, -0.66, -0.4, 0.4), _hip_l(), {"turn": PI * 0.85, "fx": "slap", "sq": 1.02}]), "s"],
		[1.96, M([H(-0.06, -0.03, 0.0), B(0.32), C(0.12), HD(0.35, -0.55, 0.0), R(0.32, -0.55, -0.25, 0.4), _hip_l(), {"turn": PI * 0.85}])],
		[2.1, M([H(0.06, -0.03, 0.0), B(0.32), C(0.12), HD(0.35, -0.5, 0.0), R(0.2, -0.66, -0.4, 0.4), _hip_l(), {"turn": PI * 0.85, "fx": "slap"}]), "s"],
		[2.24, M([H(0.0, -0.02, 0.0), B(0.25), C(0.1), HD(0.3, -0.5, 0.0), R(0.3, -0.6, -0.2, 0.4), _hip_l(), {"turn": PI * 0.85}])],
		[2.5, M([H(0.0, 0.0, 0.0), B(0.0), C(0.0), HD(0.0), LR(0.18, -0.9, 0.15, 0.2), WL(0.0), WR(0.0), {"turn": 0.0, "curl": 0.3, "curl_l": 0.3}])],
		[2.7, _end()],
	]
	return {"len": 2.7, "in": 0.1, "out": 0.22, "face": "grin", "keys": keys}



static func _salute(c: Dictionary) -> void :
	var brow: Dictionary = M([Rt(-0.12, 0.48, 0.24, 0.95), WR(0.15, -0.9, -0.35), {"curl": 0.0}])
	var attention: Dictionary = M([FL(-0.03, 0.0), FR(-0.03, 0.0), H(0.0, 0.03, 0.0), B(-0.04), C(-0.1), HD(0.08), _sh(-0.06, -0.05), Lt(0.08, -0.92, -0.02, 0.1), WL(0.0), {"curl_l": 0.75}])
	c["salute"] = {"len": 2.6, "in": 0.1, "out": 0.25, "face": "determined", "keys": [
		[0.0, _start()],
		[0.16, M([H(0.0, -0.04, 0.0), FR(0.02, 0.0, 0.1), B(0.04), HD(-0.05), {"sq": 0.98}])],
		[0.3, M([attention, FR(-0.03, 0.0, 0.0), Rt(0.2, -0.1, 0.35, 0.8), {"sq": 1.03, "fx": "heel dust"}]), "s"],
		[0.44, M([brow, attention, {"sq": 1.01, "fx": "pop_r"}]), "s"],
		[0.6, M([brow, {"sq": 1.0}])],
		[1.05, M([brow, HD(-0.06), C(-0.06), {"sq": 0.99}])],
		[1.2, M([brow, HD(0.1), C(-0.1), {"sq": 1.01}]), "s"],
		[1.75, M([brow, HD(0.08)])],
		[1.92, M([Rt(0.3, -0.3, 0.2, 0.6), WR(0.0), {"curl": 0.5}]), "s"],
		[2.05, M([attention, R(0.06, -0.94, 0.0, 0.1), WR(0.0), {"curl": 0.75}]), "s"],
		[2.35, M([H(0.0, 0.0, 0.0), FL(0.0, 0.0), FR(0.0, 0.0), B(0.0), C(0.0), HD(0.0), _sh(0.0), LR(0.16, -0.94, 0.1), WL(0.0), WR(0.0), {"curl": 0.3, "curl_l": 0.3}])],
		[2.6, _end()],
	]}



static func _selfie(c: Dictionary) -> void :
	var arm: Dictionary = M([R(0.48, 0.38, 0.6, 0.35), WR(0.1, 1.2, 0.2), {"curl": 0.75}])
	var arm_b: Dictionary = M([R(0.36, 0.48, 0.66, 0.35), WR(0.0, 1.1, 0.25), {"curl": 0.75}])
	c["selfie"] = {"len": 3.3, "in": 0.1, "out": 0.3, "face": "grin", "keys": [
		[0.0, _start()],
		[0.2, M([Rt(0.1, -0.45, 0.25, 0.3), WR(0.0, 0.6), H(0.0, -0.02, 0.0), {"prop": "phone", "curl": 0.75}])],
		[0.46, M([arm, H(0.04, 0.0, 0.0), B(0.0, 0.08, -0.05), C(-0.04, 0.1, -0.06), HD(0.12, 0.35, 0.22), _hip_l(), {"sq": 1.02}]), "s"],
		[0.7, M([HD(0.14, 0.35, 0.25), {"fx": "shutter glint", "sq": 1.03}]), "s"],
		[0.85, M([{"sq": 1.0}])],
		[1.1, M([arm_b, H(-0.05, 0.0, 0.0), B(0.0, 0.06, 0.06), C(-0.05, 0.08, 0.06), HD(0.1, 0.3, -0.22), Lt(-0.18, 0.22, 0.5, 0.6), WL(0.4, 1.2, 0.0), {"curl_l": 0.2, "face": "calm"}])],
		[1.4, M([HD(0.12, 0.32, -0.25), {"fx": "shutter glint", "sq": 1.03}]), "s"],
		[1.55, M([{"sq": 1.0}])],
		[1.82, M([arm, H(0.0, 0.03, 0.0), B(-0.06, 0.1, 0.0), C(-0.08, 0.12, 0.0), HD(0.16, 0.38, 0.05), L(0.7, 0.55, 0.2, 0.4), WL(0.0, -1.0, 0.0), {"curl_l": 0.0, "face": "laugh", "fp_l": -0.3, "fp_r": -0.3}])],
		[2.08, M([{"fx": "shutter glint", "sq": 1.04}]), "s"],
		[2.25, M([{"sq": 1.0, "fp_l": 0.0, "fp_r": 0.0}])],
		[2.5, M([Rt(-0.14, 0.02, 0.55, 0.3), WR(0.7, 1.4, 0.0), Lt(-0.08, -0.1, 0.5, 0.3), WL(0.0), H(0.0, -0.02, 0.0), B(0.04), C(0.06), HD(-0.24, 0.0, 0.0), {"curl_l": 0.4, "face": "smile"}])],
		[2.72, M([Rt(-0.14, 0.02, 0.55, 0.3), HD(-0.16, 0.0, 0.0)])],
		[2.86, M([Rt(-0.14, 0.02, 0.55, 0.3), HD(-0.26, 0.0, 0.0)])],
		[3.02, M([Rt(0.12, -0.45, 0.25, 0.3), WR(0.0, 0.6), LR(0.2, -0.85, 0.2), HD(0.0), B(0.0), C(0.0), {"prop": ""}])],
		[3.3, _end()],
	]}



static func _bow(c: Dictionary) -> void :
	c["bow"] = {"len": 2.9, "in": 0.1, "out": 0.3, "face": "calm", "keys": [
		[0.0, _start()],
		[0.25, M([H(0.0, 0.02, 0.0), B(-0.06, 0.1), C(-0.06, 0.1), HD(0.1, 0.1), R(0.75, 0.45, 0.35, 0.4), WR(0.0, -1.2, 0.3), L(0.3, -0.7, 0.1), {"curl": 0.0, "fp_r": -0.2}])],
		[0.48, M([FR(0.06, -0.32, 0.0), H(0.0, -0.05, -0.05), B(0.0, 0.04), C(0.0), HD(0.05), R(0.9, 0.05, 0.1, 0.4), WR(0.0, -1.6, 0.2), L(0.6, -0.55, -0.1, 0.3), {"fp_r": -0.5}])],
		[0.8, M([FR(0.06, -0.32, 0.0), H(0.0, -0.1, -0.08), B(0.62, 0.0), C(0.3), HD(-0.25), Rt(-0.34, -0.52, 0.36, 0.4), WR(0.2, 0.0, 0.0), Lt(0.85, -0.3, -0.25, 0.3), WL(0.0, 0.0, -0.3), {"fp_r": -0.6, "curl": 0.1, "curl_l": 0.0, "sq": 0.98}]), "s"],
		[1.55, M([B(0.66), C(0.32), HD(-0.3), {"sq": 0.99}])],
		[1.9, M([FR(0.06, -0.24, 0.0), H(0.0, -0.04, -0.03), B(0.1), C(0.05), HD(0.1), Rt(-0.1, -0.5, 0.35, 0.3), Lt(0.5, -0.6, 0.0, 0.3), {"fp_r": -0.3, "sq": 1.02, "face": "smile"}])],
		[2.25, M([FR(0.0, 0.0, 0.0), H(0.0, 0.0, 0.0), B(0.0), C(0.0), HD(0.04), LR(0.2, -0.88, 0.15), WL(0.0), WR(0.0), {"fp_r": 0.0, "curl": 0.3, "curl_l": 0.3, "sq": 1.0}])],
		[2.9, _end()],
	]}



static func _beg(c: Dictionary) -> void :
	var paws: Dictionary = M([Lt(-0.14, -0.2, 0.5, 0.2), Rt(-0.14, -0.2, 0.5, 0.2), WL(1.15), WR(1.15), {"curl": 0.75, "curl_l": 0.75}])
	var crouch: Dictionary = M([FL(0.14, 0.05), FR(0.14, 0.05), H(0.0, -0.32, 0.02), B(-0.08), C(-0.04), {"fp_l": -0.35, "fp_r": -0.35}])
	var keys: Array = [
		[0.0, _start()],
		[0.28, M([crouch, paws, HD(0.15, 0.0, 0.25), {"sq": 0.95, "jaw": 0.3}])],
	]
	var t: float = 0.45
	for k: int in range(10):
		var s: float = 1.0 if k % 2 == 0 else -1.0
		var tilt: float = 0.25 if (k / 3) % 2 == 0 else -0.25
		keys.append([t, M([H(0.07 * s, -0.31 + 0.02 * s, 0.02), Lt(-0.14, -0.2 + 0.06 * s, 0.5, 0.2), Rt(-0.14, -0.2 - 0.06 * s, 0.5, 0.2), HD(0.18, 0.05 * s, tilt), {"jaw": 0.55 if k % 2 == 0 else 0.25, "sq": 1.0 + 0.02 * s}])])
		t += 0.2
	keys += [
		[2.5, M([crouch, H(0.0, -0.36, 0.02), paws, HD(0.25, 0.0, 0.3), {"jaw": 0.7, "fx": "sparkle", "sq": 1.03}]), "s"],
		[2.78, M([FL(0.0, 0.0), FR(0.0, 0.0), H(0.0, 0.0, 0.0), B(0.0), C(0.0), HD(0.0), LR(0.2, -0.85, 0.2), WL(0.0), WR(0.0), {"fp_l": 0.0, "fp_r": 0.0, "jaw": 0.0, "curl": 0.3, "curl_l": 0.3, "sq": 1.0}])],
		[3.1, _end()],
	]
	c["beg"] = {"len": 3.1, "in": 0.1, "out": 0.3, "face": "grin", "keys": keys}



static func _sit(c: Dictionary) -> void :
	var legs: Dictionary = M([{"plant": 0.0, "gsnap": 1.0}, TL_(1.35, 0.85, 0.55), KL_(2.45, -0.3), TR_(1.35, 0.85, 0.55), KR_(2.45, -0.3)])
	var hands: Dictionary = M([L(0.34, -0.8, 0.52, 0.3), R(0.34, -0.8, 0.52, 0.3), WL(0.4), WR(0.4), {"curl": 0.4, "curl_l": 0.4}])
	var keys: Array = [
		[0.0, M([_start(), {"plant": 1.0, "gsnap": 0.0, "gait": 1.0}])],
		[0.35, M([{"gait": 0.0}, H(0.0, -0.4, 0.0), FL(0.1, 0.1), FR(0.1, 0.1), B(0.35), C(0.1), HD(-0.2), L(0.35, -0.8, 0.45), R(0.35, -0.8, 0.45), {"sq": 0.96}])],
		[0.75, M([legs, B(0.12), C(0.05), HD(-0.05), hands, {"sq": 0.97, "fx": "dust"}]), "s"],
		[1.2, M([legs, B(-0.02), C(0.04), HD(0.05), hands, {"sq": 1.0}])],
		[2.0, M([legs, B(-0.02, 0.06), C(0.08, 0.06), HD(0.08, 0.35, 0.05), hands])],
		[2.6, M([legs, B(-0.02, 0.0), C(0.02, 0.0), HD(0.12, 0.0, 0.1), hands, {"sq": 1.01}])],
		[3.3, M([legs, B(-0.02, -0.06), C(0.08, -0.06), HD(0.05, -0.35, -0.05), hands])],
		[4.0, M([legs, B(-0.02), C(0.04), HD(0.05), hands, {"sq": 1.0}])],
	]
	c["sit"] = {"len": 4.0, "loop": true, "loop_from": 1.2, "in": 0.1, "face": "calm", "keys": keys}

static func TL_(fwd: float, out: float = 0.0, yaw: float = 0.0) -> Dictionary:
	return {"l_leg": Vector3(fwd, yaw, - out)}

static func TR_(fwd: float, out: float = 0.0, yaw: float = 0.0) -> Dictionary:
	return {"r_leg": Vector3(fwd, - yaw, out)}

static func KL_(bend: float, ankle: float = 0.0) -> Dictionary:
	return {"l_knee": - bend, "l_ank": ankle}

static func KR_(bend: float, ankle: float = 0.0) -> Dictionary:
	return {"r_knee": - bend, "r_ank": ankle}
