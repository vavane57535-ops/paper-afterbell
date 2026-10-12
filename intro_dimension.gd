extends Node3D
class_name PaperIntroVoid

# Dimension ténébreuse du prologue (construite par code) : mer d'encre brillante avec ondes,
# ciel rouge-noir tourbillonnant avec éclipse, débris de papier en lévitation, nappes de brume,
# griffes d'encre qui jaillissent du sol, porte de lumière (sortie vers l'école).
# Tout est piloté par le film via des valeurs déterministes (clock, ondes, griffes…) : la
# cinémathèque peut avancer ou reculer sans état caché.

const FLOOR_SIZE: float = 1400.0
const RIPPLES: int = 12
const SPIKES: int = 10

const FLOOR_SHADER: String = """
shader_type spatial;
render_mode specular_schlick_ggx, cull_disabled;
uniform vec4 ink : source_color = vec4(0.014, 0.006, 0.009, 1.0);
uniform vec4 sky_low : source_color = vec4(0.5, 0.05, 0.035, 1.0);
uniform vec4 sky_high : source_color = vec4(0.06, 0.0, 0.012, 1.0);
uniform float clock = 0.0;
uniform vec4 ripples[12];
uniform int ripple_count = 0;
uniform vec4 shock = vec4(0.0, 0.0, -1.0, 0.0);
uniform float gloss = 1.0;
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz;
	float n1 = noise(p * 0.07 + vec2(clock * 0.025, clock * 0.012));
	float n2 = noise(p * 0.23 - vec2(clock * 0.04, -clock * 0.015));
	vec2 slope = vec2(n1 - 0.5, n2 - 0.5) * 0.1;
	float lit = 0.0;
	for (int i = 0; i < 12; i++) {
		if (i >= ripple_count) break;
		vec4 r = ripples[i];
		vec2 d = p - r.xy;
		float dist = length(d);
		float front = r.z * 4.5;
		float band = exp(-pow((dist - front) * 1.1, 2.0));
		float fade = r.w * exp(-r.z * 0.9) / (1.0 + dist * 0.12);
		float wave = sin((dist - front) * 5.0) * band * fade;
		slope += (d / max(dist, 0.001)) * wave * 0.7;
		lit += band * fade;
	}
	if (shock.z >= 0.0) {
		vec2 d = p - shock.xy;
		float dist = length(d);
		float front = shock.z * 38.0;
		float band = exp(-pow((dist - front) * 0.12, 2.0)) * exp(-shock.z * 0.5) * shock.w;
		slope += (d / max(dist, 0.001)) * sin((dist - front) * 0.8) * band * 0.8;
		lit += band * 0.6;
	}
	vec3 n = normalize(vec3(-slope.x, 1.0, -slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.5);
	vec3 refl = mix(sky_high.rgb, sky_low.rgb, fres);
	ALBEDO = ink.rgb;
	ROUGHNESS = 0.16;
	SPECULAR = 0.35;
	EMISSION = refl * fres * gloss * 0.9 + vec3(0.55, 0.09, 0.05) * lit * 0.3;
}
"""

