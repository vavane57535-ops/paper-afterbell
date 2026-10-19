class_name PaperFilmEscape
extends Node3D

# Fuites en équipe (« ending_survivors », 63 combinaisons d'élèves), 0.17 : film écrit de A à Z.
# Ils foncent vers la sortie. Alice, trop loin, plante sa griffe dans le sol : ses piques
# (Shadow spike) filent entre leurs pieds et jaillissent dans l'encadrement de la porte.
# Il faut passer par-dessus : courte échelle pour le premier, on tire le suivant par la main,
# on relève celui qui s'étale ; les combattants retiennent Alice (flashbang, drone, poussée,
# contre) ; Lysia passe en force et ouvre une brèche ; ceux qui sont passés se retournent et
# attendent. Le dernier passe de justesse : Alice arrive trop tard. Dehors, chacun craque à sa façon.
# Le planificateur (plan) distribue les rôles selon l'équipe ; les modules de mise en scène par
# perso et par rôle sont dans anim_set_film_escape.gd ; chaque acteur joue UN clip écrit pour son film.
# PaperCinema délègue l'écriture (write) et appelle update() à chaque image.
# Repère E : origine au pied de la porte (3 m avant cinematic_exit), z vers la sortie.

const Anim = preload("res://anim_set_film_escape.gd")
const AnimClip = preload("res://anim_clip.gd")
const AnimLibrary = preload("res://anim_library.gd")

# Ordre de passage : les plus fragiles d'abord, les combattants restent derrière ; Usayuko ferme la marche.
const ORDER: Array[String] = ["Bleuette", "Elly", "Simon", "Ashura", "Lysia", "Usayuko"]
const FIGHTERS: Array[String] = ["Simon", "Ashura", "Lysia", "Usayuko"]
# Façon de passer quand on passe sans aide.
const OWN: Dictionary = {"Bleuette": "brave", "Elly": "hurdle", "Simon": "flail", "Ashura": "ollie", "Lysia": "wade", "Usayuko": "vault"}
# Passages qui n'ont pas besoin d'une main tendue, même pour le dernier.
const STRONG: Array[String] = ["vault", "ollie", "wade", "slide", "flail"]
# Durée pendant laquelle le passage occupe la haie (le suivant peut s'élancer après).
const BUSY: Dictionary = {"legup": 1.42, "haul": 1.3, "hurdle": 0.9, "flail": 0.95, "ollie": 0.95, "vault": 0.85, "wade": 1.5, "slide": 1.05, "brave": 1.25}
# Fin du passage (l'élève est dehors, sur ses deux pieds, libre de bouger).
const OUT: Dictionary = {"legup": 1.52, "haul": 1.45, "hurdle": 1.0, "flail": 1.1, "ollie": 1.12, "vault": 1.05, "wade": 1.75, "slide": 1.3, "brave": 1.4}
# Instant (depuis le début du passage) où le dernier vient de franchir : la griffe d'Alice frappe là.
const LUNGE_AT: Dictionary = {"haul": 0.95, "hurdle": 0.72, "flail": 0.66, "ollie": 0.66, "vault": 0.6, "wade": 1.32, "slide": 0.62, "brave": 0.98}
# Gestes qui retiennent Alice : durée, instant du coup, distance élève-Alice au coup.
const STALL_LEN: Dictionary = {"Simon": 1.2, "Ashura": 1.15, "Lysia": 1.2, "Usayuko": 1.4, "dodge": 0.62}
const STALL_HIT: Dictionary = {"Simon": 0.95, "Ashura": 0.94, "Lysia": 0.4, "Usayuko": 0.66, "dodge": 0.24}
const STALL_REACH: Dictionary = {"Simon": 4.4, "Ashura": 3.9, "Lysia": 1.15, "Usayuko": 1.75, "dodge": 1.0}
# Ce que ça fait à Alice : temps sonnée, recul.
const DAZE: Dictionary = {"Simon": 1.25, "Ashura": 0.95, "Lysia": 1.4, "Usayuko": 1.25, "dodge": 0.4}
const KNOCK: Dictionary = {"Simon": 0.55, "Ashura": 0.3, "Lysia": 3.0, "Usayuko": 1.4, "dodge": 0.0}

const T_SLAM: float = 0.62
const T_INK: float = 0.9
const T_HEDGE: float = 1.3
const T_READY: float = 2.1
const CELEBRATE: float = 3.7
const ALICE_RUN: float = 5.4
const ALICE_START_Z: float = -13.2
const SLAM_Z: float = -10.4
const NEAR_Z: float = -1.45
const LAND_Z: float = 1.1

const GOLD: Color = Color("ffd24a")
const PAPER: Color = Color("fff6e4")
const CRIMSON: Color = Color("ff5a78")
const LETTERBOX: float = 0.79

static var _serial: int = 0

var film: PaperCinema
var world: Node
var door_z: float = 12.0
var cast: Array = []
var alice: int = -1
var plan_data: Dictionary = {}
var clip_keys: Array[String] = []
var contacts: Array = []
var half_open: float = 2.9
var _cue_links: Array = []
var _hedge: Node3D
var _thorns: Array = []
var _ink: MeshInstance3D
var _ink_material: StandardMaterial3D
var _breaks: Array = []
var _ink_from: Vector3 = Vector3.ZERO
var _ink_t: float = 0.0
var _home: Dictionary = {}
var _beats: Array = []


static func duration_for(names: Array) -> float:
	return float(plan(names).duration)


static func lane_of(k: int, n: int) -> float:
	var spacing: float = 0.84 if n > 4 else (0.98 if n > 2 else 1.15)
	return (float(k) - float(n - 1) * 0.5) * spacing


