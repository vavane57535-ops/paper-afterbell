extends PaperCinema
class_name PaperPrologue

# « Prologue — Yiero » : la cinématique d'introduction du premier lancement (et de la cinémathèque).
# Simon et Ashura affrontent Yiero dans une dimension ténébreuse, Ashura est effacé, Simon fuit et
# traverse une porte de lumière jusqu'à l'école où Usayuko se bat contre Alice ; titre final.
# Le film réutilise la machinerie de PaperCinema (_shot/_move/_do/_cue, caméra, effets BD) et
# ajoute : deux décors (dimension / école), pistes d'images clés (Yiero, lumière, décor), dialogues
# façon Undertale, ralentis, musique et bruitages propres, effacement d'Ashura, aura d'Usayuko.
# Storyboard et minutage musical : docs/INTRO-YIERO.md.

const YieroModel = preload("res://yiero_model.gd")
const VoidSet = preload("res://intro_dimension.gd")
const OverlayLayer = preload("res://intro_overlay.gd")

const LENGTH: float = 196.0
const T_SCHOOL: float = 153.0
const T_TITLE: float = 181.6
const DIM: Vector3 = Vector3(2600.0, 0.0, 0.0)
const SKIP_HOLD: float = 1.1
const MUSIC_PATH: String = "res://audio/cinematic/intro_yiero.ogg"
const SFX_DIR: String = "res://audio/cinematic/"
# Les bruitages du film (sfx_*.wav, tools/synth_intro_audio.py) sont calés en RMS court terme ; ce
# niveau les place au-dessus de la musique (-18 LUFS × MUSIC_LEVEL) sans saturer le limiteur du mix.
# Dosage réglé avec la musique de la 0.15 : _play_stream et les blips y ajoutent PaperAudio.FILM_SFX_TRIM.
const FILM_SFX_LEVEL: float = 0.6
const CAST: Array[String] = ["Simon", "Ashura", "Usayuko", "Alice", "Elly", "Bleuette", "Lysia"]

const S: int = 0
const A: int = 1
const U: int = 2
const AL: int = 3
const E: int = 4
const B: int = 5
const L: int = 6

const GOLD_LIGHT: Color = Color("ffcf5a")
const YIERO_RED: Color = Color("ff3a28")

const GLOW_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, fog_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform float energy = 1.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float core = exp(-d * d * 9.0);
	float halo = exp(-d * 3.2) * (1.0 - smoothstep(0.85, 1.0, d));
	ALBEDO = (color.rgb * halo * 0.8 + vec3(1.0, 0.97, 0.88) * core) * energy;
}
"""

const DISSOLVE_SHADER: String = """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool textured = false;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float progress = 0.0;
uniform float fade = 0.0;
uniform float base_y = 0.0;
uniform float height = 1.8;
varying vec3 wpos;
float hash(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float noise(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 base = albedo_color.rgb;
	if (textured) base *= texture(albedo_tex, UV).rgb;
	float grey = dot(base, vec3(0.3, 0.55, 0.15));
	base = mix(base, vec3(grey) * vec3(0.92, 0.88, 0.82), fade);
	float h = clamp((wpos.y - base_y) / height, 0.0, 1.0);
	float n = noise(wpos * 9.0) * 0.28 + noise(wpos * 2.5) * 0.22;
	float d = (h + n) - (progress * 1.6 - 0.25);
	if (d < 0.0) discard;
	float edge = 1.0 - smoothstep(0.0, 0.07, d);
	ALBEDO = mix(base, vec3(0.03, 0.015, 0.02), smoothstep(0.12, 0.0, d) * step(0.001, progress));
	ROUGHNESS = 1.0;
	EMISSION = vec3(1.0, 0.72, 0.28) * edge * 2.4 * step(0.001, progress) + base * 0.12;
}
"""

const FLAKE_SHADER: String = """
shader_type spatial;
render_mode cull_disabled, unshaded;
uniform float progress = 0.0;
uniform vec3 origin = vec3(0.0);
uniform vec3 target = vec3(0.0, 20.0, 40.0);
uniform float height = 1.8;
varying vec4 tint;
void vertex() {
	vec4 cd = INSTANCE_CUSTOM;
	float emit = cd.x * 0.62;
	float age = clamp((progress - emit) / 0.55, 0.0, 1.0);
	float alive = step(0.0001, age) * (1.0 - smoothstep(0.85, 1.0, age));
	vec3 start = origin + vec3((cd.y - 0.5) * 0.7, cd.x * height, (cd.z - 0.5) * 0.5);
	vec3 swirl = vec3(sin(age * 9.0 + cd.y * 30.0), 0.0, cos(age * 7.0 + cd.z * 20.0)) * (1.0 + age * 3.0);
	vec3 path = mix(start, target, smoothstep(0.15, 1.0, age) * 0.9) + swirl + vec3(0.0, age * 4.0, 0.0);
	float a = age * 12.0 + cd.w * 6.28;
	mat2 r = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a)));
	vec3 v = VERTEX;
	v.xy = r * v.xy;
	v *= alive * (0.6 + cd.w);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(path, 1.0)).xyz + v;
	tint = COLOR;
}
void fragment() {
	ALBEDO = tint.rgb;
}
"""

const FLAME_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, fog_disabled;
uniform float clock = 0.0;
uniform float power = 1.0;
uniform vec4 inner : source_color = vec4(1.0, 0.97, 0.82, 1.0);
uniform vec4 outer : source_color = vec4(1.0, 0.68, 0.18, 1.0);
uniform vec4 edge : source_color = vec4(0.85, 0.22, 0.12, 1.0);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	vec2 uv = vec2(UV.x * 6.0, UV.y);
	float n = noise(vec2(uv.x * 2.0, uv.y * 3.0 + clock * 2.6)) * 0.6 + noise(vec2(uv.x * 5.0, uv.y * 7.0 + clock * 4.1)) * 0.4;
	float h = 1.0 - UV.y;
	float flame = smoothstep(0.15, 0.95, n * (1.2 - h * 0.9) + (1.0 - h) * 0.35);
	float tongue = smoothstep(0.55, 0.9, noise(vec2(uv.x * 3.0, uv.y * 2.0 + clock * 3.3))) * h;
	vec3 col = mix(edge.rgb, outer.rgb, smoothstep(0.2, 0.6, flame));
	col = mix(col, inner.rgb, smoothstep(0.65, 1.0, flame));
	float a = flame * (0.25 + 0.75 * (1.0 - h)) * smoothstep(0.0, 0.25, UV.y) + tongue * 0.4;
	ALBEDO = col * a * power * 0.5;
}
"""

const RUNE_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, fog_disabled;
uniform float clock = 0.0;
uniform float power = 1.0;
void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float r = length(p);
	float a = atan(p.y, p.x) + clock * 0.9;
	float ring1 = smoothstep(0.03, 0.0, abs(r - 0.92)) + smoothstep(0.02, 0.0, abs(r - 0.78));
	float seg = step(0.5, fract(a * 24.0 / 6.2831)) * step(0.8, r) * step(r, 0.9);
	float glyph = step(0.62, fract(a * 8.0 / 6.2831 + 0.13)) * step(0.55, r) * step(r, 0.72) * step(0.35, fract(r * 23.0 + a * 1.7));
	float star = smoothstep(0.025, 0.0, abs(sin(a * 2.5 - clock * 1.8) * r - 0.0)) * step(r, 0.6) * 0.5;
	float glow = exp(-r * 2.4) * 0.35;
	float v = (ring1 + seg * 0.8 + glyph + star) * step(r, 1.0) + glow;
	ALBEDO = mix(vec3(1.0, 0.45, 0.12), vec3(1.0, 0.92, 0.6), clamp(v, 0.0, 1.0)) * v * power;
}
"""

const PORTAL_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform float open = 0.0;
uniform float clock = 0.0;
uniform float demon = 0.0;
void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(2.0, 2.0);
	float r = length(p * vec2(1.0, 0.62));
	float edge = 1.0 - smoothstep(0.82, 1.0, r / max(open, 0.001));
	if (edge <= 0.001) discard;
	float wobble = 0.5 + 0.5 * sin(atan(p.y, p.x) * 9.0 + clock * 3.0);
	vec3 light = mix(vec3(1.0, 0.72, 0.38), vec3(1.0, 0.98, 0.92), 1.0 - r) * (2.2 + wobble * 0.6);
	vec3 col = light;
	if (demon > 0.0) {
		vec2 q = vec2(p.x, - p.y) * vec2(1.0, 0.62);
		vec3 face = vec3(0.025, 0.0, 0.0);
		for (int k = 0; k < 2; k++) {
			vec2 c = vec2(k == 0 ? -0.15 : 0.15, 0.13);
			float d = length(q - c);
			float sclera = smoothstep(0.052, 0.045, d);
			float rim = smoothstep(0.06, 0.052, d) - sclera;
			float pupil = smoothstep(0.011, 0.006, d);
			face = mix(face, vec3(0.78, 0.72, 0.62) * (1.0 - d * 9.0), sclera);
			face = mix(face, vec3(0.08, 0.03, 0.02), rim);
			face = mix(face, vec3(1.0), pupil);
		}
		float upper = -0.05 - 0.13 * (1.0 - pow(q.x / 0.36, 2.0));
		float lower = upper - 0.08 * (1.0 - pow(q.x / 0.36, 2.0));
		float inside = step(abs(q.x), 0.36) * step(lower, q.y) * step(q.y, upper + 0.012);
		float teeth_up = step(q.y, upper) * step(upper - 0.05 * (1.0 - abs(fract(q.x * 26.0) * 2.0 - 1.0)), q.y);
		float teeth_dn = step(lower, q.y) * step(q.y, lower + 0.04 * (1.0 - abs(fract(q.x * 24.0 + 0.5) * 2.0 - 1.0)));
		vec3 mouth = mix(vec3(0.45, 0.02, 0.03), vec3(0.0), smoothstep(0.0, 0.03, upper - q.y) * smoothstep(0.0, 0.03, q.y - lower));
		mouth = mix(mouth, vec3(0.9, 0.84, 0.66), clamp(teeth_up + teeth_dn, 0.0, 1.0));
		face = mix(face, mouth, inside);
		col = mix(col, face, demon * smoothstep(0.78, 0.25, r));
	}
	ALBEDO = col;
	ALPHA = edge;
}
"""

var yiero: YieroModel
var dimension: VoidSet
var overlay: OverlayLayer
var gallery_mode: bool = false
var paused: bool = false
var clock: float = 0.0

var _set_root: Node3D
var _keys: Dictionary = {}
var _lines: Array = []
var _flashes: Array = []
var _ripples: Array = []
var _spike_rows: Array = []
var _slow: Array = []
var _shocks: Array = []
var _stage: String = ""
var _built: bool = false
var _music: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx: int = 0
var _sfx_streams: Dictionary = {}
var _glows: Array = []
var _aura: Node3D
var _aura_flames: Array[MeshInstance3D] = []
var _aura_runes: MeshInstance3D
var _aura_tags: Array[MeshInstance3D] = []
var _aura_light: OmniLight3D
var _flame_material: ShaderMaterial
var _rune_material: ShaderMaterial
var _portal: MeshInstance3D
var _portal_material: ShaderMaterial
var _portal_light: OmniLight3D
var _lysia_light: OmniLight3D
var _erase_light: OmniLight3D
var _flakes: MultiMeshInstance3D
var _flake_material: ShaderMaterial
var _erase_saved: Array = []
var _erase_materials: Array[ShaderMaterial] = []
var _erasing: bool = false
var _blip_cursor: Dictionary = {}
var _last_t: float = -1.0
var _skip_hold: float = 0.0
var _skip_seen: float = 0.0
var _camera_far: float = 340.0
var _shown_school: bool = true
var _overlay_ready: bool = false




func setup_prologue(owner: Node3D) -> void :
	setup(owner)
	name = "Prologue"

func _ensure_built() -> void :
	if _built: return
	_built = true
	_set_root = Node3D.new();_set_root.name = "PrologueSet";_cast_root.add_child(_set_root)
	dimension = VoidSet.new();dimension.name = "Dimension";_set_root.add_child(dimension)
	dimension.position = DIM
	dimension.build()
	dimension.process_mode = Node.PROCESS_MODE_DISABLED
	yiero = YieroModel.new();yiero.name = "Yiero";_set_root.add_child(yiero)
	yiero.build()
	_build_glows()
	_build_aura()
	_build_portal()
	_build_flakes()
	_lysia_light = OmniLight3D.new();_lysia_light.light_color = Color("ff6a3a");_lysia_light.omni_range = 3.0;_lysia_light.light_energy = 0.0;_set_root.add_child(_lysia_light)
	_erase_light = OmniLight3D.new();_erase_light.light_color = Color("ffb84a");_erase_light.omni_range = 4.0;_erase_light.light_energy = 0.0;_erase_light.visible = false;_set_root.add_child(_erase_light)
	overlay = OverlayLayer.new()
	var ui: Variant = world.get("ui")
	if is_instance_valid(ui): (ui.root as Control).add_child(overlay)
	else: add_child(overlay)
	overlay.setup()
	_music = AudioStreamPlayer.new();_music.name = "PrologueMusic";overlay.add_child(_music)
	_music.bus = &"PaperMusic" if AudioServer.get_bus_index(&"PaperMusic") >= 0 else &"Master"
	if ResourceLoader.exists(MUSIC_PATH): _music.stream = load(MUSIC_PATH) as AudioStream
	for i: int in range(12):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = &"PaperWorld" if AudioServer.get_bus_index(&"PaperWorld") >= 0 else &"Master"
		overlay.add_child(player)
		_sfx_players.append(player)
	_overlay_ready = true
	_set_root.hide()

func _shader(code: String) -> Shader:
	var shader: Shader = Shader.new()
	shader.code = code
	return shader

func _build_glows() -> void :
	var material: ShaderMaterial = ShaderMaterial.new();material.shader = _shader(GLOW_SHADER)
	material.set_shader_parameter("color", GOLD_LIGHT)
	for owner_index: int in [S, A]:
		var row: Array = []
		for side: int in range(2):
			var holder: Node3D = Node3D.new();_set_root.add_child(holder)
			var quad: QuadMesh = QuadMesh.new();quad.size = Vector2(1.0, 1.0)
			var mesh: MeshInstance3D = MeshInstance3D.new();mesh.mesh = quad;mesh.material_override = material.duplicate()
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(mesh)
			var light: OmniLight3D = OmniLight3D.new();light.light_color = GOLD_LIGHT;light.omni_range = 4.5;light.light_energy = 0.0
			holder.add_child(light)
			row.append([holder, mesh, light])
		_glows.append(row)

