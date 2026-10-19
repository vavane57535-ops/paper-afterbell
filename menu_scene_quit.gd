extends "res://menu_scene.gd"

# QUITTER : le hall d'entrée, la nuit. Bleuette veut rentrer chez elle : la double porte vitrée
# est fermée. Elle pousse, tire, colle son visage à la vitre. Un néon claque au fond du hall ;
# elle se retourne. Alice est là-bas, sous la dernière lampe, et lui fait au revoir de la main.
# Chaque néon qui s'éteint la rapproche.

const MenuQuit = preload("res://anim_menu_quit.gd")

var lamps: Array = []
var _doors: Array = []
var _door_kick: Array = [0.0, 0.0]
var _door_vel: Array = [0.0, 0.0]
var _minute: Node3D
var _hour: Node3D
var _minute_goal: float = 0.0
var _flicker: Array = []
var _lamp_on: Array = [1.0, 1.0, 1.0, 1.0]
var _moon: DirectionalLight3D
var _exit_glow: OmniLight3D
var _far_fill: OmniLight3D

func build_steps() -> Array:
	grade = {"vignette": 0.45, "grain": 0.032, "saturation": 0.9, "contrast": 1.07, "lift": Vector3(0.006, 0.008, 0.022)}
	return [_environment, _shell, _doors_wall, _outside, _side_walls, _lights, _cast]

func _environment() -> void :
	env = MenuKit.night_environment(Color("7c7a98"), 0.36, Color("0b0c18"), 0.05)

func _shell() -> void :
	var floor_mat: Material = MenuKit.paper(Color("8a8790"), {"grid_spacing": 0.5, "grid_width": 0.018, "grid_color": Color(0.12, 0.11, 0.14, 0.5)}, "stone")
	MenuKit.box(self, Vector3(4.8, 0.1, 14.0), Vector3(0, -0.05, -0.7), floor_mat)
	MenuKit.box(self, Vector3(4.8, 0.12, 14.0), Vector3(0, 3.46, -0.7), MenuKit.paper(Color("2a2832")))
	# Fond du hall, côté caméra : un mur, la porte du préau et l'escalier qui monte dans le noir.
	MenuKit.box(self, Vector3(4.8, 3.4, 0.2), Vector3(0, 1.7, -7.6), MenuKit.paper(Color("bfb6a6")))
	MenuKit.box(self, Vector3(4.8, 1.0, 0.02), Vector3(0, 0.5, -7.49), MenuKit.paper(Color("5a4f62")))
	var frame_mat: Material = MenuKit.paper(Color("3b4150"))
	MenuKit.box(self, Vector3(1.6, 2.3, 0.08), Vector3(-0.5, 1.15, -7.47), MenuKit.paper(Color("6b5a48"), {}, "wood"))
	MenuKit.box(self, Vector3(0.06, 2.3, 0.1), Vector3(-0.5, 1.15, -7.44), frame_mat)
	for x: float in [-0.88, -0.12]: MenuKit.box(self, Vector3(0.36, 0.6, 0.02), Vector3(x, 1.6, -7.42), MenuKit.glow(Color("141a2e"), 1.0))
	var step_mat: Material = MenuKit.paper(Color("9d978c"), {}, "stone")
	for i: int in range(9):
		MenuKit.box(self, Vector3(1.0, 0.17 * float(i + 1), 0.3), Vector3(1.75, 0.085 * float(i + 1), -4.6 - 0.3 * i), step_mat)
	MenuKit.box(self, Vector3(0.05, 0.05, 2.78), Vector3(1.25, 1.7, -5.8), frame_mat).rotation.x = 0.528