# Distribution et minutage, sans carte ni acteur (sert aussi à la durée du catalogue).
static func plan(names: Array) -> Dictionary:
	var team: Array[String] = []
	for person: String in ORDER:
		if person in names: team.append(person)
	if team.is_empty(): team.append("Ashura")
	var n: int = team.size()
	var rear: String = team[n - 1]
	var mids: Array[String] = []
	var max_mid: int = 0 if n <= 2 else (1 if n <= 4 else 2)
	for person: String in team:
		if person in FIGHTERS and person != rear and mids.size() < max_mid: mids.append(person)
	var slots: Array = []
	var t_next: float = T_READY
	var alice_ready: float = T_SLAM + 0.98
	var alice_z: float = SLAM_Z
	var gap: float = INF
	var outside: Array[String] = []
	var busy: Dictionary = {}
	var free_out: Dictionary = {}
	for person: String in team: busy[person] = T_READY
	for i: int in range(n):
		var who: String = team[i]
		var lane: float = lane_of(i, n)
		var slot: Dictionary = {"who": who, "k": i, "lane": lane, "helper": "", "method": str(OWN[who])}
		# 1) méthode de passage et aide
		if who == "Lysia":
			slot.method = "wade"
		elif i == 0 and n >= 2:
			slot.method = "legup"
			slot.helper = team[1]
			# un temps pour encaisser le piège, puis l'aide se met en place
			t_next = T_READY + 0.55
		elif who == rear and gap < INF:
			slot.method = "slide"
			slot.lane = gap
		elif not outside.is_empty() and who != "Simon" and (i == 1 or (who == rear and str(slot.method) not in STRONG)):
			slot.method = "haul"
			slot.helper = _pick_helper(outside, who)
		# 2) retenir Alice avant de passer
		var stall: String = ""
		if who in mids or (who == rear and who in FIGHTERS): stall = who
		elif who == rear: stall = "dodge"
		var start: float = maxf(t_next, float(busy[who]))
		if not stall.is_empty():
			var meet_z: float = NEAR_Z - 0.35 - float(STALL_REACH[stall])
			var travel: float = maxf(0.0, meet_z - alice_z) / ALICE_RUN
			var hit: float = maxf(start - (float(STALL_LEN[stall]) - float(STALL_HIT[stall])) + 0.12, alice_ready + travel + 0.12)
			hit = maxf(hit, float(busy[who]) + float(STALL_HIT[stall]) + 0.05)
			slot["stall"] = stall
			slot["t_stall"] = hit - float(STALL_HIT[stall])
			slot["hit"] = hit
			slot["meet_z"] = meet_z
			var daze: float = float(DAZE[stall]) * (0.55 if who == rear else 1.0)
			alice_ready = hit + daze
			alice_z = meet_z - float(KNOCK[stall])
			start = maxf(start, hit + float(STALL_LEN[stall]) - float(STALL_HIT[stall]) - 0.08)
		var method: String = str(slot.method)
		# l'aide doit avoir fini son propre passage (elle se retourne, revient à la haie)
		if method == "haul": start = maxf(start, float(free_out.get(str(slot.helper), 0.0)) + 0.6)
		slot["t_cross"] = start
		if method == "legup": busy[str(slot.helper)] = start + 1.32
		if method == "wade": gap = lane
		if method == "flail" and not outside.is_empty():
			var puller: String = _pick_helper(outside, who)
			if float(free_out.get(puller, 0.0)) < start + float(OUT.flail) - 0.3: slot["puller"] = puller
		free_out[who] = start + float(OUT[method])
		if method == "haul": free_out[str(slot.helper)] = start + 1.5
		if slot.has("puller"): free_out[str(slot.puller)] = start + float(OUT.flail) + 1.15
		slots.append(slot)
		t_next = start + float(BUSY[method])
		outside.append(who)
	# 3) trop tard : Alice se jette sur le dernier
	var last: Dictionary = slots[n - 1]
	var lunge: float = float(last.t_cross) + float(LUNGE_AT.get(str(last.method), 0.7))
	var reach: float = alice_ready + maxf(0.0, -1.85 - alice_z) / ALICE_RUN + 0.08
	if reach > lunge:
		var push: float = reach - lunge
		last.t_cross = float(last.t_cross) + push
		if last.has("t_stall"):
			last.t_stall = float(last.t_stall) + push * 0.0
		lunge = reach
	var free: float = float(last.t_cross) + float(OUT[str(last.method)])
	if last.has("puller"): free += 1.0
	var data: Dictionary = {"team": team, "slots": slots, "rear": rear, "mids": mids}
	data["lunge"] = lunge
	data["free"] = free
	data["party"] = free + 0.12
	data["duration"] = free + 0.12 + CELEBRATE
	return data


# Qui tend la main : le dernier passé (il est encore près de la haie), sauf s'il est occupé ;
# Lysia et Usayuko tirent plus fort, mais tout le monde aide.
static func _pick_helper(outside: Array[String], _who: String) -> String:
	return outside[outside.size() - 1]


func write(cinema: PaperCinema) -> void :
	film = cinema;world = cinema.world;name = "Escape"
	door_z = film._length - 3.0
	plan_data = plan(film.people)
	if OS.get_environment("ESC_PLAN") == "1":
		for slot: Dictionary in plan_data.slots: print("PLAN %s %s cross=%.2f stall=%s helper=%s" % [slot.who, slot.method, slot.t_cross, str(slot.get("t_stall", "-")), str(slot.helper) + str(slot.get("puller", ""))])
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
	_measure_opening()
	_build_hedge()
	_write_story()
	_finish()
	_hook_steps()


func _who(person: String) -> Anim.Performer:
	for p: Anim.Performer in cast:
		if p.person == person and p.index != alice: return p
	return null


func _slot_of(person: String) -> Dictionary:
	for slot: Dictionary in plan_data.slots:
		if str(slot.who) == person: return slot
	return {}


# ------------------------------------------------------------------ histoire

func _write_story() -> void :
	var slots: Array = plan_data.slots
	var n: int = slots.size()
	var a: Anim.Performer = cast[alice] if alice >= 0 else null
	_write_opening(a)
	# Créneau par créneau (le plan garde l'ordre du temps pour chaque acteur) : le geste qui
	# retient Alice, puis le passage ; avant chaque action, les acteurs concernés sont amenés
	# jusqu'à son début (attente sur place, quelques pas).
	for slot: Dictionary in slots:
		if slot.has("stall"): _write_stall(slot, a)
		_write_cross(slot, a)
	# trop tard
	if a != null: _write_late(a)
	# dehors : on attend jusqu'à la fête, puis chacun à sa façon
	_write_party()
	_write_camera()


