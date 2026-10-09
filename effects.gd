extends Node3D
class_name PaperEffects









const BOX_SHADER: Shader = preload("res://fx_box.gdshader")
const RING_SHADER: Shader = preload("res://fx_ring.gdshader")
const SPRITE_SHADER: Shader = preload("res://fx_sprite.gdshader")
const BEAM_SHADER: Shader = preload("res://fx_beam.gdshader")
const ComicFx = preload("res://fx_comic.gd")


const SHAPE_GLOW: int = 0
const SHAPE_CLAW: int = 1
const SHAPE_STAR: int = 2
const SHAPE_SHIELD: int = 3
const SHAPE_SHEET: int = 4
const SHAPE_ARC: int = 5
const SHAPE_SPLAT: int = 6


const BLEND_MIX: int = 0
const BLEND_ADD: int = 1
const BLEND_TOP: int = 2


const KIT_SCRAP: int = 0
const KIT_INK: int = 1
const KIT_SMOKE: int = 2
const KIT_CONFETTI: int = 3
const KIT_SPARK: int = 4
const KIT_EMBER: int = 5


const KIT_SPEED_MIN: Array[float] = [2.0, 1.3, 0.3, 3.4, 2.6, 0.35]
const KIT_SPEED_MAX: Array[float] = [4.2, 3.4, 0.85, 6.4, 7.2, 1.1]

const POOL_RINGS: int = 18
const POOL_SPRITES: int = 14
const POOL_LINES: int = 6
const POOL_BOXES: int = 6
const THORN_CAPACITY: int = 96
const ZONE_VISUALS: int = 4
const THORN_GROW: float = 0.055
const THORN_HOLD: float = 0.75
const THORN_SHRINK: float = 0.24


class Fx:
	var node: MeshInstance3D
	var active: bool = false
	var age: float = 0.0
	var life: float = 1.0
	var origin: Vector3 = Vector3.ZERO
	var offset: Vector3 = Vector3.ZERO
	var velocity: Vector3 = Vector3.ZERO
	var orientation: Basis = Basis.IDENTITY
	var extent: Vector3 = Vector3.ONE
	var color: Color = Color.WHITE
	var size_from: float = 1.0
	var size_to: float = 1.0
	var angle: float = 0.0
	var spin: float = 0.0
	var fade_start: float = 0.6
	var actor: int = -1
	var cast_id: int = 0
	var follow: bool = false

class Thorn:
	var position: Vector3 = Vector3.ZERO
	var yaw: float = 0.0
	var height: float = 1.0
	var age: float = 0.0


class Kit:
	var normal: Array[CPUParticles3D] = []
	var reduced: Array[CPUParticles3D] = []
	var cursor_normal: int = 0
	var cursor_reduced: int = 0

class ZoneFx:
	var ring: MeshInstance3D
	var motes: CPUParticles3D
	var position: Vector3 = Vector3.ZERO
	var radius: float = 5.0
	var left: float = 20.0
	var alive: bool = false
	var seen: bool = false
	var fade: float = 0.0
	var clock: float = 0.0

var trajectory: MeshInstance3D
var decoy_models: Array[Dictionary] = []
var shadow_pool_root: Node3D
var shadow_pool: Array[PaperVisual] = []
var shadow_free: Array[PaperVisual] = []
var world: Node3D
var shadows: Dictionary = {}
var grenades: Dictionary = {}
var drone_nodes: Dictionary = {}
var vanished: Dictionary = {}
var aim_root: Node3D
var aim_fill: MeshInstance3D
var aim_markers: Array[MeshInstance3D] = []
var dark: StandardMaterial3D
var metal: StandardMaterial3D
var warning: StandardMaterial3D
var status_nodes: Dictionary = {}
var _status_ring_mesh: TorusMesh
var _status_shell_mesh: CapsuleMesh
var _status_trail_mesh: PrismMesh

var _kit_ready: bool = false
var _dedicated: bool = false
var _entities_hidden: bool = false
var _clock: float = 0.0
var _quad: QuadMesh
var _plane: PlaneMesh
var _unit_box: BoxMesh
var _box_material: ShaderMaterial
var _ring_material: ShaderMaterial
var _sprite_materials: Array[ShaderMaterial] = []
var _beam_material: ShaderMaterial
var _beacon_material: ShaderMaterial
var _thorn_material: StandardMaterial3D
var _particle_materials: Array[StandardMaterial3D] = []
var _rings: Array[Fx] = []
var _sprites: Array = [[], [], []]
var _lines: Array[Fx] = []
var _boxes: Array[Fx] = []
var _kits: Array[Kit] = []
var _thorns: Array[Thorn] = []
var _thorn_rows: Array[MultiMeshInstance3D] = []
var _thorn_meshes: Array[ArrayMesh] = []
var _zone_fx: Array[ZoneFx] = []
var _beacon: MeshInstance3D
var _beacon_glow: MeshInstance3D
var _beacon_ring: MeshInstance3D
var _beacon_level: float = 0.0
var _flash_light: OmniLight3D
var _flash_light_age: float = -1.0
var _trajectory_mesh: ImmediateMesh
var _landing: MeshInstance3D
var _aim_multimesh: MultiMeshInstance3D
var _grenade_mesh: ArrayMesh
var _drone_body_mesh: ArrayMesh
var _rotor_mesh: ArrayMesh
var _grenade_free: Array[MeshInstance3D] = []
var _drone_free: Array[Dictionary] = []
var _status_free: Array[Dictionary] = []
var _stuns: Dictionary = {}
var _stun_free: Array[Dictionary] = []
var _stun_totals: Dictionary = {}
var _delayed: Array[Dictionary] = []
var _spike_dust_clock: float = 0.0
var _warm_root: Node3D
var _warm_frames: int = 0
var _present_ids: Dictionary = {}
var _interpolated: bool = false

var comic: ComicFx

func setup(owner: Node3D) -> void :
	world = owner
	_dedicated = bool(world.get("dedicated"))
	_interpolated = world.has_method("actor_render_position")
	shadow_pool_root = Node3D.new();shadow_pool_root.name = "PreparedShadows";add_child(shadow_pool_root)
	dark = _mat(Color("17101e"));metal = _mat(Color("899ba4"));metal.metallic = 0.7;metal.roughness = 0.3
	warning = _mat(Color("cfe5ff"));warning.emission_enabled = true;warning.emission = Color("778dab")
	set_process(false)

	if _dedicated: return
	_build_kit()
	_build_aim()

func _mat(color: Color) -> StandardMaterial3D:
	var result: StandardMaterial3D = StandardMaterial3D.new();result.albedo_color = color;result.roughness = 0.7
	return result





func _build_kit() -> void :
	_quad = QuadMesh.new()
	_quad.size = Vector2.ONE
	_plane = PlaneMesh.new()
	_plane.size = Vector2.ONE
	_unit_box = BoxMesh.new()
	_unit_box.size = Vector3.ONE
	_box_material = _shader_material(BOX_SHADER, 1)
	_ring_material = _shader_material(RING_SHADER, 0)
	_sprite_materials = [
		_shader_material(_variant(SPRITE_SHADER, "blend_add", "blend_mix"), 1), 
		_shader_material(SPRITE_SHADER, 2), 
		_shader_material(_variant(SPRITE_SHADER, "blend_add", "blend_add, depth_test_disabled"), 3), 
	]
	_beam_material = _shader_material(BEAM_SHADER, 2)

	_beacon_material = _shader_material(BEAM_SHADER, 2)
	var through: Shader = _variant(BEAM_SHADER, "blend_add", "blend_add, depth_test_disabled")
	through.code = through.code.replace("ALPHA = clamp(a * color.a, 0.0, 1.0);", "ALPHA = clamp(a * color.a * 0.22, 0.0, 1.0);")
	_beacon_material.next_pass = _shader_material(through, 3)
	_thorn_material = _mat(Color("221421"))
	_thorn_material.emission_enabled = true
	_thorn_material.emission = Color("420f23")
	_thorn_material.emission_energy_multiplier = 0.5
	for i: int in range(POOL_RINGS): _rings.append(_fx_node(_plane, _ring_material, "FxRing"))
	for variant: int in range(3):
		var pool: Array[Fx] = []
		for i: int in range(POOL_SPRITES): pool.append(_fx_node(_quad, _sprite_materials[variant], "FxSprite"))
		_sprites[variant] = pool
	for i: int in range(POOL_LINES): _lines.append(_fx_node(_quad, _beam_material, "FxLine"))
	for i: int in range(POOL_BOXES):
		var box: Fx = _fx_node(_unit_box, _box_material, "FxAttackZone")
		box.node.set_instance_shader_parameter("color", Color(1.0, 0.16, 0.3, 1.0))
		_boxes.append(box)
	_build_particles()
	_build_thorns()
	_build_zones()
	_build_beacon()
	comic = ComicFx.new()
	comic.name = "ComicFx"
	add_child(comic)
	comic.setup(self, world)
	_flash_light = OmniLight3D.new()
	_flash_light.name = "FlashbangLight"
	_flash_light.omni_range = 8.0
	_flash_light.light_color = Color("d5e6ff")
	_flash_light.light_energy = 0.0
	_flash_light.shadow_enabled = false
	_flash_light.visible = false
	add_child(_flash_light)
	_trajectory_mesh = ImmediateMesh.new()
	trajectory = MeshInstance3D.new()
	trajectory.name = "FlashbangTrajectory"
	trajectory.mesh = _trajectory_mesh
	var path_material: StandardMaterial3D = StandardMaterial3D.new()
	path_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	path_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	path_material.albedo_color = Color(0.95, 0.96, 1, 0.78)
	path_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	trajectory.material_override = path_material
	trajectory.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trajectory.visible = false
	add_child(trajectory)
	_landing = _plain_node(_plane, _ring_material, "FlashbangLanding")
	_landing.set_instance_shader_parameter("color", Color(0.95, 0.96, 1.0, 0.8))
	_landing.set_instance_shader_parameter("thickness", 0.035)
	_landing.scale = Vector3(0.64, 1.0, 0.64)
	_kit_ready = true

func _variant(source: Shader, find: String, replace: String) -> Shader:
	var shader: Shader = Shader.new()
	shader.code = source.code.replace(find, replace)
	return shader

func _shader_material(shader: Shader, priority: int) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	material.render_priority = priority
	return material

func _plain_node(mesh: Mesh, material: Material, label: String) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	node.visible = false
	add_child(node)
	return node

func _fx_node(mesh: Mesh, material: Material, label: String) -> Fx:
	var fx: Fx = Fx.new()
	fx.node = _plain_node(mesh, material, label)
	return fx

func _dot_texture(hardness: float) -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, hardness, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0)])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture

func _particle_material(texture: Texture2D, additive: bool) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = texture
	if additive:
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.disable_fog = true
	return material

func _fade_ramp(peak: float, hold: float) -> Gradient:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, hold, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, peak), Color(1, 1, 1, peak), Color(1, 1, 1, 0)])
	return gradient

func _curve(points: Array) -> Curve:
	var curve: Curve = Curve.new()
	for point: Vector2 in points: curve.add_point(point)
	return curve

