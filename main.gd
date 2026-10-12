extends Node3D

const MapAtmosphere = preload("res://map_atmosphere.gd")
const CoreCameraRig = preload("res://core_camera_rig.gd")
const CoreMenuStage = preload("res://core_menu_stage.gd")
const CoreArchives = preload("res://core_archives.gd")
const CorePerf = preload("res://core_perf.gd")
const PrologueFilm = preload("res://film_intro_yiero.gd")
const ExitAlarm = preload("res://exit_alarm.gd")
const KillScenes = preload("res://kill_scenes.gd")
const PORT: int = 27842

const PITCH_MIN: float = CoreCameraRig.PITCH_MIN
const PITCH_MAX: float = CoreCameraRig.PITCH_MAX


const CHASE_ENTER_DISTANCE: float = 14.0
const CHASE_EXIT_DISTANCE: float = 22.0
const CHASE_RELEASE_TIME: float = 3.0

const FPS_LIMITS: Array[int] = [0, 30, 60, 120, 144, 240]
var actors: Dictionary = {}
var school: PaperSchool
var combat: PaperCombat
var brain: PaperBrain
var rewards: PaperMatchRewards
var match_results: Array = []
var emote_wheel: PaperEmoteWheel
var emote_sync: PaperEmoteSync
var bindings: PaperBindings
var controls_menu: PaperControlsMenu
var exit_flow: PaperEscapeFlow
var map_interactables: PaperMapInteractables
var exit_alarm: Node
var teleport_warning: float = 0.0
var warning_lamps: Array[Light3D] = []
var warning_energies: Array[float] = []
var dedicated: bool = false
var lobby_leader: int = 1
var service: PaperOnlineService
var online_menu: PaperOnlineMenu
var options: Dictionary = {"language": "fr", "graphics": "high", "reduce_flashes": false, "colorblind": false, "camera_smooth": true, "fullscreen": false, "vsync": true, "fps_limit": 0, "render_scale": 1.0, "show_fps": false, "fov": 72.0, "camera_shake": true, "fx_words": true, "screen_fx": true}
var accessibility_layer: CanvasLayer
var camera_anchor: Vector3 = Vector3.ZERO
var camera_anchor_ready: bool = false
var ui: PaperUI
var audio: PaperAudio
var clock: float = 0.0
var time_left: float = 320.0
var phase: String = "menu"
var lms: bool = false
var drones: Array[Dictionary] = []
var training: bool = false
var practice: PaperTraining
var zones: Array[Dictionary] = []
var minions: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var presentation: PaperEffects
var reveals: PaperRevealController
var loading_ready: Dictionary = {}
var loading_remote_count: int = 1
var archive_locks: Dictionary = {}
var film: PaperCinema
var kill_scenes: KillScenes
var gallery: PaperGallery
var prologue: PrologueFilm
var intro_seen: bool = false
var _prologue_map: String = ""
var ending_people: Array = []
var ending_focus: String = "Ashura"
var ending_kind: String = "ending_survivors"
var last_victim_name: String = ""
var ending_presented: bool = false
var preview_character: String = ""
var preview_angle: float = 0.0


var menu_focus_x: float = 0.64
var menu_stage: CoreMenuStage
var camera_rig: CoreCameraRig
var archives: CoreArchives
var perf: CorePerf = CorePerf.new()
var _poses: Dictionary = {}
var _snapshot_rows: Array = []
var _chase_active: bool = false
var _chase_release: float = 0.0
var _audio_heartbeat: bool = false
var _audio_hurt: bool = false
var _capture_pose: Array = []
var _fullscreen_from_cmdline: bool = false
var _perf_snapshot_clock: float = 0.0
var _zone_signature: int = 0
var _test_orbit: bool = false
var _snapshot_raw_size: int = 0
const SURVIVOR_INTRO_DURATION: float = 7.0
const INTRO_DURATION: float = 2.4
var blocked_door: int = -1
var objective_progress: Dictionary = {}
var objective_done: Array[int] = []
var objective_nodes: Array[Node3D] = []
var camera: Camera3D
var net: ENetMultiplayerPeer
var networked: bool = false
var internet: PaperInternetRoom
var online_room: bool = false
var room_options: Dictionary = {"mode": "match", "killer_mode": "malice", "alice_peer": 0, "survivors": 6, "round_seconds": 320, "ruleset": "om"}
var roster: Dictionary = {}
var nickname: String = "Élève"
var selected: String = "Ashura"

var tickets: int = PaperDances.STARTING_TICKETS
var owned_dances: Array = []
var _dance_players: Dictionary = {}
var solo_killer: bool = false
var pause_open: bool = false
var yaw: float = 0.0
var pitch: float = -0.16
var sensitivity: float = 0.0025
var cinema: float = 0.0
var menu_time: float = 0.0
var input_clock: float = 0.0
var snapshot_clock: float = 0.0
var interact_clock: float = 0.0
var outcome: String = ""
var spectate_id: int = -1
var stage: Node3D
var barrier: StaticBody3D
var door_history: Dictionary = {}
var fx: Node3D
var zone_nodes: Array[MeshInstance3D] = []
var previous_positions: Dictionary = {}
var event_count: Dictionary = {}
var test_mode: bool = false
var test_duration: float = 0
var test_elapsed: float = 0
var test_report: String = ""
var capture_path: String = ""
var capture_at: float = 3.0
var test_started: bool = false
var test_character: String = ""
var test_client: bool = false
var test_host: bool = false
var messages_received: int = 0
var stage_models: Array[PaperVisual] = []
var request_times: Dictionary = {}
var effects_clock: float = 0.0
var round_serial: int = 0
var test_scenario: String = ""
var scenario_started: bool = false
var input_packets: int = 0
var remote_actions: int = 0
var test_action_clock: float = 0.0
var world_state_clock: float = 0.0
var selected_map: String = "school"
var environment: Environment
var objective_seconds_removed: float = 0.0
var camera_shake: float = 0.0
var camera_obscured_actor: PaperActor
var mobile_mode: bool = false
var mobile_focused: bool = true
var mobile_controls: PaperMobileControls
var mobile_quality: PaperMobileQuality
var touch_sensitivity: float = 0.0036
var mobile_profile: String = "balanced"
var ruleset: String = "om"
var round_preparing: bool = false
var ping_ms: float = -1.0
var _ping_timer: float = 0.0
var _ping_sequence: int = 0
var _ping_pending: Dictionary = {}
var _ping_last_reply: int = 0
const MAP_NAMES: Dictionary = {"school": "L'école après la cloche", "forest": "La forêt des murmures", "snow": "Le silence de l'hiver"}

func _ready() -> void :


	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	dedicated = "--dedicated" in OS.get_cmdline_user_args()
	_fullscreen_from_cmdline = "--fullscreen" in OS.get_cmdline_args() or "-f" in OS.get_cmdline_args()
	mobile_mode = OS.has_feature("android") or "--mobile-test" in OS.get_cmdline_user_args() or "--mobile-preview" in OS.get_cmdline_user_args()
	if mobile_mode:
		get_window().content_scale_size = Vector2i(1280, 720)
		get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		get_tree().auto_accept_quit = false
	_load_preferences()
	_build_inputs()
	school = PaperSchool.new();add_child(school);school.build(selected_map, ruleset)
	exit_flow = PaperEscapeFlow.new(self)
	_build_map_interactables()
	var environment_node: WorldEnvironment = WorldEnvironment.new();environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR;environment.background_color = Color("151b29")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color = Color("adb8ca");environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment;add_child(environment_node)
	fx = Node3D.new();fx.name = "Effects";add_child(fx)
	combat = PaperCombat.new(self);brain = PaperBrain.new(self);practice = PaperTraining.new(self);rewards = PaperMatchRewards.new(self)
	camera = Camera3D.new();camera.name = "Camera";camera.fov = 72;camera.near = 0.08;camera.far = 340;add_child(camera);camera.current = true
	camera_rig = CoreCameraRig.new()
	camera_rig.setup(self, camera)
	audio = PaperAudio.new();add_child(audio);audio.setup()
	_audio_heartbeat = audio.has_method("set_heartbeat")
	_audio_hurt = audio.has_method("set_hurt")
	ui = PaperUI.new();add_child(ui);ui.setup(self)
	emote_wheel = PaperEmoteWheel.new();ui.root.add_child(emote_wheel);emote_wheel.setup(self)
	emote_sync = PaperEmoteSync.new();add_child(emote_sync);emote_sync.setup(self)
	controls_menu = PaperControlsMenu.new();ui.root.add_child(controls_menu);controls_menu.setup(self)
	online_menu = PaperOnlineMenu.new();ui.root.add_child(online_menu);online_menu.setup(self)
	presentation = PaperEffects.new();add_child(presentation);presentation.setup(self)
	reveals = PaperRevealController.new();add_child(reveals);reveals.setup(self)
	var survivor_fx: PaperSurvivorFx = PaperSurvivorFx.new();add_child(survivor_fx);survivor_fx.setup(self)
	film = PaperCinema.new();add_child(film);film.setup(self)
	if not dedicated: prologue = PrologueFilm.new();add_child(prologue);prologue.setup_prologue(self)
	if not dedicated: exit_alarm = ExitAlarm.new();add_child(exit_alarm);exit_alarm.setup(self)
	kill_scenes = KillScenes.new();add_child(kill_scenes);kill_scenes.setup(self)
	gallery = PaperGallery.new(self)
	_build_objectives()
	_build_stage()
	_map_atmosphere()
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_server_disconnected)
	internet = PaperInternetRoom.new();add_child(internet)
	internet.peer_ready.connect(_internet_ready)
	internet.failed.connect( func(message: String):
		leave_network();phase = "menu";ui.show_network();ui.toast(message, 10))
	internet.status_changed.connect( func(message: String): ui.network_status(message))
	if mobile_mode:
		mobile_controls = PaperMobileControls.new();ui.root.add_child(mobile_controls);mobile_controls.setup(self)
		mobile_controls.pause_requested.connect(mobile_pause)
		mobile_controls.training_requested.connect(mobile_training)
		mobile_controls.spectate_requested.connect(mobile_spectate)
		mobile_controls.cancel_aim_requested.connect(request_cancel_aim)
		ui.apply_mobile_layout()
	mobile_quality = PaperMobileQuality.new();add_child(mobile_quality);mobile_quality.setup(self)

	get_viewport().size_changed.connect(_apply_render_scale)
	_build_accessibility()
	apply_options()
	ui.show_main()
	service = PaperOnlineService.new();add_child(service);service.setup(self)
	_parse_test_args()
	if _prologue_wanted(): play_prologue()
	print("AFTERBELL_READY actors=0 objectives=", school.objectives.size(), " doors=", school.doors.size())

func _build_inputs() -> void :
	bindings = PaperBindings.new();bindings.setup()

func _load_preferences() -> void :
	var c: ConfigFile = ConfigFile.new()
	if c.load("user://settings.cfg") == OK:
		for key: String in options: options[key] = c.get_value("options", key, options[key])
		nickname = str(c.get_value("player", "name", "Élève"))
		selected = str(c.get_value("player", "character", "Ashura"))
		selected_map = str(c.get_value("player", "map", "school"))
		ruleset = "om"
		sensitivity = float(c.get_value("settings", "sensitivity", 0.0025))
		mobile_profile = str(c.get_value("settings", "mobile_profile", "balanced"))
		touch_sensitivity = clampf(float(c.get_value("settings", "touch_sensitivity", 0.0036)), 0.001, 0.009)
		tickets = maxi(0, int(c.get_value("shop", "tickets", PaperDances.STARTING_TICKETS)))
		owned_dances = Array(c.get_value("shop", "owned", [])).filter( func(id: Variant) -> bool: return not PaperDances.info(str(id)).is_empty())
		intro_seen = bool(c.get_value("story", "intro_seen", false))
	if not PaperData.NAMES.has(selected): selected = "Ashura"
	if not MAP_NAMES.has(selected_map): selected_map = "school"
	room_options["ruleset"] = ruleset
	_sanitize_options()


func _sanitize_options() -> void :
	options["fullscreen"] = bool(options.get("fullscreen", false))
	options["vsync"] = bool(options.get("vsync", true))
	var limit: int = int(options.get("fps_limit", 0))
	options["fps_limit"] = 0 if limit <= 0 else clampi(limit, 30, 360)
	options["render_scale"] = clampf(float(options.get("render_scale", 1.0)), 0.5, 1.0)
	options["show_fps"] = bool(options.get("show_fps", false))
	options["fov"] = clampf(float(options.get("fov", 72.0)), 60.0, 95.0)
	options["camera_shake"] = bool(options.get("camera_shake", true))
	options["fx_words"] = bool(options.get("fx_words", true))
	options["screen_fx"] = bool(options.get("screen_fx", true))

func save_preferences() -> void :
	var c: ConfigFile = ConfigFile.new()
	c.set_value("player", "name", nickname);c.set_value("player", "character", selected);c.set_value("settings", "sensitivity", sensitivity)
	c.set_value("player", "map", selected_map)
	c.set_value("player", "ruleset", ruleset)
	c.set_value("settings", "touch_sensitivity", touch_sensitivity)
	c.set_value("settings", "mobile_profile", mobile_profile)
	c.set_value("shop", "tickets", tickets);c.set_value("shop", "owned", owned_dances)
	c.set_value("story", "intro_seen", intro_seen)
	for key: String in options: c.set_value("options", key, options[key])
	if camera_rig: camera_rig.save_settings(c)
	if audio: c.set_value("audio", "music", audio.music_volume);c.set_value("audio", "muted", audio.muted);c.set_value("audio", "effects", audio.effects_volume)
	if audio: c.set_value("audio", "master", audio.master_volume)
	c.save("user://settings.cfg")

