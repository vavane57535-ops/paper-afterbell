extends RefCounted

const STEP: float = 2.0
const RADIUS: float = 0.58
const BODY_HEIGHT: float = 2.25
const NAV_REVISION: int = 6
var school: Node3D
var surfaces: Array[Dictionary] = []
var solids: Array[AABB] = []
var ramps: Array[Dictionary] = []
var zones: Array[Dictionary] = []
var graph: AStar3D = AStar3D.new()
var cells: Dictionary = {}
var solid_cells: Dictionary = {}
var bounds: Rect2
var navigation_report: Dictionary = {}
var upper_targets: Array[Vector3] = []
var rooms_audit: Array[Dictionary] = []
var jump_links: Array[Dictionary] = []


var exit_point: Vector3 = Vector3.ZERO
var outlets: Array[Vector3] = []
var portable_outlets: bool = true
var _ground_material: StandardMaterial3D
var _stone: StandardMaterial3D
var _wall: StandardMaterial3D
var _trim: StandardMaterial3D
var _wood: StandardMaterial3D
var _warm: StandardMaterial3D
var _cool: StandardMaterial3D


var _ceiling: StandardMaterial3D
var _window: StandardMaterial3D
var _upper: StandardMaterial3D
var _wainscot: StandardMaterial3D

const MOON: Dictionary = {
	"school": {"rotation": Vector3(-42, -32, 0), "color": Color("b4c2e0"), "energy": 0.16, "shadow": false}, 
	"forest": {"rotation": Vector3(-40, -32, 0), "color": Color("9db8e6"), "energy": 0.45, "shadow": true}, 
	"snow": {"rotation": Vector3(-40, -32, 0), "color": Color("a9c3ee"), "energy": 0.5, "shadow": true}, 
}
const LAMP_COLOR: Color = Color("ffd49c")

const ZONE_TINTS: Dictionary = {
	"Classe de Miss Circle": Color("7b8171"), "Classe de Miss Thavel": Color("6f7788"), 
	"Infirmerie": Color("7f9590"), "Vestiaires": Color("6b776e"), "Hall d'entrée": Color("7a7078"), 
	"Laboratoire de Miss Bloomie": Color("6b8274"), "Atrium · Grand escalier": Color("6e6a78"), 
	"Couloir des casiers": Color("5f6474"), 
	"Bibliothèque": Color("857761"), "Atelier d'art": Color("8a7176"), "Gymnase": Color("857a66"), 
	"Laboratoire": Color("6b808b"), "Cantine": Color("8a8066"), "Bassin vidé": Color("688091"), 
	"Grand hall des élèves": Color("78757c"), "Cour des origamis": Color("5d6865"), 
	"Salle des trophées": Color("776c7e"), "Salle des clubs": Color("6b776e"), 
}

func build(owner_school: Node3D, selected_map: String) -> void :
	school = owner_school
	school.map_id = "school" if selected_map == "school" else "forest" if selected_map == "forest" else "snow"
	school._snow = school.map_id == "snow"
	school._rng.seed = 90032026
	school.spawn_points.clear()
	school.objectives.clear()
	school.patrol_points.clear()
	school.doors.clear()
	school._rooms.clear()
	school._obstacles.clear()
	school.collision_audit.clear()
	_materials()
	if school.map_id == "school":
		preload("res://map_school.gd").new().build(self)
	elif school.map_id == "forest":
		preload("res://map_forest.gd").new().build(self)
	else:
		preload("res://map_snow.gd").new().build(self)
	school._bounds = bounds
	_index_solids()
	school._batch_static_details(20.0 if school.map_id == "school" else 30.0, -1.0 if school.map_id == "school" else 60.0)
	_navigation()
	school.name = school.map_title

