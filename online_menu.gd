class_name PaperOnlineMenu
extends Control

const ClientScript = preload("res://game_social_client.gd")
const T = preload("res://ui_theme.gd")
const Sound = preload("res://ui_sound.gd")
const MenuFx = preload("res://ui_menu_fx.gd")

const INK: Color = Color("ece5d5")
const PAPER: Color = Color("0d0f16")
const RED: Color = Color("d6455d")
const MUTED: Color = Color("8c8f99")
var world: Node
var client: PaperGameSocialClient
var content: VBoxContainer
var status_label: Label
var account_label: Label
var heading: Label
var friends_button: Button
var scroll: ScrollContainer
var _page: String = ""
var _page_generation: int = 0
var _polling: bool = false
var _waiting_group: bool = false
var _timer: Timer
var _first_tab: Button

func setup(owner: Node) -> void :
	world = owner;name = "OnlineAccountMenu";set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);z_index = 180
	client = ClientScript.new();add_child(client);client.load_config();client.notice.connect(_status);client.identity_changed.connect(_identity)
	_build();hide()
	_timer = Timer.new();_timer.wait_time = 12.0;_timer.timeout.connect(_poll);add_child(_timer);_timer.start()

func open() -> void :
	show();Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show_account() if not client.service_url.is_empty() else show_service()
	_first_tab.grab_focus()

func close() -> void :
	_page_generation += 1;hide()

func _unhandled_input(event: InputEvent) -> void :
	if visible and event.is_action_pressed("ui_cancel"): close();get_viewport().set_input_as_handled()

func _style(background: Color, border: Color = T.LINE) -> StyleBox:
	var style: StyleBox = T.strip(background, 18, 12, 6.0, 37)
	style.set("line", Color(border, 0.6))
	return style

func _label(value: String, font_size: int = 19, color: Color = INK) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if font_size >= 25: label.add_theme_font_override("font", T.font("title"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _button(value: String, callback: Callable, primary: bool = false) -> Button:
	var button: Button = Button.new()
	button.text = value
	button.custom_minimum_size.y = 50
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.theme_type_variation = "PrimaryButton" if primary else ""
	button.pressed.connect(callback)
	button.pressed.connect(_sfx.bind("confirm" if primary else "click"))
	button.mouse_entered.connect(_sfx.bind("hover"))
	return button

func _sfx(kind: String) -> void :
	Sound.play(kind)

func _field(placeholder: String, secret: bool = false) -> LineEdit:
	var field: LineEdit = LineEdit.new()
	field.placeholder_text = placeholder
	field.secret = secret
	field.custom_minimum_size.y = 50
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return field

func _build() -> void :
	var background: Panel = Panel.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_theme_stylebox_override("panel", T.box(Color(PAPER, 0.97), Color(0, 0, 0, 0), 0, 0, 0, 0))
	add_child(background)
	var decor: MenuFx.Decor = MenuFx.Decor.new()
	decor.title = "EN LIGNE"
	decor.accent = Color("6fa8ff").lerp(T.RED_DEEP, 0.55)
	decor.giant_alpha = 0.06
	decor.ribbon_text = "LE CARNET DES ÉLÈVES"
	add_child(decor)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 48)
	for side in ["top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin); var column: VBoxContainer = VBoxContainer.new();column.add_theme_constant_override("separation", 10);margin.add_child(column)
	var top: HBoxContainer = HBoxContainer.new();column.add_child(top)
	top.add_child(_label("LE CARNET DES ÉLÈVES", 27)); var back: Button = _button("Fermer", close);back.size_flags_horizontal = Control.SIZE_SHRINK_END;back.custom_minimum_size.x = 125;top.add_child(back)
	account_label = _label("Aucun compte connecté", 16, MUTED);column.add_child(account_label)
	var tabs: HBoxContainer = HBoxContainer.new();tabs.add_theme_constant_override("separation", 8);column.add_child(tabs)
	_first_tab = _button("Compte", show_account);tabs.add_child(_first_tab);friends_button = _button("Amis", show_friends);tabs.add_child(friends_button);tabs.add_child(_button("Groupe", show_group));tabs.add_child(_button("Service", show_service))
	heading = _label("", 25);column.add_child(heading)
	scroll = ScrollContainer.new();scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED;column.add_child(scroll)
	content = VBoxContainer.new();content.size_flags_horizontal = Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation", 12);scroll.add_child(content)
	status_label = _label("", 17, MUTED);status_label.custom_minimum_size.y = 27;column.add_child(status_label)
	_identity()

func _clear(page: String, title: String) -> int:
	_page = page;_page_generation += 1;_waiting_group = false;heading.text = title;status_label.text = ""
	for child in content.get_children(): content.remove_child(child);child.queue_free()
	scroll.scroll_vertical = 0
	if is_instance_valid(world.ui.fx): world.ui.fx.cascade_children.call_deferred(content, 0.0, 0.035, Vector2(-60, 0), -0.05, 0.24)
	return _page_generation

func _card(title: String, description: String = "", title_user: bool = false, description_user: bool = false) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("151925"), T.LINE))
	content.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new();box.add_theme_constant_override("separation", 10);panel.add_child(box)
	var title_label: Label = _label(title, 22);title_label.set_meta("language_user_text", title_user);box.add_child(title_label)
	if not description.is_empty():
		var description_label: Label = _label(description, 17, MUTED);description_label.set_meta("language_user_text", description_user);box.add_child(description_label)
	return box

