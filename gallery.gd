class_name PaperGallery
extends RefCounted

var world: Node
var entries: Array = []
var entry: Dictionary = {}
var browsing: bool = true
var playing: bool = false
var time: float = 0.0
var saved_map: String = "school"
var category: String = "all"
var search: String = ""
var team: Array = []

var _backdrop_clock: float = 0.0

func _init(game_world: Node) -> void :
	world = game_world

func open() -> void :
	if world.networked or world.phase != "menu": return
	entries = PaperCinema.catalogue()
	saved_map = world.selected_map
	if world.selected_map != "school": world._rebuild_map("school")
	world.phase = "gallery";world.preview_character = ""
	world.stage.hide();world.presentation.clear_entities()
	for node: Node3D in world.objective_nodes: node.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	category = "all";search = "";team.clear()
	browse()

func filtered_entries() -> Array:
	var result: Array = []
	for item: Dictionary in entries:
		if category != "all" and str(item.category) != category: continue
		if not search.strip_edges().is_empty() and not (str(item.title) + " " + " ".join(item.participants) + " " + str(item.description)).to_lower().contains(search.strip_edges().to_lower()): continue
		if category == "team" and not team.is_empty():
			if item.participants.size() != team.size(): continue
			var exact: bool = true
			for name: String in team:
				if not item.participants.has(name): exact = false
			if not exact: continue
		result.append(item)
	return result

func browse() -> void :
	playing = false;browsing = true
	if _is_prologue(): world.prologue.stop()
	world.audio.preview_end()
	world.film.begin("intro_survivors", PaperData.NAMES, "Simon")
	world.film.seek(2.4)
	_backdrop_clock = 1.0
	world.ui.hide_film()
	world.ui.show_gallery()
	# Le panneau 3D « SORTIE · À 01:20 » flottait en grand dans le décor figé derrière la liste
	# (les films de victoire le réaffichent en s'arrêtant) : caché tant qu'on parcourt la liste.
	_show_exit_sign(false)

func _show_exit_sign(shown: bool) -> void :
	var items: Variant = world.get("map_interactables")
	if not is_instance_valid(items): return
	var sign: Variant = items.get("exit_sign")
	if is_instance_valid(sign): (sign as Node3D).visible = shown

func play_entry(item: Dictionary) -> void :
	if world.phase != "gallery" or item.is_empty(): return
	if _is_prologue(): world.prologue.stop()
	entry = item.duplicate(true);time = 0.0;browsing = false;playing = true
	var music_mode: String = "lms" if str(entry.category).begins_with("lms") else "ambient" if str(entry.category) == "intro" else "blocus" if str(entry.kind) == PaperFilmBlocus.KIND else "ending"
	world.audio.preview_begin(str(entry.focus), music_mode)
	if _is_prologue():
		world.film.stop();world.audio.preview_pause(true)
		world.prologue.begin_prologue(true)
	else: world.film.begin(str(entry.kind), entry.participants, str(entry.focus))
	world.ui.show_film();world.ui.show_gallery_transport(entry)
	_film().seek(0.0)
	world.ui.update_film("", "", _film().black)
	world.ui.update_gallery_transport(time, _film().duration, playing)

func tick(delta: float) -> void :
	if browsing:
		_backdrop_clock -= delta
		if _backdrop_clock <= 0.0:
			_backdrop_clock = 1.0
			world.film.update(2.4, 0.0)
		return
	var current: PaperCinema = _film()
	if playing:
		time = minf(current.duration, time + delta)
		current.update(time, delta)
		if time >= current.duration:
			playing = false
			if _is_prologue(): world.prologue.set_paused(true)
			else: world.audio.preview_pause(true)
	else: current.update(time, 0.0)
	world.ui.update_film("", "", current.black)
	world.ui.update_gallery_transport(time, current.duration, playing)

func toggle_pause() -> void :
	if browsing: return
	if time >= _film().duration: restart();return
	playing = not playing
	if _is_prologue(): world.prologue.set_paused( not playing)
	else: world.audio.preview_pause( not playing)
	world.ui.update_gallery_transport(time, _film().duration, playing)

func seek(seconds: float) -> void :
	if browsing or not is_finite(seconds): return
	var current: PaperCinema = _film()
	time = clampf(seconds, 0.0, current.duration)
	current.seek(time)
	if time >= current.duration: playing = false
	if _is_prologue(): world.prologue.set_paused( not playing)
	else:
		world.audio.preview_seek(time)
		world.audio.preview_pause( not playing)
	world.ui.update_film("", "", current.black)
	world.ui.update_gallery_transport(time, current.duration, playing)

# Le prologue « Yiero » a son propre film (PaperPrologue), sa musique et ses bruitages.
func _is_prologue() -> bool:
	return str(entry.get("kind", "")) == "intro_yiero" and is_instance_valid(world.get("prologue"))

func _film() -> PaperCinema:
	return world.prologue if _is_prologue() else world.film

func restart() -> void :
	if not entry.is_empty(): play_entry(entry)

func close() -> void :
	playing = false;browsing = true
	if _is_prologue(): world.prologue.stop()
	world.audio.preview_end();world.film.stop()
	_show_exit_sign(true)
	world.ui.hide_gallery_transport();world.ui.hide_film()
	if saved_map != world.selected_map: world._rebuild_map(saved_map)
	world.stage.show();world.presentation.show()
	for node: Node3D in world.objective_nodes: node.show()
	world.phase = "menu";world.ui.show_main()
	world._update_camera(1.0)

func handle_input(event: InputEvent) -> bool:
	# Manette pendant la lecture : A pause / lecture, croix ← → ±1 s (B est géré par l'interface).
	if event is InputEventJoypadButton and event.pressed and not browsing:
		match event.button_index:
			JOY_BUTTON_A: toggle_pause()
			JOY_BUTTON_DPAD_LEFT: seek(time - 1.0)
			JOY_BUTTON_DPAD_RIGHT: seek(time + 1.0)
			_: return false
		return true
	if not (event is InputEventKey and event.pressed and not event.echo): return false
	match event.keycode:
		KEY_ESCAPE:
			if browsing: close()
			else: browse()
		KEY_SPACE:
			toggle_pause()
		KEY_LEFT:
			seek(time - 1.0)
		KEY_RIGHT:
			seek(time + 1.0)
		KEY_HOME:
			restart()
		_: return false
	return true
