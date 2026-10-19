extends "res://menu_scene.gd"

# JOUER : couloir de l'école, la nuit. Un néon au-dessus de Simon qui s'échauffe ; la lune entre
# par les fenêtres et pose des carreaux de lumière au sol ; au fond, la porte de sortie verte.
# Simon se croit seul. Alice ne marche jamais : elle est là quand la lumière revient.

const MenuPlay = preload("res://anim_menu_play.gd")
const ALONE_END: float = MenuPlay.ALONE_LEN

var lamps: Array = []
var _moon: DirectionalLight3D
var _exit_glow: OmniLight3D
var _fill: OmniLight3D
var _flicker: Array = []

func build_steps() -> Array:
	grade = {"vignette": 0.42, "grain": 0.03, "saturation": 0.95, "contrast": 1.05, "lift": Vector3(0.01, 0.008, 0.025)}
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
	# Lueur verte du panneau sur le fond du couloir.
	_exit_glow = MenuKit.omni(self, Vector3(0.0, 2.2, 16.9), Color("39d483"), 0.55, 5.0)

func _lights() -> void :
	_moon = DirectionalLight3D.new()
	_moon.light_color = Color("a9bcff")
	_moon.light_energy = 1.9
	_moon.shadow_enabled = true
	_moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_moon.directional_shadow_max_distance = 24.0
	add_child(_moon)
	_moon.look_at_from_position(Vector3.ZERO, Vector3(-0.72, -0.48, 0.22), Vector3.UP)
	lamps.append(MenuKit.tube_lamp(self, Vector3(0.15, 2.98, 0.6), 1.2, Color("ffe7c9"), 7.0, 6.5, true, false))
	# Débouché de la lune sur les visages (côté fenêtres, devant Simon).
	_fill = MenuKit.omni(self, Vector3(1.0, 1.55, -0.6), Color("9fb2ff"), 0.75, 3.2)
	# Contre-jour froid, côté casiers : détache Simon du fond (et le visage d'Alice sur son épaule).
	MenuKit.omni(self, Vector3(-0.75, 1.75, 0.55), Color("8a9cff"), 0.55, 1.9)
	lamps.append(MenuKit.tube_lamp(self, Vector3(0.15, 2.98, 5.2), 1.2, Color("ffe7c9"), 5.0, 6.0, false, false))
	lamps.append(MenuKit.tube_lamp(self, Vector3(0.15, 2.98, 9.6), 1.2, Color("dfe9ff"), 5.0, 6.0, false, false))
	lamps.append(MenuKit.tube_lamp(self, Vector3(0.15, 2.98, 14.0), 1.2, Color("dfe9ff"), 4.0, 6.0, false, false))

func _props() -> void :
	# Banc contre les casiers, sac de sport.
	var wood: Material = MenuKit.paper(Color("82796f"), {}, "wood")
	MenuKit.box(self, Vector3(0.42, 0.06, 1.7), Vector3(-1.2, 0.45, 1.1), wood)
	for z: float in [0.4, 1.8]:
		MenuKit.box(self, Vector3(0.36, 0.42, 0.06), Vector3(-1.2, 0.21, z), MenuKit.paper(Color("4b5261")))
	var bag: MeshInstance3D = MenuKit.box(self, Vector3(0.32, 0.22, 0.5), Vector3(-1.18, 0.6, 1.55), MenuKit.paper(Color("3d5f8f")))
	bag.rotation.y = 0.18
	MenuKit.box(self, Vector3(0.05, 0.03, 0.42), Vector3(-1.02, 0.72, 1.55), MenuKit.paper(Color("1f2a3d")))