func _materials() -> void :
	var snow: bool = school._snow
	var indoor: bool = school.map_id == "school"

	_ground_material = school._mat(Color("91a4b2") if snow else Color("3d4f43") if not indoor else Color("626878"), false, false)
	_stone = school._mat(Color("657b8b") if snow else Color("596766"))
	_wall = school._mat(Color("d8d0c1") if indoor else Color("a6a9b3"))
	_trim = school._mat(Color("24212a") if indoor else Color("242d3b"))
	_wood = school._mat(Color("75583f"))
	_warm = school._mat(Color("ffd9a0"), true)
	_warm.emission_energy_multiplier = 2.6
	_cool = school._mat(Color("56657f"))
	_ceiling = school._mat(Color("5d5c75"), false, false)
	_upper = school._mat(Color("a49b8b"), false, false)
	_wainscot = school._mat(Color("9d8f7c"))
	_window = school._mat(Color("37557c"), true, false)
	_window.emission = Color("5a82c2")
	_window.emission_energy_multiplier = 0.75
	for pair in [[_ground_material, "snow" if snow else "stone"], [_stone, "stone"], [_wall, "plaster"], [_wood, "wood"], [_ceiling, "plaster"], [_upper, "wood"], [_wainscot, "wood"]]:
		school._finish(pair[0], pair[1], 0.85, Vector3(3, 3, 3))
	school._map_uniforms(_ceiling, {"light_gain": 0.35})
	if indoor:

		school._map_uniforms(_ground_material, {"grid_spacing": 6.0, "grid_width": 0.05, "grid_color": Color(0.12, 0.11, 0.15, 0.6)})
	else:
		school._map_uniforms(_ground_material, school.ground_patches())
	school._paper = _wall
	school._cream = school._mat(Color("cbd9de") if snow else Color("d0c8b6"))
	school._ink = _trim
	school._wood = _wood
	school._metal = school._mat(Color("576273"))
	school._glass = school._mat(Color("364c63"))
	school._blue = _cool
	school._pink = school._mat(Color("926a72"))
	school._green = school._mat(Color("526e64"))
	school._floor = _ground_material
	school._lamp = _warm

func _box(size: Vector3, pos: Vector3, material: Material, solid: bool = true, nav: bool = true) -> MeshInstance3D:
	var node: MeshInstance3D = school._box(size, pos, material, solid, false)

	for child in node.get_children():
		if child is StaticBody3D:
			child.reparent(school, true)
	if solid and nav:
		solids.append(AABB(pos - size * 0.5, size))
	return node

func _floor(rect: Rect2, height: float, material: Material, thickness: float = 0.4, mass: bool = false) -> void :
	surfaces.append({"rect": rect, "height": height})
	var thick: float = height if mass and height > 0.0 else thickness
	if not school.floor_levels.has(height):
		school.floor_levels.append(height)

	var count_x: int = maxi(1, ceili(rect.size.x / 24.0))
	var count_z: int = maxi(1, ceili(rect.size.y / 24.0))
	var tile: Vector2 = rect.size / Vector2(count_x, count_z)
	for x in range(count_x):
		for z in range(count_z):
			var center: Vector2 = rect.position + Vector2(x + 0.5, z + 0.5) * tile
			var slab: MeshInstance3D = _box(Vector3(tile.x, thick, tile.y), Vector3(center.x, height - thick * 0.5, center.y), material, true, mass)

			if height <= 0.0:
				slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	if school.map_id == "school" and height >= 3.0 and not mass:
		_occluder(Vector3(rect.size.x, thick, rect.size.y), Vector3(rect.get_center().x, height - thick * 0.5, rect.get_center().y))


func _occluder(size: Vector3, center: Vector3) -> void :
	if school.map_id != "school":
		return
	var shape: BoxOccluder3D = BoxOccluder3D.new()
	shape.size = size
	var occluder: OccluderInstance3D = OccluderInstance3D.new()
	occluder.occluder = shape
	occluder.position = center
	school.add_child(occluder)

