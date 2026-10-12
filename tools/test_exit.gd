extends Node

# Vérification de l'ouverture de la sortie (0.16).
# Lance : godot -- --simulate Simon --duration 70 --tool test_exit [--exit-out <dossier>] [--exit-audio] [--exit-plan quick|full|lms]
# Force time_left près de 80 s, capture des images (avant, annonce, pulsation rouge, +20 s, dernier appel)
# et, avec --exit-audio, enregistre le mixage final (bus Master) en WAV pour mesurer les niveaux.

var world: Node
var out_dir: String = "user://exit_test"
var plan: String = "full"
var record_audio: bool = false
var _clock: float = 0.0
var _armed: bool = false
var _open_at: float = -1.0
var _shots: Array = []
var _recorder: AudioEffectRecord
var _record_from: float = -1.0
var _record_until: float = -1.0
var _jumps: Array = []
var _log: Array = []
var _done: bool = false
var _lms_requested: bool = false

func setup(game_world: Node) -> void :
	world = game_world
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--exit-out" and i + 1 < args.size(): out_dir = args[i + 1]
		if args[i] == "--exit-plan" and i + 1 < args.size(): plan = args[i + 1]
		if args[i] == "--exit-audio": record_audio = true
	DirAccess.make_dir_recursive_absolute(out_dir)
	process_mode = Node.PROCESS_MODE_ALWAYS
	if record_audio:
		_recorder = AudioEffectRecord.new()
		AudioServer.add_bus_effect(0, _recorder)

func _note(text: String) -> void :
	var line: String = "%.2f %s" % [_clock, text]
	_log.append(line)
	print("EXIT_TEST ", line)

func _process(delta: float) -> void :
	if _done or not is_instance_valid(world): return
	_clock += delta
	if world.phase != "playing":
		if _open_at >= 0.0:
			_note("phase -> " + str(world.phase))
			_end()
		return
	if not _armed:
		if float(world.clock) < 3.0: return
		if plan == "lms" and not world.lms:
			if not _lms_requested:
				_lms_requested = true
				for a: PaperActor in world.actors.values():
					if not a.killer and a.id != world.local_id(): world.eliminate(a)
				_note("eliminated others for LMS")
			return
		_armed = true
		if "--exit-freeze" in OS.get_cmdline_user_args():
			# bots immobiles : personne ne s'échappe pendant la vérification
			for a: PaperActor in world.actors.values(): a.bot = false
		var args: PackedStringArray = OS.get_cmdline_user_args()
		if "--exit-calm" in args: world.options["reduce_flashes"] = true
		if "--exit-noscreen" in args: world.options["screen_fx"] = false
		if "--exit-view" in args: _face_exit()
		world.time_left = 81.6
		_shots.append([_clock + 0.5, "a_before"])
		_note("armed, time_left=%.1f lms=%s mode=%s" % [world.time_left, str(world.lms), world.audio.mode])
		return
	if _open_at < 0.0 and world.exit_flow.opened:
		_open_at = _clock
		_note("exit opened, time_left=%.2f mode=%s track=%s" % [world.time_left, world.audio.mode, world.audio.active_track])
		var lamps: Array = world.exit_alarm.get("_lamps")
		_note("lamps in map: %d (warning_lamps %d)" % [world.school.find_children("*", "Light3D", true, false).size(), world.warning_lamps.size()])
		_schedule()
	_run_shots()
	_run_jumps()
	_update_recording()
	if _open_at >= 0.0 and _clock - _open_at > 1.0 and _clock - _open_at - delta <= 1.0:
		var lamps: Array = world.exit_alarm.get("_lamps")
		var nearest: Light3D = null
		var me: PaperActor = world.local_actor()
		for lamp: Variant in lamps:
			if is_instance_valid(lamp) and (nearest == null or (lamp as Light3D).global_position.distance_to(me.position) < nearest.global_position.distance_to(me.position)): nearest = lamp
		if nearest: _note("tinted lamps %d, nearest %s color=%s energy=%.2f range=%s" % [lamps.size(), nearest.get_class(), str(nearest.light_color), nearest.light_energy, str(nearest.get("omni_range"))])
	if _open_at >= 0.0 and int(_clock * 2.0) != int((_clock - delta) * 2.0):
		var player: AudioStreamPlayer = world.audio.tracks.get("exit")
		_note("t=%.1f time_left=%.1f mode=%s track=%s pos=%.2f playing=%s vol=%.1f rush=%.2f level=%.2f heart=%.2f" % [_clock - _open_at, world.time_left, world.audio.mode, world.audio.active_track, player.get_playback_position() if player else -1.0, str(player.playing if player else false), player.volume_db if player else -99.0, world.exit_alarm.rush(), world.exit_alarm.level(), world.audio.heartbeat_floor])

