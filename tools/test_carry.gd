extends Node

# Banc d'essai du lot « simon » (0.17) : course « Sonic » du boost et portages de Simon par allié.
# Rendu (planches serrées, plusieurs angles) :
#   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 -- --tool test_carry --carry-out DIR
# Options :
#   --carry-mode lineup|run|carry|loop   (défaut : run)
#   --carry-cell 480x400 --carry-grid 4x3 --carry-zoom 0.8   (taille des vignettes, grille, distance caméra)
#   --carry-ally Bleuette               (allié porté en mode carry / loop ; « all » = Ashura, Bleuette, Elly, Usayuko)
#   --carry-views side,three,back,front,top,close
#   --carry-step 0.1                    (pas des vignettes, en secondes)
#   --carry-metrics                     (mesures sans rendu : écart des mains, pieds, genoux ; marche en --headless)
# Les hôtes s'appellent « Actor_<id> » comme dans main.gd : le visuel porté retrouve son porteur de la même façon.

const DT: float = 1.0 / 60.0
const SIMON_ID: int = 1
const ALLY_ID: int = 2
var CELL: Vector2i = Vector2i(320, 300)
var COLUMNS: int = 6
var ROWS: int = 4
var zoom: float = 1.0

var out_dir: String = "user://carry"
var mode: String = "run"
var allies: Array[String] = ["Bleuette"]
var views: Array[String] = ["side", "three"]
var step: float = 0.1
var metrics: bool = false

var viewport: SubViewport
var stage: Node3D
var camera: Camera3D
var sun: DirectionalLight3D
var floor_mesh: MeshInstance3D
var hosts: Dictionary = {}
var visuals: Dictionary = {}


func setup(_world: Node) -> void :
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in range(args.size()):
		var next: String = args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--carry-out": out_dir = next
			"--carry-mode": mode = next
			"--carry-ally": allies.assign(["Ashura", "Bleuette", "Elly", "Usayuko"] if next == "all" else Array(next.split(",", false)))
			"--carry-views": views.assign(Array(next.split(",", false)))
			"--carry-step": step = maxf(0.02, float(next))
			"--carry-metrics": metrics = true
			"--carry-cell":
				var size: PackedStringArray = next.split("x")
				CELL = Vector2i(int(size[0]), int(size[1]))
			"--carry-grid":
				var grid: PackedStringArray = next.split("x")
				COLUMNS = int(grid[0])
				ROWS = int(grid[1])
			"--carry-zoom": zoom = maxf(0.2, float(next))
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _run() -> void :
	_build_stage()
	for i in range(6): await get_tree().process_frame
	match mode:
		"lineup": await _lineup()
		"run":
			for view: String in views:
				await _sequence("start", _plan_start(), view)
				await _sequence("relay", _plan_relay(), view)
		"carry":
			for ally: String in allies:
				for view: String in views:
					await _carry_run(ally, view)
	print("CARRY_DONE")
	get_tree().quit()


const CARRY_START_GAP: float = 1.6
const CARRY_HOLD: float = 3.6

