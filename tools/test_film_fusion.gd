extends Node

# Fins de manche RÉELLES jouées pendant l'alerte de sortie (0.16, vérification après fusion des lots) :
# le filtre rouge, les lampes d'urgence, les gyrophares, la sirène et la musique de course doivent
# disparaître proprement au début du film, et rien du HUD (bandeau, puce SORTIE, bandeau caméra,
# roue d'émotes, X-ray) ne doit rester par-dessus.
#   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 --resolution 960x540 --fixed-fps 30 -- \
#     --tool test_film_fusion --ff-mode lms|team|killer|blocus [--ff-person Simon] [--ff-alarm 4] \
#     [--ff-times 0,0.1,0.3,1,2.6,5] [--ff-out DIR] [--ff-map school|forest|snow] [--ff-xray] [--ff-wheel]
# Sans rendu (--headless) : seulement le journal (FF_STATE) et les vérifications (FF_CHECK / FF_RESULT).
#   lms    : LMS du perso, Alice étourdie, sortie ouverte (alerte LMS), puis évasion → victoire LMS
#   team   : sortie ouverte (alerte + musique de course), tous les survivants s'évadent → fuite en équipe
#   killer : sortie ouverte (alerte + course), Alice élimine tout le monde → victoire d'Alice
#   blocus : sortie ouverte (alerte + course), Alice (humaine) quitte → blocus
#   prologue : le film entier sans geste d'attente aléatoire (fidget) ; musique à 0 dB sur le bus PaperMusic
#   films  : relevé (sans échec) des gestes d'attente aléatoires dans les films de la cinémathèque
#   levels : enregistre le bus PaperMusic pendant le thème LMS en jeu puis pendant la victoire LMS
#            (WAV dans --ff-out, à mesurer avec ffmpeg -af ebur128) : même niveau attendu
#   kill   : exécution du perso joué (vue victime), sortie ouverte : roue d'émotes ouverte au coup fatal,
#            touche C pendant le plan, X-ray de Lysia, panneau SORTIE du jeu retiré du plan
# --ff-alarm : secondes d'alerte avant la fin (0,8 pour que la sirène soit encore en cours).
# --ff-xray : le joueur (Lysia) a son X-ray actif au moment de la fin. --ff-wheel : roue d'émotes ouverte.

var world: Node
var mode: String = "lms"
var person: String = "Simon"
var alarm_seconds: float = 4.0
var times: Array[float] = [0.0, 0.05, 0.12, 0.2, 0.3, 0.45, 0.7, 1.2, 2.6, 3.4, 5.0]
var out_dir: String = ""
var map_id: String = "school"
var with_xray: bool = false
var with_wheel: bool = false
var failures: Array[String] = []
var headless: bool = false


func setup(owner: Node) -> void :
	world = owner
	headless = DisplayServer.get_name() == "headless"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		var value: String = args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--ff-mode": mode = value
			"--ff-person": person = value
			"--ff-alarm": alarm_seconds = float(value)
			"--ff-out": out_dir = value
			"--ff-map": map_id = value
			"--ff-xray": with_xray = true
			"--ff-wheel": with_wheel = true
			"--ff-times":
				times.clear()
				for part: String in value.split(",", false): times.append(float(part))
	if not out_dir.is_empty(): DirAccess.make_dir_recursive_absolute(out_dir)
	world.selected = person
	if map_id != "school": world._rebuild_map(map_id)
	_run.call_deferred()


func _check(ok: bool, what: String) -> void :
	print("FF_CHECK ", "OK   " if ok else "FAIL ", what)
	if not ok: failures.append(what)


func _shot(label: String) -> void :
	_state(label)
	if headless or out_dir.is_empty(): return
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image: image.save_png(out_dir.path_join("%s_%s_%s.png" % [mode, person, label]))


func _track_db(key: String) -> String:
	var player: Variant = world.audio.tracks.get(key) if world.audio else null
	if player == null: return "-"
	return "%s%.1f" % ["▶" if (player as AudioStreamPlayer).playing else "■", (player as AudioStreamPlayer).volume_db]