func _build_particles() -> void :
	var scrap_material: StandardMaterial3D = _particle_material(null, false)
	var ink_material: StandardMaterial3D = _particle_material(_dot_texture(0.55), false)
	var smoke_material: StandardMaterial3D = _particle_material(_dot_texture(0.05), false)
	_particle_materials = [scrap_material, ink_material, smoke_material]
	var scrap_mesh: QuadMesh = QuadMesh.new();scrap_mesh.size = Vector2(0.075, 0.05)
	var ink_mesh: QuadMesh = QuadMesh.new();ink_mesh.size = Vector2(0.085, 0.085)
	var smoke_mesh: QuadMesh = QuadMesh.new();smoke_mesh.size = Vector2(0.3, 0.3)
	var confetti_mesh: QuadMesh = QuadMesh.new();confetti_mesh.size = Vector2(0.075, 0.042)

	var spark_material: StandardMaterial3D = _particle_material(_dot_texture(0.3), true)
	var ember_material: StandardMaterial3D = _particle_material(_dot_texture(0.12), true)
	_particle_materials.append(spark_material)
	_particle_materials.append(ember_material)
	var spark_mesh: QuadMesh = QuadMesh.new();spark_mesh.size = Vector2(0.07, 0.07)
	var ember_mesh: QuadMesh = QuadMesh.new();ember_mesh.size = Vector2(0.1, 0.1)
	var flicker: Curve = _curve([Vector2(0, 0.4), Vector2(0.15, 1.0), Vector2(0.7, 0.7), Vector2(1, 0)])
	var shrink: Curve = _curve([Vector2(0, 1), Vector2(0.6, 0.9), Vector2(1, 0)])
	var grow: Curve = _curve([Vector2(0, 0.55), Vector2(1, 1.8)])
	var drops: Curve = _curve([Vector2(0, 1), Vector2(1, 0.55)])
	var palette: Gradient = Gradient.new()
	palette.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	palette.colors = PackedColorArray([Color("f3ead6"), Color("7fd3c7"), Color("e9b765"), Color("e58f9e"), Color("b3a2e8")])

	var specs: Array = [
		[scrap_mesh, scrap_material, 14, 6, 8, 4, 0.55], 
		[ink_mesh, ink_material, 10, 5, 8, 4, 0.62], 
		[smoke_mesh, smoke_material, 6, 3, 5, 3, 0.75], 
		[confetti_mesh, scrap_material, 40, 14, 2, 1, 1.7], 
		[spark_mesh, spark_material, 12, 5, 10, 5, 0.42], 
		[ember_mesh, ember_material, 9, 4, 8, 4, 1.15], 
	]
	for index: int in range(specs.size()):
		var spec: Array = specs[index]
		var kit: Kit = Kit.new()
		for reduced: int in range(2):
			var count: int = int(spec[5 if reduced else 4])
			for n: int in range(count):
				var emitter: CPUParticles3D = CPUParticles3D.new()
				emitter.name = "FxParticles"
				emitter.emitting = false
				emitter.one_shot = true
				emitter.explosiveness = 1.0
				emitter.amount = int(spec[3 if reduced else 2])
				emitter.lifetime = float(spec[6])
				emitter.lifetime_randomness = 0.35
				emitter.local_coords = false
				emitter.mesh = spec[0]
				emitter.material_override = spec[1]
				emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				emitter.visible = false
				emitter.color_ramp = _fade_ramp(1.0, 0.7)
				match index:
					KIT_SCRAP:
						emitter.spread = 60.0
						emitter.initial_velocity_min = 2.0
						emitter.initial_velocity_max = 4.2
						emitter.gravity = Vector3(0, -8.5, 0)
						emitter.damping_min = 1.0
						emitter.damping_max = 2.5
						emitter.angle_min = 0.0
						emitter.angle_max = 360.0
						emitter.angular_velocity_min = -540.0
						emitter.angular_velocity_max = 540.0
						emitter.scale_amount_min = 0.7
						emitter.scale_amount_max = 1.35
						emitter.scale_amount_curve = shrink
					KIT_INK:
						emitter.spread = 70.0
						emitter.initial_velocity_min = 1.3
						emitter.initial_velocity_max = 3.4
						emitter.gravity = Vector3(0, -11.0, 0)
						emitter.damping_min = 0.3
						emitter.damping_max = 0.8
						emitter.scale_amount_min = 0.5
						emitter.scale_amount_max = 1.15
						emitter.scale_amount_curve = drops
					KIT_SMOKE:
						emitter.spread = 55.0
						emitter.initial_velocity_min = 0.3
						emitter.initial_velocity_max = 0.85
						emitter.gravity = Vector3(0, 0.45, 0)
						emitter.damping_min = 1.2
						emitter.damping_max = 1.8
						emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
						emitter.emission_sphere_radius = 0.14
						emitter.scale_amount_min = 0.7
						emitter.scale_amount_max = 1.2
						emitter.scale_amount_curve = grow
						emitter.color_ramp = _smoke_ramp()
					KIT_CONFETTI:
						emitter.spread = 38.0
						emitter.initial_velocity_min = 3.4
						emitter.initial_velocity_max = 6.4
						emitter.gravity = Vector3(0, -4.2, 0)
						emitter.damping_min = 1.2
						emitter.damping_max = 2.2
						emitter.angle_min = 0.0
						emitter.angle_max = 360.0
						emitter.angular_velocity_min = -720.0
						emitter.angular_velocity_max = 720.0
						emitter.scale_amount_min = 0.8
						emitter.scale_amount_max = 1.3
						emitter.color_initial_ramp = palette
						emitter.color_ramp = _fade_ramp(1.0, 0.8)
						emitter.visibility_aabb = AABB(Vector3(-6, -3, -6), Vector3(12, 10, 12))
					KIT_SPARK:
						emitter.spread = 65.0
						emitter.initial_velocity_min = 2.6
						emitter.initial_velocity_max = 7.2
						emitter.gravity = Vector3(0, -13.0, 0)
						emitter.damping_min = 1.5
						emitter.damping_max = 3.5
						emitter.scale_amount_min = 0.45
						emitter.scale_amount_max = 1.25
						emitter.scale_amount_curve = shrink
						emitter.lifetime_randomness = 0.5
					KIT_EMBER:
						emitter.spread = 40.0
						emitter.initial_velocity_min = 0.35
						emitter.initial_velocity_max = 1.1
						emitter.gravity = Vector3(0, 1.5, 0)
						emitter.damping_min = 0.2
						emitter.damping_max = 0.7
						emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
						emitter.emission_sphere_radius = 0.42
						emitter.scale_amount_min = 0.5
						emitter.scale_amount_max = 1.3
						emitter.scale_amount_curve = flicker
						emitter.visibility_aabb = AABB(Vector3(-3, -2, -3), Vector3(6, 7, 6))
				add_child(emitter)
				if reduced: kit.reduced.append(emitter)
				else: kit.normal.append(emitter)
		_kits.append(kit)

func _smoke_ramp() -> Gradient:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.18, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.42), Color(1, 1, 1, 0.0)])
	return gradient

func _build_thorns() -> void :
	for lean: float in [-1.0, 1.0]:
		var mesh: ArrayMesh = _thorn(1.0, lean)
		_thorn_meshes.append(mesh)
		var multimesh: MultiMesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		multimesh.instance_count = THORN_CAPACITY
		multimesh.visible_instance_count = 0
		var row: MultiMeshInstance3D = MultiMeshInstance3D.new()
		row.name = "SpikeThorns"
		row.multimesh = multimesh
		row.material_override = _thorn_material
		row.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		row.visible = false
		add_child(row)
		_thorn_rows.append(row)

func _build_zones() -> void :
	var mote_material: StandardMaterial3D = _particle_material(_dot_texture(0.25), true)
	_particle_materials.append(mote_material)
	var mote_mesh: QuadMesh = QuadMesh.new()
	mote_mesh.size = Vector2(0.09, 0.09)
	var fade: Curve = _curve([Vector2(0, 0), Vector2(0.25, 1), Vector2(1, 0)])
	for i: int in range(ZONE_VISUALS):
		var zone: ZoneFx = ZoneFx.new()
		zone.ring = _plain_node(_plane, _ring_material, "HealZone")
		zone.ring.set_instance_shader_parameter("thickness", 0.07)
		zone.ring.set_instance_shader_parameter("fill", 0.16)
		var motes: CPUParticles3D = CPUParticles3D.new()
		motes.name = "HealMotes"
		motes.emitting = false
		motes.amount = 14
		motes.lifetime = 1.8
		motes.local_coords = false
		motes.mesh = mote_mesh
		motes.material_override = mote_material
		motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		motes.emission_ring_axis = Vector3.UP
		motes.emission_ring_height = 0.05
		motes.emission_ring_inner_radius = 0.0
		motes.emission_ring_radius = 4.8
		motes.direction = Vector3.UP
		motes.spread = 12.0
		motes.initial_velocity_min = 0.25
		motes.initial_velocity_max = 0.7
		motes.gravity = Vector3(0, 0.55, 0)
		motes.scale_amount_min = 0.6
		motes.scale_amount_max = 1.3
		motes.scale_amount_curve = fade
		motes.color = Color("8ff0d2")
		motes.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 5, 12))
		motes.visible = false
		add_child(motes)
		zone.motes = motes
		_zone_fx.append(zone)

func _build_beacon() -> void :
	_beacon = _plain_node(_quad, _beacon_material, "ExitBeacon")
	_beacon.set_instance_shader_parameter("mode", 1.0)
	_beacon.set_instance_shader_parameter("width", 2.1)
	_beacon.extra_cull_margin = 2.0
	_beacon_glow = _plain_node(_quad, _sprite_materials[BLEND_ADD], "ExitBeaconGlow")
	_beacon_glow.set_instance_shader_parameter("shape", SHAPE_GLOW)
	_beacon_ring = _plain_node(_plane, _ring_material, "ExitBeaconRing")
	_beacon_ring.set_instance_shader_parameter("thickness", 0.09)
	_beacon_ring.set_instance_shader_parameter("fill", 0.1)

func _merged(parts: Array) -> ArrayMesh:

	var mesh: ArrayMesh = ArrayMesh.new()
	var groups: Dictionary = {}
	for part: Array in parts:
		var index: int = int(part[2])
		if not groups.has(index):
			var tool: SurfaceTool = SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[index] = tool
		var source: Mesh = part[0]
		for surface: int in range(source.get_surface_count()):
			groups[index].append_from(source, surface, part[1])
	var keys: Array = groups.keys()
	keys.sort()
	for index: int in keys:
		var tool: SurfaceTool = groups[index]
		tool.commit(mesh)
	return mesh

func _cylinder(radius: float, height: float, segments: int) -> CylinderMesh:
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = segments
	cylinder.rings = 1
	return cylinder

