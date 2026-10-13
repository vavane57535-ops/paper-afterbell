extends Node3D
class_name PaperSchool

var spawn_points: Array[Vector3] = [Vector3(-5, 0.1, 29), Vector3(0, 0.1, 29), Vector3(5, 0.1, 29), Vector3(-5, 0.1, 24), Vector3(0, 0.1, 24), Vector3(5, 0.1, 24)]
var killer_spawn: Vector3 = Vector3(35, 0.1, -29)
var objectives: Array[Vector3] = [Vector3(-30, 0.05, -29), Vector3(1, 0.05, -29), Vector3(30, 0.05, -29), Vector3(-30, 0.05, 5), Vector3(30, 0.05, 28)]
var doors: Array[Dictionary] = []
var patrol_points: Array[Vector3] = [Vector3(0, 0, 17), Vector3(-17, 0, 0), Vector3(0, 0, -18), Vector3(17, 0, 0), Vector3(-42, 0, 0), Vector3(42, 0, 0), Vector3(0, 0, 29), Vector3(-30, 0, -29), Vector3(0, 0, -29), Vector3(30, 0, -29), Vector3(-30, 0, 5), Vector3(30, 0, 28)]
var _obstacles: Array[Rect2] = []
var _rooms: Array[Dictionary] = []

var _grid: AStarGrid2D
var _paper: StandardMaterial3D
var _cream: StandardMaterial3D
var _ink: StandardMaterial3D
var _wood: StandardMaterial3D
var _metal: StandardMaterial3D
var _glass: StandardMaterial3D
var _blue: StandardMaterial3D
var _pink: StandardMaterial3D
var _green: StandardMaterial3D
var _floor: StandardMaterial3D
var _lamp: StandardMaterial3D
var _built: bool = false
var map_id: String = "school"
var map_title: String = "École fondamentale · Grand campus"
var menu_spawn: Vector3 = Vector3(0, 0.05, 32.4)
var cinematic_anchor: Vector3 = Vector3(0, 0.05, 48)
var cinematic_exit: Vector3 = Vector3(0, 0.05, 58)
var cinematic_path: Array[Vector3] = []
var collision_audit: Array[Dictionary] = []
var _exit_leaves: Array[Node3D] = []
var _exit_open_tween: Tween
var _bounds: Rect2 = Rect2(-45.4, -35.4, 90.8, 70.8)
var _nav_region: Rect2i = Rect2i(-46, -36, 93, 73)
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _forest_paths: Array[Vector2] = []
var _snow: bool = false
var _material_cache: Dictionary = {}
var _surface_textures: Dictionary = {}
var _fire_flames: Array[MeshInstance3D] = []
var _scenery_time: float = 0.0
var ruleset: String = "om"
var healing_outlets: Array[Vector3] = []
var grind_rails: Array[Dictionary] = []
var escape_position: Vector3 = Vector3.ZERO
var om_layout: RefCounted



const BATCH_SECTOR: float = 20.0
const BATCH_PIECE: float = 10.0
const BATCH_LEVEL: float = 5.8
const SMALL_PROP: float = 1.7
const PROP_RANGE: float = 56.0
const TREE_CHUNK: float = 58.0

const FINISH_SCALE: Dictionary = {"stone": 0.16, "plaster": 0.3, "wood": 0.45, "snow": 0.12}

var floor_levels: Array[float] = [0.0]
var _tree_batches: Dictionary = {}
var _tree_meshes: Dictionary = {}
var _ambient_particles: Array[Node3D] = []

func build(selected_map: String = "school", _selected_ruleset: String = "om") -> void :
	if _built:
		return
	_built = true
	map_id = selected_map
	ruleset = "om"
	if ruleset == "om":
		om_layout = preload("res://om_maps.gd").new()
		om_layout.build(self, selected_map)
		set_process( not _fire_flames.is_empty() or not _ambient_particles.is_empty())
		return
	if selected_map in ["forest", "snow", "forest_snow"]:
		_build_forest(selected_map != "forest")
		return
	map_id = "school"
	name = "École de papier"
	_paper = _mat(Color("b7bbc0"))
	_cream = _mat(Color("d9d3c6"))
	_ink = _mat(Color("292c35"))
	_wood = _mat(Color("82796f"))
	_metal = _mat(Color("4b5261"))
	_glass = _mat(Color("38465b"))
	_blue = _mat(Color("758eaa"))
	_pink = _mat(Color("b58188"))
	_green = _mat(Color("79968b"))
	_floor = _mat(Color("797e89"))
	_lamp = _mat(Color("f4dfb1"), true)
	_apply_surface_finishes(false)
	_box(Vector3(94, 0.5, 74), Vector3(0, -0.26, 0), _ink, true, false)
	_box(Vector3(92, 0.08, 72), Vector3(0, -0.03, 0), _floor)
	_floor_tiles()

	_wall_x(-46, 46, -36, [])
	_wall_x(-46, -5, 36, [])
	_wall_x(5, 46, 36, [])
	_wall_z(-36, 36, -46, [])
	_wall_z(-36, 36, 46, [])
	_wall_x(-46, 46, -22, [-36.0, -23.0, -8.0, 8.0, 23.0, 36.0])
	_wall_z(-36, -22, -16, [])
	_wall_z(-36, -22, 16, [])
	_wall_x(-39, -21, -14, [-30.0])
	_wall_x(-39, -21, -1, [])
	_wall_x(-39, -21, 12, [-30.0])
	_wall_z(-14, 12, -39, [-8.0, 6.0])
	_wall_z(-14, 12, -21, [-8.0, 6.0])
	_wall_x(21, 39, -14, [30.0])
	_wall_x(21, 39, -1, [])
	_wall_x(21, 39, 12, [30.0])
	_wall_z(-14, 12, 21, [-8.0, 6.0])
	_wall_z(-14, 12, 39, [-8.0, 6.0])
	_wall_x(-46, -15, 20, [-37.0, -23.0])
	_wall_x(15, 46, 20, [23.0, 37.0])
	_wall_z(20, 36, -15, [28.0])
	_wall_z(20, 36, 15, [28.0])
	_room("Bibliothèque", Rect2(-45, -35, 28, 12), Color("9a8e78"))
	_room("Classe 01 · Calcul", Rect2(-15, -35, 30, 12), Color("8f9ba2"))
	_room("Atelier d'art", Rect2(17, -35, 28, 12), Color("ac8d92"))
	_room("Salle des professeurs", Rect2(-38, -13, 16, 11), Color("a69b8a"))
	_room("Infirmerie", Rect2(-38, 0, 16, 11), Color("8ca8a1"))
	_room("Cantine", Rect2(22, -13, 16, 11), Color("aaa088"))
	_room("Bassin intérieur", Rect2(22, 0, 16, 11), Color("809ead"))
	_room("Salle de musique", Rect2(-45, 21, 29, 14), Color("99909e"))
	_room("Laboratoire", Rect2(16, 21, 29, 14), Color("8ca6a9"))
	_room("Grand hall", Rect2(-14, 20, 28, 15), Color("a29c97"))
	_room("Cour des origamis", Rect2(-12, -14, 24, 26), Color("8b9b98"))
	_library()
	_classroom()
	_art_room()
	_west_rooms()
	_east_rooms()
	_south_rooms()
	_courtyard()
	_foyer()
	_corridor_details()
	_ceilings()
	_lighting()
	_school_furnishings()
	_school_expansion_details()
	_expand_school()
	_school_exit()
	menu_spawn = Vector3(0, 0.05, 42)
	cinematic_anchor = Vector3(0, 0.05, 46)
	cinematic_exit = Vector3(0, 0.05, 68)
	cinematic_path = [Vector3(0, 0.05, 59), Vector3(0, 0.05, 53), Vector3(0, 0.05, 46)]
	_batch_static_details()
	_prepare_navigation()

func _mat(color: Color, glow: bool = false, shared: bool = true) -> StandardMaterial3D:
	var key: String = color.to_html() + str(glow)
	if shared and _material_cache.has(key):
		return _material_cache[key]
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92


	material.set_meta("paper_map", {})
	if glow:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.35
	if shared:
		_material_cache[key] = material
	return material


func _map_uniforms(material: Material, uniforms: Dictionary) -> void :
	var current: Dictionary = material.get_meta("paper_map", {}).duplicate()
	current.merge(uniforms, true)
	material.set_meta("paper_map", current)

func _surface_texture(kind: String, normal: bool = false) -> NoiseTexture2D:
	var key: String = kind + ("_normal" if normal else "_color")
	if _surface_textures.has(key):
		return _surface_textures[key]
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 4604 + kind.hash() % 5000
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.045 if kind == "stone" else 0.09 if kind == "plaster" else 0.025
	noise.fractal_octaves = 4 if kind == "stone" else 3
	noise.fractal_gain = 0.52
	var texture: NoiseTexture2D = NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.generate_mipmaps = true
	texture.noise = noise
	if normal:
		texture.as_normal_map = true
		texture.bump_strength = 0.22 if kind == "plaster" else 0.48
	else:
		var ramp: Gradient = Gradient.new()
		ramp.set_color(0, Color(0.8, 0.8, 0.8) if kind in ["wood", "stone"] else Color(0.88, 0.88, 0.88))
		ramp.set_color(1, Color(1.0, 1.0, 1.0))
		texture.color_ramp = ramp
	_surface_textures[key] = texture
	return texture

func _finish(material: StandardMaterial3D, kind: String, roughness: float, repeats: Vector3 = Vector3(3, 3, 3)) -> void :

	if material.get_meta("paper_finish", "") == kind:
		return
	material.set_meta("paper_finish", kind)
	material.albedo_texture = _surface_texture(kind)
	material.roughness = roughness

	material.uv1_scale = repeats
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if material.has_meta("paper_map"):
		_map_uniforms(material, {"texture_scale": float(FINISH_SCALE.get(kind, 0.25)) * clampf(repeats.x / 3.0, 0.5, 2.0)})

func _apply_surface_finishes(forest: bool) -> void :
	_finish(_paper, "stone" if forest else "plaster", 0.93, Vector3(3, 3, 3))
	_finish(_cream, "snow" if _snow else "plaster", 0.97 if _snow else 0.76)
	_finish(_wood, "wood", 0.86, Vector3(2, 9, 2))
	_finish(_metal, "plaster", 0.48, Vector3(2, 2, 2))
	_metal.metallic = 0.35
	_finish(_floor, "snow" if _snow else "stone", 0.88 if forest else 0.48, Vector3(6, 6, 6))
	_glass.roughness = 0.19
	_glass.metallic = 0.38
	if not forest:
		_glass.emission_enabled = true
		_glass.emission = Color("203a55")
		_glass.emission_energy_multiplier = 0.12
	_lamp.emission_energy_multiplier = 0.8

func _box(size: Vector3, pos: Vector3, material: Material, collision: bool = false, nav: bool = true) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos

	if size.y <= 0.06:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	if collision:
		var body: StaticBody3D = StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		instance.add_child(body)
		collision_audit.append({"kind": "box", "position": pos, "size": size})
		if nav:
			_obstacles.append(Rect2(pos.x - size.x * 0.5 - 0.5, pos.z - size.z * 0.5 - 0.5, size.x + 1.0, size.z + 1.0))
	return instance

func _cylinder(pos: Vector3, radius: float, height: float, material: Material, top_radius: float = -1.0) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = material
	add_child(instance)
	return instance

func _label(text_value: String, pos: Vector3, size: int = 38, color: Color = Color("e7e0d1"), rotate_y: float = 0.0) -> Label3D:
	var label: Label3D = Label3D.new()
	label.text = text_value
	label.font_size = size
	label.pixel_size = 0.008
	label.modulate = color
	label.outline_modulate = Color("292c35")
	label.outline_size = 5
	label.position = pos
	label.rotation.y = rotate_y
	label.no_depth_test = false

	label.visibility_range_end = clampf(float(size) * 0.85, 22.0, 44.0)
	label.visibility_range_end_margin = 2.0
	add_child(label)
	return label

func _floor_tiles() -> void :

	var tile_material: StandardMaterial3D = _mat(Color("858994"))
	_finish(tile_material, "stone", 0.54, Vector3(4, 4, 4))
	for x in range(-44, 46, 4):
		for z in range(-34, 36, 4):
			if (int((x + 44) / 4) + int((z + 34) / 4)) % 2 == 0:
				_box(Vector3(3.96, 0.012, 3.96), Vector3(x, 0.018, z), tile_material)
	for x in range(-44, 45, 8):
		_box(Vector3(0.025, 0.014, 70), Vector3(x, 0.031, 0), _metal)
	for z in range(-34, 35, 8):
		_box(Vector3(90, 0.014, 0.025), Vector3(0, 0.031, z), _metal)

func _wall_piece(a: Vector3, b: Vector3) -> void :
	var along_x: bool = absf(a.x - b.x) > absf(a.z - b.z)
	var length: float = a.distance_to(b)
	if length < 0.05:
		return
	var center: Vector3 = (a + b) * 0.5
	var size: Vector3 = Vector3(length, 5.2, 0.28) if along_x else Vector3(0.28, 5.2, length)
	_box(size, center + Vector3(0, 2.6, 0), _paper, true)
	var trim_size: Vector3 = Vector3(length, 0.07, 0.32) if along_x else Vector3(0.32, 0.07, length)
	_box(trim_size, center + Vector3(0, 0.09, 0), _ink)
	_box(trim_size, center + Vector3(0, 1.16, 0), _ink)
	_box(trim_size, center + Vector3(0, 5.18, 0), _ink)
	var panel_size: Vector3 = Vector3(length, 0.97, 0.29) if along_x else Vector3(0.29, 0.97, length)
	_box(panel_size, center + Vector3(0, 0.65, 0), _cream)
	for edge in [a, b]:
		_box(Vector3(0.05, 5.2, 0.05), edge + Vector3(0, 2.6, 0), _ink)

