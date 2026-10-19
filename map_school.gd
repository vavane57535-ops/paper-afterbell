extends RefCounted
























const Kit = preload("res://map_kit.gd")

const UP: float = 5.0
const SLAB: float = 4.6
const ROOF: float = 9.6
const WALL_LOW: float = 4.6
const WALL_HIGH: float = 5.0

var L: RefCounted
var S: Node3D
var K: RefCounted

func build(layout: RefCounted) -> void :
	L = layout
	S = layout.school
	K = Kit.new(layout)
	S.map_title = "École fondamentale · Après la cloche · OM"
	L.bounds = Rect2(-56, -44, 112, 94)
	_floors()
	_walls()
	_stairs_and_galleries()
	_library()
	_circle_class()
	_cafeteria()
	_thavel_class()
	_infirmary()
	_art_room()
	_locker_room()
	_gym()
	_lobby()
	_lab()
	_atrium()
	_corridor()
	_principal_office()
	_portrait_hall()
	_music_room()
	_landings()
	_detention()
	_copy_room()
	_roof_and_windows()
	_exit()
	_zones()
	_gameplay_points()
	L._paint_zone_map()
	L._moon()



func _floors() -> void :
	L._floor(Rect2(-54, -42, 108, 84), 0.0, L._ground_material, 0.6)
	L._floor(Rect2(-8, 42, 16, 5), 0.0, L._ground_material, 0.6)


	for rect in [Rect2(-54, -42, 36, 60), Rect2(18, -42, 36, 60), Rect2(-18, -42, 36, 24), Rect2(-18, -18, 36, 6), Rect2(-18, -12, 6, 30), Rect2(12, -12, 6, 30), Rect2(-12, 12, 24, 6)]:
		L._floor(rect, UP, L._upper, 0.4)

func _walls() -> void :

	L._partition(Vector3(-54, 0, -42), Vector3(54, 0, -42), [], ROOF)
	L._partition(Vector3(-54, 0, -42), Vector3(-54, 0, 42), [], ROOF)
	L._partition(Vector3(54, 0, -42), Vector3(54, 0, 42), [], ROOF)

	L._partition(Vector3(-54, 0, 42), Vector3(-3, 0, 42), [], ROOF)
	L._partition(Vector3(3, 0, 42), Vector3(54, 0, 42), [], ROOF)
	L._box(Vector3(6, ROOF - 4.2, 0.5), Vector3(0, 4.2 + (ROOF - 4.2) * 0.5, 42), L._wall, true, false)

	L._partition(Vector3(-18, 0, -42), Vector3(-18, 0, -18), [-30.0], WALL_LOW)
	L._partition(Vector3(18, 0, -42), Vector3(18, 0, -18), [-30.0], WALL_LOW)
	L._partition(Vector3(-54, 0, -18), Vector3(-18, 0, -18), [-40.0], WALL_LOW)
	L._partition(Vector3(-18, 0, -18), Vector3(18, 0, -18), [-9.0, 9.0], WALL_LOW)
	L._partition(Vector3(18, 0, -18), Vector3(54, 0, -18), [40.0], WALL_LOW)
	L._partition(Vector3(-18, 0, -18), Vector3(-18, 0, 0), [-9.0], WALL_LOW)
	L._partition(Vector3(-18, 0, 0), Vector3(-18, 0, 18), [9.0], WALL_LOW)
	L._partition(Vector3(-54, 0, 0), Vector3(-18, 0, 0), [-40.0], WALL_LOW)
	L._partition(Vector3(18, 0, -18), Vector3(18, 0, 0), [-9.0], WALL_LOW)
	L._partition(Vector3(18, 0, 0), Vector3(18, 0, 18), [9.0], WALL_LOW)
	L._partition(Vector3(18, 0, 0), Vector3(54, 0, 0), [40.0], WALL_LOW)
	L._partition(Vector3(-54, 0, 18), Vector3(-18, 0, 18), [-30.0], WALL_LOW)
	L._partition(Vector3(-18, 0, 18), Vector3(18, 0, 18), [-9.0, 9.0], WALL_LOW)
	L._partition(Vector3(18, 0, 18), Vector3(54, 0, 18), [30.0], WALL_LOW)

	L._partition(Vector3(-18, 0, 18), Vector3(-18, 0, 42), [30.0], ROOF)
	L._partition(Vector3(18, 0, 18), Vector3(18, 0, 42), [30.0], ROOF)

	var base: float = SLAB
	L._partition(Vector3(-18, base, -42), Vector3(-18, base, -18), [-30.0], WALL_HIGH)
	L._partition(Vector3(18, base, -42), Vector3(18, base, -18), [-30.0], WALL_HIGH)
	L._partition(Vector3(-54, base, -18), Vector3(-18, base, -18), [-40.0], WALL_HIGH)
	L._partition(Vector3(-18, base, -18), Vector3(18, base, -18), [-10.0, 10.0], WALL_HIGH)
	L._partition(Vector3(18, base, -18), Vector3(54, base, -18), [40.0], WALL_HIGH)
	L._partition(Vector3(-18, base, -18), Vector3(-18, base, 18), [-12.0, 8.0], WALL_HIGH)
	L._partition(Vector3(18, base, -18), Vector3(18, base, 18), [-12.0, 8.0], WALL_HIGH)
	L._partition(Vector3(-54, base, -6), Vector3(-18, base, -6), [-44.0, -26.0], WALL_HIGH)
	L._partition(Vector3(18, base, -6), Vector3(54, base, -6), [26.0, 44.0], WALL_HIGH)
	L._partition(Vector3(-54, base, 18), Vector3(-18, base, 18), [-50.0], WALL_HIGH)
	L._partition(Vector3(18, base, 18), Vector3(54, base, 18), [50.0], WALL_HIGH)

	for x in [-36.0, 36.0]:
		K.deco(Vector3(36, 0.4, 0.56), Vector3(x, 4.8, 18), "trim")

