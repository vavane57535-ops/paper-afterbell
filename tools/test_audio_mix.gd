extends Node

# Situations réelles pour mesurer le mixage final (0.16) ; à combiner avec tools/mix_recorder.gd
# qui enregistre le bus Master :
#   godot --headless -- --tool test_audio_mix --mix menu --tool mix_recorder --rec-out /tmp/menu.wav
# Situations (--mix) :
#   menu                 menu principal (musique du menu), --mix-len s puis quitte
#   shop                 boutique avec l'aperçu de la danse --mix-dance (musique du menu + aperçu)
#   gallery              cinémathèque : joue l'entrée --mix-entry (ex. lms_win_Simon, intro_yiero, blocus)
#                        du début à la fin en temps réel, puis quitte
#   blocus               forfait d'Alice en solo (vrai déroulé) : film du blocus joué jusqu'au bout
#   dance                partie (--simulate X) : un survivant danse --mix-dance à --mix-dist m de la
#                        caméra (0 = le joueur local danse lui-même) ; --mix-hold coupe les pistes
#                        de PaperAudio pour isoler la danse
#   exit                 partie (--simulate X) : chrono à 81,6 s, bots figés, Alice au loin ; la sortie
#                        s'ouvre et la course se joue en entier jusqu'à 0:00
#   tracks               chaque piste de PaperAudio jouée seule par son vrai chemin de gain
#                        (--mix-keys a,b,c ; --mix-at s ; --mix-len s) : un WAV par piste dans --mix-out
# Le journal « MIX_TEST » donne les instants utiles (temps réel depuis le lancement de l'outil).

var world: Node
var scene: String = "menu"
var args: Dictionary = {}
var _t0: int = 0
var _hold_camera: bool = false
var _dancer: PaperActor
var _recorder: AudioEffectRecord

func setup(game_world: Node) -> void :
	world = game_world
	process_mode = Node.PROCESS_MODE_ALWAYS
	var raw: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(raw.size()):
		if raw[i].begins_with("--mix"):
			args[raw[i].substr(2)] = raw[i + 1] if i + 1 < raw.size() and not raw[i + 1].begins_with("--") else "1"
	scene = str(args.get("mix", "menu"))
	_t0 = Time.get_ticks_msec()
	_run.call_deferred()

func _now() -> float:
	return float(Time.get_ticks_msec() - _t0) / 1000.0

func _note(text: String) -> void :
	print("MIX_TEST %.2f %s" % [_now(), text])

func _wait(seconds: float) -> void :
	var goal: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < goal: await get_tree().process_frame

func _arg(key: String, fallback: String) -> String:
	return str(args.get(key, fallback))

func _run() -> void :
	for i: int in range(3): await get_tree().process_frame
	match scene:
		"menu": await _menu()
		"shop": await _shop()
		"gallery": await _gallery()
		"blocus": await _blocus()
		"dance": await _dance()
		"exit": await _exit()
		"tracks": await _tracks()
		_: _note("situation inconnue " + scene)
	_note("end")
	get_tree().quit()

func _menu() -> void :
	_note("menu phase=%s mode=%s track=%s" % [world.phase, world.audio.mode, world.audio.active_track])
	await _wait(float(_arg("mix-len", "30")))

func _shop() -> void :
	await _wait(float(_arg("mix-pre", "6")))
	world.ui.shop_selected = _arg("mix-dance", "dance_sixseven")
	world.ui.show_shop()
	_note("shop open dance=%s" % world.ui.shop_selected)
	await _wait(float(_arg("mix-len", "20")))
	world.ui.show_main()
	_note("back to main")
	await _wait(float(_arg("mix-post", "5")))

func _gallery() -> void :
	await _wait(1.0)
	world.gallery.open()
	var wanted: String = _arg("mix-entry", "lms_win_Simon")
	var entry: Dictionary = {}
	for item: Dictionary in world.gallery.entries:
		if str(item.id) == wanted: entry = item
	if entry.is_empty():
		_note("entrée introuvable " + wanted)
		return
	await _wait(0.5)
	world.gallery.play_entry(entry)
	var film: PaperCinema = world.gallery._film()
	_note("film start %s duration=%.2f" % [wanted, film.duration])
	var last_mark: int = -1
	while world.gallery.playing:
		await get_tree().process_frame
		var mark: int = int(world.gallery.time / 5.0)
		if mark != last_mark:
			last_mark = mark
			_note("film t=%.2f" % world.gallery.time)
	_note("film end t=%.2f" % world.gallery.time)
	await _wait(float(_arg("mix-post", "1.5")))

func _blocus() -> void :
	world.selected = _arg("mix-as", "Simon")
	world.start_solo(false)
	while world.phase != "playing": await get_tree().process_frame
	await _wait(2.5)
	var alice: PaperActor = world.killer_actor()
	alice.bot = false
	_note("forfeit")
	PaperAliceForfeit.peer_left(world, alice.id)
	_note("film start %s duration=%.2f track=%s" % [world.film.kind, world.film.duration, world.audio.active_track])
	while world.phase == "ending" and not world.ending_presented: await get_tree().process_frame
	_note("film end, results")
	await _wait(float(_arg("mix-post", "3")))

func _freeze_round() -> PaperActor:
	while world.phase != "playing": await get_tree().process_frame
	await _wait(1.0)
	var local: PaperActor = world.local_actor()
	for a: PaperActor in world.actors.values():
		a.bot = false;a.move_input = Vector3.ZERO;a.sprint = false
		if a.killer:
			a.position = local.position + Vector3(120.0, 0.0, 0.0);a.net_position = a.position
	return local

