extends "res://anim_pose.gd"




const RIGHT: float = 1.5708

static func add(c: Dictionary) -> void :
	_carriage(c)
	_abilities(c)
	_states(c)
	_personality(c)
	_point(c)








static func AL(swing: float, out: float, bend: float) -> Dictionary:
	return {"l_arm": Vector3(swing, 0.0, - out), "l_elb": Vector3(bend, 0.0, 0.0)}

static func AR(swing: float, out: float, bend: float) -> Dictionary:
	return {"r_arm": Vector3(swing, 0.0, out), "r_elb": Vector3(bend, 0.0, 0.0)}


static func SH(amount: float) -> Dictionary:
	return {"l_clav": Vector3(0.0, 0.0, -0.4 * amount), "r_clav": Vector3(0.0, 0.0, 0.4 * amount)}


static func _attention() -> Dictionary:
	return M([LR(0.4, -0.91, 0.0), WL(0.0), WR(0.0), {"curl": 0.05}])







static func _steps(start: Dictionary, steps: Array, move: float = 0.06, lead: bool = true) -> Array:
	var keys: Array = [[0.0, start, "h"]] if lead else []
	var held: Dictionary = start.duplicate()
	for step: Array in steps:
		var time: float = step[0]
		var pose: Dictionary = step[1]
		var leave: Dictionary = {}
		for channel: String in pose:
			if held.has(channel) and not (held[channel] is String): leave[channel] = held[channel]
		if not leave.is_empty(): keys.append([maxf(time - move, 0.0), leave, "l"])
		if step.size() > 2:
			var over: Dictionary = step[2]
			var plain: Dictionary = {}
			var settle: Dictionary = {}
			for channel: String in pose:
				if over.has(channel): settle[channel] = pose[channel]
				else: plain[channel] = pose[channel]
			if not plain.is_empty(): keys.append([time, plain, "h"])
			keys.append([time, over, "l"])
			keys.append([time + 0.05, settle, "h"])
		else:
			keys.append([time, pose, "h"])
		held.merge(pose, true)
	return keys


static func _weave(a: Array, b: Array) -> Array:
	var keys: Array = []
	var i: int = 0
	var j: int = 0
	while i < a.size() or j < b.size():
		if j >= b.size() or (i < a.size() and float(a[i][0]) <= float(b[j][0])):
			keys.append(a[i])
			i += 1
		else:
			keys.append(b[j])
			j += 1
	return keys





static func _hum(from: float, to: float, step: float, amount: float, jolts: Array = [], base: float = 1.0) -> Array:
	var keys: Array = []
	var count: int = int(round((to - from) / step))
	for i in range(count + 1):
		var time: float = minf(from + step * i, to)
		var kick: float = 0.0
		for jolt: float in jolts:
			var since: float = time - jolt
			if since >= -0.001 and since < 0.2: kick = maxf(kick, 1.0 - since / 0.2)
		var side: float = 1.0 if i % 2 == 0 else -1.0
		keys.append([time, {"sq": base - 0.08 * kick + amount * side * (1.0 + 2.0 * kick)}, "h"])
	return keys



static func _bursts(at: Array, low: float, length: float) -> Array:
	var keys: Array = []
	for time: float in at:
		if time > 0.03: keys.append([time - 0.02, {"shake": low}, "l"])
		keys.append([time, {"shake": 1.0}, "l"])
		if time + 0.1 <= length: keys.append([time + 0.1, {"shake": low}, "h"])
	return keys