func _status(message: String, error: bool = false) -> void :
	if is_instance_valid(status_label): status_label.text = message;status_label.add_theme_color_override("font_color", RED if error else MUTED)

func _identity() -> void :
	if not is_instance_valid(account_label): return
	account_label.text = (str(client.profile.get("nickname", "Élève")) + "  ·  Compte connecté") if not client.token.is_empty() else "Mode hors ligne · connecte-toi pour retrouver tes amis"

func _require_account() -> bool:
	if client.service_url.is_empty():
		_card("Le service en ligne n’est pas configuré", "Aucun serveur régional public n’est fourni pour l’instant. Le solo reste disponible. L’administrateur devra fournir l’adresse HTTPS du service.")
		content.add_child(_button("Configurer l’adresse du service", show_service, true));return false
	if client.token.is_empty():
		_card("Ton compte est nécessaire", "Connecte-toi pour rejoindre un groupe privé, recevoir des invitations et retrouver tes statistiques.")
		content.add_child(_button("Se connecter", show_account, true));return false
	return true

func show_service() -> void :
	_clear("service", "Le service de jeu")
	var box: VBoxContainer = _card("Adresse fournie par l’administrateur", "Sans hébergement configuré, les comptes et les parties régionales restent indisponibles. Utilise la même adresse sur ordinateur et Android.")
	var address: LineEdit = _field("https://adresse-du-service");address.text = client.service_url;address.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_URL;box.add_child(address)
	box.add_child(_button("Enregistrer et vérifier", func():
		if not client.configure(address.text): return
		if client.service_url.is_empty(): _status("Mode hors ligne : aucune adresse enregistrée.");return
		_status("Vérification du service…")
		var reply: Dictionary = await client.api("/health")
		if reply.get("ok", false) and int(reply.get("protocol", 0)) == PaperRules.PROTOCOL: _status("Service accessible · %d ms vers le service de comptes." % client.last_latency_ms)
		elif reply.get("ok", false): _status("Le service utilise une autre version du jeu.", true), true))
	box.add_child(_label("Seule l’adresse est enregistrée. Les mots de passe et les jetons de connexion ne sont pas conservés sur le disque.", 16, MUTED))

