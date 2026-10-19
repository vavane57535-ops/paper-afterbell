class_name PaperNetMotion
extends RefCounted

# État réseau du mouvement d'un acteur (0.17).
# Chez l'hôte, pour un joueur distant : le client calcule lui-même son mouvement (prédiction) et
# envoie sa position ; l'hôte la suit, relue sans à-coups (petit tampon anti-jitter) et bornée
# (vitesse maximale, hauteur de saut, murs). Quand l'hôte reprend la main (téléportation, coup,
# étourdissement, film…) ou refuse un déplacement, l'« epoch » change : le client se recale sur
# l'hôte et les messages de l'ancien epoch sont ignorés.
# Chez le client : état de la prédiction du joueur local, et tampon d'instantanés horodatés
# pour interpoler les autres acteurs.

const REPORT_FLAG_POSITION: int = 1
const REPORT_FLAG_FLOOR: int = 2
const REPORT_FLAG_SPRINT: int = 4

const HOLD_LIMIT: float = 1.0
const REJECT_DISTANCE: float = 0.45
const SPEED_TOLERANCE: float = 1.2
const SPEED_SLACK: float = 0.6
const BUDGET_SECONDS: float = 0.35
const VIEW_HISTORY: float = 1.2
const JUMP_HEIGHT: float = PaperRules.OM_JUMP_VELOCITY * PaperRules.OM_JUMP_VELOCITY / (2.0 * PaperRules.OM_GRAVITY)

# --- Hôte : suivi d'un joueur distant ---
var remote: bool = false
var epoch: int = 0
var owned: bool = true
var reports: Array = []
var last_seq: int = -1
var offset_min: float = INF
var offsets: Array = []
var delay: float = 0.004
var last_arrival: float = -100.0
var budget: float = 0.0
var peak_speed: float = 0.0
var peak_until: float = 0.0
var anchor_y: float = 0.0
var last_pos: Vector3 = Vector3.ZERO
var follow_frame: int = -10
var view_lag: float = 0.0
var views: Array = []
var jumps: int = -1
var rolls: int = -1
var roll_until: float = 0.0
var air_time: float = 0.0
var air_peak: float = 0.0
var rejections: int = 0
var resyncs: int = 0

# --- Client : prédiction du joueur local ---
var host_epoch: int = -1
var host_owned: bool = true
var host_followed: bool = false
var host_pos: Vector3 = Vector3.ZERO
var host_vel: Vector3 = Vector3.ZERO
var correction: Vector3 = Vector3.ZERO
var seq: int = 0
var local_jumps: int = 0
var local_rolls: int = 0

# --- Client : interpolation des autres acteurs ---
var samples: Array = []


# Hôte : l'hôte reprend la main ou refuse un déplacement. Le client se recalera sur la position de
# l'hôte ; ses messages encore en route (ancien epoch) seront ignorés.
func resync(actor: PaperActor) -> void :
	epoch = (epoch + 1) & 255
	reports.clear()
	resyncs += 1
	last_pos = actor.global_position


# Hôte : un message de position du client (déjà décodé) arrive à l'instant `arrival` (horloge de l'hôte).
func receive(report: Dictionary, arrival: float) -> void :
	var seq_in: int = int(report.seq)
	if last_seq >= 0 and ((seq_in - last_seq) & 0xFFFF) > 0x8000: return
	last_seq = seq_in
	var tc: float = float(report.tc)
	var offset: float = arrival - tc
	offsets.append([arrival, offset])
	while offsets.size() > 1 and arrival - float(offsets[0][0]) > 2.0: offsets.pop_front()
	var low: float = INF
	for sample: Array in offsets: low = minf(low, float(sample[1]))
	# Décalage d'horloge client → hôte suivi sur le paquet le plus rapide, ré-estimé en douceur.
	offset_min = low if offset_min == INF or absf(low - offset_min) > 0.25 else move_toward(offset_min, low, 0.0001)
	var spread: Array = []
	for sample: Array in offsets: spread.append(float(sample[1]) - low)
	spread.sort()
	var wanted: float = clampf(float(spread[int(spread.size() * 0.9)]) + 0.004, 0.004, 0.08)
	delay = move_toward(delay, wanted, 0.001 if wanted > delay else 0.0002)
	last_arrival = arrival
	var tv: float = float(report.tv)
	view_lag = arrival - tv if views.is_empty() else lerpf(view_lag, arrival - tv, 0.1)
	if not bool(report.has_position): return
	if not reports.is_empty() and tc <= float(reports[-1].tc): return
	reports.append(report)
	while reports.size() > 48: reports.pop_front()
	# Ce que le joueur voyait de lui-même quand son écran montrait l'instant tv de l'hôte.
	tv = minf(tv, arrival)
	if views.is_empty() or tv > float(views[-1][0]):
		views.append([tv, report.pos])
		while views.size() > 2 and tv - float(views[0][0]) > VIEW_HISTORY: views.pop_front()


