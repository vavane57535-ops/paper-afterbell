extends Node

# Vérifications des interactions entre lots 0.16 (audit du jeu fusionné).
#   godot --headless -- --tool test_crosscode [--cross rush_bonus,exec_camera,siren_end,debris_end] [--out dossier]
# Chaque plan relance une manche solo, pilote la situation et affiche
#   CROSS_RESULT <plan> OK|FAIL <détails>
# puis CROSS_TEST OK|FAIL à la fin. Sous xvfb (rendu), exec_camera et debris_end
# enregistrent aussi des images dans --out (avec --mobile-test : commandes tactiles).
#
# Plans :
#   rush_bonus  : sortie ouverte, Alice élimine un élève (+45 s) : la musique de course ne doit
#                 ni se couper ni rester muette ; un saut en arrière se fait sur la mesure.
#   exec_camera : pendant une exécution vue par Alice, C, la souris et le stick ne doivent ni
#                 afficher le bandeau caméra, ni changer de mode, ni tourner la vue ; tout revient après.
#   siren_end   : la manche se termine juste après l'ouverture de la sortie : la sirène ne
#                 déborde pas sur le film de fin.
#   debris_end  : la dernière survivante (Lysia) est exécutée sur le plateau du film de fin :
#                 aucun débris de l'exécution ne doit apparaître dans le film.
#   exec_victim : la victime locale avait la roue d'émotes ouverte : elle se referme au début du plan.
#   exec_alarm  : exécution pendant l'alerte de sortie (images seulement, à regarder).
# Par défaut : rush_bonus, exec_camera, siren_end, debris_end, exec_victim.

var world
var plans: Array[String] = []
var out_dir: String = "user://cross_test"
var failures: Array[String] = []
var headless: bool = false


func setup(w) -> void:
	world = w
	headless = DisplayServer.get_name() == "headless"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in range(args.size()):
		var next: String = args[i + 1] if i + 1 < args.size() else ""
		if args[i] == "--cross": plans.assign(next.split(",", false))
		if args[i] == "--out": out_dir = next
	if plans.is_empty(): plans.assign(["rush_bonus", "exec_camera", "siren_end", "debris_end", "exec_victim"])
	DirAccess.make_dir_recursive_absolute(out_dir)
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Le banc ne doit rien écrire dans user://settings.cfg (partagé entre les copies de travail).
	if world.camera_rig: world.camera_rig.persist = false
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	for plan: String in plans:
		match plan:
			"rush_bonus": await _plan_rush_bonus()
			"exec_camera": await _plan_exec_camera()
			"siren_end": await _plan_siren_end()
			"debris_end": await _plan_debris_end()
			"exec_victim": await _plan_exec_victim()
			"exec_alarm": await _plan_exec_alarm()
			_: _fail(plan, "plan inconnu")
	print("CROSS_TEST ", "OK" if failures.is_empty() else "FAIL", " ", JSON.stringify(failures))
	get_tree().quit()


func _fail(plan: String, why: String) -> void:
	failures.append(plan + ": " + why)


func _report(plan: String, before: int, details: String) -> void:
	print("CROSS_RESULT ", plan, " ", "OK" if failures.size() == before else "FAIL", " ", details)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _round(local_name: String, as_killer: bool) -> bool:
	world.selected = local_name
	world.start_solo(as_killer)
	var waited: float = 0.0
	while world.phase != "playing" and waited < 20.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	if world.phase != "playing": return false
	await _wait(0.4)
	for a: PaperActor in world.actors.values():
		a.bot = false
		a.move_input = Vector3.ZERO
		a.velocity = Vector3.ZERO
	return true


func _actor(character: String) -> PaperActor:
	for a: PaperActor in world.actors.values():
		if a.character == character: return a
	return null


func _capture(label: String) -> void:
	if headless: return
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = out_dir.path_join(label + ".png")
	image.save_png(path)
	print("CROSS_FRAME ", path)


# --- rush_bonus -------------------------------------------------------------------------

func _rush_sample() -> Dictionary:
	var player: AudioStreamPlayer = world.audio.tracks.get("exit")
	return {"time_left": snappedf(float(world.time_left), 0.01), "mode": str(world.audio.mode), "track": str(world.audio.active_track), "playing": player != null and player.playing, "pos": snappedf(player.get_playback_position(), 0.01) if player else -1.0, "db": snappedf(player.volume_db, 0.1) if player else -99.0}


