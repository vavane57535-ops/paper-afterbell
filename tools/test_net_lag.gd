extends Node

# Mesure du retard réseau avec un vrai hôte et un vrai client (même machine), reliés par
# tools/net_lag_proxy.py qui ajoute le ping et le jitter. Lancer plutôt tools/run_net_lag.sh.
#   hôte   : godot --headless -- --tool test_net_lag --lag-role host   --lag-port 28511 --lag-out DIR
#   client : godot --headless -- --tool test_net_lag --lag-role client --lag-port 28512 --lag-out DIR
# Le client (Elly) est piloté par des appuis de touches simulés ; Alice (l'hôte) par l'outil.
#   1. suivi : le client zigzague au sprint, chacun note ses positions (heure murale commune, et à
#      chaque pas physique) ; Alice fait des allers-retours (fluidité d'un acteur distant chez le client) ;
#   2. réactivité : départ arrêté, délai entre l'appui et le premier mouvement visible ;
#   3. recalage : l'hôte étourdit le client en pleine course (l'hôte reprend la main sur son
#      mouvement) : recul vu par le client et plus grand saut d'une image à l'autre ;
#   4. esquives : Alice griffe le client posté devant elle pendant qu'il esquive de côté, avec un
#      décalage δ variable (et des essais témoins sans esquive) ; l'hôte note touché/raté, le client
#      note si son écran le montrait dans la zone de la griffe quand le coup y est apparu.
# --lag-cheat (sur l'hôte) : à la place, le client joue un client modifié : vitesse doublée,
#   téléportation de 3 m, téléportation à travers un mur, fausse esquive par téléportation.
#   L'hôte doit borner sa vitesse, refuser les sauts, ne jamais le laisser traverser un mur, et le
#   toucher quand même (coups jugés sur les positions validées, pas sur celles annoncées).
# Chaque instance écrit son journal JSON dans DIR ; tools/net_lag_report.py les croise.
# L'outil fonctionne aussi sur l'ancien réseau (0.16), pour les mesures « avant ».

const CLAW_SIZE: Vector3 = Vector3(2.8, 2.2, 3.4)
const DODGE_DELAYS: Array[float] = [0.06, 0.1, 0.14, 0.18, 0.22, 0.26, 0.3, 0.36]
const CHEAT_DELAYS: Array[float] = [0.06, 0.1, 0.14, 0.18]

var world: Node
var role: String = "host"
var port: int = 28511
var out: String = "user://net_lag"
var label: String = ""
var step: String = "start"
var step_clock: float = 0.0
var clock: float = 0.0
var other: int = 0
var done: bool = false
var center: Vector3 = Vector3.ZERO
var forward: Vector3 = Vector3.FORWARD
var host_ticks: Array = []
var judged: Array = []
var client_frames: Array = []
var client_ticks: Array = []
var trials: Array = []
var reactions: Array = []
var stuns: Array = []
var cheats: Dictionary = {}
var net_stats: Dictionary = {}
var motion_stats: Dictionary = {}
var marks: Dictionary = {}
var _stat_from: float = -1.0
var _trial: Dictionary = {}
var _trial_index: int = -1
var _plan: Array = []
var _keys: Dictionary = {}
var _script_t: float = -1.0
var _script: Array = []
var _react: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var only_trials: bool = false
var cheat_mode: bool = false
var frames_dir: String = ""
var _frame_clock: float = -1.0
var _frame_index: int = 0
var _capturing: bool = false
var _shots: Dictionary = {}
var _stun_index: int = -1
var _stun: Dictionary = {}
var _run: Dictionary = {}
var _cheat: Dictionary = {}
var _wall_info: Dictionary = {}
var _yaw: float = 0.0


func setup(owner: Node) -> void :
	world = owner
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		var value: String = args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--lag-role": role = value
			"--lag-port": port = int(value)
			"--lag-out": out = value
			"--lag-label": label = value
			"--lag-only-trials": only_trials = true
			"--lag-cheat": cheat_mode = true
			"--lag-frames": frames_dir = value
	DirAccess.make_dir_recursive_absolute(out)
	_rng.seed = 1717
	_begin.call_deferred()


func _wall() -> float:
	return Time.get_unix_time_from_system()


