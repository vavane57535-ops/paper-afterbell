extends RefCounted
class_name PaperVictoryFilm

# 0.16 · Films de victoire LMS, mis en scène comme les écrans de victoire solo
# d'Outcome Memories : une vieille télé s'allume dans le noir sur un sol en
# damier, le souvenir se joue la nuit sous la pluie (gros plans, yeux qui
# brillent, geste signature du survivant), coupe nette sur papier blanc avec les
# silhouettes découpées du survivant qui triomphe d'Alice, puis la télé s'éteint.
#
# PaperCinema (cinematics.gd) délègue le film « ending_lms » à cette classe :
# write() écrit la timeline avec les primitives du film (_put, _move, _do, _cue,
# _shot…) et ajoute ses propres calques — décors (télé, plateau des silhouettes),
# étalonnage plein écran, débris de papier, reflets des yeux, partition et pluie —
# tous calculés en fonction du temps du film : l'avance rapide, le retour arrière
# de la cinémathèque et l'arrivée en cours de film d'un client restent justes.

const GradeShader: Shader = preload("res://film_victory_grade.gdshader")
const TvShader: Shader = preload("res://film_victory_tv.gdshader")
const FloorShader: Shader = preload("res://film_victory_floor.gdshader")

const TV_Y: float = 70.0
const INK_Y: float = 125.0
const KEY: Color = Color(0.55, 0.0, 0.55)
const PAPER: Color = Color("fff6e4")
const GOLD: Color = Color("ffd24a")
const CRIMSON: Color = Color("ff5a78")
const MUSIC_DIR: String = "res://audio/victory/"

const EMBLEM: Dictionary = {
	"Ashura": Color("39b6d6"), "Usayuko": Color("f0a531"), "Simon": Color("8f6cf0"),
	"Lysia": Color("2fd0a0"), "Elly": Color("49c9d6"), "Bleuette": Color("4f7ff0"),
}
const GLINT: Dictionary = {
	"Ashura": Color("bff4ff"), "Usayuko": Color("ffe7a6"), "Simon": Color("e6dcff"),
	"Lysia": Color("b8fff0"), "Elly": Color("cffbff"), "Bleuette": Color("cfe0ff"), "Alice": Color("ff3b55"),
}
# start of the paper-silhouette cut for each film; the TV comes back 2.6 s later
const INK_AT: Dictionary = {"Ashura": 9.85, "Usayuko": 8.95, "Simon": 9.4, "Lysia": 8.65, "Elly": 8.95, "Bleuette": 8.7}
const TAIL: float = 4.2
const TITLES: Dictionary = {
	"Ashura": "Ashura · Bricolage sous l’orage",
	"Usayuko": "Usayuko · Le poing de la dernière sonnerie",
	"Simon": "Simon · Plus vite que l’ombre",
	"Lysia": "Lysia · Surtension",
	"Elly": "Elly · Dernière cartouche",
	"Bleuette": "Bleuette · Le courage au chocolat",
}
const DESCRIPTIONS: Dictionary = {
	"Ashura": "Sous la pluie, Ashura rafistole son drone, l’envoie dans la figure d’Alice et file en rollers pendant qu’elle titube.",
	"Usayuko": "Usayuko bloque la griffe d’Alice, serre le poing et l’envoie voler à travers la cour d’un coup monstrueux.",
	"Simon": "Simon charge sa course éclair et dépasse Alice si vite qu’elle tourne sur elle-même, puis la laisse loin derrière.",
	"Lysia": "Lysia se branche, surchauffe, fonce sur Alice et la repousse dans une décharge électrique.",
	"Elly": "Blessée, Elly se soigne, esquive la griffe d’Alice et l’arrête net d’un tir de fusil à pompe.",
	"Bleuette": "Bleuette tremble, croque son chocolat, trouve son courage et file si vite qu’Alice s’étale dans une flaque.",
}

static func duration_for(person: String) -> float:
	return float(INK_AT.get(person, 9.4)) + TAIL

static func title_for(person: String) -> String:
	return str(TITLES.get(person, person + " · Victoire"))

static func description_for(person: String) -> String:
	return str(DESCRIPTIONS.get(person, ""))



class Burst:
	var start: float = 0.0
	var origin: Vector3 = Vector3.ZERO
	var direction: Vector3 = Vector3.UP
	var count: int = 12
	var speed: float = 4.0
	var spread: float = 0.8
	var lift: float = 1.5
	var gravity: float = 6.0
	var drag: float = 1.2
	var size: float = 0.12
	var life: float = 1.6
	var seed: int = 1
	var colors: Array[Color] = []
	var swirl: float = 0.0
	var radius: float = 0.0
	var first: int = 0



var cinema: Node3D
var world: Node
var person: String = "Ashura"
var active: bool = false
var length: float = 13.6

var s: int = 0
var a: int = 1
var rz: float = 20.0
# free metres in front of the exit (obstacles and the edge of the ground), measured
# with the map's physics so the long moves stay clear on every map
var room: float = 30.0
# the rain choreography is written facing away from the door, then turned as a
# whole by `turn` (radians about the vertical) toward the most open direction
var turn: float = 0.0
var snowy: bool = false

var t_cut: float = 2.25
var t_rain: float = 2.5
var t_ink: float = 9.4
var t_back: float = 12.0
var t_off: float = 12.75

var _flashes: Array = []
var _smears: Array = []
var _fx: Array = []
var _fx_cursor: int = 0
var _fx_time: float = -1.0
var _bursts: Array[Burst] = []
var _glints: Array = []
var _spins: Array = []
var _tilts: Array = []
var _bg: Array = []
var _rain_bursts: Array = []
var _lightning: Array = []

var _grade_layer: CanvasLayer
var _grade: ColorRect
var _grade_material: ShaderMaterial
var _letters: VBoxContainer
var _letter_top: Label
var _letter_name: Label
var _tv_room: Node3D
var _tv_screen: ShaderMaterial
var _tv_floor: ShaderMaterial
var _tv_glow: OmniLight3D
var _tv_rim: MeshInstance3D
var _ink_room: Node3D
var _rain_lights: Node3D
var _door_light: OmniLight3D
var _moon: OmniLight3D
var _flash_light: OmniLight3D
var _door_card: MeshInstance3D
var _back_light: OmniLight3D
var _key_light: OmniLight3D
var _sign_hidden: bool = false
var _debris: MultiMeshInstance3D
var _glint_nodes: Array[MeshInstance3D] = []
var _music: AudioStreamPlayer
var _rain_player: AudioStreamPlayer
var _tv_player: AudioStreamPlayer
var _thunder_player: AudioStreamPlayer
var _prev_forward: Vector3 = Vector3.ZERO
var _prev_shot: int = -1
var _auto_smear: Vector2 = Vector2.ZERO
var _shadows_off: bool = false
var _reduced: bool = false
var _light_profile: bool = false



