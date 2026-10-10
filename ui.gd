class_name PaperUI
extends CanvasLayer




const ScreenFx = preload("res://fx_screen.gd")
const T = preload("res://ui_theme.gd")
const W = preload("res://ui_widgets.gd")
const Icons = preload("res://ui_icons.gd")
const Sound = preload("res://ui_sound.gd")
const HudScript = preload("res://ui_hud.gd")
const MenuBackdrop = preload("res://ui_menu_backdrop.gd")
const MenuLogo = preload("res://ui_menu_logo.gd")
const MenuWipe = preload("res://ui_menu_wipe.gd")
const MenuVignettes = preload("res://ui_menu_vignettes.gd")
const MenuFx = preload("res://ui_menu_fx.gd")
const PauseMenu = preload("res://ui_pause_menu.gd")
const PAGE_TITLES: Dictionary = {"main": "MENU", "characters": "ÉLÈVES", "alice": "ALICE", "maps": "CARTES", "network": "EN LIGNE", "connecting": "CONNEXION", "advanced": "RÉSEAU", "lobby": "SALON", "settings": "RÉGLAGES", "credits": "CRÉDITS", "shop": "BOUTIQUE", "gallery": "CINÉMA"}

const MENU_PAGES: Array[String] = ["main", "characters", "alice", "maps", "network", "connecting", "advanced", "lobby", "settings", "credits", "shop"]

const VERSION_TEXT: String = "v0.15  ·  OM  ·  PC + Android"
const INK = Color("15171c")
const PAPER = Color("ece5d5")
const MUTED = Color("a9acac")
const RED = Color("d6455d")
const TEAL = Color("87c9c4")
const MAP_LINES: Dictionary = {"school": "L'école de Miss Circle sur deux étages : un atrium et ses deux escaliers, un couloir de casiers en boucle, des classes à deux portes. Les portes offrent à Alice des occasions de condamner un passage.", "forest": "Les bois derrière l'école : la fosse et son pont cassé, la serre de Miss Bloomie, la cabane perchée et les haies. La sortie est au portail du bus.", "snow": "La classe de neige : un chalet sur deux étages relié à la crête par une passerelle, des chalets à deux portes, un étang gelé à découvert. On s'échappe par le téléphérique."}
const MAP_SHORT: Dictionary = {"school": "Atrium, classes, bibliothèque, gymnase.", "forest": "Fosse, pont cassé, serre, cabane perchée.", "snow": "Chalet, passerelle, étang gelé, téléphérique."}
const MAP_TAGLINES: Dictionary = {"school": "Les couloirs gardent leurs secrets.", "forest": "Dans les bois, chaque bruit compte.", "snow": "La neige étouffe les pas. Pas la peur."}
const TIPS: Array[String] = [
	"La sortie s’ouvre à 01:20 : il faut l’atteindre pour gagner, attendre ne suffit pas.", 
	"Un allié au sol se relève immédiatement avec E. Lysia, elle, ne peut pas être réanimée.", 
	"Simon et Ashura : maintenez la capacité 2 pour charger. Trois secondes de charge donnent six secondes de boost.", 
	"Après chaque étourdissement, Alice résiste aux nouveaux stuns pendant 5 secondes : espacez vos attaques.", 
	"15 étourdissements débloquent la True Form d’Alice : 30 secondes, chrono suspendu, sortie fermée.", 
	"Le LMS dure le temps de la musique du dernier survivant. Une aura pleine garde la sortie ouverte.", 
	"Aidez l’équipe pour remplir votre aura : soins, boosts, protections et stuns comptent.", 
	"Archives : maintenez E, puis appuyez sur la bonne touche J, K ou L. Une erreur déclenche l’alarme.", 
	"Lysia se recharge aux prises murales et mange les épaves de drone pour 7 PV.", 
	"Elly entend les capacités d’Alice partout dans l’école.", 
]


var film_layer: Control
var film_chapter: Label
var film_caption: Label
var film_black: ColorRect
var world: Node
var root: Control
var page: Control
var hud: Control
var overlay: Control
var toast_label: Label
var toast_time: float = 0.0
var title_label: Label
var subtitle_label: Label
var announce_time: float = 0.0
var damage_flash: float = 0
var blind_flash: float = 0
var flash: ColorRect
var qte_panel: PanelContainer
var qte_actor: int = -1
var qte_time: float = 0
var qte_started: float = 0
var qte_bar: ProgressBar
var qte_hint: Label
var qte_choice: String = "health"
var reduced_motion: bool = false
var current_page: String = "main"
var survivor_roster: PaperSurvivorRoster
var combat_feedback: PaperCombatFeedback

var screen_fx: ScreenFx
var result_view: PaperResultsView
var result_detail: Label
var loading_label: Label
var loading_bar: ProgressBar
var connection_label: Label
var lobby_map: Label
var lobby_options: Label
var lobby_names: Label
var performance_label: Label
var active_menu_panel: PanelContainer
var last_keyboard_height: float = -1
var menu_paper: bool = false
var gallery_controls: Control
var gallery_timeline: HSlider
var gallery_clock: Label
var gallery_pause: Button
var gallery_results: VBoxContainer
var gallery_count: Label
var gallery_updating: bool = false
var gallery_dragging: bool = false
var gallery_resume: bool = false
var language_clock: float = 0


var sound: Node
var _hud: HudScript
var _toasts: Array[Dictionary] = []
var _toast_box: VBoxContainer
var _pointer: bool = true
var _language_seen: String = "fr"
var _quiet_page: bool = false
var _page_serial: int = 0
var _nav_hint: Label
var setup_role: String = "survivor"
var setup_choice: String = "Ashura"
var setup_cards: Array = []
var setup_info: VBoxContainer
var setup_cta: Button
var setup_summary: Label
var setup_mark: Label
var settings_tab: String = "game"
var _preset_note: Label
var lobby_list: VBoxContainer
var loading_tip: Label
var _tip_start: int = 0
var _tip_index: int = -1
var _loading_art: TextureRect
var _result_rows: Array = []
var _result_stamp: Control
var _result_name: Label
var _result_player: Label
var _qte_zone: TimingBar
var _pause_confirm: bool = false


var menu_backdrop: Control
var menu_vignettes: Control
var shop_selected: String = ""
var _leaving: Control
var _wipe: Control
var _backdrop_active: bool = false
var _default_hint: String = ""

var _last_focus: WeakRef

# Menus 0.16 (esprit Persona) : animation commune, listes à faire entrer en
# cascade à la fin de la page, menu pause, transition en cours.
var fx: MenuFx
var _cascade_lists: Array = []
var _pause_menu: Control
var _wipe_hold: bool = false
var _wipe_action: Callable = Callable()
var _tab_direction: float = 1.0
var _page_rerender: bool = false
var _page_focus: WeakRef = weakref(null)
var _setup_dealt: String = ""
const SETTINGS_TABS: Array = ["game", "display", "audio", "controls", "access"]


class TimingBar extends Control:

	var value: float = 0.0
	func _draw() -> void :
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		draw_rect(r, Color("1c2230"))
		draw_rect(Rect2(Vector2(size.x * 0.4, 0), Vector2(size.x * 0.25, size.y)), Color(0.53, 0.79, 0.77, 0.45))
		draw_rect(Rect2(Vector2(size.x * 0.4, 0), Vector2(2, size.y)), Color("87c9c4"))
		draw_rect(Rect2(Vector2(size.x * 0.65 - 2, 0), Vector2(2, size.y)), Color("87c9c4"))
		var x: float = size.x * clampf(value, 0, 1)
		draw_rect(Rect2(Vector2(x - 2, -4), Vector2(4, size.y + 8)), Color("f2c46d"))


func setup(game_world: Node) -> void :
	world = game_world
	layer = 10
	reduced_motion = bool(world.options.get("reduce_flashes", false))
	root = Control.new()
	root.name = "UIRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = T.theme(world.mobile_mode)
	add_child(root)
	screen_fx = ScreenFx.new()
	root.add_child(screen_fx)
	screen_fx.setup(world)
	sound = Sound.new()
	add_child(sound)
	sound.setup(world)
	fx = MenuFx.new()
	add_child(fx)
	fx.setup(self)
	page = Control.new()
	page.name = "Page"
	root.add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_menu_layers()
	_hud = HudScript.new()
	hud = _hud
	root.add_child(hud)
	_hud.setup(self)
	survivor_roster = _hud.roster
	title_label = _hud.title_label
	subtitle_label = _hud.subtitle_label
	overlay = Control.new()
	overlay.name = "Overlay"
	root.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wipe = MenuWipe.new()
	_wipe.name = "PageWipe"
	root.add_child(_wipe)
	_wipe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wipe.covered.connect(_on_wipe_covered)
	_build_film()
	_build_toasts()
	flash = ColorRect.new()
	root.add_child(flash)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1, 0, 0, 0)
	combat_feedback = PaperCombatFeedback.new()
	hud.add_child(combat_feedback)
	_build_qte_assist()
	performance_label = _label("", "num", 13, T.PAPER_DIM)
	root.add_child(performance_label)
	performance_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	performance_label.offset_left = -260
	performance_label.offset_right = -20
	performance_label.offset_top = 12
	performance_label.offset_bottom = 30
	performance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_shadow(performance_label)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	_language_seen = PaperLanguage.language




func _t(text: String) -> String:
	return PaperLanguage.t(text) if PaperLanguage.language == "en" else text

func _sfx(kind: String) -> void :
	Sound.play(kind)

func _label(text: String, font_kind: String = "body", size: int = 18, color: Color = T.PAPER) -> Label:
	var l: Label = Label.new()
	l.text = _touch_text(text)
	l.add_theme_font_override("font", T.font(font_kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _paragraph(text: String, parent: Node, size: int = 17, color: Color = T.PAPER_DIM, font_kind: String = "body") -> Label:
	var l: Label = _label(text, font_kind, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
	return l

func _kicker(text: String, color: Color = T.TEAL, size: int = 13) -> Label:
	return _label(text, "caps_wide", size, color)

func _shadow(label: Label, alpha: float = 0.55) -> void :
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, alpha))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("shadow_outline_size", 5)

func _button(text: String, action: Callable, width: float = 0, variation: String = "") -> Button:
	var b: Button = Button.new()
	b.text = text
	if not variation.is_empty(): b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(width, 58 if world.mobile_mode else 46)
	if world.mobile_mode and width > 0: b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.pressed.connect(action)
	b.pressed.connect(_sfx.bind("confirm" if variation == "PrimaryButton" else "back" if text.begins_with("←") or text in ["RETOUR", "ANNULER"] else "click"))
	b.mouse_entered.connect(_sfx.bind("hover"))
	return b

func _vbox(parent: Node, gap: int = 12) -> VBoxContainer:
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", gap)
	parent.add_child(v)
	return v

func _hbox(parent: Node, gap: int = 12) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", gap)
	parent.add_child(h)
	return h

func _spacer(parent: Node, height: float) -> Control:
	var c: Control = Control.new()
	c.custom_minimum_size.y = height
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c

func _clear(container: Node) -> void :
	for c: Node in container.get_children():
		container.remove_child(c)
		c.queue_free()

func _icon_rect(icon_name: String, size_px: float, tint: Color) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.texture = Icons.icon(icon_name)
	rect.custom_minimum_size = Vector2(size_px, size_px)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.modulate = tint
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _badge(texture: Texture2D, size_px: float, bg: Color, tint: Color) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = T.box(bg, Color(0, 0, 0, 0), 0, int(size_px * 0.5), 0, 0)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(size_px, size_px)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rect: TextureRect = TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.custom_minimum_size = Vector2(size_px * 0.62, size_px * 0.62)
	rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.modulate = tint
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(rect)
	return panel

func _paper_style(seed_value: int, margin: float = 22.0, tape: bool = false) -> W.PaperStyle:
	var style: W.PaperStyle = W.PaperStyle.new(margin)
	style.seed_value = seed_value
	style.tape = tape
	return style

func _set_focus_x(value: float) -> void :
	if "menu_focus_x" in world: world.set("menu_focus_x", value)

func _binding(action: String, fallback: String) -> String:
	return key_label(action, fallback)



static func key_label(action: String, fallback: String) -> String:
	if not InputMap.has_action(action): return fallback
	for event: InputEvent in InputMap.action_get_events(action):
		var label: String = ""
		if event is InputEventKey:
			var key: InputEventKey = event
			var code: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
			if code >= KEY_0 and code <= KEY_9: label = str(code - KEY_0)
			else: label = OS.get_keycode_string(code)

			if code >= KEY_A and code <= KEY_Z and key.physical_keycode != KEY_NONE and DisplayServer.get_name() in ["Windows", "macOS", "X11", "Wayland"]:
				var local: Key = DisplayServer.keyboard_get_label_from_physical(code)
				if local >= KEY_A and local <= KEY_Z: label = OS.get_keycode_string(local)
		elif event is InputEventMouseButton:
			var mouse: InputEventMouseButton = event
			label = "Clic G" if mouse.button_index == MOUSE_BUTTON_LEFT else "Clic D" if mouse.button_index == MOUSE_BUTTON_RIGHT else "Souris %d" % mouse.button_index
		if label.is_empty(): continue
		if PaperLanguage.language == "en": return {"Clic G": "LMB", "Clic D": "RMB"}.get(label, label.replace("Souris", "Mouse"))
		return {"Shift": "Maj", "Space": "Espace", "Escape": "Échap", "CapsLock": "Verr. Maj", "Enter": "Entrée", "Up": "Haut", "Down": "Bas", "Left": "Gauche", "Right": "Droite"}.get(label, label)
	return fallback


func _backdrop(width_ratio: float, strength: float = 0.95, parent: Control = null) -> void :
	var target: Control = parent if parent else page
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(T.BG, strength))
	gradient.set_color(1, Color(T.BG, 0.0))
	gradient.add_point(0.55, Color(T.BG, strength * 0.82))
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 4
	var shade: TextureRect = TextureRect.new()
	shade.texture = texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.add_child(shade)
	shade.anchor_left = 0
	shade.anchor_top = 0
	shade.anchor_bottom = 1
	shade.anchor_right = width_ratio
	var bottom: Gradient = Gradient.new()
	bottom.set_color(0, Color(T.BG, 0.0))
	bottom.set_color(1, Color(T.BG, 0.7))
	var bottom_texture: GradientTexture2D = GradientTexture2D.new()
	bottom_texture.gradient = bottom
	bottom_texture.fill_from = Vector2(0, 0)
	bottom_texture.fill_to = Vector2(0, 1)
	bottom_texture.width = 4
	bottom_texture.height = 128
	var floor_shade: TextureRect = TextureRect.new()
	floor_shade.texture = bottom_texture
	floor_shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	floor_shade.stretch_mode = TextureRect.STRETCH_SCALE
	floor_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.add_child(floor_shade)
	floor_shade.anchor_left = 0
	floor_shade.anchor_right = 1
	floor_shade.anchor_top = 0.72
	floor_shade.anchor_bottom = 1

func _dim(parent: Control, alpha: float = 0.78) -> ColorRect:
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.02, 0.025, 0.04, alpha)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return shade


func _begin_page(id: String, preview: String = "", focus_x: float = 0.66) -> void :
	var previous: String = current_page
	current_page = id
	menu_paper = false
	_page_serial += 1
	var animate: bool = previous != id and not reduced_motion and world.phase in ["menu", "lobby"] and previous in MENU_PAGES and id in MENU_PAGES and page.visible and page.get_child_count() > 0
	_cascade_lists.clear()
	# Même page reconstruite (aperçu de danse, choix de carte…) : pas de
	# nouvelle entrée en cascade ni de glissement du panneau.
	_page_rerender = previous == id and not _quiet_page
	_retire_decors(animate)
	if animate: _retire_page(id)
	else:
		if is_instance_valid(_wipe) and not _wipe_hold: _wipe.stop()
		_clear(_leaving)
		_clear(page)
		page.modulate.a = 1.0
		if reduced_motion and previous != id and not _quiet_page: _soft_fade(page)
	_clear(overlay)
	if not animate and not reduced_motion and not _wipe_hold and previous != id and id in MENU_PAGES and previous in ["loading", "ending", "gallery"] and world.phase in ["menu", "lobby"]:
		_wipe.reveal(1.0, str(PAGE_TITLES.get(id, "")))
	_set_backdrop_mode(id, preview, 0.22 if animate else 0.0)
	hud.hide()
	page.show()
	active_menu_panel = null
	last_keyboard_height = -1
	setup_cards.clear()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if world.mobile_mode:
		Input.emulate_mouse_from_touch = true
		if world.mobile_controls:
			world.mobile_controls.enabled = false
			world.mobile_controls.cancel_all()
	world.preview_character = preview
	_set_focus_x(focus_x)
	if animate: Sound.play("swoosh")
	elif previous != id and not _quiet_page and world.phase in ["menu", "lobby", "gallery"]: Sound.play("page")


func _end_page(focus_target: Control = null) -> void :
	_page_focus = weakref(focus_target)
	if PaperLanguage.language == "en": PaperLanguage.apply_tree(page)
	if focus_target and ( not _pointer or not Input.get_connected_joypads().is_empty()): focus_target.call_deferred("grab_focus")
	_run_cascade()

# Les listes enregistrées (formulaires, réglages, menu principal…) entrent en
# cascade, après la transition si elle couvre encore l'écran.
func _run_cascade(extra_delay: float = 0.0) -> void :
	if not is_instance_valid(fx): return
	if _page_rerender:
		_cascade_lists.clear()
		return
	var delay: float = extra_delay + (_wipe.time_to_cover() + 0.06 if is_instance_valid(_wipe) and _wipe.busy() else 0.0)
	for entry: Variant in _cascade_lists:
		if entry is Dictionary:
			delay = fx.cascade_children(entry.node, delay, float(entry.get("step", 0.03)), entry.get("from", Vector2(-64, 0)), float(entry.get("tilt", -0.07)), float(entry.get("duration", 0.26)))
		else: delay = fx.cascade_children(entry, delay)
	_cascade_lists.clear()

func _cascade(node: Node, from: Vector2 = Vector2(-64, 0), tilt: float = -0.07, step: float = 0.03, duration: float = 0.26) -> void :
	if is_instance_valid(node): _cascade_lists.append({"node": node, "from": from, "tilt": tilt, "step": step, "duration": duration})

func _soft_fade(node: CanvasItem) -> void :
	if not is_instance_valid(node): return
	node.modulate.a = 0.0
	node.create_tween().tween_property(node, "modulate:a", 1.0, 0.16)

