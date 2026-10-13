extends Control

# Scènes 3D de survol de l'écran titre (à droite du menu principal et de la boutique).
# Chaque bouton a sa petite scène mise en scène (menu_scene_<id>.gd) : décor, acteurs
# animés par des clips écrits pour elle (anim_set_menu.gd), caméra qui bouge, temps
# forts tirés au hasard. Le décor est rendu dans une vue à part puis flouté (faux flou
# de profondeur) et les personnages passent nets par-dessus (menu_vignette.gdshader).
# Les scènes se construisent une étape par image, en tâche de fond, puis chacune est
# rendue une fois en invisible pour compiler ses shaders avant le premier survol.

const Dances = preload("res://dances.gd")
const MenuScene = preload("res://menu_scene.gd")
const COMPOSITE: Shader = preload("res://menu_vignette.gdshader")
const SCENE_SCRIPTS: Dictionary = {
	"play": preload("res://menu_scene_play.gd"),
	"training": preload("res://menu_scene_training.gd"),
	"friends": preload("res://menu_scene_friends.gd"),
	"gallery": preload("res://menu_scene_gallery.gd"),
	"settings": preload("res://menu_scene_settings.gd"),
	"credits": preload("res://menu_scene_credits.gd"),
	"quit": preload("res://menu_scene_quit.gd"),
	"shop": preload("res://menu_scene_shop.gd"),
	"dance": preload("res://menu_scene_dance.gd"),
}
# Ordre de préparation en tâche de fond : JOUER (focus par défaut) d'abord.
const PREPARE_ORDER: Array[String] = ["play", "training", "friends", "shop", "gallery", "settings", "credits", "quit"]

var ui: Node
var _view: ColorRect
var _composite: ShaderMaterial
var _fg: SubViewport
var _bg: SubViewport
var _world: World3D
var _stage: Node3D
var _cam_fg: Camera3D
var _cam_bg: Camera3D
var _scenes: Dictionary = {}
var _current: String = ""
var _wanted: String = ""
var _wanted_since: float = 0.0
var _alpha: float = 0.0
var _clock: float = 0.0
var _music: AudioStreamPlayer
var _preview_person: String = "Bleuette"
var _preview_dance: String = ""
var _lineup_hidden: bool = false
var _menu_held: bool = false
var _prepare_queue: Array[String] = []
var _warming: String = ""
var _warm_frames: int = 0
var _shake_seed: float = 0.0
var _cam_state: Dictionary = {}
# Débogage et captures : caméra imposée ({eye, target, fov}) et temps fort forcé.
var debug_camera: Dictionary = {}
var debug_beat: String = ""

# Aperçu de danse : même niveau que sa propre danse en partie (≈ -32 LUFS, bus PaperMusic) ; il
# remplace la musique du menu le temps de l'aperçu au lieu de s'y superposer.
const PREVIEW_DB: float = -1.5

const ACCENTS: Dictionary = {"play": Color("ff7a59"), "training": Color("ffb347"), "friends": Color("6fa8ff"), "gallery": Color("b08cff"), "settings": Color("7fe0ff"), "credits": Color("ffd27f"), "quit": Color("ff2a3c"), "shop": Color("ff6fd0"), "dance": Color("ff6fd0")}

func setup(owner_ui: Node) -> void :
	ui = owner_ui
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view = ColorRect.new()
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.color = Color.WHITE
	add_child(_view)
	_view.anchor_left = 0.36
	_view.anchor_right = 1.0
	_view.anchor_top = 0.04
	_view.anchor_bottom = 1.0
	_world = World3D.new()
	_fg = _make_viewport(true)
	_bg = _make_viewport(false)
	_stage = Node3D.new()
	_stage.name = "MenuStage"
	_fg.add_child(_stage)
	_cam_fg = Camera3D.new()
	_cam_fg.cull_mask = 0xFFFFF & ~MenuScene.BG_LAYER
	_fg.add_child(_cam_fg)
	_cam_fg.current = true
	_cam_bg = Camera3D.new()
	_cam_bg.cull_mask = MenuScene.BG_LAYER
	_bg.add_child(_cam_bg)
	_cam_bg.current = true
	_composite = ShaderMaterial.new()
	_composite.shader = COMPOSITE
	_composite.set_shader_parameter("fg_tex", _fg.get_texture())
	_composite.set_shader_parameter("bg_tex", _bg.get_texture())
	_view.material = _composite
	_view.resized.connect(_on_resized)
	_music = AudioStreamPlayer.new()
	_music.bus = &"PaperMusic"
	_music.volume_db = PREVIEW_DB
	add_child(_music)
	_prepare_queue = PREPARE_ORDER.duplicate()
	modulate.a = 1.0
	hide()
	_on_resized.call_deferred()