func _ramp(start: Vector3, finish: Vector3, width: float, material: Material) -> void :

	var along_z: bool = absf(finish.z - start.z) > absf(finish.x - start.x)
	var half_side: Vector3 = Vector3(width * 0.5, 0, 0) if along_z else Vector3(0, 0, width * 0.5)
	var low: float = minf(start.y, finish.y) - 0.3
	var points: PackedVector3Array = [start - half_side, start + half_side, finish - half_side, finish + half_side, 
		Vector3(start.x, low, start.z) - half_side, Vector3(start.x, low, start.z) + half_side, 
		Vector3(finish.x, low, finish.z) - half_side, Vector3(finish.x, low, finish.z) + half_side]
	var triangles: Array[int] = [0, 2, 1, 1, 2, 3, 4, 5, 6, 5, 7, 6, 0, 1, 4, 1, 5, 4, 2, 6, 3, 3, 6, 7, 0, 4, 2, 2, 4, 6, 1, 3, 5, 3, 7, 5]
	var builder: SurfaceTool = SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centroid: Vector3 = Vector3.ZERO
	for p in points:
		centroid += p / points.size()
	for index in range(0, triangles.size(), 3):
		var a: Vector3 = points[triangles[index]]
		var b: Vector3 = points[triangles[index + 1]]
		var c: Vector3 = points[triangles[index + 2]]

		if (b - a).cross(c - a).dot((a + b + c) / 3.0 - centroid) > 0:
			var swap: Vector3 = b
			b = c
			c = swap
		var normal: Vector3 = (c - a).cross(b - a).normalized()
		for p in [a, b, c]:
			builder.set_normal(normal)
			builder.set_uv(Vector2(p.x, p.z) * 0.2)
			builder.add_vertex(p)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = builder.commit()
	mesh.material_override = material
	school.add_child(mesh)
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape: CollisionShape3D = CollisionShape3D.new()
	var convex: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	convex.points = points
	shape.shape = convex
	body.add_child(shape)
	mesh.add_child(body)
	var rectangle: Rect2 = Rect2(Vector2(minf(start.x, finish.x), minf(start.z, finish.z)), Vector2(absf(finish.x - start.x), absf(finish.z - start.z)))
	if along_z:
		rectangle.position.x -= width * 0.5
		rectangle.size.x = width
	else:
		rectangle.position.y -= width * 0.5
		rectangle.size.y = width
	var data: Dictionary = {"rect": rectangle, "start": start, "finish": finish, "along_z": along_z}
	ramps.append(data)
	surfaces.append(data)
	school.collision_audit.append({"kind": "om_visible_ramp", "position": (start + finish) * 0.5, "size": Vector3(rectangle.size.x, absf(finish.y - start.y) + 0.3, rectangle.size.y), "start": start, "finish": finish})

	for i in range(1, int(start.distance_to(finish) / 1.5)):
		if school.map_id != "school" and i % 5 != 0:
			continue
		var t: float = i * 1.5 / start.distance_to(finish)
		var p: Vector3 = start.lerp(finish, t) + Vector3(0, 0.012, 0)
		_box(Vector3(width - 0.4, 0.013, 0.05) if along_z else Vector3(0.05, 0.013, width - 0.4), p, school._cream if school.map_id == "school" else _wood, false)





