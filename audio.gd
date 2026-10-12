class_name PaperAudio
extends Node








var tracks: Dictionary = {}
var mode: String = "ambient"
var music_volume: float = 0.7
var effects_volume: float = 1.0
var muted: bool = false:
	set(value):
		muted = value
		var bus: int = AudioServer.get_bus_index(MIX_BUS)
		if bus >= 0: AudioServer.set_bus_mute(bus, value)
var effects: Dictionary = {}
var voice_pool: Array[AudioStreamPlayer] = []
var next_voice: int = 0
var lms_character: String = "Ashura"
var active_track: String = "ambient"
var surface: String = "concrete"
var _envelopes: Dictionary = {}
var _resume: Dictionary = {}
var _last_variants: Dictionary = {}
var _voice_kinds: Array[String] = []
var _voice_priority: Array[int] = []
var _voice_started: Array[int] = []
var _panners: Array[AudioEffectPanner] = []
var _duck_time: float = 0.0
var _duck_gain: float = 1.0
var _preview_snapshot: Dictionary = {}
var _preview_paused: bool = false
var _event_cues: Dictionary = {}
var _recent_body_cues: Dictionary = {}
var _lms_resume_after_true_form: float = -1.0
var _world: Node
var _silent: bool = false
var _pending: Dictionary = {}
var _start_requests: Dictionary = {}
var _fade_speed: Dictionary = {}
var _heart_player: AudioStreamPlayer
var _heart_target: float = 0.0
var _heart_level: float = 0.0
var _heart_clock: float = 0.0
var _hurt_target: float = 0.0
var _hurt_level: float = 0.0
var _world_bus: int = -1
var _lowpass: AudioEffectLowPassFilter
var _lowpass_on: bool = false
var _stinger_players: Array[AudioStreamPlayer] = []
var _stinger_queue: Array[Dictionary] = []
var _stinger_clock: Dictionary = {}
var _exit_open_heard: bool = false
var _escapes_heard: int = 0
var _eliminations_heard: Dictionary = {}
var _wood_regions: Array[AABB] = []
var _prefetch_clock: float = 0.0

var _bed_player: AudioStreamPlayer
var _bed_map: String = ""
var _bed_level: float = 0.0
var _bed_pending: String = ""
var _last_phase: String = ""
var _presence_clock: float = 20.0
var _owl_clock: float = 30.0

const MIX_BUS: StringName = &"PaperMix"
const MUSIC_BUS: StringName = &"PaperMusic"
const WORLD_BUS: StringName = &"PaperWorld"
const FEEDBACK_BUS: StringName = &"PaperFeedback"
const CROSSFADE_SECONDS: float = 1.35

const SUSPEND_FADE_SECONDS: float = 0.6

const MUSIC_LEVEL: float = 0.82
const HEARTBEAT_PATH: String = "res://audio/fx_heartbeat.wav"
const LMS_THEMES: Dictionary = {
	"Ashura": "lms_ashura", "Usayuko": "lms_usayuko", "Simon": "lms_simon", 
	"Lysia": "lms_lysia", "Elly": "lms_elly", "Bleuette": "lms_bleuette"
}
const LMS_TITLES: Dictionary = {
	"Ashura": "Red", "Usayuko": "USAYUKO OST", "Simon": "Simon OST", 
	"Lysia": "Vanguard", "Elly": "Helios", "Bleuette": "BLEUETTE LMS"
}


const USER_OST_FILES: Dictionary = {
	"lms_Simon": "lms_simon_user.mp3", "lms_Usayuko": "fx_lms_usayuko_user.ogg", "lms_Bleuette": "lms_bleuette_user.mp3"
}
const BASE_TRACKS: Dictionary = {"ambient": "01_empty_corridors", "chase": "02_shadow_in_pursuit", "ending": "04_after_the_bell", "true_form": "02_shadow_in_pursuit", 
	"menu": "music_menu", "ambient_forest": "music_forest", "ambient_snow": "music_snow", "defeat": "music_defeat", "blocus": "cinematic/blocus"}

const EAGER_TRACKS: Array[String] = ["ambient", "chase", "ending", "true_form", "menu"]

const AMBIENCE_BEDS: Dictionary = {"school": "res://audio/amb_school.ogg", "forest": "res://audio/amb_forest.ogg", "snow": "res://audio/amb_snow.ogg"}
const AMBIENCE_LEVEL: float = 0.85

const STEP_ALTERNATES: Dictionary = {"concrete": ["step_floor", 0.4], "grass": ["step_dirt", 0.4]}


const LMS_DURATIONS: Dictionary = {
	"Ashura": 158.0, "Usayuko": 283.173379, "Simon": 310.909393, 
	"Lysia": 158.0, "Elly": 158.0, "Bleuette": 201.534698
}


const TRACK_GAINS: Dictionary = {
	"ambient": 0.64, "chase": 0.89, "ending": 0.89, 


	"menu": 0.7, "ambient_forest": 0.5, "ambient_snow": 0.5, "defeat": 0.92, "blocus": 0.89, 

	"lms_Ashura": 1.0, "lms_Usayuko": 0.448745, "lms_Simon": 1.166809617, 
	"lms_Lysia": 1.0, "lms_Elly": 1.0, "lms_Bleuette": 0.251189
}
const VARIANT_COUNTS: Dictionary = {
	"step_concrete": 5, "step_wood": 5, "step_grass": 5, "step_snow": 5, "step_floor": 6, "step_dirt": 6, 
	"slash": 8, "hit": 7, "punch": 8, "block": 3, "stun": 6, "ability": 3, "heal": 3, "presence": 3, "owl": 2, 
	"grenade_throw": 3, "grenade_bounce": 3, "spike": 3, "shadow": 3, "ground_impact": 3, 
	"camera_place": 2, "camera_switch": 2, "boost": 2, "grab": 2, "xray": 2, "encourage": 2, 
	"shotgun": 3, "flash": 2, "bell": 1, "door_open": 3, "door_creak": 2
}
const FX_GAINS: Dictionary = {
	"step": 0.36, "slash": 0.74, "hit": 0.83, "punch": 0.88, "block": 0.84, "stun": 0.64, 
	"ability": 0.57, "heal": 0.5, "grenade_throw": 0.68, "grenade_bounce": 0.53, 
	"spike": 0.9, "shadow": 0.7, "ground_impact": 0.9, "camera_place": 0.62, 
	"camera_switch": 0.48, "boost": 0.65, "grab": 0.65, "xray": 0.51, "encourage": 0.48, 
	"shotgun": 1.0, "flash": 0.91, "shotgun_reload": 0.55, "bell": 0.69, "door_open": 0.72, "door_creak": 0.78, 
	"presence": 0.42, "owl": 0.5
}
const FX_REACH: Dictionary = {
	"step": 18.0, "camera_place": 22.0, "camera_switch": 18.0, "heal": 25.0, 
	"grenade_throw": 26.0, "grenade_bounce": 22.0, "flash": 46.0, "shotgun": 68.0, 
	"spike": 44.0, "ground_impact": 42.0, "bell": 80.0, "door_open": 34.0, "door_creak": 38.0, 
	"presence": 40.0, "owl": 70.0
}


