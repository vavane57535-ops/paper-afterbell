extends Node

# Contrôle sans rendu des portages de Simon (lot « simon », 0.17) : pour chaque allié, Simon en course éclair passe
# à côté de lui, l'attrape, le porte (ligne droite puis virages), le lâche puis s'arrête. À chaque image :
#   - écart (cm) entre chaque paume qui tient et le point tenu ;
#   - interpénétration (cm) des membres de Simon et de l'allié (capsules : bassin, buste, tête, bras, jambes) ;
#   - pour les variantes au sol, hauteur des pieds de l'allié par rapport au sol.
#   godot --headless -- --tool test_carry_check [--check-ally Ashura,Bleuette] [--check-hold 4.0] [--check-turn 1]
# Lignes « CHECK » : un résumé par tranche de 0,5 s, puis « CHECK_RESULT » par allié (pire contact, pire
# interpénétration hors mains qui tiennent).

const DT: float = 1.0 / 60.0
const SIMON_ID: int = 1
const ALLY_ID: int = 2
const SPEED: float = 20.4

var allies: Array[String] = ["Ashura", "Bleuette", "Elly", "Usayuko"]
var hold: float = 4.2
var turning: bool = true
var verbose: bool = false
var stage: Node3D
var hosts: Dictionary = {}


func setup(_world: Node) -> void :
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in range(args.size()):
		var next: String = args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--check-ally": allies.assign(Array(next.split(",", false)))
			"--check-hold": hold = float(next)
			"--check-turn": turning = next != "0"
			"--check-verbose": verbose = true
	_run.call_deferred()


func _run() -> void :
	stage = Node3D.new()
	stage.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(stage)
	var ground: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(400.0, 1.0, 400.0)
	shape.shape = box
	shape.position.y = -0.5
	ground.add_child(shape)
	stage.add_child(ground)
	await get_tree().physics_frame
	for ally: String in allies: await _check(ally)
	print("CHECK_DONE")
	get_tree().quit()


func _spawn(id: int, person: String, at: Vector3) -> PaperVisual:
	var host: Node3D = Node3D.new()
	host.name = "Actor_%d" % id
	stage.add_child(host)
	host.position = at
	var visual: PaperVisual = PaperVisual.new()
	visual.lod_enabled = false
	host.add_child(visual)
	visual.setup(person)
	hosts[id] = host
	return visual


# Capsules d'un visuel : [nom, a, b, rayon] en coordonnées monde.
func _capsules(v: PaperVisual) -> Array:
	var big: float = 1.15 if v.character_name == "Usayuko" else 1.0
	var list: Array = []
	var body: Vector3 = (v.get("_body") as Node3D).global_position
	var chest: Vector3 = (v.get("_chest") as Node3D).global_position
	var neck: Vector3 = (v.get("_neck") as Node3D).global_position
	var head_node: Node3D = v.get("_head")
	var head: Vector3 = head_node.global_position
	var crown: Vector3 = head_node.global_transform * Vector3(0.0, 0.2, 0.0)
	list.append(["bassin", body, chest, 0.12 * big])
	list.append(["buste", chest, neck, 0.13 * big])
	list.append(["tete", head + (crown - head) * 0.35, crown, 0.12])
	for side: int in [-1, 1]:
		var tag: String = "G" if side < 0 else "D"
		var arm: Vector3 = (v.get("_left_arm" if side < 0 else "_right_arm") as Node3D).global_position
		var elbow: Vector3 = (v.get("_left_elbow" if side < 0 else "_right_elbow") as Node3D).global_position
		var hand: Vector3 = (v.get("_left_hand" if side < 0 else "_right_hand") as Node3D).global_position
		var palm: Vector3 = v.call("_carry_point", "palm_l" if side < 0 else "palm_r", Vector3.ZERO)
		var leg: Vector3 = (v.get("_left_leg" if side < 0 else "_right_leg") as Node3D).global_position
		var knee: Vector3 = (v.get("_left_knee" if side < 0 else "_right_knee") as Node3D).global_position
		var ankle: Vector3 = ((v.get("_ankles") as Dictionary)[side] as Node3D).global_position
		var toe: Vector3 = ((v.get("_toes") as Dictionary)[side] as Node3D).global_position
		list.append(["bras" + tag, arm, elbow, 0.05 * big])
		list.append(["avant-bras" + tag, elbow, hand, 0.045 * big])
		list.append(["main" + tag, hand, palm + (palm - hand) * 0.6, 0.04])
		list.append(["cuisse" + tag, leg, knee, 0.075 * big])
		list.append(["tibia" + tag, knee, ankle, 0.055 * big])
		list.append(["pied" + tag, ankle, toe, 0.05])
	return list


