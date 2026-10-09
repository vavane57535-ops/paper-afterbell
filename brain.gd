class_name PaperBrain
extends RefCounted




const AiNav = preload("res://ai_nav.gd")

const DECISION_MIN: float = 0.22
const DECISION_MAX: float = 0.34
const REPATH_SECONDS: float = 0.7

const SKILL_BACKOFF: float = 2.0

const ALICE_MEMORY: float = 30.0

const PATH_MAX_AGE: float = 2.5

const ANTI_SHADOW: Dictionary = {"Usayuko": [2, 1], "Lysia": [2, 1], "Elly": [1], "Bleuette": [0, 1], "Ashura": [0], "Simon": [0]}

const EYE: Vector3 = Vector3.ZERO

var world
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _nav_helper

func _init(game_world):
	world = game_world
	rng.seed = randi()

func _nav():
	if _nav_helper == null or _nav_helper.school != world.school: _nav_helper = AiNav.new(world.school)
	return _nav_helper

func tick(delta: float) -> void :
	for actor in world.actors.values():
		if not is_instance_valid(actor) or not actor.bot:
			continue
		if actor.alive and actor.ruleset == "om" and bool(actor.effects.get("downed", false)) and world.phase == "playing":
			_crawl_toward_help(actor)
			continue
		if not actor.active() or world.phase != "playing":
			actor.move_input = Vector3.ZERO
			actor.sprint = false
			continue
		if bool(actor.effects.get("drone_piloting", false)):
			var drone: Dictionary = world.combat.piloted_drone(actor)
			var enemy = world.killer_actor()
			if enemy != null and not drone.is_empty() and world.visible(actor.position, enemy.position):
				world.combat.drone_input(actor, (enemy.position + Vector3.UP * 1.15 - Vector3(drone.position)).normalized())
			continue
		var state: Dictionary = actor.bot_state
		if bool(actor.effects.get("boost_charging", false)):
			actor.move_input = Vector3.ZERO
			_tick_charge(actor, state)
			continue
		if not state.get("brain_ready", false):
			_start(actor, state)
		_tick_archive_input(actor, state)
		if str(state.get("mode", "")) == "revive" and int(actor.effects.get("revive_target", -1)) >= 0:
			actor.move_input = Vector3.ZERO
			world.combat.interact(actor)
		_tick_archive_hold(actor, state)
		if world.clock >= float(state.get("next_decision", 0.0)):
			_perceive(actor, state)
			if actor.killer:
				_killer_decision(actor, state)
			else:
				_survivor_decision(actor, state)
			state["next_decision"] = world.clock + rng.randf_range(DECISION_MIN, DECISION_MAX)
		_steer(actor, state, delta)

func _start(actor, state: Dictionary) -> void :
	state.merge({
		"brain_ready": true, "mode": "patrol", "memory": {}, "allies": {}, 
		"next_decision": world.clock + rng.randf_range(0.0, 0.3), 
		"path": PackedVector3Array(), "path_index": 0, 
		"next_path": 0.0, "goal": actor.global_position, 
		"path_goal": actor.global_position, "has_goal": false, 
		"objective": -1, "target": -1, "target_since": world.clock, 
		"last_contact": world.clock, "reaction_at": 0.0, 
		"escape_until": 0.0, "last_escape": actor.global_position, 
		"next_interact": 0.0, "next_skill": 0.0, 
		"progress_position": actor.global_position, "progress_at": world.clock, 
		"stuck_for": 0.0, "unstick_until": 0.0, "unstick_direction": Vector3.ZERO, 
		"resting": false, "face_threat": false, "threat": {}, 
		"patrol_index": posmod(actor.id * 3, maxi(1, world.school.patrol_points.size())), 
		"bad_goal": Vector3(99999, 0, 99999), "bad_goal_until": 0.0, 
		"skill_backoff": {}, "working": -1, "alice_seen": {}, "bad_objectives": {}, 
	}, true)



func _tick_charge(actor, state: Dictionary) -> void :
	var charge: float = float(actor.effects.get("boost_charge", 0.0))
	if charge >= float(state.get("boost_release_at", 1.15)):
		world.combat.release_charge(actor)
		return
	if world.clock < float(state.get("charge_check_at", 0.0)):
		return
	state["charge_check_at"] = world.clock + 0.2
	var enemy = world.killer_actor()
	if enemy == null or not enemy.active():
		return
	var distance: float = _reachable_distance(actor, enemy.global_position)
	if distance < 8.0 and _can_see(actor, enemy.global_position, distance):
		world.combat.release_charge(actor)


func _tick_archive_hold(actor, state: Dictionary) -> void :
	var index: int = int(state.get("working", -1))
	if index < 0:
		return
	if str(state.get("mode", "")) != "objective" or index >= world.school.objectives.size() or index in world.objective_done or _reachable_distance(actor, world.school.objectives[index]) > 2.75:
		state["working"] = -1
		return
	actor.move_input = Vector3.ZERO
	if world.clock >= float(state.get("next_interact", 0.0)):
		world.combat.interact(actor)
		state["next_interact"] = world.clock + 0.2