func _state(label: String) -> void :
	var alarm: Node = world.get("exit_alarm")
	var siren: AudioStreamPlayer = alarm.get("_alarm") if alarm else null
	var rig: Variant = alarm.get("_rig") if alarm else null
	var badge: Variant = world.camera_rig.get("_badge") if world.camera_rig else null
	var fx: Node = null
	for child: Node in world.get_children():
		if child is PaperSurvivorFx: fx = child
	var xray: float = float(fx.get("_xray_alpha")) if fx != null else 0.0
	print("FF_STATE %s phase=%s cinema=%.2f film=%s level=%.3f grade=%s glow=%s rig=%s siren=%s banner=%s compass=%s badge=%s wheel=%s xray=%.2f track=%s exit=%s lms=%s ending=%s chase=%s heart_floor=%.2f" % [
		label, world.phase, float(world.cinema), str(world.film.kind),
		float(alarm.get("_level")) if alarm else -1.0,
		str(alarm._grade.visible) if alarm else "-", str(alarm._glow.visible) if alarm else "-",
		str(is_instance_valid(rig) and (rig as Node3D).visible),
		("%.2f@%.1fdB" % [siren.get_playback_position(), siren.volume_db]) if siren and siren.playing else "off",
		str(alarm._banner.visible) if alarm else "-", str(alarm._compass.visible) if alarm else "-",
		str(is_instance_valid(badge) and (badge as Control).visible), str(world.emote_wheel.visible), xray,
		str(world.audio.active_track), _track_db("exit"), _track_db("lms_" + person), _track_db("ending"), _track_db("chase"),
		float(world.audio.heartbeat_floor)])


func _wait(seconds: float) -> void :
	var until: float = float(world.clock) + seconds
	while str(world.phase) == "playing" and float(world.clock) < until:
		_hold_alice()
		await get_tree().process_frame


func _hold_alice() -> void :
	var alice: PaperActor = world.killer_actor()
	if alice: alice.effects["stun"] = 2.0


