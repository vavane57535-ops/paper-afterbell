extends Node
# Partie simulée jusqu'à une victoire LMS du survivant, par le vrai déroulé :
#   godot --headless -- --simulate Simon --scenario lms --speed 4 --duration 200 --tool test_victory_lms
# Dès que le LMS commence, Alice reste étourdie et le chrono passe sous 80 s pour
# ouvrir la sortie ; le bot survivant s'échappe seul, puis le film de victoire se joue.

var world: Node
var _opened: bool = false
var _reported: bool = false
var _film_seen: float = 0.0


func setup(game_world: Node) -> void :
	world = game_world


func _process(_delta: float) -> void :
	if str(world.phase) == "playing" and bool(world.lms):
		var alice: PaperActor = world.killer_actor()
		if alice: alice.effects["stun"] = 3.0
		if not _opened:
			_opened = true
			world.time_left = minf(float(world.time_left), 79.0)
			print("VICTORY_LMS exit forced open, time_left=", world.time_left)
	if str(world.phase) == "ending":
		if not _reported:
			_reported = true
			var victory: Variant = world.film.get("victory")
			print("VICTORY_LMS ending kind=", world.ending_kind, " outcome=", world.outcome, " focus=", world.ending_focus, " film=", world.film.kind, " victory_active=", victory.active, " person=", victory.person, " room=", victory.room, " turn=", rad_to_deg(victory.turn), " duration=", world.film.duration)
		if not bool(world.ending_presented): _film_seen = maxf(_film_seen, float(world.cinema))
		elif _film_seen > 0.0:
			print("VICTORY_LMS film played to ", _film_seen, " s, results shown")
			_film_seen = -1.0
