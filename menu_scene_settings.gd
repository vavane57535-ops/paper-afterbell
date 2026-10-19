extends "res://menu_scene.gd"

# RÉGLAGES : la salle de techno, la nuit. Lysia est assise sur un tabouret, la trappe du dos
# ouverte, branchée à la prise du mur ; Ashura, derrière elle, règle ses molettes au tournevis
# sous la lampe d'atelier. Chaque réglage a ses effets : vitesse, volume…

const MenuSettings = preload("res://anim_menu_settings.gd")
const RingShader: Shader = preload("res://fx_ring.gdshader")

var _lamp_light: SpotLight3D
var _screen_mat: StandardMaterial3D
var _screen_light: OmniLight3D
var _flash: OmniLight3D
var _sparks: CPUParticles3D
var _hatch: Node3D
var _hatch_door: Node3D
var _hatch_glow: StandardMaterial3D
var _driver: Node3D
var _outlet: Vector3 = Vector3.ZERO
var _rings: Array = []
var _ring_shots: Array = []
var _papers: Array = []
var _blow: float = -1.0
var _spark_at: float = -1.0
var _glow_level: float = 0.0
var _glow_goal: float = 0.0

func build_steps() -> Array:
	grade = {"vignette": 0.38, "grain": 0.028, "saturation": 0.97, "contrast": 1.06, "lift": Vector3(0.012, 0.01, 0.02)}
	return [_environment, _room, _bench, _bench_props, _lights, _fx, _cast, _cast_props]

func _environment() -> void :
	env = MenuKit.night_environment(Color("736d8f"), 0.62, Color("100e18"), 0.03)

func _room() -> void :
	var floor_mat: Material = MenuKit.paper(Color("7d7368"), {"grid_spacing": 0.5, "grid_width": 0.015, "grid_color": Color(0.12, 0.1, 0.1, 0.45)}, "wood")
	MenuKit.box(self, Vector3(9.0, 0.1, 9.0), Vector3(0.0, -0.05, 1.0), floor_mat)
	var wall: Material = MenuKit.paper(Color("cbc3b4"))
	MenuKit.box(self, Vector3(9.0, 3.2, 0.2), Vector3(0.0, 1.6, 2.6), wall)
	MenuKit.box(self, Vector3(0.2, 3.2, 6.0), Vector3(-3.2, 1.6, 0.0), wall)
	# Plinthe et bande peinte.
	MenuKit.box(self, Vector3(9.0, 0.9, 0.02), Vector3(0.0, 0.45, 2.49), MenuKit.paper(Color("5d6b63")))
	MenuKit.box(self, Vector3(9.0, 0.05, 0.04), Vector3(0.0, 0.92, 2.48), MenuKit.paper(Color("3e4842")))
	# Panneau perforé avec les silhouettes des outils peintes.
	MenuKit.box(self, Vector3(1.9, 0.95, 0.03), Vector3(0.55, 1.75, 2.48), MenuKit.paper(Color("b48f62"), {}, "wood"))
	var ink: Material = MenuKit.paper(Color("3a2f27"))
	var tools: Array = [[Vector3(-0.2, 1.9, 2.46), Vector3(0.05, 0.42, 0.01)], [Vector3(0.05, 1.82, 2.46), Vector3(0.22, 0.05, 0.01)], [Vector3(0.35, 1.95, 2.46), Vector3(0.04, 0.36, 0.01)],
		[Vector3(0.62, 1.7, 2.46), Vector3(0.3, 0.07, 0.01)], [Vector3(0.95, 1.88, 2.46), Vector3(0.06, 0.3, 0.01)], [Vector3(1.2, 1.62, 2.46), Vector3(0.2, 0.2, 0.01)]]
	for entry: Array in tools: MenuKit.box(self, entry[1], entry[0], ink, MenuKit.BG, false)
	# Fenêtre sur le mur de gauche : la lune.
	MenuKit.box(self, Vector3(0.06, 1.2, 1.3), Vector3(-3.08, 1.75, -0.6), MenuKit.glow(Color("2a3b66"), 1.0))
	MenuKit.box(self, Vector3(0.08, 0.05, 1.3), Vector3(-3.06, 1.75, -0.6), MenuKit.paper(Color("2d3040")))
	MenuKit.box(self, Vector3(0.08, 1.2, 0.05), Vector3(-3.06, 1.75, -0.6), MenuKit.paper(Color("2d3040")))
	# Affiche « sécurité » sans texte : un éclair dans un triangle jaune.
	var sign_root: Node3D = MenuKit.pivot(self, Vector3(-1.7, 1.95, 2.48))
	MenuKit.box(sign_root, Vector3(0.42, 0.55, 0.01), Vector3.ZERO, MenuKit.paper(Color("e9e2cf")), MenuKit.BG, false)
	var tri: MeshInstance3D = MenuKit.cylinder(sign_root, 0.15, 0.012, Vector3(0, 0.03, -0.01), MenuKit.paper(Color("e8b923")), MenuKit.BG, -1.0, 3)
	tri.rotation = Vector3(PI / 2, 0, 0)
	var bolt: MeshInstance3D = MenuKit.box(sign_root, Vector3(0.025, 0.13, 0.01), Vector3(0, 0.02, -0.02), MenuKit.paper(Color("1d1a17")), MenuKit.BG, false)
	bolt.rotation.z = 0.35
	# Prise électrique au pied du mur, sous l'établi.
	_outlet = Vector3(-0.7, 0.32, 2.47)
	MenuKit.box(self, Vector3(0.12, 0.12, 0.02), _outlet + Vector3(0, 0, 0.0), MenuKit.paper(Color("e8e4da")), MenuKit.BG, false)