# Entrée d'un panneau : il glisse, pivote et se pose avec un léger dépassement.
func _intro(node: CanvasItem, dx: float = -22.0) -> void :
	if reduced_motion or not is_instance_valid(node) or _page_rerender or (_quiet_page and node.get_parent() == page): return
	var control: Control = node as Control
	node.modulate.a = 0.0
	var delay: float = _wipe.time_to_cover() if is_instance_valid(_wipe) and _wipe.busy() else 0.0
	var tween: Tween = node.create_tween().set_parallel()
	tween.tween_property(node, "modulate:a", 1.0, 0.16).set_delay(delay)
	if control and control.get_parent() == page:
		var goal: float = control.position.x
		var turn: float = control.rotation
		control.position.x = goal + (dx * 4.0 if dx != 0.0 else -60.0)
		control.rotation = turn - 0.05 * (1.0 if dx <= 0.0 else -1.0)
		tween.tween_property(control, "position:x", goal, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
		tween.tween_property(control, "rotation", turn, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)



func _form_panel(width: float = 620) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBox = T.sheet_style(34, 30, T.RED_DEEP, _page_serial % 7 + 11)
	style.content_margin_left = 40
	style.content_margin_right = 30
	style.content_margin_top = 30
	style.content_margin_bottom = 26
	panel.add_theme_stylebox_override("panel", style)
	page.add_child(panel)
	panel.anchor_left = 0
	panel.anchor_right = 0
	panel.anchor_top = 0
	panel.anchor_bottom = 1
	var left: float = 40.0
	if world.mobile_mode: left = mobile_safe_edges().x + 18.0
	panel.offset_left = left
	panel.offset_right = left + width
	panel.offset_top = 28 if not world.mobile_mode else 16
	panel.offset_bottom = -28 if not world.mobile_mode else -16
	active_menu_panel = panel
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var v: VBoxContainer = _vbox(scroll, 12)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_intro(panel)
	_cascade(v)
	return v

func _form_header(parent: Node, kicker: String, title: String, kicker_color: Color = T.TEAL) -> void :
	parent.add_child(_kicker(kicker, kicker_color))
	parent.add_child(_display_title(title, 50))
	var rule: W.Rule = W.Rule.new()
	rule.accent = kicker_color
	parent.add_child(rule)
	_page_decor(title, T.RED if kicker_color == T.RED else T.RED_DEEP.lerp(kicker_color, 0.25))

# Titre de page en lettres découpées (collage), traduit au dessin.
func _display_title(title: String, size: int = 50, accent: Color = T.RED, width: float = 560.0) -> Control:
	var label: W.CollageTitle = W.CollageTitle.new()
	label.setup(title, float(size) * 0.92, accent, width)
	return label

func _local_person() -> String:
	var actor: Node = world.local_actor() if world.phase == "playing" and world.has_method("local_actor") else null
	if actor: return str(actor.get("character"))
	return "Alice" if world.solo_killer and not world.networked else str(world.selected)

# Découpe papier d'un personnage qui glisse depuis le bord droit (silhouette
# d'encre révélée au pinceau), derrière le panneau de la page.
func _page_art(person: String, center_x: float, instant: bool = false) -> TextureRect:
	var texture: Texture2D = MenuBackdrop.art(person)
	if texture == null: return null
	var view: Vector2 = get_viewport().get_visible_rect().size
	var art: TextureRect = TextureRect.new()
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var height: float = view.y * (1.0 if person == "Alice" else 0.94)
	var width: float = height * float(texture.get_width()) / float(texture.get_height())
	page.add_child(art)
	art.position = Vector2(center_x - width * 0.5, view.y - height + 12.0)
	art.size = Vector2(width, height)
	art.pivot_offset = Vector2(width * 0.5, height)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = preload("res://ui_menu_cutout.gdshader")
	material.set_shader_parameter("mask", MenuBackdrop.art("ink_noise"))
	material.set_shader_parameter("edge_color", MenuBackdrop.accent_for(person))
	material.set_shader_parameter("reveal", 1.0 if reduced_motion or instant else 0.0)
	art.material = material
	if reduced_motion or instant: return art
	var delay: float = _wipe.time_to_cover() if is_instance_valid(_wipe) and _wipe.busy() else 0.0
	var goal: float = art.position.x
	art.position.x = goal + 260.0
	art.rotation = 0.06
	var tween: Tween = art.create_tween().set_parallel()
	tween.tween_property(art, "position:x", goal, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
	tween.tween_property(art, "rotation", 0.0, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
	tween.tween_method(func(value: float) -> void : material.set_shader_parameter("reveal", value), 0.0, 1.0, 0.5).set_delay(delay + 0.05)
	return art

# Décor animé derrière le panneau : bande diagonale, mot géant, ruban.
func _page_decor(title: String, accent: Color = T.RED_DEEP, side: float = 1.0) -> Control:
	var decor: MenuFx.Decor = MenuFx.Decor.new()
	decor.title = title
	decor.accent = accent
	decor.side = side
	decor.reduced = reduced_motion
	_place_decor(decor)
	return decor

# Les décors vont derrière les personnages du fond de menu (et sous les scènes
# 3D animées) ; en partie (réglages par-dessus le jeu), dans la page.
func _place_decor(decor: Control) -> void :
	if _decor_in_backdrop():
		menu_backdrop.decor_holder.add_child(decor)
		return
	if world.phase == "gallery" and decor is MenuFx.Decor:
		# Devant le film de la cinémathèque : seulement le ruban qui défile.
		(decor as MenuFx.Decor).band_alpha = 0.0
		(decor as MenuFx.Decor).giant_alpha = 0.0
	page.add_child(decor)
	if is_instance_valid(active_menu_panel) and active_menu_panel.get_parent() == page: page.move_child(decor, active_menu_panel.get_index())

func _decor_in_backdrop() -> bool:
	return is_instance_valid(menu_backdrop) and is_instance_valid(menu_backdrop.get("decor_holder")) and world.phase in ["menu", "lobby"] and menu_backdrop.mode != "hidden"

# Décors de la page précédente : gardés jusqu'à ce que la transition couvre
# l'écran, sinon retirés tout de suite.
func _retire_decors(keep: bool) -> void :
	if not is_instance_valid(menu_backdrop) or not is_instance_valid(menu_backdrop.get("decor_holder")): return
	var holder: Control = menu_backdrop.decor_holder
	for child: Node in holder.get_children():
		if child.has_meta("decor_leaving") or not keep:
			holder.remove_child(child)
			child.queue_free()
		else: child.set_meta("decor_leaving", true)

func _section(parent: Node, text: String, color: Color = T.TEAL) -> void :
	_spacer(parent, 4)
	parent.add_child(_kicker(text, color, 12))

func _field(placeholder: String, value: String = "", max_length: int = 0) -> LineEdit:
	var field: LineEdit = LineEdit.new()
	field.placeholder_text = placeholder
	field.text = value
	if max_length > 0: field.max_length = max_length
	field.custom_minimum_size.y = 56 if world.mobile_mode else 46
	return field




func _build_menu_layers() -> void :

	if not bool(world.get("dedicated")):
		menu_backdrop = MenuBackdrop.new()
		root.add_child(menu_backdrop)
		root.move_child(menu_backdrop, 0)
		menu_backdrop.setup(self, world.mobile_mode)
		menu_backdrop.character_chosen.connect(_on_lineup_chosen)
		menu_backdrop.character_hovered.connect(_on_lineup_hovered)
		if not world.mobile_mode:

			menu_vignettes = MenuVignettes.new()
			root.add_child(menu_vignettes)
			root.move_child(menu_vignettes, 1)
			menu_vignettes.setup(self)

	_leaving = Control.new()
	_leaving.name = "LeavingPage"
	_leaving.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_leaving.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(_leaving)
	_leaving.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _set_backdrop_mode(id: String, preview: String, delay: float = 0.0) -> void :
	if not is_instance_valid(menu_backdrop): return
	match id:
		"main": menu_backdrop.set_mode("main")
		"characters": menu_backdrop.set_mode("setup", preview, delay)
		"alice": menu_backdrop.set_mode("alice", "Alice", delay)
		"settings": menu_backdrop.set_mode("settings")
		"gallery": menu_backdrop.set_mode("hidden")
		_: menu_backdrop.set_mode("panel")


func _retire_page(next_id: String) -> void :
	_clear(_leaving)
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus and page.is_ancestor_of(focus): focus.release_focus()
	for child: Node in page.get_children():
		page.remove_child(child)
		_leaving.add_child(child)

	var direction: float = 1.0 if next_id in ["main", "lobby"] else -1.0
	_leaving.position = Vector2.ZERO
	_leaving.modulate = Color.WHITE
	_leaving.pivot_offset = Vector2(0, _leaving.size.y)
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(_leaving, "position:x", 140.0 * direction, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_leaving, "rotation", 0.03 * direction, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_leaving, "modulate:a", 0.2, 0.2)

	page.modulate.a = 0.0
	_wipe.play(direction, next_id == "alice", str(PAGE_TITLES.get(next_id, "")))

func _on_wipe_covered() -> void :
	_clear(_leaving)
	_retire_decors_leaving()
	_leaving.position = Vector2.ZERO
	_leaving.rotation = 0.0
	_leaving.modulate = Color.WHITE
	page.modulate.a = 1.0
	if _wipe_action.is_valid():
		var action: Callable = _wipe_action
		_wipe_action = Callable()
		_wipe_hold = true
		action.call()
		_wipe_hold = false

func _retire_decors_leaving() -> void :
	if not is_instance_valid(menu_backdrop) or not is_instance_valid(menu_backdrop.get("decor_holder")): return
	for child: Node in menu_backdrop.decor_holder.get_children():
		if child.has_meta("decor_leaving"):
			child.get_parent().remove_child(child)
			child.queue_free()

# Transition « feuilles » vers un écran qui ne passe pas par le fond de menu
# (pause → réglages, réglages → pause…) : l'action construit l'écran suivant
# quand l'écran est couvert.
func transition(action: Callable, title: String = "", direction: float = -1.0) -> void :
	if reduced_motion or not is_instance_valid(_wipe):
		action.call()
		return
	_wipe_action = action
	_wipe.play(direction, false, title)
	Sound.play("swoosh")



func _update_backdrop() -> void :
	if not is_instance_valid(menu_backdrop): return
	var active: bool = world.phase in ["menu", "lobby"] and page.visible and current_page in MENU_PAGES and menu_backdrop.mode != "hidden"
	if not active and page.modulate.a < 1.0:

		_wipe.stop()
		page.modulate.a = 1.0
	var stage: Node3D = world.get("stage") as Node3D

	if active and is_instance_valid(stage) and stage.visible: stage.visible = false
	if active == _backdrop_active: return
	_backdrop_active = active
	menu_backdrop.visible = active
	get_viewport().disable_3d = active
	if is_instance_valid(stage): stage.visible = not active and world.phase in ["menu", "lobby"]
	if not active: _clear(_leaving)


func _on_lineup_chosen(person: String) -> void :
	if current_page != "main" or world.networked: return
	if person == "Alice":
		world.solo_killer = true
		world.save_preferences()
		_show_setup("alice", -1)
		return
	world.solo_killer = false
	world.selected = person
	world.update_selection()
	world.save_preferences()
	_show_setup("survivor", PaperData.NAMES.find(person))

func _on_lineup_hovered(person: String) -> void :
	if current_page != "main" or not is_instance_valid(_nav_hint): return
	if person.is_empty():
		_nav_hint.text = _t(_default_hint)
		return
	var stats: Array = PaperData.STATS.get(person, [])
	var role: String = str(stats[3]) if stats.size() > 3 else ""
	_nav_hint.text = person.to_upper() + "  ·  " + _t(role) + "  —  " + _t("Clique pour préparer une manche avec ce personnage.")




func show_main() -> void :
	_setup_dealt = ""
	if world.mobile_mode:
		_show_mobile_main()
		return
	_begin_page("main", "", 0.66)
	_backdrop(0.5, 0.78)
	_main_decor()
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(column)
	column.anchor_top = 0
	column.anchor_bottom = 1
	column.offset_left = 76
	column.offset_right = 76 + 580
	column.offset_top = 62
	column.offset_bottom = -96
	var first: Control = _main_column(column, false)
	if first: _cascade(first.get_parent(), Vector2(-240, 30), -0.5, 0.038, 0.26)
	_add_version(76.0)
	_add_loadout_note(false)
	_intro(column)
	_end_page(first)

# Fond du menu principal : grande bande d'encre déchirée derrière la liste
# (contraste façon Persona), liseré rouge et ruban qui défile.
func _main_decor() -> void :
	var decor: MenuFx.Decor = MenuFx.Decor.new()
	decor.reduced = reduced_motion
	decor.title = ""
	decor.band_a = Vector2(0.05, 1.12)
	decor.band_b = Vector2(0.3, -0.12)
	decor.band_width = 640.0
	decor.band_alpha = 0.85
	decor.band_fill = Color(0.012, 0.013, 0.022, 0.84)
	decor.accent = T.RED
	decor.ribbon_text = "DOSSIER 013  ·  LA SONNERIE NE VOUS SAUVERA PAS"
	_place_decor(decor)


func _main_column(column: VBoxContainer, mobile: bool) -> Control:
	column.add_child(_kicker("DOSSIER 013  ·  OUTCOME MEMORIES", T.TEAL, 12 if mobile else 13))
	_spacer(column, 4 if mobile else 8)


	var logo: Control = MenuLogo.new()
	column.add_child(logo)
	logo.configure("La sonnerie ne vous sauvera pas.", mobile, reduced_motion)
	_spacer(column, 14 if mobile else 30)
	var nav: VBoxContainer = _vbox(column, 0)
	var entries: Array = [
		["JOUER", "play", "Préparer une manche solo contre les bots : rôle, personnage et carte."], 
		["ENTRE AMIS", "friends", "Salon Internet par code, connexion directe, comptes et groupes."], 
		["TERRAIN D’ESSAI", "training", "École ouverte sans chrono : teste chaque capacité, le LMS et la True Form."], 
		["CINÉMATHÈQUE", "gallery", "Introductions, fins d’équipe et LMS."], 
		["BOUTIQUE", "shop", "Des danses à acheter avec tes tickets, à faire en partie (roue des émotes, Tab)."], 
		["RÉGLAGES", "settings", "Jeu, graphismes, audio, commandes et accessibilité."], 
		["CRÉDITS", "credits", "Musiques, bruitages, polices et icônes."], 
	]
	if not mobile:

		entries = [entries[0], entries[2], entries[1], entries[4], entries[3], entries[5], entries[6], ["QUITTER", "quit", "Fermer Paper Afterbell."]]
	var first: Control = null
	for entry: Array in entries:
		var item: W.NavItem = W.NavItem.new()
		item.text = str(entry[0])
		item.hint = str(entry[2])
		item.reduced_motion = reduced_motion
		var primary: bool = entry[1] == "play"
		var accent: Color = T.RED if primary else T.MUTED if entry[1] == "quit" else T.TEAL
		item.configure((38 if mobile else 46) if primary else (24 if mobile else 27), accent, primary)
		_fan_item(item, nav.get_child_count(), str(entry[1]))
		item.pressed.connect(_main_action.bind(str(entry[1])))
		item.pressed.connect(_sfx.bind("confirm" if primary else "click"))
		item.hinted.connect(_on_nav_hint)
		item.hinted.connect(_on_nav_vignette.bind(str(entry[1])))
		nav.add_child(item)
		if first == null: first = item
	if not mobile:
		_spacer(column, 10)
		_nav_hint = _paragraph("", column, 16, T.INK_TEXT, "semibold")
		_nav_hint.custom_minimum_size = Vector2(470, 30)
		_nav_hint.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var hint_strip: StyleBox = T.strip(T.CREAM, 16, 6, 9.0, 33)
		hint_strip.set("shadow", Color(T.RED, 0.9))
		hint_strip.set("shadow_offset", Vector2(5, 5))
		_nav_hint.add_theme_stylebox_override("normal", hint_strip)
		_default_hint = str(entries[0][2])
		_on_nav_hint(_default_hint)
	return first

# Liste de commandes en éventail : chaque entrée penche un peu différemment
# et se décale, la découpe derrière l'entrée sélectionnée prend la couleur de
# sa scène animée.
func _fan_item(item: W.NavItem, index: int, action: String) -> void :
	var tilts: Array = [-7.0, -3.0, -5.5, -2.0, -4.5, -1.0, -3.5, -0.5]
	var shifts: Array = [0.0, 22.0, 10.0, 30.0, 16.0, 36.0, 24.0, 42.0]
	item.tilt_deg = float(tilts[index % tilts.size()])
	item.arc_x = float(shifts[index % shifts.size()])
	item.cut_color = MenuVignettes.ACCENTS.get(action, T.RED) if action != "play" else T.RED
	# Lettres découpées plus grandes, lignes plus serrées (elles se chevauchent
	# un peu quand l'entrée sélectionnée grossit, comme dans Persona).
	var big: bool = action == "play"
	item.font_size_px = (50 if world.mobile_mode else 60) if big else (29 if world.mobile_mode else 34)
	item.custom_minimum_size.y = roundf(float(item.font_size_px) * (1.3 if big else 1.28))

func _on_nav_vignette(text: String, action: String) -> void :
	if is_instance_valid(menu_vignettes): menu_vignettes.hover(action if not text.is_empty() else "")



func show_shop() -> void :
	_begin_page("shop", "", 0.66)
	_backdrop(0.5, 0.82)
	var v: VBoxContainer = _form_panel(600)
	_form_header(v, "DANSES  ·  ÉMOTES", "Boutique")
	v.add_child(_label("TICKETS  :  %d" % world.tickets, "title", 26, T.TEAL))
	_paragraph("Chaque manche rapporte des tickets (+30, plus ton score, plus un bonus si ton camp gagne). En partie, les danses sont dans la roue des émotes (G), page DANSES (Tab). Deux personnages sur la même danse se synchronisent, musique comprise.", v, 15, T.PAPER_DIM)
	var first: Control = null
	if shop_selected.is_empty(): shop_selected = str(PaperDances.LIST[0].id)
	for entry: Dictionary in PaperDances.LIST:
		var id: String = str(entry.id)
		var row: HBoxContainer = _list_row(v, 10)
		var text: VBoxContainer = _vbox(row, 1)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_child(_label(str(entry.name).to_upper() + "   ·   " + str(entry.tag), "title", 19, T.PAPER if id != shop_selected else T.TEAL))
		var line: Label = _paragraph(str(entry.desc), text, 14, T.PAPER_DIM)
		line.custom_minimum_size.x = 300
		var preview: Button = _button("APERÇU", func() -> void :
			shop_selected = id
			show_shop(), 110, "GhostButton")
		row.add_child(preview)
		var owned: bool = world.owned_dances.has(id)
		var buy: Button = _button("✓ À TOI" if owned else "%d TICKETS" % int(entry.price), func() -> void :
			if world.owned_dances.has(id): return
			if world.tickets < int(entry.price):
				toast("Pas assez de tickets : joue une manche pour en gagner.", 4)
				return
			world.tickets -= int(entry.price)
			world.owned_dances.append(id)
			world.save_preferences()
			_sfx("confirm")
			shop_selected = id
			show_shop(), 150)
		buy.disabled = owned
		row.add_child(buy)
		if first == null: first = preview
	_spacer(v, 6)
	var back: Button = _button("←  RETOUR", show_main, 160)
	v.add_child(back)
	_end_page(first)
	if is_instance_valid(menu_vignettes): menu_vignettes.preview_dance(str(world.selected), shop_selected)


func _on_nav_hint(text: String) -> void :
	if is_instance_valid(_nav_hint): _nav_hint.text = _t(text if not text.is_empty() else _default_hint)

func _main_action(action: String) -> void :
	match action:
		"play": _show_setup()
		"training": transition(func() -> void : world.start_training(), "TERRAIN D’ESSAI")
		"friends": show_network()
		"gallery": transition(func() -> void : world.gallery.open(), "CINÉMA")
		"settings": show_settings()
		"credits": show_credits()
		"shop": show_shop()
		"quit": world.get_tree().quit()

func _add_version(left: float) -> void :
	var version: Label = _label(VERSION_TEXT, "caps", 12, T.FAINT)
	page.add_child(version)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	version.offset_left = left
	version.offset_right = left + 420
	version.offset_top = -46
	version.offset_bottom = -26


func _add_loadout_note(mobile: bool) -> void :
	var note: PanelContainer = PanelContainer.new()
	var style: W.PaperStyle = _paper_style(7, 16, true)
	style.content_margin_top = 18
	note.add_theme_stylebox_override("panel", style)
	page.add_child(note)

	note.anchor_left = 1
	note.anchor_right = 1
	note.anchor_top = 0
	note.anchor_bottom = 0
	var right: float = -56.0 if not mobile else - (mobile_safe_edges().y + 24.0)
	note.offset_right = right
	note.offset_left = right
	note.offset_top = 34 if not mobile else 18
	note.offset_bottom = note.offset_top
	note.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	note.grow_vertical = Control.GROW_DIRECTION_END
	note.custom_minimum_size.x = 290 if not mobile else 270
	note.resized.connect( func() -> void : note.pivot_offset = note.size * 0.5)
	note.rotation_degrees = 2.2
	var v: VBoxContainer = _vbox(note, 4)
	v.add_child(_label("Prochaine manche", "hand", 25, T.RED_INK))
	var row: HBoxContainer = _hbox(v, 12)
	var person: String = "Alice" if world.solo_killer else str(world.selected)
	var photo: TextureRect = TextureRect.new()
	var square: Texture2D = MenuBackdrop.bust_square(person)
	photo.texture = square if square else PaperStatusIcon.portrait_for(person)
	photo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	photo.custom_minimum_size = Vector2(58, 58)
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(photo)
	var text: VBoxContainer = _vbox(row, 1)
	var role_line: String = "ALICE  ·  " + str(PaperData.STATS["Alice"][3]) if world.solo_killer else "SURVIVANT  ·  " + person.to_upper()
	text.add_child(_label(role_line, "title", 18, T.INK_TEXT))
	text.add_child(_label(str(world.MAP_NAMES.get(world.selected_map, world.selected_map)), "medium", 15, T.INK_MUTED))
	var edit: Label = _label("MODIFIER  →", "caps", 11, T.RED_INK)
	edit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(edit)
	var hit: Button = Button.new()
	hit.flat = true
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]: hit.add_theme_stylebox_override(state, T.empty_style())
	hit.add_theme_stylebox_override("focus", T.focus_style(4))
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	note.add_child(hit)
	hit.pressed.connect(_show_setup.bind("", -1))
	hit.pressed.connect(_sfx.bind("click"))
	hit.mouse_entered.connect( func() -> void : note.modulate = Color(1.05, 1.03, 1.0))
	hit.mouse_exited.connect( func() -> void : note.modulate = Color.WHITE)

func _show_mobile_main() -> void :
	_begin_page("main", "", 0.66)
	_backdrop(0.58, 0.8)
	_main_decor()
	var safe: Vector2 = mobile_safe_edges()
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(column)
	column.anchor_top = 0
	column.anchor_bottom = 1
	column.offset_left = safe.x + 44
	column.offset_right = safe.x + 44 + 520
	column.offset_top = 26
	column.offset_bottom = -20
	var first: Control = _main_column(column, true)
	if first: _cascade(first.get_parent(), Vector2(-200, 24), -0.45, 0.035, 0.24)
	_add_version(safe.x + 44)
	_add_loadout_note(true)
	_intro(column)
	_end_page(first)




func show_characters(index: int = -1) -> void :
	_show_setup("survivor", index)

func show_alice() -> void :
	_show_setup("alice", -1)

func show_maps() -> void :
	if not world.networked:
		_show_setup("", -1)
		return
	_begin_page("maps", "", 0.66)
	_backdrop(0.75, 0.96)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	page.add_child(column)
	column.position = Vector2(56, 40)
	column.custom_minimum_size.x = 1240
	var back: Button = _button("←  RETOUR AU SALON", show_lobby, 0, "GhostButton")
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(back)
	column.add_child(_kicker("CHOISIR LE TERRAIN"))
	column.add_child(_label("Au-delà de l'école", "title", 44, T.PAPER))
	var row: HBoxContainer = _hbox(column, 22)
	var first: Control = null
	for key: String in ["school", "forest", "snow"]:
		var card: W.MapCard = W.MapCard.new()
		card.custom_minimum_size = Vector2(380, 330)
		card.setup(key, _map_thumb(key), str(world.MAP_NAMES[key]), str(MAP_LINES[key]), world.selected_map == key)
		card.pressed.connect(world.select_map.bind(key))
		card.pressed.connect(_sfx.bind("click"))
		row.add_child(card)
		if first == null or world.selected_map == key: first = card
	_intro(column)
	_end_page(first)

func _map_thumb(key: String) -> Texture2D:
	var path: String = "res://ui/maps/om_" + key + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

func _show_setup(role: String = "", index: int = -1) -> void :
	if role.is_empty(): role = "alice" if world.solo_killer and not world.networked else "survivor"
	if world.networked: role = "survivor"
	var chosen: String = str(world.selected)
	if index >= 0: chosen = str(PaperData.NAMES[posmod(index, 6)])
	if not PaperData.NAMES.has(chosen): chosen = "Ashura"
	setup_role = role
	setup_choice = chosen

	var compact: bool = get_viewport().get_visible_rect().size.y < 820
	_begin_page("alice" if role == "alice" else "characters", "Alice" if role == "alice" else chosen, 0.74)
	world.preview_angle = 0
	_backdrop(0.62, 0.9)

	setup_mark = _label("", "display", 150, Color(MenuBackdrop.accent_for("Alice" if role == "alice" else chosen), 0.09))
	page.add_child(setup_mark)
	setup_mark.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	setup_mark.offset_left = -900
	setup_mark.offset_right = -24
	setup_mark.offset_top = -210
	setup_mark.offset_bottom = -30
	setup_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	setup_mark.set_meta("language_user_text", true)

	setup_mark.visible = false
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	page.add_child(column)
	column.position = Vector2(52 + (mobile_safe_edges().x if world.mobile_mode else 0.0), 14 if compact else 26)
	column.custom_minimum_size.x = 530
	var back: Button = _button("←  RETOUR", _setup_back, 0, "GhostButton")
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(back)
	_spacer(column, 6)
	column.add_child(_kicker("SALON  ·  TON PERSONNAGE" if world.networked else "PRÉPARER LA MANCHE", T.RED if role == "alice" else T.TEAL))
	column.add_child(_display_title("Choisis ton personnage" if world.networked else "Incarne Alice" if role == "alice" else "Choisis ton élève", 36 if compact else 46))
	_spacer(column, 6 if compact else 10)
	if not world.networked:
		var tabs: HBoxContainer = _hbox(column, 12)
		var group: ButtonGroup = ButtonGroup.new()
		for spec: Array in [["survivor", "SURVIVANT", "6 élèves · atteindre la sortie", "student", T.TEAL], ["alice", "ALICE", "L’ombre · empêcher la fuite", "slash", T.RED]]:
			var tab: W.RoleTab = W.RoleTab.new()
			tab.text = str(spec[1])
			tab.subtitle = str(spec[2])
			tab.icon_tex = Icons.icon(str(spec[3]))
			tab.accent = spec[4]
			tab.button_group = group
			tab.button_pressed = role == spec[0]
			tab.custom_minimum_size = Vector2(259, 54 if compact else 62)
			tab.pressed.connect(_set_role.bind(str(spec[0])))
			tabs.add_child(tab)
		_spacer(column, 10 if compact else 18)
	var first: Control = null
	if role == "alice": first = _alice_dossier(column, compact)
	else:
		var grid: GridContainer = GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 18)
		grid.add_theme_constant_override("v_separation", 12 if compact else 20)
		column.add_child(grid)
		for i: int in range(PaperData.NAMES.size()):
			var person: String = PaperData.NAMES[i]
			var stats: Array = PaperData.STATS[person]
			var card: W.CharacterCard = W.CharacterCard.new()
			card.reduced_motion = reduced_motion
			card.custom_minimum_size = Vector2(164, (162 if compact else 200) + (26 if world.networked else 0))
			card.setup(person, PaperStatusIcon.portrait_for(person), str(stats[3]), ("∞" if float(stats[0]) < 0 else str(int(stats[0]))) + " PV", stats[5], i * 13 + 5, [-1.4, 0.8, -0.6, 1.2, -1.0, 0.7][i])
			card.art = MenuBackdrop.art(person, "_bust")
			card.art_accent = MenuBackdrop.accent_for(person)
			var owner: String = world.character_owner(person, world.local_id()) if world.networked else ""
			card.set_selected(person == chosen, owner)
			card.pressed.connect(_select_character.bind(person))
			card.mouse_entered.connect(_preview.bind(person))
			card.focus_entered.connect(_preview.bind(person))
			card.mouse_exited.connect(_preview.bind(""))
			grid.add_child(card)
			setup_cards.append(card)
			if person == chosen: first = card
	if not world.networked:
		_spacer(column, 10 if compact else 20)
		column.add_child(_kicker("CARTE", T.TEAL, 12))
		_spacer(column, 6 if compact else 8)
		var maps: HBoxContainer = _hbox(column, 14)
		for key: String in ["school", "forest", "snow"]:
			var card: W.MapCard = W.MapCard.new()
			card.custom_minimum_size = Vector2(167, 112 if compact else 158)
			card.setup(key, _map_thumb(key), str(world.MAP_NAMES[key]), str(MAP_SHORT[key]), world.selected_map == key)
			card.tooltip_text = _t(str(MAP_LINES[key]))
			card.pressed.connect(_pick_map.bind(key))
			maps.add_child(card)

	var sheet: PanelContainer = PanelContainer.new()
	var paper: W.PaperStyle = _paper_style(21, 24, true)
	paper.ruled = false
	sheet.add_theme_stylebox_override("panel", paper)
	page.add_child(sheet)
	sheet.position = Vector2(612 + (mobile_safe_edges().x if world.mobile_mode else 0.0), 64 if compact else 118)
	sheet.custom_minimum_size = Vector2(334, 0)
	sheet.size = Vector2(334, 0)
	sheet.resized.connect( func() -> void : sheet.pivot_offset = sheet.size * 0.5)
	sheet.rotation_degrees = -0.7
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(290, 0)
	sheet.add_child(scroll)
	setup_info = _vbox(scroll, 8)
	setup_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fill_info("Alice" if role == "alice" else chosen)

	scroll.custom_minimum_size.y = minf(get_viewport().get_visible_rect().size.y - sheet.position.y - 44 - 130, maxf(200, setup_info.get_combined_minimum_size().y))

	var cta_box: VBoxContainer = VBoxContainer.new()
	cta_box.add_theme_constant_override("separation", 8)
	page.add_child(cta_box)
	cta_box.anchor_left = 0
	cta_box.anchor_right = 0
	cta_box.anchor_top = 1
	cta_box.anchor_bottom = 1
	cta_box.offset_left = sheet.position.x
	cta_box.offset_right = sheet.position.x + 334
	cta_box.offset_bottom = -30
	cta_box.offset_top = -30
	cta_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	setup_summary = _label("", "caps", 12, T.PAPER_DIM)
	setup_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	setup_summary.clip_text = true
	_shadow(setup_summary)
	cta_box.add_child(setup_summary)
	setup_cta = Button.new()
	setup_cta.theme_type_variation = "PrimaryButton"
	setup_cta.custom_minimum_size = Vector2(334, 62)
	setup_cta.add_theme_font_size_override("font_size", 22)
	setup_cta.pressed.connect(_setup_confirm)
	setup_cta.mouse_entered.connect(_sfx.bind("hover"))
	cta_box.add_child(setup_cta)
	_update_setup_texts()
	_intro(column)
	_intro(sheet, 18.0)
	var deal_key: String = current_page + ":" + role
	if deal_key != _setup_dealt:
		_setup_dealt = deal_key
		for child: Node in column.get_children():
			if child is GridContainer: _cascade(child, Vector2(-40, 90), 0.2, 0.045, 0.3)
			elif child is HBoxContainer: _cascade(child, Vector2(-60, 0), -0.1, 0.05, 0.24)
		_cascade(cta_box, Vector2(0, 80), -0.06, 0.05, 0.26)
	_end_page(first if first else setup_cta)


func _fit_dossier(scroll: ScrollContainer) -> void :
	if not is_instance_valid(scroll) or not is_instance_valid(setup_info): return
	var sheet: Control = scroll.get_parent() as Control
	var top: float = sheet.position.y if sheet else 118.0
	var limit: float = get_viewport().get_visible_rect().size.y - top - 44 - 130
	scroll.custom_minimum_size.y = clampf(setup_info.get_combined_minimum_size().y, 160, limit)
	if sheet: sheet.size = Vector2(sheet.size.x, 0)

func _setup_back() -> void :
	if world.networked: show_lobby()
	else: show_main()

func _set_role(role: String) -> void :
	if role == setup_role: return
	Sound.play("click")
	world.solo_killer = role == "alice"
	world.save_preferences()
	_quiet_page = true
	_show_setup(role, -1)
	_quiet_page = false

func _preview(person: String) -> void :
	if not current_page in ["characters", "alice"]: return
	var shown: String = setup_choice if person.is_empty() else person
	if setup_role == "alice": shown = "Alice"
	world.preview_character = shown
	if is_instance_valid(menu_backdrop): menu_backdrop.show_hero(shown)
	if is_instance_valid(setup_mark):
		setup_mark.text = shown.to_upper()
		setup_mark.add_theme_color_override("font_color", Color(MenuBackdrop.accent_for(shown), 0.09))

func _select_character(person: String) -> void :
	setup_choice = person
	var owner: String = world.character_owner(person, world.local_id()) if world.networked else ""
	if not world.networked:
		world.selected = person
		world.update_selection()
	world.preview_character = person
	if is_instance_valid(menu_backdrop): menu_backdrop.show_hero(person)
	for card: W.CharacterCard in setup_cards:
		card.set_selected(card.person == person, world.character_owner(card.person, world.local_id()) if world.networked else "")
	_fill_info(person)
	_update_setup_texts()
	Sound.play("click" if owner.is_empty() else "back")

func _pick_map(key: String) -> void :
	Sound.play("click")
	if world.selected_map == key: return
	var role: String = setup_role
	var choice: String = setup_choice
	_quiet_page = true
	world.select_map(key)
	if not world.networked: _show_setup(role, PaperData.NAMES.find(choice) if role != "alice" else -1)
	_quiet_page = false

func _setup_confirm() -> void :
	if world.networked:
		var owner: String = world.character_owner(setup_choice, world.local_id())
		if not owner.is_empty(): return
		Sound.play("confirm")
		world.selected = setup_choice
		world.update_selection()
		show_lobby()
		return
	Sound.play("confirm")
	transition(func() -> void : world.start_solo(world.solo_killer), "LA CLOCHE SONNE")

func _update_setup_texts() -> void :
	if not is_instance_valid(setup_cta): return
	var person: String = "Alice" if setup_role == "alice" else setup_choice
	if is_instance_valid(setup_mark): setup_mark.text = person.to_upper()
	if world.networked:
		var owner: String = world.character_owner(setup_choice, world.local_id())
		setup_cta.text = _t("CHOISIR %s") % setup_choice.to_upper() if owner.is_empty() else _t("DÉJÀ PRIS PAR %s") % owner.to_upper()
		setup_cta.disabled = not owner.is_empty()
		setup_summary.text = _t("RETOUR AU SALON APRÈS LE CHOIX")
		return
	setup_cta.text = _t("LANCER LA PARTIE  →")
	setup_cta.disabled = false
	var role_text: String = _t("ALICE") if setup_role == "alice" else _t("SURVIVANT") + "  ·  " + person.to_upper()
	setup_summary.text = role_text + "  ·  " + _t(str(world.MAP_NAMES.get(world.selected_map, ""))).to_upper()

func _alice_dossier(column: VBoxContainer, compact: bool = false) -> Control:
	var card: PanelContainer = PanelContainer.new()
	var paper: W.PaperStyle = _paper_style(33, 18, true)
	paper.fill = Color("e9e1cf")
	card.add_theme_stylebox_override("panel", paper)
	card.custom_minimum_size = Vector2(530, 0)
	column.add_child(card)
	var row: HBoxContainer = _hbox(card, 18)
	var frame: PanelContainer = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", T.box(Color("2a0d16"), Color(0.1, 0.09, 0.12), 1, 2, 0, 0))
	frame.custom_minimum_size = Vector2(150, 190) if compact else Vector2(190, 250)
	frame.clip_contents = true
	row.add_child(frame)
	var photo: TextureRect = TextureRect.new()
	var bust: Texture2D = MenuBackdrop.art("Alice", "_bust")
	photo.texture = bust if bust else PaperStatusIcon.portrait_for("Alice")
	photo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	frame.add_child(photo)
	var text: VBoxContainer = _vbox(row, 6)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(_kicker("DOSSIER  ·  L’OMBRE DE L’ÉCOLE", T.RED_INK, 11))
	text.add_child(_label("ALICE", "display", 44 if compact else 60, T.INK_TEXT))
	text.add_child(_label("Elle connaît la dernière sonnerie.", "hand", 22 if compact else 26, T.RED_INK))
	_spacer(text, 4)
	for line: String in ["∞ PV  ·  invulnérable", "True Form après 15 stuns, une fois par partie", "Les six élèves sont joués par des bots."]:
		var item: HBoxContainer = _hbox(text, 8)
		var dot: ColorRect = ColorRect.new()
		dot.color = T.RED_INK
		dot.custom_minimum_size = Vector2(6, 6)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(dot)
		var l: Label = _label(line, "medium", 15, T.INK_TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.add_child(l)
	_spacer(text, 2)
	var passive_head: HBoxContainer = _hbox(text, 8)
	passive_head.add_child(_badge(Icons.passive("Alice"), 28, T.RED_DEEP, Color("fbeff1")))
	var passive_title: Label = _label("PASSIF", "title", 15, T.INK_TEXT)
	passive_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	passive_head.add_child(passive_title)
	var passive: Label = _label(PaperData.passive_for("Alice", world.ruleset), "body", 13, Color("3b3541"))
	passive.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	passive.custom_minimum_size.x = 250
	text.add_child(passive)
	var stamp: W.Stamp = W.Stamp.new()
	stamp.configure("DANGER", 20, T.RED_INK, false, -12.0)
	stamp.custom_minimum_size = Vector2(150, 52)
	stamp.size_flags_horizontal = Control.SIZE_SHRINK_END
	text.add_child(stamp)
	if compact:

		text.remove_child(stamp)
		frame.add_child(stamp)
		stamp.size_flags_vertical = Control.SIZE_SHRINK_END
	var focus: Button = Button.new()
	focus.flat = true
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]: focus.add_theme_stylebox_override(state, T.empty_style())
	focus.add_theme_stylebox_override("focus", T.focus_style(4))
	card.add_child(focus)
	focus.pressed.connect(_sfx.bind("click"))
	return focus



func _fill_info(person: String) -> void :
	if not is_instance_valid(setup_info): return
	_clear(setup_info)
	var stats: Array = PaperData.STATS.get(person, [])
	var accent: Color = T.RED_INK if person == "Alice" else Color("2e6d68")
	setup_info.add_child(_label(str(stats[3]) if stats.size() > 3 else "", "caps", 13, accent))
	var head: HBoxContainer = _hbox(setup_info, 10)
	var title: Label = _label(person.to_upper(), "title", 34, T.INK_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var hp_text: String = ("∞" if stats.size() > 0 and float(stats[0]) < 0 else str(int(stats[0])) if stats.size() > 0 else "") + " PV"
	var hp_chip: Label = _label(hp_text, "num", 15, T.INK_TEXT)
	hp_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(hp_chip)
	if stats.size() > 4:
		var tag: Label = _label(str(stats[4]), "hand", 25, T.RED_INK)
		tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		setup_info.add_child(tag)
	var rule: ColorRect = ColorRect.new()
	rule.color = Color(T.INK_TEXT, 0.15)
	rule.custom_minimum_size.y = 1
	setup_info.add_child(rule)
	var skills: Array = PaperData.abilities_for(person, world.ruleset)
	for i: int in range(skills.size()):
		var skill: Array = skills[i]
		if str(skill[0]) == "—": continue
		var row: HBoxContainer = _hbox(setup_info, 10)
		row.add_child(_badge(Icons.ability(person, i), 38, Color("221e29"), Color("f1ebdd")))
		var text: VBoxContainer = _vbox(row, 1)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var line: HBoxContainer = _hbox(text, 6)
		var key: W.KeyCap = W.KeyCap.new(_binding("ability_" + str(i), str(i + 1)), 11)
		key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(key)
		var name_label: Label = _label(str(skill[0]).to_upper(), "title", 15, T.INK_TEXT)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name_label)
		if int(skill[1]) > 0:
			var cd: Label = _label(str(skill[1]) + " s", "num", 13, T.INK_MUTED)
			line.add_child(cd)
		var body: Label = _label(str(skill[2]), "body", 13, Color("3b3541"))
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size.x = 230
		text.add_child(body)
	if person == "Alice":
		if PaperLanguage.language == "en": PaperLanguage.apply_tree(setup_info)
		var alice_scroll: ScrollContainer = setup_info.get_parent() as ScrollContainer
		if alice_scroll: _fit_dossier.call_deferred(alice_scroll)
		return
	var passive: HBoxContainer = _hbox(setup_info, 10)
	passive.add_child(_badge(Icons.passive(person), 38, Color("6a5a86"), Color("f6f1ff")))
	var passive_text: VBoxContainer = _vbox(passive, 1)
	passive_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	passive_text.add_child(_label("PASSIF & AURA", "title", 15, T.INK_TEXT))
	var passive_body: Label = _label(PaperData.passive_for(person, world.ruleset), "body", 13, Color("3b3541"))
	passive_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	passive_body.custom_minimum_size.x = 230
	passive_text.add_child(passive_body)
	if person == "Lysia": _paragraph("Prix prévu : 700. Accessible pour tester cette alpha.", setup_info, 12, T.INK_MUTED)
	if PaperLanguage.language == "en": PaperLanguage.apply_tree(setup_info)
	var scroll: ScrollContainer = setup_info.get_parent() as ScrollContainer
	if scroll: _fit_dossier.call_deferred(scroll)




func show_network() -> void :
	_begin_page("network", "", 0.66)
	_backdrop(0.6, 0.9)
	var v: VBoxContainer = _form_panel(640)
	_form_header(v, "LES OMBRES VOUS ATTENDENT", "En ligne, entre amis")
	var account: Button = _button("COMPTE, AMIS ET SERVEURS RÉGIONAUX", func() -> void : world.online_menu.open(), 0, "TealButton")
	account.icon = Icons.icon("friends")
	account.expand_icon = false
	account.add_theme_constant_override("icon_max_width", 22)
	v.add_child(account)
	_paragraph("Retrouve tes amis et tes groupes privés sur le service configuré. Aucun serveur régional public n'est encore hébergé pour cette version.", v, 15, T.MUTED)
	_section(v, "CONNEXION ENTRE JOUEURS (SANS COMPTE)")
	_paragraph("Crée un salon Internet et partage son code. Dans ce mode, un joueur héberge la partie. Tes amis peuvent jouer depuis une autre connexion.", v, 16)
	v.add_child(_kicker("TON NOM", T.PAPER_DIM, 11))
	var name_input: LineEdit = _field("", str(world.nickname), 18)
	v.add_child(name_input)
	name_input.text_changed.connect( func(value: String) -> void :
		world.nickname = value
		world.save_preferences())
	var host: Button = _button("CRÉER UN SALON INTERNET", func() -> void : world.host_room(), 0, "PrimaryButton")
	v.add_child(host)
	v.add_child(_kicker("CODE DU SALON", T.PAPER_DIM, 11))
	var code_row: HBoxContainer = _hbox(v, 10)
	var code: LineEdit = _field("Colle le code envoyé par l'hôte", "", 128)
	code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_row.add_child(code)
	code.text_submitted.connect( func(value: String) -> void : world.join_room(value))
	if world.mobile_mode: code_row.add_child(_button("COLLER", func() -> void : code.text = DisplayServer.clipboard_get().strip_edges(), 130))
	v.add_child(_button("REJOINDRE LE SALON  →", func() -> void : world.join_room(code.text), 0))
	_paragraph("Connexion automatique avec relais de secours. Le service de salons public de cette alpha est expérimental ; sa disponibilité peut varier.", v, 14, T.MUTED)
	_spacer(v, 4)
	var bottom: HBoxContainer = _hbox(v, 10)
	var back: Button = _button("←  RETOUR", show_main, 150, "GhostButton")
	bottom.add_child(back)
	var advanced: Button = _button("CONNEXION DIRECTE / RÉGLAGES RÉSEAU", show_network_advanced, 0, "GhostButton")
	advanced.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(advanced)
	_end_page(host)

func show_connecting() -> void :
	_begin_page("connecting", "", 0.66)
	_backdrop(0.6, 0.9)
	var v: VBoxContainer = _form_panel(620)
	_form_header(v, "CONNEXION INTERNET", "Ouverture du salon")
	var row: HBoxContainer = _hbox(v, 16)
	row.add_child(W.Spinner.new())
	connection_label = _label("Connexion…", "medium", 20, T.PAPER)
	connection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	connection_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	connection_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(connection_label)
	_paragraph("Le jeu établit une connexion entre les participants. Cela peut prendre quelques secondes.", v, 16)
	var cancel: Button = _button("ANNULER", func() -> void :
		world.leave_network()
		show_network(), 0, "DangerButton")
	v.add_child(cancel)
	_end_page(cancel)

func network_status(message: String) -> void :
	if is_instance_valid(connection_label): connection_label.text = _t(message)

func show_network_advanced() -> void :
	_begin_page("advanced", "", 0.66)
	_backdrop(0.6, 0.9)
	var v: VBoxContainer = _form_panel(640)
	_form_header(v, "CONNEXION DIRECTE", "Réglages réseau")
	_paragraph("Le mode Internet utilise normalement le service public. Un groupe disposant de son propre serveur Noray peut le renseigner ici.", v, 16)
	var relay: LineEdit = _field("", str(world.internet.relay_host))
	v.add_child(relay)
	relay.text_changed.connect( func(value: String) -> void : world.internet.relay_host = value.strip_edges())
	var force: CheckButton = CheckButton.new()
	force.text = "Toujours passer par le relais Internet"
	force.button_pressed = world.internet.force_relay
	v.add_child(force)
	force.toggled.connect( func(value: bool) -> void : world.internet.force_relay = value)
	_section(v, "CONNEXION DIRECTE")
	_paragraph("Connexion directe facultative : utile sur le même réseau ou avec un serveur déjà accessible. Le salon Internet n'en a pas besoin.", v, 16)
	v.add_child(_button("HÉBERGER EN CONNEXION DIRECTE", func() -> void : world.host_lan_room(), 0, "TealButton"))
	var address: LineEdit = _field("Adresse IP de l'hôte")
	v.add_child(address)
	v.add_child(_button("REJOINDRE CETTE ADRESSE", func() -> void : world.join_lan_room(address.text), 0))
	_spacer(v, 4)
	v.add_child(_button("←  RETOUR", show_network, 150, "GhostButton"))
	_end_page(relay)

func show_lobby() -> void :
	_begin_page("lobby", "", 0.66)
	_backdrop(0.64, 0.92)
	var v: VBoxContainer = _form_panel(720)
	var kind: String = "RÉGIONAL" if world.service and world.service.regional else "INTERNET" if world.online_room else "DIRECT"
	_form_header(v, "SALON PRIVÉ  /  " + kind, "Avant la cloche")
	if world.online_room:
		var row: HBoxContainer = _hbox(v, 10)
		var code: LineEdit = _field("", str(world.internet.code))
		code.editable = false
		code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		code.set_meta("language_user_text", true)
		row.add_child(code)
		row.add_child(_button("COPIER LE CODE DU SALON", func() -> void :
			DisplayServer.clipboard_set(world.internet.code)
			toast("Code du salon copié."), 0, "TealButton"))
	elif world.authoritative():
		var address: Label = _label("Adresse : " + world.local_addresses(), "medium", 18, T.TEAL)
		v.add_child(address)
		v.add_child(_button("COPIER L'ADRESSE", func() -> void : DisplayServer.clipboard_set(world.local_addresses().split(" / ")[0]), 0, "TealButton"))
	var map_row: HBoxContainer = _hbox(v, 14)
	var thumb: TextureRect = TextureRect.new()
	var source: Texture2D = _map_thumb(world.selected_map)
	if source:
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = source
		atlas.region = Rect2(source.get_size() * Vector2(0.22, 0.2), source.get_size() * Vector2(0.56, 0.6))
		thumb.texture = atlas
	thumb.custom_minimum_size = Vector2(132, 74)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	map_row.add_child(thumb)
	var map_text: VBoxContainer = _vbox(map_row, 2)
	map_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	map_text.add_child(_kicker("CARTE", T.PAPER_DIM, 11))
	lobby_map = _label("", "title", 20, T.PAPER)
	map_text.add_child(lobby_map)
	if world.can_manage_lobby() and world.room_options.mode != "training":
		var pick: Button = _button("CHOISIR LA CARTE", show_maps, 0)
		pick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		map_row.add_child(pick)
	_section(v, "JOUEURS")
	lobby_list = _vbox(v, 6)
	lobby_names = _label("Connexion…", "body", 16, T.PAPER_DIM)
	lobby_names.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(lobby_names)
	var choose: Button = _button("PERSONNAGE : " + str(world.selected), show_characters, 0)
	choose.icon = PaperStatusIcon.portrait_for(str(world.selected))
	choose.expand_icon = false
	choose.add_theme_constant_override("icon_max_width", 34)
	v.add_child(choose)
	_section(v, "MODE DE JEU")
	if world.can_manage_lobby(): _option_row(v, "À quoi joue-t-on ?", ["Manche OM", "Terrain d’essai · École"], ["match", "training"], "mode")
	lobby_options = _paragraph("", v, 16, T.PAPER)
	var launch: Button = null
	if world.can_manage_lobby():
		if world.room_options.mode == "match":
			_option_row(v, "Qui joue Alice ?", ["Malice", "Alice contrôlée par l'IA", "L'hôte", "Un joueur au hasard"], ["malice", "bot", "host", "random"], "killer_mode")
			_option_row(v, "Survivants (bots compris)", ["2", "3", "4", "5", "6"], [2, 3, 4, 5, 6], "survivors")
			_option_row(v, "Durée de la manche", ["5 min 20", "6 min 20", "7 min 20", "9 min 20"], [320, 380, 440, 560], "round_seconds")
			_paragraph("Le LMS dure exactement le temps de la musique du dernier survivant.", v, 14, T.MUTED)
			_paragraph("Les places restantes sont complétées par des bots. Les amis présents gardent leur place si leur nombre dépasse ce réglage.", v, 14, T.MUTED)
		else: _paragraph("École ouverte sans chrono. F2 permet de changer de personnage, préparer un LMS et réinitialiser. L’hôte règle les mannequins ; chaque ami contrôle ses propres essais.", v, 16)
		launch = _button("OUVRIR LE TERRAIN D’ESSAI  →" if world.room_options.mode == "training" else "LANCER LA MANCHE  →", func() -> void : world.start_multiplayer_round(), 0, "PrimaryButton")
		v.add_child(launch)
	else: _paragraph("L'hôte choisit les règles et lance la manche.", v, 16)
	v.add_child(_button("QUITTER LE SALON", func() -> void : world.quit_to_menu(), 0, "DangerButton"))
	refresh_lobby()
	_end_page(launch if launch else choose)

func _option_row(parent: Node, title: String, labels: Array, values: Array, key: String) -> void :
	var row: HBoxContainer = _list_row(parent, 12)
	var label: Label = _label(title, "medium", 16, T.PAPER_DIM)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	var choice: OptionButton = OptionButton.new()
	choice.custom_minimum_size = Vector2(300, 54 if world.mobile_mode else 42)
	row.add_child(choice)
	for item: String in labels: choice.add_item(item)
	choice.select(maxi(0, values.find(world.room_options[key])))
	choice.item_selected.connect( func(index: int) -> void : world.set_room_option(key, values[index]))

func refresh_lobby() -> void :
	if is_instance_valid(lobby_map): lobby_map.text = _t(str(world.MAP_NAMES[world.selected_map]))
	if is_instance_valid(lobby_options):
		var modes: Dictionary = {"malice": "Joueur avec la plus haute malice", "bot": "Alice IA", "host": "Hôte = Alice", "random": "Alice tirée au sort"}
		var o: Dictionary = world.room_options
		var text: String = "%s · %s survivants\nManche %d:%02d · LMS selon la musique" % [modes[o.killer_mode], o.survivors, int(o.round_seconds) / 60, int(o.round_seconds) % 60]
		if o.mode == "training": text = "TERRAIN D’ESSAI · Pas de chrono · Mannequins réinitialisables"
		lobby_options.text = _t(PaperRules.LABELS[world.ruleset].to_upper() + " · " + text)
	if is_instance_valid(menu_backdrop) and current_page == "lobby":
		var picked: Array = []
		for record: Dictionary in world.roster.values(): picked.append(str(record.get("character", "")))
		menu_backdrop.set_spotlight(picked)
	if not is_instance_valid(lobby_list): return
	_clear(lobby_list)
	for peer: Variant in world.roster:
		var p: Dictionary = world.roster[peer]
		var row: PanelContainer = PanelContainer.new()
		row.add_theme_stylebox_override("panel", T.strip(Color(1, 1, 1, 0.045), 14, 6, 7.0, int(peer) % 13 + 3))
		lobby_list.add_child(row)
		var h: HBoxContainer = _hbox(row, 12)
		var person: String = str(p.character)
		var icon: PaperStatusIcon = PaperStatusIcon.new()
		icon.setup(person if not person.is_empty() else "Ashura")
		icon.compact = true
		icon.custom_minimum_size = Vector2(38, 38)
		h.add_child(icon)
		var text: VBoxContainer = _vbox(h, 0)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var player_name: Label = _label(str(p.name), "semibold", 17, T.PAPER)
		player_name.set_meta("language_user_text", true)
		text.add_child(player_name)
		text.add_child(_label(person if not person.is_empty() else _t("Attribué au lancement"), "caps", 11, T.TEAL))
		var malice: Label = _label(_t("Malice") + " " + str(p.malice), "num", 14, T.PAPER_DIM)
		malice.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(malice)
		if int(peer) == 1:
			var host: Label = _label(_t("HÔTE"), "caps", 11, T.GOLD)
			host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(host)
	if is_instance_valid(lobby_names):
		lobby_names.visible = world.roster.is_empty()
		lobby_names.text = _t("Connexion…")




func show_settings() -> void :
	var playing: bool = world.phase == "playing"
	_begin_page("settings", "", 0.66)
	if playing: _dim(page, 0.82)
	else: _backdrop(0.62, 0.86)
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBox = T.sheet_style(36, 28, T.RED_DEEP, 23)
	style.content_margin_left = 42
	style.content_margin_right = 36
	style.content_margin_top = 28
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	var decor: Control = _page_decor("RÉGLAGES", T.TEAL_DEEP.lerp(T.RED_DEEP, 0.4))
	var view: Vector2 = get_viewport().get_visible_rect().size
	var wide: bool = view.x >= 1200.0 and not world.mobile_mode
	if wide: _page_art(_local_person(), view.x * 0.84, _quiet_page)
	page.add_child(panel)
	panel.anchor_left = 0.0 if wide else 0.5
	panel.anchor_right = 0.0 if wide else 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	var width: float = minf(1000.0, view.x * 0.66) if wide else minf(1060.0, view.x - 80.0)
	var height: float = minf(780.0, view.y - 60.0)
	panel.offset_left = 60.0 if wide else - width * 0.5
	panel.offset_right = 60.0 + width if wide else width * 0.5
	panel.offset_top = - height * 0.5
	panel.offset_bottom = height * 0.5
	active_menu_panel = null
	var v: VBoxContainer = _vbox(panel, 14)
	var header: HBoxContainer = _hbox(v, 16)
	var titles: VBoxContainer = _vbox(header, 0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(_kicker("PRÊT POUR LA RENTRÉE"))
	titles.add_child(_display_title("Réglages", 48))
	var saved: Label = _label("Enregistrement automatique", "caps", 11, T.FAINT)
	saved.size_flags_vertical = Control.SIZE_SHRINK_END
	header.add_child(saved)
	var tabs: HBoxContainer = _hbox(v, 4)
	var group: ButtonGroup = ButtonGroup.new()
	var specs: Array = [["game", "JEU"], ["display", "AFFICHAGE" if world.mobile_mode else "GRAPHISMES"], ["audio", "AUDIO"], ["controls", "COMMANDES"], ["access", "ACCESSIBILITÉ"]]
	var current: Button = null
	for spec: Array in specs:
		var tab: Button = Button.new()
		tab.text = str(spec[1])
		tab.theme_type_variation = "TabButton"
		tab.toggle_mode = true
		tab.button_group = group
		tab.button_pressed = settings_tab == spec[0]
		tab.custom_minimum_size.y = 52 if world.mobile_mode else 44
		tab.pressed.connect(_settings_switch.bind(str(spec[0])))
		tab.mouse_entered.connect(_sfx.bind("hover"))
		tabs.add_child(tab)
		if settings_tab == spec[0]: current = tab
	var rule: ColorRect = ColorRect.new()
	rule.color = Color(1, 1, 1, 0.07)
	rule.custom_minimum_size.y = 1
	v.add_child(rule)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var content: VBoxContainer = _vbox(scroll, 6)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	match settings_tab:
		"display": _settings_display(content)
		"audio": _settings_audio(content)
		"controls": _settings_controls(content)
		"access": _settings_access(content)
		_: _settings_game(content)
	var footer: HBoxContainer = _hbox(v, 12)
	var back: Button = _button("←  RETOUR", _settings_back, 180)
	footer.add_child(back)
	var note: Label = _label("Échap · retour" if not world.mobile_mode else "", "caps", 11, T.FAINT)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	footer.add_child(note)
	if not world.mobile_mode: note.text = _t("Échap · retour") + "     ◀ LB · RB ▶  " + _t("onglets")
	if _quiet_page:
		# Changement d'onglet : seul le contenu repart en cascade, côté de l'onglet.
		if is_instance_valid(decor): (decor as MenuFx.Decor).set("_enter", 1.0)
		_cascade(content, Vector2(90.0 * _tab_direction, 0), 0.04 * _tab_direction, 0.022, 0.22)
	else:
		_intro(panel, 0.0)
		_cascade(tabs, Vector2(0, -40), -0.12, 0.03, 0.22)
		_cascade(content, Vector2(-70, 0), -0.06, 0.028, 0.26)
	_end_page(current)

func _settings_switch(tab: String) -> void :
	if tab == settings_tab: return
	Sound.play("click")
	var order: Array = SETTINGS_TABS
	_tab_direction = 1.0 if order.find(tab) >= order.find(settings_tab) else -1.0
	settings_tab = tab
	_quiet_page = true
	show_settings()
	_quiet_page = false


func _setting_row(parent: Node, title: String, description: String, control: Control, control_width: float = 320) -> Label:
	var row: HBoxContainer = _hbox(_menu_row(parent), 24)
	row.custom_minimum_size.y = 62 if world.mobile_mode else 56
	var text: VBoxContainer = _vbox(row, 1)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_child(_label(title, "semibold", 18, T.PAPER))
	var note: Label = null
	if not description.is_empty():
		note = _label(description, "body", 14, T.MUTED)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(note)
	control.custom_minimum_size.x = control_width
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	return note

# Ligne de menu commune (réglages, options du salon, danses…) : elle s'allume
# d'une bande de papier rouge quand son contrôle est sélectionné.
func _menu_row(parent: Node) -> W.MenuRow:
	var holder: W.MenuRow = W.MenuRow.new()
	holder.reduced_motion = reduced_motion
	parent.add_child(holder)
	return holder

func _list_row(parent: Node, gap: int = 12) -> HBoxContainer:
	return _hbox(_menu_row(parent), gap)

func _check(value: bool, callback: Callable) -> CheckButton:
	var check: CheckButton = CheckButton.new()
	check.button_pressed = value
	check.text = ""
	check.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	check.toggled.connect(callback)
	check.toggled.connect( func(_on: bool) -> void : Sound.play("click"))
	return check

func _slider(low: float, high: float, step: float, value: float, format: Callable, callback: Callable) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var slider: HSlider = HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size.y = 40 if world.mobile_mode else 26
	row.add_child(slider)
	var shown: Label = _label(str(format.call(value)), "num", 15, T.TEAL)
	shown.custom_minimum_size.x = 58
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	shown.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(shown)
	slider.value_changed.connect( func(next: float) -> void :
		shown.text = str(format.call(next))
		callback.call(next))
	return row

func _options(labels: Array, selected: int, callback: Callable) -> OptionButton:
	var choice: OptionButton = OptionButton.new()
	for item: Variant in labels: choice.add_item(str(item))
	choice.select(maxi(0, selected))
	choice.custom_minimum_size.y = 50 if world.mobile_mode else 42
	choice.item_selected.connect(callback)
	choice.item_selected.connect( func(_index: int) -> void : Sound.play("click"))
	return choice

func _set_option(key: String, value: Variant) -> void :
	world.options[key] = value
	world.apply_options()
	world.save_preferences()

func _settings_game(content: VBoxContainer) -> void :
	_setting_row(content, "Langue", "Français ou anglais, appliqué immédiatement.", _options(["Français", "English"], 1 if str(world.options.get("language", "fr")) == "en" else 0, func(index: int) -> void :
		_set_option("language", "en" if index == 1 else "fr")
		_quiet_page = true
		show_settings()
		_quiet_page = false))
	if world.mobile_mode:
		_setting_row(content, "Sensibilité tactile", "Vitesse de la caméra lorsque tu glisses à droite de l’écran.", _slider(0.001, 0.009, 0.0001, float(world.touch_sensitivity), func(x: float) -> String: return "%d %%" % int(round(x / 0.0036 * 100.0)), func(x: float) -> void :
			world.touch_sensitivity = x
			world.save_preferences()))
	else:
		_setting_row(content, "Sensibilité de la souris", "Vitesse de rotation de la caméra.", _slider(0.0007, 0.005, 0.0001, float(world.sensitivity), func(x: float) -> String: return "%d %%" % int(round(x / 0.0022 * 100.0)), func(x: float) -> void :
			world.sensitivity = x
			world.save_preferences()))
	_setting_row(content, "Caméra souple", "Suivi amorti derrière le personnage.", _check(bool(world.options.get("camera_smooth", true)), func(on: bool) -> void : _set_option("camera_smooth", on)))
	_setting_row(content, "Champ de vision", "Angle de la caméra en jeu. Une valeur haute montre plus de décor.", _slider(60, 95, 1, float(world.options.get("fov", 72)), func(x: float) -> String: return "%d°" % int(x), func(x: float) -> void : _set_option("fov", int(x))))
	_setting_row(content, "Secousses de caméra", "Tremblement lors des coups et des impacts.", _check(bool(world.options.get("camera_shake", true)), func(on: bool) -> void : _set_option("camera_shake", on)))
	_setting_row(content, "Onomatopées", "Les « BAM ! » et « SHLAK ! » qui jaillissent des coups.", _check(bool(world.options.get("fx_words", true)), func(on: bool) -> void : _set_option("fx_words", on)))
	_setting_row(content, "Effets d’écran", "Lignes de vitesse, encre sur l’écran et halos selon l’état du personnage.", _check(bool(world.options.get("screen_fx", true)), func(on: bool) -> void : _set_option("screen_fx", on)))
	_spacer(content, 6)
	_paragraph("Objectif : atteindre la sortie lorsqu’elle s’ouvre à 01:20. Le dernier survivant a un LMS de la durée de sa musique. Alice ferme la sortie et suspend le chrono pendant sa True Form, une seule fois après 15 stuns. Simon et Ashura : maintenir la capacité 2 pour charger, puis relâcher. Le boost dure 3, 4 ou 6 s selon la charge.", content, 14, T.MUTED)

func _settings_display(content: VBoxContainer) -> void :
	if world.mobile_mode:
		var profiles: Array = ["balanced", "performance", "battery"]
		_setting_row(content, "Affichage Android", "Le profil Fluide allège le rendu sans changer les règles.", _options(["Équilibré · détails et fluidité", "Fluide · rendu plus léger", "Batterie · jusqu’à 45 images/s"], profiles.find(world.mobile_profile), func(index: int) -> void :
			world.mobile_profile = profiles[index]
			world.mobile_quality.set_profile(profiles[index])
			world.save_preferences()), 360)
		_setting_row(content, "Afficher les FPS", "Compteur d’images par seconde en haut à droite.", _check(bool(world.options.get("show_fps", false)), func(on: bool) -> void : _set_option("show_fps", on)))
		return
	var presets: Array = ["high", "balanced", "performance"]
	var notes: Dictionary = {"high": "Qualité complète : ombres de la lune, portée des lumières et particules.", "balanced": "Ombres plus courtes et lumières allégées, à la résolution native.", "performance": "Sans ombres de lune ni particules, rendu à 85 % : pour les petites configurations."}
	var current: String = str(world.options.get("graphics", "high"))
	_preset_note = _setting_row(content, "Qualité graphique", str(notes.get(current, "")), _options(["Élevée", "Équilibrée", "Performance"], presets.find(current), func(index: int) -> void :
		_set_option("graphics", presets[index])
		if is_instance_valid(_preset_note): _preset_note.text = _t(str(notes[presets[index]]))), 300)
	var fullscreen: bool = bool(world.options.get("fullscreen", DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]))
	_setting_row(content, "Plein écran", "Aussi disponible avec F11.", _check(fullscreen, func(on: bool) -> void : _set_option("fullscreen", on)))
	_setting_row(content, "Synchronisation verticale", "Évite les déchirures d’image ; peut ajouter un peu de latence.", _check(bool(world.options.get("vsync", true)), func(on: bool) -> void : _set_option("vsync", on)))
	var limits: Array = [0, 30, 60, 120, 144, 240]
	_setting_row(content, "Limite d’images par seconde", "Plafonne le rendu pour économiser l’énergie.", _options(["Illimitée", "30", "60", "120", "144", "240"], limits.find(int(world.options.get("fps_limit", 0))), func(index: int) -> void : _set_option("fps_limit", limits[index])), 300)
	_setting_row(content, "Échelle de rendu 3D", "Résolution de la scène ; l’interface reste nette.", _slider(0.5, 1.0, 0.05, float(world.options.get("render_scale", 1.0)), func(x: float) -> String: return "%d %%" % int(round(x * 100.0)), func(x: float) -> void : _set_option("render_scale", snappedf(x, 0.05))))
	_setting_row(content, "Afficher les FPS", "Compteur d’images par seconde en haut à droite.", _check(bool(world.options.get("show_fps", false)), func(on: bool) -> void : _set_option("show_fps", on)))

func _settings_audio(content: VBoxContainer) -> void :
	var percent: Callable = func(x: float) -> String: return "%d %%" % int(round(x * 100.0))
	_setting_row(content, "Musique", "Ambiance, poursuites, LMS et fins.", _slider(0, 1, 0.05, float(world.audio.music_volume), percent, func(x: float) -> void :
		world.audio.music_volume = x
		world.save_preferences()))
	_setting_row(content, "Effets sonores", "Pas, coups, capacités et interface.", _slider(0, 1, 0.05, float(world.audio.effects_volume), percent, func(x: float) -> void :
		world.audio.effects_volume = x
		world.save_preferences()))
	_setting_row(content, "Couper les sons", "Silence complet, musique comprise.", _check(bool(world.audio.muted), func(on: bool) -> void :
		world.audio.muted = on
		world.save_preferences()))

func _settings_controls(content: VBoxContainer) -> void :
	if world.mobile_mode:
		_paragraph("Joystick gauche · se déplacer\nGlisser à droite · orienter la caméra\nCOURIR · activer ou arrêter le sprint\nCapacités à droite · toucher pour utiliser\nPIQUES · préparer, viser puis CONFIRMER\nMaintenir INTERAGIR · archive ou réanimation\nJ / K / L · toucher la bonne réponse d’archive\nMENU · pause / ESSAI · préparer un test\nSUIVANT · changer d’allié après élimination", content, 17, T.PAPER)
		var edit: Button = _button("PERSONNALISER CLAVIER / MANETTE / TACTILE", func() -> void : world.controls_menu.open(), 0, "TealButton")
		content.add_child(edit)
		return
	var columns: HBoxContainer = _hbox(content, 34)
	var survivor: VBoxContainer = _vbox(columns, 6)
	survivor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	survivor.add_child(_kicker("SURVIVANTS", T.TEAL, 12))
	var move_keys: Array = [_binding("forward", "Z"), _binding("left", "Q"), _binding("back", "S"), _binding("right", "D")]
	var mouse: String = "Souris" if PaperLanguage.language != "en" else "Mouse"
	for spec: Array in [[move_keys, "Se déplacer"], [[mouse], "Orienter la caméra"], [[_binding("sprint", "Maj")], "Courir"], [[_binding("jump", "Espace")], "Sauter (recharge 2 s)"], [[_binding("interact", "E")], "Interagir · relever · sceller"], [["1–4"], "Capacités"], [[_binding("ability_1", "2")], "Maintenir pour charger (Simon, Ashura)"], [[_binding("ability_2", "3")], "Changer de mode (Simon, Ashura)"], [[_binding("cancel_aim", "R")], "Annuler la visée"], [[_binding("qte_0", "J"), _binding("qte_1", "K"), _binding("qte_2", "L")], "Réponses d’archive"], [[_binding("emotes", "G")], "Roue d’émotes"], [[_binding("spectate", "Tab")], "Allié suivant (spectateur)"]]:
		_key_line(survivor, spec[0], str(spec[1]))
	var alice: VBoxContainer = _vbox(columns, 6)
	alice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alice.add_child(_kicker("ALICE", T.RED, 12))
	for spec: Array in [[[_binding("ability_0", "1")], "Griffes (capacité 1)"], [["1–6"], "Capacités"], [[_binding("ability_2", "3")], "Préparer les piques, clic ou 3 : confirmer"], [[key_label("cancel_aim", "R")], "Annuler la visée des piques"], [[_binding("ability_5", "6")], "True Form après 15 stuns"]]:
		_key_line(alice, spec[0], str(spec[1]))
	_spacer(alice, 10)
	alice.add_child(_kicker("PARTOUT", T.PAPER_DIM, 12))
	for spec: Array in [[[_binding("pause_game", "Échap")], "Pause / retour"], [[_binding("training_menu", "F2")], "Terrain d’essai"], [["F11"], "Plein écran"]]:
		_key_line(alice, spec[0], str(spec[1]))
	_spacer(content, 8)
	var edit_row: HBoxContainer = _hbox(content, 14)
	var edit_button: Button = _button("PERSONNALISER CLAVIER / MANETTE", func() -> void : world.controls_menu.open(), 0, "TealButton")
	edit_button.icon = Icons.icon("gamepad")
	edit_button.add_theme_constant_override("icon_max_width", 22)
	edit_row.add_child(edit_button)
	var pad: Label = _label("Manettes Xbox, PlayStation, Switch Pro et Steam Deck reconnues.", "body", 14, T.MUTED)
	pad.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	edit_row.add_child(pad)

func _key_line(parent: Node, keys: Array, action: String) -> void :
	var row: HBoxContainer = _hbox(parent, 10)
	var cap_box: HBoxContainer = _hbox(row, 4)
	cap_box.custom_minimum_size.x = 150
	cap_box.alignment = BoxContainer.ALIGNMENT_END
	for part: Variant in keys:
		if str(part).is_empty(): continue
		cap_box.add_child(W.KeyCap.new(str(part), 13))
	var label: Label = _label(action, "medium", 16, T.PAPER_DIM)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)

