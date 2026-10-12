extends RefCounted
class_name PaperCombat



const DRONE_BATTERY: float = 10.0
const DRONE_SPEED: float = 12.0
const DRONE_HOVER: float = 1.15
const ASSIST_PERIOD: float = 8.0
const BLEEDOUT_SECONDS: float = 30.0
const REVIVE_SECONDS: float = 4.0
const REVIVE_RANGE: float = 2.3
const ARCHIVE_QTE_SECONDS: float = 2.1
const ARCHIVE_LOCK_SECONDS: float = 3.0
const ARCHIVE_KEYS: Array[String] = ["J", "K", "L"]
const TIMED_EFFECTS: Array[String] = ["stun", "slow_time", "boost_time", "block", "counter", "phase6", "reveal", "xray", "blind", "root", "adrenaline", "help_aura", "phase_cooldown", "attack_lock", "revive_invuln", "speed_boost", "chocolate_eating", "stun_immunity"]
const OUTLET_DURATION: float = 15.0
const OUTLET_COOLDOWN: float = 30.0

const OUTLET_EMPTY_LOCKOUT: float = 2.0

const OUTLET_PRESS_GAP: float = 0.4
const OUTLET_PRESS_GRACE: float = 0.5
const FEEDBACK_GAP: float = 1.5
const ARCHIVE_FEEDBACK_GAP: float = 4.0

const PREVIEW_CACHE_MS: int = 100
const SLOW_ENTRIES: String = "slow_entries"
const BOOST_ENTRIES: String = "boost_entries"

var world
var _minion_bodies: Dictionary = {}
var _minion_paths: Dictionary = {}
var _next_minion: int = 1
var _next_projectile: int = 1
var _interact_at: Dictionary = {}
var _objective_at: Dictionary = {}
var _attacks: Array[Dictionary] = []
var _spike_waves: Array[Dictionary] = []
var _next_drone: int = 1
var _drone_bodies: Dictionary = {}
var _drone_paths: Dictionary = {}
var _revives: Dictionary = {}
var _archive_challenges: Dictionary = {}
var _archive_locks: Dictionary = {}
var _archive_next_check: Dictionary = {}
var _next_archive_challenge: int = 1
var _next_cast: int = 1

var _objective_actor: Dictionary = {}

var _feedback_at: Dictionary = {}

var _spike_preview: Dictionary = {}
var _arc_preview: Dictionary = {}
var _shape_query: PhysicsShapeQueryParameters3D

var _zone_sight: Dictionary = {}

func _init(owner):
	world = owner


func _message(actor, text: String, extra: Dictionary = {}) -> void :
	if actor == null or actor.bot: return
	var data: Dictionary = {"actor": actor.id, "text": text}
	if not extra.is_empty(): data.merge(extra)
	world.event("message", data)


func _feedback(actor, kind: String, text: String, gap: float = FEEDBACK_GAP) -> void :
	if actor == null or actor.bot: return
	var key: String = kind + str(actor.id)
	var now: float = float(world.clock)
	if now < float(_feedback_at.get(key, - INF)): return
	_feedback_at[key] = now + gap
	_message(actor, text)

func _stun_blocked(target) -> bool:
	return target != null and target.killer and (_effect(target, "stun_immunity") > 0.0 or _effect(target, "stun") > 0.0)


func _body_query(actor, point: Vector3) -> PhysicsShapeQueryParameters3D:
	if _shape_query == null: _shape_query = PhysicsShapeQueryParameters3D.new()
	_shape_query.shape = actor.collider.shape
	_shape_query.transform = Transform3D(Basis.IDENTITY, point + actor.collider.position)
	_shape_query.collision_mask = actor.collision_mask
	_shape_query.exclude = [actor.get_rid()]
	return _shape_query

func _reward(kind: String, actor, amount: float = 1.0, token: String = ""):
	var rewards = world.get("rewards")
	if rewards != null: rewards.record(kind, actor, amount, token)

func _reward_escape_boost(actor):
	var enemy = world.killer_actor()
	if _can_act(enemy) and actor.position.distance_to(enemy.position) <= 18.0 and _los(actor.position, enemy.position): _reward("boost", actor)

func lms_available(actor) -> bool:
	return actor != null and actor.lms and ( not _om(actor) or bool(actor.effects.get("lms_buff_unlocked", false)))

func _om(actor = null) -> bool:
	return true

func _can_act(actor) -> bool:
	return actor != null and actor.alive and not bool(actor.effects.get("downed", false)) and not bool(actor.effects.get("dying", false))

func _life_event(victim, source_id: int, cause: String) -> Dictionary:
	var source = _actor(source_id)
	return {"actor": victim.id, "source": source_id, "position": victim.position, "source_position": victim.position if source == null else source.position, "death_kind": cause, "attack": cause}

func _fatal_damage(victim, source_id: int, cause: String):
	if not _can_act(victim) or victim.killer: return
	_cancel_revive_for(victim)
	_interrupt_life_actions(victim)
	victim.effects["death_source"] = source_id
	victim.effects["death_kind"] = cause
	if victim.character != "Lysia" and not bool(victim.effects.get("revived", false)):
		victim.effects["downed"] = true
		_reward("down", _actor(source_id))
		victim.effects["bleedout"] = BLEEDOUT_SECONDS
		victim.effects["help_aura"] = BLEEDOUT_SECONDS
		var data: Dictionary = _life_event(victim, source_id, cause)
		data["bleedout"] = BLEEDOUT_SECONDS
		world.event("downed", data)
	else:
		_begin_death(victim, source_id, cause)

func _interrupt_life_actions(actor):
	_cancel_charge(actor)
	_release_carry(actor)
	_stop_outlet(actor)
	actor.effects["chocolate_hot"] = 0.0
	cancel_aim(actor)
	_cancel_channel(actor)
	_release_grab(actor, false)
	_release_overheat(actor)
	for other in world.actors.values():
		if int(other.effects.get("heal_target", -1)) == int(actor.id): _cancel_channel(other)
		if int(other.effects.get("grab_target", -1)) == int(actor.id): _release_grab(other, false)
		if int(other.effects.get("overheat_target", -1)) == int(actor.id): _release_overheat(other)
	actor.effects["forced_time"] = 0.0
	actor.effects["grenade_windup"] = 0.0
	actor.effects["block"] = 0.0
	actor.effects["counter"] = 0.0

	actor.effects["speed_boost"] = 0.0
	actor.effects["boost_level"] = 0
	actor.effects["attack_lock"] = 0.0
	actor.effects["chocolate_eating"] = 0.0
	actor.effects["grinding"] = false
	for key in ["stun", "root", "slow_time", "boost_time", "adrenaline", "blind"]: actor.effects[key] = 0.0
	actor.effects["slow_entries"] = [];actor.effects["boost_entries"] = []
	actor.move_input = Vector3.ZERO
	actor.velocity = Vector3.ZERO
	actor.sprint = false
	if _archive_challenges.has(actor.id): _fail_archive(actor.id, "interrupted")

func _begin_death(victim, source_id: int, cause: String):
	if victim == null or not victim.alive or bool(victim.effects.get("dying", false)): return
	_cancel_revive_for(victim)
	_interrupt_life_actions(victim)
	victim.effects["downed"] = false
	victim.effects["bleedout"] = 0.0
	victim.effects["dying"] = true
	_reward("elimination", _actor(source_id))
	victim.effects["death_time"] = 1.4
	victim.effects["death_kind"] = cause
	victim.effects["death_source"] = source_id
	var data: Dictionary = _life_event(victim, source_id, cause)
	data["duration"] = 1.4
	var source = _actor(source_id)


	data["execution"] = _can_act(source) and source.position.distance_to(victim.position) < 4.0 and cause != "bleedout"
	if bool(data.execution): source.effects["attack_lock"] = 1.4;source.effects["root"] = 1.4
	world.event("death_start", data)
	if victim.character == "Lysia":
		var enemy = world.killer_actor()
		if _can_act(enemy) and enemy.position.distance_to(victim.position) <= 7.0 and _los(victim.position, enemy.position): stun(enemy, 5.0, victim)
		_dispel_radius(victim.position, 7.0, victim.id)
		world.event("lysia_explosion", {"actor": victim.id, "position": victim.position, "radius": 7.0})

func _tick_lives(delta: float):
	for actor in world.actors.values():
		if actor == null or not actor.alive: continue
		actor.effects["recover"] = maxf(0.0, _effect(actor, "recover") - delta)
		actor.effects["lms_reveal"] = maxf(0.0, _effect(actor, "lms_reveal") - delta)
		if bool(actor.effects.get("dying", false)):
			actor.effects["death_time"] = maxf(0.0, _effect(actor, "death_time") - delta)
			if _effect(actor, "death_time") <= 0.0: world.eliminate(actor)
		elif bool(actor.effects.get("downed", false)):
			actor.effects["bleedout"] = maxf(0.0, _effect(actor, "bleedout") - delta)
			if _effect(actor, "bleedout") <= 0.0:
				_begin_death(actor, int(actor.effects.get("death_source", -1)), "bleedout")

func revive_preview(helper) -> Dictionary:
	var result: Dictionary = {"target": -1, "progress": 0.0, "remaining": REVIVE_SECONDS, "available": false, "busy": false, "label": ""}
	if not _can_act(helper) or helper.killer: return result
	var nearest: float = REVIVE_RANGE + 0.001
	for target in world.actors.values():
		if target == helper or not target.alive or not bool(target.effects.get("downed", false)) or target.character == "Lysia": continue
		var distance: float = helper.position.distance_to(target.position)
		if distance > nearest or not _los(helper.position, target.position): continue
		nearest = distance
		var owner: int = int(target.effects.get("revive_helper", -1))
		var busy: bool = owner >= 0 and owner != int(helper.id)
		var progress: float = float(target.effects.get("revive_progress", 0.0))
		var interrupted: bool = _effect(helper, "stun") > 0.0 or _effect(helper, "root") > 0.0 or _effect(helper, "forced_time") > 0.0 or _effect(helper, "recover") > 0.0
		result = {"target": target.id, "progress": progress, "remaining": 0.0 if _om(helper) else REVIVE_SECONDS * (1.0 - progress), "available": not busy and not interrupted, "busy": busy, "label": ("Déjà secouru · " if busy else "Impossible de secourir · " if interrupted else ("E · Réanimer " if _om(helper) else "Maintiens E · Réanimer ")) + str(target.character)}
	return result

func _interact_revive(helper) -> bool:
	var preview: Dictionary = revive_preview(helper)
	if int(preview.target) < 0: return false
	if not bool(preview.available): return true
	var target = _actor(int(preview.target))
	if _om(helper):
		_complete_revive(helper, target)
		return true
	if _revives.has(helper.id) and int(_revives[helper.id].target) != int(target.id): _cancel_revive(int(helper.id))
	if not _revives.has(helper.id):
		_revives[helper.id] = {"target": target.id, "origin": helper.position, "target_origin": target.position, "elapsed": 0.0, "last_pulse": float(world.clock)}
		helper.effects["revive_target"] = target.id
		target.effects["revive_helper"] = helper.id
		world.event("revive_start", {"actor": helper.id, "target": target.id, "duration": REVIVE_SECONDS, "position": helper.position})
	_revives[helper.id]["last_pulse"] = float(world.clock)
	return true

func _cancel_revive(helper_id: int):
	if not _revives.has(helper_id): return
	var job: Dictionary = _revives[helper_id]
	var helper = _actor(helper_id)
	var target = _actor(int(job.target))
	if helper != null: helper.effects["revive_target"] = -1;helper.effects["revive_progress"] = 0.0
	if target != null: target.effects["revive_helper"] = -1;target.effects["revive_progress"] = 0.0
	_revives.erase(helper_id)
	world.event("revive_cancel", {"actor": helper_id, "target": int(job.target)})

func _cancel_revive_for(actor):
	if actor == null: return
	for helper_id in _revives.keys():
		if int(helper_id) == int(actor.id) or int(_revives[helper_id].target) == int(actor.id): _cancel_revive(int(helper_id))

func detach_actor(actor_id: int):


	var actor = _actor(actor_id)
	if actor != null:
		_cancel_charge(actor);_release_carry(actor);_stop_outlet(actor)
	_cancel_revive_for(actor)
	if _archive_challenges.has(actor_id): _fail_archive(actor_id, "disconnected")
	_interact_at.erase(actor_id)
	if actor != null:
		actor.effects["revive_target"] = -1;actor.effects["revive_helper"] = -1;actor.effects["revive_progress"] = 0.0

func _tick_revives(delta: float):
	for helper_id in _revives.keys():
		var job: Dictionary = _revives[helper_id]
		var helper = _actor(int(helper_id))
		var target = _actor(int(job.target))
		if not _can_act(helper) or target == null or not target.alive or not bool(target.effects.get("downed", false)):
			_cancel_revive(int(helper_id));continue
		if float(world.clock) - float(job.last_pulse) > 0.38 or helper.move_input.length() > 0.1 or helper.position.distance_to(job.origin) > 0.25 or target.position.distance_to(job.target_origin) > 0.3 or helper.position.distance_to(target.position) > REVIVE_RANGE or not _los(helper.position, target.position) or _effect(helper, "stun") > 0.0 or _effect(helper, "forced_time") > 0.0:
			_cancel_revive(int(helper_id));continue
		job["elapsed"] = float(job.elapsed) + delta
		var progress: float = clampf(float(job.elapsed) / REVIVE_SECONDS, 0.0, 1.0)
		helper.effects["revive_progress"] = progress
		target.effects["revive_progress"] = progress
		if progress < 1.0: continue
		_revives.erase(helper_id)
		_complete_revive(helper, target)

func _complete_revive(helper, target):
	helper.effects["revive_target"] = -1;helper.effects["revive_progress"] = 0.0
	target.effects["revive_helper"] = -1;target.effects["revive_progress"] = 0.0
	target.effects["downed"] = false;target.effects["bleedout"] = 0.0
	target.effects["help_aura"] = 0.0
	target.effects["revived"] = true;target.effects["recover"] = 0.0 if _om(target) else 1.0
	if _om(target):
		target.effects["revive_invuln"] = 5.0
		_speed(target, PaperRules.OM_BOOST_FACTOR, 5.0)
	_reward("revive", helper, 1.0, "revive_%d" % int(target.id))
	target.hp = minf(float(target.max_hp), clampf(float(target.max_hp) * 0.4, 35.0, 60.0))
	world.event("revived", {"actor": target.id, "helper": helper.id, "position": target.position, "hp": target.hp})

func archive_lock_remaining(index: int) -> float:
	return maxf(0.0, float(_archive_locks.get(index, 0.0)) - float(world.clock))

func archive_locks_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for index in _archive_locks.keys():
		var remaining: float = archive_lock_remaining(int(index))
		if remaining > 0.0: result[int(index)] = remaining
	return result

func reset_archives_for_training():
	if not world.training: return
	for actor_id in _archive_challenges.keys(): _clear_archive_qte(int(actor_id))
	_archive_locks.clear();_archive_next_check.clear();_objective_at.clear();_objective_actor.clear()
	world.objective_done.clear();world.objective_progress.clear()
	for actor in world.actors.values():
		actor.effects["archive_index"] = -1;actor.effects["archive_lock"] = 0.0;actor.effects["archive_alarm"] = 0.0

func _archive_busy(index: int, except_id: int = -1) -> bool:
	for actor_id in _archive_challenges:
		if int(actor_id) != except_id and int(_archive_challenges[actor_id].index) == index: return true
	return false

func _begin_archive_qte(actor, index: int):
	var key_index: int = randi_range(0, ARCHIVE_KEYS.size() - 1)
	var challenge: Dictionary = {"id": _next_archive_challenge, "index": index, "key": key_index, "started": float(world.clock), "expires": float(world.clock) + ARCHIVE_QTE_SECONDS}
	_next_archive_challenge += 1
	_archive_challenges[actor.id] = challenge
	actor.effects["archive_qte_id"] = int(challenge.id)
	actor.effects["archive_qte_key"] = key_index
	actor.effects["archive_qte_remaining"] = ARCHIVE_QTE_SECONDS
	actor.effects["archive_qte_duration"] = ARCHIVE_QTE_SECONDS
	actor.effects["archive_index"] = index
	world.event("archive_qte", {"actor": actor.id, "index": index, "id": int(challenge.id), "key": ARCHIVE_KEYS[key_index], "remaining": ARCHIVE_QTE_SECONDS, "ready": true})

func _clear_archive_qte(actor_id: int):
	_archive_challenges.erase(actor_id)
	var actor = _actor(actor_id)
	if actor != null:
		actor.effects["archive_qte_id"] = 0
		actor.effects["archive_qte_remaining"] = 0.0

