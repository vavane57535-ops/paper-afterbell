class_name PaperControlsMenu
extends Control


const T = preload("res://ui_theme.gd")
const W = preload("res://ui_widgets.gd")
const Sound = preload("res://ui_sound.gd")
const MenuFx = preload("res://ui_menu_fx.gd")

var world: Node
var list: VBoxContainer
var prompt: Label
var capture_action: String = ""
var capture_pad: bool = false
var choosing_pad: bool = false
var _capture_delay: float = 0.0

func setup(owner: Node) -> void :
	world = owner
	name = "ControlsMenu"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()

var _entering: bool = false
# Ouvert depuis le menu pause : « Enregistrer & retour » y ramène directement
# (le carnet reste affiché sous le volet jusqu'à ce que la pause revienne).
var from_pause: bool = false
var _leaving: bool = false

func open() -> void :
	from_pause = false
	_leaving = false
	world.ui.page.hide()
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_entering = true
	_build()
	_entering = false

func close() -> void :
	if _leaving: return
	capture_action = ""
	if from_pause and str(world.get("phase")) == "playing" and world.ui.has_method("_pause_reopen"):
		from_pause = false
		_leaving = true
		world.ui.call("_pause_reopen", "controls")
		# Filet de sécurité si le volet est interrompu (manche finie, retour au menu…).
		get_tree().create_timer(0.8).timeout.connect(func() -> void :
			if _leaving:
				_leaving = false
				hide())
		return
	hide()
	from_pause = false
	world.ui.show_settings()

func _build() -> void :
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var back: ColorRect = ColorRect.new()
	back.color = Color(0.03, 0.035, 0.055, 0.94)
	add_child(back)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var decor: MenuFx.Decor = MenuFx.Decor.new()
	decor.title = "COMMANDES"
	decor.accent = T.GOLD_DIM.lerp(T.RED_DEEP, 0.5)
	decor.reduced = bool(world.ui.reduced_motion)
	decor.ribbon_text = "MON CARNET DE COMMANDES"
	add_child(decor)
	if not _entering: decor.set("_enter", 1.0)
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBox = T.sheet_style(36, 28, T.RED_DEEP, 29)
	style.content_margin_left = 36
	style.content_margin_right = 30
	style.content_margin_top = 28
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0
	panel.anchor_bottom = 1
	var width: float = minf(1040.0, get_viewport_rect().size.x - 64.0)
	panel.offset_left = - width * 0.5
	panel.offset_right = width * 0.5
	panel.offset_top = 26
	panel.offset_bottom = -26
	var scroll: ScrollContainer = ScrollContainer.new()
	panel.add_child(scroll)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# La liste suit la sélection clavier / manette (activé après le focus initial, une fois mise en page).
	get_tree().create_timer(0.05).timeout.connect(scroll.set.bind("follow_focus", true))
	list = VBoxContainer.new()
	scroll.add_child(list)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	var kicker: Label = _text("RÉGLAGES · COMMANDES", 13, T.TEAL, "caps_wide")
	kicker.autowrap_mode = TextServer.AUTOWRAP_OFF
	var title: W.CollageTitle = W.CollageTitle.new()
	title.setup("Mon carnet de commandes", 40.0, T.RED, 900.0)
	list.add_child(title)
	_text("Clavier / souris et manettes · les réglages sont conservés sur cet appareil.", 16, T.MUTED)
	var selector: OptionButton = OptionButton.new()
	selector.add_item("Clavier & souris")
	selector.add_item("Manette · Xbox / PlayStation / Switch / Steam Deck")
	selector.select(1 if choosing_pad else 0)
	selector.custom_minimum_size.y = 46
	# Marge autour de la liste : sélectionnée au clavier ou à la manette, sa découpe rouge déborde
	# d'une quinzaine de pixels et recouvrait les lignes de texte voisines.
	var selector_box: MarginContainer = MarginContainer.new()
	selector_box.add_theme_constant_override("margin_top", 10)
	selector_box.add_theme_constant_override("margin_bottom", 14)
	list.add_child(selector_box)
	selector_box.add_child(selector)
	selector.item_selected.connect( func(index: int) -> void :
		choosing_pad = index == 1
		_build())
	var names: Array[String] = []
	for device: int in Input.get_connected_joypads(): names.append(Input.get_joy_name(device))
	_text("Manettes détectées : " + (", ".join(names) if not names.is_empty() else "aucune pour le moment"), 15, T.MUTED)
	prompt = _text("Choisis une commande à modifier. Échap annule la capture.", 17, T.GOLD)
	for action: String in PaperBindings.LABELS:
		var holder: W.MenuRow = W.MenuRow.new()
		list.add_child(holder)
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		holder.add_child(row)
		var label: Label = Label.new()
		label.text = PaperLanguage.t(str(PaperBindings.LABELS[action]))
		label.add_theme_color_override("font_color", T.PAPER_DIM)
		label.add_theme_font_override("font", T.font("medium"))
		label.add_theme_font_size_override("font_size", 17)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(label)
		var button: Button = Button.new()
		# Libellés de souris et de manette traduits (« Clic D », « Croix ↑ »…) ; les noms de touches restent tels quels.
		button.text = PaperLanguage.t(world.bindings.label(action, choosing_pad))
		button.custom_minimum_size = Vector2(330, 42)
		button.set_meta("language_user_text", true)
		row.add_child(button)
		button.pressed.connect( func() -> void :
			capture_action = action
			capture_pad = choosing_pad
			_capture_delay = Time.get_ticks_msec() + 220
			prompt.text = "Nouvelle touche : " + str(PaperBindings.LABELS[action]) + "…"
			button.text = "…"
			Sound.play("click")
			button.release_focus())
		button.mouse_entered.connect(_sfx.bind("hover"))
	_text("CAMÉRA À LA MANETTE", 13, T.TEAL, "caps_wide")
	_slider("Sensibilité", 0.5, 6, world.bindings.look_sensitivity, func(value: float) -> void :
		world.bindings.look_sensitivity = value
		world.bindings.save())
	_slider("Accélération du stick (demi-tour rapide)", 0.0, 1.0, world.camera_rig.pad_acceleration, func(value: float) -> void :
		world.camera_rig.pad_acceleration = value
		world.save_preferences())
	_slider("Zone morte des sticks", 0.05, 0.45, world.bindings.deadzone, _set_deadzone)
	var rumble: CheckButton = CheckButton.new()
	rumble.text = "Vibrations à l’impact"
	rumble.button_pressed = world.bindings.vibration
	list.add_child(rumble)
	rumble.toggled.connect( func(value: bool) -> void :
		world.bindings.vibration = value
		world.bindings.save())
	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	list.add_child(actions)
	if world.mobile_mode:
		_button(actions, "PLACER LES BOUTONS TACTILES", func() -> void :
			hide()
			world.mobile_controls.start_edit(), "TealButton")
	_button(actions, "RÉTABLIR LES COMMANDES", func() -> void :
		world.bindings.reset()
		_build(), "DangerButton")
	_button(actions, "ENREGISTRER & RETOUR", close, "PrimaryButton")
	if PaperLanguage.language == "en": PaperLanguage.apply_tree(self)
	selector.grab_focus()
	if _entering and is_instance_valid(world.ui.fx): world.ui.fx.cascade_children(list, 0.04, 0.018, Vector2(-60, 0), -0.05, 0.24)

