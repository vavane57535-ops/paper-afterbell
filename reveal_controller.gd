class_name PaperRevealController
extends Node





const OCCLUSION_INTERVAL: float = 0.1
const OCCLUSION_BUDGET: int = 2
const REFRESH_INTERVAL: float = 1.0
const HIDDEN: Color = Color(0, 0, 0, 0)
const PROBE_HEIGHTS: Array[float] = [0.35, 1.05, 1.65]

var world: Node3D
var _shown: Dictionary = {}
var _clock: float = 0.0
var _frame: int = 0
var _reason: String = ""
var _query: PhysicsRayQueryParameters3D

func setup(owner: Node3D) -> void :
	world = owner
	_query = PhysicsRayQueryParameters3D.new()
	_query.collision_mask = 3
	_query.collide_with_areas = false

func clear() -> void :
	for entry: Variant in _shown.values():
		var visual: Variant = entry.get("visual")
		if is_instance_valid(visual):
			visual.set_outline(false)
			visual.set_aura(false)
	_shown.clear()

func _downed(actor: PaperActor) -> bool:
	var state: Variant = actor.get("downed")
	return (state is bool and state) or bool(actor.effects.get("downed", false))

func _recoverable(actor: PaperActor) -> bool:
	return (actor.alive or _downed(actor)) and not bool(actor.effects.get("dying", false))

func _weakest(local: PaperActor) -> PaperActor:
	if local.character != "Usayuko": return null
	var chosen: PaperActor = null
	var fraction: float = INF
	for ally: PaperActor in world.actors.values():
		if ally == local or ally.killer or not _recoverable(ally): continue
		var health: float = ally.hp / maxf(1.0, ally.max_hp)
		if health < fraction:
			chosen = ally;fraction = health
	return chosen



func _evaluate(local: PaperActor, target: PaperActor, weakest: PaperActor) -> Color:
	_reason = ""
	if not is_instance_valid(local) or not is_instance_valid(target): return HIDDEN
	if local == target or not _recoverable(local) or not _recoverable(target): return HIDDEN
	if bool(target.effects.get("shadow_hide", false)): return HIDDEN
	if local.killer:
		if target.killer: return HIDDEN
		if float(target.effects.get("archive_alarm", 0.0)) > 0.0:
			_reason = "archive_alarm"
			return Color("ffbb69")
		if float(target.effects.get("lms_reveal", 0.0)) > 0.0:
			_reason = "lms_arrival"
			return Color("f1d78a")
		if float(local.effects.get("reveal", 0.0)) > 0.0 and target.character != "Simon":
			_reason = "shadow_reveal"
			return Color("e36d7e")
	elif target.killer:
		if float(local.effects.get("xray", 0.0)) > 0.0:
			_reason = "xray"
			return Color("e36d7e")
	else:
		if _downed(target):
			_reason = "rescue"
			return Color("ffc97c")
		if target == weakest:
			_reason = "weakest_ally"
			return Color("84dace")
		if float(target.effects.get("help_aura", 0.0)) > 0.0:
			_reason = "help_aura"
			return Color("84dace")
	return HIDDEN


func reveal_for(local: PaperActor, target: PaperActor, weakest: PaperActor = null) -> Dictionary:
	var color: Color = _evaluate(local, target, weakest)
	var fallback: Color = Color("84dace") if is_instance_valid(local) and is_instance_valid(target) and not local.killer and not target.killer else Color("e36d7e")
	return {"visible": color.a > 0.0, "color": color if color.a > 0.0 else fallback, "reason": _reason}

func update_reveals() -> void :
	if not is_instance_valid(world) or str(world.phase) != "playing":
		clear();return
	var local: PaperActor = world.local_actor()
	if not local:
		clear();return
	_clock += get_process_delta_time()
	_frame += 1
	var weakest: PaperActor = _weakest(local)
	var budget: int = OCCLUSION_BUDGET
	for actor: PaperActor in world.actors.values():
		var visual: Variant = actor.visual
		if not is_instance_valid(visual): continue
		var entry: Dictionary = _shown.get(actor.id, {})
		if entry.is_empty() or entry.visual != visual:
			entry = {"visual": visual, "outline": false, "color": HIDDEN, "aura": false, "aura_color": HIDDEN, "occluded": -1, "next_ray": 0.0, "refresh": 0.0, "frame": 0}
			_shown[actor.id] = entry
		entry.frame = _frame
		var color: Color = _evaluate(local, actor, weakest)
		var revealed: bool = color.a > 0.0
		var refresh: bool = _clock >= float(entry.refresh)
		if refresh: entry.refresh = _clock + REFRESH_INTERVAL + randf() * 0.25
		if revealed and visual.has_method("set_outline_occluded"):
			var first: bool = int(entry.occluded) < 0
			if first or (_clock >= float(entry.next_ray) and budget > 0):
				if not first: budget -= 1
				entry.next_ray = _clock + OCCLUSION_INTERVAL
				var hidden: int = 1 if _wall_occludes(actor) else 0
				if hidden != int(entry.occluded) or refresh:
					entry.occluded = hidden
					visual.set_outline_occluded(hidden == 1)
			elif refresh: visual.set_outline_occluded(int(entry.occluded) == 1)
		elif not revealed: entry.occluded = -1
		if refresh or revealed != bool(entry.outline) or (revealed and color != entry.color):
			var turned_on: bool = revealed and not bool(entry.outline)
			entry.outline = revealed
			entry.color = color
			visual.set_outline(revealed, color if revealed else Color("84dace"))

			if turned_on and int(entry.occluded) >= 0 and visual.has_method("set_outline_occluded"): visual.set_outline_occluded(int(entry.occluded) == 1)
		var recovery: bool = actor.killer and float(actor.effects.get("stun_immunity", 0)) > 0
		var aura: bool = recovery or (actor.lms and _recoverable(actor) and not _downed(actor))
		var aura_color: Color = Color("ee384f") if recovery else Color("e8d68d")
		if refresh or aura != bool(entry.aura) or (aura and aura_color != entry.aura_color):
			entry.aura = aura
			entry.aura_color = aura_color
			visual.set_aura(aura, aura_color)
	for id: Variant in _shown.keys():
		var entry: Dictionary = _shown[id]
		if int(entry.frame) == _frame: continue
		if is_instance_valid(entry.visual):
			entry.visual.set_outline(false)
			entry.visual.set_aura(false)
		_shown.erase(id)

func _wall_occludes(target: PaperActor) -> bool:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not camera or not target.is_inside_tree(): return true
	var space: PhysicsDirectSpaceState3D = target.get_world_3d().direct_space_state


	_query.from = camera.global_position
	for height: float in PROBE_HEIGHTS:
		_query.to = target.global_position + Vector3.UP * height
		if not space.intersect_ray(_query).is_empty(): return true
	return false