func _wall_x(start: float, end: float, z: float, openings: Array) -> void :
	var cursor: float = start
	for value in openings:
		var x: float = float(value)
		_wall_piece(Vector3(cursor, 0, z), Vector3(x - 1.6, 0, z))
		_door(Vector3(x, 0, z), "x")
		cursor = x + 1.6
	_wall_piece(Vector3(cursor, 0, z), Vector3(end, 0, z))

func _wall_z(start: float, end: float, x: float, openings: Array) -> void :
	var cursor: float = start
	for value in openings:
		var z: float = float(value)
		_wall_piece(Vector3(x, 0, cursor), Vector3(x, 0, z - 1.6))
		_door(Vector3(x, 0, z), "z")
		cursor = z + 1.6
	_wall_piece(Vector3(x, 0, cursor), Vector3(x, 0, end))

func _door(pos: Vector3, axis: String) -> void :
	doors.append({"id": doors.size(), "position": pos, "axis": axis, "width": 3.2})
	var horizontal: bool = axis == "x"
	var lintel_size: Vector3 = Vector3(3.4, 0.62, 0.42) if horizontal else Vector3(0.42, 0.62, 3.4)
	_box(lintel_size, pos + Vector3(0, 3.48, 0), _ink)
	_box(lintel_size * Vector3(0.98, 0.58, 0.98), pos + Vector3(0, 3.47, 0), _cream)
	_box(Vector3(3.4, 1.45, 0.3) if horizontal else Vector3(0.3, 1.45, 3.4), pos + Vector3(0, 4.5, 0), _paper, true, false)
	for side in [-1.0, 1.0]:
		var offset: Vector3 = Vector3(side * 1.67, 1.6, 0) if horizontal else Vector3(0, 1.6, side * 1.67)
		_box(Vector3(0.12, 3.2, 0.45) if horizontal else Vector3(0.45, 3.2, 0.12), pos + offset, _ink)

	_box(Vector3(3.1, 0.025, 0.24) if horizontal else Vector3(0.24, 0.025, 3.1), pos + Vector3(0, 0.06, 0), _cream)

func _room(title: String, bounds: Rect2, tint: Color) -> void :
	_rooms.append({"name": title, "bounds": bounds})
	var room_floor: StandardMaterial3D = _mat(tint.darkened(0.13))
	_finish(room_floor, "stone", 0.68, Vector3(9, 9, 9))
	_box(Vector3(bounds.size.x, 0.017, bounds.size.y), Vector3(bounds.get_center().x, 0.038, bounds.get_center().y), room_floor)
	for offset in [0.12, -0.12]:
		_box(Vector3(bounds.size.x - 0.45, 0.012, 0.028), Vector3(bounds.get_center().x, 0.049, bounds.position.y + 0.4 + offset), _cream)

func _table(pos: Vector3, size: Vector2 = Vector2(2.4, 1.4), material: Material = null) -> void :
	var top_material: Material = _cream if material == null else material
	_box(Vector3(size.x + 0.07, 0.13, size.y + 0.07), pos + Vector3(0, 0.95, 0), _ink, true)
	_box(Vector3(size.x, 0.05, size.y), pos + Vector3(0, 1.045, 0), top_material)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(Vector3(0.08, 0.9, 0.08), pos + Vector3(sx * (size.x * 0.5 - 0.18), 0.45, sz * (size.y * 0.5 - 0.18)), _metal)

func _chair(pos: Vector3, angle: float = 0.0) -> void :
	var seat: MeshInstance3D = _box(Vector3(0.66, 0.1, 0.67), pos + Vector3(0, 0.48, 0), _wood)
	seat.rotation.y = angle
	var back_pos: Vector3 = Vector3(0, 0.87, 0.3).rotated(Vector3.UP, angle)
	var back: MeshInstance3D = _box(Vector3(0.66, 0.62, 0.07), pos + back_pos, _cream)
	back.rotation.y = angle
	_solid_mesh(seat, true)
	_solid_mesh(back, false)
	for sx in [-0.25, 0.25]:
		for sz in [-0.25, 0.25]:
			_box(Vector3(0.035, 0.47, 0.035), pos + Vector3(sx, 0.235, sz).rotated(Vector3.UP, angle), _ink)

func _paper_sheet(pos: Vector3, angle: float = 0.0) -> void :
	var sheet: MeshInstance3D = _box(Vector3(0.45, 0.012, 0.6), pos, _cream)
	sheet.rotation.y = angle
	for n in range(3):
		_box(Vector3(0.27, 0.004, 0.018), pos + Vector3(0, 0.01, -0.14 + n * 0.09), _metal)

func _blackboard(center: Vector3, width: float, message: String) -> void :
	_box(Vector3(width + 0.15, 1.72, 0.11), center, _ink)
	_box(Vector3(width, 1.57, 0.14), center + Vector3(0, 0, 0.015), _mat(Color("384c47")))
	_box(Vector3(width + 0.2, 0.06, 0.3), center + Vector3(0, -0.85, 0.12), _wood)
	_label(message, center + Vector3(0, 0.08, 0.11), 32, Color("d7d8c6"))

func _library() -> void :
	for x in [-39.0, -30.0, -21.0]:
		for z in [-33.7, -27.4]:
			_box(Vector3(3.8, 2.65, 0.72), Vector3(x, 1.33, z), _wood, true)
			for y in [0.3, 1.05, 1.8, 2.55]:
				_box(Vector3(3.85, 0.05, 0.78), Vector3(x, y, z + 0.02), _ink)
			for column in range(11):
				for shelf in range(3):
					var color_index: int = (column + shelf * 3) % 4
					var book_material: Material = [_paper, _blue, _pink, _green][color_index]
					var h: float = 0.41 + float((column * 7 + shelf) % 4) * 0.045
					_box(Vector3(0.22, h, 0.49), Vector3(x - 1.55 + column * 0.3, 0.37 + shelf * 0.75 + h * 0.5, z + 0.19), book_material)
	_blackboard(Vector3(-30, 2.2, -35.78), 7, "BIBLIOTHÈQUE\nLe silence vous protège.")
	_table(Vector3(-30, 0, -24.4), Vector2(5.5, 1.3))
	_paper_sheet(Vector3(-31.5, 1.08, -24.4), 0.16)
	_label("01 / ARCHIVES", Vector3(-30, 3.45, -21.73), 28)

func _classroom() -> void :
	_blackboard(Vector3(0, 2.22, -35.78), 12, "ÉDUCATION FONDAMENTALE\n1 + 1 = 2     •     Ne restez jamais seuls.")
	for x in [-10.0, -4.0, 4.0, 10.0]:
		for z in [-31.5, -26.5]:
			_table(Vector3(x, 0, z), Vector2(2.5, 1.3))
			_chair(Vector3(x, 0, z + 1.3))
			_paper_sheet(Vector3(x - 0.55, 1.08, z), float(int(x) % 3) * 0.1)
	_label("02 / CALCUL", Vector3(0, 3.45, -21.73), 28)
	_clock(Vector3(12.6, 2.9, -35.73))

func _art_room() -> void :
	for x in [22.0, 30.0, 38.0]:
		_table(Vector3(x, 0, -31), Vector2(3.0, 1.8), _pink)
		_paper_sheet(Vector3(x, 1.08, -31))
		_cylinder(Vector3(x + 0.8, 1.23, -31), 0.13, 0.31, _blue)
		for offset in [-0.06, 0.02, 0.07]:
			_box(Vector3(0.03, 0.6, 0.03), Vector3(x + 0.8 + offset, 1.53, -31), _wood)
	for x in [20.0, 26.0, 33.0, 40.0]:
		_box(Vector3(1.9, 2.05, 0.11), Vector3(x, 2.15, -35.76), _ink)
		_box(Vector3(1.72, 1.88, 0.12), Vector3(x, 2.15, -35.67), _cream)
		var stroke: MeshInstance3D = _box(Vector3(1.23, 0.12, 0.04), Vector3(x, 2.15, -35.58), _pink)
		stroke.rotation.z = x * 0.3
		_cylinder(Vector3(x - 0.2, 2.6, -35.54), 0.17, 0.025, _blue).rotation.x = PI * 0.5
	_label("03 / ATELIER D'ART", Vector3(30, 3.45, -21.73), 28)
	_box(Vector3(3.6, 1.8, 0.65), Vector3(43.5, 0.9, -27.5), _wood, true)

func _west_rooms() -> void :
	_table(Vector3(-30, 0, -7.5), Vector2(6, 2.6), _wood)
	for x in [-32.0, -30.0, -28.0]:
		_chair(Vector3(x, 0, -5.4))
		_chair(Vector3(x, 0, -9.6), PI)
	_blackboard(Vector3(-30, 2.2, -13.76), 9, "SALLE DES PROFESSEURS\nPrésences : personne.")
	for x in [-34.0, -26.0]:
		_box(Vector3(2.1, 0.6, 3.4), Vector3(x, 0.7, 4), _metal, true)
		_box(Vector3(2.0, 0.2, 3.3), Vector3(x, 1.1, 4), _cream)
		_box(Vector3(1.6, 0.18, 0.6), Vector3(x, 1.29, 2.9), _paper)
		_box(Vector3(2.1, 0.06, 1.8), Vector3(x, 1.23, 4.65), _green)
	_box(Vector3(1.3, 2.4, 0.6), Vector3(-36.6, 1.2, 9.5), _cream, true)
	_box(Vector3(0.14, 0.8, 0.04), Vector3(-36.6, 1.7, 9.82), _pink)
	_box(Vector3(0.65, 0.14, 0.04), Vector3(-36.6, 1.7, 9.83), _pink)
	_label("INFIRMERIE", Vector3(-30, 2.7, -0.75), 31, Color("ccdfd5"))

func _east_rooms() -> void :
	for z in [-10.5, -4.0]:
		_table(Vector3(30, 0, z), Vector2(6.5, 2.0))
		_box(Vector3(6.5, 0.22, 0.6), Vector3(30, 0.5, z + 1.8), _wood, true)
		_box(Vector3(6.5, 0.22, 0.6), Vector3(30, 0.5, z - 1.8), _wood, true)
	_box(Vector3(7.0, 1.2, 0.8), Vector3(30, 0.6, -13.4), _metal, true)
	_label("CANTINE / MENU : ???", Vector3(30, 2.9, -13.76), 30)

	_box(Vector3(8, 0.52, 4.8), Vector3(30, 0.26, 5.5), _cream, true)
	var water: StandardMaterial3D = _mat(Color("31556d"))
	water.metallic = 0.38
	water.roughness = 0.17
	_box(Vector3(7.55, 0.025, 4.35), Vector3(30, 0.53, 5.5), water)
	for x in [26.1, 33.9]:
		_box(Vector3(0.12, 0.1, 4.8), Vector3(x, 0.57, 5.5), _ink)
	for z in [3.1, 7.9]:
		_box(Vector3(8.0, 0.1, 0.12), Vector3(30, 0.57, z), _ink)
	for x in [27.0, 29.0, 31.0, 33.0]:
		_box(Vector3(0.035, 0.008, 3.9), Vector3(x, 0.55, 5.5), _blue)
	_label("BASSIN / ACCÈS FERMÉ", Vector3(30, 2.7, -0.75), 30, Color("bdd4e5"))

func _south_rooms() -> void :
	_box(Vector3(5.5, 0.35, 3.2), Vector3(-30, 0.175, 32.5), _wood, true)
	_box(Vector3(3.5, 1.25, 1.0), Vector3(-30, 0.97, 33), _ink, true)
	_box(Vector3(3.0, 0.12, 0.45), Vector3(-30, 1.05, 32.23), _cream)
	for key in range(18):
		_box(Vector3(0.035, 0.012, 0.44), Vector3(-31.4 + key * 0.16, 1.12, 32.23), _ink)
	for x in [-39.0, -21.0]:
		for z in [25.0, 30.0]:
			_chair(Vector3(x, 0, z), PI)
			_cylinder(Vector3(x + 1.2, 0.65, z - 1.0), 0.035, 1.3, _ink)
			var music: MeshInstance3D = _box(Vector3(0.7, 0.65, 0.045), Vector3(x + 1.2, 1.35, z - 1.0), _ink)
			music.rotation.x = -0.35
	_label("MUSIQUE / LA DERNIÈRE NOTE", Vector3(-30, 2.8, 35.77), 28, Color("e5d5e5"), PI)
	for x in [22.0, 30.0, 38.0]:
		_table(Vector3(x, 0, 31), Vector2(3.8, 2.0), _green)
		for n in range(3):
			_cylinder(Vector3(x - 1.0 + n * 0.8, 1.3, 31), 0.16, 0.48, _blue if n % 2 == 0 else _pink, 0.08)
		_paper_sheet(Vector3(x + 1.2, 1.08, 31.2))
	_blackboard(Vector3(30, 2.3, 20.23), 10, "LABORATOIRE\nObserver. Comprendre. Survivre.")
	_label("LABORATOIRE", Vector3(30, 3.4, 19.75), 30, Color("dce7e1"), PI)