func _watch_rush(plan: String, seconds: float, label: String, step: float = 0.25) -> Array:
	var rows: Array = []
	var t: float = 0.0
	while t < seconds:
		await _wait(step)
		t += step
		var row: Dictionary = _rush_sample()
		row["t"] = t
		rows.append(row)
		print("CROSS_RUSH ", label, " ", JSON.stringify(row))
	return rows


func _plan_rush_bonus() -> void:
	var plan: String = "rush_bonus"
	var before: int = failures.size()
	if not await _round("Simon", false):
		_fail(plan, "manche non lancée")
		return
	var alice: PaperActor = world.killer_actor()
	world.time_left = 81.6
	var waited: float = 0.0
	while not world.exit_flow.opened and waited < 5.0:
		await _wait(0.1)
		waited += 0.1
	if not world.exit_flow.opened:
		_fail(plan, "sortie jamais ouverte")
		_report(plan, before, "")
		return
	await _wait(4.5)
	var start: Dictionary = _rush_sample()
	print("CROSS_RUSH start ", JSON.stringify(start))
	if not bool(start.playing): _fail(plan, "musique de course absente avant le bonus")
	# 1) Bonus juste après le début de la course : le chrono repasse au-dessus de 77 s.
	var victims: Array[PaperActor] = []
	for a: PaperActor in world.actors.values():
		if not a.killer and a.alive and a != world.local_actor(): victims.append(a)
	victims[0].effects["death_source"] = alice.id
	world.eliminate(victims[0])
	var rows: Array = await _watch_rush("bonus_high", 6.0, "after_bonus_1")
	var silent: int = 0
	for row: Dictionary in rows:
		if float(row.t) >= 1.25 and (not bool(row.playing) or float(row.db) < -60.0): silent += 1
		if str(row.mode) != "exit": _fail(plan, "mode audio %s après le bonus" % str(row.mode))
	if silent > 0: _fail(plan, "musique muette %d échantillons sur %d après un bonus qui fait passer le chrono à %.1f s" % [silent, rows.size(), float(rows[0].time_left)])
	# Bouclage des 16 premières mesures (chrono qui traverse 107 s, puis 77 s) : saut direct, sans fondu.
	for crossing: float in [107.0, 77.0]:
		world.time_left = crossing + 1.8
		await _wait(1.0)
		var wrap: Array = await _watch_rush("wrap", 1.6, "wrap_%d" % int(crossing), 0.05)
		var quietest: float = 0.0
		var wrapped: bool = false
		for k in range(wrap.size()):
			quietest = minf(quietest, float(wrap[k].db))
			if not bool(wrap[k].playing): _fail(plan, "musique arrêtée au bouclage (%d s)" % int(crossing))
			if k > 0 and float(wrap[k - 1].pos) - float(wrap[k].pos) > 20.0: wrapped = true
		if not wrapped: _fail(plan, "pas de bouclage observé en traversant %d s" % int(crossing))
		if quietest < -3.0: _fail(plan, "fondu au bouclage (%d s) : %.1f dB" % [int(crossing), quietest])
	# 2) Bonus en pleine course (chrono à 30 s) : la musique recule de 45 s, calée sur la mesure.
	world.time_left = 30.0
	await _wait(2.0)
	var mid: Dictionary = _rush_sample()
	print("CROSS_RUSH mid ", JSON.stringify(mid))
	victims[1].effects["death_source"] = alice.id
	world.eliminate(victims[1])
	var rows2: Array = await _watch_rush("bonus_mid", 4.0, "after_bonus_2")
	var last: Dictionary = rows2.back()
	var expected: float = 77.0 - float(last.time_left)
	if not bool(last.playing): _fail(plan, "musique arrêtée après le second bonus")
	elif absf(float(last.pos) - expected) > 0.6: _fail(plan, "position %.2f au lieu de %.2f après le second bonus" % [float(last.pos), expected])
	if float(last.db) < -40.0: _fail(plan, "volume resté bas après le second bonus (%.1f dB)" % float(last.db))
	_report(plan, before, "start=%s after1=%s last=%s" % [JSON.stringify(start), JSON.stringify(rows.back()), JSON.stringify(last)])