func _cast() -> void :
	actor("simon", "Simon", MenuPlay.SIMON_AT, MenuPlay.SIMON_YAW)
	actor("alice", "Alice", Vector3(0.0, 0.0, 15.0), 0.0)
	var chest: Vector3 = MenuPlay.SIMON_AT + Vector3(0.0, 1.0, 0.0)
	beats = [
		{"id": "alone", "len": MenuPlay.ALONE_LEN, "fade_in": 0.6, "fade_out": 0.75,
			"clips": {"simon": "menu_play_alone", "alice": "menu_play_alone"},
			"vis": {"alice": [[0.0, false], [13.85, true], [15.2, false], [23.4, true], [27.3, false], [31.45, true]]},
			"reach": [
				["simon", 1, 23.3, 27.0, "simon:foot_r", {"in": 0.35, "out": 0.25, "offset": [[23.3, Vector3(0.05, 0.08, -0.06)], [23.9, Vector3(0.03, 0.12, -0.08)], [24.35, Vector3(0.06, 0.07, -0.05)],
					[24.8, Vector3(0.02, 0.11, -0.09)], [25.3, Vector3(0.06, 0.08, -0.06)], [25.85, Vector3(0.03, 0.13, -0.07)], [26.35, Vector3(0.05, 0.08, -0.06)], [26.85, Vector3(0.13, 0.13, -0.05)]]}],
				["simon", -1, 23.35, 27.0, "simon:foot_r", {"in": 0.35, "out": 0.25, "offset": [[23.35, Vector3(-0.05, 0.08, -0.07)], [23.7, Vector3(-0.03, 0.1, -0.09)], [24.2, Vector3(-0.06, 0.07, -0.06)],
					[24.6, Vector3(-0.02, 0.12, -0.08)], [25.1, Vector3(-0.05, 0.08, -0.07)], [25.6, Vector3(-0.03, 0.1, -0.09)], [26.2, Vector3(-0.06, 0.08, -0.06)], [26.85, Vector3(-0.12, 0.12, -0.06)]]}],
				["alice", 1, 32.15, ALONE_END, "simon:chest", {"offset": Vector3(0.13, 0.13, 0.03), "in": 0.3, "out": 0.0}],
			],
			"cam": [
				# Plan large, lente avancée : Simon seul, le couloir qui file derrière lui.
				[0.0, Vector3(1.55, 1.32, -2.7), chest + Vector3(-0.05, 0.05, 0.4), 40.0, {"focus": "simon:head", "frad": 0.26, "x": 0.58}],
				[6.4, Vector3(1.15, 1.28, -1.6), chest + Vector3(-0.05, 0.0, 0.3), 38.0, {"focus": "simon:head", "frad": 0.26, "x": 0.58}],
				# Trois quarts, de l'autre côté : étirement et montées de genoux.
				[6.4, Vector3(-1.25, 1.25, -1.55), chest + Vector3(0.1, 0.08, 0.0), 40.0, {"cut": true, "focus": "simon:chest", "frad": 0.32, "x": 0.6}],
				[12.55, Vector3(-1.08, 1.27, -1.33), chest + Vector3(0.1, 0.1, 0.0), 39.0, {"focus": "simon:chest", "frad": 0.32, "x": 0.6}],
				# Contre-plongée : il fixe le néon qui grésille.
				[12.55, Vector3(0.72, 1.12, -0.42), Vector3(0.14, 1.72, 0.95), 44.0, {"cut": true, "focus": "simon:head", "frad": 0.3, "x": 0.56, "shake": 0.35}],
				[13.85, Vector3(0.68, 1.1, -0.34), Vector3(0.14, 1.76, 0.95), 43.0, {"focus": "simon:head", "frad": 0.3, "x": 0.56, "shake": 0.35}],
				# Le fond du couloir, dans le noir : quelqu'un, sous la lune.
				[13.85, Vector3(0.5, 1.45, 2.2), Vector3(-0.3, 1.2, 14.5), 24.0, {"cut": true, "focus": Vector3(-0.3, 1.3, 14.5), "frad": 0.16, "blur": 3.0, "x": 0.52, "shake": 0.2}],
				[15.2, Vector3(0.48, 1.44, 2.8), Vector3(-0.3, 1.2, 14.5), 22.0, {"focus": Vector3(-0.3, 1.3, 14.5), "frad": 0.16, "blur": 3.0, "x": 0.52, "shake": 0.2}],
				# Retour sur Simon, la lumière est revenue.
				[15.2, Vector3(0.9, 1.4, -1.35), chest + Vector3(0.0, 0.2, 0.0), 36.0, {"cut": true, "focus": "simon:head", "frad": 0.24, "x": 0.58}],
				[22.6, Vector3(1.1, 1.3, -1.7), chest + Vector3(0.0, 0.05, 0.0), 38.0, {"focus": "simon:head", "frad": 0.24, "x": 0.58}],
				# Ras du sol : le lacet net, le couloir flou derrière… Alice, et la mise au point bascule sur elle.
				[23.4, Vector3(1.42, 0.5, -2.25), Vector3(0.0, 0.88, 3.5), 34.0, {"cut": true, "focus": "simon:hand_r", "frad": 0.2, "blur": 3.0, "btop": 0.3, "x": 0.52}],
				[24.6, Vector3(1.38, 0.5, -2.15), Vector3(0.0, 0.88, 3.5), 34.0, {"focus": "simon:hand_r", "frad": 0.2, "blur": 3.0, "btop": 0.3, "x": 0.52}],
				[25.6, Vector3(1.34, 0.5, -2.06), Vector3(0.0, 0.9, 3.5), 33.0, {"focus": "alice:head", "frad": 0.14, "blur": 3.4, "btop": 0.3, "x": 0.52}],
				[26.6, Vector3(1.31, 0.5, -1.98), Vector3(0.0, 0.9, 3.5), 33.0, {"focus": "alice:head", "frad": 0.14, "blur": 3.4, "btop": 0.3, "x": 0.52}],
				[27.25, Vector3(1.29, 0.5, -1.93), Vector3(0.0, 0.92, 3.5), 33.0, {"focus": "simon:head", "frad": 0.2, "blur": 3.0, "btop": 0.3, "x": 0.52}],
				[28.3, Vector3(1.26, 0.52, -1.88), Vector3(0.0, 1.0, 3.5), 34.0, {"focus": "simon:head", "frad": 0.24, "blur": 3.0, "btop": 0.3, "x": 0.52}],
				# Il se relève : plan rapproché, le frisson.
				[28.3, Vector3(0.62, 1.42, -0.42), "simon:head", 38.0, {"cut": true, "focus": "simon:head", "frad": 0.22, "x": 0.58}],
				[30.45, Vector3(0.56, 1.42, -0.32), "simon:head", 36.0, {"focus": "simon:head", "frad": 0.22, "x": 0.58}],
				# Contrechamp par-dessus son épaule : le couloir est vide.
				[30.45, Vector3(0.05, 1.5, 1.35), Vector3(0.3, 1.2, 9.0), 40.0, {"cut": true, "focus": Vector3(0.3, 1.2, 6.0), "frad": 0.3, "blur": 2.4, "x": 0.5, "shake": 0.3}],
				[31.45, Vector3(0.08, 1.5, 1.42), Vector3(0.3, 1.2, 9.0), 39.0, {"focus": Vector3(0.3, 1.2, 6.0), "frad": 0.3, "blur": 2.4, "x": 0.5, "shake": 0.3}],
				# Face à nous, soulagé… et Alice sur son épaule.
				[31.45, Vector3(0.62, 1.34, -0.95), ["simon:head", Vector3(-0.18, -0.06, 0.0)], 36.0, {"cut": true, "focus": "simon:head", "frad": 0.34, "x": 0.58}],
				[32.85, Vector3(0.57, 1.35, -0.8), ["simon:head", Vector3(-0.18, -0.06, 0.0)], 34.0, {"focus": "simon:head", "frad": 0.36, "x": 0.58}],
				[ALONE_END, Vector3(0.55, 1.34, -0.74), ["simon:head", Vector3(-0.18, -0.04, 0.0)], 33.0, {"focus": "simon:head", "frad": 0.36, "x": 0.58, "shake": 1.2}],
			],
			"events": [ev(12.55, _set_flicker.bind([[12.55, 13.75, "buzz"], [13.75, 15.2, "off"]])), ev(27.22, _set_flicker.bind([[27.22, 27.6, "buzz"]]))]},
	]

func _set_flicker(spans: Array) -> void :
	_flicker = spans

func reset_state() -> void :
	_flicker = []
	for i: int in range(lamps.size()): MenuKit.set_lamp(lamps[i], [1.0, 0.0, 0.25, 0.0][i])

func update(_beat_id: String, t: float, _dt: float) -> void :
	# Néon au-dessus de Simon : grésillement ou extinction commandés par le temps fort.
	var level: float = 1.0
	for span: Array in _flicker:
		if t < float(span[0]) or t >= float(span[1]): continue
		if str(span[2]) == "off": level = 0.0
		else:
			var left: float = float(span[1]) - t
			var chop: int = int(t * 23.0 + sin(t * 37.0) * 2.0) % 4
			level = 0.08 if chop == 0 else (0.35 if chop == 2 else (0.75 if left > 0.25 else 0.95))
	MenuKit.set_lamp(lamps[0], level)
	MenuKit.set_lamp(lamps[2], 0.25 + 0.1 * sin(t * 3.1) * sin(t * 7.7))
