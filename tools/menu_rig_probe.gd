extends Node

# Mesures des squelettes (pour placer les contacts des clips de l'écran titre) :
#   godot --headless -- --tool menu_rig_probe

var world: Node

func setup(game_world: Node) -> void :
	world = game_world
	_run.call_deferred()

func _run() -> void :
	for i: int in range(6): await get_tree().process_frame
	var holder: Node3D = Node3D.new()
	add_child(holder)
	for person: String in ["Simon", "Usayuko", "Ashura", "Lysia", "Elly", "Bleuette", "Alice"]:
		var visual: PaperVisual = PaperVisual.new()
		visual.lod_enabled = false
		holder.add_child(visual)
		visual.setup(person)
		var scale: float = visual.scale.x
		print("RIG %s scale=%.4f base=%.4f leg_reach=%.4f thigh_h=%.4f ankle_h=%.4f hip_half=%.4f foot_rest_x=%.4f toe=%.4f" % [person, scale, float(visual.get("_base_height")), float(visual.get("_leg_reach")), float(visual.get("_thigh_height")), float(visual.get("_ankle_height")), float(visual.get("_hip_half_width")), float(visual.get("_foot_rest_x")), float(visual.get("_toe_length"))])
		var shoulders: Dictionary = visual.get("_shoulder_rest")
		var arms: Dictionary = visual.get("_arm_length")
		var feet: Dictionary = visual.get("_foot_rest")
		var hips: Dictionary = visual.get("_hip_rest")
		print("RIG %s shoulder_l=%s shoulder_r=%s arm_l=%.4f arm_r=%.4f foot_l=%s foot_r=%s hip_l=%s hip_r=%s" % [person, shoulders[-1], shoulders[1], float(arms[-1]), float(arms[1]), feet[-1], feet[1], hips[-1], hips[1]])
		var head: Node3D = visual.get("_head")
		var body: Node3D = visual.get("_body")
		print("RIG %s head=%s body=%s head_world=%s" % [person, head.global_position, body.position, visual.socket_position("head")])
		visual.queue_free()
	get_tree().quit()
