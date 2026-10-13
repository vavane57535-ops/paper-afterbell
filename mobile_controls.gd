class_name PaperMobileControls
extends Control

signal pause_requested
signal training_requested
signal spectate_requested
signal cancel_aim_requested
const DATA = preload("res://data.gd")
const T = preload("res://ui_theme.gd")
const Icons = preload("res://ui_icons.gd")

var world: Node
var enabled: bool = false:
	set(value):
		enabled = value;visible = value
		if not value: cancel_all()
var move_vector: Vector2 = Vector2.ZERO
var sprint_enabled: bool = false
var interact_held: bool = false
var safe_margins_override: Vector4 = Vector4(-1, -1, -1, -1)
var _look_accum: Vector2 = Vector2.ZERO
var _fingers: Dictionary = {}
var _buttons: Dictionary = {}
var _joystick_id: int = -1
var _look_id: int = -1
var _actor: Node
var _cooldown_peaks: Array[float] = [1, 1, 1, 1, 1, 1]
var _joystick: JoystickPad
var _look_area: Control
var _button_root: Control
var _qte_title: Label
var _qte_bar: ProgressBar
var _scale: float = 1.0
var editing: bool = false
var custom_layout: Dictionary = {}
var _layout_before_edit: Dictionary = {}
var _edit_target: Control
var _edit_offset: Vector2
var _edit_toolbar: PanelContainer

const SHORT_NAMES: Dictionary = {
	"Alice": ["GRIFFES", "RÉVÉLER", "PIQUES", "OMBRE", "DOUBLES", "PHASE 6"], 
	"Ashura": ["DRONE", "ROLLERS"], "Simon": ["FLASHBANG", "VITESSE ×2"], 
	"Usayuko": ["SAISIR", "BLOQUER", "FRAPPER", "DROPKICK"], 
	"Lysia": ["SURCHAUFFE", "REPOUSSER", "VISION"], 
	"Elly": ["SOIGNER", "ZONE", "", "FUSIL"], 
	"Bleuette": ["ENCOURAGER", "RECHARGER", "", "COURAGE"]
}

class TouchPadButton extends Control:
	var caption: String = ""
	var detail: String = ""
	var badge: String = ""
	var disabled: bool = false
	var pressed_state: bool = false
	var selected: bool = false
	var cooldown: float = 0.0
	var accent: Color = Color("87c9c4")
	var icon_tex: Texture2D
	var _panel: StyleBoxFlat
	func _draw() -> void :
		var alpha: float = 0.5 if disabled else 1.0
		if _panel == null:
			_panel = StyleBoxFlat.new()
			_panel.set_corner_radius_all(14)
			_panel.anti_aliasing = true
		_panel.bg_color = Color(0.04, 0.05, 0.075, 0.86 if not pressed_state else 0.97)
		if selected: _panel.bg_color = Color(0.1, 0.13, 0.14, 0.92)
		_panel.border_color = Color(accent, 0.3 if disabled else 1.0 if selected or pressed_state else 0.55)
		_panel.set_border_width_all(2 if selected or pressed_state else 1)
		draw_style_box(_panel, Rect2(Vector2.ZERO, size))
		if cooldown > 0:
			draw_rect(Rect2(Vector2(8, size.y - 7), Vector2((size.x - 16) * clampf(cooldown, 0, 1), 3)), Color(accent, 0.75))
		var title_font: Font = T.font("title")
		var caps: Font = T.font("caps")
		var small: int = maxi(10, int(size.y * 0.15)); var large: int = maxi(12, int(size.y * 0.19))
		if not badge.is_empty():
			draw_circle(Vector2(14, 13), 9, Color(accent, 0.22))
			draw_string(caps, Vector2(9, 18), badge, HORIZONTAL_ALIGNMENT_CENTER, 10, 11, Color(accent, alpha))
		var top: float = size.y * 0.47 if not detail.is_empty() else size.y * 0.58
		if icon_tex:
			var side: float = size.y * 0.36
			draw_texture_rect(icon_tex, Rect2(Vector2((size.x - side) * 0.5, size.y * 0.1), Vector2(side, side)), false, Color(Color("f1ebdd"), alpha))
			top = size.y * 0.66
			large = maxi(10, int(size.y * 0.15))
			small = maxi(9, int(size.y * 0.13))
		draw_string(title_font, Vector2(4, top), PaperLanguage.t(caption), HORIZONTAL_ALIGNMENT_CENTER, size.x - 8, large, Color(Color("ede7dc"), alpha))
		if not detail.is_empty(): draw_string(caps, Vector2(4, top + small + 4.0 if icon_tex else size.y * 0.74), PaperLanguage.t(detail), HORIZONTAL_ALIGNMENT_CENTER, size.x - 8, small, Color(accent, alpha))