func _make_viewport(front: bool) -> SubViewport:
	var viewport: SubViewport = SubViewport.new()
	viewport.world_3d = _world
	viewport.transparent_bg = front
	viewport.msaa_3d = Viewport.MSAA_2X if front else Viewport.MSAA_DISABLED
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.size = Vector2i(64, 64)
	add_child(viewport)
	return viewport

func _on_resized() -> void :
	var size: Vector2 = _view.size
	if size.x < 8.0 or size.y < 8.0: return
	_fg.size = Vector2i(roundi(size.x), roundi(size.y))
	_bg.size = Vector2i(maxi(8, roundi(size.x * 0.5)), maxi(8, roundi(size.y * 0.5)))
	_composite.set_shader_parameter("fg_px", Vector2(1.0 / size.x, 1.0 / size.y))
	_composite.set_shader_parameter("bg_px", Vector2(2.0 / size.x, 2.0 / size.y))
	_update_edge()

# Bord gauche du masque calé sur le liseré rouge de la bande d'encre du menu principal
# (ui.gd, _main_decor : bande de (0.05, 1.12) à (0.3, -0.12), largeur 640 × hauteur / 900).
func _update_edge() -> void :
	var screen: Vector2 = get_viewport_rect().size
	if screen.x < 8.0: return
	var k: float = screen.y / 900.0
	var from: Vector2 = Vector2(0.05, 1.12) * screen
	var to: Vector2 = Vector2(0.3, -0.12) * screen
	var dir: Vector2 = (to - from).normalized()
	var edge: Vector2 = from - dir.orthogonal() * (640.0 * k * 0.5 + 26.0 * k)
	var rect: Rect2 = _view.get_global_rect()
	if rect.size.x < 8.0: return
	var top_y: float = rect.position.y
	var bottom_y: float = rect.end.y
	var x_top: float = edge.x + dir.x * (top_y - edge.y) / dir.y
	var x_bottom: float = edge.x + dir.x * (bottom_y - edge.y) / dir.y
	_composite.set_shader_parameter("edge_u", Vector2((x_top - rect.position.x) / rect.size.x, (x_bottom - rect.position.x) / rect.size.x))

func hover(action: String) -> void :
	if action == _wanted: return
	_wanted = action
	_wanted_since = _clock

func preview_dance(person: String, dance_id: String) -> void :
	_preview_person = person
	_preview_dance = dance_id
	if _scenes.has("dance"):
		var old: Node = _scenes["dance"]
		if _current == "dance": _current = ""
		old.queue_free()
		_scenes.erase("dance")
	# La scène affichée (vignette « BOUTIQUE » du menu) doit disparaître, sinon
	# son danseur reste superposé à celui de l'aperçu.
	if _current != "" and _scenes.has(_current): _hide_scene(_current)
	_current = ""
	_alpha = 0.0
	_wanted = "dance" if not dance_id.is_empty() else ""
	_wanted_since = _clock - 1.0

func _active_page() -> bool:
	if ui == null or not ui.page.visible or not (ui.world.phase in ["menu", "lobby"]): return false
	return ui.current_page == "main" or ui.current_page == "shop"

func _scene(id: String) -> MenuScene:
	if _scenes.has(id): return _scenes[id]
	if not SCENE_SCRIPTS.has(id): return null
	var scene: MenuScene = (SCENE_SCRIPTS[id] as GDScript).new()
	scene.name = "Scene_" + id
	scene.id = id
	scene.accent = ACCENTS.get(id, Color.WHITE)
	if id == "dance":
		scene.set("person", _preview_person)
		scene.set("dance", _preview_dance)
	_stage.add_child(scene)
	scene.setup(self)
	_scenes[id] = scene
	return scene