func _ensure_entity_meshes() -> void :
	if _grenade_mesh: return
	var lever: BoxMesh = BoxMesh.new();lever.size = Vector3(0.025, 0.2, 0.025)
	var lever_transform: Transform3D = Transform3D(Basis(Vector3.BACK, -0.2), Vector3(0.076, 0.03, 0))
	_grenade_mesh = _merged([
		[_cylinder(0.065, 0.2, 16), Transform3D.IDENTITY, 0], 
		[_cylinder(0.072, 0.025, 16), Transform3D(Basis.IDENTITY, Vector3(0, -0.09, 0)), 1], 
		[_cylinder(0.072, 0.025, 16), Transform3D(Basis.IDENTITY, Vector3(0, 0.09, 0)), 1], 
		[lever, lever_transform, 1], 
		[_cylinder(0.067, 0.055, 16), Transform3D.IDENTITY, 2], 
	])
	_grenade_mesh.surface_set_material(0, metal)
	_grenade_mesh.surface_set_material(1, dark)
	_grenade_mesh.surface_set_material(2, warning)
	var shell: StandardMaterial3D = _mat(Color("282639"));shell.metallic = 0.68;shell.roughness = 0.28
	var accent: StandardMaterial3D = _mat(Color("966de5"));accent.emission_enabled = true;accent.emission = Color("39245b")
	var hull: SphereMesh = SphereMesh.new();hull.radius = 0.22;hull.height = 0.26;hull.radial_segments = 20;hull.rings = 10
	var plate: CylinderMesh = CylinderMesh.new();plate.top_radius = 0.1;plate.bottom_radius = 0.13;plate.height = 0.025;plate.radial_segments = 6;plate.rings = 1
	var beam: BoxMesh = BoxMesh.new();beam.size = Vector3(0.055, 0.055, 0.4)
	var guard: TorusMesh = TorusMesh.new();guard.inner_radius = 0.125;guard.outer_radius = 0.145;guard.rings = 16;guard.ring_segments = 6
	var glass: SphereMesh = SphereMesh.new();glass.radius = 0.045;glass.height = 0.09;glass.radial_segments = 10;glass.rings = 5
	var parts: Array = [
		[hull, Transform3D(Basis.from_scale(Vector3(1.0, 0.7, 1.45)), Vector3.ZERO), 0], 
		[plate, Transform3D(Basis.IDENTITY, Vector3(0, 0.105, 0)), 1], 
		[glass, Transform3D(Basis.IDENTITY, Vector3(0, -0.015, -0.3)), 2], 
	]
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			var point: Vector3 = Vector3(x * 0.29, 0.055, z * 0.29)
			parts.append([beam, Transform3D(Basis(Vector3.UP, atan2(point.x, point.z)), point * 0.52), 0])
			parts.append([guard, Transform3D(Basis.IDENTITY, point), 0])
	_drone_body_mesh = _merged(parts)
	_drone_body_mesh.surface_set_material(0, shell)
	_drone_body_mesh.surface_set_material(1, accent)
	_drone_body_mesh.surface_set_material(2, warning)
	var blade: BoxMesh = BoxMesh.new();blade.size = Vector3(0.24, 0.012, 0.026)
	_rotor_mesh = _merged([[blade, Transform3D.IDENTITY, 0], [blade, Transform3D(Basis(Vector3.UP, PI / 2), Vector3.ZERO), 0]])
	_rotor_mesh.surface_set_material(0, metal)





func clear_entities() -> void :
	for model: PaperVisual in shadow_pool: _release_shadow(model)
	shadows.clear();vanished.clear();decoy_models.clear();_stun_totals.clear();_delayed.clear()
	for id: Variant in grenades.keys(): _release_grenade(grenades[id])
	grenades.clear()
	for id: Variant in drone_nodes.keys(): _release_drone(drone_nodes[id])
	drone_nodes.clear()
	for id: Variant in status_nodes.keys():
		var status: Dictionary = status_nodes[id]
		status.root.hide()
		_status_free.append(status)
	status_nodes.clear()
	for id: Variant in _stuns.keys():
		var stun: Dictionary = _stuns[id]
		stun.root.hide()
		_stun_free.append(stun)
	_stuns.clear()
	if aim_root: aim_root.hide()
	if not _kit_ready: return
	for fx: Fx in _rings: _retire(fx)
	for pool: Array in _sprites:
		for fx: Fx in pool: _retire(fx)
	for fx: Fx in _lines: _retire(fx)
	for fx: Fx in _boxes: _retire(fx)
	_thorns.clear()
	for row: MultiMeshInstance3D in _thorn_rows:
		row.multimesh.visible_instance_count = 0
		row.visible = false
	for kit: Kit in _kits:
		for emitter: CPUParticles3D in kit.normal: emitter.visible = false
		for emitter: CPUParticles3D in kit.reduced: emitter.visible = false
	for zone: ZoneFx in _zone_fx: _hide_zone(zone)
	comic.clear()
	_beacon_level = 0.0
	_beacon.visible = false
	_beacon_glow.visible = false
	_beacon_ring.visible = false
	_flash_light.visible = false
	_flash_light_age = -1.0
	trajectory.visible = false
	_landing.visible = false
	_entities_hidden = false

func update_visuals(delta: float) -> void :
	if not _kit_ready: return
	_clock += delta
	_spike_dust_clock = maxf(0.0, _spike_dust_clock - delta)
	_tick_delayed(delta)

	_update_rings(delta)
	for variant: int in range(3): _update_sprites(_sprites[variant], delta)
	_update_lines(delta)
	_update_thorns(delta)
	_update_flash_light(delta)
	comic.update(delta)
	if str(world.phase) != "playing":
		_hide_gameplay_entities()
		return
	_entities_hidden = false
	comic.update_actors(delta)
	_update_boxes(delta)
	_update_trajectory()
	_update_decoys(delta)
	_update_aim()
	_update_drones(delta)
	_update_status_visuals(delta)
	_update_minions(delta)
	_update_grenades(delta)
	_update_zones(delta)
	_update_beacon(delta)

func _hide_gameplay_entities() -> void :


	if _entities_hidden: return
	_entities_hidden = true
	if aim_root: aim_root.hide()
	trajectory.visible = false
	_landing.visible = false
	for status: Dictionary in status_nodes.values(): status.root.hide()
	for stun: Dictionary in _stuns.values(): stun.root.hide()
	for id: Variant in shadows.keys(): _release_shadow(shadows[id])
	shadows.clear()
	for entry: Dictionary in decoy_models: _release_shadow(entry.model)
	decoy_models.clear()
	for id: Variant in grenades.keys(): _release_grenade(grenades[id])
	grenades.clear()
	for id: Variant in drone_nodes.keys(): _release_drone(drone_nodes[id])
	drone_nodes.clear()
	for fx: Fx in _boxes: _retire(fx)
	for zone: ZoneFx in _zone_fx: _hide_zone(zone)
	_beacon_level = 0.0
	_beacon.visible = false
	_beacon_glow.visible = false
	_beacon_ring.visible = false




func warm_up(camera: Camera3D) -> void :
	if not _kit_ready or not is_instance_valid(camera) or DisplayServer.get_name() == "headless": return
	_ensure_entity_meshes()
	if is_instance_valid(_warm_root): _warm_root.queue_free()
	_warm_root = Node3D.new()
	_warm_root.name = "EffectWarmUp"
	add_child(_warm_root)
	var front: Transform3D = camera.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 0, -2.2))
	_warm_root.global_transform = front
	var samples: Array = [
		[_unit_box, _box_material], [_plane, _ring_material], [_quad, _sprite_materials[0]], 
		[_quad, _sprite_materials[1]], [_quad, _sprite_materials[2]], [_quad, _beam_material], 
		[_quad, _beacon_material], [_thorn_meshes[0], _thorn_material], [_grenade_mesh, null], 
		[_drone_body_mesh, null], [_rotor_mesh, null], [aim_fill.mesh, aim_fill.material_override], 
	]
	samples.append_array(comic.warm_samples())
	var index: int = 0
	for sample: Array in samples:
		var node: MeshInstance3D = MeshInstance3D.new()
		node.mesh = sample[0]
		if sample[1] != null: node.material_override = sample[1]
		node.position = Vector3((index % 6 - 2.5) * 0.06, (index / 6 - 0.5) * 0.06, 0)
		node.scale = Vector3.ONE * 0.05
		node.set_instance_shader_parameter("color", Color(1, 1, 1, 0.01))
		_warm_root.add_child(node)
		index += 1
	var at: Vector3 = front.origin
	comic.warm(at)
	for kit: Kit in _kits:
		for emitter: CPUParticles3D in kit.normal + kit.reduced: _fire(emitter, at, Vector3.UP, Color(1, 1, 1, 0.02))
	for zone: ZoneFx in _zone_fx:
		zone.motes.global_position = at
		zone.motes.visible = true
		zone.motes.emitting = true
	for row: MultiMeshInstance3D in _thorn_rows:
		row.multimesh.visible_instance_count = 1
		row.multimesh.set_instance_transform(0, Transform3D(Basis.from_scale(Vector3.ONE * 0.05), at))
		row.visible = true
	_aim_multimesh.visible = true
	aim_root.global_position = at
	aim_root.show()
	trajectory.visible = true
	_warm_frames = 3
	set_process(true)

func _process(_delta: float) -> void :
	if _warm_frames <= 0:
		set_process(false)
		return
	_warm_frames -= 1
	if _warm_frames > 0: return
	if is_instance_valid(_warm_root): _warm_root.queue_free()
	_warm_root = null
	for kit: Kit in _kits:
		for emitter: CPUParticles3D in kit.normal + kit.reduced: emitter.visible = false
	for zone: ZoneFx in _zone_fx: _hide_zone(zone)
	for row: MultiMeshInstance3D in _thorn_rows:
		row.multimesh.visible_instance_count = 0
		row.visible = false
	aim_root.hide()
	trajectory.visible = false
	set_process(false)





func _acquire(pool: Array) -> Fx:
	var oldest: Fx = null
	var oldest_ratio: float = -1.0
	for fx: Fx in pool:
		if not fx.active: return fx
		var ratio: float = fx.age / maxf(0.001, fx.life)
		if ratio > oldest_ratio:
			oldest = fx
			oldest_ratio = ratio
	return oldest

func _retire(fx: Fx) -> void :
	fx.active = false
	fx.follow = false
	fx.actor = -1
	fx.cast_id = 0
	fx.node.visible = false

func _basis_from_normal(normal: Vector3) -> Basis:
	if normal.length_squared() < 0.01: return Basis.IDENTITY
	var direction: Vector3 = normal.normalized()
	if direction.dot(Vector3.UP) > 0.999: return Basis.IDENTITY
	if direction.dot(Vector3.UP) < -0.999: return Basis(Vector3.RIGHT, PI)
	return Basis(Quaternion(Vector3.UP, direction))


func _ring(at: Vector3, normal: Vector3, color: Color, radius_from: float, radius_to: float, life: float, thickness: float = 0.06, fill: float = 0.0, wobble: float = 0.0) -> void :
	if not _kit_ready or not at.is_finite(): return
	var fx: Fx = _acquire(_rings)
	fx.active = true
	fx.age = 0.0
	fx.life = maxf(0.05, life)
	fx.origin = at
	fx.orientation = _basis_from_normal(normal)
	fx.color = color
	fx.size_from = maxf(0.01, radius_from)
	fx.size_to = maxf(0.01, radius_to)
	fx.node.set_instance_shader_parameter("thickness", thickness)
	fx.node.set_instance_shader_parameter("fill", fill)
	fx.node.set_instance_shader_parameter("arc", 1.0)
	fx.node.set_instance_shader_parameter("wobble", wobble)
	_place_ring(fx, 0.0)
	fx.node.visible = true

func _place_ring(fx: Fx, t: float) -> void :
	var eased: float = 1.0 - pow(1.0 - t, 3.0)
	var radius: float = lerpf(fx.size_from, fx.size_to, eased)
	fx.node.transform = Transform3D(fx.orientation * Basis.from_scale(Vector3(radius * 2.0, 1.0, radius * 2.0)), fx.origin)
	fx.node.set_instance_shader_parameter("color", Color(fx.color, fx.color.a * pow(1.0 - t, 1.3)))

func _update_rings(delta: float) -> void :
	for fx: Fx in _rings:
		if not fx.active: continue
		fx.age += delta
		if fx.age >= fx.life:
			_retire(fx)
			continue
		_place_ring(fx, fx.age / fx.life)


func _sprite(variant: int, at: Vector3, shape: int, color: Color, size_from: float, size_to: float, life: float, angle: float = 0.0, velocity: Vector3 = Vector3.ZERO, fade_start: float = 0.55) -> Fx:
	if not _kit_ready or not at.is_finite(): return null
	var fx: Fx = _acquire(_sprites[variant])
	fx.active = true
	fx.age = 0.0
	fx.life = maxf(0.05, life)
	fx.origin = at
	fx.velocity = velocity
	fx.color = color
	fx.size_from = size_from
	fx.size_to = size_to
	fx.angle = angle
	fx.spin = 0.0
	fx.fade_start = fade_start
	fx.actor = -1
	fx.follow = false
	fx.node.set_instance_shader_parameter("shape", shape)
	fx.node.set_instance_shader_parameter("angle", angle)
	fx.node.set_instance_shader_parameter("seed", randf() * 10.0)
	_place_sprite(fx, 0.0)
	fx.node.visible = true
	return fx