func _partition(a: Vector3, b: Vector3, openings: Array = [], height: float = 4.8, door_width: float = 6.0, material: Material = null, door_height: float = 3.65) -> void :
	var along_x: bool = absf(b.x - a.x) > absf(b.z - a.z)
	var start: float = minf(a.x, b.x) if along_x else minf(a.z, b.z)
	var end: float = maxf(a.x, b.x) if along_x else maxf(a.z, b.z)
	var wall_material: Material = _wall if material == null else material
	var half: float = door_width * 0.5
	var cursor: float = start
	var segments: Array[Vector2] = []
	for value in openings:
		segments.append(Vector2(cursor, value - half))
		cursor = value + half
		var p: Vector3 = Vector3(value, a.y, a.z) if along_x else Vector3(a.x, a.y, value)
		school.doors.append({"id": school.doors.size(), "position": p, "axis": "x" if along_x else "z", "width": door_width})
		_box(Vector3(door_width, 0.5, 0.56) if along_x else Vector3(0.56, 0.5, door_width), p + Vector3(0, door_height + 0.25, 0), _trim)
		var filler: float = height - door_height - 0.5
		if filler > 0.05:
			var filler_size: Vector3 = Vector3(door_width, filler, 0.5) if along_x else Vector3(0.5, filler, door_width)
			_box(filler_size, p + Vector3(0, door_height + 0.5 + filler * 0.5, 0), wall_material, true, false)

		for side in [-1.0, 1.0]:
			var post: Vector3 = p + (Vector3(side * half, door_height * 0.5, 0) if along_x else Vector3(0, door_height * 0.5, side * half))
			_box(Vector3(0.14, door_height, 0.58) if along_x else Vector3(0.58, door_height, 0.14), post, _trim, false)
	segments.append(Vector2(cursor, end))
	for segment in segments:
		if segment.y - segment.x < 0.01:
			continue
		var size: Vector3 = Vector3(segment.y - segment.x, height, 0.5) if along_x else Vector3(0.5, height, segment.y - segment.x)
		var center: Vector3 = Vector3((segment.x + segment.y) * 0.5, a.y + height * 0.5, a.z) if along_x else Vector3(a.x, a.y + height * 0.5, (segment.x + segment.y) * 0.5)
		_box(size, center, wall_material)
		_box(Vector3(size.x + 0.02, 0.16, size.z + 0.02), center + Vector3(0, 1.1 - height * 0.5, 0), _trim, false)
		_box(Vector3(size.x + 0.03, 0.1, size.z + 0.03), center + Vector3(0, 0.05 - height * 0.5, 0), _trim, false)

		if school.map_id == "school" and height >= 3.0:
			_box(Vector3(size.x + 0.012, 1.0, size.z + 0.012), center + Vector3(0, 0.55 - height * 0.5, 0), _wainscot, false)
		if segment.y - segment.x >= 2.0:
			_occluder(size, center)

func _rail(a: Vector3, b: Vector3) -> void :
	school.grind_rails.append({"from": a + Vector3.UP * 1.15, "to": b + Vector3.UP * 1.15})
	var difference: Vector3 = b - a
	var along_x: bool = absf(difference.x) > absf(difference.z)
	var length: float = difference.length()
	_box(Vector3(length, 0.18, 0.18) if along_x else Vector3(0.18, 0.18, length), (a + b) * 0.5 + Vector3(0, 1.05, 0), _trim)
	for i in range(ceili(length / 2.5) + 1):
		var p: Vector3 = a.lerp(b, float(i) / maxf(1, ceili(length / 2.5)))
		_box(Vector3(0.14, 1.05, 0.14), p + Vector3(0, 0.52, 0), _trim)

func _zone(title: String, rect: Rect2, height: float) -> void :
	zones.append({"name": title, "rect": rect, "height": height})

func _lamp(p: Vector3, energy: float = 0.6, radius: float = 15.0) -> void :
	_box(Vector3(0.7, 0.18, 0.7), p, _warm, false)
	var light: OmniLight3D = OmniLight3D.new()
	light.position = p - Vector3(0, 0.3, 0)
	light.light_color = LAMP_COLOR



	light.light_energy = energy * 0.8
	light.omni_range = minf(radius * 0.72, p.y - 0.6) if p.y > 7.0 else radius * 0.72
	light.omni_attenuation = 0.9
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 40.0
	light.distance_fade_length = 10.0
	school.add_child(light)


func _paint_zone_map() -> void :
	var size: Vector2i = Vector2i(int(bounds.size.x), int(bounds.size.y))
	var image: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var painted: Array[Dictionary] = []
	for zone: Dictionary in zones:
		if float(zone.height) == 0.0 and ZONE_TINTS.has(zone.name):
			painted.append(zone)

	painted.sort_custom( func(a: Dictionary, b: Dictionary) -> bool: return a.rect.get_area() > b.rect.get_area())
	for zone: Dictionary in painted:
		var tint: Color = ZONE_TINTS[zone.name]
		tint.a = 0.92
		var rect: Rect2 = zone.rect
		var area: Rect2i = Rect2i(Vector2i(rect.position - bounds.position), Vector2i(rect.size)).intersection(Rect2i(Vector2i.ZERO, size))
		image.fill_rect(area, tint)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	school._map_uniforms(_ground_material, {"zoned": true, "zone_map": texture, "zone_rect": Vector4(bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y)})