func _stairs_and_galleries() -> void :
	var step: StandardMaterial3D = S._mat(Color("8f8574"))
	S._finish(step, "wood", 0.8)

	for x in [-8.0, 8.0]:
		L._ramp(Vector3(x, 0, 6), Vector3(x, UP, -12), 4, step)
		for side in [-1.0, 1.0]:
			# 0.17 : le limon s'arrête contre le poteau de la galerie (il le traversait et dépassait du plancher)
			var stringer: MeshInstance3D = K.deco(Vector3(0.3, 0.9, 18.62), Vector3(x + side * 2.22, UP * 0.5 + 0.45, -2.96), "trim")
			stringer.rotation.x = atan2(UP, 18.0)

	for x in [-50.0, 50.0]:
		L._ramp(Vector3(x, 0, 38), Vector3(x, UP, 18), 6, step)
		# 0.17 : la rambarde pleine repose sur le bord de l'escalier (elle flottait 50 cm au-dessus) et arrête
		# vraiment, comme une rambarde
		var rail: MeshInstance3D = K.deco(Vector3(0.2, 1.0, 20.7), Vector3(x - signf(x) * 3.1, UP * 0.5 + 0.5, 28), "trim")
		rail.rotation.x = atan2(UP, 20.0)
		_slanted_solid(Vector3(0.2, 1.0, 20.7), rail.transform)


	for span in [Vector2(-12, -10), Vector2(-6, -2), Vector2(2, 6), Vector2(10, 12)]:
		L._rail(Vector3(span.x, UP, -12), Vector3(span.y, UP, -12))
	L._rail(Vector3(-12, UP, -12), Vector3(-12, UP, 12))
	L._rail(Vector3(12, UP, -12), Vector3(12, UP, 12))
	L._rail(Vector3(-12, UP, 12), Vector3(-2, UP, 12))
	L._rail(Vector3(2, UP, 12), Vector3(12, UP, 12))
	for z in [-12.0, 12.0]:
		K.deco(Vector3(4.0, 0.12, 0.3), Vector3(0, UP + 0.06, z), "yellow")
	L._rail(Vector3(-18, UP, 18), Vector3(18, UP, 18))

	for z in [-6.0, 0.0, 6.0, 12.0]:
		for x in [-12.0, 12.0]:
			K.pillar(Vector3(x, 0, z), SLAB, 1.0)
	for x in [-4.0, 4.0]:
		K.pillar(Vector3(x, 0, 12), SLAB, 1.0)
	for x in [-12.0, 12.0]:
		K.pillar(Vector3(x, 0, -12), SLAB, 1.0)

	L._drop_link(Vector3(0, UP, 14), Vector3(0, 0, 9))
	L._drop_link(Vector3(0, UP, -14), Vector3(0, 0, -9))



# Collision d'une pièce inclinée (rambarde pleine le long d'un escalier).
func _slanted_solid(size: Vector3, xform: Transform3D) -> void :
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.transform = xform
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	S.add_child(body)

func _library() -> void :

	for x in [-48.0, -42.0, -36.0, -30.0, -24.0]:
		K.bookshelf(Vector3(x, 0, -35), 6.0, false)
		K.bookshelf(Vector3(x, 0, -25), 6.0, false)
	K.table(Vector3(-45, 0, -30), Vector2(3.2, 1.4), "wood")
	for side in [-1.0, 1.0]:
		K.chair(Vector3(-45, 0, -30 + side * 1.2), "n" if side > 0 else "s")
	K.blob(Vector3(-27, 1.35, -30), Vector3(0.45, 0.45, 0.45), "blue")
	K.cylinder(Vector3(-27, 0.45, -30), 0.12, 0.9, "wood")
	K.chalkboard(Vector3(-36, 2.2, -41.75), "s", 8, "BIBLIOTHÈQUE\nSILENCE, S'IL VOUS PLAÎT")
	K.clock(Vector3(-24, 3.4, -41.75), "s")
	K.notice_board(Vector3(-53.75, 2.0, -24), "e")
	K.paper_litter(Vector3(-39, 0, -30), 7, 2.5, 11)
	K.ceiling_lamp(Vector3(-42, 4.3, -30), 0.6, 14)
	K.ceiling_lamp(Vector3(-28, 4.3, -30), 0.6, 14)

func _circle_class() -> void :
	K.chalkboard(Vector3(0, 2.3, -41.75), "s", 12, "MISS CIRCLE · MATHÉMATIQUES\nA + B = ?     1 + 1 = 2")
	K.grade(Vector3(-11, 2.4, -41.75), "s", "A+", false)
	K.grade(Vector3(11, 2.4, -41.75), "s", "F", true)

	K.table(Vector3(0, 0, -37), Vector2(3.6, 1.4), "red")
	K.chair(Vector3(0, 0, -38.6), "s")
	# 0.17 : le grand compas du tableau est accroché à plat contre le mur (ses branches flottaient à 0,9 m)
	var hinge: Vector3 = Vector3(-17.68, 3.55, -37.0)
	K.bar(hinge, Vector3(-17.68, 1.25, -38.15), 0.1, "metal")
	K.bar(hinge, Vector3(-17.68, 1.45, -35.9), 0.1, "red")
	K.bar(Vector3(-17.68, 1.45, -35.9), Vector3(-17.68, 1.18, -35.8), 0.07, "yellow")
	K.bar(hinge, hinge + Vector3(0, 0.32, 0), 0.06, "trim")
	var pivot: MeshInstance3D = K.cylinder(hinge + Vector3(0.02, 0, 0), 0.13, 0.06, "trim")
	pivot.rotation.z = PI * 0.5

	for x in [-12.0, -8.0, -4.0, 4.0, 8.0, 12.0]:
		for z in [-32.0, -28.0, -24.0]:
			K.desk(Vector3(x, 0, z), "n")
	for side in [-1.0, 1.0]:
		K.poster(Vector3(side * 17.75, 2.4, -26), "w" if side > 0 else "e", Vector2(1.4, 1.8), "yellow")
		K.window(Vector3(side * 6, 3.6, -41.75), "s", 2.4, 1.2)
	K.clock(Vector3(17.75, 3.4, -35), "w")
	K.ceiling_lamp(Vector3(-8, 4.3, -30), 0.65, 14)
	K.ceiling_lamp(Vector3(8, 4.3, -30), 0.65, 14)

