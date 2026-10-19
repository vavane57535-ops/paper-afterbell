extends Node

# Mesures des squelettes (prologue, partie B) : échelle, longueurs de jambe et de bras, épaules, hanches.
#   -- --tool pb_probe
# Sert à écrire les clips du film en unités justes (pieds plantés, mains qui touchent).

var world: Node

func setup(owner: Node) -> void :
	world = owner
	_run.call_deferred()

func _run() -> void :
	await get_tree().process_frame
	for person: String in ["Simon", "Ashura", "Usayuko", "Alice", "Elly", "Bleuette", "Lysia"]:
		var visual: PaperVisual = PaperVisual.new()
		visual.lod_enabled = false
		add_child(visual)
		visual.setup(person)
		await get_tree().process_frame
		var s: float = visual._model_scale
		print("PB_RIG ", person, " scale=%.4f leg=%.4f base=%.4f leg_m=%.3f base_m=%.3f" % [s, visual._leg_reach, visual._base_height, visual._leg_reach * s, visual._base_height * s])
		print("PB_RIG ", person, " arm_l=%.4f arm_r=%.4f arm_m=%.3f" % [visual._arm_length[-1], visual._arm_length[1], float(visual._arm_length[1]) * s])
		print("PB_RIG ", person, " shoulder_l=", visual._shoulder_rest[-1], " shoulder_r=", visual._shoulder_rest[1])
		print("PB_RIG ", person, " hip_l=", visual._hip_rest[-1], " foot_l=", visual._foot_rest[-1], " hip_r=", visual._hip_rest[1], " foot_r=", visual._foot_rest[1])
		print("PB_RIG ", person, " chest=", visual._spine.position + visual._chest.position, " head=", visual._spine.position + visual._chest.position + visual._neck.position + visual._head.position, " toe=", visual._toe_length)
		visual.queue_free()
	get_tree().quit()
