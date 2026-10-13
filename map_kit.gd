extends RefCounted












var L: RefCounted
var S: Node3D
var _palette: Dictionary = {}

const FACING_YAW: Dictionary = {"s": 0.0, "n": PI, "e": PI * 0.5, "w": - PI * 0.5}
const FACING_DIR: Dictionary = {"s": Vector3(0, 0, 1), "n": Vector3(0, 0, -1), "e": Vector3(1, 0, 0), "w": Vector3(-1, 0, 0)}

func _init(layout: RefCounted) -> void :
	L = layout
	S = layout.school


func mat(key: String) -> Material:
	if _palette.has(key):
		return _palette[key]
	var material: Material
	match key:
		"wall": material = L._wall
		"trim": material = L._trim
		"wood": material = L._wood
		"cream": material = S._cream
		"metal": material = S._metal
		"blue": material = L._cool
		"green": material = S._green
		"pink": material = S._pink
		"glass": material = S._glass
		"lamp": material = L._warm
		"window": material = L._window
		"stone": material = L._stone
		"red": material = S._mat(Color("9a3b4c"))
		"carpet": material = S._mat(Color("6a2c38"))
		"board": material = S._mat(Color("2f463d"))
		"chalk": material = S._mat(Color("e6e1d2"))
		"yellow": material = S._mat(Color("c79d4f"))
		"dark": material = S._mat(Color("2c2e3b"))
		"orange": material = S._mat(Color("b86a3c"))
		"leaf": material = S._mat(Color("3f6b4a"))
		"vend_red":
			var glow: StandardMaterial3D = S._mat(Color("d4556a"), true)
			glow.emission_energy_multiplier = 1.5
			material = glow
		"vend_blue":
			var glow_blue: StandardMaterial3D = S._mat(Color("5c8fd6"), true)
			glow_blue.emission_energy_multiplier = 1.5
			material = glow_blue
		"alarm":
			var alarm: StandardMaterial3D = S._mat(Color("c43d4f"), true)
			alarm.emission_energy_multiplier = 2.2
			material = alarm
		_: material = L._wall
	_palette[key] = material
	return material



func deco(size: Vector3, pos: Vector3, key: String) -> MeshInstance3D:
	return L._box(size, pos, mat(key), false)

func solid(size: Vector3, pos: Vector3, key: String, nav: bool = true) -> MeshInstance3D:
	return L._box(size, pos, mat(key), true, nav)


func blocker(size: Vector3, pos: Vector3, nav: bool = true) -> void :
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	S.add_child(body)
	S.collision_audit.append({"kind": "box", "position": pos, "size": size})
	if nav:
		L.solids.append(AABB(pos - size * 0.5, size))


func oriented(width: float, height: float, depth: float, facing: String) -> Vector3:
	return Vector3(width, height, depth) if facing in ["n", "s"] else Vector3(depth, height, width)


func along(facing: String, amount: float, side: float = 0.0) -> Vector3:
	var front: Vector3 = FACING_DIR[facing]
	var lateral: Vector3 = Vector3(front.z, 0, - front.x)
	return front * amount + lateral * side

func sign_text(text_value: String, pos: Vector3, facing: String, size: int = 34, color: Color = Color("e7e0d1")) -> Label3D:
	var label: Label3D = S._label(text_value, pos, size, color, FACING_YAW[facing])
	return label

func cylinder(pos: Vector3, radius: float, height: float, key: String, top: float = -1.0) -> MeshInstance3D:
	return S._cylinder(pos, radius, height, mat(key), top)

func blob(pos: Vector3, radii: Vector3, key: String) -> MeshInstance3D:
	return S._organic(pos, radii, mat(key))




func ceiling_lamp(pos: Vector3, energy: float = 0.7, radius: float = 14.0, color: Color = Color("ffd49c"), along_x: bool = true) -> OmniLight3D:
	deco(Vector3(2.4, 0.12, 0.5) if along_x else Vector3(0.5, 0.12, 2.4), pos, "trim")
	deco(Vector3(2.2, 0.06, 0.34) if along_x else Vector3(0.34, 0.06, 2.2), pos - Vector3(0, 0.08, 0), "lamp")
	var light: OmniLight3D = OmniLight3D.new()

	light.position = pos - Vector3(0, 1.1, 0)
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.omni_attenuation = 0.9
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 40.0
	light.distance_fade_length = 10.0
	S.add_child(light)
	return light


