class_name PaperSurvivorRoster
extends VBoxContainer




const T = preload("res://ui_theme.gd")
const W = preload("res://ui_widgets.gd")

var world: Node
var rows: Dictionary = {}
var row_width: float = 252.0
var row_height: float = 40.0

func setup(owner: Node) -> void :
	world = owner
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 4)
	row_width = 214.0 if world.mobile_mode else 252.0
	row_height = 34.0 if world.mobile_mode else 40.0
	custom_minimum_size = Vector2(row_width, 0)

func _t(text: String) -> String:
	return PaperLanguage.t(text) if PaperLanguage.language == "en" else text

func _label(text: String, font_kind: String, size: int, color: Color) -> Label:
	var result: Label = Label.new()
	result.text = text
	result.add_theme_font_override("font", T.font(font_kind))
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

func _row(actor: PaperActor) -> Dictionary:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(row_width, row_height)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = T.box(Color(0.04, 0.05, 0.075, 0.8), T.GREEN, 0, 5, 5, 3)
	style.border_width_left = 3
	style.content_margin_right = 10
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var horizontal: HBoxContainer = HBoxContainer.new()
	horizontal.add_theme_constant_override("separation", 8)
	horizontal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(horizontal)
	var icon: PaperStatusIcon = PaperStatusIcon.new()
	icon.setup(actor.character)
	icon.compact = true
	icon.custom_minimum_size = Vector2(row_height - 6, row_height - 6)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	horizontal.add_child(icon)
	var detail: VBoxContainer = VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 1)
	detail.alignment = BoxContainer.ALIGNMENT_CENTER
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal.add_child(detail)
	var heading: HBoxContainer = HBoxContainer.new()
	heading.add_theme_constant_override("separation", 6)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.add_child(heading)
	var name_label: Label = _label(actor.character, "semibold", 13 if world.mobile_mode else 15, T.PAPER)
	name_label.clip_text = true
	name_label.custom_minimum_size.x = 60
	heading.add_child(name_label)
	var you: Label = _label(_t("TOI"), "caps", 10, T.GOLD)
	you.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(you)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(spacer)
	var hp: Label = _label("", "num", 12 if world.mobile_mode else 13, T.PAPER_DIM)
	heading.add_child(hp)
	var bar: W.Meter = W.Meter.new()
	bar.custom_minimum_size = Vector2(0, 3)
	bar.radius = 1.5
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_child(bar)
	var status: Label = _label("", "caps", 9 if world.mobile_mode else 10, T.PAPER_DIM)
	detail.add_child(status)
	return {"panel": panel, "style": style, "icon": icon, "hp": hp, "bar": bar, "status": status, "name": name_label, "you": you, "character": actor.character, "state": ""}

func _write(label: Label, text: String) -> void :
	if label.text != text: label.text = text

func refresh() -> void :
	var ids: Array = []
	for person: String in PaperData.NAMES:
		for actor: PaperActor in world.actors.values():
			if actor.killer or actor.character != person or (world.training and world.practice.is_dummy(actor)): continue
			ids.append(actor.id)
			if rows.has(actor.id) and str(rows[actor.id].character) != person:
				rows[actor.id].panel.queue_free()
				rows.erase(actor.id)
			if not rows.has(actor.id): rows[actor.id] = _row(actor)
			var row: Dictionary = rows[actor.id]
			var life: String = actor.life_state() if actor.has_method("life_state") else "alive" if actor.alive else "dead"
			if bool(actor.effects.get("escaped", false)): life = "escaped"
			var chased: bool = float(actor.effects.get("chased", 0)) > 0 and actor.active()
			row.icon.update_state(life, chased)
			row.you.visible = actor.id == world.local_id()
			var dead: bool = life == "dead"
			var down: bool = life == "downed"
			_write(row.hp, "" if dead or life == "escaped" else "%d" % maxi(0, int(ceil(actor.hp))))
			row.bar.set_value(0.0 if down or dead else clampf(actor.hp / maxf(1, actor.max_hp), 0, 1))
			row.bar.set_color(PaperStatusIcon.COLORS.get(life, PaperStatusIcon.COLORS.alive))
			var state: String = "DERNIÈRE VIE" if life == "second_life" else "ARMURE · SANS RELEVAGE" if person == "Lysia" else "1 RELEVAGE"
			var tone: Color = Color(T.PAPER, 0.55)
			if life == "second_life": tone = Color("aab6f2")
			if chased:
				state = "POURSUIVI"
				tone = Color("ef8a99")
			if down:
				state = _t("À TERRE · %d s") % int(ceil(float(actor.effects.get("bleedout", 30))))
				var progress: float = float(actor.effects.get("revive_progress", 0))
				if progress > 0: state += " · %d %%" % int(progress * 100)
				tone = T.AMBER
			if dead:
				state = "ÉLIMINÉ"
				tone = Color(T.PAPER, 0.4)
			if life == "escaped":
				state = "ÉVADÉ"
				tone = Color("a9dcc8")
			_write(row.status, state if down else _t(state))
			if row.status.get_theme_color("font_color") != tone: row.status.add_theme_color_override("font_color", tone)
			var accent: Color = Color("ef7282") if chased else PaperStatusIcon.COLORS.get(life, PaperStatusIcon.COLORS.alive)
			if row.style.border_color != accent: row.style.border_color = accent
			var faded: float = 0.55 if dead else 1.0
			if row.panel.modulate.a != faded: row.panel.modulate.a = faded
	for id: Variant in rows.keys():
		if not ids.has(id):
			rows[id].panel.queue_free()
			rows.erase(id)
	visible = not ids.is_empty()
