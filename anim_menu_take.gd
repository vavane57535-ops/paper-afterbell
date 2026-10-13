extends "res://anim_pose.gd"

# Outils d'écriture des clips de l'écran titre (anim_set_menu.gd).
#
# Take : une prise (un clip) qu'on écrit pose par pose. Chaque pose est datée et répartie
# sur ses canaux avec un léger décalage selon un « profil » de chevauchement :
#   follow : le bassin part, le buste suit, la tête puis les mains et les doigts arrivent après ;
#   lead   : le regard et le visage partent d'abord (on regarde avant de bouger) ;
#   heavy  : comme follow, en plus traînant (corps lourd, fatigue, peur qui retombe) ;
#   snap   : réflexe, presque tout ensemble ; sync : tout au même instant.
# Drapeaux : "" (passe sans s'arrêter), "s" (s'arrête net sur la clé), "h" (tient jusqu'à la clé
# suivante), "l" (linéaire). Les canaux non repris gardent leur dernière valeur.

const CHANNEL_GROUP: Dictionary = {
	"hips": "root", "body": "root", "foot_l": "root", "foot_r": "root", "fp_l": "root", "fp_r": "root",
	"turn": "root", "plant": "root", "gsnap": "root", "gclamp": "root", "sq": "root", "gait": "root", "feet": "root",
	"l_leg": "root", "r_leg": "root", "l_knee": "root", "r_knee": "root", "l_ank": "root", "r_ank": "root",
	"chest": "chest", "l_clav": "chest", "r_clav": "chest",
	"head": "head",
	"ik_l": "arms", "ik_r": "arms", "el_l": "arms", "el_r": "arms", "tf_l": "arms", "tf_r": "arms", "gr_l": "arms", "gr_r": "arms",
	"l_hand": "arms", "r_hand": "arms", "l_arm": "arms", "r_arm": "arms", "l_elb": "arms", "r_elb": "arms", "ikw_l": "arms", "ikw_r": "arms",
	"curl": "fingers", "curl_l": "fingers", "gesture": "fingers",
	"face": "face", "jaw": "face", "chatter": "face", "shake": "face",
	"ev": "cue", "fx": "cue", "prop": "cue",
}
const PROFILES: Dictionary = {
	"follow": {"root": 0.0, "chest": 0.035, "head": 0.08, "arms": 0.06, "fingers": 0.11, "face": 0.0, "cue": 0.0},
	"lead": {"root": 0.0, "chest": -0.03, "head": -0.1, "arms": 0.03, "fingers": 0.08, "face": -0.12, "cue": 0.0},
	"heavy": {"root": 0.0, "chest": 0.06, "head": 0.14, "arms": 0.1, "fingers": 0.16, "face": 0.02, "cue": 0.0},
	"snap": {"root": 0.0, "chest": 0.015, "head": 0.035, "arms": 0.025, "fingers": 0.05, "face": 0.0, "cue": 0.0},
	"sync": {"root": 0.0, "chest": 0.0, "head": 0.0, "arms": 0.0, "fingers": 0.0, "face": 0.0, "cue": 0.0},
}

