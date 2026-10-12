extends Node

# Réglages → Audio (0.16) : capture de l'onglet et vérification des volumes de bus.
var world: Node
var out_path: String = "user://audio_settings.png"
var _clock: float = 0.0
var _stage: int = 0

func setup(game_world: Node) -> void :
	world = game_world
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find("--settings-out")
	if index >= 0 and index + 1 < args.size(): out_path = args[index + 1]

func _bus_db(bus_name: StringName) -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus_name))

func _process(delta: float) -> void :
	_clock += delta
	if _stage == 0 and _clock > 2.0:
		_stage = 1
		var audio: PaperAudio = world.audio
		for pair: Array in [[1.0, 0.7], [0.5, 0.7], [1.0, 0.0], [1.0, 1.0]]:
			audio.master_volume = float(pair[0])
			audio.music_volume = float(pair[1])
			audio._apply_bus_volumes()
			print("SETTINGS_BUS master=%.2f music=%.2f -> PaperMix %.2f dB, PaperMusic %.2f dB" % [pair[0], pair[1], _bus_db(&"PaperMix"), _bus_db(&"PaperMusic")])
		audio.master_volume = 1.0
		audio.music_volume = 0.7
		world.ui.settings_tab = "audio"
		world.ui.show_settings()
	elif _stage == 1 and _clock > 4.0:
		_stage = 2
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out_path)
			print("SETTINGS_CAPTURE ", out_path)
		get_tree().quit()
