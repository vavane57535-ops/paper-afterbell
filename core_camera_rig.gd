extends RefCounted

# Caméra de jeu à la troisième personne (+ vue drone, intro, fin de manche).
#
# Deux modes, basculés par l'action « camera_mode » (C / clic du stick droit par défaut)
# et mémorisés dans user://settings.cfg (section « camera ») :
#   MODE_BEHIND « Derrière »  : caméra centrée pile derrière le dos ; le personnage tourne avec la souris.
#   MODE_FREE   « Libre 360° » : la caméra orbite autour du personnage sans le faire pivoter ;
#                                il avance dans la direction de la caméra et regarde où il va.
# Dans les deux modes, l'axe de la caméra est exactement (world.yaw, world.pitch) : les décalages
# d'épaule et de hauteur sont des translations, jamais des rotations, donc « avancer » suit l'axe de l'écran.
#
# Plans cinématiques en jeu (exécutions…) : un système prend la caméra puis la rend.
#   world.camera_rig.take_control(self, 0.25)             # le rig n'écrit plus la caméra
#   world.camera_rig.drive(self, transform, fov)          # facultatif : place la caméra (fondu d'entrée inclus)
#                                                         # sans drive(), le propriétaire écrit world.camera lui-même
#   world.camera_rig.release_control(self, 0.45)          # rend la main : fondu vers la vue de jeu
#   world.camera_rig.gameplay_transform()                 # où serait la caméra de jeu (pour partir de là)
# Un propriétaire libéré (queue_free) rend la main automatiquement. Pendant la prise de contrôle,
# la souris et le stick ne tournent plus la caméra (lock_look = true par défaut).

const CameraBadge = preload("res://camera_mode_badge.gd")

const MODE_BEHIND: String = "behind"
const MODE_FREE: String = "free"
const FACING_LEGACY: int = 0
const FACING_BEHIND: int = 1
const FACING_FREE: int = 2
const SETTINGS_VERSION: int = 1

# Angle de visée vertical réel de la caméra (rad) : -77° (vers le bas) à +69° (vers le haut).
const PITCH_MIN: float = -1.35
const PITCH_MAX: float = 1.2
const DEFAULT_PITCH: float = -0.16
const PROBE_RADIUS: float = 0.25

# Perche : rentre vite devant un mur, ressort en douceur (ressort amorti), tolère un obstacle fin
# (poteau, arbre) pendant OCCLUSION_GRACE avant de passer devant.
const PULL_IN_SLACK: float = 0.08
const PULL_IN_RATE: float = 24.0
const PUSH_OUT_RATE: float = 6.0
const PUSH_OUT_DELAY: float = 0.12
const SIDE_IN_RATE: float = 26.0
const SIDE_OUT_RATE: float = 6.0
const OCCLUSION_GRACE: float = 0.45
const THIN_OCCLUDER: float = 1.4
const WHISKER: float = 0.6
# Cadrage (épaule, hauteur au-dessus de la tête, longueur) selon le mode ; fondu de FRAME_TIME.
const SHOULDER: float = 0.3
const BEHIND_SHOULDER: float = 0.0
const LIFT: float = 0.5
const BOOM_LENGTH: float = 4.6
const BEHIND_BOOM_LENGTH: float = 4.3
const DOWNED_BOOM_LENGTH: float = 3.3
const HEAD_HEIGHT: float = 1.5
const DOWNED_HEAD_HEIGHT: float = 0.68
const FLOOR_CLEARANCE: float = 0.4
const LOOKUP_BOOM: float = 2.4
const FRAME_TIME: float = 0.45
const ANCHOR_RATE: float = 30.0
const ANCHOR_RATE_VERTICAL: float = 12.0
const ANCHOR_RATE_SNAPPY: float = 60.0
const ANCHOR_LAG: float = 0.4
const ANCHOR_LAG_VERTICAL: float = 0.7
const RECENTER_TIME: float = 0.25
const RECENTER_TIME_PER_PI: float = 0.3
const SPECTATE_FOLLOW_RATE: float = 4.5
const SPECTATE_MANUAL_HOLD: float = 1.2