func show_account() -> void :
	var epoch: int = _clear("account", "Ton dossier d’élève")
	if client.service_url.is_empty(): _require_account();return
	if client.token.is_empty():
		var box: VBoxContainer = _card("Connexion / inscription", "Identifiant : 3 à 24 lettres, chiffres ou _. Mot de passe : 10 caractères minimum.")
		var username: LineEdit = _field("Identifiant du compte"); var password: LineEdit = _field("Mot de passe", true); var nickname: LineEdit = _field("Pseudo visible (inscription)")
		box.add_child(username);box.add_child(password);box.add_child(nickname)
		box.add_child(_button("Se connecter", func(): _authenticate(username, password, nickname, false), true))
		box.add_child(_button("Créer un compte", func(): _authenticate(username, password, nickname, true)))
		password.text_submitted.connect( func(_text: String): _authenticate(username, password, nickname, false))
		return
	_status("Lecture du dossier…"); var refreshed: bool = await client.refresh_profile()
	if epoch != _page_generation: return
	if client.token.is_empty(): show_account();return
	if not refreshed: content.add_child(_button("Réessayer", show_account));return
	var profile: Dictionary = client.profile; var stats: Dictionary = profile.get("stats", {})
	var box: VBoxContainer = _card(str(profile.get("nickname", "Élève")), "@" + str(profile.get("username", "")), true, true)
	box.add_child(_label("%d parties  ·  %d victoires  ·  %d points" % [int(stats.get("matches", 0)), int(stats.get("wins", 0)), int(stats.get("points", 0))], 23))
	box.add_child(_label("%d étourdissements  ·  %d soins  ·  %d boosts  ·  %d évasions" % [int(stats.get("stuns", 0)), int(stats.get("heals", 0)), int(stats.get("boosts", 0)), int(stats.get("escapes", 0))], 17))
	var name_field: LineEdit = _field("Nouveau pseudo");name_field.text = str(profile.get("nickname", ""));box.add_child(name_field)
	box.add_child(_button("Changer mon pseudo", func():
		var reply: Dictionary = await client.api("/v1/profile", {"nickname": name_field.text}, HTTPClient.METHOD_POST)
		if reply.get("user") is Dictionary: client.profile = reply.user;_identity();show_account()))
	content.add_child(_label("Ces statistiques proviennent des parties validées par les serveurs dédiés. Le solo et les essais du bac à sable ne les modifient pas.", 17, MUTED))
	content.add_child(_button("Se déconnecter", func(): await client.logout();show_account()))
	_status("")

func _authenticate(username: LineEdit, password: LineEdit, nickname: LineEdit, register: bool) -> void :
	if client.pending > 0: return
	var epoch: int = _page_generation
	var login: String = username.text; var secret: String = password.text; var name_value: String = nickname.text
	password.clear();_status("Connexion…")
	var success: bool = await client.authenticate(login, secret, name_value, register)
	secret = ""
	if success and epoch == _page_generation: show_account()

func _post(path: String, body: Dictionary, success_page: String = "") -> Dictionary:
	if client.pending > 0: return {}
	var epoch: int = _page_generation
	var reply: Dictionary = await client.api(path, body, HTTPClient.METHOD_POST)
	if epoch != _page_generation: return reply
	if not reply.has("error"):
		match success_page:
			"friends": show_friends()
			"group": show_group()
			_: _status("C’est fait.")
	return reply

func show_friends() -> void :
	var epoch: int = _clear("friends", "La bande après les cours")
	if not _require_account(): return
	_status("Recherche des amis et invitations…")
	var friends: Dictionary = await client.api("/v1/friends"); var invitations: Dictionary = await client.api("/v1/invites"); var current: Dictionary = await client.api("/v1/parties/current")
	if epoch != _page_generation: return
	if friends.has("error") or invitations.has("error") or current.has("error"): content.add_child(_button("Réessayer", show_friends));return
	var party: Dictionary = current.party if current.get("party") is Dictionary else {}
	var add: VBoxContainer = _card("Retrouver un ami", "Entre l’identifiant de son compte."); var username: LineEdit = _field("Identifiant de ton ami");add.add_child(username)
	add.add_child(_button("Envoyer une demande", func(): _post("/v1/friends/request", {"username": username.text}, "friends")))
	for invitation: Dictionary in invitations.get("invites", []):
		var invite: Dictionary = invitation.duplicate(); var box: VBoxContainer = _card(str(invite.sender) + " t’invite dans son groupe")
		box.add_child(_button("Accepter l’invitation", func(): join_party(str(invite.party_id)), true))
	for person: Dictionary in friends.get("incoming", []):
		var peer: Dictionary = person.duplicate(); var box: VBoxContainer = _card(str(peer.nickname), "Nouvelle demande d’ami", true)
		box.add_child(_button("Accepter", func(): _post("/v1/friends/accept", {"user_id": peer.id}, "friends"), true))
		box.add_child(_button("Refuser", func(): _post("/v1/friends/remove", {"user_id": peer.id}, "friends")))
	for person: Dictionary in friends.get("friends", []):
		var peer: Dictionary = person.duplicate(); var box: VBoxContainer = _card(str(peer.nickname), "En ligne" if peer.get("online", false) else "Hors ligne", true)
		if not party.is_empty(): box.add_child(_button("Inviter dans mon groupe", func(): _post("/v1/parties/" + str(party.id) + "/invite", {"user_id": peer.id})))
		if peer.get("party_id") != null: box.add_child(_button("Rejoindre son groupe", func(): join_party(str(peer.party_id)), true))
		box.add_child(_button("Retirer de mes amis", func(): _post("/v1/friends/remove", {"user_id": peer.id}, "friends")))
	for person: Dictionary in friends.get("outgoing", []): content.add_child(_label("Demande en attente : " + str(person.nickname), 17, MUTED))
	if friends.get("friends", []).is_empty(): _card("Le couloir est encore calme", "Les amis apparaîtront ici après acceptation de leur demande.")
	content.add_child(_button("Actualiser les invitations", show_friends));_status("")

