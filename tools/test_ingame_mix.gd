extends Node

# Vérification croisée (0.16, après fusion) : élimination par Alice pendant que la sortie est ouverte.
# Le bonus de +45 s fait repasser le chrono au-dessus de 77 s alors que la sortie reste ouverte
# (held_open) : la musique de course doit continuer (pas de trou), le « dernier appel » doit pouvoir
# se rejouer si le bonus a fait ressortir du final, et le chrono doit rester cohérent.
#   godot --headless -- --simulate Simon --duration 120 --tool test_ingame_mix [--mix-kill-at 6] [--mix-final]
# Imprime des lignes « MIX » (état audio toutes les 0,5 s) puis « MIX_RESULT OK|FAIL … ».

var world: Node
var _clock: float = 0.0
var _armed: bool = false
var _open_at: float = -1.0
var _kill_at: float = 6.0
var _final_plan: bool = false
var _killed: int = 0
var _gaps: float = 0.0
var _gap_start: float = -1.0
var _longest_gap: float = 0.0
var _failures: Array[String] = []
var _done: bool = false
var _final_calls: int = 0
var _last_banner: String = ""
var _jumped: bool = false

func setup(game_world: Node) -> void :
	world = game_world
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--mix-kill-at" and i + 1 < args.size(): _kill_at = float(args[i + 1])
		if args[i] == "--mix-final": _final_plan = true

func _note(text: String) -> void :
	print("MIX %.2f %s" % [_clock, text])

func _process(delta: float) -> void :
	if _done or not is_instance_valid(world): return
	_clock += delta
	if world.phase != "playing": return
	if not _armed:
		if float(world.clock) < 3.0: return
		_armed = true
		# bots immobiles : personne ne s'échappe ni ne meurt par hasard pendant la mesure
		for a: PaperActor in world.actors.values(): a.bot = false
		world.time_left = 81.6
		_note("armed")
		return
	if _open_at < 0.0:
		if world.exit_flow.opened:
			_open_at = _clock
			_note("exit opened time_left=%.2f" % world.time_left)
		return
	var since: float = _clock - _open_at
	if _final_plan and not _jumped and since > 3.5:
		# on saute dans le final (après le dernier appel), puis on tue : le chrono ressort du final
		_jumped = true
		world.time_left = 14.0
		_note("jump time_left -> 14")
	var kill_time: float = _kill_at + (2.5 if _final_plan else 0.0)
	if _killed == 0 and since > kill_time: _kill_one()
	if _final_plan and _killed > 0 and _jumped and since > kill_time + 4.0 and float(world.time_left) > 30.0:
		# le bonus a remis le chrono vers 54 s : on revient juste avant le final pour revoir le dernier appel
		world.time_left = 18.2
		_note("jump time_left -> 18.2 (après le bonus)")
	var player: AudioStreamPlayer = world.audio.tracks.get("exit")
	var playing: bool = player != null and player.playing and not player.stream_paused
	# la piste ne joue pas pendant les 3 s de sirène seule de l'ouverture ; ensuite, aucun trou
	if since > 3.4 and str(world.audio.active_track) == "exit":
		if not playing:
			if _gap_start < 0.0: _gap_start = _clock
		elif _gap_start >= 0.0:
			_longest_gap = maxf(_longest_gap, _clock - _gap_start)
			_gap_start = -1.0
	var banner: String = str(world.exit_alarm.get("_banner_title")) if bool(world.exit_alarm.get("_banner").visible) else ""
	if banner != _last_banner:
		_last_banner = banner
		if banner == "DERNIÈRES SECONDES": _final_calls += 1
		if not banner.is_empty(): _note("banner '%s' time_left=%.2f" % [banner, world.time_left])
	if int(_clock * 2.0) != int((_clock - delta) * 2.0):
		_note("t=%.1f time_left=%.1f open=%s mode=%s track=%s pos=%.2f playing=%s rush=%.2f final=%s" % [since, world.time_left, str(world.exit_flow.opened), world.audio.mode, world.audio.active_track, player.get_playback_position() if player else -1.0, str(playing), world.exit_alarm.rush(), str(world.exit_alarm.final_stretch())])
	var end_after: float = kill_time + (22.0 if _final_plan else 14.0)
	if since > end_after: _finish()

func _kill_one() -> void :
	var alice: PaperActor = world.killer_actor()
	for a: PaperActor in world.actors.values():
		if a.killer or not a.alive or a.id == world.local_id(): continue
		a.effects["death_source"] = alice.id if alice else -1
		var before: float = float(world.time_left)
		world.eliminate(a)
		_killed += 1
		_note("eliminated %s (time_left before %.2f)" % [a.character, before])
		return

func _finish() -> void :
	_done = true
	if _gap_start >= 0.0: _longest_gap = maxf(_longest_gap, _clock - _gap_start)
	if _killed == 0: _failures.append("aucune élimination")
	if _longest_gap > 0.6: _failures.append("trou de musique de %.1f s pendant la sortie ouverte" % _longest_gap)
	if not world.exit_flow.opened: _failures.append("sortie refermée après le bonus")
	if _final_plan and _final_calls < 2: _failures.append("dernier appel non rejoué après être ressorti du final (%d)" % _final_calls)
	print("MIX_RESULT ", "OK" if _failures.is_empty() else "FAIL", " ", JSON.stringify({"longest_gap": snappedf(_longest_gap, 0.01), "final_calls": _final_calls, "failures": _failures}))
	get_tree().quit()
