extends RefCounted




const BG: Color = Color("0d0f16")
const INK: Color = Color("0a0c12")
const PANEL: Color = Color(0.082, 0.098, 0.145, 0.92)
const PANEL_SOLID: Color = Color("151925")
const PANEL_HI: Color = Color("1d2333")
const PANEL_LOW: Color = Color("10131c")
const LINE: Color = Color("2c3346")
const LINE_SOFT: Color = Color(0.93, 0.9, 0.84, 0.08)
const PAPER: Color = Color("ece5d5")
const PAPER_DIM: Color = Color("bdb6a6")
const MUTED: Color = Color("8c8f99")
const FAINT: Color = Color("5d6170")
const INK_TEXT: Color = Color("1f1b24")
const INK_MUTED: Color = Color("5e5764")
const CREAM: Color = Color("efe8d9")
const CREAM_SHADE: Color = Color("d8cfbb")
const TEAL: Color = Color("87c9c4")
const TEAL_DIM: Color = Color("4d7f7b")
const TEAL_DEEP: Color = Color("1d3b3c")
const RED: Color = Color("d6455d")
const RED_DEEP: Color = Color("8f2439")
const RED_INK: Color = Color("c23a4f")
const GOLD: Color = Color("f2c46d")
const GOLD_DIM: Color = Color("a8864a")
const LILAC: Color = Color("b7a0db")
const GREEN: Color = Color("8fc7af")
const AMBER: Color = Color("edbc72")

const FONT_DIR: String = "res://ui/fonts/"





static var pointer_mode: bool = true

static var touch_mode: bool = false

static var _fonts: Dictionary = {}
static var _theme: Theme
static var _theme_mobile: bool = false
static var _icons: Dictionary = {}



static func font(kind: String) -> Font:
	if _fonts.is_empty(): _load_fonts()
	return _fonts.get(kind, _fonts.get("body")) as Font

static func _file(file_name: String) -> Font:
	var path: String = FONT_DIR + file_name
	if not ResourceLoader.exists(path): return ThemeDB.fallback_font
	return load(path) as Font

static func _variation(base: Font, weight: int = 0, spacing: int = 0, features: Dictionary = {}, fallback: Font = null) -> FontVariation:
	var result: FontVariation = FontVariation.new()
	result.base_font = base
	if weight > 0: result.variation_opentype = {"wght": weight}
	result.spacing_glyph = spacing
	if not features.is_empty(): result.opentype_features = features
	if fallback: result.fallbacks = [fallback]
	return result

static func _load_fonts() -> void :


	var symbols: Font = _file("PaperSymbols-InterSubset.ttf")
	var chain: Array[Font] = [symbols, ThemeDB.fallback_font]
	for file_name: String in ["BarlowSemiCondensed-Regular.ttf", "BarlowSemiCondensed-Medium.ttf", "BarlowSemiCondensed-SemiBold.ttf", "BarlowSemiCondensed-Bold.ttf", "Oswald-Variable.ttf", "Anton-Regular.ttf", "BebasNeue-Regular.ttf", "Caveat-Variable.ttf"]:
		var base: Font = _file(file_name)
		if base is FontFile and base.fallbacks.is_empty(): base.fallbacks = chain
	_fonts["body"] = _file("BarlowSemiCondensed-Regular.ttf")
	_fonts["medium"] = _file("BarlowSemiCondensed-Medium.ttf")
	_fonts["semibold"] = _file("BarlowSemiCondensed-SemiBold.ttf")
	_fonts["bold"] = _file("BarlowSemiCondensed-Bold.ttf")
	_fonts["num"] = _variation(_file("BarlowSemiCondensed-SemiBold.ttf"), 0, 0, {"tnum": 1})
	var oswald: Font = _file("Oswald-Variable.ttf")
	_fonts["title"] = _variation(oswald, 600, 1)
	_fonts["caps"] = _variation(oswald, 500, 2)
	_fonts["caps_wide"] = _variation(oswald, 500, 4)
	_fonts["nav"] = _variation(oswald, 500, 2)
	_fonts["logo"] = _variation(_file("Anton-Regular.ttf"), 0, 3)
	_fonts["display"] = _file("Anton-Regular.ttf")
	_fonts["digits"] = _variation(_file("BebasNeue-Regular.ttf"), 0, 1)
	_fonts["hand"] = _variation(_file("Caveat-Variable.ttf"), 700, 0)


