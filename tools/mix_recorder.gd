extends Node

# Enregistreur du mixage final (bus Master, après le limiteur de PaperMix) pour mesurer les
# niveaux réels du jeu avec ffmpeg -af ebur128. S'ajoute à n'importe quel autre outil :
#   godot --headless -- --simulate Simon --tool test_kills --kill all --tool mix_recorder --rec-out /tmp/x.wav
# Options :
#   --rec-out F     fichier WAV écrit à la fin (durée atteinte ou fermeture du jeu)
#   --rec-start S   délai avant l'enregistrement, en secondes réelles (défaut 0)
#   --rec-len S     durée maximale (défaut : jusqu'à la fermeture)
#   --rec-fx V / --rec-music V / --rec-master V   impose les volumes (défaut : réglages du jeu)
#   --rec-muted     coupe les sons (réglage « Couper les sons ») pour vérifier le silence
#   --rec-prelimit  enregistre AVANT le limiteur de PaperMix, atténué de 12 dB (pas d'écrêtage du WAV
#                   16 bits) : ajouter 12 dB aux mesures ; montre ce que le limiteur rabote
# Le journal « MIX_REC t=… » (temps de l'enregistrement) note chaque changement de phase, de mode
# audio, de piste, d'ouverture de sortie, de LMS et de film, pour relier la courbe aux événements.

var world: Node
var out_path: String = "user://mix.wav"
var start_after: float = 0.0
var max_length: float = -1.0
var _forced: Dictionary = {}
var _recorder: AudioEffectRecord
var _started_ms: int = -1
var _setup_ms: int = 0
var _saved: bool = false
var _last_state: String = ""
var _bus: int = 0
var _pads: Array = []

func setup(game_world: Node) -> void :
	world = game_world
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in range(args.size()):
		var next: String = args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--rec-out": out_path = next
			"--rec-start": start_after = float(next)
			"--rec-len": max_length = float(next)
			"--rec-fx": _forced["effects_volume"] = float(next)
			"--rec-music": _forced["music_volume"] = float(next)
			"--rec-master": _forced["master_volume"] = float(next)
			"--rec-muted": _forced["muted"] = true
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	_recorder = AudioEffectRecord.new()
	if "--rec-prelimit" in args and AudioServer.get_bus_index(&"PaperMix") >= 0:
		_bus = AudioServer.get_bus_index(&"PaperMix")
		var down: AudioEffectAmplify = AudioEffectAmplify.new();down.volume_db = -12.0
		var up: AudioEffectAmplify = AudioEffectAmplify.new();up.volume_db = 12.0
		_pads = [down, up]
		AudioServer.add_bus_effect(_bus, down, 0)
		AudioServer.add_bus_effect(_bus, _recorder, 1)
		AudioServer.add_bus_effect(_bus, up, 2)
	else: AudioServer.add_bus_effect(0, _recorder)
	_setup_ms = Time.get_ticks_msec()
	_apply_forced()

func _apply_forced() -> void :
	if world == null or world.audio == null: return
	for key: String in _forced: world.audio.set(key, _forced[key])

func _process(_delta: float) -> void :
	if _saved: return
	_apply_forced()
	var now: int = Time.get_ticks_msec()
	if _started_ms < 0:
		if float(now - _setup_ms) / 1000.0 < start_after: return
		_started_ms = now
		_recorder.set_recording_active(true)
		print("MIX_REC start ", out_path, " music=%.2f fx=%.2f master=%.2f muted=%s" % [world.audio.music_volume, world.audio.effects_volume, world.audio.master_volume, str(world.audio.muted)])
	var t: float = float(now - _started_ms) / 1000.0
	_log_state(t)
	if max_length > 0.0 and t >= max_length: save()

func _log_state(t: float) -> void :
	var audio: PaperAudio = world.audio
	var parts: PackedStringArray = [str(world.phase), "mode=" + audio.mode, "track=" + audio.active_track]
	if world.exit_flow and world.exit_flow.opened: parts.append("exit_open")
	if bool(world.lms): parts.append("lms")
	if world.film and not str(world.film.kind).is_empty() and world.phase in ["ending", "gallery"]: parts.append("film=" + str(world.film.kind))
	if world.prologue and not str(world.prologue.kind).is_empty(): parts.append("prologue")
	var state: String = " ".join(parts)
	if state == _last_state: return
	_last_state = state
	print("MIX_REC t=%.2f %s" % [t, state])

func save() -> void :
	if _saved or _recorder == null: return
	_saved = true
	_recorder.set_recording_active(false)
	var sample: AudioStreamWAV = _recorder.get_recording()
	if sample:
		sample.save_to_wav(out_path)
		print("MIX_REC saved ", out_path, " %.2f s" % sample.get_length(), " (avant limiteur, -12 dB)" if not _pads.is_empty() else "")
	else: print("MIX_REC empty")
	_detach()

func _detach() -> void :
	for index in range(AudioServer.get_bus_effect_count(_bus) - 1, -1, -1):
		var effect: AudioEffect = AudioServer.get_bus_effect(_bus, index)
		if effect == _recorder or effect in _pads: AudioServer.remove_bus_effect(_bus, index)
	_pads.clear()

func _exit_tree() -> void :
	if not _saved and _started_ms >= 0: save()
	elif not _saved: _detach()
	_recorder = null