func _place_sprite(fx: Fx, t: float) -> void :
	var at: Vector3 = fx.origin
	if fx.follow and world.actors.has(fx.actor): at = _render_position(world.actors[fx.actor]) + fx.offset
	var size: float = lerpf(fx.size_from, fx.size_to, 1.0 - (1.0 - t) * (1.0 - t))
	fx.node.transform = Transform3D(Basis.from_scale(Vector3.ONE * maxf(0.001, size)), at)
	var fade_in: float = clampf(fx.age / 0.035, 0.0, 1.0)
	var fade_out: float = 1.0 - smoothstep(fx.fade_start, 1.0, t)
	fx.node.set_instance_shader_parameter("color", Color(fx.color, fx.color.a * fade_in * fade_out))
	fx.node.set_instance_shader_parameter("progress", t)
	if fx.spin != 0.0: fx.node.set_instance_shader_parameter("angle", fx.angle + fx.spin * fx.age)

func _update_sprites(pool: Array, delta: float) -> void :
	for fx: Fx in pool:
		if not fx.active: continue
		fx.age += delta
		if fx.age >= fx.life:
			_retire(fx)
			continue
		fx.origin += fx.velocity * delta
		_place_sprite(fx, fx.age / fx.life)

func _update_lines(delta: float) -> void :
	for fx: Fx in _lines:
		if not fx.active: continue
		fx.age += delta
		if fx.age >= fx.life:
			_retire(fx)
			continue
		var t: float = fx.age / fx.life
		var alpha: float = fx.color.a * clampf(fx.age / 0.03, 0.0, 1.0) * (1.0 - smoothstep(0.55, 1.0, t))
		fx.node.set_instance_shader_parameter("color", Color(fx.color, alpha))
		fx.node.set_instance_shader_parameter("progress", t)

func _update_boxes(delta: float) -> void :
	for fx: Fx in _boxes:
		if not fx.active: continue
		fx.age += delta
		if fx.age >= fx.life:
			_retire(fx)
			continue
		_place_box(fx)

func _place_box(fx: Fx) -> void :
	var center: Vector3 = fx.origin
	if fx.follow and world.actors.has(fx.actor): center = _render_position(world.actors[fx.actor]) + fx.offset
	var fade_in: float = clampf(fx.age / 0.05, 0.0, 1.0)
	var fade_out: float = clampf((fx.life - fx.age) / minf(0.12, fx.life * 0.4), 0.0, 1.0)
	var pop: float = 1.0 + 0.05 * (1.0 - fade_in)
	fx.node.transform = Transform3D(fx.orientation * Basis.from_scale(fx.extent * pop), center)
	fx.node.set_instance_shader_parameter("fade", minf(fade_in, fade_out))



func _emit(kit_index: int, at: Vector3, direction: Vector3, color: Color, reduced: bool = false, power: float = 1.0, spread: float = -1.0) -> void :
	if not _kit_ready or not at.is_finite() or kit_index < 0 or kit_index >= _kits.size(): return
	var kit: Kit = _kits[kit_index]
	var use_reduced: bool = reduced or _reduced_motion() or _low_profile()
	var emitter: CPUParticles3D
	if use_reduced:
		emitter = kit.reduced[kit.cursor_reduced % kit.reduced.size()]
		kit.cursor_reduced += 1
	else:
		emitter = kit.normal[kit.cursor_normal % kit.normal.size()]
		kit.cursor_normal += 1
	if spread >= 0.0: emitter.spread = spread
	emitter.initial_velocity_min = KIT_SPEED_MIN[kit_index] * power
	emitter.initial_velocity_max = KIT_SPEED_MAX[kit_index] * power
	_fire(emitter, at, direction, color)

func _fire(emitter: CPUParticles3D, at: Vector3, direction: Vector3, color: Color) -> void :
	emitter.position = at
	emitter.direction = direction.normalized() if direction.length_squared() > 0.001 else Vector3.UP
	emitter.color = color
	emitter.visible = true
	emitter.restart()

func _flashes_reduced() -> bool:
	return is_instance_valid(world) and bool(world.options.get("reduce_flashes", false))

func _reduced_motion() -> bool:
	return is_instance_valid(world) and is_instance_valid(world.ui) and bool(world.ui.reduced_motion)

func _low_profile() -> bool:

	return is_instance_valid(world) and bool(world.get("mobile_mode")) and str(world.get("mobile_profile")) in ["performance", "battery"]







func visual_fx(cue: String, visual: PaperVisual) -> void :
	if not _kit_ready or not is_instance_valid(visual) or not visible: return
	comic.cue(visual.fx_source(), cue)





func hitbox(data: Dictionary) -> void :
	if not _kit_ready: return
	var cast_id: int = int(data.get("cast_id", 0))
	var actor_id: int = int(data.get("actor", -1))
	if bool(data.get("end", false)):

		for box: Fx in _boxes:
			if box.active and box.cast_id == cast_id and box.actor == actor_id: box.life = minf(box.life, box.age + 0.08)
		return
	var center: Variant = data.get("position", Vector3.ZERO)
	if not center is Vector3 or not center.is_finite(): return
	var aim: Vector3 = data.get("aim", Vector3.FORWARD)
	aim.y = 0.0
	if aim.length_squared() < 0.0001 or not aim.is_finite(): aim = Vector3.FORWARD
	var size: Vector3 = data.get("size", Vector3(3, 2, 3))
	if not size.is_finite(): size = Vector3(3, 2, 3)
	var duration: float = maxf(0.18, float(data.get("duration", 0.2)))
	var fx: Fx = null
	if cast_id != 0:
		for box: Fx in _boxes:
			if box.active and box.cast_id == cast_id and box.actor == actor_id:
				fx = box
				break
	if fx == null:
		fx = _acquire(_boxes)
		fx.age = 0.0
		fx.life = duration
	else:
		fx.life = maxf(fx.life, fx.age + duration)
	fx.active = true
	fx.cast_id = cast_id
	fx.actor = actor_id
	fx.origin = center
	fx.extent = Vector3(maxf(0.05, absf(size.x)), maxf(0.05, absf(size.y)), maxf(0.05, absf(size.z)))
	fx.orientation = Basis.looking_at(aim.normalized(), Vector3.UP)
	fx.follow = bool(data.get("follow", false)) and world.actors.has(actor_id)
	if fx.follow:

		var offset: Variant = data.get("offset")
		fx.offset = offset if offset is Vector3 and offset.is_finite() else center - world.actors[actor_id].position
	_place_box(fx)
	fx.node.visible = true


func shadow_ring(at: Vector3) -> void :
	if not _kit_ready or not at.is_finite(): return
	var reduced: bool = _flashes_reduced()
	_ring(at + Vector3.UP * 0.05, Vector3.UP, Color("24122e", 0.82), 0.25, 1.9, 0.55, 0.42, 0.18, 1.0)
	_ring(at + Vector3.UP * 0.06, Vector3.UP, Color("b3304f", 0.3 if reduced else 0.62), 0.1, 2.25, 0.45, 0.05)
	_emit(KIT_INK, at + Vector3.UP * 0.25, Vector3.UP, Color("2b1736"), false, 0.8)
	_emit(KIT_SMOKE, at + Vector3.UP * 0.35, Vector3.UP, Color("3b2a45"))


func line(from: Vector3, to: Vector3, color: Color, duration: float) -> void :
	if not _kit_ready or not from.is_finite() or not to.is_finite(): return
	var segment: Vector3 = to - from
	if segment.length_squared() < 0.0004: return
	var reduced: bool = _flashes_reduced()
	var fx: Fx = _acquire(_lines)
	fx.active = true
	fx.age = 0.0
	fx.life = maxf(0.08, duration)
	fx.color = Color(color.darkened(0.35), 0.55) if reduced else Color(color, 0.95)
	var width: float = 0.11 if reduced else 0.15
	var side: Vector3 = segment.cross(Vector3.UP)
	if side.length_squared() < 0.0001: side = segment.cross(Vector3.RIGHT)
	side = side.normalized() * width
	var normal: Vector3 = side.cross(segment).normalized() * width
	fx.node.transform = Transform3D(Basis(side, segment, normal), (from + to) * 0.5)
	fx.node.set_instance_shader_parameter("width", width)
	fx.node.set_instance_shader_parameter("mode", 0.0)
	fx.node.set_instance_shader_parameter("color", Color(fx.color, 0.0))
	fx.node.visible = true


func sync_zones(zones: Array) -> void :
	if not _kit_ready: return
	for zone: ZoneFx in _zone_fx: zone.seen = false
	for entry: Variant in zones:
		if not entry is Dictionary: continue
		var position: Variant = entry.get("position")
		if not position is Vector3 or not position.is_finite(): continue
		var chosen: ZoneFx = null
		for zone: ZoneFx in _zone_fx:
			if zone.alive and not zone.seen and zone.position.distance_squared_to(position) < 0.36:
				chosen = zone
				break
		if chosen == null:
			for zone: ZoneFx in _zone_fx:
				if not zone.alive and zone.fade <= 0.0:
					chosen = zone
					break
			if chosen == null: continue
			chosen.alive = true
			chosen.fade = 0.0
			chosen.clock = 0.0
			_ring(position + Vector3.UP * 0.07, Vector3.UP, Color("8ff0d2", 0.7), 0.3, float(entry.get("radius", 5.0)), 0.6, 0.08)
		chosen.seen = true
		chosen.position = position
		chosen.radius = clampf(float(entry.get("radius", 5.0)), 0.5, 30.0)
		chosen.left = float(entry.get("left", entry.get("ttl", 20.0)))
	for zone: ZoneFx in _zone_fx:
		if zone.alive and not zone.seen: zone.alive = false

func burst(at: Vector3, color: Color, count: int) -> void :
	if not at.is_finite(): return
	var reduced: bool = count <= 6
	if _flashes_reduced():
		color = color.darkened(0.28)
		reduced = true
	_emit(KIT_SCRAP, at, Vector3.UP, color, reduced, 0.75)

func impact(at: Vector3, direction: Vector3, attack: String = "slash") -> void :
	if not at.is_finite(): return
	var palette: Color = Color("d78e88")
	var dark_palette: Color = Color("754453")
	match attack:
		"spike", "shadow": palette = Color("c178a6");dark_palette = Color("4c354e")
		"stun", "block": palette = Color("ffe1aa");dark_palette = Color("927e6e")
		"shotgun", "wall": palette = Color("e9cbbb");dark_palette = Color("7b747a")
	var reduced: bool = _flashes_reduced()
	var normal: Vector3 = direction.normalized() if direction.length_squared() > 0.1 else Vector3.FORWARD
	var shard_color: Color = palette.darkened(0.3) if reduced else palette
	_ring(at, normal, Color(palette, 0.34 if reduced else 0.72), 0.04, 0.55 if attack == "block" else 0.42, 0.26, 0.045)

	_emit(KIT_SCRAP, at, normal + Vector3.UP * 0.35, shard_color, reduced, 0.9, 55.0)
	if attack in ["slash", "shadow", "spike", "pounce", "execution"]:
		_emit(KIT_INK, at, normal * 0.6 + Vector3.UP * 0.2, dark_palette.darkened(0.25), reduced, 0.9, 60.0)
	_emit(KIT_SMOKE, at, Vector3.UP, dark_palette, true)
	if attack in ["slash", "shadow", "pounce", "execution"]: _claw_marks(at, normal, palette)

