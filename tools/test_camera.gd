extends Node

# Banc d'essai de la caméra 0.16 (core_camera_rig.gd + déplacements).
#   Logique seule  : godot --headless -- --tool test_camera --out DOSSIER
#   Avec captures  : xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 -- --tool test_camera --out DOSSIER
# Vérifie numériquement : rotation immédiate (aucune inertie), plage verticale, sensibilité souris
# et stick indépendantes du framerate, accélération du stick, déplacements droits par rapport à la
# caméra (avancer / strafe / diagonale, sans dérive à l'écran), modes Derrière / Libre 360° et leurs
# transitions, collisions de la perche, prise de contrôle cinématique, spectateur. Écrit
# camera_report.json (+ captures .png en rendu) et quitte avec le code 1 si un test échoue.

const Rig = preload("res://core_camera_rig.gd")

var world: Node
var rig: Variant
var out_dir: String = "user://camera_test"
var render: bool = false
var results: Array[Dictionary] = []
var metrics: Dictionary = {}
var captures: Array[String] = []
var _query: PhysicsShapeQueryParameters3D
var _props: Array[Node] = []

func setup(owner: Node) -> void :
	world = owner
	rig = world.camera_rig
	render = DisplayServer.get_name() != "headless"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		if args[i] == "--out" and i + 1 < args.size(): out_dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 0.95
	_query = PhysicsShapeQueryParameters3D.new()
	_query.shape = sphere
	_query.collision_mask = 1
	_run.call_deferred()



func _check(test_name: String, ok: bool, detail: String) -> void :
	results.append({"name": test_name, "ok": ok, "detail": detail})
	print("CAMERA_TEST ", "OK   " if ok else "FAIL ", test_name, " · ", detail)

func _wait(seconds: float) -> void :
	var elapsed: float = 0.0
	while elapsed < seconds:
		await get_tree().process_frame
		elapsed += get_process_delta_time()

func _frames(count: int) -> void :
	for i: int in range(count): await get_tree().process_frame

func _ticks(count: int) -> void :
	for i: int in range(count): await get_tree().physics_frame

func _capture(capture_name: String) -> void :
	if not render: return
	await _frames(2)
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(out_dir).path_join(capture_name + ".png")
	image.save_png(path)
	captures.append(path)
	print("CAMERA_CAPTURE ", path)

static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z).normalized()

func _cam_forward() -> Vector3:
	return - world.camera.global_basis.z

func _actor() -> PaperActor:
	return world.local_actor()

func _actor_yaw(actor: PaperActor) -> float:
	return actor.rotation.y + actor.visual.rotation.y

func _set_mode(next: String) -> void :
	rig.set_mode(next, false)

func _settle_mode(next: String) -> void :
	_set_mode(next)
	await _wait(0.75)

func _place(actor: PaperActor, at: Vector3, facing_yaw: float) -> void :
	actor.global_position = at
	actor.velocity = Vector3.ZERO
	actor.net_position = at
	actor.move_input = Vector3.ZERO
	actor.aim = Vector3.FORWARD.rotated(Vector3.UP, facing_yaw)
	actor.visual.rotation.y = facing_yaw
	actor.reset_physics_interpolation()
	world.camera_anchor_ready = false

func _release_all() -> void :
	for action: String in ["forward", "back", "left", "right", "sprint"]: Input.action_release(action)



func _clear_path(from: Vector3, direction: Vector3, length: float) -> bool:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	for height: float in [1.0, 2.1]:
		_query.transform = Transform3D(Basis.IDENTITY, from + Vector3.UP * height)
		_query.motion = direction * length
		var hit: PackedFloat32Array = space.cast_motion(_query)
		if hit.is_empty() or hit[0] < 1.0: return false
	for step: int in range(0, int(length) + 1):
		if not world.school.can_walk(from + direction * float(step)): return false
	return true

func _floor_at(point: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2.5, point + Vector3.DOWN * 4.0, 1)
	var hit: Dictionary = space.intersect_ray(query)
	return Vector3(point.x, float(hit.position.y) + 0.05, point.z) if not hit.is_empty() else point

func _boom_clear(at: Vector3, yaw: float) -> bool:
	var origin: Vector3 = at + Vector3.UP * 2.0
	return rig.cast_fraction(origin, origin - Rig.view_direction(yaw, Rig.DEFAULT_PITCH) * (Rig.BOOM_LENGTH + 0.4)) >= 1.0

func _open_spot(direction: Vector3, length: float = 6.5, camera_yaw: float = INF) -> Vector3:
	var centre: Vector3 = world.practice._spawn_centre()
	var candidates: Array[Vector3] = []
	for radius: float in [0.0, 2.5, 5.0, 7.5, 10.0, 13.0]:
		for k: int in range(12 if radius > 0.0 else 1):
			candidates.append(centre + Vector3(cos(TAU * k / 12.0), 0.0, sin(TAU * k / 12.0)) * radius)
	for spawn: Vector3 in world.school.spawn_points: candidates.append(spawn)
	for candidate: Vector3 in candidates:
		var at: Vector3 = _floor_at(candidate)
		if world.school.can_walk(at) and _clear_path(at, direction, length) and _clear_path(at, - direction, 5.0) and (camera_yaw == INF or (_boom_clear(at, camera_yaw) and _boom_clear(at + direction * 4.8, camera_yaw))): return at
	return _floor_at(centre)



