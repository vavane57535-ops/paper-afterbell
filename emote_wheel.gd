class_name PaperEmoteWheel
extends Control



const T = preload("res://ui_theme.gd")
const Sound = preload("res://ui_sound.gd")
const IDS: Array[String] = ["wave", "thumbsup", "cheer", "laugh", "point", "shrug", "sad", "fear"]
const LABELS: Array[String] = ["Salut", "Bien joué", "Célébrer", "Rire", "Par ici", "Hausser les épaules", "Déception", "Effroi"]
const INNER: float = 84.0
const SECTORS: int = 9
const OUTER: float = 236.0
var world: Node
var selected: int = -1

var page: int = 0
var _stick: Vector2 = Vector2.ZERO
var _opened_at: int = 0
var _tab_rects: Array[Rect2] = []

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

# Mis à terre ou exécuté la roue ouverte : elle se referme (sinon son voile restait sur le film de l'exécution).
func _process(_delta: float) -> void :
	if not visible or world == null: return
	var actor: PaperActor = world.local_actor()
	if world.phase != "playing" or actor == null or not actor.active(): close()

# Pages de SECTORS (9) : toutes les émotes (gratuites), puis les danses achetées (une page vide
# renvoie vers la boutique si aucune danse n'est achetée).
func _pages() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var emotes: Array[String] = PaperEmotes.ids()
	var emote_pages: int = ceili(emotes.size() / float(SECTORS))
	for i: int in range(emote_pages): result.append({"dances": false, "ids": emotes.slice(i * SECTORS, i * SECTORS + SECTORS), "index": i, "count": emote_pages})
	var owned: Array = world.owned_dances.filter( func(id: Variant) -> bool: return not PaperDances.info(str(id)).is_empty())
	var dance_pages: int = maxi(1, ceili(owned.size() / float(SECTORS)))
	for i: int in range(dance_pages): result.append({"dances": true, "ids": owned.slice(i * SECTORS, i * SECTORS + SECTORS), "index": i, "count": dance_pages})
	return result

func _current() -> Dictionary:
	var pages: Array[Dictionary] = _pages()
	page = posmod(page, pages.size())
	return pages[page]

func _ids() -> Array:
	return _current().ids

func _labels() -> Array:
	return _ids().map( func(id: Variant) -> String: return PaperEmotes.title(str(id)))