const HIDE_DISTANCE: float = 1.65
const SPECTATOR_BLEND_TIME: float = 0.75
const SHAKE_DECAY: float = 1.7
const SPRINT_FOV_KICK: float = 6.0
const TRUE_FORM_FOV_KICK: float = 12.0
const BOOST_FOV_KICK: float = 4.0
const DRONE_FOV: float = 86.0
const VIEW_DRONE: int = -2

# Souris : radians par pixel d'écran. Stick : courbe, lissage léger, accélération quand il reste à fond.
const MOUSE_DEFAULT_SENSITIVITY: float = 0.0025
const LEGACY_MOUSE_SENSITIVITY: float = 0.0022
const PAD_EXPONENT: float = 1.6
const PAD_OUTER: float = 0.04
const PAD_SMOOTH_RATE: float = 40.0
const PAD_PITCH_RATIO: float = 0.72
const PAD_BOOST_EDGE: float = 0.9
const PAD_BOOST_DELAY: float = 0.16
const PAD_BOOST_RAMP: float = 0.38
const PAD_BOOST_GAIN: float = 1.25
const PAD_DEFAULT_ACCELERATION: float = 0.65

var world: Node
var camera: Camera3D
var trauma: float = 0.0
var mode: String = MODE_FREE
var pad_acceleration: float = PAD_DEFAULT_ACCELERATION

var persist: bool = true

var test_stick: Variant = null
var _probe: PhysicsShapeQueryParameters3D
var _boom: float = BOOM_LENGTH
var _boom_speed: float = 0.0
var _boom_length: float = BOOM_LENGTH
var _push_hold: float = 0.0
var _occluded: float = 0.0
var _side: float = 1.0
var _frame: Vector3 = Vector3(SHOULDER, LIFT, BOOM_LENGTH)
var _frame_ready: bool = false
var _frame_from: Vector3 = Vector3(SHOULDER, LIFT, BOOM_LENGTH)
var _frame_goal: Vector3 = Vector3(SHOULDER, LIFT, BOOM_LENGTH)
var _frame_time: float = 0.0
var _downed: float = 0.0
var _shake_clock: float = 0.0
var _view_id: int = -1
var _blend: float = 0.0
var _blend_time: float = SPECTATOR_BLEND_TIME
var _blend_from: Transform3D = Transform3D.IDENTITY
var _following: bool = false
var _fov: float = 72.0
var _punch: float = 0.0
var _kick: Vector3 = Vector3.ZERO
var _kick_velocity: Vector3 = Vector3.ZERO
var _recenter: float = 0.0
var _recenter_done: float = 0.0
var _recenter_time: float = 0.0
var _recenter_duration: float = 0.0
var _manual_look: float = 99.0
var _pad: Vector2 = Vector2.ZERO
var _pad_hold: float = 0.0
var _pad_frame: int = -10
var _last_goal: Transform3D = Transform3D.IDENTITY
var _anchor_target: Vector3 = Vector3.ZERO
var _controllers: Array[Dictionary] = []
var _facing_sent: int = -1
var _facing_clock: float = 0.0
var _badge: Control

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
	load_settings()

func reset() -> void :
	_following = false
	_view_id = -1
	_blend = 0.0
	_boom = BOOM_LENGTH
	_boom_speed = 0.0
	_boom_length = BOOM_LENGTH
	_push_hold = 0.0
	_occluded = 0.0
	_side = 1.0
	_frame_ready = false
	_downed = 0.0
	trauma = 0.0
	_punch = 0.0
	_kick = Vector3.ZERO
	_kick_velocity = Vector3.ZERO
	_stop_recenter()
	_pad = Vector2.ZERO
	_pad_hold = 0.0
	_facing_sent = -1
	_controllers.clear()



func load_settings(config: ConfigFile = null) -> void :
	var version: int = 0
	if config == null:
		config = ConfigFile.new()
		if config.load("user://settings.cfg") != OK: config = null
	if config != null:
		mode = _clean_mode(str(config.get_value("camera", "mode", MODE_FREE)))
		pad_acceleration = clampf(float(config.get_value("camera", "pad_acceleration", PAD_DEFAULT_ACCELERATION)), 0.0, 1.0)
		version = int(config.get_value("camera", "version", 0))
	# 0.16 : l'ancienne valeur par défaut (0.0022 rad/px de viewport) passe à 0.0025 rad/px d'écran.
	if version < SETTINGS_VERSION and is_equal_approx(float(world.get("sensitivity")), LEGACY_MOUSE_SENSITIVITY):
		world.set("sensitivity", MOUSE_DEFAULT_SENSITIVITY)