func _perceive(actor, state: Dictionary) -> void :
	var memory: Dictionary = state.get("memory", {})
	var allies: Dictionary = state.get("allies", {})
	var now: float = world.clock
	for key in memory.keys():
		var contact: Dictionary = memory[key]
		contact["visible"] = false
		contact["revealed"] = false
		var known_actor = world.actors.get(int(key))
		if known_actor == null or not known_actor.active() or now - float(contact.get("stamp", -99.0)) > (9.0 if actor.killer else 8.0):
			memory.erase(key)
	for key in allies.keys():
		allies[key]["visible"] = false
		if now - float(allies[key].get("stamp", -99.0)) > 6.0:
			allies.erase(key)
	var most_hurt_id: int = -1
	var most_hurt_ratio: float = 1.0
	if not actor.killer and actor.character == "Usayuko":

		for friend in world.actors.values():
			if friend.alive and not friend.killer and friend.id != actor.id:
				var ratio: float = friend.hp / maxf(friend.max_hp, 1.0)
				if ratio < most_hurt_ratio:
					most_hurt_ratio = ratio
					most_hurt_id = friend.id
	for other in world.actors.values():
		if not is_instance_valid(other) or other.id == actor.id or not other.alive:
			continue
		if bool(other.effects.get("shadow_hide", false)): continue
		var distance: float = _reachable_distance(actor, other.global_position)
		if other.killer == actor.killer:
			if actor.killer:
				continue
			var help_aura: bool = float(other.effects.get("help_aura", 0.0)) > 0.0

			var ally_sight: bool = _can_see(actor, other.global_position, distance)
			if ally_sight or help_aura or other.id == most_hurt_id:
				allies[other.id] = {
					"id": other.id, "position": other.global_position, 
					"hp": other.hp, "max_hp": other.max_hp, 
					"character": other.character, "stamp": now, "visible": ally_sight, 
					"help_aura": help_aura, 
					"downed": bool(other.effects.get("downed", false)), 
				}
			continue
		if not other.active(): continue
		var sight: bool = _can_see(actor, other.global_position, distance)
		var revealed: bool = false
		if actor.killer:
			revealed = (float(actor.effects.get("reveal", 0.0)) > 0.0 and other.character != "Simon") or float(other.effects.get("archive_alarm", 0.0)) > 0.0 or float(other.effects.get("lms_reveal", 0.0)) > 0.0
		else:
			revealed = float(actor.effects.get("xray", 0.0)) > 0.0
		var speed: float = Vector2(other.velocity.x, other.velocity.z).length()
		if actor.character == "Elly" and other.killer:


			state["remote_killer_activity"] = "running" if speed > 4.7 else ("walking" if speed > 0.8 else "quiet")
			var previous_cues: Dictionary = state.get("remote_sound_cooldowns", {})
			for slot in other.cooldowns:
				var cooldown: float = float(other.cooldowns[slot])
				if cooldown > float(previous_cues.get(slot, cooldown)) + 1.0:
					state["remote_ability_heard_at"] = now
				previous_cues[slot] = cooldown
			state["remote_sound_cooldowns"] = previous_cues
		var hearing_radius: float = 12.0 if speed > 4.7 else 5.0
		var hearing: bool = speed > 0.8 and distance <= hearing_radius and (other.ruleset != "om" or other.is_on_floor())
		if sight or revealed:
			var first: bool = not memory.has(other.id)
			var old: Dictionary = memory.get(other.id, {})
			var reaction: float = now + rng.randf_range(0.24, 0.48) if first else float(old.get("reaction_at", now))
			memory[other.id] = {
				"id": other.id, "position": other.global_position, 
				"velocity": other.velocity if sight else Vector3.ZERO, 
				"aim": other.aim if sight else Vector3.ZERO, 
				"hp": other.hp if sight else float(old.get("hp", 100.0)), 
				"stunned": float(other.effects.get("stun", 0.0)) if sight else 0.0, 
				"stun_immunity": float(other.effects.get("stun_immunity", 0.0)) if sight else 0.0, 

				"revived": bool(other.effects.get("revived", false)) if sight else bool(old.get("revived", false)), 
				"invulnerable": float(other.effects.get("revive_invuln", 0.0)) if sight else 0.0, 
				"stamp": now, "visible": sight, "revealed": revealed, 
				"reaction_at": reaction, "source": "sight" if sight else "ability", 
			}
			state["last_contact"] = now
		elif hearing:
			var old: Dictionary = memory.get(other.id, {})

			if now - float(old.get("stamp", -99.0)) > 0.8:
				var heard_position: Vector3 = other.global_position
				heard_position.x = snappedf(heard_position.x, 3.0) + rng.randf_range(-0.7, 0.7)
				heard_position.z = snappedf(heard_position.z, 3.0) + rng.randf_range(-0.7, 0.7)
				memory[other.id] = {
					"id": other.id, "position": heard_position, "velocity": Vector3.ZERO, 
					"aim": Vector3.ZERO, "hp": float(old.get("hp", 100.0)), 
					"revived": bool(old.get("revived", false)), 
					"stamp": now, "visible": false, "revealed": false, 
					"reaction_at": float(old.get("reaction_at", now + 0.45)), "source": "sound", 
				}
				state["last_contact"] = now


	if not actor.killer:
		for contact in allies.values():
			if not contact.get("visible", false) or _reachable_distance(actor, contact["position"]) > 9.0:
				continue
			var friend = world.actors.get(int(contact["id"]))
			if friend == null or not friend.bot:
				continue
			var friend_memory: Dictionary = friend.bot_state.get("memory", {})
			for enemy_id in friend_memory:
				var report: Dictionary = friend_memory[enemy_id]
				if report.get("source", "") != "sight" or now - float(report.get("stamp", -99.0)) > 1.2:
					continue
				var own_report: Dictionary = memory.get(enemy_id, {})
				if float(report["stamp"]) > float(own_report.get("stamp", -99.0)) + 0.4:
					var copied: Dictionary = report.duplicate()
					copied["visible"] = false
					copied["revealed"] = false
					copied["source"] = "team"
					copied["reaction_at"] = now + 0.35
					memory[enemy_id] = copied

		var killer = world.killer_actor()
		if killer != null and memory.has(killer.id):
			var sighting: Dictionary = memory[killer.id]
			if float(sighting.get("stamp", -99.0)) > float(state.get("alice_seen", {}).get("stamp", -99.0)):
				state["alice_seen"] = {"position": sighting["position"], "stamp": sighting["stamp"]}
	state["memory"] = memory
	state["allies"] = allies

func _can_see(actor, position: Vector3, distance: float) -> bool:
	if float(actor.effects.get("blind", 0.0)) > 0.0 or distance > 31.0:
		return false
	var direction: Vector3 = _flat_direction(actor.global_position, position)
	if distance > 5.0 and actor.aim.dot(direction) < -0.35:
		return false
	return world.visible(actor.global_position + EYE, position + EYE)



func _killer_decision(actor, state: Dictionary) -> void :
	var exits = world.get("exit_flow")
	var exit_open: bool = exits != null and exits.has_method("is_open") and exits.is_open()
	var best: Dictionary = {}
	var best_score: float = - INF
	var current_id: int = int(state.get("target", -1))
	for contact in state.get("memory", {}).values():
		var age: float = world.clock - float(contact["stamp"])
		var distance: float = _reachable_distance(actor, contact["position"])
		var score: float = 38.0 - distance - age * 3.0
		var seen_contact: bool = contact.get("visible", false)
		score += 8.0 if seen_contact else 0.0
		score += 5.0 if int(contact["id"]) == current_id else 0.0
		if seen_contact:
			score += clampf((100.0 - float(contact.get("hp", 100.0))) * 0.08, 0.0, 6.0)

			if bool(contact.get("revived", false)): score += 6.0

			if float(contact.get("invulnerable", 0.0)) > 0.0: score -= 10.0
		if int(contact["id"]) == current_id and world.clock - float(state["target_since"]) > 18.0 and distance > 11.0:
			score -= 10.0
		if score > best_score:
			best = contact
			best_score = score
	state["threat"] = best
	state["face_threat"] = not best.is_empty() and best.get("visible", false)
	_note_down(state, current_id)
	_consider_true_form(actor, state, exit_open)
	if best.is_empty():
		if bool(actor.effects.get("spike_aiming", false)): world.combat.cancel_aim(actor)
		state["target"] = -1
		var quiet: float = world.clock - float(state["last_contact"])
		if quiet > 4.0 and _ready(actor, 1):
			_try_skill(actor, state, 1)
		elif quiet > 6.0 and not exit_open and float(actor.effects.get("phase6", 0)) <= 0 and _ready(actor, 3):

			_try_skill(actor, state, 3)
		if exit_open:
			state["mode"] = "guard"
			_guard_exit(actor, state)
		elif _linger_near_down(actor, state):
			state["mode"] = "guard"
		elif _hunt_archives(actor, state):
			state["mode"] = "patrol"
		else:
			state["mode"] = "patrol"
			_patrol(actor, state)
		return
	if int(best["id"]) != current_id:
		state["target"] = int(best["id"])
		state["target_since"] = world.clock
	var goal: Vector3 = best["position"]
	var distance: float = _reachable_distance(actor, goal)
	var seen: bool = best.get("visible", false)
	state["mode"] = "chase" if seen or best.get("revealed", false) else "search"
	if seen and distance > 3.0:

		var lead: Vector3 = goal + Vector3(best["velocity"].x, 0, best["velocity"].z) * clampf(distance / 13.0, 0.15, 0.8)
		if world.school.can_walk(lead):
			goal = lead
	elif not seen and str(best.get("source", "")) != "sound":

		var ahead: Vector3 = _predict(best, clampf(world.clock - float(best["stamp"]), 0.0, 1.5))
		if ahead.distance_to(goal) > 1.0 and world.school.can_walk(ahead):
			goal = ahead
			distance = _reachable_distance(actor, goal)
	if not seen and distance < 2.0:
		state["memory"].erase(int(best["id"]))
		state["has_goal"] = false
		if exit_open: _guard_exit(actor, state)
		elif not _hunt_archives(actor, state): _patrol(actor, state)
		return
	_set_goal(state, goal)
	if not seen and distance > 14.0 and world.clock - float(best["stamp"]) > 2.0 and not exit_open and float(actor.effects.get("phase6", 0)) <= 0 and _ready(actor, 3):

		_try_skill(actor, state, 3)
	if world.clock < float(best.get("reaction_at", 0.0)) or not seen:
		return
	actor.aim = _flat_direction(actor.global_position, best["position"])
	var seen_actor = world.actors.get(int(best.id))
	if distance < 6.0 and actor.is_on_floor() and float(actor.effects.get("jump_cd", 0)) <= 0:


		if seen_actor != null and (float(seen_actor.effects.get("block", 0)) > 0 or float(seen_actor.effects.get("grab_time", 0)) > 0 or best.position.y - actor.position.y > 0.7): actor.request_jump()
	if bool(actor.effects.get("spike_aiming", false)):
		if world.clock - float(state.get("spike_armed_at", world.clock)) >= 0.32:

			var aim_point: Vector3 = _predict(best, 0.12 + distance / 30.0)
			if _reachable_distance(actor, aim_point) <= 14.6 and world.visible(actor.global_position, aim_point):
				actor.aim = _flat_direction(actor.global_position, aim_point)
			world.combat.use(actor, 2)
		return
	if distance <= 3.3:


		if _hittable(seen_actor):
			_try_skill(actor, state, 0, int(best["id"]))
	elif float(actor.effects.get("phase6", 0)) > 0 and distance >= 4.0 and distance <= 14.5 and _ready(actor, 3):

		var pounce_point: Vector3 = _predict(best, clampf(distance / 21.7, 0.15, 0.6))
		if world.visible(actor.global_position, pounce_point): actor.aim = _flat_direction(actor.global_position, pounce_point)
		_try_skill(actor, state, 3, int(best["id"]))
	elif distance >= 5.0 and distance <= 24.0 and _ready(actor, 4):
		_try_skill(actor, state, 4, int(best["id"]))
	elif distance >= 4.0 and distance <= 14.2 and world.visible(actor.global_position + EYE, best["position"] + EYE):
		var spike_aim: Vector3 = _predict(best, 0.12 + distance / 30.0)
		if _reachable_distance(actor, spike_aim) <= 14.6 and world.visible(actor.global_position, spike_aim):
			actor.aim = _flat_direction(actor.global_position, spike_aim)
		if _try_skill(actor, state, 2, int(best["id"])): state["spike_armed_at"] = world.clock