func archive_qte(actor, challenge_id: int, key: String) -> bool:


	if world.has_method("authoritative") and not world.authoritative(): return false
	if str(world.phase) != "playing" or not _can_act(actor) or not _archive_challenges.has(actor.id): return false
	var challenge: Dictionary = _archive_challenges[actor.id]
	if int(challenge.id) != challenge_id: return false
	var elapsed: float = float(world.clock) - float(challenge.started)
	var point: Vector3 = world.school.objectives[int(challenge.index)]
	if float(world.clock) > float(challenge.expires) or elapsed < 0.18 or key.to_upper() != ARCHIVE_KEYS[int(challenge.key)] or actor.position.distance_to(point) > 2.8 or not _los(actor.position, point) or actor.move_input.length() > 0.1 or _effect(actor, "stun") > 0.0:
		_fail_archive(actor.id, "missed");return false
	_clear_archive_qte(actor.id)
	_archive_next_check[int(challenge.index)] = float(world.objective_progress.get(int(challenge.index), 0.0)) + randf_range(0.14, 0.19)
	world.event("archive_qte", {"actor": actor.id, "index": int(challenge.index), "id": challenge_id, "ready": false, "success": true})
	return true

func _fail_archive(actor_id: int, reason: String):
	if not _archive_challenges.has(actor_id): return
	var challenge: Dictionary = _archive_challenges[actor_id]
	var index: int = int(challenge.index)
	_clear_archive_qte(actor_id)
	_archive_locks[index] = float(world.clock) + ARCHIVE_LOCK_SECONDS

	var actor = _actor(actor_id)
	if actor != null: actor.effects["archive_alarm"] = 8.0;actor.effects["archive_lock"] = ARCHIVE_LOCK_SECONDS
	world.event("archive_qte", {"actor": actor_id, "index": index, "id": int(challenge.id), "ready": false, "success": false, "reason": reason})
	world.event("archive_alarm", {"actor": actor_id, "index": index, "position": world.school.objectives[index], "duration": 8.0, "lock": ARCHIVE_LOCK_SECONDS})

func _tick_archives(delta: float):
	for actor in world.actors.values():
		actor.effects["archive_alarm"] = maxf(0.0, _effect(actor, "archive_alarm") - delta)
		var index: int = int(actor.effects.get("archive_index", -1))
		if index >= 0: actor.effects["archive_lock"] = archive_lock_remaining(index)
	for actor_id in _archive_challenges.keys():
		var challenge: Dictionary = _archive_challenges[actor_id]
		var actor = _actor(int(actor_id))
		if actor == null: _clear_archive_qte(int(actor_id));continue
		var point: Vector3 = world.school.objectives[int(challenge.index)]
		actor.effects["archive_qte_remaining"] = maxf(0.0, float(challenge.expires) - float(world.clock))
		if not _can_act(actor) or float(world.clock) > float(challenge.expires) or actor.position.distance_to(point) > 2.8 or actor.move_input.length() > 0.1 or not _los(actor.position, point) or _effect(actor, "stun") > 0.0: _fail_archive(int(actor_id), "timeout" if float(world.clock) > float(challenge.expires) else "interrupted")

func use(actor, slot: int, target_id: int = -1) -> bool:
	if not _can_act(actor) or str(world.phase) != "playing":
		return false
	if slot < 0 or slot >= (6 if actor.killer else 4): return false

	if actor.character == "Lysia" and slot == 3 and _effect(actor, "outlet_healing") > 0:
		_stop_outlet(actor, "cancelled")
		return true
	if bool(actor.effects.get("boost_charging", false)) or _effect(actor, "outlet_healing") > 0 or int(actor.effects.get("carried_by", -1)) >= 0: return false

	if actor.killer and bool(actor.effects.get("spike_aiming", false)) and slot == 0: slot = 2
	if bool(actor.effects.get("drone_piloting", false)) or bool(actor.effects.get("shadow_hide", false)) or _effect(actor, "forced_time") > 0.0 or _effect(actor, "attack_lock") > 0.0 or _effect(actor, "recover") > 0.0 or _revives.has(actor.id): return false
	if actor.killer and slot == 5 and _effect(actor, "stun") > 0.0 and _effect(actor, "rage") >= 100.0 and not bool(actor.effects.get("true_form_used", false)):
		_feedback(actor, "true_form_stun", "TRUE FORM prête · active-la après le stun !")
		return false
	if _effect(actor, "stun") > 0.0 or _effect(actor, "grab_time") > 0.0 or _effect(actor, "overheat_time") > 0.0 or _effect(actor, "overheat_charge") > 0 or _effect(actor, "heal_time") > 0.0:
		return false
	var counter: bool = actor.character == "Usayuko" and slot == 1 and _effect(actor, "counter") > 0.0
	if _effect(actor, "root") > 0.0 and not counter:
		return false
	if float(actor.cooldowns.get(slot, 0.0)) > 0.0 and not counter:
		return false
	var success: bool = false
	match str(actor.character):
		"Alice": success = _alice(actor, slot)
		"Ashura": success = _ashura(actor, slot)
		"Usayuko": success = _usayuko(actor, slot)
		"Simon": success = _simon(actor, slot)
		"Lysia": success = _lysia(actor, slot)
		"Elly": success = _elly(actor, slot, target_id)
		"Bleuette": success = _bleuette(actor, slot, target_id)
	if not success and not actor.killer: success = _support_against_minion(actor, slot)
	if success:
		if not actor.killer: _dispel_support_minions(actor, slot)
		if not (actor.killer and slot == 2 and bool(actor.effects.get("spike_aiming", false))) and not (actor.character == "Simon" and slot == 0 and bool(actor.effects.get("grenade_aiming", false))):
			world.event("ability", {"actor": actor.id, "name": "Contre" if counter else ("Flash Mode" if slot == 2 else "Flash Punch" if bool(actor.effects.get("flash_melee", false)) else "Flashbang") if _om(actor) and actor.character == "Simon" and slot in [0, 2] else _ability_name(actor.character, slot), "slot": slot, "position": actor.position})
	return success

func tick(delta: float):
	if str(world.phase) != "playing":
		return
	_tick_lives(delta)
	_tick_revives(delta)
	_tick_archives(delta)
	for actor in world.actors.values():
		if actor == null:
			continue

		for slot in actor.cooldowns:
			var remaining: float = float(actor.cooldowns[slot])
			if remaining > 0.0: actor.cooldowns[slot] = maxf(0.0, remaining - delta)
		if not _can_act(actor):
			cancel_aim(actor)
			_cancel_channel(actor)
			_release_grab(actor, false)
			_release_overheat(actor)
			continue
		var was_phase: bool = _effect(actor, "phase6") > 0.0
		var was_stunned: bool = _effect(actor, "stun") > 0.0
		for key in TIMED_EFFECTS:
			var value: Variant = actor.effects.get(key)
			if value != null and float(value) > 0.0:
				actor.effects[key] = maxf(0.0, float(value) - delta)
		if actor.killer and was_stunned and _effect(actor, "stun") <= 0.0:
			actor.effects["stun_immunity"] = 5.0
			world.event("stun_immunity", {"actor": actor.id, "position": actor.position, "duration": 5.0})
		_tick_charge(actor, delta)
		_tick_outlet(actor, delta)
		_tick_chocolate(actor, delta)
		_tick_modifiers(actor, delta)
		if actor.killer:
			_tick_phase(actor, was_phase)
			_tick_shadow(actor, delta)
		_tick_forced_motion(actor, delta)
		_tick_channel(actor, delta)
		_tick_grab(actor, delta)
		_tick_overheat(actor, delta)
		_tick_lms(actor)
	_tick_carries(delta)
	_tick_grinds(delta)
	_tick_attacks(delta)
	_tick_spike_waves(delta)
	_tick_minions(delta)
	_tick_projectiles(delta)
	_tick_drones(delta)
	_tick_zones(delta)


func damage(victim, amount: float, source, indirect: bool = false, cause: String = "slash", origin: Variant = null):
	if not _can_act(victim) or amount <= 0.0 or _effect(victim, "recover") > 0.0 or _effect(victim, "revive_invuln") > 0.0 or _effect(victim, "overheat_time") > 0 or _effect(victim, "overheat_charge") > 0:
		return
	if bool(victim.effects.get("shadow_hide", false)): return
	if source != null and bool(source.effects.get("shadow_hide", false)) and not indirect: return
	var source_id: int = -1 if source == null else int(source.id)
	if _effect(victim, "block") > 0.0:
		if not bool(victim.effects.get("block_success", false)):
			victim.effects["counter"] = 1.2
			victim.effects["block_success"] = true
			_set_cd(victim, 1, 20.0)
		world.event("block", {"actor": victim.id, "source": source_id, "position": victim.position})
		_message(victim, "BLOCAGE RÉUSSI · appuie sur 2 pour contrer !")
		return
	if victim.character == "Simon" and randf() < 0.1:
		world.event("dodge", {"actor": victim.id, "position": victim.position})
		_message(victim, "Esquive !")
		return
	if float(victim.hp) >= 0.0:
		var actual: float = minf(float(victim.hp), amount)
		victim.hp = maxf(0.0, float(victim.hp) - amount)
		_reward("damage", source, actual)
	_cancel_channel(victim)
	_cancel_charge(victim)
	_stop_outlet(victim)
	_cancel_revive_for(victim)

	for healer in world.actors.values():
		if _effect(healer, "heal_time") > 0.0 and int(healer.effects.get("heal_target", -1)) == int(victim.id):
			_cancel_channel(healer)
	match str(victim.character):
		"Ashura": victim.effects["help_aura"] = 6.0
		"Simon":
			victim.effects["adrenaline"] = 5.0
			_speed(victim, 1.3, 5.0)
		"Bleuette":
			victim.effects["adrenaline"] = 3.0
			_speed(victim, 2.0, 3.0)
		"Lysia": _lysia_damage_cap(victim)
	var hit: Dictionary = {"actor": victim.id, "victim": victim.id, "source": source_id, "amount": amount, "position": victim.position, "death_kind": cause, "attack": cause, "source_position": victim.position if source == null else source.position}
	if origin is Vector3:


		hit["source_position"] = origin
		hit["source"] = -1
		hit["owner"] = source_id
		hit["indirect"] = true
	world.event("hit", hit)
	if float(victim.hp) == 0.0:
		_release_grab(victim, false)
		_release_overheat(victim)
		_fatal_damage(victim, source_id, cause)

func stun(victim, duration: float, source):
	if not _can_act(victim) or duration <= 0.0:
		return
	if bool(victim.effects.get("shadow_hide", false)): return
	if _effect(victim, "overheat_time") > 0 or _effect(victim, "overheat_charge") > 0: return
	if victim.killer and (_effect(victim, "stun_immunity") > 0 or _effect(victim, "stun") > 0):

		if _effect(victim, "stun_immunity") > 0 and source != null and not source.killer:
			_feedback(source, "immune", "Alice est protégée · étourdissement sans effet")
		return

	if victim.killer and _effect(victim, "stun") <= 0.0 and _effect(victim, "phase6") <= 0.0:
		var old_rage: float = _effect(victim, "rage")
		victim.effects["stun_count"] = int(victim.effects.get("stun_count", 0)) + 1

		if not bool(victim.effects.get("true_form_used", false)):
			victim.effects["rage"] = minf(100.0, float(victim.effects.stun_count) * 100.0 / float(PaperRules.TRUE_FORM_STUNS))
			if old_rage < 100.0 and _effect(victim, "rage") >= 100.0:
				_message(victim, "15 STUNS · TRUE FORM prête ! Une utilisation par partie.")
	var total: float = duration
	if source != null and float(source.effects.get("next_stun", 0.0)) > 0.0:
		total += float(source.effects.get("next_stun", 0.0))
		source.effects["next_stun"] = 0.0

	var added: float = maxf(0.0, total - _effect(victim, "stun"))
	victim.effects["stun"] = maxf(_effect(victim, "stun"), total)
	if victim.killer and source != null and not source.killer: _reward("stun", source, added)
	cancel_aim(victim)
	victim.velocity = Vector3.ZERO
	_cancel_channel(victim)
	_cancel_charge(victim)
	_stop_outlet(victim)
	_release_carry(victim)
	_cancel_revive_for(victim)
	world.event("stun", {"actor": victim.id, "source": -1 if source == null else source.id, "duration": total, "position": victim.position})

func interact(actor):
	if not _can_act(actor) or actor.killer or str(world.phase) != "playing":
		return
	if _effect(actor, "stun") > 0.0 or _effect(actor, "root") > 0.0 or _effect(actor, "recover") > 0.0 or _effect(actor, "heal_time") > 0.0 or _effect(actor, "overheat_time") > 0.0:
		return
	if bool(actor.effects.get("drone_piloting", false)) or _effect(actor, "forced_time") > 0.0: return
	var now: float = float(world.clock)
	if _effect(actor, "outlet_healing") > 0:


		if _om(actor) and _interact_revive(actor): return
		var last_press: float = float(actor.effects.get("outlet_press_at", - INF))
		actor.effects["outlet_press_at"] = now
		if now - last_press > OUTLET_PRESS_GAP and now - float(actor.effects.get("outlet_started", now)) >= OUTLET_PRESS_GRACE:
			_stop_outlet(actor, "cancelled")
		return
	if actor.character == "Simon" and _effect(actor, "speed_boost") > 0:


		if int(actor.effects.get("carrying_id", -1)) >= 0:
			_release_carry(actor)
			return
		if carry_survivor(actor): return

	if _om(actor) and _interact_revive(actor): return
	if actor.character == "Lysia" and _outlet_preferred(actor) and start_outlet_heal(actor): return
	if actor.move_input.length() > 0.1:

		if actor.character == "Lysia" and _archive_in_reach(actor) < 0: start_outlet_heal(actor)
		return



	if _revives.has(actor.id): _revives[actor.id]["last_pulse"] = now
	if now - float(_interact_at.get(actor.id, -100.0)) < 0.19:
		return
	_interact_at[actor.id] = now
	if _interact_revive(actor): return
	if actor.character == "Lysia":
		for index in range(world.drones.size() - 1, -1, -1):
			var drone: Dictionary = world.drones[index]
			var drone_pos: Vector3 = drone.position
			if str(drone.state) == "salvage" and actor.position.distance_to(drone_pos) < 2.8 and _los(actor.position, drone_pos):
				if actor.hp >= PaperSurvivorMechanics.heal_ceiling(actor):
					_feedback(actor, "wreck_full", "Armure déjà complète : conserve cette épave pour plus tard.")
					return
				_heal(actor, 7.0, actor)
				_remove_drone(index, "recycled")
				_message(actor, "Drone recyclé : +7 PV")
				return
	if world.school == null:
		return
	for index in range(world.school.objectives.size()):
		var objective: Vector3 = world.school.objectives[index]
		if actor.position.distance_to(objective) <= 2.8 and not world.objective_done.has(index) and _los(actor.position, objective):
			actor.effects["archive_index"] = index
			actor.effects["archive_lock"] = archive_lock_remaining(index)
			if archive_lock_remaining(index) > 0.0 or _archive_challenges.has(actor.id): return
			var shared: bool = _archive_busy(index, int(actor.id)) or (now - float(_objective_at.get(index, -100.0)) < 0.199 and int(_objective_actor.get(index, -1)) != int(actor.id))
			if shared:

				_feedback(actor, "archive_shared", "Un allié scelle déjà cette archive · à deux, elle n’avance pas plus vite", ARCHIVE_FEEDBACK_GAP)
				return
			if now - float(_objective_at.get(index, -100.0)) < 0.199: return
			_objective_at[index] = now
			_objective_actor[index] = actor.id
			var next_check: float = float(_archive_next_check.get(index, 0.045))
			if float(world.objective_progress.get(index, 0.0)) >= next_check:
				_begin_archive_qte(actor, index)
				return
			world.add_objective_progress(index, 0.2 / 30.0)
			return
	if actor.character == "Lysia": start_outlet_heal(actor)


func _archive_in_reach(actor) -> int:
	if world.school == null: return -1
	for index in range(world.school.objectives.size()):
		var objective: Vector3 = world.school.objectives[index]
		if actor.position.distance_to(objective) <= 2.8 and not world.objective_done.has(index) and _los(actor.position, objective): return index
	return -1


func _outlet_preferred(actor) -> bool:
	var preview: Dictionary = outlet_preview(actor)
	if int(preview.index) < 0: return false
	var offset: Vector3 = _flat(Vector3(preview.position) - actor.position)
	if offset.length() <= 1.0: return true
	var facing: float = offset.normalized().dot(_aim(actor))
	if facing < 0.85: return false
	var archive: int = _archive_in_reach(actor)
	if archive < 0: return true
	var toward: Vector3 = _flat(world.school.objectives[archive] - actor.position)
	return toward.length() > 0.1 and facing > toward.normalized().dot(_aim(actor))

func apply_lms(actor):
	if not _can_act(actor) or actor.killer or bool(actor.effects.get("lms_applied", false)): return
	actor.lms = true
	actor.effects["lms_applied"] = true
	actor.effects["lms_reveal"] = 6.0
	world.event("lms", {"actor": actor.id, "position": actor.position, "character": actor.character})
	var gained: float = PaperSurvivorMechanics.apply_lms_health(actor)
	if gained > 0.0:
		world.event("heal", {"actor": actor.id, "source": actor.id, "amount": gained, "position": actor.position})
		_message(actor, "DERNIÈRE PRÉSENCE · +%d PV (maximum 150)" % int(round(gained)))
	if not _om(actor) or _effect(actor, "aura_charge") >= 100.0 or bool(world.get("training")):
		_unlock_lms(actor)
	else:
		actor.effects["lms_buff_unlocked"] = false
		_message(actor, "LMS · aura %d/100 : reste en danger pour débloquer tes bonus." % int(_effect(actor, "aura_charge")))