class JoystickPad extends Control:
	var stick: Vector2 = Vector2.ZERO
	var held: bool = false
	func _draw() -> void :
		var center: Vector2 = size * 0.5; var radius: float = minf(size.x, size.y) * 0.35
		draw_circle(center, radius + 12, Color(0.02, 0.035, 0.055, 0.3))
		draw_circle(center, radius, Color(0.06, 0.09, 0.12, 0.48))
		draw_arc(center, radius, 0, TAU, 56, Color(0.7, 0.86, 0.86, 0.45), 1.5, true)
		for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			draw_line(center + direction * (radius - 9), center + direction * (radius - 3), Color(0.7, 0.86, 0.86, 0.55), 2)
		var thumb: Vector2 = center + stick * radius
		draw_circle(thumb, 26, Color(0.11, 0.18, 0.22, 0.85))
		draw_arc(thumb, 26, 0, TAU, 40, Color(0.65, 0.87, 0.83, 0.9 if held else 0.45), 2, true)
		if held: draw_circle(thumb, 5, Color("a8dbd0"))

func setup(owner: Node) -> void :
	world = owner;name = "MobileControls";mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_look_area = Control.new();_look_area.name = "LookArea";_look_area.mouse_filter = Control.MOUSE_FILTER_IGNORE;add_child(_look_area)
	_joystick = JoystickPad.new();_joystick.name = "JoystickArea";_joystick.mouse_filter = Control.MOUSE_FILTER_IGNORE;add_child(_joystick)
	_button_root = Control.new();_button_root.name = "Buttons";_button_root.mouse_filter = Control.MOUSE_FILTER_IGNORE;add_child(_button_root)
	_button_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for slot: int in range(6): _make_button("Ability" + str(slot), "", str(slot + 1))
	_make_button("Sprint", "COURIR");_make_button("Interact", "INTERAGIR", "E")
	_make_button("CancelAim", "ANNULER");_make_button("Pause", "MENU")
	_make_button("Jump", "SAUTER");_make_button("Emotes", "ÉMOTES")
	_make_button("Training", "ESSAIS");_make_button("Spectate", "SUIVRE")
	_make_button("Camera", "CAMÉRA")
	for key: String in ["J", "K", "L"]: _make_button("QTE" + key, key)
	_qte_title = Label.new();_qte_title.name = "ArchiveQTELabel";_qte_title.text = "ARCHIVE · TOUCHE LA LETTRE";_qte_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;_qte_title.mouse_filter = Control.MOUSE_FILTER_IGNORE;_button_root.add_child(_qte_title)
	_qte_title.add_theme_font_size_override("font_size", 17);_qte_title.add_theme_color_override("font_color", Color("ede7dc"));_qte_title.add_theme_font_override("font", T.font("caps"))
	_qte_bar = ProgressBar.new();_qte_bar.name = "ArchiveQTETime";_qte_bar.show_percentage = false;_qte_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE;_button_root.add_child(_qte_bar)
	var background: StyleBoxFlat = StyleBoxFlat.new();background.bg_color = Color("1c2934");background.set_corner_radius_all(3);_qte_bar.add_theme_stylebox_override("background", background)
	var fill: StyleBoxFlat = StyleBoxFlat.new();fill.bg_color = Color("9dd4c7");fill.set_corner_radius_all(3);_qte_bar.add_theme_stylebox_override("fill", fill)
	resized.connect(_layout)
	_layout();refresh(null);visible = enabled
	var config: ConfigFile = ConfigFile.new()
	if config.load("user://touch_layout.cfg") == OK:
		for key: String in config.get_section_keys("layout"): custom_layout[key] = config.get_value("layout", key)
	_layout()

