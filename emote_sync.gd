class_name PaperEmoteSync
extends Node

# Émotes et danses en partie : démarrage, synchronisation de groupe, fin, musique des
# danses, petits sons d'émotes et bots qui rejoignent l'émote d'un joueur.
#
# Tout le monde partage un temps commun : effects.emote_epoch (hôte uniquement) et
# effects.emote_time = clock - emote_epoch (envoyé aux clients). Deux survivants proches
# sur la même émote ont la même époque, donc la même phase d'animation, de son et de musique.
# Côté client, emote_time est extrapolé image par image entre deux instantanés.

const SFX: Dictionary = {
	"clap": ["clap", -4.0, 0.06], "slap": ["slap", -5.0, 0.05], "kiss": ["kiss", -7.0, 0.04],
	"shutter": ["shutter", -6.0, 0.02], "raspberry": ["raspberry", -6.0, 0.05], "heel": ["heel", -5.0, 0.04],
	"snap": ["snap", -6.0, 0.06], "stomp": ["stomp", -5.0, 0.05],
}
const SFX_REACH: float = 26.0
const BOT_JOIN_RANGE: float = 9.0
const BOT_JOIN_CHANCE: float = 0.7
const BOT_SAFE_DISTANCE: float = 24.0
const MUSIC_TOLERANCE: float = 0.15

var world: Node
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _music: Array[Dictionary] = []
var _pending: Array[Dictionary] = []
var _bot_until: Dictionary = {}
var _voices: Array[AudioStreamPlayer3D] = []
var _next_voice: int = 0
var _streams: Dictionary = {}
var _client_groups: Dictionary = {}

func setup(owner_world: Node) -> void :
	world = owner_world
	name = "EmoteSync"
	rng.randomize()



func start(actor: PaperActor, id: String) -> bool:
	if not actor or not actor.active() or actor.killer or world.phase != "playing" or not PaperEmotes.valid(id): return false
	if float(actor.effects.get("stun", 0)) > 0 or bool(actor.effects.get("drone_piloting", false)) or world.clock - float(actor.effects.get("last_emote", -10)) < 1: return false
	var clock: float = world.clock
	var epoch: float = clock
	var lead: PaperActor = _partner(actor, id)
	if lead:
		var shared: float = float(lead.effects.get("emote_epoch", clock))
		if clock - shared <= PaperEmotes.join_window(id):
			epoch = shared
		elif not PaperEmotes.holds(id):
			# Rejoint trop tard : tout le groupe recommence avec le nouveau venu.
			# (Pose tenue déjà installée : le nouveau venu fait sa propre entrée, le groupe reste assis.)
			for other: PaperActor in group(id, shared):
				other.effects["emote_epoch"] = clock
				other.effects["emote_time"] = 0.0
	actor.effects["emote_id"] = id
	actor.effects["emote_epoch"] = epoch
	actor.effects["emote_time"] = clock - epoch
	actor.effects["last_emote"] = clock
	if not actor.bot: _invite_bots(actor, id)
	return true

func cancel(actor: PaperActor) -> void :
	if not actor: return
	actor.effects.erase("emote_id");actor.effects.erase("emote_time");actor.effects.erase("emote_epoch")
	_bot_until.erase(actor.id)

func group(id: String, epoch: float) -> Array[PaperActor]:
	var result: Array[PaperActor] = []
	for other: PaperActor in world.actors.values():
		if str(other.effects.get("emote_id", "")) == id and absf(float(other.effects.get("emote_epoch", -1e9)) - epoch) < 0.001: result.append(other)
	return result

func _partner(actor: PaperActor, id: String) -> PaperActor:
	var best: PaperActor = null
	var best_distance: float = PaperEmotes.sync_range(id)
	for other: PaperActor in world.actors.values():
		if other == actor or not other.active() or str(other.effects.get("emote_id", "")) != id or not other.effects.has("emote_epoch"): continue
		var distance: float = other.position.distance_to(actor.position)
		if distance < best_distance:
			best = other
			best_distance = distance
	return best


func tick(_delta: float) -> void :
	var clock: float = world.clock
	for actor: PaperActor in world.actors.values():
		if not actor.effects.has("emote_id"): continue
		var id: String = str(actor.effects.emote_id)
		var t: float = clock - float(actor.effects.get("emote_epoch", clock))
		actor.effects["emote_time"] = t
		# Émote ponctuelle : finit avec le temps du groupe. Danse ou pose tenue : chacun garde sa
		# propre durée depuis son entrée (rejoindre un groupe tard ne coupe pas la danse).
		var looping: bool = PaperDances.is_dance(id) or PaperEmotes.holds(id)
		var elapsed: float = clock - float(actor.effects.get("last_emote", clock)) if looping else t
		if not actor.active() or actor.move_input.length_squared() > 0.02 or float(actor.effects.get("stun", 0)) > 0 or elapsed > PaperEmotes.duration(id): cancel(actor)
	_tick_bots()


