extends Node

# Gabarits des élèves pour les portages de Simon (lot « simon », 0.17) : hauteurs des articulations au repos
# (mètres, repère du sol : x droite, y haut, z arrière), longueurs des bras et des jambes.
#   godot --headless -- --tool test_carry_rigdims

func setup(_world: Node) -> void :
	_run.call_deferred()


func _run() -> void :
	var stage: Node3D = Node3D.new()
	add_child(stage)
	for person: String in ["Simon", "Ashura", "Bleuette", "Elly", "Usayuko", "Lysia"]:
		var host: Node3D = Node3D.new()
		stage.add_child(host)
		var v: PaperVisual = PaperVisual.new()
		v.lod_enabled = false
		host.add_child(v)
		v.setup(person)
		v.set_combat_state({"grounded": true, "ruleset_om": true})
		for i in range(20): v.animate(1.0 / 60.0, Vector3.ZERO, false, false)
		var inv: Transform3D = v.global_transform.affine_inverse()
		var line: String = "RIGDIM %-8s scale=%.3f base=%.3f reach=%.3f" % [person, float(v.get("_model_scale")), float(v.get("_base_height")), float(v.get("_leg_reach"))]
		for key: String in ["_body", "_chest", "_neck", "_head", "_left_arm", "_left_elbow", "_left_hand", "_left_leg", "_left_knee"]:
			var p: Vector3 = inv * (v.get(key) as Node3D).global_position
			line += " %s=(%.2f,%.2f,%.2f)" % [key.trim_prefix("_"), p.x, p.y, p.z]
		var ankle: Vector3 = inv * ((v.get("_ankles") as Dictionary)[-1] as Node3D).global_position
		line += " ankle=(%.2f,%.2f,%.2f)" % [ankle.x, ankle.y, ankle.z]
		var upper: float = ((v.get("_left_elbow") as Node3D).global_position - (v.get("_left_arm") as Node3D).global_position).length()
		var lower: float = ((v.get("_left_hand") as Node3D).global_position - (v.get("_left_elbow") as Node3D).global_position).length()
		var thigh: float = ((v.get("_left_knee") as Node3D).global_position - (v.get("_left_leg") as Node3D).global_position).length()
		var shin: float = (((v.get("_ankles") as Dictionary)[-1] as Node3D).global_position - (v.get("_left_knee") as Node3D).global_position).length()
		line += " arm=%.2f+%.2f leg=%.2f+%.2f height=%.2f" % [upper, lower, thigh, shin, v.visual_height()]
		print(line)
		host.queue_free()
	get_tree().quit()
