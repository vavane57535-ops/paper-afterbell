extends RefCounted


















const Kit = preload("res://map_kit.gd")

const HIGH: float = 4.0
const TREEHOUSE: float = 8.0

var L: RefCounted
var S: Node3D
var K: RefCounted
var snow: bool = false


var plateaus: Array[Rect2] = [Rect2(-74, -70, 148, 26), Rect2(-50, -44, 28, 44), Rect2(22, -44, 28, 44)]
var clear_rects: Array[Rect2] = []

func build(layout: RefCounted) -> void :
	L = layout
	S = layout.school
	K = Kit.new(layout)
	snow = S._snow
	S.map_title = "Forêt des murmures · Derrière l'école · OM"
	L.bounds = Rect2(-76, -72, 152, 138)
	_terrain()
	_pit_and_bridge()
	_greenhouse()
	_treehouse()
	_north_plateau()
	_janitor_shed()
	_picnic_garden()
	_playground()
	_school_facade()
	_hedges()
	_paths()
	_gameplay_points()
	_population()
	_lights()
	_perimeter()
	_zones()
	L._moon()
	L._ambient_particles()



func _terrain() -> void :
	L._floor(Rect2(-74, -64, 148, 128), 0.0, L._ground_material, 0.7)
	for rect in plateaus:
		L._floor(rect, HIGH, L._stone, 0.5, true)

		L._box(Vector3(rect.size.x, 0.012, rect.size.y), Vector3(rect.get_center().x, HIGH + 0.009, rect.get_center().y), L._ground_material, false)
	var ramp_material: Material = L._wood

	L._ramp(Vector3(-36, 0, 14), Vector3(-36, HIGH, 0), 8, ramp_material)
	L._ramp(Vector3(44, 0, 14), Vector3(44, HIGH, 0), 8, ramp_material)
	L._ramp(Vector3(-66, 0, -20), Vector3(-50, HIGH, -20), 8, ramp_material)
	L._ramp(Vector3(66, 0, -20), Vector3(50, HIGH, -20), 8, ramp_material)
	for r in [Rect2(-42, -2, 12, 20), Rect2(38, -2, 12, 20), Rect2(-68, -26, 20, 12), Rect2(48, -26, 20, 12)]:
		clear_rects.append(r)

	var tint: Color = Color("7f98a6") if snow else Color("56665b")
	for p in [Vector3(-52, 0, -36), Vector3(-53, 0, -4), Vector3(-20, 0, -40), Vector3(20, 0, -40), Vector3(-19, 0, -3), Vector3(19, 0, -4), Vector3(53, 0, -34), Vector3(52, 0, -6), Vector3(-60, 0, -41.8), Vector3(62, 0, -41.8), Vector3(-28, HIGH, -48)]:
		K.rock(p, Vector3(3.2, 3.4, 3.6), tint)