func shock_ring(at: Vector3, color: Color, normal: Vector3, radius: float) -> void :
	if not at.is_finite(): return
	_ring(at, normal, Color(color, 0.34 if _flashes_reduced() else 0.72), 0.04, radius, 0.28, clampf(radius * 0.09, 0.03, 0.14))


func spikes(from: Vector3, to: Vector3) -> void :
	if not _kit_ready or not from.is_finite() or not to.is_finite(): return
	var direction: Vector3 = (to - from).normalized()
	if direction.length_squared() < 0.01: direction = Vector3.FORWARD
	var side: Vector3 = direction.cross(Vector3.UP)
	var count: int = clampi(int(ceil(from.distance_to(to))) + 1, 2, 16)
	var yaw: float = atan2( - direction.x, - direction.z)


	for i: int in range(1, count):
		for row: int in [-1, 1]:
			if _thorns.size() >= THORN_CAPACITY * 2: _thorns.remove_at(0)
			var thorn: Thorn = Thorn.new()
			thorn.position = from.lerp(to, float(i) / float(count - 1)) + side * (float(row) * 0.7)
			thorn.yaw = yaw
			thorn.height = (1.2 + 0.8 * absf(sin(float(i) * 1.7))) * float(row)
			_thorns.append(thorn)
	if _spike_dust_clock <= 0.0:
		_spike_dust_clock = 0.1
		_emit(KIT_INK, from + Vector3.UP * 0.05, Vector3.UP, Color("51384d"), true, 0.7)

func _update_thorns(delta: float) -> void :
	if _thorns.is_empty():
		if _thorn_rows[0].visible or _thorn_rows[1].visible:
			for row: MultiMeshInstance3D in _thorn_rows:
				row.multimesh.visible_instance_count = 0
				row.visible = false
		return
	var life: float = THORN_GROW + THORN_HOLD + THORN_SHRINK
	var counts: Array[int] = [0, 0]
	for index: int in range(_thorns.size() - 1, -1, -1):
		var thorn: Thorn = _thorns[index]
		thorn.age += delta
		if thorn.age >= life: _thorns.remove_at(index)
	for thorn: Thorn in _thorns:
		var grow: float
		if thorn.age < THORN_GROW: grow = lerpf(0.02, 1.0, thorn.age / THORN_GROW)
		elif thorn.age < THORN_GROW + THORN_HOLD: grow = 1.0
		else: grow = lerpf(1.0, 0.01, (thorn.age - THORN_GROW - THORN_HOLD) / THORN_SHRINK)
		var row: int = 0 if thorn.height < 0.0 else 1
		if counts[row] >= THORN_CAPACITY: continue
		var basis: Basis = Basis(Vector3.UP, thorn.yaw) * Basis.from_scale(Vector3(1.0, absf(thorn.height) * grow, 1.0))
		_thorn_rows[row].multimesh.set_instance_transform(counts[row], Transform3D(basis, thorn.position))
		counts[row] += 1
	for row: int in range(2):
		_thorn_rows[row].multimesh.visible_instance_count = counts[row]
		_thorn_rows[row].visible = counts[row] > 0

func _thorn(height: float, lean: float) -> ArrayMesh:
	var surface: SurfaceTool = SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	for level: int in range(4):
		var fraction: float = float(level) / 3.0
		var radius: float = (1.0 - fraction) * 0.31 + 0.006
		var ring: Array[Vector3] = []
		for i: int in range(7):
			var angle: float = float(i) / 7.0 * TAU
			ring.append(Vector3(cos(angle) * radius + fraction * fraction * lean * 0.17, fraction * height, sin(angle) * radius - fraction * fraction * 0.32))
		rings.append(ring)
	for level: int in range(3):
		for i: int in range(7):
			var j: int = (i + 1) % 7
			for vertex: Vector3 in [rings[level][i], rings[level + 1][i], rings[level][j], rings[level][j], rings[level + 1][i], rings[level + 1][j]]: surface.add_vertex(vertex)
	surface.generate_normals();return surface.commit()





func receive(kind: String, data: Dictionary) -> void :
	if not _kit_ready: return
	comic.on_event(kind, data)
	match kind:
		"shadow_decoys": _spawn_decoys(data)
		"hit": _on_hit(data)
		"stun":
			var victim: int = int(data.get("actor", -1))
			if data.has("duration"): _stun_totals[victim] = float(data.get("duration", 0.0))
			var at: Vector3 = data.get("position", _actor_position(victim))
			impact(at + Vector3.UP * 1.25, Vector3.UP, "stun")
		"downed", "death_start":
			var at: Vector3 = data.get("position", Vector3.ZERO)
			_emit(KIT_SMOKE, at + Vector3.UP * 0.12, Vector3.UP, Color("746275"))
			_emit(KIT_INK, at + Vector3.UP * 0.3, Vector3.UP, Color("3a2438"), true, 0.6)
		"revived":
			var at: Vector3 = data.get("position", Vector3.ZERO)
			shock_ring(at + Vector3.UP * 0.08, Color("8de4c5"), Vector3.UP, 0.85)
			burst(at + Vector3.UP * 0.8, Color("b5f0d0"), 10)
		"revive_start":
			shock_ring(_actor_position(int(data.get("target", -1)), data.get("position", Vector3.ZERO)) + Vector3.UP * 0.1, Color("c6e6cd"), Vector3.UP, 0.45)
		"archive_alarm":
			var at: Vector3 = data.get("position", Vector3.ZERO)
			shock_ring(at + Vector3.UP * 0.1, Color("f28b61"), Vector3.UP, 0.85)
			burst(at + Vector3.UP, Color("ffa965"), 7)
		"archive_qte":
			if not bool(data.get("ready", false)) and bool(data.get("success", false)):
				burst(_actor_position(int(data.get("actor", -1))) + Vector3.UP, Color("99d5bf"), 5)
		"block": _on_block(data)
		"protection": _on_protection(data)
		"grab":
			if bool(data.get("wall", false)): impact(_actor_position(int(data.get("actor", -1))) + Vector3.UP, Vector3.UP, "wall")
		"ability":
			if "shotgun" in str(data.get("name", "")).to_lower():
				_delayed.append({"time": 0.16, "kind": "muzzle", "actor": int(data.get("actor", -1))})
		"drone":
			if str(data.get("action", "")) in ["impact", "recycled"]: burst(data.get("position", Vector3.ZERO), Color("c6b5f9"), 10)
		"minion": _on_minion(data)
		"grenade":
			if str(data.get("action", "")) == "explode": _on_flashbang(data)
		"boost", "heal":
			burst(data.get("position", Vector3.ZERO) + Vector3.UP * 0.9, Color("83d1c8"), 7)
		"phase6":
			if bool(data.get("active", false)):
				var at: Vector3 = data.get("position", _actor_position(int(data.get("actor", -1))))
				burst(at + Vector3.UP, Color("92142f"), 24)
				_emit(KIT_SMOKE, at + Vector3.UP * 0.4, Vector3.UP, Color("3d1522"))
				_ring(at + Vector3.UP * 0.07, Vector3.UP, Color("92142f", 0.35 if _flashes_reduced() else 0.7), 0.3, 3.2, 0.7, 0.12, 0.0, 1.0)
		"boost_charge":
			shock_ring(data.get("position", Vector3.ZERO) + Vector3.UP * 0.06, Color("a4a0cf"), Vector3.UP, 0.6)
		"boost_release":
			var at: Vector3 = data.get("position", Vector3.ZERO)
			_emit(KIT_SMOKE, at + Vector3.UP * 0.08, Vector3.UP, Color("8094a6"), true)
			shock_ring(at + Vector3.UP * 0.06, Color("93bcdb"), Vector3.UP, 0.85)
		"outlet_heal":
			if bool(data.get("active", false)):
				var actor: PaperActor = world.actors.get(int(data.get("actor", -1)))
				var at: Vector3 = actor.effects.get("outlet_position", actor.position + Vector3.UP * 0.8) if actor else data.get("position", Vector3.ZERO) + Vector3.UP * 0.8
				burst(at, Color("77bcac"), 3)
		"chocolate", "drone_eaten":
			burst(data.get("position", Vector3.ZERO) + Vector3.UP * 1.1, Color("a6bc91"), 3)
		"true_form_pounce":
			var at: Vector3 = data.get("position", Vector3.ZERO)
			_emit(KIT_SMOKE, at + Vector3.UP * 0.12, Vector3.UP, Color("713743"), true)
			shock_ring(at + Vector3.UP * 0.08, Color("9b4052"), Vector3.UP, 1.0)
		"lysia_explosion":
			var at: Vector3 = data.get("position", Vector3.ZERO)
			shock_ring(at + Vector3.UP * 0.12, Color("c99b79"), Vector3.UP, float(data.get("radius", 7.0)))
			_emit(KIT_SMOKE, at + Vector3.UP * 0.8, Vector3.UP, Color("796879"), _reduced_motion())
			burst(at + Vector3.UP, Color("c9a77d"), 8)
			if not _flashes_reduced(): _sprite(BLEND_ADD, at + Vector3.UP, SHAPE_GLOW, Color("ffd2a0", 0.7), 1.0, 5.0, 0.3)
		"stun_immunity":
			shock_ring(data.get("position", Vector3.ZERO) + Vector3.UP * 0.08, Color("c3344e"), Vector3.UP, 0.85)
		"overheat_charge":
			shock_ring(data.get("position", Vector3.ZERO) + Vector3.UP * 0.07, Color("dd9153"), Vector3.UP, 0.65)
		"overheat":
			if bool(data.get("active", false)): burst(_actor_position(int(data.get("actor", -1))) + Vector3.UP, Color("cfa579"), 5)
		"carry":
			if bool(data.get("active", false)): shock_ring(data.get("position", Vector3.ZERO) + Vector3.UP * 0.06, Color("99b9cd"), Vector3.UP, 0.7)
		"reveal": _on_reveal(data)
		"tracer":

			var from: Variant = data.get("from")
			var to: Variant = data.get("to")
			if from is Vector3 and to is Vector3:
				var tint: Variant = data.get("color", "ffda89")
				var color: Color = tint if tint is Color else Color.from_string(str(tint), Color("ffda89"))
				line(from, to, color, float(data.get("duration", 0.2)))
		"zone":
			var at: Vector3 = data.get("position", Vector3.ZERO)
			_ring(at + Vector3.UP * 0.08, Vector3.UP, Color("8ff0d2", 0.8), 0.2, float(data.get("radius", 5.0)), 0.7, 0.1)
		"escaped": _on_escape(data)
		"eliminated":
			var at: Vector3 = data.get("position", _actor_position(int(data.get("actor", -1))))
			_ring(at + Vector3.UP * 0.06, Vector3.UP, Color("2a1733", 0.7), 0.2, 1.4, 0.8, 0.3, 0.12, 1.0)
			_emit(KIT_SMOKE, at + Vector3.UP * 0.3, Vector3.UP, Color("4a3a55"))

func _on_hit(data: Dictionary) -> void :
	var attack: String = str(data.get("attack", "slash"))
	var at: Vector3 = data.get("position", Vector3.ZERO)
	var victim: PaperActor = world.actors.get(int(data.get("actor", -1)))
	if victim: at = _render_position(victim)
	var source: Vector3 = data.get("source_position", _actor_position(int(data.get("source", -1)), at + Vector3.FORWARD))

	var toward: Vector3 = source - at
	toward.y = 0.0
	if toward.length_squared() < 0.01 and victim: toward = victim.aim
	toward.y = 0.0
	toward = toward.normalized() if toward.length_squared() > 0.001 else Vector3.FORWARD
	var height: float = 0.55 if victim and bool(victim.effects.get("downed", false)) else 1.05
	var point: Vector3 = at + Vector3.UP * height + toward * 0.38
	impact(point, toward, attack)
	if victim and not _flashes_reduced():

		_sprite(BLEND_ADD, at + Vector3.UP * height + toward * 0.2, SHAPE_GLOW, Color(1.0, 0.24, 0.32, 0.5), 1.5, 1.9, 0.14, 0.0, Vector3.ZERO, 0.2)
	if victim and victim.visual.has_method("react_to_hit"):

		victim.visual.react_to_hit(clampf(float(data.get("amount", 20)) / 30.0, 0.35, 1.25), source)