func _doors_wall() -> void :
	var wall: Material = MenuKit.paper(Color("cfc6b5"))
	var metal: Material = MenuKit.paper(Color("3b4150"))
	var z: float = MenuQuit.DOOR_Z
	MenuKit.box(self, Vector3(1.4, 3.4, 0.2), Vector3(-1.75, 1.7, z + 0.1), wall)
	MenuKit.box(self, Vector3(1.4, 3.4, 0.2), Vector3(1.75, 1.7, z + 0.1), wall)
	MenuKit.box(self, Vector3(2.1, 0.9, 0.2), Vector3(0, 2.95, z + 0.1), wall)
	# Chambranle.
	MenuKit.box(self, Vector3(0.08, 2.5, 0.26), Vector3(-1.04, 1.25, z + 0.1), metal)
	MenuKit.box(self, Vector3(0.08, 2.5, 0.26), Vector3(1.04, 1.25, z + 0.1), metal)
	MenuKit.box(self, Vector3(2.16, 0.1, 0.26), Vector3(0, 2.5, z + 0.1), metal)
	# Vitre teintée : on voit la cour sous la lune à travers.
	var glass: StandardMaterial3D = StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.albedo_color = Color(0.42, 0.52, 0.78, 0.16)
	var bar_mat: Material = MenuKit.paper(Color("b9bec8"))
	# Deux battants vitrés (charnière côté mur), barre anti-panique côté hall.
	for side: int in [-1, 1]:
		var hinge: Node3D = MenuKit.pivot(self, Vector3(side * 1.0, 0.0, z + 0.06))
		var leaf: Node3D = MenuKit.pivot(hinge, Vector3(- side * 0.5, 0.0, 0.0))
		MenuKit.box(leaf, Vector3(0.98, 0.12, 0.06), Vector3(0, 0.06, 0), metal)
		MenuKit.box(leaf, Vector3(0.98, 0.1, 0.06), Vector3(0, 2.4, 0), metal)
		MenuKit.box(leaf, Vector3(0.08, 2.44, 0.06), Vector3(0.45, 1.22, 0), metal)
		MenuKit.box(leaf, Vector3(0.08, 2.44, 0.06), Vector3(-0.45, 1.22, 0), metal)
		var pane: MeshInstance3D = MenuKit.box(leaf, Vector3(0.84, 2.2, 0.015), Vector3(0, 1.24, 0.0), glass, MenuKit.BG, false)
		pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		MenuKit.box(leaf, Vector3(0.8, 0.05, 0.05), Vector3(0, MenuQuit.BAR_Y, -0.09), bar_mat)
		for x: float in [-0.36, 0.36]: MenuKit.box(leaf, Vector3(0.05, 0.08, 0.1), Vector3(x, MenuQuit.BAR_Y, -0.05), metal)
		_doors.append(leaf)
	# Horloge au-dessus de la porte : 16 h passées.
	var clock: Node3D = MenuKit.pivot(self, Vector3(0, 2.98, z - 0.02))
	var face: MeshInstance3D = MenuKit.cylinder(clock, 0.24, 0.05, Vector3.ZERO, MenuKit.paper(Color("eeeae0")), MenuKit.BG, -1.0, 28)
	face.rotation.x = PI / 2
	var rim: MeshInstance3D = MenuKit.cylinder(clock, 0.26, 0.04, Vector3(0, 0, 0.012), MenuKit.paper(Color("2b2d36")), MenuKit.BG, -1.0, 28)
	rim.rotation.x = PI / 2
	var ink: Material = MenuKit.paper(Color("1b1c22"))
	for i: int in range(12):
		var a: float = TAU * float(i) / 12.0
		MenuKit.box(clock, Vector3(0.018, 0.045 if i % 3 == 0 else 0.025, 0.01), Vector3(sin(a) * 0.19, cos(a) * 0.19, -0.03), ink, MenuKit.BG, false).rotation.z = - a
	_hour = MenuKit.pivot(clock, Vector3(0, 0, -0.035))
	MenuKit.box(_hour, Vector3(0.022, 0.12, 0.008), Vector3(0, 0.055, 0), ink, MenuKit.BG, false)
	_minute = MenuKit.pivot(clock, Vector3(0, 0, -0.042))
	MenuKit.box(_minute, Vector3(0.014, 0.18, 0.008), Vector3(0, 0.085, 0), ink, MenuKit.BG, false)
	MenuKit.exit_sign(self, Vector3(0, 2.66, z - 0.02), PI)
	_exit_glow = MenuKit.omni(self, Vector3(0, 2.45, z - 0.35), Color("2fd27a"), 0.22, 1.7)