func _unlock_lms(actor):
	if bool(actor.effects.get("lms_buff_unlocked", false)): return
	actor.effects["lms_buff_unlocked"] = true
	if actor.character in ["Usayuko", "Simon"] or (_om(actor) and actor.character == "Ashura"):
		actor.effects["lms_cd_factor"] = 0.85
		for slot in actor.cooldowns.keys(): actor.cooldowns[slot] = float(actor.cooldowns[slot]) * 0.85
	if actor.character == "Lysia":
		actor.effects["lms_qte_next"] = float(world.clock) + 2.0
		actor.effects["lms_qte_ready"] = false
	var instruction: String = "AURA ÉVEILLÉE · Dernière chance : tiens jusqu'à la sonnerie !"
	if actor.character == "Usayuko": instruction = "AURA ÉVEILLÉE · 4 : Dropkick unique (5 s de stun)"
	elif actor.character == "Elly": instruction = "AURA ÉVEILLÉE · 4 : Shotgun unique (3 s de stun)"
	elif actor.character == "Bleuette": instruction = "AURA ÉVEILLÉE · 4 : Je peux le faire !"
	elif actor.character == "Lysia": instruction = "AURA ÉVEILLÉE · un allié éliminé peut réparer ton armure (150 PV max)."
	_message(actor, instruction)
	world.event("aura_unlock", {"actor": actor.id, "position": actor.position, "character": actor.character})

func assist(helper_id: int, actor_id: int, choice: String):
	if str(world.phase) != "playing" or not world.actors.has(actor_id):
		return
	var actor = world.actors[actor_id]
	if not _can_act(actor) or actor.character != "Lysia" or not lms_available(actor) or not bool(actor.effects.get("lms_qte_ready", false)):
		return
	var expires: float = float(actor.effects.get("lms_qte_expires", 0.0))
	if float(world.clock) > expires or choice not in ["health", "stamina"]:
		return
	if helper_id == -1:
		if not _automatic_assist_allowed(actor):
			return
	else:
		if not world.actors.has(helper_id):
			return
		var helper = world.actors[helper_id]
		if helper.alive or helper.killer or helper.bot or int(helper.id) == actor_id:
			return
		if helper_id != int(actor.effects.get("lms_qte_helper", helper_id)):
			return


		var elapsed: float = maxf(0.0, float(world.clock) - float(actor.effects.get("lms_qte_started", world.clock)))
		var band: float = fmod(elapsed, 2.4) / 2.4
		if band < 0.35 or band > 0.7:
			actor.effects["lms_qte_ready"] = false
			actor.effects["lms_qte_next"] = float(world.clock) + ASSIST_PERIOD
			world.event("qte", {"actor": actor.id, "helper": helper_id, "ready": false, "success": false})
			return

	actor.effects["lms_qte_ready"] = false
	actor.effects["lms_qte_next"] = float(world.clock) + ASSIST_PERIOD
	var multiplier: float = 1.5 if bool(actor.effects.get("consumed", false)) else 1.0
	var outcome: String = "armure renforcée"
	var grown: float = PaperSurvivorMechanics.lms_max_growth(actor, 10.0 * multiplier) if choice == "health" else 0.0
	if choice == "health" and grown > 0.0:
		var added: float = 10.0 * multiplier
		actor.max_hp = float(actor.max_hp) + grown
		actor.hp = minf(PaperSurvivorMechanics.heal_ceiling(actor), float(actor.hp) + added)
	elif _om(actor):
		# En LMS, l'armure ne dépasse pas 150 : « + ARMURE » répare alors comme « + SOINS ».
		var repaired: float = 15.0 * multiplier
		actor.hp = minf(PaperSurvivorMechanics.heal_ceiling(actor), float(actor.hp) + repaired)
		outcome = "armure réparée"
	else:
		var added: float = 15.0 * multiplier
		actor.effects["qte_stamina_bonus"] = float(actor.effects.get("qte_stamina_bonus", 0.0)) + added
		if float(actor.max_stamina) >= 0.0:
			actor.max_stamina = float(actor.max_stamina) + added
			actor.stamina = minf(float(actor.max_stamina), float(actor.stamina) + added)
		outcome = "endurance renforcée"
	world.event("qte", {"actor": actor.id, "helper": helper_id, "ready": false, "success": true, "choice": choice})
	_message(actor, "QTE réussi · " + outcome)
	if helper_id >= 0: _message(_actor(helper_id), "Aide réussie · " + outcome)

func _alice(actor, slot: int) -> bool:
	match slot:
		0:
			_set_cd(actor, 0, 3.0)
			_begin_attack(actor, Vector3(2.8, 2.2, 3.4), {"damage": 30.0})
			return true
		1:
			actor.effects["reveal"] = 5.0
			_set_cd(actor, 1, 30.0)
			world.event("reveal", {"actor": actor.id, "duration": 5.0, "exclude": "Simon"})
			return true
		2:
			if not bool(actor.effects.get("spike_aiming", false)):
				actor.effects["spike_aiming"] = true
				_message(actor, "PIQUES PRÊTS · vise avec la souris · clic ou 3 : surgir · clic droit : annuler")
			else:
				actor.effects["spike_aiming"] = false
				_set_cd(actor, 2, 18.0)
				_erupt_spikes(actor)
			return true
		3:
			if _effect(actor, "phase6") > 0:
				actor.velocity.y = 7.5
				_start_motion(actor, _aim(actor), 13.0, 0.6, "pounce")
				_begin_attack(actor, Vector3(3.0, 2.7, 3.8), {"damage": 40.0, "cause": "pounce"}, 0.65)
				_set_cd(actor, 3, 6.0)
				world.event("true_form_pounce", {"actor": actor.id, "position": actor.position, "direction": _aim(actor), "duration": 0.6})
				return true
			if _om(actor): return _alice_decoys(actor)
			cancel_aim(actor)
			var target = _front_survivor(actor, 28.0, 0.55)
			if target == null:
				_message(actor, "Vise un survivant visible à moins de 28 m.")
				return false
			actor.effects["shadow_target"] = target.id
			actor.effects["shadow_time"] = 1.2
			actor.effects["shadow_hide"] = true
			actor.effects["shadow_origin"] = actor.position
			target.effects["shadow_mark"] = 1.2
			actor.position = _shadow_destination(actor, target, 1.0)
			actor.velocity = Vector3.ZERO
			_set_cd(actor, 3, 32.0)
			world.event("shadow", {"actor": actor.id, "target": target.id, "position": target.position, "active": true, "duration": 1.2})
			_message(target, "ALICE DANS TON OMBRE ! Elle émerge dans 1,2 s : déplace-toi !")
			return true
		4:
			_spawn_minions(actor)
			_set_cd(actor, 4, 32.0)
			return true
		5:
			if int(actor.effects.get("stun_count", 0)) < PaperRules.TRUE_FORM_STUNS or bool(actor.effects.get("true_form_used", false)) or _effect(actor, "phase6") > 0.0: return false
			actor.effects["rage"] = 0.0
			actor.effects["true_form_used"] = true
			actor.effects["phase6"] = PaperRules.TRUE_FORM_SECONDS
			actor.cooldowns[3] = 0.0
			actor.max_stamina = -1.0 if _om(actor) else 600.0
			actor.stamina = actor.max_stamina
			world.event("phase6", {"actor": actor.id, "active": true, "true_form": true, "duration": PaperRules.TRUE_FORM_SECONDS, "position": actor.position})
			_message(actor, "TRUE FORM · bond meurtrier · chronomètre suspendu")
			return true
	return false

func _ashura(actor, slot: int) -> bool:
	if _om(actor): return _ashura_om(actor, slot)
	match slot:
		0:
			for drone in world.drones:
				if int(drone.owner) == int(actor.id) and str(drone.state) != "salvage":
					_message(actor, "Ton drone est déjà en vol.")
					return false
			var factor: float = 0.75 if bool(actor.effects.get("drone_bonus", false)) else 1.0
			actor.effects["drone_bonus"] = false
			var drone: Dictionary = {"id": _next_drone, "owner": actor.id, "position": _grenade_hand_position(actor), "direction": _aim(actor), "ttl": DRONE_BATTERY, "state": "launch", "target": -1, "age": 0.0, "cooldown_factor": factor}
			_next_drone += 1
			world.drones.append(drone)
			actor.effects["drone_active"] = true
			actor.effects["drone_battery"] = DRONE_BATTERY
			actor.effects["attack_lock"] = 0.35
			_set_cd(actor, 0, 10.0 * factor)
			world.event("drone", {"action": "launch", "id": drone.id, "actor": actor.id, "owner": actor.id, "position": drone.position})
			return true
		1:
			_speed(actor, 1.55, 3.0)
			_reward_escape_boost(actor)
			_set_cd(actor, 1, 35.0)
			return true
	return false

func _ashura_om(actor, slot: int) -> bool:
	if slot == 1:
		return begin_charge(actor)
	if slot == 2:
		actor.effects["drone_precise"] = not bool(actor.effects.get("drone_precise", false))
		_set_cd(actor, 2, 0.2)
		return true
	if slot != 0: return false
	for current in world.drones:
		if int(current.owner) == int(actor.id) and str(current.state) != "salvage":
			_message(actor, "Ton drone est déjà en vol.")
			return false
	var precise: bool = bool(actor.effects.get("drone_precise", false))
	var factor: float = 0.75 if bool(actor.effects.get("drone_bonus", false)) else 1.0
	actor.effects["drone_bonus"] = false
	var drone: Dictionary = {"id": _next_drone, "owner": actor.id, "position": _grenade_hand_position(actor), "direction": _aim(actor), "ttl": DRONE_BATTERY, "state": "launch", "target": -1, "age": 0.0, "cooldown_factor": factor, "mode": "precise" if precise else "quick", "control": Vector3.ZERO, "stun": 4.0 if precise else 2.0, "cooldown_slot": slot}
	_next_drone += 1
	world.drones.append(drone)
	actor.effects["drone_active"] = true
	actor.effects["drone_piloting"] = precise
	actor.effects["drone_battery"] = DRONE_BATTERY
	actor.effects["attack_lock"] = 0.15
	if precise: actor.velocity = Vector3.ZERO;actor.move_input = Vector3.ZERO
	_set_cd(actor, 0, (35.0 if precise else 25.0) * factor)
	world.event("drone", {"action": "launch", "id": drone.id, "actor": actor.id, "owner": actor.id, "position": drone.position, "mode": drone.mode})
	return true

func piloted_drone(actor) -> Dictionary:
	if actor == null or not _om(actor): return {}
	for drone in world.drones:
		if int(drone.owner) == int(actor.id) and str(drone.get("mode", "")) == "precise" and str(drone.state) != "salvage": return drone
	return {}

func drone_input(actor, direction: Vector3):
	if world.has_method("authoritative") and not world.authoritative(): return
	if not direction.is_finite() or str(world.phase) != "playing" or not _can_act(actor): return
	var drone: Dictionary = piloted_drone(actor)
	if drone.is_empty(): return
	drone["control"] = direction.limit_length(1.0)
	drone["last_input"] = float(world.clock)

func _tick_drones(delta: float):
	for index in range(world.drones.size() - 1, -1, -1):
		var drone: Dictionary = world.drones[index]
		var source = _actor(int(drone.owner))
		drone.ttl = maxf(0.0, float(drone.ttl) - delta)
		drone.age = float(drone.get("age", 0.0)) + delta
		if str(drone.state) == "salvage":
			var recycled: bool = false
			for collector in world.actors.values():
				if collector.character == "Lysia" and _can_act(collector) and collector.hp < PaperSurvivorMechanics.heal_ceiling(collector) and collector.position.distance_to(drone.position) <= 1.25 and _los(collector.position, drone.position):
					_heal(collector, 7.0, collector)
					world.event("drone_eaten", {"actor": collector.id, "position": collector.position, "amount": 7.0})
					_remove_drone(index, "recycled");recycled = true;break
			if not recycled and float(drone.ttl) <= 0.0: _remove_drone(index, "expired")
			continue
		if source != null: source.effects["drone_battery"] = float(drone.ttl)
		if float(drone.ttl) <= 0.0 or not _can_act(source) or (str(drone.get("mode", "")) == "precise" and _effect(source, "stun") > 0.0):
			_land_drone(index, false)
			continue
		if str(drone.state) == "launch":
			if _effect(source, "stun") > 0.0:
				_land_drone(index, false)
				continue
			drone.position = _grenade_hand_position(source)
			if float(drone.age) < (0.15 if _om(source) else 0.35): continue
			var body: CharacterBody3D = CharacterBody3D.new()
			body.name = "DronePhysics_%d" % int(drone.id)
			body.collision_layer = 0
			body.collision_mask = 3
			body.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
			var collider: CollisionShape3D = CollisionShape3D.new()
			var shape: SphereShape3D = SphereShape3D.new()
			shape.radius = 0.23
			collider.shape = shape
			body.add_child(collider)
			world.add_child(body)


			body.position = source.position + Vector3.UP * DRONE_HOVER
			body.move_and_collide(Vector3(drone.position) - body.position)
			drone.position = body.position
			drone.state = "piloted" if str(drone.get("mode", "")) == "precise" else "seeking"
			_drone_bodies[int(drone.id)] = body
			_drone_paths[int(drone.id)] = {"points": PackedVector3Array(), "next": 0.0}
			world.event("drone", {"action": "fly", "id": drone.id, "owner": source.id, "actor": source.id, "position": drone.position})
		var body: CharacterBody3D = _drone_bodies.get(int(drone.id))
		if not is_instance_valid(body):
			_land_drone(index, false)
			continue
		var target = world.killer_actor()
		if target != null and bool(target.effects.get("shadow_hide", false)): target = null
		drone.target = -1 if target == null else int(target.id)
		var direction: Vector3 = Vector3.ZERO
		var precise: bool = str(drone.get("mode", "")) == "precise"


		var waiting: bool = _stun_blocked(target)
		if precise:
			if float(world.clock) - float(drone.get("last_input", -99.0)) <= 0.4: direction = drone.get("control", Vector3.ZERO)
		elif target != null:
			var floor_pos: Vector3 = body.position - Vector3.UP * DRONE_HOVER
			var state: Dictionary = _drone_paths[int(drone.id)]
			var target_pos: Vector3 = target.position + Vector3.UP * DRONE_HOVER
			if waiting and body.position.distance_to(target_pos) < 2.2:
				direction = Vector3.ZERO
			elif _drone_clear_path(body.position, target_pos):
				direction = (target_pos - body.position).normalized()
			else:
				var stale: bool = state.points.is_empty() or Vector3(state.get("goal", Vector3.INF)).distance_to(target.position) > 1.5
				if float(world.clock) >= float(state.next) and stale:
					state.points = world.school.nav_path(floor_pos, target.position, -1)
					state.goal = target.position
					state.next = float(world.clock) + randf_range(0.4, 0.5)
				var points: PackedVector3Array = state.points
				while not points.is_empty() and _flat(points[0] - floor_pos).length() < 0.5 and ( not _om(source) or absf(points[0].y - floor_pos.y) < 0.7): points.remove_at(0)
				state.points = points
				if not points.is_empty(): direction = (points[0] + Vector3.UP * DRONE_HOVER - body.position).normalized()
		body.velocity = body.velocity.move_toward(direction * (15.0 if _om(source) else DRONE_SPEED), delta * 48.0 if _om(source) else delta * 40.0)
		body.move_and_slide()
		drone.position = body.position
		if direction.length_squared() > 0.001: drone.direction = direction
		if precise:
			var shadow_hit: bool = false
			for shadow_index in range(world.minions.size() - 1, -1, -1):
				var shadow_pos: Vector3 = world.minions[shadow_index].position + Vector3.UP * DRONE_HOVER
				if body.position.distance_to(shadow_pos) <= 1.0 and _drone_clear_path(body.position, shadow_pos):
					_remove_minion(shadow_index, "drone");shadow_hit = true
			if shadow_hit:
				_land_drone(index, true)
				continue
		if waiting and body.position.distance_to(target.position + Vector3.UP * DRONE_HOVER) <= 2.4 and not bool(drone.get("wait_told", false)):
			drone["wait_told"] = true
			_message(source, "Alice est protégée · le drone attend la fin de l’aura rouge")
		if target != null and not waiting and body.position.distance_to(target.position + Vector3.UP * DRONE_HOVER) <= 0.9 and _drone_clear_path(body.position, target.position + Vector3.UP * DRONE_HOVER):
			stun(target, float(drone.get("stun", 2.0)), source)
			target.effects["blind"] = maxf(_effect(target, "blind"), 1.0)
			_dispel_radius(target.position, 3.0, source.id)
			if not _om(source): source.cooldowns[0] = 40.0 * float(drone.get("cooldown_factor", 1.0))
			world.event("flash", {"actor": target.id, "duration": 1.0, "position": body.position})
			_land_drone(index, true)

