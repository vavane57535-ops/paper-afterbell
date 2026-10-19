extends "res://menu_scene.gd"

# TERRAIN D'ESSAI : le gymnase, la nuit, une seule lampe allumée au-dessus du tapis.
# Usayuko boxe un mannequin en carton à la tête d'Alice, monté sur un ressort ; Elly lit sur le
# plinth. Le gros coup, le carton revient lui claquer le visage. Pendant qu'il raconte, la tête du
# carton se penche toute seule derrière lui. Puis le néon claque, et le carton s'est rapproché.

const MenuTraining = preload("res://anim_menu_training.gd")

var _lamp: SpotLight3D
var _bulb: StandardMaterial3D
var _dummy: Node3D
var _tilt: Node3D
var _head: Node3D
var _arms: Array = []
var _angle: float = 0.0
var _spin: float = 0.0
var _roll: float = 0.0
var _roll_spin: float = 0.0
var _gloves: Array = []
var _book: Node3D
var _ice: Node3D
var _kit: Node3D
var _ice_home: Transform3D
var _moon: DirectionalLight3D

func build_steps() -> Array:
	grade = {"vignette": 0.42, "grain": 0.03, "saturation": 0.95, "contrast": 1.06, "lift": Vector3(0.012, 0.008, 0.02)}
	return [_environment, _hall, _walls, _equipment, _lights, _make_dummy, _cast, _cast_props]

func _environment() -> void :
	env = MenuKit.night_environment(Color("847c9a"), 0.4, Color("0e0d18"), 0.04)

func _hall() -> void :
	# Parquet du gymnase, lignes du terrain peintes.
	var wood: Material = MenuKit.paper(Color("9a7650"), {"grid_spacing": 0.18, "grid_width": 0.006, "grid_color": Color(0.25, 0.16, 0.08, 0.35)}, "wood")
	MenuKit.box(self, Vector3(7.0, 0.1, 7.6), Vector3(0.3, -0.05, 0.2), wood)
	var line_w: Material = MenuKit.paper(Color("e8e2d2"))
	var line_r: Material = MenuKit.paper(Color("b8483c"))
	MenuKit.box(self, Vector3(6.6, 0.006, 0.05), Vector3(0.3, 0.003, -1.6), line_w, MenuKit.BG, false)
	MenuKit.box(self, Vector3(0.05, 0.006, 5.0), Vector3(-1.9, 0.003, 0.4), line_w, MenuKit.BG, false)
	var arc: MeshInstance3D = MenuKit.cylinder(self, 1.6, 0.006, Vector3(2.6, 0.002, 0.4), line_r, MenuKit.BG, -1.0, 40)
	arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	MenuKit.cylinder(self, 1.56, 0.008, Vector3(2.6, 0.003, 0.4), wood, MenuKit.BG, -1.0, 40).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	MenuKit.box(self, Vector3(7.0, 0.12, 7.6), Vector3(0.3, 4.6, 0.2), MenuKit.paper(Color("26242e")))