func _cafeteria() -> void :

	K.solid(Vector3(20, 1.1, 1.4), Vector3(36, 0.55, -40.2), "metal")
	K.deco(Vector3(20.2, 0.08, 1.6), Vector3(36, 1.14, -40.2), "cream")
	for i in range(6):
		K.deco(Vector3(1.4, 0.2, 0.9), Vector3(28 + i * 3.2, 1.25, -40.3), ["orange", "yellow", "green"][i % 3])
	K.sign_text("CANTINE · MENU DU JOUR : ???", Vector3(36, 3.1, -41.7), "s", 34)
	for z in [-32.0, -26.0]:
		for x in [26.0, 46.0]:
			K.long_table(Vector3(x, 0, z), 10.0, true)
	for z in [-30.0, -26.0]:
		K.vending_machine(Vector3(53.2, 0, z), "w", "vend_red" if z < -28 else "vend_blue")
	K.accent_light(Vector3(51.5, 2.2, -28), Color("e38aa0"), 0.45, 7.0)
	for x in [22.0, 50.0]:
		K.cylinder(Vector3(x, 0.5, -20.5), 0.4, 1.0, "blue")
	K.poster(Vector3(18.25, 2.4, -24), "e", Vector2(1.6, 2.0), "pink")
	K.paper_litter(Vector3(36, 0, -29), 5, 3.0, 23)
	K.ceiling_lamp(Vector3(28, 4.3, -30), 0.65, 14)
	K.ceiling_lamp(Vector3(44, 4.3, -30), 0.65, 14)

func _thavel_class() -> void :
	K.chalkboard(Vector3(-53.75, 2.3, -9), "e", 9, "MISS THAVEL · FRANÇAIS\nJE SURVIS · TU SURVIS · IL...")
	for x in [-48.0, -44.0, -34.0, -30.0, -26.0]:
		for z in [-12.0, -6.0]:
			K.desk(Vector3(x, 0, z), "w")
	K.bookshelf(Vector3(-24, 0, -16.9), 7.0, true, 2.2, false)
	K.table(Vector3(-50, 0, -15), Vector2(3.0, 1.2), "wood")
	K.poster(Vector3(-48.5, 2.6, -0.25), "n", Vector2(2.4, 1.4), "blue")
	K.poster(Vector3(-30, 2.6, -0.25), "n", Vector2(1.4, 1.8), "yellow")
	K.window(Vector3(-53.75, 3.4, -15), "e", 2.4, 1.3)
	K.ceiling_lamp(Vector3(-36, 4.3, -9), 0.6, 15)

func _infirmary() -> void :

	for x in [-50.0, -44.0]:
		K.solid(Vector3(2.0, 0.7, 3.0), Vector3(x, 0.35, 14), "chalk")
		K.deco(Vector3(1.8, 0.2, 0.8), Vector3(x, 0.8, 15.1), "cream")
		# 0.17 : le rideau pend à une tringle sur deux montants (il flottait seul au-dessus du sol)
		K.deco(Vector3(0.05, 2.28, 2.9), Vector3(x + 1.6, 1.44, 14), "pink")
		K.deco(Vector3(0.05, 0.05, 3.1), Vector3(x + 1.6, 2.6, 14), "metal")
		for z in [12.5, 15.5]:
			K.deco(Vector3(0.05, 2.6, 0.05), Vector3(x + 1.6, 1.3, z), "metal")
			K.deco(Vector3(0.42, 0.04, 0.06), Vector3(x + 1.6, 0.02, z), "metal")
	# 0.17 : l'armoire à pharmacie mordait de 50 cm sur la porte du gymnase ; elle est poussée contre le mur à côté
	K.solid(Vector3(3.0, 2.2, 0.6), Vector3(-24, 1.1, 17.4), "chalk")
	K.deco(Vector3(0.9, 0.24, 0.04), Vector3(-24, 1.7, 17.08), "red")
	K.deco(Vector3(0.24, 0.9, 0.04), Vector3(-24, 1.7, 17.08), "red")
	K.table(Vector3(-32, 0, 6), Vector2(2.4, 1.2), "cream")
	K.chair(Vector3(-32, 0, 7.2), "n")
	K.sign_text("INFIRMERIE", Vector3(-36, 3.2, 0.3), "s", 38, Color("f0c9cf"))
	K.poster(Vector3(-53.75, 2.3, 11), "e", Vector2(1.6, 1.6), "red", 2)
	K.ceiling_lamp(Vector3(-36, 4.3, 9), 0.6, 15, Color("ffe4c4"))

