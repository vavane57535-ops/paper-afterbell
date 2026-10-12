extends Node

# Test réseau local (deux instances) : choix précis d'Alice dans le salon et fin par forfait (blocus).
#   hôte   : godot --headless -- --tool test_network_alice --alice-role host   --alice-scenario client_alice --alice-port 28417
#   client : godot --headless -- --tool test_network_alice --alice-role client --alice-scenario client_alice --alice-port 28417
# Scénarios :
#   client_alice : l'hôte choisit le client comme Alice ; le client quitte en pleine manche → blocus chez l'hôte.
#   host_alice   : l'hôte se choisit lui-même ; il ferme la partie en pleine manche → blocus local chez le client.
#   lobby_reset  : l'hôte choisit le client, le client quitte le salon → le choix repasse en « aléatoire ».
#   bot_alice    : Alice IA ; le client (survivant) quitte en pleine manche → pas de blocus, la manche continue.
#   leader       : l'hôte se comporte en serveur dédié (dedicated) dont le client est chef de groupe : le chef
#                  choisit Alice et lance la manche par lobby_command ; il quitte ensuite → blocus côté serveur.
#   trio         : trois instances (rôles host, client, client2). L'hôte choisit « Client » comme Alice ; Alice
#                  quitte en pleine manche → blocus chez l'hôte ET chez l'autre client (client2), qui reste connecté.
#                  Puis client2 quitte pendant le film : l'hôte ne doit pas renvoyer la manche (film non relancé).
# Port dédié (pas le 27842 du jeu) pour ne pas gêner d'autres parties locales.

var world: Node
var role: String = "host"
var scenario: String = "client_alice"
var port: int = 28417
var clock: float = 0.0
var step: String = "start"
var step_clock: float = 0.0
var other: int = 0
var failures: Array[String] = []
var checks: int = 0
var tickets_before: int = -1
var done: bool = false
var fake_left: bool = false
var skipped_checked: bool = false


func setup(owner: Node) -> void :
	world = owner
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		var value: String = args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--alice-role": role = value
			"--alice-scenario": scenario = value
			"--alice-port": port = int(value)
	_begin.call_deferred()


func _log(text: String) -> void :
	print("NETTEST ", role, " ", text)


func _check(ok: bool, what: String) -> void :
	checks += 1
	_log(("OK   " if ok else "FAIL ") + what)
	if not ok: failures.append(what)


func _go(next: String) -> void :
	_log("step " + step + " -> " + next)
	step = next;step_clock = 0.0


func _begin() -> void :
	for i: int in range(4): await get_tree().process_frame
	world.leave_network()
	world.net = ENetMultiplayerPeer.new()
	if role == "host":
		var error: int = world.net.create_server(port, 6)
		if error != OK: _check(false, "ouverture du serveur sur le port %d" % port);_end();return
		world.multiplayer.multiplayer_peer = world.net;world.networked = true
		world.nickname = "Hote"
		world.roster = {1: {"name": "Hote", "character": "Simon", "malice": 0}}
		world.phase = "lobby";world.stage.visible = true;world.ui.show_lobby()
		_go("wait_client")
	else:
		world.nickname = "Client2" if role == "client2" else "Client";world.selected = "Elly" if role == "client2" else "Lysia"
		var error: int = world.net.create_client("127.0.0.1", port)
		if error != OK: _check(false, "connexion client");_end();return
		world.multiplayer.multiplayer_peer = world.net;world.networked = true;world.phase = "lobby";world.ui.show_lobby()
		_go("wait_roster")


func _badge_shown() -> bool:
	var list: Variant = world.ui.get("lobby_list")
	if not list is Node: return false
	for node: Node in (list as Node).find_children("*", "Label", true, false):
		if (node as Label).text == "ALICE": return true
	return false


func _process(delta: float) -> void :
	if done or world == null: return
	clock += delta;step_clock += delta
	if clock > 100.0:
		_check(false, "délai dépassé à l'étape " + step)
		_end();return
	if role == "host": _host()
	else: _client()


