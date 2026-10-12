class_name PaperTraining
extends RefCounted

var world: Node3D
var dummy_mode: String = "idle"
var respawns: Dictionary = {}
var homes: Dictionary = {}
var home_aims: Dictionary = {}
var feedback: String = "F2 · Personnages, cibles et capacités"
var feedback_until: float = 0.0
var next_dummy: int = 90000001

func _init(game_world: Node3D) -> void :
	world = game_world

func clear() -> void :
	respawns.clear();homes.clear();home_aims.clear();dummy_mode = "idle";feedback = "F2 · Personnages, cibles et capacités";feedback_until = 0

func is_dummy(actor: PaperActor) -> bool:
	return bool(actor.effects.get("training_dummy", false))





func _spawn_centre() -> Vector3:
	var spawns: Array[Vector3] = world.school.spawn_points
	if spawns.is_empty(): return Vector3(0, 0.1, 36)
	var centre: Vector3 = Vector3.ZERO
	for p: Vector3 in spawns: centre += p
	return centre / float(spawns.size())


func _inward() -> Vector3:
	var flat: Vector3 = - _spawn_centre()
	flat.y = 0.0
	return flat.normalized() if flat.length() > 1.0 else Vector3.FORWARD

func player_point(slot: int) -> Vector3:
	var spawns: Array[Vector3] = world.school.spawn_points
	if spawns.is_empty(): return Vector3((slot % 4 - 1.5) * 2.2, 0.1, 36 + floorf(slot / 4.0) * 3)
	var base: Vector3 = spawns[slot % spawns.size()]

	return _walkable(base - _inward() * 2.5 * floorf(float(slot) / float(spawns.size())), base)


func dummy_point(dummy: String) -> Vector3:
	var inward: Vector3 = _inward()
	var side: Vector3 = Vector3( - inward.z, 0.0, inward.x)
	var centre: Vector3 = _spawn_centre()
	var point: Vector3 = centre + inward * 12.0
	if dummy == "ally": point = centre + inward * 9.0 - side * 6.0
	elif dummy == "target": point = centre + inward * 9.0 + side * 6.0
	point.y = centre.y
	return _walkable(point, centre)


func _walkable(point: Vector3, fallback: Vector3) -> Vector3:
	if world.school.can_walk(point): return point
	var path: PackedVector3Array = world.school.nav_path(fallback, point)
	if not path.is_empty():
		var last: Vector3 = path[path.size() - 1]
		return Vector3(last.x, point.y, last.z)
	return fallback

func _new_dummy(character_name: String, point: Vector3, title: String) -> PaperActor:
	while world.actors.has(next_dummy) or world.roster.has(next_dummy): next_dummy += 1
	var actor: PaperActor = world._spawn(next_dummy, character_name, false, point, title)
	next_dummy += 1;actor.effects["training_dummy"] = true;homes[actor.id] = point

	home_aims[actor.id] = - _inward()
	actor.aim = home_aims[actor.id]
	return actor

func ensure_dummies() -> void :
	var human_killer: bool = false; var dummy_killer: PaperActor; var allies: Array[PaperActor] = []
	for actor: PaperActor in world.actors.values():
		if actor.killer:
			if is_dummy(actor): dummy_killer = actor
			else: human_killer = true
		elif is_dummy(actor): allies.append(actor)
	if human_killer and dummy_killer: remove_actor(dummy_killer)
	elif not human_killer and not dummy_killer: _new_dummy("Alice", dummy_point("killer"), "Alice · Cible")
	if allies.is_empty():
		var ally: PaperActor = _new_dummy("Elly", dummy_point("ally"), "Allié · Soins et soutien")
		ally.hp = maxf(1, ally.max_hp - 45)
	if allies.size() < 2: _new_dummy("Simon", dummy_point("target"), "Survivant · Cible")

func add_player(peer: int) -> void :
	var data: Dictionary = world.roster[peer]; var chosen: String = str(data.character)
	var used: Array[String] = []
	for actor: PaperActor in world.actors.values():
		if not is_dummy(actor): used.append(actor.character)
	if not PaperData.NAMES.has(chosen) or used.has(chosen):
		chosen = "Alice"
		for candidate: String in PaperData.NAMES:
			if not used.has(candidate): chosen = candidate;break
	var slot: int = maxi(0, world.roster.keys().find(peer))
	var point: Vector3 = player_point(slot)
	var actor: PaperActor = world._spawn(peer, chosen, false, point, str(data.name));homes[peer] = point
	home_aims[peer] = _inward()
	actor.aim = home_aims[peer]