func _pit_and_bridge() -> void :

	for span in [Vector2(-22, -1), Vector2(1, 22)]:
		var rect: Rect2 = Rect2(span.x, -14, span.y - span.x, 4)
		L._floor(rect, HIGH, L._wood, 0.4)
		K.planks(rect, HIGH, false)

	for span in [Vector2(-22, -10), Vector2(-6, -1), Vector2(1, 22)]:
		L._rail(Vector3(span.x, HIGH, -14), Vector3(span.y, HIGH, -14))
	for span in [Vector2(-22, -1), Vector2(1, 6), Vector2(10, 22)]:
		L._rail(Vector3(span.x, HIGH, -10), Vector3(span.y, HIGH, -10))
	for x in [-16.0, -8.0, 8.0, 16.0]:
		K.stilt(Vector3(x, 0, -12), HIGH - 0.4)

	for side in [-1.0, 1.0]:
		var splinter: MeshInstance3D = K.deco(Vector3(0.9, 0.12, 3.6), Vector3(side * 1.3, HIGH - 0.1, -12), "wood")
		splinter.rotation.z = - side * 0.35
	L._jump_link(Vector3(-2, HIGH, -12), Vector3(2, HIGH, -12))

	L._ramp(Vector3(0, 0, -26), Vector3(0, HIGH, -44), 6, L._wood)
	clear_rects.append(Rect2(-5, -46, 10, 22))

	L._drop_link(Vector3(-24, HIGH, -26), Vector3(-19, 0, -26))
	L._drop_link(Vector3(24, HIGH, -26), Vector3(19, 0, -26))
	L._drop_link(Vector3(-8, HIGH, -12), Vector3(-8, 0, -17))
	L._drop_link(Vector3(8, HIGH, -12), Vector3(8, 0, -7))

	K.rug(Rect2(-14, -32, 10, 8), 0.0, "yellow")
	for side in [-1.0, 1.0]:
		K.deco(Vector3(10.4, 0.35, 0.3), Vector3(-9, 0.17, -28 + side * 4), "wood")
		K.deco(Vector3(0.3, 0.35, 8.4), Vector3(-9 + side * 5, 0.17, -28), "wood")
	K.solid(Vector3(3.6, 0.8, 3.6), Vector3(10, 0.4, -30), "red")
	K.cylinder(Vector3(10, 0.85, -30), 2.0, 0.1, "yellow")
	for i in range(4):
		var bar: MeshInstance3D = K.deco(Vector3(0.08, 1.2, 0.08), Vector3(10 + cos(i * PI * 0.5) * 1.4, 1.45, -30 + sin(i * PI * 0.5) * 1.4), "metal")
		bar.rotation.y = i
	K.deco(Vector3(3.0, 0.08, 0.08), Vector3(10, 2.05, -30), "metal")
	K.deco(Vector3(0.08, 0.08, 3.0), Vector3(10, 2.05, -30), "metal")
	for p in [Vector3(-12, 0, -4), Vector3(12, 0, -20), Vector3(-14, 0, -38)]:
		K.solid(Vector3(1.6, 0.9, 1.6), p + Vector3(0, 0.45, 0), "dark")
		K.cylinder(p + Vector3(0, 0.95, 0), 0.5, 0.12, "trim")
	K.tree(Vector3(14, 0, -40), 9.0, 1)

	for p in [Vector3(-16, 0, -20), Vector3(-6.5, 0, -37.0), Vector3(4, 0, -20)]:
		K.rock(p, Vector3(2.8, 2.6, 3.2), Color("7f98a6") if snow else Color("56665b"))
	for x in [-18.0, -12.0]:
		K.stilt(Vector3(x, 0, -34), 2.6, "metal")
	K.deco(Vector3(6.6, 0.12, 0.12), Vector3(-15, 2.6, -34), "orange")
	K.deco(Vector3(6.6, 0.12, 0.12), Vector3(-15, 1.6, -34), "orange")
	K.sign_text("LA FOSSE\nNE PAS JOUER ICI", Vector3(-21.7, 2.2, -20), "e", 36, Color("e9d7b0"))