func _sfx(kind: String) -> void :
	Sound.play(kind)

func _text(text: String, size: int, color: Color = T.PAPER, font_kind: String = "body") -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_override("font", T.font(font_kind))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(label)
	return label

func _set_deadzone(value: float) -> void :
	world.bindings.deadzone = value
	for action: String in PaperBindings.LABELS: InputMap.action_set_deadzone(action, value)
	world.bindings.save()

func _button(parent: Node, text: String, callback: Callable, variation: String = "") -> void :
	var button: Button = Button.new()
	button.text = text
	button.theme_type_variation = variation
	button.custom_minimum_size.y = 50
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	button.pressed.connect(callback)
	button.pressed.connect(_sfx.bind("confirm" if variation == "PrimaryButton" else "click"))

func _slider(title: String, low: float, high: float, value: float, callback: Callable) -> void :
	var holder: W.MenuRow = W.MenuRow.new()
	list.add_child(holder)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	holder.add_child(row)
	var label: Label = Label.new()
	label.text = title
	label.add_theme_color_override("font_color", T.PAPER_DIM)
	label.add_theme_font_size_override("font_size", 17)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.01
	slider.value = value
	slider.custom_minimum_size = Vector2(330, 32)
	row.add_child(slider)
	slider.value_changed.connect(callback)

func _input(event: InputEvent) -> void :
	if not visible or _leaving: return
	if capture_action.is_empty():
		# Échap / Start, ou B à la manette (ui_cancel, comme dans les autres menus).
		if event.is_action_pressed("pause_game") or (event is InputEventJoypadButton and event.is_action_pressed("ui_cancel")):
			close()
			get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	if Time.get_ticks_msec() < _capture_delay: return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		capture_action = ""
		_build()
		return
	var acceptable: bool = (event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.72) if capture_pad else (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed)
	if not acceptable: return
	world.bindings.rebind(capture_action, event, capture_pad)
	capture_action = ""
	_build()
	prompt.text = "Commande enregistrée."