func _log(text: String) -> void :
	print("NETLAG ", role, " ", text)


func _go(next: String) -> void :
	_log("step " + step + " -> " + next)
	step = next;step_clock = 0.0


func _motion(a: PaperActor) -> Variant:
	return a.get("net_motion") if a != null else null


func _begin() -> void :
	for i: int in range(4): await get_tree().process_frame
	# Comme un vrai poste à 60 i/s (en headless, la boucle tournerait sans limite).
	Engine.max_fps = 60
	world.leave_network()
	world.net = ENetMultiplayerPeer.new()
	if role == "host":
		if world.net.create_server(port, 6) != OK: _log("FAIL serveur");_end();return
		world.multiplayer.multiplayer_peer = world.net;world.networked = true
		world.nickname = "Hote";world.selected = "Simon"
		world.roster = {1: {"name": "Hote", "character": "Simon", "malice": 0}}
		world.phase = "lobby";world.stage.visible = true;world.ui.show_lobby()
		_go("wait_client")
	else:
		world.nickname = "Client";world.selected = "Elly"
		if world.net.create_client("127.0.0.1", port) != OK: _log("FAIL client");_end();return
		world.multiplayer.multiplayer_peer = world.net;world.networked = true;world.phase = "lobby";world.ui.show_lobby()
		_go("wait_round")


func _process(delta: float) -> void :
	if done or world == null: return
	clock += delta;step_clock += delta
	if clock > 190.0:
		_log("FAIL délai dépassé à l'étape " + step);_end();return
	if role == "host": _host_process()
	else: _client_process(delta)


func _physics_process(delta: float) -> void :
	if done or world == null or str(world.phase) != "playing": return
	if role != "host":
		_client_physics(delta)
		return
	if other == 0: return
	var a: PaperActor = world.actors.get(other)
	var alice: PaperActor = world.actors.get(1)
	if a == null or alice == null: return
	host_ticks.append([_wall(), float(world.clock), a.global_position.x, a.global_position.y, a.global_position.z, alice.global_position.x, alice.global_position.z])
	# Position que l'hôte utiliserait pour juger un coup porté à l'instant H (si la compensation existe).
	var lag: Variant = world.get("net_lag")
	if lag != null and lag.has_method("own_view_at"):
		var h: float = float(world.clock) - 0.3
		var view: Dictionary = lag.own_view_at(a, h)
		if bool(view.get("ok", false)):
			var p: Vector3 = view.position
			judged.append([h, p.x, p.y, p.z])
	# Mur : le corps du client chez l'hôte ne doit jamais passer de l'autre côté.
	if step == "cheat_wall" and not _wall_info.is_empty():
		var depth: float = (a.global_position - Vector3(_wall_info.point)).dot(Vector3(_wall_info.dir))
		cheats["wall_max_depth"] = maxf(float(cheats.get("wall_max_depth", -1000.0)), depth)


# --- Hôte ---------------------------------------------------------------------------------------