func _face_exit() -> void :
	var me: PaperActor = world.local_actor()
	if me == null: return
	var target: Vector3 = world.school.escape_position
	var outward: Vector3 = Vector3(target.x, 0.0, target.z).normalized()
	var distance: float = 13.0
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find("--exit-view")
	if index >= 0 and index + 1 < args.size() and args[index + 1].is_valid_float(): distance = float(args[index + 1])
	me.position = Vector3(target.x, me.position.y if absf(me.position.y - target.y) < 2.0 else target.y + 0.1, target.z) - outward * distance
	me.velocity = Vector3.ZERO
	me.aim = outward
	world.yaw = atan2( - outward.x, - outward.z)
	world.pitch = -0.08
	_note("facing exit from %s" % str(me.position))

func _schedule() -> void :
	var t: float = _clock
	if plan == "quick":
		_shots += [[t + 0.3, "b_banner_slam"], [t + 1.4, "c_banner_red"], [t + 4.0, "d_music_start"]]
		_jumps = []
		_finish_at(t + 6.0)
	elif plan == "lms":
		_shots += [[t + 1.2, "b_lms_banner"], [t + 5.0, "c_lms_after"]]
		_finish_at(t + 7.0)
	else:
		_shots += [[t + 0.3, "b_banner_slam"], [t + 1.4, "c_banner_red"], [t + 2.6, "d_pulse"], [t + 4.2, "e_music_start"],
			[t + 9.5, "f_plus20"], [t + 15.2, "g_final_call"], [t + 16.5, "h_climax"], [t + 17.6, "h2_beat_a"], [t + 17.83, "h3_beat_b"], [t + 19.5, "i_last_seconds"]]
		# saute le chrono pour voir +20 s, puis la coupure finale (time_left 18) sans attendre 80 s
		_jumps = [[t + 8.0, 60.0], [t + 13.5, 19.6]]
		_finish_at(t + 21.0)
	if record_audio:
		_record_from = t - 0.05
		_record_until = t + (7.5 if plan != "full" else 20.5)
		_recorder.set_recording_active(true)
		_note("recording")

func _finish_at(t: float) -> void :
	_shots.append([t, "z_end"])

func _run_jumps() -> void :
	for jump: Array in _jumps.duplicate():
		if _clock >= float(jump[0]):
			_jumps.erase(jump)
			world.time_left = float(jump[1])
			_note("jump time_left -> %.1f" % float(jump[1]))

func _update_recording() -> void :
	if _recorder and _recorder.is_recording_active() and _clock >= _record_until:
		_recorder.set_recording_active(false)
		var sample: AudioStreamWAV = _recorder.get_recording()
		if sample:
			var path: String = out_dir.path_join("exit_mix.wav")
			sample.save_to_wav(path)
			_note("saved audio " + path + " length=%.2f" % sample.get_length())

func _run_shots() -> void :
	if _shots.is_empty() or _clock < float(_shots[0][0]): return
	var shot: Array = _shots.pop_front()
	if str(shot[1]) == "z_end":
		_end()
		return
	_capture(str(shot[1]))

func _capture(label: String) -> void :
	if DisplayServer.get_name() == "headless":
		_note("shot " + label + " (headless, skipped)")
		return
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = out_dir.path_join(label + ".png")
	image.save_png(path)
	_note("shot " + label + " -> " + path + " time_left=%.2f" % world.time_left)

func _exit_tree() -> void :
	if _recorder:
		_recorder.set_recording_active(false)
		for index in range(AudioServer.get_bus_effect_count(0) - 1, -1, -1):
			if AudioServer.get_bus_effect(0, index) == _recorder: AudioServer.remove_bus_effect(0, index)
		_recorder = null

func _end() -> void :
	if _done: return
	_done = true
	_update_recording()
	if _recorder and _recorder.is_recording_active():
		_record_until = 0.0
		_update_recording()
	var f: FileAccess = FileAccess.open(out_dir.path_join("log.txt"), FileAccess.WRITE)
	if f: f.store_string("\n".join(_log))
	_note("done")
	get_tree().quit()
