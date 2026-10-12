extends Control

# Menu pause 0.16, équivalent direct des menus pause de Persona en version
# papier : la partie se fige en trame rouge, une bande rouge et une bande
# d'encre déchirées balaient l'écran, une feuille de cahier glisse depuis la
# droite avec la découpe du personnage (silhouette d'encre qui se colore),
# les commandes arrivent en éventail en lettres découpées, « PAUSE » se plaque
# en grand, un ruban défile. Fermeture rapide en sens inverse.
# Actions : ui.gd garde les mêmes effets qu'avant (reprendre, réglages,
# quitter avec confirmation) ; « Commandes » ouvre le carnet de commandes.

const T = preload("res://ui_theme.gd")
const G = preload("res://ui_paper_geom.gd")
const C = preload("res://ui_collage.gd")
const W = preload("res://ui_widgets.gd")
const Sound = preload("res://ui_sound.gd")
const MenuBackdrop = preload("res://ui_menu_backdrop.gd")
const GRAB_SHADER: Shader = preload("res://ui_pause_grab.gdshader")

const OPEN_TIME: float = 0.42
const CLOSE_TIME: float = 0.2

var ui: Node
var world: Node
var reduced: bool = false
var networked: bool = false
var confirm_open: bool = false
var _time: float = 0.0
var _age: float = 0.0
var _closing: float = -1.0
var _close_done: Callable = Callable()
var _person: String = "Ashura"
var _art: Texture2D
var _accent: Color = T.TEAL
var _red: Color = T.RED
var _grab: ColorRect
var _grab_mat: ShaderMaterial
var _back: Layer
var _front: Layer
var _entries: Array[W.NavItem] = []
var _entry_home: Array[Vector2] = []
var _hints: Dictionary = {}
var _hint: String = ""
var _hint_time: float = 0.0
var _confirm: Control
var _confirm_t: float = 0.0
var _confirm_buttons: Array[Button] = []
var _scraps: PackedVector3Array = PackedVector3Array()
# Commande sélectionnée à l'ouverture (retour depuis les réglages ou le
# carnet de commandes : on retrouve la commande d'où l'on vient).
var start_action: String = ""


class Layer extends Control:
	var painter: Callable

	func _init() -> void :
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void :
		if painter.is_valid(): painter.call(self)


func setup(owner_ui: Node) -> void :
	ui = owner_ui
	world = ui.world
	reduced = bool(ui.reduced_motion)
	networked = bool(world.networked)
	name = "PauseMenu"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var actor: Node = world.local_actor() if world.has_method("local_actor") else null
	if actor: _person = str(actor.get("character"))
	elif ui.has_method("_local_person"): _person = str(ui.call("_local_person"))
	_art = MenuBackdrop.art(_person)
	_accent = MenuBackdrop.accent_for(_person)
	_red = Color("e0314f") if _person == "Alice" else T.RED
	_grab = ColorRect.new()
	_grab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grab_mat = ShaderMaterial.new()
	_grab_mat.shader = GRAB_SHADER
	_grab_mat.set_shader_parameter("tint", _red.darkened(0.25))
	_grab.material = _grab_mat
	add_child(_grab)
	_grab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_back = Layer.new()
	_back.painter = _paint_back
	add_child(_back)
	_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_entries()
	_front = Layer.new()
	_front.painter = _paint_front
	add_child(_front)
	_front.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i: int in range(14):
		_scraps.append(Vector3(randf(), randf(), randf()))
	if reduced: _time = OPEN_TIME
	resized.connect(_layout)
	_layout()
	_update(0.0)
	Sound.play("open")


func _k() -> float:
	return size.y / 900.0 if size.y > 10.0 else 1.0