static func box(bg: Color, border: Color = Color(0, 0, 0, 0), width: int = 0, radius: int = 4, margin_h: float = 16, margin_v: float = 10) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin_h
	style.content_margin_right = margin_h
	style.content_margin_top = margin_v
	style.content_margin_bottom = margin_v
	style.anti_aliasing = true
	return style

static func panel_style(alpha: float = 0.92, border: Color = LINE, radius: int = 6) -> StyleBoxFlat:
	var style: StyleBoxFlat = box(Color(PANEL_SOLID, alpha), border, 1, radius, 22, 18)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 6)
	return style

static func focus_style(radius: int = 5) -> StyleBoxFlat:
	var style: StyleBoxFlat = box(Color(0, 0, 0, 0), GOLD, 2, radius, 0, 0)
	style.draw_center = false
	style.set_expand_margin_all(3)
	return style

static func empty_style(margin_h: float = 0, margin_v: float = 0) -> StyleBoxEmpty:
	var style: StyleBoxEmpty = StyleBoxEmpty.new()
	style.content_margin_left = margin_h
	style.content_margin_right = margin_h
	style.content_margin_top = margin_v
	style.content_margin_bottom = margin_v
	return style


static func svg_icon(key: String, svg: String) -> Texture2D:
	if _icons.has(key): return _icons[key]
	var texture: Texture2D = DPITexture.create_from_string(svg)
	if texture == null:
		var image: Image = Image.new()
		if image.load_svg_from_string(svg, 1.0) == OK: texture = ImageTexture.create_from_image(image)
	_icons[key] = texture
	return texture

static func _hex(color: Color) -> String:
	return "#" + color.to_html(false)

static func _switch_svg(on: bool, disabled: bool) -> String:
	var track: Color = TEAL if on else Color("2a3040")
	var knob: Color = Color("fff8ea") if on else Color("9aa0ad")
	var alpha: float = 0.45 if disabled else 1.0
	var knob_x: float = 29.0 if on else 13.0
	return "<svg xmlns='http://www.w3.org/2000/svg' width='42' height='24' viewBox='0 0 42 24'><g opacity='%.2f'><rect x='1' y='2' width='40' height='20' rx='10' fill='%s' stroke='%s' stroke-width='1.5'/><circle cx='%.1f' cy='12' r='7.5' fill='%s'/></g></svg>" % [alpha, _hex(track if on else Color("1a1f2b")), _hex(TEAL if on else Color("3a4254")), knob_x, _hex(knob)]

static func _check_svg(on: bool, disabled: bool, radio: bool = false) -> String:
	var alpha: float = 0.45 if disabled else 1.0
	var shape: String = "<circle cx='11' cy='11' r='9' fill='%s' stroke='%s' stroke-width='1.5'/>" if radio else "<rect x='2' y='2' width='18' height='18' rx='4' fill='%s' stroke='%s' stroke-width='1.5'/>"
	shape = shape % [_hex(TEAL if on else Color("171b26")), _hex(TEAL if on else Color("4a5266"))]
	var mark: String = ""
	if on: mark = "<circle cx='11' cy='11' r='4' fill='#10141c'/>" if radio else "<path d='M6 11.5l3.4 3.4L16.5 7.6' fill='none' stroke='#10141c' stroke-width='2.6' stroke-linecap='round' stroke-linejoin='round'/>"
	return "<svg xmlns='http://www.w3.org/2000/svg' width='22' height='22' viewBox='0 0 22 22'><g opacity='%.2f'>%s%s</g></svg>" % [alpha, shape, mark]

static func _grabber_svg(color: Color, ring: Color) -> String:
	return "<svg xmlns='http://www.w3.org/2000/svg' width='22' height='22' viewBox='0 0 22 22'><circle cx='11' cy='11' r='8' fill='%s' stroke='%s' stroke-width='2.5'/></svg>" % [_hex(color), _hex(ring)]