func can_manage_lobby() -> bool:
	return authoritative() or (networked and local_id() == lobby_leader)

@rpc("any_peer", "call_remote", "reliable")
func lobby_command(kind: String, data: Dictionary) -> void :
	if not dedicated or not authoritative() or multiplayer.get_remote_sender_id() != lobby_leader: return
	if kind == "rematch" and phase == "ending": return_to_lobby();return
	if phase != "lobby": return
	if kind == "start": start_multiplayer_round()
	elif kind == "map": select_map(str(data.get("map", "")))
	elif kind == "option" and str(data.get("key", "")) in ["mode", "killer_mode", "survivors", "round_seconds"]: set_room_option(str(data.key), data.get("value"))
	elif kind == "alice": set_alice_choice(str(data.get("mode", "")), _peer_value(data.get("peer", 0)))

func _build_map_interactables() -> void :
	if is_instance_valid(map_interactables): map_interactables.queue_free()
	map_interactables = PaperMapInteractables.new();school.add_child(map_interactables);map_interactables.build(school)


	PaperToon.apply_tree(school, false)
	warning_lamps.clear();warning_energies.clear()
	for node: Node in school.find_children("*", "Light3D", true, false):
		if node is OmniLight3D: warning_lamps.append(node);warning_energies.append(node.light_energy)

func _restore_warning_lamps() -> void :
	for index: int in range(warning_lamps.size()):
		if is_instance_valid(warning_lamps[index]): warning_lamps[index].light_energy = warning_energies[index]

func _update_teleport_warning(delta: float) -> void :
	if teleport_warning <= 0: return
	teleport_warning = maxf(0, teleport_warning - delta)
	if teleport_warning <= 0: _restore_warning_lamps();return
	var factor: float = 0.73 if bool(options.reduce_flashes) else 0.36 + 0.64 * smoothstep( - 0.4, 0.75, sin(teleport_warning * 14))
	for index: int in range(warning_lamps.size()):
		if is_instance_valid(warning_lamps[index]): warning_lamps[index].light_energy = warning_energies[index] * factor


func _build_stage() -> void :
	menu_stage = CoreMenuStage.new()
	var base: Vector3 = school.menu_spawn + Vector3.UP * 0.05
	stage = menu_stage.build(self, base, not mobile_mode)
	stage_models.clear()
	for visual: PaperVisual in menu_stage.models: stage_models.append(visual)


func _build_objectives() -> void :
	if not archives: archives = CoreArchives.new()
	var center: Vector3 = Vector3.ZERO
	for point: Vector3 in school.objectives: center += point
	if not school.objectives.is_empty(): center /= float(school.objectives.size())
	objective_nodes.clear()
	for node: Node3D in archives.build(self, school.objectives, center): objective_nodes.append(node)


func _ring(radius: float, color: Color) -> MeshInstance3D:
	var m: MeshInstance3D = MeshInstance3D.new(); var mesh: TorusMesh = TorusMesh.new();mesh.inner_radius = radius - 0.035;mesh.outer_radius = radius + 0.035;mesh.rings = 32;mesh.ring_segments = 6;m.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new();mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color = color;mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA;m.material_override = mat
	return m

func authoritative() -> bool:
	return not networked or multiplayer.is_server()

func local_id() -> int:
	return multiplayer.get_unique_id() if networked else 1

func local_actor() -> PaperActor:
	return actors.get(local_id()) as PaperActor

func killer_actor() -> PaperActor:

	for key: Variant in actors:
		var a: PaperActor = actors[key]
		if a.killer and a.alive: return a
	return null

func living_survivors() -> Array[PaperActor]:
	var result: Array[PaperActor] = []
	for a: PaperActor in actors.values():
		if a.alive and not a.killer: result.append(a)
	return result

func visible(from: Vector3, to: Vector3) -> bool:
	if not is_inside_tree(): return false
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from + Vector3.UP * 1.1, to + Vector3.UP * 1.1, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func nearest_ally(actor: PaperActor, reach: float, injured_only: bool = false) -> PaperActor:
	var found: PaperActor = null
	var best: float = INF
	for a: PaperActor in actors.values():
		if a == actor or not a.alive or a.killer: continue
		if injured_only and a.hp >= a.max_hp: continue
		var d: float = actor.position.distance_to(a.position)
		if d > reach or not visible(actor.position, a.position): continue
		var score: float = d + maxf(0.0, 1.0 - actor.aim.dot((a.position - actor.position).normalized())) * 2.0
		if score < best: found = a;best = score
	return found

func start_solo(as_killer: bool) -> void :
	if phase == "loading": return
	leave_network()
	_clear_round();round_preparing = true
	solo_killer = as_killer
	roster = {1: {"name": nickname, "character": selected, "malice": 0}}
	phase = "loading";ui.show_loading(selected_map, ["Alice"] if as_killer else [selected])
	await get_tree().process_frame
	await get_tree().process_frame
	if phase != "loading": return
	_start_round(1 if as_killer else -1)

func host_room() -> void :
	leave_network();online_room = true
	ui.show_connecting();internet.open_room(true)

func join_room(room_code: String) -> void :
	room_code = room_code.strip_edges()
	if room_code.is_empty() or room_code.length() > 128 or " " in room_code or "\n" in room_code:
		ui.toast("Colle le code du salon envoyé par l'hôte.");return
	leave_network();online_room = true
	ui.show_connecting();internet.open_room(false, room_code)

func _internet_ready(peer: ENetMultiplayerPeer, hosting: bool) -> void :
	net = peer;multiplayer.multiplayer_peer = net;networked = true;phase = "lobby";stage.visible = true
	if hosting: roster = {1: {"name": nickname, "character": selected, "malice": 0}}
	ui.show_lobby()
	if not hosting:
		var active_peer: ENetMultiplayerPeer = net
		get_tree().create_timer(12).timeout.connect( func():
			if net == active_peer and networked and roster.is_empty(): _connection_failed())

func set_room_option(key: String, value: Variant) -> void :
	if networked and not authoritative():
		if can_manage_lobby(): lobby_command.rpc_id(1, "option", {"key": key, "value": value})
		return
	if not authoritative() or phase != "lobby": return
	var updated: Dictionary = room_options.duplicate();updated[key] = value
	room_options = _clean_room_options(updated)
	var next_ruleset: String = str(room_options.ruleset)
	if ruleset != next_ruleset: ruleset = next_ruleset;_rebuild_map("school" if room_options.mode == "training" else selected_map);save_preferences()
	if room_options.mode == "training" and selected_map != "school": _rebuild_map("school")
	_broadcast_roster();ui.show_lobby()

func _clean_room_options(options: Dictionary) -> Dictionary:
	var mode: String = str(options.get("killer_mode", "malice"))
	if not mode in ["malice", "bot", "host", "random", "player"]: mode = "malice"
	var pick: int = _peer_value(options.get("alice_peer", 0)) if mode == "player" else 0
	if mode == "player" and pick <= 0: mode = "random"
	return {"mode": "training" if options.get("mode", "match") == "training" else "match", "ruleset": "om", "killer_mode": mode, "alice_peer": pick, "survivors": clampi(int(options.get("survivors", 6)), 2, 6), "round_seconds": clampi(int(options.get("round_seconds", 320)), 260, 560)}

func _peer_value(value: Variant) -> int:
	return int(value) if value is int or value is float else 0

# Choix précis d'Alice par l'hôte : "random", "malice", "bot", ou "player" + identifiant du joueur.
func set_alice_choice(mode: String, peer: int = 0) -> void :
	if networked and not authoritative():
		if can_manage_lobby(): lobby_command.rpc_id(1, "alice", {"mode": mode, "peer": peer})
		return
	if not authoritative() or phase != "lobby" or not mode in ["malice", "bot", "host", "random", "player"]: return
	if mode == "player" and not roster.has(peer): return
	var updated: Dictionary = room_options.duplicate();updated["killer_mode"] = mode;updated["alice_peer"] = peer if mode == "player" else 0
	room_options = _clean_room_options(updated)
	_broadcast_roster()

# Joueur désigné comme Alice dans le salon : son identifiant, -1 pour l'IA, 0 si ce sera tiré au lancement.
func chosen_alice_peer() -> int:
	match str(room_options.get("killer_mode", "")):
		"player":
			var pick: int = int(room_options.get("alice_peer", 0))
			return pick if roster.has(pick) else 0
		"host": return lobby_leader if roster.has(lobby_leader) else 0
		"bot": return -1
	return 0

func host_lan_room() -> void :
	leave_network()
	net = ENetMultiplayerPeer.new()
	var error: int = net.create_server(PORT, 6)
	if error != OK:
		ui.toast("Impossible d'ouvrir la partie. Une autre partie utilise peut-être ce port.");return
	multiplayer.multiplayer_peer = net;networked = true
	roster = {1: {"name": nickname, "character": selected, "malice": 0}}
	phase = "lobby";stage.visible = true;ui.show_lobby()

func join_lan_room(address: String) -> void :
	address = address.strip_edges()
	if address.is_empty(): ui.toast("Entre l'adresse de la personne qui héberge.");return
	leave_network()
	net = ENetMultiplayerPeer.new()
	var error: int = net.create_client(address, PORT)
	if error != OK: ui.toast("Adresse invalide ou connexion indisponible.");return
	multiplayer.multiplayer_peer = net;networked = true;phase = "lobby"
	ui.show_lobby();ui.toast("Connexion à la partie…", 8)
	var active_peer: ENetMultiplayerPeer = net
	get_tree().create_timer(12).timeout.connect( func():
		if net == active_peer and networked and not authoritative() and roster.is_empty(): _connection_failed())

func leave_network() -> void :
	if internet: internet.cancel()
	if service: service.regional = false
	online_room = false
	if net: net.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	net = null;networked = false;roster.clear();request_times.clear()
	lobby_leader = 1
	_ping_pending.clear();ping_ms = -1;_ping_last_reply = 0;_ping_timer = 0

func _connected() -> void :
	PaperAliceForfeit.own_peer = multiplayer.get_unique_id()
	register_player.rpc_id(1, nickname, selected, PaperRules.PROTOCOL, service.join_ticket if service else "")

func _connection_failed() -> void :
	leave_network();phase = "menu";ui.show_network();ui.toast("Connexion interrompue. Vérifie le code du salon, ta connexion et l'autorisation du jeu dans le pare-feu.", 8)

func _server_disconnected() -> void :
	if PaperAliceForfeit.host_left(self): return
	leave_network();_clear_round();phase = "menu";stage.visible = true;ui.show_network();ui.toast("L'hôte a fermé la partie.", 6)

func _peer_connected(_peer: int) -> void :
	pass

func _peer_disconnected(peer: int) -> void :
	if service:
		service.authenticated.erase(peer);service.pending.erase(peer)
	if authoritative() and combat: combat.detach_actor(peer)
	if not authoritative(): return
	roster.erase(peer)
	if dedicated and peer == lobby_leader:
		lobby_leader = int(roster.keys()[0]) if not roster.is_empty() else -1
	if str(room_options.get("killer_mode", "")) == "player" and int(room_options.get("alice_peer", 0)) == peer:
		room_options["killer_mode"] = "random";room_options["alice_peer"] = 0
		if phase == "lobby":
			var notice: String = "La personne choisie pour jouer Alice a quitté le salon : Alice sera tirée au sort."
			ui.toast(notice, 6)
			if networked: selection_notice.rpc(notice)
	if actors.has(peer) and PaperAliceForfeit.peer_left(self, peer): return
	if training and actors.has(peer):
		practice.remove_actor(actors[peer]);practice.ensure_dummies();_sync_round_for_clients();_broadcast_roster();return
	if actors.has(peer):
		var actor: PaperActor = actors[peer];actor.bot = true;actor.display_name = actor.character + " · IA"
		actors.erase(peer);actor.id = 1000 + peer;actors[actor.id] = actor
		for c: Dictionary in drones:
			if int(c.owner) == peer: c.owner = actor.id
		for z: Dictionary in zones:
			if int(z.get("owner", -1)) == peer: z.owner = actor.id
		for other: PaperActor in actors.values():
			for field: String in ["grabbed_by", "grab_target", "heal_target", "shadow_target", "overheat_target", "revive_target", "revive_helper", "death_source"]:
				if int(other.effects.get(field, -1)) == peer: other.effects[field] = actor.id
		# Pendant le film de fin, renvoyer toute la manche relancerait le film (ou ferait quitter l'écran de résultats) chez les autres.
		if phase != "ending": _sync_round_for_clients()
	_broadcast_roster()

@rpc("any_peer", "call_remote", "reliable")
func register_player(player_name: String, char_name: String, protocol: int = 0, ticket: String = "") -> void :
	if not authoritative() or not networked: return
	var peer: int = multiplayer.get_remote_sender_id()
	if protocol != PaperRules.PROTOCOL:
		selection_notice.rpc_id(peer, "Tous les joueurs doivent utiliser Paper Afterbell 0.16 · OM.")
		return
	if dedicated and not service.authenticated.has(peer):
		service.authenticate_peer(peer, player_name, char_name, ticket)
		return
	if dedicated: player_name = str(service.authenticated[peer].nickname)
	_register_verified(peer, player_name, char_name)