func accent_light(pos: Vector3, color: Color, energy: float, radius: float) -> OmniLight3D:
	var light: OmniLight3D = OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.omni_attenuation = 1.2
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 34.0
	light.distance_fade_length = 8.0
	S.add_child(light)
	return light




func window(center: Vector3, facing: String, width: float = 3.0, height: float = 2.2) -> void :
	var offset: Vector3 = along(facing, 0.02)
	deco(oriented(width + 0.3, height + 0.3, 0.06, facing), center + offset, "trim")
	deco(oriented(width, height, 0.08, facing), center + along(facing, 0.04), "window")
	deco(oriented(0.1, height, 0.12, facing), center + along(facing, 0.07), "cream")
	deco(oriented(width, 0.1, 0.12, facing), center + along(facing, 0.07), "cream")
	deco(oriented(width + 0.4, 0.12, 0.3, facing), center + along(facing, 0.12) - Vector3(0, height * 0.5 + 0.1, 0), "cream")

func windows_row(from: Vector3, to: Vector3, facing: String, spacing: float = 6.0, width: float = 3.0, height: float = 2.2) -> void :
	var count: int = maxi(1, floori(from.distance_to(to) / spacing))
	for i in range(count):
		window(from.lerp(to, (i + 0.5) / count), facing, width, height)

func chalkboard(center: Vector3, facing: String, width: float, text_value: String = "", text_color: Color = Color("dcdccb")) -> void :
	deco(oriented(width + 0.24, 1.9, 0.08, facing), center + along(facing, 0.04), "wood")
	deco(oriented(width, 1.7, 0.1, facing), center + along(facing, 0.07), "board")
	deco(oriented(width, 0.07, 0.26, facing), center + along(facing, 0.16) - Vector3(0, 0.88, 0), "wood")
	for i in range(3):
		deco(oriented(0.22, 0.05, 0.05, facing), center + along(facing, 0.22, - width * 0.3 + i * 0.35) - Vector3(0, 0.82, 0), "chalk")
	if not text_value.is_empty():
		sign_text(text_value, center + along(facing, 0.14) + Vector3(0, 0.1, 0), facing, clampi(int(width * 6.0), 44, 76), text_color)

func poster(center: Vector3, facing: String, size: Vector2, key: String, stripes: int = 3) -> void :
	deco(oriented(size.x, size.y, 0.03, facing), center + along(facing, 0.02), key)
	for i in range(stripes):
		deco(oriented(size.x * 0.66, 0.05, 0.035, facing), center + along(facing, 0.035) + Vector3(0, size.y * 0.3 - i * size.y * 0.2, 0), "cream")


func grade(center: Vector3, facing: String, letter: String, red: bool) -> void :
	deco(oriented(1.3, 1.6, 0.03, facing), center + along(facing, 0.02), "chalk")
	sign_text(letter, center + along(facing, 0.05), facing, 150, Color("a8303f") if red else Color("2f6d52"))

func clock(center: Vector3, facing: String, radius: float = 0.45) -> void :
	var face: MeshInstance3D = cylinder(center + along(facing, 0.04), radius, 0.07, "trim")
	var dial: MeshInstance3D = cylinder(center + along(facing, 0.08), radius * 0.88, 0.04, "chalk")
	for piece in [face, dial]:
		if facing in ["n", "s"]:
			piece.rotation.x = PI * 0.5
		else:
			piece.rotation.z = PI * 0.5
	deco(oriented(0.05, radius * 0.6, 0.03, facing), center + along(facing, 0.11) + Vector3(0, radius * 0.25, 0), "trim")
	deco(oriented(radius * 0.45, 0.05, 0.03, facing), center + along(facing, 0.11, radius * 0.2), "red")

