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
const AnimLibrary = preload("res://anim_library.gd")
const FV = preload("res://anim_set_film_victory.gd")

# 0.17 · les corps de ces films ne bougent que par les clips écrits pour eux
# (anim_set_film_victory.gd) : pendant le film, l'attente du jeu (transferts de
# poids, balancement, regards au hasard) est mise à zéro et les gestes d'attente
# coupés ; « grounded »: false coupe les pas que la démarche du jeu compterait
# pendant un déplacement. Tout est rendu à l'arrêt du film.
const FILM_STYLE: Dictionary = {"contra": 0.0, "shift_rate": 0.0, "idle_sway": 0.0, "idle_bounce": 0.0, "look_rate": 0.0}
const AUTHORED: Array[String] = ["Usayuko", "Simon", "Ashura", "Lysia", "Elly", "Bleuette"]

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
# painted eyes below the rig's "eyes" socket (metres, measured on the eyelid patches)
const EYE_DROP: Dictionary = {"Ashura": -0.07, "Usayuko": -0.05, "Lysia": -0.02, "Elly": -0.12, "Bleuette": -0.05, "Simon": -0.2}
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
var _saved_styles: Array = []



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
	if person in AUTHORED: _film_bodies()
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
	_restore_bodies()
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
# (film axes), `side` shifts the camera to one cheek, `rise` lifts the camera
# above the eyes (negative: a low angle looking up at a bowed head).
func _closeup(t: float, who: int, facing: Vector3, side: float = 1.0, distance: float = 0.95, fov: float = 26.0, rise: float = 0.05) -> void :
	var front: Vector3 = Vector3(facing.x, 0.0, facing.z).normalized()
	var cheek: Vector3 = Vector3.UP.cross(front).normalized() * side * 0.3
	var from: Vector3 = front * distance + cheek + Vector3.UP * rise
	var to: Vector3 = front * distance * 0.82 + cheek * 0.8 + Vector3.UP * (rise - 0.01)
	# the rig's "eyes" socket sits above the painted eyes of the supplied models
	var drop: float = float(EYE_DROP.get(str(cinema.takes[who].person), 0.0))
	cinema._shot(t, {"rel": {"a": who, "s": "eyes", "h": drop}, "eye": [from, to], "look": {"a": who, "s": "eyes", "h": drop}, "fov": [fov, fov - 3.0], "hand": 0.25})


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


# Lance un clip du film à l'instant où ses clés commencent ("at" de
# anim_set_film_victory.gd), ou à `at` pour les clips de la partie papier.
func _play(i: int, clip: String, at: float = -1.0) -> void :
	var start: float = at if at >= 0.0 else float(AnimLibrary.source(clip).get("at", 0.0))
	cinema._do(i, start, "play", clip)


func _film_bodies() -> void :
	_saved_styles.clear()
	for take: Variant in cinema.takes:
		var visual: PaperVisual = take.visual
		var style: Variant = visual.get("_style")
		var saved: Dictionary = {}
		if style is Dictionary:
			for key: String in FILM_STYLE:
				saved[key] = (style as Dictionary).get(key)
				(style as Dictionary)[key] = FILM_STYLE[key]
		_saved_styles.append([visual, saved, visual.fidgets])
		visual.fidgets = false
	for i: int in range(cinema.takes.size()): cinema._do(i, 0.0, "state", {"grounded": false})


func _restore_bodies() -> void :
	for entry: Array in _saved_styles:
		var visual: Variant = entry[0]
		if not is_instance_valid(visual): continue
		var style: Variant = (visual as PaperVisual).get("_style")
		if style is Dictionary:
			for key: Variant in (entry[1] as Dictionary):
				if entry[1][key] == null: (style as Dictionary).erase(key)
				else: (style as Dictionary)[key] = entry[1][key]
		(visual as PaperVisual).fidgets = bool(entry[2])
	_saved_styles.clear()


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
	# before the heroes' last triggers (from ink - 0.06), so their clip words stay off the paper
	_later(ink - 0.1, "mute_words", {"seconds": 2.7})
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
# Vitesse. Coincé face à Alice, il sautille, nerveux, puis se met en position de
# départ. Elle fond sur lui et tranche une image rémanente : il est déjà passé
# (5,32) et le souffle la fait tourner. Il dérape loin derrière, agite le doigt,
# tourne autour d'elle jusqu'à ce qu'elle tombe sur les fesses, puis file dans
# la nuit, buste couché, bras en arrière.
func _write_simon() -> void :
	var c: Node3D = cinema
	var tint: Color = GLINT.Simon
	var go: float = FV.S_GO
	var center: Vector3 = _r(0.1, 1.4)
	c._put(s, _r(0.0, 0.0))
	c._face(s, 0.0, "dir", Vector3(0, 0, 1))
	c._put(a, _r(0.1, 3.2))
	c._face(a, 0.0, "dir", Vector3(0, 0, -1))
	_play(s, "fv_simon_rain")
	_play(a, "fv_simon_alice_rain")
	# A · par-dessus l'épaule d'Alice : il sautille, cherche une sortie
	c._shot(3.32, {"rel": {"a": a}, "eye": [Vector3(0.58, 1.55, 1.3), Vector3(0.52, 1.5, 1.15)], "look": {"a": s, "h": 1.0}, "fov": [40, 37], "hand": 0.4})
	# B · ses yeux se plantent dans les siens
	_closeup(3.95, s, Vector3(0, 0, 1), 1.0, 1.0, 28.0)
	_glint(4.05, 4.75, s, 1.1)
	_bolt(4.35, 0.22, 0.9)
	# C · au ras du sol derrière lui : « à vos marques », elle avance, fond sur lui
	c._shot(4.6, {"rel": {"a": s}, "eye": [Vector3(-1.05, 0.34, -1.05), Vector3(-0.95, 0.32, -0.95)], "look": {"mid": [s, a], "h": 0.75}, "fov": [48, 46], "hand": 0.4})
	c._cue(4.62, "event", "boost_charge", {"position": {"a": s}, "active": true})
	for k: int in range(5): _later(4.66 + 0.13 * float(k), "bolts", {"at": {"a": s, "h": 0.25}, "color": Color("d9c8ff"), "count": 2, "radius": 0.4, "size": 0.5})
	c._move(a, 4.62, 5.1, _r(0.1, 2.24), "linear")
	c._move(a, 5.12, 5.28, center, "out")
	_glint(4.9, 5.3, a, 0.9)
	# D · 5,32 · parti : la griffe tranche l'image rémanente
	_later(go, "pop", {"at": {"a": s, "h": 0.6}, "color": tint, "scale": 1.1})
	c._cue(go, "sound", "boost", {"a": s}, 1.0, 1.1)
	c._cue(go, "rush", 1.0)
	c._cue(go + 0.02, "shake", 0.35)
	_later(go, "cue", {"who": s, "cue": "afterimage"})
	_later(go + 0.06, "cue", {"who": s, "cue": "afterimage"})
	_later(go + 0.12, "cue", {"who": s, "cue": "afterimage"})
	_later(go + 0.02, "trail", {"who": s, "socket": "foot_r", "seconds": 0.5, "width": 0.22})
	_later(go + 0.02, "trail", {"who": s, "socket": "hand_l", "seconds": 0.5, "width": 0.18})
	c._cue(go + 0.02, "sound", "slash", {"a": a}, 0.8, 1.0)
	_later(go + 0.04, "whoosh", {"at": {"a": a, "h": 1.0, "o": Vector3(-0.8, 0, 0)}, "dir": Vector3(0, 0, 1), "color": tint, "count": 7, "length": 2.4})
	_burst(go + 0.06, _r(-0.6, 1.2, 0.3), Vector3(0, 0.4, 1), 26, 5.5, {"spread": 0.9, "lift": 2.2, "swirl": 5.0, "radius": 0.9, "life": 1.9, "size": 0.11})
	_rain_burst(go + 0.06, _r(-0.6, 1.2, 1.0), 0.7)
	_smear(go - 0.02, go + 0.3, Vector2(0.075, 0.0))
	c._face(s, go, "dir", Vector3(-0.55, 0, 1))
	c._move(s, go, go + 0.06, _r(-1.1, 1.3), "linear")
	c._face(s, go + 0.06, "dir", Vector3(0.07, 0, 1))
	var stop: float = _far(10.5)
	c._move(s, go + 0.06, FV.S_SKID, _r(-0.9, minf(4.0, stop - 2.0)), "linear")
	# le souffle la fait tourner sur elle-même (deux tours, et elle finit face à lui)
	c._face(a, go + 0.04, "dir", Vector3(0, 0, 1))
	_spin(go + 0.04, 6.2, a, 2.0, "out")
	_later(go + 0.15, "cue", {"who": a, "cue": "spin"})
	_later(go + 0.45, "cue", {"who": a, "cue": "spin"})
	c._cue(5.7, "stars", {"a": a, "s": "over"}, 4)
	c._shot(5.42, {"rel": {"a": a}, "eye": [Vector3(0.55, 1.2, -1.75), Vector3(0.45, 1.25, -1.5)], "look": {"a": a, "h": 1.25}, "fov": [40, 36], "hand": 0.4, "roll": [-4, 5]})
	# E · le dérapage : il glisse de travers vers la caméra, gerbes d'eau
	c._face(s, FV.S_SKID - 0.06, "dir", Vector3(-1, 0, 0))
	c._move(s, FV.S_SKID, FV.S_STOP, _r(-0.5, stop), "out")
	for k: int in range(7): _burst(FV.S_SKID + 0.1 * float(k), _r(-0.6 + 0.02 * float(k), lerpf(4.5, stop, 1.0 - pow(1.0 - float(k) / 7.0, 2.0)), 0.1), Vector3(0, 0.6, 1), 8, 2.6 - 0.25 * float(k), {"spread": 0.7, "lift": 1.6, "gravity": 7.0, "life": 0.7, "size": 0.05, "colors": [Color("cfdaea"), Color("9fb0c8")]})
	c._cue(FV.S_SKID, "sound", "step", {"a": s}, 0.8, 0.6)
	c._shot(5.95, {"eye": [_r(0.75, stop + 1.7, 0.42), _r(0.7, stop + 1.65, 0.45)], "look": {"a": s, "h": 0.65}, "fov": [44, 40], "hand": 0.3})
	# F · il se retourne vers elle et agite le doigt
	c._face(s, 6.3, "dir", Vector3(0, 0, -1))
	c._shot(6.42, {"rel": {"a": s}, "eye": [Vector3(0.38, 1.32, -1.75), Vector3(0.34, 1.3, -1.55)], "look": {"a": s, "h": 1.28}, "fov": [36, 34], "hand": 0.3})
	_glint(6.6, 7.1, s, 0.9)
	# G · la tornade : un tour et trois quarts autour d'elle, vue de haut
	var radius: float = 1.3
	var spin_start: float = FV.S_TORNADO + 0.06
	c._face(s, FV.S_TORNADO, "move")
	c._move(s, FV.S_TORNADO, spin_start, center + Vector3(0.0, 0.0, radius), "linear")
	var turns: int = 14
	for k: int in range(1, turns + 1):
		var angle: float = PI * 0.5 + 3.5 * PI * float(k) / float(turns)
		var t: float = lerpf(spin_start, FV.S_EXIT, float(k) / float(turns))
		c._move(s, t - (FV.S_EXIT - spin_start) / float(turns), t, center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius), "linear")
		if k % 2 == 0: _later(t, "cue", {"who": s, "cue": "afterimage"})
	c._cue(FV.S_TORNADO, "sound", "boost", {"a": s}, 0.8, 1.25)
	c._cue(FV.S_TORNADO + 0.1, "rush", 0.9)
	_spin(7.36, 8.0, a, 1.0, "in")
	_later(7.5, "cue", {"who": a, "cue": "spin"})
	_later(7.75, "cue", {"who": a, "cue": "spin"})
	c._cue(8.0, "sound", "ground_impact", {"a": a}, 0.7, 1.1)
	c._cue(8.0, "dust_ring", {"a": a}, 0.9)
	c._cue(8.08, "stars", {"a": a, "s": "over"}, 5)
	_burst(FV.S_TORNADO + 0.05, center + Vector3(0, 0.2, 0), Vector3.UP, 34, 2.4, {"spread": 0.3, "lift": 3.2, "swirl": 7.5, "radius": 1.4, "gravity": 1.2, "drag": 0.6, "life": 2.2, "size": 0.12})
	_rain_burst(FV.S_TORNADO + 0.1, center + Vector3(0, 1.0, 0), 0.9)
	c._shot(FV.S_TORNADO - 0.02, {"rel": {"a": a}, "eye": [Vector3(0.6, 4.6, 1.6), Vector3(0.45, 4.2, 1.3)], "look": {"a": a, "h": 0.4}, "fov": [54, 50], "hand": 0.5, "roll": [3, -5]})
	# H · il file dans la nuit : la caméra recule devant lui, au ras du sol
	var run_from: Vector3 = _r(0.15, 2.5)
	var run_to: Vector3 = _r(-0.35, minf(10.9, room))
	var run_end: float = FV.S_RUN + run_from.distance_to(run_to) / FV.S_RUN_SPEED
	c._move(s, FV.S_EXIT, FV.S_RUN, run_from, "linear")
	c._face(s, FV.S_EXIT + 0.05, "dir", Vector3(0, 0, 1))
	c._move(s, FV.S_RUN, run_end, run_to, "linear")
	c._cue(FV.S_RUN, "rush", 0.8)
	c._shot(FV.S_RUN, {"rel": {"a": s}, "eye": [Vector3(1.2, 0.62, 1.75), Vector3(1.1, 0.6, 1.5)], "look": {"a": s, "h": 0.75}, "fov": [48, 46], "hand": 0.6})
	_later(FV.S_RUN, "trail", {"who": s, "socket": "hand_l", "seconds": 1.0, "width": 0.14})
	_later(FV.S_RUN, "trail", {"who": s, "socket": "hand_r", "seconds": 1.0, "width": 0.14})
	_later(9.05, "cue", {"who": s, "cue": "afterimage"})
	_later(9.05, "whoosh", {"at": {"a": s, "h": 1.0}, "dir": Vector3(0, 0, -1), "color": PAPER, "count": 6, "length": 2.0})
	_smear(9.05, 9.35, Vector2(0.0, 0.04))
	_bolt(8.85, 0.3, 1.2)
	_flash(t_ink - 0.06, 0.14)
	# PAPIER · une foulée suspendue au ralenti ; derrière, Alice assise, étourdie
	var ink: float = t_ink
	_jump(s, ink, _ink(-0.7, 0, 0.6))
	_jump(a, ink, _ink(-2.1, 0, -0.9))
	c._face(s, ink, "dir", Vector3(1, 0, 0))
	c._face(a, ink, "dir", Vector3(0.6, 0, 0.8))
	_play(s, "fv_simon_ink", ink)
	_play(a, "fv_simon_alice_ink", ink)
	c._move(s, ink + 0.05, ink + 2.65, _ink(-0.7 + 0.92 * 2.6, 0, 0.6), "linear")
	_spin(ink, ink + 2.6, a, 0.75, "linear")
	_tilt(ink, ink + 2.6, a, Vector3(0, 0, -0.12), Vector3(0, 0, -0.3))
	_later(ink + 0.3, "cue", {"who": a, "cue": "spin"})
	c._cue(ink + 0.2, "stars", {"a": a, "s": "over"}, 5)
	for k: int in range(6):
		var x: float = 3.2 - 1.6 * float(k)
		_burst(ink + 0.04, _ink(x, 0.6, -0.4), Vector3(-1.0, 0.4, 0.0), 7, 0.6, {"spread": 1.0, "lift": 0.3, "gravity": 0.05, "drag": 0.4, "life": 2.6, "size": 0.09 + 0.02 * float(k % 3)})
	for k: int in range(5): _later(ink + 0.2 + 0.5 * float(k), "cue", {"who": s, "cue": "afterimage"})
	c._shot(ink, {"rel": {"a": s}, "eye": [Vector3(0.55, 1.0, 4.4), Vector3(0.45, 1.0, 4.2)], "look": {"a": s, "h": 0.9, "o": Vector3(0.6, 0, 0)}, "fov": 42, "hand": 0.1, "safe": false})



