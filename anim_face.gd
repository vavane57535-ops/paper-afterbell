extends RefCounted






const BLINK: int = 0
const PAIN: int = 1
const FEAR: int = 2
const ANGRY: int = 3
const SMILE: int = 4
const JAW: int = 5


const MOODS: Dictionary = {
	"neutral": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0], 
	"smile": [0.0, 0.0, 0.0, 0.75, 0.05, 0.0], 
	"grin": [0.0, 0.0, 0.2, 1.0, 0.18, 0.1], 
	"laugh": [0.0, 0.0, 0.0, 1.0, 0.35, 0.35], 
	"angry": [0.0, 0.0, 0.85, 0.0, 0.1, 0.0], 
	"determined": [0.0, 0.0, 0.5, 0.0, 0.0, 0.08], 
	"menace": [0.0, 0.0, 0.45, 0.55, 0.05, 0.12], 
	"fear": [0.0, 0.85, 0.0, 0.0, 0.3, 0.0], 
	"panic": [0.15, 1.0, 0.0, 0.0, 0.5, 0.0], 
	"pain": [1.0, 0.0, 0.0, 0.0, 0.4, 0.3], 
	"hurt": [0.35, 0.15, 0.0, 0.0, 0.08, 0.15], 
	"dazed": [0.4, 0.2, 0.0, 0.0, 0.25, 0.5], 
	"sad": [0.25, 0.45, 0.0, 0.0, 0.0, 0.3], 
	"tired": [0.15, 0.0, 0.0, 0.0, 0.25, 0.35], 
	"focus": [0.0, 0.0, 0.3, 0.0, 0.0, 0.12], 
	"calm": [0.0, 0.0, 0.0, 0.3, 0.0, 0.15], 
	"surprise": [0.0, 0.55, 0.0, 0.1, 0.45, 0.0], 
	"dead": [0.2, 0.0, 0.0, 0.0, 0.18, 1.0], 
	"asleep": [0.0, 0.0, 0.0, 0.0, 0.05, 1.0], 
}




const LIDS: Dictionary = {
	"neutral": [0.1, 0.0, 0.0], 
	"smile": [0.12, 0.36, 0.0], 
	"grin": [0.18, 0.42, 0.25], 
	"laugh": [0.62, 0.58, 0.0], 
	"angry": [0.46, 0.1, 1.0], 
	"determined": [0.32, 0.06, 0.65], 
	"menace": [0.38, 0.22, 0.85], 
	"fear": [0.0, 0.0, -0.55], 
	"panic": [0.0, 0.0, -0.8], 
	"pain": [0.9, 0.4, 0.45], 
	"hurt": [0.45, 0.18, -0.35], 
	"dazed": [0.58, 0.12, -0.25], 
	"sad": [0.4, 0.0, -0.95], 
	"tired": [0.52, 0.06, -0.3], 
	"focus": [0.34, 0.14, 0.45], 
	"calm": [0.24, 0.14, -0.1], 
	"surprise": [0.0, 0.0, 0.0], 
	"dead": [1.0, 0.0, 0.0], 
	"asleep": [1.0, 0.0, 0.0], 
}

var weights: PackedFloat32Array = PackedFloat32Array([0, 0, 0, 0, 0, 0])

var lids: Vector3 = Vector3(0.1, 0.0, 0.0)
var _lids_base: Vector3 = Vector3(0.1, 0.0, 0.0)
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _next_blink: float = 2.0
var _blink_time: float = -1.0
var _double: bool = false
var _pain_pulse: float = 0.0
var _jaw_pulse: float = 0.0
var _jaw_hold: float = 0.0
var _fear_pulse: float = 0.0
var _clock: float = 0.0
var _blink_shape: float = 0.0
var _mood: String = "neutral"

var fatigue: float = 0.0

var lid: float = 0.0

var chatter: float = 0.0

var jaw_min: float = 0.0

func setup(seed_value: int) -> void :
	_rng.seed = seed_value
	_next_blink = _rng.randf_range(0.4, 3.0)

func reset() -> void :
	for i in range(weights.size()): weights[i] = 0.0
	_pain_pulse = 0.0
	_jaw_pulse = 0.0
	_fear_pulse = 0.0
	_blink_time = -1.0
	chatter = 0.0