func _make_button(id: String, caption: String, badge: String = "") -> TouchPadButton:
	var button: TouchPadButton = TouchPadButton.new();button.name = id;button.caption = caption;button.badge = badge;button.mouse_filter = Control.MOUSE_FILTER_IGNORE;_button_root.add_child(button);_buttons[id] = button;return button

func _safe_margins() -> Vector4:
	if safe_margins_override.x >= 0: return safe_margins_override
	if not OS.has_feature("android"): return Vector4.ZERO
	var safe: Rect2i = DisplayServer.get_display_safe_area(); var window: Vector2i = DisplayServer.window_get_size()
	if safe.size.x <= 0 or safe.size.y <= 0 or window.x <= 0 or window.y <= 0: return Vector4.ZERO
	var ratio: Vector2 = size / Vector2(window)
	return Vector4(maxf(0, safe.position.x) * ratio.x, maxf(0, safe.position.y) * ratio.y, maxf(0, window.x - safe.end.x) * ratio.x, maxf(0, window.y - safe.end.y) * ratio.y)

func _place(id: String, rect: Rect2) -> void :
	if custom_layout.has(id):
		var saved: Vector2 = custom_layout[id]
		rect.position = (saved * size - rect.size * 0.5).clamp(Vector2.ZERO, (size - rect.size).max(Vector2.ZERO))
	var button: Control = _buttons[id];button.position = rect.position;button.size = rect.size;button.queue_redraw()

func _layout() -> void :
	if not is_instance_valid(_joystick): return
	if not _fingers.is_empty(): cancel_all()
	var safe: Vector4 = _safe_margins();_scale = clampf(size.y / 720.0, 0.85, 1.25)
	var s: float = _scale; var left: float = safe.x + 20 * s; var right: float = size.x - safe.z - 20 * s; var bottom: float = size.y - safe.w - 25 * s
	_joystick.position = Vector2(left, bottom - 235 * s);_joystick.size = Vector2(235, 230) * s
	if custom_layout.has("Joystick"): _joystick.position = (Vector2(custom_layout.Joystick) * size - _joystick.size * 0.5).clamp(Vector2.ZERO, (size - _joystick.size).max(Vector2.ZERO))
	_look_area.position = Vector2(size.x * 0.32, safe.y + 65 * s);_look_area.size = Vector2(size.x - _look_area.position.x - safe.z, size.y - _look_area.position.y - safe.w)
	var width: float = 98 * s; var height: float = 68 * s; var gap: float = 10 * s
	for slot: int in range(6):
		_place("Ability" + str(slot), Rect2(Vector2(right - width * 3 - gap * 2 + (slot % 3) * (width + gap), bottom - height * 2 - gap + (slot / 3) * (height + gap)), Vector2(width, height)))
	_place("Sprint", Rect2(Vector2(left + 235 * s, bottom - 78 * s), Vector2(100, 68) * s))
	_place("Interact", Rect2(Vector2(right - 434 * s, bottom - 86 * s), Vector2(106, 86) * s))
	_place("CancelAim", Rect2(Vector2(right - 434 * s, bottom - 155 * s), Vector2(106, 59) * s))
	_place("Pause", Rect2(Vector2(right - 86 * s, safe.y + 15 * s), Vector2(86, 54) * s))
	_place("Training", Rect2(Vector2(right - 184 * s, safe.y + 15 * s), Vector2(88, 54) * s))
	_place("Spectate", Rect2(Vector2(right - 130 * s, safe.y + 106 * s), Vector2(130, 56) * s))
	_place("Emotes", Rect2(Vector2(right - 282 * s, safe.y + 15 * s), Vector2(88, 54) * s))
	_place("Camera", Rect2(Vector2(right - 380 * s, safe.y + 15 * s), Vector2(88, 54) * s))
	_place("Jump", Rect2(Vector2(right - 106 * s, bottom - 235 * s), Vector2(106, 76) * s))
	var qte_origin: Vector2 = Vector2(size.x * 0.5 - 137 * s, bottom - 260 * s)
	for index: int in range(3): _place("QTE" + ["J", "K", "L"][index], Rect2(qte_origin + Vector2(index * 96 * s, 0), Vector2(82, 76) * s))
	_qte_title.position = qte_origin + Vector2(-40, -35) * s;_qte_title.size = Vector2(354, 30) * s
	_qte_bar.position = qte_origin + Vector2(0, 84) * s;_qte_bar.size = Vector2(274, 7) * s