# -------------------------------------------------------------- USAYUKO ---
# Force. Alice abat sa griffe : il la bloque de l'avant-bras (3,62), plie sous
# le poids et sourit ; il la repousse (4,98), elle revient à la charge et
# s'empale sur son poing (5,75), traverse la cour et s'écrase (6,69). Il souffle
# sur ses phalanges qui fument, s'essuie le nez du pouce, poings sur les hanches.
func _write_usayuko() -> void :
	var c: Node3D = cinema
	var hit: float = FV.U_HIT
	c._put(s, _r(0.0, 0.0))
	c._face(s, 0.0, "dir", Vector3(0, 0, 1))
	c._put(a, _r(0.06, 0.86))
	c._face(a, 0.0, "dir", Vector3(0, 0, -1))
	_play(s, "fv_usayuko_rain")
	_play(a, "fv_usayuko_alice_rain")
	# A · profil, contre-plongée : la griffe tombe sur l'avant-bras
	c._shot(3.32, {"rel": {"mid": [s, a]}, "eye": [Vector3(3.0, 0.95, 0.25), Vector3(2.8, 1.0, 0.15)], "look": {"mid": [s, a], "h": 1.22}, "fov": [36, 34], "hand": 0.5})
	var block: float = 3.62
	c._cue(block, "sound", "block", {"mid": [s, a], "h": 1.3})
	c._cue(block, "shake", 0.45)
	_flash(block, 0.06, Color(1.0, 0.9, 0.6))
	_later(block, "pop", {"at": {"mid": [s, a], "h": 1.32}, "color": GOLD, "scale": 0.8})
	_burst(block, _r(0.04, 0.4, 1.32), Vector3(0.7, 0.5, 0.1), 16, 3.4, {"spread": 0.7, "lift": 1.0, "gravity": 5.0, "drag": 1.5, "life": 0.7, "size": 0.05, "colors": [GOLD, Color("fff2a8"), Color.WHITE]})
	# B · nez à nez, de profil : elle le force vers le bas, il lève les yeux vers
	# elle, serre les dents… et sourit ; les deux regards brillent
	c._shot(3.95, {"rel": {"mid": [s, a]}, "eye": [Vector3(1.25, 1.38, -0.1), Vector3(1.12, 1.38, -0.08)], "look": {"mid": [s, a], "h": 1.34, "o": Vector3(0, 0, -0.1)}, "fov": [31, 29], "hand": 0.25})
	_glint(4.15, 4.85, s, 1.15)
	_glint(4.25, 4.75, a, 0.85)
	_bolt(4.5, 0.25, 1.0)
	# C · par-dessus son épaule droite : il la repousse (4,98)
	c._shot(4.62, {"rel": {"a": s}, "eye": [Vector3(1.45, 1.45, -1.55), Vector3(1.35, 1.42, -1.42)], "look": {"mid": [s, a], "h": 1.3}, "fov": [40, 37], "hand": 0.4})
	var shove: float = 4.98
	c._cue(shove, "sound", "punch", {"a": a}, 0.7, 1.15)
	c._cue(shove, "shake", 0.4)
	c._cue(shove, "pulse", Color(1.0, 0.8, 0.35, 0.25), 0.6)
	_later(shove + 0.02, "whoosh", {"at": {"a": a, "h": 1.3}, "dir": Vector3(0, 0, 1), "color": PAPER, "count": 5, "length": 1.6})
	_rain_burst(shove, _r(0.05, 0.6, 1.4), 0.6)
	# D · il arme : le poing recule, l'air se met à trembler ; elle revient à la charge
	c._shot(5.28, {"rel": {"a": s}, "eye": [Vector3(0.66, 1.0, -1.05), Vector3(0.6, 0.98, -0.95)], "look": {"a": a, "h": 1.15}, "fov": [50, 47], "hand": 0.5})
	c._cue(5.32, "pulse", Color(1.0, 0.8, 0.35, 0.3), 0.8)
	c._cue(5.4, "shake", 0.15)
	c._cue(5.58, "shake", 0.2)
	_burst(5.3, _r(0.0, 0.0, 0.05), Vector3.UP, 16, 1.1, {"spread": 1.0, "lift": 2.0, "gravity": 1.6, "life": 1.0, "size": 0.06, "colors": [Color("7a7268"), Color("5a544c")]})
	# E · l'impact, serré, de profil : arrêt sur image
	c._shot(hit - 0.03, {"rel": {"mid": [s, a]}, "eye": [Vector3(2.45, 0.85, 0.1), Vector3(2.4, 0.86, 0.1)], "look": {"mid": [s, a], "h": 1.08}, "fov": [34, 33], "hand": 0.2})
	c._cue(hit, "pop", {"mid": [s, a], "h": 1.12}, Vector3(0, 0, 1), GOLD, 1.5)
	c._cue(hit, "impact", 0.9, true)
	c._cue(hit, "sound", "punch", {"a": a}, 1.0, 0.75)
	c._cue(hit, "sound", "ground_impact", {"a": a}, 1.0, 0.7)
	c._cue(hit, "shake", 0.9)
	c._cue(hit, "frame", Color(1, 1, 1, 0.5), 0.07)
	c._cue(hit + 0.02, "dust_ring", {"a": a}, 1.4)
	_flash(hit, 0.1)
	_rain_burst(hit, _r(0.03, 0.75, 1.15), 0.8)
	_burst(hit + 0.1, _r(0.03, 0.85, 1.1), Vector3(0, 0.25, 1), 30, 7.0, {"spread": 0.55, "lift": 1.6, "gravity": 7.0, "life": 1.7, "size": 0.12})
	# F · elle traverse la cour, pliée, et s'écrase
	var fly: float = hit + 0.12
	var land: float = maxf(5.0, minf(12.5, room - 1.2))
	c._move(a, fly, fly + 0.38, _r(0.03, lerpf(0.86, land, 0.48), 1.25), "out")
	c._move(a, fly + 0.38, 6.69, _r(0.0, land, 0.0), "in")
	c._move(a, 6.69, 6.95, _r(0.0, land + 0.55, 0.0), "out")
	var crash: float = 6.69
	c._cue(crash, "crack", {"a": a}, 1.8)
	c._cue(crash, "dust_ring", {"a": a}, 1.6)
	c._cue(crash, "sound", "ground_impact", {"a": a}, 1.0, 0.8)
	c._cue(crash, "shake", 0.6)
	c._cue(crash + 0.1, "stars", {"a": a, "s": "over"}, 4)
	_rain_burst(crash, _r(0.0, land, 0.4), 0.7)
	_burst(crash, _r(0.0, land, 0.2), Vector3(0, 1, 0.4), 22, 4.2, {"spread": 1.0, "lift": 2.0, "gravity": 8.0, "life": 1.3, "size": 0.1})
	_smear(fly, fly + 0.35, Vector2(0.05, 0.0))
	# dans le couloir libre mesuré devant la sortie : au-dessus d'elle, un peu en arrière
	c._shot(fly, {"rel": {"a": a}, "eye": [Vector3(0.7, 1.95, -1.75), Vector3(0.6, 2.05, -1.05)], "look": {"a": a, "h": 0.5}, "fov": [50, 48], "hand": 0.5})
	# le corps entier bascule en arrière pendant le vol (la robe suit), puis le
	# clip la pose sur le dos à l'atterrissage
	_tilt(fly, 6.4, a, Vector3.ZERO, Vector3(1.3, 0.0, 0.15), "out")
	_tilt(6.4, crash, a, Vector3(1.3, 0.0, 0.15), Vector3.ZERO, "smooth")
	# G · la vapeur sur les phalanges : il souffle, secoue la main, sourit
	c._shot(6.95, {"rel": {"a": s}, "eye": [Vector3(-0.55, 1.12, 1.25), Vector3(-0.5, 1.14, 1.12)], "look": {"a": s, "h": 1.42}, "fov": [34, 32], "hand": 0.3})
	for k: int in range(3): _later(7.08 + 0.18 * float(k), "smoke_hand", {"who": s, "socket": "hand_l"})
	_glint(7.6, 7.85, s, 0.9)
	# H · héros en contre-plongée sous l'éclair
	c._shot(7.85, {"rel": {"a": s}, "eye": [Vector3(-0.55, 0.6, 1.5), Vector3(-0.46, 0.64, 1.32)], "look": {"a": s, "h": 1.3}, "fov": [42, 40], "hand": 0.4})
	_bolt(8.2, 0.3, 1.3)
	_flash(t_ink - 0.06, 0.12)
	# PAPIER · le coup de poing en silhouette : pliée autour du poing, elle part
	var ink: float = t_ink
	_jump(s, ink, _ink(-1.0, 0, 0.0))
	_jump(a, ink, _ink(-0.1, 0, 0.0))
	c._face(s, ink, "dir", Vector3(1, 0, 0))
	c._face(a, ink, "dir", Vector3(-1, 0, 0))
	_play(s, "fv_usayuko_ink", ink)
	_play(a, "fv_usayuko_alice_ink", ink)
	c._move(a, ink + 0.01, ink + 2.5, _ink(1.25, 0.65, -0.2), "out")
	_tilt(ink, ink + 2.6, a, Vector3(0, 0, 0.25), Vector3(0, 0, 1.15))
	_burst(ink, _ink(-0.15, 1.1, 0.0), Vector3(1, 0.25, 0), 36, 3.6, {"spread": 0.6, "lift": 0.6, "gravity": 0.9, "drag": 0.9, "life": 2.6, "size": 0.13})
	_burst(ink + 0.02, _ink(-0.2, 1.15, 0.0), Vector3(1, 0.6, 0.1), 12, 2.4, {"spread": 0.5, "lift": 0.8, "gravity": 0.6, "drag": 0.7, "life": 2.6, "size": 0.26})
	c._shot(ink, {"eye": [_ink(0.0, 1.05, 4.7), _ink(0.1, 1.05, 4.4)], "look": [_ink(0.0, 1.0, 0.0), _ink(0.15, 1.0, 0.0)], "fov": 42, "hand": 0.1, "safe": false})



