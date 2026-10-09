extends Control








const Dances = preload("res://dances.gd")

var ui: Node
var _container: SubViewportContainer
var _viewport: SubViewport
var _stage: Node3D
var _camera: Camera3D
var _key: DirectionalLight3D
var _accent: OmniLight3D
var _flash: OmniLight3D
var _scenes: Dictionary = {}
var _current: String = ""
var _wanted: String = ""
var _wanted_since: float = 0.0
var _time: float = 0.0
var _alpha: float = 0.0
var _clock: float = 0.0
var _music: AudioStreamPlayer
var _preview_person: String = "Bleuette"
var _preview_dance: String = ""
var _lineup_hidden: bool = false

const CAMERAS: Dictionary = {
	"play": [Vector3(0.6, 1.45, -4.6), Vector3(0.1, 0.95, 0.0)], 
	"training": [Vector3(0.2, 1.5, -4.8), Vector3(0.2, 0.9, 0.0)], 
	"friends": [Vector3(-0.6, 1.6, -4.9), Vector3(0.35, 0.85, 0.3)], 
	"gallery": [Vector3(0.0, 1.5, -4.7), Vector3(0.0, 0.9, 0.0)], 
	"settings": [Vector3(0.3, 1.55, -4.4), Vector3(0.1, 0.65, 0.2)], 
	"credits": [Vector3(0.0, 1.6, -5.6), Vector3(0.0, 0.95, 0.0)], 
	"quit": [Vector3(0.0, 1.5, -5.0), Vector3(0.0, 1.2, 0.0)], 
	"shop": [Vector3(0.0, 1.45, -4.6), Vector3(0.0, 0.95, 0.0)], 
	"dance": [Vector3(0.0, 1.45, -4.6), Vector3(0.0, 0.95, 0.0)], 
}
const ACCENTS: Dictionary = {"play": Color("ff7a59"), "training": Color("ffb347"), "friends": Color("6fa8ff"), "gallery": Color("b08cff"), "settings": Color("7fe0ff"), "credits": Color("ffd27f"), "quit": Color("ff2a3c"), "shop": Color("ff6fd0"), "dance": Color("ff6fd0")}

func setup(owner_ui: Node) -> void :
	ui = owner_ui
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container = SubViewportContainer.new()
	_container.stretch = true
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)
	_container.anchor_left = 0.36
	_container.anchor_right = 1.0
	_container.anchor_top = 0.04
	_container.anchor_bottom = 1.0
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_container.add_child(_viewport)
	_stage = Node3D.new()
	_viewport.add_child(_stage)
	_camera = Camera3D.new()
	_camera.fov = 34.0
	_stage.add_child(_camera)
	_camera.current = true
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("3a3550")
	e.ambient_light_energy = 0.9
	env.environment = e
	_stage.add_child(env)
	_key = DirectionalLight3D.new()
	_key.rotation = Vector3(-0.75, 2.6, 0.0)
	_key.light_energy = 1.1
	_key.light_color = Color("ffe6cf")
	_key.shadow_enabled = true
	_stage.add_child(_key)
	_accent = OmniLight3D.new()
	_accent.position = Vector3(1.8, 2.2, 1.2)
	_accent.omni_range = 7.0
	_accent.light_energy = 1.6
	_stage.add_child(_accent)
	_flash = OmniLight3D.new()
	_flash.omni_range = 4.0
	_flash.light_energy = 0.0
	_flash.light_color = Color("bfe9ff")
	_stage.add_child(_flash)

	var pool: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(7.0, 7.0)
	pool.mesh = plane
	var gradient: GradientTexture2D = GradientTexture2D.new()
	gradient.fill = GradientTexture2D.FILL_RADIAL
	gradient.fill_from = Vector2(0.5, 0.5)
	gradient.fill_to = Vector2(1.0, 0.5)
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(0.09, 0.08, 0.13, 0.95))
	g.set_color(1, Color(0.05, 0.05, 0.08, 0.0))
	gradient.gradient = g
	var pool_mat: StandardMaterial3D = StandardMaterial3D.new()
	pool_mat.albedo_texture = gradient
	pool_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pool_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pool.material_override = pool_mat
	pool.position.y = 0.01
	_stage.add_child(pool)
	_music = AudioStreamPlayer.new()
	_music.bus = &"PaperMix"
	add_child(_music)
	modulate.a = 0.0
	hide()


func hover(action: String) -> void :
	if action == _wanted: return
	_wanted = action
	_wanted_since = _clock


