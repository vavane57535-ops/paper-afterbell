class_name PaperFilmEscape
extends Node3D

# Fuites en équipe (« ending_survivors », 63 combinaisons d'élèves), 0.17 : film écrit de A à Z.
# Alice plante sa griffe dans le sol : ses piques d'encre filent jusqu'à la sortie et la
# condamnent. Chacun la retient avec sa capacité (flashbang, drone, poussée, contre, soin,
# encouragement) puis passe la haie de piques : courte échelle, saut, on tire un ami à terre ;
# ceux qui sont passés se retournent et attendent les autres. Alice traverse ses propres piques
# et arrive trop tard sur le dernier. Dehors, chacun craque à sa façon.
# PaperCinema délègue l'écriture (write) et appelle update() à chaque image. Tous les gestes
# viennent de anim_set_film_escape.gd : un clip par acteur, écrit pour ce film.
# Repère E : origine au pied de la porte (3 m avant cinematic_exit), z vers la sortie.

const Anim = preload("res://anim_set_film_escape.gd")
const AnimClip = preload("res://anim_clip.gd")
const AnimLibrary = preload("res://anim_library.gd")

# Ordre de passage : les soutiens d'abord, puis ceux qui retiennent Alice ; Usayuko ferme la marche.
const ORDER: Array[String] = ["Bleuette", "Elly", "Simon", "Ashura", "Lysia", "Usayuko"]
const MOVE: Dictionary = {"Bleuette": 0.8, "Elly": 1.0, "Simon": 1.12, "Ashura": 1.08, "Lysia": 1.05, "Usayuko": 1.3}
const CROSS: Dictionary = {"Bleuette": 1.05, "Elly": 0.85, "Simon": 1.05, "Ashura": 0.82, "Lysia": 1.1, "Usayuko": 0.9}
const KIND: Dictionary = {"Bleuette": "brave", "Elly": "hurdle", "Simon": "flail", "Ashura": "ollie", "Usayuko": "vault"}
const LEGUP: float = 1.32
const DODGE: float = 0.55
const T_SLAM: float = 0.62
const T_HEDGE: float = 1.02
const T_FIRST: float = 2.2
const CELEBRATE: float = 3.5
const ALICE_RUN: float = 5.0
const ALICE_STALK: float = 2.4
const NEAR_Z: float = -1.3
const HEDGE_W: float = 2.9

const GOLD: Color = Color("ffd24a")
const PAPER: Color = Color("fff6e4")
const CRIMSON: Color = Color("ff5a78")

static var _serial: int = 0

var film: PaperCinema
var world: Node
var door_z: float = 12.0
var cast: Array = []
var alice: int = -1
var plan_data: Dictionary = {}
var clip_keys: Array[String] = []
var contacts: Array = []
var _cue_links: Array = []
var _hedge: Node3D
var _thorns: Array = []
var _ink: MeshInstance3D
var _ink_material: StandardMaterial3D
var _breaks: Array = []
var _ink_from: Vector3 = Vector3.ZERO
var _ink_t: float = 0.0


static func duration_for(names: Array) -> float:
	return float(plan(names).duration)


static func lane_of(k: int, n: int) -> float:
	var spacing: float = 0.95 if n > 4 else 1.05
	return (float(k) - float(n - 1) * 0.5) * spacing


# Distribution et minutage, sans carte ni acteur (sert aussi au catalogue de la cinémathèque).
# Alice est simulée en gros : on ne la fait jamais courir plus vite qu'elle ne peut.
static func plan(names: Array) -> Dictionary:
	var team: Array[String] = []
	for person: String in ORDER:
		if person in names: team.append(person)
	if team.is_empty(): team.append("Ashura")
	var n: int = team.size()
	var slots: Array = []
	var t: float = T_FIRST
	var alice_z: float = -12.0
	var alice_free: float = T_SLAM + 0.9
	for k: int in range(n):
		var who: String = team[k]
		var lane: float = lane_of(k, n)
		var near_z: float = NEAR_Z - 0.22 * float(k % 2)
		var solo_dodge: bool = n == 1 and who in ["Bleuette", "Elly"]
		var slot: Dictionary = {"who": who, "k": k, "lane": lane, "near_z": near_z, "dodge": solo_dodge}
		# ce qu'il faut à Alice pour ce geste : être au contact, ou à portée de lancer
		var need_z: float = -100.0
		var offset: float = 0.0
		match who:
			"Usayuko":
				need_z = near_z - 1.75;offset = 0.3
			"Lysia":
				need_z = near_z - 1.15;offset = 0.36
			"Simon":
				need_z = near_z - 5.2;offset = 0.95
			"Ashura":
				need_z = near_z - 4.6;offset = 0.92
			_:
				if solo_dodge:
					need_z = near_z - 1.0;offset = 0.12
		if need_z > -99.0:
			var travel: float = maxf(0.0, need_z - alice_z) / ALICE_RUN
			t = maxf(t, alice_free + travel + 0.15 - offset)
		var d_move: float = float(MOVE[who]) + (DODGE if solo_dodge else 0.0)
		slot["t_move"] = t
		slot["d_move"] = d_move
		slot["hit"] = t + offset + (DODGE if solo_dodge and false else 0.0)
		var method: String = "legup" if who == "Bleuette" and n >= 2 else str(KIND.get(who, "wade"))
		if who == "Lysia": method = "wade"
		slot["method"] = method
		slot["booster"] = team[k + 1] if method == "legup" else ""
		slot["t_cross"] = t + d_move
		slot["d_cross"] = LEGUP if method == "legup" else float(CROSS[who])
		slots.append(slot)
		# Alice après le geste
		match who:
			"Usayuko":
				alice_z = need_z - 1.4;alice_free = t + 0.66 + 1.5
			"Lysia":
				alice_z = need_z - 3.2;alice_free = t + 0.4 + 1.45
			"Simon":
				alice_z = maxf(alice_z, need_z) - 0.55;alice_free = t + 0.95 + 1.3
			"Ashura":
				alice_z = maxf(alice_z, need_z) - 0.25;alice_free = t + 0.92 + 1.0
			_:
				if solo_dodge:
					alice_z = need_z;alice_free = t + 0.6
		t = float(slot.t_cross) + (float(slot.d_cross) + 0.05 if method == "legup" else 0.45)
	var last: Dictionary = slots[slots.size() - 1]
	var t_free: float = float(last.t_cross) + float(last.d_cross)
	var data: Dictionary = {"team": team, "slots": slots}
	# Alice doit pouvoir arriver à la haie pour le coup de griffe final
	var lunge: float = float(last.t_cross) + 0.24
	var reach: float = alice_free + maxf(0.0, -1.75 - alice_z) / ALICE_RUN
	if reach > lunge:
		var push: float = reach - lunge
		last["t_cross"] = float(last.t_cross) + push
		t_free += push
		lunge += push
	data["lunge"] = lunge
	data["free"] = t_free
	data["celebrate"] = t_free + 0.2
	data["duration"] = t_free + 0.2 + CELEBRATE + 0.35
	return data


