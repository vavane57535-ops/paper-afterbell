extends Node

# Captures EN JEU de situations croisées 0.16 (après fusion), vues par le joueur : vraie caméra de jeu
# (core_camera_rig), vrai HUD, touches injectées comme des évènements clavier (C, G, Tab…).
#   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 --fixed-fps 30 -- \
#     --simulate Simon --duration 300 --tool test_ingame_hud --hud-plan exit --hud-out DOSSIER [--hud-en]
# Plans :
#   exit     : ouverture de la sortie (bandeau), bascule de caméra pendant le bandeau, élimination
#              par Alice (+0:45), puce SORTIE, roue des émotes pendant l'alerte (pages 1 et 3).
#   emote    : émote puis danse synchronisées à trois ; en Libre 360° la caméra fait le tour (visage),
#              puis en Derrière ; enfin danse pendant l'alerte de sortie.
#   kill_v   : exécution du joueur local (dernière vie) puis reprise de la caméra (spectateur).
#   kill_a   : le joueur joue Alice et exécute un élève, puis reprise de la caméra.
#   lms      : LMS de Bleuette : +65 PV, courage (au-delà de 150), annonce, barre de PV.
#   pause    : élimination (+0:45) pendant l'alerte, puis menu pause ouvert aussitôt, puis reprise.
#   lysia    : X-ray de Lysia (repères de prises) et prise avec Ashura (×1,5), puis les deux pendant l'alerte.
# --hud-en : interface en anglais (sans rien enregistrer dans settings.cfg).
# Chaque capture est écrite dans --hud-out (PNG 1280×800) et listée dans le journal (« HUD_SHOT »).

var world: Node
var plan: String = "exit"
var out_dir: String = "user://ingame_hud"
var english: bool = false
var _log: Array[String] = []
var _failures: Array[String] = []

func setup(game_world: Node) -> void :
	world = game_world
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--hud-plan" and i + 1 < args.size(): plan = args[i + 1]
		if args[i] == "--hud-out" and i + 1 < args.size(): out_dir = args[i + 1]
		if args[i] == "--hud-en": english = true
	DirAccess.make_dir_recursive_absolute(out_dir)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _note(text: String) -> void :
	var line: String = "%.2f %s" % [float(world.clock), text]
	_log.append(line)
	print("HUD_TEST ", line)

func _wait(seconds: float) -> void :
	var goal: float = float(world.clock) + seconds
	while float(world.clock) < goal: await get_tree().process_frame

func _frames(count: int) -> void :
	for i in range(count): await get_tree().process_frame

func _shot(label: String) -> void :
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = out_dir.path_join(label + ".png")
	image.save_png(path)
	print("HUD_SHOT ", path)

func _key(code: Key, physical: bool = false) -> void :
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.pressed = pressed
		if physical: event.physical_keycode = code
		else: event.keycode = code
		event.physical_keycode = code
		Input.parse_input_event(event)
		await get_tree().process_frame

func _press_action(action: String) -> void :
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			await _key((event as InputEventKey).physical_keycode if (event as InputEventKey).keycode == KEY_NONE else (event as InputEventKey).keycode)
			return

func _freeze_bots() -> void :
	for a: PaperActor in world.actors.values():
		a.bot = false
		a.move_input = Vector3.ZERO
		a.velocity = Vector3.ZERO
		a.sprint = false

func _place(a: PaperActor, at: Vector3, facing: Vector3 = Vector3.ZERO) -> void :
	a.global_position = at
	a.net_position = at
	a.velocity = Vector3.ZERO
	if facing.length_squared() > 0.001: a.aim = facing.normalized()
	a.reset_physics_interpolation()

func _look(direction: Vector3, pitch: float = -0.16) -> void :
	world.yaw = atan2( - direction.x, - direction.z)
	world.pitch = pitch

func _survivor(name_value: String) -> PaperActor:
	for a: PaperActor in world.actors.values():
		if a.character == name_value and not a.killer: return a
	return null

func _others(local: PaperActor) -> Array[PaperActor]:
	var list: Array[PaperActor] = []
	for a: PaperActor in world.actors.values():
		if a != local and not a.killer and a.alive: list.append(a)
	return list

func _away(a: PaperActor, index: int) -> void :
	var base: Vector3 = world.school.spawn_points[0]
	_place(a, base + Vector3(-40.0 + 4.0 * index, 0.0, -36.0))