# Course, griffe dans le sol, haie, freinage. Rend l'instant où tout le monde est arrêté.
func _write_opening(a: Anim.Performer) -> void :
	var slots: Array = plan_data.slots
	var n: int = slots.size()
	for slot: Dictionary in slots:
		var p: Anim.Performer = _who(str(slot.who))
		var k: int = int(slot.k)
		var lane: float = float(slot.lane)
		var speed: float = 5.1 + 0.25 * Anim.n1(p.seed, 1)
		var row: int = [0, 2, 1, 2, 0, 1][k % 6]
		var start: Vector3 = Vector3(lane * 1.25 + 0.25 * Anim.n1(p.seed, 2), 0.0, -9.1 - 0.62 * float(row) + 0.2 * Anim.n1(p.seed, 3))
		var stop_at: Vector3 = Vector3(lane, 0.0, NEAR_Z - 0.18 * float(k % 2) + 0.06 * Anim.n1(p.seed, 4))
		p.start(0.0, start, Vector3(0, 0, speed))
		p.turn(0.0, 0.0, "s")
		p.pose(0.0, Anim.base_pose())
		# ils voient la ligne d'encre filer entre leurs pieds, puis les piques : freinage
		var brake: float = T_HEDGE - 0.1 + 0.05 * float(row) + 0.03 * Anim.n1(p.seed, 5)
		var at_brake: Vector3 = start + Vector3(0, 0, speed * brake)
		var room: float = stop_at.z - at_brake.z
		if room < 1.3:
			at_brake.z = stop_at.z - 1.3
			room = 1.3
		at_brake.x = lerpf(start.x, stop_at.x, 0.55)
		p.go(brake, at_brake, Vector3(0, 0, speed))
		var stop_t: float = brake + clampf(2.0 * room / speed, 0.5, 0.82)
		p.go(stop_t, stop_at, Vector3.ZERO)
		Anim.run(p, 0.0, stop_t + 0.12, {"first": 1 if k % 2 == 0 else -1, "seed": k * 13, "moving": true, "upper_until": brake})
		Anim.brake_upper(p, brake, stop_t)
		p.face(0.0, "panic" if p.person in ["Simon", "Bleuette"] else "determined")
		p.face(T_INK + 0.2, "fear")
		p.face(T_HEDGE + 0.05, "surprise")
		p.ev(T_HEDGE + 0.08, "gasp")
		_home[p.person] = {"spot": stop_at, "t": stop_t + 0.12}
	if a != null:
		a.start(0.0, Vector3(0.25, 0.0, ALICE_START_Z), Vector3(0, 0, 4.6))
		a.turn(0.0, 0.0, "s")
		a.pose(0.0, Anim.base_pose())
		a.go(T_SLAM, Vector3(0.2, 0.0, SLAM_Z), Vector3.ZERO)
		Anim.alice_run(a, 0.0, T_SLAM + 0.02, {"moving": true, "first": 1})
		a.face(0.0, "menace")
		var hit: float = Anim.alice_slam(a, T_SLAM, 0.0)
		_ink_line(hit, a.at(hit) + Vector3(0, 0, 0.55))


# Un élève retient Alice (geste de sa capacité) ; elle encaisse.
func _write_stall(slot: Dictionary, a: Anim.Performer) -> void :
	var p: Anim.Performer = _who(str(slot.who))
	var kind: String = str(slot.stall)
	var t: float = float(slot.t_stall)
	var hit: float = float(slot.hit)
	var i: int = p.index
	_bring_inside(p, t)
	# où se tient Alice au moment du coup
	var me: Vector3 = p.end_p
	var meet: Vector3 = Vector3(lerpf(me.x, 0.0, 0.35), 0.0, float(slot.meet_z))
	if kind in ["Lysia", "Usayuko", "dodge"]: meet.x = me.x * 0.85
	if a != null: _alice_to(a, hit - (0.18 if kind in ["Lysia", "Usayuko"] else 0.0), meet, p)
	var theta: float = Anim.heading_of(meet - me)
	theta = p.theta(t) + wrapf(theta - p.theta(t), -PI, PI)
	match kind:
		"dodge":
			if a != null: Anim.alice_whiff(a, hit - 0.12)
			Anim.dodge(p, t, theta)
			film._cue(hit + 0.02, "word", "miss", {"a": i, "h": 1.5}, PAPER, 0.85)
			film._cue(hit, "sweat", {"a": i, "s": "head"}, 2)
			film._cue(hit - 0.08, "sound", "slash", {"a": alice}, 0.8)
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
			var strike: float = release + 0.48
			film._flights.append([t + 0.26, release, "drone", {"a": i, "s": "hand_r"}, {"a": i, "s": "hand_r"}, 0.0, 0.0])
			film._flights.append([release, strike, "drone", {"a": i, "s": "hand_r"}, {"a": alice, "s": "head"}, 0.35, 0.6])
			film._cue(release, "sound", "drone", {"a": i}, 0.7)
			film._cue(strike, "event", "drone", {"action": "impact", "position": {"a": alice, "s": "head"}})
			film._cue(strike, "sound", "ground_impact", {"a": alice}, 0.8)
			film._cue(strike, "shake", 0.3)
			film._cue(strike, "word", "boom", {"a": alice, "h": 2.2}, Color("c6b5f9"), 0.85)
			if a != null:
				a.hold(strike)
				Anim.alice_droned(a, strike, a.theta(strike))
		"Lysia":
			film._cue(t, "event", "overheat", {"position": {"a": i}, "active": true})
			if a != null: Anim.alice_slash(a, t + 0.16)
			var impact: float = Anim.push(p, t, theta)
			film._cue(impact, "word", "push", {"a": i, "h": 2.1}, Color("a6f0d8"), 1.0)
			film._cue(impact, "shake", 0.45)
			film._cue(impact, "impact", 0.6, false)
			film._cue(impact, "sound", "block", {"a": i}, 0.9, 0.8)
			film._cue(impact + 0.3, "word", "hot", {"a": i, "h": 1.5, "o": Vector3(0.3, 0, -0.3)}, Color("ffcf8a"), 0.7)
			if a != null:
				a.hold(impact)
				Anim.alice_pushed(a, impact, a.theta(impact), float(KNOCK.Lysia))
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
	_beats.append({"kind": "stall", "t0": t, "t1": t + float(STALL_LEN[kind]), "hit": hit, "who": i, "stall": kind})