func _art_room() -> void :
	for x in [28.0, 44.0]:
		K.table(Vector3(x, 0, -9), Vector2(4.0, 2.0), "pink")
		for i in range(3):
			K.cylinder(Vector3(x - 1.2 + i * 1.2, 1.12, -9.3), 0.14, 0.34, ["blue", "yellow", "red"][i])

	for p in [Vector3(22, 0, -15), Vector3(36, 0, -3), Vector3(50, 0, -14)]:
		var leg: MeshInstance3D = K.deco(Vector3(0.08, 2.0, 0.08), p + Vector3(0, 1.0, 0), "wood")
		leg.rotation.x = 0.12
		K.deco(Vector3(1.2, 1.0, 0.06), p + Vector3(0, 1.5, 0.15), "chalk")
		K.deco(Vector3(0.7, 0.3, 0.07), p + Vector3(0.1, 1.6, 0.16), "orange")
	for i in range(6):
		var splash: MeshInstance3D = K.deco(Vector3(1.2, 0.012, 0.8), Vector3(24 + i * 5, 0.02, -4 - (i % 3) * 3), ["red", "blue", "yellow"][i % 3])
		splash.rotation.y = i * 0.9
	for i in range(4):
		K.poster(Vector3([23.5, 30.5, 46.5, 51.5][i], 2.5, -17.75), "s", Vector2(2.0, 1.5), ["pink", "blue", "yellow", "green"][i], 1)
	K.sign_text("ATELIER D'ART", Vector3(53.7, 3.3, -9), "w", 36, Color("f1d7a8"))
	K.ceiling_lamp(Vector3(36, 4.3, -9), 0.6, 15)

func _locker_room() -> void :
	K.locker_island(Vector3(28, 0, 6), 10.0, true)
	K.locker_island(Vector3(44, 0, 12), 8.0, true)
	K.lockers(Vector3(24, 0, 17.75), Vector3(27, 0, 17.75), "n", "blue", false)
	K.lockers(Vector3(33, 0, 17.75), Vector3(46, 0, 17.75), "n", "blue", false)
	K.lockers(Vector3(53.75, 0, 2), Vector3(53.75, 0, 16), "w", "red", false)
	K.sign_text("VESTIAIRES", Vector3(36, 3.2, 0.3), "s", 38)
	K.ceiling_lamp(Vector3(36, 4.3, 9), 0.55, 15)