func _run() -> void :
	while world.phase != "playing": await get_tree().process_frame
	await _wait(1.2)
	if english:
		# en mémoire seulement : la caméra n'écrit pas les préférences pendant le test
		world.options.language = "en"
		PaperLanguage.language = "en"
		if world.ui.has_method("refresh_language"): world.ui.refresh_language()
	world.camera_rig.persist = false
	world.camera_rig.set_mode("free", false)
	var local: PaperActor = world.local_actor()
	local.bot = false
	_note("plan=%s local=%s map=%s lang=%s" % [plan, local.character, world.selected_map, PaperLanguage.language])
	match plan:
		"exit": await _plan_exit()
		"emote": await _plan_emote()
		"kill_v": await _plan_kill(false)
		"kill_a": await _plan_kill(true)
		"lms": await _plan_lms()
		"lysia": await _plan_lysia()
		"pause": await _plan_pause()
	print("HUD_RESULT ", "OK" if _failures.is_empty() else "FAIL", " ", JSON.stringify({"failures": _failures}))
	get_tree().quit()


func _stage_open_area() -> Vector3:
	# hall d'entrée de l'école, face au couloir : espace dégagé, sortie à quelques dizaines de mètres
	var local: PaperActor = world.local_actor()
	return local.global_position


func _plan_exit() -> void :
	var local: PaperActor = world.local_actor()
	_freeze_bots()
	local.bot = false
	var alice: PaperActor = world.killer_actor()
	if alice: _place(alice, local.global_position + Vector3(60, 0, 60))
	var exit_at: Vector3 = world.school.escape_position
	var toward: Vector3 = exit_at - local.global_position
	toward.y = 0.0
	_look(toward.normalized().rotated(Vector3.UP, 0.5))
	await _wait(0.6)
	await _shot("exit_00_before")
	world.time_left = 80.4
	while not world.exit_flow.opened: await get_tree().process_frame
	_note("exit opened")
	await _wait(0.28)
	await _shot("exit_01_banner_slam")
	await _press_action("camera_mode")
	_note("camera mode -> %s" % world.camera_rig.mode)
	await _wait(0.35)
	await _shot("exit_02_banner_plus_camera_badge")
	await _wait(1.3)
	await _shot("exit_03_banner_red")
	await _wait(1.6)
	# élimination d'un élève par Alice : +0:45 au chrono
	var victim: PaperActor = _others(local)[0]
	victim.effects["death_source"] = alice.id if alice else -1
	world.eliminate(victim)
	_note("eliminated %s, time_left=%.1f" % [victim.character, world.time_left])
	await _wait(0.3)
	await _shot("exit_04_kill_bonus_pop")
	await _wait(1.0)
	await _shot("exit_05_kill_bonus_hold")
	await _wait(2.0)
	await _shot("exit_06_after_banner_compass")
	world.owned_dances = ["dance_sixseven", "dance_pikki", "dance_golden", "floss", "robot"]
	await _press_action("emotes")
	await _wait(0.3)
	await _shot("exit_07_wheel_page1")
	await _key(KEY_TAB)
	await _key(KEY_TAB)
	await _wait(0.2)
	await _shot("exit_08_wheel_dances")
	await _press_action("emotes")
	await _wait(0.4)
	world.time_left = 18.3
	await _wait(1.6)
	await _shot("exit_09_last_call")


func _plan_emote() -> void :
	var local: PaperActor = world.local_actor()
	_freeze_bots()
	local.bot = false
	var alice: PaperActor = world.killer_actor()
	if alice: _place(alice, local.global_position + Vector3(70, 0, 70))
	var others: Array[PaperActor] = _others(local)
	var base: Vector3 = local.global_position
	var forward: Vector3 = Vector3(0, 0, -1)
	var right: Vector3 = Vector3(1, 0, 0)
	# deux élèves à côté du joueur, tous tournés dans la même direction que lui
	for i in range(others.size()):
		if i < 2: _place(others[i], base + right * (1.5 if i == 0 else -1.5) + forward * 0.4, forward)
		else: _away(others[i], i)
	local.aim = forward
	_look(forward)
	await _wait(1.0)
	world.request_emote("heart")
	await _wait(0.5)
	for i in range(2): world._start_emote(others[i], "heart")
	await _wait(0.3)
	await _shot("emote_00_free_back")
	# Libre 360° : on tourne autour du personnage pendant l'émote pour voir son visage
	for step in range(10):
		world.yaw = wrapf(float(world.yaw) + PI / 10.0, -PI, PI)
		await get_tree().process_frame
	await _wait(0.2)
	await _shot("emote_01_free_face")
	_note("free: actor yaw=%.2f cam yaw=%.2f emote=%s t=%.2f" % [local.visual.rotation.y, world.yaw, str(local.effects.get("emote_id", "")), float(local.effects.get("emote_time", -1))])
	await _wait(1.6)
	world.owned_dances = ["dance_sixseven", "dance_pikki", "dance_golden"]
	world.request_emote("dance_golden")
	await _wait(0.6)
	for i in range(2): world._start_emote(others[i], "dance_golden")
	await _wait(1.0)
	await _shot("emote_02_dance_free_front")
	var times: Array = []
	for a: PaperActor in [local, others[0], others[1]]: times.append("%s=%.3f" % [a.character, float(a.effects.get("emote_time", -1))])
	_note("dance sync " + " ".join(times))
	# Derrière pendant la danse : le perso garde son orientation (on doit pouvoir tourner autour)
	await _press_action("camera_mode")
	_note("camera mode -> %s" % world.camera_rig.mode)
	await _wait(0.9)
	await _shot("emote_03_dance_behind")
	for step in range(10):
		world.yaw = wrapf(float(world.yaw) + PI / 12.0, -PI, PI)
		await get_tree().process_frame
	await _wait(0.3)
	await _shot("emote_04_dance_behind_orbit")
	_note("behind: actor yaw=%.2f cam yaw=%.2f emote=%s" % [local.visual.rotation.y, world.yaw, str(local.effects.get("emote_id", ""))])
	# alerte de sortie pendant la danse
	world.time_left = 80.3
	await _wait(1.3)
	await _shot("emote_05_dance_exit_alert")
	await _wait(3.5)
	await _shot("emote_06_dance_exit_after")
	# on arrête la danse en marchant : transition vers la locomotion
	Input.action_press("forward")
	await _wait(0.25)
	await _shot("emote_07_walk_out_of_dance")
	await _wait(0.5)
	Input.action_press("sprint")
	await _wait(0.6)
	await _shot("emote_08_sprint")
	Input.action_release("sprint")
	Input.action_release("forward")
	await _wait(0.8)
	await _shot("emote_09_stop")