func remove_actor(actor: PaperActor) -> void :
	world.combat.reset_for_training(actor)
	world.actors.erase(actor.id);homes.erase(actor.id);home_aims.erase(actor.id);respawns.erase(actor.id)
	world.remove_child(actor);actor.queue_free()

func human_owner(character_name: String, except_id: int) -> String:
	for actor: PaperActor in world.actors.values():
		if not is_dummy(actor) and actor.id != except_id and actor.character == character_name: return actor.display_name
	return ""

func change_character(peer: int, character_name: String, sync: bool = true) -> bool:
	if not character_name in PaperData.STATS or not world.actors.has(peer): return false
	var taken: String = human_owner(character_name, peer)
	if not taken.is_empty(): _notice(peer, "Déjà joué par " + taken + ". Choisis un personnage libre.");return false
	var old: PaperActor = world.actors[peer]; var point: Vector3 = homes.get(peer, player_point(0)); var player_name: String = old.display_name
	var aim: Vector3 = home_aims.get(peer, _inward())
	remove_actor(old)
	var actor: PaperActor = world._spawn(peer, character_name, false, point, player_name);homes[peer] = point
	home_aims[peer] = aim
	actor.aim = aim
	ensure_dummies()
	if sync:
		world.round_serial += 1;world._sync_round_for_clients()
		_notice(peer, character_name + " prêt · F2 pour préparer un test.")
	return true

