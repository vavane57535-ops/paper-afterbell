extends Node3D
class_name PaperCinemaProps





var origin: Vector3
var axis_right: Vector3
var axis_forward: Vector3
var film: String
var door: Node3D
var grenade: Node3D
var drone: Node3D
var rotors: Array[Node3D] = []
var _mat_cache: Dictionary = {}

var reduce_flashes: bool = false

func setup(anchor: Vector3, right: Vector3, forward: Vector3, kind: String, names: Array[String]) -> void :
	origin = anchor;axis_right = right;axis_forward = forward;film = kind
	if kind == "intro_alice": _room()
	if "Simon" in names and kind != "intro_survivors":
		grenade = _grenade()
		grenade.visible = false
	if "Ashura" in names and kind != "intro_survivors":
		drone = _drone()
		drone.visible = false


func set_door(open: float) -> void :
	if door: door.rotation.y = -1.92 * clampf(open, 0.0, 1.0)

func place_grenade(at: Vector3, time: float, shown: bool) -> void :
	if not grenade: return
	grenade.visible = shown
	if not shown: return
	grenade.position = at
	grenade.rotation = Vector3(time * 8.5, time * 5.1, 0.3)


func place_drone(at: Vector3, heading: Vector3, time: float, tumble: float, shown: bool) -> void :
	if not drone: return
	drone.visible = shown
	if not shown: return
	drone.position = at
	var yaw: float = atan2( - heading.x, - heading.z) if heading.length_squared() > 0.0001 else 0.0
	drone.rotation = Vector3(0.07 + 0.9 * tumble, yaw + 3.0 * tumble, -0.14 + 1.4 * tumble)
	for rotor: Node3D in rotors: rotor.rotation.y = time * 70.0 * (1.0 - tumble)

func _room() -> void :
	var set_root: Node3D = Node3D.new();add_child(set_root);set_root.position = origin
	set_root.basis = Basis(axis_right, Vector3.UP, axis_forward)
	_box(set_root, Vector3(0, -0.15, 1), Vector3(12, 0.3, 20), Color("171721"), true)
	_box(set_root, Vector3(0, 4.1, -3), Vector3(9, 0.3, 12), Color("101017"), true)
	_box(set_root, Vector3(-4.25, 2, 0), Vector3(5.5, 4, 0.28), Color("525366"), true)
	_box(set_root, Vector3(4.25, 2, 0), Vector3(5.5, 4, 0.28), Color("525366"), true)
	_box(set_root, Vector3(0, 3.72, 0), Vector3(3.0, 0.57, 0.28), Color("4b4c5e"), true)
	_box(set_root, Vector3(-5.5, 2, 2), Vector3(0.25, 4, 16), Color("353746"), true)
	_box(set_root, Vector3(5.5, 2, 2), Vector3(0.25, 4, 16), Color("353746"), true)
	_box(set_root, Vector3(0, 2, -7), Vector3(11, 4, 0.3), Color("020205"), true)



	var void_material: StandardMaterial3D = StandardMaterial3D.new()
	void_material.albedo_color = Color("010103");void_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for side: int in [-1, 1]:
		var inner: MeshInstance3D = _box(set_root, Vector3(side * 5.2, 2, -3.5), Vector3(0.2, 4.1, 7.1), Color.BLACK, true)
		inner.material_override = void_material
	var back: MeshInstance3D = _box(set_root, Vector3(0, 2, -6.85), Vector3(10.5, 4.1, 0.15), Color.BLACK, true);back.material_override = void_material
	var ceiling: MeshInstance3D = _box(set_root, Vector3(0, 4.0, -3.5), Vector3(10.5, 0.1, 7), Color.BLACK, true);ceiling.material_override = void_material
	for side: int in [-1, 1]:
		_box(set_root, Vector3(side * 1.48, 1.72, 0.08), Vector3(0.14, 3.55, 0.26), Color("8a8997"), true)
	_box(set_root, Vector3(0, 3.47, 0.08), Vector3(3.1, 0.16, 0.26), Color("8a8997"), true)
	door = Node3D.new();set_root.add_child(door);door.position = Vector3(-1.39, 0, 0)
	_box(door, Vector3(1.39, 1.71, 0), Vector3(2.76, 3.42, 0.18), Color("4f506d"), true)
	for y: float in [0.55, 1.55, 2.6]: _box(door, Vector3(1.39, y, 0.11), Vector3(2.3, 0.78, 0.055), Color("45465f"), false)
	_box(door, Vector3(2.52, 1.38, 0.15), Vector3(0.11, 0.09, 0.14), Color("aaa4a2"), false)
	var sign: Node3D = Node3D.new();door.add_child(sign);sign.position = Vector3(1.37, 2.57, 0.16);sign.rotation.z = -0.055
	_box(sign, Vector3.ZERO, Vector3(1.75, 0.56, 0.025), Color("d5d0c5"), false)
	_label(sign, "Alice’s room", Vector3(0, 0.06, 0.02), 0.0041, Color("23222c"), 42)
	_label(sign, "! !", Vector3(0, -0.13, 0.02), 0.0033, Color("542c37"), 36)
	_label(door, "DO NOT OPEN", Vector3(1.4, 0.65, 0.18), 0.0038, Color("cac5cd"), 36)
	for i: int in range(9):
		var scratch: MeshInstance3D = _box(door, Vector3(0.38 + fmod(i * 0.38, 2.1), 1.0 + fmod(i * 0.27, 1.2), 0.155), Vector3(0.016, 0.45 + fmod(i * 0.13, 0.3), 0.012), Color("211f32"), false)
		scratch.rotation.z = -0.35 + 0.12 * (i % 3)
	for i: int in range(14):
		var side: float = -1 if i % 2 == 0 else 1
		var book: MeshInstance3D = _box(set_root, Vector3(side * (2.1 + fmod(i * 0.53, 2.4)), 0.06 + i % 2 * 0.04, 0.9 + fmod(i * 0.63, 4.6)), Vector3(0.36, 0.08, 0.55), Color.from_hsv(fmod(i * 0.18, 1), 0.25, 0.4), false)
		book.rotation.y = i * 1.37
	for i: int in range(12):
		var strip: MeshInstance3D = _box(set_root, Vector3((-1 if i % 2 == 0 else 1) * (2.0 + fmod(i * 0.43, 2.8)), 0.8 + fmod(i * 0.77, 2.4), 0.165), Vector3(0.015, 0.5, 0.014), Color("777584"), false)
		strip.rotation.z = -0.45
	var red: OmniLight3D = OmniLight3D.new();set_root.add_child(red);red.position = Vector3(0, 0.4, -2.1);red.light_color = Color("a91b2c");red.light_energy = 2.2;red.omni_range = 5

	for i: int in range(5): _box(set_root, Vector3(-2.6 + i * 1.3, 0.012, -2.4), Vector3(0.018, 0.01, 6.2), Color("6a1824"), false)