static func _carriage(c: Dictionary) -> void :



	c["stance@Lysia"] = {"len": 9.0, "loop": true, "add": true, "keys": _steps(
		M([LR(0.4, -0.91, 0.0), C(-0.03), HD(0.0, 0.0, 0.0), {"curl": 0.05}]), [
		[2.0, HD(0.03, 0.22, 0.0), HD(0.03, 0.28, 0.0)], 
		[4.3, HD(-0.05, -0.2, 0.0), HD(-0.05, -0.26, 0.0)], 
		[5.5, {"curl": 0.7}], 
		[5.72, {"curl": 0.05}], 
		[6.4, HD(0.04, 0.0, -0.13), HD(0.04, 0.0, -0.17)], 
		[8.0, HD(0.0, 0.0, 0.0), HD(-0.01, 0.0, 0.03)], 
	], 0.05)}



	c["alert@Lysia"] = {"len": 2.4, "loop": true, "add": true, "keys": _steps(
		M([FLR(0.15, 0.0), H(0, -0.13, 0.0), B(0.07), C(0.03), HD(-0.06, 0.0), AL(0.8, 0.42, RIGHT), AR(0.8, 0.42, RIGHT), WL(0.0), WR(0.0), {"curl": 1.0, "shake": 0.15}]), [
		[0.55, HD(-0.06, 0.36), HD(-0.06, 0.42)], 
		[1.15, HD(-0.06, 0.0), HD(-0.06, -0.05)], 
		[1.75, HD(-0.06, -0.36), HD(-0.06, -0.42)], 
		[2.4, HD(-0.06, 0.0)], 
	], 0.05)}


	c["walk@Lysia"] = {"len": 1.0, "loop": true, "add": true, "keys": [
		[0.0, M([AR(0.9, 0.14, 0.0), AL(-0.6, 0.14, 0.0), WL(0.0), WR(0.0), {"curl": 0.05}]), "h"], 
		[0.14, M([AR(0.9, 0.14, 0.0), AL(-0.6, 0.14, 0.0)]), "s"], 
		[0.5, M([AR(-0.6, 0.14, 0.0), AL(0.9, 0.14, 0.0)]), "h"], 
		[0.64, M([AR(-0.6, 0.14, 0.0), AL(0.9, 0.14, 0.0)]), "s"], 
	]}



	# Course mécanique : bras en pistons (balancier à arrêts nets, coude fixe à angle droit, mains plates),
	# buste qui ne tourne presque pas et tête stable ; la vapeur s'échappe à chaque cycle de sprint.
	c["run@Lysia"] = {"len": 1.0, "loop": true, "add": true, "keys": [
		[0.0, M([WL(0.0), WR(0.0), {"curl": 0.05}])],
	]}


	c["sprint@Lysia"] = {"len": 1.0, "loop": true, "add": true, "keys": [
		[0.0, M([HD(0.04), WL(0.0), WR(0.0), {"curl": 0.05, "fx": "steam"}])],
	]}




static func _push_braced() -> Dictionary:
	return M([FL(0.03, 0.08), FR(0.1, -0.62), H(0, -0.24, -0.26), B(0.22), C(0.04), HD(0.14), LR(-0.14, -0.06, 1.0), WL(1.0), WR(1.0), SH(0.0), {"fp_l": 0.0, "fp_r": -0.6, "shake": 0.25}])

