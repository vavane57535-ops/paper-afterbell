extends "res://anim_pose.gd"

# Fuites en équipe (0.17) : générateurs de clés pour les films « ending_survivors ».
# Aucun clip, émote ni geste de capacité du jeu : film_escape.gd distribue les rôles,
# calcule les trajets et les appuis, puis chaque module ci-dessous écrit ses clés dans
# la piste d'un acteur. Chaque acteur joue UN clip écrit pour ce film (fesc_…), qui
# tient tous les canaux du corps ("gait": 0, "plant": 1) : la démarche du jeu est coupée.
#
# Unités (voir anim_pose.gd) :
#   pieds et bassin en longueurs de jambe, relatifs à la pose de repos ;
#   mains en longueurs de bras, relatives à l'épaule ;
#   « rig » (film_escape.gd) donne ces longueurs en mètres pour chaque acteur.
# Repère d'un acteur : x à sa droite, y en haut, f devant lui (le canal stocke -f).

const STYLE: Dictionary = {
	# cadence (pas/s), vitesse de croisière (m/s), buste penché, bras (amplitude), poings, rebond, genou
	"Simon": {"cadence": 3.9, "speed": 5.4, "lean": 0.34, "arms": 1.1, "fist": 0.85, "bob": 0.05, "kick": 0.42, "width": 0.05, "head": 0.1, "flail": 0.25},
	"Usayuko": {"cadence": 3.5, "speed": 5.3, "lean": 0.26, "arms": 1.2, "fist": 1.0, "bob": 0.06, "kick": 0.38, "width": 0.07, "head": 0.0, "flail": 0.0},
	"Ashura": {"cadence": 3.6, "speed": 5.6, "lean": 0.24, "arms": 0.8, "fist": 0.6, "bob": 0.04, "kick": 0.3, "width": 0.06, "head": 0.05, "flail": 0.0},
	"Lysia": {"cadence": 3.3, "speed": 5.0, "lean": 0.12, "arms": 0.75, "fist": 0.15, "bob": 0.035, "kick": 0.3, "width": 0.05, "head": -0.05, "flail": 0.0},
	"Elly": {"cadence": 3.2, "speed": 5.1, "lean": 0.2, "arms": 0.85, "fist": 0.35, "bob": 0.05, "kick": 0.34, "width": 0.045, "head": 0.08, "flail": 0.1},
	"Bleuette": {"cadence": 4.2, "speed": 4.7, "lean": 0.16, "arms": 0.9, "fist": 0.4, "bob": 0.045, "kick": 0.36, "width": 0.06, "head": 0.12, "flail": 0.55},
	"Alice": {"cadence": 2.9, "speed": 5.6, "lean": 0.3, "arms": 0.55, "fist": 0.2, "bob": 0.04, "kick": 0.3, "width": 0.03, "head": -0.12, "flail": 0.0},
}


static func K(t: float, pose: Dictionary, flag: String = "") -> Array:
	return [t, pose] if flag.is_empty() else [t, pose, flag]


# Bruit déterministe dans [-1, 1] (variations d'un pas à l'autre, jamais deux cycles identiques).
static func n1(seed_value: int, i: int) -> float:
	var x: float = sin(float(seed_value) * 12.9898 + float(i) * 78.233) * 43758.5453
	return (x - floor(x)) * 2.0 - 1.0


# Pose de départ complète : tous les canaux que le moteur pourrait laisser à une autre
# couche (démarche, pose « en l'air ») sont tenus par le clip.
static func zero() -> Dictionary:
	return {"plant": 1.0, "gait": 0.0, "shake": 0.0, "jaw": 0.0, "chatter": 0.0, "turn": 0.0, "sq": 1.0,
		"el_l": 0.0, "el_r": 0.0, "fp_l": 0.0, "fp_r": 0.0, "hips": Vector3.ZERO, "body": Vector3.ZERO, "chest": Vector3.ZERO,
		"head": Vector3.ZERO, "foot_l": Vector3.ZERO, "foot_r": Vector3.ZERO, "feet": Vector3.ZERO,
		"l_clav": Vector3.ZERO, "r_clav": Vector3.ZERO, "l_hand": Vector3.ZERO, "r_hand": Vector3.ZERO,
		"ik_l": Vector3(-0.3, -0.88, -0.08), "ik_r": Vector3(0.3, -0.88, -0.08), "tf_l": 0.0, "tf_r": 0.0, "gr_l": 0.0, "gr_r": 0.0,
		"ikw_l": 1.0, "ikw_r": 1.0, "curl": 0.35, "curl_l": 0.35}


static func FACE(mood: String) -> Dictionary:
	return {"face": mood}