func _greenhouse() -> void :


	var glass: StandardMaterial3D = S._mat(Color("27393f"), true)
	glass.emission = Color("3d6e5a")
	glass.emission_energy_multiplier = 0.55
	var y: float = HIGH
	L._partition(Vector3(-46, y, -36), Vector3(-30, y, -36), [], 3.6, 4.0, glass)
	L._partition(Vector3(-46, y, -36), Vector3(-46, y, -12), [], 3.6, 4.0, glass)
	L._partition(Vector3(-30, y, -36), Vector3(-30, y, -12), [], 3.6, 4.0, glass)
	L._partition(Vector3(-46, y, -12), Vector3(-30, y, -12), [-42.0, -34.0], 3.6, 4.0, glass, 3.0)
	L._partition(Vector3(-38, y, -28), Vector3(-38, y, -12), [], 3.6, 4.0, glass)

	for z in range(-36, -11, 4):
		for x in [-46.0, -30.0]:
			K.deco(Vector3(0.62, 3.7, 0.14), Vector3(x, y + 1.85, z), "trim")
	for x in range(-46, -29, 4):
		for z in [-36.0, -12.0]:
			if absf(x + 42) > 2.1 and absf(x + 34) > 2.1:
				K.deco(Vector3(0.14, 3.7, 0.62), Vector3(x, y + 1.85, z), "trim")

	for h in [1.2, 2.5]:
		for wall in [[Vector3(-38, y + h, -36), Vector3(16.1, 0.1, 0.62)], [Vector3(-46, y + h, -24), Vector3(0.62, 0.1, 24.1)], [Vector3(-30, y + h, -24), Vector3(0.62, 0.1, 24.1)], [Vector3(-38, y + h, -20), Vector3(0.62, 0.1, 16.1)]]:
			K.deco(wall[1], wall[0], "trim")
	var pitch: float = atan2(6.25 - 3.64, 8.25)
	for side in [-1.0, 1.0]:
		var pane: MeshInstance3D = K.deco(Vector3(9.0, 0.08, 24.4), Vector3(-38 + side * 4.5 * cos(pitch), y + 6.25 - 4.5 * sin(pitch), -24), "glass")
		pane.rotation.z = - side * pitch
	K.deco(Vector3(0.3, 0.3, 24.6), Vector3(-38, y + 6.35, -24), "trim")

	for z in [-32.0, -24.0, -16.0]:
		for x in [-44.8, -31.2]:
			K.solid(Vector3(1.2, 0.9, 5.0), Vector3(x, y + 0.45, z), "wood")
			K.blob(Vector3(x, y + 1.2, z), Vector3(0.5, 0.45, 2.2), "leaf")
	K.cylinder(Vector3(-38, y + 1.6, -33.6), 0.18, 3.2, "leaf")
	for i in range(6):
		var petal: MeshInstance3D = K.blob(Vector3(-38, y + 3.3, -33.6) + Vector3(cos(i * TAU / 6), 0, sin(i * TAU / 6)) * 0.9, Vector3(0.75, 0.25, 0.45), "pink")
		petal.rotation.y = - i * TAU / 6
	K.blob(Vector3(-38, y + 3.35, -33.6), Vector3(0.5, 0.35, 0.5), "yellow")
	K.sign_text("SERRE DE MISS BLOOMIE", Vector3(-38, y + 3.9, -11.7), "s", 34, Color("d9ecd2"))
	clear_rects.append(Rect2(-49, -39, 22, 32))

func _treehouse() -> void :

	var y: float = TREEHOUSE
	var p2: Rect2 = Rect2(26, -22, 10, 8)
	var bridge: Rect2 = Rect2(29, -32, 4, 10)
	var p1: Rect2 = Rect2(26, -42, 10, 10)
	for rect in [p2, bridge, p1]:
		L._floor(rect, y, L._wood, 0.35)
		K.planks(rect, y, rect.size.x > rect.size.y)
	L._ramp(Vector3(30, HIGH, -2), Vector3(30, y, -14), 4, L._wood)
	for rect in [p2, p1]:
		for corner in [rect.position, rect.position + Vector2(rect.size.x, 0), rect.position + Vector2(0, rect.size.y), rect.end]:
			var inset: Vector2 = (rect.get_center() - corner).normalized() * 0.6
			K.stilt(Vector3(corner.x + inset.x, HIGH, corner.y + inset.y), y - HIGH - 0.35)
	L._rail(Vector3(29, y, -32), Vector3(29, y, -22))
	L._rail(Vector3(33, y, -32), Vector3(33, y, -22))
	L._rail(Vector3(26, y, -42), Vector3(36, y, -42))

	for x in [27.0, 35.0]:
		for z in [-41.0, -35.0]:
			K.deco(Vector3(0.25, 2.5, 0.25), Vector3(x, y + 1.25, z), "wood")
	var roof_l: MeshInstance3D = K.deco(Vector3(5.2, 0.15, 8.0), Vector3(29, y + 3.3, -38), "red")
	roof_l.rotation.z = 0.35
	var roof_r: MeshInstance3D = K.deco(Vector3(5.2, 0.15, 8.0), Vector3(33, y + 3.3, -38), "red")
	roof_r.rotation.z = -0.35
	K.sign_text("CABANE DES ÉLÈVES", K.board(Vector3(31, y + 2.25, -35.0), "s", Vector2(7.8, 0.5)), "s", 30, Color("f2dcae"))

	L._drop_link(Vector3(34, y, -38), Vector3(39, HIGH, -38))
	L._drop_link(Vector3(28, y, -38), Vector3(24, HIGH, -38))
	clear_rects.append(Rect2(23, -46, 16, 47))