func _bench() -> void :
	var wood: Material = MenuKit.paper(Color("9a7b56"), {}, "wood")
	var dark: Material = MenuKit.paper(Color("4a4037"))
	MenuKit.box(self, Vector3(3.4, 0.07, 0.72), Vector3(0.3, 0.88, 2.1), wood)
	for x: float in [-1.3, 1.9]:
		for z: float in [1.82, 2.38]:
			MenuKit.box(self, Vector3(0.07, 0.86, 0.07), Vector3(x, 0.43, z), dark)
	MenuKit.box(self, Vector3(3.2, 0.04, 0.6), Vector3(0.3, 0.22, 2.1), dark)
	# Tabouret de Lysia : assise ronde, trois pieds, repose-pieds.
	var at: Vector3 = MenuSettings.LYSIA_AT
	var metal: Material = MenuKit.paper(Color("5b6270"))
	MenuKit.cylinder(self, 0.19, 0.06, at + Vector3(0, 0.6, 0), MenuKit.paper(Color("3b3f4f")), MenuKit.BG, -1.0, 20)
	for i: int in range(3):
		var a: float = TAU * float(i) / 3.0 + 0.4
		var leg: MeshInstance3D = MenuKit.cylinder(self, 0.018, 0.64, at + Vector3(cos(a) * 0.13, 0.3, sin(a) * 0.13), metal, MenuKit.BG, -1.0, 6)
		leg.rotation = Vector3(sin(a) * 0.18, 0.0, - cos(a) * 0.18)
	var ring: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.15
	torus.outer_radius = 0.172
	torus.rings = 16
	torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = metal
	ring.position = at + Vector3(0, 0.24, 0)
	add_child(ring)

