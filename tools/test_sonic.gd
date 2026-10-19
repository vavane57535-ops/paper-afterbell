extends Node

# Sonde du lot « simon » (0.17) : mesures de la course éclair « Sonic » et des portages, sans rendu.
#   godot --headless -- --tool test_sonic [--sonic-plan boost|relay|stop|carry] [--sonic-ally Bleuette] [--sonic-csv FICHIER]
# Mesures par image (repère du sol de Simon : x droite, y haut, z arrière) :
#   buste (bassin → cou, ° depuis la verticale, + = penché en avant), bassin, regard (élévation de l'axe avant
#   de la tête), bras (main - épaule en longueurs de bras), coudes, genoux (flexion, et genou devant la ligne
#   hanche → cheville dans le repère du bassin), glissement des pieds au sol (m/s).
# Rendu (planches serrées) : avec xvfb-run et --rendering-driver opengl3, ajouter --sonic-out DIR [--sonic-views side,back]
#   [--sonic-step 0.0333] [--sonic-cell 400x360] [--sonic-from 1.2] [--sonic-count 12].

const DT: float = 1.0 / 60.0
const SIMON_ID: int = 1
const ALLY_ID: int = 2

var plan_name: String = "boost"
var ally: String = "Bleuette"
var csv_path: String = ""
var out_dir: String = ""
var views: Array[String] = ["side"]
var step: float = 1.0 / 30.0
var cell: Vector2i = Vector2i(400, 360)
var shot_from: float = 1.2
var shot_count: int = 12
var zoom: float = 1.0
var columns: int = 6
var measure_ally: bool = false
var joints_at: float = -1.0

var stage: Node3D
var viewport: SubViewport
var camera: Camera3D
var sun: DirectionalLight3D
var hosts: Dictionary = {}


func setup(_world: Node) -> void :
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in range(args.size()):
		var next: String = args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--sonic-plan": plan_name = next
			"--sonic-ally": ally = next
			"--sonic-csv": csv_path = next
			"--sonic-out": out_dir = next
			"--sonic-views": views.assign(Array(next.split(",", false)))
			"--sonic-step": step = maxf(DT, float(next))
			"--sonic-cell":
				var size: PackedStringArray = next.split("x")
				cell = Vector2i(int(size[0]), int(size[1]))
			"--sonic-from": shot_from = float(next)
			"--sonic-count": shot_count = int(next)
			"--sonic-zoom": zoom = float(next)
			"--sonic-cols": columns = int(next)
			"--sonic-measure-ally": measure_ally = true
			"--sonic-joints": joints_at = float(next)
	_run.call_deferred()


func _rendering() -> bool:
	return not out_dir.is_empty() and DisplayServer.get_name() != "headless"


func _run() -> void :
	_build_stage()
	await get_tree().process_frame
	if _rendering():
		DirAccess.make_dir_recursive_absolute(out_dir)
		await _play("all")
	else:
		await _play("")
	print("SONIC_DONE")
	get_tree().quit()


# Plans : segments [durée, vitesse, état] ; « carry » = Simon en boost attrape l'allié (placé sur sa route).
func _plan() -> Array:
	match plan_name:
		"relay":
			return [[1.0, 10.2, {"sprinting": true}], [2.0, 20.4, {"sprinting": true, "speed_boost": 4.0}], [1.0, 10.2, {"sprinting": true}], [0.8, 0.0, {}]]
		"stop":
			return [[0.6, 10.2, {"sprinting": true}], [1.6, 20.4, {"sprinting": true, "speed_boost": 4.0}], [1.2, 0.0, {"speed_boost": 4.0}]]
		"idle":
			return [[1.0, 0.0, {}]]
		"start":
			return [[0.4, 0.0, {}], [1.4, 0.0, {"boost_charging": true, "charge": true}], [1.2, 20.4, {"sprinting": true, "speed_boost": 4.0}]]
		"carry":
			return [[0.5, 20.4, {"sprinting": true, "speed_boost": 6.0}], [4.0, 20.4, {"sprinting": true, "speed_boost": 6.0, "carry": true}], [0.6, 20.4, {"sprinting": true, "speed_boost": 6.0}], [1.0, 0.0, {"speed_boost": 6.0}]]
	return [[0.8, 10.2, {"sprinting": true}], [2.4, 20.4, {"sprinting": true, "speed_boost": 4.0}]]