# --------------------------------------------------------------- ASHURA ---
# Drone et rollers. Un genou à terre sous la pluie, il revisse son drone ; il
# relève les yeux sur Alice sans lâcher sa vis, lance le drone en se relevant
# (BONK à 5,47), charge sur ses roues, tourne autour d'elle en patinant ; le
# drone revient lui cogner la nuque (8,35). Arrêt de hockeyeur, il rattrape le
# drone, pouce levé.
func _write_ashura() -> void :
	var c: Node3D = cinema
	var tint: Color = GLINT.Ashura
	var violet: Color = Color("c6b5f9")
	c._put(s, _r(0.0, 0.0))
	c._face(s, 0.0, "dir", Vector3(0, 0, 1))
	c._put(a, _r(0.42, 4.6))
	c._face(a, 0.0, "dir", Vector3(-0.08, 0, -1))
	_play(s, "fv_ashura_rain")
	_play(a, "fv_ashura_alice_rain")
	# Alice : trois pas lents (anim_set_film_victory : A_WALK, A_WALK_SPEED)
	var walk_end: float = FV.A_WALK + 2.0 * 0.55
	var stop_at: Vector3 = _r(0.42, 4.6 - FV.A_WALK_SPEED * (walk_end - 3.3))
	c._move(a, 3.3, walk_end, stop_at, "linear")
	c._move(a, walk_end, walk_end + 0.12, stop_at + Vector3(0, 0, -0.06), "out")
	# le drone au sol sous sa main gauche (la droite visse) ; à 4,8 il glisse
	# sur la paume droite, qui le lance
	var on_left: Dictionary = {"a": s, "s": "hand_l", "h": -0.09}
	var on_right: Dictionary = {"a": s, "s": "hand_r", "h": 0.07}
	c._flights.append([3.3, 4.8, "drone", on_left, on_left, 0.0, 0.0])
	c._flights.append([4.8, 4.92, "drone", on_left, on_right, 0.0, 0.0])
	var rest: Vector3 = _r(0.05, 0.42, 0.1)
	# A1 · au-dessus de son épaule : les mains au travail sur la carcasse mouillée
	c._shot(3.32, {"rel": {"a": s}, "eye": [Vector3(0.82, 1.22, 0.55), Vector3(0.74, 1.15, 0.5)], "look": {"a": s, "s": "hand_l", "h": 0.12}, "fov": [44, 41], "hand": 0.25})
	# A2 · par-dessus son épaule droite, au ras du sol : Alice approche au fond
	c._shot(3.72, {"rel": {"a": s}, "eye": [Vector3(-1.05, 0.48, -0.25), Vector3(-0.98, 0.46, -0.15)], "look": {"a": s, "h": 0.4, "o": Vector3(0.1, 0, 0.9)}, "fov": [46, 44], "hand": 0.3})
	for t: float in [3.556, 3.946]: _later(t, "cue", {"who": s, "cue": "spark_r"})
	for t: float in [3.43, 4.075, 4.463]: c._cue(t, "sound", "camera_place", {"a": s}, 0.35, 1.7)
	_rain_burst(3.85, rest + Vector3(0, 0.15, 0), 0.4)
	# B · les yeux montent avant la tête, et brillent
	_closeup(4.05, s, Vector3(0, 0, 1), 1.0, 1.05, 30.0, -0.3)
	_glint(4.15, 4.82, s, 1.1)
	_later(4.333, "cue", {"who": s, "cue": "spark_r"})
	# C · le lancer, de profil : le drone part de sa main (5,0) et file vers elle
	c._shot(FV.A_FLING, {"rel": {"mid": [s, a]}, "eye": [Vector3(3.7, 1.0, -0.45), Vector3(3.35, 1.1, -0.2)], "look": {"mid": [s, a], "h": 1.05}, "fov": [42, 40], "hand": 0.4})
	c._flights.append([4.92, FV.A_RELEASE, "drone", on_right, on_right, 0.0, 0.0])
	c._flights.append([FV.A_RELEASE, FV.A_BONK, "drone", _r(0.05, 0.55, 1.3), {"a": a, "s": "head"}, 0.35, 0.42])
	_later(FV.A_RELEASE, "cue", {"who": s, "cue": "drone_up"})
	c._cue(FV.A_RELEASE, "sound", "camera_place", {"a": s}, 0.7, 1.4)
	# D · BONK en pleine figure
	var bonk: float = FV.A_BONK
	c._shot(bonk - 0.04, {"rel": {"a": a}, "eye": [Vector3(0.95, 1.5, -1.75), Vector3(0.82, 1.42, -1.52)], "look": {"a": a, "h": 1.38}, "fov": [38, 35], "hand": 0.4})
	c._cue(bonk, "event", "drone", {"action": "impact", "position": {"a": a, "s": "head"}})
	c._cue(bonk, "sound", "ground_impact", {"a": a}, 0.8, 1.2)
	c._cue(bonk, "word", "stun", {"a": a, "h": 2.15}, tint, 1.0)
	c._cue(bonk, "shake", 0.45)
	c._cue(bonk + 0.03, "stars", {"a": a, "s": "over"}, 4)
	c._move(a, bonk, bonk + 0.15, stop_at + Vector3(0, 0, 0.3), "out")
	_flash(bonk, 0.05, Color(0.8, 0.9, 1.0))
	_burst(bonk, stop_at + Vector3(0, 1.55, 0.05), Vector3(0, 0.6, -1), 14, 3.0, {"spread": 1.0, "lift": 1.2, "life": 1.2, "size": 0.07, "colors": [Color("8055b7"), Color("474555"), violet]})
	# E · la charge, au ras des roulettes : elles grincent sur les clics qui s'accélèrent
	var charge: float = FV.A_CHARGE
	c._shot(charge, {"rel": {"a": s}, "eye": [Vector3(0.75, 0.3, -1.55), Vector3(0.62, 0.32, -1.3)], "look": {"a": s, "h": 0.62, "o": Vector3(-0.1, 0, 1.7)}, "fov": [44, 40], "hand": 0.4})
	c._cue(charge, "event", "boost_charge", {"position": {"a": s}, "active": true})
	var click: float = charge
	var n: int = 0
	while click < 6.75:
		if n % 2 == 0: _later(click, "cue", {"who": s, "cue": "skate_sparks"})
		click += 0.11 - 0.08 * (click - charge) / 0.95
		n += 1
	_glint(6.35, 6.78, s, 0.8)
	# F · parti : poussées croisées autour d'elle, vues d'en haut
	var go: float = FV.A_GO
	var st: float = FV.A_STROKE
	c._face(s, go, "move")
	c._move(s, go, go + st, _r(-0.3, 0.9), "in")
	# un cercle serré autour d'elle, dans le couloir libre mesuré (_measure_room)
	c._move(s, go + st, go + 2.0 * st, _r(-0.85, 2.1), "linear")
	c._move(s, go + 2.0 * st, go + 3.0 * st, _r(-1.05, 3.4), "linear")
	c._move(s, go + 3.0 * st, go + 4.0 * st, _r(-0.75, 4.75), "linear")
	c._move(s, go + 4.0 * st, go + 5.0 * st, _r(0.15, 5.6), "linear")
	c._move(s, go + 5.0 * st, go + 6.0 * st, _r(1.2, 5.55), "linear")
	c._move(s, go + 6.0 * st, FV.A_STOP, _r(1.62, 4.68), "linear")
	c._cue(go, "dust_ring", {"a": s}, 0.9)
	c._cue(go, "sound", "boost", {"a": s}, 1.0, 1.0)
	c._cue(go, "rush", 0.8)
	_later(go + 0.05, "trail", {"who": s, "socket": "foot_r", "seconds": 1.4, "width": 0.16})
	_later(go + 0.05, "trail", {"who": s, "socket": "foot_l", "seconds": 1.4, "width": 0.16})
	for k: int in range(7): _later(go + st * float(k) + 0.12, "cue", {"who": s, "cue": "skate_sparks"})
	c._shot(go - 0.04, {"rel": {"a": a}, "eye": [Vector3(-2.6, 2.6, -2.4), Vector3(-1.9, 2.9, -3.0)], "look": {"mid": [s, a], "h": 0.6}, "fov": [52, 48], "hand": 0.5})
	# elle fauche le vide quand il passe (7,32)
	c._cue(7.32, "sound", "slash", {"a": a}, 0.8, 1.0)
	c._cue(7.36, "word", "miss", {"a": a, "h": 2.2}, PAPER, 0.85)
	_later(7.32, "whoosh", {"at": {"a": a, "h": 1.2, "o": Vector3(-0.6, 0, 0)}, "dir": Vector3(-1, 0, 0.2), "color": PAPER, "count": 4, "length": 1.4})
	_spin(7.34, 8.0, a, 1.0, "out")
	# le drone a repris de la hauteur et tourne derrière elle…
	c._flights.append([5.95, 8.02, "drone", _r(0.45, 3.9, 0.9), _r(0.7, 6.6, 2.7), 1.1, 0.0])
	# G · … puis pique sur sa nuque (8,35) et rebondit vers la main d'Ashura
	var bonk2: float = FV.A_BONK2
	c._flights.append([8.02, bonk2, "drone", _r(0.7, 6.6, 2.7), {"a": a, "s": "head"}, 0.15, 0.0])
	c._flights.append([bonk2, FV.A_CATCH, "drone", {"a": a, "s": "head", "h": 0.25}, {"a": s, "s": "hand_l", "h": 0.1}, 0.9, 0.0])
	c._flights.append([FV.A_CATCH, t_ink, "drone", {"a": s, "s": "hand_l", "h": 0.1}, {"a": s, "s": "hand_l", "h": 0.1}, 0.0, 0.0])
	c._shot(8.3, {"rel": {"a": a}, "eye": [Vector3(1.45, 1.35, -1.95), Vector3(1.22, 1.0, -1.72)], "look": {"a": a, "h": 0.95}, "fov": [40, 37], "hand": 0.5, "roll": [0, -5]})
	c._cue(bonk2, "event", "drone", {"action": "impact", "position": {"a": a, "s": "head"}})
	c._cue(bonk2, "sound", "hit", {"a": a}, 0.9, 1.1)
	c._cue(bonk2, "word", "ouch", {"a": a, "h": 2.0}, tint, 0.95)
	c._cue(bonk2, "shake", 0.45)
	c._cue(bonk2 + 0.04, "stars", {"a": a, "s": "over"}, 5)
	_flash(bonk2, 0.05, Color(0.75, 0.95, 1.0))
	c._cue(FV.A_STOP, "sound", "ground_impact", {"a": a}, 0.7, 1.1)
	c._cue(FV.A_STOP, "dust_ring", {"a": a}, 0.9)
	_rain_burst(FV.A_STOP, _r(0.42, 3.9, 0.3), 0.6)
	# H · arrêt de hockeyeur dans une gerbe d'eau, il la regarde, pouce levé
	var halt: Vector3 = _r(1.5, 4.15)
	var face: Vector3 = (stop_at + Vector3(0, 0, 0.3) - halt).normalized()
	var side: Vector3 = Vector3(face.z, 0.0, - face.x)
	c._move(s, FV.A_STOP, 8.85, halt, "out")
	c._face(s, FV.A_STOP, "dir", face)
	for k: int in range(4): _burst(FV.A_STOP + 0.06 * float(k), halt + Vector3(0, 0.1, 0) - face * 0.2 * float(k), Vector3(0, 0.7, 0) - face * 0.6 + side * 0.4, 9, 3.0 - 0.4 * float(k), {"spread": 0.6, "lift": 1.8, "gravity": 7.0, "life": 0.8, "size": 0.05, "colors": [Color("cfdaea"), Color("9fb0c8")]})
	c._cue(FV.A_STOP, "sound", "step", {"a": s}, 0.9, 0.6)
	_later(FV.A_STOP, "cue", {"who": s, "cue": "skid"})
	# H1 · derrière Alice assise : il s'arrête et rattrape le drone
	c._shot(8.72, {"eye": [_r(0.05, 5.85, 1.05), _r(0.1, 5.7, 1.1)], "look": [halt + Vector3(-0.3, 0.85, 0.15), halt + Vector3(-0.2, 1.0, 0.1)], "fov": [46, 43], "hand": 0.3})
	# H2 · face à lui : le pouce levé, les yeux qui brillent
	c._shot(9.26, {"eye": [halt + face * 1.35 - side * 0.95 + Vector3(0, 1.32, 0), halt + face * 1.25 - side * 0.85 + Vector3(0, 1.34, 0)], "look": [halt + Vector3(0, 1.22, 0), halt + Vector3(0, 1.28, 0)], "fov": [38, 35], "hand": 0.25})
	c._cue(FV.A_CATCH, "sound", "camera_place", {"a": s}, 0.6, 1.1)
	_later(FV.A_THUMB, "sparkles", {"at": {"a": s, "s": "hand_r"}, "color": tint, "count": 4, "radius": 0.3})
	_glint(9.5, 9.84, s, 1.0)
	_bolt(9.22, 0.25, 1.0)
	_flash(t_ink - 0.06, 0.12)
	# PAPIER · la glisse sur un patin, le drone au-dessus ; Alice assise, sonnée
	var ink: float = t_ink
	_jump(s, ink, _ink(-2.4, 0, 0.6))
	_jump(a, ink, _ink(1.7, 0, -0.5))
	c._face(s, ink, "dir", Vector3(1, 0, 0))
	c._face(a, ink, "dir", Vector3(-1, 0, 0.12))
	_play(s, "fv_ashura_ink", ink)
	_play(a, "fv_ashura_alice_ink", ink)
	c._move(s, ink + 0.02, ink + 2.6, _ink(0.0, 0, 0.6), "linear")
	c._flights.append([ink + 0.01, ink + 2.6, "drone", _ink(-2.0, 2.05, 0.4), _ink(0.55, 2.3, 0.5), 0.15, 0.0])
	c._cue(ink + 0.2, "stars", {"a": a, "s": "over"}, 4)
	_burst(ink + 0.1, _ink(-2.4, 0.1, 0.6), Vector3(-1, 0.3, 0), 16, 1.6, {"spread": 0.5, "lift": 0.5, "gravity": 0.6, "drag": 0.8, "life": 2.4, "size": 0.07})
	_burst(ink, _ink(1.7, 1.5, -0.5), Vector3.UP, 10, 0.8, {"spread": 0.6, "lift": 0.8, "gravity": 0.3, "drag": 0.6, "life": 2.6, "size": 0.1, "swirl": 2.0, "radius": 0.5})
	c._shot(ink, {"eye": [_ink(-0.4, 1.0, 6.6), _ink(-0.1, 1.0, 6.3)], "look": [_ink(-0.6, 1.0, 0.0), _ink(-0.2, 1.0, 0.0)], "fov": 42, "hand": 0.1, "safe": false})



