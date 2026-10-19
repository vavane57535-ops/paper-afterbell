extends RefCounted
















const Kit = preload("res://map_kit.gd")

const HIGH: float = 5.0
const SLAB: float = 4.6

var L: RefCounted
var S: Node3D
var K: RefCounted


var ridge: Rect2 = Rect2(-70, -68, 140, 30)
const LANTERNS: Array[Vector3] = [Vector3(-7.3, 0, 30), Vector3(8, 0, 30), Vector3(-24, 0, 0), Vector3(24, 0, -8), Vector3(-26, 0, 30), Vector3(28, 0, 32), Vector3(-58, 0, -12), Vector3(58, 0, -12), Vector3(-6, HIGH, -44), Vector3(28, HIGH, -52), Vector3(-44, 0, 26)]
var clear_rects: Array[Rect2] = []

func build(layout: RefCounted) -> void :
	L = layout
	S = layout.school
	K = Kit.new(layout)
	S.map_title = "Classe de neige · Le silence de l'hiver · OM"
	L.bounds = Rect2(-72, -70, 144, 132)
	_terrain()
	_chalet()
	_bridge()
	_cabins()
	_pond()
	_ski_shop()
	_arrival()
	_ridge_station()
	_gameplay_points()
	_paths()
	_population()
	_lights()
	_perimeter()
	_zones()
	L._moon()
	L._ambient_particles()

func _terrain() -> void :
	L._floor(Rect2(-70, -60, 140, 120), 0.0, L._ground_material, 0.7)
	L._floor(ridge, HIGH, L._stone, 0.5, true)
	L._box(Vector3(ridge.size.x, 0.012, ridge.size.y), Vector3(ridge.get_center().x, HIGH + 0.009, ridge.get_center().y), L._ground_material, false)
	L._ramp(Vector3(-56, 0, -18), Vector3(-56, HIGH, -38), 8, L._wood)
	L._ramp(Vector3(59, 0, -18), Vector3(59, HIGH, -38), 8, L._wood)
	for r in [Rect2(-62, -40, 12, 26), Rect2(53, -40, 12, 26)]:
		clear_rects.append(r)
	var tint: Color = Color("7f98a6")
	for p in [Vector3(-40, 0, -36.3), Vector3(-20, 0, -36.3), Vector3(22, 0, -36.3), Vector3(40, 0, -36.3), Vector3(-66, 0, -36.3), Vector3(66, 0, -36.3)]:
		K.rock(p, Vector3(3.4, 3.6, 3.2), tint)