func _courtyard() -> void :
	_box(Vector3(23.7, 0.02, 25.6), Vector3(0, 0.067, -1), _mat(Color("77857f")))

	for pos in [Vector3(-7, 0, -8), Vector3(7, 0, 5)]:
		_box(Vector3(5.0, 0.65, 4.0), pos + Vector3(0, 0.325, 0), _cream, true)
		_box(Vector3(4.65, 0.07, 3.65), pos + Vector3(0, 0.69, 0), _mat(Color("57685f")))
		_cylinder(pos + Vector3(0, 2.1, 0), 0.18, 3.0, _wood, 0.12)
		for tier in range(3):
			_cylinder(pos + Vector3(0, 3.0 + tier * 0.7, 0), 1.55 - tier * 0.34, 1.6, _green, 0.05)
	for x in [-11.7, 11.7]:
		for z in [-13.5, -1.0, 11.5]:
			_box(Vector3(0.36, 4.2, 0.36), Vector3(x, 2.1, z), _cream, true)
		_box(Vector3(0.48, 0.16, 25.4), Vector3(x, 4.17, -1), _ink)
	for z in [-13.5, 11.5]:
		_box(Vector3(23.8, 0.16, 0.48), Vector3(0, 4.17, z), _ink)
	_box(Vector3(3.8, 0.4, 0.65), Vector3(0, 0.6, -9.5), _wood, true)
	_box(Vector3(3.8, 0.4, 0.65), Vector3(0, 0.6, 7.5), _wood, true)
	for x in [-8.0, -4.0, 0.0, 4.0, 8.0]:
		var flag: MeshInstance3D = _box(Vector3(0.8, 0.8, 0.025), Vector3(x, 4.2 - absf(x) * 0.018, -1), _pink if int(x) % 8 == 0 else _blue)
		flag.rotation.z = PI / 4.0
	_box(Vector3(23, 0.025, 0.025), Vector3(0, 4.5, -1), _ink)

func _foyer() -> void :

	for x in [-11.0, 11.0]:
		_box(Vector3(1.1, 0.9, 1.1), Vector3(x, 0.45, 32), _wood, true)
		_cylinder(Vector3(x, 1.25, 32), 0.75, 1.5, _green, 0.08)
	_box(Vector3(6.8, 0.014, 5.8), Vector3(0, 0.06, 27), _mat(Color("655d67")))
	for x in [-3.25, 3.25]:
		_box(Vector3(0.04, 0.015, 5.4), Vector3(x, 0.073, 27), _cream)

func _school_exit() -> void :
	var glass: StandardMaterial3D = _exit_glass()
	var sign_material: StandardMaterial3D = _mat(Color("254c42"))
	_box(Vector3(17.5, 1.6, 0.5), Vector3(0, 5.05, 63), _cream, true, false)
	_box(Vector3(6.2, 0.86, 0.08), Vector3(0, 4.95, 62.69), sign_material)
	_label("S O R T I E", Vector3(0, 4.95, 62.61), 98, Color("e1ffdd"), PI)
	for side in [-1.0, 1.0]:
		_box(Vector3(5.32, 4.2, 0.12), Vector3(side * 5.98, 2.1, 63), glass, true, false)
		for x in [side * 3.22, side * 6.0, side * 8.65]:
			_box(Vector3(0.18, 4.3, 0.3), Vector3(x, 2.15, 63), _metal, true, false)
		_box(Vector3(5.32, 0.16, 0.22), Vector3(side * 5.98, 0.5, 63), _metal)
		_box(Vector3(5.32, 0.13, 0.22), Vector3(side * 5.98, 2.15, 63), _metal)
	_hinged_exit(Vector3(0, 0, 63), 6.2, 4.2, glass)
	_obstacles.append(Rect2(-9, 62.3, 18, 1.4))


	_box(Vector3(22, 0.32, 24), Vector3(0, -0.18, 75), _mat(Color("a4a393")), true, false)
	for x in range(-9, 10, 2):
		for z in range(65, 86, 2):
			_box(Vector3(1.94, 0.02, 1.94), Vector3(x, 0.0, z), _cream if (x + z) % 4 == 0 else _paper)
	for x in [-10.6, 10.6]:
		_exit_fence(Vector3(x, 0, 63), Vector3(x, 0, 87))
	_exit_fence(Vector3(-10.6, 0, 87), Vector3(10.6, 0, 87))
	for p in [Vector3(-7.7, 0, 72), Vector3(7.7, 0, 72), Vector3(-7.7, 0, 82), Vector3(7.7, 0, 82)]:
		var planter: MeshInstance3D = _cylinder(p + Vector3.UP * 0.45, 1.15, 0.9, _cream)
		_solid_mesh(planter, false)
		_forest_tree(p + Vector3.UP * 0.85, 6.0, 0, true)
	for p in [Vector3(-4.5, 0, 68), Vector3(4.5, 0, 77)]:
		_forest_lantern(p, 1.15, Color("ffd8a1"))
	var welcome: OmniLight3D = OmniLight3D.new()
	welcome.position = Vector3(0, 3.4, 68)
	welcome.light_color = Color("ffe0ae")
	welcome.light_energy = 1.35
	welcome.omni_range = 16
	add_child(welcome)

func _exit_glass() -> StandardMaterial3D:
	var glass: StandardMaterial3D = StandardMaterial3D.new()
	glass.albedo_color = Color(0.53, 0.76, 0.78, 0.22)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.roughness = 0.12
	glass.metallic = 0.1
	return glass

func _hinged_exit(center: Vector3, width: float, height: float, material: Material) -> void :
	for side in [-1.0, 1.0]:
		var hinge: Node3D = Node3D.new()
		hinge.name = "Porte articulée gauche" if side < 0 else "Porte articulée droite"
		hinge.position = center + Vector3(side * width * 0.5, 0, 0)
		hinge.set_meta("opening_angle", side * deg_to_rad(100))
		add_child(hinge)
		_exit_leaves.append(hinge)
		var leaf_width: float = width * 0.5
		var cx: float = - side * leaf_width * 0.5
		_exit_part(hinge, Vector3(leaf_width, height, 0.14), Vector3(cx, height * 0.5, 0), material, true)
		for x in [0.0, - side * leaf_width]:
			_exit_part(hinge, Vector3(0.1, height, 0.22), Vector3(x, height * 0.5, 0), _metal)
		for y in [0.08, height - 0.08, 0.5]:
			_exit_part(hinge, Vector3(leaf_width, 0.16, 0.22), Vector3(cx, y, 0), _metal)
		_exit_part(hinge, Vector3(leaf_width * 0.75, 0.1, 0.11), Vector3(cx, 1.15, -0.18), _cream)

func _exit_part(parent: Node3D, size: Vector3, pos: Vector3, material: Material, solid: bool = false) -> void :
	var part: MeshInstance3D = _box(size, pos, material, solid, false)
	part.reparent(parent, false)

	if solid and not collision_audit.is_empty():
		collision_audit[collision_audit.size() - 1]["position"] = parent.transform * pos

