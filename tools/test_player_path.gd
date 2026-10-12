extends Node

# Parcours complet du joueur (0.16) avec de vrais événements clavier, souris et
# manette, et une capture rendue à chaque écran.
#   XDG_DATA_HOME=<dossier vierge> xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 \
#       -- --tool test_player_path --first-launch --pp-out DIR \
#       [--pp-steps first,main,setup,settings,friends,shop,gallery,pause,results,verdicts] \
#       [--pp-size 1920x1080] [--pp-en] [--pp-skip escape|enter|click]
# Sans rendu (vérifications seules, pas de captures) : godot --headless -- --tool test_player_path ...
# Étapes :
#   first     premier lancement : le prologue démarre seul, on le passe en maintenant
#             Échap (ou Entrée / clic), on vérifie qu'on arrive au menu sans rien activer.
#   main      menu principal au clavier, puis survol souris de chaque entrée (scènes de survol).
#   setup     JOUER (Entrée), grille des élèves au clavier, onglet ALICE à la manette, retour B.
#   settings  Réglages par la souris : onglets Jeu, Audio, Commandes (RB), carnet de commandes.
#   friends   Entre amis, connexion directe, salon (sans serveur) avec « Qui joue Alice ? » et badge.
#   shop      Boutique : nouveautés TikTok, classiques, aperçu d'une danse.
#   gallery   Cinémathèque : liste, catégories, lecture d'un film de chaque catégorie.
#   pause     Partie solo lancée depuis la préparation, menu pause et ses sous-menus.
#   results   Fins réelles : victoire, défaite, forfait (blocus) puis écran de résultats.
#   verdicts  Les trois écrans de résultats seuls (résultats factices), pour juger la mise en page.
# Journal : lignes « PATH » (étapes, focus) et « PATH_CHECK OK|FAIL » ; DIR/log.txt.
# Le dossier XDG_DATA_HOME doit être vierge et dédié : l'outil écrit user://settings.cfg.

var world: Node
var out_dir: String = "user://player_path"
var steps: PackedStringArray = PackedStringArray(["first", "main", "setup", "settings", "friends", "shop", "gallery", "pause", "results"])
var skip_with: String = "escape"
var english: bool = false
var _clock: float = 0.0
var _shot_index: int = 0
var _log: PackedStringArray = PackedStringArray()
var _fails: int = 0

func setup(game_world: Node) -> void :
	world = game_world
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		if args[i] == "--pp-out" and i + 1 < args.size(): out_dir = args[i + 1]
		if args[i] == "--pp-steps" and i + 1 < args.size(): steps = args[i + 1].split(",")
		if args[i] == "--pp-skip" and i + 1 < args.size(): skip_with = args[i + 1]
		if args[i] == "--pp-en": english = true
		if args[i] == "--pp-size" and i + 1 < args.size():
			var parts: PackedStringArray = args[i + 1].split("x")
			if parts.size() == 2: get_window().size = Vector2i(int(parts[0]), int(parts[1]))
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _process(delta: float) -> void :
	_clock += delta

# --- Outils ---------------------------------------------------------------

func _note(text: String) -> void :
	print("PATH ", text)
	_log.append(text)

func _check(ok: bool, what: String) -> void :
	var line: String = ("OK   " if ok else "FAIL ") + what
	print("PATH_CHECK ", line)
	_log.append("CHECK " + line)
	if not ok: _fails += 1

func _wait(seconds: float) -> void :
	var start: float = _clock
	while _clock - start < seconds: await get_tree().process_frame

func _until(condition: Callable, timeout: float) -> bool:
	var start: float = _clock
	while not bool(condition.call()):
		if _clock - start > timeout: return false
		await get_tree().process_frame
	return true

func _shot(tag: String) -> void :
	await get_tree().process_frame
	_shot_index += 1
	if DisplayServer.get_name() == "headless":
		_note("capture (sans rendu) %02d_%s" % [_shot_index, tag])
		return
	await RenderingServer.frame_post_draw
	var path: String = out_dir.path_join("%02d_%s.png" % [_shot_index, tag])
	get_viewport().get_texture().get_image().save_png(path)
	_note("capture " + path)

func _tr(text: String) -> String:
	return PaperLanguage.t(text) if english else text

func _key_event(code: Key, pressed: bool, echo: bool = false) -> void :
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)

func _tap(code: Key, settle: float = 0.12) -> void :
	_key_event(code, true)
	await get_tree().process_frame
	_key_event(code, false)
	await _wait(settle)

