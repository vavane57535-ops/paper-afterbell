extends Node

# Planches de poses à bassin très penché (roulade, rampe, chute à terre, relevage, porté, roller, charge, TrueForm)
# pour vérifier le garde-fou du genou de _leg_ik (character_visual.gd) hors locomotion.
# Lancement : xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 -- --tool test_leg_ik --rev-out DIR [--rev-only crawl]
# Une image par cas : rangée du haut de profil, rangée du bas en 3/4.
const DT: float = 1.0 / 120.0
const CASES: Array = [
	["roll", "Simon", [0.05, 0.15, 0.25, 0.35, 0.45, 0.55]],
	["crawl", "Simon", [0.2, 0.45, 0.7, 0.95, 1.2, 1.45]],
	["downed", "Elly", [0.3, 0.8, 1.3, 1.8, 2.3, 2.8]],
	["death_downed", "Simon", [0.1, 0.3, 0.5, 0.7, 0.95, 1.2]],
	["revive", "Elly", [0.2, 0.5, 0.9, 1.3, 1.7, 2.1]],
	["carried", "Bleuette", [0.2, 0.5, 0.8, 1.1, 1.4, 1.7]],
	["carry_boost", "Simon", [0.6, 0.65, 0.7, 0.75, 0.8, 0.85]],
	["skate", "Ashura", [0.6, 0.75, 0.9, 1.05, 1.2, 1.35]],
	["charge", "Ashura", [0.2, 0.6, 1.0, 1.6, 2.2, 3.0]],
	["charge", "Simon", [0.2, 0.6, 1.0, 1.6, 2.2, 3.0]],
	["tackle", "Usayuko", [0.1, 0.25, 0.4, 0.55, 0.7, 0.85]],
	["tf_sprint", "TrueForm", [0.6, 0.66, 0.72, 0.78, 0.84, 0.9]],
	["tf_walk", "TrueForm", [0.6, 0.72, 0.84, 0.96, 1.08, 1.2]],
]
var out_dir: String = "/tmp/rev_poses"
var only: String = ""
var viewport: SubViewport
var camera: Camera3D
var sun: DirectionalLight3D

func setup(_w: Node) -> void :
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in range(args.size()):
		var next: String = args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--rev-out": out_dir = next
			"--rev-only": only = next
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _stage() -> Node3D:
	get_viewport().disable_3d = true
	viewport = SubViewport.new()
	viewport.size = Vector2i(300, 330)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)
	var stage: Node3D = Node3D.new()
	viewport.add_child(stage)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.36, 0.4, 0.46)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.75, 0.8)
	env.ambient_light_energy = 0.5
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	stage.add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-45.0), deg_to_rad(110.0), 0.0)
	stage.add_child(sun)
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(400, 400)
	floor_mesh.mesh = plane
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.64, 0.68)
	floor_mesh.material_override = mat
	stage.add_child(floor_mesh)
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	return stage

func _run() -> void :
	var stage: Node3D = _stage()
	for i in range(4): await get_tree().process_frame
	for case: Array in CASES:
		var kind: String = case[0]
		var person: String = case[1]
		if not only.is_empty() and not (kind + "_" + person).contains(only): continue
		var times: Array = case[2]
		var sheet: Image = null
		for view in ["side", "three"]:
			for k in range(times.size()):
				var host: Node3D = Node3D.new()
				stage.add_child(host)
				var v: PaperVisual = PaperVisual.new()
				v.lod_enabled = false
				v.blob_shadow = false
				host.add_child(v)
				v.setup(person)
				var t: float = 0.0
				var target: float = float(times[k])
				var started: bool = false
				while t < target:
					var state: Dictionary = {"grounded": true, "vertical_speed": 0.0, "ruleset_om": true}
					var vel: Vector3 = Vector3.ZERO
					match kind:
						"roll":
							state["landing_roll"] = maxf(0.0, 0.65 - t)
							vel = Vector3(0, 0, -13.0)
						"crawl":
							vel = Vector3(0, 0, -0.7)
						"carried": state["carried_by"] = 3
						"carry_boost":
							state["carrying_id"] = 4
							state["speed_boost"] = 3.0
							state["sprinting"] = true
							vel = Vector3(0, 0, -20.4)
						"skate":
							state["boost_time"] = 3.0
							state["sprinting"] = true
							vel = Vector3(0, 0, -20.4)
						"charge":
							state["boost_charging"] = true
							state["charging_boost"] = t
							state["boost_charge"] = t
						"tackle": state["grab_time"] = 1.0
						"tf_sprint":
							state["phase6"] = 3.0
							state["sprinting"] = true
							vel = Vector3(0, 0, -20.7)
						"tf_walk": vel = Vector3(0, 0, -7.0)
					if not started:
						started = true
						if kind in ["crawl", "downed", "death_downed"]: v.set_life_state("downed")
						v.set_combat_state(state)
						if kind == "death_downed": v.play("death_downed")
						if kind == "revive": v.play("revive")
					v.set_combat_state(state)
					host.position += vel * DT
					v.animate(DT, vel, false, false)
					t += DT
				var focus: Vector3 = host.position + Vector3(0, 0.6, 0)
				if view == "side":
					camera.projection = Camera3D.PROJECTION_ORTHOGONAL
					camera.size = 2.2 if person != "TrueForm" else 3.4
					camera.position = focus + Vector3(8.0, 0.25, 0.0)
					camera.look_at(focus)
				else:
					camera.projection = Camera3D.PROJECTION_PERSPECTIVE
					camera.fov = 32.0
					camera.position = focus + Vector3(3.2, 1.2, -2.6) * (1.0 if person != "TrueForm" else 1.5)
					camera.look_at(focus)
				for f in range(3): await RenderingServer.frame_post_draw
				var image: Image = viewport.get_texture().get_image()
				if sheet == null: sheet = Image.create(300 * times.size(), 330 * 2, false, image.get_format())
				sheet.blit_rect(image, Rect2i(0, 0, 300, 330), Vector2i(k * 300, (0 if view == "side" else 1) * 330))
				host.queue_free()
				await get_tree().process_frame
		var path: String = "%s/%s_%s.png" % [out_dir, kind, person]
		sheet.save_png(path)
		print("REVPOSE ", path)
	get_tree().quit()