func write(cinema: PaperCinema) -> void :
	film = cinema;world = cinema.world;name = "Escape"
	door_z = film._length - 3.0
	plan_data = plan(film.people)
	if OS.get_environment("ESC_PLAN") == "1":
		for slot: Dictionary in plan_data.slots: print("PLAN %s move=%.2f cross=%.2f (%.2f) %s" % [slot.who, slot.t_move, slot.t_cross, slot.d_cross, slot.method])
		print("PLAN lunge=%.2f free=%.2f duration=%.2f" % [plan_data.lunge, plan_data.free, plan_data.duration])
	_serial += 1
	alice = film.alice_index
	var length: float = float(plan_data.duration)
	cast.clear()
	for i: int in range(film.takes.size()):
		var take: PaperCinema.Take = film.takes[i]
		var p: Anim.Performer = Anim.Performer.new()
		p.setup(take.visual, take.person, i, length)
		cast.append(p)
		_calm_idle(take.visual)
	_build_hedge()
	_write_story()
	_finish()
	_hook_steps()


func _who(person: String) -> Anim.Performer:
	for p: Anim.Performer in cast:
		if p.person == person and p.index != alice: return p
	return null


# ------------------------------------------------------------------ histoire

func _write_story() -> void :
	var slots: Array = plan_data.slots
	var n: int = slots.size()
	var length: float = float(plan_data.duration)
	var a: Anim.Performer = cast[alice] if alice >= 0 else null
	# 1) la course jusqu'à la haie
	for slot: Dictionary in slots:
		var p: Anim.Performer = _who(str(slot.who))
		var k: int = int(slot.k)
		var lane: float = float(slot.lane)
		var speed: float = 5.0 + 0.25 * Anim.n1(p.seed, 1)
		var start: Vector3 = Vector3(lane * 1.15 + 0.3 * Anim.n1(p.seed, 2), 0.0, -9.6 - 0.55 * float(k % 3) + 0.3 * Anim.n1(p.seed, 3))
		var stop_at: Vector3 = Vector3(lane, 0.0, float(slot.near_z))
		p.start(0.0, start, Vector3(0, 0, speed))
		p.turn(0.0, 0.0, "s")
		p.pose(0.0, Anim.base_pose())
		var brake_start: float = T_HEDGE + 0.06 + 0.05 * float(k % 2)
		var at_brake: Vector3 = start + Vector3(0, 0, speed * brake_start)
		if at_brake.z > stop_at.z - 1.9: at_brake.z = stop_at.z - 1.9
		at_brake.x = lerpf(start.x, stop_at.x, 0.6)
		p.go(brake_start, at_brake, Vector3(0, 0, speed))
		var stop_t: float = brake_start + 0.62 + 0.05 * float(k % 3)
		p.go(stop_t, stop_at, Vector3.ZERO)
		Anim.run(p, 0.0, stop_t + 0.15, {"first": 1 if k % 2 == 0 else -1, "seed": k * 13, "moving": true})
		p.face(0.0, "panic")
		p.face(T_HEDGE + 0.1, "surprise")
		p.ev(T_HEDGE + 0.12, "gasp")
		slot["ready"] = stop_t + 0.15
	# 2) Alice : course, griffe au sol
	if a != null:
		a.start(0.0, Vector3(0.3, 0.0, -14.7), Vector3(0, 0, ALICE_RUN))
		a.turn(0.0, 0.0, "s")
		a.pose(0.0, Anim.base_pose())
		var slam_at: Vector3 = Vector3(0.2, 0.0, -12.0)
		a.go(T_SLAM, slam_at, Vector3.ZERO)
		Anim.alice_run(a, 0.0, T_SLAM + 0.02, {"moving": true, "first": 1})
		a.face(0.0, "menace")
		var hit: float = Anim.alice_slam(a, T_SLAM, 0.0)
		_ink_line(hit, a.at(hit) + Vector3(0, 0, 0.5))
	# 3) chacun son tour : geste, puis passage de la haie ; les premiers passés attendent
	var waiting: Array = []
	var alice_t: float = T_SLAM + 0.95
	for index: int in range(n):
		var slot: Dictionary = slots[index]
		var p: Anim.Performer = _who(str(slot.who))
		var t_move: float = float(slot.t_move)
		var ready: float = float(slot.get("ready", 2.0))
		if not bool(slot.get("turned", false)):
			Anim.pivot(p, ready, ready + 0.45, p.end_p, PI)
			ready += 0.45
		Anim.wait(p, ready, t_move, {"look": 0.4, "seed": index})
		if a != null: alice_t = _alice_meets(a, slot, p, alice_t)
		_write_move(p, slot, a)
		var out_info: Dictionary = _write_cross(p, slot, index, slots, waiting)
		var spot: Vector3 = Vector3(float(slot.lane) * 0.92, 0.0, 2.35 + 0.32 * float(int(slot.k) % 2))
		var t_out: float = float(out_info.out)
		if out_info.has("pulled"): t_out = float(out_info.pulled)
		Anim.step_to(p, t_out, t_out + 0.55, spot, PI, {"seed": 90 + index, "first": -1})
		waiting.append({"p": p, "from": t_out + 0.85, "slot": slot})
	# 4) ceux qui attendent : jusqu'au dernier passage
	var t_free: float = float(plan_data.free)
	var t_party: float = float(plan_data.celebrate)
	for entry: Dictionary in waiting:
		var p: Anim.Performer = entry.p
		var from: float = float(entry.from)
		var busy: Array = entry.get("busy", [])
		if busy.is_empty():
			Anim.wait_out(p, from, t_party, 0.0)
		else:
			Anim.wait_out(p, from, minf(float(busy[0]), t_party), 0.0)
			Anim.wait_out(p, float(busy[1]), t_party, 0.0)
	# 5) trop tard
	if a != null:
		var last: Dictionary = slots[n - 1]
		var lunge: float = float(plan_data.lunge)
		var from: Vector3 = Vector3(float(last.lane) * 0.8, 0.0, -1.75)
		if a.end_t < lunge - 0.05:
			var dist: float = a.end_p.distance_to(from)
			var travel: float = maxf(0.35, dist / ALICE_RUN)
			var leave: float = maxf(a.end_t, lunge - travel)
			a.hold(leave)
			a.turn(leave, a.theta(leave), "s")
			a.turn(leave + 0.2, 0.0, "s")
			a.go(lunge, from, Vector3(0, 0, 3.0))
			Anim.alice_run(a, leave, lunge, {"stop": false, "first": 1, "seed": 7})
		Anim.alice_lunge(a, lunge, float(last.lane))
		film._cue(lunge + 0.36, "word", "miss", {"a": alice, "h": 1.2, "o": Vector3(0, 0, 0.6)}, PAPER, 1.0)
		film._cue(lunge + 0.36, "sound", "slash", {"a": alice}, 0.9)
		Anim.alice_rage(a, lunge + 0.75, length)
		film._cue(lunge + 1.62, "word", "roar", {"a": alice, "h": 2.4}, CRIMSON, 1.25)
		film._cue(lunge + 1.62, "shake", 0.45)
		film._cue(lunge + 1.62, "sound", "shadow", {"a": alice}, 0.8, 0.8)
	# 6) dehors : chacun à sa façon
	for entry: Dictionary in waiting:
		var p: Anim.Performer = entry.p
		var facing: float = PI if p.person in ["Usayuko", "Lysia"] else 0.0
		if p.person == "Elly" or p.person == "Simon": facing = PI * 0.5 if p.end_p.x < 0.0 else - PI * 0.5
		Anim.celebrate(p, t_party + 0.08 * float(int((entry.slot as Dictionary).k)), length, facing)
	film._cue(t_free + 0.1, "event", "escaped", {"position": _f(Vector3(0, 0, 2.6))})
	film._cue(t_free + 0.15, "sound", "encourage", _f(Vector3(0, 1, 2.5)))
	film._cue(t_free + 0.3, "sparkles", _f(Vector3(0, 1.5, 2.5)), GOLD, 8, 1.4)
	film._cue(t_free + 0.2, "pulse", Color(1.0, 0.92, 0.6, 0.3), 1.2)
	_write_camera()