func _school_exit_at(center: Vector3) -> void :
	_box(Vector3(16, 4.5, 0.5), center + Vector3(0, 2.25, 5), _wall)
	for side in [-1.0, 1.0]:
		_box(Vector3(0.5, 4.5, 6), center + Vector3(side * 8, 2.25, 2.5), _wall)
		_box(Vector3(5, 4.5, 0.4), center + Vector3(side * 5.5, 2.25, 0), _wall)
	_box(Vector3(6, 0.6, 0.4), center + Vector3(0, 4.2, 0), _trim)
	school._hinged_exit(center, 6.0, 3.9, school._exit_glass())

	solids.append(AABB(center + Vector3(-3.2, 0, -0.3), Vector3(6.4, 3.9, 0.6)))
	_lamp(center + Vector3(0, 3.8, 2), 1.1, 12)
	school._label("SORTIE", center + Vector3(0, 4.3, -0.3), 52, Color("d7e5cb"), PI)



func _ambient_particles() -> void :
	if DisplayServer.get_name() == "headless":
		return
	var snow: bool = school._snow
	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.name = "Neige" if snow else "Lucioles"

	var dot: SphereMesh = SphereMesh.new()
	dot.radius = 0.05 if snow else 0.07
	dot.height = dot.radius * 2.0
	dot.radial_segments = 4 if snow else 6
	dot.rings = 2 if snow else 3
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.8, 0.85, 0.95) if snow else Color(3.2, 2.7, 1.1)
	material.disable_receive_shadows = true
	dot.material = material
	particles.mesh = dot
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.local_coords = false
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	if snow:
		particles.amount = 800
		particles.lifetime = 7.0
		particles.emission_box_extents = Vector3(18, 0.5, 18)
		particles.direction = Vector3(0.15, -1, 0.05)
		particles.spread = 10.0
		particles.gravity = Vector3(0, -0.3, 0)
		particles.initial_velocity_min = 1.2
		particles.initial_velocity_max = 1.8
		particles.set_meta("follow_offset", Vector3(0, 8.5, 0))
	else:
		particles.amount = 70
		particles.lifetime = 6.0
		particles.emission_box_extents = Vector3(20, 1.4, 20)
		particles.direction = Vector3(0, 1, 0)
		particles.spread = 180.0
		particles.gravity = Vector3.ZERO
		particles.initial_velocity_min = 0.15
		particles.initial_velocity_max = 0.45
		var fade: Curve = Curve.new()
		fade.add_point(Vector2(0.0, 0.0))
		fade.add_point(Vector2(0.25, 1.0))
		fade.add_point(Vector2(0.7, 1.0))
		fade.add_point(Vector2(1.0, 0.0))
		particles.scale_amount_curve = fade
		particles.set_meta("follow_offset", Vector3(0, -0.4, 0))
	particles.preprocess = particles.lifetime
	school.add_child(particles)
	school.follow_camera(particles)

func _moon() -> void :
	var settings: Dictionary = MOON.get(school.map_id, MOON.forest)
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.name = "Lune"
	moon.rotation_degrees = settings.rotation
	moon.light_color = settings.color
	moon.light_energy = float(settings.energy)


	moon.shadow_enabled = bool(settings.shadow)
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	moon.directional_shadow_max_distance = 58.0
	moon.directional_shadow_blend_splits = true
	moon.directional_shadow_fade_start = 0.85
	moon.shadow_blur = 1.2
	school.add_child(moon)