func _chalet() -> void :

	L._partition(Vector3(-12, 0, -12), Vector3(12, 0, -12), [2.0], SLAB, 4.0, L._wood)
	L._partition(Vector3(-12, 0, 12), Vector3(12, 0, 12), [0.0], SLAB, 4.0, L._wood)
	L._partition(Vector3(-12, 0, -12), Vector3(-12, 0, 12), [2.0], SLAB, 4.0, L._wood)
	L._partition(Vector3(12, 0, -12), Vector3(12, 0, 12), [-9.0], SLAB, 4.0, L._wood)

	for rect in [Rect2(-12, -12, 18, 24), Rect2(6, -12, 6, 6)]:
		L._floor(rect, HIGH, L._upper, 0.4)
	for rect in [Rect2(-18, -16, 36, 4), Rect2(-18, 12, 36, 4), Rect2(-18, -12, 6, 24), Rect2(12, -12, 6, 24)]:
		L._floor(rect, HIGH, L._wood, 0.4)
		K.planks(rect, HIGH, rect.size.x > rect.size.y)
	L._ramp(Vector3(9, 0, 10), Vector3(9, HIGH, -6), 4, L._wood)
	L._rail(Vector3(6, HIGH, -6), Vector3(6, HIGH, 12))
	L._partition(Vector3(-12, SLAB, -12), Vector3(12, SLAB, -12), [0.0], 4.25, 4.0, L._wood, 3.0)
	# 0.17 : la porte du balcon donnait sur le pied d'un lit superposé ; elle ouvre sur l'allée entre les lits
	L._partition(Vector3(-12, SLAB, 12), Vector3(12, SLAB, 12), [-4.0], 4.25, 4.0, L._wood, 3.0)
	L._partition(Vector3(-12, SLAB, -12), Vector3(-12, SLAB, 12), [], 4.25, 4.0, L._wood)
	L._partition(Vector3(12, SLAB, -12), Vector3(12, SLAB, 12), [-9.0], 4.25, 4.0, L._wood, 3.0)

	L._rail(Vector3(-18, HIGH, -16), Vector3(-2, HIGH, -16))
	L._rail(Vector3(2, HIGH, -16), Vector3(18, HIGH, -16))
	L._rail(Vector3(-18, HIGH, 16), Vector3(-12, HIGH, 16))
	L._rail(Vector3(-8, HIGH, 16), Vector3(18, HIGH, 16))
	L._rail(Vector3(-18, HIGH, -16), Vector3(-18, HIGH, 16))
	L._rail(Vector3(18, HIGH, -16), Vector3(18, HIGH, 8))
	L._rail(Vector3(18, HIGH, 12), Vector3(18, HIGH, 16))

	L._ramp(Vector3(-10, 0, 34), Vector3(-10, HIGH, 16), 4, L._wood)
	L._ramp(Vector3(36, 0, 10), Vector3(18, HIGH, 10), 4, L._wood)

	for p in [Vector3(-18, 0, -16), Vector3(18, 0, -16), Vector3(-18, 0, 16), Vector3(18, 0, 16), Vector3(-18, 0, 0), Vector3(18, 0, 0), Vector3(0, 0, 16), Vector3(0, 0, -16)]:
		K.stilt(p, SLAB, "wood")
	L._box(Vector3(26, 0.3, 26), Vector3(0, 9.0, 0), L._trim, true, false)

	for side in [-1.0, 1.0]:
		var roof: MeshInstance3D = K.deco(Vector3(15.2, 0.4, 30), Vector3(side * 7, 11.5, 0), "red")
		roof.rotation.z = - side * 0.35
		var snow_cap: MeshInstance3D = K.deco(Vector3(15.2, 0.2, 30.2), Vector3(side * 7, 11.75, 0), "cream")
		snow_cap.rotation.z = - side * 0.35
	K.deco(Vector3(0.6, 0.6, 30.4), Vector3(0, 14.0, 0), "trim")

	for z in [-14.8, 14.8]:
		for i in range(4):
			K.deco(Vector3(26 - i * 6.5, 1.3, 0.3), Vector3(0, 9.6 + i * 1.2, z), "wood")
	K.sign_text("CHALET · CLASSE DE NEIGE", Vector3(0, 10.6, 15.0), "s", 60, Color("f2dfb8"))
	K.wood_floor(Rect2(-12, -12, 24, 24))

	K.solid(Vector3(4.0, 3.2, 1.2), Vector3(-6, 1.6, -11.2), "stone")
	K.deco(Vector3(2.0, 1.2, 0.2), Vector3(-6, 0.8, -10.55), "vend_red")
	K.accent_light(Vector3(-6, 1.2, -9.0), Color("ff9a52"), 1.1, 9.0)
	for z in [-2.0, 6.0]:
		K.long_table(Vector3(-4, 0, z), 8.0, true)
	K.solid(Vector3(3.0, 0.9, 1.2), Vector3(0, 0.45, -8), "red")
	K.chalkboard(Vector3(-11.75, 2.3, -6), "e", 5, "MENU · SOUPE\nCHOCOLAT CHAUD")
	K.ceiling_lamp(Vector3(-4, 4.3, 2), 0.7, 14)

	for p in [Vector3(-8, HIGH, -6), Vector3(-8, HIGH, 2), Vector3(0, HIGH, -6), Vector3(0, HIGH, 2), Vector3(-8, HIGH, 9)]:
		K.solid(Vector3(2.0, 1.9, 3.0), p + Vector3(0, 0.95, 0), "wood")
		K.deco(Vector3(1.8, 0.2, 2.8), p + Vector3(0, 0.6, 0), "blue")
		K.deco(Vector3(1.8, 0.2, 2.8), p + Vector3(0, 1.8, 0), "pink")
	for i in range(5):
		var ski: MeshInstance3D = K.deco(Vector3(0.12, 2.2, 0.04), Vector3(-10 + i * 0.5, HIGH + 1.1, -11.7), ["red", "blue", "yellow", "red", "blue"][i])
		ski.rotation.z = 0.08
	K.sign_text("DORTOIR · SILENCE", Vector3(-4, HIGH + 3.4, 11.7), "n", 30, Color("e8d9c0"))
	K.ceiling_lamp(Vector3(-4, HIGH + 3.8, 0), 0.6, 13)
	for x in [-6.0, 6.0]:
		K.window(Vector3(-10.0 if x < 0.0 else x, HIGH + 2.0, 12.25), "s", 2.4, 1.6)
		K.window(Vector3(x, 2.4, 12.25), "s", 2.4, 1.6)
	clear_rects.append(Rect2(-20, -18, 40, 54))
	clear_rects.append(Rect2(16, 6, 22, 8))

