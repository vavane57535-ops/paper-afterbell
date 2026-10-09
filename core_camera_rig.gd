extends RefCounted








const PITCH_MIN: float = -0.6
const PITCH_MAX: float = 0.55
const PROBE_RADIUS: float = 0.25


const PULL_IN_SLACK: float = 0.08
const PULL_IN_RATE: float = 24.0
const PUSH_OUT_RATE: float = 3.0
const SHOULDER: float = 0.6
const BOOM_LENGTH: float = 4.6
const DOWNED_BOOM_LENGTH: float = 3.3
const HEAD_HEIGHT: float = 1.5
const DOWNED_HEAD_HEIGHT: float = 0.68


const ELEVATION_BASE: float = 0.15
const ELEVATION_GAIN: float = 0.66
const HIDE_DISTANCE: float = 1.65
const SPECTATOR_BLEND_TIME: float = 0.75
const SHAKE_DECAY: float = 1.7
const SPRINT_FOV_KICK: float = 6.0
const TRUE_FORM_FOV_KICK: float = 12.0
const BOOST_FOV_KICK: float = 4.0
const DRONE_FOV: float = 86.0
const VIEW_DRONE: int = -2

var world: Node
var camera: Camera3D
var trauma: float = 0.0
var _probe: PhysicsShapeQueryParameters3D
var _boom: float = BOOM_LENGTH
var _downed: float = 0.0
var _shake_clock: float = 0.0
var _view_id: int = -1
var _blend: float = 0.0
var _blend_from: Transform3D = Transform3D.IDENTITY
var _following: bool = false
var _fov: float = 72.0
var _punch: float = 0.0
var _kick: Vector3 = Vector3.ZERO
var _kick_velocity: Vector3 = Vector3.ZERO

func setup(owner: Node, target_camera: Camera3D) -> void :
	world = owner
	camera = target_camera
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = PROBE_RADIUS
	_probe = PhysicsShapeQueryParameters3D.new()
	_probe.shape = sphere
	_probe.collision_mask = 1
	_probe.collide_with_areas = false
	_probe.collide_with_bodies = true

func reset() -> void :
	_following = false
	_view_id = -1
	_blend = 0.0
	_boom = BOOM_LENGTH
	_downed = 0.0
	trauma = 0.0
	_punch = 0.0
	_kick = Vector3.ZERO
	_kick_velocity = Vector3.ZERO

func add_trauma(amount: float) -> void :
	trauma = clampf(trauma + amount, 0.0, 1.0)



func punch(degrees: float) -> void :
	_punch = clampf(_punch + degrees * float(world.shake_scale()), -9.0, 14.0)



func kick(direction: Vector3, amount: float) -> void :
	if direction.length_squared() < 0.0001 or not direction.is_finite():
		return
	_kick_velocity += direction.normalized() * clampf(amount, 0.0, 0.3) * 22.0 * float(world.shake_scale())


func cast_fraction(from: Vector3, to: Vector3) -> float:
	var motion: Vector3 = to - from
	if motion.length_squared() < 1e-06 or not camera.is_inside_tree():
		return 1.0
	_probe.transform = Transform3D(Basis.IDENTITY, from)
	_probe.motion = motion
	var result: PackedFloat32Array = camera.get_world_3d().direct_space_state.cast_motion(_probe)
	return result[0] if not result.is_empty() else 1.0

func update(delta: float) -> void :
	var hidden: PaperActor = world.camera_obscured_actor
	if is_instance_valid(hidden):
		hidden.visual.visible = not bool(hidden.effects.get("shadow_hide", false))
	world.camera_obscured_actor = null
	var phase: String = str(world.phase)
	var pilot: PaperActor = world.local_actor()
	if phase == "playing" and pilot and bool(pilot.effects.get("drone_piloting", false)) and _drone_view(pilot):
		return
	if phase in ["menu", "lobby"]:
		_following = false
		if world.menu_stage:
			world.menu_stage.frame_camera(camera, delta, str(world.preview_character), float(world.preview_angle), float(world.menu_focus_x))
		return
	if world.menu_stage:
		world.menu_stage.reset_camera()
	var actor: PaperActor = world._view_actor()
	if not actor:
		return
	var target: Vector3 = world.actor_render_position(actor) + Vector3.UP * (DOWNED_HEAD_HEIGHT if bool(actor.effects.get("downed", false)) else HEAD_HEIGHT)
	if phase == "intro":
		var alpha: float = clampf(float(world.cinema) / 5.0, 0.0, 1.0)
		var offset: Vector3 = Vector3(4.5 * (1.0 - alpha), 2.0, 6.5).rotated(Vector3.UP, float(world.yaw) + 0.6 * (1.0 - alpha))
		camera.position = target + offset
		camera.look_at(target)
		camera.fov = 62.0 + alpha * 10.0
		return
	if phase == "ending":
		_ending_view(delta, actor, target)
		return
	_follow(delta, actor)

func _drone_view(pilot: PaperActor) -> bool:
	var drone: Dictionary = world.combat.piloted_drone(pilot)
	if drone.is_empty():
		return false
	var pitch: float = float(world.pitch)
	var direction: Vector3 = Vector3(0.0, sin(pitch), - cos(pitch)).rotated(Vector3.UP, float(world.yaw))
	camera.position = Vector3(drone.position) + direction * 0.15
	camera.look_at(camera.position + direction)
	camera.fov = DRONE_FOV
	pilot.visual.visible = false
	world.camera_obscured_actor = pilot
	_view_id = VIEW_DRONE
	return true