func _register_verified(peer: int, player_name: String, char_name: String) -> void :
	if peer <= 1 or (roster.size() >= 7 and not roster.has(peer)): return
	if roster.has(peer) and phase != "lobby": return
	var existed: bool = roster.has(peer)
	_assign_selection(peer, player_name, char_name, not existed)
	_broadcast_roster()
	if training and phase == "playing" and not existed:
		practice.add_player(peer);practice.ensure_dummies();round_serial += 1;_sync_round_for_clients()
	elif phase in ["loading", "playing", "ending"]:
		receive_round.rpc_id(peer, _actor_setup(), phase, cinema, time_left, round_serial, selected_map, _round_context())

func update_selection() -> void :
	if not networked: save_preferences();return
	if authoritative():
		_assign_selection(1, nickname, selected, false);_broadcast_roster()
	else: register_player.rpc_id(1, nickname, selected, PaperRules.PROTOCOL)

func character_owner(character_name: String, except_id: int = -1) -> String:
	for key: Variant in roster:
		if int(key) != except_id and str(roster[key].character) == character_name: return str(roster[key].name)
	return ""

func _assign_selection(peer: int, player_name: String, choice: String, new_player: bool) -> bool:
	player_name = player_name.strip_edges().left(18)
	if player_name.is_empty(): player_name = "Élève"
	if not PaperData.NAMES.has(choice): choice = "Ashura"
	var owner: String = character_owner(choice, peer)
	var accepted: bool = owner.is_empty()
	if not accepted:
		if new_player:
			choice = ""
			for candidate: String in PaperData.NAMES:
				if character_owner(candidate, peer).is_empty(): choice = candidate;break
		else: choice = str(roster.get(peer, {}).get("character", ""))
		var message: String = "Ce survivant est déjà pris par " + owner + ". " + ("Un autre personnage t'a été attribué." if not choice.is_empty() and new_player else "Choisis un personnage libre.")
		if choice.is_empty(): message = "Les six survivants sont réservés. Ton rôle sera attribué au lancement, après le choix d'Alice."
		if peer == local_id(): ui.toast(message, 6)
		elif networked: selection_notice.rpc_id(peer, message)
	roster[peer] = {"name": player_name, "character": choice, "malice": int(roster.get(peer, {}).get("malice", 0))}
	if peer == local_id() and not choice.is_empty(): selected = choice;save_preferences()
	return accepted

@rpc("authority", "call_remote", "reliable")
func selection_notice(message: String) -> void :
	ui.toast(message, 6)

func _survivor_assignments(killer_id: int) -> Dictionary:
	var result: Dictionary = {}; var used: Array[String] = []
	for key: Variant in roster:
		if int(key) == killer_id: continue
		var preferred: String = str(roster[key].character)
		if PaperData.NAMES.has(preferred) and not used.has(preferred): result[int(key)] = preferred;used.append(preferred)
	for key: Variant in roster:
		if int(key) == killer_id or result.has(int(key)): continue
		for candidate: String in PaperData.NAMES:
			if not used.has(candidate): result[int(key)] = candidate;used.append(candidate);break
	return result

func _broadcast_roster() -> void :
	if networked: receive_roster.rpc(roster, selected_map, room_options, lobby_leader, dedicated)
	ui.refresh_lobby()

@rpc("authority", "call_remote", "reliable")
func receive_roster(data: Dictionary, map_id: String, options: Dictionary = {}, leader: int = 1, regional: bool = false) -> void :
	lobby_leader = leader
	if service: service.regional = regional
	roster = data;room_options = _clean_room_options(options)
	var next_ruleset: String = str(room_options.ruleset)
	var mode_changed: bool = ruleset != next_ruleset
	if phase == "lobby": ruleset = next_ruleset
	var own: Dictionary = roster.get(local_id(), {})
	if PaperData.NAMES.has(str(own.get("character", ""))): selected = str(own.character);save_preferences()
	if (map_id != selected_map or mode_changed) and phase == "lobby":
		_rebuild_map(map_id);ui.show_lobby()
	else: ui.refresh_lobby()
	if phase == "lobby" and ui.current_page in ["connecting", "network"]: ui.show_lobby()

func start_multiplayer_round() -> void :
	if networked and not authoritative():
		if can_manage_lobby(): lobby_command.rpc_id(1, "start", {})
		return
	if not authoritative() or phase != "lobby": return
	if room_options.mode == "training": start_training(false);return
	var candidates: Array = []; var best: int = -1
	for key: Variant in roster:
		var malice: int = int(roster[key].malice)
		if malice > best: best = malice;candidates.clear()
		if malice == best: candidates.append(int(key))
	if candidates.is_empty(): return
	var chosen: int = int(candidates.pick_random())
	match str(room_options.killer_mode):
		"bot": chosen = -1
		"host": chosen = lobby_leader
		"random": chosen = int(roster.keys().pick_random())
		"player": chosen = chosen_alice_peer() if chosen_alice_peer() > 0 else int(roster.keys().pick_random())
	if chosen < 0 and roster.size() > 6:
		ui.toast("Alice IA laisse 6 places aux survivants. Choisis une Alice humaine pour jouer à 7.", 6);return
	_clear_round();round_preparing = true
	phase = "loading";ui.show_loading(selected_map, _loading_characters())
	await get_tree().process_frame
	await get_tree().process_frame
	if phase != "loading": return
	_start_round(chosen)

func _clear_round() -> void :
	if exit_flow: exit_flow.clear()
	if emote_sync: emote_sync.clear()
	if bindings: bindings.controller_sprint = false
	teleport_warning = 0.0
	_restore_warning_lamps()
	round_preparing = false;cinema = 0;outcome = "";spectate_id = -1
	camera_anchor_ready = false;match_results.clear()
	if rewards: rewards.clear()
	if emote_wheel: emote_wheel.hide()
	input_clock = 0;interact_clock = 0;snapshot_clock = 0;world_state_clock = 0;previous_positions.clear()
	if is_instance_valid(camera_obscured_actor): camera_obscured_actor.visual.visible = true
	camera_obscured_actor = null
	if mobile_controls: mobile_controls.cancel_all()
	if reveals: reveals.clear()
	if audio: audio.clear_event_history()
	loading_ready.clear();archive_locks.clear();loading_remote_count = 1
	ending_people.clear();ending_focus = "Ashura";ending_kind = "ending_survivors";last_victim_name = ""
	if combat and combat.has_method("clear_entities"): combat.clear_entities()
	if presentation: presentation.clear_entities()
	if ui and ui.screen_fx: ui.screen_fx.clear()
	if film: film.stop()
	_show_exit_sign(true)
	if kill_scenes: kill_scenes.clear()
	if ui: ui.hide_film()
	if presentation: presentation.show()
	for node: Node3D in objective_nodes: node.show()
	if ui: ui.toast_time = 0;ui.toast_label.hide()
	minions.clear();projectiles.clear();drones.clear();training = false;practice.clear();ending_presented = false;preview_character = ""
	for a: PaperActor in actors.values(): a.queue_free()
	actors.clear();zones.clear();objective_done.clear();objective_progress.clear();door_history.clear()
	for n: Node in fx.get_children(): n.queue_free()
	zone_nodes.clear()
	if is_instance_valid(barrier): barrier.queue_free()
	barrier = null;blocked_door = -1;lms = false;clock = 0;event_count.clear();pause_open = false

	request_times.clear()
	combat = PaperCombat.new(self);brain = PaperBrain.new(self)
	objective_seconds_removed = 0;camera_shake = 0
	_poses.clear()
	_zone_signature = -1
	_chase_active = false
	_chase_release = 0.0
	if camera_rig: camera_rig.reset()

func _spawn(actor_id: int, char_name: String, is_bot: bool, spawn: Vector3, player_name: String) -> PaperActor:
	var a: PaperActor = PaperActor.new();add_child(a);a.setup(actor_id, char_name, is_bot);a.position = spawn + Vector3.UP * 0.05;a.net_position = a.position;a.display_name = player_name

	a.reset_physics_interpolation()
	a.configure_ruleset(ruleset)
	actors[actor_id] = a
	a.movement_event.connect( func(kind: String, payload: Dictionary):
		if authoritative() and phase == "playing": event(kind, payload))
	if rewards: rewards.register(a)

	if not dedicated: a.visual.anim_fx.connect(presentation.visual_fx.bind(a.visual));a.visual.anim_fx.connect(emote_sync.on_cue.bind(a.visual))
	return a

func _start_round(killer_id: int) -> void :
	_clear_round();stage.visible = false
	presentation.prepare_shadows()
	round_serial += 1
	var slot: int = 0
	var assignments: Dictionary = _survivor_assignments(killer_id)
	for key: Variant in roster:
		var actor_id: int = int(key)
		var char_name: String = "Alice" if actor_id == killer_id else str(assignments.get(actor_id, "Ashura"))
		var pos: Vector3 = school.killer_spawn if char_name == "Alice" else school.spawn_points[slot % school.spawn_points.size()]
		_spawn(actor_id, char_name, false, pos, str(roster[key].name))
		if char_name != "Alice": slot += 1
	if killer_id < 0: _spawn(100, "Alice", true, school.killer_spawn, "Alice · IA")
	var used_names: Array = []
	for actor: PaperActor in actors.values(): used_names.append(actor.character)
	while slot < (int(room_options.survivors) if networked else 6):
		var character_name: String = PaperData.NAMES[slot % 6]
		for candidate: String in PaperData.NAMES:
			if not used_names.has(candidate): character_name = candidate;break
		used_names.append(character_name)
		_spawn(101 + slot, character_name, true, school.spawn_points[slot % school.spawn_points.size()], character_name + " · IA")
		slot += 1
	time_left = float(room_options.round_seconds) if networked else 320.0;clock = 0;cinema = 0;phase = "loading";outcome = "";spectate_id = -1
	var local: PaperActor = local_actor()
	if local: yaw = 0 if not local.killer else PI
	capture_gameplay_mouse()
	loading_ready[1] = true
	ui.show_loading(selected_map, _loading_characters());audio.set_mode("ambient")
	_warm_up_effects()
	_sync_round_for_clients()
	print("ROUND_STARTED role=", "killer" if killer_id == 1 else "survivor", " actors=", actors.size())



func _warm_up_effects() -> void :
	if dedicated or not is_instance_valid(presentation) or not presentation.has_method("warm_up"): return
	presentation.warm_up(camera)

func _actor_setup() -> Array:
	var data: Array = []
	for a: PaperActor in actors.values(): data.append(a.pack())
	return data

func _sync_round_for_clients() -> void :
	if networked and authoritative(): receive_round.rpc(_actor_setup(), phase, cinema, time_left, round_serial, selected_map, _round_context())

@rpc("authority", "call_remote", "reliable")
func receive_round(data: Array, new_phase: String, t: float, remaining: float, serial: int, map_id: String, context: Dictionary = {}) -> void :
	room_options = _clean_room_options(context.get("options", room_options))
	var next_ruleset: String = str(room_options.ruleset)
	var mode_changed: bool = ruleset != next_ruleset
	_clear_round()
	ruleset = next_ruleset
	if map_id != selected_map or mode_changed: _rebuild_map(map_id)
	stage.visible = false
	round_serial = serial;training = bool(context.get("training", false));practice.dummy_mode = str(context.get("dummy_mode", "idle"))
	for d: Dictionary in data:
		var a: PaperActor = _spawn(int(d.id), str(d.character), bool(d.bot), d.position, str(d.display_name));a.unpack(d)
	presentation.prepare_shadows()
	match_results = context.get("results", []).duplicate(true)
	exit_flow.unpack(context.get("exit", {}))
	phase = new_phase;cinema = t;time_left = remaining;outcome = str(context.get("outcome", ""));lms = bool(context.get("lms", false));capture_gameplay_mouse();ui.show_hud()
	ending_people = context.get("ending_people", []).duplicate();ending_focus = str(context.get("ending_focus", "Ashura"));ending_kind = str(context.get("ending_kind", "ending_survivors"));last_victim_name = str(context.get("last_victim", ""))
	if new_phase == "loading":
		audio.set_mode("ambient");ui.show_loading(selected_map, _loading_characters());_warm_up_effects();round_loaded.rpc_id(1, round_serial)
	elif new_phase == "ending": audio.set_mode("blocus" if ending_kind == PaperAliceForfeit.KIND else "ending");_begin_film(false)
	var local: PaperActor = local_actor()
	if local: yaw = atan2( - local.aim.x, - local.aim.z) if training else PI if local.killer else 0.0

func _physics_process(delta: float) -> void :
	if not perf.enabled:
		_physics_step(delta)
		return
	var started: int = Time.get_ticks_usec()
	_physics_step(delta)
	if phase == "playing":
		perf.sample_physics_step(Time.get_ticks_usec() - started)
		_perf_snapshot_estimate(delta)

func _physics_step(delta: float) -> void :
	if phase == "loading":
		if not round_preparing: cinema += delta
		if not round_preparing and authoritative() and cinema >= INTRO_DURATION and _loading_complete():
			begin_play(round_serial)
			if networked: begin_play.rpc(round_serial)
	if phase != "playing": return
	if pause_open and not networked: return
	if authoritative():
		clock += delta
		if not training and not exit_flow.timer_paused(): time_left = maxf(0, time_left - delta)
		elif training: practice.tick(delta)
		combat.tick(delta)
		brain.tick(delta)
	else: emote_sync.extrapolate(delta)
	_collect_input(delta)
	for a: PaperActor in actors.values():
		if authoritative() and a.killer and clock < 5 and not training: a.move_input = Vector3.ZERO
		if authoritative() and not a.bot and networked and int(a.id) != 1 and clock - float(a.effects.get("last_input_clock", clock)) > 0.4:
			a.move_input = Vector3.ZERO;a.sprint = false
		a.visual.set_combat_state(_pose_for(a))
		a.visual.set_life_state("dead" if not a.alive else "downed" if bool(a.effects.get("downed", false)) else "alive")
		if bool(a.effects.get("escaped", false)): a.visual.hide()
		a.tick(delta, authoritative())
	if authoritative():
		_update_chased(delta)
		_tick_emotes(delta)
		rewards.tick(delta)
		_check_doors()
		exit_flow.tick()
		snapshot_clock += delta
		world_state_clock += delta
		if networked and snapshot_clock >= 0.05:
			snapshot_clock = 0
			_send_snapshot()
		if networked and world_state_clock >= 0.25:
			world_state_clock = 0
			receive_world_state.rpc(zones, objective_progress, objective_done, round_serial, _archive_locks_snapshot(), exit_flow.pack())