func _drone_clear_path(from: Vector3, to: Vector3) -> bool:

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 3)
	return world.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _land_drone(index: int, impact: bool):
	var drone: Dictionary = world.drones[index]
	var source = _actor(int(drone.owner))
	if source != null:
		source.effects["drone_active"] = false
		source.effects["drone_piloting"] = false
		source.effects["drone_battery"] = 0.0
	var body = _drone_bodies.get(int(drone.id))
	if is_instance_valid(body): body.queue_free()
	_drone_bodies.erase(int(drone.id))
	_drone_paths.erase(int(drone.id))
	drone.state = "salvage"
	drone.ttl = 15.0
	drone.target = -1
	var pos: Vector3 = drone.position
	var floor_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(pos, pos - Vector3.UP * (180.0 if _om(source) else 8.0), 1)
	var ground: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(floor_query)
	drone.position = Vector3(ground.position) + Vector3.UP * 0.12 if not ground.is_empty() else pos
	world.event("drone", {"action": "impact" if impact else "depleted", "id": drone.id, "owner": drone.owner, "actor": drone.owner, "position": pos})

func _remove_drone(index: int, reason: String):
	var drone: Dictionary = world.drones[index]
	var source = _actor(int(drone.owner))
	if source != null and str(drone.state) != "salvage":
		source.effects["drone_active"] = false
		source.effects["drone_piloting"] = false
		source.effects["drone_battery"] = 0.0
	var body = _drone_bodies.get(int(drone.id))
	if is_instance_valid(body): body.queue_free()
	_drone_bodies.erase(int(drone.id))
	_drone_paths.erase(int(drone.id))
	world.drones.remove_at(index)
	world.event("drone", {"action": reason, "id": drone.id, "owner": drone.owner, "actor": drone.owner, "position": drone.position})

func _usayuko(actor, slot: int) -> bool:
	match slot:
		0:
			_set_cd(actor, 0, 45.0)
			actor.effects["grab_target"] = -1
			actor.effects["grab_time"] = 4.0
			actor.effects["grab_direction"] = _aim(actor)
			actor.effects["root"] = 4.0
			actor.velocity = Vector3.ZERO

			var cast_id: int = _next_cast
			_next_cast += 1
			actor.effects["grab_cast_id"] = cast_id
			actor.effects["grab_box_until"] = float(world.clock) + 4.0
			_emit_box(actor, Vector3(2.4, 2.2, 2.6), 4.0, actor.effects["grab_direction"], cast_id)
			world.event("grab", {"actor": actor.id, "target": -1, "duration": 4.0, "charging": true})
			_message(actor, "CHARGE · attrape Alice au contact, puis entraîne-la contre un mur !")
			return true
		1:
			if _effect(actor, "counter") > 0.0:
				actor.effects["counter"] = 0.0
				_begin_attack(actor, Vector3(2.6, 2.2, 3.2), {"stun": 4.0})
			else:
				actor.effects["block"] = 1.5
				actor.effects["block_success"] = false
				_set_cd(actor, 1, 30.0)
			return true
		2:
			_set_cd(actor, 2, 35.0)
			_begin_attack(actor, Vector3(2.5, 2.2, 3.0), {"stun": 2.0})
			return true
		3:
			if not lms_available(actor) or bool(actor.effects.get("dropkick_used", false)): return false
			actor.effects["dropkick_used"] = true
			_start_motion(actor, _aim(actor), 4.5, 0.32, "dropkick")
			_begin_attack(actor, Vector3(2.6, 2.2, 3.0), {"stun": 5.0, "knock": 2.0}, 0.35)
			return true
	return false

func _simon(actor, slot: int) -> bool:
	if _om(actor) and slot == 2:
		actor.effects["grenade_aiming"] = false
		actor.effects["flash_melee"] = not bool(actor.effects.get("flash_melee", false))
		_set_cd(actor, 2, 0.2)
		return true
	if _om(actor) and slot == 0 and bool(actor.effects.get("flash_melee", false)):
		_set_cd(actor, 0, 30.0)
		actor.effects["attack_lock"] = 0.22
		_begin_attack(actor, Vector3(2.5, 2.2, 3.0), {"stun": 2.5, "blind": 4.0}, 0.18)
		return true
	match slot:
		0:
			if not bool(actor.effects.get("grenade_aiming", false)):
				actor.effects["grenade_aiming"] = true
				world.event("grenade_aim", {"actor": actor.id, "active": true})
				return true
			actor.effects["grenade_aiming"] = false
			_set_cd(actor, 0, 30.0)
			actor.effects["grenade_windup"] = 0.35
			actor.effects["attack_lock"] = 0.35
			world.projectiles.append({"id": _next_projectile, "owner": actor.id, "position": actor.position + Vector3.UP * 1.3, "velocity": Vector3.ZERO, "ttl": 1.1, "stage": "windup", "age": 0.0})
			_next_projectile += 1
			return true
		1:
			return begin_charge(actor)
	return false

func _lysia(actor, slot: int) -> bool:
	match slot:
		0:
			actor.effects["overheat_charge"] = 0.65
			actor.effects["overheat_direction"] = _aim(actor)
			actor.effects["overheat_target"] = -1
			_set_cd(actor, 0, 30.0)
			world.event("overheat_charge", {"actor": actor.id, "position": actor.position, "duration": 0.65})
			return true
		1:
			if not bool(actor.effects.get("consumed", false)):
				actor.effects["consumed"] = true
				_lysia_update_cap(actor)
			_begin_attack(actor, Vector3(2.8, 2.2, 3.2), {"knock": 20.0})
			_set_cd(actor, 1, 50.0)
			return true
		2:
			actor.effects["xray"] = 3.0
			_set_cd(actor, 2, 20.0)
			world.event("reveal", {"actor": actor.id, "duration": 3.0, "killer_only": true})
			return true
		3: return start_outlet_heal(actor)
	return false

func _elly(actor, slot: int, target_id: int) -> bool:
	match slot:
		0:
			if not actor.is_on_floor():
				_message(actor, "SOIN · pose-toi au sol pour soigner.")
				return false
			var target = _heal_target(actor, target_id)
			if target == null or target.character == "Lysia":
				_message(actor, "SOIN · approche un allié blessé à moins de 6 m, sans obstacle.")
				return false
			actor.effects["heal_target"] = target.id
			actor.effects["heal_time"] = 3.0
			actor.effects["heal_amount"] = 50.0 * float(actor.effects.get("next_heal", 1.0))
			actor.effects["heal_origin"] = actor.position
			actor.effects["heal_target_origin"] = target.position

			actor.effects["root"] = 3.0
			target.effects["root"] = maxf(_effect(target, "root"), 3.0)
			actor.velocity = Vector3.ZERO
			target.velocity = Vector3.ZERO
			_set_cd(actor, 0, 35.0)
			world.event("heal_channel", {"actor": actor.id, "target": target.id, "duration": 3.0})
			return true
		1:
			world.zones.append({"position": actor.position, "left": 20.0, "radius": 5.0, "owner": actor.id})
			_set_cd(actor, 1, 50.0)
			world.event("zone", {"actor": actor.id, "position": actor.position, "duration": 20.0, "radius": 5.0})
			return true
		3:
			if not lms_available(actor) or bool(actor.effects.get("shotgun_used", false)): return false
			actor.effects["shotgun_used"] = true
			var target = world.killer_actor()
			if target != null:
				var offset: Vector3 = _flat(target.position - actor.position)
				var forward: float = offset.dot(_aim(actor))
				var lateral: float = (offset - _aim(actor) * forward).length()
				var spread: float = 2.5 if offset.length() < 4.0 else 0.8
				if forward >= 0.0 and forward <= 25.0 and lateral <= spread and _los(actor.position, target.position):
					damage(target, 203.0, actor, false, "shotgun")
					stun(target, 3.0, actor)
					target.effects["blind"] = maxf(_effect(target, "blind"), 2.0)
					world.event("flash", {"actor": target.id, "duration": 2.0, "position": target.position})

			var muzzle: Vector3 = actor.position + Vector3.UP
			world.event("tracer", {"actor": actor.id, "from": muzzle, "to": _ray_endpoint(actor.position, _aim(actor), 25.0) + Vector3.UP, "color": "ffda89", "duration": 0.2, "kind": "shotgun"})
			return true
	return false

func _bleuette(actor, slot: int, target_id: int) -> bool:
	match slot:
		2:
			if actor.hp >= actor.max_hp or int(actor.effects.get("chocolate_uses", 0)) >= 2: return false
			actor.effects["chocolate_uses"] = int(actor.effects.get("chocolate_uses", 0)) + 1
			actor.effects["chocolate_eating"] = 1.4
			actor.effects["chocolate_hot"] = 10.0
			_heal(actor, 20.0, actor)
			_set_cd(actor, 2, 35.0)
			world.event("chocolate", {"actor": actor.id, "position": actor.position, "duration": 1.4})
			return true
		0:
			var target = _support_target(actor, slot, target_id)
			if target == null:
				_support_failure(actor, slot, target_id)
				return false
			var line: String = ""
			match str(target.character):
				"Ashura":
					target.effects["drone_bonus"] = true
					line = "Ton drone nous protège ! Sa prochaine recharge sera 25 % plus rapide."
				"Usayuko":
					target.effects["next_stun"] = 1.5
					line = "Heureusement que t'es là pour nous protéger, frangin !"
				"Simon":
					target.effects["sprint_bonus"] = PaperSurvivorMechanics.SIMON_SPRINT_BONUS
					line = "Cours, Simon, on te suit ! Ta prochaine Course éclair durera 2 s de plus."
				"Lysia":
					target.effects["cooldown_discount"] = 0.25
					line = "Allez, on va y arriver ensemble !"
				"Elly":
					target.effects["next_heal"] = 2.0
					line = "C'est si soulageant de vous avoir à nos côtés, monsieur !"
				_:
					_message(actor, "Ce personnage n'a pas de bonus Boost défini. Utilise Je crois en toi.")
					return false
			_set_cd(actor, 0, 40.0)
			_message(actor, line, {"target": target.id})
			_message(target, "BLEUETTE T’ENCOURAGE · " + PaperSurvivorMechanics.boost_summary(str(target.character)))
			_reward("boost", actor)
			world.event("boost", {"actor": actor.id, "target": target.id, "position": target.position})
			return true
		1:
			var target = _support_target(actor, slot, target_id)
			var killer = world.killer_actor()
			if target == null or killer == null:
				_support_failure(actor, slot, target_id)
				return false
			var chosen: int = -1
			var longest: float = 0.0
			for key in target.cooldowns:
				if not _rechargeable_slot(target, int(key)): continue
				var remaining: float = float(target.cooldowns.get(key, 0.0))
				if remaining > longest:
					chosen = int(key)
					longest = remaining
			if chosen < 0:
				_support_failure(actor, slot, target_id)
				return false
			target.cooldowns[chosen] = 0.0
			_reward("recharge", actor)
			_set_cd(actor, 1, 45.0)
			_message(actor, "Je crois en toi ! Capacité rechargée.", {"target": target.id})
			return true
		3:
			if not lms_available(actor) or bool(actor.effects.get("aura_used", false)): return false
			actor.effects["aura_used"] = true
			actor.max_hp = float(actor.max_hp) + 30.0
			actor.hp = minf(float(actor.max_hp), float(actor.hp) + 30.0)
			if not _om(actor):
				actor.max_stamina = float(actor.max_stamina) + 40.0
				actor.stamina = minf(float(actor.max_stamina), float(actor.stamina) + 40.0)

			if _om(actor) and float(actor.max_hp) > PaperSurvivorMechanics.LMS_HP_CAP: _message(actor, "JE PEUX LE FAIRE ! +30 PV · au-delà de 150")
			else: _message(actor, "JE PEUX LE FAIRE ! +30 PV" if _om(actor) else "JE PEUX LE FAIRE ! +30 PV, +40 endurance")
			return true
	return false

func _tick_channel(actor, delta: float):
	var left: float = _effect(actor, "heal_time")
	if left <= 0.0: return
	var target = _actor(int(actor.effects.get("heal_target", -1)))
	var origin: Vector3 = actor.effects.get("heal_origin", actor.position)
	var target_origin: Vector3 = actor.effects.get("heal_target_origin", Vector3.ZERO)
	if not _can_act(target) or _effect(actor, "stun") > 0.0 or actor.position.distance_to(origin) > 0.35 or target.position.distance_to(target_origin) > 0.35 or not _los(actor.position, target.position):
		_cancel_channel(actor)
		return
	left -= delta
	actor.effects["heal_time"] = maxf(0.0, left)
	if left <= 0.0:
		var amount: float = float(actor.effects.get("heal_amount", 50.0))
		_heal(target, amount, actor)
		actor.effects["next_heal"] = 1.0
		actor.effects["heal_target"] = -1
		actor.effects["root"] = 0.0
		if _effect(target, "grab_time") <= 0.0 and _effect(target, "overheat_time") <= 0.0: target.effects["root"] = 0.0

func _cancel_channel(actor):
	if actor == null or _effect(actor, "heal_time") <= 0.0: return
	var target = _actor(int(actor.effects.get("heal_target", -1)))
	actor.effects["heal_time"] = 0.0
	actor.effects["heal_target"] = -1
	actor.effects["root"] = 0.0
	if target != null and _effect(target, "grab_time") <= 0.0 and _effect(target, "overheat_time") <= 0.0: target.effects["root"] = 0.0
	world.event("heal_channel", {"actor": actor.id, "cancelled": true})

func _tick_grab(actor, delta: float):
	var left: float = _effect(actor, "grab_time")
	if left <= 0.0: return
	var target = _actor(int(actor.effects.get("grab_target", -1)))
	if _effect(actor, "stun") > 0.0 or (target != null and not target.alive):
		_release_grab(actor, false)
		return
	var direction: Vector3 = actor.effects.get("grab_direction", _aim(actor))
	_dispel_box(actor.position, direction, Vector3(2.4, 2.2, 2.6))



	if target == null:
		var killer = world.killer_actor()
		var touching: bool = _inside_box(actor.position, direction, Vector3(2.4, 2.2, 2.6), killer)
		if touching and _effect(killer, "stun_immunity") > 0:
			_feedback(actor, "immune", "Alice est protégée · étourdissement sans effet")
		if touching and _los(actor.position, killer.position) and not bool(killer.effects.get("shadow_hide", false)) and _effect(killer, "stun_immunity") <= 0 and _effect(killer, "stun") <= 0:
			target = killer
			actor.effects["grab_target"] = target.id
			target.effects["grabbed_by"] = actor.id
			target.effects["root"] = left
			target.effects["forced_time"] = 0.0
			world.event("grab", {"actor": actor.id, "target": target.id, "duration": left, "caught": true})
	var step: Vector3 = direction * (13.5 if _om(actor) else 9.5) * minf(delta, left)
	var actor_origin: Vector3 = actor.position
	var wall_hit: bool = false
	if target != null:

		var gather: Vector3 = _flat(actor.position + direction * 0.9 - target.position)
		if gather.length() > 0.05: target.move_and_collide(gather.limit_length(7.0 * delta))
		var target_origin: Vector3 = target.position
		if _om(actor): wall_hit = _om_slide(target, step, delta)
		else:
			var target_hit = target.move_and_collide(step)
			wall_hit = target_hit != null
		step = _flat(target.position - target_origin)
		target.velocity = (target.position - target_origin if _om(actor) else step) / maxf(delta, 0.001)
		_mark_motion(target)

		target.effects["root"] = maxf(0.0, left - delta)
	if _om(actor): wall_hit = _om_slide(actor, step, delta) or wall_hit
	else:
		var actor_hit = actor.move_and_collide(step)
		wall_hit = wall_hit or actor_hit != null
	actor.velocity = (actor.position - actor_origin if _om(actor) else _flat(actor.position - actor_origin)) / maxf(delta, 0.001)
	_mark_motion(actor)
	actor.effects["grab_time"] = maxf(0.0, left - delta)
	actor.effects["root"] = maxf(0.0, left - delta)
	if wall_hit:
		_release_grab(actor, target != null)
	elif left - delta <= 0.0:
		_release_grab(actor, false)

func _release_grab(actor, wall_hit: bool):
	if actor == null: return
	if _effect(actor, "grab_time") <= 0.0 and int(actor.effects.get("grab_target", -1)) < 0: return
	var target = _actor(int(actor.effects.get("grab_target", -1)))
	_end_box(actor, int(actor.effects.get("grab_cast_id", 0)), float(actor.effects.get("grab_box_until", 0.0)))
	actor.effects["grab_cast_id"] = 0
	actor.effects["grab_time"] = 0.0
	actor.effects["grab_target"] = -1
	actor.effects["root"] = 0.0
	actor.velocity = Vector3.ZERO
	if target != null:
		target.effects["root"] = 0.0
		target.effects["grabbed_by"] = -1
		target.velocity = Vector3.ZERO
		if wall_hit and target.alive: stun(target, 3.0, actor)
	world.event("grab", {"actor": actor.id, "released": true, "wall": wall_hit})