func _pad(button: JoyButton, settle: float = 0.12) -> void :
	for pressed: bool in [true, false]:
		var event: InputEventJoypadButton = InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		event.device = 0
		Input.parse_input_event(event)
		await get_tree().process_frame
	await _wait(settle)

# Position fenêtre du centre d'un contrôle (les événements souris injectés
# passent par l'étirement « canvas_items »).
func _window_point(control: Control) -> Vector2:
	return get_tree().root.get_final_transform() * control.get_global_rect().get_center()

func _mouse_to(point: Vector2) -> void :
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.warp_mouse(point)
	Input.parse_input_event(motion)
	await get_tree().process_frame

func _hover(control: Control, settle: float = 0.3) -> void :
	if control == null: return
	await _mouse_to(_window_point(control))
	await _wait(settle)

func _click(control: Control, settle: float = 0.3) -> void :
	if control == null:
		_check(false, "clic sur un contrôle introuvable")
		return
	# Comme un joueur à la molette : la page défile jusqu'au bouton visé.
	var holder: ScrollContainer = _scroll_parent(control)
	if holder:
		holder.ensure_control_visible(control)
		await get_tree().process_frame
		await get_tree().process_frame
	var point: Vector2 = _window_point(control)
	await _mouse_to(point)
	var hovered: Control = get_viewport().gui_get_hovered_control()
	if hovered != control and not control.is_ancestor_of(hovered):
		_note("clic « %s » : la souris survole %s" % [str(control.get("text")), (hovered.get_class() + ":" + str(hovered.get("text")) + " @" + str(hovered.get_path())) if hovered else "<rien>"])
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		Input.parse_input_event(event)
		await get_tree().process_frame
	await _wait(settle)

func _find(text: String, from: Node = null, prefix: bool = false) -> Control:
	var wanted: String = _tr(text).strip_edges()
	var start: Node = from if from else get_tree().root
	return _find_in(start, wanted, text.strip_edges(), prefix)

func _find_in(node: Node, wanted: String, source: String, prefix: bool) -> Control:
	for child: Node in node.get_children():
		var control: Control = child as Control
		if control and control.is_visible_in_tree() and "text" in control:
			var value: String = str(control.get("text")).strip_edges()
			if value == wanted or value == source or (prefix and (value.begins_with(wanted) or value.begins_with(source))): return control
		var found: Control = _find_in(child, wanted, source, prefix)
		if found: return found
	return null

func _focus() -> String:
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus == null: return "<aucun>"
	var label: String = str(focus.get("text")) if "text" in focus else ""
	if label.is_empty() and "person" in focus: label = str(focus.get("person"))
	return focus.get_class() + ":" + label

func _state() -> String:
	return "phase=%s page=%s focus=%s" % [world.phase, world.ui.current_page, _focus()]

func _wait_phase(goal: String, timeout: float) -> bool:
	return await _until(func() -> bool: return world.phase == goal, timeout)

# --- Parcours -------------------------------------------------------------

func _run() -> void :
	await get_tree().process_frame
	if english:
		world.options["language"] = "en"
		world.apply_options()
	_note("fenêtre %s · visible %s · langue %s" % [get_window().size, get_viewport().get_visible_rect().size, PaperLanguage.language])
	for step: String in steps:
		_note("=== étape " + step)
		match step:
			"first": await _step_first()
			"main": await _step_main()
			"setup": await _step_setup()
			"settings": await _step_settings()
			"friends": await _step_friends()
			"shop": await _step_shop()
			"gallery": await _step_gallery()
			"pause": await _step_pause()
			"results": await _step_results()
			"verdicts": await _step_verdicts()
	_note("fin · %d échec(s)" % _fails)
	var file: FileAccess = FileAccess.open(out_dir.path_join("log.txt"), FileAccess.WRITE)
	if file: file.store_string("\n".join(_log))
	get_tree().quit()