func save_settings(config: ConfigFile) -> void :
	config.set_value("camera", "mode", mode)
	config.set_value("camera", "pad_acceleration", pad_acceleration)
	config.set_value("camera", "version", SETTINGS_VERSION)

static func _clean_mode(value: String) -> String:
	return MODE_BEHIND if value == MODE_BEHIND else MODE_FREE

static func view_direction(yaw: float, pitch: float) -> Vector3:
	return Vector3(0.0, sin(pitch), - cos(pitch)).rotated(Vector3.UP, yaw)

func toggle_mode() -> void :
	set_mode(MODE_FREE if mode == MODE_BEHIND else MODE_BEHIND)

func set_mode(next: String, announce: bool = true) -> void :
	next = _clean_mode(next)
	var changed: bool = next != mode
	mode = next
	if mode == MODE_BEHIND: _begin_recenter()
	else: _stop_recenter()
	if announce: _announce()
	if changed and persist and world.has_method("save_preferences"): world.save_preferences()

func is_behind() -> bool:
	return mode == MODE_BEHIND



# Orientation demandée au personnage local (effet synchronisé « cam_facing », lu par actor.gd).
func facing_code() -> int:
	if mode == MODE_BEHIND and not recentering(): return FACING_BEHIND
	return FACING_FREE



# Appelé à chaque tick d'entrée : l'hôte écrit l'effet, un client l'envoie (au changement, puis
# renvoyé toutes les 0,5 s tant que l'instantané de l'hôte ne le confirme pas).
func apply_facing(actor: PaperActor, delta: float) -> void :
	if not is_instance_valid(actor): return
	var code: int = facing_code()
	if world.authoritative():
		actor.effects["cam_facing"] = code
		return
	_facing_clock += delta
	if not bool(world.get("networked")): return
	var confirmed: bool = int(actor.effects.get("cam_facing", FACING_LEGACY)) == code
	if code == _facing_sent and (confirmed or _facing_clock < 0.5): return
	_facing_sent = code
	_facing_clock = 0.0
	Callable(world, "command").rpc_id(1, "camera_mode", {"mode": code})

# Passage en « Derrière » : la caméra glisse (ease-in-out) jusque dans le dos du personnage.
# Le perso garde son orientation pendant ce temps ; la souris reste active (elle s'ajoute).
func _begin_recenter() -> void :
	_stop_recenter()
	var actor: PaperActor = world.local_actor() if world.has_method("local_actor") else null
	if not is_instance_valid(actor) or not actor.alive or not is_instance_valid(actor.visual): return
	_recenter = angle_difference(float(world.yaw), _actor_yaw(actor))
	if absf(_recenter) < 0.002:
		_recenter = 0.0
		return
	_recenter_duration = RECENTER_TIME + RECENTER_TIME_PER_PI * absf(_recenter) / PI

func _stop_recenter() -> void :
	_recenter = 0.0
	_recenter_done = 0.0
	_recenter_time = 0.0
	_recenter_duration = 0.0

func recentering() -> bool:
	return _recenter_duration > 0.0

static func _actor_yaw(actor: PaperActor) -> float:
	return actor.rotation.y + actor.visual.rotation.y

func _announce() -> void :
	if not is_instance_valid(_badge):
		var ui: Variant = world.get("ui")
		if ui == null or not is_instance_valid(ui) or ui.get("root") == null: return
		_badge = CameraBadge.new()
		ui.root.add_child(_badge)
		_badge.setup(world)
	_badge.show_mode(mode)


# Entrées de visée → world.yaw / world.pitch, appliquées tout de suite (aucune inertie) : la caméra
# est replacée à chaque image depuis ces angles. Bloquées pendant une prise de contrôle cinématique.
func look_locked() -> bool:
	for entry: Dictionary in _controllers:
		if bool(entry.get("lock_look", true)) and (entry.owner as WeakRef).get_ref() != null: return true
	return false

