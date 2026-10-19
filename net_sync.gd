class_name PaperNetSync
extends Node

# Réseau 0.17 : le joueur ne doit plus subir son ping.
# - Client : son propre perso bouge tout de suite (prédiction : même physique que l'hôte) ; il envoie
#   à chaque pas sa position, ses touches et l'instant de l'hôte que son écran montre. Quand l'hôte
#   reprend la main (coup, étourdissement, portage, film…) il suit l'hôte, puis repart en douceur.
# - Les autres acteurs sont affichés avec un petit retard adaptatif (tampon d'instantanés horodatés,
#   interpolation d'Hermite) : fluides même avec du jitter.
# - Hôte : il suit la position envoyée par le client, bornée (vitesse, hauteur, murs : net_motion.gd),
#   et juge les coups avec ce que chaque joueur voyait (net_lag.gd).
# - Instantanés à 30 par seconde dans un format binaire compact (net_codec.gd).

const SNAPSHOT_INTERVAL: float = 1.0 / 30.0
const IDLE_REPORT_INTERVAL: float = 0.1
const FOLLOW_REPORT_INTERVAL: float = 1.0 / 30.0
# Effets que le joueur local calcule lui-même pendant la prédiction (l'hôte ne les écrase pas).
const PREDICTED_KEYS: Array[String] = ["jump_cd", "jump_pending", "land_roll_time", "landing_boost_time", "roll_dash_time", "roll_direction", "grind_jump", "airborne", "air_time", "air_peak_delta", "running"]
# États où l'hôte garde la main sur le mouvement (le client le suit au lieu de prédire).
const OWNED_TIMERS: Array[String] = ["forced_time", "grab_time", "overheat_time", "stun", "root", "recover", "outlet_healing", "kill_lock"]
const OWNED_FLAGS: Array[String] = ["shadow_hide", "boost_charging", "drone_piloting", "grinding", "dying", "downed", "escaped", "motion_owned"]
const OWNED_IDS: Array[String] = ["grabbed_by", "carried_by"]

var world: Node
var lag: PaperNetLag
var stats: Dictionary = {"reports_sent": 0, "report_bytes": 0, "reports_received": 0, "snapshots_sent": 0, "snapshot_bytes": 0, "snapshots_received": 0, "entities_sent": 0, "world_sent": 0, "world_skipped": 0}

# Client : horloge d'affichage des autres acteurs (instant de l'hôte montré à l'écran).
var _view_t: float = 0.0
var _view_ready: bool = false
var _arrivals: Array = []
var _base: float = 0.0
var _buffer: float = 0.06
var _interval: float = SNAPSHOT_INTERVAL
var _last_t: float = -1.0
var _serial: int = -1
var _input: Array = []
var _report_wait: float = 0.0
var _last_report_pos: Vector3 = Vector3.INF
var _echo_until: float = -1.0

# Hôte
var _entities_quiet: float = 1.0
var _world_bytes: PackedByteArray = PackedByteArray()
var _world_age: float = 99.0


func _init() -> void :
	name = "NetSync"


func setup(owner: Node) -> void :
	world = owner
	lag = PaperNetLag.new(owner)


func reset() -> void :
	_view_ready = false;_arrivals.clear();_last_t = -1.0;_serial = -1;_buffer = 0.06
	_input = [];_report_wait = 0.0;_last_report_pos = Vector3.INF
	_entities_quiet = 1.0;_world_bytes = PackedByteArray();_world_age = 99.0
	if lag: lag.clear()


func _now() -> float:
	return Time.get_ticks_usec() / 1000000.0


# Instant de l'hôte que l'écran montre (les autres acteurs y sont dessinés).
func view_time() -> float:
	if world.authoritative() or not _view_ready: return float(world.clock)
	return _view_t


func view_delay() -> float:
	return _buffer


# Hôte : état où l'hôte garde la main sur le mouvement de l'acteur.
func _owned(a: PaperActor) -> bool:
	if not a.alive or not a.active(): return true
	var fx: Dictionary = a.effects
	for key: String in OWNED_TIMERS:
		var value: Variant = fx.get(key, 0.0)
		if (value is float or value is int or value is bool) and float(value) > 0.0: return true
	for key: String in OWNED_FLAGS:
		if bool(fx.get(key, false)): return true
	for key: String in OWNED_IDS:
		if int(fx.get(key, -1)) >= 0: return true
	return a.killer and float(world.clock) < 5.0 and not bool(world.training)