func _bridge() -> void :

	var rect: Rect2 = Rect2(-2, -38, 4, 22)
	L._floor(rect, HIGH, L._wood, 0.4)
	K.planks(rect, HIGH, false)
	L._rail(Vector3(-2, HIGH, -38), Vector3(-2, HIGH, -16))
	L._rail(Vector3(2, HIGH, -38), Vector3(2, HIGH, -16))
	for z in [-34.0, -26.0, -20.0]:
		for x in [-2.2, 2.2]:
			K.stilt(Vector3(x, 0, z), SLAB, "wood")
		K.deco(Vector3(0.25, 3.2, 0.25), Vector3(-2.2, HIGH + 1.6, z), "wood")
		K.deco(Vector3(0.25, 3.2, 0.25), Vector3(2.2, HIGH + 1.6, z), "wood")
	for side in [-1.0, 1.0]:
		var roof: MeshInstance3D = K.deco(Vector3(3.2, 0.2, 22), Vector3(side * 1.3, HIGH + 3.5, -27), "red")
		roof.rotation.z = - side * 0.45
	clear_rects.append(Rect2(-5, -40, 10, 26))

func _cabins() -> void :

	for z in [-24.0, 0.0, 24.0]:
		L._partition(Vector3(36, 0, z - 5), Vector3(52, 0, z - 5), [], 3.4, 4.0, L._wood)
		L._partition(Vector3(36, 0, z + 5), Vector3(52, 0, z + 5), [], 3.4, 4.0, L._wood)
		L._partition(Vector3(36, 0, z - 5), Vector3(36, 0, z + 5), [z], 3.4, 4.0, L._wood, 2.8)
		L._partition(Vector3(52, 0, z - 5), Vector3(52, 0, z + 5), [z], 3.4, 4.0, L._wood, 2.8)
		L._box(Vector3(17, 0.3, 11), Vector3(44, 3.55, z), L._trim, true, false)
		K.wood_floor(Rect2(36, z - 5, 16, 10))
		for side in [-1.0, 1.0]:
			var roof: MeshInstance3D = K.deco(Vector3(18, 0.3, 6.4), Vector3(44, 4.6, z + side * 2.8), "red")
			roof.rotation.x = side * 0.45
			var cap: MeshInstance3D = K.deco(Vector3(18.2, 0.12, 6.4), Vector3(44, 4.8, z + side * 2.8), "cream")
			cap.rotation.x = side * 0.45
		K.solid(Vector3(2.0, 1.6, 3.0), Vector3(40, 0.8, z - 2.6), "wood")
		K.solid(Vector3(2.0, 1.6, 3.0), Vector3(48, 0.8, z + 2.6), "wood")
		K.window(Vector3(44, 1.9, z + 5.25), "s", 2.0, 1.2)
		K.lantern(Vector3(34.6, 0, z + 3.6), 0.55, Color("ffc27a"))
		clear_rects.append(Rect2(32, z - 8, 24, 16))
	K.sign_text("CHALET DES FILLES", Vector3(35.7, 3.0, -24), "w", 26, Color("f1dcbf"))
	K.sign_text("CHALET DES GARÇONS", Vector3(35.7, 3.0, 0), "w", 26, Color("f1dcbf"))
	K.sign_text("CHALET DES PROFS", Vector3(35.7, 3.0, 24), "w", 26, Color("f1dcbf"))

