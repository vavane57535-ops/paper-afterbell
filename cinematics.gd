extends Node3D
class_name PaperCinema














class Take:
	var visual: PaperVisual
	var person: String = ""

	var path: Array = []

	var facing: Array = []

	var ops: Array = []

	var ramps: Array = []
	var cursor: int = 0
	var state: Dictionary = {}
	var stunned: bool = false
	var phase: bool = false
	var emote: String = ""
	var emote_clock: float = 0.0
	var yaw: float = 0.0
	var yaw_ready: bool = false
	var shown: bool = true

const VICTORY: Dictionary = {"Usayuko": "cheer", "Ashura": "thumbsup", "Simon": "cheer", "Lysia": "cheer", "Elly": "wave", "Bleuette": "cheer"}
const TINT: Dictionary = {"Ashura": Color("9fe0ee"), "Usayuko": Color("ffd98a"), "Simon": Color("dccbff"), "Lysia": Color("a6f0d8"), "Elly": Color("b9f3f5"), "Bleuette": Color("a9c8ff"), "Alice": Color("ff5a78")}
const GOLD: Color = Color("ffd24a")
const PAPER: Color = Color("fff6e4")
const CRIMSON: Color = Color("ff5a78")

const FRONT: Array[String] = ["Usayuko", "Lysia", "Simon", "Ashura"]
const LEAD: Array[String] = ["Usayuko", "Lysia", "Simon", "Ashura", "Elly", "Bleuette"]

const PLAYS: Array[String] = ["Bleuette", "Elly", "Simon", "Ashura", "Lysia", "Usayuko"]
const GAPS: Array[float] = [1.5, 1.25, 1.05, 0.95, 0.88, 0.82]

const BEYOND: float = 3.4

const VictoryFilm = preload("res://film_victories.gd")

var world: Node3D
var cast: Array[PaperVisual] = []
var takes: Array[Take] = []
var kind: String = ""
var elapsed: float = 0.0
var duration: float = 7.0
var anchor: Vector3
var finish: Vector3
var forward: Vector3 = Vector3.FORWARD
var right: Vector3 = Vector3.RIGHT
var focus_name: String = "Ashura"
var caption: String = ""
var chapter: String = ""
var last_shot: int = -1
var black: float = 0.0
var rim: OmniLight3D
var fill: OmniLight3D
var camera_focus: Vector3
var camera_desired: Vector3
var people: Array[String] = []
var alice_index: int = -1
var props: PaperCinemaProps
var _camera_ball: SphereShape3D = SphereShape3D.new()

var _visual_cache: Dictionary = {}
var _cast_root: Node3D
var _motion_query: PhysicsShapeQueryParameters3D
var _ray_query: PhysicsRayQueryParameters3D
var _time: float = -1.0
var _silent: bool = false
var _length: float = 12.0

var _track: Array = []
var _track_cursor: int = 0

var _shots: Array = []

var _flights: Array = []
var _door: Array = []
var _blackouts: Array = []
var _trauma: float = 0.0
var _shake_clock: float = 0.0

var _spots: Array[Vector3] = []
var _dark: bool = false

var victory: RefCounted = VictoryFilm.new()
var blocus: PaperFilmBlocus
var _marks_hidden: bool = false
var _sign_shown: bool = true






static func duration_for(film: String, names: Array = []) -> float:
	match film:
		"intro_yiero": return 196.0
		"intro_alice": return 5.6
		"intro_survivors": return 7.6
		"ending_lms": return VictoryFilm.duration_for(str(names[0]) if not names.is_empty() else "Ashura")
		"ending_killer": return 10.6
		PaperFilmBlocus.KIND: return PaperFilmBlocus.DURATION
		_: return float(_team_schedule(names).duration)

static func catalogue() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	rows.append(_entry("intro_yiero", "Prologue — Yiero", "intro", "intro_yiero", ["Simon", "Ashura", "Usayuko", "Elly", "Bleuette", "Lysia"], "Simon", "Le film du premier lancement : Simon et Ashura affrontent Yiero dans une dimension ténébreuse… puis Simon atterrit à l’école en plein combat."))
	for person: String in PaperData.NAMES:
		rows.append(_entry("lms_win_" + person, VictoryFilm.title_for(person), "lms_win", "ending_lms", [person], person, VictoryFilm.description_for(person)))
		rows.append(_entry("lms_loss_" + person, "Alice · " + person + " rattrapé", "lms_loss", "ending_killer", [person], person, "La dernière tentative de " + person + " échoue. Alice le rattrape, frappe et l’achève au sol."))
	for mask: int in range(1, 64):
		var team: Array = []
		for i: int in range(PaperData.NAMES.size()):
			if mask & (1 << i): team.append(PaperData.NAMES[i])
		var parts: PackedStringArray = []
		if "Simon" in team: parts.append("Simon lance sa flashbang")
		if "Ashura" in team: parts.append("Ashura envoie son drone")
		if "Usayuko" in team: parts.append("Usayuko frappe Alice")
		if "Lysia" in team: parts.append("Lysia repousse Alice")
		if "Elly" in team: parts.append("Elly soigne le groupe" if team.size() > 1 else "Elly esquive et pose sa zone de soin")
		if "Bleuette" in team: parts.append("Bleuette encourage le groupe" if team.size() > 1 else "Bleuette esquive et se donne du courage")
		rows.append(_entry("team_%02d" % mask, " + ".join(PackedStringArray(team)), "team", "ending_survivors", team, team[0], " ; ".join(parts) + ". Puis l’équipe s’échappe."))
	rows.append(_entry("blocus", PaperFilmBlocus.title(), "fins", PaperFilmBlocus.KIND, PaperData.NAMES.duplicate(), "Usayuko", PaperFilmBlocus.description()))
	return rows

static func _entry(id: String, title: String, category: String, film: String, names: Array, focus: String, description: String) -> Dictionary:
	return {"id": id, "title": title, "category": category, "kind": film, "participants": names, "focus": focus, "duration": duration_for(film, names), "description": description}


static func _team_schedule(names: Array) -> Dictionary:
	var team: Array = []
	for person: String in LEAD:
		if person in names: team.append(person)
	if team.is_empty(): team = ["Ashura"]
	var lead: String = team[0]
	var first: float = 1.35
	var gap: float = GAPS[clampi(team.size(), 1, 6) - 1]

	var answer: Dictionary = {"Usayuko": 1.25, "Lysia": 1.55}
	var clock: float = first + float(answer.get(lead, 0.55))
	var plays: Array = []
	for person: String in PLAYS:
		if person not in team or (person == lead and answer.has(lead)): continue
		plays.append([person, clock])
		clock += gap
	var tail: Dictionary = {"Simon": 0.7, "Ashura": 0.45, "Usayuko": 0.25, "Lysia": 0.4}
	var run: float = clock - gap + 0.95 if not plays.is_empty() else clock + 0.2
	if not plays.is_empty(): run += float(tail.get(str(plays[plays.size() - 1][0]), 0.0))
	return {"lead": lead, "first": first, "plays": plays, "run": run, "arrive": run + 2.1, "duration": run + 2.1 + 3.9}





func setup(owner: Node3D) -> void :
	world = owner;_camera_ball.radius = 0.22;hide()
	_cast_root = Node3D.new();_cast_root.name = "CastCache";add_child(_cast_root)
	rim = OmniLight3D.new();rim.name = "Rim";add_child(rim)
	fill = OmniLight3D.new();fill.name = "Fill";add_child(fill)
	_motion_query = PhysicsShapeQueryParameters3D.new()
	_motion_query.shape = _camera_ball;_motion_query.collision_mask = 1;_motion_query.margin = 0.05
	_ray_query = PhysicsRayQueryParameters3D.new()
	_ray_query.collision_mask = 1

func begin(next: String, participants: Array, focus: String = "Ashura") -> void :
	stop();kind = next;focus_name = focus;elapsed = 0
	anchor = world.school.cinematic_anchor;finish = world.school.cinematic_exit
	forward = finish - anchor;forward.y = 0;forward = forward.normalized()
	if forward.length_squared() < 0.01: forward = Vector3.FORWARD
	right = Vector3.UP.cross(forward).normalized()
	for name_value: Variant in participants:
		var person: String = str(name_value)
		if person in PaperData.NAMES and person not in people: people.append(person)
	if next == "intro_alice": people.clear()
	elif next in ["ending_lms", "ending_killer"]: people = [focus if focus in PaperData.NAMES else "Ashura"]
	elif people.is_empty(): people = [focus if focus in PaperData.NAMES else "Ashura"]
	if next in ["ending_lms", "ending_killer"]: focus_name = people[0]
	_length = anchor.distance_to(finish)
	if next == "intro_alice":
		anchor += Vector3.UP * 30.0;finish = anchor + forward * 7.0
	elif world.school.has_method("set_cinematic_exit_open"):
		world.school.set_cinematic_exit_open(next not in ["ending_killer", PaperFilmBlocus.KIND])
	for person: String in people: _add_actor(person)
	if next not in ["intro_survivors", PaperFilmBlocus.KIND]: alice_index = takes.size();_add_actor("Alice")
	props = PaperCinemaProps.new();add_child(props);props.reduce_flashes = _flashes_reduced();props.setup(anchor, right, forward, next, people)
	rim.omni_range = 11;rim.light_energy = 1.25;rim.light_color = Color("9caee4")
	fill.omni_range = 9;fill.light_energy = 0.7;fill.light_color = Color("eddfd3")
	duration = duration_for(next, people)
	_spots.resize(takes.size())
	_dark = next in ["ending_killer", "intro_alice"]
	match next:
		"intro_survivors": _write_intro_survivors()
		"intro_alice": _write_intro_alice()
		"ending_killer": _write_kill()
		"ending_lms": victory.write(self, people[0])
		PaperFilmBlocus.KIND:
			blocus = PaperFilmBlocus.new();add_child(blocus);blocus.write(self)
		_: _write_escape()
	_seal()
	show()
	var comic: Node = _comic()
	if comic: comic.set("frame_guard", true)
	_restart()
	update(0.0, 0.0)

func _add_actor(person: String) -> void :
	var visual: PaperVisual = _visual_cache.get(person)
	if not is_instance_valid(visual):
		visual = PaperVisual.new()

		visual.lod_enabled = false
		_cast_root.add_child(visual);visual.setup(person)
		visual.anim_fx.connect(_on_cue.bind(visual))
		_visual_cache[person] = visual
	visual.rotation = Vector3.ZERO
	visual.show();cast.append(visual)
	var take: Take = Take.new()
	take.visual = visual
	take.person = person
	takes.append(take)