func write(film: Node3D, who: String) -> void :
	cinema = film
	world = film.world
	person = who if who in EMBLEM else "Ashura"
	active = true
	s = 0
	a = int(film.alice_index)
	length = duration_for(person)
	rz = float(film._length) + 3.4
	_flashes.clear();_smears.clear();_fx.clear();_bursts.clear();_glints.clear();_spins.clear();_tilts.clear()
	_bg.clear();_rain_bursts.clear();_lightning.clear()
	_fx_cursor = 0;_fx_time = -1.0;_prev_shot = -1;_auto_smear = Vector2.ZERO
	_reduced = bool(film._flashes_reduced())
	_light_profile = bool(world.get("mobile_mode")) and str(world.get("mobile_profile")) in ["performance", "battery"]
	film._dark = true
	t_ink = float(INK_AT.get(person, 9.4))
	snowy = "snow" in str(world.get("selected_map"))
	_measure_room()
	_build_nodes()
	_write_opening()
	match person:
		"Usayuko": _write_usayuko()
		"Simon": _write_simon()
		"Lysia": _write_lysia()
		"Elly": _write_elly()
		"Bleuette": _write_bleuette()
		_: _write_ashura()
	_write_closing()
	if absf(turn) > 0.001: _orient_rain()
	_build_debris()
	_fx.sort_custom( func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	if is_instance_valid(world.audio) and world.audio.has_method("hold_music"): world.audio.hold_music(true)


func stop() -> void :
	if not active: return
	active = false
	if is_instance_valid(world) and is_instance_valid(world.audio) and world.audio.has_method("hold_music"): world.audio.hold_music(false)
	_restore_shadows()
	if _sign_hidden: _hide_sign(false)
	for node: Node in [_grade_layer, _tv_room, _ink_room, _rain_lights, _debris, _music, _rain_player, _tv_player, _thunder_player]:
		if is_instance_valid(node): node.queue_free()
	for node: MeshInstance3D in _glint_nodes:
		if is_instance_valid(node): node.queue_free()
	_glint_nodes.clear()



func _measure_room() -> float:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	query.collision_mask = 1
	var origin: Vector3 = Vector3(0, 0, rz)
	var base: float = cinema._world_spot(origin).y
	var best: float = -1.0
	turn = 0.0
	for degrees: float in [0.0, 90.0, -90.0, 45.0, -45.0]:
		var along: Vector3 = Vector3(0, 0, 1).rotated(Vector3.UP, deg_to_rad(degrees))
		var side: Vector3 = Vector3.UP.cross(along).normalized()
		var free: float = 30.0
		for x: float in [-1.0, 0.0, 1.0]:
			for h: float in [0.6, 1.3, 2.1]:
				query.from = cinema._world_spot(origin + side * x + Vector3.UP * h - along * 0.5)
				query.to = cinema._world_spot(origin + side * x + Vector3.UP * h + along * 30.0)
				var hit: Dictionary = space.intersect_ray(query)
				if not hit.is_empty(): free = minf(free, (hit.position as Vector3).distance_to(query.from) - 0.5 - 1.0)
		var d: float = 0.5
		while d < free:
			for x: float in [-1.0, 1.0]:
				query.from = cinema._world_spot(origin + along * d + side * x + Vector3.UP * 2.0)
				query.to = cinema._world_spot(origin + along * d + side * x + Vector3.DOWN * 2.0)
				var ground: Dictionary = space.intersect_ray(query)
				if ground.is_empty() or absf(float(ground.position.y) - base) > 0.7: free = minf(free, d - 1.0)
			d += 0.5
		# straight ahead is kept whenever it is open enough
		var score: float = free + (2.0 if degrees == 0.0 else 0.0)
		if score > best:
			best = score
			room = free
			turn = deg_to_rad(degrees)
	room = clampf(room, 5.0, 30.0)
	return room


func _far(z: float) -> float: return minf(z, room)


func _tv(x: float, y: float, z: float) -> Vector3: return Vector3(x, TV_Y + y, z)
func _ink(x: float, y: float, z: float) -> Vector3: return Vector3(x, INK_Y + y, z)
func _r(x: float, z: float, y: float = 0.0) -> Vector3: return Vector3(x, y, rz + z)

func _flash(t: float, seconds: float, color: Color = Color.WHITE) -> void : _flashes.append([t, seconds, color])
func _smear(t0: float, t1: float, amount: Vector2) -> void : _smears.append([t0, t1, amount])
func _later(t: float, kind: String, data: Dictionary = {}) -> void : _fx.append([t, kind, data])
func _glint(t0: float, t1: float, who: int, size: float = 1.0) -> void : _glints.append([t0, t1, who, size])
func _spin(t0: float, t1: float, who: int, turns: float, ease: String = "out") -> void : _spins.append([t0, t1, who, turns, ease])
func _tilt(t0: float, t1: float, who: int, from: Vector3, to: Vector3, ease: String = "smooth") -> void : _tilts.append([t0, t1, who, from, to, 0.0, ease])
func _rain_burst(t: float, at: Vector3, seconds: float = 0.6) -> void : _rain_bursts.append([t, at, seconds])
func _bolt(t: float, seconds: float = 0.25, energy: float = 1.0) -> void :
	_lightning.append([t, seconds, energy])
	_later(t + 0.12, "thunder", {"gain": energy})

func _burst(t: float, at: Vector3, direction: Vector3, count: int, speed: float, options: Dictionary = {}) -> void :
	var item: Burst = Burst.new()
	item.start = t
	item.origin = at
	item.direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector3.UP
	item.count = count
	item.speed = speed
	item.spread = float(options.get("spread", 0.8))
	item.lift = float(options.get("lift", 1.5))
	item.gravity = float(options.get("gravity", 6.0))
	item.drag = float(options.get("drag", 1.2))
	item.size = float(options.get("size", 0.12))
	item.life = float(options.get("life", 1.6))
	item.swirl = float(options.get("swirl", 0.0))
	item.radius = float(options.get("radius", 0.0))
	item.seed = 7919 * (_bursts.size() + 1) + int(t * 1000.0)
	var colors: Array = options.get("colors", [Color("f1e9d8"), Color("d9cfbd"), Color("3a3640")])
	for c: Variant in colors: item.colors.append(c)
	_bursts.append(item)


# Close-up framed on the eyes: `facing` is the direction the character faces
# (film axes), `side` shifts the camera to one cheek.
func _closeup(t: float, who: int, facing: Vector3, side: float = 1.0, distance: float = 0.95, fov: float = 26.0) -> void :
	var front: Vector3 = Vector3(facing.x, 0.0, facing.z).normalized()
	var cheek: Vector3 = Vector3.UP.cross(front).normalized() * side * 0.3
	var from: Vector3 = front * distance + cheek + Vector3.UP * 0.05
	var to: Vector3 = front * distance * 0.82 + cheek * 0.8 + Vector3.UP * 0.04
	cinema._shot(t, {"rel": {"a": who, "s": "eyes"}, "eye": [from, to], "look": {"a": who, "s": "eyes"}, "fov": [fov, fov - 3.0], "hand": 0.25})


func _turn_vector(v: Vector3) -> Vector3: return v.rotated(Vector3.UP, turn)


func _turn_point(p: Vector3) -> Vector3:
	if p.y > 30.0: return p
	var origin: Vector3 = Vector3(0, 0, rz)
	return origin + (p - origin).rotated(Vector3.UP, turn)


func _turn_spot(spec: Variant) -> Variant:
	if spec is Vector3: return _turn_point(spec)
	if spec is Dictionary:
		var data: Dictionary = (spec as Dictionary).duplicate()
		if data.has("o") and data.o is Vector3: data.o = _turn_vector(data.o)
		return data
	return spec


func _in_rain(t: float) -> bool: return t >= 3.32 and t < t_ink - 0.001


# Turns everything written for the rain about the rain origin: actor paths and
# facings, shots, cues, flights, debris and the module's own effects.
func _orient_rain() -> void :
	var c: Node3D = cinema
	for take: Variant in c.takes:
		for key: Array in take.path: key[1] = _turn_point(key[1])
		for key: Array in take.facing:
			if str(key[1]) == "dir" and float(key[0]) < t_ink - 0.001 and key[2] is Vector3: key[2] = _turn_vector(key[2])
	for shot: Array in c._shots:
		if not _in_rain(float(shot[0])): continue
		var spec: Dictionary = shot[1]
		var relative: bool = spec.has("rel")
		if relative: spec.rel = _turn_spot(spec.rel)
		var eye: Variant = spec.get("eye")
		if eye is Array: spec.eye = [_turn_vector(eye[0]) if relative else _turn_point(eye[0]), _turn_vector(eye[1]) if relative else _turn_point(eye[1])]
		elif eye is Vector3: spec.eye = _turn_vector(eye) if relative else _turn_point(eye)
		var look: Variant = spec.get("look")
		if look is Array: spec.look = [_turn_spot(look[0]), _turn_spot(look[1])]
		elif look != null: spec.look = _turn_spot(look)
	for cue: Array in c._track:
		if not _in_rain(float(cue[0])): continue
		match str(cue[1]):
			"sound", "word", "mark": cue[3] = _turn_spot(cue[3])
			"pop":
				cue[2] = _turn_spot(cue[2])
				if cue[3] is Vector3: cue[3] = _turn_vector(cue[3])
			"stars", "dust_ring", "crack", "sparkles", "pillars", "sweat": cue[2] = _turn_spot(cue[2])
			"spikes":
				cue[2] = _turn_spot(cue[2])
				cue[3] = _turn_spot(cue[3])
			"event":
				var data: Dictionary = (cue[3] as Dictionary).duplicate()
				for key: Variant in data.keys():
					if data[key] is Dictionary or (data[key] is Vector3 and str(key) in ["position", "from", "to", "source_position"]): data[key] = _turn_spot(data[key])
				cue[3] = data
	for flight: Array in c._flights:
		if not _in_rain(float(flight[0])): continue
		flight[3] = _turn_spot(flight[3])
		flight[4] = _turn_spot(flight[4])
	for item: Array in _fx:
		if not _in_rain(float(item[0])): continue
		var data: Dictionary = (item[2] as Dictionary).duplicate()
		if data.has("at"): data.at = _turn_spot(data.at)
		if data.has("dir") and data.dir is Vector3: data.dir = _turn_vector(data.dir)
		item[2] = data
	for burst: Burst in _bursts:
		if burst.origin.y > 30.0: continue
		burst.origin = _turn_point(burst.origin)
		burst.direction = _turn_vector(burst.direction)
	for item: Array in _rain_bursts: item[1] = _turn_point(item[1])
	for tilt: Array in _tilts:
		if _in_rain(float(tilt[0])): tilt[5] = turn


func _jump(i: int, t: float, spot: Vector3) -> void :
	cinema._move(i, t - 0.01, t, spot, "jump")


func _hold_pose(i: int, t0: float, t1: float) -> void :
	var t: float = t0
	while t < t1:
		cinema._do(i, t, "hitstop", 0.25)
		t += 0.2



func _write_opening() -> void :
	var c: Node3D = cinema
	t_cut = 2.25
	t_rain = 2.5
	c._shot(0.0, {"eye": [_tv(0.12, 0.85, 12.0), _tv(0.0, 0.95, 3.2)], "look": [_tv(0.0, 0.6, 0.0), _tv(0.0, 0.84, 0.0)], "fov": [30, 36], "hand": 0.05, "safe": false, "ease": "out"})
	for i: int in [s, a]:
		c._do(i, 0.0, "show", false)
		c._do(i, 3.3, "show", true)
	c._blackouts.append([t_cut, t_rain])
	c._cue(0.12, "sound", "camera_switch", _tv(0, 1.0, 3.0), 0.7, 0.8)
	c._cue(1.75, "sound", "shadow", _tv(0, 1.0, 3.0), 0.5, 0.7)
	# the door of the school glows in the dark rain (OM: the ring)
	var door: Vector3 = Vector3(0, 1.4, float(c._length))
	c._shot(t_rain, {"eye": [_r(1.1, 3.6, 1.25), _r(0.25, -2.6, 1.35)], "look": [door + Vector3(0.6, -0.1, 0), door], "fov": [44, 40], "hand": 0.3, "ease": "in"})
	_flash(3.3, 0.38)
	_later(3.3, "sound", {"kind": "flash", "at": door, "gain": 0.45, "pitch": 1.25})


func _write_closing() -> void :
	var c: Node3D = cinema
	var ink: float = t_ink
	# paper background: white, held, then down to grey and black (OM)
	_later(ink - 0.03, "mute_words", {"seconds": 2.6})
	_bg.append([ink, Color("f4efe4")])
	_bg.append([ink + 1.45, Color("f1ece1")])
	_bg.append([ink + 2.05, Color("8f8b86")])
	_bg.append([ink + 2.5, Color("0b0a0c")])
	t_back = ink + 2.6
	t_off = t_back + 0.8
	c._blackouts.append([ink + 2.5, t_back])
	c._shot(t_back, {"eye": [_tv(0.0, 0.95, 4.1), _tv(0.0, 0.95, 3.6)], "look": _tv(0.0, 0.84, 0.0), "fov": 36, "hand": 0.05, "safe": false})
	c._cue(t_off, "sound", "camera_switch", _tv(0, 1.0, 3.0), 0.8, 0.6)
	_flash(ink, 0.12)



# ---------------------------------------------------------------- SIMON ---
# Vitesse : course éclair chargée, il dépasse Alice si vite qu'elle tourne sur
# elle-même, repasse en tornade autour d'elle et disparaît dans la nuit.
func _write_simon() -> void :
	var c: Node3D = cinema
	var tint: Color = GLINT.Simon
	c._put(s, _r(0.0, 0.0))
	c._face(s, 0.0, "dir", Vector3(0, 0, 1))
	c._do(s, 0.0, "state", {"lms": true})
	c._put(a, _r(0.15, 5.2))
	c._face(a, 0.0, "at", s)
	c._do(a, 0.0, "mood", "menace")
	# A · feet in the puddle, the charge starts
	c._do(s, 3.3, "state", {"boost_charging": true, "charging_boost": 0.0, "boost_level": 0})
	c._ramp(s, 3.3, 5.18, "charging_boost", 0.0, 3.0)
	c._do(s, 3.95, "state", {"boost_level": 1})
	c._do(s, 4.6, "state", {"boost_level": 2})
	c._cue(3.45, "event", "boost_charge", {"position": {"a": s}, "active": true})
	c._shot(3.4, {"rel": {"a": s}, "eye": [Vector3(1.0, 0.24, 1.15), Vector3(0.75, 0.28, 0.95)], "look": {"a": s, "h": 0.28, "o": Vector3(0, 0, 0.1)}, "fov": [42, 38], "hand": 0.5})
	for k: int in range(5): _later(3.45 + 0.13 * float(k), "bolts", {"at": {"a": s, "h": 0.15}, "color": Color("d9c8ff"), "count": 2, "radius": 0.45, "size": 0.55})
	_later(3.5, "sparkles", {"at": {"a": s, "h": 0.3}, "color": tint, "count": 6, "radius": 0.5})
	# B · eyes
	c._do(s, 3.95, "mood", "determined")
	_closeup(4.0, s, Vector3(0, 0, 1), 1.0, 1.05, 28.0)
	_glint(4.05, 4.75, s, 1.1)
	_bolt(4.35, 0.22, 0.9)
	# C · Alice in the rain, over Simon's shoulder
	c._move(a, 4.55, 5.25, _r(0.1, 3.6), "smooth")
	c._shot(4.7, {"rel": {"a": s}, "eye": [Vector3(-0.55, 1.62, -1.5), Vector3(-0.45, 1.6, -1.25)], "look": {"a": a, "h": 1.35}, "fov": [36, 33], "hand": 0.35})
	_glint(4.75, 5.3, a, 0.9)
	# D · release: past her in a blink
	var go: float = 5.32
	c._do(s, go, "unset", ["boost_charging", "charging_boost", "boost_level"])
	c._do(s, go, "state", {"speed_boost": 6.0})
	c._cue(go, "event", "boost_release", {"position": {"a": s}, "level": 3})
	c._cue(go, "sound", "boost", {"a": s}, 1.0, 1.1)
	c._cue(go, "rush", 1.0)
	c._cue(go + 0.02, "shake", 0.35)
	c._face(s, go, "move")
	c._move(s, go, go + 0.26, _r(-0.95, _far(10.5)), "dash")
	c._do(a, go + 0.02, "trigger", "slash")
	c._cue(go + 0.14, "word", "miss", {"a": a, "h": 2.15}, PAPER, 0.9)
	_spin(go + 0.08, go + 1.45, a, 3.0, "out")
	c._stun(a, go + 0.3, 1.6)
	c._cue(go + 0.35, "stars", {"a": a, "s": "over"}, 4)
	_later(go + 0.02, "trail", {"who": s, "socket": "foot_r", "seconds": 0.5, "width": 0.22})
	_later(go + 0.02, "trail", {"who": s, "socket": "hand_l", "seconds": 0.5, "width": 0.18})
	_later(go + 0.05, "whoosh", {"at": {"a": a, "h": 1.0, "o": Vector3(-0.8, 0, 0)}, "dir": Vector3(0, 0, 1), "color": tint, "count": 7, "length": 2.4})
	_later(go + 0.06, "cue", {"who": s, "cue": "afterimage"})
	_later(go + 0.12, "cue", {"who": s, "cue": "afterimage"})
	_later(go + 0.2, "cue", {"who": a, "cue": "spin"})
	_burst(go + 0.1, _r(-0.4, 5.2, 0.4), Vector3(0, 0.4, 1), 26, 5.5, {"spread": 0.9, "lift": 2.2, "swirl": 5.0, "radius": 0.9, "life": 1.9, "size": 0.11})
	_rain_burst(go + 0.08, _r(-0.6, 5.0, 1.0), 0.7)
	_smear(go - 0.02, go + 0.3, Vector2(0.075, 0.0))
	c._shot(go - 0.08, {"rel": {"a": a}, "eye": [Vector3(4.6, 1.15, -0.6), Vector3(4.3, 1.2, -0.2)], "look": {"a": a, "h": 1.0, "o": Vector3(0, 0, -0.4)}, "fov": [48, 46], "hand": 0.6})
	# E · Alice spinning
	c._shot(go + 0.42, {"rel": {"a": a}, "eye": [Vector3(0.5, 1.45, -2.2), Vector3(0.35, 1.5, -1.9)], "look": {"a": a, "h": 1.35}, "fov": [34, 31], "hand": 0.4, "roll": [-4, 6]})
	# F · Simon skids, turns back and grins
	var skid: float = 6.45
	c._face(s, go + 0.4, "dir", Vector3(0, 0, -1))
	_later(go + 0.27, "cue", {"who": s, "cue": "skid"})
	c._do(s, skid, "mood", "grin")
	c._do(s, skid + 0.05, "emote", "point")
	c._shot(skid, {"rel": {"a": s}, "eye": [Vector3(0.9, 1.35, -2.4), Vector3(0.7, 1.4, -2.0)], "look": {"a": s, "h": 1.3}, "fov": [34, 30], "hand": 0.3})
	_glint(skid + 0.05, skid + 0.75, s, 1.0)
	# G · tornado around her
	var loop: float = 7.25
	c._do(s, loop - 0.05, "emote", "")
	c._face(s, loop, "move")
	var center: Vector3 = _r(0.15, 3.6)
	var points: Array[Vector3] = []
	for k: int in range(7):
		var angle: float = PI * 0.5 + float(k) * TAU / 6.0
		points.append(center + Vector3(cos(angle) * 1.7, 0, sin(angle) * 1.7))
	c._move(s, loop, loop + 0.12, points[0], "linear")
	for k: int in range(1, points.size()):
		c._move(s, loop + 0.12 + 0.075 * float(k - 1), loop + 0.12 + 0.075 * float(k), points[k], "linear")
		_later(loop + 0.12 + 0.075 * float(k), "cue", {"who": s, "cue": "afterimage"})
	var leave: float = loop + 0.12 + 0.075 * float(points.size() - 1)
	c._move(s, leave, leave + 0.25, _r(0.6, _far(6.5)), "dash")
	c._cue(loop, "sound", "boost", {"a": s}, 0.8, 1.25)
	c._cue(loop + 0.1, "rush", 0.9)
	_later(loop + 0.1, "cue", {"who": a, "cue": "spin"})
	_later(loop + 0.3, "cue", {"who": a, "cue": "spin"})
	_spin(loop + 0.05, loop + 1.4, a, 4.0, "out")
	c._stun(a, loop, 2.6)
	c._cue(loop + 0.7, "stars", {"a": a, "s": "over"}, 5)
	_burst(loop + 0.05, center + Vector3(0, 0.2, 0), Vector3.UP, 34, 2.4, {"spread": 0.3, "lift": 3.2, "swirl": 7.5, "radius": 1.5, "gravity": 1.2, "drag": 0.6, "life": 2.2, "size": 0.12})
	_rain_burst(loop + 0.1, center + Vector3(0, 1.0, 0), 0.9)
	c._shot(loop - 0.05, {"rel": {"a": a}, "eye": [Vector3(1.4, 5.4, 1.9), Vector3(1.1, 4.9, 1.5)], "look": {"a": a, "h": 0.6}, "fov": [52, 48], "hand": 0.5, "roll": [3, -5]})
	# H · gone: tracking sprint into the night
	var run: float = 8.3
	c._move(s, run, run + 1.1, _r(0.6, _far(24.0)), "linear")
	c._cue(run, "rush", 1.0)
	c._shot(run, {"rel": {"a": s}, "eye": [Vector3(1.0, 0.75, 2.1), Vector3(1.15, 0.8, 2.3)], "look": {"a": s, "h": 0.95}, "fov": [54, 58], "hand": 0.7})
	_smear(run, run + 1.0, Vector2(0.0, 0.0))
	_bolt(run + 0.55, 0.3, 1.2)
	_flash(t_ink - 0.06, 0.14)
	# INK · the camera keeps pace with Simon in profile: he blows past Alice, who
	# spins and slides out of the frame behind him, scraps of paper streaming by
	var ink: float = t_ink
	_jump(s, ink, _ink(1.0, 0, 0.0))
	_jump(a, ink, _ink(-1.6, 0, -1.0))
	c._face(s, ink, "move")
	c._do(s, ink, "unset", ["speed_boost"])
	c._do(s, ink, "state", {"speed_boost": 6.0})
	c._move(s, ink + 0.01, ink + 2.55, _ink(-13.0, 0, 0.0), "linear")
	c._do(a, ink, "stun", true)
	_spin(ink, ink + 2.6, a, 3.0, "linear")
	_later(ink + 0.4, "cue", {"who": a, "cue": "spin"})
	_burst(ink + 0.4, _ink(-1.6, 0.3, -1.0), Vector3.UP, 26, 1.6, {"spread": 0.4, "lift": 1.6, "swirl": 4.0, "radius": 1.0, "gravity": 0.4, "drag": 0.5, "life": 2.6, "size": 0.1})
	for k: int in range(6):
		var x: float = -3.2 - 2.2 * float(k)
		_burst(ink + 0.04, _ink(x, 0.6, -1.6), Vector3(0.2, 1.0, 0.0), 7, 0.35, {"spread": 1.0, "lift": 0.3, "gravity": 0.05, "drag": 0.6, "life": 2.6, "size": 0.09 + 0.02 * float(k % 3)})
		# grit kicked up behind his heels, where he is at that moment
		var kick: float = 0.15 + 0.4 * float(k)
		_burst(ink + kick, _ink(1.3 - 14.0 / 2.55 * kick, 0.15, 0.0), Vector3(1.0, 0.5, 0.0), 6, 3.0, {"spread": 0.5, "lift": 0.8, "gravity": 2.0, "drag": 1.2, "life": 1.4, "size": 0.07})
	for k: int in range(8): _later(ink + 0.1 + 0.28 * float(k), "cue", {"who": s, "cue": "afterimage"})
	for k: int in range(4): _later(ink + 0.15 + 0.6 * float(k), "whoosh", {"at": {"a": s, "h": 1.0, "o": Vector3(1.2, 0, 0)}, "dir": Vector3(1, 0, 0), "color": PAPER, "count": 6, "length": 2.2})
	c._shot(ink, {"rel": {"a": s}, "eye": [Vector3(0.6, 1.0, 4.8), Vector3(0.45, 1.0, 4.6)], "look": {"a": s, "h": 0.95, "o": Vector3(-0.5, 0, 0)}, "fov": 42, "hand": 0.1, "safe": false})



# -------------------------------------------------------------- USAYUKO ---
# Force : il bloque la griffe, serre le poing et envoie Alice voler à travers
# la cour d'un coup de poing monstrueux.
func _write_usayuko() -> void :
	var c: Node3D = cinema
	c._put(s, _r(0.0, 0.0))
	c._face(s, 0.0, "at", a)
	c._do(s, 0.0, "state", {"lms": true})
	c._put(a, _r(0.1, 3.4))
	c._face(a, 0.0, "at", s)
	c._do(a, 0.0, "mood", "menace")
	# A · Alice strikes, Usayuko blocks
	c._do(s, 3.3, "state", {"block": 1.2})
	c._move(a, 3.42, 3.6, _r(0.05, 1.5), "dash")
	c._do(a, 3.5, "trigger", "slash")
	c._cue(3.62, "event", "block", {"position": {"a": s, "h": 1.2}})
	c._cue(3.62, "sound", "block", {"a": s})
	c._cue(3.62, "word", "block", {"a": s, "h": 2.2}, Color("ffe3a0"), 0.95)
	c._do(s, 3.62, "play", "block_hit")
	c._do(a, 3.62, "hitstop", 0.14)
	c._cue(3.62, "shake", 0.35)
	_flash(3.62, 0.06, Color(1.0, 0.9, 0.6))
	_later(3.62, "pop", {"at": {"a": s, "h": 1.25, "o": Vector3(0, 0, 0.45)}, "color": GOLD, "scale": 1.1})
	c._shot(3.4, {"rel": {"mid": [s, a]}, "eye": [Vector3(2.9, 1.0, 0.2), Vector3(2.6, 1.05, 0.0)], "look": {"mid": [s, a], "h": 1.2}, "fov": [42, 40], "hand": 0.6})
	# B · eyes, anger
	c._do(s, 4.05, "unset", ["block"])
	c._do(s, 4.05, "mood", "angry")
	c._do(s, 4.1, "trigger", "grunt")
	_closeup(4.1, s, Vector3(0, 0, 1), -1.0, 1.05, 28.0)
	_glint(4.15, 4.85, s, 1.15)
	_bolt(4.5, 0.25, 1.0)
	# C · shove, wind-up and aura
	c._do(s, 4.85, "trigger", "contre")
	c._blow(4.98, a, s, "counter", GOLD, 0.9)
	c._knock(a, 4.98, 1.0, Vector3(0, 0, 1))
	_later(5.05, "cue", {"who": s, "cue": "flex"})
	c._cue(5.05, "pulse", Color(1.0, 0.8, 0.35, 0.3), 0.8)
	c._shot(4.85, {"rel": {"a": a}, "eye": [Vector3(0.7, 0.35, 1.6), Vector3(0.6, 0.3, 1.9)], "look": {"a": s, "h": 1.35}, "fov": [40, 36], "hand": 0.5})
	_burst(5.1, _r(0.0, 0.0, 0.05), Vector3.UP, 16, 1.2, {"spread": 1.0, "lift": 2.2, "gravity": 2.0, "life": 1.2, "size": 0.07, "colors": [Color("7a7268"), Color("5a544c")]})
	# D · the punch
	var hit: float = 5.75
	c._move(s, hit - 0.32, hit - 0.06, _r(0.0, 1.55), "dash")
	c._do(s, hit - 0.24, "trigger", "punch")
	# the blow without a word: the frame belongs to the fist
	c._cue(hit, "pop", {"a": a, "h": 1.2, "o": Vector3(0, 0, -0.3)}, Vector3(0, 0, -1), GOLD, 1.6)
	c._cue(hit, "stars", {"a": a, "s": "over"}, 4)
	c._cue(hit, "impact", 0.9, true)
	c._do(a, hit, "hit", 1.5, s)
	c._do(s, hit, "hitstop", 0.16)
	c._do(a, hit, "hitstop", 0.16)
	c._cue(hit, "sound", "punch", {"a": a}, 1.0, 0.75)
	c._cue(hit, "sound", "ground_impact", {"a": a}, 1.0, 0.7)
	c._cue(hit, "shake", 0.9)
	c._cue(hit, "frame", Color(1, 1, 1, 0.5), 0.07)
	c._cue(hit + 0.02, "dust_ring", {"a": a}, 1.4)
	_flash(hit, 0.1)
	_rain_burst(hit, _r(0.0, 2.8, 1.25), 0.8)
	_burst(hit, _r(0.0, 2.9, 1.25), Vector3(0, 0.25, 1), 30, 7.0, {"spread": 0.55, "lift": 1.6, "gravity": 7.0, "life": 1.7, "size": 0.12})
	c._shot(hit - 0.3, {"rel": {"a": s}, "eye": [Vector3(1.25, 1.2, 1.5), Vector3(1.35, 1.25, 1.75)], "look": {"a": s, "h": 1.25, "o": Vector3(0, 0, 0.6)}, "fov": [38, 44], "hand": 0.8})
	# E · Alice flies across the yard and crashes
	var fly: float = hit + 0.12
	c._do(a, fly, "state", {"forced_time": 1.0, "force_name": "knock", "grounded": false})
	# stop short of the first obstacle: the hit reaction still slides her back a little
	var land: float = maxf(5.0, minf(12.5, room - 1.2))
	c._move(a, fly, fly + 0.35, _r(0.0, lerpf(2.5, land, 0.45), 1.6), "out")
	c._move(a, fly + 0.35, fly + 0.82, _r(0.0, land, 0.0), "in")
	# thrown back head first, she rolls over in the air and lands face down: the
	# downed pose blends in during the somersault (it starts from the standing
	# pose, so it must not begin on the ground) and the roll ends level with it
	_tilt(fly, fly + 0.25, a, Vector3(0, 0, 0), Vector3(-1.35, 0, 0.35))
	_tilt(fly + 0.25, fly + 0.82, a, Vector3(-1.35, 0, 0.35), Vector3(-TAU, 0, 0.0), "linear")
	_spin(fly + 0.05, fly + 0.8, a, 1.0, "out")
	c._do(a, fly + 0.3, "life", "downed")
	_burst(fly + 0.18, _r(0.0, lerpf(2.5, land, 0.3), 1.5), Vector3(0, 0.4, -1.0), 12, 1.8, {"spread": 0.9, "lift": 0.6, "gravity": 2.5, "drag": 1.0, "life": 1.4, "size": 0.1})
	var crash: float = fly + 0.82
	c._do(a, crash, "unset", ["forced_time", "force_name", "grounded"])
	c._cue(crash, "crack", {"a": a}, 1.8)
	c._cue(crash, "dust_ring", {"a": a}, 1.6)
	c._cue(crash, "sound", "ground_impact", {"a": a}, 1.0, 0.8)
	c._cue(crash, "shake", 0.6)
	_burst(crash, _r(0.0, land, 0.2), Vector3(0, 1, 0.4), 22, 4.2, {"spread": 1.0, "lift": 2.0, "gravity": 8.0, "life": 1.3, "size": 0.1})
	_smear(fly, fly + 0.35, Vector2(0.05, 0.0))
	# chase camera inside the measured free corridor (no wall between it and her)
	c._shot(fly, {"rel": {"a": a}, "eye": [Vector3(1.0, 1.6, -2.6), Vector3(0.8, 1.2, -2.0)], "look": {"a": a, "h": 0.8}, "fov": [50, 44], "hand": 0.6})
	# F · steam from the fist, grin
	var after: float = 7.05
	c._face(s, after, "dir", Vector3(0, 0, 1))
	c._do(s, after, "mood", "grin")
	_later(after + 0.05, "cue", {"who": s, "cue": "steam"})
	_later(after + 0.45, "cue", {"who": s, "cue": "steam"})
	_closeup(after, s, Vector3(0, 0, 1), 1.0, 1.35, 32.0)
	_glint(after + 0.1, after + 0.8, s, 1.0)
	# G · hero shot under the lightning, Alice down in the background
	var hero: float = 7.85
	c._do(s, hero, "emote", "thumbsup")
	c._shot(hero, {"rel": {"a": s}, "eye": [Vector3(-1.0, 0.35, 2.7), Vector3(-0.85, 0.4, 2.35)], "look": {"a": s, "h": 1.45}, "fov": [44, 40], "hand": 0.4})
	_bolt(hero + 0.35, 0.3, 1.3)
	_flash(t_ink - 0.06, 0.12)
	# INK · the punch, frozen: Alice flying away in pieces of paper
	var ink: float = t_ink
	c._do(s, ink, "emote", "")
	_jump(s, ink, _ink(-1.25, 0, 0.0))
	_jump(a, ink, _ink(0.55, 0.55, 0.0))
	c._face(s, ink, "dir", Vector3(1, 0, 0))
	c._face(a, ink, "dir", Vector3(-1, 0, 0))
	c._do(s, ink - 0.05, "trigger", "punch")
	_hold_pose(s, ink + 0.2, ink + 2.6)
	c._do(a, ink, "life", "alive")
	c._do(a, ink, "stun", false)
	c._do(a, ink, "state", {"forced_time": 3.0, "force_name": "knock", "grounded": false})
	c._move(a, ink + 0.01, ink + 2.5, _ink(2.05, 1.2, -0.3), "out")
	# flung away from the fist (a negative roll leans her toward screen right)
	_tilt(ink, ink + 2.6, a, Vector3(0, 0, -0.5), Vector3(0, 0, -0.95))
	_burst(ink, _ink(0.4, 1.2, 0.0), Vector3(1, 0.25, 0), 36, 3.6, {"spread": 0.6, "lift": 0.6, "gravity": 0.9, "drag": 0.9, "life": 2.6, "size": 0.13})
	_burst(ink + 0.02, _ink(0.2, 1.3, 0.0), Vector3(1, 0.6, 0.1), 12, 2.4, {"spread": 0.5, "lift": 0.8, "gravity": 0.6, "drag": 0.7, "life": 2.6, "size": 0.26})
	c._shot(ink, {"eye": [_ink(0.35, 1.1, 6.3), _ink(0.4, 1.1, 5.9)], "look": [_ink(0.35, 1.05, 0.0), _ink(0.45, 1.05, 0.0)], "fov": 42, "hand": 0.1, "safe": false})



# --------------------------------------------------------------- ASHURA ---
# Drones, rollers et bricolage : il rafistole son drone sous la pluie, l'envoie
# dans la figure d'Alice et la laisse tituber en filant sur ses rollers.
func _write_ashura() -> void :
	var c: Node3D = cinema
	c._put(s, _r(0.0, 0.0))
	c._face(s, 0.0, "dir", Vector3(0.3, 0, -1))
	c._do(s, 0.0, "state", {"lms": true, "camera_view": true})
	c._put(a, _r(1.4, 6.5))
	c._face(a, 0.0, "at", s)
	c._do(a, 0.0, "mood", "menace")
	# A · tinkering with the drone, sparks in the rain
	c._shot(3.4, {"rel": {"a": s, "s": "eyes"}, "eye": [Vector3(0.75, -0.05, -1.25), Vector3(0.6, -0.08, -1.05)], "look": {"a": s, "s": "hand_r"}, "fov": [38, 34], "hand": 0.35})
	for k: int in range(4): _later(3.45 + 0.16 * float(k), "cue", {"who": s, "cue": "spark_r" if k % 2 == 0 else "spark_l"})
	c._cue(3.5, "sound", "camera_place", {"a": s}, 0.8, 1.2)
	# B · Alice comes, Ashura looks up and grins
	c._move(a, 3.9, 4.9, _r(1.0, 4.4), "smooth")
	c._do(s, 4.05, "unset", ["camera_view"])
	c._face(s, 4.05, "at", a)
	c._do(s, 4.1, "mood", "grin")
	_closeup(4.05, s, Vector3(0.15, 0, 1), 1.0, 1.05, 28.0)
	_glint(4.15, 4.8, s, 1.1)
	# C · drone away, right in her face
	var fling: float = 4.85
	c._do(s, fling, "trigger", "drone")
	c._flights.append([fling + 0.14, fling + 0.62, "drone", {"a": s, "s": "hand_r"}, {"a": a, "s": "head"}, 0.45, 0.8])
	c._cue(fling + 0.14, "sound", "camera_place", {"a": s}, 0.7, 1.4)
	_later(fling + 0.1, "cue", {"who": s, "cue": "drone_up"})
	var bonk: float = fling + 0.62
	c._cue(bonk, "event", "drone", {"action": "impact", "position": {"a": a, "s": "head"}})
	c._cue(bonk, "sound", "ground_impact", {"a": a}, 0.8, 1.2)
	c._cue(bonk, "word", "zap", {"a": a, "h": 2.2}, Color("bff4ff"), 1.0)
	c._cue(bonk, "shake", 0.4)
	c._do(a, bonk, "hit", 1.0, s)
	c._do(a, bonk, "state", {"blind": 3.5})
	c._stun(a, bonk, 0.9)
	_burst(bonk, _r(1.0, 4.4, 1.6), Vector3(0, 0.6, -1), 14, 3.0, {"spread": 1.0, "lift": 1.2, "life": 1.2, "size": 0.07, "colors": [Color("8055b7"), Color("474555"), Color("c6b5f9")]})
	c._shot(fling - 0.05, {"rel": {"mid": [s, a]}, "eye": [Vector3(-3.2, 1.25, -0.6), Vector3(-2.8, 1.3, -0.2)], "look": {"a": a, "h": 1.4}, "fov": [46, 40], "hand": 0.5})
	# D · roller charge and release
	var charge: float = 5.85
	c._face(s, charge, "dir", Vector3(-0.35, 0, 1))
	c._do(s, charge, "state", {"boost_charging": true, "charging_boost": 0.0, "boost_level": 0})
	c._ramp(s, charge, charge + 0.8, "charging_boost", 0.0, 3.0)
	c._do(s, charge + 0.45, "state", {"boost_level": 2})
	c._cue(charge, "event", "boost_charge", {"position": {"a": s}, "active": true})
	for k: int in range(3): _later(charge + 0.12 + 0.24 * float(k), "cue", {"who": s, "cue": "skate_sparks"})
	c._shot(charge, {"rel": {"a": s}, "eye": [Vector3(1.5, 0.5, 2.0), Vector3(1.25, 0.55, 1.7)], "look": {"a": s, "h": 0.6}, "fov": [42, 38], "hand": 0.45})
	var go: float = charge + 0.95
	c._do(s, go, "unset", ["boost_charging", "charging_boost", "boost_level"])
	c._do(s, go, "state", {"boost_time": 6.0})
	c._cue(go, "dust_ring", {"a": s}, 0.9)
	c._cue(go, "sound", "boost", {"a": s}, 1.0, 1.0)
	c._cue(go, "rush", 0.8)
	c._face(s, go, "move")
	# a wide curve around the blinded Alice
	c._move(s, go, go + 0.45, _r(-1.4, 3.0), "dash")
	c._move(s, go + 0.45, go + 0.85, _r(-0.6, 6.4), "linear")
	c._move(s, go + 0.85, go + 1.25, _r(1.2, 7.6), "linear")
	for k: int in range(4): _later(go + 0.1 + 0.28 * float(k), "cue", {"who": s, "cue": "skate_sparks"})
	_later(go + 0.05, "trail", {"who": s, "socket": "foot_r", "seconds": 1.2, "width": 0.18})
	_later(go + 0.05, "trail", {"who": s, "socket": "foot_l", "seconds": 1.2, "width": 0.18})
	c._do(a, go + 0.35, "trigger", "slash")
	c._cue(go + 0.48, "word", "miss", {"a": a, "h": 2.2}, PAPER, 0.85)
	_spin(go + 0.4, go + 1.1, a, 1.0, "smooth")
	c._shot(go - 0.06, {"rel": {"a": a}, "eye": [Vector3(-3.0, 1.9, -3.4), Vector3(-1.6, 1.7, -4.2)], "look": {"a": s, "h": 0.9}, "fov": [52, 48], "hand": 0.6})
	# E · the drone comes back from behind: second bonk, Alice falls
	var back: float = go + 1.3
	c._flights.append([back - 0.25, back + 0.25, "drone", Vector3(-1.5, 2.6, rz + 9.0), {"a": a, "s": "head"}, 0.3, 0.8])
	c._cue(back + 0.25, "event", "drone", {"action": "impact", "position": {"a": a, "s": "head"}})
	c._cue(back + 0.25, "sound", "hit", {"a": a}, 0.9, 1.1)
	c._cue(back + 0.25, "stars", {"a": a, "s": "over"}, 5)
	c._cue(back + 0.25, "shake", 0.45)
	c._do(a, back + 0.25, "hit", 1.2, s)
	c._knock(a, back + 0.25, 1.2, Vector3(0.2, 0, -1))
	c._stun(a, back + 0.6, 3.0)
	_flash(back + 0.25, 0.06, Color(0.75, 0.95, 1.0))
	c._shot(back - 0.2, {"rel": {"a": a}, "eye": [Vector3(1.6, 1.1, -2.1), Vector3(1.4, 1.15, -1.8)], "look": {"a": a, "h": 1.3}, "fov": [38, 36], "hand": 0.5, "roll": [0, -6]})
	# F · stop, thumbs up, eyes glint
	var cool: float = back + 0.75
	c._move(s, go + 1.25, cool, _r(0.7, 8.6), "out")
	c._face(s, cool - 0.1, "at", a)
	c._do(s, cool, "unset", ["boost_time"])
	c._do(s, cool + 0.05, "emote", "thumbsup")
	c._shot(cool, {"rel": {"a": s}, "eye": [Vector3(-1.0, 1.25, -2.3), Vector3(-0.8, 1.32, -1.95)], "look": {"a": s, "h": 1.3}, "fov": [36, 32], "hand": 0.3, "safe": false})
	_glint(cool + 0.1, cool + 0.8, s, 1.0)
	_bolt(cool + 0.3, 0.25, 1.0)
	_flash(t_ink - 0.06, 0.12)
	# INK · skating past with the drone overhead, Alice staggering blind
	var ink: float = t_ink
	c._do(s, ink, "emote", "")
	_jump(s, ink, _ink(-3.0, 0, 0.6))
	_jump(a, ink, _ink(1.5, 0, -0.4))
	c._do(s, ink, "state", {"boost_time": 6.0})
	c._face(s, ink, "move")
	c._move(s, ink + 0.01, ink + 2.5, _ink(0.6, 0, 0.9), "linear")
	c._face(a, ink, "dir", Vector3(-0.7, 0, 0.5))
	c._do(a, ink, "stun", true)
	c._do(a, ink, "state", {"blind": 3.0})
	c._flights.append([ink + 0.01, ink + 2.5, "drone", _ink(-2.6, 2.2, 0.6), _ink(1.0, 2.45, 0.9), 0.15, 0.0])
	_burst(ink, _ink(1.5, 1.7, -0.4), Vector3.UP, 10, 0.8, {"spread": 0.6, "lift": 0.8, "gravity": 0.3, "drag": 0.6, "life": 2.6, "size": 0.1, "swirl": 2.0, "radius": 0.5})
	_burst(ink + 0.1, _ink(-2.6, 0.1, 0.6), Vector3(-1, 0.3, 0), 16, 1.6, {"spread": 0.5, "lift": 0.5, "gravity": 0.6, "drag": 0.8, "life": 2.4, "size": 0.07})
	c._shot(ink, {"eye": [_ink(-0.4, 1.0, 6.6), _ink(-0.1, 1.0, 6.3)], "look": [_ink(-0.6, 1.1, 0.0), _ink(-0.2, 1.1, 0.0)], "fov": 42, "hand": 0.1, "safe": false})



# ---------------------------------------------------------------- LYSIA ---
# Mécanique, électricité et surchauffe : elle se branche, surchauffe sous la
# pluie qui s'évapore, fonce sur Alice et la repousse dans une décharge.
func _write_lysia() -> void :
	var c: Node3D = cinema
	c._put(s, _r(-0.4, 0.0))
	c._face(s, 0.0, "dir", Vector3(0.4, 0, 1))
	c._do(s, 0.0, "state", {"lms": true, "outlet_time": 3.0})
	c._put(a, _r(0.4, 6.0))
	c._face(a, 0.0, "at", s)
	c._do(a, 0.0, "mood", "menace")
	# A · plugged, the current runs through her armour
	c._shot(3.4, {"rel": {"a": s}, "eye": [Vector3(-1.0, 0.9, 1.25), Vector3(-0.8, 0.95, 1.05)], "look": {"a": s, "h": 0.95}, "fov": [38, 34], "hand": 0.35})
	for k: int in range(5): _later(3.42 + 0.12 * float(k), "cue", {"who": s, "cue": "volt"})
	c._cue(3.45, "sound", "xray", {"a": s}, 0.8, 0.7)
	_later(3.6, "cue", {"who": s, "cue": "steam"})
	_bolt(3.7, 0.18, 0.8)
	# B · eyes, x-ray scan
	c._do(s, 4.05, "unset", ["outlet_time"])
	c._do(s, 4.05, "mood", "determined")
	c._move(a, 4.0, 4.9, _r(0.3, 4.2), "smooth")
	c._face(s, 4.1, "at", a)
	_closeup(4.1, s, Vector3(0.1, 0, 1), 1.0, 1.05, 28.0)
	_glint(4.15, 4.85, s, 1.15)
	# C · overheat charge into Alice
	var dash: float = 4.9
	c._do(s, dash, "state", {"overheat_charge": 0.5})
	c._cue(dash, "event", "overheat_charge", {"position": {"a": s}})
	c._cue(dash, "sound", "boost", {"a": s}, 0.9, 0.8)
	c._cue(dash, "rush", 0.8)
	c._move(s, dash, dash + 0.3, _r(0.15, 3.0), "dash")
	c._cue(dash + 0.3, "word", "zap", {"a": a, "h": 2.2}, Color("bff6ff"), 1.05)
	c._cue(dash + 0.3, "shake", 0.5)
	c._cue(dash + 0.3, "sound", "hit", {"a": a}, 1.0, 0.8)
	c._do(a, dash + 0.3, "hit", 1.1, s)
	c._stun(a, dash + 0.3, 1.6)
	_flash(dash + 0.3, 0.07, Color(0.75, 1.0, 0.95))
	for k: int in range(4): _later(dash + 0.3 + 0.1 * float(k), "bolts", {"at": {"a": a, "h": 1.2}, "color": Color("bff6ff"), "count": 3, "radius": 0.6, "size": 0.9})
	_smear(dash, dash + 0.3, Vector2(0.0, 0.0))
	c._shot(dash - 0.05, {"rel": {"mid": [s, a]}, "eye": [Vector3(3.0, 0.9, -0.6), Vector3(2.7, 0.95, -0.2)], "look": {"mid": [s, a], "h": 1.15}, "fov": [46, 42], "hand": 0.6})
	# D · overheat: the rain turns to steam
	var heat: float = 5.55
	c._do(s, heat, "unset", ["overheat_charge"])
	c._do(s, heat, "state", {"overheat_time": 1.6})
	c._cue(heat, "event", "overheat", {"position": {"a": s}, "active": true})
	c._cue(heat, "pulse", Color(1.0, 0.5, 0.15, 0.35), 0.9)
	c._cue(heat + 0.1, "word", "hot", {"a": s, "h": 2.3}, Color("ffcf8a"), 1.0)
	for k: int in range(4): _later(heat + 0.08 + 0.18 * float(k), "cue", {"who": s, "cue": "steam"})
	c._shot(heat, {"rel": {"a": s}, "eye": [Vector3(-1.3, 0.6, 1.9), Vector3(-1.05, 0.75, 1.6)], "look": {"a": s, "h": 1.15}, "fov": [42, 38], "hand": 0.45})
	# E · consommation: the push, an electric blast across the yard
	var push: float = 6.55
	c._do(s, push - 0.12, "unset", ["overheat_time"])
	c._cue(push - 0.12, "event", "overheat", {"position": {"a": s}, "active": false})
	c._do(s, push - 0.1, "trigger", "consommation")
	c._cue(push, "word", "push", {"a": s, "h": 2.3}, Color("a6f0d8"), 1.15)
	c._cue(push, "sound", "ground_impact", {"a": a}, 1.0, 0.75)
	c._cue(push, "sound", "xray", {"a": a}, 1.0, 1.3)
	c._cue(push, "shake", 0.75)
	c._cue(push, "impact", 0.8, false)
	c._do(a, push, "hit", 1.3, s)
	c._do(a, push, "stun", false)
	c._do(a, push, "state", {"forced_time": 0.9, "force_name": "knock"})
	c._do(a, push + 0.9, "unset", ["forced_time", "force_name"])
	var thrown: float = maxf(5.0, minf(11.5, room - 1.5))
	c._move(a, push, push + 0.85, _r(0.6, thrown), "out")
	c._stun(a, push + 0.9, 3.0)
	_flash(push, 0.1, Color(0.8, 1.0, 0.98))
	_rain_burst(push, _r(0.2, 3.6, 1.2), 0.8)
	for k: int in range(6): _later(push + 0.06 * float(k), "bolts", {"at": {"a": a, "h": 1.1}, "color": Color("d9fbff"), "count": 3, "radius": 0.7, "size": 1.0})
	_burst(push, _r(0.2, 3.6, 1.0), Vector3(0, 0.3, 1), 26, 6.5, {"spread": 0.6, "lift": 1.4, "gravity": 6.0, "life": 1.5, "size": 0.11})
	_smear(push, push + 0.3, Vector2(0.06, 0.0))
	c._shot(push - 0.2, {"rel": {"a": s}, "eye": [Vector3(3.6, 1.2, 1.4), Vector3(4.2, 1.15, 3.0)], "look": {"a": a, "h": 1.0}, "fov": [44, 52], "hand": 0.7})
	# E2 · riding along with Alice to the crash, still crackling
	var land: float = push + 0.85
	# chase camera inside the measured free corridor (no wall between it and her)
	c._shot(push + 0.3, {"rel": {"a": a}, "eye": [Vector3(0.9, 1.5, -2.3), Vector3(0.75, 1.25, -1.7)], "look": {"a": a, "h": 0.85}, "fov": [48, 42], "hand": 0.6})
	_smear(push + 0.3, push + 0.75, Vector2(0.045, 0.0))
	c._cue(land, "dust_ring", {"a": a}, 1.3)
	c._cue(land, "sound", "ground_impact", {"a": a}, 0.9, 0.85)
	c._cue(land, "shake", 0.4)
	c._cue(land + 0.08, "stars", {"a": a, "s": "over"}, 4)
	_burst(land, _r(0.6, thrown, 0.2), Vector3(0, 1, -0.3), 18, 3.6, {"spread": 1.0, "lift": 1.8, "gravity": 8.0, "life": 1.2, "size": 0.09})
	for k: int in range(3): _later(land + 0.05 + 0.12 * float(k), "bolts", {"at": {"a": a, "h": 0.6}, "color": Color("d9fbff"), "count": 2, "radius": 0.6, "size": 0.7})
	# F · venting, sparks, a calm look back
	var vent: float = 7.65
	c._do(s, vent, "mood", "calm")
	_later(vent + 0.55, "cue", {"who": s, "cue": "steam"})
	_later(vent + 0.3, "cue", {"who": s, "cue": "spark_r"})
	_closeup(vent, s, Vector3(0.1, 0, 1), 1.0, 1.35, 32.0)
	_glint(vent + 0.1, vent + 0.85, s, 1.0)
	_bolt(vent + 0.4, 0.25, 1.1)
	_flash(t_ink - 0.06, 0.12)
	# INK · the push, frozen in black lightning
	var ink: float = t_ink
	_jump(s, ink, _ink(-1.3, 0, 0.0))
	_jump(a, ink, _ink(0.9, 0.35, 0.0))
	c._face(s, ink, "dir", Vector3(1, 0, 0))
	c._face(a, ink, "dir", Vector3(-1, 0, 0))
	c._do(s, ink - 0.06, "trigger", "consommation")
	_hold_pose(s, ink + 0.32, ink + 2.6)
	c._do(a, ink, "stun", false)
	c._do(a, ink, "state", {"forced_time": 3.0, "force_name": "knock", "grounded": false})
	c._move(a, ink + 0.01, ink + 2.5, _ink(2.0, 0.7, 0.0), "out")
	_tilt(ink, ink + 2.6, a, Vector3(0, 0, -0.35), Vector3(0, 0, -0.65))
	for k: int in range(9): _later(ink + 0.05 + 0.25 * float(k), "bolts", {"at": _ink(0.0, 1.15, 0.0), "color": Color("d9fbff"), "count": 3, "radius": 1.0, "size": 1.3})
	_burst(ink, _ink(0.6, 1.0, 0.0), Vector3(1, 0.2, 0), 26, 2.6, {"spread": 0.7, "lift": 0.6, "gravity": 0.5, "drag": 0.8, "life": 2.6, "size": 0.1})
	c._shot(ink, {"eye": [_ink(0.2, 1.05, 6.2), _ink(0.25, 1.05, 5.8)], "look": [_ink(0.2, 1.0, 0.0), _ink(0.3, 1.0, 0.0)], "fov": 42, "hand": 0.1, "safe": false})



# ----------------------------------------------------------------- ELLY ---
# Soin et arme à feu : blessée, elle se soigne, esquive la griffe et arrête
# Alice net d'un tir de fusil à pompe.
func _write_elly() -> void :
	var c: Node3D = cinema
	c._put(s, _r(0.0, 0.0))
	c._face(s, 0.0, "dir", Vector3(0, 0, 1))
	c._do(s, 0.0, "state", {"lms": true, "second_life": true})
	c._do(s, 0.0, "mood", "hurt")
	c._put(a, _r(0.3, 6.5))
	c._face(a, 0.0, "at", s)
	c._do(a, 0.0, "mood", "menace")
	# A · hurt, the heal zone blooms
	c._do(s, 3.32, "trigger", "zone de soin")
	_later(3.5, "cue", {"who": s, "cue": "heal_ring"})
	c._cue(3.5, "sound", "heal", {"a": s}, 0.9, 1.0)
	c._cue(3.6, "pulse", Color(0.45, 1.0, 0.75, 0.25), 0.8)
	c._shot(3.4, {"rel": {"a": s}, "eye": [Vector3(1.3, 0.55, 1.6), Vector3(1.1, 0.7, 1.35)], "look": {"a": s, "h": 1.0}, "fov": [40, 36], "hand": 0.35})
	# B · she rises: eyes
	c._do(s, 4.4, "unset", ["second_life"])
	c._do(s, 4.4, "mood", "determined")
	c._move(a, 4.2, 5.0, _r(0.2, 2.6), "smooth")
	_closeup(4.5, s, Vector3(0, 0, 1), 1.0, 1.3, 30.0)
	_glint(4.55, 5.1, s, 1.1)
	# C · the claw, the dodge
	var swing: float = 5.2
	c._move(a, swing - 0.15, swing + 0.05, _r(0.1, 1.5), "dash")
	c._do(a, swing, "trigger", "slash")
	c._do(s, swing + 0.02, "trigger", "dodge")
	c._move(s, swing + 0.02, swing + 0.34, _r(-1.3, -0.9), "out")
	c._cue(swing + 0.02, "event", "dodge", {"position": {"a": s}})
	c._cue(swing + 0.12, "word", "miss", {"a": s, "h": 2.2}, PAPER, 0.9)
	_smear(swing, swing + 0.25, Vector2(-0.04, 0.0))
	c._shot(swing - 0.15, {"rel": {"mid": [s, a]}, "eye": [Vector3(-3.0, 1.1, 0.4), Vector3(-2.7, 1.15, 0.1)], "look": {"mid": [s, a], "h": 1.2}, "fov": [44, 42], "hand": 0.6})
	# D · aim, close on the barrel
	var aim: float = 5.75
	c._face(s, aim - 0.2, "at", a)
	c._shot(aim, {"rel": {"a": s}, "eye": [Vector3(0.55, 1.45, 0.55), Vector3(0.45, 1.42, 0.45)], "look": {"a": a, "h": 1.3}, "fov": [30, 26], "hand": 0.3})
	_glint(aim + 0.05, aim + 0.5, s, 0.9)
	# E · BANG
	var bang: float = 6.15
	c._do(s, bang - 0.16, "trigger", "shotgun")
	c._cue(bang, "event", "tracer", {"from": {"a": s, "h": 1.3, "o": Vector3(0, 0, 0.6)}, "to": {"a": a, "h": 1.2}, "duration": 0.2})
	c._blow(bang + 0.02, a, s, "gun", Color("ffe6a0"), 1.5)
	c._cue(bang, "sound", "shotgun", {"a": s}, 1.0, 0.95)
	c._cue(bang, "frame", Color(1.0, 0.95, 0.8, 0.35), 0.08)
	c._cue(bang, "shake", 0.7)
	_flash(bang, 0.08, Color(1.0, 0.92, 0.7))
	c._do(a, bang + 0.02, "state", {"blind": 3.0})
	c._knock(a, bang + 0.02, 4.0, Vector3(0, 0, 1))
	c._stun(a, bang + 0.5, 3.0)
	_rain_burst(bang, _r(-0.4, 1.0, 1.3), 0.6)
	_burst(bang + 0.03, _r(-1.0, -0.6, 1.25), Vector3(1, 0.8, -0.3), 2, 2.6, {"spread": 0.3, "lift": 2.0, "gravity": 9.0, "life": 1.2, "size": 0.06, "colors": [Color("c2462e"), Color("d9a43a")]})
	_burst(bang + 0.02, _r(0.0, 2.2, 1.2), Vector3(0, 0.2, 1), 20, 6.0, {"spread": 0.6, "lift": 1.2, "gravity": 6.0, "life": 1.4, "size": 0.1})
	c._shot(bang - 0.2, {"rel": {"a": s}, "eye": [Vector3(-1.6, 1.25, -1.4), Vector3(-1.9, 1.2, -1.9)], "look": {"a": s, "h": 1.25, "o": Vector3(0, 0, 1.2)}, "fov": [40, 46], "hand": 0.8})
	# F · smoke from the barrel, a nod
	var cool: float = 7.15
	c._do(s, cool, "mood", "smile")
	for k: int in range(3): _later(cool + 0.1 + 0.25 * float(k), "smoke", {"who": s})
	_closeup(cool, s, Vector3(0, 0, 1), -1.0, 1.9, 34.0)
	_glint(cool + 0.1, cool + 0.8, s, 1.0)
	# G · walking off, healing pluses, Alice down
	var leave: float = 7.85
	c._do(s, leave, "emote", "thumbsup")
	c._shot(leave, {"rel": {"a": s}, "eye": [Vector3(1.1, 0.4, 2.9), Vector3(0.9, 0.45, 2.5)], "look": {"a": s, "h": 1.5}, "fov": [44, 40], "hand": 0.4})
	_later(leave + 0.3, "pluses", {"at": {"a": s, "h": 1.4}, "count": 4})
	_bolt(leave + 0.4, 0.28, 1.2)
	_flash(t_ink - 0.06, 0.12)
	# INK · the shot, frozen: muzzle blast and Alice thrown back
	var ink: float = t_ink
	c._do(s, ink, "emote", "")
	_jump(s, ink, _ink(-1.4, 0, 0.0))
	_jump(a, ink, _ink(1.25, 0.25, 0.0))
	c._face(s, ink, "dir", Vector3(1, 0, 0))
	c._face(a, ink, "dir", Vector3(-1, 0, 0))
	c._do(s, ink - 0.02, "trigger", "shotgun")
	_hold_pose(s, ink + 0.01, ink + 2.6)
	c._do(a, ink, "stun", false)
	c._do(a, ink, "state", {"forced_time": 3.0, "force_name": "knock", "grounded": false})
	c._move(a, ink + 0.01, ink + 2.5, _ink(2.1, 0.55, 0.0), "out")
	_tilt(ink, ink + 2.6, a, Vector3(0, 0, -0.4), Vector3(0, 0, -0.75))
	_burst(ink, _ink(-0.2, 1.3, 0.0), Vector3(1, 0.05, 0), 30, 4.5, {"spread": 0.35, "lift": 0.2, "gravity": 0.3, "drag": 1.6, "life": 2.6, "size": 0.07})
	_burst(ink + 0.02, _ink(-0.9, 1.35, 0.0), Vector3(-0.3, 1, 0.2), 2, 2.2, {"spread": 0.2, "lift": 1.2, "gravity": 3.0, "drag": 0.3, "life": 2.6, "size": 0.08})
	c._shot(ink, {"eye": [_ink(0.0, 1.15, 6.4), _ink(0.05, 1.15, 6.0)], "look": [_ink(0.0, 1.05, 0.0), _ink(0.1, 1.05, 0.0)], "fov": 42, "hand": 0.1, "safe": false})



# ------------------------------------------------------------- BLEUETTE ---
# Courage et boosts : elle tremble, croque son chocolat, se répète qu'elle peut
# le faire et file si vite qu'Alice s'étale dans une flaque.
func _write_bleuette() -> void :
	var c: Node3D = cinema
	c._put(s, _r(0.0, 0.0))
	c._face(s, 0.0, "at", a)
	c._do(s, 0.0, "state", {"lms": true})
	c._do(s, 0.0, "mood", "fear")
	c._put(a, _r(0.2, 2.6))
	c._face(a, 0.0, "at", s)
	c._do(a, 0.0, "mood", "menace")
	# A · trembling, Alice looming (low angle from Bleuette)
	c._do(s, 3.35, "emote", "fear")
	c._move(a, 3.4, 4.3, _r(0.15, 1.85), "smooth")
	c._shot(3.4, {"rel": {"a": s}, "eye": [Vector3(0.5, 0.95, -0.75), Vector3(0.45, 0.9, -0.62)], "look": {"a": a, "h": 1.55}, "fov": [46, 42], "hand": 0.4, "roll": [-4, -6]})
	_glint(3.45, 4.2, a, 1.0)
	_later(3.6, "cue", {"who": s, "cue": "sweat"})
	_bolt(3.75, 0.22, 1.0)
	# B · the chocolate
	var bite: float = 4.2
	c._do(s, bite, "emote", "")
	c._do(s, bite, "state", {"chocolate_eating": 1.2})
	c._ramp(s, bite, bite + 1.1, "chocolate_eating", 1.2, 0.0)
	c._cue(bite, "sound", "heal", {"a": s}, 0.6, 1.2)
	_later(bite + 0.4, "cue", {"who": s, "cue": "crumbs"})
	_later(bite + 0.75, "cue", {"who": s, "cue": "crumbs"})
	c._shot(bite, {"rel": {"a": s, "s": "eyes"}, "eye": [Vector3(0.55, -0.1, 1.35), Vector3(0.45, -0.1, 1.15)], "look": {"a": s, "s": "mouth"}, "fov": [32, 29], "hand": 0.3})
	# C · "Je peux le faire !": the eyes light up
	var brave: float = 5.3
	c._do(s, brave, "mood", "determined")
	c._do(s, brave, "trigger", "je peux le faire !")
	c._cue(brave + 0.35, "pulse", Color(0.55, 0.75, 1.0, 0.35), 0.9)
	c._cue(brave + 0.35, "pillars", {"a": s}, Color("a9c8ff"), 7, 0.7)
	c._cue(brave + 0.35, "sparkles", {"a": s, "h": 1.0}, Color("cfe0ff"), 8, 0.8)
	c._cue(brave + 0.35, "sound", "encourage", {"a": s}, 1.0, 1.1)
	c._cue(brave + 0.35, "shake", 0.3)
	_closeup(brave, s, Vector3(0, 0, 1), 1.0, 1.05, 28.0)
	_glint(brave + 0.35, brave + 1.05, s, 1.15)
	# D · Alice lunges, Bleuette is already gone: the faceplant
	var lunge: float = 6.45
	c._do(s, lunge - 0.1, "state", {"speed_boost": 6.0})
	c._move(a, lunge - 0.05, lunge + 0.2, _r(0.05, 0.6), "dash")
	c._do(a, lunge, "trigger", "slash")
	c._face(s, lunge, "move")
	c._move(s, lunge, lunge + 0.28, _r(-1.6, -0.6), "dash")
	c._cue(lunge + 0.12, "word", "miss", {"a": a, "h": 2.2}, PAPER, 0.9)
	_later(lunge + 0.04, "cue", {"who": s, "cue": "afterimage"})
	c._move(s, lunge + 0.28, lunge + 0.6, _r(-2.2, 2.2), "linear")
	c._move(s, lunge + 0.6, lunge + 1.0, _r(-0.4, 5.0), "linear")
	_later(lunge + 0.3, "trail", {"who": s, "socket": "foot_r", "seconds": 0.8, "width": 0.16})
	var trip: float = lunge + 0.42
	c._do(a, trip, "trigger", "slash")
	c._move(a, trip, trip + 0.35, _r(-0.5, -0.4), "dash")
	c._do(a, trip + 0.3, "state", {"forced_time": 0.6, "force_name": "knock"})
	c._do(a, trip + 0.9, "unset", ["forced_time", "force_name"])
	c._do(a, trip + 0.9, "life", "downed")
	c._cue(trip + 0.4, "sound", "ground_impact", {"a": a}, 1.0, 0.9)
	c._cue(trip + 0.4, "dust_ring", {"a": a}, 1.1)
	c._cue(trip + 0.45, "stars", {"a": a, "s": "over"}, 5)
	c._cue(trip + 0.4, "shake", 0.45)
	_rain_burst(trip + 0.4, _r(-0.5, -0.4, 0.3), 0.7)
	_burst(trip + 0.4, _r(-0.5, -0.4, 0.1), Vector3.UP, 20, 2.6, {"spread": 1.0, "lift": 2.0, "gravity": 7.0, "life": 1.1, "size": 0.07, "colors": [Color("9fb0c8"), Color("cfdaea")]})
	c._shot(lunge - 0.1, {"rel": {"mid": [s, a]}, "eye": [Vector3(3.2, 1.0, 0.4), Vector3(2.9, 1.0, -0.2)], "look": {"mid": [s, a], "h": 1.0}, "fov": [46, 44], "hand": 0.6})
	# E · a cheer from afar, hearts in the rain
	var cheer: float = lunge + 1.1
	c._do(s, cheer, "unset", ["speed_boost"])
	c._face(s, cheer, "at", a)
	c._do(s, cheer, "mood", "grin")
	c._do(s, cheer + 0.05, "emote", "cheer")
	c._shot(cheer, {"rel": {"a": s}, "eye": [Vector3(-1.1, 0.7, -2.2), Vector3(-0.95, 0.8, -1.9)], "look": {"a": s, "h": 1.1}, "fov": [42, 38], "hand": 0.35})
	_glint(cheer + 0.4, cheer + 1.0, s, 1.0)
	_bolt(cheer + 0.5, 0.25, 1.0)
	_flash(t_ink - 0.06, 0.12)
	# INK · Bleuette jumping for joy, Alice flat on her face behind
	var ink: float = t_ink
	_jump(s, ink, _ink(-0.9, 0, 0.4))
	_jump(a, ink, _ink(1.3, 0, -0.6))
	c._face(s, ink, "dir", Vector3(0.3, 0, 1))
	c._do(s, ink + 0.03, "emote", "")
	c._do(s, ink + 0.06, "emote", "cheer")
	c._do(a, ink, "life", "downed")
	c._face(a, ink, "dir", Vector3(-1, 0, 0.2))
	_burst(ink + 0.08, _ink(-0.9, 1.7, 0.4), Vector3.UP, 18, 2.6, {"spread": 1.6, "lift": 1.6, "gravity": 2.2, "drag": 0.7, "life": 2.5, "size": 0.1})
	c._shot(ink, {"eye": [_ink(0.1, 1.0, 6.2), _ink(0.15, 1.0, 5.8)], "look": [_ink(0.1, 0.95, 0.0), _ink(0.15, 0.95, 0.0)], "fov": 42, "hand": 0.1, "safe": false})



# ------------------------------------------------------------ CONSTRUCTION -

func _build_nodes() -> void :
	var c: Node3D = cinema
	# full-screen grade, below the film bars and fades of the UI (layer 10)
	_grade_layer = CanvasLayer.new();_grade_layer.name = "VictoryGrade";_grade_layer.layer = 9
	c.add_child(_grade_layer)
	_grade = ColorRect.new();_grade.name = "Grade";_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_grade_material = ShaderMaterial.new();_grade_material.shader = GradeShader
	if ResourceLoader.exists("res://ui/art/ink_noise.png"): _grade_material.set_shader_parameter("paper_tex", load("res://ui/art/ink_noise.png"))
	_grade_material.set_shader_parameter("taps", 4 if _light_profile else 8)
	_grade.material = _grade_material
	_grade_layer.add_child(_grade)
	_build_letters()
	_build_tv_room()
	_build_ink_room()
	_build_rain_lights()
	_build_glints()
	_build_audio()


func _build_letters() -> void :
	_letters = VBoxContainer.new();_letters.name = "Letters";_letters.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_letters.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_letters.anchor_top = 0.15;_letters.anchor_bottom = 0.15
	_letters.offset_left = -400;_letters.offset_right = 400;_letters.offset_top = 0;_letters.offset_bottom = 80
	_letters.alignment = BoxContainer.ALIGNMENT_BEGIN
	_letters.add_theme_constant_override("separation", -4)
	_grade_layer.add_child(_letters)
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Courier New", "Courier", "Liberation Mono", "DejaVu Sans Mono", "Noto Sans Mono", "monospace"])
	font.font_weight = 700
	for index: int in range(2):
		var label: Label = Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 30)
		label.add_theme_color_override("font_color", Color("d9ecff"))
		label.add_theme_color_override("font_shadow_color", Color(0.45, 0.7, 1.0, 0.55))
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 0)
		label.add_theme_constant_override("shadow_outline_size", 9)
		_letters.add_child(label)
		if index == 0: _letter_top = label
		else: _letter_name = label
	_letter_top.text = PaperLanguage.t("Ultime souvenir :")
	_letter_name.text = "@" + person
	_letters.modulate.a = 0.0