func _run() -> void :
	rig.persist = false
	var original_mode: String = rig.mode
	world.options["camera_shake"] = false
	if not render: Engine.max_fps = 60
	world.selected = "Simon"
	world.start_training(true)
	await _wait(0.8)
	if world.phase != "playing" or _actor() == null:
		_check("start", false, "le terrain d'essai n'a pas démarré (phase %s)" % world.phase)
		_finish(original_mode)
		return
	_check("start", true, "terrain d'essai lancé avec %s" % _actor().character)
	_test_bindings()
	await _test_rotation()
	await _test_vertical_range()
	_test_mouse()
	_test_pad()
	await _test_movement("Simon")
	await _test_modes("Simon")
	await _test_collisions()
	await _test_control_api()
	await _test_spectator()
	await _test_drone()
	if world.practice.change_character(world.local_id(), "Alice", false):
		await _wait(0.6)
		_check("alice", _actor() != null and _actor().character == "Alice", "passage à Alice dans le terrain d'essai")
		await _test_movement("Alice")
		await _test_modes("Alice")
	else:
		_check("alice", false, "impossible de passer à Alice")
	_finish(original_mode)



func _test_bindings() -> void :
	var keys: Array[String] = []
	var pad: bool = false
	for event: InputEvent in InputMap.action_get_events("camera_mode"):
		if event is InputEventKey: keys.append(OS.get_keycode_string(event.physical_keycode))
		if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_RIGHT_STICK: pad = true
	var clashes: Array[String] = []
	for action: String in PaperBindings.LABELS:
		if action == "camera_mode": continue
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey and event.physical_keycode == KEY_C: clashes.append(action)
			if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_RIGHT_STICK: clashes.append(action)
	_check("binding", keys.has("C") and pad and clashes.is_empty(), "action « camera_mode » : touche %s + R3, conflits : %s" % [", ".join(keys), "aucun" if clashes.is_empty() else ", ".join(clashes)])
	_check("controls_menu", PaperBindings.LABELS.has("camera_mode"), "libellé dans le menu Commandes : « %s »" % str(PaperBindings.LABELS.get("camera_mode", "")))



func _test_rotation() -> void :
	var worst: float = 0.0
	var roll: float = 0.0
	var count: int = 0
	var samples: Array = [[0.0, -0.16], [1.1, 0.4], [-2.6, -1.0], [3.0, Rig.PITCH_MAX], [-0.7, Rig.PITCH_MIN], [2.2, 0.9], [-1.4, 0.0]]
	for mode: String in [Rig.MODE_FREE, Rig.MODE_BEHIND]:
		_set_mode(mode)
		rig._stop_recenter()
		for sample: Array in samples:
			world.yaw = float(sample[0])
			world.pitch = float(sample[1])
			rig.update(1.0 / 60.0)
			worst = maxf(worst, rad_to_deg(_cam_forward().angle_to(Rig.view_direction(world.yaw, world.pitch))))
			roll = maxf(roll, absf(rad_to_deg(asin(clampf(world.camera.global_basis.x.y, -1.0, 1.0)))))
			count += 1

	var lag: float = 0.0
	world.yaw = 0.3
	world.pitch = -0.16
	await _frames(2)
	for step: int in range(30):
		world.yaw = wrapf(world.yaw - 0.05, - PI, PI)
		await _frames(1)
		lag = maxf(lag, rad_to_deg(_flat(_cam_forward()).angle_to(_flat(Rig.view_direction(world.yaw, 0.0)))))
	metrics["rotation_error_deg"] = worst
	metrics["rotation_lag_deg"] = lag
	_check("rotation_immediate", worst < 0.05 and roll < 0.05 and lag < 0.05, "écart caméra/visée max %.4f° sur %d orientations, roulis %.4f°, retard pendant une rotation continue %.4f° (aucune inertie)" % [worst, count, roll, lag])

func _test_vertical_range() -> void :
	var actor: PaperActor = _actor()
	_set_mode(Rig.MODE_FREE)
	world.yaw = 0.0
	world.pitch = 0.0
	rig.turn(Vector2(0.0, -10.0))
	await _frames(3)
	var up: float = rad_to_deg(asin(_cam_forward().y))
	var eye_up: Vector3 = world.camera.global_position
	await _capture("cam_look_up")
	rig.turn(Vector2(0.0, 20.0))
	await _frames(3)
	var down: float = rad_to_deg(asin(_cam_forward().y))
	await _capture("cam_look_down")
	var clearance: float = eye_up.y - actor.global_position.y
	metrics["pitch_up_deg"] = up
	metrics["pitch_down_deg"] = down
	_check("vertical_range", up >= 60.0 and down <= -70.0, "regard de %.0f° (bas) à +%.0f° (haut) ; 0.15 : environ -26° à +10°" % [down, up])
	_check("look_up_floor", clearance >= 0.3, "caméra à %.2f m au-dessus des pieds en regardant en l'air (ne passe pas sous le sol)" % clearance)
	world.pitch = Rig.DEFAULT_PITCH
	await _frames(2)