func _consider_true_form(actor, state: Dictionary, exit_open: bool) -> void :
	if float(actor.effects.get("rage", 0)) < 100 or float(actor.effects.get("phase6", 0)) > 0 or bool(actor.effects.get("true_form_used", false)) or float(actor.effects.get("stun", 0)) > 0:
		return
	var worth: bool = exit_open or float(world.time_left) < 90.0
	if not worth:
		var close: int = 0
		for contact in state.get("memory", {}).values():
			if contact.get("visible", false) and _reachable_distance(actor, contact["position"]) < 15.0: close += 1
		worth = close >= 2
	if worth: world.combat.use(actor, 5)

func _hittable(target) -> bool:
	if target == null: return true
	for key in ["block", "overheat_time", "overheat_charge", "revive_invuln", "recover"]:
		if float(target.effects.get(key, 0.0)) > 0.0: return false
	return true


func _guard_exit(actor, state: Dictionary) -> void :
	if state.get("has_goal", false) and _reachable_distance(actor, state["goal"]) > 2.0 and world.clock < float(state.get("guard_until", 0.0)):
		return
	state["guard_until"] = world.clock + rng.randf_range(3.0, 5.0)
	var exit_point: Vector3 = world.school.escape_position
	var spots: PackedVector3Array = _nav().ring(exit_point, 2.0, 12.0, 2.5, 4, rng)
	_set_goal(state, spots[rng.randi_range(0, spots.size() - 1)] if not spots.is_empty() else exit_point)


func _note_down(state: Dictionary, target_id: int) -> void :
	if target_id < 0: return
	var victim = world.actors.get(target_id)
	if victim == null or not bool(victim.effects.get("downed", false)): return
	if int(state.get("last_down", {}).get("id", -1)) == target_id: return
	state["last_down"] = {"id": target_id, "position": victim.global_position, "stamp": world.clock}


func _linger_near_down(actor, state: Dictionary) -> bool:
	var down: Dictionary = state.get("last_down", {})
	if down.is_empty() or world.clock - float(down["stamp"]) > 6.0: return false
	var victim = world.actors.get(int(down["id"]))
	if victim == null or not bool(victim.effects.get("downed", false)): return false
	if state.get("has_goal", false) and _reachable_distance(actor, state["goal"]) > 1.5 and world.clock < float(state.get("linger_until", 0.0)):
		return true
	state["linger_until"] = world.clock + 2.0
	var spots: PackedVector3Array = _nav().ring(down["position"], 3.0, 7.0, 2.0, 2, rng)
	_set_goal(state, spots[0] if not spots.is_empty() else Vector3(down["position"]))
	return true



func _hunt_archives(actor, state: Dictionary) -> bool:
	var visited: Dictionary = state.get("archive_visited", {})
	var current: int = int(state.get("hunt_index", -1))
	if current >= 0 and current < world.school.objectives.size() and not (current in world.objective_done) and world.clock >= float(visited.get(current, 0.0)):
		var point: Vector3 = world.school.objectives[current]
		var unreachable: bool = world.clock < float(state.get("bad_goal_until", 0.0)) and point.distance_to(state["bad_goal"]) < 3.0
		if not unreachable and _reachable_distance(actor, point) > 3.5:
			if not state.get("has_goal", false) or Vector3(state["goal"]).distance_to(point) > 1.0: _set_goal(state, point)
			return true
		visited[current] = world.clock + 20.0
	var best: int = -1
	var best_score: float = INF
	for index in range(world.school.objectives.size()):
		if index in world.objective_done or world.clock < float(visited.get(index, 0.0)): continue
		var score: float = _reachable_distance(actor, world.school.objectives[index]) + rng.randf_range(0.0, 12.0)
		if score < best_score:
			best = index
			best_score = score
	state["archive_visited"] = visited
	state["hunt_index"] = best
	if best < 0: return false
	_set_goal(state, world.school.objectives[best])
	return true



