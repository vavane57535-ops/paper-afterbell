extends Node



const FILES: Dictionary = {"hover": "res://ui/sfx/ui_hover.wav", "click": "res://ui/sfx/ui_click.wav", "back": "res://ui/sfx/ui_back.wav", "confirm": "res://ui/sfx/ui_confirm.wav", "page": "res://ui/sfx/ui_page.wav", "tear": "res://ui/sfx/ui_tear.wav"}
const GAINS: Dictionary = {"hover": -17.0, "click": -11.0, "back": -12.0, "confirm": -13.0, "page": -15.0, "tear": -16.0}

static var instance: Node

var world: Node
var _players: Dictionary = {}
var _last_played: Dictionary = {}

func setup(owner_world: Node) -> void :
	world = owner_world
	name = "UISound"
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	for kind: String in FILES:
		var stream: AudioStream = load(FILES[kind]) as AudioStream if ResourceLoader.exists(FILES[kind]) else null
		if stream == null: continue
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = stream
		player.max_polyphony = 2
		player.bus = &"PaperMix" if AudioServer.get_bus_index(&"PaperMix") >= 0 else &"Master"
		add_child(player)
		_players[kind] = player


static func play(kind: String) -> void :
	if is_instance_valid(instance): instance._play(kind)

func _play(kind: String) -> void :
	if world == null or bool(world.get("dedicated")): return
	var player: AudioStreamPlayer = _players.get(kind)
	if player == null: return
	var audio: Node = world.get("audio")
	var volume: float = 1.0
	if audio:
		if bool(audio.get("muted")): return
		volume = float(audio.get("effects_volume"))
	if volume <= 0.01: return

	var now: int = Time.get_ticks_msec()
	if kind == "hover" and now - int(_last_played.get(kind, -1000)) < 55: return
	_last_played[kind] = now
	player.volume_db = float(GAINS.get(kind, -12.0)) + linear_to_db(volume)
	player.play()