func _walls() -> void :
	var wall: Material = MenuKit.paper(Color("cdc4b2"))
	var low: Material = MenuKit.paper(Color("6d5a4a"), {}, "wood")
	# Mur du fond (côté Elly) : espaliers.
	MenuKit.box(self, Vector3(0.2, 4.6, 7.6), Vector3(-3.2, 2.3, 0.2), wall)
	MenuKit.box(self, Vector3(0.02, 1.2, 7.6), Vector3(-3.09, 0.6, 0.2), low)
	var bar_mat: Material = MenuKit.paper(Color("b48a5a"), {}, "wood")
	for i: int in range(5):
		var z: float = -2.2 + 0.85 * i
		MenuKit.box(self, Vector3(0.06, 2.6, 0.08), Vector3(-3.04, 1.3, z - 0.38), bar_mat)
		MenuKit.box(self, Vector3(0.06, 2.6, 0.08), Vector3(-3.04, 1.3, z + 0.38), bar_mat)
		for r: int in range(9):
			MenuKit.cylinder(self, 0.018, 0.76, Vector3(-3.0, 0.25 + 0.27 * r, z), bar_mat, MenuKit.BG, -1.0, 6).rotation.x = PI / 2
	# Mur des fenêtres hautes (la lune entre par là).
	MenuKit.box(self, Vector3(7.0, 2.5, 0.2), Vector3(0.3, 1.25, 3.9), wall)
	MenuKit.box(self, Vector3(7.0, 0.7, 0.2), Vector3(0.3, 4.25, 3.9), wall)
	for x: float in [-2.2, -0.7, 0.8, 2.3]:
		MenuKit.box(self, Vector3(0.18, 1.4, 0.2), Vector3(x + 0.71, 3.2, 3.9), wall)
		MenuKit.box(self, Vector3(1.2, 1.36, 0.04), Vector3(x, 3.2, 3.98), MenuKit.glow(Color("22305a"), 1.0))
		MenuKit.box(self, Vector3(0.04, 1.36, 0.06), Vector3(x, 3.2, 3.96), MenuKit.paper(Color("2d3040")))
	MenuKit.box(self, Vector3(7.0, 0.02, 0.02), Vector3(0.3, 1.2, 3.79), low)
	# Mur côté caméra : portes battantes, gradins repliés.
	MenuKit.box(self, Vector3(7.0, 4.6, 0.2), Vector3(0.3, 2.3, -3.5), wall)
	MenuKit.box(self, Vector3(7.0, 1.2, 0.02), Vector3(0.3, 0.6, -3.39), low)
	for i: int in range(5):
		MenuKit.box(self, Vector3(3.0, 0.3, 0.12 + 0.1 * i), Vector3(-1.2, 0.3 + 0.35 * i, -3.34 + 0.05 * i), MenuKit.paper(Color("8a6a4c"), {}, "wood"))
	for x: float in [1.7, 2.6]:
		MenuKit.box(self, Vector3(0.86, 2.2, 0.06), Vector3(x, 1.1, -3.37), MenuKit.paper(Color("5a6c82")))
		MenuKit.box(self, Vector3(0.3, 0.4, 0.02), Vector3(x, 1.55, -3.33), MenuKit.glow(Color("151a2c"), 1.0))
	# Mur de droite : panier de basket.
	MenuKit.box(self, Vector3(0.2, 4.6, 7.6), Vector3(3.8, 2.3, 0.2), wall)
	MenuKit.box(self, Vector3(0.02, 1.2, 7.6), Vector3(3.69, 0.6, 0.2), low)
	MenuKit.box(self, Vector3(0.5, 0.06, 0.06), Vector3(3.45, 2.9, 0.4), MenuKit.paper(Color("2d3040")))
	MenuKit.box(self, Vector3(0.04, 1.05, 1.8), Vector3(3.2, 3.2, 0.4), MenuKit.paper(Color("e9e4d8")))
	MenuKit.box(self, Vector3(0.045, 0.45, 0.6), Vector3(3.19, 3.05, 0.4), MenuKit.paper(Color("c0503e")))
	var ring: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.2
	torus.outer_radius = 0.225
	torus.rings = 16
	torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = MenuKit.paper(Color("d4572e"))
	ring.position = Vector3(2.92, 2.88, 0.4)
	add_child(ring)