func set_cinematic_exit_open(open: bool) -> void :
	if _exit_open_tween != null and _exit_open_tween.is_valid():
		_exit_open_tween.kill()
	if not open:
		for hinge in _exit_leaves:
			hinge.rotation.y = 0
		return
	_exit_open_tween = create_tween().set_parallel(true)
	for hinge in _exit_leaves:
		_exit_open_tween.tween_property(hinge, "rotation:y", float(hinge.get_meta("opening_angle")), 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func sample_cinematic_exit_open(seconds: float) -> void :

	if _exit_open_tween != null and _exit_open_tween.is_valid():
		_exit_open_tween.kill()
	var opening: float = smoothstep(0.0, 1.5, maxf(0.0, seconds))
	for hinge in _exit_leaves:
		hinge.rotation.y = float(hinge.get_meta("opening_angle")) * opening

func _exit_fence(start: Vector3, finish: Vector3) -> void :
	var along_x: bool = absf(finish.x - start.x) > absf(finish.z - start.z)
	var length: float = start.distance_to(finish)
	var center: Vector3 = (start + finish) * 0.5
	_box(Vector3(length + 0.2, 0.85, 0.25) if along_x else Vector3(0.25, 0.85, length + 0.2), center + Vector3.UP * 0.425, _cream, true, false)
	for i in range(ceili(length / 0.24) + 1):
		var p: Vector3 = start.lerp(finish, minf(1, i * 0.24 / length))
		_box(Vector3(0.055, 1.8, 0.055), p + Vector3.UP * 1.35, _ink, true, false)
	for y in [0.95, 2.12]:
		_box(Vector3(length, 0.09, 0.1) if along_x else Vector3(0.1, 0.09, length), center + Vector3.UP * y, _ink)

func _clock(pos: Vector3) -> void :
	_cylinder(pos, 0.39, 0.055, _ink).rotation.x = PI * 0.5
	_cylinder(pos + Vector3(0, 0, 0.04), 0.35, 0.04, _cream).rotation.x = PI * 0.5
	_box(Vector3(0.03, 0.25, 0.02), pos + Vector3(0, 0.1, 0.08), _ink)
	_box(Vector3(0.2, 0.03, 0.02), pos + Vector3(0.08, 0, 0.08), _ink)

func _corridor_details() -> void :
	for x in [-44.0, -12.0, 12.0, 44.0]:
		for z in [-35.7, 35.7]:
			_box(Vector3(1.55, 1.65, 0.1), Vector3(x, 2.45, z), _ink)
			_box(Vector3(1.4, 1.5, 0.13), Vector3(x, 2.45, z), _glass)
			_box(Vector3(0.035, 1.55, 0.17), Vector3(x, 2.45, z), _cream)
			_box(Vector3(1.4, 0.035, 0.17), Vector3(x, 2.45, z), _cream)
	for x in [-45.65, 45.65]:
		for z in [-29.0, -18.0, 0.0, 17.0, 28.0]:
			_box(Vector3(0.12, 1.65, 2.5), Vector3(x, 2.4, z), _ink)
			_box(Vector3(0.15, 1.48, 2.3), Vector3(x, 2.4, z), _glass)
			_box(Vector3(0.18, 0.035, 2.3), Vector3(x, 2.4, z), _cream)
	for x in [-17.0, 17.0]:
		_label("← COUR CENTRALE →", Vector3(x, 3.25, -14.5), 23)
	for x in [-40.0, 40.0]:
		for n in range(4):
			var locker_z: float = 23.0 + n * 0.8
			_box(Vector3(0.65, 2.2, 0.72), Vector3(x, 1.1, locker_z), _blue, true)
			_box(Vector3(0.67, 0.035, 0.025), Vector3(x, 1.8, locker_z - 0.37), _ink)
			_box(Vector3(0.1, 0.12, 0.04), Vector3(x + 0.2, 1.15, locker_z - 0.38), _ink)
	_label("← INFIRMERIE       COUR       CANTINE →", Vector3(0, 3.25, 12), 28)
	_label("ARCHIVES       CALCUL       ATELIER", Vector3(0, 3.25, -14), 29, Color("e6d6b9"), PI)
	for p in objectives:

		_box(Vector3(1.05, 0.1, 1.05), p + Vector3(0, 0.04, 0), _ink)
		_box(Vector3(0.92, 0.04, 0.92), p + Vector3(0, 0.12, 0), _blue)

func _ceilings() -> void :
	var ceiling: StandardMaterial3D = _mat(Color("979ba4"))
	var beam: StandardMaterial3D = _mat(Color("646c79"))


	_box(Vector3(92, 0.2, 22), Vector3(0, 5.3, -25), ceiling, true, false)
	_box(Vector3(92, 0.2, 24), Vector3(0, 5.3, 24), ceiling, true, false)
	_box(Vector3(34, 0.2, 26), Vector3(-29, 5.3, -1), ceiling, true, false)
	_box(Vector3(34, 0.2, 26), Vector3(29, 5.3, -1), ceiling, true, false)
	for x in range(-44, 45, 8):
		_box(Vector3(0.08, 0.1, 22), Vector3(x, 5.16, -25), beam)
		_box(Vector3(0.08, 0.1, 24), Vector3(x, 5.16, 24), beam)
	for z in [-10.0, -2.0, 6.0]:
		_box(Vector3(34, 0.1, 0.08), Vector3(-29, 5.16, z), beam)
		_box(Vector3(34, 0.1, 0.08), Vector3(29, 5.16, z), beam)
	for z in [-18.0, 16.0]:
		for x in [-36.0, -18.0, 0.0, 18.0, 36.0]:
			_ceiling_lamp(Vector3(x, 3.62, z), 0.48, 9.0)
	for x in [-42.0, 42.0]:
		_ceiling_lamp(Vector3(x, 3.62, 0), 0.45, 12.0)

func _ceiling_lamp(pos: Vector3, energy: float = 0.7, radius: float = 10.0) -> void :


	for side in [-0.8, 0.8]:
		var cable_height: float = 5.17 - pos.y
		_box(Vector3(0.024, cable_height, 0.024), pos + Vector3(side, cable_height * 0.5, 0), _metal)
	_box(Vector3(2.8, 0.08, 0.48), pos, _ink)
	_box(Vector3(2.55, 0.05, 0.29), pos - Vector3(0, 0.055, 0), _lamp)
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.position = pos - Vector3(0, 0.3, 0)
	lamp.light_color = Color("ffdcac")
	lamp.light_energy = energy * 1.25
	lamp.omni_range = radius
	lamp.omni_attenuation = 1.5
	lamp.shadow_enabled = false
	add_child(lamp)

func _lighting() -> void :
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Clair de lune"
	sun.rotation_degrees = Vector3(-38, -28, 0)
	sun.light_color = Color("91a8ca")
	sun.light_energy = 0.18
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 95
	add_child(sun)
	for pos in [Vector3(-30, 3.65, -29), Vector3(0, 3.65, -29), Vector3(30, 3.65, -29), Vector3(-30, 3.65, -7), Vector3(-30, 3.65, 5), Vector3(30, 3.65, -7), Vector3(30, 3.65, 5), Vector3(-30, 3.65, 28), Vector3(0, 3.65, 27), Vector3(30, 3.65, 28), Vector3(-17, 3.6, 0), Vector3(17, 3.6, 0)]:
		_ceiling_lamp(pos)

func _prepare_navigation() -> void :
	if _grid == null:
		_grid = AStarGrid2D.new()
	_grid.region = _nav_region
	_grid.cell_size = Vector2.ONE
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.update()
	for x in range(_nav_region.position.x, _nav_region.end.x):
		for z in range(_nav_region.position.y, _nav_region.end.y):
			_grid.set_point_solid(Vector2i(x, z), not can_walk(Vector3(x, 0, z)))

func can_walk(point: Vector3) -> bool:
	if om_layout != null:
		return om_layout.can_walk(point)
	var p: Vector2 = Vector2(point.x, point.z)
	if not _bounds.has_point(p):
		return false
	for rect in _obstacles:
		if rect.has_point(p):
			return false
	return true

func _nearest_walkable(pos: Vector3) -> Vector2i:
	var cell: Vector2i = Vector2i(clampi(roundi(pos.x), _nav_region.position.x + 1, _nav_region.end.x - 2), clampi(roundi(pos.z), _nav_region.position.y + 1, _nav_region.end.y - 2))
	if not _grid.is_point_solid(cell):
		return cell
	for radius in range(1, 12):
		var best: Vector2i = cell
		var best_distance: float = INF
		for dx in range( - radius, radius + 1):
			for dz in range( - radius, radius + 1):
				if absi(dx) != radius and absi(dz) != radius:
					continue
				var candidate: Vector2i = cell + Vector2i(dx, dz)
				if _grid.is_in_boundsv(candidate) and not _grid.is_point_solid(candidate):
					var distance: float = Vector2(candidate.x - pos.x, candidate.y - pos.z).length_squared()
					if distance < best_distance:
						best = candidate
						best_distance = distance
		if best_distance < INF:
			return best
	return cell

func nav_path(from: Vector3, to: Vector3, blocked_door: int = -1) -> PackedVector3Array:
	if om_layout != null:
		return om_layout.nav_path(from, to, blocked_door)
	var temporary: Array[Vector2i] = []
	if blocked_door >= 0 and blocked_door < doors.size():
		var data: Dictionary = doors[blocked_door]
		var pos: Vector3 = data["position"]
		var half_span: int = ceili(float(data.get("width", 3.2)) * 0.5 + 0.5)
		for x in range(roundi(pos.x) - half_span, roundi(pos.x) + half_span + 1):
			for z in range(roundi(pos.z) - half_span, roundi(pos.z) + half_span + 1):
				var cell: Vector2i = Vector2i(x, z)
				var across: bool = absf(z - pos.z) <= 1.0 if data["axis"] == "x" else absf(x - pos.x) <= 1.0
				if across and _grid.is_in_boundsv(cell) and not _grid.is_point_solid(cell):
					_grid.set_point_solid(cell, true)
					temporary.append(cell)
	var start: Vector2i = _nearest_walkable(from)
	var finish: Vector2i = _nearest_walkable(to)
	var cells: Array[Vector2i] = _grid.get_id_path(start, finish)
	for cell in temporary:
		_grid.set_point_solid(cell, false)
	var path: PackedVector3Array = PackedVector3Array()
	for cell in cells:
		path.append(Vector3(cell.x, 0, cell.y))
	return path

func room_name(pos: Vector3) -> String:
	if om_layout != null:
		return om_layout.room_name(pos)
	var point: Vector2 = Vector2(pos.x, pos.z)
	for room in _rooms:
		var bounds: Rect2 = room["bounds"]
		if bounds.has_point(point):
			return String(room["name"])
	return "Galerie de l'école" if map_id == "school" else ("Sous-bois givrés" if _snow else "Sous-bois des murmures")

func om_jump_hint(from: Vector3, to: Vector3) -> Vector3:
	return om_layout.jump_hint(from, to) if om_layout != null else Vector3.ZERO

func bot_jump_hint(_from: Vector3, _to: Vector3) -> bool:

	return false

func _expand_school() -> void :


	var stretch: Vector3 = Vector3(1.75, 1.12, 1.75)
	_stretch_world(stretch)
	_bounds = Rect2(-79.45, -61.95, 158.9, 123.9)
	_nav_region = Rect2i(-81, -64, 163, 129)

func _stretch_world(stretch: Vector3) -> void :
	for child in get_children():
		if child is Node3D:
			child.position *= stretch
			if child is MeshInstance3D:
				child.scale *= stretch
				for body in child.get_children():
					if body is StaticBody3D:
						body.scale /= stretch
						for shape_node in body.get_children():
							if shape_node is CollisionShape3D and shape_node.shape is BoxShape3D:
								shape_node.shape.size *= stretch
			elif child is StaticBody3D:
				for shape_node in child.get_children():
					if not shape_node is CollisionShape3D:
						continue
					if shape_node.shape is BoxShape3D:
						shape_node.shape.size *= stretch
					elif shape_node.shape is CylinderShape3D:
						shape_node.shape.radius *= stretch.x
						shape_node.shape.height *= stretch.y
					elif shape_node.shape is ConvexPolygonShape3D:
						var points: PackedVector3Array = shape_node.shape.points
						for i in range(points.size()):
							points[i] *= stretch
						shape_node.shape.points = points
					elif shape_node.shape is ConcavePolygonShape3D:
						var faces: PackedVector3Array = shape_node.shape.get_faces()
						for i in range(faces.size()):
							faces[i] *= stretch
						shape_node.shape.set_faces(faces)
			elif child is OmniLight3D:
				child.omni_range *= stretch.x
			elif child is DirectionalLight3D:
				child.directional_shadow_max_distance = 150.0
	for i in range(_obstacles.size()):
		_obstacles[i] = Rect2(_obstacles[i].position * stretch.x, _obstacles[i].size * stretch.x)
	for room in _rooms:
		var rectangle: Rect2 = room["bounds"]
		room["bounds"] = Rect2(rectangle.position * stretch.x, rectangle.size * stretch.x)
	for door in doors:
		door["position"] *= Vector3(stretch.x, 1.0, stretch.z)
		door["width"] *= stretch.x
	for i in range(spawn_points.size()):
		spawn_points[i] *= Vector3(stretch.x, 1.0, stretch.z)
	for i in range(objectives.size()):
		objectives[i] *= Vector3(stretch.x, 1.0, stretch.z)
	for i in range(patrol_points.size()):
		patrol_points[i] *= Vector3(stretch.x, 1.0, stretch.z)
	killer_spawn *= Vector3(stretch.x, 1.0, stretch.z)
	menu_spawn *= Vector3(stretch.x, 1.0, stretch.z)
	for entry in collision_audit:
		entry.position *= stretch
		entry.size *= stretch

func _school_furnishings() -> void :

	var brass: StandardMaterial3D = _mat(Color("b9a66e"))
	var amber: StandardMaterial3D = _mat(Color("c9ac76"), true)
	for x in [-19.3, 19.3]:
		for z in [-18.3, 16.8]:
			_box(Vector3(0.58, 1.4, 3.1), Vector3(x, 0.7, z), _wood, true)
			_box(Vector3(0.6, 0.07, 3.15), Vector3(x, 1.44, z), brass)
			for offset in [-0.9, 0.0, 0.9]:
				_cylinder(Vector3(x, 1.75, z + offset), 0.13, 0.5, brass, 0.23)
				_box(Vector3(0.3, 0.09, 0.3), Vector3(x, 1.53, z + offset), _ink)
	for x in [-42.3, 42.3]:
		_box(Vector3(0.05, 0.014, 29), Vector3(x, 0.067, 1), brass)
	for z in [-18.0, 16.0]:
		_box(Vector3(79, 0.014, 0.05), Vector3(0, 0.067, z), brass)
	for x in [-16.5, 16.5]:
		for z in [22.5, 24.0, 31.5, 33.0]:
			var side: float = signf(x)
			_box(Vector3(0.56, 2.25, 1.0), Vector3(x, 1.125, z), _blue, true)
			_box(Vector3(0.04, 1.98, 0.85), Vector3(x - side * 0.3, 1.12, z), _mat(Color("56697b")))
			_box(Vector3(0.055, 0.22, 0.035), Vector3(x - side * 0.34, 1.2, z + 0.25), brass)
			for vent in range(3):
				_box(Vector3(0.025, 0.025, 0.52), Vector3(x - side * 0.33, 1.85 + vent * 0.085, z), _ink)
	for z in [-18.0, 16.0]:
		for x in [-9.0, 9.0]:
			_box(Vector3(0.055, 0.25, 0.055), Vector3(x, 3.48, z), _ink)
			_cylinder(Vector3(x, 3.24, z), 0.48, 0.12, _ink, 0.28)
			_cylinder(Vector3(x, 3.17, z), 0.4, 0.04, amber)
	for x in [-9.0, 9.0]:
		_box(Vector3(0.16, 2.4, 0.7), Vector3(x, 1.2, 34.7), _wood)
		_box(Vector3(2.8, 1.8, 0.14), Vector3(x, 2.4, 34.7), _ink)
		_box(Vector3(2.62, 1.64, 0.17), Vector3(x, 2.4, 34.69), _mat(Color("6c7784")))
		_label("CAMPUS\nARCHIVES · AILE NORD\nINFIRMERIE · AILE OUEST\nLABORATOIRE · AILE EST", Vector3(x, 2.42, 34.56), 16, Color("ebdcc1"))
	for x in [-45.78, 45.78]:
		for z in [-11.0, 10.0]:
			_box(Vector3(0.11, 1.6, 2.8), Vector3(x, 2.2, z), _wood)
			for n in range(3):
				var sheet: MeshInstance3D = _box(Vector3(0.14, 0.86, 0.63), Vector3(x - signf(x) * 0.02, 2.2 + 0.12 * sin(n), z - 0.9 + n * 0.9), _cream)
				sheet.rotation.x = (n - 1) * 0.07

	for x in [-7.0, 7.0]:
		var p: Vector3 = Vector3(x, 4.1, -8 if x < 0 else 5)
		for offset in [Vector3(-0.8, 0.1, 0.2), Vector3(0.7, 0.5, -0.2)]:
			_organic(p + offset, Vector3(1.1, 1.3, 1.0), _green)
	_label("COUR DES ORIGAMIS", Vector3(0, 3.5, 11.7), 24, Color("d7cebc"))
	_label("APRÈS LA SONNERIE, LES OMBRES RESTENT.", Vector3(0, 3.1, -35.65), 22, Color("c9b690"))

func _school_expansion_details() -> void :


	var upholstery: StandardMaterial3D = _mat(Color("596b70"))
	for x in [-19.0, 19.0]:
		for z in [-4.0, 8.0]:
			_box(Vector3(1.35, 0.55, 3.3), Vector3(x, 0.275, z), _wood, true)
			_box(Vector3(1.23, 0.15, 3.16), Vector3(x, 0.625, z), upholstery)
			_box(Vector3(0.15, 1.05, 3.35), Vector3(x + signf(x) * 0.63, 0.7, z), _wood, true)
			for side in [-1.0, 1.0]:
				_box(Vector3(1.4, 0.16, 0.14), Vector3(x, 0.89, z + side * 1.6), _cream)
	for x in [-43.0, 43.0]:
		for z in [-8.0, 9.0]:
			_box(Vector3(1.05, 0.8, 1.2), Vector3(x, 0.4, z), _wood, true)
			for offset in [-0.25, 0.25]:
				var leaf: MeshInstance3D = _organic(Vector3(x + offset, 1.35, z), Vector3(0.45, 0.72, 0.45), _green)
				leaf.rotation.z = offset

	for x in [-7.5, 7.5]:
		_box(Vector3(3.4, 0.75, 1.2), Vector3(x, 0.375, 31.8), _wood, true)
		_box(Vector3(3.2, 1.1, 1.1), Vector3(x, 1.3, 31.8), _glass, true)
		for i in range(3):
			var museum_object: MeshInstance3D = _cylinder(Vector3(x - 0.9 + i * 0.9, 1.9, 31.8), 0.16, 0.35, _cream, 0.06)
			museum_object.rotation.z = (i - 1) * 0.16
		_label("TRAVAUX DES ÉLÈVES", Vector3(x, 0.43, 31.17), 15, Color("e3d8bd"), PI)


	for z in [-17.7, 16.8]:
		for x in [-40.0, -25.0, 0.0, 25.0, 40.0]:
			_box(Vector3(0.17, 0.21, 7.2), Vector3(x, 3.55, z), _wood)
	for x in [-44.0, 44.0]:
		for z in [-17.0, 16.5]:
			_box(Vector3(1.35, 1.1, 0.11), Vector3(x, 2.0, z), _ink)
			_box(Vector3(1.22, 0.97, 0.13), Vector3(x, 2.0, z + 0.02), _cream)
			_label("AILE " + ("OUEST" if x < 0 else "EST") + "\n02  —  09", Vector3(x, 2.01, z + 0.1), 14, Color("344151"))

	for p in [Vector3(-7.0, 0, 6.0), Vector3(7.0, 0, -8.0)]:
		var planter: MeshInstance3D = _cylinder(p + Vector3(0, 0.34, 0), 1.1, 0.68, _cream)
		_solid_mesh(planter)
		_cylinder(p + Vector3(0, 0.7, 0), 0.97, 0.05, _mat(Color("536958")))
		for i in range(4):
			_organic(p + Vector3(cos(i * 1.57) * 0.4, 1.2, sin(i * 1.57) * 0.4), Vector3(0.4, 0.5, 0.4), _green)

func _forest_expansion_details() -> void :


	_forest_route(Vector2(12, -8), Vector2(0, 12), 6.0)
	_forest_route(Vector2(0, 12), Vector2(26, 12), 6.0)
	_forest_route(Vector2(0, 12), Vector2(-3, 40), 6.0)
	_forest_route(Vector2(26, 12), Vector2(47, 31), 6.0)
	_forest_route(Vector2(-48, -1), Vector2(-61, 8), 5.0)
	_forest_route(Vector2(-61, 8), Vector2(-48, 22), 5.0)
	_box(Vector3(14, 0.04, 12), Vector3(13, 0.045, 12), _wood)
	_box(Vector3(14, 3.8, 0.26), Vector3(13, 1.9, 6), _wood, true)
	_box(Vector3(14, 3.8, 0.26), Vector3(13, 1.9, 18), _wood, true)
	for x in [6.0, 20.0]:
		for z in [7.15, 16.85]:
			_box(Vector3(0.26, 3.8, 2.3), Vector3(x, 1.9, z), _wood, true)
		_forest_gate(Vector3(x, 0, 12), "z", 6.8)
	_box(Vector3(15, 0.24, 13), Vector3(13, 3.98, 12), _ink, true, false)
	for z in [5.8, 18.2]:
		for x in [8.0, 11.0, 14.0, 17.0]:
			_box(Vector3(0.07, 3.8, 0.3), Vector3(x, 1.9, z), _ink)
	_table(Vector3(13, 0, 7.6), Vector2(3.6, 1.2), _wood)
	_paper_sheet(Vector3(12.1, 1.08, 7.6), 0.25)
	_box(Vector3(2.8, 0.62, 1.5), Vector3(16.8, 0.31, 16.4), _wood, true)
	_box(Vector3(2.72, 0.17, 1.42), Vector3(16.8, 0.7, 16.4), _green)
	_label("REFUGE DES GARDIENS", Vector3(5.82, 3.2, 12), 24, Color("e5d6b7"), - PI * 0.5)
	_forest_lantern(Vector3(9, 0, 16), 0.9)
	patrol_points.append(Vector3(13, 0, 12))

	for i in range(5):
		var p: Vector3 = Vector3(-63, 0.52 + (i / 3) * 0.65, 6 + (i % 3) * 0.84)
		var log_mesh: MeshInstance3D = _cylinder(p, 0.45, 7.5, _wood, 0.4)
		log_mesh.rotation.z = PI * 0.5
		_solid_mesh(log_mesh)
		_cylinder(p + Vector3(3.77, 0, 0), 0.33, 0.025, _cream).rotation.z = PI * 0.5
	_box(Vector3(3.0, 0.8, 1.8), Vector3(-62, 0.75, 14), _wood, true)
	for x in [-63.0, -61.0]:
		for z in [12.9, 15.1]:
			var wheel: MeshInstance3D = _cylinder(Vector3(x, 0.6, z), 0.55, 0.17, _ink)
			wheel.rotation.x = PI * 0.5
			_solid_mesh(wheel)
	_label("ANCIENNE SCIERIE", Vector3(-64, 3.0, 18), 22, Color("dfceb0"))

	_forest_gate(Vector3(-45, 0, 60), "x", 9.0)
	for x in [-51.0, -39.0]:
		_box(Vector3(2.7, 2.5, 0.25), Vector3(x, 1.25, 60), _wood, true)


	for p in [Vector3(-29, 0, -48), Vector3(25, 0, 36), Vector3(-21, 0, 27), Vector3(-56, 0, -10)]:
		for i in range(3):
			_rock(p + Vector3(i * 0.55, 0, sin(i) * 0.4), Vector3(0.65, 0.55 + i * 0.2, 0.7), true, Color("8a9ca0") if _snow else Color("7c8067"))
		for i in range(4):
			var mushroom: Vector3 = p + Vector3(1.5 + i * 0.4, 0, -1.2)
			_cylinder(mushroom + Vector3(0, 0.2, 0), 0.04, 0.4, _cream)
			_organic(mushroom + Vector3(0, 0.41, 0), Vector3(0.19, 0.1, 0.19), _pink)

func _organic(pos: Vector3, radii: Vector3, material: Material) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	var shape: SphereMesh = SphereMesh.new()
	shape.radius = 1.0
	shape.height = 2.0
	shape.radial_segments = 9
	shape.rings = 5
	node.mesh = shape
	node.material_override = material
	node.position = pos
	node.scale = radii
	add_child(node)
	return node

func _solid_mesh(node: MeshInstance3D, nav: bool = true, convex: bool = true) -> void :


	var transformed: SurfaceTool = SurfaceTool.new()
	transformed.begin(Mesh.PRIMITIVE_TRIANGLES)
	for surface_index in range(node.mesh.get_surface_count()):
		transformed.append_from(node.mesh, surface_index, Transform3D(node.basis, Vector3.ZERO))
	var mesh: ArrayMesh = transformed.commit()
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = node.position
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = mesh.create_convex_shape() if convex else mesh.create_trimesh_shape()
	body.add_child(collision)
	add_child(body)
	var bounds: AABB = mesh.get_aabb()
	if nav:
		_obstacles.append(Rect2(node.position.x + bounds.position.x - 0.5, node.position.z + bounds.position.z - 0.5, bounds.size.x + 1, bounds.size.z + 1))
	collision_audit.append({"kind": "mesh", "position": node.position + bounds.get_center(), "size": bounds.size})

func _build_forest(snowy: bool) -> void :
	_snow = snowy
	map_id = "snow" if snowy else "forest"
	map_title = "Forêt enneigée · Les Veilleurs" if snowy else "Forêt des murmures · La Grotte"
	name = map_title
	_rng.seed = 7302026
	_bounds = Rect2(-73.5, -63.5, 147.0, 127.0)
	_nav_region = Rect2i(-75, -65, 151, 131)
	_paper = _mat(Color("bdcbd0") if snowy else Color("979a85"))
	_cream = _mat(Color("bdcdd5") if snowy else Color("d7c5a1"))
	_ink = _mat(Color("23313c") if snowy else Color("232b28"))
	_wood = _mat(Color("655d56") if snowy else Color("665644"))
	_metal = _mat(Color("4d5e68"))
	_glass = _mat(Color("344757"))
	_blue = _mat(Color("81a5b8"))
	_pink = _mat(Color("976c65"))
	_green = _mat(Color("476c67") if snowy else Color("3d6153"))
	_floor = _mat(Color("9eb3bd") if snowy else Color("3e534a"))
	_lamp = _mat(Color("ffdaa2"), true)
	_apply_surface_finishes(true)
	spawn_points = [Vector3(-49, 0.1, 43), Vector3(-45, 0.1, 43), Vector3(-41, 0.1, 43), Vector3(-49, 0.1, 39), Vector3(-45, 0.1, 39), Vector3(-41, 0.1, 39)]
	killer_spawn = Vector3(52, 0.1, -50)
	objectives = [Vector3(-49, 0.05, -33), Vector3(0, 0.05, -38), Vector3(52, 0.05, -45), Vector3(47, 0.05, 31), Vector3(-3, 0.05, 40)]
	patrol_points = [Vector3(-45, 0, 40), Vector3(-47, 0, 0), Vector3(-49, 0, -33), Vector3(0, 0, -38), Vector3(12, 0, -8), Vector3(29, 0, -39), Vector3(52, 0, -45), Vector3(51, 0, -14), Vector3(47, 0, 31), Vector3(-3, 0, 40), Vector3(-13, 0, 5)]
	menu_spawn = Vector3(-45, 0.05, 39)
	_box(Vector3(154, 0.7, 134), Vector3(0, -0.37, 0), _floor, true, false)
	_forest_ground()
	_forest_route(Vector2(-45, 42), Vector2(-48, -33), 7.0)
	_forest_route(Vector2(-48, -33), Vector2(4, -38), 6.5)
	_forest_route(Vector2(4, -38), Vector2(29, -39), 6.5)
	_forest_route(Vector2(-45, 42), Vector2(-3, 40), 7.5)
	_forest_route(Vector2(-3, 40), Vector2(47, 31), 6.5)
	_forest_route(Vector2(47, 31), Vector2(50, -26), 6.5)
	_forest_route(Vector2(-48, -1), Vector2(-13, 5), 7.0)
	_forest_route(Vector2(-13, 5), Vector2(12, -8), 7.0)
	_forest_route(Vector2(12, -8), Vector2(50, -9), 6.5)
	_forest_route(Vector2(-3, 40), Vector2(-13, 5), 6.0)
	_forest_route(Vector2(0, -38), Vector2(12, -8), 6.0)
	_cave()
	_camp()
	_watchtower()
	_ruins()
	_stream_and_bridge()
	_forest_expansion_details()
	_forest_population()
	_forest_perimeter()
	_forest_lighting()
	_rooms = [{"name": "Grotte des échos", "bounds": Rect2(22, -60, 43, 35)}, {"name": "Camp des derniers élèves", "bounds": Rect2(-62, 26, 33, 30)}, {"name": "Tour de veille", "bounds": Rect2(-62, -46, 29, 27)}, {"name": "Cercle des Veilleurs", "bounds": Rect2(-16, -49, 30, 24)}, {"name": "Chapelle oubliée", "bounds": Rect2(32, 17, 31, 32)}, {"name": "Pont du ruisseau", "bounds": Rect2(-28, -7, 33, 25)}, {"name": "Clairière des lanternes", "bounds": Rect2(-18, 27, 31, 29)}, {"name": "Refuge des gardiens", "bounds": Rect2(5, 5, 16, 14)}, {"name": "Ancienne scierie", "bounds": Rect2(-69, -1, 16, 23)}]
	for pos in objectives:
		_box(Vector3(1.3, 0.11, 1.3), pos + Vector3(0, 0.015, 0), _wood)
		_forest_lantern(pos + Vector3(2.4, 0, 1.8), 0.45)
	_stretch_world(Vector3(1.3, 1.0, 1.3))
	_forest_exit()
	_bounds = Rect2(-95.55, -82.55, 191.1, 165.1)
	_nav_region = Rect2i(-98, -85, 197, 171)
	cinematic_anchor = Vector3(-58.5, 0.05, 55.9)
	cinematic_exit = Vector3(-58.5, 0.05, 82.25)
	cinematic_path = [Vector3(-58.5, 0.05, 71.5), Vector3(-58.5, 0.05, 62.4), Vector3(-58.5, 0.05, 53.3)]
	_batch_static_details()
	_prepare_navigation()
	set_process( not _fire_flames.is_empty())

func _forest_exit() -> void :


	var center: Vector3 = Vector3(-58.5, 0, 80.5)
	var warm: StandardMaterial3D = _mat(Color("aa9574"))
	_box(Vector3(7.0, 0.1, 4.0), center + Vector3(0, 0.02, 1.7), _wood, true, false)
	_box(Vector3(6.8, 3.4, 0.22), center + Vector3(0, 1.7, 3.35), warm, true)
	for side in [-1.0, 1.0]:
		_box(Vector3(0.22, 3.4, 3.6), center + Vector3(side * 3.35, 1.7, 1.65), _wood, true)
		_box(Vector3(1.64, 3.4, 0.24), center + Vector3(side * 2.53, 1.7, 0), _wood, true)
		_box(Vector3(0.13, 3.1, 0.35), center + Vector3(side * 1.74, 1.55, 0), _cream)
	_box(Vector3(6.85, 0.5, 0.3), center + Vector3(0, 3.24, 0), _wood, true, false)
	_box(Vector3(7.25, 0.26, 4.25), center + Vector3(0, 3.6, 1.65), _ink, true, false)
	_box(Vector3(3.4, 0.46, 0.08), center + Vector3(0, 3.3, -0.2), _mat(Color("355a4a")))
	_label("REFUGE", center + Vector3(0, 3.32, -0.27), 63, Color("f0eccf"), PI)
	_hinged_exit(center, 3.4, 3.0, _exit_glass())
	_obstacles.append(Rect2(center.x - 2.2, center.z - 0.6, 4.4, 1.2))
	_box(Vector3(2.0, 0.48, 0.65), center + Vector3(1.45, 0.3, 2.7), _wood, true)
	_box(Vector3(1.9, 0.1, 0.62), center + Vector3(1.45, 0.59, 2.7), _cream)
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.position = center + Vector3(0, 2.4, 1.3)
	lamp.light_color = Color("ffd291")
	lamp.light_energy = 2.1
	lamp.omni_range = 9
	add_child(lamp)
	_box(Vector3(0.5, 0.23, 0.5), center + Vector3(0, 3.23, 1.35), _lamp)
	for z in [72.0, 75.0, 78.0]:
		_box(Vector3(4.0, 0.017, 1.6), Vector3(center.x, 0.038, z), _mat(Color("c2c6bf") if _snow else Color("958c76")))
	if _snow:
		_box(Vector3(7.1, 0.14, 4.1), center + Vector3(0, 3.78, 1.65), _cream)

func _forest_ground() -> void :

	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material: StandardMaterial3D = _mat(Color.WHITE)
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_finish(material, "snow" if _snow else "stone", 0.94, Vector3.ONE)
	var base: Color = Color("8099a8") if _snow else Color("405348")
	for x in range(-75, 75, 5):
		for z in range(-65, 65, 5):
			for offset in [Vector2(0, 0), Vector2(0, 5), Vector2(5, 0), Vector2(5, 0), Vector2(0, 5), Vector2(5, 5)]:
				var px: float = x + offset.x
				var pz: float = z + offset.y
				var noise: float = sin(px * 0.13) * cos(pz * 0.11) * 0.06 + sin(px * 0.32 + pz * 0.29) * 0.02
				surface.set_color(base.lightened(maxf(0, noise)).darkened(maxf(0, - noise)))
				surface.set_normal(Vector3.UP)
				surface.set_uv(Vector2(px, pz) * 0.18)
				surface.add_vertex(Vector3(px, 0.007, pz))
	surface.generate_tangents()
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = surface.commit()
	node.material_override = material
	add_child(node)
	var clearing: StandardMaterial3D = _mat(Color("99aeb9") if _snow else Color("59604a"))
	_finish(clearing, "snow" if _snow else "stone", 0.94, Vector3(8, 8, 8))
	for pos in [Vector3(-46, 0.014, 40), Vector3(-49, 0.014, -34), Vector3(0, 0.014, -38), Vector3(47, 0.014, 31), Vector3(-3, 0.014, 40)]:
		var disc: MeshInstance3D = _cylinder(pos, 11.0, 0.01, clearing)
		disc.mesh.radial_segments = 48
		disc.scale.z = 0.85


func ground_patches() -> Dictionary:
	return {"macro_scale": 0.021, "macro_tint": Color(0.9, 0.94, 1.04) if _snow else Color(1.14, 1.07, 0.88), "variation": 0.0}

func _forest_route(start: Vector2, finish: Vector2, width: float) -> void :
	var direction: Vector2 = finish - start
	var count: int = ceili(direction.length() / 3.0)
	var dirt: Color = Color("a3b3bd") if _snow else Color("776d58")

	var edge: Color = _floor.albedo_color if _floor != null else Color("8099a8") if _snow else Color("405348")
	var side: Vector2 = Vector2(direction.y, - direction.x).normalized()
	var centers: Array[Vector2] = []
	var widths: Array[float] = []
	for i in range(count + 1):
		var t: float = float(i) / count
		var point: Vector2 = start.lerp(finish, t) + side * sin(t * PI) * sin(t * TAU * 1.3 + start.x) * 1.15
		centers.append(point)
		widths.append(width * 0.5 + sin(i * 1.7 + start.y) * 0.42)
		_forest_paths.append(point)
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(count):
		var cross_sections: Array = []
		for index in [i, i + 1]:
			var offsets: Array[float] = [ - widths[index] - 1.4, - widths[index], widths[index], widths[index] + 1.4]
			var section: Array[Vector3] = []
			for offset in offsets:
				var point: Vector2 = centers[index] + side * offset
				section.append(Vector3(point.x, 0.028, point.y))
			cross_sections.append(section)
		for band in range(3):
			var colors: Array[Color] = [edge, dirt, dirt, edge]

			for vertex in [Vector2i(0, band), Vector2i(0, band + 1), Vector2i(1, band), Vector2i(0, band + 1), Vector2i(1, band + 1), Vector2i(1, band)]:
				surface.set_color(colors[vertex.y])
				surface.set_normal(Vector3.UP)
				var point: Vector3 = cross_sections[vertex.x][vertex.y]
				surface.set_uv(Vector2(point.x, point.z) * 0.18)
				surface.add_vertex(cross_sections[vertex.x][vertex.y])
	var trail: MeshInstance3D = MeshInstance3D.new()
	trail.mesh = surface.commit()
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material: StandardMaterial3D = _mat(Color.WHITE)
	material.vertex_color_use_as_albedo = true
	_finish(material, "snow" if _snow else "stone", 0.88, Vector3(3, 3, 3))
	_map_uniforms(material, ground_patches())
	trail.material_override = material
	add_child(trail)

func _forest_keep_clear(point: Vector2, radius: float = 4.0) -> bool:
	if Rect2(18, -64, 51, 43).has_point(point):
		return true
	if Rect2(-51, 35, 12, 26).has_point(point) or Rect2(4, 4, 18, 16).has_point(point):
		return true
	for pos in _forest_paths:
		if point.distance_to(pos) < radius + 1.5:
			return true
	for pos in objectives:
		if point.distance_to(Vector2(pos.x, pos.z)) < 11.5:
			return true
	if point.distance_to(Vector2(-45, 40)) < 15 or point.distance_to(Vector2(-14, 5)) < 13:
		return true
	return false

func _solid_trunk(pos: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var trunk: MeshInstance3D = _cylinder(pos + Vector3(0, height * 0.5, 0), radius, height, material, radius * 0.72)
	_solid_mesh(trunk)
	return trunk

func _forest_tree(pos: Vector3, height: float, style: int, collidable: bool = true) -> void :
	var trunk_radius: float = height * 0.046
	if collidable:

		_solid_trunk(pos, trunk_radius, height * 0.68, _wood).free()


	var kind: String = "round" if style % 5 == 0 and not _snow else "pine"
	var yaw: float = fposmod(pos.x * 0.37 + pos.z * 0.61 + style * 1.3, TAU)
	var placement: Transform3D = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * height), pos)
	var shade: float = 0.86 + 0.14 * _batch_seed(pos)
	_add_tree_instance(kind, placement, Color(shade, shade + 0.02 * float(style % 3), shade, 1.0))