func join_party(party_id: String) -> void :
	await _post("/v1/parties/" + party_id + "/join", {}, "group")

func show_group() -> void :
	var epoch: int = _clear("group", "Votre groupe privé")
	if not _require_account(): return
	_status("Lecture du groupe…")
	var current: Dictionary = await client.api("/v1/parties/current")
	if epoch != _page_generation: return
	if current.has("error"): return
	if current.get("party") is Dictionary:
		var party: Dictionary = current.party
		var box: VBoxContainer = _card("Ensemble, jusqu’à la sortie", "Région : " + str(party.region) + "  ·  Carte : " + _map_name(str(party.config.map_id)))
		for member: Dictionary in party.members:
			var person_label: Label = _label(("★ " if str(member.id) == str(party.leader_id) else "• ") + str(member.nickname), 21);person_label.set_meta("language_user_text", true);box.add_child(person_label)
		content.add_child(_button("Inviter des amis", show_friends))
		if party.get("session") is Dictionary: content.add_child(_button("REJOINDRE LA PARTIE", func(): join_session(str(party.id)), true))
		elif str(party.leader_id) == str(client.profile.id):
			content.add_child(_button("Lancer le serveur régional", func():
				var result: Dictionary = await _post("/v1/parties/" + str(party.id) + "/start", {})
				if result.get("party") is Dictionary: join_session(str(party.id)), true))
			content.add_child(_button("Modifier les règles du groupe", func(): _show_rules(party)))
		else: _waiting_group = true;_card("En attente du chef de groupe", "Le bouton pour rejoindre apparaîtra lorsque le serveur sera prêt.")
		content.add_child(_button("Actualiser le groupe", show_group));content.add_child(_button("Quitter le groupe", func(): _post("/v1/parties/" + str(party.id) + "/leave", {}, "group")))
		_status("");return
	var response: Dictionary = await client.api("/v1/regions")
	if epoch != _page_generation: return
	if response.has("error"): content.add_child(_button("Réessayer", show_group));return
	_show_rules({}, response.get("regions", []));_status("")

func _map_name(id: String) -> String: return {"school": "École", "forest": "Forêt", "snow": "Forêt enneigée"}.get(id, id)

func _option(labels: Array) -> OptionButton:
	var option: OptionButton = OptionButton.new()
	option.custom_minimum_size.y = 48
	for label in labels: option.add_item(str(label))
	return option