const SKY_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, fog_disabled;
uniform vec4 horizon : source_color = vec4(0.42, 0.035, 0.03, 1.0);
uniform vec4 zenith : source_color = vec4(0.018, 0.0, 0.006, 1.0);
uniform vec4 glow_color : source_color = vec4(0.95, 0.16, 0.06, 1.0);
uniform vec3 sun_dir = vec3(0.0, 0.42, 1.0);
uniform float clock = 0.0;
uniform float storm = 0.0;
uniform float flash = 0.0;
uniform float dim = 1.0;
uniform float corona_power = 1.0;
varying vec3 dir;
float hash(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float noise(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float fbm(vec3 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; } return v; }
void vertex() { dir = VERTEX; }
void fragment() {
	vec3 d = normalize(dir);
	float h = d.y;
	vec3 col = mix(horizon.rgb, zenith.rgb, smoothstep(-0.08, 0.6, h));
	vec3 sd = normalize(sun_dir);
	vec3 axis = sd;
	float spin = clock * (0.006 + storm * 0.03);
	float c = cos(spin); float s = sin(spin);
	vec3 q = d * c + cross(axis, d) * s + axis * dot(axis, d) * (1.0 - c);
	float around = acos(clamp(dot(d, sd), -1.0, 1.0));
	float cloud = fbm(q * 3.2 + vec3(0.0, clock * 0.004, 0.0) + vec3(around * 2.0));
	float band = smoothstep(0.42, 0.72, cloud);
	col = mix(col, col * 0.22, band);
	col += glow_color.rgb * pow(smoothstep(0.58, 0.82, cloud), 2.0) * 0.18 * (1.2 - h);
	float sun = dot(d, sd);
	float corona = smoothstep(0.9, 0.9965, sun);
	col += glow_color.rgb * pow(corona, 6.0) * (0.9 + storm * 0.6) * corona_power;
	col += vec3(1.0, 0.6, 0.45) * smoothstep(0.9952, 0.9962, sun) * (1.0 - smoothstep(0.9962, 0.9972, sun)) * 2.2 * corona_power;
	col = mix(col, vec3(0.0), smoothstep(0.9962, 0.9968, sun));
	col += vec3(1.0, 0.86, 0.8) * flash * (0.25 + 0.75 * cloud);
	ALBEDO = col * dim;
}
"""

const DEBRIS_SHADER: String = """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap;
uniform float clock = 0.0;
uniform float storm = 0.0;
uniform vec3 storm_origin = vec3(0.0);
uniform float lift = 0.0;
varying vec4 tint;
varying vec2 uvp;
mat3 axis_rotation(vec3 axis, float a) {
	axis = normalize(axis); float s = sin(a); float c = cos(a); float oc = 1.0 - c;
	return mat3(vec3(oc * axis.x * axis.x + c, oc * axis.x * axis.y + axis.z * s, oc * axis.z * axis.x - axis.y * s),
		vec3(oc * axis.x * axis.y - axis.z * s, oc * axis.y * axis.y + c, oc * axis.y * axis.z + axis.x * s),
		vec3(oc * axis.z * axis.x + axis.y * s, oc * axis.y * axis.z - axis.x * s, oc * axis.z * axis.z + c));
}
void vertex() {
	vec4 cd = INSTANCE_CUSTOM;
	mat3 r = axis_rotation(vec3(sin(cd.x * 17.0), cos(cd.x * 5.0), 0.6), clock * cd.y + cd.x * 6.2831);
	VERTEX = r * VERTEX;
	NORMAL = r * NORMAL;
	vec3 world_origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 away = world_origin - storm_origin;
	away.y = 0.0;
	float dist = length(away);
	vec3 push = (away / max(dist, 0.01)) * storm * 9.0 * (1.0 + sin(cd.x * 40.0) * 0.3) + vec3(0.0, storm * 3.0 + lift * cd.z * 6.0, 0.0);
	vec3 bob = vec3(0.0, sin(clock * 0.45 + cd.x * 30.0) * cd.z, cos(clock * 0.31 + cd.x * 11.0) * cd.z * 0.4);
	mat3 inv = inverse(mat3(MODEL_MATRIX[0].xyz, MODEL_MATRIX[1].xyz, MODEL_MATRIX[2].xyz));
	VERTEX += inv * (push + bob);
	tint = COLOR;
	uvp = UV;
}
void fragment() {
	float edge = max(abs(uvp.x - 0.5), abs(uvp.y - 0.5)) * 2.0;
	vec3 col = tint.rgb;
	ALBEDO = col;
	ROUGHNESS = 0.95;
	EMISSION = col * 0.06 + vec3(1.0, 0.32, 0.06) * tint.a * smoothstep(0.75, 1.0, edge) * 1.6;
}
"""

const FOG_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform vec4 tint : source_color = vec4(0.32, 0.07, 0.07, 1.0);
uniform float density = 0.5;
uniform float clock = 0.0;
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], MODEL_MATRIX[1], vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, MODEL_MATRIX[1].xyz)), 0.0), MODEL_MATRIX[3]);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 uv = UV;
	float n = noise(vec2(uv.x * 4.0 + clock * 0.05 + wpos.x * 0.01, uv.y * 2.0)) * 0.6 + noise(vec2(uv.x * 9.0 - clock * 0.08, uv.y * 5.0 + clock * 0.03)) * 0.4;
	float shape = smoothstep(0.0, 0.25, uv.x) * smoothstep(1.0, 0.75, uv.x) * smoothstep(1.0, 0.35, uv.y) * smoothstep(0.0, 0.12, uv.y);
	ALBEDO = tint.rgb;
	ALPHA = clamp(shape * n * density, 0.0, 1.0);
}
"""

const DOOR_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float open = 0.0;
uniform float clock = 0.0;
void fragment() {
	vec2 c = UV - vec2(0.5);
	float core = 1.0 - smoothstep(0.0, 0.7, length(c * vec2(1.6, 0.9)));
	float flicker = 0.92 + 0.08 * sin(clock * 9.0 + UV.y * 20.0);
	vec3 col = mix(vec3(1.0, 0.78, 0.45), vec3(1.0, 0.97, 0.9), core) * (1.6 + core * 2.4) * flicker;
	ALBEDO = col * open;
}
"""

const RAY_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, fog_disabled;
uniform float open = 0.0;
uniform float clock = 0.0;
void fragment() {
	float along = UV.y;
	float across = abs(UV.x - 0.5) * 2.0;
	float stripes = 0.6 + 0.4 * sin(UV.x * 40.0 + clock * 0.7) * sin(UV.x * 13.0 - clock * 0.4);
	float a = (1.0 - along) * (1.0 - across * across) * stripes * open * 0.35;
	ALBEDO = vec3(1.0, 0.82, 0.55) * a;
}
"""

const CLAW_SHADER: String = """
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
uniform vec4 rim_color : source_color = vec4(0.7, 0.1, 0.05, 1.0);
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.25;
	SPECULAR = 0.8;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	EMISSION = rim_color.rgb * fres * 0.7 + COLOR.rgb * 0.08;
}
"""

var floor_material: ShaderMaterial
var sky_material: ShaderMaterial
var debris_material: ShaderMaterial
var fog_material: ShaderMaterial
var door_material: ShaderMaterial
var ray_material: ShaderMaterial
var door: Node3D
var door_light: OmniLight3D
var back_light: DirectionalLight3D
var fill_light: DirectionalLight3D
var sky: MeshInstance3D
var _spikes: Array[Node3D] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _built: bool = false

func build() -> void :
	if _built: return
	_built = true
	_rng.seed = 1313
	_build_floor()
	_build_sky()
	_build_debris()
	_build_fog()
	_build_ruins()
	_build_door()
	_build_spikes()
	_build_lights()

func _shader(code: String) -> Shader:
	var shader: Shader = Shader.new()
	shader.code = code
	return shader

func _mesh_node(mesh: Mesh, material: Material, label: String, parent: Node3D = null) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = label;node.mesh = mesh;node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else self).add_child(node)
	return node