const POSE_KEYS: Array[String] = ["sprinting", "second_life", "landing_roll", "lms", "ruleset_om", "grounded", "vertical_speed", "grab_holding"]



func _pose_for(a: PaperActor) -> Dictionary:
	var pose: Dictionary
	if _poses.has(a.id):
		pose = _poses[a.id]
	else:
		pose = {}
		_poses[a.id] = pose
	var effects: Dictionary = a.effects

	pose.merge(effects, true)
	var host: bool = authoritative()

	pose["sprinting"] = a.sprint if host else bool(effects.get("running", false))
	pose["second_life"] = bool(effects.get("revived", false))
	pose["landing_roll"] = float(effects.get("land_roll_time", 0))
	pose["lms"] = a.lms
	pose["ruleset_om"] = true
	pose["grounded"] = a.is_on_floor() if host else bool(effects.get("grounded", true))
	pose["vertical_speed"] = a.velocity.y

	var holding: bool = false
	if float(effects.get("grab_time", 0.0)) > 0.0:
		for other: PaperActor in actors.values():
			if int(other.effects.get("grabbed_by", -1)) == a.id:
				holding = true
				break
	pose["grab_holding"] = holding

	var expected: int = effects.size()
	for key: String in POSE_KEYS:
		if not effects.has(key): expected += 1
	if pose.size() != expected:
		for key: Variant in pose.keys():
			if not effects.has(key) and not POSE_KEYS.has(key): pose.erase(key)
	return pose




func _send_snapshot() -> void :
	var packed: PackedByteArray = _pack_snapshot_rows()
	receive_snapshot.rpc(packed, _snapshot_raw_size, clock, time_left, phase, lms, blocked_door, round_serial)
	receive_entities.rpc(_pack_entities(minions, false), _pack_entities(projectiles, true), round_serial, _pack_drones())
	if perf.sampling(): perf.sample_snapshot(var_to_bytes([packed, _snapshot_raw_size, clock, time_left, phase, lms, blocked_door, round_serial]).size(), 1)

func _pack_snapshot_rows() -> PackedByteArray:
	_snapshot_rows.clear()
	for key: Variant in actors: _snapshot_rows.append(actors[key].pack_motion())
	var raw: PackedByteArray = var_to_bytes(_snapshot_rows)
	_snapshot_raw_size = raw.size()
	return raw.compress(FileAccess.COMPRESSION_DEFLATE)


func _perf_snapshot_estimate(delta: float) -> void :
	if networked or not perf.sampling(): return
	_perf_snapshot_clock += delta
	if _perf_snapshot_clock < 0.05: return
	_perf_snapshot_clock = 0.0
	var packed: PackedByteArray = _pack_snapshot_rows()
	perf.sample_snapshot(var_to_bytes([packed, _snapshot_raw_size, clock, time_left, phase, lms, blocked_door, round_serial]).size(), 1)

func _collect_input(delta: float) -> void :
	var a: PaperActor = local_actor()
	if not a or not a.alive or a.bot: return
	if not a.active() and not (ruleset == "om" and bool(a.effects.get("downed", false))): return
	if kill_scenes and kill_scenes.input_locked(a): return
	var input: Vector2 = Input.get_vector("left", "right", "forward", "back") if not pause_open else Vector2.ZERO
	var running: bool = Input.is_action_pressed("sprint") or bindings.controller_sprint
	var interacting: bool = Input.is_action_pressed("interact")
	if mobile_mode:
		if mobile_controls and mobile_controls.enabled and mobile_controls.move_vector.length_squared() > 0: input = mobile_controls.move_vector
		running = running or (mobile_controls.sprint_enabled if mobile_controls and mobile_controls.enabled else false)
		interacting = interacting or (mobile_controls.interact_held if mobile_controls and mobile_controls.enabled else false)
	if emote_wheel.visible: input = Vector2.ZERO;running = false;interacting = false
	if test_client: input = Vector2(sin(clock * 0.3) * 0.45, -0.65)
	var world_move: Vector3 = Vector3(input.x, 0, input.y).rotated(Vector3.UP, yaw)
	var aim: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, yaw)
	var piloting: bool = bool(a.effects.get("drone_piloting", false))
	if piloting: aim = Vector3(0, sin(pitch), - cos(pitch)).rotated(Vector3.UP, yaw)
	a.aim = aim
	camera_rig.apply_facing(a, delta)
	if authoritative():
		a.move_input = world_move;a.aim = aim;a.sprint = running
		if piloting: combat.drone_input(a, _drone_movement(input, aim))
	else:
		input_clock += delta
		if input_clock >= 0.04:
			input_clock = 0;submit_input.rpc_id(1, world_move, aim, running)
	interact_clock += delta
	if not pause_open and interacting and interact_clock >= 0.2:
		interact_clock = 0
		if authoritative(): combat.interact(a)
		else: command.rpc_id(1, "interact", {})

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func submit_input(direction: Vector3, look: Vector3, running: bool) -> void :
	if not authoritative() or phase != "playing": return
	var sender: int = multiplayer.get_remote_sender_id()
	var a: PaperActor = actors.get(sender)
	if not a or not a.alive or ( not a.active() and not (ruleset == "om" and bool(a.effects.get("downed", false)))) or not direction.is_finite() or not look.is_finite(): return
	input_packets += 1
	direction.y = 0
	if not bool(a.effects.get("drone_piloting", false)): look.y = 0
	if look.length_squared() < 0.001: return
	a.move_input = direction.limit_length(1.0);a.aim = look.normalized();a.sprint = running;a.effects["last_input_clock"] = clock
	if bool(a.effects.get("drone_piloting", false)):
		var planar: Vector3 = Vector3(a.aim.x, 0, a.aim.z).normalized()
		var side: Vector3 = planar.cross(Vector3.UP)
		combat.drone_input(a, (a.aim * direction.dot(planar) + side * direction.dot(side)).limit_length(1.0))

const SNAPSHOT_MAX_BYTES: int = 262144

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func receive_snapshot(packed: PackedByteArray, raw_size: int, t: float, remaining: float, p: String, is_lms: bool, door: int, serial: int) -> void :
	if phase not in ["loading", "playing", "ending"]: return
	if serial != round_serial or (phase == "ending" and p == "playing"): return
	if raw_size <= 0 or raw_size > SNAPSHOT_MAX_BYTES: return
	var data: Variant = bytes_to_var(packed.decompress(raw_size, FileAccess.COMPRESSION_DEFLATE))
	if not data is Array: return
	if phase == "loading" and p == "playing": begin_play(serial)
	messages_received += 1;clock = t;time_left = remaining;phase = p;lms = is_lms
	for d: Variant in data:
		if not d is Array or d.size() < 12: continue
		var a: PaperActor = actors.get(int(d[0]))
		if a: a.unpack_motion(d)
	if blocked_door != door: blocked_door = door;_build_barrier()

@rpc("authority", "call_remote", "reliable", 3)
func receive_world_state(heal_zones: Array, progress: Dictionary, done: Array, serial: int, locks: Dictionary = {}, escape_state: Dictionary = {}) -> void :
	if serial != round_serial: return
	zones.assign(heal_zones);objective_progress = progress;objective_done.assign(done)
	archive_locks = locks
	exit_flow.unpack(escape_state)

func request_ability(slot: int) -> void :
	if phase != "playing" or pause_open or emote_wheel.visible: return
	var a: PaperActor = local_actor()
	if not a or not a.alive: return
	a.aim = Vector3.FORWARD.rotated(Vector3.UP, yaw)
	if authoritative(): _cancel_emote(a);combat.use(a, slot)
	else: command.rpc_id(1, "ability", {"slot": slot, "aim": a.aim})

func release_ability(slot: int) -> void :
	if slot != 1 or phase != "playing": return
	var actor: PaperActor = local_actor()
	if not actor or actor.character not in ["Simon", "Ashura"]: return
	if authoritative(): combat.release_charge(actor)
	elif networked: command.rpc_id(1, "release_charge", {})

@rpc("any_peer", "call_remote", "reliable")
func command(kind: String, data: Dictionary) -> void :
	if not authoritative() or phase != "playing": return
	var sender: int = multiplayer.get_remote_sender_id()
	var key: String = str(sender) + kind
	if clock - float(request_times.get(key, -100)) < 0.07: return
	request_times[key] = clock
	var a: PaperActor = actors.get(sender)
	if kind == "camera_mode":
		if a: a.effects["cam_facing"] = clampi(int(data.get("mode", 0)), 0, 2)
		return
	if kind == "assist": combat.assist(sender, int(data.get("actor", -1)), str(data.get("choice", "health")));return
	if not a or not a.active(): return
	if kind == "emote": _start_emote(a, str(data.get("id", "")));return
	_cancel_emote(a)
	if kind == "ability":
		var slot: int = int(data.get("slot", -1))
		if slot >= 0 and slot < 6:
			var look: Variant = data.get("aim", a.aim)
			if not look is Vector3 or not look.is_finite(): return
			look.y = 0
			if look.length_squared() < 0.01: return
			a.aim = look.normalized()
			remote_actions += 1;combat.use(a, slot)
	elif kind == "interact": combat.interact(a)
	elif kind == "release_charge": combat.release_charge(a)
	elif kind == "cancel_aim": combat.cancel_aim(a)
	elif kind == "jump": a.request_jump(true)
	elif kind == "archive_qte": combat.archive_qte(a, int(data.get("id", 0)), str(data.get("key", "")).left(1))

func request_assist(actor_id: int, choice: String) -> void :
	if authoritative(): combat.assist(local_id(), actor_id, choice)
	elif networked: command.rpc_id(1, "assist", {"actor": actor_id, "choice": choice})

func add_objective_progress(index: int, amount: float) -> void :
	if index < 0 or index >= school.objectives.size() or objective_done.has(index): return
	objective_progress[index] = minf(1, float(objective_progress.get(index, 0)) + amount)
	if float(objective_progress[index]) >= 1:
		objective_done.append(index)
		var reduction: float = 0.0 if lms or training else minf(10.0, 50.0 - objective_seconds_removed)
		objective_seconds_removed += reduction;time_left = maxf(0, time_left - reduction)
		event("objective", {"index": index, "position": school.objectives[index], "text": "Archive scellée · −%d secondes" % int(reduction)})

func eliminate(a: PaperActor) -> void :
	if not a.alive or a.killer: return
	if training: practice.on_eliminated(a)
	a.alive = false;a.move_input = Vector3.ZERO;a.velocity = Vector3.ZERO
	if not training: last_victim_name = a.character
	a.collider.set_deferred("disabled", true)
	if kill_scenes: kill_scenes.on_eliminated(a)
	event("eliminated", {"actor": a.id, "character": a.character, "position": a.position})

func _finish(winner: String, forfeit: bool = false) -> void :
	if phase != "playing" or training: return
	match_results = rewards.results()
	emote_wheel.hide()
	_award_tickets(winner)
	phase = "ending";outcome = winner;cinema = 0;Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for key: Variant in roster:
		var a: PaperActor = actors.get(int(key))
		if a: roster[key].malice = 0 if a.killer else int(roster[key].malice) + 1
	ending_people.clear()
	ending_people.append_array(exit_flow.escaped_names)
	if service and dedicated: service.submit_results(match_results, exit_flow.escaped, PaperAliceForfeit.winners(self) if forfeit else [])
	ending_focus = last_victim_name if winner == "killer" and PaperData.NAMES.has(last_victim_name) else str(ending_people[0]) if not ending_people.is_empty() else "Ashura"
	for actor: PaperActor in actors.values():
		if actor.lms: ending_focus = actor.character
	ending_kind = "ending_killer" if winner == "killer" else "ending_lms" if lms else "ending_survivors"
	if forfeit: PaperAliceForfeit.stage(self)
	event("ending", {"winner": winner, "lms": lms, "participants": ending_people.duplicate(), "focus": ending_focus, "kind": ending_kind, "results": match_results})
	if networked: _broadcast_roster()
	print("ROUND_FINISHED winner=", winner, " lms=", lms, " elapsed=", clock)

# Tickets de fin de manche pour la personne qui joue sur ce poste (hôte ou client).
func _award_tickets(winner: String, me: PaperActor = null) -> void :
	if me == null: me = local_actor()
	if not me or dedicated: return
	var points: float = 0.0
	for row: Dictionary in match_results:
		if int(row.get("id", -1)) == me.id: points = float(row.get("points", 0.0))
	var gain: int = PaperDances.reward(points, (winner == "killer") == me.killer)
	tickets += gain;save_preferences()
	ui.toast("+%d tickets · Boutique de danses" % gain, 5)

func return_to_lobby() -> void :
	if networked and not authoritative():
		if can_manage_lobby(): lobby_command.rpc_id(1, "rematch", {})
		else: ui.toast("Le chef du groupe prépare la prochaine manche.")
		return
	_clear_round();stage.visible = true
	phase = "lobby" if networked else "menu"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if networked: lobby_again.rpc();ui.show_lobby()
	else: ui.show_main()

