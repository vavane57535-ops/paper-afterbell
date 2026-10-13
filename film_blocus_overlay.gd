class_name PaperBlocusOverlay
extends Control

# Couche 2D « montage amateur » du film du blocus : WordArt arc-en-ciel, sous-titres jaunes,
# caméscope (REC + horodatage), fondu raté, parasites VHS, doigt devant l'objectif,
# transition étoile et carton de fin avec faute de frappe.
# Tout est calculé à partir du temps du film (update(t)) pour que la cinémathèque puisse
# revenir en arrière ou sauter n'importe où.

const T = preload("res://ui_theme.gd")

const CAPTION_YELLOW: Color = Color("ffe14d")
const REC_RED: Color = Color("ff3142")


class WordArt extends Control:
	var letters: Array[Label] = []
	var origin_x: Array[float] = []
	var widths: Array[float] = []
	var width: float = 0.0
	var height: float = 0.0
	var ascent: float = 0.0
	var base_color: Color = Color.WHITE

	func build(text: String, font: Font, font_size: int, outline: int, color: Color, shadow: Color) -> void :
		for child: Node in get_children(): child.queue_free()
		letters.clear();origin_x.clear();widths.clear()
		base_color = color
		var x: float = 0.0
		for i: int in range(text.length()):
			var ch: String = text[i]
			var w: float = font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var label: Label = Label.new()
			label.text = ch
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.add_theme_font_override("font", font)
			label.add_theme_font_size_override("font_size", font_size)
			label.add_theme_color_override("font_color", color)
			label.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.1))
			label.add_theme_constant_override("outline_size", outline)
			label.add_theme_color_override("font_shadow_color", shadow)
			label.add_theme_constant_override("shadow_offset_x", maxi(3, font_size / 18))
			label.add_theme_constant_override("shadow_offset_y", maxi(3, font_size / 14))
			label.add_theme_constant_override("shadow_outline_size", outline)
			label.position = Vector2(x, 0.0)
			add_child(label)
			letters.append(label);origin_x.append(x);widths.append(w)
			x += w
		width = x
		height = font.get_height(font_size)
		ascent = font.get_ascent(font_size)
		custom_minimum_size = Vector2(width, height)
		size = Vector2(width, height)
		pivot_offset = size * 0.5
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func animate(t: float, rainbow: bool, wobble: float) -> void :
		for i: int in range(letters.size()):
			var label: Label = letters[i]
			label.position = Vector2(origin_x[i], sin(t * 5.5 + float(i) * 0.85) * wobble)
			if rainbow: label.add_theme_color_override("font_color", Color.from_hsv(fposmod(t * 0.45 + float(i) * 0.075, 1.0), 0.78, 1.0))

	func place(center: Vector2) -> void :
		position = center - size * 0.5

	# Rectangle (local) couvrant les lettres [from, to).
	func span(from: int, to: int) -> Rect2:
		from = clampi(from, 0, origin_x.size() - 1);to = clampi(to, from + 1, origin_x.size())
		return Rect2(origin_x[from], 0.0, origin_x[to - 1] + widths[to - 1] - origin_x[from], height)


var world: Node
var film_duration: float = 38.0
var in_game: bool = false
# Option « réduire les flashs » (ou animations réduites) : parasites fixes, REC sans clignoter.
var calm: bool = false
var _now: float = 0.0

var _captions: Array = []
var _cuts: Array[float] = []
var _noise: Array = []
var _fails: Array = []
var _fingers: Array = []
var _cards: Array = []

var _caption_box: VBoxContainer
var _speaker: Label
var _line: Label
var _rec: Label
var _stamp: Label
var _camera_tag: Label
var _bars: Array[ColorRect] = []
var _fail_black: ColorRect
var _fail_text: Label
var _finger: TextureRect
var _star: Polygon2D
var _star_rim: Line2D
var _end_bg: TextureRect
var _skip: Button
var _arts: Dictionary = {}
var _marks: Dictionary = {}


func setup(owner: Node, duration: float) -> void :
	world = owner;film_duration = duration
	name = "BlocusOverlay"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	in_game = str(world.get("phase")) == "ending"
	var options: Variant = world.get("options")
	var ui: Variant = world.get("ui")
	calm = (options is Dictionary and bool(options.get("reduce_flashes", false))) or (is_instance_valid(ui) and bool(ui.get("reduced_motion")))
	_build()