func _north_plateau() -> void :
	var y: float = HIGH

	K.fence(Vector3(-74, y, -58), Vector3(-3.2, y, -58), "wood", 1.4)
	K.fence(Vector3(3.2, y, -58), Vector3(74, y, -58), "wood", 1.4)
	var road: StandardMaterial3D = S._mat(Color("3a3d47"))
	L._box(Vector3(148, 0.02, 5), Vector3(0, y + 0.02, -61.5), road, false)
	for x in range(-70, 71, 8):
		K.deco(Vector3(3, 0.012, 0.25), Vector3(x, y + 0.035, -61.5), "yellow")
	K.school_bus(Vector3(20, y, -61.6), true)
	for x in [-58.0, -44.0, -30.0, -16.0, 16.0, 30.0, 44.0, 58.0]:
		K.tree(Vector3(x, y, -68.5), 12.0 + fposmod(x * 0.37, 3.0), int(absf(x)) % 3, false)
	K.fence(Vector3(-74, y, -69.6), Vector3(74, y, -69.6), "wood", 1.0)
	_gate(Vector3(0, y, -58))

	for wall in [[Vector3(-40, y, -52), Vector3(10, 2.2, 1.0)], [Vector3(-46, y, -48), Vector3(1.0, 2.2, 8)], [Vector3(40, y, -50), Vector3(10, 2.2, 1.0)], [Vector3(-16, y, -50), Vector3(6, 1.4, 1.0)], [Vector3(16, y, -48), Vector3(1.0, 1.8, 6)]]:
		K.solid(wall[1], wall[0] + Vector3(0, wall[1].y * 0.5, 0), "stone")
		K.deco(wall[1] * Vector3(1.04, 0.1, 1.04), wall[0] + Vector3(0, wall[1].y, 0), "cream" if snow else "trim")
	K.solid(Vector3(6, 0.3, 2.4), Vector3(-10, y + 2.8, -55.5), "red")
	for x in [-12.6, -7.4]:
		K.stilt(Vector3(x, y, -55.5), 2.7, "metal")
	K.bench(Vector3(-10, y, -55.5), 4.0, true)
	K.sign_text("ARRÊT DU BUS SCOLAIRE", K.board(Vector3(-10, y + 3.2, -54.4), "s", Vector2(4.2, 0.5)), "s", 28, Color("f1d9a0"))
	clear_rects.append(Rect2(-8, -70, 16, 20))
	clear_rects.append(Rect2(-74, -70, 148, 13))


func _gate(center: Vector3) -> void :
	for side in [-1.0, 1.0]:
		K.solid(Vector3(0.6, 4.4, 0.6), center + Vector3(side * 3.3, 2.2, 0), "stone")
		K.deco(Vector3(0.8, 0.3, 0.8), center + Vector3(side * 3.3, 4.5, 0), "trim")
	K.deco(Vector3(7.2, 0.5, 0.4), center + Vector3(0, 4.2, 0), "wood")
	S._hinged_exit(center, 6.0, 3.6, S._exit_glass())
	L.solids.append(AABB(center + Vector3(-3.2, 0, -0.3), Vector3(6.4, 3.6, 0.6)))
	# 0.17 : la lampe pend sous la traverse et SORTIE est peint sur un panneau posé dessus (les deux flottaient)
	L._lamp(center + Vector3(0, 3.86, 0.15), 1.0, 13)
	S._label("SORTIE", K.board(center + Vector3(0, 4.85, 0), "s", Vector2(2.4, 0.8)), 56, Color("d7e5cb"))

