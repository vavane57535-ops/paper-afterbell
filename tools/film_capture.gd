extends Node

# Outil de capture d'un film de la cinémathèque.
# godot --rendering-driver opengl3 -- --tool film_capture --film ending_blocus --times 1,4,8 --out /tmp/x [--people Simon,Elly] [--map school]
# Sans --times : capture une image toutes les 0,5 s sur toute la durée (--step pour changer le pas).

var world: Node
var film_kind: String = "ending_blocus"
var times: Array[float] = []
var step: float = 0.0
var out_dir: String = "/tmp/film_capture"
var people: Array = []
var focus: String = ""
var map_id: String = "school"
var size: Vector2i = Vector2i(1280, 720)

func setup(owner: Node) -> void :
	world = owner
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		var value: String = args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--film": film_kind = value
			"--times":
				for part: String in value.split(","): times.append(float(part))
			"--step": step = float(value)
			"--out": out_dir = value
			"--people": people = Array(value.split(","))
			"--focus": focus = value
			"--film-map": map_id = value
	_run.call_deferred()

func _run() -> void :
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = size
	for i: int in range(8): await get_tree().process_frame
	if people.is_empty(): people = PaperData.NAMES.duplicate()
	if focus.is_empty(): focus = str(people[0])
	world.gallery.open()
	if map_id != "school": world._rebuild_map(map_id)
	for i: int in range(4): await get_tree().process_frame
	world.gallery.play_entry({"id": "capture", "title": "capture", "category": "fins", "kind": film_kind, "participants": people, "focus": focus, "duration": PaperCinema.duration_for(film_kind, people), "description": ""})
	world.gallery.playing = false
	world.ui.hide_gallery_transport()
	var duration: float = world.film.duration
	if times.is_empty():
		var pace: float = step if step > 0.0 else 0.5
		var t: float = 0.0
		while t <= duration + 0.001:
			times.append(t);t += pace
	print("FILM_CAPTURE kind=", film_kind, " duration=", duration, " frames=", times.size())
	var index: int = 0
	for t: float in times:
		world.gallery.seek(t)
		# Laisse les animations et les tweens de l'interface avancer d'une image à ce temps.
		for k: int in range(2):
			world.gallery.seek(t)
			await get_tree().process_frame
		RenderingServer.force_draw()
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		var path: String = "%s/f%03d_%05.2f.png" % [out_dir, index, t]
		img.save_png(path)
		print("FRAME ", path)
		index += 1
	print("FILM_CAPTURE_DONE")
	get_tree().quit()