func _claw_marks(at: Vector3, normal: Vector3, color: Color) -> void :
	var reduced: bool = _flashes_reduced()
	var tilt: float = randf_range(-0.5, 0.5)
	if reduced:

		_sprite(BLEND_MIX, at, SHAPE_CLAW, Color(color.darkened(0.2), 0.6), 1.0, 1.15, 0.22, tilt, Vector3.ZERO, 0.45)
		return

	_sprite(BLEND_TOP, at + normal * 0.05, SHAPE_CLAW, Color(color.lightened(0.15), 0.95), 1.05, 1.25, 0.24, tilt, Vector3.ZERO, 0.45)

func _on_block(data: Dictionary) -> void :
	var at: Vector3 = data.get("position", _actor_position(int(data.get("actor", -1))))
	var source: Vector3 = _actor_position(int(data.get("source", -1)), at + Vector3.FORWARD)
	var toward: Vector3 = source - at
	toward.y = 0.0
	toward = toward.normalized() if toward.length_squared() > 0.001 else Vector3.FORWARD
	var point: Vector3 = at + Vector3.UP * 1.2 + toward * 0.55
	var reduced: bool = _flashes_reduced()
	_sprite(BLEND_MIX if reduced else BLEND_ADD, point, SHAPE_SHIELD, Color("d9f2e6", 0.55 if reduced else 0.9), 1.1, 1.45, 0.34, 0.0, Vector3.ZERO, 0.5)
	impact(point, toward, "block")

func _on_protection(data: Dictionary) -> void :
	var guard: Vector3 = data.get("position", _actor_position(int(data.get("actor", -1))))
	var friend: Vector3 = _actor_position(int(data.get("target", -1)), guard)
	var reduced: bool = _flashes_reduced()
	_sprite(BLEND_MIX if reduced else BLEND_ADD, guard + Vector3.UP * 1.2, SHAPE_SHIELD, Color("84dace", 0.5 if reduced else 0.85), 1.3, 1.7, 0.4, 0.0, Vector3.ZERO, 0.5)
	if friend.distance_squared_to(guard) > 0.04:
		line(guard + Vector3.UP * 1.1, friend + Vector3.UP * 1.1, Color("84dace"), 0.35)
		_sprite(BLEND_MIX if reduced else BLEND_ADD, friend + Vector3.UP * 1.2, SHAPE_SHIELD, Color("84dace", 0.4 if reduced else 0.6), 0.9, 1.2, 0.35, 0.0, Vector3.ZERO, 0.5)

func _on_minion(data: Dictionary) -> void :
	var id: int = int(data.get("id", -1))
	var action: String = str(data.get("action", ""))
	var at: Vector3 = data.get("position", Vector3.ZERO)
	if action == "disperse":
		vanished["m" + str(id)] = true
		_emit(KIT_INK, at + Vector3.UP * 0.8, Vector3.UP, Color("66507e"))
		_emit(KIT_SMOKE, at + Vector3.UP * 0.9, Vector3.UP, Color("3b2a45"), true)
		if shadows.has(id):
			_release_shadow(shadows[id])
			shadows.erase(id)
	elif action == "attack" and shadows.has(id): shadows[id].trigger("Slash")
	elif action == "spawn":
		_emit(KIT_INK, at + Vector3.UP * 0.2, Vector3.UP, Color("632339"), true)
		_ring(at + Vector3.UP * 0.05, Vector3.UP, Color("24122e", 0.7), 0.2, 1.1, 0.4, 0.25, 0.1, 1.0)

func _on_flashbang(data: Dictionary) -> void :
	var id: int = int(data.get("id", -1))
	vanished["g" + str(id)] = true
	if grenades.has(id):
		_release_grenade(grenades[id])
		grenades.erase(id)
	var point: Vector3 = data.get("position", Vector3.ZERO)
	var reduced: bool = _flashes_reduced()
	burst(point, Color("656e80") if reduced else Color("dfefff"), 8 if reduced else 18)
	if reduced:

		_sprite(BLEND_MIX, point + Vector3.UP * 0.4, SHAPE_GLOW, Color("1a1f2a", 0.5), 0.6, 3.5, 0.35)
	else:
		_sprite(BLEND_ADD, point + Vector3.UP * 0.4, SHAPE_GLOW, Color("e8f2ff", 1.0), 0.8, 7.0, 0.3, 0.0, Vector3.ZERO, 0.2)
	_ring(point + Vector3.UP * 0.06, Vector3.UP, Color("d5e6ff", 0.3 if reduced else 0.7), 0.2, 3.4, 0.35, 0.07)

	if not reduced and not bool(world.get("mobile_mode")) and str(world.options.get("graphics", "high")) == "high":
		_flash_light.position = point + Vector3.UP * 0.2
		_flash_light.light_energy = 5.0
		_flash_light.visible = true
		_flash_light_age = 0.0

func _update_flash_light(delta: float) -> void :
	if _flash_light_age < 0.0: return
	_flash_light_age += delta
	if _flash_light_age >= 0.3:
		_flash_light.visible = false
		_flash_light.light_energy = 0.0
		_flash_light_age = -1.0
		return
	_flash_light.light_energy = 5.0 * (1.0 - _flash_light_age / 0.3)

func _on_reveal(data: Dictionary) -> void :
	var actor_id: int = int(data.get("actor", -1))
	var at: Vector3 = data.get("position", _actor_position(actor_id, Vector3(INF, INF, INF)))
	if not at.is_finite(): return
	var reduced: bool = _flashes_reduced()
	if bool(data.get("killer_only", false)):

		_ring(at + Vector3.UP * 0.08, Vector3.UP, Color("84dace", 0.35 if reduced else 0.6), 0.4, 9.0, 0.8, 0.07)
		return

	_ring(at + Vector3.UP * 0.05, Vector3.UP, Color("1d0f26", 0.5 if reduced else 0.62), 0.6, 26.0, 1.35, 0.9, 0.0, 1.0)
	_ring(at + Vector3.UP * 0.06, Vector3.UP, Color("c3344e", 0.3 if reduced else 0.55), 0.7, 27.0, 1.3, 0.07)
	_emit(KIT_INK, at + Vector3.UP * 0.3, Vector3.UP, Color("2b1736"), false, 0.9)

func _on_escape(data: Dictionary) -> void :
	var at: Vector3 = data.get("position", _actor_position(int(data.get("actor", -1))))
	if not at.is_finite(): return
	var reduced: bool = _flashes_reduced()
	_emit(KIT_CONFETTI, at + Vector3.UP * 0.9, Vector3.UP, Color.WHITE, reduced)
	_ring(at + Vector3.UP * 0.06, Vector3.UP, Color("f1dfae", 0.4 if reduced else 0.75), 0.3, 2.6, 0.7, 0.07)

	_sprite(BLEND_MIX, at + Vector3.UP * 1.0, SHAPE_SHEET, Color("efe6d2", 0.95), 1.3, 1.1, 0.75, 0.0, Vector3.UP * 1.3, 0.6)
	if not reduced: _sprite(BLEND_ADD, at + Vector3.UP * 1.0, SHAPE_GLOW, Color("f5d98f", 0.6), 1.2, 2.8, 0.4)

func _tick_delayed(delta: float) -> void :
	for index: int in range(_delayed.size() - 1, -1, -1):
		var entry: Dictionary = _delayed[index]
		entry.time = float(entry.time) - delta
		if float(entry.time) > 0.0: continue
		_delayed.remove_at(index)
		if str(entry.kind) == "muzzle": _muzzle(int(entry.actor))

func _muzzle(actor_id: int) -> void :
	if not is_instance_valid(world) or str(world.phase) != "playing" or not world.actors.has(actor_id): return
	var actor: PaperActor = world.actors[actor_id]
	var at: Vector3 = _render_position(actor) + Vector3.UP * 1.28 + actor.aim * 0.65
	if actor.visual.has_method("attachment_position"): at = actor.visual.attachment_position("shotgun_muzzle")
	var reduced: bool = _flashes_reduced()
	shock_ring(at, Color("8c7e71") if reduced else Color("ffe2b5"), actor.aim, 0.18)
	burst(at, Color("827867") if reduced else Color("fff0c5"), 3 if reduced else 7)
	_emit(KIT_SMOKE, at, Vector3.UP, Color("9b9595"), true)
	if not reduced: _sprite(BLEND_ADD, at, SHAPE_GLOW, Color("ffe7b8", 0.9), 0.4, 0.9, 0.09)





func _update_minions(delta: float) -> void :
	_present_ids.clear()
	for info: Dictionary in world.minions:
		var id: int = int(info.id)
		_present_ids[id] = true
		if vanished.has("m" + str(id)): continue
		if not shadows.has(id):
			var fresh: PaperVisual = _take_shadow()
			if not fresh: continue
			shadows[id] = fresh
			fresh.position = info.position
		var model: PaperVisual = shadows[id]
		var before: Vector3 = model.position
		model.position = model.position.lerp(info.position, minf(1.0, delta * 23))
		var aim: Vector3 = info.get("aim", Vector3.FORWARD)
		if aim.length_squared() > 0.01: model.rotation.y = lerp_angle(model.rotation.y, atan2( - aim.x, - aim.z), minf(1.0, delta * 12))
		model.animate(delta, (model.position - before) / maxf(0.001, delta), false, false)
	for id: Variant in shadows.keys():
		if not _present_ids.has(id):
			_release_shadow(shadows[id])
			shadows.erase(id)

func _update_grenades(delta: float) -> void :
	_present_ids.clear()
	for info: Dictionary in world.projectiles:
		var id: int = int(info.id)
		_present_ids[id] = true
		if vanished.has("g" + str(id)): continue
		if not grenades.has(id):
			var fresh: MeshInstance3D = _take_grenade()
			grenades[id] = fresh
			fresh.position = info.position
		var node: MeshInstance3D = grenades[id]
		node.visible = str(info.get("stage", "flight")) == "flight"
		node.position = node.position.lerp(info.position, minf(1.0, delta * 35))
		node.rotation += Vector3(8.0, 4.0, 3.0) * delta
	for id: Variant in grenades.keys():
		if not _present_ids.has(id):
			_release_grenade(grenades[id])
			grenades.erase(id)

func _take_grenade() -> MeshInstance3D:
	_ensure_entity_meshes()
	if not _grenade_free.is_empty():
		var reused: MeshInstance3D = _grenade_free.pop_back()
		reused.rotation = Vector3.ZERO
		reused.show()
		return reused
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = "Flashbang"
	node.mesh = _grenade_mesh
	add_child(node)
	return node

func _release_grenade(node: Variant) -> void :
	if not is_instance_valid(node): return
	node.hide()
	if not _grenade_free.has(node): _grenade_free.append(node)