func consume_look() -> Vector2:
	var result: Vector2 = _look_accum;_look_accum = Vector2.ZERO;return result

func cancel_all() -> void :
	if is_instance_valid(world) and _fingers.values().any( func(row: Dictionary): return row.get("button", "") == "Ability1"): world.release_ability(1)
	_fingers.clear();_joystick_id = -1;_look_id = -1;_look_accum = Vector2.ZERO
	move_vector = Vector2.ZERO;sprint_enabled = false;interact_held = false
	if is_instance_valid(_joystick): _joystick.stick = Vector2.ZERO;_joystick.held = false;_joystick.queue_redraw()
	for button: TouchPadButton in _buttons.values(): button.pressed_state = false;button.queue_redraw()

func _accepting() -> bool:
	return enabled and is_visible_in_tree() and is_instance_valid(world) and str(world.get("phase")) == "playing" and not bool(world.get("pause_open"))

func _input(event: InputEvent) -> void :
	if editing:
		_edit_input(event)
		return
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag): return
	if not _accepting():
		if not _fingers.is_empty(): cancel_all()
		return
	var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
	if event is InputEventScreenTouch:
		if event.pressed: _touch_begin(event.index, point)
		else: _touch_end(event.index)
	else: _touch_drag(event.index, point)


	get_viewport().set_input_as_handled()

func _button_at(point: Vector2) -> String:
	for id: Variant in _buttons:
		var button: TouchPadButton = _buttons[id]
		if button.visible and Rect2(button.position, button.size).has_point(point): return str(id)
	return ""

func _touch_begin(id: int, point: Vector2) -> void :
	if _fingers.has(id): _touch_end(id)
	var button_id: String = _button_at(point)
	if not button_id.is_empty():
		var button: TouchPadButton = _buttons[button_id]
		_fingers[id] = {"kind": "button", "button": button_id, "last": point}
		if button.disabled: return
		button.pressed_state = true;button.queue_redraw()
		if button_id == "Interact": interact_held = true
		else: _activate(button_id)
		return
	if _joystick.visible and Rect2(_joystick.position, _joystick.size).has_point(point):
		_fingers[id] = {"kind": "joystick" if _joystick_id < 0 else "blocked", "last": point}
		if _joystick_id < 0: _joystick_id = id;_joystick.held = true;_move_stick(point)
		return
	if Rect2(_look_area.position, _look_area.size).has_point(point) and _look_id < 0:
		_look_id = id;_fingers[id] = {"kind": "look", "last": point}
	else: _fingers[id] = {"kind": "blocked", "last": point}

func _move_stick(point: Vector2) -> void :
	var offset: Vector2 = (point - _joystick.position - _joystick.size * 0.5) / (minf(_joystick.size.x, _joystick.size.y) * 0.35)
	var length: float = minf(1.0, offset.length())
	move_vector = offset.normalized() * maxf(0.0, (length - 0.13) / 0.87) if length > 0.13 else Vector2.ZERO
	_joystick.stick = offset.limit_length(1);_joystick.queue_redraw()

func _touch_drag(id: int, point: Vector2) -> void :
	if not _fingers.has(id): return
	var finger: Dictionary = _fingers[id]
	if str(finger.kind) == "joystick" and id == _joystick_id: _move_stick(point)
	elif str(finger.kind) == "look" and id == _look_id: _look_accum += (point - Vector2(finger.last)).limit_length(400)
	elif str(finger.kind) == "button":
		var button: TouchPadButton = _buttons[str(finger.button)]
		button.pressed_state = not button.disabled and Rect2(button.position, button.size).grow(18 * _scale).has_point(point)
		button.queue_redraw()
		if str(finger.button) == "Interact": _refresh_interact(id, button.pressed_state)
	finger.last = point

func _refresh_interact(changed_id: int = -1, inside: bool = false) -> void :
	interact_held = false
	for id: Variant in _fingers:
		var finger: Dictionary = _fingers[id]
		if str(finger.kind) != "button" or str(finger.button) != "Interact": continue
		if int(id) == changed_id:
			finger["inside"] = inside
		if bool(finger.get("inside", true)): interact_held = true
	if _buttons.has("Interact"):
		_buttons.Interact.pressed_state = interact_held;_buttons.Interact.queue_redraw()