func _build_entries() -> void :
	var specs: Array = [
		["REPRENDRE", "resume", "Les amis jouent encore : la manche continue pendant ta pause." if networked else "Retourner dans la manche, là où la cloche t’attend."],
		["RÉGLAGES", "settings", "Jeu, graphismes, audio et accessibilité."],
		["COMMANDES", "controls", "Personnaliser le clavier et la manette."],
		["QUITTER LA PARTIE", "quit", "Quitter le salon de tes amis." if networked else "Abandonner la manche et retourner au menu principal."],
	]
	for i: int in range(specs.size()):
		var spec: Array = specs[i]
		var item: W.NavItem = W.NavItem.new()
		item.text = str(spec[0])
		item.hint = str(spec[2])
		item.reduced_motion = reduced
		var primary: bool = spec[1] == "resume"
		item.configure(76 if primary else 60, _red if primary else T.CREAM, primary)
		item.set_meta("base_px", 76 if primary else 60)
		item.cut_color = [_red, _accent, T.GOLD, Color("5a1626")][i]
		item.tilt_deg = [-8.0, -5.0, -7.0, -4.0][i]
		item.arc_x = [0.0, 46.0, 22.0, 64.0][i]
		item.focus_mode = Control.FOCUS_ALL
		item.pressed.connect(_choose.bind(str(spec[1])))
		item.hinted.connect(_on_hint)
		add_child(item)
		_entries.append(item)
		_hints[str(spec[1])] = str(spec[2])
	for i: int in range(_entries.size()):
		var item: W.NavItem = _entries[i]
		var up: W.NavItem = _entries[posmod(i - 1, _entries.size())]
		var down: W.NavItem = _entries[posmod(i + 1, _entries.size())]
		item.focus_neighbor_top = item.get_path_to(up)
		item.focus_neighbor_bottom = item.get_path_to(down)
		item.focus_neighbor_left = item.get_path()
		item.focus_neighbor_right = item.get_path()
	for i: int in range(specs.size()):
		if str(specs[i][1]) == start_action: _selected = i
	_hint = str(specs[_selected][2])
	_entries[_selected].call_deferred("grab_focus")


func _layout() -> void :
	var k: float = _k()
	var view: Vector2 = size
	_entry_home.clear()
	for i: int in range(_entries.size()):
		var item: W.NavItem = _entries[i]
		item.font_size_px = int(round(float(item.get_meta("base_px", 60)) * k))
		var px: float = float(item.font_size_px)
		item.custom_minimum_size = Vector2.ZERO
		item.size = Vector2(minf(view.x * 0.44, 680.0 * k), px * 1.6)
		var home: Vector2 = Vector2(view.x * 0.055, view.y * 0.17 + float(i) * 120.0 * k - (8.0 * k if i == 0 else 0.0))
		_entry_home.append(home)
		item.position = home


func _process(delta: float) -> void :
	_update(delta)


func _update(delta: float) -> void :
	if _closing >= 0.0:
		_closing += delta
		if _closing >= CLOSE_TIME:
			var done: Callable = _close_done
			_close_done = Callable()
			queue_free()
			if done.is_valid(): done.call()
			return
	else:
		_time += delta
	_hint_time += delta
	var open: float = _open_amount()
	_age += delta
	var freeze: float = clampf(_time / 0.14, 0.0, 1.0) if _closing < 0.0 else open
	# « Réduire les flashs » : la partie vire au rouge doucement et moins fort.
	if reduced: freeze = clampf(_age / 0.3, 0.0, 1.0) * 0.7
	_grab_mat.set_shader_parameter("amount", freeze)
	_grab_mat.set_shader_parameter("scroll", 0.0 if reduced else _time * 14.0)
	for i: int in range(_entries.size()):
		_place_entry(i)
	_hold_selection()
	if is_instance_valid(_confirm):
		_confirm_t = move_toward(_confirm_t, 1.0 if confirm_open else 0.0, delta / (0.16 if confirm_open else 0.1))
		if reduced: _confirm_t = 1.0 if confirm_open else 0.0
		var unfold: float = 1.0 + 2.4 * pow(_confirm_t - 1.0, 3.0) + 1.4 * pow(_confirm_t - 1.0, 2.0) if confirm_open else _confirm_t
		_confirm.scale = Vector2(1.0, maxf(0.01, unfold))
		_confirm.modulate.a = clampf(_confirm_t * 2.0, 0.0, 1.0)
		_confirm.visible = _confirm_t > 0.01
	_back.queue_redraw()
	_front.queue_redraw()