func _equipment() -> void :
	# Plinth d'Elly (caissons de bois, dessus en cuir), trousse de secours posée à côté d'elle.
	var plinth: Node3D = MenuKit.pivot(self, MenuTraining.ELLY_AT, deg_to_rad(MenuTraining.ELLY_YAW))
	var leather: Material = MenuKit.paper(Color("5b3a2c"))
	var crate: Material = MenuKit.paper(Color("b08a5e"), {}, "wood")
	var top: float = MenuTraining.BOX_TOP
	for i: int in range(4):
		var w: float = 1.25 + 0.06 * i
		var d: float = 0.5 + 0.04 * i
		MenuKit.box(plinth, Vector3(w, top / 4.0 - 0.012, d), Vector3(0, top - top / 8.0 - top / 4.0 * i - 0.06, 0.16), crate)
	MenuKit.box(plinth, Vector3(1.22, 0.07, 0.5), Vector3(0, top - 0.035, 0.16), leather)
	_kit = MenuKit.pivot(plinth, Vector3(0.42, top, 0.14), 0.25)
	MenuKit.box(_kit, Vector3(0.26, 0.12, 0.18), Vector3(0, 0.06, 0), MenuKit.paper(Color("eeeae2")))
	MenuKit.box(_kit, Vector3(0.1, 0.03, 0.002), Vector3(0, 0.07, -0.091), MenuKit.paper(Color("cc3a34")), MenuKit.BG, false)
	MenuKit.box(_kit, Vector3(0.03, 0.1, 0.002), Vector3(0, 0.07, -0.091), MenuKit.paper(Color("cc3a34")), MenuKit.BG, false)
	# Pile de tapis bleus, ballon oublié, plots.
	for i: int in range(4):
		var mat_box: MeshInstance3D = MenuKit.box(self, Vector3(1.9, 0.14, 1.0), Vector3(-2.15, 0.07 + 0.145 * i, -0.9), MenuKit.paper(Color("3e5f9a") if i % 2 == 0 else Color("36548a")))
		mat_box.rotation.y = 0.04 * float(i % 3) - 0.03
	MenuKit.sphere(self, 0.12, Vector3(-1.3, 0.12, -0.2), MenuKit.paper(Color("c8622e")))
	for p: Vector3 in [Vector3(2.2, 0, 2.6), Vector3(2.6, 0, 2.2), Vector3(-0.4, 0, -2.4)]:
		MenuKit.cylinder(self, 0.1, 0.24, p + Vector3(0, 0.12, 0), MenuKit.paper(Color("e2742e")), MenuKit.BG, 0.02, 10)

func _lights() -> void :
	_moon = DirectionalLight3D.new()
	_moon.light_color = Color("a3b6ff")
	_moon.light_energy = 1.1
	_moon.shadow_enabled = true
	_moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_moon.directional_shadow_max_distance = 16.0
	add_child(_moon)
	_moon.look_at_from_position(Vector3.ZERO, Vector3(0.25, -0.62, -1.0), Vector3.UP)
	# Suspension industrielle au-dessus du tapis d'entraînement.
	var hang: Vector3 = Vector3(0.75, 3.3, 1.05)
	MenuKit.box(self, Vector3(0.02, 1.3, 0.02), hang + Vector3(0, 0.65, 0), MenuKit.paper(Color("2a2b33")), MenuKit.BG, false)
	MenuKit.cylinder(self, 0.32, 0.22, hang, MenuKit.paper(Color("3d4a3c")), MenuKit.BG, 0.08, 20)
	_bulb = MenuKit.live_glow(Color("ffd9a6") * 2.2)
	MenuKit.sphere(self, 0.07, hang - Vector3(0, 0.1, 0), _bulb)
	_lamp = MenuKit.spot(self, hang - Vector3(0, 0.12, 0), Vector3(0.5, 0.0, 1.2), Color("ffd2a0"), 7.5, 6.0, 46.0, true)
	_lamp.spot_angle_attenuation = 1.4
	# Débouchés froids : la salle n'est pas noire, juste éteinte.
	MenuKit.omni(self, Vector3(1.9, 1.6, -0.8), Color("9aa4d8"), 0.55, 3.6)
	MenuKit.omni(self, Vector3(-1.0, 1.7, 1.2), Color("c7b8e0"), 0.45, 2.6)