# Passage de la haie, avec l'aide prévue (courte échelle, main tendue, relevé).
func _write_cross(slot: Dictionary, a: Anim.Performer) -> void :
	var p: Anim.Performer = _who(str(slot.who))
	var t: float = float(slot.t_cross)
	var method: String = str(slot.method)
	var lane: float = float(slot.lane)
	var i: int = p.index
	var beat: Dictionary = {"kind": method, "t0": t, "who": i, "lane": lane}
	match method:
		"legup":
			var b: Anim.Performer = _who(str(slot.helper))
			var side: float = 1.0 if lane < 0.0 else -1.0
			_bring_inside(b, t - 0.62)
			_bring_inside(p, t, Vector3(lane, 0.0, NEAR_Z - 0.1))
			var info: Dictionary = Anim.legup(p, b, t, lane, side)
			var window: Array = info.foot
			for side_hand: int in [-1, 1]:
				contacts.append({"who": b.index, "side": side_hand, "t0": float(window[0]) - 0.04, "t1": float(window[1]) + 0.05, "to": p.index, "socket": "foot_r", "offset": Vector3(0.05 * float(side_hand), -0.07, 0.0), "in": 0.06, "out": 0.08})
			_hedge_dust(float(info.land) - 0.25, lane)
			film._cue(float(info.top), "word", "go", {"a": b.index, "h": 1.9}, Color("ffb7cf"), 0.9)
			_home[b.person] = {"spot": b.end_p, "t": b.end_t}
			beat["helper"] = b.index
			beat["t1"] = float(info.out)
			_after_cross(p, float(info.out), slot)
		"haul":
			var h: Anim.Performer = _who(str(slot.helper))
			_bring_outside(h, t - 0.55)
			_bring_inside(p, t, Vector3(lane, 0.0, NEAR_Z))
			var info: Dictionary = Anim.haul(p, h, t, lane)
			contacts.append({"who": h.index, "side": 1, "t0": float(info.grab), "t1": float(info.release), "to": p.index, "socket": "hand_r", "mutual": true, "in": 0.08, "out": 0.1})
			contacts.append({"who": h.index, "side": -1, "t0": float(info.grab) + 0.05, "t1": float(info.release) - 0.1, "to": p.index, "socket": "hand_l", "mutual_side": -1, "mutual": true, "in": 0.08, "out": 0.1})
			_hedge_dust(float(info.land) - 0.3, lane)
			film._cue(float(info.grab) + 0.05, "word", "go", {"a": h.index, "h": 1.9}, Color("ffb7cf"), 0.85)
			_home[h.person] = {"spot": h.end_p, "t": h.end_t}
			beat["helper"] = h.index
			beat["t1"] = float(info.out)
			_after_cross(p, float(info.out), slot)
		"wade":
			_bring_inside(p, t, Vector3(lane, 0.0, NEAR_Z))
			var info: Dictionary = Anim.wade(p, t)
			_breaks.append({"x": lane, "t0": float(info.break_from), "t1": float(info.break_to), "heal": INF})
			film._cue(float(info.break_from) + 0.12, "word", "break", _f(Vector3(lane, 1.2, 0.0)), PAPER, 0.85)
			film._cue(float(info.break_from) + 0.12, "sound", "block", _f(Vector3(lane, 0.6, 0.0)), 0.7, 1.4)
			film._cue(float(info.break_from) + 0.45, "word", "zap", _f(Vector3(lane + 0.4, 1.4, 0.2)), Color("a6f0d8"), 0.7)
			film._cue(float(info.break_from) + 0.12, "dust_ring", _f(Vector3(lane, 0.05, 0.0)), 0.7)
			beat["t1"] = float(info.out)
			_after_cross(p, float(info.out), slot)
		"slide":
			_bring_inside(p, t, Vector3(lane, 0.0, NEAR_Z - 0.6))
			var info: Dictionary = Anim.slide(p, t, lane)
			_hedge_dust(float(info.through), lane)
			film._cue(float(info.through) - 0.05, "sound", "boost", _f(Vector3(lane, 0.3, 0.0)), 0.6, 1.2)
			beat["t1"] = float(info.out)
			_after_cross(p, float(info.out), slot)
		_:
			_bring_inside(p, t, Vector3(lane, 0.0, NEAR_Z))
			var info: Dictionary = Anim.hedge_jump(p, t, method, {"face": "fear" if method in ["brave", "flail"] else "determined"})
			_hedge_dust(float(info.take) + 0.22, lane)
			beat["t1"] = float(info.out)
			if method == "flail":
				var helper_name: String = str(slot.get("puller", ""))
				if helper_name.is_empty():
					_get_up(p, float(info.out))
					beat["t1"] = float(info.out) + 0.75
					_after_cross(p, float(info.out) + 0.75, slot)
				else:
					var h: Anim.Performer = _who(helper_name)
					var fallen: Vector3 = p.at(float(info.out))
					var t_help: float = float(info.out) - 0.2
					_bring_outside(h, t_help)
					var window: Array = Anim.pull_up(h, p, t_help, fallen)
					contacts.append({"who": h.index, "side": 1, "t0": float(window[0]), "t1": float(window[1]), "to": p.index, "socket": "hand_r", "mutual": true, "in": 0.06, "out": 0.08})
					if h.person == "Elly":
						film._cue(t_help + 0.5, "event", "heal", {"position": {"a": p.index}})
						film._cue(t_help + 0.5, "sound", "heal", {"a": h.index}, 0.6)
					_home[h.person] = {"spot": h.end_p, "t": h.end_t}
					beat["helper"] = h.index
					beat["t1"] = t_help + 1.3
					_after_cross(p, t_help + 1.25, slot)
			else:
				_after_cross(p, float(info.out), slot)
	_beats.append(beat)


# Après le passage : quelques pas vers sa place dehors, demi-tour, on attend les autres. Si on
# doit bientôt tendre la main à quelqu'un, on reste près de la haie, tourné vers lui.
func _after_cross(p: Anim.Performer, t: float, slot: Dictionary) -> void :
	var n: int = (plan_data.slots as Array).size()
	var k: int = int(slot.k)
	var spot: Vector3 = _outside_spot(k, n)
	if p.end_t < t: p.hold(t)
	var duty: float = _next_duty(p.person, t)
	if duty < t + 1.7:
		# on se retourne sur place vers la haie ; le module d'aide l'amènera où il faut
		if duty > t + 0.5 and absf(wrapf(PI - p.theta(t), -PI, PI)) > 0.3:
			Anim.pivot(p, t, t + 0.45, p.end_p, p.theta(t) + wrapf(PI - p.theta(t), -PI, PI))
		_home[p.person] = {"spot": p.end_p, "t": p.end_t, "out": true}
		return
	var dist: float = Vector2(spot.x - p.end_p.x, spot.z - p.end_p.z).length()
	var travel: float = clampf(dist / 1.9, 0.45, 1.1)
	Anim.step_to(p, t, t + travel, spot, PI, {"seed": 90 + k, "first": -1})
	_home[p.person] = {"spot": spot, "t": t + travel, "out": true}


# Prochain instant où cette personne (déjà dehors) doit aider quelqu'un.
func _next_duty(person: String, after: float) -> float:
	var best: float = INF
	for slot: Dictionary in plan_data.slots:
		var start: float = INF
		if str(slot.method) == "haul" and str(slot.helper) == person: start = float(slot.t_cross) - 0.55
		elif str(slot.get("puller", "")) == person: start = float(slot.t_cross) + float(OUT.flail) - 0.25
		if start > after - 0.05: best = minf(best, start)
	return best


func _outside_spot(k: int, n: int) -> Vector3:
	var x: float = lane_of(k, n) * (1.05 if n > 3 else 1.25)
	return Vector3(x, 0.0, 2.45 + 0.4 * float(k % 2) + 0.12 * float(n > 4))


# Amène un élève encore dedans jusqu'à l'instant t : il attend (tendu, regards vers Alice et la
# haie), et s'il doit être ailleurs (aide, élan), il y va juste avant.
func _bring_inside(p: Anim.Performer, t: float, spot: Variant = null) -> void :
	if p.end_t >= t - 0.02: return
	var from: float = p.end_t
	var target: Vector3 = spot if spot is Vector3 else p.end_p
	var move: bool = (target - p.end_p).length() > 0.12
	var walk: float = clampf((target - p.end_p).length() / 1.6, 0.35, 0.8) if move else 0.0
	var wait_until: float = t - walk
	if wait_until > from + 0.15:
		Anim.wait(p, from, wait_until, {"look": 0.5, "seed": p.index * 7, "face": "fear", "theta_alice": PI})
	if move:
		Anim.step_to(p, maxf(from, wait_until), t, target, 0.0, {"seed": p.index * 3 + 5})
	else:
		p.hold(t)


