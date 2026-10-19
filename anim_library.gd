extends RefCounted










const AnimClip = preload("res://anim_clip.gd")

const SETS: Array[String] = ["common", "emotes", "usayuko", "ashura", "simon", "lysia", "elly", "bleuette", "alice", "trueform", "extra", "kills", "emotes_plus", "tiktok",
	"film_alice"]

static var _cache: Dictionary = {}
static var _all: Dictionary = {}
static var _owner: Dictionary = {}

static func clip(clip_name: String, person: String = "") -> Dictionary:
	var key: String = clip_name + "@" + person
	if _cache.has(key): return _cache[key]
	if _all.is_empty(): _all = _sources()
	var source: Dictionary = {}
	if _all.has(key): source = _all[key]
	elif _all.has(clip_name): source = _all[clip_name]
	if HEAD_CLEAR.has(person) and not source.is_empty(): source = _clear_head(source, float(HEAD_CLEAR[person]))
	var compiled: Dictionary = {} if source.is_empty() else AnimClip.compile(source)
	_cache[key] = compiled
	return compiled



const HEAD_CLEAR: Dictionary = {"Simon": 1.0}

static func _clear_head(source: Dictionary, amount: float) -> Dictionary:
	var result: Dictionary = source.duplicate()
	var keys: Array = []
	for key: Array in source.get("keys", []):
		var pose: Dictionary = (key[1] as Dictionary).duplicate()
		for side: String in ["ik_l", "ik_r"]:
			if not pose.has(side) or not pose[side] is Vector3: continue
			var v: Vector3 = pose[side]
			var sgn: float = -1.0 if side == "ik_l" else 1.0
			if v.y > 0.25 and - v.z < 0.55:
				var need: float = minf(0.3 + (v.y - 0.25) * 0.8, 0.85) * amount
				if v.x * sgn < need: pose[side] = Vector3(need * sgn, v.y, v.z)
		var copy: Array = key.duplicate()
		copy[1] = pose
		keys.append(copy)
	result["keys"] = keys
	return result

static func has_clip(clip_name: String, person: String = "") -> bool:
	if _all.is_empty(): _all = _sources()
	return _all.has(clip_name) or ( not person.is_empty() and _all.has(clip_name + "@" + person))


static func names() -> PackedStringArray:
	if _all.is_empty(): _all = _sources()
	return PackedStringArray(_all.keys())


static func source(full_name: String) -> Dictionary:
	if _all.is_empty(): _all = _sources()
	return _all.get(full_name, {})

static func _sources() -> Dictionary:
	var c: Dictionary = {}
	for set_name: String in SETS:
		var path: String = "res://anim_set_%s.gd" % set_name
		if not ResourceLoader.exists(path): continue
		var set_script: Variant = load(path)

		if set_script == null or not (set_script as GDScript).can_instantiate(): continue
		var before: Dictionary = c.duplicate()
		set_script.add(c)
		for clip_name: String in c:
			if not before.has(clip_name) or not is_same(before[clip_name], c[clip_name]): _owner[clip_name] = set_name
	return c


static func set_of(full_name: String) -> String:
	if _all.is_empty(): _all = _sources()
	return str(_owner.get(full_name, ""))