func _build_floor() -> void :
	floor_material = ShaderMaterial.new();floor_material.shader = _shader(FLOOR_SHADER)
	var plane: PlaneMesh = PlaneMesh.new();plane.size = Vector2(FLOOR_SIZE, FLOOR_SIZE);plane.subdivide_width = 8;plane.subdivide_depth = 8
	var node: MeshInstance3D = _mesh_node(plane, floor_material, "InkSea")
	node.position = Vector3(0, 0, -120)
	node.extra_cull_margin = 50.0
	var body: StaticBody3D = StaticBody3D.new();body.name = "InkFloor";add_child(body);body.collision_layer = 1;body.collision_mask = 0
	var shape: CollisionShape3D = CollisionShape3D.new();body.add_child(shape)
	var box: BoxShape3D = BoxShape3D.new();box.size = Vector3(FLOOR_SIZE, 1.0, FLOOR_SIZE);shape.shape = box
	body.position = Vector3(0, -0.5, -120)

func _build_sky() -> void :
	sky_material = ShaderMaterial.new();sky_material.shader = _shader(SKY_SHADER)
	var sphere: SphereMesh = SphereMesh.new();sphere.radius = 900.0;sphere.height = 1800.0;sphere.radial_segments = 48;sphere.rings = 24
	sky = _mesh_node(sphere, sky_material, "Sky")
	sky.extra_cull_margin = 2000.0