func _bench_props() -> void :
	# Boîte à outils rouge, drone d'Ashura démonté, ordinateur portable, papiers, tournevis de rechange.
	MenuKit.box(self, Vector3(0.46, 0.22, 0.24), Vector3(-0.95, 1.03, 2.05), MenuKit.paper(Color("b3312f")))
	MenuKit.box(self, Vector3(0.48, 0.04, 0.26), Vector3(-0.95, 1.16, 2.05), MenuKit.paper(Color("7a1f1e")))
	var drone: Node3D = MenuKit.pivot(self, Vector3(-0.3, 0.96, 1.95), 0.5)
	MenuKit.box(drone, Vector3(0.22, 0.06, 0.16), Vector3.ZERO, MenuKit.paper(Color("2f3442")))
	for corner: Vector3 in [Vector3(0.15, 0, 0.12), Vector3(-0.15, 0, 0.12), Vector3(0.15, 0, -0.12), Vector3(-0.15, 0, -0.12)]:
		MenuKit.box(drone, Vector3(0.12, 0.015, 0.02), corner * 0.6, MenuKit.paper(Color("2f3442")))
		MenuKit.cylinder(drone, 0.055, 0.008, corner + Vector3(0, 0.03, 0), MenuKit.paper(Color("9aa3b5")), MenuKit.BG, -1.0, 12)
	MenuKit.cylinder(drone, 0.025, 0.02, Vector3(0, 0.04, -0.06), MenuKit.glow(Color("ff5a4a"), 1.4), MenuKit.BG, -1.0, 10)
	var laptop: Node3D = MenuKit.pivot(self, Vector3(0.35, 0.92, 2.0), -0.35)
	MenuKit.box(laptop, Vector3(0.36, 0.02, 0.25), Vector3.ZERO, MenuKit.paper(Color("3a3d48")))
	var lid: Node3D = MenuKit.pivot(laptop, Vector3(0, 0.01, 0.12))
	lid.rotation.x = -0.32
	MenuKit.box(lid, Vector3(0.36, 0.24, 0.015), Vector3(0, 0.12, 0), MenuKit.paper(Color("3a3d48")))
	_screen_mat = MenuKit.live_glow(Color("6fd6ff"))
	MenuKit.box(lid, Vector3(0.32, 0.2, 0.004), Vector3(0, 0.12, -0.009), _screen_mat, MenuKit.BG, false)
	_screen_light = MenuKit.omni(self, Vector3(0.3, 1.15, 1.75), Color("6fd6ff"), 0.5, 1.8)
	var paper_mat: Material = MenuKit.paper(Color("ece6d6"))
	for i: int in range(4):
		var sheet: MeshInstance3D = MenuKit.box(self, Vector3(0.21, 0.004, 0.29), Vector3(1.0 + 0.12 * i, 0.925 + 0.002 * i, 1.95 + 0.04 * float(i % 2)), paper_mat, MenuKit.BG, false)
		sheet.rotation.y = 0.3 * float(i) - 0.4
		_papers.append({"node": sheet, "home": sheet.transform, "vel": Vector3.ZERO, "spin": Vector3.ZERO})
	# Lampe d'atelier articulée, tête tournée vers le dos de Lysia.
	var base: Vector3 = Vector3(1.05, 0.92, 2.25)
	MenuKit.cylinder(self, 0.09, 0.03, base, MenuKit.paper(Color("2c2f3a")), MenuKit.BG, -1.0, 14)
	var arm_a: MeshInstance3D = MenuKit.box(self, Vector3(0.025, 0.5, 0.025), base + Vector3(0, 0.24, -0.06), MenuKit.paper(Color("2c2f3a")))
	arm_a.rotation.x = -0.25
	var arm_b: MeshInstance3D = MenuKit.box(self, Vector3(0.025, 0.46, 0.025), base + Vector3(-0.14, 0.52, -0.22), MenuKit.paper(Color("2c2f3a")))
	arm_b.rotation = Vector3(-0.9, 0.0, 0.55)
	var head: MeshInstance3D = MenuKit.cylinder(self, 0.035, 0.14, base + Vector3(-0.3, 0.6, -0.38), MenuKit.paper(Color("2c2f3a")), MenuKit.BG, 0.09, 14)
	head.rotation = Vector3(-1.1, 0.0, 0.8)
	MenuKit.sphere(self, 0.035, base + Vector3(-0.35, 0.56, -0.43), MenuKit.glow(Color("ffd9a0"), 2.0))