func preview_dance(person: String, dance_id: String) -> void :
	_preview_person = person
	_preview_dance = dance_id
	if _scenes.has("dance"):
		(_scenes["dance"].root as Node).queue_free()
		_scenes.erase("dance")
	_current = ""
	_wanted = "dance" if not dance_id.is_empty() else ""
	_wanted_since = _clock - 1.0

func _active_page() -> bool:
	if ui == null or not ui.page.visible or not (ui.world.phase in ["menu", "lobby"]): return false
	return ui.current_page == "main" or ui.current_page == "shop"

func _process(delta: float) -> void :
	_clock += delta
	var page_ok: bool = _active_page()
	if not page_ok and _wanted != "" and ui and ui.current_page != "shop": _wanted = ""

	var target: String = _wanted if page_ok and (_wanted != "" or _clock - _wanted_since > 0.35) else ""
	if not page_ok: target = ""
	if target != _current and target != "":
		_switch(target)
	var show: bool = target != "" and _current == target
	_alpha = move_toward(_alpha, 1.0 if show else 0.0, delta * (4.0 if show else 5.0))
	modulate.a = _alpha
	visible = _alpha > 0.001
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
	_set_lineup(show)
	if not show and _music.playing and _alpha <= 0.01: _music.stop()
	if not visible or _current == "": return
	_time += delta
	_tick(_current, _time, delta)

func _set_lineup(hidden: bool) -> void :
	var backdrop: Node = ui.menu_backdrop if ui else null
	if not is_instance_valid(backdrop): return
	if hidden:
		backdrop.set("_lineup_alpha_goal", 0.08)
		_lineup_hidden = true
	elif _lineup_hidden:
		backdrop.set("_lineup_alpha_goal", 1.0)
		_lineup_hidden = false

func _switch(id: String) -> void :
	if _current != "" and _scenes.has(_current): (_scenes[_current].root as Node3D).hide()
	_current = id
	_time = 0.0
	if not _scenes.has(id): _scenes[id] = _build(id)
	var scene: Dictionary = _scenes[id]
	(scene.root as Node3D).show()
	var cam: Array = CAMERAS.get(id, CAMERAS["play"])
	_camera.position = cam[0]
	_camera.look_at(cam[1], Vector3.UP)
	_accent.light_color = ACCENTS.get(id, Color.WHITE)
	_flash.light_energy = 0.0
	if id == "dance" and not _preview_dance.is_empty():
		_music.stream = Dances.music(_preview_dance)
		if _music.stream: _music.play(0.0)
	elif _music.playing: _music.stop()



func _actor(root: Node3D, person: String, at: Vector3, facing: Vector3 = Vector3(0, 0, -1)) -> PaperVisual:
	var visual: PaperVisual = PaperVisual.new()
	visual.lod_enabled = false
	root.add_child(visual)
	visual.setup(person)
	visual.position = at
	visual.rotation.y = atan2( - facing.x, - facing.z)
	return visual

func _box(root: Node3D, size: Vector3, at: Vector3, color: Color, glow: float = 0.0) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	mesh.material_override = mat
	mesh.position = at
	root.add_child(mesh)
	return mesh

func _sparks(root: Node3D, at: Vector3) -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = 46
	p.lifetime = 0.55
	p.explosiveness = 0.92
	p.direction = Vector3(0, 1, 0)
	p.spread = 80.0
	p.initial_velocity_min = 1.8
	p.initial_velocity_max = 4.2
	p.gravity = Vector3(0, -7.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.018
	mesh.height = 0.036
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.95, 0.6)
	mesh.material = mat
	p.mesh = mesh
	p.position = at
	root.add_child(p)
	return p