func _host_process() -> void :
	# Alice (le joueur de l'hôte) regarde toujours vers « forward » : sinon _collect_input la tourne.
	world.yaw = atan2(- forward.x, - forward.z)
	match step:
		"wait_client":
			if world.roster.size() < 2: return
			for key: Variant in world.roster:
				if int(key) != 1: other = int(key)
			world.set_room_option("survivors", 2)
			world.set_alice_choice("player", 1)
			_go("lobby")
		"lobby":
			if step_clock < 1.0: return
			world.start_multiplayer_round()
			_go("loading")
		"loading":
			if str(world.phase) != "playing": return
			_go("settle")
		"settle":
			if step_clock < 5.4: return
			_prepare_arena()
			_stats_begin()
			if cheat_mode:
				_go("cheat_speed_go")
				return
			if only_trials:
				marks["track"] = [_wall(), _wall()];marks["react"] = [_wall(), _wall()]
				_begin_trials(false)
				return
			rpc_client.rpc_id(other, "track", {"center": center, "forward": forward})
			marks["track"] = [_wall()]
			_go("track")
		"track":
			# Alice fait des allers-retours en marchant : fluidité d'un acteur distant chez le client.
			var lane: int = int(floor(step_clock / 0.7)) % 2
			_press(["left"] if lane == 0 else ["right"])
			if step_clock < 13.0: return
			_press([])
			marks.track.append(_wall())
			_place(Vector3.ZERO, false)
			rpc_client.rpc_id(other, "react", {})
			marks["react"] = [_wall()]
			_go("react")
		"react":
			if step_clock < 13.0: return
			marks.react.append(_wall())
			marks["stun"] = [_wall()]
			_stun_index = -1
			_go("stun_next")
		# Recalage : le client court, l'hôte l'étourdit (l'hôte reprend la main), puis le relâche.
		"stun_next":
			_stun_index += 1
			if _stun_index >= 4:
				marks.stun.append(_wall())
				_begin_trials(false)
				return
			_place(Vector3.ZERO, false)
			_go("stun_settle")
		"stun_settle":
			if step_clock < 1.0: return
			_stun = {"index": _stun_index, "side": "right" if _stun_index % 2 == 0 else "left", "sent": _wall()}
			rpc_client.rpc_id(other, "stun_run", {"side": _stun.side})
			_go("stun_run")
		"stun_run":
			if step_clock < 0.95: return
			var runner: PaperActor = world.actors.get(other)
			_stun["at"] = _wall();_stun["clock"] = float(world.clock)
			_stun["host_pos"] = [runner.global_position.x, runner.global_position.z]
			world.combat.stun(runner, 0.7, null)
			stuns.append(_stun)
			_go("stun_wait")
		"stun_wait":
			if step_clock < 1.7: return
			_go("stun_next")
		"trial_next":
			_trial_index += 1
			if _trial_index >= _plan.size():
				marks.trials.append(_wall())
				_stats_end()
				_capture_motion()
				rpc_client.rpc_id(other, "finish", {})
				_go("finish")
				return
			_trial = _plan[_trial_index].duplicate()
			_place(Vector3.ZERO, true)
			_go("trial_settle")
		"trial_settle":
			if step_clock < 1.2: return
			var victim: PaperActor = world.actors.get(other)
			victim.hp = victim.max_hp
			_trial["hp_before"] = victim.hp
			_trial["hits_before"] = int(world.event_count.get("hit", 0))
			_trial["dodge_wall"] = _wall() + 0.45
			_trial["swing_wall"] = float(_trial.dodge_wall) + float(_trial.delay)
			_trial["index"] = _trial_index
			rpc_client.rpc_id(other, "trial", {"index": _trial_index, "dodge_wall": _trial.dodge_wall, "dodge": _trial.dodge, "cheat": bool(_trial.get("cheat", false)), "delay_hint": float(_trial.delay)})
			_go("trial_wait_swing")
		"trial_wait_swing":
			if _wall() < float(_trial.swing_wall): return
			var alice: PaperActor = world.actors.get(1)
			alice.aim = forward;alice.cooldowns[0] = 0.0
			alice.effects["attack_lock"] = 0.0
			_trial["swing_clock"] = float(world.clock)
			_trial["swing_real"] = _wall()
			var victim: PaperActor = world.actors.get(other)
			_trial["victim_at_swing"] = [victim.global_position.x, victim.global_position.z]
			_trial["followed"] = bool(victim.get("net_follow"))
			var lag: Variant = world.get("net_lag")
			if lag != null: _trial["lag_before"] = lag.stats.duplicate()
			_trial["used"] = world.combat.use(alice, 0)
			_go("trial_result")
		"trial_result":
			if step_clock < 0.75: return
			var victim: PaperActor = world.actors.get(other)
			_trial["hit"] = victim.hp < float(_trial.hp_before) - 0.5 or int(world.event_count.get("hit", 0)) > int(_trial.hits_before)
			_trial["hp_after"] = victim.hp
			var lag: Variant = world.get("net_lag")
			var m: Variant = _motion(victim)
			if lag != null and m != null:
				_trial["lag_after"] = lag.stats.duplicate()
				var view: Dictionary = lag.own_view_at(victim, float(_trial.swing_clock))
				_trial["own_view_at_swing"] = [Vector3(view.position).x, Vector3(view.position).z, bool(view.ok)]
				_trial["epoch"] = m.epoch
				_trial["rejections"] = m.rejections
				_trial["view_lag"] = m.view_lag
			trials.append(_trial)
			_log("essai %d δ=%.2f %s → %s" % [_trial_index, float(_trial.delay), "triche" if bool(_trial.get("cheat", false)) else "esquive" if bool(_trial.dodge) else "témoin", "TOUCHÉ" if _trial.hit else "raté"])
			victim.hp = victim.max_hp
			_go("trial_next")
		# --- Client modifié (--lag-cheat) ---
		"cheat_speed_go":
			_place(Vector3.ZERO, false)
			_go("cheat_speed_settle")
		"cheat_speed_settle":
			if step_clock < 1.0: return
			cheats["speed_rejections_before"] = _count("rejections")
			marks["cheat_speed"] = [_wall()]
			rpc_client.rpc_id(other, "cheat_speed", {"duration": 3.0})
			_go("cheat_speed")
		"cheat_speed":
			if step_clock < 3.5: return
			marks.cheat_speed.append(_wall())
			cheats["speed_rejections"] = _count("rejections") - int(cheats.speed_rejections_before)
			_go("cheat_tp_go")
		"cheat_tp_go":
			_place(Vector3.ZERO, false)
			_go("cheat_tp_settle")
		"cheat_tp_settle":
			# Immobile 1,5 s : la réserve de rattrapage est pleine, le pire cas pour l'hôte.
			if step_clock < 1.5: return
			var victim: PaperActor = world.actors.get(other)
			cheats["tp_start"] = [victim.global_position.x, victim.global_position.z]
			cheats["tp_rejections_before"] = _count("rejections")
			marks["cheat_tp"] = [_wall()]
			rpc_client.rpc_id(other, "cheat_teleport", {"offset": Vector3(3.0, 0.0, 0.0)})
			_go("cheat_tp")
		"cheat_tp":
			var victim: PaperActor = world.actors.get(other)
			var moved: float = Vector2(victim.global_position.x - float(cheats.tp_start[0]), victim.global_position.z - float(cheats.tp_start[1])).length()
			cheats["tp_max_move"] = maxf(float(cheats.get("tp_max_move", 0.0)), moved)
			if step_clock < 1.2: return
			marks.cheat_tp.append(_wall())
			cheats["tp_rejections"] = _count("rejections") - int(cheats.tp_rejections_before)
			_go("cheat_wall_go")
		"cheat_wall_go":
			_wall_info = _find_wall()
			if _wall_info.is_empty():
				_log("pas de mur assez fin près de l'arène : essai du mur sauté")
				_begin_trials(true)
				return
			var victim: PaperActor = world.actors.get(other)
			var dir: Vector3 = _wall_info.dir
			victim.global_position = Vector3(_wall_info.point) - dir * 0.6 + Vector3.UP * 0.05
			victim.velocity = Vector3.ZERO;victim.net_position = victim.global_position
			victim.reset_physics_interpolation()
			var alice: PaperActor = world.actors.get(1)
			alice.global_position = Vector3(_wall_info.point) - dir * 8.0 + Vector3.UP * 0.05
			alice.reset_physics_interpolation()
			cheats["wall"] = {"point": [_wall_info.point.x, _wall_info.point.y, _wall_info.point.z], "dir": [dir.x, dir.z], "thickness": _wall_info.thickness}
			_go("cheat_wall_settle")
		"cheat_wall_settle":
			if step_clock < 1.2: return
			cheats["wall_rejections_before"] = _count("rejections")
			cheats["wall_max_depth"] = -1000.0
			marks["cheat_wall"] = [_wall()]
			var through: Vector3 = Vector3(_wall_info.dir) * (0.6 + float(_wall_info.thickness) + 0.7)
			rpc_client.rpc_id(other, "cheat_teleport", {"offset": through})
			_go("cheat_wall")
		"cheat_wall":
			if step_clock < 1.5: return
			marks.cheat_wall.append(_wall())
			cheats["wall_rejections"] = _count("rejections") - int(cheats.wall_rejections_before)
			_begin_trials(true)
		"finish":
			if step_clock < 2.5: return
			_write({"role": "host", "label": label, "cheat": cheat_mode, "ticks": host_ticks, "judged": judged, "trials": trials, "stuns": stuns, "cheats": cheats, "net": net_stats, "marks": marks, "motion": motion_stats, "center": [center.x, center.y, center.z], "forward": [forward.x, forward.z]})
			_end()