func _t(text: String) -> String:
	return PaperLanguage.t(text)


func _plain(text: String, font_kind: String, font_size: int, color: Color, outline: int = 0) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", T.font(font_kind))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if outline > 0:
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", outline)
	return label


func _build() -> void :
	# Caméscope : REC qui clignote, nom du « caméraman », horodatage.
	_rec = _plain("● REC", "caps", 30, REC_RED, 6)
	add_child(_rec)
	_camera_tag = _plain(_t("CAMÉSCOPE DU FOYER DES ÉLÈVES"), "caps", 18, Color(1, 1, 1, 0.85), 5)
	add_child(_camera_tag)
	_stamp = _plain("", "digits", 34, Color(1, 1, 1, 0.9), 6)
	add_child(_stamp)

	# Sous-titres « DVD des années 2000 » : jaune, gros contour noir.
	_caption_box = VBoxContainer.new()
	_caption_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption_box.alignment = BoxContainer.ALIGNMENT_END
	_caption_box.add_theme_constant_override("separation", -4)
	add_child(_caption_box)
	_speaker = _plain("", "caps", 20, Color("f6f1ff"), 6)
	_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption_box.add_child(_speaker)
	_line = _plain("", "title", 36, CAPTION_YELLOW, 11)
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption_box.add_child(_line)

	# Parasites VHS.
	for i: int in range(7):
		var bar: ColorRect = ColorRect.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.color = Color(1, 1, 1, 0.0)
		add_child(bar)
		_bars.append(bar)

	# Le doigt du caméraman devant l'objectif.
	_finger = TextureRect.new()
	_finger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	gradient.colors = PackedColorArray([Color(0.86, 0.62, 0.56, 0.97), Color(0.8, 0.52, 0.48, 0.9), Color(0.75, 0.45, 0.42, 0.0)])
	var radial: GradientTexture2D = GradientTexture2D.new()
	radial.gradient = gradient;radial.fill = GradientTexture2D.FILL_RADIAL
	radial.fill_from = Vector2(0.5, 0.5);radial.fill_to = Vector2(0.5, 0.0)
	radial.width = 256;radial.height = 256
	_finger.texture = radial
	_finger.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_finger.stretch_mode = TextureRect.STRETCH_SCALE
	_finger.visible = false
	add_child(_finger)

	# Fondu raté.
	_fail_black = ColorRect.new()
	_fail_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fail_black.color = Color(0, 0, 0, 0)
	add_child(_fail_black)
	_fail_text = _plain("", "medium", 22, Color(1, 1, 1, 0.75))
	add_child(_fail_text)

	# Fond de carton de fin « fond d'écran 1998 ».
	_end_bg = TextureRect.new()
	_end_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sky: Gradient = Gradient.new()
	sky.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	sky.colors = PackedColorArray([Color("3a1c71"), Color("d76d77"), Color("ffaf7b")])
	var linear: GradientTexture2D = GradientTexture2D.new()
	linear.gradient = sky;linear.fill_from = Vector2(0, 0);linear.fill_to = Vector2(1, 1)
	_end_bg.texture = linear
	_end_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_end_bg.stretch_mode = TextureRect.STRETCH_SCALE
	_end_bg.visible = false
	add_child(_end_bg)

	# Transition étoile.
	_star = Polygon2D.new()
	var points: PackedVector2Array = []
	for k: int in range(10):
		var radius: float = 1.0 if k % 2 == 0 else 0.45
		var angle: float = - PI * 0.5 + TAU * float(k) / 10.0
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	_star.polygon = points
	_star.color = Color("ff4fb8")
	_star.visible = false
	add_child(_star)
	_star_rim = Line2D.new()
	var closed: PackedVector2Array = points.duplicate();closed.append(points[0])
	_star_rim.points = closed
	_star_rim.width = 0.06
	_star_rim.default_color = Color("ffe14d")
	_star.add_child(_star_rim)

	if in_game:
		_skip = Button.new()
		_skip.text = _t("PASSER LE BLOCUS  ▸▸")
		_skip.focus_mode = Control.FOCUS_NONE
		_skip.add_theme_font_override("font", T.font("caps"))
		_skip.add_theme_font_size_override("font_size", 16)
		_skip.pressed.connect(skip)
		add_child(_skip)