func _add_tree_instance(kind: String, placement: Transform3D, tint: Color) -> void :
	var chunk: Vector2i = Vector2i(floori(placement.origin.x / TREE_CHUNK), floori(placement.origin.z / TREE_CHUNK))
	var key: String = kind + "/" + str(chunk)
	if not _tree_batches.has(key):
		_tree_batches[key] = {"kind": kind, "transforms": [], "tints": []}
	_tree_batches[key].transforms.append(placement)
	_tree_batches[key].tints.append(tint)



func _flush_tree_batches() -> void :
	for key: String in _tree_batches:
		var batch: Dictionary = _tree_batches[key]
		var transforms: Array = batch.transforms
		var geometry: MultiMesh = MultiMesh.new()
		geometry.transform_format = MultiMesh.TRANSFORM_3D
		geometry.use_colors = true
		geometry.mesh = _tree_mesh(str(batch.kind))
		geometry.instance_count = transforms.size()
		for index in range(transforms.size()):
			geometry.set_instance_transform(index, transforms[index])
			geometry.set_instance_color(index, batch.tints[index])
		var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
		node.name = "Arbres"
		node.multimesh = geometry
		node.material_override = _tree_material()
		add_child(node)
	_tree_batches.clear()

func _tree_material() -> StandardMaterial3D:
	if not _tree_meshes.has("material"):
		var material: StandardMaterial3D = _mat(Color.WHITE, false, false)
		material.vertex_color_use_as_albedo = true
		_finish(material, "stone", 0.98, Vector3(4, 4, 4))
		_map_uniforms(material, {"variation": 0.0})
		_tree_meshes["material"] = material
	return _tree_meshes["material"]