@rpc("authority", "call_remote", "reliable")
func lobby_again() -> void :
	_clear_round();stage.visible = true;phase = "lobby";Input.mouse_mode = Input.MOUSE_MODE_VISIBLE;ui.show_lobby()

func quit_to_menu() -> void :
	leave_network();_clear_round();stage.visible = true;phase = "menu";Input.mouse_mode = Input.MOUSE_MODE_VISIBLE;ui.show_main()

func _check_doors() -> void :
	var alice: PaperActor = killer_actor()
	if not alice: return
	for door: Dictionary in school.doors:
		var id: int = int(door.id); var pos: Vector3 = door.position
		var axis: String = str(door.axis)
		var delta: Vector3 = alice.position - pos
		var side: float = delta.z if axis == "x" else delta.x
		var along: float = delta.x if axis == "x" else delta.z
		var old: float = float(door_history.get(id, side))
		if old * side < 0 and absf(side) < 1.8 and absf(delta.y) < 2.0 and absf(along) < float(door.width) * 0.5 and blocked_door != id:
			blocked_door = id;_build_barrier();event("door", {"position": pos, "door": id})
		door_history[id] = side

func _build_barrier() -> void :
	if is_instance_valid(barrier): barrier.queue_free()
	barrier = null
	if blocked_door < 0: return
	for door: Dictionary in school.doors:
		if int(door.id) != blocked_door: continue
		barrier = StaticBody3D.new();barrier.collision_layer = 2;barrier.collision_mask = 0;add_child(barrier);barrier.position = door.position
		var coll: CollisionShape3D = CollisionShape3D.new(); var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(float(door.width), 2.8, 0.5) if str(door.axis) == "x" else Vector3(0.5, 2.8, float(door.width))
		coll.shape = shape;coll.position.y = 1.4;barrier.add_child(coll)
		for i in range(9):
			var m: MeshInstance3D = MeshInstance3D.new(); var cone: CylinderMesh = CylinderMesh.new();cone.top_radius = 0;cone.bottom_radius = 0.19;cone.height = 2.5 + (i % 3) * 0.25;m.mesh = cone
			var mat: StandardMaterial3D = StandardMaterial3D.new();mat.albedo_color = Color("271522");mat.emission_enabled = true;mat.emission = Color("40101f");m.material_override = mat
			var distance: float = (float(i) / 8.0 - 0.5) * float(door.width)
			m.position = Vector3(distance, cone.height / 2, 0) if str(door.axis) == "x" else Vector3(0, cone.height / 2, distance)
			barrier.add_child(m)
		break

func event(kind: String, data: Dictionary) -> void :
	data["round_serial"] = round_serial
	event_count[kind] = int(event_count.get(kind, 0)) + 1
	_event_local(kind, data)
	if networked and authoritative(): receive_event.rpc(kind, data)

@rpc("authority", "call_remote", "reliable")
func receive_event(kind: String, data: Dictionary) -> void :
	if int(data.get("round_serial", -1)) != round_serial or phase not in ["loading", "playing", "ending"]: return
	_event_local(kind, data)


func _thank_gesture(a: PaperActor) -> void :
	if is_instance_valid(a) and a.alive and is_instance_valid(a.visual): a.visual.trigger("thanks")

func _event_local(kind: String, data: Dictionary) -> void :
	if presentation: presentation.receive(kind, data)
	if kill_scenes: kill_scenes.on_event(kind, data)
	if ui and ui.screen_fx: ui.screen_fx.on_event(kind, data)
	if training: practice.observe(kind, data)
	var actor_id: int = int(data.get("actor", -1))
	var a: PaperActor = actors.get(actor_id)
	var loc: PaperActor = local_actor()

	var view: PaperActor = _view_actor()
	var listener: Vector3 = _listener_position()
	if kind in ["exit_state", "escaped"]:
		exit_flow.unpack(data.get("state", {}))
		if not (exit_alarm and str(data.get("text", "")) == "LA SORTIE EST OUVERTE · ÉCHAPPEZ-VOUS"): ui.toast(str(data.get("text", str(data.get("character", "Un élève")) + " s’est échappé.")), 4)
		if kind == "exit_state": audio.sfx("door_open", data.get("position", Vector3.ZERO), listener, 0.65)
		return
	if kind == "shadow_decoys": teleport_warning = 1.35
	if audio:
		var sound_data: Dictionary = data.duplicate()
		if not sound_data.has("position") and a: sound_data["position"] = a.position
		audio.receive_event(kind, sound_data, listener)
	if presentation: ui.receive_combat_feedback(presentation.feedback_for_event(kind, data))
	_camera_feedback(kind, data, a)
	if kind == "ability":
		if a: a.visual.trigger(str(data.get("name", "attack")))
		if a and (a == view or (view and view.character == "Elly") or (view and view.position.distance_to(a.position) < 18)):
			if audio.has_method("sfx_ability"): audio.sfx_ability(str(data.get("name", "attack")), a.position, listener)
			else: audio.sfx("slash" if a.killer else "ability", a.position, listener)
			if loc and loc.character == "Elly" and a.killer: ui.toast("À l'écoute : Alice · " + str(data.get("name", "capacité")), 2)
	elif kind in ["jump", "land_roll"]:
		audio.sfx("jump" if kind == "jump" else "ground_impact", data.get("position", Vector3.ZERO), listener, 0.6 if kind == "jump" else 0.32)
	elif kind == "hit":
		if actor_id == local_id(): bindings.rumble(0.4)
		audio.sfx("hit", data.get("position", Vector3.ZERO), listener)
		if actor_id == local_id(): add_camera_trauma(0.55)
		elif int(data.get("source", -1)) == local_id(): add_camera_trauma(0.24)
	elif kind == "hitbox":
		_hitbox_visual(data)
	elif kind == "grenade":
		var sound: String = "grenade_throw" if str(data.get("action", "")) == "throw" else "grenade_bounce" if str(data.get("action", "")) == "bounce" else "flash"
		audio.sfx(sound, data.get("position", Vector3.ZERO), listener)
	elif kind == "drone":
		var action: String = str(data.get("action", ""))
		if action in ["impact", "recycled", "depleted"]:
			audio.sfx("ground_impact" if action == "impact" else "camera_switch", data.get("position", Vector3.ZERO), listener)
	elif kind == "grab" and bool(data.get("released", false)) and bool(data.get("wall", false)):
		audio.sfx("ground_impact", a.position if a else Vector3.ZERO, listener)
		if a: a.visual.trigger("slam")
	elif kind == "block":
		audio.sfx("block", data.get("position", Vector3.ZERO), listener)
		if a: a.visual.trigger("block_hit")
		if actor_id == local_id() or int(data.get("source", -1)) == local_id(): add_camera_trauma(0.3)
	elif kind == "dodge":
		if a: a.visual.trigger("dodge")
	elif kind == "drone_eaten":
		if a: a.visual.trigger("eat_drone")
	elif kind == "minion" and str(data.get("action", "")) == "disperse":
		audio.sfx("shadow", data.get("position", Vector3.ZERO), listener)
	elif kind == "shadow" or (kind == "dash" and a and a.killer):
		_shadow_visual(data.get("position", a.position if a else Vector3.ZERO))
	elif kind == "stun":
		if a: a.visual.trigger("stun")
		audio.sfx("stun", a.position if a else Vector3.ZERO, listener)
		if actor_id == local_id(): add_camera_trauma(0.45)
		elif int(data.get("source", -1)) == local_id(): add_camera_trauma(0.3)
	elif kind == "flash":

		if actor_id == local_id() and not bool(data.get("world_only", false)): ui.blind_flash = float(data.get("duration", 1.5))
	elif kind == "spike":
		var from: Vector3 = data.get("from", Vector3.ZERO); var to: Vector3 = data.get("to", from + Vector3.FORWARD * 15)
		if bool(data.get("telegraph", false)):
			effect_line(from + Vector3.UP * 0.06, to + Vector3.UP * 0.06, Color("ff4a68"), float(data.get("duration", 0.7)))
		else: _spike_visual(from, to)
	elif kind == "message":
		if actor_id < 0 or actor_id == local_id(): ui.toast(str(data.get("text", "")), 3)
	elif kind == "aura_unlock":
		if actor_id == local_id(): ui.announcement("AURA ÉVEILLÉE", "Les bonus de LMS sont disponibles.", 3)
	elif kind == "lms":
		if training: return
		lms = true;ui.announcement("DERNIÈRE PRÉSENCE", str(data.get("character", "")) + " · duel final", 4)
		audio.set_lms_character(str(data.get("character", "Ashura")));audio.set_mode("lms");audio.sfx("bell", Vector3.ZERO, Vector3.ZERO)
	elif kind == "eliminated":
		if training: return
		if a and not a.killer:
			for other: PaperActor in actors.values():
				if other != a and other.alive and not other.killer and other.position.distance_to(a.position) < 20.0: other.visual.trigger("grieve")
		ui.toast(str(data.get("character", "Un élève")) + " a été éliminé.", 3)
		if actor_id == local_id(): ui.announcement("VOUS ÊTES TOMBÉ", "TAB · suivre un allié", 3)
	elif kind == "downed":
		if a: a.visual.set_life_state("downed")
		ui.toast(str(data.get("character", a.character if a else "Un élève")) + " est au sol · 30 secondes pour le relever.", 3)
	elif kind == "death_start":
		var cause: String = str(data.get("death_kind", data.get("attack", "slash")))
		if cause not in ["spike", "shadow"]: cause = "slash"
		if a: a.visual.trigger("death_" + cause)
		var source: PaperActor = actors.get(int(data.get("source", -1)))
		if source and bool(data.get("execution", false)): source.visual.trigger("execution_" + cause)
	elif kind == "revive_start":
		if a: a.visual.trigger("revive")
	elif kind == "revive_cancel":
		if a: a.visual.trigger("revive_cancel")
	elif kind == "heal":
		if a and not a.killer and float(data.get("amount", 0.0)) > 0.0: a.visual.trigger("healed")
	elif kind == "revived":
		if a: a.visual.set_life_state("alive");a.visual.trigger("recover")
		var helper: PaperActor = actors.get(int(data.get("helper", -1)))
		if helper and helper != a:
			helper.visual.trigger("revive_help")

			if a: get_tree().create_timer(1.0).timeout.connect(_thank_gesture.bind(a))
		ui.toast((a.character if a else "Un élève") + " a été relevé · seconde vie.", 3)
	elif kind == "archive_qte" and not bool(data.get("ready", false)) and actor_id == local_id():
		ui.toast("Contrôle réussi" if bool(data.get("success", false)) else "Contrôle raté · archive bloquée 3 s · Alice t’a repéré !", 2.5)
	elif kind == "archive_alarm":
		if loc and loc.killer: ui.toast("ALERTE ARCHIVE · UNE PRÉSENCE A ÉTÉ RÉVÉLÉE", 3)
	elif kind == "objective":
		ui.toast(str(data.get("text", "Archive scellée")));audio.sfx("heal", Vector3.ZERO, Vector3.ZERO)
	elif kind == "ending":
		match_results = data.get("results", []).duplicate(true);emote_wheel.hide()
		outcome = str(data.winner);phase = "ending";cinema = 0;Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		lms = bool(data.get("lms", lms));ending_people = data.get("participants", []).duplicate();ending_focus = str(data.get("focus", "Ashura"));ending_kind = str(data.get("kind", "ending_killer" if outcome == "killer" else "ending_lms" if lms else "ending_survivors"))
		if not authoritative(): _award_tickets(outcome)
		audio.set_mode("blocus" if ending_kind == PaperAliceForfeit.KIND else "ending");_begin_film(false)
	elif kind == "qte":
		if bool(data.get("ready", false)) and int(data.get("helper", -100)) == local_id(): ui.show_qte(actor_id, float(data.get("started", clock)))

func effect_line(from: Vector3, to: Vector3, color: Color, duration: float) -> void :
	presentation.line(from, to, color, duration)

func _spike_visual(from: Vector3, to: Vector3) -> void :
	presentation.spikes(from, to)

func _process(delta: float) -> void :
	if dedicated: return
	if not perf.enabled:
		_process_frame(delta)
		return
	var started: int = Time.get_ticks_usec()
	_process_frame(delta)
	if phase == "playing": perf.sample_frame(get_viewport(), Time.get_ticks_usec() - started)

func _process_frame(delta: float) -> void :
	_update_dance_music()
	if bindings and phase == "playing" and not pause_open and not emote_wheel.visible:
		camera_rig.pad_look(delta)
	_update_teleport_warning(delta)
	if map_interactables and exit_flow: map_interactables.update_exit(exit_flow.opened, exit_flow.true_form)
	_update_network_stats(delta)
	_update_mobile_controls()
	_update_audio_feedback()
	menu_time += delta
	if phase == "loading":
		ui.update_loading(cinema, _loading_count(), _loading_total());_update_camera(delta)
		return
	if phase == "gallery":
		gallery.tick(delta)
		presentation.update_visuals(delta)
		return
	if phase == "prologue":
		if prologue.tick_standalone(delta): end_prologue()
		else: ui.update_film("", "", prologue.black)
		presentation.update_visuals(delta)
		return
	if prologue and not prologue.kind.is_empty():
		if prologue.gallery_mode: prologue.stop()
		else: _abort_prologue()
	if phase == "ending":
		cinema += delta
		if not ending_presented and cinema >= film.duration:
			ending_presented = true;_end_film();ui.show_ending(outcome, lms)
	if phase == "ending" and not ending_presented:
		_update_round_film(delta)
	else: _update_camera(delta)
	presentation.update_visuals(delta)
	if training: practice.update_labels()
	_update_reveals()
	if phase in ["menu", "lobby"]:
		if menu_stage: menu_stage.animate(delta, preview_character)
		audio.set_mode("ambient")
	elif phase == "playing":
		_update_footsteps(delta)
		_update_music(delta)
	effects_clock += delta
	if effects_clock > 0.1: effects_clock = 0;_sync_world_effects()
	ui.update_hud(delta)
	_test_tick(delta)