func _settings_access(content: VBoxContainer) -> void :
	_setting_row(content, "Réduire les flashs", "Aveuglement sombre au lieu de blanc, moins de secousses et d’animations d’interface.", _check(bool(world.options.get("reduce_flashes", false)), func(on: bool) -> void :
		_set_option("reduce_flashes", on)
		reduced_motion = on))
	_setting_row(content, "Daltonisme", "Palette orange / bleu pour distinguer alliés, danger et objectifs.", _check(bool(world.options.get("colorblind", false)), func(on: bool) -> void : _set_option("colorblind", on)))
	_spacer(content, 6)
	_paragraph("G · roue d’émotes. Simon OM : 3 alterne lancer et coup éclair. L’aura récompense les actions utiles ; 100 points débloquent les bonus pendant le LMS.", content, 14, T.MUTED)

func _settings_back() -> void :
	if world.phase == "playing":
		transition(func() -> void :
			if world.phase != "playing": return
			_clear(page)
			page.hide()
			hud.show()
			show_pause(true), "PAUSE", 1.0)
	else: show_main()





func _credit_lines(parent: VBoxContainer, text: String) -> void :
	var lines: PackedStringArray = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
	var gap: bool = false
	for index: int in range(lines.size()):
		var line: String = lines[index].strip_edges()
		if line.is_empty():
			if not gap: _spacer(parent, 4)
			gap = true
			continue
		gap = false
		if index == 0: continue
		var heading: bool = line == line.to_upper() and line.length() > 3 and not "http" in line and not "." in line.left(line.length() - 1)
		if heading: parent.add_child(_label(line, "caps", 13, T.PAPER))
		else: _paragraph(line, parent, 14, T.TEAL_DIM.lerp(T.PAPER_DIM, 0.6) if line.begins_with("http") else T.PAPER_DIM)