func _build_aura() -> void :
	_aura = Node3D.new();_aura.name = "UsayukoAura";_set_root.add_child(_aura)
	_flame_material = ShaderMaterial.new();_flame_material.shader = _shader(FLAME_SHADER)
	for i: int in range(3):
		var cylinder: CylinderMesh = CylinderMesh.new()
		cylinder.top_radius = 0.12 + 0.1 * float(i);cylinder.bottom_radius = 0.5 + 0.13 * float(i);cylinder.height = 2.2 + 0.3 * float(i)
		cylinder.cap_top = false;cylinder.cap_bottom = false;cylinder.radial_segments = 20;cylinder.rings = 2
		var node: MeshInstance3D = MeshInstance3D.new();node.mesh = cylinder;node.material_override = _flame_material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.position = Vector3(0, cylinder.height * 0.5 - 0.05, 0)
		_aura.add_child(node);_aura_flames.append(node)
	_rune_material = ShaderMaterial.new();_rune_material.shader = _shader(RUNE_SHADER)
	var plane: PlaneMesh = PlaneMesh.new();plane.size = Vector2(3.6, 3.6)
	_aura_runes = MeshInstance3D.new();_aura_runes.mesh = plane;_aura_runes.material_override = _rune_material
	_aura_runes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;_aura_runes.position = Vector3(0, 0.04, 0)
	_aura.add_child(_aura_runes)
	var tag_material: StandardMaterial3D = StandardMaterial3D.new()
	tag_material.albedo_color = Color("f4ead2");tag_material.emission_enabled = true;tag_material.emission = Color("ffd88a");tag_material.emission_energy_multiplier = 0.9
	tag_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mark_material: StandardMaterial3D = StandardMaterial3D.new()
	mark_material.albedo_color = Color("c4142c");mark_material.emission_enabled = true;mark_material.emission = Color("ff2a3a");mark_material.emission_energy_multiplier = 1.4
	mark_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i: int in range(8):
		var quad: QuadMesh = QuadMesh.new();quad.size = Vector2(0.085, 0.25)
		var tag: MeshInstance3D = MeshInstance3D.new();tag.mesh = quad;tag.material_override = tag_material
		tag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mark: MeshInstance3D = MeshInstance3D.new();var mq: QuadMesh = QuadMesh.new();mq.size = Vector2(0.032, 0.15);mark.mesh = mq;mark.material_override = mark_material;mark.position = Vector3(0, 0, 0.004)
		tag.add_child(mark)
		_aura.add_child(tag);_aura_tags.append(tag)
	_aura_light = OmniLight3D.new();_aura_light.light_color = Color("ffc35a");_aura_light.omni_range = 6.5;_aura_light.light_energy = 0.0
	_aura_light.position = Vector3(0, 1.3, 0)
	_aura.add_child(_aura_light)
	_aura.hide()

func _build_portal() -> void :
	_portal_material = ShaderMaterial.new();_portal_material.shader = _shader(PORTAL_SHADER)
	var quad: QuadMesh = QuadMesh.new();quad.size = Vector2(2.4, 3.6)
	_portal = MeshInstance3D.new();_portal.mesh = quad;_portal.material_override = _portal_material
	_portal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_set_root.add_child(_portal)
	_portal_light = OmniLight3D.new();_portal_light.light_color = Color("ffd9a0");_portal_light.omni_range = 9.0;_portal_light.light_energy = 0.0
	_portal.add_child(_portal_light);_portal_light.position = Vector3(0, 0, 1.0)
	_portal.hide()

func _build_flakes() -> void :
	_flake_material = ShaderMaterial.new();_flake_material.shader = _shader(FLAKE_SHADER)
	var quad: QuadMesh = QuadMesh.new();quad.size = Vector2(0.17, 0.12)
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D;multimesh.use_colors = true;multimesh.use_custom_data = true;multimesh.mesh = quad
	multimesh.instance_count = 320
	var rng: RandomNumberGenerator = RandomNumberGenerator.new();rng.seed = 404
	var palette: Array[Color] = [Color("2a2f45"), Color("6f6aa0"), Color("e9e2d2"), Color("111117"), Color("9fe0ee"), Color("ffd27a")]
	for i: int in range(multimesh.instance_count):
		multimesh.set_instance_transform(i, Transform3D.IDENTITY)
		multimesh.set_instance_color(i, palette[rng.randi_range(0, palette.size() - 1)])
		multimesh.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), rng.randf(), rng.randf()))
	_flakes = MultiMeshInstance3D.new();_flakes.multimesh = multimesh;_flakes.material_override = _flake_material
	_flakes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;_flakes.extra_cull_margin = 200.0
	_set_root.add_child(_flakes)
	_flakes.hide()