# Le mannequin : une Alice en carton découpé (robe, bras, tête ronde dessinée), sur un mât et un ressort.
func _make_dummy() -> void :
	_dummy = MenuKit.pivot(self, MenuTraining.DUMMY_AT, deg_to_rad(90.0))
	MenuKit.cylinder(_dummy, 0.27, 0.1, Vector3(0, 0.05, 0), MenuKit.paper(Color("2e2e36")), MenuKit.BG, 0.24, 24)
	var coil: Material = MenuKit.paper(Color("a8adb8"))
	for i: int in range(6):
		var turn: MeshInstance3D = MeshInstance3D.new()
		var torus: TorusMesh = TorusMesh.new()
		torus.inner_radius = 0.035
		torus.outer_radius = 0.05
		torus.rings = 10
		torus.ring_segments = 5
		turn.mesh = torus
		turn.material_override = coil
		turn.position = Vector3(0, 0.12 + 0.04 * i, 0)
		_dummy.add_child(turn)
	_tilt = MenuKit.pivot(_dummy, Vector3(0, 0.36, 0))
	var card: Material = MenuKit.paper(Color("b89466"), {}, "wood")
	var dress: Material = MenuKit.paper(Color("2c2330"))
	var trim: Material = MenuKit.paper(Color("8c2f3a"))
	var skin: Material = MenuKit.paper(Color("ece4da"))
	var hair: Material = MenuKit.paper(Color("7a3438"))
	var ink: Material = MenuKit.paper(Color("171419"))
	MenuKit.box(_tilt, Vector3(0.05, 1.0, 0.04), Vector3(0, 0.5, 0.03), card)
	# Robe en trapèze, en trois bandes, liseré rouge et losange.
	MenuKit.box(_tilt, Vector3(0.62, 0.26, 0.018), Vector3(0, 0.22, 0), dress)
	MenuKit.box(_tilt, Vector3(0.5, 0.26, 0.018), Vector3(0, 0.46, 0), dress)
	MenuKit.box(_tilt, Vector3(0.36, 0.28, 0.018), Vector3(0, 0.72, 0), dress)
	MenuKit.box(_tilt, Vector3(0.64, 0.03, 0.022), Vector3(0, 0.1, -0.002), trim)
	var diamond: MeshInstance3D = MenuKit.box(_tilt, Vector3(0.12, 0.12, 0.022), Vector3(0, 0.4, -0.003), trim)
	diamond.rotation.z = PI / 4
	MenuKit.box(_tilt, Vector3(0.1, 0.08, 0.018), Vector3(0, 0.9, 0), skin)
	for side: int in [-1, 1]:
		var shoulder: Node3D = MenuKit.pivot(_tilt, Vector3(0.18 * side, 0.82, -0.004))
		var arm: MeshInstance3D = MenuKit.box(shoulder, Vector3(0.07, 0.42, 0.016), Vector3(0.03 * side, -0.2, 0), dress)
		arm.rotation.z = 0.12 * side
		MenuKit.box(shoulder, Vector3(0.07, 0.07, 0.017), Vector3(0.055 * side, -0.43, 0), skin)
		_arms.append(shoulder)
	_head = MenuKit.pivot(_tilt, Vector3(0, 0.95, 0))
	var back: MeshInstance3D = MenuKit.cylinder(_head, 0.21, 0.016, Vector3(0, 0.2, 0.004), hair, MenuKit.BG, -1.0, 24)
	back.rotation.x = PI / 2
	var face: MeshInstance3D = MenuKit.cylinder(_head, 0.155, 0.02, Vector3(0, 0.17, -0.004), skin, MenuKit.BG, -1.0, 24)
	face.rotation.x = PI / 2
	MenuKit.box(_head, Vector3(0.34, 0.09, 0.022), Vector3(0, 0.33, -0.008), hair)
	for side: int in [-1, 1]:
		var eye: MeshInstance3D = MenuKit.cylinder(_head, 0.026, 0.01, Vector3(0.06 * side, 0.2, -0.016), ink, MenuKit.BG, -1.0, 12)
		eye.rotation.x = PI / 2
		MenuKit.box(_head, Vector3(0.06, 0.014, 0.012), Vector3(0.05 * side, 0.11, -0.016), trim, MenuKit.BG, false).rotation.z = 0.35 * side
	MenuKit.box(_head, Vector3(0.05, 0.014, 0.012), Vector3(0, 0.095, -0.016), trim, MenuKit.BG, false)
	MenuKit.box(_head, Vector3(0.06, 0.035, 0.02), Vector3(-0.17, 0.3, -0.01), MenuKit.paper(Color("d8c27a"))).rotation.z = 0.4