func show_credits() -> void :
	_begin_page("credits", "", 0.66)
	_backdrop(0.7, 0.95)
	var v: VBoxContainer = _form_panel(880)
	_form_header(v, "PAPER AFTERBELL", "Crédits")
	_section(v, "MUSIQUES & BRUITAGES")
	_credit_lines(v, FileAccess.get_file_as_string("res://audio/CREDITS.txt"))
	_section(v, "POLICES")
	_paragraph("Oswald, Barlow Semi Condensed, Anton, Bebas Neue, Caveat et un extrait d’Inter — SIL Open Font License 1.1. Licences complètes : ui/fonts.", v, 15, T.PAPER_DIM)
	_section(v, "ICÔNES")
	_paragraph(Icons.CREDITS, v, 15, T.PAPER_DIM)
	_spacer(v, 6)
	var back: Button = _button("←  RETOUR", show_main, 160)
	v.add_child(back)
	_end_page(back)




func show_gallery() -> void :
	_begin_page("gallery", "", 0.66)
	hide_gallery_transport()
	_backdrop(0.62, 0.9)
	var v: VBoxContainer = _form_panel(680)
	_form_header(v, "LES HISTOIRES APRÈS LA CLOCHE", "Cinémathèque")
	_paragraph("Revois les introductions et choisis qui affronte Alice. Les fins d’équipe s’adaptent aux survivants présents.", v, 16)
	var back: Button = _button("←  RETOUR AU JEU", func() -> void : world.gallery.close(), 0, "GhostButton")
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(back)
	var categories: Array = ["all", "intro", "lms_win", "lms_loss", "team"]
	var filters: HBoxContainer = _hbox(v, 10)
	var choice: OptionButton = OptionButton.new()
	choice.custom_minimum_size = Vector2(300, 46)
	filters.add_child(choice)
	for title: String in ["Toutes les scènes", "Introductions", "LMS · Le survivant s’échappe", "LMS · Alice gagne", "Fuite en équipe · Choisir les survivants"]: choice.add_item(title)
	choice.select(maxi(0, categories.find(world.gallery.category)))
	choice.item_selected.connect( func(index: int) -> void :
		world.gallery.category = categories[index]
		show_gallery())
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var search_field: LineEdit = _field("Rechercher un personnage ou une scène", str(world.gallery.search))
	search_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(search_field)
	search_field.text_changed.connect( func(value: String) -> void :
		world.gallery.search = value
		_refresh_gallery_results())
	if world.gallery.category == "team":
		_paragraph("Coche les personnages qui ont survécu pour voir leur fin exacte. Sans sélection, les 63 compositions sont affichées.", v, 15)
		var grid: GridContainer = GridContainer.new()
		grid.columns = 3
		v.add_child(grid)
		for person: String in PaperData.NAMES:
			var check: CheckButton = CheckButton.new()
			check.text = person
			check.button_pressed = world.gallery.team.has(person)
			check.custom_minimum_size = Vector2(190, 40)
			check.icon = PaperStatusIcon.portrait_for(person)
			check.expand_icon = false
			check.add_theme_constant_override("icon_max_width", 26)
			grid.add_child(check)
			check.toggled.connect( func(value: bool) -> void :
				if value: world.gallery.team.append(person)
				else: world.gallery.team.erase(person)
				_refresh_gallery_results())
		var shortcuts: HBoxContainer = _hbox(v, 10)
		shortcuts.add_child(_button("Simon + Usayuko", func() -> void :
			world.gallery.team = ["Simon", "Usayuko"]
			show_gallery(), 0))
		shortcuts.add_child(_button("Toute l’équipe", func() -> void :
			world.gallery.team = PaperData.NAMES.duplicate()
			show_gallery(), 0))
		shortcuts.add_child(_button("EFFACER LA SÉLECTION", func() -> void :
			world.gallery.team.clear()
			show_gallery(), 0, "GhostButton"))
	gallery_count = _label("", "caps", 12, T.TEAL)
	v.add_child(gallery_count)
	gallery_results = _vbox(v, 8)
	_refresh_gallery_results()
	_end_page(choice)