# ---------------------------------------------------------------- LYSIA ---
# Surtension. À l'arrêt sous la pluie, en recharge ; elle redémarre quand Alice
# arrive, la renverse d'un coup d'épaule (5,2), surchauffe pendant qu'Alice
# revient, et la balaie d'une décharge des deux paumes (6,55). La vapeur
# s'échappe, un regard vers nous.
func _write_lysia() -> void :
	var c: Node3D = cinema
	var volt: Color = Color("bff6ff")
	var spark: Color = Color("d9fbff")
	c._put(s, _r(0.0, 0.0))
	c._face(s, 0.0, "dir", Vector3(0, 0, 1))
	var near: Vector3 = _r(0.25, 3.0)
	c._put(a, near + Vector3(0, 0, FV.LA_WALK_SPEED * (FV.LA_WALK_END - 3.3)))
	c._face(a, 0.0, "dir", Vector3(-0.05, 0, -1))
	_play(s, "fv_lysia_rain")
	_play(a, "fv_lysia_alice_rain")
	c._move(a, 3.3, FV.LA_WALK_END, near, "linear")
	c._move(a, FV.LA_WALK_END, FV.LA_WALK_END + 0.1, near + Vector3(0, 0, -0.05), "out")
	# A1 · de dos, à l'arrêt, la pluie fume sur son armure ; Alice approche au fond
	c._shot(3.32, {"rel": {"a": s}, "eye": [Vector3(0.78, 1.08, -1.55), Vector3(0.66, 1.02, -1.32)], "look": {"a": s, "h": 1.0, "o": Vector3(0, 0, 1.8)}, "fov": [44, 41], "hand": 0.3})
	for t: float in [3.4, 3.829, 4.257, 4.686]: _later(t, "cue", {"who": s, "cue": "volt"})
	for t: float in [3.507, 3.721]: _later(t, "cue", {"who": s, "cue": "spark_l" if t < 3.6 else "spark_r"})
	_later(3.5, "cue", {"who": s, "cue": "steam"})
	_later(3.95, "cue", {"who": s, "cue": "steam"})
	c._cue(3.45, "sound", "xray", {"a": s}, 0.6, 0.7)
	_bolt(3.62, 0.18, 0.8)
	# A2 · son visage, yeux fermés ; le redémarrage (4,04), les yeux s'ouvrent (4,15)
	_closeup(3.75, s, Vector3(0, 0, 1), -1.0, 1.0, 29.0, -0.05)
	c._cue(FV.L_BOOT, "pulse", Color(0.55, 1.0, 0.95, 0.25), 0.5)
	_later(FV.L_BOOT, "cue", {"who": s, "cue": "volt"})
	_glint(FV.L_OPEN, 4.85, s, 1.15)
	_later(FV.L_OPEN + 0.01, "cue", {"who": s, "cue": "scan"})
	c._cue(FV.L_OPEN, "sound", "xray", {"a": s}, 0.8, 1.0)
	_later(4.793, "cue", {"who": s, "cue": "scan"})
	# B · la ruée d'épaule, de profil
	var dash: float = FV.L_DASH
	var hit: float = FV.L_HIT
	var ram: Vector3 = _r(0.05, FV.L_DASH_SPEED * (hit - dash))
	c._move(s, dash, hit, ram, "linear")
	c._move(s, hit, 5.34, ram + Vector3(0.01, 0, 0.14), "out")
	c._cue(dash, "event", "overheat_charge", {"position": {"a": s}})
	c._cue(dash, "sound", "boost", {"a": s}, 0.9, 0.8)
	c._cue(dash, "rush", 0.8)
	_later(dash + 0.02, "trail", {"who": s, "socket": "hand_l", "seconds": 0.35, "width": 0.16})
	for k: int in range(3): _later(dash + 0.1 * float(k), "bolts", {"at": {"a": s, "h": 1.0}, "color": volt, "count": 2, "radius": 0.5, "size": 0.7})
	c._shot(dash - 0.05, {"rel": {"mid": [s, a]}, "eye": [Vector3(3.3, 0.95, -0.5), Vector3(3.0, 1.0, -0.2)], "look": {"mid": [s, a], "h": 1.1}, "fov": [44, 41], "hand": 0.55})
	_smear(dash, hit, Vector2(0.03, 0.0))
	c._cue(hit, "word", "zap", {"a": a, "h": 2.2}, volt, 1.05)
	c._cue(hit, "shake", 0.5)
	c._cue(hit, "sound", "hit", {"a": a}, 1.0, 0.8)
	c._cue(hit, "pop", {"mid": [s, a], "h": 1.2}, Vector3(0, 0, 1), volt, 1.0)
	_later(hit, "cue", {"who": s, "cue": "skid"})
	_flash(hit, 0.07, Color(0.75, 1.0, 0.95))
	for k: int in range(4): _later(hit + 0.1 * float(k), "bolts", {"at": {"a": a, "h": 1.2}, "color": volt, "count": 3, "radius": 0.6, "size": 0.9})
	var back: Vector3 = near + Vector3(0.05, 0, 1.15)
	c._move(a, hit, 5.42, back, "out")
	# C1 · la surchauffe, en contre-plongée : la pluie se change en vapeur
	var heat: float = FV.L_HEAT
	c._shot(5.42, {"rel": {"a": s}, "eye": [Vector3(1.15, 0.55, 1.45), Vector3(0.98, 0.62, 1.25)], "look": {"a": s, "h": 1.15}, "fov": [42, 38], "hand": 0.45})
	c._cue(heat, "event", "overheat", {"position": {"a": s}, "active": true})
	c._cue(heat, "pulse", Color(1.0, 0.5, 0.15, 0.35), 0.9)
	for k: int in range(8):
		var t: float = heat + 0.11875 * float(k)
		if k % 2 == 0: _later(t, "cue", {"who": s, "cue": "steam"})
		_later(t, "bolts", {"at": {"a": s, "h": 1.0}, "color": spark, "count": 1 + k / 3, "radius": 0.45 + 0.05 * float(k), "size": 0.6 + 0.06 * float(k)})
	_rain_burst(heat + 0.2, _r(0.05, 2.3, 1.5), 0.9)
	_glint(5.6, 6.0, s, 1.0)
	# C2 · par-dessus son épaule : Alice revient à la charge
	var rush_to: Vector3 = back + Vector3(-0.02, 0, - FV.LA_RUSH_SPEED * (6.38 - 5.7))
	c._move(a, 5.7, 6.38, rush_to, "linear")
	c._move(a, 6.38, 6.5, rush_to + Vector3(0, 0, -0.1), "out")
	c._shot(6.0, {"rel": {"a": s}, "eye": [Vector3(-1.2, 1.32, -0.85), Vector3(-1.05, 1.28, -0.7)], "look": {"a": a, "h": 1.1}, "fov": [42, 40], "hand": 0.5})
	c._cue(5.64, "sound", "slash", {"a": a}, 0.5, 0.7)
	# D · 6,55 · DÉCHARGE : Alice traverse la cour
	var push: float = FV.L_PUSH
	c._cue(push - 0.08, "event", "overheat", {"position": {"a": s}, "active": false})
	c._cue(push, "word", "push", {"a": s, "h": 2.3}, Color("a6f0d8"), 1.15)
	c._cue(push, "sound", "ground_impact", {"a": a}, 1.0, 0.75)
	c._cue(push, "sound", "xray", {"a": a}, 1.0, 1.3)
	c._cue(push, "shake", 0.75)
	c._cue(push, "impact", 0.8, false)
	_flash(push, 0.1, Color(0.8, 1.0, 0.98))
	_rain_burst(push, rush_to + Vector3(0, 1.2, -0.4), 0.8)
	for k: int in range(6): _later(push + 0.06 * float(k), "bolts", {"at": {"a": a, "h": 1.1}, "color": spark, "count": 3, "radius": 0.7, "size": 1.0})
	_burst(push, rush_to + Vector3(0, 1.0, -0.3), Vector3(0, 0.3, 1), 26, 6.5, {"spread": 0.6, "lift": 1.4, "gravity": 6.0, "life": 1.5, "size": 0.11})
	_smear(push, push + 0.3, Vector2(0.06, 0.0))
	var thrown: float = maxf(rush_to.z - rz + 3.0, minf(11.0, room - 1.5))
	var land: float = FV.LA_LAND
	c._move(a, push, 7.0, _r(0.15, lerpf(rush_to.z - rz, thrown, 0.6), 1.1), "out")
	c._move(a, 7.0, land, _r(0.1, thrown, 0.0), "in")
	c._move(a, land, land + 0.22, _r(0.1, thrown + 0.45, 0.0), "out")
	_tilt(push, 7.0, a, Vector3.ZERO, Vector3(1.1, 0.0, 0.1), "out")
	_tilt(7.0, land, a, Vector3(1.1, 0.0, 0.1), Vector3.ZERO, "smooth")
	c._shot(push - 0.12, {"rel": {"mid": [s, a]}, "eye": [Vector3(2.5, 1.0, -0.1), Vector3(2.85, 1.05, 0.5)], "look": [{"mid": [s, a], "h": 1.05}, {"a": s, "h": 1.0, "o": Vector3(0, 0, 1.6)}], "fov": [40, 46], "hand": 0.7})
	# D2 · on suit Alice jusqu'au choc, toujours parcourue d'éclairs
	c._shot(6.9, {"rel": {"a": a}, "eye": [Vector3(0.9, 1.5, -2.3), Vector3(0.75, 1.25, -1.7)], "look": {"a": a, "h": 0.7}, "fov": [48, 42], "hand": 0.6})
	_smear(6.9, 7.3, Vector2(0.045, 0.0))
	c._cue(land, "dust_ring", {"a": a}, 1.3)
	c._cue(land, "sound", "ground_impact", {"a": a}, 0.9, 0.85)
	c._cue(land, "shake", 0.4)
	c._cue(land + 0.08, "stars", {"a": a, "s": "over"}, 4)
	_burst(land, _r(0.1, thrown, 0.2), Vector3(0, 1, -0.3), 18, 3.6, {"spread": 1.0, "lift": 1.8, "gravity": 8.0, "life": 1.2, "size": 0.09})
	for k: int in range(5): _later(land + 0.05 + 0.15 * float(k), "bolts", {"at": {"a": a, "h": 0.4}, "color": spark, "count": 2, "radius": 0.6, "size": 0.7})
	# E · la vapeur s'échappe, les tics de recalage, un regard vers nous
	var vent: float = FV.L_VENT
	_closeup(7.55, s, Vector3(0.1, 0, 1), 1.0, 1.4, 33.0, 0.0)
	_later(vent, "cue", {"who": s, "cue": "steam"})
	_later(vent + 0.18, "cue", {"who": s, "cue": "steam"})
	_later(vent + 0.3, "cue", {"who": s, "cue": "spark_r"})
	c._cue(vent, "sound", "xray", {"a": s}, 0.5, 0.6)
	_glint(FV.L_TURN + 0.05, 8.6, s, 1.0)
	_later(8.44, "cue", {"who": s, "cue": "spark_l"})
	_bolt(vent + 0.4, 0.25, 1.1)
	_flash(t_ink - 0.06, 0.12)
	# PAPIER · la décharge figée, Alice cueillie en plein vol
	var ink: float = t_ink
	_jump(s, ink, _ink(-1.3, 0, 0.0))
	_jump(a, ink, _ink(0.9, 0.35, 0.0))
	c._face(s, ink, "dir", Vector3(1, 0, 0))
	c._face(a, ink, "dir", Vector3(-1, 0, 0))
	_play(s, "fv_lysia_ink", ink)
	_play(a, "fv_lysia_alice_ink", ink)
	c._move(a, ink + 0.01, ink + 2.5, _ink(2.0, 0.7, 0.0), "out")
	_tilt(ink, ink + 2.6, a, Vector3(0, 0, -0.2), Vector3(0, 0, -0.45))
	for k: int in range(9): _later(ink + 0.05 + 0.25 * float(k), "bolts", {"at": _ink(0.0, 1.15, 0.0), "color": spark, "count": 3, "radius": 1.0, "size": 1.3})
	_burst(ink, _ink(0.6, 1.0, 0.0), Vector3(1, 0.2, 0), 26, 2.6, {"spread": 0.7, "lift": 0.6, "gravity": 0.5, "drag": 0.8, "life": 2.6, "size": 0.1})
	c._shot(ink, {"eye": [_ink(0.2, 1.05, 6.2), _ink(0.25, 1.05, 5.8)], "look": [_ink(0.2, 1.0, 0.0), _ink(0.3, 1.0, 0.0)], "fov": 42, "hand": 0.1, "safe": false})