func _pond() -> void :

	var ice: StandardMaterial3D = S._mat(Color("a9c8dc"))
	ice.roughness = 0.2
	L._box(Vector3(28, 0.02, 26), Vector3(-44, 0.02, 0), ice, false)
	for i in range(5):
		var crack: MeshInstance3D = K.deco(Vector3(6.0, 0.012, 0.06), Vector3(-50 + i * 3.5, 0.035, -6 + i * 3), "blue")
		crack.rotation.y = 0.5 + i * 0.7
	for fort in [[Vector3(-28, 0, -8), Vector3(1.2, 1.4, 6)], [Vector3(-28, 0, 8), Vector3(1.2, 1.4, 6)], [Vector3(-60, 0, 0), Vector3(1.2, 1.4, 8)], [Vector3(-44, 0, 16), Vector3(8, 1.4, 1.2)], [Vector3(-36, 0, -16), Vector3(6, 1.4, 1.2)]]:
		K.solid(fort[1], fort[0] + Vector3(0, fort[1].y * 0.5, 0), "cream")
		K.deco(fort[1] * Vector3(1.05, 0.15, 1.05), fort[0] + Vector3(0, fort[1].y, 0), "chalk")

	for p in [Vector3(-50, 0, 20), Vector3(-24, 0, 22), Vector3(-24, 0, -24)]:
		K.blocker(Vector3(1.6, 2.6, 1.6), p + Vector3(0, 1.3, 0))
		K.blob(p + Vector3(0, 0.75, 0), Vector3(0.9, 0.8, 0.9), "chalk")
		K.blob(p + Vector3(0, 1.85, 0), Vector3(0.6, 0.55, 0.6), "chalk" if p.x != -50 else "red")
		K.deco(Vector3(0.1, 0.1, 0.4), p + Vector3(0, 1.9, 0.6), "orange")

	L._partition(Vector3(-50, 0, -30), Vector3(-38, 0, -30), [], 3.2, 4.0, L._wood)
	L._partition(Vector3(-50, 0, -20), Vector3(-38, 0, -20), [-44.0], 3.2, 4.0, L._wood, 2.8)

	L._partition(Vector3(-50, 0, -30), Vector3(-50, 0, -20), [-25.0], 3.2, 4.0, L._wood, 2.8)
	L._partition(Vector3(-38, 0, -30), Vector3(-38, 0, -20), [], 3.2, 4.0, L._wood)
	L._box(Vector3(13, 0.3, 11), Vector3(-44, 3.35, -25), L._trim, true, false)
	K.wood_floor(Rect2(-50, -30, 12, 10))
	K.cylinder(Vector3(-41, 0.03, -27), 0.7, 0.03, "dark")
	K.crate_stack(Vector3(-40, 0, -28), 1)
	K.sign_text("CABANE DE PÊCHE", Vector3(-44, 2.9, -19.7), "s", 28, Color("e8dcc2"))
	K.stake_sign(Vector3(-29.2, 0, 0), "e", "GLACE FRAGILE", 34, Color("d1e6f5"), 2.3)
	clear_rects.append(Rect2(-62, -32, 36, 52))