func _janitor_shed() -> void :

	L._partition(Vector3(-70, 0, 8), Vector3(-58, 0, 8), [], 3.6, 4.0)
	L._partition(Vector3(-70, 0, 8), Vector3(-70, 0, 22), [], 3.6, 4.0)
	L._partition(Vector3(-58, 0, 8), Vector3(-58, 0, 22), [16.0], 3.6, 4.0, null, 3.0)
	L._partition(Vector3(-70, 0, 22), Vector3(-58, 0, 22), [-64.0], 3.6, 4.0, null, 3.0)
	L._box(Vector3(13, 0.3, 15), Vector3(-64, 3.75, 15), L._trim, true, false)
	K.wood_floor(Rect2(-70, 8, 12, 14))
	K.bookshelf(Vector3(-69, 0, 15), 5.0, false, 2.2, false)
	K.crate_stack(Vector3(-62, 0, 11), 2)
	K.cylinder(Vector3(-67, 0.4, 20), 0.4, 0.8, "yellow")
	var mop: MeshInstance3D = K.deco(Vector3(0.05, 1.6, 0.05), Vector3(-66.82, 1.25, 20.1), "wood")
	mop.rotation.z = 0.12
	K.sign_text("REMISE DU CONCIERGE", Vector3(-57.7, 3.1, 11), "e", 28, Color("e8d6b0"))
	clear_rects.append(Rect2(-73, 5, 18, 21))

func _picnic_garden() -> void :

	for p in [Vector3(52, 0, 30), Vector3(52, 0, 48)]:
		K.picnic(p, true)
	for z in [28.0, 50.0]:
		K.solid(Vector3(8, 0.7, 2.2), Vector3(66, 0.35, z), "wood")
		for i in range(4):
			K.blob(Vector3(63 + i * 2, 0.95, z), Vector3(0.5, 0.35, 0.5), "leaf")
	K.solid(Vector3(2.2, 0.7, 6), Vector3(68, 0.35, 39), "wood")
	for i in range(3):
		K.blob(Vector3(68, 0.95, 37 + i * 2), Vector3(0.5, 0.35, 0.5), "leaf")
	var scarecrow: MeshInstance3D = K.deco(Vector3(0.12, 2.6, 0.12), Vector3(64, 1.3, 39), "wood")
	scarecrow.rotation.z = 0.05
	K.deco(Vector3(1.6, 0.1, 0.1), Vector3(64, 2.0, 39), "wood")
	K.blob(Vector3(64, 2.55, 39), Vector3(0.3, 0.3, 0.3), "chalk")
	K.stake_sign(Vector3(66, 0, 25.8), "s", "POTAGER", 30, Color("e6ddb6"), 1.6)
	clear_rects.append(Rect2(48, 24, 26, 30))

func _playground() -> void :

	for x in [-12.0, -4.0, 4.0, 12.0]:
		for z in [38.0, 52.0]:
			K.pillar(Vector3(x, 0, z), 4.5, 0.6, "red")
	L._box(Vector3(30, 0.35, 16), Vector3(0, 4.7, 45), L._trim, true, false)
	K.deco(Vector3(30.4, 0.5, 0.3), Vector3(0, 4.35, 37), "red")
	K.deco(Vector3(30.4, 0.5, 0.3), Vector3(0, 4.35, 53), "red")
	var concrete: StandardMaterial3D = S._mat(Color("62656c") if not snow else Color("8f9aa6"))
	L._box(Vector3(30, 0.02, 16), Vector3(0, 0.02, 45), concrete, false)
	for i in range(8):
		K.deco(Vector3(1.0, 0.012, 1.0), Vector3(-9 + (i % 2) * 1.1, 0.035, 40 + i * 1.1), "chalk")
	K.sign_text("PRÉAU", Vector3(0, 4.35, 37.17), "s", 48, Color("f3e1b8"))
	K.sign_text("PRÉAU", Vector3(0, 4.35, 36.83), "n", 48, Color("f3e1b8"))
	K.bench(Vector3(-13.5, 0, 45), 5.0, false)
	K.bench(Vector3(13.5, 0, 45), 5.0, false)
	clear_rects.append(Rect2(-16, 34, 32, 22))

	K.swings(Vector3(-28, 0, 44), true)
	K.slide(Vector3(-24, 0, 54), "e")
	K.dome(Vector3(-36, 0, 52), 2.2)
	K.rug(Rect2(-40, 38, 20, 22), 0.0, "orange")
	clear_rects.append(Rect2(-42, 36, 24, 26))
	var court: Rect2 = Rect2(20, 38, 18, 18)
	K.rug(court, 0.0, "blue")
	K.deco(Vector3(0.1, 0.012, 18), Vector3(29, 0.04, 47), "chalk")
	K.cylinder(Vector3(29, 0.04, 47), 2.0, 0.01, "chalk")
	K.stilt(Vector3(37, 0, 47), 3.4, "metal")
	K.basket(Vector3(36.75, 0, 47), "w", 3.05)
	clear_rects.append(Rect2(18, 36, 22, 22))

