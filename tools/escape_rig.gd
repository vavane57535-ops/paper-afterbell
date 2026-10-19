extends Node

# Mesures des squelettes pour écrire les clips des films de fuite (anim_set_film_escape.gd).
# godot --headless -- --tool escape_rig

func setup(_world: Node) -> void :
	_run.call_deferred()

func _run() -> void :
	for person: String in ["Ashura", "Usayuko", "Simon", "Lysia", "Elly", "Bleuette", "Alice"]:
		var v: PaperVisual = PaperVisual.new()
		add_child(v)
		v.setup(person)
		var s: float = float(v.get("_model_scale"))
		var arm: Dictionary = v.get("_arm_length")
		var sh: Dictionary = v.get("_shoulder_rest")
		var fr: Dictionary = v.get("_foot_rest")
		var hr: Dictionary = v.get("_hip_rest")
		print("RIG %s scale=%.4f leg=%.4f leg_m=%.4f arm_m=%.4f/%.4f base=%.4f ankle=%.4f toe=%.4f" % [person, s, float(v.get("_leg_reach")), float(v.get("_leg_reach")) * s, float(arm[-1]) * s, float(arm[1]) * s, float(v.get("_base_height")) * s, float(v.get("_ankle_height")) * s, float(v.get("_toe_length")) * s])
		print("RIG %s shoulder_l=%s shoulder_r=%s foot_l=%s foot_r=%s hip_l=%s" % [person, str(Vector3(sh[-1]) * s), str(Vector3(sh[1]) * s), str(Vector3(fr[-1]) * s), str(Vector3(fr[1]) * s), str(Vector3(hr[-1]) * s)])
		print("RIG %s head=%s hand_r=%s" % [person, str(v.socket_position("head")), str(v.socket_position("hand_r"))])
		v.queue_free()
	get_tree().quit()