func _play(view: String) -> void :
	var simon: PaperVisual = _spawn(SIMON_ID, "Simon", Vector3.ZERO)
	print("RIG base=%.3f reach=%.3f scale=%.3f hip_rest=%s foot_rest=%s leg=%s arm=%s" % [simon.get("_base_height"), simon.get("_leg_reach"), simon.get("_model_scale"), simon.get("_hip_rest"), simon.get("_foot_rest"), simon.get("_leg_length"), simon.get("_arm_length")])
	var mate: PaperVisual = null
	var simon_host: Node3D = hosts[SIMON_ID]
	var mate_host: Node3D = null
	var plan: Array = _plan()
	var carry_plan: bool = plan_name == "carry"
	var factor: float = 0.85 if ally == "Usayuko" else 1.0
	var desired: Vector3 = Vector3.ZERO
	if carry_plan:
		# L'allié attend sur la route de Simon, à l'endroit où commence le segment « carry ».
		var meet: float = - float(plan[0][1]) * float(plan[0][0])
		mate = _spawn(ALLY_ID, ally, Vector3(-0.7, 0.0, meet - 0.6))
		mate_host = hosts[ALLY_ID]
		mate.rotation.y = 0.0
		print("RIG %s base=%.3f reach=%.3f scale=%.3f arm=%s" % [ally, mate.get("_base_height"), mate.get("_leg_reach"), mate.get("_model_scale"), mate.get("_arm_length")])
		desired = (load("res://carry_rig.gd") as GDScript).call("desired_offset", ally)
	var rows: Array = []
	var shots: Dictionary = {}
	for name: String in views: shots[name] = [] as Array[Image]
	var clock: float = 0.0
	var next_shot: float = shot_from
	var speed: float = 0.0
	var prev_feet: Dictionary = {}
	for segment: Array in plan:
		var elapsed: float = 0.0
		while elapsed < float(segment[0]) - 0.0001:
			var state: Dictionary = {"grounded": true, "vertical_speed": 0.0, "ruleset_om": true}
			var extra: Dictionary = segment[2]
			for key: String in extra:
				if key != "carry" and key != "charge": state[key] = extra[key]
			if bool(extra.get("charge", false)):
				state["charging_boost"] = elapsed + 0.001
				state["boost_charge"] = elapsed
			var carrying: bool = bool(extra.get("carry", false))
			var goal_speed: float = float(segment[1]) * (factor if carrying else 1.0)
			speed = move_toward(speed, goal_speed, DT * 2000.0)
			var velocity: Vector3 = Vector3(0.0, 0.0, - speed)
			if carrying:
				state["carrying_id"] = ALLY_ID
				state["carry_speed_factor"] = factor
			simon_host.position += velocity * DT
			simon.set_combat_state(state)
			simon.animate(DT, velocity, false, false)
			if mate != null:
				var mate_state: Dictionary = {"grounded": true, "vertical_speed": 0.0, "ruleset_om": true}
				var mate_velocity: Vector3 = Vector3.ZERO
				if carrying:
					mate_state["carried_by"] = SIMON_ID
					var goal: Vector3 = simon_host.position + simon.global_basis.orthonormalized() * desired
					mate_velocity = (goal - mate_host.position) / DT
					mate_host.position = goal
				mate.set_combat_state(mate_state)
				mate.animate(DT, mate_velocity, false, false)
				if carrying: mate.carry_finalize()
			clock += DT
			elapsed += DT
			rows.append(_measure(mate if measure_ally and mate != null else simon, clock, speed, prev_feet))
			if joints_at > 0.0 and absf(clock - joints_at) < DT * 0.5:
				_print_joints("Simon", simon, simon)
				if mate != null:
					_print_joints(ally, mate, simon)
					_print_contacts(simon, mate)
			if view != "" and clock + 0.0001 >= next_shot and (shots[views[0]] as Array).size() < shot_count:
				next_shot += step
				var focus: Vector3 = (simon.get("_body") as Node3D).global_position
				if mate != null and (carrying or bool(mate.get("_carry_pinned"))): focus = (focus + (mate.get("_body") as Node3D).global_position) * 0.5
				for name: String in views:
					_frame(focus, name)
					(shots[name] as Array).append(await _snap())
	_report(rows)
	if view != "":
		for name: String in views:
			var list: Array[Image] = []
			list.assign(shots[name])
			if not list.is_empty(): _save_sheet("%s_%s%s" % [plan_name, ("%s_" % ally.to_lower()) if carry_plan else "", name], list)
	_clear()


