extends Node

# Textes restés en français dans les menus en anglais (0.16), sans rendu :
#   XDG_DATA_HOME=<dossier de test> godot --headless -- --tool test_menu_i18n [--i18n-all]
# Ouvre chaque écran (menu, préparation, réglages, carnet, réseau, salon, boutique,
# cinémathèque, crédits, partie, pause, roue d'émotes, résultats), relève les textes
# visibles (libellés, boutons, listes, infobulles, titres dessinés) tels qu'ils
# s'affichent en anglais et signale ceux qui ressemblent encore à du français.
# Lignes « I18N <écran> | <texte> » ; --i18n-all affiche aussi les textes corrects.

const FRENCH_WORDS: PackedStringArray = ["le", "la", "les", "des", "du", "de", "et", "pour", "avec", "ton", "ta", "tes", "une", "un", "est", "sont", "pas", "sans", "dans", "sur", "au", "aux", "qui", "que", "joue", "jouer", "retour", "quitter", "choisis", "manche", "partie", "salon", "carte", "danse", "danses", "boutique", "prise", "vie", "nouveau", "nouvelle", "tendances", "classiques", "aperçu", "toi", "tickets", "scène", "scènes", "fin", "fins", "lecture", "revoir", "rejouer", "maintenir", "passer", "caméra", "libre", "derrière", "général", "musique", "effets", "volume", "survivants", "élèves", "hôte", "aléatoire", "malice", "personnage", "commandes", "réglages", "jeu", "oui", "non", "annuler", "reprendre", "valider", "choisir", "onglets", "souris", "manette", "clavier", "touche", "sensibilité", "accélération", "zone", "morte"]

var world: Node
var show_all: bool = false
var _clock: float = 0.0
var _seen: Dictionary = {}
var _flagged: int = 0
var _word_re: RegEx

func setup(game_world: Node) -> void :
	world = game_world
	show_all = "--i18n-all" in OS.get_cmdline_user_args()
	_word_re = RegEx.new()
	_word_re.compile("(?i)(?<![\\p{L}])(" + "|".join(FRENCH_WORDS) + ")(?![\\p{L}])")
	_run.call_deferred()

func _process(delta: float) -> void :
	_clock += delta

func _wait(seconds: float) -> void :
	var start: float = _clock
	while _clock - start < seconds: await get_tree().process_frame

func _french(text: String) -> bool:
	var probe: String = text.strip_edges()
	if probe.length() < 2: return false
	for ch: String in ["é", "è", "ê", "à", "â", "î", "ô", "û", "ù", "ç", "œ", "É", "È", "Ê", "À", "Â", "Î", "Ô", "Û", "Ç", "’"]:
		if ch in probe: return true
	return _word_re.search(probe) != null

func _collect(node: Node, out: Array) -> void :
	if node is CanvasItem and not (node as CanvasItem).visible: return
	if node is Control:
		var control: Control = node as Control
		if not bool(control.get_meta("language_user_text", false)):
			if control is OptionButton:
				var option: OptionButton = control as OptionButton
				for i: int in range(option.item_count): out.append(option.get_item_text(i))
			elif "text" in control:
				var value: String = str(control.get("text"))
				# Widgets dessinés (collage, entrées du menu…) : ils traduisent au dessin.
				if not (control is Label or control is Button or control is RichTextLabel or control is LineEdit): value = T_tr(value)
				elif control is Button and control.get_script() != null: value = T_tr(value)
				out.append(value)
			if control is LineEdit: out.append(str((control as LineEdit).placeholder_text))
			# Aides affichées seulement au survol / à la sélection (entrées du menu principal…).
			if "hint" in control and control.get("hint") is String: out.append(T_tr(str(control.get("hint"))))
			if not control.tooltip_text.is_empty(): out.append(control.tooltip_text)
	for child: Node in node.get_children(): _collect(child, out)

func T_tr(text: String) -> String:
	return PaperLanguage.t(text)