# épaules : haussement (+) et avancée (+)
static func SH(left: float, right: float, fwd_l: float = 0.0, fwd_r: float = 0.0) -> Dictionary:
	return {"l_clav": Vector3(0.0, - fwd_l, - left), "r_clav": Vector3(0.0, fwd_r, right)}


# clignement : paupières fermées un instant (humeur « asleep »), puis la mine `after`
static func blink(k: Array, t: float, after: String, hold: float = 0.08) -> void :
	k.append(K(t, FACE("asleep")))
	k.append(K(t + hold, FACE(after)))


# ------------------------------------------------------------------ PIEDS --

# Canal d'un pied pour une cheville posée à (droite, haut, devant) mètres de l'origine
# de l'acteur : relatif à la pose de repos, en longueurs de jambe.
static func foot(rig: Dictionary, side: int, right_m: float, fwd_m: float, up_m: float = 0.0) -> Dictionary:
	var idle: Vector3 = rig.idle_l if side < 0 else rig.idle_r
	var leg: float = float(rig.leg)
	var v: Vector3 = Vector3((right_m - idle.x) / leg, up_m / leg, - (fwd_m - (- idle.z)) / leg)
	return {("foot_l" if side < 0 else "foot_r"): v}


# Pieds à leur place de repos, écartés de `spread` m de plus et décalés (devant +).
static func feet(rig: Dictionary, spread: float = 0.0, fwd_l: float = 0.0, fwd_r: float = 0.0, up_l: float = 0.0, up_r: float = 0.0) -> Dictionary:
	var idle_l: Vector3 = rig.idle_l
	var idle_r: Vector3 = rig.idle_r
	return M([foot(rig, -1, idle_l.x - spread * 0.5, - idle_l.z + fwd_l, up_l), foot(rig, 1, idle_r.x + spread * 0.5, - idle_r.z + fwd_r, up_r)])


# Bassin : décalage en mètres (droite, haut, devant) converti en longueurs de jambe.
static func hips_m(rig: Dictionary, right_m: float, up_m: float, fwd_m: float) -> Dictionary:
	var leg: float = float(rig.leg)
	return {"hips": Vector3(right_m / leg, up_m / leg, - fwd_m / leg)}


# ------------------------------------------------------------- LOCOMOTION --

