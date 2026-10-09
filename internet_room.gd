class_name PaperInternetRoom
extends Node

signal peer_ready(peer: ENetMultiplayerPeer, hosting: bool)
signal failed(message: String)
signal status_changed(message: String)
const DEFAULT_HOST: String = "tomfol.io"
var relay_host: String = DEFAULT_HOST
var code: String = ""
var route: String = ""
var hosting: bool = false
var busy: bool = false
var force_relay: bool = false
var _generation: int = 0
var _noray: Node
var _handshake: Node
var _server: ENetMultiplayerPeer
var _target: String = ""
var _connecting: bool = false
var _relay_requested: bool = false

func _ready() -> void :
	NetfoxLogger.module_log_level["netfox.noray"] = NetfoxLogger.LOG_WARN
	_handshake = preload("res://addons/netfox.noray/packet-handshake.gd").new();add_child(_handshake)

func cancel() -> void :
	_generation += 1;busy = false;_connecting = false;code = "";route = "";_server = null
	if is_instance_valid(_noray):
		_noray.disconnect_from_host();_noray.queue_free();_noray = null

func open_room(as_host: bool, room_code: String = "") -> void :
	cancel();hosting = as_host;busy = true;_target = room_code.strip_edges();_relay_requested = false
	var generation: int = _generation
	_noray = preload("res://addons/netfox.noray/noray.gd").new();add_child(_noray)
	_noray.on_connect_nat.connect( func(address: String, port: int): _connect_peer(address, port, false, generation))
	_noray.on_connect_relay.connect( func(address: String, port: int): _connect_peer(address, port, true, generation))
	status_changed.emit("Connexion au service de salons…")
	var error: int = await _noray.connect_to_host(relay_host, 8890)
	if generation != _generation: return
	if error != OK: _fail("Le service de salons est indisponible. Réessaie dans un instant.");return
	_noray.register_host()
	var deadline: int = Time.get_ticks_msec() + 7000
	while _noray.pid.is_empty() or _noray.oid.is_empty():
		await get_tree().process_frame
		if generation != _generation: return
		if Time.get_ticks_msec() > deadline: _fail("Le service ne répond pas à la création du salon.");return
	status_changed.emit("Vérification de la connexion Internet…")
	error = await _noray.register_remote()
	if generation != _generation: return
	if error != OK: _fail("La connexion UDP est bloquée. Vérifie que Paper Afterbell est autorisé dans le pare-feu.");return
	if hosting:
		_server = ENetMultiplayerPeer.new()
		error = _server.create_server(_noray.local_port, 6)
		if error != OK: _fail("Impossible d'ouvrir le salon sur ce PC.");return
		code = _noray.oid;route = "Internet";busy = false
		peer_ready.emit(_server, true)
	else:
		code = _target
		if force_relay: _request_relay()
		else:
			status_changed.emit("Recherche du salon…")
			_noray.connect_nat(_target)
			get_tree().create_timer(10).timeout.connect( func():
				if generation == _generation and busy and not _relay_requested and not _connecting: _request_relay())
		get_tree().create_timer(30).timeout.connect( func():
			if generation == _generation and busy: _fail("Salon introuvable ou fermé. Vérifie le code envoyé par l'hôte."))

func _request_relay() -> void :
	if not is_instance_valid(_noray) or _relay_requested: return
	_relay_requested = true
	status_changed.emit("Connexion par le relais Internet…")
	_noray.connect_relay(_target)

func _connect_peer(address: String, port: int, relayed: bool, generation: int) -> void :
	if generation != _generation: return
	if hosting:
		if _server: await _handshake.over_enet_peer(_server, address, port)
		return
	if _connecting or not busy: return
	if not relayed and _relay_requested: return
	_connecting = true
	var udp: PacketPeerUDP = PacketPeerUDP.new()
	if udp.bind(_noray.local_port) != OK:
		_connecting = false;_fail("Le port de connexion n'est plus disponible.");return
	udp.set_dest_address(address, port)
	var error: int = await _handshake.over_packet_peer(udp, 7.0, 0.1, func(): return generation != _generation)
	udp.close()
	if generation != _generation: return
	_connecting = false
	if error != OK and error != ERR_BUSY:
		if not relayed: _request_relay()
		else: _fail("Le relais ne répond pas. Réessaie ou vérifie ton pare-feu.")
		return
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	error = peer.create_client(address, port, 0, 0, 0, _noray.local_port)
	if error != OK: _fail("Impossible de rejoindre ce salon.");return
	route = "Relais Internet" if relayed else "Internet direct"
	busy = false;peer_ready.emit(peer, false)

func _fail(message: String) -> void :
	cancel();failed.emit(message)