func _box(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new();mesh.size = size
	node.mesh = mesh;node.position = at;node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


func _plain(color: Color, unshaded: bool = true, cull: int = BaseMaterial3D.CULL_BACK) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.disable_fog = true
	material.cull_mode = cull
	material.roughness = 0.7
	return material


func _set_root(at: Vector3) -> Node3D:
	var root: Node3D = Node3D.new()
	cinema.add_child(root)
	root.global_transform = Transform3D(Basis(cinema.right, Vector3.UP, cinema.forward), cinema._world_spot(at))
	return root


func _build_tv_room() -> void :
	_tv_room = _set_root(_tv(0, 0, 0));_tv_room.name = "VictoryTv"
	# the void around everything
	_box(_tv_room, Vector3(0, 6, 0), Vector3(60, 24, 60), _plain(Color(0.0, 0.0, 0.004), true, BaseMaterial3D.CULL_FRONT))
	var floor_node: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new();plane.size = Vector2(46, 46);plane.subdivide_width = 1;plane.subdivide_depth = 1
	floor_node.mesh = plane
	_tv_floor = ShaderMaterial.new();_tv_floor.shader = FloorShader
	_tv_floor.set_shader_parameter("tile_color", Color("3f62c8"))
	_tv_floor.set_shader_parameter("light_center", Vector2(0.0, 1.4))
	floor_node.material_override = _tv_floor
	_tv_room.add_child(floor_node)
	var body_material: StandardMaterial3D = _plain(Color("17161c"), false)
	body_material.roughness = 0.42
	if ResourceLoader.exists("res://ui/art/ink_noise.png"):
		body_material.albedo_texture = load("res://ui/art/ink_noise.png")
		body_material.uv1_scale = Vector3(2, 2, 2)
		body_material.albedo_color = Color("1d1c24")
	var trim: StandardMaterial3D = _plain(Color("0c0b10"), false)
	# stand, pole and set
	_box(_tv_room, Vector3(0, 0.03, 0), Vector3(0.9, 0.06, 0.7), trim)
	_box(_tv_room, Vector3(0, 0.24, 0), Vector3(0.16, 0.42, 0.16), trim)
	_box(_tv_room, Vector3(0, 0.47, -0.05), Vector3(1.05, 0.06, 0.85), trim)
	_box(_tv_room, Vector3(0, 0.98, -0.1), Vector3(1.42, 1.0, 1.05), body_material)
	_box(_tv_room, Vector3(0, 0.98, 0.43), Vector3(1.32, 0.92, 0.04), trim)
	for side: float in [-1.0, 1.0]: _box(_tv_room, Vector3(side * 0.6, 0.98, 0.44), Vector3(0.04, 0.86, 0.02), body_material)
	_tv_rim = _box(_tv_room, Vector3(0, 1.485, 0.36), Vector3(1.38, 0.018, 0.05), _plain(Color(0.55, 0.75, 1.0)))
	var screen: MeshInstance3D = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new();quad.size = Vector2(1.12, 0.8)
	screen.mesh = quad;screen.position = Vector3(0, 0.98, 0.455)
	_tv_screen = ShaderMaterial.new();_tv_screen.shader = TvShader
	var art_path: String = "res://ui/art/%s_bust.png" % person
	if ResourceLoader.exists(art_path): _tv_screen.set_shader_parameter("art", load(art_path))
	_tv_screen.set_shader_parameter("emblem", EMBLEM.get(person, Color("6f8cff")))
	screen.material_override = _tv_screen
	_tv_room.add_child(screen)
	_tv_glow = OmniLight3D.new();_tv_glow.position = Vector3(0, 1.0, 1.4);_tv_glow.omni_range = 4.0;_tv_glow.light_energy = 1.2;_tv_glow.light_color = Color("dfe8ff")
	_tv_room.add_child(_tv_glow)
	var top: OmniLight3D = OmniLight3D.new();top.position = Vector3(0, 2.6, -0.9);top.omni_range = 3.4;top.light_energy = 1.6;top.light_color = Color("7f9cff")
	_tv_room.add_child(top)


func _build_ink_room() -> void :
	_ink_room = _set_root(_ink(0, 0, 0));_ink_room.name = "VictoryInk"
	_box(_ink_room, Vector3(0, 4, 0), Vector3(80, 40, 80), _plain(KEY, true, BaseMaterial3D.CULL_FRONT))


func _build_rain_lights() -> void :
	_rain_lights = _set_root(_r(0, 0));_rain_lights.name = "VictoryRain"
	_door_light = OmniLight3D.new();_door_light.position = Vector3(0, 1.7, float(cinema._length) - rz + 0.4);_door_light.omni_range = 7.0;_door_light.light_energy = 2.4;_door_light.light_color = Color("e6eeff")
	_rain_lights.add_child(_door_light)
	_moon = OmniLight3D.new();_moon.position = Vector3(-4.0, 9.0, 9.0);_moon.omni_range = 34.0;_moon.light_energy = 1.9;_moon.light_color = Color("9fb6ff")
	_moon.position = _moon.position.rotated(Vector3.UP, turn)
	_rain_lights.add_child(_moon)
	_flash_light = OmniLight3D.new();_flash_light.position = Vector3(4.0, 9.0, 6.0);_flash_light.omni_range = 40.0;_flash_light.light_energy = 0.0;_flash_light.light_color = Color("e8efff")
	_rain_lights.add_child(_flash_light)
	# OM lighting: a cold rim behind the subject and a soft key from the camera side
	_back_light = OmniLight3D.new();_back_light.omni_range = 6.0;_back_light.light_energy = 4.6;_back_light.light_color = Color("d4e2ff")
	_rain_lights.add_child(_back_light)
	_key_light = OmniLight3D.new();_key_light.omni_range = 6.5;_key_light.light_energy = 1.4;_key_light.light_color = Color("a9b7d6")
	_rain_lights.add_child(_key_light)
	# the open door glows like the exit ring of Outcome Memories
	_door_card = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new();quad.size = Vector2(3.0, 3.4)
	_door_card.mesh = quad
	var glow: StandardMaterial3D = _plain(Color(1.6, 1.7, 1.9))
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var soft: GradientTexture2D = GradientTexture2D.new()
	soft.fill = GradientTexture2D.FILL_SQUARE;soft.fill_from = Vector2(0.5, 0.5);soft.fill_to = Vector2(1.0, 0.5)
	var fade: Gradient = Gradient.new();fade.set_color(0, Color(1, 1, 1, 1));fade.set_color(1, Color(1, 1, 1, 0));fade.add_point(0.55, Color(1, 1, 1, 0.85))
	soft.gradient = fade
	glow.albedo_texture = soft
	_door_card.material_override = glow
	_door_card.position = Vector3(0, 1.6, float(cinema._length) - rz - 0.35)
	_door_card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rain_lights.add_child(_door_card)


func _build_debris() -> void :
	var total: int = 0
	for item: Burst in _bursts:
		item.first = total
		total += item.count
	_debris = MultiMeshInstance3D.new();_debris.name = "VictoryDebris"
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = _scrap_mesh()
	multimesh.instance_count = maxi(1, total)
	multimesh.visible_instance_count = 0
	_debris.multimesh = multimesh
	_debris.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_debris.custom_aabb = AABB(Vector3(-4000, -500, -4000), Vector3(8000, 2000, 8000))
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.85
	_debris.material_override = material
	cinema.add_child(_debris)


# A torn paper scrap: an irregular flat pentagon.
func _scrap_mesh() -> ArrayMesh:
	var points: PackedVector2Array = PackedVector2Array([Vector2(-0.5, -0.38), Vector2(0.44, -0.5), Vector2(0.52, 0.12), Vector2(0.08, 0.5), Vector2(-0.46, 0.3)])
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.BACK)
	for k: int in range(1, points.size() - 1):
		for p: Vector2 in [points[0], points[k], points[k + 1]]:
			st.add_vertex(Vector3(p.x, p.y, 0.0))
	return st.commit()