func _update_footsteps(delta: float) -> void :
	var view: PaperActor = _view_actor()
	var host: bool = authoritative()
	for key: Variant in actors:
		var walker: PaperActor = actors[key]
		var grounded: bool = walker.is_on_floor() if host else bool(walker.effects.get("grounded", true))
		if not walker.active() or not grounded or float(walker.effects.get("land_roll_time", 0)) > 0 or bool(walker.effects.get("shadow_hide", false)) or Vector2(walker.velocity.x, walker.velocity.z).length() < 0.4:
			walker.foot_clock = 0
			continue
		walker.foot_clock += delta
		if walker.foot_clock <= (0.27 if walker.velocity.length() > 4.5 else 0.46): continue
		walker.foot_clock = 0
		if not view: continue
		var elly_hears: bool = view.character == "Elly" and walker.killer
		if elly_hears or view.position.distance_to(walker.position) < 14:
			audio.sfx("step", walker.position, walker.position if elly_hears else view.position)

func _update_music(delta: float) -> void :
	var k: PaperActor = killer_actor()
	if k and float(k.effects.get("phase6", 0)) > 0:
		audio.set_mode("true_form")
		return
	if training:
		var me: PaperActor = local_actor()
		if me and me.lms:
			audio.set_lms_character(me.character)
			audio.set_mode("lms")
		else: audio.set_mode("ambient")
		return
	if lms:
		for key: Variant in actors:
			var survivor: PaperActor = actors[key]
			if survivor.alive and not survivor.killer and survivor.lms:
				audio.set_lms_character(survivor.character)
				break
		audio.set_mode("lms")
		return
	var chased: bool = _chase_music(_view_actor(), k, delta)
	if exit_flow and exit_flow.opened and audio.has_method("set_rush"):
		audio.set_mode("exit")
		return
	audio.set_mode("chase" if chased else "ambient")





func _chase_music(view: PaperActor, killer: PaperActor, delta: float) -> bool:
	if not view or not killer or not view.alive:
		_chase_active = false
		_chase_release = 0.0
		return false
	var trigger: bool = false
	var far: bool = true
	if view.killer:
		var nearest: float = INF
		for key: Variant in actors:
			var survivor: PaperActor = actors[key]
			if survivor.killer or not survivor.alive: continue
			var distance: float = view.position.distance_to(survivor.position)
			nearest = minf(nearest, distance)
			if not trigger and distance < CHASE_ENTER_DISTANCE and visible(view.position, survivor.position): trigger = true
		far = nearest > CHASE_EXIT_DISTANCE
	else:
		var hidden: bool = bool(killer.effects.get("shadow_hide", false))
		var gap: float = view.position.distance_to(killer.position)
		if not hidden:
			trigger = float(view.effects.get("chased", 0.0)) > 0.0 or (gap < CHASE_ENTER_DISTANCE and visible(view.position, killer.position))
		far = hidden or gap > CHASE_EXIT_DISTANCE
	if trigger:
		_chase_active = true
		_chase_release = 0.0
	elif _chase_active:
		_chase_release = _chase_release + delta if far else 0.0
		if _chase_release >= CHASE_RELEASE_TIME: _chase_active = false
	return _chase_active



func _update_audio_feedback() -> void :
	if not _audio_heartbeat and not _audio_hurt: return
	var beat: float = 0.0
	var hurt: float = 0.0
	if phase == "playing":
		var me: PaperActor = local_actor()
		if me and me.alive and not me.killer and not bool(me.effects.get("escaped", false)):
			var k: PaperActor = killer_actor()
			if k and not bool(k.effects.get("shadow_hide", false)):
				beat = smoothstep(32.0, 6.0, me.position.distance_to(k.position))
			if bool(me.effects.get("downed", false)): hurt = 1.0
			elif me.max_hp > 0.0: hurt = clampf((0.4 - me.hp / me.max_hp) / 0.4, 0.0, 1.0)
	if _audio_heartbeat: audio.set_heartbeat(beat)
	if _audio_hurt: audio.set_hurt(hurt)

func _nearest_survivor_distance(a: PaperActor) -> float:
	var d: float = INF
	for key: Variant in actors:
		var s: PaperActor = actors[key]
		if s.alive and not s.killer: d = minf(d, a.position.distance_to(s.position))
	return d



func _view_actor() -> PaperActor:
	var a: PaperActor = local_actor()
	if a and a.alive: return a
	if actors.has(spectate_id) and actors[spectate_id].alive: return actors[spectate_id]
	for key: Variant in actors:
		var survivor: PaperActor = actors[key]
		if survivor.alive and not survivor.killer: return survivor
	return killer_actor()


func _listener_position() -> Vector3:
	var view: PaperActor = _view_actor()
	if view: return view.position
	return camera.global_position if camera and camera.is_inside_tree() else Vector3.ZERO



func actor_render_position(a: PaperActor) -> Vector3:
	if not is_instance_valid(a): return Vector3.ZERO
	if not a.is_inside_tree(): return a.position
	return a.get_global_transform_interpolated().origin

func base_fov() -> float:
	return clampf(float(options.get("fov", 72.0)), 60.0, 95.0)


func shake_scale() -> float:
	if not bool(options.get("camera_shake", true)): return 0.0
	if bool(options.get("reduce_flashes", false)) or (ui and ui.reduced_motion): return 0.3
	return 1.0

func add_camera_trauma(amount: float) -> void :
	if camera_rig: camera_rig.add_trauma(amount)



func _camera_feedback(kind: String, data: Dictionary, a: PaperActor) -> void :
	if not camera_rig or phase != "playing": return
	var me: int = local_id()
	var actor_id: int = int(data.get("actor", -1))
	var source_id: int = int(data.get("source", -1))
	match kind:
		"hit", "stun":
			var heavy: float = 1.3 if kind == "stun" else 1.0
			if actor_id == me and a:
				var from: Vector3 = data.get("source_position", actors[source_id].position if actors.has(source_id) else a.position + a.aim)
				camera_rig.kick(a.position - from, 0.2 * heavy)
				camera_rig.punch(3.5 * heavy)
			elif source_id == me and not bool(data.get("indirect", false)):
				camera_rig.punch(-2.6 * heavy)
				if a and actors.has(me): camera_rig.kick(a.position - actors[me].position, 0.07)
		"block":
			if actor_id == me or source_id == me: camera_rig.punch(-2.4)
		"dash", "true_form_pounce", "boost_release":
			if actor_id == me: camera_rig.punch(6.0)
		"knockback":
			if actor_id == me:
				camera_rig.kick(data.get("direction", Vector3.ZERO), 0.22)
				camera_rig.punch(4.0)
		"phase6":
			if bool(data.get("active", false)): camera_rig.punch(8.0 if actor_id == me else 4.0)
		"lysia_explosion":
			var at: Vector3 = data.get("position", Vector3.ZERO)
			if camera and camera.is_inside_tree() and camera.global_position.distance_to(at) < 16.0:
				camera_rig.kick(camera.global_position - at, 0.25)
				camera_rig.punch(5.0)
		"grab":
			if bool(data.get("released", false)) and bool(data.get("wall", false)) and actor_id == me: camera_rig.punch(-3.5)

func _update_camera(delta: float) -> void :
	if kill_scenes and phase == "playing" and kill_scenes.camera_override(delta): return
	if camera_rig: camera_rig.update(delta)

func _update_reveals() -> void :
	if reveals: reveals.update_reveals()

func _sync_world_effects() -> void :
	presentation.sync_zones(zones)
	if archives: archives.sync(objective_progress, objective_done, self)

func _input(e: InputEvent) -> void :
	if online_menu and online_menu.visible:
		if e.is_action_pressed("ui_cancel") or e.is_action_pressed("pause_game"):
			online_menu.close();get_viewport().set_input_as_handled()
		return
	if controls_menu and controls_menu.visible: return
	bindings.observe(e)
	if phase == "playing" and not pause_open:
		var actor: PaperActor = local_actor()
		if actor and actor.active() and int(actor.effects.get("archive_qte_id", 0)) > 0:
			for index: int in range(3):
				if e.is_action_pressed("qte_" + str(index)):
					request_archive_qte(int(actor.effects.archive_qte_id), ["J", "K", "L"][index]);get_viewport().set_input_as_handled();return


	if phase == "gallery" and gallery and not gallery.browsing and gallery.handle_input(e):
		get_viewport().set_input_as_handled()

func _unhandled_input(e: InputEvent) -> void :
	if online_menu and online_menu.visible: return
	if controls_menu.visible or (mobile_controls and mobile_controls.editing): return
	if phase == "gallery" and gallery.handle_input(e):
		get_viewport().set_input_as_handled()
		return
	if e is InputEventKey and e.echo: return
	if e.is_action_pressed("pause_game") and phase == "playing":
		if ui.current_page == "settings" and ui.page.visible: ui._settings_back();return
		if emote_wheel.visible: emote_wheel.hide();capture_gameplay_mouse();return
		var actor: PaperActor = local_actor()
		if actor and (bool(actor.effects.get("spike_aiming", false)) or bool(actor.effects.get("grenade_aiming", false)) or bool(actor.effects.get("drone_piloting", false))): request_cancel_aim();return
		release_ability(1);bindings.controller_sprint = false;pause_open = not pause_open;Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if pause_open else Input.MOUSE_MODE_CAPTURED;ui.show_pause(pause_open);return
	if phase == "playing" and not pause_open:
		if e.is_action_pressed("emotes"): toggle_emotes();return
		if e.is_action_pressed("jump"): request_jump();return
		if e.is_action_pressed("cancel_aim"): request_cancel_aim();return
		if e.is_action_pressed("run_toggle"): bindings.controller_sprint = not bindings.controller_sprint;return
		if e.is_action_pressed("training_menu") and training: pause_open = true;Input.mouse_mode = Input.MOUSE_MODE_VISIBLE;ui.show_training_panel(true);return
		if e.is_action_pressed("spectate"): mobile_spectate();return
		if e.is_action_pressed("camera_mode"): camera_rig.toggle_mode();return
		for slot: int in range(6):
			if e.is_action_pressed("ability_" + str(slot)): request_ability(slot);return
			if e.is_action_released("ability_" + str(slot)): release_ability(slot);return
	if e is InputEventKey and e.pressed and e.keycode == KEY_F11 and not mobile_mode:
		toggle_fullscreen()
	if not mobile_mode and e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and phase == "playing" and not pause_open:
		camera_rig.mouse_look(e)
	if phase in ["menu", "lobby"] and e is InputEventJoypadButton and e.pressed and not get_viewport().gui_get_focus_owner():
		var buttons: Array[Node] = ui.page.find_children("*", "Button", true, false)
		if not buttons.is_empty(): buttons[0].grab_focus()

func local_addresses() -> String:
	var addresses: Array = []
	for ip: String in IP.get_local_addresses():
		if ip.contains(".") and not ip.begins_with("127.") and not ip.begins_with("169.254."): addresses.append(ip)
	return " / ".join(addresses) if not addresses.is_empty() else "127.0.0.1"

func _parse_test_args() -> void :
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--map" and i + 1 < args.size(): _rebuild_map(args[i + 1])
		if args[i] == "--simulate" and i + 1 < args.size(): test_mode = true;test_character = args[i + 1]
		if args[i] == "--duration" and i + 1 < args.size(): test_duration = float(args[i + 1])
		if args[i] == "--report" and i + 1 < args.size(): test_report = args[i + 1]
		if args[i] == "--capture" and i + 1 < args.size(): capture_path = args[i + 1]
		if args[i] == "--capture-at" and i + 1 < args.size(): capture_at = float(args[i + 1])
		if args[i] == "--host-test": test_host = true;test_mode = true
		if args[i] == "--join-test": test_client = true;test_mode = true
		if args[i] == "--speed" and i + 1 < args.size(): Engine.time_scale = clampf(float(args[i + 1]), 0.1, 12)
		if args[i] == "--seed" and i + 1 < args.size(): seed(int(args[i + 1]))
		if args[i] == "--scenario" and i + 1 < args.size(): test_scenario = args[i + 1]

		if args[i] == "--perf": perf.begin()
		if args[i] == "--orbit": _test_orbit = true
		if args[i] == "--capture-pose" and i + 1 < args.size(): _capture_pose = Array(args[i + 1].split(",")).map( func(value: String) -> float: return float(value))
		if args[i] == "--capture-wall": _capture_pose = ["wall"]
		if args[i] == "--capture-archive" and i + 1 < args.size(): _capture_pose = ["archive", int(args[i + 1])]
		if args[i] == "--menu-preview" and i + 1 < args.size(): preview_character = args[i + 1]
		if args[i] == "--menu-focus" and i + 1 < args.size(): menu_focus_x = clampf(float(args[i + 1]), 0.0, 1.0)

		if args[i] == "--tool" and i + 1 < args.size(): _load_tool(args[i + 1])
	if test_mode and test_duration <= 0: test_duration = 35
	if test_host: host_lan_room()
	elif test_client: join_lan_room("127.0.0.1")
	elif test_mode:
		selected = test_character if PaperData.NAMES.has(test_character) else "Ashura"
		await start_solo(test_character == "Alice");local_actor().bot = true