func _outside() -> void :
	# La cour sous la lune, derrière la vitre : sol, arbres découpés, ciel.
	var z: float = MenuQuit.DOOR_Z
	MenuKit.box(self, Vector3(16.0, 0.1, 18.0), Vector3(0, -0.06, z + 9.2), MenuKit.paper(Color("3c4460"), {}, "stone"))
	MenuKit.box(self, Vector3(24.0, 14.0, 0.2), Vector3(0, 5.0, z + 16.0), MenuKit.glow(Color("1a2546"), 1.0))
	MenuKit.sphere(self, 0.7, Vector3(-3.5, 7.5, z + 15.6), MenuKit.glow(Color("dfe6ff"), 1.3))
	var trunk: Material = MenuKit.paper(Color("15161f"))
	for tree: Vector3 in [Vector3(-2.6, 0, z + 6.5), Vector3(2.2, 0, z + 8.5), Vector3(4.5, 0, z + 5.0), Vector3(-5.0, 0, z + 9.0)]:
		MenuKit.cylinder(self, 0.12, 3.0, tree + Vector3(0, 1.5, 0), trunk, MenuKit.BG, 0.08, 8)
		MenuKit.sphere(self, 1.2, tree + Vector3(0, 3.4, 0), trunk)
	# Le grillage du portail, au fond de la cour.
	MenuKit.box(self, Vector3(14.0, 1.8, 0.05), Vector3(0, 0.9, z + 12.0), MenuKit.paper(Color("20232f")))

func _side_walls() -> void :
	var wall: Material = MenuKit.paper(Color("d6cebf"))
	var band: Material = MenuKit.paper(Color("5a4f62"))
	for side: int in [-1, 1]:
		MenuKit.box(self, Vector3(0.2, 3.4, 14.0), Vector3(side * 2.4, 1.7, -0.7), wall)
		MenuKit.box(self, Vector3(0.02, 1.0, 14.0), Vector3(side * 2.29, 0.5, -0.7), band)
		MenuKit.box(self, Vector3(0.04, 0.14, 14.0), Vector3(side * 2.28, 0.07, -0.7), MenuKit.paper(Color("24212a")))
	# Côté gauche : patères et manteaux oubliés, banc.
	var hook_mat: Material = MenuKit.paper(Color("8f8676"), {}, "wood")
	MenuKit.box(self, Vector3(0.04, 0.1, 3.4), Vector3(-2.27, 1.62, 2.4), hook_mat)
	var coats: Array = [[1.2, Color("6b3a3a")], [1.9, Color("3e5b74")], [3.3, Color("5c6b45")]]
	for coat: Array in coats:
		var c: MeshInstance3D = MenuKit.box(self, Vector3(0.16, 0.75, 0.4), Vector3(-2.18, 1.25, float(coat[0])), MenuKit.paper(coat[1]))
		c.rotation.z = 0.05
	var wood: Material = MenuKit.paper(Color("82796f"), {}, "wood")
	MenuKit.box(self, Vector3(0.4, 0.06, 2.4), Vector3(-1.95, 0.45, 2.3), wood)
	for z: float in [1.3, 3.3]: MenuKit.box(self, Vector3(0.34, 0.42, 0.06), Vector3(-1.95, 0.21, z), MenuKit.paper(Color("4b5261")))
	MenuKit.box(self, Vector3(0.3, 0.3, 0.22), Vector3(-1.95, 0.63, 2.9), MenuKit.paper(Color("8c5f9c")))
	# Côté droit : portes de classes fermées, vitrine des coupes.
	var door_mat: Material = MenuKit.paper(Color("6b5a48"), {}, "wood")
	for z: float in [-3.4, 0.6]:
		MenuKit.box(self, Vector3(0.06, 2.2, 1.0), Vector3(2.27, 1.1, z), door_mat)
		MenuKit.box(self, Vector3(0.02, 0.5, 0.36), Vector3(2.24, 1.55, z), MenuKit.glow(Color("141a2e"), 1.0))
	MenuKit.box(self, Vector3(0.4, 1.6, 1.4), Vector3(2.05, 1.0, 3.6), MenuKit.paper(Color("4a3c33"), {}, "wood"))
	MenuKit.box(self, Vector3(0.02, 1.2, 1.2), Vector3(1.84, 1.1, 3.6), MenuKit.glow(Color("1d2238"), 1.0))
	for i: int in range(3):
		MenuKit.cylinder(self, 0.06, 0.22, Vector3(2.05, 0.85 + 0.42 * float(i % 2), 3.2 + 0.4 * i), MenuKit.paper(Color("c9a43c")), MenuKit.BG, 0.03, 10)
	# Affiches de la fête de l'école, une arrachée.
	var posters: Array = [[Vector3(-2.28, 1.95, -2.2), Color("e2d6b8")], [Vector3(-2.28, 1.9, -1.4), Color("b9c7d9")], [Vector3(2.28, 1.95, -1.6), Color("e0b9b0")]]
	for p: Array in posters:
		var sheet: MeshInstance3D = MenuKit.box(self, Vector3(0.015, 0.55, 0.42), p[0], MenuKit.paper(p[1]))
		sheet.rotation.x = 0.04