func _refresh_gallery_results() -> void :
	if not is_instance_valid(gallery_results): return
	_clear(gallery_results)
	var items: Array = world.gallery.filtered_entries()
	gallery_count.text = _t("%d SCÈNE%s  ·  CLIQUE POUR REGARDER") % [items.size(), "S" if items.size() != 1 else ""]
	if items.is_empty(): _paragraph("Aucune scène pour cette recherche. Essaie un nom de personnage ou efface la sélection.", gallery_results, 16)
	for item: Dictionary in items:
		var watch: Button = Button.new()
		watch.text = "▶  " + str(item.title)
		watch.alignment = HORIZONTAL_ALIGNMENT_LEFT
		watch.custom_minimum_size.y = 50
		watch.tooltip_text = str(item.description)
		watch.pressed.connect( func() -> void : world.gallery.play_entry(item))
		watch.pressed.connect(_sfx.bind("confirm"))
		watch.mouse_entered.connect(_sfx.bind("hover"))
		gallery_results.add_child(watch)
		var detail: Label = _label("%.1f s · %s" % [float(item.duration), str(item.description)], "body", 14, T.MUTED)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gallery_results.add_child(detail)
	if PaperLanguage.language == "en": PaperLanguage.apply_tree(gallery_results)

func show_gallery_transport(item: Dictionary) -> void :
	gallery_dragging = false
	gallery_resume = false
	if not is_instance_valid(gallery_controls):
		gallery_controls = Control.new()
		root.add_child(gallery_controls)
		gallery_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		gallery_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clear(gallery_controls)
	gallery_controls.show()
	var top: HBoxContainer = HBoxContainer.new()
	gallery_controls.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 32
	top.offset_right = -32
	top.offset_top = 22
	top.offset_bottom = 72
	top.add_theme_constant_override("separation", 22)
	top.add_child(_button("←  LES SCÈNES", func() -> void : world.gallery.browse(), 200))
	var title: Label = _label(str(item.title), "title", 24, T.PAPER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_shadow(title)
	top.add_child(title)
	var panel: PanelContainer = PanelContainer.new()
	gallery_controls.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 32
	panel.offset_right = -32
	panel.offset_top = -124
	panel.offset_bottom = -18
	panel.add_theme_stylebox_override("panel", T.sheet_style(26, 16, T.RED_DEEP, 41))
	var v: VBoxContainer = _vbox(panel, 8)
	gallery_timeline = HSlider.new()
	gallery_timeline.min_value = 0
	gallery_timeline.max_value = float(item.duration)
	gallery_timeline.step = 0.01
	gallery_timeline.custom_minimum_size.y = 22
	v.add_child(gallery_timeline)
	gallery_timeline.value_changed.connect( func(value: float) -> void :
		if gallery_updating: return
		if gallery_dragging: gallery_clock.text = _t("%.1f / %.1f s · Relâcher pour voir") % [value, gallery_timeline.max_value]
		else: world.gallery.seek(value))
	gallery_timeline.drag_started.connect( func() -> void :
		gallery_dragging = true
		gallery_resume = world.gallery.playing
		if gallery_resume: world.gallery.toggle_pause())
	gallery_timeline.drag_ended.connect( func(_changed: bool) -> void :
		var target: float = gallery_timeline.value
		gallery_dragging = false
		world.gallery.seek(target)
		if gallery_resume and target < world.film.duration and not world.gallery.playing: world.gallery.toggle_pause()
		gallery_resume = false)
	var row: HBoxContainer = _hbox(v, 14)
	gallery_pause = _button("PAUSE", func() -> void : world.gallery.toggle_pause(), 150, "TealButton")
	gallery_pause.custom_minimum_size.y = 42
	row.add_child(gallery_pause)
	var replay: Button = _button("REVOIR", func() -> void : world.gallery.restart(), 150)
	replay.custom_minimum_size.y = 42
	row.add_child(replay)
	gallery_clock = _label("", "num", 17, T.TEAL)
	gallery_clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gallery_clock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(gallery_clock)
	var keys: Label = _label("ESPACE · pause     ← → · 1 s     ÉCHAP · retour", "caps", 12, T.MUTED)
	keys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(keys)
	if PaperLanguage.language == "en": PaperLanguage.apply_tree(gallery_controls)

func update_gallery_transport(seconds: float, total: float, playing: bool) -> void :
	if not is_instance_valid(gallery_controls) or not gallery_controls.visible: return
	gallery_updating = true
	gallery_timeline.max_value = total
	if not gallery_dragging: gallery_timeline.value = seconds
	gallery_updating = false
	gallery_pause.text = _t("PAUSE" if playing else "REJOUER" if seconds >= total else "LECTURE")
	if not gallery_dragging: gallery_clock.text = "%.1f / %.1f s%s" % [seconds, total, _t(" · Scène terminée") if seconds >= total else ""]

func hide_gallery_transport() -> void :
	gallery_dragging = false
	gallery_resume = false
	if is_instance_valid(gallery_controls): gallery_controls.hide()




func show_hud() -> void :
	menu_paper = false
	_clear(page)
	_clear(overlay)
	page.hide()
	hud.show()
	announce_time = 0
	qte_panel.hide()
	_hud.on_show()

func toast(text: String, duration: float = 3) -> void :
	if text.is_empty(): return
	var shown: String = _touch_text(_t(text))

	for i: int in range(_toasts.size() - 1, 0, -1):
		_toasts[i].time = _toasts[i - 1].time
		_toasts[i].total = _toasts[i - 1].total
		_toasts[i].label.text = _toasts[i - 1].label.text
	_toasts[0].time = duration
	_toasts[0].total = duration
	toast_label.text = shown
	toast_label.show()
	for entry: Dictionary in _toasts: _fit_toast(entry.label)
	toast_time = maxf(toast_time, duration)
	_toast_box.show()
	for entry: Dictionary in _toasts: entry.panel.visible = entry.time > 0
	if not reduced_motion:
		var panel: Control = _toasts[0].panel
		panel.modulate.a = 0.0
		var tween: Tween = panel.create_tween()
		tween.tween_property(panel, "modulate:a", 1.0, 0.18)

func announcement(title: String, subtitle: String, duration: float = 3) -> void :
	announce_time = duration
	_hud.announce(title, subtitle, duration)

func update_hud(delta: float) -> void :
	combat_feedback.reduced_motion = reduced_motion
	if film_layer.visible:
		_toast_box.hide()
		flash.color.a = 0
		return
	_update_toasts(delta)
	damage_flash = maxf(0, damage_flash - delta)
	blind_flash = maxf(0, blind_flash - delta)
	flash.color = (Color(0.005, 0.005, 0.012, minf(blind_flash, 0.99)) if bool(world.options.reduce_flashes) else Color(0.95, 0.97, 1, minf(blind_flash, 0.96))) if blind_flash > 0 else Color(0.35, 0.02, 0.06, damage_flash * 0.24 if bool(world.options.reduce_flashes) else damage_flash * 0.4)
	announce_time = maxf(0, announce_time - delta)
	if not hud.visible: return
	_hud.update(delta)
	if qte_panel.visible:
		qte_time = world.clock - qte_started
		var value: float = fmod(qte_time, 2.4) / 2.4
		qte_bar.value = value * 100
		if is_instance_valid(_qte_zone):
			_qte_zone.value = value
			_qte_zone.queue_redraw()
		qte_hint.text = _t("Appuie entre 40 et 65 % pour aider.")
		if qte_time > 6: qte_panel.hide()

func _update_toasts(delta: float) -> void :

	if toast_time <= 0:
		for entry: Dictionary in _toasts:
			entry.time = 0.0
			entry.panel.visible = false
		return
	toast_time = maxf(0, toast_time - delta)
	var hidden: bool = (world.mobile_mode and world.pause_open) or (is_instance_valid(_pause_menu) and _pause_menu.is_inside_tree())
	_toast_box.visible = not hidden
	for entry: Dictionary in _toasts:
		if entry.time <= 0: continue
		entry.time = maxf(0.0, float(entry.time) - delta)
		var panel: Control = entry.panel
		panel.visible = entry.time > 0 and (entry.label != toast_label or toast_label.visible)
		if panel.visible and entry.time < 0.35: panel.modulate.a = float(entry.time) / 0.35

func _build_toasts() -> void :
	_toast_box = VBoxContainer.new()
	_toast_box.name = "Toasts"
	_toast_box.add_theme_constant_override("separation", 6)
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toast_box)
	_toast_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast_box.offset_left = -380
	_toast_box.offset_right = 380
	_toast_box.offset_top = 176
	_toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_box.set_meta("language_user_text", true)
	for i: int in range(3):
		var panel: PanelContainer = PanelContainer.new()
		var style: StyleBoxFlat = T.box(Color(0.03, 0.04, 0.065, 0.86 - i * 0.12), Color(1, 1, 1, 0.08), 1, 14, 18, 6)
		panel.add_theme_stylebox_override("panel", style)
		panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_toast_box.add_child(panel)
		var label: Label = _label("", "medium", 17 - i, T.PAPER if i == 0 else T.PAPER_DIM)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 0
		panel.add_child(label)
		panel.hide()
		_toasts.append({"panel": panel, "label": label, "time": 0.0, "total": 1.0})
	toast_label = _toasts[0].label
	_limit_toast_width()

