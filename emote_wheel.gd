class_name PaperEmoteWheel
extends Control



const T = preload("res://ui_theme.gd")
const Sound = preload("res://ui_sound.gd")
const IDS: Array[String] = ["wave", "thumbsup", "cheer", "laugh", "point", "shrug", "sad", "fear"]
const LABELS: Array[String] = ["Salut", "Bien joué", "Célébrer", "Rire", "Par ici", "Hausser les épaules", "Déception", "Effroi"]
const INNER: float = 84.0
const OUTER: float = 236.0
var world: Node
var selected: int = -1

var page: int = 0
var _stick: Vector2 = Vector2.ZERO
var _opened_at: int = 0

func setup(owner_world: Node) -> void :
	world = owner_world
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	focus_mode = Control.FOCUS_ALL
	hide()

func open() -> void :
	show()
	selected = -1
	_stick = Vector2.ZERO
	_opened_at = Time.get_ticks_msec()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	world.release_ability(1)
	grab_focus()
	if world.mobile_controls: world.mobile_controls.cancel_all()
	queue_redraw()

func close() -> void :
	hide()
	release_focus()
	if world.phase == "playing" and not world.pause_open: world.capture_gameplay_mouse()

func _ids() -> Array:
	if page == 0: return IDS
	return world.owned_dances.slice(0, 8)

func _labels() -> Array:
	if page == 0: return LABELS
	return _ids().map( func(id: Variant) -> String: return PaperDances.title(str(id)))

func _flip() -> void :
	page = 1 - page
	selected = -1
	Sound.play("hover")
	queue_redraw()

func _choose(index: int) -> void :
	var ids: Array = _ids()
	if index < 0 or index >= ids.size(): return
	Sound.play("click")
	world.request_emote(str(ids[index]))
	close()

func _sector_at(point: Vector2) -> int:
	var offset: Vector2 = point - size * 0.5
	var distance: float = offset.length()
	if distance < INNER or distance > OUTER + 40.0: return -1

	var angle: float = fposmod(offset.angle() + PI * 0.5 + TAU / 16.0, TAU)
	return int(angle / (TAU / 8.0)) % 8

func _set_selected(index: int) -> void :
	if index == selected: return
	selected = index
	if index >= 0: Sound.play("hover")
	queue_redraw()

func _gui_input(event: InputEvent) -> void :
	if event is InputEventMouseMotion:
		_set_selected(_sector_at(event.position))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_flip()
		accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var index: int = _sector_at(event.position)
		if index >= 0: _choose(index)
		elif (event.position - size * 0.5).length() < INNER: close()
		accept_event()

func _input(event: InputEvent) -> void :
	if not visible: return
	if event.is_action_pressed("emotes") or event.is_action_pressed("pause_game") or event.is_action_pressed("cancel_aim"):

		if Time.get_ticks_msec() - _opened_at > 80:
			close()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_G, KEY_ESCAPE]:
			close()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_TAB or event.keycode == KEY_9:
			_flip()
			get_viewport().set_input_as_handled()
			return
		var digit: int = int(event.physical_keycode) - KEY_1
		if digit >= 0 and digit < 8:
			_choose(digit)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
		if event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_RIGHT_X]: _stick.x = event.axis_value
		else: _stick.y = event.axis_value
		if _stick.length() > 0.55: _set_selected(_sector_at(size * 0.5 + _stick.normalized() * (INNER + OUTER) * 0.5))
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		_set_selected(posmod(selected + 1, 8))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		_set_selected(posmod(selected - 1 if selected >= 0 else 0, 8))
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
		_flip()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") and selected >= 0:
		_choose(selected)
		get_viewport().set_input_as_handled()

func _draw() -> void :
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.018, 0.035, 0.62))
	var center: Vector2 = size * 0.5
	var title: Font = T.font("title")
	var caps: Font = T.font("caps")
	var body: Font = T.font("semibold")
	var labels: Array = _labels()
	for i: int in range(8):
		var start: float = - PI * 0.5 - TAU / 16.0 + float(i) * TAU / 8.0 + 0.012
		var end: float = start + TAU / 8.0 - 0.024
		var hovered: bool = i == selected
		var outer: float = OUTER + (10.0 if hovered else 0.0)
		var points: PackedVector2Array = PackedVector2Array()
		var steps: int = 14
		for s: int in range(steps + 1): points.append(center + Vector2.from_angle(lerpf(start, end, float(s) / steps)) * outer)
		for s: int in range(steps, -1, -1): points.append(center + Vector2.from_angle(lerpf(start, end, float(s) / steps)) * INNER)
		draw_colored_polygon(points, Color(0.08, 0.16, 0.17, 0.94) if hovered else Color(0.06, 0.07, 0.1, 0.88))
		var edge: PackedVector2Array = points.duplicate()
		edge.append(points[0])
		draw_polyline(edge, T.TEAL if hovered else Color(1, 1, 1, 0.08), 2.0 if hovered else 1.0, true)
		var mid: Vector2 = center + Vector2.from_angle((start + end) * 0.5) * (INNER + outer) * 0.5
		var text: String = PaperLanguage.t(str(labels[i])) if i < labels.size() else "—"
		var size_px: int = 16 if text.length() < 12 else 14
		var width: float = body.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		if width > 118.0:
			draw_multiline_string(body, mid + Vector2(-60, 6), text, HORIZONTAL_ALIGNMENT_CENTER, 120, size_px, 2, T.PAPER if hovered else T.PAPER_DIM)
		else:
			draw_string(body, mid + Vector2( - width * 0.5, 12), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, T.PAPER if hovered else T.PAPER_DIM)
		var key: String = str(i + 1)
		var cap: Rect2 = Rect2(mid + Vector2(-10, -26), Vector2(20, 20))
		var cap_style: StyleBoxFlat = StyleBoxFlat.new()
		cap_style.bg_color = T.TEAL if hovered else Color("3a4357")
		cap_style.set_corner_radius_all(4)
		draw_style_box(cap_style, cap)
		draw_string(caps, cap.position + Vector2(6, 15), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("10141c") if hovered else T.PAPER)
	draw_circle(center, INNER - 8.0, Color(0.04, 0.05, 0.075, 0.96))
	draw_arc(center, INNER - 8.0, 0, TAU, 48, Color(T.TEAL, 0.5), 1.5, true)
	var head: String = PaperLanguage.t("ÉMOTES" if page == 0 else "DANSES")
	var head_width: float = title.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	draw_string(title, center + Vector2( - head_width * 0.5, 2), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, T.PAPER)
	var hint: String = PaperLanguage.t("TAB · Danses" if page == 0 else ("TAB · Émotes" if not world.owned_dances.is_empty() else "Boutique du menu"))
	var hint_width: float = caps.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(caps, center + Vector2( - hint_width * 0.5, 24), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, T.PAPER_DIM)