func _school_facade() -> void :

	var wall: Material = L._wall
	L._box(Vector3(90, 12, 1.0), Vector3(0, 6, 64.5), wall, true, false)
	L.solids.append(AABB(Vector3(-45, 0, 64), Vector3(90, 12, 1)))
	for x in range(-40, 41, 8):
		for y in [3.0, 8.0]:
			K.window(Vector3(x, y, 64.0), "n", 3.0, 2.4)
	K.sign_text("ÉCOLE FONDAMENTALE", Vector3(0, 10.6, 63.9), "n", 90, Color("f0e2c2"))
	K.deco(Vector3(0.9, 3.4, 0.2), Vector3(0, 1.7, 63.9), "trim")
	K.deco(Vector3(3.2, 3.6, 0.1), Vector3(0, 1.8, 63.95), "wood")



func _hedges() -> void :
	for side in [-1.0, 1.0]:
		for hedge in [[Vector3(-13, 0, 6), Vector3(10, 2.4, 1.2)], [Vector3(-18, 0, 11), Vector3(1.2, 2.4, 8)], [Vector3(-9, 0, 12), Vector3(8, 2.4, 1.2)], [Vector3(-13, 0, 18), Vector3(8, 2.4, 1.2)]]:
			var center: Vector3 = hedge[0] * Vector3(side, 1, 1)
			var size: Vector3 = hedge[1]
			K.solid(size, center + Vector3(0, size.y * 0.5, 0), "leaf")
			K.blob(center + Vector3(0, size.y, 0), Vector3(size.x * 0.52, 0.35, size.z * 0.52), "leaf")
		clear_rects.append(Rect2(-20 if side < 0 else 4, 3, 16, 17))

	for p in [Vector3(-44, 0, 26), Vector3(-30, 0, 26), Vector3(40, 0, 26), Vector3(28, 0, 30), Vector3(-62, 0, -30), Vector3(62, 0, -30), Vector3(-60, 0, 4), Vector3(60, 0, 8), Vector3(-44, HIGH, -40), Vector3(44, HIGH, -12)]:
		K.blocker(Vector3(2.2, 1.7, 2.2), p + Vector3(0, 0.85, 0))
		K.blob(p + Vector3(0, 0.9, 0), Vector3(1.3, 0.95, 1.2), "leaf")
		clear_rects.append(Rect2(p.x - 2, p.z - 2, 4, 4))

func _paths() -> void :
	for route in [[Vector2(0, 36), Vector2(-36, 16)], [Vector2(0, 36), Vector2(44, 16)], [Vector2(0, 36), Vector2(0, 2)], [Vector2(-17, 38), Vector2(-60, 25)], [Vector2(17, 38), Vector2(56, 30)], [Vector2(-62, 7), Vector2(-66, -14)], [Vector2(60, 20), Vector2(64, -14)]]:
		S._forest_route(route[0], route[1], 5)