# Alice va au contact (ou à portée) pour le geste de ce créneau ; rend l'instant où elle est en place.
func _alice_meets(a: Anim.Performer, slot: Dictionary, p: Anim.Performer, alice_t: float) -> float:
	var who: String = str(slot.who)
	var near: Vector3 = Vector3(float(slot.lane), 0.0, float(slot.near_z))
	var x: float = float(slot.lane) * 0.85
	var target: Vector3
	var arrive: float = float(slot.hit)
	match who:
		"Usayuko": target = Vector3(x, 0.0, near.z - 1.75)
		"Lysia": target = Vector3(x, 0.0, near.z - 1.12)
		"Simon": target = Vector3(x * 0.5, 0.0, minf(a.end_p.z + 2.2, near.z - 5.2))
		"Ashura": target = Vector3(x * 0.5, 0.0, minf(a.end_p.z + 2.6, near.z - 4.6))
		_:
			if bool(slot.dodge): target = Vector3(x, 0.0, near.z - 1.0)
			else:
				# elle avance lentement, sans aller au contact
				arrive = float(slot.t_move) + float(slot.d_move)
				target = Vector3(x * 0.4, 0.0, minf(near.z - 4.0, a.end_p.z + ALICE_STALK * maxf(0.0, arrive - maxf(a.end_t, alice_t))))
	var start_t: float = maxf(a.end_t, alice_t)
	var dist: float = a.end_p.distance_to(target)
	if dist > 0.1 and arrive > start_t + 0.15:
		var speed: float = dist / (arrive - start_t)
		var leave: float = start_t
		if speed < ALICE_STALK * 0.6:
			leave = arrive - dist / (ALICE_STALK * 0.8)
			a.hold(leave)
			Anim.wait(a, start_t, leave, {"pose": Anim.neutral("Alice"), "face": "menace", "seed": 5})
		a.turn(leave, a.theta(leave), "s")
		a.turn(leave + 0.2, Anim.heading_of(target - a.end_p) if dist > 0.4 else a.theta(leave), "s")
		a.go(arrive, target, Vector3.ZERO)
		Anim.alice_run(a, leave, arrive + 0.1, {"first": 1 if int(slot.k) % 2 == 0 else -1, "seed": int(slot.k) * 5})
	elif a.end_t < arrive:
		a.hold(arrive)
	var face_p: float = Anim.heading_of(p.end_p - a.end_p) if (p.end_p - a.end_p).length() > 0.3 else 0.0
	var now: float = a.theta(arrive)
	a.turn(arrive + 0.05, now + wrapf(face_p - now, -PI, PI), "s")
	return arrive