func _plan_kill(as_alice: bool) -> void :
	var local: PaperActor = world.local_actor()
	_freeze_bots()
	local.bot = false
	var alice: PaperActor = world.killer_actor()
	var victim: PaperActor = null
	var base: Vector3 = local.global_position
	if as_alice:
		for a: PaperActor in _others(local):
			if victim == null: victim = a
			else: _away(a, a.id)
		_place(victim, base + Vector3(0, 0, -2.4), Vector3(0, 0, 1))
		local.aim = Vector3(0, 0, -1)
		_look(Vector3(0, 0, -1))
	else:
		victim = local
		var index: int = 0
		for a: PaperActor in _others(local):
			if index == 0: _place(a, base + Vector3(5.0, 0, 3.0), Vector3(-1, 0, 0))
			else: _away(a, index)
			index += 1
		_place(alice, base + Vector3(0.4, 0, -2.4), Vector3(0, 0, 1))
		_look(Vector3(0, 0, -1).rotated(Vector3.UP, 0.4))
	if victim.character != "Lysia": victim.effects["revived"] = true
	victim.hp = 1.0
	await _wait(0.8)
	await _shot("kill_00_before")
	var before: float = float(world.time_left)
	for attempt in range(8):
		world.combat.damage(victim, 999.0, alice, false, "slash")
		if bool(victim.effects.get("dying", false)): break
	_note("execution started=%s variant=%s" % [str(not world.kill_scenes._scenes.is_empty()), str(world.kill_scenes._scenes.values()[0].variant) if not world.kill_scenes._scenes.is_empty() else "-"])
	await _wait(0.5)
	# touche caméra pendant le plan cinématique : doit être ignorée (pas de bandeau sur le film)
	await _press_action("camera_mode")
	_note("camera mode during execution -> %s" % world.camera_rig.mode)
	await _wait(0.3)
	await _shot("kill_01_cine_after_C")
	await _wait(1.4)
	await _shot("kill_02_cine_mid")
	while not world.kill_scenes._shows.is_empty() or not world.kill_scenes._scenes.is_empty():
		await get_tree().process_frame
		if float(world.clock) > before + 30.0: break
	_note("execution over; victim alive=%s time_left %.1f -> %.1f" % [str(victim.alive), before, world.time_left])
	await _wait(0.12)
	await _shot("kill_03_return_0s1")
	await _wait(0.5)
	await _shot("kill_04_return_0s6")
	await _wait(1.2)
	await _shot("kill_05_return_1s8")
	_note("hud alpha=%.2f bars=%s mode=%s" % [world.ui.hud.modulate.a, str(world.kill_scenes._bars[0].visible), world.camera_rig.mode])
	if world.ui.hud.modulate.a < 0.99: _failures.append("HUD resté estompé après l'exécution")
	if as_alice:
		# Alice reprend la main : elle avance
		Input.action_press("forward")
		await _wait(0.8)
		await _shot("kill_06_alice_moves")
		Input.action_release("forward")