func _height(surface: Dictionary, p: Vector2) -> float:
	if not surface.has("start"):
		return float(surface.height)
	var a: Vector3 = surface.start
	var b: Vector3 = surface.finish
	var t: float = (p.y - a.z) / (b.z - a.z) if surface.along_z else (p.x - a.x) / (b.x - a.x)
	return lerpf(a.y, b.y, clampf(t, 0, 1))

func _surface_at(p: Vector2, height: float, tolerance: float = 0.13) -> bool:
	for surface in surfaces:
		if surface.rect.grow(0.015).has_point(p) and absf(_height(surface, p) - height) < tolerance:
			return true
	return false

func _track_audit(start: int) -> void :
	for index in range(start, school.collision_audit.size()):
		var entry: Dictionary = school.collision_audit[index]
		solids.append(AABB(entry.position - entry.size * 0.5, entry.size))

func _index_solids() -> void :
	for obstacle in solids:
		for x in range(floori((obstacle.position.x - RADIUS) / 12.0), floori((obstacle.end.x + RADIUS) / 12.0) + 1):
			for z in range(floori((obstacle.position.z - RADIUS) / 12.0), floori((obstacle.end.z + RADIUS) / 12.0) + 1):
				var key: Vector2i = Vector2i(x, z)
				if not solid_cells.has(key):
					solid_cells[key] = []
				solid_cells[key].append(obstacle)

func can_walk(point: Vector3) -> bool:
	var p: Vector2 = Vector2(point.x, point.z)
	if not bounds.grow( - RADIUS).has_point(p) or not _surface_at(p, point.y):
		return false

	for offset in [Vector2(RADIUS, 0), Vector2( - RADIUS, 0), Vector2(0, RADIUS), Vector2(0, - RADIUS)]:
		if not _surface_at(p + offset, point.y, 0.23):
			return false

	var step: float = 0.08
	for ramp in ramps:
		if ramp.rect.has_point(p) and absf(_height(ramp, p) - point.y) < 0.13:
			step = 0.3
			break
	for obstacle: AABB in solid_cells.get(Vector2i(floori(point.x / 12.0), floori(point.z / 12.0)), []):
		if point.y + BODY_HEIGHT <= obstacle.position.y + 0.025 or point.y >= obstacle.end.y - step:
			continue
		if Rect2(obstacle.position.x - RADIUS, obstacle.position.z - RADIUS, obstacle.size.x + RADIUS * 2, obstacle.size.z + RADIUS * 2).has_point(p):
			return false
	for ramp in ramps:
		if ramp.rect.grow(RADIUS * 0.9).has_point(p):
			var y: float = _height(ramp, p)
			if point.y < y - 0.025 and point.y + BODY_HEIGHT > minf(ramp.start.y, ramp.finish.y) - 0.3:
				return false
	return true

func _segment_walkable(a: Vector3, b: Vector3) -> bool:
	var n: int = maxi(2, ceili(a.distance_to(b) / 0.45))
	for index in range(n + 1):
		if not can_walk(a.lerp(b, float(index) / n)):
			return false
	return true