func _measure(v: PaperVisual, clock: float, speed: float, prev_feet: Dictionary) -> Dictionary:
	var root: Transform3D = Transform3D(v.global_basis.orthonormalized(), v.global_position)
	var inv: Transform3D = root.affine_inverse()
	var body: Node3D = v.get("_body")
	var chest: Node3D = v.get("_chest")
	var neck: Node3D = v.get("_neck")
	var head: Node3D = v.get("_head")
	var p_body: Vector3 = inv * body.global_position
	var p_neck: Vector3 = inv * neck.global_position
	var p_chest: Vector3 = inv * chest.global_position
	var torso: Vector3 = p_neck - p_body
	var upper: Vector3 = p_neck - p_chest
	var row: Dictionary = {"t": clock, "speed": speed}
	row["torso"] = rad_to_deg(atan2( - torso.z, torso.y))
	row["upper"] = rad_to_deg(atan2( - upper.z, upper.y))
	var body_fwd: Vector3 = (inv.basis * (body.global_basis.orthonormalized() * Vector3.FORWARD)).normalized()
	row["pelvis"] = rad_to_deg(asin(clampf( - body_fwd.y, -1.0, 1.0)))
	var head_fwd: Vector3 = (inv.basis * (head.global_basis.orthonormalized() * Vector3.FORWARD)).normalized()
	row["look"] = rad_to_deg(asin(clampf(head_fwd.y, -1.0, 1.0)))
	row["hip_y"] = p_body.y
	for side: int in [-1, 1]:
		var tag: String = "l" if side < 0 else "r"
		var arm: Node3D = v.get("_left_arm" if side < 0 else "_right_arm")
		var elbow: Node3D = v.get("_left_elbow" if side < 0 else "_right_elbow")
		var hand: Node3D = v.get("_left_hand" if side < 0 else "_right_hand")
		var s: Vector3 = inv * arm.global_position
		var e: Vector3 = inv * elbow.global_position
		var h: Vector3 = inv * hand.global_position
		var arm_len: float = (e - s).length() + (h - e).length()
		var reach: Vector3 = (h - s) / maxf(arm_len, 0.001)
		row["arm_" + tag] = Vector3(reach.x * float(side), reach.y, reach.z)
		row["elb_" + tag] = 180.0 - rad_to_deg((s - e).angle_to(h - e))
		row["hand_" + tag] = h
		var leg: Node3D = v.get("_left_leg" if side < 0 else "_right_leg")
		var knee: Node3D = v.get("_left_knee" if side < 0 else "_right_knee")
		var ankle: Node3D = (v.get("_ankles") as Dictionary)[side]
		var hip_w: Vector3 = leg.global_position
		var knee_w: Vector3 = knee.global_position
		var ankle_w: Vector3 = ankle.global_position
		row["knee_" + tag] = 180.0 - rad_to_deg((hip_w - knee_w).angle_to(ankle_w - knee_w))
		var line: Vector3 = (ankle_w - hip_w).normalized()
		var off: Vector3 = (knee_w - hip_w) - line * (knee_w - hip_w).dot(line)
		var pelvis_fwd: Vector3 = body.global_basis.orthonormalized() * Vector3.FORWARD
		row["kfwd_" + tag] = off.dot(pelvis_fwd)
		# Sens de flexion : le tibia doit tourner vers l'arrière du bassin par rapport à la cuisse.
		var pelvis_right: Vector3 = body.global_basis.orthonormalized() * Vector3.RIGHT
		row["kbend_" + tag] = (knee_w - hip_w).normalized().cross((ankle_w - knee_w).normalized()).dot(pelvis_right)
		var thigh: Vector3 = inv.basis * (knee_w - hip_w)
		row["thigh_" + tag] = rad_to_deg(atan2( - thigh.z, - thigh.y))
		var ground_y: float = v.global_position.y
		var foot_y: float = ankle_w.y - ground_y
		row["foot_" + tag] = foot_y
		# Appui d'après la phase de foulée : le pied ne doit pas glisser tant qu'il reste posé.
		var phase: float = float(v.get("_gait_phase"))
		var p: float = phase if side < 0 else fposmod(phase + 0.5, 1.0)
		var planted: bool = p < float(v.get("_g_stance")) and float(v.get("_g_move")) > 0.9
		# Glissement mesuré à la pointe du pied (le talon se lève en fin d'appui, la pointe reste posée).
		var toe_w: Vector3 = ((v.get("_toes") as Dictionary)[side] as Node3D).global_position
		if prev_feet.has(tag) and planted and bool(prev_feet.get(tag + "_planted", false)):
			var before: Vector3 = prev_feet[tag]
			row["slip_" + tag] = Vector2(toe_w.x - before.x, toe_w.z - before.z).length() / DT
		prev_feet[tag] = toe_w
		prev_feet[tag + "_planted"] = planted
	return row


