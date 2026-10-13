extends Node3D
class_name PaperYiero

# Yiero, le démon colossal du prologue (« Prologue — Yiero »), construit entièrement par code :
# crâne et corps en papier noir froissé (peau brun-rouge à peine visible), yeux ronds pâles sans
# paupières, sourire plus large que le visage avec des dents pointues irrégulières, gencives rouge sang,
# bras immenses à griffes pilotés par IK, franges de papier déchiré qui ondulent.
# Le film règle les paramètres publics ci-dessous à chaque image puis appelle pose().
# Repère local : +Z = devant (vers ce que Yiero regarde), Y = haut, origine = surface de l'encre.

const HEAD_Y: float = 30.0
const HEAD_HALF: float = 15.0
const MOUTH_HALF: float = 17.5
const EYE_X: float = 7.4
const EYE_Y: float = 35.5
const EYE_R: float = 1.85
const FACE_Z: float = 8.4
const UPPER_ARM: float = 25.0
const FOREARM: float = 24.0
const SHOULDER: Vector3 = Vector3(25.0, 17.0, -2.0)
const CORNER_Y: float = 27.6

const SKIN_SHADER: String = """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;
uniform vec4 base_color : source_color = vec4(0.09, 0.03, 0.022, 1.0);
uniform vec4 rim_color : source_color = vec4(0.62, 0.1, 0.06, 1.0);
uniform float reveal = 1.0;
uniform float rim_power = 2.6;
uniform float hurt = 0.0;
uniform vec4 hurt_color : source_color = vec4(1.0, 0.82, 0.45, 1.0);
uniform float fury = 0.0;
varying vec3 wpos;
float hash(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float noise(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float fibre = noise(wpos * 0.42) * 0.6 + noise(wpos * 1.7) * 0.4;
	float burn = smoothstep(0.55, 0.85, noise(wpos * 0.11 + vec3(3.0)));
	vec3 col = base_color.rgb * (0.65 + 0.7 * fibre);
	col = mix(col, vec3(0.012, 0.006, 0.006), burn * 0.8);
	ALBEDO = col * reveal;
	ROUGHNESS = 0.9;
	SPECULAR = 0.2 * reveal;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	vec3 rim = rim_color.rgb * fres * (0.55 + 0.45 * fibre);
	EMISSION = rim * reveal * (1.0 + fury * 1.6) + hurt_color.rgb * hurt * (0.12 + fres) * 0.9;
}
"""

const BONE_SHADER: String = """
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
uniform float glow = 0.35;
uniform float wet = 0.5;
uniform float reveal = 1.0;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	vec3 c = COLOR.rgb * tint.rgb;
	ALBEDO = c * mix(0.5, 1.0, reveal);
	ROUGHNESS = mix(0.75, 0.18, wet);
	SPECULAR = 0.5 + 0.5 * wet;
	EMISSION = c * glow;
}
"""

const GLOW_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 color : source_color = vec4(1.0);
uniform float energy = 1.0;
void fragment() {
	ALBEDO = COLOR.rgb * color.rgb * energy;
}
"""

const HALO_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform vec4 color : source_color = vec4(1.0);
uniform float energy = 0.25;
void fragment() {
	float a = COLOR.a * COLOR.a;
	ALBEDO = color.rgb * energy * a;
	ALPHA = a;
}
"""