func _tree_mesh(kind: String) -> ArrayMesh:
	if _tree_meshes.has(kind):
		return _tree_meshes[kind]
	var merged: MergedMesh = MergedMesh.new()
	merged.use_colors = true
	var reference: float = 13.0
	var bark: Color = _wood.albedo_color if _wood != null else Color("75583f")
	var leaf: Color = Color("3a5d41") if not _snow else Color("33545a")
	var snow_cap: Color = _cream.albedo_color if _cream != null else Color("cbd9de")
	var trunk: CylinderMesh = CylinderMesh.new()
	trunk.bottom_radius = 0.046
	trunk.top_radius = 0.046 * 0.72
	trunk.height = 0.68
	trunk.radial_segments = 8
	trunk.rings = 0
	trunk.cap_bottom = false
	merged.append(_tinted(trunk.get_mesh_arrays(), bark), Transform3D(Basis(), Vector3(0, 0.34, 0)), Vector2.ZERO)
	for side in [-1.0, 1.0]:
		var branch: CylinderMesh = CylinderMesh.new()
		branch.bottom_radius = 0.046 * 0.42
		branch.top_radius = 0.02 / reference
		branch.height = 0.23
		branch.radial_segments = 6
		branch.rings = 0
		merged.append(_tinted(branch.get_mesh_arrays(), bark), Transform3D(Basis(Vector3.BACK, side * -1.02), Vector3(side * 0.09, 0.37, 0)), Vector2.ZERO)
	if kind == "round":
		var blob: SphereMesh = SphereMesh.new()
		blob.radial_segments = 9
		blob.rings = 5
		for offset: Vector3 in [Vector3(-0.8, -0.2, 0), Vector3(0.9, 0.4, 0.4), Vector3(0, 1.1, -0.8)]:
			var shape: Transform3D = Transform3D(Basis.from_scale(Vector3(0.25, 0.23, 0.24)), Vector3(0, 0.72, 0) + offset / reference)
			merged.append(_tinted(blob.get_mesh_arrays(), leaf), shape, Vector2.ZERO)
	else:
		for tier in range(4):
			var radius: float = 0.25 - tier * 0.046
			var y: float = 0.38 + tier * 0.14
			var spin: Basis = Basis(Vector3.UP, tier * 0.67)
			merged.append(_tinted(_crown_arrays(radius, 0.37, tier * 2.1, reference), leaf), Transform3D(spin, Vector3(0, y, 0)), Vector2.ZERO)
			if _snow:
				merged.append(_tinted(_crown_arrays(radius * 0.91, 0.25, tier * 2.1, reference), snow_cap), Transform3D(spin, Vector3(0, y + 0.069, 0)), Vector2.ZERO)
	var mesh: ArrayMesh = merged.commit()
	_tree_meshes[kind] = mesh
	return mesh

func _tinted(arrays: Array, color: Color) -> Array:
	var colors: PackedColorArray = PackedColorArray()
	colors.resize(arrays[Mesh.ARRAY_VERTEX].size())
	colors.fill(color)
	arrays[Mesh.ARRAY_COLOR] = colors
	return arrays


func _crown_arrays(radius: float, height: float, variation: float, reference: float) -> Array:
	var primitive: CylinderMesh = CylinderMesh.new()
	primitive.bottom_radius = radius
	primitive.top_radius = 0.045 / reference
	primitive.height = height
	primitive.radial_segments = 10
	primitive.rings = 1
	primitive.cap_top = false
	var arrays: Array = primitive.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in range(vertices.size()):
		var vertex: Vector3 = vertices[i]
		var angle: float = atan2(vertex.z, vertex.x)
		var t: float = clampf(vertex.y / height + 0.5, 0, 1)
		var spread: float = 1.0 + sin(angle * 5.0 + variation) * 0.1 + sin(angle * 9.0 - variation * 1.7) * 0.055
		vertex.x *= spread
		vertex.z *= spread
		vertex.y += (1.0 - t) * sin(angle * 6.0 + variation) * height * 0.065
		vertices[i] = vertex
	arrays[Mesh.ARRAY_VERTEX] = vertices
	return arrays

func _pine_crown(pos: Vector3, radius: float, height: float, material: Material, variation: float) -> MeshInstance3D:


	var primitive: CylinderMesh = CylinderMesh.new()
	primitive.bottom_radius = radius
	primitive.top_radius = 0.045
	primitive.height = height
	primitive.radial_segments = 16
	primitive.rings = 3
	var arrays: Array = primitive.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in range(vertices.size()):
		var vertex: Vector3 = vertices[i]
		var angle: float = atan2(vertex.z, vertex.x)
		var t: float = clampf(vertex.y / height + 0.5, 0, 1)
		var spread: float = 1.0 + sin(angle * 5.0 + variation) * 0.1 + sin(angle * 9.0 - variation * 1.7) * 0.055
		vertex.x *= spread
		vertex.z *= spread
		vertex.y += (1.0 - t) * sin(angle * 6.0 + variation) * height * 0.065
		vertices[i] = vertex
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	add_child(instance)
	return instance

func _rock(pos: Vector3, dimensions: Vector3, collision: bool = true, tint: Color = Color("65716d")) -> void :
	var material: StandardMaterial3D = _mat(tint)
	_finish(material, "stone", 0.93)
	var rock: MeshInstance3D = _organic(pos + Vector3(0, dimensions.y * 0.42, 0), dimensions * Vector3(0.58, 0.65, 0.58), material)
	rock.rotation.y = _rng.randf_range( - PI, PI)
	if collision:
		_solid_mesh(rock)
	if _snow:
		_organic(pos + Vector3(0, dimensions.y * 0.82, 0), dimensions * Vector3(0.51, 0.15, 0.51), _cream)

func _forest_population() -> void :
	var count: int = 0
	for attempt in range(1500):
		if count >= 225:
			break
		var pos: Vector2 = Vector2(_rng.randf_range(-71, 71), _rng.randf_range(-61, 61))
		if _forest_keep_clear(pos, 3.0):
			continue
		if not can_walk(Vector3(pos.x, 0, pos.y)):
			continue
		_forest_tree(Vector3(pos.x, 0, pos.y), _rng.randf_range(7.0, 13.5), count)
		count += 1
	for i in range(68):
		var pos: Vector2 = Vector2(_rng.randf_range(-68, 68), _rng.randf_range(-58, 58))
		if _forest_keep_clear(pos, 4.0):
			continue
		_rock(Vector3(pos.x, 0, pos.y), Vector3(_rng.randf_range(2, 4.5), _rng.randf_range(1.4, 3.0), _rng.randf_range(2, 4.0)), true, Color("788994") if _snow else Color("626c60"))
	var grass: StandardMaterial3D = _mat(Color("6a8b89") if _snow else Color("678068"))
	for i in range(130):
		var p: Vector3 = Vector3(_rng.randf_range(-71, 71), 0, _rng.randf_range(-60, 60))
		if _forest_keep_clear(Vector2(p.x, p.z), 1.5):
			continue
		for blade in range(3):
			var plant: MeshInstance3D = _cylinder(p + Vector3((blade - 1) * 0.24, 0.3, 0), 0.17, 0.6, grass, 0.015)
			plant.rotation.z = (blade - 1) * -0.27