func _build(id: String) -> Dictionary:
	var root: Node3D = Node3D.new()
	_stage.add_child(root)
	var s: Dictionary = {"root": root, "actors": {}, "props": {}, "step": -1}
	match id:
		"play":
			s.actors["simon"] = _actor(root, "Simon", Vector3(0.0, 0, 0.0))
		"training":
			s.actors["usa"] = _actor(root, "Usayuko", Vector3(-0.55, 0, 0.0), Vector3(1.0, 0.0, -0.35))
			var dummy: Node3D = Node3D.new()
			dummy.position = Vector3(0.75, 0, 0.35)
			root.add_child(dummy)
			_box(dummy, Vector3(0.6, 0.1, 0.6), Vector3(0, 0.05, 0), Color("4a3b2f"))
			var body: Node3D = Node3D.new()
			dummy.add_child(body)
			_box(body, Vector3(0.12, 0.9, 0.12), Vector3(0, 0.5, 0), Color("6b5843"))
			_box(body, Vector3(0.5, 0.75, 0.38), Vector3(0, 1.25, 0), Color("b49a6a"))
			_box(body, Vector3(0.34, 0.34, 0.34), Vector3(0, 1.82, 0), Color("c2a878"))
			s.props["dummy"] = body
			s["wobble"] = 0.0
			s["wobble_v"] = 0.0
		"friends":
			s.actors["simon"] = _actor(root, "Simon", Vector3(-0.55, 0, 0.0), Vector3(1.0, 0.0, -0.75))
			s.actors["usa"] = _actor(root, "Usayuko", Vector3(0.25, 0, 0.45), Vector3(1.0, 0.0, -0.6))
			var tv: Node3D = Node3D.new()
			tv.position = Vector3(1.85, 0, 0.9)
			tv.rotation.y = -1.9
			root.add_child(tv)
			_box(tv, Vector3(1.5, 0.5, 0.45), Vector3(0, 0.25, 0), Color("2b2733"))
			_box(tv, Vector3(1.35, 0.82, 0.08), Vector3(0, 0.98, 0), Color("15141a"))
			s.props["screen"] = _box(tv, Vector3(1.22, 0.7, 0.02), Vector3(0, 0.98, -0.05), Color("4aa3ff"), 2.4)
			_box(tv, Vector3(0.36, 0.08, 0.26), Vector3(-0.4, 0.54, 0), Color("dddde6"))
			var glow: OmniLight3D = OmniLight3D.new()
			glow.position = Vector3(0, 1.0, -0.6)
			glow.omni_range = 3.5
			glow.light_energy = 1.2
			tv.add_child(glow)
			s.props["glow"] = glow
		"gallery":
			s.actors["bleu"] = _actor(root, "Bleuette", Vector3(-0.45, 0, 0.0), Vector3(0.15, 0.0, -1.0))
			s.actors["elly"] = _actor(root, "Elly", Vector3(0.55, 0, 0.15), Vector3(-0.15, 0.0, -1.0))
			var beam: SpotLight3D = SpotLight3D.new()
			beam.position = Vector3(0.0, 2.2, -3.0)
			beam.look_at_from_position(beam.position, Vector3(0, 1.0, 0.0), Vector3.UP)
			beam.spot_range = 7.0
			beam.spot_angle = 30.0
			beam.light_energy = 2.0
			beam.light_color = Color("a9c4ff")
			root.add_child(beam)
			s.props["beam"] = beam
		"settings":
			var lysia: PaperVisual = _actor(root, "Lysia", Vector3(0.55, 0, 0.45), Vector3(-0.55, 0.0, -1.0))
			lysia.set_combat_state({"outlet_healing": 99.0})
			s.actors["lysia"] = lysia
			s.actors["ash"] = _actor(root, "Ashura", Vector3(-0.35, 0, 0.1), Vector3(1.0, 0.0, 0.2))
			_box(root, Vector3(0.45, 0.24, 0.26), Vector3(-0.75, 0.12, 0.65), Color("b3312f"))
			_box(root, Vector3(0.47, 0.04, 0.28), Vector3(-0.75, 0.26, 0.65), Color("7a1f1e"))
			s.props["sparks"] = _sparks(root, Vector3(0.3, 0.9, 0.35))
			_flash.position = Vector3(0.3, 1.1, 0.2)
		"credits":
			s.actors["lysia"] = _actor(root, "Lysia", Vector3(-0.85, 0, 0.2), Vector3(0.2, 0.0, -1.0))
			s.actors["bleu"] = _actor(root, "Bleuette", Vector3(0.0, 0, 0.0))
			s.actors["elly"] = _actor(root, "Elly", Vector3(0.85, 0, 0.2), Vector3(-0.2, 0.0, -1.0))
		"quit":
			s.actors["alice"] = _actor(root, "Alice", Vector3(0.0, 0, 1.4))
		"shop":
			s.actors["bleu"] = _actor(root, "Bleuette", Vector3(0.0, 0, 0.0))
			s["dance"] = "dance_hedgehog"
		"dance":
			s.actors["dancer"] = _actor(root, _preview_person, Vector3(0.0, 0, 0.0))
			s["dance"] = _preview_dance
	return s



func _emote(v: PaperVisual, id: String, t: float) -> void :
	v.set_combat_state({"emote_id": id, "emote_time": t})

