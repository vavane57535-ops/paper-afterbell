extends Node

# Banc d'essai des mécaniques 0.16 des survivants. Force chaque situation, imprime les valeurs
# mesurées (lignes « MECH ») puis quitte. Les durées sont mesurées sur l'horloge de jeu (world.clock).
#   Logique : godot --headless -- --simulate Lysia --duration 400 --speed 3 --tool test_mechanics
#   Rendu   : xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 -- --simulate Lysia --duration 400 --tool test_mechanics --mech-shots /tmp/dossier
# Les captures dépendent du personnage local : Lysia (prises en X-ray, lien Ashura, surchauffe), Bleuette (barre au-delà de 150).

const Mech = preload("res://survivor_mechanics.gd")

var world: Node
var _shots: String = ""
var _only: PackedStringArray = []
var _summary: Dictionary = {}
var _failures: Array[String] = []


func setup(owner: Node) -> void :
	world = owner
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		if args[i] == "--mech-shots" and i + 1 < args.size(): _shots = args[i + 1]
		if args[i] == "--mech-only" and i + 1 < args.size(): _only = args[i + 1].split(",")
	if not _shots.is_empty(): DirAccess.make_dir_recursive_absolute(_shots)
	_run()


func _run() -> void :
	while str(world.phase) != "playing" or world.actors.is_empty():
		await get_tree().process_frame
	await _frames(20)
	world.time_left = 999.0
	for actor: PaperActor in world.actors.values():
		actor.bot = false
		actor.move_input = Vector3.ZERO
		actor.sprint = false
	print("MECH_START local=", world.local_actor().character, " map=", world.selected_map, " render=", _rendering())
	if _wants("overheat"):
		await _test_overheat("complete", 200.0, false)
		await _test_overheat("interrupted", 200.0, true)
		await _test_overheat("floor", 25.0, false)
	if _wants("outlet"):
		await _test_outlet(false)
		await _test_outlet(true)
	if _wants("ashura_ai"): await _test_ashura_ai()
	if _wants("xray"): await _test_xray()
	if _wants("boost"): await _test_boosts()
	if _wants("lms"): await _test_lms()
	_summary["failures"] = _failures
	print("MECH_SUMMARY ", JSON.stringify(_summary))
	print("MECH_RESULT ", "OK" if _failures.is_empty() else "FAILED " + str(_failures))
	if world.networked: await _wait(2.0)
	get_tree().quit()




func _test_overheat(kind: String, start_hp: float, interrupt: bool) -> void :
	var lysia: PaperActor = _by("Lysia")
	var alice: PaperActor = world.killer_actor()
	_reset(lysia);_reset(alice)
	var base: Vector3 = world.school.spawn_points[0]
	_place(lysia, base)
	var front: Vector3 = _free_offset(base, 2.4)
	_place(alice, front)
	await _wait(0.4)
	lysia.hp = start_hp
	_face(lysia, alice.global_position)
	await _frames(2)
	var used: bool = world.combat.use(lysia, 0)
	var started: float = -1.0
	var curve: Array = []
	var deadline: float = world.clock + 6.0
	var moved_away: bool = false
	var shot_taken: bool = false
	while world.clock < deadline:
		await get_tree().physics_frame
		var hold: float = float(lysia.effects.get("overheat_time", 0.0))
		if started < 0.0 and hold > 0.0: started = world.clock - (3.0 - hold)
		if started >= 0.0:
			var t: float = world.clock - started
			if curve.is_empty() or t - float(curve[-1][0]) >= 0.5 - 0.001: curve.append([snappedf(t, 0.01), snappedf(lysia.hp, 0.01)])
			if interrupt and not moved_away and t >= 1.5:
				moved_away = true
				_place(alice, base + (front - base).normalized() * 9.0)
			if kind == "complete" and not shot_taken and t >= 1.5 and _is_local(lysia):
				shot_taken = true
				await _shot("overheat_mid")
			if hold <= 0.0 and float(lysia.effects.get("overheat_charge", 0.0)) <= 0.0: break
	var lost: float = start_hp - float(lysia.hp)
	var row: Dictionary = {"case": kind, "used": used, "overheat_started": started >= 0.0, "hp_before": start_hp, "hp_after": snappedf(lysia.hp, 0.001), "hp_lost": snappedf(lost, 0.001), "drained_effect": snappedf(float(lysia.effects.get("overheat_drained", 0.0)), 0.001), "alive": lysia.alive, "downed": bool(lysia.effects.get("downed", false)), "curve_t_hp": curve}
	print("MECH overheat ", JSON.stringify(row))
	_summary["overheat_" + kind] = row
	if kind == "complete": _check(started >= 0.0 and absf(lost - 40.0) < 0.05, "surchauffe complète : -40 PV attendus, mesuré %.3f" % lost)
	elif kind == "interrupted": _check(started >= 0.0 and lost > 15.0 and lost < 25.0, "surchauffe interrompue à 1,5 s : ~20 PV attendus, mesuré %.3f" % lost)
	else: _check(absf(float(lysia.hp) - 1.0) < 0.001 and lysia.alive and not bool(lysia.effects.get("downed", false)), "surchauffe à 25 PV : doit finir à 1 PV, mesuré %.3f" % lysia.hp)