# Compteurs du suivi du client chez l'hôte, relevés avant son départ (l'acteur disparaît ensuite).
func _capture_motion() -> void :
	motion_stats = {}
	var m: Variant = _motion(world.actors.get(other))
	if m != null:
		motion_stats = {"rejections": m.rejections, "resyncs": m.resyncs, "delay": m.delay, "view_lag": m.view_lag, "offset": m.offset_min}
	var sync: Variant = world.get("net_sync")
	if sync != null: motion_stats["sync"] = sync.stats.duplicate()
	var lag: Variant = world.get("net_lag")
	if lag != null: motion_stats["lag"] = lag.stats.duplicate()


func _count(key: String) -> int:
	var m: Variant = _motion(world.actors.get(other))
	return int(m.get(key)) if m != null else 0


func _begin_trials(cheating: bool) -> void :
	marks["trials"] = [_wall()]
	_plan.clear()
	if cheating:
		for d: float in CHEAT_DELAYS: _plan.append({"delay": d, "dodge": true, "cheat": true})
	else:
		for repeat: int in range(2):
			for d: float in DODGE_DELAYS: _plan.append({"delay": d, "dodge": true})
			_plan.append({"delay": 0.2, "dodge": false})
	_trial_index = -1
	_go("trial_next")


# Terrain dégagé : on cherche, près des points d'apparition, l'endroit le plus loin des murs.
func _prepare_arena() -> void :
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var best: float = -1.0
	var candidates: Array = []
	for p: Vector3 in world.school.spawn_points: candidates.append(p)
	candidates.append(world.school.killer_spawn)
	for base: Vector3 in candidates.duplicate():
		for ring: int in range(1, 4):
			for k: int in range(8):
				candidates.append(base + Vector3(float(ring) * 4.0, 0, 0).rotated(Vector3.UP, TAU * k / 8.0))
	for p: Vector3 in candidates:
		var down: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2.0, p + Vector3.DOWN * 3.0, 1))
		if down.is_empty(): continue
		var floor_at: Vector3 = down.position
		var clearance: float = INF
		for k: int in range(16):
			var dir: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 16.0)
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(floor_at + Vector3.UP * 0.6, floor_at + Vector3.UP * 0.6 + dir * 12.0, 3))
			clearance = minf(clearance, 12.0 if hit.is_empty() else floor_at.distance_to(Vector3(hit.position)))
		if clearance > best: best = clearance;center = floor_at
	_log("arène %s dégagement %.1f m" % [str(center), best])
	forward = Vector3.FORWARD
	for actor: PaperActor in world.actors.values():
		if actor.id == 1 or actor.id == other: continue
		actor.bot = false;actor.move_input = Vector3.ZERO
		actor.global_position = center + Vector3(60, 0, 60);actor.velocity = Vector3.ZERO
		actor.reset_physics_interpolation()
	_place(Vector3.ZERO, false)


