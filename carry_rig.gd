extends RefCounted

# Portages de Simon pendant la course éclair (0.17) : un montage différent par allié porté.
# Le visuel porté est posé sur le visuel de Simon (character_visual.gd, passe « carry_finalize ») :
#   anchor : repère de Simon qui sert d'appui
#     "root"  : ses pieds (sol) et son cap ;
#     "chest" / "hips" : la position de son buste / de son bassin et son cap (le porté suit les rebonds de la
#       foulée, pas ses rotations) ;
#     "back"  : son buste complet, inclinaison comprise.
#   offset / yaw : racine du porté dans ce repère (mètres ; x à droite, y en haut, z vers l'arrière).
#   ground : la racine se recale sur le sol (roulettes d'Ashura, dos d'Usayuko).
#   grab : durée de la prise (s) ; le porté glisse de là où il était jusqu'à sa place ; arc : bosse (m) de cette
#     trajectoire ; spin : sens imposé de sa rotation (+1 vers la gauche, -1 vers la droite, 0 le plus court).
#   trail : ressort (raideur, amortissement) de la traîne en virage autour de « pivot » (variantes au sol) ;
#     bank : roulis (rad par rad de traîne) vers l'intérieur du virage.
#   contacts : mains qui tiennent vraiment quelque chose, résolues par IK après les deux poses (la paume vient
#     sur le point visé).
#     who : "carried" (main du porté) ou "carrier" (main de Simon) ; hand : "l" / "r" (ou foot : "l" / "r", la
#       cheville du porté amenée par IK de jambe) ;
#     node : articulation visée chez l'autre (palm_l, palm_r, root, neck, head, chest, body, knee_l, knee_r, knees,
#       ankle_l, ankle_r, arm_l, arm_r, elbow_l, elbow_r, leg_l, leg_r, thigh_l, thigh_r) ;
#     at : décalage en mètres dans le repère de la racine de l'autre (x droite, y haut, z arrière) ;
#     wrist : rotation du poignet (rad) ; aim : direction visée par l'objet tenu (repère de Simon) ;
#     on / full : la main arrive (poids 0 → 1) entre ces deux instants (horloge du portage) ;
#     off / free : la main lâche (poids 1 → 0) entre ces deux instants (facultatif).
#   aim : arme tenue (hand), braquée vers dir (repère de Simon), l'autre main (support) posée « reach » mètres plus
#     loin le long du canon ; on / full comme un contact.
#   desired : où combat.gd range l'acteur porté (repère du sol de Simon), près de son visuel.
#   lean : part de l'inclinaison « Sonic » que Simon garde pendant ce portage (1 = buste plongé, 0 = droit).
#   gait : allure de Simon pendant ce portage (clés de SONIC_GAIT, anim_set_simon.gd).
# Lysia n'est jamais portée (règle de jeu, combat.gd) : pas de montage pour elle.

const CARRIER: String = "Simon"