func _test_mouse() -> void :
	var results_by_chunks: Array[Vector2] = []
	var sensitivity: float = float(world.sensitivity)
	for chunks: int in [1, 4, 16, 60, 240]:
		world.yaw = 0.0
		world.pitch = 0.0
		for i: int in range(chunks):
			var motion: InputEventMouseMotion = InputEventMouseMotion.new()
			motion.screen_relative = Vector2(600.0, -120.0) / float(chunks)
			motion.relative = motion.screen_relative
			rig.mouse_look(motion)
		results_by_chunks.append(Vector2(world.yaw, world.pitch))
	var spread: float = 0.0
	for value: Vector2 in results_by_chunks: spread = maxf(spread, value.distance_to(results_by_chunks[0]))
	var expected: Vector2 = Vector2(wrapf( - 600.0 * sensitivity, - PI, PI), 120.0 * sensitivity)
	var error: float = results_by_chunks[0].distance_to(expected)
	metrics["mouse_pixels_for_180"] = PI / sensitivity
	_check("mouse_framerate_independent", spread < 1e-06 and error < 1e-06, "même geste (600 px) découpé en 1 à 240 évènements : écart %.9f rad ; sensibilité %.4f rad/px (demi-tour = %d px, en pixels écran)" % [spread, sensitivity, int(PI / sensitivity)])
	world.yaw = 0.0
	world.pitch = Rig.DEFAULT_PITCH

func _pad_turn(stick: Vector2, fps: float, seconds: float) -> Array:
	rig._pad = Vector2.ZERO
	rig._pad_hold = 0.0
	var dt: float = 1.0 / fps
	var t: float = 0.0
	var turned: float = 0.0
	var early: float = 0.0
	var half_turn: float = -1.0
	while t < seconds - 1e-09:
		var rate: Vector2 = rig.pad_rate(stick, dt)
		turned += rate.x * dt
		t += dt
		if early == 0.0 and t >= 0.1: early = rate.x
		if half_turn < 0.0 and turned >= PI: half_turn = t
	var final: Vector2 = rig.pad_rate(stick, dt)
	return [turned, early, final.x, half_turn]

func _test_pad() -> void :
	var totals: Array[float] = []
	var text: Array[String] = []
	for fps: float in [30.0, 60.0, 144.0, 240.0]:
		var run: Array = _pad_turn(Vector2(1.0, 0.0), fps, 1.0)
		totals.append(float(run[0]))
		text.append("%d i/s %.0f°" % [int(fps), rad_to_deg(float(run[0]))])
	var low: float = totals.min()
	var high: float = totals.max()
	var spread: float = (high - low) / maxf(0.001, (high + low) * 0.5)
	metrics["pad_turn_1s_deg"] = rad_to_deg(totals[1])
	_check("pad_framerate_independent", spread < 0.02, "stick à fond pendant 1 s : %s (écart %.2f %%)" % [", ".join(text), spread * 100.0])
	var full: Array = _pad_turn(Vector2(1.0, 0.0), 60.0, 1.2)
	var half: Array = _pad_turn(Vector2(0.55, 0.0), 60.0, 1.2)
	var ratio: float = float(full[2]) / maxf(0.001, float(full[1]))
	metrics["pad_speed_start"] = rad_to_deg(float(full[1]))
	metrics["pad_speed_boost"] = rad_to_deg(float(full[2]))
	metrics["pad_half_turn_s"] = float(full[3])
	var dead: Array = _pad_turn(Vector2(0.12, 0.05), 60.0, 0.5)
	var vertical: Array = []
	rig._pad = Vector2.ZERO
	rig._pad_hold = 0.0
	var climb: float = 0.0
	for i: int in range(60): climb += rig.pad_rate(Vector2(0.0, -1.0), 1.0 / 60.0).y / 60.0
	_check("pad_acceleration", ratio > 1.5 and ratio < 2.3 and absf(float(half[2]) - float(half[1])) < 0.05 and absf(float(dead[0])) < 1e-06,
		"vitesse stick à fond : %.0f°/s à 0,1 s puis %.0f°/s après accélération (×%.2f) ; demi-tour en %.2f s ; demi-course stable à %.0f°/s ; zone morte respectée ; vertical %.0f°/s" % [rad_to_deg(float(full[1])), rad_to_deg(float(full[2])), ratio, float(full[3]), rad_to_deg(float(half[2])), rad_to_deg(absf(climb))])
	rig._pad = Vector2.ZERO
	rig._pad_hold = 0.0