func notice_board(center: Vector3, facing: String, width: float = 2.6) -> void :
	deco(oriented(width + 0.16, 1.4, 0.06, facing), center + along(facing, 0.03), "wood")
	deco(oriented(width, 1.24, 0.07, facing), center + along(facing, 0.05), "orange")
	var keys: Array[String] = ["chalk", "yellow", "cream", "blue", "pink"]
	for i in range(5):
		var p: Vector3 = center + along(facing, 0.09, - width * 0.36 + i * width * 0.18) + Vector3(0, 0.22 if i % 2 == 0 else -0.2, 0)
		deco(oriented(0.4, 0.5, 0.02, facing), p, keys[i])


func lockers(from: Vector3, to: Vector3, facing: String, key: String = "blue", solid_depth: bool = true) -> void :
	var length: float = from.distance_to(to)
	var count: int = maxi(1, roundi(length / 0.9))
	var step: float = length / count
	var center: Vector3 = (from + to) * 0.5
	var body: Vector3 = oriented(length, 2.3, 0.6, facing)
	if solid_depth:
		solid(body, center + along(facing, 0.3) + Vector3(0, 1.15, 0), key)
	else:
		deco(body, center + along(facing, 0.3) + Vector3(0, 1.15, 0), key)
	for i in range(count):
		var p: Vector3 = from.lerp(to, (i + 0.5) / count) + along(facing, 0.61)
		deco(oriented(0.04, 2.2, 0.03, facing), p + along(facing, 0.0, step * 0.5) + Vector3(0, 1.15, 0), "trim")
		deco(oriented(0.1, 0.16, 0.04, facing), p + along(facing, 0.0, step * 0.3) + Vector3(0, 1.1, 0), "metal")
		for v in range(3):
			deco(oriented(step * 0.55, 0.035, 0.03, facing), p + Vector3(0, 1.9 - v * 0.09, 0), "trim")


func locker_island(center: Vector3, length: float, along_x: bool, key: String = "blue") -> void :
	var size: Vector3 = Vector3(length, 2.3, 1.2) if along_x else Vector3(1.2, 2.3, length)
	solid(size, center + Vector3(0, 1.15, 0), key)
	deco(Vector3(size.x + 0.08, 0.1, size.z + 0.08), center + Vector3(0, 2.35, 0), "trim")
	var count: int = maxi(1, roundi(length / 0.9))
	for i in range(count + 1):
		var t: float = - length * 0.5 + i * length / count
		var off: Vector3 = Vector3(t, 1.15, 0) if along_x else Vector3(0, 1.15, t)
		deco(Vector3(0.04, 2.2, 1.24) if along_x else Vector3(1.24, 2.2, 0.04), center + off, "trim")
	for side in [-1.0, 1.0]:
		var bench: Vector3 = center + (Vector3(0, 0.25, side * 1.5) if along_x else Vector3(side * 1.5, 0.25, 0))
		deco(Vector3(length * 0.7, 0.08, 0.4) if along_x else Vector3(0.4, 0.08, length * 0.7), bench + Vector3(0, 0.2, 0), "wood")

func bookshelf(center: Vector3, length: float, along_x: bool, height: float = 2.6, double: bool = true) -> void :
	var depth: float = 1.1 if double else 0.6
	var size: Vector3 = Vector3(length, height, depth) if along_x else Vector3(depth, height, length)
	solid(size, center + Vector3(0, height * 0.5, 0), "wood")
	var shelves: int = int(height / 0.62)
	var book_keys: Array[String] = ["red", "blue", "yellow", "green", "cream"]
	for s in range(shelves):
		var y: float = 0.25 + s * 0.62
		deco(Vector3(length + 0.04, 0.05, depth + 0.06) if along_x else Vector3(depth + 0.06, 0.05, length + 0.04), center + Vector3(0, y, 0), "trim")

		var pieces: int = maxi(2, int(length / 1.1))
		for b in range(pieces):
			var t: float = - length * 0.5 + (b + 0.5) * length / pieces
			var h: float = 0.36 + fposmod(float(b * 7 + s * 3), 4.0) * 0.04
			var key: String = book_keys[(b + s * 2) % book_keys.size()]
			var book_size: Vector3 = Vector3(length / pieces - 0.08, h, depth + 0.04) if along_x else Vector3(depth + 0.04, h, length / pieces - 0.08)
			deco(book_size, center + (Vector3(t, y + 0.03 + h * 0.5, 0) if along_x else Vector3(0, y + 0.03 + h * 0.5, t)), key)
	deco(Vector3(length + 0.1, 0.08, depth + 0.1) if along_x else Vector3(depth + 0.1, 0.08, length + 0.1), center + Vector3(0, height + 0.04, 0), "trim")


