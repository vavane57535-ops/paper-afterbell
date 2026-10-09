extends RefCounted
class_name PaperToon

const SURFACE = preload("res://toon_surface.gdshader")
const INK = preload("res://character_ink.gdshader")
const MAP_SURFACE = preload("res://map_toon.gdshader")
const MAP_RENDER_MODE: String = "render_mode specular_disabled, cull_back;"


static var _cache: Dictionary = {}
static var _map_double_sided: Shader

static func material(source: Material, outline: bool = true) -> Material:
	if not source is StandardMaterial3D: return source
	var base: StandardMaterial3D = source as StandardMaterial3D

	if base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or base.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED: return source
	var key: StringName = &"paper_toon_outline" if outline else &"paper_toon_plain"
	if base.has_meta(key):
		var cached: Variant = base.get_meta(key)
		if cached is Material: return cached
	var result: ShaderMaterial
	if base.has_meta("paper_map"):
		result = _map_material(base)
	else:
		result = ShaderMaterial.new();result.shader = SURFACE
		result.set_shader_parameter("paper_color", base.albedo_color)
		result.set_shader_parameter("textured", base.albedo_texture != null)
		if base.albedo_texture: result.set_shader_parameter("paper_texture", base.albedo_texture)
		result.set_shader_parameter("use_vertex_color", base.vertex_color_use_as_albedo)
		if base.emission_enabled:
			result.set_shader_parameter("glow_color", base.emission)
			result.set_shader_parameter("glow_energy", base.emission_energy_multiplier)
	if outline:
		var ink: ShaderMaterial = ShaderMaterial.new();ink.shader = INK
		ink.set_shader_parameter("width", 0.003)
		result.next_pass = ink
	base.set_meta(key, result)
	return result



static func _map_material(base: StandardMaterial3D) -> ShaderMaterial:
	var result: ShaderMaterial = ShaderMaterial.new()
	result.shader = _double_sided_shader() if base.cull_mode == BaseMaterial3D.CULL_DISABLED else MAP_SURFACE
	result.set_shader_parameter("paper_color", base.albedo_color)
	result.set_shader_parameter("use_vertex_color", base.vertex_color_use_as_albedo)
	if base.albedo_texture:
		result.set_shader_parameter("textured", true)
		result.set_shader_parameter("paper_texture", base.albedo_texture)
	if base.emission_enabled:
		result.set_shader_parameter("glow_color", base.emission)
		result.set_shader_parameter("glow_energy", base.emission_energy_multiplier)
	var extra: Variant = base.get_meta("paper_map")
	if extra is Dictionary:
		for uniform_name: String in extra:
			result.set_shader_parameter(uniform_name, extra[uniform_name])
	return result

static func _double_sided_shader() -> Shader:
	if _map_double_sided == null:
		_map_double_sided = Shader.new()
		_map_double_sided.code = MAP_SURFACE.code.replace(MAP_RENDER_MODE, "render_mode specular_disabled, cull_disabled;")
	return _map_double_sided

static func apply_tree(root: Node, include_outlines: bool = true) -> void :
	if root is MeshInstance3D:
		var item: MeshInstance3D = root
		if item.material_override: item.material_override = material(item.material_override, include_outlines)
		elif item.mesh:
			for index in range(item.mesh.get_surface_count()):
				item.set_surface_override_material(index, material(item.get_active_material(index), include_outlines))
	elif root is MultiMeshInstance3D:
		var batch: MultiMeshInstance3D = root
		if batch.material_override: batch.material_override = material(batch.material_override, include_outlines)
		elif batch.multimesh and batch.multimesh.mesh:
			var geometry: Mesh = batch.multimesh.mesh.duplicate()
			for index in range(geometry.get_surface_count()):
				geometry.surface_set_material(index, material(geometry.surface_get_material(index), include_outlines))
			batch.multimesh.mesh = geometry
	for child in root.get_children(): apply_tree(child, include_outlines)