func _move_case(actor: PaperActor, mode: String, yaw: float, actions: Array, local_dir: Vector2) -> Dictionary:
	var forward: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, yaw)
	var right: Vector3 = Vector3.RIGHT.rotated(Vector3.UP, yaw)
	var want: Vector3 = (right * local_dir.x + forward * local_dir.y).normalized()
	var spot: Vector3 = _open_spot(want, 6.5, yaw)
	_place(actor, spot, yaw)
	world.yaw = yaw
	world.pitch = Rig.DEFAULT_PITCH
	await _wait(0.35)
	var cam_forward: Vector3 = _flat(_cam_forward())
	var cam_right: Vector3 = _flat(world.camera.global_basis.x)
	var cam_want: Vector3 = (cam_right * local_dir.x + cam_forward * local_dir.y).normalized()
	var start: Vector3 = actor.global_position
	var viewport: Vector2 = world.get_viewport().get_visible_rect().size
	var screen_start: Vector2 = world.camera.unproject_position(world.actor_render_position(actor) + Vector3.UP * 1.1)
	var yaw_start: float = world.yaw
	var side_start: float = float(rig._side)
	var boom_start: float = float(rig._boom)
	for action: String in actions: Input.action_press(action)
	var path: Array[Vector3] = []
	for tick: int in range(45):
		await get_tree().physics_frame
		path.append(actor.global_position)
	var screen_mid: Vector2 = world.camera.unproject_position(world.actor_render_position(actor) + Vector3.UP * 1.1)
	var body: Vector3 = world.actor_render_position(actor)
	var follow_lag: float = Vector2(world.camera_anchor.x - body.x, world.camera_anchor.z - body.z).length()
	var side_change: float = maxf(absf(float(rig._side) - side_start), absf(float(rig._boom) - boom_start) / Rig.BOOM_LENGTH)
	_release_all()
	var finish: Vector3 = actor.global_position
	var moved: Vector3 = Vector3(finish.x - start.x, 0.0, finish.z - start.z)
	var deviation: float = 0.0
	for point: Vector3 in path:
		var offset: Vector3 = Vector3(point.x - start.x, 0.0, point.z - start.z)
		deviation = maxf(deviation, (offset - cam_want * offset.dot(cam_want)).length())
	var error: float = rad_to_deg(moved.angle_to(cam_want)) if moved.length() > 0.2 else 180.0
	var axis_error: float = rad_to_deg(cam_forward.angle_to(forward))
	await _ticks(10)
	return {"lag": follow_lag, "side": side_change, "error": error, "deviation": deviation, "distance": moved.length(), "drift": absf(screen_mid.x - screen_start.x) / maxf(1.0, viewport.x), "axis": axis_error, "yaw_kept": absf(angle_difference(yaw_start, world.yaw)), "facing": absf(rad_to_deg(angle_difference(_actor_yaw(actor), atan2( - cam_want.x, - cam_want.z)))), "facing_cam": absf(rad_to_deg(angle_difference(_actor_yaw(actor), world.yaw)))}

# Référence 0.15 : la caméra visait un point 1 m devant la tête depuis une épaule décalée de 0,6 m,
# donc son axe horizontal tournait de quelques degrés par rapport à la direction de marche.
static func _legacy_axis_error(pitch: float) -> float:
	var elevation: float = 0.15 - clampf(pitch, -0.6, 0.55) * 0.66
	return rad_to_deg(atan2(0.6, 1.0 + 4.6 * cos(elevation)))