func _limit_toast_width() -> void :
	for entry: Dictionary in _toasts: _fit_toast(entry.label)


func _fit_toast(label: Label) -> void :
	var limit: float = 480.0 if world.mobile_mode else 700.0
	var width: float = label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
	if width > limit:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = limit
	else:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.custom_minimum_size.x = 0

func receive_combat_feedback(data: Dictionary) -> void :
	if not data.is_empty(): combat_feedback.receive(data, world.camera, world.local_actor())

func update_performance(ping: float) -> void :
	if not is_instance_valid(performance_label): return
	var show_fps: bool = bool(world.options.get("show_fps", false))
	var remote: bool = world.networked and not world.authoritative()
	performance_label.visible = world.phase not in ["gallery", "ending"] and (show_fps or remote) and not film_layer.visible
	if not performance_label.visible: return
	var parts: PackedStringArray = []
	if show_fps: parts.append("%d FPS" % Engine.get_frames_per_second())
	if world.networked: parts.append("0 ms · " + _t("HÔTE") if world.authoritative() else "%d ms" % int(round(ping)) if ping >= 0 else "PING —")
	var text: String = "  ·  ".join(parts)
	if performance_label.text != text: performance_label.text = text




func show_pause(open: bool) -> void :
	menu_paper = false
	_pause_confirm = false
	if not open and is_instance_valid(_pause_menu) and _pause_menu.is_inside_tree() and overlay.is_ancestor_of(_pause_menu):
		# Fermeture rapide en sens inverse (la partie reprend pendant ce temps).
		for child: Node in overlay.get_children():
			if child != _pause_menu:
				overlay.remove_child(child)
				child.queue_free()
		_pause_menu.call("close_animated")
		_pause_menu = null
		return
	_clear(overlay)
	if not open: return
	if not bool(world.get("dedicated")):
		_pause_menu = PauseMenu.new()
		overlay.add_child(_pause_menu)
		_pause_menu.call("setup", self)
		if PaperLanguage.language == "en": PaperLanguage.apply_tree(overlay)
		return
	_dim(overlay, 0.74)
	var card: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = T.panel_style(0.97, T.LINE, 10)
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 34
	style.content_margin_bottom = 30
	card.add_theme_stylebox_override("panel", style)
	overlay.add_child(card)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.offset_left = -250
	card.offset_right = 250
	card.offset_top = 0
	card.offset_bottom = 0
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	card.resized.connect( func() -> void : card.pivot_offset = card.size * 0.5)
	var v: VBoxContainer = _vbox(card, 12)
	v.add_child(_kicker("PAUSE" if not world.networked else "LA MANCHE CONTINUE"))
	v.add_child(_label("La cloche attend" if not world.networked else "Les amis jouent encore", "title", 36, T.PAPER))
	var rule: W.Rule = W.Rule.new()
	v.add_child(rule)
	var actions: VBoxContainer = _vbox(v, 10)
	_fill_pause_actions(actions)
	_spacer(v, 4)
	if world.mobile_mode:
		_paragraph("Touche REPRENDRE pour continuer.\nLes amis continuent de jouer en ligne." if world.networked else "Touche REPRENDRE pour continuer.", v, 15, T.MUTED)
	else:
		var keys: HBoxContainer = _hbox(v, 8)
		for spec: Array in [[_binding("pause_game", "Échap"), "reprendre"], ["1–6", "capacités"], [_binding("interact", "E"), "interagir"]]:
			var cap: W.KeyCap = W.KeyCap.new(str(spec[0]), 12)
			cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			keys.add_child(cap)
			var l: Label = _label(str(spec[1]), "medium", 14, T.MUTED)
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			keys.add_child(l)
	if not reduced_motion:
		card.scale = Vector2(0.96, 0.96)
		card.modulate.a = 0.0
		var tween: Tween = card.create_tween().set_parallel()
		tween.tween_property(card, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "modulate:a", 1.0, 0.15)
	if PaperLanguage.language == "en": PaperLanguage.apply_tree(overlay)

# Actions du menu pause (mêmes effets qu'avant la refonte).
func _pause_resume() -> void :
	world.pause_open = false
	world.capture_gameplay_mouse()
	show_pause(false)

func _pause_settings() -> void :
	transition(func() -> void :
		_clear(overlay)
		show_settings(), "RÉGLAGES")

func _pause_controls() -> void :
	transition(func() -> void :
		_clear(overlay)
		world.controls_menu.open(), "COMMANDES")

func _fill_pause_actions(actions: VBoxContainer) -> void :
	_clear(actions)
	if _pause_confirm:
		actions.add_child(_label("Quitter la manche en cours ?", "semibold", 19, T.PAPER))
		_paragraph("Tu retourneras au menu principal." if not world.networked else "Tu quitteras le salon de tes amis.", actions, 15, T.MUTED)
		var yes: Button = _button("OUI, QUITTER", func() -> void : world.quit_to_menu(), 0, "DangerButton")
		actions.add_child(yes)
		actions.add_child(_button("ANNULER", func() -> void :
			_pause_confirm = false
			_fill_pause_actions(actions), 0))
		yes.call_deferred("grab_focus")
		if PaperLanguage.language == "en": PaperLanguage.apply_tree(actions)
		return
	var resume: Button = _button("REPRENDRE", func() -> void :
		world.pause_open = false
		world.capture_gameplay_mouse()
		show_pause(false), 0, "PrimaryButton")
	actions.add_child(resume)
	actions.add_child(_button("RÉGLAGES", func() -> void :
		_clear(overlay)
		show_settings(), 0))
	actions.add_child(_button("QUITTER LA PARTIE", func() -> void :
		_pause_confirm = true
		_fill_pause_actions(actions), 0, "DangerButton"))
	resume.call_deferred("grab_focus")
	if PaperLanguage.language == "en": PaperLanguage.apply_tree(actions)