func _cast() -> void :
	actor("usa", "Usayuko", MenuTraining.USA_AT, -90.0)
	var elly: PaperVisual = actor("elly", "Elly", MenuTraining.ELLY_AT, MenuTraining.ELLY_YAW)
	elly.blob_shadow = false

func _cast_props() -> void :
	# Gants de boxe rouges.
	for side: String in ["left", "right"]:
		var glove: Node3D = Node3D.new()
		var ball: MeshInstance3D = MenuKit.sphere(glove, 0.1, Vector3.ZERO, MenuKit.flat(Color("c4312c")), 1)
		ball.scale = Vector3(0.95, 1.1, 0.95)
		MenuKit.cylinder(glove, 0.07, 0.08, Vector3(0, 0.1, 0), MenuKit.flat(Color("efe9df")), 1, -1.0, 12)
		attach("usa", glove, side)
		glove.position = Vector3(0.0, -0.06, -0.01)
		_gloves.append(glove)
	# Le livre d'Elly (main gauche), ouvert.
	_book = Node3D.new()
	for side: int in [-1, 1]:
		var page: MeshInstance3D = MenuKit.box(_book, Vector3(0.13, 0.012, 0.19), Vector3(0.065 * side, 0.0, 0.0), MenuKit.flat(Color("f1ece0")), 1)
		page.rotation.z = -0.22 * side
		MenuKit.box(_book, Vector3(0.135, 0.008, 0.195), Vector3(0.067 * side, -0.012, 0.0), MenuKit.flat(Color("4a6b8c")), 1).rotation.z = -0.22 * side
	attach("elly", _book, "left")
	_book.position = Vector3(0.08, -0.08, -0.06)
	_book.rotation = Vector3(-0.2, 0.0, -1.2)
	# Poche de glace bleue, rangée dans la trousse.
	_ice = Node3D.new()
	MenuKit.box(_ice, Vector3(0.11, 0.035, 0.08), Vector3.ZERO, MenuKit.flat(Color("6fb7e6")), 1)
	_kit.add_child(_ice)
	_ice.position = Vector3(0.0, 0.1, 0.0)
	_ice_home = _ice.transform
	_write_beats()