# Articulations (mètres) dans le repère du sol de Simon : x à droite, y en haut, z vers l'arrière.
func _print_joints(label: String, visual: PaperVisual, simon: PaperVisual) -> void :
	var frame: Transform3D = Transform3D(simon.global_basis.orthonormalized(), simon.global_position).affine_inverse()
	var line: String = "JOINTS %-8s" % label
	for key: String in ["_body", "_chest", "_neck", "_head", "_left_arm", "_right_arm", "_left_elbow", "_right_elbow", "_left_hand", "_right_hand", "_left_leg", "_right_leg", "_left_knee", "_right_knee"]:
		var p: Vector3 = frame * (visual.get(key) as Node3D).global_position
		line += " %s=(%.2f,%.2f,%.2f)" % [key.trim_prefix("_"), p.x, p.y, p.z]
	for side: int in [-1, 1]:
		var p: Vector3 = frame * ((visual.get("_ankles") as Dictionary)[side] as Node3D).global_position
		line += " ankle%s=(%.2f,%.2f,%.2f)" % ["L" if side < 0 else "R", p.x, p.y, p.z]
	line += " curl=%.2f/%.2f" % [float(visual.get("_curl")), float(visual.get("_curl_left"))]
	print(line)


# Contacts du montage : écart main → point tenu (cm), et volumes du corps qui se traversent.
const BODY_SPHERES: Dictionary = {"_head": 0.15, "_chest": 0.15, "_body": 0.14, "_left_knee": 0.08, "_right_knee": 0.08, "_left_elbow": 0.06, "_right_elbow": 0.06}

func _print_contacts(simon: PaperVisual, mate: PaperVisual) -> void :
	var rig: Dictionary = (load("res://carry_rig.gd") as GDScript).call("variant", ally)
	var line: String = "CONTACTS"
	for contact: Dictionary in rig.get("contacts", []):
		var holder: PaperVisual = mate if str(contact.who) == "carried" else simon
		var held: PaperVisual = simon if holder == mate else mate
		var target: Vector3 = held.call("_carry_point", str(contact.node), contact.at)
		var palm: Vector3 = holder.call("_carry_point", "palm_" + str(contact.hand), Vector3.ZERO)
		line += " %s.%s->%s=%.1fcm" % [contact.who, contact.hand, contact.node, palm.distance_to(target) * 100.0]
	print(line)
	var hits: String = "OVERLAP"
	for a: String in BODY_SPHERES:
		for b: String in BODY_SPHERES:
			var pa: Vector3 = (simon.get(a) as Node3D).global_position
			var pb: Vector3 = (mate.get(b) as Node3D).global_position
			var gap: float = pa.distance_to(pb) - float(BODY_SPHERES[a]) - float(BODY_SPHERES[b])
			if gap < 0.0: hits += " simon%s/%s%s=%.0fcm" % [a, ally.to_lower(), b, gap * 100.0]
	print(hits)


