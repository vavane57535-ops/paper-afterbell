extends Node

# Textes 0.17 : une capture par écran (menus, partie, résultats) et un relevé
# des textes coupés ou qui sortent de leur cadre, en français ou en anglais.
#   XDG_DATA_HOME=<dossier de test> xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 \
#       -- --tool test_textes --tx-out DIR [--tx-en] [--tx-size 1920x1080] [--tx-screens main,hints,setup,...]
# Sans rendu (relevé seul) : godot --headless -- --tool test_textes [--tx-en]
# Écrans : main hints setup alice shop gallery credits network advanced connecting lobby
#          settings controls online loading game pause confirm emotes training alice_game verdicts
# Journal : « TX_SHOT <fichier> », « TX_CUT <écran> | <texte> | <détail> » pour chaque texte coupé
# ou hors de l'écran, puis « TX_RESULT cuts=<n> ».
# Traductions seules (sans rendu) : godot --headless -- --tool test_textes --tx-l10n <liste.json>
#   (tableau JSON de textes français) : « TX_L10N_MISSING <texte> » pour chaque texte sans anglais.
# Cinémathèque (sans rendu) : godot --headless -- --tool test_textes --tx-catalogue
#   (titres et descriptions de catalogue() en français et en anglais, « TX_CAT_RESULT »).
# Fiches des persos (sans rendu) : godot --headless -- --tool test_textes --tx-data (« TX_DATA_RESULT »).

const ALL: Array[String] = ["main", "hints", "setup", "alice", "shop", "gallery", "credits", "network", "advanced", "connecting", "lobby", "settings", "controls", "online", "loading", "game", "pause", "confirm", "emotes", "training", "alice_game", "verdicts"]

var world: Node
var out_dir: String = "user://textes"
var screens: Array[String] = []
var english: bool = false
var _clock: float = 0.0
var _cuts: int = 0
var _seen: Dictionary = {}
var _log: PackedStringArray = PackedStringArray()

func setup(game_world: Node) -> void :
	world = game_world
	screens = ALL.duplicate()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		if args[i] == "--tx-out" and i + 1 < args.size(): out_dir = args[i + 1]
		if args[i] == "--tx-en": english = true
		if args[i] == "--tx-screens" and i + 1 < args.size():
			screens.clear()
			for part: String in args[i + 1].split(","): screens.append(part.strip_edges())
		if args[i] == "--tx-size" and i + 1 < args.size():
			var parts: PackedStringArray = args[i + 1].split("x")
			if parts.size() == 2: get_window().size = Vector2i(int(parts[0]), int(parts[1]))
	DirAccess.make_dir_recursive_absolute(out_dir)
	# Langue changée en mémoire seulement (rien n'est écrit dans settings.cfg).
	if english: PaperLanguage.language = "en"
	_run.call_deferred()

func _process(delta: float) -> void :
	_clock += delta

func _note(text: String) -> void :
	print(text)
	_log.append(text)

func _wait(seconds: float) -> void :
	var start: float = _clock
	while _clock - start < seconds: await get_tree().process_frame

func _until(condition: Callable, timeout: float) -> bool:
	var start: float = _clock
	while not bool(condition.call()):
		if _clock - start > timeout: return false
		await get_tree().process_frame
	return true

func _mouse_away() -> void :
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = Vector2(4, 4)
	motion.global_position = Vector2(4, 4)
	Input.warp_mouse(Vector2(4, 4))
	Input.parse_input_event(motion)
	await get_tree().process_frame