func _build_debris() -> void :
	debris_material = ShaderMaterial.new();debris_material.shader = _shader(DEBRIS_SHADER)
	var quad: QuadMesh = QuadMesh.new();quad.size = Vector2(1.0, 1.0)
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	var count: int = 1100
	multimesh.instance_count = count
	for i: int in range(count):
		var big: bool = i % 18 == 0
		var near_path: bool = i % 3 != 0
		var x: float = _rng.randf_range(-24.0, 24.0) if near_path else _rng.randf_range(-170.0, 170.0)
		var z: float = _rng.randf_range(-330.0, 120.0)
		var y: float = _rng.randf_range(0.6, 9.0) if near_path else _rng.randf_range(1.0, 70.0)
		if big:
			y = _rng.randf_range(8.0, 60.0);x = _rng.randf_range(-160.0, 160.0)
			# Pas de grands débris devant le visage de Yiero ni entre lui et les élèves (plans de révélation).
			if absf(x) < 48.0 and z > -60.0: x = signf(x + 0.01) * (48.0 + fmod(absf(x) * 7.3, 110.0))
		elif near_path and y > 2.4 and absf(x) < 9.0 and z > -26.0 and z < 72.0:
			# Couloir caméra → visage de Yiero dégagé au-dessus des têtes (les débris proches de l'objectif
			# masquaient le visage pendant la révélation).
			x = signf(x + 0.01) * (9.0 + fmod(absf(x) * 5.1, 15.0))
		var size: float = _rng.randf_range(0.18, 0.75) if not big else _rng.randf_range(3.0, 8.0)
		var basis: Basis = Basis.from_euler(Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU)).scaled(Vector3(size, size * _rng.randf_range(0.7, 1.35), size))
		multimesh.set_instance_transform(i, Transform3D(basis, Vector3(x, y, z)))
		var roll: float = _rng.randf()
		var color: Color = Color(0.86, 0.8, 0.68, 0.0) if roll < 0.35 else Color(0.05, 0.03, 0.03, 0.0) if roll < 0.75 else Color(0.32, 0.12, 0.08, 1.0)
		if roll >= 0.35 and roll < 0.75 and _rng.randf() < 0.3: color.a = 1.0
		multimesh.set_instance_color(i, color)
		multimesh.set_instance_custom_data(i, Color(_rng.randf(), _rng.randf_range(0.2, 1.1) * (0.4 if big else 1.0), _rng.randf_range(0.2, 1.4), 0.0))
	var node: MultiMeshInstance3D = MultiMeshInstance3D.new();node.name = "Debris";node.multimesh = multimesh
	node.material_override = debris_material;node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = 60.0
	add_child(node)

func _build_fog() -> void :
	fog_material = ShaderMaterial.new();fog_material.shader = _shader(FOG_SHADER)
	for i: int in range(46):
		var quad: QuadMesh = QuadMesh.new()
		var w: float = _rng.randf_range(40.0, 90.0)
		var h: float = _rng.randf_range(7.0, 16.0)
		quad.size = Vector2(w, h)
		var node: MeshInstance3D = _mesh_node(quad, fog_material, "Fog")
		var x: float = _rng.randf_range(-140.0, 140.0)
		var z: float = _rng.randf_range(-340.0, 160.0)
		if absf(x) < 18.0 and i % 2 == 0: x = 18.0 * signf(x + 0.01) + x
		node.position = Vector3(x, h * 0.42 - 1.0, z)
		node.sorting_offset = -2.0