const FX_PRIORITY: Dictionary = {
	"hit": 2, "slash": 2, "punch": 2, "block": 2, "spike": 2, "shadow": 2, "ground_impact": 2, "stun": 2, "grab": 2, 
	"shotgun": 3, "flash": 3, "bell": 3, "door_open": 3, "door_creak": 3
}

const HEART_BANDS: Array = [[0.0, 64.0, 0.94], [0.34, 88.0, 1.0], [0.67, 118.0, 1.06]]

const STINGERS: Dictionary = {
	"exit_open": [["bell", 1.0, 0.9, 0.0], ["door_open", 0.92, 0.5, 0.12]], 
	"escape": [["bell", 1.26, 0.5, 0.0], ["encourage", 1.0, 0.45, 0.06], ["heal", 1.12, 0.4, 0.12]], 
	"elimination": [["bell", 0.71, 0.75, 0.0], ["ground_impact", 0.74, 0.5, 0.05]], 
	"chase": [["shadow", 0.78, 0.5, 0.0], ["ground_impact", 0.86, 0.42, 0.0]]
}
const STINGER_COOLDOWN: Dictionary = {"exit_open": 2.0, "escape": 1.5, "elimination": 1.5, "chase": 25.0}

func setup() -> void :
	if not tracks.is_empty(): return
	_world = get_parent()
	_silent = _is_dedicated()
	_setup_mix()
	var keys: Array = BASE_TRACKS.keys()
	for character_name: String in LMS_THEMES: keys.append("lms_" + character_name)
	for key: String in keys:
		var p: AudioStreamPlayer = AudioStreamPlayer.new();add_child(p)
		p.bus = MUSIC_BUS;p.volume_db = -80.0
		if key == "true_form": p.pitch_scale = 0.86
		if USER_OST_FILES.has(key): p.finished.connect(_restart_complete_ost.bind(key))
		tracks[key] = p;_envelopes[key] = 0.0;_resume[key] = 0.0

	if _silent: return
	for key: String in EAGER_TRACKS: _load_track_now(key)
	for key: String in VARIANT_COUNTS:
		var variants: Array[AudioStream] = []
		for index in range(int(VARIANT_COUNTS[key])):
			var stream: AudioStream = load("res://audio/sfx/%s_%02d.wav" % [key, index]) as AudioStream
			if stream: variants.append(stream)
		effects[key] = variants
	for index in range(18):
		var bus_name: StringName = StringName("PaperFoley%02d" % index)
		var bus: int = _ensure_bus(bus_name, WORLD_BUS)
		var pan: AudioEffectPanner
		if AudioServer.get_bus_effect_count(bus) == 0:
			pan = AudioEffectPanner.new();AudioServer.add_bus_effect(bus, pan)
		else: pan = AudioServer.get_bus_effect(bus, 0) as AudioEffectPanner
		var p: AudioStreamPlayer = AudioStreamPlayer.new();p.bus = bus_name;add_child(p)
		voice_pool.append(p);_panners.append(pan);_voice_kinds.append("");_voice_priority.append(0);_voice_started.append(0)
	_heart_player = AudioStreamPlayer.new()
	_heart_player.bus = FEEDBACK_BUS
	_heart_player.stream = load(HEARTBEAT_PATH) as AudioStream
	add_child(_heart_player)
	_bed_player = AudioStreamPlayer.new()
	_bed_player.bus = WORLD_BUS
	_bed_player.volume_db = -80.0
	add_child(_bed_player)
	for index in range(3):
		var stinger_player: AudioStreamPlayer = AudioStreamPlayer.new()
		stinger_player.bus = FEEDBACK_BUS
		add_child(stinger_player)
		_stinger_players.append(stinger_player)
	if tracks.has(active_track): _play_from(active_track, 0.0)

func _is_dedicated() -> bool:
	if "--dedicated" in OS.get_cmdline_user_args(): return true
	return is_instance_valid(_world) and bool(_world.get("dedicated"))

func _ensure_bus(bus_name: StringName, destination: StringName) -> int:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index < 0:
		AudioServer.add_bus();index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, destination)
	return index

func _setup_mix() -> void :

	var mix: int = _ensure_bus(MIX_BUS, &"Master")
	if AudioServer.get_bus_effect_count(mix) == 0:
		var limiter: AudioEffectHardLimiter = AudioEffectHardLimiter.new()
		limiter.ceiling_db = -1.2;limiter.pre_gain_db = 0.0;limiter.release = 0.16
		AudioServer.add_bus_effect(mix, limiter)
	AudioServer.set_bus_mute(mix, muted)
	_world_bus = _ensure_bus(WORLD_BUS, MIX_BUS)
	if AudioServer.get_bus_effect_count(_world_bus) == 0:
		_lowpass = AudioEffectLowPassFilter.new()
		_lowpass.cutoff_hz = 20000.0
		AudioServer.add_bus_effect(_world_bus, _lowpass)
	else: _lowpass = AudioServer.get_bus_effect(_world_bus, 0) as AudioEffectLowPassFilter
	AudioServer.set_bus_effect_enabled(_world_bus, 0, false)
	_lowpass_on = false
	_ensure_bus(MUSIC_BUS, WORLD_BUS)
	_ensure_bus(FEEDBACK_BUS, MIX_BUS)