# Un mur fin (moins de 0,8 m) avec du sol des deux côtés, près de l'arène.
func _find_wall() -> Dictionary:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var best: Dictionary = {}
	var origins: Array = [center]
	for p: Vector3 in world.school.spawn_points: origins.append(p)
	for origin: Vector3 in origins:
		for k: int in range(16):
			var dir: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 16.0)
			var from: Vector3 = origin + Vector3.UP * 0.9
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * 14.0, 1))
			if hit.is_empty() or absf(Vector3(hit.normal).y) > 0.2: continue
			var near: Vector3 = hit.position
			var back: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(near + dir * 1.2, near + dir * 0.01, 1))
			if back.is_empty(): continue
			var thickness: float = Vector3(back.position).distance_to(near)
			if thickness > 0.8: continue
			var beyond: Vector3 = near + dir * (thickness + 0.7)
			var floor_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(beyond + Vector3.UP * 0.5, beyond + Vector3.DOWN * 2.0, 1))
			var floor_near: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(near - dir * 0.6 + Vector3.UP * 0.5, near - dir * 0.6 + Vector3.DOWN * 2.0, 1))
			if floor_hit.is_empty() or floor_near.is_empty(): continue
			var on_floor: Vector3 = Vector3(near.x, Vector3(floor_near.position).y, near.z)
			var score: float = from.distance_to(near)
			if best.is_empty() or score < float(best.score): best = {"point": on_floor, "dir": dir, "thickness": thickness, "score": score}
		if not best.is_empty(): break
	return best


