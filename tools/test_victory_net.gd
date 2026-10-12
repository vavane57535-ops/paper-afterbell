extends Node
# Vérifie qu'une victoire LMS se joue chez tous les clients (hôte + client LAN).
#   godot --headless -- --host-test --tool test_victory_net --vnet host
#   godot --headless -- --join-test --tool test_victory_net --vnet client
# L'hôte force une victoire LMS du premier survivant ; chaque côté affiche
# « NET_VICTORY <rôle> … » quand le film de victoire démarre chez lui.
# --vnet-team : force une fuite en équipe (fin « ending_survivors ») pour comparer.

var world: Node
var role: String = "host"
var lms_win: bool = true
var _forced: bool = false
var _reported: bool = false
var _clock: float = 0.0
var _playing_since: float = -1.0


func setup(game_world: Node) -> void :
	world = game_world
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		if args[i] == "--vnet" and i + 1 < args.size(): role = args[i + 1]
		if args[i] == "--vnet-team": lms_win = false


func _process(delta: float) -> void :
	_clock += delta
	if role == "host" and not _forced and str(world.phase) == "playing":
		if _playing_since < 0.0: _playing_since = _clock
		var survivors: Array = []
		for actor: PaperActor in world.actors.values():
			if not actor.killer: survivors.append(actor)
		if survivors.size() >= 2 and _clock - _playing_since > 2.0:
			_forced = true
			var hero: PaperActor = survivors[0]
			world.lms = lms_win
			hero.lms = lms_win
			world.exit_flow.escaped.append(hero.id)
			world.exit_flow.escaped_names.append(hero.character)
			print("NET_VICTORY host forcing ", "LMS" if lms_win else "team", " win for ", hero.character)
			world._finish("survivors")
	if not _reported and str(world.phase) == "ending" and not str(world.film.kind).is_empty():
		_reported = true
		var victory: Variant = world.film.get("victory")
		print("NET_VICTORY ", role, " kind=", world.ending_kind, " focus=", world.ending_focus, " film=", world.film.kind, " victory_active=", victory.active if victory else false, " person=", victory.person if victory else "", " duration=", world.film.duration)
		# the host lingers so the client film is not cut by the disconnection
		get_tree().create_timer(3.0 if role != "host" else 7.0).timeout.connect( func() -> void :
			print("NET_VICTORY ", role, " film_time=", world.cinema, " phase=", world.phase)
			get_tree().quit())