func _navigation() -> void :
	var started: int = Time.get_ticks_msec()
	var cache_path: String = "res://maps/om_" + school.map_id + "_navigation.res"
	if ResourceLoader.exists(cache_path) and not OS.get_cmdline_user_args().has("--maps-rebuild-nav"):
		var cache: Resource = load(cache_path)
		if cache.revision == NAV_REVISION:
			for id in range(cache.points.size()):
				var point: Vector3 = cache.points[id]
				graph.add_point(id, point)
				var cell: Vector2i = Vector2i(roundi(point.x), roundi(point.z))
				if not cells.has(cell):
					cells[cell] = []
				cells[cell].append(id)
			for index in range(0, cache.connections.size(), 2):
				graph.connect_points(cache.connections[index], cache.connections[index + 1])
			_jump_connections()
			navigation_report = {"nodes": graph.get_point_count(), "surfaces": surfaces.size(), "ramps": ramps.size(), "size": [bounds.size.x, bounds.size.y], "build_ms": Time.get_ticks_msec() - started, "vertical": true, "baked": true, "rooms": rooms_audit.size(), "jump_links": jump_links.size()}
			return
	var next_id: int = 0
	for x in range(int(bounds.position.x) + 2, int(bounds.end.x), 2):
		for z in range(int(bounds.position.y) + 2, int(bounds.end.y), 2):
			var cell: Vector2i = Vector2i(x, z)
			var heights: Array[float] = []
			for surface in surfaces:
				if not surface.rect.grow(0.015).has_point(Vector2(x, z)):
					continue
				var height: float = _height(surface, Vector2(x, z))
				if heights.has(height):
					continue
				heights.append(height)
				var point: Vector3 = Vector3(x, height, z)
				if can_walk(point):
					graph.add_point(next_id, point)
					if not cells.has(cell):
						cells[cell] = []
					cells[cell].append(next_id)
					next_id += 1
	for cell in cells:
		for offset in [Vector2i(2, 0), Vector2i(0, 2), Vector2i(2, 2), Vector2i(-2, 2)]:
			if not cells.has(cell + offset):
				continue
			for a_id in cells[cell]:
				for b_id in cells[cell + offset]:
					var a: Vector3 = graph.get_point_position(a_id)
					var b: Vector3 = graph.get_point_position(b_id)
					if absf(a.y - b.y) <= 0.8 and _segment_walkable(a, b):
						graph.connect_points(a_id, b_id)
	_jump_connections()
	var pruned: int = _prune_islands()
	navigation_report = {"nodes": graph.get_point_count(), "surfaces": surfaces.size(), "ramps": ramps.size(), "size": [bounds.size.x, bounds.size.y], "build_ms": Time.get_ticks_msec() - started, "vertical": true, "baked": false, "rooms": rooms_audit.size(), "jump_links": jump_links.size(), "pruned": pruned}




func _prune_islands() -> int:
	if graph.get_point_count() == 0 or school.spawn_points.is_empty():
		return 0
	var seed_id: int = _closest_point(school.spawn_points[0])
	var reached: Dictionary = {seed_id: true}
	var queue: Array[int] = [seed_id]
	while not queue.is_empty():
		var id: int = queue.pop_back()
		for neighbor: int in graph.get_point_connections(id):
			if not reached.has(neighbor):
				reached[neighbor] = true
				queue.append(neighbor)
	var removed: int = 0
	for id: int in graph.get_point_ids():
		if reached.has(id):
			continue
		var p: Vector3 = graph.get_point_position(id)
		var cell: Vector2i = Vector2i(roundi(p.x), roundi(p.z))
		if cells.has(cell):
			cells[cell].erase(id)
			if cells[cell].is_empty():
				cells.erase(cell)
		graph.remove_point(id)
		removed += 1
	return removed

func save_navigation_cache() -> Error:
	var cache: Resource = preload("res://om_navigation_cache.gd").new()
	cache.revision = NAV_REVISION
	var points: PackedVector3Array = PackedVector3Array()
	var connections: PackedInt32Array = PackedInt32Array()

	var index_of: Dictionary = {}
	for id in graph.get_point_ids():
		index_of[id] = points.size()
		points.append(graph.get_point_position(id))
	var jumps: Dictionary = {}
	for link in jump_links:
		if link.get("added", false):
			jumps[Vector2i(mini(link.from_id, link.to_id), maxi(link.from_id, link.to_id))] = true
	for id in graph.get_point_ids():
		for neighbor in graph.get_point_connections(id):

			if neighbor > id and not jumps.has(Vector2i(id, neighbor)):
				connections.append(index_of[id])
				connections.append(index_of[neighbor])
	cache.points = points
	cache.connections = connections
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://maps"))
	return ResourceSaver.save(cache, "res://maps/om_" + school.map_id + "_navigation.res", ResourceSaver.FLAG_COMPRESS)

