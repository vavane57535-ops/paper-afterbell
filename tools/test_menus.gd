extends Node

# Captures de tous les menus et d'images en cours de transition.
# Usage :
#   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 -- --tool test_menus \
#       --menu-out /tmp/menus --menus main,nav,settings,setup,shop,gallery,credits,network,lobby,pause,ending
# Options : --menu-times 0,80,160,300,600 (ms) ; --menu-slow 0.12 (ralenti pendant les rafales) ;
#           --menu-reduced (active « Réduire les flashs ») ; --menu-en (interface en anglais).
# Les instants sont mesurés sur l'horloge du jeu (delta ralenti), pas sur l'horloge murale :
# llvmpipe peut être lent sans fausser les instants capturés.

var world: Node
var out_dir: String = "user://menu_caps"
var menus: PackedStringArray = PackedStringArray(["main", "nav", "settings", "setup", "shop", "gallery", "credits", "network", "pause", "ending"])
var times: Array[float] = [0.0, 80.0, 160.0, 300.0, 600.0]
var slow: float = 0.12
var _clock: float = 0.0
var _log: PackedStringArray = PackedStringArray()

func setup(game_world: Node) -> void :
	world = game_world
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		if args[i] == "--menu-out" and i + 1 < args.size(): out_dir = args[i + 1]
		if args[i] == "--menus" and i + 1 < args.size(): menus = args[i + 1].split(",")
		if args[i] == "--menu-slow" and i + 1 < args.size(): slow = clampf(float(args[i + 1]), 0.01, 1.0)
		if args[i] == "--menu-times" and i + 1 < args.size():
			times.clear()
			for part: String in args[i + 1].split(","): times.append(float(part))
		if args[i] == "--menu-reduced": world.options["reduce_flashes"] = true
		if args[i] == "--menu-size" and i + 1 < args.size():
			var parts: PackedStringArray = args[i + 1].split("x")
			if parts.size() == 2: get_window().size = Vector2i(int(parts[0]), int(parts[1]))
		if args[i] == "--menu-en": world.options["language"] = "en"
	DirAccess.make_dir_recursive_absolute(out_dir)
	world.apply_options()
	world.ui.reduced_motion = bool(world.options.get("reduce_flashes", false))
	_run.call_deferred()

func _process(delta: float) -> void :
	_clock += delta

func _note(text: String) -> void :
	print("[test_menus] ", text)
	_log.append(text)

func _wait_game(seconds: float) -> void :
	var start: float = _clock
	while _clock - start < seconds: await get_tree().process_frame

func _wait_frames(count: int) -> void :
	for i: int in range(count): await get_tree().process_frame

func _save(tag: String) -> void :
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = out_dir.path_join(tag + ".png")
	image.save_png(path)
	_note("capture " + path)

# Lance une action puis capture aux instants voulus (ms, horloge du jeu ralentie).
func _burst(tag: String, action: Callable, at: Array = []) -> void :
	var marks: Array = at if not at.is_empty() else times
	Engine.time_scale = slow
	await get_tree().process_frame
	var start: float = _clock
	action.call()
	for mark: Variant in marks:
		var goal: float = float(mark) / 1000.0
		while _clock - start < goal: await get_tree().process_frame
		await _save("%s_%04d" % [tag, int(mark)])
	Engine.time_scale = 1.0

const KEYS: Dictionary = {&"ui_down": KEY_DOWN, &"ui_up": KEY_UP, &"ui_left": KEY_LEFT, &"ui_right": KEY_RIGHT, &"ui_accept": KEY_ENTER, &"ui_cancel": KEY_ESCAPE, &"pause_game": KEY_ESCAPE}

# Vraie touche clavier (passe par la logique de focus de ui.gd).
func _key(action: StringName) -> void :
	var code: Key = KEYS.get(action, KEY_NONE)
	if code == KEY_NONE:
		var press: InputEventAction = InputEventAction.new()
		press.action = action
		press.pressed = true
		Input.parse_input_event(press)
		return
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)

func _raw_key(code: Key) -> void :
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)

func _joy(button: JoyButton) -> void :
	for pressed: bool in [true, false]:
		var event: InputEventJoypadButton = InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)

func _mouse_to(point: Vector2) -> void :
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	get_viewport().warp_mouse(point)
	Input.parse_input_event(motion)

