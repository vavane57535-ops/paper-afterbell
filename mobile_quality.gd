class_name PaperMobileQuality
extends Node


const PROFILES: Dictionary = {
	"balanced": {"pixels": 1048576.0, "scale_max": 0.85, "msaa": Viewport.MSAA_2X, "lod": 2.0, "shadow_distance": 45.0, "fade_begin": 34.0, "fade_length": 16.0, "fps": 60}, 
	"performance": {"pixels": 737280.0, "scale_max": 0.75, "msaa": Viewport.MSAA_DISABLED, "lod": 3.0, "shadow_distance": 32.0, "fade_begin": 26.0, "fade_length": 12.0, "fps": 60}, 
	"battery": {"pixels": 737280.0, "scale_max": 0.75, "msaa": Viewport.MSAA_DISABLED, "lod": 3.0, "shadow_distance": 32.0, "fade_begin": 26.0, "fade_length": 12.0, "fps": 45}
}




const DESKTOP_PROFILES: Dictionary = {
	"balanced": {"scale": 1.0, "msaa": Viewport.MSAA_2X, "moon_shadow": true, "shadow_distance": 45.0, "fade_begin": 34.0, "fade_length": 10.0, "range_scale": 1.0, "particles": true}, 
	"performance": {"scale": 0.85, "msaa": Viewport.MSAA_DISABLED, "moon_shadow": false, "shadow_distance": 32.0, "fade_begin": 26.0, "fade_length": 8.0, "range_scale": 0.85, "particles": false}, 
	"battery": {"scale": 0.75, "msaa": Viewport.MSAA_DISABLED, "moon_shadow": false, "shadow_distance": 32.0, "fade_begin": 24.0, "fade_length": 8.0, "range_scale": 0.8, "particles": false}, 
}
const VIEW_PROPERTIES: Array[String] = ["scaling_3d_mode", "scaling_3d_scale", "msaa_3d", "screen_space_aa", "mesh_lod_threshold", "anisotropic_filtering_level", "positional_shadow_atlas_size"]
var world: Node3D
var profile: String = "balanced"
var enabled: bool = false

var mobile: bool = false
var _viewport: Viewport
var _original_view: Dictionary = {}
var _original_fps: int = 0
var _lights: Dictionary = {}
var _batches: Array[Dictionary] = []
var _batched_schools: Dictionary = {}
var _unit_box: BoxMesh

func setup(owner_world: Node3D) -> void :
	world = owner_world
	_viewport = world.get_viewport()
	for property: String in VIEW_PROPERTIES: _original_view[property] = _viewport.get(property)
	_original_fps = Engine.max_fps
	var flags: PackedStringArray = OS.get_cmdline_user_args()
	mobile = OS.has_feature("android") or "--mobile-test" in flags or "--mobile-preview" in flags
	for info: Dictionary in world.get_property_list():
		if str(info.name) == "mobile_mode": mobile = mobile or bool(world.get("mobile_mode"));break
	if mobile: apply_mobile_profile()
	if not get_tree().node_added.is_connected(_node_added): get_tree().node_added.connect(_node_added)
	if not _viewport.size_changed.is_connected(_viewport_resized): _viewport.size_changed.connect(_viewport_resized)

func set_profile(requested: String) -> void :
	var normalized: String = requested.to_lower().strip_edges()
	match normalized:
		"équilibré", "equilibre": normalized = "balanced"
		"fluide": normalized = "performance"
		"économie", "economie", "batterie": normalized = "battery"
	if not PROFILES.has(normalized): return
	profile = normalized
	if enabled: apply_mobile_profile()

func apply_mobile_profile() -> void :
	if not is_instance_valid(_viewport): return
	enabled = true
	if mobile:
		var settings: Dictionary = PROFILES[profile]
		_viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		_update_resolution()
		_viewport.msaa_3d = int(settings.msaa)
		_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		_viewport.mesh_lod_threshold = float(settings.lod)
		_viewport.anisotropic_filtering_level = Viewport.ANISOTROPY_4X

		_viewport.positional_shadow_atlas_size = 0
		Engine.max_fps = int(settings.fps)
	else:
		var desktop: Dictionary = DESKTOP_PROFILES[profile]
		_viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		_viewport.scaling_3d_scale = float(desktop.scale)
		_viewport.msaa_3d = int(desktop.msaa)
		Engine.max_fps = _original_fps
	map_rebuilt()
	_refresh_atmosphere()