func overheat_target(actor) -> Dictionary:
	var target = world.killer_actor()
	var result: Dictionary = {"target": -1 if target == null else target.id, "ready": false, "reason": "Alice est absente"}
	if not _can_act(target): return result
	if bool(target.effects.get("shadow_hide", false)):
		result.reason = "attends qu’Alice sorte de l’ombre"
	elif (_flat(target.position - actor.position).length() > 10.0 or absf(target.position.y - actor.position.y) > 1.5):
		result.reason = "charge vers Alice à moins de 10 m"
	elif not _los(actor.position, target.position):
		result.reason = "un obstacle te sépare d’Alice"
	elif _effect(target, "stun_immunity") > 0 or _effect(target, "stun") > 0:
		result.reason = "attends la fin de l’aura rouge"
	elif _flat(target.position - actor.position).normalized().dot(_aim(actor)) < 0.65:
		result.reason = "oriente ton regard vers Alice"
	elif int(target.effects.get("grabbed_by", -1)) >= 0:
		result.reason = "Alice est déjà portée par Usayuko"
	else:
		result.ready = true
		result.reason = "SURCHAUFFE · charge frontale"
	return result

func _tick_overheat(actor, delta: float):
	var charging: float = _effect(actor, "overheat_charge")
	if charging > 0:
		var direction: Vector3 = actor.effects.get("overheat_direction", _aim(actor))
		var enemy = world.killer_actor()
		var blocked: bool = _om_slide(actor, direction * 15.0 * minf(charging, delta), delta)
		_mark_motion(actor)
		actor.effects["overheat_charge"] = maxf(0.0, charging - delta)
		_dispel_box(actor.position, direction, Vector3(2.6, 2.2, 2.8))
		var touching: bool = _inside_box(actor.position, direction, Vector3(2.6, 2.2, 2.8), enemy)
		if touching and _effect(enemy, "stun_immunity") > 0:
			_feedback(actor, "immune", "Alice est protégée · étourdissement sans effet")
		if touching and _los(actor.position, enemy.position) and _effect(enemy, "stun_immunity") <= 0 and _effect(enemy, "stun") <= 0 and not bool(enemy.effects.get("shadow_hide", false)):
			stun(enemy, 5.0, actor)
			actor.effects["overheat_charge"] = 0.0
			actor.effects["overheat_time"] = 3.0
			actor.effects["overheat_hold"] = 3.0
			actor.effects["overheat_drained"] = 0.0
			actor.effects["overheat_target"] = enemy.id
			actor.velocity = Vector3.ZERO
			world.event("overheat", {"actor": actor.id, "target": enemy.id, "duration": 3.0, "active": true})
		elif blocked: actor.effects["overheat_charge"] = 0.0
		return
	var left: float = _effect(actor, "overheat_time")
	if left <= 0.0: return
	var target = _actor(int(actor.effects.get("overheat_target", -1)))
	if not _can_act(target) or _effect(actor, "stun") > 0.0 or bool(target.effects.get("shadow_hide", false)):
		_release_overheat(actor)
		return
	actor.velocity = Vector3.ZERO
	actor.aim = _flat(target.position - actor.position).normalized()
	_mark_motion(actor)
	if actor.position.distance_to(target.position) > 3.6 or not _los(actor.position, target.position):
		_release_overheat(actor)
		return
	_reward("control", actor, minf(delta, left))
	actor.effects["overheat_time"] = maxf(0.0, left - delta)
	actor.effects["overheat_hold"] = maxf(0.0, left - delta)
	actor.effects["root"] = maxf(0.0, left - delta)
	PaperSurvivorMechanics.overheat_drain(actor)
	if left - delta <= 0.0: _release_overheat(actor, true)

func _release_overheat(actor, completed: bool = false):
	if actor == null: return
	actor.effects["overheat_charge"] = 0.0
	actor.effects["overheat_hold"] = 0.0
	if int(actor.effects.get("overheat_target", -1)) < 0: return
	var target = _actor(int(actor.effects.get("overheat_target", -1)))
	if target != null:
		_remove_slow(target, "overheat_%d" % actor.id)
	actor.effects["overheat_time"] = 0.0
	actor.effects["overheat_target"] = -1
	actor.effects["root"] = 0.0
	actor.velocity = Vector3.ZERO
	world.event("overheat", {"actor": actor.id, "active": false, "completed": completed, "target": -1 if target == null else target.id})

func _tick_phase(actor, was_phase: bool):
	if _om(actor):
		actor.max_stamina = -1.0;actor.stamina = -1.0
		if was_phase and _effect(actor, "phase6") <= 0.0: world.event("phase6", {"actor": actor.id, "active": false, "position": actor.position})
		return
	if was_phase and _effect(actor, "phase6") <= 0.0:
		actor.max_stamina = 200.0
		actor.stamina = minf(float(actor.stamina), 200.0)
		world.event("phase6", {"actor": actor.id, "active": false, "position": actor.position})

func cancel_aim(actor):
	if actor == null: return
	actor.effects["spike_aiming"] = false
	actor.effects["grenade_aiming"] = false
	_cancel_charge(actor)
	if _om(actor):
		for index in range(world.drones.size() - 1, -1, -1):
			if int(world.drones[index].owner) == int(actor.id) and str(world.drones[index].get("mode", "")) == "precise" and str(world.drones[index].state) != "salvage":
				_land_drone(index, false)



func spike_endpoint(actor) -> Vector3:
	if _om(actor):
		var aim: Vector3 = _aim(actor)
		var now: int = Time.get_ticks_msec()
		var cache: Dictionary = _spike_preview
		if int(cache.get("actor", -1)) == int(actor.id) and now - int(cache.get("at", -100000)) < PREVIEW_CACHE_MS and Vector3(cache.origin).distance_to(actor.position) < 0.15 and Vector3(cache.aim).dot(aim) > 0.9994:
			var reach: Vector3 = Vector3(cache.end) - Vector3(cache.origin)
			return actor.position + reach.rotated(Vector3.UP, Vector3(cache.aim).signed_angle_to(aim, Vector3.UP))
		var points: PackedVector3Array = _spike_ground_points(actor)
		var end: Vector3 = actor.position if points.is_empty() else points[-1]
		_spike_preview = {"actor": actor.id, "at": now, "origin": actor.position, "aim": aim, "end": end}
		return end
	return _trace_endpoint(actor.position, _aim(actor), 15.0)

func _erupt_spikes(source):
	if _om(source):
		_begin_spike_wave(source)
		return
	var start: Vector3 = source.position
	var end: Vector3 = spike_endpoint(source)
	var direction: Vector3 = _aim(source)
	var length: float = start.distance_to(end)
	for target in world.actors.values():
		if not _can_act(target) or target.killer: continue
		var offset: Vector3 = _flat(target.position - start)
		var along: float = offset.dot(direction)
		var lateral: float = absf(offset.dot(direction.cross(Vector3.UP)))
		if along >= -0.25 and along <= length + 0.38 and lateral <= 1.4 + 0.38 and _los(start, target.position):
			var health_before: float = float(target.hp)
			damage(target, 20.0, source, false, "spike")
			if target.alive and float(target.hp) < health_before: _slow(target, 0.85, 3.0)
	world.event("spike", {"actor": source.id, "from": start, "to": end, "width": 2.8, "duration": 0.85, "telegraph": false})

func clear_entities():
	for helper_id in _revives.keys(): _cancel_revive(int(helper_id))
	for actor_id in _archive_challenges.keys(): _clear_archive_qte(int(actor_id))
	_archive_locks.clear();_archive_next_check.clear();_objective_at.clear();_interact_at.clear()
	_objective_actor.clear();_feedback_at.clear();_spike_preview.clear();_arc_preview.clear()
	for body in _minion_bodies.values():
		if is_instance_valid(body): body.queue_free()
	_minion_bodies.clear()
	_minion_paths.clear()
	world.minions.clear()
	world.projectiles.clear()
	for body in _drone_bodies.values():
		if is_instance_valid(body): body.queue_free()
	_drone_bodies.clear()
	_drone_paths.clear()
	world.drones.clear()
	for actor in world.actors.values():
		actor.effects["drone_active"] = false
		actor.effects["drone_piloting"] = false
		actor.effects["drone_battery"] = 0.0
	_attacks.clear()
	_spike_waves.clear()

func reset_for_training(actor, preserve_lms: bool = false):
	if actor == null: return
	_release_carry(actor)
	_cancel_revive_for(actor)
	_clear_archive_qte(actor.id)
	var was_lms: bool = actor.lms and preserve_lms
	var dummy: bool = bool(actor.effects.get("training_dummy", false))
	var marked = _actor(int(actor.effects.get("shadow_target", -1)))
	if marked != null: marked.effects["shadow_mark"] = 0.0

	for other in world.actors.values():
		if other == actor or int(other.effects.get("heal_target", -1)) == actor.id: _cancel_channel(other)
		if other == actor or int(other.effects.get("grab_target", -1)) == actor.id: _release_grab(other, false)
		if other == actor or int(other.effects.get("overheat_target", -1)) == actor.id: _release_overheat(other)
		if int(other.effects.get("shadow_target", -1)) == actor.id:
			other.effects["shadow_hide"] = false
			other.effects["shadow_time"] = 0.0
			other.effects["shadow_target"] = -1
	for index in range(world.drones.size() - 1, -1, -1):
		if int(world.drones[index].owner) == actor.id: _remove_drone(index, "reset")
	for index in range(world.minions.size() - 1, -1, -1):
		if int(world.minions[index].owner) == actor.id: _remove_minion(index, "reset")
	for index in range(world.projectiles.size() - 1, -1, -1):
		if int(world.projectiles[index].owner) == actor.id: world.projectiles.remove_at(index)
	for index in range(world.zones.size() - 1, -1, -1):
		if int(world.zones[index].get("owner", -1)) == actor.id: world.zones.remove_at(index)
	for index in range(_attacks.size() - 1, -1, -1):
		if int(_attacks[index].actor) == actor.id: _attacks.remove_at(index)
	for index in range(_spike_waves.size() - 1, -1, -1):
		if int(_spike_waves[index].actor) == actor.id: _spike_waves.remove_at(index)
	actor.effects.clear()
	if dummy: actor.effects["training_dummy"] = true
	actor.alive = true
	if actor.collider != null: actor.collider.set_deferred("disabled", false)
	actor.lms = false
	actor.max_hp = float(PaperData.STATS[actor.character][0])
	actor.hp = actor.max_hp
	actor.max_stamina = float(PaperData.STATS[actor.character][1])
	actor.stamina = actor.max_stamina
	actor.configure_ruleset(actor.ruleset)
	actor.regen_wait = 0.0
	actor.velocity = Vector3.ZERO
	actor.net_velocity = Vector3.ZERO
	actor.net_position = actor.position
	actor.move_input = Vector3.ZERO
	actor.sprint = false
	actor.visual.rotation.z = 0.0
	actor.visual.visible = true
	actor.bot_state.clear()
	for slot in range(6): actor.cooldowns[slot] = 0.0
	if actor.killer: actor.effects["rage"] = 0.0
	_interact_at.erase(actor.id)
	if was_lms: apply_lms(actor)

func _spawn_minions(actor):
	for index in range(world.minions.size() - 1, -1, -1):
		if int(world.minions[index].owner) == int(actor.id): _remove_minion(index, "replaced")
	for side in [-1.0, 1.0]:
		var spawn: Vector3 = actor.position + Vector3.UP * 0.04
		var forward: Vector3 = _aim(actor)
		for offset in [forward.cross(Vector3.UP) * float(side) * 1.25, forward * 1.2, - forward * 1.2, Vector3.ZERO]:
			var candidate: Vector3 = actor.position + offset + Vector3.UP * 0.04
			if not _los(actor.position, candidate): continue
			var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
			query.shape = actor.collider.shape
			query.transform = Transform3D(Basis.IDENTITY, candidate + Vector3.UP * 0.95)
			query.collision_mask = 1
			if actor.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
				spawn = candidate
				break
		var body: CharacterBody3D = CharacterBody3D.new()
		body.name = "ShadowPhysics_%d" % _next_minion
		body.collision_layer = 0
		body.collision_mask = 1
		body.floor_snap_length = 0.4
		var collider: CollisionShape3D = CollisionShape3D.new()
		var shape: CapsuleShape3D = CapsuleShape3D.new()
		shape.radius = 0.38
		shape.height = 1.8
		collider.shape = shape
		collider.position.y = 0.91
		body.add_child(collider)
		world.add_child(body)
		body.position = spawn
		var minion: Dictionary = {"id": _next_minion, "owner": actor.id, "position": spawn, "aim": forward, "target": -1, "ttl": 25.0, "attack_cd": 0.6}
		world.minions.append(minion)
		_minion_bodies[_next_minion] = body
		_minion_paths[_next_minion] = {"points": PackedVector3Array(), "next": 0.0, "target": -1}
		world.event("minion", {"action": "spawn", "id": _next_minion, "owner": actor.id, "position": spawn})
		_next_minion += 1

func _minion_index(minion_id: int) -> int:
	for index in range(world.minions.size()):
		if int(world.minions[index].id) == minion_id: return index
	return -1

func _tick_minions(delta: float):


	var snapshot: Array[Dictionary] = world.minions.duplicate()
	for position_in_snapshot in range(snapshot.size() - 1, -1, -1):
		var minion: Dictionary = snapshot[position_in_snapshot]
		if not _minion_paths.has(int(minion.id)): continue
		minion.ttl = float(minion.ttl) - delta
		var source = _actor(int(minion.owner))
		if float(minion.ttl) <= 0.0 or not _can_act(source):
			_remove_minion(_minion_index(int(minion.id)), "expired")
			continue
		var body: CharacterBody3D = _minion_bodies.get(int(minion.id))
		if not is_instance_valid(body):
			_remove_minion(_minion_index(int(minion.id)), "missing")
			continue
		var target = _actor(int(minion.target))
		if not _can_act(target) or target.killer:
			var nearest: float = INF
			for candidate in world.actors.values():
				if not _can_act(candidate) or candidate.killer: continue
				var distance: float = body.position.distance_to(candidate.position)

				for other in world.minions:
					if int(other.id) != int(minion.id) and int(other.target) == int(candidate.id): distance += 12.0
				if distance < nearest:
					nearest = distance
					target = candidate
			minion.target = -1 if target == null else int(target.id)
		var direction: Vector3 = Vector3.ZERO
		if target != null:
			var path_state: Dictionary = _minion_paths[int(minion.id)]
			var retarget: bool = int(path_state.target) != int(target.id)
			var stale: bool = path_state.points.is_empty() or Vector3(path_state.get("goal", Vector3.INF)).distance_to(target.position) > 1.5
			if retarget or (float(world.clock) >= float(path_state.next) and stale):
				path_state.points = world.school.nav_path(body.position, target.position, -1)

				path_state.next = float(world.clock) + randf_range(0.55, 0.7)
				path_state.target = target.id
				path_state.goal = target.position
			var points: PackedVector3Array = path_state.points
			while not points.is_empty() and _flat(points[0] - body.position).length() < 0.65 and ( not _om(source) or absf(points[0].y - body.position.y) < 0.7): points.remove_at(0)
			path_state.points = points
			if not points.is_empty(): direction = _flat(points[0] - body.position).normalized()
			elif _los(body.position, target.position): direction = _flat(target.position - body.position).normalized()
			if body.position.distance_to(target.position) < 0.9: direction = Vector3.ZERO
		body.velocity.x = direction.x * (6.7 if _om(source) else 4.8)
		body.velocity.z = direction.z * (6.7 if _om(source) else 4.8)
		body.velocity.y = -0.2 if body.is_on_floor() else body.velocity.y - 20.0 * delta
		body.move_and_slide()
		minion.position = body.position
		if direction.length_squared() > 0.01: minion.aim = direction
		minion.attack_cd = maxf(0.0, float(minion.attack_cd) - delta)
		if target != null and float(minion.attack_cd) <= 0.0 and body.position.distance_to(target.position) <= 1.45 and _los(body.position, target.position):
			minion.attack_cd = 2.5
			var strike_from: Vector3 = body.position
			world.event("minion", {"action": "attack", "id": minion.id, "owner": minion.owner, "position": strike_from, "target": target.id})

			damage(target, 10.0, source, true, "shadow", strike_from)

func _remove_minion(index: int, reason: String = "dispel"):
	if index < 0 or index >= world.minions.size(): return
	var minion: Dictionary = world.minions[index]
	var body = _minion_bodies.get(int(minion.id))
	if is_instance_valid(body): body.queue_free()
	_minion_bodies.erase(int(minion.id))
	_minion_paths.erase(int(minion.id))
	world.minions.remove_at(index)
	world.event("minion", {"action": "disperse", "id": minion.id, "owner": minion.owner, "position": minion.position, "reason": reason})

func _dispel_radius(center: Vector3, radius: float, _source_id: int):
	for index in range(world.minions.size() - 1, -1, -1):
		var minion: Dictionary = world.minions[index]
		if center.distance_to(minion.position) <= radius and _los(center, minion.position): _remove_minion(index)