func _survivor_decision(actor, state: Dictionary) -> void :
	var exits = world.get("exit_flow")
	var threat: Dictionary = {}
	var best_danger: float = - INF
	for contact in state.get("memory", {}).values():
		var age: float = world.clock - float(contact["stamp"])
		var distance: float = _reachable_distance(actor, contact["position"])
		var danger: float = 25.0 - distance - age * 2.5
		if contact.get("visible", false):
			danger += 4.0
		if danger > best_danger:
			best_danger = danger
			threat = contact
	for shadow: Dictionary in world.minions:
		var shadow_distance: float = _reachable_distance(actor, shadow.position)
		if shadow_distance < 12.0 and _can_see(actor, shadow.position, shadow_distance):
			if shadow_distance < 3.3:
				var defensive: int = _anti_shadow_slot(actor, state)
				if defensive >= 0:
					actor.aim = _flat_direction(actor.global_position, shadow.position)
					_try_skill(actor, state, defensive)
			if threat.is_empty() or shadow_distance < _reachable_distance(actor, threat.position):
				threat = {"id": -1, "position": shadow.position, "stamp": world.clock, "visible": false, "velocity": Vector3.ZERO}
	if float(actor.effects.get("shadow_mark", 0)) > 0:


		var warning: Dictionary = {"id": -1, "position": actor.global_position - actor.aim * 2.0, "stamp": world.clock, "visible": false, "velocity": Vector3.ZERO}
		threat = warning
		if not bool(state.get("shadow_warned", false)):
			state["escape_until"] = 0.0;state["next_path"] = 0.0
		state["shadow_warned"] = true
	else: state["shadow_warned"] = false
	state["threat"] = threat
	state["face_threat"] = false
	var danger_distance: float = INF if threat.is_empty() else _reachable_distance(actor, threat["position"])
	var danger_age: float = INF if threat.is_empty() else world.clock - float(threat["stamp"])
	var urgent: bool = not threat.is_empty() and danger_distance < 18.0 and danger_age < 4.5
	var threat_seen: bool = not threat.is_empty() and threat.get("visible", false)
	if float(actor.effects.get("outlet_healing", 0)) > 0:

		if threat_seen and danger_distance < 12.0:
			world.combat.use(actor, 3)
		else:
			state["mode"] = "heal"
			state["has_goal"] = false
			return
	if actor.character == "Bleuette" and actor.hp <= actor.max_hp - 20 and int(actor.effects.get("chocolate_uses", 0)) < 2 and _ready(actor, 2): _try_skill(actor, state, 2)
	if threat_seen and world.clock >= float(threat.get("reaction_at", 0.0)):
		_survivor_defence(actor, state, threat, danger_distance)
	if actor.character == "Lysia" and threat.is_empty() and world.clock - float(state["last_contact"]) > 6.0:
		_try_skill(actor, state, 2)
	if actor.character == "Bleuette" and (actor.lms or world.lms) and not actor.effects.get("aura_used", false):
		_try_skill(actor, state, 3)
	if exits != null and exits.has_method("is_open") and exits.is_open():

		if not (threat_seen and danger_distance < 14.0) and _rescue(actor, state, danger_distance, 12.0):
			return
		state["mode"] = "escape";state["objective"] = -1
		_set_goal(state, world.school.escape_position)
		return
	if urgent:
		state["objective"] = -1
		state["mode"] = "flee"
		if _protect_ally(actor, state, threat, danger_distance):
			return

		if actor.character in ["Simon", "Ashura"] and not threat_seen and _boost_window(threat, danger_distance) and _try_skill(actor, state, 1):
			return
		_choose_escape(actor, state, threat)
		return
	if _rescue(actor, state, danger_distance): return
	if _support(actor, state, danger_distance):
		return
	if actor.lms or world.lms:
		_hide(actor, state)
		return
	state["mode"] = "objective"
	_work_objective(actor, state)

func _anti_shadow_slot(actor, state: Dictionary) -> int:
	for slot in ANTI_SHADOW.get(str(actor.character), []):
		if actor.character == "Ashura" and bool(actor.effects.get("drone_active", false)): continue

		if actor.character == "Simon" and not bool(actor.effects.get("flash_melee", false)): continue
		if _ready(actor, int(slot)) and not _backing_off(state, int(slot)): return int(slot)
	return -1


func _boost_window(threat: Dictionary, distance: float) -> bool:
	if threat.is_empty() or int(threat.get("id", -1)) < 0: return false
	if float(threat.get("stunned", 0.0)) > 1.4 and distance > 3.5: return true
	if not bool(threat.get("visible", false)): return distance > 9.0 and distance < 26.0
	return distance > 16.0 and distance < 30.0


func _charge_target(actor, state: Dictionary) -> float:
	var threat: Dictionary = state.get("threat", {})
	if threat.is_empty() or int(threat.get("id", -1)) < 0: return 3.1
	if float(threat.get("stunned", 0.0)) > 2.4: return 2.1
	if not bool(threat.get("visible", false)) and _reachable_distance(actor, threat["position"]) > 18.0: return 2.1
	return 1.15

func _survivor_defence(actor, state: Dictionary, threat: Dictionary, distance: float) -> void :
	if actor.character in ["Simon", "Ashura"] and _boost_window(threat, distance) and float(actor.effects.get("boost_time", 0)) <= 0 and float(actor.effects.get("speed_boost", 0)) <= 0:
		if _try_skill(actor, state, 1): return
	var enemy_id: int = int(threat["id"])
	var old_aim: Vector3 = actor.aim
	var stunned: float = float(threat.get("stunned", 0.0))
	if stunned > 0.7 or float(threat.get("stun_immunity", 0)) > 0:

		if actor.character == "Lysia" and stunned <= 0.7 and distance < 2.7 and _ready(actor, 1):
			actor.aim = _flat_direction(actor.global_position, threat["position"])
			if not _try_skill(actor, state, 1, enemy_id): actor.aim = old_aim
		return
	actor.aim = _flat_direction(actor.global_position, threat["position"])
	state["face_threat"] = distance < 8.0
	match actor.character:
		"Usayuko":
			_usayuko_defence(actor, state, threat, distance)
		"Simon":
			_simon_defence(actor, state, threat, distance)
		"Lysia":


			if distance < 2.7 and _ready(actor, 1) and ( not _ready(actor, 0) or actor.hp < actor.max_hp * 0.55):
				_try_skill(actor, state, 1, enemy_id)
			elif distance < 9.0 and _ready(actor, 0):
				actor.aim = _flat_direction(actor.global_position, _predict(threat, distance / 15.0))
				_try_skill(actor, state, 0, enemy_id)
		"Ashura":
			if distance < 24.0 and not bool(actor.effects.get("drone_active", false)):
				_try_skill(actor, state, 0, enemy_id)
		"Elly":
			if (actor.lms or world.lms) and distance < 12.0:
				_try_skill(actor, state, 3, enemy_id)
		"Bleuette":
			for ally in state.get("allies", {}).values():
				if not ally.get("visible", false):
					continue
				if _reachable_distance(actor, ally["position"]) < 5.5 and _flat_distance(ally["position"], threat["position"]) < 11.0:
					var friend = world.actors.get(int(ally["id"]))
					if friend != null and _has_spent_skill(friend) and world.combat.support_eligible(actor, 1, friend):
						if _try_skill(actor, state, 1, int(ally["id"])):
							break
	if not state.get("face_threat", false):
		actor.aim = old_aim

func _usayuko_defence(actor, state: Dictionary, threat: Dictionary, distance: float) -> void :
	var enemy_id: int = int(threat["id"])
	var lms: bool = actor.lms or world.lms
	if float(actor.effects.get("counter", 0.0)) > 0.0:
		world.combat.use(actor, 1, enemy_id)
		return
	if distance < 3.1:
		if _try_skill(actor, state, 2, enemy_id): return
	if distance < 3.4 and _ready(actor, 1) and _claw_incoming(actor, threat):

		_try_skill(actor, state, 1, enemy_id)
		return
	if distance < 3.1:
		var wall_behind: bool = not world.visible(threat["position"] + EYE, threat["position"] + actor.aim * 14.0 + EYE)
		if wall_behind and _try_skill(actor, state, 0, enemy_id): return
		if lms: _try_skill(actor, state, 3, enemy_id)
		return
	if distance < 8.0 and _ready(actor, 0) and not _backing_off(state, 0):

		var approaching: bool = Vector3(threat.get("velocity", Vector3.ZERO)).dot(_flat_direction(threat["position"], actor.global_position)) > 2.0
		var wall_ahead: bool = not world.visible(threat["position"] + EYE, threat["position"] + actor.aim * 14.0 + EYE)
		if approaching or wall_ahead:
			actor.aim = _flat_direction(actor.global_position, _predict(threat, distance / 13.5))
			if _try_skill(actor, state, 0, enemy_id): return
			actor.aim = _flat_direction(actor.global_position, threat["position"])
	if lms and distance < 2.9:
		_try_skill(actor, state, 3, enemy_id)

func _claw_incoming(actor, threat: Dictionary) -> bool:
	var alice_aim: Vector3 = threat.get("aim", Vector3.ZERO)
	if alice_aim.length_squared() < 0.01: return true
	if alice_aim.dot(_flat_direction(threat["position"], actor.global_position)) > 0.55: return true
	for ally in actor.bot_state.get("allies", {}).values():
		if bool(ally.get("downed", false)) or _reachable_distance(actor, ally["position"]) > 1.5: continue
		if alice_aim.dot(_flat_direction(threat["position"], ally["position"])) > 0.55: return true
	return false