func _step_first() -> void :
	var prologue_on: bool = await _wait_phase("prologue", 3.0)
	var first_launch: bool = "--first-launch" in OS.get_cmdline_user_args()
	_check(prologue_on == first_launch, "prologue au lancement : %s (premier lancement : %s)" % [prologue_on, first_launch])
	if not prologue_on:
		await _wait(1.0)
		await _shot("lancement_menu")
		return
	await _until(func() -> bool: return float(world.prologue.clock) >= 3.0, 30.0)
	await _shot("prologue_3s")
	await _until(func() -> bool: return float(world.prologue.clock) >= 9.5, 30.0)
	await _shot("prologue_9s")
	var cfg: ConfigFile = ConfigFile.new()
	_check(cfg.load("user://settings.cfg") == OK and bool(cfg.get_value("story", "intro_seen", false)), "drapeau [story] intro_seen écrit dès le début du film")
	# Maintenir la touche choisie pour passer, avec les répétitions du clavier.
	var code: Key = KEY_ESCAPE if skip_with == "escape" else KEY_ENTER
	var started: float = _clock
	var shot_gauge: bool = false
	if skip_with == "click":
		var centre: Vector2 = Vector2(get_window().size) * 0.5
		await _mouse_to(centre)
		var press: InputEventMouseButton = InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = centre
		press.global_position = centre
		Input.parse_input_event(press)
	else: _key_event(code, true)
	while world.phase == "prologue" and _clock - started < 6.0:
		await get_tree().process_frame
		if skip_with != "click": _key_event(code, true, true)
		if not shot_gauge and _clock - started > 0.55:
			shot_gauge = true
			await _shot("prologue_jauge")
	var held_for: float = _clock - started
	_check(world.phase == "menu", "prologue passé en maintenant (%s, %.2f s) → phase %s" % [skip_with, held_for, world.phase])
	# On garde encore la touche 0,6 s (répétitions), puis on relâche : rien ne doit s'activer.
	var after: float = _clock
	while _clock - after < 0.6:
		await get_tree().process_frame
		if skip_with != "click": _key_event(code, true, true)
	await _shot("menu_apres_prologue_tenu")
	if skip_with == "click":
		var release: InputEventMouseButton = InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		var centre_up: Vector2 = Vector2(get_window().size) * 0.5
		release.position = centre_up
		release.global_position = centre_up
		Input.parse_input_event(release)
	else: _key_event(code, false)
	await _wait(0.8)
	_note("après relâchement : " + _state())
	_check(world.phase == "menu" and world.ui.current_page == "main", "toujours sur le menu principal après le relâchement")
	await _shot("menu_apres_prologue")
	await _wait(1.2)
	await _shot("menu_pose")

func _step_main() -> void :
	if world.phase != "menu" or world.ui.current_page != "main":
		world.ui.show_main()
		await _wait(1.2)
	await _tap(KEY_DOWN, 0.4)
	_note("menu bas : " + _state())
	await _shot("menu_clavier_bas")
	for entry: String in ["JOUER", "TERRAIN D’ESSAI", "ENTRE AMIS", "BOUTIQUE", "CINÉMATHÈQUE", "RÉGLAGES", "CRÉDITS", "QUITTER"]:
		var item: Control = _find(entry, world.ui.page)
		_check(item != null, "entrée du menu « %s »" % entry)
		if item == null: continue
		await _hover(item, 0.9)
		await _shot("menu_survol_" + entry.to_lower().replace(" ", "_").replace("’", ""))
	await _mouse_to(Vector2(8, 8))
	await _wait(0.4)

func _step_setup() -> void :
	world.ui.show_main()
	await _wait(1.0)
	await _tap(KEY_DOWN, 0.2)
	if not _focus().ends_with(_tr("JOUER")): await _tap(KEY_UP, 0.2)
	_note("avant Entrée : " + _state())
	await _tap(KEY_ENTER, 1.4)
	_note("préparation : " + _state())
	_check(world.ui.current_page == "characters", "Entrée sur JOUER ouvre la préparation")
	await _shot("preparation")
	await _tap(KEY_RIGHT, 0.25)
	await _tap(KEY_RIGHT, 0.6)
	var backdrop: Node = world.ui.get("menu_backdrop")
	_note("préparation droite x2 : %s · aperçu=%s · héros=%s" % [_state(), world.preview_character, backdrop.get("hero_person") if is_instance_valid(backdrop) else "-"])
	await _shot("preparation_clavier")
	await _pad(JOY_BUTTON_DPAD_UP, 0.3)
	_note("croix haut : " + _state())
	var alice_tab: Control = _find("ALICE", world.ui.page)
	if alice_tab:
		alice_tab.grab_focus()
		await _wait(0.2)
		await _pad(JOY_BUTTON_A, 1.2)
	_note("onglet ALICE (A) : " + _state())
	_check(world.ui.current_page == "alice", "A sur l'onglet ALICE ouvre le dossier d'Alice")
	await _shot("preparation_alice")
	var survivor_tab: Control = _find("SURVIVANT", world.ui.page)
	if survivor_tab: await _click(survivor_tab, 1.0)
	_check(world.ui.current_page == "characters", "clic sur SURVIVANT revient aux élèves")
	await _pad(JOY_BUTTON_B, 1.2)
	_note("B : " + _state())
	_check(world.ui.current_page == "main", "B revient au menu principal")