# Le geste d'un élève, et ce qu'il fait à Alice.
func _write_move(p: Anim.Performer, slot: Dictionary, a: Anim.Performer) -> void :
	var t: float = float(slot.t_move)
	var who: String = str(slot.who)
	var i: int = p.index
	var theta: float = PI
	if a != null and (a.end_p - p.end_p).length() > 0.3: theta = Anim.heading_of(a.end_p - p.end_p)
	theta = p.theta(t) + wrapf(theta - p.theta(t), -PI, PI)
	if bool(slot.dodge) and a != null:
		# seule : Alice frappe, elle plonge sous la griffe
		Anim.alice_whiff(a, t + 0.05)
		_dodge(p, t, theta)
		film._cue(t + 0.24, "word", "miss", {"a": i, "h": 1.5}, PAPER, 0.85)
		film._cue(t + 0.2, "sweat", {"a": i, "s": "head"}, 2)
		t += DODGE
	match who:
		"Bleuette":
			var at: float = Anim.cheer_on(p, t, theta if bool(slot.dodge) else p.theta(t))
			film._cue(at, "word", "go", {"a": i, "h": 2.0}, Color("ffb7cf"), 0.95)
			film._cue(at, "sound", "encourage", {"a": i}, 0.8)
			for other: Anim.Performer in cast:
				if other.index == alice: continue
				film._cue(at + 0.1 + 0.06 * float(other.index), "event", "boost", {"position": {"a": other.index}})
		"Elly":
			var at: float = Anim.heal(p, t, theta if bool(slot.dodge) else p.theta(t))
			film._cue(at, "event", "zone", {"position": {"a": i}, "radius": 3.6})
			film._cue(at + 0.05, "pulse", Color(0.45, 1.0, 0.75, 0.2), 0.7)
			film._cue(at, "sound", "heal", {"a": i}, 0.7)
			for other: Anim.Performer in cast:
				if other.index == alice or other.index == i: continue
				film._cue(at + 0.2 + 0.07 * float(other.index), "event", "heal", {"position": {"a": other.index}})
		"Simon":
			var release: float = Anim.flash(p, t, theta)
			var land: float = release + 0.38
			film._flights.append([release, land, "grenade", {"a": i, "s": "hand_r"}, {"a": alice, "h": 0.15, "o": Vector3(0, 0, 0.6)}, 1.1, 0.0])
			film._cue(release, "sound", "grenade_throw", {"a": i})
			film._cue(land, "sound", "grenade_bounce", {"a": alice})
			film._cue(land + 0.05, "event", "grenade", {"action": "explode", "id": -7, "position": {"a": alice, "h": 0.0, "o": Vector3(0, 0, 0.6)}})
			film._cue(land + 0.05, "sound", "flash", {"a": alice})
			film._cue(land + 0.05, "shake", 0.4)
			film._cue(land + 0.05, "impact", 0.55, false)
			film._cue(land + 0.1, "word", "flash", {"a": alice, "h": 2.1}, Color("fff3a0"), 1.0)
			if a != null:
				a.hold(land + 0.05)
				Anim.alice_flashed(a, land + 0.05, a.theta(land))
		"Ashura":
			var release: float = Anim.drone(p, t, theta)
			var hit: float = release + 0.48
			film._flights.append([t + 0.26, release, "drone", {"a": i, "s": "hand_r"}, {"a": i, "s": "hand_r"}, 0.0, 0.0])
			film._flights.append([release, hit, "drone", {"a": i, "s": "hand_r"}, {"a": alice, "s": "head"}, 0.35, 0.6])
			film._cue(release, "sound", "drone", {"a": i}, 0.7)
			film._cue(hit, "event", "drone", {"action": "impact", "position": {"a": alice, "s": "head"}})
			film._cue(hit, "sound", "ground_impact", {"a": alice}, 0.8)
			film._cue(hit, "shake", 0.3)
			film._cue(hit, "word", "boom", {"a": alice, "h": 2.2}, Color("c6b5f9"), 0.85)
			if a != null:
				a.hold(hit)
				Anim.alice_droned(a, hit, a.theta(hit))
		"Lysia":
			film._cue(t, "event", "overheat", {"position": {"a": i}, "active": true})
			if a != null: Anim.alice_slash(a, t + 0.18)
			var impact: float = Anim.push(p, t, theta)
			film._cue(impact, "word", "push", {"a": i, "h": 2.1}, Color("a6f0d8"), 1.0)
			film._cue(impact, "shake", 0.45)
			film._cue(impact, "impact", 0.6, false)
			film._cue(impact, "sound", "block", {"a": i}, 0.9, 0.8)
			film._cue(impact + 0.3, "word", "hot", {"a": i, "h": 1.5, "o": Vector3(0.3, 0, -0.3)}, Color("ffcf8a"), 0.7)
			if a != null:
				a.hold(impact)
				Anim.alice_pushed(a, impact, a.theta(impact), 3.2)
		"Usayuko":
			if a != null: Anim.alice_slash(a, t + 0.2)
			var beats: Array = Anim.counter(p, t, theta)
			film._cue(float(beats[0]), "event", "block", {"position": {"a": i}})
			film._cue(float(beats[0]), "sound", "block", {"a": i})
			film._cue(float(beats[0]), "word", "block", {"a": i, "h": 2.0}, Color("ffe3a0"), 0.9)
			film._cue(float(beats[0]), "shake", 0.25)
			var hook: float = float(beats[1])
			film._cue(hook, "pop", {"a": alice, "h": 1.5}, Vector3(0, 0, -1), GOLD, 1.2)
			film._cue(hook, "word", "counter", {"a": alice, "h": 2.0}, GOLD, 1.15)
			film._cue(hook, "stars", {"a": alice, "s": "over"}, 4)
			film._cue(hook, "sound", "hit", {"a": alice})
			film._cue(hook, "shake", 0.5)
			film._cue(hook, "impact", 0.65, true)
			if a != null:
				a.hold(hook)
				Anim.alice_countered(a, hook, a.theta(hook))