static func _abilities(c: Dictionary) -> void :




	c["push"] = {"len": 0.9, "in": 0.03, "out": 0.14, "face": "angry", "keys": _weave([
		[0.0, M([LRt(0.1, -0.5, 0.3, 0.4), WL(0.0), WR(0.0), SH(0.0), {"curl": 0.0, "shake": 0.0, "fx": "volt trail_both"}])], 
		[0.05, M([FLR(0.05, 0.0), H(0, -0.16, -0.12), B(-0.16), C(-0.14), HD(0.2), LRt(-0.02, -0.12, 0.12, 0.85), WL(0.9), WR(0.9), {"sq": 0.9}])], 
		[0.1, M([FL(0.03, 0.44), FR(0.1, -0.3), H(0, -0.2, 0.38), B(0.4), C(0.1), HD(0.3), LR(-0.14, -0.06, 1.0), WL(1.0), WR(1.0), {"fp_l": 0.0, "fp_r": -0.6, "sq": 1.1, "shake": 1.0, "ev": "grunt", "fx": "pop_front crack"}])], 
		[0.15, M([FL(0.03, 0.34), FR(0.1, -0.38), H(0, -0.23, 0.24), B(0.3), HD(0.22), LR(-0.14, -0.01, 1.0), {"fp_l": 0.35, "sq": 0.97, "fx": "skid"}])], 
		[0.28, M([FL(0.03, 0.14), FR(0.1, -0.56), H(0, -0.26, -0.16), B(0.2), C(0.04), HD(0.16), LR(-0.14, -0.05, 1.0), {"shake": 0.6, "sq": 1.0}])], 
		[0.44, _push_braced(), "h"], 
	], _steps(_push_braced(), [
		[0.52, M([HD(-0.3), C(0.16), LR(-0.14, -0.16, 0.98), SH(-0.6), {"shake": 0.0, "fx": "steam"}])], 
		[0.62, M([LRt(0.12, -0.5, 0.5, 0.0), WL(0.0), WR(0.0), B(0.08), C(0.0), HD(0.0), SH(0.0)])], 
		[0.7, M([LR(0.4, -0.91, 0.0), H(0, -0.08, -0.26), B(0.0)])], 
		[0.78, M([FR(0.0, 0.0), H(0, -0.03, -0.02), {"fp_r": 0.0}])], 
		[0.85, M([FL(0.0, 0.0), H(0, 0.0, 0.0)])], 
		[0.9, M([rest(), _attention()])], 
	], 0.05, false))}


	c["xray"] = {"len": 1.2, "in": 0.03, "out": 0.14, "face": "focus", "lid": 0.25, "keys": _weave(_steps(
		M([R(0.4, -0.91, 0.0), WR(0.0), FLR(0.0, 0.0), H(0, 0, 0), B(0.0), C(0.0), HD(0.0), {"curl": 0.05}]), [
		[0.1, M([FLR(0.07, 0.0), H(0, -0.08, 0.0), B(0.06, 0.22), C(0.0, 0.3), HD(-0.04, 0.2), Rt(0.38, 0.5, 0.25, 0.9), WR(0.0, 0.0, -1.0), {"curl": 1.0, "gesture": "point", "fx": "scan glint"}]), M([HD(-0.04, 0.28)])], 
		[0.42, M([B(0.06, 0.0), C(0.0, 0.0), HD(-0.04, 0.0), {"fx": "scan"}]), M([HD(-0.04, -0.07)])], 
		[0.74, M([B(0.06, -0.22), C(0.0, -0.3), HD(-0.04, -0.2), {"fx": "scan"}]), M([HD(-0.04, -0.28)])], 
		[1.02, M([B(0.0, 0.0), C(0.0), HD(0.08, 0.0), Rt(0.5, 0.42, 0.55, 0.5), WR(0.0)])], 
		[1.1, M([FLR(0.0, 0.0), H(0, 0, 0), HD(0.0), R(0.4, -0.91, 0.0), {"curl": 0.05, "gesture": ""}])], 
		[1.2, M([rest(), R(0.4, -0.91, 0.0)])], 
	]), [
		[0.0, M([L(0.4, -0.91, 0.0), WL(0.0), {"curl_l": 0.05}]), "l"], 
		[0.1, M([L(0.85, -0.12, 0.5), WL(0.3), {"curl_l": 0.0}]), "l"], 
		[0.98, M([L(-0.45, -0.12, 0.88), WL(0.3)]), "l"], 
		[1.08, M([L(0.4, -0.91, 0.0), WL(0.0), {"curl_l": 0.05}]), "h"], 
	])}



	c["eat_drone"] = {"len": 0.9, "in": 0.03, "out": 0.14, "face": "focus", "keys": [
		[0.0, M([LR(0.4, -0.91, 0.0), H(0, 0, 0), B(0.0), C(0.0), HD(0.0), SH(0.0), {"curl": 0.0, "jaw": 0.0, "chatter": 0.0, "sq": 1.0}])], 
		[0.06, M([H(0, -0.18, 0.14), B(0.48), C(0.12), HD(0.1), L(-0.22, -0.6, 0.72, 0.3), R(-0.22, -0.64, 0.72, 0.3), {"sq": 0.94}]), "s"], 
		[0.1, {"curl": 1.0, "fx": "spark_r"}], 
		[0.19, M([H(0, -0.03, 0.0), B(0.0), C(0.08), HD(-0.3), LRt(-0.2, 0.3, 0.62, 0.1), {"sq": 1.03, "jaw": 1.0}])], 
		[0.22, {"jaw": 0.0, "sq": 0.97}], 
		[0.28, M([C(-0.2), HD(0.5), LRt(-0.2, 0.0, 0.8, 0.1), {"sq": 1.02, "fx": "crumbs", "ev": "effort"}])], 
		[0.34, M([C(0.08), HD(-0.3), LRt(-0.2, 0.3, 0.62, 0.1), {"sq": 1.0, "jaw": 1.0}])], 
		[0.37, {"jaw": 0.0, "sq": 0.97}], 
		[0.43, M([C(-0.2), HD(0.5), LRt(-0.2, 0.0, 0.8, 0.1), {"sq": 1.02, "chatter": 1.0, "fx": "crumbs"}])], 
		[0.53, M([H(0, 0, 0), C(-0.1), HD(0.42), LRt(0.0, -0.2, 0.55, 0.2), {"curl": 0.0, "sq": 1.0}])], 
		[0.62, M([C(0.0), HD(0.1, 0.0, 0.42), LRt(0.14, -0.5, 0.3, 0.2), SH(0.8), {"chatter": 0.0, "face": "smile", "fx": "sparkle"}]), "s"], 
		[0.8, M([HD(0.1, 0.0, 0.42), LRt(0.14, -0.5, 0.3, 0.2), SH(0.8)]), "h"], 
		[0.9, M([rest(), _attention(), SH(0.0), {"jaw": 0.0}])], 
	]}