func turn(amount: Vector2) -> void :
	if amount == Vector2.ZERO or not amount.is_finite(): return
	world.yaw = wrapf(float(world.yaw) - amount.x, - PI, PI)
	world.pitch = clampf(float(world.pitch) - amount.y, PITCH_MIN, PITCH_MAX)
	_manual_look = 0.0


func mouse_look(event: InputEventMouseMotion) -> void :
	if look_locked(): return
	turn(event.screen_relative * float(world.sensitivity))

func touch_look(drag: Vector2) -> void :
	if look_locked(): return
	turn(drag * float(world.touch_sensitivity))



func pad_look(delta: float) -> void :
	var frame: int = Engine.get_process_frames()
	if frame - _pad_frame > 2:
		_pad = Vector2.ZERO
		_pad_hold = 0.0
	_pad_frame = frame
	var rate: Vector2 = pad_rate(_pad_stick(), delta)
	if look_locked(): return
	turn(rate * delta)


func pad_rate(raw: Vector2, delta: float) -> Vector2:
	var bindings: Variant = world.get("bindings")
	var deadzone: float = clampf(float(bindings.deadzone) if bindings else 0.18, 0.05, 0.45)
	var sensitivity: float = float(bindings.look_sensitivity) if bindings else 2.6
	var strength: float = raw.length()
	var shaped: Vector2 = Vector2.ZERO
	var amount: float = 0.0
	if strength > deadzone:
		amount = clampf((strength - deadzone) / maxf(0.05, 1.0 - deadzone - PAD_OUTER), 0.0, 1.0)
		shaped = raw / strength * pow(amount, PAD_EXPONENT)
	_pad = _pad.lerp(shaped, 1.0 - exp( - delta * PAD_SMOOTH_RATE))
	if amount >= PAD_BOOST_EDGE and absf(raw.x) > 0.7 * strength:
		_pad_hold += delta
	else:
		_pad_hold = maxf(0.0, minf(_pad_hold, PAD_BOOST_DELAY + PAD_BOOST_RAMP) - delta * 4.0)
	var boost: float = 1.0 + pad_acceleration * PAD_BOOST_GAIN * smoothstep(PAD_BOOST_DELAY, PAD_BOOST_DELAY + PAD_BOOST_RAMP, _pad_hold)
	return Vector2(_pad.x * sensitivity * boost, _pad.y * sensitivity * PAD_PITCH_RATIO * (1.0 + (boost - 1.0) * 0.25))

func _pad_stick() -> Vector2:
	if test_stick is Vector2: return test_stick
	var bindings: Variant = world.get("bindings")
	if bindings == null: return Vector2.ZERO
	var device: int = int(bindings.active_device)
	if device < 0 or not Input.get_connected_joypads().has(device) or not DisplayServer.window_is_focused(): return Vector2.ZERO
	return Vector2(Input.get_joy_axis(device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y))



# Prise de contrôle par un plan cinématique (voir l'en-tête du fichier).
func take_control(owner: Object, blend_in: float = 0.0, lock_look: bool = true) -> void :
	if owner == null: return
	_drop_controller(owner)
	_controllers.append({"owner": weakref(owner), "blend_in": maxf(0.0, blend_in), "time": 0.0, "lock_look": lock_look, "driven": false, "from": camera.global_transform, "from_fov": camera.fov, "shot": camera.global_transform, "fov": camera.fov})

func drive(owner: Object, shot: Transform3D, fov: float = -1.0) -> void :
	for entry: Dictionary in _controllers:
		if (entry.owner as WeakRef).get_ref() == owner:
			entry.shot = shot
			if fov > 0.0: entry.fov = fov
			entry.driven = true
			return

func release_control(owner: Object, blend_out: float = 0.45) -> void :
	if _drop_controller(owner) and _controllers.is_empty(): _hand_back(blend_out)

func has_control(owner: Object = null) -> bool:
	if owner == null: return not _controllers.is_empty()
	for entry: Dictionary in _controllers:
		if (entry.owner as WeakRef).get_ref() == owner: return true
	return false

func gameplay_transform() -> Transform3D:
	return _last_goal

func _drop_controller(owner: Object) -> bool:
	var removed: bool = false
	for index: int in range(_controllers.size() - 1, -1, -1):
		if (_controllers[index].owner as WeakRef).get_ref() == owner:
			_controllers.remove_at(index)
			removed = true
	return removed