func _shot(tag: String) -> void :
	await get_tree().process_frame
	_scan(tag)
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var path: String = out_dir.path_join(tag + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	_note("TX_SHOT " + path)

# --- Relevé des textes coupés --------------------------------------------

func _cut(screen: String, text: String, detail: String) -> void :
	var key: String = screen + "|" + text + "|" + detail
	if _seen.has(key): return
	_seen[key] = true
	_cuts += 1
	_note("TX_CUT %s | %s | %s" % [screen, text.replace("\n", "⏎"), detail])

func _visible(control: Control) -> bool:
	if not control.is_visible_in_tree(): return false
	var node: Node = control
	while node:
		if node is CanvasItem and (node as CanvasItem).modulate.a < 0.05: return false
		if node is CanvasLayer and not (node as CanvasLayer).visible: return false
		node = node.get_parent()
	return true

func _clip_parent(control: Control) -> Control:
	var node: Node = control.get_parent()
	while node:
		if node is ScrollContainer: return node as Control
		node = node.get_parent()
	return null

func _width(font: Font, text: String, size: int) -> float:
	var widest: float = 0.0
	for line: String in text.split("\n"): widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	return widest

func _lines(font: Font, text: String, size: int, width: float) -> int:
	var paragraph: TextParagraph = TextParagraph.new()
	paragraph.add_string(text, font, size)
	paragraph.width = width
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	return paragraph.get_line_count()

func _scan(screen: String) -> void :
	var view: Rect2 = get_viewport().get_visible_rect()
	for root: Node in [get_tree().root]:
		for node: Node in root.find_children("*", "Control", true, false):
			var control: Control = node as Control
			if not _visible(control): continue
			_scan_control(screen, control, view)

func _scan_control(screen: String, control: Control, view: Rect2) -> void :
	var text: String = ""
	if control is Label: text = (control as Label).text
	elif control is Button: text = (control as Button).text
	var rect: Rect2 = control.get_global_rect()
	if control is Label and not text.strip_edges().is_empty():
		var label: Label = control as Label
		var font: Font = label.get_theme_font("font")
		var size: int = label.get_theme_font_size("font_size")
		if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
			var wide: float = _width(font, text, size)
			if (label.clip_text or label.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING) and wide > label.size.x + 1.0:
				_cut(screen, text, "coupé : %d px pour %d px" % [int(wide), int(label.size.x)])
		elif label.get_visible_line_count() < label.get_line_count() and label.max_lines_visible != 0:
			_cut(screen, text, "lignes cachées : %d sur %d" % [label.get_visible_line_count(), label.get_line_count()])
	if control is Button and not text.strip_edges().is_empty() and not control.get_script():
		var button: Button = control as Button
		if button.clip_text or button.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
			var font: Font = button.get_theme_font("font")
			var size: int = button.get_theme_font_size("font_size")
			var wide: float = _width(font, text, size)
			var style: StyleBox = button.get_theme_stylebox("normal")
			var room: float = button.size.x - (style.get_margin(SIDE_LEFT) + style.get_margin(SIDE_RIGHT) if style else 0.0)
			if wide > room + 1.0: _cut(screen, text, "bouton coupé : %d px pour %d px" % [int(wide), int(room)])
	# Cartes et onglets dessinés à la main (draw_string tronque sans prévenir).
	var script: Script = control.get_script() as Script
	if script:
		var T: Variant = preload("res://ui_theme.gd")
		if "role_title" in control and "person" in control and str(control.get("role_title")) != "":
			var shown: String = T.tr_text(str(control.get("role_title")))
			var wide: float = T.font("caps").get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			if wide > control.size.x - 24.0: _cut(screen, shown, "rôle de la carte coupé : %d px pour %d px" % [int(wide), int(control.size.x - 24.0)])
		if "subtitle" in control and "icon_tex" in control and str(control.get("subtitle")) != "":
			var shown: String = T.tr_text(str(control.get("subtitle")))
			var x: float = 62.0 if control.get("icon_tex") else 18.0
			var wide: float = T.font("caps").get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			if wide > control.size.x - x - 10.0: _cut(screen, shown, "onglet coupé : %d px pour %d px" % [int(wide), int(control.size.x - x - 10.0)])
			var title: String = str((control as Button).text)
			var title_wide: float = T.font("title").get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			if title_wide > control.size.x - x - 10.0: _cut(screen, title, "titre d'onglet coupé")
		if "map_id" in control and "line" in control:
			var size_px: Vector2 = control.size
			var shown_title: String = T.tr_text(str(control.get("title")))
			var title_size: int = 16 if size_px.x > 240 else 14
			var title_lines: int = _lines(T.font("title"), shown_title, title_size, size_px.x - 24)
			if title_lines > 2: _cut(screen, shown_title, "titre de carte sur %d lignes (2 max)" % title_lines)
			var lines: int = 1 if T.font("title").get_string_size(shown_title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x <= size_px.x - 24 else 2
			var body_lines: int = 3 if size_px.x > 240 else (2 if lines == 1 else 0)
			if size_px.y < 130: body_lines = 0
			var shown_line: String = T.tr_text(str(control.get("line")))
			if body_lines > 0:
				var needed: int = _lines(T.font("body"), shown_line, 12 if size_px.x <= 240 else 14, size_px.x - 24)
				if needed > body_lines: _cut(screen, shown_line, "texte de carte sur %d lignes (%d max)" % [needed, body_lines])
	# Hors de l'écran (ou hors de la zone qui défile, à l'horizontale).
	if text.strip_edges().is_empty() or control.get_global_transform().get_rotation() != 0.0 and absf(control.get_global_transform().get_rotation()) > 0.2: return
	if rect.size.x <= 1.0: return
	var limit: Rect2 = view
	var holder: Control = _clip_parent(control)
	if holder:
		var area: Rect2 = holder.get_global_rect()
		if rect.position.x < area.position.x - 8.0 or rect.end.x > area.end.x + 8.0:
			_cut(screen, text, "dépasse la zone qui défile de %d px" % int(maxf(area.position.x - rect.position.x, rect.end.x - area.end.x)))
		return
	if rect.end.x > limit.end.x + 2.0 or rect.position.x < limit.position.x - 2.0 or rect.end.y > limit.end.y + 2.0 or rect.position.y < limit.position.y - 2.0:
		_cut(screen, text, "hors écran : %s dans %s" % [rect, limit.size])

# --- Écrans --------------------------------------------------------------

func _menu(tag: String, action: Callable, settle: float = 1.3) -> void :
	action.call()
	await _wait(settle)
	await _mouse_away()
	await _shot(tag)

func _start_round(killer: bool) -> bool:
	if world.phase == "playing" and bool(world.solo_killer) == killer: return true
	if world.phase != "menu":
		world.quit_to_menu()
		await _wait(0.8)
	world.selected = "Simon"
	world.start_solo(killer)
	var loading_seen: bool = false
	if "loading" in screens:
		await _wait(0.5)
		if world.ui.current_page != "" or world.phase != "playing":
			await _shot("loading_" + ("alice" if killer else "simon"))
			loading_seen = true
	var ok: bool = await _until(func() -> bool: return world.phase == "playing", 90.0)
	_note("TX partie %s : %s (chargement capturé : %s)" % ["Alice" if killer else "Simon", world.phase, loading_seen])
	await _wait(2.5)
	return ok

func _key(code: Key, settle: float = 0.3) -> void :
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
	await _wait(settle)

# --tx-l10n FICHIER.json : liste de textes français (tableau JSON) dont la traduction anglaise doit exister.
# Imprime « TX_L10N_MISSING <texte> » pour chaque texte rendu tel quel, puis « TX_L10N_RESULT ».
func _check_l10n(path: String) -> void :
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var missing: int = 0
	var previous: String = PaperLanguage.language
	PaperLanguage.language = "en"
	for value: Variant in (data if data is Array else []):
		var source: String = str(value)
		var shown: String = PaperLanguage.t(source)
		if shown == source:
			missing += 1
			_note("TX_L10N_MISSING " + source)
		else: _note("TX_L10N_OK " + source + " -> " + shown)
	PaperLanguage.language = previous
	_note("TX_L10N_RESULT %s" % ("OK" if missing == 0 else "MISSING %d" % missing))

# --tx-data : fiches des persos (rôle, réplique, capacités, passif tel que l'affiche la préparation).
# « TX_DATA_MISSING » pour un texte resté en français, puis « TX_DATA_RESULT ».
func _check_data() -> void :
	var missing: int = 0
	var previous: String = PaperLanguage.language
	var sources: Array[String] = []
	for person: String in PaperData.STATS.keys():
		sources.append(str(PaperData.STATS[person][3]))
		sources.append(str(PaperData.STATS[person][4]))
		sources.append(PaperData.passive_for(person, "om"))
		for ability: Array in PaperData.abilities_for(person, "om"):
			if str(ability[2]) != "": sources.append(str(ability[2]))
	PaperLanguage.language = "en"
	for source: String in sources:
		var shown: String = PaperLanguage.t(source)
		_note("TX_DATA %s -> %s" % [source, shown])
		if shown == source:
			missing += 1
			_note("TX_DATA_MISSING " + source)
	PaperLanguage.language = previous
	_note("TX_DATA_RESULT %s" % ("OK" if missing == 0 else "MISSING %d" % missing))

# --tx-catalogue : titres et descriptions de toute la cinémathèque (63 fuites en équipe comprises).
# Imprime « TX_CAT_FR » / « TX_CAT_EN » pour chaque entrée, « TX_CAT_MISSING » pour un texte resté en
# français (un titre fait seulement de prénoms, comme « Simon + Elly », n'a pas à changer), puis « TX_CAT_RESULT ».
func _check_catalogue() -> void :
	var missing: int = 0
	var previous: String = PaperLanguage.language
	for entry: Dictionary in PaperCinema.catalogue():
		var title: String = str(entry.title)
		var description: String = str(entry.description)
		PaperLanguage.language = "en"
		var title_en: String = PaperLanguage.t(title)
		var description_en: String = PaperLanguage.t(description)
		PaperLanguage.language = previous
		_note("TX_CAT_FR %s | %s | %s" % [entry.id, title, description])
		_note("TX_CAT_EN %s | %s | %s" % [entry.id, title_en, description_en])
		var names_only: bool = title.replace(" + ", "").replace(" ", "").is_valid_identifier()
		if title_en == title and not names_only and title != "Prologue — Yiero":
			missing += 1
			_note("TX_CAT_MISSING titre " + title)
		if description_en == description and not description.is_empty():
			missing += 1
			_note("TX_CAT_MISSING description " + description)
	_note("TX_CAT_RESULT %s" % ("OK" if missing == 0 else "MISSING %d" % missing))

func _run() -> void :
	await _wait(0.5)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--tx-catalogue") or args.has("--tx-data"):
		if args.has("--tx-catalogue"): _check_catalogue()
		if args.has("--tx-data"): _check_data()
		get_tree().quit()
		return
	var l10n_at: int = args.find("--tx-l10n")
	if l10n_at >= 0 and l10n_at + 1 < args.size():
		_check_l10n(args[l10n_at + 1])
		get_tree().quit()
		return
	var ui: Node = world.ui
	_note("TX viewport %s langue %s" % [get_viewport().get_visible_rect().size, PaperLanguage.language])
	if "main" in screens: await _menu("main", func() -> void : ui.show_main(), 2.0)
	if "hints" in screens:
		ui.show_main()
		await _wait(1.6)
		var items: Array = ui.page.find_children("*", "Button", true, false).filter(func(n: Node) -> bool: return "hint" in n and not str(n.get("hint")).is_empty())
		for item: Variant in items:
			var nav: Control = item as Control
			nav.grab_focus()
			ui._on_nav_hint(str(nav.get("hint")))
			await _wait(0.5)
			await _shot("hint_" + str(nav.get("text")).to_lower().replace(" ", "_").replace("’", "").replace("é", "e").replace("è", "e"))
		# Survol d'un perso dans la vitrine (ligne « RÔLE — Clique pour… »).
		if ui.has_method("_on_lineup_hovered"):
			ui._on_lineup_hovered("Usayuko")
			await _wait(0.3)
			await _shot("hint_lineup_usayuko")
	if "setup" in screens:
		for i: int in range(6):
			await _menu("setup_" + str(PaperData.NAMES[i]).to_lower(), func() -> void : ui._show_setup("survivor", i), 1.2)
	if "alice" in screens: await _menu("setup_alice", func() -> void : ui._show_setup("alice", -1), 1.3)
	if "shop" in screens:
		await _menu("shop", func() -> void : ui.show_shop(), 1.5)
		var scroll: ScrollContainer = ui.page.find_children("*", "ScrollContainer", true, false).front() if not ui.page.find_children("*", "ScrollContainer", true, false).is_empty() else null
		if scroll:
			for step: int in range(1, 4):
				scroll.scroll_vertical = step * 520
				await _wait(0.3)
				await _shot("shop_%d" % step)
	if "gallery" in screens:
		world.gallery.open()
		await _wait(1.6)
		await _mouse_away()
		await _shot("gallery")
		for category: String in ["intro", "lms_win", "lms_loss", "team", "fins"]:
			world.gallery.category = category
			ui.show_gallery()
			await _wait(0.8)
			await _mouse_away()
			await _shot("gallery_" + category)
		world.gallery.category = "all"
		world.gallery.close()
		await _wait(0.6)
	if "credits" in screens:
		await _menu("credits", func() -> void : ui.show_credits(), 1.5)
		# Toute la liste, page par page (la zone défile).
		var credits_scroll: ScrollContainer = ui.page.find_children("*", "ScrollContainer", true, false).front() if not ui.page.find_children("*", "ScrollContainer", true, false).is_empty() else null
		if credits_scroll:
			var page_height: int = maxi(200, int(credits_scroll.size.y) - 60)
			for step: int in range(1, 8):
				if step * page_height > int(credits_scroll.get_v_scroll_bar().max_value) + page_height: break
				credits_scroll.scroll_vertical = step * page_height
				await _wait(0.3)
				await _shot("credits_%d" % step)
	if "network" in screens: await _menu("network", func() -> void : ui.show_network(), 1.3)
	if "advanced" in screens: await _menu("advanced", func() -> void : ui.show_network_advanced(), 1.3)
	if "connecting" in screens:
		await _menu("connecting", func() -> void : ui.show_connecting(), 1.0)
		ui.show_main()
		await _wait(0.6)
	if "lobby" in screens:
		world.host_lan_room()
		await _wait(0.4)
		await _menu("lobby", func() -> void : ui.show_lobby(), 1.5)
		world.set_room_option("mode", "training")
		await _wait(0.3)
		await _menu("lobby_training", func() -> void : ui.show_lobby(), 1.2)
		world.set_room_option("mode", "match")
		world.quit_to_menu()
		await _wait(0.8)
	if "settings" in screens:
		for tab: String in ["game", "display", "audio", "controls", "access"]:
			ui.settings_tab = tab
			await _menu("settings_" + tab, func() -> void : ui.show_settings(), 1.2)
		ui.settings_tab = "game"
		ui.show_main()
		await _wait(0.6)
	if "controls" in screens:
		world.controls_menu.open()
		await _wait(1.2)
		await _mouse_away()
		await _shot("controls")
		world.controls_menu.close()
		await _wait(0.6)
	if "online" in screens:
		world.online_menu.open()
		await _wait(1.2)
		await _mouse_away()
		await _shot("online")
		world.online_menu.close()
		await _wait(0.6)
	var playing: bool = false
	for need: String in ["loading", "game", "pause", "confirm", "emotes"]:
		if need in screens: playing = true
	if playing and await _start_round(false):
		if "game" in screens:
			await _shot("game_hud")
			# Un message de partie et un toast, pour juger la taille des bandeaux.
			world.ui.toast(world.ui._t("Pas assez de tickets : joue une manche pour en gagner."), 6)
			await _wait(0.4)
			await _shot("game_toast")
		if "emotes" in screens:
			world.emote_wheel.open()
			await _wait(0.8)
			await _shot("emotes")
			await _key(KEY_TAB, 0.6)
			await _shot("emotes_dances")
			world.emote_wheel.close()
			await _wait(0.5)
		if "pause" in screens or "confirm" in screens:
			await _key(KEY_ESCAPE, 1.0)
			await _mouse_away()
			await _shot("pause")
			if "confirm" in screens:
				await _key(KEY_UP, 0.2)
				await _key(KEY_ENTER, 0.9)
				await _shot("pause_confirm")
				await _key(KEY_ESCAPE, 0.6)
			await _key(KEY_ESCAPE, 0.8)
	if "alice_game" in screens and await _start_round(true):
		await _shot("game_alice_hud")
	if "training" in screens:
		if world.phase != "menu":
			world.quit_to_menu()
			await _wait(0.8)
		world.start_training()
		if await _until(func() -> bool: return world.phase == "playing", 90.0):
			await _wait(2.5)
			await _shot("training_hud")
			await _key(KEY_F2, 1.2)
			await _mouse_away()
			await _shot("training_panel")
			await _key(KEY_F2, 0.8)
	if "verdicts" in screens:
		if world.phase != "menu":
			world.quit_to_menu()
			await _wait(0.8)
		for spec: Array in [["survivors", false, "ending_survivors", "victoire"], ["killer", true, "ending_killer", "defaite_lms"], ["survivors", false, PaperAliceForfeit.KIND, "forfait"]]:
			var rows: Array = []
			var people: Array = ["Simon", "Lysia", "Ashura", "Elly", "Bleuette", "Usayuko"]
			for i: int in range(people.size()):
				rows.append({"id": i + 2, "character": people[i], "name": people[i] + (" · Toi" if i == 0 else " · IA"), "points": [412, 355, 280, 211, 160, 90][i], "grade": ["A", "B", "B", "C", "C", "D"][i], "aura": 40 + i * 9, "breakdown": {"heal": 30 + i * 4, "stun": 2 + i, "danger": 12}})
			world.match_results = rows
			world.ending_kind = str(spec[2])
			world.ui.show_ending(str(spec[0]), bool(spec[1]))
			await _wait(2.0)
			await _mouse_away()
			await _shot("verdict_" + str(spec[3]))
	_note("TX_RESULT cuts=%d" % _cuts)
	var file: FileAccess = FileAccess.open(out_dir.path_join("log.txt"), FileAccess.WRITE)
	if file: file.store_string("\n".join(_log))
	get_tree().quit()
