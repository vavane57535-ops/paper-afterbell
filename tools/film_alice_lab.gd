extends Node

# Labo des films « Alice · X rattrapé(e) » et de l'épilogue (0.17).
#   godot --headless -- --tool film_alice_lab --fal-mode measure
#     mesures du squelette de chaque perso (mètres) : jambe, bras, hauteur du bassin, pied
#   godot --headless -- --tool film_alice_lab --fal-mode clips
#     vérifie que les clips film_alice_* existent et que les films n'appellent aucun clip du jeu

var world: Node
var mode: String = "measure"


func setup(owner: Node) -> void :
	world = owner
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		var value: String = args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--fal-mode": mode = value
	_run.call_deferred()


func _run() -> void :
	for i: int in range(3): await get_tree().process_frame
	match mode:
		"measure": await _measure()
		"space":
			for map_id: String in ["school", "forest", "snow"]:
				if map_id != "school": world._rebuild_map(map_id)
				for i: int in range(4): await get_tree().physics_frame
				_space(map_id)
	get_tree().quit()


# Place libre autour de l'ancre des films (coordonnées du film : x à droite, z vers la sortie).
func _space(map_id: String) -> void :
	var anchor: Vector3 = world.school.cinematic_anchor
	var finish: Vector3 = world.school.cinematic_exit
	var forward: Vector3 = finish - anchor
	forward.y = 0.0
	forward = forward.normalized()
	var right: Vector3 = Vector3.UP.cross(forward).normalized()
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var line: String = "SPACE %s anchor=%s length=%.2f" % [map_id, str(anchor), anchor.distance_to(finish)]
	for z: float in [-8.0, -4.0, 0.0, 4.0]:
		for dir: Vector2 in [Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0)]:
			var from: Vector3 = anchor + forward * z + Vector3.UP * 1.0
			var to: Vector3 = from + (right * dir.x + forward * dir.y) * 30.0
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
			var hit: Dictionary = space.intersect_ray(query)
			var free: float = from.distance_to(hit.position) if not hit.is_empty() else 30.0
			line += " z%+.0f%s=%.1f" % [z, {Vector2(0, 1): "+z", Vector2(0, -1): "-z", Vector2(1, 0): "+x", Vector2(-1, 0): "-x"}[dir], free]
	print(line)
	var ground: String = "GROUND %s" % map_id
	for z: float in [-9.0, -6.0, -3.0, 0.0, 3.0, 6.0]:
		for x: float in [-3.0, 0.0, 3.0]:
			var top: Vector3 = anchor + forward * z + right * x + Vector3.UP * 3.0
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(top, top + Vector3.DOWN * 8.0, 1))
			ground += " (%+.0f,%+.0f)=%s" % [x, z, ("%+.2f" % (float(hit.position.y) - anchor.y)) if not hit.is_empty() else "--"]
	print(ground)


func _measure() -> void :
	for person: String in ["Simon", "Usayuko", "Ashura", "Lysia", "Elly", "Bleuette", "Alice"]:
		var visual: PaperVisual = PaperVisual.new()
		add_child(visual)
		visual.setup(person)
		await get_tree().process_frame
		var s: float = float(visual.get("_model_scale"))
		var arm: Dictionary = visual.get("_arm_length")
		var foot: Dictionary = visual.get("_foot_rest")
		var shoulder: Dictionary = visual.get("_shoulder_rest")
		print("MEASURE %s scale=%.3f leg=%.3f arm=%.3f hips=%.3f toe=%.3f foot_r=%s shoulder_r=%s height=%.3f" % [person, s,
			float(visual.get("_leg_reach")) * s, float(arm[1]) * s, float(visual.get("_base_height")) * s,
			float(visual.get("_toe_length")) / maxf(float(visual.get("_leg_reach")), 0.001),
			str((foot[1] as Vector3) * s), str((shoulder[1] as Vector3) * s), visual.visual_height()])
		visual.queue_free()