static func _arrow_svg(color: Color) -> String:
	return "<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 16 16'><path d='M3.5 6l4.5 4.5L12.5 6' fill='none' stroke='%s' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'/></svg>" % _hex(color)


static func theme(mobile: bool = false) -> Theme:
	if _theme and _theme_mobile == mobile: return _theme
	_theme_mobile = mobile
	var t: Theme = Theme.new()
	var bump: int = 2 if mobile else 0
	t.default_font = font("body")
	t.default_font_size = 18 + bump

	t.set_color("font_color", "Label", PAPER)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	t.set_constant("line_spacing", "Label", 2)

	var normal: StyleBoxFlat = box(Color("181d2a"), LINE, 1, 4, 18, 9)
	var hover: StyleBoxFlat = box(Color("222939"), TEAL_DIM, 1, 4, 18, 9)
	var pressed: StyleBoxFlat = box(Color("11151e"), TEAL, 1, 4, 18, 9)
	var disabled: StyleBoxFlat = box(Color("141821"), Color("20263a"), 1, 4, 18, 9)
	for type_name: String in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", type_name, normal)
		t.set_stylebox("hover", type_name, hover)
		t.set_stylebox("pressed", type_name, pressed)
		t.set_stylebox("hover_pressed", type_name, pressed)
		t.set_stylebox("disabled", type_name, disabled)
		t.set_stylebox("focus", type_name, focus_style())
		t.set_font("font", type_name, font("semibold"))
		t.set_font_size("font_size", type_name, 17 + bump)
		t.set_color("font_color", type_name, PAPER)
		t.set_color("font_hover_color", type_name, Color("fffaf0"))
		t.set_color("font_pressed_color", type_name, TEAL)
		t.set_color("font_hover_pressed_color", type_name, TEAL)
		t.set_color("font_focus_color", type_name, Color("fffaf0"))
		t.set_color("font_disabled_color", type_name, Color(PAPER, 0.32))
		t.set_color("icon_normal_color", type_name, PAPER_DIM)
		t.set_color("icon_hover_color", type_name, PAPER)
		t.set_color("icon_pressed_color", type_name, TEAL)
		t.set_color("icon_focus_color", type_name, PAPER)
		t.set_color("icon_disabled_color", type_name, Color(PAPER, 0.3))
		t.set_constant("h_separation", type_name, 10)
	t.set_icon("arrow", "OptionButton", svg_icon("arrow", _arrow_svg(TEAL)))
	t.set_constant("arrow_margin", "OptionButton", 12)

	_variation_button(t, "PrimaryButton", box(RED, Color("e7677b"), 1, 4, 22, 11), box(Color("e25a70"), Color("f38a9a"), 1, 4, 22, 11), box(RED_DEEP, RED, 1, 4, 22, 11), Color("fff6ea"), Color("fff6ea"))
	t.set_font("font", "PrimaryButton", font("title"))
	t.set_font_size("font_size", "PrimaryButton", 20 + bump)
	_variation_button(t, "DangerButton", box(Color(0, 0, 0, 0), Color(RED, 0.7), 1, 4, 18, 9), box(Color(RED, 0.18), RED, 1, 4, 18, 9), box(Color(RED, 0.32), RED, 1, 4, 18, 9), Color("f08a9a"), Color("ffd8de"))
	_variation_button(t, "GhostButton", empty_style(10, 6), box(Color(1, 1, 1, 0.05), Color(0, 0, 0, 0), 0, 4, 10, 6), box(Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 0, 4, 10, 6), PAPER_DIM, PAPER)
	_variation_button(t, "TealButton", box(Color(TEAL, 0.12), TEAL_DIM, 1, 4, 18, 9), box(Color(TEAL, 0.22), TEAL, 1, 4, 18, 9), box(Color(TEAL, 0.32), TEAL, 1, 4, 18, 9), TEAL, Color("dff6f3"))
	var tab_normal: StyleBoxFlat = box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 16, 10)
	var tab_hover: StyleBoxFlat = box(Color(1, 1, 1, 0.04), Color(0, 0, 0, 0), 0, 0, 16, 10)
	var tab_on: StyleBoxFlat = box(Color(TEAL, 0.08), TEAL, 0, 0, 16, 10)
	tab_on.border_width_bottom = 3
	_variation_button(t, "TabButton", tab_normal, tab_hover, tab_on, PAPER_DIM, PAPER)
	t.set_font("font", "TabButton", font("caps"))
	t.set_font_size("font_size", "TabButton", 16 + bump)
	t.set_color("font_pressed_color", "TabButton", TEAL)
	t.set_color("font_hover_pressed_color", "TabButton", TEAL)

	var field: StyleBoxFlat = box(Color("0f121a"), LINE, 1, 4, 14, 10)
	var field_focus: StyleBoxFlat = box(Color("121722"), TEAL, 2, 4, 14, 10)
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", field_focus)
	t.set_stylebox("read_only", "LineEdit", box(Color("0c0e14"), Color("20263a"), 1, 4, 14, 10))
	t.set_color("font_color", "LineEdit", PAPER)
	t.set_color("font_placeholder_color", "LineEdit", Color(PAPER, 0.35))
	t.set_color("caret_color", "LineEdit", TEAL)
	t.set_color("selection_color", "LineEdit", Color(TEAL, 0.3))
	t.set_color("font_uneditable_color", "LineEdit", PAPER_DIM)
	t.set_font_size("font_size", "LineEdit", 18 + bump)
	t.set_stylebox("normal", "TextEdit", field)
	t.set_stylebox("focus", "TextEdit", field_focus)

	var popup: StyleBoxFlat = box(PANEL_SOLID, LINE, 1, 5, 6, 6)
	popup.shadow_color = Color(0, 0, 0, 0.45)
	popup.shadow_size = 12
	t.set_stylebox("panel", "PopupMenu", popup)
	t.set_stylebox("hover", "PopupMenu", box(Color(TEAL, 0.16), Color(0, 0, 0, 0), 0, 3, 8, 4))
	t.set_color("font_color", "PopupMenu", PAPER_DIM)
	t.set_color("font_hover_color", "PopupMenu", Color("fffaf0"))
	t.set_color("font_disabled_color", "PopupMenu", Color(PAPER, 0.3))
	t.set_font_size("font_size", "PopupMenu", 17 + bump)
	t.set_constant("v_separation", "PopupMenu", 12 if mobile else 8)
	t.set_constant("item_start_padding", "PopupMenu", 12)
	t.set_constant("item_end_padding", "PopupMenu", 12)
	t.set_icon("radio_checked", "PopupMenu", svg_icon("radio_on_small", _check_svg(true, false, true)))
	t.set_icon("radio_unchecked", "PopupMenu", svg_icon("radio_off_small", _check_svg(false, false, true)))

	for type_name: String in ["CheckButton", "CheckBox"]:
		t.set_stylebox("normal", type_name, empty_style(4, 6))
		t.set_stylebox("hover", type_name, box(Color(1, 1, 1, 0.035), Color(0, 0, 0, 0), 0, 4, 4, 6))
		t.set_stylebox("pressed", type_name, empty_style(4, 6))
		t.set_stylebox("hover_pressed", type_name, box(Color(1, 1, 1, 0.035), Color(0, 0, 0, 0), 0, 4, 4, 6))
		t.set_stylebox("disabled", type_name, empty_style(4, 6))
		t.set_stylebox("focus", type_name, focus_style())
		t.set_font("font", type_name, font("medium"))
		t.set_font_size("font_size", type_name, 17 + bump)
		t.set_color("font_color", type_name, PAPER_DIM)
		t.set_color("font_hover_color", type_name, PAPER)
		t.set_color("font_pressed_color", type_name, PAPER)
		t.set_color("font_hover_pressed_color", type_name, PAPER)
		t.set_color("font_focus_color", type_name, PAPER)
		t.set_color("font_disabled_color", type_name, Color(PAPER, 0.3))
		t.set_constant("h_separation", type_name, 12)
	t.set_icon("checked", "CheckButton", svg_icon("switch_on", _switch_svg(true, false)))
	t.set_icon("unchecked", "CheckButton", svg_icon("switch_off", _switch_svg(false, false)))
	t.set_icon("checked_disabled", "CheckButton", svg_icon("switch_on_d", _switch_svg(true, true)))
	t.set_icon("unchecked_disabled", "CheckButton", svg_icon("switch_off_d", _switch_svg(false, true)))
	t.set_icon("checked", "CheckBox", svg_icon("check_on", _check_svg(true, false)))
	t.set_icon("unchecked", "CheckBox", svg_icon("check_off", _check_svg(false, false)))
	t.set_icon("checked_disabled", "CheckBox", svg_icon("check_on_d", _check_svg(true, true)))
	t.set_icon("unchecked_disabled", "CheckBox", svg_icon("check_off_d", _check_svg(false, true)))
	t.set_icon("radio_checked", "CheckBox", svg_icon("radio_on", _check_svg(true, false, true)))
	t.set_icon("radio_unchecked", "CheckBox", svg_icon("radio_off", _check_svg(false, false, true)))

	var track: StyleBoxFlat = box(Color("262c3b"), Color(0, 0, 0, 0), 0, 3, 0, 0)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill: StyleBoxFlat = box(TEAL, Color(0, 0, 0, 0), 0, 3, 0, 0)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", svg_icon("grabber", _grabber_svg(Color("f4eee1"), TEAL)))
	t.set_icon("grabber_highlight", "HSlider", svg_icon("grabber_hi", _grabber_svg(Color("ffffff"), GOLD)))
	t.set_icon("grabber_disabled", "HSlider", svg_icon("grabber_off", _grabber_svg(Color("6a7080"), Color("3a4254"))))
	t.set_stylebox("focus", "HSlider", focus_style(6))
	t.set_constant("center_grabber", "HSlider", 1)

	for type_name: String in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", type_name, box(Color(1, 1, 1, 0.03), Color(0, 0, 0, 0), 0, 3, 3, 3))
		t.set_stylebox("grabber", type_name, box(Color(PAPER, 0.18), Color(0, 0, 0, 0), 0, 3, 3, 3))
		t.set_stylebox("grabber_highlight", type_name, box(Color(TEAL, 0.55), Color(0, 0, 0, 0), 0, 3, 3, 3))
		t.set_stylebox("grabber_pressed", type_name, box(TEAL, Color(0, 0, 0, 0), 0, 3, 3, 3))

	t.set_stylebox("background", "ProgressBar", box(Color("232838"), Color(0, 0, 0, 0), 0, 3, 0, 0))
	t.set_stylebox("fill", "ProgressBar", box(TEAL, Color(0, 0, 0, 0), 0, 3, 0, 0))
	t.set_color("font_color", "ProgressBar", PAPER)

	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("panel", "Panel", panel_style())
	t.set_stylebox("panel", "ScrollContainer", empty_style())

	t.set_stylebox("tab_selected", "TabBar", tab_on)
	t.set_stylebox("tab_unselected", "TabBar", tab_normal)
	t.set_stylebox("tab_hovered", "TabBar", tab_hover)
	t.set_stylebox("tab_focus", "TabBar", focus_style())
	t.set_color("font_selected_color", "TabBar", TEAL)
	t.set_color("font_unselected_color", "TabBar", PAPER_DIM)
	t.set_color("font_hovered_color", "TabBar", PAPER)
	t.set_font("font", "TabBar", font("caps"))
	for item: String in ["tab_selected", "tab_unselected", "tab_hovered", "tab_focus"]: t.set_stylebox(item, "TabContainer", t.get_stylebox(item, "TabBar"))
	t.set_stylebox("panel", "TabContainer", empty_style(0, 12))
	t.set_color("font_selected_color", "TabContainer", TEAL)
	t.set_color("font_unselected_color", "TabContainer", PAPER_DIM)
	t.set_font("font", "TabContainer", font("caps"))

	var tip: StyleBoxFlat = box(Color("0f121a"), TEAL_DIM, 1, 4, 12, 8)
	tip.shadow_color = Color(0, 0, 0, 0.4)
	tip.shadow_size = 8
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", PAPER)
	t.set_font_size("font_size", "TooltipLabel", 15 + bump)

	var line: StyleBoxLine = StyleBoxLine.new()
	line.color = LINE_SOFT
	line.thickness = 1
	t.set_stylebox("separator", "HSeparator", line)
	t.set_constant("separation", "HSeparator", 14)

	t.set_color("default_color", "RichTextLabel", PAPER)
	t.set_font("normal_font", "RichTextLabel", font("body"))
	t.set_font("bold_font", "RichTextLabel", font("semibold"))
	_theme = t
	return t