# Côté client : les instantanés arrivent ~20 fois par seconde. Chaque groupe synchronisé (même
# émote, même époque) garde une horloge locale qui avance à chaque image et rattrape en douceur
# le temps de l'hôte (jamais de recul visible) ; tous les membres du groupe partagent la même.
func extrapolate(delta: float) -> void :
	var frame: int = Engine.get_physics_frames()
	for actor: PaperActor in world.actors.values():
		var fx: Dictionary = actor.effects
		if not fx.has("emote_id"): continue
		var fresh: bool = not fx.has("_emote_snap")
		var snap: float = float(fx.get("emote_time", 0.0)) if fresh else float(fx["_emote_snap"])
		var key: String = str(fx.emote_id) + "@" + str(snappedf(world.clock - snap, 0.05))
		var g: Dictionary = _client_groups.get(key, {})
		if g.is_empty():
			g = {"t": snap, "snap": snap, "age": 0.0, "frame": frame}
			_client_groups[key] = g
		elif int(g.frame) != frame:
			g.frame = frame
			if absf(snap - float(g.snap)) > 0.0001:
				g.snap = snap
				g.age = 0.0
			else:
				g.age = float(g.age) + delta
			var target: float = float(g.snap) + float(g.age)
			var error: float = target - float(g.t)
			if absf(error) > 0.35: g.t = target
			else: g.t = float(g.t) + delta * clampf(1.0 + error * 3.0, 0.4, 1.6)
		fx["_emote_snap"] = snap
		fx["emote_time"] = g.t
	for key: Variant in _client_groups.keys():
		if int(_client_groups[key].frame) < frame - 30: _client_groups.erase(key)



func update_music() -> void :
	# Un lecteur 3D par groupe de danseurs synchronisés (même danse, même époque). Les lecteurs
	# sont rattachés au groupe par son époque, pas par ses membres : quelqu'un qui rejoint ou
	# quitte le groupe ne coupe pas la musique.
	var clusters: Array[Dictionary] = []
	if world.phase == "playing":
		for actor: PaperActor in world.actors.values():
			var id: String = str(actor.effects.get("emote_id", ""))
			if not PaperDances.is_dance(id) or not actor.alive: continue
			var t: float = float(actor.effects.get("emote_time", 0.0))
			var epoch: float = _epoch_of(actor)
			var found: Dictionary = {}
			for cluster: Dictionary in clusters:
				if cluster.id == id and absf(float(cluster.epoch) - epoch) < MUSIC_TOLERANCE:
					found = cluster
					break
			if found.is_empty():
				found = {"id": id, "time": t, "epoch": epoch, "sum": Vector3.ZERO, "count": 0}
				clusters.append(found)
			found.sum += actor.position
			found.count += 1
	for entry: Dictionary in _music: entry.used = false
	for cluster: Dictionary in clusters:
		var stream: AudioStream = PaperDances.music(str(cluster.id))
		if stream == null: continue
		var entry: Dictionary = {}
		for candidate: Dictionary in _music:
			if not bool(candidate.used) and candidate.id == cluster.id and absf(float(candidate.epoch) - float(cluster.epoch)) < MUSIC_TOLERANCE:
				entry = candidate
				break
		var length: float = maxf(stream.get_length(), 0.1)
		var want: float = fposmod(float(cluster.time), length)
		var player: AudioStreamPlayer3D
		if entry.is_empty():
			player = AudioStreamPlayer3D.new();player.stream = stream;player.bus = world.audio.MUSIC_BUS;player.unit_size = 9.0;player.max_distance = 45.0;player.volume_db = 4.0
			add_child(player)
			entry = {"id": cluster.id, "epoch": cluster.epoch, "player": player, "used": false}
			_music.append(entry)
			player.play(want)
		player = entry.player
		entry.epoch = cluster.epoch
		entry.used = true
		player.global_position = cluster.sum / float(cluster.count) + Vector3.UP * 1.2
		if not player.playing: player.play(want)
		else:
			var drift: float = absf(player.get_playback_position() - want)
			if drift > 0.12 and drift < length - 0.12: player.seek(want)
	for i: int in range(_music.size() - 1, -1, -1):
		if not bool(_music[i].used):
			(_music[i].player as Node).queue_free()
			_music.remove_at(i)