func _write_beats() -> void :
	var len_: float = MenuTraining.JAB_LEN
	var smack: float = MenuTraining.SMACK
	var mid: Vector3 = Vector3(0.75, 1.15, 1.0)
	beats = [
		{"id": "jab", "len": len_, "fade_in": 0.7, "fade_out": 1.3,
			"clips": {"usa": "menu_training_jab", "elly": "menu_training_jab"},
			"reach": [
				# La main droite d'Elly tient l'autre côté du livre ; puis fouille la trousse.
				["elly", 1, 0.0, 2.05, _book, {"in": 0.0, "out": 0.15, "offset": Vector3(-0.1, 0.02, 0.02)}],
				["elly", 1, 2.85, 4.25, _book, {"in": 0.2, "out": 0.15, "offset": Vector3(-0.1, 0.02, 0.02)}],
				["elly", 1, 5.7, 12.7, _book, {"in": 0.25, "out": 0.2, "offset": Vector3(-0.1, 0.02, 0.02)}],
				["elly", 1, 12.95, 13.45, _kit, {"in": 0.2, "out": 0.15, "offset": Vector3(0.0, 0.12, 0.0)}],
				["elly", 1, 15.8, 16.1, _kit, {"in": 0.15, "out": 0.15, "offset": Vector3(0.0, 0.12, 0.0)}],
				["elly", 1, 16.3, 21.1, _book, {"in": 0.25, "out": 0.2, "offset": Vector3(-0.1, 0.02, 0.02)}],
				["elly", 1, 23.6, 27.5, _book, {"in": 0.3, "out": 0.15, "offset": Vector3(-0.1, 0.02, 0.02)}],
				# Le gant sur le nez.
				["usa", 1, 11.35, 15.3, "usa:mouth", {"in": 0.15, "out": 0.3, "offset": Vector3(0.0, 0.03, -0.1)}],
			],
			"cam": [
				# Large, de trois quarts, côté mannequin (on le voit de dos) : Usayuko sautille, Elly lit au fond.
				[0.0, Vector3(2.75, 1.5, -0.75), Vector3(0.35, 1.05, 1.45), 40.0, {"focus": "usa:head", "frad": 0.32, "x": 0.56}],
				[5.4, Vector3(2.55, 1.45, -0.45), Vector3(0.3, 1.05, 1.5), 38.0, {"focus": "usa:head", "frad": 0.32, "x": 0.56}],
				# Contrechamp derrière Usayuko : le mannequin est une Alice en carton.
				[5.4, Vector3(-0.15, 1.6, 0.55), ["usa:head", Vector3(1.0, -0.35, 0.18)], 38.0, {"cut": true, "focus": MenuTraining.DUMMY_AT + Vector3(0, 1.4, 0), "frad": 0.26, "x": 0.55}],
				[8.3, Vector3(-0.08, 1.58, 0.62), ["usa:head", Vector3(1.0, -0.35, 0.18)], 37.0, {"focus": MenuTraining.DUMMY_AT + Vector3(0, 1.4, 0), "frad": 0.26, "x": 0.55}],
				# Face à lui : il arme.
				[8.3, Vector3(1.85, 1.4, 0.15), ["usa:head", Vector3(0.0, -0.25, 0.0)], 34.0, {"cut": true, "focus": "usa:head", "frad": 0.26, "x": 0.56}],
				[9.95, Vector3(1.78, 1.38, 0.3), ["usa:head", Vector3(0.0, -0.25, 0.0)], 32.0, {"focus": "usa:head", "frad": 0.26, "x": 0.56}],
				# Large, de côté : le carton part en arrière… et revient.
				[9.95, Vector3(0.7, 1.3, 3.45), mid, 42.0, {"cut": true, "focus": mid, "frad": 0.34, "x": 0.56, "shake": 0.3}],
				[12.2, Vector3(0.62, 1.28, 3.3), mid + Vector3(-0.2, 0.0, 0.0), 41.0, {"focus": "usa:head", "frad": 0.34, "x": 0.56, "shake": 0.5}],
				# Elly : un soupir, la poche de glace.
				[12.2, Vector3(-0.55, 1.32, 1.05), ["elly:head", Vector3(0.0, -0.3, 0.0)], 36.0, {"cut": true, "focus": "elly:head", "frad": 0.28, "x": 0.55}],
				[15.7, Vector3(-0.42, 1.3, 1.15), ["elly:head", Vector3(0.12, -0.35, -0.1)], 38.0, {"focus": "elly:head", "frad": 0.3, "x": 0.55}],
				# Par-dessus l'épaule d'Elly : il raconte ; derrière lui, la tête du carton se penche.
				[15.7, Vector3(-0.95, 1.55, 1.8), Vector3(0.62, 1.18, 0.98), 36.0, {"cut": true, "focus": "usa:head", "frad": 0.3, "x": 0.55}],
				[18.5, Vector3(-0.9, 1.55, 1.76), Vector3(0.66, 1.2, 0.98), 34.0, {"focus": "usa:head", "frad": 0.3, "x": 0.55}],
				[21.1, Vector3(-0.85, 1.54, 1.72), Vector3(0.75, 1.3, 1.0), 31.0, {"focus": MenuTraining.DUMMY_AT + Vector3(0, 1.35, 0), "frad": 0.24, "x": 0.55}],
				# Elly montre le carton du doigt.
				[21.1, Vector3(-0.5, 1.3, 1.25), ["elly:head", Vector3(0.0, -0.2, 0.0)], 34.0, {"cut": true, "focus": "elly:head", "frad": 0.26, "x": 0.55}],
				[22.6, Vector3(-0.45, 1.3, 1.3), ["elly:head", Vector3(0.0, -0.2, 0.0)], 33.0, {"focus": "elly:head", "frad": 0.26, "x": 0.55}],
				# Il se retourne : le carton est droit. « Quoi ? »
				[22.6, Vector3(-0.95, 1.55, 1.8), Vector3(0.62, 1.22, 0.98), 34.0, {"cut": true, "focus": "usa:head", "frad": 0.3, "x": 0.55}],
				[25.1, Vector3(-1.05, 1.52, 1.7), Vector3(0.62, 1.15, 1.0), 38.0, {"focus": "usa:head", "frad": 0.3, "x": 0.55}],
				# De côté : deux directs ; le carton ne bouge plus.
				[25.1, Vector3(0.75, 1.3, 3.4), mid, 40.0, {"cut": true, "focus": mid, "frad": 0.34, "x": 0.56}],
				[26.95, Vector3(0.72, 1.29, 3.3), mid, 39.0, {"focus": mid, "frad": 0.34, "x": 0.56}],
				# Le néon revient : derrière Usayuko, le carton est tout près de lui, la tête penchée.
				[27.5, Vector3(-0.2, 1.62, 0.5), ["usa:head", Vector3(0.75, -0.3, 0.16)], 36.0, {"cut": true, "focus": MenuTraining.DUMMY_AT + Vector3(-0.3, 1.4, 0.0), "frad": 0.24, "x": 0.55, "shake": 0.3}],
				[29.0, Vector3(-0.3, 1.6, 0.55), ["usa:head", Vector3(0.75, -0.3, 0.16)], 34.0, {"focus": MenuTraining.DUMMY_AT + Vector3(-0.3, 1.4, 0.0), "frad": 0.24, "x": 0.55, "shake": 0.3}],
				# Elly serre son livre.
				[29.0, Vector3(-0.55, 1.3, 1.2), ["elly:head", Vector3(0.0, -0.22, 0.0)], 34.0, {"cut": true, "focus": "elly:head", "frad": 0.26, "x": 0.55, "shake": 0.3}],
				[len_, Vector3(-0.6, 1.28, 1.28), ["elly:head", Vector3(0.0, -0.22, 0.0)], 32.0, {"focus": "elly:head", "frad": 0.26, "x": 0.55, "shake": 0.3}],
			],
			"events": [ev(MenuTraining.JABS[0], _hit.bind(1.6)), ev(MenuTraining.JABS[1], _hit.bind(2.0)), ev(MenuTraining.HAYMAKER, _big_hit),
				ev(13.55, _take_ice), ev(15.95, _store_ice), ev(MenuTraining.FLICKER_OFF, _flick.bind(0.0)), ev(MenuTraining.FLICKER_ON, _creep),
				ev(30.55, _flick.bind(0.0))]},
	]

