extends Control





const T = preload("res://ui_theme.gd")
const W = preload("res://ui_widgets.gd")
const Icons = preload("res://ui_icons.gd")
const HpOvercap = preload("res://ui_hp_overcap.gd")


const SHORT: Dictionary = {
	"Ashura": ["DRONE", "ROLLERS", "MODE", ""], 
	"Usayuko": ["SAISIR", "BLOQUER", "FRAPPER", "DROPKICK"], 
	"Simon": ["FLASHBANG", "COURSE", "MODE", ""], 
	"Lysia": ["SURCHAUFFE", "REPOUSSER", "VISION X", "PRISE"], 
	"Elly": ["SOIN", "ZONE", "", "FUSIL"], 
	"Bleuette": ["ENCOURAGER", "RECHARGER", "CHOCOLAT", "COURAGE"], 
	"Alice": ["GRIFFES", "RÉVÉLER", "PIQUES", "OMBRES", "DOUBLES", "TRUE FORM"], 
}

var ui: Node
var world: Node
var announce_time: float = 0.0
var announce_total: float = 3.0

var halo: TextureRect
var top_box: VBoxContainer
var timer_label: Label
var objective_panel: PanelContainer
var objective_icon: TextureRect
var objective_label: Label
var music_row: HBoxContainer
var music_label: Label
var true_form_panel: PanelContainer
var true_form_label: Label
var true_form_meter: W.Meter

var room_row: HBoxContainer
var room_label: Label
var roster: PaperSurvivorRoster

var card: PanelContainer
var portrait: PaperStatusIcon
var name_label: Label
var role_label: Label
var hp_label: Label
var hp_unit: Label
var hp_meter: W.Meter
var hp_overcap: HpOvercap
var aura_row: HBoxContainer
var aura_label: Label
var aura_state: Label
var aura_meter: W.Meter
var tf_row: HBoxContainer
var tf_label: Label
var tf_meter: W.Meter
var _card_character: String = ""

var ability_bar: HBoxContainer
var slots: Array = []
var _peaks: Array[float] = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
var _last_cd: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _keys: Array[String] = ["1", "2", "3", "4", "5", "6"]
var _key_clock: float = 0.0
var _skill_cache: Dictionary = {}

var prompt_panel: PanelContainer
var prompt: Label
var archive_panel: PanelContainer
var archive_caps: Array = []
var archive_meter: W.Meter
var archive_hint: Label
var hints_box: HBoxContainer
var hint_caps: Dictionary = {}
var hint_labels: Dictionary = {}
var spectator_panel: PanelContainer
var spectator_label: Label
var spectator_name: Label
var reticle: Control

var drone_frame: Control
var drone_label: Label
var intro_top: ColorRect
var intro_bottom: ColorRect
var title_label: Label
var subtitle_label: Label


class DroneCorners extends Control:
	func _draw() -> void :
		var color: Color = Color("a9d9d4")
		var inset: Vector2 = Vector2(size.x * 0.07, size.y * 0.14)
		var corners: Array[Vector2] = [inset, Vector2(size.x - inset.x, inset.y), Vector2(inset.x, size.y - inset.y * 1.2), Vector2(size.x - inset.x, size.y - inset.y * 1.2)]
		for corner: Vector2 in corners:
			var dx: float = 34.0 if corner.x < size.x * 0.5 else -34.0
			var dy: float = 26.0 if corner.y < size.y * 0.5 else -26.0
			draw_line(corner, corner + Vector2(dx, 0), color, 3.0)
			draw_line(corner, corner + Vector2(0, dy), color, 3.0)
		var center: Vector2 = size * 0.5
		draw_arc(center, 22, 0, TAU, 32, Color(color, 0.5), 1.5, true)
		draw_line(center + Vector2(-34, 0), center + Vector2(-12, 0), Color(color, 0.7), 1.5)
		draw_line(center + Vector2(12, 0), center + Vector2(34, 0), Color(color, 0.7), 1.5)


class Reticle extends Control:
	func _draw() -> void :
		var center: Vector2 = size * 0.5
		draw_circle(center, 2.6, Color(0, 0, 0, 0.45))
		draw_circle(center, 1.7, Color(1, 1, 1, 0.85))


func setup(owner_ui: Node) -> void :
	ui = owner_ui
	world = ui.world
	name = "HUD"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	set_meta("language_user_text", true)
	_build_top()
	_build_roster()
	_build_card()
	_build_abilities()
	_build_prompt()
	_build_archive()
	_build_hints()
	_build_spectator()
	_build_drone()
	_build_intro()




func _t(text: String) -> String:
	return PaperLanguage.t(text) if PaperLanguage.language == "en" else text

func _label(text: String, font_kind: String, size_px: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_override("font", T.font(font_kind))
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _shadow(label: Label, alpha: float = 0.6) -> void :
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, alpha))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("shadow_outline_size", 6)

func _write(label: Label, text: String) -> void :
	if label.text != text: label.text = text

func _color(label: Label, color: Color) -> void :
	if label.get_theme_color("font_color") != color: label.add_theme_color_override("font_color", color)

func _pill(bg: Color, border: Color, margin_h: float = 14, margin_v: float = 5) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = T.box(bg, border, 1, 14, margin_h, margin_v)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel

func _icon(name_value: String, size_px: float, tint: Color) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.texture = Icons.icon(name_value)
	rect.custom_minimum_size = Vector2(size_px, size_px)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.modulate = tint
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

func _meter(color: Color, height: float) -> W.Meter:
	var meter: W.Meter = W.Meter.new()
	meter.color = color
	meter.custom_minimum_size = Vector2(0, height)
	meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return meter




