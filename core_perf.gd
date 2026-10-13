extends RefCounted





const WARMUP_FRAMES: int = 30

var enabled: bool = false
var frames_seen: int = 0
var frame_ms: PackedFloat32Array = PackedFloat32Array()
var process_ms: PackedFloat32Array = PackedFloat32Array()
var physics_ms: PackedFloat32Array = PackedFloat32Array()
var main_process_ms: PackedFloat32Array = PackedFloat32Array()
var main_physics_step_ms: PackedFloat32Array = PackedFloat32Array()
var draw_calls: PackedFloat32Array = PackedFloat32Array()
var primitives: PackedFloat32Array = PackedFloat32Array()
var objects: PackedFloat32Array = PackedFloat32Array()
var nodes: PackedFloat32Array = PackedFloat32Array()
var snapshot_bytes: PackedFloat32Array = PackedFloat32Array()
var snapshot_rpcs: PackedFloat32Array = PackedFloat32Array()
var camera_frames: int = 0
var camera_clipped: int = 0
var _last_frame_usec: int = 0
var _camera_probe: PhysicsShapeQueryParameters3D

func begin() -> void :
	enabled = true
	_last_frame_usec = Time.get_ticks_usec()

func sampling() -> bool:
	return enabled and frames_seen >= WARMUP_FRAMES


func sample_frame(viewport: Viewport, main_process_usec: int) -> void :
	if not enabled:
		return
	var now: int = Time.get_ticks_usec()
	var elapsed: int = now - _last_frame_usec
	_last_frame_usec = now
	frames_seen += 1
	if frames_seen <= WARMUP_FRAMES:
		return
	frame_ms.append(float(elapsed) / 1000.0)
	process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	main_process_ms.append(float(main_process_usec) / 1000.0)
	objects.append(Performance.get_monitor(Performance.OBJECT_COUNT))
	nodes.append(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	if viewport:
		draw_calls.append(float(viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)))
		primitives.append(float(viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)))


func sample_physics_step(usec: int) -> void :
	if sampling():
		main_physics_step_ms.append(float(usec) / 1000.0)


func sample_snapshot(bytes: int, rpcs: int) -> void :
	if sampling():
		snapshot_bytes.append(float(bytes))
		snapshot_rpcs.append(float(rpcs))



func probe_camera(camera: Camera3D) -> void :
	if not sampling() or not is_instance_valid(camera) or not camera.is_inside_tree():
		return
	if _camera_probe == null:
		var sphere: SphereShape3D = SphereShape3D.new()
		sphere.radius = 0.12
		_camera_probe = PhysicsShapeQueryParameters3D.new()
		_camera_probe.shape = sphere
		_camera_probe.collision_mask = 1
	_camera_probe.transform = Transform3D(Basis.IDENTITY, camera.global_position)
	camera_frames += 1
	if not camera.get_world_3d().direct_space_state.intersect_shape(_camera_probe, 1).is_empty():
		camera_clipped += 1

static func stats(values: PackedFloat32Array) -> Dictionary:
	if values.is_empty():
		return {"n": 0}
	var sorted: PackedFloat32Array = values.duplicate()
	sorted.sort()
	var total: float = 0.0
	for value: float in sorted:
		total += value
	var p95_index: int = clampi(int(ceil(sorted.size() * 0.95)) - 1, 0, sorted.size() - 1)
	return {"n": sorted.size(), "avg": snappedf(total / sorted.size(), 0.001), "p95": snappedf(sorted[p95_index], 0.001), "max": snappedf(sorted[sorted.size() - 1], 0.001)}

func summary() -> Dictionary:
	return {
		"frames": frame_ms.size(), 
		"frame_ms": stats(frame_ms), 
		"process_ms": stats(process_ms), 
		"physics_ms": stats(physics_ms), 
		"main_process_ms": stats(main_process_ms), 
		"main_physics_step_ms": stats(main_physics_step_ms), 
		"draw_calls": stats(draw_calls), 
		"primitives": stats(primitives), 
		"objects": stats(objects), 
		"nodes": stats(nodes), 
		"snapshot_bytes": stats(snapshot_bytes), 
		"snapshot_rpcs": stats(snapshot_rpcs), 
		"camera_frames": camera_frames, 
		"camera_clip_frames": camera_clipped, 
	}