# 0 → 1 à l'ouverture, 1 → 0 à la fermeture (rapide, sens inverse).
func _open_amount() -> float:
	if _closing >= 0.0: return clampf(1.0 - _closing / CLOSE_TIME, 0.0, 1.0)
	return clampf(_time / OPEN_TIME, 0.0, 1.0)

func _phase(start: float, length: float) -> float:
	if _closing >= 0.0:
		return clampf(1.0 - _closing / CLOSE_TIME, 0.0, 1.0)
	return clampf((_time - start) / maxf(0.001, length), 0.0, 1.0)

static func _back_out(p: float) -> float:
	return 1.0 + 2.6 * pow(p - 1.0, 3.0) + 1.6 * pow(p - 1.0, 2.0)

static func _out(p: float) -> float:
	return 1.0 - pow(1.0 - p, 3.0)


func _place_entry(i: int) -> void :
	if i >= _entry_home.size(): return
	var item: W.NavItem = _entries[i]
	var k: float = _k()
	var p: float = _phase(0.12 + float(i) * 0.045, 0.22)
	var e: float = _back_out(p) if _closing < 0.0 else _out(p)
	var dim: float = 0.35 if confirm_open and i != 3 else 1.0
	item.position = _entry_home[i] + Vector2(- 520.0 * k * (1.0 - e), 60.0 * k * (1.0 - e))
	item.rotation = -0.55 * (1.0 - _out(p))
	item.modulate.a = clampf(p * 3.0, 0.0, 1.0) * dim


# Une commande reste toujours sélectionnée : celle survolée ou ayant le
# focus, sinon la dernière choisie.
var _selected: int = 0

func _hold_selection() -> void :
	if _closing >= 0.0: return
	for i: int in range(_entries.size()):
		var item: W.NavItem = _entries[i]
		if not confirm_open and item.is_lit_now() and i != _selected:
			_selected = i
			_hint = item.hint
			_hint_time = 0.0
			break
	for i: int in range(_entries.size()):
		_entries[i].set_held(i == _selected)

func _on_hint(text: String) -> void :
	if text.is_empty(): return
	if text != _hint: _hint_time = 0.0
	_hint = text


func _choose(action: String) -> void :
	if _closing >= 0.0 or (confirm_open and action != "quit"): return
	match action:
		"resume":
			Sound.play("confirm")
			ui.call("_pause_resume")
		"settings":
			Sound.play("confirm")
			ui.call("_pause_settings")
		"controls":
			Sound.play("confirm")
			ui.call("_pause_controls")
		"quit":
			Sound.play("click")
			_open_confirm()


# Ferme en sens inverse puis appelle `done` (déjà libéré).
func close_animated(done: Callable = Callable()) -> void :
	if _closing >= 0.0: return
	_close_done = done
	if reduced:
		queue_free()
		if done.is_valid(): done.call()
		return
	_closing = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for item: W.NavItem in _entries:
		item.focus_mode = Control.FOCUS_NONE
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Sound.play("close")


