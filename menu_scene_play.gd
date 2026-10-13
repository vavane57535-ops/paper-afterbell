extends "res://menu_scene.gd"

# JOUER : couloir de l'école, la nuit. Un néon grésille au-dessus de Simon qui s'échauffe
# près d'un banc ; la lune entre par les fenêtres ; au fond, la porte de sortie verte.
# Simon se croit seul.

var lamps: Array = []
var _moon: DirectionalLight3D

func build_steps() -> Array:
	grade = {"vignette": 0.4, "grain": 0.03, "saturation": 0.95, "contrast": 1.05, "lift": Vector3(0.01, 0.008, 0.025)}
	return [_environment, _shell, _left_wall, _right_wall, _far_end, _lights, _props, _cast]

func _environment() -> void :
	env = MenuKit.night_environment(Color("857f9c"), 0.42, Color("0d0e1a"), 0.045)

func _shell() -> void :
	var floor_mat: Material = MenuKit.paper(Color("797e89"), {"grid_spacing": 0.6, "grid_width": 0.022, "grid_color": Color(0.1, 0.1, 0.13, 0.5)}, "stone")
	MenuKit.box(self, Vector3(3.6, 0.1, 26.0), Vector3(0, -0.05, 5.0), floor_mat)
	MenuKit.box(self, Vector3(3.6, 0.12, 26.0), Vector3(0, 3.06, 5.0), MenuKit.paper(Color("2b2a33")))
	var trim: Material = MenuKit.paper(Color("24212a"))
	MenuKit.box(self, Vector3(0.04, 0.14, 26.0), Vector3(-1.68, 0.07, 5.0), trim)
	MenuKit.box(self, Vector3(0.04, 0.14, 26.0), Vector3(1.63, 0.07, 5.0), trim)

func _left_wall() -> void :
	MenuKit.box(self, Vector3(0.2, 3.0, 26.0), Vector3(-1.8, 1.5, 5.0), MenuKit.paper(Color("d8d0c1")))
	MenuKit.lockers(self, Vector3(-1.7, 0, -5.0), Vector3(-1.7, 0, 2.6), Vector3(1, 0, 0), Color("758eaa"))
	MenuKit.lockers(self, Vector3(-1.7, 0, 5.4), Vector3(-1.7, 0, 12.0), Vector3(1, 0, 0), Color("758eaa"))
	# Panneau de liège entre les deux rangées de casiers.
	MenuKit.box(self, Vector3(0.05, 1.0, 1.6), Vector3(-1.68, 1.55, 4.0), MenuKit.paper(Color("8a5a3c")))
	var colors: Array = [Color("e6e1d2"), Color("c79d4f"), Color("e6e1d2"), Color("b58188"), Color("79968b")]
	for i: int in range(5):
		var sheet: MeshInstance3D = MenuKit.box(self, Vector3(0.02, 0.3, 0.22), Vector3(-1.645, 1.4 + 0.24 * float(i % 2), 3.45 + 0.28 * i), MenuKit.paper(colors[i]))
		sheet.rotation.x = 0.07 * float(i - 2)

func _right_wall() -> void :
	MenuKit.window_wall(self, 1.75, -8.0, 18.0, 3.0, [-2.2, 1.8, 5.8, 9.8, 13.8], Color("d8d0c1"), -1.0)
	# Bande peinte en bas du mur, comme dans les couloirs du jeu.
	MenuKit.box(self, Vector3(0.02, 0.9, 26.0), Vector3(1.64, 0.45, 5.0), MenuKit.paper(Color("56657f")))

func _far_end() -> void :
	MenuKit.box(self, Vector3(3.6, 3.0, 0.2), Vector3(0, 1.5, 18.0), MenuKit.paper(Color("cfc6b5")))
	for x: float in [-0.39, 0.39]:
		MenuKit.box(self, Vector3(0.74, 2.2, 0.08), Vector3(x, 1.1, 17.86), MenuKit.paper(Color("56657f")))
		MenuKit.box(self, Vector3(0.28, 0.55, 0.02), Vector3(x, 1.55, 17.81), MenuKit.glow(Color("26375a"), 1.0))
		MenuKit.box(self, Vector3(0.4, 0.04, 0.06), Vector3(x * 0.6, 1.0, 17.8), MenuKit.paper(Color("9aa0ad")))
	MenuKit.exit_sign(self, Vector3(0, 2.55, 17.86), PI)

func _lights() -> void :
	_moon = DirectionalLight3D.new()
	_moon.light_color = Color("a9bcff")
	_moon.light_energy = 1.9
	_moon.shadow_enabled = true
	_moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_moon.directional_shadow_max_distance = 24.0
	add_child(_moon)
	_moon.look_at_from_position(Vector3.ZERO, Vector3(-0.72, -0.48, 0.22), Vector3.UP)
	lamps.append(MenuKit.tube_lamp(self, Vector3(0.15, 2.98, 0.5), 1.2, Color("ffe7c9"), 7.0, 6.5, true, false))
	lamps.append(MenuKit.tube_lamp(self, Vector3(0.15, 2.98, 5.2), 1.2, Color("ffe7c9"), 5.0, 6.0, false, false))
	lamps.append(MenuKit.tube_lamp(self, Vector3(0.15, 2.98, 9.6), 1.2, Color("dfe9ff"), 5.0, 6.0, false, false))
	lamps.append(MenuKit.tube_lamp(self, Vector3(0.15, 2.98, 14.0), 1.2, Color("dfe9ff"), 4.0, 6.0, false, false))

func _props() -> void :
	# Banc contre les casiers, sac de sport et gourde.
	var wood: Material = MenuKit.paper(Color("82796f"), {}, "wood")
	MenuKit.box(self, Vector3(0.42, 0.06, 1.7), Vector3(-1.2, 0.45, 1.1), wood)
	for z: float in [0.4, 1.8]:
		MenuKit.box(self, Vector3(0.36, 0.42, 0.06), Vector3(-1.2, 0.21, z), MenuKit.paper(Color("4b5261")))

func _cast() -> void :
	actor("simon", "Simon", Vector3(0.0, 0, 0.6), 0.0)
	beats = [
		{"id": "calib", "len": 22.0, "clips": {"simon": "menu_calib@Simon"},
			"cam": [[0.0, Vector3(1.5, 1.45, -3.0), Vector3(-0.2, 1.05, 2.0), 40.0, {"x": 0.5, "shake": 0.3, "focus": "simon:head", "blur": 2.6, "frad": 0.22}],
				[22.0, Vector3(1.1, 1.35, -2.4), Vector3(-0.2, 1.05, 2.0), 40.0, {"x": 0.5, "shake": 0.3, "focus": "simon:head", "blur": 2.6, "frad": 0.22}]]},
	]

func reset_state() -> void :
	for i: int in range(lamps.size()): MenuKit.set_lamp(lamps[i], [1.0, 0.0, 0.25, 0.0][i])

func update(_beat_id: String, t: float, _dt: float) -> void :
	var buzz: float = 1.0
	var phase: float = fmod(t, 7.3)
	if phase > 6.6: buzz = 0.55 + 0.45 * float(int(t * 23.0) % 2)
	MenuKit.set_lamp(lamps[0], buzz)
	MenuKit.set_lamp(lamps[2], 0.25 + 0.1 * sin(t * 3.1) * sin(t * 7.7))
