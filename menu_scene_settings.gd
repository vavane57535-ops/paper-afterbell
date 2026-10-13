extends "res://menu_scene.gd"

# RÉGLAGES : Lysia branchée, réparée par Ashura (étincelle toutes les 7 s).
# Gardée telle quelle à la demande du joueur : mêmes acteurs, mêmes clips, mêmes
# lumières et même cadrage que la scène de la 0.16, simplement portée dans le moteur
# des scènes de survol (pas de décor ni de flou).

var _key: DirectionalLight3D
var _accent: OmniLight3D
var _flash: OmniLight3D
var _sparks: CPUParticles3D
var _zapped: int = -1
var _time: float = 0.0

func build_steps() -> Array:
	layered = false
	masked = false
	grade = {"vignette": 0.0, "grain": 0.0}
	return [_lights, _decor, _cast]

func _lights() -> void :
	env_fg = Environment.new()
	env_fg.background_mode = Environment.BG_CLEAR_COLOR
	env_fg.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_fg.ambient_light_color = Color("3a3550")
	env_fg.ambient_light_energy = 0.9
	env_bg = env_fg
	_key = DirectionalLight3D.new()
	_key.rotation = Vector3(-0.75, 2.6, 0.0)
	_key.light_energy = 1.1
	_key.light_color = Color("ffe6cf")
	_key.shadow_enabled = true
	add_child(_key)
	_accent = OmniLight3D.new()
	_accent.position = Vector3(1.8, 2.2, 1.2)
	_accent.omni_range = 7.0
	_accent.light_energy = 1.6
	_accent.light_color = accent
	add_child(_accent)
	_flash = OmniLight3D.new()
	_flash.omni_range = 4.0
	_flash.light_energy = 0.0
	_flash.light_color = Color("bfe9ff")
	_flash.position = Vector3(0.3, 1.1, 0.2)
	add_child(_flash)

func _decor() -> void :
	add_child(MenuKit.floor_pool())
	_old_box(Vector3(0.45, 0.24, 0.26), Vector3(-0.75, 0.12, 0.65), Color("b3312f"))
	_old_box(Vector3(0.47, 0.04, 0.28), Vector3(-0.75, 0.26, 0.65), Color("7a1f1e"))
	_sparks = MenuKit.sparks(self, Vector3(0.3, 0.9, 0.35))

func _old_box(size: Vector3, at: Vector3, color: Color) -> void :
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	mesh.material_override = mat
	mesh.position = at
	add_child(mesh)

func _old_actor(key: String, person: String, at: Vector3, facing: Vector3) -> PaperVisual:
	var visual: PaperVisual = PaperVisual.new()
	visual.lod_enabled = false
	add_child(visual)
	visual.setup(person)
	visual.position = at
	visual.rotation.y = atan2( - facing.x, - facing.z)
	actors[key] = visual
	homes[key] = [at, visual.rotation.y]
	return visual

func _cast() -> void :
	var lysia: PaperVisual = _old_actor("lysia", "Lysia", Vector3(0.55, 0, 0.45), Vector3(-0.55, 0.0, -1.0))
	lysia.set_combat_state({"outlet_healing": 99.0})
	_old_actor("ash", "Ashura", Vector3(-0.35, 0, 0.1), Vector3(1.0, 0.0, 0.2))
	beats = [{"id": "repair", "len": 1.0e9, "cam": [[0.0, Vector3(0.3, 1.55, -4.4), Vector3(0.1, 0.65, 0.2), 34.0, {"x": 0.5, "shake": 0.0, "bg": 0.0}]]}]

func reset_state() -> void :
	_time = 0.0
	_zapped = -1
	if _flash: _flash.light_energy = 0.0

func update(_beat_id: String, _t: float, dt: float) -> void :
	_time += dt
	var t: float = _time
	_flash.light_energy = move_toward(_flash.light_energy, 0.0, dt * 9.0)
	var cycle: float = fmod(t, 7.0)
	var ash: PaperVisual = actors.ash
	var zap_step: int = int(t / 7.0)
	if cycle >= 4.2 and _zapped != zap_step:
		_zapped = zap_step
		ash.play("zap")
		_sparks.restart()
		_sparks.emitting = true
		_flash.light_energy = 6.0
	elif cycle < 4.2 or cycle > 5.85:
		if ash.get("_action") != "repair" or float(ash.get("_action_time")) < 0.05: ash.play("repair")
	if cycle >= 4.2 and cycle < 4.7 and fmod(t, 0.12) < 0.06: _flash.light_energy = 5.0