func _dodge(p: Anim.Performer, t: float, theta: float) -> void :
	var s: Vector3 = p.end_p
	var side_dir: Vector3 = Anim.leftward(theta) * (1.0 if p.person == "Elly" else -1.0)
	var to: Vector3 = s + side_dir * 0.45 + Anim.ahead(theta) * -0.15
	p.hold(t + 0.1)
	p.go(t + 0.3, to, Vector3.ZERO)
	p.hold(t + DODGE)
	Anim.run(p, t + 0.05, t + DODGE, {"stop": true, "first": 1, "no_upper": true, "seed": 3})
	Anim.keys(p, t, [
		[0.0, {"face": "fear"}],
		[0.12, Anim.M([Anim.H(0, -0.3, 0), Anim.B(0.35, 0.0, 0.15), Anim.C(0.15), Anim.HD(-0.3, 0.0, 0.1), Anim.Lt(0.0, 0.45, 0.2, 0.6), Anim.Rt(0.0, 0.48, 0.22, 0.6), Anim.WL(0.8), Anim.WR(0.8), {"curl": 0.4, "curl_l": 0.4, "ev": "gasp", "face": "panic"}])],
		[0.32, Anim.M([Anim.H(0, -0.34, 0), Anim.B(0.4, 0.0, 0.1), Anim.HD(-0.25, 0.1, 0.1), {"shake": 0.4}])],
		[0.52, Anim.M([Anim.tense(p.person), {"shake": 0.0, "face": "fear"}])],
	])


# Passage de la haie selon le perso et l'équipe. Rend {"out": instant où il repart, ["pulled"]}.
func _write_cross(p: Anim.Performer, slot: Dictionary, index: int, slots: Array, waiting: Array) -> Dictionary:
	var t: float = float(slot.t_cross)
	var method: String = str(slot.method)
	var lane: float = float(slot.lane)
	# il se retourne vers la haie
	var face_door: float = p.theta(t) + wrapf(0.0 - p.theta(t), -PI, PI)
	if absf(face_door - p.theta(t)) > 0.3:
		Anim.pivot(p, t - 0.02, t + 0.3, p.end_p, face_door)
		t += 0.3
	if method == "legup":
		var b: Anim.Performer = _who(str(slot.booster))
		var side: float = 1.0 if lane < 0.0 else -1.0
		var info: Dictionary = Anim.legup(p, b, t + 0.05, lane, side)
		var window: Array = info.foot
		for side_hand: int in [-1, 1]:
			contacts.append({"who": b.index, "side": side_hand, "t0": float(window[0]) - 0.04, "t1": float(window[1]) + 0.06, "to": p.index, "socket": "foot_r", "offset": Vector3(0.05 * float(side_hand), -0.06, 0.0), "in": 0.06, "out": 0.08})
		var next: Dictionary = slots[index + 1]
		next["turned"] = false
		next["ready"] = float(info.free)
		_hedge_dust(t + 0.7, lane)
		return {"out": float(info.out)}
	if method == "wade":
		var info: Dictionary = Anim.wade(p, t)
		_breaks.append({"x": lane, "t0": float(info.break_from), "t1": float(info.break_to)})
		film._cue(float(info.break_from) + 0.15, "word", "break", _f(Vector3(lane, 1.1, 0.0)), PAPER, 0.85)
		film._cue(float(info.break_from) + 0.15, "sound", "block", _f(Vector3(lane, 0.6, 0.0)), 0.7, 1.4)
		film._cue(float(info.break_from) + 0.4, "word", "zap", _f(Vector3(lane + 0.4, 1.4, 0.2)), Color("a6f0d8"), 0.7)
		return {"out": float(info.out)}
	var kind: String = method
	var info: Dictionary = Anim.hedge_jump(p, t, kind, {"face": "fear" if kind in ["brave", "flail"] else "determined"})
	_hedge_dust(float(info.take) + 0.2, lane)
	var result: Dictionary = {"out": float(info.out)}
	if kind == "flail":
		# à quatre pattes : quelqu'un vient le relever, sinon il se relève tout seul
		var helper: Dictionary = {}
		for pick: String in ["Elly", "Bleuette", "Ashura", "Usayuko", "Lysia"]:
			for entry: Dictionary in waiting:
				if (entry.p as Anim.Performer).person == pick and float(entry.from) < float(info.land) + 0.2:
					helper = entry
					break
			if not helper.is_empty(): break
		if not helper.is_empty():
			var h: Anim.Performer = helper.p
			var fallen: Vector3 = p.at(float(info.out))
			var t_help: float = float(info.out) - 0.15
			var window: Array = Anim.pull_up(h, p, t_help, fallen)
			contacts.append({"who": h.index, "side": 1, "t0": float(window[0]), "t1": float(window[1]), "to": p.index, "socket": "hand_r", "mutual": true, "in": 0.06, "out": 0.08})
			# l'aide reprend sa place
			var spot: Vector3 = Vector3(h.end_p.x, 0.0, h.end_p.z + 0.65)
			Anim.step_to(h, t_help + 1.3, t_help + 1.75, spot, PI, {"seed": 66})
			helper["busy"] = [t_help - 0.05, t_help + 1.85]
			result["pulled"] = t_help + 1.25
		else:
			_get_up(p, float(info.out))
			result["out"] = float(info.out) + 0.7
	return result