func _process(delta: float) -> void :
	_clock += delta
	var page_ok: bool = _active_page()
	if not page_ok and _wanted != "" and ui and ui.current_page != "shop": _wanted = ""
	var target: String = _wanted if page_ok and (_wanted != "" or _clock - _wanted_since > 0.35) else ""
	if not page_ok: target = ""
	# Construction progressive : la scène voulue d'abord, puis les autres en tâche de fond.
	var building: bool = false
	if target != "":
		var wanted_scene: MenuScene = _scene(target)
		if wanted_scene and not wanted_scene.built:
			wanted_scene.build_next()
			building = true
	if not building and page_ok and _warming == "": _prepare_step(_current == "" and _alpha <= 0.001 and target == "")
	# Fondu : la scène affichée s'efface avant que la suivante n'apparaisse.
	var ready: bool = target != "" and _scenes.has(target) and (_scenes[target] as MenuScene).built
	if _current != target and _alpha <= 0.02:
		if _current != "": _hide_scene(_current)
		_current = ""
		if ready: _show_scene(target)
	var show: bool = target != "" and _current == target
	var speed: float = 3.2 if show else 6.5
	_alpha = move_toward(_alpha, 1.0 if show else 0.0, delta * speed)
	visible = _alpha > 0.001
	_set_lineup(show or (_current != "" and _alpha > 0.02))
	if not show and _music.playing and _alpha <= 0.01: _music.stop()
	_hold_menu_music(_music.playing)
	var rendering: bool = visible and _current != ""
	if _warming != "" and (_current != "" or target != ""):
		# Survol pendant le préchauffage : on l'abandonne, la scène voulue passe d'abord.
		if _warming != _current: (_scenes[_warming] as Node3D).visible = false
		_warming = ""
	if _warming != "":
		_warm_frames -= 1
		if _warm_frames <= 0:
			var warmed: MenuScene = _scenes[_warming]
			warmed.visible = false
			warmed.leave()
			warmed.set_meta("warmed", true)
			_warming = ""
	var mode: int = SubViewport.UPDATE_ALWAYS if rendering or _warming != "" else SubViewport.UPDATE_DISABLED
	_fg.render_target_update_mode = mode
	var scene: MenuScene = _scenes.get(_current) if _current != "" else null
	_bg.render_target_update_mode = mode if (scene == null or scene.layered) else SubViewport.UPDATE_DISABLED
	if not rendering:
		if _warming == "": return
		_apply_look(_scenes[_warming], 0.0)
		return
	scene.tick(delta)
	_apply_camera(scene, delta)
	_apply_look(scene, _alpha)

func _show_scene(id: String) -> void :
	var scene: MenuScene = _scenes[id]
	_current = id
	_warming = ""
	for other: String in _scenes:
		if other != id: (_scenes[other] as Node3D).visible = false
	scene.visible = true
	scene.forced_beat = debug_beat
	scene.enter()
	# Un pas d'animation hors champ : la première image montrée est déjà la bonne pose.
	scene.tick(1.0 / 60.0)
	_cam_state = {}
	_shake_seed = randf() * 100.0
	if id == "dance" and not _preview_dance.is_empty():
		_music.stream = Dances.music(_preview_dance)
		if _music.stream: _music.play(0.0)
	elif _music.playing: _music.stop()

func _hide_scene(id: String) -> void :
	var scene: MenuScene = _scenes.get(id)
	if scene == null: return
	scene.leave()
	scene.visible = false

# Préparation en tâche de fond : une étape de construction par image, puis un rendu
# invisible de la scène finie pour compiler ses shaders avant le premier survol.
func _prepare_step(can_warm: bool) -> void :
	for id: String in _prepare_queue:
		var scene: MenuScene = _scene(id)
		if scene == null: continue
		if not scene.built:
			scene.build_next()
			return
		if scene.has_meta("warmed"): continue
		if not can_warm: continue
		_warming = id
		_warm_frames = 2
		scene.visible = true
		scene.forced_beat = ""
		scene.enter()
		scene.tick(1.0 / 60.0)
		_apply_camera(scene, 0.0)
		return