func _build_top() -> void :


	halo = TextureRect.new()
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(0.02, 0.025, 0.04, 0.62))
	gradient.set_color(1, Color(0.02, 0.025, 0.04, 0.0))
	gradient.add_point(0.55, Color(0.02, 0.025, 0.04, 0.3))
	var radial: GradientTexture2D = GradientTexture2D.new()
	radial.gradient = gradient
	radial.fill = GradientTexture2D.FILL_RADIAL
	radial.fill_from = Vector2(0.5, 0.18)
	radial.fill_to = Vector2(0.5, 1.0)
	radial.width = 128
	radial.height = 64
	halo.texture = radial
	halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	halo.stretch_mode = TextureRect.STRETCH_SCALE
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(halo)
	halo.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	halo.offset_left = -470
	halo.offset_right = 470
	halo.offset_top = -40
	halo.offset_bottom = 190
	top_box = VBoxContainer.new()
	top_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_box.add_theme_constant_override("separation", 4)
	add_child(top_box)
	top_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top_box.offset_left = -380
	top_box.offset_right = 380
	top_box.offset_top = 8
	top_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	timer_label = _label("05:20", "digits", 66, T.PAPER)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shadow(timer_label, 0.55)
	top_box.add_child(timer_label)
	objective_panel = _pill(Color(0.03, 0.04, 0.065, 0.78), Color(T.TEAL, 0.35), 14, 4)
	objective_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top_box.add_child(objective_panel)
	var objective_row: HBoxContainer = HBoxContainer.new()
	objective_row.add_theme_constant_override("separation", 8)
	objective_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_panel.add_child(objective_row)
	objective_icon = _icon("exit", 16, T.TEAL)
	objective_row.add_child(objective_icon)
	objective_label = _label("", "caps", 15, T.TEAL)
	objective_row.add_child(objective_label)
	music_row = HBoxContainer.new()
	music_row.alignment = BoxContainer.ALIGNMENT_CENTER
	music_row.add_theme_constant_override("separation", 6)
	music_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_box.add_child(music_row)
	music_row.add_child(_icon("music", 14, T.PAPER_DIM))
	music_label = _label("", "medium", 15, T.PAPER_DIM)
	_shadow(music_label, 0.5)
	music_row.add_child(music_label)
	true_form_panel = _pill(Color(0.18, 0.02, 0.06, 0.86), Color(T.RED, 0.8), 16, 6)
	true_form_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top_box.add_child(true_form_panel)
	var true_box: VBoxContainer = VBoxContainer.new()
	true_box.add_theme_constant_override("separation", 4)
	true_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	true_form_panel.add_child(true_box)
	true_form_label = _label("", "caps", 15, Color("ffd9df"))
	true_form_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	true_box.add_child(true_form_label)
	true_form_meter = _meter(T.RED, 3)
	true_form_meter.custom_minimum_size.x = 280
	true_box.add_child(true_form_meter)
	true_form_panel.hide()
	music_row.hide()

func _build_roster() -> void :
	room_row = HBoxContainer.new()
	room_row.add_theme_constant_override("separation", 8)
	room_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(room_row)
	room_row.position = Vector2(28, 20)
	var marker: ColorRect = ColorRect.new()
	marker.color = T.TEAL
	marker.custom_minimum_size = Vector2(3, 14)
	marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room_row.add_child(marker)
	room_label = _label("", "caps", 13, T.PAPER_DIM)
	_shadow(room_label, 0.6)
	room_row.add_child(room_label)
	roster = PaperSurvivorRoster.new()
	add_child(roster)
	roster.position = Vector2(24, 48)
	roster.setup(world)

func _build_card() -> void :
	card = PanelContainer.new()
	var style: StyleBoxFlat = T.box(Color(0.06, 0.072, 0.105, 0.9), Color(1, 1, 1, 0.07), 1, 8, 14, 12)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 14
	card.add_theme_stylebox_override("panel", style)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	card.anchor_left = 0
	card.anchor_right = 0
	card.anchor_top = 1
	card.anchor_bottom = 1
	card.offset_left = 24
	card.offset_right = 24 + 352
	card.offset_bottom = -22
	card.offset_top = -22
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	portrait = PaperStatusIcon.new()
	portrait.setup("Ashura")
	portrait.custom_minimum_size = Vector2(78, 78)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(portrait)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 3)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	var heading: HBoxContainer = HBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(heading)
	name_label = _label("ASHURA", "title", 22, T.PAPER)
	heading.add_child(name_label)
	role_label = _label("", "caps", 11, T.TEAL)
	role_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	role_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(role_label)
	var hp_row: HBoxContainer = HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 6)
	hp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(hp_row)
	hp_row.add_child(_icon("heart", 15, T.RED))
	hp_label = _label("90 / 90", "digits", 24, T.PAPER)
	hp_row.add_child(hp_label)
	hp_unit = _label("PV", "caps", 11, T.PAPER_DIM)
	hp_unit.size_flags_vertical = Control.SIZE_SHRINK_END
	hp_row.add_child(hp_unit)
	hp_meter = _meter(T.GREEN, 10)
	hp_meter.ticks = 4
	column.add_child(hp_meter)
	hp_overcap = HpOvercap.new()
	hp_meter.add_child(hp_overcap)
	aura_row = HBoxContainer.new()
	aura_row.add_theme_constant_override("separation", 6)
	aura_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(aura_row)
	aura_row.add_child(_icon("aura", 13, T.LILAC))
	aura_label = _label("", "caps", 11, Color("c9b8e6"))
	aura_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aura_row.add_child(aura_label)
	aura_state = _label("", "caps", 11, T.GOLD)
	aura_row.add_child(aura_state)
	aura_meter = _meter(T.LILAC, 4)
	column.add_child(aura_meter)
	tf_row = HBoxContainer.new()
	tf_row.add_theme_constant_override("separation", 6)
	tf_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(tf_row)
	tf_row.add_child(_icon("true_form", 14, T.RED))
	tf_label = _label("", "caps", 11, T.PAPER)
	tf_row.add_child(tf_label)
	tf_meter = _meter(T.RED, 6)
	tf_meter.segments = 15
	column.add_child(tf_meter)