func _get_up(p: Anim.Performer, t: float) -> void :
	p.hold(t + 0.7)
	p.plant(-1, p.foot_free[-1], t + 0.7, p.foot_at[-1])
	p.plant(1, p.foot_free[1], t + 0.7, p.foot_at[1])
	Anim.keys(p, t, [
		[0.0, Anim.M([Anim.H(0, -0.5, 0.3), Anim.B(0.95), Anim.HD(0.7), Anim.Lg(0.25, 0.42, 0.0), Anim.Rg(0.25, 0.46, 0.0), {"el_l": 0.5, "el_r": 0.5, "face": "hurt"}])],
		[0.3, Anim.M([Anim.H(0, -0.3, 0.12), Anim.B(0.6), Anim.HD(0.4), Anim.Lg(0.25, 0.3, 0.1), Anim.R(0.3, -0.6, 0.3, 0.3), {"ev": "effort"}])],
		[0.6, Anim.M([Anim.neutral(p.person), Anim.HD(0.1, -0.2), {"face": "fear"}])],
	])


# ------------------------------------------------------------------ caméra

func _write_camera() -> void :
	var slots: Array = plan_data.slots
	var n: int = slots.size()
	# A. de face, bas, dans le hall : ils foncent vers nous, Alice derrière
	film._shot(0.0, {"rel": _f(Vector3(0.9, 0.0, -0.8)), "eye": [Vector3(0, 0.55, 0), Vector3(0, 0.6, -0.4)], "look": [_f(Vector3(0, 1.0, -9.0)), _f(Vector3(0, 0.9, -6.5))], "fov": [38.0, 42.0], "hand": 0.4, "safe": false})
	# B. la griffe dans le sol, en contre-plongée de côté
	if alice >= 0: film._shot(T_SLAM - 0.05, {"rel": {"a": alice}, "eye": [Vector3(-1.9, 0.35, 1.9), Vector3(-1.7, 0.3, 1.6)], "look": {"a": alice, "h": 0.6}, "fov": 40.0, "hand": 0.5})
	# C. depuis dehors, la haie jaillit au premier plan, ils freinent vers nous
	film._shot(T_HEDGE - 0.12, {"rel": _f(Vector3(0.6, 0.0, 3.3)), "eye": [Vector3(0, 0.75, 0), Vector3(0, 0.8, 0.25)], "look": [_f(Vector3(0, 0.75, -2.0)), _f(Vector3(0, 0.95, -2.2))], "fov": [48.0, 44.0], "hand": 0.5, "safe": false})
	for index: int in range(n):
		var slot: Dictionary = slots[index]
		var p: Anim.Performer = _who(str(slot.who))
		var t: float = float(slot.t_move)
		var side: float = 1.0 if index % 2 == 0 else -1.0
		if float(slot.lane) * side > 0.8: side = - side
		# le geste : plan de profil sur l'élève et Alice
		if alice >= 0: film._shot(t - 0.08, {"rel": {"mid": [p.index, alice]}, "span": [p.index, alice], "eye": [Vector3(side * 3.1, 1.2, 0.3), Vector3(side * 2.8, 1.1, 0.1)], "look": {"mid": [p.index, alice], "h": 1.05}, "fov": [44.0, 41.0], "hand": 0.45})
		# le passage : depuis dehors, à travers la porte
		var tc: float = float(slot.t_cross) + 0.18
		var cross_eye: Vector3 = Vector3(float(slot.lane) * 0.4 - side * 1.4, 0.55, 3.6)
		film._shot(tc, {"rel": _f(Vector3(float(slot.lane), 0.0, 0.0)), "eye": [cross_eye, cross_eye + Vector3(0, 0.1, 0.35)], "look": [_f(Vector3(float(slot.lane), 0.9, -0.8)), _f(Vector3(float(slot.lane), 0.8, 0.6))], "fov": [46.0, 50.0], "hand": 0.5, "safe": false})
	# D. trop tard : la griffe passe la porte, plan serré de côté
	var lunge: float = float(plan_data.lunge)
	var last: Dictionary = slots[n - 1]
	film._shot(lunge - 0.05, {"rel": _f(Vector3(float(last.lane), 0.0, 0.2)), "eye": [Vector3(2.8, 0.7, 0.6), Vector3(2.6, 0.75, 0.4)], "look": _f(Vector3(float(last.lane), 0.8, 0.1)), "fov": 42.0, "hand": 0.35, "safe": false})
	# E. dehors : le groupe, la porte et Alice derrière ses piques
	var party: float = float(plan_data.celebrate)
	var wide: float = 4.2 + 0.35 * float(n)
	film._shot(party + 0.15, {"rel": _f(Vector3(0, 0.0, 2.6)), "eye": [Vector3(-1.2, 1.25, wide), Vector3(-0.9, 1.3, wide - 0.6)], "look": [_f(Vector3(0, 1.0, 2.0)), _f(Vector3(0, 1.1, 1.6))], "fov": [46.0, 42.0], "hand": 0.3, "safe": false})
	var length: float = float(plan_data.duration)
	film._shot(length - 1.35, {"rel": _f(Vector3(0, 0.0, 0.0)), "eye": [Vector3(1.6, 1.5, 4.8), Vector3(1.4, 1.55, 5.3)], "look": [_f(Vector3(0, 1.1, 0.4)), _f(Vector3(0, 1.3, -0.4))], "fov": [38.0, 33.0], "hand": 0.2, "safe": false})


# ------------------------------------------------------------------ accessoires

# Point du repère E → point film-local de PaperCinema.
func _f(e: Vector3) -> Vector3:
	return Vector3(e.x, e.y, door_z + e.z)


func _hedge_dust(t: float, lane: float) -> void :
	film._cue(t, "dust_ring", _f(Vector3(lane, 0.05, 0.0)), 0.6)