func desk(center: Vector3, facing: String = "n", with_chair: bool = true, key: String = "wood") -> void :
	var top: Vector3 = oriented(1.6, 0.08, 0.9, facing)
	blocker(oriented(1.6, 0.95, 0.9, facing), center + Vector3(0, 0.47, 0))
	deco(top, center + Vector3(0, 0.95, 0), key)
	deco(oriented(1.5, 0.5, 0.05, facing), center + Vector3(0, 0.62, 0) + along(facing, 0.4), "metal")
	for sx in [-0.7, 0.7]:
		for sz in [-0.35, 0.35]:
			deco(Vector3(0.06, 0.9, 0.06), center + along(facing, sz, sx) + Vector3(0, 0.45, 0), "metal")
	deco(oriented(0.4, 0.012, 0.55, facing), center + Vector3(0, 1.0, 0) + along(facing, 0.05, -0.3), "chalk")
	if with_chair:
		chair(center - along(facing, 0.95), facing)

func chair(center: Vector3, facing: String = "n") -> void :
	deco(oriented(0.62, 0.07, 0.6, facing), center + Vector3(0, 0.5, 0), "wood")
	deco(oriented(0.62, 0.55, 0.06, facing), center + Vector3(0, 0.82, 0) - along(facing, 0.28), "wood")
	for sx in [-0.26, 0.26]:
		for sz in [-0.25, 0.25]:
			deco(Vector3(0.04, 0.5, 0.04), center + along(facing, sz, sx) + Vector3(0, 0.25, 0), "metal")


func table(center: Vector3, size: Vector2, key: String = "wood", height: float = 0.95) -> void :
	blocker(Vector3(size.x, height, size.y), center + Vector3(0, height * 0.5, 0))
	deco(Vector3(size.x + 0.08, 0.1, size.y + 0.08), center + Vector3(0, height, 0), key)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			deco(Vector3(0.1, height, 0.1), center + Vector3(sx * (size.x * 0.5 - 0.2), height * 0.5, sz * (size.y * 0.5 - 0.2)), "metal")


func long_table(center: Vector3, length: float, along_x: bool = true) -> void :
	var footprint: Vector3 = Vector3(length, 0.95, 2.4) if along_x else Vector3(2.4, 0.95, length)
	blocker(footprint, center + Vector3(0, 0.47, 0))
	deco(Vector3(length, 0.1, 1.2) if along_x else Vector3(1.2, 0.1, length), center + Vector3(0, 0.9, 0), "cream")
	deco(Vector3(length - 0.3, 0.8, 0.5) if along_x else Vector3(0.5, 0.8, length - 0.3), center + Vector3(0, 0.45, 0), "metal")
	for side in [-1.0, 1.0]:
		var p: Vector3 = center + (Vector3(0, 0.45, side * 0.95) if along_x else Vector3(side * 0.95, 0.45, 0))
		deco(Vector3(length, 0.08, 0.4) if along_x else Vector3(0.4, 0.08, length), p, "blue")
		deco(Vector3(length * 0.9, 0.42, 0.12) if along_x else Vector3(0.12, 0.42, length * 0.9), p - Vector3(0, 0.23, 0), "metal")
	for i in range(int(length / 2.0)):
		var t: float = - length * 0.5 + 1.0 + i * 2.0
		var tray: Vector3 = center + (Vector3(t, 0.97, 0.3 * (1 if i % 2 == 0 else -1)) if along_x else Vector3(0.3 * (1 if i % 2 == 0 else -1), 0.97, t))
		deco(Vector3(0.5, 0.04, 0.36), tray, ["yellow", "chalk", "pink"][i % 3])

