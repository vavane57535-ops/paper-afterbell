extends Node

# Planches des films de fuite en équipe (0.17) et du blocus, pour juger l'animation.
# xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 --resolution 960x540 --fixed-fps 30 -- \
#   --tool escape_shots --es-people Simon,Elly [--es-film ending_survivors|ending_blocus] \
#   [--es-from 0 --es-to 4 --es-step 0.1 | --es-times 0.5,1,2] [--es-out DIR] [--es-map school|forest|snow] \
#   [--es-cam film|side:N|front:N|back:N|wide|door] [--es-focus Usayuko] [--es-size 640x360]
# side:N / front:N / back:N : caméra de contrôle qui suit l'acteur N (indice dans le film, Alice en dernier),
# de profil, de face ou de dos ; wide : plan large fixe de côté sur la porte ; door : depuis dehors.
# Sans rendu (--headless) : seulement le journal (durée, dépassements de portée des jambes).

var world: Node
var film_kind: String = "ending_survivors"
var people: Array = []
var focus: String = ""
var map_id: String = "school"
var out_dir: String = "/tmp/escape_shots"
var times: Array[float] = []
var from_t: float = 0.0
var to_t: float = -1.0
var step: float = 0.25
var cam: String = "film"
var size: Vector2i = Vector2i(960, 540)


func setup(owner: Node) -> void :
	world = owner
	# après le jeu : le film replace sa caméra à chaque image, la caméra de contrôle passe derrière
	process_priority = 1000
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		var value: String = args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--es-film": film_kind = value
			"--es-people": people = Array(value.split(","))
			"--es-focus": focus = value
			"--es-map": map_id = value
			"--es-out": out_dir = value
			"--es-times":
				for part: String in value.split(","): times.append(float(part))
			"--es-from": from_t = float(value)
			"--es-to": to_t = float(value)
			"--es-step": step = float(value)
			"--es-cam": cam = value
			"--es-size":
				var parts: PackedStringArray = value.split("x")
				if parts.size() == 2: size = Vector2i(int(parts[0]), int(parts[1]))
	_run.call_deferred()


func _run() -> void :
	var headless: bool = DisplayServer.get_name() == "headless"
	DirAccess.make_dir_recursive_absolute(out_dir)
	if not headless: get_window().size = size
	for i: int in range(6): await get_tree().process_frame
	if people.is_empty(): people = PaperData.NAMES.duplicate()
	if focus.is_empty(): focus = str(people[0])
	world.gallery.open()
	if map_id != "school": world._rebuild_map(map_id)
	for i: int in range(3): await get_tree().process_frame
	var started: int = Time.get_ticks_msec()
	world.gallery.play_entry({"id": "shots", "title": "shots", "category": "fins", "kind": film_kind, "participants": people, "focus": focus, "duration": PaperCinema.duration_for(film_kind, people), "description": ""})
	world.gallery.playing = false
	world.ui.hide_gallery_transport()
	var film: PaperCinema = world.film
	var duration: float = film.duration
	print("ESCAPE_SHOTS kind=%s people=%s duration=%.2f build_ms=%d" % [film_kind, ",".join(PackedStringArray(people)), duration, Time.get_ticks_msec() - started])
	if times.is_empty():
		var last: float = duration if to_t < 0.0 else minf(to_t, duration)
		var t: float = from_t
		while t <= last + 0.0001:
			times.append(t);t += step
	if headless:
		var clock: int = Time.get_ticks_msec()
		for t: float in times: world.gallery.seek(t)
		print("ESCAPE_SHOTS seek_ms=%d" % (Time.get_ticks_msec() - clock))
		print("ESCAPE_SHOTS_DONE")
		get_tree().quit()
		return
	var index: int = 0
	for t: float in times:
		for k: int in range(2):
			world.gallery.seek(t)
			await get_tree().process_frame
		_debug_camera(film)
		RenderingServer.force_draw()
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png("%s/f%03d_%05.2f.png" % [out_dir, index, t])
		index += 1
	print("ESCAPE_SHOTS_DONE frames=%d" % index)
	get_tree().quit()


func _process(_delta: float) -> void :
	if world != null and is_instance_valid(world.get("film")) and not (world.film as PaperCinema).takes.is_empty(): _debug_camera(world.film)


func _debug_camera(film: PaperCinema) -> void :
	if cam == "film" or film.takes.is_empty(): return
	var camera: Camera3D = world.camera
	var parts: PackedStringArray = cam.split(":")
	var mode: String = parts[0]
	var who: int = clampi(int(parts[1]) if parts.size() > 1 else 0, 0, film.takes.size() - 1)
	var visual: PaperVisual = film.takes[who].visual
	var target: Vector3 = visual.global_position + Vector3.UP * 0.85
	var eye: Vector3
	match mode:
		"side": eye = target + film.right * 4.6 + Vector3.UP * 0.15
		"front": eye = target + film.forward * 4.6 + Vector3.UP * 0.25
		"back": eye = target - film.forward * 4.6 + Vector3.UP * 0.4
		"wide":
			var door: Vector3 = film.finish - film.forward * 3.0
			target = door - film.forward * 3.0 + Vector3.UP * 1.0
			eye = target + film.right * 9.5 + Vector3.UP * 0.6
		"door":
			var door: Vector3 = film.finish - film.forward * 3.0
			target = door - film.forward * 2.5 + Vector3.UP * 1.0
			eye = door + film.forward * 6.0 + Vector3.UP * 1.6 + film.right * 0.8
		_: return
	camera.global_position = eye
	camera.look_at(target)
	camera.fov = 34.0 if mode in ["side", "front", "back"] else 50.0
