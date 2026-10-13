extends Node
# Labo des victoires LMS (0.17) : captures précises du film, avec des caméras
# témoins pour vérifier les contacts (main sur l'avant-bras, griffe, fusil),
# les appuis (pieds qui ne glissent pas) et les silhouettes.
#   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 --fixed-fps 30 -- \
#     --tool film_victory_lab --lab Usayuko --lab-times 3.5,3.62 --lab-cams film,side --lab-dir /tmp/x
# Options : --lab <nom> · --lab-times t1,t2… ou --lab-from/--lab-to/--lab-step
#           --lab-cams film,side,front,back,top,wide (une image par caméra et par instant)
#           --lab-focus s|a|mid (acteur cadré par les caméras témoins, défaut mid)
#           --lab-dist <m> (distance des caméras témoins, défaut 3.2) · --lab-h <m> (hauteur visée)
#           --lineup : les sept personnages au repos, de face et de profil

var world: Node
var person: String = "Usayuko"
var times: Array[float] = []
var cams: PackedStringArray = PackedStringArray(["film"])
var out_dir: String = "/tmp/lab"
var focus: String = "mid"
var distance: float = 3.2
var aim_height: float = 1.0
var lineup: bool = false
var _override: Transform3D
var _override_fov: float = 40.0
var _overriding: bool = false


func setup(game_world: Node) -> void :
	world = game_world
	process_priority = 1000
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var from: float = -1.0
	var to: float = -1.0
	var step: float = 0.1
	for i: int in range(args.size()):
		var value: String = args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--lab": person = value
			"--lab-times":
				for item: String in value.split(",", false): times.append(float(item))
			"--lab-from": from = float(value)
			"--lab-to": to = float(value)
			"--lab-step": step = float(value)
			"--lab-cams": cams = value.split(",", false)
			"--lab-dir": out_dir = value
			"--lab-focus": focus = value
			"--lab-dist": distance = float(value)
			"--lab-h": aim_height = float(value)
			"--lineup": lineup = true
	if from >= 0.0 and to >= from:
		var t: float = from
		while t <= to + 0.0001:
			times.append(snappedf(t, 0.001))
			t += step
	times.sort()
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _process(_delta: float) -> void :
	if _overriding and is_instance_valid(world.camera):
		world.camera.global_transform = _override
		world.camera.fov = _override_fov


func _run() -> void :
	for i: int in range(20): await get_tree().process_frame
	while str(world.phase) != "menu": await get_tree().process_frame
	if lineup:
		await _lineup()
		get_tree().quit()
		return
	world.gallery.open()
	await get_tree().process_frame
	var entry: Dictionary = {}
	for item: Dictionary in world.gallery.entries:
		if str(item.id) == "lms_win_" + person: entry = item
	if entry.is_empty():
		push_error("LAB film introuvable " + person)
		get_tree().quit()
		return
	world.gallery.play_entry(entry)
	world.ui.hide_gallery_transport()
	if not "--lab-flash" in OS.get_cmdline_user_args():
		# flashs et éclairs coupés : la caméra témoin doit voir les corps
		world.film.victory.get("_flashes").clear()
		world.film.victory.get("_lightning").clear()
	await get_tree().process_frame
	world.gallery.toggle_pause()
	for t: float in times:
		world.gallery.seek(t)
		await get_tree().process_frame
		for cam: String in cams:
			_place(cam)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var image: Image = get_viewport().get_texture().get_image()
			if image: image.save_png(out_dir.path_join("%s_%s_%05.2f.png" % [person, cam, t]))
			_overriding = false
		_report(t)
	print("LAB done ", person, " ", times.size(), " instants")
	get_tree().quit()