func _build_abilities() -> void :
	ability_bar = HBoxContainer.new()
	ability_bar.add_theme_constant_override("separation", 10)
	ability_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	ability_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ability_bar)
	ability_bar.anchor_left = 0.5
	ability_bar.anchor_right = 0.5
	ability_bar.anchor_top = 1
	ability_bar.anchor_bottom = 1
	ability_bar.offset_left = -300
	ability_bar.offset_right = 300
	ability_bar.offset_bottom = -14
	ability_bar.offset_top = -14
	ability_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ability_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	for i: int in range(6):
		var slot: W.AbilitySlot = W.AbilitySlot.new()
		slot.world = world
		slot.index = i
		slot.square = 66
		ability_bar.add_child(slot)
		slots.append(slot)

func _build_prompt() -> void :
	prompt_panel = _pill(Color(0.03, 0.04, 0.065, 0.84), Color(1, 1, 1, 0.1), 18, 7)
	add_child(prompt_panel)
	prompt_panel.anchor_left = 0.5
	prompt_panel.anchor_right = 0.5
	prompt_panel.anchor_top = 1
	prompt_panel.anchor_bottom = 1
	prompt_panel.offset_bottom = -134
	prompt_panel.offset_top = -134
	prompt_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	prompt = _label("", "medium", 18, T.PAPER)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.autowrap_mode = TextServer.AUTOWRAP_OFF
	prompt_panel.add_child(prompt)
	prompt_panel.hide()
	reticle = Reticle.new()
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(reticle)
	reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	reticle.offset_left = -6
	reticle.offset_right = 6
	reticle.offset_top = -6
	reticle.offset_bottom = 6

func _build_archive() -> void :
	archive_panel = PanelContainer.new()
	var style: StyleBoxFlat = T.box(Color(0.03, 0.05, 0.075, 0.94), Color(T.TEAL, 0.8), 2, 10, 22, 14)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 16
	archive_panel.add_theme_stylebox_override("panel", style)
	archive_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(archive_panel)
	archive_panel.anchor_left = 0.5
	archive_panel.anchor_right = 0.5
	archive_panel.anchor_top = 1
	archive_panel.anchor_bottom = 1
	archive_panel.offset_left = -190
	archive_panel.offset_right = 190
	archive_panel.offset_bottom = -190
	archive_panel.offset_top = -190
	archive_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	archive_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	archive_panel.add_child(box)
	var title: Label = _label(_t("ARCHIVE · CONTRÔLE D’INTÉGRITÉ"), "caps", 14, T.TEAL)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_meta("fr", "ARCHIVE · CONTRÔLE D’INTÉGRITÉ")
	box.add_child(title)
	var keys: HBoxContainer = HBoxContainer.new()
	keys.alignment = BoxContainer.ALIGNMENT_CENTER
	keys.add_theme_constant_override("separation", 16)
	keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(keys)
	for key: String in ["J", "K", "L"]:
		var cap: W.KeyCap = W.KeyCap.new(key, 30)
		cap.min_width = 64
		keys.add_child(cap)
		archive_caps.append(cap)
	archive_meter = _meter(T.TEAL, 6)
	box.add_child(archive_meter)
	archive_hint = _label("", "body", 14, T.PAPER_DIM)
	archive_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(archive_hint)
	archive_panel.hide()

func _build_hints() -> void :
	hints_box = HBoxContainer.new()
	hints_box.add_theme_constant_override("separation", 14)
	hints_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hints_box)
	hints_box.anchor_left = 1
	hints_box.anchor_right = 1
	hints_box.anchor_top = 1
	hints_box.anchor_bottom = 1
	hints_box.offset_right = -24
	hints_box.offset_left = -24
	hints_box.offset_bottom = -20
	hints_box.offset_top = -20
	hints_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hints_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hints_box.modulate = Color(1, 1, 1, 0.78)
	for spec: Array in [["emotes", "Émotes"], ["sprint", "Courir"], ["interact", "Interagir"], ["jump", "Saut"], ["camera_mode", "Caméra"], ["pause_game", "Menu"]]:
		var pair: HBoxContainer = HBoxContainer.new()
		pair.add_theme_constant_override("separation", 6)
		pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hints_box.add_child(pair)
		var cap: W.KeyCap = W.KeyCap.new("", 12)
		cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pair.add_child(cap)
		var label: Label = _label(_t(str(spec[1])), "medium", 14, T.PAPER_DIM)
		label.set_meta("fr", str(spec[1]))
		_shadow(label, 0.6)
		pair.add_child(label)
		hint_caps[spec[0]] = cap
		hint_labels[spec[0]] = label
	_refresh_keys()