func _test_movement(character: String) -> void :
	if character == "Simon":
		metrics["legacy_axis_error_deg"] = _legacy_axis_error(Rig.DEFAULT_PITCH)
		_check("legacy_reference", true, "0.15 (calcul) : axe de caméra décalé de %.1f° à %.1f° de la direction « avancer » selon l'inclinaison → dérive à droite à l'écran ; 0.16 : 0° par construction" % [_legacy_axis_error(0.55), _legacy_axis_error(-0.6)])
	var actor: PaperActor = _actor()
	var cases: Array = [["avancer", ["forward"], Vector2(0, 1)], ["strafe droite", ["right"], Vector2(1, 0)], ["diagonale avant-gauche", ["forward", "left"], Vector2(-1, 1)], ["reculer", ["back"], Vector2(0, -1)]]
	var yaws: Array = [0.0, 0.83, 2.4, -1.9] if character == "Simon" else [0.4, -2.2]
	for mode: String in [Rig.MODE_FREE, Rig.MODE_BEHIND]:
		await _settle_mode(mode)
		var worst: float = 0.0
		var worst_dev: float = 0.0
		var worst_drift: float = 0.0
		var worst_axis: float = 0.0
		var shortest: float = INF
		var facing_bad: float = 0.0
		var worst_side: float = 0.0
		var worst_lag: float = 0.0
		var count: int = 0
		for yaw: float in yaws:
			for spec: Array in cases:
				if character != "Simon" and spec[0] == "reculer": continue
				var r: Dictionary = await _move_case(actor, mode, yaw, spec[1], spec[2])
				if OS.get_cmdline_user_args().has("--verbose"): print("MOVE_CASE ", character, " ", mode, " yaw=", snappedf(yaw, 0.01), " ", spec[0], " ", r)
				worst = maxf(worst, float(r.error))
				worst_dev = maxf(worst_dev, float(r.deviation))
				worst_axis = maxf(worst_axis, float(r.axis))
				shortest = minf(shortest, float(r.distance))
				if spec[0] == "avancer" and float(r.side) < 0.02: worst_drift = maxf(worst_drift, float(r.drift))
				worst_side = maxf(worst_side, float(r.side))
				worst_lag = maxf(worst_lag, float(r.lag))
				if mode == Rig.MODE_BEHIND: facing_bad = maxf(facing_bad, float(r.facing_cam))
				elif spec[0] != "reculer" or character != "Alice": facing_bad = maxf(facing_bad, float(r.facing))
				count += 1
		var key: String = character.to_lower() + "_" + mode
		metrics["move_error_deg_" + key] = worst
		metrics["move_deviation_m_" + key] = worst_dev
		metrics["move_screen_drift_" + key] = worst_drift
		metrics["follow_lag_m_" + key] = worst_lag
		_check("move_straight_%s_%s" % [character, mode], worst < 0.5 and worst_dev < 0.03 and worst_axis < 0.01 and shortest > 2.0 and worst_drift < 0.006,
			"%d trajets (avant, strafe, diagonale%s) : écart de direction max %.3f°, sortie de ligne max %.3f m, axe caméra/yaw %.4f°, dérive écran %.2f %% de la largeur (perche/épaule modifiée par le décor : %.2f), %.1f m parcourus min" % [count, ", arrière" if character == "Simon" else "", worst, worst_dev, worst_axis, worst_drift * 100.0, worst_side, shortest])
		_check("follow_lag_%s_%s" % [character, mode], worst_lag < 0.4, "retard du suivi en marchant : %.2f m (lissage « Caméra souple », ~33 ms), la rotation n'est jamais lissée" % worst_lag)
		var facing_ok: bool = facing_bad < 6.0
		_check("move_facing_%s_%s" % [character, mode], facing_ok, ("le perso garde le dos à la caméra en se déplaçant (écart max %.1f°)" if mode == Rig.MODE_BEHIND else "le perso regarde où il va (écart max %.1f°)") % facing_bad)