# La haie de piques d'encre en travers de la porte (z ∈ [-0.3, 0.3]), qui jaillit du centre vers
# les bords quand la ligne d'encre arrive ; Lysia en casse sur son passage.
func _build_hedge() -> void :
	_hedge = Node3D.new();_hedge.name = "Hedge";add_child(_hedge)
	var basis: Basis = Basis(film.right, Vector3.UP, film.forward)
	_hedge.global_transform = Transform3D(basis, film.anchor + film.forward * door_z)
	var dark: StandardMaterial3D = StandardMaterial3D.new()
	dark.albedo_color = Color("2a1430");dark.roughness = 0.55;dark.metallic = 0.1
	dark.emission_enabled = true;dark.emission = Color("5a0f2a");dark.emission_energy_multiplier = 0.35
	var tip: StandardMaterial3D = StandardMaterial3D.new()
	tip.albedo_color = Color("c2304f");tip.emission_enabled = true;tip.emission = Color("ff3355");tip.emission_energy_multiplier = 0.9
	var count: int = 46
	for k: int in range(count):
		var u: float = float(k) / float(count - 1)
		var x: float = lerpf( - HEDGE_W, HEDGE_W, u) + 0.05 * Anim.n1(5, k)
		var row: int = k % 3
		var z: float = [-0.2, 0.05, 0.24][row] + 0.06 * Anim.n1(7, k)
		var height: float = (0.62 + 0.3 * absf(Anim.n1(11, k))) * (0.85 if row == 2 else 1.0)
		var radius: float = 0.07 + 0.04 * absf(Anim.n1(13, k))
		var root: Node3D = Node3D.new()
		root.position = Vector3(x, 0.0, z)
		root.rotation = Vector3(0.25 * Anim.n1(17, k), 0.0, 0.3 * Anim.n1(19, k))
		_hedge.add_child(root)
		var spike: MeshInstance3D = MeshInstance3D.new()
		var mesh: CylinderMesh = CylinderMesh.new()
		mesh.top_radius = 0.0;mesh.bottom_radius = radius;mesh.height = height;mesh.radial_segments = 6;mesh.rings = 1
		spike.mesh = mesh;spike.material_override = dark;spike.position = Vector3(0, height * 0.5, 0)
		root.add_child(spike)
		var point: MeshInstance3D = MeshInstance3D.new()
		var cone: CylinderMesh = CylinderMesh.new()
		cone.top_radius = 0.0;cone.bottom_radius = radius * 0.32;cone.height = height * 0.28;cone.radial_segments = 6;cone.rings = 1
		point.mesh = cone;point.material_override = tip;point.position = Vector3(0, height * 0.86, 0)
		root.add_child(point)
		var delay: float = absf(x) / HEDGE_W * 0.22 + 0.03 * absf(Anim.n1(23, k))
		_thorns.append({"node": root, "x": x, "delay": delay, "tilt": root.rotation})
	_hedge.visible = false
	# la ligne d'encre au sol
	_ink = MeshInstance3D.new()
	var plane: BoxMesh = BoxMesh.new();plane.size = Vector3(0.34, 0.012, 1.0)
	_ink.mesh = plane
	_ink_material = StandardMaterial3D.new();_ink_material.albedo_color = Color("16081c");_ink_material.roughness = 0.3
	_ink_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ink_material.emission_enabled = true;_ink_material.emission = Color("4a0a24");_ink_material.emission_energy_multiplier = 0.5
	_ink.material_override = _ink_material
	_ink.visible = false
	add_child(_ink)


func _ink_line(t: float, from: Vector3) -> void :
	_ink_from = from;_ink_t = t
	film._cue(t, "crack", _f(from), 1.4)
	film._cue(t, "sound", "shadow", _f(from), 0.9, 1.2)
	film._cue(T_HEDGE + 0.05, "word", "seal", _f(Vector3(0, 1.6, 0.4)), CRIMSON, 1.15)
	film._cue(T_HEDGE + 0.05, "shake", 0.45)
	film._cue(T_HEDGE + 0.05, "impact", 0.5, true)
	film._cue(T_HEDGE + 0.05, "sound", "ground_impact", _f(Vector3(0, 0.3, 0.0)), 0.9, 0.8)
	film._cue(T_HEDGE + 0.1, "word", "thorn", _f(Vector3(1.6, 1.1, 0.2)), Color("d86ad0"), 0.8)


func update(t: float, _delta: float) -> void :
	_update_ink(t)
	_update_hedge(t)
	_apply_contacts(t)


func _update_ink(t: float) -> void :
	if not is_instance_valid(_ink): return
	var travel: float = clampf((t - _ink_t) / maxf(T_HEDGE - _ink_t, 0.05), 0.0, 1.0)
	var fade: float = 1.0 - smoothstep(T_HEDGE + 0.3, T_HEDGE + 1.6, t)
	_ink.visible = t >= _ink_t and fade > 0.01
	if not _ink.visible: return
	var head: Vector3 = _ink_from.lerp(Vector3(_ink_from.x * 0.3, 0.0, -0.2), travel)
	var length: float = maxf(0.05, _ink_from.distance_to(head))
	var mid: Vector3 = (_ink_from + head) * 0.5
	var dir: Vector3 = (head - _ink_from).normalized() if length > 0.06 else Vector3(0, 0, 1)
	var basis: Basis = Basis(film.right, Vector3.UP, film.forward)
	var world_mid: Vector3 = film.anchor + basis * _f(mid + Vector3(0, 0.012, 0))
	var yaw: float = atan2(dir.x, dir.z)
	_ink.global_transform = Transform3D(basis * Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(1.0 + 0.5 * (1.0 - fade), 1.0, length)), world_mid)
	_ink_material.albedo_color.a = fade