# --- Avant les pas des acteurs -------------------------------------------------------------------

func pre_tick(delta: float) -> void :
	if not bool(world.networked) or str(world.phase) != "playing": return
	if world.authoritative(): _host_pre_tick()
	else: _client_pre_tick(delta)


func _host_pre_tick() -> void :
	var peers: PackedInt32Array = multiplayer.get_peers()
	for a: PaperActor in world.actors.values():
		var m: PaperNetMotion = a.net_motion
		var remote: bool = not a.bot and int(a.id) != 1 and peers.has(int(a.id))
		m.remote = remote
		if not remote:
			a.net_follow = false
			continue
		var owned: bool = _owned(a)
		if owned and not m.owned: m.resync(a)
		m.owned = owned
		a.net_follow = not owned


func _client_pre_tick(delta: float) -> void :
	_advance_view(delta)
	var me: PaperActor = world.local_actor()
	for a: PaperActor in world.actors.values():
		if a == me and a.net_predicted: continue
		var s: Array = a.net_motion.sample_at(_view_t) if _view_ready else []
		if s.is_empty():
			a.net_exact = false
			continue
		a.net_position = s[0];a.net_velocity = s[1];a.net_exact = true
	if me != null: _local_mode(me, delta)


func _client_owned(a: PaperActor) -> bool:
	if not a.alive or not a.active(): return true
	var fx: Dictionary = a.effects
	for key: String in OWNED_TIMERS:
		var value: Variant = fx.get(key, 0.0)
		if (value is float or value is int or value is bool) and float(value) > 0.0: return true
	for key: String in OWNED_FLAGS:
		if bool(fx.get(key, false)): return true
	for key: String in OWNED_IDS:
		if int(fx.get(key, -1)) >= 0: return true
	return a.killer and float(world.clock) < 5.0 and not bool(world.training)


# Client : le joueur local prédit-il son mouvement, ou suit-il l'hôte ?
func _local_mode(me: PaperActor, delta: float) -> void :
	var m: PaperNetMotion = me.net_motion
	var can: bool = m.host_followed and not m.host_owned and m.host_epoch >= 0 and not me.bot and not _client_owned(me)
	if can and not me.net_predicted:
		me.net_predicted = true;me.net_exact = false
		m.epoch = m.host_epoch
		m.correction = m.host_pos - me.global_position
		me.velocity = m.host_vel
		if not me.movement_event.is_connected(_local_movement): me.movement_event.connect(_local_movement.bind(me))
	elif not can and me.net_predicted:
		me.net_predicted = false
		m.correction = Vector3.ZERO
	elif can and m.host_epoch != m.epoch:
		# L'hôte a repris la main ou refusé un déplacement : recalage en douceur sur sa position.
		m.epoch = m.host_epoch
		m.correction = m.host_pos - me.global_position
	if not me.net_predicted or m.correction == Vector3.ZERO: return
	if m.correction.length() > PaperActor.REMOTE_SNAP_DISTANCE:
		me.global_position += m.correction;m.correction = Vector3.ZERO
		me.reset_physics_interpolation()
		return
	var step: Vector3 = m.correction if m.correction.length() < 0.01 else m.correction * minf(1.0, delta * 12.0)
	me.global_position += step
	m.correction -= step


# Pas de prédiction : saut et roulade joués tout de suite chez soi (l'écho de l'hôte est ignoré).
func _local_movement(kind: String, payload: Dictionary, me: PaperActor) -> void :
	if not me.net_predicted or world.authoritative(): return
	if kind == "jump": me.net_motion.local_jumps += 1
	elif kind == "land_roll": me.net_motion.local_rolls += 1
	else: return
	_echo_until = _now() + 2.0
	var data: Dictionary = payload.duplicate()
	data["round_serial"] = world.round_serial
	world._event_local(kind, data)


func local_echo(kind: String, data: Dictionary) -> bool:
	if world.authoritative() or not kind in ["jump", "land_roll"]: return false
	return int(data.get("actor", -1)) == int(world.local_id()) and _now() < _echo_until


# Client : les touches de ce pas (appelé par _collect_input), envoyées après le pas physique.
func set_input(move: Vector3, aim: Vector3, sprint: bool) -> void :
	_input = [move, aim, sprint]


# --- Après les pas des acteurs -------------------------------------------------------------------