static func _hug(index: int) -> Dictionary:
	match index:
		0: return M([H(0, -0.2, 0.22), B(0.36, 0.0), C(0.06, 0.0), HD(0.3, 0.0), L(-0.36, -0.08, 0.74, 0.9), R(-0.36, -0.2, 0.74, 0.9), {"shake": 0.85}])
		1: return M([H(0, -0.14, 0.18), B(0.28, 0.0), C(-0.04, 0.0), HD(0.36, 0.0), L(-0.18, -0.06, 0.8, 0.8), R(-0.18, -0.18, 0.8, 0.8), {"shake": 0.85}])
		2: return M([H(0, -0.3, 0.28), B(0.5, 0.14), C(0.14, 0.1), HD(0.32, -0.2), L(-0.5, -0.2, 0.66, 1.0), R(-0.5, -0.36, 0.66, 1.0), {"shake": 1.0}])
	return M([H(0, -0.3, 0.28), B(0.5, -0.14), C(0.14, -0.1), HD(0.32, 0.2), L(-0.5, -0.36, 0.66, 1.0), R(-0.5, -0.2, 0.66, 1.0), {"shake": 1.0}])

static func _states(c: Dictionary) -> void :




	c["overheat_dash"] = {"len": 0.44, "loop": true, "loop_from": 0.12, "in": 0.03, "face": "angry", "keys": _weave([
		[0.0, M([H(0, -0.14, 0.2), B(1.1), C(0.05), HD(-0.2), L(0.24, 0.1, 0.97), R(0.24, 0.06, 0.97), WL(0.0), WR(0.0), {"curl": 1.0, "shake": 0.5, "sq": 0.84}])], 
		[0.12, M([H(0, -0.1, 0.15), B(1.3, 0.0, 0.05), HD(0.18), L(0.2, 0.25, 0.97), R(0.24, 0.21, 0.97)]), "s"], 
		[0.28, M([H(0, -0.13, 0.15), B(1.34, 0.0, -0.05), HD(0.24), L(0.24, 0.21, 0.97), R(0.2, 0.25, 0.97)]), "s"], 
		[0.44, M([H(0, -0.1, 0.15), B(1.3, 0.0, 0.05), HD(0.18), L(0.2, 0.25, 0.97), R(0.24, 0.21, 0.97)]), "s"], 
	], _weave([[0.13, {"fx": "steam whoosh"}]], _hum(0.12, 0.44, 0.04, 0.012, [], 0.93)))}




	c["overheat_hold"] = {"len": 1.2, "loop": true, "loop_from": 0.2, "in": 0.03, "face": "angry", "keys": _weave([
		[0.0, M([FL(0.08, 0.34), FR(0.14, -0.3), H(0, -0.16, 0.18), B(0.3), C(-0.06), HD(0.2), L(0.85, 0.05, 0.5, 0.6), R(0.85, 0.0, 0.5, 0.6), WL(0.0), WR(0.0), {"curl": 0.0, "shake": 0.4, "fp_r": -0.5, "sq": 1.06, "gait": 0.0}])], 
		[0.12, M([H(0, -0.12, 0.12), B(0.22), C(-0.12), HD(0.24), L(0.98, 0.1, 0.36, 0.6), R(0.98, 0.05, 0.36, 0.6), {"sq": 1.08}]), "s"], 
		[0.2, M([_hug(2), {"curl": 0.9, "ev": "grunt"}]), "s"], 
		[0.21, {"fx": "pop_front volt steam"}], 
		[0.3, _hug(0)], 
		[0.62, _hug(1), "s"], 
		[0.7, M([_hug(3), {"fx": "steam volt"}]), "s"], 
		[0.8, _hug(0)], 
		[1.12, _hug(1), "s"], 
		[1.2, _hug(2), "s"], 
	], _hum(0.2, 1.2, 0.04, 0.012, [0.2, 0.7, 1.2]))}






	c["plugged"] = {"len": 2.7, "loop": true, "loop_from": 0.7, "in": 0.05, "face": "focus", "keys": [
		[0.0, M([LR(0.4, -0.91, 0.0), H(0, 0, 0), B(0.0), C(0.0), HD(0.0), SH(0.0), FL(0.0, 0.0), FR(0.0, 0.0), {"fp_l": 0.0, "curl": 0.05, "curl_l": 0.05, "shake": 0.0, "sq": 1.0, "gait": 0.0}])], 
		[0.12, M([H(0, -0.06, -0.03), B(-0.1, -0.25, 0.08), C(0.0, 0.75, 0.1), HD(-0.2, 0.6), L(-0.15, -0.86, -0.52), R(0.25, -0.5, 0.55), {"curl_l": 0.0}]), "s"], 
		[0.2, M([L(-0.15, -0.84, -0.56), {"curl_l": 1.0}])], 
		[0.44, M([H(0.0, -0.53, 0.0), FL(0.0, -0.5, 0.09), FR(0.05, 0.45), B(0.14, 0.1, 0.0), C(0.05, 0.5, 0.12), HD(-0.3, 0.5), L(0.35, -1.0, -0.42), R(-0.12, -0.34, 0.72), {"fp_l": -1.2, "curl": 0.15, "sq": 0.93, "shake": 0.8}]), "s"], 
		[0.45, {"fx": "spark_l"}], 
		[0.5, {"sq": 1.03, "shake": 0.3}], 
		[0.7, M([_kneel(false), {"curl": 0.15, "curl_l": 0.15, "shake": 0.0, "face": "asleep"}]), "s"], 
		[1.7, _kneel(true), "s"], 
		[1.75, M([HD(-0.38), SH(1.0), {"sq": 0.96, "shake": 0.9, "fx": "spark_l volt"}])], 
		[1.83, M([HD(-0.2), SH(0.6), {"sq": 1.01}])], 
		[1.96, {"shake": 0.0}], 
		[2.7, _kneel(false), "s"], 
	]}





	c["stunned@Lysia"] = {"len": 2.02, "loop": true, "loop_from": 0.42, "in": 0.03, "face": "dazed", "keys": _weave(_steps(
		M([FLR(0.0, 0.0), H(0, 0, 0), B(0.0), C(0.0), HD(0.0), AL(0.0, 0.41, 0.0), AR(0.0, 0.41, 0.0), WL(0.0), WR(0.0), {"curl": 0.05, "curl_l": 0.05, "sq": 1.0, "fp_l": 0.0, "fp_r": 0.0}]), [
		[0.05, M([FLR(0.1, 0.0), H(0, 0.03, -0.06), B(-0.2), C(-0.25), HD(0.5, 0.0, 0.1), AL(0.0, 1.25, 0.0), AR(0.0, 1.4, 0.0), {"curl": 0.0, "curl_l": 0.0, "sq": 1.08, "fp_l": -0.4, "fp_r": -0.4, "fx": "stars volt"}])], 
		[0.26, M([H(0, -0.16, 0.02), B(0.2), C(0.35), HD(-0.6), AL(0.25, 0.1, 0.1), AR(0.25, 0.1, 0.1), {"curl": 0.3, "curl_l": 0.3, "sq": 0.94, "fp_l": 0.0, "fp_r": 0.0}])], 
		[0.42, _broken(0)], 
		[0.62, M([HD(-0.05, 0.2, 0.64), AR( - RIGHT, 1.45, 0.9)])], 
		[0.68, M([HD(-0.05, 0.2, 0.5), AR( - RIGHT, 1.45, 1.45)])], 
		[0.82, M([_broken(1), {"fx": "volt spark_l"}])], 
		[1.02, M([HD(-0.4, -0.3, -0.56), AL(0.9, 0.3, 1.1)])], 
		[1.08, M([HD(-0.4, -0.3, -0.42), AL(0.9, 0.3, RIGHT)])], 
		[1.22, M([_broken(2), {"fx": "volt"}])], 
		[1.42, M([AR(1.3, 0.1, 0.0), HD(-0.62, 0.0, -0.1)])], 
		[1.48, M([AR(1.0, 0.1, 0.0), HD(-0.5, 0.0, 0.0)])], 
		[1.62, M([_broken(3), {"fx": "volt spark_r"}])], 
		[1.82, M([AR( - RIGHT, 1.9, 1.2), HD(0.38, -0.12, 0.28)])], 
		[1.88, M([AR( - RIGHT, 1.9, 0.5), HD(0.38, -0.12, 0.42)])], 
		[2.02, _broken(0)], 
	], 0.04), _weave([[0.0, {"shake": 0.0}, "l"], [0.05, {"shake": 1.0}, "l"], [0.26, {"shake": 0.2}, "h"]], _bursts([0.42, 0.82, 1.22, 1.62, 2.02], 0.2, 2.02)))}