func _population() -> void :
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 13013
	var accepted: Array[Vector2] = []
	for attempt in range(1400):
		if accepted.size() >= 120:
			break
		var p2: Vector2 = Vector2(rng.randf_range(-72, 72), rng.randf_range(-62, 60))
		var height: float = _level_at(p2)
		if height < 0.0:
			continue
		if not _tree_spot(p2, 3.0):
			continue
		var crowded: bool = false
		for other in accepted:
			if other.distance_to(p2) < 5.5:
				crowded = true
				break
		if crowded:
			continue
		accepted.append(p2)
		# 0.17 : la place reste dans le tirage (les autres arbres ne bougent pas), mais pas d'arbre qui pousse
		# dans un rocher, un muret ou un meuble
		var tree_height: float = rng.randf_range(10, 16)
		if _crowded_by_solid(Vector3(p2.x, height, p2.y), tree_height):
			continue
		K.tree(Vector3(p2.x, height, p2.y), tree_height, accepted.size() % 3)

	for i in range(64):
		var angle: float = i * TAU / 64.0
		var radius: float = 88.0 + fposmod(float(i) * 7.3, 12.0)
		var p: Vector3 = Vector3(cos(angle) * radius * 0.95, 0, sin(angle) * radius * 0.85)
		if p.z > 60 and absf(p.x) < 50:
			continue
		# 0.17 : la couronne d'arbres reste hors de la carte (des arbres sans collision poussaient dans la cour,
		# dans le potager et sous le plateau) et pousse sur le sol de décor, haut au nord
		if L.bounds.grow(3.0).has_point(Vector2(p.x, p.z)):
			continue
		# ni dans un rocher du pourtour, ni collé au pied de la falaise du nord (le feuillage entrait dedans)
		var ring_height: float = 14 + fposmod(float(i) * 3.1, 6.0)
		if _in_perimeter_rock(p, ring_height) or absf(p.z + 44.0) < 3.0:
			continue
		p.y = HIGH if p.z < -44.0 else 0.0
		K.tree(p, ring_height, i % 3, false)

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

func _level_at(p: Vector2) -> float:
	for rect in plateaus:
		if rect.grow(2.5).has_point(p) and not rect.grow(-2.5).has_point(p):
			return -1.0
		if rect.has_point(p):
			return HIGH
	return 0.0

func _tree_spot(p: Vector2, margin: float) -> bool:
	for rect in clear_rects:
		if rect.grow(margin).has_point(p):
			return false
	for route_point in S._forest_paths:
		if route_point.distance_to(p) < margin + 2.5:
			return false

	if Rect2(-22, -44, 44, 44).grow(1.0).has_point(p):
		return false
	for objective in S.objectives:
		if Vector2(objective.x, objective.z).distance_to(p) < 7.0:
			return false
	return true

func _lights() -> void :
	var warm: Color = Color("ffb36b")
	for p in [Vector3(-8, 0, 30), Vector3(8, 0, 30), Vector3(-30, 0, 18), Vector3(40, 0, 18), Vector3(-56, 0, 26), Vector3(56, 0, 26), Vector3(-60, 0, -8), Vector3(60, 0, -10), Vector3(-6, 0, -22), Vector3(-26, HIGH, -6), Vector3(26, HIGH, -44 + 2), Vector3(-30, HIGH, -46), Vector3(40, HIGH, -46)]:
		K.lantern(p, 0.75, warm)
	for x in [-8.0, 8.0]:
		K.ceiling_lamp(Vector3(x, 4.45, 45), 0.8, 16)
	K.accent_light(Vector3(-38, HIGH + 2.4, -26), Color("c8f0b4"), 0.6, 12)
	K.accent_light(Vector3(31, TREEHOUSE + 2.6, -38), Color("ffc27a"), 0.8, 10)
	K.accent_light(Vector3(-64, 3.0, 15), Color("ffd49c"), 0.6, 9)

func _perimeter() -> void :

	for wall in [[Vector3(0, 6, -70.5), Vector3(152, 12, 1)], [Vector3(0, 6, 65.5), Vector3(152, 12, 1)], [Vector3(-75.5, 6, -3), Vector3(1, 12, 138)], [Vector3(75.5, 6, -3), Vector3(1, 12, 138)]]:
		K.blocker(wall[1], wall[0])
	var tint: Color = Color("758b99") if snow else Color("4b5d56")
	for rock: Array in _perimeter_rocks():
		S._rock(rock[0], rock[1], false, tint)