func _touch_end(id: int) -> void :
	if not _fingers.has(id): return
	var finger: Dictionary = _fingers[id];_fingers.erase(id)
	if id == _joystick_id:
		_joystick_id = -1;move_vector = Vector2.ZERO;_joystick.stick = Vector2.ZERO;_joystick.held = false;_joystick.queue_redraw()
	if id == _look_id: _look_id = -1
	if str(finger.kind) == "button":
		var button: TouchPadButton = _buttons[str(finger.button)];button.pressed_state = false;button.queue_redraw()
		if str(finger.button).begins_with("Ability") and not _fingers.values().any( func(other: Dictionary): return other.get("button", "") == finger.button): world.release_ability(int(str(finger.button).trim_prefix("Ability")))
	_refresh_interact()

func _activate(id: String) -> void :
	if id == "Emotes": world.toggle_emotes();return
	if id.begins_with("Ability"):
		world.request_ability(int(id.trim_prefix("Ability")))
	elif id.begins_with("QTE") and is_instance_valid(_actor):
		world.request_archive_qte(int(_actor.effects.get("archive_qte_id", 0)), id.trim_prefix("QTE"))
	elif id == "Sprint": sprint_enabled = not sprint_enabled
	elif id == "CancelAim": cancel_aim_requested.emit()
	elif id == "Pause": cancel_all();pause_requested.emit()
	elif id == "Training": cancel_all();training_requested.emit()
	elif id == "Spectate": spectate_requested.emit()
	elif id == "Camera" and is_instance_valid(world) and world.camera_rig: world.camera_rig.toggle_mode()
	elif id == "Jump": world.request_jump()