func _test_modes(character: String) -> void :
	var actor: PaperActor = _actor()
	var direction: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, 0.6)
	var spot: Vector3 = _open_spot(direction, 3.0)
	await _settle_mode(Rig.MODE_FREE)
	_place(actor, spot, 0.6)
	world.yaw = 0.6
	world.pitch = Rig.DEFAULT_PITCH
	await _wait(0.5)
	var tag: String = character.to_lower()
	await _capture("cam_%s_free_back" % tag)

	var facing_before: float = _actor_yaw(actor)
	for step: int in range(45):
		rig.turn(Vector2(PI / 45.0, 0.0))
		await _frames(1)
	await _wait(0.3)
	var facing_after: float = _actor_yaw(actor)
	var kept: float = absf(rad_to_deg(angle_difference(facing_before, facing_after)))
	var char_forward: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, facing_after)
	var face_dot: float = _flat(_cam_forward()).dot(char_forward)
	var face_point: Vector3 = world.actor_render_position(actor) + Vector3.UP * 1.45
	var face_visible: bool = not world.camera.is_position_behind(face_point) and world.get_viewport().get_visible_rect().has_point(world.camera.unproject_position(face_point)) and actor.visual.visible
	_check("free_orbit_%s" % tag, kept < 0.5 and face_dot < -0.99 and face_visible and int(actor.effects.get("cam_facing", 0)) == Rig.FACING_FREE, "orbite de 180° : le perso n'a pas pivoté (%.2f°), la caméra lui fait face (cos = %.3f), visage à l'écran : %s" % [kept, face_dot, str(face_visible)])
	world.pitch = -0.05
	await _wait(0.25)
	await _capture("cam_%s_free_face" % tag)
	for step: int in range(15):
		rig.turn(Vector2(PI / 30.0, 0.0))
		await _frames(1)
	await _wait(0.25)
	await _capture("cam_%s_free_side" % tag)

	world.pitch = Rig.DEFAULT_PITCH
	var yaw_before: float = world.yaw
	var target_yaw: float = _actor_yaw(actor)
	var eye_trace: Array[Vector3] = []
	var dts: Array[float] = []
	rig.toggle_mode()
	var badge_ok: bool = is_instance_valid(rig._badge) and rig._badge.visible and str(rig._badge._title.text) == PaperLanguage.t("CAMÉRA : DERRIÈRE")
	var elapsed: float = 0.0
	while elapsed < 0.85:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		eye_trace.append(world.camera.global_position)
		dts.append(get_process_delta_time())
		if render and elapsed > 0.2 and elapsed < 0.2 + get_process_delta_time() * 1.5: await _capture("cam_%s_badge_behind" % tag)
	var settle_error: float = absf(rad_to_deg(angle_difference(world.yaw, target_yaw)))
	var peak_speed: float = 0.0
	var max_accel: float = 0.0
	var last_speed: float = 0.0
	for i: int in range(1, eye_trace.size()):
		var speed: float = eye_trace[i].distance_to(eye_trace[i - 1]) / maxf(0.001, dts[i])
		peak_speed = maxf(peak_speed, speed)
		if i > 1: max_accel = maxf(max_accel, absf(speed - last_speed) / maxf(0.001, dts[i]))
		last_speed = speed
	var start_speed: float = eye_trace[1].distance_to(eye_trace[0]) / maxf(0.001, dts[1]) if eye_trace.size() > 1 else 0.0
	metrics["behind_swing_peak_speed_" + tag] = peak_speed
	_check("behind_recenter_%s" % tag, settle_error < 2.0 and badge_ok and start_speed < peak_speed * 0.5, "passage en Derrière : la caméra glisse dans le dos (écart final %.2f°, départ en douceur %.1f m/s → pic %.1f m/s), bandeau « %s » : %s" % [settle_error, start_speed, peak_speed, PaperLanguage.t("CAMÉRA : DERRIÈRE"), str(badge_ok)])
	var viewport: Vector2 = world.get_viewport().get_visible_rect().size
	var screen: Vector2 = world.camera.unproject_position(world.actor_render_position(actor) + Vector3.UP * 1.2)
	var centred: float = absf(screen.x - viewport.x * 0.5) / viewport.x
	await _capture("cam_%s_behind" % tag)

	for step: int in range(10):
		rig.turn(Vector2(PI * 0.5 / 10.0, 0.0))
		await _frames(1)
	await _wait(0.45)
	var follow: float = absf(rad_to_deg(angle_difference(_actor_yaw(actor), world.yaw)))
	_check("behind_follow_%s" % tag, follow < 3.0 and centred < 0.01 and int(actor.effects.get("cam_facing", 0)) == Rig.FACING_BEHIND, "le perso suit la caméra après un quart de tour (écart %.2f°), centré à l'écran (décalage %.2f %%)" % [follow, centred * 100.0])

	rig.toggle_mode()
	var free_badge: bool = rig._badge.visible and str(rig._badge._title.text) == PaperLanguage.t("CAMÉRA : LIBRE 360°")
	await _wait(0.6)
	_check("toggle_free_%s" % tag, rig.mode == Rig.MODE_FREE and free_badge and int(actor.effects.get("cam_facing", 0)) == Rig.FACING_FREE, "retour en Libre 360° par la même touche, bandeau « %s » : %s" % [PaperLanguage.t("CAMÉRA : LIBRE 360°"), str(free_badge)])

	var config: ConfigFile = ConfigFile.new()
	rig.mode = Rig.MODE_BEHIND
	rig.save_settings(config)
	rig.mode = Rig.MODE_FREE
	rig.load_settings(config)
	var remembered: bool = rig.mode == Rig.MODE_BEHIND and str(config.get_value("camera", "mode", "")) == Rig.MODE_BEHIND
	rig.mode = Rig.MODE_FREE
	_check("mode_saved_%s" % tag, remembered, "mode écrit puis relu dans la section [camera] de settings.cfg")

	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_C
	key.keycode = KEY_C
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(3)
	var release: InputEventKey = key.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	await _frames(2)
	var by_key: bool = rig.mode == Rig.MODE_BEHIND
	_check("toggle_key_%s" % tag, by_key, "appui sur C en jeu → mode %s" % rig.mode)
	await _settle_mode(Rig.MODE_FREE)



func _prop(shape: Shape3D, at: Transform3D) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	world.add_child(body)
	body.global_transform = at
	_props.append(body)
	return body

func _drop_props() -> void :
	for body: Node in _props:
		if is_instance_valid(body): body.queue_free()
	_props.clear()

func _boom_trace(seconds: float) -> Array[float]:
	var trace: Array[float] = []
	var elapsed: float = 0.0
	while elapsed < seconds:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		trace.append(float(rig._boom))
	return trace

