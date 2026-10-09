extends RefCounted






























const ROTATION_CHANNELS: Array[String] = ["body", "chest", "head", "l_clav", "r_clav", "l_arm", "r_arm", "l_elb", "r_elb", "l_hand", "r_hand", "l_leg", "r_leg", "l_knee", "r_knee", "l_ank", "r_ank"]
const LEG_CHANNELS: Array[String] = ["l_leg", "r_leg", "l_knee", "r_knee", "l_ank", "r_ank"]
const STRING_CHANNELS: Array[String] = ["face", "prop", "ev", "gesture", "fx"]

const FLAG_SMOOTH: int = 0
const FLAG_STOP: int = 1
const FLAG_LINEAR: int = 2
const FLAG_HOLD: int = 3




static func compile(source: Dictionary) -> Dictionary:
	var clip: Dictionary = {
		"len": float(source.get("len", 1.0)), 
		"loop": bool(source.get("loop", false)), 
		"in": float(source.get("in", 0.12)), 
		"out": float(source.get("out", 0.2)), 
		"face": str(source.get("face", "")), 
		"lid": float(source.get("lid", 0.0)), 

		"add": bool(source.get("add", false)), 

		"loop_from": float(source.get("loop_from", 0.0)), 
		"channels": {}, 
		"strings": {}, 
		"legs": false, 
	}
	var channels: Dictionary = clip.channels
	var strings: Dictionary = clip.strings
	for key: Array in source.get("keys", []):
		var time: float = float(key[0])
		var pose: Dictionary = key[1]
		var flag: int = FLAG_SMOOTH
		if key.size() > 2:
			match str(key[2]):
				"s": flag = FLAG_STOP
				"l": flag = FLAG_LINEAR
				"h": flag = FLAG_HOLD
		for channel: String in pose:
			var value: Variant = pose[channel]
			if channel in STRING_CHANNELS:
				if not strings.has(channel): strings[channel] = []
				strings[channel].append([time, str(value)])
				continue
			if channel in ROTATION_CHANNELS and (value is float or value is int):
				value = Vector3(float(value), 0.0, 0.0)
			elif value is int:
				value = float(value)
			if not channels.has(channel):
				channels[channel] = {"t": PackedFloat32Array(), "v": [], "f": PackedByteArray(), "m": []}
			var track: Dictionary = channels[channel]
			track.t.append(time)
			track.v.append(value)
			track.f.append(flag)
			if channel in LEG_CHANNELS: clip.legs = true
	for channel: String in channels: _tangents(channels[channel], clip.loop and float(clip.loop_from) <= 0.0, clip.len)
	return clip

static func _tangents(track: Dictionary, loop: bool, length: float) -> void :
	var times: PackedFloat32Array = track.t
	var values: Array = track.v
	var flags: PackedByteArray = track.f
	var count: int = times.size()
	var tangents: Array = []
	tangents.resize(count)
	for i in range(count):
		var zero: Variant = values[i] * 0.0
		if flags[i] == FLAG_STOP or count < 2:
			tangents[i] = zero
			continue
		var prev: int = i - 1
		var next: int = i + 1
		var prev_time: float = 0.0
		var next_time: float = 0.0
		var prev_value: Variant = null
		var next_value: Variant = null
		if prev >= 0:
			prev_time = times[prev]
			prev_value = values[prev]
		elif loop:
			prev_time = times[count - 1] - length
			prev_value = values[count - 1]
		if next < count:
			next_time = times[next]
			next_value = values[next]
		elif loop:
			next_time = times[0] + length
			next_value = values[0]
		if prev_value == null or next_value == null:

			tangents[i] = zero
			continue
		tangents[i] = (next_value - prev_value) / maxf(next_time - prev_time, 0.001)
	track.m = tangents



static func wrap_time(clip: Dictionary, elapsed: float) -> float:
	var length: float = clip.len
	if not clip.loop: return clampf(elapsed, 0.0, length)
	var from: float = clip.loop_from
	if from <= 0.0 or elapsed < length: return fposmod(elapsed, length)
	return from + fposmod(elapsed - from, maxf(length - from, 0.001))


static func sample(track: Dictionary, time: float, loop: bool = false, length: float = 1.0) -> Variant:
	var times: PackedFloat32Array = track.t
	var values: Array = track.v
	var count: int = times.size()
	if count == 1 or time <= times[0] and not loop: return values[0]
	if time >= times[count - 1] and not loop: return values[count - 1]

	var i: int = count - 1
	for k in range(count - 1):
		if time < times[k + 1]:
			i = k
			break
	var a_time: float = times[i]
	var b: int = i + 1
	var b_time: float = 0.0
	if b >= count:

		b = 0
		b_time = times[0] + length
		if time < a_time: time += length
	else:
		b_time = times[b]
	if time < a_time:

		i = count - 1
		b = 0
		a_time = times[i] - length
		b_time = times[0]
	var span: float = maxf(b_time - a_time, 0.0001)
	var u: float = clampf((time - a_time) / span, 0.0, 1.0)
	var flag: int = track.f[i]
	if flag == FLAG_HOLD: return values[i]
	if flag == FLAG_LINEAR: return values[i] + (values[b] - values[i]) * u
	var u2: float = u * u
	var u3: float = u2 * u
	var h00: float = 2.0 * u3 - 3.0 * u2 + 1.0
	var h10: float = u3 - 2.0 * u2 + u
	var h01: float = -2.0 * u3 + 3.0 * u2
	var h11: float = u3 - u2
	return values[i] * h00 + track.m[i] * (h10 * span) + values[b] * h01 + track.m[b] * (h11 * span)


static func sample_string(list: Array, time: float) -> String:
	var result: String = ""
	for entry: Array in list:
		if time >= float(entry[0]): result = str(entry[1])
		else: break
	return result



static func envelope(clip: Dictionary, time: float) -> float:
	var fade_in: float = 1.0 if float(clip["in"]) <= 0.0 else smoothstep(0.0, float(clip["in"]), time)
	if clip.loop: return fade_in
	var length: float = clip.len
	var fade_out: float = 1.0 if float(clip.out) <= 0.0 else 1.0 - smoothstep(length - float(clip.out), length, time)
	return fade_in * fade_out
