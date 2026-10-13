extends RefCounted

# Portages de Simon pendant la course éclair (0.17) : un montage différent par allié porté.
# Le visuel porté est posé sur le visuel de Simon (character_visual.gd, passe « _carry_finalize ») :
#   anchor : repère de Simon qui sert d'appui
#     "root"  : ses pieds (sol) et son cap ;
#     "chest" : la position de son buste et son cap (le porté suit les rebonds, pas la torsion des épaules) ;
#     "back"  : son buste complet, inclinaison comprise (le porté est couché sur son dos).
#   offset / yaw : racine du porté dans ce repère (mètres ; x à droite, y en haut, z vers l'arrière).
#   ground : la racine se recale sur le sol (roulettes d'Ashura, talons d'Usayuko).
#   grab : durée de la prise (s) ; le porté glisse de là où il était jusqu'à sa place, en arc.
#   contacts : mains qui tiennent vraiment quelque chose, résolues par IK après les deux poses.
#     who : "carried" (main du porté) ou "carrier" (main de Simon) ; hand : "l" / "r" ;
#     node : articulation visée chez l'autre (palm_l, palm_r, neck, chest, body, knee_l, knee_r, arm_l, arm_r) ;
#     at : décalage en mètres dans le repère de cette articulation ; wrist : rotation du poignet (rad) ;
#     on / full : la main arrive (poids 0 → 1) entre ces deux instants de la prise.
#   desired : où combat.gd range l'acteur porté (repère du sol de Simon), près de son visuel.
# Lysia n'est jamais portée (règle de jeu, combat.gd) : pas de montage pour elle.

const CARRIER: String = "Simon"

const VARIANTS: Dictionary = {
	"Ashura": {
		"key": "ashura", "anchor": "root", "offset": Vector3(-0.88, 0.0, 0.52), "yaw": 0.0, "ground": true, "grab": 0.34,
		"contacts": [
			{"who": "carried", "hand": "r", "node": "palm_l", "at": Vector3(0.0, 0.0, 0.0), "wrist": Vector3(0.0, 0.0, 0.0), "on": 0.08, "full": 0.15},
		],
		"desired": Vector3(-0.85, 0.15, 0.55),
	},
	"Bleuette": {
		"key": "bleuette", "anchor": "chest", "offset": Vector3(0.05, -0.96, -0.32), "yaw": - PI * 0.5, "ground": false, "grab": 0.36,
		"contacts": [
			{"who": "carrier", "hand": "l", "node": "chest", "at": Vector3(0.0, 0.02, 0.12), "wrist": Vector3(0.0, 0.0, 0.0), "on": 0.1, "full": 0.18},
			{"who": "carrier", "hand": "r", "node": "knee_l", "at": Vector3(0.0, -0.06, 0.04), "wrist": Vector3(0.0, 0.0, 0.0), "on": 0.1, "full": 0.18},
			{"who": "carried", "hand": "r", "node": "neck", "at": Vector3(0.06, 0.0, 0.1), "wrist": Vector3(0.0, 0.0, 0.0), "on": 0.26, "full": 0.42},
			{"who": "carried", "hand": "l", "node": "arm_r", "at": Vector3(0.0, 0.05, -0.04), "wrist": Vector3(0.0, 0.0, 0.0), "on": 0.3, "full": 0.48},
		],
		"desired": Vector3(0.0, 0.2, -0.3),
	},
	"Elly": {
		"key": "elly", "anchor": "back", "offset": Vector3(0.0, -1.18, 0.17), "yaw": 0.0, "ground": false, "grab": 0.4,
		"contacts": [
			{"who": "carrier", "hand": "r", "node": "knee_r", "at": Vector3(0.0, -0.04, 0.12), "wrist": Vector3(0.0, 0.0, 0.0), "on": 0.14, "full": 0.24},
			{"who": "carried", "hand": "l", "node": "arm_l", "at": Vector3(0.0, 0.06, -0.02), "wrist": Vector3(0.0, 0.0, 0.0), "on": 0.24, "full": 0.36},
			# Fusil braqué vers l'arrière de la course, le long du flanc droit de Simon.
			{"who": "carried", "hand": "r", "node": "root", "at": Vector3(0.3, 0.8, 0.22), "wrist": Vector3(0.0, 0.0, 0.0), "aim": Vector3(0.06, 0.02, 1.0), "on": 0.7, "full": 0.9},
		],
		"desired": Vector3(0.0, 0.2, 0.2),
	},
	"Usayuko": {
		"key": "usayuko", "anchor": "root", "offset": Vector3(0.24, 0.0, 1.22), "yaw": PI, "ground": true, "grab": 0.42,
		"contacts": [
			{"who": "carrier", "hand": "r", "node": "chest", "at": Vector3(0.0, 0.16, 0.12), "wrist": Vector3(0.0, 0.0, 0.0), "on": 0.08, "full": 0.14},
		],
		"desired": Vector3(0.24, 0.1, 1.15),
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