func _run() -> void :
	for i: int in range(6): await get_tree().process_frame
	if mode == "films":
		await _run_films()
		print("FF_RESULT ", "OK" if failures.is_empty() else "FAIL " + ", ".join(failures))
		get_tree().quit()
		return
	if mode == "prologue":
		await _run_prologue()
		print("FF_RESULT ", "OK" if failures.is_empty() else "FAIL " + ", ".join(failures))
		get_tree().quit()
		return
	world.start_solo(false)
	var waited: int = 0
	while str(world.phase) != "playing" and waited < 2000:
		await get_tree().process_frame
		waited += 1
	_check(str(world.phase) == "playing", "la manche démarre (%s)" % str(world.phase))
	await _wait(2.0)
	if mode == "levels":
		await _run_levels()
		print("FF_RESULT ", "OK" if failures.is_empty() else "FAIL " + ", ".join(failures))
		get_tree().quit()
		return
	if mode == "kill":
		await _run_kill()
		print("FF_RESULT ", "OK" if failures.is_empty() else "FAIL " + ", ".join(failures))
		get_tree().quit()
		return
	var me: PaperActor = world.local_actor()
	var alice: PaperActor = world.killer_actor()
	# bots figés (personne ne s'évade ni ne meurt avant la fin voulue), sauf Alice
	for a: PaperActor in world.actors.values():
		if not a.killer: a.bot = false
	if mode == "lms":
		for a: PaperActor in world.actors.values():
			if not a.killer and a != me: world.eliminate(a)
		var guard: int = 0
		while not bool(world.lms) and guard < 300:
			_hold_alice()
			await get_tree().process_frame
			guard += 1
		_check(bool(world.lms), "LMS de %s" % person)
		await _wait(1.0)
	world.time_left = 79.6
	var opened: int = 0
	while not world.exit_flow.opened and opened < 120:
		_hold_alice()
		await get_tree().process_frame
		opened += 1
	_check(world.exit_flow.opened, "sortie ouverte")
	await _wait(0.5)
	await _shot("alarm_a")
	await _wait(maxf(0.05, alarm_seconds - 0.5))
	if with_xray and me: me.effects["xray"] = 3.0
	if with_wheel: world.emote_wheel.open()
	await _shot("alarm_b")
	_check(float(world.exit_alarm.get("_level")) > 0.9, "alerte active avant la fin (niveau %.2f)" % float(world.exit_alarm.get("_level")))
	# fin de manche
	match mode:
		"lms", "team":
			for a: PaperActor in world.living_survivors():
				a.position = world.school.escape_position + Vector3(0.0, 0.05, 0.0)
				a.velocity = Vector3.ZERO
		"killer":
			for a: PaperActor in world.actors.values():
				if not a.killer and a.alive:
					a.effects["death_source"] = alice.id
					world.eliminate(a)
		"blocus":
			alice.bot = false
			PaperAliceForfeit.peer_left(world, alice.id)
	var guard_end: int = 0
	while str(world.phase) == "playing" and guard_end < 200:
		await get_tree().process_frame
		guard_end += 1
	_check(str(world.phase) == "ending", "fin de manche (%s, %s)" % [str(world.phase), str(world.ending_kind)])
	print("FF_ENDING kind=", world.ending_kind, " film=", world.film.kind, " duration=", world.film.duration, " people=", world.ending_people)
	var index: int = 0
	var siren_until: float = -1.0
	var rush_until: float = -1.0
	var red_until: float = -1.0
	var marks_until: float = -1.0
	while str(world.phase) == "ending" and not bool(world.ending_presented) and index < times.size():
		var t: float = float(world.cinema)
		var siren_player: AudioStreamPlayer = world.exit_alarm.get("_alarm")
		if siren_player.playing and siren_player.volume_db > -60.0: siren_until = t
		var rush_player: AudioStreamPlayer = world.audio.tracks.get("exit")
		if rush_player and rush_player.playing and rush_player.volume_db > -60.0: rush_until = t
		if float(world.exit_alarm.get("_level")) > 0.001: red_until = t
		var items: Variant = world.get("map_interactables")
		if t > 0.05 and is_instance_valid(items) and ((items.exit_sign as Node3D).visible or (items.exit_glow as Node3D).visible): marks_until = t
		if t + 0.0001 >= times[index]:
			while index < times.size() and times[index] <= t + 0.0001: index += 1
			await _shot("film_%05.2f" % t)
			continue
		await get_tree().process_frame
	print("FF_TAIL red_until=%.2f siren_until=%.2f rush_until=%.2f" % [red_until, siren_until, rush_until])
	_check(red_until < 0.05, "alerte visuelle coupée dès le premier plan (jusqu'à %.2f s)" % red_until)
	# fondu de la sirène d'exit_alarm (jusqu'à -60 dB, environ 0,35 s)
	_check(siren_until < 0.45, "sirène effacée au début du film (jusqu'à %.2f s)" % siren_until)
	_check(rush_until < 0.45, "musique de course coupée au début du film (jusqu'à %.2f s)" % rush_until)
	_check(marks_until < 0.0, "panneau « SORTIE · … » et anneau de la sortie absents du film (vus jusqu'à %.2f s)" % marks_until)
	var alarm: Node = world.exit_alarm
	_check(float(alarm.get("_level")) <= 0.001, "filtre rouge coupé pendant le film (niveau %.3f)" % float(alarm.get("_level")))
	_check(not alarm._grade.visible and not alarm._glow.visible, "filtre et halo masqués pendant le film")
	var rig: Variant = alarm.get("_rig")
	_check(not (is_instance_valid(rig) and (rig as Node3D).visible), "gyrophares masqués pendant le film")
	_check(not (alarm.get("_alarm") as AudioStreamPlayer).playing, "sirène coupée pendant le film")
	_check(not world.emote_wheel.visible, "roue d'émotes fermée pendant le film")
	print("FF_RESULT ", "OK" if failures.is_empty() else "FAIL " + ", ".join(failures))
	get_tree().quit()