func _dispel_box(origin: Vector3, direction: Vector3, size: Vector3) -> int:
	var count: int = 0
	for index in range(world.minions.size() - 1, -1, -1):
		var minion: Dictionary = world.minions[index]
		var center: Vector3 = origin + direction * (size.z * 0.5 - 0.25)
		var offset: Vector3 = minion.position - center
		if absf(offset.dot(direction.cross(Vector3.UP))) <= size.x * 0.5 + 0.38 and absf(offset.dot(direction)) <= size.z * 0.5 + 0.38 and absf(offset.y) <= size.y * 0.5 + 0.9 and _los(origin, minion.position):
			_remove_minion(index)
			count += 1
	return count

func _support_against_minion(actor, slot: int) -> bool:

	var cooldown: float = 0.0
	if actor.character == "Elly" and slot == 0: cooldown = 35.0
	if actor.character == "Bleuette" and slot == 0: cooldown = 40.0
	if actor.character == "Bleuette" and slot == 1: cooldown = 45.0
	if cooldown <= 0.0: return false
	if _dispel_box(actor.position, _aim(actor), Vector3(2.8, 2.2, 6.0)) == 0: return false
	_set_cd(actor, slot, cooldown)
	world.event("boost", {"actor": actor.id, "target": actor.id, "position": actor.position})
	return true

func _dispel_support_minions(actor, slot: int):
	var radius: float = 0.0
	match str(actor.character):
		"Ashura":
			if slot in [0, 1]: radius = 2.5
		"Usayuko":
			if slot == 1: radius = 2.5
		"Simon":
			if slot == 1: radius = 2.5
		"Lysia":
			if slot == 0: _dispel_box(actor.position, _aim(actor), Vector3(2.8, 2.2, 3.0))
			if slot == 2: radius = 6.0
		"Elly":
			if slot == 0: radius = 3.0
			if slot == 1: radius = 5.0
			if slot == 3: _dispel_box(actor.position, _aim(actor), Vector3(1.6, 2.2, 25.0))
		"Bleuette": radius = 6.0 if slot != 3 else 5.0
	if radius > 0.0: _dispel_radius(actor.position, radius, actor.id)

func _tick_projectiles(delta: float):
	for index in range(world.projectiles.size() - 1, -1, -1):
		var projectile: Dictionary = world.projectiles[index]
		var source = _actor(int(projectile.owner))
		projectile.age = float(projectile.age) + delta
		projectile.ttl = float(projectile.ttl) - delta
		if str(projectile.stage) == "windup":
			if not _can_act(source) or _effect(source, "stun") > 0.0:
				if source != null: source.effects["grenade_windup"] = 0.0
				world.projectiles.remove_at(index)
				continue
			source.effects["grenade_windup"] = maxf(0.0, 0.35 - float(projectile.age))
			projectile.position = _grenade_hand_position(source)
			if float(projectile.age) < 0.35: continue
			projectile.stage = "flight"
			projectile.velocity = _aim(source) * 13.3 + Vector3.UP * 3.2
			world.event("grenade", {"action": "throw", "id": projectile.id, "actor": source.id, "position": projectile.position, "velocity": projectile.velocity})
		var remaining: float = delta
		while remaining > 0.0001:
			var step: float = minf(remaining, 1.0 / 120.0)
			remaining -= step
			var velocity: Vector3 = projectile.velocity
			velocity.y -= 14.0 * step
			var start: Vector3 = projectile.position
			var end: Vector3 = start + velocity * step
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, end, 3)
			var collision: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
			if not collision.is_empty():
				var normal: Vector3 = collision.normal
				projectile.position = collision.position + normal * 0.07
				if velocity.length() > 1.5 and float(projectile.age) - float(projectile.get("last_bounce", -1.0)) > 0.12:
					projectile.last_bounce = projectile.age
					world.event("grenade", {"action": "bounce", "id": projectile.id, "actor": projectile.owner, "position": projectile.position})
				velocity = velocity.bounce(normal) * 0.45
			else: projectile.position = end
			projectile.velocity = velocity
		if float(projectile.ttl) <= 0.0:
			_explode_grenade(projectile, source)
			world.projectiles.remove_at(index)

func _grenade_hand_position(source) -> Vector3:
	var chest: Vector3 = source.position + Vector3.UP * 1.3
	var hand: Vector3 = chest + _aim(source).cross(Vector3.UP) * 0.28
	if is_instance_valid(source.visual) and source.visual.has_method("hand_position"):
		var socket: Variant = source.visual.hand_position()
		if socket is Vector3 and socket.is_finite() and socket.distance_to(source.position) < 2.0: hand = socket


	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(chest, hand, 3)
	var collision: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
	if not collision.is_empty(): hand = collision.position + collision.normal * 0.07
	return hand

func _explode_grenade(projectile: Dictionary, source):
	var pos: Vector3 = projectile.position
	var ground: Vector3 = pos - Vector3.UP * 1.1
	var target = world.killer_actor()
	if target != null and (target.position.distance_to(pos) if _om(source) else _flat(target.position - pos).length()) <= 4.5 and _los(ground, target.position):
		var distance: float = _flat(target.position - pos).length()
		var duration: float = lerpf(4.0, 2.0, clampf(distance / 4.5, 0.0, 1.0))
		stun(target, duration, source)
		target.effects["blind"] = maxf(_effect(target, "blind"), 1.4)
		world.event("flash", {"actor": target.id, "position": pos, "duration": 1.4})
	_dispel_radius(ground, 4.5, int(projectile.owner))
	world.event("grenade", {"action": "explode", "id": projectile.id, "actor": projectile.owner, "position": pos})

	world.event("flash", {"actor": -1, "owner": projectile.owner, "position": pos, "duration": 0.2, "world_only": true})

func _tick_zones(delta: float):
	var recipients: Dictionary = {}
	for index in range(world.zones.size() - 1, -1, -1):
		var zone: Dictionary = world.zones[index]
		var left: float = maxf(0.0, float(zone.get("left", 0.0)))
		var active: float = minf(delta, left)
		var pos: Vector3 = zone.get("position", Vector3.ZERO)
		_dispel_radius(pos, float(zone.get("radius", 5.0)), int(zone.get("owner", -1)))
		for actor in world.actors.values():

			if _can_act(actor) and not actor.killer and actor.character != "Lysia" and float(actor.hp) < PaperSurvivorMechanics.heal_ceiling(actor) and actor.position.distance_to(pos) <= float(zone.get("radius", 5.0)) and _zone_sees(pos, actor):
				if active * 2.0 > float(recipients.get(actor.id, {}).get("amount", 0.0)): recipients[actor.id] = {"amount": active * 2.0, "owner": int(zone.get("owner", -1))}
		zone["left"] = maxf(0.0, left - delta)
		if float(zone.left) <= 0.0: world.zones.remove_at(index)
	for actor_id in recipients:
		var actor = _actor(int(actor_id))
		if actor == null: continue
		var before: float = actor.hp
		actor.hp = minf(PaperSurvivorMechanics.heal_ceiling(actor), before + float(recipients[actor_id].amount))
		_reward("heal", _actor(int(recipients[actor_id].owner)), actor.hp - before)

func _zone_sees(center: Vector3, actor) -> bool:
	var key: Vector3 = center + Vector3(0.0, float(actor.id) * 1000.0, 0.0)
	var cached: Variant = _zone_sight.get(key)
	var now: float = float(world.clock)
	if cached is Vector2 and now < cached.x: return cached.y > 0.5
	var seen: bool = _los(center, actor.position)
	_zone_sight[key] = Vector2(now + 0.25, 1.0 if seen else 0.0)
	if _zone_sight.size() > 64: _zone_sight.clear()
	return seen

func _tick_lms(actor):
	if not actor.lms: return
	if _om(actor) and not bool(actor.effects.get("lms_buff_unlocked", false)) and _effect(actor, "aura_charge") >= 100.0: _unlock_lms(actor)
	if not lms_available(actor) or actor.character != "Lysia": return
	var now: float = float(world.clock)
	if bool(actor.effects.get("lms_qte_ready", false)):
		if now > float(actor.effects.get("lms_qte_expires", 0.0)):
			actor.effects["lms_qte_ready"] = false
			actor.effects["lms_qte_next"] = now + ASSIST_PERIOD
			world.event("qte", {"actor": actor.id, "ready": false, "success": false})
		elif _automatic_assist_allowed(actor) and now >= float(actor.effects.get("lms_qte_auto_at", INF)):

			actor.effects["lms_qte_auto_at"] = INF
			if bool(world.get("training")) or randf() < 0.8:
				var hurt: bool = float(actor.hp) < float(actor.max_hp) * 0.65

				var choice: String = ("stamina" if hurt else "health") if _om(actor) else ("health" if hurt else "stamina")
				assist(-1, actor.id, choice)
		return
	if now >= float(actor.effects.get("lms_qte_next", now + ASSIST_PERIOD)):
		actor.effects["lms_qte_ready"] = true
		actor.effects["lms_qte_started"] = now
		actor.effects["lms_qte_expires"] = now + 6.0
		actor.effects["lms_qte_auto_at"] = now + 1.5
		var helper: int = -1
		if not bool(world.get("training")):
			for candidate in world.actors.values():
				if not candidate.alive and not candidate.bot and not candidate.killer:
					helper = int(candidate.id)
					break
		actor.effects["lms_qte_helper"] = helper
		world.event("qte", {"actor": actor.id, "ready": true, "helper": helper, "duration": 6.0, "started": now, "period": 2.4, "automated": helper == -1})

func _automatic_assist_allowed(actor) -> bool:


	if bool(world.get("training")): return true
	for candidate in world.actors.values():
		if int(candidate.id) != int(actor.id) and not candidate.alive and not candidate.bot and not candidate.killer: return false
	return true

func _lysia_damage_cap(actor):
	var cap: float = float(actor.effects.get("damage_stamina_cap", 300.0))
	if cap < 0.0: cap = 300.0
	cap = minf(cap, 300.0)
	if float(actor.hp) < float(actor.max_hp) * 0.5: cap = minf(cap, 100.0)
	if float(actor.hp) < float(actor.max_hp) * 0.3: cap = minf(cap, 70.0)
	actor.effects["damage_stamina_cap"] = cap
	_lysia_update_cap(actor)

func _lysia_update_cap(actor):
	if _om(actor):
		actor.max_stamina = -1.0;actor.stamina = -1.0
		return
	var cap: float = float(actor.effects.get("damage_stamina_cap", -1.0))
	if bool(actor.effects.get("consumed", false)):
		cap = 150.0 if cap < 0.0 else minf(cap, 150.0)
	if cap >= 0.0:
		cap += float(actor.effects.get("qte_stamina_bonus", 0.0))
		var was_infinite: bool = float(actor.max_stamina) < 0.0
		actor.max_stamina = cap
		actor.stamina = cap if was_infinite else minf(float(actor.stamina), cap)

func _heal(actor, amount: float, source):
	if not _can_act(actor) or actor.killer: return
	if actor.character == "Lysia" and source != null and source.character == "Elly": return
	var before: float = float(actor.hp)
	actor.hp = minf(PaperSurvivorMechanics.heal_ceiling(actor), before + amount)
	_reward("heal", source, float(actor.hp) - before)
	world.event("heal", {"actor": actor.id, "source": -1 if source == null else source.id, "amount": float(actor.hp) - before, "position": actor.position})

func _set_cd(actor, slot: int, seconds: float):
	var factor: float = float(actor.effects.get("lms_cd_factor", 1.0))
	if _om(actor) and actor.character in ["Ashura", "Simon"] and slot == 1 and lms_available(actor): factor = 0.85
	var discount: float = float(actor.effects.get("cooldown_discount", 0.0))
	if discount > 0.0:
		factor *= 1.0 - clampf(discount, 0.0, 0.5)
		actor.effects["cooldown_discount"] = 0.0
	actor.cooldowns[slot] = seconds * factor

func _slow(actor, factor: float, duration: float, tag: String = ""):
	var entries: Array = _entries(actor, SLOW_ENTRIES)
	if not tag.is_empty():
		for index in range(entries.size() - 1, -1, -1):
			if str(entries[index].get("tag", "")) == tag: entries.remove_at(index)
	entries.append({"factor": factor, "left": duration, "tag": tag})
	actor.effects[SLOW_ENTRIES] = entries
	_refresh_modifier(actor, "slow", entries)

func _remove_slow(actor, tag: String):
	var entries: Array = _entries(actor, SLOW_ENTRIES)
	for index in range(entries.size() - 1, -1, -1):
		if str(entries[index].get("tag", "")) == tag: entries.remove_at(index)
	actor.effects[SLOW_ENTRIES] = entries
	_refresh_modifier(actor, "slow", entries)

func _speed(actor, factor: float, duration: float):
	var entries: Array = _entries(actor, BOOST_ENTRIES)
	entries.append({"factor": factor, "left": duration})
	actor.effects[BOOST_ENTRIES] = entries
	_refresh_modifier(actor, "boost", entries)

func _entries(actor, key: String) -> Array:
	var entries: Variant = actor.effects.get(key)
	return entries if entries is Array else []


func _tick_modifiers(actor, delta: float):
	_tick_modifier_kind(actor, delta, SLOW_ENTRIES, "slow")
	_tick_modifier_kind(actor, delta, BOOST_ENTRIES, "boost")

func _tick_modifier_kind(actor, delta: float, key: String, kind: String):
	var entries: Variant = actor.effects.get(key)
	if not entries is Array or entries.is_empty():
		var factor_key: String = "slow_factor" if kind == "slow" else "boost_factor"
		var time_key: String = "slow_time" if kind == "slow" else "boost_time"
		if float(actor.effects.get(time_key, 0.0)) != 0.0 or float(actor.effects.get(factor_key, 1.0)) != 1.0:
			actor.effects[factor_key] = 1.0
			actor.effects[time_key] = 0.0
		return
	for index in range(entries.size() - 1, -1, -1):
		var entry: Dictionary = entries[index]
		entry["left"] = float(entry.get("left", 0.0)) - delta
		if float(entry.left) <= 0.0: entries.remove_at(index)
	_refresh_modifier(actor, kind, entries)

func _refresh_modifier(actor, kind: String, entries: Array):
	var slow: bool = kind == "slow"
	var factor: float = 1.0
	var remaining: float = 0.0
	for entry in entries:
		var value: float = float(entry.get("factor", 1.0))
		factor = minf(factor, value) if slow else maxf(factor, value)
		remaining = maxf(remaining, float(entry.get("left", 0.0)))
	if slow:
		actor.effects["slow_factor"] = factor
		actor.effects["slow_time"] = remaining
	else:
		actor.effects["boost_factor"] = factor
		actor.effects["boost_time"] = remaining

func _effect(actor, key: String) -> float:
	return float(actor.effects.get(key, 0.0)) if actor != null else 0.0

func _actor(actor_id: int):
	return world.actors.get(actor_id, null)

func _ally(actor, target_id: int, distance: float, injured: bool):
	if target_id >= 0:
		var requested = _actor(target_id)
		if _can_act(requested) and not requested.killer and not (actor.character == "Elly" and requested.character == "Lysia") and int(requested.id) != int(actor.id) and actor.position.distance_to(requested.position) <= distance and ( not injured or float(requested.hp) < float(requested.max_hp)) and _los(actor.position, requested.position):
			return requested
		return null
	var best = null
	var best_distance: float = distance + 0.01
	for ally in world.actors.values():
		if actor.character == "Elly" and ally.character == "Lysia": continue
		if not _can_act(ally) or ally.killer or int(ally.id) == int(actor.id) or (injured and float(ally.hp) >= float(ally.max_hp)): continue
		var current: float = actor.position.distance_to(ally.position)
		if current < best_distance and _los(actor.position, ally.position):
			best = ally
			best_distance = current
	return best



func _heal_target(actor, target_id: int):
	if target_id >= 0: return _ally(actor, target_id, 6.0, true)
	var best = null
	var best_score: float = INF
	for ally in world.actors.values():
		if ally.character == "Lysia" or not _can_act(ally) or ally.killer or int(ally.id) == int(actor.id) or float(ally.hp) >= float(ally.max_hp): continue
		var distance: float = actor.position.distance_to(ally.position)
		if distance > 6.0: continue
		var offset: Vector3 = _flat(ally.position - actor.position)
		var facing: float = offset.normalized().dot(_aim(actor)) if offset.length() > 0.1 else 1.0
		var score: float = distance - maxf(0.0, facing) * 10.0
		if score < best_score and _los(actor.position, ally.position):
			best = ally
			best_score = score
	return best

func _support_eligible(actor, slot: int, target) -> bool:
	if not _can_act(target) or target.killer or target.id == actor.id: return false
	if slot == 0:
		match str(target.character):
			"Ashura": return not bool(target.effects.get("drone_bonus", false))
			"Usayuko": return _effect(target, "next_stun") <= 0.0
			"Simon": return _effect(target, "sprint_bonus") <= 0.0
			"Lysia": return _effect(target, "cooldown_discount") <= 0.0
			"Elly": return _effect(target, "next_heal") <= 1.0
		return false
	var killer = world.killer_actor()
	if not _can_act(killer) or target.position.distance_to(killer.position) > 12.0: return false
	for key in target.cooldowns:
		if _rechargeable_slot(target, int(key)): return true
	return false


func support_eligible(actor, slot: int, target) -> bool:
	return _support_eligible(actor, slot, target)