func volume_to_db(value: float) -> float:
	if not is_finite(value) or value <= 0.001: return -80.0
	var v: float = minf(value, 1.0)
	return 20.0 * log(v) / log(10.0) * (2.0 - v)

func _slider_gain(value: float) -> float:
	return db_to_linear(volume_to_db(value))





func _track_path(key: String) -> String:
	if USER_OST_FILES.has(key): return "res://audio/" + str(USER_OST_FILES[key])
	if BASE_TRACKS.has(key): return "res://audio/" + str(BASE_TRACKS[key]) + ".ogg"
	var character_name: String = key.trim_prefix("lms_")
	return "res://audio/" + str(LMS_THEMES.get(character_name, "lms_ashura")) + ".ogg"

func _configure_loop(key: String, stream: AudioStream) -> void :
	var complete: bool = USER_OST_FILES.has(key)
	if stream is AudioStreamOggVorbis:
		stream.loop = not complete;stream.loop_offset = 0.0
	elif stream is AudioStreamMP3: stream.loop = not complete
	elif stream is AudioStreamWAV: stream.loop_mode = AudioStreamWAV.LOOP_DISABLED

func _attach(key: String, stream: AudioStream) -> void :
	var player: AudioStreamPlayer = tracks.get(key)
	if player == null or stream == null: return
	_configure_loop(key, stream)
	player.stream = stream
	if not _start_requests.has(key): return
	var request: Dictionary = _start_requests[key]
	_start_requests.erase(key)
	if key != active_track: return
	var at: float = float(request.position)

	if bool(request.catch_up): at += float(Time.get_ticks_msec() - int(request.since)) / 1000.0
	player.play(clampf(at, 0.0, maxf(0.0, stream.get_length() - 0.05)))
	player.stream_paused = _preview_paused

func _load_track_now(key: String) -> bool:
	var player: AudioStreamPlayer = tracks.get(key)
	if player == null or _silent: return false
	if player.stream != null: return true
	var path: String = _track_path(key)
	var stream: AudioStream
	if _pending.has(key):
		stream = ResourceLoader.load_threaded_get(path) as AudioStream
		_pending.erase(key)
	else: stream = load(path) as AudioStream
	_attach(key, stream)
	return player.stream != null


func _request_track(key: String) -> void :
	if _silent or not tracks.has(key) or tracks[key].stream != null or _pending.has(key): return
	var path: String = _track_path(key)
	if ResourceLoader.load_threaded_request(path, "AudioStream") == OK: _pending[key] = path
	else: _load_track_now(key)

func _poll_loads() -> void :
	for key: Variant in _pending.keys():
		var path: String = _pending[key]
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS: continue
		_pending.erase(key)
		if status == ResourceLoader.THREAD_LOAD_LOADED: _attach(str(key), ResourceLoader.load_threaded_get(path) as AudioStream)
		else: _attach(str(key), load(path) as AudioStream)


func prefetch_lms(names: Array) -> void :
	for name_value: Variant in names:
		if LMS_THEMES.has(str(name_value)): _request_track("lms_" + str(name_value))

func _play_from(key: String, position: float, catch_up: bool = false) -> void :
	var player: AudioStreamPlayer = tracks.get(key)
	if player == null: return
	player.stream_paused = false
	if player.stream == null:
		if _silent: return
		_request_track(key)
		_start_requests[key] = {"position": position, "since": Time.get_ticks_msec(), "catch_up": catch_up}
		return
	player.play(maxf(0.0, position))

func _true_form_running() -> bool:
	if not is_instance_valid(_world) or not _world.has_method("killer_actor"): return false
	var killer: Variant = _world.call("killer_actor")
	return killer != null and float(killer.effects.get("phase6", 0.0)) > 0.0

func set_mode(next: String) -> void :
	if not _preview_snapshot.is_empty(): return
	if next != "lms" and not tracks.has(next): return
	if mode == next: return
	if next == "lms" and mode == "true_form" and _true_form_running():

		_request_track("lms_" + lms_character)
		if _lms_resume_after_true_form < 0.0: _lms_resume_after_true_form = 0.0
		return
	var previous: String = mode
	if next == "true_form" and previous == "lms":

		var suspended: String = "lms_" + lms_character
		var player: AudioStreamPlayer = tracks.get(suspended)
		_lms_resume_after_true_form = player.get_playback_position() if player and player.playing else maxf(0.0, _lms_resume_after_true_form)
		_fade_speed[suspended] = 1.0 / SUSPEND_FADE_SECONDS
	mode = next
	if next == "lms":
		_enter_lms(previous)
		return
	if next == "true_form":

		_select_track("true_form", not tracks["true_form"].playing)
		if previous == "lms": _fade_speed["true_form"] = 1.0 / SUSPEND_FADE_SECONDS
		return
	if previous == "true_form" or next in ["ending", "blocus"]: _lms_resume_after_true_form = -1.0
	if next == "chase" and previous == "ambient": stinger("chase")
	_select_track(_track_for(next), next in ["ending", "blocus"])

func _enter_lms(previous: String) -> void :
	var key: String = "lms_" + lms_character
	_fade_speed.erase(key)
	if previous == "true_form" and _lms_resume_after_true_form >= 0.0:
		var at: float = _lms_resume_after_true_form
		_lms_resume_after_true_form = -1.0
		active_track = key
		_play_from(key, at, true)
		return
	_lms_resume_after_true_form = -1.0
	_select_track(key, true)