func _update_resolution() -> void :
	if not enabled or not is_instance_valid(_viewport): return
	if not mobile:
		_viewport.scaling_3d_scale = float(DESKTOP_PROFILES[profile].scale)
		return
	var pixels: Vector2i = world.get_window().size
	if pixels.x <= 0 or pixels.y <= 0: pixels = Vector2i(_viewport.get_visible_rect().size)
	var settings: Dictionary = PROFILES[profile]
	var area: float = maxf(1.0, float(pixels.x) * float(pixels.y))
	_viewport.scaling_3d_scale = clampf(sqrt(float(settings.pixels) / area), 0.5, float(settings.scale_max))

func _viewport_resized() -> void : _update_resolution()

func map_rebuilt() -> void :
	if not enabled or not is_instance_valid(world): return
	for id: int in _lights.keys():
		if not is_instance_valid(_lights[id].ref.get_ref()): _lights.erase(id)
	_scan_lights(world)
	for id: int in _batched_schools.keys():
		if not is_instance_valid(_batched_schools[id].get_ref()): _batched_schools.erase(id)
	for index: int in range(_batches.size() - 1, -1, -1):
		if not is_instance_valid(_batches[index].node.get_ref()): _batches.remove_at(index)
	for child: Node in world.get_children():
		if child is Node3D and child.get_script() != null and child.get_script().resource_path == "res://school.gd":
			_batch_static_boxes(child)
			_set_particles(child, not mobile and bool(DESKTOP_PROFILES[profile].particles))



func _set_particles(school: Node, active: bool) -> void :
	if not school.has_method("ambient_particles"): return
	for node: Node3D in school.ambient_particles():
		if not is_instance_valid(node): continue
		node.visible = active
		if node is CPUParticles3D: node.emitting = active

func _refresh_atmosphere() -> void :

	if is_instance_valid(world) and world.has_method("_map_atmosphere"): world._map_atmosphere()

func _box_is_static(source: MeshInstance3D) -> bool:
	if not source.visible or source.get_script() != null or source.skin != null or source.material_overlay != null: return false
	if not source.mesh is BoxMesh or source.mesh.flip_faces: return false
	if source.mesh.subdivide_width != 0 or source.mesh.subdivide_height != 0 or source.mesh.subdivide_depth != 0: return false
	if source.visibility_range_begin != 0 or source.visibility_range_end != 0 or source.transparency != 0: return false
	if source.has_meta("base_scale") or source.mesh.get_surface_count() != 1: return false
	var material: Material = source.get_active_material(0)


	if material == null or material.next_pass != null: return false
	if material is StandardMaterial3D:
		if material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: return false
	elif not material is ShaderMaterial: return false


	for body: Node in source.get_children():
		if not body is StaticBody3D or body.get_script() != null: return false
		for shape: Node in body.get_children():
			if not shape is CollisionShape3D or shape.get_child_count() > 0 or shape.get_script() != null: return false
	return true

func _batch_static_boxes(school: Node3D) -> void :
	var school_id: int = school.get_instance_id()
	if _batched_schools.has(school_id): return
	_batched_schools[school_id] = weakref(school)
	if _unit_box == null: _unit_box = BoxMesh.new();_unit_box.size = Vector3.ONE
	var groups: Dictionary = {}
	for source: Node in school.get_children():
		if not source is MeshInstance3D or not _box_is_static(source): continue
		var cell: Vector2i = Vector2i(floori(source.position.x / 16.0), floori(source.position.z / 16.0))
		var key: String = str(source.get_active_material(0).get_instance_id()) + "/" + str(cell) + "/" + str(source.cast_shadow) + "/" + str(source.layers) + "/" + str(source.gi_mode) + "/" + str(source.extra_cull_margin)
		if not groups.has(key): groups[key] = []
		groups[key].append(source)
	for members: Array in groups.values():
		if members.size() < 6: continue
		var geometry: MultiMesh = MultiMesh.new();geometry.transform_format = MultiMesh.TRANSFORM_3D;geometry.mesh = _unit_box;geometry.instance_count = members.size()
		var bounds: AABB = AABB(); var first: bool = true; var valid: bool = true
		var sources: Array[Dictionary] = []
		for index: int in range(members.size()):
			var source: MeshInstance3D = members[index]
			var transform: Transform3D = source.transform * Transform3D(Basis.from_scale(source.mesh.size), Vector3.ZERO)
			var original: AABB = source.transform * source.mesh.get_aabb()
			var replacement: AABB = transform * _unit_box.get_aabb()

			if original.position.distance_to(replacement.position) > 0.0001 or original.size.distance_to(replacement.size) > 0.0001: valid = false;break
			geometry.set_instance_transform(index, transform)
			bounds = original if first else bounds.merge(original);first = false
			sources.append({"ref": weakref(source), "visible": source.visible, "transform": source.transform, "box_size": source.mesh.size})
		if not valid: continue
		geometry.custom_aabb = bounds
		var batch: MultiMeshInstance3D = MultiMeshInstance3D.new();batch.name = "MobileStaticBoxes"
		batch.multimesh = geometry;batch.material_override = members[0].get_active_material(0)
		batch.cast_shadow = members[0].cast_shadow;batch.layers = members[0].layers;batch.gi_mode = members[0].gi_mode;batch.extra_cull_margin = members[0].extra_cull_margin
		school.add_child(batch)
		_batches.append({"node": weakref(batch), "sources": sources, "bounds": bounds})

		for source: MeshInstance3D in members: source.visible = false