func stop() -> void :
	var was_playing: bool = not kind.is_empty()
	victory.stop()
	_hide_game_marks(false)
	if world and is_instance_valid(world.school) and world.school.has_method("set_cinematic_exit_open"): world.school.set_cinematic_exit_open(false)

	for n: Node in get_children():
		if n == _cast_root or n == rim or n == fill: continue
		remove_child(n);n.queue_free()
	if is_instance_valid(_cast_root):
		for visual: Node in _cast_root.get_children():
			visual.hide()
			if visual is PaperVisual: (visual as PaperVisual).mood_override = ""
	cast.clear();takes.clear();people.clear();props = null;alice_index = -1;blocus = null
	_track.clear();_shots.clear();_flights.clear();_door.clear();_blackouts.clear();_spots.clear()
	hide();kind = "";last_shot = -1;caption = "";chapter = "";_time = -1.0;_trauma = 0.0
	var comic: Node = _comic() if world else null
	if comic:
		comic.set("frame_guard", false)

		if was_playing: comic.call("clear")


func release_cache() -> void :
	stop()
	for visual: Variant in _visual_cache.values():
		if is_instance_valid(visual): visual.queue_free()
	_visual_cache.clear()

func _flashes_reduced() -> bool:
	if not world: return false
	var options: Variant = world.get("options")
	var reduced: bool = options is Dictionary and bool(options.get("reduce_flashes", false))
	var ui: Variant = world.get("ui")
	return reduced or (is_instance_valid(ui) and bool(ui.get("reduced_motion")))





func seek(time: float) -> void :
	if kind.is_empty() or takes.is_empty(): return
	_jump(clampf(time, 0.0, duration))
	update(time, 0.0)

func update(t: float, delta: float) -> void :
	if kind.is_empty() or takes.is_empty(): return
	t = clampf(t, 0, duration);caption = "";chapter = ""
	if t < _time - 0.0005 or t - _time > 0.3: _jump(t)
	elif t > _time: _step(t, false)
	elapsed = t
	if kind not in ["intro_alice", "ending_killer", PaperFilmBlocus.KIND] and world.school.has_method("sample_cinematic_exit_open"):
		world.school.sample_cinematic_exit_open(t + 2.0)
	black = 1.0 - smoothstep(0, 0.28, t)
	if t > duration - 0.32: black = smoothstep(duration - 0.32, duration, t)
	for cut: Array in _blackouts:
		if t >= float(cut[0]) and t < float(cut[1]): black = 1.0
	_place_props(t)
	_camera(t, delta)
	_hide_game_marks(true)
	if victory.active: victory.update(t, delta)
	if is_instance_valid(blocus): blocus.update(t, delta)


# Panneau de jeu « SORTIE · … » et anneau doré de la sortie (map_interactables) : jamais dans un film
# (fuite en équipe, victoire d'Alice… ; update_exit réaffiche l'anneau à chaque image).
func _hide_game_marks(on: bool) -> void :
	var items: Variant = world.get("map_interactables") if world else null
	if not is_instance_valid(items): return
	var sign: Variant = items.get("exit_sign")
	var ring: Variant = items.get("exit_glow")
	var sign_ok: bool = sign is Node3D and is_instance_valid(sign)
	if on:
		if not _marks_hidden and sign_ok: _sign_shown = (sign as Node3D).visible
		_marks_hidden = true
		if sign_ok: (sign as Node3D).visible = false
		if ring is Node3D and is_instance_valid(ring): (ring as Node3D).visible = false
	elif _marks_hidden:
		_marks_hidden = false
		if sign_ok: (sign as Node3D).visible = _sign_shown


func _jump(t: float) -> void :
	if t < _time or _time < 0.0: _restart()
	_silent = true
	var at: float = maxf(_time, 0.0)
	if _time < 0.0: _step(0.0, true)
	while at < t - 0.0001:
		at = minf(t, at + 1.0 / 30.0)
		_step(at, true)
	_silent = false

func _restart() -> void :
	_time = -1.0
	_track_cursor = 0
	_trauma = 0.0
	for take: Take in takes:
		take.cursor = 0
		take.state = {}
		take.stunned = false
		take.phase = false
		take.emote = ""
		take.emote_clock = 0.0
		take.yaw_ready = false
		take.shown = true
		take.visual.mood_override = ""
		take.visual.reset_motion()
		take.visual.set_life_state("alive")
	var effects: Variant = world.get("presentation")
	if is_instance_valid(effects) and is_instance_valid(effects.get("comic")): effects.comic.clear()

func _step(t: float, silent: bool) -> void :
	var dt: float = clampf(t - maxf(_time, 0.0), 0.0, 0.1) if _time >= 0.0 else 0.0
	for index: int in range(takes.size()):
		var take: Take = takes[index]
		while take.cursor < take.ops.size() and float(take.ops[take.cursor][0]) <= t:
			_run_op(index, take.ops[take.cursor])
			take.cursor += 1
		for ramp: Array in take.ramps:
			var start: float = float(ramp[0])
			var end: float = float(ramp[1])
			if t < start: continue
			var key: String = str(ramp[2])
			if t < end:
				take.state[key] = lerpf(float(ramp[3]), float(ramp[4]), (t - start) / maxf(0.001, end - start))
			elif _time < end:

				if is_zero_approx(float(ramp[4])): take.state.erase(key)
				else: take.state[key] = float(ramp[4])
		var spot: Vector3 = _world_spot(_where(take, t))
		var velocity: Vector3 = (spot - _world_spot(_where(take, t - 0.03))) / 0.03
		var visual: PaperVisual = take.visual
		visual.position = spot
		var target: float = _facing(index, take, t, velocity)
		if not take.yaw_ready or dt <= 0.0:
			take.yaw = target
			take.yaw_ready = true
		else:
			take.yaw = lerp_angle(take.yaw, target, 1.0 - exp( - dt * 11.0))
		visual.rotation = Vector3(0.0, take.yaw, 0.0)
		if not take.emote.is_empty():
			take.emote_clock += dt
			take.state["emote_id"] = take.emote
			take.state["emote_time"] = take.emote_clock
			if take.emote_clock > 2.6:
				take.emote = ""
				take.state.erase("emote_id")
				take.state.erase("emote_time")
		if visual.visible != take.shown: visual.visible = take.shown
		visual.set_combat_state(take.state)
		if dt > 0.0 or _time < 0.0: visual.animate(maxf(dt, 1.0 / 240.0), velocity, take.stunned, take.phase)
	while _track_cursor < _track.size() and float(_track[_track_cursor][0]) <= t:
		if not silent: _run_cue(_track[_track_cursor])
		_track_cursor += 1
	_time = t

func _run_op(index: int, op: Array) -> void :
	var take: Take = takes[index]
	var visual: PaperVisual = take.visual
	var a: Variant = op[2]
	var b: Variant = op[3]
	match str(op[1]):
		"trigger":
			visual.trigger(str(a))
			if not _silent and b != false and world.audio and world.audio.has_method("sfx_ability"): world.audio.sfx_ability(str(a), visual.global_position, world.camera.global_position)
		"play": visual.play(str(a))
		"state": take.state.merge(a as Dictionary, true)
		"unset":
			for key: Variant in (a as Array): take.state.erase(key)
		"stun": take.stunned = bool(a)
		"phase": take.phase = bool(a)
		"life": visual.set_life_state(str(a))
		"emote":
			take.emote = str(a)
			take.emote_clock = 0.0
			if take.emote.is_empty():
				take.state.erase("emote_id")
				take.state.erase("emote_time")
		"show": take.shown = bool(a)
		"hit": visual.react_to_hit(float(a), takes[int(b)].visual.global_position if int(b) >= 0 and int(b) < takes.size() else Vector3.INF)
		"mood": visual.mood_override = str(a)
		"hitstop": visual.hit_stop(float(a))


func _on_cue(cue: String, visual: PaperVisual) -> void :
	if _silent or kind.is_empty() or not visual.visible: return
	var effects: Variant = world.get("presentation")
	if is_instance_valid(effects): effects.visual_fx(cue, visual)
	if not world.audio or not world.audio.has_method("sfx") or not world.camera.is_inside_tree(): return
	match cue:
		"step_l", "step_r": world.audio.sfx("step", visual.global_position, world.camera.global_position, 0.8)
		"land", "land_hard", "crack": world.audio.sfx("ground_impact", visual.global_position, world.camera.global_position, 0.5)





func _ease(u: float, mode: String) -> float:
	u = clampf(u, 0.0, 1.0)
	match mode:
		"linear": return u
		"out": return 1.0 - (1.0 - u) * (1.0 - u)
		"dash": return 1.0 - pow(1.0 - u, 3.0)
		"in": return u * u
		"jump": return 1.0 if u >= 1.0 else 0.0
		"run":

			var accelerate: float = 0.12
			var brake: float = 0.2
			var cruise: float = 1.0 / (1.0 - accelerate * 0.5 - brake * 0.5)
			if u < accelerate: return cruise * u * u / (2.0 * accelerate)
			if u > 1.0 - brake:
				var left: float = 1.0 - u
				return 1.0 - cruise * left * left / (2.0 * brake)
			return cruise * (u - accelerate * 0.5)
	return smoothstep(0.0, 1.0, u)

func _where(take: Take, t: float) -> Vector3:
	var path: Array = take.path
	if path.is_empty(): return Vector3.ZERO
	if t <= float(path[0][0]): return path[0][1]
	for k: int in range(1, path.size()):
		if t <= float(path[k][0]):
			var from: Array = path[k - 1]
			var to: Array = path[k]
			return (from[1] as Vector3).lerp(to[1], _ease((t - float(from[0])) / maxf(0.001, float(to[0]) - float(from[0])), str(to[2])))
	return path[path.size() - 1][1]

func _world_spot(local: Vector3) -> Vector3:
	return anchor + right * local.x + Vector3.UP * local.y + forward * local.z

func _world_direction(local: Vector3) -> Vector3:
	return right * local.x + Vector3.UP * local.y + forward * local.z

func _facing(index: int, take: Take, t: float, velocity: Vector3) -> float:
	var mode: String = "move"
	var value: Variant = null
	for key: Array in take.facing:
		if float(key[0]) > t: break
		mode = str(key[1])
		value = key[2]
	var direction: Vector3 = Vector3.ZERO
	match mode:
		"at":
			var other: int = int(value)
			if other >= 0 and other < takes.size() and other != index: direction = takes[other].visual.position - take.visual.position
		"dir": direction = _world_direction(value)
		_:
			if Vector2(velocity.x, velocity.z).length() > 0.5: direction = velocity
	direction.y = 0.0
	if direction.length_squared() < 0.0004: return take.yaw
	return atan2( - direction.x, - direction.z)



