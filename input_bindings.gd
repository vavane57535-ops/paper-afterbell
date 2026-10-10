class_name PaperBindings
extends RefCounted

const LABELS: Dictionary = {"forward": "Avancer", "back": "Reculer", "left": "Gauche", "right": "Droite", "sprint": "Courir (maintenir)", "run_toggle": "Course (basculer)", "jump": "Sauter", "interact": "Interagir / attraper", "ability_0": "Capacité 1 / confirmer", "ability_1": "Capacité 2 (maintenir : charge)", "ability_2": "Capacité 3 / changer de mode", "ability_3": "Capacité 4", "ability_4": "Capacité 5", "ability_5": "True Form", "cancel_aim": "Annuler la visée", "emotes": "Roue d’émotes", "pause_game": "Pause", "spectate": "Changer de spectateur", "training_menu": "Terrain d’essai", "qte_0": "Archive : réponse gauche", "qte_1": "Archive : réponse centrale", "qte_2": "Archive : réponse droite", "camera_mode": "Caméra : derrière / libre 360°"}
var active_device: int = -1
var controller_sprint: bool = false
var look_sensitivity: float = 2.6
var deadzone: float = 0.18
var vibration: bool = true
var _defaults: Dictionary = {}

func setup() -> void :
	var keys: Dictionary = {"forward": [KEY_W, KEY_Z, KEY_UP], "back": [KEY_S, KEY_DOWN], "left": [KEY_A, KEY_Q, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "sprint": [KEY_SHIFT], "run_toggle": [KEY_CAPSLOCK], "jump": [KEY_SPACE], "interact": [KEY_E], "cancel_aim": [KEY_R], "emotes": [KEY_G], "pause_game": [KEY_ESCAPE], "spectate": [KEY_TAB], "training_menu": [KEY_F2], "qte_0": [KEY_J], "qte_1": [KEY_K], "qte_2": [KEY_L]}
	for slot: int in range(6): keys["ability_" + str(slot)] = [KEY_1 + slot]
	keys["camera_mode"] = [KEY_C]
	for action: String in LABELS:
		if not InputMap.has_action(action): InputMap.add_action(action, deadzone)
		InputMap.action_erase_events(action)
		for code: int in keys.get(action, []):
			var event: InputEventKey = InputEventKey.new();event.physical_keycode = code;InputMap.action_add_event(action, event)
	for spec: Array in [["forward", JOY_AXIS_LEFT_Y, -1.0], ["back", JOY_AXIS_LEFT_Y, 1.0], ["left", JOY_AXIS_LEFT_X, -1.0], ["right", JOY_AXIS_LEFT_X, 1.0], ["ability_0", JOY_AXIS_TRIGGER_RIGHT, 1.0], ["ability_1", JOY_AXIS_TRIGGER_LEFT, 1.0]]:
		var event: InputEventJoypadMotion = InputEventJoypadMotion.new();event.axis = spec[1];event.axis_value = spec[2];event.device = -1;InputMap.action_add_event(spec[0], event)
	for spec: Array in [["jump", JOY_BUTTON_A], ["interact", JOY_BUTTON_X], ["cancel_aim", JOY_BUTTON_B], ["run_toggle", JOY_BUTTON_LEFT_STICK], ["ability_2", JOY_BUTTON_LEFT_SHOULDER], ["ability_3", JOY_BUTTON_RIGHT_SHOULDER], ["ability_4", JOY_BUTTON_DPAD_UP], ["ability_5", JOY_BUTTON_DPAD_DOWN], ["emotes", JOY_BUTTON_DPAD_LEFT], ["pause_game", JOY_BUTTON_START], ["spectate", JOY_BUTTON_BACK], ["qte_0", JOY_BUTTON_X], ["qte_1", JOY_BUTTON_Y], ["qte_2", JOY_BUTTON_B]]:
		var event: InputEventJoypadButton = InputEventJoypadButton.new();event.button_index = spec[1];event.device = -1;InputMap.action_add_event(spec[0], event)
	for spec: Array in [["ability_0", MOUSE_BUTTON_LEFT], ["cancel_aim", MOUSE_BUTTON_RIGHT]]:
		var event: InputEventMouseButton = InputEventMouseButton.new();event.button_index = spec[1];InputMap.action_add_event(spec[0], event)
	var view_button: InputEventJoypadButton = InputEventJoypadButton.new();view_button.button_index = JOY_BUTTON_RIGHT_STICK;view_button.device = -1;InputMap.action_add_event("camera_mode", view_button)
	for action: String in LABELS: _defaults[action] = InputMap.action_get_events(action).duplicate()
	var settings: ConfigFile = ConfigFile.new()
	if settings.load("user://controls.cfg") == OK:
		look_sensitivity = clampf(float(settings.get_value("pad", "sensitivity", 2.6)), 0.5, 6)
		deadzone = clampf(float(settings.get_value("pad", "deadzone", 0.18)), 0.05, 0.45)
		vibration = bool(settings.get_value("pad", "vibration", true))
		for action: String in LABELS:
			var saved: Variant = settings.get_value("bindings", action, null)
			if saved is Array and not saved.is_empty():
				InputMap.action_erase_events(action)
				for event: Variant in saved:
					if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion or event is InputEventMouseButton: InputMap.action_add_event(action, event)
	for action: String in LABELS: InputMap.action_set_deadzone(action, deadzone)
	var connected: Array = Input.get_connected_joypads()
	if not connected.is_empty(): active_device = int(connected[0])

func observe(event: InputEvent) -> void :
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.3): active_device = event.device