func _report(t: float) -> void :
	var film: Variant = world.film
	var line: PackedStringArray = []
	for take: Variant in film.takes:
		var visual: PaperVisual = take.visual
		var feet: Array = []
		for socket: String in ["foot_l", "foot_r"]:
			var p: Vector3 = visual.socket_position(socket)
			feet.append("%s(%.3f,%.3f,%.3f)" % [socket, p.x, p.y, p.z])
		line.append("%s root(%.3f,%.3f,%.3f) %s hand_r%s" % [take.person, visual.global_position.x, visual.global_position.y, visual.global_position.z, " ".join(PackedStringArray(feet)), str(visual.socket_position("hand_r").snappedf(0.001))])
	if "--lab-state" in OS.get_cmdline_user_args():
		for take: Variant in film.takes:
			var v: PaperVisual = take.visual
			line.append("%s action=%s left=%.2f stunned=%s body=%s chest=%s life=%s state=%s" % [take.person, str(v.get("_action")), float(v.get("_action_time")), str(take.stunned), str((v.get("_body") as Node3D).rotation.snappedf(0.01)), str((v.get("_chest") as Node3D).rotation.snappedf(0.01)), str(v.get("_life_state")), str(take.state)])
			line.append("%s hips_y=%.3f root_y=%.3f clip=%s" % [take.person, (v.get("_body") as Node3D).global_position.y, v.global_position.y, str(v.get("_action"))])
	var camera: Camera3D = world.camera
	line.append("cam(%.2f,%.2f,%.2f) focus(%.2f,%.2f,%.2f) shot=%d" % [camera.global_position.x, camera.global_position.y, camera.global_position.z, film.camera_focus.x, film.camera_focus.y, film.camera_focus.z, int(film.last_shot)])
	print("LAB t=%.2f %s" % [t, " | ".join(line)])


func _place(cam: String) -> void :
	if cam == "film":
		_overriding = false
		return
	var film: Variant = world.film
	var s_visual: Node3D = film.takes[0].visual
	var a_visual: Node3D = film.takes[film.alice_index].visual if film.alice_index >= 0 else s_visual
	var center: Vector3 = s_visual.global_position
	if focus == "a": center = a_visual.global_position
	elif focus == "mid": center = (s_visual.global_position + a_visual.global_position) * 0.5
	var forward: Vector3 = film.forward.rotated(Vector3.UP, float(film.victory.turn))
	var right: Vector3 = Vector3.UP.cross(forward).normalized() * -1.0
	var target: Vector3 = center + Vector3.UP * aim_height
	var eye: Vector3 = target
	match cam:
		"side": eye = target + right * distance
		"left": eye = target - right * distance
		"front": eye = target + forward * distance
		"back": eye = target - forward * distance
		"top": eye = target + Vector3.UP * distance * 1.4 + forward * 0.01
		"wide": eye = target + right * distance * 1.8 + Vector3.UP * 1.2 + forward * distance * 0.6
		"low": eye = target + right * distance * 0.8 + forward * distance * 0.5 + Vector3.DOWN * (aim_height - 0.25)
	_override = Transform3D(Basis.IDENTITY, eye).looking_at(target, Vector3.UP if cam != "top" else forward)
	_override_fov = 40.0
	_overriding = true
	world.camera.global_transform = _override
	world.camera.fov = _override_fov


func _lineup() -> void :
	var stage: Node3D = Node3D.new()
	stage.position = Vector3(0, 400, 0)
	add_child(stage)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation = Vector3(-0.7, 0.5, 0)
	sun.light_energy = 1.2
	stage.add_child(sun)
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(30, 30)
	floor_mesh.mesh = plane
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("8f8a80")
	floor_mesh.material_override = material
	stage.add_child(floor_mesh)
	var names: Array[String] = ["Simon", "Usayuko", "Ashura", "Lysia", "Elly", "Bleuette", "Alice"]
	for k: int in range(names.size()):
		var visual: PaperVisual = PaperVisual.new()
		visual.lod_enabled = false
		stage.add_child(visual)
		visual.setup(names[k])
		visual.position = Vector3(-4.5 + 1.5 * k, 0, 0)
		visual.animate(1.0 / 30.0, Vector3.ZERO, false, false)
	for node: Node in world.get_children():
		if node is CanvasLayer: (node as CanvasLayer).visible = false
	var camera: Camera3D = Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	for view: String in ["front", "side"]:
		var eye: Vector3 = stage.position + (Vector3(0, 1.1, 9.5) if view == "front" else Vector3(9.5, 1.1, 0.6))
		camera.global_transform = Transform3D(Basis.IDENTITY, eye).looking_at(stage.position + Vector3(0, 0.95, 0), Vector3.UP)
		camera.fov = 50.0 if view == "front" else 75.0
		for i: int in range(3): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		if image: image.save_png(out_dir.path_join("lineup_%s.png" % view))