const VARIANTS: Dictionary = {
	# Tiré par la main gauche de Simon, à sa gauche et un peu en arrière, accroupi en patineur de vitesse sur ses
	# rollers ; en virage il part vers l'extérieur autour de la main de Simon et se penche vers l'intérieur.
	"Ashura": {
		"key": "ashura", "anchor": "root", "offset": Vector3(-0.78, 0.0, 0.44), "yaw": -0.12, "ground": true, "grab": 0.34,
		"trail": Vector2(32.0, 9.0), "pivot": Vector3(-0.38, 0.0, 0.02), "bank": 0.45,
		"lean": 1.0,
		"contacts": [
			{"who": "carried", "hand": "r", "node": "palm_l", "at": Vector3(0.0, -0.01, 0.0), "wrist": Vector3(0.0, 0.0, 0.0), "on": 0.05, "full": 0.11},
		],
		"desired": Vector3(-0.78, 0.1, 0.44),
	},
	# En princesse : bras gauche de Simon sous son dos, bras droit sous ses genoux ; elle s'accroche à son cou.
	"Bleuette": {
		"key": "bleuette", "anchor": "chest", "offset": Vector3(0.02, -0.74, -0.32), "yaw": - PI * 0.5, "ground": false, "grab": 0.36, "arc": 0.18,
		"lean": 0.42,
		"contacts": [
			{"who": "carrier", "hand": "l", "node": "chest", "at": Vector3(0.0, -0.1, 0.1), "wrist": Vector3(0.0, 0.0, 0.0), "on": 0.08, "full": 0.18},
			{"who": "carrier", "hand": "r", "node": "knees", "at": Vector3(0.0, -0.07, 0.03), "wrist": Vector3(0.0, 0.0, 0.0), "on": 0.1, "full": 0.2},
			{"who": "carried", "hand": "r", "node": "neck", "at": Vector3(-0.06, 0.0, 0.0), "wrist": Vector3(0.0, 0.0, 0.0), "flare": 0.8, "on": 0.24, "full": 0.4},
		],
		"desired": Vector3(0.02, 0.15, -0.36),
		# Avec quelqu'un dans les bras, les genoux ne peuvent pas monter aussi haut.
		"gait": {"knee_lift": 0.62, "heel_kick": 0.9, "cadence": 1.3},
	},
	# Assise à l'envers sur les reins de Simon, comme une tourelle : cuisses de part et d'autre de ses hanches, que
	# ses mains (bras « Sonic » tendus en arrière) tiennent ; fusil braqué vers l'arrière de la course.
	"Elly": {
		"key": "elly", "anchor": "hips", "offset": Vector3(0.0, -0.7, 0.03), "yaw": PI, "ground": false, "grab": 0.46, "arc": 0.55, "spin": 1.0,
		"lean": 1.0,
		"contacts": [
			{"who": "carrier", "hand": "l", "node": "thigh_r", "at": Vector3(0.0, -0.05, 0.0), "wrist": Vector3(0.0, 0.0, 0.0), "on": 0.34, "full": 0.46},
			{"who": "carrier", "hand": "r", "node": "thigh_l", "at": Vector3(0.0, -0.05, 0.0), "wrist": Vector3(0.0, 0.0, 0.0), "on": 0.34, "full": 0.46},
		],
		"aim": {"hand": "r", "dir": Vector3(0.0, -0.03, 1.0), "support": "l", "reach": 0.3, "on": 1.0, "full": 1.3},
		"desired": Vector3(0.0, 0.15, 0.05),
		"gait": {"knee_lift": 0.85, "cadence": 1.36},
	},
	# Plus lourd (vitesse × 0,85) : traîné sur le dos par la cheville gauche, hanches soulevées, les mains derrière
	# la tête comme sur un transat.
	"Usayuko": {
		"key": "usayuko", "anchor": "root", "offset": Vector3(0.62, 0.0, 0.62), "yaw": 0.0, "ground": true, "grab": 0.42,
		"trail": Vector2(26.0, 8.0), "pivot": Vector3(0.37, 0.0, 0.0), "bank": 0.0,
		"lean": 1.06,
		"contacts": [
			{"who": "carried", "foot": "l", "node": "palm_r", "at": Vector3(0.0, -0.02, 0.0), "on": 0.05, "full": 0.12},
			{"who": "carrier", "hand": "r", "node": "ankle_l", "at": Vector3(0.0, 0.03, 0.0), "wrist": Vector3(0.0, 0.0, 0.0), "on": 0.05, "full": 0.12},
		],
		"desired": Vector3(0.6, 0.1, 0.8),
		"gait": {"cadence": 1.2, "bob": 1.1, "press": 1.0},
	},
}


static func variant(person: String) -> Dictionary:
	return VARIANTS.get(person, {})


# Position physique visée pour l'acteur porté, dans le repère du sol de Simon (z vers l'arrière).
static func desired_offset(person: String) -> Vector3:
	var rig: Dictionary = VARIANTS.get(person, {})
	return rig.get("desired", Vector3(0.0, 0.25, 0.6))


# Poids d'un contact à l'instant t du portage (arrivée entre on et full, lâcher facultatif entre off et free).
static func contact_weight(contact: Dictionary, t: float) -> float:
	var weight: float = smoothstep(float(contact.on), maxf(float(contact.full), float(contact.on) + 0.001), t)
	if contact.has("off"): weight *= 1.0 - smoothstep(float(contact.off), maxf(float(contact.get("free", contact.off)), float(contact.off) + 0.001), t)
	return weight