func refresh(actor: Node) -> void :
	if editing: return
	if _actor != actor: cancel_all()
	_actor = actor
	if _buttons.is_empty(): return
	for id: String in ["Emotes", "Training", "Pause", "Spectate", "CancelAim"]:
		_buttons[id].detail = "TOUCHER";_buttons[id].queue_redraw()
	_buttons["Emotes"].visible = actor != null and not actor.killer and actor.active()
	var active: bool = actor != null and (actor.active() if actor.has_method("active") else bool(actor.get("alive")))
	var character: String = str(actor.get("character")) if actor else ""
	var effects: Dictionary = actor.effects if actor else {}
	var om: bool = is_instance_valid(world) and str(world.get("ruleset")) == "om"
	var crawling: bool = om and actor != null and bool(actor.get("alive")) and bool(effects.get("downed", false))


	var action_blocked: bool = bool(effects.get("shadow_hide", false)) or bool(effects.get("drone_piloting", false)) or int(effects.get("revive_target", -1)) >= 0
	for effect: String in ["stun", "forced_time", "attack_lock", "recover", "grab_time", "overheat_time", "heal_time"]:
		action_blocked = action_blocked or float(effects.get(effect, 0)) > 0
	var rooted: bool = float(effects.get("root", 0)) > 0
	var skills: Array = DATA.abilities_for(character, "om" if om else "forsaken")
	for slot: int in range(6):
		var button: TouchPadButton = _buttons["Ability" + str(slot)]
		button.visible = slot < skills.size() and str(skills[slot][0]) != "—"
		if not button.visible: continue
		var names: Array = SHORT_NAMES.get(character, []);button.caption = str(names[slot]) if slot < names.size() and not str(names[slot]).is_empty() else str(skills[slot][0])
		button.icon_tex = Icons.ability_live(character, slot, effects)
		button.accent = Color("e0657a") if character == "Alice" else Color("87c9c4")
		if om and character == "Simon":
			if slot == 0: button.caption = "COUP ÉCLAIR" if bool(effects.get("flash_melee", false)) else "FLASHBANG"
			if slot == 2: button.caption = "MODE LANCER" if bool(effects.get("flash_melee", false)) else "MODE COUP"
		if om and character == "Ashura":
			if slot == 0: button.caption = "TÉLÉGUIDÉ" if bool(effects.get("drone_precise", false)) else "DRONE RAPIDE"
			elif slot == 1: button.caption = "ROLLERS"
			elif slot == 2: button.caption = "CHANGER MODE"
		var cooldown: float = float(actor.cooldowns.get(slot, 0));_cooldown_peaks[slot] = maxf(maxf(1, float(skills[slot][1])), cooldown)
		var locked: bool = slot == 3 and character in ["Elly", "Usayuko", "Bleuette"] and not world.combat.lms_available(actor)
		var used: bool = slot == 3 and ((character == "Usayuko" and bool(effects.get("dropkick_used", false))) or (character == "Elly" and bool(effects.get("shotgun_used", false))) or (character == "Bleuette" and bool(effects.get("aura_used", false))))
		button.disabled = not active or locked or used or cooldown > 0
		button.cooldown = cooldown / _cooldown_peaks[slot];button.selected = false
		button.detail = "%.1f s" % cooldown if cooldown > 0 else "LMS" if locked else "UTILISÉ" if used else "PRÊT"
		if character in ["Simon", "Ashura"] and slot == 1:
			button.detail = "CHARGE %.1f s · N%d" % [float(effects.get("boost_charge", 0)), int(effects.get("boost_level", 0))] if bool(effects.get("boost_charging", false)) else "MAINTENIR"
		if character == "Simon" and slot == 0 and bool(effects.get("grenade_aiming", false)): button.detail = "CONFIRMER";button.selected = true
		if character == "Usayuko" and slot == 1 and float(effects.get("counter", 0)) > 0:
			button.caption = "CONTRER";button.detail = "MAINTENANT";button.disabled = not active;button.selected = true
		if character == "Alice" and slot == 2 and bool(effects.get("spike_aiming", false)):
			button.caption = "PIQUES";button.detail = "CONFIRMER";button.selected = true;button.disabled = not active
		if character == "Alice" and slot == 5:
			var rage: float = float(effects.get("rage", 0)); var phase: float = float(effects.get("phase6", 0))
			button.caption = "TRUE FORM";button.disabled = not active or rage < 100 or phase > 0 or bool(effects.get("true_form_used", false));button.detail = "%.0f s" % phase if phase > 0 else "UTILISÉ" if bool(effects.get("true_form_used", false)) else "ACTIVER" if rage >= 100 else "%d / 15" % int(effects.get("stun_count", 0));button.cooldown = clampf(rage / 100, 0, 1);button.selected = rage >= 100 and phase <= 0
		var counter_available: bool = character == "Usayuko" and slot == 1 and float(effects.get("counter", 0)) > 0
		if active and (action_blocked or (rooted and not counter_available)):
			button.disabled = true;button.selected = false
			button.detail = "ÉTOURDI" if float(effects.get("stun", 0)) > 0 else "IMMOBILISÉ" if rooted else "OCCUPÉ"
		button.queue_redraw()
	_buttons.Sprint.visible = active and not bool(effects.get("drone_piloting", false));_buttons.Sprint.selected = sprint_enabled;_buttons.Sprint.detail = "ACTIVÉ" if sprint_enabled else "TOUCHER";_buttons.Sprint.queue_redraw()
	_buttons.Interact.visible = active and character != "Alice" and not bool(effects.get("drone_piloting", false));_buttons.Interact.detail = "TOUCHER / TENIR"
	if int(effects.get("revive_target", -1)) >= 0: _buttons.Interact.caption = "RÉANIMER";_buttons.Interact.detail = "%d %%" % int(float(effects.get("revive_progress", 0)) * 100)
	else: _buttons.Interact.caption = "INTERAGIR"
	_buttons.Interact.queue_redraw()
	_buttons.CancelAim.visible = active and (bool(effects.get("spike_aiming", false)) or bool(effects.get("grenade_aiming", false)) or bool(effects.get("drone_piloting", false)))
	_buttons.Jump.visible = om and active and not bool(effects.get("drone_piloting", false));_buttons.Jump.disabled = not active or action_blocked or rooted or float(effects.get("jump_cd", 0)) > 0
	_buttons.Jump.detail = "%.1f s" % float(effects.get("jump_cd", 0)) if float(effects.get("jump_cd", 0)) > 0 else "PRÊT";_buttons.Jump.queue_redraw()
	_buttons.Training.visible = bool(world.get("training")) if is_instance_valid(world) else false
	_buttons.Spectate.visible = actor == null or not bool(actor.get("alive"))
	if is_instance_valid(world) and world.camera_rig: _buttons.Camera.detail = "DERRIÈRE" if world.camera_rig.is_behind() else "LIBRE 360°";_buttons.Camera.queue_redraw()
	_joystick.visible = active or crawling
	var remaining: float = float(effects.get("archive_qte_remaining", 0))
	var qte: bool = active and remaining > 0 and int(effects.get("archive_qte_id", 0)) > 0
	for key: String in ["J", "K", "L"]:
		var button: TouchPadButton = _buttons["QTE" + key];button.visible = qte;button.detail = "TOUCHER";button.disabled = false
		button.selected = qte and ["J", "K", "L"][clampi(int(effects.get("archive_qte_key", 0)), 0, 2)] == key
		button.queue_redraw()
	_qte_title.visible = qte;_qte_bar.visible = qte
	if qte:
		_qte_title.text = "ARCHIVE · TOUCHE " + ["J", "K", "L"][clampi(int(effects.get("archive_qte_key", 0)), 0, 2)]
		_qte_bar.value = remaining / maxf(0.1, float(effects.get("archive_qte_duration", 2.1))) * 100
	if not active and not crawling and (move_vector.length_squared() > 0 or interact_held or sprint_enabled): cancel_all()
	if crawling: interact_held = false;sprint_enabled = false