func _lights() -> void :
	_lamp_light = MenuKit.spot(self, Vector3(0.72, 1.5, 1.85), MenuSettings.LYSIA_AT + Vector3(0.05, 1.0, 0.1), Color("ffcf94"), 9.0, 4.5, 34.0, true)
	# Lune par la fenêtre de gauche, froide, en contre-jour.
	var moon: DirectionalLight3D = DirectionalLight3D.new()
	moon.light_color = Color("98abff")
	moon.light_energy = 0.55
	moon.shadow_enabled = false
	add_child(moon)
	moon.look_at_from_position(Vector3.ZERO, Vector3(0.8, -0.35, 0.3), Vector3.UP)
	# Débouché chaud côté caméra, très doux, pour lire les visages.
	MenuKit.omni(self, Vector3(-0.9, 1.6, -1.1), Color("ffe1c4"), 1.5, 3.8)
	MenuKit.omni(self, Vector3(-0.9, 1.9, 1.3), Color("ffcf94"), 0.8, 2.2)
	_flash = MenuKit.omni(self, MenuSettings.LYSIA_AT + Vector3(0.1, 1.15, 0.35), Color("bfe9ff"), 0.0, 3.0)

func _fx() -> void :
	_sparks = MenuKit.sparks(self, MenuSettings.LYSIA_AT + Vector3(0.08, 1.12, 0.22))
	for i: int in range(5):
		var ring: MeshInstance3D = MeshInstance3D.new()
		var plane: PlaneMesh = PlaneMesh.new()
		plane.size = Vector2(1.0, 1.0)
		ring.mesh = plane
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = RingShader
		ring.material_override = mat
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.visible = false
		add_child(ring)
		_rings.append(ring)

func _cast() -> void :
	var lysia: PaperVisual = actor("lysia", "Lysia", MenuSettings.LYSIA_AT, MenuSettings.LYSIA_YAW)
	lysia.blob_shadow = false
	actor("ash", "Ashura", MenuSettings.ASH_AT, MenuSettings.ASH_YAW)

func _cast_props() -> void :
	# Trappe du dos de Lysia : cadre, porte sur charnière, intérieur lumineux, molettes.
	var chest: Node3D = (actors.lysia as PaperVisual).get("_chest")
	_hatch = Node3D.new()
	chest.add_child(_hatch)
	_hatch.position = Vector3(0.0, 0.1, 0.205)
	_hatch.rotation.x = -0.12
	var frame_mat: Material = MenuKit.flat(Color("2d3140"))
	MenuKit.box(_hatch, Vector3(0.2, 0.17, 0.02), Vector3.ZERO, frame_mat, 1, false)
	_hatch_glow = MenuKit.live_glow(Color("63f2ff"))
	MenuKit.box(_hatch, Vector3(0.16, 0.13, 0.005), Vector3(0, 0, 0.011), _hatch_glow, 1, false)
	for x: float in [-0.045, 0.0, 0.045]:
		MenuKit.cylinder(_hatch, 0.016, 0.02, Vector3(x, -0.03, 0.022), MenuKit.flat(Color("e8e4da")), 1, -1.0, 10).rotation.x = PI / 2
	_hatch_door = Node3D.new()
	_hatch.add_child(_hatch_door)
	_hatch_door.position = Vector3(0.1, 0.0, 0.012)
	_hatch_door.rotation.y = -1.9
	MenuKit.box(_hatch_door, Vector3(0.18, 0.16, 0.012), Vector3(-0.09, 0, 0), MenuKit.flat(Color("44506a")), 1, false)
	# Tournevis d'Ashura (main droite) : manche jaune, tige d'acier.
	_driver = Node3D.new()
	MenuKit.cylinder(_driver, 0.017, 0.1, Vector3(0, 0, 0), MenuKit.flat(Color("e8b923")), 1, 0.014, 10)
	MenuKit.cylinder(_driver, 0.004, 0.12, Vector3(0, -0.11, 0), MenuKit.flat(Color("c9ced8")), 1, -1.0, 6)
	attach("ash", _driver, "right")
	_driver.position = Vector3(0.0, -0.06, -0.035)
	_driver.rotation = Vector3(-1.2, 0.0, 0.0)
	_write_beats()

# --- Effets commandés par les temps forts ---------------------------------------------------

func spark(power: float = 1.0) -> void :
	_sparks.amount = int(46 * power)
	_sparks.restart()
	_sparks.emitting = true
	_flash.light_energy = 6.0 * power
	_spark_at = beat_time