# --- exec_camera ------------------------------------------------------------------------

func _execute(victim: PaperActor, alice: PaperActor) -> Dictionary:
	for attempt in range(8):
		world.combat.damage(victim, 999.0, alice, false, "slash")
		if bool(victim.effects.get("dying", false)): break
	var scene: Dictionary = {}
	for s: Dictionary in world.kill_scenes._scenes.values(): scene = s
	return scene


func _badge_visible() -> bool:
	var badge: Variant = world.camera_rig.get("_badge")
	return badge != null and is_instance_valid(badge) and (badge as Control).visible and (badge as Control).modulate.a > 0.01


func _press_camera_key() -> void:
	for pressed: bool in [true, false]:
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = KEY_C
		key.keycode = KEY_C
		key.pressed = pressed
		Input.parse_input_event(key)
		await get_tree().process_frame
		await get_tree().process_frame


func _plan_exec_camera() -> void:
	var plan: String = "exec_camera"
	var before: int = failures.size()
	if not await _round("Alice", true):
		_fail(plan, "manche non lancée")
		return
	var rig = world.camera_rig
	var alice: PaperActor = world.local_actor()
	var victim: PaperActor = _actor("Usayuko")
	var base: Vector3 = world.school.spawn_points[1] + Vector3(0, 0, -9)
	victim.global_position = base
	victim.reset_physics_interpolation()
	alice.global_position = base + Vector3(0.6, 0, -2.4)
	alice.aim = (base - alice.global_position).normalized()
	alice.reset_physics_interpolation()
	world.yaw = atan2(-alice.aim.x, -alice.aim.z)
	victim.effects["revived"] = true
	victim.hp = 1.0
	await _wait(0.4)
	var scene: Dictionary = _execute(victim, alice)
	if scene.is_empty():
		_fail(plan, "pas d'exécution déclenchée")
		_report(plan, before, "")
		return
	await _wait(0.9)
	var overriding: bool = int(world.kill_scenes._camera_id) >= 0
	if not overriding: _fail(plan, "le plan d'exécution n'a pas pris la caméra")
	await _capture("exec_mid_before_keys")
	var yaw0: float = float(world.yaw)
	var pitch0: float = float(world.pitch)
	var mode0: String = str(rig.mode)
	await _press_camera_key()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.relative = Vector2(320, 140)
	motion.screen_relative = Vector2(320, 140)
	rig.mouse_look(motion)
	rig.test_stick = Vector2(1.0, 0.0)
	await _wait(0.35)
	rig.test_stick = null
	await get_tree().process_frame
	var badge: bool = _badge_visible()
	var yaw_moved: float = absf(angle_difference(yaw0, float(world.yaw)))
	var pitch_moved: float = absf(pitch0 - float(world.pitch))
	await _capture("exec_mid_after_keys")
	var touch: Variant = world.get("mobile_controls")
	if touch is Control and is_instance_valid(touch) and (touch as Control).visible and (touch as Control).modulate.a > 0.35:
		_fail(plan, "commandes tactiles pleinement visibles pendant le plan (alpha %.2f)" % (touch as Control).modulate.a)
	if badge: _fail(plan, "bandeau « CAMÉRA » affiché pendant l'exécution")
	if str(rig.mode) != mode0: _fail(plan, "mode de caméra changé pendant l'exécution (%s -> %s)" % [mode0, str(rig.mode)])
	if yaw_moved > 0.01 or pitch_moved > 0.01: _fail(plan, "la vue a tourné pendant l'exécution (yaw %.3f, pitch %.3f)" % [yaw_moved, pitch_moved])
	# Fin du plan : on attend la fin de la mise en scène (le rendu logiciel ralentit l'horloge de jeu).
	var waited: float = 0.0
	while (int(world.kill_scenes._camera_id) >= 0 or not world.kill_scenes._shows.is_empty()) and waited < 20.0:
		await _wait(0.2)
		waited += 0.2
	await _wait(0.3)
	var still: bool = int(world.kill_scenes._camera_id) >= 0
	var held: bool = rig.has_control()
	if still or held: _fail(plan, "caméra non rendue après l'exécution (plan=%s, contrôle=%s)" % [str(still), str(held)])
	var yaw1: float = float(world.yaw)
	rig.mouse_look(motion)
	if absf(angle_difference(yaw1, float(world.yaw))) < 0.01: _fail(plan, "la souris ne tourne plus la vue après l'exécution")
	_report(plan, before, "override=%s badge=%s mode=%s->%s yaw_moved=%.3f pitch_moved=%.3f released=%s" % [str(overriding), str(badge), mode0, str(rig.mode), yaw_moved, pitch_moved, str(not still and not held)])


