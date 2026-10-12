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
	world.audio.preview_end()
	world.film.begin("intro_survivors", PaperData.NAMES, "Simon")
	world.film.seek(2.4)
	_backdrop_clock = 1.0
	world.ui.hide_film()
	world.ui.show_gallery()

func play_entry(item: Dictionary) -> void :
	if world.phase != "gallery" or item.is_empty(): return
	entry = item.duplicate(true);time = 0.0;browsing = false;playing = true
	world.film.begin(str(entry.kind), entry.participants, str(entry.focus))
	var music_mode: String = "lms" if str(entry.category).begins_with("lms") else "ambient" if str(entry.category) == "intro" else "blocus" if str(entry.kind) == PaperFilmBlocus.KIND else "ending"
	world.audio.preview_begin(str(entry.focus), music_mode)
	world.ui.show_film();world.ui.show_gallery_transport(entry)
	world.film.seek(0.0)
	world.ui.update_film("", "", world.film.black)
	world.ui.update_gallery_transport(time, world.film.duration, playing)

func tick(delta: float) -> void :
	if browsing:
		_backdrop_clock -= delta
		if _backdrop_clock <= 0.0:
			_backdrop_clock = 1.0
			world.film.update(2.4, 0.0)
		return
	if playing:
		time = minf(world.film.duration, time + delta)
		world.film.update(time, delta)
		if time >= world.film.duration:
			playing = false;world.audio.preview_pause(true)
	else: world.film.update(time, 0.0)
	world.ui.update_film("", "", world.film.black)
	world.ui.update_gallery_transport(time, world.film.duration, playing)

func toggle_pause() -> void :
	if browsing: return
	if time >= world.film.duration: restart();return
	playing = not playing
	world.audio.preview_pause( not playing)
	world.ui.update_gallery_transport(time, world.film.duration, playing)

func seek(seconds: float) -> void :
	if browsing or not is_finite(seconds): return
	time = clampf(seconds, 0.0, world.film.duration)
	world.film.seek(time);world.audio.preview_seek(time)
	if time >= world.film.duration: playing = false
	world.audio.preview_pause( not playing)
	world.ui.update_film("", "", world.film.black)
	world.ui.update_gallery_transport(time, world.film.duration, playing)

func restart() -> void :
	if not entry.is_empty(): play_entry(entry)

func close() -> void :
	playing = false;browsing = true
	world.audio.preview_end();world.film.stop()
	world.ui.hide_gallery_transport();world.ui.hide_film()
	if saved_map != world.selected_map: world._rebuild_map(saved_map)
	world.stage.show();world.presentation.show()
	for node: Node3D in world.objective_nodes: node.show()
	world.phase = "menu";world.ui.show_main()
	world._update_camera(1.0)

func handle_input(event: InputEvent) -> bool:
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
