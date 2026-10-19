extends Node

# Planches des scènes de survol de l'écran titre (ui_menu_vignettes.gd).
# Lance avec --fixed-fps 30 pour un pas de temps régulier :
#   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 --fixed-fps 30 -- \
#       --tool menu_scene_capture --scenes play,quit --to 40 --step 0.25 --out /tmp/x [--crop] [--switch 2.0]
# --crop : n'enregistre que la zone de la scène (droite de l'écran) ; sinon l'écran entier.
# --switch S : survole la scène suivante au bout de S secondes sans attendre (fluidité du passage).
# --dance ID : ouvre la boutique et prévisualise cette danse (scène « dance »).

var world: Node
var scenes: PackedStringArray = PackedStringArray(["play"])
var start_at: float = 0.0
var end_at: float = 10.0
var step: float = 0.5
var out_dir: String = "/tmp/menu_scene_capture"
var crop: bool = false
var switch_after: float = -1.0
var dance: String = ""
var fast: bool = true
var window_size: Vector2i = Vector2i(1280, 800)
var beat: String = ""
var camera: Dictionary = {}
var scout: Array = []
var fg_only: bool = false
var around_actor: String = ""
var around_dist: float = 3.0
var around_height: float = 1.2
var around_fov: float = 36.0
var around_angles: Array[float] = []

func _around_camera(vignettes: Node, angle: float) -> Dictionary:
	var scene: Node = vignettes.call("current_scene")
	var actors: Dictionary = scene.get("actors") if scene else {}
	var visual: Node3D = actors.get(around_actor)
	if visual == null: return {}
	var chest: Vector3 = visual.call("socket_position", "chest")
	var base: Vector3 = Vector3(chest.x, 0.0, chest.z)
	var facing: float = visual.rotation.y + deg_to_rad(angle)
	var eye: Vector3 = base + Vector3(-sin(facing), 0.0, -cos(facing)) * around_dist + Vector3(0, around_height, 0)
	return {"eye": eye, "target": chest - Vector3(0, 0.15, 0), "fov": around_fov, "x": 0.55, "blur": 0.0}

func _vec(text: String) -> Vector3:
	var p: PackedStringArray = text.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))
var _clock: float = 0.0

func setup(game_world: Node) -> void :
	world = game_world
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		var value: String = args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--scenes": scenes = value.split(",")
			"--from": start_at = float(value)
			"--to": end_at = float(value)
			"--step": step = maxf(float(value), 1.0 / 60.0)
			"--out": out_dir = value
			"--crop": crop = true
			"--switch": switch_after = float(value)
			"--dance": dance = value
			"--beat": beat = value
			"--cam":
				# "x,y,z>x,y,z>fov" : caméra imposée (repérage du décor).
				var parts: PackedStringArray = value.split(">")
				camera = {"eye": _vec(parts[0]), "target": _vec(parts[1]), "fov": float(parts[2]) if parts.size() > 2 else 40.0, "x": 0.5, "bg": 0.0}
			"--cams":
				# Repérage : plusieurs caméras « œil>cible>fov » séparées par « ; », une image chacune.
				for item: String in value.split(";"):
					var bits: PackedStringArray = item.split(">")
					scout.append({"eye": _vec(bits[0]), "target": _vec(bits[1]), "fov": float(bits[2]) if bits.size() > 2 else 40.0, "x": 0.5, "bg": 0.0})
			"--fg-only": fg_only = true
			"--around":
				# « acteur,distance,hauteur,fov,angle1,angle2… » : caméras autour d'un acteur
				# (angles en degrés, 0 = face à lui), une image par angle et par instant.
				var bits: PackedStringArray = value.split(",")
				around_actor = bits[0]
				around_dist = float(bits[1])
				around_height = float(bits[2])
				around_fov = float(bits[3])
				for j: int in range(4, bits.size()): around_angles.append(float(bits[j]))
			"--slow": fast = false
			"--size":
				var parts: PackedStringArray = value.split("x")
				if parts.size() == 2: window_size = Vector2i(int(parts[0]), int(parts[1]))
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _process(delta: float) -> void :
	_clock += delta

func _wait(seconds: float) -> void :
	var start: float = _clock
	while _clock - start < seconds - 0.0001: await get_tree().process_frame

func _save(tag: String) -> void :
	# Rendu coupé entre deux captures (llvmpipe est lent) : seule l'animation avance.
	var resumed: bool = not RenderingServer.render_loop_enabled
	RenderingServer.render_loop_enabled = true
	await RenderingServer.frame_post_draw
	# Première image après une coupure du rendu : la texture lue peut être en retard d'une image.
	if resumed: await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if fast: RenderingServer.render_loop_enabled = false
	if crop:
		var size: Vector2i = image.get_size()
		var x: int = int(size.x * 0.36)
		image = image.get_region(Rect2i(x, int(size.y * 0.04), size.x - x, size.y - int(size.y * 0.04)))
	image.save_png(out_dir.path_join(tag + ".png"))

# Avec --beat, les instants sont ceux du temps fort (horloge de la scène), pas de l'outil.
func _wait_beat(vignettes: Node, t: float) -> void :
	while true:
		var scene: Node = vignettes.call("current_scene")
		if scene != null and float(scene.get("beat_time")) >= t - 0.0001: return
		await get_tree().process_frame

func _run() -> void :
	get_window().size = window_size
	if fast: RenderingServer.render_loop_enabled = false
	await _wait(0.6)
	var ui: Node = world.ui
	ui._clear(ui.page)
	ui.show_main()
	await _wait(1.8)
	var vignettes: Node = ui.get("menu_vignettes")
	if not is_instance_valid(vignettes):
		print("MENU_SCENE_CAPTURE pas de vignettes")
		get_tree().quit()
		return
	# La souris loin des boutons : seul le survol forcé compte.
	Input.warp_mouse(Vector2(4, 4))
	vignettes.set("debug_beat", beat)
	vignettes.set("debug_camera", camera)
	if not dance.is_empty():
		ui.shop_selected = dance
		ui.show_shop()
		await _wait(1.2)
	var index: int = 0
	for scene: String in scenes:
		if dance.is_empty(): vignettes.hover(scene)
		var started: float = _clock
		var t: float = start_at
		if not beat.is_empty(): await _wait_beat(vignettes, t)
		elif t > 0.0: await _wait(t)
		if fg_only and vignettes.call("current_scene") != null: vignettes.call("current_scene").set("styled", false)
		if not scout.is_empty():
			for i: int in range(scout.size()):
				vignettes.set("debug_camera", scout[i])
				await get_tree().process_frame
				await _save("%s_cam%02d" % [scene, i])
			vignettes.set("debug_camera", camera)
			index += 1
			continue
		while t <= end_at + 0.0001:
			if switch_after > 0.0 and t >= switch_after and index + 1 < scenes.size(): break
			if not beat.is_empty(): await _wait_beat(vignettes, t)
			else: await _wait(started + t - _clock)
			if around_angles.is_empty():
				await _save("%s_%06.2f" % [scene, t])
			else:
				for a: int in range(around_angles.size()):
					vignettes.set("debug_camera", _around_camera(vignettes, around_angles[a]))
					await get_tree().process_frame
					await _save("%s%d_%06.2f" % [scene, a, t])
				vignettes.set("debug_camera", camera)
			t += step
		print("MENU_SCENE_CAPTURE ", scene, " jusqu'à ", snappedf(_clock - started, 0.01), " s")
		index += 1
	print("MENU_SCENE_CAPTURE fin")
	get_tree().quit()