# Amène quelqu'un qui est dehors jusqu'à l'instant t (il attendait, il se rapproche de la haie).
func _bring_outside(p: Anim.Performer, t: float) -> void :
	if p.end_t >= t - 0.02: return
	if t - p.end_t > 0.25: Anim.wait_out(p, p.end_t, t, 0.0)
	else: p.hold(t)


func _get_up(p: Anim.Performer, t: float) -> void :
	p.hold(t + 0.75)
	var fl: Vector3 = p.foot_at[-1]
	var fr: Vector3 = p.foot_at[1]
	p.plant(-1, p.foot_free[-1], t + 0.75, fl)
	p.plant(1, p.foot_free[1], t + 0.38, fr, 0.0, -0.5)
	var stand_r: Vector3 = Anim.w(p.at(t), p.theta(t), 0.13, -0.05)
	Anim.swing_to(p, 1, t + 0.38, fr, t + 0.56, stand_r)
	p.plant(1, t + 0.56, t + 0.75, stand_r)
	Anim.keys(p, t, [
		[0.0, Anim.M([Anim.H(0, -0.5, 0.3), Anim.B(0.95), Anim.HD(0.7), Anim.Lg(0.25, 0.42, 0.0), Anim.Rg(0.25, 0.46, 0.0), {"el_l": 0.5, "el_r": 0.5, "face": "hurt"}])],
		[0.22, Anim.M([Anim.H(0, -0.38, 0.2), Anim.B(0.7), Anim.HD(0.55, 0.3), Anim.Lg(0.25, 0.36, 0.05), Anim.Rg(0.22, 0.3, 0.12), {"ev": "effort", "face": "fear"}])],
		[0.42, Anim.M([Anim.H(0, -0.24, 0.08), Anim.B(0.45), Anim.HD(0.2, -0.4), Anim.L(0.3, -0.6, 0.3, 0.3), Anim.R(0.3, -0.55, 0.32, 0.3), {"el_l": 0.2, "el_r": 0.2}])],
		[0.72, Anim.M([Anim.tense(p.person), Anim.HD(0.1, -0.3), {"face": "panic"}])],
	])


# ------------------------------------------------------------------ Alice

# Alice rejoint `target` pour l'instant `t_arrive` : elle court si c'est juste, sinon elle avance
# en traquant (marche lente, tête basse), après un temps d'arrêt menaçant si elle a de l'avance.
func _alice_to(a: Anim.Performer, t_arrive: float, target: Vector3, victim: Anim.Performer) -> void :
	var start_t: float = a.end_t
	var dist: float = Vector2(target.x - a.end_p.x, target.z - a.end_p.z).length()
	var face_victim: float = Anim.heading_of(victim.end_p - target) if (victim.end_p - target).length() > 0.3 else 0.0
	if dist < 0.12 or t_arrive <= start_t + 0.1:
		if t_arrive > start_t + 0.3: Anim.alice_wait(a, start_t, t_arrive)
		a.hold(t_arrive)
		var now0: float = a.theta(t_arrive)
		a.turn(t_arrive + 0.05, now0 + wrapf(face_victim - now0, -PI, PI), "s")
		return
	var avail: float = t_arrive - start_t
	var run_time: float = dist / ALICE_RUN
	var leave: float = start_t
	if avail > run_time * 1.25 + 0.2:
		var walk_speed: float = clampf(dist / maxf(avail - 0.2, 0.1), 1.25, 2.7)
		leave = t_arrive - dist / walk_speed
		if leave > start_t + 0.25: Anim.alice_wait(a, start_t, leave)
		else: leave = start_t
	a.hold(leave)
	var now: float = a.theta(leave)
	var heading: float = now + wrapf(Anim.heading_of(target - a.end_p) - now, -PI, PI)
	a.turn(leave, now, "s")
	a.turn(leave + minf(0.3, (t_arrive - leave) * 0.4), heading, "s")
	a.go(t_arrive, target, Vector3.ZERO)
	var final: float = heading + wrapf(face_victim - heading, -PI, PI)
	a.turn(t_arrive - 0.05, lerpf(heading, final, 0.5))
	a.turn(t_arrive + 0.12, final, "s")
	Anim.alice_run(a, leave, t_arrive + 0.1, {"first": 1, "seed": int(t_arrive * 10.0)})


func _write_late(a: Anim.Performer) -> void :
	var slots: Array = plan_data.slots
	var last: Dictionary = slots[slots.size() - 1]
	var lunge: float = float(plan_data.lunge)
	var x: float = float(last.lane)
	var from: Vector3 = Vector3(x * 0.85, 0.0, -1.95)
	var length: float = float(plan_data.duration)
	if a.end_t < lunge - 0.05:
		var dist: float = a.end_p.distance_to(from)
		var travel: float = maxf(0.3, dist / ALICE_RUN)
		var leave: float = maxf(a.end_t, lunge - travel)
		if leave > a.end_t + 0.2: Anim.alice_wait(a, a.end_t, leave)
		a.hold(leave)
		var now: float = a.theta(leave)
		a.turn(leave, now, "s")
		a.turn(leave + 0.18, now + wrapf(0.0 - now, -PI, PI), "s")
		a.go(lunge, from, Vector3(0, 0, 3.2))
		Anim.alice_run(a, leave, lunge, {"stop": false, "first": 1, "seed": 7})
	var blocked: bool = str(last.method) in ["slide", "wade"]
	if blocked:
		# la brèche se referme sous son nez : ses propres piques l'arrêtent
		for cut: Dictionary in _breaks:
			if absf(float(cut.x) - x) < 0.3: cut["heal"] = lunge + 0.12
		Anim.alice_blocked(a, lunge, x)
		film._cue(lunge + 0.2, "word", "thorn", _f(Vector3(x, 1.4, -0.1)), Color("d86ad0"), 0.9)
		film._cue(lunge + 0.2, "sound", "shadow", _f(Vector3(x, 0.6, 0.0)), 0.8, 1.3)
		film._cue(lunge + 0.34, "shake", 0.35)
		film._cue(lunge + 0.4, "word", "ouch", {"a": alice, "h": 2.0}, PAPER, 0.9)
	else:
		Anim.alice_lunge(a, lunge, x)
		film._cue(lunge + 0.36, "word", "miss", {"a": alice, "h": 1.2, "o": Vector3(0, 0, 0.6)}, PAPER, 1.0)
	film._cue(lunge + 0.3, "sound", "slash", {"a": alice}, 0.9)
	Anim.alice_rage(a, lunge + 0.78, length)
	film._cue(lunge + 1.62, "word", "roar", {"a": alice, "h": 2.4}, CRIMSON, 1.25)
	film._cue(lunge + 1.62, "shake", 0.45)
	film._cue(lunge + 1.62, "sound", "shadow", {"a": alice}, 0.8, 0.8)
	_beats.append({"kind": "late", "t0": lunge - 0.6, "t1": lunge + 0.9, "who": (_who(str(last.who)) as Anim.Performer).index, "lane": x, "blocked": blocked})