func _tick(id: String, t: float, dt: float) -> void :
	var s: Dictionary = _scenes[id]
	var a: Dictionary = s.actors
	_flash.light_energy = move_toward(_flash.light_energy, 0.0, dt * 9.0)
	match id:
		"play":
			var v: PaperVisual = a.simon
			var step: int = int(t / 4.2)
			if step != int(s.step):
				s.step = step
				v.play("warmup")
		"training":
			var v2: PaperVisual = a.usa
			var step2: int = int(t / 1.25)
			if step2 != int(s.step):
				s.step = step2
				v2.play("punch")
				s["hit_at"] = t + 0.12
			if t >= float(s.get("hit_at", INF)):
				s["hit_at"] = INF
				s.wobble_v = float(s.wobble_v) + 3.2
			s.wobble_v = float(s.wobble_v) - (float(s.wobble) * 60.0 + float(s.wobble_v) * 4.0) * dt
			s.wobble = float(s.wobble) + float(s.wobble_v) * dt
			(s.props.dummy as Node3D).rotation.z = - float(s.wobble) * 0.35
		"friends":
			var cycle: float = fmod(t, 9.0)
			var screen: MeshInstance3D = s.props.screen
			var hue: float = fmod(t * 0.37, 1.0)
			var c: Color = Color.from_hsv(hue, 0.55, 1.0)
			(screen.material_override as StandardMaterial3D).emission = c
			(s.props.glow as OmniLight3D).light_color = c
			(s.props.glow as OmniLight3D).light_energy = 1.0 + 0.4 * sin(t * 11.0)
			if cycle < 6.0:
				for key: String in ["simon", "usa"]:
					var v3: PaperVisual = a[key]
					if v3.get("_action") != "console" or float(v3.get("_action_time")) < 0.05: v3.play("console")
					v3.set_combat_state({})
			else:
				_emote(a.usa, "cheer", cycle - 6.0)
				_emote(a.simon, "sad", cycle - 6.0)
		"gallery":
			var cycle2: float = fmod(t, 6.0)
			var step3: int = int(t / 1.6)
			if step3 != int(s.step):
				s.step = step3
				a.bleu.play("eat")
			if cycle2 > 3.0 and cycle2 < 5.3: _emote(a.elly, "laugh", cycle2 - 3.0)
			else: a.elly.set_combat_state({})
			(s.props.beam as SpotLight3D).light_energy = 1.6 + 0.5 * sin(t * 23.0) * sin(t * 3.1)
		"settings":
			var cycle3: float = fmod(t, 7.0)
			var ash: PaperVisual = a.ash
			var zap_step: int = int(t / 7.0)
			if cycle3 >= 4.2 and int(s.get("zapped", -1)) != zap_step:
				s["zapped"] = zap_step
				ash.play("zap")
				(s.props.sparks as CPUParticles3D).restart()
				(s.props.sparks as CPUParticles3D).emitting = true
				_flash.light_energy = 6.0
			elif cycle3 < 4.2 or cycle3 > 5.85:
				if ash.get("_action") != "repair" or float(ash.get("_action_time")) < 0.05: ash.play("repair")
			if cycle3 >= 4.2 and cycle3 < 4.7 and fmod(t, 0.12) < 0.06: _flash.light_energy = 5.0
		"credits":
			var cycle4: float = fmod(t, 7.5)
			_emote(a.lysia, "wave", fmod(t, 2.5))
			_emote(a.bleu, "cheer", fmod(t + 0.8, 2.5))
			_emote(a.elly, "thumbsup", fmod(t + 1.6, 2.5))
		"quit":
			var cycle5: float = fmod(t, 7.0)
			var alice: PaperVisual = a.alice
			var z: float = lerpf(1.4, -0.6, clampf(cycle5 / 5.0, 0.0, 1.0))
			var speed: float = 0.4 if cycle5 < 5.0 else 0.0
			alice.position.z = z
			alice.animate(dt, Vector3(0, 0, - speed), false, false)
			_accent.light_energy = 1.4 + 1.2 * absf(sin(t * 2.2))
			if cycle5 > 6.6: modulate.a = minf(modulate.a, (7.0 - cycle5) / 0.4)
			return
		"shop", "dance":
			var dancer: PaperVisual = a.values()[0]
			var dance: String = str(s.get("dance", ""))
			var info: Dictionary = Dances.info(dance)
			var dance_t: float = t
			if id == "dance" and _music.playing and _music.stream:
				dance_t = _music.get_playback_position()
				if ui and ui.world.audio: ui.world.audio.duck_for(0.4)
			_emote(dancer, dance, dance_t)
	for key: Variant in a:
		var visual: PaperVisual = a[key]
		visual.animate(dt, Vector3.ZERO, false, false)