func _build_glints() -> void :
	var dot: GradientTexture2D = GradientTexture2D.new()
	dot.fill = GradientTexture2D.FILL_RADIAL;dot.fill_from = Vector2(0.5, 0.5);dot.fill_to = Vector2(1.0, 0.5);dot.width = 64;dot.height = 64
	var ramp: Gradient = Gradient.new();ramp.set_color(0, Color(1, 1, 1, 1));ramp.set_color(1, Color(1, 1, 1, 0));ramp.add_point(0.18, Color(1, 1, 1, 0.9));ramp.add_point(0.45, Color(1, 1, 1, 0.22))
	dot.gradient = ramp
	for k: int in range(6):
		var node: MeshInstance3D = MeshInstance3D.new()
		var quad: QuadMesh = QuadMesh.new()
		var streak: bool = k >= 4
		quad.size = Vector2(0.62, 0.007) if streak else Vector2(0.042, 0.042)
		node.mesh = quad
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.no_depth_test = true
		material.disable_fog = true
		material.albedo_texture = dot
		material.render_priority = 8
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visible = false
		cinema.add_child(node)
		_glint_nodes.append(node)


func _build_audio() -> void :
	_music = _player("music", "res://audio/victory/%s.ogg" % person, &"PaperMusic")
	_rain_player = _player("rain", MUSIC_DIR + "rain.ogg", &"PaperWorld")
	_tv_player = _player("tv", MUSIC_DIR + "tv.ogg", &"PaperWorld")
	_thunder_player = _player("thunder", MUSIC_DIR + "thunder.ogg", &"PaperWorld")