func _build_spectator() -> void :
	spectator_panel = _pill(Color(0.03, 0.04, 0.065, 0.88), Color(T.TEAL, 0.45), 22, 10)
	add_child(spectator_panel)
	spectator_panel.anchor_left = 0.5
	spectator_panel.anchor_right = 0.5
	spectator_panel.anchor_top = 1
	spectator_panel.anchor_bottom = 1
	spectator_panel.offset_bottom = -36
	spectator_panel.offset_top = -36
	spectator_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	spectator_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spectator_panel.add_child(box)
	spectator_label = _label("", "caps", 15, T.TEAL)
	spectator_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(spectator_label)
	spectator_name = _label("", "title", 22, T.PAPER)
	spectator_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(spectator_name)
	spectator_panel.hide()

func _build_drone() -> void :
	drone_frame = DroneCorners.new()
	drone_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(drone_frame)
	drone_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	drone_label = _label("", "caps", 16, T.TEAL)
	_shadow(drone_label, 0.7)
	drone_frame.add_child(drone_label)
	drone_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	drone_label.offset_left = -340
	drone_label.offset_right = 340
	drone_label.offset_top = 196
	drone_label.offset_bottom = 222
	drone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drone_frame.hide()

func _build_intro() -> void :
	intro_top = ColorRect.new()
	intro_top.color = Color(0.02, 0.022, 0.03, 0.96)
	intro_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(intro_top)
	intro_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	intro_top.offset_bottom = 110
	intro_bottom = ColorRect.new()
	intro_bottom.color = intro_top.color
	intro_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(intro_bottom)
	intro_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	intro_bottom.offset_top = -130
	title_label = _label("", "display", 70, T.PAPER)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_shadow(title_label, 0.65)
	add_child(title_label)
	title_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	title_label.offset_left = -720
	title_label.offset_right = 720
	title_label.offset_top = -120
	title_label.offset_bottom = -10
	subtitle_label = _label("", "medium", 22, T.PAPER)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_shadow(subtitle_label, 0.65)
	add_child(subtitle_label)
	subtitle_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	subtitle_label.offset_left = -560
	subtitle_label.offset_right = 560
	subtitle_label.offset_top = 0
	subtitle_label.offset_bottom = 90
	title_label.hide()
	subtitle_label.hide()
	intro_top.hide()
	intro_bottom.hide()




