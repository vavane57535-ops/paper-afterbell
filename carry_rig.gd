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
#     node : articulation visée chez l'autre (palm_l, palm_r, root, neck, head, chest, body, knee_l, knee_r, knees, arm_l, arm_r) ;
#     at : décalage en mètres dans le repère de la racine de l'autre (x droite, y haut, z arrière) ;
#     wrist : rotation du poignet (rad) ; aim : direction visée par l'objet tenu (repère de Simon) ;
#     on / full : la main arrive (poids 0 → 1) entre ces deux instants de la prise.
#   desired : où combat.gd range l'acteur porté (repère du sol de Simon), près de son visuel.
#   gait : allure de Simon pendant ce portage (clés de SONIC_GAIT, anim_set_simon.gd).
# Lysia n'est jamais portée (règle de jeu, combat.gd) : pas de montage pour elle.

const CARRIER: String = "Simon"

const VARIANTS: Dictionary = {
	"Ashura": {
		"key": "ashura", "anchor": "root", "offset": Vector3(-0.88, 0.0, 0.52), "yaw": 0.0, "ground": true, "grab": 0.34,
		"contacts": [
			{"who": "carried", "hand": "r", "node": "palm_l", "at": Vector3(-0.03, 0.0, 0.05), "wrist": Vector3(0.0, 0.0, 0.0), "on": 0.08, "full": 0.15},
		],
		"desired": Vector3(-0.85, 0.15, 0.55),
	},
	"Bleuette": {
		"key": "bleuette", "anchor": "chest", "offset": Vector3(0.1, -1.0, -0.4), "yaw": - PI * 0.5, "ground": false, "grab": 0.36,
		"contacts": [
			{"who": "carrier", "hand": "l", "node": "chest", "at": Vector3(0.0, -0.04, 0.12), "wrist": Vector3(0.0, 0.0, 0.0), "on": 0.1, "full": 0.18},
			{"who": "carrier", "hand": "r", "node": "knees", "at": Vector3(0.0, -0.09, 0.03), "wrist": Vector3(0.0, 0.0, 0.0), "on": 0.1, "full": 0.18},
			{"who": "carried", "hand": "r", "node": "neck", "at": Vector3(0.04, 0.02, 0.1), "wrist": Vector3(0.0, 0.0, 0.0), "on": 0.26, "full": 0.42},
			{"who": "carried", "hand": "l", "node": "arm_r", "at": Vector3(0.0, 0.07, -0.05), "wrist": Vector3(0.0, 0.0, 0.0), "on": 0.3, "full": 0.48},
		],
		"desired": Vector3(0.0, 0.2, -0.3),
		# Avec quelqu'un dans les bras, les genoux ne peuvent pas monter aussi haut.
		"gait": {"knee_lift": 0.72, "heel_kick": 1.0, "cadence": 1.22},
	},
	"Elly": {
		"key": "elly", "anchor": "back", "offset": Vector3(0.06, -1.12, 0.32), "yaw": 0.0, "ground": false, "grab": 0.4,
		"contacts": [
			{"who": "carrier", "hand": "r", "node": "knee_r", "at": Vector3(0.0, -0.06, 0.08), "wrist": Vector3(0.0, 0.0, 0.0), "on": 0.14, "full": 0.24},
			{"who": "carried", "hand": "l", "node": "arm_l", "at": Vector3(0.0, 0.06, -0.06), "wrist": Vector3(0.0, 0.0, 0.0), "on": 0.24, "full": 0.36},
			# Fusil braqué vers l'arrière de la course, le long du flanc droit de Simon.
			{"who": "carried", "hand": "r", "node": "root", "at": Vector3(0.3, 0.8, 0.22), "wrist": Vector3(0.0, 0.0, 0.0), "aim": Vector3(0.06, 0.02, 1.0), "on": 0.7, "full": 0.9},
		],
		"desired": Vector3(0.0, 0.2, 0.2),
	},
	"Usayuko": {
		"key": "usayuko", "anchor": "root", "offset": Vector3(0.3, 0.0, 1.1), "yaw": PI, "ground": true, "grab": 0.42,
		"contacts": [
			{"who": "carrier", "hand": "r", "node": "chest", "at": Vector3(0.0, 0.07, 0.15), "wrist": Vector3(0.0, 0.0, 0.0), "on": 0.08, "full": 0.14},
		],
		"desired": Vector3(0.3, 0.1, 1.05),
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
