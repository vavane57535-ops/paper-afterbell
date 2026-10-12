extends Node

# Menu pause par-dessus les états spéciaux d'une manche 0.16 : exécution en cours (bandes noires du
# plan), « +0:45 » au chrono après une élimination par Alice, alerte de sortie (filtre rouge).
# Rien de la partie ne doit rester dessiné au-dessus du menu, et tout doit revenir à la reprise.
#   XDG_DATA_HOME=<dossier de test> xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 \
#       -- --tool test_pause_states --ps-out DIR [--ps-plans exec,bonus,alarm]
#   Sans rendu (vérifications seules) : godot --headless -- --tool test_pause_states
# Lignes « PAUSE_STATE OK|FAIL … », « PAUSE_FRAME <image> », puis « PAUSE_STATES OK|FAIL n ».

var world: Node
var out_dir: String = "user://pause_states"
var plans: PackedStringArray = PackedStringArray(["exec", "bonus", "alarm"])
var _fails: int = 0

func setup(game_world: Node) -> void :
	world = game_world
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		if args[i] == "--ps-out" and i + 1 < args.size(): out_dir = args[i + 1]
		if args[i] == "--ps-plans" and i + 1 < args.size(): plans = args[i + 1].split(",")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _check(ok: bool, what: String) -> void :
	print("PAUSE_STATE ", "OK   " if ok else "FAIL ", what)
	if not ok: _fails += 1

func _wait(seconds: float) -> void :
	await get_tree().create_timer(seconds, true, false, true).timeout

func _shot(tag: String) -> void :
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var path: String = out_dir.path_join(tag + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("PAUSE_FRAME ", path)

func _escape() -> void :
	for pressed: bool in [true, false]:
		var key: InputEventKey = InputEventKey.new()
		key.keycode = KEY_ESCAPE
		key.physical_keycode = KEY_ESCAPE
		key.pressed = pressed
		Input.parse_input_event(key)
		await get_tree().process_frame
		await get_tree().process_frame

func _round(local_name: String, as_killer: bool) -> bool:
	world.selected = local_name
	world.start_solo(as_killer)
	var waited: float = 0.0
	while world.phase != "playing" and waited < 30.0:
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

# Éléments de la mise en scène des exécutions (couche au-dessus de l'interface) encore visibles.
func _above_menu() -> PackedStringArray:
	var shown: PackedStringArray = PackedStringArray()
	var scenes: Node = world.kill_scenes
	for bar: ColorRect in scenes._bars:
		if bar.visible and bar.size.y > 0.5:
			shown.append("bandes")
			break
	if (scenes._bonus_label as Control).visible: shown.append("+0:45")
	return shown

func _run() -> void :
	await get_tree().process_frame
	for plan: String in plans:
		match plan:
			"exec": await _plan_exec()
			"bonus": await _plan_bonus()
			"alarm": await _plan_alarm()
		world.quit_to_menu()
		await _wait(0.6)
	print("PAUSE_STATES %s %d" % ["OK" if _fails == 0 else "FAIL", _fails])
	get_tree().quit()

# Alice exécute Usayuko (dernière vie) ; Échap au milieu du plan.
func _plan_exec() -> void :
	if not await _round("Alice", true):
		_check(false, "exec : manche non lancée")
		return
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
	for attempt: int in range(8):
		world.combat.damage(victim, 999.0, alice, false, "slash")
		if bool(victim.effects.get("dying", false)): break
	await _wait(0.9)
	_check(int(world.kill_scenes._camera_id) >= 0, "exec : le plan d'exécution a la caméra")
	await _shot("exec_avant_pause")
	await _escape()
	await _wait(0.1)
	await _shot("exec_pause_ouverture")
	await _wait(0.7)
	_check(bool(world.pause_open), "exec : Échap ouvre la pause pendant le plan")
	var above: PackedStringArray = _above_menu()
	_check(above.is_empty(), "exec : rien du plan au-dessus du menu pause (%s)" % ", ".join(above))
	await _shot("exec_pause")
	await _escape()
	await _wait(0.8)
	_check(not bool(world.pause_open), "exec : Échap reprend")
	_check(int(world.kill_scenes._camera_id) < 0 or (world.kill_scenes._bars[0] as ColorRect).visible, "exec : les bandes reviennent à la reprise si le plan continue")
	await _shot("exec_reprise")

# Élimination définitive par Alice : « +0:45 » s'affiche près du chrono ; Échap aussitôt.
func _plan_bonus() -> void :
	if not await _round("Simon", false):
		_check(false, "bonus : manche non lancée")
		return
	var alice: PaperActor = world.killer_actor()
	var victim: PaperActor = _actor("Elly")
	victim.effects["death_source"] = alice.id
	world.eliminate(victim)
	var waited: float = 0.0
	while not (world.kill_scenes._bonus_label as Control).visible and waited < 3.0:
		await _wait(0.05)
		waited += 0.05
	_check((world.kill_scenes._bonus_label as Control).visible, "bonus : « +0:45 » affiché")
	await _shot("bonus_avant_pause")
	await _escape()
	await _wait(0.6)
	var above: PackedStringArray = _above_menu()
	_check(bool(world.pause_open) and above.is_empty(), "bonus : rien au-dessus du menu pause (%s)" % ", ".join(above))
	await _shot("bonus_pause")
	await _escape()
	await _wait(0.3)
	_check((world.kill_scenes._bonus_label as Control).visible, "bonus : « +0:45 » revient à la reprise")
	# Il finit sa course (2,6 s de jeu ; le rendu logiciel ralentit l'horloge de jeu).
	var gone: float = 0.0
	while (world.kill_scenes._bonus_label as Control).visible and gone < 12.0:
		await _wait(0.2)
		gone += 0.2
	_check(not (world.kill_scenes._bonus_label as Control).visible, "bonus : « +0:45 » finit par disparaître après la reprise")

# Sortie ouverte : alerte (filtre rouge, sirène) ; Échap pendant l'alerte.
func _plan_alarm() -> void :
	if not await _round("Simon", false):
		_check(false, "alarm : manche non lancée")
		return
	world.time_left = 81.6
	var waited: float = 0.0
	while not world.exit_flow.opened and waited < 6.0:
		await _wait(0.1)
		waited += 0.1
	_check(bool(world.exit_flow.opened), "alarm : sortie ouverte")
	await _wait(1.2)
	await _shot("alerte_avant_pause")
	await _escape()
	await _wait(0.8)
	_check(bool(world.pause_open), "alarm : Échap ouvre la pause pendant l'alerte")
	await _shot("alerte_pause")
	await _escape()
	await _wait(0.6)
	await _shot("alerte_reprise")
