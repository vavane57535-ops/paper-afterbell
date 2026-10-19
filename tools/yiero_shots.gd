extends Node

# Planches de contrôle de Yiero (PaperYiero, yiero_model.gd), rendues dans la vraie dimension du prologue.
#   -- --tool yiero_shots --ys-mode sheet [--ys-out DIR] [--ys-views "front,three,profile,..."] [--ys-pose NOM]
#        modèle seul, temps du film figé à 60,5 s : vues face, trois-quarts, profil, gros plans visage,
#        contre-plongée, mains. --ys-pose : neutral (défaut), roar, squint, fury, grab, laugh, closed.
#   -- --tool yiero_shots --ys-mode film --ys-times "36.5,39.2" [--ys-out DIR]
#        images du prologue à ces instants (le film est déterministe : saut puis 2 images).
#   -- --tool yiero_shots --ys-mode film --ys-ranges "34-40:0.25,46-52:0.5"
#        lecture continue de chaque tranche avec une image tous les N s (planches d'animation).
#   -- --tool yiero_shots --ys-mode stats   nombre de triangles et de matériaux du modèle (sans rendu).
# Lancer avec : xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --fixed-fps 30 -- --tool yiero_shots ...

const VIEWS: Dictionary = {
	"front": [Vector3(0, 33, 150), Vector3(0, 21, 0), 38.0],
	"three": [Vector3(104, 42, 104), Vector3(0, 21, 0), 38.0],
	"profile": [Vector3(150, 30, -4), Vector3(0, 21, -4), 38.0],
	"back": [Vector3(-90, 48, -110), Vector3(0, 22, 0), 38.0],
	"face": [Vector3(0, 32, 52), Vector3(0, 28, 6), 42.0],
	"face34": [Vector3(30, 36, 40), Vector3(0, 28, 6), 44.0],
	"mouth": [Vector3(4, 22, 34), Vector3(0, 22, 8), 44.0],
	"eye": [Vector3(-9, 37, 22), Vector3(-7.4, 35.5, 7.8), 34.0],
	"low": [Vector3(-3, 1.6, 66), Vector3(0, 30, 0), 62.0],
	"hand": [Vector3(-52, 14, 78), Vector3(-30, 4, 44), 40.0],
	"silhouette": [Vector3(0, 8, 210), Vector3(0, 24, 0), 30.0],
}

var world: Node
var mode: String = "sheet"
var out_dir: String = "user://yiero_shots"
var times: Array[float] = []
var spans: Array[Vector3] = []
var views: PackedStringArray = PackedStringArray(["front", "three", "profile", "face", "face34", "low", "hand", "eye"])
var pose_name: String = "neutral"
var _cam: Camera3D
var _freeze: float = -1.0
var _override: bool = false
var _t: float = 0.0

func setup(owner: Node) -> void :
	world = owner
	process_priority = 1000
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		if i + 1 >= args.size(): continue
		var value: String = args[i + 1]
		match args[i]:
			"--ys-mode": mode = value
			"--ys-out": out_dir = value
			"--ys-pose": pose_name = value
			"--ys-views": views = value.split(",")
			"--ys-times":
				for part: String in value.split(","): times.append(float(part))
			"--ys-ranges":
				for part: String in value.split(","):
					var step: float = 0.25
					var span: String = part
					if part.contains(":"):
						step = float(part.get_slice(":", 1));span = part.get_slice(":", 0)
					spans.append(Vector3(float(span.get_slice("-", 0)), float(span.get_slice("-", 1)), step))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir) if out_dir.begins_with("user://") else out_dir)
	_run.call_deferred()

func _frames(count: int) -> void :
	for i: int in range(count): await get_tree().process_frame

func _save(label: String) -> void :
	await RenderingServer.frame_post_draw
	var image: Image = world.get_viewport().get_texture().get_image()
	var path: String = out_dir.path_join(label + ".png")
	image.save_png(path)
	print("YS_CAPTURE ", path)

func _run() -> void :
	await _frames(3)
	match mode:
		"sheet": await _sheet()
		"film": await _film()
		"stats": _stats()
	get_tree().quit()

func _film_node() -> Node:
	if world.phase != "prologue": world.play_prologue()
	return world.prologue