# ---------------------------------------------------------------- timeline

func caption(t0: float, t1: float, speaker: String, text: String) -> void :
	_captions.append([t0, t1, speaker, text])

func cut(t: float, noise: float = 0.18) -> void :
	_cuts.append(t)
	if noise > 0.0: _noise.append([t - 0.02, t + noise])

func noise(t0: float, t1: float) -> void :
	_noise.append([t0, t1])

func failed_fade(t0: float, t1: float) -> void :
	_fails.append([t0, t1])

func finger(t0: float, t1: float) -> void :
	_fingers.append([t0, t1])

# Cartons WordArt : id, début, fin, texte, taille, centre relatif (0..1), style.
func card(id: String, t0: float, t1: float, text: String, font_size: int, at: Vector2, style: Dictionary = {}) -> void :
	var art: WordArt = WordArt.new()
	var font_kind: String = str(style.get("font", "display"))
	art.build(text, T.font(font_kind), font_size, int(style.get("outline", maxi(8, font_size / 7))), style.get("color", Color.WHITE), style.get("shadow", Color("4b1d6e")))
	art.visible = false
	add_child(art)
	_arts[id] = art
	_cards.append({"id": id, "t0": t0, "t1": t1, "at": at, "style": style})

# Correction au feutre rouge : rature des lettres [from, to) d'un carton et réécriture au-dessus.
func correction(card_id: String, t0: float, from: int, to: int, fix: String) -> void :
	var strike: Line2D = Line2D.new()
	strike.width = 9.0
	strike.default_color = Color("e01b2f")
	strike.visible = false
	add_child(strike)
	# Contour papier : la correction reste lisible même sur l'enseigne rouge de l'école.
	var hand: Label = _plain(fix, "hand", 78, Color("e01b2f"), 0)
	hand.add_theme_color_override("font_outline_color", Color("fbf4e4"))
	hand.add_theme_constant_override("outline_size", 14)
	hand.visible = false
	add_child(hand)
	var caret: Label = _plain("^", "hand", 70, Color("e01b2f"), 0)
	caret.add_theme_color_override("font_outline_color", Color("fbf4e4"))
	caret.add_theme_constant_override("outline_size", 12)
	caret.visible = false
	add_child(caret)
	_marks[card_id + str(from)] = {"card": card_id, "t0": t0, "from": from, "to": to, "strike": strike, "hand": hand, "caret": caret}

func star_wipe(t0: float, t1: float) -> void :
	_cards.append({"id": "_star", "t0": t0, "t1": t1})

func end_background(t0: float) -> void :
	_cards.append({"id": "_end", "t0": t0, "t1": INF})


# ---------------------------------------------------------------- rendu

func update(t: float) -> void :
	_now = t
	var view: Vector2 = get_viewport_rect().size
	_vhs(t, view)
	_subtitles(t, view)
	_noise_bars(t, view)
	_finger_blob(t, view)
	_failed(t, view)
	_end_card(t, view)
	_wordart(t, view)
	_star_frame(t, view)
	if _skip:
		_skip.visible = t < film_duration - 0.6
		var mobile: bool = bool(world.get("mobile_mode")) if is_instance_valid(world) else false
		_skip.size = Vector2(300, 56) if mobile else Vector2(250, 40)
		_skip.position = Vector2(view.x - _skip.size.x - 40, view.y - _skip.size.y - 32)


func _vhs(t: float, view: Vector2) -> void :
	var ended: bool = _ending_from() <= t
	_rec.visible = not ended and (calm or fmod(t, 1.0) < 0.62)
	_rec.position = Vector2(48, 112)
	_camera_tag.visible = not ended
	_camera_tag.position = Vector2(view.x - _camera_tag.get_minimum_size().x - 48, 118)
	_stamp.visible = not ended
	var seconds: int = 7 + int(t)
	_stamp.text = "▶ 16:47:%02d   %s" % [seconds % 60, _t("VEN. 13 OCT.")]
	_stamp.position = Vector2(48, view.y - 98 - 58)