static func _variation_button(t: Theme, type_name: String, normal: StyleBox, hover: StyleBox, pressed: StyleBox, color: Color, hover_color: Color) -> void :
	t.set_type_variation(type_name, "Button")
	t.set_stylebox("normal", type_name, normal)
	t.set_stylebox("hover", type_name, hover)
	t.set_stylebox("pressed", type_name, pressed)
	t.set_stylebox("hover_pressed", type_name, pressed)
	t.set_stylebox("focus", type_name, focus_style())
	var off: StyleBox = normal.duplicate()
	if off is StyleBoxFlat:
		(off as StyleBoxFlat).bg_color = Color((off as StyleBoxFlat).bg_color, (off as StyleBoxFlat).bg_color.a * 0.4)
		(off as StyleBoxFlat).border_color = Color((off as StyleBoxFlat).border_color, (off as StyleBoxFlat).border_color.a * 0.4)
	t.set_stylebox("disabled", type_name, off)
	t.set_color("font_color", type_name, color)
	t.set_color("font_hover_color", type_name, hover_color)
	t.set_color("font_pressed_color", type_name, hover_color)
	t.set_color("font_hover_pressed_color", type_name, hover_color)
	t.set_color("font_focus_color", type_name, hover_color)
	t.set_color("font_disabled_color", type_name, Color(color, 0.35))