func _click(point: Vector2) -> void :
	_mouse_to(point)
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		Input.parse_input_event(event)

func _focus_name() -> String:
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus == null: return "<aucun>"
	var text: String = str(focus.get("text")) if "text" in focus else ""
	return focus.get_class() + ":" + text

func _hovered_center(control: Control) -> Vector2:
	var rect: Rect2 = control.get_global_rect()
	return get_viewport().get_screen_transform() * rect.get_center()

func _find_text(node: Node, text: String) -> Control:
	for child: Node in node.get_children():
		var control: Control = child as Control
		if control and control.is_visible_in_tree() and "text" in control and str(control.get("text")).strip_edges() == text: return control
		var found: Control = _find_text(child, text)
		if found: return found
	return null

func _run() -> void :
	await _wait_frames(4)
	var ui: Node = world.ui
	_note("viewport " + str(get_viewport().get_visible_rect().size))
	if "main" in menus:
		# Comme au lancement du jeu : page vide puis menu principal.
		await _burst("main_open", func() -> void :
			ui._clear(ui.page)
			ui.show_main(), [0, 80, 160, 300, 500, 900, 1600])
	if "nav" in menus:
		await _wait_game(0.4)
		await _burst("main_down", func() -> void : _key(&"ui_down"), [0, 60, 120, 240])
		_note("focus après bas : " + _focus_name())
		await _burst("main_down2", func() -> void : _key(&"ui_down"), [0, 60, 120, 240, 600])
		_note("focus après bas x2 : " + _focus_name())
		var target: Control = _find_text(ui.page, "RÉGLAGES")
		if target:
			await _burst("main_hover", func() -> void : _mouse_to(_hovered_center(target)), [0, 80, 200, 500])
		_mouse_to(Vector2(4, 4))
	if "settings" in menus:
		await _burst("settings_open", func() -> void : ui.show_settings(), [0, 80, 160, 300, 500, 900])
		_key(&"ui_down")
		await _wait_game(0.2)
		_note("focus réglages : " + _focus_name())
		_key(&"ui_down")
		await _wait_game(0.1)
		await _burst("settings_row", func() -> void : _key(&"ui_down"), [0, 60, 140, 300])
		_note("focus ligne : " + _focus_name())
		await _burst("settings_tab", func() -> void : ui._settings_switch("audio"), [0, 80, 200, 500])
		await _burst("settings_pagedown", func() -> void : _raw_key(KEY_PAGEDOWN), [0, 120, 400])
		_note("onglet après Page suiv. : " + str(ui.settings_tab))
		await _burst("settings_controls", func() -> void : ui._settings_switch("controls"), [0, 300])
		await _burst("settings_access", func() -> void : ui._settings_switch("access"), [0, 300])
		ui.settings_tab = "game"
		await _burst("settings_back", func() -> void : ui._settings_back(), [0, 80, 160, 300, 600])
	if "setup" in menus:
		await _burst("setup_open", func() -> void : ui._show_setup("survivor", -1), [0, 80, 160, 300, 600, 1000])
		_key(&"ui_right")
		await _wait_game(0.3)
		_note("focus perso : " + _focus_name())
		await _save("setup_nav")
		await _burst("setup_alice", func() -> void : ui._set_role("alice"), [0, 160, 600])
		await _burst("setup_back", func() -> void : ui.show_main(), [0, 160, 600])
	if "shop" in menus:
		await _burst("shop_open", func() -> void : ui.show_shop(), [0, 80, 160, 300, 600, 1200])
		_key(&"ui_down")
		await _wait_game(0.3)
		await _save("shop_nav")
		await _burst("shop_back", func() -> void : ui.show_main(), [0, 300])
	if "credits" in menus:
		await _burst("credits_open", func() -> void : ui.show_credits(), [0, 160, 600])
		await _burst("credits_back", func() -> void : ui.show_main(), [0, 300])
	if "network" in menus:
		await _burst("network_open", func() -> void : ui.show_network(), [0, 160, 600])
		await _burst("advanced_open", func() -> void : ui.show_network_advanced(), [0, 600])
		await _burst("network_back", func() -> void : ui.show_main(), [0, 300])
	if "controls" in menus:
		await _burst("controls_open", func() -> void : world.controls_menu.open(), [0, 160, 600])
		world.controls_menu.close()
		await _wait_game(0.3)
	if "online" in menus:
		await _burst("online_open", func() -> void : world.online_menu.open(), [0, 160, 600])
		world.online_menu.close()
		await _wait_game(0.3)
	if "gallery" in menus:
		await _burst("gallery_open", func() -> void : world.gallery.open(), [0, 160, 300, 600, 1200])
		_key(&"ui_down")
		await _wait_game(0.3)
		await _save("gallery_nav")
		world.gallery.close()
		await _wait_game(0.5)
	if "lobby" in menus:
		world.host_lan_room()
		await _wait_game(0.2)
		await _burst("lobby_open", func() -> void : ui.show_lobby(), [0, 160, 600, 1200])
		world.quit_to_menu()
		await _wait_game(0.5)
	if "pause" in menus or "ending" in menus:
		world.selected = "Simon"
		world.start_solo(false)
		var waited: float = 0.0
		while world.phase != "playing" and waited < 60.0:
			await get_tree().process_frame
			waited += get_process_delta_time()
		_note("phase partie : " + str(world.phase))
		await _wait_game(1.5)
		if "pause" in menus:
			await _burst("pause_open", func() -> void : _press_pause(), [0, 40, 80, 120, 160, 220, 300, 450, 700])
			await _burst("pause_down", func() -> void : _key(&"ui_down"), [0, 60, 120, 240])
			_note("focus pause : " + _focus_name())
			_key(&"ui_down")
			_key(&"ui_down")
			await _wait_game(0.3)
			_note("focus pause x3 : " + _focus_name())
			await _burst("pause_confirm", func() -> void : _key(&"ui_accept"), [0, 60, 120, 240, 400])
			_note("focus confirmation : " + _focus_name())
			await _burst("pause_confirm_close", func() -> void : _key(&"ui_cancel"), [0, 120])
			_note("focus après annulation : " + _focus_name())
			# Manette : croix directionnelle (ui_up) deux fois.
			_joy(JOY_BUTTON_DPAD_UP)
			await _wait_game(0.1)
			_joy(JOY_BUTTON_DPAD_UP)
			await _wait_game(0.3)
			_note("focus avant réglages (manette) : " + _focus_name())
			await _burst("pause_settings", func() -> void : _activate_focus(), [0, 80, 160, 300, 600])
			await _burst("pause_settings_back", func() -> void : ui._settings_back(), [0, 80, 160, 300, 600])
			await _wait_game(0.6)
			var command: Control = _find_text(ui.overlay, "COMMANDES")
			if command:
				await _burst("pause_hover", func() -> void : _mouse_to(_hovered_center(command)), [0, 80, 240])
				_mouse_to(Vector2(6, 6))
				await _wait_game(0.2)
				await _save("pause_hover_left")
			await _burst("pause_close", func() -> void : _press_pause(), [0, 60, 120, 200, 320])
		if "ending" in menus:
			world.match_results = _fake_results()
			await _burst("ending_open", func() -> void : ui.show_ending("survivors", true), [0, 80, 160, 300, 600, 1000, 1600])
			_key(&"ui_down")
			await _wait_game(0.3)
			await _save("ending_nav")
			world.match_results = _fake_results()
			await _burst("ending_killer", func() -> void : ui.show_ending("killer", false), [0, 300, 1200])
	var file: FileAccess = FileAccess.open(out_dir.path_join("log.txt"), FileAccess.WRITE)
	if file: file.store_string("\n".join(_log))
	_note("fin")
	get_tree().quit()

func _press_pause() -> void :
	_key(&"pause_game")

func _activate_focus() -> void :
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is BaseButton: (focus as BaseButton).pressed.emit()

func _fake_results() -> Array:
	var rows: Array = []
	var grades: Array = ["A", "B", "B", "C", "C", "D"]
	var points: Array = [412, 355, 280, 211, 160, 90]
	var people: Array = ["Simon", "Lysia", "Ashura", "Elly", "Bleuette", "Usayuko"]
	for i: int in range(people.size()):
		rows.append({"id": i + 2, "character": people[i], "name": people[i] + " · " + ("Toi" if i == 0 else "Bot"), "points": points[i], "grade": grades[i], "aura": 40 + i * 9, "breakdown": {"heal": 30 + i * 4, "stun": 2 + i, "danger": 12}})
	return rows