func _dance() -> void :
	var local: PaperActor = await _freeze_round()
	var dist: float = float(_arg("mix-dist", "6"))
	var id: String = _arg("mix-dance", "dance_floss")
	if args.has("mix-hold"): world.audio.hold_music(true)
	await _wait(2.0)
	_dancer = local
	if dist > 0.0:
		for a: PaperActor in world.actors.values():
			if a != local and not a.killer and a.active():
				_dancer = a
				break
		var cam: Vector3 = world.camera.global_position
		var ahead: Vector3 = - world.camera.global_basis.z
		ahead.y = 0.0
		ahead = ahead.normalized()
		var spot: Vector3 = Vector3(cam.x, local.position.y, cam.z) + ahead * dist
		_dancer.position = spot;_dancer.net_position = spot
		# les autres survivants s'écartent (pas de second danseur ni de pas)
		var away: int = 0
		for a: PaperActor in world.actors.values():
			if a == local or a == _dancer or a.killer: continue
			away += 1
			a.position = local.position + Vector3(-60.0 - 5.0 * away, 0.0, 0.0);a.net_position = a.position
	await _wait(1.0)
	world._start_emote(_dancer, id)
	_note("dance start %s by %s" % [id, _dancer.character])
	var length: float = float(_arg("mix-len", "20"))
	var until: float = _now() + length
	var report: float = 0.0
	while _now() < until:
		await get_tree().process_frame
		if _now() >= report:
			report = _now() + 2.0
			var players: Array = world.emote_sync._music
			var gap: float = (_dancer.position + Vector3.UP * 1.2).distance_to(world.camera.global_position)
			_note("dance t=%.1f emote=%s players=%d distance=%.2f" % [float(_dancer.effects.get("emote_time", -1.0)), str(_dancer.effects.get("emote_id", "")), players.size(), gap])

func _exit() -> void :
	var local: PaperActor = await _freeze_round()
	await _wait(2.0)
	world.time_left = 81.6
	_note("time_left set 81.6 mode=%s" % world.audio.mode)
	var opened: bool = false
	var last: int = -1
	while world.phase == "playing":
		await get_tree().process_frame
		if not opened and world.exit_flow.opened:
			opened = true
			_note("exit opened time_left=%.2f" % world.time_left)
		var mark: int = int(world.time_left / 5.0)
		if mark != last:
			last = mark
			var p: AudioStreamPlayer = world.audio.tracks.get("exit")
			_note("time_left=%.2f mode=%s pos=%.2f" % [world.time_left, world.audio.mode, p.get_playback_position() if p.playing else -1.0])
	_note("phase -> %s outcome=%s" % [world.phase, world.outcome])
	await _wait(float(_arg("mix-post", "2")))

# Chaque piste seule par le vrai calcul de gain de PaperAudio._process (bus PaperMusic, TRACK_GAINS,
# enveloppe, filtre et volume de la course) ; effets coupés.
func _tracks() -> void :
	var out_dir: String = _arg("mix-out", "user://mix_tracks")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_recorder = AudioEffectRecord.new()
	AudioServer.add_bus_effect(0, _recorder)
	var audio: PaperAudio = world.audio
	audio.effects_volume = 0.0
	await _wait(1.5)
	audio.preview_begin("Ashura", "ambient")
	var keys: Array = _arg("mix-keys", "menu,ambient,ambient_forest,ambient_snow,chase,true_form,ending,defeat,blocus,lms_Ashura,lms_Usayuko,lms_Simon,lms_Lysia,lms_Elly,lms_Bleuette").split(",", false)
	var length: float = float(_arg("mix-len", "20"))
	var rows: Array = []
	for key: String in keys:
		for player: AudioStreamPlayer in audio.tracks.values(): player.stop();player.volume_db = -80.0
		for k: Variant in audio._envelopes.keys(): audio._envelopes[k] = 0.0
		audio.active_track = key
		audio._load_track_now(key)
		var player: AudioStreamPlayer = audio.tracks[key]
		var at: float = float(_arg("mix-at", "20"))
		at = minf(at, maxf(0.0, player.stream.get_length() - length - 4.0))
		player.play(at)
		await _wait(2.0)
		var from: float = player.get_playback_position()
		_recorder.set_recording_active(true)
		await _wait(length)
		_recorder.set_recording_active(false)
		var sample: AudioStreamWAV = _recorder.get_recording()
		var path: String = out_dir.path_join(key + ".wav")
		if sample: sample.save_to_wav(path)
		rows.append({"key": key, "file": audio._track_path(key), "from": from, "length": length, "pitch": player.pitch_scale, "volume_db": player.volume_db, "bus_db": AudioServer.get_bus_volume_db(AudioServer.get_bus_index(audio.MUSIC_BUS))})
		_note("track %s from=%.2f pitch=%.2f volume_db=%.2f" % [key, from, player.pitch_scale, player.volume_db])
	var f: FileAccess = FileAccess.open(out_dir.path_join("tracks.json"), FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(rows, "  "))
	audio.preview_end()
	for index in range(AudioServer.get_bus_effect_count(0) - 1, -1, -1):
		if AudioServer.get_bus_effect(0, index) == _recorder: AudioServer.remove_bus_effect(0, index)
	_recorder = null
