extends RefCounted

# Portages de Simon pendant la course éclair (0.17) : un montage différent par allié porté.
# Le visuel porté est posé sur le visuel de Simon (character_visual.gd, passe « carry_finalize ») :
#   anchor : repère de Simon qui sert d'appui
#     "root"  : ses pieds (sol) et son cap ;
#     "chest" : la position de son buste et son cap (le porté suit les rebonds, pas la torsion des épaules) ;
#     "back"  : son buste complet, inclinaison comprise (le porté est assis sur son dos).
#   offset / yaw : racine du porté dans ce repère (mètres ; x à droite, y en haut, z vers l'arrière).
#   ground : la racine se recale sur le sol (roulettes d'Ashura, dos d'Usayuko).
#   grab : durée de la prise (s) ; le porté glisse de là où il était jusqu'à sa place, en arc.
#   contacts : mains qui tiennent vraiment quelque chose, résolues par IK après les deux poses (la paume vient
#     sur le point visé).
#     who : "carried" (main du porté) ou "carrier" (main de Simon) ; hand : "l" / "r" ;
#     node : articulation visée chez l'autre (palm_l, palm_r, root, neck, head, chest, body, knee_l, knee_r, knees,
#       ankle_l, ankle_r, arm_l, arm_r) ;
#     at : décalage en mètres dans le repère de la racine de l'autre (x droite, y haut, z arrière) ;
#     wrist : rotation du poignet (rad) ; aim : direction visée par l'objet tenu (repère de Simon) ;
#     on / full : la main arrive (poids 0 → 1) entre ces deux instants de la prise.
#   desired : où combat.gd range l'acteur porté (repère du sol de Simon), près de son visuel.
#   lean : part de l'inclinaison « Sonic » que Simon garde pendant ce portage (1 = buste plongé, 0 = droit).
#   gait : allure de Simon pendant ce portage (clés de SONIC_GAIT, anim_set_simon.gd).
# Lysia n'est jamais portée (règle de jeu, combat.gd) : pas de montage pour elle.

const CARRIER: String = "Simon"

const VARIANTS: Dictionary = {
	# Tiré par la main gauche de Simon, accroupi sur ses rollers, le bras gauche en balancier.
	"Ashura": {
		"key": "ashura", "anchor": "root", "offset": Vector3(-0.66, 0.0, 0.6), "yaw": -0.16, "ground": true, "grab": 0.34,
		"lean": 1.0,
		"contacts": [
			{"who": "carried", "hand": "r", "node": "palm_l", "at": Vector3(0.0, 0.0, 0.0), "wrist": Vector3(0.0, 0.0, 0.0), "on": 0.06, "full": 0.13},
		],
		"desired": Vector3(-0.66, 0.15, 0.6),
	},
	# En princesse : bras gauche de Simon sous son dos, bras droit sous ses genoux ; elle s'accroche à son cou.
	"Bleuette": {
		"key": "bleuette", "anchor": "chest", "offset": Vector3(0.1, -0.93, -0.3), "yaw": - PI * 0.5, "ground": false, "grab": 0.36,
		"lean": 0.3,
		"contacts": [
			{"who": "carrier", "hand": "l", "node": "chest", "at": Vector3(0.0, -0.12, 0.06), "wrist": Vector3(0.0, 0.0, 0.0), "on": 0.1, "full": 0.2},
			{"who": "carrier", "hand": "r", "node": "knees", "at": Vector3(0.0, -0.08, 0.0), "wrist": Vector3(0.0, 0.0, 0.0), "on": 0.1, "full": 0.2},
			{"who": "carried", "hand": "r", "node": "neck", "at": Vector3(0.0, 0.0, 0.09), "wrist": Vector3(0.0, 0.0, 0.0), "flare": 0.8, "on": 0.26, "full": 0.42},
			{"who": "carried", "hand": "l", "node": "chest", "at": Vector3(0.09, 0.06, -0.12), "wrist": Vector3(0.0, 0.0, 0.0), "on": 0.3, "full": 0.48},
		],
		"desired": Vector3(0.0, 0.2, -0.3),
		# Avec quelqu'un dans les bras, les genoux ne peuvent pas monter aussi haut.
		"gait": {"knee_lift": 0.62, "heel_kick": 0.9, "cadence": 1.3},
	},
	# Sur son dos, jambes repliées en jockey, retournée pour braquer son fusil vers l'arrière.
	"Elly": {
		"key": "elly", "anchor": "back", "offset": Vector3(0.0, -1.12, 0.25), "yaw": 0.0, "ground": false, "grab": 0.4,
		"lean": 0.7,
		"contacts": [
			{"who": "carrier", "hand": "r", "node": "knee_r", "at": Vector3(0.0, -0.06, 0.04), "wrist": Vector3(0.0, 0.0, 0.0), "on": 0.16, "full": 0.26},
			{"who": "carried", "hand": "l", "node": "arm_l", "at": Vector3(0.0, 0.03, -0.09), "wrist": Vector3(0.0, 0.0, 0.0), "on": 0.24, "full": 0.36},
			# Fusil braqué vers l'arrière de la course, le long du flanc droit de Simon.
			{"who": "carried", "hand": "r", "node": "root", "at": Vector3(0.3, 1.3, 0.34), "wrist": Vector3(0.0, 0.0, 0.0), "aim": Vector3(0.08, -0.08, 1.0), "on": 0.72, "full": 0.92},
		],
		"desired": Vector3(0.0, 0.25, 0.15),
		"gait": {"knee_lift": 0.9, "cadence": 1.36},
	},
	# Plus lourd (vitesse × 0,85) : traîné sur le dos par la cheville gauche, les mains derrière la tête.
	"Usayuko": {
		"key": "usayuko", "anchor": "root", "offset": Vector3(0.4, 0.0, 0.42), "yaw": 0.0, "ground": true, "grab": 0.42,
		"lean": 0.85,
		"contacts": [
			{"who": "carrier", "hand": "r", "node": "ankle_l", "at": Vector3(0.0, 0.02, 0.0), "wrist": Vector3(0.0, 0.0, 0.0), "on": 0.06, "full": 0.14},
		],
		"desired": Vector3(0.36, 0.1, 0.75),
		"gait": {"cadence": 1.2, "bob": 1.1, "press": 1.0},
	},
}


static func variant(person: String) -> Dictionary:
	return VARIANTS.get(person, {})


# Position physique visée pour l'acteur porté, dans le repère du sol de Simon (z vers l'arrière).
static func desired_offset(person: String) -> Vector3:
	var rig: Dictionary = VARIANTS.get(person, {})
	return rig.get("desired", Vector3(0.0, 0.25, 0.6))


# Poids d'un contact à l'instant t de la prise.
static func contact_weight(contact: Dictionary, t: float) -> float:
	return smoothstep(float(contact.on), maxf(float(contact.full), float(contact.on) + 0.001), t)