# ----------------------------------------------------------------- ELLY ---
# Soin, esquive, fusil. Blessée, un genou à terre, elle se soigne ; elle lève
# les yeux, se relève, plonge sous la griffe (5,2), décroche son fusil et tire
# (6,15). Elle souffle sur la fumée, cale le fusil sur l'épaule et s'en va vers
# la porte, avec un regard par-dessus l'épaule.
func _write_elly() -> void :
	var c: Node3D = cinema
	var mint: Color = Color("8ff0d2")
	c._put(s, _r(0.0, 0.0))
	c._face(s, 0.0, "dir", Vector3(0, 0, 1))
	var near: Vector3 = _r(0.3, 2.4)
	c._put(a, near + Vector3(0, 0, FV.EA_WALK_SPEED * (FV.EA_WALK_END - 3.3)))
	c._face(a, 0.0, "dir", Vector3(-0.1, 0, -1))
	_play(s, "fv_elly_rain")
	_play(a, "fv_elly_alice_rain")
	c._move(a, 3.3, FV.EA_WALK_END, near, "linear")
	c._move(a, FV.EA_WALK_END, FV.EA_WALK_END + 0.1, near + Vector3(0, 0, -0.05), "out")
	# A1 · à genoux, la trousse sur la plaie : la lumière du soin sur son visage
	c._shot(3.32, {"rel": {"a": s}, "eye": [Vector3(0.95, 0.75, 1.3), Vector3(0.82, 0.78, 1.12)], "look": {"a": s, "h": 0.78}, "fov": [40, 36], "hand": 0.35})
	_later(FV.E_HEAL, "cue", {"who": s, "cue": "heal_ring"})
	_later(FV.E_HEAL + 0.05, "cue", {"who": s, "cue": "heal_l"})
	_later(3.72, "cue", {"who": s, "cue": "heal_l"})
	c._cue(FV.E_HEAL, "sound", "heal", {"a": s}, 0.9, 1.0)
	c._cue(3.6, "pulse", Color(0.45, 1.0, 0.75, 0.25), 0.8)
	# A2 · derrière elle : Alice arrive
	c._shot(3.95, {"rel": {"a": s}, "eye": [Vector3(-0.72, 1.0, -1.1), Vector3(-0.62, 0.98, -0.95)], "look": {"a": a, "h": 1.05}, "fov": [44, 42], "hand": 0.3})
	_bolt(4.15, 0.22, 0.9)
	# B · les yeux montent sous la frange, et brillent
	_closeup(FV.E_RISE, s, Vector3(0, 0, 1), 1.0, 1.25, 30.0, -0.3)
	_glint(4.55, 5.05, s, 1.1)
	# C · la griffe, l'esquive : vue de côté
	var dodge: float = FV.E_DODGE
	var lunge: Vector3 = _r(0.12, 1.5)
	c._move(a, FV.EA_LUNGE, dodge, lunge, "dash")
	c._move(a, dodge, 5.46, _r(0.06, 1.18), "out")
	var hop: Vector3 = _r(-0.5, 0.0)
	var spot: Vector3 = _r(-0.6, -0.45)
	c._move(s, dodge, 5.33, hop, "out")
	c._move(s, 5.38, 5.47, spot, "out")
	c._cue(dodge, "event", "dodge", {"position": {"a": s}})
	c._cue(dodge, "sound", "slash", {"a": a}, 0.8, 1.0)
	c._cue(dodge + 0.08, "word", "miss", {"a": s, "h": 2.2}, PAPER, 0.9)
	_smear(dodge - 0.04, dodge + 0.2, Vector2(-0.04, 0.0))
	c._shot(FV.EA_LUNGE, {"rel": {"mid": [s, a]}, "eye": [Vector3(-3.0, 1.1, 0.3), Vector3(-2.75, 1.12, 0.12)], "look": {"mid": [s, a], "h": 1.15}, "fov": [44, 42], "hand": 0.55})
	# elle se retourne vers Elly, gronde, revient d'un pas (6,08)
	var close: Vector3 = _r(0.0, 0.98)
	c._face(a, 5.5, "at", s)
	c._move(a, 5.92, 6.08, close, "out")
	c._face(s, 5.42, "at", a)
	# D · en joue, le long du canon : la pompe claque sur les clics
	var line: Vector3 = (close - spot)
	line.y = 0.0
	line = line.normalized()
	var across: Vector3 = Vector3(line.z, 0.0, - line.x)
	c._shot(FV.E_AIM - 0.04, {"eye": [spot - line * 0.5 - across * 0.32 + Vector3(0, 1.52, 0), spot - line * 0.42 - across * 0.3 + Vector3(0, 1.5, 0)], "look": {"a": a, "h": 1.3}, "fov": [32, 28], "hand": 0.3})
	for t: float in [5.8, 5.93]: c._cue(t, "sound", "camera_place", {"a": s}, 0.6, 0.8)
	_glint(5.8, 6.1, s, 0.9)
	# E · BANG : Alice est soufflée en arrière
	var bang: float = FV.E_BANG
	var fall: Vector3 = close + line * 3.4
	c._cue(bang, "event", "tracer", {"from": {"a": s, "h": 1.35, "o": line * 0.6}, "to": {"a": a, "h": 1.2}, "duration": 0.2})
	c._cue(bang, "sound", "shotgun", {"a": s}, 1.0, 0.95)
	c._cue(bang, "frame", Color(1.0, 0.95, 0.8, 0.35), 0.08)
	c._cue(bang, "shake", 0.7)
	c._cue(bang, "impact", 0.7, true)
	c._cue(bang + 0.02, "pop", {"a": a, "h": 1.15}, line, Color("ffe6a0"), 1.4)
	c._cue(bang + 0.04, "stars", {"a": a, "s": "over"}, 3)
	_flash(bang, 0.08, Color(1.0, 0.92, 0.7))
	_rain_burst(bang, close + Vector3(0, 1.2, 0) - line * 0.4, 0.6)
	_burst(bang + 0.03, spot + Vector3(0, 1.25, 0) + across * 0.2, Vector3(0, 0.8, 0) + across, 2, 2.6, {"spread": 0.3, "lift": 2.0, "gravity": 9.0, "life": 1.2, "size": 0.06, "colors": [Color("c2462e"), Color("d9a43a")]})
	_burst(bang + 0.02, close + Vector3(0, 1.2, 0), line + Vector3(0, 0.2, 0), 20, 6.0, {"spread": 0.6, "lift": 1.2, "gravity": 6.0, "life": 1.4, "size": 0.1})
	c._move(a, bang, 6.4, close + line * 2.4 + Vector3(0, 0.45, 0), "out")
	c._move(a, 6.4, FV.EA_LAND, fall, "in")
	c._move(a, FV.EA_LAND, 6.75, fall + line * 0.4, "out")
	_tilt(bang, 6.4, a, Vector3.ZERO, Vector3(0.9, 0.0, 0.1), "out")
	_tilt(6.4, FV.EA_LAND, a, Vector3(0.9, 0.0, 0.1), Vector3.ZERO, "smooth")
	c._cue(FV.EA_LAND, "dust_ring", {"a": a}, 1.1)
	c._cue(FV.EA_LAND, "sound", "ground_impact", {"a": a}, 0.9, 0.9)
	c._cue(FV.EA_LAND, "shake", 0.3)
	var mid: Vector3 = (spot + close) * 0.5
	c._shot(bang - 0.12, {"eye": [mid - across * 3.3 + line * 0.4 + Vector3(0, 1.15, 0), mid - across * 3.6 + line * 1.4 + Vector3(0, 1.2, 0)], "look": [mid + Vector3(0, 1.1, 0), mid + line * 1.6 + Vector3(0, 0.9, 0)], "fov": [42, 46], "hand": 0.7})
	# F · la fumée du canon, le fusil sur l'épaule
	var cool: float = FV.E_COOL
	c._shot(6.75, {"eye": [spot + line * 1.55 - across * 0.55 + Vector3(0, 1.42, 0), spot + line * 1.4 - across * 0.5 + Vector3(0, 1.46, 0)], "look": [spot + Vector3(0, 1.4, 0), spot + Vector3(0, 1.48, 0)], "fov": [36, 33], "hand": 0.3})
	for k: int in range(3): _later(cool + 0.05 + 0.12 * float(k), "smoke", {"who": s})
	_later(7.38, "smoke", {"who": s})
	_glint(7.4, 7.7, s, 0.9)
	# G · elle s'en va vers la porte, vers nous ; un regard par-dessus l'épaule
	var leave: float = FV.E_LEAVE
	var home: Vector3 = Vector3(-0.1, 0, -1)
	c._face(s, leave, "dir", home)
	var walk_to: Vector3 = spot + home.normalized() * FV.E_WALK_SPEED * (t_ink + 0.05 - FV.E_WALK)
	c._move(s, FV.E_WALK, t_ink + 0.05, walk_to, "linear")
	c._shot(leave, {"eye": [spot + Vector3(0.42, 1.28, -2.35), spot + Vector3(0.36, 1.32, -2.15)], "look": [spot + Vector3(0, 1.3, -0.2), walk_to + Vector3(0, 1.45, 0)], "fov": [40, 36], "hand": 0.35})
	_later(8.4, "pluses", {"at": {"a": s, "h": 1.4}, "count": 3})
	_glint(8.72, 8.94, s, 1.0)
	_bolt(8.1, 0.28, 1.2)
	_flash(t_ink - 0.06, 0.12)
	# PAPIER · le coup de feu figé : le recul, Alice soufflée en arrière
	var ink: float = t_ink
	_jump(s, ink, _ink(-1.4, 0, 0.0))
	_jump(a, ink, _ink(1.25, 0.25, 0.0))
	c._face(s, ink, "dir", Vector3(1, 0, 0))
	c._face(a, ink, "dir", Vector3(-1, 0, 0))
	_play(s, "fv_elly_ink", ink)
	_play(a, "fv_elly_alice_ink", ink)
	c._move(a, ink + 0.01, ink + 2.5, _ink(2.1, 0.55, 0.0), "out")
	_tilt(ink, ink + 2.6, a, Vector3(0, 0, -0.3), Vector3(0, 0, -0.6))
	_burst(ink, _ink(-0.2, 1.3, 0.0), Vector3(1, 0.05, 0), 30, 4.5, {"spread": 0.35, "lift": 0.2, "gravity": 0.3, "drag": 1.6, "life": 2.6, "size": 0.07})
	_burst(ink + 0.02, _ink(-0.9, 1.35, 0.0), Vector3(-0.3, 1, 0.2), 2, 2.2, {"spread": 0.2, "lift": 1.2, "gravity": 3.0, "drag": 0.3, "life": 2.6, "size": 0.08})
	c._shot(ink, {"eye": [_ink(0.0, 1.15, 6.4), _ink(0.05, 1.15, 6.0)], "look": [_ink(0.0, 1.05, 0.0), _ink(0.1, 1.05, 0.0)], "fov": 42, "hand": 0.1, "safe": false})