func _forest_perimeter() -> void :


	for x in [-75.0, 75.0]:
		_palisade(Vector3(x, 0, -65), Vector3(x, 0, 65))
		for z in range(-66, 68, 7):
			_rock(Vector3(x + signf(x) * 3.5, 0, z), Vector3(8, _rng.randf_range(11, 17), 10), true, Color("697e87") if _snow else Color("495c53"))
			_forest_tree(Vector3(x - signf(x) * 1.6, 0, z + 3), _rng.randf_range(12, 18), z, true)
	for z in [-65.0, 65.0]:
		_palisade(Vector3(-75, 0, z), Vector3(75, 0, z))
		for x in range(-72, 75, 8):
			_rock(Vector3(x, 0, z + signf(z) * 3.5), Vector3(11, _rng.randf_range(10, 17), 8), true, Color("6f8289") if _snow else Color("4c5e54"))
			_forest_tree(Vector3(x, 0, z - signf(z) * 1.5), _rng.randf_range(12, 17), x, true)

func _palisade(start: Vector3, finish: Vector3) -> void :
	var along_x: bool = absf(finish.x - start.x) > absf(finish.z - start.z)
	var length: float = start.distance_to(finish)
	var center: Vector3 = (start + finish) * 0.5
	var wooden_wall: MeshInstance3D = _box(Vector3(length + 0.1, 3.0, 0.24) if along_x else Vector3(0.24, 3.0, length + 0.1), center + Vector3(0, 1.5, 0), _wood, true)
	wooden_wall.name = "Palissade solide visible"
	for y in [0.3, 1.4, 2.55]:
		_box(Vector3(length, 0.16, 0.34) if along_x else Vector3(0.34, 0.16, length), center + Vector3(0, y, 0), _ink)
	for index in range(ceili(length / 0.7) + 1):
		var point: Vector3 = start.lerp(finish, minf(1, index * 0.7 / length))
		_box(Vector3(0.045, 3.0, 0.28) if along_x else Vector3(0.28, 3.0, 0.045), point + Vector3(0, 1.5, 0), _ink)
		_cylinder(point + Vector3(0, 3.14, 0), 0.17, 0.28, _wood, 0.01)

func _forest_gate(pos: Vector3, axis: String, width: float = 6.8) -> void :
	doors.append({"id": doors.size(), "position": pos, "axis": axis, "width": width})
	var across_x: bool = axis == "x"
	for side in [-1.0, 1.0]:
		var offset: Vector3 = Vector3(side * (width * 0.5 + 0.18), 1.7, 0) if across_x else Vector3(0, 1.7, side * (width * 0.5 + 0.18))
		_box(Vector3(0.35, 3.4, 0.35), pos + offset, _wood, true)
	var beam_size: Vector3 = Vector3(width + 0.8, 0.4, 0.45) if across_x else Vector3(0.45, 0.4, width + 0.8)
	_box(beam_size, pos + Vector3(0, 3.6, 0), _wood)
	_box(Vector3(width, 0.025, 0.15) if across_x else Vector3(0.15, 0.025, width), pos + Vector3(0, 0.04, 0), _cream)

func _cave() -> void :
	var stone: StandardMaterial3D = _mat(Color("65747e") if _snow else Color("515d5c"))
	var stone_floor: StandardMaterial3D = _mat(Color("78949f") if _snow else Color("64675b"))
	_finish(stone, "stone", 0.84, Vector3(2, 2, 2))
	_finish(stone_floor, "stone", 0.64, Vector3(8, 8, 8))
	_box(Vector3(43, 0.02, 35), Vector3(43.5, 0.023, -42.5), stone_floor)
	_cave_wall(Vector3(45, 10, 3), Vector3(43.5, 5, -60), stone)
	_cave_wall(Vector3(3, 10, 36), Vector3(65, 5, -42.5), stone)
	_cave_wall(Vector3(3, 9, 18.5), Vector3(22, 4.5, -50.75), stone)
	_cave_wall(Vector3(3, 9, 10.5), Vector3(22, 4.5, -30.25), stone)
	_cave_wall(Vector3(25.6, 9, 3), Vector3(34.8, 4.5, -25), stone)
	_cave_wall(Vector3(11.6, 9, 3), Vector3(59.2, 4.5, -25), stone)
	_box(Vector3(46, 2.2, 38), Vector3(43.5, 9, -42.5), stone, true, false)
	_forest_gate(Vector3(22, 0, -38.5), "z", 6.8)
	_forest_gate(Vector3(50.5, 0, -25), "x", 6.8)
	for x in range(25, 66, 7):
		_rock(Vector3(x, 7.8, -53), Vector3(13, _rng.randf_range(5, 9), 15), false, Color("7a8d96") if _snow else Color("657066"))
		_rock(Vector3(x, 7.7, -34), Vector3(12, _rng.randf_range(3, 6), 13), false, Color("70838d") if _snow else Color("59665f"))
	_rock(Vector3(40, 0, -44), Vector3(8.5, 7.3, 8.5), true, Color("546976") if _snow else Color("46524f"))
	_rock(Vector3(59, 0, -31), Vector3(4.5, 5.4, 4.5), true)
	for x in [28.0, 35.0, 43.0, 53.0, 60.0]:
		for z in [-56.0, -29.0]:
			var stalactite: MeshInstance3D = _cylinder(Vector3(x, 6.8, z), 0.025, 2.7, _cream if _snow else stone, 0.75)
			stalactite.rotation.z = sin(x) * 0.1
	for p in [Vector3(27, 0, -46), Vector3(58, 0, -53), Vector3(32, 0, -29)]:
		for i in range(3):
			var crystal: MeshInstance3D = _cylinder(p + Vector3(i * 0.35, 0.7 + i * 0.15, 0), 0.26, 1.4 + i * 0.3, _blue, 0.01)
			crystal.rotation.z = (i - 1) * 0.3
		_forest_lantern(p + Vector3(0.7, 0, 0.5), 0.9, Color("a8d1ed"))
	_label("GROTTE DES ÉCHOS", Vector3(50.5, 3.15, -23.38), 30, Color("ccdbd9"))

	for p in [Vector3(30, 5, -39), Vector3(53, 5, -45), Vector3(50, 5, -30)]:
		var light: OmniLight3D = OmniLight3D.new()
		light.position = p
		light.light_color = Color("a9c9d7") if _snow else Color("c8d1bd")
		light.light_energy = 0.7
		light.omni_range = 20
		light.omni_attenuation = 1.2
		add_child(light)
		_box(Vector3(0.035, 3.6, 0.035), p + Vector3.UP * 1.8, _metal)
		_box(Vector3(0.6, 0.12, 0.6), p + Vector3.UP * 0.24, _ink)
		_box(Vector3(0.26, 0.32, 0.26), p, _mat(Color("9ebad0"), true))

func _cave_wall(size: Vector3, pos: Vector3, material: Material) -> void :

	var along_x: bool = size.x > size.z
	var length: float = size.x if along_x else size.z
	var thickness: float = size.z if along_x else size.x
	var columns: int = ceili(length / 2.5)
	var rows: int = 5
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		for col in range(columns):
			for row in range(rows):
				var offsets: Array[Vector2i] = [Vector2i(col, row), Vector2i(col + 1, row), Vector2i(col, row + 1), Vector2i(col + 1, row), Vector2i(col + 1, row + 1), Vector2i(col, row + 1)]
				if side < 0:
					offsets.reverse()
				for cell in offsets:
					var horizontal: float = float(cell.x) / columns * length - length * 0.5
					var y: float = float(cell.y) / rows * size.y - size.y * 0.5
					var amount: float = 0.16 if cell.y == 0 else 0.45
					var depth: float = side * (thickness * 0.5 + sin(cell.x * 1.67 + cell.y * 2.87 + pos.x) * amount)
					surface.set_uv(Vector2(horizontal, y) * 0.22)
					surface.add_vertex(Vector3(horizontal, y, depth) if along_x else Vector3(depth, y, - horizontal))
	surface.generate_normals()
	surface.index()
	surface.generate_tangents()
	var cliff: MeshInstance3D = MeshInstance3D.new()
	cliff.mesh = surface.commit()
	cliff.material_override = material
	cliff.position = pos
	add_child(cliff)
	_solid_mesh(cliff, true, false)

	for side in [-1.0, 1.0]:
		var offset: Vector3 = Vector3(side * length * 0.5, 0, 0) if along_x else Vector3(0, 0, side * length * 0.5)
		_box(Vector3(0.04, size.y, thickness) if along_x else Vector3(thickness, size.y, 0.04), pos + offset, material, true, false)

func _tent(pos: Vector3, color: Color) -> void :
	var canvas: StandardMaterial3D = _mat(color)
	var tent: PrismMesh = PrismMesh.new()
	tent.size = Vector3(5.0, 3.0, 4.8)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = tent
	mesh.position = pos + Vector3(0, 1.5, 0)
	mesh.material_override = canvas
	add_child(mesh)
	_solid_mesh(mesh)
	_box(Vector3(0.08, 2.5, 0.1), pos + Vector3(0, 1.25, 2.45), _wood)
	_box(Vector3(1.7, 2.1, 0.015), pos + Vector3(0, 1.05, 2.42), _ink)
	for side in [-1.0, 1.0]:
		var line: MeshInstance3D = _box(Vector3(0.04, 3.8, 0.04), pos + Vector3(side * 2.8, 1.1, 2.0), _cream)
		line.rotation.z = side * 0.65
	if _snow:
		_organic(pos + Vector3(-0.55, 2.5, 0), Vector3(1.3, 0.4, 2.2), _cream)

func _camp() -> void :
	_tent(Vector3(-56, 0, 32), Color("61756b"))
	_tent(Vector3(-36, 0, 50), Color("977f66"))
	_table(Vector3(-58, 0, 45), Vector2(3.8, 1.6), _wood)
	_box(Vector3(3.8, 0.4, 0.5), Vector3(-58, 0.45, 47), _wood, true)
	_cylinder(Vector3(-35, 0.12, 35), 2.0, 0.24, _ink)
	for i in range(10):
		var angle: float = TAU * i / 10.0
		_organic(Vector3(-35 + cos(angle) * 2.0, 0.3, 35 + sin(angle) * 2.0), Vector3(0.4, 0.3, 0.32), _paper)
	for side in [-1.0, 1.0]:
		var log_node: MeshInstance3D = _cylinder(Vector3(-35, 0.4, 35 + side * 0.25), 0.18, 2.2, _wood)
		log_node.rotation.z = PI * 0.5
		log_node.rotation.y = side * 0.4
	var fire: Node3D = Node3D.new()
	fire.name = "Braises animées"
	add_child(fire)
	for i in range(6):
		var ember: StandardMaterial3D = _mat(Color("d34b17") if i % 2 == 0 else Color("ea871b"), true)
		ember.emission_energy_multiplier = 0.75
		var flame: MeshInstance3D = _organic(Vector3(-35 + sin(i * 2.4) * 0.27, 0.63 + (i % 3) * 0.13, 35 + cos(i * 2.4) * 0.26), Vector3(0.18 + i * 0.014, 0.45 + (i % 3) * 0.12, 0.2), ember)
		flame.reparent(fire)
		flame.set_meta("base_scale", flame.scale)
		_fire_flames.append(flame)
	_forest_lantern(Vector3(-37, 0, 36), 1.2, Color("ffc587"))
	_forest_gate(Vector3(-45, 0, 25), "x", 6.8)
	_label("CAMP DES DERNIERS ÉLÈVES", Vector3(-45, 3.1, 25.24), 24, Color("e4d7be"))
	for pos in [Vector3(-61, 0, 51), Vector3(-59, 0, 53), Vector3(-30, 0, 45)]:
		_box(Vector3(1.9, 1.7, 1.7), pos + Vector3(0, 0.85, 0), _wood, true)
		for y in [0.35, 1.4]:
			_box(Vector3(1.96, 0.12, 1.76), pos + Vector3(0, y, 0), _ink)

func _watchtower() -> void :

	for x in [-58.0, -50.0]:
		for z in [-43.0, -38.0]:
			_box(Vector3(0.55, 7.3, 0.55), Vector3(x, 3.65, z), _wood, true)
	_box(Vector3(9.2, 0.35, 6.2), Vector3(-54, 4.8, -40.5), _wood, true, false)
	_box(Vector3(9.6, 0.3, 6.7), Vector3(-54, 7.3, -40.5), _wood)
	for y in [5.2, 5.9]:
		_box(Vector3(9, 0.12, 0.12), Vector3(-54, y, -43.4), _cream)
		_box(Vector3(9, 0.12, 0.12), Vector3(-54, y, -37.6), _cream)
		_box(Vector3(0.12, 0.12, 5.7), Vector3(-58.4, y, -40.5), _cream)
		_box(Vector3(0.12, 0.12, 5.7), Vector3(-49.6, y, -40.5), _cream)
	_box(Vector3(5.2, 1.8, 1.4), Vector3(-42, 0.9, -40), _wood, true)
	_forest_gate(Vector3(-48.5, 0, -22), "x", 6.8)
	_label("TOUR DE VEILLE", Vector3(-48.5, 3.12, -21.73), 27)
	_forest_lantern(Vector3(-52.5, 0, -24), 0.6)

	for i in range(7):
		var angle: float = - PI + i * PI / 3.0
		var pos: Vector3 = Vector3(cos(angle) * 8.0, 0, -38 + sin(angle) * 8.0)
		if absf(pos.x) < 3 or pos.z > -32:
			continue
		_rock(pos, Vector3(1.7, 4.6 + (i % 3) * 0.8, 1.6), true, Color("799196") if _snow else Color("7b8070"))
	_cylinder(Vector3(0, 0.04, -38), 6.5, 0.035, _ink)
	_cylinder(Vector3(0, 0.064, -38), 6.18, 0.012, _mat(Color("a3b7bf") if _snow else Color("69705b")))