func _rechargeable_slot(target, slot: int) -> bool:
	if target.character == "Bleuette" and slot == 1: return false
	if target.character in ["Simon", "Ashura"] and slot == 2: return false
	return float(target.cooldowns.get(slot, 0.0)) >= 1.0

func _support_target(actor, slot: int, target_id: int = -1):
	if target_id >= 0:
		var requested = _ally(actor, target_id, 6.0, false)
		return requested if _support_eligible(actor, slot, requested) and ( not _om(actor) or _in_front(actor, requested, 6.0, 0.88)) else null
	var best = null
	var best_score: float = INF
	for target in world.actors.values():
		if not _support_eligible(actor, slot, target): continue
		var offset: Vector3 = _flat(target.position - actor.position)
		if offset.length() > 6.0 or not _los(actor.position, target.position): continue
		if _om(actor) and not _in_front(actor, target, 6.0, 0.88): continue


		var score: float = offset.length() - maxf(0.0, offset.normalized().dot(_aim(actor))) * (10.0 if _om(actor) else 1.8)
		if score < best_score:
			best = target
			best_score = score
	return best

func support_target_preview(actor, slot: int) -> Dictionary:
	var target = _support_target(actor, slot)
	return {"target": -1 if target == null else target.id, "ready": target != null, "reason": ("Vise un allié compatible à moins de 6 m" if slot == 0 else "Allié à moins de 6 m, près d’Alice, avec une recharge en cours") if target == null else ("Encourager " if slot == 0 else "Recharger ") + str(target.character)}

func _support_failure(actor, slot: int, _target_id: int):
	var line: String = "ENCOURAGER · vise un allié à moins de 6 m : Ashura, Usayuko, Simon, Lysia ou Elly. Un bonus déjà prêt ne se cumule pas."
	if slot == 1: line = "JE CROIS EN TOI · il faut un allié à moins de 6 m, à moins de 12 m d’Alice, avec une capacité en recharge."
	_message(actor, line)

func _front_killer(actor, distance: float, dot_min: float):
	var target = world.killer_actor()
	return target if _in_front(actor, target, distance, dot_min) else null

func _front_survivor(actor, distance: float, dot_min: float):
	var best = null
	var nearest: float = distance + 0.01
	for target in world.actors.values():
		if target.killer or not _in_front(actor, target, distance, dot_min): continue
		var current: float = actor.position.distance_to(target.position)
		if current < nearest:
			best = target
			nearest = current
	return best

func _in_front(actor, target, distance: float, dot_min: float) -> bool:
	if not _can_act(target) or int(target.id) == int(actor.id): return false
	var offset: Vector3 = _flat(target.position - actor.position)
	if _om(actor) and distance <= 6.0 and absf(target.position.y - actor.position.y) > 1.8: return false
	var range_to_target: float = actor.position.distance_to(target.position) if _om(actor) else offset.length()
	return range_to_target <= distance and (offset.length() < 0.1 or offset.normalized().dot(_aim(actor)) >= dot_min) and _los(actor.position, target.position)

func _aim(actor) -> Vector3:
	var direction: Vector3 = _flat(actor.aim)
	return direction.normalized() if direction.length_squared() > 0.001 else Vector3.FORWARD

func _flat(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)

func _los(start: Vector3, end: Vector3) -> bool:
	if start.distance_to(end) < 0.1: return true

	return bool(world.visible(start, end))

func _trace_endpoint(start: Vector3, direction: Vector3, distance: float) -> Vector3:
	var end: Vector3 = start
	var steps: int = maxi(1, int(ceil(distance / 0.4)))
	for index in range(1, steps + 1):
		var candidate: Vector3 = start + direction * minf(distance, float(index) * 0.4)
		if not _los(start, candidate): break
		end = candidate
	return end


func _ray_endpoint(start: Vector3, direction: Vector3, distance: float) -> Vector3:
	var from: Vector3 = start + Vector3.UP * 1.1
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + direction * distance, 1)
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return start + direction * distance
	return start + direction * maxf(0.0, from.distance_to(Vector3(hit.position)) - 0.05)

func _knock(actor, direction: Vector3, distance: float):
	_start_motion(actor, direction, distance, 0.55, "knock")

func _start_motion(actor, direction: Vector3, distance: float, duration: float, kind: String):
	if actor == null or distance <= 0.0 or duration <= 0.0: return
	actor.effects["forced_direction"] = _flat(direction).normalized()
	actor.effects["forced_time"] = duration
	actor.effects["forced_speed"] = distance / duration
	actor.effects["force_name"] = kind
	world.event("knockback" if kind == "knock" else "dash", {"actor": actor.id, "position": actor.position, "distance": distance, "duration": duration, "direction": _flat(direction).normalized()})

func _mark_motion(actor):
	actor.effects["motion_owned"] = true

func _tick_forced_motion(actor, delta: float):
	var left: float = _effect(actor, "forced_time")
	if left <= 0.0: return
	if str(actor.effects.get("force_name", "")) != "knock" and _effect(actor, "stun") > 0.0:
		actor.effects["forced_time"] = 0.0
		actor.velocity = Vector3.ZERO
		return
	var direction: Vector3 = actor.effects.get("forced_direction", Vector3.ZERO)
	var start: Vector3 = actor.position
	var motion: Vector3 = direction * _effect(actor, "forced_speed") * minf(left, delta)
	var blocked: bool = false
	if _om(actor): blocked = _om_slide(actor, motion, delta)
	else: blocked = actor.move_and_collide(motion) != null
	actor.velocity = (actor.position - start if _om(actor) else _flat(actor.position - start)) / maxf(delta, 0.001)
	actor.effects["forced_time"] = 0.0 if blocked else maxf(0.0, left - delta)
	_mark_motion(actor)
	if _effect(actor, "forced_time") <= 0.0: actor.velocity = Vector3.ZERO

func _tick_shadow(actor, delta: float):
	if _om(actor):
		_tick_decoy_emergence(actor, delta)
		return
	var left: float = _effect(actor, "shadow_time")
	if left <= 0.0: return
	var target = _actor(int(actor.effects.get("shadow_target", -1)))
	actor.effects["shadow_time"] = maxf(0.0, left - delta)
	actor.velocity = Vector3.ZERO
	_mark_motion(actor)
	if _can_act(target):
		target.effects["shadow_mark"] = maxf(0.0, left - delta)
		if left > delta:


			var desired: Vector3 = _shadow_destination(actor, target, 1.0)
			actor.move_and_collide(_flat(desired - actor.position))
			return
		actor.position = _shadow_destination(actor, target, 2.0)
		actor.aim = _flat(target.position - actor.position).normalized()
		actor.effects["attack_lock"] = 0.25
	actor.effects["shadow_time"] = 0.0
	actor.effects["shadow_hide"] = false
	actor.effects["shadow_target"] = -1
	world.event("shadow", {"actor": actor.id, "position": actor.position, "active": false})

func _shadow_destination(actor, target, distance: float) -> Vector3:
	var behind: Vector3 = - _aim(target)
	for offset in [behind * distance, behind * 1.15, behind.rotated(Vector3.UP, 0.65) * 1.5, behind.rotated(Vector3.UP, -0.65) * 1.5]:


		var desired: Vector3 = target.position + offset + Vector3.UP * 0.05
		if not _los(target.position, desired): continue
		if actor.get_world_3d().direct_space_state.intersect_shape(_body_query(actor, desired), 1).is_empty(): return desired
	return actor.position



func _emit_box(actor, size: Vector3, duration: float, direction: Vector3 = Vector3.ZERO, cast_id: int = 0):
	if direction.length_squared() < 0.001: direction = _aim(actor)
	var offset: Vector3 = direction * (size.z * 0.5 - 0.25) + Vector3.UP
	world.event("hitbox", {"actor": actor.id, "position": actor.position + offset, "offset": offset, "aim": direction, "size": size, "duration": duration, "cast_id": cast_id, "follow": true})


func _end_box(actor, cast_id: int, planned_until: float):
	if actor == null or cast_id <= 0 or planned_until - float(world.clock) < 0.2: return
	world.event("hitbox", {"actor": actor.id, "position": actor.position + Vector3.UP, "offset": Vector3.UP, "aim": _aim(actor), "size": Vector3.ZERO, "duration": 0.0, "cast_id": cast_id, "follow": true, "end": true})

func _begin_attack(actor, size: Vector3, payload: Dictionary, duration: float = 0.15):
	var attack: Dictionary = {"actor": actor.id, "aim": _aim(actor), "size": size, "left": duration, "payload": payload, "hit": {}, "previous": actor.position, "cast_id": _next_cast, "guarded": {}}
	_next_cast += 1
	_attacks.append(attack)
	_emit_box(actor, size, duration, attack.aim, int(attack.cast_id))
	_sample_attack(attack, actor.position)

func _inside_box(origin: Vector3, direction: Vector3, size: Vector3, target) -> bool:
	if not _can_act(target): return false
	var center: Vector3 = origin + direction * (size.z * 0.5 - 0.25) + Vector3.UP
	var offset: Vector3 = target.position + Vector3.UP * 0.9 - center
	var side: Vector3 = direction.cross(Vector3.UP)

	return absf(offset.dot(side)) <= size.x * 0.5 + 0.38 and absf(offset.dot(direction)) <= size.z * 0.5 + 0.38 and absf(offset.y) <= size.y * 0.5 + 0.9

func _sample_attack(attack: Dictionary, origin: Vector3):
	var source = _actor(int(attack.actor))
	if not _can_act(source): return
	if not source.killer: _dispel_box(origin, attack.aim, attack.size)
	var payload: Dictionary = attack.payload
	var contacts: Array = []
	for target in world.actors.values():
		if target.killer == source.killer or attack.hit.has(target.id) or bool(target.effects.get("shadow_hide", false)): continue
		if _inside_box(origin, attack.aim, attack.size, target) and _los(origin, target.position): contacts.append(target)


	if _om(source) and source.killer and payload.has("damage"):
		for guard in contacts:
			if guard.character != "Usayuko": continue
			for friend in contacts:
				if friend == guard or friend.position.distance_to(guard.position) > 1.5 or not _los(guard.position, friend.position): continue
				attack.guarded[friend.id] = guard.id
				_reward("protection", guard, 1.0, "claw_%d" % int(attack.cast_id))
				world.event("protection", {"actor": guard.id, "target": friend.id, "source": source.id, "position": guard.position, "cast_id": attack.cast_id})
	for target in contacts:
		attack.hit[target.id] = true
		if attack.guarded.has(target.id): continue
		if payload.has("damage"): damage(target, float(payload.damage), source, false, str(payload.get("cause", "slash")))
		if payload.has("stun"): stun(target, float(payload.stun), source)
		if payload.has("blind"):
			target.effects["blind"] = maxf(_effect(target, "blind"), float(payload.blind))
			world.event("flash", {"actor": target.id, "position": target.position, "duration": float(payload.blind)})
		if payload.has("knock"): _knock(target, attack.aim, float(payload.knock))

func _tick_attacks(delta: float):
	for index in range(_attacks.size() - 1, -1, -1):
		var attack: Dictionary = _attacks[index]
		var source = _actor(int(attack.actor))
		if not _can_act(source) or _effect(source, "stun") > 0.0 or bool(source.effects.get("shadow_hide", false)):
			_end_box(source, int(attack.cast_id), float(world.clock) + float(attack.left))
			_attacks.remove_at(index)
			continue
		var previous: Vector3 = attack.previous
		var steps: int = maxi(1, int(ceil(previous.distance_to(source.position) / 0.4)))

		for step in range(1, steps + 1):
			_sample_attack(attack, previous.lerp(source.position, float(step) / float(steps)))
		attack.previous = source.position
		attack.left = float(attack.left) - delta
		if float(attack.left) <= 0.0: _attacks.remove_at(index)