func _simon_defence(actor, state: Dictionary, threat: Dictionary, distance: float) -> void :
	var enemy_id: int = int(threat["id"])
	if actor.ruleset == "om" and bool(actor.effects.get("flash_melee", false)) != (distance < 3.0):
		world.combat.use(actor, 2)
	if bool(actor.effects.get("flash_melee", false)):
		if distance < 2.9:
			_try_skill(actor, state, 0, enemy_id)
		return
	if bool(actor.effects.get("grenade_aiming", false)):


		var predicted: Vector3 = _predict(threat, 1.15)
		var reach: float = _flat_distance(actor.global_position, predicted)
		if reach >= 5.0 and reach <= 13.5 and world.visible(actor.global_position, predicted):
			actor.aim = _flat_direction(actor.global_position, predicted)
			state["face_threat"] = true
			world.combat.use(actor, 0, enemy_id)
		elif world.clock - float(state.get("grenade_armed_at", world.clock)) > 2.5:
			world.combat.cancel_aim(actor)
		return
	if distance < 14.0 and _ready(actor, 0) and _try_skill(actor, state, 0, enemy_id):
		state["grenade_armed_at"] = world.clock

func _protect_ally(actor, state: Dictionary, threat: Dictionary, distance: float) -> bool:
	if actor.character not in ["Usayuko", "Lysia"] or actor.hp < actor.max_hp * 0.32:
		return false
	if not threat.get("visible", false) or distance > 10.0 or float(threat.get("stunned", 0.0)) > 0.7 or float(threat.get("stun_immunity", 0)) > 0:
		return false
	if not _ready(actor, 0) and not _ready(actor, 2 if actor.character == "Usayuko" else 1):
		return false
	for ally in state.get("allies", {}).values():
		if bool(ally.get("downed", false)): continue
		if float(ally["hp"]) >= float(ally["max_hp"]) * 0.6:
			continue
		if _flat_distance(ally["position"], threat["position"]) < 6.0:
			var toward: Vector3 = _flat_direction(threat["position"], actor.global_position)
			var goal: Vector3 = threat["position"] + toward * 1.2
			if actor.character == "Lysia":
				var enemy_aim: Vector3 = threat.get("aim", Vector3.ZERO)
				goal = threat["position"] - enemy_aim * 1.25
			if world.school.can_walk(goal):
				state["mode"] = "protect"
				_set_goal(state, goal)
				return true
	return false

func _support(actor, state: Dictionary, danger_distance: float) -> bool:
	match str(actor.character):
		"Lysia": return _lysia_support(actor, state, danger_distance)
		"Elly": return _elly_support(actor, state, danger_distance)
		"Bleuette": _bleuette_support(actor, state)
	return false

func _lysia_support(actor, state: Dictionary, danger_distance: float) -> bool:

	if actor.hp < actor.max_hp * 0.72 and danger_distance > 14.0 and _ready(actor, 3) and world.clock >= float(state.get("outlet_retry_at", 0.0)):
		var outlets: Variant = world.school.get("healing_outlets")
		if outlets is Array:
			var closest: Vector3 = Vector3.INF
			var distance: float = 24.0
			for point in outlets:
				var current: float = actor.position.distance_to(point)
				if current < distance and not _near_last_alice(state, point, 14.0): closest = point;distance = current
			if closest.is_finite():
				state["mode"] = "heal";state["objective"] = -1
				if distance < 1.9:
					state["has_goal"] = false
					if not world.combat.start_outlet_heal(actor):

						state["outlet_retry_at"] = world.clock + 4.0
				else: _set_goal(state, closest)
				return true
	if actor.hp < actor.max_hp - 7.0:
		for drone in world.drones:
			if str(drone.state) != "salvage" or float(drone.ttl) < 2.0: continue
			if actor.position.distance_to(drone.position) < 8.0 and world.visible(actor.position, drone.position):
				state["mode"] = "salvage"
				state["objective"] = -1
				if actor.position.distance_to(drone.position) <= 2.6:
					state["has_goal"] = false
					actor.move_input = Vector3.ZERO
					world.combat.interact(actor)
				else: _set_goal(state, drone.position)
				return true
	return false

func _elly_support(actor, state: Dictionary, danger_distance: float) -> bool:
	if float(actor.effects.get("heal_time", 0.0)) > 0.0:
		state["mode"] = "heal"
		state["has_goal"] = false
		return true
	var injured_count: int = 1 if actor.hp < actor.max_hp - 15.0 else 0
	var best: Dictionary = {}
	var priority: float = 0.0
	for ally in state.get("allies", {}).values():
		if str(ally.get("character", "")) == "Lysia": continue
		if not ally.get("visible", false):
			continue
		if bool(ally.get("downed", false)): continue
		var distance: float = _reachable_distance(actor, ally["position"])
		var missing: float = float(ally["max_hp"]) - float(ally["hp"])
		if distance < 5.0 and missing > 15.0:
			injured_count += 1
		var score: float = missing - distance * 1.2
		if missing >= 30.0 and distance < 17.0 and score > priority:
			best = ally
			priority = score
	if danger_distance > 10.0 and (injured_count >= 2 or actor.hp < actor.max_hp * 0.65):
		_try_skill(actor, state, 1)
	if not best.is_empty() and danger_distance > 14.0 and _ready(actor, 0) and not _backing_off(state, 0):
		state["mode"] = "heal"
		state["objective"] = -1
		if _reachable_distance(actor, best["position"]) <= 4.8 and actor.is_on_floor():
			state["has_goal"] = false
			_try_skill(actor, state, 0, int(best["id"]))
		else:
			_set_goal(state, best["position"])
		return true
	return false

func _bleuette_support(actor, state: Dictionary) -> void :
	if not _ready(actor, 0) or _backing_off(state, 0):
		return
	for ally in state.get("allies", {}).values():
		if not ally.get("visible", false) or _reachable_distance(actor, ally["position"]) > 5.5:
			continue
		var friend = world.actors.get(int(ally["id"]))

		if friend == null or not world.combat.support_eligible(actor, 0, friend):
			continue
		if _try_skill(actor, state, 0, int(ally["id"])):
			break

func _near_last_alice(state: Dictionary, point: Vector3, radius: float) -> bool:
	var seen: Dictionary = state.get("alice_seen", {})
	if seen.is_empty() or world.clock - float(seen.get("stamp", -99.0)) > 12.0: return false
	return _flat_distance(seen["position"], point) < radius

func _work_objective(actor, state: Dictionary) -> void :
	var objective: int = int(state.get("objective", -1))
	if objective < 0 or objective >= world.school.objectives.size() or objective in world.objective_done:
		objective = _pick_objective(actor, state)
		state["objective"] = objective
	if objective < 0:
		state["mode"] = "patrol"
		state["working"] = -1
		_patrol(actor, state)
		return
	var position: Vector3 = world.school.objectives[objective]
	_set_goal(state, position)

	if _reachable_distance(actor, position) <= 2.6 and world.visible(actor.global_position + EYE, position + EYE):
		state["has_goal"] = false
		actor.move_input = Vector3.ZERO

		state["working"] = objective
	else:
		state["working"] = -1