# ------------------------------------------------------------------ dehors

func _write_party() -> void :
	var length: float = float(plan_data.duration)
	var party: float = float(plan_data.party)
	var slots: Array = plan_data.slots
	var n: int = slots.size()
	for slot: Dictionary in slots:
		var p: Anim.Performer = _who(str(slot.who))
		if p.end_t < party - 0.25: Anim.wait_out(p, p.end_t, party, 0.0)
		p.hold(party)
		# vers où chacun se tourne : vers le groupe, vers la caméra, ou vers Alice pour la narguer
		var facing: float = 0.0
		match p.person:
			"Usayuko": facing = PI
			"Lysia": facing = PI if n > 1 else 0.0
			"Elly", "Simon": facing = (0.6 if p.end_p.x < 0.0 else -0.6) if n > 1 else 0.0
			"Ashura": facing = 0.35 if p.end_p.x < 0.0 else -0.35
		Anim.celebrate(p, party + 0.07 * float(int(slot.k)), length, facing, {"n": n})
	film._cue(party - 0.02, "event", "escaped", {"position": _f(Vector3(0, 0, 2.6))})
	film._cue(party + 0.05, "sound", "encourage", _f(Vector3(0, 1, 2.5)))
	film._cue(party + 0.2, "sparkles", _f(Vector3(0, 1.5, 2.6)), GOLD, 8, 1.4)
	film._cue(party + 0.1, "pulse", Color(1.0, 0.92, 0.6, 0.3), 1.2)


# ------------------------------------------------------------------ caméra
# Chaque plan est calculé à l'écriture à partir des positions réelles des acteurs : les sujets
# tiennent dans le cadre (bandes noires comprises) quelle que soit l'équipe.

func _write_camera() -> void :
	var slots: Array = plan_data.slots
	var n: int = slots.size()
	var survivors: Array = []
	for p: Anim.Performer in cast:
		if p.index != alice: survivors.append(p)
	# A. la course, de face, au ras du sol, qui recule devant eux
	film._shot(0.0, {"rel": {"group": true}, "eye": [Vector3(0.9, 0.5, 3.9 + 0.12 * float(n)), Vector3(0.7, 0.62, 3.4 + 0.12 * float(n))], "look": [{"group": true, "h": 0.95}, {"group": true, "h": 1.0}], "fov": [52.0, 48.0], "hand": 0.55})
	# B. la griffe dans le sol, en contre-plongée de trois quarts
	if alice >= 0:
		film._shot(T_SLAM - 0.06, {"rel": {"a": alice}, "eye": [Vector3(-1.75, 0.38, 2.1), Vector3(-1.55, 0.32, 1.85)], "look": [{"a": alice, "h": 0.95}, {"a": alice, "h": 0.55}], "fov": 42.0, "hand": 0.4})
	# C. depuis dehors : les piques jaillissent au premier plan, ils pilent derrière
	var front: Array = _points(survivors, [T_HEDGE + 0.35, T_READY])
	front.append(Vector3(-1.6, 0.0, 0.0))
	front.append(Vector3(1.6, 1.0, 0.0))
	_framed(T_INK + 0.26, T_READY, front, PI + 0.12, -0.06, 50.0, {"min": 3.2, "drift": Vector3(0, 0.05, -0.25), "hand": 0.5, "outside": true})
	# les plans d'action, dans l'ordre
	_beats.sort_custom( func(x: Dictionary, y: Dictionary) -> bool: return float(x.t0) < float(y.t0))
	var cuts: Array = []
	for beat: Dictionary in _beats:
		cuts.append(beat)
	var party: float = float(plan_data.party)
	var lunge: float = float(plan_data.lunge)
	var last_cut: float = T_READY
	for index: int in range(cuts.size()):
		var beat: Dictionary = cuts[index]
		var t0: float = maxf(float(beat.t0) - 0.08, last_cut + 0.55)
		var t_end: float = float(cuts[index + 1].t0) - 0.08 if index + 1 < cuts.size() else party
		if str(beat.kind) == "late": t_end = party
		if t0 > t_end - 0.45: continue
		_beat_shot(beat, t0, t_end)
		last_cut = t0
	_party_shots(survivors, party)


# Les points d'intérêt de quelques acteurs (pieds et tête) aux instants donnés.
func _points(list: Array, times: Array) -> Array:
	var out: Array = []
	for p: Anim.Performer in list:
		for t: float in times:
			var root: Vector3 = p.at(t)
			out.append(root)
			out.append(root + Vector3.UP * p.height * 0.98)
	return out


func _beat_shot(beat: Dictionary, t0: float, t1: float) -> void :
	var kind: String = str(beat.kind)
	var who: Anim.Performer = cast[int(beat.who)]
	var mid_t: float = (t0 + t1) * 0.5
	match kind:
		"stall":
			# profil à deux : l'élève et Alice, du côté libre
			var a: Anim.Performer = cast[alice] if alice >= 0 else who
			var hit: float = float(beat.hit)
			var subjects: Array = _points([who, a], [t0 + 0.1, hit, minf(t1, hit + 0.5)])
			var me: Vector3 = who.at(hit)
			var her: Vector3 = a.at(hit)
			var line: Vector3 = her - me
			line.y = 0.0
			var side: float = 1.0 if me.x >= 0.0 else -1.0
			var yaw: float = Anim.heading_of(line) + PI * 0.5 * side
			_framed(t0, t1, subjects, yaw + 0.25 * side, -0.03, 40.0, {"min": 2.6, "drift": Vector3(0, 0.04, 0.0), "hand": 0.45})
		"legup", "haul":
			var helper: Anim.Performer = cast[int(beat.get("helper", beat.who))]
			var lane: float = float(beat.lane)
			var subjects: Array = _points([who, helper], [t0 + 0.2, mid_t, t1 - 0.05])
			var side: float = -1.0 if lane < 0.0 else 1.0
			_framed(t0, t1, subjects, PI - 0.62 * side, -0.07, 44.0, {"min": 2.5, "drift": Vector3(0.1 * side, 0.06, 0.12), "hand": 0.45, "outside": true})
		"wade":
			var subjects: Array = _points([who], [t0 + 0.2, mid_t, t1])
			_framed(t0, t1, subjects, PI + 0.2, -0.02, 46.0, {"min": 2.9, "drift": Vector3(0, 0, 0.35), "hand": 0.55, "outside": true})
		"late":
			var lane: float = float(beat.lane)
			var a: Anim.Performer = cast[alice] if alice >= 0 else who
			var lunge: float = float(plan_data.lunge)
			var subjects: Array = _points([who], [t0 + 0.1, lunge, minf(t1, lunge + 0.5)])
			subjects.append_array(_points([a], [lunge, lunge + 0.45]))
			var side: float = 1.0 if lane <= 0.0 else -1.0
			_framed(t0, t1, subjects, PI + 0.5 * side, -0.1, 44.0, {"min": 2.4, "drift": Vector3(0, 0.05, 0.15), "hand": 0.6, "outside": true})
		_:
			# saut : trois quarts de profil depuis dehors, l'arc au-dessus des piques bien lisible
			var lane: float = float(beat.lane)
			var list: Array = [who]
			if beat.has("helper"): list.append(cast[int(beat.helper)])
			var subjects: Array = _points(list, [t0 + 0.15, mid_t, t1 - 0.05])
			subjects.append(Vector3(lane, 1.0, 0.0))
			var side: float = -1.0 if lane < 0.0 else 1.0
			_framed(t0, t1, subjects, PI * 0.5 * side + PI + 0.55 * - side, -0.05, 44.0, {"min": 2.6, "drift": Vector3(0.0, 0.05, 0.2), "hand": 0.5, "outside": true})