# Simon en course éclair passe près de l'allié, l'attrape, le porte CARRY_HOLD s, le dépose puis s'arrête.
# Comme main.gd : Simon joue son pas avant le porté, puis carry_finalize() pose le porté et recolle les mains.
func _carry_run(ally: String, view: String) -> void :
	var simon: PaperVisual = _spawn(SIMON_ID, "Simon", Vector3.ZERO)
	var mate: PaperVisual = _spawn(ALLY_ID, ally, Vector3(-0.85, 0.0, -9.0))
	var simon_host: Node3D = hosts[SIMON_ID]
	var mate_host: Node3D = hosts[ALLY_ID]
	_frame_camera(simon_host.position, view, true)
	for i in range(4): await RenderingServer.frame_post_draw
	var factor: float = 0.85 if ally == "Usayuko" else 1.0
	var shots: Array[Image] = []
	var clock: float = 0.0
	var next_shot: float = 0.0
	var carry_from: float = -1.0
	var released: float = -1.0
	var desired: Vector3 = (load("res://carry_rig.gd") as GDScript).call("desired_offset", ally)
	while true:
		var simon_state: Dictionary = _base_state()
		var mate_state: Dictionary = _base_state()
		var speed: float = 20.4
		if carry_from < 0.0 and simon_host.position.distance_to(mate_host.position) < CARRY_START_GAP: carry_from = clock
		var carrying: bool = carry_from >= 0.0 and clock - carry_from < CARRY_HOLD
		if carry_from >= 0.0 and not carrying and released < 0.0: released = clock
		if released >= 0.0 and clock - released > 0.7: speed = 0.0
		if released >= 0.0 and clock - released > 1.6: break
		simon_state.merge({"speed_boost": 4.0, "sprinting": speed > 0.0}, true)
		if carrying:
			speed *= factor
			simon_state["carrying_id"] = ALLY_ID
			simon_state["carry_speed_factor"] = factor
			mate_state["carried_by"] = SIMON_ID
		var velocity: Vector3 = Vector3(0.0, 0.0, - speed)
		simon_host.position += velocity * DT
		simon.set_combat_state(simon_state)
		simon.animate(DT, velocity, false, false)
		var mate_velocity: Vector3 = Vector3.ZERO
		if carrying:
			var goal: Vector3 = simon_host.position + simon.global_basis.orthonormalized() * desired
			mate_velocity = (goal - mate_host.position) / DT
			mate_host.position = goal
		mate.set_combat_state(mate_state)
		mate.animate(DT, mate_velocity, false, false)
		if carrying: mate.carry_finalize()
		clock += DT
		if clock + 0.0001 >= next_shot:
			next_shot += step
			_frame_camera(simon_host.position, view, true)
			shots.append(await _snap())
	_save_sheets("carry_%s_%s" % [ally.to_lower(), view], shots)
	_clear()


# Départ en starting-blocks → course éclair → arrêt net (dérapage).
func _plan_start() -> Array:
	return [
		{"time": 0.3, "speed": 0.0, "state": {}},
		{"time": 1.3, "speed": 0.0, "state": {"boost_charging": true}, "charge": true},
		{"time": 1.6, "speed": 20.4, "state": {"speed_boost": 4.0, "sprinting": true}},
		{"time": 0.9, "speed": 0.0, "state": {"speed_boost": 4.0}},
	]


# Sprint normal → boost (encouragement de Bleuette) → fin du boost → sprint → arrêt.
func _plan_relay() -> Array:
	return [
		{"time": 0.9, "speed": 10.2, "state": {"sprinting": true}},
		{"time": 1.4, "speed": 20.4, "state": {"sprinting": true, "boost_time": 3.0}},
		{"time": 0.9, "speed": 10.2, "state": {"sprinting": true}},
		{"time": 0.6, "speed": 0.0, "state": {}},
	]


func _base_state() -> Dictionary:
	return {"grounded": true, "vertical_speed": 0.0, "ruleset_om": true}


# Rejoue un plan (segments de vitesse et d'état) sur Simon seul et assemble une planche par vue.
func _sequence(label: String, plan: Array, view: String) -> void :
	var simon: PaperVisual = _spawn(SIMON_ID, "Simon", Vector3.ZERO)
	var host: Node3D = hosts[SIMON_ID]
	_frame_camera(host.position, view)
	for i in range(4): await RenderingServer.frame_post_draw
	var shots: Array[Image] = []
	var clock: float = 0.0
	var next_shot: float = 0.0
	var speed: float = 0.0
	for segment: Dictionary in plan:
		var elapsed: float = 0.0
		while elapsed < float(segment.time) - 0.0001:
			var state: Dictionary = _base_state()
			state.merge(segment.state, true)
			if bool(segment.get("charge", false)):
				state["charging_boost"] = elapsed + 0.001
				state["boost_charge"] = elapsed
			speed = move_toward(speed, float(segment.speed), DT * 2000.0)
			var velocity: Vector3 = Vector3(0.0, 0.0, - speed)
			simon.set_combat_state(state)
			host.position += velocity * DT
			simon.animate(DT, velocity, false, false)
			elapsed += DT
			clock += DT
			if clock + 0.0001 >= next_shot:
				next_shot += step
				_frame_camera(host.position, view)
				shots.append(await _snap())
	_save_sheets("%s_%s" % [label, view], shots)
	_clear()


