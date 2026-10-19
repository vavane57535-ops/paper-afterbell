extends Node
func setup(owner: Node) -> void:
	owner.play_prologue()
	owner.set_process(false)
	var film: Node = owner.prologue
	for t: float in [78.6, 78.95, 79.0, 79.3, 80.2]:
		film.update(t, 0.0)
		var y: Node3D = film.yiero
		var d: Vector3 = film.DIM
		print("YPROBE t=", t, " hand_l=", y.socket("hand_l") - d, " pinch_l=", y.socket("pinch_l") - d, " grip_l=", y.socket("grip_l") - d, " hand_r=", y.socket("hand_r") - d, " chin=", y.socket("chin") - d, " eye_l=", y.socket("eye_l") - d, " teeth=", y.socket("teeth") - d)
	owner.set_process(true)
	owner.end_prologue()
	get_tree().quit()