func command(peer: int, action: String, value: String) -> void :
	if not world.training or not world.authoritative() or not world.actors.has(peer): return
	var actor: PaperActor = world.actors[peer]
	if action in ["reset_all", "dummy_mode", "dummy_character", "injure", "ally_cooldown", "down_ally", "archive_test"] and peer != world.lobby_leader:
		_notice(peer, "L'hôte règle les cibles communes. Tu peux réinitialiser ton propre personnage.");return
	match action:
		"character": change_character(peer, value);return
		"reset":
			_reset(actor, false);_notice(peer, "PV, endurance, capacités et états remis à zéro.")
		"lms":
			if actor.killer:
				actor.effects["rage"] = 100;actor.effects["stun_count"] = 15;actor.effects["true_form_used"] = false
				_notice(peer, "True Form prête · ferme le panneau et active la compétence 6.")
			else:
				_reset(actor, false);actor.lms = true;world.combat.apply_lms(actor)
				_notice(peer, "LMS de " + actor.character + " activé, avec sa musique.")
		"injure":
			for target: PaperActor in world.actors.values():
				if is_dummy(target) and not target.killer:
					_reset(target, false);target.hp = maxf(1, target.max_hp - 50)
			_notice(peer, "Les mannequins alliés ont perdu 50 PV. Tu peux tester les soins.")
		"ally_cooldown":
			for target: PaperActor in world.actors.values():
				if is_dummy(target) and not target.killer: target.cooldowns[0] = 20.0
			_notice(peer, "Première capacité des mannequins en recharge : 20 s. Bleuette peut la réduire.")
		"down_ally":
			var target: PaperActor
			var nearest: float = INF
			for candidate: PaperActor in world.actors.values():
				if is_dummy(candidate) and not candidate.killer and candidate.character != "Lysia" and actor.position.distance_to(candidate.position) < nearest:
					target = candidate;nearest = actor.position.distance_to(candidate.position)
			if target:
				_reset(target, false);target.hp = 0
				world.combat._fatal_damage(target, -1, "slash")
				_notice(peer, "Allié au sol · approche-le et touche INTERAGIR / E pour le relever immédiatement. Il reste 30 s pour le sauver." if str(world.ruleset) == "om" else "Allié au sol · approche-le et maintiens E pendant 4 s. Il reste 30 s pour le sauver.")
		"down_self":
			if actor.killer: _notice(peer, "Choisis un survivant pour tester la réanimation.");return
			actor.hp = 0;world.combat._fatal_damage(actor, -1, "slash")
			_notice(peer, "Blessure fatale appliquée : première chute, ou mort définitive après une réanimation. Lysia ne peut pas être relevée.")
		"archive_test":
			world.combat.reset_archives_for_training()
			_notice(peer, "Archives réinitialisées. Approche une archive et maintiens E : réponds avec J, K ou L. Échec = panne 3 s + alarme.")
		"dummy_mode":
			if not value in ["idle", "walk", "attack"]: return
			dummy_mode = value
			for target: PaperActor in world.actors.values():
				if is_dummy(target): _reset(target, true)
			_notice(peer, "Cibles : " + {"idle": "immobiles", "walk": "en mouvement", "attack": "Alice attaque à portée"}[value])
		"dummy_character":
			if not PaperData.NAMES.has(value): return
			for target: PaperActor in world.actors.values():
				if is_dummy(target) and not target.killer and target.display_name.begins_with("Allié"):
					var point: Vector3 = homes.get(target.id, dummy_point("ally"))
					remove_actor(target); var fresh: PaperActor = _new_dummy(value, point, "Allié · Soins et soutien");fresh.hp = maxf(1, fresh.max_hp - 45);break
		"near", "behind", "ally_near":
			var target: PaperActor = world.killer_actor()
			if actor.killer or action == "ally_near":
				for candidate: PaperActor in world.actors.values():
					if is_dummy(candidate) and not candidate.killer and (action != "ally_near" or candidate.display_name.begins_with("Allié")): target = candidate;break
			if not target or target == actor: return
			var forward: Vector3 = target.aim.normalized()
			if forward.length_squared() < 0.5: forward = Vector3.FORWARD
			var point: Vector3 = target.position + forward * (-1.8 if action == "behind" else 1.8)

			var path: PackedVector3Array = world.school.nav_path(actor.position, point)
			if path.is_empty(): _notice(peer, "Cette cible n'est pas accessible depuis ici.");return
			var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
			query.shape = actor.collider.shape;query.transform = Transform3D(Basis.IDENTITY, point + actor.collider.position + Vector3.UP * 0.06);query.collision_mask = actor.collision_mask
			if not world.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(): _notice(peer, "L'emplacement est bloqué. Déplace la cible ou réinitialise le terrain.");return
			actor.position = point;actor.net_position = point;actor.velocity = Vector3.ZERO;actor.aim = (target.position - point).normalized()
			if peer == world.local_id(): world.yaw = atan2( - actor.aim.x, - actor.aim.z)
			elif world.networked: world.training_view.rpc_id(peer, actor.aim)
		"reset_all": reset_all();_notice(peer, "Terrain réinitialisé.")
		_: return
	world.round_serial += 1;world._sync_round_for_clients()

func _notice(peer: int, message: String) -> void :
	if peer == world.local_id(): world.ui.toast(message, 5)
	elif world.networked: world.selection_notice.rpc_id(peer, message)

func _reset(actor: PaperActor, move_home: bool) -> void :
	world.combat.reset_for_training(actor)
	actor.collider.set_deferred("disabled", false)
	respawns.erase(actor.id)
	if move_home: actor.position = homes.get(actor.id, actor.position);actor.net_position = actor.position
	actor.aim = home_aims.get(actor.id, Vector3.FORWARD);actor.visual.rotation.z = 0;actor.visual.set_aura(false, Color.WHITE)

func reset_all() -> void :
	for actor: PaperActor in world.actors.values(): _reset(actor, true)
	world.combat.clear_entities();world.lms = false;world.blocked_door = -1;world._build_barrier();world.objective_done.clear();world.objective_progress.clear()
	dummy_mode = "idle"

func on_eliminated(actor: PaperActor) -> void :
	respawns[actor.id] = world.clock + 2.0

