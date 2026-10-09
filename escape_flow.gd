class_name PaperEscapeFlow
extends RefCounted

var world: Node
var opened: bool = false
var lms_keeps_exit: bool = false
var escaped: Array[int] = []
var escaped_names: Array[String] = []
var true_form: bool = false

func _init(owner: Node) -> void : world = owner

func clear() -> void :
	opened = false;lms_keeps_exit = false;true_form = false;escaped.clear();escaped_names.clear()
	if world.school: world.school.set_cinematic_exit_open(false)

func is_open() -> bool: return opened

func timer_paused() -> bool:
	var alice: PaperActor = world.killer_actor()
	return alice != null and float(alice.effects.get("phase6", 0)) > 0

func pack() -> Dictionary:
	return {"open": opened, "lms_keeps_exit": lms_keeps_exit, "true_form": true_form, "escaped": escaped.duplicate(), "names": escaped_names.duplicate()}

func unpack(data: Dictionary) -> void :
	var next: bool = bool(data.get("open", false))
	if next != opened: world.school.set_cinematic_exit_open(next)
	opened = next;lms_keeps_exit = bool(data.get("lms_keeps_exit", false));true_form = bool(data.get("true_form", false))
	escaped.assign(data.get("escaped", []));escaped_names.assign(data.get("names", []))
	for id: int in escaped:
		var actor: PaperActor = world.actors.get(id)
		if actor: actor.effects["escaped"] = true;actor.alive = false;actor.visual.hide()

func tick() -> void :
	if world.training or world.phase != "playing": return
	true_form = timer_paused()
	var desired: bool = (world.time_left <= 80.0 or (world.lms and lms_keeps_exit)) and not true_form
	if desired != opened:
		opened = desired;world.school.set_cinematic_exit_open(opened)
		world.event("exit_state", {"state": pack(), "position": world.school.escape_position, "text": "LA SORTIE EST OUVERTE · ÉCHAPPEZ-VOUS" if opened else "TRUE FORM · LA SORTIE SE REFERME" if true_form else "LMS · LA SORTIE SE REFERME"})
	if opened:
		for actor: PaperActor in world.active_survivors():
			var relative: Vector3 = actor.position - world.school.escape_position
			if absf(relative.y) < 1.6 and absf(relative.x) < 2.6 and absf(relative.z) < 1.3: _escape(actor)
	var living: Array[PaperActor] = world.living_survivors()
	if living.is_empty(): world._finish("survivors" if not escaped.is_empty() else "killer");return


	if living.size() == 1 and living[0].active() and not world.lms and escaped.is_empty():
		lms_keeps_exit = opened and float(living[0].effects.get("aura_charge", 0)) >= 100
		world.lms = true
		world.time_left = world.audio.lms_duration(living[0].character)
		world.combat.apply_lms(living[0])
		if opened and not lms_keeps_exit:
			opened = false;world.school.set_cinematic_exit_open(false)
		world.event("exit_state", {"state": pack(), "position": world.school.escape_position, "text": "LMS · AURA COMPLÈTE, SORTIE MAINTENUE" if lms_keeps_exit else "LMS · LA SORTIE S’OUVRIRA AUX 80 DERNIÈRES SECONDES"})
	if world.time_left <= 0:
		world._finish("survivors" if not escaped.is_empty() else "killer")

func _escape(actor: PaperActor) -> void :
	if escaped.has(actor.id): return
	escaped.append(actor.id);escaped_names.append(actor.character)
	world.combat.detach_actor(actor.id)
	actor.effects["escaped"] = true;actor.alive = false;actor.move_input = Vector3.ZERO;actor.velocity = Vector3.ZERO;actor.visual.hide();actor.collider.set_deferred("disabled", true)
	world.event("escaped", {"actor": actor.id, "character": actor.character, "state": pack(), "position": actor.position})