func _segment_distance(point: Vector3, start: Vector3, end: Vector3) -> float:
	var segment: Vector3 = _flat(end - start)
	if segment.length_squared() < 0.001: return _flat(point - start).length()
	var t: float = clampf(_flat(point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return _flat(point - (start + segment * t)).length()

func _ability_name(character: String, slot: int) -> String:
	if character == "Ashura" and slot == 2: return "Drone Mode"
	var names: Dictionary = {
		"Alice": ["Slash", "Shadow Reveal", "Shadow Spike", "Ombres / Bond", "Doubles d'ombre", "True Form"], 
		"Ashura": ["Drone", "Roller Boost", "", ""], 
		"Usayuko": ["Grab", "Block / Contre", "Punch", "Dropkick"], 
		"Simon": ["Flashbang", "Boost de vitesse", "", ""], 
		"Lysia": ["Surchauffe", "Consommation", "Xray", "Recharge électrique"], 
		"Elly": ["Soin", "Zone de soin", "", "Shotgun"], 
		"Bleuette": ["Boost", "Je crois en toi", "Chocolat", "Je peux le faire !"]
	}
	var list: Array = names.get(character, [])
	return str(list[slot]) if slot >= 0 and slot < list.size() else "Capacité"

func _spike_ground_points(source) -> PackedVector3Array:
	var start: Vector3 = source.position
	var direction: Vector3 = _aim(source)
	var points: PackedVector3Array = PackedVector3Array()
	var previous: Vector3 = start
	var ground_y: float = start.y
	for i in range(10):
		var point: Vector3 = start + direction * float(i + 1) * 1.5


		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(point.x, ground_y + 0.8, point.z), Vector3(point.x, ground_y - 1.0, point.z), 1)
		var floor_hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
		if floor_hit.is_empty() or Vector3(floor_hit.normal).y < 0.65: break
		point.y = Vector3(floor_hit.position).y
		if not _los(previous, point): break
		points.append(point);ground_y = point.y;previous = point
	return points

func _begin_spike_wave(source):
	var start: Vector3 = source.position
	var points: PackedVector3Array = _spike_ground_points(source)
	if points.is_empty(): return
	var cells: Array[Dictionary] = []
	var previous: Vector3 = start
	for i in points.size():
		cells.append({"from": previous, "to": points[i], "at": 0.12 + float(i) * 0.05, "shown": false})
		previous = points[i]
	var cast_id: int = _next_cast;_next_cast += 1
	_spike_waves.append({"actor": source.id, "age": 0.0, "cells": cells, "hit": {}, "cast_id": cast_id})
	world.event("spike", {"actor": source.id, "from": start, "to": previous, "width": 2.8, "duration": 0.12, "telegraph": true, "cast_id": cast_id})

func _tick_spike_waves(delta: float):
	for index in range(_spike_waves.size() - 1, -1, -1):
		var wave: Dictionary = _spike_waves[index]
		var source = _actor(int(wave.actor))
		if source == null or not source.alive:
			_spike_waves.remove_at(index);continue
		wave.age = float(wave.age) + delta
		for cell in wave.cells:
			if float(wave.age) < float(cell.at): continue
			if not bool(cell.shown):
				cell.shown = true
				world.event("spike", {"actor": source.id, "from": cell.from, "to": cell.to, "width": 2.8, "duration": 0.65, "telegraph": false, "segment": true, "cast_id": wave.cast_id})
			if float(wave.age) > float(cell.at) + 0.2: continue
			var segment: Vector3 = cell.to - cell.from
			for target in world.actors.values():
				if not _can_act(target) or target.killer or wave.hit.has(target.id): continue
				var t: float = clampf((target.position - cell.from).dot(segment) / maxf(segment.length_squared(), 0.001), 0.0, 1.0)
				var closest: Vector3 = cell.from + segment * t
				if _flat(target.position - closest).length() > 1.78 or target.position.y - closest.y > 1.3 or target.position.y - closest.y < -0.6: continue
				if not _los(closest, target.position): continue
				wave.hit[target.id] = true
				var health: float = target.hp
				damage(target, 20.0, source, false, "spike")
				if target.alive and target.hp < health: _slow(target, 0.85, 3.0)
		if float(wave.age) > 1.0: _spike_waves.remove_at(index)

func _om_slide(actor, motion: Vector3, delta: float) -> bool:


	actor.velocity.x = motion.x / maxf(delta, 0.001)
	actor.velocity.z = motion.z / maxf(delta, 0.001)
	actor.velocity.y = -0.2 if actor.is_on_floor() and actor.velocity.y <= 0 else actor.velocity.y - PaperRules.OM_GRAVITY * delta
	actor.move_and_slide()
	for i in actor.get_slide_collision_count():
		if actor.get_slide_collision(i).get_normal().dot(Vector3.UP) < 0.65: return true
	return false

const DECOY_CANDIDATES: int = 12

func _decoy_spot(actor, target) -> Vector3:
	var behind: Vector3 = - _aim(target)
	var space: PhysicsDirectSpaceState3D = actor.get_world_3d().direct_space_state
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	ray.collision_mask = 1
	var tried: int = 0
	for distance in [3.5, 4.2, 2.8]:
		for angle in [0.0, 0.45, -0.45, 0.8, -0.8, 1.2, -1.2]:

			tried += 1
			if tried > DECOY_CANDIDATES: return Vector3(INF, INF, INF)
			var point: Vector3 = target.position + behind.rotated(Vector3.UP, float(angle)) * float(distance)

			var occupied: bool = false
			for other in world.actors.values():
				if other != actor and other.active() and point.distance_to(other.position) < 2.2: occupied = true;break
			if occupied: continue
			ray.from = point + Vector3.UP * 0.9
			ray.to = point - Vector3.UP * 4.5
			var floor_hit: Dictionary = space.intersect_ray(ray)
			if floor_hit.is_empty() or Vector3(floor_hit.normal).y < 0.7: continue
			point.y = Vector3(floor_hit.position).y + 0.06
			if not _los(target.position, point): continue
			if not space.intersect_shape(_body_query(actor, point), 1).is_empty(): continue
			return point
	return Vector3(INF, INF, INF)

func _alice_decoys(actor) -> bool:
	var decoys: Array[Dictionary] = []
	for target in world.actors.values():
		if target.killer or not _can_act(target): continue
		var point: Vector3 = _decoy_spot(actor, target)
		if not point.is_finite(): continue
		decoys.append({"target": target.id, "position": point, "aim": _flat(target.position - point).normalized()})
	if decoys.is_empty():
		_message(actor, "Aucun espace libre derrière les élèves pour émerger.")
		return false
	cancel_aim(actor)
	var chosen: Dictionary = decoys[randi_range(0, decoys.size() - 1)]
	actor.effects["shadow_time"] = 1.2
	actor.effects["shadow_hide"] = true
	actor.effects["shadow_origin"] = actor.position
	actor.effects["shadow_target"] = int(chosen.target)
	actor.effects["shadow_destination"] = chosen.position
	actor.effects["shadow_aim"] = chosen.aim
	actor.velocity = Vector3.ZERO
	_set_cd(actor, 3, 32.0)
	for decoy in decoys:
		var target = _actor(int(decoy.target))
		target.effects["shadow_mark"] = 1.2
		_message(target, "UNE OMBRE DERRIÈRE TOI · Alice émerge dans 1,2 s !")
	world.event("shadow_decoys", {"actor": actor.id, "position": actor.position, "decoys": decoys, "destination": chosen.position, "true_target": chosen.target, "duration": 1.2})
	return true

func _tick_decoy_emergence(actor, delta: float):
	var left: float = _effect(actor, "shadow_time")
	if left <= 0: return
	actor.effects["shadow_time"] = maxf(0.0, left - delta)
	actor.velocity = Vector3.ZERO
	_mark_motion(actor)
	for target in world.actors.values(): target.effects["shadow_mark"] = maxf(0.0, _effect(target, "shadow_mark") - delta)
	if left > delta: return
	var point: Vector3 = actor.effects.get("shadow_destination", actor.position)
	var safe: bool = actor.get_world_3d().direct_space_state.intersect_shape(_body_query(actor, point), 1).is_empty()
	for target in world.actors.values():
		if target != actor and target.active() and point.distance_to(target.position) < 1.5: safe = false
	if safe:
		actor.position = point
		actor.aim = actor.effects.get("shadow_aim", actor.aim)
	actor.effects["shadow_time"] = 0.0;actor.effects["shadow_hide"] = false;actor.effects["shadow_target"] = -1
	actor.effects["attack_lock"] = 0.35
	world.event("shadow", {"actor": actor.id, "position": actor.position, "active": false, "cancelled": not safe})




func trajectory_preview(actor) -> PackedVector3Array:
	var points: PackedVector3Array = PackedVector3Array()
	if actor == null: return points
	var hand: Vector3 = _grenade_hand_position(actor)
	var aim: Vector3 = _aim(actor)
	var now: int = Time.get_ticks_msec()
	var cache: Dictionary = _arc_preview
	if int(cache.get("actor", -1)) == int(actor.id) and now - int(cache.get("at", -100000)) < PREVIEW_CACHE_MS and Vector3(cache.hand).distance_to(hand) < 0.3 and Vector3(cache.aim).dot(aim) > 0.9986:
		var turn: float = Vector3(cache.aim).signed_angle_to(aim, Vector3.UP)
		var cached: PackedVector3Array = cache.points
		for cached_point in cached: points.append(hand + (cached_point - Vector3(cache.hand)).rotated(Vector3.UP, turn))
		return points
	var space: PhysicsDirectSpaceState3D = actor.get_world_3d().direct_space_state
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	ray.collision_mask = 3
	var horizontal: Vector3 = aim * 13.3
	var point: Vector3 = hand
	points.append(point)
	for i in range(1, 31):
		var t: float = float(i) / 40.0

		var next: Vector3 = hand + horizontal * t + Vector3.UP * (3.2 * t - 7.0 * t * (t + 1.0 / 120.0))
		ray.from = point
		ray.to = next
		var contact: Dictionary = space.intersect_ray(ray)
		if not contact.is_empty():
			points.append(Vector3(contact.position))
			break
		point = next
		points.append(point)
	_arc_preview = {"actor": actor.id, "at": now, "hand": hand, "aim": aim, "points": points}
	return points

func begin_charge(actor) -> bool:
	if world.has_method("authoritative") and not world.authoritative(): return false
	if not _can_act(actor) or str(world.phase) != "playing" or actor.character not in ["Simon", "Ashura"]: return false
	if bool(actor.effects.get("boost_charging", false)) or float(actor.cooldowns.get(1, 0)) > 0: return false
	for key in ["stun", "root", "recover", "forced_time", "heal_time", "speed_boost", "overheat_time", "outlet_healing", "attack_lock", "grab_time"]:
		if _effect(actor, key) > 0: return false
	if int(actor.effects.get("carried_by", -1)) >= 0 or bool(actor.effects.get("drone_piloting", false)) or not actor.is_on_floor(): return false
	actor.effects["boost_charging"] = true
	actor.effects["boost_charge"] = 0.0
	actor.effects["charging_boost"] = 0.001
	actor.effects["boost_level"] = 0
	actor.velocity = Vector3.ZERO
	actor.move_input = Vector3.ZERO
	world.event("boost_charge", {"actor": actor.id, "position": actor.position, "active": true})
	return true

func _cancel_charge(actor):
	if actor == null: return
	actor.effects["boost_charging"] = false
	actor.effects["boost_charge"] = 0.0
	actor.effects["charging_boost"] = 0.0

func release_charge(actor) -> bool:
	if world.has_method("authoritative") and not world.authoritative(): return false
	if actor == null or not bool(actor.effects.get("boost_charging", false)): return false
	var charged: float = _effect(actor, "boost_charge")
	_cancel_charge(actor)
	if not _can_act(actor) or str(world.phase) != "playing" or _effect(actor, "stun") > 0 or charged < 1.0: return false
	var level: int = 3 if charged >= 3.0 else 2 if charged >= 2.0 else 1
	var duration: float = 6.0 if level == 3 else 4.0 if level == 2 else 3.0
	if actor.character == "Simon" and _effect(actor, "sprint_bonus") > 0.0:
		duration += _effect(actor, "sprint_bonus")
		actor.effects["sprint_bonus"] = 0.0
	actor.effects["boost_level"] = level
	actor.effects["speed_boost"] = duration
	_speed(actor, PaperRules.OM_BOOST_FACTOR, duration)
	_reward_escape_boost(actor)
	_set_cd(actor, 1, PaperRules.OM_BOOST_COOLDOWN)
	world.event("boost_release", {"actor": actor.id, "position": actor.position, "duration": duration, "level": level})
	return true

func _tick_charge(actor, delta: float):
	if not bool(actor.effects.get("boost_charging", false)): return
	if _effect(actor, "stun") > 0 or not _can_act(actor): _cancel_charge(actor);return
	actor.effects["boost_charge"] = minf(10.0, _effect(actor, "boost_charge") + delta)
	actor.effects["charging_boost"] = actor.effects.boost_charge
	actor.effects["boost_level"] = 3 if _effect(actor, "boost_charge") >= 3.0 else 2 if _effect(actor, "boost_charge") >= 2.0 else 1 if _effect(actor, "boost_charge") >= 1.0 else 0
	actor.velocity = Vector3.ZERO
	actor.move_input = Vector3.ZERO


	if _effect(actor, "boost_charge") >= 10.0: release_charge(actor)

func carry_survivor(actor, target_id: int = -1) -> bool:
	if not _can_act(actor) or actor.character != "Simon" or _effect(actor, "speed_boost") <= 0 or int(actor.effects.get("carrying_id", -1)) >= 0: return false
	var target = _ally(actor, target_id, 2.0, false)
	if target == null or target.character == "Lysia" or int(target.effects.get("carried_by", -1)) >= 0 or _effect(target, "overheat_time") > 0: return false
	_cancel_charge(target);_cancel_channel(target)
	actor.effects["carrying_id"] = target.id
	actor.effects["carry_speed_factor"] = 0.85 if target.character == "Usayuko" else 1.0
	target.effects["carried_by"] = actor.id
	world.event("carry", {"actor": actor.id, "target": target.id, "active": true, "position": actor.position})
	var enemy = world.killer_actor()
	if _can_act(enemy) and actor.position.distance_to(enemy.position) <= 18.0 and _los(actor.position, enemy.position): _reward("protection", actor, 1.0, "carry_%d" % target.id)
	return true

func _release_carry(actor):
	if actor == null: return
	var carrier = actor
	if int(actor.effects.get("carried_by", -1)) >= 0: carrier = _actor(int(actor.effects.carried_by))
	if carrier == null: actor.effects["carried_by"] = -1;return
	var target = _actor(int(carrier.effects.get("carrying_id", -1)))
	carrier.effects["carrying_id"] = -1;carrier.effects["carry_speed_factor"] = 1.0
	if target != null:
		target.effects["carried_by"] = -1
		world.event("carry", {"actor": carrier.id, "target": target.id, "active": false, "position": target.position})

func _tick_carries(delta: float):
	for actor in world.actors.values():
		if int(actor.effects.get("carrying_id", -1)) < 0: continue
		var target = _actor(int(actor.effects.carrying_id))
		if not _can_act(actor) or not _can_act(target) or _effect(actor, "speed_boost") <= 0 or _effect(actor, "stun") > 0: _release_carry(actor);continue
		var desired: Vector3 = actor.position - _aim(actor) * 0.6 + Vector3.UP * 0.25
		var offset: Vector3 = desired - target.position
		if offset.length() > 5.0 or not _los(target.position, actor.position): _release_carry(actor);continue
		var previous: Vector3 = target.position
		target.move_and_collide(offset.limit_length(30.0 * delta))
		target.velocity = (target.position - previous) / maxf(delta, 0.001)
		_mark_motion(target)

func outlet_preview(actor) -> Dictionary:
	var result: Dictionary = {"ready": false, "index": -1, "position": Vector3.ZERO, "remaining": 0.0}
	if actor == null or actor.character != "Lysia" or world.school == null: return result
	var points: Variant = world.school.get("healing_outlets")
	if not points is Array: return result
	var nearest: float = 2.0
	for index in points.size():
		var point: Vector3 = points[index]
		var distance: float = actor.position.distance_to(point)
		if distance < nearest and _los(actor.position, point):
			nearest = distance;result.index = index;result.position = point
	result.ready = int(result.index) >= 0 and float(actor.cooldowns.get(3, 0)) <= 0 and actor.hp < PaperSurvivorMechanics.heal_ceiling(actor)
	result.remaining = float(actor.cooldowns.get(3, 0))
	return result

func start_outlet_heal(actor) -> bool:
	if not _can_act(actor) or actor.character != "Lysia" or str(world.phase) != "playing" or _effect(actor, "outlet_healing") > 0: return false
	for key in ["stun", "root", "forced_time", "overheat_time", "overheat_charge"]:
		if _effect(actor, key) > 0: return false

	if not actor.is_on_floor(): return false
	var preview: Dictionary = outlet_preview(actor)
	if not bool(preview.ready): return false
	var now: float = float(world.clock)
	actor.effects["outlet_index"] = int(preview.index)
	actor.effects["outlet_position"] = Vector3(preview.position) + (Vector3(0, 0.85, -0.8) if str(world.school.get("map_id")) == "school" else Vector3(0, 0.55, -0.66))
	actor.effects["outlet_origin"] = actor.position
	actor.effects["outlet_healing"] = OUTLET_DURATION
	actor.effects["outlet_pulse"] = 0.0
	actor.effects["outlet_healed"] = 0.0
	actor.effects["outlet_started"] = now
	actor.effects["outlet_press_at"] = now

	actor.effects["outlet_move_armed"] = false
	actor.velocity = Vector3.ZERO;actor.move_input = Vector3.ZERO
	world.event("outlet_heal", {"actor": actor.id, "position": preview.position, "duration": OUTLET_DURATION, "active": true})
	return true


func _stop_outlet(actor, reason: String = "interrupted"):
	if actor == null or _effect(actor, "outlet_healing") <= 0: return
	var healed: float = _effect(actor, "outlet_healed")
	actor.effects["outlet_healing"] = 0.0
	actor.effects["outlet_index"] = -1
	actor.effects["outlet_ashura"] = -1


	if healed > 0.0: _set_cd(actor, 3, OUTLET_COOLDOWN)
	else: actor.cooldowns[3] = maxf(float(actor.cooldowns.get(3, 0.0)), OUTLET_EMPTY_LOCKOUT)
	world.event("outlet_heal", {"actor": actor.id, "position": actor.position, "active": false, "reason": reason, "healed": healed})
	if reason == "full": _message(actor, "Armure pleine · prise débranchée" if float(actor.hp) >= float(actor.max_hp) else "LMS · armure au maximum (150) · prise débranchée")

func _tick_outlet(actor, delta: float):
	var left: float = _effect(actor, "outlet_healing")
	if left <= 0: return
	if not _can_act(actor) or _effect(actor, "stun") > 0 or actor.position.distance_to(actor.effects.get("outlet_origin", actor.position)) > 0.5: _stop_outlet(actor);return

	if actor.move_input.length() <= 0.35:
		actor.effects["outlet_move_armed"] = true
	elif bool(actor.effects.get("outlet_move_armed", false)):
		_stop_outlet(actor, "cancelled")
		return
	var step: float = minf(left, delta)
	var partner = PaperSurvivorMechanics.outlet_partner(self, actor)
	var rate: float = PaperSurvivorMechanics.ASHURA_OUTLET_FACTOR if partner != null else 1.0
	actor.effects["outlet_ashura"] = -1 if partner == null else int(partner.id)
	actor.effects["outlet_pulse"] = _effect(actor, "outlet_pulse") + step * rate
	while _effect(actor, "outlet_pulse") >= 2.0:
		actor.effects["outlet_pulse"] = _effect(actor, "outlet_pulse") - 2.0
		var before: float = float(actor.hp)
		_heal(actor, 10.0, actor)
		actor.effects["outlet_healed"] = _effect(actor, "outlet_healed") + float(actor.hp) - before
		if partner != null: _reward("heal", partner, (float(actor.hp) - before) * (1.0 - 1.0 / rate))
	if float(actor.hp) >= PaperSurvivorMechanics.heal_ceiling(actor):
		_stop_outlet(actor, "full")
		return
	if left <= delta: _stop_outlet(actor, "done")
	else: actor.effects["outlet_healing"] = left - delta

func _tick_chocolate(actor, delta: float):
	var left: float = _effect(actor, "chocolate_hot")
	if left <= 0: return
	var step: float = minf(left, delta)
	actor.effects["chocolate_hot"] = maxf(0.0, left - delta)

	var before: float = actor.hp
	actor.hp = minf(actor.max_hp, actor.hp + step * 2.0)
	_reward("heal", actor, actor.hp - before)

func _tick_grinds(delta: float):
	if world.school == null: return
	var rails: Variant = world.school.get("grind_rails")
	if not rails is Array: return
	for actor in world.actors.values():
		if actor.character != "Ashura" or not _can_act(actor): continue
		actor.effects["grinding"] = false
		if ( not actor.sprint and _effect(actor, "speed_boost") <= 0) or _effect(actor, "stun") > 0 or bool(actor.effects.get("boost_charging", false)) or bool(actor.effects.get("jump_pending", false)) or _effect(actor, "grind_jump") > 0: continue
		for rail in rails:
			var start: Vector3 = rail.from; var end: Vector3 = rail.to
			var segment: Vector3 = end - start
			if segment.length_squared() < 0.25: continue
			var t: float = clampf((actor.position - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
			var closest: Vector3 = start + segment * t
			if actor.position.distance_to(closest) > 0.85 or actor.position.y < closest.y - 0.2: continue
			var direction: Vector3 = segment.normalized()
			if direction.dot(_aim(actor)) < 0: direction = - direction
			if (t <= 0.01 and direction.dot(segment) < 0) or (t >= 0.99 and direction.dot(segment) > 0): continue
			var grind_speed: float = PaperRules.OM_SURVIVOR_SPRINT * PaperRules.OM_BOOST_FACTOR if _effect(actor, "speed_boost") > 0 else 13.8
			var goal: Vector3 = closest + direction * grind_speed * delta
			var old: Vector3 = actor.position
			actor.move_and_collide(goal - actor.position)
			actor.velocity = (actor.position - old) / maxf(delta, 0.001)
			actor.effects["grinding"] = true;actor.effects["grind_direction"] = direction
			_mark_motion(actor)
			break
