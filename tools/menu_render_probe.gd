extends Node

# Ce que le rendu Compatibility sait faire dans une SubViewport (flou de profondeur, halo,
# brouillard, ombres de projecteur) :
#   xvfb-run -a godot --rendering-driver opengl3 -- --tool menu_render_probe --out /tmp/x

var world: Node
var out_dir: String = "/tmp/menu_render_probe"
var layer_bits: int = 1

func setup(game_world: Node) -> void :
	world = game_world
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		if args[i] == "--out" and i + 1 < args.size(): out_dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _box(root: Node3D, size: Vector3, at: Vector3, color: Color, glow: float = 0.0) -> void :
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	mesh.material_override = mat
	mesh.position = at
	mesh.layers = layer_bits
	root.add_child(mesh)

func _run() -> void :
	for i: int in range(6): await get_tree().process_frame
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(640, 400)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var root: Node3D = Node3D.new()
	viewport.add_child(root)
	var camera: Camera3D = Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0, 1.4, 4.0)
	camera.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	camera.current = true
	var env_node: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("20202c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("404060")
	env_node.environment = env
	root.add_child(env_node)
	_box(root, Vector3(10, 0.1, 30), Vector3(0, -0.05, -10), Color("6a6a7a"))
	for i: int in range(8):
		_box(root, Vector3(0.6, 2.0, 0.6), Vector3(-2.0 + (i % 2) * 4.0, 1.0, 1.0 - i * 3.0), Color.from_hsv(i * 0.12, 0.5, 0.8))
	_box(root, Vector3(0.5, 0.5, 0.5), Vector3(0.0, 1.0, 0.0), Color("ffe0a0"), 4.0)
	var spot: SpotLight3D = SpotLight3D.new()
	spot.position = Vector3(1.5, 3.5, 2.0)
	spot.look_at_from_position(spot.position, Vector3(0, 0, 0), Vector3.UP)
	spot.spot_range = 10.0
	spot.spot_angle = 35.0
	spot.light_energy = 6.0
	spot.shadow_enabled = true
	root.add_child(spot)
	if "--layer" in OS.get_cmdline_user_args():
		layer_bits = 1 << 10
		for child: Node in root.get_children():
			if child is VisualInstance3D: (child as VisualInstance3D).layers = layer_bits
		camera.cull_mask = layer_bits
	var omni: OmniLight3D = OmniLight3D.new()
	omni.position = Vector3(-2.0, 1.5, 1.5)
	omni.light_color = Color(1, 0.3, 0.3)
	omni.light_energy = 3.0
	omni.omni_range = 4.0
	root.add_child(omni)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.light_color = Color(0.3, 1.0, 0.3)
	sun.light_energy = 0.6
	root.add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, Vector3(0.5, -0.6, -0.3), Vector3.UP)
	await _shot(viewport, "0_base")
	spot.shadow_enabled = false
	await _shot(viewport, "0b_noshadow")
	env.glow_enabled = true
	env.glow_intensity = 1.2
	env.glow_bloom = 0.2
	await _shot(viewport, "1_glow")
	env.fog_enabled = true
	env.fog_light_color = Color("20202c")
	env.fog_density = 0.08
	await _shot(viewport, "2_fog")
	var attributes: CameraAttributesPractical = CameraAttributesPractical.new()
	attributes.dof_blur_far_enabled = true
	attributes.dof_blur_far_distance = 6.0
	attributes.dof_blur_far_transition = 3.0
	attributes.dof_blur_near_enabled = true
	attributes.dof_blur_near_distance = 2.0
	attributes.dof_blur_amount = 0.3
	camera.attributes = attributes
	await _shot(viewport, "3_dof")
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.6
	await _shot(viewport, "4_tonemap_adjust")
	print("PROBE fin")
	get_tree().quit()

func _shot(viewport: SubViewport, tag: String) -> void :
	for i: int in range(3): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(out_dir.path_join(tag + ".png"))
	print("PROBE ", tag)
