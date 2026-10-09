extends RefCounted





const TOON: Shader = preload("res://char_toon.gdshader")
const OUTLINE: Shader = preload("res://char_outline.gdshader")
const REVEAL: Shader = preload("res://char_reveal.gdshader")
const BLOB: Shader = preload("res://char_blob_shadow.gdshader")
const CLONE_COLOR: Color = Color("191123")

static var _skins: Dictionary = {}
static var _flats: Dictionary = {}
static var _outlines: Dictionary = {}
static var _clone: ShaderMaterial
static var _blob: ShaderMaterial
static var _blob_mesh: PlaneMesh
static var _outlines_enabled: bool = true



static func skin(source: Material) -> Material:
	if not source is BaseMaterial3D:
		return source
	var base: BaseMaterial3D = source as BaseMaterial3D
	if base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return source
	var key: int = source.get_instance_id()
	if _skins.has(key):
		return _skins[key]
	var result: ShaderMaterial = ShaderMaterial.new()
	result.shader = TOON
	result.set_shader_parameter("albedo_color", base.albedo_color)
	if base.albedo_texture != null:
		result.set_shader_parameter("albedo_tex", base.albedo_texture)
		result.set_shader_parameter("textured", true)
	result.set_shader_parameter("use_vertex_color", base.vertex_color_use_as_albedo)
	if base.emission_enabled:
		result.set_shader_parameter("glow_color", base.emission)
		result.set_shader_parameter("glow_energy", base.emission_energy_multiplier)
	result.set_meta("ink", _outline(base.albedo_texture, base.albedo_color))
	if _outlines_enabled:
		result.next_pass = result.get_meta("ink")
	_skins[key] = result
	return result



static func flat(color: Color, glow: float = 0.0, outline: bool = true) -> ShaderMaterial:
	var key: String = color.to_html() + "/" + str(snappedf(glow, 0.01)) + "/" + str(outline)
	if _flats.has(key):
		return _flats[key]
	var result: ShaderMaterial = _make_flat(color, glow)
	if outline:
		result.set_meta("ink", _outline(null, color))
		if _outlines_enabled:
			result.next_pass = result.get_meta("ink")
	_flats[key] = result
	return result



static func glow(color: Color, energy: float = 1.5) -> ShaderMaterial:
	return _make_flat(color, energy)



static func clone_tint() -> ShaderMaterial:
	if _clone == null:
		_clone = _make_flat(CLONE_COLOR, 0.0)
		_clone.set_shader_parameter("fill_energy", 0.1)
		_clone.set_shader_parameter("rim_amount", 0.4)
		_clone.set_shader_parameter("shade_tint", Color("6b4a8a"))
		_clone.set_meta("ink", _outline(null, Color("0b0710")))
		if _outlines_enabled:
			_clone.next_pass = _clone.get_meta("ink")
	return _clone



static func reveal(color: Color) -> ShaderMaterial:
	var result: ShaderMaterial = ShaderMaterial.new()
	result.shader = REVEAL
	result.set_shader_parameter("tint", color)
	result.set_shader_parameter("occluded_hint", 0.0)
	return result


static func blob_material() -> ShaderMaterial:
	if _blob == null:
		_blob = ShaderMaterial.new()
		_blob.shader = BLOB
	return _blob


static func blob_mesh() -> PlaneMesh:
	if _blob_mesh == null:
		_blob_mesh = PlaneMesh.new()
		_blob_mesh.size = Vector2.ONE
	return _blob_mesh



static func set_outlines_enabled(enabled: bool) -> void :
	if enabled == _outlines_enabled:
		return
	_outlines_enabled = enabled
	var all: Array = _skins.values() + _flats.values()
	if _clone != null:
		all.append(_clone)
	for item: Variant in all:
		var material: ShaderMaterial = item as ShaderMaterial
		if material == null or not material.has_meta("ink"):
			continue
		material.next_pass = material.get_meta("ink") if enabled else null


static func outlines_enabled() -> bool:
	return _outlines_enabled


static func _make_flat(color: Color, glow_energy: float) -> ShaderMaterial:
	var result: ShaderMaterial = ShaderMaterial.new()
	result.shader = TOON
	result.set_shader_parameter("albedo_color", color)
	if glow_energy > 0.0:
		result.set_shader_parameter("glow_color", color)
		result.set_shader_parameter("glow_energy", glow_energy)
	return result


static func _outline(texture: Texture2D, color: Color) -> ShaderMaterial:
	var key: String = (str(texture.get_instance_id()) if texture != null else "flat") + "/" + color.to_html()
	if _outlines.has(key):
		return _outlines[key]
	var ink: ShaderMaterial = ShaderMaterial.new()
	ink.shader = OUTLINE
	ink.set_shader_parameter("albedo_color", color)
	if texture != null:
		ink.set_shader_parameter("albedo_tex", texture)
		ink.set_shader_parameter("textured", true)
	_outlines[key] = ink
	return ink