func hurt(strength: float) -> void :
	_pain_pulse = maxf(_pain_pulse, clampf(0.6 + strength * 0.5, 0.0, 1.0))
	grunt(0.35 + strength * 0.35, 0.18)
	_blink_time = 0.0
	_double = false


func grunt(amount: float, hold: float = 0.12) -> void :
	_jaw_pulse = maxf(_jaw_pulse, clampf(amount, 0.0, 1.0))
	_jaw_hold = maxf(_jaw_hold, hold)


func gasp() -> void :
	_fear_pulse = 1.0
	grunt(0.45, 0.2)


func update(dt: float, mood: String, alive: bool = true) -> PackedFloat32Array:
	_clock += dt
	if MOODS.has(mood): _mood = mood
	var target: Array = MOODS[_mood]
	var pain: float = maxf(float(target[0]), _pain_pulse)
	var fear: float = maxf(float(target[1]), _fear_pulse * 0.9)
	var angry: float = float(target[2]) * (1.0 - _pain_pulse)
	var smile: float = float(target[3]) * (1.0 - _pain_pulse) * (1.0 - _fear_pulse)
	var jaw: float = maxf(float(target[4]), _jaw_pulse)
	jaw = maxf(jaw, fatigue * (0.18 + 0.1 * sin(_clock * 5.0)))
	if chatter > 0.0: jaw = maxf(jaw, chatter * (0.2 + 0.25 * absf(sin(_clock * 17.0))))
	jaw = maxf(jaw, jaw_min)
	var eyelid: float = maxf(float(target[5]), lid)

	_pain_pulse = maxf(0.0, _pain_pulse - dt * 1.4)
	_fear_pulse = maxf(0.0, _fear_pulse - dt * 1.6)
	if _jaw_hold > 0.0: _jaw_hold -= dt
	else: _jaw_pulse = maxf(0.0, _jaw_pulse - dt * 3.5)
	_blink_shape = _blink_amount(dt, alive and eyelid < 0.95)
	var blink: float = eyelid + (1.0 - eyelid) * _blink_shape

	_ease(PAIN, pain, dt, 22.0, 7.0)
	_ease(FEAR, fear, dt, 14.0, 5.0)
	_ease(ANGRY, angry, dt, 10.0, 5.0)
	_ease(SMILE, smile, dt, 8.0, 5.0)
	_ease(JAW, jaw, dt, 26.0, 12.0)
	weights[BLINK] = blink

	var shape: Array = LIDS.get(_mood, LIDS.neutral)
	var top: float = maxf(float(shape[0]), lid)
	top = maxf(top, _pain_pulse * 0.88) * (1.0 - _fear_pulse * 0.9)
	var low: float = maxf(float(shape[1]), _pain_pulse * 0.35)
	var tilt: float = lerpf(float(shape[2]), 0.5, _pain_pulse * 0.6) - _fear_pulse * 0.5
	var lid_target: Vector3 = Vector3(top, low, tilt)

	_lids_base = _lids_base.lerp(lid_target, 1.0 - exp( - dt * 14.0))
	lids = _lids_base
	lids.x = lids.x + (1.0 - lids.x) * _blink_shape
	return weights

func _ease(index: int, target: float, dt: float, attack: float, release: float) -> void :
	var current: float = weights[index]
	var rate: float = attack if target > current else release
	weights[index] = lerpf(current, target, 1.0 - exp( - dt * rate))


func _blink_amount(dt: float, enabled: bool) -> float:
	if _blink_time < 0.0:
		_next_blink -= dt
		if _next_blink <= 0.0 and enabled:
			_blink_time = 0.0
			_double = _rng.randf() < 0.14
		else:
			return 0.0
	_blink_time += dt
	var t: float = _blink_time
	var amount: float = 0.0
	if t < 0.055: amount = t / 0.055
	elif t < 0.085: amount = 1.0
	elif t < 0.2: amount = 1.0 - smoothstep(0.085, 0.2, t)
	else:
		if _double:
			_double = false
			_blink_time = 0.0
			return 0.0
		_blink_time = -1.0

		var mean: float = 3.2
		if _mood in ["fear", "panic", "angry", "determined", "focus"]: mean = 5.0
		elif _mood in ["tired", "sad", "calm"]: mean = 2.4
		_next_blink = clampf( - log(maxf(_rng.randf(), 0.001)) * mean, 0.7, 8.0)
	return amount
