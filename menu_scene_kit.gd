extends RefCounted

# Décors et accessoires des scènes de survol de l'écran titre. Les murs et meubles
# prennent le même shader « papier » que l'école du jeu (PaperToon, map_toon.gdshader),
# les accessoires tenus en main le style des personnages (CharMaterials.flat, liseré).
# Le flou de mise au point est fait à l'écran (menu_vignette.gdshader) : tout est rendu ensemble.

const G = preload("res://model_geometry.gd")
const CharMaterials = preload("res://char_materials.gd")
const BG: int = 1

static var _mats: Dictionary = {}
static var _noise: Dictionary = {}

# --- Matériaux ------------------------------------------------------------------

static func paper(color: Color, uniforms: Dictionary = {}, kind: String = "plaster") -> Material:
	var key: String = color.to_html() + kind + str(uniforms)
	if _mats.has(key): return _mats[key]
	var base: StandardMaterial3D = StandardMaterial3D.new()
	base.albedo_color = color
	base.roughness = 0.9
	var extra: Dictionary = {"texture_scale": 0.35 if kind == "wood" else 0.25}
	extra.merge(uniforms, true)
	base.set_meta("paper_map", extra)
	base.albedo_texture = _texture(kind)
	var result: Material = PaperToon.material(base, false)
	_mats[key] = result
	return result

static func glow(color: Color, energy: float = 1.5) -> Material:
	var key: String = "glow" + color.to_html() + str(snappedf(energy, 0.01))
	if _mats.has(key): return _mats[key]
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color * energy
	_mats[key] = mat
	return mat

# Matériau lumineux qu'on fait varier (néon qui grésille, écran) : jamais partagé.
static func live_glow(color: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	return mat

static func flat(color: Color, glow_energy: float = 0.0, outline: bool = true) -> Material:
	return CharMaterials.flat(color, glow_energy, outline)

static func _texture(kind: String) -> NoiseTexture2D:
	if _noise.has(kind): return _noise[kind]
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 4604 + absi(kind.hash()) % 5000
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.045 if kind == "stone" else 0.09 if kind == "plaster" else 0.025
	noise.fractal_octaves = 3
	noise.fractal_gain = 0.52
	var texture: NoiseTexture2D = NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.generate_mipmaps = true
	texture.noise = noise
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(0.8, 0.8, 0.8) if kind in ["wood", "stone"] else Color(0.88, 0.88, 0.88))
	ramp.set_color(1, Color(1.0, 1.0, 1.0))
	texture.color_ramp = ramp
	_noise[kind] = texture
	return texture

# Nuit à l'école, comme les cartes du jeu (map_atmosphere.gd) : ambiance bleu-violet,
# brouillard, tonemap filmique, légère désaturation. Fond transparent (masque de la vignette).
static func night_environment(ambient: Color, ambient_energy: float, fog: Color, fog_density: float) -> Environment:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = ambient_energy
	env.fog_enabled = fog_density > 0.0
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = fog
	env.fog_density = fog_density
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	env.adjustment_enabled = true
	env.adjustment_brightness = 0.97
	env.adjustment_contrast = 1.1
	env.adjustment_saturation = 0.88
	return env

# --- Primitives -----------------------------------------------------------------

static func box(parent: Node3D, size: Vector3, at: Vector3, mat: Material, layer: int = BG, shadow: bool = true) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var shape: BoxMesh = BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = mat
	mesh.position = at
	mesh.layers = layer
	if not shadow or size.y <= 0.03: mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh

static func cylinder(parent: Node3D, radius: float, height: float, at: Vector3, mat: Material, layer: int = BG, top: float = -1.0, sides: int = 16) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var shape: CylinderMesh = CylinderMesh.new()
	shape.top_radius = radius if top < 0.0 else top
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = sides
	shape.rings = 1
	mesh.mesh = shape
	mesh.material_override = mat
	mesh.position = at
	mesh.layers = layer
	parent.add_child(mesh)
	return mesh

static func sphere(parent: Node3D, radius: float, at: Vector3, mat: Material, layer: int = BG) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var shape: SphereMesh = SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2.0
	shape.radial_segments = 16
	shape.rings = 8
	mesh.mesh = shape
	mesh.material_override = mat
	mesh.position = at
	mesh.layers = layer
	parent.add_child(mesh)
	return mesh

static func pivot(parent: Node3D, at: Vector3, yaw: float = 0.0) -> Node3D:
	var node: Node3D = Node3D.new()
	node.position = at
	node.rotation.y = yaw
	parent.add_child(node)
	return node

static func omni(parent: Node3D, at: Vector3, color: Color, energy: float, radius: float, shadow: bool = false) -> OmniLight3D:
	var light: OmniLight3D = OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.omni_attenuation = 1.1
	light.shadow_enabled = shadow
	parent.add_child(light)
	return light

