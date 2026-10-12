extends Node

# Recensement des bruitages joués (0.16, vérification du mixage) : à chaque son qui démarre sur les
# voix de PaperAudio, note sa famille et son volume ; à la fin, un tableau par famille (nombre, volume
# moyen et maximal, sonie estimée = sonie du fichier + volume). À combiner avec une partie simulée :
#   godot --headless -- --simulate Simon --duration 80 --tool test_audio_census [--census-out F.json]

var world: Node
var _seen: Dictionary = {}
var _rows: Dictionary = {}
var _out: String = ""

func setup(game_world: Node) -> void :
	world = game_world
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find("--census-out")
	if index >= 0 and index + 1 < args.size(): _out = args[index + 1]

func _process(_delta: float) -> void :
	var audio: PaperAudio = world.audio
	if audio == null: return
	for i: int in range(audio.voice_pool.size()):
		var p: AudioStreamPlayer = audio.voice_pool[i]
		var started: int = int(audio._voice_started[i])
		if not p.playing or int(_seen.get(i, -1)) == started: continue
		_seen[i] = started
		_add(str(audio._voice_kinds[i]), p.volume_db)
	for i: int in range(audio._stinger_players.size()):
		var s: AudioStreamPlayer = audio._stinger_players[i]
		if s.playing and s.get_playback_position() < 0.05 and not _seen.has("st%d" % i):
			_seen["st%d" % i] = true
			_add("stinger:" + str(s.stream.resource_path.get_file()), s.volume_db)
		elif not s.playing: _seen.erase("st%d" % i)

func _add(kind: String, db: float) -> void :
	var row: Dictionary = _rows.get(kind, {"n": 0, "sum": 0.0, "max": -200.0})
	row.n = int(row.n) + 1
	row.sum = float(row.sum) + db
	row.max = maxf(float(row.max), db)
	_rows[kind] = row

func _exit_tree() -> void :
	var keys: Array = _rows.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return int(_rows[a].n) > int(_rows[b].n))
	for kind: String in keys:
		var row: Dictionary = _rows[kind]
		print("CENSUS %-28s n=%4d  moyen=%6.1f dB  max=%6.1f dB" % [kind, int(row.n), float(row.sum) / maxf(1.0, float(row.n)), float(row.max)])
	if not _out.is_empty():
		var f: FileAccess = FileAccess.open(_out, FileAccess.WRITE)
		if f: f.store_string(JSON.stringify(_rows, "  "))