func _step_settings() -> void :
	world.ui.show_main()
	await _wait(1.0)
	await _click(_find("RÉGLAGES", world.ui.page), 1.3)
	_check(world.ui.current_page == "settings", "clic sur RÉGLAGES")
	if world.ui.settings_tab != "game": world.ui._settings_switch("game")
	await _wait(0.6)
	await _mouse_to(Vector2(8, 8))
	await _shot("reglages_jeu")
	var mode_label: Control = _find("Mode de caméra", world.ui.page)
	_check(mode_label != null, "ligne « Mode de caméra » dans l'onglet Jeu")
	# Clavier : descendre jusqu'à la ligne du mode de caméra (la bande rouge doit la suivre).
	for i: int in range(5): await _tap(KEY_DOWN, 0.15)
	_note("jeu bas x5 : " + _state())
	await _wait(0.3)
	await _shot("reglages_jeu_ligne")
	await _pad(JOY_BUTTON_RIGHT_SHOULDER, 0.5)
	await _pad(JOY_BUTTON_RIGHT_SHOULDER, 0.9)
	_check(world.ui.settings_tab == "audio", "RB x2 → onglet Audio (%s)" % world.ui.settings_tab)
	await _tap(KEY_DOWN, 0.3)
	await _shot("reglages_audio")
	await _pad(JOY_BUTTON_RIGHT_SHOULDER, 0.9)
	_check(world.ui.settings_tab == "controls", "RB → onglet Commandes (%s)" % world.ui.settings_tab)
	await _shot("reglages_commandes")
	await _click(_find("PERSONNALISER CLAVIER / MANETTE", world.ui.page), 1.2)
	_check(world.controls_menu.visible, "carnet de commandes ouvert")
	await _shot("carnet_commandes")
	var camera_row: Control = _find(PaperBindings.LABELS["camera_mode"], world.controls_menu)
	_check(camera_row != null, "action « %s » dans le carnet" % PaperBindings.LABELS["camera_mode"])
	if camera_row:
		var scroll: ScrollContainer = _scroll_parent(camera_row)
		if scroll: scroll.ensure_control_visible(camera_row)
		await _wait(0.5)
		await _shot("carnet_commandes_camera")
	var sens: Control = _find("Sensibilité", world.controls_menu)
	if sens:
		var scroll_s: ScrollContainer = _scroll_parent(sens)
		if scroll_s: scroll_s.ensure_control_visible(sens)
		await _wait(0.5)
		await _shot("carnet_commandes_manette")
	await _pad(JOY_BUTTON_B, 1.0)
	_check(not world.controls_menu.visible, "B ferme le carnet")
	await _tap(KEY_ESCAPE, 1.0)
	_check(world.ui.current_page == "main", "Échap quitte les réglages")

func _scroll_parent(node: Node) -> ScrollContainer:
	var current: Node = node.get_parent()
	while current:
		if current is ScrollContainer: return current as ScrollContainer
		current = current.get_parent()
	return null

