class_name PaperOnlineService
extends Node

var world: Node
var base_url: String = ""
var session_id: String = ""
var join_ticket: String = ""
var regional: bool = false
var authenticated: Dictionary = {}
var pending: Dictionary = {}
var _server_key: String = ""
var _args: Dictionary = {}
var _empty_seconds: float = 0.0

func _process(delta: float) -> void :
	if not world or not world.dedicated or not world.networked: return
	_empty_seconds = _empty_seconds + delta if authenticated.is_empty() and pending.is_empty() else 0.0

	if _empty_seconds >= 180.0: get_tree().quit()

func setup(owner: Node) -> void :
	world = owner
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--"):
			var pair: PackedStringArray = argument.trim_prefix("--").split("=", true, 1);_args[pair[0]] = pair[1] if pair.size() > 1 else "true"
	base_url = str(_args.get("service-url", "")).trim_suffix("/");session_id = str(_args.get("session-id", ""));join_ticket = str(_args.get("join-ticket", ""))
	if _args.has("dedicated"): _start_dedicated.call_deferred()
	elif _args.has("server-host"): _join.call_deferred()

func _valid_service() -> bool:
	return base_url.begins_with("https://") or base_url.begins_with("http://127.0.0.1:") or base_url.begins_with("http://localhost:")

func _start_dedicated() -> void :
	_server_key = OS.get_environment("PAPER_SERVER_KEY")
	if not _valid_service() or _server_key.length() < 24 or session_id.is_empty():
		push_error("Dedicated server: missing trusted service configuration.");get_tree().quit(2);return
	var file: String = str(_args.get("room-config", ""))
	var config: Variant = JSON.parse_string(FileAccess.get_file_as_string(file)) if FileAccess.file_exists(file) else null
	if not config is Dictionary or str(config.get("session_id", "")) != session_id: push_error("Dedicated server: invalid room config.");get_tree().quit(2);return
	world.leave_network();world.dedicated = true;regional = true;world.lobby_leader = -1
	world.room_options = world._clean_room_options(config.get("options", {}));world.ruleset = "om"
	world._rebuild_map(str(config.get("map_id", "school")))
	world.net = ENetMultiplayerPeer.new()
	var error: int = world.net.create_server(clampi(int(_args.get("port", 27842)), 1024, 65535), 7)
	if error != OK: push_error("Dedicated server: UDP port unavailable.");get_tree().quit(3);return
	world.multiplayer.multiplayer_peer = world.net;world.networked = true;world.online_room = false;world.roster.clear();world.phase = "lobby";world.stage.hide();world.ui.root.hide()
	print("DEDICATED_READY session=", session_id, " port=", int(_args.get("port", 27842)))

func _join() -> void :
	if not _valid_service() or join_ticket.is_empty(): world.ui.toast("Invitation invalide. Rejoins la partie depuis le launcher.", 8);return
	world.leave_network();regional = true;world.net = ENetMultiplayerPeer.new()
	var error: int = world.net.create_client(str(_args.get("server-host", "")), clampi(int(_args.get("server-port", 27842)), 1024, 65535))
	if error != OK: world.ui.toast("Le serveur régional est indisponible.", 8);return
	world.multiplayer.multiplayer_peer = world.net;world.networked = true;world.phase = "lobby";world.ui.show_connecting();world.ui.network_status("Connexion au serveur régional…")
	var peer: ENetMultiplayerPeer = world.net
	get_tree().create_timer(15).timeout.connect( func():
		if world.net == peer and world.roster.is_empty(): world._connection_failed())

func join_session(service_url: String, session: Dictionary) -> void :
	base_url = service_url.trim_suffix("/");session_id = str(session.get("id", session.get("session_id", "")));join_ticket = str(session.get("ticket", ""))
	_args["server-host"] = str(session.get("host", ""));_args["server-port"] = int(session.get("port", 27842))
	_join()

func authenticate_peer(peer: int, _name: String, character: String, ticket: String) -> void :
	if not world.dedicated or authenticated.has(peer) or pending.has(peer): return
	if ticket.length() < 20 or ticket.length() > 256 or pending.size() >= 7: _deny(peer);return
	pending[peer] = true
	var response: Dictionary = await _request("/v1/sessions/claim", {"session_id": session_id, "ticket": ticket})
	pending.erase(peer)
	if not world.multiplayer.get_peers().has(peer): return
	var data: Dictionary = response.get("data", {})
	if int(response.get("status", 0)) != 200 or not data.get("user") is Dictionary or str(data.get("session", {}).get("session_id", "")) != session_id: _deny(peer);return
	var user: Dictionary = data.user
	if str(user.get("id", "")).is_empty(): _deny(peer);return
	for existing: Dictionary in authenticated.values():
		if str(existing.id) == str(user.id): _deny(peer);return
	authenticated[peer] = user
	if str(data.get("party_role", "")) == "leader": world.lobby_leader = peer
	world._register_verified(peer, str(user.get("nickname", "Élève")), character)
	world._broadcast_roster()

func _deny(peer: int) -> void :
	if world.multiplayer.get_peers().has(peer):
		world.selection_notice.rpc_id(peer, "Invitation expirée ou invalide. Rejoins ton groupe depuis le launcher.")
		get_tree().create_timer(0.3).timeout.connect( func():
			if world.net and world.multiplayer.get_peers().has(peer): world.net.disconnect_peer(peer))

func submit_results(results: Array, escapes: Array, winners: Array = []) -> void :
	if not world.dedicated: return
	var rows: Array = []
	for result: Dictionary in results:
		var actor_id: int = int(result.get("id", result.get("actor_id", -1)))
		if not authenticated.has(actor_id): continue
		var metrics: Dictionary = result.get("breakdown", {})
		rows.append({"user_id": authenticated[actor_id].id, "stats": {"matches": 1, "wins": 1 if escapes.has(actor_id) or winners.has(actor_id) else 0, "escapes": 1 if escapes.has(actor_id) else 0, "points": maxi(0, int(result.get("points", 0))), "stuns": maxi(0, int(metrics.get("stun", 0))), "heals": maxi(0, int(metrics.get("heal", 0))), "boosts": maxi(0, int(metrics.get("boost", 0))), "danger_seconds": maxi(0, int(metrics.get("danger", 0)))}})
	var alice: PaperActor = world.killer_actor()
	if alice and authenticated.has(alice.id): rows.append({"user_id": authenticated[alice.id].id, "stats": {"matches": 1, "wins": 1 if world.outcome == "killer" else 0, "points": 0, "stuns": 0, "heals": 0, "boosts": 0, "danger_seconds": 0, "escapes": 0}})
	if rows.is_empty(): return
	var response: Dictionary = await _request("/v1/sessions/result", {"session_id": session_id, "round_id": session_id + ":" + str(world.round_serial), "results": rows})
	if int(response.get("status", 0)) not in [200, 201]: push_warning("Player statistics could not be saved to the service.")

func _request(path: String, data: Dictionary) -> Dictionary:
	var request: HTTPRequest = HTTPRequest.new();request.timeout = 10;add_child(request)
	var headers: PackedStringArray = ["Content-Type: application/json", "X-Server-Key: " + _server_key]
	var error: int = request.request(base_url + path, headers, HTTPClient.METHOD_POST, JSON.stringify(data))
	if error != OK: request.queue_free();return {"status": 0}
	var response: Array = await request.request_completed
	request.queue_free()
	var decoded: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	return {"status": int(response[1]), "data": decoded if decoded is Dictionary else {}}