func _update_drones(delta: float) -> void :
	_present_ids.clear()
	var local: PaperActor = world.local_actor()
	for data: Dictionary in world.drones:
		var id: int = int(data.id)
		_present_ids[id] = true
		if not drone_nodes.has(id):
			var fresh: Dictionary = _take_drone()
			drone_nodes[id] = fresh
			fresh.root.position = data.position
		var record: Dictionary = drone_nodes[id]
		var node: Node3D = record.root
		var state: String = str(data.state)
		node.visible = not (local and int(data.owner) == local.id and bool(local.effects.get("drone_piloting", false)) and str(data.get("mode", "")) == "precise")
		node.position = node.position.lerp(data.position, minf(1, delta * 28))
		var direction: Vector3 = data.get("direction", Vector3.FORWARD)
		if direction.length_squared() > 0.01: node.rotation.y = lerp_angle(node.rotation.y, atan2( - direction.x, - direction.z), minf(1, delta * 12))
		node.rotation.x = lerpf(node.rotation.x, -0.16 if state in ["seeking", "piloted"] else 0.0, minf(1, delta * 8))
		node.rotation.z = lerpf(node.rotation.z, 0.25 if state == "salvage" else sin(world.clock * 5) * 0.025, minf(1, delta * 8))
		var spin: float = 80.0 if state in ["seeking", "piloted"] else 18.0 if state == "launch" else 0.0
		for rotor: Node3D in record.rotors: rotor.rotation.y += delta * spin
		if str(record.state) != state:
			record.state = state

			record.glow.set_instance_shader_parameter("color", Color("e6a45d", 0.75) if state == "salvage" else Color("b49cfb", 0.7))
	for id: Variant in drone_nodes.keys():
		if not _present_ids.has(int(id)):
			_release_drone(drone_nodes[id])
			drone_nodes.erase(id)

func _take_drone() -> Dictionary:
	_ensure_entity_meshes()
	if not _drone_free.is_empty():
		var reused: Dictionary = _drone_free.pop_back()
		reused.root.rotation = Vector3.ZERO
		reused.state = ""
		reused.root.show()
		return reused
	var root: Node3D = Node3D.new()
	root.name = "Drone"
	add_child(root)
	var body: MeshInstance3D = MeshInstance3D.new()
	body.mesh = _drone_body_mesh
	root.add_child(body)
	var rotors_root: Node3D = Node3D.new()
	rotors_root.name = "Rotors"
	root.add_child(rotors_root)
	var rotors: Array[Node3D] = []
	for x: float in [-1.0, 1.0]:
		for z: float in [-1.0, 1.0]:
			var rotor: MeshInstance3D = MeshInstance3D.new()
			rotor.mesh = _rotor_mesh
			rotor.position = Vector3(x * 0.29, 0.055, z * 0.29) + Vector3.UP * 0.012
			rotors_root.add_child(rotor)
			rotors.append(rotor)
	var glow: MeshInstance3D = MeshInstance3D.new()
	glow.name = "StatusGlow"
	glow.mesh = _quad
	glow.material_override = _sprite_materials[BLEND_ADD]
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.position = Vector3(0, 0.16, 0)
	glow.scale = Vector3.ONE * 0.5
	glow.set_instance_shader_parameter("shape", SHAPE_GLOW)
	glow.set_instance_shader_parameter("color", Color("b49cfb", 0.7))
	root.add_child(glow)
	return {"root": root, "rotors": rotors, "glow": glow, "state": ""}

func _release_drone(record: Variant) -> void :
	if not record is Dictionary or not is_instance_valid(record.get("root")): return
	record.root.hide()
	if not _drone_free.has(record): _drone_free.append(record)

func _spawn_decoys(data: Dictionary) -> void :
	for entry: Dictionary in data.get("decoys", []):
		var point: Variant = entry.get("position")
		if not point is Vector3 or not point.is_finite(): continue

		_emit(KIT_INK, point + Vector3.UP * 0.3, Vector3.UP, Color("2b1736"), true, 0.8)
		_ring(point + Vector3.UP * 0.05, Vector3.UP, Color("24122e", 0.75), 0.2, 1.2, 0.45, 0.28, 0.12, 1.0)
		var visual: PaperVisual = _take_shadow()
		if not visual: continue
		visual.position = point
		var aim: Vector3 = entry.get("aim", Vector3.FORWARD)
		visual.rotation.y = atan2( - aim.x, - aim.z)
		decoy_models.append({"model": visual, "time": 0.0, "duration": float(data.get("duration", 1.2))})

func _update_decoys(delta: float) -> void :
	for i: int in range(decoy_models.size() - 1, -1, -1):
		var entry: Dictionary = decoy_models[i];entry.time += delta
		var visual: PaperVisual = entry.model
		if entry.time >= entry.duration:

			_emit(KIT_INK, visual.position + Vector3.UP * 0.9, Vector3.UP, Color("2b1736"), true, 0.7)
			_emit(KIT_SMOKE, visual.position + Vector3.UP * 0.8, Vector3.UP, Color("3b2a45"), true)
			_release_shadow(visual);decoy_models.remove_at(i);continue
		visual.animate(delta, Vector3.ZERO, false, false)
		visual.scale.y = visual._model_scale * clampf(float(entry.time) / 0.22, 0.01, 1.0)

func prepare_shadows() -> void :
	if _dedicated: return
	while shadow_pool.size() < 10:
		var model: PaperVisual = PaperVisual.new()

		model.set("lightweight", true)
		shadow_pool_root.add_child(model)
		model.setup("Alice")
		model.set_shadow_clone(true)
		model.anim_fx.connect(visual_fx.bind(model))
		model.hide()
		shadow_pool.append(model);shadow_free.append(model)

func _take_shadow() -> PaperVisual:
	if shadow_free.is_empty(): return null
	var model: PaperVisual = shadow_free.pop_back()
	model.scale = Vector3.ONE * model._model_scale;model._action = "";model._action_time = 0
	if model.has_method("reset_motion"): model.call("reset_motion")
	model.set_combat_state({});model.set_life_state("alive");model.show()
	return model

func _release_shadow(model: PaperVisual) -> void :
	if not is_instance_valid(model): return
	model.hide();model.scale = Vector3.ONE * model._model_scale
	if not shadow_free.has(model): shadow_free.append(model)





func _hide_zone(zone: ZoneFx) -> void :
	zone.alive = false
	zone.fade = 0.0
	zone.ring.visible = false
	zone.motes.emitting = false
	zone.motes.visible = false

func _update_zones(delta: float) -> void :
	for zone: ZoneFx in _zone_fx:
		if not zone.alive and zone.fade <= 0.0:
			if zone.ring.visible: _hide_zone(zone)
			continue
		zone.clock += delta
		zone.fade = move_toward(zone.fade, 1.0 if zone.alive else 0.0, delta * (2.5 if zone.alive else 3.0))
		if zone.fade <= 0.0 and not zone.alive:
			_hide_zone(zone)
			continue
		zone.left = maxf(0.0, zone.left - delta)
		var ending: float = clampf(zone.left / 2.0, 0.0, 1.0)
		var pulse: float = 0.5 + 0.12 * sin(zone.clock * 2.4)
		var alpha: float = pulse * zone.fade * lerpf(0.35 + 0.35 * absf(sin(zone.clock * 9.0)), 1.0, ending)
		zone.ring.transform = Transform3D(Basis.from_scale(Vector3(zone.radius * 2.0, 1.0, zone.radius * 2.0)), zone.position + Vector3.UP * 0.07)
		zone.ring.set_instance_shader_parameter("color", Color(0.45, 0.95, 0.8, alpha))
		zone.ring.visible = true
		zone.motes.position = zone.position + Vector3.UP * 0.1
		zone.motes.emission_ring_radius = zone.radius * 0.92
		var emit: bool = zone.alive and not _low_profile()
		if emit and not zone.motes.visible: zone.motes.visible = true
		if zone.motes.emitting != emit: zone.motes.emitting = emit

func _update_beacon(delta: float) -> void :
	var flow: Variant = world.get("exit_flow")
	var school: Variant = world.get("school")
	var opened: bool = flow != null and bool(flow.opened) and is_instance_valid(school)
	_beacon_level = move_toward(_beacon_level, 1.0 if opened else 0.0, delta * (1.2 if opened else 2.0))
	var shown: bool = _beacon_level > 0.001
	_beacon.visible = shown
	_beacon_glow.visible = shown
	_beacon_ring.visible = shown
	if not shown: return
	var base: Vector3 = school.escape_position
	var height: float = 46.0
	var reduced: bool = _flashes_reduced()
	var strength: float = _beacon_level * (0.55 if reduced else 1.0)
	_beacon.transform = Transform3D(Basis(Vector3.RIGHT * 2.1, Vector3.UP * height, Vector3.BACK * 2.1), base + Vector3.UP * (height * 0.5))
	_beacon.set_instance_shader_parameter("color", Color(0.98, 0.84, 0.5, 0.72 * strength))
	_beacon.set_instance_shader_parameter("progress", fposmod(_clock * 0.18, 1.0))
	var breathe: float = 1.0 + 0.06 * sin(_clock * 2.2)
	_beacon_glow.transform = Transform3D(Basis.from_scale(Vector3.ONE * 4.2 * breathe), base + Vector3.UP * 1.2)
	_beacon_glow.set_instance_shader_parameter("color", Color(0.98, 0.84, 0.52, 0.35 * strength))
	var ring_radius: float = 2.7 + 0.25 * fposmod(_clock * 0.6, 1.0)
	_beacon_ring.transform = Transform3D(Basis.from_scale(Vector3(ring_radius * 2.0, 1.0, ring_radius * 2.0)), base + Vector3.UP * 0.08)
	_beacon_ring.set_instance_shader_parameter("color", Color(0.91, 0.74, 0.38, 0.6 * strength * (1.0 - fposmod(_clock * 0.6, 1.0))))





func _status_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = _mat(Color(1, 1, 1, 0.32))
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _status_mesh(parent: Node3D, mesh: Mesh, material: StandardMaterial3D) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new();node.mesh = mesh;node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(node)
	return node

func _make_status() -> Dictionary:
	if not _status_free.is_empty(): return _status_free.pop_back()
	if not _status_ring_mesh:
		_status_ring_mesh = TorusMesh.new();_status_ring_mesh.inner_radius = 0.94;_status_ring_mesh.outer_radius = 1.0;_status_ring_mesh.rings = 32;_status_ring_mesh.ring_segments = 4
		_status_shell_mesh = CapsuleMesh.new();_status_shell_mesh.radius = 0.55;_status_shell_mesh.height = 2.1;_status_shell_mesh.radial_segments = 16;_status_shell_mesh.rings = 4
		_status_trail_mesh = PrismMesh.new();_status_trail_mesh.size = Vector3(0.055, 0.045, 1.6)
	var node: Node3D = Node3D.new();node.name = "AbilityStatus";add_child(node)
	var ring_material: StandardMaterial3D = _status_material()
	var shell_material: StandardMaterial3D = _status_material()
	var trail_material: StandardMaterial3D = _status_material()
	var rings: Array[MeshInstance3D] = []
	for index: int in range(3):
		var ring: MeshInstance3D = _status_mesh(node, _status_ring_mesh, ring_material)
		ring.position.y = 0.055 + float(index) * 0.035;rings.append(ring)
	var shell: MeshInstance3D = _status_mesh(node, _status_shell_mesh, shell_material);shell.position.y = 1.0
	var trails: Array[MeshInstance3D] = []
	for side: float in [-1.0, 1.0]:
		var trail: MeshInstance3D = _status_mesh(node, _status_trail_mesh, trail_material)
		trail.position = Vector3(side * 0.3, 0.18, 0.8);trails.append(trail)
	return {"root": node, "rings": rings, "shell": shell, "trails": trails, "ring_material": ring_material, "shell_material": shell_material, "trail_material": trail_material, "color": Color(0, 0, 0, 0)}