func vending_machine(center: Vector3, facing: String, glow_key: String) -> void :
	solid(oriented(1.3, 2.3, 0.9, facing), center + Vector3(0, 1.15, 0), "dark")
	deco(oriented(0.8, 1.5, 0.05, facing), center + along(facing, 0.46, -0.15) + Vector3(0, 1.35, 0), glow_key)
	deco(oriented(0.25, 0.9, 0.05, facing), center + along(facing, 0.46, 0.45) + Vector3(0, 1.4, 0), "metal")
	deco(oriented(0.8, 0.25, 0.06, facing), center + along(facing, 0.46, -0.15) + Vector3(0, 0.35, 0), "trim")

func trophy_case(center: Vector3, facing: String, width: float = 4.0) -> void :
	solid(oriented(width, 1.0, 0.8, facing), center + Vector3(0, 0.5, 0), "wood")
	deco(oriented(width, 1.3, 0.7, facing), center + Vector3(0, 1.65, 0), "glass")
	deco(oriented(width + 0.1, 0.1, 0.84, facing), center + Vector3(0, 2.35, 0), "wood")
	var count: int = maxi(2, int(width / 0.9))
	for i in range(count):
		var p: Vector3 = center + along(facing, 0.0, - width * 0.5 + (i + 0.5) * width / count) + Vector3(0, 1.1, 0)
		deco(Vector3(0.3, 0.12, 0.3), p, "trim")
		blob(p + Vector3(0, 0.32, 0), Vector3(0.14, 0.26, 0.14), "yellow" if i % 3 != 1 else "chalk")

func plant(center: Vector3, scale: float = 1.0, key: String = "leaf") -> void :
	cylinder(center + Vector3(0, 0.35 * scale, 0), 0.38 * scale, 0.7 * scale, "orange", 0.46 * scale)
	blob(center + Vector3(0, 1.1 * scale, 0), Vector3(0.55, 0.6, 0.55) * scale, key)
	blob(center + Vector3(0.25, 1.5, 0.1) * scale, Vector3(0.35, 0.4, 0.35) * scale, key)


func bench(center: Vector3, length: float, along_x: bool) -> void :
	deco(Vector3(length, 0.08, 0.45) if along_x else Vector3(0.45, 0.08, length), center + Vector3(0, 0.46, 0), "wood")
	for t in [-0.4, 0.4]:
		deco(Vector3(0.08, 0.44, 0.4) if along_x else Vector3(0.4, 0.44, 0.08), center + (Vector3(t * length, 0.22, 0) if along_x else Vector3(0, 0.22, t * length)), "metal")

func pillar(center: Vector3, height: float, width: float = 1.0, key: String = "wall") -> void :
	solid(Vector3(width, height, width), center + Vector3(0, height * 0.5, 0), key)
	deco(Vector3(width + 0.16, 0.2, width + 0.16), center + Vector3(0, 0.1, 0), "trim")
	deco(Vector3(width + 0.2, 0.25, width + 0.2), center + Vector3(0, height - 0.12, 0), "trim")


func wood_floor(rect: Rect2, height: float = 0.0) -> void :
	L._box(Vector3(rect.size.x, 0.02, rect.size.y), Vector3(rect.get_center().x, height + 0.014, rect.get_center().y), L._upper, false)

func rug(rect: Rect2, height: float, key: String) -> void :
	deco(Vector3(rect.size.x, 0.02, rect.size.y), Vector3(rect.get_center().x, height + 0.012, rect.get_center().y), key)

func crate_stack(center: Vector3, levels: int = 2) -> void :
	solid(Vector3(1.8, 0.9 * levels, 1.8), center + Vector3(0, 0.45 * levels, 0), "cream")
	for l in range(levels):
		deco(Vector3(1.86, 0.08, 1.86), center + Vector3(0, 0.9 * l + 0.86, 0), "trim")
		deco(Vector3(1.2, 0.5, 0.02), center + Vector3(0, 0.9 * l + 0.45, 0.92), "chalk")

func paper_litter(center: Vector3, count: int, spread: float, seed_value: int) -> void :
	for i in range(count):
		var angle: float = float(i * 2.4 + seed_value)
		var r: float = spread * fposmod(sin(float(i) * 12.9898 + seed_value) * 43758.5453, 1.0)
		var sheet: MeshInstance3D = deco(Vector3(0.42, 0.01, 0.58), center + Vector3(cos(angle) * r, 0.012, sin(angle) * r), "chalk")
		sheet.rotation.y = angle * 1.7