func _party_shots(survivors: Array, party: float) -> void :
	var length: float = float(plan_data.duration)
	var n: int = survivors.size()
	# D. le groupe dehors, de face (la porte et Alice derrière ses piques)
	var group: Array = _points(survivors, [party + 0.3, party + 1.5])
	_framed(party - 0.05, party + 1.75, group, PI + 0.1, -0.04, 42.0, {"min": 2.6, "drift": Vector3(0.1, 0.03, -0.3), "hand": 0.3})
	# E. contrechamp : Alice derrière ses piques, qui hurle
	if alice >= 0:
		var a: Anim.Performer = cast[alice]
		var her: Array = _points([a], [party + 1.8, party + 2.5])
		_framed(party + 1.75, party + 2.55, her, 0.12, 0.02, 36.0, {"min": 2.4, "drift": Vector3(0, 0, 0.15), "hand": 0.35, "from_outside": true})
	# F. plan large final, en hauteur
	var wide: Array = _points(survivors, [length - 1.0])
	wide.append(Vector3(-half_open, 0.0, 0.0))
	wide.append(Vector3(half_open, 1.2, 0.0))
	_framed(party + 2.55, length, wide, PI - 0.28, -0.24, 40.0, {"min": 4.0, "drift": Vector3(-0.2, 0.15, 0.5), "hand": 0.2})


# Pose la caméra pour que tous les points (repère E) tiennent dans l'image, en regardant vers
# yaw (0 = vers la sortie) avec la plongée pitch ; elle dérive de `drift` mètres pendant le plan.
func _framed(t0: float, t1: float, points: Array, yaw: float, pitch: float, fov: float, opts: Dictionary = {}) -> void :
	if points.is_empty(): return
	var dir: Vector3 = Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)).normalized()
	var right: Vector3 = dir.cross(Vector3.UP).normalized()
	var up: Vector3 = right.cross(dir).normalized()
	var low: Vector3 = Vector3(INF, INF, INF)
	var high: Vector3 = - low
	for point: Vector3 in points:
		low = low.min(point);high = high.max(point)
	var center: Vector3 = (low + high) * 0.5
	var tan_v: float = tan(deg_to_rad(fov) * 0.5) * LETTERBOX * 0.86
	var tan_h: float = tan(deg_to_rad(fov) * 0.5) * (16.0 / 9.0) * 0.84
	var distance: float = float(opts.get("min", 2.0))
	for point: Vector3 in points:
		var v: Vector3 = point - center
		var depth: float = v.dot(dir)
		distance = maxf(distance, absf(v.dot(right)) / tan_h - depth)
		distance = maxf(distance, absf(v.dot(up)) / tan_v - depth)
	distance = minf(distance, float(opts.get("max", 11.0)))
	var eye: Vector3 = center - dir * distance
	eye.y = maxf(eye.y, 0.25)
	if bool(opts.get("outside", false)):
		# la caméra est dehors et regarde à travers la porte : la ligne de visée passe par l'ouverture
		eye.z = maxf(eye.z, 0.9)
		if absf(eye.x) > half_open + 0.2 and eye.z < 4.0:
			eye.x = signf(eye.x) * (half_open - 0.2)
	if bool(opts.get("from_outside", false)): eye.z = maxf(eye.z, 0.9)
	var drift: Vector3 = opts.get("drift", Vector3.ZERO)
	var look: Vector3 = center
	var spec: Dictionary = {"rel": Vector3(0.0, 0.0, door_z), "eye": [eye, eye + drift], "look": [_f(look), _f(look + drift * 0.3)], "fov": fov, "hand": float(opts.get("hand", 0.3)), "safe": true}
	if opts.has("ease"): spec["ease"] = opts.ease
	film._shot(t0, spec)


# ------------------------------------------------------------------ accessoires

# Point du repère E → point film-local de PaperCinema.
func _f(e: Vector3) -> Vector3:
	return Vector3(e.x, e.y, door_z + e.z)


func _hedge_dust(t: float, lane: float) -> void :
	film._cue(t, "dust_ring", _f(Vector3(lane, 0.05, 0.0)), 0.6)


# Largeur libre de la porte (le portail est ouvert pendant le film) : la haie la ferme d'un mur à l'autre.
func _measure_opening() -> void :
	half_open = 2.9
	if not is_instance_valid(world) or not world.is_inside_tree(): return
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	if space == null: return
	var query: PhysicsPointQueryParameters3D = PhysicsPointQueryParameters3D.new()
	query.collision_mask = 1
	var reach: Array[float] = [3.4, 3.4]
	for s: int in range(2):
		var sign_x: float = -1.0 if s == 0 else 1.0
		var x: float = 0.4
		while x < 3.4:
			var hit: bool = false
			for h: float in [0.6, 1.3]:
				query.position = film.anchor + film.right * (sign_x * x) + film.forward * door_z + Vector3.UP * h
				if not space.intersect_point(query, 1).is_empty(): hit = true
			if hit:
				reach[s] = x
				break
			x += 0.1
	half_open = clampf(minf(reach[0], reach[1]) + 0.1, 1.9, 3.3)