# Distance minimale entre deux segments [p1, q1] et [p2, q2].
static func _segment_gap(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3) -> float:
	var d1: Vector3 = q1 - p1
	var d2: Vector3 = q2 - p2
	var r: Vector3 = p1 - p2
	var a: float = d1.dot(d1)
	var e: float = d2.dot(d2)
	var f: float = d2.dot(r)
	var s: float = 0.0
	var t: float = 0.0
	if a <= 1e-8 and e <= 1e-8: return r.length()
	if a <= 1e-8:
		t = clampf(f / e, 0.0, 1.0)
	else:
		var c: float = d1.dot(r)
		if e <= 1e-8:
			s = clampf( - c / a, 0.0, 1.0)
		else:
			var b: float = d1.dot(d2)
			var denom: float = a * e - b * b
			s = clampf((b * f - c * e) / denom, 0.0, 1.0) if denom > 1e-8 else 0.0
			t = (b * s + f) / e
			if t < 0.0:
				t = 0.0
				s = clampf( - c / a, 0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = clampf((b - c) / a, 0.0, 1.0)
	return ((p1 + d1 * s) - (p2 + d2 * t)).length()


func _check(ally: String) -> void :
	var rig: Dictionary = (load("res://carry_rig.gd") as GDScript).call("variant", ally)
	var simon: PaperVisual = _spawn(SIMON_ID, "Simon", Vector3.ZERO)
	# L'allié attend un peu à gauche de la route de Simon, à 20 m.
	var mate: PaperVisual = _spawn(ALLY_ID, ally, Vector3(-0.9, 0.0, -20.0))
	var simon_host: Node3D = hosts[SIMON_ID]
	var mate_host: Node3D = hosts[ALLY_ID]
	var factor: float = 0.85 if ally == "Usayuko" else 1.0
	var desired: Vector3 = (load("res://carry_rig.gd") as GDScript).call("desired_offset", ally)
	var clock: float = 0.0
	var carry_from: float = -1.0
	var released: float = -1.0
	var heading: float = 0.0
	var rows: Array = []
	var worst_contact: float = 0.0
	var worst_overlap: float = 0.0
	var worst_pair: String = ""
	var worst_at: float = 0.0
	var holders: Dictionary = {}
	for contact: Dictionary in rig.get("contacts", []):
		var who: String = "simon:" if str(contact.who) == "carrier" else "ally:"
		if contact.has("foot"):
			var foot_tag: String = "G" if str(contact.foot) == "l" else "D"
			holders[who + "pied" + foot_tag] = true
			holders[who + "tibia" + foot_tag] = true
			continue
		var tag: String = "G" if str(contact.hand) == "l" else "D"
		holders[who + "main" + tag] = true
		holders[who + "avant-bras" + tag] = true
	if rig.has("aim"):
		holders["ally:mainG"] = true
		holders["ally:mainD"] = true
	while true:
		var simon_state: Dictionary = {"grounded": true, "vertical_speed": 0.0, "ruleset_om": true}
		var mate_state: Dictionary = {"grounded": true, "vertical_speed": 0.0, "ruleset_om": true}
		var speed: float = SPEED
		if carry_from < 0.0 and simon_host.position.distance_to(mate_host.position) < 1.7: carry_from = clock
		var carrying: bool = carry_from >= 0.0 and clock - carry_from < hold
		if carry_from >= 0.0 and not carrying and released < 0.0: released = clock
		if released >= 0.0 and clock - released > 0.8: speed = 0.0
		if released >= 0.0 and clock - released > 1.6: break
		simon_state.merge({"speed_boost": 4.0, "sprinting": speed > 0.0}, true)
		var t_carry: float = clock - carry_from if carry_from >= 0.0 else -1.0
		# Virages : à gauche puis à droite pendant le portage (traîne des variantes au sol).
		if turning and carrying and t_carry > 1.4 and t_carry < 2.4: heading += DT * 1.6
		elif turning and carrying and t_carry > 2.6 and t_carry < 3.4: heading -= DT * 1.8
		if carrying:
			speed *= factor
			simon_state["carrying_id"] = ALLY_ID
			simon_state["carry_speed_factor"] = factor
			mate_state["carried_by"] = SIMON_ID
		var forward: Vector3 = Vector3(- sin(heading), 0.0, - cos(heading))
		var velocity: Vector3 = forward * speed
		simon_host.position += velocity * DT
		simon.set_combat_state(simon_state)
		simon.animate(DT, velocity, false, false)
		var mate_velocity: Vector3 = Vector3.ZERO
		if carrying:
			var goal: Vector3 = simon_host.position + simon.global_basis.orthonormalized() * desired
			mate_velocity = (goal - mate_host.position) / DT
			mate_host.position = goal
		elif released >= 0.0:
			mate_host.position.y = 0.0
		mate.set_combat_state(mate_state)
		mate.animate(DT, mate_velocity, false, false)
		if carrying: mate.carry_finalize()
		clock += DT
		if t_carry < 0.0: continue
		var row: Dictionary = {"t": t_carry, "contact": 0.0, "overlap": 0.0, "pair": "", "foot": 0.0}
		if carrying:
			for contact: Dictionary in rig.get("contacts", []):
				var weight: float = (load("res://carry_rig.gd") as GDScript).call("contact_weight", contact, t_carry)
				if weight < 0.99: continue
				var holder: PaperVisual = mate if str(contact.who) == "carried" else simon
				var held: PaperVisual = simon if holder == mate else mate
				var target: Vector3 = held.call("_carry_point", str(contact.node), contact.at)
				var palm: Vector3 = holder.call("_carry_point", ("ankle_" + str(contact.foot)) if contact.has("foot") else ("palm_" + str(contact.hand)), Vector3.ZERO)
				row.contact = maxf(float(row.contact), palm.distance_to(target) * 100.0)
		var mine: Array = _capsules(simon)
		var theirs: Array = _capsules(mate)
		for a: Array in mine:
			for b: Array in theirs:
				if carrying and (holders.has("simon:" + str(a[0])) or holders.has("ally:" + str(b[0]))): continue
				var gap: float = _segment_gap(a[1], a[2], b[1], b[2]) - float(a[3]) - float(b[3])
				if - gap * 100.0 > float(row.overlap):
					row.overlap = - gap * 100.0
					row.pair = "simon.%s/%s.%s" % [a[0], ally.to_lower(), b[0]]
		if bool(rig.get("ground", false)) and carrying:
			var low: float = INF
			for side: int in [-1, 1]:
				low = minf(low, ((mate.get("_ankles") as Dictionary)[side] as Node3D).global_position.y - mate.global_position.y)
			row.foot = low
		rows.append(row)
		if float(row.contact) > worst_contact: worst_contact = row.contact
		if float(row.overlap) > worst_overlap:
			worst_overlap = row.overlap
			worst_pair = row.pair
			worst_at = t_carry
		if verbose and int(round(t_carry / DT)) % 6 == 0: print("CHECKV %s t=%.2f contact=%.1f overlap=%.1f %s" % [ally, t_carry, row.contact, row.overlap, row.pair])
	var start: float = 0.0
	while start < float(rows[-1].t):
		var chunk: Array = rows.filter( func(r: Dictionary) -> bool: return float(r.t) >= start and float(r.t) < start + 0.5)
		if not chunk.is_empty():
			var c_max: float = 0.0
			var o_max: float = 0.0
			var pair: String = ""
			var foot_lo: float = INF
			var foot_hi: float = - INF
			for r: Dictionary in chunk:
				c_max = maxf(c_max, float(r.contact))
				if float(r.overlap) > o_max:
					o_max = r.overlap
					pair = r.pair
				if float(r.foot) != 0.0:
					foot_lo = minf(foot_lo, float(r.foot))
					foot_hi = maxf(foot_hi, float(r.foot))
			var line: String = "CHECK %-8s t=%4.1f contact_max=%5.1fcm overlap_max=%5.1fcm %s" % [ally, start, c_max, o_max, pair]
			if foot_lo < INF: line += " pieds=%.2f..%.2f" % [foot_lo, foot_hi]
			print(line)
		start += 0.5
	print("CHECK_RESULT %s pire_contact=%.1fcm pire_interpenetration=%.1fcm (%s à t=%.2f)" % [ally, worst_contact, worst_overlap, worst_pair, worst_at])
	for host: Node3D in hosts.values():
		stage.remove_child(host)
		host.queue_free()
	hosts.clear()
	await get_tree().physics_frame