func _place(offset: Vector3, duel: bool) -> void :
	var alice: PaperActor = world.actors.get(1)
	var victim: PaperActor = world.actors.get(other)
	var alice_at: Vector3 = center - forward * (1.0 if duel else 7.0) + Vector3.UP * 0.05
	alice.global_position = alice_at;alice.velocity = Vector3.ZERO;alice.move_input = Vector3.ZERO;alice.aim = forward
	alice.reset_physics_interpolation()
	victim.global_position = center + forward * 0.6 + offset + Vector3.UP * 0.05
	victim.velocity = Vector3.ZERO
	victim.net_position = victim.global_position
	victim.reset_physics_interpolation()
	for key: String in ["recover", "revive_invuln", "stun", "slow_time", "adrenaline", "boost_time", "help_aura", "land_roll_time", "landing_boost_time", "roll_dash_time"]:
		victim.effects.erase(key)


func _stats_begin() -> void :
	_stat_from = _wall()
	var host: ENetConnection = world.net.host
	if host == null: return
	for kind: int in [ENetConnection.HOST_TOTAL_SENT_DATA, ENetConnection.HOST_TOTAL_RECEIVED_DATA, ENetConnection.HOST_TOTAL_SENT_PACKETS, ENetConnection.HOST_TOTAL_RECEIVED_PACKETS]: host.pop_statistic(kind)


func _stats_end() -> void :
	var host: ENetConnection = world.net.host
	if host == null or _stat_from < 0.0: return
	var seconds: float = maxf(0.001, _wall() - _stat_from)
	net_stats = {"seconds": seconds,
		"sent_bytes_per_s": host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA) / seconds,
		"received_bytes_per_s": host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA) / seconds,
		"sent_packets_per_s": host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_PACKETS) / seconds,
		"received_packets_per_s": host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_PACKETS) / seconds}


# --- Client -------------------------------------------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func rpc_client(kind: String, data: Dictionary) -> void :
	match kind:
		"track":
			center = data.center;forward = data.forward
			# Zigzag au sprint : des paires aller/retour de durée variable (pas de dérive hors de l'arène).
			_script.clear()
			var t: float = 0.3
			while t < 11.5:
				var hold: float = _rng.randf_range(0.22, 0.5)
				var depth: String = ["", "forward", "back"][_rng.randi_range(0, 2)]
				var back: String = {"": "", "forward": "back", "back": "forward"}[depth]
				var first: Array = ["right", "sprint"];var second: Array = ["left", "sprint"]
				if depth != "": first.append(depth);second.append(back)
				_script.append([t, first]);t += hold
				_script.append([t, second]);t += hold
				if _rng.randf() < 0.3: _script.append([t, []]);t += _rng.randf_range(0.15, 0.35)
			_script.append([t, []])
			_script_t = 0.0
		"react":
			_react = {"count": 0, "next": 1.2}
			_script_t = -1.0;_press([])
		"stun_run":
			_run = {"side": str(data.side), "t": 0.0, "pressed": false, "released": false}
		"trial":
			_trial = data.duplicate()
			_trial["pressed"] = false;_trial["released"] = false
			_trial["seen"] = -1.0;_trial["inside"] = false;_trial["min_lateral"] = 99.0;_trial["frames"] = 0
			trials.append(_trial)
		"cheat_speed":
			_cheat = {"kind": "speed", "t": 0.0, "duration": float(data.duration)}
		"cheat_teleport":
			_cheat = {"kind": "teleport", "t": 0.0, "offset": data.offset, "done": false}
		"finish":
			_press([])
			_write({"role": "client", "label": label, "frames": client_frames, "ticks": client_ticks, "trials": trials, "reactions": reactions})
			_end.call_deferred()


func _press(keys: Array) -> void :
	for key: String in ["left", "right", "forward", "back", "sprint"]:
		var want: bool = key in keys
		if want and not bool(_keys.get(key, false)): Input.action_press(key)
		elif not want and bool(_keys.get(key, false)): Input.action_release(key)
		_keys[key] = want