func begin_prologue(from_gallery: bool) -> void :
	stop()
	_ensure_built()
	kind = "intro_yiero";focus_name = "Simon";elapsed = 0.0;duration = LENGTH
	gallery_mode = from_gallery;paused = false;clock = 0.0;_skip_hold = 0.0;_skip_seen = 0.0;_last_t = -1.0
	anchor = DIM;right = Vector3.RIGHT;forward = Vector3.BACK;finish = DIM + forward * 20.0;_length = 20.0
	people = ["Simon", "Ashura", "Usayuko", "Elly", "Bleuette", "Lysia"]
	for person: String in CAST: _add_actor(person)
	# Pas de geste d'attente aléatoire (dépend de l'instance : il changeait d'une machine à l'autre) :
	# chaque geste du film est écrit.
	for take: Take in takes: take.visual.fidgets = false
	alice_index = AL
	props = PaperCinemaProps.new();add_child(props);props.reduce_flashes = _flashes_reduced()
	props.setup(DIM, Vector3.RIGHT, Vector3.BACK, kind, ["Simon", "Ashura"])
	rim.omni_range = 11;rim.light_energy = 1.3;fill.omni_range = 9;fill.light_energy = 0.6
	_spots.resize(takes.size())
	_keys.clear();_lines.clear();_flashes.clear();_ripples.clear();_spike_rows.clear();_slow.clear();_shocks.clear();_blip_cursor.clear()
	_write_prologue()
	_seal()
	for track: String in _keys:
		(_keys[track] as Array).sort_custom( func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	_lines.sort_custom( func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	_camera_far = world.camera.far
	_stage = ""
	show();_set_root.show()
	overlay.reset();overlay.show()
	overlay.set_raise(112.0 if gallery_mode else 0.0)
	var comic: Node = _comic()
	if comic: comic.set("frame_guard", true)
	_restart()
	update(0.0, 0.0)

func stop() -> void :
	var was: bool = kind == "intro_yiero"
	if was:
		_restore_erase()
		if _music: _music.stop()
		for player: AudioStreamPlayer in _sfx_players: player.stop()
		if overlay: overlay.reset();overlay.hide()
		_enter_stage("")
	super.stop()
	if _set_root: _set_root.hide()

func set_paused(value: bool) -> void :
	paused = value
	if _music: _music.stream_paused = value and _music.playing

func _restart() -> void :
	super._restart()
	_restore_erase()
	_blip_cursor.clear()

# Lecture autonome (premier lancement) : avance le film, gère « maintenir pour passer ».
# Renvoie vrai quand le film est fini ou passé.
func tick_standalone(delta: float) -> bool:
	if kind.is_empty(): return true
	var held: bool = Input.is_key_pressed(KEY_ESCAPE) or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_KP_ENTER) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	for pad: int in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(pad, JOY_BUTTON_A) or Input.is_joy_button_pressed(pad, JOY_BUTTON_START): held = true
	if held:
		_skip_hold += delta;_skip_seen = 2.2
	else:
		_skip_hold = maxf(0.0, _skip_hold - delta * 2.5);_skip_seen = maxf(0.0, _skip_seen - delta)
	clock = minf(duration, clock + delta)
	update(clock, delta)
	var hint: float = clampf(_skip_seen, 0.0, 1.0)
	if clock > 1.2 and clock < 7.5: hint = maxf(hint, 0.55 * (1.0 - smoothstep(6.5, 7.5, clock)) * smoothstep(1.2, 2.0, clock))
	overlay.set_skip(clampf(_skip_hold / SKIP_HOLD, 0.0, 1.0), hint)
	return _skip_hold >= SKIP_HOLD or clock >= duration




func _stage_at(t: float) -> String:
	return "void" if t < T_SCHOOL else "school"

func _apply_frame(stage: String) -> void :
	if stage == "school" and is_instance_valid(world.school):
		anchor = world.school.cinematic_anchor
		var ahead: Vector3 = world.school.cinematic_exit - anchor
		ahead.y = 0.0
		forward = ahead.normalized() if ahead.length_squared() > 0.01 else Vector3.BACK
		right = Vector3.UP.cross(forward).normalized()
	else:
		anchor = DIM;right = Vector3.RIGHT;forward = Vector3.BACK

func _enter_stage(stage: String) -> void :
	if stage == _stage: return
	_stage = stage
	var env: Environment = world.get("environment")
	var school: Node3D = world.school
	if is_instance_valid(dimension): dimension.process_mode = Node.PROCESS_MODE_INHERIT if stage == "void" else Node.PROCESS_MODE_DISABLED
	if stage == "void":
		if is_instance_valid(school): school.hide()
		dimension.show();yiero.show()
		world.camera.far = 1600.0
		if env:
			env.background_mode = Environment.BG_COLOR
			env.background_color = Color("070102")
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color("6a2a2a")
			env.ambient_light_energy = 0.42
			env.fog_enabled = true
			env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
			env.fog_light_color = Color("1c0506")
			env.fog_density = 0.0055
			env.fog_sky_affect = 0.0
			env.fog_height_density = 0.0
			env.fog_sun_scatter = 0.0
			env.glow_enabled = not bool(world.get("mobile_mode"))
			env.glow_hdr_threshold = 0.85
			env.glow_intensity = 0.85
			env.tonemap_exposure = 1.05
			env.adjustment_enabled = true
			env.adjustment_brightness = 1.0
			env.adjustment_contrast = 1.12
			env.adjustment_saturation = 0.95
	else:
		if is_instance_valid(dimension): dimension.hide()
		if is_instance_valid(yiero): yiero.hide()
		if is_instance_valid(_erase_light): _erase_light.visible = false
		if is_instance_valid(school): school.show()
		var interactables: Variant = world.get("map_interactables")
		if is_instance_valid(interactables) and is_instance_valid(interactables.get("exit_sign")): (interactables.exit_sign as Node3D).visible = stage == ""
		world.camera.far = _camera_far if stage == "" else maxf(_camera_far, 340.0)
		if world.has_method("_map_atmosphere"): world.call("_map_atmosphere")




func _speed_at(t: float) -> float:
	var speed: float = 1.0
	for row: Array in _slow:
		if t >= float(row[0]) and t < float(row[1]): speed = minf(speed, float(row[2]))
	return speed

func _scaled(t: float) -> float:
	var lost: float = 0.0
	for row: Array in _slow:
		var a: float = float(row[0])
		var b: float = float(row[1])
		if t <= a: continue
		lost += (minf(t, b) - a) * (1.0 - float(row[2]))
	return t - lost

func _step(t: float, silent: bool) -> void :
	_apply_frame(_stage_at(t))
	var dt: float = clampf(t - maxf(_time, 0.0), 0.0, 0.1) if _time >= 0.0 else 0.0
	var speed: float = _speed_at(t)
	for index: int in range(takes.size()):
		var take: Take = takes[index]
		while take.cursor < take.ops.size() and float(take.ops[take.cursor][0]) <= t:
			_run_op(index, take.ops[take.cursor])
			take.cursor += 1
		for ramp: Array in take.ramps:
			var start: float = float(ramp[0])
			var end: float = float(ramp[1])
			if t < start: continue
			var key: String = str(ramp[2])
			if t < end:
				take.state[key] = lerpf(float(ramp[3]), float(ramp[4]), (t - start) / maxf(0.001, end - start))
			elif _time < end:
				if is_zero_approx(float(ramp[4])): take.state.erase(key)
				else: take.state[key] = float(ramp[4])
		var spot: Vector3 = _world_spot(_where(take, t))
		var velocity: Vector3 = (spot - _world_spot(_where(take, t - 0.03))) / 0.03
		if velocity.length() > 40.0: velocity = Vector3.ZERO
		var visual: PaperVisual = take.visual
		visual.position = spot
		var target: float = _facing(index, take, t, velocity)
		if not take.yaw_ready or dt <= 0.0:
			take.yaw = target
			take.yaw_ready = true
		else:
			take.yaw = lerp_angle(take.yaw, target, 1.0 - exp( - dt * speed * 11.0))
		visual.rotation = Vector3(0.0, take.yaw, 0.0)
		if not take.emote.is_empty():
			take.emote_clock += dt * speed
			take.state["emote_id"] = take.emote
			take.state["emote_time"] = take.emote_clock
			if take.emote_clock > 2.6:
				take.emote = ""
				take.state.erase("emote_id")
				take.state.erase("emote_time")
		if visual.visible != take.shown: visual.visible = take.shown
		visual.set_combat_state(take.state)
		if (dt > 0.0 or _time < 0.0) and take.shown:
			visual.animate(maxf(dt * speed, 1.0 / 240.0), velocity * minf(1.0, speed * 4.0), take.stunned, take.phase)
			_post_pose(take)
	while _track_cursor < _track.size() and float(_track[_track_cursor][0]) <= t:
		if not silent: _run_cue(_track[_track_cursor])
		_track_cursor += 1
	_time = t


func _post_pose(take: Take) -> void :
	var pitch: float = float(take.state.get("look_up", 0.0))
	if absf(pitch) < 0.01: return
	var visual: PaperVisual = take.visual
	if not is_instance_valid(visual._head): return
	visual._head.rotation.x += pitch * 0.62
	if is_instance_valid(visual._neck): visual._neck.rotation.x += pitch * 0.38
	visual._sync_now()


func _spot(spec: Variant) -> Vector3:
	if spec is Dictionary and (spec as Dictionary).has("y"):
		var data: Dictionary = spec
		var at: Vector3 = yiero.socket(str(data.y)) if is_instance_valid(yiero) else anchor
		if data.has("h"): at += Vector3.UP * float(data.h)
		if data.has("o"): at += _world_direction(data.o)
		return at
	return super._spot(spec)


func _sound(sound: String, at: Vector3, gain: float = 1.0, pitch: float = 1.0) -> void :
	var audio: Variant = world.get("audio")
	if not audio: return
	var effects: Dictionary = audio.get("effects")
	var variants: Array = effects.get(sound, [])
	if variants.is_empty(): return
	_play_stream(variants[randi() % variants.size()], gain * 0.8, pitch * randf_range(0.97, 1.03))

func _on_cue(cue: String, visual: PaperVisual) -> void :
	if _silent or kind.is_empty() or not visual.visible: return
	var effects: Variant = world.get("presentation")
	if is_instance_valid(effects): effects.visual_fx(cue, visual)
	match cue:
		"step_l", "step_r":
			if _stage == "void": _sfx("sfx_ink_step", 0.65, randf_range(0.9, 1.1))
			else: _sound("step_floor", visual.global_position, 0.45)
		"land", "land_hard", "crack": _sound("ground_impact", visual.global_position, 0.5)

func _run_cue(cue: Array) -> void :
	var a: Variant = cue[2]
	var b: Variant = cue[3]
	var c: Variant = cue[4]
	var d: Variant = cue[5]
	var comic: Node = _comic()
	match str(cue[1]):
		"sfx": _sfx(str(a), float(b) if b != null else 1.0, float(c) if c != null else 1.0)
		"trail":
			if comic: comic.trail(takes[int(a)].visual, str(b), c if c is Color else GOLD, float(d) if d != null else 0.3, 0.18, 0.15)
		"bolts":
			if comic: comic.bolts(_spot(a), b if b is Color else GOLD, int(c) if c != null else 3, float(d) if d != null else 0.6)
		"whoosh":
			if comic: comic.whoosh(_spot(a), _world_direction(b), c if c is Color else PAPER, 6, float(d) if d != null else 1.6)
		"ink":
			if comic: comic.ink_puffs(_spot(a), int(b) if b != null else 6, float(c) if c != null else 3.0)
		"pluses":
			if comic: comic.pluses(_spot(a), int(b) if b != null else 3)
		"speak":
			var take: Take = takes[int(a)]
			take.visual.speak(float(b), float(c) if c != null else 1.0)
		_: super._run_cue(cue)




func _sfx(sound: String, gain: float = 1.0, pitch: float = 1.0) -> void :
	if _silent: return
	var stream: AudioStream = _sfx_streams.get(sound)
	if stream == null:
		var path: String = SFX_DIR + sound + ".wav"
		if not ResourceLoader.exists(path):
			var audio: Variant = world.get("audio")
			if audio and (audio.get("effects") as Dictionary).has(sound):
				_sound(sound, Vector3.ZERO, gain, pitch)
				return
			path = "res://audio/sfx/" + sound + ".wav"
		if not ResourceLoader.exists(path): return
		stream = load(path) as AudioStream
		_sfx_streams[sound] = stream
	_play_stream(stream, gain * (FILM_SFX_LEVEL if sound.begins_with("sfx_") else 1.0), pitch)

func _play_stream(stream: AudioStream, gain: float, pitch: float) -> void :
	var audio: Variant = world.get("audio")
	if not audio or bool(audio.get("muted")) or _sfx_players.is_empty(): return
	var volume: float = float(audio.get("effects_volume"))
	if volume <= 0.001: return
	var player: AudioStreamPlayer = _sfx_players[_next_sfx]
	_next_sfx = (_next_sfx + 1) % _sfx_players.size()
	player.stream = stream
	player.pitch_scale = clampf(pitch, 0.4, 2.0)
	# Bruitages du film : même dosage par rapport à la musique que le montage (PaperAudio.FILM_SFX_TRIM).
	player.volume_db = linear_to_db(maxf(0.0001, gain * PaperAudio.FILM_SFX_TRIM)) + float(audio.call("volume_to_db", volume))
	player.play()




func _key(track: String, t: float, value: Variant, ease_mode: String = "smooth") -> void :
	if not _keys.has(track): _keys[track] = []
	(_keys[track] as Array).append([t, value, ease_mode])

func _val(track: String, t: float, fallback: Variant) -> Variant:
	var rows: Array = _keys.get(track, [])
	if rows.is_empty(): return fallback
	if t <= float(rows[0][0]): return rows[0][1]
	for k: int in range(1, rows.size()):
		if t <= float(rows[k][0]):
			var from: Array = rows[k - 1]
			var to: Array = rows[k]
			var u: float = _ease((t - float(from[0])) / maxf(0.001, float(to[0]) - float(from[0])), str(to[2]))
			return lerp(from[1], to[1], u)
	return rows[rows.size() - 1][1]

func _f(track: String, t: float, fallback: float = 0.0) -> float:
	return float(_val(track, t, fallback))

func _v(track: String, t: float, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	var value: Variant = _val(track, t, fallback)
	return value if value is Vector3 else fallback

func _say(t: float, who: String, text: String, hold: float = 1.2, shout: bool = false, pace: float = 1.0) -> void :
	var speed: Dictionary = {"Simon": 34.0, "Ashura": 22.0, "Yiero": 12.0, "Usayuko": 30.0, "Elly": 24.0, "Bleuette": 26.0, "Lysia": 20.0, "Alice": 20.0}
	var cps: float = float(speed.get(who, 24.0)) * (1.25 if shout else 1.0) * pace
	var times: PackedFloat32Array = PackedFloat32Array()
	var clock_value: float = 0.0
	for i: int in range(text.length()):
		times.append(clock_value)
		var ch: String = text[i]
		clock_value += 1.0 / cps
		if ch in [",", ";"]: clock_value += 0.14
		elif ch in [".", "!", "?"] and (i + 1 >= text.length() or text[i + 1] == " "): clock_value += 0.26
		elif ch == "…": clock_value += 0.42
	_lines.append([t, who, text, t + clock_value + hold, shout, times])

func _flash(t: float, color: Color, hold: float, fade: float) -> void :
	_flashes.append([t, color, hold, fade])

func _ripple(t: float, local: Vector3, strength: float = 1.0) -> void :
	_ripples.append([t, local, strength])

func _spike(t_up: float, t_down: float, local: Vector3, yaw: float, size: float = 1.0) -> void :
	_spike_rows.append([t_up, t_down, local, yaw, size])

func _slowmo(t0: float, t1: float, factor: float) -> void :
	_slow.append([t0, t1, factor])

func _shock(t: float, local: Vector3, strength: float = 1.0) -> void :
	_shocks.append([t, local, strength])




func update(t: float, delta: float) -> void :
	if kind.is_empty() or takes.is_empty(): return
	t = clampf(t, 0.0, duration);caption = "";chapter = ""
	var jumped: bool = _last_t >= 0.0 and absf(t - _last_t) > 0.3
	if t < _time - 0.0005 or t - _time > 0.3: _jump(t)
	elif t > _time: _step(t, false)
	elapsed = t
	var stage: String = _stage_at(t)
	_enter_stage(stage)
	_apply_frame(stage)
	black = _black_at(t)
	_place_props(t)
	_pose_world(t, delta)
	_camera(t, delta)
	_update_glows(t)
	_update_overlay(t, delta, jumped)
	_update_music(t, delta, jumped or _last_t < 0.0)
	_last_t = t

func _black_at(t: float) -> float:
	if t < 4.6: return 1.0
	if t < 5.8: return 1.0 - smoothstep(4.6, 5.8, t)
	if t >= T_TITLE: return 1.0
	if t > T_TITLE - 0.25: return smoothstep(T_TITLE - 0.25, T_TITLE, t)
	return 0.0

func _camera(t: float, delta: float) -> void :
	_apply_frame(_stage_at(t))
	super._camera(t, delta)
	if _stage_at(t) == "void":
		var gold: float = maxf(_f("gold_s", t), _f("gold_a", t))
		var subject: Vector3 = takes[S].visual.global_position
		if takes[A].shown: subject = subject.lerp(takes[A].visual.global_position, 0.5)
		# Ashura tenu par la griffe (plans 108,8 → 117,6 sur lui seul) : les lumières le suivent.
		if takes[A].shown and t >= 108.8 and _f("held", t) > 0.5: subject = takes[A].visual.global_position
		var to_camera: Vector3 = world.camera.global_position - subject
		to_camera.y = 0.0
		to_camera = to_camera.normalized() if to_camera.length_squared() > 0.01 else Vector3.BACK
		rim.position = subject - to_camera * 2.4 + Vector3.UP * 2.3
		fill.position = subject + to_camera * 2.8 + to_camera.cross(Vector3.UP) * 1.6 + Vector3.UP * 1.5
		rim.light_color = Color(1.0, 0.36, 0.26);rim.light_energy = 1.8;rim.omni_range = 7.0;rim.light_specular = 0.2;fill.light_specular = 0.1
		fill.light_color = Color(0.62, 0.52, 0.86).lerp(GOLD_LIGHT, clampf(gold, 0.0, 1.0) * 0.6);fill.light_energy = 0.6 + gold * 0.25;fill.omni_range = 7.0
	else:
		rim.light_color = Color("d0dcec");rim.light_energy = 1.1;fill.light_energy = 0.78;rim.light_specular = 0.5;fill.light_specular = 0.5




func _pose_world(t: float, delta: float) -> void :
	var void_stage: bool = _stage_at(t) == "void"
	var scaled: float = _scaled(t)
	if void_stage:
		dimension.set_clock(scaled)
		var rows: Array = []
		for row: Array in _ripples:
			var age: float = t - float(row[0])
			if age < 0.0 or age > 5.0: continue
			var at: Vector3 = DIM + (row[1] as Vector3)
			rows.append(Vector4(at.x, at.z, _scaled(t) - _scaled(float(row[0])), float(row[2])))
		if rows.size() > VoidSet.RIPPLES: rows = rows.slice(rows.size() - VoidSet.RIPPLES)
		dimension.set_ripples(rows)
		var shock_age: float = -1.0
		var shock_at: Vector3 = DIM
		var shock_power: float = 0.0
		for row: Array in _shocks:
			var age: float = t - float(row[0])
			if age >= 0.0 and age < 6.0:
				shock_age = age;shock_at = DIM + (row[1] as Vector3);shock_power = float(row[2])
		dimension.set_shock(shock_at, shock_age, shock_power)
		dimension.set_storm(_f("storm", t), _f("lift", t))
		dimension.set_sky(_f("sky_storm", t), _f("sky_flash", t), _f("sky_dim", t, 1.0), _f("corona", t, 1.0))
		dimension.set_fog(_f("fog", t, 0.55))
		var spikes: Array = []
		for row: Array in _spike_rows:
			var up: float = smoothstep(float(row[0]), float(row[0]) + 0.22, t)
			var down: float = 1.0 - smoothstep(float(row[1]), float(row[1]) + 0.7, t)
			var amount: float = up * down
			if amount > 0.001: spikes.append([DIM + (row[2] as Vector3), amount, float(row[3]), float(row[4])])
		dimension.set_spikes(spikes)
		var door_open: float = _f("door", t)
		dimension.set_door(DIM + _v("door_at", t, Vector3(0, 0, -246)), 0.0, door_open)
		var env: Environment = world.get("environment")
		if env:
			env.ambient_light_energy = 0.42 * _f("sky_dim", t, 1.0)
			env.fog_density = 0.0055 * _f("fog_mul", t, 1.0)
		_pose_yiero(t, scaled)
		# Ashura pendu à la griffe : le placer AVANT l'effacement, qui lit sa position (base de la
		# dissolution, départ des lambeaux de papier).
		_update_held(t)
		_update_erase(t)
	else:
		_update_portal(t)
	_update_aura(t)
	_update_lysia(t)

func _pose_yiero(t: float, scaled: float) -> void :
	yiero.position = DIM + _v("y_pos", t, Vector3(0, 0, 80))
	yiero.rotation = Vector3(0, _f("y_yaw", t, PI), 0)
	yiero.rise = _f("rise", t, 0.8)
	yiero.reveal = _f("reveal", t, 0.0)
	yiero.eye_open = _f("eye_open", t, 0.0)
	yiero.eye_glow = _f("eye_glow", t, 1.0)
	yiero.grin = _f("grin", t, 0.0)
	yiero.grin_wide = _f("grin_wide", t, 1.0)
	var jaw: float = _f("jaw", t, 0.0)
	var line: Array = _line_at(t)
	if not line.is_empty() and str(line[1]) == "Yiero":
		var shown: int = _shown_count(line, t)
		if shown < str(line[2]).length(): jaw += 0.07 + 0.07 * absf(sin(t * 13.0))
	if _f("laugh", t) > 0.0: jaw += _f("laugh", t) * (0.12 + 0.12 * absf(sin(t * 15.0)))
	yiero.jaw = clampf(jaw, 0.0, 1.2)
	yiero.lean = _f("lean", t)
	yiero.head_pitch = _f("pitch", t)
	yiero.head_roll = _f("roll", t)
	yiero.head_yaw = _f("head_yaw", t)
	yiero.tremble = _f("tremble", t, 0.15)
	yiero.hurt = _f("hurt", t)
	yiero.fury = _f("fury", t)
	yiero.squint = _f("squint", t)
	yiero.wind = 1.0 + _f("storm", t) * 2.0
	yiero.tooth_chip = _f("chip", t)
	yiero.clock = scaled
	yiero.hand_target[0] = DIM + _v("hand_px", t, Vector3(40, -30, 60))
	yiero.hand_target[1] = DIM + _v("hand_nx", t, Vector3(-40, -30, 60))
	yiero.hand_curl[0] = _f("curl_px", t, 0.4)
	yiero.hand_curl[1] = _f("curl_nx", t, 0.4)
	var who: float = _f("look_who", t, 0.5)
	var simon: Vector3 = takes[S].visual.global_position + Vector3.UP * 1.4
	var ashura: Vector3 = takes[A].visual.global_position + Vector3.UP * 1.4
	yiero.look_target = simon.lerp(ashura, clampf(who, 0.0, 1.0))
	yiero.pose()

func _update_held(t: float) -> void :
	var held: float = _f("held", t)
	if held < 0.5 or not is_instance_valid(yiero) or not yiero.visible: return
	takes[A].visual.global_position = yiero.socket("pinch_l") + Vector3.DOWN * 1.72

func _update_glows(t: float) -> void :
	var void_stage: bool = _stage_at(t) == "void"
	for k: int in range(2):
		var take_index: int = [S, A][k]
		var power: float = _f("gold_s" if k == 0 else "gold_a", t)
		var flicker: float = 1.0 + 0.12 * sin(t * 23.0 + float(k)) + 0.08 * sin(t * 41.0)
		var visual: PaperVisual = takes[take_index].visual
		var shown: bool = power > 0.01 and visual.visible and takes[take_index].shown
		for side: int in range(2):
			var row: Array = _glows[k][side]
			var holder: Node3D = row[0]
			holder.visible = shown
			if not shown: continue
			holder.global_position = visual.socket_position("hand_r" if side == 0 else "hand_l")
			var size: float = (0.22 + power * 0.2) * flicker
			holder.scale = Vector3.ONE * size
			(row[1] as MeshInstance3D).material_override.set_shader_parameter("energy", power * 1.6 * flicker)
			(row[2] as OmniLight3D).light_energy = power * (2.4 if void_stage else 1.2) * flicker




func _update_erase(t: float) -> void :
	var progress: float = _f("erase", t)
	var fade: float = _f("erase_fade", t)
	var visual: PaperVisual = takes[A].visual
	_erase_light.visible = progress > 0.0 and progress < 1.0 and visual.visible
	if _erase_light.visible:
		_erase_light.global_position = visual.global_position + Vector3.UP * visual.visual_height() * clampf(progress * 1.25, 0.1, 1.0)
		_erase_light.light_energy = 2.2 * sin(PI * clampf(progress, 0.0, 1.0)) + 0.6
	if progress <= 0.0 and fade <= 0.0:
		_restore_erase()
		_flakes.hide()
		return
	if not _erasing:
		_erasing = true
		_erase_saved.clear();_erase_materials.clear()
		for mesh: MeshInstance3D in visual.get_render_meshes():
			for surface: int in range(mesh.mesh.get_surface_count()):
				var original: Material = mesh.get_surface_override_material(surface)
				_erase_saved.append([mesh, surface, original])
				var material: ShaderMaterial = ShaderMaterial.new();material.shader = _dissolve_shader()
				if original is ShaderMaterial:
					var source: ShaderMaterial = original
					var texture: Variant = source.get_shader_parameter("albedo_tex")
					if texture is Texture2D:
						material.set_shader_parameter("albedo_tex", texture)
						material.set_shader_parameter("textured", bool(source.get_shader_parameter("textured")))
					var color: Variant = source.get_shader_parameter("albedo_color")
					if color is Color: material.set_shader_parameter("albedo_color", color)
				mesh.set_surface_override_material(surface, material)
				_erase_materials.append(material)
	var base: float = visual.global_position.y
	for material: ShaderMaterial in _erase_materials:
		material.set_shader_parameter("progress", progress)
		material.set_shader_parameter("fade", fade)
		material.set_shader_parameter("base_y", base)
		material.set_shader_parameter("height", visual.visual_height())
	_flakes.visible = progress > 0.0 and progress < 1.0
	_flake_material.set_shader_parameter("progress", progress)
	_flake_material.set_shader_parameter("origin", visual.global_position)
	_flake_material.set_shader_parameter("target", yiero.socket("mouth"))
	_flake_material.set_shader_parameter("height", visual.visual_height())

var _dissolve: Shader
func _dissolve_shader() -> Shader:
	if _dissolve == null: _dissolve = _shader(DISSOLVE_SHADER)
	return _dissolve

func _restore_erase() -> void :
	if not _erasing: return
	_erasing = false
	for row: Array in _erase_saved:
		var mesh: MeshInstance3D = row[0]
		if is_instance_valid(mesh): mesh.set_surface_override_material(int(row[1]), row[2])
	_erase_saved.clear();_erase_materials.clear()

func _update_aura(t: float) -> void :
	var power: float = _f("aura", t)
	_aura.visible = power > 0.01 and _stage_at(t) == "school"
	if not _aura.visible: return
	var visual: PaperVisual = takes[U].visual
	_aura.global_position = visual.global_position
	_aura.rotation = Vector3(0, t * 0.4, 0)
	var pulse: float = 0.85 + 0.15 * sin(t * 7.0) + 0.1 * sin(t * 17.0)
	_flame_material.set_shader_parameter("clock", t)
	_flame_material.set_shader_parameter("power", power * pulse)
	_rune_material.set_shader_parameter("clock", t)
	_rune_material.set_shader_parameter("power", power * (0.9 + 0.1 * sin(t * 5.0)))
	for i: int in range(_aura_tags.size()):
		var tag: MeshInstance3D = _aura_tags[i]
		var a: float = t * 1.6 + float(i) / float(_aura_tags.size()) * TAU
		var radius: float = 0.95 + 0.1 * sin(t * 2.0 + float(i))
		tag.position = Vector3(cos(a) * radius, 1.05 + 0.35 * sin(t * 2.6 + float(i) * 1.7), sin(a) * radius)
		tag.rotation = Vector3(0.3 * sin(t * 3.0 + float(i)), - a + PI * 0.5, 0.25 * cos(t * 2.0 + float(i)))
		tag.scale = Vector3.ONE * power
	_aura_light.light_energy = power * 2.3 * pulse

func _update_portal(t: float) -> void :
	var open: float = _f("portal", t)
	_portal.visible = open > 0.002 and _stage_at(t) == "school"
	if not _portal.visible: return
	_portal.global_position = _world_spot(Vector3(-3.0, 1.75, -4.4))
	_portal.global_basis = Basis.looking_at(- forward, Vector3.UP)
	_portal_material.set_shader_parameter("open", open)
	_portal_material.set_shader_parameter("clock", t)
	_portal_material.set_shader_parameter("demon", _f("portal_demon", t))
	_portal_light.light_energy = open * 3.0

func _update_lysia(t: float) -> void :
	var power: float = _f("lysia_spark", t)
	_lysia_light.visible = power > 0.01 and _stage_at(t) == "school"
	if not _lysia_light.visible: return
	_lysia_light.global_position = takes[L].visual.global_position + Vector3.UP * 1.1
	var flicker: float = maxf(0.0, sin(t * 31.0) * sin(t * 13.0 + 1.0)) + (0.8 if fmod(t * 1.7, 1.0) < 0.08 else 0.0)
	_lysia_light.light_energy = power * flicker * 2.5




func _line_at(t: float) -> Array:
	var found: Array = []
	for line: Array in _lines:
		if float(line[0]) > t: break
		if t <= float(line[3]) + 0.25: found = line
	return found

func _shown_count(line: Array, t: float) -> int:
	var times: PackedFloat32Array = line[5]
	var local: float = t - float(line[0])
	var count: int = 0
	for i: int in range(times.size()):
		if times[i] <= local: count = i + 1
		else: break
	return count

func _update_overlay(t: float, delta: float, jumped: bool) -> void :
	if not _overlay_ready: return
	overlay.tick(delta)
	var ui: Variant = world.get("ui")
	if is_instance_valid(ui) and is_instance_valid(ui.get("film_layer")) and (ui.film_layer as Control).get_child_count() > 0:
		overlay.bar = ((ui.film_layer as Control).get_child(0) as Control).size.y
	var audio: Variant = world.get("audio")
	if audio:
		overlay.muted = bool(audio.get("muted"))
		overlay.volume = float(audio.get("effects_volume"))
		overlay.volume_db = float(audio.call("volume_to_db", overlay.volume)) + linear_to_db(PaperAudio.FILM_SFX_TRIM)
	var line: Array = _line_at(t)
	if line.is_empty():
		overlay.set_line("", "", 0, 0.0)
	else:
		var shown: int = _shown_count(line, t)
		var fade_in: float = smoothstep(float(line[0]) - 0.01, float(line[0]) + 0.12, t)
		var fade_out: float = 1.0 - smoothstep(float(line[3]), float(line[3]) + 0.25, t)
		overlay.set_line(str(line[1]), str(line[2]), shown, fade_in * fade_out, bool(line[4]))
		var key: int = _lines.find(line)
		var before: int = int(_blip_cursor.get(key, -1))
		if before < 0 or jumped or delta <= 0.0:
			_blip_cursor[key] = shown
		elif shown > before:
			_blip_cursor[key] = shown
			var text: String = str(line[2])
			var letter: bool = false
			for i: int in range(before, mini(shown, text.length())):
				var code: int = text.unicode_at(i)
				if (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or code > 191: letter = true
			if letter:
				var who: String = str(line[1])
				overlay.blip(who, bool(line[4]))
				var index: int = CAST.find(who)
				if index >= 0 and index < takes.size(): takes[index].visual.speak(0.16, 1.25 if bool(line[4]) else 0.9)
	var chapter_alpha: float = smoothstep(0.8, 1.8, t) * (1.0 - smoothstep(3.6, 4.5, t))
	overlay.set_chapter("Avant la première sonnerie…", chapter_alpha)
	var flash: Color = Color(0, 0, 0, 0)
	for row: Array in _flashes:
		var t0: float = float(row[0])
		if t < t0: continue
		var color: Color = row[1]
		var hold: float = float(row[2])
		var fade: float = float(row[3])
		var level: float = 1.0 if t < t0 + hold else 1.0 - smoothstep(t0 + hold, t0 + hold + fade, t)
		if level <= 0.0: continue
		var alpha: float = color.a * level
		if _flashes_reduced(): alpha *= 0.35
		if alpha > flash.a: flash = Color(color.r, color.g, color.b, alpha)
	overlay.set_flash(flash)
	var title: float = smoothstep(184.55, 184.7, t) * (1.0 - smoothstep(194.0, 195.6, t))
	var face: float = smoothstep(181.95, 182.6, t) * (1.0 - smoothstep(191.8, 194.4, t))
	var grin: float = smoothstep(182.8, 184.4, t)
	var sub_text: String = "Bienvenue dans votre nouvel enfer."
	var sub_start: float = 186.6
	var sub_shown: int = int(clampf((t - sub_start) * 12.5, 0.0, float(sub_text.length())))
	var sub_alpha: float = smoothstep(sub_start - 0.05, sub_start + 0.1, t) * (1.0 - smoothstep(194.0, 195.6, t))
	overlay.set_title(title, maxf(0.0, t - 184.6), face, grin, sub_text, sub_shown, sub_alpha, Vector2(sin(t * 0.7) * 0.4, 0.2))
	var sub_key: int = -7
	var sub_before: int = int(_blip_cursor.get(sub_key, -1))
	if sub_before < 0 or jumped or delta <= 0.0: _blip_cursor[sub_key] = sub_shown
	elif sub_shown > sub_before:
		_blip_cursor[sub_key] = sub_shown
		if sub_text[sub_shown - 1] != " ": overlay.blip("Yiero")

func _update_music(t: float, delta: float, jumped: bool) -> void :
	if not _music or not _music.stream: return
	var audio: Variant = world.get("audio")
	if audio:
		# 0.16 : le bus PaperMusic applique déjà le curseur Musique et MUSIC_LEVEL (même niveau que les
		# thèmes LMS) ; les appliquer aussi ici atténuait la musique deux fois (-25 dB au lieu de -12,5).
		_music.volume_db = -80.0 if bool(audio.get("muted")) or float(audio.get("music_volume")) <= 0.001 else 0.0
	var running: bool = delta > 0.0 and not paused and t < duration - 0.05
	if running:
		if not _music.playing: _music.play(t)
		elif jumped: _music.seek(t)
		elif AudioServer.get_driver_name() != "Dummy" and absf(_music.get_playback_position() - t) > 0.35: _music.seek(t)
		_music.stream_paused = false
	elif _music.playing:
		if jumped: _music.seek(t)
		_music.stream_paused = paused or delta <= 0.0
	if t >= duration - 0.05 and _music.playing: _music.stop()




func _write_prologue() -> void :
	for i: int in [U, AL, E, B, L]:
		_do(i, 0.0, "show", false)
		_do(i, T_SCHOOL, "show", true)
	_do(A, T_SCHOOL, "show", false)
	_write_void_intro()
	_write_apparition()
	_write_fight()
	_write_defeat()
	_write_chase()
	_write_school()
	_write_footsteps()


# Acte I — la dimension ténébreuse : marche prudente, suspense (0 → 30 s).
# Simon et Ashura sont joués par des clips écrits pour le film (anim_set_film_prologue_a.gd) : trajets,
# orientations, appuis et clips viennent de _pa_cast().
func _write_void_intro() -> void :
	_pa_begin()
	_pa_cast(0.0, 30.0)
	_key("gold_s", 0.0, 0.12);_key("gold_a", 0.0, 0.12)
	_cue(25.0, "sfx", "sfx_thump", 0.45);_cue(26.2, "sfx", "sfx_thump", 0.65);_cue(27.4, "sfx", "sfx_thump", 0.85)
	_cue(26.4, "sweat", {"a": S, "s": "head"}, 2)
	_say(17.6, "Simon", "C'est calme… beaucoup trop calme.", 0.9)
	_say(20.9, "Ashura", "Mes drones ne captent rien. Pas un seul écho.", 0.9)
	_say(26.8, "Simon", "Hé… T'as entendu ça ?", 0.8)

	_key("y_pos", 0.0, Vector3(0, 0, 84));_key("y_yaw", 0.0, PI);_key("rise", 0.0, 0.0);_key("rise", 28.6, 0.0);_key("rise", 30.0, 0.8);_key("reveal", 0.0, 0.0)
	_key("eye_open", 0.0, 0.0);_key("eye_open", 30.4, 0.0)
	_ripple(9.4, Vector3(-6, 0, 70), 6.0);_ripple(9.9, Vector3(5, 0, 74), 5.0);_cue(9.4, "sfx", "sfx_rumble", 1.5, 0.7)
	_key("sky_dim", 0.0, 0.62);_key("sky_dim", 24.0, 0.62);_key("sky_dim", 29.4, 0.13);_key("sky_dim", 40.2, 0.13);_key("sky_dim", 44.6, 1.0, "smooth")
	_key("corona", 0.0, 0.5);_key("corona", 24.0, 0.5);_key("corona", 29.0, 0.0);_key("corona", 40.2, 0.0);_key("corona", 44.6, 1.0, "smooth")
	_key("eye_glow", 0.0, 0.7);_key("grin", 0.0, 0.0);_key("jaw", 0.0, 0.0);_key("tremble", 0.0, 0.1)
	_key("hand_px", 0.0, Vector3(36, -30, 62));_key("hand_nx", 0.0, Vector3(-38, -30, 62))
	_key("curl_px", 0.0, 1.0);_key("curl_nx", 0.0, 1.0)
	_key("fog", 0.0, 0.55);_key("storm", 0.0, 0.0);_key("sky_storm", 0.0, 0.0)

	_shot(0.0, {"eye": [Vector3(-22, 21, -66), Vector3(-15, 9, -55)], "look": [Vector3(0, 7, 20), Vector3(0, 3, 6)], "fov": [50, 46], "hand": 0.2, "ease": "smooth", "safe": false})
	_shot(12.0, {"rel": {"a": S}, "eye": [Vector3(-2.7, 0.28, 1.0), Vector3(-2.5, 0.3, -0.6)], "look": {"a": S, "h": 0.3, "o": Vector3(1.3, 0, 0.4)}, "fov": 40, "hand": 0.3})
	_shot(17.0, {"rel": {"mid": [S, A]}, "eye": [Vector3(0.1, 1.45, 4.6), Vector3(0.05, 1.4, 3.4)], "look": {"mid": [S, A], "h": 1.25}, "fov": [40, 36], "hand": 0.3})
	_shot(24.0, {"rel": {"a": A}, "eye": [Vector3(0.7, 1.75, -1.4), Vector3(0.6, 1.72, -1.15)], "look": {"a": A, "h": 1.5, "o": Vector3(-1.4, 0, 12)}, "fov": [44, 40], "hand": 0.3})
	_shot(26.55, {"rel": {"a": S}, "eye": [Vector3(0.9, 1.42, -2.3), Vector3(0.75, 1.44, -2.0)], "look": {"a": S, "h": 1.36}, "fov": [36, 33], "hand": 0.4})


# Acte II — l'apparition de Yiero (30 → 59,45 s).
func _write_apparition() -> void :
	_pa_cast(30.0, 59.45)
	_shot(30.0, {"rel": {"a": S}, "eye": [Vector3(0.38, 1.05, -1.35), Vector3(0.32, 1.05, -1.15)], "look": {"a": S, "h": 1.18}, "fov": [36, 32], "hand": 0.25})
	_key("eye_open", 32.8, 1.0, "out");_key("eye_glow", 30.4, 0.55);_key("eye_glow", 33.2, 1.0)
	_cue(30.3, "sfx", "sfx_drop", 0.9)

	_shot(34.0, {"eye": [Vector3(0.6, 0.55, -19.5), Vector3(0.3, 0.5, -18.0)], "look": {"y": "eyes", "h": -7.0}, "fov": [46, 42], "hand": 0.25, "safe": false})
	_key("grin", 35.3, 0.0);_key("grin", 37.9, 0.45, "smooth");_key("grin", 38.12, 1.0, "out")
	_cue(38.0, "shake", 0.3);_key("tremble", 37.95, 0.1);_key("tremble", 38.06, 0.65, "out");_key("tremble", 39.6, 0.2)
	_say(36.0, "Yiero", "Hm hm hm… Deux petites lumières…", 0.6)
	_cue(35.3, "sfx", "sfx_creak", 0.8)

	_shot(40.0, {"eye": [Vector3(3.6, 0.9, -14.0), Vector3(4.2, 0.6, -13.0)], "look": [{"mid": [S, A], "h": 1.3}, {"y": "head", "h": 4.0}], "fov": [50, 60], "hand": 0.3, "ease": "smooth", "safe": false})
	_key("rise", 40.0, 0.8);_key("rise", 45.6, 1.0, "smooth")
	_key("reveal", 40.4, 0.0);_key("reveal", 44.2, 1.0, "smooth")
	_key("tremble", 40.0, 0.2);_key("tremble", 43.6, 0.9);_key("tremble", 46.5, 0.3)
	_key("hand_px", 40.8, Vector3(34, -14, 54));_key("hand_px", 44.4, Vector3(30, 6.0, 46), "out")
	_key("hand_nx", 41.4, Vector3(-36, -14, 56));_key("hand_nx", 45.0, Vector3(-29, 5.5, 45), "out")
	_key("curl_px", 42.4, 1.0);_key("curl_px", 44.6, 0.25);_key("curl_nx", 43.0, 1.0);_key("curl_nx", 45.2, 0.25)
	_cue(40.0, "sfx", "sfx_rumble", 1.4)
	for row: Array in [[40.5, 0.3], [42.6, 0.45], [43.4, 0.45], [44.6, 0.35]]: _cue(float(row[0]), "shake", float(row[1]))
	_cue(42.6, "sfx", "sfx_splash", 0.9);_cue(43.4, "sfx", "sfx_splash", 0.9, 0.85)
	_ripple(42.6, Vector3(-30, 0, 40), 4.0);_ripple(43.4, Vector3(29, 0, 40), 4.0)

	_shot(46.0, {"eye": [Vector3(-0.9, 0.14, -7.0), Vector3(-0.8, 0.16, -6.0)], "look": {"y": "face", "h": -3.0}, "fov": [64, 56], "hand": 0.3, "safe": false})
	_key("y_pos", 46.0, Vector3(0, 0, 84));_key("y_pos", 50.0, Vector3(0, 0, 70), "smooth")
	_key("pitch", 46.0, 0.0);_key("pitch", 50.0, 0.22);_key("lean", 46.0, 0.0);_key("lean", 50.0, 6.0)
	_say(46.4, "Yiero", "…perdues dans MA dimension.", 0.3)
	_key("jaw", 50.0, 0.0);_key("jaw", 50.32, 1.05, "out");_key("jaw", 51.7, 1.0);_key("jaw", 52.5, 0.22)
	_cue(50.05, "sfx", "sfx_roar", 1.25)
	_cue(50.2, "shake", 1.0);_cue(50.9, "shake", 0.6);_cue(50.2, "impact", 0.9, true);_cue(50.2, "pulse", Color(0.8, 0.04, 0.05, 0.42), 2.0)
	_shock(50.2, Vector3(0, 0, 62), 1.0)
	_key("storm", 50.2, 0.0);_key("storm", 50.7, 1.0, "out");_key("storm", 53.6, 0.0)
	_key("sky_storm", 50.2, 0.0);_key("sky_storm", 50.6, 1.0, "out");_key("sky_storm", 54.0, 0.3)
	_key("fury", 50.0, 0.0);_key("fury", 50.4, 0.8, "out");_key("fury", 53.0, 0.15)
	_key("sky_flash", 50.2, 0.0);_key("sky_flash", 50.35, 0.35, "out");_key("sky_flash", 51.2, 0.0)
	_key("tremble", 50.2, 0.9);_key("tremble", 52.6, 0.25)

	_shot(51.0, {"rel": {"mid": [S, A]}, "eye": [Vector3(0.5, 1.25, 3.5), Vector3(0.4, 1.3, 3.1)], "look": {"mid": [S, A], "h": 1.35}, "fov": [40, 37], "hand": 0.8})
	_say(52.4, "Ashura", "Simon. Les armes bénies. Maintenant.", 0.4)
	_shot(55.3, {"rel": {"a": S}, "eye": [Vector3(0.6, 1.42, 2.0), Vector3(0.55, 1.42, 1.8)], "look": {"a": S, "h": 1.36}, "fov": [36, 34], "hand": 0.5})
	_say(55.45, "Simon", "Ouais ! On le renvoie d'où il vient !", 0.5, true)
	_key("gold_s", 56.9, 0.12);_key("gold_s", 57.2, 1.0, "out");_key("gold_a", 56.95, 0.12);_key("gold_a", 57.25, 1.0, "out")
	_cue(56.85, "sfx", "sfx_ignite", 0.85)
	_flash(56.95, Color(1.0, 0.85, 0.4, 0.3), 0.05, 0.5)
	for i: int in [S, A]:
		_cue(57.0, "pillars", {"a": i}, GOLD, 5, 0.6)
		_cue(57.05, "sparkles", {"a": i, "s": "hand_r"}, GOLD, 3, 1.0)
	_cue(57.0, "shake", 0.35)
	_shot(56.75, {"rel": {"a": S}, "eye": [Vector3(1.0, 1.05, 1.5), Vector3(0.85, 1.1, 1.3)], "look": {"a": S, "s": "hand_r"}, "fov": [34, 30], "hand": 0.4})
	_shot(57.75, {"rel": {"mid": [S, A]}, "eye": [Vector3(-1.6, 0.45, 3.2), Vector3(-1.2, 0.5, 2.8)], "look": {"mid": [S, A], "h": 1.5}, "fov": [44, 41], "hand": 0.4})


# Acte III — le combat épique (59,45 → 104 s).
func _write_fight() -> void :
	_pa_cast(59.45, 104.0)
	_shot(59.45, {"rel": {"mid": [S, A]}, "eye": [Vector3(-2.4, 0.32, -3.2), Vector3(2.2, 0.42, -3.3)], "look": {"y": "head", "h": -9.0}, "fov": [52, 50], "hand": 0.3, "ease": "smooth"})
	_cue(59.45, "shake", 0.3)

	_key("hand_px", 60.6, Vector3(30, 6.0, 46));_key("hand_px", 62.35, Vector3(12, 30, 26), "smooth");_key("hand_px", 63.2, Vector3(1.5, 4.0, 4.0), "in")
	_key("hand_px", 64.6, Vector3(1.5, 4.0, 4.0));_key("hand_px", 66.2, Vector3(30, 6, 40), "smooth")
	_key("lean", 62.35, 6.0);_key("lean", 63.2, 13.0, "in");_key("lean", 64.6, 13.0);_key("lean", 66.4, 6.0, "smooth")
	_key("curl_px", 62.3, 0.25);_key("curl_px", 63.0, 0.05)
	_key("pitch", 61.0, 0.22);_key("pitch", 63.2, 0.32)
	_shot(61.9, {"eye": [Vector3(-12.0, 2.6, -21.0), Vector3(-11.0, 2.2, -20.0)], "look": [Vector3(1.0, 7.0, -4.0), Vector3(1.0, 3.0, -6.0)], "fov": [60, 56], "hand": 0.4, "safe": false})
	_cue(62.95, "sfx", "sfx_whoosh", 0.7)
	_cue(63.2, "sfx", "sfx_slam", 1.2);_cue(63.2, "shake", 0.9);_cue(63.2, "impact", 0.9, true)
	for row: Array in PROLOGUE_A.SLOW: _slowmo(float(row[0]), float(row[1]), float(row[2]))
	_shot(63.25, {"rel": {"a": S}, "eye": [Vector3(-2.2, 0.6, -2.4), Vector3(-2.3, 0.65, -2.6)], "look": Vector3(0.5, 2.0, -6.0), "fov": [50, 48], "hand": 0.6})

	_cue(65.55, "rush", 0.85);_cue(65.55, "sfx", "boost", 0.8);_cue(65.6, "trail", S, "hand_r", GOLD, 0.6);_cue(65.6, "trail", S, "hand_l", GOLD, 0.6)
	_shot(65.45, {"rel": {"a": S}, "eye": [Vector3(-4.4, 0.8, -0.8), Vector3(-4.2, 0.9, 0.6)], "look": {"a": S, "h": 1.0, "o": Vector3(0, 0, 0.9)}, "fov": 50, "hand": 0.8})
	_flights.append([68.6, 69.45, "grenade", {"a": S, "s": "hand_r"}, {"y": "eye_l"}, 3.0, 0.0])
	_cue(68.6, "sfx", "grenade_throw", 0.8)
	_shot(68.25, {"rel": {"a": S}, "eye": [Vector3(1.3, -0.4, -4.6), Vector3(1.2, 0.2, -4.0)], "look": {"y": "eye_l", "h": -9.0}, "fov": [50, 48], "hand": 0.5, "safe": false})
	_flash(69.45, Color(1.0, 0.94, 0.72, 0.7), 0.05, 0.35)
	_cue(69.45, "sfx", "flash", 1.0);_cue(69.6, "sfx", "sfx_growl", 1.1);_cue(69.45, "shake", 0.55)
	_key("squint", 69.45, 0.0);_key("squint", 69.55, 1.0, "out");_key("squint", 71.0, 1.0);_key("squint", 71.8, 0.0)
	_key("pitch", 69.45, 0.3);_key("pitch", 70.2, -0.12, "out");_key("pitch", 72.6, 0.15)
	_key("roll", 69.45, 0.0);_key("roll", 70.2, 0.18, "out");_key("roll", 72.6, 0.0)
	_key("hurt", 69.45, 0.0);_key("hurt", 69.5, 0.5, "out");_key("hurt", 70.4, 0.0)
	_key("y_pos", 69.5, Vector3(0, 0, 70));_key("y_pos", 70.5, Vector3(0, 0, 73), "out")
	_shot(69.5, {"rel": {"y": "eye_l"}, "eye": [Vector3(4.5, -1.5, -15.0), Vector3(4.0, -1.2, -13.5)], "look": {"y": "eye_l"}, "fov": [38, 34], "hand": 0.9, "safe": false})

	_shot(72.9, {"rel": {"a": A}, "eye": [Vector3(2.5, 0.5, -0.6), Vector3(2.7, 0.55, 1.2)], "look": {"a": A, "h": 0.9, "o": Vector3(0, 0, 0.6)}, "fov": 46, "hand": 0.7})
	_flights.append([74.7, 76.0, "drone", {"a": A, "s": "hand_r"}, {"y": "teeth"}, 2.0, 0.0])
	_cue(74.7, "sfx", "sfx_whoosh", 0.6, 1.3)
	_shot(74.85, {"eye": [Vector3(9.2, 2.3, 7.6), Vector3(9.0, 2.6, 8.2)], "look": {"y": "teeth"}, "fov": [36, 34], "hand": 0.5, "safe": false})
	_cue(76.0, "sfx", "ground_impact", 1.0);_cue(76.0, "sfx", "sfx_metal", 1.0);_cue(76.0, "shake", 0.4)
	_flash(76.0, Color(1.0, 0.88, 0.55, 0.3), 0.03, 0.3)
	_key("chip", 76.0, 0.001);_key("chip", 78.2, 0.999, "in")
	_key("hurt", 76.0, 0.0);_key("hurt", 76.05, 0.35);_key("hurt", 76.7, 0.0)
	_key("jaw", 76.0, 0.15);_key("jaw", 76.2, 0.35, "out");_key("jaw", 77.0, 0.1)
	_key("y_pos", 76.0, Vector3(0, 0, 73));_key("y_pos", 77.5, Vector3(0, 0, 76), "out")
	_say(75.1, "Simon", "Il recule ! Ashura, il recule !", 0.4, true)
	_shot(76.25, {"rel": {"a": S}, "eye": [Vector3(0.6, 1.42, 2.0), Vector3(0.55, 1.42, 1.8)], "look": {"a": S, "h": 1.36}, "fov": [36, 34], "hand": 0.4})
	_say(77.2, "Ashura", "Ensemble ! Vise la mâchoire !", 0.4, true)

	for i: int in [S, A]:
		_cue(77.9, "trail", i, "hand_r", GOLD, 1.2);_cue(78.3, "trail", i, "hand_l", GOLD, 1.0)
	_cue(77.9, "sfx", "sfx_whoosh", 1.0, 0.8);_cue(77.9, "rush", 1.0)
	_key("gold_s", 77.9, 1.0);_key("gold_s", 78.9, 1.5);_key("gold_s", 80.5, 1.0);_key("gold_a", 77.9, 1.0);_key("gold_a", 78.9, 1.5);_key("gold_a", 80.5, 1.0)
	_shot(77.75, {"rel": {"mid": [S, A]}, "eye": [Vector3(0.35, -1.0, -4.4), Vector3(0.25, -0.5, -3.2)], "look": {"y": "chin"}, "fov": [56, 48], "hand": 0.8, "safe": false})
	_flash(79.0, Color(1.0, 0.87, 0.45, 0.5), 0.05, 0.45)
	_cue(79.0, "sfx", "sfx_gold_hit", 1.3);_cue(79.0, "sfx", "punch", 1.0);_cue(79.0, "shake", 1.0);_cue(79.0, "impact", 1.0, false)
	_cue(79.02, "sparkles", {"y": "chin", "o": Vector3(0, 0, -2)}, GOLD, 14, 3.0);_cue(79.02, "pillars", {"y": "chin", "o": Vector3(0, -2, -3)}, GOLD, 9, 2.5)
	_key("pitch", 79.0, 0.16);_key("pitch", 80.5, -0.5, "out");_key("roll", 79.0, 0.0);_key("roll", 80.5, -0.25, "out")
	_key("jaw", 78.9, 0.15);_key("jaw", 79.05, 0.0, "in")
	_key("hurt", 79.0, 0.0);_key("hurt", 79.05, 0.45);_key("hurt", 80.4, 0.0)
	_key("y_pos", 79.0, Vector3(0, 0, 76));_key("y_pos", 81.0, Vector3(0, 0, 82), "out");_key("lean", 79.0, 6.0);_key("lean", 81.0, 0.0, "out")
	_key("tremble", 79.0, 0.9);_key("tremble", 81.5, 0.3)
	_cue(79.02, "word", "boom", {"y": "chin", "o": Vector3(0, 1.0, -3.0)}, GOLD, 2.4)
	_shot(79.4, {"eye": [Vector3(-27, 9, 30), Vector3(-26, 9.5, 31)], "look": {"y": "chin", "o": Vector3(0, -2, -5)}, "fov": [42, 40], "hand": 0.3, "safe": false})
	_cue(81.6, "sfx", "sfx_splash", 0.7)
	_shot(80.3, {"rel": {"mid": [S, A]}, "eye": [Vector3(4.5, 2.2, -7.0), Vector3(3.8, 1.4, -6.0)], "look": {"mid": [S, A], "h": 0.8}, "fov": [46, 42], "hand": 0.5, "safe": false})

	_key("pitch", 82.0, -0.5);_key("pitch", 85.2, 0.18, "smooth");_key("roll", 82.0, -0.25);_key("roll", 85.2, 0.12, "smooth")
	_key("laugh", 82.9, 0.0);_key("laugh", 83.3, 1.0);_key("laugh", 86.2, 1.0);_key("laugh", 86.6, 0.0)
	_key("grin_wide", 83.0, 1.0);_key("grin_wide", 86.6, 1.25, "smooth")
	_key("tremble", 83.0, 0.45)
	_say(83.0, "Yiero", "Ha… Ha ha ha ha. C'est tout ?", 0.4)
	_cue(83.0, "sfx", "sfx_laugh", 1.0)
	_shot(82.0, {"eye": [Vector3(-38, 54, 106), Vector3(-36, 52, 103)], "look": {"mid": [S, A], "h": 1.0}, "fov": [26, 24], "hand": 0.3, "safe": false})
	_shot(84.6, {"rel": {"y": "mouth"}, "eye": [Vector3(-7.0, -4.0, -24.0), Vector3(-5.5, -3.2, -20.0)], "look": {"y": "mouth"}, "fov": [42, 40], "hand": 0.4, "safe": false})

	_say(87.3, "Yiero", "Votre petite lumière… je vais l'ÉTEINDRE.", 0.4)
	_key("fury", 87.3, 0.15);_key("fury", 89.0, 1.0, "smooth");_key("eye_glow", 87.3, 1.0);_key("eye_glow", 89.0, 1.7)
	_key("sky_storm", 87.3, 0.3);_key("sky_storm", 89.5, 1.0);_key("sky_dim", 87.3, 1.0);_key("sky_dim", 89.5, 0.62);_key("fog_mul", 87.3, 1.0);_key("fog_mul", 89.5, 1.7)
	_key("gold_s", 87.5, 1.0);_key("gold_s", 88.1, 0.45);_key("gold_s", 88.4, 0.8);_key("gold_s", 88.9, 0.35);_key("gold_s", 89.5, 0.6)
	_key("gold_a", 87.6, 1.0);_key("gold_a", 88.2, 0.4);_key("gold_a", 88.6, 0.75);_key("gold_a", 89.1, 0.3);_key("gold_a", 89.6, 0.55)
	_key("grin_wide", 87.3, 1.25);_key("grin_wide", 90.0, 1.1)
	_key("y_pos", 87.0, Vector3(0, 0, 82));_key("y_pos", 91.6, Vector3(0, 0, 70), "smooth");_key("y_pos", 96.0, Vector3(0, 0, 78), "smooth");_key("y_pos", 103.5, Vector3(0, 0, 80), "smooth")
	_key("lean", 87.0, 0.0);_key("lean", 92.2, 5.0, "smooth");_key("lean", 96.5, 0.0, "smooth")
	_cue(87.3, "sfx", "sfx_rumble", 1.3, 0.8)
	_shot(87.0, {"eye": [Vector3(-9, 1.8, 24), Vector3(-8.0, 1.6, 25)], "look": {"y": "eyes"}, "fov": [50, 46], "hand": 0.3, "safe": false})
	var spikes: Array = [[89.2, Vector3(-6.0, 0, 36.0)], [89.45, Vector3(6.5, 0, 37.0)], [89.7, Vector3(-4.0, 0, 46.5)], [89.9, Vector3(5.0, 0, 45.5)]]
	for row: Array in spikes:
		var at: Vector3 = row[1]
		var yaw: float = atan2( - at.x, 40.25 - at.z)
		_spike(float(row[0]), 96.0, at, yaw, 1.0)
		_cue(float(row[0]), "sfx", "sfx_spike", 0.8, 0.9 + 0.07 * float(spikes.find(row)))
		_cue(float(row[0]), "shake", 0.3)
		_ripple(float(row[0]), at, 3.0)
	_shot(89.05, {"rel": {"mid": [S, A]}, "eye": [Vector3(-9.5, 1.5, 2.5), Vector3(-8.6, 1.4, 2.2)], "look": {"mid": [S, A], "h": 2.0}, "fov": [54, 50], "hand": 0.4, "safe": false})

	_key("hand_nx", 90.4, Vector3(-29, 5.5, 45));_key("hand_nx", 92.3, Vector3(-30, 8, 50), "smooth");_key("hand_nx", 92.9, Vector3(-4, 2, 40), "in");_key("hand_nx", 93.4, Vector3(12, 6, 34), "out");_key("hand_nx", 95.0, Vector3(-30, 4, 50), "smooth")
	_key("curl_nx", 92.2, 0.25);_key("curl_nx", 92.8, 0.6)
	_shot(92.0, {"rel": {"mid": [S, A]}, "eye": [Vector3(-6.5, 1.6, -1.4), Vector3(-6.0, 1.5, -1.0)], "look": {"mid": [S, A], "h": 1.2}, "fov": [46, 44], "hand": 0.6})
	_cue(92.9, "sfx", "hit", 1.0);_cue(92.9, "sfx", "sfx_slam", 0.8, 1.2);_cue(92.9, "shake", 0.8);_cue(92.9, "impact", 0.8, true)
	_cue(92.92, "pop", {"a": S, "h": 1.1}, Vector3(1, 0, 0), CRIMSON, 0.9)
	_ripple(93.85, Vector3(9.0, 0, 28.5), 2.5);_cue(93.85, "sfx", "sfx_splash", 0.6, 1.2);_ripple(94.6, Vector3(11.5, 0, 26.0), 1.2)
	_shot(92.82, {"rel": {"a": S}, "eye": [Vector3(0.3, 1.0, -4.2), Vector3(1.6, 0.9, -4.5)], "look": {"a": S, "h": 1.0}, "fov": [42, 46], "hand": 0.8})
	_say(93.6, "Ashura", "SIMON !", 0.6, true)
	_shot(93.55, {"rel": {"a": A}, "eye": [Vector3(1.6, 1.08, -0.8), Vector3(1.45, 1.1, -0.7)], "look": {"a": A, "h": 1.3}, "fov": [34, 31], "hand": 0.5})

	_cue(95.4, "event", "boost_charge", {"position": {"a": A}, "active": true})
	_cue(96.6, "event", "boost_release", {"position": {"a": A}, "level": 3});_cue(96.6, "sfx", "boost", 0.9)
	_shot(96.5, {"rel": {"a": A}, "eye": [Vector3(1.9, 0.42, 2.6), Vector3(2.0, 0.45, 1.2)], "look": {"a": A, "h": 1.0}, "fov": 46, "hand": 0.7})
	_key("hand_px", 96.6, Vector3(30, 6, 40));_key("hand_px", 97.8, Vector3(16, 24, 30), "smooth");_key("hand_px", 98.4, Vector3(8.5, 4.0, 15.5), "in")
	_key("curl_px", 97.7, 0.1)
	_cue(98.4, "sfx", "sfx_slam", 1.1, 0.9);_cue(98.4, "shake", 0.8)
	_shot(98.3, {"eye": [Vector3(13.6, 0.9, 24.4), Vector3(13.2, 1.0, 24.9)], "look": [{"a": A, "h": 1.0}, {"y": "hand_l"}], "fov": [48, 52], "hand": 0.7, "safe": false})
	_key("hand_px", 98.9, Vector3(8.5, 4.0, 15.5));_key("hand_px", 99.5, Vector3(7.4, 3.2, 17.8), "smooth")
	_key("curl_px", 99.2, 0.15);_key("curl_px", 99.6, 1.05, "out")
	_key("held", 0.0, 0.0);_key("held", 99.5, 0.0, "jump");_key("held", 99.51, 1.0, "jump");_key("held", 117.6, 1.0, "jump");_key("held", 117.61, 0.0, "jump")
	_cue(99.45, "sfx", "grab_00", 1.0);_cue(99.45, "shake", 0.5)
	_key("hand_px", 103.0, Vector3(4.0, 23.0, 46.0), "smooth")
	_key("look_who", 98.0, 0.0);_key("look_who", 99.6, 1.0)
	_key("pitch", 99.0, 0.18);_key("pitch", 103.0, 0.05)
	_say(100.1, "Yiero", "Toi, le petit observateur… Je vais t'effacer.", 0.4)
	_shot(99.55, {"eye": [Vector3(10.0, 2.0, 2.0), Vector3(9.5, 9.0, 6.0)], "look": [{"a": A, "h": 1.0}, {"y": "face", "h": -6.0}], "fov": [44, 52], "hand": 0.4, "ease": "smooth", "safe": false})
	_pa_contacts()


# --- prologue_a : acteurs écrits (anim_set_film_prologue_a.gd) ---------------------------------------
# Le jeu de Simon et d'Ashura de 0 à 104 s : trajets de la racine, cibles d'orientation, clips, appuis
# (anneaux dans l'encre et bruits de pas). Les corps sont « en l'air » pour le moteur (pas de démarche
# ni d'appuis automatiques) et ne suivent que les clips ; à 104 s, le lot prologue_b reprend.
const PROLOGUE_A = preload("res://anim_set_film_prologue_a.gd")

func _pa_begin() -> void :
	PROLOGUE_A.register()
	for i: int in [S, A]:
		var style: Variant = takes[i].visual.get("_style")
		if style is Dictionary: (style as Dictionary).merge(PROLOGUE_A.FILM_STYLE, true)
		_do(i, 0.0, "state", {"grounded": false})
		_do(i, PROLOGUE_A.HANDOFF, "unset", ["grounded"])
		takes[i].path = []
	if is_instance_valid(dimension): dimension.clear_steps()

func _pa_cast(t0: float, t1: float) -> void :
	var last: bool = t1 >= PROLOGUE_A.HANDOFF - 0.001
	for i: int in [S, A]:
		var actor: RefCounted = PROLOGUE_A.actor("Simon" if i == S else "Ashura")
		var path: Array = takes[i].path
		for row: Array in actor.root:
			var t: float = float(row[0])
			if t < t0 - 0.0001 or t > t1 + 0.0001 or (t > t1 - 0.0001 and not last): continue
			path.append([t, row[1], "linear"])
		if last:
			_spots[i] = PROLOGUE_A.root_at(actor, t1)
			if path.is_empty() or float(path[path.size() - 1][0]) < t1 - 0.0001: path.append([t1, _spots[i], "linear"])
		for row: Array in actor.aims:
			if float(row[0]) >= t0 - 0.0001 and float(row[0]) < t1 - 0.0001: _face(i, float(row[0]), "dir", PROLOGUE_A.dir_of(float(row[1])))
		for row: Array in actor.clips:
			if float(row[1]) >= t0 - 0.0001 and float(row[1]) < t1 - 0.0001: _do(i, float(row[1]), "play", str(row[0]))
		for row: Array in actor.falls:
			var t: float = float(row[0])
			if t < t0 - 0.0001 or t >= t1 - 0.0001: continue
			var power: float = float(row[3])
			var at: Vector3 = row[2]
			_cue(t, "sfx", "sfx_ink_step", 0.42 * clampf(power, 0.2, 1.6), 0.92 + 0.16 * absf(sin(t * 12.9898 + float(i) * 4.1)))
			if is_instance_valid(dimension): dimension.add_step(PROLOGUE_A.scaled(t), DIM + at, clampf(power, 0.2, 1.6))


# Les gestes de Yiero qui touchent les personnages sont calés sur le modèle lui-même : la cible de la
# main est corrigée jusqu'à ce que la prise voulue (pince, paume) tombe au bon endroit.
func _pa_solve(track: String, t: float, socket: String, want: Vector3) -> Vector3:
	var rows: Array = _keys[track]
	var row: Array = []
	for candidate: Array in rows:
		if absf(float(candidate[0]) - t) < 0.0005: row = candidate
	if row.is_empty(): return want
	for name_value: String in _keys: (_keys[name_value] as Array).sort_custom( func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	var target: Vector3 = row[1]
	for k: int in range(10):
		row[1] = target
		_pose_yiero(t, _scaled(t))
		var miss: Vector3 = want - (yiero.socket(socket) - DIM)
		if miss.length() < 0.04: break
		target += miss
	row[1] = target
	return yiero.socket(socket) - DIM

func _pa_contacts() -> void :
	var simon: RefCounted = PROLOGUE_A.actor("Simon")
	var ashura: RefCounted = PROLOGUE_A.actor("Ashura")
	# 63,2 : la griffe s'abat entre eux deux (là où ils couraient une seconde plus tôt).
	var claw: Vector3 = _pa_solve("hand_px", 63.2, "pinch_l", Vector3(-0.2, -0.6, -2.4))
	claw.y = 0.0
	_ripple(63.2, claw, 6.0);_cue(63.22, "ink", claw + Vector3(0, 0.4, 0), 10, 5.0);_cue(63.22, "dust_ring", claw + Vector3(0, 0.05, 0), 2.5)
	# 92,9 : le revers fauche Simon (paume sur son flanc).
	_pa_solve("hand_nx", 92.9, "hand_r", PROLOGUE_A.root_at(simon, 92.9) + Vector3(-0.9, 1.1, 0.3))
	# 98,4 : la main s'abat devant Ashura, entre lui et Simon ; 99,5 : la pince se referme sur lui.
	var from: Vector3 = PROLOGUE_A.root_at(ashura, 98.35)
	var ahead: Vector3 = (PROLOGUE_A.root_at(simon, 98.35) - from)
	ahead.y = 0.0
	var slam: Vector3 = from + ahead.normalized() * 3.2
	var hit: Vector3 = _pa_solve("hand_px", 98.4, "pinch_l", slam + Vector3(0, -0.4, 0))
	hit.y = 0.0
	_ripple(98.4, hit, 5.0);_cue(98.42, "ink", hit + Vector3(0, 0.4, 0), 10, 4.0)
	_pa_solve("hand_px", 99.5, "pinch_l", PROLOGUE_A.root_at(ashura, 99.5) + Vector3(0, 1.72, 0))


# Acte IV — la défaite : Ashura est effacé de la dimension (104 → 122 s).
func _write_defeat() -> void :
	_do(S, 103.8, "state", {"look_up": 0.55})
	_say(105.4, "Simon", "ASHURA ! Lâche-le !", 0.8, true)
	_shot(104.0, {"rel": {"a": S}, "eye": [Vector3(-0.6, 0.5, 1.6), Vector3(-0.5, 0.5, 1.35)], "look": {"a": S, "h": 0.5}, "fov": [38, 34], "hand": 0.4})
	_shot(106.9, {"rel": {"a": S}, "eye": [Vector3(0.7, 0.75, -1.5), Vector3(0.65, 0.8, -1.4)], "look": {"a": A, "h": 1.2}, "fov": [40, 36], "hand": 0.4, "safe": false})
	_do(A, 108.8, "stun", false);_do(A, 108.8, "state", {"carried_by": 0});_do(A, 108.8, "mood", "sad")
	_face(A, 108.8, "dir", Vector3(0.35, 0, -1))
	_say(109.4, "Ashura", "Simon… cours. Ne te retourne pas.", 1.0)
	_do(A, 111.6, "mood", "calm")
	_key("gold_a", 109.9, 0.55);_key("gold_a", 113.0, 0.0)
	_shot(109.0, {"rel": {"a": A}, "eye": [Vector3(-0.7, 0.9, -2.6), Vector3(-0.6, 0.95, -2.3)], "look": {"a": A, "h": 1.25}, "fov": [32, 29], "hand": 0.3, "safe": false})

	_key("erase_fade", 0.0, 0.0);_key("erase_fade", 113.0, 0.0);_key("erase_fade", 114.4, 1.0)
	_key("erase", 0.0, 0.0);_key("erase", 113.8, 0.0);_key("erase", 117.4, 1.0, "linear")
	_key("jaw", 113.8, 0.12);_key("jaw", 114.7, 0.55);_key("jaw", 117.6, 0.55);_key("jaw", 118.4, 0.1)
	_key("eye_glow", 113.5, 1.4);_key("eye_glow", 115.0, 2.0);_key("eye_glow", 118.0, 1.3)
	_cue(113.8, "sfx", "sfx_erase", 1.2)
	_cue(113.9, "pulse", Color(0.9, 0.85, 0.7, 0.25), 3.0)
	_do(A, 117.5, "show", false)
	_flights.append([114.3, 115.6, "drone", {"a": A, "s": "hand_r"}, Vector3(7.0, 0.1, 30.0), 0.5, 1.2])
	_key("curl_px", 117.4, 1.05);_key("curl_px", 118.2, 0.2)
	_key("hand_px", 117.6, Vector3(4.0, 23.0, 46.0));_key("hand_px", 120.0, Vector3(28, 4, 44), "smooth")
	_shot(113.5, {"rel": {"a": A}, "eye": [Vector3(3.6, 0.5, -1.9), Vector3(3.2, 0.6, -1.6)], "look": {"a": A, "h": 0.95}, "fov": [42, 40], "hand": 0.3, "safe": false})
	# Effacement vu en contre-plongée derrière Ashura : il se dissout au premier plan, la gueule béante
	# derrière lui avale les lambeaux. Coordonnées fixes (Ashura pend à la griffe vers (-5, 8,5, 48)).
	# Le plan dure jusqu'au cri de Simon : la gueule se referme sur le vide à 117,6.
	_shot(114.6, {"eye": [Vector3(-6.85, 8.2, 44.5), Vector3(-6.35, 8.55, 45.3)], "look": [Vector3(-3.8, 12.6, 55.4), Vector3(-3.6, 13.2, 56.0)], "fov": [50, 46], "hand": 0.3, "ease": "smooth", "safe": false})

	_do(S, 118.9, "mood", "pain")
	_say(119.2, "Simon", "ASHURAAA !", 1.0, true)
	_cue(119.3, "shake", 0.45)
	_shot(119.0, {"rel": {"a": S}, "eye": [Vector3(-0.4, 0.62, 1.6), Vector3(-0.35, 0.62, 1.4)], "look": {"a": S, "h": 0.52}, "fov": [34, 30], "hand": 0.5})


# Acte V — la course-poursuite, Acte VI — la porte de sortie (122 → 154 s).
func _write_chase() -> void :
	_say(122.2, "Yiero", "Un de moins. À ton tour, petite lumière.", 0.3)
	_key("look_who", 121.0, 0.0)
	_key("y_pos", 122.0, Vector3(0, 0, 82));_key("y_pos", 126.0, Vector3(0, 0, 60), "smooth")
	_key("pitch", 122.0, 0.05);_key("pitch", 126.0, 0.42);_key("rise", 122.0, 1.0);_key("rise", 126.0, 0.88)
	_key("lean", 122.0, 0.0);_key("lean", 126.0, 8.0);_key("jaw", 122.0, 0.1);_key("jaw", 126.0, 0.32)
	_key("fury", 122.0, 0.4);_key("eye_glow", 122.0, 1.4);_key("tremble", 122.0, 0.45)
	_shot(122.0, {"rel": {"a": S}, "eye": [Vector3(1.3, 1.7, -3.4), Vector3(1.1, 1.5, -3.0)], "look": {"y": "face", "h": -8.0}, "fov": [50, 48], "hand": 0.3, "safe": false})
	_do(S, 123.0, "life", "alive");_do(S, 123.0, "play", "recover");_do(S, 123.0, "mood", "panic");_do(S, 123.0, "unset", ["look_up"])
	_face(S, 123.0, "dir", Vector3(-0.2, 0, 1))
	_move(S, 123.6, 124.9, Vector3(11.3, 0, 23.6), "smooth")
	_do(S, 124.9, "state", {"speed_boost": 30.0, "chased": 3.0});_face(S, 124.9, "move")
	_do(S, 149.15, "unset", ["speed_boost", "chased"])
	var path: Array = [[126.0, Vector3(10.0, 0, 15.0), "in"], [131.0, Vector3(6.0, 0, -40.0), "linear"], [133.35, Vector3(4.6, 0, -66.0), "linear"], [133.75, Vector3(2.6, 0, -70.4), "linear"],
		[135.5, Vector3(2.0, 0, -93.0), "linear"], [140.0, Vector3(-1.0, 0, -142.0), "linear"], [144.5, Vector3(0.0, 0, -191.0), "linear"], [148.0, Vector3(0.0, 0, -229.0), "linear"], [149.2, Vector3(0.0, 0, -241.5), "linear"]]
	for row: Array in path: _move(S, float(takes[S].path[takes[S].path.size() - 1][0]), float(row[0]), row[1], str(row[2]))
	_do(S, 133.35, "trigger", "dodge", false);_cue(133.35, "sfx", "sfx_whoosh", 0.6)
	_cue(125.0, "sfx", "boost", 0.8);_cue(125.1, "rush", 0.8)
	_shot(124.9, {"rel": {"a": S}, "eye": [Vector3(-3.2, 1.2, -2.0), Vector3(-2.6, 1.1, -3.0)], "look": {"a": S, "h": 1.1}, "fov": 46, "hand": 0.7})
	_shot(126.0, {"rel": {"a": S}, "eye": [Vector3(0.35, 1.3, -4.4), Vector3(0.3, 1.32, -4.0)], "look": {"a": S, "h": 1.25}, "fov": [40, 38], "hand": 0.9})
	_say(127.0, "Simon", "Non non non non non…", 0.6)
	_shot(131.0, {"rel": {"a": S}, "eye": [Vector3(-5.6, 0.6, 0.6), Vector3(-5.5, 0.65, -0.4)], "look": {"a": S, "h": 1.0}, "fov": 46, "hand": 0.9})
	_shot(135.5, {"rel": {"a": S}, "eye": [Vector3(-30, 14, -26), Vector3(-28, 13, -24)], "look": {"a": S, "h": 4.0, "o": Vector3(0, 0, 22)}, "fov": [50, 48], "hand": 0.3, "safe": false})
	_say(136.0, "Yiero", "Cours ! COURS ! C'est tellement plus drôle !", 0.4, true)
	_shot(140.0, {"rel": {"a": S}, "eye": [Vector3(0.45, 0.5, 2.7), Vector3(0.4, 0.55, 2.4)], "look": {"a": S, "h": 1.0, "o": Vector3(0, 0, -30)}, "fov": [50, 48], "hand": 0.8})
	_say(141.0, "Simon", "Une porte… ?!", 0.8)
	_shot(144.5, {"rel": {"a": S}, "eye": [Vector3(0.3, 1.05, -2.9), Vector3(0.25, 1.05, -2.7)], "look": {"a": S, "h": 1.1}, "fov": [40, 38], "hand": 1.0})
	_say(144.8, "Yiero", "Tu ne m'échapperas JAMAIS.", 0.2)
	_cue(144.8, "pulse", Color(0.75, 0.02, 0.05, 0.42), 3.0);_cue(147.0, "pulse", Color(0.75, 0.02, 0.05, 0.42), 2.0)
	_cue(132.0, "shake", 0.45);_cue(133.6, "shake", 0.45);_cue(137.2, "shake", 0.35);_cue(138.4, "shake", 0.35)

	var chase_y: Array = [[126.0, 58.0], [131.0, 18.0], [135.5, -40.0], [140.0, -95.0], [144.5, -152.0], [148.0, -198.0], [150.6, -224.0]]
	for row: Array in chase_y: _key("y_pos", float(row[0]), Vector3(0, 0, float(row[1])), "linear")
	_key("y_pos", 152.0, Vector3(0, 0, -226.0), "out")
	_key("rise", 130.0, 0.86);_key("lean", 130.0, 10.0);_key("pitch", 130.0, 0.48)
	_key("jaw", 130.0, 0.4);_key("jaw", 140.0, 0.7);_key("jaw", 146.0, 1.0);_key("jaw", 150.42, 1.12);_key("jaw", 150.6, 0.0, "in");_key("jaw", 153.0, 0.0)
	_key("fury", 130.0, 0.7);_key("tremble", 130.0, 0.55);_key("eye_glow", 130.0, 1.5)
	_key("curl_px", 126.0, 0.5);_key("curl_nx", 126.0, 0.5)
	var step: float = 1.1
	var k: int = 0
	var t: float = 126.2
	while t < 150.0:
		for side: int in [0, 1]:
			var start: float = t + (0.55 if side == 1 else 0.0)
			var sx: float = 22.0 if side == 0 else -22.0
			var plant: Vector3 = Vector3(sx, 0.4, _chase_z(start) - 30.0)
			var track: String = "hand_px" if side == 0 else "hand_nx"
			_key(track, start, plant, "in")
			_key(track, start + 0.45, plant)
			_key(track, start + 0.8, Vector3(sx * 0.8, 11.0, _chase_z(start + 0.8) - 40.0), "out")
			if k % 2 == side:
				_cue(start, "sfx", "sfx_slam", 0.45, 1.25)
				_ripple(start, plant + Vector3(0, 0, -6.0), 3.0)
		t += step
		k += 1
	for row: Array in [[132.0, Vector3(3.5, 0, 3.0)], [133.6, Vector3(-2.8, 0, -1.0)], [137.2, Vector3(3.0, 0, 2.0)], [138.4, Vector3(-3.2, 0, 1.0)], [142.6, Vector3(3.4, 0, 3.5)]]:
		var at: Vector3 = _where(takes[S], float(row[0])) + (row[1] as Vector3)
		at.y = 0.0
		_spike(float(row[0]), float(row[0]) + 1.4, at, float(row[0]) * 1.7, 0.9)
		_cue(float(row[0]), "sfx", "sfx_spike", 0.9)
		_ripple(float(row[0]), at, 3.0)
		_cue(float(row[0]) + 0.02, "ink", {"a": S, "o": row[1] as Vector3, "h": 0.5}, 8, 4.0)
	_key("gold_s", 125.0, 0.3);_key("gold_s", 140.0, 0.25);_key("gold_s", 140.3, 1.15, "out");_key("gold_s", 142.5, 0.65);_key("gold_s", 150.6, 0.65);_key("gold_s", 150.7, 0.0, "jump")
	_cue(140.0, "event", "boost_release", {"position": {"a": S}, "level": 3});_cue(140.0, "sfx", "sfx_ignite", 0.7, 1.2);_cue(140.0, "rush", 1.0)
	_flash(140.0, Color(1.0, 0.85, 0.4, 0.25), 0.04, 0.35)
	_key("door_at", 0.0, Vector3(0, 0, -246.0));_key("door", 0.0, 0.0);_key("door", 140.5, 0.0);_key("door", 143.0, 1.0)

	_shot(148.0, {"rel": {"a": S}, "eye": [Vector3(0.6, 1.55, 2.3), Vector3(0.5, 1.5, 2.0)], "look": {"a": S, "h": 1.2, "o": Vector3(0, 0, -8)}, "fov": [46, 44], "hand": 0.9})
	_do(S, 149.2, "state", {"grounded": false, "vertical_speed": 3.0})
	_move(S, 149.2, 150.6, Vector3(0.0, 1.2, -245.3), "out")
	_slowmo(149.2, 150.6, 0.3)
	_shot(149.2, {"rel": {"a": S}, "eye": [Vector3(-5.6, 1.3, 3.6), Vector3(-5.4, 1.2, 3.0)], "look": {"a": S, "h": 0.9, "o": Vector3(0, 0, -1.0)}, "fov": [52, 50], "hand": 0.3, "safe": false})
	_do(S, 150.65, "show", false)
	_cue(150.55, "sfx", "sfx_chomp", 1.3);_cue(150.6, "shake", 1.0)
	_flash(150.62, Color(1, 1, 1, 1), 2.4, 1.2)
	_cue(153.2, "sfx", "bell_00", 0.9)


# Position z de Yiero pendant la poursuite (même tableau que les clés y_pos).
func _chase_z(t: float) -> float:
	var rows: Array = [[126.0, 58.0], [131.0, 18.0], [135.5, -40.0], [140.0, -95.0], [144.5, -152.0], [148.0, -198.0], [150.6, -224.0]]
	if t <= float(rows[0][0]): return float(rows[0][1])
	for i: int in range(1, rows.size()):
		if t <= float(rows[i][0]):
			return lerpf(float(rows[i - 1][1]), float(rows[i][1]), (t - float(rows[i - 1][0])) / (float(rows[i][0]) - float(rows[i - 1][0])))
	return float(rows[rows.size() - 1][1])


# Acte VII — l'école Paper Afterbell (153 → 182 s).
func _write_school() -> void :
	var t0: float = T_SCHOOL
	_move(S, t0, t0 + 0.02, Vector3(-3.0, 1.0, -4.0), "jump")
	_do(S, t0, "unset", ["grounded", "vertical_speed"])
	_do(S, t0, "state", {"grounded": false, "vertical_speed": -2.0})
	_face(S, t0, "dir", Vector3(0.15, 0, 1))
	_do(S, 154.2, "show", true)
	_move(S, 154.25, 154.9, Vector3(-2.5, 0, -2.4), "in")
	_do(S, 154.9, "unset", ["grounded", "vertical_speed"]);_do(S, 154.9, "state", {"landing_roll": 0.65});_ramp(S, 154.9, 155.55, "landing_roll", 0.65, 0.0)
	_do(S, 155.5, "life", "downed");_do(S, 155.5, "mood", "tired")
	_cue(154.9, "sfx", "ground_impact", 0.8)
	_key("portal", 0.0, 0.0);_key("portal", 153.3, 0.0);_key("portal", 153.9, 1.0, "out");_key("portal", 156.1, 1.0);_key("portal", 156.6, 0.0, "in")
	_key("portal_demon", 155.5, 0.0);_key("portal_demon", 155.8, 1.0);_key("portal_demon", 156.4, 1.0)
	_cue(156.1, "sfx", "sfx_portal", 0.9);_cue(155.5, "sfx", "sfx_growl", 0.6, 0.7)
	_shot(t0, {"eye": [Vector3(-0.3, 1.6, 2.6), Vector3(-0.4, 1.5, 2.2)], "look": Vector3(-2.8, 1.0, -3.4), "fov": [50, 48], "hand": 0.3})
	_shot(156.7, {"eye": [Vector3(-1.0, 0.7, 0.4), Vector3(-1.1, 0.7, 0.3)], "look": Vector3(-2.5, 0.4, -2.4), "fov": [42, 40], "hand": 0.3})

	_put(U, Vector3(0.8, 0, 2.6));_put(AL, Vector3(0.6, 0, 4.6))
	_face(U, 0.0, "at", AL);_face(AL, 0.0, "at", U)
	_do(U, 0.0, "mood", "grin");_do(AL, 0.0, "mood", "menace")
	_key("aura", 0.0, 0.0);_key("aura", t0, 1.0, "jump");_key("aura", 181.6, 1.0);_key("aura", 182.0, 0.0)
	_shot(157.4, {"eye": [Vector3(-1.6, 1.2, 0.0), Vector3(-1.5, 1.2, 0.1)], "look": [Vector3(-2.5, 0.5, -2.4), {"mid": [U, AL], "h": 1.2}], "fov": 44, "hand": 0.3, "ease": "dash"})
	_shot(157.7, {"eye": [Vector3(2.9, 0.45, 1.2), Vector3(2.7, 0.5, 1.6)], "look": {"mid": [U, AL], "h": 1.25}, "fov": [46, 44], "hand": 0.8})
	_move(AL, 157.45, 157.7, Vector3(0.7, 0, 3.7), "dash");_do(AL, 157.62, "trigger", "slash")
	_do(U, 157.3, "state", {"block": 1.0});_do(U, 158.25, "unset", ["block"])
	_cue(157.78, "event", "block", {"position": {"a": U}});_cue(157.78, "sound", "block", {"a": U});_do(U, 157.78, "play", "block_hit");_do(AL, 157.78, "hitstop", 0.12);_cue(157.78, "shake", 0.3)
	_cue(157.8, "bolts", {"a": U, "h": 1.3}, GOLD, 4, 0.7)
	_do(U, 158.3, "trigger", "contre");_blow(158.42, AL, U, "counter", GOLD, 1.25);_knock(AL, 158.42, 1.3, Vector3(0, 0, 1))
	_shot(158.9, {"rel": {"a": U}, "eye": [Vector3(0.55, 1.75, -1.1), Vector3(0.5, 1.7, -0.9)], "look": {"a": AL, "h": 1.25}, "fov": [42, 40], "hand": 0.6})
	_move(AL, 159.3, 159.55, Vector3(0.6, 0, 3.5), "dash");_do(AL, 159.48, "trigger", "slash")
	_move(U, 159.4, 159.6, Vector3(0.7, 0, 2.7), "dash");_do(U, 159.5, "trigger", "punch")
	_blow(159.62, AL, U, "punch", GOLD, 1.3);_knock(AL, 159.62, 1.6, Vector3(0, 0, 1));_stun(AL, 159.62, 0.8)
	_shot(160.4, {"eye": [Vector3(-4.6, 1.2, 3.9), Vector3(-4.3, 1.1, 4.1)], "look": {"mid": [U, AL], "h": 1.1}, "fov": [42, 40], "hand": 0.5})
	_move(AL, 160.6, 160.9, Vector3(0.6, 0, 3.6), "dash");_do(AL, 160.85, "trigger", "slash")
	_do(U, 160.6, "state", {"block": 1.0});_do(U, 161.4, "unset", ["block"])
	_cue(161.0, "event", "block", {"position": {"a": U}});_cue(161.0, "sound", "block", {"a": U});_do(U, 161.0, "play", "block_hit");_cue(161.0, "shake", 0.3)
	_cue(161.02, "bolts", {"a": U, "h": 1.3}, GOLD, 5, 0.8)
	_do(U, 161.9, "trigger", "dropkick");_move(U, 161.9, 162.2, Vector3(0.7, 0, 3.1), "dash")
	_blow(162.15, AL, U, "punch", GOLD, 1.6);_cue(162.15, "frame", Color(1, 1, 1, 0.18), 0.08);_knock(AL, 162.15, 3.6, Vector3(0, 0, 1));_stun(AL, 162.15, 2.1)
	_cue(162.15, "sfx", "sfx_gold_hit", 0.7, 1.2);_cue(162.55, "dust_ring", {"a": AL}, 1.1);_cue(162.6, "crack", {"a": AL}, 1.4)
	_slowmo(162.15, 162.55, 0.3)
	_shot(161.85, {"eye": [Vector3(2.3, 0.35, 2.9), Vector3(2.6, 0.45, 4.2)], "look": {"a": AL, "h": 1.0}, "fov": [52, 48], "hand": 0.8})
	_do(U, 162.7, "emote", "laugh");_do(U, 162.7, "mood", "laugh")
	_say(162.6, "Usayuko", "HA HA ! C'est tout ce que t'as, Alice ?!", 0.5, true)
	_shot(162.6, {"rel": {"a": U}, "eye": [Vector3(0.9, 1.55, 2.4), Vector3(0.85, 1.55, 2.2)], "look": {"a": U, "h": 1.5}, "fov": [34, 32], "hand": 0.4})
	_do(AL, 164.3, "play", "recover");_do(AL, 165.0, "trigger", "fury");_cue(165.6, "word", "roar", {"a": AL, "h": 2.4}, CRIMSON, 1.1);_cue(165.6, "sfx", "shadow", 0.7, 0.8)
	_shot(164.2, {"rel": {"a": AL}, "eye": [Vector3(-0.9, 1.25, -2.3), Vector3(-0.8, 1.3, -2.0)], "look": {"a": AL, "h": 1.33}, "fov": [38, 34], "hand": 0.4})
	var bolt_t: float = 157.0
	while bolt_t < 181.5:
		_cue(bolt_t, "bolts", {"a": U, "h": 1.2}, Color("ffe08a"), 2, 0.9)
		bolt_t += 0.75

	_put(B, Vector3(-5.6, 0, 4.2));_put(E, Vector3(-4.6, 0, 3.0))
	_face(B, 0.0, "at", E);_face(E, 0.0, "at", B)
	_do(B, t0, "state", {"second_life": true});_do(B, t0, "mood", "hurt")
	_do(B, 167.6, "play", "healed");_do(B, 169.0, "mood", "sad")
	_do(E, t0, "state", {"heal_time": 99.0});_do(E, t0, "mood", "focus")
	_cue(166.0, "event", "zone", {"position": {"a": B}, "radius": 2.6});_cue(166.0, "sfx", "heal", 0.8)
	var plus_t: float = 166.0
	while plus_t < 171.0:
		_cue(plus_t, "pluses", {"a": B, "h": 0.6}, 3)
		plus_t += 0.8
	_say(166.0, "Elly", "Tiens bon, Bleuette. Personne ne reste en arrière.", 0.3, false, 1.18)
	_say(169.05, "Bleuette", "J-je vais bien… je crois…", 0.3, false, 1.1)
	_shot(166.0, {"eye": [Vector3(-2.9, 1.25, 5.3), Vector3(-3.1, 1.2, 5.2)], "look": {"mid": [E, B], "h": 1.15}, "fov": [42, 40], "hand": 0.3})
	_shot(168.9, {"rel": {"a": B}, "eye": [Vector3(1.3, 1.2, -0.1), Vector3(1.2, 1.2, -0.05)], "look": {"a": B, "h": 1.15}, "fov": [32, 30], "hand": 0.3})

	_put(L, Vector3(6.0, 0, 5.6));_face(L, 0.0, "dir", Vector3(-1, 0, -0.2))
	_do(L, t0, "state", {"outlet_healing": 99.0, "second_life": true});_do(L, t0, "mood", "hurt")
	_key("lysia_spark", 0.0, 0.0);_key("lysia_spark", t0, 1.0, "jump");_key("lysia_spark", 181.6, 1.0);_key("lysia_spark", 181.7, 0.0)
	var spark_t: float = 155.0
	while spark_t < 181.0:
		_cue(spark_t, "bolts", {"a": L, "h": 1.15}, Color("9ff0ff"), 2, 0.5)
		spark_t += 0.55
	_cue(171.2, "event", "overheat", {"position": {"a": L}, "active": true})
	_say(171.22, "Lysia", "Armure à 40 %… Je tiens encore.", 0.3, false, 1.3)
	# Lysia à genoux, tête basse : elle relève la tête vers la caméra (basse, face à elle) pour parler.
	_do(L, 170.9, "state", {"look_up": 0.55});_do(L, 173.6, "unset", ["look_up"])
	_shot(171.1, {"rel": {"a": L}, "eye": [Vector3(-2.2, 0.55, 0.75), Vector3(-2.0, 0.56, 0.62)], "look": {"a": L, "h": 0.78}, "fov": [38, 36], "hand": 0.3})

	_face(U, 173.6, "at", S);_do(U, 173.6, "mood", "surprise");_do(U, 173.6, "emote", "")
	_say(173.72, "Usayuko", "SIMON ?! T'étais passé où, toi ?!", 0.4, true)
	_shot(173.65, {"rel": {"a": U}, "eye": [Vector3(-1.9, 1.55, -1.3), Vector3(-1.8, 1.55, -1.2)], "look": {"a": U, "h": 1.5}, "fov": [36, 34], "hand": 0.3})
	_do(S, 174.5, "life", "alive");_do(S, 174.5, "play", "recover");_do(S, 174.5, "mood", "tired");_face(S, 174.5, "at", U)
	_do(S, 175.7, "mood", "determined")
	_say(175.88, "Simon", "…Longue histoire. Je suis avec toi !", 0.3)
	_key("gold_s", 153.0, 0.0);_key("gold_s", 177.35, 0.0);_key("gold_s", 177.7, 0.9, "out");_key("gold_s", 178.9, 1.2);_key("gold_s", 179.0, 1.2)
	_cue(177.4, "sparkles", {"a": S, "s": "hand_r"}, GOLD, 6, 0.4);_cue(177.4, "sfx", "sfx_ignite", 0.55, 1.4)
	_shot(175.75, {"rel": {"a": S}, "eye": [Vector3(0.9, 1.32, 1.7), Vector3(0.85, 1.34, 1.5)], "look": {"a": S, "h": 1.36}, "fov": [34, 32], "hand": 0.3})
	_shot(177.3, {"rel": {"a": S}, "eye": [Vector3(0.75, 1.05, 1.1), Vector3(0.7, 1.05, 1.0)], "look": {"a": S, "s": "hand_r"}, "fov": [30, 28], "hand": 0.3})

	_face(AL, 177.6, "at", S)
	_do(S, 177.83, "state", {"speed_boost": 3.0});_face(S, 177.83, "move");_move(S, 177.88, 178.73, Vector3(0.1, 0, 6.4), "dash")
	_face(U, 178.03, "at", AL);_do(U, 178.03, "mood", "angry");_move(U, 178.08, 178.68, Vector3(1.5, 0, 7.2), "dash")
	_do(S, 178.68, "trigger", "flash punch");_do(U, 178.68, "trigger", "punch")
	_face(S, 178.63, "at", AL)
	_blow(178.95, AL, S, "punch", GOLD, 1.6)
	_flash(178.95, Color(1, 1, 1, 0.45), 0.04, 0.3)
	_cue(178.95, "sfx", "sfx_gold_hit", 1.0);_cue(178.95, "frame", Color(1, 1, 1, 0.22), 0.1)
	_slowmo(179.01, 181.7, 0.0)
	_flash(179.03, Color(1.0, 0.96, 0.86, 0.14), 2.55, 0.05)
	_shot(177.85, {"eye": [Vector3(-3.4, 0.5, 2.4), Vector3(-3.2, 0.55, 3.0)], "look": {"mid": [S, AL], "h": 1.1}, "fov": [50, 46], "hand": 0.6})
	_shot(178.83, {"eye": [Vector3(2.7, 0.65, 4.4), Vector3(2.8, 0.7, 4.6)], "look": {"a": AL, "h": 1.2}, "fov": [44, 42], "hand": 0.0})
	_cue(184.6, "sfx", "sfx_title", 1.2)
	_cue(190.4, "sfx", "sfx_laugh", 0.6, 0.85)


# Ondes dans l'encre sous les pas de Simon et d'Ashura.
func _write_footsteps() -> void :
	for i: int in [S, A]:
		var t: float = 4.2
		var side: float = 1.0
		while t < T_SCHOOL - 0.5:
			var here: Vector3 = _where(takes[i], t)
			var ahead: Vector3 = _where(takes[i], t + 0.1)
			var speed: float = (ahead - here).length() / 0.1
			var held_now: bool = i == A and t > 99.4 and t < 117.7
			if speed > 0.35 and here.y < 0.05 and not held_now:
				var lateral: Vector3 = Vector3.UP.cross((ahead - here).normalized()) * 0.12 * side
				_ripple(t, here + lateral, 0.55 if speed < 4.0 else 1.0)
				side = - side
			t += 0.48 if speed < 4.0 else 0.3