func _step_friends() -> void :
	world.ui.show_main()
	await _wait(1.0)
	await _click(_find("ENTRE AMIS", world.ui.page), 1.2)
	_check(world.ui.current_page == "network", "ENTRE AMIS ouvre la page réseau (%s)" % world.ui.current_page)
	await _mouse_to(Vector2(8, 8))
	await _shot("entre_amis")
	await _click(_find("CONNEXION DIRECTE / RÉGLAGES RÉSEAU", world.ui.page), 1.0)
	await _mouse_to(Vector2(8, 8))
	await _shot("connexion_directe")
	# Salon simulé sans ouvrir de port (d'autres tests réseau tournent peut-être sur la machine).
	world.phase = "lobby"
	world.stage.visible = true
	world.roster = {1: {"name": world.nickname, "character": "Simon", "malice": 2}, 51234: {"name": "Margaux", "character": "Lysia", "malice": 4}, 77001: {"name": "Théo", "character": "Bleuette", "malice": 1}}
	world.lobby_leader = 1
	world.room_options = world._clean_room_options({"killer_mode": "random"})
	world.ui.show_lobby()
	await _wait(1.4)
	await _shot("salon")
	var choice: OptionButton = world.ui.get("lobby_alice")
	_check(is_instance_valid(choice), "sélecteur « Qui joue Alice ? » présent pour l'hôte")
	if is_instance_valid(choice):
		choice.grab_focus()
		await _wait(0.4)
		await _shot("salon_selecteur_focus")
		await _pad(JOY_BUTTON_A, 0.6)
		await _shot("salon_selecteur_ouvert")
		var popup: PopupMenu = choice.get_popup()
		var target: int = -1
		for index: int in range(choice.item_count):
			if choice.get_item_text(index).begins_with("Margaux"): target = index
		_note("menu Alice : " + ", ".join(PackedStringArray(range(choice.item_count).map(func(i: int) -> String: return choice.get_item_text(i)))))
		if popup.visible: popup.hide()
		if target >= 0:
			choice.select(target)
			choice.item_selected.emit(target)
		await _wait(0.8)
		_check(world.chosen_alice_peer() == 51234, "Margaux choisie pour jouer Alice (%d)" % world.chosen_alice_peer())
		await _mouse_to(Vector2(8, 8))
		await _shot("salon_badge_alice")
	await _click(_find("QUITTER LE SALON", world.ui.page), 1.0)
	world.roster = {}
	_note("après QUITTER LE SALON : " + _state())

func _step_shop() -> void :
	world.ui.show_main()
	await _wait(1.0)
	await _click(_find("BOUTIQUE", world.ui.page), 1.4)
	_check(world.ui.current_page == "shop", "BOUTIQUE ouverte")
	await _mouse_to(Vector2(8, 8))
	await _shot("boutique")
	for i: int in range(3): await _tap(KEY_DOWN, 0.15)
	await _wait(0.4)
	_note("boutique bas x3 : " + _state())
	await _shot("boutique_clavier")
	var classics: Control = _find("LES CLASSIQUES", world.ui.page)
	_check(classics != null, "section « LES CLASSIQUES »")
	var fresh: Control = _find("NOUVEAU  ·  TENDANCES TIKTOK 2025-2026", world.ui.page)
	_check(fresh != null, "section « NOUVEAU · TENDANCES TIKTOK 2025-2026 »")
	if classics:
		var scroll: ScrollContainer = _scroll_parent(classics)
		if scroll: scroll.ensure_control_visible(classics)
		await _wait(0.5)
		await _shot("boutique_classiques")
	# Aperçu d'une nouveauté : le danseur change derrière la liste.
	var previews: Array = world.ui.page.find_children("*", "Button", true, false).filter(func(node: Node) -> bool: return (node as Button).is_visible_in_tree() and str((node as Button).text).strip_edges() == _tr("APERÇU"))
	_note("boutons APERÇU : %d" % previews.size())
	if previews.size() >= 3:
		var scroll_p: ScrollContainer = _scroll_parent(previews[2])
		if scroll_p: scroll_p.ensure_control_visible(previews[2])
		await _wait(0.3)
		await _click(previews[2], 1.6)
		await _mouse_to(Vector2(8, 8))
		await _wait(1.2)
		await _shot("boutique_apercu")
	await _tap(KEY_ESCAPE, 1.0)
	_check(world.ui.current_page == "main", "Échap quitte la boutique")

