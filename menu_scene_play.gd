extends "res://menu_scene.gd"

# JOUER : couloir de l'école, la nuit. Un néon grésille au-dessus de Simon qui s'échauffe
# près d'un banc ; la lune entre par les fenêtres ; au fond, la porte de sortie verte.
# Simon se croit seul.

var lamps: Array = []
var _moon: DirectionalLight3D
var _flicker: float = 0.0

func build_steps() -> Array:
	grade = {"vignette": 0.42, "grain": 0.03, "saturation": 0.92, "contrast": 1.06, "lift": Vector3(0.012, 0.01, 0.03)}
	return [_environment, _shell, _left_wall, _right_wall, _far_end, _lights, _props, _cast]

func _environment() -> void :
	env_bg = Environment.new()
	env_bg.background_mode = Environment.BG_COLOR
	env_bg.background_color = Color("07080e")
	env_bg.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_bg.ambient_light_color = Color("6f6a8c")
	env_bg.ambient_light_energy = 0.32
	env_bg.fog_enabled = true
	env_bg.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env_bg.fog_light_color = Color("0b0c16")
	env_bg.fog_density = 0.06
	env_bg.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env_bg.tonemap_exposure = 1.05
	env_bg.glow_enabled = true
	env_bg.glow_intensity = 0.7
	env_bg.glow_bloom = 0.0
	env_bg.glow_hdr_threshold = 0.9
	env_bg.adjustment_enabled = true
	env_bg.adjustment_brightness = 0.95
	env_bg.adjustment_contrast = 1.12
	env_bg.adjustment_saturation = 0.85
	env_fg = env_bg.duplicate()
	env_fg.background_mode = Environment.BG_CLEAR_COLOR
	env_fg.glow_enabled = false

func _shell() -> void :
	var floor_mat: Material = MenuKit.paper(Color("454a5e"), {"grid_spacing": 0.6, "grid_width": 0.025, "grid_color": Color(0.08, 0.08, 0.11, 0.6)}, "stone")
	MenuKit.box(self, Vector3(3.6, 0.1, 24.0), Vector3(0, -0.05, 6.0), floor_mat)
	MenuKit.box(self, Vector3(3.6, 0.12, 24.0), Vector3(0, 3.06, 6.0), MenuKit.paper(Color("2a2c38")))
	# Plinthes.
	MenuKit.box(self, Vector3(0.04, 0.14, 24.0), Vector3(-1.68, 0.07, 6.0), MenuKit.paper(Color("23252f")))
	MenuKit.box(self, Vector3(0.04, 0.14, 24.0), Vector3(1.6, 0.07, 6.0), MenuKit.paper(Color("23252f")))

func _left_wall() -> void :
	MenuKit.box(self, Vector3(0.2, 3.0, 24.0), Vector3(-1.8, 1.5, 6.0), MenuKit.paper(Color("5b6075")))
	MenuKit.lockers(self, Vector3(-1.7, 0, -4.0), Vector3(-1.7, 0, 3.0), Vector3(1, 0, 0), Color("4d6a8e"))
	MenuKit.lockers(self, Vector3(-1.7, 0, 5.0), Vector3(-1.7, 0, 11.5), Vector3(1, 0, 0), Color("4d6a8e"))
	# Panneau d'affichage entre les deux rangées.
	MenuKit.box(self, Vector3(0.05, 1.0, 1.4), Vector3(-1.68, 1.55, 4.0), MenuKit.paper(Color("8a5a3c")))
	for i: int in range(4):
		var sheet: MeshInstance3D = MenuKit.box(self, Vector3(0.02, 0.32, 0.24), Vector3(-1.65, 1.42 + 0.22 * float(i % 2), 3.55 + 0.3 * i), MenuKit.paper([Color("e6e1d2"), Color("c79d4f"), Color("e6e1d2"), Color("9a3b4c")][i]))
		sheet.rotation.x = 0.06 * float(i - 2)

