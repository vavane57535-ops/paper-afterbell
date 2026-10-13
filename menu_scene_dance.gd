extends "res://menu_scene.gd"

# Aperçu d'une danse de la boutique : le personnage choisi danse la danse demandée, calée
# sur sa musique, sur une petite scène éclairée ; la caméra tourne lentement autour.

var person: String = "Bleuette"
var dance: String = ""
var _ring: MeshInstance3D
var _spot: SpotLight3D
var _rim: OmniLight3D

func build_steps() -> Array:
	masked = true
	grade = {"vignette": 0.4, "grain": 0.02, "saturation": 1.0, "contrast": 1.04}
	return [_lights, _stage_set, _cast]

func _lights() -> void :
	env_fg = Environment.new()
	env_fg.background_mode = Environment.BG_CLEAR_COLOR
	env_fg.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_fg.ambient_light_color = Color("5a4f78")
	env_fg.ambient_light_energy = 0.75
	env_fg.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env_bg = env_fg.duplicate()
	env_bg.background_mode = Environment.BG_COLOR
	env_bg.background_color = Color("120f1c")
	env_bg.glow_enabled = true
	env_bg.glow_intensity = 0.8
	env_bg.glow_bloom = 0.0
	_spot = MenuKit.spot(self, Vector3(0.4, 4.2, -1.2), Vector3(0, 0.9, 0), Color("ffe6f4"), 5.5, 9.0, 24.0, true)
	_rim = MenuKit.omni(self, Vector3(-1.6, 2.0, 1.6), accent, 2.4, 6.0)
	MenuKit.omni(self, Vector3(1.8, 1.2, -1.8), Color("8fa8ff"), 0.8, 6.0)

func _stage_set() -> void :
	# Plancher de scène sombre et anneau lumineux au sol.
	MenuKit.cylinder(self, 2.1, 0.12, Vector3(0, -0.06, 0), MenuKit.paper(Color("2a2336"), {"grid_spacing": 0.45, "grid_width": 0.02}), MenuKit.BG)
	_ring = MenuKit.cylinder(self, 2.12, 0.02, Vector3(0, 0.005, 0), MenuKit.glow(accent, 1.4), MenuKit.BG, 2.0, 48)
	MenuKit.box(self, Vector3(12, 0.1, 12), Vector3(0, -0.2, 0), MenuKit.paper(Color("100d17")))

func _cast() -> void :
	actor("dancer", person, Vector3.ZERO)
	var eye_a: Vector3 = Vector3(0.0, 1.45, -4.6)
	var keys: Array = []
	# Lente révolution (quatre quarts de tour sur 64 s), recadrage léger en hauteur.
	for i: int in range(9):
		var angle: float = deg_to_rad(-38.0 + 76.0 * float(i % 2))
		var radius: float = 4.6 - 0.35 * float(i % 3)
		var eye: Vector3 = Vector3(sin(angle) * radius, 1.35 + 0.15 * float((i + 1) % 2), - cos(angle) * radius)
		keys.append([8.0 * i, eye if i > 0 else eye_a, Vector3(0, 0.95, 0), 32.0, {"x": 0.55, "shake": 0.15, "bg": 1.4}])
	beats = [{"id": "dance", "len": 1.0e9, "cam": keys}]

func update(_beat_id: String, t: float, _dt: float) -> void :
	var dancer: PaperVisual = actors.dancer
	var dance_t: float = t
	var music: AudioStreamPlayer = engine.get("_music") if engine else null
	if music and music.playing and music.stream: dance_t = music.get_playback_position()
	dancer.set_combat_state({"emote_id": dance, "emote_time": dance_t})
	_rim.light_energy = 2.2 + 0.4 * sin(t * 2.1)
