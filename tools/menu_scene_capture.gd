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
	RenderingServer.render_loop_enabled = true
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if fast: RenderingServer.render_loop_enabled = false
	if crop:
		var size: Vector2i = image.get_size()
		var x: int = int(size.x * 0.36)
		image = image.get_region(Rect2i(x, int(size.y * 0.04), size.x - x, size.y - int(size.y * 0.04)))
	image.save_png(out_dir.path_join(tag + ".png"))

func _run() -> void :
	get_window().size = window_size
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
	if not dance.is_empty():
		ui.shop_selected = dance
		ui.show_shop()
		await _wait(1.2)
	var index: int = 0
	for scene: String in scenes:
		if dance.is_empty(): vignettes.hover(scene)
		var started: float = _clock
		var t: float = start_at
		if t > 0.0: await _wait(t)
		while t <= end_at + 0.0001:
			if switch_after > 0.0 and t >= switch_after and index + 1 < scenes.size(): break
			await _wait(started + t - _clock)
			await _save("%s_%06.2f" % [scene, t])
			t += step
		print("MENU_SCENE_CAPTURE ", scene, " jusqu'à ", snappedf(_clock - started, 0.01), " s")
		index += 1
	print("MENU_SCENE_CAPTURE fin")
	get_tree().quit()