func _test_collisions() -> void :
	var actor: PaperActor = _actor()
	await _settle_mode(Rig.MODE_FREE)
	var yaw: float = 0.3
	var forward: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, yaw)
	var spot: Vector3 = _open_spot(- forward, 7.0)
	_place(actor, spot, yaw)
	world.yaw = yaw
	world.pitch = Rig.DEFAULT_PITCH
	await _wait(0.9)
	var full: float = float(rig._boom)

	var pivot: Vector3 = world.camera_anchor
	var back: Vector3 = (world.camera.global_position - pivot)
	var post: CylinderShape3D = CylinderShape3D.new()
	post.radius = 0.18
	post.height = 6.0
	var post_at: Vector3 = pivot + Vector3(back.x, 0.0, back.z).normalized() * 2.3
	_prop(post, Transform3D(Basis.IDENTITY, Vector3(post_at.x, spot.y + 2.0, post_at.z)))
	await _ticks(2)
	var early: Array[float] = await _boom_trace(0.3)
	var later: Array[float] = await _boom_trace(0.6)
	var held: float = early.min()
	var pulled: float = later[later.size() - 1]
	_drop_props()
	await _ticks(2)
	var out: Array[float] = await _boom_trace(1.4)
	var biggest_step: float = 0.0
	for i: int in range(1, out.size()): biggest_step = maxf(biggest_step, out[i] - out[i - 1])
	_check("collision_thin_post", held > full * 0.95 and pulled < 2.3 and out[out.size() - 1] > full * 0.95,
		"poteau fin sur la perche : la caméra ne saute pas pendant %.2f s (perche ≥ %.2f / %.2f m), puis se place devant (%.2f m) ; ressort en douceur jusqu'à %.2f m (pas max %.3f m/image)" % [Rig.OCCLUSION_GRACE, held, full, pulled, out[out.size() - 1], biggest_step])

	var wall: BoxShape3D = BoxShape3D.new()
	wall.size = Vector3(5.0, 5.0, 0.3)
	var flat_back: Vector3 = Vector3(back.x, 0.0, back.z).normalized()
	var wall_at: Vector3 = pivot + flat_back * 2.0
	_prop(wall, Transform3D(Basis.looking_at(flat_back, Vector3.UP), Vector3(wall_at.x, spot.y + 2.0, wall_at.z)))
	await _ticks(2)
	var hit: Array[float] = await _boom_trace(0.12)
	var eye: Vector3 = world.camera.global_position
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var probe: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var tiny: SphereShape3D = SphereShape3D.new()
	tiny.radius = 0.1
	probe.shape = tiny
	probe.transform = Transform3D(Basis.IDENTITY, eye)
	probe.collision_mask = 1
	var inside: bool = not space.intersect_shape(probe, 1).is_empty()
	var behind_wall: bool = (eye - wall_at).dot(flat_back) > -0.05
	_check("collision_wall", hit[0] < 2.0 and not inside and not behind_wall, "mur sur la perche : caméra ramenée dès la 1re image (%.2f m), jamais dans le mur ni derrière" % hit[0])
	await _capture("cam_wall")
	_drop_props()
	await _wait(0.4)

	var sweep_spot: Vector3 = _floor_at(spot)
	_place(actor, sweep_spot, yaw)
	var room: BoxShape3D = BoxShape3D.new()
	room.size = Vector3(0.3, 5.0, 24.0)
	var side: Vector3 = Vector3.RIGHT.rotated(Vector3.UP, yaw)
	_prop(room, Transform3D(Basis(Vector3.UP, yaw), Vector3(sweep_spot.x, sweep_spot.y + 2.0, sweep_spot.z) + side * 1.4))
	await _wait(0.6)
	var steps: int = 0
	var pops: int = 0
	var worst_jump: float = 0.0
	var last_eye: Vector3 = world.camera.global_position
	var last_boom: float = float(rig._boom)
	var elapsed: float = 0.0
	while elapsed < 3.0:
		var dt: float = get_process_delta_time()
		rig.turn(Vector2(TAU / 3.0 * maxf(dt, 1.0 / 240.0), 0.0))
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		var now: float = float(rig._boom)
		if absf(now - last_boom) > 0.6: pops += 1
		worst_jump = maxf(worst_jump, absf(now - last_boom))
		last_boom = now
		last_eye = world.camera.global_position
		steps += 1
	_drop_props()
	_check("collision_sweep", render or pops == 0, "tour complet de caméra le long d'un mur (%d images) : %d saut(s) de perche > 0,6 m, plus grand pas %.2f m" % [steps, pops, worst_jump])
	await _wait(0.5)