func _input(event: InputEvent) -> void :
	if _closing >= 0.0 or not is_visible_in_tree(): return
	if not confirm_open and (event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up")) and get_viewport().gui_get_focus_owner() == null:
		# Le clavier/la manette repart de la commande sélectionnée.
		_entries[_selected].grab_focus()
	if confirm_open and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause_game")):
		_close_confirm()
		Sound.play("back")
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void :
	if _closing >= 0.0 or not is_visible_in_tree() or confirm_open: return
	if event.is_action_pressed("ui_cancel") and not event.is_action_pressed("pause_game"):
		Sound.play("back")
		ui.call("_pause_resume")
		get_viewport().set_input_as_handled()


# Volet de confirmation : une bande de papier se déplie sous « Quitter ».
func _open_confirm() -> void :
	if confirm_open: return
	confirm_open = true
	if not is_instance_valid(_confirm): _build_confirm()
	_confirm.visible = true
	for item: W.NavItem in _entries:
		item.focus_mode = Control.FOCUS_NONE
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_buttons[0].call_deferred("grab_focus")

func _close_confirm() -> void :
	confirm_open = false
	for item: W.NavItem in _entries:
		item.focus_mode = Control.FOCUS_ALL
		item.mouse_filter = Control.MOUSE_FILTER_STOP
	_entries[3].call_deferred("grab_focus")

func _build_confirm() -> void :
	var k: float = _k()
	_confirm = PanelContainer.new()
	var style: StyleBox = T.sheet_style(30, 22, _red, 77)
	_confirm.add_theme_stylebox_override("panel", style)
	add_child(_confirm)
	var home: Vector2 = _entry_home[3] if _entry_home.size() > 3 else Vector2(80, 600)
	_confirm.position = home + Vector2(70.0 * k, 92.0 * k)
	_confirm.custom_minimum_size = Vector2(560.0 * k, 0)
	_confirm.pivot_offset = Vector2(0, 0)
	_confirm.rotation = -0.04
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_confirm.add_child(v)
	var title: Label = Label.new()
	title.text = "Quitter la manche en cours ?"
	title.add_theme_font_override("font", T.font("display"))
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", T.CREAM)
	v.add_child(title)
	var line: Label = Label.new()
	line.text = "Tu quitteras le salon de tes amis." if networked else "Tu retourneras au menu principal."
	line.add_theme_font_size_override("font_size", 16)
	line.add_theme_color_override("font_color", T.PAPER_DIM)
	v.add_child(line)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	var yes: Button = Button.new()
	yes.text = "OUI, QUITTER"
	yes.theme_type_variation = "DangerButton"
	yes.custom_minimum_size = Vector2(240, 50)
	yes.pressed.connect(func() -> void :
		Sound.play("confirm")
		world.quit_to_menu())
	yes.mouse_entered.connect(Sound.play.bind("hover"))
	row.add_child(yes)
	var no: Button = Button.new()
	no.text = "ANNULER"
	no.custom_minimum_size = Vector2(200, 50)
	no.pressed.connect(func() -> void :
		Sound.play("back")
		_close_confirm())
	no.mouse_entered.connect(Sound.play.bind("hover"))
	row.add_child(no)
	_confirm_buttons = [yes, no]
	yes.focus_neighbor_right = yes.get_path_to(no)
	no.focus_neighbor_left = no.get_path_to(yes)
	for b: Button in _confirm_buttons:
		b.focus_neighbor_top = b.get_path()
		b.focus_neighbor_bottom = b.get_path()
	if PaperLanguage.language == "en": PaperLanguage.apply_tree(_confirm)
	_confirm_t = 0.0
	_confirm.scale = Vector2(1, 0.01)



# ---------- Dessin ----------

func _paint_back(layer: Control) -> void :
	var view: Vector2 = layer.size
	if view.x < 10.0: return
	var k: float = _k()
	var item: RID = layer.get_canvas_item()
	var motion: float = 0.0 if reduced else 1.0
	var t: float = _time
	# Feuille de cahier crème inclinée qui glisse depuis la droite.
	var sheet_p: float = _phase(0.03, 0.24)
	var sheet_x: float = view.x * 0.62 * (1.0 - (_back_out(sheet_p) if _closing < 0.0 else _out(sheet_p)))
	var top_left: Vector2 = Vector2(view.x * 0.5 + sheet_x, -60.0)
	var bottom_left: Vector2 = Vector2(view.x * 0.33 + sheet_x, view.y + 60.0)
	var sheet: PackedVector2Array = G.edge_points(top_left, bottom_left, 9.0 * k, 5, 16.0).duplicate()
	sheet.append(bottom_left)
	sheet.append(Vector2(view.x + 80.0 + sheet_x, view.y + 60.0))
	sheet.append(Vector2(view.x + 80.0 + sheet_x, -60.0))
	G.polygon(item, G.offset(sheet, Vector2(-16, 10) * k), Color(0, 0, 0, 0.45))
	G.polygon(item, sheet, T.CREAM)
	var slope: float = (bottom_left.x - top_left.x) / (bottom_left.y - top_left.y)
	var y: float = 30.0 * k
	while y < view.y:
		var x0: float = top_left.x + (y - top_left.y) * slope + 14.0
		layer.draw_line(Vector2(x0, y), Vector2(view.x, y), Color(0.25, 0.42, 0.7, 0.2), 1.5)
		y += 34.0 * k
	var margin_top: Vector2 = top_left + Vector2(70.0 * k, 0)
	layer.draw_line(margin_top, bottom_left + Vector2(70.0 * k, 0), Color(T.RED, 0.45), 2.5)
	# Grande bande rouge déchirée en diagonale (balaie depuis le bas à gauche).
	var red_p: float = _phase(0.0, 0.2)
	var red_from: Vector2 = Vector2(- view.x * 0.08, view.y * 1.12)
	var red_to: Vector2 = Vector2(view.x * 0.66, - view.y * 0.14)
	var red_tip: Vector2 = red_from.lerp(red_to, _back_out(red_p) if _closing < 0.0 else _out(red_p))
	if red_tip.distance_to(red_from) > 4.0:
		var band: PackedVector2Array = G.band(red_from, red_tip, 470.0 * k, 11, 26.0 * k)
		G.polygon(item, G.offset(band, Vector2(18, 22) * k), Color(0, 0, 0, 0.45))
		G.polygon(item, band, _red.darkened(0.1))
		var lift: Vector2 = (red_to - red_from).normalized().orthogonal()
		# Hachures d'encre rouge foncé dans la bande (texture imprimée).
		for stripe: int in range(-3, 4):
			var off: Vector2 = lift * (float(stripe) * 58.0 * k + fposmod(t * 18.0 * motion, 58.0 * k))
			G.polygon(item, G.quad_band(red_from + off, red_tip + off, 7.0 * k), Color(_red.darkened(0.42), 0.55))
		G.polygon(item, G.band(red_from + lift * 262.0 * k, red_tip + lift * 262.0 * k, 12.0 * k, 17, 4.0), T.CREAM)
	# Bande d'encre derrière la liste (contraste), légèrement décalée.
	var ink_p: float = _phase(0.05, 0.2)
	var ink_from: Vector2 = Vector2(- view.x * 0.1, view.y * 0.98)
	var ink_to: Vector2 = Vector2(view.x * 0.5, - view.y * 0.1)
	var ink_tip: Vector2 = ink_from.lerp(ink_to, _out(ink_p))
	if ink_tip.distance_to(ink_from) > 4.0:
		G.polygon(item, G.band(ink_from, ink_tip, 250.0 * k, 23, 30.0 * k), Color(0.035, 0.03, 0.05, 0.9))
	# Découpe du personnage : silhouette d'encre qui glisse depuis le bord,
	# puis se colore (contour crème de la découpe papier).
	if _art:
		var art_p: float = _phase(0.07, 0.26)
		var color_p: float = _phase(0.2, 0.16)
		var h: float = view.y * (1.16 if _person == "Alice" else 1.08)
		var w: float = h * float(_art.get_width()) / float(_art.get_height())
		var slide: float = view.x * 0.42 * (1.0 - (_back_out(art_p) if _closing < 0.0 else _out(art_p)))
		var bob: float = sin(t * 1.6) * 5.0 * k * motion
		var rect: Rect2 = Rect2(Vector2(view.x * 0.73 - w * 0.5 + slide, view.y * 1.04 - h + bob), Vector2(w, h))
		var center: Vector2 = rect.get_center()
		layer.draw_set_transform(center, -0.05 + 0.04 * (1.0 - art_p), Vector2.ONE)
		var local: Rect2 = Rect2(- rect.size * 0.5, rect.size)
		layer.draw_texture_rect(_art, Rect2(local.position + Vector2(22, 16) * k, local.size), false, Color(0, 0, 0, 0.55 * art_p))
		var tone: Color = Color.BLACK.lerp(Color.WHITE, color_p)
		layer.draw_texture_rect(_art, local, false, Color(tone, clampf(art_p * 3.0, 0.0, 1.0)))
		layer.draw_set_transform(Vector2.ZERO)
	# Ruban de scotch qui défile en haut.
	var ribbon_p: float = _phase(0.1, 0.3)
	var ribbon_from: Vector2 = Vector2(-40.0, 96.0 * k)
	var ribbon_to: Vector2 = Vector2(view.x + 40.0, - 20.0 * k)
	C.draw_ribbon(layer, ribbon_from, ribbon_from.lerp(ribbon_to, _out(ribbon_p)), 34.0 * k, T.tr_text("LA CLOCHE ATTEND") + "   ·   PAUSE", t * 60.0 * motion, Color(T.INK, 0.85), Color(T.CREAM, 0.85), 5)
	# Bouts de papier qui volent lentement.
	if not reduced:
		for i: int in range(_scraps.size()):
			var s: Vector3 = _scraps[i]
			var px: float = fposmod(s.x * view.x + t * (30.0 + s.z * 40.0), view.x + 80.0) - 40.0
			var py: float = fposmod(s.y * view.y + t * (14.0 + s.z * 20.0), view.y + 60.0) - 30.0
			var scrap: Rect2 = Rect2(Vector2(-9, -6) * (0.6 + s.z), Vector2(18, 12) * (0.6 + s.z))
			var xform: Transform2D = Transform2D(t * (0.6 + s.z) + float(i), Vector2(px, py))
			G.polygon(item, G.transformed(G.cut(scrap, i * 7 + 3, 0.2), xform), Color(T.CREAM if i % 3 else _red, 0.55 * _open_amount()))


func _paint_front(layer: Control) -> void :
	var view: Vector2 = layer.size
	if view.x < 10.0: return
	var k: float = _k()
	var item: RID = layer.get_canvas_item()
	var t: float = _time
	var motion: float = 0.0 if reduced else 1.0
	# « PAUSE » géant en lettres découpées, plaqué en bas à gauche.
	var giant_p: float = _phase(0.2, 0.16)
	if giant_p > 0.0:
		var px: float = 150.0 * k
		var word: String = "PAUSE"
		var seed_value: int = 77
		var scale: float = lerpf(1.7, 1.0, _out(giant_p))
		var drift: float = sin(t * 0.9) * 6.0 * k * motion
		var at: Vector2 = Vector2(view.x * 0.04 + drift, view.y * 0.955)
		var base: Transform2D = Transform2D(-0.14, Vector2(scale, scale), 0.0, at)
		C.draw_word(layer, word, base, px, seed_value, 0.0, _red, clampf(giant_p * 2.0, 0.0, 1.0), 0, false, T.CREAM, _red)
	# Étiquette « MENU · PAUSE » + chrono, scotchée en haut à droite.
	var tag_p: float = _phase(0.22, 0.18)
	if tag_p > 0.0:
		var tag_pos: Vector2 = Vector2(view.x - 400.0 * k, 46.0 * k + (1.0 - _out(tag_p)) * -140.0 * k)
		var xform: Transform2D = Transform2D(0.05, tag_pos)
		var tag: PackedVector2Array = G.cut(Rect2(Vector2.ZERO, Vector2(360, 122) * k), 41, 0.08)
		G.polygon(item, G.transformed(G.offset(tag, Vector2(8, 10) * k), xform), Color(0, 0, 0, 0.5))
		G.polygon(item, G.transformed(tag, xform), Color(0.04, 0.035, 0.055))
		layer.draw_set_transform_matrix(xform)
		var caps: Font = T.font("caps_wide")
		layer.draw_string(caps, Vector2(18, 30) * k, T.tr_text("MENU · PAUSE") if not networked else T.tr_text("LA MANCHE CONTINUE"), HORIZONTAL_ALIGNMENT_LEFT, 250.0 * k, int(15 * k), _accent.lerp(T.CREAM, 0.3))
		var digits: Font = T.font("digits")
		var clock: String = _clock_text()
		layer.draw_string(digits, Vector2(16, 104) * k, clock, HORIZONTAL_ALIGNMENT_LEFT, -1, int(76 * k), T.CREAM)
		var map_name: String = T.tr_text(str(world.MAP_NAMES.get(world.selected_map, ""))).to_upper()
		var clock_w: float = digits.get_string_size(clock, HORIZONTAL_ALIGNMENT_LEFT, -1, int(76 * k)).x
		var side_x: float = 16.0 * k + clock_w + 14.0 * k
		layer.draw_string(T.font("caps"), Vector2(side_x, 70.0 * k), _person.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 340.0 * k - side_x, int(16 * k), _accent)
		layer.draw_string(T.font("caps"), Vector2(side_x, 94.0 * k), map_name, HORIZONTAL_ALIGNMENT_LEFT, 344.0 * k - side_x, int(11 * k), Color(T.CREAM, 0.6))
		layer.draw_set_transform(Vector2.ZERO)
		T.draw_tape(item, tag_pos + Vector2(180, 0) * k, 90.0 * k, -0.06, Color(0.96, 0.93, 0.84, 0.6), 7)
	# Bande d'aide : description de la commande sélectionnée.
	var hint_p: float = _phase(0.26, 0.16)
	if hint_p > 0.0 and not _hint.is_empty():
		var shown: String = T.tr_text(_hint)
		var font: Font = T.font("semibold")
		var fs: int = int(19 * k)
		var width: float = minf(font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x, view.x * 0.42)
		var pop: float = 1.0 if reduced else _out(clampf(_hint_time / 0.14, 0.0, 1.0))
		var at: Vector2 = Vector2(view.x * 0.06 + (1.0 - _out(hint_p)) * -400.0 * k, view.y * 0.755)
		var band: Rect2 = Rect2(at + Vector2(-16, -30) * k, Vector2((width + 44.0 * k) * pop, 44.0 * k))
		var shape: PackedVector2Array = G.strip(band, 12.0 * k, 2.0, 1.5, 3 + (G.boil_frame if not reduced else 0))
		G.polygon(item, G.offset(shape, Vector2(6, 6) * k), Color(0, 0, 0, 0.6))
		G.polygon(item, shape, T.CREAM)
		if pop > 0.6: layer.draw_string(font, at, shown, HORIZONTAL_ALIGNMENT_LEFT, view.x * 0.42, fs, T.INK_TEXT)
	# Touches (bas à droite).
	var keys_p: float = _phase(0.3, 0.14)
	if keys_p > 0.0 and not world.mobile_mode:
		var specs: Array = [[ui.key_label("pause_game", "Échap"), "Reprendre"], [ui.key_label("ui_accept", "Entrée"), "Valider"], ["↑ ↓", "Choisir"]]
		var x: float = view.x - 40.0 * k
		var yk: float = view.y - 34.0 * k + (1.0 - _out(keys_p)) * 80.0 * k
		var label_font: Font = T.font("caps")
		var key_font: Font = T.font("semibold")
		# Bandeau d'encre derrière les touches (lisible sur la découpe).
		var bar: PackedVector2Array = G.strip(Rect2(Vector2(view.x - 520.0 * k, yk - 30.0 * k), Vector2(540.0 * k, 44.0 * k)), 14.0 * k, 1.5, 1.5, 61)
		G.polygon(item, G.offset(bar, Vector2(-6, 5) * k), Color(_red, 0.9))
		G.polygon(item, bar, Color(0.03, 0.028, 0.045, 0.96))
		for i: int in range(specs.size() - 1, -1, -1):
			var spec: Array = specs[i]
			var label: String = T.tr_text(str(spec[1])).to_upper()
			var lw: float = label_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * k)).x
			x -= lw
			layer.draw_string(label_font, Vector2(x, yk), label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * k), T.CREAM)
			var key: String = str(spec[0])
			var kw: float = key_font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * k)).x + 16.0 * k
			x -= kw + 8.0 * k
			var chip: PackedVector2Array = G.strip(Rect2(Vector2(x, yk - 20.0 * k), Vector2(kw, 27.0 * k)), 5.0, 1.0, 1.0, i * 9 + 1)
			G.polygon(item, G.offset(chip, Vector2(2, 3)), Color(0, 0, 0, 0.6))
			G.polygon(item, chip, T.CREAM)
			layer.draw_string(key_font, Vector2(x + 8.0 * k, yk), key, HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * k), T.INK_TEXT)
			x -= 26.0 * k


func _clock_text() -> String:
	if bool(world.get("training")): return T.tr_text("ESSAI")
	var left: float = maxf(0.0, float(world.get("time_left")))
	return "%02d:%02d" % [int(left) / 60, int(left) % 60]