func nav_path(from: Vector3, to: Vector3, blocked_door: int = -1) -> PackedVector3Array:
	if graph.get_point_count() == 0:
		return PackedVector3Array()
	var disabled: Array[int] = []
	if blocked_door >= 0 and blocked_door < school.doors.size():
		var door: Dictionary = school.doors[blocked_door]
		var position: Vector3 = door.position
		var half_span: float = float(door.get("width", 6.0)) * 0.5 + RADIUS
		var extent: int = ceili(half_span) + 1
		for x in range(roundi(position.x) - extent, roundi(position.x) + extent + 1):
			for z in range(roundi(position.z) - extent, roundi(position.z) + extent + 1):
				for id in cells.get(Vector2i(x, z), []):
					var point: Vector3 = graph.get_point_position(id)
					if absf(point.y - position.y) > 1.0:
						continue
					var d: Vector3 = point - position
					if (absf(d.z) < 1.3 and absf(d.x) < half_span) if door.axis == "x" else (absf(d.x) < 1.3 and absf(d.z) < half_span):
						graph.set_point_disabled(id, true)
						disabled.append(id)
	var start: int = _closest_point(from)
	var finish: int = _closest_point(to)
	var result: PackedVector3Array = graph.get_point_path(start, finish)
	for id in disabled:
		graph.set_point_disabled(id, false)
	return result



func _closest_point(p: Vector3) -> int:
	if cells.is_empty():
		return graph.get_closest_point(p)
	var cx: int = 2 * roundi(p.x * 0.5)
	var cz: int = 2 * roundi(p.z * 0.5)
	var best: int = -1
	var best_distance: float = INF
	var limit: int = int(maxf(bounds.size.x, bounds.size.y)) + 2
	for ring in range(limit):
		if best >= 0:

			var reach: float = maxf(0.0, ring * 2.0 - 1.0)
			if reach * reach > best_distance:
				break
		for dx in range( - ring, ring + 1):
			var edge_column: bool = absi(dx) == ring
			for dz in range( - ring, ring + 1):
				if not edge_column and absi(dz) != ring:
					continue
				var ids: Variant = cells.get(Vector2i(cx + dx * 2, cz + dz * 2))
				if ids == null:
					continue
				for id: int in ids:
					if graph.is_point_disabled(id):
						continue
					var distance: float = p.distance_squared_to(graph.get_point_position(id))
					if distance < best_distance or (distance == best_distance and id < best):
						best = id
						best_distance = distance
	return best if best >= 0 else graph.get_closest_point(p)

func room_name(pos: Vector3) -> String:
	for zone in zones:
		if absf(pos.y - float(zone.height)) < 2 and zone.rect.has_point(Vector2(pos.x, pos.z)):
			return zone.name
	return "Campus · Étage" if school.map_id == "school" and pos.y > 3 else "Campus · Rez-de-chaussée" if school.map_id == "school" else "Forêt · Hautes corniches" if pos.y > 2 else "Forêt · Sentiers bas"

func _jump_link(a: Vector3, b: Vector3) -> void :
	jump_links.append({"start": a, "finish": b})
	jump_links.append({"start": b, "finish": a})


func _drop_link(a: Vector3, b: Vector3) -> void :
	jump_links.append({"start": a, "finish": b})

func _jump_connections() -> void :
	for link in jump_links:
		var a_id: int = _closest_point(link.start)
		var b_id: int = _closest_point(link.finish)
		if a_id < 0 or b_id < 0:
			continue
		var a: Vector3 = graph.get_point_position(a_id)
		var b: Vector3 = graph.get_point_position(b_id)
		if a.distance_to(link.start) > 1.2 or b.distance_to(link.finish) > 1.2:
			continue
		link.start = a
		link.finish = b
		link.from_id = a_id
		link.to_id = b_id

		if not graph.are_points_connected(a_id, b_id, false):
			graph.connect_points(a_id, b_id, false)
			link.added = true

func jump_hint(from: Vector3, to: Vector3) -> Vector3:

	for link in jump_links:
		if not link.has("from_id") or from.distance_to(link.start) > 1.2:
			continue
		if to.distance_to(link.finish) + 2.5 < to.distance_to(link.start):
			return link.finish
	return Vector3.ZERO