func _report(rows: Array) -> void :
	if rows.is_empty(): return
	if not csv_path.is_empty():
		var file: FileAccess = FileAccess.open(csv_path, FileAccess.WRITE)
		if file != null:
			file.store_line("t,speed,torso,upper,pelvis,look,hip_y,arm_l_x,arm_l_y,arm_l_z,arm_r_x,arm_r_y,arm_r_z,elb_l,elb_r,knee_l,knee_r,kfwd_l,kfwd_r,thigh_l,thigh_r,foot_l,foot_r")
			for row: Dictionary in rows:
				var al: Vector3 = row.arm_l
				var ar: Vector3 = row.arm_r
				file.store_line("%.3f,%.1f,%.1f,%.1f,%.1f,%.1f,%.3f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.0f,%.0f,%.0f,%.0f,%.3f,%.3f,%.0f,%.0f,%.3f,%.3f" % [row.t, row.speed, row.torso, row.upper, row.pelvis, row.look, row.hip_y,
					al.x, al.y, al.z, ar.x, ar.y, ar.z, row.elb_l, row.elb_r, row.knee_l, row.knee_r, row.kfwd_l, row.kfwd_r, row.thigh_l, row.thigh_r, row.foot_l, row.foot_r])
	# Résumé par tranches de 0,5 s.
	var start: float = 0.0
	while start < float(rows[-1].t):
		var chunk: Array = rows.filter( func(r: Dictionary) -> bool: return float(r.t) > start and float(r.t) <= start + 0.5)
		start += 0.5
		if chunk.is_empty(): continue
		var line: String = "SONIC t=%4.1f v=%4.1f" % [float(chunk[-1].t), float(chunk[-1].speed)]
		for key: String in ["torso", "upper", "pelvis", "look", "hip_y", "elb_l", "elb_r", "knee_l", "knee_r", "thigh_l", "thigh_r"]:
			var lo: float = INF
			var hi: float = - INF
			for r: Dictionary in chunk:
				lo = minf(lo, float(r[key]))
				hi = maxf(hi, float(r[key]))
			line += (" %s=%.2f..%.2f" if key == "hip_y" else " %s=%.0f..%.0f") % [key, lo, hi]
		var kmin: float = - INF
		var slip: float = 0.0
		var arm_l: Vector3 = Vector3.ZERO
		var arm_r: Vector3 = Vector3.ZERO
		for r: Dictionary in chunk:
			kmin = maxf(kmin, maxf(float(r.kbend_l), float(r.kbend_r)))
			slip = maxf(slip, maxf(float(r.get("slip_l", 0.0)), float(r.get("slip_r", 0.0))))
			arm_l += r.arm_l
			arm_r += r.arm_r
		arm_l /= chunk.size()
		arm_r /= chunk.size()
		line += " kbend_max=%.3f slip=%.2f armL=(%.2f,%.2f,%.2f) armR=(%.2f,%.2f,%.2f)" % [kmin, slip, arm_l.x, arm_l.y, arm_l.z, arm_r.x, arm_r.y, arm_r.z]
		print(line)