func _hand_back(blend_out: float) -> void :
	_fov = camera.fov
	if blend_out > 0.0: _start_blend(camera.global_transform, blend_out)

func _purge_controllers() -> void :
	var had: bool = not _controllers.is_empty()
	for index: int in range(_controllers.size() - 1, -1, -1):
		if (_controllers[index].owner as WeakRef).get_ref() == null: _controllers.remove_at(index)
	if had and _controllers.is_empty(): _hand_back(0.45)

func _apply_control(delta: float) -> void :
	var entry: Dictionary = _controllers.back()
	entry.time = float(entry.time) + delta
	if not bool(entry.driven): return
	var shot: Transform3D = entry.shot
	var fov: float = float(entry.fov)
	var blend_in: float = float(entry.blend_in)
	if blend_in > 0.0 and float(entry.time) < blend_in:
		var u: float = smoothstep(0.0, 1.0, float(entry.time) / blend_in)
		shot = (entry.from as Transform3D).interpolate_with(shot, u)
		fov = lerpf(float(entry.from_fov), fov, u)
	camera.global_transform = shot
	camera.fov = fov
	_apply_shake(delta)

func _start_blend(from: Transform3D, duration: float) -> void :
	_blend = 1.0
	_blend_time = maxf(0.05, duration)
	_blend_from = from

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
	_manual_look += delta
	_purge_controllers()
	var phase: String = str(world.phase)
	var pilot: PaperActor = world.local_actor()
	if _controllers.is_empty() and phase == "playing" and pilot and bool(pilot.effects.get("drone_piloting", false)) and _drone_view(pilot):
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
		if not _controllers.is_empty(): _apply_control(delta)
		return
	var target: Vector3 = world.actor_render_position(actor) + Vector3.UP * (DOWNED_HEAD_HEIGHT if bool(actor.effects.get("downed", false)) else HEAD_HEIGHT)
	if phase == "intro" and _controllers.is_empty():
		var alpha: float = clampf(float(world.cinema) / 5.0, 0.0, 1.0)
		var offset: Vector3 = Vector3(4.5 * (1.0 - alpha), 2.0, 6.5).rotated(Vector3.UP, float(world.yaw) + 0.6 * (1.0 - alpha))
		camera.position = target + offset
		camera.look_at(target)
		camera.fov = 62.0 + alpha * 10.0
		return
	if phase == "ending" and _controllers.is_empty():
		_ending_view(delta, actor, target)
		return
	_follow(delta, actor)

func _drone_view(pilot: PaperActor) -> bool:
	var drone: Dictionary = world.combat.piloted_drone(pilot)
	if drone.is_empty():
		return false
	var direction: Vector3 = view_direction(float(world.yaw), float(world.pitch))
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

		_start_blend(camera.global_transform, SPECTATOR_BLEND_TIME)
		world.camera_anchor_ready = false
		_boom = BOOM_LENGTH
		_boom_speed = 0.0
		_boom_length = BOOM_LENGTH
		_side = 1.0
		_fov = camera.fov
	elif not _following:
		_fov = camera.fov
	_view_id = view_id
	_following = true
	_steer(delta, actor)
	var eye_goal: Transform3D = gameplay_goal(delta, actor)
	_last_goal = eye_goal
	if not _controllers.is_empty():
		_apply_control(delta)
		return
	if _blend > 0.0:
		_blend = maxf(0.0, _blend - delta / _blend_time)
		camera.global_transform = _blend_from.interpolate_with(eye_goal, smoothstep(0.0, 1.0, 1.0 - _blend))
	else:
		camera.global_transform = eye_goal
	if eye_goal.origin.distance_to(world.camera_anchor) < HIDE_DISTANCE:
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

	var left: float = minf(delta, 0.25)
	while left > 1e-06:
		var step: float = minf(left, 1.0 / 120.0)
		_kick_velocity += ( - _kick * 180.0 - _kick_velocity * 16.0) * step
		_kick += _kick_velocity * step
		left -= step
	if _kick.length_squared() > 4e-06:
		camera.global_position += _kick.limit_length(0.3)
	_apply_shake(delta)