func _update_hedge(t: float) -> void :
	if not is_instance_valid(_hedge): return
	_hedge.visible = t >= T_HEDGE - 0.02
	if not _hedge.visible: return
	for thorn: Dictionary in _thorns:
		var node: Node3D = thorn.node
		var u: float = (t - T_HEDGE - float(thorn.delay)) / 0.16
		var grow: float = 0.0
		if u > 0.0: grow = minf(smoothstep(0.0, 1.0, u) * 1.18, 1.0 + 0.18 * sin(minf(u, 3.0) * 2.2) * exp(-u * 0.9))
		var tilt: Vector3 = thorn.tilt
		for cut: Dictionary in _breaks:
			var gap: float = absf(float(thorn.x) - float(cut.x))
			if gap < 0.42:
				var k: float = clampf((t - float(cut.t0) - gap * 0.3) / 0.25, 0.0, 1.0)
				grow *= lerpf(1.0, 0.32, k)
				tilt = tilt + Vector3(0.9 * k, 0.0, signf(float(thorn.x) - float(cut.x)) * 0.6 * k)
		node.scale = Vector3(1.0, maxf(grow, 0.001), 1.0)
		node.rotation = tilt
		node.visible = grow > 0.002


# Contacts précis (mains de l'aide sous le pied de la grimpeuse, mains qui se tiennent) :
# IK appliquée après l'animation, comme kill_scenes.gd.
func _apply_contacts(t: float) -> void :
	for c: Dictionary in contacts:
		var t0: float = float(c.t0)
		var t1: float = float(c.t1)
		if t < t0 or t > t1: continue
		var w: float = smoothstep(t0, t0 + float(c.get("in", 0.08)), t) * (1.0 - smoothstep(t1 - float(c.get("out", 0.08)), t1, t))
		var holder: PaperVisual = film.takes[int(c.who)].visual
		var other: PaperVisual = film.takes[int(c.to)].visual
		if not is_instance_valid(holder) or not is_instance_valid(other) or not holder.is_inside_tree(): continue
		var target: Vector3 = other.socket_position(str(c.socket)) + film._world_direction(c.get("offset", Vector3.ZERO))
		if bool(c.get("mutual", false)):
			var mine: Vector3 = holder.socket_position("hand_r")
			var meet: Vector3 = (mine + target) * 0.5
			_reach(holder, int(c.side), meet, w)
			_reach(other, 1, meet, w)
		else:
			_reach(holder, int(c.side), target, w)


func _reach(visual: PaperVisual, side: int, target: Vector3, weight: float) -> void :
	if weight <= 0.001 or not is_instance_valid(visual._body) or not target.is_finite(): return
	var hand: Node3D = visual._right_hand if side > 0 else visual._left_hand
	var local: Vector3 = visual._body.global_transform.affine_inverse() * target
	visual._hand_target_weighted(side, local, clampf(weight, 0.0, 1.0), hand.quaternion, 1.0)
	visual._sync_now()


# ------------------------------------------------------------------ assemblage

func _finish() -> void :
	for i: int in range(cast.size()):
		var p: Anim.Performer = cast[i]
		var length: float = p.duration
		p.hold(length + 0.5)
		# racine : échantillons serrés, reliés en ligne droite par la timeline du film
		film._put(i, _f(p.at(0.0)))
		var t: float = Anim.GRID
		while t <= length + 0.0001:
			film._move(i, t - Anim.GRID, t, _f(p.at(t)), "linear")
			t += Anim.GRID
		film._face(i, 0.0, "dir", Vector3(0, 0, 1))
		var clip_name: String = "fesc%d_%s" % [_serial, p.person]
		var source: Dictionary = p.compile_source(clip_name)
		var compiled: Dictionary = AnimClip.compile(source)
		var cache_key: String = clip_name + "@" + p.person
		AnimLibrary._cache[cache_key] = compiled
		clip_keys.append(cache_key)
		film._do(i, 0.0, "play", clip_name)
		if OS.is_debug_build() and p.overreach > 0.02:
			print("FILM_ESCAPE overreach %s %.3f m at %.2f s" % [p.person, p.overreach, p.overreach_t])


# Pas de transfert de poids aléatoire pendant le film : les pieds de base restent fixes.
func _calm_idle(visual: PaperVisual) -> void :
	visual.set("_weight_side", 0.0)
	visual.set("_weight_target", 0.0)
	visual.set("_shift_timer", 1.0e9)
	var feet: Dictionary = visual.get("_idle_feet")
	var rest: Dictionary = visual.get("_foot_rest")
	var look: Dictionary = visual.get("_style")
	for side: int in [-1, 1]:
		var r: Vector3 = rest[side]
		feet[side] = Vector3(r.x * float(look.get("stance", 1.0)), r.y, r.z)
	var yaw: Dictionary = visual.get("_idle_foot_yaw")
	yaw[-1] = 0.0;yaw[1] = 0.0


# Les pas automatiques du jeu (cadence de sa démarche) ne collent pas aux appuis écrits :
# on les coupe ; le clip émet ses propres pas (fstep_l / fstep_r).
func _hook_steps() -> void :
	for take: PaperCinema.Take in film.takes:
		var visual: PaperVisual = take.visual
		for link: Dictionary in visual.anim_fx.get_connections():
			var callable: Callable = link.callable
			if callable.get_object() == film and str(callable.get_method()) == "_on_cue":
				visual.anim_fx.disconnect(callable)
				var mine: Callable = _on_fx.bind(callable)
				visual.anim_fx.connect(mine)
				_cue_links.append([visual, callable, mine])


func _on_fx(cue: String, original: Callable) -> void :
	if cue == "step_l" or cue == "step_r": return
	if cue == "fstep_l" or cue == "fstep_r":
		original.call(cue.substr(1))
		return
	original.call(cue)


func _exit_tree() -> void :
	for link: Array in _cue_links:
		var visual: PaperVisual = link[0]
		if not is_instance_valid(visual): continue
		if visual.anim_fx.is_connected(link[2]): visual.anim_fx.disconnect(link[2])
		if not visual.anim_fx.is_connected(link[1]): visual.anim_fx.connect(link[1])
	_cue_links.clear()
	for cache_key: String in clip_keys: AnimLibrary._cache.erase(cache_key)
	clip_keys.clear()
	if film:
		for take: PaperCinema.Take in film.takes:
			if is_instance_valid(take.visual): take.visual.set("_shift_timer", 3.0)