func _apply_camera(scene: MenuScene, delta: float) -> void :
	var shot: Dictionary = debug_camera if not debug_camera.is_empty() else scene.camera()
	if shot.is_empty(): return
	var eye: Vector3 = shot.eye
	var target: Vector3 = shot.target
	var fov: float = float(shot.get("fov", 34.0))
	var shake: float = float(shot.get("shake", 0.0)) if debug_camera.is_empty() else 0.0
	var t: float = _clock + _shake_seed
	# Caméra à l'épaule : quelques sinusoïdes lentes, jamais en phase.
	var wobble: Vector3 = Vector3(sin(t * 0.71) + 0.6 * sin(t * 1.93 + 1.7), sin(t * 0.53 + 0.4) + 0.5 * sin(t * 1.37 + 2.1), sin(t * 0.37 + 2.9)) * 0.012 * shake
	var aim: Vector3 = Vector3(sin(t * 0.61 + 0.9) + 0.4 * sin(t * 2.3), sin(t * 0.83 + 2.2) + 0.4 * sin(t * 1.7 + 0.5), 0.0) * 0.006 * shake
	var basis_look: Basis = Basis.looking_at(target - eye, Vector3.UP)
	# Cadrage : la cible tombe à la place « x » de l'image (le masque mange la gauche).
	var place: float = float(shot.get("x", 0.56))
	var aspect: float = float(_fg.size.x) / maxf(1.0, float(_fg.size.y))
	var half_width: float = tan(deg_to_rad(fov) * 0.5) * aspect
	var yaw_shift: float = atan((place - 0.5) * 2.0 * half_width)
	basis_look = basis_look * Basis(Vector3.UP, yaw_shift)
	basis_look = basis_look * Basis(Vector3(1, 0, 0), aim.y) * Basis(Vector3.UP, aim.x)
	var roll: float = float(shot.get("roll", 0.0))
	if absf(roll) > 0.0001: basis_look = basis_look * Basis(Vector3(0, 0, 1), roll)
	var xform: Transform3D = Transform3D(basis_look, eye + basis_look * wobble)
	xform = scene.global_transform * xform
	for camera: Camera3D in [_cam_fg, _cam_bg]:
		camera.global_transform = xform
		camera.fov = fov
		camera.environment = scene.env_fg if camera == _cam_fg else scene.env_bg
	_composite.set_shader_parameter("bg_blur", float(shot.get("bg", 1.6)))
	_composite.set_shader_parameter("fg_blur", float(shot.get("fg", 0.0)))

func _apply_look(scene: MenuScene, alpha: float) -> void :
	var look: Dictionary = scene.grade
	_composite.set_shader_parameter("has_bg", scene.layered)
	_composite.set_shader_parameter("masked", scene.masked)
	_composite.set_shader_parameter("fade", alpha)
	_composite.set_shader_parameter("dip", float(look.get("dip", 0.0)))
	_composite.set_shader_parameter("flash", float(look.get("flash", 0.0)) * (0.35 if ui and bool(ui.get("reduced_motion")) else 1.0))
	_composite.set_shader_parameter("lift", look.get("lift", Vector3.ZERO))
	_composite.set_shader_parameter("gain", look.get("gain", Vector3.ONE))
	_composite.set_shader_parameter("saturation", float(look.get("saturation", 1.0)))
	_composite.set_shader_parameter("contrast", float(look.get("contrast", 1.0)))
	_composite.set_shader_parameter("vignette_amount", float(look.get("vignette", 0.35)))
	_composite.set_shader_parameter("grain", float(look.get("grain", 0.025)))
	_composite.set_shader_parameter("time", _clock)

func _hold_menu_music(on: bool) -> void :
	if on == _menu_held or not is_instance_valid(ui) or not is_instance_valid(ui.world): return
	var audio: Variant = ui.world.get("audio")
	if not is_instance_valid(audio): return
	_menu_held = on
	audio.hold_music(on, "shop")

func _exit_tree() -> void :
	_hold_menu_music(false)

func _set_lineup(hidden: bool) -> void :
	var backdrop: Node = ui.menu_backdrop if ui else null
	if not is_instance_valid(backdrop): return
	if hidden:
		backdrop.set("_lineup_alpha_goal", 0.08)
		_lineup_hidden = true
	elif _lineup_hidden:
		backdrop.set("_lineup_alpha_goal", float(backdrop.call("lineup_goal_for_mode")) if backdrop.has_method("lineup_goal_for_mode") else 1.0)
		_lineup_hidden = false

# --- Outils de capture ----------------------------------------------------------

func debug_scene(id: String) -> MenuScene:
	return _scene(id)

func current_scene() -> MenuScene:
	return _scenes.get(_current) if _current != "" else null
