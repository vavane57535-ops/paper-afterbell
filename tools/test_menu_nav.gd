extends Node

# Navigation clavier / manette des menus, sans rendu (headless) : ouvre chaque
# écran, envoie des touches et note qui a le focus. Les lignes « NAV » du
# journal se comparent d'une version à l'autre.
#   godot --headless -- --tool test_menu_nav

var world: Node
var _clock: float = 0.0

func setup(game_world: Node) -> void :
	world = game_world
	_run.call_deferred()

func _process(delta: float) -> void :
	_clock += delta

func _wait(seconds: float) -> void :
	var start: float = _clock
	while _clock - start < seconds: await get_tree().process_frame

func _focus() -> String:
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus == null: return "<aucun>"
	var label: String = str(focus.get("text")) if "text" in focus else ""
	if label.is_empty() and "person" in focus: label = str(focus.get("person"))
	if label.is_empty() and "map_id" in focus: label = str(focus.get("map_id"))
	return focus.get_class() + ":" + label

func _note(text: String) -> void :
	print("NAV ", text)

func _press(code: Key) -> void :
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)

func _pad(button: JoyButton) -> void :
	for pressed: bool in [true, false]:
		var event: InputEventJoypadButton = InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)

func _keys(label: String, codes: Array, settle: float = 0.15) -> void :
	for code: Variant in codes:
		if code is String:
			_pad({"pad_up": JOY_BUTTON_DPAD_UP, "pad_down": JOY_BUTTON_DPAD_DOWN, "pad_left": JOY_BUTTON_DPAD_LEFT, "pad_right": JOY_BUTTON_DPAD_RIGHT, "pad_a": JOY_BUTTON_A, "pad_b": JOY_BUTTON_B, "rb": JOY_BUTTON_RIGHT_SHOULDER}[code])
		else: _press(code)
		await _wait(settle)
	_note(label + " → " + _focus())

func _run() -> void :
	await _wait(0.5)
	var ui: Node = world.ui
	ui.show_main()
	await _wait(1.2)
	_note("menu ouvert → " + _focus())
	await _keys("menu bas", [KEY_DOWN])
	await _keys("menu bas x2", [KEY_DOWN])
	await _keys("menu haut x3", [KEY_UP, KEY_UP, KEY_UP])
	await _keys("menu manette bas x3", ["pad_down", "pad_down", "pad_down"])
	ui._show_setup("survivor", -1)
	await _wait(1.6)
	_note("préparation ouverte → " + _focus())
	await _keys("préparation droite", [KEY_RIGHT])
	await _keys("préparation droite x2", [KEY_RIGHT])
	await _keys("préparation bas", [KEY_DOWN])
	await _keys("préparation gauche", [KEY_LEFT])
	await _keys("préparation bas x2", [KEY_DOWN, KEY_DOWN])
	await _keys("préparation haut", [KEY_UP])
	ui.show_settings()
	await _wait(1.4)
	_note("réglages ouverts → " + _focus())
	await _keys("réglages bas", [KEY_DOWN])
	await _keys("réglages bas x2", [KEY_DOWN])
	await _keys("réglages RB", ["rb"], 0.5)
	_note("onglet → " + str(ui.settings_tab))
	await _keys("réglages bas après onglet", [KEY_DOWN])
	ui.show_shop()
	await _wait(1.4)
	_note("boutique ouverte → " + _focus())
	await _keys("boutique bas", [KEY_DOWN])
	await _keys("boutique bas x2", [KEY_DOWN])
	ui.show_main()
	await _wait(1.0)
	world.selected = "Simon"
	world.start_solo(false)
	var waited: float = 0.0
	while world.phase != "playing" and waited < 60.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	await _wait(1.0)
	_note("phase → " + str(world.phase))
	_press(KEY_ESCAPE)
	await _wait(0.6)
	_note("pause ouverte (pause_open=%s) → %s" % [world.pause_open, _focus()])
	await _keys("pause bas", [KEY_DOWN])
	await _keys("pause manette bas x3", ["pad_down", "pad_down", "pad_down"])
	await _keys("pause bas (tour)", [KEY_DOWN])
	await _keys("pause haut", [KEY_UP])
	await _keys("pause haut (tour)", [KEY_UP])
	await _keys("pause Entrée (quitter)", [KEY_ENTER], 0.4)
	await _keys("confirmation droite", [KEY_RIGHT])
	await _keys("confirmation B", ["pad_b"], 0.3)
	await _keys("pause B (reprendre)", ["pad_b"], 0.5)
	_note("après B : pause_open=%s" % world.pause_open)
	_press(KEY_ESCAPE)
	await _wait(0.6)
	await _keys("pause bas", [KEY_DOWN])
	await _keys("pause Entrée (réglages)", [KEY_ENTER], 0.8)
	_note("page=%s visible=%s pause_open=%s" % [ui.current_page, ui.page.visible, world.pause_open])
	await _keys("réglages en partie bas", [KEY_DOWN])
	_press(KEY_ESCAPE)
	await _wait(0.9)
	_note("retour pause : page visible=%s pause_open=%s focus=%s" % [ui.page.visible, world.pause_open, _focus()])
	await _keys("pause bas (commandes)", [KEY_DOWN])
	await _keys("pause Entrée (commandes)", [KEY_ENTER], 0.8)
	_note("commandes visibles=%s pause_open=%s" % [world.controls_menu.visible, world.pause_open])
	_press(KEY_ESCAPE)
	await _wait(0.9)
	_note("retour pause depuis commandes : commandes=%s page=%s pause_open=%s focus=%s" % [world.controls_menu.visible, ui.page.visible, world.pause_open, _focus()])
	await _keys("pause haut x2", [KEY_UP, KEY_UP])
	# Échap très vite après « Réglages » (pendant le volet) : la partie doit
	# rester cohérente (pas de réglages ouverts par-dessus une partie qui tourne).
	await _keys("pause bas", [KEY_DOWN])
	_press(KEY_ENTER)
	await _wait(0.05)
	_press(KEY_ESCAPE)
	await _wait(1.0)
	_note("Échap pendant le volet : page=%s visible=%s pause_open=%s mouse=%d" % [ui.current_page, ui.page.visible, world.pause_open, Input.mouse_mode])
	_note("fin")
	get_tree().quit()