static func _kneel(charged: bool) -> Dictionary:
	if charged: return M([H(0.0, -0.5, 0.0), B(0.34, 0.0, 0.0), C(-0.02, -0.12, 0.0), HD(-0.14, 0.0), SH(0.5), R(-0.12, -0.46, 0.8), L(-0.44, -0.39, 0.78), {"sq": 1.03, "shake": 0.0}])
	return M([H(0.0, -0.53, 0.0), B(0.44, 0.0, 0.0), C(0.08, -0.12, 0.0), HD(-0.48, 0.0), SH(0.0), R(-0.12, -0.37, 0.74), L(-0.44, -0.3, 0.72), {"sq": 1.0, "shake": 0.0}])


static func _broken(index: int) -> Dictionary:
	match index:
		0: return M([H(0.05, -0.1, 0.0), B(0.04, 0.0, -0.1), C(0.08, 0.12, -0.12), HD(-0.05, 0.2, 0.5), AR( - RIGHT, 1.45, 1.45), WR(-0.9), AL(0.12, 0.08, 0.15), WL(0.0), {"curl": 0.2, "curl_l": 0.4, "sq": 1.0}])
		1: return M([H(-0.06, -0.16, -0.06), B(-0.2, 0.0, 0.12), C(-0.12, -0.16, 0.12), HD(-0.4, -0.3, -0.42), AR(0.35, 0.15, 0.1), WR(0.0), AL(0.9, 0.3, RIGHT), WL(-1.2), {"curl": 0.5, "curl_l": 0.0, "sq": 1.0}])
		2: return M([H(0.0, -0.05, -0.14), B(0.75, 0.0, 0.0), C(0.3, 0.0, 0.0), HD(-0.5, 0.0, 0.0), AR(1.0, 0.1, 0.0), WR(0.0), AL(1.05, 0.12, 0.0), WL(0.0), {"curl": 0.3, "curl_l": 0.3, "sq": 1.0}])
	return M([H(0.06, -0.02, 0.02), B(-0.12, -0.2, 0.08), C(-0.14, -0.2, -0.06), HD(0.38, -0.12, 0.42), AR( - RIGHT, 1.9, 0.5), WR(0.9), AL(0.5, -0.4, 1.8), WL(0.0), {"curl": 0.0, "curl_l": 0.6, "sq": 1.0}])