# Hôte : position du client à rejouer maintenant (interpolée entre deux messages, en retard de
# `delay` sur le paquet le plus rapide pour absorber le jitter). Vide s'il n'y a rien à rejouer.
func playback(now: float) -> Dictionary:
	if reports.is_empty(): return {}
	var play: float = now - offset_min - delay
	var last: Dictionary = reports[-1]
	if play >= float(last.tc):
		var ahead: float = minf(play - float(last.tc), 0.05)
		return {"pos": Vector3(last.pos) + Vector3(last.vel) * ahead, "vel": last.vel, "flags": int(last.flags), "stale": play - float(last.tc)}
	var first: Dictionary = reports[0]
	if play <= float(first.tc): return {"pos": first.pos, "vel": first.vel, "flags": int(first.flags), "stale": 0.0}
	var i: int = 0
	while i + 2 < reports.size() and float(reports[i + 1].tc) <= play: i += 1
	var a: Dictionary = reports[i]
	var b: Dictionary = reports[i + 1]
	var u: float = clampf((play - float(a.tc)) / maxf(float(b.tc) - float(a.tc), 0.0001), 0.0, 1.0)
	if i > 0: reports = reports.slice(i)
	return {"pos": Vector3(a.pos).lerp(b.pos, u), "vel": Vector3(a.vel).lerp(b.vel, u), "flags": int(b.flags if u > 0.5 else a.flags), "stale": 0.0}


# Vitesse au sol la plus haute que l'acteur peut avoir en ce moment (mêmes règles que actor.gd).
static func max_speed(actor: PaperActor) -> float:
	var fx: Dictionary = actor.effects
	var speed: float = PaperRules.OM_KILLER_SPRINT if actor.killer else PaperRules.OM_SURVIVOR_SPRINT
	if float(fx.get("slow_time", 0.0)) > 0: speed *= clampf(float(fx.get("slow_factor", 0.85)), 0.1, 1.0)
	if float(fx.get("boost_time", 0.0)) > 0: speed *= maxf(1.0, float(fx.get("boost_factor", 2.0)))
	elif float(fx.get("adrenaline", 0.0)) > 0: speed *= 2.0 if actor.character == "Bleuette" else 1.3
	if float(fx.get("landing_boost_time", 0)) > 0: speed *= 1.25
	if float(fx.get("speed_boost", 0)) > 0: speed = maxf(speed, PaperRules.OM_SURVIVOR_SPRINT * PaperRules.OM_BOOST_FACTOR * maxf(1.0, float(fx.get("carry_speed_factor", 1.0))))
	if float(fx.get("phase6", 0.0)) > 0: speed *= PaperRules.TRUE_FORM_SPEED_FACTOR
	return speed