func _select_track(key: String, restart: bool) -> void :
	if key != active_track and "--audio-log" in OS.get_cmdline_user_args(): print("AUDIO track ", active_track, " -> ", key)
	active_track = key
	if not tracks.has(key): return
	var p: AudioStreamPlayer = tracks[key]
	p.stream_paused = false
	_fade_speed.erase(key)
	if restart: _play_from(key, 0.0, key.begins_with("lms_") or key == "blocus")
	elif not p.playing: _play_from(key, float(_resume.get(key, 0.0)))



func _track_for(next: String) -> String:
	if next == "ambient": return _ambient_key()
	if next == "ending" and is_instance_valid(_world) and str(_world.get("outcome")) == "killer": return "defeat"
	return next

func _ambient_key() -> String:
	if not is_instance_valid(_world): return "ambient"
	var phase: String = str(_world.get("phase"))
	if phase in ["menu", "lobby"]: return "menu"
	var map_track: String = "ambient_" + _map_name()
	return map_track if tracks.has(map_track) else "ambient"

func _map_name() -> String:
	if not is_instance_valid(_world): return "school"
	var key: String = str(_world.get("selected_map")).to_lower()
	if "snow" in key or "neige" in key: return "snow"
	if "forest" in key or "forêt" in key or "foret" in key: return "forest"
	return "school"

func set_lms_character(character_name: String) -> void :
	if not _preview_snapshot.is_empty(): return
	var next: String = character_name if LMS_THEMES.has(character_name) else "Ashura"
	if lms_character == next and mode == "lms": return
	var changed: bool = next != lms_character
	lms_character = next
	_request_track("lms_" + next)
	if mode == "true_form" and _true_form_running():

		if changed or _lms_resume_after_true_form < 0.0: _lms_resume_after_true_form = 0.0
		return
	var previous: String = mode
	mode = "lms"
	_enter_lms(previous)

func lms_title() -> String:
	var title: String = str(LMS_TITLES.get(lms_character, LMS_TITLES["Ashura"]))
	return title if lms_character in ["Simon", "Usayuko", "Bleuette"] else title + " · Scott Buckley"

func lms_duration(character_name: String) -> float:
	var player: AudioStreamPlayer = tracks.get("lms_" + character_name)
	if player and player.stream: return maxf(1.0, player.stream.get_length())
	if LMS_DURATIONS.has(character_name): return float(LMS_DURATIONS[character_name])
	return 150.0

func credit_text() -> String:
	return "Musique : Scott Buckley — CC-BY 4.0 — www.scottbuckley.com.au\n" + """Signal to Noise · Juggernaut · Echoes Of Home · Red · Vanguard · Helios · Emergent.
""" + \
	"LMS Simon, Usayuko et Bleuette : OST fournies par le propriétaire du projet, conservées intégralement.\n" + \
	"Montages, fondus et niveaux adaptés au jeu. Bruitages CC0 : Kenney ; Ben Jaszczak, Brian Nelson, Kevin Heras, Matthew Nanney ; zer0_sol.\n" + \
	"Musiques du menu, de la forêt, de la neige et de la défaite : compositions originales du jeu (carillon de Westminster, domaine public).\n" + \
	"Ambiances et bruitages freesound : blouhond, nicola_ariutti, nuFF3 (CC BY) ; rsn267, beambot, guyburns, florianreichelt, kretopi, mateusboga, PorkMuncher, qubodup, Fabrizio84 (CC0).\n" + \
	"Voix : synthèse Piper (MIT), voix SIWIS (CC BY 4.0), traitées pour chaque personnage.\n" + \
	"Sources et licences complètes : AUDIO-CREDITS.md."

func _restart_complete_ost(key: String) -> void :
	if key != active_track or not tracks.has(key): return
	_envelopes[key] = 0.0
	var player: AudioStreamPlayer = tracks[key]
	player.volume_db = -80.0;player.play();player.stream_paused = _preview_paused





func set_surface(map_id: String) -> void :
	var key: String = map_id.to_lower()
	if "snow" in key or "neige" in key: surface = "snow"
	elif "forest" in key or "forêt" in key or "foret" in key: surface = "grass"
	elif key == "wood": surface = "wood"
	else: surface = "concrete"
	_scan_wood_floors()



func _scan_wood_floors() -> void :
	_wood_regions.clear()
	if _silent or not is_instance_valid(_world): return
	var school: Variant = _world.get("school")
	if not is_instance_valid(school) or not school.is_inside_tree(): return
	var wood: Variant = school.get("_wood")
	if not wood is Material: return
	for child: Node in school.get_children():
		if not child is MeshInstance3D: continue
		var node: MeshInstance3D = child
		if node.material_override != wood or not node.mesh is BoxMesh: continue
		var bounds: AABB = node.global_transform * node.mesh.get_aabb()
		if bounds.size.y > 0.45 or minf(bounds.size.x, bounds.size.z) < 1.2 or bounds.size.x * bounds.size.z < 4.0: continue

		_wood_regions.append(AABB(Vector3(bounds.position.x, bounds.end.y - 0.35, bounds.position.z), Vector3(bounds.size.x, 1.35, bounds.size.z)))

func _surface_at(position: Vector3) -> String:
	for region: AABB in _wood_regions:
		if region.has_point(position): return "wood"
	return surface





func preview_begin(character_name: String, preview_mode: String = "lms") -> void :

	if tracks.is_empty(): setup()
	if _preview_snapshot.is_empty():
		var playing: Dictionary = {}
		for key: String in tracks:
			var player: AudioStreamPlayer = tracks[key]
			playing[key] = {"playing": player.playing, "position": player.get_playback_position(), "paused": player.stream_paused}
		_preview_snapshot = {"mode": mode, "active_track": active_track, "lms_character": lms_character, 
			"envelopes": _envelopes.duplicate(), "resume": _resume.duplicate(), "players": playing, 
			"duck_time": _duck_time, "duck_gain": _duck_gain}
	_preview_paused = false
	lms_character = character_name if LMS_THEMES.has(character_name) else "Ashura"
	mode = preview_mode if preview_mode in ["ambient", "chase", "ending", "lms", "blocus"] else "ambient"
	active_track = "lms_" + lms_character if mode == "lms" else mode
	_stinger_queue.clear()
	_start_requests.clear()
	_fade_speed.clear()
	for player: AudioStreamPlayer in voice_pool:
		player.stop();player.stream_paused = false
	for player: AudioStreamPlayer in _stinger_players: player.stop()
	if _heart_player: _heart_player.stop()
	for key: String in tracks:
		var player: AudioStreamPlayer = tracks[key]
		player.stop();player.stream_paused = false;player.volume_db = -80.0
		_envelopes[key] = 0.0
	_duck_time = 0.0;_duck_gain = 1.0

	_load_track_now(active_track)
	tracks[active_track].play()