func look() -> Vector2:
	if active_device < 0 or not Input.get_connected_joypads().has(active_device) or not DisplayServer.window_is_focused(): return Vector2.ZERO
	var vector: Vector2 = Vector2(Input.get_joy_axis(active_device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(active_device, JOY_AXIS_RIGHT_Y))
	var strength: float = vector.length()
	return vector.normalized() * pow(clampf((strength - deadzone) / (1 - deadzone), 0, 1), 1.45) if strength > deadzone else Vector2.ZERO

func rebind(action: String, event: InputEvent, controller: bool) -> void :
	if not LABELS.has(action): return
	for old: InputEvent in InputMap.action_get_events(action):
		var is_pad: bool = old is InputEventJoypadButton or old is InputEventJoypadMotion
		if is_pad == controller: InputMap.action_erase_event(action, old)
	var binding: InputEvent = event.duplicate()
	if binding is InputEventKey: binding.pressed = false;binding.echo = false;binding.keycode = 0
	if binding is InputEventJoypadButton: binding.pressed = false;binding.device = -1
	if binding is InputEventJoypadMotion: binding.axis_value = signf(binding.axis_value);binding.device = -1
	if binding is InputEventMouseButton: binding.pressed = false;binding.double_click = false
	InputMap.action_add_event(action, binding);save()

func label(action: String, controller: bool = false) -> String:
	var labels: Array[String] = []
	for event: InputEvent in InputMap.action_get_events(action):
		var is_pad: bool = event is InputEventJoypadButton or event is InputEventJoypadMotion
		if is_pad != controller: continue
		if event is InputEventKey: labels.append(OS.get_keycode_string(event.physical_keycode if event.physical_keycode else event.keycode))
		elif event is InputEventJoypadButton: labels.append(_button_name(event.button_index))
		elif event is InputEventJoypadMotion: labels.append("RT / R2 / ZR" if event.axis == JOY_AXIS_TRIGGER_RIGHT else "LT / L2 / ZL" if event.axis == JOY_AXIS_TRIGGER_LEFT else "Stick G " + ["←", "→", "↑", "↓"][int(event.axis) * 2 + int(event.axis_value > 0)])
		elif event is InputEventMouseButton: labels.append("Clic G" if event.button_index == MOUSE_BUTTON_LEFT else "Clic D" if event.button_index == MOUSE_BUTTON_RIGHT else "Souris %d" % event.button_index)
	return " / ".join(labels) if not labels.is_empty() else "—"

func _button_name(button: int) -> String:
	var names: Dictionary = {JOY_BUTTON_A: "A / Croix / B", JOY_BUTTON_B: "B / Rond / A", JOY_BUTTON_X: "X / Carré / Y", JOY_BUTTON_Y: "Y / Triangle / X", JOY_BUTTON_LEFT_SHOULDER: "LB / L1 / L", JOY_BUTTON_RIGHT_SHOULDER: "RB / R1 / R", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_START: "Menu / Options / +", JOY_BUTTON_BACK: "Vue / Partage / −", JOY_BUTTON_DPAD_UP: "Croix ↑", JOY_BUTTON_DPAD_DOWN: "Croix ↓", JOY_BUTTON_DPAD_LEFT: "Croix ←", JOY_BUTTON_DPAD_RIGHT: "Croix →"}
	return str(names.get(button, "Bouton %d" % button))

func reset() -> void :
	for action: String in LABELS:
		InputMap.action_erase_events(action)
		for event: InputEvent in _defaults[action]: InputMap.action_add_event(action, event)
	controller_sprint = false;save()

func save() -> void :
	var config: ConfigFile = ConfigFile.new()
	for action: String in LABELS: config.set_value("bindings", action, InputMap.action_get_events(action))
	config.set_value("pad", "sensitivity", look_sensitivity);config.set_value("pad", "deadzone", deadzone);config.set_value("pad", "vibration", vibration);config.save("user://controls.cfg")

func rumble(strength: float = 0.3) -> void :
	if vibration and active_device >= 0: Input.start_joy_vibration(active_device, strength, strength * 0.6, 0.12)