func _scan(screen: String) -> void :
	await _wait(0.7)
	var texts: Array = []
	_collect(get_tree().root, texts)
	for value: Variant in texts:
		var text: String = str(value).strip_edges()
		if text.is_empty(): continue
		var key: String = screen + "|" + text
		if _seen.has(text): continue
		_seen[text] = true
		if _french(text):
			_flagged += 1
			print("I18N ", screen, " | ", text.replace("\n", "⏎"))
		elif show_all: print("I18N_OK ", screen, " | ", text.replace("\n", "⏎"))

func _run() -> void :
	await _wait(0.5)
	world.options["language"] = "en"
	world.apply_options()
	PaperLanguage.language = "en"
	var ui: Node = world.ui
	ui.show_main()
	await _scan("menu")
	ui._show_setup("survivor", -1)
	await _scan("preparation")
	ui._show_setup("alice", -1)
	await _scan("preparation_alice")
	world.solo_killer = false
	for tab: String in ["game", "display", "audio", "controls", "access"]:
		ui.settings_tab = tab
		ui.show_settings()
		await _scan("reglages_" + tab)
	world.controls_menu.open()
	await _scan("carnet")
	world.controls_menu.hide()
	ui.show_network()
	await _scan("reseau")
	ui.show_network_advanced()
	await _scan("reseau_direct")
	world.online_menu.open()
	await _scan("en_ligne")
	world.online_menu.close()
	world.phase = "lobby"
	world.roster = {1: {"name": world.nickname, "character": "Simon", "malice": 2}, 51234: {"name": "Margaux", "character": "Lysia", "malice": 4}}
	world.room_options = world._clean_room_options({"killer_mode": "player", "alice_peer": 51234})
	ui.show_lobby()
	await _scan("salon")
	world.room_options = world._clean_room_options({"mode": "training"})
	ui.show_lobby()
	await _scan("salon_essai")
	world.roster = {}
	world.room_options = world._clean_room_options({})
	world.phase = "menu"
	ui.show_shop()
	await _scan("boutique")
	ui.show_credits()
	await _scan("credits")
	world.gallery.open()
	await _scan("cinematheque")
	world.gallery.category = "team"
	ui.show_gallery()
	await _scan("cinematheque_equipe")
	world.gallery.category = "all"
	for id: String in ["intro_yiero", "lms_win_Simon", "lms_loss_Elly", "blocus"]:
		for item: Dictionary in world.gallery.entries:
			if str(item.id) == id: world.gallery.play_entry(item)
		await _wait(1.0)
		world.gallery.seek(5.0)
		await _scan("film_" + id)
		world.gallery.browse()
		await _wait(0.3)
	world.gallery.close()
	await _wait(0.5)
	world.selected = "Simon"
	world.start_solo(false)
	var waited: float = 0.0
	while world.phase != "playing" and waited < 90.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	await _wait(2.0)
	await _scan("partie_hud")
	world.emote_wheel.open()
	await _scan("roue_emotes")
	world.emote_wheel.close()
	await _wait(0.3)
	for pressed: bool in [true, false]:
		var key: InputEventKey = InputEventKey.new()
		key.keycode = KEY_ESCAPE
		key.physical_keycode = KEY_ESCAPE
		key.pressed = pressed
		Input.parse_input_event(key)
		await get_tree().process_frame
	await _wait(0.8)
	await _scan("pause")
	var pause: Node = ui.get("_pause_menu")
	if is_instance_valid(pause): pause.call("_open_confirm")
	await _scan("pause_confirmation")
	world._finish("survivors")
	while world.ui.current_page != "ending" and waited < 200.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	await _scan("resultats_victoire")
	world.match_results = world.match_results
	world.ending_kind = PaperAliceForfeit.KIND
	ui.show_ending("survivors", false)
	await _scan("resultats_forfait")
	world.ending_kind = "ending_killer"
	ui.show_ending("killer", true)
	await _scan("resultats_defaite")
	print("I18N_DONE flagged=%d" % _flagged)
	get_tree().quit()