func _step_gallery() -> void :
	world.ui.show_main()
	await _wait(1.0)
	await _click(_find("CINÉMATHÈQUE", world.ui.page), 0.4)
	await _wait_phase("gallery", 6.0)
	await _wait(1.6)
	_check(world.phase == "gallery", "CINÉMATHÈQUE ouverte (%s)" % world.phase)
	await _mouse_to(Vector2(8, 8))
	await _shot("cinematheque")
	var exit_sign: Node3D = world.map_interactables.exit_sign if is_instance_valid(world.map_interactables) else null
	_check(exit_sign == null or not exit_sign.visible, "panneau 3D « SORTIE · À 01:20 » caché derrière la liste")
	var titles: Array = world.gallery.filtered_entries().map(func(item: Dictionary) -> String: return str(item.title))
	_check(not titles.is_empty() and str(titles[0]).begins_with("Prologue"), "le Prologue est en tête (%s)" % (titles[0] if not titles.is_empty() else "-"))
	var intros: Array = world.gallery.entries.filter(func(item: Dictionary) -> bool: return str(item.kind) in ["intro_survivors", "intro_alice"])
	_check(intros.is_empty(), "aucune intro de survivants ni d'Alice dans le catalogue")
	var counts: Dictionary = {}
	for item: Dictionary in world.gallery.entries: counts[str(item.category)] = int(counts.get(str(item.category), 0)) + 1
	_note("catégories : " + str(counts))
	var choice: OptionButton = null
	for node: Node in world.ui.page.find_children("*", "OptionButton", true, false):
		if (node as Control).is_visible_in_tree(): choice = node as OptionButton
	_check(choice != null and choice.item_count == 6, "filtre de catégories à 6 entrées")
	if choice:
		var items: PackedStringArray = PackedStringArray()
		for index: int in range(choice.item_count): items.append(choice.get_item_text(index))
		_note("filtre : " + " | ".join(items))
		choice.grab_focus()
		await _pad(JOY_BUTTON_A, 0.6)
		await _shot("cinematheque_filtre_ouvert")
		choice.get_popup().hide()
	# Un film de chaque catégorie : lecture depuis la liste, deux instants, retour.
	var plan: Array = [["intro", "intro_yiero", [44.0, 186.5]], ["lms_win", "lms_win_Lysia", [3.5, 8.0]], ["lms_loss", "lms_loss_Elly", [2.5, 5.5]], ["team", "team_63", [3.0, 7.0]], ["fins", "blocus", [6.0, 25.0]]]
	for spec: Array in plan:
		world.gallery.category = str(spec[0])
		world.ui.show_gallery()
		await _wait(0.8)
		if str(spec[0]) == "team":
			await _mouse_to(Vector2(8, 8))
			await _shot("cinematheque_equipe")
		var wanted: Dictionary = {}
		for item: Dictionary in world.gallery.filtered_entries():
			if str(item.id) == str(spec[1]): wanted = item
		_check(not wanted.is_empty(), "film %s dans la catégorie %s" % [spec[1], spec[0]])
		if wanted.is_empty(): continue
		var button: Control = _find("▶  " + str(wanted.title), world.ui.page)
		if button == null: button = _find("▶  " + PaperLanguage.t(str(wanted.title)), world.ui.page)
		if button:
			var scroll: ScrollContainer = _scroll_parent(button)
			if scroll: scroll.ensure_control_visible(button)
			await _wait(0.3)
			await _click(button, 0.5)
		else: world.gallery.play_entry(wanted)
		await _wait(0.6)
		_check(world.gallery.playing, "lecture de « %s »" % wanted.title)
		if str(spec[0]) == "lms_win":
			# Manette pendant la lecture : A met en pause, la croix avance d'une seconde, A relance.
			await _pad(JOY_BUTTON_A, 0.3)
			var paused_at: float = float(world.gallery.time)
			_check(not world.gallery.playing, "A met le film en pause")
			await _pad(JOY_BUTTON_DPAD_RIGHT, 0.3)
			_check(absf(float(world.gallery.time) - paused_at - 1.0) < 0.05, "croix → avance d'1 s (%.2f → %.2f)" % [paused_at, float(world.gallery.time)])
			await _pad(JOY_BUTTON_A, 0.3)
			_check(world.gallery.playing, "A relance le film")
		for at: Variant in spec[2]:
			world.gallery.seek(float(at))
			await _wait(0.5)
			await _mouse_to(Vector2(8, 8))
			await _shot("film_%s_%04.1fs" % [spec[1], float(at)])
		await _tap(KEY_ESCAPE, 0.8)
		_check(world.gallery.browsing, "Échap revient à la liste")
	world.gallery.category = "all"
	world.ui.show_gallery()
	await _wait(0.6)
	_check(exit_sign == null or not exit_sign.visible, "panneau toujours caché au retour à la liste (après les films)")
	await _pad(JOY_BUTTON_B, 1.4)
	_check(world.phase == "menu", "B quitte la cinémathèque (%s)" % world.phase)
	_check(exit_sign == null or exit_sign.visible, "panneau rétabli en quittant la cinémathèque")