# --- exec_victim : la victime locale avait la roue d'émotes ouverte -------------------------

func _plan_exec_victim() -> void:
	var plan: String = "exec_victim"
	var before: int = failures.size()
	if not await _round("Usayuko", false):
		_fail(plan, "manche non lancée")
		return
	var me: PaperActor = world.local_actor()
	var alice: PaperActor = world.killer_actor()
	var base: Vector3 = world.school.spawn_points[1] + Vector3(0, 0, -9)
	me.global_position = base
	me.reset_physics_interpolation()
	alice.global_position = base + Vector3(0.6, 0, -2.4)
	alice.aim = (base - alice.global_position).normalized()
	alice.reset_physics_interpolation()
	me.effects["revived"] = true
	me.hp = 1.0
	await _wait(0.3)
	world.toggle_emotes()
	await get_tree().process_frame
	var opened: bool = world.emote_wheel.visible
	if not opened: _fail(plan, "roue d'émotes non ouverte (préparation)")
	var scene: Dictionary = _execute(me, alice)
	if scene.is_empty():
		_fail(plan, "pas d'exécution de la victime locale")
		_report(plan, before, "")
		return
	await _wait(0.6)
	await _capture("exec_victim_mid")
	if world.emote_wheel.visible: _fail(plan, "roue d'émotes restée ouverte par-dessus l'exécution")
	_report(plan, before, "wheel_opened=%s wheel_after=%s override=%s" % [str(opened), str(world.emote_wheel.visible), str(int(world.kill_scenes._camera_id) >= 0)])
	world.quit_to_menu()
	await _wait(0.3)


# --- exec_alarm : exécution pendant l'alerte de sortie (rendu : images) ----------------------

func _plan_exec_alarm() -> void:
	var plan: String = "exec_alarm"
	var before: int = failures.size()
	if not await _round("Alice", true):
		_fail(plan, "manche non lancée")
		return
	var alice: PaperActor = world.local_actor()
	var victim: PaperActor = _actor("Elly")
	world.time_left = 80.4
	var waited: float = 0.0
	while not world.exit_flow.opened and waited < 5.0:
		await _wait(0.1)
		waited += 0.1
	await _wait(4.5)
	var base: Vector3 = world.school.spawn_points[1] + Vector3(0, 0, -9)
	victim.global_position = base
	victim.reset_physics_interpolation()
	alice.global_position = base + Vector3(0.6, 0, -2.4)
	alice.aim = (base - alice.global_position).normalized()
	alice.reset_physics_interpolation()
	world.yaw = atan2(-alice.aim.x, -alice.aim.z)
	victim.effects["revived"] = true
	victim.hp = 1.0
	await _wait(0.3)
	await _capture("exec_alarm_before")
	var scene: Dictionary = _execute(victim, alice)
	if scene.is_empty():
		_fail(plan, "pas d'exécution pendant l'alerte")
		_report(plan, before, "")
		return
	var level_start: float = float(world.exit_alarm.level())
	for at: float in [1.0, 2.2, 3.4]:
		var show: Dictionary = {}
		for sh: Dictionary in world.kill_scenes._shows.values(): show = sh
		while not show.is_empty() and float(show.t) - float(show.lead) < at and world.kill_scenes._shows.has(int(show.id)): await get_tree().process_frame
		await _capture("exec_alarm_%.1f" % at)
		print("CROSS_NOTE exec_alarm t=%.1f alarm_level=%.2f bars=%.2f" % [at, float(world.exit_alarm.level()), float(world.kill_scenes._bars_amount)])
	_report(plan, before, "alarm_level_at_start=%.2f" % level_start)
	world.quit_to_menu()
	await _wait(0.3)


# --- siren_end ---------------------------------------------------------------------------