func _lights() -> void :
	_moon = DirectionalLight3D.new()
	_moon.light_color = Color("9fb4ff")
	_moon.light_energy = 1.6
	_moon.shadow_enabled = true
	_moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_moon.directional_shadow_max_distance = 22.0
	add_child(_moon)
	_moon.look_at_from_position(Vector3.ZERO, Vector3(0.22, -0.42, -1.0), Vector3.UP)
	for i: int in range(MenuQuit.LAMPS_Z.size()):
		var z: float = MenuQuit.LAMPS_Z[i]
		var lamp: Dictionary = MenuKit.tube_lamp(self, Vector3(0.0, 3.38, z), 1.2, Color("f4ecd9") if i < 3 else Color("ffe9c8"), 3.6 if i < 3 else 4.2, 5.2, i == 3, false)
		# Faisceau resserré : une flaque de lumière sous chaque néon, les murs restent dans l'ombre.
		(lamp.light as SpotLight3D).spot_angle = 44.0
		(lamp.light as SpotLight3D).spot_angle_attenuation = 2.2
		lamps.append(lamp)
	# Débouché bleu de la vitre sur le visage de Bleuette quand elle se retourne.
	MenuKit.omni(self, Vector3(0.2, 1.5, MenuQuit.DOOR_Z - 0.3), Color("8fa6ff"), 0.6, 2.4)
	MenuKit.omni(self, Vector3(-1.2, 1.8, 3.0), Color("8790c4"), 0.35, 4.0)
	# Débouché très doux sur Alice tout au fond (il meurt avec le premier néon).
	_far_fill = MenuKit.omni(self, MenuQuit.ALICE_AT[0] + Vector3(0.3, 1.5, 1.4), Color("a7a2d8"), 0.45, 2.6)