func preview_pause(paused: bool) -> void :
	if _preview_snapshot.is_empty(): return
	_preview_paused = paused
	for player: AudioStreamPlayer in tracks.values(): player.stream_paused = paused
	for player: AudioStreamPlayer in voice_pool: player.stream_paused = paused

func preview_seek(seconds: float) -> void :
	if _preview_snapshot.is_empty() or not is_finite(seconds) or not tracks.has(active_track): return
	var player: AudioStreamPlayer = tracks[active_track]
	var length: float = player.stream.get_length() if player.stream else 0.0
	if length <= 0.0: return
	var position: float = fposmod(maxf(0.0, seconds), length)
	if not player.playing: player.play(position)
	else: player.seek(position)
	player.stream_paused = _preview_paused

	for voice: AudioStreamPlayer in voice_pool: voice.stop()
	_duck_time = 0.0;_duck_gain = 1.0

func preview_end() -> void :
	if _preview_snapshot.is_empty(): return
	var saved: Dictionary = _preview_snapshot
	_preview_snapshot = {};_preview_paused = false
	mode = str(saved["mode"]);active_track = str(saved["active_track"]);lms_character = str(saved["lms_character"])
	_envelopes = saved["envelopes"].duplicate();_resume = saved["resume"].duplicate()
	_duck_time = float(saved["duck_time"]);_duck_gain = float(saved["duck_gain"])
	for key: String in tracks:
		var player: AudioStreamPlayer = tracks[key]
		var state: Dictionary = saved["players"][key]
		player.stop();player.stream_paused = false
		if bool(state["playing"]) and player.stream: player.play(float(state["position"]))
		player.stream_paused = bool(state["paused"])
	for player: AudioStreamPlayer in voice_pool:
		player.stop();player.stream_paused = false
	_process(0.0)





func _process(delta: float) -> void :
	if _silent: return
	if not _pending.is_empty(): _poll_loads()
	if _preview_paused: return
	_duck_time = maxf(0.0, _duck_time - delta)

	var duck_goal: float = 0.72 if _duck_time > 0 else 1.0
	_duck_gain = move_toward(_duck_gain, duck_goal, delta * (6.0 if duck_goal < _duck_gain else 1.6))
	var level: float = _slider_gain(music_volume) * MUSIC_LEVEL * _duck_gain
	for key: String in tracks:
		var p: AudioStreamPlayer = tracks[key]
		var goal: float = 1.0 if key == active_track else 0.0
		var speed: float = float(_fade_speed.get(key, 1.0 / CROSSFADE_SECONDS))
		var envelope: float = move_toward(float(_envelopes.get(key, 0.0)), goal, delta * speed)
		_envelopes[key] = envelope

		var gain: float = sin(envelope * PI * 0.5) * level * float(TRACK_GAINS.get(key, 1.0))
		p.volume_db = linear_to_db(gain) if gain > 0.0001 and not muted else -80.0
		if key != active_track and p.playing and envelope <= 0.0001:
			_resume[key] = p.get_playback_position();p.stop()
	_follow_phase()
	_update_bed(delta)
	_update_heartbeat(delta)
	_update_hurt(delta)
	_update_stingers(delta)
	_watch_world(delta)



func _follow_phase() -> void :
	if not _preview_snapshot.is_empty() or not is_instance_valid(_world): return
	var phase: String = str(_world.get("phase"))
	if phase != _last_phase:
		_last_phase = phase
		if phase == "loading": _prefetch_map()
	if mode == "ambient" or mode == "ending":
		var want: String = _track_for(mode)
		if want != active_track: _select_track(want, mode == "ending")

func _prefetch_map() -> void :
	var map_track: String = "ambient_" + _map_name()
	if tracks.has(map_track): _request_track(map_track)
	var bed_path: String = str(AMBIENCE_BEDS.get(_map_name(), ""))
	if bed_path.is_empty() or _bed_pending == bed_path: return
	if ResourceLoader.load_threaded_request(bed_path, "AudioStream") == OK: _bed_pending = bed_path


func _update_bed(delta: float) -> void :
	if _bed_player == null: return
	var phase: String = str(_world.get("phase")) if is_instance_valid(_world) else ""
	var map: String = _map_name()
	var wanted: bool = phase == "playing" and _preview_snapshot.is_empty() and not muted
	if wanted and _bed_map != map:
		var path: String = str(AMBIENCE_BEDS.get(map, ""))
		var stream: AudioStream = null
		if not _bed_pending.is_empty() and _bed_pending == path:
			var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path)
			if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS: return
			stream = ResourceLoader.load_threaded_get(path) as AudioStream
			_bed_pending = ""
		elif not path.is_empty():
			stream = load(path) as AudioStream
		if stream is AudioStreamOggVorbis: stream.loop = true
		_bed_player.stop()
		_bed_player.stream = stream
		_bed_map = map
		_bed_level = 0.0
		if stream: _bed_player.play(randf() * maxf(0.0, stream.get_length() - 1.0))
		if "--audio-log" in OS.get_cmdline_user_args(): print("AUDIO bed ", map, " ", path)
	_bed_level = move_toward(_bed_level, 1.0 if wanted else 0.0, delta * (0.5 if wanted else 0.8))
	if _bed_level <= 0.001:
		_bed_player.volume_db = -80.0
		return
	var gain: float = _bed_level * AMBIENCE_LEVEL
	_bed_player.volume_db = linear_to_db(maxf(0.0001, gain)) + volume_to_db(effects_volume)


