class_name PaperResultsView
extends SubViewportContainer



var portrait: PaperVisual
var camera: Camera3D
var scene: Node3D
var elapsed: float = 0
var grade: String = "C"
var person: String = ""
var _rim: OmniLight3D

func setup() -> void :
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(320, 330)
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(620, 650)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	scene = Node3D.new()
	viewport.add_child(scene)
	var env_node: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("9aa6c8")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env_node.environment = env
	scene.add_child(env_node)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-32, -28, 0)
	key.light_color = Color("f3dcc0")
	key.light_energy = 1.45
	scene.add_child(key)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, 150, 0)
	fill.light_color = Color("8fb9c9")
	fill.light_energy = 0.35
	scene.add_child(fill)
	_rim = OmniLight3D.new()
	_rim.position = Vector3(-1.6, 2.1, -1.4)
	_rim.light_color = Color("87c9c4")
	_rim.light_energy = 2.2
	_rim.omni_range = 5.0
	scene.add_child(_rim)
	var lilac: OmniLight3D = OmniLight3D.new()
	lilac.position = Vector3(1.7, 1.2, -1.2)
	lilac.light_color = Color("b7a0db")
	lilac.light_energy = 1.2
	lilac.omni_range = 4.5
	scene.add_child(lilac)

	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = 0.95
	disc.bottom_radius = 0.95
	disc.height = 0.01
	floor_mesh.mesh = disc
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.02, 0.02, 0.04, 0.55)
	floor_mesh.material_override = material
	floor_mesh.position.y = -0.01
	scene.add_child(floor_mesh)
	camera = Camera3D.new()
	camera.fov = 30
	scene.add_child(camera)
	camera.current = true

func present(row: Dictionary) -> void :
	grade = str(row.get("grade", "C"))
	elapsed = 0
	var next_person: String = str(row.get("character", "Simon"))
	if next_person != person:
		if is_instance_valid(portrait): portrait.queue_free()
		portrait = PaperVisual.new()
		scene.add_child(portrait)
		portrait.setup(next_person)
		portrait.rotation.y = PI
		person = next_person

	if _rim: _rim.light_color = Color("f2c46d") if grade in ["S", "A"] else Color("87c9c4") if grade in ["B", "C"] else Color("8d96b8")

func _process(delta: float) -> void :
	if not is_instance_valid(portrait): return
	elapsed += minf(delta, 0.05)


	portrait.set_result_reaction(grade, elapsed)
	var angle: float = sin(elapsed * 0.25) * 0.16
	camera.position = Vector3(sin(angle) * 3.9, 1.45 + sin(elapsed * 0.3) * 0.06, cos(angle) * 3.9)
	camera.look_at(Vector3(0, 1.0, 0))
