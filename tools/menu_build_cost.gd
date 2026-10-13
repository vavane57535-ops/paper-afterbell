extends Node

# Coût de construction des acteurs des scènes de survol (headless) :
#   godot --headless -- --tool menu_build_cost

var world: Node

func setup(game_world: Node) -> void :
	world = game_world
	_run.call_deferred()

func _run() -> void :
	for i: int in range(10): await get_tree().process_frame
	var holder: Node3D = Node3D.new()
	add_child(holder)
	for round_index: int in range(2):
		for person: String in ["Simon", "Usayuko", "Ashura", "Lysia", "Elly", "Bleuette", "Alice"]:
			var start: int = Time.get_ticks_usec()
			var visual: PaperVisual = PaperVisual.new()
			visual.lod_enabled = false
			visual.fidgets = false
			holder.add_child(visual)
			visual.setup(person)
			var built: int = Time.get_ticks_usec()
			visual.animate(1.0 / 60.0, Vector3.ZERO, false, false)
			var animated: int = Time.get_ticks_usec()
			var total: float = 0.0
			for k: int in range(60):
				var a: int = Time.get_ticks_usec()
				visual.animate(1.0 / 60.0, Vector3.ZERO, false, false)
				total += float(Time.get_ticks_usec() - a)
			print("BUILD %d %s : setup %.1f ms, 1er animate %.1f ms, animate moyen %.3f ms" % [round_index, person, (built - start) / 1000.0, (animated - built) / 1000.0, total / 60000.0])
	get_tree().quit()