func _subtitles(t: float, view: Vector2) -> void :
	var active: Array = []
	for row: Array in _captions:
		if t >= float(row[0]) and t < float(row[1]): active = row
	_caption_box.visible = not active.is_empty()
	if active.is_empty(): return
	var speaker: String = str(active[2])
	_speaker.text = _t(speaker).to_upper() if not speaker.is_empty() else ""
	_speaker.visible = not speaker.is_empty()
	_line.text = _t(str(active[3]))
	var width: float = minf(view.x - 160.0, 1100.0)
	_caption_box.size = Vector2(width, 0)
	# Cinémathèque (hors partie) : la barre de transport couvre le bas de l'écran, les sous-titres passent au-dessus.
	var lift: float = 0.0 if in_game else 70.0
	_caption_box.position = Vector2((view.x - width) * 0.5, view.y - 98.0 - _caption_box.get_combined_minimum_size().y + 30.0 - lift)


func _hash(value: int) -> float:
	var x: int = (value * 1103515245 + 12345) & 0x7fffffff
	x = (x ^ (x >> 13)) * 1274126177 & 0x7fffffff
	return float(x % 10000) / 10000.0


func _noise_bars(t: float, view: Vector2) -> void :
	var on: bool = false
	for window: Array in _noise:
		if t >= float(window[0]) and t < float(window[1]): on = true
	# En mode calme, les parasites ne scintillent pas : mêmes bandes pendant toute la coupe.
	var frame: int = int(t * 24.0)
	if calm:
		for window: Array in _noise:
			if t >= float(window[0]) and t < float(window[1]): frame = int(float(window[0]) * 24.0)
	for i: int in range(_bars.size()):
		var bar: ColorRect = _bars[i]
		bar.visible = on
		if not on: continue
		var h: float = 3.0 + 16.0 * _hash(frame * 31 + i * 7)
		bar.size = Vector2(view.x, h)
		bar.position = Vector2(0, 98.0 + (view.y - 196.0) * _hash(frame * 17 + i * 13))
		bar.color = Color(1, 1, 1, (0.08 + 0.12 * _hash(frame * 5 + i)) if calm else (0.18 + 0.4 * _hash(frame * 5 + i)))


func _finger_blob(t: float, view: Vector2) -> void :
	var shown: bool = false
	var age: float = 0.0
	for window: Array in _fingers:
		if t >= float(window[0]) and t < float(window[1]): shown = true;age = t - float(window[0])
	_finger.visible = shown
	if not shown: return
	var wobble: Vector2 = Vector2(sin(age * 1.7) * 18.0, cos(age * 1.3) * 14.0)
	_finger.size = Vector2(view.y * 0.62, view.y * 0.86)
	_finger.position = Vector2(view.x - view.y * 0.36, 40.0) + wobble
	_finger.rotation = -0.35


func _failed(t: float, view: Vector2) -> void :
	var alpha: float = 0.0
	var text: String = ""
	for window: Array in _fails:
		var t0: float = float(window[0])
		var t1: float = float(window[1])
		if t < t0 or t >= t1: continue
		# Le fondu descend… s'arrête à 88 %, hésite, puis l'image revient d'un coup.
		alpha = smoothstep(t0, t0 + 0.6, t) * 0.88
		if t > t0 + 0.6:
			alpha = 0.88 + 0.06 * sin((t - t0) * 40.0)
			text = _t("fondu en cours") + ".".repeat(1 + int((t - t0) * 4.0) % 3)
	_fail_black.color.a = alpha
	_fail_black.size = view
	_fail_text.visible = not text.is_empty()
	_fail_text.text = text
	_fail_text.position = Vector2(view.x * 0.5 - 90, view.y * 0.5 - 14)


func _ending_from() -> float:
	for row: Dictionary in _cards:
		if row.id == "_end": return float(row.t0)
	return INF


func _end_card(t: float, view: Vector2) -> void :
	var from: float = _ending_from()
	_end_bg.visible = t >= from
	_end_bg.size = view
	_end_bg.position = Vector2.ZERO


