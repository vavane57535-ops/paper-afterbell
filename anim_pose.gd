extends RefCounted































static func V(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y, z)

static func M(parts: Array) -> Dictionary:
	var result: Dictionary = {}
	for part: Dictionary in parts: result.merge(part, true)
	return result

static func L(out: float, up: float, fwd: float, flare: float = 0.0) -> Dictionary:
	return {"ik_l": Vector3( - out, up, - fwd), "el_l": flare, "tf_l": 0.0, "gr_l": 0.0}

static func R(out: float, up: float, fwd: float, flare: float = 0.0) -> Dictionary:
	return {"ik_r": Vector3(out, up, - fwd), "el_r": flare, "tf_r": 0.0, "gr_r": 0.0}

static func LR(out: float, up: float, fwd: float, flare: float = 0.0) -> Dictionary:
	return {"ik_l": Vector3( - out, up, - fwd), "el_l": flare, "tf_l": 0.0, "gr_l": 0.0, "ik_r": Vector3(out, up, - fwd), "el_r": flare, "tf_r": 0.0, "gr_r": 0.0}

static func Lt(out: float, up: float, fwd: float, flare: float = 0.0) -> Dictionary:
	return {"ik_l": Vector3( - out, up, - fwd), "el_l": flare, "tf_l": 1.0, "gr_l": 0.0}

static func Rt(out: float, up: float, fwd: float, flare: float = 0.0) -> Dictionary:
	return {"ik_r": Vector3(out, up, - fwd), "el_r": flare, "tf_r": 1.0, "gr_r": 0.0}

static func LRt(out: float, up: float, fwd: float, flare: float = 0.0) -> Dictionary:
	return {"ik_l": Vector3( - out, up, - fwd), "el_l": flare, "tf_l": 1.0, "gr_l": 0.0, "ik_r": Vector3(out, up, - fwd), "el_r": flare, "tf_r": 1.0, "gr_r": 0.0}

static func Lg(out: float, fwd: float, lift: float = 0.0) -> Dictionary:
	return {"ik_l": Vector3( - out, lift, - fwd), "el_l": 0.0, "tf_l": 0.0, "gr_l": 1.0}

static func Rg(out: float, fwd: float, lift: float = 0.0) -> Dictionary:
	return {"ik_r": Vector3(out, lift, - fwd), "el_r": 0.0, "tf_r": 0.0, "gr_r": 1.0}

static func WL(bend: float, twist: float = 0.0, side: float = 0.0) -> Dictionary:
	return {"l_hand": Vector3(bend, twist, side)}

static func WR(bend: float, twist: float = 0.0, side: float = 0.0) -> Dictionary:
	return {"r_hand": Vector3(bend, twist, side)}

static func FL(out: float, fwd: float, up: float = 0.0) -> Dictionary:
	return {"foot_l": Vector3( - out, up, - fwd)}

static func FR(out: float, fwd: float, up: float = 0.0) -> Dictionary:
	return {"foot_r": Vector3(out, up, - fwd)}

static func FLR(out: float, fwd: float, up: float = 0.0) -> Dictionary:
	return {"foot_l": Vector3( - out, up, - fwd), "foot_r": Vector3(out, up, - fwd)}

static func H(right: float, up: float, fwd: float) -> Dictionary:
	return {"hips": Vector3(right, up, - fwd)}

static func B(fwd: float, left: float = 0.0, tilt: float = 0.0) -> Dictionary:
	return {"body": Vector3( - fwd, left, tilt)}

static func C(fwd: float, left: float = 0.0, tilt: float = 0.0) -> Dictionary:
	return {"chest": Vector3( - fwd, left, tilt)}

static func HD(up: float, left: float = 0.0, tilt: float = 0.0) -> Dictionary:
	return {"head": Vector3(up, left, tilt)}

static func rest() -> Dictionary:
	return {"hips": Vector3.ZERO, "body": Vector3.ZERO, "chest": Vector3.ZERO, "head": Vector3.ZERO, "foot_l": Vector3.ZERO, "foot_r": Vector3.ZERO, "feet": Vector3.ZERO, "fp_l": 0.0, "fp_r": 0.0, "turn": 0.0, "sq": 1.0}