func _tick_archive_input(actor, state: Dictionary) -> void :
	var challenge_id: int = int(actor.effects.get("archive_qte_id", 0))
	if challenge_id <= 0: return
	if int(state.get("archive_qte_seen", 0)) != challenge_id:
		state["archive_qte_seen"] = challenge_id
		state["archive_answer_at"] = world.clock + rng.randf_range(0.42, 1.05)
		state["archive_answered"] = false
	if bool(state.get("archive_answered", false)) or world.clock < float(state.get("archive_answer_at", INF)): return
	state["archive_answered"] = true


	var key_index: int = int(actor.effects.get("archive_qte_key", 0))
	if rng.randf() < 0.07: key_index = (key_index + 1) % 3
	world.combat.archive_qte(actor, challenge_id, ["J", "K", "L"][key_index])

func _rescue(actor, state: Dictionary, danger_distance: float, max_distance: float = INF) -> bool:
	if danger_distance < 8.0: return false
	var target = null
	var best: float = INF
	for contact in state.get("allies", {}).values():
		if not bool(contact.get("downed", false)): continue
		var candidate = world.actors.get(int(contact.id))
		if candidate == null or not candidate.alive or not bool(candidate.effects.get("downed", false)): continue
		if actor.ruleset == "om" and _rescue_waiting_for_route(state, int(contact.id), contact.position): continue
		var reserved: int = int(candidate.effects.get("revive_helper", -1))
		if reserved >= 0 and reserved != actor.id: continue
		var distance: float = _reachable_distance(actor, contact.position)
		if distance > max_distance: continue


		if distance / (10.2 if actor.ruleset == "om" else 6.5) + (0.3 if actor.ruleset == "om" else 4.5) > float(candidate.effects.get("bleedout", 0.0)): continue
		var score: float = distance + float(candidate.effects.get("bleedout", 30.0)) * 0.1
		if score < best: best = score;target = candidate
	if target == null: return false
	state["mode"] = "revive";state["objective"] = -1
	if actor.ruleset == "om": state["rescue_target"] = target.id
	if _reachable_distance(actor, target.position) <= 2.1 and world.visible(actor.position, target.position):
		state["has_goal"] = false;actor.move_input = Vector3.ZERO;actor.sprint = false
		actor.aim = _flat_direction(actor.position, target.position)
		world.combat.interact(actor)
	else:
		_set_goal(state, target.position)
	return true

func _rescue_waiting_for_route(state: Dictionary, target_id: int, observed_position: Vector3) -> bool:
	var failed: Dictionary = state.get("unreachable_rescues", {})
	if not failed.has(target_id): return false
	var attempt: Dictionary = failed[target_id]


	if world.clock >= float(attempt.until) or int(attempt.blocked_door) != int(world.blocked_door) or observed_position.distance_to(attempt.position) >= 0.85:
		failed.erase(target_id)
		state["next_path"] = 0.0
		return false
	return true

func _remember_unreachable_rescue(actor, state: Dictionary, goal: Vector3) -> void :
	if actor.ruleset != "om" or state.get("mode", "") != "revive": return
	var target_id: int = int(state.get("rescue_target", -1))
	if target_id < 0: return
	var failed: Dictionary = state.get("unreachable_rescues", {})
	failed[target_id] = {"position": goal, "blocked_door": world.blocked_door, "until": world.clock + 1.5}
	state["unreachable_rescues"] = failed



func _pick_objective(actor, state: Dictionary = {}) -> int:
	var best: int = -1
	var best_score: float = INF
	var seen: Dictionary = state.get("alice_seen", {})
	var alice_known: bool = not seen.is_empty() and world.clock - float(seen.get("stamp", -99.0)) < ALICE_MEMORY
	var bad: Dictionary = state.get("bad_objectives", {})
	for index in range(world.school.objectives.size()):
		if index in world.objective_done:
			continue
		var point: Vector3 = world.school.objectives[index]
		var reservations: int = 0

		for friend in world.actors.values():
			if not friend.alive or friend.killer or friend.id == actor.id: continue
			if friend.bot:
				if int(friend.bot_state.get("objective", -1)) == index: reservations += 1
			elif friend.active() and friend.position.distance_to(point) < 3.0:
				reservations += 1
		var distance: float = _reachable_distance(actor, point)
		var score: float = distance + reservations * 35.0 + posmod(index + actor.id, 5) * 0.45
		if alice_known:
			score += maxf(0.0, 28.0 - _flat_distance(seen["position"], point)) * 1.5
		if world.clock < float(bad.get(index, 0.0)):
			score += 1000.0
		if score < best_score:
			best_score = score
			best = index
	return best

func _mark_bad_objective(state: Dictionary) -> void :
	var objective: int = int(state.get("objective", -1))
	if objective < 0 or str(state.get("mode", "")) != "objective": return
	var bad: Dictionary = state.get("bad_objectives", {})
	bad[objective] = world.clock + 8.0
	state["bad_objectives"] = bad



func _choose_escape(actor, state: Dictionary, threat: Dictionary) -> void :
	if world.clock < float(state.get("escape_until", 0.0)) and state.get("has_goal", false) and _reachable_distance(actor, state["goal"]) > 2.2:
		return
	var threat_position: Vector3 = threat["position"]
	var here: Vector3 = actor.global_position
	var current_distance: float = _reachable_distance(actor, threat_position)
	var away: Vector3 = _flat_direction(threat_position, here)
	var candidates: Array[Vector3] = []
	for point in _nav().ring(here, 7.0, 24.0, 2.6, 14, rng):
		candidates.append(point)
	for point in world.school.patrol_points:
		var travel: float = _reachable_distance(actor, point)
		if travel >= 6.0 and travel <= 30.0: candidates.append(point)
	var bad_active: bool = world.clock < float(state.get("bad_goal_until", 0.0))
	var ranked: Array = []
	for point in candidates:
		if bad_active and point.distance_to(state["bad_goal"]) < 3.0:
			continue
		var travel: float = _reachable_distance(actor, point)
		var enemy_distance: float = _flat_distance(threat_position, point)
		var departure: Vector3 = _flat_direction(here, point)
		var score: float = enemy_distance * 0.9 - travel * 0.33 + departure.dot(away) * 7.0
		if enemy_distance < current_distance - 2.0:
			score -= 13.0

		if departure.dot( - away) > 0.5 and current_distance < 14.0:
			score -= 10.0
		if point.distance_to(state.get("last_escape", here)) < 3.0:
			score -= 4.0
		ranked.append([score, point])
	ranked.sort_custom( func(a: Array, b: Array): return float(a[0]) > float(b[0]))
	var best_score: float = - INF
	var chosen: Vector3 = here

	for entry in ranked.slice(0, 5):
		var point: Vector3 = entry[1]
		var score: float = float(entry[0])
		if not world.visible(threat_position + EYE, point + EYE):
			score += 11.0
		var exits: int = 0
		for direction in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
			if world.school.can_walk(point + direction * 2.0):
				exits += 1
		score += exits * 1.4
		if exits <= 1:
			score -= 13.0
		if score > best_score:
			best_score = score
			chosen = point
	if best_score == - INF:
		chosen = here + away * 7.0
		if not world.school.can_walk(chosen):
			_patrol(actor, state)
			return
	state["last_escape"] = state.get("goal", here)
	state["escape_until"] = world.clock + rng.randf_range(1.5, 2.1)
	_set_goal(state, chosen)



