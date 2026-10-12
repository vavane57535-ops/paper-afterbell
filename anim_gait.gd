extends RefCounted

# Locomotion procédurale des personnages : cadence, paramètres et courbes par allure.
# Allures mélangées selon la vitesse : 0 marche, 1 footing (~6 m/s), 2 sprint (~10 m/s), 3 sur-sprint (boost, ~20 m/s).
#
# Oscillation d'une jambe, du décollage des orteils (s = 0) à la pose du pied (s = 1) :
#  - cuisse : angle avec la verticale (+ = vers l'avant), en degrés ;
#  - genou : flexion, en degrés ;
#  - cheville : rotation du pied par rapport au tibia (+ = pointe relevée), en radians.
# Repères biomécaniques (Novacheck 1998, Mann) : talon qui remonte sous les fesses puis montée du genou,
# extension du tibia en fin d'oscillation et pied qui « griffe » vers l'arrière juste avant la pose.

const WALK: int = 0
const RUN: int = 1
const SPRINT: int = 2
const BOOST: int = 3

const KNOTS: PackedFloat32Array = [0.0, 0.15, 0.35, 0.55, 0.75, 0.9, 1.0]

const THIGH: Array = [
	[-16.0, -11.0, 3.0, 17.0, 25.0, 27.0, 18.0],
	[-24.0, -18.0, 2.0, 27.0, 42.0, 37.0, 29.0],
	[-30.0, -22.0, 1.0, 42.0, 66.0, 52.0, 34.0],
	[-34.0, -24.0, 5.0, 52.0, 80.0, 60.0, 37.0],
]
const KNEE: Array = [
	[36.0, 55.0, 60.0, 40.0, 15.0, 5.0, 3.0],
	[26.0, 64.0, 100.0, 98.0, 58.0, 28.0, 19.0],
	[30.0, 88.0, 128.0, 120.0, 72.0, 32.0, 22.0],
	[32.0, 96.0, 140.0, 132.0, 80.0, 34.0, 22.0],
]
const ANKLE: Array = [
	[-0.25, -0.12, 0.05, 0.12, 0.12, 0.08, 0.05],
	[0.05, -0.25, -0.25, -0.05, 0.12, 0.08, -0.04],
	[0.08, -0.3, -0.3, -0.05, 0.12, 0.04, -0.22],
	[0.08, -0.3, -0.3, -0.05, 0.12, 0.04, -0.25],
]

# Paramètres par allure (mêmes colonnes pour les quatre allures).
const P_SWEEP: int = 0 # course du pied d'appui sous la hanche (× longueur de jambe)
const P_LEAD: int = 1 # part de cette course devant la hanche à la pose
const P_DUTY: int = 2 # part d'appui visée (sert à la marche)
const P_LEAN: int = 3 # inclinaison du buste vers l'avant (rad)
const P_PRESS: int = 4 # écrasement du bassin à mi-appui (× jambe)
const P_YAW: int = 5 # rotation du bassin (rad)
const P_TWIST: int = 6 # contre-rotation des épaules (× rotation du bassin)
const P_ROLL: int = 7 # bascule du bassin côté jambe libre (rad)
const P_SWAY: int = 8 # balancement latéral du bassin (× jambe)
const P_ARM_F: int = 9 # flexion de l'épaule, bras devant (rad)
const P_ARM_B: int = 10 # extension de l'épaule, bras derrière (rad)
const P_ELB: int = 11 # flexion de base du coude (rad)
const P_ELB_F: int = 12 # flexion en plus quand la main passe devant
const P_ELB_B: int = 13 # ouverture du coude quand le bras est derrière
const P_CROSS: int = 14 # la main rentre vers l'axe du corps devant (rad)
const P_ABD: int = 15 # écartement des bras (rad)
const P_NOD: int = 16 # hochement de tête à chaque pas (rad)
const P_C0: int = 17 # angle du pied à la pose (+ = talon, - = avant-pied)
const P_FLAT: int = 18 # angle du pied à mi-appui
const P_TOE: int = 19 # angle du pied au décollage (talon levé)
const P_RISE: int = 20 # moment de l'appui où le talon commence à se lever
const P_WIDTH: int = 21 # écart latéral des appuis (× demi-largeur du bassin)
const P_CROUCH: int = 22 # bassin plus bas en moyenne (× jambe)
const P_COUNT: int = 23