# --- Mannequin -------------------------------------------------------------------------------

var _scripted: Array = []
var _scripted_from: float = -1.0
var _frozen: bool = false
var _lamp_level: float = 1.0
var _flicker: Array = []

func _hit(power: float) -> void :
	if _frozen: return
	_spin += power
	_roll_spin += power * 0.35 * (1.0 if randf() > 0.5 else -1.0)

# Le gros coup : courbe écrite à la main (part très loin, revient frapper, rebondit, s'amortit).
func _big_hit() -> void :
	_scripted_from = beat_time
	var s: float = MenuTraining.SMACK - MenuTraining.HAYMAKER
	_scripted = [[0.0, 0.0], [0.1, 0.75], [0.2, 1.12], [0.3, 1.2], [0.4, 0.95], [s - 0.16, 0.25], [s - 0.06, -0.12], [s, -0.3], [s + 0.07, -0.2],
		[s + 0.22, 0.1], [s + 0.42, 0.16], [s + 0.65, -0.07], [s + 0.9, 0.05], [s + 1.2, -0.02], [s + 1.5, 0.0]]

func _sample(keys: Array, t: float) -> float:
	if t <= float(keys[0][0]): return float(keys[0][1])
	for i: int in range(keys.size() - 1):
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if t < float(b[0]):
			var u: float = (t - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001)
			var m0: float = 0.0
			var m1: float = 0.0
			if i > 0: m0 = (float(b[1]) - float(keys[i - 1][1])) / maxf(float(b[0]) - float(keys[i - 1][0]), 0.001)
			if i + 2 < keys.size(): m1 = (float(keys[i + 2][1]) - float(a[1])) / maxf(float(keys[i + 2][0]) - float(a[0]), 0.001)
			var span: float = float(b[0]) - float(a[0])
			var u2: float = u * u
			var u3: float = u2 * u
			return float(a[1]) * (2.0 * u3 - 3.0 * u2 + 1.0) + m0 * span * (u3 - 2.0 * u2 + u) + float(b[1]) * (-2.0 * u3 + 3.0 * u2) + m1 * span * (u3 - u2)
	return float(keys[keys.size() - 1][1])