# ------------------------------------------------------------- BLEUETTE ---
# Chocolat, courage, sprint. Alice approche ; Bleuette tremble, sa tablette
# contre elle. Elle croque (4,22), avale, range le chocolat, se redresse et
# serre les poings (5,65). Alice frappe (6,45) : Bleuette a déjà filé sous son
# bras. Alice se retourne, se prend les pieds dans sa robe et s'étale à plat
# ventre dans une flaque (7,27). Bleuette dérape, se retourne, les mains sur la
# bouche, puis lève le poing en sautillant (8,09).
func _write_bleuette() -> void :
	var c: Node3D = cinema
	var tint: Color = GLINT.Bleuette
	var blue: Color = Color("a9c8ff")
	var water: Array = [Color("cfdaea"), Color("9fb0c8"), Color("e8f0ff")]
	var start: Vector3 = _r(-0.3, 0.0)
	var near: Vector3 = _r(0.3, 1.25)
	var toward: Vector3 = (near - start).normalized()
	# sa droite : la frange cache son visage dès qu'on la filme à plus de 20° de face
	var right: Vector3 = toward.cross(Vector3.UP)
	var eyes: Dictionary = {"a": s, "s": "eyes", "h": -0.05}
	c._put(s, start)
	c._face(s, 0.0, "at", a)
	c._put(a, near + toward * FV.BA_WALK_SPEED * (FV.BA_WALK_END - 3.3))
	c._face(a, 0.0, "at", s)
	_play(s, "fv_bleuette_rain")
	_play(a, "fv_bleuette_alice_rain")
	# Alice : trois pas lents (anim_set_film_victory : BA_WALK_SPEED)
	c._move(a, 3.3, FV.BA_WALK_END, near, "linear")
	# A1 · par-dessus l'épaule de Bleuette, en contre-plongée : Alice arrive
	c._shot(3.32, {"rel": {"a": s}, "eye": [Vector3(0.3, 0.72, -0.62), Vector3(0.28, 0.75, -0.55)], "look": {"a": a, "h": 1.5}, "fov": [36, 33], "hand": 0.45, "roll": [-6, -9]})
	_glint(3.5, 4.12, a, 0.9)
	_bolt(3.62, 0.2, 0.85)
	# A2 · son visage : elle tremble, lève les yeux, puis les baisse sur le chocolat
	c._shot(3.85, {"rel": eyes, "eye": [toward * 0.9 + right * 0.27 + Vector3.UP * 0.02, toward * 0.84 + right * 0.25 + Vector3.UP * 0.03], "look": {"a": s, "s": "eyes", "h": -0.11}, "fov": [36, 33], "hand": 0.3})
	_later(3.92, "cue", {"who": s, "cue": "sweat"})
	# B1 · elle croque, trois fois, sur le célesta
	# (par-dessus l'épaule gauche d'Alice, en plongée : la petite qui grignote sous
	# le nez du monstre)
	c._shot(4.12, {"rel": eyes, "eye": [toward * 1.25 + right * 0.44 + Vector3.UP * 0.14, toward * 1.2 + right * 0.43 + Vector3.UP * 0.12], "look": {"a": s, "s": "eyes", "h": -0.12}, "fov": [30, 28], "hand": 0.25})
	c._cue(4.62, "pulse", Color(1.0, 0.78, 0.6, 0.16), 0.7)
	# B2 · Alice, interdite (elle mange ?!), la tête qui penche
	c._shot(4.66, {"rel": {"a": a, "s": "eyes"}, "eye": [- toward * 0.95 + right * 0.32 - Vector3.UP * 0.12, - toward * 0.9 + right * 0.3 - Vector3.UP * 0.1], "look": {"a": a, "s": "eyes", "h": -0.08}, "fov": [32, 30], "hand": 0.3})
	_glint(4.7, 4.92, a, 0.8)
	# B3 · les yeux se rouvrent sur Alice ; la tablette retourne dans la poche
	c._shot(4.94, {"rel": {"a": s}, "eye": [toward * 0.95 + right * 0.42 + Vector3.UP * 0.8, toward * 0.9 + right * 0.4 + Vector3.UP * 0.84], "look": {"a": s, "h": 1.15}, "fov": [40, 36], "hand": 0.3})
	# C1 · elle se redresse, la caméra monte avec elle
	c._shot(FV.B_RISE, {"rel": {"a": s}, "eye": [toward * 1.0 + right * 0.55 + Vector3.UP * 0.45, toward * 0.95 + right * 0.5 + Vector3.UP * 0.85], "look": [{"a": s, "h": 0.9}, {"a": s, "h": 1.25}], "fov": [42, 36], "hand": 0.35})
	# C2 · 5,65 · Mi majeur : ses yeux s'allument
	var brave: float = FV.B_BRAVE
	_closeup(5.6, s, toward, -1.0, 0.95, 28.0, 0.0)
	_glint(brave, 6.2, s, 1.2)
	c._cue(brave, "pulse", Color(0.55, 0.75, 1.0, 0.35), 0.9)
	c._cue(brave, "pillars", {"a": s}, blue, 7, 0.7)
	c._cue(brave, "sparkles", {"a": s, "h": 1.0}, Color("cfe0ff"), 8, 0.8)
	c._cue(brave, "sound", "encourage", {"a": s}, 1.0, 1.1)
	c._cue(brave, "shake", 0.3)
	_rain_burst(brave, start + Vector3(0, 1.2, 0), 0.8)
	# C3 · de profil, au ras du sol : elle se ramasse, Alice arme… et fauche le vide
	c._shot(5.92, {"eye": [_r(-2.75, 0.62, 0.42), _r(-2.6, 0.82, 0.45)], "look": [_r(0.0, 0.62, 1.05), _r(0.0, 0.95, 1.0)], "fov": [46, 46], "hand": 0.5})
	var lunge_to: Vector3 = near - toward * FV.BA_LUNGE
	c._face(a, 6.3, "dir", - toward)
	c._move(a, 6.4, 6.55, lunge_to, "dash")
	c._cue(FV.BA_SWIPE, "sound", "slash", {"a": a}, 0.9, 1.0)
	c._cue(FV.BA_SWIPE + 0.02, "word", "miss", {"a": a, "h": 2.15}, PAPER, 0.85)
	_later(FV.BA_SWIPE, "whoosh", {"at": {"a": a, "h": 1.1, "o": - toward * 0.5}, "dir": Vector3(-1, -0.3, 0), "color": PAPER, "count": 4, "length": 1.2})
	# D · 6,38 · le sprint : un appui toutes les B_STEP s, au mètre près
	var lane: Vector3 = Vector3(0, 0, 1)
	var go: float = FV.B_GO
	var speed: float = FV.B_RUN_SPEED
	c._face(s, go, "dir", lane)
	var p1: Vector3 = start + lane * (speed * (FV.B_FIRST - go) * 0.5)
	var p2: Vector3 = p1 + lane * speed * (FV.B_SKID - FV.B_FIRST)
	var p3: Vector3 = p2 + lane * (speed * (FV.B_SKID_END - FV.B_SKID) * 0.5)
	c._move(s, go, FV.B_FIRST, p1, "in")
	c._move(s, FV.B_FIRST, FV.B_SKID, p2, "linear")
	c._move(s, FV.B_SKID, FV.B_SKID_END, p3, "out")
	c._cue(go, "sound", "boost", {"a": s}, 0.9, 1.2)
	c._cue(go, "rush", 0.9)
	_later(go + 0.01, "cue", {"who": s, "cue": "afterimage"})
	_later(go + 0.06, "cue", {"who": s, "cue": "afterimage"})
	_later(go + 0.02, "trail", {"who": s, "socket": "foot_r", "seconds": 0.8, "width": 0.14})
	_later(go + 0.02, "trail", {"who": s, "socket": "foot_l", "seconds": 0.8, "width": 0.14})
	_smear(go, 6.6, Vector2(0.05, 0.0))
	for k: int in range(4): _burst(FV.B_FIRST + 2.0 * FV.B_STEP * float(k), start + lane * (0.5 + 1.3 * float(k)) + Vector3(0, 0.05, 0), Vector3(0, 0.7, -1), 6, 2.0, {"spread": 0.6, "lift": 1.2, "gravity": 7.0, "life": 0.6, "size": 0.045, "colors": water})
	# Alice se retourne d'un bond, se lance… et se prend les pieds dans sa robe
	c._face(a, FV.BA_WHIRL - 0.02, "at", s)
	var fall_dir: Vector3 = (start + lane * 2.4 - lunge_to)
	fall_dir.y = 0.0
	fall_dir = fall_dir.normalized()
	var lie: Vector3 = lunge_to + fall_dir * 1.07
	c._move(a, FV.BA_PUSH, FV.BA_TRIP, lunge_to + fall_dir * 0.22, "in")
	c._move(a, FV.BA_TRIP, FV.BA_LAND, lie, "in")
	c._face(a, 6.95, "dir", fall_dir)
	c._cue(6.66, "sound", "slash", {"a": a}, 0.5, 0.8)
	# D2 · à côté d'elle, en travelling : le sprint de profil
	c._shot(6.62, {"rel": {"a": s}, "eye": [Vector3(-1.9, 0.62, 0.3), Vector3(-1.85, 0.64, 0.2)], "look": [{"a": s, "h": 0.72, "o": Vector3(0, 0, 0.3)}, {"a": s, "h": 0.74, "o": Vector3(0, 0, 0.2)}], "fov": [46, 46], "hand": 0.4})
	c._cue(6.62, "rush", 0.8)
	_later(6.64, "whoosh", {"at": {"a": s, "h": 0.8}, "dir": Vector3(0, 0, -1), "color": PAPER, "count": 5, "length": 1.6})
	# E1 · 7,27 · PLOUF, au ras de la flaque ; au fond, Bleuette dérape
	c._shot(6.88, {"eye": [lie + Vector3(1.6, 0.45, -0.95), lie + Vector3(1.45, 0.42, -0.8)], "look": [lie + Vector3(-0.1, 0.55, 0.2), lie + Vector3(-0.15, 0.35, 0.85)], "fov": [44, 42], "hand": 0.45})
	var land: float = FV.BA_LAND
	var splash: Vector3 = lie + fall_dir * 0.45
	c._cue(land, "sound", "ground_impact", {"a": a}, 1.0, 0.85)
	c._cue(land, "dust_ring", {"a": a}, 0.7)
	c._cue(land, "shake", 0.5)
	c._cue(land + 0.09, "stars", {"a": a, "s": "over"}, 5)
	_rain_burst(land, splash + Vector3(0, 0.4, 0), 0.9)
	_burst(land, splash + Vector3(0, 0.08, 0), Vector3(0, 1, 0), 30, 3.6, {"spread": 1.1, "lift": 2.4, "gravity": 8.0, "life": 1.2, "size": 0.07, "colors": water})
	_burst(land + 0.02, splash + Vector3(0, 0.05, 0), fall_dir + Vector3(0, 0.5, 0), 14, 4.2, {"spread": 0.5, "lift": 1.4, "gravity": 8.0, "life": 1.0, "size": 0.06, "colors": water})
	# le dérapage de Bleuette, gerbes d'eau sous ses talons
	for k: int in range(5): _burst(FV.B_SKID + 0.05 * float(k), p2 + lane * (0.15 * float(k)) + Vector3(0, 0.08, 0), Vector3(0, 0.6, 0) + lane, 7, 2.6 - 0.35 * float(k), {"spread": 0.6, "lift": 1.6, "gravity": 7.0, "life": 0.7, "size": 0.05, "colors": water})
	c._cue(FV.B_SKID, "sound", "step", {"a": s}, 0.8, 0.7)
	c._face(s, FV.B_TURN, "at", a)
	# E2 · au-dessus d'Alice dans la flaque : Bleuette, au fond, les mains sur la bouche
	c._shot(7.62, {"rel": {"a": s}, "eye": [Vector3(0.62, 0.62, -2.05), Vector3(0.58, 0.66, -1.9)], "look": [{"a": s, "h": 0.92}, {"a": s, "h": 0.98}], "fov": [34, 32], "hand": 0.3})
	_later(7.66, "cue", {"who": s, "cue": "sweat"})
	# Alice relève la tête, glisse et retombe le nez dans l'eau, tape l'eau de rage
	var face_at: Vector3 = lie + fall_dir * 0.75
	_rain_burst(8.12, face_at + Vector3(0, 0.3, 0), 0.5)
	_burst(8.12, face_at + Vector3(0, 0.05, 0), Vector3(0, 1, 0), 12, 2.2, {"spread": 1.0, "lift": 1.6, "gravity": 8.0, "life": 0.8, "size": 0.05, "colors": water})
	for t: float in [8.3, 8.5]:
		_burst(t, face_at + Vector3(0, 0.05, 0), Vector3(0, 1, 0), 8, 2.0, {"spread": 1.2, "lift": 1.5, "gravity": 8.0, "life": 0.7, "size": 0.045, "colors": water})
		c._cue(t, "sound", "step", {"a": a}, 0.5, 1.3)
	# E3 · elle lève le poing et sautille ; ses yeux brillent
	c._shot(8.04, {"rel": {"a": s}, "eye": [Vector3(0.3, 1.0, -1.65), Vector3(0.26, 1.18, -1.2)], "look": [{"a": s, "h": 1.2}, {"a": s, "s": "eyes", "h": -0.12}], "fov": [40, 32], "hand": 0.3, "ease": "smooth"})
	_glint(8.36, 8.66, s, 0.85)
	_bolt(8.2, 0.26, 1.0)
	_flash(t_ink - 0.06, 0.12)
	# PAPIER · elle file, Alice plonge derrière elle et rate son coup
	var ink: float = t_ink
	_jump(s, ink, _ink(-1.3, 0.12, 0.35))
	_jump(a, ink, _ink(1.05, -0.42, -0.1))
	c._face(s, ink, "dir", Vector3(-1, 0, 0))
	c._face(a, ink, "dir", Vector3(-1, 0, 0))
	_play(s, "fv_bleuette_ink", ink)
	_play(a, "fv_bleuette_alice_ink", ink)
	c._move(s, ink + 0.05, ink + 2.65, _ink(-1.3 - 0.55 * 2.6, 0.16, 0.35), "linear")
	c._move(a, ink + 0.01, ink + 2.5, _ink(0.6, -0.56, -0.1), "linear")
	_later(ink + 0.25, "cue", {"who": s, "cue": "cheer"})
	_burst(ink, _ink(0.75, 0.05, -0.1), Vector3(0, 1, 0), 22, 1.3, {"spread": 1.0, "lift": 0.9, "gravity": 0.5, "drag": 0.6, "life": 2.6, "size": 0.07})
	_burst(ink + 0.04, _ink(-0.9, 0.1, 0.35), Vector3(1, 0.4, 0), 10, 0.9, {"spread": 0.6, "lift": 0.4, "gravity": 0.3, "drag": 0.6, "life": 2.5, "size": 0.06})
	c._shot(ink, {"eye": [_ink(-0.5, 1.0, 6.3), _ink(-0.6, 1.0, 5.95)], "look": [_ink(-0.5, 0.85, 0.0), _ink(-0.65, 0.85, 0.0)], "fov": 42, "hand": 0.1, "safe": false})



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
	_snap_yaw(t)
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