func glow(level: float) -> void :
	_glow_goal = level

func voice(power: float, count: int = 2) -> void :
	for i: int in range(count): _ring_shots.append([beat_time + 0.16 * i, power])
	if power > 0.8: _blow = beat_time

func reset_state() -> void :
	_flash.light_energy = 0.0
	_glow_level = 0.0
	_glow_goal = 0.0
	_ring_shots.clear()
	_blow = -1.0
	for ring: MeshInstance3D in _rings: ring.visible = false
	for paper: Dictionary in _papers:
		(paper.node as Node3D).transform = paper.home
		paper.vel = Vector3.ZERO
		paper.spin = Vector3.ZERO

func update(beat_id: String, t: float, dt: float) -> void :
	_flash.light_energy = move_toward(_flash.light_energy, 0.0, dt * 14.0)
	if t - _spark_at < 0.45 and fmod(t, 0.1) < 0.05: _flash.light_energy = maxf(_flash.light_energy, 3.0)
	_glow_level = move_toward(_glow_level, _glow_goal, dt * 3.0)
	var flick: float = 0.85 + 0.15 * sin(t * 37.0) * sin(t * 11.0)
	_hatch_glow.albedo_color = Color("63f2ff") * lerpf(0.25, 2.2, _glow_level) * flick
	_screen_mat.albedo_color = Color("6fd6ff") * (1.1 + 0.15 * sin(t * 1.7))
	_screen_light.light_energy = 0.45 + 0.05 * sin(t * 1.7)
	# Porte de la trappe : grande ouverte pendant les réglages, rabattue quand Lysia s'éteint.
	_hatch_door.rotation.y = lerpf(_hatch_door.rotation.y, -1.9, 1.0 - exp(- dt * 6.0))

func after_animate(_beat_id: String, t: float, dt: float) -> void :
	_place_cable()
	_update_rings(t)
	_update_papers(t, dt)

# Câble de Lysia : de la queue d'alimentation du dos jusqu'à la prise, avec un peu de mou.
func _place_cable() -> void :
	var lysia: PaperVisual = actors.lysia
	var tail: Node3D = lysia.get("_plug_tail")
	var segments: Array = lysia.get("_plug_segments")
	if tail == null or segments.is_empty(): return
	var start: Vector3 = tail.global_position
	var finish: Vector3 = global_transform * (_outlet + Vector3(0, 0, -0.03))
	var count: int = segments.size()
	for i: int in range(count):
		var u: float = float(i) / float(count)
		var v: float = float(i + 1) / float(count)
		var a: Vector3 = start.lerp(finish, u) + Vector3.DOWN * sin(u * PI) * 0.28
		var b: Vector3 = start.lerp(finish, v) + Vector3.DOWN * sin(v * PI) * 0.28
		var seg: Node3D = segments[i]
		seg.global_transform = Transform3D(Basis.looking_at(b - a, Vector3.UP, true), a)
		seg.scale = Vector3(seg.scale.x, seg.scale.y, a.distance_to(b) / (0.25 if i == count - 1 else 0.13))

# Ondes de voix : anneaux qui partent de la bouche de Lysia, face à la caméra.
func _update_rings(t: float) -> void :
	var mouth: Vector3 = to_local((actors.lysia as PaperVisual).socket_position("mouth"))
	var facing: Vector3 = Vector3(- sin(deg_to_rad(MenuSettings.LYSIA_YAW)), 0.0, - cos(deg_to_rad(MenuSettings.LYSIA_YAW)))
	var slot: int = 0
	for shot: Array in _ring_shots:
		var age: float = t - float(shot[0])
		if age < 0.0 or age > 0.7 or slot >= _rings.size(): continue
		var ring: MeshInstance3D = _rings[slot]
		slot += 1
		var power: float = shot[1]
		var size: float = lerpf(0.12, 0.5 + 0.9 * power, age / 0.7)
		ring.visible = true
		ring.position = mouth + facing * (0.06 + age * 0.5 * power)
		var side: Vector3 = Vector3.UP.cross(facing).normalized()
		ring.basis = Basis(side, facing, side.cross(facing)).orthonormalized() * Basis.from_scale(Vector3.ONE * size)
		ring.set_instance_shader_parameter("color", Color(0.75, 0.95, 1.0, (1.0 - age / 0.7) * 0.85))
		ring.set_instance_shader_parameter("thickness", 0.02 + 0.03 * power)
	for i: int in range(slot, _rings.size()): (_rings[i] as Node3D).visible = false