func post_tick(delta: float) -> void :
	if not bool(world.networked): return
	if world.authoritative():
		if str(world.phase) == "playing":
			lag.record()
			lag.tick()
		return
	_send_report(delta)


func _send_report(delta: float) -> void :
	var input: Array = _input
	_input = []
	if input.is_empty() or str(world.phase) != "playing": return
	var me: PaperActor = world.local_actor()
	if me == null: return
	var m: PaperNetMotion = me.net_motion
	var with_position: bool = me.net_predicted and m.correction.length() < 0.15
	var moving: bool = (input[0] as Vector3).length_squared() > 0.0001 or me.velocity.length_squared() > 0.0025 or (with_position and me.global_position.distance_squared_to(_last_report_pos) > 0.000025)
	_report_wait -= delta
	# En mouvement : un message par pas physique (60 par seconde) ; à l'arrêt ou en suivant l'hôte, moins.
	if not (with_position and moving) and _report_wait > 0.0: return
	_report_wait = IDLE_REPORT_INTERVAL if with_position else FOLLOW_REPORT_INTERVAL
	m.seq = (m.seq + 1) & 0xFFFF
	var flags: int = 0
	if with_position: flags |= PaperNetMotion.REPORT_FLAG_POSITION
	if me.is_on_floor(): flags |= PaperNetMotion.REPORT_FLAG_FLOOR
	if bool(input[2]): flags |= PaperNetMotion.REPORT_FLAG_SPRINT
	var packed: PackedByteArray = PaperNetCodec.encode_report(m.seq, m.epoch, flags, _now(), view_time(), me.global_position, me.velocity, input[0], input[1], m.local_jumps, m.local_rolls)
	_last_report_pos = me.global_position
	rx_report.rpc_id(1, packed)
	stats.reports_sent += 1;stats.report_bytes += packed.size()


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func rx_report(packed: PackedByteArray) -> void :
	if not world.authoritative() or not bool(world.networked) or str(world.phase) != "playing": return
	var sender: int = multiplayer.get_remote_sender_id()
	var a: PaperActor = world.actors.get(sender)
	if a == null or a.bot: return
	var report: Dictionary = PaperNetCodec.decode_report(packed)
	if report.is_empty(): return
	stats.reports_received += 1
	# Touches : mêmes vérifications qu'avant (submit_input lit l'expéditeur de ce message).
	world.submit_input(report.move, report.aim, (int(report.flags) & PaperNetMotion.REPORT_FLAG_SPRINT) != 0)
	var m: PaperNetMotion = a.net_motion
	_remote_movement(a, m, report)
	if bool(report.has_position) and (int(report.epoch) & 255) != (m.epoch & 255): report.has_position = false
	m.receive(report, float(world.clock))


# Hôte : sauts et roulades faits chez le client → mêmes événements qu'avant pour les autres.
func _remote_movement(a: PaperActor, m: PaperNetMotion, report: Dictionary) -> void :
	var jumps: int = int(report.jumps)
	var rolls: int = int(report.rolls)
	if m.jumps >= 0 and jumps != m.jumps and a.net_follow:
		a.movement_event.emit("jump", {"actor": a.id, "position": a.global_position, "velocity": report.vel})
	if m.rolls >= 0 and rolls != m.rolls and a.net_follow:
		a.effects["land_roll_time"] = 0.55;a.effects["landing_boost_time"] = 0.8
		m.roll_until = float(world.clock) + 0.4
		a.movement_event.emit("land_roll", {"actor": a.id, "position": a.global_position, "duration": 0.65, "boost_duration": 1.0, "height": 1.0})
	m.jumps = jumps;m.rolls = rolls


# --- Instantanés ---------------------------------------------------------------------------------

func send_snapshot() -> int:
	var packed: PackedByteArray = PaperNetCodec.encode_snapshot(world)
	rx_snapshot.rpc(packed)
	stats.snapshots_sent += 1;stats.snapshot_bytes += packed.size()
	# Ombres, grenades et drones : seulement s'il y en a (et quelques envois vides pour effacer).
	var busy: bool = not world.minions.is_empty() or not world.projectiles.is_empty() or not world.drones.is_empty()
	_entities_quiet = 0.0 if busy else _entities_quiet + SNAPSHOT_INTERVAL
	if busy or _entities_quiet < 0.5:
		world.receive_entities.rpc(world._pack_entities(world.minions, false), world._pack_entities(world.projectiles, true), world.round_serial, world._pack_drones())
		stats.entities_sent += 1
	return packed.size()