func _creep() -> void :
	# La lumière revient : le carton s'est rapproché d'Usayuko, la tête penchée, les bras levés.
	_frozen = true
	_lamp_level = 1.0
	_dummy.position = MenuTraining.DUMMY_AT + Vector3(-0.27, 0.0, 0.05)
	_dummy.rotation.y = deg_to_rad(96.0)
	_head.rotation.z = 0.5
	(_arms[0] as Node3D).rotation.z = -0.55
	(_arms[1] as Node3D).rotation.z = 0.7
	_angle = -0.08
	_spin = 0.0

func _flick(level: float) -> void :
	_lamp_level = level

func _take_ice() -> void :
	attach("elly", _ice, "right")
	_ice.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, -0.08, -0.03))

func _store_ice() -> void :
	if _ice.get_parent() == null: _kit.add_child(_ice)
	elif _ice.get_parent() != _kit: _ice.reparent(_kit, false)
	_ice.transform = _ice_home

func reset_state() -> void :
	_angle = 0.0
	_spin = 0.0
	_roll = 0.0
	_roll_spin = 0.0
	_scripted = []
	_scripted_from = -1.0
	_frozen = false
	_lamp_level = 1.0
	_dummy.position = MenuTraining.DUMMY_AT
	_dummy.rotation.y = deg_to_rad(90.0)
	_head.rotation = Vector3.ZERO
	for arm: Node3D in _arms: arm.rotation = Vector3.ZERO
	if _ice.get_parent() != _kit: _store_ice()

func update(_beat_id: String, t: float, dt: float) -> void :
	# Ressort du mannequin : chaque coup ajoute de la vitesse ; amortissement un peu mou.
	if not _scripted.is_empty() and t - _scripted_from <= float(_scripted[_scripted.size() - 1][0]):
		_angle = _sample(_scripted, t - _scripted_from)
		_spin = 0.0
	elif not _frozen:
		var steps: int = 4
		var h: float = dt / float(steps)
		for i: int in range(steps):
			_spin += (- _angle * 62.0 - _spin * 2.6) * h
			_angle += _spin * h
			_roll_spin += (- _roll * 70.0 - _roll_spin * 3.0) * h
			_roll += _roll_spin * h
	_tilt.rotation = Vector3(_angle, 0.0, _roll * 0.4)
	# La tête du carton se penche toute seule pendant qu'il raconte ; elle se redresse hors champ.
	if not _frozen:
		var lean: float = smoothstep(17.6, 20.8, t) * 0.42 * (1.0 - step_at(MenuTraining.SNAP_BACK, t))
		_head.rotation.z = lean + sin(t * 0.9) * 0.01 * smoothstep(17.6, 18.5, t)
	# Néon : grésillement, coupure, retour.
	var level: float = _lamp_level
	if t > MenuTraining.FLICKER_OFF - 0.45 and t < MenuTraining.FLICKER_OFF:
		level = 0.25 if int(t * 21.0) % 3 == 0 else 1.0
	if t > 30.1 and t < 30.55:
		level = 0.2 if int(t * 19.0) % 3 == 1 else 0.9
	_lamp.light_energy = 7.5 * level
	_bulb.albedo_color = Color("ffd9a6") * lerpf(0.2, 2.2, level)

static func step_at(edge: float, t: float) -> float:
	return 1.0 if t >= edge else 0.0