func tree(pos: Vector3, height: float, style: int = 0, collidable: bool = true) -> void :
	var start: int = S.collision_audit.size()
	S._forest_tree(pos, height, style, collidable)
	L._track_audit(start)

func rock(pos: Vector3, dimensions: Vector3, tint: Color = Color("57685c")) -> void :
	var start: int = S.collision_audit.size()
	S._rock(pos, dimensions, true, tint)
	L._track_audit(start)

func lantern(pos: Vector3, energy: float = 0.7, color: Color = Color("ffb36b")) -> void :
	var start: int = S.collision_audit.size()
	S._forest_lantern(pos, energy, color)
	L._track_audit(start)


func fence(from: Vector3, to: Vector3, key: String = "wood", height: float = 1.2) -> void :
	var along_x: bool = absf(to.x - from.x) > absf(to.z - from.z)
	var length: float = from.distance_to(to)
	var center: Vector3 = (from + to) * 0.5
	blocker(Vector3(length, height, 0.3) if along_x else Vector3(0.3, height, length), center + Vector3(0, height * 0.5, 0))
	for y in [height * 0.45, height * 0.9]:
		deco(Vector3(length, 0.12, 0.08) if along_x else Vector3(0.08, 0.12, length), center + Vector3(0, y, 0), key)
	var posts: int = maxi(1, ceili(length / 2.0))
	for i in range(posts + 1):
		deco(Vector3(0.16, height + 0.15, 0.16), from.lerp(to, float(i) / posts) + Vector3(0, (height + 0.15) * 0.5, 0), key)


func swings(center: Vector3, along_x: bool = true) -> void :
	for side in [-1.0, 1.0]:
		var foot: Vector3 = center + (Vector3(side * 2.4, 0, 0) if along_x else Vector3(0, 0, side * 2.4))
		blocker(Vector3(0.4, 2.8, 1.6) if along_x else Vector3(1.6, 2.8, 0.4), foot + Vector3(0, 1.4, 0))
		for lean in [-1.0, 1.0]:
			var leg: MeshInstance3D = deco(Vector3(0.14, 3.0, 0.14), foot + (Vector3(0, 1.45, lean * 0.45) if along_x else Vector3(lean * 0.45, 1.45, 0)), "red")
			if along_x:
				leg.rotation.x = lean * 0.3
			else:
				leg.rotation.z = - lean * 0.3
	deco(Vector3(5.0, 0.14, 0.14) if along_x else Vector3(0.14, 0.14, 5.0), center + Vector3(0, 2.9, 0), "red")
	for t in [-1.0, 1.0]:
		var seat: Vector3 = center + (Vector3(t, 0, 0) if along_x else Vector3(0, 0, t))
		deco(Vector3(0.03, 2.2, 0.03), seat + Vector3(0.25 if along_x else 0, 1.8, 0 if along_x else 0.25), "metal")
		deco(Vector3(0.03, 2.2, 0.03), seat + Vector3(-0.25 if along_x else 0, 1.8, 0 if along_x else -0.25), "metal")
		deco(Vector3(0.7, 0.06, 0.3) if along_x else Vector3(0.3, 0.06, 0.7), seat + Vector3(0, 0.7, 0), "yellow")


func slide(center: Vector3, facing: String) -> void :
	solid(Vector3(1.4, 2.4, 1.4), center + Vector3(0, 1.2, 0), "blue")
	deco(Vector3(1.6, 0.12, 1.6), center + Vector3(0, 2.46, 0), "yellow")
	var chute_center: Vector3 = center + along(facing, 2.3) + Vector3(0, 1.25, 0)
	var chute: MeshInstance3D = deco(oriented(0.9, 0.1, 3.6, facing), chute_center, "red")
	var tilt: float = atan2(2.3, 3.2)
	if facing == "s": chute.rotation.x = tilt
	elif facing == "n": chute.rotation.x = - tilt
	elif facing == "e": chute.rotation.z = - tilt
	else: chute.rotation.z = tilt
	blocker(oriented(1.0, 1.2, 2.6, facing), center + along(facing, 2.2) + Vector3(0, 0.6, 0))