func _host() -> void :
	match step:
		"wait_client":
			if world.roster.size() < (3 if scenario == "trio" else 2): return
			for key: Variant in world.roster:
				if int(key) != 1 and (scenario != "trio" or str(world.roster[key].get("name", "")) == "Client"): other = int(key)
			if scenario == "leader":
				world.dedicated = true;world.lobby_leader = other;world._broadcast_roster()
				_go("leader_wait")
				return
			match scenario:
				"host_alice": world.set_alice_choice("player", 1)
				"bot_alice": world.set_alice_choice("bot", 0)
				_: world.set_alice_choice("player", other)
			var expected: int = 1 if scenario == "host_alice" else -1 if scenario == "bot_alice" else other
			_check(world.chosen_alice_peer() == expected, "hôte : Alice désignée = %d (attendu %d)" % [world.chosen_alice_peer(), expected])
			var choice: OptionButton = world.ui.get("lobby_alice")
			var meta: Variant = choice.get_item_metadata(choice.selected) if is_instance_valid(choice) and choice.selected >= 0 else null
			_check(meta is Array and (int(meta[1]) == expected or (expected == -1 and str(meta[0]) == "bot")), "hôte : le sélecteur affiche le choix " + str(meta))
			_check(expected <= 0 or _badge_shown(), "hôte : badge ALICE dans la liste des joueurs")
			_go("lobby_wait")
		"lobby_wait":
			if scenario == "lobby_reset":
				if world.roster.size() > 1 or step_clock < 0.5: return
				_check(str(world.room_options.killer_mode) == "random" and int(world.room_options.alice_peer) == 0, "hôte : choix réinitialisé après le départ (%s)" % str(world.room_options))
				_check(world.chosen_alice_peer() == 0 and not _badge_shown(), "hôte : plus de badge ALICE")
				_end();return
			if step_clock < 2.0: return
			world.start_multiplayer_round()
			_go("wait_play")
		"leader_wait":
			if world.phase == "loading" or world.phase == "playing":
				_check(str(world.room_options.killer_mode) == "player" and int(world.room_options.alice_peer) == other, "serveur : choix du chef reçu par lobby_command (%s)" % str(world.room_options))
				_go("wait_play")
			elif step_clock > 25.0: _check(false, "serveur : le chef n'a jamais lancé la manche");_end()
		"wait_play":
			if world.phase != "playing": return
			var alice: PaperActor = world.killer_actor()
			var expected: int = 1 if scenario == "host_alice" else 100 if scenario == "bot_alice" else other
			_check(alice != null and alice.id == expected, "hôte : la manche respecte le choix (Alice = acteur %s, attendu %d)" % [str(alice.id) if alice else "aucun", expected])
			tickets_before = world.tickets
			_go("playing")
		"playing":
			if scenario == "host_alice":
				if step_clock < 4.0: return
				_log("l'hôte (Alice) ferme la partie")
				world.quit_to_menu()
				_go("closing")
			elif scenario == "bot_alice":
				if world.roster.size() > 1:
					if step_clock > 20.0: _check(false, "hôte : le client n'est jamais parti");_end()
					return
				if step_clock < 3.0: return
				_check(world.phase == "playing", "hôte : un survivant qui part ne termine pas la manche (phase %s)" % world.phase)
				_check(world.ending_kind != PaperAliceForfeit.KIND, "hôte : pas de blocus avec une Alice IA")
				var alice: PaperActor = world.killer_actor()
				_check(alice != null and alice.bot and alice.id == 100, "hôte : l'Alice IA continue")
				_end()
			else:
				if world.phase != "ending":
					if step_clock > 25.0: _check(false, "hôte : aucune fin après le départ d'Alice");_end()
					return
				_check(world.outcome == "survivors", "hôte : victoire des survivants (outcome %s)" % world.outcome)
				_check(world.ending_kind == PaperAliceForfeit.KIND, "hôte : fin = blocus (%s)" % world.ending_kind)
				_check(world.film.kind == PaperAliceForfeit.KIND and is_instance_valid(world.film.blocus), "hôte : le film du blocus est lancé")
				_check(not world.ending_people.is_empty(), "hôte : distribution du blocus %s" % str(world.ending_people))
				_check(scenario == "leader" or world.tickets > tickets_before, "hôte : tickets gagnés (%d -> %d)" % [tickets_before, world.tickets])
				_check(not world.match_results.is_empty(), "hôte : résultats de manche (%d lignes)" % world.match_results.size())
				_check(str(world.room_options.killer_mode) == "random", "hôte : le choix d'Alice repasse en aléatoire (%s)" % str(world.room_options.killer_mode))
				_go("trio_wait" if scenario == "trio" else "watch_film")
		"trio_wait":
			# Un survivant bot « se déconnecte » pendant le film : l'hôte ne doit pas renvoyer toute la manche
			# (sinon client2, passé aux résultats, serait ramené dans le film).
			if step_clock >= 6.0 and not fake_left:
				fake_left = true
				for actor: PaperActor in world.actors.values():
					if actor.bot and not actor.killer and actor.id >= 100:
						_log("départ simulé du survivant %d pendant le film" % actor.id)
						world._peer_disconnected(actor.id)
						break
			# client2 regarde le blocus puis quitte pendant le film.
			if world.roster.size() > 1:
				if step_clock > 30.0: _check(false, "hôte : client2 n'est jamais parti");_end()
				return
			_check(world.phase == "ending" and world.film.kind == PaperAliceForfeit.KIND and world.film.elapsed > 3.0, "hôte : le blocus continue après le départ de client2 (%.1f s)" % world.film.elapsed)
			_end()
		"watch_film":
			if step_clock < 3.0: return
			_check(scenario == "leader" or (world.film.elapsed > 1.0 and world.phase == "ending"), "hôte : le film avance (%.1f s)" % world.film.elapsed)
			_end()
		"closing":
			if step_clock > 1.5: _end()