# Client, à chaque pas physique (après celui du jeu) : positions sur une base de temps régulière,
# et le client modifié (vitesse doublée : un second déplacement identique, murs respectés).
func _client_physics(delta: float) -> void :
	var me: PaperActor = world.local_actor()
	var alice: PaperActor = world.actors.get(1)
	if me == null or alice == null: return
	var sync: Variant = world.get("net_sync")
	var view: float = float(sync.view_time()) if sync != null and sync.has_method("view_time") else -1.0
	var m: Variant = _motion(me)
	var correction: float = (m.correction as Vector3).length() if m != null else 0.0
	client_ticks.append([float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second), me.global_position.x, me.global_position.y, me.global_position.z, alice.global_position.x, alice.global_position.z, view, correction, 1 if bool(me.get("net_predicted")) else 0, _wall(), 1 if float(me.effects.get("stun", 0.0)) > 0.0 else 0])
	if _cheat.get("kind", "") == "speed" and float(_cheat.t) < float(_cheat.duration):
		var flat: Vector3 = Vector3(me.velocity.x, 0.0, me.velocity.z)
		if flat.length_squared() > 0.01: me.move_and_collide(flat * delta)


func _client_process(delta: float) -> void :
	if str(world.phase) != "playing": return
	world.yaw = _yaw
	var me: PaperActor = world.local_actor()
	var alice: PaperActor = world.actors.get(1)
	if me == null or alice == null: return
	var now: float = _wall()
	var shown: Vector3 = world.actor_render_position(me)
	var alice_shown: Vector3 = world.actor_render_position(alice)
	var t_view: float = -1.0
	var sync: Variant = world.get("net_sync")
	if sync != null and sync.has_method("view_time"): t_view = float(sync.view_time())
	var acting: bool = alice.visual.is_performing_action()
	client_frames.append([now, shown.x, shown.y, shown.z, alice_shown.x, alice_shown.z, 1 if acting else 0, t_view, float(world.clock), 1 if bool(me.get("net_predicted")) else 0])
	# Captures rendues (--lag-frames DIR), pour juger à l'œil : le zigzag (une image tous les 0,15 s),
	# puis chaque image autour du premier étourdissement et de la première esquive à δ = 0,14 s.
	if not frames_dir.is_empty() and not _capturing:
		_frame_clock += delta
		var stunned: bool = float(me.effects.get("stun", 0.0)) > 0.0
		if stunned and not _shots.has("stun"): _shots["stun"] = now
		if _script_t >= 0.0 and _frame_clock >= 0.15 and int(_shots.get("track_count", 0)) < 24:
			_frame_clock = 0.0;_shots["track_count"] = int(_shots.get("track_count", 0)) + 1
			_capture_frame("track")
		elif _shots.has("stun") and now - float(_shots.stun) < 0.6:
			_capture_frame("stun")
		elif not _trial.is_empty() and absf(float(_trial.get("delay_hint", -1.0)) - 0.14) < 0.001 and not _shots.has("dodge_done") and bool(_trial.get("pressed", false)) and now - float(_trial.get("press_real", now)) < 0.7:
			_capture_frame("dodge")
		elif not _trial.is_empty() and absf(float(_trial.get("delay_hint", -1.0)) - 0.14) < 0.001 and bool(_trial.get("pressed", false)) and now - float(_trial.get("press_real", now)) >= 0.7:
			_shots["dodge_done"] = true
	# Suivi : script de touches.
	if _script_t >= 0.0:
		_script_t += delta
		while not _script.is_empty() and _script_t >= float(_script[0][0]):
			_press(_script[0][1]);_script.pop_front()
		if _script.is_empty(): _script_t = -1.0;_press([])
	# Réactivité : départ arrêté, puis appui ; premier mouvement affiché.
	if not _react.is_empty():
		_react["next"] = float(_react.next) - delta
		if not _react.has("pressed_at") and float(_react.next) <= 0.0:
			_react["rest"] = shown;_react["pressed_at"] = now
			_press(["right" if int(_react.count) % 2 == 0 else "left", "sprint"])
		elif _react.has("pressed_at"):
			if not _react.has("moved_at") and Vector2(shown.x - Vector3(_react.rest).x, shown.z - Vector3(_react.rest).z).length() > 0.03: _react["moved_at"] = now
			if now - float(_react.pressed_at) > 0.45:
				_press([])
				reactions.append({"pressed": _react.pressed_at, "moved": _react.get("moved_at", -1.0), "delay_ms": (float(_react.get("moved_at", -1.0)) - float(_react.pressed_at)) * 1000.0 if _react.has("moved_at") else -1.0})
				_react["count"] = int(_react.count) + 1
				_react.erase("pressed_at");_react.erase("moved_at");_react["next"] = 1.1
				if int(_react.count) >= 8: _react.clear()
	# Recalage : course de côté pendant que l'hôte l'étourdit.
	if not _run.is_empty():
		_run["t"] = float(_run.t) + delta
		if not bool(_run.pressed) and float(_run.t) >= 0.25: _run["pressed"] = true;_press([_run.side, "sprint"])
		if not bool(_run.released) and float(_run.t) >= 2.0: _run["released"] = true;_press([]);_run.clear()
	# Client modifié.
	if not _cheat.is_empty():
		_cheat["t"] = float(_cheat.t) + delta
		match str(_cheat.kind):
			"speed":
				var lane: int = int(floor(float(_cheat.t) / 0.55)) % 2
				_press((["right"] if lane == 0 else ["left"]) + ["sprint"] if float(_cheat.t) < float(_cheat.duration) else [])
				if float(_cheat.t) >= float(_cheat.duration): _cheat.clear()
			"teleport":
				if not bool(_cheat.done) and float(_cheat.t) >= 0.2:
					_cheat["done"] = true
					me.global_position += Vector3(_cheat.offset)
					me.reset_physics_interpolation()
				if float(_cheat.t) >= 1.0: _cheat.clear()
	# Esquive : appui à l'heure dite (ou fausse esquive : téléportation) ; ce que montre l'écran
	# quand la griffe apparaît.
	if not _trial.is_empty() and _trial.has("dodge_wall"):
		if not bool(_trial.pressed) and now >= float(_trial.dodge_wall):
			_trial["pressed"] = true;_trial["press_real"] = now
			if bool(_trial.get("cheat", false)):
				me.global_position += Vector3(3.0, 0.0, 0.0)
				me.reset_physics_interpolation()
			elif bool(_trial.dodge): _press(["right", "sprint"])
		if bool(_trial.pressed) and not bool(_trial.released) and now >= float(_trial.dodge_wall) + 0.6:
			_trial["released"] = true;_press([])
		if acting and float(_trial.seen) < 0.0 and now > float(_trial.dodge_wall) - 0.2: _trial["seen"] = now
		if float(_trial.seen) > 0.0 and now - float(_trial.seen) <= 0.15:
			_trial["frames"] = int(_trial.frames) + 1
			var aim: Vector3 = Vector3(forward.x, 0, forward.z).normalized()
			var middle: Vector3 = alice_shown + aim * (CLAW_SIZE.z * 0.5 - 0.25) + Vector3.UP
			var offset: Vector3 = shown + Vector3.UP * 0.9 - middle
			var lateral: float = absf(offset.dot(aim.cross(Vector3.UP)))
			_trial["min_lateral"] = minf(float(_trial.min_lateral), lateral)
			if lateral <= CLAW_SIZE.x * 0.5 + 0.38 and absf(offset.dot(aim)) <= CLAW_SIZE.z * 0.5 + 0.38 and absf(offset.y) <= CLAW_SIZE.y * 0.5 + 0.9: _trial["inside"] = true


func _capture_frame(kind: String) -> void :
	_capturing = true
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	if image != null:
		DirAccess.make_dir_recursive_absolute(frames_dir)
		image.save_png(frames_dir.path_join("%s_%03d_%d.png" % [kind, _frame_index, int(round(fmod(_wall(), 1000.0) * 1000.0))]))
	_frame_index += 1
	_capturing = false


func _write(data: Dictionary) -> void :
	var path: String = out.path_join("%s.json" % role)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null: _log("FAIL écriture " + path);return
	file.store_string(JSON.stringify(data))
	file.close()
	_log("journal écrit " + path)


func _end() -> void :
	if done: return
	done = true
	_press([])
	_log("FIN")
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()