func _cast() -> void :
	actor("bleu", "Bleuette", MenuQuit.BLEU_AT, 180.0)
	var alice: PaperVisual = actor("alice", "Alice", MenuQuit.ALICE_AT[0], 180.0)
	alice.blob_shadow = false
	var leave: float = MenuQuit.LEAVE_LEN
	var bar: float = MenuQuit.BAR_Y
	var z_bar: float = MenuQuit.DOOR_Z - 0.03
	beats = [
		{"id": "leave", "len": leave, "fade_in": 0.8, "fade_out": 1.4,
			"clips": {"bleu": "menu_quit_leave", "alice": "menu_quit_leave"},
			"vis": {"alice": [[0.0, false], [14.3, true]]},
			"reach": [
				# Les deux mains sur la barre du battant de droite, puis sur celle de gauche.
				["bleu", 1, 0.0, 3.55, Vector3(0.18, bar, z_bar), {"in": 0.0, "out": 0.2}],
				["bleu", -1, 0.0, 3.55, Vector3(0.48, bar, z_bar), {"in": 0.0, "out": 0.2}],
				["bleu", 1, 4.25, 6.1, Vector3(-0.5, bar, z_bar), {"in": 0.2, "out": 0.25}],
				["bleu", -1, 4.3, 6.1, Vector3(-0.18, bar, z_bar), {"in": 0.2, "out": 0.25}],
				# Les paumes à plat sur la vitre, de part et d'autre du visage.
				["bleu", 1, 8.35, 11.3, Vector3(MenuQuit.BLEU_GLASS.x - 0.23, 1.17, MenuQuit.DOOR_Z + 0.035), {"in": 0.3, "out": 0.3}],
				["bleu", -1, 8.45, 11.3, Vector3(MenuQuit.BLEU_GLASS.x + 0.23, 1.2, MenuQuit.DOOR_Z + 0.035), {"in": 0.3, "out": 0.3}],
			],
			"cam": [
				# Depuis la cour, à travers la vitre : Bleuette enfermée qui pousse la barre ; lente avancée
				# jusqu'à son visage collé au verre, les mains en visière.
				[0.0, Vector3(0.95, 1.3, MenuQuit.DOOR_Z + 3.0), ["bleu:head", Vector3(0.0, -0.3, 0.0)], 40.0, {"focus": "bleu:head", "frad": 0.32, "x": 0.56, "shake": 0.2}],
				[4.5, Vector3(0.62, 1.27, MenuQuit.DOOR_Z + 2.45), ["bleu:head", Vector3(0.0, -0.26, 0.0)], 39.0, {"focus": "bleu:head", "frad": 0.3, "x": 0.56, "shake": 0.2}],
				[8.4, Vector3(0.22, 1.16, MenuQuit.DOOR_Z + 1.95), ["bleu:head", Vector3(0.0, -0.18, 0.0)], 37.0, {"focus": "bleu:head", "frad": 0.28, "x": 0.56, "shake": 0.2}],
				[11.4, Vector3(0.0, 1.06, MenuQuit.DOOR_Z + 1.62), ["bleu:head", Vector3(0.0, -0.12, 0.0)], 36.0, {"focus": "bleu:head", "frad": 0.28, "x": 0.56, "shake": 0.2}],
				# Elle se retourne vers le hall (vers nous).
				[11.4, Vector3(0.0, 1.2, 3.75), ["bleu:head", Vector3(0.0, -0.15, 0.0)], 36.0, {"cut": true, "focus": "bleu:head", "frad": 0.26, "x": 0.56}],
				[14.4, Vector3(0.05, 1.18, 3.95), ["bleu:head", Vector3(0.0, -0.15, 0.0)], 35.0, {"focus": "bleu:head", "frad": 0.26, "x": 0.56}],
				# Par-dessus son épaule : tout au fond, sous la dernière lampe, quelqu'un.
				[14.4, Vector3(0.62, 1.34, 6.02), Vector3(-0.2, 1.1, -4.4), 30.0, {"cut": true, "focus": "alice:head", "frad": 0.14, "blur": 3.0, "x": 0.52}],
				[17.4, Vector3(0.6, 1.33, 5.98), Vector3(-0.2, 1.1, -4.4), 27.0, {"focus": "alice:head", "frad": 0.14, "blur": 3.0, "x": 0.52}],
				# Son visage.
				[17.4, Vector3(0.2, 1.1, 4.25), ["bleu:head", Vector3(0.0, -0.2, 0.0)], 34.0, {"cut": true, "focus": "bleu:head", "frad": 0.24, "x": 0.56, "shake": 0.4}],
				[19.4, Vector3(0.16, 1.1, 4.42), ["bleu:head", Vector3(0.0, -0.2, 0.0)], 33.0, {"focus": "bleu:head", "frad": 0.24, "x": 0.56, "shake": 0.4}],
				# Alice, au téléobjectif : au revoir.
				[19.4, Vector3(0.35, 1.25, 4.9), ["alice:head", Vector3(0.0, -0.32, 0.0)], 13.0, {"cut": true, "focus": "alice:head", "frad": 0.22, "blur": 2.6, "x": 0.54}],
				[22.5, Vector3(0.38, 1.25, 4.9), ["alice:head", Vector3(0.0, -0.28, 0.0)], 12.0, {"focus": "alice:head", "frad": 0.22, "blur": 2.6, "x": 0.54}],
				# Par-dessus son épaule : les néons s'éteignent un à un.
				[22.5, Vector3(0.62, 1.34, 6.02), Vector3(0.0, 1.0, -1.0), 34.0, {"cut": true, "focus": "alice:head", "frad": 0.16, "blur": 2.6, "x": 0.52, "shake": 0.3}],
				[25.4, Vector3(0.6, 1.32, 5.96), Vector3(0.0, 1.0, 1.0), 36.0, {"focus": "alice:head", "frad": 0.18, "blur": 2.6, "x": 0.52, "shake": 0.3}],
				# Plan à deux, de profil : Alice penchée sur elle, la main levée ; Bleuette glisse contre la porte.
				[25.4, Vector3(-1.95, 1.3, 3.85), Vector3(-0.1, 1.02, 5.5), 40.0, {"cut": true, "focus": "bleu:head", "frad": 0.36, "x": 0.56, "shake": 0.3}],
				[27.6, Vector3(-1.82, 1.12, 3.98), Vector3(-0.12, 0.86, 5.56), 39.0, {"focus": "bleu:head", "frad": 0.36, "x": 0.56, "shake": 0.3}],
				[leave, Vector3(-1.7, 1.0, 4.1), Vector3(-0.12, 0.76, 5.6), 38.0, {"focus": "bleu:head", "frad": 0.36, "x": 0.56, "shake": 0.3}],
			],
			"events": [ev(0.0, _push.bind(0.0)), ev(0.45, _push.bind(1.0)), ev(1.05, _push.bind(0.7)), ev(2.45, _push.bind(1.0)), ev(2.85, _push.bind(1.2)),
				ev(4.75, _push.bind(-1.0)), ev(5.35, _pull.bind(-1.0)), ev(5.75, _pull.bind(-1.0)), ev(6.45, _tick_minute),
				ev(10.9, _set_flicker.bind(0, 10.9, 11.6)), ev(22.55, _lamp.bind(0, 0.0)), ev(23.85, _lamp.bind(1, 0.0)), ev(25.15, _lamp.bind(2, 0.0)),
				ev(26.6, _set_flicker.bind(3, 26.6, 28.3)), ev(28.3, _lamp.bind(3, 0.0))]},
	]