func _frame_camera(at: Vector3, view: String, wide: bool = false) -> void :
	var focus: Vector3 = at + Vector3(0.0, 0.8, 0.4 if wide else 0.0)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 34.0
	var offset: Vector3 = Vector3(3.3, 0.3, 0.0)
	match view:
		"left": offset = Vector3(-3.3, 0.3, 0.0)
		"three": offset = Vector3(2.3, 0.8, -2.4)
		"threeleft": offset = Vector3(-2.3, 0.8, -2.4)
		"back": offset = Vector3(1.2, 1.4, 3.2)
		"front": offset = Vector3(0.0, 0.5, -3.8)
		"top": offset = Vector3(0.5, 4.2, 0.6)
		"close": offset = Vector3(2.0, 0.5, -1.1)
	if wide: offset *= 1.25
	camera.position = focus + offset * zoom
	camera.look_at(focus)
	sun.rotation = Vector3(deg_to_rad(-48.0), deg_to_rad(120.0 if view != "back" else 30.0), 0.0)


# Planches de COLUMNS × ROWS vignettes (une vignette par pas de temps), numérotées dans l'ordre.
func _save_sheets(name: String, shots: Array[Image]) -> void :
	var per_page: int = COLUMNS * ROWS
	var page: int = 0
	var index: int = 0
	while index < shots.size():
		var sheet: Image = Image.create(CELL.x * COLUMNS, CELL.y * ROWS, false, shots[0].get_format())
		for k in range(per_page):
			if index >= shots.size(): break
			sheet.blit_rect(shots[index], Rect2i(Vector2i.ZERO, CELL), Vector2i((k % COLUMNS) * CELL.x, (k / COLUMNS) * CELL.y))
			index += 1
		var path: String = "%s/%s_%d.png" % [out_dir, name, page]
		sheet.save_png(path)
		print("CAPTURE ", path)
		page += 1


func _build_stage() -> void :
	if DisplayServer.get_name() != "headless": get_viewport().disable_3d = true
	viewport = SubViewport.new()
	viewport.size = CELL
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)
	stage = Node3D.new()
	stage.name = "Stage"
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
	sun.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(40.0), 0.0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 30.0
	stage.add_child(sun)
	floor_mesh = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(600, 600)
	floor_mesh.mesh = plane
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	var img: Image = Image.create(8, 8, false, Image.FORMAT_RGB8)
	for x in range(8):
		for y in range(8):
			var dark: bool = (int(x / 4.0) + int(y / 4.0)) % 2 == 0
			img.set_pixel(x, y, Color(0.55, 0.57, 0.6) if dark else Color(0.68, 0.7, 0.73))
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.roughness = 1.0
	floor_mesh.material_override = mat
	stage.add_child(floor_mesh)
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.current = true


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
	visuals[id] = visual
	return visual


func _clear() -> void :
	for host: Node3D in hosts.values(): host.queue_free()
	hosts.clear()
	visuals.clear()


func _snap() -> Image:
	for i in range(3): await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


# Alignement des six élèves, de face puis de profil (repères de gabarit).
func _lineup() -> void :
	var people: Array[String] = ["Simon", "Ashura", "Bleuette", "Elly", "Usayuko", "Lysia"]
	viewport.size = Vector2i(1500, 560)
	for k in range(people.size()):
		var v: PaperVisual = _spawn(10 + k, people[k], Vector3((float(k) - 2.5) * 1.15, 0.0, 0.0))
		v.set_combat_state({"grounded": true, "ruleset_om": true})
		for f in range(30): v.animate(DT, Vector3.ZERO, false, false)
	for view: String in ["front", "side"]:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 2.6
		if view == "front":
			camera.position = Vector3(0.0, 1.0, -12.0)
			camera.rotation = Vector3(0.0, PI, 0.0)
		else:
			for k in range(people.size()):
				(visuals[10 + k] as PaperVisual).rotation.y = - PI * 0.5
			camera.position = Vector3(0.0, 1.0, -12.0)
			camera.rotation = Vector3(0.0, PI, 0.0)
		var image: Image = await _snap()
		var path: String = "%s/lineup_%s.png" % [out_dir, view]
		image.save_png(path)
		print("CAPTURE ", path)
	_clear()
	viewport.size = CELL