static func _personality(c: Dictionary) -> void :



	c["fidget@Lysia"] = {"len": 3.2, "in": 0.12, "out": 0.2, "face": "focus", "keys": _steps(
		M([LR(0.4, -0.91, 0.0), WL(0.0), WR(0.0), B(0.0), C(0.0), HD(0.0), SH(0.0), {"curl": 0.05, "curl_l": 0.05, "sq": 1.0}]), [
		[0.24, HD(0.0, 0.7), HD(0.0, 0.78)], 
		[0.66, HD(0.0, -0.7), HD(0.0, -0.78)], 
		[1.08, M([HD(-0.3, -0.3, -0.1), C(0.04, -0.12), R(0.25, 0.0, 0.8, 0.2), WR(0.4), {"curl": 0.0}])], 
		[1.3, {"curl": 1.1}], 
		[1.5, {"curl": 0.0}], 
		[1.7, {"curl": 1.1}], 
		[1.9, {"curl": 0.0}], 
		[2.06, HD(-0.44, -0.3, -0.1)], 
		[2.16, HD(-0.3, -0.3, -0.1)], 
		[2.3, WR(0.4, -2.6)], 
		[2.44, WR(0.4, 0.0)], 
		[2.58, M([R(0.4, -0.91, 0.0), WR(0.0), HD(0.0), C(0.0), {"curl": 0.05}])], 
		[2.76, M([SH(1.0), LR(0.5, -0.85, 0.0), {"sq": 1.04}])], 
		[2.96, M([SH(0.0), LR(0.4, -0.91, 0.0), {"sq": 1.0, "fx": "steam"}]), M([SH(-0.3), {"sq": 0.97}])], 
		[3.2, M([rest(), _attention()])], 
	])}


	c["wave@Lysia"] = {"len": 2.3, "in": 0.08, "out": 0.12, "face": "neutral", "keys": _steps(
		M([AR(0.0, 0.41, 0.0), WR(0.0), L(0.4, -0.91, 0.0), WL(0.0), B(0.0), C(0.0), HD(0.0), {"curl": 0.05}]), [
		[0.14, AR(RIGHT, RIGHT, 0.0)], 
		[0.3, AR(RIGHT, RIGHT, RIGHT)], 
		[0.5, M([AR(RIGHT, RIGHT, 1.0), HD(0.0, 0.0, -0.14)]), AR(RIGHT, RIGHT, 0.9)], 
		[0.7, M([AR(RIGHT, RIGHT, 1.85), HD(0.0, 0.0, 0.14)]), AR(RIGHT, RIGHT, 1.95)], 
		[0.9, M([AR(RIGHT, RIGHT, 1.0), HD(0.0, 0.0, -0.14)]), AR(RIGHT, RIGHT, 0.9)], 
		[1.1, M([AR(RIGHT, RIGHT, 1.85), HD(0.0, 0.0, 0.14)]), AR(RIGHT, RIGHT, 1.95)], 
		[1.3, M([AR(RIGHT, RIGHT, 1.0), HD(0.0, 0.0, -0.14)]), AR(RIGHT, RIGHT, 0.9)], 
		[1.5, M([AR(RIGHT, RIGHT, 1.85), HD(0.0, 0.0, 0.14)]), AR(RIGHT, RIGHT, 1.95)], 
		[1.72, M([AR(RIGHT, RIGHT, RIGHT), HD(0.0, 0.0, 0.0), {"face": "smile"}])], 
		[2.02, AR(RIGHT, RIGHT, 0.0)], 
		[2.16, AR(0.0, 0.41, 0.0)], 
		[2.3, M([rest(), {"face": "neutral"}])], 
	])}


	c["thumbsup@Lysia"] = {"len": 2.1, "in": 0.08, "out": 0.12, "face": "neutral", "keys": _steps(
		M([R(0.4, -0.91, 0.0), WR(0.0), L(0.4, -0.91, 0.0), WL(0.0), B(0.0), C(0.0), HD(0.0), {"curl": 0.05, "curl_l": 0.05}]), [
		[0.14, M([Rt(0.2, -0.55, -0.15, 0.3), C(0.0, -0.25), {"curl": 1.0}])], 
		[0.32, M([R(0.62, 0.62, 0.48), WR(0.0, - RIGHT, -0.6), C(0.0, 0.2), B(0.0, 0.1), HD(0.05, -0.2), {"gesture": "thumbsup", "fx": "glint"}]), M([R(0.64, 0.7, 0.4)])], 
		[1.2, {"face": "smile"}], 
		[1.6, M([Rt(0.2, -0.3, 0.55, 0.1), WR(0.0), C(0.0, 0.0), B(0.0, 0.0), HD(0.0, 0.0)])], 
		[1.76, M([R(0.4, -0.91, 0.0), {"curl": 0.05, "gesture": ""}])], 
		[2.1, M([rest(), {"face": "neutral"}])], 
	])}


	c["laugh@Lysia"] = {"len": 2.2, "in": 0.08, "out": 0.12, "face": "neutral", "keys": _steps(
		M([LR(0.4, -0.91, 0.0), WL(0.0), WR(0.0), H(0, 0, 0), B(0.0), C(0.0), HD(0.0), SH(0.0), {"curl": 0.05, "jaw": 0.0, "sq": 1.0, "fp_l": 0.0, "fp_r": 0.0}]), [
		[0.16, M([LRt(0.05, -0.68, 0.15, 0.5), {"curl": 1.0}])], 
		[0.38, _ha(true)], [0.54, _ha(false)], 
		[0.7, _ha(true)], [0.86, _ha(false)], 
		[1.02, _ha(true)], [1.18, M([_ha(false), {"face": "neutral"}])], 
		[1.6, HD(0.0, 0.0, 0.34)], 
		[1.9, M([HD(0.0), C(0.0), H(0, 0, 0), LR(0.4, -0.91, 0.0), {"curl": 0.05}])], 
		[2.2, M([rest(), {"jaw": 0.0}])], 
	], 0.05)}


	c["shrug@Lysia"] = {"len": 2.1, "in": 0.08, "out": 0.12, "face": "surprise", "keys": _steps(
		M([LR(0.4, -0.91, 0.0), WL(0.0), WR(0.0), B(0.0), C(0.0), HD(0.0), SH(0.0), {"curl": 0.05}]), [
		[0.16, M([LRt(0.62, -0.3, 0.42, 0.0), WL(0.0, 2.9), WR(0.0, -2.9), C(0.0, 0.0, -0.08), HD(0.0, 0.0, 0.45), SH(1.0), {"curl": 0.0}])], 
		[0.9, M([C(0.0, 0.0, 0.08), HD(0.0, 0.0, -0.45), {"fx": "steam"}])], 
		[1.56, M([C(0.0), HD(0.0), LR(0.4, -0.91, 0.0), WL(0.0), WR(0.0), SH(0.0), {"curl": 0.05}])], 
		[2.1, rest()], 
	])}


	c["cheer@Lysia"] = {"len": 2.3, "in": 0.06, "out": 0.12, "face": "grin", "keys": _weave(_steps(
		M([LR(0.4, -0.91, 0.0), WL(0.0), WR(0.0), H(0, 0, 0), HD(0.0), {"curl": 0.05, "sq": 1.0, "feet": V(0, 0, 0)}]), [
		[0.12, M([H(0, -0.12, 0.0), LR(0.3, -0.9, -0.3), {"sq": 0.92}])], 
		[0.26, M([H(0, 0.14, 0.0), LR(0.5, 0.86, 0.0), {"sq": 1.08, "feet": V(0, 0.14, 0), "fx": "dust"}])], 
		[0.42, M([H(0, -0.08, 0.0), LR(0.75, 0.6, 0.1, 0.4), {"sq": 0.94, "feet": V(0, 0, 0)}])], 
		[0.58, M([H(0, 0.14, 0.0), LR(0.5, 0.86, 0.0), {"sq": 1.08, "feet": V(0, 0.14, 0), "fx": "dust"}])], 
		[0.74, M([H(0, -0.08, 0.0), LR(0.75, 0.6, 0.1, 0.4), {"sq": 0.94, "feet": V(0, 0, 0)}])], 
		[0.9, M([H(0, 0.16, 0.0), LR(0.5, 0.86, 0.0), {"sq": 1.1, "feet": V(0, 0.16, 0), "fx": "dust sparkle"}])], 
		[1.06, M([H(0, 0, 0), {"sq": 1.0, "feet": V(0, 0, 0)}])], 
		[1.9, M([LR(0.4, -0.91, 0.0)])], 
		[2.3, rest()], 
	]), [
		[0.0, {"turn": 0.0}, "h"], 
		[1.06, {"turn": 0.0}, "l"], 
		[1.66, {"turn": 6.283}, "h"], 
		[1.68, {"turn": 0.0}, "h"], 
	])}



