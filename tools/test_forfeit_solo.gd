extends Node

# Forfait d'Alice simulé en solo (sans réseau) : fin « blocus » en jeu, bouton PASSER, écran de résultats.
# godot --rendering-driver opengl3 -- --tool test_forfeit_solo --out /tmp/x [--forfeit-map snow]
# Sans rendu : godot --headless -- --tool test_forfeit_solo

var world: Node
var out_dir: String = ""
var failures: Array[String] = []

func setup(owner: Node) -> void :
	world = owner
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var map_id: String = "school"
	for i: int in range(args.size()):
		if args[i] == "--out" and i + 1 < args.size(): out_dir = args[i + 1]
		if args[i] == "--forfeit-map" and i + 1 < args.size(): map_id = args[i + 1]
	world.selected = "Simon"
	world._rebuild_map(map_id)
	_run.call_deferred()

func _check(ok: bool, what: String) -> void :
	print("FORFEIT_TEST ", "OK   " if ok else "FAIL ", what)
	if not ok: failures.append(what)

func _shot(file_name: String) -> void :
	if out_dir.is_empty(): return
	for k: int in range(3): await get_tree().process_frame
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir + "/" + file_name)
	print("FRAME ", out_dir + "/" + file_name)

func _run() -> void :
	if not out_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(out_dir)
		get_window().size = Vector2i(1280, 720)
	for i: int in range(4): await get_tree().process_frame
	world.start_solo(false)
	var waited: float = 0.0
	while world.phase != "playing" and waited < 30.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	_check(world.phase == "playing", "la manche démarre")
	await get_tree().create_timer(2.0).timeout
	var alice: PaperActor = world.killer_actor()
	_check(alice != null and alice.bot, "Alice IA en solo")
	_check(not PaperAliceForfeit.peer_left(world, alice.id), "une Alice IA ne déclenche pas le blocus")
	var tickets: int = world.tickets
	# On fait comme si Alice était humaine et venait de quitter la partie.
	alice.bot = false
	_check(PaperAliceForfeit.peer_left(world, alice.id), "Alice humaine qui part → forfait")
	_check(world.phase == "ending" and world.outcome == "survivors" and world.ending_kind == PaperAliceForfeit.KIND, "fin : %s / %s / %s" % [world.phase, world.outcome, world.ending_kind])
	_check(world.film.kind == PaperAliceForfeit.KIND, "film du blocus lancé")
	_check(world.tickets > tickets, "tickets %d -> %d" % [tickets, world.tickets])
	_check(str(world.audio.active_track) == "blocus", "musique du blocus (%s)" % str(world.audio.active_track))
	print("FORFEIT_TEST people=", world.ending_people, " focus=", world.ending_focus, " results=", world.match_results.size())
	for t: float in [3.0, 13.0, 27.0]:
		world.cinema = t
		await _shot("ingame_%04.1f.png" % t)
	var overlay: Variant = world.film.blocus.overlay if is_instance_valid(world.film.blocus) else null
	_check(overlay != null and is_instance_valid(overlay._skip), "bouton PASSER présent en jeu")
	if overlay: overlay.skip()
	for i: int in range(5): await get_tree().process_frame
	_check(world.ending_presented and world.ui.current_page == "ending", "PASSER mène à l'écran de résultats (%s)" % str(world.ui.current_page))
	await get_tree().create_timer(1.2).timeout
	await _shot("ending_screen.png")
	_check(not is_instance_valid(world.film.blocus), "film arrêté et nettoyé après la fin")
	print("FORFEIT_TEST_RESULT ", "PASS" if failures.is_empty() else "FAIL", " ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