class Take:
	var length: float = 1.0
	var face: String = "neutral"
	var rows: Array = []
	var state: Dictionary = {}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var lag_scale: float = 1.0
	var _order: int = 0

	func _init(clip_length: float, base_face: String = "neutral", seed_value: int = 1) -> void :
		length = clip_length
		face = base_face
		rng.seed = seed_value

	# Pose datée, répartie sur ses canaux selon le profil de chevauchement.
	func at(t: float, pose: Dictionary, profile: String = "follow", flag: String = "") -> Take:
		var lags: Dictionary = PROFILES.get(profile, PROFILES.follow)
		for channel: String in pose:
			var group: String = CHANNEL_GROUP.get(channel, "root")
			var when: float = t + float(lags.get(group, 0.0)) * lag_scale
			if group == "cue" or group == "face": when = t + float(lags.get(group, 0.0))
			rows.append([clampf(when, 0.0, length), _order, channel, pose[channel], flag])
			_order += 1
			state[channel] = pose[channel]
		return self

	# Clé brute, sans chevauchement.
	func key(t: float, pose: Dictionary, flag: String = "") -> Take:
		return at(t, pose, "sync", flag)

	# Pose relative à l'état courant (valeurs ajoutées à la dernière pose écrite).
	func rel(t: float, delta: Dictionary, profile: String = "follow", flag: String = "") -> Take:
		var pose: Dictionary = {}
		for channel: String in delta:
			var base: Variant = state.get(channel, null)
			var change: Variant = delta[channel]
			if base == null or change is String: pose[channel] = change
			elif base is Vector3 and (change is float or change is int): pose[channel] = (base as Vector3) + Vector3(float(change), 0.0, 0.0)
			elif (base is float or base is int) and change is Vector3: pose[channel] = Vector3(float(base), 0.0, 0.0) + (change as Vector3)
			else: pose[channel] = base + change
		return at(t, pose, profile, flag)

	# Tenue vivante : le corps ne se fige jamais (respiration, poids, tête qui dérive).
	func hold(t0: float, t1: float, amount: float = 1.0, profile: String = "heavy") -> Take:
		var span: float = t1 - t0
		if span < 0.7: return self
		var count: int = maxi(1, floori(span / 1.05))
		var base: Dictionary = {}
		for channel: String in ["hips", "chest", "head"]:
			if state.has(channel): base[channel] = state[channel]
		for i: int in range(count):
			var t: float = t0 + span * (float(i) + 0.55 + rng.randf_range(-0.12, 0.12)) / float(count + 0.35)
			var pose: Dictionary = {}
			if base.has("chest"): pose["chest"] = (base.chest as Vector3) + Vector3(rng.randf_range(-0.02, 0.025), rng.randf_range(-0.025, 0.025), rng.randf_range(-0.015, 0.015)) * amount
			if base.has("head"): pose["head"] = (base.head as Vector3) + Vector3(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.05, 0.05), rng.randf_range(-0.03, 0.03)) * amount
			if base.has("hips"): pose["hips"] = (base.hips as Vector3) + Vector3(rng.randf_range(-0.008, 0.008), rng.randf_range(-0.006, 0.004), 0.0) * amount
			at(t, pose, profile)
		var back: Dictionary = {}
		for channel: String in base: back[channel] = base[channel]
		at(t1, back, profile, "s")
		return self

	func clip(extra: Dictionary = {}) -> Dictionary:
		var sorted: Array = rows.duplicate()
		sorted.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]) or (is_equal_approx(float(a[0]), float(b[0])) and int(a[1]) < int(b[1])))
		# Deux clés du même canal presque au même instant : la dernière écrite gagne.
		var last: Dictionary = {}
		var keep: Array = []
		for row: Array in sorted:
			var channel: String = row[2]
			if last.has(channel):
				var previous: Array = keep[int(last[channel])]
				if float(row[0]) - float(previous[0]) < 0.006 and not (row[3] is String):
					keep[int(last[channel])] = []
			last[channel] = keep.size()
			keep.append(row)
		var keys: Array = []
		var current_time: float = -1.0
		var current_flag: String = "?"
		var current: Dictionary = {}
		for row: Array in keep:
			if row.is_empty(): continue
			var time: float = snappedf(float(row[0]), 0.0001)
			var flag: String = row[4]
			if time != current_time or flag != current_flag or current.has(row[2]):
				if not current.is_empty(): keys.append([current_time, current, current_flag] if current_flag != "" else [current_time, current])
				current = {}
				current_time = time
				current_flag = flag
			current[row[2]] = row[3]
		if not current.is_empty(): keys.append([current_time, current, current_flag] if current_flag != "" else [current_time, current])
		var result: Dictionary = {"len": length, "in": 0.0, "out": 0.0, "face": face, "keys": keys}
		result.merge(extra, true)
		return result


# --- Raccourcis de pose ---------------------------------------------------------

static func TL(fwd: float, out: float = 0.0, yaw: float = 0.0) -> Dictionary:
	return {"l_leg": Vector3(fwd, yaw, - out)}

static func TR(fwd: float, out: float = 0.0, yaw: float = 0.0) -> Dictionary:
	return {"r_leg": Vector3(fwd, - yaw, out)}

static func KL(bend: float, ankle: float = 0.0) -> Dictionary:
	return {"l_knee": - bend, "l_ank": ankle}

static func KR(bend: float, ankle: float = 0.0) -> Dictionary:
	return {"r_knee": - bend, "r_ank": ankle}

static func F(mood: String) -> Dictionary:
	return {"face": mood}

static func CU(right: float, left: float = -1.0) -> Dictionary:
	return {"curl": right, "curl_l": right if left < 0.0 else left}

# Début de tout clip de menu : pieds plantés, pas d'allure du jeu, pas de rotation ajoutée.
static func start() -> Dictionary:
	return {"plant": 1.0, "gait": 0.0, "gsnap": 0.0, "turn": 0.0, "sq": 1.0, "jaw": 0.0, "shake": 0.0, "chatter": 0.0, "fp_l": 0.0, "fp_r": 0.0, "el_l": 0.0, "el_r": 0.0}

# Debout, bras le long du corps, mains détendues.
static func stand(width: float = 0.0) -> Dictionary:
	return M([rest(), start(), FL(0.02 + width, 0.0), FR(0.02 + width, 0.0), H(0, 0, 0), B(0.0), C(0.02), HD(0.0),
		L(0.2, -0.93, 0.04, 0.0), R(0.2, -0.93, 0.04, 0.0), WL(0.0), WR(0.0), CU(0.25)])
