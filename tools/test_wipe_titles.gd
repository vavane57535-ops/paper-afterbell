extends Node

# Volets de transition des menus : le titre de la page suivante, en lettres découpées géantes,
# capturé au moment où il est plaqué (horloge du jeu ralentie pendant le volet).
#   XDG_DATA_HOME=<dossier de test> xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 \
#       -- --tool test_wipe_titles --wt-out DIR [--wt-en] [--wt-size 1920x1080] [--wt-pages settings,shop,credits]
# Une image par page : DIR/volet_<page>.png ; lignes « WIPE <page> <titre affiché> ».

var world: Node
var out_dir: String = "user://wipe_titles"
var pages: PackedStringArray = PackedStringArray(["settings", "shop", "credits", "network"])
var english: bool = false

func setup(game_world: Node) -> void :
	world = game_world
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		if args[i] == "--wt-out" and i + 1 < args.size(): out_dir = args[i + 1]
		if args[i] == "--wt-pages" and i + 1 < args.size(): pages = args[i + 1].split(",")
		if args[i] == "--wt-en": english = true
		if args[i] == "--wt-size" and i + 1 < args.size():
			var parts: PackedStringArray = args[i + 1].split("x")
			if parts.size() == 2: get_window().size = Vector2i(int(parts[0]), int(parts[1]))
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _wait(seconds: float) -> void :
	await get_tree().create_timer(seconds, true, false, true).timeout

func _run() -> void :
	await get_tree().process_frame
	# Langue pour cette session seulement (world.options n'est pas touché).
	if english: PaperLanguage.language = "en"
	await _wait(2.0)
	var actions: Dictionary = {"settings": "settings", "shop": "shop", "credits": "credits", "network": "friends"}
	for page: String in pages:
		world.ui.show_main()
		await _wait(1.4)
		var wipe: Node = world.ui.get("_wipe")
		# Le volet joue vite : on ralentit l'horloge du jeu le temps de le saisir plaqué.
		Engine.time_scale = 0.08
		world.ui._main_action(str(actions.get(page, page)))
		var waited: float = 0.0
		while is_instance_valid(wipe) and float(wipe.get("_t")) < 0.42 and waited < 20.0:
			await get_tree().process_frame
			waited += get_process_delta_time() / maxf(Engine.time_scale, 0.001)
		await RenderingServer.frame_post_draw
		var path: String = out_dir.path_join("volet_%s.png" % page)
		get_viewport().get_texture().get_image().save_png(path)
		print("WIPE ", page, " ", PaperLanguage.t(str(world.ui.PAGE_TITLES.get(page, ""))), " t=", wipe.get("_t") if is_instance_valid(wipe) else -1.0, " -> ", path)
		Engine.time_scale = 1.0
		await _wait(1.2)
	PaperLanguage.language = "fr"
	get_tree().quit()