func _spot(spec: Variant) -> Vector3:
	if spec is Vector3: return _world_spot(spec)
	if not spec is Dictionary: return anchor
	var data: Dictionary = spec
	var at: Vector3 = anchor
	if data.has("a"):
		var index: int = clampi(int(data.a), 0, takes.size() - 1)
		var visual: PaperVisual = takes[index].visual
		at = visual.fx_source().socket_position(str(data.s)) if data.has("s") else visual.position
	elif data.has("mid"):
		var pair: Array = data.mid
		at = (takes[int(pair[0])].visual.position + takes[int(pair[1])].visual.position) * 0.5
	elif data.has("group"):
		at = _group_center()
	if data.has("h"): at += Vector3.UP * float(data.h)
	if data.has("o"): at += _world_direction(data.o)
	return at

func _group_center() -> Vector3:
	var center: Vector3 = Vector3.ZERO
	var count: int = 0
	for index: int in range(takes.size()):
		if index == alice_index: continue
		center += takes[index].visual.position
		count += 1
	return center / float(maxi(1, count)) if count > 0 else anchor





func _comic() -> Node:
	var effects: Variant = world.get("presentation")
	if not is_instance_valid(effects): return null
	var layer: Variant = effects.get("comic")
	return layer if is_instance_valid(layer) else null

func _screen() -> Node:
	var ui: Variant = world.get("ui")
	if not is_instance_valid(ui): return null
	var layer: Variant = ui.get("screen_fx")
	return layer if is_instance_valid(layer) else null

func _sound(sound: String, at: Vector3, gain: float = 1.0, pitch: float = 1.0) -> void :
	if world.audio and world.audio.has_method("sfx") and world.camera.is_inside_tree(): world.audio.sfx(sound, at, world.camera.global_position, gain, pitch)

func _run_cue(cue: Array) -> void :
	var a: Variant = cue[2]
	var b: Variant = cue[3]
	var c: Variant = cue[4]
	var d: Variant = cue[5]
	var comic: Node = _comic()
	var screen: Node = _screen()
	match str(cue[1]):
		"sound": _sound(str(a), _spot(b), float(c) if c != null else 1.0, float(d) if d != null else 1.0)
		"event":

			var data: Dictionary = (b as Dictionary).duplicate()
			for key: Variant in data.keys():
				if data[key] is Dictionary or (data[key] is Vector3 and str(key) in ["position", "from", "to", "source_position"]): data[key] = _spot(data[key])
			var effects: Variant = world.get("presentation")
			if is_instance_valid(effects): effects.receive(str(a), data)
			if world.audio and world.audio.has_method("receive_event"): world.audio.receive_event(str(a), data, world.camera.global_position)
		"pop":
			if comic: comic.pop(_spot(a), _world_direction(b) if b is Vector3 else Vector3.UP, c if c is Color else PAPER, float(d) if d != null else 1.0)
		"word":
			if comic: comic.word(str(a), _spot(b), c if c is Color else PAPER, float(d) if d != null else 1.0)
		"stars":
			if comic: comic.stars(_spot(a), int(b) if b != null else 4)
		"dust_ring":
			if comic: comic.dust_ring(_spot(a), float(b) if b != null else 1.0)
		"crack":
			if comic: comic.crack(_spot(a), float(b) if b != null else 1.6)
		"sparkles":
			if comic: comic.sparkles(_spot(a), b if b is Color else GOLD, int(c) if c != null else 6, float(d) if d != null else 0.8)
		"pillars":
			if comic: comic.pillars(_spot(a), b if b is Color else GOLD, int(c) if c != null else 6, float(d) if d != null else 0.6)
		"sweat":
			if comic: comic.sweat(_spot(a), int(b) if b != null else 3)
		"mark":
			if comic: comic.mark(int(a), _spot(b), c if c is Color else PAPER, float((d as Array)[0]), float((d as Array)[1]), float((d as Array)[2]), (d as Array)[3] if (d as Array).size() > 3 else {})
		"spikes":
			var effects: Variant = world.get("presentation")
			if is_instance_valid(effects): effects.spikes(_spot(a), _spot(b))
		"shake": _trauma = clampf(_trauma + float(a), 0.0, 1.0)
		"impact":
			if screen: screen.impact(float(a), b != false)
		"pulse":
			if screen: screen.pulse(a, float(b) if b != null else 0.6)
		"rush":
			if screen: screen.rush(float(a))
		"frame":
			if screen: screen.frame(a, float(b) if b != null else 0.07)
		"splash":
			if screen: screen.splash(float(a) if a != null else 1.2)

func _place_props(t: float) -> void :
	if props == null: return
	for entry: Array in _door:
		props.set_door(smoothstep(float(entry[0]), float(entry[1]), t))
	var grenade_shown: bool = false
	var drone_shown: bool = false
	for flight: Array in _flights:
		var start: float = float(flight[0])
		var end: float = float(flight[1])
		var linger: float = float(flight[6])
		if t < start or t > end + linger: continue
		var u: float = clampf((t - start) / maxf(0.01, end - start), 0.0, 1.0)
		var from: Vector3 = _spot(flight[3])
		var to: Vector3 = _spot(flight[4])
		var at: Vector3 = from.lerp(to, u) + Vector3.UP * sin(u * PI) * float(flight[5])
		if str(flight[2]) == "grenade":
			grenade_shown = t <= end
			props.place_grenade(at, t, grenade_shown)
		else:

			var fall: float = clampf((t - end) / maxf(0.01, linger), 0.0, 1.0)
			at += Vector3.DOWN * fall * fall * 1.3 + right * 0.5 * fall
			drone_shown = true
			props.place_drone(at, to - from, t, fall, true)
	if not grenade_shown: props.place_grenade(Vector3.ZERO, t, false)
	if not drone_shown: props.place_drone(Vector3.ZERO, Vector3.FORWARD, t, 0.0, false)





func _camera(t: float, delta: float) -> void :
	if _shots.is_empty(): return
	var index: int = 0
	for k: int in range(_shots.size()):
		if float(_shots[k][0]) <= t: index = k
	var start: float = float(_shots[index][0])
	var end: float = float(_shots[index + 1][0]) if index + 1 < _shots.size() else duration
	var spec: Dictionary = _shots[index][1]
	var u: float = _ease((t - start) / maxf(0.01, end - start), str(spec.get("ease", "linear")))
	var eye_value: Variant = spec.get("eye", Vector3(3.0, 1.6, 3.0))
	var offset: Vector3 = (eye_value[0] as Vector3).lerp(eye_value[1], u) if eye_value is Array else eye_value
	var base: Vector3 = _spot(spec.rel) if spec.has("rel") else anchor
	if spec.has("span"):

		var pair: Array = spec.span
		var apart: float = takes[int(pair[0])].visual.position.distance_to(takes[int(pair[1])].visual.position)
		var widen: float = clampf(0.62 + 0.2 * apart, 0.85, 2.4)
		offset = Vector3(offset.x * widen, offset.y * lerpf(1.0, widen, 0.35), offset.z)
	var eye: Vector3 = base + _world_direction(offset)
	var look_value: Variant = spec.get("look", {"group": true, "h": 1.2})
	var target: Vector3 = _spot(look_value[0]).lerp(_spot(look_value[1]), u) if look_value is Array else _spot(look_value)
	var fov_value: Variant = spec.get("fov", 44.0)
	var fov: float = lerpf(float(fov_value[0]), float(fov_value[1]), u) if fov_value is Array else float(fov_value)

	var hand: float = float(spec.get("hand", 0.2))
	eye += right * sin(t * 1.3 + float(index)) * 0.035 * hand + Vector3.UP * sin(t * 1.7 + 1.3) * 0.03 * hand
	target += right * sin(t * 0.9 + 2.0) * 0.03 * hand + Vector3.UP * sin(t * 1.1) * 0.025 * hand
	camera_focus = target;camera_desired = eye
	var safe: Vector3 = _safe_eye(target, eye) if bool(spec.get("safe", true)) else eye
	world.camera.position = safe
	if safe.distance_squared_to(target) > 0.01: world.camera.look_at(target)
	world.camera.fov = fov
	var roll_value: Variant = spec.get("roll", 0.0)
	var roll: float = lerpf(float(roll_value[0]), float(roll_value[1]), u) if roll_value is Array else float(roll_value)
	if roll != 0.0: world.camera.rotate_object_local(Vector3.BACK, deg_to_rad(roll))

	if _trauma > 0.0:
		_trauma = maxf(0.0, _trauma - delta * 1.9)
		var scale: float = float(world.call("shake_scale")) if world.has_method("shake_scale") else 1.0
		var amount: float = _trauma * _trauma * scale
		_shake_clock += delta
		var clock: float = _shake_clock
		world.camera.rotate_object_local(Vector3.RIGHT, 0.03 * amount * (sin(clock * 41.0) * 0.7 + sin(clock * 97.0 + 1.7) * 0.3))
		world.camera.rotate_object_local(Vector3.UP, 0.024 * amount * (sin(clock * 37.0 + 0.5) * 0.7 + sin(clock * 83.0 + 2.9) * 0.3))
		world.camera.rotate_object_local(Vector3.BACK, 0.045 * amount * (sin(clock * 29.0 + 1.1) * 0.7 + sin(clock * 71.0 + 0.3) * 0.3))
	rim.position = target - forward * 2.3 - right * 2.1 + Vector3.UP * 2.2
	rim.light_color = Color("a9b8e3") if _dark else Color("d0dcec")
	rim.light_energy = 1.1
	fill.position = target + forward * 3.2 + right * 2.4 + Vector3.UP * 1.6
	fill.light_energy = 0.6 if _dark else 0.78
	last_shot = index

func _safe_eye(target: Vector3, desired: Vector3) -> Vector3:
	var motion: Vector3 = desired - target
	if motion.length() < 0.01: return desired
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state

	_motion_query.transform = Transform3D(Basis.IDENTITY, target);_motion_query.motion = motion
	var fractions: PackedFloat32Array = space.cast_motion(_motion_query)
	var fraction: float = fractions[0] if fractions.size() > 0 else 1.0
	var safe: Vector3 = target + motion * maxf(0, fraction - 0.025 / motion.length())
	_ray_query.from = target;_ray_query.to = safe
	var hit: Dictionary = space.intersect_ray(_ray_query)
	if not hit.is_empty(): safe = Vector3(hit.position) - motion.normalized() * 0.28
	return safe





func _put(i: int, spot: Vector3) -> void :
	takes[i].path = [[0.0, spot, "linear"]]
	_spots[i] = spot


func _move(i: int, t0: float, t1: float, spot: Vector3, ease: String = "smooth") -> void :
	var path: Array = takes[i].path
	var last: float = float(path[path.size() - 1][0]) if not path.is_empty() else 0.0
	t0 = maxf(t0, last)
	t1 = maxf(t1, t0 + 0.02)
	if t0 > last + 0.001: path.append([t0, _spots[i], "linear"])
	path.append([t1, spot, ease])
	_spots[i] = spot