func _player(label: String, path: String, bus: StringName) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = "Victory_" + label
	player.bus = bus if AudioServer.get_bus_index(bus) >= 0 else &"Master"
	player.volume_db = -80.0
	if ResourceLoader.exists(path) and not bool(world.get("dedicated")): player.stream = load(path) as AudioStream
	if player.stream is AudioStreamOggVorbis: (player.stream as AudioStreamOggVorbis).loop = label in ["rain", "tv"]
	cinema.add_child(player)
	return player



# ----------------------------------------------------------------- UPDATE --

func update(t: float, delta: float) -> void :
	if not active or not is_instance_valid(_grade): return
	var camera: Camera3D = world.camera
	_reset_bodies(t)
	_apply_spins(t)
	_apply_tilts(t)
	_run_fx(t, delta)
	_place_debris(t)
	_place_glints(t, camera)
	_update_sets(t)
	_update_grade(t, delta, camera)
	_update_audio(t, delta)


func _look_at_time(t: float) -> String:
	if t < t_cut: return "tv"
	if t < t_ink: return "rain"
	if t < t_back: return "ink"
	return "tv"


# Spins and tilts are layered over the pose the film step placed. While the film
# is paused (cinémathèque) no step runs, so the bodies they touch are put back
# first: otherwise the tilt would compound frame after frame.
func _reset_bodies(t: float) -> void :
	var touched: Dictionary = {}
	for spin: Array in _spins:
		if t >= float(spin[0]) and t <= float(spin[1]) + 0.02: touched[int(spin[2])] = true
	for tilt: Array in _tilts:
		if t >= float(tilt[0]) and t <= float(tilt[1]): touched[int(tilt[2])] = true
	var at: float = maxf(float(cinema._time), 0.0)
	for index: Variant in touched:
		var take: Variant = cinema.takes[int(index)]
		take.visual.position = cinema._world_spot(cinema._where(take, at))
		take.visual.rotation = Vector3(0.0, take.yaw, 0.0)