static func _point(c: Dictionary) -> void :
	c["point@Lysia"] = {"len": 2.0, "in": 0.08, "out": 0.12, "face": "focus", "keys": _steps(
		M([R(0.4, -0.91, 0.0), WR(0.0), L(0.4, -0.91, 0.0), WL(0.0), FL(0.0, 0.0), FR(0.0, 0.0), H(0, 0, 0), B(0.0), C(0.0), HD(0.0), {"curl": 0.05, "curl_l": 0.05}]), [
		[0.12, M([Rt(0.15, -0.3, 0.3, 0.5), C(0.0, -0.2), {"curl": 1.0}])], 
		[0.28, M([FR(0.04, 0.22), FL(0.06, -0.12), H(0, -0.06, 0.06), B(0.04, 0.5), C(0.0, 0.25), HD(0.0, -0.4), R(-0.1, 0.06, 1.0), L(0.35, -0.9, -0.25), {"gesture": "point", "curl_l": 1.0, "fx": "glint"}]), M([R(-0.1, 0.14, 1.0)])], 
		[0.5, HD(0.0, -0.72), HD(0.0, -0.8)], 
		[0.9, R(-0.1, 0.16, 1.0)], 
		[0.98, R(-0.1, 0.06, 1.0)], 
		[1.14, R(-0.1, 0.16, 1.0)], 
		[1.22, R(-0.1, 0.06, 1.0)], 
		[1.6, M([FR(0.0, 0.0), FL(0.0, 0.0), H(0, 0, 0), B(0.0), C(0.0), HD(0.0), Rt(0.15, -0.3, 0.45, 0.2)])], 
		[1.74, M([R(0.4, -0.91, 0.0), L(0.4, -0.91, 0.0), {"curl": 0.05, "curl_l": 0.05, "gesture": ""}])], 
		[2.0, rest()], 
	])}


static func _ha(up: bool) -> Dictionary:
	if up: return M([H(0, 0.04, -0.03), B(-0.12), C(-0.3), HD(0.5), SH(0.8), {"jaw": 1.0, "sq": 1.04, "fp_l": -0.35, "fp_r": -0.35, "face": "laugh"}])
	return M([H(0, -0.03, 0.0), B(0.0), C(0.08), HD(-0.1), SH(0.0), {"jaw": 0.0, "sq": 1.0, "fp_l": 0.0, "fp_r": 0.0}])
