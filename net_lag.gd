class_name PaperNetLag
extends RefCounted

# Compensation du retard pour les coups (chez l'hôte, 0.17).
# Un coup ne touche une cible que si elle était dans la zone à la fois :
#   1. là où l'attaquant la voyait quand il a frappé (rembobinage de l'historique des corps, borné
#      à MAX_REWIND, seulement si l'attaquant est un joueur distant) ;
#   2. là où la cible se voyait elle-même au moment où son écran montrait ce coup (positions que
#      son client a envoyées, repérées par l'instant de l'hôte qu'il affichait).
# Si les deux ne sont pas d'accord, l'esquive gagne. Pour un joueur distant, la seconde vérification
# attend ses messages (MAX_REWIND au plus), puis tranche avec la position la plus récente connue.
# Les bots et le joueur de l'hôte sont jugés sur l'état de l'hôte, comme avant.

const MAX_REWIND: float = 0.2
const BODY_HISTORY: float = 0.8

var world: Node
var stats: Dictionary = {"immediate": 0, "deferred": 0, "ready": 0, "timeout": 0, "dodged": 0, "landed": 0}
var _bodies: Dictionary = {}
var _queue: Array = []


func _init(owner: Node) -> void :
	world = owner


func active() -> bool:
	return bool(world.networked) and world.authoritative() and str(world.phase) == "playing"


func clear() -> void :
	_bodies.clear()
	_queue.clear()


# Joueur distant dont l'hôte suit la position prédite (et donc ce qu'il voit de lui-même).
func is_followed(actor: Variant) -> bool:
	return actor is PaperActor and is_instance_valid(actor) and (actor as PaperActor).net_follow


# Hôte, à chaque pas physique : historique des corps (pour le rembobinage).
func record() -> void :
	var now: float = float(world.clock)
	for actor: PaperActor in world.actors.values():
		var rows: Array = _bodies.get(actor.id, [])
		if rows.is_empty(): _bodies[actor.id] = rows
		rows.append([now, actor.global_position])
		while rows.size() > 2 and now - float(rows[0][0]) > BODY_HISTORY: rows.pop_front()


func body_at(actor: PaperActor, t: float) -> Vector3:
	var rows: Array = _bodies.get(actor.id, [])
	if rows.is_empty() or t >= float(rows[-1][0]): return actor.global_position
	if t <= float(rows[0][0]): return rows[0][1]
	var i: int = rows.size() - 2
	while i > 0 and float(rows[i][0]) > t: i -= 1
	var a: Array = rows[i]
	var b: Array = rows[i + 1]
	return Vector3(a[1]).lerp(b[1], clampf((t - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001), 0.0, 1.0))


# Position de l'acteur telle qu'il la voyait lui-même quand son écran montrait l'instant t de
# l'hôte. ok = false tant que ses messages ne couvrent pas encore cet instant.
func own_view_at(actor: PaperActor, t: float) -> Dictionary:
	if not is_followed(actor): return {"ok": true, "position": body_at(actor, t)}
	var views: Array = actor.net_motion.views
	if views.is_empty(): return {"ok": false, "position": actor.global_position}
	var last: Array = views[-1]
	if float(last[0]) < t: return {"ok": false, "position": last[1]}
	if t <= float(views[0][0]): return {"ok": true, "position": views[0][1]}
	var i: int = views.size() - 2
	while i > 0 and float(views[i][0]) > t: i -= 1
	var a: Array = views[i]
	var b: Array = views[i + 1]
	return {"ok": true, "position": Vector3(a[1]).lerp(b[1], clampf((t - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001), 0.0, 1.0))}


# Retard de l'écran d'un attaquant distant : de combien rembobiner pour voir ce qu'il voyait.
func rewind_for(source: Variant) -> float:
	if not is_followed(source): return 0.0
	return clampf((source as PaperActor).net_motion.view_lag, 0.0, MAX_REWIND)


# Échantillon d'une attaque en boîte (_sample_attack). Renvoie false pour laisser combat.gd juger
# comme avant (attaquant de l'hôte, aucune cible distante en jeu).
func judge_box(combat: Object, attack: Dictionary, origin: Vector3, source: PaperActor) -> bool:
	if not active(): return false
	var now: float = float(world.clock)
	var rewind: float = rewind_for(source)
	var candidates: Array = []
	var remote: bool = false
	for target: PaperActor in world.actors.values():
		if target.killer == source.killer or attack.hit.has(target.id) or bool(target.effects.get("shadow_hide", false)): continue
		var seen: Vector3 = body_at(target, now - rewind) if rewind > 0.0 else target.global_position
		if not combat._inside_box(origin, attack.aim, attack.size, target, seen): continue
		candidates.append(target.id)
		if is_followed(target): remote = true
	if not remote and rewind <= 0.0: return false
	if candidates.is_empty(): return true
	if not remote:
		var current: Dictionary = {}
		for id: int in candidates: current[id] = (world.actors[id] as PaperActor).global_position
		stats.immediate += 1
		combat._sample_contacts(attack, origin, source, current)
		return true
	stats.deferred += 1
	_queue.append({"kind": "box", "combat": combat, "attack": attack, "origin": origin, "source": source.id, "at": now, "targets": candidates})
	return true


# Coup sur une seule cible (piques, ombres, grenade, fusil…) : touch(position) dit si la cible est
# atteinte à cette position, strike() applique le coup. Renvoie false pour laisser l'ancien code.
func judge(source: Variant, target: PaperActor, touch: Callable, strike: Callable) -> bool:
	if not active() or target == null: return false
	var rewind: float = rewind_for(source)
	var remote: bool = is_followed(target)
	if not remote and rewind <= 0.0: return false
	var now: float = float(world.clock)
	if rewind > 0.0 and not touch.call(body_at(target, now - rewind)): return true
	if not remote:
		stats.immediate += 1
		if touch.call(target.global_position): strike.call()
		return true
	stats.deferred += 1
	_queue.append({"kind": "one", "target": target.id, "at": now, "touch": touch, "strike": strike})
	return true


# Hôte, à chaque pas : tranche les coups dont les positions des cibles distantes sont arrivées.
func tick() -> void :
	if _queue.is_empty(): return
	if not active(): _queue.clear();return
	var now: float = float(world.clock)
	var index: int = 0
	while index < _queue.size():
		var entry: Dictionary = _queue[index]
		var at: float = float(entry.at)
		var late: bool = now - at >= MAX_REWIND
		var ids: Array = entry.targets if entry.kind == "box" else [entry.target]
		var views: Dictionary = {}
		var ready: bool = true
		for id: int in ids:
			var target: PaperActor = world.actors.get(id)
			if target == null: continue
			var view: Dictionary = own_view_at(target, at)
			if not bool(view.ok) and not late: ready = false;break
			views[id] = view.position
		if not ready:
			index += 1
			continue
		_queue.remove_at(index)
		stats["timeout" if late else "ready"] += 1
		if entry.kind == "box":
			var source: PaperActor = world.actors.get(int(entry.source))
			if source == null: continue
			var before: int = (entry.attack.hit as Dictionary).size()
			entry.combat._sample_contacts(entry.attack, entry.origin, source, views)
			stats["landed" if (entry.attack.hit as Dictionary).size() > before else "dodged"] += 1
		else:
			var target: PaperActor = world.actors.get(int(entry.target))
			if target == null or not views.has(target.id): continue
			if (entry.touch as Callable).call(views[target.id]):
				stats.landed += 1
				(entry.strike as Callable).call()
			else: stats.dodged += 1