func _show_rules(party: Dictionary, regions: Array = []) -> void :
	if not party.is_empty(): _clear("group_edit", "Les règles du groupe")
	var box: VBoxContainer = _card("Créer votre partie" if party.is_empty() else "Personnaliser la partie", "Un serveur dédié exécute la simulation. Les bots complètent l’équipe. Ordinateurs et Android rejoignent le même groupe.")
	var region: OptionButton = _option([]); var available: bool = not party.is_empty()
	if party.is_empty():
		for item: Dictionary in regions:
			var index: int = region.item_count;region.add_item(str(item.name) + ("" if item.available else " — indisponible"));region.set_item_metadata(index, item.id);region.set_item_disabled(index, not bool(item.available))
			if bool(item.available) and not available: region.select(index);available = true
		box.add_child(_label("Région du serveur", 17));box.add_child(region)
		if not available: box.add_child(_label("Aucune région n’est hébergée pour l’instant. Les parties régionales deviendront disponibles quand un administrateur déploiera le serveur.", 18, RED))
	var existing: Dictionary = party.get("config", {}); var options: Dictionary = existing.get("options", {})
	var maps: OptionButton = _option(["École", "Forêt", "Forêt enneigée"]);maps.select(maxi(0, ["school", "forest", "snow"].find(str(existing.get("map_id", "school")))));box.add_child(_label("Carte", 17));box.add_child(maps)
	var alice: OptionButton = _option(["Alice est un bot", "Alice : chef du groupe", "Alice : joueur au hasard", "Alice : malice"]);alice.select(maxi(0, ["bot", "host", "random", "malice"].find(str(options.get("killer_mode", "bot")))));box.add_child(_label("Rôle d’Alice", 17));box.add_child(alice)
	var count: OptionButton = _option(["2 survivants", "3 survivants", "4 survivants", "5 survivants", "6 survivants"]);count.select(clampi(int(options.get("survivors", 6)), 2, 6) - 2);box.add_child(count)
	var practice: CheckBox = CheckBox.new();practice.text = "Bac à sable / entraînement";practice.button_pressed = options.get("mode", "match") == "training";practice.custom_minimum_size.y = 50;practice.add_theme_color_override("font_color", INK);box.add_child(practice)
	var friends: CheckBox = CheckBox.new();friends.text = "Mes amis peuvent rejoindre sans invitation";friends.button_pressed = bool(options.get("friends_can_join", true));friends.custom_minimum_size.y = 50;friends.add_theme_color_override("font_color", INK);box.add_child(friends)
	for check_box in [practice, friends]:
		for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]: check_box.add_theme_color_override(color_name, INK)
	var save: Button = _button("Créer le groupe" if party.is_empty() else "Enregistrer les règles", func():
		var body: Dictionary = {"map_id": ["school", "forest", "snow"][maps.selected], "options": {"killer_mode": ["bot", "host", "random", "malice"][alice.selected], "survivors": count.selected + 2, "mode": "training" if practice.button_pressed else "match", "round_seconds": 320, "friends_can_join": friends.button_pressed}}
		if party.is_empty(): body["region"] = region.get_item_metadata(region.selected)
		await _post("/v1/parties" if party.is_empty() else "/v1/parties/" + str(party.id) + "/configure", body, "group"), true)
	save.disabled = not available;box.add_child(save)
	if not party.is_empty(): content.add_child(_button("Retour au groupe", show_group))

func join_session(party_id: String) -> void :
	if client.pending > 0: return
	_status("Connexion à la partie…")
	var reply: Dictionary = await client.api("/v1/parties/" + party_id)
	var session: Variant = reply.party.get("session") if reply.get("party") is Dictionary else null
	if not session is Dictionary: _status("Le serveur n’est pas prêt. Actualise le groupe.", true);return
	if world == null or world.get("service") == null or not world.service.has_method("join_session"): _status("La connexion au serveur n’est pas disponible dans cette version.", true);return
	close();world.service.join_session(client.service_url, session)

func _poll() -> void :
	if not visible or client.token.is_empty() or client.pending > 0 or _polling: return
	_polling = true; var epoch: int = _page_generation
	await client.refresh_profile()
	if epoch == _page_generation and not client.token.is_empty():
		var reply: Dictionary = await client.api("/v1/invites")
		var count: int = reply.get("invites", []).size();friends_button.text = "Amis (%d)" % count if count > 0 else "Amis"
		if _waiting_group and epoch == _page_generation:
			var current: Dictionary = await client.api("/v1/parties/current")
			if current.get("party") is Dictionary and current.party.get("session") is Dictionary: show_group()
	_polling = false