func _notification(what: int) -> void :
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]: cancel_all()

func start_edit() -> void :
	cancel_all();_layout_before_edit = custom_layout.duplicate();editing = true;enabled = true;show();world.ui.page.hide();world.ui.hud.hide();Input.emulate_mouse_from_touch = true
	for id: String in _buttons:
		var button: TouchPadButton = _buttons[id];button.show();button.disabled = false;button.detail = "DÉPLACER"
		if id.begins_with("Ability"): button.caption = "CAPACITÉ " + str(int(id.trim_prefix("Ability")) + 1)
		if id.begins_with("QTE"): button.hide()
		button.queue_redraw()
	_joystick.show();_qte_title.hide();_qte_bar.hide()
	_edit_toolbar = PanelContainer.new();add_child(_edit_toolbar);_edit_toolbar.position = Vector2(30, 100);_edit_toolbar.size = Vector2(size.x - 60, 85)
	var style: StyleBoxFlat = T.panel_style(0.96, T.TEAL_DIM, 10);style.set_content_margin_all(12);_edit_toolbar.add_theme_stylebox_override("panel", style)
	var row: HBoxContainer = HBoxContainer.new();_edit_toolbar.add_child(row)
	var hint: Label = Label.new();hint.text = "Fais glisser les boutons et le joystick.\nLe saut reste toujours disponible.";hint.add_theme_color_override("font_color", T.PAPER);hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL;row.add_child(hint)
	for spec: Array in [["DÉFAUT", func(): custom_layout.clear();_layout()], ["ANNULER", func(): finish_edit(false)], ["ENREGISTRER", func(): finish_edit(true)]]:
		var button: Button = Button.new();button.text = spec[0];button.custom_minimum_size = Vector2(145, 55);row.add_child(button);button.pressed.connect(spec[1])
		if spec[0] == "ENREGISTRER": button.theme_type_variation = "PrimaryButton"

func finish_edit(save: bool) -> void :
	if not save: custom_layout = _layout_before_edit.duplicate()
	else:
		var config: ConfigFile = ConfigFile.new()
		for key: String in custom_layout: config.set_value("layout", key, custom_layout[key])
		config.save("user://touch_layout.cfg")
	editing = false;_edit_target = null;_edit_toolbar.queue_free();enabled = false;_layout();world.controls_menu.open()

func _edit_input(event: InputEvent) -> void :
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton or event is InputEventMouseMotion): return
	var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			if Rect2(_edit_toolbar.position, _edit_toolbar.size).has_point(point): return
			var id: String = _button_at(point)
			_edit_target = _buttons[id] if not id.is_empty() else _joystick if Rect2(_joystick.position, _joystick.size).has_point(point) else null
			if _edit_target: _edit_offset = point - _edit_target.position
		else: _edit_target = null
	elif _edit_target:
		_edit_target.position = (point - _edit_offset).clamp(Vector2.ZERO, (size - _edit_target.size).max(Vector2.ZERO))
		var key: String = "Joystick" if _edit_target == _joystick else str(_edit_target.name)
		custom_layout[key] = (_edit_target.position + _edit_target.size * 0.5) / size
	if _edit_target: get_viewport().set_input_as_handled()
