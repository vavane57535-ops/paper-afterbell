extends Node

# Mesure du niveau réel de chaque musique en jeu (0.16) : chaque piste est jouée seule
# (effets coupés, curseur Musique à sa valeur par défaut 70 %) et le bus Master est
# enregistré en WAV dans --levels-out ; mesurer ensuite avec ffmpeg -af ebur128.

var world: Node
var out_dir: String = "user://music_levels"
var _recorder: AudioEffectRecord
var _queue: Array = []
var _clock: float = 0.0
var _step: Dictionary = {}
var _stage: String = "wait"
var _extra: AudioStreamPlayer

func setup(game_world: Node) -> void :
	world = game_world
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find("--levels-out")
	if index >= 0 and index + 1 < args.size(): out_dir = args[index + 1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_recorder = AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, _recorder)
	for key: String in ["menu", "ambient", "ambient_forest", "ambient_snow", "chase", "true_form", "ending", "defeat", 
			"lms_Ashura", "lms_Usayuko", "lms_Simon", "lms_Lysia", "lms_Elly", "lms_Bleuette"]:
		_queue.append({"key": key})
	_queue.append({"key": "exit", "rush": 0.0, "at": 4.0, "name": "exit_start"})
	_queue.append({"key": "exit", "rush": 0.5, "at": 40.0, "name": "exit_middle"})
	_queue.append({"key": "exit", "rush": 1.0, "at": 63.0, "name": "exit_climax"})
	_queue.append({"key": "dance", "dance": "dance_floss", "db": -2.0, "name": "dance_floss_ingame"})
	_queue.append({"key": "dance", "dance": "dance_griddy", "db": 0.0, "name": "dance_griddy_menu"})
	index = args.find("--levels-only")
	if index >= 0 and index + 1 < args.size():
		var only: String = args[index + 1]
		_queue = _queue.filter(func(step: Dictionary) -> bool: return str(step.key).begins_with(only))

func _process(delta: float) -> void :
	_clock += delta
	var audio: PaperAudio = world.audio
	# exit_alarm remet set_rush à zéro hors partie : on impose l'intensité à chaque image
	if str(_step.get("key", "")) == "exit": audio.set_rush(float(_step.get("rush", 0.0)), -1.0)
	if _stage == "wait":
		if _clock < 2.0: return
		audio.effects_volume = 0.0
		audio.music_volume = 0.7
		audio.master_volume = 1.0
		audio.preview_begin("Ashura", "ambient")
		_stage = "next"
		return
	if _stage == "next":
		if _queue.is_empty():
			print("LEVELS_DONE")
			_cleanup()
			get_tree().quit()
			return
		_step = _queue.pop_front()
		for player: AudioStreamPlayer in audio.tracks.values():
			player.stop()
			player.volume_db = -80.0
		for key: Variant in audio._envelopes.keys(): audio._envelopes[key] = 0.0
		if is_instance_valid(_extra): _extra.queue_free()
		var key: String = str(_step.key)
		if key == "dance":
			audio.active_track = "none"
			_extra = AudioStreamPlayer.new()
			_extra.bus = &"PaperMusic"
			_extra.stream = PaperDances.music(str(_step.dance))
			_extra.volume_db = float(_step.db)
			add_child(_extra)
			_extra.play()
		else:
			audio.active_track = key
			audio.set_rush(float(_step.get("rush", 0.0)), -1.0)
			audio._load_track_now(key)
			var player: AudioStreamPlayer = audio.tracks[key]
			var length: float = player.stream.get_length() if player.stream else 60.0
			player.play(float(_step.get("at", minf(30.0, length * 0.3))))
		_clock = 0.0
		_stage = "settle"
		return
	if _stage == "settle" and _clock >= 2.0:
		_recorder.set_recording_active(true)
		_clock = 0.0
		_stage = "record"
		return
	if _stage == "record" and _clock >= 10.0:
		_recorder.set_recording_active(false)
		var sample: AudioStreamWAV = _recorder.get_recording()
		var name_value: String = str(_step.get("name", _step.key))
		if sample: sample.save_to_wav(out_dir.path_join(name_value + ".wav"))
		print("LEVELS_SAVED ", name_value)
		_stage = "next"

func _cleanup() -> void :
	for index in range(AudioServer.get_bus_effect_count(0) - 1, -1, -1):
		if AudioServer.get_bus_effect(0, index) == _recorder: AudioServer.remove_bus_effect(0, index)
	_recorder = null
	if is_instance_valid(_extra):
		_extra.stop()
		_extra.stream = null