func _right_wall() -> void :
	MenuKit.window_wall(self, 1.75, -6.0, 18.0, 3.0, [-1.8, 2.4, 6.6, 10.8], Color("5b6075"), -1.0)

func _far_end() -> void :
	var wall: Material = MenuKit.paper(Color("4a4e62"))
	MenuKit.box(self, Vector3(3.6, 3.0, 0.2), Vector3(0, 1.5, 17.0), wall)
	MenuKit.box(self, Vector3(0.7, 2.2, 0.08), Vector3(-0.38, 1.1, 16.86), MenuKit.paper(Color("3c4152")))
	MenuKit.box(self, Vector3(0.7, 2.2, 0.08), Vector3(0.38, 1.1, 16.86), MenuKit.paper(Color("3c4152")))
	MenuKit.box(self, Vector3(0.3, 0.5, 0.02), Vector3(-0.38, 1.55, 16.81), MenuKit.glow(Color("1d2a44"), 1.0))
	MenuKit.box(self, Vector3(0.3, 0.5, 0.02), Vector3(0.38, 1.55, 16.81), MenuKit.glow(Color("1d2a44"), 1.0))
	MenuKit.exit_sign(self, Vector3(0, 2.5, 16.85), PI)

func _lights() -> void :
	_moon = DirectionalLight3D.new()
	_moon.light_color = Color("9fb4ff")
	_moon.light_energy = 1.25
	_moon.shadow_enabled = true
	_moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_moon.directional_shadow_max_distance = 22.0
	add_child(_moon)
	_moon.look_at_from_position(Vector3.ZERO, Vector3(-0.7, -0.5, 0.25), Vector3.UP)
	lamps.append(MenuKit.tube_lamp(self, Vector3(0.1, 2.98, 0.35), 1.2, Color("e9f3ff"), 3.4, 6.0, true, false))
	lamps.append(MenuKit.tube_lamp(self, Vector3(0.1, 2.98, 4.8), 1.2, Color("e9f3ff"), 2.6, 6.0, false, false))
	lamps.append(MenuKit.tube_lamp(self, Vector3(0.1, 2.98, 9.3), 1.2, Color("e9f3ff"), 2.2, 6.0, false, false))
	lamps.append(MenuKit.tube_lamp(self, Vector3(0.1, 2.98, 13.6), 1.2, Color("e9f3ff"), 2.0, 6.0, false, false))

func _props() -> void :
	# Banc contre les casiers, sac de sport et gourde.
	var wood: Material = MenuKit.paper(Color("8a6a4c"), {}, "wood")
	MenuKit.box(self, Vector3(0.4, 0.06, 1.6), Vector3(-1.22, 0.45, 0.9), wood)
	for z: float in [0.25, 1.55]:
		MenuKit.box(self, Vector3(0.34, 0.42, 0.06), Vector3(-1.22, 0.21, z), MenuKit.paper(Color("3a3d4c")))

func _cast() -> void :
	actor("simon", "Simon", Vector3(0.0, 0, 0.6), 0.0)
	beats = [
		{"id": "calib", "len": 22.0, "clips": {"simon": "menu_calib@Simon"},
			"cam": [[0.0, Vector3(0.0, 1.2, -2.6), Vector3(0.0, 1.0, 0.6), 38.0, {"x": 0.5, "shake": 0.0, "bg": 0.8}]]},
	]

func reset_state() -> void :
	for i: int in range(lamps.size()): MenuKit.set_lamp(lamps[i], [1.0, 0.0, 0.25, 0.0][i])

func update(_beat_id: String, t: float, _dt: float) -> void :
	# Le néon au-dessus de Simon grésille de temps en temps.
	var buzz: float = 1.0
	var phase: float = fmod(t, 7.3)
	if phase > 6.6: buzz = 0.55 + 0.45 * float(int(t * 23.0) % 2)
	MenuKit.set_lamp(lamps[0], buzz)
	MenuKit.set_lamp(lamps[2], 0.18 + 0.08 * sin(t * 3.1) * sin(t * 7.7))
