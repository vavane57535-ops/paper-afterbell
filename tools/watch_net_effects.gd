extends Node

# Côté client : vérifie que les effets 0.16 des survivants arrivent bien par le réseau
# (lancer l'hôte avec --host-test --tool test_mechanics, puis ce client avec --join-test --tool watch_net_effects).

const KEYS: Array[String] = ["outlet_ashura", "sprint_bonus", "lms_hp_cap", "overheat_time", "xray", "outlet_healing"]

var world: Node
var _seen: Dictionary = {}
var _link_seen: bool = false
var _max_hp: Dictionary = {}
var _played: bool = false
var _clock: float = 0.0


func setup(owner: Node) -> void :
	world = owner


func _process(delta: float) -> void :
	_clock += delta
	var playing: bool = str(world.phase) == "playing" and not world.actors.is_empty()
	if playing:
		_played = true
		for actor: PaperActor in world.actors.values():
			for key: String in KEYS:
				if actor.effects.has(key) and not _seen.has(actor.character + "." + key):
					_seen[actor.character + "." + key] = actor.effects[key]
					print("NET_SEEN ", actor.character, ".", key, " = ", actor.effects[key])
			_max_hp[actor.character] = maxf(float(_max_hp.get(actor.character, 0.0)), float(actor.max_hp))
			if actor.character == "Lysia":
				var fx: Node = world.get_node_or_null("SurvivorFx")
				if fx != null and fx.link_active(actor.id) and not _link_seen:
					_link_seen = true
					print("NET_SEEN link_fx Lysia-Ashura on client")
	if _clock > 150.0 or (_played and not playing and _clock > 10.0):
		print("NET_SUMMARY ", JSON.stringify({"seen": _seen.keys(), "link_fx": _link_seen, "max_hp": _max_hp, "networked": world.networked}))
		get_tree().quit()