func _film() -> void :
	var film: Node = _film_node()
	await _frames(2)
	for t: float in times:
		film.clock = t
		await _frames(2)
		await _save("f_%06.2f" % t)
	for span: Vector3 in spans:
		film.clock = span.x
		await _frames(1)
		var next: float = span.x
		while float(film.clock) <= span.y + 0.001 and world.phase == "prologue":
			await get_tree().process_frame
			if float(film.clock) + 0.001 >= next:
				await _save("r_%06.2f" % float(film.clock))
				next += span.z

func _process(_delta: float) -> void :
	if _freeze < 0.0 or not _override: return
	var film: Node = world.prologue
	film.clock = _freeze
	_t += 1.0 / 30.0
	_pose_model(film.yiero)
	if is_instance_valid(_cam): _cam.make_current()

func _pose_model(y: Node3D) -> void :
	var xf: Transform3D = y.global_transform
	y.rise = 1.0;y.reveal = 1.0;y.eye_open = 1.0;y.eye_glow = 1.0;y.grin = 1.0;y.grin_wide = 1.0
	y.jaw = 0.22;y.lean = 0.0;y.head_pitch = 0.0;y.head_roll = 0.0;y.head_yaw = 0.0;y.tremble = 0.0
	y.hurt = 0.0;y.fury = 0.0;y.squint = 0.0;y.wind = 1.0;y.tooth_chip = 0.0;y.clock = 60.0 + _t
	y.hand_target[0] = xf * Vector3(-30, 6, 46);y.hand_target[1] = xf * Vector3(30, 5.5, 45)
	y.hand_curl[0] = 0.3;y.hand_curl[1] = 0.3
	y.look_target = xf * Vector3(0, 2, 90)
	match pose_name:
		"roar":
			y.jaw = 1.05;y.fury = 0.8;y.head_pitch = 0.22;y.lean = 6.0;y.wind = 3.0
		"squint":
			y.squint = 1.0;y.head_pitch = -0.12;y.head_roll = 0.18;y.hurt = 0.3
		"fury":
			y.fury = 1.0;y.eye_glow = 1.7;y.grin_wide = 1.25;y.jaw = 0.4
		"grab":
			y.hand_target[0] = xf * Vector3(-4.0, 23.0, 46.0);y.hand_curl[0] = 1.05;y.jaw = 0.55
		"laugh":
			y.grin_wide = 1.25;y.jaw = 0.3 + 0.12 * absf(sin(_t * 15.0));y.head_pitch = -0.3;y.head_roll = -0.15
		"closed":
			y.grin = 0.0;y.jaw = 0.0;y.reveal = 0.0
		"half":
			y.grin = 0.45;y.jaw = 0.0;y.reveal = 0.0
	if y.has_method("set"):
		for key: String in ["breath", "tilt"]:
			if key in y: y.set(key, y.get(key))
	y.pose()

func _sheet() -> void :
	var film: Node = _film_node()
	await _frames(2)
	_freeze = 60.5
	film.clock = _freeze
	await _frames(2)
	_cam = Camera3D.new();_cam.name = "YieroSheetCamera";_cam.far = 4000.0
	world.add_child(_cam)
	_override = true
	await _frames(2)
	for view: String in views:
		if not VIEWS.has(view): continue
		var spec: Array = VIEWS[view]
		var xf: Transform3D = film.yiero.global_transform
		_cam.fov = float(spec[2])
		_cam.global_position = xf * (spec[0] as Vector3)
		_cam.look_at(xf * (spec[1] as Vector3), Vector3.UP)
		_cam.make_current()
		await _frames(2)
		await _save("s_%s_%s" % [pose_name, view])

func _stats() -> void :
	var film: Node = _film_node()
	var y: Node3D = film.yiero
	var tris: int = 0
	var meshes: int = 0
	var stack: Array[Node] = [y]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child: Node in node.get_children(): stack.append(child)
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var mesh: Mesh = (node as MeshInstance3D).mesh
			meshes += 1
			for s: int in range(mesh.get_surface_count()):
				var arrays: Array = mesh.surface_get_arrays(s)
				var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var count: int = index.size() / 3 if index.size() > 0 else verts.size() / 3
				tris += count
				print("YS_MESH ", node.name, " surface ", s, " tris ", count)
	print("YS_STATS meshes ", meshes, " triangles ", tris)
