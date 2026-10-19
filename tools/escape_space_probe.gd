extends Node

# Sonde l'espace libre autour de la sortie (repère E du film de fuite : origine au pied de la
# porte, z vers la sortie) : carte ASCII des collisions à 0,3 m, 1,0 m et 1,8 m de haut.
#   godot --headless -- --tool escape_space_probe [--probe-map school|forest|snow] [--probe-open]
# « # » : obstacle à toutes les hauteurs testées ; « + » : obstacle bas seulement ; « . » : libre.

var world: Node
var map_id: String = "school"


func setup(owner: Node) -> void :
	world = owner
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		if args[i] == "--probe-map" and i + 1 < args.size(): map_id = args[i + 1]
	_run.call_deferred()


func _run() -> void :
	for i: int in range(4): await get_tree().process_frame
	if map_id != "school": world._rebuild_map(map_id)
	if OS.get_cmdline_user_args().has("--probe-open") and world.school.has_method("sample_cinematic_exit_open"):
		world.school.sample_cinematic_exit_open(10.0)
	for i: int in range(4): await get_tree().physics_frame
	var anchor: Vector3 = world.school.cinematic_anchor
	var finish: Vector3 = world.school.cinematic_exit
	var forward: Vector3 = finish - anchor
	forward.y = 0.0
	forward = forward.normalized()
	var right: Vector3 = Vector3.UP.cross(forward).normalized()
	var length: float = anchor.distance_to(finish)
	var door: Vector3 = anchor + forward * (length - 3.0)
	print("PROBE map=%s length=%.2f door_z=%.2f anchor=%s finish=%s" % [map_id, length, length - 3.0, anchor, finish])
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var query: PhysicsPointQueryParameters3D = PhysicsPointQueryParameters3D.new()
	query.collision_mask = 1
	var ground: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	ground.collision_mask = 1
	var header: String = "      "
	for xi: int in range(-16, 17):
		header += "|" if xi == 0 else ("%d" % (absi(xi) / 2 % 10) if xi % 2 == 0 else " ")
	print(header)
	for zi: int in range(10, -41, -1 if not OS.get_cmdline_user_args().has("--probe-open") else -1):
		if OS.get_cmdline_user_args().has("--probe-open") and (zi > 6 or zi < -4): continue
		var z: float = float(zi) * 0.5
		var row: String = "%5.1f " % z
		for xi: int in range(-16, 17):
			var x: float = float(xi) * 0.5
			var base: Vector3 = door + right * x + forward * z
			var hits: int = 0
			var low: bool = false
			for h: float in [0.3, 1.0, 1.8]:
				query.position = base + Vector3.UP * h
				if not space.intersect_point(query, 1).is_empty():
					hits += 1
					if h < 0.5: low = true
			# sol : y a-t-il un sol à moins de 0,6 m sous la racine ?
			ground.from = base + Vector3.UP * 0.5
			ground.to = base + Vector3.DOWN * 0.6
			var floor_hit: Dictionary = space.intersect_ray(ground)
			var c: String = "."
			if hits >= 2: c = "#"
			elif low: c = "+"
			elif hits == 1: c = "^"
			elif floor_hit.is_empty(): c = " "
			row += c
		print(row)
	print("PROBE_DONE")
	get_tree().quit()
