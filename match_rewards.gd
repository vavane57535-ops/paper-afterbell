class_name PaperMatchRewards
extends RefCounted


const RATES: Dictionary = {"danger": [1.5, 1.5], "control": [3.0, 5.0], "stun": [6.0, 8.0], "heal": [0.35, 0.35], "boost": [20.0, 22.0], "recharge": [15.0, 18.0], "protection": [18.0, 24.0], "revive": [25.0, 28.0], "damage": [0.3, 0.0], "down": [20.0, 0.0], "elimination": [35.0, 0.0]}
const DANGER_STEP: float = 0.2
var world
var entries: Dictionary = {}
var _seen: Dictionary = {}
var _danger_wait: Dictionary = {}

func _init(owner): world = owner
func clear():
	entries.clear();_seen.clear();_danger_wait.clear()
	for actor in world.actors.values():
		actor.effects["score_points"] = 0.0;actor.effects["aura_charge"] = 0.0
func register(actor):
	if actor == null or actor.killer: return


	if not entries.has(actor.id):
		for previous_id in entries.keys():
			if str(entries[previous_id].character) == str(actor.character) and not world.actors.has(previous_id):
				entries[actor.id] = entries[previous_id];entries.erase(previous_id)
				entries[actor.id]["id"] = actor.id
				break
	var old: Dictionary = entries.get(actor.id, {})
	if old.is_empty() or str(old.character) != str(actor.character):
		entries[actor.id] = {"id": actor.id, "character": actor.character, "name": actor.display_name, "points": 0.0, "aura": 0.0, "grade": "F", "breakdown": {}}
	actor.effects["score_points"] = float(entries[actor.id].points)
	actor.effects["aura_charge"] = maxf(float(actor.effects.get("aura_charge", 0)), float(entries[actor.id].aura))
func record(kind: String, actor, amount: float = 1.0, token: String = ""):
	if actor == null or actor.killer or not world.authoritative() or world.phase != "playing" or bool(world.get("training")) or not RATES.has(kind) or not is_finite(amount) or amount <= 0: return
	register(actor)


	if not token.is_empty():
		var key: String = "%s:%s:%s:%s" % [actor.id, actor.character, kind, token]
		if _seen.has(key): return
		_seen[key] = true
	var rates: Array = RATES[kind]
	var row: Dictionary = entries[actor.id]
	row.points = float(row.points) + amount * float(rates[0])
	row.aura = clampf(float(row.aura) + amount * float(rates[1]), 0, 100)
	row.breakdown[kind] = float(row.breakdown.get(kind, 0.0)) + amount
	row.grade = grade(float(row.points));row.name = actor.display_name
	actor.effects["score_points"] = row.points;actor.effects["aura_charge"] = row.aura
func tick(delta: float):
	if not world.authoritative() or world.phase != "playing" or bool(world.get("training")): return
	var killer = world.killer_actor()
	for actor in world.actors.values():
		register(actor)
		if actor.killer or not actor.active() or killer == null or not killer.active() or float(killer.effects.get("stun", 0)) > 0:
			_danger_wait.erase(actor.id)
			continue


		var waited: float = float(_danger_wait.get(actor.id, float(posmod(int(actor.id), 5)) * 0.04)) + delta
		if waited < DANGER_STEP:
			_danger_wait[actor.id] = waited
			continue
		_danger_wait[actor.id] = 0.0
		if actor.position.distance_to(killer.position) <= 18.0 and world.visible(actor.position, killer.position):
			record("danger", actor, clampf(waited, 0, 0.25))
func results() -> Array[Dictionary]:
	for actor in world.actors.values(): register(actor)
	var rows: Array[Dictionary] = []
	for value in entries.values():
		var row: Dictionary = value.duplicate(true)
		row.points = snappedf(float(row.points), 0.1);row.aura = snappedf(float(row.aura), 0.1);row.grade = grade(float(row.points));rows.append(row)
	rows.sort_custom( func(a: Dictionary, b: Dictionary): return float(a.points) > float(b.points) if not is_equal_approx(float(a.points), float(b.points)) else int(a.id) < int(b.id))
	return rows
static func grade(points: float) -> String:
	if points >= 320: return "S"
	if points >= 220: return "A"
	if points >= 150: return "B"
	if points >= 90: return "C"
	if points >= 50: return "D"
	if points >= 20: return "E"
	return "F"