# [position, dimensions] des gros rochers hors de la carte (même ordre qu'avant : mêmes tirages aléatoires)
func _perimeter_rocks() -> Array:
	var rocks: Array = []
	for x in range(-72, 73, 12):
		rocks.append([Vector3(x, HIGH, -75), Vector3(10, 9, 6)])
	for z in range(-60, 61, 12):
		for x in [-78.0, 78.0]:
			rocks.append([Vector3(x, HIGH if z < -44 else 0.0, z), Vector3(6, 9, 10)])
	for x in [-66.0, -54.0, 54.0, 66.0]:
		rocks.append([Vector3(x, 0, 68), Vector3(10, 7, 6)])
	return rocks

func _zones() -> void :
	L._zone("Cabane des élèves", Rect2(24, -43, 14, 30), TREEHOUSE)
	L._zone("Pont cassé", Rect2(-22, -14, 44, 4), HIGH)
	L._zone("Serre de Miss Bloomie", Rect2(-46, -36, 16, 24), HIGH)
	L._zone("Portail du bus", Rect2(-74, -70, 148, 26), HIGH)
	L._zone("Terrasse ouest", Rect2(-50, -44, 28, 44), HIGH)
	L._zone("Terrasse est", Rect2(22, -44, 28, 44), HIGH)
	L._zone("La fosse", Rect2(-22, -44, 44, 44), 0)
	L._zone("Remise du concierge", Rect2(-70, 8, 12, 14), 0)
	L._zone("Potager", Rect2(50, 20, 24, 30), 0)
	L._zone("Préau", Rect2(-16, 36, 32, 20), 0)
	L._zone("Cour de récréation", Rect2(-74, 34, 148, 30), 0)
	L._zone("Bois de l'ouest", Rect2(-74, -44, 24, 78), 0)
	L._zone("Bois de l'est", Rect2(50, -44, 24, 78), 0)
	L._zone("Sous-bois", Rect2(-74, 0, 148, 34), 0)

func _gameplay_points() -> void :
	S.spawn_points.clear()
	for i in range(6):
		S.spawn_points.append(Vector3(-6 + (i % 3) * 6, 0.1, 46 + (i / 3) * 4))
	S.killer_spawn = Vector3(24, HIGH + 0.1, -52)
	# 0.17 : les meubles d'archive reposent sur ce qui est dessous (herbe du plateau, tapis jaune de la fosse,
	# plancher de la cabane et de la remise)
	S.objectives.assign([Vector3(-38, HIGH + 0.015, -32), Vector3(-9, 0.022, -28), Vector3(31, TREEHOUSE, -18), Vector3(-64, 0.024, 14), Vector3(60, 0.0, 40)])
	S.patrol_points.assign([Vector3(0, 0, 30), Vector3(0, 0, -20), Vector3(-36, 0, 20), Vector3(44, 0, 20), Vector3(-62, 0, -8), Vector3(62, 0, -8), Vector3(-36, HIGH, -4), Vector3(40, HIGH, -8), Vector3(0, HIGH, -50), Vector3(-40, HIGH, -46), Vector3(42, HIGH, -46), Vector3(-64, 0, 26), Vector3(58, 0, 36), Vector3(-28, 0, 50), Vector3(28, 0, 50), Vector3(31, TREEHOUSE, -18)])
	L.upper_targets.assign([Vector3(-36, HIGH, -4), Vector3(40, HIGH, -8), Vector3(0, HIGH, -50), Vector3(31, TREEHOUSE, -18)])
	S.menu_spawn = Vector3(0, 0.05, 42)
	S.cinematic_anchor = Vector3(0, HIGH + 0.05, -50)
	S.cinematic_exit = Vector3(0, HIGH + 0.05, -61)
	S.cinematic_path.assign([Vector3(0, HIGH + 0.05, -60), Vector3(0, HIGH + 0.05, -56), Vector3(0, HIGH + 0.05, -50)])
	L.exit_point = Vector3(0, HIGH + 0.05, -56.9)
	L.outlets.assign([Vector3(-10, 0, 48), Vector3(-52, 0, 12), Vector3(-36, HIGH, -6), Vector3(50, 0, 36), Vector3(38, HIGH, -4)])
	L.portable_outlets = true