func _load_tool(tool_name: String) -> void :
	var path: String = "res://tools/" + tool_name.get_file().get_basename() + ".gd"
	if not ResourceLoader.exists(path): return
	var script: GDScript = load(path) as GDScript
	if script == null: return
	var node: Node = script.new()
	node.name = "Tool_" + tool_name
	add_child(node)
	if node.has_method("setup"): node.call("setup", self)

func _test_tick(delta: float) -> void :
	if not test_mode and capture_path.is_empty(): return
	test_elapsed += delta
	if test_client and phase == "playing":
		test_action_clock += delta
		if test_action_clock > 4:
			test_action_clock = 0
			request_ability(0)
	if test_mode and phase == "playing" and not scenario_started and not test_scenario.is_empty():
		scenario_started = true
		if test_scenario == "lms":
			for a: PaperActor in actors.values():
				if not a.killer and a.id != local_id(): eliminate(a)
		elif test_scenario == "survivor_win": time_left = 0.3
		elif test_scenario == "killer_win":
			var hunter: PaperActor = killer_actor()
			for a: PaperActor in actors.values():
				if not a.killer:
					if hunter: a.effects["death_source"] = hunter.id
					eliminate(a)
	if test_host and not test_started and test_elapsed > 3:
		test_started = true;start_multiplayer_round()
		if local_actor(): local_actor().bot = true
	if phase == "playing":
		if _test_orbit: yaw += delta * 0.6
		if not _capture_pose.is_empty(): _apply_capture_pose()
		if perf.enabled: perf.probe_camera(camera)
	if not capture_path.is_empty() and test_elapsed >= capture_at:
		var path: String = capture_path;capture_path = ""
		RenderingServer.force_draw()
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image();img.save_png(path);print("CAPTURE_SAVED ", path)
		if not test_mode: get_tree().quit()
	if test_mode and test_elapsed >= test_duration:
		var summary: Dictionary = {"map": selected_map, "phase": phase, "time": clock, "remaining": time_left, "archives": objective_done.size(), "objective_reduction": objective_seconds_removed, "lms": lms, "outcome": outcome, "events": event_count, "networked": networked, "roster_size": roster.size(), "snapshots_received": messages_received, "input_packets": input_packets, "remote_actions": remote_actions, "drones": drones, "training": training, "minions": minions, "projectiles": projectiles, "actors": []}
		for a: PaperActor in actors.values(): summary.actors.append({"id": a.id, "character": a.character, "hp": a.hp, "max_hp": a.max_hp, "alive": a.alive, "position": [a.position.x, a.position.y, a.position.z], "stamina": a.stamina, "effects": a.network_effects(), "cooldowns": a.cooldowns, "bot_state": str(a.bot_state)})
		if not test_report.is_empty():
			var f: FileAccess = FileAccess.open(test_report, FileAccess.WRITE);f.store_string(JSON.stringify(summary, "  "))
		if perf.enabled: print("PERF_SUMMARY ", JSON.stringify(perf.summary()))
		print("TEST_COMPLETE ", JSON.stringify(summary));get_tree().quit()



func _apply_capture_pose() -> void :
	var actor: PaperActor = local_actor()
	if not actor: return
	var spec: Array = _capture_pose
	_capture_pose = []
	var at: Vector3 = actor.position
	var look_yaw: float = yaw
	var look_pitch: float = pitch
	if spec.size() >= 4 and not spec[0] is String:
		at = Vector3(float(spec[0]), float(spec[1]), float(spec[2]))
		look_yaw = deg_to_rad(float(spec[3]))
		if spec.size() >= 5: look_pitch = float(spec[4])
	elif str(spec[0]) == "archive" and not objective_nodes.is_empty():
		var node: Node3D = objective_nodes[clampi(int(spec[1]), 0, objective_nodes.size() - 1)]
		var front: Vector3 = node.global_transform.basis.z
		var side: Vector3 = node.global_transform.basis.x
		at = node.global_position + front * 3.0 + side * 1.3
		var to_archive: Vector3 = node.global_position - side * 0.9 - at
		look_yaw = atan2( - to_archive.x, - to_archive.z)
		look_pitch = -0.05

		if authoritative(): objective_progress[clampi(int(spec[1]), 0, objective_nodes.size() - 1)] = 0.6
	elif str(spec[0]) == "wall":

		var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		var best: float = INF
		var best_direction: Vector3 = Vector3.BACK
		var best_point: Vector3 = at
		for step: int in range(16):
			var direction: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, TAU * step / 16.0)
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at + Vector3.UP * 1.5, at + Vector3.UP * 1.5 + direction * 40.0, 1)
			var hit: Dictionary = space.intersect_ray(query)
			if not hit.is_empty() and at.distance_to(hit.position) < best:
				best = at.distance_to(hit.position)
				best_direction = direction
				best_point = hit.position


		at = Vector3(best_point.x, at.y, best_point.z) - best_direction * 2.3
		look_yaw = atan2(best_direction.x, best_direction.z) + deg_to_rad(35.0)
		look_pitch = -0.35
	actor.bot = false
	actor.move_input = Vector3.ZERO
	actor.global_position = at
	actor.velocity = Vector3.ZERO
	actor.reset_physics_interpolation()
	yaw = look_yaw
	pitch = look_pitch
	camera_anchor_ready = false
	print("CAPTURE_POSE ", at, " yaw=", snappedf(rad_to_deg(look_yaw), 0.1), " pitch=", look_pitch)

func select_map(map_id: String) -> void :
	if networked and not authoritative():
		if can_manage_lobby(): lobby_command.rpc_id(1, "map", {"map": map_id})
		return
	if networked and room_options.mode == "training": map_id = "school"
	if phase not in ["menu", "lobby"] or (networked and not authoritative()): return
	_rebuild_map(map_id);save_preferences()
	if networked: _broadcast_roster();ui.show_lobby()
	elif ui.current_page not in ["characters", "alice"]: ui.show_main()

func _rebuild_map(map_id: String) -> void :
	if not MAP_NAMES.has(map_id): return
	selected_map = map_id
	if is_instance_valid(stage): remove_child(stage);stage.queue_free()
	stage_models.clear()
	if archives: archives.clear()
	objective_nodes.clear()
	if is_instance_valid(school): remove_child(school);school.queue_free()
	school = PaperSchool.new();add_child(school);school.build(selected_map, ruleset)
	_build_map_interactables()
	_build_objectives();_build_stage();_map_atmosphere()
	if mobile_quality: mobile_quality.map_rebuilt()

func _map_atmosphere() -> void :
	if not environment: return
	var profile: String = mobile_profile if mobile_mode else str(options.get("graphics", "high"))
	MapAtmosphere.apply(environment, selected_map, profile)
	if audio.has_method("set_surface"): audio.set_surface(selected_map)

func _hitbox_visual(data: Dictionary) -> void :
	presentation.hitbox(data)

func _shadow_visual(at: Vector3) -> void :
	presentation.shadow_ring(at)

@rpc("authority", "call_remote", "unreliable_ordered", 5)
func receive_entities(shadows: Array, grenades: Array, serial: int, drone_rows: Array = []) -> void :
	if serial != round_serial: return
	minions.clear();projectiles.clear();drones.clear()
	for row: Array in drone_rows:
		if row.size() >= 8: drones.append({"id": row[0], "owner": row[1], "position": row[2], "direction": row[3], "ttl": row[4], "state": row[5], "target": row[6], "age": row[7], "mode": str(row[8]) if row.size() > 8 else "quick"})
	for row: Array in shadows:
		if row.size() == 7: minions.append({"id": row[0], "owner": row[1], "position": row[2], "aim": row[3], "target": row[4], "ttl": row[5], "attack_cd": row[6]})
	for row: Array in grenades:
		if row.size() == 7: projectiles.append({"id": row[0], "owner": row[1], "position": row[2], "velocity": row[3], "ttl": row[4], "stage": "windup" if row[5] == 0 else "flight", "age": row[6]})

func request_cancel_aim() -> void :
	var actor: PaperActor = local_actor()
	if phase != "playing" or not actor: return
	if authoritative(): combat.cancel_aim(actor)
	else: command.rpc_id(1, "cancel_aim", {})

# Prologue « Yiero » : joué automatiquement au tout premier lancement (drapeau [story] intro_seen
# dans user://settings.cfg), puis seulement depuis la cinémathèque.
func _prologue_wanted() -> bool:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if dedicated or test_mode or networked or intro_seen or not capture_path.is_empty() or "--no-intro" in args: return false
	if ("--tool" in args or "--menu-preview" in args) and not "--first-launch" in args: return false
	for arg: String in args:
		if arg.begins_with("--server-host") or arg.begins_with("--join-ticket"): return false
	return prologue != null

func play_prologue() -> void :
	if prologue == null or networked or phase != "menu": return
	intro_seen = true;save_preferences()
	_prologue_map = selected_map
	if selected_map != "school": _rebuild_map("school")
	phase = "prologue";preview_character = ""
	stage.hide();presentation.clear_entities()
	for node: Node3D in objective_nodes: node.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	audio.preview_begin("Ashura", "ambient");audio.preview_pause(true)
	ui.show_film()
	prologue.begin_prologue(false)

func end_prologue() -> void :
	if phase != "prologue": return
	prologue.stop();ui.hide_film()
	audio.preview_end()
	if not _prologue_map.is_empty() and _prologue_map != selected_map: _rebuild_map(_prologue_map)
	_prologue_map = ""
	stage.show();presentation.show()
	for node: Node3D in objective_nodes: node.show()
	phase = "menu";ui.show_main()
	_update_camera(1.0)

# Le prologue a été interrompu de l'extérieur (connexion à un salon…) : on le nettoie sans revenir au menu.
func _abort_prologue() -> void :
	prologue.stop();ui.hide_film()
	audio.preview_end()
	_prologue_map = ""
	stage.show()
	for node: Node3D in objective_nodes: node.show()