func _run_kill() -> void :
	var me: PaperActor = world.local_actor()
	var alice: PaperActor = world.killer_actor()
	for a: PaperActor in world.actors.values():
		a.bot = false
		a.move_input = Vector3.ZERO
		a.velocity = Vector3.ZERO
	world.time_left = 70.0
	await _wait(1.0)
	_check(world.exit_flow.opened, "sortie ouverte avant l'exécution")
	var base: Vector3 = world.school.spawn_points[1] + Vector3(0, 0, -9)
	me.global_position = base
	me.reset_physics_interpolation()
	alice.global_position = base + Vector3(0.6, 0, -2.4)
	alice.aim = (base - alice.global_position).normalized()
	alice.reset_physics_interpolation()
	if me.character != "Lysia": me.effects["revived"] = true
	me.hp = 1.0
	if with_xray: me.effects["xray"] = 3.0
	alice.effects["stun"] = 0.0
	world.emote_wheel.open()
	await get_tree().process_frame
	await _shot("kill_before")
	for attempt in range(8):
		world.combat.damage(me, 999.0, alice, false, "slash")
		if bool(me.effects.get("dying", false)): break
	var guard: int = 0
	while not bool(world.kill_scenes.cinematic()) and guard < 120:
		await get_tree().process_frame
		guard += 1
	_check(bool(world.kill_scenes.cinematic()), "l'exécution prend la caméra")
	await get_tree().process_frame
	_check(not world.emote_wheel.visible, "roue d'émotes fermée au début de l'exécution")
	var mode_before: String = str(world.camera_rig.mode)
	var yaw_before: float = float(world.yaw)
	var press: InputEventAction = InputEventAction.new()
	press.action = &"camera_mode"
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame
	var release: InputEventAction = InputEventAction.new()
	release.action = &"camera_mode"
	release.pressed = false
	Input.parse_input_event(release)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.relative = Vector2(240, 60)
	motion.screen_relative = Vector2(240, 60)
	world.camera_rig.mouse_look(motion)
	for k: int in range(10): await get_tree().process_frame
	var badge: Variant = world.camera_rig.get("_badge")
	_check(str(world.camera_rig.mode) == mode_before, "touche C ignorée pendant l'exécution (%s -> %s)" % [mode_before, str(world.camera_rig.mode)])
	_check(not (is_instance_valid(badge) and (badge as Control).visible), "pas de bandeau caméra sur l'exécution")
	_check(absf(angle_difference(yaw_before, float(world.yaw))) < 0.001, "visée bloquée pendant l'exécution")
	await _wait(0.5)
	var alarm: Node = world.exit_alarm
	# Pendant le plan, l'alerte passe à mi-intensité (exit_alarm : 0,45) pour que l'éclairage film reste lisible.
	_check(float(alarm.get("_level")) <= 0.5, "alerte atténuée pendant l'exécution (niveau %.2f)" % float(alarm.get("_level")))
	var masked: bool = (world.camera.cull_mask & world.kill_scenes.SIGN_LAYER) == 0
	_check(masked, "panneau SORTIE du jeu retiré des plans de l'exécution")
	var fx: Node = null
	for child: Node in world.get_children():
		if child is PaperSurvivorFx: fx = child
	if with_xray and fx != null: _check(float(fx.get("_xray_alpha")) <= 0.001, "X-ray (prises) masqué pendant l'exécution (%.2f)" % float(fx.get("_xray_alpha")))
	for t: float in [0.6, 1.6, 2.6, 3.6]:
		await _wait(t - (0.6 if t > 0.6 else 0.0) if t == 0.6 else 1.0)
		await _shot("kill_%.1f" % t)
		if is_equal_approx(t, 1.6):
			_check(float(world.audio.get("_hurt_level")) < 0.05, "son de l'exécution non étouffé par l'effet « blessé » (%.2f)" % float(world.audio.get("_hurt_level")))
			_check(float(world.audio.heartbeat_floor) <= 0.0, "pas de cœur de l'alerte sur l'exécution (%.2f)" % float(world.audio.heartbeat_floor))
	var wait_end: int = 0
	while bool(world.kill_scenes.cinematic()) and wait_end < 600:
		await get_tree().process_frame
		wait_end += 1
	for k: int in range(5): await get_tree().process_frame
	_check(not bool(world.kill_scenes.cinematic()), "fin de l'exécution")
	_check((world.camera.cull_mask & world.kill_scenes.SIGN_LAYER) != 0, "panneau SORTIE rendu à la caméra de jeu après l'exécution")
	for k: int in range(20): await get_tree().process_frame
	_check(world.exit_alarm._grade.visible and float(world.exit_alarm.get("_level")) > 0.6, "filtre rouge revenu après l'exécution (niveau %.2f)" % float(world.exit_alarm.get("_level")))
	await _wait(1.5)
	var rush: AudioStreamPlayer = world.audio.tracks.get("exit")
	var track: String = str(world.audio.active_track)
	var music_on: bool = (track == "exit" and rush != null and rush.playing) or (track != "exit" and world.audio.tracks.has(track) and (world.audio.tracks[track] as AudioStreamPlayer).playing)
	print("FF_AFTER_KILL time_left=%.1f exit_open=%s track=%s rush_playing=%s" % [float(world.time_left), str(world.exit_flow.opened), track, str(rush.playing if rush else false)])
	_check(music_on, "musique après le bonus de +45 s pendant la sortie ouverte (piste %s)" % track)
	await _shot("kill_after")