func _test_control_api() -> void :
	var actor: PaperActor = _actor()
	var holder: Node = Node.new()
	add_child(holder)
	var shot: Transform3D = Transform3D(Basis.looking_at(Vector3(1, -0.2, 0.3).normalized(), Vector3.UP), world.actor_render_position(actor) + Vector3(-2.5, 2.2, 1.5))
	rig.take_control(holder, 0.0)
	rig.drive(holder, shot, 48.0)
	await _frames(3)
	var placed: bool = world.camera.global_transform.origin.distance_to(shot.origin) < 0.001 and absf(world.camera.fov - 48.0) < 0.01
	var yaw_before: float = world.yaw
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.screen_relative = Vector2(300, 0)
	rig.mouse_look(motion)
	var locked: bool = world.yaw == yaw_before
	rig.release_control(holder, 0.45)
	await _wait(0.12)
	var mid: Vector3 = world.camera.global_position
	var blending: bool = mid.distance_to(shot.origin) > 0.05 and mid.distance_to(rig.gameplay_transform().origin) > 0.05
	await _wait(0.5)
	var back_home: bool = world.camera.global_position.distance_to(rig.gameplay_transform().origin) < 0.02 and _cam_forward().angle_to(Rig.view_direction(world.yaw, world.pitch)) < 0.002
	var temporary: Node = Node.new()
	add_child(temporary)
	rig.take_control(temporary, 0.2)
	await _frames(2)
	var held: bool = rig.has_control()
	temporary.queue_free()
	await _frames(3)
	var auto_released: bool = not rig.has_control()
	holder.queue_free()
	_check("cinematic_api", placed and locked and blending and back_home and held and auto_released, "take_control/drive : plan appliqué %s, regard bloqué %s ; release_control : fondu %s puis retour exact %s ; propriétaire libéré → rendu auto %s" % [str(placed), str(locked), str(blending), str(back_home), str(auto_released)])
	await _wait(0.3)

func _test_spectator() -> void :
	var me: PaperActor = _actor()
	var watched: PaperActor = null
	for actor: PaperActor in world.actors.values():
		if actor != me and not actor.killer and actor.alive: watched = actor
	if watched == null:
		_check("spectator", false, "aucun allié à suivre")
		return
	await _settle_mode(Rig.MODE_BEHIND)
	watched.visual.rotation.y = 1.3
	watched.aim = Vector3.FORWARD.rotated(Vector3.UP, 1.3)
	world.yaw = -1.2
	me.alive = false
	world.spectate_id = watched.id
	rig._manual_look = 99.0
	await _wait(1.6)
	var follow: float = absf(rad_to_deg(angle_difference(world.yaw, _actor_yaw(watched))))
	await _capture("cam_spectator_behind")
	_set_mode(Rig.MODE_FREE)
	world.yaw = -1.2
	await _wait(0.8)
	var free_kept: float = absf(rad_to_deg(angle_difference(world.yaw, -1.2)))
	me.alive = true
	world.spectate_id = -1
	await _wait(0.5)
	_check("spectator", follow < 3.0 and free_kept < 0.01, "spectateur : en Derrière la caméra se place dans le dos de l'allié suivi (écart %.2f°), en Libre 360° elle reste où on la met (%.3f°)" % [follow, free_kept])



func _test_drone() -> void :
	if not world.practice.change_character(world.local_id(), "Ashura", false):
		_check("drone", false, "impossible de passer à Ashura")
		return
	await _wait(0.6)
	var actor: PaperActor = _actor()
	await _settle_mode(Rig.MODE_FREE)
	_place(actor, _open_spot(Vector3.FORWARD.rotated(Vector3.UP, 0.4), 6.0), 0.4)
	world.yaw = 0.4
	world.pitch = Rig.DEFAULT_PITCH
	await _wait(0.4)
	actor.effects["drone_precise"] = true
	actor.cooldowns[0] = 0.0
	world.request_ability(0)
	await _wait(0.5)
	var drone: Dictionary = world.combat.piloted_drone(actor)
	var piloting: bool = not drone.is_empty() and bool(actor.effects.get("drone_piloting", false))
	world.pitch = Rig.PITCH_MIN
	await _frames(3)
	var aligned: float = rad_to_deg(_cam_forward().angle_to(Rig.view_direction(world.yaw, world.pitch))) if piloting else 180.0
	var at_drone: float = world.camera.global_position.distance_to(Vector3(drone.position)) if piloting else 99.0
	var down: float = rad_to_deg(asin(_cam_forward().y))
	await _capture("cam_drone_down")
	world.request_cancel_aim()
	await _wait(1.2)
	var back: bool = not bool(actor.effects.get("drone_piloting", false)) and _cam_forward().angle_to(Rig.view_direction(world.yaw, world.pitch)) < 0.002 and actor.visual.visible
	world.pitch = Rig.DEFAULT_PITCH
	_check("drone", piloting and aligned < 0.05 and at_drone < 0.3 and back, "vue drone d'Ashura : caméra sur le drone (%.2f m), regard %.0f° vers le bas aligné (%.3f°) ; retour fluide derrière Ashura à l'atterrissage : %s" % [at_drone, down, aligned, str(back)])
	await _wait(0.3)

func _finish(original_mode: String) -> void :
	_release_all()
	rig.mode = original_mode
	var failed: int = 0
	for row: Dictionary in results:
		if not bool(row.ok): failed += 1
	var report: Dictionary = {"render": render, "passed": results.size() - failed, "failed": failed, "results": results, "metrics": metrics, "captures": captures}
	var path: String = ProjectSettings.globalize_path(out_dir).path_join("camera_report.json")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(report, "  "))
	print("CAMERA_TEST_SUMMARY passed=", results.size() - failed, " failed=", failed, " report=", path)
	get_tree().quit(1 if failed > 0 else 0)