func tick(_delta: float) -> void :
	for key: Variant in respawns.keys():
		if world.clock >= float(respawns[key]):
			var actor: PaperActor = world.actors.get(int(key))
			if actor: _reset(actor, true)
			else: respawns.erase(key)
	for actor: PaperActor in world.actors.values():
		if not is_dummy(actor) or not actor.active(): continue
		actor.move_input = Vector3.ZERO;actor.sprint = false
		if dummy_mode == "walk":
			var home: Vector3 = homes.get(actor.id, actor.position)
			var goal: Vector3 = home + Vector3(sin(world.clock * 0.45) * 3.0, 0, 0)
			var direction: Vector3 = goal - actor.position;direction.y = 0
			actor.move_input = direction.limit_length(0.6)
		elif dummy_mode == "attack" and actor.killer:
			var target: PaperActor
			var best: float = INF
			for human: PaperActor in world.actors.values():
				if human.active() and not human.killer and not is_dummy(human) and actor.position.distance_to(human.position) < best: best = actor.position.distance_to(human.position);target = human
			if target:
				actor.aim = (target.position - actor.position).normalized()
				if best < 3.1: world.combat.use(actor, 0)

func update_labels() -> void :
	for actor: PaperActor in world.actors.values():
		if not is_dummy(actor): continue
		var label: Label3D = actor.get_node_or_null("TrainingLabel")
		if not label:
			label = Label3D.new();label.name = "TrainingLabel";actor.add_child(label);label.position.y = 2.9;label.font_size = 29;label.pixel_size = 0.009;label.billboard = BaseMaterial3D.BILLBOARD_ENABLED;label.modulate = Color("bbded6");label.outline_size = 9
			var ring: MeshInstance3D = world._ring(0.8, Color(0.4, 0.8, 0.7, 0.6));actor.add_child(ring);ring.position.y = 0.025
		var status: String = ""
		if not actor.alive: status = "Retour dans 2 s"
		elif bool(actor.effects.get("dying", false)): status = "ÉLIMINATION"
		elif bool(actor.effects.get("downed", false)): status = "AU SOL · %.0f s · E pour réanimer" % float(actor.effects.get("bleedout", 0))
		elif float(actor.effects.get("stun", 0)) > 0: status = "ÉTOURDI · %.1f s" % float(actor.effects.stun)
		elif float(actor.effects.get("slow_time", 0)) > 0: status = "RALENTI · %.1f s" % float(actor.effects.slow_time)
		elif int(actor.effects.get("grabbed_by", -1)) >= 0: status = "ATTRAPÉ"
		elif float(actor.effects.get("next_stun", 0)) > 0: status = "PROCHAIN STUN RENFORCÉ"
		elif float(actor.effects.get("next_heal", 0)) > 1: status = "PROCHAIN SOIN RENFORCÉ"
		elif bool(actor.effects.get("drone_bonus", false)): status = "RÉSERVE DRONE PRÊTE"
		elif float(actor.effects.get("sprint_bonus", 0)) > 0: status = "PROCHAINE COURSE RENFORCÉE"
		elif float(actor.effects.get("cooldown_discount", 0)) > 0: status = "PROCHAINE RECHARGE RÉDUITE"
		elif float(actor.cooldowns.get(0, 0)) > 0: status = "CAPACITÉ 1 · %.1f s" % float(actor.cooldowns[0])
		label.text = actor.character + " · MANNEQUIN\n" + ("PV ∞" if actor.killer else "%d / %d PV" % [ceili(actor.hp), int(actor.max_hp)]) + "\n" + status

func observe(kind: String, data: Dictionary) -> void :
	var actor: PaperActor = world.actors.get(int(data.get("actor", -1)))
	var name: String = actor.character if actor else "Cible"
	match kind:
		"hit": feedback = name + " · impact reçu"
		"stun": feedback = name + " · étourdissement appliqué"
		"heal": feedback = "Soin appliqué"
		"boost": feedback = "Bonus appliqué"
		"drone": feedback = "Drone · " + str(data.get("action", ""))
		"ability": feedback = name + " · " + str(data.get("name", ""))
		"downed": feedback = name + " · au sol, réanimation possible pendant 30 s"
		"revive_start": feedback = "Réanimation en cours · maintiens E pendant 4 s"
		"revive_cancel": feedback = "Réanimation interrompue"
		"revived": feedback = name + " · seconde vie, prochaine chute définitive"
		"death_start": feedback = name + " · élimination définitive"
		"archive_alarm": feedback = "QTE raté · archive bloquée 3 s, position signalée à Alice"
		"archive_qte": feedback = "Archive · " + ("appuie sur " + str(data.get("key", "")) if bool(data.get("ready", false)) else "QTE réussi" if bool(data.get("success", false)) else "QTE raté")
		_: return
	feedback_until = world.clock + 5