func _begin_film(introduction: bool) -> void :
	var people: Array = []
	for actor: PaperActor in actors.values():
		if not actor.killer: people.append(actor.character)
	for actor: PaperActor in actors.values(): actor.visible = false

	stage.hide();presentation.clear_entities()
	for node: Node3D in objective_nodes: node.hide()
	_show_exit_sign(false)
	var kind: String = "intro_survivors" if cinema < SURVIVOR_INTRO_DURATION else "intro_alice"
	if not introduction: kind = ending_kind;people = ending_people.duplicate()
	film.begin(kind, people, ending_focus);ui.show_film();ending_presented = false
	_update_round_film(0.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _update_round_film(delta: float) -> void :
	var local_time: float = cinema
	if phase == "intro" and cinema >= SURVIVOR_INTRO_DURATION:
		if film.kind != "intro_alice": film.begin("intro_alice", [], "Alice")
		local_time = cinema - SURVIVOR_INTRO_DURATION
	film.update(local_time, delta);ui.update_film(film.chapter, film.caption, film.black)

func _end_film() -> void :
	film.stop();ui.hide_film();presentation.visible = true
	_show_exit_sign(true)
	for node: Node3D in objective_nodes: node.show()
	for actor: PaperActor in actors.values(): actor.visible = true
	if phase == "intro": capture_gameplay_mouse()

# Panneau de jeu « SORTIE · À 01:20 » (billboard au-dessus de la sortie) : caché pendant tous les films
# de fin, comme le font déjà les victoires LMS et le blocus (sinon il flotte devant la porte dans le film).
func _show_exit_sign(on: bool) -> void :
	if is_instance_valid(map_interactables) and is_instance_valid(map_interactables.exit_sign): map_interactables.exit_sign.visible = on

func _pack_entities(items: Array[Dictionary], grenades: bool) -> Array:
	var rows: Array = []
	for item: Dictionary in items:
		if grenades: rows.append([item.id, item.owner, item.position, item.velocity, item.ttl, 0 if item.stage == "windup" else 1, item.age])
		else: rows.append([item.id, item.owner, item.position, item.aim, item.target, item.ttl, item.attack_cd])
	return rows

func _round_context() -> Dictionary:
	return {"outcome": outcome, "lms": lms, "options": room_options, "training": training, "dummy_mode": practice.dummy_mode, "ending_people": ending_people.duplicate(), "ending_focus": ending_focus, "ending_kind": ending_kind, "last_victim": last_victim_name, "results": match_results, "exit": exit_flow.pack()}

func _pack_drones() -> Array:
	var rows: Array = []
	for d: Dictionary in drones: rows.append([d.id, d.owner, d.position, d.direction, d.ttl, d.state, d.target, d.get("age", 0.0), d.get("mode", "quick")])
	return rows

func start_training(solo: bool = true) -> void :
	if solo:
		leave_network();roster = {1: {"name": nickname, "character": selected, "malice": 0}}
	elif not authoritative(): return
	_clear_round()
	if selected_map != "school": _rebuild_map("school")
	presentation.prepare_shadows()
	training = true;phase = "playing";time_left = 0;clock = 0;cinema = 0;outcome = "";lms = false;stage.hide();round_serial += 1
	for key: Variant in roster: practice.add_player(int(key))
	if solo and solo_killer: practice.change_character(local_id(), "Alice", false)
	practice.ensure_dummies();practice.reset_all()
	var me: PaperActor = local_actor()
	capture_gameplay_mouse();yaw = atan2( - me.aim.x, - me.aim.z) if me else 0.0;ui.show_hud();audio.set_mode("ambient");_sync_round_for_clients()
	ui.toast("Terrain d'essai · F2 pour choisir un personnage, tester le LMS et réinitialiser.", 7)

func training_action(action: String, value: String = "") -> void :
	if not training or phase != "playing": return
	if authoritative(): practice.command(local_id(), action, value)
	else: request_training.rpc_id(1, action, value)

@rpc("any_peer", "call_remote", "reliable")
func request_training(action: String, value: String) -> void :
	if not authoritative() or not training or phase != "playing": return
	var sender: int = multiplayer.get_remote_sender_id()
	if not roster.has(sender) or not actors.has(sender): return
	var key: String = "training" + str(sender)
	if clock - float(request_times.get(key, -100.0)) < 0.15: return
	request_times[key] = clock;practice.command(sender, action.left(24), value.left(24))

@rpc("authority", "call_remote", "reliable")
func training_view(direction: Vector3) -> void :
	if training and direction.is_finite(): yaw = atan2( - direction.x, - direction.z)

func _loading_characters() -> Array:
	var result: Array = []
	for person: String in PaperData.NAMES + ["Alice"]:
		for actor: PaperActor in actors.values():
			if actor.character == person and not result.has(person): result.append(person)
	if result.is_empty():
		for row: Dictionary in roster.values():
			var person: String = str(row.get("character", "Ashura"))
			if not result.has(person): result.append(person)
	return result

func _loading_total() -> int:
	var count: int = 1
	if networked:
		for actor: PaperActor in actors.values():
			if not actor.bot and actor.id != 1: count += 1
	return count

func _loading_count() -> int:
	if not authoritative(): return loading_remote_count
	var count: int = 1
	for actor: PaperActor in actors.values():
		if not actor.bot and actor.id != 1 and bool(loading_ready.get(actor.id, false)): count += 1
	return count

func _loading_complete() -> bool:
	return not round_preparing and not actors.is_empty() and bool(loading_ready.get(1, false)) and _loading_count() >= _loading_total()

@rpc("any_peer", "call_remote", "reliable")
func round_loaded(serial: int) -> void :
	if not authoritative() or phase != "loading" or serial != round_serial: return
	var sender: int = multiplayer.get_remote_sender_id()
	if roster.has(sender) and actors.has(sender):
		loading_ready[sender] = true
		if networked: receive_loading_ready.rpc(_loading_count(), round_serial)

@rpc("authority", "call_remote", "reliable")
func receive_loading_ready(count: int, serial: int) -> void :
	if serial == round_serial and phase == "loading": loading_remote_count = clampi(count, 1, _loading_total())

@rpc("authority", "call_remote", "reliable")
func begin_play(serial: int) -> void :
	if serial != round_serial or phase != "loading" or round_preparing or actors.is_empty(): return
	phase = "playing";cinema = 0;ui.show_hud();capture_gameplay_mouse()
	if authoritative(): event("message", {"text": "La cloche a sonné. Rejoignez la sortie lorsqu’elle s’ouvrira à 1:20."})

func active_survivors() -> Array[PaperActor]:
	var result: Array[PaperActor] = []
	for actor: PaperActor in actors.values():
		if not actor.killer and actor.active(): result.append(actor)
	return result

func _has_dying_survivor() -> bool:
	for actor: PaperActor in actors.values():
		if not actor.killer and actor.alive and bool(actor.effects.get("dying", false)): return true
	return false

func _update_chased(delta: float) -> void :
	for actor: PaperActor in actors.values(): actor.effects["chased"] = maxf(0, float(actor.effects.get("chased", 0)) - delta)
	var killer: PaperActor = killer_actor()
	if not killer or not killer.active() or bool(killer.effects.get("shadow_hide", false)): return
	var chosen: PaperActor = null; var score: float = INF
	for actor: PaperActor in active_survivors():
		var offset: Vector3 = actor.position - killer.position;offset.y = 0
		var distance: float = offset.length()
		if distance > 18 or not visible(killer.position + Vector3.UP, actor.position + Vector3.UP): continue
		var alignment: float = killer.aim.normalized().dot(offset.normalized())
		if alignment < 0.35 or (distance > 7 and killer.velocity.length() < 1.5): continue
		var priority: float = distance - alignment * 7.0
		if priority < score: chosen = actor;score = priority
	if chosen: chosen.effects["chased"] = 3.0

func _archive_locks_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for index in range(school.objectives.size()):
		var remaining: float = combat.archive_lock_remaining(index)
		if remaining > 0: result[index] = clock + remaining
	return result

func archive_lock_remaining(index: int) -> float:
	if authoritative(): return combat.archive_lock_remaining(index)
	return maxf(0.0, float(archive_locks.get(index, 0.0)) - clock)

func request_archive_qte(challenge_id: int, key: String) -> void :
	if phase != "playing" or pause_open: return
	var actor: PaperActor = local_actor()
	if not actor or not actor.active(): return
	if authoritative(): combat.archive_qte(actor, challenge_id, key)
	elif networked: command.rpc_id(1, "archive_qte", {"id": challenge_id, "key": key})

func capture_gameplay_mouse() -> void :
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if mobile_mode or (emote_wheel and emote_wheel.visible) else Input.MOUSE_MODE_CAPTURED
	_update_mobile_controls()

func _update_mobile_controls() -> void :
	if not mobile_mode or not is_instance_valid(mobile_controls): return
	if mobile_controls.editing: return
	var usable: bool = phase == "playing" and not pause_open and mobile_focused and not ui.qte_panel.visible and not emote_wheel.visible
	if mobile_controls.enabled != usable:
		mobile_controls.cancel_all();mobile_controls.enabled = usable
	Input.emulate_mouse_from_touch = not usable
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mobile_controls.refresh(local_actor())
	if usable:
		var look: Vector2 = mobile_controls.consume_look()
		camera_rig.touch_look(look)

func mobile_pause() -> void :
	if phase != "playing": return
	pause_open = not pause_open
	if mobile_controls: mobile_controls.cancel_all()
	ui.show_pause(pause_open);capture_gameplay_mouse()

func mobile_training() -> void :
	if not training or phase != "playing": return
	pause_open = not pause_open
	if mobile_controls: mobile_controls.cancel_all()
	ui.show_training_panel(pause_open);capture_gameplay_mouse()

func mobile_spectate() -> void :
	if phase != "playing": return
	var alive: Array[PaperActor] = living_survivors()
	if alive.is_empty(): return
	var ids: Array = []
	for a: PaperActor in alive: ids.append(a.id)
	spectate_id = int(ids[(ids.find(spectate_id) + 1) % ids.size()])

func mobile_back() -> void :
	if not ui: return
	if emote_wheel and emote_wheel.visible: emote_wheel.close();return
	if ui.current_page == "settings" and ui.page.visible and phase == "playing": ui._settings_back();return
	if ui.qte_panel.visible: ui.qte_panel.hide();_update_mobile_controls();return
	if phase == "playing":
		if local_actor() and (bool(local_actor().effects.get("spike_aiming", false)) or bool(local_actor().effects.get("drone_piloting", false))): request_cancel_aim()
		else: mobile_pause()
	elif phase == "gallery":
		if gallery.browsing: gallery.close()
		else: gallery.browse()
	elif phase == "prologue": return
	elif phase == "loading": ui.toast("La carte se prépare…", 2)
	elif phase == "ending": quit_to_menu()
	else: ui.mobile_back()

func _notification(what: int) -> void :
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		if bindings: bindings.controller_sprint = false
		if combat: release_ability(1)
	if not mobile_mode: return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		mobile_focused = false
		if mobile_controls: mobile_controls.cancel_all()
		var actor: PaperActor = local_actor()
		if actor: actor.move_input = Vector3.ZERO;actor.sprint = false
		if phase == "playing" and not networked: pause_open = true;ui.show_pause(true)
		_update_mobile_controls()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		mobile_focused = true;_update_mobile_controls()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST: mobile_back()

func select_ruleset(value: String) -> void :
	if phase not in ["menu", "lobby"] or (networked and not authoritative()): return
	if networked: set_room_option("ruleset", value);return
	ruleset = "om";room_options["ruleset"] = "om"
	_rebuild_map(selected_map);save_preferences();ui.show_main()

func request_jump() -> void :
	if phase != "playing" or pause_open or ruleset != "om" or emote_wheel.visible: return
	var actor: PaperActor = local_actor()
	if not actor or not actor.active(): return
	if authoritative(): actor.request_jump(true)
	else: command.rpc_id(1, "jump", {})

func _drone_movement(input: Vector2, look: Vector3) -> Vector3:
	var side: Vector3 = Vector3.RIGHT.rotated(Vector3.UP, yaw)
	return (side * input.x - look * input.y).limit_length(1.0)

func _update_network_stats(delta: float) -> void :
	if not networked: ping_ms = -1
	elif authoritative(): ping_ms = 0
	else:
		_ping_timer += delta
		var now: int = Time.get_ticks_msec()
		for sequence: Variant in _ping_pending.keys():
			if now - int(_ping_pending[sequence]) > 5000: _ping_pending.erase(sequence)
		if _ping_last_reply > 0 and now - _ping_last_reply > 5000: ping_ms = -1
		if _ping_timer >= 1.0 and net and multiplayer.get_peers().has(1):
			_ping_timer = 0;_ping_sequence += 1;_ping_pending[_ping_sequence] = now
			ping_probe.rpc_id(1, _ping_sequence)
	if ui: ui.update_performance(ping_ms)

@rpc("any_peer", "call_remote", "unreliable", 6)
func ping_probe(sequence: int) -> void :
	if not networked or not authoritative(): return
	var sender: int = multiplayer.get_remote_sender_id()
	if not roster.has(sender): return
	ping_reply.rpc_id(sender, sequence)

@rpc("authority", "call_remote", "unreliable", 6)
func ping_reply(sequence: int) -> void :
	if authoritative() or not _ping_pending.has(sequence): return
	var now: int = Time.get_ticks_msec(); var sample: float = maxf(0, now - int(_ping_pending[sequence]))
	_ping_pending.erase(sequence);_ping_last_reply = now
	ping_ms = sample if ping_ms < 0 else lerpf(ping_ms, sample, 0.35)

func toggle_emotes() -> void :
	if emote_wheel.visible: emote_wheel.close();return
	var actor: PaperActor = local_actor()
	if phase != "playing" or pause_open or not actor or not actor.active() or actor.killer or bool(actor.effects.get("drone_piloting", false)): return
	emote_wheel.open()

func request_emote(id: String) -> void :
	if authoritative(): _start_emote(local_actor(), id)
	elif networked: command.rpc_id(1, "emote", {"id": id})

func _start_emote(actor: PaperActor, id: String) -> void :
	emote_sync.start(actor, id)

func _cancel_emote(actor: PaperActor) -> void :
	emote_sync.cancel(actor)



func _update_dance_music() -> void :
	emote_sync.update_music()

func _tick_emotes(delta: float) -> void :
	emote_sync.tick(delta)

func _build_accessibility() -> void :
	accessibility_layer = CanvasLayer.new();accessibility_layer.layer = 100;add_child(accessibility_layer)
	var filter: ColorRect = ColorRect.new();accessibility_layer.add_child(filter);filter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material: ShaderMaterial = ShaderMaterial.new();material.shader = preload("res://accessibility.gdshader");filter.material = material
	var config: ConfigFile = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		audio.music_volume = float(config.get_value("audio", "music", audio.music_volume));audio.muted = bool(config.get_value("audio", "muted", false));audio.effects_volume = float(config.get_value("audio", "effects", 1.0))
		audio.master_volume = clampf(float(config.get_value("audio", "master", 1.0)), 0.0, 1.0)

func apply_options() -> void :
	_sanitize_options()
	PaperLanguage.language = str(options.language)
	if accessibility_layer:
		accessibility_layer.visible = bool(options.colorblind)
		(accessibility_layer.get_child(0).material as ShaderMaterial).set_shader_parameter("colorblind", bool(options.colorblind))
	if mobile_quality:
		var profile: String = mobile_profile if mobile_mode else str(options.graphics)
		if profile == "high": mobile_quality.restore_desktop_profile()
		else: mobile_quality.set_profile(profile);mobile_quality.apply_mobile_profile()
	if ui: ui.reduced_motion = bool(options.reduce_flashes)
	_apply_display_options()

	_map_atmosphere()



func _apply_display_options() -> void :
	if mobile_mode or dedicated: return
	if DisplayServer.get_name() != "headless":
		var wanted: bool = bool(options.fullscreen) or _fullscreen_from_cmdline
		if _window_fullscreen() != wanted:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if wanted else DisplayServer.WINDOW_MODE_WINDOWED)
		var vsync: DisplayServer.VSyncMode = DisplayServer.VSYNC_ENABLED if bool(options.vsync) else DisplayServer.VSYNC_DISABLED
		if DisplayServer.window_get_vsync_mode() != vsync: DisplayServer.window_set_vsync_mode(vsync)
	Engine.max_fps = int(options.fps_limit)
	_apply_render_scale()

func _window_fullscreen() -> bool:
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN



func _apply_render_scale() -> void :
	if mobile_mode or dedicated or not is_inside_tree(): return
	var viewport: Viewport = get_viewport()
	var scale: float = clampf(float(options.get("render_scale", 1.0)), 0.5, 1.0)
	if mobile_quality and mobile_quality.enabled:
		viewport.scaling_3d_scale = minf(viewport.scaling_3d_scale, scale)
	else:
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		viewport.scaling_3d_scale = scale


func toggle_fullscreen() -> void :
	if mobile_mode: return
	options["fullscreen"] = not _window_fullscreen() if DisplayServer.get_name() != "headless" else not bool(options.get("fullscreen", false))
	_fullscreen_from_cmdline = false
	_apply_display_options()
	save_preferences()