func _paper_box(parent: Node3D, size: Vector3, at: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var box: BoxMesh = BoxMesh.new();box.size = size
	var mat: StandardMaterial3D = StandardMaterial3D.new();mat.albedo_color = color;mat.roughness = 0.95
	var node: MeshInstance3D = _mesh_node(box, mat, "Ruin", parent)
	node.position = at;node.rotation = rot
	return node

func _build_ruins() -> void :
	var root: Node3D = Node3D.new();root.name = "Ruins";add_child(root)
	for i: int in range(26):
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var x: float = side * _rng.randf_range(16.0, 75.0)
		var z: float = _rng.randf_range(-320.0, 60.0)
		var h: float = _rng.randf_range(6.0, 26.0)
		var lean: Vector3 = Vector3(_rng.randf_range(-0.25, 0.25), _rng.randf() * TAU, _rng.randf_range(-0.3, 0.3))
		var pillar: MeshInstance3D = _paper_box(root, Vector3(_rng.randf_range(1.6, 3.4), h, _rng.randf_range(1.6, 3.4)), Vector3(x, h * 0.42, z), Color(0.08, 0.05, 0.05), lean)
		if _rng.randf() < 0.5:
			_paper_box(root, Vector3(_rng.randf_range(2.0, 4.0), 0.2, _rng.randf_range(2.0, 4.0)), Vector3(x + _rng.randf_range(-3, 3), h * 0.85 + _rng.randf_range(2.0, 6.0), z), Color(0.75, 0.69, 0.58), Vector3(_rng.randf(), _rng.randf() * TAU, _rng.randf()))
	for i: int in range(14):
		var desk: Node3D = Node3D.new();root.add_child(desk)
		desk.position = Vector3(_rng.randf_range(-60.0, 60.0), _rng.randf_range(4.0, 22.0), _rng.randf_range(-300.0, 80.0))
		if absf(desk.position.x) < 12.0: desk.position.x += 24.0 * signf(desk.position.x + 0.01)
		desk.rotation = Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU)
		_paper_box(desk, Vector3(2.2, 0.14, 1.3), Vector3.ZERO, Color(0.36, 0.24, 0.16))
		for leg: Vector3 in [Vector3(-0.95, -0.6, -0.5), Vector3(0.95, -0.6, -0.5), Vector3(-0.95, -0.6, 0.5), Vector3(0.95, -0.6, 0.5)]:
			_paper_box(desk, Vector3(0.1, 1.2, 0.1), leg, Color(0.12, 0.1, 0.1))

func _build_door() -> void :
	door = Node3D.new();door.name = "ExitDoor";add_child(door)
	door_material = ShaderMaterial.new();door_material.shader = _shader(DOOR_SHADER)
	ray_material = ShaderMaterial.new();ray_material.shader = _shader(RAY_SHADER)
	var frame_color: Color = Color(0.94, 0.9, 0.82)
	_paper_box(door, Vector3(0.45, 4.6, 0.5), Vector3(-1.45, 2.3, 0), frame_color)
	_paper_box(door, Vector3(0.45, 4.6, 0.5), Vector3(1.45, 2.3, 0), frame_color)
	_paper_box(door, Vector3(3.35, 0.45, 0.5), Vector3(0, 4.6, 0), frame_color)
	var sign: Label3D = Label3D.new();door.add_child(sign);sign.text = "SORTIE";sign.position = Vector3(0, 5.2, 0.3);sign.font_size = 64;sign.pixel_size = 0.012;sign.modulate = Color(1.0, 0.92, 0.75)
	var quad: QuadMesh = QuadMesh.new();quad.size = Vector2(2.5, 4.2)
	var glow: MeshInstance3D = _mesh_node(quad, door_material, "Light", door);glow.position = Vector3(0, 2.15, 0)
	for i: int in range(5):
		var ray: QuadMesh = QuadMesh.new();ray.size = Vector2(3.6 + i * 1.6, 26.0)
		var node: MeshInstance3D = _mesh_node(ray, ray_material, "Ray", door)
		node.position = Vector3(0, 2.0, 13.0)
		node.rotation = Vector3(PI * 0.5, 0, float(i) * 0.6)
	door_light = OmniLight3D.new();door.add_child(door_light);door_light.position = Vector3(0, 2.5, 3.0);door_light.light_color = Color("ffd9a0");door_light.omni_range = 30.0;door_light.light_energy = 0.0

