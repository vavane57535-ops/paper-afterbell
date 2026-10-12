extends Node

# Essai réseau des exécutions : lancer un hôte et un client headless.
#   godot --headless -- --host-test --duration 70 --tool test_kills_net
#   godot --headless -- --join-test --duration 66 --tool test_kills_net
# L'hôte force trois exécutions (dont Lysia) ; chaque pair affiche ce qu'il a vu.

var world
var seen: Dictionary = {}
var bonuses: int = 0
var forced: int = 0

func setup(w) -> void:
	world = w
	_run.call_deferred()


var _bonus_visible: bool = false

func _process(_delta: float) -> void:
	if world == null or world.kill_scenes == null: return
	var showing: bool = world.kill_scenes._bonus_time >= 0.0 and world.kill_scenes._bonus_time < 0.1
	if showing and not _bonus_visible: bonuses += 1
	_bonus_visible = showing
	for id: Variant in world.kill_scenes._shows.keys():
		if not seen.has(id):
			seen[id] = true
			var show: Dictionary = world.kill_scenes._shows[id]
			print("KILL_NET_SHOW ", "host" if world.authoritative() else "client", " id=", id, " variant=", show.variant, " victim=", show.victim)


func _run() -> void:
	while world.phase != "playing": await get_tree().process_frame
	world.event_count.erase("kill_bonus")
	if not world.authoritative():
		await get_tree().create_timer(58.0).timeout
		_report("client")
		return
	await get_tree().create_timer(4.0).timeout
	for victim_name: String in ["Lysia", "Simon", "Bleuette"]:
		await _force(victim_name)
		await get_tree().create_timer(7.5).timeout
	_report("host")


func _force(victim_name: String) -> void:
	var alice: PaperActor = world.killer_actor()
	var victim: PaperActor = null
	for a: PaperActor in world.actors.values():
		if a.character == victim_name and a.alive: victim = a
	if alice == null or victim == null: return
	victim.global_position = alice.global_position + alice.aim.normalized() * 1.6
	victim.reset_physics_interpolation()
	if victim_name != "Lysia": victim.effects["revived"] = true
	for attempt in range(8):
		world.combat.damage(victim, 999.0, alice, false, "slash")
		if bool(victim.effects.get("dying", false)): break
	forced += 1


func _report(role: String) -> void:
	print("KILL_NET_", role.to_upper(), " shows=", seen.size(), " forced=", forced, " bonus_popups=", bonuses, " time_left=", snappedf(float(world.time_left), 0.1))