# Course ou marche écrite au mètre près. `steps` vient de film_escape.gd : pour chaque
# appui, {t, side, stance, land (Vector3 m dans le repère de l'acteur à l'instant t),
# off (idem à la fin de l'appui), speed, last}. Pendant l'appui, le pied passe en
# ligne droite de `land` à `off` : il reste fixe au sol pendant que l'acteur avance.
# Puis le talon monte, le genou repasse devant et le pied va se poser au pas suivant.
# Le haut du corps (buste penché, bras opposés aux jambes, tête stabilisée) suit les
# appuis, avec de petites variations à chaque pas.
static func locomotion(k: Array, rig: Dictionary, style: Dictionary, steps: Array, opts: Dictionary = {}) -> void :
	if steps.is_empty(): return
	var person: String = str(rig.person)
	var seed_value: int = absi(person.hash()) % 977 + int(opts.get("seed", 0))
	var leg: float = float(rig.leg)
	var toe: float = float(rig.toe)
	var walk: bool = bool(opts.get("walk", false))
	var lean: float = float(opts.get("lean", style.lean))
	var arms: float = float(opts.get("arms", style.arms))
	var kick: float = float(opts.get("kick", style.kick)) * leg
	var bob: float = float(opts.get("bob", style.bob)) * leg
	var low: float = float(opts.get("low", 0.09 if not walk else 0.03)) * leg
	var fist: float = float(opts.get("fist", style.fist))
	var flail: float = float(opts.get("flail", style.get("flail", 0.0)))
	var head_up: float = float(opts.get("head", style.get("head", 0.0)))
	var arm_tf: float = float(opts.get("arm_frame", 1.0))
	var skip_arms: bool = bool(opts.get("no_arms", false))
	var skip_body: bool = bool(opts.get("no_body", false))
	var face: String = str(opts.get("face", ""))
	for j: int in range(steps.size()):
		var s: Dictionary = steps[j]
		var t: float = float(s.t)
		var side: int = int(s.side)
		var stance: float = float(s.stance)
		var land: Vector3 = s.land
		var off: Vector3 = s.off
		var fp: String = "fp_l" if side < 0 else "fp_r"
		var wob: float = n1(seed_value, j)
		var wob2: float = n1(seed_value + 31, j)
		# appui : posé (léger talon), ligne droite jusqu'à la poussée
		var strike: float = (0.16 if walk else 0.08) + 0.04 * wob
		k.append(K(t, M([foot(rig, side, land.x, land.z, land.y), {fp: strike}]), "l"))
		if walk: k.append(K(t + stance * 0.25, M([foot(rig, side, land.x + (off.x - land.x) * 0.25, land.z + (off.z - land.z) * 0.25, 0.0), {fp: 0.0}]), "l"))
		var push: float = (-0.45 if walk else -0.6) + 0.08 * wob2
		var heel: float = toe * sin( - push)
		var last: bool = bool(s.get("last", false))
		if last:
			# dernier appui : le pied reste posé, la suite du clip reprend la main
			k.append(K(t + stance, M([foot(rig, side, off.x, off.z, off.y), {fp: 0.0}])))
		else:
			k.append(K(t + stance, M([foot(rig, side, off.x, off.z, heel), {fp: push}])))
			# vol : le talon remonte derrière, le genou repasse devant, la jambe s'allonge
			var next_land: Vector3 = Vector3.ZERO
			var next_t: float = t + stance * 2.0
			for m: int in range(j + 1, steps.size()):
				if int(steps[m].side) == side:
					next_land = steps[m].land
					next_t = float(steps[m].t)
					break
			if next_land == Vector3.ZERO: next_land = Vector3(off.x, 0.0, land.z)
			var swing: float = next_t - (t + stance)
			var lift: float = kick * (0.55 if walk else 1.0) * (1.0 + 0.12 * wob)
			var x_mid: float = lerpf(off.x, next_land.x, 0.5) - float(side) * 0.012
			k.append(K(t + stance + swing * 0.24, M([foot(rig, side, lerpf(off.x, x_mid, 0.4), off.z - 0.04 * leg, lift * 0.72), {fp: push - 0.25}])))
			k.append(K(t + stance + swing * 0.52, M([foot(rig, side, x_mid, lerpf(off.z, next_land.z, 0.5) + 0.04 * leg, lift * 0.9), {fp: push * 0.5}])))
			k.append(K(t + stance + swing * 0.8, M([foot(rig, side, lerpf(x_mid, next_land.x, 0.7), next_land.z + 0.06 * leg, lift * 0.32 + 0.03), {fp: 0.22}])))
		if skip_body: continue
		# bassin : écrasé à mi-appui, remonte pendant l'envol, glisse vers la jambe d'appui
		var mid: float = t + stance * 0.5
		k.append(K(mid, hips_m(rig, float(side) * 0.018, - low - bob * (1.0 + 0.2 * wob), 0.02 * leg)))
		if not last:
			var flight: float = t + stance + (float(s.get("period", stance * 2.5)) - stance) * 0.5
			k.append(K(flight, hips_m(rig, 0.0, - low + bob * (0.35 if walk else 0.6), 0.025 * leg)))
		# buste : penché vers l'avant, roule vers la jambe d'appui ; la poitrine contre-tourne
		var speed: float = float(s.get("speed", 4.0))
		var lean_now: float = lean * clampf(speed / 4.5, 0.35, 1.15)
		k.append(K(t + stance * 0.3, M([B(lean_now + 0.03 * wob, float(side) * 0.1, float(side) * -0.035), C(0.04 + 0.02 * wob2, float(side) * -0.2 * arms, float(side) * 0.02), HD(lean_now * 0.75 + head_up + 0.04 * wob2, float(side) * 0.08, float(side) * 0.03)])))
		if skip_arms: continue
		# bras : opposés aux jambes, l'extrême juste après le poser (rattrapage)
		var at: float = t + stance * 0.35 + 0.02
		var front: int = - side
		var a: float = arms * (1.0 + 0.1 * wob2)
		var fl: float = flail * (0.5 + 0.5 * wob)
		var fwd_arm: Dictionary = _arm(front, Vector3(0.12 + 0.12 * fl, -0.28 + 0.12 * a - 0.05 * fl, 0.32 + 0.24 * a), 0.25 + 0.3 * fl, arm_tf)
		var back_arm: Dictionary = _arm(side, Vector3(0.16 + 0.15 * fl, -0.62 + 0.04 * a, -0.18 - 0.26 * a), 0.35 + 0.25 * fl, arm_tf)
		var curls: Dictionary = {"curl": fist + 0.08 * wob, "curl_l": fist + 0.08 * wob2}
		k.append(K(at, M([fwd_arm, back_arm, curls, WL(0.1 * a, 0.2), WR(0.1 * a, -0.2)])))
	if not face.is_empty(): k.append(K(float(steps[0].t), FACE(face)))


# Bras vers une position (dehors, haut, devant) en longueurs de bras ; `frame` 1 = repère du buste.
static func _arm(side: int, at: Vector3, flare: float, frame: float) -> Dictionary:
	if side < 0: return {"ik_l": Vector3( - at.x, at.y, - at.z), "el_l": flare, "tf_l": frame, "gr_l": 0.0}
	return {"ik_r": Vector3(at.x, at.y, - at.z), "el_r": flare, "tf_r": frame, "gr_r": 0.0}