func _star_frame(t: float, view: Vector2) -> void :
	_star.visible = false
	for row: Dictionary in _cards:
		if row.id != "_star": continue
		var t0: float = float(row.t0)
		var t1: float = float(row.t1)
		if t < t0 or t >= t1: continue
		var u: float = (t - t0) / maxf(0.01, t1 - t0)
		# Grandit, tourne, recouvre l'écran… puis rapetisse en tournant dans l'autre sens.
		var grow: float = smoothstep(0.0, 0.5, u) if u < 0.5 else 1.0 - smoothstep(0.5, 1.0, u)
		_star.visible = true
		_star.position = view * 0.5
		_star.rotation = u * 5.0
		_star.scale = Vector2.ONE * (8.0 + grow * view.length() * 1.15)
		_star.color = Color("ff4fb8") if calm else Color.from_hsv(fposmod(u * 1.5, 1.0), 0.7, 1.0)


func _wordart(t: float, view: Vector2) -> void :
	for row: Dictionary in _cards:
		var id: String = str(row.id)
		if id.begins_with("_"): continue
		var art: WordArt = _arts[id]
		var t0: float = float(row.t0)
		var t1: float = float(row.t1)
		var style: Dictionary = row.style
		art.visible = t >= t0 and t < t1
		if not art.visible: continue
		var age: float = t - t0
		var left: float = t1 - t
		var spin_in: float = float(style.get("spin", 0.0))
		var scale_value: float = 1.0
		var angle: float = deg_to_rad(float(style.get("tilt", 0.0)))
		if spin_in > 0.0 and age < spin_in:
			# Entrée « tourbillon » de logiciel de présentation.
			var u: float = age / spin_in
			scale_value = u * u * (3.0 - 2.0 * u)
			angle += (1.0 - u) * TAU * 2.0
		if bool(style.get("fly_out", false)) and left < 0.45:
			var v: float = 1.0 - left / 0.45
			scale_value *= 1.0 + v * 2.5
			art.modulate.a = 1.0 - v
		else: art.modulate.a = 1.0
		if style.has("pulse"): scale_value *= 1.0 + 0.06 * sin(age * TAU * float(style.pulse))
		art.scale = Vector2.ONE * scale_value
		art.rotation = angle
		art.place(view * (row.at as Vector2))
		art.animate(t, bool(style.get("rainbow", false)), float(style.get("wobble", 0.0)))
	for key: Variant in _marks:
		var mark: Dictionary = _marks[key]
		var art: WordArt = _arts.get(str(mark.card))
		var strike: Line2D = mark.strike
		var hand: Label = mark.hand
		var caret: Label = mark.caret
		var shown: bool = art != null and art.visible and t >= float(mark.t0)
		strike.visible = shown;hand.visible = shown;caret.visible = shown
		if not shown: continue
		var rect: Rect2 = art.span(int(mark.from), int(mark.to))
		var origin: Vector2 = art.position
		var draw: float = clampf((t - float(mark.t0)) / 0.35, 0.0, 1.0)
		var y: float = origin.y + rect.position.y + rect.size.y * 0.55
		var x0: float = origin.x + rect.position.x - 10.0
		var x1: float = origin.x + rect.position.x + rect.size.x + 10.0
		strike.points = PackedVector2Array([Vector2(x0, y + 6), Vector2(lerpf(x0, x1, draw), y - 8)])
		hand.modulate.a = clampf((t - float(mark.t0) - 0.35) / 0.2, 0.0, 1.0)
		caret.modulate.a = hand.modulate.a
		hand.position = Vector2(origin.x + rect.position.x + rect.size.x * 0.5 - hand.get_minimum_size().x * 0.5, origin.y - 70.0)
		hand.rotation = -0.08
		# Le « ^ » d'insertion juste sous la ligne de base des lettres raturées.
		caret.position = Vector2(origin.x + rect.position.x + rect.size.x * 0.5 - caret.get_minimum_size().x * 0.5, origin.y + art.ascent - caret.get_minimum_size().y * 0.28)


func skip() -> void :
	if not is_instance_valid(world) or str(world.get("phase")) != "ending": return
	var cinema: Variant = world.get("film")
	if cinema == null: return
	world.set("cinema", maxf(float(world.get("cinema")), float(cinema.duration)))


func _unhandled_input(event: InputEvent) -> void :
	if not in_game or not is_visible_in_tree(): return
	# Les premières secondes, on ignore les touches : un saut ou une capacité pressés au moment
	# où Alice quitte ne doivent pas faire sauter tout le film.
	if _now < 1.5: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		skip()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_A, JOY_BUTTON_START]:
		skip()
		get_viewport().set_input_as_handled()