func _gym() -> void :

	var line: String = "chalk"
	K.deco(Vector3(30, 0.012, 0.1), Vector3(-34, 0.025, 20.5), line)
	K.deco(Vector3(30, 0.012, 0.1), Vector3(-34, 0.025, 34.5), line)
	K.deco(Vector3(0.1, 0.012, 14), Vector3(-34, 0.025, 27.5), line)
	var circle: MeshInstance3D = K.cylinder(Vector3(-34, 0.02, 27.5), 2.4, 0.012, "orange")
	circle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 0.17 : panier fixé au mur du fond (l'ancien poteau était planté devant la porte du gymnase,
	# panneau et cercle flottant devant lui)
	K.basket(Vector3(-53.75, 0, 27.5), "e", 3.05, 0.6)

	for i in range(3):
		L._floor(Rect2(-44, 35 + i * 2, 20, 6.75 - i * 2), 0.8 * (i + 1), L._wood, 0.3, true)
		K.deco(Vector3(20, 0.06, 0.12), Vector3(-34, 0.8 * (i + 1) + 0.02, 35.1 + i * 2), "chalk")
	for p in [Vector3(-30, 0, 24), Vector3(-40, 0, 30)]:
		L._floor(Rect2(p.x - 2, p.z - 1.5, 4, 3), 0.4, K.mat("blue"), 0.4, true)
	K.sign_text("GYMNASE", Vector3(-53.7, 6.2, 30), "e", 60, Color("f1e3bd"))
	K.grade(Vector3(-36, 7.0, 41.75), "n", "A+", false)
	for x in [-44.0, -28.0]:
		K.window(Vector3(x, 7.2, 41.75), "n", 5.0, 2.6)
	K.ceiling_lamp(Vector3(-40, 9.2, 28), 0.8, 18)
	K.ceiling_lamp(Vector3(-26, 9.2, 28), 0.7, 18)

func _lobby() -> void :

	for side in [-1.0, 1.0]:
		K.pillar(Vector3(side * 12, 0, 26), 9.6, 1.2, "wall")
		K.pillar(Vector3(side * 12, 0, 36), 9.6, 1.2, "wall")
		K.bench(Vector3(side * 16.6, 0, 23.5), 4.0, false)
		K.plant(Vector3(side * 16.4, 0, 40.4), 1.2)
		K.plant(Vector3(side * 6.5, 0, 40.4), 0.9)
		K.notice_board(Vector3(side * 17.75, 2.2, 37.5), "w" if side > 0 else "e")
		K.window(Vector3(side * 13, 6.6, 41.75), "n", 5.0, 3.6)
	K.trophy_case(Vector3(0, 0, 18.7), "s", 5.6)
	K.sign_text("ÉCOLE FONDAMENTALE", Vector3(0, 7.6, 41.7), "n", 70, Color("f3e3c0"))
	K.deco(Vector3(14, 1.6, 0.06), Vector3(0, 7.6, 41.72), "red")
	K.rug(Rect2(-4, 20, 8, 21), 0.0, "carpet")
	K.clock(Vector3(0, 3.8, 18.25), "s", 0.6)
	K.ceiling_lamp(Vector3(-6, 9.2, 30), 0.85, 18)
	K.ceiling_lamp(Vector3(6, 9.2, 30), 0.85, 18)

func _lab() -> void :

	for p in [Vector3(28, 0, 24), Vector3(28, 0, 34), Vector3(40, 0, 24), Vector3(40, 0, 34)]:
		K.solid(Vector3(6.0, 1.0, 2.0), p + Vector3(0, 0.5, 0), "chalk")
		K.deco(Vector3(6.1, 0.08, 2.1), p + Vector3(0, 1.02, 0), "dark")
		for i in range(3):
			K.cylinder(p + Vector3(-2 + i * 2, 1.25, 0.3), 0.12, 0.4, ["green", "blue", "pink"][i], 0.05)
		K.deco(Vector3(0.1, 0.6, 0.1), p + Vector3(2.4, 1.3, -0.5), "metal")
	K.blocker(Vector3(0.6, 4.8, 0.6), Vector3(22, 2.4, 40))
	var stem: MeshInstance3D = K.cylinder(Vector3(22, 2.4, 40), 0.2, 4.8, "leaf")
	stem.rotation.z = 0.08
	for i in range(6):
		var petal: MeshInstance3D = K.blob(Vector3(22, 5.2, 40) + Vector3(cos(i * TAU / 6), 0, sin(i * TAU / 6)) * 1.1, Vector3(0.9, 0.3, 0.55), "pink")
		petal.rotation.y = - i * TAU / 6
	K.blob(Vector3(22, 5.25, 40), Vector3(0.6, 0.4, 0.6), "yellow")
	for x in [34.0, 46.0]:
		K.plant(Vector3(x, 0, 40.6), 1.1)
	# 0.17 : le tableau débordait de 60 cm sur l'huisserie de la porte du hall
	K.chalkboard(Vector3(18.25, 2.3, 22.6), "e", 7, "MISS BLOOMIE · SCIENCES\nOBSERVER · COMPRENDRE")
	K.sign_text("LABORATOIRE", Vector3(53.7, 6.2, 30), "w", 56, Color("cfe6d4"))
	for x in [28.0, 42.0]:
		K.window(Vector3(x, 7.2, 41.75), "n", 5.0, 2.6)
	K.ceiling_lamp(Vector3(28, 9.2, 29), 0.75, 18, Color("f3f0c8"))
	K.ceiling_lamp(Vector3(42, 9.2, 29), 0.75, 18, Color("f3f0c8"))

func _atrium() -> void :

	L._floor(Rect2(-2, -6, 4, 4), 1.0, L._stone, 0.3, true)
	K.deco(Vector3(4.3, 0.12, 4.3), Vector3(0, 1.05, -4), "trim")
	for i in range(3):
		K.deco(Vector3(3.0 - i * 0.4, 0.5, 2.2 - i * 0.2), Vector3(0, 1.3 + i * 0.5, -4), ["blue", "yellow", "red"][i])
	K.blob(Vector3(0, 3.5, -4), Vector3(1.1, 1.0, 1.1), "red")
	K.cylinder(Vector3(0, 4.6, -4), 0.07, 0.5, "wood")
	var leaf: MeshInstance3D = K.blob(Vector3(0.35, 4.75, -4), Vector3(0.35, 0.08, 0.18), "leaf")
	leaf.rotation.z = 0.4
	K.sign_text("ÉDUCATION FONDAMENTALE", Vector3(0, 1.2, -1.93), "s", 26, Color("e8dcc4"))

	K.clock(Vector3(0, 7.4, -17.75), "s", 1.1)
	K.sign_text("NE RESTEZ JAMAIS SEULS", Vector3(0, 5.9, -17.7), "s", 34, Color("e0cfb0"))

	# 0.17 : guirlande tendue d'un mur à l'autre, fanions accrochés à la ficelle (le fil s'arrêtait dans le vide
	# et les fanions des bouts flottaient dessous)
	var sag: Callable = func(x: float) -> float: return 8.95 - 0.6 * (1.0 - pow(x / 17.75, 2.0))
	for k in range(14):
		var x0: float = -17.75 + k * 35.5 / 14.0
		var x1: float = -17.75 + (k + 1) * 35.5 / 14.0
		K.bar(Vector3(x0, sag.call(x0), 0), Vector3(x1, sag.call(x1), 0), 0.035, "trim")
	for i in range(9):
		var x: float = -14.0 + i * 3.5
		var banner: MeshInstance3D = K.deco(Vector3(0.8, 0.8, 0.03), Vector3(x, sag.call(x) - 0.55, 0), ["red", "yellow", "blue"][i % 3])
		banner.rotation.z = PI / 4
	K.ceiling_lamp(Vector3(0, 9.3, 0), 0.9, 20)
	K.accent_light(Vector3(0, 3.2, -1.5), Color("ffb08a"), 0.5, 6.0)

func _corridor() -> void :

	for side in [-1.0, 1.0]:
		var wall_x: float = side * 17.75
		var facing: String = "w" if side > 0 else "e"
		K.lockers(Vector3(wall_x, 0, -16), Vector3(wall_x, 0, -12.5), facing, "blue", true)
		K.lockers(Vector3(wall_x, 0, -5.5), Vector3(wall_x, 0, 5.5), facing, "red" if side > 0 else "blue", true)
		K.lockers(Vector3(wall_x, 0, 12.5), Vector3(wall_x, 0, 16), facing, "blue", true)
		K.poster(Vector3(side * 3.6, 2.4, -17.75), "s", Vector2(1.2, 1.6), "yellow" if side > 0 else "pink")
		K.notice_board(Vector3(side * 15, 2.2, -17.75), "s", 2.0)
	K.sign_text("← BIBLIOTHÈQUE · CLASSE · CANTINE →", Vector3(0, 3.5, -17.7), "s", 26)

	for plaque in [["MISS CIRCLE", Vector3(-9, 4.38, -17.7), "s"], ["MISS CIRCLE", Vector3(9, 4.38, -17.7), "s"], ["MISS THAVEL", Vector3(-17.7, 4.38, -9), "e"], ["INFIRMERIE", Vector3(-17.7, 4.38, 9), "e"], ["ATELIER D'ART", Vector3(17.7, 4.38, -9), "w"], ["VESTIAIRES", Vector3(17.7, 4.38, 9), "w"], ["GYMNASE", Vector3(-17.7, 4.38, 30), "e"], ["LABO · MISS BLOOMIE", Vector3(17.7, 4.38, 30), "w"], ["RETENUE", Vector3(-17.7, UP + 3.4, 8), "e"], ["SALLE DES COPIES", Vector3(17.7, UP + 3.4, 8), "w"], ["PORTRAITS", Vector3(-10, UP + 3.4, -17.7), "s"], ["PORTRAITS", Vector3(10, UP + 3.4, -17.7), "s"]]:
		K.sign_text(plaque[0], plaque[1], plaque[2], 22, Color("f1e6cf"))
	for p in [Vector3(-15, 0, -15), Vector3(15, 0, -15), Vector3(-15, 0, 15), Vector3(15, 0, 15)]:
		K.ceiling_lamp(p + Vector3(0, 4.3, 0), 0.45, 11, Color("ffd49c"), false)



func _principal_office() -> void :

	var y: float = UP
	K.rug(Rect2(-48, -38, 24, 16), y, "carpet")
	K.table(Vector3(-36, y, -36), Vector2(5.0, 2.0), "wood")
	K.chair(Vector3(-36, y, -38), "s")
	for x in [-48.0, -40.0, -32.0, -24.0]:
		K.bookshelf(Vector3(x, y, -41.2), 5.0, true, 3.2, false)
	K.bookshelf(Vector3(-30, y, -26), 6.0, true, 2.2)
	K.bookshelf(Vector3(-44, y, -26), 6.0, true, 2.2)
	for z in [-36.0, -28.0]:
		K.poster(Vector3(-53.75, y + 2.6, z), "e", Vector2(1.5, 2.0), "dark", 0)
		K.deco(Vector3(0.04, 1.6, 1.1), Vector3(-53.66, y + 2.6, z), "cream")
	K.sign_text("BUREAU DU PRINCIPAL", Vector3(-17.7, y + 3.5, -30), "e", 32, Color("e0cfa8"))
	K.sign_text("ALICE\nDON'T GO THERE", Vector3(-36, y + 2.7, -41.72), "s", 46, Color("cc5968"))
	K.ceiling_lamp(Vector3(-36, 9.2, -30), 0.55, 15, Color("ff9a8a"))
	K.accent_light(Vector3(-36, y + 1.2, -34), Color("d13a4a"), 0.35, 7.0)

func _portrait_hall() -> void :
	var y: float = UP
	for x in [-8.0, 8.0]:
		K.trophy_case(Vector3(x, y, -30), "s", 4.0)
		K.trophy_case(Vector3(x, y, -29.2), "n", 4.0)
	for i in range(6):
		var x: float = -15 + i * 6
		K.deco(Vector3(1.6, 2.0, 0.06), Vector3(x, y + 2.6, -41.72), "trim")
		K.deco(Vector3(1.3, 1.7, 0.07), Vector3(x, y + 2.6, -41.68), ["pink", "blue", "yellow", "green", "red", "blue"][i])
		K.blob(Vector3(x, y + 2.9, -41.62), Vector3(0.35, 0.4, 0.05), "chalk")
	K.bench(Vector3(0, y, -22), 6.0, true)
	K.sign_text("GALERIE DES PORTRAITS", Vector3(0, y + 3.6, -41.65), "s", 36)
	K.ceiling_lamp(Vector3(0, 9.2, -30), 0.6, 16)

func _music_room() -> void :
	var y: float = UP

	K.solid(Vector3(3.2, 1.0, 2.0), Vector3(30, y + 0.5, -34), "dark")
	K.deco(Vector3(3.3, 0.08, 2.1), Vector3(30, y + 1.02, -34), "trim")
	K.deco(Vector3(3.0, 0.05, 0.4), Vector3(30, y + 0.96, -32.8), "chalk")
	# 0.17 : couvercle charnière sur le grand côté, ouvert et tenu par sa béquille (il flottait derrière le piano)
	var lid: MeshInstance3D = K.deco(Vector3(3.0, 0.06, 1.8), Vector3(28.4 + 1.5 * cos(0.38), y + 1.09 + 1.5 * sin(0.38), -34), "dark")
	lid.rotation.z = 0.38
	K.deco(Vector3(0.05, 1.0, 0.05), Vector3(31.0, y + 1.56, -33.5), "trim")
	for i in range(5):
		var angle: float = -0.8 + i * 0.4
		var p: Vector3 = Vector3(42 + sin(angle) * 6, y, -30 + cos(angle) * 6)
		K.chair(p, "n")
		K.music_stand(p + Vector3(0, 0, -0.75), "s")
	K.cylinder(Vector3(48, y + 0.45, -38), 0.7, 0.9, "red")
	K.chalkboard(Vector3(53.75, y + 2.3, -30), "w", 7, "♪ SALLE DE MUSIQUE ♪\nDO RÉ MI FA SOL")
	K.window(Vector3(28, y + 2.6, -41.75), "s", 3.0, 2.0)
	K.window(Vector3(46, y + 2.6, -41.75), "s", 3.0, 2.0)
	K.ceiling_lamp(Vector3(36, 9.2, -30), 0.6, 16)

func _landings() -> void :
	var y: float = UP
	for side in [-1.0, 1.0]:
		var x0: float = side * 36
		K.lockers(Vector3(side * 20, y, -17.75), Vector3(side * 34, y, -17.75), "s", "blue", true)
		K.bench(Vector3(side * 50, y, -12), 4.0, false)
		K.windows_row(Vector3(side * 53.75, y + 2.6, -17), Vector3(side * 53.75, y + 2.6, -7), "w" if side > 0 else "e", 5.0, 2.6, 2.0)
		K.poster(Vector3(x0, y + 2.4, -6.25), "n", Vector2(1.4, 1.8), "pink" if side > 0 else "yellow")
		K.ceiling_lamp(Vector3(x0, 9.2, -12), 0.5, 14)

func _detention() -> void :
	var y: float = UP
	for x in [-46.0, -40.0, -34.0, -28.0]:
		for z in [0.0, 6.0, 12.0]:
			if x == -46.0 and z == 12.0:
				continue
			K.desk(Vector3(x, y, z), "n")
	K.chalkboard(Vector3(-36, y + 2.3, -5.75), "s", 9, "RETENUE\nIIII IIII IIII IIII II")
	K.clock(Vector3(-18.25, y + 3.4, 2), "w")
	K.windows_row(Vector3(-53.75, y + 2.6, -4), Vector3(-53.75, y + 2.6, 14), "e", 6.0, 2.6, 2.0)
	K.sign_text("SALLE DE RETENUE", Vector3(-36, y + 3.7, -5.7), "s", 30, Color("e8b8b8"))
	K.ceiling_lamp(Vector3(-36, 9.2, 6), 0.55, 16)

func _copy_room() -> void :
	var y: float = UP

	for p in [Vector3(26, y, 2), Vector3(34, y, 8), Vector3(42, y, 2), Vector3(26, y, 12), Vector3(42, y, 12)]:
		K.crate_stack(p, 2)
	K.solid(Vector3(2.0, 1.3, 1.2), Vector3(48, y + 0.65, -4.4), "chalk")
	K.deco(Vector3(1.6, 0.06, 0.9), Vector3(48, y + 1.33, -4.4), "trim")
	K.paper_litter(Vector3(34, y, 4), 9, 5.0, 37)
	K.windows_row(Vector3(53.75, y + 2.6, -4), Vector3(53.75, y + 2.6, 14), "w", 6.0, 2.6, 2.0)
	K.sign_text("SALLE DES COPIES", Vector3(36, y + 3.7, -5.7), "s", 30)
	K.ceiling_lamp(Vector3(36, 9.2, 6), 0.55, 16)

func _roof_and_windows() -> void :
	var ceiling: StandardMaterial3D = L._ceiling
	L._box(Vector3(108, 0.4, 84), Vector3(0, ROOF + 0.2, 0), ceiling, true, false)

	for x in range(-48, 49, 12):
		K.deco(Vector3(0.4, 0.4, 84), Vector3(x, ROOF - 0.2, 0), "trim")
	for spot in [Vector3(-53.75, 2.6, -36), Vector3(-53.75, 2.6, -30), Vector3(-53.75, 2.6, 4), Vector3(53.75, 2.6, -36), Vector3(53.75, 2.6, -15)]:
		K.window(spot, "e" if spot.x < 0 else "w", 3.0, 2.0)

	for rect in [Rect2(-54, -42, 36, 60), Rect2(18, -42, 36, 60), Rect2(-18, -42, 36, 24), Rect2(-18, -18, 36, 6), Rect2(-18, -12, 6, 30), Rect2(12, -12, 6, 30), Rect2(-12, 12, 24, 6)]:
		L._box(Vector3(rect.size.x, 0.04, rect.size.y), Vector3(rect.get_center().x, SLAB - 0.03, rect.get_center().y), ceiling, false)

func _exit() -> void :

	var center: Vector3 = Vector3(0, 0, 42)
	K.deco(Vector3(6.4, 0.3, 0.7), center + Vector3(0, 4.05, 0), "trim")
	for side in [-1.0, 1.0]:
		K.deco(Vector3(0.2, 3.9, 0.7), center + Vector3(side * 3.1, 1.95, 0), "trim")
	S._hinged_exit(center, 6.0, 3.9, S._exit_glass())
	L.solids.append(AABB(center + Vector3(-3.2, 0, -0.3), Vector3(6.4, 3.9, 0.6)))
	S._label("SORTIE", center + Vector3(0, 4.6, -0.32), 52, Color("d7e5cb"), PI)
	_forecourt(center)




func _forecourt(door: Vector3) -> void :
	var paving: StandardMaterial3D = S._mat(Color("8c8f97"))
	S._finish(paving, "stone", 0.8, Vector3(4, 4, 4))
	var court: Rect2 = Rect2(-14, 42.25, 28, 16)
	L.outside_walkable.append(court)
	L._box(Vector3(court.size.x, 0.4, court.size.y), Vector3(0, -0.2, court.get_center().y), paving, true, false)
	for z in range(44, 58, 2):
		K.deco(Vector3(27.6, 0.012, 0.05), Vector3(0, 0.006, z), "trim")
	K.rug(Rect2(-2.5, 42.3, 5, 15.5), 0.0, "stone")

	S._label("ÉCOLE FONDAMENTALE", Vector3(0, 6.2, 42.3), 64, Color("f0e2c2"))
	K.deco(Vector3(12, 1.3, 0.06), Vector3(0, 6.2, 42.27), "red")
	for x in [-11.0, -6.5, 6.5, 11.0]:
		for y in [2.4, 7.2]:
			if absf(x) < 7.0 and y > 5.0:
				continue
			K.window(Vector3(x, y, 42.25), "s", 2.6, 1.8)

	for wall in [[Vector3(-14.5, 5, 50.2), Vector3(1, 10, 16)], [Vector3(14.5, 5, 50.2), Vector3(1, 10, 16)], [Vector3(0, 5, 58.6), Vector3(30, 10, 1)]]:
		K.blocker(wall[1], wall[0], false)
	for side in [-1.0, 1.0]:
		K.deco(Vector3(1.4, 1.5, 15.4), Vector3(side * 13.4, 0.75, 50.2), "leaf")
		K.blob(Vector3(side * 13.4, 1.5, 50.2), Vector3(0.75, 0.3, 7.7), "leaf")
		K.fence(Vector3(side * 13.8, 0, 57.8), Vector3(side * 3.4, 0, 57.8), "metal", 1.6)
		K.deco(Vector3(0.5, 4.6, 0.5), Vector3(side * 3.2, 2.3, 57.8), "stone")
		K.deco(Vector3(0.7, 0.3, 0.7), Vector3(side * 3.2, 4.7, 57.8), "trim")

		K.deco(Vector3(0.14, 3.4, 0.14), Vector3(side * 5.5, 1.7, 47), "trim")
		K.deco(Vector3(0.5, 0.6, 0.5), Vector3(side * 5.5, 3.6, 47), "lamp")
		K.cylinder(Vector3(side * 9.5, 0.45, 53), 1.1, 0.9, "stone")
		S._forest_tree(Vector3(side * 9.5, 0.85, 53), 6.5, 0, false)
		K.bench(Vector3(side * 9.5, 0, 46.5), 3.0, true)
	K.deco(Vector3(6.8, 0.8, 0.3), Vector3(0, 4.4, 57.8), "red")
	S._label("À DEMAIN !", Vector3(0, 4.4, 57.6), 44, Color("f3e1c0"), PI)
	var lamp: OmniLight3D = K.accent_light(Vector3(0, 3.4, 47.5), Color("ffd9a8"), 1.1, 13.0)
	lamp.shadow_enabled = false
	K.accent_light(Vector3(0, 3.2, 55), Color("ffd9a8"), 0.6, 9.0)



func _zones() -> void :

	L._zone("Bureau du principal", Rect2(-54, -42, 36, 24), UP)
	L._zone("Galerie des portraits", Rect2(-18, -42, 36, 24), UP)
	L._zone("Salle de musique", Rect2(18, -42, 36, 24), UP)
	L._zone("Palier ouest", Rect2(-54, -18, 36, 12), UP)
	L._zone("Palier est", Rect2(18, -18, 36, 12), UP)
	L._zone("Salle de retenue", Rect2(-54, -6, 36, 24), UP)
	L._zone("Salle des copies", Rect2(18, -6, 36, 24), UP)
	L._zone("Galeries de l'atrium", Rect2(-18, -18, 36, 36), UP)
	L._zone("Bibliothèque", Rect2(-54, -42, 36, 24), 0)
	L._zone("Classe de Miss Circle", Rect2(-18, -42, 36, 24), 0)
	L._zone("Cantine", Rect2(18, -42, 36, 24), 0)
	L._zone("Classe de Miss Thavel", Rect2(-54, -18, 36, 18), 0)
	L._zone("Infirmerie", Rect2(-54, 0, 36, 18), 0)
	L._zone("Atelier d'art", Rect2(18, -18, 36, 18), 0)
	L._zone("Vestiaires", Rect2(18, 0, 36, 18), 0)
	L._zone("Gymnase", Rect2(-54, 18, 36, 24), 0)
	L._zone("Hall d'entrée", Rect2(-18, 18, 36, 30), 0)
	L._zone("Laboratoire de Miss Bloomie", Rect2(18, 18, 36, 24), 0)
	L._zone("Atrium · Grand escalier", Rect2(-12, -12, 24, 24), 0)
	L._zone("Couloir des casiers", Rect2(-18, -18, 36, 36), 0)

func _gameplay_points() -> void :
	S.spawn_points.clear()
	for i in range(6):
		S.spawn_points.append(Vector3(-6 + (i % 3) * 6, 0.1, 34 + (i / 3) * 4))
	S.killer_spawn = Vector3(-36, UP + 0.1, -31)
	# 0.17 : les meubles d'archive reposent sur le sol (ils flottaient à 5 cm)
	S.objectives.assign([Vector3(-39, 0.0, -30), Vector3(0, 0.0, -34), Vector3(36, 0.0, -35.5), Vector3(-30, UP, 9), Vector3(36, UP, -29)])
	S.patrol_points.assign([Vector3(0, 0, 9), Vector3(-15, 0, 0), Vector3(15, 0, 0), Vector3(0, 0, -15), Vector3(-36, 0, -30), Vector3(0, 0, -26), Vector3(36, 0, -29), Vector3(-36, 0, -9), Vector3(-36, 0, 9), Vector3(36, 0, -9), Vector3(36, 0, 9), Vector3(-34, 0, 28), Vector3(34, 0, 29), Vector3(0, 0, 30), Vector3(-15, UP, 0), Vector3(15, UP, 0), Vector3(0, UP, -30), Vector3(-36, UP, 6), Vector3(36, UP, 6), Vector3(36, UP, -29)])
	L.upper_targets.assign([Vector3(-15, UP, 0), Vector3(15, UP, 0), Vector3(0, UP, -30), Vector3(-36, UP, 6)])
	S.menu_spawn = Vector3(0, 0.05, 24.5)
	S.cinematic_anchor = Vector3(0, 0.05, 30)
	S.cinematic_exit = Vector3(0, 0.05, 45)
	S.cinematic_path.assign([Vector3(0, 0.05, 44), Vector3(0, 0.05, 37), Vector3(0, 0.05, 30)])
	L.exit_point = Vector3(0, 0.05, 41.1)

	L.outlets.assign([Vector3(-26, 0, 1.1), Vector3(-40, 0, 19.1), Vector3(44, 0, 19.1), Vector3(-50, UP, -4.9), Vector3(46, UP, -40.9)])
	L.portable_outlets = false