func _ski_shop() -> void :

	L._partition(Vector3(34, 0, 36), Vector3(52, 0, 36), [40.0, 46.0], 3.4, 4.0, L._wood, 2.8)
	L._partition(Vector3(34, 0, 50), Vector3(52, 0, 50), [], 3.4, 4.0, L._wood)
	L._partition(Vector3(34, 0, 36), Vector3(34, 0, 50), [], 3.4, 4.0, L._wood)
	L._partition(Vector3(52, 0, 36), Vector3(52, 0, 50), [43.0], 3.4, 4.0, L._wood, 2.8)
	L._box(Vector3(19, 0.3, 15), Vector3(43, 3.55, 43), L._trim, true, false)
	K.wood_floor(Rect2(34, 36, 18, 14))
	K.solid(Vector3(8, 1.8, 1.0), Vector3(40, 0.9, 44), "wood")
	for i in range(8):
		var ski: MeshInstance3D = K.deco(Vector3(0.12, 1.9, 0.05), Vector3(36.6 + i * 0.9, 0.95, 44.55), ["red", "blue", "yellow", "chalk"][i % 4])
		ski.rotation.z = 0.1
	K.sign_text("LOCATION DE SKIS", Vector3(43, 3.0, 35.7), "n", 34, Color("f4dcb0"))
	clear_rects.append(Rect2(31, 33, 24, 20))

func _arrival() -> void :

	K.school_bus(Vector3(-24, 0, 52), true)
	K.solid(Vector3(3.0, 2.6, 2.0), Vector3(20, 1.3, 52), "red")
	K.deco(Vector3(3.2, 0.2, 2.2), Vector3(20, 2.7, 52), "cream")
	K.sign_text("POINT DE RENDEZ-VOUS", Vector3(0, 3.2, 36.2), "s", 44, Color("f5e3be"))
	for x in [-4.0, 4.0]:
		K.stilt(Vector3(x, 0, 36), 3.6, "metal")
	K.deco(Vector3(8.6, 0.8, 0.12), Vector3(0, 3.2, 36.0), "blue")
	for p in [Vector3(-12, 0, 46), Vector3(12, 0, 46)]:
		K.bench(p, 4.0, false)
	clear_rects.append(Rect2(-32, 34, 60, 26))

