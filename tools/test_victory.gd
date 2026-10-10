extends Node
# Joue les films de victoire LMS de la cinémathèque et capture des images.
# Usage (rendu) :
#   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 --fixed-fps 30 -- \
#     --tool test_victory --victory Simon,Usayuko --vcap-dir /tmp/x --vcap-step 0.5
# Options : --victory <noms|all> · --vfilm <id de la cinémathèque> · --vcap-dir <dossier>
#           --vcap-step <s> (0 = aucune capture) · --vcap-from <s> · --vcap-to <s>
#           --vclean (cache les commandes de la cinémathèque sur les captures)
#           --vreal <nom> : joue la fin comme main.gd en fin de manche (phase « ending »,
#           puis écran des résultats), sur la carte choisie avec --map school|forest|snow
#           --vquit <s> : avec --vreal, quitte le jeu en plein film (test de fermeture)

var world: Node
var films: Array[String] = []
var out_dir: String = ""
var step: float = 0.5
var from_time: float = 0.0
var to_time: float = INF
var clean: bool = false
var real: String = ""
var quit_at: float = INF


func setup(game_world: Node) -> void :
	world = game_world
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		var value: String = args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--victory":
				var names: PackedStringArray = PaperData.NAMES if value == "all" else value.split(",", false)
				for person: String in names: films.append("lms_win_" + person.strip_edges())
			"--vfilm":
				for id: String in value.split(",", false): films.append(id.strip_edges())
			"--vcap-dir": out_dir = value
			"--vcap-step": step = float(value)
			"--vcap-from": from_time = float(value)
			"--vcap-to": to_time = float(value)
			"--vclean": clean = true
			"--vreal": real = value
			"--vquit": quit_at = float(value)
	if films.is_empty(): films.append("lms_win_Simon")
	if not out_dir.is_empty(): DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void :
	for i: int in range(20): await get_tree().process_frame
	while str(world.phase) != "menu": await get_tree().process_frame
	if not real.is_empty():
		await _run_real()
		return
	world.gallery.open()
	await get_tree().process_frame
	var errors: int = 0
	for id: String in films:
		var entry: Dictionary = {}
		for item: Dictionary in world.gallery.entries:
			if str(item.id) == id: entry = item
		if entry.is_empty():
			push_error("VICTORY_TEST film introuvable: " + id)
			errors += 1
			continue
		print("VICTORY_TEST start ", id, " kind=", entry.kind, " duration=", entry.duration)
		world.gallery.play_entry(entry)
		if clean: world.ui.hide_gallery_transport()
		print("VICTORY_TEST room=", world.film.victory.room, " turn=", rad_to_deg(world.film.victory.turn), " snowy=", world.film.victory.snowy)
		var next_capture: float = from_time
		var frames: int = 0
		var started: int = Time.get_ticks_msec()
		while world.gallery.playing:
			await get_tree().process_frame
			frames += 1
			var t: float = float(world.gallery.time)
			if step > 0.0 and not out_dir.is_empty() and t >= next_capture and t <= to_time:
				next_capture += step
				await RenderingServer.frame_post_draw
				var image: Image = get_viewport().get_texture().get_image()
				if image: image.save_png(out_dir.path_join("%s_%05.2f.png" % [id, t]))
		var film: Variant = world.film
		print("VICTORY_TEST done ", id, " film_kind=", film.kind, " duration=", film.duration, " frames=", frames, " wall_ms=", Time.get_ticks_msec() - started)
		world.gallery.browse()
		await get_tree().process_frame
	world.gallery.close()
	await get_tree().process_frame
	print("VICTORY_TEST complete errors=", errors)
	get_tree().quit()


func _run_real() -> void :
	print("VICTORY_TEST real ending ", real, " map=", world.selected_map)
	world.outcome = "survivors";world.lms = true;world.ending_kind = "ending_lms"
	world.ending_people = [real];world.ending_focus = real
	world.phase = "ending";world.cinema = 0.0
	world.audio.set_mode("ending")
	world._begin_film(false)
	print("VICTORY_TEST room=", world.film.victory.room, " turn=", rad_to_deg(world.film.victory.turn), " snowy=", world.film.victory.snowy)
	var next_capture: float = from_time
	var started: int = Time.get_ticks_msec()
	while str(world.phase) == "ending" and not bool(world.ending_presented):
		await get_tree().process_frame
		var t: float = float(world.cinema)
		if t >= quit_at:
			print("VICTORY_TEST quitting mid-film at ", t)
			get_tree().quit()
			return
		if step > 0.0 and not out_dir.is_empty() and t >= next_capture and t <= to_time:
			next_capture += step
			await RenderingServer.frame_post_draw
			var image: Image = get_viewport().get_texture().get_image()
			if image: image.save_png(out_dir.path_join("real_%s_%s_%05.2f.png" % [world.selected_map, real, t]))
	print("VICTORY_TEST real done film_kind=", world.film.kind, " presented=", world.ending_presented, " cinema=", world.cinema, " wall_ms=", Time.get_ticks_msec() - started)
	for i: int in range(20): await get_tree().process_frame
	if not out_dir.is_empty():
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		if image: image.save_png(out_dir.path_join("real_%s_%s_results.png" % [world.selected_map, real]))
	print("VICTORY_TEST complete errors=0")
	get_tree().quit()
