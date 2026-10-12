extends Node

# Capture de la carte depuis des points de vue fixes (repérage des plans).
# godot --rendering-driver opengl3 -- --tool view_capture --view "0,1.7,56>0,2,44" --view "..." --out /tmp/x [--view-map school]

var world: Node
var views: Array = []
var out_dir: String = "/tmp/view_capture"
var map_id: String = "school"

func setup(owner: Node) -> void :
	world = owner
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		var value: String = args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--view":
				var parts: PackedStringArray = value.split(">")
				views.append([_vec(parts[0]), _vec(parts[1]), float(parts[2]) if parts.size() > 2 else 50.0])
			"--out": out_dir = value
			"--view-map": map_id = value
	_run.call_deferred()

func _vec(text: String) -> Vector3:
	var p: PackedStringArray = text.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))

func _run() -> void :
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_window().size = Vector2i(1280, 720)
	for i: int in range(6): await get_tree().process_frame
	world.gallery.open()
	if map_id != "school": world._rebuild_map(map_id)
	world.film.stop();world.ui.hide_film();world.ui.page.hide();world.ui.overlay.hide()
	print("ANCHOR ", world.school.cinematic_anchor, " EXIT ", world.school.cinematic_exit, " ESCAPE ", world.school.escape_position)
	var index: int = 0
	if "--auto-exit" in OS.get_cmdline_user_args():
		var exit: Vector3 = world.school.cinematic_exit
		var forward: Vector3 = exit - world.school.cinematic_anchor;forward.y = 0;forward = forward.normalized()
		var side: Vector3 = Vector3.UP.cross(forward).normalized()
		views.append([exit + forward * 12.0 + Vector3.UP * 1.3, exit + Vector3.UP * 1.6, 60.0])
		views.append([exit + forward * 7.0 + side * 5.0 + Vector3.UP * 2.0, exit + forward * 2.0 + Vector3.UP * 1.0, 60.0])
		views.append([exit - forward * 3.0 + Vector3.UP * 2.0, exit + forward * 6.0 + Vector3.UP * 1.0, 60.0])
	for view: Array in views:
		world.camera.position = view[0];world.camera.look_at(view[1]);world.camera.fov = float(view[2])
		for k: int in range(3): await get_tree().process_frame
		RenderingServer.force_draw()
		await RenderingServer.frame_post_draw
		var path: String = "%s/v%02d.png" % [out_dir, index]
		get_viewport().get_texture().get_image().save_png(path)
		print("FRAME ", path)
		index += 1
	get_tree().quit()