func _client() -> void :
	if role == "client2":
		_client2()
		return
	match step:
		"wait_roster":
			if not world.roster.has(world.local_id()): return
			if scenario == "leader":
				if world.lobby_leader != world.local_id():
					if step_clock > 15.0: _check(false, "client : jamais chef de groupe");_end()
					return
				world.ui.show_lobby()
				_check(world.can_manage_lobby() and is_instance_valid(world.ui.get("lobby_alice")), "chef : le sélecteur d'Alice est proposé")
				world.set_alice_choice("player", world.local_id())
				_go("leader_choice")
				return
			var expected: int = 1 if scenario == "host_alice" else -1 if scenario == "bot_alice" else world.local_id()
			if world.chosen_alice_peer() != expected:
				if step_clock > 15.0: _check(false, "client : choix d'Alice jamais reçu (%d)" % world.chosen_alice_peer());_end()
				return
			_check(true, "client : choix d'Alice synchronisé (%d)" % expected)
			_check(expected <= 0 or _badge_shown(), "client : badge ALICE affiché")
			_check(not world.can_manage_lobby() and not is_instance_valid(world.ui.get("lobby_alice")), "client : pas de sélecteur pour les autres joueurs")
			# Un client ne peut pas imposer son choix : l'appel est ignoré par l'hôte.
			world.set_alice_choice("bot", 0)
			_go("lobby")
		"leader_choice":
			if world.chosen_alice_peer() != world.local_id():
				if step_clock > 10.0: _check(false, "chef : choix jamais confirmé par le serveur");_end()
				return
			_check(_badge_shown(), "chef : choix confirmé, badge ALICE")
			world.start_multiplayer_round()
			_go("lobby")
		"lobby":
			if scenario == "lobby_reset":
				if step_clock < 1.0: return
				_log("le client quitte le salon")
				world.quit_to_menu()
				_go("closing")
				return
			if world.phase == "playing": _go("playing")
		"playing":
			if step_clock < 0.1: return
			if tickets_before < 0:
				var me: PaperActor = world.local_actor()
				var alice: PaperActor = world.killer_actor()
				var expected_alice: bool = scenario in ["client_alice", "leader", "trio"]
				_check(me != null and me.killer == expected_alice, "client : rôle reçu (Alice = %s)" % str(me.killer if me else "?"))
				if scenario == "host_alice": _check(alice != null and alice.id == 1, "client : l'hôte est Alice")
				tickets_before = world.tickets
			if scenario in ["client_alice", "bot_alice", "leader", "trio"]:
				if step_clock < 4.0: return
				_log("le client quitte la manche")
				world.quit_to_menu()
				_go("closing")
			else:
				if world.phase != "ending":
					if step_clock > 25.0: _check(false, "client : rien après le départ de l'hôte");_end()
					return
				_check(not world.networked, "client : déconnecté proprement")
				_check(world.outcome == "survivors" and world.ending_kind == PaperAliceForfeit.KIND, "client : blocus local (outcome %s, fin %s)" % [world.outcome, world.ending_kind])
				_check(world.film.kind == PaperAliceForfeit.KIND, "client : film du blocus lancé")
				_check(world.tickets > tickets_before, "client : tickets gagnés (%d -> %d)" % [tickets_before, world.tickets])
				_check(not world.match_results.is_empty(), "client : résultats (%d lignes)" % world.match_results.size())
				_go("watch_film")
		"watch_film":
			if step_clock < 3.0: return
			_check(world.film.elapsed > 1.0 and world.phase == "ending", "client : le film avance (%.1f s)" % world.film.elapsed)
			_end()
		"closing":
			if step_clock > 1.5: _end()