func _scan_lights(node: Node) -> void :
	if node is Light3D: _apply_light(node)
	for child: Node in node.get_children(): _scan_lights(child)

func _node_added(node: Node) -> void :

	if enabled and node is Light3D: call_deferred("_apply_new_light", weakref(node))

func _apply_new_light(reference: WeakRef) -> void :
	var light: Light3D = reference.get_ref() as Light3D
	if enabled and is_instance_valid(light) and world.is_ancestor_of(light): _apply_light(light)

func _apply_light(light: Light3D) -> void :
	var id: int = light.get_instance_id()
	if not _lights.has(id):
		var original: Dictionary = {"shadow_enabled": light.shadow_enabled}
		if light is DirectionalLight3D:
			original.directional_shadow_mode = light.directional_shadow_mode
			original.directional_shadow_max_distance = light.directional_shadow_max_distance
			original.directional_shadow_blend_splits = light.directional_shadow_blend_splits
		else:
			original.distance_fade_enabled = light.distance_fade_enabled
			original.distance_fade_begin = light.distance_fade_begin
			original.distance_fade_length = light.distance_fade_length
			if light is OmniLight3D: original.omni_range = light.omni_range
		_lights[id] = {"ref": weakref(light), "properties": original}
	var properties: Dictionary = _lights[id].properties
	var settings: Dictionary = PROFILES[profile] if mobile else DESKTOP_PROFILES[profile]
	if light is DirectionalLight3D:
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		light.directional_shadow_max_distance = minf(float(properties.directional_shadow_max_distance), float(settings.shadow_distance))
		light.directional_shadow_blend_splits = true
		if not mobile: light.shadow_enabled = bool(properties.shadow_enabled) and bool(settings.moon_shadow)
	else:
		light.shadow_enabled = false
		light.distance_fade_enabled = true
		light.distance_fade_begin = float(settings.fade_begin)
		light.distance_fade_length = float(settings.fade_length)
		if light is OmniLight3D and properties.has("omni_range"):
			light.omni_range = float(properties.omni_range) * float(settings.get("range_scale", 1.0))

func restore_desktop_profile() -> void :
	enabled = false
	if is_instance_valid(_viewport):
		for property: String in _original_view: _viewport.set(property, _original_view[property])
	Engine.max_fps = _original_fps
	for entry: Dictionary in _lights.values():
		var light: Light3D = entry.ref.get_ref() as Light3D
		if is_instance_valid(light):
			for property: String in entry.properties: light.set(property, entry.properties[property])
	_lights.clear()
	for record: Dictionary in _batches:
		for source_record: Dictionary in record.sources:
			var source: MeshInstance3D = source_record.ref.get_ref() as MeshInstance3D
			if is_instance_valid(source): source.visible = bool(source_record.visible)
		var batch: MultiMeshInstance3D = record.node.get_ref() as MultiMeshInstance3D
		if is_instance_valid(batch): batch.visible = false;batch.queue_free()
	_batches.clear();_batched_schools.clear()
	if is_instance_valid(world):
		for child: Node in world.get_children():
			if child is Node3D and child.get_script() != null and child.get_script().resource_path == "res://school.gd":
				_set_particles(child, true)
	_refresh_atmosphere()

func snapshot() -> Dictionary:
	if not is_instance_valid(_viewport): return {"enabled": false}
	var sources: int = 0
	for record: Dictionary in _batches: sources += record.sources.size()
	return {"enabled": enabled, "profile": profile, "render_scale": _viewport.scaling_3d_scale, "msaa": _viewport.msaa_3d, "fps_cap": Engine.max_fps, "physics_hz": Engine.physics_ticks_per_second, "mesh_lod": _viewport.mesh_lod_threshold, "lights": _lights.size(), "shadow_atlas": _viewport.positional_shadow_atlas_size, "static_box_batches": _batches.size(), "static_box_sources": sources, "static_draw_reduction": sources - _batches.size()}