static func spot(parent: Node3D, at: Vector3, aim: Vector3, color: Color, energy: float, radius: float, angle: float, shadow: bool = true) -> SpotLight3D:
	var light: SpotLight3D = SpotLight3D.new()
	parent.add_child(light)
	light.position = at
	light.look_at(aim, Vector3.UP if absf((aim - at).normalized().y) < 0.99 else Vector3.FORWARD)
	light.light_color = color
	light.light_energy = energy
	light.spot_range = radius
	light.spot_angle = angle
	light.spot_attenuation = 0.9
	light.spot_angle_attenuation = 1.6
	light.shadow_enabled = shadow
	light.shadow_bias = 0.04
	return light

# Ancien sol des vignettes : tache sombre radiale (gardée pour Réglages).
static func floor_pool() -> MeshInstance3D:
	var pool: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(7.0, 7.0)
	pool.mesh = plane
	var gradient: GradientTexture2D = GradientTexture2D.new()
	gradient.fill = GradientTexture2D.FILL_RADIAL
	gradient.fill_from = Vector2(0.5, 0.5)
	gradient.fill_to = Vector2(1.0, 0.5)
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(0.09, 0.08, 0.13, 0.95))
	g.set_color(1, Color(0.05, 0.05, 0.08, 0.0))
	gradient.gradient = g
	var pool_mat: StandardMaterial3D = StandardMaterial3D.new()
	pool_mat.albedo_texture = gradient
	pool_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pool_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pool.material_override = pool_mat
	pool.position.y = 0.01
	return pool

static func sparks(parent: Node3D, at: Vector3, color: Color = Color(1.0, 0.95, 0.6), amount: int = 46) -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.55
	p.explosiveness = 0.92
	p.direction = Vector3(0, 1, 0)
	p.spread = 80.0
	p.initial_velocity_min = 1.8
	p.initial_velocity_max = 4.2
	p.gravity = Vector3(0, -7.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.018
	mesh.height = 0.036
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mesh.material = mat
	p.mesh = mesh
	p.position = at
	parent.add_child(p)
	return p

# Petite bouffée de poussière au sol (départ en trombe, chute).
static func dust(parent: Node3D, at: Vector3, color: Color = Color(0.72, 0.7, 0.8, 0.55)) -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = 18
	p.lifetime = 0.9
	p.explosiveness = 0.85
	p.direction = Vector3(0, 0.35, 1)
	p.spread = 55.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 2.0
	p.gravity = Vector3(0, 0.2, 0)
	p.damping_min = 2.0
	p.damping_max = 3.5
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.4))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curve
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.07
	mesh.height = 0.1
	mesh.radial_segments = 8
	mesh.rings = 4
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mesh.material = mat
	p.mesh = mesh
	p.position = at
	parent.add_child(p)
	return p

# --- Pièces de décor --------------------------------------------------------------

# Rangée de casiers adossée à un mur : de « from » à « to » (au sol), portes tournées
# vers « facing » (vecteur horizontal). Renvoie les pivots des portes (charnière à gauche).
static func lockers(parent: Node3D, from: Vector3, to: Vector3, facing: Vector3, color: Color, height: float = 2.0, depth: float = 0.5) -> Array:
	var length: float = from.distance_to(to)
	var count: int = maxi(1, roundi(length / 0.42))
	var step: float = length / count
	var along: Vector3 = (to - from).normalized()
	var body_mat: Material = paper(color)
	var trim_mat: Material = paper(color.darkened(0.35))
	var vent_mat: Material = paper(color.darkened(0.55))
	var center: Vector3 = (from + to) * 0.5 - facing * depth * 0.5
	var yaw: float = atan2(facing.x, facing.z)
	var frame: Node3D = pivot(parent, center + Vector3(0, height * 0.5, 0), yaw)
	box(frame, Vector3(length, height, depth), Vector3.ZERO, body_mat)
	box(frame, Vector3(length + 0.04, 0.06, depth + 0.04), Vector3(0, height * 0.5 + 0.03, 0), trim_mat)
	box(frame, Vector3(length + 0.02, 0.12, depth + 0.02), Vector3(0, - height * 0.5 + 0.06, 0), trim_mat)
	var doors: Array = []
	for i: int in range(count):
		var x: float = - length * 0.5 + (i + 0.5) * step
		var hinge: Node3D = pivot(frame, Vector3(x - step * 0.46, 0.04, depth * 0.5 + 0.012))
		var door: Node3D = pivot(hinge, Vector3(step * 0.46, 0, 0))
		box(door, Vector3(step * 0.92, height - 0.26, 0.02), Vector3.ZERO, paper(color.lightened(0.04 if i % 3 == 0 else 0.0)))
		for v: int in range(3):
			box(door, Vector3(step * 0.5, 0.022, 0.012), Vector3(0, height * 0.32 - v * 0.06, 0.014), vent_mat, BG, false)
		box(door, Vector3(0.03, 0.12, 0.03), Vector3(step * 0.32, 0.02, 0.022), paper(Color("9aa0ad")), BG, false)
		doors.append(hinge)
	return doors