func set_heartbeat(intensity: float) -> void :
	_heart_target = clampf(intensity, 0.0, 1.0) if is_finite(intensity) else 0.0


func set_hurt(amount: float) -> void :
	_hurt_target = clampf(amount, 0.0, 1.0) if is_finite(amount) else 0.0

func _update_heartbeat(delta: float) -> void :
	if _heart_player == null: return
	var goal: float = 0.0 if muted or not _preview_snapshot.is_empty() else _heart_target
	_heart_level = move_toward(_heart_level, goal, delta * (2.0 if goal > _heart_level else 0.8))
	if _heart_level <= 0.02:

		_heart_clock = 0.0
		return
	_heart_clock -= delta
	if _heart_clock > 0.0: return
	var band: Array = HEART_BANDS[0]
	for entry: Array in HEART_BANDS:
		if _heart_level >= float(entry[0]): band = entry
	_heart_clock = maxf(_heart_clock + 60.0 / float(band[1]), 0.12)
	_heart_player.pitch_scale = float(band[2])
	_heart_player.volume_db = linear_to_db(lerpf(0.26, 0.95, _heart_level)) + volume_to_db(effects_volume)
	_heart_player.play()

func _update_hurt(delta: float) -> void :
	if _world_bus < 0 or _lowpass == null: return
	var goal: float = 0.0 if not _preview_snapshot.is_empty() else _hurt_target
	_hurt_level = move_toward(_hurt_level, goal, delta * 1.5)
	var on: bool = _hurt_level > 0.01
	if on != _lowpass_on:
		_lowpass_on = on
		AudioServer.set_bus_effect_enabled(_world_bus, 0, on)
		if not on: AudioServer.set_bus_volume_db(_world_bus, 0.0)
	if not on: return

	_lowpass.cutoff_hz = 20000.0 * pow(1200.0 / 20000.0, _hurt_level)
	AudioServer.set_bus_volume_db(_world_bus, -3.5 * _hurt_level)


func duck_for(seconds: float) -> void :
	if not is_finite(seconds): return
	_duck_time = maxf(_duck_time, clampf(seconds, 0.0, 6.0))


func stinger(kind: String) -> void :
	if _silent or muted or not STINGERS.has(kind) or not _preview_snapshot.is_empty(): return
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	if now - float(_stinger_clock.get(kind, -1000.0)) < float(STINGER_COOLDOWN.get(kind, 1.0)): return
	_stinger_clock[kind] = now
	for layer: Array in STINGERS[kind]:
		_stinger_queue.append({"family": layer[0], "pitch": layer[1], "gain": layer[2], "delay": layer[3]})
	_duck_time = maxf(_duck_time, 0.45)

func _update_stingers(delta: float) -> void :
	for index: int in range(_stinger_queue.size() - 1, -1, -1):
		var layer: Dictionary = _stinger_queue[index]
		layer.delay = float(layer.delay) - delta
		if float(layer.delay) > 0.0: continue
		_stinger_queue.remove_at(index)
		var variants: Array = effects.get(str(layer.family), [])
		if variants.is_empty() or _stinger_players.is_empty(): continue
		var player: AudioStreamPlayer = _stinger_players[0]
		for candidate: AudioStreamPlayer in _stinger_players:
			if not candidate.playing:
				player = candidate
				break
		player.stream = variants[0]
		player.pitch_scale = float(layer.pitch)
		player.volume_db = linear_to_db(maxf(0.0001, float(layer.gain))) + volume_to_db(effects_volume)
		player.play()




func _watch_world(delta: float) -> void :
	if not is_instance_valid(_world): return
	var phase: String = str(_world.get("phase"))
	if phase != "playing":
		if phase in ["menu", "lobby", "loading"]:
			_exit_open_heard = false
			_escapes_heard = 0
		return
	var flow: Variant = _world.get("exit_flow")
	if flow == null or bool(_world.get("training")): return
	var opened: bool = bool(flow.opened)
	if opened and not _exit_open_heard: stinger("exit_open")
	_exit_open_heard = opened
	var escaped: int = flow.escaped.size()
	if escaped > _escapes_heard: stinger("escape")
	_escapes_heard = escaped
	_ambient_cues(delta)
	_prefetch_clock -= delta
	if _prefetch_clock <= 0.0 and _world.has_method("living_survivors"):
		_prefetch_clock = 1.0
		var living: Array = _world.call("living_survivors")
		if living.size() <= 2:
			for survivor: Variant in living: _request_track("lms_" + str(survivor.character))





func sfx_ability(ability_name: String, source: Vector3, listener: Vector3) -> void :
	var name_lower: String = ability_name.to_lower()


	if name_lower in ["boost de vitesse", "roller boost", "chocolat", "recharge électrique", "true form", "surchauffe", "ombres / bond"]: return


	var kind: String = "ability"
	if "flashbang" in name_lower: kind = "camera_switch"
	elif "drone" in name_lower: kind = "camera_place"
	elif "roller" in name_lower or "boost" in name_lower: kind = "boost"
	elif "shotgun" in name_lower: kind = "shotgun"
	elif "slash" in name_lower: kind = "slash"
	elif "shadow spike" in name_lower: kind = "spike"
	elif "reveal" in name_lower or "xray" in name_lower: kind = "xray"
	elif "ombre" in name_lower or "phase" in name_lower: kind = "shadow"
	elif "surveillance" in name_lower: kind = "camera_switch"
	elif "caméra" in name_lower or "camera" in name_lower: kind = "camera_place"
	elif name_lower == "flash": kind = "flash"
	elif "block" in name_lower: kind = "block"
	elif "punch" in name_lower or "contre" in name_lower: kind = "punch"
	elif "dropkick" in name_lower or "grab" in name_lower: kind = "grab"
	elif "soin" in name_lower: kind = "heal"
	elif "encourag" in name_lower or "crois" in name_lower or "peux" in name_lower: kind = "encourage"
	elif "surchauffe" in name_lower or "consommation" in name_lower: kind = "spike"
	elif "vitesse" in name_lower: kind = "boost"
	sfx(kind, source, listener)