func _face(i: int, t: float, mode: String, value: Variant = null) -> void :
	takes[i].facing.append([t, mode, value])

func _do(i: int, t: float, op: String, a: Variant = null, b: Variant = null) -> void :
	takes[i].ops.append([t, op, a, b])

func _ramp(i: int, t0: float, t1: float, key: String, from: float, to: float) -> void :
	takes[i].ramps.append([t0, t1, key, from, to])

func _cue(t: float, op: String, a: Variant = null, b: Variant = null, c: Variant = null, d: Variant = null) -> void :
	_track.append([t, op, a, b, c, d])

func _shot(t: float, spec: Dictionary) -> void :
	_shots.append([t, spec])

func _seal() -> void :
	for take: Take in takes:
		take.ops.sort_custom( func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		take.facing.sort_custom( func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		if take.path.is_empty(): take.path = [[0.0, Vector3.ZERO, "linear"]]
	_track.sort_custom( func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	_shots.sort_custom( func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	if _shots.is_empty(): _shot(0.0, {"eye": Vector3(4.8, 2.7, 6.8), "look": {"group": true, "h": 1.3}, "fov": 48.0})





func _blow(t: float, victim: int, from: int, word_key: String, tint: Color, weight: float = 1.0) -> void :
	var toward: Vector3 = (_spots[from] - _spots[victim]) if from >= 0 else Vector3(0, 0, -1)
	toward.y = 0.0
	toward = toward.normalized() if toward.length_squared() > 0.001 else Vector3(0, 0, -1)
	_cue(t, "pop", {"a": victim, "h": 1.15, "o": toward * 0.4}, toward, tint, weight)
	_cue(t, "word", word_key, {"a": victim, "h": 1.8, "o": toward * 0.3}, tint.lerp(PAPER, 0.35), 0.95 * weight)
	_cue(t, "stars", {"a": victim, "s": "over"}, 3)
	_cue(t, "sound", "hit", {"a": victim})
	_cue(t, "shake", 0.38 * weight)
	_cue(t, "impact", 0.6 * weight, true)
	_do(victim, t, "hit", 1.0, from)
	_do(victim, t, "hitstop", 0.06)
	if from >= 0: _do(from, t, "hitstop", 0.09)


func _stun(i: int, t: float, seconds: float) -> void :
	_do(i, t, "stun", true)
	_do(i, t + seconds, "stun", false)


func _knock(i: int, t: float, metres: float, direction: Vector3 = Vector3(0, 0, -1)) -> void :
	_do(i, t, "state", {"forced_time": 0.55, "force_name": "knock"})
	_do(i, t + 0.5, "unset", ["forced_time", "force_name"])
	_move(i, t, t + 0.5, _spots[i] + direction.normalized() * metres, "out")


func _alice_misses(t: float, target: int, hop: Vector3 = Vector3(0, 0, 0.95)) -> void :
	var a: int = alice_index
	_face(a, t - 0.3, "at", target)
	_move(a, t - 0.22, t + 0.02, Vector3(_spots[target].x * 0.8, 0.0, _spots[target].z - 1.75), "dash")
	_do(a, t, "trigger", "slash")
	_do(target, t + 0.02, "play", "startle")
	_move(target, t + 0.02, t + 0.34, _spots[target] + hop, "out")
	_cue(t + 0.14, "word", "miss", {"a": target, "h": 1.55}, PAPER, 0.85)
	_cue(t + 0.12, "sweat", {"a": target, "s": "head"}, 2)





func _write_escape() -> void :
	var a: int = alice_index
	var schedule: Dictionary = _team_schedule(people)
	var lead: int = people.find(str(schedule.lead))
	var first: float = float(schedule.first)
	var run: float = float(schedule.run)
	var arrive: float = float(schedule.arrive)

	var front: Array[int] = []
	var back: Array[int] = []
	for person: String in FRONT:
		if person in people: front.append(people.find(person))
	for person: String in ["Elly", "Bleuette"]:
		if person in people: back.append(people.find(person))
	if front.is_empty():
		front = back.duplicate()
		back.clear()
	var half: float = float(front.size() - 1) * 0.5 * 1.4
	for k: int in range(front.size()):
		var x: float = float(k) * 1.4 - half
		_put(front[k], Vector3(x, 0, -0.25))
		_move(front[k], 0.0, 1.05, Vector3(x, 0, 0.5))
	for k: int in range(back.size()):
		var flank: float = -1.0 if (people[back[k]] == "Elly") == (back.size() > 1 or true) else 1.0
		if back.size() == 1: flank = 1.0 if front.size() % 2 == 1 else -1.0
		var x: float = flank * (half + 1.45)
		_put(back[k], Vector3(x, 0, 0.6))
		_move(back[k], 0.0, 1.1, Vector3(x, 0, 1.25))
	for i: int in range(people.size()):
		_face(i, 0.0, "at", a)
		_do(i, 0.0, "state", {"chased": 3.0})

	_put(a, Vector3(_spots[lead].x * 0.4, 0, -6.6))
	_face(a, 0.0, "at", lead)
	_move(a, 0.0, 1.1, Vector3(_spots[lead].x * 0.6, 0, -2.3), "smooth")
	_shot(0.0, {"rel": {"a": a}, "eye": [Vector3(1.25, 0.85, -2.3), Vector3(0.8, 1.05, -1.6)], "look": [{"group": true, "h": 1.15}, {"a": lead, "h": 1.2}], "fov": [42, 46], "hand": 0.5})
	var busy: float = _answer(lead, first)

	var side: float = 1.0
	var plays: Array = schedule.plays
	for index: int in range(plays.size()):
		var who: int = people.find(str(plays[index][0]))
		var at: float = float(plays[index][1])
		var supports: bool = people[who] in ["Elly", "Bleuette"]

		if supports and busy < at - 0.2 and index > 0:
			_alice_misses(at + 0.1, front[index % front.size()])
			busy = at + 0.5
		side = - side
		_frame_play(at, who, side)
		busy = maxf(busy, _strike(who, at, busy))

	for i: int in range(people.size()):
		var row: int = i / 3
		var in_row: int = mini(3, people.size() - row * 3)
		var lane: float = (float(i % 3) - float(in_row - 1) * 0.5) * 1.2 + (0.55 if row > 0 else 0.0)
		var leave: float = run + 0.07 * float(i)
		_do(i, leave, "unset", ["emote_id", "emote_time"])
		_do(i, leave, "emote", "")
		_face(i, leave, "move")
		_move(i, leave, arrive + 0.1 * float(i % 3) + 0.14 * float(row), Vector3(lane, 0, _length + BEYOND - float(row) * 1.05), "run")
		var stop: float = arrive + 0.1 * float(i % 3) + 0.14 * float(row)
		_do(i, stop - 0.1, "unset", ["chased"])
		_face(i, stop - 0.25, "dir", Vector3(0.2 * sin(float(i) * 2.1), 0, -1))
		_do(i, stop + 0.55 + 0.1 * float(i), "emote", str(VICTORY.get(people[i], "cheer")))
		_do(i, stop + 0.55 + 0.1 * float(i), "mood", "grin")
	_cue(run + 0.1, "rush", 0.85)
	_cue(run + 0.05, "sound", "boost", {"group": true}, 0.7)
	_cue(arrive + 0.6, "event", "escaped", {"position": {"group": true}})
	_cue(arrive + 0.6, "sound", "encourage", {"group": true})
	_cue(arrive + 0.75, "sparkles", {"group": true, "h": 1.5}, GOLD, 8, 1.4)
	_cue(arrive + 0.6, "pulse", Color(1.0, 0.92, 0.6, 0.3), 1.2)

	var free: float = clampf(busy, run + 0.25, run + 0.85)
	_do(a, free, "stun", false)
	_do(a, free, "unset", ["blind"])
	_face(a, free, "dir", Vector3(0, 0, 1))
	if busy < run:

		_do(a, run + 0.05, "trigger", "slash")
		_cue(run + 0.2, "word", "miss", {"a": a, "h": 2.2, "o": Vector3(0, 0, 1.2)}, PAPER, 0.9)
		_move(a, run + 0.5, run + 1.5, _spots[a] + Vector3(0, 0, 3.2))
		free = run + 1.5
	else:
		_move(a, free + 0.1, free + 0.8, _spots[a] + Vector3(0, 0, 1.4))
		free += 0.8
	var tantrum: float = maxf(free + 0.05, arrive - 0.75)
	_do(a, tantrum, "trigger", "fury")
	_cue(tantrum + 0.64, "shake", 0.5)
	_cue(tantrum + 0.9, "word", "roar", {"a": a, "h": 2.5}, CRIMSON, 1.3)
	_cue(tantrum + 0.9, "impact", 0.7, true)
	_cue(tantrum + 0.9, "sound", "shadow", {"a": a}, 0.8, 0.8)

	var ahead: float = 3.0 + 0.3 * float(people.size())
	_shot(run, {"rel": {"group": true}, "eye": [Vector3(0.8, 0.55, ahead + 0.5), Vector3(0.5, 0.65, ahead)], "look": {"group": true, "h": 1.05}, "fov": [54, 58], "hand": 0.8})
	_shot(run + 0.95, {"rel": {"group": true}, "eye": [Vector3(-3.9, 1.25, 1.2), Vector3(-3.4, 1.1, 2.6)], "look": {"group": true, "h": 1.1}, "fov": 47, "hand": 0.7})
	_shot(tantrum + 0.25, {"rel": {"a": a}, "eye": [Vector3(1.5, 0.6, 2.9), Vector3(1.1, 0.75, 2.3)], "look": {"a": a, "h": 1.25}, "fov": [38, 34], "hand": 0.4})
	var wide: float = 2.5 + 0.32 * float(people.size())
	_shot(maxf(arrive + 0.45, tantrum + 1.75), {"rel": {"group": true}, "eye": [Vector3(1.3, 1.25, - wide - 0.5), Vector3(0.9, 1.35, - wide)], "look": {"group": true, "h": 1.1}, "fov": [47, 43], "hand": 0.3})
	_shot(duration - 1.25, {"rel": {"group": true}, "eye": [Vector3(-1.9, 2.0, 3.4), Vector3(-1.7, 2.1, 3.8)], "look": [{"group": true, "h": 1.3}, {"a": a, "h": 1.4}], "fov": [36, 30], "hand": 0.2})



func _frame_play(t: float, who: int, side: float) -> void :
	if people[who] in ["Elly", "Bleuette"]:
		var out: float = 1.0 if _spots[who].x >= 0.0 else -1.0
		_shot(t, {"rel": {"a": who}, "eye": [Vector3(out * 1.9, 1.3, -3.0), Vector3(out * 1.5, 1.2, -2.5)], "look": {"a": who, "h": 1.15}, "fov": [42, 38], "hand": 0.4})
		return
	if absf(_spots[who].x) > 0.9: side = 1.0 if _spots[who].x > 0.0 else -1.0
	_shot(t, {"rel": {"mid": [who, alice_index]}, "span": [who, alice_index], "eye": [Vector3(side * 3.3, 1.45, 0.25), Vector3(side * 2.9, 1.25, 0.0)], "look": {"mid": [who, alice_index], "h": 1.15}, "fov": [46, 42], "hand": 0.45})


func _answer(who: int, t: float) -> float:
	var a: int = alice_index
	var person: String = people[who]
	if person in FRONT: _move(a, t - 0.2, t + 0.02, Vector3(_spots[who].x * 0.9, 0, _spots[who].z - 1.6), "dash")
	var view: float = 1.0 if _spots[who].x >= 0.0 else -1.0
	_shot(t - 0.15, {"rel": {"mid": [who, a]}, "span": [who, a], "eye": [Vector3(view * 3.2, 1.3, -0.5), Vector3(view * 2.8, 1.15, -0.7)], "look": {"mid": [who, a], "h": 1.2}, "fov": [44, 41], "hand": 0.5})
	match person:
		"Usayuko":

			_do(who, t - 0.3, "state", {"block": 1.2})
			_do(a, t, "trigger", "slash")
			_cue(t + 0.1, "event", "block", {"position": {"a": who}})
			_cue(t + 0.1, "sound", "block", {"a": who})
			_do(who, t + 0.1, "play", "block_hit")
			_do(a, t + 0.1, "hitstop", 0.14)
			_cue(t + 0.1, "shake", 0.3)
			_do(who, t + 0.42, "unset", ["block"])
			_do(who, t + 0.45, "trigger", "contre")
			_blow(t + 0.57, a, who, "counter", GOLD, 1.25)
			_stun(a, t + 0.57, 2.2)
			_knock(a, t + 0.57, 1.3)
			return t + 2.8
		"Lysia":

			_do(who, t - 0.35, "state", {"overheat_time": 1.3})
			_cue(t - 0.35, "event", "overheat", {"position": {"a": who}, "active": true})
			_do(a, t, "trigger", "slash")
			_cue(t + 0.1, "pop", {"a": who, "h": 1.2, "o": Vector3(0, 0, -0.5)}, Vector3(0, 0, -1), Color("ffb46b"), 0.9)
			_cue(t + 0.1, "word", "block", {"a": who, "h": 2.1}, Color("ffcf8a"), 0.9)
			_cue(t + 0.1, "sound", "block", {"a": who})
			_do(a, t + 0.1, "hit", 0.9, who)
			_cue(t + 0.1, "shake", 0.3)
			_do(who, t + 0.75, "unset", ["overheat_time"])
			_do(who, t + 0.8, "trigger", "consommation")
			_cue(t + 0.9, "word", "push", {"a": who, "h": 2.2}, Color("a6f0d8"), 1.0)
			_cue(t + 0.9, "shake", 0.4)
			_cue(t + 0.9, "impact", 0.6, false)
			_do(a, t + 0.9, "hit", 1.1, who)
			_knock(a, t + 0.9, 3.0)
			_stun(a, t + 1.4, 1.2)
			return t + 2.6
		"Simon":
			_do(a, t, "trigger", "slash")
			_do(who, t + 0.02, "trigger", "dodge", false)
			_move(who, t + 0.02, t + 0.36, _spots[who] + Vector3(-1.3, 0, 0.5), "out")
			_cue(t + 0.02, "event", "dodge", {"position": {"a": who}})
			return t + 0.4
		"Ashura":
			_do(a, t, "trigger", "slash")
			_do(who, t, "state", {"boost_time": 0.9})
			_do(who, t + 0.75, "unset", ["boost_time"])
			_move(who, t + 0.02, t + 0.6, _spots[who] + Vector3(1.5, 0, 1.3), "out")
			_cue(t + 0.14, "word", "miss", {"a": who, "h": 2.1}, PAPER, 0.85)
			return t + 0.4
		_:
			_alice_misses(t, who, Vector3(0.3 if person == "Elly" else -0.3, 0, 1.0))
			return t + 0.4


func _strike(who: int, t: float, busy: float) -> float:
	var a: int = alice_index
	match people[who]:
		"Bleuette":

			_do(who, t, "trigger", "boost" if people.size() > 1 else "je peux le faire !")
			for other: int in range(people.size()):
				if people.size() > 1 and other == who: continue
				_cue(t + 0.36, "event", "boost", {"position": {"a": other}})
				_do(other, t + 0.5, "state", {"speed_boost": 8.0})
			_do(who, t + 0.5, "state", {"speed_boost": 8.0})
			_cue(t + 0.36, "word", "go", {"a": who, "h": 2.1}, Color("ffb7cf"), 0.95)
			return busy
		"Elly":
			_do(who, t, "trigger", "zone de soin")
			_cue(t + 0.4, "event", "zone", {"position": {"a": who}, "radius": 4.0})
			for other: int in range(people.size()):
				if other != who: _do(other, t + 0.6 + 0.07 * float(other), "play", "healed")
			_cue(t + 0.45, "pulse", Color(0.45, 1.0, 0.75, 0.2), 0.7)
			return busy
		"Simon":

			_move(who, t - 0.3, t, Vector3(_spots[who].x, 0, -0.4))
			_do(who, t, "state", {"grenade_aiming": true})
			_do(who, t + 0.32, "unset", ["grenade_aiming"])
			_do(who, t + 0.32, "trigger", "flashbang")
			var land: float = t + 0.32 + 0.35 + 0.45
			_flights.append([t + 0.67, land, "grenade", {"a": who, "s": "hand_r"}, {"a": a, "h": 0.15, "o": Vector3(0.2, 0, 0.5)}, 1.3, 0.0])
			_cue(t + 0.67, "sound", "grenade_throw", {"a": who})
			_cue(land, "sound", "grenade_bounce", {"a": a})
			_cue(land + 0.1, "event", "grenade", {"action": "explode", "id": -7, "position": {"a": a, "h": 0.0, "o": Vector3(0.2, 0, 0.5)}})
			_cue(land + 0.1, "sound", "flash", {"a": a})
			_cue(land + 0.1, "shake", 0.45)
			_cue(land + 0.1, "impact", 0.6, false)
			_do(a, land + 0.1, "state", {"blind": 2.4})
			_do(a, land + 2.5, "unset", ["blind"])
			_cue(land + 0.12, "stars", {"a": a, "s": "over"}, 3)
			return maxf(busy, land + 2.5)
		"Ashura":

			_move(who, t - 0.3, t, Vector3(_spots[who].x, 0, -0.4))
			_do(who, t, "trigger", "drone")
			var hit: float = t + 0.75
			_flights.append([t + 0.14, hit, "drone", {"a": who, "s": "hand_r"}, {"a": a, "s": "head"}, 0.35, 0.6])
			_cue(hit, "event", "drone", {"action": "impact", "position": {"a": a, "s": "head"}})
			_cue(hit, "sound", "ground_impact", {"a": a}, 0.8)
			_cue(hit, "shake", 0.3)
			_do(a, hit, "hit", 0.9, who)
			if busy < hit:
				_do(a, hit, "state", {"blind": 1.5})
				_do(a, hit + 1.5, "unset", ["blind"])
			return maxf(busy, hit + 1.5)
		"Lysia":
			var reach: Vector3 = Vector3(_spots[a].x + 0.2, 0, _spots[a].z + 1.5)
			_move(who, t - 0.35, t - 0.02, reach, "dash")
			_do(who, t, "trigger", "consommation")
			_cue(t + 0.1, "word", "push", {"a": who, "h": 2.2}, Color("a6f0d8"), 1.0)
			_cue(t + 0.1, "shake", 0.4)
			_cue(t + 0.1, "impact", 0.6, false)
			_do(a, t + 0.1, "hit", 1.1, who)
			_knock(a, t + 0.1, 2.8)
			_stun(a, t + 0.6, 1.3)
			return maxf(busy, t + 1.9)
		"Usayuko":
			var reach: Vector3 = Vector3(_spots[a].x + 0.25, 0, _spots[a].z + 1.25)
			_move(who, t - 0.38, t - 0.02, reach, "dash")
			_do(who, t, "trigger", "punch")
			_blow(t + 0.11, a, who, "punch", GOLD, 1.2)
			_stun(a, t + 0.11, 2.0)
			_knock(a, t + 0.11, 1.2)
			return maxf(busy, t + 2.1)
	return busy





func _write_last_stand() -> void :
	var s: int = 0
	var a: int = alice_index
	var person: String = people[0]
	var run: float = 6.0
	_put(s, Vector3(0, 0, 0.9))
	_face(s, 0.0, "at", a)
	_do(s, 0.0, "state", {"lms": true, "chased": 3.0})
	_put(a, Vector3(0.3, 0, -7.5))
	_face(a, 0.0, "at", s)
	_move(a, 0.0, 1.25, Vector3(0.2, 0, -1.6), "smooth")

	_shot(0.0, {"rel": {"a": s}, "eye": [Vector3(-0.9, 1.35, 2.3), Vector3(-0.7, 1.25, 1.8)], "look": {"a": a, "h": 1.2}, "fov": [44, 39], "hand": 0.5})
	_shot(0.95, {"rel": {"mid": [s, a]}, "eye": [Vector3(3.4, 1.0, 0.4), Vector3(3.0, 1.1, 0.2)], "look": {"mid": [s, a], "h": 1.15}, "fov": [44, 41], "hand": 0.5})
	match person:
		"Usayuko":

			_do(s, 1.05, "state", {"block": 1.2})
			_move(a, 1.2, 1.37, Vector3(0.1, 0, -0.7), "dash")
			_do(a, 1.35, "trigger", "slash")
			_cue(1.45, "event", "block", {"position": {"a": s}})
			_cue(1.45, "sound", "block", {"a": s})
			_do(s, 1.45, "play", "block_hit")
			_do(a, 1.45, "hitstop", 0.14)
			_cue(1.45, "shake", 0.3)
			_do(s, 1.78, "unset", ["block"])
			_do(s, 1.8, "trigger", "contre")
			_blow(1.92, a, s, "counter", GOLD, 1.2)
			_stun(a, 1.92, 1.5)
			_knock(a, 1.92, 2.4)
			_shot(1.75, {"rel": {"a": a}, "eye": [Vector3(-1.6, 1.0, 2.6), Vector3(-1.3, 1.1, 2.9)], "look": {"a": a, "h": 1.25}, "fov": [40, 44], "hand": 0.6})
			_shot(2.75, {"rel": {"mid": [s, a]}, "eye": [Vector3(-4.2, 1.15, 0.2), Vector3(-3.6, 0.9, 0.0)], "look": {"mid": [s, a], "h": 1.1}, "fov": [46, 42], "hand": 0.6})
			_do(s, 3.3, "trigger", "dropkick")
			_move(s, 3.3, 3.62, Vector3(0.1, 0, -1.65), "dash")
			_blow(3.5, a, s, "punch", GOLD, 1.5)
			_cue(3.5, "frame", Color(1, 1, 1, 0.16), 0.08)
			_stun(a, 3.5, 2.6)
			_knock(a, 3.5, 4.2)
			_cue(3.9, "dust_ring", {"a": a}, 1.1)
			_shot(3.42, {"rel": {"a": a}, "eye": [Vector3(2.2, 0.55, -1.2), Vector3(2.6, 0.7, -2.6)], "look": {"a": a, "h": 1.0}, "fov": [50, 46], "hand": 0.8})
			_do(s, 4.45, "emote", "laugh")
			_shot(4.4, {"rel": {"a": s}, "eye": [Vector3(1.1, 0.9, -2.6), Vector3(0.9, 1.05, -2.2)], "look": {"a": s, "h": 1.25}, "fov": [40, 37], "hand": 0.3})
			run = 5.7
		"Simon":

			_move(a, 1.1, 1.3, Vector3(0.1, 0, -0.75), "dash")
			_do(a, 1.3, "trigger", "slash")
			_do(s, 1.32, "trigger", "dodge", false)
			_move(s, 1.32, 1.66, Vector3(-1.5, 0, 1.3), "out")
			_cue(1.32, "event", "dodge", {"position": {"a": s}})
			_do(s, 1.75, "state", {"grenade_aiming": true})
			_do(s, 2.1, "unset", ["grenade_aiming"])
			_do(s, 2.1, "trigger", "flashbang")
			_flights.append([2.45, 2.9, "grenade", {"a": s, "s": "hand_r"}, {"a": a, "h": 0.15, "o": Vector3(0.1, 0, 0.5)}, 1.1, 0.0])
			_cue(2.45, "sound", "grenade_throw", {"a": s})
			_cue(3.0, "event", "grenade", {"action": "explode", "id": -7, "position": {"a": a, "o": Vector3(0.1, 0, 0.5)}})
			_cue(3.0, "sound", "flash", {"a": a})
			_cue(3.0, "shake", 0.45)
			_cue(3.0, "impact", 0.6, false)
			_do(a, 3.0, "state", {"blind": 3.2})
			_do(a, 4.6, "unset", ["blind"])
			_shot(1.7, {"rel": {"a": s}, "eye": [Vector3(1.3, 1.15, -2.0), Vector3(1.0, 1.2, -1.7)], "look": {"a": s, "h": 1.25}, "fov": [40, 37], "hand": 0.4})
			_shot(2.5, {"rel": {"mid": [s, a]}, "eye": [Vector3(3.6, 1.6, 0.9), Vector3(3.3, 1.4, 0.6)], "look": {"a": a, "h": 1.1}, "fov": [46, 43], "hand": 0.5})
			_move(s, 3.25, 3.6, Vector3(-0.35, 0, 0.4), "dash")
			_do(s, 3.62, "trigger", "flash punch")
			_blow(3.73, a, s, "punch", Color("dccbff"), 1.3)
			_stun(a, 3.73, 2.3)
			_knock(a, 3.73, 2.2)
			_shot(3.55, {"rel": {"a": a}, "eye": [Vector3(1.9, 0.7, 1.8), Vector3(2.3, 0.8, 0.6)], "look": {"a": a, "h": 1.15}, "fov": [44, 48], "hand": 0.8})
			_do(s, 4.5, "state", {"boost_charging": true, "charging_boost": 0.0, "boost_level": 0})
			_ramp(s, 4.5, 5.6, "charging_boost", 0.0, 3.0)
			_do(s, 5.0, "state", {"boost_level": 1})
			_do(s, 5.4, "state", {"boost_level": 2})
			_cue(4.5, "event", "boost_charge", {"position": {"a": s}, "active": true})
			_face(s, 4.5, "dir", Vector3(0, 0, 1))
			_shot(4.45, {"rel": {"a": s}, "eye": [Vector3(-1.5, 0.6, 2.4), Vector3(-1.2, 0.8, 2.0)], "look": {"a": s, "h": 1.1}, "fov": [42, 38], "hand": 0.4})
			_do(s, 5.65, "unset", ["boost_charging", "charging_boost", "boost_level"])
			_do(s, 5.65, "state", {"speed_boost": 6.0})
			_cue(5.65, "event", "boost_release", {"position": {"a": s}, "level": 3})
			run = 5.65
		"Ashura":

			_move(a, 1.1, 1.3, Vector3(0.1, 0, -0.75), "dash")
			_do(a, 1.3, "trigger", "slash")
			_do(s, 1.25, "state", {"boost_time": 1.6})
			_move(s, 1.3, 2.3, Vector3(2.2, 0, 1.9), "out")
			_cue(1.44, "word", "miss", {"a": s, "h": 1.85}, PAPER, 0.85)
			_do(s, 2.5, "unset", ["boost_time"])
			_do(s, 2.5, "trigger", "drone")
			_flights.append([2.64, 3.3, "drone", {"a": s, "s": "hand_r"}, {"a": a, "s": "head"}, 0.4, 0.7])
			_face(a, 1.6, "at", s)
			_cue(3.3, "event", "drone", {"action": "impact", "position": {"a": a, "s": "head"}})
			_cue(3.3, "sound", "ground_impact", {"a": a}, 0.8)
			_cue(3.3, "shake", 0.35)
			_do(a, 3.3, "hit", 1.0, s)
			_do(a, 3.3, "state", {"blind": 3.0})
			_do(a, 5.6, "unset", ["blind"])
			_stun(a, 3.3, 0.8)
			_shot(1.95, {"rel": {"a": s}, "eye": [Vector3(-1.4, 1.2, -2.9), Vector3(-1.1, 1.25, -2.5)], "look": {"a": s, "h": 1.15}, "fov": [42, 39], "hand": 0.4})
			_shot(2.7, {"rel": {"mid": [s, a]}, "eye": [Vector3(-3.4, 1.7, 1.6), Vector3(-2.6, 1.5, 0.6)], "look": {"a": a, "h": 1.35}, "fov": [46, 40], "hand": 0.6})
			_do(s, 3.9, "state", {"boost_charging": true, "charging_boost": 0.0, "boost_level": 0})
			_ramp(s, 3.9, 5.3, "charging_boost", 0.0, 3.0)
			_do(s, 4.4, "state", {"boost_level": 1})
			_do(s, 4.9, "state", {"boost_level": 2})
			_cue(3.9, "event", "boost_charge", {"position": {"a": s}, "active": true})
			_face(s, 3.9, "dir", Vector3(-0.2, 0, 1))
			_shot(3.85, {"rel": {"a": s}, "eye": [Vector3(1.6, 0.5, 2.3), Vector3(1.2, 0.7, 1.9)], "look": {"a": s, "h": 1.0}, "fov": [42, 38], "hand": 0.4})
			_do(s, 5.35, "unset", ["boost_charging", "charging_boost", "boost_level"])
			_do(s, 5.35, "state", {"boost_time": 6.0})
			_cue(5.35, "event", "boost_release", {"position": {"a": s}, "level": 3})
			run = 5.35
		"Lysia":

			_move(a, 1.1, 1.3, Vector3(0.1, 0, -0.7), "dash")
			_do(a, 1.3, "trigger", "slash")
			_blow(1.4, s, a, "slash", CRIMSON, 1.0)
			_cue(1.4, "splash", 0.9)
			_do(s, 1.95, "state", {"overheat_charge": 0.5})
			_cue(1.95, "event", "overheat_charge", {"position": {"a": s}})
			_do(s, 2.45, "unset", ["overheat_charge"])
			_do(s, 2.45, "state", {"overheat_time": 1.6})
			_cue(2.45, "event", "overheat", {"position": {"a": s}, "active": true})
			_cue(2.45, "pulse", Color(1.0, 0.5, 0.15, 0.3), 0.8)
			_shot(1.85, {"rel": {"a": s}, "eye": [Vector3(1.2, 0.9, -2.2), Vector3(0.9, 1.1, -1.8)], "look": {"a": s, "h": 1.2}, "fov": [40, 36], "hand": 0.4})
			_do(a, 2.9, "trigger", "slash")
			_cue(3.0, "pop", {"a": s, "h": 1.2, "o": Vector3(0, 0, -0.5)}, Vector3(0, 0, -1), Color("ffb46b"), 1.0)
			_cue(3.0, "word", "block", {"a": s, "h": 2.1}, Color("ffcf8a"), 0.95)
			_cue(3.0, "sound", "block", {"a": s})
			_cue(3.0, "shake", 0.3)
			_do(a, 3.0, "hit", 0.9, s)
			_do(a, 3.0, "hitstop", 0.12)
			_shot(2.8, {"rel": {"mid": [s, a]}, "eye": [Vector3(-3.3, 1.2, 0.3), Vector3(-2.9, 1.1, 0.1)], "look": {"mid": [s, a], "h": 1.2}, "fov": [44, 40], "hand": 0.5})
			_do(s, 3.75, "unset", ["overheat_time"])
			_cue(3.75, "event", "overheat", {"position": {"a": s}, "active": false})
			_do(s, 3.8, "trigger", "consommation")
			_cue(3.9, "word", "push", {"a": s, "h": 2.2}, Color("a6f0d8"), 1.1)
			_cue(3.9, "shake", 0.45)
			_cue(3.9, "impact", 0.7, false)
			_do(a, 3.9, "hit", 1.2, s)
			_knock(a, 3.9, 4.0)
			_stun(a, 4.4, 2.2)
			_shot(3.7, {"rel": {"a": a}, "eye": [Vector3(2.4, 0.6, -1.0), Vector3(2.8, 0.7, -2.4)], "look": {"a": a, "h": 1.05}, "fov": [50, 46], "hand": 0.8})
			_do(s, 4.85, "trigger", "xray")
			_shot(4.75, {"rel": {"a": s}, "eye": [Vector3(-0.8, 1.25, -1.9), Vector3(-0.6, 1.3, -1.6)], "look": {"a": s, "h": 1.4}, "fov": [36, 33], "hand": 0.3})
			run = 6.1
		"Elly":

			_alice_misses(1.3, s, Vector3(0.3, 0, 1.2))
			_alice_misses(2.15, s, Vector3(-0.3, 0, 1.1))
			_do(s, 2.85, "trigger", "shotgun")
			_cue(2.87, "event", "tracer", {"from": {"a": s, "h": 1.3, "o": Vector3(0, 0, -0.7)}, "to": {"a": a, "h": 1.2}, "duration": 0.2})
			_blow(2.9, a, s, "gun", Color("ffe6a0"), 1.3)
			_cue(2.9, "frame", Color(1.0, 0.95, 0.8, 0.18), 0.08)
			_knock(a, 2.9, 2.6)
			_stun(a, 2.9, 1.0)
			_shot(2.7, {"rel": {"a": s}, "eye": [Vector3(0.9, 1.35, 1.9), Vector3(0.8, 1.4, 2.4)], "look": {"a": a, "h": 1.2}, "fov": [44, 48], "hand": 0.7})
			_move(s, 3.5, 4.1, _spots[s] + Vector3(0, 0, -1.0))
			_do(s, 4.3, "trigger", "shotgun")
			_cue(4.32, "event", "tracer", {"from": {"a": s, "h": 1.3, "o": Vector3(0, 0, -0.7)}, "to": {"a": a, "h": 1.2}, "duration": 0.2})
			_blow(4.35, a, s, "gun", Color("ffe6a0"), 1.4)
			_cue(4.35, "frame", Color(1.0, 0.95, 0.8, 0.18), 0.08)
			_knock(a, 4.35, 2.8)
			_stun(a, 4.35, 2.6)
			_shot(4.15, {"rel": {"mid": [s, a]}, "span": [s, a], "eye": [Vector3(-3.0, 0.9, 0.3), Vector3(-3.2, 1.0, 0.0)], "look": {"mid": [s, a], "h": 1.1}, "fov": [48, 45], "hand": 0.7})
			_do(s, 5.1, "emote", "thumbsup")
			_shot(5.0, {"rel": {"a": s}, "eye": [Vector3(0.8, 1.2, -2.0), Vector3(0.6, 1.3, -1.7)], "look": {"a": s, "h": 1.45}, "fov": [36, 33], "hand": 0.3})
			run = 6.4
		_:

			_do(s, 0.5, "emote", "fear")
			_move(a, 1.25, 3.4, Vector3(0.2, 0, -0.9))
			_do(s, 2.0, "emote", "")
			_do(s, 2.0, "state", {"chocolate_eating": 1.4})
			_ramp(s, 2.0, 3.4, "chocolate_eating", 1.4, 0.0)
			_cue(2.0, "event", "chocolate", {"position": {"a": s}})
			_shot(1.9, {"rel": {"a": s}, "eye": [Vector3(0.7, 1.05, -1.7), Vector3(0.5, 1.15, -1.4)], "look": {"a": s, "h": 1.25}, "fov": [36, 32], "hand": 0.3})
			_do(s, 3.45, "trigger", "je peux le faire !")
			_do(s, 3.45, "mood", "determined")
			_cue(3.9, "pulse", Color(0.55, 0.75, 1.0, 0.3), 0.8)
			_cue(3.9, "shake", 0.25)
			_shot(3.4, {"rel": {"a": s}, "eye": [Vector3(-1.0, 0.6, -2.3), Vector3(-0.8, 0.9, -2.0)], "look": {"a": s, "h": 1.2}, "fov": [44, 40], "hand": 0.5})
			_do(s, 4.6, "state", {"speed_boost": 8.0})
			_move(a, 4.7, 4.9, Vector3(0.1, 0, -0.55), "dash")
			_do(a, 4.9, "trigger", "slash")
			_do(s, 4.9, "play", "startle")
			_move(s, 4.92, 5.25, Vector3(-1.3, 0, 1.9), "out")
			_cue(5.04, "word", "miss", {"a": s, "h": 2.0}, PAPER, 0.9)
			_do(a, 5.5, "trigger", "slash")
			_cue(5.64, "word", "miss", {"a": a, "h": 2.2, "o": Vector3(0, 0, 1.0)}, PAPER, 0.85)
			_shot(4.6, {"rel": {"mid": [s, a]}, "eye": [Vector3(3.3, 1.0, 0.6), Vector3(3.0, 1.1, 1.2)], "look": {"mid": [s, a], "h": 1.1}, "fov": [44, 47], "hand": 0.7})
			run = 5.3

	var arrive: float = run + 2.2
	_do(s, run, "emote", "")
	_face(s, run, "move")
	_move(s, run + 0.05, arrive, Vector3(0, 0, _length + BEYOND), "run")
	_cue(run + 0.1, "rush", 0.9)
	_cue(run + 0.05, "sound", "boost", {"a": s}, 0.7)
	_do(s, arrive - 0.1, "unset", ["chased", "speed_boost", "boost_time"])
	_face(s, arrive - 0.25, "dir", Vector3(0.15, 0, -1))
	_do(s, arrive + 0.55, "emote", str(VICTORY.get(person, "cheer")))
	_do(s, arrive + 0.55, "mood", "grin")
	_cue(arrive + 0.6, "event", "escaped", {"position": {"a": s}})
	_cue(arrive + 0.6, "sound", "encourage", {"a": s})
	_cue(arrive + 0.6, "pulse", Color(1.0, 0.92, 0.6, 0.32), 1.2)

	var free: float = maxf(run + 1.0, 6.9)
	_do(a, free, "stun", false)
	_do(a, free, "unset", ["blind"])
	_face(a, free, "dir", Vector3(0, 0, 1))
	_move(a, free + 0.1, free + 0.8, _spots[a] + Vector3(0, 0, 1.3))
	_do(a, free + 0.9, "trigger", "fury")
	_cue(free + 1.54, "shake", 0.5)
	_cue(free + 1.8, "word", "roar", {"a": a, "h": 2.5}, CRIMSON, 1.3)
	_cue(free + 1.8, "impact", 0.7, true)
	_cue(free + 1.8, "sound", "shadow", {"a": a}, 0.8, 0.8)
	_shot(run, {"rel": {"a": s}, "eye": [Vector3(0.7, 0.55, 3.4), Vector3(0.4, 0.65, 2.9)], "look": {"a": s, "h": 1.05}, "fov": [54, 58], "hand": 0.8})
	_shot(run + 1.0, {"rel": {"a": s}, "eye": [Vector3(-3.6, 1.2, 1.0), Vector3(-3.1, 1.05, 2.4)], "look": {"a": s, "h": 1.1}, "fov": 46, "hand": 0.7})
	_shot(free + 1.1, {"rel": {"a": a}, "eye": [Vector3(1.5, 0.6, 2.9), Vector3(1.1, 0.75, 2.3)], "look": {"a": a, "h": 1.25}, "fov": [38, 34], "hand": 0.4})
	_shot(maxf(arrive + 0.45, free + 2.5), {"rel": {"a": s}, "eye": [Vector3(1.1, 1.15, -3.0), Vector3(0.8, 1.3, -2.3)], "look": {"a": s, "h": 1.2}, "fov": [44, 38], "hand": 0.3})





func _write_kill() -> void :
	var s: int = 0
	var a: int = alice_index
	var person: String = people[0]

	_put(s, Vector3(0, 0, -0.4))
	_face(s, 0.0, "at", a)
	_do(s, 0.0, "state", {"chased": 3.0, "second_life": true})
	_do(s, 0.0, "mood", "fear")
	_move(s, 0.0, 1.5, Vector3(0, 0, 0.7))
	_put(a, Vector3(0.2, 0, -5.6))
	_face(a, 0.0, "at", s)
	_move(a, 0.0, 1.7, Vector3(0.1, 0, -2.2))
	_shot(0.0, {"rel": {"mid": [s, a]}, "eye": [Vector3(4.3, 1.9, 1.4), Vector3(3.6, 1.6, 1.0)], "look": {"mid": [s, a], "h": 1.2}, "fov": [46, 42], "hand": 0.4})

	var attempt: float = 1.55
	match person:
		"Usayuko":
			_move(s, 1.3, 1.6, Vector3(0, 0, -0.75), "dash")
			_do(s, 1.62, "trigger", "punch")
		"Simon":
			_do(s, 1.2, "state", {"grenade_aiming": true})
			_do(s, 1.5, "unset", ["grenade_aiming"])
			_do(s, 1.5, "trigger", "flashbang")
			_flights.append([1.85, 2.35, "grenade", {"a": s, "s": "hand_r"}, Vector3(0.2, 0.15, -2.0), 1.1, 0.0])
			_cue(2.45, "event", "grenade", {"action": "explode", "id": -7, "position": Vector3(0.2, 0, -2.0)})
			_cue(2.45, "sound", "flash", Vector3(0.2, 0, -2.0))
		"Ashura":
			_do(s, 1.4, "trigger", "drone")
			_flights.append([1.54, 2.1, "drone", {"a": s, "s": "hand_r"}, Vector3(0.1, 1.5, -2.2), 0.3, 0.7])
		"Lysia":
			_move(s, 1.3, 1.6, Vector3(0, 0, -0.75), "dash")
			_do(s, 1.62, "trigger", "consommation")
		"Elly":
			_do(s, 1.6, "trigger", "shotgun")
			_cue(1.62, "event", "tracer", {"from": {"a": s, "h": 1.3, "o": Vector3(0, 0, -0.7)}, "to": Vector3(0.1, 1.2, -9.0), "duration": 0.2})
		_:
			_do(s, 1.2, "emote", "fear")
	_shot(1.25, {"rel": {"a": s}, "eye": [Vector3(1.3, 1.1, -2.2), Vector3(1.0, 1.2, -1.8)], "look": {"a": s, "h": 1.2}, "fov": [42, 38], "hand": 0.5})

	_do(a, attempt, "trigger", "ombres / bond")
	_do(a, attempt, "state", {"shadow_hide": true})
	_do(a, attempt + 0.4, "show", false)
	_cue(attempt + 0.2, "word", "miss", {"a": s, "h": 2.1, "o": Vector3(0, 0, -0.8)}, PAPER, 0.9)
	_cue(attempt + 0.05, "sound", "shadow", {"a": a})
	_shot(attempt + 0.1, {"rel": {"mid": [s, a]}, "eye": [Vector3(-3.2, 1.3, 0.6), Vector3(-2.8, 1.2, 0.4)], "look": {"mid": [s, a], "h": 1.0}, "fov": [44, 41], "hand": 0.5})

	_face(s, attempt + 0.3, "dir", Vector3(0, 0, -1))
	_face(s, attempt + 0.8, "dir", Vector3(-0.6, 0, -1))
	_face(s, attempt + 1.12, "dir", Vector3(0.5, 0, -1))

	var rise: float = 2.95
	_move(a, attempt + 0.45, attempt + 0.5, Vector3(-0.4, 0, _spots[s].z + 1.7), "jump")
	_cue(rise - 0.5, "mark", 16, {"a": a, "h": 0.03}, Color("1c0f24", 0.85), [0.6, 2.2, 1.0, {"normal": Vector3.UP, "fade": 0.8}])
	_do(a, rise, "show", true)
	_do(a, rise, "unset", ["shadow_hide"])
	_face(a, rise - 0.1, "at", s)
	_cue(rise, "sound", "shadow", {"a": a}, 1.0, 0.85)
	_do(s, rise + 0.25, "emote", "")
	_do(s, rise + 0.25, "play", "startle")
	_face(s, rise + 0.3, "at", a)
	_shot(rise - 0.15, {"rel": {"a": s}, "eye": [Vector3(-1.5, 1.3, -2.5), Vector3(-1.3, 1.35, -2.15)], "look": [{"a": s, "h": 1.3}, {"mid": [s, a], "h": 1.4}], "fov": [40, 36], "hand": 0.5})

	var strike: float = 3.75
	_do(a, strike, "trigger", "slash")
	_blow(strike + 0.1, s, a, "slash", CRIMSON, 1.4)
	_cue(strike + 0.1, "splash", 1.4)
	_cue(strike + 0.1, "frame", Color(0.6, 0.0, 0.1, 0.2), 0.09)
	_do(s, strike + 0.1, "unset", ["chased"])
	_do(s, strike + 0.12, "life", "downed")
	_cue(strike + 0.12, "event", "downed", {"position": {"a": s}})
	_shot(strike - 0.1, {"rel": {"mid": [s, a]}, "eye": [Vector3(3.1, 0.7, 0.9), Vector3(2.7, 0.6, 0.6)], "look": {"mid": [s, a], "h": 1.0}, "fov": [44, 40], "hand": 0.7})

	_face(s, strike + 0.9, "dir", Vector3(0.1, 0, -1))
	_move(s, strike + 1.0, strike + 3.3, _spots[s] + Vector3(0.2, 0, -1.5), "linear")
	_move(a, strike + 1.5, strike + 3.1, _spots[s] + Vector3(-0.2, 0, 0.3), "linear")
	_face(a, strike + 1.0, "at", s)
	_shot(strike + 0.95, {"rel": {"a": s}, "eye": [Vector3(0.9, 0.3, -2.3), Vector3(0.6, 0.35, -1.9)], "look": [{"a": s, "h": 0.4}, {"a": a, "h": 1.2}], "fov": [44, 40], "hand": 0.5})

	var finish_time: float = strike + 3.35
	_do(a, finish_time, "trigger", "execution_spike", false)
	_cue(finish_time + 0.3, "spikes", {"a": s, "o": Vector3(0, 0, 0.9)}, {"a": s, "o": Vector3(0, 0, -0.9)})
	_cue(finish_time + 0.3, "sound", "spike", {"a": s})
	_cue(finish_time + 0.32, "event", "death_start", {"position": {"a": s}, "death_kind": "spike", "attack": "spike", "execution": true})
	_cue(finish_time + 0.32, "shake", 0.6)
	_cue(finish_time + 0.32, "impact", 0.9, true)
	_cue(finish_time + 0.32, "word", "spike", {"a": s, "h": 1.15, "o": Vector3(0.5, 0, 0.3)}, Color("e58ad0"), 1.05)
	_do(s, finish_time + 0.32, "trigger", "death_spike", false)
	_do(s, finish_time + 1.7, "life", "dead")
	_blackouts.append([finish_time + 0.3, finish_time + 0.36])
	_shot(finish_time - 0.25, {"rel": {"a": s}, "eye": [Vector3(-2.3, 0.45, -1.7), Vector3(-2.0, 0.5, -1.4)], "look": {"a": a, "h": 1.1}, "fov": [46, 42], "hand": 0.6})

	var gloat: float = finish_time + 1.75
	_do(a, gloat, "trigger", "gloat", false)
	_do(a, gloat, "mood", "menace")
	_cue(gloat + 0.9, "event", "reveal", {"position": {"a": a}})
	_cue(gloat + 0.9, "pulse", Color(0.7, 0.05, 0.2, 0.35), 1.4)
	_shot(gloat - 0.05, {"rel": {"a": a}, "eye": [Vector3(1.4, 0.55, -2.6), Vector3(0.9, 0.9, -1.7)], "look": {"a": a, "h": 1.45}, "fov": [42, 33], "hand": 0.3, "roll": [0, -4]})





func _write_intro_survivors() -> void :
	var count: int = people.size()
	var bits: Dictionary = {"Simon": ["wave", 2.7], "Bleuette": ["cheer", 3.0], "Usayuko": ["laugh", 3.5], "Ashura": ["thumbsup", 3.2], "Lysia": ["shrug", 3.9], "Elly": ["point", 2.9]}
	var lead: int = mini(1, count - 1)
	for i: int in range(count):
		var row: int = i / 3
		var in_row: int = mini(3, count - row * 3)
		var col: float = float(i % 3) - float(in_row - 1) * 0.5
		var start: Vector3 = Vector3(col * 1.25, 0, _length + 1.6 + float(row) * 1.5)
		var stand: Vector3 = Vector3(col * 1.55 + (0.5 if row > 0 else 0.0), 0, _length - 5.6 + float(row) * 1.45)
		if world.school.map_id != "school":
			start = Vector3(col * 1.25, 0, 6.4 + float(row) * 1.5)
			stand = Vector3(col * 1.55 + (0.5 if row > 0 else 0.0), 0, 0.2 + float(row) * 1.45)
		_put(i, start)
		_face(i, 0.0, "dir", Vector3(0, 0, -1))
		_move(i, 0.06 * float(i), 2.25 + 0.06 * float(i), stand, "smooth")
		_do(i, 0.0, "mood", "smile" if i % 2 == 0 else "calm")

		_face(i, 2.45, "dir", Vector3( - col * 0.9 + (0.3 if row == 0 else -0.2), 0, -1.0 if row == 0 else -0.5))
		var bit: Array = bits.get(people[i], ["wave", 3.0])
		_do(i, float(bit[1]), "emote", str(bit[0]))

		var creak: float = 5.45 + 0.05 * float(i)
		_do(i, creak, "emote", "")
		_do(i, creak, "play", "startle")
		_do(i, creak, "mood", "fear")
		_do(i, creak + 0.1, "state", {"chased": 3.0})
		_face(i, creak, "dir", Vector3(0.12 * sin(float(i) * 1.7), 0, -1))
		_move(i, creak + 0.1, creak + 0.7, stand + Vector3(0, 0, 0.45), "out")
		_cue(creak + 0.08, "sweat", {"a": i, "s": "head"}, 2)
	_cue(5.4, "sound", "door_creak", {"group": true, "o": Vector3(0, 1.0, -6.0)})
	_cue(5.45, "impact", 0.5, true)
	_cue(5.5, "pulse", Color(0.55, 0.02, 0.1, 0.3), 1.6)
	_cue(5.45, "mark", 14, {"a": lead, "s": "over", "o": Vector3(0, 0.2, 0)}, Color("ff5a4a", 0.98), [0.3, 0.6, 1.0, {"pop": 0.8, "fade": 0.75}])

	_shot(0.0, {"rel": {"group": true}, "eye": [Vector3(2.6, 2.3, -6.6), Vector3(1.2, 1.5, -5.0)], "look": {"group": true, "h": 1.25}, "fov": [50, 44], "hand": 0.3})
	_shot(2.55, {"rel": {"group": true}, "eye": [Vector3(-3.0, 1.35, -3.2), Vector3(-0.6, 1.35, -3.6)], "look": [{"group": true, "h": 1.25, "o": Vector3(-1.2, 0, 0)}, {"group": true, "h": 1.25, "o": Vector3(1.0, 0, 0)}], "fov": 40, "hand": 0.3})
	_shot(4.1, {"rel": {"group": true}, "eye": [Vector3(2.4, 1.2, -3.0), Vector3(2.9, 1.25, -2.4)], "look": {"group": true, "h": 1.2}, "fov": [42, 40], "hand": 0.3})
	_shot(5.42, {"rel": {"group": true}, "eye": [Vector3(0.5, 1.75, 3.4), Vector3(0.4, 1.7, 3.0)], "look": {"group": true, "h": 1.3, "o": Vector3(0, 0, -7.0)}, "fov": [46, 40], "hand": 0.7})
	_shot(6.2, {"rel": {"a": lead}, "eye": [Vector3(0.9, 1.15, -2.3), Vector3(0.6, 1.2, -1.7)], "look": {"a": lead, "h": 1.3}, "fov": [38, 32], "hand": 0.5})





func _write_intro_alice() -> void :
	var a: int = alice_index
	_put(a, Vector3(0, 0, -1.9))
	_face(a, 0.0, "dir", Vector3(0, 0, 1))
	_do(a, 0.0, "mood", "menace")
	_door.append([0.3, 1.5])
	_cue(0.3, "sound", "door_creak", Vector3(0, 1.5, 0))
	_cue(1.0, "sound", "door_open", Vector3(0, 1.5, 0))
	_move(a, 1.0, 2.9, Vector3(0, 0, 1.5), "smooth")

	_do(a, 3.0, "trigger", "shadow reveal")
	_cue(3.35, "event", "reveal", {"position": {"a": a}})
	_cue(3.35, "pulse", Color(0.7, 0.05, 0.2, 0.34), 1.2)
	_cue(3.35, "shake", 0.3)

	_move(a, 4.3, 4.85, Vector3(0.1, 0, 3.6), "in")
	_do(a, 4.8, "trigger", "slash")
	_cue(4.9, "impact", 1.0, true)
	_cue(4.9, "shake", 0.7)
	_cue(4.92, "splash", 1.0)
	_blackouts.append([5.0, 5.6])
	_shot(0.0, {"eye": [Vector3(1.9, 0.5, 5.4), Vector3(1.5, 0.6, 4.8)], "look": Vector3(0, 1.6, 0), "fov": [46, 42], "hand": 0.4, "safe": false})
	_shot(1.55, {"rel": {"a": a}, "eye": [Vector3(2.5, 1.2, 0.8), Vector3(2.2, 1.3, 1.6)], "look": {"a": a, "h": 1.3}, "fov": [42, 38], "hand": 0.4, "safe": false})
	_shot(2.95, {"rel": {"a": a}, "eye": [Vector3(-1.2, 0.5, 3.0), Vector3(-0.7, 0.8, 2.4)], "look": {"a": a, "h": 1.35}, "fov": [42, 36], "hand": 0.4, "roll": [0, 5], "safe": false})
	_shot(4.3, {"eye": [Vector3(0.2, 1.35, 5.2), Vector3(0.15, 1.35, 5.0)], "look": {"a": a, "h": 1.4}, "fov": [40, 46], "hand": 0.8, "safe": false})
