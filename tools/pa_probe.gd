extends Node

func setup(owner: Node) -> void :
	for person: String in ["Simon", "Ashura"]:
		var v: PaperVisual = PaperVisual.new()
		v.lod_enabled = false
		owner.add_child(v)
		v.setup(person)
		print("PROBE ", person, " leg_reach=", v._leg_reach, " scale=", v._model_scale, " base_h=", v._base_height, " foot_rest=", v._foot_rest, " hip_rest=", v._hip_rest, " arm=", v._arm_length, " shoulder=", v._shoulder_rest, " stance=", v._style.stance, " toe=", v._toe_length, " ankle_h=", v._ankle_height, " thigh_h=", v._thigh_height)
		print("PROBE ", person, " style=", v._style)
	get_tree().quit()