func _test_outlet(with_ashura: bool) -> void :
	var lysia: PaperActor = _by("Lysia")
	var ashura: PaperActor = _by("Ashura")
	var alice: PaperActor = world.killer_actor()
	_reset(lysia);_reset(ashura);_reset(alice)
	_place(alice, world.school.killer_spawn)
	var outlet: Vector3 = world.school.healing_outlets[0]
	_place(lysia, outlet + Vector3(0, 0.08, 0))
	var side: Vector3 = _free_offset(outlet, 2.0, [Vector3(1, 0, 0.35), Vector3(-1, 0, 0.35), Vector3(0.7, 0, 1), Vector3(-0.7, 0, 1), Vector3(0, 0, 1)])
	_place(ashura, side if with_ashura else world.school.spawn_points[1])
	await _wait(0.5)
	lysia.hp = 100.0
	lysia.cooldowns[3] = 0.0
	_face(lysia, outlet + Vector3(0, 0, -1))
	if _is_local(lysia):
		var middle: Vector3 = (outlet + Vector3(0, 0, -0.8)).lerp(ashura.global_position, 0.35) if with_ashura else outlet + Vector3(0, 0, -0.8)
		_look(lysia.global_position + Vector3(0, 0, 0.01), middle, -0.22)
	await _frames(2)
	var plugged: bool = world.combat.start_outlet_heal(lysia)
	var t0: float = world.clock
	var hp0: float = float(lysia.hp)
	var at_6: float = -1.0
	var t60: float = -1.0
	var partner_seen: bool = false
	var link_seen: bool = false
	var shots: int = 0
	while world.clock - t0 < 14.0 and float(lysia.effects.get("outlet_healing", 0.0)) > 0.0:
		await get_tree().physics_frame
		var t: float = world.clock - t0
		if int(lysia.effects.get("outlet_ashura", -1)) == int(ashura.id): partner_seen = true
		var fx: Node = world.get_node_or_null("SurvivorFx")
		if fx != null and fx.link_active(lysia.id): link_seen = true
		if at_6 < 0.0 and t >= 6.0: at_6 = float(lysia.hp) - hp0
		if t60 < 0.0 and float(lysia.hp) - hp0 >= 60.0 - 0.001: t60 = t
		if with_ashura and _is_local(lysia) and ((shots == 0 and t >= 0.9) or (shots == 1 and t >= 3.0)):
			shots += 1
			await _shot("outlet_ashura_%d" % shots)
		if t60 >= 0.0 and at_6 >= 0.0: break
	world.combat._stop_outlet(lysia, "cancelled")
	var row: Dictionary = {"ashura_near": with_ashura, "ashura_distance": snappedf(ashura.global_position.distance_to(lysia.global_position), 0.01), "plugged": plugged, "hp_gained_6s": at_6, "seconds_for_60hp": snappedf(t60, 0.01), "hp_per_second": snappedf(60.0 / t60, 0.001) if t60 > 0 else 0.0, "partner_effect_seen": partner_seen, "link_fx_seen": link_seen}
	print("MECH outlet ", JSON.stringify(row))
	_summary["outlet_" + ("ashura" if with_ashura else "alone")] = row
	if with_ashura:
		var alone: float = float(_summary.get("outlet_alone", {}).get("seconds_for_60hp", 0.0))
		var ratio: float = alone / t60 if t60 > 0 else 0.0
		_summary["outlet_speed_ratio"] = snappedf(ratio, 0.001)
		print("MECH outlet_ratio ", snappedf(ratio, 0.001))
		_check(plugged and partner_seen and absf(ratio - 1.5) < 0.04, "soin à la prise avec Ashura : ratio ×1,5 attendu, mesuré %.3f" % ratio)
	else:
		_check(plugged and not partner_seen and absf(t60 - 12.0) < 0.15, "soin à la prise seule : 60 PV en 12 s attendus, mesuré %.2f s" % t60)




# IA : Ashura (bot) doit rejoindre Lysia branchée à une prise et déclencher le bonus ×1,5.
func _test_ashura_ai() -> void :
	var lysia: PaperActor = _by("Lysia")
	var ashura: PaperActor = _by("Ashura")
	var alice: PaperActor = world.killer_actor()
	_reset(lysia);_reset(ashura);_reset(alice)
	_place(alice, world.school.killer_spawn)
	var outlet: Vector3 = world.school.healing_outlets[0]
	_place(lysia, outlet + Vector3(0, 0.08, 0))
	var start: Vector3 = _free_offset(outlet, 11.0, [Vector3.BACK, Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3.RIGHT, Vector3.LEFT])
	_place(ashura, start)
	await _wait(0.5)
	lysia.hp = 80.0
	lysia.cooldowns[3] = 0.0
	var plugged: bool = world.combat.start_outlet_heal(lysia)
	ashura.bot = true
	ashura.bot_state.clear()
	var t0: float = world.clock
	var joined: float = -1.0
	while world.clock - t0 < 12.0 and float(lysia.effects.get("outlet_healing", 0.0)) > 0.0:
		await get_tree().physics_frame
		if joined < 0.0 and int(lysia.effects.get("outlet_ashura", -1)) == int(ashura.id): joined = world.clock - t0
		if joined >= 0.0 and world.clock - t0 > joined + 1.0: break
	var row: Dictionary = {"plugged": plugged, "start_distance": snappedf(start.distance_to(outlet), 0.01), "seconds_to_join": snappedf(joined, 0.01), "final_distance": snappedf(ashura.global_position.distance_to(lysia.global_position), 0.01), "mode": str(ashura.bot_state.get("mode", ""))}
	ashura.bot = false
	ashura.move_input = Vector3.ZERO
	world.combat._stop_outlet(lysia, "cancelled")
	print("MECH ashura_ai ", JSON.stringify(row))
	_summary["ashura_ai"] = row
	_check(plugged and joined >= 0.0, "IA d'Ashura : doit rejoindre Lysia branchée, mesuré " + JSON.stringify(row))


func _test_xray() -> void :
	var lysia: PaperActor = _by("Lysia")
	_reset(lysia)
	var base: Vector3 = world.school.spawn_points[0]
	_place(lysia, base)
	await _wait(0.3)
	var hidden_target: Vector3 = Vector3.INF
	var best: float = INF
	for point: Vector3 in world.school.healing_outlets:
		var distance: float = base.distance_to(point)
		if not world.visible(base, point + Vector3(0, 0, -0.8)) and distance < best: best = distance;hidden_target = point
	if not hidden_target.is_finite(): hidden_target = world.school.healing_outlets[0]
	var alice: PaperActor = world.killer_actor()
	_reset(alice)
	_place(alice, _free_offset(hidden_target + Vector3(0, 0.08, 1.2), 3.6, [Vector3.LEFT, Vector3.RIGHT, Vector3.BACK]))
	if _is_local(lysia): _look(base, hidden_target + Vector3(0, 0.85, -0.8), -0.12)
	await _wait(0.6)
	var fx: Node = world.get_node_or_null("SurvivorFx")
	var before: int = fx.visible_outlets() if fx else -1
	world.combat.use(lysia, 2)
	await _wait(0.6)
	var during: int = fx.visible_outlets() if fx else -1
	if _is_local(lysia): await _shot("xray_outlets")
	if _is_local(lysia) and OS.get_cmdline_user_args().has("--mech-occlusion-debug"):
		print("MECH_DEBUG alice_reveal=", world.reveals.reveal_for(lysia, alice), " alice_pos=", alice.global_position)
		get_viewport().use_occlusion_culling = false
		await _frames(3)
		await _shot("xray_outlets_no_occlusion")
		get_viewport().use_occlusion_culling = true
	await _wait(3.2)
	var after: int = fx.visible_outlets() if fx else -1
	var total: int = world.school.healing_outlets.size()
	var row: Dictionary = {"local_is_lysia": _is_local(lysia), "outlets_on_map": total, "visible_before": before, "visible_during_xray": during, "visible_after": after, "hidden_outlet_looked_at": [hidden_target.x, hidden_target.y, hidden_target.z], "occluded_from_lysia": not world.visible(base, hidden_target + Vector3(0, 0, -0.8))}
	print("MECH xray ", JSON.stringify(row))
	_summary["xray"] = row
	if _is_local(lysia): _check(before == 0 and during == total and after == 0, "X-ray : %d prises attendues pendant l'effet, mesuré %d (avant %d, après %d)" % [total, during, before, after])
	else: _check(during == 0, "X-ray : les prises ne doivent apparaître que pour Lysia, mesuré %d" % during)




func _test_boosts() -> void :
	var bleuette: PaperActor = _by("Bleuette")
	var alice: PaperActor = world.killer_actor()
	_reset(alice)
	_place(alice, world.school.killer_spawn)
	var base: Vector3 = world.school.spawn_points[2]
	var rows: Array = []
	var all_ok: bool = true
	for name: String in ["Ashura", "Usayuko", "Simon", "Lysia", "Elly"]:
		var target: PaperActor = _by(name)
		_reset(bleuette);_reset(target)
		_place(bleuette, base)
		_place(target, _free_offset(base, 2.6))
		await _wait(0.3)
		_face(bleuette, target.global_position)
		var used: bool = world.combat.use(bleuette, 0, target.id)
		var effect: Variant = {"Ashura": target.effects.get("drone_bonus"), "Usayuko": target.effects.get("next_stun"), "Simon": target.effects.get("sprint_bonus"), "Lysia": target.effects.get("cooldown_discount"), "Elly": target.effects.get("next_heal")}[name]
		var ok: bool = used and effect != null and (bool(effect) if effect is bool else float(effect) > (1.0 if name == "Elly" else 0.0))
		all_ok = all_ok and ok
		var row: Dictionary = {"target": name, "used": used, "effect": effect, "bleuette_cooldown": snappedf(float(bleuette.cooldowns.get(0, 0.0)), 0.01)}
		if name == "Simon":
			await _wait(0.2)
			var boosted: float = await _simon_sprint(target)
			var plain: float = await _simon_sprint(target)
			row["sprint_with_boost_s"] = boosted
			row["sprint_without_boost_s"] = plain
			ok = ok and absf(boosted - 5.0) < 0.05 and absf(plain - 3.0) < 0.05
			all_ok = all_ok and ok
		rows.append(row)
		print("MECH boost ", JSON.stringify(row))
		_check(ok, "Encourager sur " + name + " : " + JSON.stringify(row))
	_summary["boosts"] = rows
	_summary["boosts_all_ok"] = all_ok


func _simon_sprint(simon: PaperActor) -> float:
	simon.cooldowns[1] = 0.0
	simon.effects["speed_boost"] = 0.0
	if not world.combat.begin_charge(simon): return -1.0
	simon.effects["boost_charge"] = 1.4
	await get_tree().physics_frame
	simon.effects["boost_charge"] = 1.4
	world.combat.release_charge(simon)
	var duration: float = float(simon.effects.get("speed_boost", 0.0))
	simon.effects["speed_boost"] = 0.0
	return snappedf(duration, 0.01)




func _test_lms() -> void :
	var rows: Array = []
	for start: String in ["low", "mid", "full"]:
		for name: String in PaperData.NAMES:
			var actor: PaperActor = _by(name)
			_reset(actor)
			actor.lms = false
			actor.effects["lms_applied"] = false
			actor.effects["lms_buff_unlocked"] = false
			actor.effects.erase("lms_hp_cap")
			var base_max: float = float(PaperData.STATS[name][0])
			actor.max_hp = base_max
			actor.hp = 40.0 if start == "low" else base_max - 30.0 if start == "mid" else base_max
			var before: float = actor.hp
			world.combat.apply_lms(actor)
			var row: Dictionary = {"start": start, "character": name, "base_max": base_max, "hp_before": before, "hp_after": actor.hp, "max_after": actor.max_hp, "gain": actor.hp - before}
			rows.append(row)
			print("MECH lms ", JSON.stringify(row))
			var expected: float = maxf(before, minf(before + 65.0, 150.0))
			_check(absf(float(actor.hp) - expected) < 0.01 and absf(float(actor.max_hp) - maxf(expected, 150.0)) < 0.01, "LMS " + name + " (" + start + ") : %.0f / %.0f PV attendus, mesuré %.0f / %.0f" % [expected, maxf(expected, 150.0), actor.hp, actor.max_hp])
	_summary["lms"] = rows
	var bleuette: PaperActor = _by("Bleuette")
	bleuette.effects["aura_charge"] = 100.0
	world.combat._unlock_lms(bleuette)
	bleuette.cooldowns[3] = 0.0
	var before_courage: Array = [bleuette.hp, bleuette.max_hp]
	var used: bool = world.combat.use(bleuette, 3)
	var courage: Dictionary = {"used": used, "before": before_courage, "after": [bleuette.hp, bleuette.max_hp], "lms_hp_cap": bleuette.effects.get("lms_hp_cap", 0.0)}
	if _is_local(bleuette):
		await _wait(0.6)
		await _shot("bleuette_courage_full")
		bleuette.hp = 166.0
		await _wait(0.6)
		await _shot("bleuette_courage_partial")
	print("MECH courage ", JSON.stringify(courage))
	_summary["bleuette_courage"] = courage
	_check(used and float(bleuette.max_hp) > 150.0 and float(bleuette.hp) > 150.0, "Courage de Bleuette : doit dépasser 150 PV, mesuré " + JSON.stringify(courage))
	for name: String in ["Ashura", "Simon", "Elly"]:
		var other: PaperActor = _by(name)
		other.hp = other.max_hp
		world.combat._heal(other, 50.0, other)
		_check(float(other.hp) <= 150.0, name + " ne doit pas dépasser 150 PV en LMS, mesuré %.0f" % other.hp)
	await _test_lms_ceiling()


# Plafond de 150 PV en LMS pour tous sauf Bleuette : soins, prise, QTE d'armure de Lysia, zone d'Elly.
func _test_lms_ceiling() -> void :
	var lysia: PaperActor = _by("Lysia")
	var usayuko: PaperActor = _by("Usayuko")
	var bleuette: PaperActor = _by("Bleuette")
	var rows: Dictionary = {}
	# Lysia entrée en LMS blessée : 40 → 105 / 150, la prise s'arrête à 150.
	_lms_fresh(lysia, 40.0)
	var outlet: Vector3 = world.school.healing_outlets[0]
	_place(lysia, outlet + Vector3(0, 0.08, 0))
	_place(world.killer_actor(), world.school.killer_spawn)
	await _wait(0.4)
	lysia.hp = 130.0
	lysia.cooldowns[3] = 0.0
	var plugged: bool = world.combat.start_outlet_heal(lysia)
	var t0: float = world.clock
	while world.clock - t0 < 15.5 and float(lysia.effects.get("outlet_healing", 0.0)) > 0.0: await get_tree().physics_frame
	rows["lysia_outlet"] = {"plugged": plugged, "hp": lysia.hp, "max_hp": lysia.max_hp, "seconds": snappedf(world.clock - t0, 0.01)}
	_check(plugged and absf(float(lysia.hp) - 150.0) < 0.01 and float(lysia.max_hp) == 150.0, "LMS Lysia : la prise doit s'arrêter à 150 / 150, mesuré " + JSON.stringify(rows["lysia_outlet"]))
	# QTE « + ARMURE » de Lysia en LMS : pas de PV max au-delà de 150, réparation à la place.
	lysia.hp = 120.0
	lysia.effects["lms_qte_ready"] = true
	lysia.effects["lms_qte_expires"] = world.clock + 5.0
	lysia.effects["lms_buff_unlocked"] = true
	world.combat.assist(-1, lysia.id, "health")
	rows["lysia_qte"] = {"hp": lysia.hp, "max_hp": lysia.max_hp}
	_check(float(lysia.max_hp) <= 150.0 and float(lysia.hp) > 120.0 and float(lysia.hp) <= 150.0, "LMS Lysia QTE + ARMURE : max 150, réparation, mesuré " + JSON.stringify(rows["lysia_qte"]))
	# Lysia entrée en LMS au-dessus de 150 : garde 200, mais ne regagne pas ce qu'elle perd au-delà de 150.
	_lms_fresh(lysia, 200.0)
	var entered: Array = [lysia.hp, lysia.max_hp]
	lysia.hp = 170.0
	world.combat._heal(lysia, 7.0, lysia)
	var after_hit: float = lysia.hp
	var ready_above: bool = bool(world.combat.outlet_preview(lysia).get("ready", false))
	if _is_local(lysia):
		await _wait(0.6)
		await _shot("lysia_lms_170")
	lysia.hp = 120.0
	world.combat._heal(lysia, 50.0, lysia)
	if _is_local(lysia):
		await _wait(0.6)
		await _shot("lysia_lms_150_capped")
	rows["lysia_above"] = {"entered": entered, "healed_at_170": after_hit, "outlet_ready_at_170": ready_above, "healed_from_120": lysia.hp}
	_check(float(entered[0]) == 200.0 and after_hit == 170.0 and not ready_above and absf(float(lysia.hp) - 150.0) < 0.01, "LMS Lysia entrée à 200 : garde 200, jamais de soin au-delà de 150, mesuré " + JSON.stringify(rows["lysia_above"]))
	# Usayuko entrée pleine (165) : la zone de soin d'Elly ne la remonte pas au-delà de 150.
	_lms_fresh(usayuko, 165.0)
	usayuko.hp = 140.0
	var elly: PaperActor = _by("Elly")
	_place(usayuko, world.school.spawn_points[3])
	await _wait(0.3)
	world.zones.append({"position": usayuko.position, "radius": 5.0, "left": 7.0, "owner": elly.id})
	await _wait(7.2)
	rows["usayuko_zone"] = {"hp": usayuko.hp, "max_hp": usayuko.max_hp}
	_check(absf(float(usayuko.hp) - 150.0) < 0.01, "LMS Usayuko : zone de soin plafonnée à 150, mesuré " + JSON.stringify(rows["usayuko_zone"]))
	# Bleuette après le courage : son chocolat la soigne au-delà de 150.
	_lms_fresh(bleuette, 40.0)
	bleuette.effects["aura_charge"] = 100.0
	world.combat._unlock_lms(bleuette)
	world.combat.use(bleuette, 3)
	bleuette.hp = 150.0
	world.combat._heal(bleuette, 20.0, bleuette)
	rows["bleuette_heal"] = {"hp": bleuette.hp, "max_hp": bleuette.max_hp}
	_check(float(bleuette.max_hp) == 180.0 and float(bleuette.hp) == 170.0, "LMS Bleuette : soin au-delà de 150 après le courage, mesuré " + JSON.stringify(rows["bleuette_heal"]))
	print("MECH lms_ceiling ", JSON.stringify(rows))
	_summary["lms_ceiling"] = rows


func _lms_fresh(actor: PaperActor, hp: float) -> void :
	_reset(actor)
	actor.lms = false
	actor.effects["lms_applied"] = false
	actor.effects["lms_buff_unlocked"] = false
	actor.effects["aura_used"] = false
	actor.effects.erase("lms_hp_cap")
	actor.max_hp = float(PaperData.STATS[actor.character][0])
	actor.hp = minf(hp, actor.max_hp)
	world.combat.apply_lms(actor)




func _wants(test_name: String) -> bool:
	return _only.is_empty() or _only.has(test_name)


func _by(character_name: String) -> PaperActor:
	for actor: PaperActor in world.actors.values():
		if actor.character == character_name: return actor
	return null


func _is_local(actor: PaperActor) -> bool:
	return actor != null and actor == world.local_actor()


func _rendering() -> bool:
	return DisplayServer.get_name() != "headless"


func _reset(actor: PaperActor) -> void :
	if actor == null: return
	for key: String in ["stun", "root", "stun_immunity", "overheat_time", "overheat_hold", "overheat_charge", "slow_time", "boost_time", "speed_boost", "xray", "attack_lock", "forced_time", "recover", "revive_invuln"]:
		actor.effects[key] = 0.0
	actor.effects["overheat_target"] = -1
	actor.effects["drone_bonus"] = false;actor.effects["next_stun"] = 0.0;actor.effects["sprint_bonus"] = 0.0;actor.effects["cooldown_discount"] = 0.0;actor.effects["next_heal"] = 1.0
	world.combat._stop_outlet(actor, "cancelled")
	for slot: int in range(6): actor.cooldowns[slot] = 0.0
	actor.move_input = Vector3.ZERO
	actor.velocity = Vector3.ZERO


func _place(actor: PaperActor, at: Vector3) -> void :
	actor.global_position = at
	actor.velocity = Vector3.ZERO
	actor.net_position = at
	actor.reset_physics_interpolation()
	if actor == world.local_actor(): world.camera_anchor_ready = false


func _face(actor: PaperActor, point: Vector3) -> void :
	var direction: Vector3 = Vector3(point.x - actor.global_position.x, 0, point.z - actor.global_position.z).normalized()
	if direction.length_squared() < 0.01: return
	actor.aim = direction
	if actor == world.local_actor(): world.yaw = atan2( - direction.x, - direction.z)


func _look(from: Vector3, point: Vector3, pitch: float) -> void :
	var direction: Vector3 = Vector3(point.x - from.x, 0, point.z - from.z).normalized()
	world.yaw = atan2( - direction.x, - direction.z)
	world.pitch = pitch
	world.camera_anchor_ready = false


func _free_offset(base: Vector3, distance: float, directions: Array = []) -> Vector3:
	var tries: Array = directions if not directions.is_empty() else [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT, Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(-1, 0, -1)]
	for direction: Vector3 in tries:
		var point: Vector3 = base + direction.normalized() * distance
		if world.school.can_walk(point) and world.visible(base, point): return point
	return base + Vector3.FORWARD * distance


func _wait(seconds: float) -> void :
	var end: float = world.clock + seconds
	while world.clock < end: await get_tree().physics_frame


func _frames(count: int) -> void :
	for i: int in range(count): await get_tree().physics_frame


func _shot(label: String) -> void :
	if _shots.is_empty() or not _rendering(): return
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var path: String = _shots.path_join(label + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("MECH_SHOT ", path)


func _check(ok: bool, message: String) -> void :
	if not ok: _failures.append(message)
	print("MECH_CHECK ", "OK " if ok else "FAIL ", message)