func _ending_view(delta: float, actor: PaperActor, target: Vector3) -> void :
	var offset: Vector3 = Vector3(1.8, 0.9, -3.8).rotated(Vector3.UP, actor.visual.rotation.y + sin(float(world.cinema) * 0.18) * 0.25)
	var goal: Vector3 = target + offset
	goal = target.lerp(goal, cast_fraction(target, goal))
	camera.position = camera.position.lerp(goal, minf(1.0, delta * 2.0))
	if camera.position.distance_squared_to(target) > 0.01:
		camera.look_at(target)

func _follow(delta: float, actor: PaperActor) -> void :
	var view_id: int = int(actor.id)
	if _following and view_id != _view_id:

		_blend = 1.0
		_blend_from = camera.global_transform
		world.camera_anchor_ready = false
		_boom = BOOM_LENGTH
		_fov = camera.fov
	elif not _following:
		_fov = camera.fov
	_view_id = view_id
	_following = true
	var downed: bool = bool(actor.effects.get("downed", false))
	_downed = move_toward(_downed, 1.0 if downed else 0.0, delta * 2.5)
	var target: Vector3 = world.actor_render_position(actor) + Vector3.UP * lerpf(HEAD_HEIGHT, DOWNED_HEAD_HEIGHT, _downed)
	var smooth: bool = bool(world.options.get("camera_smooth", true))
	if not world.camera_anchor_ready or world.camera_anchor.distance_to(target) > 12.0:
		world.camera_anchor = target
		world.camera_anchor_ready = true
	else:
		world.camera_anchor = world.camera_anchor.lerp(target, 1.0 - exp( - delta * (18.0 if smooth else 60.0)))
	var pivot: Vector3 = world.camera_anchor
	var yaw: float = float(world.yaw)
	var pitch: float = clampf(float(world.pitch), PITCH_MIN, PITCH_MAX)
	var elevation: float = ELEVATION_BASE - pitch * ELEVATION_GAIN
	var back: Vector3 = Vector3(0.0, sin(elevation), cos(elevation)).rotated(Vector3.UP, yaw)
	var right: Vector3 = Vector3.RIGHT.rotated(Vector3.UP, yaw)

	var shoulder: Vector3 = pivot + right * SHOULDER * (1.0 - 0.4 * _downed)
	var origin: Vector3 = pivot.lerp(shoulder, cast_fraction(pivot, shoulder))
	var length: float = lerpf(BOOM_LENGTH, DOWNED_BOOM_LENGTH, _downed)
	var allowed: float = length * cast_fraction(origin, origin + back * length)
	if allowed < _boom:
		_boom = minf(lerpf(_boom, allowed, 1.0 - exp( - delta * PULL_IN_RATE)), allowed + PULL_IN_SLACK)
	else:
		_boom = lerpf(_boom, allowed, 1.0 - exp( - delta * PUSH_OUT_RATE))
	var eye: Vector3 = origin + back * _boom
	var focus: Vector3 = pivot + Vector3.FORWARD.rotated(Vector3.UP, yaw)
	var goal: Transform3D = Transform3D(Basis.looking_at(focus - eye, Vector3.UP), eye)
	if _blend > 0.0:
		_blend = maxf(0.0, _blend - delta / SPECTATOR_BLEND_TIME)
		camera.global_transform = _blend_from.interpolate_with(goal, smoothstep(0.0, 1.0, 1.0 - _blend))
	else:
		camera.global_transform = goal
	if eye.distance_to(pivot) < HIDE_DISTANCE:
		actor.visual.visible = false
		world.camera_obscured_actor = actor
	var fov: float = float(world.base_fov())
	if float(actor.effects.get("phase6", 0.0)) > 0.0:
		fov += TRUE_FORM_FOV_KICK
	elif bool(actor.effects.get("running", false)):
		fov += SPRINT_FOV_KICK
	if float(actor.effects.get("speed_boost", 0.0)) > 0.0 or float(actor.effects.get("boost_time", 0.0)) > 0.0:
		fov += BOOST_FOV_KICK
	_fov = lerpf(_fov, fov, 1.0 - exp( - delta * 5.0))
	_punch = lerpf(_punch, 0.0, 1.0 - exp( - delta * 9.0))
	camera.fov = clampf(_fov + _punch, 40.0, 112.0)

	var step: float = minf(delta, 0.034)
	_kick_velocity += ( - _kick * 180.0 - _kick_velocity * 16.0) * step
	_kick += _kick_velocity * step
	if _kick.length_squared() > 4e-06:
		camera.global_position += _kick.limit_length(0.3)
	_apply_shake(delta)


func _apply_shake(delta: float) -> void :

	if float(world.camera_shake) > 0.0:
		add_trauma(float(world.camera_shake) * 3.0)
		world.camera_shake = 0.0
	if trauma <= 0.0:
		return
	trauma = maxf(0.0, trauma - delta * SHAKE_DECAY)
	var amount: float = trauma * trauma * float(world.shake_scale())
	if amount <= 0.0001:
		return
	_shake_clock += delta
	var t: float = _shake_clock
	var pitch_offset: float = 0.03 * amount * (sin(t * 41.0) * 0.7 + sin(t * 97.0 + 1.7) * 0.3)
	var yaw_offset: float = 0.022 * amount * (sin(t * 37.0 + 0.5) * 0.7 + sin(t * 83.0 + 2.9) * 0.3)
	var roll_offset: float = 0.045 * amount * (sin(t * 29.0 + 1.1) * 0.7 + sin(t * 71.0 + 0.3) * 0.3)
	camera.rotate_object_local(Vector3.RIGHT, pitch_offset)
	camera.rotate_object_local(Vector3.UP, yaw_offset)
	camera.rotate_object_local(Vector3.BACK, roll_offset)