# Néon de plafond : boîtier, tube lumineux (matériau à faire varier) et projecteur vers le bas.
static func tube_lamp(parent: Node3D, at: Vector3, length: float, color: Color, energy: float, radius: float, shadow: bool = true, along_x: bool = true) -> Dictionary:
	var housing: Material = paper(Color("3a3d4c"))
	var size: Vector3 = Vector3(length + 0.12, 0.07, 0.2) if along_x else Vector3(0.2, 0.07, length + 0.12)
	box(parent, size, at + Vector3(0, 0.035, 0), housing)
	var tube_mat: StandardMaterial3D = live_glow(color * 2.4)
	var tube: MeshInstance3D = box(parent, Vector3(length, 0.035, 0.07) if along_x else Vector3(0.07, 0.035, length), at - Vector3(0, 0.01, 0), tube_mat, BG, false)
	var light: SpotLight3D = spot(parent, at - Vector3(0, 0.08, 0), at - Vector3(0, 3.0, 0), color, energy, radius, 62.0, shadow)
	return {"tube": tube, "mat": tube_mat, "light": light, "color": color, "energy": energy}

static func set_lamp(lamp: Dictionary, amount: float) -> void :
	var light: SpotLight3D = lamp.light
	light.light_energy = float(lamp.energy) * amount
	light.visible = amount > 0.01
	var mat: StandardMaterial3D = lamp.mat
	var color: Color = lamp.color
	mat.albedo_color = color.lerp(Color(0.16, 0.17, 0.2), 1.0 - clampf(amount, 0.0, 1.0)) * lerpf(1.0, 2.4, clampf(amount, 0.0, 1.0))

# Panneau de sortie vert (pictogramme du bonhomme qui court, sans texte à traduire).
static func exit_sign(parent: Node3D, at: Vector3, yaw: float) -> Node3D:
	var root: Node3D = pivot(parent, at, yaw)
	box(root, Vector3(0.5, 0.22, 0.06), Vector3.ZERO, glow(Color("2fd27a"), 1.6), BG, false)
	var ink: Material = glow(Color("eafff2"), 1.2)
	box(root, Vector3(0.05, 0.05, 0.01), Vector3(-0.1, 0.06, 0.035), ink, BG, false)
	var torso: MeshInstance3D = box(root, Vector3(0.03, 0.08, 0.01), Vector3(-0.09, 0.005, 0.035), ink, BG, false)
	torso.rotation.z = -0.4
	var leg_a: MeshInstance3D = box(root, Vector3(0.025, 0.07, 0.01), Vector3(-0.12, -0.06, 0.035), ink, BG, false)
	leg_a.rotation.z = -0.7
	var leg_b: MeshInstance3D = box(root, Vector3(0.025, 0.07, 0.01), Vector3(-0.06, -0.06, 0.035), ink, BG, false)
	leg_b.rotation.z = 0.6
	box(root, Vector3(0.12, 0.03, 0.01), Vector3(0.08, 0.0, 0.035), ink, BG, false)
	var arrow: MeshInstance3D = box(root, Vector3(0.05, 0.03, 0.01), Vector3(0.13, 0.015, 0.035), ink, BG, false)
	arrow.rotation.z = -0.7
	var arrow_b: MeshInstance3D = box(root, Vector3(0.05, 0.03, 0.01), Vector3(0.13, -0.015, 0.035), ink, BG, false)
	arrow_b.rotation.z = 0.7
	omni(root, Vector3(0, -0.1, 0.25), Color("2fd27a"), 0.6, 2.2)
	return root

# Mur percé de fenêtres (le long de x, à la hauteur z donnée) : la lune passe par les
# ouvertures et dessine des carreaux de lumière au sol.
static func window_wall(parent: Node3D, x: float, z_from: float, z_to: float, height: float, windows: Array, color: Color, facing: float) -> void :
	var mat: Material = paper(color)
	var sill: Material = paper(Color("d8d2c4"))
	var frame_mat: Material = paper(Color("2d3040"))
	var cuts: Array = windows.duplicate()
	cuts.sort()
	var z: float = z_from
	var bottom: float = 1.0
	var top: float = 2.35
	for w: Variant in cuts:
		var center: float = float(w)
		var a: float = center - 0.75
		var b: float = center + 0.75
		if a > z: box(parent, Vector3(0.2, height, a - z), Vector3(x, height * 0.5, (z + a) * 0.5), mat)
		box(parent, Vector3(0.2, bottom, b - a), Vector3(x, bottom * 0.5, center), mat)
		box(parent, Vector3(0.2, height - top, b - a), Vector3(x, top + (height - top) * 0.5, center), mat)
		box(parent, Vector3(0.34, 0.05, b - a + 0.1), Vector3(x + facing * 0.06, bottom - 0.02, center), sill)
		box(parent, Vector3(0.06, top - bottom, 0.05), Vector3(x, (top + bottom) * 0.5, center), frame_mat)
		box(parent, Vector3(0.06, 0.05, b - a), Vector3(x, (top + bottom) * 0.5 + 0.1, center), frame_mat)
		z = b
	if z < z_to: box(parent, Vector3(0.2, height, z_to - z), Vector3(x, height * 0.5, (z + z_to) * 0.5), mat)