func _update_status_visuals(delta: float) -> void :
	var reduced: bool = _flashes_reduced()
	for actor: PaperActor in world.actors.values():
		_update_stun(actor, delta)
		var charging: bool = bool(actor.effects.get("boost_charging", false))
		var boost: bool = float(actor.effects.get("speed_boost", 0)) > 0
		var outlet: bool = float(actor.effects.get("outlet_healing", 0)) > 0
		var immunity: bool = actor.killer and float(actor.effects.get("stun_immunity", 0)) > 0
		var overheat: bool = float(actor.effects.get("overheat_hold", 0)) > 0 or float(actor.effects.get("overheat_charge", 0)) > 0
		var active: bool = actor.alive and not bool(actor.effects.get("escaped", false)) and not bool(actor.effects.get("downed", false)) and (charging or boost or outlet or immunity or overheat)
		if not active:
			if status_nodes.has(actor.id): status_nodes[actor.id].root.hide()
			continue
		if not status_nodes.has(actor.id): status_nodes[actor.id] = _make_status()
		var status: Dictionary = status_nodes[actor.id]; var node: Node3D = status.root
		node.show();node.position = _render_position(actor)
		var direction: Vector3 = Vector3(actor.velocity.x, 0, actor.velocity.z)
		if direction.length_squared() < 0.1: direction = Vector3(actor.aim.x, 0, actor.aim.z)
		if direction.length_squared() > 0.01: node.rotation.y = lerp_angle(node.rotation.y, atan2( - direction.x, - direction.z), minf(1.0, delta * 18.0))
		var color: Color = Color("9a7bdd") if actor.character == "Ashura" else Color("93bcdb")
		if immunity: color = Color("c3344e")
		elif overheat: color = Color("dd9153")
		elif outlet: color = Color("77bcac")
		var tint: Color = Color(color, 0.34 if reduced else 0.6)

		if tint != status.color:
			status.color = tint
			status.ring_material.albedo_color = tint
			status.shell_material.albedo_color = Color(color, 0.055 if reduced else 0.105)
			status.trail_material.albedo_color = Color(color, 0.18 if reduced else 0.36)
		var level: int = clampi(int(actor.effects.get("boost_level", 0)), 0, 3)
		var progress: float = clampf(float(actor.effects.get("charging_boost", 0)) / 3.0, 0, 1)
		for index: int in range(3):
			var ring: MeshInstance3D = status.rings[index]
			ring.visible = not boost and (index == 0 or (charging and level >= index + 1) or (immunity and index == 1))
			var radius: float = 0.52 + float(index) * 0.12 + (progress * 0.16 if charging else 0.0)
			ring.scale = Vector3(radius, 0.6, radius)
			ring.position.y = 0.06 + float(index) * 0.035 if not immunity else 0.07 + float(index) * 0.8
		status.shell.visible = immunity or overheat
		for trail: MeshInstance3D in status.trails:
			trail.visible = boost and direction.length_squared() > 4.0
			trail.scale.z = clampf(direction.length() / 16.0, 0.3, 1.4)
	for id: Variant in status_nodes.keys():
		if not world.actors.has(id):
			status_nodes[id].root.hide()
			_status_free.append(status_nodes[id])
			status_nodes.erase(id)
	for id: Variant in _stuns.keys():
		if not world.actors.has(id):
			_stuns[id].root.hide()
			_stun_free.append(_stuns[id])
			_stuns.erase(id)

func _make_stun() -> Dictionary:
	if not _stun_free.is_empty(): return _stun_free.pop_back()
	var root: Node3D = Node3D.new()
	root.name = "StunIndicator"
	add_child(root)
	var stars: Array[MeshInstance3D] = []
	for i: int in range(4):
		var star: MeshInstance3D = MeshInstance3D.new()
		star.mesh = _quad
		star.material_override = _sprite_materials[BLEND_MIX]
		star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		star.scale = Vector3.ONE * 0.26
		star.set_instance_shader_parameter("shape", SHAPE_STAR)
		star.set_instance_shader_parameter("seed", float(i) * 0.4)
		star.set_instance_shader_parameter("color", Color("f7dc8e") if i % 2 == 0 else Color("f3ead6"))
		root.add_child(star)
		stars.append(star)
	var arc: MeshInstance3D = MeshInstance3D.new()
	arc.mesh = _quad
	arc.material_override = _sprite_materials[BLEND_MIX]
	arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arc.scale = Vector3.ONE * 0.46
	arc.set_instance_shader_parameter("shape", SHAPE_ARC)
	arc.set_instance_shader_parameter("color", Color("f7dc8e", 0.95))
	root.add_child(arc)
	return {"root": root, "stars": stars, "arc": arc, "remaining": 0.0, "total": 0.0, "shown": -1.0}


func _update_stun(actor: PaperActor, delta: float) -> void :
	var remaining: float = float(actor.effects.get("stun", 0.0))
	var visible_now: bool = remaining > 0.02 and actor.alive and actor.visible and is_instance_valid(actor.visual) and actor.visual.visible and not bool(actor.effects.get("shadow_hide", false)) and not bool(actor.effects.get("downed", false))
	if not visible_now:
		if _stuns.has(actor.id):
			var idle: Dictionary = _stuns[actor.id]
			idle.root.hide()
			idle.remaining = 0.0
			idle.total = 0.0
		return
	if not _stuns.has(actor.id): _stuns[actor.id] = _make_stun()
	var stun: Dictionary = _stuns[actor.id]

	if remaining > float(stun.remaining) + 0.05 or float(stun.total) <= 0.0:
		stun.total = maxf(remaining, float(_stun_totals.get(actor.id, 0.0)))
		_stun_totals.erase(actor.id)
	stun.remaining = remaining
	var height: float = 1.9
	if actor.visual.has_method("visual_height"): height = float(actor.visual.visual_height())
	var root: Node3D = stun.root
	root.show()
	root.position = _render_position(actor) + Vector3.UP * (height + 0.3)
	var fraction: float = clampf(remaining / maxf(0.01, float(stun.total)), 0.0, 1.0)
	if absf(fraction - float(stun.shown)) > 0.004:
		stun.shown = fraction
		stun.arc.set_instance_shader_parameter("progress", fraction)
	var calm: bool = _reduced_motion()
	var speed: float = 1.4 if calm else 3.2
	var stars: Array = stun.stars
	for i: int in range(stars.size()):
		var star: MeshInstance3D = stars[i]
		var angle: float = _clock * speed + float(i) * TAU / float(stars.size())
		var bob: float = 0.0 if calm else sin(_clock * 5.0 + float(i) * 1.7) * 0.05
		star.position = Vector3(cos(angle) * 0.42, bob, sin(angle) * 0.42)
		star.set_instance_shader_parameter("angle", _clock * (0.8 if calm else 2.2) + float(i))





func _build_aim() -> void :
	aim_root = Node3D.new();aim_root.name = "SpikeAim";add_child(aim_root)
	aim_fill = MeshInstance3D.new(); var mesh: BoxMesh = BoxMesh.new();mesh.size = Vector3(2.8, 0.018, 1);aim_fill.mesh = mesh
	var material: StandardMaterial3D = _mat(Color(0.95, 0.22, 0.34, 0.16));material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA;material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED;aim_fill.material_override = material
	aim_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aim_root.add_child(aim_fill)

	var shape: PrismMesh = PrismMesh.new();shape.size = Vector3(0.28, 0.018, 0.36)
	var marker_material: StandardMaterial3D = _mat(Color("ff6682"));marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = shape
	multimesh.instance_count = 16
	_aim_multimesh = MultiMeshInstance3D.new()
	_aim_multimesh.multimesh = multimesh
	_aim_multimesh.material_override = marker_material
	_aim_multimesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aim_root.add_child(_aim_multimesh)
	aim_root.hide()

func _update_aim() -> void :
	var actor: PaperActor = world.local_actor()
	aim_root.visible = actor != null and actor.alive and bool(actor.effects.get("spike_aiming", false))
	if not aim_root.visible: return
	var from: Vector3 = actor.position; var direction: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, world.yaw)
	var saved_aim: Vector3 = actor.aim;actor.aim = direction
	var finish: Vector3 = world.combat.spike_endpoint(actor)
	actor.aim = saved_aim
	var distance: float = from.distance_to(finish)
	aim_root.position = _render_position(actor) + Vector3.UP * 0.035
	if direction.length_squared() > 0.01: aim_root.look_at(aim_root.position + direction)
	aim_fill.position = Vector3(0, 0, - distance * 0.5);aim_fill.scale.z = maxf(0.01, distance)
	var multimesh: MultiMesh = _aim_multimesh.multimesh
	for i: int in range(multimesh.instance_count):
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(0, 0.02, - float(i) * distance / 15.0)))

func _update_trajectory() -> void :
	var actor: PaperActor = world.local_actor()
	var show_path: bool = actor != null and actor.character == "Simon" and actor.active() and bool(actor.effects.get("grenade_aiming", false)) and not bool(actor.effects.get("flash_melee", false)) and float(actor.cooldowns.get(0, 0)) <= 0 and not world.pause_open
	if not show_path:
		trajectory.visible = false
		_landing.visible = false
		return
	var points: PackedVector3Array = world.combat.trajectory_preview(actor)
	if points.size() < 2:
		trajectory.visible = false
		_landing.visible = false
		return

	_trajectory_mesh.clear_surfaces()
	_trajectory_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var eye: Vector3 = world.camera.global_position
	for i: int in range(points.size() - 1):
		var edge: Vector3 = points[i + 1] - points[i]
		var side: Vector3 = edge.cross(eye - points[i])
		if side.length_squared() < 1e-06: continue
		side = side.normalized() * 0.022
		_trajectory_mesh.surface_add_vertex(points[i] - side)
		_trajectory_mesh.surface_add_vertex(points[i] + side)
		_trajectory_mesh.surface_add_vertex(points[i + 1] + side)
		_trajectory_mesh.surface_add_vertex(points[i] - side)
		_trajectory_mesh.surface_add_vertex(points[i + 1] + side)
		_trajectory_mesh.surface_add_vertex(points[i + 1] - side)
	_trajectory_mesh.surface_end()
	trajectory.visible = true

	_landing.position = points[-1] + Vector3.UP * 0.03
	_landing.visible = true





func _actor_position(id: int, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if is_instance_valid(world) and world.actors.has(id): return _render_position(world.actors[id])
	return fallback


func _render_position(actor: PaperActor) -> Vector3:
	if _interpolated: return world.actor_render_position(actor)
	return actor.position

func feedback_for_event(kind: String, data: Dictionary) -> Dictionary:
	var feedback: Dictionary = {}
	if not is_instance_valid(world) or str(world.phase) != "playing": return feedback
	var local: PaperActor = world.local_actor()
	if not local: return feedback
	var victim: int = int(data.get("actor", -1)); var source_id: int = int(data.get("source", -1))
	if kind == "hit" and victim == local.id:
		var source: Vector3 = data.get("source_position", _actor_position(source_id, local.position))
		var direction: Vector3 = (source - local.position).normalized()
		var camera: Camera3D = get_viewport().get_camera_3d()
		var angle: float = 0.0
		if camera: angle = atan2(camera.global_basis.x.dot(direction), ( - camera.global_basis.z).dot(direction))
		feedback = {"damage_strength": clampf(float(data.get("amount", 20)) / 60.0, 0.22, 0.65), "duration": 0.42, "direction": angle, "source_position": source, "local_victim": true}
	elif kind in ["hit", "stun"] and source_id == local.id and victim != local.id:
		feedback = {"hit_confirm": true, "stun_confirm": kind == "stun", "duration": 0.28}
	elif kind == "block" and (victim == local.id or source_id == local.id):

		feedback = {"blocked": true, "block_self": victim == local.id, "duration": 0.32}
	elif kind == "protection" and (victim == local.id or int(data.get("target", -1)) == local.id):
		feedback = {"blocked": true, "block_self": true, "duration": 0.32}
	return feedback