func dome(center: Vector3, radius: float = 2.2) -> void :
	blocker(Vector3(radius * 1.5, radius * 0.9, radius * 1.5), center + Vector3(0, radius * 0.45, 0))
	for i in range(4):
		var arch: MeshInstance3D = deco(Vector3(radius * 2.0, 0.1, 0.1), center + Vector3(0, radius * 0.72, 0), "orange")
		arch.rotation.y = i * PI / 4
	for ring in range(2):
		var hoop: MeshInstance3D = cylinder(center + Vector3(0, 0.6 + ring * 0.8, 0), radius * (0.95 - ring * 0.25), 0.08, "orange")
		hoop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func picnic(center: Vector3, along_x: bool = true) -> void :
	blocker(Vector3(2.6, 0.9, 2.0) if along_x else Vector3(2.0, 0.9, 2.6), center + Vector3(0, 0.45, 0))
	deco(Vector3(2.6, 0.08, 0.9) if along_x else Vector3(0.9, 0.08, 2.6), center + Vector3(0, 0.8, 0), "wood")
	for side in [-1.0, 1.0]:
		deco(Vector3(2.6, 0.06, 0.32) if along_x else Vector3(0.32, 0.06, 2.6), center + (Vector3(0, 0.45, side * 0.8) if along_x else Vector3(side * 0.8, 0.45, 0)), "wood")
		deco(Vector3(0.1, 0.8, 1.9) if along_x else Vector3(1.9, 0.8, 0.1), center + (Vector3(side * 1.1, 0.4, 0) if along_x else Vector3(0, 0.4, side * 1.1)), "wood")


func school_bus(center: Vector3, along_x: bool = true) -> void :
	var size: Vector3 = Vector3(11, 3.0, 2.8) if along_x else Vector3(2.8, 3.0, 11)
	solid(size, center + Vector3(0, 1.8, 0), "yellow")
	deco(size * Vector3(1.01, 0.1, 1.01), center + Vector3(0, 1.4, 0), "trim")
	deco((Vector3(11.02, 0.9, 2.3) if along_x else Vector3(2.3, 0.9, 11.02)), center + Vector3(0, 2.55, 0), "window")
	deco((Vector3(10.4, 0.9, 2.84) if along_x else Vector3(2.84, 0.9, 10.4)), center + Vector3(0, 2.55, 0), "window")
	deco(size * Vector3(1.0, 0.08, 1.0) + Vector3(0.1, 0, 0.1), center + Vector3(0, 3.34, 0), "cream")
	for t in [-3.6, 3.6]:
		for side in [-1.0, 1.0]:
			var wheel: MeshInstance3D = cylinder(center + (Vector3(t, 0.5, side * 1.35) if along_x else Vector3(side * 1.35, 0.5, t)), 0.55, 0.4, "trim")
			if along_x:
				wheel.rotation.x = PI * 0.5
			else:
				wheel.rotation.z = PI * 0.5
	sign_text("ÉCOLE", center + (Vector3(0, 1.9, 1.43) if along_x else Vector3(1.43, 1.9, 0)), "s" if along_x else "e", 60, Color("2b2320"))


func stilt(base: Vector3, height: float, key: String = "wood") -> void :
	solid(Vector3(0.5, height, 0.5), base + Vector3(0, height * 0.5, 0), key)
	deco(Vector3(0.7, 0.2, 0.7), base + Vector3(0, 0.1, 0), "trim")


func planks(rect: Rect2, height: float, along_x: bool, key: String = "trim") -> void :
	var count: int = int((rect.size.y if along_x else rect.size.x) / 0.8)
	for i in range(1, count):
		var t: float = float(i) / count
		if along_x:
			deco(Vector3(rect.size.x - 0.1, 0.012, 0.04), Vector3(rect.get_center().x, height + 0.008, rect.position.y + rect.size.y * t), key)
		else:
			deco(Vector3(0.04, 0.012, rect.size.y - 0.1), Vector3(rect.position.x + rect.size.x * t, height + 0.008, rect.get_center().y), key)