# --- Effets commandés par le temps fort ------------------------------------------------------

func _push(side: float) -> void :
	# Coup d'épaule dans la porte fermée : le battant tremble dans son chambranle.
	var index: int = 1 if side >= 0.0 else 0
	_door_vel[index] = float(_door_vel[index]) + 0.35 * maxf(absf(side), 0.4)

func _pull(side: float) -> void :
	var index: int = 1 if side >= 0.0 else 0
	_door_vel[index] = float(_door_vel[index]) - 0.3

func _tick_minute() -> void :
	_minute_goal += TAU / 60.0

func _set_flicker(index: int, from: float, to: float) -> void :
	_flicker.append([index, from, to])

func _lamp(index: int, level: float) -> void :
	_lamp_on[index] = level

func reset_state() -> void :
	_flicker.clear()
	_lamp_on = [1.0, 1.0, 1.0, 1.0]
	_door_kick = [0.0, 0.0]
	_door_vel = [0.0, 0.0]
	# 16 h 04 : les cours sont finis depuis longtemps.
	_minute_goal = TAU * 4.0 / 60.0
	_minute.rotation.z = - _minute_goal
	_hour.rotation.z = - TAU * (4.0 + 4.0 / 60.0) / 12.0
	for i: int in range(lamps.size()): MenuKit.set_lamp(lamps[i], 1.0)

func update(_beat_id: String, t: float, dt: float) -> void :
	for i: int in range(2):
		# Ressort raide : le battant bute dans sa gâche.
		var x: float = _door_kick[i]
		var v: float = _door_vel[i]
		v += (- x * 900.0 - v * 22.0) * dt
		x += v * dt
		_door_kick[i] = x
		_door_vel[i] = v
		(_doors[i] as Node3D).position.z = clampf(x, -0.02, 0.012)
	_minute.rotation.z = lerp_angle(_minute.rotation.z, - _minute_goal, 1.0 - exp(- dt * 30.0))
	for i: int in range(lamps.size()):
		var level: float = float(_lamp_on[i])
		for span: Array in _flicker:
			if int(span[0]) != i or t < float(span[1]) or t >= float(span[2]): continue
			var chop: int = int(t * 19.0 + sin(t * 31.0) * 2.0) % 5
			level = 0.05 if chop == 0 else (0.4 if chop == 2 else (0.15 if chop == 4 else 0.9))
		MenuKit.set_lamp(lamps[i], level)
		if i == 0: _far_fill.light_energy = 0.45 * level
	_exit_glow.light_energy = 0.22 + 0.02 * sin(t * 2.3)