func _build_spikes() -> void :
	var material: ShaderMaterial = ShaderMaterial.new();material.shader = _shader(CLAW_SHADER)
	for i: int in range(SPIKES):
		var st: SurfaceTool = SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var sides: int = 6
		var rings: int = 7
		var grid: Array = []
		for r: int in range(rings + 1):
			var v: float = float(r) / float(rings)
			var radius: float = lerpf(1.6, 0.05, pow(v, 0.8))
			var bend: float = v * v * 3.0
			var row: Array[Vector3] = []
			for s: int in range(sides):
				var a: float = float(s) / float(sides) * TAU
				row.append(Vector3(cos(a) * radius, v * 14.0, sin(a) * radius + bend))
			grid.append(row)
		for r: int in range(rings):
			for s: int in range(sides):
				var a: Vector3 = grid[r][s]
				var b: Vector3 = grid[r][(s + 1) % sides]
				var c: Vector3 = grid[r + 1][s]
				var d: Vector3 = grid[r + 1][(s + 1) % sides]
				var col: Color = Color(0.03, 0.012, 0.012).lerp(Color(0.85, 0.78, 0.6), smoothstep(0.75, 1.0, float(r) / float(rings)))
				for tri: Array in [[a, c, b], [b, c, d]]:
					var n: Vector3 = ((tri[1] as Vector3) - (tri[0] as Vector3)).cross((tri[2] as Vector3) - (tri[0] as Vector3)).normalized()
					for p: Vector3 in [tri[0], tri[2], tri[1]]:
						st.set_color(col);st.set_normal(n);st.add_vertex(p)
		var holder: Node3D = Node3D.new();add_child(holder)
		_mesh_node(st.commit(), material, "Claw", holder)
		holder.visible = false
		_spikes.append(holder)

func _build_lights() -> void :
	back_light = DirectionalLight3D.new();back_light.name = "Backlight";add_child(back_light)
	back_light.light_color = Color("ff4a30");back_light.light_energy = 0.55;back_light.shadow_enabled = false
	back_light.light_specular = 0.2
	back_light.rotation = Vector3(-0.35, 0.0, 0.0)
	fill_light = DirectionalLight3D.new();fill_light.name = "Fill";add_child(fill_light)
	fill_light.light_color = Color("8a7cc4");fill_light.light_energy = 0.16;fill_light.shadow_enabled = false
	fill_light.light_specular = 0.1
	fill_light.rotation = Vector3(-0.6, PI * 0.85, 0.0)




func set_clock(t: float) -> void :
	for material: ShaderMaterial in [floor_material, sky_material, debris_material, fog_material, door_material, ray_material]:
		material.set_shader_parameter("clock", t)

func set_ripples(rows: Array) -> void :
	var packed: Array = []
	for i: int in range(RIPPLES):
		packed.append(rows[i] if i < rows.size() else Vector4.ZERO)
	floor_material.set_shader_parameter("ripples", packed)
	floor_material.set_shader_parameter("ripple_count", mini(rows.size(), RIPPLES))

func set_shock(origin: Vector3, age: float, strength: float) -> void :
	floor_material.set_shader_parameter("shock", Vector4(origin.x, origin.z, age, strength))
	debris_material.set_shader_parameter("storm_origin", origin)

func set_storm(amount: float, lift: float = 0.0) -> void :
	debris_material.set_shader_parameter("storm", amount)
	debris_material.set_shader_parameter("lift", lift)

func set_sky(storm: float, flash: float, dim: float, corona: float = 1.0) -> void :
	sky_material.set_shader_parameter("storm", storm)
	sky_material.set_shader_parameter("flash", flash)
	sky_material.set_shader_parameter("dim", dim)
	sky_material.set_shader_parameter("corona_power", corona)
	floor_material.set_shader_parameter("gloss", clampf(dim, 0.1, 1.0))

func set_fog(density: float) -> void :
	fog_material.set_shader_parameter("density", density)

func set_door(at: Vector3, yaw: float, open: float) -> void :
	door.visible = open > 0.001
	door.global_position = at
	door.rotation = Vector3(0, yaw, 0)
	door_material.set_shader_parameter("open", open)
	ray_material.set_shader_parameter("open", open)
	door_light.light_energy = open * 5.0

func set_spikes(rows: Array) -> void :
	for i: int in range(_spikes.size()):
		var holder: Node3D = _spikes[i]
		if i >= rows.size():
			holder.visible = false
			continue
		var row: Array = rows[i]
		var amount: float = float(row[1])
		holder.visible = amount > 0.001
		holder.global_position = (row[0] as Vector3) + Vector3.DOWN * (1.0 - amount) * 15.0
		holder.rotation = Vector3(0, float(row[2]), 0)
		holder.scale = Vector3.ONE * float(row[3])