# Papiers de l'établi soufflés par le cri, qui retombent en planant.
func _update_papers(t: float, dt: float) -> void :
	if _blow < 0.0: return
	var age: float = t - _blow
	for i: int in range(_papers.size()):
		var paper: Dictionary = _papers[i]
		var node: Node3D = paper.node
		if age < 0.05 + 0.04 * i: continue
		if (paper.vel as Vector3) == Vector3.ZERO and age < 0.3:
			paper.vel = Vector3(0.6 + 0.3 * i, 1.6 + 0.25 * float(i % 2), 0.4 - 0.25 * i)
			paper.spin = Vector3(2.0 + i, 3.0 - i, 1.5)
		var v: Vector3 = paper.vel
		v += Vector3(0, -2.2, 0) * dt
		v = v.lerp(Vector3(0, -0.35, 0), 1.0 - exp(- dt * 1.4))
		paper.vel = v
		var pos: Vector3 = node.position + v * dt
		if pos.y < 0.01:
			pos.y = 0.01
			paper.vel = Vector3.ZERO
			paper.spin = Vector3.ZERO
		node.position = pos
		node.rotation += (paper.spin as Vector3) * dt

# --- Temps forts ---------------------------------------------------------------------------------

func _write_beats() -> void :
	var both: Vector3 = Vector3(0.0, 1.05, 0.66)
	var tune: float = MenuSettings.TUNE_LEN
	beats = [
		{"id": "tune", "len": tune, "fade_in": 0.6, "fade_out": 0.6,
			"clips": {"lysia": "menu_settings_tune", "ash": "menu_settings_tune"},
			"reach": [
				["ash", 1, 0.0, 3.95, "lysia:back", {"in": 0.0, "out": 0.3, "offset": Vector3(0.05, 0.02, 0.17)}],
				["ash", 1, 31.0, tune, "lysia:back", {"in": 0.5, "out": 0.0, "offset": Vector3(0.05, 0.02, 0.17)}],
				["ash", -1, 0.0, 4.3, "lysia:chest", {"in": 0.0, "out": 0.25, "offset": Vector3(-0.16, 0.14, 0.04)}],
				["ash", -1, 31.0, tune, "lysia:chest", {"in": 0.5, "out": 0.0, "offset": Vector3(-0.16, 0.14, 0.04)}],
				["ash", -1, 4.5, 5.0, "lysia:back", {"in": 0.15, "out": 0.2, "offset": Vector3(-0.02, -0.03, 0.04)}],
				["ash", -1, 10.8, 12.35, "lysia:head", {"in": 0.2, "out": 0.25, "offset": Vector3(0.0, 0.02, 0.01)}],
				["ash", -1, 12.75, 14.0, "lysia:back", {"in": 0.2, "out": 0.25, "offset": Vector3(-0.04, -0.04, 0.04)}],
				["ash", -1, 17.75, 18.35, "lysia:back", {"in": 0.12, "out": 0.15, "offset": Vector3(-0.04, -0.04, 0.04)}],
				["ash", -1, 20.0, 20.65, "lysia:back", {"in": 0.15, "out": 0.15, "offset": Vector3(-0.04, -0.04, 0.04)}],
			],
			"cam": [
				# Large, trois quarts face : l'atelier, la lampe, Ashura penché sur le dos de Lysia éteinte.
				[0.0, Vector3(-1.6, 1.32, -1.75), Vector3(0.08, 1.0, 0.7), 38.0, {"focus": both, "frad": 0.3, "x": 0.56}],
				[5.0, Vector3(-1.28, 1.28, -1.36), Vector3(0.06, 1.0, 0.7), 37.0, {"focus": both, "frad": 0.3, "x": 0.56}],
				# Elle démarre : gros plan, Ashura flou derrière.
				[5.0, Vector3(-0.55, 1.06, -0.95), ["lysia:head", Vector3(0.0, -0.12, 0.0)], 38.0, {"cut": true, "focus": "lysia:head", "frad": 0.26, "x": 0.56}],
				[9.6, Vector3(-0.47, 1.05, -0.85), ["lysia:head", Vector3(0.0, -0.12, 0.0)], 37.0, {"focus": "lysia:head", "frad": 0.26, "x": 0.56}],
				# La tête qui tourne trop : plan à deux, de l'autre côté.
				[9.6, Vector3(-1.85, 1.45, -0.7), both, 40.0, {"cut": true, "focus": "lysia:head", "frad": 0.32, "x": 0.56}],
				[14.4, Vector3(-1.7, 1.42, -0.62), both, 39.0, {"focus": "ash:head", "frad": 0.32, "x": 0.56}],
				# Molette « vitesse » : plan large à deux, caméra à l'épaule quand ça s'emballe.
				[14.4, Vector3(-1.45, 1.3, -1.9), both, 40.0, {"cut": true, "focus": both, "frad": 0.34, "x": 0.56, "shake": 0.2}],
				[18.3, Vector3(-1.35, 1.28, -1.72), both, 40.0, {"focus": both, "frad": 0.34, "x": 0.56, "shake": 0.25}],
				[18.45, Vector3(-1.33, 1.28, -1.7), both, 41.0, {"focus": both, "frad": 0.34, "x": 0.56, "shake": 1.4}],
				[20.6, Vector3(-1.22, 1.26, -1.55), both, 40.0, {"focus": both, "frad": 0.34, "x": 0.56, "shake": 1.4}],
				[21.2, Vector3(-1.2, 1.26, -1.52), both, 40.0, {"focus": both, "frad": 0.34, "x": 0.56, "shake": 0.2}],
				# Le coucou pour nous.
				[21.2, Vector3(-0.42, 1.1, -0.98), ["lysia:head", Vector3(0.0, -0.1, 0.0)], 37.0, {"cut": true, "focus": "lysia:head", "frad": 0.26, "x": 0.56}],
				[23.6, Vector3(-0.38, 1.1, -0.88), ["lysia:head", Vector3(0.0, -0.1, 0.0)], 36.0, {"focus": "lysia:head", "frad": 0.26, "x": 0.56}],
				# Le pouce à l'envers, l'étincelle.
				[23.6, Vector3(-0.95, 1.2, -1.45), both + Vector3(0.0, -0.05, 0.0), 38.0, {"cut": true, "focus": both, "frad": 0.34, "x": 0.56}],
				[27.3, Vector3(-0.88, 1.2, -1.32), both + Vector3(0.0, -0.05, 0.0), 37.0, {"focus": both, "frad": 0.34, "x": 0.56}],
				[27.3, Vector3(-1.45, 1.32, -1.6), Vector3(0.08, 1.0, 0.7), 38.0, {"cut": true, "focus": both, "frad": 0.32, "x": 0.56, "shake": 0.6}],
				[28.2, Vector3(-1.5, 1.32, -1.66), Vector3(0.08, 1.0, 0.7), 38.0, {"focus": both, "frad": 0.32, "x": 0.56, "shake": 0.2}],
				[tune, Vector3(-1.6, 1.32, -1.75), Vector3(0.08, 1.0, 0.7), 38.0, {"focus": both, "frad": 0.3, "x": 0.56}],
			],
			"events": [ev(0.0, glow.bind(0.2)), ev(4.8, glow.bind(1.0)), ev(4.82, spark.bind(0.25)), ev(13.5, glow.bind(0.5)), ev(14.2, glow.bind(0.85)),
				ev(18.1, glow.bind(1.6)), ev(20.5, glow.bind(0.9)), ev(26.5, spark.bind(0.2)), ev(27.4, spark.bind(1.0)), ev(27.45, glow.bind(0.1)), ev(31.0, glow.bind(0.2))]},
	]