# Hôte, appelé par PaperActor.tick à la place de son propre calcul de mouvement : le corps suit la
# position envoyée par le client, dans les limites anti-triche. Renvoie false pour laisser l'hôte
# simuler lui-même (client muet depuis plus d'une seconde).
static func follow(actor: PaperActor, delta: float) -> bool:
	var m: PaperNetMotion = actor.net_motion
	if m == null: return false
	var now: float = float(actor.get_parent().get("clock"))
	var frame: int = Engine.get_physics_frames()
	# L'hôte a déplacé le corps depuis notre dernier pas (téléportation, film, terrain d'essai…) ou
	# vient de rendre la main : le client doit se recaler sur cette position.
	if frame - m.follow_frame > 1 or actor.global_position.distance_to(m.last_pos) > 0.02: m.resync(actor)
	m.follow_frame = frame
	var sample: Dictionary = m.playback(now)
	if sample.is_empty() or float(sample.get("stale", 0.0)) > HOLD_LIMIT:
		if now - m.last_arrival > HOLD_LIMIT:
			m.last_pos = actor.global_position
			return false
		actor.velocity = Vector3.ZERO
		m.budget = minf(m.budget + max_speed(actor) * SPEED_TOLERANCE * delta, max_speed(actor) * BUDGET_SECONDS + 0.25)
		m.last_pos = actor.global_position
		return true
	var speed: float = max_speed(actor)
	if now < m.roll_until: speed = maxf(speed, 13.0)
	# Un ralentissement ou une fin de bonus n'arrive chez le client qu'un aller simple plus tard :
	# on garde l'ancienne vitesse permise un court instant.
	if speed >= m.peak_speed or now > m.peak_until:
		m.peak_speed = speed;m.peak_until = now + 0.45
	var allowed: float = m.peak_speed * SPEED_TOLERANCE + SPEED_SLACK
	m.budget = minf(m.budget + allowed * delta, allowed * BUDGET_SECONDS + 0.25)
	var start: Vector3 = actor.global_position
	var target: Vector3 = sample.pos
	var flat: Vector3 = Vector3(target.x - start.x, 0.0, target.z - start.z)
	var refused: bool = false
	if flat.length() > m.budget:
		refused = flat.length() - m.budget > REJECT_DISTANCE
		flat = flat.normalized() * m.budget
		target = Vector3(start.x + flat.x, target.y, start.z + flat.z)
	m.budget = maxf(0.0, m.budget - flat.length())
	if actor.is_on_floor(): m.anchor_y = start.y
	var ceiling: float = m.anchor_y + JUMP_HEIGHT * 1.15 + 0.6
	if target.y > ceiling:
		refused = refused or target.y - ceiling > REJECT_DISTANCE
		target.y = ceiling
	actor.velocity = (target - start) / maxf(delta, 0.0001)
	actor.move_and_slide()
	# Bloqué par un mur (ou position refusée) : l'hôte garde sa position, le client se recale.
	if refused or actor.global_position.distance_to(target) > REJECT_DISTANCE:
		m.rejections += 1
		m.resync(actor)
	actor.velocity = sample.vel
	var airborne: bool = (int(sample.flags) & REPORT_FLAG_FLOOR) == 0
	m.air_time = m.air_time + delta if airborne else 0.0
	m.air_peak = maxf(m.air_peak, actor.global_position.y) if airborne else actor.global_position.y
	actor.effects["airborne"] = airborne;actor.effects["air_time"] = m.air_time;actor.effects["air_peak_delta"] = maxf(0.0, m.air_peak - actor.global_position.y)
	m.last_pos = actor.global_position
	return true


# --- Client : interpolation ---------------------------------------------------------------------

func push_sample(t: float, pos: Vector3, vel: Vector3) -> void :
	if not samples.is_empty():
		var last_t: float = float(samples[-1][0])
		if t < last_t: return
		if t == last_t: samples[-1] = [t, pos, vel];return
	samples.append([t, pos, vel])
	while samples.size() > 40: samples.pop_front()


# Position et vitesse à l'instant t (horloge de l'hôte) : Hermite entre les deux instantanés qui
# encadrent t ; au-delà du dernier, on prolonge la vitesse 100 ms au plus.
func sample_at(t: float) -> Array:
	var n: int = samples.size()
	if n == 0: return []
	if t <= float(samples[0][0]): return [samples[0][1], samples[0][2]]
	var last: Array = samples[n - 1]
	if t >= float(last[0]):
		var ahead: float = minf(t - float(last[0]), 0.1)
		return [Vector3(last[1]) + Vector3(last[2]) * ahead, last[2]]
	var i: int = n - 2
	while i > 0 and float(samples[i][0]) > t: i -= 1
	var a: Array = samples[i]
	var b: Array = samples[i + 1]
	if i > 2: samples = samples.slice(i - 2)
	var h: float = maxf(float(b[0]) - float(a[0]), 0.0001)
	var u: float = clampf((t - float(a[0])) / h, 0.0, 1.0)
	var pa: Vector3 = a[1]
	var pb: Vector3 = b[1]
	if pa.distance_to(pb) > 4.0 or h > 0.35: return [pb if u > 0.5 else pa, b[2]]
	var va: Vector3 = Vector3(a[2]) * h
	var vb: Vector3 = Vector3(b[2]) * h
	var u2: float = u * u
	var u3: float = u2 * u
	var p: Vector3 = pa * (2.0 * u3 - 3.0 * u2 + 1.0) + va * (u3 - 2.0 * u2 + u) + pb * (-2.0 * u3 + 3.0 * u2) + vb * (u3 - u2)
	return [p, Vector3(a[2]).lerp(b[2], u)]