# À la coupe sur le papier, les corps prennent net leur orientation : sans ça,
# le lissage du film les ferait pivoter sous nos yeux pendant 0,3 s.
func _snap_yaw(t: float) -> void :
	if t < t_ink or t > t_ink + 0.45: return
	for index: int in range(cinema.takes.size()):
		var take: Variant = cinema.takes[index]
		var target: float = float(cinema._facing(index, take, t, Vector3.ZERO))
		if absf(angle_difference(float(take.yaw), target)) < 0.0005: continue
		take.yaw = target
		take.visual.rotation.y = target


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
		"smoke_hand":
			var visual: PaperVisual = cinema.takes[int(data.who)].visual
			var hand: Vector3 = visual.socket_position(str(data.get("socket", "hand_r")))
			for k: int in range(2):
				comic.mark(6, hand + Vector3(randf_range(-0.03, 0.03), 0.05, randf_range(-0.03, 0.03)), Color("e4e0d8", 0.55), 0.06, 0.22, 0.5, {"vel": Vector3.UP * randf_range(0.45, 0.7), "drag": 1.6, "fade": 0.4, "ink": Color("8a857e"), "delay": 0.05 * float(k)})
		"smoke":
			var visual: Node3D = cinema.takes[int(data.who)].visual
			var muzzle: Vector3 = visual.attachment_position("shotgun_muzzle")
			comic.mark(6, muzzle + Vector3.UP * 0.1, Color("d9d4cc", 0.55), 0.15, 0.6, 0.9, {"vel": Vector3.UP * 0.7, "drag": 1.5, "fade": 0.3, "ink": Color("6f6a66")})
		"mute_words":
			if "_word_clock" in comic: comic.set("_word_clock", float(data.get("seconds", 1.0)))
			# words are pinned to the camera: one still showing would follow the cut onto the paper
			var words: Variant = comic.get("_words")
			if words is Array:
				for item: Variant in words:
					if bool(item.active):
						item.active = false
						item.node.visible = false
		"thunder":
			if is_instance_valid(_thunder_player) and _thunder_player.stream and is_instance_valid(world.audio):
				_thunder_player.volume_db = float(world.audio.volume_to_db(float(world.audio.effects_volume))) + linear_to_db(0.6 * float(data.get("gain", 1.0)) * PaperAudio.FILM_SFX_TRIM)
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
	# one eyelid patch per painted eye under the head's "Eyelids" attachment
	# (only the first keeps the name "Lid"); Lysia, Elly and Bleuette show a
	# single eye, the other one is under the hair. The rig's "eyes" socket sits
	# up to 14 cm above the painted eyes, so it is only the fallback (Simon, Alice).
	for holder: Node in visual.find_children("Eyelids", "BoneAttachment3D", true, false):
		for child: Node in holder.get_children():
			var mesh: MeshInstance3D = child as MeshInstance3D
			if mesh and mesh.mesh: points.append(mesh.global_transform * mesh.mesh.get_aabb().get_center())
	if not points.is_empty(): return points
	points.clear()
	var eyes: Vector3 = visual.socket_position("eyes") + Vector3.UP * float(EYE_DROP.get(str(visual.get("character_name")), 0.0))
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
	# the scores are mastered at -18 LUFS like the game's tracks; the PaperMusic bus already applies the
	# Music slider and PaperAudio.MUSIC_LEVEL (same level as the LMS themes). Rain, TV and thunder keep the
	# balance the film was mixed with against the score (PaperAudio.FILM_SFX_TRIM).
	if is_instance_valid(audio):
		music_db = 0.0 if float(audio.music_volume) > 0.001 else -80.0
		sfx_db = float(audio.volume_to_db(float(audio.effects_volume))) + linear_to_db(PaperAudio.FILM_SFX_TRIM)
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