func _ridge_station() -> void :
	var y: float = HIGH

	var center: Vector3 = Vector3(-30, y, -54)
	for side in [-1.0, 1.0]:
		L._box(Vector3(0.5, 4.4, 3), center + Vector3(side * 8, 2.2, -1.5), L._wood)
		L._box(Vector3(5, 4.4, 0.4), center + Vector3(side * 5.5, 2.2, 0), L._wood)

	L._box(Vector3(16.5, 0.4, 2.0), center + Vector3(0, 4.6, -0.75), L._trim, true, false)
	K.fence(Vector3(-70, y, -57), Vector3(-38.3, y, -57), "wood", 1.4)
	K.fence(Vector3(-21.7, y, -57), Vector3(70, y, -57), "wood", 1.4)
	S._hinged_exit(center, 6.0, 3.9, S._exit_glass())
	L.solids.append(AABB(center + Vector3(-3.2, 0, -0.3), Vector3(6.4, 3.9, 0.6)))
	L._lamp(center + Vector3(0, 4.31, -0.1), 1.1, 13)
	S._label("SORTIE · TÉLÉPHÉRIQUE", K.board(center + Vector3(0, 5.15, 0.15), "s", Vector2(5.4, 0.7)), 46, Color("d7e5cb"))

	var terminal: Vector3 = Vector3(-44, y, -62)
	# 0.17 : la cabine flottait à 40 cm du sol, la roue au-dessus de sa traverse et le câble 2 m au-dessus de la roue
	K.deco(Vector3(3, 2.4, 3), terminal + Vector3(0, 1.2, 0), "red")
	K.deco(Vector3(3.05, 0.9, 2.4), terminal + Vector3(0, 1.7, 0), "window")
	K.deco(Vector3(0.12, 1.3, 0.12), terminal + Vector3(0, 3.05, 0), "metal")
	K.deco(Vector3(0.25, 0.25, 5.6), terminal + Vector3(0, 3.825, -1.95), "metal")
	K.stilt(terminal + Vector3(0, 0, -4), 8.0, "metal")
	K.deco(Vector3(3.0, 0.25, 0.25), terminal + Vector3(0, 8.0, -4), "metal")
	var wheel: MeshInstance3D = K.cylinder(terminal + Vector3(0, 8.225, -4), 1.2, 0.2, "trim")
	wheel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for side in [-1.0, 1.0]:
		var cable: MeshInstance3D = K.deco(Vector3(0.06, 0.06, 40), terminal + Vector3(side * 1.17, 8.225 - 20.0 * sin(0.1), -4 - 20.0 * cos(0.1)), "trim")
		cable.rotation.x = -0.1
	K.lantern(Vector3(-38, y, -61), 0.7, Color("ffc27a"))
	K.sign_text("TÉLÉPHÉRIQUE · DESCENTE", terminal + Vector3(0, 0.75, 1.53), "s", 26, Color("f3e1c0"))

	for wall in [[Vector3(-8, y, -48), Vector3(8, 1.4, 1.2)], [Vector3(14, y, -52), Vector3(1.2, 1.4, 8)], [Vector3(-50, y, -46), Vector3(1.2, 1.4, 6)], [Vector3(30, y, -46), Vector3(8, 1.4, 1.2)]]:
		K.solid(wall[1], wall[0] + Vector3(0, wall[1].y * 0.5, 0), "cream")
	L._partition(Vector3(44, y, -58), Vector3(56, y, -58), [], 3.4, 4.0, L._wood)
	L._partition(Vector3(44, y, -58), Vector3(44, y, -48), [-53.0], 3.4, 4.0, L._wood, 2.8)
	L._partition(Vector3(56, y, -58), Vector3(56, y, -48), [-53.0], 3.4, 4.0, L._wood, 2.8)
	L._box(Vector3(13, 0.3, 11), Vector3(50, y + 3.55, -53), L._trim, true, false)
	K.sign_text("REMONTE-PENTE", K.board(Vector3(50, y + 3.1, -47.56), "s", Vector2(4.4, 0.6)), "s", 30, Color("e6dac3"))
	clear_rects.append(Rect2(-48, -68, 36, 16))

	clear_rects.append(Rect2(-40, -54, 20, 14))
	clear_rects.append(Rect2(42, -60, 16, 14))

func _population() -> void :
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 21213
	var accepted: Array[Vector2] = []
	for attempt in range(1400):
		if accepted.size() >= 95:
			break
		var p2: Vector2 = Vector2(rng.randf_range(-68, 68), rng.randf_range(-66, 58))
		var height: float = 0.0
		if ridge.grow(2.5).has_point(p2) and not ridge.grow(-2.5).has_point(p2):
			continue
		if ridge.has_point(p2):
			height = HIGH
		var blocked: bool = false
		for rect in clear_rects:
			if rect.grow(3.0).has_point(p2):
				blocked = true
				break
		if blocked:
			continue
		for route_point in S._forest_paths:
			if route_point.distance_to(p2) < 5.0:
				blocked = true
				break
		for objective in S.objectives:
			if Vector2(objective.x, objective.z).distance_to(p2) < 7.0:
				blocked = true
		for other in accepted:
			if other.distance_to(p2) < 5.5:
				blocked = true
				break
		if blocked:
			continue
		accepted.append(p2)
		# 0.17 : la place reste dans le tirage, mais pas d'arbre dans un fort de neige, un rocher ou un mur
		var tree_height: float = rng.randf_range(10, 15)
		if _crowded_by_solid(Vector3(p2.x, height, p2.y), tree_height) or _over_lantern(Vector3(p2.x, height, p2.y), tree_height):
			continue
		K.tree(Vector3(p2.x, height, p2.y), tree_height, accepted.size() % 3)
	for i in range(60):
		var angle: float = i * TAU / 60.0
		var radius: float = 84.0 + fposmod(float(i) * 7.3, 12.0)
		# 0.17 : la couronne reste hors de la carte (des arbres sans collision traversaient la gare du
		# téléphérique, le remonte-pente et la crête) et pousse sur le sol de décor, haut au nord
		var p: Vector3 = Vector3(cos(angle) * radius, 0, sin(angle) * radius * 0.85)
		if L.bounds.grow(3.0).has_point(Vector2(p.x, p.z)):
			continue
		# ni dans un rocher du pourtour, ni collé au pied de la crête (le feuillage entrait dans la roche)
		var ring_height: float = 13 + fposmod(float(i) * 3.1, 6.0)
		if _in_perimeter_rock(p, ring_height) or absf(p.z + 38.0) < 3.0:
			continue
		p.y = HIGH if p.z < -38.0 else 0.0
		K.tree(p, ring_height, i % 3, false)