# Troisième instance (scénario trio) : survivante qui reste connectée quand Alice part.

func _client2() -> void :
	match step:
		"wait_roster":
			if not world.roster.has(world.local_id()): return
			var pick: int = world.chosen_alice_peer()
			if pick <= 1 or pick == world.local_id():
				if step_clock > 25.0: _check(false, "client2 : choix d'Alice jamais reçu (%d)" % pick);_end()
				return
			_check(_badge_shown(), "client2 : badge ALICE à côté de l'autre client")
			_go("lobby")
		"lobby":
			if world.phase == "playing": _go("playing")
			elif step_clock > 40.0: _check(false, "client2 : la manche ne démarre pas");_end()
		"playing":
			if tickets_before < 0:
				var me: PaperActor = world.local_actor()
				_check(me != null and not me.killer, "client2 : survivant")
				tickets_before = world.tickets
			if world.phase != "ending":
				if step_clock > 30.0: _check(false, "client2 : aucune fin après le départ d'Alice");_end()
				return
			_check(world.networked, "client2 : reste connecté à l'hôte")
			_check(world.outcome == "survivors" and world.ending_kind == PaperAliceForfeit.KIND, "client2 : blocus (outcome %s, fin %s)" % [world.outcome, world.ending_kind])
			_check(world.film.kind == PaperAliceForfeit.KIND and is_instance_valid(world.film.blocus), "client2 : film du blocus lancé")
			_check(not world.ending_people.is_empty() and not "Alice" in world.ending_people, "client2 : distribution %s" % str(world.ending_people))
			_check(world.tickets > tickets_before, "client2 : tickets gagnés (%d -> %d)" % [tickets_before, world.tickets])
			_check(not world.match_results.is_empty(), "client2 : résultats (%d lignes)" % world.match_results.size())
			_check(str(world.audio.active_track) == "blocus" or world.audio.get("_silent") == true, "client2 : musique du blocus (%s)" % str(world.audio.active_track))
			_go("watch_film")
		"watch_film":
			if step_clock < 3.0: return
			_check(world.film.elapsed > 1.0 and world.phase == "ending" and world.ending_kind == PaperAliceForfeit.KIND, "client2 : le film avance (%.1f s)" % world.film.elapsed)
			# Le bouton PASSER mène aux résultats, sans que l'hôte ne nous ramène dans le film.
			var overlay: Variant = world.film.blocus.overlay if is_instance_valid(world.film.blocus) else null
			_check(overlay != null and is_instance_valid(overlay._skip), "client2 : bouton PASSER présent")
			if overlay: overlay.skip()
			_go("skipped")
		"skipped":
			if step_clock < 1.0: return
			if not skipped_checked:
				skipped_checked = true
				_check(world.ending_presented and world.ui.current_page == "ending", "client2 : écran de résultats après PASSER (%s)" % str(world.ui.current_page))
			# L'hôte simule un départ pendant son film (vers +6 s) : on doit rester sur les résultats.
			if step_clock < 5.5: return
			_check(world.ending_presented and world.ui.current_page == "ending" and world.phase == "ending", "client2 : toujours sur les résultats après un départ pendant le film (%s)" % str(world.ui.current_page))
			_log("client2 quitte pendant le film")
			world.quit_to_menu()
			_go("closing")
		"closing":
			if step_clock > 1.5: _end()


func _end() -> void :
	if done: return
	done = true
	print("NETTEST_RESULT ", role, " ", scenario, " ", "PASS" if failures.is_empty() else "FAIL", " checks=", checks, " failures=", failures)
	await get_tree().create_timer(0.3).timeout
	get_tree().quit(0 if failures.is_empty() else 1)