# La haie de piques d'encre en travers de la porte (z ∈ [-0.3, 0.3]), mêmes piques courbes que
# le Shadow spike du jeu, plus basses : elles jaillissent du centre vers les bords quand la ligne
# d'encre arrive ; Lysia en casse sur son passage, la brèche repousse quand Alice s'y jette.
func _build_hedge() -> void :
	_hedge = Node3D.new();_hedge.name = "Hedge";add_child(_hedge)
	var basis: Basis = Basis(film.right, Vector3.UP, film.forward)
	_hedge.global_transform = Transform3D(basis, film.anchor + film.forward * door_z)
	var ink: StandardMaterial3D = StandardMaterial3D.new()
	ink.albedo_color = Color("241322");ink.roughness = 0.42;ink.metallic = 0.05
	ink.emission_enabled = true;ink.emission = Color("4a1027");ink.emission_energy_multiplier = 0.45
	ink.rim_enabled = true;ink.rim = 0.35;ink.rim_tint = 0.6
	var meshes: Array = []
	for k: int in range(4): meshes.append(Anim.thorn_mesh(1.0, [-0.9, -0.3, 0.35, 0.95][k]))
	var count: int = int(half_open * 2.0 / 0.17)
	for k: int in range(count):
		var u: float = float(k) / float(count - 1)
		var x: float = lerpf( - half_open, half_open, u) + 0.04 * Anim.n1(5, k)
		var row: int = k % 3
		var z: float = [-0.2, 0.04, 0.22][row] + 0.05 * Anim.n1(7, k)
		var edge: float = smoothstep(half_open - 0.9, half_open, absf(x))
		var height: float = (0.86 + 0.24 * absf(Anim.n1(11, k)) + 0.5 * edge) * (0.82 if row == 1 else 1.0)
		var width: float = 0.3 + 0.12 * absf(Anim.n1(13, k))
		var root: Node3D = Node3D.new()
		root.position = Vector3(x, 0.0, z)
		var yaw: float = PI * 0.5 * signf(Anim.n1(19, k)) + 0.5 * Anim.n1(23, k) + (PI if row == 0 else 0.0)
		root.rotation = Vector3(0.12 * Anim.n1(17, k), yaw, 0.0)
		_hedge.add_child(root)
		var spike: MeshInstance3D = MeshInstance3D.new()
		spike.mesh = meshes[k % meshes.size()]
		spike.material_override = ink
		spike.scale = Vector3(width, height, width)
		root.add_child(spike)
		var delay: float = absf(x) / maxf(half_open, 0.5) * 0.2 + 0.03 * absf(Anim.n1(29, k))
		_thorns.append({"node": root, "spike": spike, "x": x, "delay": delay, "tilt": root.rotation, "height": height, "width": width})
	_hedge.visible = false
	# la ligne d'encre au sol
	_ink = MeshInstance3D.new()
	var plane: BoxMesh = BoxMesh.new();plane.size = Vector3(0.3, 0.012, 1.0)
	_ink.mesh = plane
	_ink_material = StandardMaterial3D.new();_ink_material.albedo_color = Color("16081c");_ink_material.roughness = 0.3
	_ink_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ink_material.emission_enabled = true;_ink_material.emission = Color("5a0f2e");_ink_material.emission_energy_multiplier = 0.6
	_ink.material_override = _ink_material
	_ink.visible = false
	add_child(_ink)


func _ink_line(t: float, from: Vector3) -> void :
	_ink_from = from;_ink_t = t
	film._cue(t, "crack", _f(from), 1.4)
	film._cue(t, "sound", "shadow", _f(from), 0.9, 1.2)
	film._cue(T_HEDGE, "word", "seal", _f(Vector3(0, 1.75, 0.3)), CRIMSON, 1.1)
	film._cue(T_HEDGE, "shake", 0.45)
	film._cue(T_HEDGE, "impact", 0.5, true)
	film._cue(T_HEDGE, "sound", "ground_impact", _f(Vector3(0, 0.3, 0.0)), 0.9, 0.8)
	film._cue(T_HEDGE + 0.05, "word", "thorn", _f(Vector3(1.4, 1.2, 0.2)), Color("d86ad0"), 0.8)


func update(t: float, _delta: float) -> void :
	_update_ink(t)
	_update_hedge(t)
	_apply_contacts(t)


func _update_ink(t: float) -> void :
	if not is_instance_valid(_ink): return
	var travel: float = clampf((t - _ink_t) / maxf(T_HEDGE - _ink_t, 0.05), 0.0, 1.0)
	var fade: float = 1.0 - smoothstep(T_HEDGE + 0.3, T_HEDGE + 1.4, t)
	_ink.visible = t >= _ink_t and fade > 0.01
	if not _ink.visible: return
	var head: Vector3 = _ink_from.lerp(Vector3(_ink_from.x * 0.2, 0.0, -0.25), travel)
	var length: float = maxf(0.05, _ink_from.distance_to(head))
	var mid: Vector3 = (_ink_from + head) * 0.5
	var dir: Vector3 = (head - _ink_from).normalized() if length > 0.06 else Vector3(0, 0, 1)
	var basis: Basis = Basis(film.right, Vector3.UP, film.forward)
	var world_mid: Vector3 = film.anchor + basis * _f(mid + Vector3(0, 0.012, 0))
	var yaw: float = atan2(dir.x, dir.z)
	_ink.global_transform = Transform3D(basis * Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(1.0 + 0.6 * (1.0 - fade), 1.0, length)), world_mid)
	_ink_material.albedo_color.a = fade


func _update_hedge(t: float) -> void :
	if not is_instance_valid(_hedge): return
	_hedge.visible = t >= T_HEDGE - 0.02
	if not _hedge.visible: return
	for thorn: Dictionary in _thorns:
		var node: Node3D = thorn.node
		var u: float = (t - T_HEDGE - float(thorn.delay)) / 0.14
		var grow: float = 0.0
		if u > 0.0: grow = minf(smoothstep(0.0, 1.0, u) * 1.2, 1.0 + 0.2 * sin(minf(u, 3.0) * 2.4) * exp(-u * 0.9))
		var tilt: Vector3 = thorn.tilt
		for cut: Dictionary in _breaks:
			var gap: float = absf(float(thorn.x) - float(cut.x))
			if gap < 0.46:
				var k: float = clampf((t - float(cut.t0) - gap * 0.35) / 0.22, 0.0, 1.0)
				# la brèche repousse d'un coup quand Alice s'y jette
				var heal: float = clampf((t - float(cut.get("heal", INF)) - gap * 0.1) / 0.12, 0.0, 1.0)
				k *= 1.0 - heal
				grow *= lerpf(1.0, 0.25, k) * (1.0 + 0.25 * heal * exp(-maxf(t - float(cut.get("heal", INF)), 0.0) * 5.0))
				tilt = tilt + Vector3(0.0, 0.0, signf(float(thorn.x) - float(cut.x)) * 1.1 * k)
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
			var my_side: int = int(c.side)
			var mine: Vector3 = holder.socket_position("hand_r" if my_side > 0 else "hand_l")
			var meet: Vector3 = (mine + target) * 0.5
			_reach(holder, my_side, meet, w)
			_reach(other, int(c.get("mutual_side", 1)), meet, w)
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