# Recentrage « Derrière » du joueur local, ou suivi du dos de l'allié observé en spectateur.
func _steer(delta: float, actor: PaperActor) -> void :
	var local: PaperActor = world.local_actor()
	if actor != local:
		_stop_recenter()
		if mode == MODE_BEHIND and _manual_look > SPECTATE_MANUAL_HOLD and not look_locked() and is_instance_valid(actor.visual):
			world.yaw = lerp_angle(float(world.yaw), _actor_yaw(actor), 1.0 - exp( - delta * SPECTATE_FOLLOW_RATE))
		return
	if not recentering(): return
	_recenter_time += delta
	var progress: float = smoothstep(0.0, 1.0, minf(1.0, _recenter_time / _recenter_duration))
	var applied: float = _recenter * progress
	world.yaw = wrapf(float(world.yaw) + applied - _recenter_done, - PI, PI)
	_recenter_done = applied
	if progress >= 1.0: _stop_recenter()


# Transform de la caméra de jeu pour cet acteur (axe = yaw/pitch exacts, puis épaule, hauteur, perche).
func gameplay_goal(delta: float, actor: PaperActor) -> Transform3D:
	var downed: bool = bool(actor.effects.get("downed", false))
	_downed = move_toward(_downed, 1.0 if downed else 0.0, delta * 2.5)
	var head: float = lerpf(HEAD_HEIGHT, DOWNED_HEAD_HEIGHT, _downed)
	var target: Vector3 = world.actor_render_position(actor) + Vector3.UP * head
	_update_anchor(delta, target)
	var pivot: Vector3 = world.camera_anchor
	var behind: bool = mode == MODE_BEHIND
	var want: Vector3 = Vector3(BEHIND_SHOULDER if behind else SHOULDER, LIFT, BEHIND_BOOM_LENGTH if behind else BOOM_LENGTH)
	if not _frame_ready:
		_frame = want
		_frame_goal = want
		_frame_time = FRAME_TIME
		_frame_ready = true
	elif want != _frame_goal:
		_frame_from = _frame
		_frame_goal = want
		_frame_time = 0.0
	if _frame_time < FRAME_TIME:
		_frame_time += delta
		_frame = _frame_from.lerp(_frame_goal, smoothstep(0.0, 1.0, minf(1.0, _frame_time / FRAME_TIME)))
	var shoulder: float = _frame.x * (1.0 - 0.4 * _downed)
	var lift: float = _frame.y * (1.0 - 0.5 * _downed)
	var length: float = lerpf(_frame.z, DOWNED_BOOM_LENGTH, _downed)
	var yaw: float = float(world.yaw)
	var pitch: float = clampf(float(world.pitch), PITCH_MIN, PITCH_MAX)
	var look: Vector3 = view_direction(yaw, pitch)
	var right: Vector3 = Vector3.RIGHT.rotated(Vector3.UP, yaw)
	var side_goal: Vector3 = pivot + right * shoulder + Vector3.UP * lift
	var side_free: float = cast_fraction(pivot, side_goal)
	if side_free < _side:
		_side = minf(lerpf(_side, side_free, 1.0 - exp( - delta * SIDE_IN_RATE)), side_free + 0.12)
	else:
		_side = lerpf(_side, side_free, 1.0 - exp( - delta * SIDE_OUT_RATE))
	var origin: Vector3 = pivot.lerp(side_goal, _side)
	# Vers le haut, la caméra descend vers le sol en se rapprochant (perche raccourcie, sans retard),
	# jusqu'à LOOKUP_BOOM ; au-delà elle s'incline seulement. Le perso reste en bas de l'image.
	var orbit_pitch: float = pitch
	var reach: float = length
	if pitch > 0.0:
		var height: float = maxf(0.05, origin.y - (target.y - head) - FLOOR_CLEARANCE)
		var limit: float = asin(clampf(height / maxf(0.5, minf(length, LOOKUP_BOOM)), 0.02, 0.95))
		orbit_pitch = limit * tanh(pitch / limit)
		reach = clampf(height / maxf(0.01, sin(orbit_pitch)), minf(length, LOOKUP_BOOM), length)
	var back: Vector3 = - view_direction(yaw, orbit_pitch)
	var boom: float = _resolve_boom(delta, origin, back, length, reach, right)
	return Transform3D(Basis.looking_at(look, Vector3.UP), origin + back * boom)