func _run_prologue() -> void :
	world.play_prologue()
	_check(str(world.phase) == "prologue", "prologue lancé")
	var film: Node = world.prologue
	world.set_process(false)
	var fidgets: Array[String] = []
	var seen: Dictionary = {}
	var t: float = 0.0
	while t <= float(film.duration):
		film.update(t, 1.0 / 30.0)
		for take: Variant in film.takes:
			var fidgeting: bool = float(take.visual.get("_fidget_time")) >= 0.0
			if fidgeting and not seen.get(take.person, false): fidgets.append("%s@%.1f" % [take.person, t])
			seen[take.person] = fidgeting
		t += 1.0 / 30.0
	world.set_process(true)
	_check(fidgets.is_empty(), "aucun geste d'attente aléatoire dans le prologue (%s)" % ", ".join(fidgets))
	var music: AudioStreamPlayer = film.get("_music")
	if music: _check(absf(music.volume_db) < 0.01, "musique du prologue à 0 dB sur le bus PaperMusic (%.1f dB)" % music.volume_db)
	world.end_prologue()


func _run_films() -> void :
	world.gallery.open()
	for k: int in range(3): await get_tree().process_frame
	for entry: Dictionary in world.gallery.entries:
		if str(entry.id) == "intro_yiero": continue
		world.gallery.play_entry(entry)
		world.gallery.playing = false
		await get_tree().process_frame
		var film: Node = world.film
		var found: Array[String] = []
		var seen: Dictionary = {}
		var t: float = 0.0
		while t <= float(film.duration):
			film.update(t, 1.0 / 30.0)
			for take: Variant in film.takes:
				var fidgeting: bool = float(take.visual.get("_fidget_time")) >= 0.0
				if fidgeting and not seen.get(take.person, false): found.append("%s@%.1f" % [take.person, t])
				seen[take.person] = fidgeting
			t += 1.0 / 30.0
		print("FF_FIDGETS %s (%s) %s" % [str(entry.id), str(entry.kind), ", ".join(found) if not found.is_empty() else "aucun"])
		world.gallery.browse()
		await get_tree().process_frame
	world.gallery.close()


func _record_music(seconds: float, file_name: String) -> void :
	var bus: int = AudioServer.get_bus_index(&"PaperMusic")
	var recorder: AudioEffectRecord = AudioEffectRecord.new()
	AudioServer.add_bus_effect(bus, recorder)
	recorder.set_recording_active(true)
	var until: float = Time.get_ticks_msec() * 0.001 + seconds
	while Time.get_ticks_msec() * 0.001 < until:
		_hold_alice()
		await get_tree().process_frame
	recorder.set_recording_active(false)
	var sample: AudioStreamWAV = recorder.get_recording()
	if sample and not out_dir.is_empty():
		sample.save_to_wav(out_dir.path_join(file_name))
		print("FF_WAV ", out_dir.path_join(file_name), " ", sample.get_length(), " s")
	for index: int in range(AudioServer.get_bus_effect_count(bus)):
		if AudioServer.get_bus_effect(bus, index) == recorder:
			AudioServer.remove_bus_effect(bus, index)
			break


func _run_levels() -> void :
	world.start_solo(false)
	var waited: int = 0
	while str(world.phase) != "playing" and waited < 2000:
		await get_tree().process_frame
		waited += 1
	await _wait(1.5)
	var me: PaperActor = world.local_actor()
	for a: PaperActor in world.actors.values():
		if not a.killer: a.bot = false
		if not a.killer and a != me: world.eliminate(a)
	var guard: int = 0
	while not bool(world.lms) and guard < 300:
		_hold_alice()
		await get_tree().process_frame
		guard += 1
	_check(bool(world.lms), "LMS de %s" % person)
	await _wait(3.0)
	await _record_music(8.0, "levels_lms_%s.wav" % person)
	me.position = world.school.escape_position + Vector3(0.0, 0.05, 0.0)
	world.time_left = 79.0
	var guard_end: int = 0
	while str(world.phase) == "playing" and guard_end < 400:
		_hold_alice()
		await get_tree().process_frame
		guard_end += 1
	_check(str(world.ending_kind) == "ending_lms", "victoire LMS (%s)" % str(world.ending_kind))
	await _record_music(float(world.film.duration) - 0.2, "levels_victory_%s.wav" % person)