func _hide(actor, state: Dictionary) -> void :
	state["mode"] = "hide"
	state["objective"] = -1
	state["working"] = -1
	var seen: Dictionary = state.get("alice_seen", {})
	var danger: Vector3 = world.school.killer_spawn if seen.is_empty() else Vector3(seen["position"])
	var spot: Vector3 = state.get("hide_spot", Vector3.INF)
	var moved: bool = danger.distance_to(state.get("hide_from", danger)) > 8.0
	if spot.is_finite() and not moved and world.clock < float(state.get("hide_until", 0.0)) and not (world.clock < float(state.get("bad_goal_until", 0.0)) and spot.distance_to(state["bad_goal"]) < 3.0):
		if _reachable_distance(actor, spot) < 1.6:
			state["has_goal"] = false
		else:
			_set_goal(state, spot)
		return
	var ranked: Array = []
	for point in _nav().ring(actor.global_position, 8.0, 34.0, 2.6, 12, rng):
		ranked.append([_flat_distance(danger, point) - 0.35 * _reachable_distance(actor, point), point])
	ranked.sort_custom( func(a: Array, b: Array): return float(a[0]) > float(b[0]))
	var best: Vector3 = Vector3.INF
	var best_score: float = - INF
	for entry in ranked.slice(0, 4):
		var score: float = float(entry[0]) + (15.0 if not world.visible(danger + EYE, Vector3(entry[1]) + EYE) else 0.0)
		if score > best_score:
			best_score = score
			best = entry[1]
	if not best.is_finite():
		_patrol(actor, state)
		return
	state["hide_spot"] = best
	state["hide_from"] = danger
	state["hide_until"] = world.clock + rng.randf_range(18.0, 26.0)
	_set_goal(state, best)

func _patrol(actor, state: Dictionary) -> void :
	if state.get("has_goal", false) and _reachable_distance(actor, state["goal"]) > 2.0 and float(state.get("stuck_for", 0.0)) < 2.0:
		return
	var points = world.school.patrol_points
	if points.is_empty():
		points = world.school.objectives
	if points.is_empty():
		state["has_goal"] = false
		return
	var index: int = posmod(int(state.get("patrol_index", 0)) + 1, points.size())
	state["patrol_index"] = index
	_set_goal(state, points[index])

func _set_goal(state: Dictionary, position: Vector3) -> void :
	state["goal"] = position
	state["has_goal"] = true



func _steer(actor, state: Dictionary, delta: float) -> void :
	if float(actor.effects.get("grab_time", 0)) > 0 or float(actor.effects.get("forced_time", 0)) > 0 or bool(actor.effects.get("shadow_hide", false)):
		return
	actor.move_input = Vector3.ZERO
	actor.sprint = false
	if float(actor.effects.get("stun", 0.0)) > 0.0 or float(actor.effects.get("root", 0.0)) > 0.0 or float(actor.effects.get("heal_time", 0.0)) > 0.0 or float(actor.effects.get("outlet_healing", 0)) > 0 or bool(actor.effects.get("boost_charging", false)) or int(actor.effects.get("carried_by", -1)) >= 0:
		state["progress_position"] = actor.global_position
		state["progress_at"] = world.clock
		return
	if not state.get("has_goal", false):
		state["progress_position"] = actor.global_position
		state["progress_at"] = world.clock
		return
	var path: PackedVector3Array = state.get("path", PackedVector3Array())
	var path_index: int = int(state.get("path_index", 0))
	var goal: Vector3 = state["goal"]
	var mode: String = state.get("mode", "patrol")


	var goal_moved: bool = goal.distance_to(state.get("path_goal", goal)) > 1.5
	var block_changed: bool = int(state.get("path_block", -2)) != int(world.blocked_door)
	var stale: bool = mode in ["chase", "protect", "flee"] and world.clock - float(state.get("path_time", -99.0)) > PATH_MAX_AGE
	if world.clock >= float(state.get("next_path", 0.0)) and (goal_moved or path_index >= path.size() or block_changed or stale):
		path = world.school.nav_path(actor.global_position, goal, -1 if actor.killer else world.blocked_door)
		path_index = 0
		state["path"] = path
		state["path_index"] = 0
		state["path_goal"] = goal
		state["path_block"] = world.blocked_door
		state["path_time"] = world.clock
		state["next_path"] = world.clock + REPATH_SECONDS + rng.randf_range(0.0, 0.12)
		if path.is_empty():
			_remember_unreachable_rescue(actor, state, goal)
			_mark_bad_objective(state)
			state["bad_goal"] = goal
			state["bad_goal_until"] = world.clock + 5.0
			state["escape_until"] = 0.0
			state["has_goal"] = false
			state["objective"] = -1
			return
	while path_index < path.size() and _reachable_distance(actor, path[path_index]) < 0.7 and (actor.ruleset != "om" or absf(actor.global_position.y - path[path_index].y) < 0.7):
		path_index += 1
	state["path_index"] = path_index
	var direction: Vector3 = Vector3.ZERO
	var close_target = null
	if actor.killer and mode == "chase" and state.get("face_threat", false):


		close_target = world.actors.get(int(state.get("threat", {}).get("id", -1)))
		if close_target == null or not close_target.active() or _reachable_distance(actor, close_target.global_position) > 5.0 or absf(close_target.global_position.y - actor.global_position.y) > 1.0:
			close_target = null
	if world.clock < float(state.get("unstick_until", 0.0)):
		direction = state.get("unstick_direction", Vector3.ZERO)
	elif close_target != null:
		direction = _flat_direction(actor.global_position, close_target.global_position)
	elif path_index < path.size():
		direction = _flat_direction(actor.global_position, path[path_index])
	elif _reachable_distance(actor, goal) < 1.3:
		state["has_goal"] = false
		state["escape_until"] = 0.0
		return
	elif _goal_in_straight_reach(actor, state, goal):

		direction = _flat_direction(actor.global_position, goal)
	elif _reachable_distance(actor, goal) < 2.6:


		if mode == "objective":
			state["has_goal"] = false
			return
		direction = _flat_direction(actor.global_position, goal)
	else:

		state["next_path"] = minf(float(state.get("next_path", 0.0)), world.clock + 0.3)

	var separation: Vector3 = Vector3.ZERO
	for other in world.actors.values():
		if not other.alive or other.id == actor.id or other.killer != actor.killer:
			continue
		var distance: float = _reachable_distance(actor, other.global_position)
		if distance > 0.05 and distance < 1.35:
			separation += _flat_direction(other.global_position, actor.global_position) * (1.35 - distance) * 0.65
	direction = (direction + separation).normalized()
	actor.move_input = direction
	if actor.killer and actor.is_on_floor() and world.clock >= float(state.get("barrier_check_at", 0.0)):
		state["barrier_check_at"] = world.clock + 0.1
		if _low_barrier_ahead(actor, direction): actor.request_jump()
	if actor.ruleset == "om":
		var jump_point: Vector3 = Vector3.ZERO
		if world.school.has_method("om_jump_hint"): jump_point = world.school.om_jump_hint(actor.global_position, goal)
		if jump_point != Vector3.ZERO and actor.request_jump():
			state["jump_goal"] = jump_point
			state["jump_until"] = world.clock + 1.15
		elif path_index < path.size() and world.school.has_method("bot_jump_hint") and world.school.bot_jump_hint(actor.global_position, path[path_index]): actor.request_jump()
		if world.clock < float(state.get("jump_until", 0.0)):
			actor.move_input = _flat_direction(actor.global_position, state["jump_goal"])
			direction = actor.move_input
	var threat: Dictionary = state.get("threat", {})
	if float(actor.effects.get("grenade_windup", 0.0)) > 0.0:
		pass
	elif state.get("face_threat", false) and not threat.is_empty():
		var desired_aim: Vector3 = _flat_direction(actor.global_position, threat["position"])
		actor.aim = actor.aim.lerp(desired_aim, minf(1.0, delta * 13.0)).normalized()
	elif direction.length_squared() > 0.1:
		actor.aim = actor.aim.lerp(direction, minf(1.0, delta * 10.0)).normalized()
	var distance_to_threat: float = INF if threat.is_empty() else _reachable_distance(actor, threat["position"])
	var stamina_fraction: float = 1.0 if actor.max_stamina < 0 else actor.stamina / maxf(actor.max_stamina, 1.0)
	if stamina_fraction < 0.2:
		state["resting"] = true
	elif stamina_fraction > 0.58:
		state["resting"] = false
	var chase_or_flee: bool = mode in ["chase", "flee", "protect"]
	var emergency: bool = distance_to_threat < (4.5 if actor.killer else 8.0)
	var sprint_wanted: bool = chase_or_flee and ( not state.get("resting", false) or emergency)
	if mode == "objective" and stamina_fraction > 0.87 and _reachable_distance(actor, goal) > 15.0:
		sprint_wanted = true
	actor.sprint = (sprint_wanted or (actor.ruleset == "om" and mode in ["objective", "revive", "escape", "guard", "heal", "salvage"])) and direction.length_squared() > 0.1 and (actor.max_stamina < 0 or actor.stamina > 2.0)
	_check_stuck(actor, state, direction)