func show_ending(winner: String, was_lms: bool) -> void :
	menu_paper = false
	_page_rerender = false
	toast_time = 0
	toast_label.hide()
	blind_flash = 0
	damage_flash = 0
	flash.color.a = 0
	_clear(overlay)
	_clear(page)
	page.hide()
	hud.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	current_page = "ending"
	var shade: ColorRect = ColorRect.new()
	overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.03, 0.035, 0.055, 0.97)
	var killer_won: bool = winner == "killer"
	var accent: Color = T.RED if killer_won else T.TEAL

	var spot: TextureRect = TextureRect.new()
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(accent, 0.2))
	gradient.set_color(1, Color(accent, 0.0))
	var radial: GradientTexture2D = GradientTexture2D.new()
	radial.gradient = gradient
	radial.fill = GradientTexture2D.FILL_RADIAL
	radial.fill_from = Vector2(0.5, 0.55)
	radial.fill_to = Vector2(0.5, 1.05)
	spot.texture = radial
	spot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spot.stretch_mode = TextureRect.STRETCH_SCALE
	spot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(spot)
	spot.anchor_left = 0
	spot.anchor_right = 0.42
	spot.anchor_top = 0.24
	spot.anchor_bottom = 1
	var decor: MenuFx.Decor = MenuFx.Decor.new()
	decor.reduced = reduced_motion
	decor.title = "ALICE" if killer_won else "ÉVASION"
	decor.accent = accent
	decor.band_alpha = 0.6
	decor.band_a = Vector2(-0.05, 0.95)
	decor.band_b = Vector2(0.62, -0.1)
	decor.band_width = 300.0
	decor.giant_alpha = 0.07
	decor.ribbon_text = "LE BULLETIN DE LA NUIT"
	overlay.add_child(decor)
	var header: VBoxContainer = VBoxContainer.new()
	header.add_theme_constant_override("separation", 0)
	overlay.add_child(header)
	header.anchor_left = 0
	header.anchor_right = 0.42
	header.offset_left = 56
	header.offset_right = -12
	header.offset_top = 34
	header.add_child(_kicker("LE BULLETIN DE LA NUIT"))
	var verdict: Control = _display_title("VICTOIRE D’ALICE" if killer_won else "LES ÉLÈVES S’ÉCHAPPENT", 70, accent.darkened(0.15), 500.0)
	header.add_child(verdict)
	header.rotation_degrees = -3.0
	if was_lms:
		var lms_line: Label = _label("LAST MAN STANDING", "caps_wide", 15, T.GOLD)
		header.add_child(lms_line)

	result_view = PaperResultsView.new()
	overlay.add_child(result_view)
	result_view.anchor_left = 0.02
	result_view.anchor_right = 0.4
	result_view.anchor_top = 0.3
	result_view.anchor_bottom = 0.86
	result_view.setup()
	var name_box: VBoxContainer = VBoxContainer.new()
	name_box.add_theme_constant_override("separation", 0)
	overlay.add_child(name_box)
	name_box.anchor_left = 0.04
	name_box.anchor_right = 0.4
	name_box.anchor_top = 0.84
	name_box.anchor_bottom = 0.84
	_result_name = _label("", "title", 30, T.PAPER)
	name_box.add_child(_result_name)
	_result_player = _label("", "medium", 16, T.PAPER_DIM)
	_result_player.set_meta("language_user_text", true)
	name_box.add_child(_result_player)

	var sheet: PanelContainer = PanelContainer.new()
	var paper: W.PaperStyle = _paper_style(58, 30, true)
	paper.ruled = true
	paper.margin_line = true
	paper.content_margin_left = 48
	sheet.add_theme_stylebox_override("panel", paper)
	overlay.add_child(sheet)
	sheet.anchor_left = 0.44
	sheet.anchor_right = 0.97
	sheet.anchor_top = 0.05
	sheet.anchor_bottom = 0.84
	sheet.resized.connect( func() -> void : sheet.pivot_offset = sheet.size * 0.5)
	sheet.rotation_degrees = 0.6
	var body: VBoxContainer = _vbox(sheet, 6)
	var sheet_head: HBoxContainer = _hbox(body, 10)
	var titles: VBoxContainer = _vbox(sheet_head, 0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(_label("Bulletin de la nuit", "hand", 34, T.RED_INK))
	titles.add_child(_label("CLASSEMENT · CONTRIBUTION À LA PARTIE", "caps", 12, T.INK_MUTED))
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var rows: VBoxContainer = _vbox(scroll, 4)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_rows.clear()
	var rank: int = 0
	for record: Dictionary in world.match_results:
		rank += 1
		rows.add_child(_result_row(record.duplicate(true), rank))
	if world.match_results.is_empty(): _paragraph("Aucun élève n’a été noté pour cette manche.", rows, 16, T.INK_MUTED)
	var rule: ColorRect = ColorRect.new()
	rule.color = Color(T.INK_TEXT, 0.18)
	rule.custom_minimum_size.y = 1
	body.add_child(rule)
	result_detail = _label("", "medium", 15, T.INK_TEXT)
	result_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_detail.set_meta("language_user_text", true)
	body.add_child(result_detail)
	_paragraph("Les soins effectifs, stuns, boosts, protections et le temps passé en danger comptent. Choisis un élève pour voir sa réaction.", body, 13, T.INK_MUTED)
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 14)
	overlay.add_child(actions)
	actions.anchor_left = 1
	actions.anchor_right = 1
	actions.anchor_top = 1
	actions.anchor_bottom = 1
	actions.offset_right = -44
	actions.offset_left = -44
	actions.offset_bottom = -30
	actions.offset_top = -30
	actions.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	actions.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var again: Button = _button("RETOUR AU SALON" if world.networked else "NOUVELLE MANCHE", func() -> void : world.return_to_lobby(), 280, "PrimaryButton")
	actions.add_child(_button("MENU PRINCIPAL", func() -> void : world.quit_to_menu(), 220))
	actions.add_child(again)
	if not world.match_results.is_empty(): _present_result(world.match_results[0])
	_intro(header)
	if not reduced_motion:
		# Le verdict se plaque, la feuille de notes pivote depuis la droite,
		# les lignes du classement arrivent en cascade.
		header.pivot_offset = Vector2(0, 60)
		header.scale = Vector2(1.5, 1.5)
		header.modulate.a = 0.0
		var slam: Tween = header.create_tween().set_parallel()
		slam.tween_property(header, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		slam.tween_property(header, "modulate:a", 1.0, 0.1)
		sheet.modulate.a = 0.0
		var tween: Tween = sheet.create_tween().set_parallel()
		var goal: float = sheet.rotation
		sheet.rotation = goal + 0.09
		tween.tween_property(sheet, "modulate:a", 1.0, 0.16).set_delay(0.1)
		tween.tween_property(sheet, "rotation", goal, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.1)
		Sound.play("swoosh")
		fx.cascade_children(rows, 0.24, 0.05, Vector2(110, 0), 0.06, 0.28)
		fx.cascade_children(actions, 0.5, 0.06, Vector2(0, 70), -0.08, 0.24)
	elif reduced_motion:
		_soft_fade(overlay)
	if PaperLanguage.language == "en": PaperLanguage.apply_tree(overlay)
	again.call_deferred("grab_focus")


func _result_row(row: Dictionary, rank: int) -> Button:
	var line: Button = Button.new()
	line.custom_minimum_size.y = 58
	line.focus_mode = Control.FOCUS_ALL
	for state: String in ["normal", "pressed", "disabled"]: line.add_theme_stylebox_override(state, T.empty_style())
	var lit_mark: StyleBox = T.marker(Color(0.95, 0.78, 0.3, 0.42), 0, 0)
	lit_mark.set("boil", true)
	line.add_theme_stylebox_override("hover", lit_mark)
	line.add_theme_stylebox_override("hover_pressed", T.marker(Color(0.95, 0.78, 0.3, 0.55), 0, 0))
	line.add_theme_stylebox_override("focus", lit_mark)
	line.pressed.connect(_present_result.bind(row))
	line.pressed.connect(_sfx.bind("click"))
	line.mouse_entered.connect(_sfx.bind("hover"))
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(h)
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 6
	h.offset_right = -6
	var number: Label = _label("%d." % rank, "hand", 26, T.INK_MUTED)
	number.custom_minimum_size.x = 30
	number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(number)
	var icon: PaperStatusIcon = PaperStatusIcon.new()
	var person: String = str(row.get("character", "Ashura"))
	icon.setup(person)
	icon.compact = true
	icon.custom_minimum_size = Vector2(46, 46)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fate: String = _fate(row)
	icon.update_state("escaped" if fate == "escaped" else "dead" if fate == "dead" else "alive", false)
	h.add_child(icon)
	var names: VBoxContainer = VBoxContainer.new()
	names.add_theme_constant_override("separation", -2)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(names)
	names.add_child(_label(person.to_upper(), "title", 19, T.INK_TEXT))
	var player: Label = _label(_player_name(row), "medium", 14, T.INK_MUTED)
	player.set_meta("language_user_text", true)
	names.add_child(player)
	if not fate.is_empty():
		var tag: Label = _label({"escaped": "ÉVADÉ", "dead": "TOMBÉ", "alive": "EN VIE"}.get(fate, ""), "caps", 11, Color("2e6d68") if fate == "escaped" else T.INK_MUTED)
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(tag)
	var points: Label = _label("%d" % int(row.get("points", 0)), "digits", 30, T.INK_TEXT)
	points.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	points.custom_minimum_size.x = 52
	points.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(points)
	var unit: Label = _label("pts", "caps", 11, T.INK_MUTED)
	unit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(unit)
	var stamp: W.Stamp = W.Stamp.new()
	stamp.configure(str(row.get("grade", "C")), 26, T.RED_INK, true, -12.0 + float(rank % 3) * 6.0)
	stamp.custom_minimum_size = Vector2(54, 54)
	stamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(stamp)
	_result_rows.append({"button": line, "row": row})
	if rank <= 6 and not reduced_motion: stamp.ready.connect(stamp.slam_after.bind(0.35 + rank * 0.12))
	return line


func _player_name(row: Dictionary) -> String:
	var shown: String = str(row.get("name", ""))
	var prefix: String = str(row.get("character", "")) + " · "
	if shown.begins_with(prefix): return _t(shown.substr(prefix.length()))
	return shown

func _fate(row: Dictionary) -> String:
	var id: int = int(row.get("id", -1))
	if world.exit_flow and world.exit_flow.escaped.has(id): return "escaped"
	var actor: PaperActor = world.actors.get(id)
	if actor == null: return ""
	if bool(actor.effects.get("escaped", false)): return "escaped"
	return "alive" if actor.alive else "dead"

func _present_result(row: Dictionary) -> void :
	if is_instance_valid(result_view): result_view.present(row)
	for entry: Dictionary in _result_rows:
		var selected: bool = int(entry.row.get("id", -1)) == int(row.get("id", -2))
		var style: StyleBox = T.marker(Color(0.95, 0.78, 0.3, 0.3), 0, 0) if selected else T.empty_style()
		entry.button.add_theme_stylebox_override("normal", style)
	var breakdown: Dictionary = row.get("breakdown", {})
	var parts: Array[String] = []
	for key: String in breakdown:
		if float(breakdown[key]) > 0: parts.append(PaperLanguage.breakdown_label(key) + " : " + str(int(breakdown[key])))
	if is_instance_valid(_result_name): _result_name.text = str(row.get("character", "")).to_upper() + "  ·  " + _t("NOTE") + " " + str(row.get("grade", ""))
	if is_instance_valid(_result_player): _result_player.text = _player_name(row)
	var aura_line: String = _t("AURA · %d / 100") % int(row.get("aura", 0))
	result_detail.text = ("  ·  ".join(parts) if not parts.is_empty() else _t("Aucune action notée.")) + "\n" + aura_line




func _build_qte_assist() -> void :
	qte_panel = PanelContainer.new()
	var style: StyleBoxFlat = T.box(Color(0.04, 0.055, 0.08, 0.96), T.TEAL, 2, 10, 26, 20)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 18
	qte_panel.add_theme_stylebox_override("panel", style)
	root.add_child(qte_panel)
	qte_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	qte_panel.offset_left = -270
	qte_panel.offset_right = 270
	qte_panel.offset_top = -120
	qte_panel.offset_bottom = 120
	qte_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	qte_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	qte_panel.hide()
	var q: VBoxContainer = _vbox(qte_panel, 12)
	var head: HBoxContainer = _hbox(q, 10)
	head.add_child(_icon_rect("outlet", 26, T.TEAL))
	head.add_child(_label("ASSISTANCE · LYSIA", "title", 24, T.TEAL))
	qte_hint = _label("", "medium", 17, T.PAPER)
	q.add_child(qte_hint)
	qte_bar = ProgressBar.new()
	qte_bar.max_value = 100
	qte_bar.show_percentage = false
	qte_bar.visible = false
	q.add_child(qte_bar)
	_qte_zone = TimingBar.new()
	_qte_zone.custom_minimum_size.y = 14
	q.add_child(_qte_zone)
	var choices: HBoxContainer = _hbox(q, 12)
	var armour: Button = _button("+ ARMURE", func() -> void : _qte_press("health"), 230, "TealButton")
	armour.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_child(armour)
	var heal: Button = _button("+ SOINS", func() -> void : _qte_press("stamina"), 230, "TealButton")
	heal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_child(heal)

func show_qte(actor_id: int, started: float) -> void :
	var local: PaperActor = world.local_actor()
	if local and local.alive: return
	qte_actor = actor_id
	qte_started = started
	qte_time = world.clock - started
	qte_panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if PaperLanguage.language == "en": PaperLanguage.apply_tree(qte_panel)
	toast("Lysia t'appelle : aide-la à tenir !", 4)

func _qte_press(choice: String) -> void :
	var value: float = fmod(qte_time, 2.4) / 2.4
	if value >= 0.4 and value <= 0.65:
		world.request_assist(qte_actor, choice)
		toast("Signal transmis à Lysia.")
	else: toast("Signal manqué. Attends le prochain appel.")
	qte_panel.hide()
	qte_actor = -1




func show_training_panel(open: bool = true) -> void :
	_clear(overlay)
	if not open: return
	_dim(overlay, 0.74)
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBox = T.sheet_style(30, 22, T.TEAL_DEEP, 47)
	style.content_margin_left = 34
	style.content_margin_right = 26
	panel.add_theme_stylebox_override("panel", style)
	overlay.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -470
	panel.offset_right = 470
	panel.offset_top = -380 if not world.mobile_mode else -330
	panel.offset_bottom = 380 if not world.mobile_mode else 330
	var view_height: float = get_viewport().get_visible_rect().size.y
	panel.offset_top = maxf(panel.offset_top, - view_height * 0.5 + 20)
	panel.offset_bottom = minf(panel.offset_bottom, view_height * 0.5 - 20)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var v: VBoxContainer = _vbox(scroll, 10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_kicker("TERRAIN D’ESSAI"))
	v.add_child(_display_title("Le terrain d’essai", 40, T.TEAL_DIM))
	_paragraph("Teste les vrais coups et les vrais effets. Les cibles reviennent après deux secondes. F2 ferme ce panneau.", v, 16)
	var actor: PaperActor = world.local_actor()
	if not actor: return
	_section(v, "TON PERSONNAGE")
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	var focus_first: Button = null
	for character_name: String in ["Alice", "Ashura", "Elly", "Lysia", "Bleuette", "Usayuko", "Simon"]:
		var chosen: String = character_name
		var owner: String = world.practice.human_owner(chosen, actor.id)
		var button: Button = _button(chosen + (" · pris" if not owner.is_empty() else ""), func() -> void :
			world.training_action("character", chosen)
			_resume_training(), 208, "TealButton" if chosen == actor.character else "")
		button.icon = PaperStatusIcon.portrait_for(chosen)
		button.expand_icon = false
		button.add_theme_constant_override("icon_max_width", 30)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.disabled = not owner.is_empty()
		grid.add_child(button)
		if focus_first == null: focus_first = button
	var row: HBoxContainer = _hbox(v, 10)
	var recharge: Button = _button("TOUT RECHARGER", func() -> void : world.training_action("reset"), 0)
	recharge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(recharge)
	var lms: Button = _button("PRÉPARER LA TRUE FORM" if actor.killer else "ACTIVER MON LMS", func() -> void :
		world.training_action("lms")
		_resume_training(), 0, "PrimaryButton")
	lms.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lms)
	var positions: HBoxContainer = _hbox(v, 10)
	for spec: Array in [["FACE À LA CIBLE", "near"], ["DERRIÈRE LA CIBLE", "behind"], ["PRÈS DU MANNEQUIN ALLIÉ", "ally_near"]]:
		var action: String = str(spec[1])
		var b: Button = _button(str(spec[0]), func() -> void :
			world.training_action(action)
			_resume_training(), 0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		positions.add_child(b)
	var life_tests: HBoxContainer = _hbox(v, 10)
	var down_test: Button = _button("TESTER MA CHUTE / SECONDE VIE", func() -> void :
		world.training_action("down_self")
		_resume_training(), 0)
	down_test.disabled = actor.killer
	down_test.tooltip_text = "Les survivants peuvent être mis au sol. Alice est invulnérable."
	down_test.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	life_tests.add_child(down_test)
	var archive_test: Button = _button("TESTER UNE ARCHIVE + QTE", func() -> void :
		world.training_action("archive_test")
		_resume_training(), 0)
	archive_test.disabled = not world.can_manage_lobby() or actor.killer
	archive_test.tooltip_text = "L’hôte réinitialise les archives communes. Approche une archive pour y travailler."
	archive_test.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	life_tests.add_child(archive_test)
	if world.can_manage_lobby():
		_section(v, "CIBLES COMMUNES · RÉGLAGES DE L’HÔTE")
		var modes: HBoxContainer = _hbox(v, 10)
		for mode: String in ["idle", "walk", "attack"]:
			var choice: String = mode
			var b: Button = _button({"idle": "IMMOBILES", "walk": "EN MOUVEMENT", "attack": "ALICE ATTAQUE"}[mode], func() -> void :
				world.training_action("dummy_mode", choice)
				_resume_training(), 0, "TealButton" if world.practice.dummy_mode == choice else "")
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			modes.add_child(b)
		_paragraph("Alice attaque les joueurs à portée : approche-toi pour tester blocage, contre et soins. En mouvement, les mannequins marchent entre leurs repères.", v, 14, T.MUTED)
		var ally_row: HBoxContainer = _hbox(v, 12)
		var ally_label: Label = _label("MANNEQUIN ALLIÉ · TESTER LES BONUS DE BLEUETTE", "caps", 12, T.TEAL)
		ally_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ally_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ally_row.add_child(ally_label)
		var ally: OptionButton = OptionButton.new()
		ally.custom_minimum_size = Vector2(260, 42)
		ally_row.add_child(ally)
		for character_name: String in PaperData.NAMES: ally.add_item(character_name)
		for target: PaperActor in world.actors.values():
			if world.practice.is_dummy(target) and target.display_name.begins_with("Allié"): ally.select(PaperData.NAMES.find(target.character))
		ally.item_selected.connect( func(index: int) -> void : world.training_action("dummy_character", PaperData.NAMES[index]))
		var reset_row: HBoxContainer = _hbox(v, 10)
		for spec: Array in [["BLESSER LES ALLIÉS · −50 PV", "injure", false], ["RÉINITIALISER LE TERRAIN", "reset_all", false], ["ALLIÉ AU SOL · TESTER LA RÉANIMATION", "down_ally", true]]:
			var action: String = str(spec[1])
			var resume: bool = bool(spec[2])
			var b: Button = _button(str(spec[0]), func() -> void :
				world.training_action(action)
				if resume: _resume_training(), 0)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			reset_row.add_child(b)
		v.add_child(_button("METTRE LES CAPACITÉS ALLIÉES EN RECHARGE · 20 S", func() -> void : world.training_action("ally_cooldown"), 0))
	else: _paragraph("L’hôte règle les mannequins. Tu peux changer ton personnage, le recharger et activer ton LMS librement.", v, 15)
	_spacer(v, 4)
	var exit_row: HBoxContainer = _hbox(v, 10)
	var resume_button: Button = _button("REPRENDRE LES ESSAIS", _resume_training, 0, "PrimaryButton")
	resume_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exit_row.add_child(resume_button)
	var leave: Button = _button("RETOUR AU SALON" if world.networked and world.authoritative() else "MENU PRINCIPAL", func() -> void :
		if world.authoritative(): world.return_to_lobby()
		else: world.quit_to_menu(), 0, "DangerButton")
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exit_row.add_child(leave)
	if PaperLanguage.language == "en": PaperLanguage.apply_tree(overlay)
	resume_button.call_deferred("grab_focus")
	if is_instance_valid(fx) and not reduced_motion: fx.cascade_children(v, 0.0, 0.02, Vector2(-60, 0), -0.05, 0.22)

func _resume_training() -> void :
	world.pause_open = false
	world.capture_gameplay_mouse()
	_clear(overlay)




func show_loading(map_id: String, characters: Array = []) -> void :
	menu_paper = false
	_page_rerender = false
	_clear(page)
	_clear(overlay)
	page.show()
	hide_film()
	hud.hide()
	qte_panel.hide()
	current_page = "loading"
	toast_time = 0
	toast_label.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	blind_flash = 0
	damage_flash = 0
	flash.color.a = 0
	var base: ColorRect = ColorRect.new()
	base.color = T.BG
	page.add_child(base)
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading_art = TextureRect.new()
	_loading_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_loading_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_loading_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(_loading_art)
	_loading_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for path: String in ["res://ui/maps/om_" + map_id + ".png", "res://ui/maps/" + map_id + ".jpg"]:
		if ResourceLoader.exists(path):
			_loading_art.texture = load(path)
			break
	_loading_art.modulate = Color(0.92, 0.94, 1.0)
	if not reduced_motion:
		_loading_art.resized.connect( func() -> void : _loading_art.pivot_offset = _loading_art.size * 0.5)
		_loading_art.scale = Vector2(1.02, 1.02)
		var drift: Tween = _loading_art.create_tween()
		drift.tween_property(_loading_art, "scale", Vector2(1.09, 1.09), 9.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_backdrop(0.64, 0.86)
	var vignette: TextureRect = TextureRect.new()
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, 0))
	gradient.set_color(1, Color(0.02, 0.02, 0.04, 0.65))
	var radial: GradientTexture2D = GradientTexture2D.new()
	radial.gradient = gradient
	radial.fill = GradientTexture2D.FILL_RADIAL
	radial.fill_from = Vector2(0.62, 0.45)
	radial.fill_to = Vector2(1.25, 1.1)
	vignette.texture = radial
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(vignette)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var local_person: String = ""
	var local: Node = world.local_actor() if world.has_method("local_actor") else null
	if local: local_person = str(local.get("character"))
	elif characters.size() == 1: local_person = str(characters[0])
	if not local_person.is_empty(): _loading_cutout(local_person)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	page.add_child(column)
	column.anchor_top = 0.2
	column.anchor_bottom = 0.2
	column.offset_left = 72
	column.offset_right = 72 + 980
	column.add_child(_kicker("MANCHE OM  ·  PRÉPARATION"))
	_spacer(column, 6)
	var title: Label = _label(_t(str(world.MAP_NAMES.get(map_id, map_id))).to_upper(), "display", 82, T.PAPER)
	title.set_meta("language_user_text", true)
	_shadow(title, 0.5)
	column.add_child(title)
	var tagline: Label = _label(str(MAP_TAGLINES.get(map_id, "")), "hand", 36, T.RED)
	tagline.rotation_degrees = -1.6
	column.add_child(tagline)

	var cast_box: VBoxContainer = VBoxContainer.new()
	cast_box.add_theme_constant_override("separation", 10)
	page.add_child(cast_box)
	cast_box.anchor_top = 1
	cast_box.anchor_bottom = 1
	cast_box.offset_left = 72
	cast_box.offset_bottom = -78
	cast_box.offset_top = -78
	cast_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	cast_box.add_child(_kicker("LES PRÉSENCES DE CETTE MANCHE", T.PAPER_DIM, 12))
	var cast: HBoxContainer = _hbox(cast_box, 14)
	var killer_present: bool = false
	for person: Variant in characters:
		if str(person) == "Alice":
			killer_present = true
			continue
		cast.add_child(_cast_tile(str(person), false))
	if killer_present:
		var separator: ColorRect = ColorRect.new()
		separator.color = Color(T.RED, 0.6)
		separator.custom_minimum_size = Vector2(2, 90)
		separator.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cast.add_child(separator)
		cast.add_child(_cast_tile("Alice", true))

	var note: PanelContainer = PanelContainer.new()
	var paper: W.PaperStyle = _paper_style(91, 20, true)
	note.add_theme_stylebox_override("panel", paper)
	page.add_child(note)
	note.anchor_left = 1
	note.anchor_right = 1
	note.anchor_top = 1
	note.anchor_bottom = 1
	note.offset_right = -64
	note.offset_left = -64 - 380
	note.offset_bottom = -82
	note.offset_top = -82
	note.grow_vertical = Control.GROW_DIRECTION_BEGIN
	note.resized.connect( func() -> void : note.pivot_offset = note.size * 0.5)
	note.rotation_degrees = 1.3
	var tip_box: VBoxContainer = _vbox(note, 4)
	tip_box.add_child(_label("Astuce", "hand", 28, T.RED_INK))
	loading_tip = _label("", "medium", 17, T.INK_TEXT)
	loading_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	loading_tip.custom_minimum_size = Vector2(330, 72)
	loading_tip.set_meta("language_user_text", true)
	tip_box.add_child(loading_tip)
	_tip_start = randi() % TIPS.size()
	_tip_index = -1

	loading_label = _label("Préparation de la carte…", "caps", 13, T.PAPER_DIM)
	page.add_child(loading_label)
	loading_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	loading_label.offset_left = -640
	loading_label.offset_right = -64
	loading_label.offset_top = -58
	loading_label.offset_bottom = -38
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	loading_label.set_meta("language_user_text", true)
	loading_bar = ProgressBar.new()
	loading_bar.show_percentage = false
	loading_bar.max_value = 100
	page.add_child(loading_bar)
	loading_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	loading_bar.offset_left = 72
	loading_bar.offset_right = -64
	loading_bar.offset_top = -28
	loading_bar.offset_bottom = -24
	loading_bar.value = 0
	var ribbon: MenuFx.Decor = MenuFx.Decor.new()
	ribbon.reduced = reduced_motion
	ribbon.band_alpha = 0.0
	ribbon.giant_alpha = 0.0
	ribbon.ribbon_text = "MANCHE OM  ·  PRÉPARATION"
	page.add_child(ribbon)
	_update_tip(0.0)
	_intro(column)
	if PaperLanguage.language == "en": PaperLanguage.apply_tree(page)