func _update_anchor(delta: float, target: Vector3) -> void :
	_anchor_target = target
	if not world.camera_anchor_ready or world.camera_anchor.distance_to(target) > 12.0:
		world.camera_anchor = target
		world.camera_anchor_ready = true
		_boom_speed = 0.0
		return
	var smooth: bool = bool(world.options.get("camera_smooth", true))
	var anchor: Vector3 = world.camera_anchor
	var flat: Vector2 = Vector2(anchor.x, anchor.z).lerp(Vector2(target.x, target.z), 1.0 - exp( - delta * (ANCHOR_RATE if smooth else ANCHOR_RATE_SNAPPY)))
	var lag: Vector2 = flat - Vector2(target.x, target.z)
	if lag.length() > ANCHOR_LAG: flat = Vector2(target.x, target.z) + lag.limit_length(ANCHOR_LAG)
	var height: float = lerpf(anchor.y, target.y, 1.0 - exp( - delta * (ANCHOR_RATE_VERTICAL if smooth else ANCHOR_RATE_SNAPPY)))
	height = clampf(height, target.y - ANCHOR_LAG_VERTICAL, target.y + ANCHOR_LAG_VERTICAL)
	world.camera_anchor = Vector3(flat.x, height, flat.y)


# _boom suit la longueur nominale (ou l'obstacle) ; « reach » est la longueur permise par l'inclinaison
# (regard vers le haut), appliquée directement : seule la gêne d'un obstacle passe par le ressort.
func _resolve_boom(delta: float, origin: Vector3, back: Vector3, length: float, reach: float, right: Vector3) -> float:
	# Perche libre (aucun obstacle) : elle suit tout de suite les changements de cadrage, déjà lissés.
	if _boom >= _boom_length - 0.002 and _push_hold <= 0.0: _boom = length
	_boom_length = length
	var full: Vector3 = origin + back * reach
	var free: float = cast_fraction(origin, full)
	var target: float = length
	var hard: bool = false
	if free < 1.0:
		# Mur : la perche rentre tout de suite. Poteau / arbre fin derrière lequel la caméra se trouve
		# déjà : toléré OCCLUSION_GRACE secondes (évite les sauts quand on longe des piliers).
		var hit: float = reach * free
		if minf(_boom, reach) > hit + PULL_IN_SLACK and _thin_occluder(origin, full, free, reach, right):
			_occluded += delta
			hard = _occluded >= OCCLUSION_GRACE
		else:
			_occluded = OCCLUSION_GRACE
			hard = true
		if hard: target = hit
	else:
		_occluded = 0.0
	if target < _boom - 0.0005:
		_boom = minf(lerpf(_boom, target, 1.0 - exp( - delta * PULL_IN_RATE)), target + PULL_IN_SLACK)
		_boom_speed = 0.0
		_push_hold = PUSH_OUT_DELAY
		return minf(_boom, reach)
	if _push_hold > 0.0:
		_push_hold -= delta
		return minf(_boom, reach)
	# Ressort critique sous-échantillonné : même mouvement quel que soit le framerate.
	var left: float = minf(delta, 0.25)
	while left > 1e-06:
		var step: float = minf(left, 1.0 / 120.0)
		_boom_speed += ((target - _boom) * PUSH_OUT_RATE * PUSH_OUT_RATE - 2.0 * PUSH_OUT_RATE * _boom_speed) * step
		_boom = minf(_boom + _boom_speed * step, target)
		left -= step
	if _boom >= target - 0.0005: _boom_speed = 0.0
	return minf(_boom, reach)


func _thin_occluder(origin: Vector3, full: Vector3, free: float, length: float, right: Vector3) -> bool:
	var back_free: float = cast_fraction(full, origin)
	if back_free <= 0.0: return false
	if length * (1.0 - free - back_free) > THIN_OCCLUDER: return false
	for side: float in [1.0, -1.0]:
		var near: Vector3 = right * WHISKER * side
		if cast_fraction(origin + near, full + near) >= 1.0: continue
		if cast_fraction(origin + near * 2.0, full + near * 2.0) >= 1.0: continue
		return false
	return true


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