func _goal_in_straight_reach(actor, state: Dictionary, goal: Vector3) -> bool:
	if Vector3(state.get("reach_goal", Vector3.INF)).distance_to(goal) > 0.05:
		state["reach_goal"] = goal
		state["reach_walkable"] = world.school.can_walk(goal)
		state["reach_checked_at"] = -99.0
	if not bool(state.get("reach_walkable", false)):
		return false
	if world.clock - float(state.get("reach_checked_at", -99.0)) > 0.2:
		state["reach_checked_at"] = world.clock
		state["reach_visible"] = world.visible(actor.global_position, goal)
	return bool(state.get("reach_visible", false))

func _check_stuck(actor, state: Dictionary, direction: Vector3) -> void :
	if world.clock - float(state.get("progress_at", 0.0)) < 0.85:
		return
	var moved: float = _reachable_distance(actor, state.get("progress_position", actor.global_position))
	if direction.length_squared() > 0.2 and moved < 0.28:
		state["stuck_for"] = float(state.get("stuck_for", 0.0)) + 0.85
	else:
		state["stuck_for"] = maxf(0.0, float(state.get("stuck_for", 0.0)) - 1.0)
	state["progress_position"] = actor.global_position
	state["progress_at"] = world.clock
	if float(state["stuck_for"]) > 1.0:
		var side: Vector3 = Vector3( - direction.z, 0, direction.x)
		if rng.randf() < 0.5:
			side = - side
		for alternative in [side, - side, - direction]:
			var position: Vector3 = actor.global_position + alternative * 1.2
			if world.school.can_walk(position) and world.visible(actor.global_position + EYE, position + EYE):
				state["unstick_direction"] = alternative
				state["unstick_until"] = world.clock + 0.6
				break
		state["path"] = PackedVector3Array()
	if float(state["stuck_for"]) > 2.5:
		_mark_bad_objective(state)
		state["bad_goal"] = state.get("goal", actor.global_position)
		state["bad_goal_until"] = world.clock + 7.0
		state["objective"] = -1
		state["has_goal"] = false
		state["escape_until"] = 0.0
		state["stuck_for"] = 0.0



func _ready(actor, slot: int) -> bool:
	return float(actor.cooldowns.get(slot, 0.0)) <= 0.0 and float(actor.effects.get("stun", 0.0)) <= 0.0

func _backing_off(state: Dictionary, slot: int) -> bool:
	return world.clock < float(state.get("skill_backoff", {}).get(slot, 0.0))

func _try_skill(actor, state: Dictionary, slot: int, target_id: int = -1) -> bool:
	if world.clock < float(state.get("next_skill", 0.0)) or not _ready(actor, slot) or _backing_off(state, slot):
		return false
	if actor.ruleset == "om" and target_id >= 0 and ((actor.character == "Bleuette" and slot in [0, 1]) or (actor.character == "Elly" and slot == 0)):
		var friend = world.actors.get(target_id)
		if friend != null: actor.aim = _flat_direction(actor.global_position, friend.global_position)
	var succeeded: bool = world.combat.use(actor, slot, target_id)
	if succeeded:
		if slot == 1 and actor.character in ["Simon", "Ashura"]: state["boost_release_at"] = _charge_target(actor, state)
		state["next_skill"] = world.clock + rng.randf_range(0.26, 0.44)
	else:

		var backoff: Dictionary = state.get("skill_backoff", {})
		backoff[slot] = world.clock + SKILL_BACKOFF
		state["skill_backoff"] = backoff
	return succeeded

func _has_spent_skill(actor) -> bool:
	for cooldown in actor.cooldowns.values():
		if float(cooldown) > 8.0:
			return true
	return false


func _predict(contact: Dictionary, seconds: float) -> Vector3:
	var velocity: Vector3 = contact.get("velocity", Vector3.ZERO)
	return Vector3(contact["position"]) + Vector3(velocity.x, 0.0, velocity.z).limit_length(22.0) * seconds

func _flat_distance(from: Vector3, to: Vector3) -> float:
	return Vector2(to.x - from.x, to.z - from.z).length()

func _flat_direction(from: Vector3, to: Vector3) -> Vector3:
	return Vector3(to.x - from.x, 0, to.z - from.z).normalized()

func _reachable_distance(actor, point: Vector3) -> float:
	return actor.global_position.distance_to(point) if actor.ruleset == "om" else _flat_distance(actor.global_position, point)



func _crawl_toward_help(actor):
	actor.move_input = Vector3.ZERO;actor.sprint = false
	var state: Dictionary = actor.bot_state
	if world.clock >= float(state.get("crawl_think_at", 0.0)):
		state["crawl_think_at"] = world.clock + rng.randf_range(DECISION_MIN, DECISION_MAX)
		var friend = null
		var distance: float = INF
		for ally in world.actors.values():
			if ally.killer or not ally.active() or ally == actor: continue
			var current: float = actor.position.distance_to(ally.position)
			if ally.bot and str(ally.bot_state.get("mode", "")) == "revive" and int(ally.bot_state.get("rescue_target", -1)) == int(actor.id):
				friend = ally
				distance = current
				break
			if current < distance:
				friend = ally
				distance = current
		state["crawl_friend"] = -1 if friend == null or distance <= 1.3 else int(friend.id)
		if friend != null and distance > 1.3:
			var destination: Vector3 = friend.position
			if world.clock >= float(state.get("crawl_next", 0.0)) and destination.distance_to(state.get("crawl_goal", destination + Vector3.ONE * 10)) > 1.5:
				state["crawl_path"] = world.school.nav_path(actor.position, destination, world.blocked_door)
				state["crawl_next"] = world.clock + rng.randf_range(0.65, 0.8)
				state["crawl_goal"] = destination
	if int(state.get("crawl_friend", -1)) < 0:
		return
	var route: PackedVector3Array = state.get("crawl_path", PackedVector3Array())
	while not route.is_empty() and actor.position.distance_to(route[0]) < 0.7: route.remove_at(0)
	state["crawl_path"] = route
	if not route.is_empty(): actor.move_input = _flat_direction(actor.position, route[0])

func _low_barrier_ahead(actor, direction: Vector3) -> bool:
	if direction.length_squared() < 0.1 or float(actor.effects.get("jump_cd", 0)) > 0: return false
	var space: PhysicsDirectSpaceState3D = actor.get_world_3d().direct_space_state
	var foot: Vector3 = actor.position + Vector3.UP * 0.6
	var low: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(foot, foot + direction * 2.0, 1))
	if low.is_empty(): return false
	var head: Vector3 = actor.position + Vector3.UP * 2.4
	if not space.intersect_ray(PhysicsRayQueryParameters3D.create(head, head + direction * 3.5, 1)).is_empty(): return false
	var landing: Vector3 = actor.position + direction * 3.8
	var floor_hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(landing + Vector3.UP * 2.5, landing - Vector3.UP * 2.0, 1))
	return not floor_hit.is_empty() and Vector3(floor_hit.normal).y > 0.65
