extends Control

# Bandeau bref affiché quand on change de mode de caméra (« CAMÉRA : DERRIÈRE » / « CAMÉRA : LIBRE 360° »).

const T = preload("res://ui_theme.gd")

const FADE_IN: float = 0.12
const HOLD: float = 1.35
const FADE_OUT: float = 0.4

var world: Node
var mode: String = "free"
var _panel: PanelContainer
var _glyph: Glyph
var _title: Label
var _detail: Label
var _key: Label
var _time: float = 0.0


class Glyph extends Control:
	var behind: bool = false


	func _person(at: Vector2, color: Color) -> void :
		draw_circle(at + Vector2(0, -6), 4.2, color)
		var shoulders: PackedVector2Array = PackedVector2Array()
		for i: int in range(13): shoulders.append(at + Vector2(0, 6) + Vector2(cos(PI + PI * i / 12.0) * 7.5, sin(PI + PI * i / 12.0) * 6.5))
		draw_colored_polygon(shoulders, color)

	func _camera(at: Vector2, color: Color) -> void :
		draw_rect(Rect2(at + Vector2(-6, -2), Vector2(12, 8)), color)
		draw_colored_polygon(PackedVector2Array([at + Vector2(-4, -2), at + Vector2(4, -2), at + Vector2(0, -6)]), color)

	func _draw() -> void :
		var c: Vector2 = size * 0.5
		var ink: Color = T.TEAL
		var paper: Color = Color(T.PAPER, 0.95)
		if behind:

			var lens: Vector2 = c + Vector2(0, 9)
			draw_colored_polygon(PackedVector2Array([lens, c + Vector2(-10, -9), c + Vector2(10, -9)]), Color(ink, 0.3))
			_person(c + Vector2(0, -3), paper)
			_camera(c + Vector2(0, 14), ink)
		else:

			_person(c + Vector2(0, 1), paper)
			draw_arc(c, 17.0, -PI * 0.2, PI * 1.45, 44, ink, 2.2, true)
			var a: float = -PI * 0.2
			var tip: Vector2 = c + Vector2(cos(a), sin(a)) * 17.0
			var tangent: Vector2 = Vector2(-sin(a), cos(a))
			var normal: Vector2 = Vector2(cos(a), sin(a))
			draw_colored_polygon(PackedVector2Array([tip - tangent * 6.5, tip + normal * 5.0 + tangent * 1.5, tip - normal * 5.0 + tangent * 1.5]), ink)


func setup(owner: Node) -> void :
	world = owner
	name = "CameraModeBadge"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = T.box(Color(0.035, 0.045, 0.07, 0.86), Color(T.TEAL, 0.5), 1, 22, 18, 9)
	style.border_width_left = 4
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.27
	_panel.anchor_bottom = 0.27
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	_panel.add_child(row)
	_glyph = Glyph.new()
	_glyph.custom_minimum_size = Vector2(44, 44)
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_glyph)
	var text: VBoxContainer = VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	_title = _label("caps_wide", 19, T.PAPER)
	text.add_child(_title)
	_detail = _label("body", 13, T.PAPER_DIM)
	text.add_child(_detail)
	_key = _label("caps", 13, T.TEAL)
	_key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_key)
	modulate.a = 0.0
	hide()

func _label(kind: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", T.font(kind))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label

func show_mode(next: String) -> void :
	mode = next
	var behind: bool = mode == "behind"
	_title.text = PaperLanguage.t("CAMÉRA : DERRIÈRE" if behind else "CAMÉRA : LIBRE 360°")
	_detail.text = PaperLanguage.t("Le personnage tourne avec la caméra" if behind else "Tourne librement autour du personnage")
	var key: String = PaperUI.key_label("camera_mode", "C")
	_key.text = "[" + key + "]" if not key.is_empty() and not bool(world.get("mobile_mode")) else ""
	_glyph.behind = behind
	_glyph.queue_redraw()
	_time = FADE_IN + HOLD + FADE_OUT
	_panel.offset_left = 0
	_panel.offset_right = 0
	_panel.offset_top = 0
	_panel.offset_bottom = 0
	show()
	_apply()

func _process(delta: float) -> void :
	if not visible: return
	_time = maxf(0.0, _time - delta)
	_apply()
	if _time <= 0.0: hide()

func _apply() -> void :
	var total: float = FADE_IN + HOLD + FADE_OUT
	var age: float = total - _time
	var alpha: float = clampf(age / FADE_IN, 0.0, 1.0) if age < FADE_IN else clampf(_time / FADE_OUT, 0.0, 1.0)
	modulate.a = alpha
	var reduced: bool = world != null and world.get("ui") != null and bool(world.ui.get("reduced_motion"))
	var rise: float = 0.0 if reduced else (1.0 - smoothstep(0.0, FADE_IN * 2.0, age)) * 10.0
	_panel.offset_top = rise
	_panel.offset_bottom = rise