# 0.17 : pas de lanterne dans les branches basses d'un sapin (la lampe était cachée dans le feuillage)
func _over_lantern(base: Vector3, height: float) -> bool:
	for lantern: Vector3 in LANTERNS:
		if absf(lantern.y - base.y) < 1.0 and Vector2(lantern.x - base.x, lantern.z - base.z).length() < height * 0.24 + 0.5:
			return true
	return false

func _in_perimeter_rock(p: Vector3, height: float) -> bool:
	for rock: Array in _perimeter_rocks():
		var reach: float = maxf(rock[1].x, rock[1].z) * 0.58 + height * 0.04 + 0.3
		if Vector2(p.x - rock[0].x, p.z - rock[0].z).length() < reach:
			return true
	return false

func _crowded_by_solid(base: Vector3, height: float) -> bool:
	var reach: float = height * 0.046 + 0.35
	for obstacle: AABB in L.solids:
		if obstacle.end.y <= base.y + 0.1 or obstacle.position.y > base.y + height * 0.68:
			continue
		if Rect2(obstacle.position.x, obstacle.position.z, obstacle.size.x, obstacle.size.z).grow(reach).has_point(Vector2(base.x, base.z)):
			return true
	return false

func _paths() -> void :
	for route in [[Vector2(0, 38), Vector2(0, 18)], [Vector2(8, 40), Vector2(34, 26)], [Vector2(-8, 40), Vector2(-30, 20)], [Vector2(-22, -18), Vector2(-54, -16)], [Vector2(22, -18), Vector2(54, -16)], [Vector2(20, 30), Vector2(34, 40)]]:
		S._forest_route(route[0], route[1], 4)

func _lights() -> void :
	var warm: Color = Color("ffc27a")
	for p: Vector3 in LANTERNS:
		K.lantern(p, 0.75, warm)
	K.accent_light(Vector3(-4, HIGH + 2.5, 0), Color("ffcf94"), 0.5, 11)
	K.accent_light(Vector3(44, 2.4, 0), Color("ffcf94"), 0.45, 8)
	K.accent_light(Vector3(-44, 2.2, -25), Color("ffcf94"), 0.45, 8)

func _perimeter() -> void :
	for wall in [[Vector3(0, 6, -68.5), Vector3(144, 12, 1)], [Vector3(0, 6, 61.5), Vector3(144, 12, 1)], [Vector3(-71.5, 6, -4), Vector3(1, 12, 130)], [Vector3(71.5, 6, -4), Vector3(1, 12, 130)]]:
		K.blocker(wall[1], wall[0])
	var tint: Color = Color("758b99")
	for rock: Array in _perimeter_rocks():
		S._rock(rock[0], rock[1], false, tint)

