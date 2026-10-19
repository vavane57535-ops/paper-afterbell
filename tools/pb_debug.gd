extends Node
const AnimLibrary = preload("res://anim_library.gd")
const AnimClip = preload("res://anim_clip.gd")
func setup(_w: Node) -> void :
	_run.call_deferred()
func _run() -> void :
	var v: PaperVisual = PaperVisual.new()
	v.lod_enabled = false
	add_child(v)
	v.setup("Simon")
	v.play("pb_test_run")
	var clip: Dictionary = AnimLibrary.clip("pb_test_run", "Simon")
	print("channels: ", clip.channels.keys())
	var body: Dictionary = clip.channels.body
	print("body keys n=", body.t.size(), " first t=", body.t.slice(0, 6), " v=", body.v.slice(0, 4))
	var t: float = 0.0
	while t < 4.6:
		v.animate(1.0 / 60.0, Vector3(0, 0, -7.5), false, false)
		t += 1.0 / 60.0
	print("body rot ", v._body.rotation, " chest ", v._chest.rotation, " sample ", AnimClip.sample(body, 4.6, false, 6.0))
	get_tree().quit()