const PARAMS: Array = [
	[1.0, 0.48, 0.6, 0.04, 0.0, 0.07, 0.55, 0.05, 0.026, 0.3, 0.26, 0.2, 0.22, -0.04, 0.06, 0.1, 0.0, 0.3, 0.0, -0.55, 0.55, 0.95, 0.012],
	[0.95, 0.38, 0.3, 0.24, 0.045, 0.09, 1.0, 0.05, 0.01, 0.62, 0.52, 1.42, 0.16, 0.12, 0.16, 0.13, 0.035, 0.08, 0.0, -0.85, 0.5, 0.62, 0.03],
	[1.0, 0.33, 0.22, 0.5, 0.035, 0.12, 1.2, 0.04, 0.006, 1.02, 0.86, 1.5, 0.38, 0.45, 0.12, 0.14, 0.025, -0.12, -0.05, -0.95, 0.42, 0.5, 0.04],
	[1.04, 0.31, 0.17, 0.95, 0.03, 0.13, 1.25, 0.03, 0.004, 1.2, 1.0, 1.55, 0.45, 0.5, 0.1, 0.16, 0.015, -0.16, -0.08, -1.0, 0.36, 0.45, 0.06],
]

const CADENCE_SPEEDS: PackedFloat32Array = [0.0, 1.0, 1.5, 2.0, 3.0, 4.5, 6.3, 8.0, 10.2, 14.0, 20.4, 26.0]
const CADENCE_VALUES: PackedFloat32Array = [0.8, 0.9, 0.98, 1.05, 1.28, 1.38, 1.48, 1.68, 2.02, 2.45, 3.0, 3.3]
const REFERENCE_LEG: float = 0.85


# Fréquence du cycle (cycles / s) pour une jambe (hanche → cheville) de référence de 0,85 m.
static func cadence(speed: float) -> float:
	var xs: PackedFloat32Array = CADENCE_SPEEDS
	var ys: PackedFloat32Array = CADENCE_VALUES
	if speed <= xs[0]: return ys[0]
	for i in range(1, xs.size()):
		if speed < xs[i]: return lerpf(ys[i - 1], ys[i], (speed - xs[i - 1]) / (xs[i] - xs[i - 1]))
	return ys[ys.size() - 1]


# Mélange les allures (poids w) dans params et dans les trois courbes d'oscillation (angles en radians).
# knee_lift agrandit la montée du genou, heel_kick le repli du talon (les extrémités restent intactes).
static func mix(w: PackedFloat32Array, params: PackedFloat32Array, thigh: PackedFloat32Array, knee: PackedFloat32Array, ankle: PackedFloat32Array, knee_lift: float = 1.0, heel_kick: float = 1.0) -> void :
	params.resize(P_COUNT)
	thigh.resize(KNOTS.size())
	knee.resize(KNOTS.size())
	ankle.resize(KNOTS.size())
	params.fill(0.0)
	thigh.fill(0.0)
	knee.fill(0.0)
	ankle.fill(0.0)
	for g in range(4):
		var k: float = w[g]
		if k <= 0.0001: continue
		var row: Array = PARAMS[g]
		for i in range(P_COUNT): params[i] += float(row[i]) * k
		var th: Array = THIGH[g]
		var kn: Array = KNEE[g]
		var an: Array = ANKLE[g]
		for i in range(KNOTS.size()):
			thigh[i] += deg_to_rad(float(th[i])) * k
			knee[i] += deg_to_rad(float(kn[i])) * k
			ankle[i] += float(an[i]) * k
	var last: int = KNOTS.size() - 1
	for i in range(1, last):
		if thigh[i] > 0.0: thigh[i] *= knee_lift
		var edge: float = lerpf(knee[0], knee[last], KNOTS[i])
		knee[i] = edge + (knee[i] - edge) * heel_kick


# Courbe d'Hermite (tangentes de Catmull-Rom) à travers les nœuds.
static func sample(ys: PackedFloat32Array, x: float) -> float:
	var xs: PackedFloat32Array = KNOTS
	var count: int = xs.size()
	var i: int = count - 2
	for k in range(count - 1):
		if x < xs[k + 1]:
			i = k
			break
	var span: float = xs[i + 1] - xs[i]
	var u: float = clampf((x - xs[i]) / span, 0.0, 1.0)
	var m0: float = (ys[i + 1] - ys[i]) / span if i == 0 else (ys[i + 1] - ys[i - 1]) / (xs[i + 1] - xs[i - 1])
	var m1: float = (ys[i + 1] - ys[i]) / span if i + 2 >= count else (ys[i + 2] - ys[i]) / (xs[i + 2] - xs[i])
	var u2: float = u * u
	var u3: float = u2 * u
	return ys[i] * (2.0 * u3 - 3.0 * u2 + 1.0) + m0 * span * (u3 - 2.0 * u2 + u) + ys[i + 1] * (-2.0 * u3 + 3.0 * u2) + m1 * span * (u3 - u2)