func announce(title: String, subtitle: String, duration: float) -> void :
	title_label.text = _t(title)
	subtitle_label.text = _t(subtitle)
	announce_time = duration
	announce_total = maxf(0.3, duration)
	title_label.pivot_offset = title_label.size * 0.5
	if ui.reduced_motion:
		title_label.scale = Vector2.ONE
		return
	title_label.scale = Vector2(0.86, 0.86)
	var tween: Tween = title_label.create_tween()
	tween.tween_property(title_label, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func on_show() -> void :
	announce_time = 0
	archive_panel.hide()
	_refresh_keys()
	for i: int in range(6):
		_last_cd[i] = 0.0
		_peaks[i] = 1.0

func apply_mobile_layout(safe: Vector2) -> void :
	ability_bar.hide()
	hints_box.hide()
	roster.position = Vector2(14 + safe.x, 40)
	room_row.position = Vector2(18 + safe.x, 12)
	room_label.add_theme_font_size_override("font_size", 12)
	top_box.offset_top = 4
	timer_label.add_theme_font_size_override("font_size", 42)
	objective_label.add_theme_font_size_override("font_size", 12)
	music_label.add_theme_font_size_override("font_size", 12)
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.offset_left = -150
	card.offset_right = 150
	card.offset_bottom = -10
	card.offset_top = -10
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var style: StyleBoxFlat = T.box(Color(0.025, 0.04, 0.055, 0.84), Color("42585b"), 1, 8, 12, 7)
	card.add_theme_stylebox_override("panel", style)
	portrait.custom_minimum_size = Vector2(46, 46)
	name_label.add_theme_font_size_override("font_size", 16)
	hp_label.add_theme_font_size_override("font_size", 18)
	hp_meter.custom_minimum_size.y = 7
	prompt_panel.offset_bottom = -206
	prompt_panel.offset_top = -206
	prompt.add_theme_font_size_override("font_size", 15)
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.custom_minimum_size.x = 480
	spectator_panel.offset_bottom = -170
	spectator_panel.offset_top = -170
	archive_panel.hide()




func update(delta: float) -> void :
	var a: PaperActor = world.local_actor()
	var intro: bool = world.phase == "intro"
	intro_top.visible = intro
	intro_bottom.visible = intro
	announce_time = maxf(0.0, announce_time - delta)
	var titled: bool = announce_time > 0 or intro
	title_label.visible = titled
	subtitle_label.visible = titled
	if titled:
		var fade: float = 1.0 if intro else clampf(announce_time / 0.4, 0.0, 1.0)
		title_label.modulate.a = fade
		subtitle_label.modulate.a = fade
	_key_clock -= delta
	if _key_clock <= 0:
		_key_clock = 1.0
		_refresh_keys()
	var piloting: bool = a != null and bool(a.effects.get("drone_piloting", false))
	hints_box.visible = not world.mobile_mode and a != null and a.active() and not piloting
	if hints_box.visible: _update_hints(a)
	drone_frame.visible = a != null and world.phase == "playing" and piloting
	if drone_frame.visible: _write(drone_label, _t("● DRONE PRÉCIS · BATTERIE %.1f s · CORPS IMMOBILE") % float(a.effects.get("drone_battery", 0)))
	reticle.visible = a != null and a.active() and not piloting
	if intro:
		_write(title_label, _t("L'ÉCOLE SE REFERME"))
		var line: String = _t("ALICE · Éliminez tous les survivants.") if a and a.killer else _t("SURVIVANTS · Tenez jusqu’à 01:20, puis rejoignez la sortie.")
		_write(subtitle_label, line + "\n" + str(maxi(1, int(ceil(world.INTRO_DURATION - world.cinema)))))
	_update_top(a)
	room_row.visible = a != null
	if a:
		_write(room_label, _t(world.school.room_name(a.position)).to_upper())
		_update_card(a)
		_update_slots(a)
		var text: String = _prompt_text(a)
		if world.mobile_mode:
			text = ui._touch_text(text)
			if bool(a.effects.get("spike_aiming", false)): text = _t("GLISSE POUR VISER · PIQUES POUR CONFIRMER · ANNULER POUR RENONCER")
			if float(a.effects.get("counter", 0)) > 0: text = _t("TOUCHE BLOQUER · CONTRE DISPONIBLE !")
			if float(a.effects.get("archive_qte_remaining", 0)) > 0: text = ""
		_write(prompt, text)
	else:
		_write(prompt, "")
		card.hide()
		ability_bar.hide()
	prompt_panel.visible = not prompt.text.is_empty()
	_update_spectator(a)
	roster.refresh()
	_update_archive(a)

func _update_top(a: PaperActor) -> void :
	var t: int = int(ceil(world.time_left))
	_write(timer_label, "%02d:%02d" % [t / 60, t % 60])
	_color(timer_label, T.RED if world.lms else T.PAPER)
	var timer_size: int = (34 if world.mobile_mode else 44) if world.training else (42 if world.mobile_mode else 66)
	if timer_label.get_theme_font_size("font_size") != timer_size: timer_label.add_theme_font_size_override("font_size", timer_size)
	var killer_view: bool = a != null and a.killer
	var objective: String = ""
	var tint: Color = T.TEAL
	var icon_name: String = "exit"
	if world.exit_flow.opened:
		objective = "SORTIE OUVERTE · EMPÊCHEZ LEUR FUITE" if killer_view else "SORTIE OUVERTE · FUYEZ !"
		tint = T.GOLD
	elif world.lms:
		objective = "LAST MAN STANDING"
		tint = T.RED
		icon_name = "bell"
	elif killer_view:
		objective = "EMPÊCHEZ LEUR FUITE"
		tint = Color("f08a9a")
		icon_name = "slash"
	else: objective = "SORTIE À 01:20 · RESTEZ EN VIE"
	var alice: PaperActor = world.killer_actor()
	var true_time: float = float(alice.effects.get("phase6", 0)) if alice else 0.0
	true_form_panel.visible = true_time > 0
	if true_time > 0:
		_write(true_form_label, _t("TRUE FORM · %.1f s · CHRONO SUSPENDU") % true_time)
		true_form_meter.set_value(true_time / PaperRules.TRUE_FORM_SECONDS, true)
	music_row.visible = world.lms
	if world.lms: _write(music_label, world.audio.lms_title())
	if world.training:
		var practice_title: String = "ESSAI LIBRE"
		_write(timer_label, _t(practice_title))
		_color(timer_label, T.TEAL)
		objective = "ESSAIS · PERSONNAGES, CIBLES & LMS" if world.mobile_mode else "F2 · PERSONNAGES, CIBLES & LMS"
		tint = T.TEAL
		icon_name = "dummy"
		music_row.visible = true
		var feedback: String = world.audio.lms_title() if a and a.lms else world.practice.feedback if world.clock < world.practice.feedback_until else "École · Capacités réelles · Cibles réinitialisables"
		_write(music_label, ui._touch_text(_t(feedback)))
	_write(objective_label, _t(objective))
	_color(objective_label, tint)
	if objective_icon.modulate != tint: objective_icon.modulate = tint
	var icon_tex: Texture2D = Icons.icon(icon_name)
	if objective_icon.texture != icon_tex: objective_icon.texture = icon_tex
	var border: Color = Color(tint, 0.4)
	var style: StyleBoxFlat = objective_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style and style.border_color != border: style.border_color = border

func _update_card(a: PaperActor) -> void :
	card.visible = a.alive or bool(a.effects.get("escaped", false)) or bool(a.effects.get("downed", false))
	if _card_character != a.character:
		_card_character = a.character
		portrait.setup(a.character)
		portrait.custom_minimum_size = Vector2(46, 46) if world.mobile_mode else Vector2(78, 78)
		_write(name_label, a.character.to_upper())
		var stats: Array = PaperData.STATS.get(a.character, [])
		_write(role_label, _t(str(stats[3])) if stats.size() > 3 else "")
		_color(role_label, T.RED if a.killer else T.TEAL)
	var life: String = "escaped" if bool(a.effects.get("escaped", false)) else "dead" if not a.alive else "downed" if bool(a.effects.get("downed", false)) else "second_life" if bool(a.effects.get("revived", false)) else "alive"
	portrait.update_state(life, float(a.effects.get("chased", 0)) > 0)
	if a.max_hp < 0:
		_write(hp_label, "∞")
		hp_meter.set_value(1.0, true)
	elif life == "downed":
		_write(hp_label, _t("À TERRE · %d s") % int(ceil(float(a.effects.get("bleedout", 30)))))
		hp_meter.set_value(clampf(float(a.effects.get("bleedout", 30)) / 30.0, 0, 1), true)
	else:
		_write(hp_label, "%d / %d" % [maxi(0, int(ceil(a.hp))), int(a.max_hp)])
		hp_meter.set_value(maxf(0, a.hp / a.max_hp))
	hp_unit.visible = life != "downed" and a.max_hp >= 0
	_write(hp_unit, _t("PV"))
	var hp_color: Color = T.AMBER if life == "downed" else T.RED if a.killer else PaperStatusIcon.COLORS.get(life, T.GREEN)
	if a.max_hp > 0 and a.hp / a.max_hp < 0.3 and life in ["alive", "second_life"]: hp_color = T.RED
	hp_meter.set_color(hp_color)
	_color(hp_label, T.GOLD if hp_overcap.update_from(a, life) else T.PAPER)
	var survivor: bool = world.ruleset == "om" and not a.killer
	aura_row.visible = survivor
	aura_meter.visible = survivor
	if survivor:
		var aura: float = float(a.effects.get("aura_charge", 0))
		aura_meter.set_value(aura / 100.0, true)
		_write(aura_label, _t("AURA · %d / 100") % int(aura))
		_write(aura_state, _t("PRÊTE") if aura >= 100 else "")
	tf_row.visible = a.killer and a.alive
	tf_meter.visible = tf_row.visible
	if a.killer:
		var rage: float = float(a.effects.get("rage", 0))
		var frenzy: float = float(a.effects.get("phase6", 0))
		var used: bool = bool(a.effects.get("true_form_used", false))
		var text: String = ""
		if frenzy > 0: text = _t("TRUE FORM · %.0f s restantes") % frenzy
		elif used: text = _t("TRUE FORM · UTILISÉE")
		elif rage >= 100: text = _t("%s · ACTIVER TRUE FORM") % _keys[5]
		else: text = _t("TRUE FORM · %d / 15 STUNS") % int(a.effects.get("stun_count", 0))
		_write(tf_label, text)
		_color(tf_label, T.GOLD if rage >= 100 and not used else T.PAPER)
		tf_meter.set_value(1.0 if frenzy > 0 or rage >= 100 else clampf(float(a.effects.get("stun_count", 0)) / 15.0, 0, 1), true)
		tf_meter.set_color(T.GOLD if rage >= 100 and frenzy <= 0 and not used else T.RED)

func _update_slots(a: PaperActor) -> void :
	ability_bar.visible = not world.mobile_mode and a.alive and not bool(a.effects.get("escaped", false))
	if not ability_bar.visible: return
	var skills: Array = _skills(a.character)
	var names: Array = SHORT.get(a.character, [])
	var piloting: bool = bool(a.effects.get("drone_piloting", false))
	for i: int in range(6):
		var slot: W.AbilitySlot = slots[i]
		if i >= skills.size() or str(skills[i][0]) == "—":
			slot.visible = false
			continue
		slot.visible = true
		var skill: Array = skills[i]
		var cd: float = float(a.cooldowns.get(i, 0))


		if cd > _last_cd[i] + 0.25: _peaks[i] = cd
		if cd <= 0.0: _peaks[i] = maxf(1.0, float(skill[1]))
		_last_cd[i] = cd
		var locked: bool = i == 3 and a.character in ["Elly", "Usayuko", "Bleuette"] and not world.combat.lms_available(a)
		var blocked: bool = locked or not a.active() or piloting
		var title: String = str(names[i]) if i < names.size() and not str(names[i]).is_empty() else str(skill[0]).replace(" · LMS", "").to_upper()
		var state: String = ""
		var state_color: Color = T.PAPER_DIM
		var highlight: bool = false
		var charge: float = -1.0
		var charge_label: String = ""
		var icon_tex: Texture2D = Icons.ability_live(a.character, i, a.effects)
		if locked:
			state = "LMS"
			state_color = T.RED
		if i == 1 and a.character in ["Simon", "Ashura"]:
			if bool(a.effects.get("boost_charging", false)):
				charge = clampf(float(a.effects.get("boost_charge", 0)) / 3.0, 0, 1)
				charge_label = "N%d" % int(a.effects.get("boost_level", 0))
				state = "%.1f s" % float(a.effects.get("boost_charge", 0))
				state_color = T.GOLD
			elif cd <= 0:
				state = "MAINTENIR"
				state_color = T.TEAL
		if a.character == "Ashura":
			if i == 0 and cd <= 0:
				state = "TÉLÉGUIDÉ" if bool(a.effects.get("drone_precise", false)) else "RAPIDE"
				state_color = T.TEAL
			if i == 2:
				title = "MODE"
				state = "VERS RAPIDE" if bool(a.effects.get("drone_precise", false)) else "VERS PRÉCIS"
		if world.ruleset == "om" and a.character == "Simon":
			if i == 0:
				title = "COUP ÉCLAIR" if bool(a.effects.get("flash_melee", false)) else "FLASHBANG"
				if cd <= 0:
					var aiming: bool = bool(a.effects.get("grenade_aiming", false))
					state = "CONFIRMER" if aiming else "VISER"
					state_color = T.GOLD if aiming else T.TEAL
					highlight = aiming
			if i == 2:
				title = "CHANGER"
				state = "VERS LANCER" if bool(a.effects.get("flash_melee", false)) else "VERS COUP"
		if a.active() and a.character == "Usayuko" and i == 1 and float(a.effects.get("counter", 0)) > 0:
			blocked = false
			title = "CONTRE"
			state = "MAINTENANT !"
			state_color = T.GOLD
			highlight = true
		if a.character == "Alice" and i == 2 and bool(a.effects.get("spike_aiming", false)):
			title = "PIQUES"
			state = "CONFIRMER"
			state_color = T.GOLD
			highlight = true
		if a.character == "Alice" and i == 5:
			var rage: float = float(a.effects.get("rage", 0))
			var frenzy: float = float(a.effects.get("phase6", 0))
			var used: bool = bool(a.effects.get("true_form_used", false))
			blocked = rage < 100 or frenzy > 0 or not a.active() or used
			if frenzy > 0:
				state = "ACTIVE"
				state_color = T.RED
			elif used:
				state = "UTILISÉE"
			elif not blocked:
				state = "ACTIVER"
				state_color = T.GOLD
				highlight = true
			else:
				state = "%d / 15" % int(a.effects.get("stun_count", 0))
				charge = clampf(rage / 100.0, 0, 1)
		if i == 3 and ((a.character == "Usayuko" and a.effects.get("dropkick_used", false)) or (a.character == "Elly" and a.effects.get("shotgun_used", false)) or (a.character == "Bleuette" and a.effects.get("aura_used", false))):
			state = "UTILISÉ"
			state_color = T.PAPER_DIM
			blocked = true
		var accent: Color = T.RED if a.killer else T.TEAL
		if slot.accent != accent: slot.accent = accent
		slot.reduced_motion = ui.reduced_motion
		var tip: String = _t(str(skill[2]))
		if slot.tooltip_text != tip: slot.tooltip_text = tip
		slot.apply(icon_tex, _keys[i], _t(title), _t(state), state_color, cd, maxf(_peaks[i], cd), blocked, locked, highlight, charge, charge_label)



func _skills(character_name: String) -> Array:
	if not _skill_cache.has(character_name): _skill_cache[character_name] = PaperData.abilities_for(character_name, world.ruleset)
	return _skill_cache[character_name]

func _update_spectator(a: PaperActor) -> void :
	var watching: bool = world.phase == "playing" and (a == null or not a.alive or bool(a.effects.get("escaped", false)))
	spectator_panel.visible = watching
	if not watching: return
	var escaped: bool = a != null and bool(a.effects.get("escaped", false))
	var head: String = _t("ÉVADÉ · TU ES EN SÉCURITÉ") if escaped else _t("SPECTATEUR")
	var camera_hint: String = "" if world.mobile_mode else "  ·  " + _t("%s : caméra") % _binding("camera_mode", "C")
	_write(spectator_label, head + "  ·  " + _t(ui._touch_text("TAB : allié suivant")) + camera_hint)
	var viewed: PaperActor = world.call("_view_actor") if world.has_method("_view_actor") else null
	var shown: String = ""
	if viewed and viewed != a:
		shown = _t("Tu suis %s") % (viewed.character + ("" if viewed.bot or viewed.display_name.is_empty() or viewed.display_name == viewed.character else " · " + viewed.display_name))
	_write(spectator_name, shown)
	spectator_name.visible = not shown.is_empty()

func _update_archive(actor: PaperActor) -> void :
	if world.mobile_mode:
		archive_panel.hide()
		return
	var remaining: float = float(actor.effects.get("archive_qte_remaining", 0.0)) if actor else 0.0
	archive_panel.visible = remaining > 0 and actor.active() and not world.pause_open and world.phase == "playing"
	if not archive_panel.visible: return
	var key: int = clampi(int(actor.effects.get("archive_qte_key", 0)), 0, 2)
	var urgent: bool = remaining < 0.45
	for i: int in range(3):
		var cap: W.KeyCap = archive_caps[i]
		cap.set_label(_binding("qte_" + str(i), ["J", "K", "L"][i]))
		cap.accent = T.RED if urgent and i == key else T.TEAL
		cap.set_lit(i == key)
		cap.modulate.a = 1.0 if i == key else 0.45
	archive_meter.set_value(clampf(remaining / maxf(0.1, float(actor.effects.get("archive_qte_duration", 2.1))), 0, 1), true)
	archive_meter.set_color(T.RED if urgent else T.TEAL)
	_write(archive_hint, _t("Garde E enfoncé · mauvaise touche = alarme + blocage 3 s"))

func _update_hints(a: PaperActor) -> void :
	hint_caps.emotes.get_parent().visible = not a.killer
	var jump_cd: float = float(a.effects.get("jump_cd", 0))
	var jump_text: String = _t("Saut") if jump_cd <= 0 else _t("Saut") + " %.1f s" % jump_cd
	_write(hint_labels.jump, jump_text)
	_color(hint_labels.jump, T.PAPER_DIM if jump_cd <= 0 else T.FAINT)

func _refresh_keys() -> void :
	for i: int in range(6): _keys[i] = _binding("ability_" + str(i), str(i + 1))
	for action: String in hint_caps: hint_caps[action].set_label(_binding(action, ""))
	for action: String in hint_labels:
		var source: String = str(hint_labels[action].get_meta("fr", ""))
		if action != "jump" and not source.is_empty(): _write(hint_labels[action], _t(source))


func _binding(action: String, fallback: String) -> String:
	return PaperUI.key_label(action, fallback)





func _prompt_text(a: PaperActor) -> String:
	if bool(a.effects.get("escaped", false)): return _t("ÉCHAPPÉ · TU ES EN SÉCURITÉ")
	if bool(a.effects.get("boost_charging", false)): return _t("CHARGE %.1f s · NIVEAU %d · RELÂCHER POUR PARTIR") % [float(a.effects.get("boost_charge", 0)), int(a.effects.get("boost_level", 0))]
	if bool(a.effects.get("grenade_aiming", false)): return _t("VISE · CAPACITÉ 1 POUR LANCER · ANNULER POUR RENONCER")
	if float(a.effects.get("outlet_healing", 0)) > 0 and int(a.effects.get("outlet_ashura", -1)) >= 0: return _t("BRANCHÉE · ASHURA ×1,5 · +10 PV / 1,3 s · %.1f s · BOUGER / INTERAGIR / 4 : DÉBRANCHER") % float(a.effects.outlet_healing)
	if float(a.effects.get("outlet_healing", 0)) > 0: return _t("BRANCHÉE · +10 PV / 2 s · %.1f s · BOUGER / INTERAGIR / 4 : DÉBRANCHER") % float(a.effects.outlet_healing)
	if a.character == "Simon" and float(a.effects.get("speed_boost", 0)) > 0: return _t("INTERAGIR · DÉPOSER TON ALLIÉ") if int(a.effects.get("carrying_id", -1)) >= 0 else _t("INTERAGIR PRÈS D’UN ALLIÉ · L’EMPORTER (SAUF LYSIA)")
	if not a.alive: return ""
	if bool(a.effects.get("dying", false)): return _t("LA DERNIÈRE BLESSURE…")
	if bool(a.effects.get("downed", false)):
		return (_t("À TERRE · RAMPE VERS UN ALLIÉ · %d s") if world.ruleset == "om" else _t("À TERRE · UN ALLIÉ PEUT TE RELEVER · %d s")) % int(ceil(float(a.effects.get("bleedout", 30))))
	if float(a.effects.get("stun", 0)) > 0: return _t("ÉTOURDI  ·  %.1f s") % float(a.effects.stun)
	if bool(a.effects.get("spike_aiming", false)): return _t("VISE AVEC LA SOURIS · CLIC OU 3 : PIQUES · CLIC DROIT : ANNULER")
	if float(a.effects.get("grab_time", 0)) > 0: return _t("CHARGE · ATTRAPE ALICE AU CONTACT ET VISE UN MUR")
	if float(a.effects.get("shadow_mark", 0)) > 0: return _t("ALICE EST DANS TON OMBRE ! ELLE ARRIVE DERRIÈRE TOI")
	if bool(a.effects.get("shadow_hide", false)): return _t("OMBRE PORTÉE · ÉMERGENCE DERRIÈRE LA CIBLE…")
	if float(a.effects.get("phase6", 0)) > 0: return _t("TRUE FORM · %.0f s · COMPÉTENCE 4 : BONDIR") % float(a.effects.phase6)
	if float(a.effects.get("counter", 0)) > 0: return _t("2  ·  CONTRE DISPONIBLE !")
	if float(a.effects.get("overheat_time", 0)) > 0: return _t("SURCHAUFFE · INVULNÉRABLE · ARMURE −%d PV · %.1f s") % [int(floor(PaperSurvivorMechanics.OVERHEAT_HP_COST * clampf(1.0 - float(a.effects.overheat_time) / PaperSurvivorMechanics.OVERHEAT_SECONDS, 0.0, 1.0))), float(a.effects.overheat_time)]
	if float(a.effects.get("heal_time", 0)) > 0: return _t("SOIN EN COURS · %.1f s") % float(a.effects.heal_time)
	if bool(a.effects.get("drone_piloting", false)): return _t("JOYSTICK + REGARD POUR PILOTER · ANNULER POUR QUITTER") if world.mobile_mode else _t("ZQSD / WASD + SOURIS : PILOTER · CLIC DROIT : QUITTER")
	if bool(a.effects.get("drone_active", false)): return _t("DRONE EN VOL · BATTERIE %.1f / 10 s") % float(a.effects.get("drone_battery", 0))
	if a.killer and world.clock < 5 and not world.training: return _t("Les élèves prennent de l'avance…")
	if not a.killer:
		var rescue: Dictionary = world.combat.revive_preview(a)
		if int(rescue.get("target", -1)) >= 0: return _t(str(rescue.get("label", "MAINTENIR E · RELEVER")))
		for i: int in range(world.school.objectives.size()):
			if not world.objective_done.has(i) and a.position.distance_to(world.school.objectives[i]) < 2.6:
				var blocked: float = world.archive_lock_remaining(i)
				if blocked > 0: return _t("ARCHIVE BLOQUÉE · %.1f s") % blocked
				return _t("MAINTENIR E · SCELLER · QTE J / K / L") + "   " + str(int(float(world.objective_progress.get(i, 0)) * 100)) + " %"
		if a.character == "Ashura":
			for other: PaperActor in world.actors.values():
				if other.character == "Lysia" and int(other.effects.get("outlet_ashura", -1)) == a.id: return _t("ASHURA ×1,5 · TU ACCÉLÈRES LA RECHARGE DE LYSIA")
		if a.character == "Lysia":
			var outlet: Dictionary = world.combat.outlet_preview(a)
			if bool(outlet.get("ready", false)): return _t("INTERAGIR / 4 · SE BRANCHER · 15 s DE SOIN")
			for c: Dictionary in world.drones:
				if c.state == "salvage" and a.position.distance_to(c.position) < 2.8: return _t("MARCHE SUR LE DRONE · +7 PV")
			var target: Dictionary = world.combat.overheat_target(a)
			if float(a.cooldowns.get(0, 0)) <= 0: return "1 · " + _t(str(target.reason))
		# LMS : plus aucun allié à encourager, le rappel se tait.
		if a.character == "Bleuette" and not world.lms:
			var support: Dictionary = world.combat.support_target_preview(a, 0)
			return "1 · " + _t(str(support.reason))
	if world.training: return _t("F2 · PRÉPARER UN TEST / CHANGER DE PERSONNAGE")
	return ""