func _start_round() -> bool:
	world.ui.show_main()
	await _wait(1.0)
	await _click(_find("JOUER", world.ui.page), 1.3)
	if world.ui.current_page == "alice": world.ui._set_role("survivor")
	await _wait(0.4)
	var launch: Control = _find("LANCER LA PARTIE", world.ui.page, true)
	_check(launch != null, "bouton LANCER LA PARTIE")
	await _click(launch, 0.5)
	var ok: bool = await _wait_phase("playing", 90.0)
	_check(ok, "partie solo lancée (%s)" % world.phase)
	await _wait(2.0)
	return ok

func _step_pause() -> void :
	if not await _start_round(): return
	await _shot("partie_hud")
	await _tap(KEY_ESCAPE, 0.9)
	_check(world.pause_open, "Échap ouvre la pause")
	_note("pause : " + _state())
	await _shot("pause")
	await _tap(KEY_DOWN, 0.2)
	await _tap(KEY_ENTER, 1.3)
	_check(world.ui.current_page == "settings" and world.ui.page.visible, "Réglages depuis la pause")
	await _shot("pause_reglages")
	await _tap(KEY_ESCAPE, 1.2)
	_note("retour pause : " + _state())
	await _tap(KEY_DOWN, 0.2)
	await _tap(KEY_ENTER, 1.2)
	_check(world.controls_menu.visible, "Commandes depuis la pause")
	await _shot("pause_commandes")
	await _pad(JOY_BUTTON_B, 1.2)
	_note("retour pause (B) : " + _state())
	await _tap(KEY_DOWN, 0.2)
	await _tap(KEY_ENTER, 0.8)
	_note("confirmation : " + _state())
	await _shot("pause_confirmation")
	await _pad(JOY_BUTTON_B, 0.6)
	await _pad(JOY_BUTTON_B, 0.8)
	_check(not world.pause_open, "B, B : la partie reprend")
	await _shot("partie_reprise")

func _step_results() -> void :
	for spec: Array in [["survivors", false, "victoire"], ["killer", false, "defaite"], ["survivors", true, "forfait"]]:
		if world.phase != "playing":
			if not await _start_round(): return
		world._finish(str(spec[0]), bool(spec[1]))
		await _wait(0.2)
		_note("fin %s : kind=%s duree=%.1f" % [spec[2], world.ending_kind, float(world.film.duration)])
		await _wait(minf(4.0, float(world.film.duration) * 0.4))
		await _shot("fin_%s_film" % spec[2])
		var shown: bool = await _until(func() -> bool: return world.ui.current_page == "ending", 70.0)
		_check(shown, "écran de résultats (%s)" % spec[2])
		await _wait(1.6)
		await _mouse_to(Vector2(8, 8))
		await _shot("resultats_%s" % spec[2])
		_note("résultats %s : %s" % [spec[2], _state()])
		if str(spec[2]) == "victoire":
			# « NOUVELLE MANCHE » en solo : retour à la préparation, prête à relancer.
			await _click(_find("NOUVELLE MANCHE", world.ui.overlay), 1.2)
			_check(world.phase == "menu" and world.ui.current_page in ["characters", "alice"], "NOUVELLE MANCHE ouvre la préparation (%s)" % world.ui.current_page)
			await _shot("nouvelle_manche_preparation")
			continue
		await _click(_find("MENU PRINCIPAL", world.ui.overlay), 1.0)
		_check(world.phase == "menu", "MENU PRINCIPAL depuis les résultats")

func _step_verdicts() -> void :
	for spec: Array in [["survivors", false, "ending_survivors", "victoire"], ["killer", true, "ending_killer", "defaite_lms"], ["survivors", false, PaperAliceForfeit.KIND, "forfait"]]:
		var rows: Array = []
		var people: Array = ["Simon", "Lysia", "Ashura", "Elly", "Bleuette", "Usayuko"]
		for i: int in range(people.size()):
			rows.append({"id": i + 2, "character": people[i], "name": people[i] + (" · Toi" if i == 0 else " · IA"), "points": [412, 355, 280, 211, 160, 90][i], "grade": ["A", "B", "B", "C", "C", "D"][i], "aura": 40 + i * 9, "breakdown": {"heal": 30 + i * 4, "stun": 2 + i, "danger": 12}})
		world.match_results = rows
		world.ending_kind = str(spec[2])
		world.ui.show_ending(str(spec[0]), bool(spec[1]))
		await _wait(1.8)
		await _mouse_to(Vector2(8, 8))
		await _shot("verdict_" + str(spec[3]))
	world.quit_to_menu()
	await _wait(0.6)