func _apply_spins(t: float) -> void :
	for spin: Array in _spins:
		var t0: float = float(spin[0])
		var t1: float = float(spin[1])
		if t < t0 or t > t1 + 0.02: continue
		var take: Variant = cinema.takes[int(spin[2])]
		var u: float = cinema._ease((t - t0) / maxf(0.01, t1 - t0), str(spin[4]))
		take.visual.rotation.y = take.yaw + float(spin[3]) * TAU * u


func _apply_tilts(t: float) -> void :
	for tilt: Array in _tilts:
		var t0: float = float(tilt[0])
		var t1: float = float(tilt[1])
		if t < t0 or t > t1: continue
		var u: float = cinema._ease((t - t0) / maxf(0.01, t1 - t0), str(tilt[6]))
		var euler: Vector3 = (tilt[3] as Vector3).lerp(tilt[4], u)
		var visual: Node3D = cinema.takes[int(tilt[2])].visual
		# pitch about the film's right axis, roll about its forward axis, pivoting on the hips
		var spin: float = float(tilt[5])
		var bend: Basis = Basis(cinema.right.rotated(Vector3.UP, spin), euler.x) * Basis(cinema.forward.rotated(Vector3.UP, spin), euler.z)
		var pivot: Vector3 = Vector3.UP * 0.95
		var base: Transform3D = visual.transform
		visual.transform = Transform3D(bend * base.basis, base.origin + pivot - bend * pivot)