func _ruins() -> void :
	var stone: StandardMaterial3D = _mat(Color("8c9fa4") if _snow else Color("7c8172"))
	_box(Vector3(21, 0.025, 22), Vector3(47, 0.044, 31), _mat(Color("9baeb3") if _snow else Color("666a5c")))
	for x in [36.5, 57.5]:
		for z in [22.0, 40.0]:
			_box(Vector3(1.3, 5.0, 1.3), Vector3(x, 2.5, z), stone, true)
		_box(Vector3(1.0, 3.8, 5.5), Vector3(x, 1.9, 30), stone, true)
	for z in [20.0, 42.0]:
		_box(Vector3(7.0, 3.6, 0.9), Vector3(40.0, 1.8, z), stone, true)
		_box(Vector3(7.0, 4.4, 0.9), Vector3(54.0, 2.2, z), stone, true)
		_forest_gate(Vector3(47, 0, z), "x", 6.8)
	for x in [39.0, 55.0]:
		_box(Vector3(3.2, 0.8, 0.7), Vector3(x, 0.4, 28), _wood, true)
		_box(Vector3(3.2, 0.8, 0.7), Vector3(x, 0.4, 35), _wood, true)
	_box(Vector3(4.4, 0.12, 0.3), Vector3(47, 5.2, 41.8), stone)
	_box(Vector3(0.3, 2.4, 0.3), Vector3(47, 5.0, 41.8), stone)
	_label("CHAPELLE OUBLIÉE", Vector3(47, 3.05, 20.24), 27)
	for pos in [Vector3(36.5, 0, 18), Vector3(57.5, 0, 44)]:
		_forest_lantern(pos, 0.7)

	for x in [-10.0, 6.0]:
		_solid_trunk(Vector3(x, 0, 43), 0.21, 5.0, _wood)
	_box(Vector3(16, 0.055, 0.055), Vector3(-2, 4.8, 43), _wood)
	for x in [-8.0, -3.0, 2.0]:
		_box(Vector3(0.35, 0.5, 0.35), Vector3(x, 4.45, 43), _lamp)
	for p in [Vector3(-13, 0, 47), Vector3(8, 0, 33)]:
		_box(Vector3(5.0, 1.4, 1.0), p + Vector3(0, 0.7, 0), stone, true)

func _stream_and_bridge() -> void :

	var water: StandardMaterial3D = _mat(Color("6d9bac") if _snow else Color("365e61"))
	_finish(water, "stone", 0.23, Vector3(6, 6, 6))
	water.normal_scale = 0.12
	water.roughness = 0.23
	water.metallic = 0.22
	for i in range(7):
		var p: Vector3 = Vector3(-23.0 + i * 4.0, 0.034, -9.0 + i * 5.8)
		var stream: MeshInstance3D = _cylinder(p, 6.7, 0.021, water)
		stream.mesh.radial_segments = 36
		stream.scale = Vector3(0.67, 1.0, 1.0)
		stream.rotation.y = -0.5
	for x in range(-24, -4):
		_box(Vector3(0.93, 0.075, 6.0), Vector3(x + 0.4, 0.071, 5), _wood)
	for z in [2.0, 8.0]:
		_box(Vector3(18.5, 0.13, 0.13), Vector3(-14.4, 1.35, z), _wood, true)
		_box(Vector3(18.5, 0.1, 0.1), Vector3(-14.4, 0.65, z), _wood, true)
		for x in [-23.0, -14.0, -5.8]:
			_box(Vector3(0.25, 1.55, 0.25), Vector3(x, 0.775, z), _wood, true)
	_forest_gate(Vector3(-24.5, 0, 5), "z", 6.8)
	_forest_gate(Vector3(-4.5, 0, 5), "z", 6.8)
	_forest_lantern(Vector3(-25.5, 0, 9.5), 0.6)
	_forest_lantern(Vector3(-3.5, 0, 0.5), 0.6)

func _forest_lantern(pos: Vector3, energy: float = 0.55, color: Color = Color("ffb36b")) -> void :
	_box(Vector3(0.1, 2.5, 0.1), pos + Vector3(0, 1.25, 0), _wood, true)
	_box(Vector3(0.5, 0.07, 0.5), pos + Vector3(0, 2.75, 0), _ink)
	_box(Vector3(0.31, 0.55, 0.31), pos + Vector3(0, 2.43, 0), _lamp)
	_box(Vector3(0.43, 0.07, 0.43), pos + Vector3(0, 2.12, 0), _ink)
	for x in [-0.18, 0.18]:
		for z in [-0.18, 0.18]:
			_box(Vector3(0.035, 0.56, 0.035), pos + Vector3(x, 2.43, z), _ink)
	var light: OmniLight3D = OmniLight3D.new()
	light.position = pos + Vector3(0, 2.5, 0)
	light.light_color = color

	light.light_energy = energy * 1.1
	light.omni_range = 12
	light.omni_attenuation = 1.3
	light.distance_fade_enabled = true
	light.distance_fade_begin = 42.0
	light.distance_fade_length = 10.0
	add_child(light)

func _forest_lighting() -> void :
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.name = "Lune nocturne"
	moon.rotation_degrees = Vector3(-36, -34, 0)
	moon.light_color = Color("8ea9d0") if _snow else Color("7e98b9")
	moon.light_energy = 0.23 if _snow else 0.2
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 160
	add_child(moon)
	for pos in [Vector3(-46, 0, 15), Vector3(-43, 0, -12), Vector3(-22, 0, -33), Vector3(14, 0, -34), Vector3(14, 0, -4), Vector3(48, 0, 8), Vector3(23, 0, 35), Vector3(-24, 0, 38)]:
		_forest_lantern(pos)




func _batch_static_details(sector_size: float = BATCH_SECTOR, flat_sector: float = -1.0) -> void :
	_flush_tree_batches()
	var sources: Array[MeshInstance3D] = []
	for child in get_children():
		if not child is MeshInstance3D or child.get_child_count() > 0 or not child.visible:
			continue
		if child.mesh == null or child.material_override == null or child.has_meta("paper_unbatched"):
			continue
		sources.append(child)
	var groups: Dictionary = {}
	for source: MeshInstance3D in sources:
		var bounds: AABB = source.transform * source.mesh.get_aabb()
		var extent: float = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
		var small: bool = extent < SMALL_PROP

		var tag: Vector2 = Vector2(_contact_base(bounds) + 1000.0, _batch_seed(source.position) if extent < 4.0 else 0.5)


		var size: float = flat_sector if flat_sector > 0.0 and source.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF else sector_size
		for piece: Dictionary in _batch_pieces(source, bounds):
			var center: Vector3 = piece.bounds.get_center()
			var cell: Vector3i = Vector3i(floori(center.x / size), floori(center.y / BATCH_LEVEL), floori(center.z / size))
			var key: String = str(source.material_override.get_instance_id()) + "/" + str(source.cast_shadow) + "/" + str(small) + "/" + str(cell)
			if not groups.has(key):
				groups[key] = {"material": source.material_override, "shadow": source.cast_shadow, "small": small, "pieces": [], "bounds": piece.bounds}
			var group: Dictionary = groups[key]
			piece["tag"] = tag
			group.pieces.append(piece)
			group.bounds = group.bounds.merge(piece.bounds)
	var consumed: Dictionary = {}
	for key: String in groups:
		var group: Dictionary = groups[key]
		var pieces: Array = group.pieces
		if pieces.size() == 1 and not bool(pieces[0].split):
			if group.small:
				_prop_range(pieces[0].node)
			continue
		var origin: Vector3 = group.bounds.get_center()
		var merged: MergedMesh = MergedMesh.new()
		for piece: Dictionary in pieces:
			for arrays: Array in piece.arrays:
				if arrays[Mesh.ARRAY_COLOR] != null:
					merged.use_colors = true
		for piece: Dictionary in pieces:
			var local: Transform3D = Transform3D(Basis(), - origin) * piece.transform
			for arrays: Array in piece.arrays:
				merged.append(arrays, local, piece.tag)
			consumed[piece.node] = true
		var combined: MeshInstance3D = MeshInstance3D.new()
		combined.name = "Décor regroupé"
		combined.mesh = merged.commit()
		combined.material_override = group.material
		combined.cast_shadow = group.shadow
		combined.position = origin
		if group.small:
			_prop_range(combined)
		add_child(combined)
	for source: MeshInstance3D in consumed:
		source.free()


func _batch_pieces(source: MeshInstance3D, bounds: AABB) -> Array:
	var box: BoxMesh = source.mesh as BoxMesh
	if box != null and source.transform.basis.is_equal_approx(Basis.IDENTITY) and (box.size.x > BATCH_PIECE * 1.2 or box.size.z > BATCH_PIECE * 1.2):
		var counts: Vector2i = Vector2i(maxi(1, ceili(box.size.x / BATCH_PIECE)), maxi(1, ceili(box.size.z / BATCH_PIECE)))
		var piece_size: Vector3 = Vector3(box.size.x / counts.x, box.size.y, box.size.z / counts.y)
		var piece_mesh: BoxMesh = BoxMesh.new()
		piece_mesh.size = piece_size
		var surfaces: Array = [piece_mesh.get_mesh_arrays()]
		var pieces: Array = []
		for ix in range(counts.x):
			for iz in range(counts.y):
				var center: Vector3 = bounds.position + Vector3(piece_size.x * (ix + 0.5), box.size.y * 0.5, piece_size.z * (iz + 0.5))
				pieces.append({"node": source, "arrays": surfaces, "transform": Transform3D(Basis(), center), "bounds": AABB(center - piece_size * 0.5, piece_size), "split": true})
		return pieces
	var arrays_list: Array = []
	for index in range(source.mesh.get_surface_count()):
		arrays_list.append(source.mesh.surface_get_arrays(index))
	return [{"node": source, "arrays": arrays_list, "transform": source.transform, "bounds": bounds, "split": false}]


func _contact_base(bounds: AABB) -> float:
	var bottom: float = bounds.position.y
	for level: float in floor_levels:
		if absf(bottom - level) < 0.15:
			return bottom
	return -100.0

func _batch_seed(p: Vector3) -> float:
	return fposmod(sin(p.x * 12.9898 + p.y * 78.233 + p.z * 37.719) * 43758.5453, 1.0)

func _prop_range(node: GeometryInstance3D) -> void :
	node.visibility_range_end = PROP_RANGE
	node.visibility_range_end_margin = 4.0


func follow_camera(node: Node3D) -> void :
	_ambient_particles.append(node)
	set_process(true)

func ambient_particles() -> Array[Node3D]:
	return _ambient_particles

func _ready() -> void :

	set_process(false)

func _process(delta: float) -> void :
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera != null:
		for node: Node3D in _ambient_particles:
			if is_instance_valid(node):
				var offset: Vector3 = node.get_meta("follow_offset", Vector3.ZERO)
				node.global_position = camera.global_position + offset
	if _fire_flames.is_empty():
		return
	_scenery_time += delta
	for i in range(_fire_flames.size()):
		var flame: MeshInstance3D = _fire_flames[i]
		var base: Vector3 = flame.get_meta("base_scale")
		flame.scale = base * Vector3(1.0 + sin(_scenery_time * 6.0 + i * 1.6) * 0.12, 1.0 + sin(_scenery_time * 9.0 + i * 2.3) * 0.23, 1.0)


class MergedMesh extends RefCounted:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var uv2s: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()
	var use_colors: bool = false

	func append(arrays: Array, xform: Transform3D, tag: Vector2) -> void :
		var source_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var source_normals: PackedVector3Array = PackedVector3Array()
		if arrays[Mesh.ARRAY_NORMAL] != null:
			source_normals = arrays[Mesh.ARRAY_NORMAL]
		var source_uvs: PackedVector2Array = PackedVector2Array()
		if arrays[Mesh.ARRAY_TEX_UV] != null:
			source_uvs = arrays[Mesh.ARRAY_TEX_UV]
		var source_colors: PackedColorArray = PackedColorArray()
		if arrays[Mesh.ARRAY_COLOR] != null:
			source_colors = arrays[Mesh.ARRAY_COLOR]

		var normal_basis: Basis = xform.basis.inverse().transposed()
		var start: int = vertices.size()
		var count: int = source_vertices.size()
		for i in range(count):
			vertices.append(xform * source_vertices[i])
			normals.append((normal_basis * source_normals[i]).normalized() if i < source_normals.size() else Vector3.UP)
			uvs.append(source_uvs[i] if i < source_uvs.size() else Vector2.ZERO)
			uv2s.append(tag)
			if use_colors:
				colors.append(source_colors[i] if i < source_colors.size() else Color.WHITE)
		var source_indices: PackedInt32Array = PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			source_indices = arrays[Mesh.ARRAY_INDEX]
		if source_indices.is_empty():
			for i in range(count):
				indices.append(start + i)
		else:
			for index: int in source_indices:
				indices.append(start + index)

	func commit() -> ArrayMesh:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_TEX_UV2] = uv2s
		if use_colors:
			arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh: ArrayMesh = ArrayMesh.new()
		if not vertices.is_empty():
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh
