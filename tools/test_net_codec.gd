extends Node

# Aller-retour du format d'instantané 0.17 (net_codec.gd) sur une vraie partie simulée à 7 acteurs.
#   godot --headless -- --simulate Simon --duration 40 --tool test_net_codec
# Toutes les 0,5 s : encode, décode, compare chaque champ, et mesure la taille contre l'ancien
# format (tableau de Variant + deflate + arguments d'appel). Affiche NET_CODEC PASS/FAIL.

var world: Node
var clock: float = 0.0
var next: float = 3.0
var checks: int = 0
var failures: Array[String] = []
var new_sizes: Array[int] = []
var old_sizes: Array[int] = []
var report_sizes: Array[int] = []


func setup(owner: Node) -> void :
	world = owner


func _fail(text: String) -> void :
	if failures.size() < 12: failures.append(text)


func _process(delta: float) -> void :
	if world == null or str(world.phase) != "playing": return
	clock += delta
	if clock < next: return
	next = clock + 0.5
	_round_trip()
	if clock > 30.0 and not failures.is_empty() or clock > 34.0: _finish()


func _old_size() -> int:
	var rows: Array = []
	for key: Variant in world.actors: rows.append(world.actors[key].pack_motion())
	var raw: PackedByteArray = var_to_bytes(rows)
	var packed: PackedByteArray = raw.compress(FileAccess.COMPRESSION_DEFLATE)
	return var_to_bytes([packed, raw.size(), world.clock, world.time_left, world.phase, world.lms, world.blocked_door, world.round_serial]).size()


func _round_trip() -> void :
	var packed: PackedByteArray = PaperNetCodec.encode_snapshot(world)
	new_sizes.append(packed.size())
	old_sizes.append(_old_size())
	var data: Dictionary = PaperNetCodec.decode_snapshot(packed)
	checks += 1
	if data.is_empty(): _fail("décodage vide");return
	if absf(float(data.t) - float(world.clock)) > 0.000001: _fail("horloge")
	if str(data.phase) != str(world.phase) or int(data.serial) != int(world.round_serial) or int(data.door) != int(world.blocked_door): _fail("en-tête")
	if (data.rows as Array).size() != world.actors.size(): _fail("nombre de lignes");return
	for row: Dictionary in data.rows:
		var a: PaperActor = world.actors.get(int(row.id))
		if a == null: _fail("acteur inconnu %d" % int(row.id));continue
		if Vector3(row.pos).distance_to(a.global_position) > 0.0001: _fail("position %s" % a.character)
		if Vector3(row.vel).distance_to(a.velocity) > 0.01: _fail("vitesse %s" % a.character)
		var aim: Vector3 = a.aim.normalized() if a.aim.length_squared() > 0.000001 else Vector3.FORWARD
		if Vector3(row.aim).distance_to(aim) > 0.001: _fail("visée %s" % a.character)
		if absf(float(row.hp) - a.hp) > 0.001 or absf(float(row.max_hp) - a.max_hp) > 0.001: _fail("vie %s" % a.character)
		if absf(float(row.stamina) - a.stamina) > 0.001: _fail("endurance %s" % a.character)
		if ((int(row.flags) & PaperNetCodec.ROW_ALIVE) != 0) != a.alive: _fail("vivant %s" % a.character)
		for slot: int in range(6):
			if absf(float(row.cooldowns[slot]) - float(a.cooldowns.get(slot, 0.0))) > 0.011: _fail("recharge %d %s" % [slot, a.character])
		var fx: Dictionary = a.network_effects()
		var got: Dictionary = row.effects
		if fx.size() != got.size(): _fail("effets %s : %d au lieu de %d" % [a.character, got.size(), fx.size()])
		for key: Variant in fx:
			if not got.has(str(key)): _fail("effet manquant %s.%s" % [a.character, key]);continue
			var want: Variant = fx[key]
			var have: Variant = got[str(key)]
			if want is float and absf(float(have) - want) > maxf(0.0001, absf(want) * 0.000001): _fail("effet %s.%s %s≠%s" % [a.character, key, have, want])
			elif want is Vector3 and Vector3(have).distance_to(want) > 0.0001: _fail("effet %s.%s" % [a.character, key])
			elif (want is bool or want is int or want is String) and str(have) != str(want): _fail("effet %s.%s %s≠%s" % [a.character, key, have, want])
	# Message du client : aller-retour.
	var me: PaperActor = world.local_actor()
	if me != null:
		var bytes: PackedByteArray = PaperNetCodec.encode_report(513, 7, 7, 12.5, 11.75, me.global_position, me.velocity, Vector3(0.5, 0, -0.5), me.aim, 3, 4)
		report_sizes.append(bytes.size())
		var r: Dictionary = PaperNetCodec.decode_report(bytes)
		if r.is_empty() or int(r.seq) != 513 or int(r.epoch) != 7 or not bool(r.has_position) or Vector3(r.pos).distance_to(me.global_position) > 0.0001 or int(r.jumps) != 3 or int(r.rolls) != 4: _fail("message client")


func _finish() -> void :
	set_process(false)
	var mean_new: float = 0.0
	var mean_old: float = 0.0
	for v: int in new_sizes: mean_new += v
	for v: int in old_sizes: mean_old += v
	mean_new /= maxf(1.0, new_sizes.size());mean_old /= maxf(1.0, old_sizes.size())
	new_sizes.sort();old_sizes.sort()
	print("NET_CODEC acteurs=%d instantanés=%d · ancien format moy %.0f o (max %d) à 20/s = %.0f o/s · nouveau moy %.0f o (max %d) à 30/s = %.0f o/s · message client %d o" % [world.actors.size(), checks, mean_old, old_sizes[-1], mean_old * 20.0, mean_new, new_sizes[-1], mean_new * 30.0, report_sizes[0] if not report_sizes.is_empty() else 0])
	print("NET_CODEC ", "PASS" if failures.is_empty() else "FAIL", " checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