func _loading_cutout(person: String) -> void :
	var texture: Texture2D = MenuBackdrop.art(person)
	if texture == null: return
	var view: Vector2 = get_viewport().get_visible_rect().size
	var art: TextureRect = TextureRect.new()
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var height: float = view.y * (0.92 if person == "Alice" else 0.84)
	var width: float = height * float(texture.get_width()) / float(texture.get_height())
	page.add_child(art)
	art.anchor_left = 1
	art.anchor_right = 1
	art.anchor_top = 1
	art.anchor_bottom = 1
	var right: float = -60.0 - (mobile_safe_edges().y if world.mobile_mode else 0.0)
	art.offset_right = right
	art.offset_left = right - width
	art.offset_bottom = 10
	art.offset_top = 10 - height
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = preload("res://ui_menu_cutout.gdshader")
	material.set_shader_parameter("mask", MenuBackdrop.art("ink_noise"))
	material.set_shader_parameter("edge_color", MenuBackdrop.accent_for(person))
	material.set_shader_parameter("reveal", 1.0 if reduced_motion else 0.0)
	art.material = material
	if reduced_motion: return
	art.position.y += 40.0
	var tween: Tween = art.create_tween().set_parallel()
	tween.tween_method( func(value: float) -> void : material.set_shader_parameter("reveal", value), 0.0, 1.0, 0.9).set_delay(0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(art, "position:y", art.position.y - 40.0, 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _cast_tile(person: String, killer: bool) -> VBoxContainer:
	var tile: VBoxContainer = VBoxContainer.new()
	tile.add_theme_constant_override("separation", 6)
	var frame: PanelContainer = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", T.box(MenuBackdrop.accent_for(person).darkened(0.62), T.RED if killer else Color(T.PAPER, 0.28), 2, 6, 3, 3))
	frame.custom_minimum_size = Vector2(76, 76) if not killer else Vector2(88, 88)
	tile.add_child(frame)
	var photo: TextureRect = TextureRect.new()
	var square: Texture2D = MenuBackdrop.bust_square(person)
	photo.texture = square if square else PaperStatusIcon.portrait_for(person)
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	frame.add_child(photo)
	var label: Label = _label(person.to_upper(), "caps", 12, T.RED if killer else T.PAPER)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.add_child(label)
	tile.size_flags_vertical = Control.SIZE_SHRINK_END
	return tile

func _update_tip(elapsed: float) -> void :
	if not is_instance_valid(loading_tip): return
	var index: int = (_tip_start + int(elapsed / 4.5)) % TIPS.size()
	if index == _tip_index: return
	_tip_index = index
	loading_tip.text = _touch_text(_t(TIPS[index]))
	if not reduced_motion and elapsed > 0.1:
		loading_tip.modulate.a = 0.0
		var tween: Tween = loading_tip.create_tween()
		tween.tween_property(loading_tip, "modulate:a", 1.0, 0.3)

func update_loading(elapsed: float, ready: int, total: int) -> void :
	if not is_instance_valid(loading_label): return
	var dots: String = ".".repeat(1 + int(elapsed * 2) % 3)
	loading_label.text = _t("En attente des joueurs · %d/%d") % [ready, total] if ready < total else _t("Entrée dans la partie") + dots
	loading_bar.value = minf(100, elapsed / 2.4 * 100) * float(ready) / maxf(1, total)
	_update_tip(elapsed)




func _build_film() -> void :
	film_layer = Control.new()
	film_layer.name = "Film"
	root.add_child(film_layer)
	film_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	film_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	for top: bool in [true, false]:
		var bar: ColorRect = ColorRect.new()
		film_layer.add_child(bar)
		bar.color = Color("07080c")
		bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		if top: bar.offset_bottom = 98
		else: bar.offset_top = -98
	film_chapter = _label("", "caps_wide", 16, T.TEAL)
	film_layer.add_child(film_chapter)
	film_chapter.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	film_chapter.offset_top = 35
	film_chapter.offset_bottom = 70
	film_chapter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	film_caption = _label("", "title", 25, T.PAPER)
	film_layer.add_child(film_caption)
	film_caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	film_caption.offset_top = -70
	film_caption.offset_bottom = -24
	film_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	film_black = ColorRect.new()
	film_layer.add_child(film_black)
	film_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	film_black.color = Color.BLACK
	film_layer.hide()

func show_film() -> void :
	hud.hide()
	overlay.hide()
	page.hide()
	qte_panel.hide()
	_toast_box.hide()
	film_layer.show()

func update_film(chapter: String, caption: String, black: float) -> void :
	film_chapter.hide()
	film_caption.hide()
	film_black.color.a = black

func hide_film() -> void :
	if not film_layer: return
	film_layer.hide()
	hud.show()
	overlay.show()
	_toast_box.show()




func mobile_safe_edges() -> Vector2:
	if not OS.has_feature("android"): return Vector2.ZERO
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var physical: Vector2 = Vector2(world.get_window().size)
	var logical: Vector2 = world.get_viewport().get_visible_rect().size
	if physical.x <= 0 or safe.size.x <= 0: return Vector2.ZERO
	return Vector2(maxf(0, safe.position.x), maxf(0, physical.x - safe.end.x)) * logical.x / physical.x

func apply_mobile_layout() -> void :
	if not world.mobile_mode: return
	var safe: Vector2 = mobile_safe_edges()
	_hud.apply_mobile_layout(safe)
	_toast_box.offset_top = 110
	_toast_box.offset_left = -270
	_toast_box.offset_right = 270
	for entry: Dictionary in _toasts:
		entry.label.add_theme_font_size_override("font_size", 15)
		_fit_toast(entry.label)
	if is_instance_valid(performance_label):
		performance_label.offset_left = -220 - safe.y
		performance_label.offset_right = -20 - safe.y
		performance_label.offset_top = 80
		performance_label.offset_bottom = 96
	if not root.resized.is_connected(apply_mobile_layout): root.resized.connect(apply_mobile_layout)

func mobile_back() -> void :
	match current_page:
		"connecting":
			world.leave_network()
			show_network()
		"characters", "alice", "maps":
			if world.networked: show_lobby()
			else: show_main()
		"advanced": show_network()
		"lobby": world.quit_to_menu()
		"main": toast("Utilise le bouton d’accueil du téléphone pour quitter.", 3)
		"settings": _settings_back()
		_: show_main()

func _touch_text(text: String) -> String:
	if not world or not world.mobile_mode: return text
	return text.replace("F2 ferme ce panneau.", "Utilise REPRENDRE en bas du panneau.").replace("F2", "ESSAIS").replace("MAINTENIR E", "MAINTENIR INTERAGIR").replace("Maintiens E", "Maintiens INTERAGIR").replace("maintiens E", "maintiens INTERAGIR").replace("TAB :", "SUIVRE :").replace("TAB pour", "SUIVRE pour").replace("E  ·", "INTERAGIR ·").replace("SUIVANT · changer", "SUIVRE · changer").replace("ESSAI · préparer", "ESSAIS · préparer")




func _process(delta: float) -> void :
	_update_backdrop()
	language_clock += delta
	var language: String = PaperLanguage.language
	var switched: bool = language != _language_seen


	if switched or (language == "en" and language_clock >= 0.25):
		language_clock = 0
		_language_seen = language
		var player_names: Array = [world.nickname]
		for record: Dictionary in world.roster.values(): player_names.append(str(record.get("name", "")))
		for actor: PaperActor in world.actors.values():
			if not actor.bot: player_names.append(actor.display_name)
		PaperLanguage.set_player_names(player_names)
		PaperLanguage.apply_tree(root)
		PaperLanguage.apply_world_labels(world)
		if switched: _hud.on_show()
	if not world or not world.mobile_mode or not page.visible or not is_instance_valid(active_menu_panel) or not active_menu_panel.is_inside_tree(): return
	var height: float = 0
	if OS.has_feature("android"):
		height = float(DisplayServer.virtual_keyboard_get_height()) * world.get_viewport().get_visible_rect().size.y / maxf(1, world.get_window().size.y)
	if absf(height - last_keyboard_height) < 1: return
	last_keyboard_height = height
	active_menu_panel.offset_bottom = - maxf(20, height + 12)
	call_deferred("_scroll_to_focused_field")

func _scroll_to_focused_field() -> void :
	if not is_instance_valid(active_menu_panel) or not active_menu_panel.is_inside_tree(): return
	var focus: Control = world.get_viewport().gui_get_focus_owner()
	var scroll: ScrollContainer = active_menu_panel.get_child(0) as ScrollContainer
	if focus and scroll and scroll.is_ancestor_of(focus): scroll.ensure_control_visible(focus)

func _input(event: InputEvent) -> void :
	if event is InputEventMouseMotion or event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventScreenDrag:
		T.touch_mode = event is InputEventScreenTouch or event is InputEventScreenDrag or (event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION)
		_set_pointer_mode(true)


		if event is InputEventMouseButton:
			if not event.pressed: _drop_button_focus.call_deferred()
		elif event is InputEventMouseMotion: _drop_button_focus()
	elif event is InputEventKey or event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		_set_pointer_mode(false)
		if event.is_pressed() and not event.is_echo(): _restore_focus(event)



func _set_pointer_mode(on: bool) -> void :
	if _pointer == on and T.pointer_mode == on: return
	_pointer = on
	T.pointer_mode = on
	var viewport: Viewport = get_viewport()
	if viewport == null: return
	for control: Control in [viewport.gui_get_focus_owner(), viewport.gui_get_hovered_control()]:
		if control == null: continue
		if control.has_method("refresh_highlight"): control.call("refresh_highlight")
		else: control.queue_redraw()



func _drop_button_focus() -> void :
	if not T.pointer_mode or Input.get_mouse_button_mask() != 0: return
	var viewport: Viewport = get_viewport()
	if viewport == null: return
	var focus: Control = viewport.gui_get_focus_owner()
	if focus == null or not (focus is BaseButton or focus is Range): return
	focus.release_focus()



func _restore_focus(event: InputEvent) -> void :
	if get_viewport().gui_get_focus_owner() != null: return
	var navigation: bool = false
	for action: StringName in [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_focus_next", &"ui_focus_prev"]:
		if event.is_action_pressed(action):
			navigation = true
			break
	if not navigation and not event.is_action_pressed(&"ui_accept"): return
	var target: Control = _focus_candidate()
	if target == null: return
	target.grab_focus()

	if navigation: get_viewport().set_input_as_handled()

func _focus_scope() -> Node:
	if not is_instance_valid(world): return null
	if world.controls_menu and world.controls_menu.visible: return world.controls_menu
	if world.online_menu and world.online_menu.visible: return world.online_menu
	if world.phase == "gallery" and world.gallery and not world.gallery.browsing: return null
	if is_instance_valid(overlay) and overlay.visible and overlay.get_child_count() > 0: return overlay
	if is_instance_valid(page) and page.visible and page.modulate.a > 0.5: return page
	return null

func _focus_candidate() -> Control:
	var scope: Node = _focus_scope()
	if scope == null: return null
	var last: Control = _last_focus.get_ref() as Control if _last_focus else null
	if is_instance_valid(last) and last.is_inside_tree() and last.is_visible_in_tree() and last.focus_mode != Control.FOCUS_NONE and scope.is_ancestor_of(last) and not (last is BaseButton and (last as BaseButton).disabled): return last
	# Sinon la cible principale de la page (carte choisie, premier onglet…).
	var preferred: Control = _page_focus.get_ref() as Control if _page_focus else null
	if is_instance_valid(preferred) and preferred.is_visible_in_tree() and preferred.focus_mode != Control.FOCUS_NONE and scope.is_ancestor_of(preferred): return preferred
	return _first_focusable(scope)

func _first_focusable(node: Node) -> Control:
	for child: Node in node.get_children():
		var control: Control = child as Control
		if control == null or not control.visible: continue
		if control is BaseButton and control.focus_mode != Control.FOCUS_NONE and not (control as BaseButton).disabled: return control
		var found: Control = _first_focusable(control)
		if found: return found
	return null

func _unhandled_input(event: InputEvent) -> void :

	if _settings_tab_input(event): return
	if not event.is_action_pressed("ui_cancel"): return
	if world.phase not in ["menu", "lobby"] or not page.visible: return
	if (world.online_menu and world.online_menu.visible) or (world.controls_menu and world.controls_menu.visible): return
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is LineEdit:
		focus.release_focus()
		get_viewport().set_input_as_handled()
		return
	match current_page:
		"main", "lobby": return
		"connecting":
			world.leave_network()
			show_network()
		"characters", "alice", "maps":
			if world.networked: show_lobby()
			else: show_main()
		"advanced": show_network()
		"settings": _settings_back()
		_: show_main()
	Sound.play("back")
	get_viewport().set_input_as_handled()

# Réglages : gâchettes hautes LB / RB (ou Page préc. / Page suiv.) pour
# changer d'onglet, comme les L / R des menus de Persona.
func _settings_tab_input(event: InputEvent) -> bool:
	if current_page != "settings" or not page.visible: return false
	if (world.online_menu and world.online_menu.visible) or (world.controls_menu and world.controls_menu.visible): return false
	var step: int = 0
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER: step = -1
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER: step = 1
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_PAGEUP: step = -1
		elif event.keycode == KEY_PAGEDOWN: step = 1
	if step == 0: return false
	var tabs: Array = SETTINGS_TABS
	_settings_switch(str(tabs[posmod(tabs.find(settings_tab) + step, tabs.size())]))
	get_viewport().set_input_as_handled()
	return true

func _on_focus_changed(control: Control) -> void :
	if control != null: _last_focus = weakref(control)

	if _pointer or control == null or not control.is_visible_in_tree(): return
	if control is W.NavItem or control is W.CharacterCard or control is W.MapCard or control is W.RoleTab or control is MenuBackdrop.Cutout: return
	if control is BaseButton or control is Range: Sound.play("hover")