func _priority(family: String) -> int:
	if family.begins_with("step"): return 0
	return int(FX_PRIORITY.get(family, 1))

func _choose_voice(kind: String) -> int:
	var priority: int = _priority(kind)
	if priority == 0:
		var steps: int = 0
		for i in range(voice_pool.size()):
			if voice_pool[i].playing and _voice_priority[i] == 0: steps += 1
		if steps >= 6: return -1
	for offset in range(voice_pool.size()):
		var i: int = (next_voice + offset) % voice_pool.size()
		if not voice_pool[i].playing: return i

	var chosen: int = -1
	for i in range(voice_pool.size()):
		if _voice_priority[i] > priority: continue
		if chosen < 0 or _voice_priority[i] < _voice_priority[chosen] or (_voice_priority[i] == _voice_priority[chosen] and _voice_started[i] < _voice_started[chosen]): chosen = i
	return chosen

func sfx(kind: String, source: Vector3, listener: Vector3, gain_scale: float = 1.0, pitch_scale: float = 1.0) -> void :
	if muted or _preview_paused or voice_pool.is_empty() or effects_volume <= 0.001 or not source.is_finite() or not listener.is_finite(): return
	var step_surface: String = _surface_at(source) if kind == "step" else surface
	var family: String = "step_" + step_surface if kind == "step" else "boost" if kind == "jump" else kind
	var alice_step: bool = false
	if kind == "step":
		var alternate: Array = STEP_ALTERNATES.get(step_surface, [])
		if not alternate.is_empty() and effects.has(alternate[0]) and randf() < float(alternate[1]): family = str(alternate[0])
		alice_step = _killer_at(source)
	if not effects.has(family): return
	var variants: Array = effects[family]
	if variants.is_empty(): return
	var distance: float = source.distance_to(listener)
	var reach: float = float(FX_REACH.get(kind, 38.0))
	if distance > reach: return
	var voice: int = _choose_voice(family)
	if voice < 0: return
	var last: int = int(_last_variants.get(family, -1))
	var variant: int = randi_range(0, variants.size() - 1)
	if variants.size() > 1 and variant == last: variant = (variant + 1) % variants.size()
	_last_variants[family] = variant
	var p: AudioStreamPlayer = voice_pool[voice]
	p.stream = variants[variant];_voice_kinds[voice] = family;next_voice = (voice + 1) % voice_pool.size()
	_voice_priority[voice] = _priority(family);_voice_started[voice] = Time.get_ticks_msec()
	p.pitch_scale = (randf_range(0.975, 1.035) if kind in ["step", "hit", "slash", "punch", "grenade_bounce"] else 1.0) * clampf(pitch_scale, 0.7, 1.3)
	var falloff: float = pow(clampf(1.0 - distance / reach, 0.0, 1.0), 1.25)
	var snow: float = 0.42 if kind == "step" and step_surface == "snow" else 1.0

	if alice_step:
		p.pitch_scale *= 0.84
		snow *= 1.35
	p.volume_db = linear_to_db(maxf(0.0001, falloff * float(FX_GAINS.get(kind, 0.65)) * clampf(gain_scale, 0.0, 1.5) * snow)) + volume_to_db(effects_volume)
	var pan: float = 0.0
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera and distance > 0.4:
		pan = clampf(camera.global_basis.x.dot((source - listener).normalized()) * 0.78, -0.78, 0.78)
	if _panners[voice]: _panners[voice].pan = pan
	p.play()
	if distance < 12.0 and kind in ["hit", "punch", "spike", "shotgun", "flash", "ground_impact"]: _duck_time = 0.3

func _killer_at(position: Vector3) -> bool:
	if not is_instance_valid(_world) or not _world.has_method("killer_actor"): return false
	var killer: Variant = _world.call("killer_actor")
	return killer != null and killer.position.distance_squared_to(position) < 0.01