# État du monde (zones, archives, sortie) : fiable, seulement s'il a changé (rappel toutes les 2 s).
func send_world_state(delta: float) -> void :
	_world_age += delta
	var args: Array = [world.zones, world.objective_progress, world.objective_done, world.round_serial, world._archive_locks_snapshot(), world.exit_flow.pack()]
	var bytes: PackedByteArray = var_to_bytes(args)
	if bytes == _world_bytes and _world_age < 2.0:
		stats.world_skipped += 1
		return
	_world_bytes = bytes;_world_age = 0.0
	world.receive_world_state.rpc(args[0], args[1], args[2], args[3], args[4], args[5])
	stats.world_sent += 1


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func rx_snapshot(packed: PackedByteArray) -> void :
	if world.authoritative() or packed.size() > 262144: return
	var data: Dictionary = PaperNetCodec.decode_snapshot(packed)
	if data.is_empty(): return
	if not world.accept_snapshot(float(data.t), float(data.remaining), str(data.phase), bool(data.lms), int(data.door), int(data.serial)): return
	stats.snapshots_received += 1
	if int(data.serial) != _serial:
		_serial = int(data.serial);_view_ready = false;_arrivals.clear();_last_t = -1.0
	var t: float = float(data.t)
	_note_arrival(t)
	var me: PaperActor = world.local_actor()
	for row: Dictionary in data.rows:
		var a: PaperActor = world.actors.get(int(row.id))
		if a != null: _apply_row(a, row, a == me, t)


func _apply_row(a: PaperActor, row: Dictionary, mine: bool, t: float) -> void :
	var m: PaperNetMotion = a.net_motion
	var flags: int = int(row.flags)
	m.push_sample(t, row.pos, row.vel)
	if not a.net_exact: a.net_position = row.pos;a.net_velocity = row.vel
	var predicted: bool = mine and a.net_predicted
	if mine:
		m.host_followed = (flags & PaperNetCodec.ROW_FOLLOWED) != 0
		m.host_owned = (flags & PaperNetCodec.ROW_OWNED) != 0
		m.host_epoch = int(row.epoch)
		m.host_pos = row.pos;m.host_vel = row.vel
	if not predicted: a.aim = row.aim
	a.hp = float(row.hp);a.max_hp = float(row.max_hp);a.stamina = float(row.stamina);a.max_stamina = float(row.max_stamina)
	a.alive = (flags & PaperNetCodec.ROW_ALIVE) != 0;a.lms = (flags & PaperNetCodec.ROW_LMS) != 0
	for i: int in range(6): a.cooldowns[i] = float(row.cooldowns.get(i, 0.0))
	var fx: Dictionary = row.effects
	if predicted:
		for key: String in PREDICTED_KEYS:
			if a.effects.has(key): fx[key] = a.effects[key]
			else: fx.erase(key)
	a.effects = fx


# Client : horloge d'affichage. _base suit le paquet le plus rapide des 2 dernières secondes ;
# le tampon couvre l'intervalle entre deux instantanés plus le jitter mesuré.
func _note_arrival(t: float) -> void :
	var local: float = _now()
	_arrivals.append([local, t - local])
	while _arrivals.size() > 1 and local - float(_arrivals[0][0]) > 2.0: _arrivals.pop_front()
	if _last_t > 0.0 and t > _last_t: _interval = lerpf(_interval, clampf(t - _last_t, 0.005, 0.25), 0.1)
	_last_t = maxf(_last_t, t)
	var high: float = -INF
	for sample: Array in _arrivals: high = maxf(high, float(sample[1]))
	var spread: Array = []
	for sample: Array in _arrivals: spread.append(high - float(sample[1]))
	spread.sort()
	var jitter: float = float(spread[int(spread.size() * 0.8)])
	_base = high if not _view_ready or absf(high - _base) > 0.25 else move_toward(_base, high, 0.002)
	var wanted: float = clampf(_interval + jitter + 0.006, 0.03, 0.18)
	_buffer = move_toward(_buffer, wanted, 0.004 if wanted > _buffer else 0.0008)
	if not _view_ready:
		_view_t = local + _base - _buffer
		_view_ready = true


func _advance_view(delta: float) -> void :
	if not _view_ready: return
	var target: float = _now() + _base - _buffer
	var error: float = target - _view_t
	if absf(error) > 0.25: _view_t = target
	else: _view_t += delta * clampf(1.0 + error * 4.0, 0.9, 1.1)