func _plan_siren_end() -> void:
	var plan: String = "siren_end"
	var before: int = failures.size()
	if not await _round("Simon", false):
		_fail(plan, "manche non lancée")
		return
	world.time_left = 80.3
	var waited: float = 0.0
	while not world.exit_flow.opened and waited < 5.0:
		await _wait(0.1)
		waited += 0.1
	await _wait(0.4)
	var siren: AudioStreamPlayer = world.exit_alarm.get("_alarm")
	var during: bool = siren.playing
	world._finish("survivors")
	await _wait(0.7)
	var after: bool = siren.playing
	var db: float = siren.volume_db
	if world.phase != "ending": _fail(plan, "la manche ne s'est pas terminée (%s)" % str(world.phase))
	if not during: print("CROSS_NOTE siren_end : sirène déjà finie avant la fin de manche (pilote audio factice ?)")
	if after and db > -40.0: _fail(plan, "la sirène continue pendant le film de fin (%.1f dB)" % db)
	_report(plan, before, "siren_before_end=%s siren_in_film=%s db=%.1f" % [str(during), str(after), db])
	await _wait(0.3)
	world.quit_to_menu()
	await _wait(0.3)


# --- debris_end --------------------------------------------------------------------------

func _visible_debris() -> int:
	var count: int = 0
	var camera: Camera3D = world.camera
	for entry: Dictionary in world.kill_scenes._debris:
		var node: Node3D = entry.node
		if not is_instance_valid(node) or not node.is_visible_in_tree(): continue
		if camera.is_position_in_frustum(node.global_position) and camera.global_position.distance_to(node.global_position) < 40.0: count += 1
	return count


func _plan_debris_end() -> void:
	var plan: String = "debris_end"
	var before: int = failures.size()
	if not await _round("Simon", false):
		_fail(plan, "manche non lancée")
		return
	var alice: PaperActor = world.killer_actor()
	var lysia: PaperActor = _actor("Lysia")
	for a: PaperActor in world.actors.values():
		if not a.killer and a != lysia and a.alive: world.eliminate(a)
	await _wait(0.8)
	var anchor: Vector3 = world.school.cinematic_anchor
	var ahead: Vector3 = world.school.cinematic_exit - anchor
	ahead.y = 0.0
	ahead = ahead.normalized() if ahead.length_squared() > 0.01 else Vector3.BACK
	var side: Vector3 = Vector3.UP.cross(ahead).normalized()
	var spot: Vector3 = anchor + ahead * 1.5
	lysia.global_position = spot
	lysia.velocity = Vector3.ZERO
	lysia.reset_physics_interpolation()
	alice.global_position = spot - ahead * 2.3 + side * 0.4
	alice.aim = (spot - alice.global_position).normalized()
	alice.reset_physics_interpolation()
	lysia.hp = 1.0
	await _wait(0.3)
	var scene: Dictionary = _execute(lysia, alice)
	if scene.is_empty():
		_fail(plan, "pas d'exécution de Lysia sur le plateau du film")
		_report(plan, before, "")
		return
	var waited: float = 0.0
	while world.phase == "playing" and waited < 12.0:
		await _wait(0.1)
		waited += 0.1
	if world.phase != "ending":
		_fail(plan, "la manche ne s'est pas terminée après l'exécution (%s)" % str(world.phase))
		_report(plan, before, "")
		return
	var debris_total: int = world.kill_scenes._debris.size()
	var worst: int = 0
	var samples: Array = []
	for at: float in [0.6, 2.0, 3.6, 5.5, 7.5]:
		while float(world.cinema) < at and world.phase == "ending": await get_tree().process_frame
		await get_tree().process_frame
		var seen: int = _visible_debris()
		worst = maxi(worst, seen)
		samples.append("%.1f:%d" % [at, seen])
		await _capture("debris_end_%.1f" % at)
	if debris_total == 0: print("CROSS_NOTE debris_end : aucun débris créé (vérifier l'explosion de Lysia)")
	if worst > 0: _fail(plan, "%d débris d'exécution visibles dans le film de fin" % worst)
	_report(plan, before, "debris=%d film=%s samples=%s" % [debris_total, str(world.film.kind), ", ".join(samples)])
	world.quit_to_menu()
	await _wait(0.3)