# [position, dimensions] des gros rochers hors de la carte (même ordre qu'avant : mêmes tirages aléatoires)
func _perimeter_rocks() -> Array:
	var rocks: Array = []
	for x in range(-66, 67, 12):
		rocks.append([Vector3(x, HIGH, -72), Vector3(10, 10, 6)])
		rocks.append([Vector3(x, 0, 64), Vector3(10, 6, 5)])
	for z in range(-54, 55, 12):
		for x in [-74.0, 74.0]:
			rocks.append([Vector3(x, HIGH if z < -38 else 0.0, z), Vector3(6, 9, 10)])
	return rocks

func _zones() -> void :
	L._zone("Dortoir du chalet", Rect2(-12, -12, 24, 24), HIGH)
	L._zone("Balcon du chalet", Rect2(-18, -16, 36, 32), HIGH)
	L._zone("Passerelle couverte", Rect2(-2, -38, 4, 22), HIGH)
	L._zone("Gare du téléphérique", Rect2(-40, -68, 20, 16), HIGH)
	L._zone("Remonte-pente", Rect2(42, -60, 16, 14), HIGH)
	L._zone("Crête enneigée", ridge, HIGH)
	L._zone("Grande salle du chalet", Rect2(-12, -12, 24, 24), 0)
	L._zone("Sous le balcon", Rect2(-18, -16, 36, 32), 0)
	L._zone("Cabane de pêche", Rect2(-50, -30, 12, 10), 0)
	L._zone("Étang gelé", Rect2(-62, -18, 36, 40), 0)
	L._zone("Chalets des élèves", Rect2(32, -32, 24, 64), 0)
	L._zone("Location de skis", Rect2(34, 36, 18, 14), 0)
	L._zone("Point de rendez-vous", Rect2(-32, 34, 64, 26), 0)
	L._zone("Sentier sous la passerelle", Rect2(-8, -38, 16, 22), 0)

func _gameplay_points() -> void :
	S.spawn_points.clear()
	for i in range(6):
		S.spawn_points.append(Vector3(-6 + (i % 3) * 6, 0.1, 46 + (i / 3) * 4))
	S.killer_spawn = Vector3(50, HIGH + 0.1, -44)
	# 0.17 : les meubles d'archive reposent sur le plancher (ils flottaient de 3 à 5 cm)
	S.objectives.assign([Vector3(-4, 0.024, -8), Vector3(-4, HIGH, 6), Vector3(44, 0.024, 0), Vector3(-44, 0.024, -25), Vector3(46, 0.024, 40)])
	S.patrol_points.assign([Vector3(0, 0, 26), Vector3(-22, 0, 4), Vector3(24, 0, -4), Vector3(-44, 0, 0), Vector3(44, 0, -24), Vector3(44, 0, 24), Vector3(0, 0, -28), Vector3(-56, 0, -10), Vector3(56, 0, -10), Vector3(0, HIGH, -44), Vector3(-30, HIGH, -46), Vector3(30, HIGH, -50), Vector3(-15, HIGH, 0), Vector3(0, HIGH, 14), Vector3(-4, HIGH, -2), Vector3(40, 0, 30)])
	L.upper_targets.assign([Vector3(-15, HIGH, 0), Vector3(0, HIGH, -44), Vector3(-4, HIGH, -2), Vector3(30, HIGH, -50)])
	S.menu_spawn = Vector3(0, 0.05, 41)
	S.cinematic_anchor = Vector3(-30, HIGH + 0.05, -46)
	S.cinematic_exit = Vector3(-30, HIGH + 0.05, -57)
	S.cinematic_path.assign([Vector3(-30, HIGH + 0.05, -56), Vector3(-30, HIGH + 0.05, -51), Vector3(-30, HIGH + 0.05, -46)])
	L.exit_point = Vector3(-30, HIGH + 0.05, -52.9)
	L.outlets.assign([Vector3(-10, 0, 44), Vector3(-26, 0, -4), Vector3(28, 0, 16), Vector3(-6, HIGH, -40), Vector3(26, 0, 44)])
	L.portable_outlets = true