func _frame(at: Vector3, view: String) -> void :
	var focus: Vector3 = Vector3(at.x, (hosts[SIMON_ID] as Node3D).position.y + 0.75, at.z)
	var offset: Vector3 = Vector3(3.0, 0.15, 0.0)
	match view:
		"left": offset = Vector3(-3.0, 0.15, 0.0)
		"three": offset = Vector3(2.2, 0.7, -2.1)
		"back": offset = Vector3(0.6, 1.1, 3.1)
		"front": offset = Vector3(0.4, 0.4, -3.2)
		"top": offset = Vector3(0.3, 3.6, 0.4)
		# Gros plan sur les mains et le bassin (trois quarts arrière, côté droit).
		"close": offset = Vector3(1.25, 0.3, 0.95)
		"closeleft": offset = Vector3(-1.25, 0.3, 0.95)
	camera.fov = 34.0
	camera.position = focus + offset * zoom
	camera.look_at(focus)
	if view == "game":
		# Caméra de jeu (core_camera_rig.gd) : perche de 4,6 m derrière la tête, tangage par défaut -0,16 rad.
		# Même point de vue, cadré serré sur le perso (le jeu le montre plus petit, en grand angle).
		var root: Vector3 = (hosts[SIMON_ID] as Node3D).position
		var look: Vector3 = Vector3(0.0, sin(-0.16), - cos(-0.16))
		var pivot: Vector3 = Vector3(at.x, root.y + 2.0, at.z) + Vector3(0.3, 0.0, 0.0)
		camera.fov = 30.0
		camera.position = pivot - look * 4.6
		camera.look_at(Vector3(at.x, root.y + 0.7, at.z))
	sun.rotation = Vector3(deg_to_rad(-48.0), deg_to_rad(120.0 if view != "back" and view != "game" else 30.0), 0.0)


func _snap() -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


func _save_sheet(name: String, shots: Array[Image]) -> void :
	var rows_count: int = int(ceil(float(shots.size()) / float(columns)))
	var sheet: Image = Image.create(cell.x * columns, cell.y * rows_count, false, shots[0].get_format())
	for k in range(shots.size()):
		sheet.blit_rect(shots[k], Rect2i(Vector2i.ZERO, cell), Vector2i((k % columns) * cell.x, (k / columns) * cell.y))
	var path: String = "%s/%s.png" % [out_dir, name]
	sheet.save_png(path)
	print("CAPTURE ", path)


func _build_stage() -> void :
	stage = Node3D.new()
	stage.name = "Stage"
	# Rendu exact de la pose calculée (pas d'interpolation physique entre deux pas).
	stage.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if _rendering():
		get_viewport().disable_3d = true
		viewport = SubViewport.new()
		viewport.size = cell
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.msaa_3d = Viewport.MSAA_2X
		add_child(viewport)
		viewport.add_child(stage)
		var env: Environment = Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.36, 0.4, 0.46)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.75, 0.75, 0.8)
		env.ambient_light_energy = 0.45
		var we: WorldEnvironment = WorldEnvironment.new()
		we.environment = env
		stage.add_child(we)
		sun = DirectionalLight3D.new()
		sun.light_energy = 0.9
		sun.shadow_enabled = true
		sun.directional_shadow_max_distance = 25.0
		stage.add_child(sun)
		var floor_mesh: MeshInstance3D = MeshInstance3D.new()
		var plane: PlaneMesh = PlaneMesh.new()
		plane.size = Vector2(400, 400)
		floor_mesh.mesh = plane
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		var img: Image = Image.create(8, 8, false, Image.FORMAT_RGB8)
		for x in range(8):
			for y in range(8):
				img.set_pixel(x, y, Color(0.55, 0.57, 0.6) if (int(x / 4.0) + int(y / 4.0)) % 2 == 0 else Color(0.68, 0.7, 0.73))
		mat.albedo_texture = ImageTexture.create_from_image(img)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		floor_mesh.material_override = mat
		floor_mesh.position.z = -150.0
		stage.add_child(floor_mesh)
		camera = Camera3D.new()
		camera.fov = 34.0
		stage.add_child(camera)
		camera.current = true
	else:
		add_child(stage)


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


func _clear() -> void :
	for host: Node3D in hosts.values():
		stage.remove_child(host)
		host.queue_free()
	hosts.clear()