const THROAT_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float glow = 1.0;
uniform float clock = 0.0;
varying vec2 local;
void vertex() { local = VERTEX.xy; }
void fragment() {
	float d = length((local - vec2(0.0, -3.0)) * vec2(0.09, 0.2));
	float pulse = 0.85 + 0.15 * sin(clock * 3.1);
	vec3 deep = vec3(0.01, 0.0, 0.0);
	vec3 hot = vec3(0.55, 0.03, 0.02) * pulse;
	ALBEDO = mix(hot, deep, smoothstep(0.0, 1.0, d)) * glow;
}
"""

const FRINGE_SHADER: String = """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap;
uniform float clock = 0.0;
uniform float wind = 1.0;
uniform float reveal = 1.0;
uniform vec4 rim_color : source_color = vec4(0.55, 0.09, 0.05, 1.0);
void vertex() {
	float w = COLOR.a;
	float phase = UV2.x;
	vec3 side = vec3(UV2.y, 0.0, 0.0);
	VERTEX += NORMAL * sin(clock * 2.3 + phase) * w * 0.9 * wind;
	VERTEX.y += cos(clock * 1.7 + phase * 1.3) * w * 0.6 * wind;
}
void fragment() {
	ALBEDO = COLOR.rgb * reveal;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1 * reveal;
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	EMISSION = rim_color.rgb * (0.25 + fres) * reveal * 0.6;
}
"""

var jaw: float = 0.0
var grin: float = 1.0
var grin_wide: float = 1.0
var eye_open: float = 1.0
var eye_glow: float = 1.0
var squint: float = 0.0
var reveal: float = 1.0
var rise: float = 1.0
var lean: float = 0.0
var head_pitch: float = 0.0
var head_roll: float = 0.0
var head_yaw: float = 0.0
var tremble: float = 0.0
var breath: float = 1.0
var hurt: float = 0.0
var fury: float = 0.0
var wind: float = 1.0
var clock: float = 0.0
var look_target: Vector3 = Vector3.INF
var hand_target: Array[Vector3] = [Vector3.INF, Vector3.INF]
var hand_curl: Array[float] = [0.25, 0.25]
var hand_spread: Array[float] = [0.6, 0.6]
var arm_shown: Array[bool] = [true, true]
var tooth_chip: float = 0.0

var _body: Node3D
var _head: Node3D
var _mouth: Node3D
var _jaw: Node3D
var _eyes: Array[Node3D] = []
var _pupils: Array[Node3D] = []
var _scleras: Array[MeshInstance3D] = []
var _upper: Array[Node3D] = []
var _fore: Array[Node3D] = []
var _hand: Array[Node3D] = []
var _fingers: Array = [[], []]
var _chip: MeshInstance3D
var _skin: ShaderMaterial
var _bone: ShaderMaterial
var _gum: ShaderMaterial
var _sclera: ShaderMaterial
var _ring: ShaderMaterial
var _pupil: ShaderMaterial
var _throat: ShaderMaterial
var _halo: ShaderMaterial
var _fringe: ShaderMaterial
var _claw: ShaderMaterial
var _mouth_light: OmniLight3D
var _eye_lights: Array[OmniLight3D] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _built: bool = false

func build() -> void :
	if _built: return
	_built = true
	_rng.seed = 6661
	_materials()
	_body = Node3D.new();_body.name = "Body";add_child(_body)
	_build_torso()
	_head = Node3D.new();_head.name = "Head";_body.add_child(_head);_head.position = Vector3(0, HEAD_Y - 6.0, 0)
	var skull_root: Node3D = Node3D.new();_head.add_child(skull_root);skull_root.position = Vector3(0, 6.0, 0)
	_build_skull(skull_root)
	_build_eyes(skull_root)
	_build_mouth(skull_root)
	_build_fringe(skull_root)
	for side: int in [0, 1]: _build_arm(side)
	_mouth_light = OmniLight3D.new();_mouth_light.light_color = Color("ff2a14");_mouth_light.omni_range = 26.0;_mouth_light.light_energy = 0.0;_mouth_light.shadow_enabled = false
	_mouth.add_child(_mouth_light);_mouth_light.position = Vector3(0, -2.0, FACE_Z + 2.0)
	for side: int in [-1, 1]:
		var light: OmniLight3D = OmniLight3D.new();light.light_color = Color("f3e6c8");light.omni_range = 9.0;light.light_energy = 0.0
		skull_root.add_child(light);light.position = Vector3(side * EYE_X, EYE_Y - HEAD_Y, FACE_Z + 3.0)
		_eye_lights.append(light)
	pose()

func _shader(code: String) -> Shader:
	var shader: Shader = Shader.new()
	shader.code = code
	return shader

func _materials() -> void :
	_skin = ShaderMaterial.new();_skin.shader = _shader(SKIN_SHADER)
	_bone = ShaderMaterial.new();_bone.shader = _shader(BONE_SHADER)
	_bone.set_shader_parameter("glow", 0.42);_bone.set_shader_parameter("wet", 0.7)
	_claw = ShaderMaterial.new();_claw.shader = _bone.shader
	_claw.set_shader_parameter("glow", 0.22);_claw.set_shader_parameter("wet", 0.35)
	_gum = ShaderMaterial.new();_gum.shader = _bone.shader
	_gum.set_shader_parameter("glow", 0.3);_gum.set_shader_parameter("wet", 1.0)
	var glow: Shader = _shader(GLOW_SHADER)
	_sclera = ShaderMaterial.new();_sclera.shader = glow;_sclera.set_shader_parameter("color", Color("cdc4b0"));_sclera.set_shader_parameter("energy", 1.0)
	_ring = ShaderMaterial.new();_ring.shader = glow;_ring.set_shader_parameter("color", Color("1e100b"));_ring.set_shader_parameter("energy", 1.0)
	_pupil = ShaderMaterial.new();_pupil.shader = glow;_pupil.set_shader_parameter("color", Color("ffffff"));_pupil.set_shader_parameter("energy", 3.0)
	_throat = ShaderMaterial.new();_throat.shader = _shader(THROAT_SHADER)
	_halo = ShaderMaterial.new();_halo.shader = _shader(HALO_SHADER);_halo.set_shader_parameter("color", Color("e8d9b8"))
	_fringe = ShaderMaterial.new();_fringe.shader = _shader(FRINGE_SHADER)




func _mesh_node(parent: Node3D, mesh: Mesh, material: Material, label: String) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = label;node.mesh = mesh;node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = 40.0
	parent.add_child(node)
	return node

# Triangle donné dans le sens trigonométrique vu de l'extérieur ; Godot attend des faces avant
# horaires, on émet donc (a, c, b) avec la normale extérieure.
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void :
	_tri3(st, a, b, c, color, color, color)

func _tri3(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void :
	var n: Vector3 = (b - a).cross(c - a)
	n = n.normalized() if n.length_squared() > 1e-10 else Vector3.BACK
	st.set_color(ca);st.set_normal(n);st.add_vertex(a)
	st.set_color(cc);st.set_normal(n);st.add_vertex(c)
	st.set_color(cb);st.set_normal(n);st.add_vertex(b)

func _area(outline: PackedVector2Array) -> float:
	var sum: float = 0.0
	for i: int in range(outline.size()):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % outline.size()]
		sum += a.x * b.y - b.x * a.y
	return sum * 0.5


func _prism(st: SurfaceTool, source: PackedVector2Array, z0: float, z1: float, front: Color, side: Color, bulge: float = 0.0) -> void :
	var outline: PackedVector2Array = source.duplicate()
	if _area(outline) < 0.0: outline.reverse()
	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(outline)
	if indices.is_empty(): return
	var center: Vector2 = Vector2.ZERO
	for p: Vector2 in outline: center += p
	center /= float(outline.size())
	var radius: float = 0.001
	for p: Vector2 in outline: radius = maxf(radius, p.distance_to(center))
	for k: int in range(0, indices.size(), 3):
		var pts: Array[Vector3] = []
		for j: int in range(3):
			var p: Vector2 = outline[indices[k + j]]
			var lift: float = bulge * (1.0 - clampf(p.distance_to(center) / radius, 0.0, 1.0))
			pts.append(Vector3(p.x, p.y, z1 + lift))
		var ccw: bool = (pts[1].x - pts[0].x) * (pts[2].y - pts[0].y) - (pts[1].y - pts[0].y) * (pts[2].x - pts[0].x) > 0.0
		if not ccw: pts = [pts[0], pts[2], pts[1]]
		_tri(st, pts[0], pts[1], pts[2], front)
		_tri(st, Vector3(pts[0].x, pts[0].y, z0), Vector3(pts[2].x, pts[2].y, z0), Vector3(pts[1].x, pts[1].y, z0), side)
	for i: int in range(outline.size()):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % outline.size()]
		_tri(st, Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z0), Vector3(b.x, b.y, z1), side)
		_tri(st, Vector3(a.x, a.y, z0), Vector3(b.x, b.y, z1), Vector3(a.x, a.y, z1), side)


func _blob(st: SurfaceTool, center: Vector3, radii: Vector3, rings: int, segments: int, rough: float, color: Color, flat_front: float = 0.0) -> void :
	var grid: Array = []
	for r: int in range(rings + 1):
		var row: Array[Vector3] = []
		var v: float = float(r) / float(rings)
		var phi: float = v * PI
		for s: int in range(segments):
			var theta: float = float(s) / float(segments) * TAU
			var dir: Vector3 = Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
			var jitter: float = 1.0 + (_rng.randf() - 0.5) * rough if r > 0 and r < rings else 1.0
			var p: Vector3 = dir * radii * jitter
			if flat_front > 0.0 and p.z > 0.0: p.z *= 1.0 - flat_front
			row.append(center + p)
		grid.append(row)
	for r: int in range(rings):
		for s: int in range(segments):
			var a: Vector3 = grid[r][s]
			var b: Vector3 = grid[r][(s + 1) % segments]
			var c: Vector3 = grid[r + 1][s]
			var d: Vector3 = grid[r + 1][(s + 1) % segments]
			var shade: Color = color.lerp(Color.BLACK, _rng.randf() * 0.35)
			_tri(st, a, b, c, shade)
			_tri(st, b, d, c, shade)




func _build_torso() -> void :
	var st: SurfaceTool = SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_blob(st, Vector3(0, 4.0, -6.0), Vector3(26.0, 20.0, 15.0), 9, 16, 0.22, Color.WHITE)
	for side: int in [-1, 1]:
		_blob(st, Vector3(side * 21.0, 14.0, -3.0), Vector3(11.0, 9.0, 10.0), 7, 12, 0.3, Color.WHITE)
		_blob(st, Vector3(side * 12.0, 21.0, -7.0), Vector3(8.5, 7.0, 7.5), 6, 10, 0.3, Color.WHITE)
	_mesh_node(_body, st.commit(), _skin, "Torso")


func _build_skull(root: Node3D) -> void :
	var st: SurfaceTool = SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)

	_blob(st, Vector3(0, 6.0, 0), Vector3(HEAD_HALF, 13.5, 9.5), 11, 20, 0.12, Color.WHITE, 0.25)
	for side: int in [-1, 1]:
		_blob(st, Vector3(side * 8.5, 17.0, -1.5), Vector3(6.0, 5.0, 5.5), 6, 10, 0.25, Color.WHITE)
		_blob(st, Vector3(side * 11.5, 1.0, 1.5), Vector3(5.0, 6.5, 5.0), 6, 10, 0.25, Color.WHITE)

	_blob(st, Vector3(0, 0.5, 2.5), Vector3(12.0, 4.0, 6.5), 6, 14, 0.15, Color.WHITE, 0.2)
	_mesh_node(root, st.commit(), _skin, "Skull")


func _ring_points(radius: float, count: int, wobble: float, seed_value: int) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new();rng.seed = seed_value
	for i: int in range(count):
		var a: float = float(i) / float(count) * TAU
		var r: float = radius * (1.0 + (rng.randf() - 0.5) * wobble)
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts

func _disc_mesh(radius: float, count: int, wobble: float, seed_value: int, depth: float, color: Color) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_prism(st, _ring_points(radius, count, wobble, seed_value), - depth, 0.0, color, color.darkened(0.3))
	return st.commit()

func _annulus_mesh(inner: float, outer: float, count: int, depth: float, color: Color) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(count):
		var a0: float = float(i) / float(count) * TAU
		var a1: float = float(i + 1) / float(count) * TAU
		var p0: Vector3 = Vector3(cos(a0), sin(a0), 0) * inner
		var p1: Vector3 = Vector3(cos(a1), sin(a1), 0) * inner
		var q0: Vector3 = Vector3(cos(a0), sin(a0), 0) * outer
		var q1: Vector3 = Vector3(cos(a1), sin(a1), 0) * outer
		_tri(st, p0, q0, q1, color);_tri(st, p0, q1, p1, color)
	return st.commit()


func _build_eyes(root: Node3D) -> void :
	for side: int in [-1, 1]:
		var eye: Node3D = Node3D.new();eye.name = "Eye";root.add_child(eye)
		eye.position = Vector3(side * EYE_X, EYE_Y - HEAD_Y, FACE_Z - 0.6)
		eye.rotation = Vector3(-0.05, side * 0.16, 0)

		var socket: MeshInstance3D = _mesh_node(eye, _disc_mesh(EYE_R * 1.7, 18, 0.25, 40 + side, 1.0, Color.WHITE), _skin, "Socket")
		socket.position = Vector3(0, 0, -0.2)
		var halo: MeshInstance3D = _mesh_node(eye, _halo_mesh(EYE_R * 3.2), _halo, "Halo")
		halo.position = Vector3(0, 0, 0.2)
		var sclera: MeshInstance3D = _mesh_node(eye, _eye_disc_mesh(EYE_R), _sclera, "Sclera")
		sclera.position = Vector3(0, 0, 0.35)
		_scleras.append(sclera)
		var ring: MeshInstance3D = _mesh_node(eye, _annulus_mesh(EYE_R * 0.9, EYE_R * 1.06, 30, 0.05, Color.WHITE), _ring, "Rim")
		ring.position = Vector3(0, 0, 0.42)
		var pupil_root: Node3D = Node3D.new();eye.add_child(pupil_root);pupil_root.position = Vector3(0, 0, 0.5)
		var iris: MeshInstance3D = _mesh_node(pupil_root, _annulus_mesh(EYE_R * 0.13, EYE_R * 0.22, 16, 0.04, Color.WHITE), _ring, "Iris")
		iris.position = Vector3(0, 0, 0.0)
		var pupil: MeshInstance3D = _mesh_node(pupil_root, _disc_mesh(EYE_R * 0.14, 12, 0.0, 60 + side, 0.05, Color.WHITE), _pupil, "Pupil")
		pupil.position = Vector3(0, 0, 0.06)
		_eyes.append(eye)
		_pupils.append(pupil_root)


func _eye_disc_mesh(radius: float) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = 30
	var centre: Color = Color(1.0, 0.99, 0.96)
	for i: int in range(count):
		var a0: float = float(i) / float(count) * TAU
		var a1: float = float(i + 1) / float(count) * TAU
		var mid0: Vector3 = Vector3(cos(a0), sin(a0), 0) * radius * 0.6
		var mid1: Vector3 = Vector3(cos(a1), sin(a1), 0) * radius * 0.6
		var out0: Vector3 = Vector3(cos(a0), sin(a0), 0) * radius
		var out1: Vector3 = Vector3(cos(a1), sin(a1), 0) * radius
		var middle: Color = Color(0.9, 0.86, 0.78)
		var edge: Color = Color(0.5, 0.44, 0.38)
		_tri3(st, Vector3.ZERO, mid0, mid1, centre, middle, middle)
		_tri3(st, mid0, out0, out1, middle, edge, edge)
		_tri3(st, mid0, out1, mid1, middle, edge, middle)
	return st.commit()


func _halo_mesh(radius: float) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = 24
	for i: int in range(count):
		var a0: float = float(i) / float(count) * TAU
		var a1: float = float(i + 1) / float(count) * TAU
		var centre: Color = Color(1, 1, 1, 1)
		var edge: Color = Color(1, 1, 1, 0)
		_tri3(st, Vector3.ZERO, Vector3(cos(a0), sin(a0), 0) * radius, Vector3(cos(a1), sin(a1), 0) * radius, centre, edge, edge)
	return st.commit()


func _smile_upper(u: float) -> float:
	return CORNER_Y - 6.6 * (1.0 - u * u) - HEAD_Y

func _smile_lower(u: float) -> float:
	return CORNER_Y - 11.8 * (1.0 - u * u) - HEAD_Y


func _build_mouth(root: Node3D) -> void :
	_mouth = Node3D.new();_mouth.name = "Mouth";root.add_child(_mouth)
	var steps: int = 24
	var pivot: float = CORNER_Y - HEAD_Y

	var cavity: PackedVector2Array = PackedVector2Array()
	for i: int in range(steps + 1):
		var u: float = lerpf(-1.0, 1.0, float(i) / float(steps))
		cavity.append(Vector2(u * MOUTH_HALF, _smile_upper(u) + 0.6))
	for i: int in range(steps, -1, -1):
		var u: float = lerpf(-1.0, 1.0, float(i) / float(steps))
		cavity.append(Vector2(u * MOUTH_HALF * 0.96, _smile_lower(u) - 17.0 * (1.0 - u * u * 0.6) - 1.0))
	var st: SurfaceTool = SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_prism(st, cavity, -0.3, 0.0, Color.WHITE, Color.WHITE)
	_mesh_node(_mouth, st.commit(), _throat, "Throat").position = Vector3(0, 0, FACE_Z - 2.6)

	var gum: PackedVector2Array = PackedVector2Array()
	for i: int in range(steps + 1):
		var u: float = lerpf(-1.04, 1.04, float(i) / float(steps))
		gum.append(Vector2(u * MOUTH_HALF, _smile_upper(clampf(u, -1, 1)) + 1.3 + 0.3 * sin(u * 9.0)))
	for i: int in range(steps, -1, -1):
		var u: float = lerpf(-1.0, 1.0, float(i) / float(steps))
		gum.append(Vector2(u * MOUTH_HALF * 0.995, _smile_upper(u) - 0.55))
	st = SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_prism(st, gum, -0.6, 0.0, Color("8c0d12"), Color("4a0508"), 0.35)
	_mesh_node(_mouth, st.commit(), _gum, "UpperGum").position = Vector3(0, 0, FACE_Z)
	st = SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_teeth(st, true)
	_mesh_node(_mouth, st.commit(), _bone, "UpperTeeth").position = Vector3(0, 0, FACE_Z)

	_jaw = Node3D.new();_jaw.name = "Jaw";_mouth.add_child(_jaw)
	_jaw.position = Vector3(0, pivot, -2.0)
	var lower: PackedVector2Array = PackedVector2Array()
	for i: int in range(steps + 1):
		var u: float = lerpf(-1.0, 1.0, float(i) / float(steps))
		lower.append(Vector2(u * MOUTH_HALF * 0.995, _smile_lower(u) + 0.5 - pivot))
	for i: int in range(steps, -1, -1):
		var u: float = lerpf(-1.05, 1.05, float(i) / float(steps))
		lower.append(Vector2(u * MOUTH_HALF, _smile_lower(clampf(u, -1, 1)) - 1.2 - 0.3 * sin(u * 7.0) - pivot))
	st = SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_prism(st, lower, -0.6, 0.0, Color("8c0d12"), Color("4a0508"), 0.35)
	_mesh_node(_jaw, st.commit(), _gum, "LowerGum").position = Vector3(0, 0, FACE_Z + 2.0)
	st = SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_teeth(st, false)
	_mesh_node(_jaw, st.commit(), _bone, "LowerTeeth").position = Vector3(0, 0, FACE_Z + 2.0)

	var chin: SurfaceTool = SurfaceTool.new();chin.begin(Mesh.PRIMITIVE_TRIANGLES)
	var chin_outline: PackedVector2Array = PackedVector2Array()
	for i: int in range(steps + 1):
		var u: float = lerpf(-1.08, 1.08, float(i) / float(steps))
		chin_outline.append(Vector2(u * MOUTH_HALF, _smile_lower(clampf(u, -1, 1)) - 1.0 - pivot))
	for i: int in range(10, -1, -1):
		var a: float = lerpf(0.0, PI, float(i) / 10.0)
		chin_outline.append(Vector2(cos(a) * MOUTH_HALF * 0.95, - 15.0 - sin(a) * 7.0 + 3.0))
	_prism(chin, chin_outline, -6.0, 0.0, Color.WHITE, Color.WHITE, 1.4)
	_mesh_node(_jaw, chin.commit(), _skin, "Chin").position = Vector3(0, 0, FACE_Z + 1.4)

	var chip_st: SurfaceTool = SurfaceTool.new();chip_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_tooth_shape(chip_st, Vector3.ZERO, 1.2, 2.2, 0.0, 1.0, 0.0)
	_chip = _mesh_node(_mouth, chip_st.commit(), _bone, "ToothChip")
	_chip.visible = false


func _tooth_shape(st: SurfaceTool, root: Vector3, width: float, length: float, lean: float, down: float, curl: float) -> void :
	var tip: Vector3 = root + Vector3(lean * length, - down * length, 0.35 + curl)
	var l: Vector3 = root + Vector3( - width * 0.5, 0, 0)
	var r: Vector3 = root + Vector3(width * 0.5, 0, 0)
	var front: Vector3 = root + Vector3(0, - down * length * 0.25, 0.55)
	var back: Vector3 = root + Vector3(0, 0, -0.35)
	var ivory: Color = Color("efe4c4")
	var stain: Color = Color("9c7f45")
	var mid: Color = ivory.lerp(stain, 0.45 + _rng.randf() * 0.3)
	var shade: Color = stain.darkened(0.3)
	if down > 0.0:
		_tri3(st, l, tip, front, stain, ivory, mid)
		_tri3(st, front, tip, r, mid, ivory, stain)
		_tri3(st, r, tip, back, stain, ivory, shade)
		_tri3(st, back, tip, l, shade, ivory, stain)
	else:
		_tri3(st, l, front, tip, stain, mid, ivory)
		_tri3(st, front, r, tip, mid, stain, ivory)
		_tri3(st, r, back, tip, stain, shade, ivory)
		_tri3(st, back, l, tip, shade, stain, ivory)


func _teeth(st: SurfaceTool, upper: bool) -> void :
	var count: int = 25 if upper else 23
	var pivot: float = CORNER_Y - HEAD_Y
	for i: int in range(count):
		var u: float = lerpf(-0.95, 0.95, (float(i) + 0.5) / float(count))
		u += (_rng.randf() - 0.5) * 0.03
		var span: float = 1.0 - u * u
		var gap: float = (_smile_upper(u) - _smile_lower(u))
		var length: float = maxf(0.7, gap * (0.55 + _rng.randf() * 0.35) + 0.3) * (0.9 + 0.4 * span)
		if _rng.randf() < 0.12: length *= 0.55
		var width: float = (1.15 + _rng.randf() * 0.7) * (0.65 + 0.5 * span)
		var lean: float = (_rng.randf() - 0.5) * 0.35 - u * 0.25
		if upper:
			var at: Vector3 = Vector3(u * MOUTH_HALF, _smile_upper(u) + 0.15, 0.1 + _rng.randf() * 0.3)
			_tooth_shape(st, at, width, length, lean, 1.0, (_rng.randf() - 0.5) * 0.4)
			if _rng.randf() < 0.35:
				_tooth_shape(st, at + Vector3((_rng.randf() - 0.5) * 0.8, 0.2, -0.45), width * 0.7, length * 0.6, - lean, 1.0, 0.0)
		else:
			var at: Vector3 = Vector3(u * MOUTH_HALF, _smile_lower(u) - 0.1 - pivot, 0.1 + _rng.randf() * 0.3)
			_tooth_shape(st, at, width * 0.95, length * 0.92, lean, -1.0, (_rng.randf() - 0.5) * 0.4)




func _build_fringe(root: Node3D) -> void :
	var st: SurfaceTool = SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = 70
	for i: int in range(count):
		var a: float = float(i) / float(count) * TAU + _rng.randf() * 0.05
		var edge: Vector3 = Vector3(cos(a) * HEAD_HALF * 0.98, 6.0 + sin(a) * 13.3, -1.0 + _rng.randf() * 2.0)
		if sin(a) < -0.55: continue
		var out: Vector3 = Vector3(cos(a), sin(a) * 0.9, 0.0).normalized()
		var length: float = 2.0 + _rng.randf() * 5.5
		var width: float = 1.0 + _rng.randf() * 2.2
		var side: Vector3 = out.cross(Vector3.BACK).normalized() * width * 0.5
		var tip: Vector3 = edge + out * length + side * (_rng.randf() - 0.5) * 2.0
		var mid: Vector3 = edge + out * length * 0.55 + side * 0.4
		var shade: Color = Color(0.05 + _rng.randf() * 0.06, 0.016, 0.012)
		var phase: float = _rng.randf() * TAU
		var pts: Array = [[edge - side, 0.0], [edge + side, 0.0], [mid + side * 0.5, 0.55], [tip, 1.0], [mid - side * 0.6, 0.55]]
		var n: Vector3 = Vector3.BACK
		for tri: Array in [[0, 1, 2], [0, 2, 4], [4, 2, 3]]:
			for k: int in tri:
				var p: Array = pts[k]
				st.set_color(Color(shade.r, shade.g, shade.b, float(p[1])))
				st.set_uv2(Vector2(phase, 0.0))
				st.set_normal(n)
				st.add_vertex(p[0])
	_mesh_node(root, st.commit(), _fringe, "Fringe")




func _segment_mesh(length: float, r0: float, r1: float, sides: int, rough: float) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: int = 5
	var grid: Array = []
	for r: int in range(rings + 1):
		var v: float = float(r) / float(rings)
		var radius: float = lerpf(r0, r1, v) * (1.0 + sin(v * PI) * 0.18)
		var row: Array[Vector3] = []
		for s: int in range(sides):
			var a: float = float(s) / float(sides) * TAU + v * 0.4
			var jitter: float = 1.0 + (_rng.randf() - 0.5) * rough
			row.append(Vector3(cos(a) * radius * jitter, sin(a) * radius * jitter * 0.85, - v * length))
		grid.append(row)
	for r: int in range(rings):
		for s: int in range(sides):
			var a: Vector3 = grid[r][s]
			var b: Vector3 = grid[r][(s + 1) % sides]
			var c: Vector3 = grid[r + 1][s]
			var d: Vector3 = grid[r + 1][(s + 1) % sides]
			var shade: Color = Color.WHITE.lerp(Color.BLACK, _rng.randf() * 0.35)
			_tri(st, a, c, b, shade);_tri(st, b, c, d, shade)
	for s: int in range(sides):
		_tri(st, Vector3.ZERO, grid[0][s], grid[0][(s + 1) % sides], Color.WHITE)
		_tri(st, Vector3(0, 0, - length), grid[rings][(s + 1) % sides], grid[rings][s], Color.WHITE)
	return st.commit()

func _claw_mesh(length: float, radius: float) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides: int = 5
	var root_color: Color = Color("6e5a3a")
	var tip_color: Color = Color("ece0bd")
	for s: int in range(sides):
		var a0: float = float(s) / float(sides) * TAU
		var a1: float = float(s + 1) / float(sides) * TAU
		var p0: Vector3 = Vector3(cos(a0) * radius, sin(a0) * radius * 0.7, 0)
		var p1: Vector3 = Vector3(cos(a1) * radius, sin(a1) * radius * 0.7, 0)
		var tip: Vector3 = Vector3(0, - radius * 1.6, - length)
		_tri3(st, p0, tip, p1, root_color, tip_color, root_color)
	return st.commit()


func _build_arm(side: int) -> void :
	var upper: Node3D = Node3D.new();upper.name = "Upper%d" % side;add_child(upper)
	_mesh_node(upper, _segment_mesh(UPPER_ARM, 5.2, 3.6, 7, 0.3), _skin, "Mesh")
	var fore: Node3D = Node3D.new();fore.name = "Fore%d" % side;add_child(fore)
	_mesh_node(fore, _segment_mesh(FOREARM, 3.8, 2.4, 7, 0.32), _skin, "Mesh")
	var hand: Node3D = Node3D.new();hand.name = "Hand%d" % side;add_child(hand)
	_mesh_node(hand, _segment_mesh(6.5, 3.0, 4.2, 7, 0.3), _skin, "Palm")
	var fingers: Array = []
	for f: int in range(5):
		var thumb: bool = f == 4
		var finger: Dictionary = {"joints": [], "spread": (float(f) - 1.5) * 0.24 if not thumb else 0.0, "thumb": thumb}
		var parent: Node3D = hand
		var lengths: Array = [5.0, 4.4, 3.6] if not thumb else [4.0, 3.5, 3.0]
		for j: int in range(3):
			var joint: Node3D = Node3D.new();parent.add_child(joint)
			if j == 0:
				joint.position = Vector3((float(f) - 1.5) * 1.55, -0.2, -6.3) if not thumb else Vector3(2.9 * (1 if side == 0 else -1), -0.6, -3.0)
			else:
				joint.position = Vector3(0, 0, - float(lengths[j - 1]))
			var radius: float = 0.9 - 0.18 * float(j)
			_mesh_node(joint, _segment_mesh(float(lengths[j]), radius, radius * 0.8, 5, 0.25), _skin, "Bone")
			finger.joints.append(joint)
			parent = joint
		var claw: MeshInstance3D = _mesh_node(parent, _claw_mesh(4.2 if not thumb else 3.4, 0.62), _claw, "Claw")
		claw.position = Vector3(0, 0, - float(lengths[2]) + 0.2)
		finger["tip"] = float(lengths[2]) + (3.2 if not thumb else 2.6)
		fingers.append(finger)
	_upper.append(upper);_fore.append(fore);_hand.append(hand)
	_fingers[side] = fingers




func socket(name_value: String) -> Vector3:
	if not _built: return global_position
	match name_value:
		"eye_l": return _eyes[0].global_position
		"eye_r": return _eyes[1].global_position
		"eyes": return (_eyes[0].global_position + _eyes[1].global_position) * 0.5
		"mouth": return _mouth.global_transform * Vector3(0, _smile_upper(0.0) - 1.5, FACE_Z + 1.0)
		"teeth": return _mouth.global_transform * Vector3(-3.0, _smile_upper(0.0) - 1.2, FACE_Z + 1.4)
		"chin": return _jaw.global_transform * Vector3(0, -12.0, FACE_Z + 3.0)
		"head": return _head.global_transform * Vector3(0, 6.0, 0)
		"face": return _head.global_transform * Vector3(0, 6.0, FACE_Z)
		"brow": return _head.global_transform * Vector3(0, 13.0, FACE_Z - 1.0)
		"hand_l": return _hand[0].global_transform * Vector3(0, 0, -6.0)
		"hand_r": return _hand[1].global_transform * Vector3(0, 0, -6.0)
		"grip_l": return _hand[0].global_transform * Vector3(0, 0, -9.5) + Vector3.DOWN * 3.4
		"pinch_l": return _tip(0, 1).lerp(_tip(0, 2), 0.5)
		"chest": return _body.global_transform * Vector3(0, 6.0, 6.0)
	return global_position




func _tip(side: int, index: int) -> Vector3:
	var finger: Dictionary = _fingers[side][index]
	var last: Node3D = (finger.joints as Array).back()
	return last.global_transform * Vector3(0, 0, - float(finger.get("tip", 6.0)))


func pose() -> void :
	if not _built: return
	var shake: Vector3 = Vector3(sin(clock * 37.0) + sin(clock * 23.0 + 1.0), sin(clock * 41.0 + 2.0), sin(clock * 29.0 + 0.5)) * tremble * 0.35
	var heave: float = sin(clock * 0.9) * 0.6 * breath
	_body.position = Vector3(0, lerpf(-58.0, 0.0, rise) + heave, lean) + shake
	_body.rotation = Vector3(lean * 0.004, 0, sin(clock * 0.37) * 0.015)
	_head.rotation = Vector3(head_pitch, head_yaw, head_roll + sin(clock * 0.53) * 0.02)
	var g: float = clampf(grin, 0.0, 1.0)
	_mouth.scale = Vector3(maxf(0.02, g) * grin_wide, lerpf(0.25, 1.0, smoothstep(0.0, 0.6, g)), 1.0)
	_mouth.visible = g > 0.005
	_mouth.position = Vector3(0, 0, 0)
	_jaw.rotation = Vector3( - jaw * 0.16, 0, 0)
	_jaw.position = Vector3(0, CORNER_Y - HEAD_Y - jaw * 13.0, -2.0 + jaw * 3.0)
	_throat.set_shader_parameter("glow", 0.35 + jaw * 1.4 + fury * 0.4)
	_throat.set_shader_parameter("clock", clock)
	_mouth_light.light_energy = jaw * 3.0 * reveal + fury * 1.5
	var open: float = clampf(eye_open, 0.0, 1.0)
	for k: int in range(2):
		var eye: Node3D = _eyes[k]
		var s: float = maxf(0.001, open)
		eye.scale = Vector3(s, s * (1.0 - squint * 0.72), s)
		eye.visible = open > 0.002
		if look_target.is_finite():
			var local: Vector3 = eye.global_transform.affine_inverse() * look_target
			var flat: Vector2 = Vector2(local.x, local.y)
			var reach: float = clampf(flat.length() / maxf(1.0, absf(local.z)), 0.0, 1.0)
			var shift: Vector2 = flat.normalized() * reach * EYE_R * 0.42 if flat.length() > 0.01 else Vector2.ZERO
			_pupils[k].position = Vector3(shift.x, shift.y, 0.5)
		else:
			_pupils[k].position = Vector3(0, 0, 0.5)
		_eye_lights[k].light_energy = eye_glow * open * 1.4
	var glow_energy: float = eye_glow * (1.0 + fury * 0.6)
	_sclera.set_shader_parameter("energy", glow_energy * 1.05)
	_sclera.set_shader_parameter("color", Color("cdc4b0").lerp(Color("ffb8a0"), fury * 0.6))
	_halo.set_shader_parameter("energy", 0.22 * glow_energy * eye_open)
	_pupil.set_shader_parameter("energy", 2.4 + glow_energy * 2.0)
	_bone.set_shader_parameter("glow", 0.42 * eye_glow + 0.1)
	_gum.set_shader_parameter("glow", 0.3 * eye_glow + 0.05)
	for material: ShaderMaterial in [_skin]:
		material.set_shader_parameter("reveal", reveal)
		material.set_shader_parameter("hurt", hurt)
		material.set_shader_parameter("fury", fury)
	_fringe.set_shader_parameter("clock", clock)
	_fringe.set_shader_parameter("wind", wind)
	_fringe.set_shader_parameter("reveal", reveal)
	_bone.set_shader_parameter("reveal", 1.0)
	_chip.visible = tooth_chip > 0.0 and tooth_chip < 1.0
	if _chip.visible:
		var u: float = tooth_chip
		_chip.position = Vector3(-3.0 - u * 9.0, _smile_upper(0.1) - 1.0 - u * u * 26.0, FACE_Z + 1.5 + u * 10.0)
		_chip.rotation = Vector3(u * 9.0, u * 5.0, u * 7.0)
	for side: int in [0, 1]: _pose_arm(side)


func _pose_arm(side: int) -> void :
	var sign_x: float = -1.0 if side == 0 else 1.0
	var shown: bool = arm_shown[side] and hand_target[side].is_finite()
	_upper[side].visible = shown;_fore[side].visible = shown;_hand[side].visible = shown
	if not shown: return
	var basis_root: Basis = _body.global_transform.basis.orthonormalized()
	var shoulder: Vector3 = _body.global_transform * Vector3(sign_x * SHOULDER.x, SHOULDER.y, SHOULDER.z)
	var target: Vector3 = hand_target[side]
	var to_target: Vector3 = target - shoulder
	var reach: float = clampf(to_target.length(), 2.0, UPPER_ARM + FOREARM - 0.5)
	var dir: Vector3 = to_target.normalized() if to_target.length_squared() > 0.01 else - basis_root.y
	var pole: Vector3 = basis_root * Vector3(sign_x * 1.0, 0.75, -0.55)
	pole = (pole - dir * pole.dot(dir))
	pole = pole.normalized() if pole.length_squared() > 0.0001 else basis_root.x * sign_x
	var cos_a: float = clampf((UPPER_ARM * UPPER_ARM + reach * reach - FOREARM * FOREARM) / (2.0 * UPPER_ARM * reach), -1.0, 1.0)
	var alpha: float = acos(cos_a)
	var elbow: Vector3 = shoulder + dir * cos(alpha) * UPPER_ARM + pole * sin(alpha) * UPPER_ARM
	var wrist: Vector3 = shoulder + dir * reach
	_place_segment(_upper[side], shoulder, elbow, pole)
	_place_segment(_fore[side], elbow, wrist, pole)

	var fore_dir: Vector3 = (wrist - elbow).normalized()
	var palm_dir: Vector3 = (fore_dir + Vector3.DOWN * 0.35).normalized()
	var up_hint: Vector3 = - pole if absf(palm_dir.dot(pole)) < 0.95 else Vector3.UP
	var hand_basis: Basis = Basis.looking_at(palm_dir, up_hint)
	_hand[side].global_transform = Transform3D(hand_basis, wrist)
	var curl: float = clampf(hand_curl[side], 0.0, 1.2)
	var spread: float = hand_spread[side]
	var twitch: float = sin(clock * 3.3 + float(side) * 2.0) * 0.05
	for finger: Dictionary in _fingers[side]:
		var joints: Array = finger.joints
		for j: int in range(joints.size()):
			var joint: Node3D = joints[j]
			var bend: float = curl * (0.55 + 0.25 * float(j)) + twitch * float(j)
			if bool(finger.thumb): joint.rotation = Vector3(bend * 0.6 - 0.1, sign_x * (0.7 - curl * 0.4) if j == 0 else 0.0, 0)
			else: joint.rotation = Vector3(-0.08 + bend if j > 0 else bend * 0.6 - 0.05, float(finger.spread) * spread * sign_x if j == 0 else 0.0, 0)


func _place_segment(node: Node3D, from: Vector3, to: Vector3, pole: Vector3) -> void :
	var forward: Vector3 = to - from
	if forward.length_squared() < 0.0001: return
	var up: Vector3 = pole if absf(forward.normalized().dot(pole)) < 0.98 else Vector3.UP
	node.global_transform = Transform3D(Basis.looking_at(forward, up), from)