func receive_event(kind: String, data: Dictionary, listener: Vector3) -> void :



	var now: int = Time.get_ticks_msec()
	var event_id: String = str(data.get("event_id", ""))
	if not event_id.is_empty():
		if _event_cues.has(event_id): return
		_event_cues[event_id] = now
	for key: Variant in _event_cues.keys():
		if now - int(_event_cues[key]) > 15000: _event_cues.erase(key)
	var source: Vector3 = data.get("position", listener)
	if not source.is_finite() or not listener.is_finite(): return
	var actor: int = int(data.get("actor", -1))
	match kind:
		"hit":


			var attack: String = str(data.get("attack", "slash"))
			if attack in ["spike", "shadow"]: sfx("shadow", source, listener, 0.27, 0.86)
			else: sfx("grab", source, listener, 0.24, 0.91)
			if now - int(_recent_body_cues.get(actor, -1000)) > 120:
				sfx("ground_impact", source, listener, 0.26, 0.88)
				_recent_body_cues[actor] = now
		"stun":

			if now - int(_recent_body_cues.get(actor, -1000)) > 120:
				sfx("hit", source, listener, 0.48, 0.9)
				_recent_body_cues[actor] = now
		"downed":
			sfx("ground_impact", source, listener, 0.66, 0.83)
			sfx("grab", source, listener, 0.4, 0.88)
		"death_start":
			if str(data.get("attack", "")) == "bleedout":
				sfx("grab", source, listener, 0.32, 0.84)
				sfx("ground_impact", source, listener, 0.36, 0.8)
			else:
				sfx("shadow" if str(data.get("attack", "")) in ["shadow", "spike"] else "slash", source, listener, 0.5, 0.85)
				sfx("ground_impact", source, listener, 0.62, 0.8)
		"eliminated":
			if not _eliminations_heard.has(actor):
				_eliminations_heard[actor] = true
				stinger("elimination")
		"revive_start":
			sfx("grab", source, listener, 0.45, 1.03)
			if actor >= 0: _recent_body_cues[actor] = now
		"revived":
			sfx("heal", source, listener, 0.9)
			sfx("encourage", source, listener, 0.45)
		"revive_cancel":
			sfx("grab", source, listener, 0.25, 0.9)
		"archive_qte":
			if bool(data.get("ready", false)):
				sfx("camera_switch", source, listener, 0.55, 1.08)
			elif bool(data.get("success", false)):
				sfx("camera_switch", source, listener, 0.65, 1.12)
				sfx("encourage", source, listener, 0.38)
		"archive_alarm":

			sfx("block", source, listener, 0.58, 0.86)
			sfx("bell", source, listener, 0.5, 1.07)
		"dodge":
			sfx("boost", source, listener, 0.43, 1.06)
		"knockback":
			sfx("grab", source, listener, 0.47, 0.85)
		"overheat":
			if bool(data.get("active", false)):
				sfx("grab", source, listener, 0.61, 0.9)
				sfx("shadow", source, listener, 0.36, 1.1)
		"heal_channel":
			if not bool(data.get("cancelled", false)): sfx("heal", source, listener, 0.45)
		"heal":

			if float(data.get("amount", 0.0)) >= 8.0: sfx("heal", source, listener, 0.5)
		"phase6":
			if bool(data.get("active", false)):
				sfx("shadow", source, listener, 0.9, 0.75)
				sfx("ground_impact", source, listener, 0.54, 0.86)
		"boost_charge":
			sfx("grab", source, listener, 0.42, 0.9)
			sfx("boost", source, listener, 0.22, 0.8)
		"boost_release":
			sfx("boost", source, listener, 0.85, 1.08)
			sfx("ground_impact", source, listener, 0.24, 1.1)
		"grenade_aim":
			if bool(data.get("active", false)): sfx("camera_switch", source, listener, 0.32, 1.05)
		"outlet_heal":

			sfx("camera_switch", source, listener, 0.48 if bool(data.get("active", false)) else 0.28, 0.92)
		"chocolate":
			sfx("grab", source, listener, 0.42, 1.12)
		"drone_eaten":
			sfx("grenade_bounce", source, listener, 0.45, 0.84)
			sfx("grab", source, listener, 0.26, 1.1)
		"overheat_charge":
			sfx("boost", source, listener, 0.54, 0.92)
		"true_form_pounce":
			sfx("boost", source, listener, 0.67, 0.78)
			sfx("grab", source, listener, 0.42, 0.8)
		"lysia_explosion":
			sfx("ground_impact", source, listener, 0.82, 0.8)
			sfx("block", source, listener, 0.46, 0.88)
		"stun_immunity":
			sfx("shadow", source, listener, 0.3, 0.9)
		"carry":
			if bool(data.get("active", false)): sfx("grab", source, listener, 0.4, 1.04)
		"shadow_decoys":


			var nearest: Vector3 = source
			var nearest_distance: float = INF
			for decoy: Dictionary in data.get("decoys", []):
				var point: Vector3 = decoy.get("position", source)
				if point.is_finite() and point.distance_squared_to(listener) < nearest_distance:
					nearest = point;nearest_distance = point.distance_squared_to(listener)
			sfx("shadow", nearest, listener, 0.45, 0.88)



func _ambient_cues(delta: float) -> void :
	if not _world.has_method("_listener_position"): return
	var listener: Vector3 = _world.call("_listener_position")
	_presence_clock -= delta
	if _presence_clock <= 0.0:
		_presence_clock = randf_range(16.0, 32.0)
		var me: Variant = _world.call("local_actor") if _world.has_method("local_actor") else null
		var killer: Variant = _world.call("killer_actor") if _world.has_method("killer_actor") else null
		if me != null and killer != null and me.alive and not me.killer and mode == "ambient" and not bool(killer.effects.get("shadow_hide", false)):
			var gap: float = killer.position.distance_to(listener)
			if gap > 12.0 and gap < 36.0: sfx("presence", killer.position + Vector3.UP * 1.5, listener)
	if _map_name() != "forest": return
	_owl_clock -= delta
	if _owl_clock > 0.0: return
	_owl_clock = randf_range(28.0, 60.0)
	var angle: float = randf() * TAU
	sfx("owl", listener + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(22.0, 34.0) + Vector3.UP * 6.0, listener)

func clear_event_history() -> void :
	_event_cues.clear();_recent_body_cues.clear();_eliminations_heard.clear()
	_lms_resume_after_true_form = -1
	_stinger_queue.clear()
	_heart_target = 0.0
	_hurt_target = 0.0
	_exit_open_heard = false
	_escapes_heard = 0
	_fade_speed.clear()
	for player: AudioStreamPlayer in tracks.values(): player.stream_paused = false

	for key: String in tracks:
		if not key.begins_with("lms_") or key == active_track: continue
		var player: AudioStreamPlayer = tracks[key]
		if not player.playing and player.stream != null:
			player.stream = null
			_resume[key] = 0.0

func _exit_tree() -> void :
	for key: Variant in _pending.keys(): ResourceLoader.load_threaded_get(str(_pending[key]))
	_pending.clear()
	for p: AudioStreamPlayer in tracks.values():
		if is_instance_valid(p): p.stop();p.stream = null
	for p: AudioStreamPlayer in voice_pool:
		if is_instance_valid(p): p.stop();p.stream = null
	for p: AudioStreamPlayer in _stinger_players:
		if is_instance_valid(p): p.stop();p.stream = null
	if is_instance_valid(_heart_player): _heart_player.stop();_heart_player.stream = null
	if not _bed_pending.is_empty(): ResourceLoader.load_threaded_get(_bed_pending)
	if is_instance_valid(_bed_player):
		_bed_player.stop()
		_bed_player.stream = null
	tracks.clear();voice_pool.clear();effects.clear();_panners.clear();_stinger_players.clear()
