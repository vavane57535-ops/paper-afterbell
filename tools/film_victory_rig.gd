extends Node
# Mesures du squelette de chaque personnage, pour écrire les clips des victoires
# LMS en mètres (pieds plantés sans glissement, mains sur les accessoires).
#   godot --headless -- --tool film_victory_rig

func setup(_world: Node) -> void :
	_run.call_deferred()


func _run() -> void :
	for person: String in ["Simon", "Usayuko", "Ashura", "Lysia", "Elly", "Bleuette", "Alice"]:
		var visual: PaperVisual = PaperVisual.new()
		visual.lod_enabled = false
		add_child(visual)
		visual.setup(person)
		var scale: float = float(visual.get("_model_scale"))
		var reach: float = float(visual.get("_leg_reach"))
		var arms: Dictionary = visual.get("_arm_length")
		var hip: Dictionary = visual.get("_hip_rest")
		var foot: Dictionary = visual.get("_foot_rest")
		var shoulder: Dictionary = visual.get("_shoulder_rest")
		print("RIG %s scale=%.4f leg_reach=%.4f (%.3f m) arm=%.4f (%.3f m) base=%.4f (%.3f m) toe=%.4f ankle=%.4f" % [person, scale, reach, reach * scale, float(arms[1]), float(arms[1]) * scale, float(visual.get("_base_height")), float(visual.get("_base_height")) * scale, float(visual.get("_toe_length")), float(visual.get("_ankle_height"))])
		print("RIG %s hip_r=%s foot_r=%s shoulder_r=%s head_y=%.3f eyes=%s" % [person, str(hip[1]), str(foot[1]), str(shoulder[1]), visual.cinematic_focus_height(), str(visual.socket_position("eyes"))])
		visual.queue_free()
	get_tree().quit()