# Époque du groupe : connue de l'hôte ; chez un client, déduite du dernier instantané.
func _epoch_of(actor: PaperActor) -> float:
	var fx: Dictionary = actor.effects
	if fx.has("emote_epoch"): return float(fx.emote_epoch)
	return world.clock - float(fx.get("_emote_snap", fx.get("emote_time", 0.0)))



func on_cue(cue: String, visual: PaperVisual) -> void :
	if not SFX.has(cue) or not is_instance_valid(visual) or not visual.is_inside_tree(): return
	var listener: Vector3 = world.camera.global_position if world.camera else visual.global_position
	if visual.global_position.distance_to(listener) > SFX_REACH: return
	var spec: Array = SFX[cue]
	var stream: AudioStream = _sfx_stream(str(spec[0]))
	if stream == null: return
	if _voices.size() < 8:
		var created: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		created.bus = &"PaperWorld" if AudioServer.get_bus_index(&"PaperWorld") >= 0 else &"Master"
		created.unit_size = 6.0
		created.max_distance = SFX_REACH
		add_child(created)
		_voices.append(created)
	var player: AudioStreamPlayer3D = _voices[_next_voice % _voices.size()]
	_next_voice += 1
	player.stream = stream
	player.volume_db = float(spec[1])
	player.pitch_scale = 1.0 + rng.randf_range(- float(spec[2]), float(spec[2]))
	player.global_position = visual.global_position + Vector3.UP * 1.3
	player.play()

func _sfx_stream(sfx_name: String) -> AudioStream:
	if _streams.has(sfx_name): return _streams[sfx_name]
	var path: String = "res://audio/emotes/%s.wav" % sfx_name
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_streams[sfx_name] = stream
	return stream



func _bot_safe(bot: PaperActor) -> bool:
	if not bot.active() or bool(bot.effects.get("chased", false)) or bool(bot.effects.get("downed", false)): return false
	for key: String in ["revive_target", "heal_target", "carrying_id", "carried_by", "grabbed_by"]:
		if int(bot.effects.get(key, -1)) >= 0: return false
	if float(bot.effects.get("heal_time", 0)) > 0 or bool(bot.effects.get("boost_charging", false)) or int(bot.effects.get("archive_qte_id", 0)) > 0: return false
	var killer: PaperActor = world.killer_actor()
	return killer == null or not killer.alive or killer.position.distance_to(bot.position) > BOT_SAFE_DISTANCE

func _invite_bots(actor: PaperActor, id: String) -> void :
	for other: PaperActor in world.actors.values():
		if not other.bot or other.killer or other == actor or other.effects.has("emote_id"): continue
		if other.position.distance_to(actor.position) > BOT_JOIN_RANGE or not _bot_safe(other): continue
		if rng.randf() > BOT_JOIN_CHANCE: continue
		# Un bot rejoint toujours à temps : il ne fait jamais redémarrer l'émote du joueur.
		var latest: float = 1.2 if PaperDances.is_dance(id) or PaperEmotes.holds(id) else clampf(PaperEmotes.join_window(id) * 0.85, 0.4, 1.2)
		_pending.append({"actor": other.id, "id": id, "at": world.clock + rng.randf_range(0.35, latest)})

func _tick_bots() -> void :
	for i: int in range(_pending.size() - 1, -1, -1):
		var plan: Dictionary = _pending[i]
		if world.clock < float(plan.at): continue
		_pending.remove_at(i)
		var bot: PaperActor = world.actors.get(int(plan.actor))
		var id: String = str(plan.id)
		if bot == null or bot.effects.has("emote_id") or not _bot_safe(bot) or _partner(bot, id) == null: continue
		bot.move_input = Vector3.ZERO
		if start(bot, id):
			var long: bool = PaperDances.is_dance(id) or PaperEmotes.holds(id)
			_bot_until[bot.id] = world.clock + (rng.randf_range(7.0, 14.0) if long else PaperEmotes.duration(id) + 0.3)

# Appelé par le cerveau des bots : vrai tant que le bot doit rester sur place pour son émote.
func holds_bot(actor: PaperActor) -> bool:
	if not _bot_until.has(actor.id): return false
	if not actor.effects.has("emote_id"):
		_bot_until.erase(actor.id)
		return false
	if world.clock > float(_bot_until[actor.id]) or not _bot_safe(actor):
		cancel(actor)
		return false
	return true

func clear() -> void :
	_pending.clear()
	_bot_until.clear()
	_client_groups.clear()