func _plan_lms() -> void :
	var local: PaperActor = world.local_actor()
	_freeze_bots()
	local.bot = false
	var alice: PaperActor = world.killer_actor()
	if alice: _place(alice, local.global_position + Vector3(60, 0, 60))
	for a: PaperActor in _others(local):
		a.effects["death_source"] = -1
		world.eliminate(a)
	while not world.lms: await get_tree().process_frame
	await _wait(0.5)
	await _shot("lms_00_announce")
	_note("lms: hp=%.0f/%.0f" % [local.hp, local.max_hp])
	await _wait(3.8)
	await _shot("lms_01_hud")
	# courage de Bleuette (case 4) si disponible
	if local.character == "Bleuette":
		local.effects["aura_charge"] = 100.0
		world.request_ability(3)
		await _wait(0.2)
		world.release_ability(3)
		await _wait(1.5)
		_note("courage: hp=%.0f/%.0f" % [local.hp, local.max_hp])
		local.hp = local.max_hp
		await _wait(0.6)
		await _shot("lms_02_courage_overcap")
		world.time_left = 80.3
		await _wait(1.2)
		await _shot("lms_03_exit_in_lms")



func _plan_lysia() -> void :
	var lysia: PaperActor = world.local_actor()
	_freeze_bots()
	var alice: PaperActor = world.killer_actor()
	var ashura: PaperActor = _survivor("Ashura")
	for a: PaperActor in _others(lysia):
		if a != ashura: _away(a, a.id)
	if alice: _place(alice, world.school.killer_spawn)
	for round_index in range(2):
		var tag: String = "alert_" if round_index == 1 else ""
		if round_index == 1:
			world.time_left = 80.3
			await _wait(4.6)
		# X-ray : repères des prises à travers les murs
		var base: Vector3 = world.school.spawn_points[0]
		_place(lysia, base)
		var hidden_target: Vector3 = world.school.healing_outlets[0]
		var best: float = INF
		for point: Vector3 in world.school.healing_outlets:
			if not world.visible(base, point + Vector3(0, 0, -0.8)) and base.distance_to(point) < best:
				best = base.distance_to(point)
				hidden_target = point
		_look((hidden_target - base).normalized(), -0.12)
		world.camera_anchor_ready = false
		await _wait(0.5)
		lysia.cooldowns[2] = 0.0
		world.combat.use(lysia, 2)
		await _wait(0.7)
		await _shot("lysia_%s00_xray" % tag)
		await _wait(3.5)
		# prise avec Ashura tout près : soin ×1,5, arc et étiquette
		var outlet: Vector3 = world.school.healing_outlets[0]
		_place(lysia, outlet + Vector3(0, 0.08, 0))
		_place(ashura, outlet + Vector3(1.9, 0.08, 0.7), Vector3(-1, 0, -0.35))
		lysia.hp = 100.0
		lysia.cooldowns[3] = 0.0
		lysia.aim = Vector3(0, 0, -1)
		_look(Vector3(0.35, 0, -1).normalized(), -0.22)
		world.camera_anchor_ready = false
		await _wait(0.4)
		var plugged: bool = world.combat.start_outlet_heal(lysia)
		_note("%splugged=%s partner=%d" % [tag, str(plugged), int(lysia.effects.get("outlet_ashura", -1))])
		await _wait(1.2)
		await _shot("lysia_%s01_outlet_ashura" % tag)
		world.yaw = wrapf(float(world.yaw) + 2.2, -PI, PI)
		await _wait(0.5)
		await _shot("lysia_%s02_outlet_ashura_side" % tag)
		world.combat._stop_outlet(lysia, "cancelled")
		await _wait(0.4)


func _plan_pause() -> void :
	var local: PaperActor = world.local_actor()
	_freeze_bots()
	local.bot = false
	var alice: PaperActor = world.killer_actor()
	if alice: _place(alice, local.global_position + Vector3(60, 0, 60))
	world.time_left = 80.4
	while not world.exit_flow.opened: await get_tree().process_frame
	await _wait(1.0)
	var victim: PaperActor = _others(local)[0]
	victim.effects["death_source"] = alice.id if alice else -1
	world.eliminate(victim)
	await _wait(0.3)
	await _press_action("pause_game")
	_note("pause_open=%s bonus_visible=%s" % [str(world.pause_open), str(world.kill_scenes._bonus_label.visible)])
	await _frames(20)
	await _shot("pause_00_menu_after_kill")
	if bool(world.kill_scenes._bonus_label.visible): _failures.append("+0:45 visible par-dessus le menu pause")
	await _press_action("pause_game")
	await _wait(0.5)
	_note("pause_open=%s bonus_visible=%s" % [str(world.pause_open), str(world.kill_scenes._bonus_label.visible)])
	await _shot("pause_01_resumed")