func _grenade() -> Node3D:
	var body: Node3D = Node3D.new();add_child(body)
	var mesh: MeshInstance3D = MeshInstance3D.new();body.add_child(mesh)
	var cylinder: CylinderMesh = CylinderMesh.new();cylinder.top_radius = 0.085;cylinder.bottom_radius = 0.085;cylinder.height = 0.23;cylinder.radial_segments = 16
	mesh.mesh = cylinder;mesh.material_override = _material(Color("9b9fa4"))
	_box(body, Vector3(0, 0.14, 0), Vector3(0.055, 0.045, 0.08), Color("292b36"), false)
	return body

func _drone() -> Node3D:
	var body: Node3D = Node3D.new();add_child(body)
	_box(body, Vector3.ZERO, Vector3(0.29, 0.1, 0.22), Color("292637"), false)
	_box(body, Vector3(0, 0.065, 0), Vector3(0.18, 0.025, 0.15), Color("8055b7"), false)
	for sx: int in [-1, 1]:
		for sz: int in [-1, 1]:
			var arm: MeshInstance3D = _box(body, Vector3(sx * 0.15, 0, sz * 0.15), Vector3(0.27, 0.035, 0.04), Color("474555"), false);arm.rotation.y = - sx * sz * 0.7
			var rotor: Node3D = Node3D.new();body.add_child(rotor);rotor.position = Vector3(sx * 0.26, 0.06, sz * 0.23);rotors.append(rotor)
			_box(rotor, Vector3.ZERO, Vector3(0.28, 0.01, 0.028), Color("a9a2b8"), false)
			_box(rotor, Vector3.ZERO, Vector3(0.028, 0.01, 0.28), Color("a9a2b8"), false)
	return body

func _label(parent: Node3D, text_value: String, location: Vector3, pixel: float, color: Color, font_size: int) -> void :
	var label: Label3D = Label3D.new();parent.add_child(label);label.text = text_value;label.position = location;label.pixel_size = pixel;label.font_size = font_size;label.modulate = color;label.outline_size = 0;label.no_depth_test = false

func _material(color: Color) -> StandardMaterial3D:
	var key: String = color.to_html()
	if _mat_cache.has(key): return _mat_cache[key]
	var mat: StandardMaterial3D = StandardMaterial3D.new();mat.albedo_color = color;mat.roughness = 0.78;_mat_cache[key] = mat;return mat

func _box(parent: Node3D, location: Vector3, size: Vector3, color: Color, solid: bool) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new();parent.add_child(node);node.position = location
	var box: BoxMesh = BoxMesh.new();box.size = size;node.mesh = box;node.material_override = _material(color)
	if solid:
		var body: StaticBody3D = StaticBody3D.new();node.add_child(body);body.collision_layer = 1;body.collision_mask = 0
		var collision: CollisionShape3D = CollisionShape3D.new();body.add_child(collision); var shape: BoxShape3D = BoxShape3D.new();shape.size = size;collision.shape = shape
	return node

func _local(value: Vector3) -> Vector3: return axis_right * value.x + Vector3.UP * value.y + axis_forward * value.z
