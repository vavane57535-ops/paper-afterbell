extends Node
# Labo des clips des victoires LMS (0.17) : joue UN clip sur un plateau éclairé
# (sans le film, sans la pluie) et le capture depuis des caméras témoins, aux
# instants du film (le "at" du clip est retranché). Sert à régler les poses
# avant de juger le plan dans le film (tools/film_victory_lab.gd).
#   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 --resolution 640x400 -- \
#     --tool fv_clip_lab --clip fv_ashura_rain --who Ashura --from 3.3 --to 4.0 --step 0.1 --cams side,34 --dir /tmp/x
# Options : --times t1,t2… · --from/--to/--step · --cams front,back,side,left,34,34l,top,low
#           --dist <m> (défaut 2.6) · --h <m> (hauteur visée, défaut 0.8) · --fov <deg>
#           --path x0,z0,t0,x1,z1,t1 : déplace le corps en ligne droite (mètres, axe z = devant)

const AnimLibrary = preload("res://anim_library.gd")
const FILM_STYLE: Dictionary = {"contra": 0.0, "shift_rate": 0.0, "idle_sway": 0.0, "idle_bounce": 0.0, "look_rate": 0.0}

var world: Node
var clip_name: String = ""
var who: String = "Ashura"
var times: Array[float] = []
var cams: PackedStringArray = PackedStringArray(["34"])
var out_dir: String = "/tmp/fv_clip"
var distance: float = 2.6
var aim: float = 0.8
var fov: float = 40.0
var path: PackedFloat32Array = PackedFloat32Array()


func setup(game_world: Node) -> void :
	world = game_world
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var from: float = -1.0
	var to: float = -1.0
	var step: float = 0.1
	for i: int in range(args.size()):
		var value: String = args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--clip": clip_name = value
			"--who": who = value
			"--times":
				for item: String in value.split(",", false): times.append(float(item))
			"--from": from = float(value)
			"--to": to = float(value)
			"--step": step = float(value)
			"--cams": cams = value.split(",", false)
			"--dir": out_dir = value
			"--dist": distance = float(value)
			"--h": aim = float(value)
			"--fov": fov = float(value)
			"--path":
				for item: String in value.split(",", false): path.append(float(item))
	if from >= 0.0 and to >= from:
		var t: float = from
		while t <= to + 0.0001:
			times.append(snappedf(t, 0.001))
			t += step
	times.sort()
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _process(_delta: float) -> void :
	if get_viewport().disable_3d: get_viewport().disable_3d = false


func _root_at(t: float) -> Vector3:
	if path.size() < 6: return Vector3.ZERO
	var u: float = clampf((t - path[2]) / maxf(0.001, path[5] - path[2]), 0.0, 1.0)
	return Vector3(path[0], 0.0, -path[1]).lerp(Vector3(path[3], 0.0, -path[4]), u)


func _run() -> void :
	for i: int in range(20): await get_tree().process_frame
	while str(world.phase) != "menu": await get_tree().process_frame
	for node: Node in world.get_children():
		if node is CanvasLayer: (node as CanvasLayer).visible = false
	# l'écran titre coupe la 3D de la fenêtre principale (ui.gd, fond de menu)
	get_viewport().disable_3d = false
	set_process(true)
	var stage: Node3D = Node3D.new()
	stage.position = Vector3(0, 400, 0)
	add_child(stage)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.6, 0)
	sun.light_energy = 1.25
	stage.add_child(sun)
	var back: DirectionalLight3D = DirectionalLight3D.new()
	back.rotation = Vector3(-0.4, 2.8, 0)
	back.light_energy = 0.5
	stage.add_child(back)
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(40, 40)
	floor_mesh.mesh = plane
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("8f8a80")
	floor_mesh.material_override = material
	stage.add_child(floor_mesh)
	# repères au sol tous les 50 cm, pour juger les glissements de pieds
	for k: int in range(-8, 9):
		for axis: int in range(2):
			var line: MeshInstance3D = MeshInstance3D.new()
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(8.0, 0.004, 0.012) if axis == 0 else Vector3(0.012, 0.004, 8.0)
			line.mesh = box
			var ink: StandardMaterial3D = StandardMaterial3D.new()
			ink.albedo_color = Color("5c584f")
			line.material_override = ink
			line.position = Vector3(0, 0.002, k * 0.5) if axis == 0 else Vector3(k * 0.5, 0.002, 0)
			stage.add_child(line)
	var visual: PaperVisual = PaperVisual.new()
	visual.lod_enabled = false
	stage.add_child(visual)
	visual.setup(who)
	var style: Variant = visual.get("_style")
	if style is Dictionary:
		for key: String in FILM_STYLE: (style as Dictionary)[key] = FILM_STYLE[key]
	visual.fidgets = false
	visual.set_combat_state({"grounded": false})
	var source: Dictionary = AnimLibrary.source(clip_name)
	if source.is_empty():
		push_error("FV_CLIP clip introuvable " + clip_name)
		get_tree().quit()
		return
	var at: float = float(source.get("at", 0.0))
	var camera: Camera3D = Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	camera.fov = fov
	visual.animate(1.0 / 30.0, Vector3.ZERO, false, false)
	visual.play(clip_name)
	var clock: float = at
	var previous: Vector3 = _root_at(clock)
	for t: float in times:
		while clock < t - 0.0001:
			var dt: float = minf(1.0 / 30.0, t - clock)
			clock += dt
			var root: Vector3 = _root_at(clock)
			visual.position = root
			visual.animate(dt, (root - previous) / dt, false, false)
			previous = root
		var center: Vector3 = stage.position + visual.position + Vector3.UP * aim
		for cam: String in cams:
			var dir: Vector3 = Vector3(0.75, 0.25, -0.75)
			match cam:
				"front": dir = Vector3(0, 0.12, -1)
				"back": dir = Vector3(0, 0.15, 1)
				"side": dir = Vector3(1, 0.08, 0)
				"left": dir = Vector3(-1, 0.08, 0)
				"34": dir = Vector3(0.75, 0.2, -0.75)
				"34l": dir = Vector3(-0.75, 0.2, -0.75)
				"34b": dir = Vector3(0.75, 0.25, 0.75)
				"top": dir = Vector3(0.05, 1.0, -0.3)
				"low": dir = Vector3(0.8, -0.12, -0.6)
			camera.global_transform = Transform3D(Basis.IDENTITY, center + dir.normalized() * distance).looking_at(center, Vector3.UP)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var image: Image = get_viewport().get_texture().get_image()
			if image: image.save_png(out_dir.path_join("%s_%s_%05.2f.png" % [who, cam, t]))
	print("FV_CLIP done ", clip_name, " at=", at, " ", times.size(), " instants")
	get_tree().quit()