func _run_fx(t: float, delta: float) -> void :
	if t < _fx_time - 0.0005:
		_fx_cursor = 0
		while _fx_cursor < _fx.size() and float(_fx[_fx_cursor][0]) <= t: _fx_cursor += 1
		_fx_time = t
		return
	var live: bool = delta > 0.0 and t - _fx_time <= 0.3
	while _fx_cursor < _fx.size() and float(_fx[_fx_cursor][0]) <= t:
		if live: _fire(str(_fx[_fx_cursor][1]), _fx[_fx_cursor][2])
		_fx_cursor += 1
	_fx_time = t


func _fire(kind: String, data: Dictionary) -> void :
	var comic: Node = cinema._comic()
	if comic == null: return
	match kind:
		"bolts": comic.bolts(cinema._spot(data.at), data.get("color", Color.WHITE), int(data.get("count", 3)), float(data.get("radius", 0.6)), float(data.get("size", 0.8)))
		"sparkles": comic.sparkles(cinema._spot(data.at), data.get("color", GOLD), int(data.get("count", 5)), float(data.get("radius", 0.7)))
		"pluses": comic.pluses(cinema._spot(data.at), int(data.get("count", 3)))
		"pop": comic.pop(cinema._spot(data.at), Vector3.UP, data.get("color", PAPER), float(data.get("scale", 1.0)))
		"whoosh": comic.whoosh(cinema._spot(data.at), cinema._world_direction(data.get("dir", Vector3.FORWARD)), data.get("color", PAPER), int(data.get("count", 5)), float(data.get("length", 1.5)))
		"trail":
			var visual: Node3D = cinema.takes[int(data.who)].visual
			comic.trail(visual, str(data.socket), Color(EMBLEM.get(person, PAPER).lerp(Color.WHITE, 0.45), 0.9), float(data.get("seconds", 0.3)), float(data.get("width", 0.15)))
		"cue":
			var visual: Node3D = cinema.takes[int(data.who)].visual
			comic.cue(visual, str(data.cue))
		"smoke":
			var visual: Node3D = cinema.takes[int(data.who)].visual
			var muzzle: Vector3 = visual.attachment_position("shotgun_muzzle")
			comic.mark(6, muzzle + Vector3.UP * 0.1, Color("d9d4cc", 0.55), 0.15, 0.6, 0.9, {"vel": Vector3.UP * 0.7, "drag": 1.5, "fade": 0.3, "ink": Color("6f6a66")})
		"mute_words":
			if "_word_clock" in comic: comic.set("_word_clock", float(data.get("seconds", 1.0)))
		"thunder":
			if is_instance_valid(_thunder_player) and _thunder_player.stream and is_instance_valid(world.audio):
				_thunder_player.volume_db = float(world.audio.volume_to_db(float(world.audio.effects_volume))) + linear_to_db(0.6 * float(data.get("gain", 1.0)))
				_thunder_player.play(0.0)
		"sound":
			cinema._sound(str(data.kind), cinema._spot(data.at), float(data.get("gain", 1.0)), float(data.get("pitch", 1.0)))



func _place_debris(t: float) -> void :
	if not is_instance_valid(_debris): return
	var multimesh: MultiMesh = _debris.multimesh
	var shown: int = 0
	var axis_basis: Basis = Basis(cinema.right, Vector3.UP, cinema.forward)
	for item: Burst in _bursts:
		var age: float = t - item.start
		if age < 0.0 or age > item.life: continue
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		for k: int in range(item.count):
			rng.seed = item.seed * 131 + k * 977
			var dir: Vector3 = item.direction
			var jitter: Vector3 = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * item.spread
			var velocity: Vector3 = (dir + jitter).normalized() * item.speed * rng.randf_range(0.45, 1.15) + Vector3.UP * item.lift * rng.randf_range(0.4, 1.2)
			var travel: float = (1.0 - exp( - item.drag * age)) / maxf(item.drag, 0.001)
			var local: Vector3 = item.origin + velocity * travel + Vector3.DOWN * 0.5 * item.gravity * age * age * rng.randf_range(0.6, 1.0)
			if item.swirl > 0.0:
				var angle: float = rng.randf() * TAU + item.swirl * age * rng.randf_range(0.8, 1.2)
				var radius: float = item.radius * rng.randf_range(0.6, 1.3) * (1.0 + 0.35 * age)
				local = item.origin + Vector3(cos(angle) * radius, velocity.y * travel * 0.6 + rng.randf_range(0.0, 1.4), sin(angle) * radius) + Vector3.DOWN * 0.5 * item.gravity * age * age
			var spin_axis: Vector3 = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
			if spin_axis.length_squared() < 0.01: spin_axis = Vector3.UP
			var turn: float = rng.randf() * TAU + age * rng.randf_range(5.0, 14.0)
			var fade: float = 1.0 - smoothstep(item.life * 0.75, item.life, age)
			var size: float = item.size * rng.randf_range(0.55, 1.4) * fade
			var basis: Basis = (axis_basis * Basis(spin_axis, turn)).scaled(Vector3(size, size * rng.randf_range(0.6, 1.1), size))
			var world_at: Vector3 = cinema._world_spot(local)
			multimesh.set_instance_transform(shown, Transform3D(basis, world_at))
			multimesh.set_instance_color(shown, item.colors[k % item.colors.size()])
			shown += 1
			if shown >= multimesh.instance_count: break
	multimesh.visible_instance_count = shown


func _eye_points(visual: Node3D) -> Array[Vector3]:
	var points: Array[Vector3] = []
	# one eyelid mesh per eye under the head's "Eyelids" attachment; only the
	# first one keeps the name "Lid" (its sibling gets a generated name)
	for holder: Node in visual.find_children("Eyelids", "BoneAttachment3D", true, false):
		for child: Node in holder.get_children():
			var mesh: MeshInstance3D = child as MeshInstance3D
			if mesh and mesh.mesh: points.append(mesh.global_transform * mesh.mesh.get_aabb().get_center())
	if points.size() >= 2: return points
	points.clear()
	var eyes: Vector3 = visual.socket_position("eyes")
	var head: Variant = visual.get("_head")
	var side: Vector3 = (head as Node3D).global_transform.basis.x.normalized() if head is Node3D else visual.global_transform.basis.x.normalized()
	points.append(eyes - side * 0.045)
	points.append(eyes + side * 0.045)
	return points