func _flip(step: int = 1) -> void :
	page = posmod(page + step, _pages().size())
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

	var angle: float = fposmod(offset.angle() + PI * 0.5 + TAU / (2.0 * SECTORS), TAU)
	return int(angle / (TAU / SECTORS)) % SECTORS

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
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_flip(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
		accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i: int in range(_tab_rects.size()):
			if _tab_rects[i].grow(4.0).has_point(event.position):
				if i != page: _flip(i - page)
				accept_event()
				return
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
		if event.keycode == KEY_TAB or event.physical_keycode == KEY_0:
			_flip(-1 if event.shift_pressed else 1)
			get_viewport().set_input_as_handled()
			return
		var digit: int = int(event.physical_keycode) - KEY_1
		if digit >= 0 and digit < SECTORS:
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
		_set_selected(posmod(selected + 1, SECTORS))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		_set_selected(posmod(selected - 1 if selected >= 0 else 0, SECTORS))
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
		_flip(-1 if event.button_index == JOY_BUTTON_LEFT_SHOULDER else 1)
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
	for i: int in range(SECTORS):
		var start: float = - PI * 0.5 - TAU / (2.0 * SECTORS) + float(i) * TAU / SECTORS + 0.012
		var end: float = start + TAU / SECTORS - 0.024
		var hovered: bool = i == selected
		var outer: float = OUTER + (10.0 if hovered else 0.0)
		var points: PackedVector2Array = PackedVector2Array()
		var steps: int = 14
		for s: int in range(steps + 1): points.append(center + Vector2.from_angle(lerpf(start, end, float(s) / steps)) * outer)
		for s: int in range(steps, -1, -1): points.append(center + Vector2.from_angle(lerpf(start, end, float(s) / steps)) * INNER)
		# Secteur survolé : papier rouge découpé avec ombre d'encre (menus 0.16).
		if hovered:
			var shadow: PackedVector2Array = PackedVector2Array()
			for point: Vector2 in points: shadow.append(point + Vector2(6, 8))
			draw_colored_polygon(shadow, Color(0, 0, 0, 0.6))
		draw_colored_polygon(points, T.RED if hovered else Color(0.06, 0.07, 0.1, 0.88))
		var edge: PackedVector2Array = points.duplicate()
		edge.append(points[0])
		draw_polyline(edge, T.CREAM if hovered else Color(1, 1, 1, 0.08), 3.0 if hovered else 1.0, true)
		var mid: Vector2 = center + Vector2.from_angle((start + end) * 0.5) * (INNER + outer) * 0.5
		var text: String = PaperLanguage.t(str(labels[i])) if i < labels.size() else "—"
		var size_px: int = 15 if text.length() < 12 else 13
		var width: float = body.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		if width > 104.0:
			draw_multiline_string(body, mid + Vector2(-54, 6), text, HORIZONTAL_ALIGNMENT_CENTER, 108, size_px, 2, T.CREAM if hovered else T.PAPER_DIM)
		else:
			draw_string(body, mid + Vector2( - width * 0.5, 12), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, T.CREAM if hovered else T.PAPER_DIM)
		var key: String = str(i + 1)
		var cap: Rect2 = Rect2(mid + Vector2(-10, -26), Vector2(20, 20))
		var cap_style: StyleBoxFlat = StyleBoxFlat.new()
		cap_style.bg_color = T.CREAM if hovered else Color("3a4357")
		cap_style.set_corner_radius_all(4)
		draw_style_box(cap_style, cap)
		draw_string(caps, cap.position + Vector2(6, 15), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("10141c") if hovered else T.PAPER)
	draw_circle(center + Vector2(4, 6), INNER - 8.0, Color(0, 0, 0, 0.55))
	draw_circle(center, INNER - 8.0, T.CREAM)
	draw_arc(center, INNER - 8.0, 0, TAU, 48, Color(T.RED, 0.8), 3.0, true)
	var current: Dictionary = _current()
	var dances: bool = bool(current.dances)
	var head: String = PaperLanguage.t("DANSES" if dances else "ÉMOTES")
	var head_width: float = T.font("display").get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	draw_string(T.font("display"), center + Vector2( - head_width * 0.5, 4), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, T.INK_TEXT)
	var sub: String = "%d / %d" % [int(current.index) + 1, int(current.count)]
	if dances and (current.ids as Array).is_empty(): sub = PaperLanguage.t("Boutique du menu")
	var sub_width: float = caps.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(caps, center + Vector2( - sub_width * 0.5, 24), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, T.INK_MUTED)
	_draw_tabs(center + Vector2(0.0, OUTER + 46.0), caps)

# Onglets sous la roue : une languette de papier par page, la page courante en couleur.
func _draw_tabs(at: Vector2, caps: Font) -> void :
	var pages: Array[Dictionary] = _pages()
	var labels: Array[String] = []
	for entry: Dictionary in pages:
		var text: String = PaperLanguage.t("DANSES" if bool(entry.dances) else "ÉMOTES")
		if int(entry.count) > 1: text += " " + str(int(entry.index) + 1)
		labels.append(text)
	var widths: Array[float] = []
	var total: float = 0.0
	for text: String in labels:
		var w: float = caps.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 22.0
		widths.append(w)
		total += w + 8.0
	total -= 8.0
	var x: float = at.x - total * 0.5
	_tab_rects.clear()
	for i: int in range(labels.size()):
		var active: bool = i == page
		var dance_tab: bool = bool(pages[i].dances)
		var accent: Color = Color("ff6fd0") if dance_tab else T.RED
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = accent if active else Color(0.06, 0.07, 0.1, 0.88)
		box.border_color = T.CREAM if active else Color(accent, 0.7)
		box.set_border_width_all(2 if active else 1)
		box.set_corner_radius_all(2)
		box.shadow_color = Color(0, 0, 0, 0.5)
		box.shadow_offset = Vector2(3, 4)
		box.shadow_size = 1 if active else 0
		var rect: Rect2 = Rect2(Vector2(x, at.y - 11.0), Vector2(widths[i], 22.0))
		_tab_rects.append(rect)
		draw_style_box(box, rect)
		var label_color: Color = (Color("10141c") if dance_tab else T.CREAM) if active else T.PAPER_DIM
		draw_string(caps, Vector2(x + 11.0, at.y + 5.0), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, label_color)
		x += widths[i] + 8.0
	var hint: String = PaperLanguage.t("TAB · page suivante") if not world.mobile_mode else ""
	var hint_width: float = caps.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	if not hint.is_empty(): draw_string(caps, Vector2(at.x - hint_width * 0.5, at.y + 30.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, T.PAPER_DIM)