const INK_SHADER: String = "shader_type canvas_item;\nuniform sampler2D mask : repeat_enable, filter_linear;\nuniform float scale = 0.0055;\nuniform vec2 shift = vec2(0.31, 0.17);\nvarying vec2 local_pos;\nvoid vertex() { local_pos = VERTEX; }\nvoid fragment() { COLOR.a *= texture(mask, local_pos * scale + shift).a; }\n"

static var _ink_material: ShaderMaterial
static var _grain: Texture2D

static func ink_material() -> ShaderMaterial:
	if _ink_material: return _ink_material
	var shader: Shader = Shader.new()
	shader.code = INK_SHADER
	_ink_material = ShaderMaterial.new()
	_ink_material.shader = shader
	if ResourceLoader.exists("res://ui/tex/ink_mask.png"): _ink_material.set_shader_parameter("mask", load("res://ui/tex/ink_mask.png"))
	return _ink_material

static func grain() -> Texture2D:
	if _grain == null and ResourceLoader.exists("res://ui/tex/paper_grain.png"): _grain = load("res://ui/tex/paper_grain.png")
	return _grain

static func tr_text(text: String) -> String:
	return PaperLanguage.t(text) if PaperLanguage.language == "en" else text


static func noise(seed_value: int, index: int) -> float:
	var h: int = (seed_value * 374761393 + index * 668265263) & 2147483647
	h = ((h ^ (h >> 13)) * 1274126177) & 2147483647
	return float(h % 10000) / 10000.0


static func draw_tape(item: RID, center: Vector2, width: float, angle: float, color: Color = Color(0.96, 0.93, 0.84, 0.62), seed_value: int = 3) -> void :
	var half: Vector2 = Vector2(width * 0.5, 11)
	var points: PackedVector2Array = PackedVector2Array()
	points.append(Vector2( - half.x, - half.y))
	points.append(Vector2(half.x, - half.y))
	for i: int in range(5):
		points.append(Vector2(half.x + (noise(seed_value, i) - 0.5) * 5.0, - half.y + half.y * 2.0 * float(i + 1) / 6.0))
	points.append(Vector2(half.x, half.y))
	points.append(Vector2( - half.x, half.y))
	for i: int in range(5):
		points.append(Vector2( - half.x + (noise(seed_value, i + 9) - 0.5) * 5.0, half.y - half.y * 2.0 * float(i + 1) / 6.0))
	var rotated: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points: rotated.append(center + point.rotated(angle))
	RenderingServer.canvas_item_add_polygon(item, rotated, PackedColorArray([color]))