func _place_glints(t: float, camera: Camera3D) -> void :
	var used: int = 0
	var streak_used: int = 0
	for glint: Array in _glints:
		var t0: float = float(glint[0])
		var t1: float = float(glint[1])
		if t < t0 or t > t1: continue
		var take: Variant = cinema.takes[int(glint[2])]
		var visual: Node3D = take.visual
		if not visual.visible: continue
		var u: float = (t - t0) / maxf(0.01, t1 - t0)
		var level: float = smoothstep(0.0, 0.18, u) * (1.0 - smoothstep(0.8, 1.0, u))
		var who: String = str(take.person)
		var color: Color = GLINT.get(who, Color.WHITE)
		var to_camera: Vector3 = (camera.global_position - visual.global_position).normalized()
		var points: Array[Vector3] = _eye_points(visual)
		for p: Vector3 in points:
			if used >= 4: break
			var node: MeshInstance3D = _glint_nodes[used]
			node.visible = true
			node.global_position = p + to_camera * 0.03
			node.scale = Vector3.ONE * float(glint[3]) * (0.8 + 0.35 * level)
			(node.material_override as StandardMaterial3D).albedo_color = Color(color.r * 1.6, color.g * 1.6, color.b * 1.6, level)
			used += 1
			if streak_used < 2:
				var streak: MeshInstance3D = _glint_nodes[4 + streak_used]
				streak.visible = true
				streak.global_position = p + to_camera * 0.035
				streak.scale = Vector3(float(glint[3]) * (0.6 + 0.6 * level), 1.0, 1.0)
				(streak.material_override as StandardMaterial3D).albedo_color = Color(color.r, color.g, color.b, level * 0.75)
				streak_used += 1
	for k: int in range(used, 4): _glint_nodes[k].visible = false
	for k: int in range(streak_used, 2): _glint_nodes[4 + k].visible = false


func _update_sets(t: float) -> void :
	var look: String = _look_at_time(t)
	_tv_room.visible = look == "tv"
	_ink_room.visible = look == "ink"
	_rain_lights.visible = look == "rain"
	if look == "ink": _shadows_disable()
	else: _restore_shadows()
	# television
	var second: bool = t >= t_back
	var local: float = t - (t_back if second else 0.0)
	var power: float = smoothstep(0.0, 0.45, t) if not second else 1.0
	var art: float = smoothstep(0.45, 0.95, t) if not second else 1.0
	var red: float = smoothstep(1.6, 2.15, t) if not second else 0.0
	var collapse: float = 0.0 if not second else smoothstep(t_off - t_back, t_off - t_back + 0.45, local)
	_tv_screen.set_shader_parameter("power", power)
	_tv_screen.set_shader_parameter("art_amount", art * (1.0 - 0.6 * red))
	_tv_screen.set_shader_parameter("red", red)
	_tv_screen.set_shader_parameter("collapse", collapse)
	_tv_screen.set_shader_parameter("clock", t)
	_tv_screen.set_shader_parameter("snow", 1.0 - 0.5 * art)
	var blue: Color = Color("3f62c8")
	var floor_color: Color = blue.lerp(Color("7a3fc0"), smoothstep(1.6, 1.85, t)).lerp(Color("d0213a"), smoothstep(1.85, 2.1, t)) if not second else blue
	_tv_floor.set_shader_parameter("tile_color", floor_color)
	_tv_floor.set_shader_parameter("clock", t)
	var floor_level: float = smoothstep(0.05, 0.7, t) if not second else 1.0 - smoothstep(0.1, 0.5, collapse)
	_tv_floor.set_shader_parameter("brightness", floor_level * (0.9 + 0.1 * sin(t * 37.0)))
	_tv_glow.light_energy = 1.3 * power * (1.0 - collapse) * (0.85 + 0.15 * sin(t * 53.0))
	_tv_glow.light_color = Color("dfe8ff").lerp(Color("ff5060"), red)
	(_tv_rim.material_override as StandardMaterial3D).albedo_color = Color(0.55, 0.75, 1.0).lerp(Color(1.0, 0.3, 0.35), red) * (0.35 + 0.65 * floor_level)
	# lettering ("Inspired by")
	var letters: float = smoothstep(0.75, 1.05, t) * (1.0 - smoothstep(1.85, 2.15, t)) if not second else 0.0
	_letters.modulate = Color(1.0, 1.0 - 0.5 * red, 1.0 - 0.5 * red, letters)
	# rain lights and lightning
	var door: float = 1.0 - smoothstep(3.25, 3.4, t)
	_door_light.light_energy = 2.6 * door + 0.4
	_door_card.visible = t < 3.45
	if look == "rain":
		var camera: Camera3D = world.camera
		var target: Vector3 = cinema.camera_focus
		var away: Vector3 = target - camera.global_position
		away.y = 0.0
		away = away.normalized() if away.length_squared() > 0.0001 else cinema.forward
		var side: Vector3 = Vector3.UP.cross(away).normalized()
		_back_light.global_position = target + away * 1.7 + Vector3.UP * 1.1 - side * 0.7
		_key_light.global_position = camera.global_position.lerp(target, 0.4) + Vector3.UP * 0.9 + side * 0.9
	(_door_card.material_override as StandardMaterial3D).albedo_color = Color(1.5, 1.6, 1.8, smoothstep(t_rain, t_rain + 0.6, t) * (0.75 + 0.25 * sin(t * 31.0)))
	_hide_sign(true)
	var strike: float = 0.0
	for bolt: Array in _lightning:
		var age: float = t - float(bolt[0])
		if age < 0.0 or age > float(bolt[1]): continue
		var u: float = age / float(bolt[1])
		strike = maxf(strike, float(bolt[2]) * (1.0 - u) * (0.6 + 0.4 * sin(u * 40.0)))
	_flash_light.light_energy = 4.0 * strike * (0.4 if _reduced else 1.0)


func _flash_level(t: float) -> Color:
	var best: Color = Color(1, 1, 1, 0)
	for flash: Array in _flashes:
		var age: float = t - float(flash[0])
		var seconds: float = float(flash[1])
		if age < -0.04 or age > seconds: continue
		var level: float = smoothstep(-0.04, 0.0, age) * (1.0 - smoothstep(0.0, seconds, age))
		if level > best.a: best = Color(flash[2], level)
	if _reduced: best.a *= 0.35
	return best


func _update_grade(t: float, delta: float, camera: Camera3D) -> void :
	var m: ShaderMaterial = _grade_material
	var look: String = _look_at_time(t)
	var size: Vector2 = _grade.get_viewport_rect().size
	m.set_shader_parameter("aspect", size.x / maxf(1.0, size.y))
	m.set_shader_parameter("clock", t)
	m.set_shader_parameter("rain_mix", 1.0 if look == "rain" else 0.0)
	m.set_shader_parameter("ink_mix", 1.0 if look == "ink" else 0.0)
	var exposure: float = 1.0
	if look == "rain": exposure = smoothstep(t_rain, t_rain + 0.55, t) * 1.0
	m.set_shader_parameter("exposure", exposure * (0.8 if snowy else 1.1))
	m.set_shader_parameter("flakes", 1.0 if snowy else 0.0)
	m.set_shader_parameter("rain", 1.0 if look == "rain" else 0.0)
	var burst: float = 0.0
	var center: Vector2 = Vector2(0.5, 0.5)
	for item: Array in _rain_bursts:
		var age: float = t - float(item[0])
		if age < 0.0 or age > float(item[2]): continue
		var level: float = 1.0 - age / float(item[2])
		if level > burst:
			burst = level
			var world_at: Vector3 = cinema._world_spot(item[1])
			if not camera.is_position_behind(world_at): center = camera.unproject_position(world_at) / size
	m.set_shader_parameter("rain_burst", burst * burst)
	m.set_shader_parameter("rain_center", center)
	# motion smear: authored windows plus camera rotation speed
	var authored: Vector2 = Vector2.ZERO
	for item: Array in _smears:
		if t >= float(item[0]) and t <= float(item[1]):
			var u: float = (t - float(item[0])) / maxf(0.01, float(item[1]) - float(item[0]))
			authored = (item[2] as Vector2) * sin(u * PI)
	var forward: Vector3 = - camera.global_transform.basis.z
	var shot: int = int(cinema.last_shot)
	var auto: Vector2 = Vector2.ZERO
	if delta > 0.0 and shot == _prev_shot and _prev_forward != Vector3.ZERO:
		var turn: Vector3 = forward - _prev_forward
		auto = Vector2(turn.dot(camera.global_transform.basis.x), - turn.dot(camera.global_transform.basis.y)) / maxf(delta, 0.001) * 0.012
	_prev_forward = forward
	_prev_shot = shot
	_auto_smear = _auto_smear.lerp(auto.limit_length(0.05), 0.5)
	var smear: Vector2 = authored + _auto_smear
	m.set_shader_parameter("smear", smear if look == "rain" else smear * 0.3)
	m.set_shader_parameter("zoom_blur", 0.0)
	m.set_shader_parameter("aberration", (0.0 if _light_profile else 0.004 + smear.length() * 0.1) if look == "rain" else 0.0)
	# ink background ramp
	if look == "ink":
		var bg: Color = Color("f4efe4")
		for k: int in range(_bg.size()):
			var key: Array = _bg[k]
			if t >= float(key[0]):
				bg = key[1]
				if k + 1 < _bg.size():
					var next: Array = _bg[k + 1]
					var u: float = smoothstep(float(key[0]), float(next[0]), t)
					bg = (key[1] as Color).lerp(next[1], u)
		m.set_shader_parameter("ink_bg", bg)
		m.set_shader_parameter("ink_color", Color(0.015, 0.012, 0.02).lerp(Color(0.0, 0.0, 0.0), 1.0 - bg.get_luminance()))
		m.set_shader_parameter("ink_shadow", 0.18 * bg.get_luminance())
	m.set_shader_parameter("vignette", 0.55 if look == "rain" else 0.62 if look == "tv" else 0.18)
	m.set_shader_parameter("grain", 0.085 if look == "rain" else 0.06 if look == "tv" else 0.045)
	var glitch: float = 0.0
	if look == "tv" and t < t_cut: glitch = smoothstep(1.7, 2.2, t)
	if t >= t_back: glitch = 0.25 * smoothstep(t_off - 0.1, t_off + 0.3, t)
	m.set_shader_parameter("glitch", glitch * (0.3 if _reduced else 1.0))
	var flash: Color = _flash_level(t)
	m.set_shader_parameter("flash_color", flash)


func _update_audio(t: float, delta: float) -> void :
	if bool(world.get("dedicated")): return
	var audio: Node = world.audio
	var music_db: float = -80.0
	var sfx_db: float = -80.0
	# the scores are mastered at -18 LUFS like the game's tracks: same level as PaperAudio.MUSIC_LEVEL
	if is_instance_valid(audio):
		music_db = float(audio.volume_to_db(float(audio.music_volume))) + linear_to_db(0.82)
		sfx_db = float(audio.volume_to_db(float(audio.effects_volume)))
	var paused: bool = delta <= 0.0
	if is_instance_valid(_thunder_player) and _thunder_player.playing: _thunder_player.stream_paused = paused
	_sync(_music, t, music_db, paused, false)
	var look: String = _look_at_time(t)
	var rain_level: float = 0.0
	if look == "rain": rain_level = smoothstep(t_rain, t_rain + 0.5, t)
	_sync(_rain_player, t, sfx_db + linear_to_db(maxf(0.0001, rain_level * (0.22 if snowy else 0.55))), paused or rain_level <= 0.0, true)
	var tv_level: float = 0.0
	if t < t_cut: tv_level = smoothstep(0.0, 0.3, t) * (1.0 - 0.4 * smoothstep(1.7, 2.2, t))
	elif t >= t_back: tv_level = 1.0 - smoothstep(t_off, t_off + 0.4, t)
	_sync(_tv_player, t, sfx_db + linear_to_db(maxf(0.0001, tv_level * 0.22)), paused or tv_level <= 0.0, true)


func _sync(player: AudioStreamPlayer, t: float, volume: float, paused: bool, looped: bool) -> void :
	if not is_instance_valid(player) or player.stream == null: return
	var stream_length: float = player.stream.get_length()
	var at: float = fposmod(t, stream_length) if looped and stream_length > 0.0 else t
	if not looped and (stream_length <= 0.0 or t >= stream_length - 0.02):
		if player.playing: player.stop()
		return
	player.volume_db = volume
	if paused:
		if player.playing: player.stream_paused = true
		return
	player.stream_paused = false
	if not player.playing: player.play(at)
	elif absf(player.get_playback_position() - at) > 0.12 and not (looped and absf(player.get_playback_position() - at) > stream_length - 0.2): player.seek(at)


func _hide_sign(on: bool) -> void :
	var items: Variant = world.get("map_interactables") if is_instance_valid(world) else null
	if not is_instance_valid(items): return
	var sign: Variant = items.get("exit_sign")
	var ring: Variant = items.get("exit_glow")
	if is_instance_valid(sign): (sign as Node3D).visible = not on
	if is_instance_valid(ring) and on: (ring as Node3D).visible = false
	_sign_hidden = on


func _shadows_disable() -> void :
	if _shadows_off: return
	_shadows_off = true
	for take: Variant in cinema.takes: take.visual.blob_shadow = false


func _restore_shadows() -> void :
	if not _shadows_off: return
	_shadows_off = false
	if not is_instance_valid(cinema): return
	for take: Variant in cinema.takes:
		if is_instance_valid(take.visual): take.visual.blob_shadow = true
